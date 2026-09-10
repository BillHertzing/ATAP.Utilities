<#
.SYNOPSIS
    Detects silently-failing database backups by verifying that the backup mechanism actually
    engaged, not merely that a file appeared.

.DESCRIPTION
    Task 15.192.h. This function exists because of a specific, verified failure class on this
    estate: a backup mechanism that reports success while doing nothing.

    Three instances were confirmed in Sprint 0015, and all three would have passed a naive
    "did a recent file appear / did it exit 0" check:

      1. The Cobian SQL jobs invoked `pwsh -File` against a script that only DEFINES a
         function. The invocation exited 0 having never run the function. No backup was
         taken for four months and nothing alerted, because nothing failed.
      2. The nightly application-data job wrote a 22-byte empty archive every night. A fresh,
         correctly-named artifact appeared on schedule and was indistinguishable from success.
      3. The shared git hooks were `.ps1` files where git requires extensionless names, so no
         hook ever ran and every commit passed validation that did not exist (SC-0413).

    The common defect is that an exit code or a freshly-dated artifact was taken as proof the
    mechanism engaged. This function therefore treats `msdb.dbo.backupset` as the authority on
    whether SQL Server actually performed a backup, and cross-checks it against what was
    published to the off-host root. Presence and absence are BOTH findings, in both
    directions:

      - a backupset row with no published artifact means the publisher failed;
      - a published artifact with no backupset row means something other than SQL Server wrote
        it, which is exactly the unexplained shape of the 2026-04-02..05-03 artifacts.

    No filesystem root is hardcoded. Roots are resolved through Get-PVal from $global:Settings
    keyed by $global:ConfigRootKeys, identically to Invoke-SqlServerBackup:
        LocalDBsRootPathConfigRootKey              -> instance-local staging root
        DatabaseBackupPublicationRootConfigRootKey -> off-host publication root
    The function throws rather than guessing a root, because a health check pointed at the
    wrong directory reports healthy forever and is worse than no check at all.

.PARAMETER SqlInstances
    Instance names to check (for example 'PRODUCTION','QA'). Each is contacted as .\<name>.

.PARAMETER ProtectedDatabases
    Databases that MUST have current backups. A protected database with no recent backupset
    row is the highest-severity finding this function produces, because it is the silent case.

.PARAMETER ExcludeDatabasePattern
    SQL LIKE pattern for databases excluded from checks. Defaults to the disposable
    'ATAPUtilities[_]Task%' pattern; those are recreated by ordinary task runs and would
    otherwise make findings unbounded.

.PARAMETER MaxFullAgeDays
    A protected database with no full backup newer than this is reported. Default 8, allowing
    one missed weekly full before alerting.

.PARAMETER MaxDiffAgeHours
    A protected database with no differential newer than this is reported. Default 48.

.PARAMETER MaxLogAgeMinutes
    Only applied when the database is in FULL recovery. Default 30, twice the policy's
    15-minute RPO.

.PARAMETER MinPlausibleArtifactBytes
    Published artifacts smaller than this are reported as implausible. Default 4096 — chosen
    because an empty zip is 22 bytes and an empty 7z is similarly tiny, and no real database
    backup is under 4 KB.

.PARAMETER ExpectedRecoveryModel
    When supplied, a protected database whose recovery model differs is reported. Use FULL
    once Task 15.192.b converts; leave unset to skip the check.

.PARAMETER MaxStagingAgeHours
    Artifacts left in instance-local staging longer than this are reported: the publisher ran
    and did not move them, or died mid-move. Default 6.

.OUTPUTS
    [PSCustomObject] with Healthy, FindingCount, CheckedInstanceCount, Findings, and
    GeneratedUtc. Each finding carries Severity, Check, Instance, Database, Detail.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Read-only. Performs no backup, no move, no delete, and no configuration change.
#>

function Test-DatabaseBackupHealth {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [string[]] $SqlInstances = @('PRODUCTION', 'QA', 'INTEGRATION', 'DEVWHERTZING', 'EXPWHERTZING'),

    [Parameter()]
    [string[]] $ProtectedDatabases = @('ATAPUtilities', 'BuildMaster', 'ProGet', 'BuildSets'),

    [Parameter()]
    [string] $ExcludeDatabasePattern = 'ATAPUtilities[_]Task%',

    [Parameter()]
    [string] $ComputerName,

    [Parameter()]
    [string] $LocalDBsRoot,

    [Parameter()]
    [string] $DatabaseBackupPublicationRoot,

    [Parameter()]
    [int] $MaxFullAgeDays = 8,

    [Parameter()]
    [int] $MaxDiffAgeHours = 48,

    [Parameter()]
    [int] $MaxLogAgeMinutes = 30,

    [Parameter()]
    [int] $MinPlausibleArtifactBytes = 4096,

    [Parameter()]
    [ValidateSet('FULL', 'SIMPLE', 'BULK_LOGGED')]
    [string] $ExpectedRecoveryModel,

    [Parameter()]
    [int] $MaxStagingAgeHours = 6,

    [Parameter()]
    [hashtable] $Settings
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'

    $effectiveSettings = if ($PSBoundParameters.ContainsKey('Settings') -and $Settings) { $Settings } else { $global:Settings }

    $ComputerName = Get-PVal -ParameterName 'ComputerName' -originalPSBoundParameters $PSBoundParameters -DefaultValue $env:COMPUTERNAME -AllowMissing
    if ([string]::IsNullOrWhiteSpace($ComputerName)) { $ComputerName = $env:COMPUTERNAME }
    $ComputerName = $ComputerName.ToLowerInvariant()

    $localKey = $global:ConfigRootKeys['LocalDBsRootPathConfigRootKey']
    $localDefault = if ($localKey -and $effectiveSettings -and $effectiveSettings.ContainsKey($localKey)) { $effectiveSettings[$localKey] } else { $null }
    $LocalDBsRoot = Get-PVal -ParameterName 'LocalDBsRoot' -originalPSBoundParameters $PSBoundParameters -DefaultValue $localDefault -AllowMissing

    $pubKey = $global:ConfigRootKeys['DatabaseBackupPublicationRootConfigRootKey']
    $pubDefault = if ($pubKey -and $effectiveSettings -and $effectiveSettings.ContainsKey($pubKey)) { $effectiveSettings[$pubKey] } else { $null }
    $DatabaseBackupPublicationRoot = Get-PVal -ParameterName 'DatabaseBackupPublicationRoot' -originalPSBoundParameters $PSBoundParameters -DefaultValue $pubDefault -AllowMissing

    # Fail closed. A health check that silently defaults to the wrong directory reports
    # healthy forever, which is the exact defect class this function exists to catch.
    foreach ($pair in @(
        @{ Name = 'LocalDBsRoot'; Value = $LocalDBsRoot; Key = $localKey },
        @{ Name = 'DatabaseBackupPublicationRoot'; Value = $DatabaseBackupPublicationRoot; Key = $pubKey })) {
      if ([string]::IsNullOrWhiteSpace($pair.Value)) {
        $msg = "$($pair.Name) could not be resolved (config root key '$($pair.Key)'). Refusing to run a health check against a guessed path."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }
    }

    $publicationRootForHost = Join-Path $DatabaseBackupPublicationRoot $ComputerName
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Health check on [$ComputerName]: staging [$LocalDBsRoot], publication [$publicationRootForHost]."

    $findings = [System.Collections.Generic.List[object]]::new()
    function Add-Finding {
      param([string]$Severity, [string]$Check, [string]$Instance, [string]$Database, [string]$Detail)
      $findings.Add([PSCustomObject]@{
          Severity = $Severity
          Check    = $Check
          Instance = $Instance
          Database = $Database
          Detail   = $Detail
        })
    }
  }

  process {
    $now = Get-Date
    $checkedInstances = 0
    $reportedStagingDirs = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($instance in $SqlInstances) {
      $server = ".\$instance"

      # msdb.dbo.backupset is the authority on whether SQL Server actually performed a backup.
      # The filesystem is not: a file can exist without a backup having happened, and a backup
      # can have happened without a file surviving.
      $query = @"
SET NOCOUNT ON;
SELECT d.name AS DatabaseName,
       d.recovery_model_desc AS RecoveryModel,
       CONVERT(varchar(30), MAX(CASE WHEN b.type = 'D' THEN b.backup_finish_date END), 126) AS LastFull,
       CONVERT(varchar(30), MAX(CASE WHEN b.type = 'I' THEN b.backup_finish_date END), 126) AS LastDiff,
       CONVERT(varchar(30), MAX(CASE WHEN b.type = 'L' THEN b.backup_finish_date END), 126) AS LastLog
FROM sys.databases d
LEFT JOIN msdb.dbo.backupset b
       ON b.database_name COLLATE DATABASE_DEFAULT = d.name COLLATE DATABASE_DEFAULT
WHERE d.database_id > 4
  AND d.name NOT LIKE '$ExcludeDatabasePattern'
GROUP BY d.name, d.recovery_model_desc;
"@

      $raw = & sqlcmd -S $server -E -h -1 -W -s '|' -Q $query 2>&1
      if ($LASTEXITCODE -ne 0) {
        Add-Finding -Severity 'Critical' -Check 'InstanceUnreachable' -Instance $instance -Database '' `
          -Detail "Could not query [$server]. A health check that cannot reach an instance proves nothing about it; treat as failure, not as absence of findings. sqlcmd: $($raw -join ' ')"
        continue
      }
      $checkedInstances++

      $rows = $raw | Where-Object { "$_".Trim() -and "$_" -notmatch 'rows affected' -and "$_" -match '\|' }
      $seenDatabases = @()

      foreach ($row in $rows) {
        $parts = "$row".Split('|')
        if ($parts.Count -lt 5) { continue }
        $db = $parts[0].Trim()
        $recovery = $parts[1].Trim()
        $seenDatabases += $db

        $lastFull = if ($parts[2].Trim() -in @('NULL', '')) { $null } else { [datetime]::Parse($parts[2].Trim()) }
        $lastDiff = if ($parts[3].Trim() -in @('NULL', '')) { $null } else { [datetime]::Parse($parts[3].Trim()) }
        $lastLog = if ($parts[4].Trim() -in @('NULL', '')) { $null } else { [datetime]::Parse($parts[4].Trim()) }

        $isProtected = $ProtectedDatabases -contains $db
        if (-not $isProtected) { continue }

        # --- The silent case: SQL Server never ran a backup at all. ---
        if ($null -eq $lastFull) {
          Add-Finding -Severity 'Critical' -Check 'NoBackupEverRecorded' -Instance $instance -Database $db `
            -Detail 'msdb.dbo.backupset holds no full-backup row for this protected database. The mechanism has never engaged. This is the failure shape that produced four months of undetected data loss exposure in Sprint 0015.'
        } elseif ($lastFull -lt $now.AddDays(-$MaxFullAgeDays)) {
          Add-Finding -Severity 'Critical' -Check 'StaleFullBackup' -Instance $instance -Database $db `
            -Detail "Last full backup recorded $($lastFull.ToString('yyyy-MM-dd HH:mm')), older than the $MaxFullAgeDays-day threshold."
        }

        if ($null -ne $lastFull -and ($null -eq $lastDiff -or $lastDiff -lt $now.AddHours(-$MaxDiffAgeHours))) {
          $detail = if ($null -eq $lastDiff) { 'No differential backup has ever been recorded.' } else { "Last differential recorded $($lastDiff.ToString('yyyy-MM-dd HH:mm'))." }
          Add-Finding -Severity 'Warning' -Check 'StaleDifferentialBackup' -Instance $instance -Database $db `
            -Detail "$detail Threshold is $MaxDiffAgeHours hours."
        }

        if ($recovery -eq 'FULL') {
          if ($null -eq $lastLog) {
            Add-Finding -Severity 'Critical' -Check 'BrokenLogChain' -Instance $instance -Database $db `
              -Detail 'Database is in FULL recovery but no log backup has ever been recorded. The log will grow without bound and no point-in-time recovery is possible.'
          } elseif ($lastLog -lt $now.AddMinutes(-$MaxLogAgeMinutes)) {
            Add-Finding -Severity 'Critical' -Check 'StaleLogBackup' -Instance $instance -Database $db `
              -Detail "Last log backup $($lastLog.ToString('yyyy-MM-dd HH:mm')), beyond the $MaxLogAgeMinutes-minute threshold. The stated RPO is not being met."
          }
        }

        if ($ExpectedRecoveryModel -and $recovery -ne $ExpectedRecoveryModel) {
          Add-Finding -Severity 'Warning' -Check 'RecoveryModelMismatch' -Instance $instance -Database $db `
            -Detail "Recovery model is $recovery, expected $ExpectedRecoveryModel. Any RPO shorter than the differential interval is unachievable while this is SIMPLE."
        }

        # --- Cross-check: SQL says it ran; did anything reach the publication root? ---
        $publishedDir = Join-Path (Join-Path $DatabaseBackupPublicationRoot $ComputerName) $db
        $published = @()
        if (Test-Path -LiteralPath $publishedDir) {
          $published = @(Get-ChildItem -LiteralPath $publishedDir -File -Force -ErrorAction SilentlyContinue)
        }

        if ($null -ne $lastFull -and $published.Count -eq 0) {
          Add-Finding -Severity 'Critical' -Check 'BackupNotPublished' -Instance $instance -Database $db `
            -Detail "SQL recorded a backup at $($lastFull.ToString('yyyy-MM-dd HH:mm')) but [$publishedDir] holds no artifact. The backup ran and the publisher did not deliver it off-host."
        }

        foreach ($artifact in $published) {
          if ($artifact.Length -lt $MinPlausibleArtifactBytes) {
            Add-Finding -Severity 'Critical' -Check 'ImplausibleArtifactSize' -Instance $instance -Database $db `
              -Detail "[$($artifact.Name)] is $($artifact.Length) bytes, below the $MinPlausibleArtifactBytes-byte plausibility floor. An empty archive is $([char]0x2248)22 bytes and looks identical to a success to any timestamp-based check."
          }
        }

        # An artifact newer than anything SQL recorded means something other than SQL Server
        # wrote it. This is the unexplained 2026-04-02..05-03 shape and must not be treated as
        # healthy just because a recent file exists.
        $newestPublished = $published | Sort-Object LastWriteTime | Select-Object -Last 1
        if ($newestPublished -and $null -ne $lastFull -and $newestPublished.LastWriteTime -gt $lastFull.AddHours(1)) {
          Add-Finding -Severity 'Warning' -Check 'UnattributedArtifact' -Instance $instance -Database $db `
            -Detail "Published artifact [$($newestPublished.Name)] dated $($newestPublished.LastWriteTime.ToString('yyyy-MM-dd HH:mm')) is newer than the most recent backupset row ($($lastFull.ToString('yyyy-MM-dd HH:mm'))). Something other than this instance produced it; do not count it as coverage until explained."
        }
      }

      foreach ($expected in $ProtectedDatabases) {
        if ($seenDatabases -notcontains $expected) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "[$instance] does not host [$expected]; not a finding."
        }
      }

      # --- Staging: artifacts stranded where SQL wrote them mean the publisher stalled. ---
      # BOTH staging roots are checked deliberately. The Task 13.60.b policy root is
      # <LocalDBsRoot>\<INSTANCE>\Backup, but the Gate B decision of 2026-09-10 has SQL
      # writing to <FastTempBasePath>\CobianReflectorBackup instead (SC-0421 tracks
      # restoring the policy root). Checking only one would report healthy staging forever
      # against an empty directory — which is precisely the silent-success failure this
      # function exists to catch, and would have missed the 32-byte empty archive stranded
      # in the temp root since 2026-04-02. Checking both is correct before and after SC-0421.
      $fastTempKey = $global:ConfigRootKeys['FastTempBasePathConfigRootKey']
      $fastTempRoot = if ($fastTempKey -and $effectiveSettings -and $effectiveSettings.ContainsKey($fastTempKey)) { $effectiveSettings[$fastTempKey] } else { $null }

      $stagingDirs = @(Join-Path (Join-Path $LocalDBsRoot $instance) 'Backup')
      if (-not [string]::IsNullOrWhiteSpace($fastTempRoot)) {
        $stagingDirs += (Join-Path $fastTempRoot 'CobianReflectorBackup')
      }

      foreach ($stagingDir in ($stagingDirs | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $stagingDir)) { continue }
        # The temp staging root is shared across instances, not instance-scoped, so without
        # this guard the same stranded artifact is reported once per instance. Duplicate
        # alerts for one fact are how alert channels get muted, which recreates the silence
        # this function exists to break.
        if (-not $reportedStagingDirs.Add($stagingDir)) { continue }
        $stranded = @(Get-ChildItem -LiteralPath $stagingDir -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $now.AddHours(-$MaxStagingAgeHours) })
        if ($stranded.Count -gt 0) {
          $oldest = ($stranded | Sort-Object LastWriteTime | Select-Object -First 1)
          Add-Finding -Severity 'Warning' -Check 'StaleStaging' -Instance $instance -Database '' `
            -Detail "$($stranded.Count) artifact(s) left in [$stagingDir] beyond $MaxStagingAgeHours hours; oldest [$($oldest.Name)] at $($oldest.LastWriteTime.ToString('yyyy-MM-dd HH:mm')), $($oldest.Length) bytes. The publisher is not draining staging."
        }
      }
    }

    if ($checkedInstances -eq 0) {
      Add-Finding -Severity 'Critical' -Check 'NoInstanceChecked' -Instance '' -Database '' `
        -Detail 'No instance could be reached. This result carries no information about backup health and must never be reported as healthy.'
    }

    $critical = @($findings | Where-Object { $_.Severity -eq 'Critical' })

    [PSCustomObject]@{
      GeneratedUtc         = (Get-Date).ToUniversalTime()
      ComputerName         = $ComputerName
      Healthy              = ($findings.Count -eq 0)
      FindingCount         = $findings.Count
      CriticalCount        = $critical.Count
      CheckedInstanceCount = $checkedInstances
      StagingRoot          = $LocalDBsRoot
      PublicationRoot      = $publicationRootForHost
      Findings             = $findings.ToArray()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "$fn complete."
  }
}

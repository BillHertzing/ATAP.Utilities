function Assert-MaintenanceWindowBinding {
  <#
  .SYNOPSIS
    Reads, pins and validates one database maintenance window binding against the schema and the fixed tier map.
  .DESCRIPTION
    Refuses unless:
      - the file's SHA-256 equals ExpectedSha256 (MaintenanceWindowBindingPinMismatch);
      - it is UTF-8 JSON without a BOM and passes database-maintenance-binding-v1 (MaintenanceWindowBindingSchemaInvalid);
      - its tier and mode equal the call's -Tier and -Mode, and the mode is allowed for the tier;
      - its host, instance, allowed data sources, runner login and SID, SqlClient path and hash equal the fixed tier map;
      - the clone name, clone files and backup file follow the OperationSet/tier/attempt naming rule, contain no
        'rehearsal', and the backup and evidence paths are under the artifact root (never Dropbox);
      - every declared operation has a unique name, an existing file with exactly its pinned SHA-256, a
        database of master, the catalog or the clone, and a kind this runner may run (Recover is
        operator-only and refused);
      - the approval window is open now and no longer than the tier map's maximum;
      - for Production, the Ace Outpost pause record exists with its pinned hash and the pause list names Ace Outpost.
    Every refusal throws 'MaintenanceWindow<Reason>|<detail>' before any SQL runs.
  .PARAMETER BindingPath
    Path to the binding JSON.
  .PARAMETER ExpectedSha256
    Independently supplied SHA-256 of the binding file.
  .PARAMETER Tier
    Tier the caller intends; must equal the binding's.
  .PARAMETER Mode
    Mode the caller intends; must equal the binding's.
  .PARAMETER NowUtc
    Evaluation time (test seam); defaults to the current UTC time.
  .OUTPUTS
    PSCustomObject with Binding, BindingSha256, TierMap, RehearsalName.
  .EXAMPLE
    Assert-MaintenanceWindowBinding -BindingPath $p -ExpectedSha256 $h -Tier Development -Mode PrecheckOnly
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines. DB-Runner-S1-Foundation.
  .LINK
    Get-MaintenanceWindowTierMap
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)][string]$BindingPath,
    [Parameter(Mandatory)][ValidatePattern('\A[0-9a-fA-F]{64}\z')][string]$ExpectedSha256,
    [Parameter(Mandatory)][ValidateSet('Development', 'Integration', 'QA', 'Production')][string]$Tier,
    [Parameter(Mandatory)][ValidateSet('PrecheckOnly', 'BackupOnly', 'Full', 'DropClone')][string]$Mode,
    [DateTimeOffset]$NowUtc = [DateTimeOffset]::UtcNow
  )
  begin {
    $fn = 'Assert-MaintenanceWindowBinding'
    $mn = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
    $null = Get-Command -Name Test-Json -ErrorAction Stop
  }
  process {
    $refuse = { param($code, $detail) Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Binding refused: $code $detail"; throw ('MaintenanceWindow' + $code + '|' + $detail) }
    if (-not [IO.File]::Exists($BindingPath)) { & $refuse 'BindingMissing' $BindingPath }
    $bytes = [IO.File]::ReadAllBytes($BindingPath)
    $sha = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
    if (-not [string]::Equals($sha, $ExpectedSha256, [StringComparison]::OrdinalIgnoreCase)) { & $refuse 'BindingPinMismatch' $sha }
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { & $refuse 'BindingSchemaInvalid' 'BOM' }
    try { $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes) } catch { & $refuse 'BindingSchemaInvalid' 'NotUtf8' }
    $schemaPath = Join-Path (Get-MaintenanceWindowModuleRoot) 'schemas\database-maintenance-binding-v1.schema.json'
    $schemaText = [IO.File]::ReadAllText($schemaPath)
    $valid = $false
    try { $valid = Test-Json -Json $text -Schema $schemaText -ErrorAction Stop } catch { $valid = $false }
    if (-not $valid) { & $refuse 'BindingSchemaInvalid' 'database-maintenance-binding-v1' }
    # -DateKind String: otherwise ISO timestamps become local DateTime values and the window check drifts.
    $b = $text | ConvertFrom-Json -Depth 20 -DateKind String

    $map = Get-MaintenanceWindowTierMap -Tier $Tier
    if ([string]$b.tier -cne $Tier) { & $refuse 'BindingTierMismatch' ([string]$b.tier) }
    if ([string]$b.mode -cne $Mode) { & $refuse 'BindingModeMismatch' ([string]$b.mode) }
    if ($map.AllowedModes -cnotcontains $Mode) { & $refuse 'TierHasNoSuchMode' "$Tier/$Mode" }
    if (-not [string]::Equals([string]$b.sqlInstance, $map.SqlInstance, [StringComparison]::OrdinalIgnoreCase)) { & $refuse 'BindingInstanceMismatch' ([string]$b.sqlInstance) }
    if ([string]$b.catalog -cne $map.Catalog) { & $refuse 'BindingCatalogMismatch' ([string]$b.catalog) }
    if (-not [string]::Equals([string]$b.expectedLogin, $map.RunnerLogin, [StringComparison]::OrdinalIgnoreCase)) { & $refuse 'BindingRunnerMismatch' 'login' }
    if ([string]$b.expectedSid -cne $map.RunnerSid) { & $refuse 'BindingRunnerMismatch' 'sid' }
    if (-not [string]::Equals([string]$b.sqlClient.path, $map.SqlClientPath, [StringComparison]::OrdinalIgnoreCase) -or
        -not [string]::Equals([string]$b.sqlClient.sha256, $map.SqlClientSha256, [StringComparison]::OrdinalIgnoreCase)) { & $refuse 'BindingSqlClientNotPinned' ([string]$b.sqlClient.path) }

    # Host and data sources: the binding's host must be the tier map's, and every allowed data source must name
    # this tier's instance on that host (or localhost / '.').
    if (-not [string]::Equals([string]$b.HostName, $map.MachineName, [StringComparison]::OrdinalIgnoreCase)) { & $refuse 'BindingHostMismatch' ([string]$b.HostName) }
    $sources = @($b.AllowedDataSources)
    if (-not ($sources | Where-Object { [string]::Equals([string]$_, $map.SqlInstance, [StringComparison]::OrdinalIgnoreCase) })) { & $refuse 'BindingDataSourceMismatch' 'SqlInstanceNotListed' }
    foreach ($s in $sources) {
      $parts = ([string]$s).Split('\')
      if ($parts.Count -ne 2 -or $parts[0] -notin @($map.MachineName, 'localhost', '.') -or -not [string]::Equals($parts[1], ($map.SqlInstance.Split('\')[1]), [StringComparison]::OrdinalIgnoreCase)) { & $refuse 'BindingDataSourceMismatch' ([string]$s) }
    }

    # Naming rule: one clone and one backup per operation set, tier and attempt. 'rehearsal' is reserved for the gate (63043/63045 analogues).
    $set = [string]$b.OperationSet.Name
    $expectedClone = 'ATAPUtilities_{0}Clone_{1}_{2}' -f $set, $Tier, $b.attempt
    if ([string]$b.cloneName -cne $expectedClone) { & $refuse 'BindingCloneNameInvalid' ([string]$b.cloneName) }
    if ([IO.Path]::GetFileName([string]$b.cloneDataPath) -cne ($expectedClone + '.mdf') -or
        [IO.Path]::GetFileName([string]$b.cloneLogPath) -cne ($expectedClone + '_log.ldf')) { & $refuse 'BindingClonePathInvalid' 'leaf' }
    $expectedBak = 'ATAPUtilities_{0}_{1}_BeforeMaintenance_{2}.bak' -f $Tier, $set, $b.attempt
    if ([IO.Path]::GetFileName([string]$b.backupPath) -cne $expectedBak) { & $refuse 'BindingBackupPathInvalid' 'leaf' }
    foreach ($p in @([string]$b.cloneDataPath, [string]$b.cloneLogPath, [string]$b.backupPath, [string]$b.evidenceRoot)) {
      if ($p -imatch 'rehearsal') { & $refuse 'BindingPathReserved' $p }
      if ([IO.Path]::GetFullPath($p) -cne $p) { & $refuse 'BindingPathNotCanonical' $p }
    }
    foreach ($p in @([string]$b.backupPath, [string]$b.evidenceRoot)) {
      if (-not $p.StartsWith($map.ArtifactRoot, [StringComparison]::OrdinalIgnoreCase)) { & $refuse 'BindingPathOutsideArtifactRoot' $p }
    }

    # Declared operation set: every operation is pinned to its exact file, targets only master, the catalog
    # or this window's clone, and has a kind this runner may run. Recover is operator-only.
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($op in @($b.Operations)) {
      if (-not $names.Add([string]$op.Name)) { & $refuse 'OperationNameDuplicate' ([string]$op.Name) }
      if ([string]$op.Kind -ceq 'Recover') { & $refuse 'OperationKindNotAllowed' ([string]$op.Name) }
      if ([string]$op.Database -cnotin @('master', $map.Catalog, $expectedClone)) { & $refuse 'OperationDatabaseNotAllowed' ([string]$op.Name) }
      if ([string]$op.Kind -ceq 'LfLineEndingRepair') {
        # A line-ending repair changes modules and history, so it targets the catalog or the clone, never master;
        # each module and each repair target is named once.
        if ([string]$op.Database -ceq 'master') { & $refuse 'OperationDatabaseNotAllowed' ([string]$op.Name) }
        $modules = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($alter in @($op.ModuleAlters)) { if (-not $modules.Add(([string]$alter.Schema) + '.' + ([string]$alter.Name))) { & $refuse 'OperationModuleDuplicate' (([string]$alter.Schema) + '.' + ([string]$alter.Name)) } }
        $versions = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($target in @($op.FlywayRepairTargets)) { if (-not $versions.Add([string]$target.Version)) { & $refuse 'OperationRepairTargetDuplicate' ([string]$target.Version) } }
      }
      if (-not [IO.File]::Exists([string]$op.Path)) { & $refuse 'OperationFileMissing' ([string]$op.Name) }
      $opSha = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes([string]$op.Path)))
      if (-not [string]::Equals($opSha, [string]$op.Sha256, [StringComparison]::OrdinalIgnoreCase)) { & $refuse 'OperationPinMismatch' ([string]$op.Name) }
    }

    # Approval window: open now, positive and bounded.
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $start = [DateTimeOffset]::MinValue; $end = [DateTimeOffset]::MinValue
    # The shared schema allows null until approval fills the window; no run is possible before that.
    if ($null -eq $b.NotBeforeUtc -or $null -eq $b.ExpiresUtc) { & $refuse 'BindingWindowNotFilled' '' }
    if (-not [DateTimeOffset]::TryParse([string]$b.notBeforeUtc, $culture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$start) -or
        -not [DateTimeOffset]::TryParse([string]$b.expiresUtc, $culture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$end)) { & $refuse 'BindingWindowInvalid' 'unparseable' }
    if ($end -le $start -or ($end - $start).TotalHours -gt $map.MaxWindowHours) { & $refuse 'BindingWindowInvalid' 'length' }
    if ($NowUtc -lt $start -or $NowUtc -ge $end) { & $refuse 'BindingWindowClosed' $NowUtc.ToString('o') }

    # Production: the Ace Outpost pause must be on record and named.
    if ($map.RequiresProductionPauseRecord) {
      $record = $b.productionPauseRecord
      if ($null -eq $record -or -not [IO.File]::Exists([string]$record.path)) { & $refuse 'ProductionPauseRecordMissing' '' }
      $recordSha = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes([string]$record.path)))
      if (-not [string]::Equals($recordSha, [string]$record.sha256, [StringComparison]::OrdinalIgnoreCase)) { & $refuse 'ProductionPauseRecordPinMismatch' $recordSha }
      if (-not (@($b.pauseList) | Where-Object { $_ -imatch 'Ace ?Outpost' })) { & $refuse 'ProductionPauseListLacksAceOutpost' '' }
    }

    [pscustomobject]@{
      Binding       = $b
      BindingSha256 = $sha
      TierMap       = $map
      RehearsalName = 'ATAPUtilities-rehearsal-{0}-{1}' -f $b.buildId, $Tier
      ClonePrefix   = 'ATAPUtilities_{0}Clone_' -f $set
    }
  }
  end {}
}

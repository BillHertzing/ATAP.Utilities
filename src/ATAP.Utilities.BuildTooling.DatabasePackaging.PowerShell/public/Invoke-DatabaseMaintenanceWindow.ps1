#Requires -Version 7.0
<#
.SYNOPSIS
  Runs one database maintenance window step set for one tier (slice S1: -Mode PrecheckOnly only).

.DESCRIPTION
  A general, binding-driven maintenance window: the specific job (for example the line-ending repair
  for package 0.1.21, OperationSet 'LF021') is the binding's declared OperationSet and Operations[],
  so later one-off fixes reuse the same window. It is the tier-parameterized form of the two reviewed
  Experimental packets (senior1-backup-r3 and clerk2-clone-maint), run as UTAT022\SvcBuildmaster from
  the BuildMaster plan ATAPUtilitiesDb-MaintenanceWindow (application 1005) through the signed
  launcher Resources\MaintenanceWindow\Start-DatabaseMaintenanceWindow.ps1. Design: _Planning
  ...\senior3-maint-runner-design\Design.md and Design.r2.md.

  Every tier-specific value comes from one hashed binding (database-maintenance-binding-v1) checked
  against the module's fixed tier map. Before any SQL it requires, in order:
    1. the binding pin, schema, tier, mode, names, paths, approval window and (Production) the
       Ace Outpost pause record (Assert-MaintenanceWindowBinding);
    2. every pinned SQL and schema resource unchanged (Assert-MaintenanceWindowResources);
    3. exactly one ATAP.Utilities.DatabaseManagement.Powershell, loaded from its pinned AllUsers
       folder (Assert-MaintenanceWindowDependency);
    4. the process identity equal to the binding's runner SID;
    5. a new, not yet existing evidence folder under the binding's evidence root.

  -Mode PrecheckOnly then runs Resources\MaintenanceWindow\WindowPrecheck.sql against master through
  the pinned Microsoft.Data.SqlClient (read-only: DMVs and catalog views), writes the capture in
  the shared {ResultSets:[...]} shape and a verdict, and returns Passed or Failed. It writes no SQL
  state. Other modes refuse (MaintenanceWindowModeNotImplemented) until their slices land.

  Refusals before SQL throw 'MaintenanceWindow<Reason>|<detail>'. Nothing retries.

.PARAMETER Tier
  Development, Integration, QA or Production. Experimental is run by hand from the packets.

.PARAMETER Mode
  PrecheckOnly (S1). BackupOnly, Full and DropClone refuse until implemented.

.PARAMETER BindingPath
  The window binding JSON.

.PARAMETER ExpectedBindingSha256
  Independently supplied SHA-256 of the binding (a BuildMaster variable).

.OUTPUTS
  PSCustomObject: Status (Passed, Failed), Tier, Mode, Attempt, BindingSha256, EvidencePath,
  CapturePath, CaptureSha256, VerdictPath, VerdictSha256, FailedChecks, SqlErrorNumber.

.EXAMPLE
  Invoke-DatabaseMaintenanceWindow -Tier Development -Mode PrecheckOnly -BindingPath $b -ExpectedBindingSha256 $h

.NOTES
  AI assisted using Powershell.instructions.md as guidelines. DB-Runner-S1-Foundation.

.LINK
  Start-DatabaseMaintenanceWindow.ps1
#>
function Invoke-DatabaseMaintenanceWindow {
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)][ValidateSet('Development', 'Integration', 'QA', 'Production')][string]$Tier,
    [Parameter(Mandatory)][ValidateSet('PrecheckOnly', 'BackupOnly', 'Full', 'DropClone')][string]$Mode,
    [Parameter(Mandatory)][string]$BindingPath,
    [Parameter(Mandatory)][ValidatePattern('\A[0-9a-fA-F]{64}\z')][string]$ExpectedBindingSha256
  )

  begin {
    $fn = 'Invoke-DatabaseMaintenanceWindow'
    $mn = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Function started (Tier=$Tier, Mode=$Mode)"
  }

  process {
    if ($Mode -cne 'PrecheckOnly') { throw "MaintenanceWindowModeNotImplemented|$Mode" }

    # 1-4. Everything that can refuse before SQL.
    $checked = Assert-MaintenanceWindowBinding -BindingPath $BindingPath -ExpectedSha256 $ExpectedBindingSha256 -Tier $Tier -Mode $Mode
    $binding = $checked.Binding
    $resources = Assert-MaintenanceWindowResources
    $dependency = Assert-MaintenanceWindowDependency -ExpectedVersion ([string]$binding.databaseManagementVersion)
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    try { $runnerSid = $identity.User.Value } finally { $identity.Dispose() }
    if ($runnerSid -cne [string]$binding.expectedSid) { throw "MaintenanceWindowRunnerIdentityMismatch|$runnerSid" }

    # 5. A fresh evidence folder per run.
    $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
    $evidence = Join-Path ([string]$binding.evidenceRoot) (Join-Path ([string]$binding.attempt) ('PrecheckOnly-' + $stamp))
    if (Test-Path -LiteralPath $evidence) { throw "MaintenanceWindowEvidenceExists|$evidence" }

    $result = [ordered]@{
      Status = 'NotRun'; Tier = $Tier; Mode = $Mode; Attempt = [string]$binding.attempt; BindingSha256 = $checked.BindingSha256
      EvidencePath = $evidence; CapturePath = $null; CaptureSha256 = $null; VerdictPath = $null; VerdictSha256 = $null
      FailedChecks = @(); SqlErrorNumber = $null
    }
    if (-not $PSCmdlet.ShouldProcess("$($checked.TierMap.SqlInstance)/master", 'Run the read-only LF maintenance window precheck')) {
      $result.Status = 'ProposedOnly'
      return [pscustomobject]$result
    }
    $null = New-Item -ItemType Directory -Path $evidence -Force:$false -ErrorAction Stop

    $sqlPath = Join-Path (Get-MaintenanceWindowModuleRoot) 'Resources\MaintenanceWindow\WindowPrecheck.sql'
    $sqlText = [IO.File]::ReadAllText($sqlPath)
    $sidBytes = [byte[]]::new(([Security.Principal.SecurityIdentifier]::new([string]$binding.expectedSid)).BinaryLength)
    ([Security.Principal.SecurityIdentifier]::new([string]$binding.expectedSid)).GetBinaryForm($sidBytes, 0)
    $parameters = [ordered]@{
      ExpectedMachine  = $checked.TierMap.MachineName
      ExpectedInstance = $checked.TierMap.InstanceName
      ExpectedLogin    = [string]$binding.expectedLogin
      ExpectedSid      = $sidBytes
      Catalog          = $checked.TierMap.Catalog
      CloneName        = [string]$binding.cloneName
      ClonePrefix      = $checked.ClonePrefix
      CloneDataPath    = [string]$binding.cloneDataPath
      CloneLogPath     = [string]$binding.cloneLogPath
      RehearsalName    = $checked.RehearsalName
    }
    $started = [DateTimeOffset]::UtcNow
    $capture = Invoke-MaintenanceSqlDataSet -SqlInstance $checked.TierMap.SqlInstance -Database 'master' -CommandText $sqlText -Parameters $parameters `
      -SqlClientPath ([string]$binding.sqlClient.path) -ExpectedSqlClientSha256 ([string]$binding.sqlClient.sha256) -ApplicationName ("ATAP.MaintenanceWindow.$Tier.$($binding.attempt).PrecheckOnly")

    $document = [ordered]@{
      Kind = 'Coordination-database-maintenance-capture-v1'; Step = 'WindowPrecheck'; OperationSet = [string]$binding.OperationSet.Name; Tier = $Tier; Attempt = [string]$binding.attempt
      SqlInstance = $checked.TierMap.SqlInstance; Catalog = $checked.TierMap.Catalog; BuildId = [string]$binding.buildId
      PackageSha256 = [string]$binding.packageSha256; BindingSha256 = $checked.BindingSha256; RunnerSid = $runnerSid
      SqlSha256 = $resources['Resources\MaintenanceWindow\WindowPrecheck.sql']; Status = $capture.Status; SqlErrorNumber = $capture.SqlErrorNumber
      SqlErrors = $capture.SqlErrors; StartedUtc = $started.ToString('o'); CompletedUtc = [DateTimeOffset]::UtcNow.ToString('o')
      ReadOnly = $true; SQLWrites = 0; ResultSets = $capture.ResultSets
    }
    $captureFile = Write-MaintenanceWindowEvidenceFile -Path (Join-Path $evidence 'WindowPrecheck.Capture.json') -Text (ConvertTo-MaintenanceWindowCaptureJson -Document $document) -Confirm:$false
    $verdict = Test-MaintenanceWindowPrecheckResult -Capture $capture -Binding $binding -RehearsalName $checked.RehearsalName
    $verdictDoc = [ordered]@{
      Kind = 'Coordination-database-maintenance-precheck-verdict-v1'; Status = $verdict.Status; Tier = $Tier; Attempt = [string]$binding.attempt
      SqlInstance = $checked.TierMap.SqlInstance; Catalog = $checked.TierMap.Catalog; BuildId = [string]$binding.buildId
      BindingSha256 = $checked.BindingSha256; CaptureSha256 = $captureFile.Sha256; DependencyModuleBase = $dependency.ModuleBase
      Checks = $verdict.Checks; FailedChecks = $verdict.FailedChecks; SqlErrorNumber = $verdict.SqlErrorNumber
      SourceDataBytes = $verdict.SourceDataBytes; SourceLogBytes = $verdict.SourceLogBytes; DriveFreeBytes = $verdict.DriveFreeBytes
      ResourcePins = $resources; CompletedUtc = [DateTimeOffset]::UtcNow.ToString('o')
    }
    $verdictFile = Write-MaintenanceWindowEvidenceFile -Path (Join-Path $evidence 'WindowPrecheck.Verdict.json') -Text (($verdictDoc | ConvertTo-Json -Depth 8).Replace("`r`n", "`n")) -Confirm:$false

    $result.Status = $verdict.Status
    $result.CapturePath = $captureFile.Path; $result.CaptureSha256 = $captureFile.Sha256
    $result.VerdictPath = $verdictFile.Path; $result.VerdictSha256 = $verdictFile.Sha256
    $result.FailedChecks = $verdict.FailedChecks; $result.SqlErrorNumber = $verdict.SqlErrorNumber
    $level = if ($verdict.Status -ceq 'Passed') { 'Important' } else { 'Error' }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level $level -Message "LF maintenance precheck $($verdict.Status) for $Tier $($binding.attempt): $($verdict.FailedChecks -join ', ')"
    [pscustomobject]$result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

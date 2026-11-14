[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
  [string]$BindingPath,
  [string]$ExpectedBindingSha256,
  [string]$AttestationPath,
  [string]$ExpectedAttestationSha256,
  [string]$NupkgPath,
  [string]$OperationId,
  [string]$EvidencePath,
  [int]$StopTimeoutSeconds = 300,
  [string]$AdoptStopFileOfOperationId,
  [switch]$LauncherReinstallPlanned
)

# Custodian upgrade orchestration (0.1.17 slice 8). Runs as the custodian after the broker
# install and installed proof of a new version:
#   preconditions (the NEW package is verified as bytes by the CURRENTLY ADMITTED module before
#   anything of it is imported, run or written; the candidate is never imported)
#   -> stop file + bounded wait for the resident's boundary exit (never kill)
#   -> the admitted version's Invoke-CoordCustodyHandoff -Mode ApplyPackage -CandidateModuleRoot
#   -> Upgraded: remove stop file, start the unchanged task | NotNow: same, old version stays
#      | Held (trust or uncertainty): leave stopped
#   -> one receipt under the caller's evidence folder.
# Task Scheduler is touched only through Get-CoordUpgradeTaskState and Start-CoordUpgradeTask
# (read and start of the existing task). It never registers, unregisters, ends or kills a task.

function Get-CoordUpgradeSha256([byte[]]$Bytes) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)) }

function Get-CoordUpgradeTaskState {
  # Read-only view of the existing resident task. Injectable: tests mock this function.
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$TaskPath, [Parameter(Mandatory)][string]$TaskName)
  $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
  if ($null -eq $task) { return [pscustomobject]@{ Exists = $false; State = 'Absent'; Enabled = $false; DefinitionSha256 = $null } }
  $xml = Export-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
  [pscustomobject]@{ Exists = $true; State = [string]$task.State; Enabled = ([string]$task.State -cne 'Disabled')
    DefinitionSha256 = Get-CoordUpgradeSha256 ([Text.Encoding]::UTF8.GetBytes($xml)) }
}

function Start-CoordUpgradeTask {
  # Starts the existing, unchanged task. Injectable: tests mock this function.
  [CmdletBinding(SupportsShouldProcess)]
  param([Parameter(Mandatory)][string]$TaskPath, [Parameter(Mandatory)][string]$TaskName)
  if ($PSCmdlet.ShouldProcess($TaskPath + $TaskName, 'Start existing resident task')) { Start-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop }
}

function Test-CoordUpgradeLeaseHeld {
  # The resident holds its lifetime lease exclusively while it runs (slice 6 host).
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$LeasePath)
  if (-not [IO.File]::Exists($LeasePath)) { return $false }
  try { $probe = [IO.File]::Open($LeasePath, 'Open', 'ReadWrite', 'None'); $probe.Dispose(); $false } catch [IO.IOException] { $true }
}

function Wait-CoordUpgradeResidentStop {
  # Bounded wait for a boundary exit. Never ends or kills the task or process.
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$TaskPath, [Parameter(Mandatory)][string]$TaskName, [Parameter(Mandatory)][string]$LeasePath,
    [Parameter(Mandatory)][int]$TimeoutSeconds, [int]$PollMilliseconds = 1000)
  $clock = [Diagnostics.Stopwatch]::StartNew()
  while ($true) {
    $state = Get-CoordUpgradeTaskState -TaskPath $TaskPath -TaskName $TaskName
    if ($state.State -cne 'Running' -and -not (Test-CoordUpgradeLeaseHeld -LeasePath $LeasePath)) { return [pscustomobject]@{ Stopped = $true; WaitedMilliseconds = $clock.ElapsedMilliseconds } }
    if ($clock.Elapsed.TotalSeconds -ge $TimeoutSeconds) { return [pscustomobject]@{ Stopped = $false; WaitedMilliseconds = $clock.ElapsedMilliseconds } }
    Start-Sleep -Milliseconds $PollMilliseconds
  }
}

function Get-CoordUpgradeOutcome {
  # Classifies an ApplyPackage refusal from the STRUCTURED values Invoke-CoordCustodyHandoff puts in the
  # thrown exception's Data (CoordPackageCode, CoordPackageClass, CoordPackageConsumed,
  # CoordPackagePolicyDisable, CoordPackageHoldMarker). Message text is never parsed. An exception
  # without structured data (or with malformed values) is Held, unclassified, with unknown consumption.
  [CmdletBinding()]
  param([AllowNull()][Exception]$Exception)
  $data = if ($null -ne $Exception) { $Exception.Data } else { $null }
  $text = { param($key) if ($null -ne $data -and $data.Contains($key) -and $data[$key] -is [string] -and $data[$key] -cmatch '\A[A-Za-z][A-Za-z0-9_]{0,127}\z') { [string]$data[$key] } else { $null } }
  $code = & $text 'CoordPackageCode'
  $class = & $text 'CoordPackageClass'
  $consumed = if ($null -ne $data -and $data.Contains('CoordPackageConsumed') -and $data['CoordPackageConsumed'] -is [bool]) { [bool]$data['CoordPackageConsumed'] } else { $null }
  $structured = ($null -ne $code -and $null -ne $class -and $null -ne $consumed)
  [pscustomobject]@{
    Class = $(if ($structured -and $class -ceq 'NotNow' -and -not $consumed) { 'NotNow' } else { 'Held' })
    Code = $(if ($code) { $code } else { 'UnclassifiedApplyFailure' })
    Consumed = $consumed
    PolicyDisable = (& $text 'CoordPackagePolicyDisable')
    HoldMarker = (& $text 'CoordPackageHoldMarker')
    Structured = $structured
  }
}

function Get-CoordUpgradeInstallCount {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Version, [Parameter(Mandatory)][string]$ModulesRoot)
  $name = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
  $roots = @(@($ModulesRoot) + @($env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ })) | ForEach-Object { [IO.Path]::GetFullPath($_).TrimEnd('\') } | Select-Object -Unique
  $installs = @($roots | ForEach-Object { Join-Path $_ (Join-Path $name (Join-Path $Version ($name + '.psd1'))) } | Where-Object { [IO.File]::Exists($_) } | ForEach-Object { [IO.Path]::GetDirectoryName($_) } | Select-Object -Unique)
  $allUsers = [IO.Path]::GetFullPath((Join-Path $ModulesRoot (Join-Path $name $Version)))
  [pscustomobject]@{ Count = $installs.Count; InAllUsers = ($installs -icontains $allUsers); Root = $allUsers }
}

function Get-CoordUpgradeLauncherCheck {
  # A wrapper, so the launcher's own script parameters bind here and never in the caller. The launcher file is read from
  # the currently ADMITTED module's root; only its function definitions are used (nothing from the candidate runs).
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$ModuleRoot, [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$CandidateFiles,
    [Parameter(Mandatory)][string]$InstalledLauncherPath, [switch]$LauncherReinstallPlanned)
  . (Join-Path $ModuleRoot 'Resources\Resident\Start-CoordClerkResident.ps1')
  Test-CoordLauncherUpgradeCompatibility -CandidateFiles $CandidateFiles -InstalledLauncherPath $InstalledLauncherPath -LauncherReinstallPlanned:$LauncherReinstallPlanned
}

function Resolve-CoordUpgradeHandoffCommand {
  # Production path: the handoff command of the CURRENTLY ADMITTED version (the one custody names), from
  # its AllUsers install. The candidate is never imported: it is only verified, by this module, as bytes.
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$InstallRoot, [Parameter(Mandatory)][string]$AdmittedVersion)
  $name = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
  $manifest = Join-Path $InstallRoot ($name + '.psd1')
  if (-not [IO.File]::Exists($manifest)) { throw 'UpgradeAdmittedModuleUnavailable' }
  $root = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
  # Any other copy of this module already loaded (for example the candidate) refuses the run.
  $foreign = @(Get-Module -Name $name -All | Where-Object { [IO.Path]::GetFullPath($_.ModuleBase).TrimEnd('\') -ine $root })
  if ($foreign.Count) { throw 'UpgradeUnexpectedModuleLoaded' }
  $module = Import-Module -Name $manifest -PassThru -ErrorAction Stop
  if ([string]$module.Version -cne $AdmittedVersion) { throw 'UpgradeAdmittedModuleVersionMismatch' }
  Get-Command -Name Invoke-CoordCustodyHandoff -Module $module.Name -ErrorAction Stop | Where-Object { $_.Module.Path -ieq $module.Path } | Select-Object -First 1
}

function Invoke-CoordPackageUpgrade {
  <#
  .SYNOPSIS
    Stops the resident at a boundary, admits the attested package only, and restarts the unchanged task.
  .DESCRIPTION
    Custodian-run orchestration of one package-only upgrade. Preconditions are checked
    before anything is written. The resident is asked to stop through its descriptor's stop
    file and waited for (bounded); it is never killed. Invoke-CoordCustodyHandoff
    -Mode ApplyPackage performs the only custody write. On success or a NotNow refusal the
    stop file this run created is removed and the existing task is started; with the stable
    launcher it resolves the custody-admitted version, so nothing is re-registered. On a
    trust-class failure or a stop timeout the resident is left stopped (Held). One receipt
    is written under -EvidencePath in every outcome after preconditions pass.
  .PARAMETER BindingPath
    The resident's v2 descriptor (its stop, lease and custody paths are used).
  .PARAMETER ExpectedBindingSha256
    Exact descriptor bytes; also re-checked after the upgrade.
  .PARAMETER AttestationPath
    Coordination-package-attestation-v1 for the new version.
  .PARAMETER ExpectedAttestationSha256
    Independently supplied digest of the attestation file.
  .PARAMETER NupkgPath
    The installed version's archive, passed to ApplyPackage.
  .PARAMETER OperationId
    Fresh GUID for the ApplyPackage operation.
  .PARAMETER EvidencePath
    Existing folder for the receipt.
  .PARAMETER StopTimeoutSeconds
    Bound on the wait for a boundary exit; on timeout the run refuses and holds.
  .PARAMETER TaskPath
    Existing resident task folder.
  .PARAMETER TaskName
    Existing resident task name.
  .PARAMETER ModulesRoot
    AllUsers module root (fixed in production; a parameter for disposable tests).
  .PARAMETER HandoffCommand
    Test seam: the Invoke-CoordCustodyHandoff command to call. Production resolves it from
    the CURRENTLY ADMITTED version's AllUsers install (the version custody names), never the
    candidate; its module must differ from the candidate's root, and the receipt records its
    module path. That module's Test-CoordPackageAttestation verifies the new install root
    before the stop file is written or anything else happens.
  .PARAMETER AdoptStopFileOfOperationId
    A stop file whose content is 'package-upgrade <this OperationId>' is this run's own earlier
    stop file (a crashed run): it is adopted and removed on success, so the resident restarts. A
    stop file recorded by a DIFFERENT upgrade operation is refused unless that exact operation id
    is supplied here. Any other stop file is the operator's and is preserved.
  .OUTPUTS
    Status (Upgraded, NotNow, Held, Refused, ProposedOnly), reason and receipt path/hash.
  .EXAMPLE
    Invoke-CoordPackageUpgrade -BindingPath $d -ExpectedBindingSha256 $h -AttestationPath $a -ExpectedAttestationSha256 $ah -NupkgPath $n -OperationId $id -EvidencePath $e -WhatIf
  .NOTES
    Never registers, unregisters, ends or kills a task; never edits the descriptor.
  .LINK
    Start-CoordClerkResident.ps1
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  param(
    [Parameter(Mandatory)][string]$BindingPath,
    [Parameter(Mandatory)][ValidatePattern('\A[0-9a-fA-F]{64}\z')][string]$ExpectedBindingSha256,
    [Parameter(Mandatory)][string]$AttestationPath,
    [Parameter(Mandatory)][ValidatePattern('\A[0-9a-fA-F]{64}\z')][string]$ExpectedAttestationSha256,
    [Parameter(Mandatory)][string]$NupkgPath,
    [Parameter(Mandatory)][string]$OperationId,
    [Parameter(Mandatory)][string]$EvidencePath,
    [ValidateRange(1, 3600)][int]$StopTimeoutSeconds = 300,
    [string]$TaskPath = '\ATAP\Orchestration\',
    [string]$TaskName = 'CoordClerkResident',
    [string]$ModulesRoot = 'C:\Program Files\PowerShell\Modules',
    [Management.Automation.CommandInfo]$HandoffCommand,
    [ValidateRange(10, 60000)][int]$PollMilliseconds = 1000,
    [ValidatePattern('\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z')][string]$AdoptStopFileOfOperationId,
    [string]$InstalledLauncherPath = 'C:\Program Files\ATAP\Orchestration\Start-CoordClerkResident.ps1',
    [switch]$LauncherReinstallPlanned
  )
  begin { $fn = 'Invoke-CoordPackageUpgrade'; $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell' }
  process {
    $now = { [DateTimeOffset]::UtcNow.ToString('o') }
    $refuse = { param($code, $detail = $null) Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message ('Package upgrade refused before any write: ' + $code + $(if ($detail) { ' (' + $detail + ')' })); [pscustomobject]@{ Status = 'Refused'; Reason = $code; Detail = $detail; ReceiptPath = $null; ReceiptSha256 = $null; Receipt = $null } }

    # 1. Preconditions. Nothing is written until all pass.
    $guid = [guid]::Empty
    if (-not [guid]::TryParseExact($OperationId, 'D', [ref]$guid) -or $guid.ToString('D') -cne $OperationId) { return & $refuse 'UpgradeOperationIdInvalid' }
    if (-not [IO.Directory]::Exists($EvidencePath)) { return & $refuse 'UpgradeEvidencePathRequired' }
    $receiptPath = Join-Path ([IO.Path]::GetFullPath($EvidencePath)) ('package-upgrade-' + $OperationId + '.receipt.json')
    if ([IO.File]::Exists($receiptPath)) { return & $refuse 'UpgradeReceiptExists' }
    if (-not [IO.File]::Exists($BindingPath)) { return & $refuse 'UpgradeDescriptorMissing' }
    $descriptorBytes = [IO.File]::ReadAllBytes($BindingPath)
    if ((Get-CoordUpgradeSha256 $descriptorBytes) -ine $ExpectedBindingSha256) { return & $refuse 'UpgradeDescriptorChanged' }
    try { $descriptor = [Text.Encoding]::UTF8.GetString($descriptorBytes) | ConvertFrom-Json -AsHashtable } catch { return & $refuse 'UpgradeDescriptorInvalid' }
    if ($descriptor.schemaVersion -cne 'CoordResidentStartup-v2' -or -not $descriptor.stopPath -or -not $descriptor.leasePath -or -not $descriptor.custodyPath) { return & $refuse 'UpgradeDescriptorInvalid' }
    $stopPath = [IO.Path]::GetFullPath($descriptor.stopPath); $leasePath = [IO.Path]::GetFullPath($descriptor.leasePath); $custodyPath = [IO.Path]::GetFullPath($descriptor.custodyPath)
    if (-not [IO.File]::Exists($AttestationPath)) { return & $refuse 'UpgradeAttestationMissing' }
    $attestationBytes = [IO.File]::ReadAllBytes($AttestationPath)
    $attestationSha = Get-CoordUpgradeSha256 $attestationBytes
    if ($attestationSha -ine $ExpectedAttestationSha256) { return & $refuse 'UpgradeAttestationPinMismatch' }
    try { $attestationDoc = [Text.Encoding]::UTF8.GetString($attestationBytes) | ConvertFrom-Json -AsHashtable; $newVersion = [string]$attestationDoc.moduleVersion } catch { return & $refuse 'UpgradeAttestationInvalid' }
    if ($newVersion -cnotmatch '\A[0-9]+\.[0-9]+\.[0-9]+\z') { return & $refuse 'UpgradeAttestationInvalid' }
    $install = Get-CoordUpgradeInstallCount -Version $newVersion -ModulesRoot $ModulesRoot
    if ($install.Count -ne 1 -or -not $install.InAllUsers) { return & $refuse 'UpgradeNewVersionNotInstalledOnce' }
    try { $custodyBefore = [string]((Get-Content -LiteralPath $custodyPath -Raw | ConvertFrom-Json -AsHashtable).package.moduleVersion) } catch { return & $refuse 'UpgradeCustodyUnreadable' }
    if ($custodyBefore -cnotmatch '\A[0-9]+\.[0-9]+\.[0-9]+\z') { return & $refuse 'UpgradeCustodyUnreadable' }
    if ($custodyBefore -ceq $newVersion) { return & $refuse 'UpgradeAlreadyAtVersion' }
    # H1: ApplyPackage runs from the CURRENTLY ADMITTED version, never the candidate.
    $injected = [bool]$HandoffCommand
    if (-not $injected) {
      $admittedRoot = Join-Path $ModulesRoot (Join-Path 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell' $custodyBefore)
      try { $HandoffCommand = Resolve-CoordUpgradeHandoffCommand -InstallRoot $admittedRoot -AdmittedVersion $custodyBefore } catch { return & $refuse 'UpgradeHandoffUnavailable' $_.Exception.Message }
    }
    if ($null -eq $HandoffCommand -or $null -eq $HandoffCommand.Module) { return & $refuse 'UpgradeHandoffModuleMismatch' }
    if (-not $injected -and [string]$HandoffCommand.Module.Version -cne $custodyBefore) { return & $refuse 'UpgradeHandoffModuleMismatch' }
    $admittedModule = $HandoffCommand.Module
    if ([IO.Path]::GetFullPath($admittedModule.ModuleBase).TrimEnd('\') -ieq [IO.Path]::GetFullPath($install.Root).TrimEnd('\')) { return & $refuse 'UpgradeHandoffFromCandidate' }
    # H1: the new package is verified, as bytes, by the admitted module's own verifier pointed at the new
    # install root. This is before any import of, or dot-source from, the candidate, and before any write.
    $preVerdict = $null
    try {
      $custodyBytes = [IO.File]::ReadAllBytes($custodyPath)
      $preVerdict = & $admittedModule {
        param($Root, $AttPath, $Bytes, $Nupkg, $Current)
        $policy = [pscustomobject](ConvertFrom-CoordElement ((Read-CoordJsonBytes $Bytes).GetProperty('autoPackageAdmission')))
        Test-CoordPackageAttestation -ModuleRoot $Root -AttestationPath $AttPath -Policy $policy -NupkgPath $Nupkg -CurrentVersion $Current
      } $install.Root $AttestationPath $custodyBytes $NupkgPath $custodyBefore
    } catch { return & $refuse 'UpgradeNewPackageNotVerified' ('VerifierFailed:' + $_.Exception.GetType().Name) }
    if ($null -eq $preVerdict -or $preVerdict.Valid -isnot [bool] -or -not $preVerdict.Valid) { return & $refuse 'UpgradeNewPackageNotVerified' ('Reason:' + [string]$preVerdict.ReasonCode) }
    # M1: a candidate that changes the bundled launcher would strand the resident behind the fixed-path launcher
    # (LauncherSelfNotAdmitted) unless the plan re-installs it. Checked by the admitted module's own function,
    # after the candidate is verified and before any custody write, stop file or resident stop. Pure and read-only.
    try {
      $launcherCheck = Get-CoordUpgradeLauncherCheck -ModuleRoot $admittedModule.ModuleBase -CandidateFiles @($attestationDoc.files) -InstalledLauncherPath $InstalledLauncherPath -LauncherReinstallPlanned:$LauncherReinstallPlanned
    } catch { return & $refuse 'UpgradeLauncherCheckUnavailable' ('CheckFailed:' + $_.Exception.GetType().Name) }
    if ($null -eq $launcherCheck -or $launcherCheck.Status -cnotin @('Compatible', 'Refused') -or [string]$launcherCheck.Reason -cnotmatch '\A[A-Za-z][A-Za-z0-9]{0,63}\z') { return & $refuse 'UpgradeLauncherCheckUnavailable' 'CheckReturnedNoVerdict' }
    if ($launcherCheck.Status -ceq 'Refused') {
      $code = 'Upgrade' + [string]$launcherCheck.Reason
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message ('Package upgrade not now, nothing written: ' + $code)
      return [pscustomobject]@{ Status = 'NotNow'; Reason = $code; Detail = $null; ReceiptPath = $null; ReceiptSha256 = $null; Receipt = $null }
    }
    # M7: recognize this operation's own earlier stop file (a crashed run); preserve an operator's.
    $stopOwnership = 'None'
    $stopRecordedOperation = $null
    if ([IO.File]::Exists($stopPath)) {
      try { $stopText = [IO.File]::ReadAllText($stopPath) } catch { $stopText = '' }
      $recorded = [regex]::Match([string]$stopText, '\Apackage-upgrade ([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\z')
      if (-not $recorded.Success) { $stopOwnership = 'OperatorOwned' }
      else {
        $stopRecordedOperation = $recorded.Groups[1].Value
        if ($stopRecordedOperation -ceq $OperationId) { $stopOwnership = 'OwnPreviousRun' }
        elseif ($AdoptStopFileOfOperationId -and $AdoptStopFileOfOperationId -ceq $stopRecordedOperation) { $stopOwnership = 'AdoptedConfirmed' }
        else { return & $refuse 'UpgradeStrandedStopFileFromOtherOperation' }
      }
    }
    $taskBefore = Get-CoordUpgradeTaskState -TaskPath $TaskPath -TaskName $TaskName
    if (-not $PSCmdlet.ShouldProcess($OperationId, "Stop resident, admit package $newVersion, restart unchanged task")) {
      return [pscustomobject]@{ Status = 'ProposedOnly'; Reason = 'NotStarted'; ReceiptPath = $null; ReceiptSha256 = $null; Receipt = $null }
    }

    $receipt = [ordered]@{
      kind = 'Coordination-package-upgrade-receipt-v1'; operationId = $OperationId; startedUtc = (& $now)
      custodyVersionBefore = $custodyBefore; newVersion = $newVersion; custodyVersionAfter = $null
      attestationSha256 = $attestationSha; handoffModulePath = $HandoffCommand.Module.Path
      preVerification = [ordered]@{ performedByAdmittedModule = $true; candidateRoot = $install.Root; valid = $true; reasonCode = [string]$preVerdict.ReasonCode }
      descriptorPath = [IO.Path]::GetFullPath($BindingPath); descriptorSha256Before = (Get-CoordUpgradeSha256 $descriptorBytes); descriptorSha256After = $null; descriptorUnchanged = $null
      task = [ordered]@{ path = $TaskPath; name = $TaskName; existedBefore = [bool]$taskBefore.Exists; stateBefore = [string]$taskBefore.State
        definitionSha256Before = $taskBefore.DefinitionSha256; definitionSha256After = $null; definitionUnchanged = $null }
      stop = [ordered]@{ stopPath = $stopPath; preexisting = ($stopOwnership -ceq 'OperatorOwned'); ownership = $stopOwnership; recordedOperationId = $stopRecordedOperation; residentRunning = $null; requestedUtc = $null; stoppedUtc = $null; waitedMilliseconds = $null; timeoutSeconds = $StopTimeoutSeconds }
      apply = [ordered]@{ called = $false; status = $null; outcomeClass = $null; code = $null; consumed = $null; policyDisable = $null; holdMarker = $null; structured = $null; receiptPath = $null; receiptSha256 = $null }
      hold = [ordered]@{ policyDisableConfirmed = $null; fence = $null }
      restart = [ordered]@{ stopFileRemoved = $false; startRequested = $false; startedUtc = $null; skippedReason = $null }
      status = $null; reason = $null; completedUtc = $null
    }
    $created = $false
    try {
      # 2. Ask the resident to stop at its next boundary and wait, bounded. Never kill.
      $receipt.stop.residentRunning = ([string]$taskBefore.State -ceq 'Running') -or (Test-CoordUpgradeLeaseHeld -LeasePath $leasePath)
      if ($stopOwnership -ceq 'None') {
        # Content is written to a temp file first and moved into place, so a crash can never leave an
        # empty stop file that a retry would mistake for the operator's. Move refuses an existing target.
        $stopTemp = $stopPath + '.' + $OperationId + '.tmp'
        try {
          $stream = [IO.File]::Open($stopTemp, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
          try { $bytes = [Text.Encoding]::UTF8.GetBytes('package-upgrade ' + $OperationId); $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
          [IO.File]::Move($stopTemp, $stopPath)
        } finally { if ([IO.File]::Exists($stopTemp)) { [IO.File]::Delete($stopTemp) } }
        $created = $true
      }
      $receipt.stop.requestedUtc = & $now
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message ('Stop requested for package upgrade ' + $OperationId + '; waiting for a boundary exit.')
      $wait = Wait-CoordUpgradeResidentStop -TaskPath $TaskPath -TaskName $TaskName -LeasePath $leasePath -TimeoutSeconds $StopTimeoutSeconds -PollMilliseconds $PollMilliseconds
      $receipt.stop.waitedMilliseconds = $wait.WaitedMilliseconds
      if (-not $wait.Stopped) {
        # Hold: the stop file stays so the resident stops at its next boundary; custody untouched.
        $receipt.status = 'Held'; $receipt.reason = 'UpgradeStopTimeout'
        $receipt.restart.skippedReason = 'StopTimeoutHeld'
      } else {
      $receipt.stop.stoppedUtc = & $now

      # 3. The only custody write: slice 2 ApplyPackage.
      $receipt.apply.called = $true
      try {
        $applied = & $HandoffCommand -Mode ApplyPackage -OperationId $OperationId -AttestationPath $AttestationPath -ExpectedAttestationSha256 $ExpectedAttestationSha256 -NupkgPath $NupkgPath -CandidateModuleRoot $install.Root -Confirm:$false
        $receipt.apply.status = [string]$applied.Status
        if ($applied.Status -ceq 'PackageAdmitted') {
          $receipt.apply.outcomeClass = 'Admitted'; $receipt.apply.code = 'PackageAdmitted'
          $receipt.apply.receiptPath = [string]$applied.ReceiptPath; $receipt.apply.receiptSha256 = [string]$applied.ReceiptSha256
        } else { $receipt.apply.outcomeClass = 'Held'; $receipt.apply.code = 'UnexpectedApplyStatus' }
      } catch {
        $outcome = Get-CoordUpgradeOutcome -Exception $_.Exception
        $receipt.apply.status = 'Refused'; $receipt.apply.outcomeClass = $outcome.Class; $receipt.apply.code = $outcome.Code
        $receipt.apply.consumed = $outcome.Consumed; $receipt.apply.policyDisable = $outcome.PolicyDisable
        $receipt.apply.holdMarker = $outcome.HoldMarker; $receipt.apply.structured = $outcome.Structured
      }

      # 4. Restart only after Admitted or NotNow, and only an unchanged task and descriptor.
      $taskNow = Get-CoordUpgradeTaskState -TaskPath $TaskPath -TaskName $TaskName
      $receipt.task.definitionSha256After = $taskNow.DefinitionSha256
      $receipt.task.definitionUnchanged = ([string]$taskNow.DefinitionSha256 -ceq [string]$taskBefore.DefinitionSha256) -and ([bool]$taskNow.Exists -eq [bool]$taskBefore.Exists)
      $receipt.descriptorSha256After = Get-CoordUpgradeSha256 ([IO.File]::ReadAllBytes($BindingPath))
      $receipt.descriptorUnchanged = $receipt.descriptorSha256After -ceq $receipt.descriptorSha256Before
      if ($receipt.apply.outcomeClass -cin @('Admitted', 'NotNow')) {
        $receipt.status = if ($receipt.apply.outcomeClass -ceq 'Admitted') { 'Upgraded' } else { 'NotNow' }
        $receipt.reason = $receipt.apply.code
        if (-not $receipt.task.definitionUnchanged -or -not $receipt.descriptorUnchanged) {
          $receipt.status = 'Held'; $receipt.reason = 'UpgradeTaskOrDescriptorChanged'; $receipt.restart.skippedReason = 'TaskOrDescriptorChanged'
        } elseif ($receipt.stop.preexisting) {
          $receipt.restart.skippedReason = 'OperatorStopFilePreserved'
        } else {
          [IO.File]::Delete($stopPath); $created = $false; $receipt.restart.stopFileRemoved = $true
          if ($taskNow.Exists -and $taskNow.Enabled) {
            Start-CoordUpgradeTask -TaskPath $TaskPath -TaskName $TaskName -Confirm:$false
            $receipt.restart.startRequested = $true; $receipt.restart.startedUtc = & $now
          } else { $receipt.restart.skippedReason = $(if ($taskNow.Exists) { 'TaskDisabled' } else { 'TaskAbsent' }) }
        }
      } else {
        $receipt.status = 'Held'; $receipt.reason = $receipt.apply.code; $receipt.restart.skippedReason = 'HeldAfterApplyRefusal'
        # M6: a Held refusal must show that the policy was switched off. If that is not confirmed, say so
        # explicitly: the resident stays stopped (fenced) and the handoff has left its hold marker.
        if ($receipt.apply.status -ceq 'Refused') {
          $disable = [string]$receipt.apply.policyDisable
          if ($disable -cin @('Disabled', 'AlreadyDisabled')) { $receipt.hold.policyDisableConfirmed = $true }
          elseif ($disable -cin @('NotDisabled_NotNowRefusal', 'NotAttempted')) { $receipt.hold.policyDisableConfirmed = $null }  # nothing was trusted or consumed, so nothing needed disabling
          else {
            # Unsafe, failed or unknown (including missing structured data): never silent.
            $receipt.hold.policyDisableConfirmed = $false
            $receipt.hold.fence = 'PolicyDisableNotConfirmed_HeldFenced'
            $receipt.reason = 'PolicyDisableNotConfirmed_HeldFenced'
          }
        }
      }
      }
    } catch {
      $receipt.status = 'Held'; $receipt.reason = 'UpgradeOrchestrationFailed'
      $receipt.restart.skippedReason = 'OrchestrationFailure'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message ('Package upgrade orchestration failed and holds: ' + $_.Exception.Message)
    } finally {
      try { $receipt.custodyVersionAfter = [string]((Get-Content -LiteralPath $custodyPath -Raw | ConvertFrom-Json -AsHashtable).package.moduleVersion) } catch { $receipt.custodyVersionAfter = 'Unreadable' }
      $receipt.completedUtc = & $now
      $json = [Text.Encoding]::UTF8.GetBytes((($receipt | ConvertTo-Json -Depth 10) -replace "`r`n", "`n"))
      $out = [IO.File]::Open($receiptPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
      try { $out.Write($json, 0, $json.Length); $out.Flush($true) } finally { $out.Dispose() }
      $level = if ($receipt.status -cin @('Upgraded', 'NotNow')) { 'Important' } else { 'Error' }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level $level -Message ('Package upgrade ' + $OperationId + ': ' + $receipt.status + ' (' + $receipt.reason + ').')
    }
    [pscustomobject]@{ Status = $receipt.status; Reason = $receipt.reason; ReceiptPath = $receiptPath; ReceiptSha256 = (Get-CoordUpgradeSha256 ([IO.File]::ReadAllBytes($receiptPath))); Receipt = $receipt }
  }
  end {}
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  $adopt = @{}
  if ($PSBoundParameters.ContainsKey('AdoptStopFileOfOperationId')) { $adopt.AdoptStopFileOfOperationId = $AdoptStopFileOfOperationId }
  $upgrade = Invoke-CoordPackageUpgrade -BindingPath $BindingPath -ExpectedBindingSha256 $ExpectedBindingSha256 -AttestationPath $AttestationPath `
    -ExpectedAttestationSha256 $ExpectedAttestationSha256 -NupkgPath $NupkgPath -OperationId $OperationId -EvidencePath $EvidencePath -StopTimeoutSeconds $StopTimeoutSeconds -LauncherReinstallPlanned:$LauncherReinstallPlanned @adopt
  $upgrade | ConvertTo-Json -Depth 12 -Compress
  if ($upgrade.Status -cnotin @('Upgraded', 'NotNow')) { exit 3 }
}

#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

# Slice 8 (0.1.17): custodian package-upgrade orchestration, end to end on disposable fixtures.
# Each fixture builds protected custody, state, recovery history and a board quartet under a
# unique per-run folder in the approved artifacts root (removed in AfterAll), and the real
# slice 2 Invoke-CoordCustodyHandoff -Mode ApplyPackage runs against it. Task Scheduler is
# never touched: Get-CoordUpgradeTaskState and Start-CoordUpgradeTask are mocked, and a
# "running" resident is simulated by holding its lifetime lease until the stop file appears.
# Test-CoordPackageAttestation is mocked as in slice 2 (the unsigned source cannot pass
# Authenticode). Nothing touches C:\ProgramData, Program Files or a live task.

BeforeDiscovery {
  $sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  $moduleName = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
  $manifest = Join-Path $sourceRoot ($moduleName + '.psd1')
  $data = Import-PowerShellDataFile -LiteralPath $manifest
  $modulePath = Join-Path $sourceRoot $data.RootModule
  $loaded = @(Get-Module -Name $moduleName -All)
  if ($loaded.Count -gt 1 -or @($loaded | Where-Object { $_.Path -ine $modulePath }).Count) { throw 'UpgradeTestConflictingLoadedModule' }
  $selected = if ($loaded.Count) { $loaded[0] } else { Import-Module -Name $manifest -PassThru -ErrorAction Stop }
  & $selected { param($binding) $script:upgradeTestBinding = $binding } ([pscustomobject]@{ ModuleBase = $sourceRoot; ModulePath = $modulePath; Version = $data.ModuleVersion })
  $script:upgradeTestModuleName = $moduleName
}

InModuleScope -ModuleName $script:upgradeTestModuleName {
Describe 'Custodian package upgrade orchestration, end to end' -Tag 'Integration', 'CoordPackageUpgrade' {
  BeforeAll {
    $script:moduleRoot = $script:upgradeTestBinding.ModuleBase
    $script:newVersion = $script:upgradeTestBinding.Version
    $script:upgradeScript = Join-Path $script:moduleRoot 'Resources\Resident\Invoke-CoordPackageUpgrade.ps1'
    . $script:upgradeScript
    # Dot-sourcing binds the script's own parameters as empty variables in this scope; drop
    # them so they cannot shadow the fixture's same-named (case-insensitive) script variables.
    foreach ($name in 'BindingPath', 'ExpectedBindingSha256', 'AttestationPath', 'ExpectedAttestationSha256', 'NupkgPath', 'OperationId', 'EvidencePath', 'StopTimeoutSeconds') {
      Remove-Variable -Name $name -Scope Local -ErrorAction SilentlyContinue
    }
    # Inert stand-ins so the tripwire mocks below resolve without the ScheduledTasks module;
    # no call can reach the real Task Scheduler.
    function Start-ScheduledTask { [CmdletBinding()] param($TaskPath, $TaskName) }
    function Stop-ScheduledTask { [CmdletBinding()] param($TaskPath, $TaskName) }
    $script:handoff = Get-Command Invoke-CoordCustodyHandoff
    $script:handoff.Module.Path | Should -BeExactly $script:upgradeTestBinding.ModulePath
    $script:sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $script:oldSettings = $global:settings; $script:oldKeys = $global:configRootKeys; $script:oldModulePath = $env:PSModulePath
    $script:schemaBytes = [IO.File]::ReadAllBytes((Join-Path $script:moduleRoot 'schemas/state-v1.schema.json'))
    $script:schemaHash = Get-CoordHash $script:schemaBytes
    $script:thumb = '3B5E16C03B5E16C03B5E16C03B5E16C03B5E16C0'
    $script:requestHash = ('a' * 64); $script:resultHash = ('b' * 64)
    $script:custodyVersion = '0.1.13'
    $script:taskDefinition = ('7A' * 32)
    $script:runId = 'run-' + [guid]::NewGuid().ToString('N')
    $script:fixtureBase = switch ([Environment]::MachineName.ToUpperInvariant()) {
      UTAT022 { 'D:/ATAPArtifacts/_generated/Sprint0017/orch017-slice8-fixtures' }
      UTAT01 { 'C:/ATAPArtifacts/_generated/Sprint0017/orch017-slice8-fixtures' }
      default { throw 'Unknown upgrade fixture host' }
    }
    $script:runRoot = Join-Path $script:fixtureBase $script:runId

    function Protect-UpgradeDirectory([string]$Path) {
      $acl = Get-Acl -LiteralPath $Path
      $acl.SetOwner([Security.Principal.SecurityIdentifier]::new($sid)); $acl.SetAccessRuleProtection($true, $false)
      foreach ($rule in @($acl.GetAccessRules($true, $false, [Security.Principal.SecurityIdentifier]))) { $acl.RemoveAccessRuleSpecific($rule) }
      foreach ($who in $sid, 'S-1-5-18', 'S-1-5-32-544') {
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($who), 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
      }
      Set-Acl -LiteralPath $Path -AclObject $acl
    }
    function Write-UpgradeJson([string]$Path, $Value) { [IO.File]::WriteAllBytes($Path, (ConvertTo-CoordStateBytes (ConvertTo-CoordElement $Value))) }
    function Get-UpgradeInventory([string]$Root) {
      @(Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object {
          $_.Extension -in '.ps1', '.psm1', '.psd1', '.json' -and -not (Test-CoordDescendant $_.FullName (Join-Path $Root 'tests')) } | ForEach-Object {
          $bytes = [IO.File]::ReadAllBytes($_.FullName)
          [ordered]@{ path = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\', '/'); sha256 = (Get-CoordHash $bytes).ToUpperInvariant(); size = [long]$bytes.LongLength }
        })
    }
    function New-UpgradeFixture {
      $null = [IO.Directory]::CreateDirectory($script:runRoot)
      $script:fixtureRoot = Join-Path $script:runRoot ([guid]::NewGuid().ToString('N'))
      $script:fakeProgramData = Join-Path $fixtureRoot 'ProgramData'
      $script:stateRoot = Join-Path $fakeProgramData 'State'; $script:custodyRoot = Join-Path $fakeProgramData 'Custody'
      $script:backupRoot = Join-Path $fakeProgramData 'Backup'; $script:historyRoot = Join-Path $fakeProgramData 'RecoveryHistory'
      $script:boardRoot = Join-Path $fixtureRoot 'Board'; $script:inputRoot = Join-Path $fixtureRoot 'Inputs'
      $script:controlRoot = Join-Path $fixtureRoot 'Control'; $script:evidenceRoot = Join-Path $fixtureRoot 'Evidence'
      $script:modulesRoot = Join-Path $fixtureRoot 'Modules'
      foreach ($directory in $fixtureRoot, $fakeProgramData, $stateRoot, $custodyRoot, $backupRoot, $boardRoot, $inputRoot, $historyRoot) {
        $null = [IO.Directory]::CreateDirectory($directory); Protect-UpgradeDirectory $directory
      }
      foreach ($directory in $controlRoot, $evidenceRoot) { $null = [IO.Directory]::CreateDirectory($directory) }
      # The new version "installed exactly once" in the fixture AllUsers root.
      # It is a byte copy of the module tree (minus tests) whose psm1 ends with a side effect. That side effect
      # must never fire: the candidate is verified as bytes by the admitted module and is never imported.
      $installed = Join-Path $modulesRoot ('ATAP.Utilities.BuildTooling.Orchestration.PowerShell\' + $newVersion)
      $null = [IO.Directory]::CreateDirectory($installed)
      foreach ($file in Get-ChildItem -LiteralPath $moduleRoot -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($moduleRoot, $file.FullName)
        if ($relative -match '\A(tests)(\\|\z)') { continue }
        $destination = Join-Path $installed $relative
        $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
        [IO.File]::WriteAllBytes($destination, [IO.File]::ReadAllBytes($file.FullName))
      }
      $script:candidateSentinel = Join-Path $fixtureRoot 'candidate-code-ran.txt'
      [IO.File]::AppendAllText((Join-Path $installed 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psm1'), "`n[IO.File]::WriteAllText('$($script:candidateSentinel)', 'candidate code executed')`n")
      $script:installedRoot = [IO.Path]::GetFullPath($installed).TrimEnd('\')
      # The fixed-path launcher the logon task runs: byte-equal to the candidate's bundled launcher, so the M1 check is Compatible by default.
      $script:installedLauncher = Join-Path $fixtureRoot 'LauncherInstall\Start-CoordClerkResident.ps1'
      $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($script:installedLauncher))
      [IO.File]::WriteAllBytes($script:installedLauncher, [IO.File]::ReadAllBytes((Join-Path $moduleRoot 'Resources\Resident\Start-CoordClerkResident.ps1')))
      $script:statePath = Join-Path $stateRoot 'state.json'; $script:witnessPath = Join-Path $custodyRoot 'custody.json'
      $script:boardLock = Join-Path $boardRoot 'board.lock'
      [IO.File]::WriteAllBytes($boardLock, [byte[]]@()); [IO.File]::WriteAllBytes((Join-Path $custodyRoot 'resource.lock'), [byte[]]@())
      $manifest = [ordered]@{}; $script:quartetPaths = [ordered]@{}
      foreach ($slot in 'markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml') {
        $path = Join-Path $boardRoot ($slot + '.bin'); $image = [Text.Encoding]::UTF8.GetBytes('unchanged ' + $slot)
        [IO.File]::WriteAllBytes($path, $image); $manifest[$slot] = [ordered]@{ path = $path; digest = Get-CoordHash $image }
        $script:quartetPaths[$slot] = $path
      }
      $reference = [ordered]@{ reference = 'disposable-reference'; digest = ('0' * 64) }
      $scope = @([ordered]@{ registeredRootId = 'fixture'; path = 'a.md' })
      Write-UpgradeJson $statePath ([ordered]@{ schemaVersion = 'Coordination-state-v1'; resourceId = 'upgrade-fixture'; lineageId = 'lineage-upgrade'
        registeredRoots = @([ordered]@{ registeredRootId = 'fixture'; path = $boardRoot }); generation = 'epoch-before'; committedRevision = 'head-1'
        committedOutputManifest = $manifest; custodyEvidence = $reference; compatibilityEvidence = $reference; admissionEvidence = @($reference)
        requests = @(); preparedOperations = @(); commitReceipts = @()
        claims = @([ordered]@{ claimId = 'held-claim'; resourceId = 'upgrade-fixture'; taskId = '17.1'; scope = $scope
            holder = [ordered]@{ holderId = 'Worker'; sessionId = 'worker-1' }; generation = 'epoch-before'; claimRequestId = 'earlier-claim' })
        reservations = @([ordered]@{ reservationId = 'held-reservation'; resourceId = 'upgrade-fixture'; requestId = 'unpublished'; taskId = '17.2'
            scope = $scope; generation = 'epoch-before' })
        mutationAdmission = [ordered]@{ status = 'Admitted'; reason = 'Disposable'; observedOutputs = @() } })
      $oldPackage = [ordered]@{ moduleVersion = $custodyVersion; files = @([ordered]@{ path = 'schemas/state-v1.schema.json'; digest = $schemaHash }, [ordered]@{ path = 'old.psm1'; digest = ('c' * 64) }) }
      Write-UpgradeJson $witnessPath ([ordered]@{ schemaVersion = 'Coordination-custody-v1'; admissionMode = 'Established'; custodianSid = $sid
        resourceId = 'upgrade-fixture'; lineageId = 'lineage-upgrade'; generation = 'epoch-before'; sprintId = '0017'; coordinatorId = 'Coordinator'
        statePath = $statePath; stateSha256 = Get-CoordHash ([IO.File]::ReadAllBytes($statePath)); pendingWrite = $null; boardLockPath = $boardLock
        actors = @([ordered]@{ holderId = 'Coordinator'; sessionId = 'coordinator-1'; windowsSid = $sid; role = 'Coordinator' },
          [ordered]@{ holderId = 'Worker'; sessionId = 'worker-1'; windowsSid = $sid; role = 'Worker' })
        retiredActors = @(); authorizations = @(); existingTasks = @([ordered]@{ taskId = '17.32.b'; ancestorTaskIds = @() }); package = $oldPackage
        autoPackageAdmission = [ordered]@{ enabled = $true; signer = $thumb; minVersion = '0.1.14'
          schemaHashes = [ordered]@{ state = $schemaHash; request = $requestHash; result = $resultHash }; semanticRevision = 'sem-1' } })
      $attestation = [ordered]@{ kind = 'Coordination-package-attestation-v1'; moduleName = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
        moduleVersion = $newVersion; archiveSha256 = ('D' * 64); signerThumbprint = $thumb.ToLowerInvariant()
        stateSchemaSha256 = $schemaHash.ToUpperInvariant(); requestSchemaSha256 = $requestHash; resultSchemaSha256 = $resultHash
        coordinationSemanticRevision = 'sem-1'; buildId = 'build-1'; executionIds = @('exec-1'); createdUtc = '2026-11-13T11:00:00.0000000Z'
        finalProductionTestReceiptSha256 = ('e' * 64); tierReceiptSha256 = [ordered]@{ Production = ('f' * 64) }; files = (Get-UpgradeInventory $installed) }
      $script:attestationPath = Join-Path $inputRoot 'attestation.json'
      [IO.File]::WriteAllBytes($attestationPath, [Text.Encoding]::UTF8.GetBytes(($attestation | ConvertTo-Json -Depth 20)))
      $script:attestationPin = Get-CoordHash ([IO.File]::ReadAllBytes($attestationPath))
      $script:nupkgPath = Join-Path $inputRoot 'package.nupkg'
      [IO.File]::WriteAllBytes($nupkgPath, [byte[]](1..32))
      # The resident's v2 descriptor: only its paths are read by the orchestration.
      $script:leasePath = Join-Path $controlRoot 'resident.lock'; $script:stopPath = Join-Path $controlRoot 'stop'
      [IO.File]::WriteAllBytes($leasePath, [byte[]]@())
      $script:bindingPath = Join-Path $controlRoot 'binding.json'
      [IO.File]::WriteAllText($bindingPath, ([ordered]@{ schemaVersion = 'CoordResidentStartup-v2'; mode = 'Active'; hostName = [Environment]::MachineName; windowsSid = $sid
        holderId = 'Coordinator'; sessionId = 'coordinator-1'; resourceId = 'upgrade-fixture'; lineageId = 'lineage-upgrade'
        statePath = $statePath; custodyPath = $witnessPath; leasePath = $leasePath; stopPath = $stopPath; activationPath = Join-Path $controlRoot 'activation.json' } | ConvertTo-Json))
      $script:bindingPin = (Get-FileHash -LiteralPath $bindingPath).Hash
      $script:opId = [guid]::NewGuid().ToString('D')
      $global:configRootKeys = @{}; $global:settings = @{}
      $values = @{ StateRootPath = $stateRoot; CustodyRecordPath = $witnessPath; ProtectedBackupRootPath = $backupRoot; RecoveryHistoryRootPath = $historyRoot
        SevenZipPath = 'C:/Program Files/7-Zip/7z.exe'; SevenZipSha256 = 'DC0493429FE28136FCB177A0E77C9875CBB3B0BFF5F2F8EEBA4DF302E98CEF76'
        MaxRequestBytes = 65536; MaxBatchBytes = 262144; MaxBatchRequests = 8; MaxDrainRequests = 16; MaxDrainBatches = 8; MaxDrainMilliseconds = 10000 }
      foreach ($key in $values.Keys) { $name = 'Orchestration' + $key; $global:configRootKeys[$name + 'ConfigRootKey'] = $name; $global:settings[$name] = $values[$key] }
      $null = Write-CoordRecoveryHistory -Action Initialize -Confirm:$false
      $env:PSModulePath = $modulesRoot
    }
    function Start-FakeResident {
      # A running resident: Task Scheduler reports Running and the host holds its lease
      # exclusively until it sees the stop file at a boundary.
      $script:residentLease = [IO.File]::Open($script:leasePath, 'Open', 'ReadWrite', 'None')
      $script:residentRunning = $true
    }
    function Invoke-Upgrade([int]$Timeout = 30, [string]$Adopt, [switch]$Reinstall) {
      $extra = @{}
      if ($Adopt) { $extra.AdoptStopFileOfOperationId = $Adopt }
      Invoke-CoordPackageUpgrade -BindingPath $bindingPath -ExpectedBindingSha256 $bindingPin -AttestationPath $attestationPath -ExpectedAttestationSha256 $attestationPin `
        -NupkgPath $nupkgPath -OperationId $opId -EvidencePath $evidenceRoot -StopTimeoutSeconds $Timeout -ModulesRoot $modulesRoot -HandoffCommand $script:handoff -PollMilliseconds 50 `
        -InstalledLauncherPath $script:installedLauncher -LauncherReinstallPlanned:$Reinstall -Confirm:$false @extra
    }
    function Set-AttestationWithoutLauncherPin {
      $doc = [IO.File]::ReadAllText($script:attestationPath) | ConvertFrom-Json -AsHashtable
      $doc.files = @($doc.files | Where-Object { $_.path -cne 'Resources/Resident/Start-CoordClerkResident.ps1' })
      [IO.File]::WriteAllBytes($script:attestationPath, [Text.Encoding]::UTF8.GetBytes(($doc | ConvertTo-Json -Depth 20)))
      $script:attestationPin = Get-CoordHash ([IO.File]::ReadAllBytes($script:attestationPath))
    }
    function Get-UpgradeWitness { Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath)) }
    function Get-ProtectedImage {
      @(Get-ChildItem -LiteralPath $fakeProgramData -Recurse -File -Force | Sort-Object FullName | ForEach-Object { $_.FullName + '=' + (Get-CoordHash ([IO.File]::ReadAllBytes($_.FullName))) }) -join "`n"
    }
  }
  BeforeEach {
    Mock Get-CoordProgramDataPath { $script:fakeProgramData }
    New-UpgradeFixture
    $script:residentRunning = $false; $script:residentLease = $null; $script:stopSeenAt = $null
    $script:verifierCalls = [Collections.Generic.List[object]]::new()
    Mock Test-CoordPackageAttestation {
      $script:verifierCalls.Add([pscustomobject]@{ ModuleRoot = $ModuleRoot; StopFileExisted = [IO.File]::Exists($script:stopPath); CandidateSentinelExisted = [IO.File]::Exists($script:candidateSentinel) })
      [pscustomobject]@{ Valid = $true; ReasonCode = 'Valid'; Detail = $null; InstalledModuleVersion = $script:newVersion; AttestationPath = $AttestationPath }
    }
    Mock Get-CoordUpgradeTaskState {
      if ($script:residentRunning -and [IO.File]::Exists($script:stopPath) -and -not $script:stuck) {
        # Boundary exit: the host sees the stop file between drains and releases its lease.
        $script:residentLease.Dispose(); $script:residentLease = $null; $script:residentRunning = $false; $script:stopSeenAt = [DateTimeOffset]::UtcNow
      }
      [pscustomobject]@{ Exists = $true; State = $(if ($script:residentRunning) { 'Running' } else { 'Ready' }); Enabled = $true; DefinitionSha256 = $script:taskDefinition }
    }
    Mock Start-CoordUpgradeTask {}
    Mock Start-ScheduledTask { throw 'MustNotReachTaskScheduler' }
    Mock Stop-ScheduledTask { throw 'MustNeverStopTask' }
    $script:stuck = $false
  }
  AfterEach {
    if ($script:residentLease) { $script:residentLease.Dispose(); $script:residentLease = $null }
    Should -Invoke Stop-ScheduledTask -Times 0
    Should -Invoke Start-ScheduledTask -Times 0
    $global:settings = $script:oldSettings; $global:configRootKeys = $script:oldKeys; $env:PSModulePath = $script:oldModulePath
    if ($script:fixtureRoot -and (Test-Path -LiteralPath $script:fixtureRoot)) { Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue }
  }
  AfterAll {
    $global:settings = $script:oldSettings; $global:configRootKeys = $script:oldKeys; $env:PSModulePath = $script:oldModulePath
    if ($script:runRoot -and (Test-Path -LiteralPath $script:runRoot)) { Remove-Item -LiteralPath $script:runRoot -Recurse -Force -ErrorAction SilentlyContinue }
    if ($script:fixtureBase -and (Test-Path -LiteralPath $script:fixtureBase) -and -not @(Get-ChildItem -LiteralPath $script:fixtureBase -Force).Count) {
      Remove-Item -LiteralPath $script:fixtureBase -Force -ErrorAction SilentlyContinue
    }
  }

  It 'upgrades with held claims and a running resident: stops at the boundary, swaps, restarts, claims byte-identical, task unchanged' {
    Start-FakeResident
    $stateBefore = [IO.File]::ReadAllBytes($statePath)
    $r = Invoke-Upgrade
    $r.Status | Should -BeExactly 'Upgraded'
    $r.Reason | Should -BeExactly 'PackageAdmitted'
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($statePath)) | Should -BeExactly ([Convert]::ToBase64String($stateBefore))
    (([IO.File]::ReadAllText($statePath) | ConvertFrom-Json).claims[0].claimId) | Should -BeExactly 'held-claim'
    (Get-UpgradeWitness).GetProperty('package').GetProperty('moduleVersion').GetString() | Should -BeExactly $newVersion
    (Get-UpgradeWitness).GetProperty('generation').GetString() | Should -BeExactly 'epoch-before'
    $script:stopSeenAt | Should -Not -BeNullOrEmpty
    Test-Path -LiteralPath $stopPath | Should -BeFalse
    Should -Invoke Start-CoordUpgradeTask -Times 1 -Exactly
    $receipt = Get-Content -LiteralPath $r.ReceiptPath -Raw | ConvertFrom-Json
    $receipt.custodyVersionBefore | Should -BeExactly '0.1.13'
    $receipt.custodyVersionAfter | Should -BeExactly $newVersion
    $receipt.attestationSha256 | Should -BeExactly $attestationPin.ToUpperInvariant()
    $receipt.apply.code | Should -BeExactly 'PackageAdmitted'
    $receipt.apply.receiptSha256 | Should -Not -BeNullOrEmpty
    $receipt.stop.residentRunning | Should -BeTrue
    $receipt.stop.requestedUtc | Should -Not -BeNullOrEmpty
    $receipt.stop.stoppedUtc | Should -Not -BeNullOrEmpty
    $receipt.restart.startRequested | Should -BeTrue
    $receipt.restart.startedUtc | Should -Not -BeNullOrEmpty
    $receipt.task.definitionSha256Before | Should -BeExactly $script:taskDefinition
    $receipt.task.definitionSha256After | Should -BeExactly $script:taskDefinition
    $receipt.task.definitionUnchanged | Should -BeTrue
    $receipt.descriptorUnchanged | Should -BeTrue
    (Get-FileHash -LiteralPath $bindingPath).Hash | Should -BeExactly $bindingPin
    $r.ReceiptSha256 | Should -BeExactly (Get-FileHash -LiteralPath $r.ReceiptPath).Hash
  }

  It 'a NotNow refusal restarts the unchanged task on the old version without disabling the policy' {
    Start-FakeResident
    Mock New-CoordPackageAdmissionPlan { throw 'PendingWritePresent' }
    $r = Invoke-Upgrade
    $r.Status | Should -BeExactly 'NotNow'
    $r.Reason | Should -BeExactly 'PendingWritePresent'
    (Get-UpgradeWitness).GetProperty('package').GetProperty('moduleVersion').GetString() | Should -BeExactly $custodyVersion
    (Get-UpgradeWitness).GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly True
    Test-Path -LiteralPath $stopPath | Should -BeFalse
    Should -Invoke Start-CoordUpgradeTask -Times 1 -Exactly
    $receipt = Get-Content -LiteralPath $r.ReceiptPath -Raw | ConvertFrom-Json
    $receipt.apply.outcomeClass | Should -BeExactly 'NotNow'
    $receipt.apply.policyDisable | Should -BeExactly 'NotDisabled_NotNowRefusal'
    $receipt.custodyVersionAfter | Should -BeExactly $custodyVersion
  }

  It 'a trust failure at apply (bytes changed after the pre-check) leaves the task stopped and the policy disabled' {
    Start-FakeResident
    $script:verifyCount = 0
    Mock Test-CoordPackageAttestation {
      $script:verifyCount++
      [pscustomobject]@{ Valid = ($script:verifyCount -le 1); ReasonCode = 'SignatureInvalid'; Detail = 'x'; InstalledModuleVersion = $null; AttestationPath = $AttestationPath }
    }
    $r = Invoke-Upgrade
    $r.Status | Should -BeExactly 'Held'
    $r.Reason | Should -BeExactly 'PackageAttestationRejected'
    $script:verifyCount | Should -Be 2
    (Get-UpgradeWitness).GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly False
    (Get-UpgradeWitness).GetProperty('package').GetProperty('moduleVersion').GetString() | Should -BeExactly $custodyVersion
    Test-Path -LiteralPath $stopPath | Should -BeTrue
    Should -Invoke Start-CoordUpgradeTask -Times 0
    $receipt = Get-Content -LiteralPath $r.ReceiptPath -Raw | ConvertFrom-Json
    $receipt.apply.policyDisable | Should -BeExactly 'Disabled'
    $receipt.apply.structured | Should -BeTrue
    $receipt.hold.policyDisableConfirmed | Should -BeTrue
    $receipt.restart.skippedReason | Should -BeExactly 'HeldAfterApplyRefusal'
    Test-Path -LiteralPath $candidateSentinel | Should -BeFalse
  }

  It 'H1: the new package is verified by the admitted module, against the new install root, before the stop file and before any write' {
    Start-FakeResident
    $r = Invoke-Upgrade
    $r.Status | Should -BeExactly 'Upgraded'
    # Two verifications, both of the candidate's installed root, both by the admitted (running) module.
    $script:verifierCalls.Count | Should -Be 2
    foreach ($call in $script:verifierCalls) { $call.ModuleRoot | Should -BeExactly $script:installedRoot }
    # The first is the pre-check: before the stop file exists, so before anything is written.
    $script:verifierCalls[0].StopFileExisted | Should -BeFalse
    $script:verifierCalls[1].StopFileExisted | Should -BeTrue
    $receipt = Get-Content -LiteralPath $r.ReceiptPath -Raw | ConvertFrom-Json
    $receipt.preVerification.performedByAdmittedModule | Should -BeTrue
    $receipt.preVerification.candidateRoot | Should -BeExactly $script:installedRoot
    $receipt.handoffModulePath | Should -BeExactly $script:upgradeTestBinding.ModulePath
    $receipt.handoffModulePath | Should -Not -BeLike ($script:installedRoot + '*')
  }

  It 'H1: no candidate code executes, even on a successful upgrade, and none is loaded' {
    $r = Invoke-Upgrade
    $r.Status | Should -BeExactly 'Upgraded'
    Test-Path -LiteralPath $candidateSentinel | Should -BeFalse
    @(Get-Module -Name 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell' -All | Where-Object { [IO.Path]::GetFullPath($_.ModuleBase).TrimEnd('\') -ieq $script:installedRoot }).Count | Should -Be 0
    $script:verifierCalls | ForEach-Object { $_.CandidateSentinelExisted | Should -BeFalse }
  }

  It 'H1: a failed pre-verification refuses with nothing written, no stop file, and no candidate code run' {
    Start-FakeResident
    Mock Test-CoordPackageAttestation {
      $script:verifierCalls.Add([pscustomobject]@{ ModuleRoot = $ModuleRoot; StopFileExisted = [IO.File]::Exists($script:stopPath); CandidateSentinelExisted = [IO.File]::Exists($script:candidateSentinel) })
      [pscustomobject]@{ Valid = $false; ReasonCode = 'SignatureInvalid'; Detail = 'x'; InstalledModuleVersion = $null; AttestationPath = $AttestationPath }
    }
    $protectedBefore = Get-ProtectedImage
    $r = Invoke-Upgrade
    $r.Status | Should -BeExactly 'Refused'
    $r.Reason | Should -BeExactly 'UpgradeNewPackageNotVerified'
    $r.Detail | Should -BeLike '*SignatureInvalid*'
    $script:verifierCalls.Count | Should -Be 1
    $script:verifierCalls[0].ModuleRoot | Should -BeExactly $script:installedRoot
    $script:verifierCalls[0].StopFileExisted | Should -BeFalse
    Test-Path -LiteralPath $candidateSentinel | Should -BeFalse
    Get-ProtectedImage | Should -BeExactly $protectedBefore
    Test-Path -LiteralPath $stopPath | Should -BeFalse
    @(Get-ChildItem -LiteralPath $evidenceRoot -File).Count | Should -Be 0
    Should -Invoke Start-CoordUpgradeTask -Times 0
    (Get-UpgradeWitness).GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly True
  }

  It 'H1: a verifier that throws also refuses before anything is written' {
    Mock Test-CoordPackageAttestation { throw 'VerifierExploded' }
    $protectedBefore = Get-ProtectedImage
    $r = Invoke-Upgrade
    $r.Status | Should -BeExactly 'Refused'
    $r.Reason | Should -BeExactly 'UpgradeNewPackageNotVerified'
    Get-ProtectedImage | Should -BeExactly $protectedBefore
    Test-Path -LiteralPath $stopPath | Should -BeFalse
    Test-Path -LiteralPath $candidateSentinel | Should -BeFalse
  }

  It 'H1: production resolution imports the admitted version only, and refuses when another copy (such as the candidate) is already loaded' {
    $admitted = Join-Path $script:modulesRoot ('ATAP.Utilities.BuildTooling.Orchestration.PowerShell\' + $script:custodyVersion)
    { Resolve-CoordUpgradeHandoffCommand -InstallRoot $admitted -AdmittedVersion $script:custodyVersion } | Should -Throw '*UpgradeAdmittedModuleUnavailable*'
    # The module under test is loaded from the source tree, which is neither the admitted root nor the candidate.
    $null = [IO.Directory]::CreateDirectory($admitted)
    [IO.File]::WriteAllText((Join-Path $admitted 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psd1'), '@{ ModuleVersion = ''0.1.13'' }')
    { Resolve-CoordUpgradeHandoffCommand -InstallRoot $admitted -AdmittedVersion $script:custodyVersion } | Should -Throw '*UpgradeUnexpectedModuleLoaded*'
  }

  Context 'M1: a launcher change would strand the resident, so it is a NotNow before any write' {
    It 'is NotNow <Code> and writes nothing: <Name>' -ForEach @(
      @{ Name = 'candidate launcher differs from the installed one'; Code = 'UpgradeLauncherChangeRequiresReinstall'; Arrange = { [IO.File]::AppendAllText($script:installedLauncher, "`n# an older launcher") } }
      @{ Name = 'installed launcher is missing'; Code = 'UpgradeInstalledLauncherMissing'; Arrange = { Remove-Item -LiteralPath $script:installedLauncher -Force } }
      @{ Name = 'candidate does not pin its launcher'; Code = 'UpgradeCandidateLauncherPinMissing'; Arrange = { Set-AttestationWithoutLauncherPin } }
    ) {
      Start-FakeResident
      & $Arrange
      $protectedBefore = Get-ProtectedImage
      $r = Invoke-Upgrade
      $r.Status | Should -BeExactly 'NotNow'
      $r.Reason | Should -BeExactly $Code
      $r.ReceiptPath | Should -BeNullOrEmpty
      Get-ProtectedImage | Should -BeExactly $protectedBefore
      Test-Path -LiteralPath $stopPath | Should -BeFalse
      @(Get-ChildItem -LiteralPath $evidenceRoot -File).Count | Should -Be 0
      Should -Invoke Start-CoordUpgradeTask -Times 0
      (Get-UpgradeWitness).GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly True
      (Get-UpgradeWitness).GetProperty('package').GetProperty('moduleVersion').GetString() | Should -BeExactly $custodyVersion
      # The check ran after the candidate was verified (once, by the pre-check) and before ApplyPackage (which never ran).
      $script:verifierCalls.Count | Should -Be 1
      Test-Path -LiteralPath $candidateSentinel | Should -BeFalse
    }
    It 'proceeds when the plan re-installs the launcher: <Name>' -ForEach @(
      @{ Name = 'installed launcher differs'; Arrange = { [IO.File]::AppendAllText($script:installedLauncher, "`n# an older launcher") } }
      @{ Name = 'installed launcher is missing (first install)'; Arrange = { Remove-Item -LiteralPath $script:installedLauncher -Force } }
    ) {
      & $Arrange
      $r = Invoke-Upgrade -Reinstall
      $r.Status | Should -BeExactly 'Upgraded'
      $script:verifierCalls.Count | Should -Be 2
    }
    It 'an unchanged launcher proceeds without a reinstall' {
      $r = Invoke-Upgrade
      $r.Status | Should -BeExactly 'Upgraded'
    }
    It 'refuses (not NotNow) when the check itself cannot give a verdict: <Name>' -ForEach @(
      @{ Name = 'throws'; Body = { throw 'LauncherFileUnreadable' } }
      @{ Name = 'returns nothing'; Body = { } }
      @{ Name = 'returns an unknown status'; Body = { [pscustomobject]@{ Status = 'Maybe'; Reason = 'Unsure' } } }
    ) {
      $script:checkBody = $Body
      Mock Get-CoordUpgradeLauncherCheck { & $script:checkBody }
      $protectedBefore = Get-ProtectedImage
      $r = Invoke-Upgrade
      $r.Status | Should -BeExactly 'Refused'
      $r.Reason | Should -BeExactly 'UpgradeLauncherCheckUnavailable'
      Get-ProtectedImage | Should -BeExactly $protectedBefore
      Test-Path -LiteralPath $stopPath | Should -BeFalse
    }
    It 'uses the admitted module root, never the candidate root, to find the launcher functions' {
      Mock Get-CoordUpgradeLauncherCheck { [pscustomobject]@{ Status = 'Compatible'; Reason = 'LauncherUnchanged' } } -ParameterFilter { [IO.Path]::GetFullPath($ModuleRoot).TrimEnd('\') -ieq [IO.Path]::GetFullPath($script:moduleRoot).TrimEnd('\') -and [IO.Path]::GetFullPath($ModuleRoot).TrimEnd('\') -ine $script:installedRoot }
      $r = Invoke-Upgrade
      $r.Status | Should -BeExactly 'Upgraded'
      Should -Invoke Get-CoordUpgradeLauncherCheck -Times 1 -Exactly
    }
  }

  It 'M6: an unconfirmed policy disable is reported explicitly, fenced and held, with the marker blocking the next attempt' {
    Start-FakeResident
    $script:verifyCount = 0
    Mock Test-CoordPackageAttestation {
      $script:verifyCount++
      if ($script:verifyCount -ge 2) {
        # A foreign writer changes custody while the attempt is in flight, so the disable is unsafe.
        $w = ConvertFrom-CoordElement (Get-UpgradeWitness); $w.pendingWrite = [ordered]@{ kind = 'Foreign'; operationId = 'someone-else' }
        Write-UpgradeJson $script:witnessPath $w
      }
      [pscustomobject]@{ Valid = ($script:verifyCount -le 1); ReasonCode = 'SignatureInvalid'; Detail = 'x'; InstalledModuleVersion = $null; AttestationPath = $AttestationPath }
    }
    $r = Invoke-Upgrade
    $r.Status | Should -BeExactly 'Held'
    $r.Reason | Should -BeExactly 'PolicyDisableNotConfirmed_HeldFenced'
    Test-Path -LiteralPath $stopPath | Should -BeTrue
    Should -Invoke Start-CoordUpgradeTask -Times 0
    $receipt = Get-Content -LiteralPath $r.ReceiptPath -Raw | ConvertFrom-Json
    $receipt.apply.code | Should -BeExactly 'PackageAttestationRejected'
    $receipt.apply.policyDisable | Should -BeLike 'DisableUnsafe*'
    $receipt.apply.holdMarker | Should -BeExactly 'Written'
    $receipt.hold.policyDisableConfirmed | Should -BeFalse
    $receipt.hold.fence | Should -BeExactly 'PolicyDisableNotConfirmed_HeldFenced'
    Test-Path -LiteralPath (Join-Path $custodyRoot 'package-admission.hold.json') | Should -BeTrue
    # Even with the stop file cleared by an operator, a new attempt is refused by the marker.
    Remove-Item -LiteralPath $stopPath -Force
    $script:opId = [guid]::NewGuid().ToString('D')
    $script:verifyCount = 0
    Mock Test-CoordPackageAttestation { [pscustomobject]@{ Valid = $true; ReasonCode = 'Valid'; Detail = $null; InstalledModuleVersion = $script:newVersion; AttestationPath = $AttestationPath } }
    $again = Invoke-Upgrade
    $again.Status | Should -BeExactly 'Held'
    $again.Reason | Should -BeExactly 'PackageAdmissionHeldUnsafeDisable'
  }

  It 'M7: a crashed run leaves its own stop file; the same-operation retry recognizes it, upgrades, removes it and restarts' {
    [IO.File]::WriteAllText($stopPath, 'package-upgrade ' + $opId)
    $r = Invoke-Upgrade
    $r.Status | Should -BeExactly 'Upgraded'
    Test-Path -LiteralPath $stopPath | Should -BeFalse
    Should -Invoke Start-CoordUpgradeTask -Times 1 -Exactly
    $receipt = Get-Content -LiteralPath $r.ReceiptPath -Raw | ConvertFrom-Json
    $receipt.stop.ownership | Should -BeExactly 'OwnPreviousRun'
    $receipt.stop.preexisting | Should -BeFalse
    $receipt.restart.stopFileRemoved | Should -BeTrue
    $receipt.restart.startRequested | Should -BeTrue
  }

  It 'M7: a stop file recorded by another upgrade operation is refused unless that exact operation id is confirmed' {
    $other = [guid]::NewGuid().ToString('D')
    [IO.File]::WriteAllText($stopPath, 'package-upgrade ' + $other)
    $r = Invoke-Upgrade
    $r.Status | Should -BeExactly 'Refused'
    $r.Reason | Should -BeExactly 'UpgradeStrandedStopFileFromOtherOperation'
    [IO.File]::ReadAllText($stopPath) | Should -BeExactly ('package-upgrade ' + $other)
    $wrong = Invoke-Upgrade -Adopt ([guid]::NewGuid().ToString('D'))
    $wrong.Reason | Should -BeExactly 'UpgradeStrandedStopFileFromOtherOperation'
    @(Get-ChildItem -LiteralPath $evidenceRoot -File).Count | Should -Be 0
    Should -Invoke Start-CoordUpgradeTask -Times 0
    $adopted = Invoke-Upgrade -Adopt $other
    $adopted.Status | Should -BeExactly 'Upgraded'
    Test-Path -LiteralPath $stopPath | Should -BeFalse
    Should -Invoke Start-CoordUpgradeTask -Times 1 -Exactly
    $receipt = Get-Content -LiteralPath $adopted.ReceiptPath -Raw | ConvertFrom-Json
    $receipt.stop.ownership | Should -BeExactly 'AdoptedConfirmed'
    $receipt.stop.recordedOperationId | Should -BeExactly $other
  }

  It 'M7: an operator stop file is preserved: <Name>' -ForEach @(
    @{ Name = 'free text'; Content = 'operator hold' }
    @{ Name = 'empty'; Content = '' }
    @{ Name = 'look-alike with a bad id'; Content = 'package-upgrade not-a-guid' }
    @{ Name = 'look-alike with trailing text'; Content = ('package-upgrade ' + '00000000-0000-0000-0000-000000000000' + ' please keep') }
  ) {
    [IO.File]::WriteAllText($stopPath, $Content)
    $r = Invoke-Upgrade
    $r.Status | Should -BeExactly 'Upgraded'
    [IO.File]::ReadAllText($stopPath) | Should -BeExactly $Content
    Should -Invoke Start-CoordUpgradeTask -Times 0
    $receipt = Get-Content -LiteralPath $r.ReceiptPath -Raw | ConvertFrom-Json
    $receipt.stop.ownership | Should -BeExactly 'OperatorOwned'
    $receipt.restart.skippedReason | Should -BeExactly 'OperatorStopFilePreserved'
  }

  It 'M7: the stop file is created atomically with its operation id and leaves no temp file' {
    Start-FakeResident
    $script:stuck = $true
    $r = Invoke-Upgrade -Timeout 1
    $r.Reason | Should -BeExactly 'UpgradeStopTimeout'
    [IO.File]::ReadAllText($stopPath) | Should -BeExactly ('package-upgrade ' + $opId)
    @(Get-ChildItem -LiteralPath $controlRoot -Filter '*.tmp' -Force).Count | Should -Be 0
    # And the held stop file is recognized as its own by the retry of the same operation.
    $script:stuck = $false
    $script:opId = $opId
    Remove-Item -LiteralPath (Join-Path $evidenceRoot ('package-upgrade-' + $opId + '.receipt.json')) -Force
    $retry = Invoke-Upgrade
    $retry.Status | Should -BeExactly 'Upgraded'
    Test-Path -LiteralPath $stopPath | Should -BeFalse
  }

  It 'a stop timeout refuses and holds with nothing written to custody, state or history' {
    Start-FakeResident
    $script:stuck = $true
    $protectedBefore = Get-ProtectedImage
    $r = Invoke-Upgrade -Timeout 1
    $r.Status | Should -BeExactly 'Held'
    $r.Reason | Should -BeExactly 'UpgradeStopTimeout'
    Get-ProtectedImage | Should -BeExactly $protectedBefore
    @(Get-ChildItem -LiteralPath $custodyRoot -Filter 'package-*').Count | Should -Be 0
    Test-Path -LiteralPath $stopPath | Should -BeTrue
    Should -Invoke Start-CoordUpgradeTask -Times 0
    # Only the pre-verification ran; ApplyPackage (and its verifier) never did.
    Should -Invoke Test-CoordPackageAttestation -Times 1 -Exactly
    $receipt = Get-Content -LiteralPath $r.ReceiptPath -Raw | ConvertFrom-Json
    $receipt.apply.called | Should -BeFalse
    $receipt.stop.stoppedUtc | Should -BeNullOrEmpty
  }

  It 'an idle resident still gets a stop file during the swap, removed afterwards' {
    $r = Invoke-Upgrade
    $r.Status | Should -BeExactly 'Upgraded'
    $receipt = Get-Content -LiteralPath $r.ReceiptPath -Raw | ConvertFrom-Json
    $receipt.stop.residentRunning | Should -BeFalse
    $receipt.restart.stopFileRemoved | Should -BeTrue
    Test-Path -LiteralPath $stopPath | Should -BeFalse
  }

  It 'preserves an operator stop file and does not restart' {
    [IO.File]::WriteAllText($stopPath, 'operator hold')
    $r = Invoke-Upgrade
    $r.Status | Should -BeExactly 'Upgraded'
    [IO.File]::ReadAllText($stopPath) | Should -BeExactly 'operator hold'
    Should -Invoke Start-CoordUpgradeTask -Times 0
    (Get-Content -LiteralPath $r.ReceiptPath -Raw | ConvertFrom-Json).restart.skippedReason | Should -BeExactly 'OperatorStopFilePreserved'
  }

  It 'refuses before any write: <Name>' -ForEach @(
    @{ Name = 'attestation pin mismatch'; Expect = 'UpgradeAttestationPinMismatch'; Change = { $script:attestationPin = ('0' * 64) } }
    @{ Name = 'descriptor changed'; Expect = 'UpgradeDescriptorChanged'; Change = { [IO.File]::AppendAllText($script:bindingPath, ' ') } }
    @{ Name = 'second install of the new version'; Expect = 'UpgradeNewVersionNotInstalledOnce'; Change = {
        $other = Join-Path $script:fixtureRoot 'OtherModules'
        $dir = Join-Path $other ('ATAP.Utilities.BuildTooling.Orchestration.PowerShell\' + $script:newVersion)
        $null = [IO.Directory]::CreateDirectory($dir); [IO.File]::WriteAllText((Join-Path $dir 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psd1'), '@{}')
        $env:PSModulePath = $script:modulesRoot + [IO.Path]::PathSeparator + $other } }
    @{ Name = 'new version not installed'; Expect = 'UpgradeNewVersionNotInstalledOnce'; Change = { Remove-Item -LiteralPath (Join-Path $script:modulesRoot 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell') -Recurse -Force } }
    @{ Name = 'operation id not a GUID'; Expect = 'UpgradeOperationIdInvalid'; Change = { $script:opId = 'not-a-guid' } }
  ) {
    Start-FakeResident
    & $Change
    $protectedBefore = Get-ProtectedImage
    $r = Invoke-Upgrade
    $r.Status | Should -BeExactly 'Refused'
    $r.Reason | Should -BeExactly $Expect
    Get-ProtectedImage | Should -BeExactly $protectedBefore
    Test-Path -LiteralPath $stopPath | Should -BeFalse
    @(Get-ChildItem -LiteralPath $evidenceRoot -File).Count | Should -Be 0
    Should -Invoke Start-CoordUpgradeTask -Times 0
  }

  It 'WhatIf proposes only and writes nothing' {
    $protectedBefore = Get-ProtectedImage
    $r = Invoke-CoordPackageUpgrade -BindingPath $bindingPath -ExpectedBindingSha256 $bindingPin -AttestationPath $attestationPath -ExpectedAttestationSha256 $attestationPin `
      -NupkgPath $nupkgPath -OperationId $opId -EvidencePath $evidenceRoot -ModulesRoot $modulesRoot -HandoffCommand $script:handoff -InstalledLauncherPath $script:installedLauncher -WhatIf
    $r.Status | Should -BeExactly 'ProposedOnly'
    Get-ProtectedImage | Should -BeExactly $protectedBefore
    Test-Path -LiteralPath $stopPath | Should -BeFalse
    @(Get-ChildItem -LiteralPath $evidenceRoot -File).Count | Should -Be 0
  }
}

Describe 'Package upgrade outcome classification and shape' -Tag 'Integration', 'CoordPackageUpgrade' {
  BeforeAll {
    . (Join-Path $script:upgradeTestBinding.ModuleBase 'Resources\Resident\Invoke-CoordPackageUpgrade.ps1')
    $tokens = $null; $errors = $null
    $script:upgradeAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $script:upgradeTestBinding.ModuleBase 'Resources\Resident\Invoke-CoordPackageUpgrade.ps1'), [ref]$tokens, [ref]$errors)
    $script:upgradeParseErrors = $errors
  }

  BeforeAll {
    function New-StructuredApplyError([string]$Message, $Code, $Class, $Consumed, $Disable, $Hold) {
      $e = [InvalidOperationException]::new($Message)
      if ($null -ne $Code) { $e.Data['CoordPackageCode'] = $Code }
      if ($null -ne $Class) { $e.Data['CoordPackageClass'] = $Class }
      if ($null -ne $Consumed) { $e.Data['CoordPackageConsumed'] = $Consumed }
      if ($null -ne $Disable) { $e.Data['CoordPackagePolicyDisable'] = $Disable }
      if ($null -ne $Hold) { $e.Data['CoordPackageHoldMarker'] = $Hold }
      $e
    }
  }

  It 'L4: classifies by structured data: <Name>' -ForEach @(
    @{ Name = 'busy collision'; Message = 'text is irrelevant'; Code = 'PendingWritePresent'; DataClass = 'NotNow'; Consumed = $false; Disable = 'NotDisabled_NotNowRefusal'; Class = 'NotNow' }
    @{ Name = 'trust failure'; Message = 'PendingWritePresent'; Code = 'PackageAttestationRejected'; DataClass = 'Held'; Consumed = $false; Disable = 'Disabled'; Class = 'Held' }
    @{ Name = 'busy code but consumed'; Message = 'x'; Code = 'PendingWritePresent'; DataClass = 'NotNow'; Consumed = $true; Disable = 'Disabled'; Class = 'Held' }
    @{ Name = 'unsafe disable'; Message = 'x'; Code = 'PackageAttestationRejected'; DataClass = 'Held'; Consumed = $true; Disable = 'DisableUnsafe_UnknownWitness_HeldAsFound'; Class = 'Held' }
  ) {
    $o = Get-CoordUpgradeOutcome -Exception (New-StructuredApplyError $Message $Code $DataClass $Consumed $Disable 'Written')
    $o.Class | Should -BeExactly $Class
    $o.Code | Should -BeExactly $Code
    $o.Consumed | Should -BeExactly $Consumed
    $o.PolicyDisable | Should -BeExactly $Disable
    $o.HoldMarker | Should -BeExactly 'Written'
    $o.Structured | Should -BeTrue
  }

  It 'L4: never classifies from message text: <Name>' -ForEach @(
    @{ Name = 'busy-class text without data'; Kind = 'TextOnly' }
    @{ Name = 'empty message without data'; Kind = 'Empty' }
    @{ Name = 'null exception'; Kind = 'Null' }
    @{ Name = 'wrong data types'; Kind = 'WrongTypes' }
    @{ Name = 'code not an identifier'; Kind = 'BadCode' }
    @{ Name = 'missing consumed flag'; Kind = 'NoConsumed' }
  ) {
    $exception = switch ($Kind) {
      'TextOnly' { [InvalidOperationException]::new('PendingWritePresent [policyDisable=NotDisabled_NotNowRefusal]') }
      'Empty' { [InvalidOperationException]::new('') }
      'Null' { $null }
      'WrongTypes' { New-StructuredApplyError 'PendingWritePresent' 5 'NotNow' 'false' 'Disabled' $null }
      'BadCode' { New-StructuredApplyError 'x' 'bad code!' 'NotNow' $false 'x' $null }
      'NoConsumed' { New-StructuredApplyError 'x' 'PendingWritePresent' 'NotNow' $null 'x' $null }
    }
    $o = Get-CoordUpgradeOutcome -Exception $exception
    $o.Class | Should -BeExactly 'Held'
    $o.Structured | Should -BeFalse
    # A well-formed code survives (it is data, not text); a malformed or missing one never does.
    $o.Code | Should -BeExactly $(if ($Kind -ceq 'NoConsumed') { 'PendingWritePresent' } else { 'UnclassifiedApplyFailure' })
  }

  It 'L4: the upgrade script carries no copy of the busy-code list and no message-text pattern for outcomes' {
    $text = [IO.File]::ReadAllText((Join-Path $script:upgradeTestBinding.ModuleBase 'Resources\Resident\Invoke-CoordPackageUpgrade.ps1'))
    $text | Should -Not -Match 'PendingWritePresent'
    $text | Should -Not -Match 'policyDisable=\['
  }

  It 'parses cleanly and has no top-level code beyond functions and the dual-purpose guard' {
    @($script:upgradeParseErrors).Count | Should -Be 0
    $other = @($script:upgradeAst.EndBlock.Statements | Where-Object { $_ -isnot [Management.Automation.Language.FunctionDefinitionAst] })
    $other.Count | Should -Be 1
    $other[0].Extent.Text | Should -BeLike "if (`$MyInvocation.InvocationName -ne '.' -and `$MyInvocation.InvocationName -ne '&')*"
  }

  It 'never registers, unregisters, ends, disables or kills a task or process' {
    $names = @($script:upgradeAst.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ })
    foreach ($forbidden in 'Register-ScheduledTask', 'Unregister-ScheduledTask', 'Stop-ScheduledTask', 'Disable-ScheduledTask', 'Enable-ScheduledTask', 'Set-ScheduledTask', 'Stop-Process', 'taskkill', 'schtasks') {
      $names | Should -Not -Contain $forbidden
    }
    @($names | Where-Object { $_ -ceq 'Start-ScheduledTask' }).Count | Should -Be 1
  }
}
}

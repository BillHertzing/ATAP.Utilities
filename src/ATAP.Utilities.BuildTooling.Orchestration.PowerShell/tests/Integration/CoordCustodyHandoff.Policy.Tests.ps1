#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

# Standing custody.autoPackageAdmission policy (0.1.17 slice 5): set, carried, cleared and killed only by a v2 handoff;
# ApplyPackage only reads it and may only switch enabled off.
# Every fixture builds its own protected custody, state, history and board quartet under a disposable
# root inside the approved artifacts root. Nothing touches C:\ProgramData\ATAP\AICoordinator, the real
# board or any live custodian path: Get-CoordProgramDataPath and the settings are redirected.
# Test-CoordPackageAttestation is mocked: the unsigned source tree cannot pass Authenticode, and the
# verifier has its own unit tests. These tests check how the handoff uses its verdict.

BeforeDiscovery {
  $sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  $moduleName = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
  $promoted = [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
  $promotedVersion = [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_VERSION', 'Process')
  if (($null -eq $promoted) -ne ($null -eq $promotedVersion)) { throw 'RecoveryPromotedContextIncomplete' }
  if ($null -ne $promoted) {
    if ([string]::IsNullOrWhiteSpace($promoted) -or [string]::IsNullOrWhiteSpace($promotedVersion)) { throw 'RecoveryPromotedContextEmpty' }
    $releaseVersion = $null
    if ($promotedVersion -cnotmatch '\A[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.+-]+)?\z' -or
        -not [Management.Automation.SemanticVersion]::TryParse($promotedVersion, [ref]$releaseVersion)) { throw 'RecoveryPromotedVersionInvalid' }
    $expectedModuleVersion = [version]::new($releaseVersion.Major, $releaseVersion.Minor, $releaseVersion.Patch).ToString()
  }
  $sourceManifest = Join-Path $sourceRoot ($moduleName + '.psd1')
  $manifest = if ($null -eq $promoted) { $sourceManifest } else { $promoted }
  if ([string]::IsNullOrWhiteSpace($manifest) -or -not [IO.Path]::IsPathFullyQualified($manifest) -or
      [Management.Automation.WildcardPattern]::ContainsWildcardCharacters($manifest) -or
      -not [string]::Equals([IO.Path]::GetFullPath($manifest), $manifest.Replace('/', '\'), [StringComparison]::OrdinalIgnoreCase)) { throw 'RecoveryTestManifestMustBeCanonical' }
  if ($null -ne $promoted -and [string]::Equals($manifest, $sourceManifest, [StringComparison]::OrdinalIgnoreCase)) { throw 'RecoveryPromotedManifestCannotBeSource' }
  for ($part = $manifest; $part; $part = [IO.Path]::GetDirectoryName($part)) {
    if ((Get-Item -LiteralPath $part -Force -ErrorAction Stop).LinkType) { throw 'RecoveryTestManifestCannotTraverseLinks' }
  }
  $item = Get-Item -LiteralPath $manifest -Force -ErrorAction Stop
  if ($item.PSIsContainer -or $item.Name -cne ($moduleName + '.psd1')) { throw 'RecoveryInvalidSelectedManifest' }
  $data = Import-PowerShellDataFile -LiteralPath $manifest
  if ($null -eq $promoted) { $expectedModuleVersion = (Import-PowerShellDataFile -LiteralPath $sourceManifest).ModuleVersion }
  if ($data.RootModule -cne ($moduleName + '.psm1') -or $data.ModuleVersion -cne $expectedModuleVersion) { throw 'RecoverySelectedModuleVersionMismatch' }
  $moduleBase = [IO.Path]::GetDirectoryName($manifest)
  $modulePath = Join-Path $moduleBase $data.RootModule
  $loaded = @(Get-Module -Name $moduleName -All)
  if ($loaded.Count -gt 1 -or @($loaded | Where-Object { $_.Path -ine $modulePath -or $_.Version -ne [version]$data.ModuleVersion }).Count) { throw 'RecoveryConflictingLoadedModule' }
  $selected = if ($loaded.Count) { $loaded[0] } else { Import-Module -Name $manifest -PassThru -ErrorAction Stop }
  if ($selected.Name -cne $moduleName -or $selected.Path -ine $modulePath -or $selected.ModuleBase -ine $moduleBase -or $selected.Version -ne [version]$data.ModuleVersion) { throw 'RecoverySelectedModuleIdentityMismatch' }
  & $selected {
    param($binding)
    $script:policyTestBinding = $binding
  } ([pscustomobject]@{ Module = $selected; ModuleBase = $moduleBase; ModulePath = $modulePath; Promoted = ($null -ne $promoted) })
  $script:policyTestModuleName = $moduleName
}

InModuleScope -ModuleName $script:policyTestModuleName {
Describe 'Standing package-admission policy' -Tag 'Integration', 'CoordCustodyHandoff', 'Policy' {
  BeforeAll {
    $script:moduleRoot = $script:policyTestBinding.ModuleBase
    $script:sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $script:oldSettings = $global:settings; $script:oldKeys = $global:configRootKeys
    $script:boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
    $script:realAtomic = (Get-Command Write-CoordAtomicBytes).ScriptBlock
    foreach ($name in 'Invoke-CoordCustodyHandoff', 'New-CoordSuccessorCustodyPlan', 'ConvertTo-SuccessorPolicyBlock') {
      (Get-Command $name).Module.Path | Should -BeExactly $script:policyTestBinding.ModulePath
    }
    $script:schemaBytes = [IO.File]::ReadAllBytes((Join-Path $script:moduleRoot 'schemas/state-v1.schema.json'))
    $script:schemaHash = Get-CoordHash $script:schemaBytes
    $script:moduleVersion = (Import-PowerShellDataFile -LiteralPath (Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psd1')).ModuleVersion
    $script:thumb = '3B5E16C03B5E16C03B5E16C03B5E16C03B5E16C0'
    $script:requestHash = ('a' * 64); $script:resultHash = ('b' * 64)
    $script:custodyVersion = '0.1.13'
    $script:runId = 'run-' + [guid]::NewGuid().ToString('N')
    $script:runRoot = $null; $script:fixtureBase = $null
    function New-GoodPolicy([bool]$Enabled = $true) {
      [ordered]@{ enabled = $Enabled; signer = $thumb; minVersion = '0.1.14'
        schemaHashes = [ordered]@{ state = $schemaHash; request = $requestHash; result = $resultHash }; semanticRevision = 'sem-1' }
    }
    function Protect-PackageDirectory([string]$Path) {
      $acl = Get-Acl -LiteralPath $Path
      $acl.SetOwner([Security.Principal.SecurityIdentifier]::new($sid)); $acl.SetAccessRuleProtection($true, $false)
      foreach ($rule in @($acl.GetAccessRules($true, $false, [Security.Principal.SecurityIdentifier]))) { $acl.RemoveAccessRuleSpecific($rule) }
      foreach ($who in $sid, 'S-1-5-18', 'S-1-5-32-544') {
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($who), 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
      }
      Set-Acl -LiteralPath $Path -AclObject $acl
    }
    function Write-PackageJson([string]$Path, $Value) { [IO.File]::WriteAllBytes($Path, (ConvertTo-CoordStateBytes (ConvertTo-CoordElement $Value))) }
    function Get-PackageInventory([string]$Root) {
      @(Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object {
          $_.Extension -in '.ps1', '.psm1', '.psd1', '.json' -and -not (Test-CoordDescendant $_.FullName (Join-Path $Root 'tests')) } | ForEach-Object {
          $bytes = [IO.File]::ReadAllBytes($_.FullName)
          [ordered]@{ path = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\', '/'); sha256 = (Get-CoordHash $bytes).ToUpperInvariant(); size = [long]$bytes.LongLength }
        })
    }
    function New-PackageFixture([switch]$NoPolicy) {
      $base = switch ([Environment]::MachineName.ToUpperInvariant()) {
        UTAT022 { 'D:/ATAPArtifacts/_generated/Sprint0017/orch017-slice5-fixtures' }
        UTAT01 { 'C:/ATAPArtifacts/_generated/Sprint0017/orch017-slice5-fixtures' }
        default { throw 'Unknown package fixture host' }
      }
      $script:fixtureBase = $base
      $script:runRoot = Join-Path $base $script:runId
      $null = [IO.Directory]::CreateDirectory($script:runRoot)
      $script:fixtureRoot = Join-Path $script:runRoot ([guid]::NewGuid().ToString('N'))
      $script:fakeProgramData = Join-Path $fixtureRoot 'ProgramData'
      $script:stateRoot = Join-Path $fakeProgramData 'State'; $script:custodyRoot = Join-Path $fakeProgramData 'Custody'
      $script:backupRoot = Join-Path $fakeProgramData 'Backup'; $script:historyRoot = Join-Path $fakeProgramData 'RecoveryHistory'
      $script:boardRoot = Join-Path $fixtureRoot 'Board'; $script:inputRoot = Join-Path $fixtureRoot 'Inputs'
      foreach ($directory in $fixtureRoot, $fakeProgramData, $stateRoot, $custodyRoot, $backupRoot, $boardRoot, $inputRoot, $historyRoot) {
        $null = [IO.Directory]::CreateDirectory($directory); Protect-PackageDirectory $directory
      }
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
      $script:state = [ordered]@{ schemaVersion = 'Coordination-state-v1'; resourceId = 'package-fixture'; lineageId = 'lineage-package'
        registeredRoots = @([ordered]@{ registeredRootId = 'fixture'; path = $boardRoot }); generation = 'epoch-before'; committedRevision = 'head-1'
        committedOutputManifest = $manifest; custodyEvidence = $reference; compatibilityEvidence = $reference; admissionEvidence = @($reference)
        requests = @(); preparedOperations = @(); commitReceipts = @()
        claims = @([ordered]@{ claimId = 'held-claim'; resourceId = 'package-fixture'; taskId = '17.1'; scope = $scope
            holder = [ordered]@{ holderId = 'Worker'; sessionId = 'worker-1' }; generation = 'epoch-before'; claimRequestId = 'earlier-claim' })
        reservations = @([ordered]@{ reservationId = 'held-reservation'; resourceId = 'package-fixture'; requestId = 'unpublished'; taskId = '17.2'
            scope = $scope; generation = 'epoch-before' })
        mutationAdmission = [ordered]@{ status = 'Admitted'; reason = 'Disposable'; observedOutputs = @() } }
      Write-PackageJson $statePath $state
      $oldPackage = [ordered]@{ moduleVersion = $custodyVersion; files = @([ordered]@{ path = 'schemas/state-v1.schema.json'; digest = $schemaHash }, [ordered]@{ path = 'old.psm1'; digest = ('c' * 64) }) }
      $script:actors = @([ordered]@{ holderId = 'Coordinator'; sessionId = 'coordinator-1'; windowsSid = $sid; role = 'Coordinator' },
        [ordered]@{ holderId = 'Worker'; sessionId = 'worker-1'; windowsSid = $sid; role = 'Worker' })
      $script:witness = [ordered]@{ schemaVersion = 'Coordination-custody-v1'; admissionMode = 'Established'; custodianSid = $sid
        resourceId = 'package-fixture'; lineageId = 'lineage-package'; generation = 'epoch-before'; sprintId = '0017'; coordinatorId = 'Coordinator'
        statePath = $statePath; stateSha256 = Get-CoordHash ([IO.File]::ReadAllBytes($statePath)); pendingWrite = $null; boardLockPath = $boardLock
        actors = $actors; retiredActors = @(); authorizations = @(); existingTasks = @([ordered]@{ taskId = '17.32.b'; ancestorTaskIds = @() }); package = $oldPackage
        autoPackageAdmission = [ordered]@{ enabled = $true; signer = $thumb; minVersion = '0.1.14'
          schemaHashes = [ordered]@{ state = $schemaHash; request = $requestHash; result = $resultHash }; semanticRevision = 'sem-1' }
        future = [ordered]@{ text = 'preserved'; number = 1 } }
      if ($NoPolicy) { $script:witness.Remove('autoPackageAdmission') }
      Write-PackageJson $witnessPath $witness
      $script:attestation = [ordered]@{ kind = 'Coordination-package-attestation-v1'; moduleName = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
        moduleVersion = $moduleVersion; archiveSha256 = ('D' * 64); signerThumbprint = $thumb.ToLowerInvariant()
        stateSchemaSha256 = $schemaHash.ToUpperInvariant(); requestSchemaSha256 = $requestHash; resultSchemaSha256 = $resultHash
        coordinationSemanticRevision = 'sem-1'; buildId = 'build-1'; executionIds = @('exec-1'); createdUtc = '2026-11-13T11:00:00.0000000Z'
        finalProductionTestReceiptSha256 = ('e' * 64); tierReceiptSha256 = [ordered]@{ Production = ('f' * 64) }; files = (Get-PackageInventory $moduleRoot) }
      $script:attestationPath = Join-Path $inputRoot 'attestation.json'
      [IO.File]::WriteAllBytes($attestationPath, [Text.Encoding]::UTF8.GetBytes(($attestation | ConvertTo-Json -Depth 20)))
      $script:attestationPin = Get-CoordHash ([IO.File]::ReadAllBytes($attestationPath))
      $script:nupkgPath = Join-Path $inputRoot 'package.nupkg'
      [IO.File]::WriteAllBytes($nupkgPath, [byte[]](1..32))
      $script:opId = [guid]::NewGuid().ToString('D')
      $global:configRootKeys = @{}; $global:settings = @{}
      $values = @{ StateRootPath = $stateRoot; CustodyRecordPath = $witnessPath; ProtectedBackupRootPath = $backupRoot; RecoveryHistoryRootPath = $historyRoot
        SevenZipPath = 'C:/Program Files/7-Zip/7z.exe'; SevenZipSha256 = 'DC0493429FE28136FCB177A0E77C9875CBB3B0BFF5F2F8EEBA4DF302E98CEF76'
        MaxRequestBytes = 65536; MaxBatchBytes = 262144; MaxBatchRequests = 8; MaxDrainRequests = 16; MaxDrainBatches = 8; MaxDrainMilliseconds = 10000 }
      foreach ($key in $values.Keys) { $name = 'Orchestration' + $key; $global:configRootKeys[$name + 'ConfigRootKey'] = $name; $global:settings[$name] = $values[$key] }
      $null = Write-CoordRecoveryHistory -Action Initialize -Confirm:$false
      $script:atomicCalls = 0; $script:faultBefore = 0; $script:faultAfter = 0; $script:crashed = $false; $script:crashMode = $false
      $script:verifierCalls = [Collections.Generic.List[object]]::new()
    }
    function New-CandidateCopy {
      # ApplyPackage now always verifies a separate candidate root. This is a byte-identical copy of the module tree (minus
      # tests) standing in for the NEW installed package; it is only ever verified as bytes, never imported.
      $target = Join-Path $script:fixtureRoot 'Candidate'
      foreach ($file in Get-ChildItem -LiteralPath $script:moduleRoot -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($script:moduleRoot, $file.FullName)
        if ($relative -match '\A(tests)(\\|\z)') { continue }
        $destination = Join-Path $target $relative
        $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
        [IO.File]::WriteAllBytes($destination, [IO.File]::ReadAllBytes($file.FullName))
      }
      $script:candidateFor = $script:fixtureRoot
      $script:candidateRoot = [IO.Path]::GetFullPath($target).TrimEnd('\')
    }
    function Invoke-PackageApply {
      if ($script:candidateFor -cne $script:fixtureRoot -or -not $script:candidateRoot -or -not (Test-Path -LiteralPath $script:candidateRoot)) { New-CandidateCopy }
      Invoke-CoordCustodyHandoff -Mode ApplyPackage -OperationId $opId -AttestationPath $attestationPath -ExpectedAttestationSha256 $attestationPin -NupkgPath $nupkgPath -CandidateModuleRoot $script:candidateRoot -Confirm:$false
    }
    function Invoke-PackageRecover { Invoke-CoordCustodyHandoff -Mode RecoverPackage -OperationId $opId -Confirm:$false }
    function Get-PackageWitness { Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath)) }
    function Get-PackageMember($Element, [string]$Name) { $Element.GetProperty($Name).GetRawText() }

    # ---- v2 handoff fixture (adapted from CoordCustodyHandoff.Tests.ps1), with an optional policy block in the intent ----
    function Get-HandoffInventory([string]$Root) {
      $data = Import-PowerShellDataFile -LiteralPath (Join-Path $Root 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psd1')
      @{ moduleVersion = $data.ModuleVersion; files = @(Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object { $_.Extension -in '.ps1', '.psm1', '.psd1', '.json' -and -not (Test-CoordDescendant $_.FullName (Join-Path $Root 'tests')) } | ForEach-Object {
            @{ path = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\', '/'); digest = Get-CoordHash ([IO.File]::ReadAllBytes($_.FullName)) } }) }
    }
    function Set-PolicyTestSettings {
      $global:configRootKeys = @{}; $global:settings = @{}
      $values = @{ StateRootPath = $stateRoot; CustodyRecordPath = $witnessPath; ProtectedBackupRootPath = $backupRoot; RecoveryHistoryRootPath = $historyRoot
        SevenZipPath = 'C:/Program Files/7-Zip/7z.exe'; SevenZipSha256 = 'DC0493429FE28136FCB177A0E77C9875CBB3B0BFF5F2F8EEBA4DF302E98CEF76'
        MaxRequestBytes = 65536; MaxBatchBytes = 262144; MaxBatchRequests = 8; MaxDrainRequests = 16; MaxDrainBatches = 8; MaxDrainMilliseconds = 10000 }
      foreach ($key in $values.Keys) { $name = 'Orchestration' + $key; $global:configRootKeys[$name + 'ConfigRootKey'] = $name; $global:settings[$name] = $values[$key] }
    }
    function New-V2Fixture($IntentPolicy = $null, [switch]$ClearIntent, $WitnessPolicy = $null) {
      $base = switch ([Environment]::MachineName.ToUpperInvariant()) {
        UTAT022 { 'D:/ATAPArtifacts/_generated/Sprint0017/orch017-slice5-fixtures' }
        UTAT01 { 'C:/ATAPArtifacts/_generated/Sprint0017/orch017-slice5-fixtures' }
        default { throw 'Unknown policy fixture host' }
      }
      $script:fixtureBase = $base
      $script:runRoot = Join-Path $base $script:runId
      $null = [IO.Directory]::CreateDirectory($script:runRoot)
      $script:fixtureRoot = Join-Path $script:runRoot ([guid]::NewGuid().ToString('N'))
      $script:fakeProgramData = Join-Path $fixtureRoot 'ProgramData'
      $script:stateRoot = Join-Path $fakeProgramData 'State'; $script:custodyRoot = Join-Path $fakeProgramData 'Custody'
      $script:backupRoot = Join-Path $fakeProgramData 'Backup'; $script:historyRoot = Join-Path $fakeProgramData 'RecoveryHistory'
      $script:boardRoot = Join-Path $fixtureRoot 'Board'
      foreach ($directory in $fixtureRoot, $fakeProgramData, $stateRoot, $custodyRoot, $backupRoot, $boardRoot) {
        $null = [IO.Directory]::CreateDirectory($directory); Protect-PackageDirectory $directory
      }
      $script:statePath = Join-Path $stateRoot 'state.json'; $script:witnessPath = Join-Path $custodyRoot 'custody.json'
      $script:boardLock = Join-Path $boardRoot 'board.lock'
      [IO.File]::WriteAllBytes($boardLock, [byte[]]@()); [IO.File]::WriteAllBytes((Join-Path $custodyRoot 'resource.lock'), [byte[]]@())
      $manifest = [ordered]@{}
      foreach ($slot in 'markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml') {
        $path = Join-Path $boardRoot ($slot + '.bin'); $image = [Text.Encoding]::UTF8.GetBytes('unchanged ' + $slot)
        [IO.File]::WriteAllBytes($path, $image); $manifest[$slot] = @{ path = $path; digest = Get-CoordHash $image }
      }
      $reference = @{ reference = 'disposable-reference'; digest = ('0' * 64) }
      $script:state = [ordered]@{ schemaVersion = 'Coordination-state-v1'; resourceId = 'handoff-fixture'; lineageId = 'lineage-handoff'
        registeredRoots = @(@{ registeredRootId = 'fixture'; path = $boardRoot }); generation = 'epoch-before'; committedRevision = 'head-1'
        committedOutputManifest = $manifest; custodyEvidence = $reference; compatibilityEvidence = $reference; admissionEvidence = @($reference)
        requests = @(); claims = @(); reservations = @(); preparedOperations = @(); commitReceipts = @()
        mutationAdmission = @{ status = 'Admitted'; reason = 'Disposable'; observedOutputs = @() } }
      Write-PackageJson $statePath $state
      $oldRoot = 'C:/Program Files/PowerShell/Modules/ATAP.Utilities.BuildTooling.Orchestration.PowerShell/0.1.13'
      $oldPackage = Get-HandoffInventory $oldRoot
      $script:oldCoordinator = @{ holderId = 'Coordinator'; sessionId = 'old-coordinator'; windowsSid = $sid; role = 'Coordinator' }
      $script:oldWorker = @{ holderId = 'Worker'; sessionId = 'old-worker'; windowsSid = $sid; role = 'Worker' }
      $script:finalWorker = @{ holderId = 'Worker'; sessionId = 'new-worker'; windowsSid = $sid; role = 'Worker' }
      $script:witness = [ordered]@{ schemaVersion = 'Coordination-custody-v1'; admissionMode = 'Established'; custodianSid = $sid
        resourceId = 'handoff-fixture'; lineageId = 'lineage-handoff'; generation = 'epoch-before'; sprintId = '0017'; coordinatorId = 'Coordinator'
        statePath = $statePath; stateSha256 = Get-CoordHash ([IO.File]::ReadAllBytes($statePath)); pendingWrite = $null; boardLockPath = $boardLock
        actors = @($oldCoordinator, $oldWorker); retiredActors = @(); authorizations = @(); existingTasks = @(@{ taskId = '17.32.b'; ancestorTaskIds = @() }); package = $oldPackage
        future = @{ text = 'preserved'; number = 1 } }
      if ($null -ne $WitnessPolicy) { $script:witness['autoPackageAdmission'] = $WitnessPolicy }
      Write-PackageJson $witnessPath $witness
      $script:transitionId = [guid]::NewGuid().ToString('D')
      $targetBytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-CoordElement (Get-HandoffInventory $moduleRoot)).GetRawText())
      $oldPackageElement = (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath))).GetProperty('package')
      $script:plannerIntent = [ordered]@{ kind = 'SuccessorCustodyPlan-v2'; operationId = $transitionId; custodianSid = $sid
        resourceId = 'handoff-fixture'; lineageId = 'lineage-handoff'; generation = 'epoch-before'
        nextGeneration = ('epoch-' + [guid]::NewGuid().ToString('N')); priorCustodyGenerations = @(); committedRevision = 'head-1'
        holderId = 'Coordinator'; outgoingSessionId = 'old-coordinator'; successorSessionId = 'new-coordinator'
        statePath = $statePath; boardLockPath = $boardLock
        beforeStateSha256 = Get-CoordHash ([IO.File]::ReadAllBytes($statePath)); beforeWitnessSha256 = Get-CoordHash ([IO.File]::ReadAllBytes($witnessPath))
        oldPackageSha256 = Get-CoordHash ([Text.Encoding]::UTF8.GetBytes($oldPackageElement.GetRawText()))
        targetPackageSha256 = Get-CoordHash $targetBytes; stateSchemaSha256 = $schemaHash
        retiredActors = @($oldCoordinator, $oldWorker) }
      if ($ClearIntent) { $plannerIntent['autoPackageAdmission'] = $null }
      elseif ($null -ne $IntentPolicy) { $plannerIntent['autoPackageAdmission'] = $IntentPolicy }
      $plannerBytes = ConvertTo-CoordStateBytes (ConvertTo-CoordElement $plannerIntent)
      $script:packetData = [ordered]@{ kind = 'Coordination-custody-handoff-v1'; transitionId = $transitionId
        beforeStateBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($statePath)); beforeWitnessBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($witnessPath))
        plannerIntentBase64 = [Convert]::ToBase64String($plannerBytes); plannerIntentSha256 = Get-CoordHash $plannerBytes
        targetPackageBase64 = [Convert]::ToBase64String($targetBytes); targetPackageSha256 = Get-CoordHash $targetBytes
        oldModuleRoot = $oldRoot; codeDigest = Get-CoordHash ([IO.File]::ReadAllBytes($script:policyTestBinding.ModulePath))
        finalWorker = $finalWorker; workerUpdateId = [guid]::NewGuid().ToString('D'); workerApprovalReference = 'fixture-worker-approval'; initializeHistory = $true }
      $script:packetPath = Join-Path $fixtureRoot 'packet.json'
      Write-PackageJson $packetPath $packetData
      $script:packetPin = Get-CoordHash ([IO.File]::ReadAllBytes($packetPath))
      $script:attemptPath = Join-Path $custodyRoot ('handoff-' + $transitionId + '.once.json')
      Set-PolicyTestSettings
    }
    function Get-HandoffSnapshot { Invoke-CoordCustodyHandoff -Mode Inspect -PacketPath $packetPath -ExpectedPacketSha256 $packetPin }
    function New-HandoffAuthority {
      $snapshot = Get-HandoffSnapshot
      $start = [DateTimeOffset]::UtcNow.AddMinutes(-1).ToString('o'); $end = [DateTimeOffset]::UtcNow.AddMinutes(8).ToString('o')
      $script:exclusionPath = Join-Path $fixtureRoot ('exclusion-' + [guid]::NewGuid().ToString('N') + '.json')
      Write-PackageJson $exclusionPath @{ kind = 'Coordination-writer-exclusion-v1'; hostBootUtc = $boot; hosts = @('UTAT022', 'UTAT01')
        notBeforeUtc = $start; notAfterUtc = $end; allWritersHeld = $true; bothDropboxClosed = $true; reference = 'disposable-exclusion' }
      $script:exclusionPin = Get-CoordHash ([IO.File]::ReadAllBytes($exclusionPath))
      $grantData = @{ kind = 'Coordination-custody-handoff-approval-v1'; mode = 'Apply'; approvalId = [guid]::NewGuid().ToString('D')
        reference = ('disposable-authority-' + [guid]::NewGuid().ToString('N')); packetDigest = $packetPin; planDigest = $snapshot.PlanDigest
        codeDigest = $packetData.codeDigest; exclusionDigest = $exclusionPin; custodianSid = $sid; notBeforeUtc = $start; notAfterUtc = $end
        expectedPair = @{ state = Get-CoordHash ([IO.File]::ReadAllBytes($statePath)); witness = Get-CoordHash ([IO.File]::ReadAllBytes($witnessPath)) }
        expectedHistory = $snapshot.History; recovery = $null }
      $script:grantPath = Join-Path $fixtureRoot ('authority-' + $grantData.approvalId + '.json')
      Write-PackageJson $grantPath $grantData
      $script:grantPin = Get-CoordHash ([IO.File]::ReadAllBytes($grantPath))
    }
    function Invoke-V2Apply {
      New-HandoffAuthority
      Invoke-CoordCustodyHandoff -Mode Apply -PacketPath $packetPath -ExpectedPacketSha256 $packetPin -ApprovalPath $grantPath -ExpectedApprovalSha256 $grantPin -ExclusionPath $exclusionPath -ExpectedExclusionSha256 $exclusionPin -Confirm:$false
    }
    function Get-PolicyText($Witness) {
      $member = [Text.Json.JsonElement]::new()
      if ($Witness.TryGetProperty('autoPackageAdmission', [ref]$member)) { $member.GetRawText() } else { '<absent>' }
    }
  }
  BeforeEach {
    Mock Get-CoordProgramDataPath { $script:fakeProgramData }
    Mock Test-CoordPackageAttestation {
      [pscustomobject]@{ Valid = $true; ReasonCode = 'Valid'; Detail = $null; InstalledModuleVersion = $script:moduleVersion; AttestationPath = $AttestationPath }
    }
  }
  AfterAll {
    if ($script:runRoot -and (Test-Path -LiteralPath $script:runRoot)) { Remove-Item -LiteralPath $script:runRoot -Recurse -Force -ErrorAction SilentlyContinue }
    if ($script:fixtureBase -and (Test-Path -LiteralPath $script:fixtureBase) -and -not @(Get-ChildItem -LiteralPath $script:fixtureBase -Force).Count) {
      Remove-Item -LiteralPath $script:fixtureBase -Force -ErrorAction SilentlyContinue
    }
  }
  AfterEach {
    $global:settings = $script:oldSettings; $global:configRootKeys = $script:oldKeys
    if ($script:fixtureRoot -and (Test-Path -LiteralPath $script:fixtureRoot)) { Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue }
  }

  Context 'only a v2 handoff sets, carries, clears or kills the policy' {
    It 'sets the policy through a v2 handoff and reports the action in the plan' {
      New-V2Fixture -IntentPolicy (New-GoodPolicy)
      (Get-HandoffSnapshot).Metadata.policyAction | Should -BeExactly Set
      (Invoke-V2Apply).Status | Should -BeExactly HandoffHeld
      $after = Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath))
      $policy = $after.GetProperty('autoPackageAdmission')
      $policy.GetProperty('enabled').ValueKind.ToString() | Should -BeExactly True
      $policy.GetProperty('signer').GetString() | Should -BeExactly $thumb
      $policy.GetProperty('minVersion').GetString() | Should -BeExactly '0.1.14'
      $policy.GetProperty('schemaHashes').GetProperty('state').GetString() | Should -BeExactly $schemaHash
      $policy.GetProperty('semanticRevision').GetString() | Should -BeExactly 'sem-1'
      $after.GetProperty('generation').GetString() | Should -BeExactly $plannerIntent.nextGeneration
    }
    It 'carries an existing policy forward unchanged when the intent has no policy block' {
      New-V2Fixture -WitnessPolicy (New-GoodPolicy)
      $before = Get-PolicyText (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath)))
      (Get-HandoffSnapshot).Metadata.Contains('policyAction') | Should -BeFalse
      (Invoke-V2Apply).Status | Should -BeExactly HandoffHeld
      Get-PolicyText (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath))) | Should -BeExactly $before
    }
    It 'adds no policy member when neither the witness nor the intent has one' {
      New-V2Fixture
      (Invoke-V2Apply).Status | Should -BeExactly HandoffHeld
      Get-PolicyText (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath))) | Should -BeExactly '<absent>'
    }
    It 'clears the policy when the intent carries an explicit null' {
      New-V2Fixture -WitnessPolicy (New-GoodPolicy) -ClearIntent
      (Get-HandoffSnapshot).Metadata.policyAction | Should -BeExactly Cleared
      (Invoke-V2Apply).Status | Should -BeExactly HandoffHeld
      Get-PolicyText (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath))) | Should -BeExactly '<absent>'
    }
    It 'applies enabled=false as the kill switch without touching the other policy fields' {
      New-V2Fixture -WitnessPolicy (New-GoodPolicy) -IntentPolicy (New-GoodPolicy $false)
      (Invoke-V2Apply).Status | Should -BeExactly HandoffHeld
      $policy = (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath))).GetProperty('autoPackageAdmission')
      $policy.GetProperty('enabled').ValueKind.ToString() | Should -BeExactly False
      $policy.GetProperty('signer').GetString() | Should -BeExactly $thumb
      $policy.GetProperty('semanticRevision').GetString() | Should -BeExactly 'sem-1'
    }
    It 'rejects a malformed policy at plan time with its own code: <Code>' -ForEach @(
      @{ Code = 'InvalidPolicySigner'; Mutate = { $p = New-GoodPolicy; $p.signer = 'not-a-thumbprint'; $p } }
      @{ Code = 'InvalidPolicySigner'; Mutate = { $p = New-GoodPolicy; $p.signer = ('A' * 39); $p } }
      @{ Code = 'InvalidPolicyMinVersion'; Mutate = { $p = New-GoodPolicy; $p.minVersion = 'v1'; $p } }
      @{ Code = 'InvalidPolicyMinVersion'; Mutate = { $p = New-GoodPolicy; $p.minVersion = '0.1.017'; $p } }
      @{ Code = 'InvalidPolicySchemaHashes'; Mutate = { $p = New-GoodPolicy; $p.schemaHashes.state = 'abc'; $p } }
      @{ Code = 'InvalidPolicySchemaHashes'; Mutate = { $p = New-GoodPolicy; $p.schemaHashes.request = ('A' * 64); $p } }
      @{ Code = 'InvalidPolicySchemaHashes'; Mutate = { $p = New-GoodPolicy; $p.schemaHashes.Remove('result'); $p } }
      @{ Code = 'InvalidPolicySemanticRevision'; Mutate = { $p = New-GoodPolicy; $p.semanticRevision = '   '; $p } }
      @{ Code = 'InvalidPolicyEnabled'; Mutate = { $p = New-GoodPolicy; $p.enabled = 'yes'; $p } }
      @{ Code = 'InvalidPolicyShape'; Mutate = { $p = New-GoodPolicy; $p.Remove('semanticRevision'); $p } }
      @{ Code = 'InvalidPolicyShape'; Mutate = { $p = New-GoodPolicy; $p.extra = 1; $p } }
    ) {
      New-V2Fixture -IntentPolicy (& $Mutate)
      { Invoke-CoordCustodyHandoff -Mode Plan -PacketPath $packetPath -ExpectedPacketSha256 $packetPin } | Should -Throw ('*' + $Code + '*')
      Test-Path -LiteralPath $attemptPath | Should -BeFalse
      Test-Path -LiteralPath $historyRoot | Should -BeFalse
    }
  }

  Context 'a policy carried forward by a v2 handoff is validated like a new one' {
    It 'rejects a malformed carried-forward policy with the same code: <Code>' -ForEach @(
      @{ Code = 'InvalidPolicySigner'; Mutate = { $p = New-GoodPolicy; $p.signer = 'zz'; $p } }
      @{ Code = 'InvalidPolicyMinVersion'; Mutate = { $p = New-GoodPolicy; $p.minVersion = 'garbage'; $p } }
      @{ Code = 'InvalidPolicySchemaHashes'; Mutate = { $p = New-GoodPolicy; $p.schemaHashes.result = 'short'; $p } }
      @{ Code = 'InvalidPolicySemanticRevision'; Mutate = { $p = New-GoodPolicy; $p.semanticRevision = ''; $p } }
      @{ Code = 'InvalidPolicyShape'; Mutate = { $p = New-GoodPolicy; $p.extra = 'x'; $p } }
    ) {
      New-V2Fixture -WitnessPolicy (& $Mutate)
      { Invoke-CoordCustodyHandoff -Mode Plan -PacketPath $packetPath -ExpectedPacketSha256 $packetPin } | Should -Throw ('*' + $Code + '*')
      Test-Path -LiteralPath $attemptPath | Should -BeFalse
      Test-Path -LiteralPath $historyRoot | Should -BeFalse
    }
    It 'still lets an explicit intent replace or clear a malformed carried policy' {
      $bad = New-GoodPolicy; $bad.signer = 'zz'
      New-V2Fixture -WitnessPolicy $bad -ClearIntent
      (Invoke-V2Apply).Status | Should -BeExactly HandoffHeld
      Get-PolicyText (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath))) | Should -BeExactly '<absent>'
    }
    It 'carries a disabled but well-formed policy forward' {
      New-V2Fixture -WitnessPolicy (New-GoodPolicy $false)
      (Invoke-V2Apply).Status | Should -BeExactly HandoffHeld
      (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath))).GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly False
    }
  }

  Context 'every other custody.json writer preserves the policy' {
    BeforeAll {
      function Get-PolicySemantics($Witness) {
        $member = [Text.Json.JsonElement]::new()
        if (-not $Witness.TryGetProperty('autoPackageAdmission', [ref]$member)) { return '<absent>' }
        # Member order is canonical after a producer rewrite, so compare parsed values, not raw text.
        (ConvertTo-CoordStateBytes $member | ForEach-Object { [Text.Encoding]::UTF8.GetString($_) }) -join ''
      }
      function New-AppendProposal([byte[]]$Current, [string]$Mode) {
        $members = Get-CoordMembers (Read-CoordJsonBytes $Current)
        $actors = @($members['actors'].EnumerateArray() | ForEach-Object { $_.Clone() })
        $members['actors'] = $actors + @([ordered]@{ holderId = 'Worker'; sessionId = 'extra-worker'; windowsSid = $sid; role = 'Worker' })
        if ($Mode -ceq 'Drop') { $members.Remove('autoPackageAdmission') }
        if ($Mode -ceq 'Change') {
          $policy = Get-CoordMembers $members['autoPackageAdmission']; $policy['enabled'] = $false; $members['autoPackageAdmission'] = $policy
        }
        ,(ConvertTo-SuccessorPlanBytes $members)
      }
      function Invoke-WitnessAppend([string]$Mode) {
        $current = [IO.File]::ReadAllBytes($witnessPath)
        $proposal = New-AppendProposal $current $Mode
        Update-CoordWitness -HolderId 'Coordinator' -SessionId 'new-coordinator' -ExpectedWitnessBytes $current -ProposedWitnessBytes $proposal `
          -UpdateId ([guid]::NewGuid()) -ApprovalReference 'disposable-approval' -Confirm:$false
      }
    }
    It 'Update-CoordWitness keeps the policy byte for byte and refuses a delta that drops or changes it' {
      New-V2Fixture -IntentPolicy (New-GoodPolicy)
      (Invoke-V2Apply).Status | Should -BeExactly HandoffHeld
      $policyBefore = Get-PolicyText (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath)))
      $witnessBefore = [IO.File]::ReadAllBytes($witnessPath)
      { Invoke-WitnessAppend 'Drop' } | Should -Throw '*InvalidWitnessDelta*'
      { Invoke-WitnessAppend 'Change' } | Should -Throw '*InvalidWitnessDelta*'
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($witnessPath)) | Should -BeExactly ([Convert]::ToBase64String($witnessBefore))
      (Invoke-WitnessAppend 'Keep').Status | Should -BeExactly Updated
      $after = Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath))
      Get-PolicyText $after | Should -BeExactly $policyBefore
      $after.GetProperty('actors').GetArrayLength() | Should -Be 3
    }
    It 'the producer state writer keeps the policy (parsed values) through its re-serialization' {
      New-V2Fixture -IntentPolicy (New-GoodPolicy)
      (Invoke-V2Apply).Status | Should -BeExactly HandoffHeld
      $before = Get-PolicySemantics (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath)))
      $context = Read-CoordProducerContext -HolderId 'Coordinator' -SessionId 'new-coordinator' -Role Export
      try {
        $newState = Get-CoordMembers $context.State
        $newState['committedRevision'] = 'head-2'
        Save-CoordProducerState $context (ConvertTo-CoordElement $newState)
      } finally { try { $context.BoardLease.Dispose() } finally { $context.Lease.Dispose() } }
      $after = Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath))
      $after.GetProperty('pendingWrite').ValueKind.ToString() | Should -BeExactly Null
      Get-PolicySemantics $after | Should -BeExactly $before
      (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($statePath))).GetProperty('committedRevision').GetString() | Should -BeExactly 'head-2'
    }
    It 'the pending-write and durable-operation writers use the same serialization and keep the policy' {
      New-V2Fixture -WitnessPolicy (New-GoodPolicy)
      $bytes = [IO.File]::ReadAllBytes($witnessPath)
      $record = ConvertFrom-CoordElement (Read-CoordJsonBytes $bytes)
      $record.pendingWrite = @{ kind = 'Complete'; operationId = 'op-1' }
      $fenced = ConvertTo-CoordStateBytes (ConvertTo-CoordElement $record)
      $record.pendingWrite = $null
      $final = ConvertTo-CoordStateBytes (ConvertTo-CoordElement $record)
      Get-PolicySemantics (Read-CoordJsonBytes $fenced) | Should -BeExactly (Get-PolicySemantics (Read-CoordJsonBytes $bytes))
      Get-PolicySemantics (Read-CoordJsonBytes $final) | Should -BeExactly (Get-PolicySemantics (Read-CoordJsonBytes $bytes))
      # A second pass is stable, so repeated clerk writes never drift the policy.
      Get-CoordHash (ConvertTo-CoordStateBytes (ConvertTo-CoordElement (ConvertFrom-CoordElement (Read-CoordJsonBytes $final)))) | Should -BeExactly (Get-CoordHash $final)
    }
    It 'export and restore carry the exact custody bytes, so the policy survives byte for byte' {
      New-V2Fixture -WitnessPolicy (New-GoodPolicy)
      $custody = [IO.File]::ReadAllBytes($witnessPath)
      $stateBytes = [IO.File]::ReadAllBytes($statePath)
      $observed = [ordered]@{}
      foreach ($slot in 'markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml') {
        $path = $state.committedOutputManifest[$slot].path; $image = [IO.File]::ReadAllBytes($path)
        $observed[$slot] = @{ path = $path; digest = Get-CoordHash $image; bytesBase64 = [Convert]::ToBase64String($image) }
      }
      $bundle = New-CoordRecoverySnapshot -StateBytes $stateBytes -CustodyBytes $custody -ObservedOutputs $observed
      $verified = Test-CoordRestoreBundle -BundleBytes $bundle -ExpectedSha256 (Get-CoordHash $bundle) -ExpectedResourceId 'handoff-fixture' `
        -ExpectedLineageId 'lineage-handoff' -ExpectedGeneration 'epoch-before' -ExpectedCommittedRevision 'head-1' -MaxBundleBytes 67108864 -StateSchemaBytes $schemaBytes
      [Convert]::ToBase64String($verified.Custody.Bytes) | Should -BeExactly ([Convert]::ToBase64String($custody))
      Get-PolicyText (Read-CoordJsonBytes $verified.Custody.Bytes) | Should -BeExactly (Get-PolicyText (Read-CoordJsonBytes $custody))
    }
    It 'the resident host, launcher and upgrade script never write custody' {
      $resident = Join-Path $moduleRoot 'Resources/Resident'
      foreach ($name in 'Invoke-CoordClerkResident.ps1', 'Start-CoordClerkResident.ps1', 'Invoke-CoordPackageUpgrade.ps1') {
        $path = Join-Path $resident $name
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $text = [IO.File]::ReadAllText($path)
        $text | Should -Not -Match 'Write-CoordAtomicBytes'
        $text | Should -Not -Match 'Update-CoordWitness'
      }
      $host1 = [IO.File]::ReadAllText((Join-Path $resident 'Invoke-CoordClerkResident.ps1'))
      $host1 | Should -Not -Match '(?i)WriteAllBytes|WriteAllText|Set-Content|Out-File|Move-Item|\.Replace\(\$'
    }
  }

  Context 'ApplyPackage only reads the policy and can only switch it off' {
    It 'refuses when the policy is absent and writes nothing' {
      New-PackageFixture -NoPolicy
      $before = [IO.File]::ReadAllBytes($witnessPath)
      { Invoke-PackageApply } | Should -Throw '*PackagePolicyAbsent*'
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($witnessPath)) | Should -BeExactly ([Convert]::ToBase64String($before))
      Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '.once.json')) | Should -BeFalse
    }
    It 'can disable the policy but never re-enable it or change its other fields' {
      New-PackageFixture
      $beforePolicy = (Get-PackageWitness).GetProperty('autoPackageAdmission')
      $fields = @{}; foreach ($name in 'signer', 'minVersion', 'semanticRevision') { $fields[$name] = $beforePolicy.GetProperty($name).GetString() }
      $hashesBefore = $beforePolicy.GetProperty('schemaHashes').GetRawText()
      Mock Test-CoordPackageAttestation { [pscustomobject]@{ Valid = $false; ReasonCode = 'SignerMismatch'; Detail = 'x'; InstalledModuleVersion = $null; AttestationPath = $AttestationPath } }
      { Invoke-PackageApply } | Should -Throw '*policyDisable=Disabled*'
      $disabled = (Get-PackageWitness).GetProperty('autoPackageAdmission')
      $disabled.GetProperty('enabled').ValueKind.ToString() | Should -BeExactly False
      foreach ($name in $fields.Keys) { $disabled.GetProperty($name).GetString() | Should -BeExactly $fields[$name] }
      $disabled.GetProperty('schemaHashes').GetRawText() | Should -BeExactly $hashesBefore
      # A later, fully valid attestation does not re-enable it.
      Mock Test-CoordPackageAttestation { [pscustomobject]@{ Valid = $true; ReasonCode = 'Valid'; Detail = $null; InstalledModuleVersion = $script:moduleVersion; AttestationPath = $AttestationPath } }
      $witnessAfterDisable = [IO.File]::ReadAllBytes($witnessPath)
      $script:opId = [guid]::NewGuid().ToString('D')
      { Invoke-PackageApply } | Should -Throw '*PackagePolicyDisabled*'
      { Invoke-PackageRecover } | Should -Throw '*PackagePolicyDisabled*'
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($witnessPath)) | Should -BeExactly ([Convert]::ToBase64String($witnessAfterDisable))
      (Get-PackageWitness).GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly False
    }
    It 'turns a malformed standing policy into a disable, not an acceptance' {
      New-PackageFixture
      $members = Get-CoordMembers (Get-PackageWitness)
      $policy = Get-CoordMembers $members['autoPackageAdmission']; $policy['minVersion'] = 'garbage'; $members['autoPackageAdmission'] = $policy
      Write-CoordAtomicBytes -Path $witnessPath -ExpectedBytes ([IO.File]::ReadAllBytes($witnessPath)) -Bytes (ConvertTo-SuccessorPlanBytes $members)
      { Invoke-PackageApply } | Should -Throw '*InvalidPackagePolicy*policyDisable=Disabled*'
      (Get-PackageWitness).GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly False
      (Get-PackageWitness).GetProperty('package').GetProperty('moduleVersion').GetString() | Should -BeExactly $custodyVersion
    }
  }
}
}

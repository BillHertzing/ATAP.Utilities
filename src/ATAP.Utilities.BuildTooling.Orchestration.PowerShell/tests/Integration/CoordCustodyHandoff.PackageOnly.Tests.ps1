#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

# Package-only custody transition (Invoke-CoordCustodyHandoff -Mode ApplyPackage / RecoverPackage).
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
    $script:packageTestBinding = $binding
  } ([pscustomobject]@{ Module = $selected; ModuleBase = $moduleBase; ModulePath = $modulePath; Promoted = ($null -ne $promoted) })
  $script:packageTestModuleName = $moduleName
}

InModuleScope -ModuleName $script:packageTestModuleName {
Describe 'Package-only custody transition on disposable selected-module fixtures' -Tag 'Integration', 'CoordCustodyHandoff', 'PackageOnly' {
  BeforeAll {
    $script:moduleRoot = $script:packageTestBinding.ModuleBase
    $script:sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $script:oldSettings = $global:settings; $script:oldKeys = $global:configRootKeys
    $script:realAtomic = (Get-Command Write-CoordAtomicBytes).ScriptBlock
    $script:realRecord = (Get-Command New-CoordRecoveryRecord).ScriptBlock
    $script:realResource = (Get-Command Enter-CoordResourceLease).ScriptBlock
    foreach ($name in 'Invoke-CoordCustodyHandoff', 'New-CoordPackageAdmissionPlan', 'Test-CoordPackageAttestation', 'Write-CoordAtomicBytes') {
      $command = Get-Command $name
      $command.Module.Path | Should -BeExactly $script:packageTestBinding.ModulePath
    }
    $script:schemaBytes = [IO.File]::ReadAllBytes((Join-Path $script:moduleRoot 'schemas/state-v1.schema.json'))
    $script:schemaHash = Get-CoordHash $script:schemaBytes
    $script:moduleVersion = (Import-PowerShellDataFile -LiteralPath (Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psd1')).ModuleVersion
    $script:thumb = '3B5E16C03B5E16C03B5E16C03B5E16C03B5E16C0'
    $script:requestHash = ('a' * 64); $script:resultHash = ('b' * 64)
    $script:custodyVersion = '0.1.13'
    $script:runId = 'run-' + [guid]::NewGuid().ToString('N')
    $script:runRoot = $null; $script:fixtureBase = $null

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
    function New-CandidateCopy([string]$Name = 'Candidate') {
      # A byte-identical copy of the module tree (minus tests) standing in for the NEW installed package. It is
      # only ever verified as bytes by the running module; it is never imported.
      $target = Join-Path $script:fixtureRoot $Name
      foreach ($file in Get-ChildItem -LiteralPath $script:moduleRoot -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($script:moduleRoot, $file.FullName)
        if ($relative -match '\A(tests)(\\|\z)') { continue }
        $destination = Join-Path $target $relative
        $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
        [IO.File]::WriteAllBytes($destination, [IO.File]::ReadAllBytes($file.FullName))
      }
      $script:candidateFor = $script:fixtureRoot
      $script:candidateRoot = [IO.Path]::GetFullPath($target).TrimEnd('\')
      $script:candidateRoot
    }
    function New-PackageFixture {
      $base = switch ([Environment]::MachineName.ToUpperInvariant()) {
        UTAT022 { 'D:/ATAPArtifacts/_generated/Sprint0017/orch017-slice2-fixtures' }
        UTAT01 { 'C:/ATAPArtifacts/_generated/Sprint0017/orch017-slice2-fixtures' }
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
    function Invoke-PackageApply {
      # ApplyPackage always verifies a separate candidate root (mandatory parameter): one copy per fixture, made on first use.
      if ($script:candidateFor -cne $script:fixtureRoot -or -not $script:candidateRoot -or -not (Test-Path -LiteralPath $script:candidateRoot)) { $null = New-CandidateCopy }
      Invoke-CoordCustodyHandoff -Mode ApplyPackage -OperationId $opId -AttestationPath $attestationPath -ExpectedAttestationSha256 $attestationPin -NupkgPath $nupkgPath -CandidateModuleRoot $script:candidateRoot -Confirm:$false
    }
    function Invoke-PackageRecover { Invoke-CoordCustodyHandoff -Mode RecoverPackage -OperationId $opId -Confirm:$false }
    function Get-PackageWitness { Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath)) }
    function Get-PackageMember($Element, [string]$Name) { $Element.GetProperty($Name).GetRawText() }
    function Set-PackageFault([int]$Before = 0, [int]$After = 0, [switch]$Crash) {
      # -Crash models process death at the boundary: every later atomic write also fails until $script:crashed is cleared.
      $script:atomicCalls = 0; $script:faultBefore = $Before; $script:faultAfter = $After; $script:crashed = $false; $script:crashMode = $Crash.IsPresent
      Mock Write-CoordAtomicBytes {
        $script:atomicCalls++
        if ($script:crashed) { throw 'DisposableProcessDead' }
        if ($script:atomicCalls -eq $script:faultBefore) { if ($script:crashMode) { $script:crashed = $true }; throw 'DisposableBeforeAtomic' }
        & $script:realAtomic -Path $Path -ExpectedBytes $ExpectedBytes -Bytes $Bytes
        if ($script:atomicCalls -eq $script:faultAfter) { if ($script:crashMode) { $script:crashed = $true }; throw 'DisposableAfterAtomic' }
      }
    }
  }
  BeforeEach {
    Mock Get-CoordProgramDataPath { $script:fakeProgramData }
    New-PackageFixture
    Mock Test-CoordPackageAttestation {
      $script:verifierCalls.Add(@{ CurrentVersion = $CurrentVersion; ModuleRoot = $ModuleRoot; AttestationPath = $AttestationPath; Policy = $Policy; NupkgPath = $NupkgPath })
      [pscustomobject]@{ Valid = $true; ReasonCode = 'Valid'; Detail = $null; InstalledModuleVersion = $script:moduleVersion; AttestationPath = $AttestationPath }
    }
  }
  AfterAll {
    # Always remove this run's folder (and the shared parent when nothing else is left), even after failures.
    if ($script:runRoot -and (Test-Path -LiteralPath $script:runRoot)) { Remove-Item -LiteralPath $script:runRoot -Recurse -Force -ErrorAction SilentlyContinue }
    if ($script:fixtureBase -and (Test-Path -LiteralPath $script:fixtureBase) -and -not @(Get-ChildItem -LiteralPath $script:fixtureBase -Force).Count) {
      Remove-Item -LiteralPath $script:fixtureBase -Force -ErrorAction SilentlyContinue
    }
  }
  AfterEach {
    $global:settings = $script:oldSettings; $global:configRootKeys = $script:oldKeys
    if ($script:fixtureRoot -and (Test-Path -LiteralPath $script:fixtureRoot)) { Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue }
  }

  It 'swaps only the package: held claims and reservations survive byte for byte, generation and actors are unchanged' {
    $stateBefore = [IO.File]::ReadAllBytes($statePath)
    $quartetBefore = @($quartetPaths.Values | ForEach-Object { Get-CoordHash ([IO.File]::ReadAllBytes($_)) })
    $before = Get-PackageWitness
    $result = Invoke-PackageApply
    $result.Status | Should -BeExactly PackageAdmitted
    $result.StateChanged | Should -BeFalse
    $result.GenerationChanged | Should -BeFalse
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($statePath)) | Should -BeExactly ([Convert]::ToBase64String($stateBefore))
    @($quartetPaths.Values | ForEach-Object { Get-CoordHash ([IO.File]::ReadAllBytes($_)) }) | Should -Be $quartetBefore
    $after = Get-PackageWitness
    foreach ($name in 'generation', 'actors', 'retiredActors', 'authorizations', 'existingTasks', 'future', 'autoPackageAdmission', 'custodianSid', 'stateSha256', 'pendingWrite', 'sprintId', 'coordinatorId') {
      Get-PackageMember $after $name | Should -BeExactly (Get-PackageMember $before $name)
    }
    $after.GetProperty('package').GetProperty('moduleVersion').GetString() | Should -BeExactly $moduleVersion
    $history = $after.GetProperty('history')
    $history.GetArrayLength() | Should -Be 1
    $history[0].GetProperty('kind').GetString() | Should -BeExactly 'PackageAdmission-v1'
    $history[0].GetProperty('operationId').GetString() | Should -BeExactly $opId
    $history[0].GetProperty('fromVersion').GetString() | Should -BeExactly $custodyVersion
    (([IO.File]::ReadAllText($statePath) | ConvertFrom-Json).claims[0].claimId) | Should -BeExactly 'held-claim'
    (Read-CoordRecoveryHistory $historyRoot).Ordinal | Should -Be 2
    Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '.once.json')) | Should -BeTrue
    foreach ($file in 'before.witness.bin', 'before.state.bin', 'attestation.json', 'after.witness.bin', 'final.receipt.json') {
      Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '/' + $file)) | Should -BeTrue
    }
    Should -Invoke Test-CoordPackageAttestation -Times 1 -Exactly -ParameterFilter { $CurrentVersion -ceq '0.1.13' -and $ModuleRoot -ceq $script:candidateRoot }
    Should -Invoke Test-CoordPackageAttestation -Times 0 -ParameterFilter { $ModuleRoot -ceq $script:moduleRoot }
    @(Get-ChildItem -LiteralPath $stateRoot -Filter '*stage*').Count | Should -Be 0
  }
  It 'makes WhatIf effect-free' {
    $result = Invoke-CoordCustodyHandoff -Mode ApplyPackage -OperationId $opId -AttestationPath $attestationPath -ExpectedAttestationSha256 $attestationPin -NupkgPath $nupkgPath -CandidateModuleRoot (Join-Path $script:fixtureRoot 'Candidate') -WhatIf
    $result.Status | Should -BeExactly ProposedOnly
    Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '.once.json')) | Should -BeFalse
  }
  It 'keeps the v2 and package modes in separate parameter sets and requires the attestation pin' {
    { Invoke-CoordCustodyHandoff -Mode ApplyPackage -PacketPath $attestationPath -ExpectedPacketSha256 $attestationPin -Confirm:$false } | Should -Throw
    { Invoke-CoordCustodyHandoff -Mode Apply -OperationId $opId -Confirm:$false } | Should -Throw
    { Invoke-CoordCustodyHandoff -Mode RecoverPackage -OperationId $opId -NupkgPath $nupkgPath -Confirm:$false } | Should -Throw
    { Invoke-CoordCustodyHandoff -Mode ApplyPackage -OperationId $opId -AttestationPath $attestationPath -NupkgPath $nupkgPath -Confirm:$false -ErrorAction Stop } | Should -Throw
    { Invoke-CoordCustodyHandoff -Mode RecoverPackage -OperationId $opId -Confirm:$false } | Should -Throw '*PackageRecoveryHasNoKnownOrigin*'
    { Invoke-CoordCustodyHandoff -Mode ApplyPackage -OperationId $opId -AttestationPath $attestationPath -ExpectedAttestationSha256 ('0' * 64) -NupkgPath $nupkgPath -CandidateModuleRoot (New-CandidateCopy) -Confirm:$false } | Should -Throw '*HandoffInputPinMismatch*'
    # The candidate root is mandatory for ApplyPackage and absent from RecoverPackage's set (checked by metadata: no prompt).
    $attributes = @((Get-Command Invoke-CoordCustodyHandoff).Parameters['CandidateModuleRoot'].Attributes | Where-Object { $_ -is [Management.Automation.ParameterAttribute] })
    @($attributes | Where-Object { $_.ParameterSetName -ceq 'Package' -and $_.Mandatory }).Count | Should -Be 1
    @($attributes | Where-Object { $_.ParameterSetName -ceq 'PackageRecover' }).Count | Should -Be 0
    Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '.once.json')) | Should -BeFalse
  }
  It 'refuses a disabled policy without writing anything' {
    $members = Get-CoordMembers (Get-PackageWitness)
    $policy = Get-CoordMembers $members['autoPackageAdmission']; $policy['enabled'] = $false; $members['autoPackageAdmission'] = $policy
    $disabledWitness = ConvertTo-SuccessorPlanBytes $members
    Write-CoordAtomicBytes -Path $witnessPath -ExpectedBytes ([IO.File]::ReadAllBytes($witnessPath)) -Bytes $disabledWitness
    $witnessBefore = [IO.File]::ReadAllBytes($witnessPath)
    { Invoke-PackageApply } | Should -Throw '*PackagePolicyDisabled*'
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($witnessPath)) | Should -BeExactly ([Convert]::ToBase64String($witnessBefore))
    Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '.once.json')) | Should -BeFalse
    Should -Invoke Test-CoordPackageAttestation -Times 0 -Exactly
  }
  It 'refuses a consumed operation id without disabling the policy' {
    $null = Invoke-PackageApply
    $policyBefore = Get-PackageMember (Get-PackageWitness) 'autoPackageAdmission'
    { Invoke-PackageApply } | Should -Throw '*PackageApplyNotFresh*'
    Get-PackageMember (Get-PackageWitness) 'autoPackageAdmission' | Should -BeExactly $policyBefore
  }
  It 'disables the policy and leaves the package untouched when the attestation fails' {
    Mock Test-CoordPackageAttestation { [pscustomobject]@{ Valid = $false; ReasonCode = 'SignatureInvalid'; Detail = 'x'; InstalledModuleVersion = $null; AttestationPath = $AttestationPath } }
    $stateBefore = Get-CoordHash ([IO.File]::ReadAllBytes($statePath))
    { Invoke-PackageApply } | Should -Throw '*PackageAttestationRejected:SignatureInvalid*policyDisable=Disabled*'
    $after = Get-PackageWitness
    $after.GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly False
    $after.GetProperty('package').GetProperty('moduleVersion').GetString() | Should -BeExactly $custodyVersion
    $after.GetProperty('pendingWrite').ValueKind.ToString() | Should -BeExactly Null
    Get-CoordHash ([IO.File]::ReadAllBytes($statePath)) | Should -BeExactly $stateBefore
    Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '.once.json')) | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '.disabled.json')) | Should -BeTrue
    # A confirmed disable needs no hold marker.
    Test-Path -LiteralPath (Join-Path $custodyRoot 'package-admission.hold.json') | Should -BeFalse
    $script:opId = [guid]::NewGuid().ToString('D')
    { Invoke-PackageApply } | Should -Throw '*PackagePolicyDisabled*'
  }
  It 'refuses without disabling when the quartet changed after the leases were taken, before the attempt' {
    Mock Enter-CoordResourceLease {
      $lease = & $script:realResource -StateDirectory $StateDirectory
      [IO.File]::WriteAllText($script:quartetPaths['markdown'], 'changed after snapshot')
      $lease
    }
    $witnessBefore = [IO.File]::ReadAllBytes($witnessPath)
    { Invoke-PackageApply } | Should -Throw '*PackageQuartetChangedBeforeAttempt*policyDisable=NotDisabled_NotNowRefusal*'
    Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '.once.json')) | Should -BeFalse
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($witnessPath)) | Should -BeExactly ([Convert]::ToBase64String($witnessBefore))
    (Get-PackageWitness).GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly True
    (Get-PackageWitness).GetProperty('package').GetProperty('moduleVersion').GetString() | Should -BeExactly $custodyVersion
  }
  It 'treats <Code> as a busy collision: refuses without disabling or consuming anything' -ForEach @(
    @{ Code = 'PendingWritePresent' }, @{ Code = 'OperationInFlight' }, @{ Code = 'MutationNotAdmitted' }
  ) {
    $script:planCode = $Code
    Mock New-CoordPackageAdmissionPlan { throw $script:planCode }
    $witnessBefore = [IO.File]::ReadAllBytes($witnessPath)
    { Invoke-PackageApply } | Should -Throw ('*' + $Code + '*policyDisable=NotDisabled_NotNowRefusal*')
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($witnessPath)) | Should -BeExactly ([Convert]::ToBase64String($witnessBefore))
    Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '.once.json')) | Should -BeFalse
    $script:opId = [guid]::NewGuid().ToString('D')
  }
  It 'disables the policy for trust and uncertainty failure <Code>' -ForEach @(
    @{ Code = 'PackageNotNewer' }, @{ Code = 'PackageBelowMinVersion' }, @{ Code = 'SchemaHashMismatch' }
    @{ Code = 'SemanticRevisionMismatch' }, @{ Code = 'PackageSignerMismatch' }, @{ Code = 'UnexpectedDisposableError' }
  ) {
    $script:planCode = $Code
    Mock New-CoordPackageAdmissionPlan { throw $script:planCode }
    { Invoke-PackageApply } | Should -Throw ('*' + $Code + '*policyDisable=Disabled*')
    (Get-PackageWitness).GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly False
    Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '.once.json')) | Should -BeFalse
  }
  It 'fails closed and disables when the quartet changes during the write' {
    $script:atomicCalls = 0
    Mock Write-CoordAtomicBytes {
      $script:atomicCalls++
      & $script:realAtomic -Path $Path -ExpectedBytes $ExpectedBytes -Bytes $Bytes
      if ($script:atomicCalls -eq 2) { [IO.File]::WriteAllText($script:quartetPaths['boardHtml'], 'changed during write') }
    }
    { Invoke-PackageApply } | Should -Throw '*AttemptConsumed*PackageQuartetChanged*'
    (Get-PackageWitness).GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly False
    Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '/final.receipt.json')) | Should -BeFalse
    { Invoke-PackageRecover } | Should -Throw '*PackagePolicyDisabled*'
  }
  It 'completes an interrupted apply with RecoverPackage after a process death <Name>' -ForEach @(
    @{ Name = 'before the fence write'; FaultBefore = 1; FaultAfter = 0; Calls = 2 }
    @{ Name = 'after the fence write'; FaultBefore = 0; FaultAfter = 1; Calls = 1 }
    @{ Name = 'before the target write'; FaultBefore = 2; FaultAfter = 0; Calls = 1 }
    @{ Name = 'after the target write'; FaultBefore = 0; FaultAfter = 2; Calls = 0 }
  ) {
    $stateBefore = [IO.File]::ReadAllBytes($statePath)
    $before = Get-PackageWitness
    Set-PackageFault -Before $FaultBefore -After $FaultAfter -Crash
    { Invoke-PackageApply } | Should -Throw '*AttemptConsumed*policyDisable=DisableUnsafeOrFailed_Held*'
    # Died before disabling: the policy is still on, the once-file exists and no receipt was written.
    (Get-PackageWitness).GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly True
    Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '.once.json')) | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '/final.receipt.json')) | Should -BeFalse
    $script:crashed = $false; $script:faultBefore = 0; $script:faultAfter = 0
    $callsBefore = $script:atomicCalls
    $result = Invoke-PackageRecover
    $result.Status | Should -BeExactly PackageAdmitted
    $result.Recovered | Should -BeTrue
    ($script:atomicCalls - $callsBefore) | Should -Be $Calls
    $after = Get-PackageWitness
    $after.GetProperty('package').GetProperty('moduleVersion').GetString() | Should -BeExactly $moduleVersion
    $after.GetProperty('pendingWrite').ValueKind.ToString() | Should -BeExactly Null
    $after.GetProperty('history').GetArrayLength() | Should -Be 1
    Get-PackageMember $after 'generation' | Should -BeExactly (Get-PackageMember $before 'generation')
    Get-PackageMember $after 'actors' | Should -BeExactly (Get-PackageMember $before 'actors')
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($statePath)) | Should -BeExactly ([Convert]::ToBase64String($stateBefore))
    Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '/final.receipt.json')) | Should -BeTrue
    @(Get-ChildItem -LiteralPath $custodyRoot -Filter ('package-' + $opId + '.recover-*.once.json')).Count | Should -Be 1
    (Read-CoordRecoveryHistory $historyRoot).Pending | Should -BeNullOrEmpty
    # A second recovery of a completed operation verifies and returns the same receipt.
    (Invoke-PackageRecover).Status | Should -BeExactly PackageAdmitted
  }
  It 'disables the policy on a handled interruption and then refuses to recover it' {
    Set-PackageFault -After 1
    { Invoke-PackageApply } | Should -Throw '*AttemptConsumed*DisposableAfterAtomic*policyDisable=Disabled*'
    $after = Get-PackageWitness
    $after.GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly False
    $after.GetProperty('pendingWrite').ValueKind.ToString() | Should -BeExactly Null
    $after.GetProperty('package').GetProperty('moduleVersion').GetString() | Should -BeExactly $custodyVersion
    { Invoke-PackageRecover } | Should -Throw '*PackagePolicyDisabled*'
  }
  It 'holds fenced when the disabling write is itself unsafe, then resolves the exact pending history on recovery' {
    $script:failReceiptOnce = $true
    Mock New-CoordRecoveryRecord {
      if ($Path.EndsWith('.receipt.json') -and $script:failReceiptOnce) { $script:failReceiptOnce = $false; throw 'DisposableHistoryReceiptFailure' }
      & $script:realRecord -Path $Path -Record $Record
    }
    { Invoke-PackageApply } | Should -Throw '*AttemptConsumed*DisposableHistoryReceiptFailure*policyDisable=DisableUnsafeOrFailed_Held*'
    $held = Get-PackageWitness
    $held.GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly True
    $held.GetProperty('pendingWrite').GetProperty('kind').GetString() | Should -BeExactly PackageAdmission
    (Read-CoordRecoveryHistory $historyRoot).Pending | Should -Not -BeNullOrEmpty
    (Invoke-PackageRecover).Status | Should -BeExactly PackageAdmitted
    (Read-CoordRecoveryHistory $historyRoot).Pending | Should -BeNullOrEmpty
    (Get-PackageWitness).GetProperty('package').GetProperty('moduleVersion').GetString() | Should -BeExactly $moduleVersion
  }
  It 'never touches state.json or a board file in any package mode' {
    $watched = @($statePath) + @($quartetPaths.Values)
    $stamps = @{}; foreach ($path in $watched) { $stamps[$path] = (Get-Item -LiteralPath $path).LastWriteTimeUtc.Ticks }
    $null = Invoke-PackageApply
    $null = Invoke-PackageRecover
    foreach ($path in $watched) { (Get-Item -LiteralPath $path).LastWriteTimeUtc.Ticks | Should -Be $stamps[$path] }
  }
  It 'refuses recovery for an operation with no once-file' {
    { Invoke-PackageRecover } | Should -Throw '*PackageRecoveryHasNoKnownOrigin*'
  }

  Context 'H1: the running (admitted) module verifies and admits a separate candidate root' {
    It 'verifies the candidate root, not the running root, and records it for recovery' {
      $candidate = New-CandidateCopy
      $result = Invoke-CoordCustodyHandoff -Mode ApplyPackage -OperationId $opId -AttestationPath $attestationPath -ExpectedAttestationSha256 $attestationPin -NupkgPath $nupkgPath -CandidateModuleRoot $candidate -Confirm:$false
      $result.Status | Should -BeExactly PackageAdmitted
      Should -Invoke Test-CoordPackageAttestation -Times 1 -Exactly -ParameterFilter { $ModuleRoot -ceq $script:candidateRoot -and $CurrentVersion -ceq '0.1.13' }
      Should -Invoke Test-CoordPackageAttestation -Times 0 -ParameterFilter { $ModuleRoot -ceq $script:moduleRoot }
      $once = ConvertFrom-CoordElement (Read-CoordJsonBytes ([IO.File]::ReadAllBytes((Join-Path $custodyRoot ('package-' + $opId + '.once.json')))))
      $once.candidateModuleRoot | Should -BeExactly $candidate
      (Get-PackageWitness).GetProperty('package').GetProperty('moduleVersion').GetString() | Should -BeExactly $moduleVersion
    }
    It 'refuses a candidate that is the running module root, before anything is written' {
      $witnessBefore = [IO.File]::ReadAllBytes($witnessPath)
      { Invoke-CoordCustodyHandoff -Mode ApplyPackage -OperationId $opId -AttestationPath $attestationPath -ExpectedAttestationSha256 $attestationPin -NupkgPath $nupkgPath -CandidateModuleRoot $script:moduleRoot -Confirm:$false } | Should -Throw '*PackageCandidateMustDifferFromRunningModule*'
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($witnessPath)) | Should -BeExactly ([Convert]::ToBase64String($witnessBefore))
      Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '.once.json')) | Should -BeFalse
      Should -Invoke Test-CoordPackageAttestation -Times 0 -Exactly
    }
    It 'refuses a missing candidate root, before anything is written' {
      { Invoke-CoordCustodyHandoff -Mode ApplyPackage -OperationId $opId -AttestationPath $attestationPath -ExpectedAttestationSha256 $attestationPin -NupkgPath $nupkgPath -CandidateModuleRoot (Join-Path $script:fixtureRoot 'NoSuchCandidate') -Confirm:$false } | Should -Throw '*PackageCandidateModuleRootMissing*'
      Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '.once.json')) | Should -BeFalse
      (Get-PackageWitness).GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly True
    }
    It 'fails closed when the candidate bytes differ from the attested inventory (verifier mocked valid)' {
      $candidate = New-CandidateCopy
      $victim = Get-ChildItem -LiteralPath $candidate -Recurse -File -Filter '*.ps1' | Select-Object -First 1
      [IO.File]::AppendAllText($victim.FullName, "`n# tampered after attestation")
      { Invoke-CoordCustodyHandoff -Mode ApplyPackage -OperationId $opId -AttestationPath $attestationPath -ExpectedAttestationSha256 $attestationPin -NupkgPath $nupkgPath -CandidateModuleRoot $candidate -Confirm:$false } | Should -Throw '*AttemptConsumed*'
      Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '/final.receipt.json')) | Should -BeFalse
      (Get-PackageWitness).GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly False
    }
    It 'recovers against the candidate root recorded by the apply attempt, not the running root' {
      $candidate = New-CandidateCopy
      Set-PackageFault -After 1 -Crash
      { Invoke-CoordCustodyHandoff -Mode ApplyPackage -OperationId $opId -AttestationPath $attestationPath -ExpectedAttestationSha256 $attestationPin -NupkgPath $nupkgPath -CandidateModuleRoot $candidate -Confirm:$false } | Should -Throw '*AttemptConsumed*'
      $script:crashed = $false; $script:faultBefore = 0; $script:faultAfter = 0
      $script:verifierCalls.Clear()
      (Invoke-PackageRecover).Status | Should -BeExactly PackageAdmitted
      $script:verifierCalls.Count | Should -Be 1
      $script:verifierCalls[0].ModuleRoot | Should -BeExactly $candidate
    }
  }

  Context 'Mandatory candidate root: the running module can never vouch for itself' {
    It 'RecoverPackage refuses an interrupted attempt that recorded no candidate root' {
      Set-PackageFault -After 1 -Crash
      { Invoke-PackageApply } | Should -Throw '*AttemptConsumed*'
      $script:crashed = $false; $script:faultBefore = 0; $script:faultAfter = 0
      $oncePath = Join-Path $custodyRoot ('package-' + $opId + '.once.json')
      $once = ConvertFrom-CoordElement (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($oncePath)))
      $once.Remove('candidateModuleRoot')
      Write-PackageJson $oncePath $once
      { Invoke-PackageRecover } | Should -Throw '*PackageRecoveryCandidateRootMissing*'
    }
    It 'RecoverPackage refuses a recorded candidate that is the running module root' {
      Set-PackageFault -After 1 -Crash
      { Invoke-PackageApply } | Should -Throw '*AttemptConsumed*'
      $script:crashed = $false; $script:faultBefore = 0; $script:faultAfter = 0
      $oncePath = Join-Path $custodyRoot ('package-' + $opId + '.once.json')
      $once = ConvertFrom-CoordElement (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($oncePath)))
      $once.candidateModuleRoot = $script:moduleRoot
      Write-PackageJson $oncePath $once
      { Invoke-PackageRecover } | Should -Throw '*PackageCandidateMustDifferFromRunningModule*'
    }
  }

  Context 'M6: a disable that cannot be confirmed is never silent' {
    It 'leaves a hold marker, reports it in structured data, and refuses the next ApplyPackage until reconciled' {
      Set-PackageFault -After 1 -Crash
      $failure = try { Invoke-PackageApply } catch { $_ }
      $failure.Exception.Message | Should -BeLike '*AttemptConsumed*policyDisable=DisableUnsafeOrFailed_Held*holdMarker=Written*'
      $failure.Exception.Data['CoordPackagePolicyDisable'] | Should -BeExactly 'DisableUnsafeOrFailed_Held'
      $failure.Exception.Data['CoordPackageHoldMarker'] | Should -BeExactly 'Written'
      $holdPath = Join-Path $custodyRoot 'package-admission.hold.json'
      Test-Path -LiteralPath $holdPath | Should -BeTrue
      $hold = ConvertFrom-CoordElement (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($holdPath)))
      $hold.operationId | Should -BeExactly $opId
      $hold.policyDisable | Should -BeExactly 'DisableUnsafeOrFailed_Held'
      # Policy is still on, so only the marker stops a new attempt.
      (Get-PackageWitness).GetProperty('autoPackageAdmission').GetProperty('enabled').ValueKind.ToString() | Should -BeExactly True
      $script:crashed = $false; $script:faultBefore = 0; $script:faultAfter = 0
      $recoverId = $opId
      $script:opId = [guid]::NewGuid().ToString('D')
      $next = try { Invoke-PackageApply } catch { $_ }
      $next.Exception.Message | Should -BeLike '*PackageAdmissionHeldUnsafeDisable*'
      Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '.once.json')) | Should -BeFalse
      # Exact recovery of the operation that left the marker reconciles and removes it.
      $script:opId = $recoverId
      $recovered = Invoke-PackageRecover
      $recovered.Status | Should -BeExactly PackageAdmitted
      $recovered.HoldCleared | Should -BeTrue
      Test-Path -LiteralPath $holdPath | Should -BeFalse
    }
    It 'treats any pre-existing hold path (even a directory) as already held, and still blocks' {
      $null = [IO.Directory]::CreateDirectory((Join-Path $custodyRoot 'package-admission.hold.json'))
      $witnessBefore = [IO.File]::ReadAllBytes($witnessPath)
      $failure = try { Invoke-PackageApply } catch { $_ }
      $failure.Exception.Message | Should -BeLike '*PackageAdmissionHeldUnsafeDisable*'
      $failure.Exception.Data['CoordPackageConsumed'] | Should -BeFalse
      Test-Path -LiteralPath (Join-Path $custodyRoot ('package-' + $opId + '.once.json')) | Should -BeFalse
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($witnessPath)) | Should -BeExactly ([Convert]::ToBase64String($witnessBefore))
      Should -Invoke Test-CoordPackageAttestation -Times 0 -Exactly
    }
    It 'does not leave a marker after a busy refusal or a confirmed disable' {
      Mock New-CoordPackageAdmissionPlan { throw 'PendingWritePresent' }
      { Invoke-PackageApply } | Should -Throw '*PendingWritePresent*'
      Test-Path -LiteralPath (Join-Path $custodyRoot 'package-admission.hold.json') | Should -BeFalse
    }
  }

  Context 'L4: outcomes carry structured codes' {
    It 'busy collision: NotNow, unconsumed, code from data' {
      Mock New-CoordPackageAdmissionPlan { throw 'OperationInFlight' }
      $failure = try { Invoke-PackageApply } catch { $_ }
      $failure.Exception.Data['CoordPackageCode'] | Should -BeExactly 'OperationInFlight'
      $failure.Exception.Data['CoordPackageClass'] | Should -BeExactly 'NotNow'
      $failure.Exception.Data['CoordPackageConsumed'] | Should -BeFalse
      $failure.Exception.Data['CoordPackagePolicyDisable'] | Should -BeExactly 'NotDisabled_NotNowRefusal'
    }
    It 'trust failure: Held with the confirmed disable' {
      Mock Test-CoordPackageAttestation { [pscustomobject]@{ Valid = $false; ReasonCode = 'SignatureInvalid'; Detail = 'x'; InstalledModuleVersion = $null; AttestationPath = $AttestationPath } }
      $failure = try { Invoke-PackageApply } catch { $_ }
      $failure.Exception.Data['CoordPackageCode'] | Should -BeExactly 'PackageAttestationRejected'
      $failure.Exception.Data['CoordPackageClass'] | Should -BeExactly 'Held'
      $failure.Exception.Data['CoordPackageConsumed'] | Should -BeFalse
      $failure.Exception.Data['CoordPackagePolicyDisable'] | Should -BeExactly 'Disabled'
    }
    It 'consumed attempt: Held and flagged consumed' {
      Set-PackageFault -After 1
      $failure = try { Invoke-PackageApply } catch { $_ }
      $failure.Exception.Data['CoordPackageConsumed'] | Should -BeTrue
      $failure.Exception.Data['CoordPackageClass'] | Should -BeExactly 'Held'
    }
  }
}
}

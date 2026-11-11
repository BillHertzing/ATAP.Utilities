BeforeDiscovery {
  $sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  $moduleName = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
  $promoted = [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
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
  $sourceVersion = (Import-PowerShellDataFile -LiteralPath $sourceManifest).ModuleVersion
  if ($data.RootModule -cne ($moduleName + '.psm1') -or $data.ModuleVersion -cne $sourceVersion) { throw 'RecoverySelectedModuleVersionMismatch' }
  $moduleBase = [IO.Path]::GetDirectoryName($manifest)
  $modulePath = Join-Path $moduleBase $data.RootModule
  $loaded = @(Get-Module -Name $moduleName -All)
  if ($loaded.Count -gt 1 -or @($loaded | Where-Object { $_.Path -ine $modulePath -or $_.Version -ne [version]$data.ModuleVersion }).Count) { throw 'RecoveryConflictingLoadedModule' }
  $selected = if ($loaded.Count) { $loaded[0] } else { Import-Module -Name $manifest -PassThru -ErrorAction Stop }
  if ($selected.Name -cne $moduleName -or $selected.Path -ine $modulePath -or $selected.ModuleBase -ine $moduleBase -or $selected.Version -ne [version]$data.ModuleVersion) { throw 'RecoverySelectedModuleIdentityMismatch' }
  & $selected {
    param($binding)
    $script:handoffTestBinding = $binding
  } ([pscustomobject]@{ Module = $selected; ModuleBase = $moduleBase; ModulePath = $modulePath; Promoted = ($null -ne $promoted) })
  $script:handoffTestModuleName = $moduleName
}

InModuleScope -ModuleName $script:handoffTestModuleName {
Describe 'Custodian handoff on disposable selected-module fixtures' -Tag 'Integration','CoordCustodyHandoff' {
  BeforeAll {
    $script:moduleRoot=$script:handoffTestBinding.ModuleBase
    $script:sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $script:oldSettings=$global:settings;$script:oldKeys=$global:configRootKeys
    $script:boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
    $script:realAtomic=(Get-Command Write-CoordAtomicBytes).ScriptBlock
    $script:realHistory=(Get-Command Write-CoordRecoveryHistory).ScriptBlock
    $script:realRecord=(Get-Command New-CoordRecoveryRecord).ScriptBlock
    $script:realResource=(Get-Command Enter-CoordResourceLease).ScriptBlock
    foreach($name in 'Invoke-CoordCustodyHandoff','New-CoordSuccessorCustodyPlan','Get-CoordSuccessorCheckpoint','New-CoordRecoverySnapshot','Write-CoordAtomicBytes'){
      $command=Get-Command $name
      $command.Module.Path|Should -BeExactly $script:handoffTestBinding.ModulePath
      if($script:handoffTestBinding.Promoted){$command.ScriptBlock.File|Should -BeExactly $script:handoffTestBinding.ModulePath}
    }
    function Protect-HandoffDirectory([string]$Path){
      $acl=Get-Acl -LiteralPath $Path
      $acl.SetOwner([Security.Principal.SecurityIdentifier]::new($sid));$acl.SetAccessRuleProtection($true,$false)
      foreach($rule in @($acl.GetAccessRules($true,$false,[Security.Principal.SecurityIdentifier]))){$acl.RemoveAccessRuleSpecific($rule)}
      foreach($who in $sid,'S-1-5-18','S-1-5-32-544'){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($who),'FullControl','ContainerInherit,ObjectInherit','None','Allow'))}
      Set-Acl -LiteralPath $Path -AclObject $acl
    }
    function Write-HandoffJson([string]$Path,$Value){[IO.File]::WriteAllBytes($Path,(ConvertTo-CoordStateBytes (ConvertTo-CoordElement $Value)))}
    function Get-HandoffInventory([string]$Root){
      $data=Import-PowerShellDataFile -LiteralPath (Join-Path $Root 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psd1')
      @{moduleVersion=$data.ModuleVersion;files=@(Get-ChildItem -LiteralPath $Root -Recurse -File|Where-Object {$_.Extension -in '.ps1','.psm1','.psd1','.json' -and -not (Test-CoordDescendant $_.FullName (Join-Path $Root 'tests'))}|ForEach-Object {@{path=[IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/');digest=Get-CoordHash ([IO.File]::ReadAllBytes($_.FullName))}})}
    }
    function New-HandoffFixture([switch]$RetainWorker){
      $base=switch([Environment]::MachineName.ToUpperInvariant()){
        UTAT022 {'D:/ATAPArtifacts/_generated/Sprint0017/stream-c-filesystem-recovery-module-20261110/AdapterFixtures'}
        UTAT01 {'C:/ATAPArtifacts/_generated/Sprint0017/stream-c-filesystem-recovery-module-20261110/AdapterFixtures'}
        default {throw 'Unknown handoff fixture host'}
      }
      $script:fixtureRoot=Join-Path $base ([guid]::NewGuid().ToString('N'))
      $script:fakeProgramData=Join-Path $fixtureRoot 'ProgramData'
      $script:stateRoot=Join-Path $fakeProgramData 'State';$script:custodyRoot=Join-Path $fakeProgramData 'Custody'
      $script:backupRoot=Join-Path $fakeProgramData 'Backup';$script:historyRoot=Join-Path $fakeProgramData 'RecoveryHistory'
      $script:boardRoot=Join-Path $fixtureRoot 'Board'
      foreach($directory in $fixtureRoot,$fakeProgramData,$stateRoot,$custodyRoot,$backupRoot,$boardRoot){
        $null=[IO.Directory]::CreateDirectory($directory);Protect-HandoffDirectory $directory
      }
      $script:statePath=Join-Path $stateRoot 'state.json';$script:witnessPath=Join-Path $custodyRoot 'custody.json'
      $script:boardLock=Join-Path $boardRoot 'board.lock'
      [IO.File]::WriteAllBytes($boardLock,[byte[]]@());[IO.File]::WriteAllBytes((Join-Path $custodyRoot 'resource.lock'),[byte[]]@())
      $manifest=[ordered]@{}
      foreach($slot in 'markdown','boardHtml','proceduralDetailsHtml','accomplishedHtml'){
        $path=Join-Path $boardRoot ($slot+'.bin');$image=[Text.Encoding]::UTF8.GetBytes('unchanged '+$slot)
        [IO.File]::WriteAllBytes($path,$image);$manifest[$slot]=@{path=$path;digest=Get-CoordHash $image}
      }
      $reference=@{reference='disposable-reference';digest=('0'*64)}
      $script:state=[ordered]@{schemaVersion='Coordination-state-v1';resourceId='handoff-fixture';lineageId='lineage-handoff'
        registeredRoots=@(@{registeredRootId='fixture';path=$boardRoot});generation='epoch-before';committedRevision='head-1'
        committedOutputManifest=$manifest;custodyEvidence=$reference;compatibilityEvidence=$reference;admissionEvidence=@($reference)
        requests=@();claims=@();reservations=@();preparedOperations=@();commitReceipts=@()
        mutationAdmission=@{status='Admitted';reason='Disposable';observedOutputs=@()}}
      Write-HandoffJson $statePath $state
      $oldRoot='C:/Program Files/PowerShell/Modules/ATAP.Utilities.BuildTooling.Orchestration.PowerShell/0.1.13'
      $oldPackage=Get-HandoffInventory $oldRoot
      $script:oldCoordinator=@{holderId='Coordinator';sessionId='old-coordinator';windowsSid=$sid;role='Coordinator'}
      $script:oldWorker=@{holderId='Worker';sessionId='old-worker';windowsSid=$sid;role='Worker'}
      $script:finalWorker=@{holderId='Worker';sessionId='new-worker';windowsSid=$sid;role='Worker'}
      $actors=@($oldCoordinator,$oldWorker)
      if($RetainWorker){$actors+=@($finalWorker)}
      $script:witness=[ordered]@{schemaVersion='Coordination-custody-v1';admissionMode='Established';custodianSid=$sid
        resourceId='handoff-fixture';lineageId='lineage-handoff';generation='epoch-before';sprintId='0017';coordinatorId='Coordinator'
        statePath=$statePath;stateSha256=Get-CoordHash ([IO.File]::ReadAllBytes($statePath));pendingWrite=$null;boardLockPath=$boardLock
        actors=$actors;retiredActors=@();authorizations=@();existingTasks=@(@{taskId='17.32.b';ancestorTaskIds=@()});package=$oldPackage
        future=@{text='preserved';number=1}}
      Write-HandoffJson $witnessPath $witness
      $script:transitionId=[guid]::NewGuid().ToString('D')
      $targetBytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-CoordElement (Get-HandoffInventory $moduleRoot)).GetRawText())
      $oldPackageElement=(Read-CoordJsonBytes ([IO.File]::ReadAllBytes($witnessPath))).GetProperty('package')
      $script:plannerIntent=[ordered]@{kind='SuccessorCustodyPlan-v2';operationId=$transitionId;custodianSid=$sid
        resourceId='handoff-fixture';lineageId='lineage-handoff';generation='epoch-before'
        nextGeneration=('epoch-'+[guid]::NewGuid().ToString('N'));priorCustodyGenerations=@();committedRevision='head-1'
        holderId='Coordinator';outgoingSessionId='old-coordinator';successorSessionId='new-coordinator'
        statePath=$statePath;boardLockPath=$boardLock
        beforeStateSha256=Get-CoordHash ([IO.File]::ReadAllBytes($statePath));beforeWitnessSha256=Get-CoordHash ([IO.File]::ReadAllBytes($witnessPath))
        oldPackageSha256=Get-CoordHash ([Text.Encoding]::UTF8.GetBytes($oldPackageElement.GetRawText()))
        targetPackageSha256=Get-CoordHash $targetBytes;stateSchemaSha256=Get-CoordHash ([IO.File]::ReadAllBytes((Join-Path $moduleRoot 'schemas/state-v1.schema.json')))
        retiredActors=@($oldCoordinator,$oldWorker)}
      $plannerBytes=ConvertTo-CoordStateBytes (ConvertTo-CoordElement $plannerIntent)
      $script:packetData=[ordered]@{kind='Coordination-custody-handoff-v1';transitionId=$transitionId
        beforeStateBase64=[Convert]::ToBase64String([IO.File]::ReadAllBytes($statePath));beforeWitnessBase64=[Convert]::ToBase64String([IO.File]::ReadAllBytes($witnessPath))
        plannerIntentBase64=[Convert]::ToBase64String($plannerBytes);plannerIntentSha256=Get-CoordHash $plannerBytes
        targetPackageBase64=[Convert]::ToBase64String($targetBytes);targetPackageSha256=Get-CoordHash $targetBytes
        oldModuleRoot=$oldRoot;codeDigest=Get-CoordHash ([IO.File]::ReadAllBytes($script:handoffTestBinding.ModulePath))
        finalWorker=$finalWorker;workerUpdateId=[guid]::NewGuid().ToString('D');workerApprovalReference='fixture-worker-approval';initializeHistory=$true}
      $script:packetPath=Join-Path $fixtureRoot 'packet.json'
      Write-HandoffJson $packetPath $packetData
      $script:packetPin=Get-CoordHash ([IO.File]::ReadAllBytes($packetPath))
      $script:attemptPath=Join-Path $custodyRoot ('handoff-'+$transitionId+'.once.json')
      $global:configRootKeys=@{};$global:settings=@{}
      $values=@{StateRootPath=$stateRoot;CustodyRecordPath=$witnessPath;ProtectedBackupRootPath=$backupRoot;RecoveryHistoryRootPath=$historyRoot
        SevenZipPath='C:/Program Files/7-Zip/7z.exe';SevenZipSha256='DC0493429FE28136FCB177A0E77C9875CBB3B0BFF5F2F8EEBA4DF302E98CEF76'
        MaxRequestBytes=65536;MaxBatchBytes=262144;MaxBatchRequests=8;MaxDrainRequests=16;MaxDrainBatches=8;MaxDrainMilliseconds=10000}
      foreach($key in $values.Keys){$name='Orchestration'+$key;$global:configRootKeys[$name+'ConfigRootKey']=$name;$global:settings[$name]=$values[$key]}
      $script:atomicCalls=0;$script:interruptBefore=0;$script:interruptAfter=0;$script:failInit=$false
    }
    function Get-HandoffSnapshot {
      Invoke-CoordCustodyHandoff -Mode Inspect -PacketPath $packetPath -ExpectedPacketSha256 $packetPin
    }
    function New-HandoffAuthority([string]$Mode='Apply',[string]$Action='ContinuePlanner'){
      $snapshot=Get-HandoffSnapshot
      $start=[DateTimeOffset]::UtcNow.AddMinutes(-1).ToString('o');$end=[DateTimeOffset]::UtcNow.AddMinutes(8).ToString('o')
      $script:exclusionPath=Join-Path $fixtureRoot ('exclusion-'+[guid]::NewGuid().ToString('N')+'.json')
      Write-HandoffJson $exclusionPath @{kind='Coordination-writer-exclusion-v1';hostBootUtc=$boot;hosts=@('UTAT022','UTAT01')
        notBeforeUtc=$start;notAfterUtc=$end;allWritersHeld=$true;bothDropboxClosed=$true;reference='disposable-exclusion'}
      $script:exclusionPin=Get-CoordHash ([IO.File]::ReadAllBytes($exclusionPath))
      $recovery=$null
      if($Mode -ceq 'Recover'){
        $recovery=@{priorAttemptDigest=Get-CoordHash ([IO.File]::ReadAllBytes($attemptPath));checkpoint=$snapshot.Checkpoint;action=$Action
          historyPendingDigest=$snapshot.History.pendingDigest;historyOutcome=$(if($snapshot.History.condition -ceq 'Pending'){'Committed'}else{'none'})
          workerAttemptDigest=$snapshot.LastWorkerAttemptDigest
          workerUpdateId=$(if($Action -cin @('AcknowledgeWorkerAfter','Finalize')){$snapshot.WorkerUpdateId}else{[guid]::NewGuid().ToString('D')})}
      }
      $script:grantData=@{kind='Coordination-custody-handoff-approval-v1';mode=$Mode;approvalId=[guid]::NewGuid().ToString('D')
        reference=('disposable-authority-'+[guid]::NewGuid().ToString('N'));packetDigest=$packetPin;planDigest=$snapshot.PlanDigest
        codeDigest=$packetData.codeDigest;exclusionDigest=$exclusionPin;custodianSid=$sid;notBeforeUtc=$start;notAfterUtc=$end
        expectedPair=@{state=Get-CoordHash ([IO.File]::ReadAllBytes($statePath));witness=Get-CoordHash ([IO.File]::ReadAllBytes($witnessPath))}
        expectedHistory=$snapshot.History;recovery=$recovery}
      $script:grantPath=Join-Path $fixtureRoot ('authority-'+$grantData.approvalId+'.json')
      Write-HandoffJson $grantPath $grantData
      $script:grantPin=Get-CoordHash ([IO.File]::ReadAllBytes($grantPath))
    }
    function Invoke-HandoffFixture([string]$Mode='Apply'){
      Invoke-CoordCustodyHandoff -Mode $Mode -PacketPath $packetPath -ExpectedPacketSha256 $packetPin -ApprovalPath $grantPath -ExpectedApprovalSha256 $grantPin -ExclusionPath $exclusionPath -ExpectedExclusionSha256 $exclusionPin -Confirm:$false
    }
    function Set-HandoffAtomicFault([int]$Before=0,[int]$After=0){
      $script:interruptBefore=$Before;$script:interruptAfter=$After
      Mock Write-CoordAtomicBytes {
        $script:atomicCalls++
        if($script:atomicCalls -eq $script:interruptBefore){throw 'DisposableBeforeAtomic'}
        & $script:realAtomic -Path $Path -ExpectedBytes $ExpectedBytes -Bytes $Bytes
        if($script:atomicCalls -eq $script:interruptAfter){throw 'DisposableAfterAtomic'}
      }
    }
  }
  BeforeEach {
    Mock Get-CoordProgramDataPath { $script:fakeProgramData }
    New-HandoffFixture
  }
  AfterEach {$global:settings=$script:oldSettings;$global:configRootKeys=$script:oldKeys}

  It 'applies exact two retirements, fresh generation and one Worker append with retained backup/history' {
    New-HandoffAuthority
    $result=Invoke-HandoffFixture
    $result.Status|Should -BeExactly HandoffHeld
    $result.WorkerOutcome|Should -BeExactly OrdinaryReceiptComplete
    $after=[IO.File]::ReadAllText($witnessPath)|ConvertFrom-Json
    $after.actors.Count|Should -Be 2
    $after.retiredActors.Count|Should -Be 2
    $after.generation|Should -BeExactly $plannerIntent.nextGeneration
    ([IO.File]::ReadAllText($statePath)|ConvertFrom-Json).mutationAdmission.status|Should -BeExactly Admitted
    (Get-HandoffSnapshot).FinalReceipt|Should -BeExactly VerifiedCurrent
    (Read-CoordRecoveryHistory $historyRoot).Ordinal|Should -Be 4
    Test-Path -LiteralPath (Join-Path $custodyRoot ('handoff-'+$transitionId+'/before.bundle.json'))|Should -BeTrue
  }
  It 'retains the exact already designated Worker without appending an extra actor' {
    New-HandoffFixture -RetainWorker
    New-HandoffAuthority
    $result=Invoke-HandoffFixture
    $result.WorkerOutcome|Should -BeExactly RetainedDesignatedWorker
    (Read-CoordRecoveryHistory $historyRoot).Ordinal|Should -Be 3
    @(Get-ChildItem -LiteralPath $custodyRoot -Filter '*.update-*').Count|Should -Be 0
  }
  It 'makes WhatIf effect-free before reading a packet or opening custody' {
    $result=Invoke-CoordCustodyHandoff -Mode Apply -PacketPath 'C:/missing-custody-packet.json' -ExpectedPacketSha256 ('0'*64) -WhatIf
    $result.Status|Should -BeExactly ProposedOnly
    Test-Path -LiteralPath $attemptPath|Should -BeFalse
  }
  It 'rejects noncanonical mode <Value> before any mutation' -ForEach @(
    @{Value='apply'};@{Value='aPpLy'};@{Value='plan'};@{Value='inspect'};@{Value='recover'}
  ){
    {Invoke-CoordCustodyHandoff -Mode $Value -PacketPath $packetPath -ExpectedPacketSha256 $packetPin -Confirm:$false}|Should -Throw
    Test-Path -LiteralPath $attemptPath|Should -BeFalse
    Test-Path -LiteralPath $historyRoot|Should -BeFalse
  }
  It 'requires independent authority and exclusion pins before protected operational reads' {
    {Invoke-CoordCustodyHandoff -Mode Apply -PacketPath 'C:/missing-packet.json' -ExpectedPacketSha256 ('0'*64) -Confirm:$false}|Should -Throw '*IndependentlySuppliedAuthorityPinsRequired*'
    Test-Path -LiteralPath $attemptPath|Should -BeFalse
  }
  It 'rechecks quartet under custody before consuming an attempt' {
    New-HandoffAuthority
    Mock Enter-CoordResourceLease {
      $lease=& $script:realResource -StateDirectory $StateDirectory
      [IO.File]::WriteAllText($script:state.committedOutputManifest.markdown.path,'changed after snapshot')
      $lease
    }
    {Invoke-HandoffFixture}|Should -Throw '*QuartetChangedBeforeAttempt*'
    Test-Path -LiteralPath $attemptPath|Should -BeFalse
    Test-Path -LiteralPath $historyRoot|Should -BeFalse
  }
  It 'preserves a consumed initialization attempt and continues only under fresh exact recovery' {
    New-HandoffAuthority
    $script:failInit=$true
    Mock Write-CoordRecoveryHistory {
      if($Action -ceq 'Initialize' -and $script:failInit){
        $script:failInit=$false
        if(-not [IO.File]::Exists($script:attemptPath)){throw 'AttemptWasNotFirst'}
        throw 'DisposableInitializeFailure'
      }
      $parameters=@{Action=$Action;Confirm=$false}
      if($ExpectedIntentDigest){$parameters.ExpectedIntentDigest=$ExpectedIntentDigest}
      if($Outcome){$parameters.Outcome=$Outcome}
      & $script:realHistory @parameters
    }
    {Invoke-HandoffFixture}|Should -Throw '*AttemptConsumed*'
    (Get-HandoffSnapshot).History.condition|Should -BeExactly Empty
    New-HandoffAuthority Recover ContinueInitialization
    (Invoke-HandoffFixture Recover).Status|Should -BeExactly HandoffHeld
  }
  It 'continues a pinned partial planner checkpoint without replaying the original Apply' {
    New-HandoffAuthority
    Set-HandoffAtomicFault -Before 2
    {Invoke-HandoffFixture}|Should -Throw '*AttemptConsumed*'
    (Get-HandoffSnapshot).Checkpoint|Should -BeExactly FencedBeforeState
    New-HandoffAuthority Recover ContinuePlanner
    (Invoke-HandoffFixture Recover).Status|Should -BeExactly HandoffHeld
    (Read-CoordRecoveryHistory $historyRoot).Ordinal|Should -Be 4
  }
  It 'holds consumed-before Worker append and uses a fresh update identity for explicit continuation' {
    New-HandoffAuthority
    Set-HandoffAtomicFault -Before 4
    {Invoke-HandoffFixture}|Should -Throw '*AttemptConsumed*'
    $snapshot=Get-HandoffSnapshot
    $snapshot.Checkpoint|Should -BeExactly Target
    $snapshot.WorkerEvidence|Should -BeExactly BeforeOrPartialAudit
    New-HandoffAuthority Recover RetryWorkerBefore
    (Invoke-HandoffFixture Recover).Status|Should -BeExactly HandoffHeld
  }
  It 'acknowledges an exact after Worker image without forging the missing ordinary receipt or retrying it' {
    New-HandoffAuthority
    $originalApplyPin=$grantPin
    Set-HandoffAtomicFault -After 4
    {Invoke-HandoffFixture}|Should -Throw '*AttemptConsumed*'
    (Get-HandoffSnapshot).WorkerEvidence|Should -BeExactly OrdinaryReceiptMissing
    New-HandoffAuthority Recover AcknowledgeWorkerAfter
    $result=Invoke-HandoffFixture Recover
    $result.WorkerOutcome|Should -BeExactly ReconciledObservedAfter_OrdinaryReceiptMissing
    Test-Path -LiteralPath ($witnessPath+'.update-'+$packetData.workerUpdateId+'.receipt.json')|Should -BeFalse
    $script:atomicCalls|Should -Be 4
    (Get-HandoffSnapshot).FinalReceipt|Should -BeExactly VerifiedCurrent
    # A known consumed Apply is real authority, but cannot acknowledge the
    # observed after-image whose ordinary Worker receipt was never written.
    $receipt=Get-Content -LiteralPath $result.ReceiptPath -Raw|ConvertFrom-Json -AsHashtable
    $receipt.completionApprovalDigest=$originalApplyPin
    Write-HandoffJson $result.ReceiptPath $receipt
    {Get-HandoffSnapshot}|Should -Throw '*AcknowledgementMismatch*'
  }
  It 'refuses an invalid recovery action before resolving retained pending history or writing a recovery marker' {
    New-HandoffAuthority
    Mock New-CoordRecoveryRecord {
      if($Path.EndsWith('.receipt.json')){throw 'DisposableHistoryReceiptFailure'}
      & $script:realRecord -Path $Path -Record $Record
    }
    {Invoke-HandoffFixture}|Should -Throw '*AttemptConsumed*'
    $before=Get-HandoffSnapshot
    $before.History.condition|Should -BeExactly Pending
    New-HandoffAuthority Recover InvalidAction
    {Invoke-HandoffFixture Recover}|Should -Throw '*RecoveryActionInvalid*'
    (Get-HandoffSnapshot).History.pendingDigest|Should -BeExactly $before.History.pendingDigest
    @(Get-ChildItem -LiteralPath $custodyRoot -Filter '*.recover-*.once.json').Count|Should -Be 0
  }
}
}


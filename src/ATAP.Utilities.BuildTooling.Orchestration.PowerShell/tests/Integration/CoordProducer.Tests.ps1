BeforeAll {
  Import-Module PSFramework -MinimumVersion 1.14.457 -ErrorAction Stop
  $script:moduleRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  foreach ($file in Get-ChildItem (Join-Path $moduleRoot 'private') -Filter '*.ps1') { . $file.FullName }
  . (Join-Path $moduleRoot 'public/Submit-CoordRequest.ps1')
  . (Join-Path $moduleRoot 'public/Invoke-CoordClerk.ps1')
  . (Join-Path $moduleRoot 'public/Get-CoordResult.ps1')
  . (Join-Path $moduleRoot 'public/Export-CoordState.ps1')
  $script:sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $script:fixtureRoot = Join-Path ([IO.Path]::GetFullPath((Join-Path $moduleRoot '../..'))) ('_generated/Sprint0017/CloseStreams/C/Producer-' + [guid]::NewGuid().ToString('N'))
  $null = [IO.Directory]::CreateDirectory($fixtureRoot)
  $script:priorSettings = $global:settings
  $script:priorKeys = $global:configRootKeys
  function Protect-FixturePath([string]$Path) {
    $acl = Get-Acl -LiteralPath $Path
    $acl.SetOwner([Security.Principal.SecurityIdentifier]::new($sid))
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($acl.GetAccessRules($true, $false, [Security.Principal.SecurityIdentifier]))) { $null = $acl.RemoveAccessRuleSpecific($rule) }
    foreach ($who in @($sid, 'S-1-5-18', 'S-1-5-32-544')) {
      $rule = if ([IO.Directory]::Exists($Path)) {
        [Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($who), 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
      } else { [Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($who), 'FullControl', 'Allow') }
      $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
  }
  function Write-FixtureJson([string]$Path, $Value) {
    [IO.File]::WriteAllBytes($Path, (ConvertTo-CoordStateBytes (ConvertTo-CoordElement $Value)))
  }
  function Set-FixtureRequest([string]$Id = 'request-1', [string]$ScopePath = 'work.ps1',
      [string]$Category = 'Claim', [hashtable]$Payload = @{}, [string[]]$Predecessors = @()) {
    if ([IO.File]::Exists($script:witnessPath)) {
      $script:witness = [IO.File]::ReadAllText($script:witnessPath) | ConvertFrom-Json -AsHashtable -Depth 100
    }
    $script:request = [ordered]@{ protocolVersion = 'Coordination-v1'; resourceId = 'board-S17'; sprintId = '0017'
      requestId = $Id; category = $Category; taskId = '17.24'; scope = @(@{ registeredRootId = 'fixture'; path = $ScopePath })
      holder = @{ holderId = 'Coordinator'; sessionId = 'session-1' }; authorizationReference = 'grant-' + $Id
      generation = 'epoch-1'; expectedRevision = ([IO.File]::ReadAllText($statePath) | ConvertFrom-Json).committedRevision
      predecessors = $Predecessors; payload = $Payload }
    $draft = [Text.Encoding]::UTF8.GetBytes((@{ request = $request; digest = ('0' * 64) } | ConvertTo-Json -Depth 30 -Compress))
    $canonical = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $draft -MaxRequestBytes 65536 -DeferDigestComparison
    $script:envelope = [Text.Encoding]::UTF8.GetBytes((@{ request = $request; digest = $canonical.Digest } | ConvertTo-Json -Depth 30 -Compress))
    $script:witness.authorizations += @{ reference = 'grant-' + $Id; requestId = $Id; digest = $canonical.Digest; claimId = 'claim-' + $Id }
    Write-FixtureJson $script:witnessPath $script:witness
  }
  function New-ProducerFixture {
    $root = Join-Path $fixtureRoot ([guid]::NewGuid().ToString('N'))
    $script:fakeProgramData = Join-Path $root 'ProgramData'
    $stateRoot = Join-Path $fakeProgramData 'State'
    $custody = Join-Path $fakeProgramData 'Custody'
    $board = Join-Path $root 'Board'
    $script:backupRoot = Join-Path $fakeProgramData 'Backup'
    foreach ($directory in @($stateRoot, $custody, $board, $backupRoot)) { $null = [IO.Directory]::CreateDirectory($directory) }
    Protect-FixturePath $stateRoot
    Protect-FixturePath $custody
    Protect-FixturePath $backupRoot
    $script:statePath = Join-Path $stateRoot 'state.json'
    $script:witnessPath = Join-Path $custody 'custody.json'
    $manifest = [ordered]@{}
    foreach ($slot in @('markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml')) {
      $name = switch ($slot) { markdown { 'Tasks.Sprint0017.md' }; boardHtml { 'Tasks.Sprint0017.html' }
        proceduralDetailsHtml { 'Tasks.Sprint0017.ProceduralDetails.html' }; accomplishedHtml { 'Tasks.Sprint0017.Accomplished.html' } }
      $path = Join-Path $board $name
      $text = if ($slot -eq 'markdown') {
        @('# Current Sprint: fixture', '', '## Goal', 'Disposable producer fixture.', '', '## Stream C - fixture', '- [ ] **Task 17.24** [ATAP.Utilities] - Fixture', '  - Status: Planned.', '') -join [char]10
      } else { 'fixture' }
      $bytes = [Text.Encoding]::UTF8.GetBytes($text)
      [IO.File]::WriteAllBytes($path, $bytes)
      $manifest[$slot] = @{ path = $path; digest = Get-CoordHash $bytes }
    }
    $lockPath = Join-Path $board 'CoordinatorBoard.lock'
    [IO.File]::WriteAllBytes($lockPath, [byte[]]@())
    $receipt = @{ reference = 'fixture-admission'; digest = ('0' * 64) }
    $script:state = [ordered]@{ schemaVersion = 'Coordination-state-v1'; resourceId = 'board-S17'; lineageId = 'lineage-1'
      registeredRoots = @(@{ registeredRootId = 'fixture'; path = $board }); generation = 'epoch-1'
      committedRevision = 'head-1'; committedOutputManifest = $manifest; custodyEvidence = $receipt
      compatibilityEvidence = $receipt; admissionEvidence = @($receipt); requests = @(); claims = @(); reservations = @()
      preparedOperations = @(); commitReceipts = @(); mutationAdmission = @{ status = 'Admitted'; reason = 'Disposable fixture'; observedOutputs = @() } }
    Write-FixtureJson $statePath $state
    Protect-FixturePath $statePath
    $pins = @(Get-ChildItem $moduleRoot -File -Recurse | Where-Object {
      $_.Extension -in @('.ps1', '.psm1', '.psd1', '.json') -and -not (Test-CoordDescendant $_.FullName (Join-Path $moduleRoot 'tests'))
    } | ForEach-Object { @{ path = [IO.Path]::GetRelativePath($moduleRoot, $_.FullName).Replace('\', '/'); digest = Get-CoordHash ([IO.File]::ReadAllBytes($_.FullName)) } })
    $script:witness = [ordered]@{ schemaVersion = 'Coordination-custody-v1'; admissionMode = 'Established'; custodianSid = $sid
      resourceId = 'board-S17'; lineageId = 'lineage-1'; generation = 'epoch-1'; sprintId = '0017'; coordinatorId = 'Coordinator'
      statePath = $statePath; stateSha256 = Get-CoordHash ([IO.File]::ReadAllBytes($statePath)); pendingWrite = $null; boardLockPath = $lockPath
      actors = @(@{ holderId = 'Coordinator'; sessionId = 'session-1'; windowsSid = $sid; role = 'Coordinator' })
      authorizations = @(); existingTasks = @(@{ taskId = '17.24'; ancestorTaskIds = @() })
      package = @{ moduleVersion = (Import-PowerShellDataFile (Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psd1')).ModuleVersion; files = $pins } }
    Write-FixtureJson $witnessPath $witness
    Protect-FixturePath $witnessPath
    $global:configRootKeys = @{}
    $global:settings = @{}
    $values = @{ StateRootPath = $stateRoot; CustodyRecordPath = $witnessPath; ProtectedBackupRootPath = $backupRoot; MaxRequestBytes = 65536
      MaxBatchBytes = 262144; MaxBatchRequests = 8; MaxDrainRequests = 16; MaxDrainBatches = 8; MaxDrainMilliseconds = 10000 }
    foreach ($name in $values.Keys) {
      $key = 'Orchestration' + $name
      $global:configRootKeys[$key + 'ConfigRootKey'] = $key
      $global:settings[$key] = $values[$name]
    }
    Set-FixtureRequest
  }
}
AfterAll {
  $global:settings = $script:priorSettings
  $global:configRootKeys = $script:priorKeys
}
Describe 'Actual coordination producer under disposable protected custody' -Tag 'Integration' {

  It 'renders and publishes one authorized annotation after an applied report' -Tag 'C1637' {
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $null = Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $board = [IO.Path]::GetDirectoryName($state.committedOutputManifest.markdown.path)
    $proof = Join-Path $board 'annotation-proof.txt'
    [IO.File]::WriteAllText($proof, 'Synthetic source result')
    $evidence = @(@{ reference = $proof; digest = @{ algorithm = 'SHA256'; value = Get-CoordHash ([IO.File]::ReadAllBytes($proof)) } })
    Set-FixtureRequest -Id 'report-1' -Category ReportResult -Predecessors @('request-1') -Payload @{
      claimId = 'claim-request-1'; outcome = 'source-ready'; evidence = $evidence; statedLimits = 'Fixture only.' }
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $null = Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false
    Set-FixtureRequest -Id 'accept-1' -Category AcceptChange -Predecessors @('report-1') -Payload @{
      reportRequestId = 'report-1'; evidence = $evidence; approvedChange = @{ annotation = 'Implementation awaiting consuming pilot.' } }
    $witness.scratchRoot = Join-Path 'D:/ATAPArtifacts/_generated/Sprint0017/CloseStreams/C' ([guid]::NewGuid().ToString('N'))
    $null = [IO.Directory]::CreateDirectory($witness.scratchRoot)
    Write-FixtureJson $witnessPath $witness
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $result = Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $result.Applied | Should -Be 1
    [IO.File]::ReadAllText($state.committedOutputManifest.markdown.path) | Should -Match 'Implementation awaiting consuming pilot\.'
    [IO.File]::ReadAllText($state.committedOutputManifest.boardHtml.path) | Should -Match 'Implementation awaiting consuming pilot\.'
    [IO.File]::ReadAllText($state.committedOutputManifest.proceduralDetailsHtml.path) | Should -BeExactly 'fixture'
    [IO.File]::ReadAllText($state.committedOutputManifest.accomplishedHtml.path) | Should -BeExactly 'fixture'
  }

  It 'recovers a durable pending queue write forward after interruption' -Tag 'C1637' {
    # An actual open handle permits reads but denies atomic replacement.
    $hold = [IO.File]::Open($statePath, 'Open', 'Read', 'ReadWrite')
    $failure = $null
    try {
      try {
        $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
      } catch { $failure = $_ }
    } finally { $hold.Dispose() }
    $failure | Should -Not -BeNullOrEmpty
    $failure.Exception.ToString() | Should -Match '(?i)(used by another process|sharing violation)'
    $captured = [IO.File]::ReadAllText($witnessPath) | ConvertFrom-Json -AsHashtable
    $captured.pendingWrite.kind | Should -BeExactly 'State'
    $result = Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $result.Applied | Should -Be 1
    (Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false).Status | Should -BeExactly 'Applied'
    $loaded = Read-CoordJsonBytes ([IO.File]::ReadAllBytes($statePath))
    $loaded.GetProperty('requests').GetArrayLength() | Should -Be 1
    $loaded.GetProperty('commitReceipts').GetArrayLength() | Should -Be 1
  }
  It 'applies a real claim then report and release through existing Save and Complete' {
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $drain = Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $drain.Applied | Should -Be 1
    $drain.DrainStatus | Should -BeExactly 'Drained'
    $loaded = Read-CoordJsonBytes ([IO.File]::ReadAllBytes($statePath))
    $loaded.GetProperty('claims').GetArrayLength() | Should -Be 1
    $loaded.GetProperty('commitReceipts').GetArrayLength() | Should -Be 1
    $proofPath = Join-Path ([IO.Path]::GetDirectoryName($state.committedOutputManifest.markdown.path)) 'proof.txt'
    [IO.File]::WriteAllText($proofPath, 'fixture proof')
    $evidence = @(@{ reference = $proofPath; digest = @{ algorithm = 'SHA256'; value = Get-CoordHash ([IO.File]::ReadAllBytes($proofPath)) } })
    Set-FixtureRequest -Id 'report-1' -Category ReportResult -Predecessors @('request-1') -Payload @{
      claimId = 'claim-request-1'; outcome = 'source-ready'; evidence = $evidence; statedLimits = 'Disposable fixture only.' }
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    (Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false).Applied | Should -Be 1
    Set-FixtureRequest -Id 'release-1' -Category Release -Predecessors @('report-1') -Payload @{
      claimId = 'claim-request-1'; releaseReason = 'Fixture completed.' }
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    (Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false).Applied | Should -Be 1
    $loaded = Read-CoordJsonBytes ([IO.File]::ReadAllBytes($statePath))
    $loaded.GetProperty('claims').GetArrayLength() | Should -Be 0
    $loaded.GetProperty('commitReceipts').GetArrayLength() | Should -Be 3
    (Get-CoordResult -StatePath $statePath -ResourceId board-S17 -RequestId request-1).RetainedStatus | Should -BeExactly 'Applied'
  }

  It 'exports exact pending state and restores retained request identity without another queue effect' {
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $exportPath = Join-Path $backupRoot 'recovery.json'
    $export = Export-CoordState -HolderId Coordinator -SessionId session-1 -DestinationPath $exportPath -Confirm:$false
    $export.Status | Should -BeExactly 'Exported'
    $snapshot = [IO.File]::ReadAllText($exportPath) | ConvertFrom-Json -AsHashtable -Depth 100
    $snapshot.stateBytesBase64 | Should -BeExactly ([Convert]::ToBase64String([IO.File]::ReadAllBytes($statePath)))
    # Disposable custodian restore to the SAME roots/lineage; no live-writer replacement.
    Remove-Item -LiteralPath $statePath
    [IO.File]::WriteAllBytes($statePath, [Convert]::FromBase64String($snapshot.stateBytesBase64))
    Protect-FixturePath $statePath
    $retry = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $retry.Decision | Should -BeExactly 'Retained'
    (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($statePath))).GetProperty('requests').GetArrayLength() | Should -Be 1
  }
  BeforeEach {
    $WhatIfPreference = $false
    New-ProducerFixture
    Mock Get-CoordProgramDataPath { $script:fakeProgramData }
    Mock Write-PSFMessage {}
  }
  It 'durably queues ordinal zero and answers an exact retry without another write' {
    $first = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $first.Status | Should -BeExactly 'Pending'
    $first.QueueOrdinal | Should -BeExactly '0'
    $before = [IO.File]::ReadAllBytes($statePath)
    $second = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $second.Decision | Should -BeExactly 'Retained'
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($statePath)) | Should -BeExactly ([Convert]::ToBase64String($before))
    $stored = Read-CoordJsonBytes ([IO.File]::ReadAllBytes($statePath))
    $stored.GetProperty('requests').GetArrayLength() | Should -Be 1
  }
  It 'refuses a changed payload under a retained identity' {
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    Set-FixtureRequest -ScopePath 'other.ps1'
    (Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false).Status | Should -BeExactly 'IdentityConflict'
  }
  It 'does not bootstrap a lost established state' {
    Remove-Item -LiteralPath $statePath
    { Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false } | Should -Throw '*MissingEstablishedState*'
    [IO.File]::Exists($statePath) | Should -BeFalse
  }
  It 'holds on a replaced state instead of accepting a new lineage' {
    $state.committedRevision = 'other-head'
    Write-FixtureJson $statePath $state
    { Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false } | Should -Throw '*StateLossOrExternalReplacement*'
  }
  It 'refuses unregistered actors and self-asserted caller authority' {
    { Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Unregistered -SessionId session-1 -Confirm:$false } | Should -Throw '*ActorNotAuthorized*'
  }
  It 'checks Int64 ordinal overflow before persistence' {
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $value = [IO.File]::ReadAllText($statePath) | ConvertFrom-Json -AsHashtable -Depth 100
    $value.requests[0].queueOrdinal = [long]::MaxValue.ToString()
    Write-FixtureJson $statePath $value
    $witness.stateSha256 = Get-CoordHash ([IO.File]::ReadAllBytes($statePath))
    Write-FixtureJson $witnessPath $witness
    Set-FixtureRequest -Id 'request-2'
    { Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false } | Should -Throw '*QueueOrdinalExhausted*'
  }
}

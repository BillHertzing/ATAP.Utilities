Describe 'Actual coordination producer under disposable protected custody' -Tag 'Integration' {
BeforeAll {
  Import-Module PSFramework -MinimumVersion 1.14.457 -ErrorAction Stop
  $script:moduleRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  foreach ($file in Get-ChildItem (Join-Path $moduleRoot 'private') -Filter '*.ps1') { . $file.FullName }
  . (Join-Path $moduleRoot 'public/Submit-CoordRequest.ps1')
  . (Join-Path $moduleRoot 'public/Invoke-CoordClerk.ps1')
  . (Join-Path $moduleRoot 'public/Get-CoordResult.ps1')
  . (Join-Path $moduleRoot 'public/Export-CoordState.ps1')
  $script:sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  # Mitigation, not a root-cause claim: exclusive opens on Dropbox-synced fixtures were intermittently refused (C2041).
  $fixtureBase = if ($env:C1754_FIXTURE_ROOT) { $env:C1754_FIXTURE_ROOT }
    elseif ([Environment]::MachineName -ieq 'UTAT022') { 'D:/ATAPArtifacts/_generated/Sprint0017/CloseStreams/C' }
    else { throw 'No default fixture root is approved on this host; set C1754_FIXTURE_ROOT to a non-synced local folder.' }
  $script:fixtureRoot = Join-Path $fixtureBase ('Producer-' + [guid]::NewGuid().ToString('N'))
  $null = [IO.Directory]::CreateDirectory($fixtureRoot)
  $script:priorSettings = $global:settings
  $script:priorKeys = $global:configRootKeys
  $script:lockLifetimeObservations = [Collections.Generic.List[object]]::new()
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
      [string]$Category = 'Claim', [hashtable]$Payload = @{}, [string[]]$Predecessors = @(),
      [string]$ExpectedRevision) {
    if ([IO.File]::Exists($script:witnessPath)) {
      $script:witness = [IO.File]::ReadAllText($script:witnessPath) | ConvertFrom-Json -AsHashtable -Depth 100
    }
    $script:request = [ordered]@{ protocolVersion = 'Coordination-v1'; resourceId = 'board-S17'; sprintId = '0017'
      requestId = $Id; category = $Category; taskId = '17.24'; scope = @(@{ registeredRootId = 'fixture'; path = $ScopePath })
      holder = @{ holderId = 'Coordinator'; sessionId = 'session-1' }; authorizationReference = 'grant-' + $Id
      generation = 'epoch-1'; expectedRevision = $(if ($PSBoundParameters.ContainsKey('ExpectedRevision')) { $ExpectedRevision } else { ([IO.File]::ReadAllText($statePath) | ConvertFrom-Json).committedRevision })
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
  function Start-CompletionReport([string]$Fault = '') {
    # Fresh synthetic custody only. Seed proper companion HTML and an unrelated
    # existing task before the first request; never patch a committed live head.
    $board = [IO.Path]::GetDirectoryName($state.committedOutputManifest.markdown.path)
    [IO.File]::AppendAllText($state.committedOutputManifest.markdown.path,
      "`n- [ ] **Task 17.25** [ATAP.Utilities] - Unrelated`n  - Status: Planned.`n")
    foreach ($slot in @('accomplishedHtml', 'proceduralDetailsHtml')) {
      [IO.File]::WriteAllText($state.committedOutputManifest[$slot].path, "<html><body><p>Historical $slot</p></body></html>`n")
    }
    foreach ($slot in $state.committedOutputManifest.Keys) {
      $state.committedOutputManifest[$slot].digest = Get-CoordHash ([IO.File]::ReadAllBytes($state.committedOutputManifest[$slot].path))
    }
    Write-FixtureJson $statePath $state
    $witness.stateSha256 = Get-CoordHash ([IO.File]::ReadAllBytes($statePath))
    $witness.existingTasks += @{ taskId = '17.25'; ancestorTaskIds = @() }
    $witness.scratchRoot = Join-Path $fixtureRoot ('scratch-' + [guid]::NewGuid().ToString('N'))
    $null = [IO.Directory]::CreateDirectory($witness.scratchRoot)
    Write-FixtureJson $witnessPath $witness
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $null = Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $proofs = @(foreach ($name in @('acceptance', 'readback')) {
      $path = Join-Path $board ($name + '.json')
      [IO.File]::WriteAllText($path, ('{"synthetic":"' + $name + ' accepted existing-task proof"}'))
      @{ reference = $path; digest = @{ algorithm = 'SHA256'; value = Get-CoordHash ([IO.File]::ReadAllBytes($path)) } }
    })
    $script:completionRecord = @{
      kind = 'Coordination-CompletionRecord-v1'; resourceId = 'board-S17'; sprintId = '0017'; generation = 'epoch-1'
      taskId = '17.24'; claimId = 'claim-request-1'; beforeMarkdownSha256 = $state.committedOutputManifest.markdown.digest
      annotation = 'Completed with independently accepted consuming evidence.'
      acceptance = $proofs[0]; readback = $proofs[1]
      companions = @{
        accomplishedHtml = @{ beforeSha256 = $state.committedOutputManifest.accomplishedHtml.digest; text = 'Observed consuming result <accepted> & retained.' }
        proceduralDetailsHtml = @{ beforeSha256 = $state.committedOutputManifest.proceduralDetailsHtml.digest; text = 'Use one attempt and independent final readback.' }
      }
    }
    switch ($Fault) {
      StaleCompanion { $completionRecord.companions.accomplishedHtml.beforeSha256 = '0' * 64 }
      ExtraEdit { $completionRecord.extraReplacement = 'Change unrelated task' }
    }
    $recordPath = Join-Path $board 'completion-record.json'
    Write-FixtureJson $recordPath $completionRecord
    $script:completionEvidence = @(@{ reference = $recordPath; digest = @{ algorithm = 'SHA256'; value = Get-CoordHash ([IO.File]::ReadAllBytes($recordPath)) } }) + $proofs
    Set-FixtureRequest -Id 'completion-report' -Category ReportResult -Predecessors @('request-1') -Payload @{
      claimId = 'claim-request-1'; outcome = $(if ($Fault -eq 'FailedReport') { 'failed' } else { 'source-ready' })
      evidence = $completionEvidence; statedLimits = 'Bookkeeping of immutable synthetic accepted proof; no new pilot.' }
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    (Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false).Applied | Should -Be 1
    if ($Fault -eq 'StaleProof') { [IO.File]::AppendAllText($proofs[0].reference, 'changed after report') }
    if ($Fault -eq 'ReleasedClaim') {
      Set-FixtureRequest -Id 'early-release' -Category Release -Predecessors @('completion-report') -Payload @{
        claimId = 'claim-request-1'; releaseReason = 'Fixture release before completion admission.' }
      $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
      $null = Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false
    }
    if ($Fault -eq 'ParentTarget') {
      $script:witness = Get-Content -LiteralPath $witnessPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
      $witness.existingTasks[1].ancestorTaskIds = @('17.24')
      Write-FixtureJson $witnessPath $witness
    }
    Set-FixtureRequest -Id 'completion-accept' -Category AcceptChange -Predecessors @('completion-report') -Payload @{
      reportRequestId = 'completion-report'; evidence = $completionEvidence
      approvedChange = @{ status = 'done'; annotation = $completionRecord.annotation } }
  }
}
AfterAll {
  $global:settings = $script:priorSettings
  $global:configRootKeys = $script:priorKeys
  if ($script:lockLifetimeObservations.Count) {
    $script:lockLifetimeObservations | ConvertTo-Json -Depth 8 |
      Set-Content -LiteralPath (Join-Path $script:fixtureRoot 'C1687-LockLifetime.json')
  }
}

  It 'distinguishes retained custody from interrupted state replacement and recovers after both owners release' -Tag 'C1687' {
    $owner = Read-CoordProducerContext -HolderId Coordinator -SessionId session-1
    $stateHold = $null
    $beforeState = Get-CoordHash ([IO.File]::ReadAllBytes($statePath))
    $beforeWitness = Get-CoordHash ([IO.File]::ReadAllBytes($witnessPath))
    try {
      $stateHold = [IO.File]::Open($statePath, 'Open', 'Read', 'ReadWrite')
      $custodyFailure = $null
      try {
        $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
      } catch { $custodyFailure = $_ }
      $custodyFailure | Should -Not -BeNullOrEmpty
      $custodyFailure.ScriptStackTrace | Should -Match 'Enter-CoordResourceLease'
      $custodyFailure.Exception.ToString() | Should -Match '(?i)(used by another process|sharing violation)'
      $owner.Lease.CanRead | Should -BeTrue
      (Get-CoordHash ([IO.File]::ReadAllBytes($statePath))) | Should -BeExactly $beforeState
      (Get-CoordHash ([IO.File]::ReadAllBytes($witnessPath))) | Should -BeExactly $beforeWitness
      ([IO.File]::ReadAllText($witnessPath) | ConvertFrom-Json).pendingWrite | Should -BeNullOrEmpty
      $script:lockLifetimeObservations.Add([pscustomobject]@{
        Stage = 'Known retained custody owner; state replacement also blocked'
        KnownOwnerProcessId = [Environment]::ProcessId; CustodyLeasePath = $owner.Lease.Name
        BoardLeasePath = $owner.BoardLease.Name; StateHandlePath = $stateHold.Name
        Failure = $custodyFailure.Exception.ToString(); Stack = $custodyFailure.ScriptStackTrace
        PendingWrite = $null; StateAndWitnessUnchanged = $true
      })

      $owner.BoardLease.Dispose()
      $owner.Lease.Dispose()
      $owner = $null
      $stateFailure = $null
      try {
        $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
      } catch { $stateFailure = $_ }
      $stateFailure | Should -Not -BeNullOrEmpty
      $stateFailure.ScriptStackTrace | Should -Match 'Write-CoordAtomicBytes'
      $stateFailure.Exception.ToString() | Should -Match '(?i)(used by another process|sharing violation)'
      $pending = [IO.File]::ReadAllText($witnessPath) | ConvertFrom-Json
      $pending.pendingWrite.kind | Should -BeExactly 'State'
      # Failure released producer custody even while the independently held state file remains open.
      $probe = Enter-CoordResourceLease -StateDirectory ([IO.Path]::GetDirectoryName($witnessPath))
      try { $probe.CanWrite | Should -BeTrue } finally { $probe.Dispose() }
      $script:lockLifetimeObservations.Add([pscustomobject]@{
        Stage = 'Custody owner released; known state replacement owner retained'
        KnownOwnerProcessId = [Environment]::ProcessId; StateHandlePath = $stateHold.Name
        Failure = $stateFailure.Exception.ToString(); Stack = $stateFailure.ScriptStackTrace
        PendingWrite = $pending.pendingWrite.kind; CustodyReleasedAfterFailure = $true
      })
    } finally {
      if ($owner) { $owner.BoardLease.Dispose(); $owner.Lease.Dispose() }
      if ($stateHold) { $stateHold.Dispose() }
    }
    (Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false).Applied | Should -Be 1
    (Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false).Status | Should -BeExactly 'Applied'
    $recovered = Read-CoordJsonBytes ([IO.File]::ReadAllBytes($statePath))
    $recovered.GetProperty('requests').GetArrayLength() | Should -Be 1
    $recovered.GetProperty('commitReceipts').GetArrayLength() | Should -Be 1
  }

  It 'releases custody after early rejection and only after a synchronous result consumer finishes' -Tag 'C1687' {
    $rejection = $null
    try {
      $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Unregistered -SessionId session-1 -Confirm:$false
    } catch { $rejection = $_ }
    $rejection.Exception.Message | Should -Match 'ActorNotAuthorized'
    $probe = Enter-CoordResourceLease -StateDirectory ([IO.Path]::GetDirectoryName($witnessPath))
    try { $probe.CanWrite | Should -BeTrue } finally { $probe.Dispose() }

    $consumerFailure = $null
    $submission = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false |
      ForEach-Object {
        # Output reaches downstream code before the producer's finally block runs.
        # A reentrant submit here contends with its own still-active producer.
        try {
          $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
        } catch { $consumerFailure = $_ }
        $_
      }
    $submission.Status | Should -BeExactly 'Pending'
    $consumerFailure | Should -Not -BeNullOrEmpty
    $consumerFailure.ScriptStackTrace | Should -Match 'Enter-CoordResourceLease'
    $consumerFailure.Exception.ToString() | Should -Match '(?i)(used by another process|sharing violation)'
    # Once the result pipeline has completed, both leases must be available again.
    $probe = Enter-CoordResourceLease -StateDirectory ([IO.Path]::GetDirectoryName($witnessPath))
    try { $probe.CanWrite | Should -BeTrue } finally { $probe.Dispose() }
    $boardProbe = [IO.File]::Open($witness.boardLockPath, 'Open', 'ReadWrite', 'None')
    try { $boardProbe.CanWrite | Should -BeTrue } finally { $boardProbe.Dispose() }
    $retry = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $retry.Decision | Should -BeExactly 'Retained'
    $retry.Status | Should -BeExactly 'Pending'
    (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($statePath))).GetProperty('requests').GetArrayLength() | Should -Be 1
    $script:lockLifetimeObservations.Add([pscustomobject]@{
      Stage = 'Reentrant synchronous result consumer before producer finally'
      ProcessId = [Environment]::ProcessId; CustodyDirectory = [IO.Path]::GetDirectoryName($witnessPath)
      Rejection = $rejection.Exception.ToString(); RejectionStack = $rejection.ScriptStackTrace
      Failure = $consumerFailure.Exception.ToString(); Stack = $consumerFailure.ScriptStackTrace
      CustodyAndBoardReleasedAfterPipeline = $true; RetryDecision = $retry.Decision
    })
  }

  It 'renders and publishes one authorized annotation after an applied report' -Tag 'C1637' {
    try {
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
    $scratchBase = if ($env:C1754_FIXTURE_ROOT) { $fixtureRoot } else { 'D:/ATAPArtifacts/_generated/Sprint0017/CloseStreams/C' }
    $witness.scratchRoot = Join-Path $scratchBase ([guid]::NewGuid().ToString('N'))
    $null = [IO.Directory]::CreateDirectory($witness.scratchRoot)
    Write-FixtureJson $witnessPath $witness
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $result = Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $result.Applied | Should -Be 1
    [IO.File]::ReadAllText($state.committedOutputManifest.markdown.path) | Should -Match 'Implementation awaiting consuming pilot\.'
    [IO.File]::ReadAllText($state.committedOutputManifest.boardHtml.path) | Should -Match 'Implementation awaiting consuming pilot\.'
    [IO.File]::ReadAllText($state.committedOutputManifest.proceduralDetailsHtml.path) | Should -BeExactly 'fixture'
    [IO.File]::ReadAllText($state.committedOutputManifest.accomplishedHtml.path) | Should -BeExactly 'fixture'
    } catch {
      if ($env:C1754_FIXTURE_ROOT) { [IO.File]::WriteAllText((Join-Path $fixtureRoot 'C1754-annotation-failure.txt'), ($_.Exception.ToString() + "`n" + $_.ScriptStackTrace)) }
      throw
    }
  }

  It 'completes one existing leaf and both companions through real serialization renderer and durable publication once' -Tag 'CompletionCapability' {
    Start-CompletionReport
    $paths = $state.committedOutputManifest
    $before = @{}
    foreach ($slot in $paths.Keys) { $before[$slot] = [IO.File]::ReadAllText($paths[$slot].path) }
    [byte[]]$acceptEnvelope = $envelope.Clone()
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    (Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false).Applied | Should -Be 1
    $after = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    # Only the target Status is replaced; the unrelated task remains byte exact.
    $expected = $before.markdown.Replace('- [ ] **Task 17.24** [ATAP.Utilities] - Fixture' + "`n  - Status: Planned.",
      '- [x] **Task 17.24** [ATAP.Utilities] - Fixture' + "`n  - Status: " + $completionRecord.annotation)
    [IO.File]::ReadAllText($paths.markdown.path) | Should -BeExactly $expected
    [IO.File]::ReadAllText($paths.boardHtml.path) | Should -Match 'Completed with independently accepted consuming evidence'
    foreach ($slot in @('accomplishedHtml', 'proceduralDetailsHtml')) {
      $text = [IO.File]::ReadAllText($paths[$slot].path)
      $text | Should -Match ([regex]::Escape("<p>Historical $slot</p>"))
      @([regex]::Matches($text, 'data-coordination-completion=')).Count | Should -Be 1
      $text | Should -Match ([regex]::Escape([Net.WebUtility]::HtmlEncode($completionRecord.companions[$slot].text)))
    }
    $receipt = $after.commitReceipts[-1]
    foreach ($slot in $paths.Keys) {
      $hash = Get-CoordHash ([IO.File]::ReadAllBytes($paths[$slot].path))
      $hash | Should -BeExactly $after.committedOutputManifest[$slot].digest
      $hash | Should -BeExactly $receipt.outputManifest[$slot].digest
      $hash | Should -Not -BeExactly $state.committedOutputManifest[$slot].digest
    }
    $published = @{}; $ticks = @{}
    foreach ($slot in $paths.Keys) {
      $published[$slot] = Get-CoordHash ([IO.File]::ReadAllBytes($paths[$slot].path))
      $ticks[$slot] = [IO.File]::GetLastWriteTimeUtc($paths[$slot].path).Ticks
    }
    (Submit-CoordRequest -EnvelopeBytes $acceptEnvelope -HolderId Coordinator -SessionId session-1 -Confirm:$false).Decision | Should -BeExactly 'Retained'
    (Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false).Applied | Should -Be 0
    foreach ($slot in $paths.Keys) {
      (Get-CoordHash ([IO.File]::ReadAllBytes($paths[$slot].path))) | Should -BeExactly $published[$slot]
      [IO.File]::GetLastWriteTimeUtc($paths[$slot].path).Ticks | Should -Be $ticks[$slot]
    }
    Set-FixtureRequest -Id 'completion-release' -Category Release -Predecessors @('completion-accept') -Payload @{
      claimId = 'claim-request-1'; releaseReason = 'Accepted bookkeeping complete.' }
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    (Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false).Applied | Should -Be 1
    $final = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -Depth 100
    $final.claims.Count | Should -Be 0
    $final.commitReceipts.Count | Should -Be 4
    $report = @($final.requests | Where-Object { $_.request.requestId -eq 'completion-report' })[0]
    $report.request.payload.evidence[0].digest.value | Should -BeExactly $completionEvidence[0].digest.value
  }

  It 'refuses completion <Fault> before any quartet publication' -Tag 'CompletionCapability' -ForEach @(
    @{ Fault = 'StaleProof' }; @{ Fault = 'StaleCompanion' }; @{ Fault = 'ExtraEdit' }; @{ Fault = 'FailedReport' }
    @{ Fault = 'ReleasedClaim' }; @{ Fault = 'ParentTarget' }
  ) {
    Start-CompletionReport -Fault $Fault
    $before = @{}
    foreach ($slot in $state.committedOutputManifest.Keys) { $before[$slot] = Get-CoordHash ([IO.File]::ReadAllBytes($state.committedOutputManifest[$slot].path)) }
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $result = Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $result.Applied | Should -Be 0
    $result.Rejected | Should -Be 1
    foreach ($slot in $before.Keys) { (Get-CoordHash ([IO.File]::ReadAllBytes($state.committedOutputManifest[$slot].path))) | Should -BeExactly $before[$slot] }
    $final = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -Depth 100
    $final.commitReceipts.Count | Should -Be $(if ($Fault -eq 'ReleasedClaim') { 3 } else { 2 })
    $final.claims.Count | Should -Be $(if ($Fault -eq 'ReleasedClaim') { 0 } else { 1 })
  }

  It 'rejects a completion mixed with <OtherChange> without losing either companion delta' -Tag 'CompletionCapability' -ForEach @(
    @{ OtherChange = 'annotation' }; @{ OtherChange = 'completion' }
  ) {
    Start-CompletionReport
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $change = if ($OtherChange -eq 'annotation') { @{ annotation = 'Evidence observed.' } }
      else { @{ status = 'done'; annotation = $completionRecord.annotation } }
    Set-FixtureRequest -Id 'mixed-change' -Category AcceptChange -Predecessors @('completion-report') -Payload @{
      reportRequestId = 'completion-report'; evidence = $completionEvidence; approvedChange = $change }
    $null = Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $result = Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Confirm:$false
    $result.Applied | Should -Be 0
    $result.Rejected | Should -Be 2
    [IO.File]::ReadAllText($state.committedOutputManifest.markdown.path) | Should -Not -Match '\[x\]'
    [IO.File]::ReadAllText($state.committedOutputManifest.accomplishedHtml.path) | Should -Not -Match 'data-coordination-completion='
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
    if ($env:C1754_FIXTURE_ROOT -and $failure) { [IO.File]::WriteAllText((Join-Path $fixtureRoot 'C1754-pending-caught.txt'), ($failure.Exception.ToString() + "`n" + $failure.ScriptStackTrace)) }
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
    $export = Export-CoordState -HolderId Coordinator -SessionId session-1 -DestinationPath $exportPath -NoCompression -Confirm:$false
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
  It 'refuses a valid new request with a stale expected revision without persistence' -Tag 'C1822' {
    Set-FixtureRequest -Id 'stale-request' -ExpectedRevision 'stale-head'
    $beforeState = Get-CoordHash ([IO.File]::ReadAllBytes($statePath))
    $beforeWitness = Get-CoordHash ([IO.File]::ReadAllBytes($witnessPath))

    { Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-1 -Confirm:$false } | Should -Throw '*RevisionConflict*'

    (Get-CoordHash ([IO.File]::ReadAllBytes($statePath))) | Should -BeExactly $beforeState
    (Get-CoordHash ([IO.File]::ReadAllBytes($witnessPath))) | Should -BeExactly $beforeWitness
    (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($statePath))).GetProperty('requests').GetArrayLength() | Should -Be 0
    ([IO.File]::ReadAllText($witnessPath) | ConvertFrom-Json).pendingWrite | Should -BeNullOrEmpty
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
  It 'refuses a registered holder with an unregistered current caller session without persistence' -Tag 'C1825' {
    Set-FixtureRequest -Id 'session-request'
    $beforeState = Get-CoordHash ([IO.File]::ReadAllBytes($statePath))
    $beforeWitness = Get-CoordHash ([IO.File]::ReadAllBytes($witnessPath))

    { Submit-CoordRequest -EnvelopeBytes $envelope -HolderId Coordinator -SessionId session-other -Confirm:$false } | Should -Throw '*ActorNotAuthorized*'

    (Get-CoordHash ([IO.File]::ReadAllBytes($statePath))) | Should -BeExactly $beforeState
    (Get-CoordHash ([IO.File]::ReadAllBytes($witnessPath))) | Should -BeExactly $beforeWitness
    (Read-CoordJsonBytes ([IO.File]::ReadAllBytes($statePath))).GetProperty('requests').GetArrayLength() | Should -Be 0
    ([IO.File]::ReadAllText($witnessPath) | ConvertFrom-Json).pendingWrite | Should -BeNullOrEmpty
  }
  It 'denies the retired caller and request holder despite an active U+00AD session' -Tag 'C2065SuccessorOrdinalFix' {
    # The assigned disposable root can be on Dropbox. Keep the real context
    # and fixture leases, and isolate cloud-tag inspection to this fixture tree.
    Mock Assert-CoordCloudPlaceholder {
      if ($Path -ine $script:fixtureRoot -and
          -not (Test-CoordDescendant $Path $script:fixtureRoot) -and
          -not (Test-CoordDescendant $script:fixtureRoot $Path)) { throw 'OutsideDisposableFixtureTree' }
    }
    $retiredSession = 'retired-session'
    $activeSession = $retiredSession + [char]0x00AD
    $witness.actors += @{ holderId = 'Coordinator'; sessionId = $activeSession; windowsSid = $sid; role = 'Coordinator' }
    $witness.retiredActors = @(@{ holderId = 'Coordinator'; sessionId = $retiredSession; windowsSid = $sid; role = 'Coordinator' })
    $exactRequest = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $envelope -MaxRequestBytes 65536
    $retiredRequestValue = Get-CoordMembers $exactRequest.Request
    $retiredRequestValue.holder = @{ holderId = 'Coordinator'; sessionId = $retiredSession }
    $retiredRequestValue.requestId = 'retired-request'
    $retiredRequestValue.authorizationReference = 'grant-retired-request'
    $draft = ConvertTo-CoordStateBytes (ConvertTo-CoordElement @{ request = $retiredRequestValue; digest = ('0' * 64) })
    $retiredRequest = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $draft -MaxRequestBytes 65536 -DeferDigestComparison
    $witness.authorizations += @{
      reference = 'grant-retired-request'; requestId = 'retired-request'; digest = $retiredRequest.Digest; claimId = 'claim-retired-request'
    }
    Write-FixtureJson $witnessPath $witness

    { Read-CoordProducerContext -HolderId Coordinator -SessionId $retiredSession } | Should -Throw 'ActorNotAuthorized'
    $context = Read-CoordProducerContext -HolderId Coordinator -SessionId $activeSession
    try {
      [StringComparer]::Ordinal.Equals($context.Actor.sessionId, $activeSession) | Should -BeTrue
    } finally {
      $context.BoardLease.Dispose()
      $context.Lease.Dispose()
    }
    $context = Read-CoordProducerContext -HolderId Coordinator -SessionId session-1
    try {
      (Get-CoordRequestGrant $context $exactRequest.Request $exactRequest.Digest).requestId | Should -BeExactly 'request-1'
      { Get-CoordRequestGrant $context $retiredRequest.Request $retiredRequest.Digest } | Should -Throw 'AuthorityConflict'
    } finally {
      $context.BoardLease.Dispose()
      $context.Lease.Dispose()
    }
  }

  It 'denies a grant with a valid digest but U+00AD in the stored <Field>' -Tag 'C2065ExactGrantFix' -ForEach @(
    @{ Field = 'reference' }
    @{ Field = 'requestId' }
  ) {
    Mock Assert-CoordCloudPlaceholder {
      if ($Path -ine $script:fixtureRoot -and
          -not (Test-CoordDescendant $Path $script:fixtureRoot) -and
          -not (Test-CoordDescendant $script:fixtureRoot $Path)) { throw 'OutsideDisposableFixtureTree' }
    }
    $canonical = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $envelope -MaxRequestBytes 65536
    $witness.authorizations[0][$Field] += [char]0x00AD
    Write-FixtureJson $witnessPath $witness

    $context = Read-CoordProducerContext -HolderId Coordinator -SessionId session-1
    try {
      $context.Record.authorizations[0].digest | Should -BeExactly $canonical.Digest
      { Get-CoordRequestGrant $context $canonical.Request $canonical.Digest } | Should -Throw 'AuthorityConflict'
    } finally {
      $context.BoardLease.Dispose()
      $context.Lease.Dispose()
    }
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

Describe 'Successor witness actor retirement validation in memory' -Tag 'C2065SuccessorGuard' {
  BeforeAll {
    $sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
    . (Join-Path $sourceRoot 'private/CoordProducerJson.ps1')
    . (Join-Path $sourceRoot 'private/CoordProducer.ps1')
  }

  BeforeEach {
    $retired = [ordered]@{ holderId = 'coordinator'; sessionId = 'retired-session'; windowsSid = 'fixture-sid'; role = 'Coordinator' }
    $witness = [ordered]@{
      actors = @([ordered]@{ holderId = 'coordinator'; sessionId = 'successor-session'; windowsSid = 'fixture-sid'; role = 'Coordinator' })
      retiredActors = @($retired)
    }
  }

  It 'accepts an independent active successor and a historical retired actor' {
    { Assert-CoordActorRetirement (ConvertTo-CoordElement $witness) 'fixture-sid' } | Should -Not -Throw
  }

  It 'leaves legacy actor validation to the existing admission path' {
    $witness.Remove('retiredActors')
    $witness.actors = 'legacy-input-without-retirement-validation'
    { Assert-CoordActorRetirement (ConvertTo-CoordElement $witness) 'fixture-sid' } | Should -Not -Throw
  }

  It 'rejects a retired session reintroduced as <Session> for <Holder>' -ForEach @(
    @{ Session = 'retired-session'; Holder = 'coordinator' }
    @{ Session = 'retired-session'; Holder = 'other-holder' }
    @{ Session = 'RETIRED-SESSION'; Holder = 'other-holder' }
  ) {
    $witness.actors[0].sessionId = $Session
    $witness.actors[0].holderId = $Holder
    { Assert-CoordActorRetirement (ConvertTo-CoordElement $witness) 'fixture-sid' } | Should -Throw 'RetiredActorConflict'
  }

  It 'rejects malformed retirement data: <Fault>' -ForEach @(
    @{ Fault = 'NullList' }; @{ Fault = 'ObjectList' }; @{ Fault = 'NonObjectEntry' }
    @{ Fault = 'MissingField' }; @{ Fault = 'UnknownField' }; @{ Fault = 'WrongType' }
    @{ Fault = 'BlankSession' }; @{ Fault = 'WrongSid' }; @{ Fault = 'WrongRole' }
    @{ Fault = 'DuplicateSessionAlias' }; @{ Fault = 'MalformedActiveSession' }
  ) {
    switch ($Fault) {
      NullList { $witness.retiredActors = $null }
      ObjectList { $witness.retiredActors = $retired }
      NonObjectEntry { $witness.retiredActors = @('retired-session') }
      MissingField { $retired.Remove('holderId') }
      UnknownField { $retired.extra = 'unsupported' }
      WrongType { $retired.holderId = 1 }
      BlankSession { $retired.sessionId = ' ' }
      WrongSid { $retired.windowsSid = 'other-sid' }
      WrongRole { $retired.role = 'Admin' }
      DuplicateSessionAlias {
        $witness.retiredActors += [ordered]@{ holderId = 'other-holder'; sessionId = 'RETIRED-SESSION'; windowsSid = 'fixture-sid'; role = 'Worker' }
      }
      MalformedActiveSession { $witness.actors[0].sessionId = $null }
    }
    { Assert-CoordActorRetirement (ConvertTo-CoordElement $witness) 'fixture-sid' } | Should -Throw 'InvalidActorRetirement'
  }
}

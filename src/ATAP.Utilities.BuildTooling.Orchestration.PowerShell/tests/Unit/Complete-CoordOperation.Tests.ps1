#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
param([Parameter()][string]$FixtureRoot = $(if ([Environment]::MachineName -ieq 'UTAT022') { 'D:\ATAPArtifacts\Sprint0017\Task17.28\Complete356\Fixtures' } else { throw 'FixtureRoot must be supplied explicitly on this host.' }))

BeforeAll {
  $allowed = [IO.Path]::GetFullPath('D:/ATAPArtifacts/Sprint0017/Task17.28/Complete356').TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  $script:runRoot = [IO.Path]::GetFullPath($FixtureRoot)
  if (-not $runRoot.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'D-only FixtureRoot required.' }
  $null = [IO.Directory]::CreateDirectory($runRoot)
  $null = Get-Command Write-PSFMessage -ErrorAction Stop
  . (Join-Path $PSScriptRoot '../../private/Save-CoordOperation.ps1')
  . (Join-Path $PSScriptRoot '../../private/Complete-CoordOperation.ps1')
  $script:realCoordIo = (Get-Command Invoke-CoordOperationFileIo -CommandType Function).ScriptBlock
  $script:enc = [Text.UTF8Encoding]::new($false, $true)
  # Independent hex-key fixture oracle; production serializer is never called.
  $script:projection = @('schemaVersion', 'resourceId', 'lineageId', 'registeredRoots', 'generation',
    'committedRevision', 'committedOutputManifest', 'custodyEvidence', 'compatibilityEvidence',
    'admissionEvidence', 'requests', 'claims', 'reservations', 'mutationAdmission')
  $script:slotNames = @('markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml')

  function Test-CompleteSha([byte[]]$Bytes) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
  }
  function Test-CompleteJson($Value, [string[]]$TopNames) {
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [System.Collections.IDictionary]) {
      [string[]]$keys = if ($null -ne $TopNames) { $TopNames } else { @($Value.Keys) }
      if ($null -eq $TopNames) {
        $order = [Collections.Generic.SortedDictionary[string, string]]::new([StringComparer]::Ordinal)
        foreach ($key in $keys) { $order.Add([Convert]::ToHexString($enc.GetBytes($key)), $key) }
        $keys = @($order.Values)
      }
      $pairs = foreach ($key in $keys) {
        (ConvertTo-Json -InputObject ([string]$key) -Compress) + ':' + (Test-CompleteJson $Value[$key] $null)
      }
      return '{' + ($pairs -join ',') + '}'
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
      return '[' + (@($Value | ForEach-Object { Test-CompleteJson $_ $null }) -join ',') + ']'
    }
    return (ConvertTo-Json -InputObject $Value -Depth 100 -Compress)
  }
  function Test-CompleteBytes($Value, [switch]$Projection) {
    $names = if ($Projection) { $script:projection } else { $null }
    $json = (Test-CompleteJson $Value $names).Replace('"__RAW_NUMBER__"', '1e2')
    return , ($enc.GetBytes($json + [char]10))
  }
  function Test-CompleteElement([byte[]]$Bytes) {
    $doc = [System.Text.Json.JsonDocument]::Parse($enc.GetString($Bytes))
    try { $doc.RootElement.Clone() } finally { $doc.Dispose() }
  }
  function Test-CompleteClone($Value) { (Test-CompleteJson $Value $null) | ConvertFrom-Json -AsHashtable -Depth 100 }
  function Test-CompleteImage([byte[]]$Bytes, [string]$Path) {
    $value = [ordered]@{ bytesBase64 = [Convert]::ToBase64String($Bytes); digest = Test-CompleteSha $Bytes }
    if ($Path) { $value.path = $Path }
    return $value
  }
  function New-CompleteFixture([switch]$History) {
    $root = Join-Path $runRoot ([guid]::NewGuid().ToString('N'))
    $null = [IO.Directory]::CreateDirectory($root)
    $manifest = [ordered]@{}; $beforeOutputs = [ordered]@{}; $afterOutputs = [ordered]@{}; $afterManifest = [ordered]@{}
    foreach ($slot in $slotNames) {
      $path = Join-Path $root ($slot + '.fixture')
      [byte[]]$before = if ($slot -eq 'markdown') { @(239, 187, 191) + $enc.GetBytes('Before board' + [char]13 + [char]10) } else { $enc.GetBytes("Before $slot" + [char]13 + [char]10) }
      [byte[]]$next = $enc.GetBytes("After $slot" + [char]10)
      [IO.File]::WriteAllBytes($path, $before)
      $beforeOutputs[$slot] = Test-CompleteImage $before $path; $afterOutputs[$slot] = Test-CompleteImage $next $path
      $manifest[$slot] = [ordered]@{path = $path; digest = Test-CompleteSha $before}
      $afterManifest[$slot] = [ordered]@{path = $path; digest = Test-CompleteSha $next}
    }
    # Shape-valid synthetic authority/evidence assumptions; no live admission proof.
    $request = [ordered]@{
      protocolVersion = 'Coordination-v1'; resourceId = 'board-S17'; sprintId = '0017'; requestId = 'R-new'
      category = 'Claim'; taskId = '17.27'; scope = @([ordered]@{registeredRootId = 'fixture'; path = 'owned.ps1'})
      holder = [ordered]@{holderId = 'fixture-holder'; sessionId = 'fixture-session'}
      authorizationReference = 'synthetic-boundary'; generation = 'epoch-A'; expectedRevision = 'head-A'
      predecessors = @(); payload = [ordered]@{}
    }
    $requestJson = Test-CompleteJson $request $null
    $record = [ordered]@{request = $request; digest = Test-CompleteSha $enc.GetBytes($requestJson); originalRequestJson = $requestJson
      queueOrdinal = '1'; status = 'Pending'; pendingEvidence = [ordered]@{reason = 'Eligible'}}
    $reference = [ordered]@{reference = 'synthetic/receipt'; digest = ('0' * 64)}
    $state = [ordered]@{
      schemaVersion = 'Coordination-state-v1'; resourceId = 'board-S17'; lineageId = 'lineage-A'
      registeredRoots = @([ordered]@{registeredRootId = 'fixture'; path = $root}); generation = 'epoch-A'
      committedRevision = 'head-A'; committedOutputManifest = $manifest; custodyEvidence = $reference
      compatibilityEvidence = $reference; admissionEvidence = @($reference); requests = @($record); claims = @()
      reservations = @([ordered]@{reservationId = 'imported'; resourceId = 'board-S17'; requestId = 'R-imported'
          taskId = '17.999'; scope = @([ordered]@{registeredRootId = 'fixture'; path = 'unpublished.ps1'}); generation = 'epoch-A'})
      preparedOperations = @(); commitReceipts = @()
      mutationAdmission = [ordered]@{status = 'Admitted'; reason = 'Synthetic prevalidated caller'; observedOutputs = @()}
    }
    if ($History) {
      $rejected = [ordered]@{resourceId = 'board-S17'; requestId = 'R-rejected'; opaque = '__RAW_NUMBER__'}
      $rejected.orthography = @([string][char]0xE9, ('e' + [char]0x301))
      $rejected.extension = [ordered]@{}
      $rejected.extension[[char]::ConvertFromUtf32(0x10000)] = 'supplementary'
      $rejected.extension[[string][char]0xE000] = 'bmp'
      $original = (Test-CompleteJson $rejected $null).Replace('"__RAW_NUMBER__"', '1e2')
      $state.requests += [ordered]@{request = $rejected; digest = ('2' * 64); originalRequestJson = $original
        queueOrdinal = '999999999999999999999999999999999999'; status = 'Rejected'
        terminalEvidence = [ordered]@{resourceId = 'board-S17'; requestId = 'R-rejected'; digest = ('2' * 64)
          status = 'Rejected'; reason = 'Historical synthetic rejection'; receipt = $reference}}
    }
    $after = Test-CompleteClone $state
    $after.committedRevision = 'head-N'; $after.committedOutputManifest = $afterManifest
    $after.requests[0].Remove('pendingEvidence'); $after.requests[0].status = 'Applied'
    $after.requests[0].preparedOperationId = 'op-explicit'
    $after.requests[0].terminalEvidence = [ordered]@{resourceId = 'board-S17'; requestId = 'R-new'; digest = $record.digest
      status = 'Applied'; reason = 'Planned caller-validated outcome'; receipt = $reference}
    $operation = [ordered]@{
      operationId = 'op-explicit'; resourceId = 'board-S17'; status = 'Prepared'
      baseHead = [ordered]@{generation = 'epoch-A'; committedRevision = 'head-A'; outputManifest = $manifest}
      nextRevision = 'head-N'; requestIds = @('R-new')
      beforeStateImage = Test-CompleteImage (Test-CompleteBytes $state -Projection)
      afterStateImage = Test-CompleteImage (Test-CompleteBytes $after -Projection)
      beforeOutputs = $beforeOutputs; afterOutputs = $afterOutputs; outputManifest = $afterManifest; reservations = $state.reservations
    }
    if ($History) {
      # Shape/history retention data only, not authenticated completion or graph proof.
      $old = Test-CompleteClone $operation
      $old.operationId = 'old-op'; $old.status = 'Applied'; $old.commitReceiptId = 'old-receipt'; $old.requestIds = @('R-old')
      $state.preparedOperations = @($old)
      $state.commitReceipts = @([ordered]@{receiptId = 'old-receipt'; resourceId = 'board-S17'; operationId = 'old-op'
        generation = 'epoch-A'; committedRevision = 'head-A'; requestIds = @('R-old'); outputManifest = $manifest
        reservations = $state.reservations; terminalEvidence = @([ordered]@{resourceId = 'board-S17'; requestId = 'R-old'
          digest = ('3' * 64); status = 'Applied'; reason = 'Historical synthetic outcome'; receipt = $reference})})
    }
    $path = Join-Path $root 'state.json'
    [byte[]]$raw = Test-CompleteBytes $state
    [IO.File]::WriteAllBytes($path, $raw)
    return @{Root = $root; Path = $path; Raw = $raw; State = $state; AfterState = $after; Operation = $operation}
  }
  function Invoke-PreparedFixture($Fixture, [switch]$WhatIf, [byte[]]$Expected) {
    if(-not $PSBoundParameters.ContainsKey('Expected')){$Expected = $Fixture.Raw}
    Save-CoordOperation -StatePath $Fixture.Path -ExpectedStateBytes $Expected -Operation (Test-CompleteElement (Test-CompleteBytes $Fixture.Operation)) -Confirm:$false -WhatIf:$WhatIf
  }
  function Get-CompleteFiles([string]$Root) {
    return @(Get-ChildItem -LiteralPath $Root -Force -File | Sort-Object Name | ForEach-Object {
      $_.Name + ':' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName)) + ':' + $_.LastWriteTimeUtc.Ticks
    }) -join '|'
  }
  function Get-CompleteBoards($Fixture) {
    return @($slotNames | ForEach-Object {
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($Fixture.Operation.beforeOutputs[$_].path))
    }) -join '|'
  }
}

BeforeAll {
  function New-PreparedCompleteFixture {
    param([switch]$History, [switch]$Unchanged, [switch]$EmptyMarkdown)
    $fixture = New-CompleteFixture -History:$History
    if ($EmptyMarkdown) {
      $image = Test-CompleteImage ([byte[]]@()) $fixture.Operation.beforeOutputs.markdown.path
      $fixture.Operation.beforeOutputs.markdown = $image
      $fixture.State.committedOutputManifest.markdown.digest = $image.digest
      [IO.File]::WriteAllBytes($image.path, [byte[]]@())
    }
    if ($Unchanged) {
      $fixture.Operation.afterOutputs = Test-CompleteClone $fixture.Operation.beforeOutputs
      $fixture.Operation.outputManifest = Test-CompleteClone $fixture.State.committedOutputManifest
      $fixture.AfterState.committedOutputManifest = Test-CompleteClone $fixture.State.committedOutputManifest
    }
    $fixture.Operation.baseHead.outputManifest = $fixture.State.committedOutputManifest
    $fixture.Operation.beforeStateImage = Test-CompleteImage (Test-CompleteBytes $fixture.State -Projection)
    $fixture.Operation.afterStateImage = Test-CompleteImage (Test-CompleteBytes $fixture.AfterState -Projection)
    [IO.File]::WriteAllBytes($fixture.Path, (Test-CompleteBytes $fixture.State))
    $fixture.Raw = [IO.File]::ReadAllBytes($fixture.Path)
    $script:caseRoot = $fixture.Root; $script:caseStatePath = $fixture.Path
    $null = Invoke-PreparedFixture $fixture
    $fixture.Raw = [IO.File]::ReadAllBytes($fixture.Path)
    $script:events.Clear(); $script:outputReplaces = 0; $script:stateReplaces = 0
    return $fixture
  }
  function Invoke-CompleteFixture {
    param($Fixture, [switch]$Resume, [switch]$Preview, [byte[]]$Expected)
    if (-not $PSBoundParameters.ContainsKey('Expected')) { $Expected = [IO.File]::ReadAllBytes($Fixture.Path) }
    Complete-CoordOperation -StatePath $Fixture.Path -ExpectedStateBytes $Expected -OperationId 'op-explicit' -Resume:$Resume -WhatIf:$Preview -Confirm:$false
  }
  function Read-CompleteFixture($Fixture) {
    Get-Content -LiteralPath $Fixture.Path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
  }
  function Write-CompleteFixture($Fixture, $Value) {
    [IO.File]::WriteAllBytes($Fixture.Path, (Test-CompleteBytes $Value))
  }
  function Assert-CompleteIoPath([string]$Path) {
    if (-not ([IO.Path]::GetFullPath($Path)).StartsWith($script:caseRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Test I/O escaped its disposable case.'
    }
  }
}

Describe 'Complete-CoordOperation retained plan completion (D-only synthetic custody)' -Tag 'Unit' {
  BeforeEach {
    $script:events = [Collections.Generic.List[string]]::new()
    $script:outputReplaces = 0; $script:stateReplaces = 0
    $script:interruptAfter = 0; $script:fault = ''; $script:driftBeforeCommit = $null
    $script:stateDriftOnOutputStage = $false
    $script:unreadablePath = ''
    Mock Write-PSFMessage {}
    Mock Invoke-CoordOperationFileIo {
      param($Phase, $StatePath, $StagePath, $Bytes)
      Assert-CompleteIoPath $StatePath
      if ($StagePath) {
        Assert-CompleteIoPath $StagePath
        if ((Split-Path $StagePath -Parent) -cne (Split-Path $StatePath -Parent)) { throw 'Stage is not beside target.' }
      }
      $script:events.Add($Phase + ':' + $StatePath)
      $isState = $StatePath -ceq $script:caseStatePath
      if ($Phase -eq 'ReadBack' -and $StatePath -ceq $script:unreadablePath) { throw 'Synthetic unavailable output.' }
      if ($script:fault -eq 'StateReplace' -and $isState -and $Phase -eq 'Replace') {
        $script:fault = ''; throw 'Synthetic state replacement failure.'
      }
      if ($script:fault -eq 'OutputStage' -and -not $isState -and $Phase -eq 'Stage') {
        $script:fault = ''; throw 'Synthetic output stage failure.'
      }
      if ($script:fault -eq 'StateStage' -and $isState -and $Phase -eq 'Stage') {
        $null = & $script:realCoordIo @PSBoundParameters
        $script:fault = ''; throw 'Synthetic failure after state stage.'
      }
      $value = & $script:realCoordIo @PSBoundParameters
      if ($Phase -eq 'Stage' -and -not $isState -and $script:stateDriftOnOutputStage) {
        $foreign = Get-Content -LiteralPath $script:caseStatePath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $foreign.committedRevision = 'foreign-head'
        [IO.File]::WriteAllBytes($script:caseStatePath, (Test-CompleteBytes $foreign))
        $script:stateDriftOnOutputStage = $false
      }
      if ($Phase -eq 'Stage' -and $isState -and $null -ne $script:driftBeforeCommit) {
        [IO.File]::WriteAllBytes($script:driftBeforeCommit, $enc.GetBytes('late-third'))
        $script:driftBeforeCommit = $null
      }
      if ($Phase -eq 'Replace') {
        if ($isState) { $script:stateReplaces++ } else { $script:outputReplaces++ }
        if (-not $isState -and $script:interruptAfter -eq $script:outputReplaces) {
          $script:interruptAfter = 0; throw 'Synthetic interruption after output replacement.'
        }
      }
      if ($script:fault -eq 'StateReadBack' -and $isState -and $Phase -eq 'ReadBack' -and $script:stateReplaces -gt 0) {
        $script:fault = ''; throw 'Synthetic uncertain state readback.'
      }
      if ($Phase -eq 'ReadBack') { return ,([byte[]]$value) }
    }
  }

  It 'completes all-before and commits one coherent receipt, head and member result' {
    $f = New-PreparedCompleteFixture
    $r = Invoke-CompleteFixture $f
    $r.Stage | Should -Be 'Applied'
    $r.Action | Should -Be 'Completed'
    $r.CommitReceiptId | Should -Be 'op-explicit'
    $r.Generation | Should -Be 'epoch-A'
    $script:outputReplaces | Should -Be 4
    $s = Read-CompleteFixture $f
    $s.committedRevision | Should -Be 'head-N'
    $s.requests[0].status | Should -Be 'Applied'
    $s.preparedOperations[0].status | Should -Be 'Applied'
    $s.preparedOperations[0].commitReceiptId | Should -Be 'op-explicit'
    $s.commitReceipts.Count | Should -Be 1
    $s.commitReceipts[0].receiptId | Should -Be 'op-explicit'
    $s.commitReceipts[0].terminalEvidence[0].digest | Should -Be $f.State.requests[0].digest
    (Test-CompleteJson $s.reservations $null) | Should -Be (Test-CompleteJson $f.State.reservations $null)
    foreach ($slot in $slotNames) {
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($f.Operation.afterOutputs[$slot].path)) | Should -Be $f.Operation.afterOutputs[$slot].bytesBase64
    }
    $stateReplaceIndex = $script:events.FindLastIndex([Predicate[string]]{ param($line) $line -eq ('Replace:' + $f.Path) })
    $outputReplaceIndex = $script:events.FindLastIndex([Predicate[string]]{ param($line) $line.StartsWith('Replace:') -and $line -ne ('Replace:' + $f.Path) })
    $stateReplaceIndex | Should -BeGreaterThan $outputReplaceIndex
  }

  It 'skips <Count> already-after files without changing their mtimes' -ForEach @(
    @{ Count = 1 }; @{ Count = 2 }; @{ Count = 3 }; @{ Count = 4 }
  ) {
    $f = New-PreparedCompleteFixture
    $times = @{}
    for ($i = 0; $i -lt $Count; $i++) {
      $image = $f.Operation.afterOutputs[$slotNames[$i]]
      [IO.File]::WriteAllBytes($image.path, [Convert]::FromBase64String($image.bytesBase64))
      $times[$image.path] = [IO.File]::GetLastWriteTimeUtc($image.path).Ticks
    }
    (Invoke-CompleteFixture $f).Stage | Should -Be 'Applied'
    $script:outputReplaces | Should -Be (4 - $Count)
    foreach ($path in $times.Keys) { [IO.File]::GetLastWriteTimeUtc($path).Ticks | Should -Be $times[$path] }
  }

  It 'commits a business-only batch with unchanged raw outputs including an empty existing file' {
    $f = New-PreparedCompleteFixture -Unchanged -EmptyMarkdown
    $boards = Get-CompleteBoards $f
    (Invoke-CompleteFixture $f).Stage | Should -Be 'Applied'
    $script:outputReplaces | Should -Be 0
    Get-CompleteBoards $f | Should -Be $boards
    (Read-CompleteFixture $f).committedRevision | Should -Be 'head-N'
  }

  It 'preserves a third preimage and persists recovery at the old head without any output write' {
    $f = New-PreparedCompleteFixture
    $path = $f.Operation.beforeOutputs.boardHtml.path
    [IO.File]::WriteAllBytes($path, [byte[]]@(0, 13, 10, 255))
    $boards = Get-CompleteBoards $f
    $r = Invoke-CompleteFixture $f
    $r.Stage | Should -Be 'NeedsRecovery'
    $script:outputReplaces | Should -Be 0
    Get-CompleteBoards $f | Should -Be $boards
    $s = Read-CompleteFixture $f
    $s.committedRevision | Should -Be 'head-A'
    $s.commitReceipts.Count | Should -Be 0
    $s.requests[0].status | Should -Be 'NeedsRecovery'
    $s.mutationAdmission.status | Should -Be 'NeedsRecovery'
    $s.preparedOperations[0].recoveryEvidence.observedOutputs.Count | Should -Be 4
    $s.preparedOperations[0].recoveryEvidence.observedOutputs[1].bytesBase64 | Should -Be ([Convert]::ToBase64String([byte[]]@(0, 13, 10, 255)))
  }

  It 'does not invent empty bytes for a missing output' {
    $f = New-PreparedCompleteFixture
    [IO.File]::Delete($f.Operation.beforeOutputs.boardHtml.path)
    (Invoke-CompleteFixture $f).Stage | Should -Be 'NeedsRecovery'
    [IO.File]::Exists($f.Operation.beforeOutputs.boardHtml.path) | Should -BeFalse
    $s = Read-CompleteFixture $f
    $s.preparedOperations[0].recoveryEvidence.observedOutputs.Count | Should -Be 3
    $s.commitReceipts.Count | Should -Be 0
  }

  It 'retains recovery without Resume even with a stale mutation preimage' {
    $f = New-PreparedCompleteFixture
    [IO.File]::WriteAllText($f.Operation.beforeOutputs.markdown.path, 'third')
    $null = Invoke-CompleteFixture $f
    $before = Get-CompleteFiles $f.Root
    (Invoke-CompleteFixture $f -Expected ([byte[]]@(1))).Action | Should -Be 'Held'
    Get-CompleteFiles $f.Root | Should -Be $before
  }

  It 'preserves prefix after interruption at slot <Boundary> then resumes the same plan once' -ForEach @(
    @{ Boundary = 1 }; @{ Boundary = 2 }; @{ Boundary = 3 }; @{ Boundary = 4 }
  ) {
    $f = New-PreparedCompleteFixture
    $script:interruptAfter = $Boundary
    (Invoke-CompleteFixture $f).Stage | Should -Be 'NeedsRecovery'
    $s = Read-CompleteFixture $f
    $s.committedRevision | Should -Be 'head-A'
    $s.commitReceipts.Count | Should -Be 0
    for ($i = 0; $i -lt 4; $i++) {
      $expected = if ($i -lt $Boundary) { $f.Operation.afterOutputs[$slotNames[$i]] } else { $f.Operation.beforeOutputs[$slotNames[$i]] }
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($expected.path)) | Should -Be $expected.bytesBase64
    }
    (Invoke-CompleteFixture $f -Resume).Stage | Should -Be 'Applied'
    $s = Read-CompleteFixture $f
    $s.committedRevision | Should -Be 'head-N'
    $s.commitReceipts.Count | Should -Be 1
    $s.preparedOperations[0].operationId | Should -Be 'op-explicit'
    $s.preparedOperations[0].nextRevision | Should -Be 'head-N'
    $s.preparedOperations[0].Contains('recoveryEvidence') | Should -BeTrue
    $s.requests[0].Contains('recoveryEvidence') | Should -BeFalse
  }

  It 'keeps unresolved third bytes held under explicit Resume' {
    $f = New-PreparedCompleteFixture
    [IO.File]::WriteAllText($f.Operation.beforeOutputs.boardHtml.path, 'third')
    $null = Invoke-CompleteFixture $f
    $boards = Get-CompleteBoards $f
    (Invoke-CompleteFixture $f -Resume).Stage | Should -Be 'NeedsRecovery'
    Get-CompleteBoards $f | Should -Be $boards
    (Read-CompleteFixture $f).committedRevision | Should -Be 'head-A'
  }

  It 'persists recovery after an output staging failure' {
    $f = New-PreparedCompleteFixture
    $script:fault = 'OutputStage'
    (Invoke-CompleteFixture $f).Stage | Should -Be 'NeedsRecovery'
    $script:outputReplaces | Should -Be 0
    (Read-CompleteFixture $f).committedRevision | Should -Be 'head-A'
  }

  It 'retains staging and never advertises completion after <Fault>' -ForEach @(
    @{ Fault = 'StateStage' }; @{ Fault = 'StateReplace' }
  ) {
    $f = New-PreparedCompleteFixture
    $script:fault = $Fault
    { Invoke-CompleteFixture $f } | Should -Throw '*PersistenceFailed*'
    (Read-CompleteFixture $f).committedRevision | Should -Be 'head-A'
    (Read-CompleteFixture $f).commitReceipts.Count | Should -Be 0
    @([IO.Directory]::GetFiles($f.Root, '*.complete.tmp')).Count | Should -Be 1
    (Invoke-CompleteFixture $f).Stage | Should -Be 'Applied'
  }

  It 'recognizes an already-committed state after uncertain readback with no second publication' {
    $f = New-PreparedCompleteFixture
    $script:fault = 'StateReadBack'
    { Invoke-CompleteFixture $f } | Should -Throw '*PersistenceFailed*'
    $s = Read-CompleteFixture $f
    $s.preparedOperations[0].status | Should -Be 'Applied'
    $snapshot = Get-CompleteFiles $f.Root
    $script:events.Clear()
    (Invoke-CompleteFixture $f -Expected $f.Raw).Stage | Should -Be 'Retained'
    $script:events.Count | Should -Be 0
    Get-CompleteFiles $f.Root | Should -Be $snapshot
    (Read-CompleteFixture $f).commitReceipts.Count | Should -Be 1
  }

  It 'returns the historical receipt after later head/generation and output changes without replay' {
    $f = New-PreparedCompleteFixture
    $null = Invoke-CompleteFixture $f
    $s = Read-CompleteFixture $f
    $s.generation = 'epoch-L'; $s.committedRevision = 'head-L'
    $s.mutationAdmission.status = 'Held'
    Write-CompleteFixture $f $s
    [IO.File]::WriteAllText($f.Operation.afterOutputs.markdown.path, 'later-head-output')
    $snapshot = Get-CompleteFiles $f.Root
    $script:events.Clear()
    $r = Invoke-CompleteFixture $f -Expected $f.Raw
    $r.Stage | Should -Be 'Retained'
    $r.Generation | Should -Be 'epoch-A'
    $r.NextRevision | Should -Be 'head-N'
    $r.CommitReceiptId | Should -Be 'op-explicit'
    $script:events.Count | Should -Be 0
    Get-CompleteFiles $f.Root | Should -Be $snapshot
  }

  It 'preserves opaque numeric lexemes, original JSON, reservations and old journals/receipts' {
    $f = New-PreparedCompleteFixture -History
    $before = Read-CompleteFixture $f
    (Invoke-CompleteFixture $f).Stage | Should -Be 'Applied'
    $text = [IO.File]::ReadAllText($f.Path)
    $text | Should -Match '"opaque":1e2'
    $s = Read-CompleteFixture $f
    $s.requests[1].originalRequestJson | Should -BeExactly $before.requests[1].originalRequestJson
    (Test-CompleteJson $s.preparedOperations[0] $null) | Should -Be (Test-CompleteJson $before.preparedOperations[0] $null)
    (Test-CompleteJson $s.commitReceipts[0] $null) | Should -Be (Test-CompleteJson $before.commitReceipts[0] $null)
    (Test-CompleteJson $s.reservations $null) | Should -Be (Test-CompleteJson $before.reservations $null)
  }

  It 'makes WhatIf effect-free for <Mode>' -ForEach @(
    @{ Mode = 'Prepared' }; @{ Mode = 'Third' }; @{ Mode = 'RecoveryResume' }
  ) {
    $f = New-PreparedCompleteFixture
    if ($Mode -ne 'Prepared') { [IO.File]::WriteAllText($f.Operation.beforeOutputs.boardHtml.path, 'third') }
    if ($Mode -eq 'RecoveryResume') { $null = Invoke-CompleteFixture $f }
    $snapshot = Get-CompleteFiles $f.Root
    $script:events.Clear()
    $r = Invoke-CompleteFixture $f -Preview -Resume:($Mode -eq 'RecoveryResume')
    $r.Stage | Should -Be 'ProposedNotCompleted'
    $r.PersistedStateSha256 | Should -BeNullOrEmpty
    @($script:events | Where-Object { $_.StartsWith('Stage:') -or $_.StartsWith('Replace:') }).Count | Should -Be 0
    Get-CompleteFiles $f.Root | Should -Be $snapshot
  }

  It 'rejects a stale preimage or unrelated business drift before output effects' -ForEach @(
    @{ Mode = 'Stale' }; @{ Mode = 'Reservations' }; @{ Mode = 'Admission' }
  ) {
    $f = New-PreparedCompleteFixture
    if ($Mode -eq 'Reservations') { $s = Read-CompleteFixture $f; $s.reservations[0].taskId = '17.changed'; Write-CompleteFixture $f $s }
    if ($Mode -eq 'Admission') {
      $s = Read-CompleteFixture $f; $s.mutationAdmission.reason = 'unrelated business change'; Write-CompleteFixture $f $s
    }
    $snapshot = Get-CompleteFiles $f.Root
    $expected = if ($Mode -eq 'Stale') { [byte[]]@(1) } else { [IO.File]::ReadAllBytes($f.Path) }
    { Invoke-CompleteFixture $f -Expected $expected } | Should -Throw '*SnapshotMismatch*'
    Get-CompleteFiles $f.Root | Should -Be $snapshot
  }

  It 'refuses deterministic receipt collision before output publication' {
    $f = New-PreparedCompleteFixture -History
    $s = Read-CompleteFixture $f
    $s.commitReceipts[0].receiptId = 'op-explicit'
    Write-CompleteFixture $f $s
    $snapshot = Get-CompleteFiles $f.Root
    { Invoke-CompleteFixture $f } | Should -Throw '*OperationConflict*'
    Get-CompleteFiles $f.Root | Should -Be $snapshot
  }

  It 'rejects corrupt stored images or member results without writes' -ForEach @(
    @{ Mode = 'Digest' }; @{ Mode = 'Base64' }; @{ Mode = 'Recursive' }; @{ Mode = 'Terminal' }; @{ Mode = 'DuplicateOperation' }
  ) {
    $f = New-PreparedCompleteFixture
    $s = Read-CompleteFixture $f
    switch ($Mode) {
      'Digest' { $s.preparedOperations[0].beforeStateImage.digest = '0' * 64 }
      'Base64' { $s.preparedOperations[0].afterOutputs.markdown.bytesBase64 = '%%%' }
      'Recursive' { $s.preparedOperations[0].beforeStateImage = Test-CompleteImage ([IO.File]::ReadAllBytes($f.Path)) }
      'Terminal' {
        $f.AfterState.requests[0].terminalEvidence.digest = '0' * 64
        $s.preparedOperations[0].afterStateImage = Test-CompleteImage (Test-CompleteBytes $f.AfterState -Projection)
      }
      'DuplicateOperation' { $s.preparedOperations += Test-CompleteClone $s.preparedOperations[0] }
    }
    Write-CompleteFixture $f $s
    $snapshot = Get-CompleteFiles $f.Root
    { Invoke-CompleteFixture $f } | Should -Throw '*Complete-CoordOperation*'
    Get-CompleteFiles $f.Root | Should -Be $snapshot
  }

  It 'detects last-moment third bytes before final state replacement' {
    $f = New-PreparedCompleteFixture
    $script:driftBeforeCommit = $f.Operation.afterOutputs.boardHtml.path
    (Invoke-CompleteFixture $f).Stage | Should -Be 'NeedsRecovery'
    [IO.File]::ReadAllText($f.Operation.afterOutputs.boardHtml.path) | Should -Be 'late-third'
    $s = Read-CompleteFixture $f
    $s.committedRevision | Should -Be 'head-A'
    $s.commitReceipts.Count | Should -Be 0
  }

  It 'does not initialize a missing state' {
    $f = New-PreparedCompleteFixture
    [IO.File]::Delete($f.Path)
    { Invoke-CompleteFixture $f -Expected $f.Raw } | Should -Throw '*MissingEstablishedState*'
    [IO.File]::Exists($f.Path) | Should -BeFalse
  }

  It 'orders a two-member aggregate by stored requestIds while preserving request array order' {
    $f = New-CompleteFixture
    $second = Test-CompleteClone $f.State.requests[0]
    $second.request.requestId = 'R-two'; $second.request.taskId = '17.28'
    $second.request.scope[0].path = 'second.ps1'
    $second.originalRequestJson = Test-CompleteJson $second.request $null
    $second.digest = Test-CompleteSha $enc.GetBytes($second.originalRequestJson)
    $second.queueOrdinal = '2'
    $f.State.requests += $second
    $applied = Test-CompleteClone $second
    $applied.Remove('pendingEvidence'); $applied.status = 'Applied'; $applied.preparedOperationId = 'op-explicit'
    $applied.terminalEvidence = Test-CompleteClone $f.AfterState.requests[0].terminalEvidence
    $applied.terminalEvidence.requestId = 'R-two'; $applied.terminalEvidence.digest = $second.digest
    $f.AfterState.requests += $applied
    $f.Operation.requestIds = @('R-two', 'R-new')
    $f.Operation.beforeStateImage = Test-CompleteImage (Test-CompleteBytes $f.State -Projection)
    $f.Operation.afterStateImage = Test-CompleteImage (Test-CompleteBytes $f.AfterState -Projection)
    $f.Raw = Test-CompleteBytes $f.State
    [IO.File]::WriteAllBytes($f.Path, $f.Raw)
    $script:caseRoot = $f.Root; $script:caseStatePath = $f.Path
    $null = Invoke-PreparedFixture $f
    $script:events.Clear(); $script:outputReplaces = 0; $script:stateReplaces = 0
    (Invoke-CompleteFixture $f).Stage | Should -Be 'Applied'
    $s = Read-CompleteFixture $f
    $s.requests[0].request.requestId | Should -Be 'R-new'
    $s.requests[1].request.requestId | Should -Be 'R-two'
    ($s.commitReceipts[0].requestIds -join ',') | Should -Be 'R-two,R-new'
    (@($s.commitReceipts[0].terminalEvidence | ForEach-Object requestId) -join ',') | Should -Be 'R-two,R-new'
    $s.commitReceipts.Count | Should -Be 1
  }

  It 'keeps case-only member IDs distinct in ordered receipt evidence and effect-free historical retry' {
    $f = New-CompleteFixture
    $second = Test-CompleteClone $f.State.requests[0]
    $second.request.requestId = 'r-new'; $second.request.taskId = '17.28'
    $second.request.scope[0].path = 'second.ps1'
    $second.originalRequestJson = Test-CompleteJson $second.request $null
    $second.digest = Test-CompleteSha $enc.GetBytes($second.originalRequestJson)
    $second.queueOrdinal = '2'
    $second.digest | Should -Not -BeExactly $f.State.requests[0].digest
    $f.State.requests += $second
    $applied = Test-CompleteClone $second
    $applied.Remove('pendingEvidence'); $applied.status = 'Applied'; $applied.preparedOperationId = 'op-explicit'
    $applied.terminalEvidence = Test-CompleteClone $f.AfterState.requests[0].terminalEvidence
    $applied.terminalEvidence.requestId = 'r-new'; $applied.terminalEvidence.digest = $second.digest
    $f.AfterState.requests += $applied
    $f.Operation.requestIds = @('r-new', 'R-new')
    $f.Operation.beforeStateImage = Test-CompleteImage (Test-CompleteBytes $f.State -Projection)
    $f.Operation.afterStateImage = Test-CompleteImage (Test-CompleteBytes $f.AfterState -Projection)
    $f.Raw = Test-CompleteBytes $f.State
    [IO.File]::WriteAllBytes($f.Path, $f.Raw)
    $script:caseRoot = $f.Root; $script:caseStatePath = $f.Path
    $null = Invoke-PreparedFixture $f
    $script:events.Clear(); $script:outputReplaces = 0; $script:stateReplaces = 0

    (Invoke-CompleteFixture $f).Stage | Should -Be 'Applied'
    $s = Read-CompleteFixture $f
    $s.requests.Count | Should -Be 2
    (Test-CompleteJson $s.requests[0] $null) | Should -BeExactly (Test-CompleteJson $f.AfterState.requests[0] $null)
    (Test-CompleteJson $s.requests[1] $null) | Should -BeExactly (Test-CompleteJson $f.AfterState.requests[1] $null)
    $s.commitReceipts.Count | Should -Be 1
    $receipt = $s.commitReceipts[0]
    $receipt.requestIds.Count | Should -Be 2
    ($receipt.requestIds -join ',') | Should -BeExactly 'r-new,R-new'
    $receipt.terminalEvidence.Count | Should -Be 2
    $receipt.terminalEvidence[0].requestId | Should -BeExactly 'r-new'
    $receipt.terminalEvidence[0].digest | Should -BeExactly $second.digest
    $receipt.terminalEvidence[1].requestId | Should -BeExactly 'R-new'
    $receipt.terminalEvidence[1].digest | Should -BeExactly $f.State.requests[0].digest
    (Test-CompleteJson $receipt.terminalEvidence[0] $null) | Should -BeExactly (Test-CompleteJson $f.AfterState.requests[1].terminalEvidence $null)
    (Test-CompleteJson $receipt.terminalEvidence[1] $null) | Should -BeExactly (Test-CompleteJson $f.AfterState.requests[0].terminalEvidence $null)

    $snapshot = Get-CompleteFiles $f.Root
    $script:events.Clear()
    $retry = Invoke-CompleteFixture $f -Expected $f.Raw
    $retry.Stage | Should -Be 'Retained'
    $retry.Action | Should -Be 'Unchanged'
    $retry.CommitReceiptId | Should -BeExactly $receipt.receiptId
    $script:events.Count | Should -Be 0
    Get-CompleteFiles $f.Root | Should -BeExactly $snapshot
  }

  It 'retains an imported historical receipt ID rather than relabelling it' {
    $f = New-PreparedCompleteFixture
    $null = Invoke-CompleteFixture $f
    $s = Read-CompleteFixture $f
    # Synthetic valid imported history; this is not an authorized relabelling operation.
    $s.preparedOperations[0].commitReceiptId = 'legacy-receipt'
    $s.commitReceipts[0].receiptId = 'legacy-receipt'
    Write-CompleteFixture $f $s
    $snapshot = Get-CompleteFiles $f.Root
    $script:events.Clear()
    (Invoke-CompleteFixture $f -Expected $f.Raw).CommitReceiptId | Should -Be 'legacy-receipt'
    $script:events.Count | Should -Be 0
    Get-CompleteFiles $f.Root | Should -Be $snapshot
  }

  It 'preserves foreign state after custody loss without writing a recovery overlay' {
    $f = New-PreparedCompleteFixture
    $boards = Get-CompleteBoards $f
    $script:stateDriftOnOutputStage = $true
    { Invoke-CompleteFixture $f } | Should -Throw '*SnapshotMismatch*'
    $s = Read-CompleteFixture $f
    $s.committedRevision | Should -Be 'foreign-head'
    $s.preparedOperations[0].status | Should -Be 'Prepared'
    $s.commitReceipts.Count | Should -Be 0
    $script:stateReplaces | Should -Be 0
    Get-CompleteBoards $f | Should -Be $boards
  }

  It 'records only known observations when an existing output is unreadable' {
    $f = New-PreparedCompleteFixture
    $boards = Get-CompleteBoards $f
    $script:unreadablePath = $f.Operation.beforeOutputs.boardHtml.path
    (Invoke-CompleteFixture $f).Stage | Should -Be 'NeedsRecovery'
    $s = Read-CompleteFixture $f
    $s.preparedOperations[0].recoveryEvidence.observedOutputs.Count | Should -Be 3
    Get-CompleteBoards $f | Should -Be $boards
    $s.commitReceipts.Count | Should -Be 0
  }

  It 'does not claim durable recovery when recovery persistence fails' {
    $f = New-PreparedCompleteFixture
    [IO.File]::WriteAllText($f.Operation.beforeOutputs.boardHtml.path, 'third')
    $boards = Get-CompleteBoards $f
    $script:fault = 'StateStage'
    { Invoke-CompleteFixture $f } | Should -Throw '*PersistenceFailed*'
    $s = Read-CompleteFixture $f
    $s.preparedOperations[0].status | Should -Be 'Prepared'
    $s.mutationAdmission.status | Should -Be 'Admitted'
    $s.commitReceipts.Count | Should -Be 0
    Get-CompleteBoards $f | Should -Be $boards
  }
}

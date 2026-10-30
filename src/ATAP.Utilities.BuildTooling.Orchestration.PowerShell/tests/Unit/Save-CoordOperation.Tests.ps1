#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
param([Parameter()][string]$FixtureRoot = $(if ([Environment]::MachineName -ieq 'UTAT022') { 'D:\ATAPArtifacts\Sprint0017\Task17.27\PackageTests' } else { throw 'FixtureRoot must be supplied explicitly on this host.' }))

BeforeAll {
  $allowed = [IO.Path]::GetFullPath('D:/ATAPArtifacts/Sprint0017/Task17.27').TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  $script:runRoot = [IO.Path]::GetFullPath($FixtureRoot)
  if (-not $runRoot.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'D-only FixtureRoot required.' }
  $null = [IO.Directory]::CreateDirectory($runRoot)
  $null = Get-Command Write-PSFMessage -ErrorAction Stop
  . (Join-Path $PSScriptRoot '../../private/Save-CoordOperation.ps1')
  $script:realCoordIo = (Get-Command Invoke-CoordOperationFileIo -CommandType Function).ScriptBlock
  $script:enc = [Text.UTF8Encoding]::new($false, $true)
  # Independent hex-key fixture oracle; production serializer is never called.
  $script:projection = @('schemaVersion', 'resourceId', 'lineageId', 'registeredRoots', 'generation',
    'committedRevision', 'committedOutputManifest', 'custodyEvidence', 'compatibilityEvidence',
    'admissionEvidence', 'requests', 'claims', 'reservations', 'mutationAdmission')
  $script:slotNames = @('markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml')

  function Test-SaveSha([byte[]]$Bytes) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
  }
  function Test-SaveJson($Value, [string[]]$TopNames) {
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [System.Collections.IDictionary]) {
      [string[]]$keys = if ($null -ne $TopNames) { $TopNames } else { @($Value.Keys) }
      if ($null -eq $TopNames) {
        $order = [Collections.Generic.SortedDictionary[string, string]]::new([StringComparer]::Ordinal)
        foreach ($key in $keys) { $order.Add([Convert]::ToHexString($enc.GetBytes($key)), $key) }
        $keys = @($order.Values)
      }
      $pairs = foreach ($key in $keys) {
        (ConvertTo-Json -InputObject ([string]$key) -Compress) + ':' + (Test-SaveJson $Value[$key] $null)
      }
      return '{' + ($pairs -join ',') + '}'
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
      return '[' + (@($Value | ForEach-Object { Test-SaveJson $_ $null }) -join ',') + ']'
    }
    return (ConvertTo-Json -InputObject $Value -Depth 100 -Compress)
  }
  function Test-SaveBytes($Value, [switch]$Projection) {
    $names = if ($Projection) { $script:projection } else { $null }
    $json = (Test-SaveJson $Value $names).Replace('"__RAW_NUMBER__"', '1e2')
    return , ($enc.GetBytes($json + [char]10))
  }
  function Test-SaveElement([byte[]]$Bytes) {
    $doc = [System.Text.Json.JsonDocument]::Parse($enc.GetString($Bytes))
    try { $doc.RootElement.Clone() } finally { $doc.Dispose() }
  }
  function Test-SaveClone($Value) { (Test-SaveJson $Value $null) | ConvertFrom-Json -AsHashtable -Depth 100 }
  function Test-SaveImage([byte[]]$Bytes, [string]$Path) {
    $value = [ordered]@{ bytesBase64 = [Convert]::ToBase64String($Bytes); digest = Test-SaveSha $Bytes }
    if ($Path) { $value.path = $Path }
    return $value
  }
  function New-SaveFixture([switch]$History) {
    $root = Join-Path $runRoot ([guid]::NewGuid().ToString('N'))
    $null = [IO.Directory]::CreateDirectory($root)
    $manifest = [ordered]@{}; $beforeOutputs = [ordered]@{}; $afterOutputs = [ordered]@{}; $afterManifest = [ordered]@{}
    foreach ($slot in $slotNames) {
      $path = Join-Path $root ($slot + '.fixture')
      [byte[]]$before = if ($slot -eq 'markdown') { @(239, 187, 191) + $enc.GetBytes('Before board' + [char]13 + [char]10) } else { $enc.GetBytes("Before $slot" + [char]13 + [char]10) }
      [byte[]]$next = $enc.GetBytes("After $slot" + [char]10)
      [IO.File]::WriteAllBytes($path, $before)
      $beforeOutputs[$slot] = Test-SaveImage $before $path; $afterOutputs[$slot] = Test-SaveImage $next $path
      $manifest[$slot] = [ordered]@{path = $path; digest = Test-SaveSha $before}
      $afterManifest[$slot] = [ordered]@{path = $path; digest = Test-SaveSha $next}
    }
    # Shape-valid synthetic authority/evidence assumptions; no live admission proof.
    $request = [ordered]@{
      protocolVersion = 'Coordination-v1'; resourceId = 'board-S17'; sprintId = '0017'; requestId = 'R-new'
      category = 'Claim'; taskId = '17.27'; scope = @([ordered]@{registeredRootId = 'fixture'; path = 'owned.ps1'})
      holder = [ordered]@{holderId = 'fixture-holder'; sessionId = 'fixture-session'}
      authorizationReference = 'synthetic-boundary'; generation = 'epoch-A'; expectedRevision = 'head-A'
      predecessors = @(); payload = [ordered]@{}
    }
    $requestJson = Test-SaveJson $request $null
    $record = [ordered]@{request = $request; digest = Test-SaveSha $enc.GetBytes($requestJson); originalRequestJson = $requestJson
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
      $original = (Test-SaveJson $rejected $null).Replace('"__RAW_NUMBER__"', '1e2')
      $state.requests += [ordered]@{request = $rejected; digest = ('2' * 64); originalRequestJson = $original
        queueOrdinal = '999999999999999999999999999999999999'; status = 'Rejected'
        terminalEvidence = [ordered]@{resourceId = 'board-S17'; requestId = 'R-rejected'; digest = ('2' * 64)
          status = 'Rejected'; reason = 'Historical synthetic rejection'; receipt = $reference}}
    }
    $after = Test-SaveClone $state
    $after.committedRevision = 'head-N'; $after.committedOutputManifest = $afterManifest
    $after.requests[0].Remove('pendingEvidence'); $after.requests[0].status = 'Applied'
    $after.requests[0].preparedOperationId = 'op-explicit'
    $after.requests[0].terminalEvidence = [ordered]@{resourceId = 'board-S17'; requestId = 'R-new'; digest = $record.digest
      status = 'Applied'; reason = 'Planned caller-validated outcome'; receipt = $reference}
    $operation = [ordered]@{
      operationId = 'op-explicit'; resourceId = 'board-S17'; status = 'Prepared'
      baseHead = [ordered]@{generation = 'epoch-A'; committedRevision = 'head-A'; outputManifest = $manifest}
      nextRevision = 'head-N'; requestIds = @('R-new')
      beforeStateImage = Test-SaveImage (Test-SaveBytes $state -Projection)
      afterStateImage = Test-SaveImage (Test-SaveBytes $after -Projection)
      beforeOutputs = $beforeOutputs; afterOutputs = $afterOutputs; outputManifest = $afterManifest; reservations = $state.reservations
    }
    if ($History) {
      # Shape/history retention data only, not authenticated completion or graph proof.
      $old = Test-SaveClone $operation
      $old.operationId = 'old-op'; $old.status = 'Applied'; $old.commitReceiptId = 'old-receipt'; $old.requestIds = @('R-old')
      $state.preparedOperations = @($old)
      $state.commitReceipts = @([ordered]@{receiptId = 'old-receipt'; resourceId = 'board-S17'; operationId = 'old-op'
        generation = 'epoch-A'; committedRevision = 'head-A'; requestIds = @('R-old'); outputManifest = $manifest
        reservations = $state.reservations; terminalEvidence = @([ordered]@{resourceId = 'board-S17'; requestId = 'R-old'
          digest = ('3' * 64); status = 'Applied'; reason = 'Historical synthetic outcome'; receipt = $reference})})
    }
    $path = Join-Path $root 'state.json'
    [byte[]]$raw = Test-SaveBytes $state
    [IO.File]::WriteAllBytes($path, $raw)
    return @{Root = $root; Path = $path; Raw = $raw; State = $state; AfterState = $after; Operation = $operation}
  }
  function Invoke-SaveFixture($Fixture, [switch]$WhatIf, [byte[]]$Expected) {
    if(-not $PSBoundParameters.ContainsKey('Expected')){$Expected = $Fixture.Raw}
    Save-CoordOperation -StatePath $Fixture.Path -ExpectedStateBytes $Expected -Operation (Test-SaveElement (Test-SaveBytes $Fixture.Operation)) -Confirm:$false -WhatIf:$WhatIf
  }
  function Get-SaveFiles([string]$Root) {
    return @(Get-ChildItem -LiteralPath $Root -Force -File | Sort-Object Name | ForEach-Object {
      $_.Name + ':' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName)) + ':' + $_.LastWriteTimeUtc.Ticks
    }) -join '|'
  }
  function Get-SaveBoards($Fixture) {
    return @($slotNames | ForEach-Object {
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($Fixture.Operation.beforeOutputs[$_].path))
    }) -join '|'
  }
}

Describe 'Save-CoordOperation prepared persistence (D-only synthetic caller boundary)' -Tag 'Unit' {
  BeforeEach { Mock Write-PSFMessage {} }

  It 'persists supplied images and member bookkeeping, preserving board/head/reservations' {
    $f = New-SaveFixture; $boards = Get-SaveBoards $f
    $result = Invoke-SaveFixture $f
    $result.Stage | Should -BeExactly 'Prepared'
    $result.Action | Should -BeExactly 'Saved'
    $result.PersistedStateSha256 | Should -BeExactly (Test-SaveSha ([IO.File]::ReadAllBytes($f.Path)))
    $saved = Get-Content $f.Path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $saved.committedRevision | Should -BeExactly 'head-A'
    $saved.generation | Should -BeExactly 'epoch-A'
    $saved.preparedOperations.Count | Should -Be 1
    (Test-SaveJson $saved.preparedOperations[0] $null) | Should -BeExactly (Test-SaveJson $f.Operation $null)
    $saved.requests[0].status | Should -BeExactly 'Prepared'
    $saved.requests[0].preparedOperationId | Should -BeExactly 'op-explicit'
    $saved.requests[0].Contains('pendingEvidence') | Should -BeFalse
    (Test-SaveJson $saved.reservations $null) | Should -BeExactly (Test-SaveJson $f.State.reservations $null)
    $saved.commitReceipts.Count | Should -Be 0
    Get-SaveBoards $f | Should -BeExactly $boards
    $bytes = [IO.File]::ReadAllBytes($f.Path)
    ($bytes -contains [byte]13) | Should -BeFalse
    $bytes[-1] | Should -Be 10
    [Convert]::ToHexString($bytes) | Should -Not -Match '^EFBBBF'
  }

  It 'WhatIf leaves files/timestamps exact and never calls persistence' {
    $f = New-SaveFixture
    Mock Invoke-CoordOperationFileIo { throw 'Unexpected persistence' }
    $before = Get-SaveFiles $f.Root
    $result = Invoke-SaveFixture $f -WhatIf
    $result.Stage | Should -BeExactly 'ProposedNotPrepared'
    $result.OperationStatus | Should -BeNullOrEmpty
    $result.PersistedStateSha256 | Should -BeNullOrEmpty
    Get-SaveFiles $f.Root | Should -BeExactly $before
    Should -Invoke Invoke-CoordOperationFileIo -Times 0 -Exactly
  }

  It 'refuses missing established <Missing> without initialization' -ForEach @(@{Missing = 'file'}, @{Missing = 'root'}) {
    $f = New-SaveFixture
    if($Missing -eq 'file'){[IO.File]::Delete($f.Path)}else{$f.Path = Join-Path $f.Root 'absent/state.json'}
    {Invoke-SaveFixture $f} | Should -Throw '*MissingEstablishedState*'
    Test-Path $f.Path | Should -BeFalse
    Test-Path (Join-Path $f.Root 'absent') | Should -BeFalse
  }

  It 'uses raw expected bytes rather than BOM-stripped decoded equality' {
    $f = New-SaveFixture; $before = Get-SaveFiles $f.Root
    {Invoke-SaveFixture $f -Expected ([byte[]](@(239, 187, 191) + $f.Raw))} | Should -Throw '*SnapshotMismatch*'
    Get-SaveFiles $f.Root | Should -BeExactly $before
  }

  It 'refuses <Variant> before any persistence' -ForEach @(
    @{Variant = 'digest'}, @{Variant = 'after-digest'}, @{Variant = 'unknown-property'}, @{Variant = 'base64'}, @{Variant = 'missing-slot'}, @{Variant = 'manifest'},
    @{Variant = 'next-revision'}, @{Variant = 'reservations'}, @{Variant = 'duplicate-path'},
    @{Variant = 'foreign-member'}, @{Variant = 'after-metadata'}, @{Variant = 'stale-board'}
  ) {
    $f = New-SaveFixture
    switch($Variant){
      'digest' {$f.Operation.beforeOutputs.markdown.digest = '0' * 64}
      'after-digest' {$f.Operation.afterOutputs.markdown.digest = '0' * 64}
      'unknown-property' {$f.Operation.faultCallback = 'not executable or supported'}
      'base64' {$f.Operation.beforeOutputs.markdown.bytesBase64 += ' '}
      'missing-slot' {$f.Operation.afterOutputs.Remove('boardHtml')}
      'manifest' {$f.Operation.outputManifest.boardHtml.digest = '0' * 64}
      'next-revision' {$f.Operation.nextRevision = 'head-A'}
      'reservations' {$f.Operation.reservations = @()}
      'duplicate-path' {$f.Operation.beforeOutputs.boardHtml.path = $f.Operation.beforeOutputs.markdown.path}
      'foreign-member' {$f.Operation.requestIds = @('not-retained')}
      'after-metadata' {$f.AfterState.lineageId = 'substituted'; $f.Operation.afterStateImage = Test-SaveImage (Test-SaveBytes $f.AfterState -Projection)}
      'stale-board' {[IO.File]::WriteAllText($f.Operation.beforeOutputs.markdown.path, 'third state', $enc)}
    }
    $before = Get-SaveFiles $f.Root
    {Invoke-SaveFixture $f} | Should -Throw '*Save-CoordOperation:*'
    Get-SaveFiles $f.Root | Should -BeExactly $before
  }

  It 'rejects escaped duplicate property names in the plan' {
    $f = New-SaveFixture
    $json = $enc.GetString((Test-SaveBytes $f.Operation)).Replace('"operationId":', '"\u006fperationId":"duplicate","operationId":')
    $element = Test-SaveElement $enc.GetBytes($json); $before = Get-SaveFiles $f.Root
    {Save-CoordOperation -StatePath $f.Path -ExpectedStateBytes $f.Raw -Operation $element -Confirm:$false} |
      Should -Throw '*InvalidPreparedOperation*'
    Get-SaveFiles $f.Root | Should -BeExactly $before
  }

  It 'rejects malformed escaped Unicode in an identity without mutation' {
    $f = New-SaveFixture
    $json = $enc.GetString((Test-SaveBytes $f.Operation)).Replace('"operationId":"op-explicit"', '"operationId":"\ud800"')
    $element = Test-SaveElement $enc.GetBytes($json)
    $before = Get-SaveFiles $f.Root
    {Save-CoordOperation -StatePath $f.Path -ExpectedStateBytes $f.Raw -Operation $element -Confirm:$false} |
      Should -Throw '*InvalidPreparedOperation*'
    Get-SaveFiles $f.Root | Should -BeExactly $before
  }

  It 'refuses noncanonical or recursive <ImageVariant> images' -ForEach @(
    @{ImageVariant = 'missing-final-LF'}, @{ImageVariant = 'journal-field'}, @{ImageVariant = 'duplicate-key'}, @{ImageVariant = 'invalid-UTF8'}
  ) {
    $f = New-SaveFixture
    [byte[]]$raw = [Convert]::FromBase64String($f.Operation.beforeStateImage.bytesBase64)
    switch($ImageVariant){
      'missing-final-LF' {$raw = $raw[0..($raw.Length - 2)]}
      'journal-field' {$raw = $enc.GetBytes($enc.GetString($raw).Replace('{"schemaVersion":', '{"preparedOperations":[],"schemaVersion":'))}
      'duplicate-key' {$raw = $enc.GetBytes($enc.GetString($raw).Replace('"lineageId":', '"\u006cineageId":"duplicate","lineageId":'))}
      'invalid-UTF8' {$raw = [byte[]]@(255, 10)}
    }
    $f.Operation.beforeStateImage = Test-SaveImage $raw; $before = Get-SaveFiles $f.Root
    {Invoke-SaveFixture $f} | Should -Throw '*Save-CoordOperation:*'
    Get-SaveFiles $f.Root | Should -BeExactly $before
  }

  It 'returns retained Prepared before stale new-work conditions, without rewriting' {
    $f = New-SaveFixture; $null = Invoke-SaveFixture $f; $before = Get-SaveFiles $f.Root
    $again = Invoke-SaveFixture $f -Expected ([byte[]]@(1))
    $again.Stage | Should -BeExactly 'Retained'
    $again.OperationStatus | Should -BeExactly 'Prepared'
    Get-SaveFiles $f.Root | Should -BeExactly $before
  }

  It 'preserves the stored plan on same-ID changed content' {
    $f = New-SaveFixture; $null = Invoke-SaveFixture $f; $before = Get-SaveFiles $f.Root
    $f.Operation.nextRevision = 'head-other'
    {Invoke-SaveFixture $f} | Should -Throw '*OperationConflict*'
    Get-SaveFiles $f.Root | Should -BeExactly $before
  }

  It 'returns retained <RetainedStatus> without resetting lifecycle' -ForEach @(
    @{RetainedStatus = 'NeedsRecovery'}, @{RetainedStatus = 'Applied'}
  ) {
    $f = New-SaveFixture; $null = Invoke-SaveFixture $f
    $state = Get-Content $f.Path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $state.preparedOperations[0].status = $RetainedStatus
    if($RetainedStatus -eq 'NeedsRecovery'){
      $evidence = @{reason = 'Synthetic interruption'; observedOutputs = @()}
      $state.preparedOperations[0].recoveryEvidence = $evidence
      $state.requests[0].status = 'NeedsRecovery'; $state.requests[0].recoveryEvidence = $evidence
    }else{
      $state.preparedOperations[0].commitReceiptId = 'synthetic-complete'
      $state.requests[0] = $f.AfterState.requests[0]
      $state.committedRevision = 'head-N'
      $state.committedOutputManifest = $f.Operation.outputManifest
      $state.commitReceipts = @(@{receiptId = 'synthetic-complete'; resourceId = 'board-S17'; operationId = 'op-explicit'
        generation = 'epoch-A'; committedRevision = 'head-N'; requestIds = @('R-new'); outputManifest = $f.Operation.outputManifest
        reservations = $f.State.reservations; terminalEvidence = @($f.AfterState.requests[0].terminalEvidence)})
      foreach($slot in $slotNames){[IO.File]::WriteAllBytes($f.Operation.afterOutputs[$slot].path,
        [Convert]::FromBase64String($f.Operation.afterOutputs[$slot].bytesBase64))}
    }
    [IO.File]::WriteAllBytes($f.Path, (Test-SaveBytes $state)); $before = Get-SaveFiles $f.Root
    (Invoke-SaveFixture $f).OperationStatus | Should -BeExactly $RetainedStatus
    Get-SaveFiles $f.Root | Should -BeExactly $before
  }

  It 'retains old journal/receipts and opaque rejected numeric/request evidence' {
    $f = New-SaveFixture -History; $boards = Get-SaveBoards $f
    $null = Invoke-SaveFixture $f; $raw = [IO.File]::ReadAllText($f.Path)
    $raw | Should -Match '"opaque":1e2'
    $raw | Should -Match '999999999999999999999999999999999999'
    $state = $raw | ConvertFrom-Json -AsHashtable -Depth 100
    $state.preparedOperations.Count | Should -Be 2
    (Test-SaveJson $state.preparedOperations[0] $null) | Should -BeExactly (Test-SaveJson $f.State.preparedOperations[0] $null)
    (Test-SaveJson $state.commitReceipts $null) | Should -BeExactly (Test-SaveJson $f.State.commitReceipts $null)
    $state.requests[1].originalRequestJson | Should -BeExactly $f.State.requests[1].originalRequestJson
    [Convert]::ToHexString($enc.GetBytes($state.requests[1].request.orthography[0])) | Should -BeExactly 'C3A9'
    [Convert]::ToHexString($enc.GetBytes($state.requests[1].request.orthography[1])) | Should -BeExactly '65CC81'
    $element = Test-SaveElement ([IO.File]::ReadAllBytes($f.Path))
    $keys = @($element.GetProperty('requests')[1].GetProperty('request').GetProperty('extension').EnumerateObject() | ForEach-Object Name)
    [Convert]::ToHexString($enc.GetBytes($keys[0])) | Should -BeExactly 'EE8080'
    [Convert]::ToHexString($enc.GetBytes($keys[1])) | Should -BeExactly 'F0908080'
    Get-SaveBoards $f | Should -BeExactly $boards
  }

  It 'holds new work while an older plan is unresolved' {
    $f = New-SaveFixture -History
    $f.State.preparedOperations[0].status = 'Prepared'; $f.State.preparedOperations[0].Remove('commitReceiptId')
    $f.Raw = Test-SaveBytes $f.State; [IO.File]::WriteAllBytes($f.Path, $f.Raw)
    $before = Get-SaveFiles $f.Root
    {Invoke-SaveFixture $f} | Should -Throw '*ResourceHeld*'
    Get-SaveFiles $f.Root | Should -BeExactly $before
  }

  It 'reports no Saved success for <FaultPhase> failure, then reconciles actual state' -ForEach @(
    @{FaultPhase = 'Stage'}, @{FaultPhase = 'Replace'}, @{FaultPhase = 'ReadBack'}
  ) {
    $f = New-SaveFixture; $boards = Get-SaveBoards $f
    $script:saveFaultPhase = $FaultPhase
    Mock Invoke-CoordOperationFileIo {
      param($Phase, $StatePath, $StagePath, $Bytes)
      if(-not ([IO.Path]::GetFullPath($StatePath)).StartsWith($runRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)){
        throw 'Mock refused nonfixture path'
      }
      if($Phase -eq $script:saveFaultPhase){throw 'Injected finite IO failure'}
      & $script:realCoordIo -Phase $Phase -StatePath $StatePath -StagePath $StagePath -Bytes $Bytes
    }
    {Invoke-SaveFixture $f} | Should -Throw '*PersistenceFailed*'
    Get-SaveBoards $f | Should -BeExactly $boards
    if($FaultPhase -eq 'ReadBack'){
      $saved = Get-Content $f.Path -Raw | ConvertFrom-Json -Depth 100
      $saved.preparedOperations.Count | Should -Be 1
      (Invoke-SaveFixture $f).Stage | Should -BeExactly 'Retained'
    }else{
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($f.Path)) | Should -BeExactly ([Convert]::ToBase64String($f.Raw))
      if($FaultPhase -eq 'Replace'){@(Get-ChildItem $f.Root -Filter '*.prepared.tmp' -Force).Count | Should -Be 1}
    }
  }

  It 'refuses escaped duplicate keys in established state without rewriting it' {
    $f = New-SaveFixture
    $json = $enc.GetString($f.Raw).Replace('"lineageId":', '"\u006cineageId":"duplicate","lineageId":')
    [IO.File]::WriteAllText($f.Path, $json, $enc)
    $before = Get-SaveFiles $f.Root
    {Invoke-SaveFixture $f} | Should -Throw '*InvalidPreparedOperation*'
    Get-SaveFiles $f.Root | Should -BeExactly $before
  }

  It 'preserves a concurrently changed <Changed> preimage and refuses replacement' -ForEach @(
    @{Changed = 'state'}, @{Changed = 'board'}
  ) {
    $f = New-SaveFixture
    $script:changedFixture = $f; $script:changedKind = $Changed
    $script:thirdBytes = $enc.GetBytes('unrelated third-state bytes')
    Mock Invoke-CoordOperationFileIo {
      param($Phase, $StatePath, $StagePath, $Bytes)
      if(-not [string]::Equals($StatePath, $script:changedFixture.Path, [StringComparison]::Ordinal)){
        throw 'Mock refused nonfixture state'
      }
      if($Phase -ne 'Stage'){throw 'Unexpected replacement/readback'}
      $null = & $script:realCoordIo -Phase $Phase -StatePath $StatePath -StagePath $StagePath -Bytes $Bytes
      $changedPath = if($script:changedKind -eq 'state'){$StatePath}else{$script:changedFixture.Operation.beforeOutputs.markdown.path}
      [IO.File]::WriteAllBytes($changedPath, $script:thirdBytes)
    }
    {Invoke-SaveFixture $f} | Should -Throw '*SnapshotMismatch*'
    $changedPath = if($Changed -eq 'state'){$f.Path}else{$f.Operation.beforeOutputs.markdown.path}
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($changedPath)) | Should -BeExactly ([Convert]::ToBase64String($script:thirdBytes))
    if($Changed -eq 'board'){
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($f.Path)) | Should -BeExactly ([Convert]::ToBase64String($f.Raw))
    }
    Should -Invoke Invoke-CoordOperationFileIo -Exactly -Times 0 -ParameterFilter {$Phase -eq 'Replace'}
  }
}

#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
param([Parameter()][string]$FixtureRoot)

BeforeAll {
  $script:enc = [Text.UTF8Encoding]::new($false, $true)
  if ([string]::IsNullOrWhiteSpace($FixtureRoot)) {
    $artifactRoot = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'Process')
    if ([string]::IsNullOrWhiteSpace($artifactRoot)) { $artifactRoot = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'User') }
    $FixtureRoot = if ([string]::IsNullOrWhiteSpace($artifactRoot)) {
      'D:/ATAPArtifacts/Sprint0017/Task17.29.a/ResultQuery411/Fixtures'
    } else { Join-Path $artifactRoot 'ResultQuery411Fixtures' }
  }
  $allowed = [IO.Path]::GetFullPath('D:/ATAPArtifacts').TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  $script:runRoot = [IO.Path]::GetFullPath($FixtureRoot)
  if (-not $runRoot.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'D-only fixture root required.' }
  $null = [IO.Directory]::CreateDirectory($runRoot)
  $null = Get-Command Write-PSFMessage -ErrorAction Stop
  . (Join-Path $PSScriptRoot '../../public/Get-CoordResult.ps1')
  $script:fields = @('schemaVersion', 'resourceId', 'lineageId', 'registeredRoots', 'generation',
    'committedRevision', 'committedOutputManifest', 'custodyEvidence', 'compatibilityEvidence',
    'admissionEvidence', 'requests', 'claims', 'reservations', 'mutationAdmission')
  $script:slots = @('markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml')

  function Test-ResultSha([byte[]]$Bytes) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
  }
  # Independent fixture oracle, not the product serializer. Dictionary keys sort
  # by encoded-byte hex. No tests invoke Save/Complete or mutation helpers.
  function Test-ResultJson($Value, [string[]]$TopNames) {
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [Collections.IDictionary]) {
      [string[]]$keys = if ($null -ne $TopNames) { $TopNames } else { @($Value.Keys) }
      if ($null -eq $TopNames) {
        $order = [Collections.Generic.SortedDictionary[string, string]]::new([StringComparer]::Ordinal)
        foreach ($key in $keys) { $order.Add([Convert]::ToHexString($enc.GetBytes($key)), $key) }
        $keys = @($order.Values)
      }
      $pairs = foreach ($key in $keys) { (ConvertTo-Json -InputObject ([string]$key) -Compress) + ':' + (Test-ResultJson $Value[$key] $null) }
      return '{' + ($pairs -join ',') + '}'
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
      return '[' + (@($Value | ForEach-Object { Test-ResultJson $_ $null }) -join ',') + ']'
    }
    return (ConvertTo-Json -InputObject $Value -Depth 100 -Compress)
  }
  function Test-ResultBytes($Value, [switch]$Projection) {
    $names = if ($Projection) { $script:fields } else { $null }
    return ,$enc.GetBytes((Test-ResultJson $Value $names).Replace('"__RAW_NUMBER__"', '1e2') + [char]10)
  }
  function Copy-ResultValue($Value) { (Test-ResultJson $Value $null) | ConvertFrom-Json -AsHashtable -Depth 100 }
  function Test-ResultElement([byte[]]$Bytes) {
    $doc = [Text.Json.JsonDocument]::Parse($enc.GetString($Bytes))
    try { $doc.RootElement.Clone() } finally { $doc.Dispose() }
  }
  function New-ResultImage([byte[]]$Bytes, [string]$Path) {
    $result = [ordered]@{ bytesBase64 = [Convert]::ToBase64String($Bytes); digest = Test-ResultSha $Bytes }
    if ($Path) { $result.path = $Path }
    return $result
  }
  function Write-ResultFixture($Fixture) { [IO.File]::WriteAllBytes($Fixture.Path, (Test-ResultBytes $Fixture.State)) }
  function Get-ResultFiles([string]$Root) {
    $entries = @(Get-Item -LiteralPath $Root -Force) + @(Get-ChildItem -LiteralPath $Root -Force -Recurse)
    return @($entries | Sort-Object FullName | ForEach-Object {
      $kind = if ($_.PSIsContainer) { 'D' } else { 'F' }
      $body = if ($_.PSIsContainer) { '' } else { [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName)) }
      $kind + ':' + $_.FullName + ':' + $_.LastWriteTimeUtc.Ticks + ':' + $body
    }) -join '|'
  }
  function Invoke-ResultFixture($Fixture, [string]$Id = 'R-new', [string]$Resource = 'board-S17') {
    $before = Get-ResultFiles $Fixture.Root
    try { Get-CoordResult -StatePath $Fixture.Path -ResourceId $Resource -RequestId $Id }
    finally { (Get-ResultFiles $Fixture.Root) | Should -BeExactly $before }
  }
  function New-ResultFixture([string]$Status = 'Applied') {
    $root = Join-Path $runRoot ([guid]::NewGuid().ToString('N'))
    $null = [IO.Directory]::CreateDirectory($root)
    $manifest = [ordered]@{}; $nextManifest = [ordered]@{}; $beforeOutputs = [ordered]@{}; $afterOutputs = [ordered]@{}
    foreach ($slot in $slots) {
      $path = Join-Path $root ($slot + '.fixture')
      [byte[]]$oldBytes = @(239, 187, 191) + $enc.GetBytes("Before $slot" + [char]13 + [char]10)
      [byte[]]$nextBytes = $enc.GetBytes("After $slot" + [char]10)
      [IO.File]::WriteAllBytes($path, $oldBytes)
      $manifest[$slot] = [ordered]@{ path = $path; digest = Test-ResultSha $oldBytes }
      $nextManifest[$slot] = [ordered]@{ path = $path; digest = Test-ResultSha $nextBytes }
      $beforeOutputs[$slot] = New-ResultImage $oldBytes $path
      $afterOutputs[$slot] = New-ResultImage $nextBytes $path
    }
    $records = @(); $ordinal = 0
    $reference = [ordered]@{ reference = 'synthetic/prevalidated-boundary'; digest = ('0' * 64) }
    foreach ($id in @('R-new', 'r-new')) {
      $ordinal++
      $request = [ordered]@{
        protocolVersion = 'Coordination-v1'; resourceId = 'board-S17'; sprintId = '0017'; requestId = $id
        category = 'Claim'; taskId = '17.29.a'; scope = @([ordered]@{registeredRootId = 'fixture'; path = 'owned.ps1'})
        holder = [ordered]@{holderId = 'fixture-holder'; sessionId = 'fixture-session'}
        authorizationReference = 'synthetic-boundary'; generation = 'epoch-A'; expectedRevision = 'head-A'
        predecessors = @(); payload = [ordered]@{}
      }
      if ($Status -ceq 'Rejected') {
        # Deliberately not executable grammar: opaque number, invalid category and
        # string forms must remain as recorded; digest is retained, not invented.
        $request = [ordered]@{resourceId = 'board-S17'; requestId = $id; category = 'invalid-category'; opaque = '__RAW_NUMBER__'
          orthography = @([string][char]0xE9, ('e' + [char]0x301)); escaped = 'quote"slash\line' + [char]10}
      }
      $original = (Test-ResultJson $request $null).Replace('"__RAW_NUMBER__"', '1e2')
      $digest = if ($Status -ceq 'Rejected') { ([string]($ordinal + 1)) * 64 } else { Test-ResultSha $enc.GetBytes($original) }
      $record = [ordered]@{request = $request; digest = $digest; originalRequestJson = $original
        queueOrdinal = [string]$ordinal; status = 'Pending'; pendingEvidence = [ordered]@{reason = 'Synthetic eligible'}}
      if ($Status -ceq 'Rejected') {
        $record.Remove('pendingEvidence'); $record.status = 'Rejected'; $record.queueOrdinal = ('9' * 38) + [string]$ordinal
        $record.terminalEvidence = [ordered]@{resourceId = 'board-S17'; requestId = $id; digest = $digest
          status = 'Rejected'; reason = ('Historical malformed ' + $id); receipt = $reference}
      }
      $records += $record
    }
    # These fixtures assume caller-owned permission, lineage and custody. They
    # assert local retained integrity only, never live authority or wire conformance.
    $state = [ordered]@{
      schemaVersion = 'Coordination-state-v1'; resourceId = 'board-S17'; lineageId = 'lineage-A'
      registeredRoots = @([ordered]@{registeredRootId = 'fixture'; path = $root}); generation = 'epoch-A'
      committedRevision = 'head-A'; committedOutputManifest = $manifest; custodyEvidence = $reference
      compatibilityEvidence = $reference; admissionEvidence = @($reference); requests = $records; claims = @(); reservations = @()
      preparedOperations = @(); commitReceipts = @()
      mutationAdmission = [ordered]@{status = 'Admitted'; reason = 'Synthetic caller boundary'; observedOutputs = @()}
    }
    if ($Status -cin @('Prepared', 'NeedsRecovery', 'Applied')) {
      $before = Copy-ResultValue $state
      $after = Copy-ResultValue $state
      $after.committedRevision = 'head-N'; $after.committedOutputManifest = $nextManifest
      foreach ($record in $after.requests) {
        $record.Remove('pendingEvidence'); $record.status = 'Applied'; $record.preparedOperationId = 'op-original'
        $record.terminalEvidence = [ordered]@{resourceId = 'board-S17'; requestId = $record.request.requestId
          digest = $record.digest; status = 'Applied'; reason = ('Original outcome ' + $record.request.requestId); receipt = $reference}
      }
      $operation = [ordered]@{
        operationId = 'op-original'; resourceId = 'board-S17'; status = $Status
        baseHead = [ordered]@{generation = 'epoch-A'; committedRevision = 'head-A'; outputManifest = $manifest}
        nextRevision = 'head-N'; requestIds = @('R-new', 'r-new')
        beforeStateImage = New-ResultImage (Test-ResultBytes $before -Projection)
        afterStateImage = New-ResultImage (Test-ResultBytes $after -Projection)
        beforeOutputs = $beforeOutputs; afterOutputs = $afterOutputs; outputManifest = $nextManifest; reservations = @()
      }
      if ($Status -ceq 'Applied') {
        $state.requests = $after.requests; $state.committedRevision = 'head-N'; $state.committedOutputManifest = $nextManifest
        $operation.commitReceiptId = 'receipt-original'
        $state.commitReceipts = @([ordered]@{receiptId = 'receipt-original'; resourceId = 'board-S17'; operationId = 'op-original'
          generation = 'epoch-A'; committedRevision = 'head-N'; requestIds = @('R-new', 'r-new'); outputManifest = $nextManifest
          reservations = @(); terminalEvidence = @($after.requests[1].terminalEvidence, $after.requests[0].terminalEvidence)})
      } else {
        foreach ($record in $state.requests) {
          $record.Remove('pendingEvidence'); $record.status = $Status; $record.preparedOperationId = 'op-original'
          if ($Status -ceq 'NeedsRecovery') { $record.recoveryEvidence = [ordered]@{reason = 'Retained interruption'; observedOutputs = @()} }
        }
        if ($Status -ceq 'NeedsRecovery') { $operation.recoveryEvidence = [ordered]@{reason = 'Retained interruption'; observedOutputs = @()} }
      }
      $state.preparedOperations = @($operation)
    }
    $fixture = @{Root = $root; Path = (Join-Path $root 'state.json'); State = $state}
    Write-ResultFixture $fixture
    return $fixture
  }
}

Describe 'Get-CoordResult local retained projection' {
  BeforeEach { Mock Write-PSFMessage {} }

  It 'preserves exact <Status> data and linked clones without writes' -ForEach @(
    @{Status = 'Pending'}, @{Status = 'Prepared'}, @{Status = 'Applied'}, @{Status = 'Rejected'}, @{Status = 'NeedsRecovery'}
  ) {
    $f = New-ResultFixture $Status
    $expected = Test-ResultElement ([IO.File]::ReadAllBytes($f.Path))
    $result = @(Invoke-ResultFixture $f)
    $result.Count | Should -Be 1
    $result[0].Outcome | Should -BeExactly 'Found'
    $result[0].RetainedStatus | Should -BeExactly $Status
    $result[0].ResourceId | Should -BeExactly 'board-S17'
    $result[0].RequestId | Should -BeExactly 'R-new'
    $result[0].StateSha256 | Should -BeExactly (Test-ResultSha ([IO.File]::ReadAllBytes($f.Path)))
    $result[0].Record.GetRawText() | Should -BeExactly $expected.GetProperty('requests')[0].GetRawText()
    @($result[0].PSObject.Properties.Name).Count | Should -Be 9
    if ($Status -cin @('Pending', 'Rejected')) {
      $result[0].Operation | Should -BeNullOrEmpty
      $result[0].CommitReceipt | Should -BeNullOrEmpty
    } else {
      $result[0].Operation.GetRawText() | Should -BeExactly $expected.GetProperty('preparedOperations')[0].GetRawText()
      if ($Status -ceq 'Applied') { $result[0].CommitReceipt.GetRawText() | Should -BeExactly $expected.GetProperty('commitReceipts')[0].GetRawText() }
      else { $result[0].CommitReceipt | Should -BeNullOrEmpty }
    }
  }

  It 'returns NotFound only for an absent exact key in valid matching state' {
    $f = New-ResultFixture 'Pending'
    foreach ($id in @('R-absent', 'R-NEW')) {
      $r = Invoke-ResultFixture $f $id
      $r.Outcome | Should -BeExactly 'NotFound'
      $r.RequestId | Should -BeExactly $id
      $r.RetainedStatus | Should -BeNullOrEmpty
      $r.Record | Should -BeNullOrEmpty
      $r.Operation | Should -BeNullOrEmpty
      $r.CommitReceipt | Should -BeNullOrEmpty
      $r.RecordedHead.committedRevision | Should -BeExactly 'head-A'
    }
  }

  It 'keeps case-only batch members and reversed receipt terminals separate' {
    $f = New-ResultFixture
    $upper = Invoke-ResultFixture $f 'R-new'
    $lower = Invoke-ResultFixture $f 'r-new'
    $upper.Record.GetProperty('request').GetProperty('requestId').GetString() | Should -BeExactly 'R-new'
    $lower.Record.GetProperty('request').GetProperty('requestId').GetString() | Should -BeExactly 'r-new'
    $upper.Record.GetProperty('digest').GetString() | Should -Not -BeExactly $lower.Record.GetProperty('digest').GetString()
    $upper.Record.GetProperty('terminalEvidence').GetRawText() | Should -Not -BeExactly $lower.Record.GetProperty('terminalEvidence').GetRawText()
    $upper.CommitReceipt.GetProperty('terminalEvidence')[0].GetProperty('requestId').GetString() | Should -BeExactly 'r-new'
    $upper.CommitReceipt.GetRawText() | Should -BeExactly $lower.CommitReceipt.GetRawText()
    $upper.Record = $null
    (Invoke-ResultFixture $f).Record.GetProperty('request').GetProperty('requestId').GetString() | Should -BeExactly 'R-new'
  }

  It 'preserves historical <Status> under later generation/revision and <Admission> admission' -ForEach @(
    @{Status = 'Applied'; Admission = 'Held'}, @{Status = 'Applied'; Admission = 'NeedsRecovery'},
    @{Status = 'Rejected'; Admission = 'Held'}, @{Status = 'Rejected'; Admission = 'NeedsRecovery'}
  ) {
    $f = New-ResultFixture $Status
    $before = Test-ResultElement ([IO.File]::ReadAllBytes($f.Path))
    $f.State.generation = 'epoch-later'; $f.State.committedRevision = 'head-later'
    $f.State.mutationAdmission.status = $Admission
    Write-ResultFixture $f
    $r = Invoke-ResultFixture $f
    $r.RetainedStatus | Should -BeExactly $Status
    $r.Record.GetRawText() | Should -BeExactly $before.GetProperty('requests')[0].GetRawText()
    $r.RecordedHead.generation | Should -BeExactly 'epoch-later'
    $r.RecordedHead.committedRevision | Should -BeExactly 'head-later'
    if ($Status -ceq 'Applied') {
      $r.CommitReceipt.GetRawText() | Should -BeExactly $before.GetProperty('commitReceipts')[0].GetRawText()
      $r.CommitReceipt.GetProperty('generation').GetString() | Should -BeExactly 'epoch-A'
      $r.CommitReceipt.GetProperty('committedRevision').GetString() | Should -BeExactly 'head-N'
    }
  }

  It 'preserves rejected raw numbers Unicode forms original escaping and large string ordinal after document disposal' {
    $f = New-ResultFixture 'Rejected'
    $expected = Test-ResultElement ([IO.File]::ReadAllBytes($f.Path))
    $r = Invoke-ResultFixture $f
    $request = $r.Record.GetProperty('request')
    $request.GetProperty('opaque').GetRawText() | Should -BeExactly '1e2'
    $request.GetProperty('orthography')[0].GetString() | Should -BeExactly ([string][char]0xE9)
    $request.GetProperty('orthography')[1].GetString() | Should -BeExactly ('e' + [char]0x301)
    $r.Record.GetProperty('queueOrdinal').GetString() | Should -BeExactly (('9' * 38) + '1')
    $r.Record.GetProperty('originalRequestJson').GetRawText() | Should -BeExactly $expected.GetProperty('requests')[0].GetProperty('originalRequestJson').GetRawText()
    $request.GetProperty('category').GetString() | Should -BeExactly 'invalid-category'
  }

  It 'does not read quartet outputs or external receipt references' {
    $f = New-ResultFixture
    foreach ($slot in $slots) { [IO.File]::Delete($f.State.committedOutputManifest[$slot].path) }
    (Invoke-ResultFixture $f).RetainedStatus | Should -BeExactly 'Applied'
  }

  It 'refuses missing state without initialization' {
    $f = New-ResultFixture 'Pending'
    [IO.File]::Delete($f.Path)
    { Invoke-ResultFixture $f } | Should -Throw '*Get-CoordResult: UnavailableState*'
  }

  It 'refuses unreadable state without changing fixtures' {
    $f = New-ResultFixture 'Pending'
    $before = Get-ResultFiles $f.Root
    $lock = [IO.File]::Open($f.Path, 'Open', 'ReadWrite', 'None')
    try { { Get-CoordResult -StatePath $f.Path -ResourceId 'board-S17' -RequestId 'R-new' } | Should -Throw '*Get-CoordResult: UnavailableState*' }
    finally { $lock.Dispose() }
    (Get-ResultFiles $f.Root) | Should -BeExactly $before
  }

  It 'refuses <Fault> input without a successful observation' -ForEach @(
    @{Fault = 'Malformed'}, @{Fault = 'DuplicateKey'}, @{Fault = 'InvalidUtf8'}, @{Fault = 'InvalidScalar'},
    @{Fault = 'UnsupportedSchema'}, @{Fault = 'ResourceMismatch'}, @{Fault = 'RelativePath'}, @{Fault = 'Directory'}
  ) {
    $f = New-ResultFixture 'Pending'
    switch ($Fault) {
      'Malformed' { [IO.File]::WriteAllText($f.Path, '{', $enc) }
      'DuplicateKey' { $text = [IO.File]::ReadAllText($f.Path); [IO.File]::WriteAllText($f.Path, $text.Replace('"lineageId":', '"lineageId":"ambiguous","lineageId":'), $enc) }
      'InvalidUtf8' { [IO.File]::WriteAllBytes($f.Path, [byte[]]@(0xC3, 0x28)) }
      'InvalidScalar' { $text = [IO.File]::ReadAllText($f.Path); [IO.File]::WriteAllText($f.Path, $text.Replace('lineage-A', '\uD800'), $enc) }
      'UnsupportedSchema' { $f.State.schemaVersion = 'Coordination-state-v999'; Write-ResultFixture $f }
      'ResourceMismatch' { $f.State.resourceId = 'board-s17'; Write-ResultFixture $f }
      'RelativePath' { $f.Path = 'state.json' }
      'Directory' { $f.Path = $f.Root }
    }
    { Invoke-ResultFixture $f } | Should -Throw '*Get-CoordResult:*'
  }

  It 'refuses retained corruption <Fault> with no writes' -ForEach @(
    @{Fault = 'DuplicateRequest'}, @{Fault = 'DuplicateOperation'}, @{Fault = 'DuplicateReceipt'}, @{Fault = 'DuplicateReceiptOperation'},
    @{Fault = 'ForeignRequest'}, @{Fault = 'ForeignOperation'}, @{Fault = 'ForeignReceipt'}, @{Fault = 'RequestDigest'},
    @{Fault = 'OriginalJson'}, @{Fault = 'OriginalDuplicateKey'}, @{Fault = 'OperationId'}, @{Fault = 'OperationStatus'},
    @{Fault = 'MemberMissing'}, @{Fault = 'OuterMemberMissing'}, @{Fault = 'ReceiptMissing'}, @{Fault = 'ReceiptOperation'},
    @{Fault = 'ReceiptGeneration'}, @{Fault = 'ReceiptRevision'}, @{Fault = 'ReceiptMembers'}, @{Fault = 'ReceiptManifest'},
    @{Fault = 'ReceiptReservations'}, @{Fault = 'TerminalMissing'}, @{Fault = 'TerminalDuplicate'}, @{Fault = 'TerminalDigest'},
    @{Fault = 'TerminalResource'}, @{Fault = 'TerminalStatus'}, @{Fault = 'TerminalCase'}, @{Fault = 'OuterTerminalReason'},
    @{Fault = 'ImageDigest'}, @{Fault = 'ImageMemberDigest'}
  ) {
    $f = New-ResultFixture
    switch ($Fault) {
      'DuplicateRequest' { $f.State.requests += Copy-ResultValue $f.State.requests[0] }
      'DuplicateOperation' { $f.State.preparedOperations += Copy-ResultValue $f.State.preparedOperations[0] }
      'DuplicateReceipt' { $f.State.commitReceipts += Copy-ResultValue $f.State.commitReceipts[0] }
      'DuplicateReceiptOperation' { $copy = Copy-ResultValue $f.State.commitReceipts[0]; $copy.receiptId = 'other-receipt'; $f.State.commitReceipts += $copy }
      'ForeignRequest' { $f.State.requests[0].request.resourceId = 'foreign' }
      'ForeignOperation' { $f.State.preparedOperations[0].resourceId = 'foreign' }
      'ForeignReceipt' { $f.State.commitReceipts[0].resourceId = 'foreign' }
      'RequestDigest' { $f.State.requests[0].digest = ('f' * 64) }
      'OriginalJson' { $f.State.requests[0].originalRequestJson = '{}' }
      'OriginalDuplicateKey' { $f.State.requests[0].originalRequestJson = '{"resourceId":"board-S17","resourceId":"board-S17"}' }
      'OperationId' { $f.State.requests[0].preparedOperationId = 'OP-original' }
      'OperationStatus' { $f.State.preparedOperations[0].status = 'Prepared'; $f.State.preparedOperations[0].Remove('commitReceiptId') }
      'MemberMissing' { $f.State.preparedOperations[0].requestIds = @('r-new') }
      'OuterMemberMissing' { $f.State.requests = @($f.State.requests[1]) }
      'ReceiptMissing' { $f.State.commitReceipts = @() }
      'ReceiptOperation' { $f.State.commitReceipts[0].operationId = 'OP-original' }
      'ReceiptGeneration' { $f.State.commitReceipts[0].generation = 'epoch-later' }
      'ReceiptRevision' { $f.State.commitReceipts[0].committedRevision = 'head-later' }
      'ReceiptMembers' { $f.State.commitReceipts[0].requestIds = @('r-new', 'R-new') }
      'ReceiptManifest' { $f.State.commitReceipts[0].outputManifest.markdown.digest = ('f' * 64) }
      'ReceiptReservations' { $f.State.commitReceipts[0].reservations = @([ordered]@{reservationId = 'extra'; resourceId = 'board-S17'; requestId = 'R-new'; taskId = '17.29.a'; scope = @([ordered]@{registeredRootId = 'fixture'; path = 'owned.ps1'}); generation = 'epoch-A'}) }
      'TerminalMissing' { $f.State.commitReceipts[0].terminalEvidence = @($f.State.commitReceipts[0].terminalEvidence[0]) }
      'TerminalDuplicate' { $f.State.commitReceipts[0].terminalEvidence = @($f.State.commitReceipts[0].terminalEvidence[0], $f.State.commitReceipts[0].terminalEvidence[0]) }
      'TerminalDigest' { $f.State.commitReceipts[0].terminalEvidence[1].digest = ('f' * 64) }
      'TerminalResource' { $f.State.commitReceipts[0].terminalEvidence[1].resourceId = 'foreign' }
      'TerminalStatus' { $f.State.commitReceipts[0].terminalEvidence[1].status = 'Rejected' }
      'TerminalCase' { $f.State.commitReceipts[0].terminalEvidence[1].requestId = 'R-NEW' }
      'OuterTerminalReason' { $f.State.requests[0].terminalEvidence.reason = 'Changed history' }
      'ImageDigest' { $f.State.preparedOperations[0].afterStateImage.digest = ('f' * 64) }
      'ImageMemberDigest' {
        $image = $f.State.preparedOperations[0].afterStateImage
        $value = (Test-ResultElement ([Convert]::FromBase64String($image.bytesBase64))).GetRawText() | ConvertFrom-Json -AsHashtable -Depth 100
        $value.requests[0].digest = ('f' * 64)
        $f.State.preparedOperations[0].afterStateImage = New-ResultImage (Test-ResultBytes $value -Projection)
      }
    }
    Write-ResultFixture $f
    $expectedFailure = if ($Fault -ceq 'TerminalStatus') { '*Get-CoordResult: InvalidState*' } else { '*Get-CoordResult: InconsistentRetainedState*' }
    { Invoke-ResultFixture $f } | Should -Throw $expectedFailure
  }

  It 'refuses historical rejected <Fault> without imposing executable grammar' -ForEach @(
    @{Fault = 'Digest'}, @{Fault = 'RequestId'}, @{Fault = 'Resource'}, @{Fault = 'Original'}, @{Fault = 'Status'}
  ) {
    $f = New-ResultFixture 'Rejected'
    switch ($Fault) {
      'Digest' { $f.State.requests[0].terminalEvidence.digest = ('f' * 64) }
      'RequestId' { $f.State.requests[0].terminalEvidence.requestId = 'R-NEW' }
      'Resource' { $f.State.requests[0].terminalEvidence.resourceId = 'foreign' }
      'Original' { $f.State.requests[0].originalRequestJson = '{"resourceId":"board-S17","requestId":"R-NEW"}' }
      'Status' { $f.State.requests[0].terminalEvidence.status = 'Applied' }
    }
    Write-ResultFixture $f
    { Invoke-ResultFixture $f } | Should -Throw '*Get-CoordResult:*'
  }

  It 'refuses a missing requested record claimed by journal instead of NotFound' {
    $f = New-ResultFixture 'Prepared'
    $f.State.requests = @($f.State.requests[1]); Write-ResultFixture $f
    { Invoke-ResultFixture $f } | Should -Throw '*Get-CoordResult: InconsistentRetainedState*'
  }

  It 'refuses mismatched retained recovery evidence' {
    $f = New-ResultFixture 'NeedsRecovery'
    $f.State.requests[0].recoveryEvidence.reason = 'Changed evidence'; Write-ResultFixture $f
    { Invoke-ResultFixture $f } | Should -Throw '*Get-CoordResult: InconsistentRetainedState*'
  }
}

Describe 'Get-CoordResult selected receipt membership closure (F1)' {
  BeforeEach { Mock Write-PSFMessage {} }

  BeforeAll {
    function Add-ResultForeignReceipt($Fixture, [string]$Id = 'R-new', [switch]$TerminalOnly) {
      $record = @($Fixture.State.requests | Where-Object { [string]::Equals($_.request.requestId, $Id, [StringComparison]::Ordinal) })[0]
      $memberId = if ($TerminalOnly) { if ($Id -ceq 'R-new') { 'r-new' } else { 'R-new' } } else { $Id }
      # Distinct only by case from the valid Applied receipt/operation when those
      # exist: both must survive Ordinal indexing and then contradict membership.
      $Fixture.State.commitReceipts += [ordered]@{
        receiptId = 'RECEIPT-original'; resourceId = 'board-S17'; operationId = 'OP-original'
        generation = 'epoch-A'; committedRevision = 'head-A'; requestIds = @($memberId)
        outputManifest = Copy-ResultValue $Fixture.State.committedOutputManifest; reservations = @()
        terminalEvidence = @([ordered]@{
          resourceId = 'board-S17'; requestId = $Id; digest = $record.digest; status = 'Applied'
          reason = 'Foreign retained Applied claim'
          receipt = [ordered]@{reference = 'synthetic/prevalidated-boundary'; digest = ('0' * 64)}
        })
      }
      Write-ResultFixture $Fixture
    }
    function Assert-ResultFixtureSchema($Fixture) {
      $schemaText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../schemas/state-v1.schema.json') -Raw
      # A negative must pass the existing schema so the regression proves a
      # cross-record contradiction refusal rather than a shape-only refusal.
      Test-Json -Json ([IO.File]::ReadAllText($Fixture.Path)) -Schema $schemaText -ErrorAction Stop | Should -BeTrue
    }
  }

  It 'refuses a foreign Applied receipt naming selected <Status> request <Id>' -ForEach @(
    @{Status = 'Pending'; Id = 'R-new'}, @{Status = 'Rejected'; Id = 'R-new'},
    @{Status = 'Prepared'; Id = 'R-new'}, @{Status = 'NeedsRecovery'; Id = 'r-new'},
    @{Status = 'Applied'; Id = 'R-new'}
  ) {
    $f = New-ResultFixture $Status
    Add-ResultForeignReceipt $f $Id
    Assert-ResultFixtureSchema $f
    { Invoke-ResultFixture $f $Id } | Should -Throw '*Get-CoordResult: InconsistentRetainedState*'
  }

  It 'refuses a foreign receipt naming selected <Status> only in terminal evidence' -ForEach @(
    @{Status = 'Pending'}, @{Status = 'Applied'}
  ) {
    $f = New-ResultFixture $Status
    Add-ResultForeignReceipt $f 'R-new' -TerminalOnly
    Assert-ResultFixtureSchema $f
    { Invoke-ResultFixture $f } | Should -Throw '*Get-CoordResult: InconsistentRetainedState*'
  }
}

Describe 'Get-CoordResult absent selected record evidence (F1b)' {
  BeforeEach { Mock Write-PSFMessage {} }

  It 'refuses retained exact terminal evidence for an absent record while preserving a case-only no-evidence NotFound' {
    $f = New-ResultFixture 'Pending'
    # Capture the legitimate digest before removal; requestIds still names the
    # retained case-only peer, so the existing state schema remains satisfied.
    $digest = $f.State.requests[0].digest
    $f.State.commitReceipts = @([ordered]@{
      receiptId = 'receipt-orphan'; resourceId = 'board-S17'; operationId = 'op-orphan'
      generation = 'epoch-A'; committedRevision = 'head-A'; requestIds = @('r-new')
      outputManifest = Copy-ResultValue $f.State.committedOutputManifest; reservations = @()
      terminalEvidence = @([ordered]@{
        resourceId = 'board-S17'; requestId = 'R-new'; digest = $digest; status = 'Applied'
        reason = 'Retained terminal-only claim for removed request'
        receipt = [ordered]@{reference = 'synthetic/prevalidated-boundary'; digest = ('0' * 64)}
      })
    })
    $f.State.requests = @($f.State.requests[1])
    Write-ResultFixture $f
    $schemaText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../schemas/state-v1.schema.json') -Raw
    Test-Json -Json ([IO.File]::ReadAllText($f.Path)) -Schema $schemaText -ErrorAction Stop | Should -BeTrue
    (Invoke-ResultFixture $f 'R-NEW').Outcome | Should -BeExactly 'NotFound'
    { Invoke-ResultFixture $f 'R-new' } | Should -Throw '*Get-CoordResult: InconsistentRetainedState*'
  }
}

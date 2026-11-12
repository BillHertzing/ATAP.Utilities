#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
param(
  [Parameter()][ValidateNotNullOrEmpty()][string]$FixtureRoot = $(
    if ([Environment]::MachineName -ieq 'UTAT022') {
      'D:/ATAPArtifacts/_generated/Sprint0017/Task17.30.b/CandidateRecovery679/Fixtures-' + [guid]::NewGuid().ToString('N')
    } else {
      throw 'FixtureRoot must be supplied explicitly on this host; no default mapping is approved.'
    }
  )
)

# Synthetic custody only: no live admission, Invoke-CoordClerk/drain or power-loss proof.
# One independent Run.Path container; no mocks, old test-container imports or cleanup.
# Codec, fourteen-field projection and state/plan literals reuse baseline531:
# tests/Integration/SaveCompleteSharingViolation.Tests.ps1 (raw pin in InputPins.json).
# Fixture/plan definitions reuse success661; real-handle and immutable-plan helpers reuse531.
# Only source text is reused at authoring; neither old Pester container is loaded.
# The preview is caller-constructed; preview provenance is assumed.
BeforeAll {
  if (-not $IsWindows) { throw 'This integration container requires Windows publication semantics.' }
  $allowed = [IO.Path]::GetFullPath('D:/ATAPArtifacts/_generated/Sprint0017/Task17.30.b/CandidateRecovery679').TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not [IO.Path]::IsPathFullyQualified($FixtureRoot)) { throw 'Fully qualified FixtureRoot required.' }
  $script:runRoot = [IO.Path]::GetFullPath($FixtureRoot).TrimEnd('\', '/')
  if (-not $runRoot.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'FixtureRoot must descend from the registered D-only packet.' }
  if (Test-Path -LiteralPath $runRoot) { throw 'FixtureRoot must be fresh; existing paths are never reused or cleaned.' }
  $ancestor = [IO.DirectoryInfo]::new($runRoot).Parent
  while ($null -ne $ancestor) {
    if (Test-Path -LiteralPath $ancestor.FullName) {
      $item = Get-Item -LiteralPath $ancestor.FullName -Force -ErrorAction Stop
      if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Reparse ancestors are prohibited.' }
    }
    $ancestor = $ancestor.Parent
  }
  $null = [IO.Directory]::CreateDirectory($runRoot)
  $null = Get-Command Write-PSFMessage -ErrorAction Stop
  . (Join-Path $PSScriptRoot '../../private/Save-CoordOperation.ps1')
  . (Join-Path $PSScriptRoot '../../private/Complete-CoordOperation.ps1')
  . (Join-Path $PSScriptRoot '../../private/New-CoordQuartetCandidate.ps1')
  $script:enc = [Text.UTF8Encoding]::new($false, $true)
  $script:projection = @('schemaVersion', 'resourceId', 'lineageId', 'registeredRoots', 'generation',
    'committedRevision', 'committedOutputManifest', 'custodyEvidence', 'compatibilityEvidence',
    'admissionEvidence', 'requests', 'claims', 'reservations', 'mutationAdmission')
  $script:slotNames = @('markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml')
  function Test-Recovery679Sha([byte[]]$Bytes) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
  }
  function Test-Recovery679Json($Value, [string[]]$TopNames) {
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [System.Collections.IDictionary]) {
      [string[]]$keys = if ($null -ne $TopNames) { $TopNames } else { @($Value.Keys) }
      if ($null -eq $TopNames) {
        $order = [Collections.Generic.SortedDictionary[string, string]]::new([StringComparer]::Ordinal)
        foreach ($key in $keys) { $order.Add([Convert]::ToHexString($enc.GetBytes($key)), $key) }
        $keys = @($order.Values)
      }
      $pairs = foreach ($key in $keys) {
        (ConvertTo-Json -InputObject ([string]$key) -Compress) + ':' + (Test-Recovery679Json $Value[$key] $null)
      }
      return '{' + ($pairs -join ',') + '}'
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
      return '[' + (@($Value | ForEach-Object { Test-Recovery679Json $_ $null }) -join ',') + ']'
    }
    return (ConvertTo-Json -InputObject $Value -Depth 100 -Compress)
  }
  function Test-Recovery679Bytes($Value, [switch]$Projection) {
    $names = if ($Projection) { $script:projection } else { $null }
    $json = (Test-Recovery679Json $Value $names)
    return , ($enc.GetBytes($json + [char]10))
  }
  function Test-Recovery679Element([byte[]]$Bytes) {
    $doc = [System.Text.Json.JsonDocument]::Parse($enc.GetString($Bytes))
    try { $doc.RootElement.Clone() } finally { $doc.Dispose() }
  }
  function Test-Recovery679Clone($Value) { (Test-Recovery679Json $Value $null) | ConvertFrom-Json -AsHashtable -Depth 100 }
  function Test-Recovery679Image([byte[]]$Bytes, [string]$Path) {
    $value = [ordered]@{ bytesBase64 = [Convert]::ToBase64String($Bytes); digest = Test-Recovery679Sha $Bytes }
    if ($Path) { $value.path = $Path }
    return $value
  }
  function Get-Recovery679Raw([string]$Path) { [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path)) }
  function Read-Recovery679State($Fixture) {
    [IO.File]::ReadAllText($Fixture.Path, $enc) | ConvertFrom-Json -AsHashtable -Depth 100
  }
  function New-Recovery679Fixture {
    $root = Join-Path $runRoot 'Inputs'
    $null = [IO.Directory]::CreateDirectory($root)
    $text = @('# Current Sprint: fixture', '', '## Goal', 'Synthetic quartet publication.', '',
      '## Stream C - fixture', '- [ ] **Task 17.30** [ATAP.Utilities] - Fixture', '  - Status: Planned.', '') -join [char]10
    [byte[]]$beforeMarkdown = $enc.GetBytes($text)
    [byte[]]$afterMarkdown = $enc.GetBytes($text.Replace('- [ ] **Task 17.30**', '- [x] **Task 17.30**').Replace('Planned.', 'Completed with accepted evidence.'))
    $files = [ordered]@{
      markdown = @{name = 'Tasks.Sprint0017.md'; bytes = $beforeMarkdown}
      boardHtml = @{name = 'Tasks.Sprint0017.html'; bytes = [byte[]]@()}
      proceduralDetailsHtml = @{name = 'Tasks.Sprint0017.ProceduralDetails.html'; bytes = $enc.GetBytes("<html><body>Prior procedure</body></html>`n")}
      accomplishedHtml = @{name = 'Tasks.Sprint0017.Accomplished.html'; bytes = $enc.GetBytes("<html><body>Prior outcome</body></html>`n")}
    }
    $manifest = [ordered]@{}; $beforeOutputs = [ordered]@{}
    foreach ($slot in $slotNames) {
      $path = Join-Path $root $files[$slot].name
      [byte[]]$bytes = $files[$slot].bytes
      [IO.File]::WriteAllBytes($path, $bytes)
      $beforeOutputs[$slot] = Test-Recovery679Image $bytes $path
      $manifest[$slot] = [ordered]@{path = $path; digest = Test-Recovery679Sha $bytes}
    }
    # Baseline531 shape-valid state: these references assert synthetic caller authority only.
    $request = [ordered]@{
      protocolVersion = 'Coordination-v1'; resourceId = 'board-S17'; sprintId = '0017'; requestId = 'R-new'
      category = 'Claim'; taskId = '17.30'; scope = @([ordered]@{registeredRootId = 'fixture'; path = 'owned.ps1'})
      holder = [ordered]@{holderId = 'fixture-holder'; sessionId = 'fixture-session'}
      authorizationReference = 'synthetic-boundary'; generation = 'epoch-A'; expectedRevision = 'head-A'
      predecessors = @(); payload = [ordered]@{}
    }
    $requestJson = Test-Recovery679Json $request $null
    $record = [ordered]@{request = $request; digest = Test-Recovery679Sha $enc.GetBytes($requestJson); originalRequestJson = $requestJson
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
    $preview = [pscustomobject]@{
      Stage = 'ProposedNotPrepared'; RequestId = 'R-new'; TaskId = '17.30'; Generation = 'epoch-A'; BaseRevision = 'head-A'
      BeforeSha256 = Test-Recovery679Sha $beforeMarkdown; AfterSha256 = Test-Recovery679Sha $afterMarkdown
      BeforeBytes = $beforeMarkdown.Clone(); AfterBytes = $afterMarkdown.Clone(); AfterText = $enc.GetString($afterMarkdown)
      Reservations = (Test-Recovery679Element (Test-Recovery679Bytes $state.reservations))
    }
    $closeout = @{
      kind = 'Coordination-CompletionRecord-v1'; resourceId = 'board-S17'; sprintId = '0017'
      taskId = '17.30'; generation = 'epoch-A'; claimId = 'synthetic-claim'
      beforeMarkdownSha256 = $preview.BeforeSha256; annotation = 'Completed with accepted evidence.'
      acceptance = @{ reference = 'synthetic-accepted-proof'; digest = @{ algorithm = 'SHA256'; value = '1' * 64 } }
      readback = @{ reference = 'synthetic-readback'; digest = @{ algorithm = 'SHA256'; value = '2' * 64 } }
      companions = @{
        proceduralDetailsHtml = @{ beforeSha256 = $manifest.proceduralDetailsHtml.digest; text = 'Resume the retained four images without another renderer.' }
        accomplishedHtml = @{ beforeSha256 = $manifest.accomplishedHtml.digest; text = 'Accepted synthetic consuming result.' }
      }
    }
    $recordBytes = Test-Recovery679Bytes $closeout
    $preview | Add-Member -NotePropertyName Completion -NotePropertyValue ([pscustomobject]@{
      Record = Test-Recovery679Element $recordBytes; RecordSha256 = Test-Recovery679Sha $recordBytes
    })
    $path = Join-Path $root 'state.json'
    [byte[]]$raw = Test-Recovery679Bytes $state
    [IO.File]::WriteAllBytes($path, $raw)
    return @{Root = $root; Path = $path; Raw = $raw; State = $state; BeforeOutputs = $beforeOutputs; Preview = $preview}
  }
  function New-Recovery679Plan($Fixture, $Candidate) {
    $afterOutputs = $Candidate.AfterOutputs.GetRawText() | ConvertFrom-Json -AsHashtable -Depth 100
    $afterManifest = [ordered]@{}
    foreach ($slot in $slotNames) {
      $afterManifest[$slot] = [ordered]@{path = $afterOutputs[$slot].path; digest = $afterOutputs[$slot].digest}
    }
    $after = Test-Recovery679Clone $Fixture.State
    $after.committedRevision = 'head-N'; $after.committedOutputManifest = $afterManifest
    $after.requests[0].Remove('pendingEvidence'); $after.requests[0].status = 'Applied'
    $after.requests[0].preparedOperationId = 'op-explicit'
    $after.requests[0].terminalEvidence = [ordered]@{resourceId = 'board-S17'; requestId = 'R-new'; digest = $Fixture.State.requests[0].digest
      status = 'Applied'; reason = 'Planned caller-validated outcome'; receipt = $Fixture.State.custodyEvidence}
    return [ordered]@{
      operationId = 'op-explicit'; resourceId = 'board-S17'; status = 'Prepared'
      baseHead = [ordered]@{generation = 'epoch-A'; committedRevision = 'head-A'; outputManifest = $Fixture.State.committedOutputManifest}
      nextRevision = 'head-N'; requestIds = @('R-new')
      beforeStateImage = Test-Recovery679Image (Test-Recovery679Bytes $Fixture.State -Projection)
      afterStateImage = Test-Recovery679Image (Test-Recovery679Bytes $after -Projection)
      beforeOutputs = $Fixture.BeforeOutputs; afterOutputs = $afterOutputs; outputManifest = $afterManifest; reservations = $Fixture.State.reservations
    }
  }
function Open-Recovery679ReadHandle([string]$Path) {
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith($runRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Lock path escaped the fresh fixture root.'
    }
    $item = Get-Item -LiteralPath $fullPath -Force -ErrorAction Stop
    if ($item.PSIsContainer) { throw 'Lock target must be an existing fixture file.' }
    while ($null -ne $item) {
      if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Reparse lock path prohibited.' }
      $item = if ($item -is [IO.FileInfo]) { $item.Directory } else { $item.Parent }
    }
    # Real OS handle: readers remain admitted; replacement/deletion are denied.
    return [IO.FileStream]::new($fullPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
  }

function Assert-Recovery679Plan($Fixture, $Retained) {
    $immutable = Test-Recovery679Clone $Retained
    foreach ($key in @('status', 'recoveryEvidence', 'commitReceiptId')) { $immutable.Remove($key) }
    $original = Test-Recovery679Clone $Fixture.Operation
    $original.Remove('status')
    (Test-Recovery679Json $immutable $null) | Should -BeExactly (Test-Recovery679Json $original $null)
  }
}

Describe 'Actual quartet candidate recovery after Windows sharing refusal (synthetic custody)' -Tag 'Integration' {
  It 'resumes the exact completion quartet after companion replacement refusal without replaying its published prefix' -Tag 'CompletionCapability' {
    $f = New-Recovery679Fixture
    $beforeImages = Test-Recovery679Element (Test-Recovery679Bytes $f.BeforeOutputs)
    $scratch = Join-Path $runRoot 'Candidate'
    # One actual source candidate call uses installed Lifecycle0.1.61 before the refusal.
    $results = @(New-CoordQuartetCandidate -Preview $f.Preview -BeforeImages $beforeImages -ScratchRoot $scratch -Confirm:$false -ErrorAction Stop)
    $results.Count | Should -Be 1
    $candidate = $results[0]
    $candidate.Stage | Should -BeExactly 'CandidateNotPrepared'
    $candidate.Action | Should -BeExactly 'Rendered'
    $candidateJson = $candidate.AfterOutputs.GetRawText()
    $operation = New-Recovery679Plan $f $candidate
    $f['Operation'] = $operation
    $scratchPins = @(Get-ChildItem -LiteralPath $scratch -File -Recurse -Force | ForEach-Object {
        [pscustomobject]@{Path = $_.FullName; Raw = Get-Recovery679Raw $_.FullName; WriteTicks = $_.LastWriteTimeUtc.Ticks}
      })
    $scratchPins.Count | Should -Be 2
    foreach ($slot in @('markdown', 'boardHtml')) {
      $path = Join-Path $scratch ([IO.Path]::GetFileName($operation.afterOutputs[$slot].path))
      (Get-Recovery679Raw $path) | Should -BeExactly $operation.afterOutputs[$slot].bytesBase64
    }
    $plan = Test-Recovery679Element (Test-Recovery679Bytes $operation)
    $saved = Save-CoordOperation -StatePath $f.Path -ExpectedStateBytes $f.Raw -Operation $plan -Confirm:$false -ErrorAction Stop
    $saved.Stage | Should -BeExactly 'Prepared'
    $saved.Action | Should -BeExactly 'Saved'
    $prepared = Read-Recovery679State $f
    $prepared.preparedOperations.Count | Should -Be 1
    Assert-Recovery679Plan $f $prepared.preparedOperations[0]

    $handle = $null
    try {
      # Both MD and rendered HTML commit before the changed procedure companion.
      $handle = Open-Recovery679ReadHandle $operation.beforeOutputs.proceduralDetailsHtml.path
      (Get-Recovery679Raw $operation.beforeOutputs.proceduralDetailsHtml.path) | Should -BeExactly $operation.beforeOutputs.proceduralDetailsHtml.bytesBase64
      $held = Complete-CoordOperation -StatePath $f.Path -ExpectedStateBytes ([IO.File]::ReadAllBytes($f.Path)) -OperationId 'op-explicit' -Confirm:$false -ErrorAction Stop
      $held.Stage | Should -BeExactly 'NeedsRecovery'
      $held.Action | Should -BeExactly 'Held'
      $held.OperationStatus | Should -BeExactly 'NeedsRecovery'
      $held.CommitReceiptId | Should -BeNullOrEmpty
      $state = Read-Recovery679State $f
      $state.generation | Should -BeExactly 'epoch-A'
      $state.committedRevision | Should -BeExactly 'head-A'
      (Test-Recovery679Json $state.committedOutputManifest $null) | Should -BeExactly (Test-Recovery679Json $f.State.committedOutputManifest $null)
      $state.commitReceipts.Count | Should -Be 0
      $state.requests[0].status | Should -BeExactly 'NeedsRecovery'
      $state.requests[0].preparedOperationId | Should -BeExactly 'op-explicit'
      $state.requests[0].Contains('terminalEvidence') | Should -BeFalse
      $state.preparedOperations.Count | Should -Be 1
      $state.preparedOperations[0].status | Should -BeExactly 'NeedsRecovery'
      Assert-Recovery679Plan $f $state.preparedOperations[0]
      $state.mutationAdmission.status | Should -BeExactly 'NeedsRecovery'
      $state.mutationAdmission.reason | Should -BeExactly 'OutputPublicationInterrupted'
      $state.preparedOperations[0].recoveryEvidence.reason | Should -BeExactly 'OutputPublicationInterrupted'
      (Test-Recovery679Json $state.requests[0].recoveryEvidence $null) | Should -BeExactly (Test-Recovery679Json $state.preparedOperations[0].recoveryEvidence $null)
      $heldRecovery = Test-Recovery679Clone $state.preparedOperations[0].recoveryEvidence
      $observed = $state.preparedOperations[0].recoveryEvidence.observedOutputs
      $observed.Count | Should -Be 4
      foreach ($slot in $slotNames) {
        $expected = if ($slot -in @('markdown', 'boardHtml')) { $operation.afterOutputs[$slot] } else { $operation.beforeOutputs[$slot] }
        (Get-Recovery679Raw $expected.path) | Should -BeExactly $expected.bytesBase64
        $evidence = @($observed | Where-Object {$_.path -ceq $expected.path})
        $evidence.Count | Should -Be 1
        $evidence[0].bytesBase64 | Should -BeExactly $expected.bytesBase64
        $evidence[0].digest | Should -BeExactly $expected.digest
      }
      $stages = @([IO.Directory]::GetFiles($f.Root, '*.output.tmp'))
      $stages.Count | Should -Be 1
      (Get-Recovery679Raw $stages[0]) | Should -BeExactly $operation.afterOutputs.proceduralDetailsHtml.bytesBase64
    } finally {
      if ($null -ne $handle) { $handle.Dispose() }
    }

    # Prefix replacement would fail on this real handle. Scratch handles likewise
    # deny the installed renderer's writes to its original candidate files.
    $handles = [Collections.Generic.List[IO.FileStream]]::new()
    try {
      $handles.Add((Open-Recovery679ReadHandle $operation.afterOutputs.markdown.path))
      $handles.Add((Open-Recovery679ReadHandle $operation.afterOutputs.boardHtml.path))
      $prefixTime = [IO.File]::GetLastWriteTimeUtc($operation.afterOutputs.markdown.path).Ticks
      $boardPrefixTime = [IO.File]::GetLastWriteTimeUtc($operation.afterOutputs.boardHtml.path).Ticks
      foreach ($pin in $scratchPins) { $handles.Add((Open-Recovery679ReadHandle $pin.Path)) }
      $resumed = Complete-CoordOperation -StatePath $f.Path -ExpectedStateBytes ([IO.File]::ReadAllBytes($f.Path)) -OperationId 'op-explicit' -Resume -Confirm:$false -ErrorAction Stop
      $resumed.Stage | Should -BeExactly 'Applied'
      $resumed.Action | Should -BeExactly 'Completed'
      $resumed.CommitReceiptId | Should -BeExactly 'op-explicit'
      [IO.File]::GetLastWriteTimeUtc($operation.afterOutputs.markdown.path).Ticks | Should -Be $prefixTime
      [IO.File]::GetLastWriteTimeUtc($operation.afterOutputs.boardHtml.path).Ticks | Should -Be $boardPrefixTime
      foreach ($pin in $scratchPins) {
        (Get-Recovery679Raw $pin.Path) | Should -BeExactly $pin.Raw
        [IO.File]::GetLastWriteTimeUtc($pin.Path).Ticks | Should -Be $pin.WriteTicks
      }
      @(Get-ChildItem -LiteralPath $scratch -File -Recurse -Force).Count | Should -Be $scratchPins.Count
    } finally {
      foreach ($openHandle in $handles) { $openHandle.Dispose() }
    }

    $state = Read-Recovery679State $f
    [Convert]::ToBase64String((Test-Recovery679Bytes $state -Projection)) | Should -BeExactly $operation.afterStateImage.bytesBase64
    $state.preparedOperations.Count | Should -Be 1
    $state.preparedOperations[0].status | Should -BeExactly 'Applied'
    $state.preparedOperations[0].commitReceiptId | Should -BeExactly 'op-explicit'
    Assert-Recovery679Plan $f $state.preparedOperations[0]
    (Test-Recovery679Json $state.preparedOperations[0].recoveryEvidence $null) | Should -BeExactly (Test-Recovery679Json $heldRecovery $null)
    $state.requests[0].Contains('recoveryEvidence') | Should -BeFalse
    $state.commitReceipts.Count | Should -Be 1
    $receipt = $state.commitReceipts[0]
    $receipt.receiptId | Should -BeExactly 'op-explicit'
    $receipt.operationId | Should -BeExactly 'op-explicit'
    $receipt.resourceId | Should -BeExactly $state.resourceId
    $receipt.generation | Should -BeExactly $state.generation
    $receipt.committedRevision | Should -BeExactly 'head-N'
    $receipt.requestIds.Count | Should -Be 1
    $receipt.requestIds[0] | Should -BeExactly 'R-new'
    (Test-Recovery679Json $receipt.outputManifest $null) | Should -BeExactly (Test-Recovery679Json $state.committedOutputManifest $null)
    (Test-Recovery679Json $receipt.reservations $null) | Should -BeExactly (Test-Recovery679Json $state.reservations $null)
    $receipt.terminalEvidence.Count | Should -Be 1
    (Test-Recovery679Json $receipt.terminalEvidence[0] $null) | Should -BeExactly (Test-Recovery679Json $state.requests[0].terminalEvidence $null)
    foreach ($slot in $slotNames) {
      (Get-Recovery679Raw $operation.afterOutputs[$slot].path) | Should -BeExactly $operation.afterOutputs[$slot].bytesBase64
    }
    $candidate.AfterOutputs.GetRawText() | Should -BeExactly $candidateJson
    [IO.File]::Exists($stages[0]) | Should -BeTrue
    (Get-Recovery679Raw $stages[0]) | Should -BeExactly $operation.afterOutputs.proceduralDetailsHtml.bytesBase64
  }
}

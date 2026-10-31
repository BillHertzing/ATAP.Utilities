#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
param(
  [Parameter()][ValidateNotNullOrEmpty()][string]$FixtureRoot = $(
    if ([Environment]::MachineName -ieq 'UTAT022') {
      'D:/ATAPArtifacts/Sprint0017/Task17.30.b/CandidatePublication649/Fixtures-' + [guid]::NewGuid().ToString('N')
    } else {
      throw 'FixtureRoot must be supplied explicitly on this host; no default mapping is approved.'
    }
  )
)

# Synthetic custody only: no live admission, Invoke-CoordClerk/drain or power-loss proof.
# One independent Run.Path container; no mocks, old test-container imports or cleanup.
# Codec, fourteen-field projection and state/plan literals reuse baseline531:
# tests/Integration/SaveCompleteSharingViolation.Tests.ps1 (raw pin in InputPins.json).
# The preview is caller-constructed, matching583/645; preview provenance is assumed.
BeforeAll {
  if (-not $IsWindows) { throw 'This integration container requires Windows publication semantics.' }
  $allowed = [IO.Path]::GetFullPath('D:/ATAPArtifacts/Sprint0017/Task17.30.b/CandidatePublication649').TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
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
  function Test-Publication649Sha([byte[]]$Bytes) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
  }
  function Test-Publication649Json($Value, [string[]]$TopNames) {
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [System.Collections.IDictionary]) {
      [string[]]$keys = if ($null -ne $TopNames) { $TopNames } else { @($Value.Keys) }
      if ($null -eq $TopNames) {
        $order = [Collections.Generic.SortedDictionary[string, string]]::new([StringComparer]::Ordinal)
        foreach ($key in $keys) { $order.Add([Convert]::ToHexString($enc.GetBytes($key)), $key) }
        $keys = @($order.Values)
      }
      $pairs = foreach ($key in $keys) {
        (ConvertTo-Json -InputObject ([string]$key) -Compress) + ':' + (Test-Publication649Json $Value[$key] $null)
      }
      return '{' + ($pairs -join ',') + '}'
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
      return '[' + (@($Value | ForEach-Object { Test-Publication649Json $_ $null }) -join ',') + ']'
    }
    return (ConvertTo-Json -InputObject $Value -Depth 100 -Compress)
  }
  function Test-Publication649Bytes($Value, [switch]$Projection) {
    $names = if ($Projection) { $script:projection } else { $null }
    $json = (Test-Publication649Json $Value $names)
    return , ($enc.GetBytes($json + [char]10))
  }
  function Test-Publication649Element([byte[]]$Bytes) {
    $doc = [System.Text.Json.JsonDocument]::Parse($enc.GetString($Bytes))
    try { $doc.RootElement.Clone() } finally { $doc.Dispose() }
  }
  function Test-Publication649Clone($Value) { (Test-Publication649Json $Value $null) | ConvertFrom-Json -AsHashtable -Depth 100 }
  function Test-Publication649Image([byte[]]$Bytes, [string]$Path) {
    $value = [ordered]@{ bytesBase64 = [Convert]::ToBase64String($Bytes); digest = Test-Publication649Sha $Bytes }
    if ($Path) { $value.path = $Path }
    return $value
  }
  function Get-Publication649Raw([string]$Path) { [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path)) }
  function Read-Publication649State($Fixture) {
    [IO.File]::ReadAllText($Fixture.Path, $enc) | ConvertFrom-Json -AsHashtable -Depth 100
  }
  function New-Publication649Fixture {
    $root = Join-Path $runRoot 'Inputs'
    $null = [IO.Directory]::CreateDirectory($root)
    $text = @('# Current Sprint: fixture', '', '## Goal', 'Synthetic quartet publication.', '',
      '## Stream C - fixture', '- [ ] **Task 17.30** [ATAP.Utilities] - Fixture', '  - Status: Planned.', '') -join [char]10
    [byte[]]$beforeMarkdown = $enc.GetBytes($text)
    [byte[]]$afterMarkdown = $enc.GetBytes($text.Replace('Planned.', 'CLAIMED.'))
    $files = [ordered]@{
      markdown = @{name = 'Tasks.Sprint0017.md'; bytes = $beforeMarkdown}
      boardHtml = @{name = 'Tasks.Sprint0017.html'; bytes = [byte[]]@()}
      proceduralDetailsHtml = @{name = 'Tasks.Sprint0017.ProceduralDetails.html'; bytes = [byte[]]@(239, 187, 191, 13, 10, 0, 255)}
      accomplishedHtml = @{name = 'Tasks.Sprint0017.Accomplished.html'; bytes = [byte[]]@()}
    }
    $manifest = [ordered]@{}; $beforeOutputs = [ordered]@{}
    foreach ($slot in $slotNames) {
      $path = Join-Path $root $files[$slot].name
      [byte[]]$bytes = $files[$slot].bytes
      [IO.File]::WriteAllBytes($path, $bytes)
      $beforeOutputs[$slot] = Test-Publication649Image $bytes $path
      $manifest[$slot] = [ordered]@{path = $path; digest = Test-Publication649Sha $bytes}
    }
    # Baseline531 shape-valid state: these references assert synthetic caller authority only.
    $request = [ordered]@{
      protocolVersion = 'Coordination-v1'; resourceId = 'board-S17'; sprintId = '0017'; requestId = 'R-new'
      category = 'Claim'; taskId = '17.30'; scope = @([ordered]@{registeredRootId = 'fixture'; path = 'owned.ps1'})
      holder = [ordered]@{holderId = 'fixture-holder'; sessionId = 'fixture-session'}
      authorizationReference = 'synthetic-boundary'; generation = 'epoch-A'; expectedRevision = 'head-A'
      predecessors = @(); payload = [ordered]@{}
    }
    $requestJson = Test-Publication649Json $request $null
    $record = [ordered]@{request = $request; digest = Test-Publication649Sha $enc.GetBytes($requestJson); originalRequestJson = $requestJson
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
      BeforeSha256 = Test-Publication649Sha $beforeMarkdown; AfterSha256 = Test-Publication649Sha $afterMarkdown
      BeforeBytes = $beforeMarkdown.Clone(); AfterBytes = $afterMarkdown.Clone(); AfterText = $enc.GetString($afterMarkdown)
      Reservations = (Test-Publication649Element (Test-Publication649Bytes $state.reservations))
    }
    $path = Join-Path $root 'state.json'
    [byte[]]$raw = Test-Publication649Bytes $state
    [IO.File]::WriteAllBytes($path, $raw)
    return @{Root = $root; Path = $path; Raw = $raw; State = $state; BeforeOutputs = $beforeOutputs; Preview = $preview}
  }
  function New-Publication649Plan($Fixture, $Candidate) {
    $afterOutputs = $Candidate.AfterOutputs.GetRawText() | ConvertFrom-Json -AsHashtable -Depth 100
    $afterManifest = [ordered]@{}
    foreach ($slot in $slotNames) {
      $afterManifest[$slot] = [ordered]@{path = $afterOutputs[$slot].path; digest = $afterOutputs[$slot].digest}
    }
    $after = Test-Publication649Clone $Fixture.State
    $after.committedRevision = 'head-N'; $after.committedOutputManifest = $afterManifest
    $after.requests[0].Remove('pendingEvidence'); $after.requests[0].status = 'Applied'
    $after.requests[0].preparedOperationId = 'op-explicit'
    $after.requests[0].terminalEvidence = [ordered]@{resourceId = 'board-S17'; requestId = 'R-new'; digest = $Fixture.State.requests[0].digest
      status = 'Applied'; reason = 'Planned caller-validated outcome'; receipt = $Fixture.State.custodyEvidence}
    return [ordered]@{
      operationId = 'op-explicit'; resourceId = 'board-S17'; status = 'Prepared'
      baseHead = [ordered]@{generation = 'epoch-A'; committedRevision = 'head-A'; outputManifest = $Fixture.State.committedOutputManifest}
      nextRevision = 'head-N'; requestIds = @('R-new')
      beforeStateImage = Test-Publication649Image (Test-Publication649Bytes $Fixture.State -Projection)
      afterStateImage = Test-Publication649Image (Test-Publication649Bytes $after -Projection)
      beforeOutputs = $Fixture.BeforeOutputs; afterOutputs = $afterOutputs; outputManifest = $afterManifest; reservations = $Fixture.State.reservations
    }
  }
}

Describe 'Actual quartet candidate to Save/Complete (D-only synthetic custody)' -Tag 'Integration' {
  It 'retains the rendered candidate in Prepared then publishes exact quartet bytes and one coherent receipt' {
    $f = New-Publication649Fixture
    $beforeImages = Test-Publication649Element (Test-Publication649Bytes $f.BeforeOutputs)
    $scratch = Join-Path $runRoot 'Candidate'
    # Actual source adapter imports and resolves exactly installed SprintLifecycle0.1.61.
    $results = @(New-CoordQuartetCandidate -Preview $f.Preview -BeforeImages $beforeImages -ScratchRoot $scratch -Confirm:$false -ErrorAction Stop)
    $results.Count | Should -Be 1
    $candidate = $results[0]
    $candidate.Stage | Should -BeExactly 'CandidateNotPrepared'
    $candidate.Action | Should -BeExactly 'Rendered'
    $candidate.BeforeOutputs.GetRawText() | Should -BeExactly $beforeImages.GetRawText()
    (Get-Publication649Raw $f.Path) | Should -BeExactly ([Convert]::ToBase64String($f.Raw))
    $operation = New-Publication649Plan $f $candidate
    foreach ($slot in $slotNames) {
      $image = $operation.afterOutputs[$slot]
      $image.path | Should -BeExactly $f.BeforeOutputs[$slot].path
      [byte[]]$bytes = [Convert]::FromBase64String($image.bytesBase64)
      (Test-Publication649Sha $bytes) | Should -BeExactly $image.digest
      (Get-Publication649Raw $image.path) | Should -BeExactly $f.BeforeOutputs[$slot].bytesBase64
    }
    $operation.afterOutputs.markdown.bytesBase64 | Should -BeExactly ([Convert]::ToBase64String($f.Preview.AfterBytes))
    foreach ($slot in @('proceduralDetailsHtml', 'accomplishedHtml')) {
      $operation.afterOutputs[$slot].bytesBase64 | Should -BeExactly $f.BeforeOutputs[$slot].bytesBase64
    }
    foreach ($slot in @('markdown', 'boardHtml')) {
      [byte[]]$bytes = [Convert]::FromBase64String($operation.afterOutputs[$slot].bytesBase64)
      $bytes.Length | Should -BeGreaterThan 3
      ($bytes -contains [byte]13) | Should -BeFalse
      [Convert]::ToHexString($bytes[0..2]) | Should -Not -BeExactly 'EFBBBF'
      $bytes[-1] | Should -Be 10
      $text = $enc.GetString($bytes)
      $text | Should -Match '17\.30'
      $text | Should -Match 'CLAIMED'
      (Get-Publication649Raw (Join-Path $scratch ([IO.Path]::GetFileName($operation.afterOutputs[$slot].path)))) | Should -BeExactly $operation.afterOutputs[$slot].bytesBase64
    }
    $candidateJson = $candidate.AfterOutputs.GetRawText()
    $plan = Test-Publication649Element (Test-Publication649Bytes $operation)
    $saved = Save-CoordOperation -StatePath $f.Path -ExpectedStateBytes $f.Raw -Operation $plan -Confirm:$false -ErrorAction Stop
    $saved.Stage | Should -BeExactly 'Prepared'
    $saved.Action | Should -BeExactly 'Saved'
    $prepared = Read-Publication649State $f
    $prepared.committedRevision | Should -BeExactly 'head-A'
    $prepared.requests[0].status | Should -BeExactly 'Prepared'
    $prepared.requests[0].preparedOperationId | Should -BeExactly 'op-explicit'
    $prepared.requests[0].Contains('terminalEvidence') | Should -BeFalse
    $prepared.commitReceipts.Count | Should -Be 0
    $prepared.preparedOperations.Count | Should -Be 1
    (Test-Publication649Json $prepared.preparedOperations[0] $null) | Should -BeExactly (Test-Publication649Json $operation $null)
    foreach ($slot in $slotNames) {
      (Get-Publication649Raw $operation.beforeOutputs[$slot].path) | Should -BeExactly $operation.beforeOutputs[$slot].bytesBase64
    }
    $completed = Complete-CoordOperation -StatePath $f.Path -ExpectedStateBytes ([IO.File]::ReadAllBytes($f.Path)) -OperationId 'op-explicit' -Confirm:$false -ErrorAction Stop
    $completed.Stage | Should -BeExactly 'Applied'
    $completed.Action | Should -BeExactly 'Completed'
    $completed.CommitReceiptId | Should -BeExactly 'op-explicit'
    $state = Read-Publication649State $f
    [Convert]::ToBase64String((Test-Publication649Bytes $state -Projection)) | Should -BeExactly $operation.afterStateImage.bytesBase64
    $state.preparedOperations.Count | Should -Be 1
    $state.preparedOperations[0].status | Should -BeExactly 'Applied'
    $state.preparedOperations[0].commitReceiptId | Should -BeExactly 'op-explicit'
    $immutable = Test-Publication649Clone $state.preparedOperations[0]
    $immutable.Remove('commitReceiptId'); $immutable.status = 'Prepared'
    (Test-Publication649Json $immutable $null) | Should -BeExactly (Test-Publication649Json $operation $null)
    $state.commitReceipts.Count | Should -Be 1
    $receipt = $state.commitReceipts[0]
    $receipt.receiptId | Should -BeExactly 'op-explicit'
    $receipt.operationId | Should -BeExactly 'op-explicit'
    $receipt.resourceId | Should -BeExactly 'board-S17'
    $receipt.generation | Should -BeExactly 'epoch-A'
    $receipt.committedRevision | Should -BeExactly 'head-N'
    $receipt.requestIds.Count | Should -Be 1
    $receipt.requestIds[0] | Should -BeExactly 'R-new'
    (Test-Publication649Json $receipt.outputManifest $null) | Should -BeExactly (Test-Publication649Json $state.committedOutputManifest $null)
    (Test-Publication649Json $receipt.reservations $null) | Should -BeExactly (Test-Publication649Json $f.State.reservations $null)
    $receipt.terminalEvidence.Count | Should -Be 1
    (Test-Publication649Json $receipt.terminalEvidence[0] $null) | Should -BeExactly (Test-Publication649Json $state.requests[0].terminalEvidence $null)
    foreach ($slot in $slotNames) {
      (Get-Publication649Raw $operation.afterOutputs[$slot].path) | Should -BeExactly $operation.afterOutputs[$slot].bytesBase64
      (Get-FileHash -LiteralPath $operation.afterOutputs[$slot].path -Algorithm SHA256).Hash.ToLowerInvariant() | Should -BeExactly $state.committedOutputManifest[$slot].digest
    }
    $candidate.AfterOutputs.GetRawText() | Should -BeExactly $candidateJson
    # Existing retained-Applied contract: retry reads history and leaves all five files unchanged.
    $paths = @($f.Path) + @($slotNames | ForEach-Object { $operation.afterOutputs[$_].path })
    $pins = @{}
    foreach ($path in $paths) { $pins[$path] = @((Get-Publication649Raw $path), [IO.File]::GetLastWriteTimeUtc($path).Ticks) }
    $retry = Complete-CoordOperation -StatePath $f.Path -ExpectedStateBytes ([IO.File]::ReadAllBytes($f.Path)) -OperationId 'op-explicit' -Confirm:$false -ErrorAction Stop
    $retry.Stage | Should -BeExactly 'Retained'
    $retry.Action | Should -BeExactly 'Unchanged'
    $retry.OperationStatus | Should -BeExactly 'Applied'
    $retry.CommitReceiptId | Should -BeExactly 'op-explicit'
    foreach ($path in $paths) {
      (Get-Publication649Raw $path) | Should -BeExactly $pins[$path][0]
      [IO.File]::GetLastWriteTimeUtc($path).Ticks | Should -Be $pins[$path][1]
    }
    (Read-Publication649State $f).commitReceipts.Count | Should -Be 1
  }
}

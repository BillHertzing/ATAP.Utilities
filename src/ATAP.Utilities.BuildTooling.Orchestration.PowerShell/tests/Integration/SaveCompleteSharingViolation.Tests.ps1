#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
param(
  [Parameter()][ValidateNotNullOrEmpty()][string]$FixtureRoot = $(
    if ([Environment]::MachineName -ieq 'UTAT022') {
      'D:/ATAPArtifacts/Sprint0017/Task17.30.b/SharingViolation531/Fixtures-' + [guid]::NewGuid().ToString('N')
    } else {
      throw 'FixtureRoot must be supplied explicitly on this host; no default mapping is approved.'
    }
  )
)

# Synthetic custody only: no live authority, physical admission or power-loss proof.
# Run only this container; UTAT022 defaults to a fresh D-only root, with the same guards for explicit overrides.
# Fixture codec and literal state/plan shape adapted from tests/Unit/Complete-CoordOperation.Tests.ps1
# (SHA256 184DEED887CBF10A708494CDDE6456F8CE400AC13F59F82D63B61730C5AFED75).
# Its containers, I/O wrapper and synthetic faults are deliberately not loaded.
BeforeAll {
  if (-not $IsWindows) { throw 'This integration container requires Windows file sharing semantics.' }
  $allowed = [IO.Path]::GetFullPath('D:/ATAPArtifacts/Sprint0017/Task17.30.b/SharingViolation531').TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
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
  $script:enc = [Text.UTF8Encoding]::new($false, $true)
  $script:projection = @('schemaVersion', 'resourceId', 'lineageId', 'registeredRoots', 'generation',
    'committedRevision', 'committedOutputManifest', 'custodyEvidence', 'compatibilityEvidence',
    'admissionEvidence', 'requests', 'claims', 'reservations', 'mutationAdmission')
  $script:slotNames = @('markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml')
  function Test-Sharing531Sha([byte[]]$Bytes) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
  }
  function Test-Sharing531Json($Value, [string[]]$TopNames) {
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [System.Collections.IDictionary]) {
      [string[]]$keys = if ($null -ne $TopNames) { $TopNames } else { @($Value.Keys) }
      if ($null -eq $TopNames) {
        $order = [Collections.Generic.SortedDictionary[string, string]]::new([StringComparer]::Ordinal)
        foreach ($key in $keys) { $order.Add([Convert]::ToHexString($enc.GetBytes($key)), $key) }
        $keys = @($order.Values)
      }
      $pairs = foreach ($key in $keys) {
        (ConvertTo-Json -InputObject ([string]$key) -Compress) + ':' + (Test-Sharing531Json $Value[$key] $null)
      }
      return '{' + ($pairs -join ',') + '}'
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
      return '[' + (@($Value | ForEach-Object { Test-Sharing531Json $_ $null }) -join ',') + ']'
    }
    return (ConvertTo-Json -InputObject $Value -Depth 100 -Compress)
  }
  function Test-Sharing531Bytes($Value, [switch]$Projection) {
    $names = if ($Projection) { $script:projection } else { $null }
    $json = (Test-Sharing531Json $Value $names)
    return , ($enc.GetBytes($json + [char]10))
  }
  function Test-Sharing531Element([byte[]]$Bytes) {
    $doc = [System.Text.Json.JsonDocument]::Parse($enc.GetString($Bytes))
    try { $doc.RootElement.Clone() } finally { $doc.Dispose() }
  }
  function Test-Sharing531Clone($Value) { (Test-Sharing531Json $Value $null) | ConvertFrom-Json -AsHashtable -Depth 100 }
  function Test-Sharing531Image([byte[]]$Bytes, [string]$Path) {
    $value = [ordered]@{ bytesBase64 = [Convert]::ToBase64String($Bytes); digest = Test-Sharing531Sha $Bytes }
    if ($Path) { $value.path = $Path }
    return $value
  }
  function New-Sharing531Fixture() {
    $root = Join-Path $runRoot ([guid]::NewGuid().ToString('N'))
    $null = [IO.Directory]::CreateDirectory($root)
    $manifest = [ordered]@{}; $beforeOutputs = [ordered]@{}; $afterOutputs = [ordered]@{}; $afterManifest = [ordered]@{}
    foreach ($slot in $slotNames) {
      $path = Join-Path $root ($slot + '.fixture')
      [byte[]]$before = if ($slot -eq 'markdown') { @(239, 187, 191) + $enc.GetBytes('Before board' + [char]13 + [char]10) } else { $enc.GetBytes("Before $slot" + [char]13 + [char]10) }
      [byte[]]$next = $enc.GetBytes("After $slot" + [char]10)
      [IO.File]::WriteAllBytes($path, $before)
      $beforeOutputs[$slot] = Test-Sharing531Image $before $path; $afterOutputs[$slot] = Test-Sharing531Image $next $path
      $manifest[$slot] = [ordered]@{path = $path; digest = Test-Sharing531Sha $before}
      $afterManifest[$slot] = [ordered]@{path = $path; digest = Test-Sharing531Sha $next}
    }
    # Shape-valid synthetic authority/evidence assumptions; no live admission proof.
    $request = [ordered]@{
      protocolVersion = 'Coordination-v1'; resourceId = 'board-S17'; sprintId = '0017'; requestId = 'R-new'
      category = 'Claim'; taskId = '17.27'; scope = @([ordered]@{registeredRootId = 'fixture'; path = 'owned.ps1'})
      holder = [ordered]@{holderId = 'fixture-holder'; sessionId = 'fixture-session'}
      authorizationReference = 'synthetic-boundary'; generation = 'epoch-A'; expectedRevision = 'head-A'
      predecessors = @(); payload = [ordered]@{}
    }
    $requestJson = Test-Sharing531Json $request $null
    $record = [ordered]@{request = $request; digest = Test-Sharing531Sha $enc.GetBytes($requestJson); originalRequestJson = $requestJson
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
    $after = Test-Sharing531Clone $state
    $after.committedRevision = 'head-N'; $after.committedOutputManifest = $afterManifest
    $after.requests[0].Remove('pendingEvidence'); $after.requests[0].status = 'Applied'
    $after.requests[0].preparedOperationId = 'op-explicit'
    $after.requests[0].terminalEvidence = [ordered]@{resourceId = 'board-S17'; requestId = 'R-new'; digest = $record.digest
      status = 'Applied'; reason = 'Planned caller-validated outcome'; receipt = $reference}
    $operation = [ordered]@{
      operationId = 'op-explicit'; resourceId = 'board-S17'; status = 'Prepared'
      baseHead = [ordered]@{generation = 'epoch-A'; committedRevision = 'head-A'; outputManifest = $manifest}
      nextRevision = 'head-N'; requestIds = @('R-new')
      beforeStateImage = Test-Sharing531Image (Test-Sharing531Bytes $state -Projection)
      afterStateImage = Test-Sharing531Image (Test-Sharing531Bytes $after -Projection)
      beforeOutputs = $beforeOutputs; afterOutputs = $afterOutputs; outputManifest = $afterManifest; reservations = $state.reservations
    }
    $path = Join-Path $root 'state.json'
    [byte[]]$raw = Test-Sharing531Bytes $state
    [IO.File]::WriteAllBytes($path, $raw)
    return @{Root = $root; Path = $path; Raw = $raw; Plan = (Test-Sharing531Element (Test-Sharing531Bytes $operation)); State = $state; Operation = $operation}
  }

  function Open-Sharing531ReadHandle([string]$Path) {
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
  function Read-Sharing531State($Fixture) {
    [IO.File]::ReadAllText($Fixture.Path, $enc) | ConvertFrom-Json -AsHashtable -Depth 100
  }
  function Get-Sharing531Raw([string]$Path) { [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path)) }
  function Save-Sharing531Fixture($Fixture) {
    Save-CoordOperation -StatePath $Fixture.Path -ExpectedStateBytes $Fixture.Raw -Operation $Fixture.Plan -Confirm:$false
  }
  function Complete-Sharing531Fixture($Fixture, [switch]$Resume) {
    Complete-CoordOperation -StatePath $Fixture.Path -ExpectedStateBytes ([IO.File]::ReadAllBytes($Fixture.Path)) -OperationId 'op-explicit' -Resume:$Resume -Confirm:$false
  }
  function Assert-Sharing531Plan($Fixture, $Retained) {
    $immutable = Test-Sharing531Clone $Retained
    foreach ($key in @('status', 'recoveryEvidence', 'commitReceiptId')) { $immutable.Remove($key) }
    $original = Test-Sharing531Clone $Fixture.Operation
    $original.Remove('status')
    (Test-Sharing531Json $immutable $null) | Should -BeExactly (Test-Sharing531Json $original $null)
  }
  function Assert-Sharing531AppliedAndRetry($Fixture) {
    $state = Read-Sharing531State $Fixture
    $state.generation | Should -BeExactly 'epoch-A'
    $state.committedRevision | Should -BeExactly 'head-N'
    $state.requests.Count | Should -Be 1
    $state.requests[0].status | Should -BeExactly 'Applied'
    $state.requests[0].preparedOperationId | Should -BeExactly 'op-explicit'
    $state.requests[0].Contains('pendingEvidence') | Should -BeFalse
    $state.requests[0].Contains('recoveryEvidence') | Should -BeFalse
    $state.preparedOperations.Count | Should -Be 1
    $state.preparedOperations[0].status | Should -BeExactly 'Applied'
    $state.preparedOperations[0].commitReceiptId | Should -BeExactly 'op-explicit'
    Assert-Sharing531Plan $Fixture $state.preparedOperations[0]
    $state.commitReceipts.Count | Should -Be 1
    $receipt = $state.commitReceipts[0]
    $receipt.receiptId | Should -BeExactly 'op-explicit'
    $receipt.operationId | Should -BeExactly 'op-explicit'
    $receipt.generation | Should -BeExactly 'epoch-A'
    $receipt.committedRevision | Should -BeExactly 'head-N'
    $receipt.requestIds.Count | Should -Be 1
    $receipt.requestIds[0] | Should -BeExactly 'R-new'
    $receipt.terminalEvidence.Count | Should -Be 1
    $receipt.terminalEvidence[0].status | Should -BeExactly 'Applied'
    $receipt.terminalEvidence[0].requestId | Should -BeExactly 'R-new'
    $receipt.terminalEvidence[0].digest | Should -BeExactly $Fixture.State.requests[0].digest
    (Test-Sharing531Json $state.requests[0].terminalEvidence $null) | Should -BeExactly (Test-Sharing531Json $receipt.terminalEvidence[0] $null)
    (Test-Sharing531Json $state.committedOutputManifest $null) | Should -BeExactly (Test-Sharing531Json $Fixture.Operation.outputManifest $null)
    (Test-Sharing531Json $receipt.outputManifest $null) | Should -BeExactly (Test-Sharing531Json $Fixture.Operation.outputManifest $null)
    (Test-Sharing531Json $state.reservations $null) | Should -BeExactly (Test-Sharing531Json $Fixture.State.reservations $null)
    foreach ($slot in $slotNames) {
      (Get-Sharing531Raw $Fixture.Operation.afterOutputs[$slot].path) | Should -BeExactly $Fixture.Operation.afterOutputs[$slot].bytesBase64
    }

    # Hold state AND all quartet targets read-only during retry. Any publication
    # would hit an actual sharing denial; retained retry must need only reads.
    $handles = [Collections.Generic.List[IO.FileStream]]::new()
    try {
      $paths = @($Fixture.Path) + @($slotNames | ForEach-Object { $Fixture.Operation.afterOutputs[$_].path })
      $before = @{}
      foreach ($path in $paths) {
        $handles.Add((Open-Sharing531ReadHandle $path))
        $before[$path] = @((Get-Sharing531Raw $path), [IO.File]::GetLastWriteTimeUtc($path).Ticks)
      }
      $retry = Complete-Sharing531Fixture $Fixture
      $retry.Stage | Should -BeExactly 'Retained'
      $retry.Action | Should -BeExactly 'Unchanged'
      $retry.OperationStatus | Should -BeExactly 'Applied'
      $retry.CommitReceiptId | Should -BeExactly 'op-explicit'
      foreach ($path in $paths) {
        (Get-Sharing531Raw $path) | Should -BeExactly $before[$path][0]
        [IO.File]::GetLastWriteTimeUtc($path).Ticks | Should -Be $before[$path][1]
      }
      (Read-Sharing531State $Fixture).commitReceipts.Count | Should -Be 1
    } finally {
      foreach ($handle in $handles) { $handle.Dispose() }
    }
  }
}

Describe 'Save/Complete real Windows sharing denial (D-only synthetic custody)' -Tag 'Integration' {
  It 'controls an unmocked prepare/complete round trip and read-locked idempotent retry' {
    $f = New-Sharing531Fixture
    $saved = Save-Sharing531Fixture $f
    $saved.Stage | Should -BeExactly 'Prepared'
    $saved.Action | Should -BeExactly 'Saved'
    $state = Read-Sharing531State $f
    $state.committedRevision | Should -BeExactly 'head-A'
    $state.requests[0].status | Should -BeExactly 'Prepared'
    $state.commitReceipts.Count | Should -Be 0
    Assert-Sharing531Plan $f $state.preparedOperations[0]
    foreach ($slot in $slotNames) {
      (Get-Sharing531Raw $f.Operation.beforeOutputs[$slot].path) | Should -BeExactly $f.Operation.beforeOutputs[$slot].bytesBase64
    }
    $completed = Complete-Sharing531Fixture $f
    $completed.Stage | Should -BeExactly 'Applied'
    $completed.Action | Should -BeExactly 'Completed'
    Assert-Sharing531AppliedAndRetry $f
  }

  It 'keeps pending state and staged preparation when a real state handle denies Save replacement' {
    $f = New-Sharing531Fixture
    $handle = $null
    try {
      $handle = Open-Sharing531ReadHandle $f.Path
      # Successful reads rule out an unreadable-state preflight failure.
      (Get-Sharing531Raw $f.Path) | Should -BeExactly ([Convert]::ToBase64String($f.Raw))
      { Save-Sharing531Fixture $f } | Should -Throw '*Save-CoordOperation: PersistenceFailed.*'
      (Get-Sharing531Raw $f.Path) | Should -BeExactly ([Convert]::ToBase64String($f.Raw))
      $state = Read-Sharing531State $f
      $state.committedRevision | Should -BeExactly 'head-A'
      $state.requests[0].status | Should -BeExactly 'Pending'
      $state.requests[0].Contains('preparedOperationId') | Should -BeFalse
      $state.requests[0].Contains('terminalEvidence') | Should -BeFalse
      $state.preparedOperations.Count | Should -Be 0
      $state.commitReceipts.Count | Should -Be 0
      $stages = @([IO.Directory]::GetFiles($f.Root, '*.prepared.tmp'))
      $stages.Count | Should -Be 1
      $staged = [IO.File]::ReadAllText($stages[0], $enc) | ConvertFrom-Json -AsHashtable -Depth 100
      $staged.requests[0].status | Should -BeExactly 'Prepared'
      Assert-Sharing531Plan $f $staged.preparedOperations[0]
      foreach ($slot in $slotNames) {
        (Get-Sharing531Raw $f.Operation.beforeOutputs[$slot].path) | Should -BeExactly $f.Operation.beforeOutputs[$slot].bytesBase64
      }
    } finally {
      if ($null -ne $handle) { $handle.Dispose() }
    }
    # Same original JsonElement and expected raw preimage, not a newly built plan.
    (Save-Sharing531Fixture $f).Stage | Should -BeExactly 'Prepared'
    [IO.File]::Exists($stages[0]) | Should -BeTrue
    (Complete-Sharing531Fixture $f).Stage | Should -BeExactly 'Applied'
    Assert-Sharing531AppliedAndRetry $f
  }

  It 'retains a published prefix and recovery when a quartet handle denies replacement then resumes that same plan' {
    $f = New-Sharing531Fixture
    (Save-Sharing531Fixture $f).Stage | Should -BeExactly 'Prepared'
    $handle = $null
    try {
      $handle = Open-Sharing531ReadHandle $f.Operation.beforeOutputs.boardHtml.path
      (Get-Sharing531Raw $f.Operation.beforeOutputs.boardHtml.path) | Should -BeExactly $f.Operation.beforeOutputs.boardHtml.bytesBase64
      $held = Complete-Sharing531Fixture $f
      $held.Stage | Should -BeExactly 'NeedsRecovery'
      $held.Action | Should -BeExactly 'Held'
      $held.OperationStatus | Should -BeExactly 'NeedsRecovery'
      $held.CommitReceiptId | Should -BeNullOrEmpty
      $state = Read-Sharing531State $f
      $state.committedRevision | Should -BeExactly 'head-A'
      $state.commitReceipts.Count | Should -Be 0
      $state.requests[0].status | Should -BeExactly 'NeedsRecovery'
      $state.requests[0].Contains('terminalEvidence') | Should -BeFalse
      $state.preparedOperations.Count | Should -Be 1
      $state.preparedOperations[0].status | Should -BeExactly 'NeedsRecovery'
      Assert-Sharing531Plan $f $state.preparedOperations[0]
      $state.mutationAdmission.status | Should -BeExactly 'NeedsRecovery'
      (Test-Sharing531Json $state.requests[0].recoveryEvidence $null) | Should -BeExactly (Test-Sharing531Json $state.preparedOperations[0].recoveryEvidence $null)
      $state.mutationAdmission.reason | Should -BeExactly 'OutputPublicationInterrupted'
      $state.preparedOperations[0].recoveryEvidence.reason | Should -BeExactly 'OutputPublicationInterrupted'
      $observed = $state.preparedOperations[0].recoveryEvidence.observedOutputs
      $observed.Count | Should -Be 4
      foreach ($slot in $slotNames) {
        $expected = if ($slot -eq 'markdown') { $f.Operation.afterOutputs[$slot] } else { $f.Operation.beforeOutputs[$slot] }
        (Get-Sharing531Raw $expected.path) | Should -BeExactly $expected.bytesBase64
        $evidence = @($observed | Where-Object { $_.path -ceq $expected.path })
        $evidence.Count | Should -Be 1
        $evidence[0].bytesBase64 | Should -BeExactly $expected.bytesBase64
        $evidence[0].digest | Should -BeExactly $expected.digest
      }
      (Test-Sharing531Json $state.committedOutputManifest $null) | Should -BeExactly (Test-Sharing531Json $f.State.committedOutputManifest $null)
      $stages = @([IO.Directory]::GetFiles($f.Root, '*.output.tmp'))
      $stages.Count | Should -Be 1
      (Get-Sharing531Raw $stages[0]) | Should -BeExactly $f.Operation.afterOutputs.boardHtml.bytesBase64
      # No Resume must preserve the exact recovery bytes while the lock remains.
      $heldRaw = Get-Sharing531Raw $f.Path
      $heldRetry = Complete-Sharing531Fixture $f
      $heldRetry.Stage | Should -BeExactly 'Retained'
      $heldRetry.Action | Should -BeExactly 'Held'
      (Get-Sharing531Raw $f.Path) | Should -BeExactly $heldRaw
    } finally {
      if ($null -ne $handle) { $handle.Dispose() }
    }
    # The already-published prefix is read-locked during resume: replay fails.
    $prefix = $null
    try {
      $prefix = Open-Sharing531ReadHandle $f.Operation.afterOutputs.markdown.path
      $prefixTime = [IO.File]::GetLastWriteTimeUtc($f.Operation.afterOutputs.markdown.path).Ticks
      $resumed = Complete-Sharing531Fixture $f -Resume
      $resumed.Stage | Should -BeExactly 'Applied'
      $resumed.Action | Should -BeExactly 'Completed'
      [IO.File]::GetLastWriteTimeUtc($f.Operation.afterOutputs.markdown.path).Ticks | Should -Be $prefixTime
      [IO.File]::Exists($stages[0]) | Should -BeTrue
    } finally {
      if ($null -ne $prefix) { $prefix.Dispose() }
    }
    Assert-Sharing531AppliedAndRetry $f
  }
}

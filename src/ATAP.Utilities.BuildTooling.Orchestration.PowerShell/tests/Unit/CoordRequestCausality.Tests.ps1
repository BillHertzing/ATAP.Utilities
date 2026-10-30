BeforeAll {
  $null = Get-Command -Name 'Write-PSFMessage' -ErrorAction Stop
  . (Join-Path $PSScriptRoot '../../private/Test-CoordRequestCausality.ps1')

  function ConvertTo-CausalElement {
    param([string]$Json)
    $document = [Text.Json.JsonDocument]::Parse($Json, [Text.Json.JsonDocumentOptions]::new())
    try { $document.RootElement.Clone() } finally { $document.Dispose() }
  }

  function New-CausalCandidate {
    param([string[]]$Predecessors = @(), [string]$Id = 'NEW', [string]$Resource = 'board-S17')
    $request = [ordered]@{
      resourceId = $Resource
      requestId = $Id
      predecessors = $Predecessors
    }
    ConvertTo-CausalElement ($request | ConvertTo-Json -Depth 10 -Compress)
  }

  function New-CausalRecord {
    param(
      [string]$Id,
      [string]$Status = 'Applied',
      [string[]]$Predecessors = @(),
      [string]$Resource = 'board-S17',
      [switch]$NoEdges
    )
    # Deliberate graph projection; upstream schema/digest/provenance are assumed.
    $request = [ordered]@{ resourceId = $Resource; requestId = $Id }
    if (-not $NoEdges) { $request.predecessors = $Predecessors }
    [ordered]@{ request = $request; status = $Status }
  }

  function New-CausalSnapshot {
    param([object[]]$Records = @())
    ConvertTo-CausalElement (ConvertTo-Json -InputObject $Records -Depth 20 -Compress)
  }
}

Describe 'Test-CoordRequestCausality bounded graph observation' -Tag 'Unit' {
  BeforeEach { Mock Write-PSFMessage {} }

  It 'returns NeedsFurtherValidation for empty or all-Applied predecessors' -ForEach @(
    @{ Kind = 'empty' }, @{ Kind = 'all Applied' }
  ) {
    $ids = @(if ($Kind -ne 'empty') { 'B'; 'A' })
    $request = New-CausalCandidate -Predecessors $ids
    $snapshot = New-CausalSnapshot -Records @((New-CausalRecord 'B'), (New-CausalRecord 'A'))
    $before = $request.GetRawText() + $snapshot.GetRawText()
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Stage | Should -BeExactly 'CausalityCheckedNotAdmitted'
    $result.Decision | Should -BeExactly 'NeedsFurtherValidation'
    $result.PredecessorIds.Count | Should -Be 0
    $result.Boundary | Should -Match 'category/claim compatibility'
    ($request.GetRawText() + $snapshot.GetRawText()) | Should -BeExactly $before
    foreach ($field in @('Eligible', 'Accepted', 'Durable', 'Granted', 'Status')) {
      $result.PSObject.Properties.Name | Should -Not -Contain $field
    }
  }

  It 'never waits for missing IDs and returns all winning direct IDs in ordinal order' {
    $request = New-CausalCandidate -Predecessors @('z', 'pending', '2', 'foreign', 'a', 'A', '10')
    $snapshot = New-CausalSnapshot -Records @(
      (New-CausalRecord 'pending' 'Pending'),
      (New-CausalRecord 'foreign' -Resource 'another-resource')
    )
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'MissingPredecessor'
    ($result.PredecessorIds -join ',') | Should -BeExactly '10,2,A,a,z'
  }

  It 'prioritizes direct self and every other cyclic branch over missing and foreign IDs' {
    $request = New-CausalCandidate -Predecessors @('missing', 'NEW', 'foreign', 'Cycle', 'pending', 'rejected')
    $snapshot = New-CausalSnapshot -Records @(
      (New-CausalRecord 'Cycle' 'Pending' @('Loop')),
      (New-CausalRecord 'Loop' 'Pending' @('Cycle')),
      (New-CausalRecord 'foreign' -Resource 'elsewhere'),
      (New-CausalRecord 'pending' 'Pending'),
      (New-CausalRecord 'rejected' 'Rejected')
    )
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'CausalCycle'
    ($result.PredecessorIds -join ',') | Should -BeExactly 'Cycle,NEW'
  }

  It 'reports direct branch roots rather than internal cycle vertex IDs' {
    $request = New-CausalCandidate -Predecessors @('zRoot', 'ARoot')
    $snapshot = New-CausalSnapshot -Records @(
      (New-CausalRecord 'zRoot' 'Pending' @('internalA')),
      (New-CausalRecord 'ARoot' 'Pending' @('internalA')),
      (New-CausalRecord 'internalA' 'Pending' @('internalB')),
      (New-CausalRecord 'internalB' 'Pending' @('internalA'))
    )
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'CausalCycle'
    ($result.PredecessorIds -join ',') | Should -BeExactly 'ARoot,zRoot'
  }

  It 'detects a reachable back edge to the candidate even when no candidate record exists' {
    $request = New-CausalCandidate -Predecessors @('A')
    $snapshot = New-CausalSnapshot -Records @((New-CausalRecord 'A' 'Pending' @('NEW')))
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'CausalCycle'
    ($result.PredecessorIds -join ',') | Should -BeExactly 'A'
  }

  It 'maps shared transitive missing targets to all directly declared affected roots' {
    $request = New-CausalCandidate -Predecessors @('B', 'A', 'foreignRoot')
    $snapshot = New-CausalSnapshot -Records @(
      (New-CausalRecord 'A' 'Pending' @('lost')),
      (New-CausalRecord 'B' 'Pending' @('lost')),
      (New-CausalRecord 'foreignRoot' 'Pending' @('foreign')),
      (New-CausalRecord 'foreign' -Resource 'elsewhere')
    )
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'MissingPredecessor'
    ($result.PredecessorIds -join ',') | Should -BeExactly 'A,B'
  }

  It 'classifies foreign targets only when no exact same-resource record exists' {
    $request = New-CausalCandidate -Predecessors @('B', 'A')
    $snapshot = New-CausalSnapshot -Records @(
      (New-CausalRecord 'A' -Resource 'elsewhere'),
      (New-CausalRecord 'B'),
      (New-CausalRecord 'B' -Resource 'elsewhere')
    )
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'ForeignPredecessor'
    ($result.PredecessorIds -join ',') | Should -BeExactly 'A'
  }

  It 'uses ordinal case-sensitive predecessor and resource identities' -ForEach @(
    @{ Kind = 'ID'; ExpectedDecision = 'MissingPredecessor' },
    @{ Kind = 'resource'; ExpectedDecision = 'ForeignPredecessor' }
  ) {
    $request = New-CausalCandidate -Predecessors @('A')
    $records = if ($Kind -eq 'ID') {
      @((New-CausalRecord 'a'))
    } else {
      @((New-CausalRecord 'A' -Resource 'board-s17'))
    }
    $snapshot = New-CausalSnapshot -Records $records
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly $ExpectedDecision
    ($result.PredecessorIds -join ',') | Should -BeExactly 'A'
  }

  It 'does not traverse authentic Rejected historical <History> edges' -ForEach @(
    @{ History = 'self' }, @{ History = 'missing' }, @{ History = 'foreign' }, @{ History = 'absent' }
  ) {
    $request = New-CausalCandidate -Predecessors @('old')
    $old = switch ($History) {
      'self' { New-CausalRecord 'old' 'Rejected' @('old') }
      'missing' { New-CausalRecord 'old' 'Rejected' @('not-arrived') }
      'foreign' { New-CausalRecord 'old' 'Rejected' @('foreign') }
      'absent' { New-CausalRecord 'old' 'Rejected' -NoEdges }
    }
    $snapshot = New-CausalSnapshot -Records @($old, (New-CausalRecord 'foreign' -Resource 'another-resource'))
    $before = $snapshot.GetRawText()
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'PredecessorFailed'
    ($result.PredecessorIds -join ',') | Should -BeExactly 'old'
    $snapshot.GetRawText() | Should -BeExactly $before
  }

  It 'prioritizes every direct Rejected predecessor before any waiting status' {
    $request = New-CausalCandidate -Predecessors @('zRejected', 'waiting', 'ARejected', 'recovery')
    $snapshot = New-CausalSnapshot -Records @(
      (New-CausalRecord 'zRejected' 'Rejected' @('not-arrived')),
      (New-CausalRecord 'waiting' 'Pending'),
      (New-CausalRecord 'ARejected' 'Rejected' @('ARejected')),
      (New-CausalRecord 'recovery' 'NeedsRecovery')
    )
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'PredecessorFailed'
    ($result.PredecessorIds -join ',') | Should -BeExactly 'ARejected,zRejected'
  }

  It 'observes <Status> waiting without claiming durable Pending or settled compatibility' -ForEach @(
    @{ Status = 'Pending' }, @{ Status = 'Prepared' }, @{ Status = 'NeedsRecovery' }
  ) {
    $request = New-CausalCandidate -Predecessors @('wait')
    $snapshot = New-CausalSnapshot -Records @((New-CausalRecord 'wait' $Status))
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'WaitingForPredecessor'
    ($result.PredecessorIds -join ',') | Should -BeExactly 'wait'
    $result.Stage | Should -BeExactly 'CausalityCheckedNotAdmitted'
    $result.Boundary | Should -Match 'category/claim compatibility'
    $result.PSObject.Properties.Name | Should -Not -Contain 'Status'
  }

  It 'does not mistake a shared acyclic descendant for a cycle' {
    $request = New-CausalCandidate -Predecessors @('root')
    $snapshot = New-CausalSnapshot -Records @(
      (New-CausalRecord 'root' 'Pending' @('left', 'right')),
      (New-CausalRecord 'left' 'Applied' @('shared')),
      (New-CausalRecord 'right' 'Applied' @('shared')),
      (New-CausalRecord 'shared')
    )
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'WaitingForPredecessor'
  }

  It 'does not follow rejected descendants or reclassify a direct Pending predecessor from their invalid history' {
    $request = New-CausalCandidate -Predecessors @('pending')
    $snapshot = New-CausalSnapshot -Records @(
      (New-CausalRecord 'pending' 'Pending' @('rejected')),
      (New-CausalRecord 'rejected' 'Rejected' @('missing', 'rejected'))
    )
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'WaitingForPredecessor'
    ($result.PredecessorIds -join ',') | Should -BeExactly 'pending'
  }

  It 'does not perform a global audit of unrelated cycles or ambiguous unrelated vertices' {
    $request = New-CausalCandidate -Predecessors @('A')
    $snapshot = New-CausalSnapshot -Records @(
      (New-CausalRecord 'A'),
      (New-CausalRecord 'X' 'Pending' @('Y')),
      (New-CausalRecord 'Y' 'Pending' @('X')),
      (New-CausalRecord 'unused'),
      (New-CausalRecord 'unused')
    )
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'NeedsFurtherValidation'
  }

  It 'holds malformed reachable <Damage> instead of waiting or inventing success' -ForEach @(
    @{ Damage = 'duplicate identity' }, @{ Damage = 'unknown status' },
    @{ Damage = 'missing edge list' }, @{ Damage = 'duplicate edge' }
  ) {
    $request = New-CausalCandidate -Predecessors @('A')
    $records = switch ($Damage) {
      'duplicate identity' { @((New-CausalRecord 'A'), (New-CausalRecord 'A')) }
      'unknown status' { @((New-CausalRecord 'A' 'Deleted')) }
      'missing edge list' { @((New-CausalRecord 'A' 'Pending' -NoEdges)) }
      'duplicate edge' { @((New-CausalRecord 'A' 'Pending' @('B', 'B')), (New-CausalRecord 'B')) }
    }
    $snapshot = New-CausalSnapshot -Records $records
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'NeedsRecovery'
    $result.PredecessorIds.Count | Should -Be 0
  }

  It 'checks the expected resource before inspecting an invalid retained container' {
    $request = New-CausalCandidate -Predecessors @('A')
    $snapshot = ConvertTo-CausalElement '"not-an-array"'
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-s17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'ResourceMismatch'
  }

  It 'fails duplicate candidate IDs at its input boundary rather than converting them to a wait' {
    $request = New-CausalCandidate -Predecessors @('A', 'A')
    $snapshot = New-CausalSnapshot -Records @((New-CausalRecord 'A' 'Pending'))
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'InvalidInput'
  }

  It 'reports all waiting direct IDs in ordinal order while preserving request and record order' {
    $request = New-CausalCandidate -Predecessors @('z', 'a', 'Z', 'done')
    $snapshot = New-CausalSnapshot -Records @(
      (New-CausalRecord 'z' 'NeedsRecovery'),
      (New-CausalRecord 'a' 'Pending'),
      (New-CausalRecord 'Z' 'Prepared'),
      (New-CausalRecord 'done')
    )
    $before = $request.GetRawText() + $snapshot.GetRawText()
    $result = Test-CoordRequestCausality -Request $request -ExpectedResourceId 'board-S17' -RetainedRecords $snapshot
    $result.Decision | Should -BeExactly 'WaitingForPredecessor'
    ($result.PredecessorIds -join ',') | Should -BeExactly 'Z,a,z'
    ($request.GetRawText() + $snapshot.GetRawText()) | Should -BeExactly $before
  }
}

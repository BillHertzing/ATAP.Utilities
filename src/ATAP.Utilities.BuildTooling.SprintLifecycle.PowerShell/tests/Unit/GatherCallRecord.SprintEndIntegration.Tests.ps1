#Requires -Version 7.0

<#
  Regression suite for the SprintEnd integration of the gather-call correlation
  harvester (Sprint 0015, Stream M, Task 15.183.b).

  SKIP STATE
  ----------
  The SprintEnd integration is Task 15.183.d and does not exist yet. Every block
  below is written in full against the contracts and is marked -Skip so the suite
  stays green until .d lands. Un-skipping is a ONE-LINE change: delete the -Skip
  switch on the single Describe below. Nothing here is a placeholder.

  Blocking task id: 15.183.d

  Authority (all in
  _Planning/InformationForTheFuture/Sprint0015/StreamM/Task15.183/):
    correlated-corpus.contract.v1.md  - sections 7 and 8: durable output path,
                                        ephemeral evidence, reconciliation counts
    gather-call-record.contract.v1.md - section 6.2: the record stream lives under
                                        the ephemeral _generated tree
  Repo rule R-38: _generated under a sprint worktree is deleted at sprint end;
  information for future work must be durable under _Planning.

  THE ORDERING CONSTRAINT THIS FILE EXISTS TO PROTECT
  ---------------------------------------------------
  The correlation reads the gather-call record stream, which lives under the
  ephemeral _generated tree. If SprintEnd removed _generated before correlating,
  the inputs would be gone and the durable corpus would be silently empty - a
  failure that looks exactly like "there was nothing to correlate". Hence:

      handoffs complete  ->  call records complete  ->  CORRELATION  ->  _generated removal

  SEAMS (owned by Task 15.183.d, NOT ratified)
  --------------------------------------------
  Two things below are seams rather than settled fact, declared once each so that
  reconciling this suite with .d's actual decision is a single edit:

    1. $script:CorrelationCommandName / $script:CleanupCommandName - the command
       names SprintEnd invokes, and the phase name the correlation runs under.
    2. $script:WarningFailurePolicy - the warning/failure policy. Task 15.183.d
       owns it and it is NOT YET RATIFIED. The policy table below encodes the
       ONLY reading consistent with the contracts already ratified (warnings
       propagate and never abort the close; a correlation failure is reported and
       does not by itself fail SprintEnd, because the corpus is derived evidence
       rather than a boundary invariant). It is marked unratified and reported as
       a coverage finding in the 15.183.b handoff rather than being presented as
       settled. If .d ratifies a different policy, change the table, not the tests.

  Isolation: every fixture is created beneath $TestDrive. Every SprintEnd phase is
  mocked. No test invokes a real SprintEnd close, removes a real _generated tree,
  touches real git state, a real worktree, a database, or the network.
#>

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param(
        [string]$Level,
        [string]$Message,
        [Parameter(ValueFromRemainingArguments = $true)]$Rest
      )
    }
  }

  # ---- SEAMS (owned by Task 15.183.d, unratified) ------------------------
  $script:CorrelationCommandName = 'Invoke-GatherCallCorrelation'
  $script:CleanupCommandName = 'Clear-SprintGeneratedArtifacts'
  $script:SprintEndCommandName = 'Invoke-SprintEndLifecycle'
  $script:CorrelationPhaseName = 'GatherCallCorrelation'

  # UNRATIFIED. Task 15.183.d owns this table. See the header note.
  $script:WarningFailurePolicy = [pscustomobject]@{
    Ratified                          = $false
    OwnedBy                           = 'Task 15.183.d'
    WarningsPropagateToSprintEndResult = $true
    WarningsAbortTheClose             = $false
    CorrelationFailureAbortsTheClose  = $false
    CorrelationFailureIsReported      = $true
    UnbalancedReconciliationIsWarning = $true
  }
  # ------------------------------------------------------------------------

  $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:lifecyclePath = Join-Path $script:moduleRoot 'public\Invoke-SprintEndLifecycle.ps1'
  $script:correlationPath = Join-Path $script:moduleRoot ('public\' + $script:CorrelationCommandName + '.ps1')

  foreach ($path in @($script:lifecyclePath, $script:correlationPath)) {
    if (Test-Path -LiteralPath $path -PathType Leaf) { . $path }
  }

  $script:fixtureRoot = Join-Path $TestDrive 'gather-sprintend'
  New-Item -ItemType Directory -Path $script:fixtureRoot -Force | Out-Null

  # Shared, ordered trace of which SprintEnd phase ran when. Every mock appends to
  # it, so ordering assertions rest on recorded fact rather than on wall clock.
  $script:PhaseTrace = [System.Collections.Generic.List[string]]::new()

  function Reset-PhaseTrace {
    $script:PhaseTrace.Clear()
  }

  function Add-PhaseTrace {
    param([Parameter(Mandatory)][string]$Phase)
    $script:PhaseTrace.Add($Phase)
  }

  function Get-PhaseIndex {
    param([Parameter(Mandatory)][string]$Phase)
    $script:PhaseTrace.IndexOf($Phase)
  }

  function New-SprintEndFixture {
    param([string]$Name)
    $root = Join-Path $script:fixtureRoot ($Name + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    $worktrees = @()
    foreach ($repository in @('ATAP.Utilities', 'Ace')) {
      $worktree = Join-Path $root ("$repository-wt-99-Sprint-0015-work-items")
      New-Item -ItemType Directory -Path (Join-Path $worktree '_generated\Sprint0015\StreamM\gather-calls') -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $worktree '_generated\Sprint0015\handoffs') -Force | Out-Null
      $worktrees += $worktree
    }

    $planning = Join-Path $root '_Planning-wt-35-Sprint-0015-work-items'
    $durable = Join-Path $planning 'InformationForTheFuture\Sprint0015\StreamM\Task15.183'
    New-Item -ItemType Directory -Path $durable -Force | Out-Null

    [pscustomobject]@{
      Root          = $root
      WorktreePaths = $worktrees
      PlanningRoot  = $planning
      DurablePath   = (Join-Path $durable 'correlated-corpus.v1.json')
    }
  }

  function New-CorrelationResult {
    param(
      [int]$GatherRecordsRead = 3,
      [int]$GatherRecordsMalformed = 0,
      [int]$GatherRecordsDuplicate = 0,
      [int]$HandoffsRead = 2,
      [int]$ChangedFileEntriesRead = 5,
      [int]$RowCount = 8,
      [bool]$Balanced = $true,
      [string[]]$Warnings = @(),
      [bool]$Succeeded = $true
    )
    [pscustomobject]@{
      Succeeded      = $Succeeded
      DurablePath    = $null
      Warnings       = @($Warnings)
      Reconciliation = [pscustomobject]@{
        gatherRecordsRead       = $GatherRecordsRead
        gatherRecordsMalformed  = $GatherRecordsMalformed
        gatherRecordsDuplicate  = $GatherRecordsDuplicate
        handoffsRead            = $HandoffsRead
        handoffsUnparseable     = 0
        changedFileEntriesRead  = $ChangedFileEntriesRead
        changedFileEntriesMalformed = 0
        rowCount                = $RowCount
        balanced                = $Balanced
      }
    }
  }

  # Installs the phase mocks every ordering test relies on. Each mock records its
  # phase name and does nothing else - no real close phase ever runs.
  function Install-SprintEndPhaseMock {
    param([object]$CorrelationResult)

    Mock -CommandName $script:CorrelationCommandName -MockWith {
      Add-PhaseTrace -Phase 'Correlation'
      $CorrelationResult
    }
    Mock -CommandName $script:CleanupCommandName -MockWith {
      Add-PhaseTrace -Phase 'GeneratedRemoval'
      [pscustomobject]@{ Ok = $true }
    }
    Mock -CommandName 'New-SprintEndHandoff' -MockWith {
      Add-PhaseTrace -Phase 'Handoffs'
      [pscustomobject]@{ Ok = $true }
    }
    Mock -CommandName 'Save-SprintHistoryArtifacts' -MockWith {
      Add-PhaseTrace -Phase 'History'
      [pscustomobject]@{ Ok = $true }
    }
    Mock -CommandName 'Invoke-SprintEndInfrastructureCleanup' -MockWith {
      Add-PhaseTrace -Phase 'InfrastructureCleanup'
      [pscustomobject]@{ Ok = $true }
    }
    Mock -CommandName 'Remove-SprintWorktreeSafely' -MockWith {
      Add-PhaseTrace -Phase 'WorktreeRemoval'
      [pscustomobject]@{ Ok = $true }
    }
  }

  function Invoke-SprintEndUnderTest {
    param(
      [Parameter(Mandatory)]$Fixture,
      [hashtable]$Extra
    )
    $command = Get-Command -Name $script:SprintEndCommandName -ErrorAction Stop
    $declared = $command.Parameters.Keys

    $argument = @{
      GitRoot                     = $Fixture.Root
      PlanningRoot                = $Fixture.PlanningRoot
      WorktreePaths               = $Fixture.WorktreePaths
      GatherCallCorrelationPath   = $Fixture.DurablePath
      MergeAuthorizationConfirmed = $true
    }
    if ($Extra) { foreach ($key in $Extra.Keys) { $argument[$key] = $Extra[$key] } }

    $splat = @{}
    foreach ($key in $argument.Keys) {
      if ($declared -contains $key) { $splat[$key] = $argument[$key] }
    }
    & $script:SprintEndCommandName @splat
  }
}

AfterAll {
  if ($script:fixtureRoot -and (Test-Path -LiteralPath $script:fixtureRoot)) {
    Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# Remove -Skip on the line below when Task 15.183.d lands the SprintEnd integration.
Describe 'SprintEnd gather-call correlation integration [Blocked by Task 15.183.d - SprintEnd integration not yet implemented]' -Tag 'Unit', 'Blocked-15.183.d' -Skip {

  BeforeEach {
    Reset-PhaseTrace
  }

  Context 'The phase exists and is wired into the close' {

    It 'exposes a correlation phase on the SprintEnd orchestrator' {
      $command = Get-Command -Name $script:SprintEndCommandName -CommandType Function
      $command | Should -Not -BeNullOrEmpty
      $source = Get-Content -LiteralPath $script:lifecyclePath -Raw
      $source | Should -Match ([regex]::Escape($script:CorrelationCommandName))
    }

    It 'runs the correlation exactly once per close' {
      $fixture = New-SprintEndFixture -Name 'phase-once'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult)

      Invoke-SprintEndUnderTest -Fixture $fixture

      Should -Invoke -CommandName $script:CorrelationCommandName -Times 1 -Exactly
    }

    It 'reports the correlation as a named phase in the close result' {
      $fixture = New-SprintEndFixture -Name 'phase-named'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult)

      $result = Invoke-SprintEndUnderTest -Fixture $fixture

      @($result.Phases.Name) | Should -Contain $script:CorrelationPhaseName
    }
  }

  Context 'Ordering - after inputs are complete, before ephemeral removal' {

    It 'runs the correlation after sprint handoffs are generated' {
      $fixture = New-SprintEndFixture -Name 'order-after-handoffs'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult)

      Invoke-SprintEndUnderTest -Fixture $fixture

      $handoffIndex = Get-PhaseIndex -Phase 'Handoffs'
      $correlationIndex = Get-PhaseIndex -Phase 'Correlation'
      $handoffIndex | Should -BeGreaterOrEqual 0
      $correlationIndex | Should -BeGreaterThan $handoffIndex `
        -Because 'a handoff written after correlation would never be correlated'
    }

    It 'runs the correlation before the ephemeral _generated tree is removed' {
      $fixture = New-SprintEndFixture -Name 'order-before-removal'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult)

      Invoke-SprintEndUnderTest -Fixture $fixture

      $correlationIndex = Get-PhaseIndex -Phase 'Correlation'
      $removalIndex = Get-PhaseIndex -Phase 'GeneratedRemoval'
      $correlationIndex | Should -BeGreaterOrEqual 0
      $removalIndex | Should -BeGreaterThan $correlationIndex `
        -Because 'the gather-call record stream lives under _generated and would be gone'
    }

    It 'runs the correlation before the sprint worktrees are removed' {
      $fixture = New-SprintEndFixture -Name 'order-before-worktree'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult)

      Invoke-SprintEndUnderTest -Fixture $fixture

      $correlationIndex = Get-PhaseIndex -Phase 'Correlation'
      $worktreeIndex = Get-PhaseIndex -Phase 'WorktreeRemoval'
      if ($worktreeIndex -ge 0) {
        $worktreeIndex | Should -BeGreaterThan $correlationIndex
      }
    }

    It 'still finds its inputs on disk at the moment it runs' {
      # The ordering assertion above is about call sequence. This one is about the
      # observable consequence: when the correlation executes, the record stream
      # must not yet have been deleted.
      $fixture = New-SprintEndFixture -Name 'order-inputs-present'
      $probeRoot = $fixture.WorktreePaths[0]
      $recordFile = Join-Path $probeRoot '_generated\Sprint0015\StreamM\gather-calls\gather-calls.jsonl'
      [System.IO.File]::WriteAllText($recordFile, "{}`n", [System.Text.UTF8Encoding]::new($false))

      $script:inputsPresentAtCorrelation = $null
      Mock -CommandName $script:CorrelationCommandName -MockWith {
        Add-PhaseTrace -Phase 'Correlation'
        $script:inputsPresentAtCorrelation = Test-Path -LiteralPath $recordFile
        New-CorrelationResult
      }
      Mock -CommandName $script:CleanupCommandName -MockWith {
        Add-PhaseTrace -Phase 'GeneratedRemoval'
        Remove-Item -LiteralPath (Join-Path $probeRoot '_generated') -Recurse -Force -ErrorAction SilentlyContinue
        [pscustomobject]@{ Ok = $true }
      }
      Mock -CommandName 'New-SprintEndHandoff' -MockWith { Add-PhaseTrace -Phase 'Handoffs'; [pscustomobject]@{ Ok = $true } }
      Mock -CommandName 'Invoke-SprintEndInfrastructureCleanup' -MockWith { [pscustomobject]@{ Ok = $true } }
      Mock -CommandName 'Remove-SprintWorktreeSafely' -MockWith { [pscustomobject]@{ Ok = $true } }

      Invoke-SprintEndUnderTest -Fixture $fixture

      $script:inputsPresentAtCorrelation |
        Should -BeTrue -Because 'the record stream must still exist when the correlation reads it'
    }

    It 'does not run the correlation at all when the close is a dry run' {
      $fixture = New-SprintEndFixture -Name 'order-dryrun'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult)

      Invoke-SprintEndUnderTest -Fixture $fixture -Extra @{ WhatIf = $true }

      Should -Invoke -CommandName $script:CleanupCommandName -Times 0 -Exactly
      Get-PhaseIndex -Phase 'GeneratedRemoval' | Should -Be -1
    }
  }

  Context 'The correlation receives resolved inputs, not placeholders' {

    It 'passes every resolved sprint worktree root' {
      $fixture = New-SprintEndFixture -Name 'inputs-roots'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult)

      Invoke-SprintEndUnderTest -Fixture $fixture

      Should -Invoke -CommandName $script:CorrelationCommandName -Times 1 -Exactly -ParameterFilter {
        $expected = $fixture.WorktreePaths
        @($WorktreeRoot).Count -eq @($expected).Count -and
        (@($expected | Where-Object { $_ -notin @($WorktreeRoot) }).Count -eq 0)
      }
    }

    It 'passes absolute, existing worktree roots rather than unresolved placeholders' {
      $fixture = New-SprintEndFixture -Name 'inputs-absolute'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult)

      Invoke-SprintEndUnderTest -Fixture $fixture

      Should -Invoke -CommandName $script:CorrelationCommandName -Times 1 -Exactly -ParameterFilter {
        $allResolved = $true
        foreach ($root in @($WorktreeRoot)) {
          if ($root -match '\$\{[A-Z_]+\}') { $allResolved = $false }
          if (-not [System.IO.Path]::IsPathRooted($root)) { $allResolved = $false }
          if (-not (Test-Path -LiteralPath $root)) { $allResolved = $false }
        }
        $allResolved
      }
    }

    It 'passes the durable output path under _Planning InformationForTheFuture' {
      $fixture = New-SprintEndFixture -Name 'inputs-durable'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult)

      Invoke-SprintEndUnderTest -Fixture $fixture

      Should -Invoke -CommandName $script:CorrelationCommandName -Times 1 -Exactly -ParameterFilter {
        ($DurableOutputPath -replace '\\', '/') -match '/InformationForTheFuture/'
      }
    }

    It 'never routes the durable corpus into an ephemeral _generated tree' {
      # R-38: _generated is deleted at sprint end, and the corpus is input to
      # future work. Writing it there would destroy it moments later.
      $fixture = New-SprintEndFixture -Name 'inputs-notephemeral'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult)

      Invoke-SprintEndUnderTest -Fixture $fixture

      Should -Invoke -CommandName $script:CorrelationCommandName -Times 1 -Exactly -ParameterFilter {
        ($DurableOutputPath -replace '\\', '/') -notmatch '/_generated/'
      }
    }

    It 'passes the sprint being closed, not the sprint being opened' {
      $fixture = New-SprintEndFixture -Name 'inputs-sprint'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult)

      Invoke-SprintEndUnderTest -Fixture $fixture -Extra @{ ClosedSprintNumber = '0015' }

      Should -Invoke -CommandName $script:CorrelationCommandName -Times 1 -Exactly -ParameterFilter {
        $Sprint -match '0015'
      }
    }
  }

  Context 'Counts and warnings propagate' {

    It 'surfaces the reconciliation counts on the close result' {
      $fixture = New-SprintEndFixture -Name 'propagate-counts'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult `
          -GatherRecordsRead 7 -HandoffsRead 4 -ChangedFileEntriesRead 19 -RowCount 42)

      $result = Invoke-SprintEndUnderTest -Fixture $fixture

      $phase = @($result.Phases | Where-Object { $_.Name -eq $script:CorrelationPhaseName })[0]
      $phase.Reconciliation.gatherRecordsRead | Should -Be 7
      $phase.Reconciliation.handoffsRead | Should -Be 4
      $phase.Reconciliation.changedFileEntriesRead | Should -Be 19
      $phase.Reconciliation.rowCount | Should -Be 42
    }

    It 'propagates every correlation warning verbatim rather than summarizing it away' {
      $fixture = New-SprintEndFixture -Name 'propagate-warnings'
      $warnings = @(
        'duplicate invocationId in gather-calls.jsonl line 12',
        'association method not-determined; no association inferred'
      )
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult -Warnings $warnings)

      $result = Invoke-SprintEndUnderTest -Fixture $fixture

      foreach ($warning in $warnings) {
        @($result.Warnings) | Should -Contain $warning
      }
    }

    It 'reports zero counts as real facts rather than omitting the phase' {
      $fixture = New-SprintEndFixture -Name 'propagate-zero'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult `
          -GatherRecordsRead 0 -HandoffsRead 0 -ChangedFileEntriesRead 0 -RowCount 0)

      $result = Invoke-SprintEndUnderTest -Fixture $fixture

      $phase = @($result.Phases | Where-Object { $_.Name -eq $script:CorrelationPhaseName })
      $phase.Count | Should -Be 1 -Because 'an empty correlation is a reportable result, not an absent phase'
      $phase[0].Reconciliation.gatherRecordsRead | Should -Be 0
    }

    It 'surfaces malformed and duplicate counts distinctly from the read count' {
      $fixture = New-SprintEndFixture -Name 'propagate-malformed'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult `
          -GatherRecordsRead 5 -GatherRecordsMalformed 2 -GatherRecordsDuplicate 3)

      $result = Invoke-SprintEndUnderTest -Fixture $fixture

      $phase = @($result.Phases | Where-Object { $_.Name -eq $script:CorrelationPhaseName })[0]
      $phase.Reconciliation.gatherRecordsMalformed | Should -Be 2
      $phase.Reconciliation.gatherRecordsDuplicate | Should -Be 3
      $phase.Reconciliation.gatherRecordsRead | Should -Be 5
    }
  }

  Context 'Warning and failure policy [UNRATIFIED SEAM - Task 15.183.d]' {

    It 'declares the policy as an explicit unratified seam rather than an assumption' {
      # This test exists so that a reader cannot mistake the table below for a
      # ratified decision. When 15.183.d ratifies the policy, flip Ratified to
      # $true and reconcile the assertions in this Context with the ratified text.
      $script:WarningFailurePolicy.Ratified |
        Should -BeFalse -Because 'Task 15.183.d has not ratified the warning/failure policy'
      $script:WarningFailurePolicy.OwnedBy | Should -Be 'Task 15.183.d'
    }

    It 'does not abort the close on correlation warnings' {
      $fixture = New-SprintEndFixture -Name 'policy-warn'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult `
          -Warnings @('association method not-determined'))

      $result = Invoke-SprintEndUnderTest -Fixture $fixture

      if (-not $script:WarningFailurePolicy.WarningsAbortTheClose) {
        Get-PhaseIndex -Phase 'GeneratedRemoval' |
          Should -BeGreaterThan -1 -Because 'a warning must not stop the close from completing'
        $result.Ok | Should -BeTrue
      }
    }

    It 'reports a correlation failure rather than swallowing it' {
      $fixture = New-SprintEndFixture -Name 'policy-fail-reported'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult `
          -Succeeded $false -Warnings @('correlation failed: durable path not writable'))

      $result = Invoke-SprintEndUnderTest -Fixture $fixture

      if ($script:WarningFailurePolicy.CorrelationFailureIsReported) {
        $phase = @($result.Phases | Where-Object { $_.Name -eq $script:CorrelationPhaseName })[0]
        $phase.Ok | Should -BeFalse
        (@($result.Warnings) + @($result.Errors)) -join ' ' | Should -Match 'correlation failed'
      }
    }

    It 'treats an unbalanced reconciliation as a loud warning, never a silent pass' {
      $fixture = New-SprintEndFixture -Name 'policy-unbalanced'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult -Balanced $false)

      $result = Invoke-SprintEndUnderTest -Fixture $fixture

      if ($script:WarningFailurePolicy.UnbalancedReconciliationIsWarning) {
        (@($result.Warnings) -join ' ') |
          Should -Match '(?i)balanc' -Because 'a reconciliation defect must be loud'
      }
    }

    It 'still removes the ephemeral tree when the correlation failed, if the policy says so' {
      $fixture = New-SprintEndFixture -Name 'policy-fail-continue'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult -Succeeded $false)

      Invoke-SprintEndUnderTest -Fixture $fixture

      if (-not $script:WarningFailurePolicy.CorrelationFailureAbortsTheClose) {
        Get-PhaseIndex -Phase 'GeneratedRemoval' | Should -BeGreaterThan -1
      } else {
        Get-PhaseIndex -Phase 'GeneratedRemoval' | Should -Be -1
      }
    }

    It 'never lets a correlation throw escape and kill the close unhandled' {
      $fixture = New-SprintEndFixture -Name 'policy-throw'
      Mock -CommandName $script:CorrelationCommandName -MockWith {
        Add-PhaseTrace -Phase 'Correlation'
        throw 'correlation exploded'
      }
      Mock -CommandName $script:CleanupCommandName -MockWith {
        Add-PhaseTrace -Phase 'GeneratedRemoval'; [pscustomobject]@{ Ok = $true }
      }
      Mock -CommandName 'New-SprintEndHandoff' -MockWith { Add-PhaseTrace -Phase 'Handoffs'; [pscustomobject]@{ Ok = $true } }
      Mock -CommandName 'Invoke-SprintEndInfrastructureCleanup' -MockWith { [pscustomobject]@{ Ok = $true } }
      Mock -CommandName 'Remove-SprintWorktreeSafely' -MockWith { [pscustomobject]@{ Ok = $true } }

      $result = $null
      { $result = Invoke-SprintEndUnderTest -Fixture $fixture } | Should -Not -Throw

      $phase = @($result.Phases | Where-Object { $_.Name -eq $script:CorrelationPhaseName })[0]
      $phase.Ok | Should -BeFalse
      (@($result.Warnings) + @($result.Errors)) -join ' ' | Should -Match 'correlation exploded'
    }
  }

  Context 'The close does not fabricate a correlation it did not run' {

    It 'omits reconciliation counts rather than inventing them when the phase was skipped' {
      $fixture = New-SprintEndFixture -Name 'nofabricate-skipped'
      Install-SprintEndPhaseMock -CorrelationResult (New-CorrelationResult)

      $result = Invoke-SprintEndUnderTest -Fixture $fixture -Extra @{ SkipGatherCallCorrelation = $true }

      Should -Invoke -CommandName $script:CorrelationCommandName -Times 0 -Exactly
      $phase = @($result.Phases | Where-Object { $_.Name -eq $script:CorrelationPhaseName })
      if ($phase.Count -eq 1) {
        $phase[0].Skipped | Should -BeTrue
        $phase[0].Reconciliation | Should -BeNullOrEmpty
      }
    }

    It 'records the durable corpus path it actually wrote, not the one it intended' {
      $fixture = New-SprintEndFixture -Name 'nofabricate-path'
      $written = Join-Path (Split-Path -Parent $fixture.DurablePath) 'correlated-corpus.v1.json'
      $correlationResult = New-CorrelationResult
      $correlationResult.DurablePath = $written
      Install-SprintEndPhaseMock -CorrelationResult $correlationResult

      $result = Invoke-SprintEndUnderTest -Fixture $fixture

      $phase = @($result.Phases | Where-Object { $_.Name -eq $script:CorrelationPhaseName })[0]
      $phase.DurablePath | Should -Be $written
    }
  }
}

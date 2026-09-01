# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ tests for Test-SprintCheckpointCoverage conversation-state classification.
#
# SC-0327: a roster row used to satisfy coverage purely by worktree name plus a
# reachable archive file. Neither fact says the archive holds THAT worktree's
# session, and the reported failure was exactly a row that passed both checks while
# its archive held an unrelated session's conversation. These tests pin the
# classification that distinguishes the three cases.

BeforeAll {
  $functionPath = Join-Path $PSScriptRoot '..\..\public\Test-SprintCheckpointCoverage.ps1'
  if (-not (Test-Path $functionPath)) {
    throw "Function file not found: $functionPath"
  }
  if (-not (Get-Module -Name PSFramework -ErrorAction SilentlyContinue)) {
    Import-Module PSFramework -ErrorAction SilentlyContinue
  }
  . $functionPath

  $script:sprintNumber = 15
  $script:fixtureRoots = [System.Collections.Generic.List[string]]::new()

  # Builds a Planning root holding one roster row plus the archive and memory
  # directories that row points at, so only the conversation fields vary per case.
  function script:New-CoverageFixture {
    param(
      [Parameter(Mandatory)][hashtable]$ConversationFields
    )

    $planRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('tscc-' + [guid]::NewGuid().ToString('N'))
    # Registered for the AfterEach backstop: the per-test `finally` blocks below are
    # the normal path, but a failure between creation and `try` would otherwise leak
    # a fixture into the system temporary directory (sprint-boundary isolation
    # contract).
    [void]$script:fixtureRoots.Add($planRoot)
    $worktreePath = Join-Path $planRoot 'ATAP.Utilities-wt-137-Sprint-0015-work-items'
    $convRoot = Join-Path $planRoot 'SprintWorkSessionConversations'
    $memRoot = Join-Path $planRoot 'SprintWorkSessionMemorys'
    $rosterDir = Join-Path $planRoot 'SprintWorkSessionRoster'
    New-Item -ItemType Directory -Path $worktreePath, $convRoot, $memRoot, $rosterDir -Force | Out-Null

    $archivePath = Join-Path $convRoot 'SprintWorkSession-0015-Conversation-x.7z'
    Set-Content -LiteralPath $archivePath -Value 'archive-bytes' -Encoding UTF8
    $memPath = Join-Path $memRoot 'SprintWorkSession-0015-x'
    New-Item -ItemType Directory -Path $memPath -Force | Out-Null

    $entry = [ordered]@{
      SprintN                    = '0015'
      RecordedAt                 = (Get-Date).ToString('o')
      Agent                      = 'ClaudeCode'
      WorktreeName               = 'ATAP.Utilities-wt-137-Sprint-0015-work-items'
      ConversationArchivePath    = $archivePath
      ConversationArchiveCreated = $true
      MemorySnapshotPath         = $memPath
      MemorySnapshotCreated      = $true
      MemoryFileCount            = 3
    }
    foreach ($k in $ConversationFields.Keys) { $entry[$k] = $ConversationFields[$k] }

    $rosterPath = Join-Path $rosterDir 'SprintWorkSessionRoster-0015.jsonl'
    Set-Content -LiteralPath $rosterPath -Value ($entry | ConvertTo-Json -Compress) -Encoding UTF8

    return [pscustomobject]@{ PlanRoot = $planRoot; WorktreePath = $worktreePath }
  }

  function script:Invoke-Coverage {
    param([Parameter(Mandatory)]$Fixture)
    Test-SprintCheckpointCoverage `
      -PlanningRoot $Fixture.PlanRoot `
      -SprintNumber $script:sprintNumber `
      -WorktreePaths @($Fixture.WorktreePath)
  }
}

Describe 'Test-SprintCheckpointCoverage — SC-0327 conversation state' {

  # Pester rejects a teardown directly in the block container, so this lives inside
  # the Describe rather than at file scope.
  AfterEach {
    foreach ($root in $script:fixtureRoots) {
      Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
    $script:fixtureRoots.Clear()
  }

  It 'accepts a row whose transcript was chosen by session id' {
    $fixture = script:New-CoverageFixture -ConversationFields @{
      ConversationSelectionRule = 'EnvironmentSessionId'
      ConversationSkipKind      = $null
    }
    try {
      $r = script:Invoke-Coverage -Fixture $fixture
      $r.PerWorktree[0].ConversationState | Should -Be 'VerifiedSession'
      $r.PerWorktree[0].Ok | Should -BeTrue
      $r.Ok | Should -BeTrue
    } finally {
      Remove-Item -Recurse -Force $fixture.PlanRoot -ErrorAction SilentlyContinue
    }
  }

  It 'accepts a cross-store session-id selection — the normal cross-repository shape' {
    $fixture = script:New-CoverageFixture -ConversationFields @{
      ConversationSelectionRule = 'SessionIdCrossStore'
      ConversationSkipKind      = $null
    }
    try {
      $r = script:Invoke-Coverage -Fixture $fixture
      $r.PerWorktree[0].ConversationState | Should -Be 'VerifiedSession'
      $r.Ok | Should -BeTrue
    } finally {
      Remove-Item -Recurse -Force $fixture.PlanRoot -ErrorAction SilentlyContinue
    }
  }

  It 'marks a newest-mtime selection Unverified without failing coverage' {
    # Agents that expose no session id legitimately land here; failing would strand
    # them. It must still be distinguishable from a verified capture.
    $fixture = script:New-CoverageFixture -ConversationFields @{
      ConversationSelectionRule = 'NewestInProjectStore'
      ConversationSkipKind      = 'Ambiguous'
    }
    try {
      $r = script:Invoke-Coverage -Fixture $fixture
      $r.PerWorktree[0].ConversationState | Should -Be 'UnverifiedSession'
      $r.PerWorktree[0].Ok | Should -BeTrue
    } finally {
      Remove-Item -Recurse -Force $fixture.PlanRoot -ErrorAction SilentlyContinue
    }
  }

  It 'fails coverage when the row records that no conversation was captured' {
    $fixture = script:New-CoverageFixture -ConversationFields @{
      ConversationSelectionRule = 'EnvironmentSessionId'
      ConversationSkipKind      = 'NotFound'
      ConversationSkipReason    = "No transcript named 'abc.jsonl' found under any project store."
    }
    try {
      $r = script:Invoke-Coverage -Fixture $fixture
      $r.PerWorktree[0].ConversationState | Should -Be 'NotCaptured'
      $r.PerWorktree[0].Ok | Should -BeFalse
      $r.Ok | Should -BeFalse
      ($r.Failures -join ' ') | Should -Match 'archived no conversation'
    } finally {
      Remove-Item -Recurse -Force $fixture.PlanRoot -ErrorAction SilentlyContinue
    }
  }

  It 'classifies a legacy row with no selection rule as Unrecorded, not as verified' {
    # Rosters written before SC-0327 carry none of these fields. Such a row must not
    # be silently promoted to 'verified' -- that is the claim that was wrong -- but it
    # also must not retroactively fail an already-closed sprint.
    $fixture = script:New-CoverageFixture -ConversationFields @{}
    try {
      $r = script:Invoke-Coverage -Fixture $fixture
      $r.PerWorktree[0].ConversationState | Should -Be 'Unrecorded'
      $r.PerWorktree[0].Ok | Should -BeTrue
    } finally {
      Remove-Item -Recurse -Force $fixture.PlanRoot -ErrorAction SilentlyContinue
    }
  }
}

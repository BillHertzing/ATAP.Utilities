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
      ConversationFileCount      = 2
      ConversationArchiveEntryCount = 3
      ConversationArchiveSha256  = 'CONVERSATION-HASH'
      MemorySnapshotPath         = $memPath
      MemorySnapshotCreated      = $true
      MemoryFileCount            = 3
      MemoryArchiveEntryCount    = 4
      MemoryArchiveSha256        = 'MEMORY-HASH'
    }
    foreach ($k in $ConversationFields.Keys) { $entry[$k] = $ConversationFields[$k] }

    $rosterPath = Join-Path $rosterDir 'SprintWorkSessionRoster-0015.jsonl'
    Set-Content -LiteralPath $rosterPath -Value ($entry | ConvertTo-Json -Compress) -Encoding UTF8

    return [pscustomobject]@{ PlanRoot = $planRoot; WorktreePath = $worktreePath; Entry = [pscustomobject]$entry }
  }

  function script:Invoke-Coverage {
    param(
      [Parameter(Mandatory)]$Fixture,
      [switch]$NoEvidence,
      [object[]]$Evidence,
      [object]$Override
    )
    if (-not $NoEvidence -and -not $PSBoundParameters.ContainsKey('Evidence')) {
      $replicas = @(
        [pscustomobject]@{
          Kind = 'Primary'; Path = 'C:\CorpusFixture\conversation.7z'; Status = 'Present'
          VerifiedSha256 = 'CONVERSATION-HASH'; VerifiedAtUtc = $Fixture.Entry.RecordedAt
        },
        [pscustomobject]@{
          Kind = 'DropboxMirror'; Path = 'C:\CorpusMirrorFixture\conversation.7z'; Status = 'CopiedLocally'
          VerifiedSha256 = 'CONVERSATION-HASH'; VerifiedAtUtc = $Fixture.Entry.RecordedAt
        }
      )
      $memoryReplicas = @(
        [pscustomobject]@{
          Kind = 'Primary'; Path = 'C:\CorpusFixture\memory.7z'; Status = 'Present'
          VerifiedSha256 = 'MEMORY-HASH'; VerifiedAtUtc = $Fixture.Entry.RecordedAt
        },
        [pscustomobject]@{
          Kind = 'DropboxMirror'; Path = 'C:\CorpusMirrorFixture\memory.7z'; Status = 'CopiedLocally'
          VerifiedSha256 = 'MEMORY-HASH'; VerifiedAtUtc = $Fixture.Entry.RecordedAt
        }
      )
      $Evidence = @([pscustomobject]@{
          WorktreeName = $Fixture.Entry.WorktreeName
          CheckpointRecordedAt = $Fixture.Entry.RecordedAt
          ManifestRecordedAtUtc = $Fixture.Entry.RecordedAt
          Artifacts = @(
            [pscustomobject]@{ Kind = 'Conversation'; ArchiveSha256 = 'CONVERSATION-HASH'; Replicas = $replicas },
            [pscustomobject]@{ Kind = 'Memory'; ArchiveSha256 = 'MEMORY-HASH'; Replicas = $memoryReplicas }
          )
        })
    }
    $parameters = @{
      PlanningRoot = $Fixture.PlanRoot
      SprintNumber = $script:sprintNumber
      WorktreePaths = @($Fixture.WorktreePath)
      ExternalDurabilityEvidence = @($Evidence)
    }
    if ($null -ne $Override) { $parameters.ExternalDurabilityOverride = $Override }
    Test-SprintCheckpointCoverage @parameters
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

  It 'fails closed when external corpus evidence is unavailable' {
    $fixture = script:New-CoverageFixture -ConversationFields @{
      ConversationSelectionRule = 'EnvironmentSessionId'
    }
    try {
      $r = script:Invoke-Coverage -Fixture $fixture -NoEvidence
      $r.Ok | Should -BeFalse
      $r.PerWorktree[0].ExternalDurabilityState | Should -Be 'Failed'
      ($r.Failures -join ' ') | Should -Match 'evidence is unavailable'
    } finally {
      Remove-Item -Recurse -Force $fixture.PlanRoot -ErrorAction SilentlyContinue
    }
  }

  It 'rejects a stale manifest row even when replica hashes match' {
    $fixture = script:New-CoverageFixture -ConversationFields @{
      ConversationSelectionRule = 'EnvironmentSessionId'
    }
    try {
      $evidence = @([pscustomobject]@{
          WorktreeName = $fixture.Entry.WorktreeName
          CheckpointRecordedAt = $fixture.Entry.RecordedAt
          ManifestRecordedAtUtc = '2000-01-01T00:00:00Z'
          Artifacts = @()
        })
      $r = script:Invoke-Coverage -Fixture $fixture -Evidence $evidence
      $r.Ok | Should -BeFalse
      ($r.PerWorktree[0].ExternalDurabilityFailures -join ' ') | Should -Match 'manifest evidence is stale'
    } finally {
      Remove-Item -Recurse -Force $fixture.PlanRoot -ErrorAction SilentlyContinue
    }
  }

  It 'rejects a partial replica set' {
    $fixture = script:New-CoverageFixture -ConversationFields @{
      ConversationSelectionRule = 'EnvironmentSessionId'
      MemorySnapshotCreated = $false
      MemorySkipReason = 'Agent has no on-disk memory store.'
    }
    try {
      $evidence = @([pscustomobject]@{
          WorktreeName = $fixture.Entry.WorktreeName
          CheckpointRecordedAt = $fixture.Entry.RecordedAt
          ManifestRecordedAtUtc = $fixture.Entry.RecordedAt
          Artifacts = @([pscustomobject]@{
              Kind = 'Conversation'
              ArchiveSha256 = 'CONVERSATION-HASH'
              Replicas = @([pscustomobject]@{
                  Kind = 'Primary'; Path = 'C:\CorpusFixture\conversation.7z'; Status = 'Present'
                  VerifiedSha256 = 'CONVERSATION-HASH'; VerifiedAtUtc = '2026-09-09T20:00:00Z'
                })
            })
        })
      $r = script:Invoke-Coverage -Fixture $fixture -Evidence $evidence
      $r.Ok | Should -BeFalse
      ($r.PerWorktree[0].ExternalDurabilityFailures -join ' ') | Should -Match 'DropboxMirror replica'
    } finally {
      Remove-Item -Recurse -Force $fixture.PlanRoot -ErrorAction SilentlyContinue
    }
  }

  It 'records a named operator override without erasing failed evidence checks' {
    $fixture = script:New-CoverageFixture -ConversationFields @{
      ConversationSelectionRule = 'EnvironmentSessionId'
    }
    try {
      $override = [pscustomobject]@{
        OperatorName = 'bill.hertzing'
        Reason = 'Accepted temporary corpus outage for this exact close.'
        RecordedAtUtc = '2026-09-09T21:00:00Z'
      }
      $r = script:Invoke-Coverage -Fixture $fixture -NoEvidence -Override $override
      $r.Ok | Should -BeTrue
      $r.PerWorktree[0].ExternalDurabilityState | Should -Be 'OperatorOverride'
      $r.PerWorktree[0].ExternalDurabilityFailures | Should -Not -BeNullOrEmpty
      $r.PerWorktree[0].OperatorOverride.OperatorName | Should -Be 'bill.hertzing'
    } finally {
      Remove-Item -Recurse -Force $fixture.PlanRoot -ErrorAction SilentlyContinue
    }
  }
}

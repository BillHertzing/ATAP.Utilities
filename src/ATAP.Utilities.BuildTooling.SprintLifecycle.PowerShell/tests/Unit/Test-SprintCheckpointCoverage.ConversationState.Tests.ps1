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
  $script:fixtureBase = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../_generated/Sprint0016/Task16.41/MemoryArchiveContract/Fixtures'))

  function script:Remove-CoverageFixture {
    param([Parameter(Mandatory)][string]$Path)

    $resolved = [IO.Path]::GetFullPath($Path).TrimEnd(
      [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    )
    $prefix = $script:fixtureBase.TrimEnd(
      [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    ) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Fixture cleanup escaped the owned generated root.'
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
  }

  # Builds one roster row with nonempty conversation and memory archive stand-ins.
  # Archive integrity is the producer's contract; these tests cover reachability.
  function script:New-CoverageFixture {
    param(
      [Parameter(Mandatory)][hashtable]$ConversationFields
    )

    $planRoot = Join-Path $script:fixtureBase ('tscc-' + [guid]::NewGuid().ToString('N'))
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
    $memPath = Join-Path $memRoot 'SprintWorkSession-0015-Memory-x.7z'
    Set-Content -LiteralPath $memPath -Value 'memory-archive-stand-in' -Encoding UTF8

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
      MemoryFileCount            = 1
      MemoryArchiveByteCount     = (Get-Item -LiteralPath $memPath).Length
      MemoryArchiveEntryCount    = 2
      MemoryArchiveSha256        = (Get-FileHash -LiteralPath $memPath -Algorithm SHA256).Hash
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
          VerifiedSha256 = $Fixture.Entry.MemoryArchiveSha256; VerifiedAtUtc = $Fixture.Entry.RecordedAt
        },
        [pscustomobject]@{
          Kind = 'DropboxMirror'; Path = 'C:\CorpusMirrorFixture\memory.7z'; Status = 'CopiedLocally'
          VerifiedSha256 = $Fixture.Entry.MemoryArchiveSha256; VerifiedAtUtc = $Fixture.Entry.RecordedAt
        }
      )
      $Evidence = @([pscustomobject]@{
          WorktreeName = $Fixture.Entry.WorktreeName
          CheckpointRecordedAt = $Fixture.Entry.RecordedAt
          ManifestRecordedAtUtc = $Fixture.Entry.RecordedAt
          Artifacts = @(
            [pscustomobject]@{ Kind = 'Conversation'; ArchiveSha256 = 'CONVERSATION-HASH'; Replicas = $replicas },
            [pscustomobject]@{ Kind = 'Memory'; ArchiveSha256 = $Fixture.Entry.MemoryArchiveSha256; Replicas = $memoryReplicas }
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
      script:Remove-CoverageFixture -Path $root
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
      script:Remove-CoverageFixture -Path $fixture.PlanRoot
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
      script:Remove-CoverageFixture -Path $fixture.PlanRoot
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
      script:Remove-CoverageFixture -Path $fixture.PlanRoot
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
      script:Remove-CoverageFixture -Path $fixture.PlanRoot
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
      script:Remove-CoverageFixture -Path $fixture.PlanRoot
    }
  }

  It 'fails closed when external corpus evidence is unavailable' {
    $fixture = script:New-CoverageFixture -ConversationFields @{
      ConversationSelectionRule = 'EnvironmentSessionId'
    }
    try {
      $r = script:Invoke-Coverage -Fixture $fixture -NoEvidence
      $r.Ok | Should -BeFalse
      $r.PerWorktree[0].MemoryState | Should -Be 'CanonicalMemory'
      $r.PerWorktree[0].ExternalDurabilityState | Should -Be 'Failed'
      ($r.Failures -join ' ') | Should -Match 'evidence is unavailable'
    } finally {
      script:Remove-CoverageFixture -Path $fixture.PlanRoot
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
      script:Remove-CoverageFixture -Path $fixture.PlanRoot
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
      script:Remove-CoverageFixture -Path $fixture.PlanRoot
    }
  }

  It 'accepts a producer-shaped nonempty canonical memory archive' {
    $fixture = script:New-CoverageFixture -ConversationFields @{}
    try {
      $fixture.Entry.MemorySnapshotPath | Should -Match '\.7z$'
      $fixture.Entry.MemoryArchiveByteCount | Should -BeGreaterThan 0
      $fixture.Entry.MemoryArchiveByteCount | Should -Be (Get-Item -LiteralPath $fixture.Entry.MemorySnapshotPath).Length
      $fixture.Entry.MemoryArchiveSha256 | Should -Be (Get-FileHash -LiteralPath $fixture.Entry.MemorySnapshotPath -Algorithm SHA256).Hash
      $r = script:Invoke-Coverage -Fixture $fixture
      $r.PerWorktree[0].MemoryState | Should -Be 'CanonicalMemory'
      $r.Ok | Should -BeTrue
    } finally {
      script:Remove-CoverageFixture -Path $fixture.PlanRoot
    }
  }

  It 'rejects <Case> memory instead of treating it as a canonical archive' -TestCases @(
    @{ Case = 'missing' }, @{ Case = 'empty' }, @{ Case = 'directory' },
    @{ Case = 'outside-root' }, @{ Case = 'sibling-prefix' }, @{ Case = 'unset-path' }
  ) {
    param($Case)
    $fixture = script:New-CoverageFixture -ConversationFields @{}
    try {
      $memoryPath = $fixture.Entry.MemorySnapshotPath
      switch ($Case) {
        'missing' { Remove-Item -LiteralPath $memoryPath -Force }
        'empty' { [IO.File]::WriteAllBytes($memoryPath, [byte[]]::new(0)) }
        'directory' {
          Remove-Item -LiteralPath $memoryPath -Force
          New-Item -ItemType Directory -Path $memoryPath | Out-Null
        }
        'outside-root' {
          $fixture.Entry.MemorySnapshotPath = Join-Path $fixture.PlanRoot 'outside.7z'
          Move-Item -LiteralPath $memoryPath -Destination $fixture.Entry.MemorySnapshotPath
        }
        'sibling-prefix' {
          $sibling = Join-Path $fixture.PlanRoot 'SprintWorkSessionMemorys-sibling'
          New-Item -ItemType Directory -Path $sibling | Out-Null
          $fixture.Entry.MemorySnapshotPath = Join-Path $sibling 'memory.7z'
          Move-Item -LiteralPath $memoryPath -Destination $fixture.Entry.MemorySnapshotPath
        }
        'unset-path' { $fixture.Entry.MemorySnapshotPath = '' }
      }
      $rosterPath = Join-Path $fixture.PlanRoot 'SprintWorkSessionRoster/SprintWorkSessionRoster-0015.jsonl'
      Set-Content -LiteralPath $rosterPath -Value ($fixture.Entry | ConvertTo-Json -Compress) -Encoding UTF8
      $r = script:Invoke-Coverage -Fixture $fixture
      $r.PerWorktree[0].MemoryState | Should -Be 'MissingCanonicalMemory'
      $r.PerWorktree[0].ExternalDurabilityState | Should -Be 'Verified'
      $r.Ok | Should -BeFalse
      ($r.Failures -join ' ') | Should -Match 'canonical memory root'
    } finally {
      script:Remove-CoverageFixture -Path $fixture.PlanRoot
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
      script:Remove-CoverageFixture -Path $fixture.PlanRoot
    }
  }
}

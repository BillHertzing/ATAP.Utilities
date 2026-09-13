function Test-SprintCheckpointCoverage {
  <#
  .SYNOPSIS
  Verifies agent-neutral SprintEnd checkpoint coverage.

  .DESCRIPTION
  Reads the canonical Planning roster and verifies that every selected sprint
  worktree has a latest entry whose conversation archive is reachable beneath
  SprintWorkSessionConversations, and that the archive actually holds that
  worktree's session (ConversationState; see SC-0327). Memory is accepted beneath
  SprintWorkSessionMemorys when the agent supports a memory snapshot. Because the
  raw archives are intentionally ignored by git, coverage also requires injected
  external-durability evidence for every required artifact. No live corpus or
  database call is made by this function.

  .PARAMETER PlanningRoot
  Active or stable Planning repository containing canonical checkpoint data.

  .PARAMETER SprintNumber
  Sprint number whose roster is audited.

  .PARAMETER WorktreePaths
  Worktrees that require a discoverable final checkpoint.

  .PARAMETER ExternalDurabilityEvidence
  Snapshot evidence supplied by a future corpus adapter. Each row identifies one
  worktree/checkpoint and contains Artifacts with archive hashes plus verified
  Replicas. This function consumes the contract but never discovers or mutates a
  corpus itself.

  .PARAMETER RequiredExternalReplicaKind
  Replica kinds that every required conversation or memory artifact must have.

  .PARAMETER ExternalDurabilityOverride
  Explicit exception record containing OperatorName, Reason, and RecordedAtUtc.
  A valid named override permits teardown while preserving the failed evidence
  checks in the returned result.

  .PARAMETER ThrowOnFailure
  Throws when any worktree lacks canonical checkpoint coverage.

  .OUTPUTS
  PSCustomObject containing per-worktree coverage and failures.

  .EXAMPLE
  Test-SprintCheckpointCoverage -PlanningRoot C:\Repos\_Planning-wt-20-Sprint-0010-work-items `
    -SprintNumber 10 -WorktreePaths $worktreePaths -ThrowOnFailure

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$PlanningRoot,

    [Parameter(Mandatory)]
    [ValidateRange(1, 9999)]
    [int]$SprintNumber,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorktreePaths,

    [Parameter()]
    [object[]]$ExternalDurabilityEvidence = @(),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$RequiredExternalReplicaKind = @('Primary', 'DropboxMirror'),

    [Parameter()]
    [object]$ExternalDurabilityOverride,

    [Parameter()]
    [switch]$ThrowOnFailure
  )

  begin {
    $fn = 'Test-SprintCheckpointCoverage'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $planningRootFull = [IO.Path]::GetFullPath($PlanningRoot)
    $sprintText = '{0:D4}' -f $SprintNumber
    $conversationRoot = Join-Path $planningRootFull 'SprintWorkSessionConversations'
    $memoryRoot = Join-Path $planningRootFull 'SprintWorkSessionMemorys'
    $rosterPath = Join-Path $planningRootFull `
      "SprintWorkSessionRoster\SprintWorkSessionRoster-$sprintText.jsonl"
    $failures = [System.Collections.Generic.List[string]]::new()
    $rosterEntries = [System.Collections.Generic.List[object]]::new()
    $overrideValid = $false
    if ($null -ne $ExternalDurabilityOverride) {
      $overrideTime = [datetimeoffset]::MinValue
      $overrideValid = (
        -not [string]::IsNullOrWhiteSpace([string]$ExternalDurabilityOverride.OperatorName) -and
        -not [string]::IsNullOrWhiteSpace([string]$ExternalDurabilityOverride.Reason) -and
        [datetimeoffset]::TryParse([string]$ExternalDurabilityOverride.RecordedAtUtc, [ref]$overrideTime)
      )
      if (-not $overrideValid) {
        [void]$failures.Add('External durability override is invalid; OperatorName, Reason, and RecordedAtUtc are required.')
      }
    }

    if (Test-Path -LiteralPath $rosterPath -PathType Leaf) {
      $lineNumber = 0
      foreach ($line in Get-Content -LiteralPath $rosterPath) {
        $lineNumber++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
          [void]$rosterEntries.Add(($line | ConvertFrom-Json -ErrorAction Stop))
        } catch {
          [void]$failures.Add("Roster line $lineNumber is not valid JSON.")
        }
      }
    } else {
      [void]$failures.Add("Sprint roster not found: $rosterPath")
    }

    $perWorktree = foreach ($worktreePath in $WorktreePaths) {
      $worktreeName = Split-Path -Path $worktreePath -Leaf
      $latest = @($rosterEntries |
          Where-Object { $_.WorktreeName -eq $worktreeName } |
          Sort-Object { [datetimeoffset]$_.RecordedAt } -Descending |
          Select-Object -First 1)
      if ($latest.Count -eq 0) {
        [void]$failures.Add("$worktreeName has no roster entry for Sprint $sprintText.")
        [PSCustomObject]@{
          WorktreeName = $worktreeName
          Agent = $null
          RecordedAt = $null
          ConversationArchiveReachable = $false
          ConversationState = 'MissingRosterEntry'
          ConversationSelectionRule = $null
          MemoryState = 'MissingRosterEntry'
          Ok = $false
        }
        continue
      }

      $entry = $latest[0]
      $archivePath = [string]$entry.ConversationArchivePath
      $archiveReachable = $false
      if (-not [string]::IsNullOrWhiteSpace($archivePath)) {
        $archiveFull = [IO.Path]::GetFullPath($archivePath)
        $archiveReachable = (
          $archiveFull.StartsWith(
            [IO.Path]::GetFullPath($conversationRoot),
            [StringComparison]::OrdinalIgnoreCase
          ) -and
          (Test-Path -LiteralPath $archiveFull -PathType Leaf) -and
          ((Get-Item -LiteralPath $archiveFull).Length -gt 0)
        )
      }
      if (-not $archiveReachable) {
        [void]$failures.Add(
          "$worktreeName latest checkpoint archive is not reachable beneath the canonical conversation root."
        )
      }

      # SC-0327: a reachable archive proves a FILE was written, not that it holds
      # THIS worktree's session. Before transcript selection was pinned to the
      # invoking session id, a row could satisfy coverage by worktree name while its
      # archive held an unrelated session's conversation. Save-SprintWorkSession now
      # records which rule chose the transcript, so classify that here instead of
      # accepting any archive as equivalent.
      #   VerifiedSession   -> chosen by session id; the row covers the session it names
      #   UnverifiedSession -> chosen by newest-mtime; may be a different session
      #   NotCaptured       -> the session's transcript was not found; nothing archived
      #   Unrecorded        -> a legacy row written before the rule was recorded
      $conversationState = if ($entry.PSObject.Properties.Name -notcontains 'ConversationSelectionRule' -or
        [string]::IsNullOrWhiteSpace([string]$entry.ConversationSelectionRule)) {
        'Unrecorded'
      } elseif ([string]$entry.ConversationSkipKind -eq 'NotFound') {
        'NotCaptured'
      } elseif ([string]$entry.ConversationSelectionRule -in @('ExplicitSessionId', 'EnvironmentSessionId', 'SessionIdCrossStore')) {
        'VerifiedSession'
      } else {
        'UnverifiedSession'
      }

      if ($conversationState -eq 'NotCaptured') {
        [void]$failures.Add(
          "$worktreeName latest checkpoint archived no conversation: $([string]$entry.ConversationSkipReason)"
        )
      } elseif ($conversationState -eq 'UnverifiedSession') {
        # Not a failure: agents that expose no session id legitimately land here, and
        # failing would strand them. But it must be visible, because the archive cannot
        # be assumed to be the session this row names.
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "$worktreeName latest checkpoint selected its transcript by '$([string]$entry.ConversationSelectionRule)'; the archived conversation is not confirmed to be that worktree's session."
      }

      $memoryState = if ([bool]$entry.MemorySnapshotCreated) {
        $memoryPath = [string]$entry.MemorySnapshotPath
        $memoryFull = if ([string]::IsNullOrWhiteSpace($memoryPath)) {
          $null
        } else {
          [IO.Path]::GetFullPath($memoryPath)
        }
        $memoryReachable = (
          $null -ne $memoryFull -and
          $memoryFull.StartsWith(
            [IO.Path]::GetFullPath($memoryRoot),
            [StringComparison]::OrdinalIgnoreCase
          ) -and
          (Test-Path -LiteralPath $memoryFull -PathType Container)
        )
        if (-not $memoryReachable) {
          [void]$failures.Add(
            "$worktreeName latest memory snapshot is not reachable beneath the canonical memory root."
          )
          'MissingCanonicalMemory'
        } else {
          'CanonicalMemory'
        }
      } elseif (-not [string]::IsNullOrWhiteSpace([string]$entry.MemorySkipReason)) {
        'AgentHasNoMemorySnapshot'
      } else {
        'MemoryNotCaptured'
      }

      $externalFailures = [System.Collections.Generic.List[string]]::new()
      $entryRecordedAt = [datetimeoffset]$entry.RecordedAt
      $evidenceRows = @($ExternalDurabilityEvidence | Where-Object {
          $candidateRecordedAt = [datetimeoffset]::MinValue
          [string]($_.WorktreeName) -eq $worktreeName -and
          [datetimeoffset]::TryParse([string]($_.CheckpointRecordedAt), [ref]$candidateRecordedAt) -and
          $candidateRecordedAt -eq $entryRecordedAt
        })
      $evidence = if ($evidenceRows.Count -eq 1) { $evidenceRows[0] } else { $null }
      if ($evidenceRows.Count -eq 0) {
        [void]$externalFailures.Add('matching external-durability evidence is unavailable')
      } elseif ($evidenceRows.Count -gt 1) {
        [void]$externalFailures.Add('external-durability evidence is ambiguous')
      }

      $requiredArtifacts = [System.Collections.Generic.List[object]]::new()
      [void]$requiredArtifacts.Add([PSCustomObject]@{
          Kind = 'Conversation'
          Sha256 = [string]$entry.ConversationArchiveSha256
        })
      if ([bool]$entry.MemorySnapshotCreated) {
        [void]$requiredArtifacts.Add([PSCustomObject]@{
            Kind = 'Memory'
            Sha256 = [string]$entry.MemoryArchiveSha256
          })
      }

      if ($null -ne $evidence) {
        $checkpointTime = [datetimeoffset]::MinValue
        $manifestTime = [datetimeoffset]::MinValue
        $checkpointTimeValid = [datetimeoffset]::TryParse([string]$entry.RecordedAt, [ref]$checkpointTime)
        $manifestTimeValid = [datetimeoffset]::TryParse([string]$evidence.ManifestRecordedAtUtc, [ref]$manifestTime)
        if (-not $checkpointTimeValid -or -not $manifestTimeValid -or $manifestTime -lt $checkpointTime) {
          [void]$externalFailures.Add('manifest evidence is stale or has an invalid timestamp')
        }

        foreach ($requiredArtifact in $requiredArtifacts) {
          if ([string]::IsNullOrWhiteSpace($requiredArtifact.Sha256)) {
            [void]$externalFailures.Add("$($requiredArtifact.Kind) roster hash is absent")
            continue
          }
          $artifactRows = @($evidence.Artifacts | Where-Object { [string]($_.Kind) -eq $requiredArtifact.Kind })
          if ($artifactRows.Count -ne 1) {
            [void]$externalFailures.Add("$($requiredArtifact.Kind) evidence count is $($artifactRows.Count), expected 1")
            continue
          }
          $artifact = $artifactRows[0]
          if ([string]$artifact.ArchiveSha256 -ne $requiredArtifact.Sha256) {
            [void]$externalFailures.Add("$($requiredArtifact.Kind) evidence hash does not match the checkpoint roster")
          }
          foreach ($replicaKind in $RequiredExternalReplicaKind) {
            $replicas = @($artifact.Replicas | Where-Object { [string]($_.Kind) -eq $replicaKind })
            $matchingReplica = @($replicas | Where-Object {
                $replicaVerifiedAt = [datetimeoffset]::MinValue
                $replicaPath = [string]($_.Path)
                $replicaPathIsExternal = $false
                if ([IO.Path]::IsPathRooted($replicaPath)) {
                  $replicaFullPath = [IO.Path]::GetFullPath($replicaPath)
                  $blockedRoots = @($planningRootFull) + @($WorktreePaths | ForEach-Object {
                      [IO.Path]::GetFullPath($_)
                    })
                  $replicaPathIsExternal = -not @($blockedRoots | Where-Object {
                      $blockedRoot = $_.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
                      $replicaFullPath.StartsWith($blockedRoot, [StringComparison]::OrdinalIgnoreCase)
                    })
                }
                [string]($_.Status) -in @('Present', 'CopiedLocally') -and
                $replicaPathIsExternal -and
                [string]($_.VerifiedSha256) -eq $requiredArtifact.Sha256 -and
                [datetimeoffset]::TryParse([string]($_.VerifiedAtUtc), [ref]$replicaVerifiedAt) -and
                $replicaVerifiedAt -ge $entryRecordedAt
              })
            if ($matchingReplica.Count -ne 1) {
              [void]$externalFailures.Add("$($requiredArtifact.Kind) has no unique hash-verified $replicaKind replica")
            }
          }
        }
      }

      $externalDurabilityState = if ($externalFailures.Count -eq 0) {
        'Verified'
      } elseif ($overrideValid) {
        'OperatorOverride'
      } else {
        foreach ($externalFailure in $externalFailures) {
          [void]$failures.Add("$worktreeName external durability failed: $externalFailure.")
        }
        'Failed'
      }

      [PSCustomObject]@{
        WorktreeName = $worktreeName
        Agent = $entry.Agent
        RecordedAt = $entry.RecordedAt
        ConversationArchivePath = $archivePath
        ConversationArchiveReachable = $archiveReachable
        ConversationState = $conversationState
        ConversationSelectionRule = [string]$entry.ConversationSelectionRule
        MemoryState = $memoryState
        GitDurability = 'RosterMetadataOnly'
        RawArtifactsGitTracked = $false
        ExternalDurabilityState = $externalDurabilityState
        ExternalDurabilityFailures = $externalFailures.ToArray()
        OperatorOverride = if ($externalDurabilityState -eq 'OperatorOverride') { $ExternalDurabilityOverride } else { $null }
        Ok = ($archiveReachable -and $conversationState -ne 'NotCaptured' -and $memoryState -notin @(
            'MissingCanonicalMemory',
            'MemoryNotCaptured'
          ) -and $externalDurabilityState -in @('Verified', 'OperatorOverride'))
      }
    }

    $result = [PSCustomObject]@{
      Ok               = ($failures.Count -eq 0)
      SprintNumber     = $sprintText
      RosterPath       = $rosterPath
      CanonicalRoots   = [PSCustomObject]@{
        Conversations = $conversationRoot
        Memory        = $memoryRoot
        Roster        = Split-Path -Path $rosterPath -Parent
      }
      PerWorktree      = @($perWorktree)
      Failures         = $failures.ToArray()
    }
    if (-not $result.Ok -and $ThrowOnFailure) {
      throw "Sprint checkpoint coverage failed: $($result.Failures -join '; ')"
    }
    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

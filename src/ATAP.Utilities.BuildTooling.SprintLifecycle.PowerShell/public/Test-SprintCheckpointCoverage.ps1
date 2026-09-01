function Test-SprintCheckpointCoverage {
  <#
  .SYNOPSIS
  Verifies agent-neutral SprintEnd checkpoint coverage.

  .DESCRIPTION
  Reads the canonical Planning roster and verifies that every selected sprint
  worktree has a latest entry whose conversation archive is reachable beneath
  SprintWorkSessionConversations, and that the archive actually holds that
  worktree's session (ConversationState; see SC-0327). Memory is accepted beneath
  SprintWorkSessionMemorys when the agent supports a memory snapshot. No
  Claude-, Codex-, Copilot-, or Antigravity-local path is needed for discovery.

  .PARAMETER PlanningRoot
  Active or stable Planning repository containing canonical checkpoint data.

  .PARAMETER SprintNumber
  Sprint number whose roster is audited.

  .PARAMETER WorktreePaths
  Worktrees that require a discoverable final checkpoint.

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

      [PSCustomObject]@{
        WorktreeName = $worktreeName
        Agent = $entry.Agent
        RecordedAt = $entry.RecordedAt
        ConversationArchivePath = $archivePath
        ConversationArchiveReachable = $archiveReachable
        ConversationState = $conversationState
        ConversationSelectionRule = [string]$entry.ConversationSelectionRule
        MemoryState = $memoryState
        Ok = ($archiveReachable -and $conversationState -ne 'NotCaptured' -and $memoryState -notin @(
            'MissingCanonicalMemory',
            'MemoryNotCaptured'
          ))
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

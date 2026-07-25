function New-CheckpointNameComponents {
    <#
.SYNOPSIS
    Composes collision-free conversation-archive and memory-snapshot base names
    for a sprint checkpoint.

.DESCRIPTION
    Save-SprintWorkSession and Save-CopilotCheckpoint both write two artifacts
    per checkpoint into the shared _Planning worktree: a conversation archive
    (SprintWorkSessionConversations\*.7z) and a memory snapshot folder
    (SprintWorkSessionMemorys\<name>\). Before this helper existed, both names
    were derived only from the sprint number, branch name, and a minute-grained
    timestamp. Two different stable repositories both on branch `main`,
    checkpointed in the same minute, produced identical names and one
    silently overwrote/collided with the other.

    This helper composes names from four ingredients so that two independent
    processes — even from different repositories that share a branch name —
    cannot collide:

      1. SprintN                      — the sprint number.
      2. A sanitized repo/worktree tag — WorktreeName (e.g. the leaf folder of
         the calling repo's working directory, such as 'ATAP.Utilities' or
         'AceCommander-wt-7-Sprint-0013-work-items'). This is the repository
         identity component; two repos on the same branch now produce
         different tags.
      3. A sanitized branch tag        — Branch, second-precision timestamp
         (yyyy-MM-dd-HHmmss) so names remain sortable by time within a given
         repo/branch pair, matching the readability of the previous format.
      4. A disambiguator               — the calling process id combined with
         a high-resolution monotonic tick count
         ([System.Diagnostics.Stopwatch]::GetTimestamp(), sub-microsecond
         resolution on Windows). This guarantees uniqueness even when four
         checkpoints are issued within the same wall-clock second, which a
         minute- or even second-grained timestamp alone cannot guarantee.

.PARAMETER SprintN
    Four-digit sprint number (e.g. '0013').

.PARAMETER WorktreeName
    Repository/worktree identity component — typically the leaf name of the
    calling repo's working directory (Split-Path -Leaf on the cwd).

.PARAMETER Branch
    Git branch name (or an agent-specific substitute tag) for the checkpoint.

.PARAMETER AgentTag
    Optional short agent label inserted between the repo tag and the branch
    tag (e.g. 'copilot'). Omit for the default ClaudeCode/Antigravity/Codex
    naming, which carries no agent segment.

.OUTPUTS
    [pscustomobject] with ConvName, MemName, RepoTag, BranchTag, Timestamp,
    and Disambiguator properties.

.EXAMPLE
    New-CheckpointNameComponents -SprintN '0013' -WorktreeName 'ATAP.Utilities' -Branch 'main'

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Sprint 0013 Task 13.20.f — checkpoint archive/memory name collisions across
    multiple stable repositories all on branch `main`.
#>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $SprintN,

        [Parameter(Mandatory = $true)]
        [string] $WorktreeName,

        [Parameter(Mandatory = $true)]
        [string] $Branch,

        [Parameter(Mandatory = $false)]
        [string] $AgentTag = ''
    )

    # Sanitize repo/worktree identity and branch into filesystem-safe, readable
    # tags. '.' becomes '-' (matches the ClaudeCode slug convention elsewhere in
    # this module) and any other non-alphanumeric/dash character is collapsed
    # to '-' so the resulting name stays a single unbroken token run.
    $repoTag = ($WorktreeName -replace '[^A-Za-z0-9\-]', '-')
    $branchTag = ($Branch -replace '[^A-Za-z0-9\-]', '-')

    # Second-precision timestamp. Coarser than this (e.g. minute-precision)
    # is what originally allowed same-minute collisions; seconds alone are
    # still not sufficient on their own (see disambiguator below) but keep
    # the name sortable-by-time within a given repo/branch pair.
    $ts = Get-Date -Format 'yyyy-MM-dd-HHmmss'

    # Disambiguator: process id + high-resolution monotonic tick count.
    # Stopwatch.GetTimestamp() is not wall-clock time — it is a monotonically
    # increasing counter at sub-microsecond resolution on Windows — so two
    # calls made microseconds apart (e.g. four checkpoints fired in the same
    # wall-clock second, or by a test loop) still resolve to different
    # disambiguator values, guaranteeing distinct names.
    $hiResTicks = [System.Diagnostics.Stopwatch]::GetTimestamp()
    $disambiguator = '{0:x}-{1:x}' -f $PID, ($hiResTicks -band 0xFFFFFF)

    $base = "SprintWorkSession-$SprintN"
    $agentSegment = if ($AgentTag) { "$AgentTag-" } else { '' }

    [pscustomobject]@{
        ConvName      = "$base-Conversation-$repoTag-$agentSegment$branchTag-$ts-$disambiguator"
        MemName       = "$base-$repoTag-$agentSegment$branchTag-$ts-$disambiguator"
        RepoTag       = $repoTag
        BranchTag     = $branchTag
        Timestamp     = $ts
        Disambiguator = $disambiguator
    }
}

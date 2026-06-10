function Save-CopilotCheckpoint {
    <#
.SYNOPSIS
    Archives a GitHub Copilot checkpoint conversation and copies memory files
    to the sprint _Planning worktree.

.DESCRIPTION
    Companion to Save-SprintWorkSession for the GitHub Copilot path.  Because
    Copilot does not write an on-disk JSONL, the caller provides a pre-written
    conversation markdown file via -ConversationFile.  The function compresses
    it with 7-zip, runs an optional memory de-duplication check, copies
    new/changed memory files, and reports results.

    Sprint number is auto-detected from the most-recent SharedVSCode sprint
    worktree found under -GitHubRoot.  The _Planning worktree is resolved using
    the same hard-stop logic as Save-SprintWorkSession: throws without
    -AllowMainFallback if no sprint worktree is found, so sprint artifacts
    never silently land in the main _Planning repo.

.PARAMETER ConversationFile
    Path to a markdown file containing the reconstructed Copilot conversation.
    The file must exist before calling this function.  Typically written by the
    AI using the create_file tool in CP-1 of the checkpoint skill.

.PARAMETER SprintN
    Four-digit sprint number (e.g. '0007').  Auto-detected from the most-recent
    SharedVSCode sprint worktree name when omitted.

.PARAMETER PlanningRoot
    Absolute path to the _Planning sprint worktree (or main _Planning repo).
    Auto-resolved from sibling directories under -GitHubRoot when omitted.

.PARAMETER GitHubRoot
    Root directory that contains all sprint worktrees.
    Defaults to C:\Dropbox\whertzing\GitHub.

.PARAMETER CopilotMemoryRoot
    Root directory where the Copilot memory tool stores persistent files.
    Defaults to the conventional path C:\Users\<username>\.copilot\memory.
    Skipped gracefully when the directory does not exist.

.PARAMETER AllowMainFallback
    When set, permits writing to the main _Planning repo when no sprint
    worktree is found.  Off by default to prevent silent misrouting.

.OUTPUTS
    [void]

.EXAMPLE
    Save-CopilotCheckpoint -ConversationFile "$env:TEMP\checkpoint-conversation-20260519-143021.md"
    # Auto-detect sprint and _Planning worktree, archive conversation, copy memory.

.EXAMPLE
    Save-CopilotCheckpoint -ConversationFile "$env:TEMP\checkpoint-conversation-20260519-143021.md" -SprintN 0007
    # Override sprint number.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    See H18 in TASKS_V3GPT5.5.md for context.
    Replaces the 6 inline CP-1…CP-6 PowerShell blocks in the checkpoint skill's
    § Copilot section, collapsing them into a single pwsh -File invocation so
    the GitHub Copilot agent requires only one terminal-approval prompt.

.LINK
    https://github.com/BillHertzing/SharedVSCode
#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $ConversationFile,

        [Parameter(Mandatory = $false)]
        [string] $SprintN = '',

        [Parameter(Mandatory = $false)]
        [string] $PlanningRoot = '',

        [Parameter(Mandatory = $false)]
        [string] $GitHubRoot = 'C:\Dropbox\whertzing\GitHub',

        [Parameter(Mandatory = $false)]
        [string] $CopilotMemoryRoot = (Join-Path $env:USERPROFILE '.copilot\memory'),

        [Parameter(Mandatory = $false)]
        [switch] $AllowMainFallback
    )

    begin {
        $fn = $MyInvocation.MyCommand.Name
        $mn = $MyInvocation.MyCommand.ModuleName
        if (-not $mn) { $mn = 'Save-CopilotCheckpoint' }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function'
    }

    process {
        try {
            # ── Validate conversation file ─────────────────────────────────────────
            if (-not (Test-Path $ConversationFile)) {
                throw "ConversationFile not found: '$ConversationFile'. Write the conversation markdown to this path before calling the script."
            }

            # ── Auto-detect sprint number from SharedVSCode worktree name ──────────
            if (-not $SprintN) {
                $svWt = Get-ChildItem $GitHubRoot -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match '^SharedVSCode-wt-\d+-[Ss]print-(\d{4})-' } |
                    Sort-Object Name -Descending |
                    Select-Object -First 1

                if ($svWt -and $svWt.Name -match '[Ss]print-(\d{4})') {
                    $SprintN = $Matches[1]
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Sprint number auto-detected from '$($svWt.Name)': $SprintN"
                } else {
                    throw "Could not auto-detect sprint number from SharedVSCode worktrees under '$GitHubRoot'. Pass -SprintN <NNNN> to override."
                }
            }

            # ── Derive branchTag from SharedVSCode worktree name ───────────────────
            $svWtForTag = Get-ChildItem $GitHubRoot -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "^SharedVSCode-wt-(.+-[Ss]print-$SprintN-.+)$" } |
                Sort-Object Name -Descending |
                Select-Object -First 1

            $branchTag = if ($svWtForTag -and $svWtForTag.Name -match '^SharedVSCode-wt-(.+)$') {
                $Matches[1]   # e.g. '42-Sprint-0007-work-items'
            } else {
                "copilot-sprint-$SprintN"
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Branch tag: $branchTag"

            # ── Auto-resolve _Planning worktree (SC-0097 fix) ──────────────────────
            if (-not $PlanningRoot) {
                $mainPlanning = Join-Path $GitHubRoot '_Planning'
                $planningWTs = @(Get-ChildItem $GitHubRoot -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match "^_Planning-wt-\d+-sprint-$SprintN(-|$)" })

                if ($planningWTs.Count -eq 1) {
                    $PlanningRoot = $planningWTs[0].FullName
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Planning worktree auto-resolved: $PlanningRoot"
                } elseif ($planningWTs.Count -gt 1) {
                    $candidates = ($planningWTs | ForEach-Object { $_.FullName }) -join ', '
                    throw "Multiple _Planning sprint worktrees matched sprint $SprintN. Pass -PlanningRoot to disambiguate: $candidates"
                } elseif ($AllowMainFallback) {
                    $PlanningRoot = $mainPlanning
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "No _Planning sprint worktree found for sprint $SprintN. -AllowMainFallback set; using main _Planning: $PlanningRoot"
                } else {
                    throw "No _Planning sprint worktree matched ^_Planning-wt-\d+-sprint-$SprintN under '$GitHubRoot'. Sprint artifacts must not land in main _Planning silently. Create the sprint worktree, pass -PlanningRoot explicitly, or re-run with -AllowMainFallback."
                }
            }

            # ── Build name components ──────────────────────────────────────────────
            $ts       = Get-Date -Format 'yyyy-MM-dd-HH-mm'
            $base     = "SprintWorkSession-$SprintN"
            $convName = "$base-Conversation-copilot-$branchTag-$ts"
            $memName  = "$base-copilot-$branchTag-$ts"

            # ── 1. Compress conversation markdown with 7-zip ───────────────────────
            $convDir = Join-Path $PlanningRoot 'SprintWorkSessionConversations'
            New-Item -ItemType Directory -Path $convDir -Force | Out-Null
            $archive = Join-Path $convDir "$convName.7z"

            if ($PSCmdlet.ShouldProcess($archive, "Archive conversation '$ConversationFile'")) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Archiving '$ConversationFile' → '$archive'"
                & 7z a $archive $ConversationFile 2>&1 | Out-Null
                if (Test-Path $archive) {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Conversation saved: $archive"
                } else {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message 'Archive not created — verify 7z is on PATH: 7z i'
                }
                Remove-Item $ConversationFile -ErrorAction SilentlyContinue
            }

            # ── 2. Memory de-duplication check and copy ────────────────────────────
            if (-not (Test-Path $CopilotMemoryRoot)) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "Memory directory not found: '$CopilotMemoryRoot' — memory copy skipped."
                return
            }

            $memSnapshotBase = Join-Path $PlanningRoot 'SprintWorkSessionMemorys'
            $lastSnap = Get-ChildItem $memSnapshotBase -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | Select-Object -First 1

            $memoryChanged = $true   # assume changed until proven otherwise
            if ($lastSnap) {
                $changed = $false
                Get-ChildItem $CopilotMemoryRoot -File -Recurse | ForEach-Object {
                    $relativeFile = $_.FullName.Substring($CopilotMemoryRoot.Length).TrimStart('\')
                    $prev = Join-Path $lastSnap.FullName $relativeFile
                    if (-not (Test-Path $prev)) {
                        $changed = $true
                    } elseif ((Get-FileHash $_.FullName).Hash -ne (Get-FileHash $prev).Hash) {
                        $changed = $true
                    }
                }
                $memoryChanged = $changed
            }

            if ($memoryChanged) {
                $snapDir = Join-Path $memSnapshotBase $memName
                if ($PSCmdlet.ShouldProcess($snapDir, "Copy memory files from '$CopilotMemoryRoot'")) {
                    New-Item -ItemType Directory -Path $snapDir -Force | Out-Null
                    Copy-Item -Path "$CopilotMemoryRoot\*" -Destination $snapDir -Recurse -Force
                    $fileCount = (Get-ChildItem $snapDir -Recurse -File -ErrorAction SilentlyContinue).Count
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Memory files saved ($fileCount files): $snapDir"
                }
            } else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Memory unchanged since last checkpoint — skipped.'
            }
        } catch {
            $errorMessage = "Save-CopilotCheckpoint failed. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function'
    }
}

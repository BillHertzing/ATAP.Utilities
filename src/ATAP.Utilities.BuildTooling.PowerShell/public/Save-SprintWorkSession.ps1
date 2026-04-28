function Save-SprintWorkSession {
    <#
.SYNOPSIS
    Archives the current Claude Code conversation JSONL and copies memory files
    for the current sprint work session.

.DESCRIPTION
    Saves a point-in-time snapshot of the active Claude Code session into the
    _Planning sprint worktree so it can be referenced later.  Two artifacts
    are produced:

      1. A 7-zip archive of the most-recent conversation JSONL found under
         ~\.claude\projects\<slug>\  →  SprintWorkSessionConversations\
      2. A copy of all current memory files from the same slug directory
         →  SprintWorkSessionMemorys\<name>\

    The sprint number is auto-detected from the current branch name
    (pattern: ^\d+-sprint-(\d{4})-.+$).  The _Planning worktree is
    auto-resolved from sibling directories matching
    ^_Planning-wt-\d+-sprint-<SprintN>; falls back to the main _Planning repo
    when no sprint worktree is found.

.PARAMETER SprintN
    Four-digit sprint number (e.g. '0006').  Auto-detected from the current
    Git branch when omitted.

.PARAMETER PlanningRoot
    Absolute path to the _Planning sprint worktree (or main _Planning repo).
    Auto-resolved from sibling directories when omitted.

.PARAMETER ClaudeProjectsRoot
    Root directory where Claude Code stores per-project sessions.
    Defaults to ~\.claude\projects.

.OUTPUTS
    [void]

.EXAMPLE
    Save-SprintWorkSession
    # Auto-detect sprint number and Planning root, then archive and copy.

.EXAMPLE
    Save-SprintWorkSession -SprintN 0006
    # Override auto-detection with sprint 0006.

.EXAMPLE
    Save-SprintWorkSession -SprintN 0006 -PlanningRoot 'C:\GitHub\_Planning-wt-12-sprint-0006-work-items'
    # Explicit sprint number and Planning root.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string] $SprintN = '',

        [Parameter(Mandatory = $false, Position = 1)]
        [string] $PlanningRoot = '',

        [Parameter(Mandatory = $false)]
        [string] $ClaudeProjectsRoot = (Join-Path $env:USERPROFILE '.claude\projects')
    )

    begin {
        $fn = $MyInvocation.MyCommand.Name
        $mn = $MyInvocation.MyCommand.ModuleName

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function'

        # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: SprintN)
        $SprintN = Get-PVal -ParameterName SprintN -originalPSBoundParameters $PSBoundParameters -dottedPath SprintN -DefaultValue $SprintN

        # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: PlanningRoot)
        $PlanningRoot = Get-PVal -ParameterName PlanningRoot -originalPSBoundParameters $PSBoundParameters -dottedPath PlanningRoot -DefaultValue $PlanningRoot

        # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: ClaudeProjectsRoot)
        $ClaudeProjectsRoot = Get-PVal -ParameterName ClaudeProjectsRoot -originalPSBoundParameters $PSBoundParameters -dottedPath ClaudeProjectsRoot -DefaultValue $ClaudeProjectsRoot
    }

    process {
        try {
            # ── Auto-detect sprint number from branch ──────────────────────────────
            $branch = & git rev-parse --abbrev-ref HEAD 2>&1
            if ($LASTEXITCODE -ne 0) { throw "Could not determine current branch: $branch" }

            if (-not $SprintN) {
                if ($branch -match '^\d+-sprint-(\d{4})-.+$') {
                    $SprintN = $Matches[1]
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Sprint number auto-detected from branch '$branch': $SprintN"
                } else {
                    throw "Current branch '$branch' is not a sprint branch (expected ^\d+-sprint-(\d{4})-.+`$). Re-run with -SprintN <NNNN> to override."
                }
            }

            # ── Auto-resolve _Planning worktree from siblings ──────────────────────
            if (-not $PlanningRoot) {
                $parentDir = Split-Path -Parent (Get-Location).Path
                $planningWTs = @(Get-ChildItem $parentDir -Directory -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -match "^_Planning-wt-\d+-sprint-$SprintN" })

                if ($planningWTs.Count -eq 1) {
                    $PlanningRoot = $planningWTs[0].FullName
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Planning worktree auto-resolved: $PlanningRoot"
                } elseif ($planningWTs.Count -gt 1) {
                    $candidates = ($planningWTs | ForEach-Object { $_.FullName }) -join ', '
                    throw "Multiple _Planning sprint worktrees match sprint $SprintN. Pass -PlanningRoot to disambiguate: $candidates"
                } else {
                    $PlanningRoot = 'C:\Dropbox\whertzing\GitHub\_Planning'
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "No _Planning sprint worktree found for sprint $SprintN. Falling back to main _Planning: $PlanningRoot"
                }
            }

            # ── Derive project slug from cwd ───────────────────────────────────────
            # Claude Code slugs the project path by lowercasing the drive letter
            # and replacing ':', '\', '_' with '-'.
            $cwd = (Get-Location).Path
            $slug = ($cwd.Substring(0, 1).ToLower() + $cwd.Substring(1)) -replace '[:\\._]', '-' -replace '^-', ''
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Slug derived from cwd '$cwd': $slug"

            # ── Find most-recent session JSONL ─────────────────────────────────────
            $sessionDir = Join-Path $ClaudeProjectsRoot $slug
            $jsonl = Get-ChildItem -Path $sessionDir -Filter '*.jsonl' -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

            if (-not $jsonl) {
                throw "No JSONL found in '$sessionDir' — verify the slug is correct. Slug derived: $slug"
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Most-recent JSONL: $($jsonl.FullName) (LastWriteTime: $($jsonl.LastWriteTime))"

            # ── Build name components ──────────────────────────────────────────────
            $ts = Get-Date -Format 'yyyy-MM-dd-HH-mm'
            $base = "SprintWorkSession-$SprintN"
            $convName = "$base-Conversation-$branch-$ts"
            $memName = "$base-$branch-$ts"

            # ── 1. Compress conversation JSONL with 7-zip ──────────────────────────
            $convDir = Join-Path $PlanningRoot 'SprintWorkSessionConversations'
            New-Item -ItemType Directory -Path $convDir -Force | Out-Null
            $archive = Join-Path $convDir "$convName.7z"

            if ($PSCmdlet.ShouldProcess($archive, "Archive conversation JSONL '$($jsonl.Name)'")) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Archiving '$($jsonl.FullName)' → '$archive'"
                & 7z a $archive $jsonl.FullName 2>&1 | Out-Null
                if (Test-Path $archive) {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Conversation saved: $archive"
                } else {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message 'Archive not created — verify 7z is on PATH.'
                }
            }

            # ── 2. Copy memory files ───────────────────────────────────────────────
            # Memory lives under the slug of the directory where Claude Code was launched
            # (i.e. the current working directory), NOT under the _Planning slug.
            $memSrcDir = Join-Path $ClaudeProjectsRoot "$slug\memory"

            if (-not (Test-Path $memSrcDir)) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "Memory directory not found: $memSrcDir — memory copy skipped."
                return
            }

            $memDstDir = Join-Path $PlanningRoot "SprintWorkSessionMemorys\$memName"

            if ($PSCmdlet.ShouldProcess($memDstDir, "Copy memory files from '$memSrcDir'")) {
                New-Item -ItemType Directory -Path $memDstDir -Force | Out-Null
                Copy-Item -Path (Join-Path $memSrcDir '*.md') -Destination $memDstDir -Force
                $copied = (Get-ChildItem $memDstDir -ErrorAction SilentlyContinue).Count
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Memory files saved ($copied files): $memDstDir"
            }
        } catch {
            $errorMessage = "Save-SprintWorkSession failed. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function'
    }
}

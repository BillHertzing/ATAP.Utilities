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
        [string] $ClaudeProjectsRoot = (Join-Path $env:USERPROFILE '.claude\projects'),

        [Parameter(Mandatory = $false)]
        [string] $GitHubRoot = 'C:\Dropbox\whertzing\GitHub',

        [Parameter(Mandatory = $false)]
        [switch] $AllowMainFallback
    )

    begin {
        $fn = $MyInvocation.MyCommand.Name
        $mn = $MyInvocation.MyCommand.ModuleName

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function'

        # Load helper functions
        # None of this is needed once the modules are built and installed into the PSModulePath, but while we are
        # still running from source code, we need to dot source the helper functions that are not yet in a module.
        # Once the modules are built and installed, all of the helper functions will be available as cmdlets and
        # this block can be removed.
        $helpfunctionsneeded = @(
            # Get-PVal is an alias for Get-ParameterValueFromNeoConfigurationRoot, used to populate parameters.
            @{FunctionName = 'Get-ParameterValueFromNeoConfigurationRoot'; ModuleName = 'ATAP.Utilities.PowerShell' }
        )
        # These are three hardcoded values which we use until we get packaging working
        $repoRootParentPath = 'C:\Dropbox\whertzing\GitHub'
        $stablePath = 'ATAP.Utilities'
        # If we are in a sprint branch, use the sprint branch version of the helper functions, otherwise use the
        # stable branch version.  This allows us to use helper functions that are in progress in the sprint branch
        # without having to merge them into the stable branch first.
        $wtFolder = $PWD.Path.Split([IO.Path]::DirectorySeparatorChar) |
            Where-Object { $_ -like '*-wt-*' } |
            Select-Object -First 1
        $resolvedModulePath = $wtFolder ? (Join-Path $repoRootParentPath $wtFolder 'src') : (Join-Path $repoRootParentPath $stablePath 'src')
        foreach ($helpfunction in $helpfunctionsneeded) {
            try {
                if (-not (Test-Path -LiteralPath "Function:\$($helpfunction.FunctionName)")) {
                    $helperPath = Join-Path $resolvedModulePath $helpfunction.ModuleName 'public' "$($helpfunction.FunctionName).ps1"
                    . $helperPath
                }
            } catch {
                # Non-fatal: if the helper cannot be loaded, log a debug message and continue without Get-PVal.
                # Parameters already carry usable defaults so settings-resolution is not strictly required.
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                    -Message "Helper '$($helpfunction.FunctionName)' not loaded from module '$($helpfunction.ModuleName)' at '$helperPath': $($_.Exception.Message). Continuing with parameter declaration defaults."
            }
        }
        # This is the end of the help loading block; it and all above can be removed once module autoloading is
        # working and the helper functions are available as cmdlets in the PSModulePath.

        # Populate parameters from settings only when Get-PVal is available.
        # When the helper is absent (sparse environment / direct import), the parameter-declaration
        # defaults are already usable and no non-terminating error should be emitted.
        if (Test-Path -LiteralPath 'Function:\Get-PVal') {
            # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: SprintN)
            $SprintN = Get-PVal -ParameterName SprintN -originalPSBoundParameters $PSBoundParameters -dottedPath SprintN -DefaultValue $SprintN

            # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: PlanningRoot)
            $PlanningRoot = Get-PVal -ParameterName PlanningRoot -originalPSBoundParameters $PSBoundParameters -dottedPath PlanningRoot -DefaultValue $PlanningRoot

            # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: ClaudeProjectsRoot)
            $ClaudeProjectsRoot = Get-PVal -ParameterName ClaudeProjectsRoot -originalPSBoundParameters $PSBoundParameters -dottedPath ClaudeProjectsRoot -DefaultValue $ClaudeProjectsRoot

            # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: GitHubRoot)
            $GitHubRoot = Get-PVal -ParameterName GitHubRoot -originalPSBoundParameters $PSBoundParameters -dottedPath GitHubRoot -DefaultValue $GitHubRoot
        }
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

            # ── Auto-resolve _Planning worktree (SC-0096 fix) ──────────────────────
            # Resolution order:
            #   1. Caller-supplied -PlanningRoot wins.
            #   2. Scan $GitHubRoot for ^_Planning-wt-\d+-sprint-$SprintN-.*
            #   3. Scan the parent of the current cwd (legacy sibling-scan path)
            #      in case cwd lives outside $GitHubRoot.
            #   4. Refuse to fall back to main _Planning unless -AllowMainFallback
            #      is set, so sprint artifacts never silently land in the main
            #      planning repo.
            if (-not $PlanningRoot) {
                $mainPlanning = Join-Path $GitHubRoot '_Planning'
                $searchRoots = @($GitHubRoot, (Split-Path -Parent (Get-Location).Path)) |
                    Where-Object { $_ -and (Test-Path $_) } |
                    Select-Object -Unique

                $planningWTs = @()
                foreach ($root in $searchRoots) {
                    $planningWTs += @(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
                            Where-Object { $_.Name -match "^_Planning-wt-\d+-sprint-$SprintN(-|$)" })
                }
                $planningWTs = $planningWTs | Sort-Object FullName -Unique

                if ($planningWTs.Count -eq 1) {
                    $PlanningRoot = $planningWTs[0].FullName
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Planning worktree auto-resolved: $PlanningRoot"
                } elseif ($planningWTs.Count -gt 1) {
                    $candidates = ($planningWTs | ForEach-Object { $_.FullName }) -join ', '
                    throw "Multiple _Planning sprint worktrees match sprint $SprintN. Pass -PlanningRoot to disambiguate: $candidates"
                } elseif ($AllowMainFallback) {
                    $PlanningRoot = $mainPlanning
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "No _Planning sprint worktree found for sprint $SprintN. -AllowMainFallback set; using main _Planning: $PlanningRoot"
                } else {
                    throw "No _Planning sprint worktree matched ^_Planning-wt-\\d+-sprint-$SprintN under: $($searchRoots -join '; '). Sprint artifacts must not land in main _Planning silently. Create the sprint worktree, pass -PlanningRoot explicitly, or re-run with -AllowMainFallback."
                }
            }

            # ── Derive project slug from cwd ───────────────────────────────────────
            # Claude Code slugs the project path by lowercasing the drive letter
            # and replacing ':', '\', '_', '.' with '-'.
            # From a sprint worktree the CWD yields a '...-wt-...' slug, but Claude
            # Code may have been launched from the stable repo root so memory lives
            # under the main-repo slug (Bug 2). Try the sprint slug first; if no JSONL
            # is found, fall back to the stable slug by stripping '-wt-.+$' from the
            # path before slugging.
            $cwd = (Get-Location).Path
            $makeSlug = { param([string]$p) ($p.Substring(0, 1).ToLower() + $p.Substring(1)) -replace ':', '-' -replace '\\', '-' -replace '_', '-' -replace '\.', '-' -replace '^-', '' }
            $slug = & $makeSlug $cwd
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Slug derived from cwd '$cwd': $slug"

            # ── Find most-recent session JSONL ─────────────────────────────────────
            $sessionDir = Join-Path $ClaudeProjectsRoot $slug
            $jsonl = Get-ChildItem -Path $sessionDir -Filter '*.jsonl' -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

            if (-not $jsonl) {
                # Worktree fallback: strip '-wt-.+$' to get the stable repo path,
                # recompute slug, and search there.
                $stableCwd = $cwd -replace '-wt-.+$', ''
                if ($stableCwd -ne $cwd) {
                    $stableSlug = & $makeSlug $stableCwd
                    $stableSessionDir = Join-Path $ClaudeProjectsRoot $stableSlug
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "No JSONL at sprint slug '$slug'; trying stable slug '$stableSlug'"
                    $jsonl = Get-ChildItem -Path $stableSessionDir -Filter '*.jsonl' -ErrorAction SilentlyContinue |
                        Sort-Object LastWriteTime -Descending |
                        Select-Object -First 1
                    if ($jsonl) {
                        $slug = $stableSlug
                        $sessionDir = $stableSessionDir
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Using stable repo slug '$slug' — Claude Code was launched from the main repo root"
                    }
                }
            }

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

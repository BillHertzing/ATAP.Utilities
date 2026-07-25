function Save-SprintWorkSession {
    <#
.SYNOPSIS
    Archives the current Claude Code conversation JSONL and copies memory files
    for the current sprint work session.

.DESCRIPTION
    Saves a point-in-time snapshot of the active AI coding-agent session into the
    _Planning sprint worktree so it can be referenced later.  Two artifacts
    are produced:

      1. A 7-zip archive of the most-recent conversation transcript for the
         calling agent  →  SprintWorkSessionConversations\
      2. A copy of the agent's current memory files/artifacts
         →  SprintWorkSessionMemorys\<name>\

    Four agent families are supported via -Agent:

      * ClaudeCode  (default) — transcript JSONL under ~\.claude\projects\<slug>\;
        memory from the same slug's memory\ folder.
      * Antigravity (Google DeepMind / Gemini) — transcript under the brain folder
        ~\.gemini\antigravity\brain\<ConversationId>\.system_generated\logs\
        (transcript_full.jsonl, falling back to transcript.jsonl); memory is every
        artifact directly under the brain folder except the .system_generated
        subfolder.  -ConversationId keys the brain folder; when omitted the newest
        brain folder is auto-detected.
      * Codex (OpenAI Codex CLI) — rollout transcript JSONL under
        ~\.codex\sessions\<YYYY>\<MM>\<DD>\rollout-*-<SessionId>.jsonl (falling back
        to ~\.codex\archived_sessions\); -SessionId selects the rollout, otherwise the
        newest rollout is auto-detected.
      * Copilot (GitHub Copilot) — has no on-disk transcript, so this path delegates
        to Save-CopilotCheckpoint with the caller-supplied -ConversationFile.

    The sprint number is auto-detected from the current branch name
    (pattern: ^\d+-sprint-(\d{4})-.+$).  The _Planning worktree is
    auto-resolved from sibling directories matching
    ^_Planning-wt-\d+-sprint-<SprintN>; falls back to the main _Planning repo
    when no sprint worktree is found.

.PARAMETER Agent
    Which AI coding-agent family's session to checkpoint:
    'ClaudeCode' (default), 'Antigravity', 'Codex', or 'Copilot'.

.PARAMETER ConversationId
    Antigravity conversation UUID that keys the brain folder
    ~\.gemini\antigravity\brain\<ConversationId>\.  When omitted (and -Agent is
    'Antigravity'), the most-recently-modified brain folder is auto-detected.

.PARAMETER SessionId
    Codex session UUID embedded in the rollout transcript filename
    (rollout-<ISO-timestamp>-<SessionId>.jsonl).  When omitted (and -Agent is
    'Codex'), the most-recently-modified rollout JSONL is auto-detected.

.PARAMETER ConversationFile
    Copilot-only: path to a pre-written markdown file containing the reconstructed
    Copilot conversation.  Required when -Agent is 'Copilot'; forwarded to
    Save-CopilotCheckpoint.

.PARAMETER AntigravityRoot
    Root of the Antigravity on-disk data
    (contains brain\ and conversations\).  Defaults to ~\.gemini\antigravity.

.PARAMETER CodexRoot
    Root of the Codex on-disk data (contains sessions\ and archived_sessions\).
    Defaults to ~\.codex.

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

.EXAMPLE
    Save-SprintWorkSession -Agent Antigravity -ConversationId '3f2a9c84-1d77-4b6e-9a2c-0f5e8b1d4a21'
    # Checkpoint an Antigravity session keyed by its conversation UUID.

.EXAMPLE
    Save-SprintWorkSession -Agent Antigravity
    # Checkpoint the most-recently-modified Antigravity brain folder.

.EXAMPLE
    Save-SprintWorkSession -Agent Codex -SessionId '019eced5-2e16-7c80-bfc0-333ccd663db1'
    # Checkpoint a Codex session by its rollout session id (auto-detected when omitted).

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
        [ValidateSet('ClaudeCode', 'Antigravity', 'Codex', 'Copilot')]
        [string] $Agent = 'ClaudeCode',

        [Parameter(Mandatory = $false)]
        [string] $ConversationId = '',

        [Parameter(Mandatory = $false)]
        [string] $SessionId = '',

        [Parameter(Mandatory = $false)]
        [string] $ConversationFile = '',

        [Parameter(Mandatory = $false)]
        [string] $ClaudeProjectsRoot = (Join-Path $env:USERPROFILE '.claude\projects'),

        [Parameter(Mandatory = $false)]
        [string] $AntigravityRoot = (Join-Path $env:USERPROFILE '.gemini\antigravity'),

        [Parameter(Mandatory = $false)]
        [string] $CodexRoot = (Join-Path $env:USERPROFILE '.codex'),

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
                    if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
                        . $helperPath
                    } else {
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                            -Message "Helper '$($helpfunction.FunctionName)' not found at '$helperPath'. Continuing with parameter declaration defaults."
                    }
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

        # Load the collision-free name-composition helper (private\New-CheckpointNameComponents.ps1)
        # when running from source (dot-sourced directly, as the Pester tests do) rather than via
        # module import, where it is already dot-sourced by the .psm1.
        if (-not (Test-Path -LiteralPath 'Function:\New-CheckpointNameComponents')) {
            $checkpointNameHelperPath = Join-Path $PSScriptRoot '..\private\New-CheckpointNameComponents.ps1'
            if (Test-Path -LiteralPath $checkpointNameHelperPath) {
                . $checkpointNameHelperPath
            } else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                    -Message "Helper 'New-CheckpointNameComponents' not found at '$checkpointNameHelperPath'."
            }
        }

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

            # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: AntigravityRoot)
            $AntigravityRoot = Get-PVal -ParameterName AntigravityRoot -originalPSBoundParameters $PSBoundParameters -dottedPath AntigravityRoot -DefaultValue $AntigravityRoot

            # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: CodexRoot)
            $CodexRoot = Get-PVal -ParameterName CodexRoot -originalPSBoundParameters $PSBoundParameters -dottedPath CodexRoot -DefaultValue $CodexRoot

            # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: GitHubRoot)
            $GitHubRoot = Get-PVal -ParameterName GitHubRoot -originalPSBoundParameters $PSBoundParameters -dottedPath GitHubRoot -DefaultValue $GitHubRoot
        }

        function Resolve-CaseInsensitiveChildDirectory {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true)]
                [string] $ParentPath,

                [Parameter(Mandatory = $true)]
                [string] $ChildName
            )

            $candidatePath = Join-Path -Path $ParentPath -ChildPath $ChildName
            if (-not (Test-Path -LiteralPath $ParentPath -PathType Container)) {
                return $candidatePath
            }

            $children = @(Get-ChildItem -LiteralPath $ParentPath -Directory -Force -ErrorAction SilentlyContinue)
            $exactMatch = $children |
                Where-Object { $_.Name -ceq $ChildName } |
                Select-Object -First 1
            if ($exactMatch) {
                return $exactMatch.FullName
            }

            $caseInsensitiveMatch = $children |
                Where-Object { $_.Name -ieq $ChildName } |
                Select-Object -First 1
            if ($caseInsensitiveMatch) {
                return $caseInsensitiveMatch.FullName
            }

            return $candidatePath
        }
    }

    process {
        try {
            # ── Copilot path: delegate to Save-CopilotCheckpoint ───────────────────
            # GitHub Copilot writes no on-disk transcript, so it cannot be archived the
            # way ClaudeCode/Antigravity/Codex are. The caller pre-writes the
            # reconstructed conversation markdown (-ConversationFile) and we hand the
            # whole job to the companion cmdlet, which mirrors the same _Planning
            # hard-stop. This keeps -Agent Copilot a valid, working call.
            if ($Agent -eq 'Copilot') {
                if (-not $ConversationFile) {
                    throw "The Copilot path requires -ConversationFile (GitHub Copilot has no on-disk transcript). Write the reconstructed conversation to a markdown file, then call: Save-SprintWorkSession -Agent Copilot -ConversationFile <path>."
                }
                if (-not (Get-Command -Name 'Save-CopilotCheckpoint' -ErrorAction SilentlyContinue)) {
                    throw "Save-CopilotCheckpoint is not available in this session. Import/dot-source ATAP.Utilities.BuildTooling.PowerShell (which provides it) before checkpointing the Copilot path."
                }
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Agent=Copilot: delegating to Save-CopilotCheckpoint with ConversationFile '$ConversationFile'"
                $copilotParams = @{ ConversationFile = $ConversationFile }
                if ($SprintN)           { $copilotParams['SprintN'] = $SprintN }
                if ($PlanningRoot)      { $copilotParams['PlanningRoot'] = $PlanningRoot }
                if ($GitHubRoot)        { $copilotParams['GitHubRoot'] = $GitHubRoot }
                if ($AllowMainFallback) { $copilotParams['AllowMainFallback'] = $true }
                Save-CopilotCheckpoint @copilotParams
                return
            }

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

            # ── Resolve the agent's transcript + memory source ─────────────────────
            # Each agent stores its conversation transcript and memory artifacts in a
            # different on-disk location. The switch below sets, for the selected agent:
            #   $jsonl              the transcript file to archive (FileInfo)
            #   $memSrcDir          directory whose files become the memory snapshot
            #   $memoryCopyMode     'ClaudeMd' | 'AntigravityArtifacts' | 'None'
            #   $slug               session key recorded in the roster (SessionSlug)
            #   $agentSessionKey    the agent-specific id (slug / ConversationId / SessionId)
            #   $conversationDbPath optional SQLite DB path (Antigravity), else $null
            $cwd = (Get-Location).Path
            $jsonl = $null
            $memSrcDir = $null
            $memoryCopyMode = 'None'
            $slug = $null
            $agentSessionKey = $null
            $conversationDbPath = $null

            switch ($Agent) {
                'ClaudeCode' {
                    # Claude Code slugs the project path by lowercasing the drive letter
                    # and replacing ':', '\', '_', '.' with '-'.
                    # From a sprint worktree the CWD yields a '...-wt-...' slug, but Claude
                    # Code may have been launched from the stable repo root so memory lives
                    # under the main-repo slug (Bug 2). Try the sprint slug first; if no
                    # JSONL is found, fall back to the stable slug by stripping '-wt-.+$'
                    # from the path before slugging.
                    $makeSlug = { param([string]$p) ($p.Substring(0, 1).ToLower() + $p.Substring(1)) -replace ':', '-' -replace '\\', '-' -replace '_', '-' -replace '\.', '-' -replace '^-', '' }
                    $slug = & $makeSlug $cwd
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Slug derived from cwd '$cwd': $slug"

                    $sessionDir = Resolve-CaseInsensitiveChildDirectory -ParentPath $ClaudeProjectsRoot -ChildName $slug
                    $jsonl = Get-ChildItem -Path $sessionDir -Filter '*.jsonl' -ErrorAction SilentlyContinue |
                        Sort-Object LastWriteTime -Descending |
                        Select-Object -First 1

                    if (-not $jsonl) {
                        # Worktree fallback: strip '-wt-.+$' to get the stable repo path,
                        # recompute slug, and search there.
                        $stableCwd = $cwd -replace '-wt-.+$', ''
                        if ($stableCwd -ne $cwd) {
                            $stableSlug = & $makeSlug $stableCwd
                            $stableSessionDir = Resolve-CaseInsensitiveChildDirectory -ParentPath $ClaudeProjectsRoot -ChildName $stableSlug
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

                    # Memory lives under the slug of the directory where Claude Code was
                    # launched (the current working directory), NOT under the _Planning slug.
                    $memSrcDir = Resolve-CaseInsensitiveChildDirectory -ParentPath $sessionDir -ChildName 'memory'
                    $memoryCopyMode = 'ClaudeMd'
                    $agentSessionKey = $slug
                }

                'Antigravity' {
                    # Antigravity stores each conversation in a "brain" folder keyed by the
                    # conversation UUID. Auto-detect the newest brain folder when no
                    # -ConversationId was supplied.
                    $brainRoot = Join-Path $AntigravityRoot 'brain'
                    if (-not (Test-Path $brainRoot)) {
                        throw "Antigravity brain root not found: '$brainRoot'. Pass -AntigravityRoot to override."
                    }

                    if (-not $ConversationId) {
                        $newestBrain = Get-ChildItem -Path $brainRoot -Directory -ErrorAction SilentlyContinue |
                            Sort-Object LastWriteTime -Descending |
                            Select-Object -First 1
                        if (-not $newestBrain) {
                            throw "No Antigravity brain folders found under '$brainRoot'. Pass -ConversationId or verify the path."
                        }
                        $ConversationId = $newestBrain.Name
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "ConversationId auto-detected from newest brain folder: $ConversationId"
                    }

                    $brainFolder = Join-Path $brainRoot $ConversationId
                    if (-not (Test-Path $brainFolder)) {
                        throw "Antigravity brain folder not found for ConversationId '$ConversationId': '$brainFolder'."
                    }

                    # Transcript: prefer transcript_full.jsonl, fall back to transcript.jsonl.
                    $logsDir = Join-Path $brainFolder '.system_generated\logs'
                    $transcriptFull = Join-Path $logsDir 'transcript_full.jsonl'
                    $transcript = Join-Path $logsDir 'transcript.jsonl'
                    if (Test-Path -LiteralPath $transcriptFull) {
                        $jsonl = Get-Item -LiteralPath $transcriptFull
                    } elseif (Test-Path -LiteralPath $transcript) {
                        $jsonl = Get-Item -LiteralPath $transcript
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "transcript_full.jsonl absent; using transcript.jsonl in '$logsDir'"
                    } else {
                        throw "No Antigravity transcript found under '$logsDir' (looked for transcript_full.jsonl then transcript.jsonl)."
                    }

                    # Memory: every artifact directly under the brain folder EXCEPT the
                    # .system_generated subfolder.
                    $memSrcDir = $brainFolder
                    $memoryCopyMode = 'AntigravityArtifacts'
                    $slug = "antigravity-$ConversationId"
                    $agentSessionKey = $ConversationId

                    # Optional SQLite conversation database for this conversation.
                    $candidateDb = Join-Path $AntigravityRoot "conversations\$ConversationId.db"
                    if (Test-Path -LiteralPath $candidateDb) {
                        $conversationDbPath = $candidateDb
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Antigravity conversation DB: $conversationDbPath"
                    }
                }

                'Codex' {
                    # Codex (OpenAI Codex CLI) writes a rollout transcript JSONL under a
                    # dated tree, keyed by session UUID. Search the live sessions tree
                    # first, then archived_sessions.
                    $sessionsRoot = Join-Path $CodexRoot 'sessions'
                    $archivedRoot = Join-Path $CodexRoot 'archived_sessions'
                    $rollFilter = if ($SessionId) { "rollout-*-$SessionId.jsonl" } else { 'rollout-*.jsonl' }

                    foreach ($root in @($sessionsRoot, $archivedRoot)) {
                        if (-not (Test-Path $root)) { continue }
                        $jsonl = Get-ChildItem -Path $root -Filter $rollFilter -Recurse -File -ErrorAction SilentlyContinue |
                            Sort-Object LastWriteTime -Descending |
                            Select-Object -First 1
                        if ($jsonl) { break }
                    }

                    if (-not $jsonl) {
                        $what = if ($SessionId) { "for session id '$SessionId'" } else { 'any rollout' }
                        throw "No Codex rollout JSONL found ($what) under '$sessionsRoot' or '$archivedRoot'. Pass -CodexRoot/-SessionId or verify the path."
                    }

                    # Recover the session id from the rollout filename when auto-detected.
                    if (-not $SessionId -and $jsonl.Name -match 'rollout-.*-([0-9a-fA-F-]{36})\.jsonl$') {
                        $SessionId = $Matches[1]
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "SessionId auto-detected from newest rollout: $SessionId"
                    }

                    # Codex has no conventional on-disk memory store; the roster records
                    # the skip reason and the conversation archive is still written.
                    $memSrcDir = $null
                    $memoryCopyMode = 'None'
                    $slug = if ($SessionId) { "codex-$SessionId" } else { 'codex' }
                    $agentSessionKey = $SessionId
                }
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Agent=$Agent transcript: $($jsonl.FullName) (LastWriteTime: $($jsonl.LastWriteTime))"

            # ── Build name components ──────────────────────────────────────────────
            # Names must be collision-free across multiple stable repositories that
            # are all on branch `main`, checkpointed within the same second — see
            # New-CheckpointNameComponents (repo/worktree identity + second-precision
            # timestamp + PID/high-resolution-tick disambiguator).
            $worktreeName = Split-Path -Path $cwd -Leaf
            $nameComponents = New-CheckpointNameComponents -SprintN $SprintN -WorktreeName $worktreeName -Branch $branch
            $convName = $nameComponents.ConvName
            $memName = $nameComponents.MemName
            $rosterDir = Join-Path $PlanningRoot 'SprintWorkSessionRoster'
            $rosterPath = Join-Path $rosterDir "SprintWorkSessionRoster-$SprintN.jsonl"
            $archiveCreated = $false
            $memoryCopied = $false
            $memoryFileCount = 0
            $memorySkipReason = $null

            # ── 1. Compress conversation JSONL with 7-zip ──────────────────────────
            $convDir = Join-Path $PlanningRoot 'SprintWorkSessionConversations'
            New-Item -ItemType Directory -Path $convDir -Force | Out-Null
            $archive = Join-Path $convDir "$convName.7z"

            if ($PSCmdlet.ShouldProcess($archive, "Archive conversation JSONL '$($jsonl.Name)'")) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Archiving '$($jsonl.FullName)' → '$archive'"
                & 7z a $archive $jsonl.FullName 2>&1 | Out-Null
                if (Test-Path $archive) {
                    # Task 13.76.d: the existence of the .7z proves nothing about its payload.
                    # `7z a` can emit an archive with zero entries when path/token expansion
                    # fails, and the previous check reported ConversationArchiveCreated = $true
                    # for it -- a checkpoint that claims the conversation was saved when it was
                    # not. Assert the contents before claiming success.
                    $listing = & 7z l -ba $archive 2>&1
                    $entries = @($listing | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                    if ($entries.Count -eq 0) {
                        throw "7z archive was created but contains no files: $archive"
                    }

                    # The bare listing puts the stored name last on each line; match on the
                    # file name rather than a column position so 7z formatting changes cannot
                    # silently turn this assertion into a no-op.
                    $jsonlFileName = [IO.Path]::GetFileName($jsonl.FullName)
                    $containsRolloutJsonl = @(
                        $entries | Where-Object { $_ -match [regex]::Escape($jsonlFileName) }
                    ).Count -gt 0
                    if (-not $containsRolloutJsonl) {
                        throw "7z archive created but rollout file '$jsonlFileName' is absent: $archive"
                    }

                    $archiveCreated = $true
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Conversation saved: $archive ($($entries.Count) entr$(if ($entries.Count -eq 1) { 'y' } else { 'ies' }))"
                } else {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message 'Archive not created — verify 7z is on PATH.'
                }
            }

            # ── 2. Copy memory files ───────────────────────────────────────────────
            # The memory source and copy semantics were resolved per-agent above:
            #   ClaudeMd              -> copy *.md from the slug's memory\ folder
            #   AntigravityArtifacts  -> copy every top-level artifact under the brain
            #                            folder EXCEPT the .system_generated subfolder
            #   None                  -> agent has no on-disk memory store (e.g. Codex)
            $memDstDir = Join-Path $PlanningRoot "SprintWorkSessionMemorys\$memName"

            if ($memoryCopyMode -eq 'None' -or -not $memSrcDir) {
                $memorySkipReason = "Agent '$Agent' has no on-disk memory store; memory copy skipped."
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $memorySkipReason
            } elseif (-not (Test-Path $memSrcDir)) {
                $memorySkipReason = "Memory directory not found: $memSrcDir"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "$memorySkipReason — memory copy skipped."
            } elseif ($PSCmdlet.ShouldProcess($memDstDir, "Copy memory files from '$memSrcDir'")) {
                New-Item -ItemType Directory -Path $memDstDir -Force | Out-Null
                switch ($memoryCopyMode) {
                    'ClaudeMd' {
                        Copy-Item -Path (Join-Path $memSrcDir '*.md') -Destination $memDstDir -Force
                    }
                    'AntigravityArtifacts' {
                        # Copy all artifacts directly under the brain folder, excluding the
                        # .system_generated subfolder (which holds the transcript/logs).
                        Get-ChildItem -LiteralPath $memSrcDir -Force -ErrorAction SilentlyContinue |
                            Where-Object { $_.Name -ne '.system_generated' } |
                            ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $memDstDir -Recurse -Force }
                    }
                }
                $memoryFileCount = (Get-ChildItem $memDstDir -ErrorAction SilentlyContinue).Count
                $memoryCopied = $true
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Memory files saved ($memoryFileCount files): $memDstDir"
            }

            # ── 3. Append a lightweight session roster entry ───────────────────────
            $rosterEntry = [ordered]@{
                SprintN                    = $SprintN
                RecordedAt                 = (Get-Date).ToString('o')
                Agent                      = $Agent
                AgentSessionKey            = $agentSessionKey
                WorktreeName               = $worktreeName
                WorktreePath               = $cwd
                Branch                     = $branch
                SessionSlug                = $slug
                ConversationJsonlPath      = $jsonl.FullName
                ConversationArchivePath    = $archive
                ConversationArchiveCreated = $archiveCreated
                ConversationDbPath         = $conversationDbPath
                MemorySourcePath           = $memSrcDir
                MemorySnapshotPath         = $memDstDir
                MemorySnapshotCreated      = $memoryCopied
                MemoryFileCount            = $memoryFileCount
                MemorySkipReason           = $memorySkipReason
            }

            if ($PSCmdlet.ShouldProcess($rosterPath, "Append sprint session roster entry for '$worktreeName'")) {
                New-Item -ItemType Directory -Path $rosterDir -Force | Out-Null
                $rosterJson = $rosterEntry | ConvertTo-Json -Compress
                Add-Content -LiteralPath $rosterPath -Value $rosterJson -Encoding UTF8
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Session roster updated: $rosterPath"
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

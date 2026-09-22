function Save-SprintWorkSession {
    <#
.SYNOPSIS
    Archives the current agent conversation, its required sidecars, and memory files
    for the current sprint work session.

.DESCRIPTION
    Saves a point-in-time snapshot of the active AI coding-agent session into the
    _Planning sprint worktree so it can be referenced later.  Two artifacts
    are produced:

      1. A self-verifying 7-zip archive of the selected conversation transcript,
         sibling subagent transcripts, and referenced overflow tool results for the
         calling agent  →  SprintWorkSessionConversations\
      2. A self-verifying 7-zip archive of the agent's current memory directory
         →  SprintWorkSessionMemorys\<name>.7z

    Four agent families are supported via -Agent:

      * ClaudeCode  (default) — transcript JSONL under ~\.claude\projects\<slug>\,
        named <session-id>.jsonl; memory from a project store's memory\ folder.
        The transcript is selected by session id (-SessionId, else
        $env:CLAUDE_CODE_SESSION_ID), searching this repository's project store,
        then the stable-repo store, then every store — because a session rooted in
        one worktree routinely checkpoints work done in another.  Newest-by-mtime
        is used only when no session id is available, and the roster row then
        records ConversationSelectionRule = 'NewestInProjectStore' (SC-0327).
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
    The invoking agent session's own UUID.

    For 'Codex' it is the id embedded in the rollout transcript filename
    (rollout-<ISO-timestamp>-<SessionId>.jsonl); when omitted, the
    most-recently-modified rollout JSONL is auto-detected.

    For 'ClaudeCode' it is the id that names the transcript
    (<SessionId>.jsonl) under ~\.claude\projects\<slug>\.  When omitted, it
    falls back to $env:CLAUDE_CODE_SESSION_ID, and only if that is absent does
    the function fall back to newest-by-mtime.  Pass it whenever the caller knows
    it: it is the only input that identifies the invoking session exactly, and a
    project store routinely holds transcripts from several concurrent sessions.

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
    [PSCustomObject] — the same facts appended to the sprint session roster,
    including ConversationJsonlPath, ConversationSelectionRule (which rule chose
    the transcript), ConversationSkipKind / ConversationSkipReason (set when no
    transcript could be resolved, or when one was chosen by an unverified rule),
    and the corresponding Memory* fields.

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

.EXAMPLE
    Save-SprintWorkSession -Agent ClaudeCode -SessionId $env:CLAUDE_CODE_SESSION_ID
    # Checkpoint THIS Claude Code session, wherever its transcript lives. Required
    # form when the session's own project store differs from the repository being
    # checkpointed, which is the normal shape of cross-repository work here.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
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

        function Copy-ConversationSnapshot {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [string] $SourcePath,

                [Parameter(Mandatory)]
                [string] $DestinationPath,

                [int] $RetryCount = 8,

                [int] $RetryDelayMilliseconds = 250
            )

            for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
                try {
                    $sourceStream = [IO.File]::Open($SourcePath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
                    try {
                        $destinationStream = [IO.File]::Open($DestinationPath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
                        try {
                            $sourceStream.CopyTo($destinationStream)
                        } finally {
                            $destinationStream.Dispose()
                        }
                    } finally {
                        $sourceStream.Dispose()
                    }
                    $sourceAfter = Get-Item -LiteralPath $SourcePath -ErrorAction Stop
                    $destinationAfter = Get-Item -LiteralPath $DestinationPath -ErrorAction Stop
                    if ($sourceAfter.Length -ne $destinationAfter.Length) {
                        throw [IO.IOException]::new("Source changed while it was being snapshotted: '$SourcePath'.")
                    }
                    $destinationAfter.LastWriteTimeUtc = $sourceAfter.LastWriteTimeUtc
                    return $destinationAfter
                } catch [IO.IOException] {
                    if ($attempt -eq $RetryCount) {
                        throw "Could not snapshot active conversation '$SourcePath' after $RetryCount shared-read attempts. Close or release the agent transcript and retry checkpoint. Last error: $($_.Exception.Message)"
                    }
                    Start-Sleep -Milliseconds $RetryDelayMilliseconds
                }
            }
        }

        function Test-CheckpointJsonLines {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [string] $Path
            )

            $lineNumber = 0
            foreach ($line in [IO.File]::ReadLines($Path)) {
                $lineNumber++
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                try {
                    $null = $line | ConvertFrom-Json -ErrorAction Stop
                } catch {
                    throw "Incomplete or invalid JSONL at '$Path' line $($lineNumber): $($_.Exception.Message)"
                }
            }
        }

        function New-VerifiedCheckpointArchive {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [ValidateSet('Conversation', 'Memory')]
                [string] $Kind,

                [Parameter(Mandatory)]
                [object[]] $SourceItems,

                [Parameter(Mandatory)]
                [string] $ArchivePath,

                [Parameter(Mandatory)]
                [string] $StagingPath,

                [string] $ToolResultsRoot = '',

                [string] $ToolResultsArchivePrefix = ''
            )

            $pendingArchive = "$ArchivePath.pending"
            $quarantineArchive = "$ArchivePath.quarantine"
            $stagedItems = [System.Collections.Generic.List[object]]::new()
            $seenArchivePaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

            try {
                New-Item -ItemType Directory -Path $StagingPath -Force | Out-Null

                foreach ($sourceItem in $SourceItems) {
                    $archiveRelativePath = ([string]$sourceItem.ArchivePath).Replace('/', [IO.Path]::DirectorySeparatorChar)
                    if ([IO.Path]::IsPathRooted($archiveRelativePath) -or $archiveRelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
                        throw "Unsafe checkpoint archive path '$archiveRelativePath'."
                    }
                    if (-not $seenArchivePaths.Add($archiveRelativePath)) { continue }
                    if (-not (Test-Path -LiteralPath $sourceItem.SourcePath -PathType Leaf)) {
                        throw "Required checkpoint source is absent: '$($sourceItem.SourcePath)'."
                    }

                    $stagedPath = Join-Path $StagingPath $archiveRelativePath
                    New-Item -ItemType Directory -Path (Split-Path -Path $stagedPath -Parent) -Force | Out-Null
                    $stagedFile = Copy-ConversationSnapshot -SourcePath $sourceItem.SourcePath -DestinationPath $stagedPath
                    if ($sourceItem.ValidateJsonl) {
                        Test-CheckpointJsonLines -Path $stagedFile.FullName
                    }
                    $stagedItems.Add([PSCustomObject]@{
                            SourcePath  = $sourceItem.SourcePath
                            ArchivePath = $archiveRelativePath
                            StagedPath  = $stagedFile.FullName
                        })
                }

                if ($ToolResultsRoot) {
                    $referencePattern = '(?i)(?:^|[\\/])tool-results[\\/]+(?<Name>[A-Za-z0-9][A-Za-z0-9._-]*\.txt)'
                    $referencedNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
                    foreach ($stagedJsonl in @($stagedItems | Where-Object { $_.ArchivePath -like '*.jsonl' })) {
                        $content = Get-Content -LiteralPath $stagedJsonl.StagedPath -Raw
                        foreach ($match in [regex]::Matches($content, $referencePattern)) {
                            $null = $referencedNames.Add($match.Groups['Name'].Value)
                        }
                    }

                    foreach ($referencedName in $referencedNames) {
                        $sourcePath = Join-Path $ToolResultsRoot $referencedName
                        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                            throw "Dangling overflow tool-result reference '$referencedName'; expected exact file '$sourcePath'."
                        }
                        $archiveRelativePath = Join-Path $ToolResultsArchivePrefix $referencedName
                        if (-not $seenArchivePaths.Add($archiveRelativePath)) { continue }
                        $stagedPath = Join-Path $StagingPath $archiveRelativePath
                        New-Item -ItemType Directory -Path (Split-Path -Path $stagedPath -Parent) -Force | Out-Null
                        $stagedFile = Copy-ConversationSnapshot -SourcePath $sourcePath -DestinationPath $stagedPath
                        $stagedItems.Add([PSCustomObject]@{
                                SourcePath  = $sourcePath
                                ArchivePath = $archiveRelativePath
                                StagedPath  = $stagedFile.FullName
                            })
                    }
                }

                $manifestFiles = @($stagedItems | Sort-Object ArchivePath | ForEach-Object {
                        $file = Get-Item -LiteralPath $_.StagedPath
                        [PSCustomObject][ordered]@{
                            Path   = $_.ArchivePath.Replace([IO.Path]::DirectorySeparatorChar, '/')
                            Bytes  = $file.Length
                            Sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
                        }
                    })
                $payloadBytes = [long](($manifestFiles | Measure-Object -Property Bytes -Sum).Sum)
                $manifest = [ordered]@{
                    SchemaVersion = '1.0.0'
                    Kind          = $Kind
                    PayloadFiles  = $manifestFiles.Count
                    PayloadBytes  = $payloadBytes
                    Files         = $manifestFiles
                }
                $manifestPath = Join-Path $StagingPath '.checkpoint-manifest.json'
                $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Creating pending $Kind archive '$pendingArchive' from '$StagingPath'."
                $sevenZipOutput = @(& 7z a -t7z $pendingArchive (Join-Path $StagingPath '*') -r 2>&1)
                if ($LASTEXITCODE -ne 0) {
                    throw "7z failed to create pending $Kind archive (exit $LASTEXITCODE): $($sevenZipOutput -join ' ')"
                }
                $testOutput = @(& 7z t $pendingArchive 2>&1)
                if ($LASTEXITCODE -ne 0) {
                    throw "7z integrity test failed for pending $Kind archive (exit $LASTEXITCODE): $($testOutput -join ' ')"
                }
                $listing = @(& 7z l -ba $pendingArchive 2>&1)
                $expectedEntries = @($manifestFiles.Path) + '.checkpoint-manifest.json'
                foreach ($expectedEntry in $expectedEntries) {
                    $windowsEntry = $expectedEntry.Replace('/', [IO.Path]::DirectorySeparatorChar)
                    if (-not ($listing | Where-Object { $_ -match "(?:^|\s)$([regex]::Escape($windowsEntry))$" })) {
                        throw "7z archive is incomplete; expected entry '$expectedEntry' is absent from '$pendingArchive'."
                    }
                }

                if (Test-Path -LiteralPath $ArchivePath) {
                    $existingHash = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash
                    $pendingHash = (Get-FileHash -LiteralPath $pendingArchive -Algorithm SHA256).Hash
                    if ($existingHash -ne $pendingHash) {
                        throw "Idempotent publish refused to overwrite a different archive at '$ArchivePath'."
                    }
                } else {
                    Move-Item -LiteralPath $pendingArchive -Destination $ArchivePath
                }

                $archiveFile = Get-Item -LiteralPath $ArchivePath
                return [PSCustomObject]@{
                    ArchivePath       = $archiveFile.FullName
                    ArchiveEntryCount = $expectedEntries.Count
                    PayloadFileCount  = $manifestFiles.Count
                    PayloadByteCount  = $payloadBytes
                    ArchiveByteCount  = $archiveFile.Length
                    ArchiveSha256     = (Get-FileHash -LiteralPath $archiveFile.FullName -Algorithm SHA256).Hash
                }
            } catch {
                if (Test-Path -LiteralPath $pendingArchive -PathType Leaf) {
                    Move-Item -LiteralPath $pendingArchive -Destination $quarantineArchive -Force
                }
                throw
            } finally {
                if (Test-Path -LiteralPath $StagingPath) {
                    Remove-Item -LiteralPath $StagingPath -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }

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
                # @(...) is load-bearing: with exactly one match Sort-Object -Unique emits a
                # bare DirectoryInfo, and the .Count below then throws under Set-StrictMode.
                $planningWTs = @($planningWTs | Sort-Object FullName -Unique)

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
            # Which rule actually chose $jsonl (SC-0327). A checkpoint that cannot say
            # HOW it picked a transcript cannot be audited, and the newest-by-mtime
            # heuristic is wrong whenever more than one session writes to a store.
            #   ExplicitSessionId    -> caller passed -SessionId
            #   EnvironmentSessionId -> resolved from the agent's own session-id variable
            #   SessionIdCrossStore  -> as above, but the transcript lives under a project
            #                           store other than the checkpointed repository's
            #   NewestInProjectStore -> no session id was available; newest mtime was used
            #   NotApplicable        -> agent whose store is keyed some other way
            $conversationSelectionRule = 'NotApplicable'
            # Discriminated conversation-skip outcome, mirroring MemorySkipKind:
            #   NotFound  -> the invoking session is known and its transcript is not on disk
            #   Ambiguous -> no session id, and the store holds several candidate transcripts
            $conversationSkipKind = $null
            $conversationSkipReason = $null

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
                    $sprintSlug = & $makeSlug $cwd
                    $slug = $sprintSlug
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Slug derived from cwd '$cwd': $slug"

                    # Compute the stable-repo slug up front. Both the transcript fallback
                    # below and the independent memory probe need it, and memory must not
                    # depend on whether the transcript fallback happened to run.
                    $stableCwd = $cwd -replace '-wt-.+$', ''
                    $stableSlug = if ($stableCwd -ne $cwd) { & $makeSlug $stableCwd } else { $null }

                    $sessionDir = Resolve-CaseInsensitiveChildDirectory -ParentPath $ClaudeProjectsRoot -ChildName $slug

                    # ── Transcript selection (SC-0327) ────────────────────────────────
                    # Claude Code names each transcript '<session-id>.jsonl', so the
                    # invoking session's id identifies its transcript EXACTLY. Prefer it
                    # over any heuristic:
                    #
                    #   1. -SessionId, when the caller passes it.
                    #   2. The runtime's own session-id environment variable.
                    #   3. Newest-by-mtime in the project store (legacy fallback only).
                    #
                    # Rule 3 is not a tie-breaker, it is a guess, and it is wrong in the
                    # normal case here: a session rooted in one worktree routinely does its
                    # writing in another, and several agents write to one store
                    # concurrently. Twice observed archiving an unrelated session's
                    # transcript while reporting success. Keep it only for runtimes that
                    # expose no session id, and record on the roster row that a guess was
                    # made.
                    $claudeSessionId = if ($SessionId) {
                        $conversationSelectionRule = 'ExplicitSessionId'
                        $SessionId
                    } elseif ($env:CLAUDE_CODE_SESSION_ID) {
                        $conversationSelectionRule = 'EnvironmentSessionId'
                        $env:CLAUDE_CODE_SESSION_ID
                    } else {
                        $null
                    }

                    if ($claudeSessionId) {
                        # Search the two keys tied to this repository first so the common
                        # case stays cheap and the reported store is the expected one, then
                        # sweep every project store. The cross-store sweep is what makes a
                        # checkpoint run from a DIFFERENT repository than the session's own
                        # root find the right transcript instead of a wrong one.
                        $transcriptName = "$claudeSessionId.jsonl"
                        $orderedStores = @($sessionDir)
                        if ($stableSlug) {
                            $orderedStores += Resolve-CaseInsensitiveChildDirectory -ParentPath $ClaudeProjectsRoot -ChildName $stableSlug
                        }

                        foreach ($store in $orderedStores) {
                            $candidate = Join-Path $store $transcriptName
                            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                                $jsonl = Get-Item -LiteralPath $candidate
                                $slug = Split-Path -Path $store -Leaf
                                $sessionDir = $store
                                break
                            }
                        }

                        if (-not $jsonl) {
                            $crossStoreHit = Get-ChildItem -LiteralPath $ClaudeProjectsRoot -Directory -ErrorAction SilentlyContinue |
                                ForEach-Object { Join-Path $_.FullName $transcriptName } |
                                Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
                                Select-Object -First 1
                            if ($crossStoreHit) {
                                $jsonl = Get-Item -LiteralPath $crossStoreHit
                                $sessionDir = Split-Path -Path $crossStoreHit -Parent
                                $slug = Split-Path -Path $sessionDir -Leaf
                                $conversationSelectionRule = 'SessionIdCrossStore'
                                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Session '$claudeSessionId' transcript found under project store '$slug', not under the checkpointed repository's store '$sprintSlug'. This is normal for a cross-repository session."
                            }
                        }

                        if (-not $jsonl) {
                            # The invoking session is KNOWN and its transcript is not on
                            # disk. Falling back to newest-by-mtime here would reintroduce
                            # exactly the silent wrong-file success this contract exists to
                            # prevent, so report the skip instead of guessing.
                            $conversationSkipKind = 'NotFound'
                            $conversationSkipReason = "No transcript named '$transcriptName' found under any project store in '$ClaudeProjectsRoot'. The invoking session id is known, so no newest-file fallback was attempted."
                            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "$conversationSkipReason — conversation archive skipped."
                        }
                    } else {
                        # No session id available. Legacy newest-by-mtime, sprint key then
                        # stable key, flagged so the roster row never implies certainty.
                        $jsonl = Get-ChildItem -Path $sessionDir -Filter '*.jsonl' -ErrorAction SilentlyContinue |
                            Sort-Object LastWriteTime -Descending |
                            Select-Object -First 1

                        if (-not $jsonl -and $stableSlug) {
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

                        if ($jsonl) {
                            $conversationSelectionRule = 'NewestInProjectStore'
                            $storeTranscriptCount = @(Get-ChildItem -Path $sessionDir -Filter '*.jsonl' -ErrorAction SilentlyContinue).Count
                            if ($storeTranscriptCount -gt 1) {
                                # Not fatal — but the caller must never read this row as an
                                # assertion that the invoking session was captured.
                                $conversationSkipKind = 'Ambiguous'
                                $conversationSkipReason = "No session id was available and project store '$slug' holds $storeTranscriptCount transcripts; '$($jsonl.Name)' was chosen by newest modification time and may belong to a different session. Pass -SessionId to select the invoking session."
                                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message $conversationSkipReason
                            }
                        } else {
                            $conversationSkipKind = 'NotFound'
                            $conversationSkipReason = "No JSONL found in '$sessionDir' and no session id was available. Slug derived: $slug"
                            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "$conversationSkipReason — conversation archive skipped."
                        }
                    }

                    if ($jsonl) {
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Conversation transcript selected by rule '$conversationSelectionRule': $($jsonl.FullName)"
                    }

                    # Memory lives under a project slug, but NOT necessarily the same slug
                    # the transcript was found under (Task 14.13). The transcript can sit at
                    # the sprint-worktree key while the memory store exists only at the
                    # stable-repo key, so the store is located independently here rather
                    # than inherited from $sessionDir.
                    #
                    # Probe order is sprint key first, then stable key: a live sprint store
                    # must never be shadowed by a staler stable one. Neither is under the
                    # _Planning slug.
                    #
                    # The store the transcript was resolved from is a LAST candidate
                    # (SC-0327): when the invoking session lives under a third project
                    # store, its memory is there and nowhere else, but a live store keyed
                    # to the repository being checkpointed still takes precedence.
                    $memoryCandidateSlugs = @($sprintSlug)
                    if ($stableSlug -and $stableSlug -ne $sprintSlug) {
                        $memoryCandidateSlugs += $stableSlug
                    }
                    if ($slug -and $memoryCandidateSlugs -notcontains $slug) {
                        $memoryCandidateSlugs += $slug
                    }

                    $memSrcDir = $null
                    $memorySourceKey = $null
                    foreach ($candidateSlug in $memoryCandidateSlugs) {
                        $candidateSessionDir = Resolve-CaseInsensitiveChildDirectory -ParentPath $ClaudeProjectsRoot -ChildName $candidateSlug
                        $candidateMemoryDir = Resolve-CaseInsensitiveChildDirectory -ParentPath $candidateSessionDir -ChildName 'memory'
                        if (Test-Path -LiteralPath $candidateMemoryDir -PathType Container) {
                            $memSrcDir = $candidateMemoryDir
                            $memorySourceKey = $candidateSlug
                            if ($candidateSlug -ne $sprintSlug) {
                                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Memory store found under the stable repo slug '$candidateSlug', not the sprint slug '$sprintSlug'"
                            }
                            break
                        }
                    }

                    if (-not $memSrcDir) {
                        # Nothing found at any candidate. Keep the sprint-key path so the
                        # skip diagnostic names the location that was expected.
                        $sprintSessionDir = Resolve-CaseInsensitiveChildDirectory -ParentPath $ClaudeProjectsRoot -ChildName $sprintSlug
                        $memSrcDir = Resolve-CaseInsensitiveChildDirectory -ParentPath $sprintSessionDir -ChildName 'memory'
                        $memorySourceKey = $sprintSlug
                    }

                    $memoryCopyMode = 'ClaudeMd'
                    # Prefer the session id: the slug only identifies a project store, and
                    # a store holds many sessions, so a slug alone cannot answer "which
                    # session does this roster row cover?" (SC-0327).
                    $agentSessionKey = if ($claudeSessionId) { $claudeSessionId } else { $slug }
                }

                'Antigravity' {
                    # Antigravity stores each conversation in a "brain" folder keyed by the
                    # conversation UUID. Auto-detect the newest brain folder when no
                    # -ConversationId was supplied.
                    $brainRoot = Join-Path $AntigravityRoot 'brain'
                    if (-not (Test-Path $brainRoot)) {
                        throw "Antigravity brain root not found: '$brainRoot'. Pass -AntigravityRoot to override."
                    }

                    $conversationSelectionRule = if ($ConversationId) { 'ExplicitSessionId' } else { 'NewestInProjectStore' }

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
                    $conversationSelectionRule = if ($SessionId) { 'ExplicitSessionId' } else { 'NewestInProjectStore' }
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
            $conversationArchiveMetrics = $null
            $memoryCopied = $false
            $memoryFileCount = 0
            $memoryArchiveMetrics = $null
            $memorySkipReason = $null
            # Discriminated skip outcome (Task 14.13). Prose in $memorySkipReason cannot be
            # acted on by a caller, and a boolean cannot tell "this agent has no memory
            # store" apart from "a store was expected and was not found":
            #   None     -> the agent legitimately has no on-disk memory store (Codex)
            #   NotFound -> a store was expected at a known key and was not there
            #   Empty    -> the store exists but held nothing to copy
            $memorySkipKind = $null

            # ── 1. Archive the complete conversation bundle ───────────────────────
            $convDir = Join-Path $PlanningRoot 'SprintWorkSessionConversations'
            New-Item -ItemType Directory -Path $convDir -Force | Out-Null
            $archive = Join-Path $convDir "$convName.7z"
            $snapshotDir = Join-Path ([IO.Path]::GetTempPath()) "ATAP-checkpoint-$($nameComponents.Disambiguator)"

            if (-not $jsonl) {
                # Transcript selection reported a skip (SC-0327). Continue so the memory
                # snapshot and the roster row are still written -- but write a row that
                # says plainly no conversation was captured, rather than one that archives
                # some other session's transcript and reports success.
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "No conversation transcript resolved ($conversationSkipKind); conversation archive skipped. $conversationSkipReason"
            } elseif ($PSCmdlet.ShouldProcess($archive, "Archive conversation JSONL '$($jsonl.Name)'")) {
                $conversationSources = [System.Collections.Generic.List[object]]::new()
                $conversationSources.Add([PSCustomObject]@{
                        SourcePath    = $jsonl.FullName
                        ArchivePath   = $jsonl.Name
                        ValidateJsonl = $true
                    })

                # Sidecars live only beneath the exact transcript basename. Close
                # variants and renamed sibling directories must never be guessed.
                $sidecarName = $jsonl.BaseName
                $sidecarRoot = Join-Path $jsonl.Directory.FullName $sidecarName
                $subagentsRoot = Join-Path $sidecarRoot 'subagents'
                if (Test-Path -LiteralPath $subagentsRoot -PathType Container) {
                    foreach ($subagentTranscript in @(Get-ChildItem -LiteralPath $subagentsRoot -File -Filter '*.jsonl' -ErrorAction Stop | Sort-Object Name)) {
                        $conversationSources.Add([PSCustomObject]@{
                                SourcePath    = $subagentTranscript.FullName
                                ArchivePath   = Join-Path $sidecarName 'subagents' $subagentTranscript.Name
                                ValidateJsonl = $true
                            })
                    }
                }

                $conversationArchiveParameters = @{
                    Kind                     = 'Conversation'
                    SourceItems              = $conversationSources.ToArray()
                    ArchivePath              = $archive
                    StagingPath              = $snapshotDir
                    ToolResultsRoot          = Join-Path $sidecarRoot 'tool-results'
                    ToolResultsArchivePrefix = Join-Path $sidecarName 'tool-results'
                }
                $conversationArchiveMetrics = New-VerifiedCheckpointArchive @conversationArchiveParameters
                $archiveCreated = $true
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Conversation saved and verified: $archive ($($conversationArchiveMetrics.PayloadFileCount) payload files, $($conversationArchiveMetrics.PayloadByteCount) bytes, SHA-256 $($conversationArchiveMetrics.ArchiveSha256))"
            }

            # ── 2. Archive memory files ────────────────────────────────────────────
            # The memory source and selection semantics were resolved per-agent above:
            #   ClaudeMd              -> archive the complete memory\ directory
            #   AntigravityArtifacts  -> copy every top-level artifact under the brain
            #                            folder EXCEPT the .system_generated subfolder
            #   None                  -> agent has no on-disk memory store (e.g. Codex)
            $memDstDir = Join-Path $PlanningRoot 'SprintWorkSessionMemorys'
            $memoryArchive = Join-Path $memDstDir "$memName.7z"
            $memoryStagingPath = Join-Path ([IO.Path]::GetTempPath()) "ATAP-checkpoint-memory-$($nameComponents.Disambiguator)"

            if ($memoryCopyMode -eq 'None' -or -not $memSrcDir) {
                $memorySkipKind = 'None'
                $memorySkipReason = "Agent '$Agent' has no on-disk memory store; memory copy skipped."
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $memorySkipReason
            } elseif (-not (Test-Path $memSrcDir)) {
                # A store was expected at a known key and is not there. Structurally
                # distinct from the 'None' case above, which is correct behavior.
                $memorySkipKind = 'NotFound'
                $memorySkipReason = "Memory directory not found: $memSrcDir"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "$memorySkipReason — memory copy skipped."
            } elseif ($PSCmdlet.ShouldProcess($memoryArchive, "Archive memory files from '$memSrcDir'")) {
                New-Item -ItemType Directory -Path $memDstDir -Force | Out-Null
                $memorySourceFiles = @()
                switch ($memoryCopyMode) {
                    'ClaudeMd' {
                        $memorySourceFiles = @(Get-ChildItem -LiteralPath $memSrcDir -File -Recurse -Force -ErrorAction SilentlyContinue)
                    }
                    'AntigravityArtifacts' {
                        $memorySourceFiles = @(Get-ChildItem -LiteralPath $memSrcDir -Force -ErrorAction SilentlyContinue |
                            Where-Object { $_.Name -ne '.system_generated' } |
                            ForEach-Object {
                                if ($_.PSIsContainer) {
                                    Get-ChildItem -LiteralPath $_.FullName -File -Recurse -Force -ErrorAction SilentlyContinue
                                } else {
                                    $_
                                }
                            })
                    }
                }
                $memoryFileCount = $memorySourceFiles.Count
                if ($memoryFileCount -eq 0) {
                    # The store existed but held nothing to copy — a third outcome that is
                    # neither a legitimate 'None' nor a missing-store 'NotFound'.
                    $memorySkipKind = 'Empty'
                    $memorySkipReason = "Memory directory contained no files to copy: $memSrcDir"
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message $memorySkipReason
                } else {
                    $memorySourceItems = @($memorySourceFiles | ForEach-Object {
                            [PSCustomObject]@{
                                SourcePath    = $_.FullName
                                ArchivePath   = [IO.Path]::GetRelativePath($memSrcDir, $_.FullName)
                                ValidateJsonl = $false
                            }
                        })
                    $memoryArchiveParameters = @{
                        Kind        = 'Memory'
                        SourceItems = $memorySourceItems
                        ArchivePath = $memoryArchive
                        StagingPath = $memoryStagingPath
                    }
                    $memoryArchiveMetrics = New-VerifiedCheckpointArchive @memoryArchiveParameters
                    $memoryCopied = $true
                }
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Memory archive saved ($memoryFileCount files): $memoryArchive"
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
                ConversationJsonlPath      = if ($jsonl) { $jsonl.FullName } else { $null }
                ConversationSelectionRule  = $conversationSelectionRule
                ConversationSkipKind       = $conversationSkipKind
                ConversationSkipReason     = $conversationSkipReason
                ConversationArchivePath    = $archive
                ConversationArchiveCreated = $archiveCreated
                ConversationArchiveEntryCount = if ($conversationArchiveMetrics) { $conversationArchiveMetrics.ArchiveEntryCount } else { 0 }
                ConversationFileCount       = if ($conversationArchiveMetrics) { $conversationArchiveMetrics.PayloadFileCount } else { 0 }
                ConversationByteCount       = if ($conversationArchiveMetrics) { $conversationArchiveMetrics.PayloadByteCount } else { 0 }
                ConversationArchiveByteCount = if ($conversationArchiveMetrics) { $conversationArchiveMetrics.ArchiveByteCount } else { 0 }
                ConversationArchiveSha256   = if ($conversationArchiveMetrics) { $conversationArchiveMetrics.ArchiveSha256 } else { $null }
                ConversationDbPath         = $conversationDbPath
                MemorySourcePath           = $memSrcDir
                MemorySourceKey            = $memorySourceKey
                MemorySnapshotPath         = $memoryArchive
                MemorySnapshotCreated      = $memoryCopied
                MemoryFileCount            = $memoryFileCount
                MemoryByteCount            = if ($memoryArchiveMetrics) { $memoryArchiveMetrics.PayloadByteCount } else { 0 }
                MemoryArchiveByteCount     = if ($memoryArchiveMetrics) { $memoryArchiveMetrics.ArchiveByteCount } else { 0 }
                MemoryArchiveEntryCount    = if ($memoryArchiveMetrics) { $memoryArchiveMetrics.ArchiveEntryCount } else { 0 }
                MemoryArchiveSha256        = if ($memoryArchiveMetrics) { $memoryArchiveMetrics.ArchiveSha256 } else { $null }
                MemorySkipKind             = $memorySkipKind
                MemorySkipReason           = $memorySkipReason
            }

            if ($PSCmdlet.ShouldProcess($rosterPath, "Append sprint session roster entry for '$worktreeName'")) {
                New-Item -ItemType Directory -Path $rosterDir -Force | Out-Null
                $rosterJson = $rosterEntry | ConvertTo-Json -Compress
                Add-Content -LiteralPath $rosterPath -Value $rosterJson -Encoding UTF8
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Session roster updated: $rosterPath"
            }

            # Return the same facts the roster records so the caller — the checkpoint
            # skill's report in particular — can see an unexpected 'NotFound' without
            # reading PSFramework output (Task 14.13).
            [PSCustomObject]$rosterEntry
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

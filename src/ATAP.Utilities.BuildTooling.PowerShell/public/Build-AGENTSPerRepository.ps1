<#
.SYNOPSIS
Materializes the Codex AGENTS.md base into each repository worktree in the current sprint.

.DESCRIPTION
Build-AGENTSPerRepository is the Codex (AGENTS.md) sibling of Build-CLAUDEPerRepository.
It locates the Overview-wt-sprintNNNN.code-workspace file one level above the current
worktree root, reads the folders list, then for each repository worktree writes the
shared Codex base instructions to AGENTS.md at the worktree root.

The Codex base is the AGENTS.md rendered by SharedVSCode/.ai/tools/Render-AIAdapters.ps1
from the canonical .ai/core/main-instructions.md (the Codex 'generated-wrapper' target of
the ai.core.main-instructions.v1 manifest record). That rendered base file lives at the
SharedVSCode sprint worktree root as AGENTS.md and is read here as the source of truth.

Unlike Build-CLAUDEPerRepository, this cmdlet:
  - performs a PURE copy of the rendered base (no per-repo local overlay and no
    provenance table). Codex gets the pure rendered base for now; a per-repo Codex
    overlay (analogous to ai-local.md) can be added later. The generated-wrapper header
    already carries provenance (SourceId, SourceSha256). Omitting the timestamped
    provenance table keeps the per-repo AGENTS.md BYTE-IDENTICAL across repos and
    idempotent on re-run (a second build is a no-op), which the AGENTS.md acceptance
    requires.

When the workspace is a sprint Overview workspace (it carries a sprintEphemeral block
and/or lists at least one sprint worktree folder), any repository that has no sprint
worktree this sprint is listed under its stable folder name and is SKIPPED rather than
written. This honors the stable-worktree boundary (Task 10.14.b) and avoids seeding
sprint-base-derived content into a stable repo. Skipped repos are reported with
Skipped = $true in RepositoryResults.

.PARAMETER WorktreeRoot
Optional path to the current worktree root. Defaults to the git toplevel of the
current working directory.

.PARAMETER WorkspacePath
Optional explicit path to the sprint Overview code-workspace file. When supplied,
the cmdlet uses this file instead of filename-based discovery in the parent folder.

.OUTPUTS
System.Management.Automation.PSCustomObject
Returns a result object containing:
  - Success (bool): Whether the operation completed successfully
  - WorkspacePath (string): Path to the discovered workspace file
  - BaseFilePath (string): Path to the rendered AGENTS.md base in SharedVSCode
  - RepositoriesProcessed (int): Number of repositories processed
  - RepositoryResults (array): Per-repository details
  - Errors (array): Any errors encountered

.EXAMPLE
Build-AGENTSPerRepository

Discovers the sprint workspace from the current worktree and writes AGENTS.md for all
sprint repositories from the SharedVSCode rendered Codex base.

.NOTES
AI assisted using Powershell.instructions.md as guidelines.
The rendered base (SharedVSCode/AGENTS.md) is produced by Render-AIAdapters; because the
whole Dropbox tree carries a Cloud-Files reparse attribute, Render-AIAdapters' reparse
guard (SC-0198) blocks in-place writes, so the base render is performed by invoking the
renderer's generated-wrapper logic directly. This cmdlet only copies that base out.
#>

function Build-AGENTSPerRepository {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $false, Position = 0,
      HelpMessage = 'Path to the current worktree root')]
    [ValidateNotNullOrEmpty()]
    [string]$WorktreeRoot,

    [Parameter(Mandatory = $false, Position = 1,
      HelpMessage = 'Path to the sprint Overview code-workspace file')]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspacePath
  )

  begin {
    $fn = 'Build-AGENTSPerRepository'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Snippet: Check and populate simple parameter
    # Parameter: WorktreeRoot
    if (-not $PSBoundParameters.ContainsKey('WorktreeRoot') -or [string]::IsNullOrWhiteSpace($WorktreeRoot)) {
      try {
        $gitTopLevel = git rev-parse --show-toplevel 2>&1
        if ($LASTEXITCODE -ne 0) {
          throw "git rev-parse --show-toplevel failed: $gitTopLevel"
        }
        $WorktreeRoot = (Resolve-Path $gitTopLevel -ErrorAction Stop).Path
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "WorktreeRoot defaulted to git toplevel: $WorktreeRoot"
      } catch {
        $errorMessage = "Failed to determine worktree root: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }
    } else {
      try {
        $WorktreeRoot = (Resolve-Path $WorktreeRoot -ErrorAction Stop).Path
      } catch {
        $errorMessage = "WorktreeRoot path does not exist: $WorktreeRoot"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Using worktree root: $WorktreeRoot"

    # Initialize result object
    $result = [PSCustomObject]@{
      Success               = $false
      WorkspacePath         = $null
      BaseFilePath          = $null
      RepositoriesProcessed = 0
      RepositoryResults     = @()
      Errors                = @()
    }
  }

  process {
    try {
      # Step 1: Resolve the sprint workspace file. Prefer an explicit path so new
      # Overview naming styles do not break propagation.
      $parentDir = Split-Path $WorktreeRoot -Parent
      if ($PSBoundParameters.ContainsKey('WorkspacePath') -and -not [string]::IsNullOrWhiteSpace($WorkspacePath)) {
        try {
          $workspaceFile = Get-Item -LiteralPath $WorkspacePath -ErrorAction Stop
        } catch {
          throw "WorkspacePath does not exist: $WorkspacePath"
        }
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Searching for workspace file in: $parentDir"

        $workspaceFiles = @()
        $workspaceFiles += Get-ChildItem -Path $parentDir -Filter 'Overview-wt-sprint????.code-workspace' -File -ErrorAction SilentlyContinue
        $workspaceFiles += Get-ChildItem -Path $parentDir -Filter 'OverviewSprint????.code-workspace' -File -ErrorAction SilentlyContinue

        if (-not $workspaceFiles -or $workspaceFiles.Count -eq 0) {
          throw "No Overview sprint code-workspace file found in '$parentDir'"
        }
        if ($workspaceFiles.Count -gt 1) {
          # Use the most recently updated workspace if more than one naming style exists.
          $workspaceFiles = $workspaceFiles | Sort-Object LastWriteTime, Name -Descending
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Multiple workspace files found; using latest: $($workspaceFiles[0].Name)"
        }
        $workspaceFile = $workspaceFiles[0]
      }

      $workspaceFile = Get-Item -LiteralPath $workspaceFile.FullName -ErrorAction Stop
      $result.WorkspacePath = $workspaceFile.FullName
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Using workspace file: $($workspaceFile.FullName)"

      # Step 2: Read the workspace file and extract folder paths
      try {
        $workspaceContent = Get-Content -Path $workspaceFile.FullName -Raw -ErrorAction Stop
        # Remove trailing commas before closing brackets (JSONC tolerance)
        $cleanedJson = $workspaceContent -replace ',\s*([}\]])', '$1'
        $workspaceData = $cleanedJson | ConvertFrom-Json -ErrorAction Stop
      } catch {
        throw "Failed to parse workspace file '$($workspaceFile.FullName)': $($_.Exception.Message)"
      }

      if (-not $workspaceData.folders) {
        throw "Workspace file '$($workspaceFile.FullName)' has no folders section"
      }

      $folderPaths = @()
      foreach ($folder in $workspaceData.folders) {
        $folderPaths += $folder.path
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Found $($folderPaths.Count) folder(s) in workspace: $($folderPaths -join ', ')"

      # Detect sprint context so stable worktrees are not overwritten during a sprint.
      $sprintWorktreePattern = '-wt-\d+-Sprint-\d{4}-work-items$'
      $hasEphemeral = [bool]$workspaceData.PSObject.Properties['sprintEphemeral'] -and $null -ne $workspaceData.sprintEphemeral
      $hasSprintFolder = @($folderPaths | Where-Object { $_ -match $sprintWorktreePattern }).Count -gt 0
      $isSprintContext = $hasEphemeral -or $hasSprintFolder
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Sprint context: $isSprintContext (ephemeral=$hasEphemeral, sprintFolder=$hasSprintFolder)"

      # Step 3: Identify the SharedVSCode worktree path
      $sharedVSCodeRelPath = $folderPaths | Where-Object { $_ -match 'SharedVSCode' }
      if (-not $sharedVSCodeRelPath) {
        throw 'No SharedVSCode folder found in workspace file'
      }
      $sharedVSCodeFullPath = Join-Path $parentDir $sharedVSCodeRelPath
      $sharedVSCodeFullPath = (Resolve-Path $sharedVSCodeFullPath -ErrorAction Stop).Path
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "SharedVSCode worktree: $sharedVSCodeFullPath"

      # Step 4: Locate the rendered Codex base AGENTS.md in the SharedVSCode worktree
      $baseFilePath = Join-Path $sharedVSCodeFullPath 'AGENTS.md'
      if (-not (Test-Path $baseFilePath -PathType Leaf)) {
        throw "Rendered Codex base AGENTS.md not found at '$baseFilePath'. Render it first from canonical via Render-AIAdapters (Codex target of ai.core.main-instructions.v1)."
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Codex base AGENTS.md found at: $baseFilePath"
      $result.BaseFilePath = $baseFilePath

      # Read raw bytes so the per-repo copy is byte-identical to the rendered base.
      $baseContent = Get-Content -Path $baseFilePath -Raw -ErrorAction Stop

      # Step 5: Process each repository worktree
      foreach ($relPath in $folderPaths) {
        $repoFullPath = Join-Path $parentDir $relPath
        try {
          $repoFullPath = (Resolve-Path $repoFullPath -ErrorAction Stop).Path
        } catch {
          $errorMessage = "Repository path does not exist: $repoFullPath"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          $result.Errors += $errorMessage
          continue
        }

        $repoName = Split-Path $repoFullPath -Leaf

        $repoResult = [PSCustomObject]@{
          Repository   = $repoName
          Path         = $repoFullPath
          Success      = $false
          Skipped      = $false
          Action       = $null
          ErrorMessage = $null
        }

        # Boundary guard: in a sprint context, never write AGENTS.md into a stable
        # worktree. A repo with no sprint worktree this sprint is listed under its
        # stable folder name; writing here would violate stable-worktree boundary
        # rules and seed sprint-base-derived content into a stable repo. Skip it.
        if ($isSprintContext -and $repoName -notmatch $sprintWorktreePattern) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Skipping stable worktree '$repoName' (no sprint worktree this sprint); AGENTS.md left untouched to honor stable-worktree boundary."
          $repoResult.Skipped = $true
          $result.RepositoryResults += $repoResult
          $result.RepositoriesProcessed++
          continue
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Processing repository: $repoName"

        try {
          $agentsMdPath = Join-Path $repoFullPath 'AGENTS.md'

          # Idempotent write: only touch the file when the rendered base differs from
          # what is already there. This makes a re-run a true no-op (Action=unchanged),
          # proves drift-identical idempotency, and avoids needlessly rewriting a file
          # that a cloud-sync provider may still be holding open.
          $existing = if (Test-Path -LiteralPath $agentsMdPath -PathType Leaf) {
            Get-Content -LiteralPath $agentsMdPath -Raw -ErrorAction Stop
          } else { $null }

          if ($null -ne $existing -and $existing -ceq $baseContent) {
            $repoResult.Action = 'unchanged'
            $repoResult.Success = $true
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "AGENTS.md unchanged for $repoName"
          } elseif ($PSCmdlet.ShouldProcess($agentsMdPath, 'Write Codex base AGENTS.md')) {
            # Pure copy of the rendered base; -NoNewline preserves byte-for-byte content.
            Set-Content -Path $agentsMdPath -Value $baseContent -Encoding UTF8 -NoNewline -ErrorAction Stop
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Wrote AGENTS.md for $repoName"
            $repoResult.Action = 'written'
            $repoResult.Success = $true
          }
        } catch {
          $errorMessage = "Failed to build AGENTS.md for '$repoName': $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          $repoResult.ErrorMessage = $errorMessage
          $result.Errors += $errorMessage
        }

        $result.RepositoryResults += $repoResult
        $result.RepositoriesProcessed++
      }

      $result.Success = ($result.Errors.Count -eq 0)
    } catch {
      $errorMessage = "Build-AGENTSPerRepository failed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.Errors += $errorMessage
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    $result
  }
}

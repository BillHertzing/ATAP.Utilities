<#
.SYNOPSIS
Distributes the rendered agent-specific instruction files into each sprint repository.

.DESCRIPTION
Build-AgentSpecificPerRepository is the agent-specific-lane sibling of
Build-AGENTSPerRepository and Build-CLAUDEPerRepository (Task 10.23). After the shared
core is rendered to AGENTS-base.md and combined into each repo's AGENTS.md, the
per-agent (NON-core) surfaces must also land in every repo the way AGENTS.md / CLAUDE.md
do, because each agent reads them repo-relatively:

  - GEMINI.md                       (Antigravity / Gemini agent-specific)
  - .github/copilot-instructions.md (GitHub Copilot agent-specific)

These files are rendered ONCE at the SharedVSCode worktree root by Render-AIAdapters
(the ai.agent-specific.* records) and contain ONLY per-agent deltas plus a pointer to
AGENTS.md for core, never the core body (no-double-core invariant). Distribution is a
PURE COPY (the agent-specific content is repo-independent; repo-specific rules live in
the AGENTS.md / CLAUDE.md AI-LOCAL block). A pure copy makes the self-copy into the
SharedVSCode worktree a harmless no-op and keeps re-runs idempotent.

When the workspace is a sprint Overview workspace (it carries a sprintEphemeral block
and/or lists at least one sprint worktree folder), any repository that has no sprint
worktree this sprint is listed under its stable folder name and is SKIPPED rather than
written, honoring the stable-worktree boundary (Task 10.14.b).

.PARAMETER WorktreeRoot
Optional path to the current worktree root. Defaults to the git toplevel of the
current working directory.

.PARAMETER WorkspacePath
Optional explicit path to the sprint Overview code-workspace file. When supplied,
the cmdlet uses this file instead of filename-based discovery in the parent folder.

.PARAMETER RepositoryContext
Internal pre-resolved repository context supplied by
Build-AIInstructionsPerRepository so all lanes share one workspace read and one
stable-worktree skip decision.

.OUTPUTS
System.Management.Automation.PSCustomObject
Returns a result object containing Success, WorkspacePath, the discovered base files,
RepositoriesProcessed, RepositoryResults, and Errors.

.EXAMPLE
Build-AgentSpecificPerRepository

Discovers the sprint workspace and writes GEMINI.md and .github/copilot-instructions.md
into every sprint repository from the SharedVSCode rendered agent-specific bases.

.NOTES
AI assisted using Powershell.instructions.md as guidelines.
#>

function Build-AgentSpecificPerRepository {
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
    [string]$WorkspacePath,

    [Parameter(Mandatory = $false, DontShow = $true)]
    [PSCustomObject]$RepositoryContext
  )

  begin {
    $fn = 'Build-AgentSpecificPerRepository'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # The agent-specific surfaces distributed to every repo. RelativePath is the
    # repo-relative destination; a parent directory is created when needed.
    $agentSpecificFiles = @(
      [PSCustomObject]@{ Name = 'GEMINI.md'; RelativePath = 'GEMINI.md' }
      [PSCustomObject]@{ Name = 'copilot-instructions.md'; RelativePath = '.github/copilot-instructions.md' }
    )

    if ($null -eq $RepositoryContext -and
      (-not $PSBoundParameters.ContainsKey('WorktreeRoot') -or [string]::IsNullOrWhiteSpace($WorktreeRoot))) {
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
    } elseif ($null -eq $RepositoryContext) {
      try {
        $WorktreeRoot = (Resolve-Path $WorktreeRoot -ErrorAction Stop).Path
      } catch {
        $errorMessage = "WorktreeRoot path does not exist: $WorktreeRoot"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }
    }

    if ($null -eq $RepositoryContext) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Using worktree root: $WorktreeRoot"
    }

    $result = [PSCustomObject]@{
      Success               = $false
      WorkspacePath         = $null
      BaseFiles             = @()
      RepositoriesProcessed = 0
      RepositoryResults     = @()
      Errors                = @()
    }
  }

  process {
    try {
      if ($null -ne $RepositoryContext) {
        $result.WorkspacePath = $RepositoryContext.WorkspacePath
        $sharedVSCodeFullPath = $RepositoryContext.SharedVSCodePath
        $sprintWorktreePattern = $RepositoryContext.SprintWorktreePattern
        $repositoryEntries = @($RepositoryContext.Repositories)
      } else {
        $parentDir = Split-Path $WorktreeRoot -Parent
        if ($PSBoundParameters.ContainsKey('WorkspacePath') -and -not [string]::IsNullOrWhiteSpace($WorkspacePath)) {
          try {
            $workspaceFile = Get-Item -LiteralPath $WorkspacePath -ErrorAction Stop
          } catch {
            throw "WorkspacePath does not exist: $WorkspacePath"
          }
        } else {
          $workspaceFiles = @()
          $workspaceFiles += Get-ChildItem -Path $parentDir -Filter 'Overview-wt-sprint????.code-workspace' -File -ErrorAction SilentlyContinue
          $workspaceFiles += Get-ChildItem -Path $parentDir -Filter 'OverviewSprint????.code-workspace' -File -ErrorAction SilentlyContinue

          if (-not $workspaceFiles -or $workspaceFiles.Count -eq 0) {
            throw "No Overview sprint code-workspace file found in '$parentDir'"
          }
          if ($workspaceFiles.Count -gt 1) {
            $workspaceFiles = $workspaceFiles | Sort-Object LastWriteTime, Name -Descending
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Multiple workspace files found; using latest: $($workspaceFiles[0].Name)"
          }
          $workspaceFile = $workspaceFiles[0]
        }

        $workspaceFile = Get-Item -LiteralPath $workspaceFile.FullName -ErrorAction Stop
        $result.WorkspacePath = $workspaceFile.FullName
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Using workspace file: $($workspaceFile.FullName)"

        try {
          $workspaceContent = Get-Content -Path $workspaceFile.FullName -Raw -ErrorAction Stop
          $cleanedJson = $workspaceContent -replace ',\s*([}\]])', '$1'
          $workspaceData = $cleanedJson | ConvertFrom-Json -ErrorAction Stop
        } catch {
          throw "Failed to parse workspace file '$($workspaceFile.FullName)': $($_.Exception.Message)"
        }
        if (-not $workspaceData.folders) {
          throw "Workspace file '$($workspaceFile.FullName)' has no folders section"
        }

        $folderPaths = @($workspaceData.folders | ForEach-Object { $_.path })
        $sprintWorktreePattern = '-wt-\d+-Sprint-\d{4}-work-items$'
        $hasEphemeral = [bool]$workspaceData.PSObject.Properties['sprintEphemeral'] -and $null -ne $workspaceData.sprintEphemeral
        $hasSprintFolder = @($folderPaths | Where-Object { $_ -match $sprintWorktreePattern }).Count -gt 0
        $isSprintContext = $hasEphemeral -or $hasSprintFolder

        $repositoryEntries = foreach ($relativePath in $folderPaths) {
          $candidatePath = Join-Path $parentDir $relativePath
          $resolvedPath = $null
          $resolutionError = $null
          try {
            $resolvedPath = (Resolve-Path $candidatePath -ErrorAction Stop).Path
          } catch {
            $resolutionError = "Repository path does not exist: $candidatePath"
          }
          $repositoryName = if ($resolvedPath) { Split-Path $resolvedPath -Leaf } else { Split-Path $candidatePath -Leaf }
          [PSCustomObject]@{
            Repository      = $repositoryName
            Path            = $resolvedPath
            Skipped         = $isSprintContext -and $repositoryName -notmatch $sprintWorktreePattern
            ResolutionError = $resolutionError
          }
        }

        $sharedRepository = $repositoryEntries |
          Where-Object { -not $_.ResolutionError -and $_.Repository -match '^SharedVSCode(?:-wt-\d+-Sprint-\d{4}-work-items)?$' } |
          Select-Object -First 1
        if (-not $sharedRepository) {
          throw 'No SharedVSCode folder found in workspace file'
        }
        $sharedVSCodeFullPath = $sharedRepository.Path
      }

      # Step 4: Read the rendered agent-specific bases once.
      $bases = @()
      foreach ($spec in $agentSpecificFiles) {
        $baseFilePath = Join-Path $sharedVSCodeFullPath $spec.RelativePath
        if (-not (Test-Path -LiteralPath $baseFilePath -PathType Leaf)) {
          throw "Rendered agent-specific base '$($spec.RelativePath)' not found at '$baseFilePath'. Render it first from canonical via Render-AIAdapters (ai.agent-specific.* records)."
        }
        $baseContent = Get-Content -LiteralPath $baseFilePath -Raw -ErrorAction Stop
        if ($baseContent -match 'SourceId:\s*ai\.core\.main-instructions\.v1' -or
          $baseContent -match '<!-- AI-CORE:BEGIN -->') {
          throw "Rendered agent-specific base '$($spec.RelativePath)' contains the shared core body. The no-double-core invariant requires core instructions to live only in AGENTS.md."
        }
        $bases += [PSCustomObject]@{
          Name         = $spec.Name
          RelativePath = $spec.RelativePath
          FullPath     = $baseFilePath
          Content      = $baseContent
        }
      }
      $result.BaseFiles = @($bases | ForEach-Object { $_.FullPath })

      # Step 5: Distribute into every repository worktree.
      foreach ($repositoryEntry in $repositoryEntries) {
        if ($repositoryEntry.ResolutionError) {
          $errorMessage = $repositoryEntry.ResolutionError
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          $result.Errors += $errorMessage
          continue
        }

        $repoFullPath = $repositoryEntry.Path
        $repoName = $repositoryEntry.Repository

        $repoResult = [PSCustomObject]@{
          Repository   = $repoName
          Path         = $repoFullPath
          Skipped      = $false
          Files        = @()
          ErrorMessage = $null
        }

        if ($repositoryEntry.Skipped) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Skipping stable worktree '$repoName' (no sprint worktree this sprint); agent-specific files left untouched to honor stable-worktree boundary."
          $repoResult.Skipped = $true
          $result.RepositoryResults += $repoResult
          $result.RepositoriesProcessed++
          continue
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Processing repository: $repoName"

        $fileResults = @()
        foreach ($base in $bases) {
          $fileResult = [PSCustomObject]@{
            RelativePath = $base.RelativePath
            Action       = $null
            Success      = $false
          }
          try {
            $destPath = Join-Path $repoFullPath ($base.RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
            $destDir = Split-Path -Path $destPath -Parent
            if (-not (Test-Path -LiteralPath $destDir -PathType Container)) {
              if ($PSCmdlet.ShouldProcess($destDir, 'Create parent directory')) {
                New-Item -ItemType Directory -Path $destDir -Force -ErrorAction Stop | Out-Null
              }
            }

            $existing = if (Test-Path -LiteralPath $destPath -PathType Leaf) {
              Get-Content -LiteralPath $destPath -Raw -ErrorAction Stop
            } else { $null }

            if ($null -ne $existing -and $existing -ceq $base.Content) {
              $fileResult.Action = 'unchanged'
              $fileResult.Success = $true
            } elseif ($PSCmdlet.ShouldProcess($destPath, "Write agent-specific $($base.Name)")) {
              Set-Content -LiteralPath $destPath -Value $base.Content -Encoding UTF8 -NoNewline -ErrorAction Stop
              $fileResult.Action = 'written'
              $fileResult.Success = $true
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Wrote $($base.RelativePath) for $repoName"
            }
          } catch {
            $errorMessage = "Failed to write '$($base.RelativePath)' for '$repoName': $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            $result.Errors += $errorMessage
          }
          $fileResults += $fileResult
        }

        $repoResult.Files = $fileResults
        $result.RepositoryResults += $repoResult
        $result.RepositoriesProcessed++
      }

      $result.Success = ($result.Errors.Count -eq 0)
    } catch {
      $errorMessage = "Build-AgentSpecificPerRepository failed: $($_.Exception.Message)"
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

<#
.SYNOPSIS
Builds a combined CLAUDE.md file for each repository worktree in the current sprint.

.DESCRIPTION
Locates the Overview-wt-sprintNNNN.code-workspace file one level above the current
worktree root, reads the folders list, then for each repository worktree:
  1. Reads CLAUDE-base.md from the SharedVSCode sprint worktree
  2. Reads ai-local.md (legacy: CLAUDE-local.md) from the repository worktree root (if present)
  3. Combines local + provenance table + base into CLAUDE.md at the worktree root

The provenance table inserted between local and base content records the last-modified
timestamps of the base file, the local file, and the newly written combined file.

When the workspace is a sprint Overview workspace (it carries a sprintEphemeral block
and/or lists at least one sprint worktree folder), any repository that has no sprint
worktree this sprint is listed under its stable folder name and is SKIPPED rather than
overwritten. This honors the stable-worktree boundary and avoids seeding
sprint-base-derived content into a stable repo. Skipped repos are reported with
Skipped = $true in RepositoryResults.

.PARAMETER WorktreeRoot
Optional path to the current worktree root. Defaults to the git toplevel of the
current working directory.

.PARAMETER WorkspacePath
Optional explicit path to the sprint Overview code-workspace file. When supplied,
the cmdlet uses this file instead of filename-based discovery in the parent folder.

.PARAMETER RepositoryContext
Internal pre-resolved repository context supplied by
Build-AIInstructionsPerRepository so the three lanes share one workspace read and
one stable-worktree skip decision.

.OUTPUTS
System.Management.Automation.PSCustomObject
Returns a result object containing:
  - Success (bool): Whether the operation completed successfully
  - WorkspacePath (string): Path to the discovered workspace file
  - RepositoriesProcessed (int): Number of repositories processed
  - RepositoryResults (array): Per-repository details
  - Errors (array): Any errors encountered

.EXAMPLE
Build-CLAUDEPerRepository

Discovers the sprint workspace from the current worktree and builds CLAUDE.md for all repositories.

.EXAMPLE
Build-CLAUDEPerRepository -WorktreeRoot 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-94-sprint-0004-work-items'

Builds CLAUDE.md for all repositories starting from the specified worktree root.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
#>

function Build-CLAUDEPerRepository {
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
    $fn = 'Build-CLAUDEPerRepository'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Snippet: Check and populate simple parameter
    # Parameter: WorktreeRoot
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

    # Initialize result object
    $result = [PSCustomObject]@{
      Success               = $false
      WorkspacePath         = $null
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
          $workspaceFiles += Get-ChildItem -Path $parentDir -Filter 'Overview.Sprint.????.code-workspace' -File -ErrorAction SilentlyContinue
          # Legacy compatibility only:
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
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "SharedVSCode worktree: $sharedVSCodeFullPath"

      # Step 4: Locate CLAUDE-base.md in SharedVSCode worktree
      $baseFilePath = Join-Path $sharedVSCodeFullPath 'CLAUDE-base.md'
      if (-not (Test-Path $baseFilePath -PathType Leaf)) {
        throw "CLAUDE-base.md not found at '$baseFilePath'"
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "CLAUDE-base.md found at: $baseFilePath"

      $baseContent = Get-Content -Path $baseFilePath -Raw -ErrorAction Stop
      $baseLastModified = (Get-Item $baseFilePath -ErrorAction Stop).LastWriteTime

      # Remove the sentinel line and its trailing blank line from base content
      $baseContent = $baseContent -replace '(?m)^# Claude-Base md file start \(remove as part of conatenation\)\r?\n\r?\n', ''

      # Step 5: Process each repository worktree
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
          Repository      = $repoName
          Path            = $repoFullPath
          HasLocal        = $false
          Success         = $false
          Skipped         = $false
          ErrorMessage    = $null
          WrittenPath     = $null
          ClaudeMdLinkType = $null
          Action          = $null
        }

        # Boundary guard: in a sprint context, never write CLAUDE.md into a stable
        # worktree. A repo with no sprint worktree this sprint is listed under its
        # stable folder name; writing here would violate stable-worktree boundary
        # rules and seed sprint-base-derived content into a stable repo. Skip it.
        if ($repositoryEntry.Skipped) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Skipping stable worktree '$repoName' (no sprint worktree this sprint); CLAUDE.md left untouched to honor stable-worktree boundary."
          $repoResult.Skipped = $true
          $result.RepositoryResults += $repoResult
          $result.RepositoriesProcessed++
          continue
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Processing repository: $repoName"

        try {
          # Step 6a: Read the per-repo local overlay if present.
          # As of Task 9.34 the canonical local file is 'ai-local.md'; fall back to the
          # legacy 'CLAUDE-local.md' for repos not yet renamed.
          $localFilePath = Join-Path $repoFullPath 'ai-local.md'
          $localFileName = 'ai-local.md'
          if (-not (Test-Path $localFilePath -PathType Leaf)) {
            $legacyLocal = Join-Path $repoFullPath 'CLAUDE-local.md'
            if (Test-Path $legacyLocal -PathType Leaf) {
              $localFilePath = $legacyLocal
              $localFileName = 'CLAUDE-local.md'
            }
          }
          $localContent = $null
          $localLastModified = $null

          if (Test-Path $localFilePath -PathType Leaf) {
            $localContent = Get-Content -Path $localFilePath -Raw -ErrorAction Stop
            $localLastModified = (Get-Item $localFilePath -ErrorAction Stop).LastWriteTime
            $repoResult.HasLocal = $true
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Found $localFileName for $repoName"
          } else {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "No ai-local.md/CLAUDE-local.md found for $repoName; using base only"
          }

          # Step 6b: Build the provenance table
          $dateFormat = 'yyyy-MM-dd HH:mm:ss'
          $claudeMdPath = Join-Path $repoFullPath 'CLAUDE.md'
          $existingContent = if (Test-Path -LiteralPath $claudeMdPath -PathType Leaf) {
            Get-Content -LiteralPath $claudeMdPath -Raw -ErrorAction Stop
          } else {
            $null
          }
          $existingCombinedTimestamp = $null
          if ($existingContent -match '\| CLAUDE\.md \(combined\) \| (?<Timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \|') {
            $existingCombinedTimestamp = $Matches.Timestamp
          }
          $combinedTimestamp = if ($existingCombinedTimestamp) {
            $existingCombinedTimestamp
          } else {
            (Get-Date).ToString($dateFormat)
          }
          $tableLines = @(
            ''
            '---'
            ''
            '<!-- CLAUDE.md provenance - generated by Build-CLAUDEPerRepository -->'
            ''
            '| Source File    | Last Modified            |'
            '| -------------- | ------------------------ |'
            "| CLAUDE-base.md | $($baseLastModified.ToString($dateFormat)) |"
          )
          if ($localLastModified) {
            $tableLines += "| $localFileName | $($localLastModified.ToString($dateFormat)) |"
          }
          $tableLines += "| CLAUDE.md (combined) | $combinedTimestamp |"
          $tableLines += @(
            ''
            '---'
            ''
          )
          $provenanceBlock = $tableLines -join "`n"

          # Step 6c: Combine local + provenance + base into CLAUDE.md
          $combinedParts = @()
          if ($localContent) {
            $combinedParts += $localContent.TrimEnd()
          }
          $combinedParts += $provenanceBlock
          $combinedParts += $baseContent.TrimEnd()
          $combinedParts += ''

          $combinedContent = ($combinedParts -join "`n")

          # Task 10.14.c (Wrong CLAUDE.md): verify the write target is the literal worktree-root
          # file, not a junction or symlink pointing elsewhere. Resolve-Path follows junctions,
          # so $repoFullPath could silently differ from the path the user inspects in VS Code.
          $claudeMdLinkType = $null
          if (Test-Path -LiteralPath $claudeMdPath) {
            $claudeMdItem = Get-Item -LiteralPath $claudeMdPath -ErrorAction SilentlyContinue
            if ($claudeMdItem) {
              $claudeMdLinkType = $claudeMdItem.LinkType
              if ($claudeMdLinkType) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "CLAUDE.md at '$claudeMdPath' is a $claudeMdLinkType (Target: $($claudeMdItem.Target)). The write will follow the link and may land in an unexpected location."
              }
            }
          }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Writing CLAUDE.md for $repoName to: $claudeMdPath (LinkType: $($claudeMdLinkType ?? 'none'))"

          if ($null -ne $existingContent -and $existingContent -ceq $combinedContent) {
            $repoResult.Success = $true
            $repoResult.WrittenPath = $claudeMdPath
            $repoResult.ClaudeMdLinkType = $claudeMdLinkType
            $repoResult.Action = 'unchanged'
          } else {
            if ($existingCombinedTimestamp) {
              $combinedContent = $combinedContent -replace [regex]::Escape("| CLAUDE.md (combined) | $existingCombinedTimestamp |"), "| CLAUDE.md (combined) | $((Get-Date).ToString($dateFormat)) |"
            }
          }

          if (-not $repoResult.Success -and $PSCmdlet.ShouldProcess($claudeMdPath, 'Write combined CLAUDE.md')) {
            Set-Content -LiteralPath $claudeMdPath -Value $combinedContent -Encoding UTF8 -NoNewline -ErrorAction Stop
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Wrote CLAUDE.md for $repoName"
            $repoResult.Success = $true
            $repoResult.WrittenPath = $claudeMdPath
            $repoResult.ClaudeMdLinkType = $claudeMdLinkType
            $repoResult.Action = 'written'
          }
        } catch {
          $errorMessage = "Failed to build CLAUDE.md for '$repoName': $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          $repoResult.ErrorMessage = $errorMessage
          $result.Errors += $errorMessage
        }

        $result.RepositoryResults += $repoResult
        $result.RepositoriesProcessed++
      }

      $result.Success = ($result.Errors.Count -eq 0)
    } catch {
      $errorMessage = "Build-CLAUDEPerRepository failed: $($_.Exception.Message)"
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

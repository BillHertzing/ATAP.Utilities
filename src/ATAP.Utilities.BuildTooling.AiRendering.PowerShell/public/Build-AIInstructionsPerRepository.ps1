<#
.SYNOPSIS
Materializes all per-repository AI instruction files for the current sprint.

.DESCRIPTION
Build-AIInstructionsPerRepository is the single SprintStart orchestration entry
point for per-repository AI instruction materialization. It resolves and parses
the Overview workspace once, computes the stable-worktree boundary once, and
passes that shared repository context to the three existing lane builders:

  1. Build-CLAUDEPerRepository
  2. Build-AGENTSPerRepository
  3. Build-AgentSpecificPerRepository

The lane builders retain ownership of their file-composition and copy logic.
The returned aggregate contains each lane result plus a per-repository view of
Success, Skipped, and Errors. A lane failure is recorded without preventing the
remaining lanes from running.

.PARAMETER WorktreeRoot
Optional path to the current worktree root. Defaults to the git toplevel of the
current working directory.

.PARAMETER WorkspacePath
Optional explicit path to the sprint Overview code-workspace file. When omitted,
the newest supported Overview sprint workspace in the worktree parent is used.

.OUTPUTS
System.Management.Automation.PSCustomObject
Returns the resolved workspace, lane results, per-repository aggregate results,
and errors.

.EXAMPLE
Build-AIInstructionsPerRepository

Discovers the sprint workspace once and materializes all four instruction files.

.EXAMPLE
Build-AIInstructionsPerRepository -WorkspacePath $workspacePath -WhatIf

Previews the three instruction lanes without changing files.

.NOTES
AI assisted using Powershell.instructions.md as guidelines.
#>

function Build-AIInstructionsPerRepository {
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
    $fn = 'Build-AIInstructionsPerRepository'
    $mn = 'ATAP.Utilities.BuildTooling.AiRendering.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    $builderOrder = @(
      [PSCustomObject]@{ Name = 'Build-CLAUDEPerRepository'; Property = 'Claude' }
      [PSCustomObject]@{ Name = 'Build-AGENTSPerRepository'; Property = 'Agents' }
      [PSCustomObject]@{ Name = 'Build-AgentSpecificPerRepository'; Property = 'AgentSpecific' }
    )

    foreach ($builder in $builderOrder) {
      $builderPath = Join-Path $PSScriptRoot "$($builder.Name).ps1"
      if (Test-Path -LiteralPath $builderPath -PathType Leaf) {
        . $builderPath
      } elseif (-not (Get-Command -Name $builder.Name -ErrorAction SilentlyContinue)) {
        $errorMessage = "Required builder '$($builder.Name)' is not available and was not found at '$builderPath'."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }
    }

    $result = [PSCustomObject]@{
      Success                = $false
      WorkspacePath          = $null
      WorkspaceReadCount     = 0
      SharedVSCodePath       = $null
      RepositoriesDiscovered = 0
      RepositoriesSkipped    = 0
      Builders               = [PSCustomObject]@{
        Claude        = $null
        Agents        = $null
        AgentSpecific = $null
      }
      RepositoryResults      = @()
      Errors                 = @()
    }
  }

  process {
    try {
      if (-not $PSBoundParameters.ContainsKey('WorktreeRoot') -or [string]::IsNullOrWhiteSpace($WorktreeRoot)) {
        $gitTopLevel = git rev-parse --show-toplevel 2>&1
        if ($LASTEXITCODE -ne 0) {
          throw "git rev-parse --show-toplevel failed: $gitTopLevel"
        }
        $WorktreeRoot = (Resolve-Path $gitTopLevel -ErrorAction Stop).Path
      } else {
        $WorktreeRoot = (Resolve-Path $WorktreeRoot -ErrorAction Stop).Path
      }

      $worktreeParent = Split-Path $WorktreeRoot -Parent
      if ($PSBoundParameters.ContainsKey('WorkspacePath') -and -not [string]::IsNullOrWhiteSpace($WorkspacePath)) {
        $workspaceFile = Get-Item -LiteralPath $WorkspacePath -ErrorAction Stop
      } else {
        $workspaceFiles = @()
        $workspaceFiles += Get-ChildItem -Path $worktreeParent -Filter 'Overview.Sprint.????.code-workspace' -File -ErrorAction SilentlyContinue
        # Legacy compatibility only:
        $workspaceFiles += Get-ChildItem -Path $worktreeParent -Filter 'Overview-wt-sprint????.code-workspace' -File -ErrorAction SilentlyContinue
        $workspaceFiles += Get-ChildItem -Path $worktreeParent -Filter 'Overview.Sprint????.code-workspace' -File -ErrorAction SilentlyContinue
        $workspaceFiles += Get-ChildItem -Path $worktreeParent -Filter 'OverviewSprint????.code-workspace' -File -ErrorAction SilentlyContinue
        if ($workspaceFiles.Count -eq 0) {
          throw "No Overview sprint code-workspace file found in '$worktreeParent'."
        }
        $workspaceFile = $workspaceFiles |
          Sort-Object LastWriteTime, Name -Descending |
          Select-Object -First 1
      }

      $workspaceFile = Get-Item -LiteralPath $workspaceFile.FullName -ErrorAction Stop
      $result.WorkspacePath = $workspaceFile.FullName
      $workspaceRoot = Split-Path $workspaceFile.FullName -Parent

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Reading workspace once: $($workspaceFile.FullName)"
      $workspaceContent = Get-Content -LiteralPath $workspaceFile.FullName -Raw -ErrorAction Stop
      $result.WorkspaceReadCount++
      $cleanedJson = $workspaceContent -replace ',\s*([}\]])', '$1'
      $workspaceData = $cleanedJson | ConvertFrom-Json -ErrorAction Stop
      if (-not $workspaceData.folders) {
        throw "Workspace file '$($workspaceFile.FullName)' has no folders section."
      }

      $folderPaths = @($workspaceData.folders | ForEach-Object { [string]$_.path })
      $sprintWorktreePattern = '-wt-\d+-Sprint-\d{4}-work-items$'
      $hasEphemeral = [bool]$workspaceData.PSObject.Properties['sprintEphemeral'] -and $null -ne $workspaceData.sprintEphemeral
      $hasSprintFolder = @($folderPaths | Where-Object { $_ -match $sprintWorktreePattern }).Count -gt 0
      $isSprintContext = $hasEphemeral -or $hasSprintFolder

      $repositories = @()
      foreach ($relativePath in $folderPaths) {
        $candidatePath = if ([IO.Path]::IsPathRooted($relativePath)) {
          $relativePath
        } else {
          Join-Path $workspaceRoot $relativePath
        }

        $resolvedPath = $null
        $resolutionError = $null
        try {
          $resolvedPath = (Resolve-Path -LiteralPath $candidatePath -ErrorAction Stop).Path
        } catch {
          $resolutionError = "Repository path does not exist: $candidatePath"
          $result.Errors += $resolutionError
        }

        $repositoryName = if ($resolvedPath) {
          Split-Path $resolvedPath -Leaf
        } else {
          Split-Path $candidatePath -Leaf
        }
        $skipped = $isSprintContext -and $repositoryName -notmatch $sprintWorktreePattern

        $repositories += [PSCustomObject]@{
          Repository      = $repositoryName
          RelativePath    = $relativePath
          Path            = $resolvedPath
          Skipped         = $skipped
          ResolutionError = $resolutionError
        }
      }

      $sharedRepositories = @($repositories | Where-Object {
          -not $_.ResolutionError -and $_.Repository -match '^SharedVSCode(?:-wt-\d+-Sprint-\d{4}-work-items)?$'
        })
      if ($sharedRepositories.Count -ne 1) {
        throw "Expected exactly one SharedVSCode folder in '$($workspaceFile.FullName)'; found $($sharedRepositories.Count)."
      }

      $result.SharedVSCodePath = $sharedRepositories[0].Path
      $result.RepositoriesDiscovered = $repositories.Count
      $result.RepositoriesSkipped = @($repositories | Where-Object Skipped).Count

      $repositoryContext = [PSCustomObject]@{
        WorkspacePath        = $workspaceFile.FullName
        WorkspaceRoot        = $workspaceRoot
        SharedVSCodePath     = $result.SharedVSCodePath
        IsSprintContext      = $isSprintContext
        SprintWorktreePattern = $sprintWorktreePattern
        Repositories         = $repositories
      }

      foreach ($builder in $builderOrder) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Running $($builder.Name)"
        try {
          $builderResult = & $builder.Name -RepositoryContext $repositoryContext -WhatIf:$WhatIfPreference
          $result.Builders.$($builder.Property) = $builderResult
          if ($builderResult.PSObject.Properties['Errors']) {
            $result.Errors += @($builderResult.Errors)
          }
        } catch {
          $errorMessage = "$($builder.Name) failed: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          $result.Errors += $errorMessage
        }
      }

      foreach ($repository in $repositories) {
        $laneResults = [ordered]@{}
        $repositoryErrors = @()
        $laneSuccess = $true

        foreach ($builder in $builderOrder) {
          $builderResult = $result.Builders.$($builder.Property)
          $laneResult = if ($builderResult -and $builderResult.PSObject.Properties['RepositoryResults']) {
            $builderResult.RepositoryResults |
              Where-Object { $_.Repository -eq $repository.Repository } |
              Select-Object -First 1
          } else {
            $null
          }
          $laneResults[$builder.Property] = $laneResult

          if ($laneResult -and $laneResult.PSObject.Properties['ErrorMessage'] -and $laneResult.ErrorMessage) {
            $repositoryErrors += $laneResult.ErrorMessage
          }
          if (-not $repository.Skipped -and (-not $laneResult -or
              ($laneResult.PSObject.Properties['Success'] -and -not $laneResult.Success))) {
            $laneSuccess = $false
          }
        }

        if ($repository.ResolutionError) {
          $repositoryErrors += $repository.ResolutionError
          $laneSuccess = $false
        }

        $result.RepositoryResults += [PSCustomObject]@{
          Repository = $repository.Repository
          Path       = $repository.Path
          Skipped    = $repository.Skipped
          Success    = ($repository.Skipped -or ($laneSuccess -and $repositoryErrors.Count -eq 0))
          Lanes      = [PSCustomObject]$laneResults
          Errors     = $repositoryErrors
        }
      }

      $result.Errors = @($result.Errors | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
      $result.Success = ($result.Errors.Count -eq 0)
    } catch {
      $errorMessage = "Build-AIInstructionsPerRepository failed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.Errors += $errorMessage
      $result.Success = $false
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    $result
  }
}

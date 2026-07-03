function Invoke-SprintEndLifecycle {
  <#
  .SYNOPSIS
  Orchestrates the typed SprintEnd close workflow.

  .DESCRIPTION
  Coordinates context detection, command contracts, module readiness, one-pass
  worktree inspection, AIAdapter/template boundary reset, GitHub PR/issue close,
  sprint history, sprint-specific handoff generation, infrastructure cleanup,
  and final boundary verification. Destructive phases require explicit switches
  and honor WhatIf.

  This cmdlet removes sprint databases while retaining permanent SQL Server
  instances. It never deletes Bitwarden secrets and never marks a synthetic
  "sprint complete" task.

  .PARAMETER GitRoot
  Parent directory containing repositories and sprint worktrees.

  .PARAMETER PlanningRoot
  Active _Planning sprint worktree.

  .PARAMETER SharedVSCodeWorktreePath
  SharedVSCode sprint worktree used as the canonical boundary source.

  .PARAMETER WorktreePaths
  Sprint worktrees included in the close.

  .PARAMETER BuiltModule
  Modules built during the sprint, each with Name and Version properties.

  .PARAMETER ApplyBoundary
  Applies the SprintEnd AIAdapter/template boundary reset.

  .PARAMETER CreatePullRequests
  Creates missing draft PRs and ensures closing keywords.

  .PARAMETER MergePullRequests
  Merges ready PRs and verifies originating issues close.

  .PARAMETER ArchiveHistory
  Copies dotted sprint task artifacts into SprintHistory.

  .PARAMETER VerifyCheckpoints
  Verifies every selected worktree has a reachable canonical Planning checkpoint.

  .PARAMETER WriteHandoff
  Generates HANDOFF.SprintNNNN.md.

  .PARAMETER CloseOverview
  Updates Overview.code-workspace and archives OverviewSprintNNNN.code-workspace.

  .PARAMETER CleanupInfrastructure
  Drops sprint databases, clears BuildMaster variables, and reasserts stable boundary.

  .PARAMETER TestFreshShell
  Includes profile-enabled fresh-shell verification in the final boundary audit.

  .PARAMETER ThrowOnFailure
  Throws when any required phase fails.

  .OUTPUTS
  PSCustomObject containing compact phase results.

  .EXAMPLE
  Invoke-SprintEndLifecycle -GitRoot C:\Repos -PlanningRoot C:\Repos\_Planning-wt-20-Sprint-0010-work-items `
    -SharedVSCodeWorktreePath C:\Repos\SharedVSCode-wt-48-Sprint-0010-work-items -WorktreePaths $paths -WhatIf

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$GitRoot,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$PlanningRoot,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$SharedVSCodeWorktreePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorktreePaths,

    [Parameter()]
    [object[]]$BuiltModule = @(),

    [Parameter()]
    [switch]$ApplyBoundary,

    [Parameter()]
    [switch]$CreatePullRequests,

    [Parameter()]
    [switch]$MergePullRequests,

    [Parameter()]
    [switch]$ArchiveHistory,

    [Parameter()]
    [switch]$VerifyCheckpoints,

    [Parameter()]
    [switch]$WriteHandoff,

    [Parameter()]
    [switch]$CloseOverview,

    [Parameter()]
    [switch]$CleanupInfrastructure,

    [Parameter()]
    [switch]$TestFreshShell,

    [Parameter()]
    [switch]$ThrowOnFailure
  )

  begin {
    $fn = 'Invoke-SprintEndLifecycle'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $gitRootFull = [IO.Path]::GetFullPath($GitRoot)
    $planningRootFull = [IO.Path]::GetFullPath($PlanningRoot)
    $worktreeSet = [System.Collections.Generic.List[string]]::new()
    foreach ($worktreePath in @($WorktreePaths) + @($planningRootFull)) {
      $fullPath = [IO.Path]::GetFullPath($worktreePath)
      if (-not @($worktreeSet | Where-Object { [StringComparer]::OrdinalIgnoreCase.Equals($_, $fullPath) })) {
        [void]$worktreeSet.Add($fullPath)
      }
    }
    $worktreeFullPaths = $worktreeSet.ToArray()
    $phases = [ordered]@{}
    $failures = [System.Collections.Generic.List[string]]::new()

    $phases.Context = Get-SprintEndContext -GitRoot $gitRootFull -CurrentPath $planningRootFull
    if (-not $phases.Context.Ok) { [void]$failures.Add('Context') }

    $closePlan = foreach ($worktreePath in $worktreeFullPaths) {
      $leaf = Split-Path -Path $worktreePath -Leaf
      $stableName = $leaf -replace '-wt-\d+-Sprint-\d{4}-work-items$', ''
      [PSCustomObject]@{
        WorktreePath             = $worktreePath
        WorktreeName             = $leaf
        RepositoryName           = $stableName
        IsPlanningWorktree       = [StringComparer]::OrdinalIgnoreCase.Equals($worktreePath, $planningRootFull)
        PullRequestClosePlanned  = [bool]($CreatePullRequests -or $MergePullRequests)
        PullRequestMergePlanned  = [bool]$MergePullRequests
        BranchDeletePlanned      = [bool]$WriteHandoff
        WorktreeRemovalPlanned   = [bool]$WriteHandoff
      }
    }
    $phases.ClosePlan = @($closePlan)

    $phases.CommandSurface = Test-SprintEndCommandSurface
    if (-not $phases.CommandSurface.Ok) { [void]$failures.Add('CommandSurface') }

    $prerequisiteParameters = @{
      RequiredRepoWorktrees = $worktreeFullPaths
      BuiltModule           = $BuiltModule
    }
    $phases.Prerequisites = Test-SprintPrerequisites @prerequisiteParameters
    if (-not $phases.Prerequisites.AllOk) { [void]$failures.Add('Prerequisites') }

    $phases.WorktreeState = Test-SprintEndWorktreeState -WorktreePaths $worktreeFullPaths
    if (-not $phases.WorktreeState.Ok) { [void]$failures.Add('WorktreeState') }

    if ($VerifyCheckpoints -and $phases.Context.Ok) {
      $phases.CheckpointCoverage = Test-SprintCheckpointCoverage `
        -PlanningRoot $planningRootFull `
        -SprintNumber ([int]$phases.Context.ClosedSprintNumber) `
        -WorktreePaths $worktreeFullPaths
      if (-not $phases.CheckpointCoverage.Ok) {
        [void]$failures.Add('CheckpointCoverage')
      }
    } else {
      $phases.CheckpointCoverage = $null
    }

    $phases.RetrospectiveNotebook = [PSCustomObject]@{ Ok = $true; Message = 'Notebook check skipped.' }
    if ($phases.Context.Ok) {
      $notebookName = "Notebook-SprintWorkSession-$($phases.Context.ClosedSprintNumber)-End.md"
      $notebookPath = Join-Path $planningRootFull 'SprintRetrospective' | Join-Path -ChildPath $notebookName
      if (-not (Test-Path -LiteralPath $notebookPath -PathType Leaf)) {
        $phases.RetrospectiveNotebook.Ok = $false
        $phases.RetrospectiveNotebook.Message = "Closing sprint retrospective notebook not found at: $notebookPath"
        [void]$failures.Add('RetrospectiveNotebook')
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $phases.RetrospectiveNotebook.Message
      } else {
        $phases.RetrospectiveNotebook.Message = "Closing sprint retrospective notebook found: $notebookName"
      }
    }

    if ($failures.Count -eq 0 -and $ApplyBoundary) {
      $boundaryParameters = @{
        Boundary                    = 'End'
        SharedVSCodeWorktreePath    = [IO.Path]::GetFullPath($SharedVSCodeWorktreePath)
        WorktreePaths               = $worktreeFullPaths
        Confirm                     = $false
      }
      if ($WhatIfPreference) { $boundaryParameters.WhatIf = $true }
      $phases.BoundaryReset = Set-SprintBoundaryContext @boundaryParameters
      if (@($phases.BoundaryReset.Errors).Count -gt 0) { [void]$failures.Add('BoundaryReset') }

      $templateResults = [System.Collections.Generic.List[object]]::new()
      foreach ($worktreePath in $worktreeFullPaths) {
        $workspaceFiles = @(Get-ChildItem -LiteralPath $worktreePath -Filter '*.code-workspace' -File -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName)
        if ($workspaceFiles.Count -gt 0) {
          try {
            $assertion = Assert-MainBranchTemplateRef -WorkspaceFiles $workspaceFiles
            [void]$templateResults.Add([PSCustomObject]@{ Path = $worktreePath; Ok = $true; Result = $assertion })
          } catch {
            [void]$templateResults.Add([PSCustomObject]@{ Path = $worktreePath; Ok = $false; Error = $_.Exception.Message })
            [void]$failures.Add('TemplateRef')
          }
        }
      }
      $phases.TemplateRef = $templateResults.ToArray()
    } else {
      $phases.BoundaryReset = $null
      $phases.TemplateRef = @()
    }

    $githubResults = [System.Collections.Generic.List[object]]::new()
    if ($failures.Count -eq 0 -and ($CreatePullRequests -or $MergePullRequests)) {
      foreach ($worktreePath in $worktreeFullPaths) {
        $githubParameters = @{
          RepoPath        = $worktreePath
          CreateIfMissing = [bool]$CreatePullRequests
          Merge           = [bool]$MergePullRequests
          Confirm         = $false
        }
        if ($WhatIfPreference) { $githubParameters.WhatIf = $true }
        try {
          $githubResult = Invoke-SprintEndGitHubClose @githubParameters
          [void]$githubResults.Add($githubResult)
          if (-not $githubResult.Ok) { [void]$failures.Add("GitHub:$($githubResult.Repository)") }
        } catch {
          [void]$githubResults.Add([PSCustomObject]@{
              RepoPath = $worktreePath; Ok = $false; Error = $_.Exception.Message
            })
          [void]$failures.Add("GitHub:$worktreePath")
        }
      }
    }
    $phases.GitHub = $githubResults.ToArray()

    if ($failures.Count -eq 0 -and $ArchiveHistory -and $phases.Context.Ok) {
      $historyParameters = @{
        PlanningRoot = $planningRootFull
        SprintNumber = [int]$phases.Context.ClosedSprintNumber
        Confirm = $false
      }
      if ($WhatIfPreference) { $historyParameters.WhatIf = $true }
      $phases.History = Save-SprintHistoryArtifacts @historyParameters
      if (-not $phases.History.Ok) { [void]$failures.Add('History') }
    } else {
      $phases.History = $null
    }

    if ($failures.Count -eq 0 -and $CloseOverview -and $phases.Context.Ok) {
      $overviewParameters = @{
        GitRoot       = $gitRootFull
        PlanningRoot  = $planningRootFull
        SprintNumber  = [int]$phases.Context.ClosedSprintNumber
        Confirm       = $false
      }
      if ($WhatIfPreference) { $overviewParameters.WhatIf = $true }
      $phases.Overview = Invoke-SprintEndOverviewClose @overviewParameters
      if (-not $phases.Overview.Ok) { [void]$failures.Add('Overview') }
    } else {
      $phases.Overview = $null
    }

    if ($failures.Count -eq 0 -and $WriteHandoff) {
      $handoffParameters = @{
        GitRoot       = $gitRootFull
        WorktreePaths = $worktreeFullPaths
        SprintNumber  = $phases.Context.ClosedSprintNumber
        Confirm       = $false
      }
      if ($WhatIfPreference) { $handoffParameters.WhatIf = $true }
      $phases.Handoff = New-SprintEndHandoff @handoffParameters
    } else {
      $phases.Handoff = $null
    }

    if ($failures.Count -eq 0 -and $CleanupInfrastructure) {
      $cleanupParameters = @{
        GitRoot = $gitRootFull
        Apply   = $true
        Confirm = $false
      }
      if ($WhatIfPreference) { $cleanupParameters.WhatIf = $true }
      $phases.InfrastructureCleanup = Invoke-SprintEndInfrastructureCleanup @cleanupParameters
      if (-not $phases.InfrastructureCleanup.Ok) { [void]$failures.Add('InfrastructureCleanup') }
    } else {
      $phases.InfrastructureCleanup = $null
    }

    if (-not $WhatIfPreference -and ($ApplyBoundary -or $CleanupInfrastructure)) {
      $phases.FinalBoundary = Test-SprintEndBoundaryState `
        -GitRoot $gitRootFull `
        -SearchRoots $worktreeFullPaths `
        -TestFreshShell:$TestFreshShell
      if (-not $phases.FinalBoundary.Ok) { [void]$failures.Add('FinalBoundary') }
    } else {
      $phases.FinalBoundary = [PSCustomObject]@{
        Ok = $true
        Planned = [bool]($ApplyBoundary -or $CleanupInfrastructure)
        Skipped = $true
        SearchRoots = $worktreeFullPaths
        TestFreshShell = [bool]$TestFreshShell
        Detail = 'Final boundary verification is planned after live mutations are applied.'
      }
    }

    $uniqueFailures = @($failures | Select-Object -Unique)
    $result = [PSCustomObject]@{
      Ok                         = ($uniqueFailures.Count -eq 0)
      DryRun                     = [bool]$WhatIfPreference
      ClosedSprintNumber         = $phases.Context.ClosedSprintNumber
      NextSprintNumber           = $phases.Context.NextSprintNumber
      Phases                     = [PSCustomObject]$phases
      Failures                   = $uniqueFailures
      DatabaseCleanupMode        = 'SprintDatabasesOnly'
      BitwardenSecretsRemoved    = $false
      SqlInstancesRetained       = $true
      SyntheticTaskCompleted     = $false
    }
    if (-not $result.Ok -and $ThrowOnFailure) {
      throw "SprintEnd lifecycle failed: $($result.Failures -join ', ')."
    }
    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

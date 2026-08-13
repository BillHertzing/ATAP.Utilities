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

  .PARAMETER ProfiledRemotingPolicy
  Controls the profiled-remoting boundary concern. Auto is the safe default;
  Disabled opts out, while Required fails when remoting is unavailable.

  .PARAMETER CreatePullRequests
  Creates missing draft PRs and ensures closing keywords.

  .PARAMETER MergePullRequests
  Merges ready PRs and verifies originating issues close.

  .PARAMETER MergeAuthorizationConfirmed
  Records that the operator already authorized this close's pull-request merge,
  so downstream calls do not re-ask the question the operator answered at the
  dry-run gate. It suppresses duplicate prompts only; it never authorizes a
  merge that was not requested with -MergePullRequests.

  .PARAMETER DelegationMode
  'None' when this orchestrator performs GitHub operations itself, 'Delegated'
  when a PR/version-control agent performs them on its behalf. A delegate must
  relay a named authorization source rather than raising its own prompt.

  .PARAMETER DelegatedAuthorizationSource
  Provenance for the authorization relayed to the delegate, for example
  'Operator:2026-08-03T09:15:00-06:00'. Required when DelegationMode is
  'Delegated'.

  .PARAMETER ArchiveHistory
  Copies dotted sprint task artifacts into SprintHistory.

  .PARAMETER VerifyCheckpoints
  Verifies every selected worktree has a reachable canonical Planning checkpoint.

  .PARAMETER WriteHandoff
  Generates HANDOFF.SprintNNNN.md.

  .PARAMETER CloseOverview
  Updates Overview.code-workspace and archives Overview.Sprint.NNNN.code-workspace.

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
    [ValidateSet('Disabled', 'Auto', 'Required')]
    [string]$ProfiledRemotingPolicy = 'Auto',

    [Parameter()]
    [switch]$CreatePullRequests,

    [Parameter()]
    [switch]$MergePullRequests,

    [Parameter()]
    [switch]$MergeAuthorizationConfirmed,

    [Parameter()]
    [ValidateSet('None', 'Delegated')]
    [string]$DelegationMode = 'None',

    [Parameter()]
    [AllowEmptyString()]
    [string]$DelegatedAuthorizationSource,

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

    # Task 14.10. Every worktree this close will mutate must be a sprint
    # worktree. Gate the whole close plan once, before any phase runs, so a
    # stable path substituted into WorktreePaths is rejected up front instead of
    # surfacing incidentally from inside whichever helper happens to touch it
    # first. This is the regression boundary for the Sprint 0013 behavior that
    # wrote remediation changes into stable worktrees.
    $phases.WriteTargetBoundary = Test-SprintEndWriteTarget `
      -Path $worktreeFullPaths `
      -GitRoot $gitRootFull `
      -Operation 'SprintEndClosePlan'
    if (-not $phases.WriteTargetBoundary.Ok) { [void]$failures.Add('WriteTargetBoundary') }

    # Task 14.11. Resolve every approval concern deterministically before any
    # phase asks the operator anything, so a single authorization is recorded
    # once rather than re-evaluated by each layer that can prompt.
    $approvalParameters = @{
      MergePullRequests           = [bool]$MergePullRequests
      MergeAuthorizationConfirmed = [bool]$MergeAuthorizationConfirmed
      DelegationMode              = $DelegationMode
      WorktreePaths               = $worktreeFullPaths
    }
    if ($PSBoundParameters.ContainsKey('DelegatedAuthorizationSource')) {
      $approvalParameters.DelegatedAuthorizationSource = $DelegatedAuthorizationSource
    }
    $phases.ApprovalPlan = Get-SprintEndApprovalPlan @approvalParameters
    if (-not $phases.ApprovalPlan.Ok) { [void]$failures.Add('ApprovalPlan') }

    $phases.CommandSurface = Test-SprintEndCommandSurface
    if (-not $phases.CommandSurface.Ok) { [void]$failures.Add('CommandSurface') }

    $prerequisiteParameters = @{
      RequiredRepoWorktrees = $worktreeFullPaths
      BuiltModule           = $BuiltModule
    }
    # Task 14.11. When no selected worktree tracks a packages.lock.json, the
    # lock-file guard is skipped because it cannot apply -- not because anyone
    # answered a prompt about runner availability.
    $lockFileConcern = @($phases.ApprovalPlan.Concerns | Where-Object Concern -eq 'NuGetLockFileRunner') | Select-Object -First 1
    if ($lockFileConcern -and $lockFileConcern.Decision -eq 'NotApplicable') {
      $prerequisiteParameters.SkipLockFileGuard = $true
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

    $checkpointConfirmed = [bool](
      $VerifyCheckpoints -and
      $null -ne $phases.CheckpointCoverage -and
      $phases.CheckpointCoverage.Ok
    )
    if ($ApplyBoundary -and -not $checkpointConfirmed) {
      [void]$failures.Add('CheckpointCoverageRequiredForBoundary')
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
        ProfiledRemotingPolicy      = $ProfiledRemotingPolicy
        AllowUserGlobalWrite        = $true
        CheckpointConfirmed         = $checkpointConfirmed
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
            $assertionParameters = @{ WorkspaceFiles = $workspaceFiles }
            if ($WhatIfPreference) { $assertionParameters.WhatIf = $true }
            $assertion = Assert-MainBranchTemplateRef @assertionParameters
            [void]$templateResults.Add([PSCustomObject]@{
                Path = $worktreePath
                Ok = $true
                PlannedAfterBoundary = [bool]$WhatIfPreference
                CurrentStateWouldThrow = [bool]$assertion.WouldThrow
                Result = $assertion
              })
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

    # Task 14.11. A live merge runs only after the operator authorization is
    # recorded. The dry run plans the merge without it, because -WhatIf mutates
    # nothing; a live run refuses rather than raising the prompt a second time
    # from inside a phase the operator has already approved as a whole.
    $mergeAuthorized = [bool]($MergeAuthorizationConfirmed -or $WhatIfPreference)
    if ($MergePullRequests -and -not $mergeAuthorized) {
      [void]$failures.Add('MergeAuthorizationRequired')
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
        -Message 'A live pull-request merge was requested without recorded operator authorization. Re-run with -MergeAuthorizationConfirmed after the operator approves the dry run.'
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
          if ($WhatIfPreference) {
            $githubResult | Add-Member -NotePropertyName PlannedAfterDryRun -NotePropertyValue $true -Force
            $githubResult | Add-Member -NotePropertyName CurrentStateOk -NotePropertyValue ([bool]$githubResult.Ok) -Force
          }
          [void]$githubResults.Add($githubResult)
          if (-not $WhatIfPreference -and -not $githubResult.Ok) {
            [void]$failures.Add("GitHub:$($githubResult.Repository)")
          }
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
        ProfiledRemotingPolicy = $ProfiledRemotingPolicy
        Confirm       = $false
      }
      if ($WhatIfPreference) { $handoffParameters.WhatIf = $true }
      try {
        $phases.Handoff = New-SprintEndHandoff @handoffParameters
      } catch {
        $phases.Handoff = [PSCustomObject]@{
          Ok = $false
          Error = $_.Exception.Message
          WorktreePaths = $worktreeFullPaths
        }
        [void]$failures.Add('Handoff')
      }
    } else {
      $phases.Handoff = $null
    }

    if ($failures.Count -eq 0 -and $CleanupInfrastructure) {
      $cleanupParameters = @{
        GitRoot = $gitRootFull
        ProfiledRemotingPolicy = $ProfiledRemotingPolicy
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
      StableWorktreeWritesPlanned = @($phases.WriteTargetBoundary.BlockedPaths)
      OperatorPromptsRequired    = @($phases.ApprovalPlan.RequiredPrompts)
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

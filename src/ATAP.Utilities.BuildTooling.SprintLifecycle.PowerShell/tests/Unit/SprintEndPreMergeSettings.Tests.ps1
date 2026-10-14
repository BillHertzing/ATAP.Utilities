#Requires -Version 7.0

BeforeAll {
  # Load the actual lifecycle only; every dependency is a local fail-closed
  # stub or a Pester mock. No installed lifecycle or host boundary runs here.
  function Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  function Get-SprintEndContext { param($GitRoot, $CurrentPath) throw 'Unmocked context' }
  function Test-SprintEndWriteTarget { param($Path, $GitRoot, $Operation) throw 'Unmocked write gate' }
  function Get-SprintEndApprovalPlan {
    param($MergePullRequests, $MergeAuthorizationConfirmed, $DelegationMode, $WorktreePaths)
    throw 'Unmocked approval plan'
  }
  function Test-SprintEndCommandSurface { throw 'Unmocked command surface' }
  function Test-SprintPrerequisites { param($RequiredRepoWorktrees, $BuiltModule) throw 'Unmocked prerequisites' }
  function Test-SprintEndWorktreeState { param($WorktreePaths) throw 'Unmocked worktree state' }
  function Test-SprintCheckpointCoverage {
    param($PlanningRoot, $SprintNumber, $WorktreePaths, $ExternalDurabilityEvidence, $RequiredExternalReplicaKind)
    throw 'Unmocked coverage'
  }
  function Set-SprintBoundaryContext {
    [CmdletBinding(SupportsShouldProcess)]
    param($Boundary, $GitRoot, $SharedVSCodeWorktreePath, $WorktreePaths,
      $ProfiledRemotingPolicy, $AllowUserGlobalWrite, $CheckpointConfirmed,
      [switch]$SkipSharedVSCodeSettings)
    throw 'Unmocked boundary mutation'
  }
  function Assert-MainBranchTemplateRef {
    [CmdletBinding(SupportsShouldProcess)]
    param($WorkspaceFiles)
    throw 'Unmocked template mutation'
  }
  function Test-SprintEndBoundaryState {
    param($GitRoot, $SearchRoots, $WorktreePaths, $TestFreshShell)
    throw 'Unmocked final audit'
  }
  function New-SprintEndHandoff {
    [CmdletBinding(SupportsShouldProcess)]
    param($GitRoot, $WorktreePaths, $SprintNumber, $ProfiledRemotingPolicy,
      [AllowEmptyCollection()][object[]]$DatabaseCleanupTargets)
    throw 'Unmocked handoff write'
  }
  function Invoke-SprintEndInfrastructureCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    param($GitRoot, $WorktreePaths, $ProfiledRemotingPolicy, [switch]$Apply,
      [AllowEmptyCollection()][object[]]$DatabaseCleanupTargets)
    throw 'Unmocked infrastructure mutation'
  }
  . (Join-Path $PSScriptRoot '../../public/Invoke-SprintEndLifecycle.ps1')
}

Describe 'SprintEnd premerge shared settings deferral' -Tag 'Unit' {
  BeforeEach {
    $gitRoot = Join-Path $TestDrive 'GitHub'
    $planning = Join-Path $gitRoot '_Planning-wt-35-Sprint-0015-work-items'
    $shared = Join-Path $gitRoot 'SharedVSCode-wt-64-Sprint-0015-work-items'
    $retrospective = Join-Path $planning 'SprintRetrospective'
    New-Item -ItemType Directory -Path $retrospective, $shared -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $retrospective 'Notebook-SprintWorkSession-0015-End.md') -Value 'fixture'
    Set-Content -LiteralPath (Join-Path $shared 'SharedVSCode.code-workspace') -Value '{}'
    $script:lifecycleParameters = @{
      GitRoot = $gitRoot
      PlanningRoot = $planning
      SharedVSCodeWorktreePath = $shared
      WorktreePaths = @($planning, $shared)
      ApplyBoundary = $true
      VerifyCheckpoints = $true
      Confirm = $false
    }
    Mock Write-PSFMessage {}
    Mock Get-SprintEndContext { [PSCustomObject]@{ Ok = $true; ClosedSprintNumber = '0015'; NextSprintNumber = '0016' } }
    Mock Test-SprintEndWriteTarget { [PSCustomObject]@{ Ok = $true; BlockedPaths = @() } }
    Mock Get-SprintEndApprovalPlan { [PSCustomObject]@{ Ok = $true; Concerns = @(); RequiredPrompts = @() } }
    Mock Test-SprintEndCommandSurface { [PSCustomObject]@{ Ok = $true } }
    Mock Test-SprintPrerequisites { [PSCustomObject]@{ AllOk = $true } }
    Mock Test-SprintEndWorktreeState { [PSCustomObject]@{ Ok = $true } }
    Mock Test-SprintCheckpointCoverage { [PSCustomObject]@{ Ok = $true } }
    $script:boundaryCalls = @()
    Mock Set-SprintBoundaryContext {
      $script:boundaryCalls += [PSCustomObject]@{
        SkipBound = $PesterBoundParameters.ContainsKey('SkipSharedVSCodeSettings')
        SkipValue = [bool]$SkipSharedVSCodeSettings
        WhatIfBound = $PesterBoundParameters.ContainsKey('WhatIf')
        WhatIfValue = [bool]$PesterBoundParameters['WhatIf']
      }
      [PSCustomObject]@{ Errors = @() }
    }
    Mock Assert-MainBranchTemplateRef { [PSCustomObject]@{ WouldThrow = $false } }
    Mock Test-SprintEndBoundaryState { [PSCustomObject]@{ Ok = $true } }
    $script:targetCalls = @()
    Mock New-SprintEndHandoff {
      $script:targetCalls += [PSCustomObject]@{
        Phase = 'Handoff'; Bound = $PesterBoundParameters.ContainsKey('DatabaseCleanupTargets')
        Targets = @($DatabaseCleanupTargets); Planned = [bool]$WhatIfPreference
      }
      [PSCustomObject]@{ Ok = $true }
    }
    Mock Invoke-SprintEndInfrastructureCleanup {
      $script:targetCalls += [PSCustomObject]@{
        Phase = 'Cleanup'; Bound = $PesterBoundParameters.ContainsKey('DatabaseCleanupTargets')
        Targets = @($DatabaseCleanupTargets); Planned = [bool]$WhatIfPreference
      }
      [PSCustomObject]@{ Ok = $true }
    }
  }

  It 'forwards explicit true and still audits the final stable boundary' {
    $result = Invoke-SprintEndLifecycle @lifecycleParameters -SkipSharedVSCodeSettings

    $result.Ok | Should -BeTrue
    $boundaryCalls.Count | Should -Be 1
    $boundaryCalls[0].SkipBound | Should -BeTrue
    $boundaryCalls[0].SkipValue | Should -BeTrue
    Should -Invoke Test-SprintEndBoundaryState -Times 1 -Exactly
    Should -Invoke Assert-MainBranchTemplateRef -Times 1 -Exactly
  }

  It 'leaves the dependency default untouched when the switch is absent' {
    $result = Invoke-SprintEndLifecycle @lifecycleParameters

    $result.Ok | Should -BeTrue
    $boundaryCalls[0].SkipBound | Should -BeFalse
    $boundaryCalls[0].SkipValue | Should -BeFalse
  }

  It 'forwards explicitly bound false without enabling deferral' {
    $result = Invoke-SprintEndLifecycle @lifecycleParameters -SkipSharedVSCodeSettings:$false

    $result.Ok | Should -BeTrue
    $boundaryCalls[0].SkipBound | Should -BeTrue
    $boundaryCalls[0].SkipValue | Should -BeFalse
  }

  It 'forwards WhatIf with deferral and skips the live final audit' {
    $result = Invoke-SprintEndLifecycle @lifecycleParameters -SkipSharedVSCodeSettings -WhatIf

    $result.Ok | Should -BeTrue
    $result.DryRun | Should -BeTrue
    $boundaryCalls[0].SkipValue | Should -BeTrue
    $boundaryCalls[0].WhatIfBound | Should -BeTrue
    $boundaryCalls[0].WhatIfValue | Should -BeTrue
    $result.Phases.FinalBoundary.Skipped | Should -BeTrue
    Should -Invoke Test-SprintEndBoundaryState -Times 0 -Exactly
    Should -Invoke Assert-MainBranchTemplateRef -Times 1 -Exactly -ParameterFilter { $PesterBoundParameters['WhatIf'] }
  }

  It 'does not bypass checkpoint durability when deferral is enabled' {
    Mock Test-SprintCheckpointCoverage { [PSCustomObject]@{ Ok = $false } }

    $result = Invoke-SprintEndLifecycle @lifecycleParameters -SkipSharedVSCodeSettings

    $result.Ok | Should -BeFalse
    $result.Failures | Should -Contain 'CheckpointCoverageRequiredForBoundary'
    Should -Invoke Set-SprintBoundaryContext -Times 0 -Exactly
    Should -Invoke Assert-MainBranchTemplateRef -Times 0 -Exactly
  }

  It 'reports a failed stable settings audit even when the boundary pass deferred settings' {
    Mock Test-SprintEndBoundaryState { [PSCustomObject]@{ Ok = $false } }

    $result = Invoke-SprintEndLifecycle @lifecycleParameters -SkipSharedVSCodeSettings

    $result.Ok | Should -BeFalse
    $result.Failures | Should -Contain 'FinalBoundary'
    Should -Invoke Test-SprintEndBoundaryState -Times 1 -Exactly
  }

  It 'forwards the exact reviewed matrix to handoff and cleanup in WhatIf' {
    $targets = @(
      [PSCustomObject]@{ InstanceName = 'DEVWHERTZING'; Databases = @('ATAPUtilities') }
      [PSCustomObject]@{ InstanceName = 'EXPWHERTZING'; Databases = @('ATAPUtilities', 'ATAPUtilities_S15_15205a_EXP_Rehearsal') }
      [PSCustomObject]@{ InstanceName = 'INTEGRATION'; Databases = @('ATAPUtilities') }
      [PSCustomObject]@{ InstanceName = 'QA'; Databases = @('ATAPUtilities') }
    )

    $result = Invoke-SprintEndLifecycle @lifecycleParameters -WriteHandoff -CleanupInfrastructure -DatabaseCleanupTargets $targets -WhatIf

    $result.Ok | Should -BeTrue
    $targetCalls.Count | Should -Be 2
    foreach ($call in $targetCalls) {
      $call.Bound | Should -BeTrue
      $call.Planned | Should -BeTrue
      ($call.Targets | ConvertTo-Json -Depth 4 -Compress) | Should -Be ($targets | ConvertTo-Json -Depth 4 -Compress)
    }
  }

  It 'retains helper target defaults when exact targets are omitted' {
    $result = Invoke-SprintEndLifecycle @lifecycleParameters -WriteHandoff -CleanupInfrastructure -WhatIf

    $result.Ok | Should -BeTrue
    $targetCalls.Count | Should -Be 2
    @($targetCalls | Where-Object Bound).Count | Should -Be 0
  }

  It 'forwards explicitly empty targets for fail-closed helper validation' {
    $result = Invoke-SprintEndLifecycle @lifecycleParameters -WriteHandoff -CleanupInfrastructure -DatabaseCleanupTargets @() -WhatIf

    $result.Ok | Should -BeTrue
    $targetCalls.Count | Should -Be 2
    foreach ($call in $targetCalls) {
      $call.Bound | Should -BeTrue
      $call.Targets.Count | Should -Be 0
    }
  }
}

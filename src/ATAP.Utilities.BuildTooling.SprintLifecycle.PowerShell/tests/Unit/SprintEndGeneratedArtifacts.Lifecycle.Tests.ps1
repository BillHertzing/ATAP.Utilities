#Requires -Version 7.0

# Tasks 16.91.a/b (SC-0470): Invoke-SprintEndLifecycle runs the R-38
# GeneratedArtifacts gate before any close effect and the opt-in pre-merge
# clear before any pull request work. Every dependency is a fail-closed stub
# or a Pester mock; nothing on the host is touched.

BeforeAll {
  function Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  function Set-UserSettingsSymlink {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$SharedVSCodeWorktreePath, [switch]$CheckOnly, [string[]]$WorktreePaths)
    throw 'Unmocked settings audit'
  }
  function Set-SprintLoginScheduledTaskTarget {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Boundary, [string]$GitRoot, [string]$LoginScriptPath, [string[]]$WorktreePaths, [switch]$CheckOnly)
    throw 'Unmocked login audit'
  }
  function Get-SprintEndContext { param($GitRoot, $CurrentPath) throw 'Unmocked context' }
  function Test-SprintEndWriteTarget { param($Path, $GitRoot, $Operation) throw 'Unmocked write gate' }
  function Get-SprintEndApprovalPlan {
    param($MergePullRequests, $MergeAuthorizationConfirmed, $DelegationMode, $WorktreePaths)
    throw 'Unmocked approval plan'
  }
  function Test-SprintEndCommandSurface { throw 'Unmocked command surface' }
  function Test-SprintPrerequisites { param($RequiredRepoWorktrees, $BuiltModule) throw 'Unmocked prerequisites' }
  function Test-SprintEndWorktreeState { param($WorktreePaths) throw 'Unmocked worktree state' }
  function Get-SprintGeneratedArtifactState { param($WorktreePaths, $PlanningRoot) throw 'Unmocked gate' }
  function Clear-SprintGeneratedArtifacts {
    [CmdletBinding(SupportsShouldProcess)]
    param($SprintNumber, $GitRoot, $WorktreePaths, $PlanningRoot, [switch]$Force)
    throw 'Unmocked clear'
  }
  function Invoke-SprintEndGitHubClose {
    [CmdletBinding(SupportsShouldProcess)]
    param($RepoPath, $CreateIfMissing, $Merge)
    throw 'Unmocked GitHub close'
  }
  . (Join-Path $PSScriptRoot '../../public/Invoke-SprintEndLifecycle.ps1')
}

Describe 'SprintEnd GeneratedArtifacts gate and pre-merge clear' -Tag 'Unit' {
  BeforeEach {
    $gitRoot = Join-Path $TestDrive 'GitHub'
    $planning = Join-Path $gitRoot '_Planning-wt-40-Sprint-0016-work-items'
    $ace = Join-Path $gitRoot 'Ace-wt-47-Sprint-0016-work-items'
    $retrospective = Join-Path $planning 'SprintRetrospective'
    New-Item -ItemType Directory -Path $retrospective, $ace -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $retrospective 'Notebook-SprintWorkSession-0016-End.md') -Value 'fixture'
    $script:lifecycleParameters = @{
      GitRoot = $gitRoot
      PlanningRoot = $planning
      SharedVSCodeWorktreePath = $ace
      WorktreePaths = @($ace)
      Confirm = $false
    }
    $script:trace = [System.Collections.Generic.List[string]]::new()
    Mock Get-SprintEndContext { [PSCustomObject]@{ Ok = $true; ClosedSprintNumber = '0016'; NextSprintNumber = '0017' } }
    Mock Test-SprintEndWriteTarget { [PSCustomObject]@{ Ok = $true; BlockedPaths = @() } }
    Mock Get-SprintEndApprovalPlan { [PSCustomObject]@{ Ok = $true; Concerns = @(); RequiredPrompts = @() } }
    Mock Test-SprintEndCommandSurface { [PSCustomObject]@{ Ok = $true } }
    Mock Test-SprintPrerequisites { [PSCustomObject]@{ AllOk = $true } }
    Mock Test-SprintEndWorktreeState { [PSCustomObject]@{ Ok = $true } }
    Mock Set-UserSettingsSymlink { [PSCustomObject]@{ Ok = $true } }
    Mock Set-SprintLoginScheduledTaskTarget { [PSCustomObject]@{ Ok = $true; Failures = @() } }
    Mock Get-SprintGeneratedArtifactState {
      $script:trace.Add('Gate')
      [PSCustomObject]@{ Ok = $true; TrackedPaths = @(); CitedPaths = @(); Failures = @() }
    }
    Mock Clear-SprintGeneratedArtifacts {
      $script:trace.Add('Clear')
      [PSCustomObject]@{ blocked = $false; errors = @(); filesRemoved = 3 }
    }
    Mock Invoke-SprintEndGitHubClose {
      $script:trace.Add('GitHub')
      [PSCustomObject]@{ Ok = $true; Repository = 'Ace' }
    }
  }

  It 'does not run the gate when no close effect is requested' {
    $result = Invoke-SprintEndLifecycle @lifecycleParameters

    $result.Ok | Should -BeTrue
    $result.Phases.GeneratedArtifacts | Should -BeNullOrEmpty
    Should -Invoke Get-SprintGeneratedArtifactState -Times 0 -Exactly
  }

  It 'runs the gate before creating pull requests and passes the full close set' {
    $result = Invoke-SprintEndLifecycle @lifecycleParameters -CreatePullRequests

    $result.Ok | Should -BeTrue
    @($script:trace) | Should -Be @('Gate', 'GitHub', 'GitHub')
    Should -Invoke Get-SprintGeneratedArtifactState -Times 1 -Exactly -ParameterFilter {
      @($WorktreePaths).Count -eq 2 -and $PlanningRoot -eq [IO.Path]::GetFullPath($planning)
    }
    Should -Invoke Clear-SprintGeneratedArtifacts -Times 0 -Exactly
  }

  It 'fails closed and creates no pull request when tracked _generated files exist' {
    Mock Get-SprintGeneratedArtifactState {
      [PSCustomObject]@{ Ok = $false; TrackedPaths = @([PSCustomObject]@{ Path = '_generated/x' }); CitedPaths = @()
        Failures = @('TrackedGeneratedArtifacts') }
    }

    $result = Invoke-SprintEndLifecycle @lifecycleParameters -CreatePullRequests -ClearGeneratedArtifacts

    $result.Ok | Should -BeFalse
    $result.Failures | Should -Contain 'GeneratedArtifacts'
    Should -Invoke Clear-SprintGeneratedArtifacts -Times 0 -Exactly
    Should -Invoke Invoke-SprintEndGitHubClose -Times 0 -Exactly
  }

  It 'fails closed when the gate itself throws' {
    Mock Get-SprintGeneratedArtifactState { throw 'git unavailable' }

    $result = Invoke-SprintEndLifecycle @lifecycleParameters -CreatePullRequests

    $result.Ok | Should -BeFalse
    $result.Failures | Should -Contain 'GeneratedArtifacts'
    Should -Invoke Invoke-SprintEndGitHubClose -Times 0 -Exactly
  }

  It 'clears sprint _generated after the gate and before any pull request work' {
    $result = Invoke-SprintEndLifecycle @lifecycleParameters -ClearGeneratedArtifacts -MergePullRequests -MergeAuthorizationConfirmed

    $result.Ok | Should -BeTrue
    @($script:trace)[0..1] | Should -Be @('Gate', 'Clear')
    Should -Invoke Clear-SprintGeneratedArtifacts -Times 1 -Exactly -ParameterFilter {
      $SprintNumber -eq '0016' -and $Force -and @($WorktreePaths).Count -eq 2 -and
        $PlanningRoot -eq [IO.Path]::GetFullPath($planning)
    }
  }

  It 'stops before pull request work when the clear is blocked' {
    Mock Clear-SprintGeneratedArtifacts { [PSCustomObject]@{ blocked = $true; errors = @('Refusing to clear') } }

    $result = Invoke-SprintEndLifecycle @lifecycleParameters -ClearGeneratedArtifacts -CreatePullRequests

    $result.Ok | Should -BeFalse
    $result.Failures | Should -Contain 'GeneratedClear'
    Should -Invoke Invoke-SprintEndGitHubClose -Times 0 -Exactly
  }

  It 'forwards WhatIf to the clear in a dry run' {
    $result = Invoke-SprintEndLifecycle @lifecycleParameters -ClearGeneratedArtifacts -WhatIf

    $result.DryRun | Should -BeTrue
    Should -Invoke Clear-SprintGeneratedArtifacts -Times 1 -Exactly -ParameterFilter { $WhatIf }
  }
}

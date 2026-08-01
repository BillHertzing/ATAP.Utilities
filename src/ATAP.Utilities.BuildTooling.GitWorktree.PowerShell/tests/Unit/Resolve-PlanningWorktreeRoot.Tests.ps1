BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  . "$PSScriptRoot\..\..\public\Resolve-PlanningWorktreeRoot.ps1"
}

Describe 'Resolve-PlanningWorktreeRoot' -Tag 'Unit' {
  BeforeEach {
    # A path inside the ATAP.Utilities sprint worktree. Note the issue number (110)
    # differs from the _Planning worktree's issue number (18) - the Sprint token is
    # the cross-repo anchor.
    $script:sprintContext = 'C:\Repos\ATAP.Utilities-wt-110-Sprint-0009-work-items\src\ATAP.Utilities.BuildTooling.PowerShell\public'
    $script:reposParent = 'C:\Repos'
    $script:sprintPlanning = 'C:\Repos\_Planning-wt-18-Sprint-0009-work-items'
    $script:stablePlanning = 'C:\Repos\_Planning'

    Mock Get-ChildItem { @() }
  }

  It 'resolves the sprint _Planning sibling worktree by the Sprint token (not the issue number)' {
    Mock Get-ChildItem {
      [pscustomobject]@{ Name = '_Planning-wt-18-Sprint-0009-work-items'; FullName = $script:sprintPlanning }
    } -ParameterFilter { $Directory }
    Mock Test-Path { $true }

    $res = Resolve-PlanningWorktreeRoot -ContextPath @($script:sprintContext) -ReposParent $script:reposParent

    $res.PlanningRoot | Should -Be $script:sprintPlanning
    $res.Method | Should -Be 'SprintSiblingWorktree'
    $res.IsSprint | Should -BeTrue
    $res.SprintToken | Should -Be 'Sprint-0009-work-items'
  }

  It 'REFUSES to fall back to the stable _Planning worktree when a sprint context is detected but no sprint worktree exists' {
    Mock Get-ChildItem { @() } -ParameterFilter { $Directory }
    Mock Get-ChildItem { @() } -ParameterFilter { $Filter -eq 'OverView*.code-workspace' }
    # Even if a stable inbox exists, the resolver must NOT silently choose it.
    Mock Test-Path { $true }

    { Resolve-PlanningWorktreeRoot -ContextPath @($script:sprintContext) -ReposParent $script:reposParent } |
      Should -Throw '*Refusing to fall back to the stable*'
  }

  It 'resolves a sprint _Planning worktree from a widened OverView*.code-workspace fallback' {
    Mock Get-ChildItem { @() } -ParameterFilter { $Directory }
    Mock Get-ChildItem {
      [pscustomobject]@{ FullName = 'C:\Repos\OverView.code-workspace'; LastWriteTime = Get-Date }
    } -ParameterFilter { $Filter -eq 'OverView*.code-workspace' }
    Mock Get-Content {
      '{ "folders": [ { "path": "C:/Repos/_Planning-wt-18-Sprint-0009-work-items" } ] }'
    } -ParameterFilter { $LiteralPath -eq 'C:\Repos\OverView.code-workspace' }
    Mock Test-Path { $true }
    Mock Resolve-Path { [pscustomobject]@{ Path = $script:sprintPlanning } }

    $res = Resolve-PlanningWorktreeRoot -ContextPath @($script:sprintContext) -ReposParent $script:reposParent

    $res.PlanningRoot | Should -Be $script:sprintPlanning
    $res.Method | Should -Be 'SprintWorkspaceFile'
    $res.IsSprint | Should -BeTrue
  }

  It 'resolves a sprint _Planning worktree from Overview.Sprint.NNNN when called outside any sprint worktree' {
    $outsideSprintContext = 'C:\Tools\scratch'
    Mock Get-ChildItem {
      [pscustomobject]@{ FullName = 'C:\Repos\Overview.Sprint.0009.code-workspace'; LastWriteTime = Get-Date }
    } -ParameterFilter { $Filter -eq 'OverView.Sprint*.code-workspace' }
    Mock Get-Content {
      '{ "folders": [ { "path": "C:/Repos/_Planning-wt-18-Sprint-0009-work-items" } ] }'
    } -ParameterFilter { $LiteralPath -eq 'C:\Repos\Overview.Sprint.0009.code-workspace' }
    Mock Test-Path { $true }
    Mock Resolve-Path { [pscustomobject]@{ Path = $script:sprintPlanning } }

    $res = Resolve-PlanningWorktreeRoot -ContextPath @($outsideSprintContext) -ReposParent $script:reposParent

    $res.PlanningRoot | Should -Be $script:sprintPlanning
    $res.Method | Should -Be 'SprintOverviewWorkspaceFile'
    $res.IsSprint | Should -BeTrue
    $res.SprintToken | Should -Be 'Sprint-0009-work-items'
  }

  It 'falls back to stable _Planning from Overview.code-workspace when no sprint overview exists' {
    $outsideSprintContext = 'C:\Tools\scratch'
    Mock Get-ChildItem { @() } -ParameterFilter { $Filter -eq 'OverView.Sprint*.code-workspace' }
    Mock Get-ChildItem {
      [pscustomobject]@{ FullName = 'C:\Repos\Overview.code-workspace'; LastWriteTime = Get-Date }
    } -ParameterFilter { $Filter -eq 'OverView.code-workspace' }
    Mock Get-Content {
      '{ "folders": [ { "path": "_Planning" } ] }'
    } -ParameterFilter { $LiteralPath -eq 'C:\Repos\Overview.code-workspace' }
    Mock Test-Path { $true }
    Mock Resolve-Path { [pscustomobject]@{ Path = $script:stablePlanning } }

    $res = Resolve-PlanningWorktreeRoot -ContextPath @($outsideSprintContext) -ReposParent $script:reposParent

    $res.PlanningRoot | Should -Be $script:stablePlanning
    $res.Method | Should -Be 'StableWorkspaceFile'
    $res.IsSprint | Should -BeFalse
  }

  It 'does NOT accept a stable-only OverView workspace folder when a sprint context is detected' {
    Mock Get-ChildItem { @() } -ParameterFilter { $Directory }
    Mock Get-ChildItem {
      [pscustomobject]@{ FullName = 'C:\Repos\OverView.code-workspace'; LastWriteTime = Get-Date }
    } -ParameterFilter { $Filter -eq 'OverView*.code-workspace' }
    # Workspace lists only the stable _Planning folder (the real-world bug).
    Mock Get-Content {
      '{ "folders": [ { "path": "_Planning" } ] }'
    } -ParameterFilter { $LiteralPath -eq 'C:\Repos\OverView.code-workspace' }
    Mock Test-Path { $true }

    { Resolve-PlanningWorktreeRoot -ContextPath @($script:sprintContext) -ReposParent $script:reposParent } |
      Should -Throw '*Refusing to fall back to the stable*'
  }

  It 'honors an explicit -PlanningRoot override' {
    Mock Test-Path { $true }
    Mock Resolve-Path { [pscustomobject]@{ Path = $script:sprintPlanning } }

    $res = Resolve-PlanningWorktreeRoot -PlanningRoot $script:sprintPlanning

    $res.PlanningRoot | Should -Be $script:sprintPlanning
    $res.Method | Should -Be 'ExplicitPlanningRoot'
    $res.IsSprint | Should -BeTrue
  }

  It 'throws when an explicit -PlanningRoot has no ScopeCreep-Inbox.md' {
    Mock Test-Path { $false }

    { Resolve-PlanningWorktreeRoot -PlanningRoot 'C:\Repos\NotAPlanningRoot' } |
      Should -Throw '*does not contain*'
  }

  It 'falls back to the stable _Planning worktree only when NO sprint context is present' {
    $stableContext = 'C:\Repos\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public'
    Mock Get-ChildItem { @() } -ParameterFilter { $Filter -eq 'OverView*.code-workspace' }
    Mock Test-Path { $true }

    $res = Resolve-PlanningWorktreeRoot -ContextPath @($stableContext) -ReposParent $script:reposParent

    $res.PlanningRoot | Should -Be $script:stablePlanning
    $res.Method | Should -Be 'StableReposParent'
    $res.IsSprint | Should -BeFalse
  }
}

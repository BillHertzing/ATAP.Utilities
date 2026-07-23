BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  . "$PSScriptRoot\..\..\..\ATAP.Utilities.BuildTooling.GitWorktree.PowerShell\private\Resolve-PlanningWorktreeRoot.ps1"
  . "$PSScriptRoot\..\..\public\Add-ScopeCreepIdea.ps1"
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

Describe 'Add-ScopeCreepIdea' -Tag 'Unit' {
  BeforeEach {
    $script:planningRoot = 'C:\Fake\_Planning-wt-18-Sprint-0009-work-items'
    $script:scopeCreepPath = Join-Path $script:planningRoot 'ScopeCreepManagement'
    $script:inboxPath = Join-Path $script:scopeCreepPath 'ScopeCreep-Inbox.md'
    $script:adoptedPath = Join-Path $script:scopeCreepPath 'ScopeCreep-Adopted.md'
    $script:deferredPath = Join-Path $script:scopeCreepPath 'ScopeCreep-Deferred.md'
    $script:appendedEntries = [System.Collections.Generic.List[string]]::new()

    Mock Resolve-PlanningWorktreeRoot {
      [pscustomobject]@{
        PlanningRoot = $script:planningRoot
        Method       = 'SprintSiblingWorktree'
        IsSprint     = $true
        SprintToken  = 'Sprint-0009-work-items'
      }
    }

    Mock Get-Content {
      switch ($LiteralPath) {
        $script:inboxPath { "## SC-0119`n- **Title**: Inbox duplicate" }
        $script:adoptedPath { "## SC-0120`n- **Title**: Adopted duplicate`n`n## SC-0141`n- **Title**: Adopted latest" }
        $script:deferredPath { "## SC-0146`n- **Title**: Deferred latest" }
        default { throw "Unexpected Get-Content path: $LiteralPath" }
      }
    }

    Mock Test-Path { $true }

    Mock Add-Content {
      $script:appendedEntries.Add($Value) | Out-Null
    } -ParameterFilter { $LiteralPath -eq $script:inboxPath }
  }

  It 'writes the new entry to the sprint _Planning inbox resolved by Resolve-PlanningWorktreeRoot' {
    $result = Add-ScopeCreepIdea `
      -Title 'Capture against sprint worktree' `
      -SuggestedBy 'Self' `
      -Repo 'ATAP.Utilities' `
      -Context 'BuildTooling / planning hygiene' `
      -InitialSize 'S' `
      -Description 'New ideas must land in the sprint _Planning worktree, never stable.' `
      -Tags 'PlanningHygiene' `
      -Confirm:$false

    $result.InboxPath | Should -Be $script:inboxPath
    $result.PlanningRoot | Should -Be $script:planningRoot
    $result.IsSprintTarget | Should -BeTrue
    $result.ResolvedVia | Should -Be 'SprintSiblingWorktree'
    $script:appendedEntries.Count | Should -Be 1
    Assert-MockCalled Resolve-PlanningWorktreeRoot -Times 1
  }

  It 'allocates the next unique SC id across Inbox, Adopted, and Deferred before writing' {
    $result = Add-ScopeCreepIdea `
      -Title 'Normalize checkpoint roster wording' `
      -SuggestedBy 'Self' `
      -Repo 'ATAP.Utilities' `
      -Context 'BuildTooling / planning hygiene' `
      -InitialSize 'S' `
      -Description 'Ensure new IDs do not collide with adopted or deferred items.' `
      -Tags 'PlanningHygiene' `
      -Confirm:$false

    $result.ScopeCreepId | Should -Be 'SC-0147'
    $script:appendedEntries.Count | Should -Be 1
    $script:appendedEntries[0] | Should -Match '## SC-0147'
    Assert-MockCalled Get-Content -Times 1 -ParameterFilter { $LiteralPath -eq $script:inboxPath }
    Assert-MockCalled Get-Content -Times 1 -ParameterFilter { $LiteralPath -eq $script:adoptedPath }
    Assert-MockCalled Get-Content -Times 1 -ParameterFilter { $LiteralPath -eq $script:deferredPath }
  }

  It 'writes an entry without tags when the optional tags prompt is unavailable' {
    Mock Read-Host {
      throw [System.Management.Automation.PSInvalidOperationException]::new('PowerShell is in NonInteractive mode.')
    }

    $result = Add-ScopeCreepIdea `
      -Title 'Non-interactive optional tags' `
      -SuggestedBy 'Self' `
      -Repo 'ATAP.Utilities' `
      -Context 'BuildTooling / scope-creep capture' `
      -InitialSize 'XS' `
      -Description 'The optional tags prompt must not block capture.' `
      -Confirm:$false

    $result.ScopeCreepId | Should -Be 'SC-0147'
    $script:appendedEntries.Count | Should -Be 1
    $script:appendedEntries[0] | Should -Not -Match '(?m)^- \*\*Tags\*\*:'
    Assert-MockCalled Read-Host -Times 1
  }

  It 'propagates the resolver refusal and never writes when only a stable worktree is available' {
    Mock Resolve-PlanningWorktreeRoot {
      throw 'Resolve-PlanningWorktreeRoot: Refusing to fall back to the stable _Planning (main) worktree for sprint work.'
    }

    { Add-ScopeCreepIdea `
        -Title 'Should not be written' `
        -SuggestedBy 'Self' `
        -Repo 'ATAP.Utilities' `
        -Context 'BuildTooling' `
        -InitialSize 'S' `
        -Description 'This must fail rather than write to stable.' `
        -Confirm:$false } | Should -Throw '*Refusing to fall back to the stable*'

    $script:appendedEntries.Count | Should -Be 0
    Assert-MockCalled Add-Content -Times 0
  }
}

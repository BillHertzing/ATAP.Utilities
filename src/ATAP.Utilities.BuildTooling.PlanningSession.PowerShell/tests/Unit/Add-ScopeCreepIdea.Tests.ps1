BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  . "$PSScriptRoot\..\..\..\ATAP.Utilities.BuildTooling.GitWorktree.PowerShell\public\Resolve-PlanningWorktreeRoot.ps1"
  . "$PSScriptRoot\..\..\public\Add-ScopeCreepIdea.ps1"
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

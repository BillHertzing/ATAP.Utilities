BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  . "$PSScriptRoot\..\..\public\Add-ScopeCreepIdea.ps1"
}

Describe 'Add-ScopeCreepIdea' -Tag 'Unit' {
  BeforeEach {
    $script:planningRoot = 'C:\Fake\_Planning-wt-16-Sprint-0008-work-items'
    $script:workspacePath = 'C:\Fake\OverviewSprint0008.code-workspace'
    $script:scopeCreepPath = Join-Path $script:planningRoot 'ScopeCreepManagement'
    $script:inboxPath = Join-Path $script:scopeCreepPath 'ScopeCreep-Inbox.md'
    $script:adoptedPath = Join-Path $script:scopeCreepPath 'ScopeCreep-Adopted.md'
    $script:deferredPath = Join-Path $script:scopeCreepPath 'ScopeCreep-Deferred.md'
    $script:appendedEntries = [System.Collections.Generic.List[string]]::new()

    Mock Get-ChildItem {
      [pscustomobject]@{
        FullName = $script:workspacePath
        LastWriteTime = Get-Date
      }
    } -ParameterFilter { $Filter -eq 'OverviewSprint*.code-workspace' }

    Mock Get-Content {
      switch ($LiteralPath) {
        $script:workspacePath { '{"folders":[{"path":"C:/Fake/_Planning-wt-16-Sprint-0008-work-items"}]}' }
        $script:inboxPath { "## SC-0119`n- **Title**: Inbox duplicate" }
        $script:adoptedPath { "## SC-0120`n- **Title**: Adopted duplicate`n`n## SC-0141`n- **Title**: Adopted latest" }
        $script:deferredPath { "## SC-0146`n- **Title**: Deferred latest" }
        default { throw "Unexpected Get-Content path: $LiteralPath" }
      }
    }

    Mock Test-Path {
      $true
    }

    Mock Resolve-Path {
      [pscustomobject]@{ Path = $script:planningRoot }
    } -ParameterFilter { $LiteralPath -eq $script:planningRoot }

    Mock Add-Content {
      $script:appendedEntries.Add($Value) | Out-Null
    } -ParameterFilter { $LiteralPath -eq $script:inboxPath }
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
}

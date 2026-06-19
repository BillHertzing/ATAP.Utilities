BeforeAll {
  # Import the module from THIS worktree (tests/Unit -> module root) so the test
  # exercises the worktree's source rather than a stable-repo copy on PSModulePath.
  $script:manifestPath = Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.PowerShell.psd1'
  Import-Module $script:manifestPath -Force
}

Describe 'Set-SprintBoundaryContext [public]' {
  BeforeAll {
    $script:gitRoot = Join-Path ([System.IO.Path]::GetTempPath()) "sbc_test_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:gitRoot -Force | Out-Null

    # Stable repo + sprint worktree + a workspace file inside the worktree.
    $script:repoName  = 'ATAP.Utilities'
    $script:stableRepo = Join-Path $script:gitRoot $script:repoName
    New-Item -ItemType Directory -Path $script:stableRepo -Force | Out-Null

    $script:worktree = Join-Path $script:gitRoot "$($script:repoName)-wt-100-Sprint-0007-work-items"
    New-Item -ItemType Directory -Path $script:worktree -Force | Out-Null
    $script:wsFile = Join-Path $script:worktree 'Test.code-workspace'
    @{ folders = @(@{ path = '.' }) } | ConvertTo-Json | Set-Content -Path $script:wsFile -Encoding UTF8

    $script:svSprint = Join-Path $script:gitRoot 'SharedVSCode-wt-42-Sprint-0007-work-items'
    New-Item -ItemType Directory -Path $script:svSprint -Force | Out-Null
    $script:svStable = Join-Path $script:gitRoot 'SharedVSCode'
    New-Item -ItemType Directory -Path $script:svStable -Force | Out-Null
  }

  AfterAll {
    Remove-Item -Path $script:gitRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  BeforeEach {
    Mock -ModuleName ATAP.Utilities.BuildTooling.PowerShell Set-WorktreeJunctions { [PSCustomObject]@{ Success = $true; Errors = @() } }
    Mock -ModuleName ATAP.Utilities.BuildTooling.PowerShell Initialize-DownstreamSprintFromSharedVSCode { }
    Mock -ModuleName ATAP.Utilities.BuildTooling.PowerShell Reset-DownstreamToSharedVSCodeMain { }
    Mock -ModuleName ATAP.Utilities.BuildTooling.PowerShell Set-UserSettingsSymlink { }
    Mock -ModuleName ATAP.Utilities.BuildTooling.PowerShell Set-ClaudeSettingsSymlink { }
    Mock -ModuleName ATAP.Utilities.BuildTooling.PowerShell Invoke-SprintAISettingsLifecycle {
      [PSCustomObject]@{ DriftClean = $true; Results = @(); ChangedCount = 0 }
    }
  }

  Context 'Parameter validation' {
    It 'Rejects an invalid Boundary value' {
      { Set-SprintBoundaryContext -Boundary 'Sideways' -SharedVSCodeWorktreePath $script:svSprint } |
        Should -Throw
    }

    It 'Requires a non-empty SharedVSCodeWorktreePath' {
      { Set-SprintBoundaryContext -Boundary 'Start' -SharedVSCodeWorktreePath '' } | Should -Throw
    }
  }

  Context 'Start boundary' {
    It 'Retargets junctions with a dev-redirect to the SharedVSCode sprint worktree' {
      Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Set-WorktreeJunctions -Times 1 -Exactly -Scope It `
        -ParameterFilter { $DevSourceRepoPath -eq $script:svSprint }
    }

    It 'Applies downstream context via Initialize-DownstreamSprintFromSharedVSCode' {
      Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Initialize-DownstreamSprintFromSharedVSCode -Times 1 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Reset-DownstreamToSharedVSCodeMain -Times 0 -Exactly -Scope It
    }

    It 'Retargets both settings symlinks to the sprint worktree' {
      Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Set-UserSettingsSymlink -Times 1 -Exactly -Scope It `
        -ParameterFilter { $SharedVSCodeWorktreePath -eq $script:svSprint }
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Set-ClaudeSettingsSymlink -Times 1 -Exactly -Scope It `
        -ParameterFilter { $SharedVSCodeWorktreePath -eq $script:svSprint }
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Invoke-SprintAISettingsLifecycle -Times 1 -Exactly -Scope It `
        -ParameterFilter { $Boundary -eq 'Start' -and $TargetRoot -eq $script:worktree }
    }
  }

  Context 'End boundary' {
    It 'Retargets junctions without a dev-redirect (back to stable)' {
      Set-SprintBoundaryContext -Boundary End `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Set-WorktreeJunctions -Times 1 -Exactly -Scope It `
        -ParameterFilter { [string]::IsNullOrEmpty($DevSourceRepoPath) }
    }

    It 'Resets downstream context via Reset-DownstreamToSharedVSCodeMain' {
      Set-SprintBoundaryContext -Boundary End `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svStable `
        -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Reset-DownstreamToSharedVSCodeMain -Times 1 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Initialize-DownstreamSprintFromSharedVSCode -Times 0 -Exactly -Scope It
    }
  }

  Context 'Return contract' {
    It 'Covers the boundary concerns and marks profiles/ConfigRootKeys stable-by-design' {
      $result = Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot

      $names = $result.Concerns.Concern
      $names | Should -Contain 'MachineLinks'
      $names | Should -Contain 'SharedVSCodeSettings'
      $names | Should -Contain 'DownstreamContexts'
      $names | Should -Contain 'AISettingsLifecycle'
      $names | Should -Contain 'PowerShellProfiles'
      $names | Should -Contain 'ConfigRootKeys'

      ($result.Concerns | Where-Object Concern -EQ 'PowerShellProfiles').StableByDesign | Should -BeTrue
      ($result.Concerns | Where-Object Concern -EQ 'ConfigRootKeys').StableByDesign | Should -BeTrue
    }

    It 'Reports a per-worktree breakdown with the derived stable repo path' {
      $result = Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot

      $result.PerWorktree | Should -HaveCount 1
      $result.PerWorktree[0].StableRepoPath | Should -Be $script:stableRepo
      $result.PerWorktree[0].JunctionsRetargeted | Should -BeTrue
      $result.PerWorktree[0].ContextRetargeted | Should -BeTrue
      $result.PerWorktree[0].AISettingsProcessed | Should -BeTrue
      $result.PerWorktree[0].AISettingsDriftClean | Should -BeTrue
    }

    It 'Records a missing worktree as an error and continues' {
      $missing = Join-Path $script:gitRoot 'Nope-wt-1-Sprint-0007-work-items'
      $result = Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($missing) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot

      $result.Errors.Count | Should -BeGreaterThan 0
      $result.PerWorktree[0].Error | Should -Match 'not found'
    }
  }

  Context 'Settings-only invocation' {
    It 'Retargets settings symlinks with no worktrees supplied' {
      Set-SprintBoundaryContext -Boundary End -SharedVSCodeWorktreePath $script:svStable -GitRoot $script:gitRoot

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Set-UserSettingsSymlink -Times 1 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Set-WorktreeJunctions -Times 0 -Exactly -Scope It
    }
  }

  Context 'WhatIf' {
    It 'Performs no mutation under -WhatIf' {
      Set-SprintBoundaryContext -Boundary Start `
        -WorktreePaths @($script:worktree) `
        -SharedVSCodeWorktreePath $script:svSprint `
        -GitRoot $script:gitRoot `
        -WhatIf

      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Set-WorktreeJunctions -Times 0 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Initialize-DownstreamSprintFromSharedVSCode -Times 0 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Set-UserSettingsSymlink -Times 0 -Exactly -Scope It
      Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Invoke-SprintAISettingsLifecycle -Times 0 -Exactly -Scope It
    }
  }
}

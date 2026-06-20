BeforeAll {
  $script:manifestPath = Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.PowerShell.psd1'
  Import-Module $script:manifestPath -Force
}

Describe 'Invoke-SprintAISettingsLifecycle compatibility wrapper' {
  BeforeEach {
    Mock -ModuleName ATAP.Utilities.BuildTooling.PowerShell Invoke-SprintAIAdapterLifecycle {
      [pscustomobject]@{
        Boundary = $Boundary
        TargetRoot = $TargetRoot
        SharedVSCodeWorktreePath = $SharedVSCodeWorktreePath
        FixtureMode = [bool]$FixtureMode
        CheckpointConfirmed = [bool]$CheckpointConfirmed
        DriftClean = $true
      }
    }
  }

  It 'forwards to the adapter lifecycle with compatibility parameters intact' {
    $target = Join-Path $TestDrive 'target'
    $source = Join-Path $TestDrive 'SharedVSCode'
    $result = Invoke-SprintAISettingsLifecycle `
      -Boundary Start `
      -TargetRoot $target `
      -SharedVSCodeWorktreePath $source `
      -FixtureMode `
      -Confirm:$false

    $result.Boundary | Should -Be 'Start'
    $result.FixtureMode | Should -BeTrue
    Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell `
      Invoke-SprintAIAdapterLifecycle -Times 1 -Exactly -Scope It
  }

  It 'performs no forwarding call under WhatIf' {
    $result = Invoke-SprintAISettingsLifecycle `
      -Boundary Start `
      -TargetRoot (Join-Path $TestDrive 'whatif-target') `
      -SharedVSCodeWorktreePath (Join-Path $TestDrive 'SharedVSCode') `
      -WhatIf

    $result | Should -BeNullOrEmpty
    Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell `
      Invoke-SprintAIAdapterLifecycle -Times 0 -Exactly -Scope It
  }
}

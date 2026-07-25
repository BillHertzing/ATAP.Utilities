BeforeAll {
  $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:manifestPath = Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell.psd1'
  $script:manifest = Import-PowerShellDataFile -LiteralPath $script:manifestPath
}

Describe 'SprintLifecycle module dependency contract' -Tag 'Unit' {
  It 'declares every frozen direct child dependency at its deployed minimum version' {
    $expectedDependencies = [ordered]@{
      'ATAP.Utilities.BuildTooling.AiRendering.PowerShell'       = [version]'0.1.0'
      'ATAP.Utilities.BuildTooling.BuildMaster.PowerShell'       = [version]'0.1.0'
      'ATAP.Utilities.BuildTooling.Common.PowerShell'            = [version]'0.1.7'
      'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell' = [version]'0.1.0'
      'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell'       = [version]'0.1.3'
      'ATAP.Utilities.BuildTooling.ProGet.PowerShell'            = [version]'0.1.1'
      'ATAP.Utilities.BuildTooling.Secrets.PowerShell'           = [version]'0.1.0'
    }

    $actualDependencies = @{}
    foreach ($dependency in $script:manifest.RequiredModules) {
      $actualDependencies[$dependency.ModuleName] = [version]$dependency.ModuleVersion
    }

    $actualDependencies.Count | Should -Be $expectedDependencies.Count
    foreach ($entry in $expectedDependencies.GetEnumerator()) {
      $actualDependencies.ContainsKey($entry.Key) | Should -BeTrue
      $actualDependencies[$entry.Key] | Should -Be $entry.Value
    }
  }

  It 'packages the GitWorktree private bridges required by sprint start' {
    Test-Path -LiteralPath (Join-Path $script:moduleRoot 'private\Confirm-WorktreeGitPointerOwnership.ps1') |
      Should -BeTrue
    Test-Path -LiteralPath (Join-Path $script:moduleRoot 'private\Get-GitHubOwnerFromWorkspace.ps1') |
      Should -BeTrue
  }

  It 'defines an explicit empty VariablesToExport contract' {
    $script:manifest.ContainsKey('VariablesToExport') | Should -BeTrue
    @($script:manifest.VariablesToExport).Count | Should -Be 0
  }
}

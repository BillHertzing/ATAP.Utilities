#Requires -Version 7.0

Describe 'GitWorktree child scaffold contract' -Tag 'Unit' {
  BeforeAll {
    $script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:ManifestPath = Join-Path $script:ModuleRoot 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell.psd1'
    $script:Manifest = Import-PowerShellDataFile -LiteralPath $script:ManifestPath
    $script:Family = Import-PowerShellDataFile -LiteralPath (Join-Path (Split-Path -Parent (Split-Path -Parent $script:ModuleRoot)) 'ModuleFamily.psd1')
    $script:ExpectedExports = @(
      'Assert-MainBranchTemplateRef', 'Confirm-GitFSCK', 'Convert-StableWorktreeToConcreteAdapters',
      'Get-BrokenGitSubDirs', 'Get-LocalPowerShellModulePollerGitScalar', 'Invoke-GitCommit',
      'Invoke-GitPostCheckoutHook', 'Invoke-GitPostCommitHook', 'Invoke-GitPreCommitHook',
      'Invoke-LocalPowerShellModulePollerGit', 'New-GitHubIssue', 'New-WorktreeWithJunctions',
      'Set-WorktreeJunctions'
    )
  }

  It 'uses the approved identity and PowerShell policy' {
    $script:Manifest.GUID.ToString() | Should -Be '1e070ad5-6431-4c3e-b7e6-bc69b9cd5af3'
    $script:Manifest.PowerShellVersion.ToString() | Should -Be '7.0'
    @($script:Manifest.CompatiblePSEditions) | Should -Be @('Core')
  }

  It 'declares exactly the thirteen approved public exports' {
    @($script:Manifest.FunctionsToExport | Sort-Object) | Should -Be @($script:ExpectedExports | Sort-Object)
    @($script:Manifest.CmdletsToExport).Count | Should -Be 0
    @($script:Manifest.VariablesToExport).Count | Should -Be 0
    @($script:Manifest.AliasesToExport).Count | Should -Be 0
  }

  It 'pins Common 0.1.5 consistently in the manifest and family metadata' {
    $requirement = @($script:Manifest.RequiredModules | Where-Object ModuleName -eq 'ATAP.Utilities.BuildTooling.Common.PowerShell')
    $requirement.Count | Should -Be 1
    $requirement[0].ModuleVersion.ToString() | Should -Be '0.1.5'

    $member = @($script:Family.Members | Where-Object Name -eq 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell')
    $member.Count | Should -Be 1
    $member[0].MinimumVersions['ATAP.Utilities.BuildTooling.Common.PowerShell'] | Should -Be '0.1.5'
  }

  It 'has stable-release NBGV metadata' {
    $metadata = Get-Content -LiteralPath (Join-Path $script:ModuleRoot 'version.json') -Raw | ConvertFrom-Json
    $metadata.version | Should -Be '0.1.0'
    @($metadata.publicReleaseRefSpec) | Should -Contain '.*'
  }
}

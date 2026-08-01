BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $manifestPath = Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.Common.PowerShell.psd1'
  $promotedManifest = [System.Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
  Remove-Module -Name 'ATAP.Utilities.BuildTooling.Common.PowerShell' -Force -ErrorAction SilentlyContinue
  Import-Module -Name $(if ([string]::IsNullOrWhiteSpace($promotedManifest)) { $manifestPath } else { $promotedManifest }) -Force -ErrorAction Stop
}

Describe 'Get-RepositoryRoot' -Tag 'Unit' {
  It "returns Git's absolute root for the current worktree" {
    $expected = (git -C $PWD rev-parse --show-toplevel).Trim().Replace('\', '/')
    $actual = (Get-RepositoryRoot -StartPath $PWD -Absolute).Replace('\', '/')

    $actual | Should -Be $expected
  }

  It 'returns a non-empty relative path by default' {
    $actual = Get-RepositoryRoot -StartPath $PWD

    $actual | Should -Not -BeNullOrEmpty
    $actual | Should -Not -Match '^[A-Za-z]:[\\/]'
  }

  It 'throws for a nonexistent start path' {
    { Get-RepositoryRoot -StartPath (Join-Path $TestDrive 'missing') } | Should -Throw '*Start path does not exist*'
  }
}

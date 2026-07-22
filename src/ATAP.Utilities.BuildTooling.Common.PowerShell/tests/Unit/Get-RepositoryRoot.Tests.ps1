BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $manifestPath = Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.Common.PowerShell.psd1'
  # Preserve the already-imported promoted package when this suite runs in a
  # promotion gate. Standalone source runs import the source manifest instead.
  if ($null -eq (Get-Module -Name 'ATAP.Utilities.BuildTooling.Common.PowerShell')) {
    Import-Module -Name $manifestPath -Force -ErrorAction Stop
  }
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

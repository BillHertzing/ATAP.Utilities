BeforeAll {
  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  Import-Module (Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell.psd1') -Force
}

Describe 'GitWorktree Batch 2 public contracts' {
  It 'returns an empty result when no child directories contain Git metadata' {
    Push-Location $TestDrive
    try {
      New-Item -ItemType Directory -Path (Join-Path $TestDrive 'plain-directory') -Force | Out-Null
      $result = Get-BrokenGitSubDirs
      $result | Should -BeOfType [hashtable]
      $result.Count | Should -Be 0
    } finally {
      Pop-Location
    }
  }

  It 'exports both frozen Git lifecycle hook commands' {
    foreach ($name in @('Invoke-GitPostCheckoutHook', 'Invoke-GitPostCommitHook')) {
      $command = Get-Command $name -Module ATAP.Utilities.BuildTooling.GitWorktree.PowerShell
      $command.CommandType | Should -Be 'Function'
    }
  }

  It 'keeps every Batch 2 implementation file function-only at module import' {
    $files = @(
      'Convert-StableWorktreeToConcreteAdapters.ps1',
      'Get-BrokenGitSubDirs.ps1',
      'Invoke-GitCommit.ps1',
      'Invoke-GitPostCheckoutHook.ps1',
      'Invoke-GitPostCommitHook.ps1'
    )

    foreach ($name in $files) {
      $path = Join-Path $moduleRoot "public\$name"
      $tokens = $null
      $errors = $null
      $ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
      $errors.Count | Should -Be 0
      @($ast.EndBlock.Statements | Where-Object { $_ -isnot [Management.Automation.Language.FunctionDefinitionAst] }).Count | Should -Be 0
    }
  }
}

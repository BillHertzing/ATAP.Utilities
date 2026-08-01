BeforeAll {
  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  Import-Module (Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell.psd1') -Force
}

Describe 'GitWorktree Batch 3 public contracts' {
  It 'exports the seven commands implemented by the five frozen files' {
    $expected = @(
      'Get-LocalPowerShellModulePollerGitScalar',
      'Invoke-GitPreCommitHook',
      'Invoke-LocalPowerShellModulePollerGit',
      'New-GitHubIssue',
      'New-WorktreeWithJunctions',
      'Set-WorktreeJunctions',
      'Start-LocalPowerShellModuleBuildMasterPoller'
    )

    foreach ($name in $expected) {
      Get-Command $name -Module ATAP.Utilities.BuildTooling.GitWorktree.PowerShell |
        Should -Not -BeNullOrEmpty
    }
  }

  It 'runs both exported poller Git helpers against a local repository' {
    $repo = Join-Path $TestDrive 'poller-repo'
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    git -C $repo init --quiet

    Invoke-LocalPowerShellModulePollerGit -RepoRoot $repo -Arguments @('rev-parse', '--is-inside-work-tree') |
      Should -Be @('true')
    Get-LocalPowerShellModulePollerGitScalar -RepoRoot $repo -Arguments @('rev-parse', '--is-inside-work-tree') |
      Should -Be 'true'
  }

  It 'previews issue creation without invoking the GitHub CLI' {
    $childModule = Get-Module ATAP.Utilities.BuildTooling.GitWorktree.PowerShell
    & $childModule {
      function script:Get-PVal {
        param($ParameterName, $originalPSBoundParameters, $dottedPath, $DefaultValue)
        $DefaultValue
      }
    }

    { New-GitHubIssue -RepoName 'owner/repo' -Title 'test title' -Body 'test body' -WhatIf } |
      Should -Not -Throw
  }

  It 'keeps every Batch 3 implementation file function-only at module import' {
    $files = @(
      'Invoke-GitPreCommitHook.ps1',
      'New-GitHubIssue.ps1',
      'New-WorktreeWithJunctions.ps1',
      'Set-WorktreeJunctions.ps1',
      'Start-LocalPowerShellModuleBuildMasterPoller.ps1'
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

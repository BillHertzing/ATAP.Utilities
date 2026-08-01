BeforeAll {
  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  $manifestPath = Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell.psd1'
  $promotedManifest = [System.Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
  $moduleToTest = if ([string]::IsNullOrWhiteSpace($promotedManifest)) { $manifestPath } else { $promotedManifest }
  Remove-Module -Name 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell' -Force -ErrorAction SilentlyContinue
  Import-Module -Name $moduleToTest -Force -ErrorAction Stop
}

Describe 'Get-GitHubOwnerFromWorkspace' -Tag 'Unit' {
  BeforeEach {
    $script:tempGitRoot = Join-Path ([System.IO.Path]::GetTempPath()) "owner_ws_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempGitRoot -Force | Out-Null
    $script:workspaceFile = Join-Path $script:tempGitRoot 'OverView.code-workspace'
  }

  AfterEach {
    Remove-Item -LiteralPath $script:tempGitRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'returns the githubOwner read from OverView.code-workspace (Task 10.2 acceptance)' {
    Set-Content -LiteralPath $script:workspaceFile -Encoding UTF8 -Value (@{
        folders     = @(@{ path = 'SharedVSCode' })
        githubOwner = 'BillHertzing'
      } | ConvertTo-Json -Depth 4)

    InModuleScope ATAP.Utilities.BuildTooling.GitWorktree.PowerShell -Parameters @{ GitRoot = $script:tempGitRoot } {
      Get-GitHubOwnerFromWorkspace -GitRoot $GitRoot -Fallback 'whertzing'
    } | Should -Be 'BillHertzing'
  }

  It 'trims surrounding whitespace from githubOwner' {
    Set-Content -LiteralPath $script:workspaceFile -Encoding UTF8 -Value (@{
        githubOwner = '  BillHertzing  '
      } | ConvertTo-Json -Depth 4)

    InModuleScope ATAP.Utilities.BuildTooling.GitWorktree.PowerShell -Parameters @{ GitRoot = $script:tempGitRoot } {
      Get-GitHubOwnerFromWorkspace -GitRoot $GitRoot -Fallback 'whertzing'
    } | Should -Be 'BillHertzing'
  }

  It 'returns the fallback when OverView.code-workspace is missing' {
    InModuleScope ATAP.Utilities.BuildTooling.GitWorktree.PowerShell -Parameters @{ GitRoot = $script:tempGitRoot } {
      Get-GitHubOwnerFromWorkspace -GitRoot $GitRoot -Fallback 'whertzing'
    } | Should -Be 'whertzing'
  }

  It 'returns the fallback when githubOwner key is absent' {
    Set-Content -LiteralPath $script:workspaceFile -Encoding UTF8 -Value (@{
        folders = @(@{ path = 'SharedVSCode' })
      } | ConvertTo-Json -Depth 4)

    InModuleScope ATAP.Utilities.BuildTooling.GitWorktree.PowerShell -Parameters @{ GitRoot = $script:tempGitRoot } {
      Get-GitHubOwnerFromWorkspace -GitRoot $GitRoot -Fallback 'whertzing'
    } | Should -Be 'whertzing'
  }

  It 'returns the fallback when githubOwner is empty/whitespace' {
    Set-Content -LiteralPath $script:workspaceFile -Encoding UTF8 -Value (@{
        githubOwner = '   '
      } | ConvertTo-Json -Depth 4)

    InModuleScope ATAP.Utilities.BuildTooling.GitWorktree.PowerShell -Parameters @{ GitRoot = $script:tempGitRoot } {
      Get-GitHubOwnerFromWorkspace -GitRoot $GitRoot -Fallback 'whertzing'
    } | Should -Be 'whertzing'
  }

  It 'returns the fallback when the workspace file is not valid JSON' {
    Set-Content -LiteralPath $script:workspaceFile -Encoding UTF8 -Value 'not-json{'

    InModuleScope ATAP.Utilities.BuildTooling.GitWorktree.PowerShell -Parameters @{ GitRoot = $script:tempGitRoot } {
      Get-GitHubOwnerFromWorkspace -GitRoot $GitRoot -Fallback 'whertzing'
    } | Should -Be 'whertzing'
  }
}

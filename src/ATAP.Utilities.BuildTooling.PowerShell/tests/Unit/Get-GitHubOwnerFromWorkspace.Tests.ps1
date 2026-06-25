BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  # Dot-source the private helpers under test. Get-GitHubOwnerFromWorkspace
  # delegates the JSON read to Get-WorkspaceJson, so both must be loaded.
  . "$PSScriptRoot\..\..\private\Get-WorkspaceJson.ps1"
  . "$PSScriptRoot\..\..\private\Get-GitHubOwnerFromWorkspace.ps1"
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

    Get-GitHubOwnerFromWorkspace -GitRoot $script:tempGitRoot -Fallback 'whertzing' |
      Should -Be 'BillHertzing'
  }

  It 'trims surrounding whitespace from githubOwner' {
    Set-Content -LiteralPath $script:workspaceFile -Encoding UTF8 -Value (@{
        githubOwner = '  BillHertzing  '
      } | ConvertTo-Json -Depth 4)

    Get-GitHubOwnerFromWorkspace -GitRoot $script:tempGitRoot -Fallback 'whertzing' |
      Should -Be 'BillHertzing'
  }

  It 'returns the fallback when OverView.code-workspace is missing' {
    Get-GitHubOwnerFromWorkspace -GitRoot $script:tempGitRoot -Fallback 'whertzing' |
      Should -Be 'whertzing'
  }

  It 'returns the fallback when githubOwner key is absent' {
    Set-Content -LiteralPath $script:workspaceFile -Encoding UTF8 -Value (@{
        folders = @(@{ path = 'SharedVSCode' })
      } | ConvertTo-Json -Depth 4)

    Get-GitHubOwnerFromWorkspace -GitRoot $script:tempGitRoot -Fallback 'whertzing' |
      Should -Be 'whertzing'
  }

  It 'returns the fallback when githubOwner is empty/whitespace' {
    Set-Content -LiteralPath $script:workspaceFile -Encoding UTF8 -Value (@{
        githubOwner = '   '
      } | ConvertTo-Json -Depth 4)

    Get-GitHubOwnerFromWorkspace -GitRoot $script:tempGitRoot -Fallback 'whertzing' |
      Should -Be 'whertzing'
  }

  It 'returns the fallback when the workspace file is not valid JSON' {
    Set-Content -LiteralPath $script:workspaceFile -Encoding UTF8 -Value 'not-json{'

    Get-GitHubOwnerFromWorkspace -GitRoot $script:tempGitRoot -Fallback 'whertzing' |
      Should -Be 'whertzing'
  }
}

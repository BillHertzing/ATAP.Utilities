BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  # Stage 1 enforces an autoload-or-throw contract for these commands; stub them so
  # the dry run reaches the owner-resolution path. They are ShouldProcess-guarded
  # and must not run under DryRun, so the bodies throw as canaries.
  $script:stubbedNames = @(
    'Assert-GitAvailable'
    'gh'
    'git'
    'Set-WorktreeJunctions'
    'Initialize-DownstreamSprintFromSharedVSCode'
    'Initialize-SprintAIAdapters'
    'Get-SprintHistoryReconstruction'
  )
  foreach ($name in $script:stubbedNames) {
    Set-Item -Path "Function:\global:$name" -Value ([scriptblock]::Create("throw '$name should not be called during DryRun.'"))
  }

  # Dot-source the private helpers (owner resolution) and the Stage 1 function.
  . "$PSScriptRoot\..\..\private\Get-WorkspaceJson.ps1"
  . "$PSScriptRoot\..\..\private\Get-GitHubOwnerFromWorkspace.ps1"
  . "$PSScriptRoot\..\..\public\New-SprintStage1.ps1"
}

AfterAll {
  foreach ($name in $script:stubbedNames) {
    Remove-Item -Path "Function:\$name" -Force -ErrorAction SilentlyContinue
  }
}

Describe 'New-SprintStage1 owner resolution (Task 10.2)' -Tag 'Unit' {
  BeforeEach {
    $script:tempGitRoot = Join-Path ([System.IO.Path]::GetTempPath()) "stage1_owner_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempGitRoot -Force | Out-Null
  }

  AfterEach {
    Remove-Item -LiteralPath $script:tempGitRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'resolves the owner from OverView.code-workspace githubOwner when -Owner is not passed' {
    Set-Content -LiteralPath (Join-Path $script:tempGitRoot 'OverView.code-workspace') -Encoding UTF8 -Value (@{
        githubOwner = 'BillHertzing'
      } | ConvertTo-Json -Depth 4)

    $result = New-SprintStage1 -GitRoot $script:tempGitRoot -SprintNumber '0010' -DryRun

    $result.owner | Should -Be 'BillHertzing'
  }

  It 'lets an explicit -Owner override the OverView.code-workspace default' {
    Set-Content -LiteralPath (Join-Path $script:tempGitRoot 'OverView.code-workspace') -Encoding UTF8 -Value (@{
        githubOwner = 'BillHertzing'
      } | ConvertTo-Json -Depth 4)

    $result = New-SprintStage1 -GitRoot $script:tempGitRoot -Owner 'explicitOwner' -SprintNumber '0010' -DryRun

    $result.owner | Should -Be 'explicitOwner'
  }

  It 'falls back to the local account name when OverView.code-workspace is absent' {
    $result = New-SprintStage1 -GitRoot $script:tempGitRoot -SprintNumber '0010' -DryRun

    $result.owner | Should -Be $env:USERNAME
  }
}

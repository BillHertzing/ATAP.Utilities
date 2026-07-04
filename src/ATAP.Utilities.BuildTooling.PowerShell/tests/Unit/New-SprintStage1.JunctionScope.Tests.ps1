#Requires -Version 7.0

# SC-0236 regression: Set-WorktreeJunctions' junction SOURCE SCAN must be filtered
# by -SourceRepoFolderNames at Start, not just the dev-redirect via
# -DevSourceRepoFolderNames. Without it, any junction physically present in the
# stable _Planning repo (e.g. a stale .claude/.github junction) would be recreated
# unfiltered in the new sprint worktree. See
# _generated/Task-12.2-investigation-findings.md.
BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  function global:Assert-GitAvailable {}
  function global:gh {
    $global:LASTEXITCODE = 0
    'https://github.com/owner/repo/issues/999'
  }
  function global:git {
    $global:LASTEXITCODE = 0
    ''
  }
  function global:Set-WorktreeJunctions {
    param(
      [string]$SourceRepoPath,
      [string]$WorktreePath,
      [string]$DevSourceRepoPath,
      [string[]]$DevSourceRepoFolderNames,
      [string[]]$SourceRepoFolderNames
    )
    $global:stage1JunctionCalls.Add([PSCustomObject]@{
        SourceRepoFolderNames = $SourceRepoFolderNames
      }) | Out-Null
    [PSCustomObject]@{
      Success          = $true
      JunctionsCreated = 3
      Errors           = @()
    }
  }
  function global:Initialize-DownstreamSprintFromSharedVSCode {}
  function global:Initialize-SprintAIAdapters {}
  function global:Get-SprintHistoryReconstruction {
    param([string]$PlanningRoot)
    [PSCustomObject]@{
      LastCompletedSprintNumber = 9
      Warnings                  = @()
    }
  }

  . "$PSScriptRoot\..\..\public\Convert-TasksMdToSprintBoard.ps1"
  . "$PSScriptRoot\..\..\public\New-SprintStage1.ps1"
}

AfterAll {
  @(
    'Assert-GitAvailable'
    'gh'
    'git'
    'Set-WorktreeJunctions'
    'Initialize-DownstreamSprintFromSharedVSCode'
    'Initialize-SprintAIAdapters'
    'Get-SprintHistoryReconstruction'
  ) | ForEach-Object {
    Remove-Item -Path "Function:\$_" -Force -ErrorAction SilentlyContinue
  }
}

Describe 'New-SprintStage1 junction scan scope (SC-0236)' -Tag 'Unit', 'PromotedModuleHostSensitive' {
  BeforeEach {
    $global:stage1JunctionCalls = [System.Collections.Generic.List[object]]::new()

    $script:tempGitRoot = Join-Path ([System.IO.Path]::GetTempPath()) "stage1_junctionscope_$([guid]::NewGuid().ToString('N'))"
    $script:sharedWorktree = Join-Path $script:tempGitRoot 'SharedVSCode-wt-999-Sprint-0010-work-items'
    $script:planningWorktree = Join-Path $script:tempGitRoot '_Planning-wt-999-Sprint-0010-work-items'

    New-Item -ItemType Directory -Path $script:sharedWorktree -Force | Out-Null
    New-Item -ItemType Directory -Path $script:planningWorktree -Force | Out-Null

    Set-Content -LiteralPath (Join-Path $script:sharedWorktree 'NuGet.config.template') -Encoding UTF8 -Value @(
      '<?xml version="1.0" encoding="utf-8"?>'
      '<configuration><packageSources><add key="test" value="${ProGetBaseUrl}/nuget/test/v3/index.json" /></packageSources></configuration>'
    )

    Set-Content -LiteralPath (Join-Path $script:planningWorktree 'Tasks.Sprint0009.md') -Encoding UTF8 -Value @(
      '# Current Sprint: Sprint 9 - Prior sprint title'
      ''
      'Source: prior sprint'
      'Last updated: 2026-06-16'
      ''
      '## Goal'
      ''
      'PRIOR-GOAL-SENTINEL'
      ''
      '## Stream M - Prior modules'
      ''
      '- [ ] **Task 9.1** [ATAP.Utilities] - PRIOR-TASK-SENTINEL'
    )
    Set-Content -LiteralPath (Join-Path $script:planningWorktree 'Tasks.Sprint0009.html') -Encoding UTF8 -Value '<html>prior board</html>'
    Set-Content -LiteralPath (Join-Path $script:planningWorktree 'Tasks.Sprint0009.Accomplished.html') -Encoding UTF8 -Value '<html>prior accomplishments</html>'
    Set-Content -LiteralPath (Join-Path $script:planningWorktree 'Tasks.Sprint0009.ProceduralDetails.html') -Encoding UTF8 -Value '<html>prior procedures</html>'
  }

  AfterEach {
    Remove-Item -LiteralPath $script:tempGitRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name stage1JunctionCalls -Scope Global -Force -ErrorAction SilentlyContinue
  }

  It 'Passes -SourceRepoFolderNames matching JunctionFolderNames (default .vscode only)' {
    New-SprintStage1 `
      -GitRoot $script:tempGitRoot `
      -Owner 'owner' `
      -SprintNumber '0010' `
      -Confirm:$false | Out-Null

    $global:stage1JunctionCalls | Should -HaveCount 1
    (@($global:stage1JunctionCalls[0].SourceRepoFolderNames) -join ',') | Should -Be '.vscode'
  }

  It 'An explicit JunctionFolderNames override flows through to the source scan too' {
    New-SprintStage1 `
      -GitRoot $script:tempGitRoot `
      -Owner 'owner' `
      -SprintNumber '0010' `
      -JunctionFolderNames @('.claude', '.github', '.vscode') `
      -Confirm:$false | Out-Null

    $global:stage1JunctionCalls | Should -HaveCount 1
    @($global:stage1JunctionCalls[0].SourceRepoFolderNames) | Should -Contain '.claude'
  }
}

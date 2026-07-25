#Requires -Version 7.0

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
    [PSCustomObject]@{
      Success = $true
      JunctionsCreated = 3
      Errors = @()
    }
  }
  function global:Initialize-DownstreamSprintFromSharedVSCode {}
  # Task 12.2.b: New-SprintStage1 provisions the worktree via the single Start
  # entry point. Healthy fake so the stage continues into the artifact steps.
  function global:Set-SprintBoundaryContext {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
      [string]$Boundary, [string]$SharedVSCodeWorktreePath, [string[]]$WorktreePaths = @(),
      [string]$TemplateRef, [string]$Profile, [string[]]$JunctionFolderNames,
      [string[]]$StableJunctionFolderNames, [string]$GitRoot,
      [switch]$SkipSharedVSCodeSettings, [switch]$SkipProfileSymlinks,
      [switch]$AllowUserGlobalWrite, [switch]$CheckpointConfirmed, [switch]$SkipAIAdapterLifecycle
    )
    [PSCustomObject]@{
      Boundary = $Boundary; DryRun = $false; Concerns = @(); Errors = @()
      PerWorktree = @(foreach ($wt in $WorktreePaths) {
        [PSCustomObject]@{
          WorktreePath = $wt; StableRepoPath = $null
          JunctionsRetargeted = $true; ContextRetargeted = $true
          AISettingsProcessed = $true; AISettingsDriftClean = $true
          JunctionError = $null; ContextError = $null; AdapterError = $null; Error = $null
        }
      })
    }
  }
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
    'Set-SprintBoundaryContext'
    'Get-SprintHistoryReconstruction'
  ) | ForEach-Object {
    Remove-Item -Path "Function:\$_" -Force -ErrorAction SilentlyContinue
  }
}

Describe 'New-SprintStage1 task artifact templating (Task 10.11)' -Tag 'Unit', 'PromotedModuleHostSensitive' {
  BeforeEach {
    $script:tempGitRoot = Join-Path ([System.IO.Path]::GetTempPath()) "stage1_tasks_$([guid]::NewGuid().ToString('N'))"
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
      ''
      '## Stream SEC - Prior security'
      ''
      '- [x] **Task 9.2** [SharedVSCode] - PRIOR-CLOSED-TASK-SENTINEL'
    )
    Set-Content -LiteralPath (Join-Path $script:planningWorktree 'Tasks.Sprint0009.html') -Encoding UTF8 -Value '<html>prior board</html>'
    Set-Content -LiteralPath (Join-Path $script:planningWorktree 'Tasks.Sprint0009.Accomplished.html') -Encoding UTF8 -Value '<html>prior accomplishments</html>'
    Set-Content -LiteralPath (Join-Path $script:planningWorktree 'Tasks.Sprint0009.ProceduralDetails.html') -Encoding UTF8 -Value '<html>prior procedures</html>'
  }

  AfterEach {
    Remove-Item -LiteralPath $script:tempGitRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'creates the new sprint set without carrying prior task content' {
    $result = New-SprintStage1 `
      -GitRoot $script:tempGitRoot `
      -Owner 'owner' `
      -SprintNumber '0010' `
      -Confirm:$false

    $result.planning.error | Should -BeNullOrEmpty

    $markdownPath = Join-Path $script:planningWorktree 'Tasks.Sprint0010.md'
    $boardPath = Join-Path $script:planningWorktree 'Tasks.Sprint0010.html'
    $accomplishedPath = Join-Path $script:planningWorktree 'Tasks.Sprint0010.Accomplished.html'
    $proceduralPath = Join-Path $script:planningWorktree 'Tasks.Sprint0010.ProceduralDetails.html'

    Test-Path -LiteralPath $markdownPath | Should -BeTrue
    Test-Path -LiteralPath $boardPath | Should -BeTrue
    Test-Path -LiteralPath $accomplishedPath | Should -BeTrue
    Test-Path -LiteralPath $proceduralPath | Should -BeTrue

    $markdown = Get-Content -LiteralPath $markdownPath -Raw
    $markdown | Should -Match '# Current Sprint: Sprint 10 - Planning in progress'
    $markdown | Should -Match '## Stream M - Sprint 0010 planning \[DRAFT\]'
    $markdown | Should -Match '## Stream SEC - Sprint 0010 planning \[DRAFT\]'
    $markdown | Should -Not -Match 'PRIOR-GOAL-SENTINEL|PRIOR-TASK-SENTINEL|PRIOR-CLOSED-TASK-SENTINEL'

    $board = Get-Content -LiteralPath $boardPath -Raw
    $board | Should -Match 'Sprint 10 - Planning in progress'
    $board | Should -Match 'const STREAMS='
    $board | Should -Not -Match 'PRIOR-TASK-SENTINEL'

    (Get-Content -LiteralPath $accomplishedPath -Raw) | Should -Match '<main class="entries">\s*</main>'
    (Get-Content -LiteralPath $proceduralPath -Raw) | Should -Match '<main class="procedures">\s*</main>'
  }

  It 'removes prior-sprint task artifacts after using them as templates' {
    New-SprintStage1 `
      -GitRoot $script:tempGitRoot `
      -Owner 'owner' `
      -SprintNumber '0010' `
      -Confirm:$false | Out-Null

    Test-Path -LiteralPath (Join-Path $script:planningWorktree 'Tasks.Sprint0009.md') | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $script:planningWorktree 'Tasks.Sprint0009.html') | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $script:planningWorktree 'Tasks.Sprint0009.Accomplished.html') | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $script:planningWorktree 'Tasks.Sprint0009.ProceduralDetails.html') | Should -BeFalse
  }
}

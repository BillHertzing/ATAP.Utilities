# Task 10.14.a — New-SprintStage2 must generate and verify the sprint Overview
# workspace (OverviewSprintNNNN.code-workspace) so a fresh sprint start always
# produces the manifest that Build-CLAUDEPerRepository / CLAUDE.md propagation
# (Task 10.3) depend on, with no manual agent step.
BeforeAll {
  Remove-Module 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell' -Force -ErrorAction SilentlyContinue
  # New-SprintStage2's begin block runs an autoload contract (Get-Command -Name
  # <exported>) over its dependencies. On a workstation where the installed
  # ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell module is on PSModulePath, that lookup
  # triggers module auto-loading, which imports the REAL exported functions and
  # overwrites the global test stubs below (e.g. New-OverviewSprintWorkspace,
  # Set-WorktreeJunctions). Suppress auto-loading for the duration of the test so
  # the stubs always win; private functions are unaffected. Restored in AfterAll.
  $script:priorModuleAutoLoad = $global:PSModuleAutoLoadingPreference
  $global:PSModuleAutoLoadingPreference = 'None'

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  $script:stubbedFunctionNames = @(
    'Assert-GitAvailable',
    'gh',
    'git',
    'Set-WorktreeJunctions',
    'Initialize-DownstreamSprintFromSharedVSCode',
    'Initialize-SprintAIAdapters',
    'Set-SprintBoundaryContext',
    'Set-ClaudeSettingsSymlink',
    'Set-PowerShell7ProfileSymlink',
    'Set-UserSettingsSymlink',
    'Get-SprintTaskRepositoryNames',
    'Initialize-ATAPConfigurationGlobals',
    'Set-BuildMasterSprintVariables',
    'Reset-SprintDatabases',
    'New-OverviewSprintWorkspace',
    'Build-AIInstructionsPerRepository'
  )

  function global:Assert-GitAvailable { }

  function global:gh {
    $global:LASTEXITCODE = 0
    'https://github.com/owner/ATAP.Utilities/issues/321'
  }

  function global:git {
    $addIndex = [Array]::IndexOf($args, 'add')
    if ($addIndex -ge 0 -and $args.Count -gt ($addIndex + 1)) {
      New-Item -ItemType Directory -Path $args[$addIndex + 1] -Force | Out-Null
    }
    $global:LASTEXITCODE = 0
    ''
  }

  function global:Set-WorktreeJunctions {
    [PSCustomObject]@{ Success = $true; JunctionsCreated = 3; Errors = @() }
  }

  function global:Initialize-DownstreamSprintFromSharedVSCode { }
  function global:Initialize-SprintAIAdapters { }
  # Task 12.2.b: New-SprintStage2 provisions each worktree via the single Start
  # entry point. Healthy fake so the stage continues into the Overview step.
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
  function global:Set-ClaudeSettingsSymlink { }
  function global:Set-PowerShell7ProfileSymlink {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$ATAPUtilitiesRoot, [string]$ATAPIACRoot)
    $global:overviewStubCalls.Add('Set-PowerShell7ProfileSymlink') | Out-Null
    [PSCustomObject]@{ Ok = $true; Failures = @() }
  }
  function global:Set-UserSettingsSymlink { }

  function global:Get-SprintTaskRepositoryNames {
    param($TasksContent, $ExcludeRepos)
    , @('ATAP.Utilities')
  }

  function global:Initialize-ATAPConfigurationGlobals {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$RepositoryRoot)
    if (-not ($global:configRootKeys -is [hashtable]) -or $global:configRootKeys.Count -eq 0) {
      $global:configRootKeys = @{ DatabasesCollectionConfigRootKey = 'Databases' }
    }
    if (-not ($global:settings -is [hashtable]) -or $global:settings.Count -eq 0) {
      $global:settings = @{ Databases = @{ ATAPUtilities = @{ DatabaseHost = 'localhost'; ConnectionMethod = 'tcp' } } }
    }
    [PSCustomObject]@{ Initialized = $true }
  }

  function global:Set-BuildMasterSprintVariables {
    [PSCustomObject]@{ variablesSet = @('SprintNumber'); errors = @() }
  }

  function global:Reset-SprintDatabases {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$DatabaseHost, [string]$ConnectionMethod, [string]$RepositoryRoot, [string]$ProvisioningScriptsPath)
    @()
  }

  function global:Build-AIInstructionsPerRepository {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$WorktreeRoot, [string]$WorkspacePath)
    $global:overviewStubCalls.Add('Build-AIInstructionsPerRepository') | Out-Null
    [PSCustomObject]@{
      Success                = $true
      WorkspacePath          = $WorkspacePath
      RepositoriesDiscovered = 2
      Builders               = [PSCustomObject]@{}
      Errors                 = @()
    }
  }

  # Behaviour of the Overview workspace generator stub is controlled per test
  # via $global:overviewStubMode:
  #   'valid'      -> writes a workspace containing a sprint worktree folder
  #   'nofolders'  -> writes a workspace whose folders resolve no sprint worktree
  #   'nofile'     -> returns a path but writes nothing (file missing)
  function global:New-OverviewSprintWorkspace {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
      [int]$SprintNumber,
      [string]$GitRoot,
      [string]$DeveloperUsername,
      [string]$BuildMasterBaseUrl,
      [string]$ProGetBaseUrl
    )
    $global:overviewStubCalls.Add('New-OverviewSprintWorkspace') | Out-Null
    $sprintText = '{0:D4}' -f $SprintNumber
    $outputPath = Join-Path $GitRoot ("Overview.Sprint.{0}.code-workspace" -f $sprintText)

    switch ($global:overviewStubMode) {
      'nofile' { }
      'nofolders' {
        $ws = [PSCustomObject]@{ folders = @([PSCustomObject]@{ path = 'ATAP.Utilities' }) }
        Set-Content -LiteralPath $outputPath -Value ($ws | ConvertTo-Json -Depth 10) -Encoding UTF8
      }
      default {
        $ws = [PSCustomObject]@{
          folders = @(
            [PSCustomObject]@{ path = "_Planning-wt-456-Sprint-$sprintText-work-items" }
            [PSCustomObject]@{ path = "ATAP.Utilities-wt-321-Sprint-$sprintText-work-items" }
          )
        }
        Set-Content -LiteralPath $outputPath -Value ($ws | ConvertTo-Json -Depth 10) -Encoding UTF8
      }
    }

    [PSCustomObject]@{ OutputWorkspacePath = $outputPath; SprintNumber = $sprintText; FolderCount = 2 }
  }

  . "$PSScriptRoot\..\..\public\New-SprintStage2Result.ps1"
  . "$PSScriptRoot\..\..\public\New-SprintStage2.ps1"
}

AfterAll {
  foreach ($name in $script:stubbedFunctionNames) {
    Remove-Item -Path "Function:\$name" -Force -ErrorAction SilentlyContinue
  }
  Remove-Variable -Name overviewStubCalls -Scope Global -Force -ErrorAction SilentlyContinue
  Remove-Variable -Name overviewStubMode -Scope Global -Force -ErrorAction SilentlyContinue
  $global:PSModuleAutoLoadingPreference = $script:priorModuleAutoLoad
}

Describe 'New-SprintStage2 Overview workspace generation (Task 10.14.a)' -Tag 'Unit', 'PromotedModuleHostSensitive' {
  BeforeEach {
    $global:overviewStubCalls = [System.Collections.Generic.List[string]]::new()
    $global:overviewStubMode = 'valid'
    $script:tempGitRoot = Join-Path ([System.IO.Path]::GetTempPath()) "stage2_overview_$([guid]::NewGuid().ToString('N'))"
    $repoPath = Join-Path $script:tempGitRoot 'ATAP.Utilities'
    New-Item -ItemType Directory -Path (Join-Path $repoPath '.git') -Force | Out-Null

    $script:tasksPath = Join-Path $script:tempGitRoot 'TASKS.md'
    Set-Content -LiteralPath $script:tasksPath -Encoding UTF8 -Value @(
      '- [ ] **Task 9.1** [ATAP.Utilities] - Test overview workspace wiring'
    )

    $script:stage1 = [PSCustomObject]@{
      nextSprintNumber = '0008'
      sharedVSCode     = @{
        issueNumber  = '123'
        branchName   = '123-Sprint-0008-work-items'
        worktreePath = (Join-Path $script:tempGitRoot 'SharedVSCode-wt-123-Sprint-0008-work-items')
      }
      planning         = @{
        worktreePath = (Join-Path $script:tempGitRoot '_Planning-wt-456-Sprint-0008-work-items')
      }
    }

    $script:oldConfigRootKeys = $global:configRootKeys
    $script:oldSettings = $global:settings
    $global:configRootKeys = @{ DatabasesCollectionConfigRootKey = 'Databases' }
    $global:settings = @{ Databases = @{ ATAPUtilities = @{ DatabaseHost = 'localhost'; ConnectionMethod = 'tcp' } } }
  }

  AfterEach {
    $global:configRootKeys = $script:oldConfigRootKeys
    $global:settings = $script:oldSettings
    Remove-Item -LiteralPath $script:tempGitRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'generates and verifies the Overview sprint workspace after worktrees exist' {
    $result = New-SprintStage2 `
      -Stage1Result $script:stage1 `
      -TasksFilePath $script:tasksPath `
      -GitRoot $script:tempGitRoot `
      -Owner 'owner' `
      -SkipDatabaseReset `
      -Confirm:$false

    $global:overviewStubCalls | Should -Contain 'New-OverviewSprintWorkspace'
    $expected = Join-Path $script:tempGitRoot 'Overview.Sprint.0008.code-workspace'
    $result.infrastructure.overviewWorkspacePath | Should -Be $expected
    $result.infrastructure.overviewWorkspaceVerified | Should -BeTrue
    $result.infrastructure.overviewWorkspaceError | Should -BeNullOrEmpty
    $global:overviewStubCalls |
      Where-Object { $_ -eq 'Build-AIInstructionsPerRepository' } |
      Should -HaveCount 1
    $result.infrastructure.aiInstructions.Success | Should -BeTrue
    $result.infrastructure.aiInstructionsError | Should -BeNullOrEmpty
    Test-Path -LiteralPath $expected | Should -BeTrue
  }

  It 'fails the verification gate (non-fatally) when no sprint worktree folder resolves' {
    $global:overviewStubMode = 'nofolders'

    $result = New-SprintStage2 `
      -Stage1Result $script:stage1 `
      -TasksFilePath $script:tasksPath `
      -GitRoot $script:tempGitRoot `
      -Owner 'owner' `
      -SkipDatabaseReset `
      -Confirm:$false

    $result.infrastructure.overviewWorkspaceVerified | Should -BeFalse
    $result.infrastructure.overviewWorkspaceError | Should -Match 'no sprint worktree folders'
    # Stage 2 still returns its full result object rather than throwing.
    $result.repoResults.repoName | Should -Contain 'ATAP.Utilities'
  }

  It 'fails the verification gate (non-fatally) when the workspace file is missing' {
    $global:overviewStubMode = 'nofile'

    $result = New-SprintStage2 `
      -Stage1Result $script:stage1 `
      -TasksFilePath $script:tasksPath `
      -GitRoot $script:tempGitRoot `
      -Owner 'owner' `
      -SkipDatabaseReset `
      -Confirm:$false

    $result.infrastructure.overviewWorkspaceVerified | Should -BeFalse
    $result.infrastructure.overviewWorkspaceError | Should -Match 'was not created'
  }

  It 'skips generation under DryRun/WhatIf and writes no workspace file' {
    $result = New-SprintStage2 `
      -Stage1Result $script:stage1 `
      -TasksFilePath $script:tasksPath `
      -GitRoot $script:tempGitRoot `
      -Owner 'owner' `
      -DryRun

    $global:overviewStubCalls | Should -Not -Contain 'New-OverviewSprintWorkspace'
    $global:overviewStubCalls | Should -Not -Contain 'Build-AIInstructionsPerRepository'
    $result.infrastructure.overviewWorkspaceVerified | Should -BeFalse
    $result.infrastructure.aiInstructions.DryRun | Should -BeTrue
    $result.infrastructure.aiInstructionsError | Should -BeNullOrEmpty
    Test-Path -LiteralPath (Join-Path $script:tempGitRoot 'Overview.Sprint.0008.code-workspace') | Should -BeFalse
  }
}

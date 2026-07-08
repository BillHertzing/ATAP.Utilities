BeforeAll {
  Remove-Module 'ATAP.Utilities.BuildTooling.PowerShell' -Force -ErrorAction SilentlyContinue
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
    'Set-UserSettingsSymlink',
    'Get-SprintTaskRepositoryNames',
    'Initialize-ATAPConfigurationGlobals',
    'Set-BuildMasterSprintVariables',
    'New-SprintBitwardenSecrets',
    'Reset-SprintDatabases',
    'New-DeveloperSqlServerInstances',
    'New-OverviewSprintWorkspace',
    'Build-AIInstructionsPerRepository'
  )

  function global:Assert-GitAvailable {
    $global:stage2DatabaseResetCalls.Add('Assert-GitAvailable') | Out-Null
  }

  function global:gh {
    $global:stage2DatabaseResetCalls.Add('gh') | Out-Null
    $global:LASTEXITCODE = 0
    'https://github.com/owner/ATAP.Utilities/issues/321'
  }

  function global:git {
    $global:stage2DatabaseResetCalls.Add("git:$($args -join ' ')") | Out-Null
    $addIndex = [Array]::IndexOf($args, 'add')
    if ($addIndex -ge 0 -and $args.Count -gt ($addIndex + 1)) {
      New-Item -ItemType Directory -Path $args[$addIndex + 1] -Force | Out-Null
    }
    $global:LASTEXITCODE = 0
    ''
  }

  function global:Set-WorktreeJunctions {
    $global:stage2DatabaseResetCalls.Add('Set-WorktreeJunctions') | Out-Null
    [PSCustomObject]@{ Success = $true; JunctionsCreated = 3; Errors = @() }
  }

  function global:Initialize-DownstreamSprintFromSharedVSCode {
    $global:stage2DatabaseResetCalls.Add('Initialize-DownstreamSprintFromSharedVSCode') | Out-Null
  }

  function global:Initialize-SprintAIAdapters {
    $global:stage2DatabaseResetCalls.Add('Initialize-SprintAIAdapters') | Out-Null
  }

  # Task 12.2.b: New-SprintStage2 provisions each worktree via the single Start
  # entry point. Healthy recording fake so the stage continues into the
  # database-reset steps under test.
  function global:Set-SprintBoundaryContext {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
      [string]$Boundary, [string]$SharedVSCodeWorktreePath, [string[]]$WorktreePaths = @(),
      [string]$TemplateRef, [string]$Profile, [string[]]$JunctionFolderNames,
      [string[]]$StableJunctionFolderNames, [string]$GitRoot,
      [switch]$SkipSharedVSCodeSettings, [switch]$SkipProfileSymlinks,
      [switch]$AllowUserGlobalWrite, [switch]$CheckpointConfirmed, [switch]$SkipAIAdapterLifecycle
    )
    $global:stage2DatabaseResetCalls.Add('Set-SprintBoundaryContext') | Out-Null
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

  function global:Set-ClaudeSettingsSymlink {
    $global:stage2DatabaseResetCalls.Add('Set-ClaudeSettingsSymlink') | Out-Null
  }

  function global:Set-UserSettingsSymlink {
    $global:stage2DatabaseResetCalls.Add('Set-UserSettingsSymlink') | Out-Null
  }

  function global:Get-SprintTaskRepositoryNames {
    param($TasksContent, $ExcludeRepos)
    $global:stage2DatabaseResetCalls.Add('Get-SprintTaskRepositoryNames') | Out-Null
    , @('ATAP.Utilities')
  }

  function global:Initialize-ATAPConfigurationGlobals {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$RepositoryRoot)

    $global:stage2DatabaseResetCalls.Add('Initialize-ATAPConfigurationGlobals') | Out-Null
    if (-not ($global:configRootKeys -is [hashtable]) -or $global:configRootKeys.Count -eq 0) {
      $global:configRootKeys = @{ DatabasesCollectionConfigRootKey = 'Databases' }
    }
    if (-not ($global:settings -is [hashtable]) -or $global:settings.Count -eq 0) {
      $global:settings = @{
        Databases = @{
          ATAPUtilities = @{
            DatabaseHost     = 'localhost'
            ConnectionMethod = 'tcp'
          }
        }
      }
    }

    [PSCustomObject]@{
      Initialized         = $true
      ConfigRootKeysCount = $global:configRootKeys.Count
      SettingsCount       = $global:settings.Count
    }
  }

  function global:Set-BuildMasterSprintVariables {
    $global:stage2DatabaseResetCalls.Add('Set-BuildMasterSprintVariables') | Out-Null
    [PSCustomObject]@{ variablesSet = @('SprintNumber'); errors = @() }
  }

  function global:New-SprintBitwardenSecrets {
    $global:stage2DatabaseResetCalls.Add('New-SprintBitwardenSecrets') | Out-Null
    @([PSCustomObject]@{ Name = 'connection-string-secret'; Created = $true })
  }

  function global:Reset-SprintDatabases {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
      [string]$DatabaseHost,
      [string]$ConnectionMethod,
      [string]$RepositoryRoot,
      [string]$ProvisioningScriptsPath
    )
    $global:stage2DatabaseResetCalls.Add('Reset-SprintDatabases') | Out-Null
    $global:stage2DatabaseResetParameters = @{}
    foreach ($key in $PSBoundParameters.Keys) {
      $global:stage2DatabaseResetParameters[$key] = $PSBoundParameters[$key]
    }
    @(
      [PSCustomObject]@{ instanceName = 'Devtester'; database = 'ATAPUtilities'; reset = $true; migrated = $true; error = $null }
      [PSCustomObject]@{ instanceName = 'Exptester'; database = 'ATAPUtilities'; reset = $true; migrated = $true; error = $null }
    )
  }

  function global:New-DeveloperSqlServerInstances {
    $global:stage2DatabaseResetCalls.Add('New-DeveloperSqlServerInstances') | Out-Null
    throw 'New-SprintStage2 must not call New-DeveloperSqlServerInstances.'
  }

  function global:Build-AIInstructionsPerRepository {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$WorktreeRoot, [string]$WorkspacePath)
    $global:stage2DatabaseResetCalls.Add('Build-AIInstructionsPerRepository') | Out-Null
    [PSCustomObject]@{
      Success                = $true
      WorkspacePath          = $WorkspacePath
      RepositoriesDiscovered = 1
      Builders               = [PSCustomObject]@{}
      Errors                 = @()
    }
  }

  function global:New-OverviewSprintWorkspace {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
      [int]$SprintNumber,
      [string]$GitRoot,
      [string]$DeveloperUsername,
      [string]$BuildMasterBaseUrl,
      [string]$ProGetBaseUrl
    )
    $global:stage2DatabaseResetCalls.Add('New-OverviewSprintWorkspace') | Out-Null
    $sprintText = '{0:D4}' -f $SprintNumber
    $outputPath = Join-Path $GitRoot ("OverviewSprint{0}.code-workspace" -f $sprintText)
    $workspace = [PSCustomObject]@{
      folders = @([PSCustomObject]@{ path = "ATAP.Utilities-wt-1-Sprint-$sprintText-work-items" })
    }
    Set-Content -LiteralPath $outputPath -Value ($workspace | ConvertTo-Json -Depth 10) -Encoding UTF8
    [PSCustomObject]@{
      OutputWorkspacePath = $outputPath
      SprintNumber        = $sprintText
      FolderCount         = 1
    }
  }

  . "$PSScriptRoot\..\..\public\New-SprintStage2Result.ps1"
  . "$PSScriptRoot\..\..\public\New-SprintStage2.ps1"
}

AfterAll {
  foreach ($name in $script:stubbedFunctionNames) {
    Remove-Item -Path "Function:\$name" -Force -ErrorAction SilentlyContinue
  }
  Remove-Variable -Name stage2DatabaseResetCalls -Scope Global -Force -ErrorAction SilentlyContinue
  Remove-Variable -Name stage2DatabaseResetParameters -Scope Global -Force -ErrorAction SilentlyContinue
}

Describe 'New-SprintStage2 database reset wiring' -Tag 'Unit' {
  BeforeEach {
    $script:priorWhatIf = $WhatIfPreference
    $WhatIfPreference = $false
    $global:stage2DatabaseResetCalls = [System.Collections.Generic.List[string]]::new()
    $global:stage2DatabaseResetParameters = @{}
    $script:tempGitRoot = Join-Path ([System.IO.Path]::GetTempPath()) "stage2_dbreset_$([guid]::NewGuid().ToString('N'))"
    $repoPath = Join-Path $script:tempGitRoot 'ATAP.Utilities'
    New-Item -ItemType Directory -Path (Join-Path $repoPath '.git') -Force | Out-Null

    $script:tasksPath = Join-Path $script:tempGitRoot 'TASKS.md'
    Set-Content -LiteralPath $script:tasksPath -Encoding UTF8 -Value @(
      '- [ ] **Task 8.2** [ATAP.Utilities] - Test database reset wiring'
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
    $global:settings = @{
      Databases = @{
        ATAPUtilities = @{
          DatabaseHost     = 'localhost'
          ConnectionMethod = 'tcp'
        }
      }
    }

    Mock -CommandName Get-Service -MockWith {
      [PSCustomObject]@{ Name = $Name; Status = 'Running' }
    } -ParameterFilter { $Name -like 'MSSQL$*' }
  }

  AfterEach {
    $WhatIfPreference = $script:priorWhatIf
    $global:configRootKeys = $script:oldConfigRootKeys
    $global:settings = $script:oldSettings
    Remove-Item -LiteralPath $script:tempGitRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'uses Reset-SprintDatabases and returns per-database reset results' {
    $result = New-SprintStage2 `
      -Stage1Result $script:stage1 `
      -TasksFilePath $script:tasksPath `
      -GitRoot $script:tempGitRoot `
      -Owner 'owner' `
      -Confirm:$false `
      -WhatIf:$false

    if (-not $WhatIfPreference) {
      $global:stage2DatabaseResetCalls | Should -Contain 'Reset-SprintDatabases'
      $global:stage2DatabaseResetCalls | Should -Not -Contain 'New-DeveloperSqlServerInstances'
      $global:stage2DatabaseResetParameters['RepositoryRoot'] |
        Should -Be (Join-Path $script:tempGitRoot 'ATAP.Utilities-wt-321-Sprint-0008-work-items')
      $global:stage2DatabaseResetParameters['ProvisioningScriptsPath'] |
        Should -Be (Join-Path $script:tempGitRoot 'ATAP.Utilities-wt-321-Sprint-0008-work-items\src\ATAP.Utilities.DatabaseManagement\SharedSQL')
      $global:stage2DatabaseResetParameters['Confirm'] | Should -BeFalse
      $result.infrastructure.PSObject.Properties.Name | Should -Contain 'databaseResets'
      $result.infrastructure.PSObject.Properties.Name | Should -Not -Contain 'databaseInstances'
      $result.infrastructure.databaseResets.Count | Should -Be 2
      $result.infrastructure.databaseResetError | Should -BeNullOrEmpty
    } else {
      $global:stage2DatabaseResetCalls | Should -Not -Contain 'Reset-SprintDatabases'
      $result.infrastructure.databaseResets | Should -BeNullOrEmpty
    }
  }

  It 'fails before downstream side effects when required SQL Server instances are missing' {
    Mock -CommandName Get-Service -MockWith { $null } -ParameterFilter { $Name -like 'MSSQL$*' }

    {
      New-SprintStage2 `
        -Stage1Result $script:stage1 `
        -TasksFilePath $script:tasksPath `
        -GitRoot $script:tempGitRoot `
        -Owner 'owner' `
        -Confirm:$false `
        -WhatIf:$false
    } | Should -Throw -ExpectedMessage '*developer onboarding SQL Server instance setup*'

    $global:stage2DatabaseResetCalls | Should -Not -Contain 'gh'
    $global:stage2DatabaseResetCalls | Should -Not -Contain 'Reset-SprintDatabases'
    $global:stage2DatabaseResetCalls | Should -Not -Contain 'New-DeveloperSqlServerInstances'
  }

  It 'bootstraps missing configuration globals before Stage 2 side effects' {
    $global:configRootKeys = $null
    $global:settings = $null

    $result = New-SprintStage2 `
      -Stage1Result $script:stage1 `
      -TasksFilePath $script:tasksPath `
      -GitRoot $script:tempGitRoot `
      -Owner 'owner' `
      -SkipDatabaseReset `
      -Confirm:$false `
      -WhatIf:$false

    if (-not $WhatIfPreference) {
      $global:stage2DatabaseResetCalls[0] | Should -Be 'Initialize-ATAPConfigurationGlobals'
      $global:configRootKeys['DatabasesCollectionConfigRootKey'] | Should -Be 'Databases'
      $global:settings.ContainsKey('Databases') | Should -BeTrue
    } else {
      $global:stage2DatabaseResetCalls | Should -Not -Contain 'Initialize-ATAPConfigurationGlobals'
    }
    $result.infrastructure.databaseResets | Should -BeNullOrEmpty
  }

  It 'skips the SQL instance guard and reset when SkipDatabaseReset is supplied' {
    Mock -CommandName Get-Service -MockWith { $null } -ParameterFilter { $Name -like 'MSSQL$*' }

    {
      New-SprintStage2 `
        -Stage1Result $script:stage1 `
        -TasksFilePath $script:tasksPath `
        -GitRoot $script:tempGitRoot `
        -Owner 'owner' `
        -SkipDatabaseReset `
        -Confirm:$false `
        -WhatIf:$false
    } | Should -Not -Throw

    $global:stage2DatabaseResetCalls | Should -Not -Contain 'Reset-SprintDatabases'
  }

  It 'provisions IncludeRepos entries that are absent from task-board markers' {
    New-Item -ItemType Directory -Path (Join-Path $script:tempGitRoot 'ATAP.IAC\.git') -Force | Out-Null

    $result = New-SprintStage2 `
      -Stage1Result $script:stage1 `
      -TasksFilePath $script:tasksPath `
      -GitRoot $script:tempGitRoot `
      -Owner 'owner' `
      -IncludeRepos 'ATAP.IAC' `
      -SkipDatabaseReset `
      -Confirm:$false

    $result.repoResults.repoName | Should -Contain 'ATAP.Utilities'
    $result.repoResults.repoName | Should -Contain 'ATAP.IAC'
    $result.repoResults.Count | Should -Be 2
  }
}

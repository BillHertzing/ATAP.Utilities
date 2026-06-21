BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  # K04: single tracking list for every external command the dry-run stubs
  # receive. Created before the dot-source so any load-time side effect would be
  # recorded; the stubs also throw, since none of them may run during DryRun.
  $global:dryRunExternalCalls = [System.Collections.Generic.List[string]]::new()
  $script:dryRunStubbedFunctionNames = @(
    'Assert-GitAvailable'
    'gh'
    'git'
    'Set-WorktreeJunctions'
    'Initialize-DownstreamSprintFromSharedVSCode'
    'Initialize-SprintAIAdapters'
    'Set-ClaudeSettingsSymlink'
    'Set-UserSettingsSymlink'
    'Get-SprintTaskRepositoryNames'
    'Initialize-ATAPConfigurationGlobals'
    'New-DeveloperSqlServerInstances'
    'Reset-SprintDatabases'
    'Set-BuildMasterSprintVariables'
    'New-SprintBitwardenSecrets'
  )
  $script:dryRunOriginalFunctions = @{}
  foreach ($name in $script:dryRunStubbedFunctionNames) {
    $existing = Get-Command -Name $name -CommandType Function -ErrorAction SilentlyContinue
    if ($existing) {
      $script:dryRunOriginalFunctions[$name] = $existing.ScriptBlock
    }
  }

  function global:Assert-GitAvailable {
    $global:dryRunExternalCalls.Add('Assert-GitAvailable') | Out-Null
    throw 'Assert-GitAvailable should not be called during DryRun.'
  }

  function global:gh {
    $global:dryRunExternalCalls.Add('gh') | Out-Null
    throw 'gh should not be called during DryRun.'
  }

  function global:git {
    $global:dryRunExternalCalls.Add('git') | Out-Null
    throw 'git should not be called during DryRun.'
  }

  function global:Set-WorktreeJunctions {
    $global:dryRunExternalCalls.Add('Set-WorktreeJunctions') | Out-Null
    throw 'Set-WorktreeJunctions should not be called during DryRun.'
  }

  function global:Initialize-DownstreamSprintFromSharedVSCode {
    $global:dryRunExternalCalls.Add('Initialize-DownstreamSprintFromSharedVSCode') | Out-Null
    throw 'Initialize-DownstreamSprintFromSharedVSCode should not be called during DryRun.'
  }

  function global:Initialize-SprintAIAdapters {
    $global:dryRunExternalCalls.Add('Initialize-SprintAIAdapters') | Out-Null
    throw 'Initialize-SprintAIAdapters should not be called during DryRun.'
  }

  # Required by the Stage 2 autoload-or-throw contract (FSS-11). These are guarded
  # by ShouldProcess so they never run during DryRun; the throwing body is a canary
  # if that ever changes.
  function global:Set-ClaudeSettingsSymlink {
    $global:dryRunExternalCalls.Add('Set-ClaudeSettingsSymlink') | Out-Null
    throw 'Set-ClaudeSettingsSymlink should not be called during DryRun.'
  }

  function global:Set-UserSettingsSymlink {
    $global:dryRunExternalCalls.Add('Set-UserSettingsSymlink') | Out-Null
    throw 'Set-UserSettingsSymlink should not be called during DryRun.'
  }

  # Repo discovery is pure text parsing (no external side effect) and runs even in
  # DryRun, so this stub returns the repo list rather than throwing.
  function global:Get-SprintTaskRepositoryNames {
    param($TasksContent, $ExcludeRepos)
    , @('ATAP.Utilities')
  }

  function global:Initialize-ATAPConfigurationGlobals {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$RepositoryRoot)

    $global:dryRunExternalCalls.Add('Initialize-ATAPConfigurationGlobals') | Out-Null
    $global:configRootKeys = @{ DatabasesCollectionConfigRootKey = 'Databases' }
    $global:settings = @{
      Databases = @{
        ATAPUtilities = @{
          DatabaseHost     = 'localhost'
          ConnectionMethod = 'tcp'
        }
      }
    }
    [PSCustomObject]@{
      Initialized         = $true
      ConfigRootKeysCount = 1
      SettingsCount       = 1
    }
  }

  function global:New-DeveloperSqlServerInstances {
    $global:dryRunExternalCalls.Add('New-DeveloperSqlServerInstances') | Out-Null
    throw 'New-DeveloperSqlServerInstances should not be called during DryRun.'
  }

  function global:Reset-SprintDatabases {
    $global:dryRunExternalCalls.Add('Reset-SprintDatabases') | Out-Null
    throw 'Reset-SprintDatabases should not be called during DryRun.'
  }

  function global:Set-BuildMasterSprintVariables {
    $global:dryRunExternalCalls.Add('Set-BuildMasterSprintVariables') | Out-Null
    throw 'Set-BuildMasterSprintVariables should not be called during DryRun.'
  }

  function global:New-SprintBitwardenSecrets {
    $global:dryRunExternalCalls.Add('New-SprintBitwardenSecrets') | Out-Null
    throw 'New-SprintBitwardenSecrets should not be called during DryRun.'
  }

  # Dot-source the function definitions. Defining the functions must not execute
  # any Stage 1 / Stage 2 work.
  . "$PSScriptRoot\..\..\public\New-SprintStage1.ps1"
  . "$PSScriptRoot\..\..\public\New-SprintStage2Result.ps1"
  . "$PSScriptRoot\..\..\public\New-SprintStage2.ps1"

  # K04: freeze the set of external calls observed up to and including the
  # dot-source. The first test below asserts this stayed empty.
  $script:callsObservedAtLoad = @($global:dryRunExternalCalls)
}

AfterAll {
  foreach ($name in $script:dryRunStubbedFunctionNames) {
    Remove-Item -Path "Function:\$name" -Force -ErrorAction SilentlyContinue
  }
  Remove-Variable -Name dryRunExternalCalls -Scope Global -Force -ErrorAction SilentlyContinue
}

Describe 'New-SprintStage dry-run support' -Tag 'Unit', 'PromotedModuleHostSensitive' {
  BeforeEach {
    $global:dryRunExternalCalls.Clear()
    $script:tempGitRoot = Join-Path ([System.IO.Path]::GetTempPath()) "sprint_dryrun_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempGitRoot -Force | Out-Null
  }

  AfterEach {
    Remove-Item -LiteralPath $script:tempGitRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'dot-sourcing the Stage scripts triggers no external commands at load time (K04)' {
    Get-Command New-SprintStage1 -CommandType Function -ErrorAction SilentlyContinue |
      Should -Not -BeNullOrEmpty
    $script:callsObservedAtLoad | Should -BeNullOrEmpty -Because (
      'loading the function files must only define the functions. ' +
      "Commands observed during dot-source: $($script:callsObservedAtLoad -join ', ')"
    )
  }

  It 'previews Stage 1 without external side effects' {
    $result = New-SprintStage1 -GitRoot $script:tempGitRoot -Owner 'owner' -SprintNumber '0007' -DryRun

    $result.nextSprintNumber | Should -Be '0007'
    $result.previousSprintNumber | Should -Be '0006'
    $result.dryRun | Should -BeTrue
    $result.sharedVSCode.issueNumber | Should -Be 'DRYRUN'
    $result.sharedVSCode.branchName | Should -Be 'DRYRUN-Sprint-0007-work-items'
    $result.sharedVSCode.worktreePath | Should -Be (Join-Path $script:tempGitRoot 'SharedVSCode-wt-DRYRUN-Sprint-0007-work-items')
    $result.sharedVSCode.created | Should -BeFalse
    $result.planning.issueNumber | Should -Be 'DRYRUN'
    $result.planning.branchName | Should -Be 'DRYRUN-Sprint-0007-work-items'
    $result.planning.worktreePath | Should -Be (Join-Path $script:tempGitRoot '_Planning-wt-DRYRUN-Sprint-0007-work-items')
    $result.planning.created | Should -BeFalse
    $result.planning.junctionsCreated | Should -BeFalse
    $global:dryRunExternalCalls.Count | Should -Be 0
  }

  It 'previews Stage 2 without downstream side effects' {
    $tasksPath = Join-Path $script:tempGitRoot 'TASKS.md'
    Set-Content -LiteralPath $tasksPath -Encoding UTF8 -Value @(
      '- [ ] **Task 7.99** [ATAP.Utilities] [Junior] - Test dry run'
    )

    $stage1 = [PSCustomObject]@{
      nextSprintNumber = '0007'
      sharedVSCode     = @{
        issueNumber  = 'DRYRUN'
        branchName   = 'DRYRUN-Sprint-0007-work-items'
        worktreePath = (Join-Path $script:tempGitRoot 'SharedVSCode-wt-DRYRUN-Sprint-0007-work-items')
      }
      planning         = @{
        worktreePath = (Join-Path $script:tempGitRoot '_Planning-wt-DRYRUN-Sprint-0007-work-items')
      }
    }

    $result = New-SprintStage2 -Stage1Result $stage1 -TasksFilePath $tasksPath -GitRoot $script:tempGitRoot -Owner 'owner' -DryRun

    $result.repoResults.Count | Should -Be 1
    $result.dryRun | Should -BeTrue
    $result.repoResults[0].repoName | Should -Be 'ATAP.Utilities'
    $result.repoResults[0].issueNumber | Should -Be 'DRYRUN'
    $result.repoResults[0].branchName | Should -Be 'DRYRUN-Sprint-0007-work-items'
    $result.repoResults[0].worktreePath | Should -Be (Join-Path $script:tempGitRoot 'ATAP.Utilities-wt-DRYRUN-Sprint-0007-work-items')
    $result.repoResults[0].created | Should -BeFalse
    $result.repoResults[0].dryRun | Should -BeTrue
    $result.infrastructure.buildMasterVariablesSet.Count | Should -Be 0
    # connectionStrings field removed (SC-0172 / FSS-30): sprint start creates no secrets.
    $result.infrastructure.PSObject.Properties.Name | Should -Not -Contain 'connectionStrings'
    $result.infrastructure.databaseResets.Count | Should -Be 0
    $global:dryRunExternalCalls.Count | Should -Be 0
  }

  It 'resolves the Tasks.SprintNNNN.md default produced by Stage 1' {
    $planningWorktreePath = Join-Path $script:tempGitRoot '_Planning-wt-DRYRUN-Sprint-0007-work-items'
    New-Item -ItemType Directory -Path $planningWorktreePath -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $planningWorktreePath 'Tasks.Sprint0007.md') -Encoding UTF8 -Value @(
      '- [ ] **Task 7.99** [ATAP.Utilities] [Junior] - Test current sprint filename'
    )

    $stage1 = [PSCustomObject]@{
      nextSprintNumber = '0007'
      sharedVSCode     = @{
        issueNumber  = 'DRYRUN'
        branchName   = 'DRYRUN-Sprint-0007-work-items'
        worktreePath = (Join-Path $script:tempGitRoot 'SharedVSCode-wt-DRYRUN-Sprint-0007-work-items')
      }
      planning         = @{
        worktreePath = $planningWorktreePath
      }
    }

    $result = New-SprintStage2 -Stage1Result $stage1 -GitRoot $script:tempGitRoot -Owner 'owner' -DryRun

    $result.repoResults.Count | Should -Be 1
    $result.repoResults[0].repoName | Should -Be 'ATAP.Utilities'
    $global:dryRunExternalCalls.Count | Should -Be 0
  }

  It 'bootstraps missing configuration globals before the SQL instance guard' {
    $tasksPath = Join-Path $script:tempGitRoot 'TASKS.md'
    Set-Content -LiteralPath $tasksPath -Encoding UTF8 -Value @(
      '- [ ] **Task 7.99** [ATAP.Utilities] [Junior] - Test no-profile guard'
    )

    $stage1 = [PSCustomObject]@{
      nextSprintNumber = '0007'
      sharedVSCode     = @{
        issueNumber  = '123'
        branchName   = '123-Sprint-0007-work-items'
        worktreePath = (Join-Path $script:tempGitRoot 'SharedVSCode-wt-123-Sprint-0007-work-items')
      }
      planning         = @{
        worktreePath = (Join-Path $script:tempGitRoot '_Planning-wt-456-Sprint-0007-work-items')
      }
    }

    $oldConfigRootKeys = $global:configRootKeys
    $oldSettings = $global:settings
    try {
      $global:configRootKeys = $null
      $global:settings = $null
      Mock -CommandName Get-Service -MockWith { $null } -ParameterFilter { $Name -like 'MSSQL$*' }

      {
        New-SprintStage2 `
          -Stage1Result $stage1 `
          -TasksFilePath $tasksPath `
          -GitRoot $script:tempGitRoot `
          -Owner 'owner'
      } | Should -Throw -ExpectedMessage '*developer onboarding SQL Server instance setup*'

      $global:dryRunExternalCalls | Should -Contain 'Initialize-ATAPConfigurationGlobals'
      $global:dryRunExternalCalls | Should -Not -Contain 'gh'
      $global:configRootKeys['DatabasesCollectionConfigRootKey'] | Should -Be 'Databases'
      $global:settings.ContainsKey('Databases') | Should -BeTrue
    } finally {
      $global:configRootKeys = $oldConfigRootKeys
      $global:settings = $oldSettings
    }
  }
}

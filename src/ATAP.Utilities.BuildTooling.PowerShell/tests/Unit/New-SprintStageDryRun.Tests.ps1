BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  # K04: single tracking list for every external command the dry-run stubs
  # receive. Created before the dot-source so any load-time side effect would be
  # recorded; the stubs also throw, since none of them may run during DryRun.
  $global:dryRunExternalCalls = [System.Collections.Generic.List[string]]::new()

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

  function global:New-SprintSqlServerInstances {
    $global:dryRunExternalCalls.Add('New-SprintSqlServerInstances') | Out-Null
    throw 'New-SprintSqlServerInstances should not be called during DryRun.'
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
  . "$PSScriptRoot\..\..\public\New-SprintStage2.ps1"

  # K04: freeze the set of external calls observed up to and including the
  # dot-source. The first test below asserts this stayed empty.
  $script:callsObservedAtLoad = @($global:dryRunExternalCalls)
}

Describe 'New-SprintStage dry-run support' -Tag 'Unit' {
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
    $result.repoResults[0].junctionsCreated | Should -BeFalse
    $result.repoResults[0].dryRun | Should -BeTrue
    $result.infrastructure.claudeSettingsLinked | Should -BeFalse
    $result.infrastructure.buildMasterVariablesSet.Count | Should -Be 0
    $result.infrastructure.connectionStrings.Count | Should -Be 0
    $result.infrastructure.databaseInstances.Count | Should -Be 0
    $global:dryRunExternalCalls.Count | Should -Be 0
  }

  It 'throws an actionable setup command before side effects when config globals are missing' {
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

      {
        New-SprintStage2 -Stage1Result $stage1 -TasksFilePath $tasksPath -GitRoot $script:tempGitRoot -Owner 'owner'
      } | Should -Throw -ExpectedMessage '*Set-GlobalConfigRootKeys*Get-HostSettings*'

      $global:dryRunExternalCalls.Count | Should -Be 0
    } finally {
      $global:configRootKeys = $oldConfigRootKeys
      $global:settings = $oldSettings
    }
  }
}

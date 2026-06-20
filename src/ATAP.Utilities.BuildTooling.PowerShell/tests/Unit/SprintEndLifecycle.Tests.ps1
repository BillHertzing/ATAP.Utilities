#Requires -Version 7.0

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  . (Join-Path $moduleRoot 'private\Invoke-SprintEndNativeCommand.ps1')
  foreach ($name in @(
      'Get-SprintEndContext',
      'Test-SprintEndCommandSurface',
      'Test-SprintEndWorktreeState',
      'Invoke-SprintEndGitHubClose',
      'Invoke-SprintEndOverviewClose',
      'New-SprintEndHandoff',
      'Invoke-SprintEndInfrastructureCleanup',
      'Save-SprintHistoryArtifacts',
      'Test-SprintEndBoundaryState',
      'Test-SprintEndPullOverlap',
      'Invoke-SprintEndLifecycle'
    )) {
    . (Join-Path $moduleRoot "public\$name.ps1")
  }
}

Describe 'SprintEnd typed lifecycle' -Tag 'Unit' {
  Context 'Test-SprintEndCommandSurface' {
    It 'returns one structured failure for a missing parameter contract' {
      function Test-Task106Command { param([string]$Present) }
      $result = Test-SprintEndCommandSurface -CommandContracts @{
        'Test-Task106Command' = @('Present', 'Missing')
      }

      $result.Ok | Should -BeFalse
      $result.Commands.Count | Should -Be 1
      $result.Commands[0].MissingParameters | Should -Be @('Missing')
      $result.Failures[0] | Should -Match 'Missing parameter'
    }
  }

  Context 'Test-SprintEndWorktreeState' {
    BeforeEach {
      $script:repo = Join-Path $TestDrive 'repo'
      New-Item -ItemType Directory -Path $script:repo -Force | Out-Null
      git -C $script:repo init --quiet --initial-branch=48-Sprint-0010-work-items
      git -C $script:repo config user.email 'test@example.invalid'
      git -C $script:repo config user.name 'SprintEnd Test'
      Set-Content -LiteralPath (Join-Path $script:repo 'README.md') -Value 'seed'
      git -C $script:repo add .
      git -C $script:repo commit --quiet -m seed
    }

    It 'accepts a clean worktree' {
      $result = Test-SprintEndWorktreeState -WorktreePaths @($script:repo)
      $result.Ok | Should -BeTrue
      $result.PerWorktree[0].IsClean | Should -BeTrue
    }

    It 'classifies an expected workspace mutation separately' {
      Set-Content -LiteralPath (Join-Path $script:repo 'Repo.code-workspace') -Value '{}'
      $result = Test-SprintEndWorktreeState -WorktreePaths @($script:repo)
      $result.Ok | Should -BeTrue
      $result.PerWorktree[0].ExpectedChanges.Path | Should -Contain 'Repo.code-workspace'
      $result.PerWorktree[0].UnexpectedChanges | Should -BeNullOrEmpty
    }

    It 'blocks an unexpected user change' {
      Add-Content -LiteralPath (Join-Path $script:repo 'README.md') -Value 'user change'
      $result = Test-SprintEndWorktreeState -WorktreePaths @($script:repo)
      $result.Ok | Should -BeFalse
      $result.PerWorktree[0].UnexpectedChanges.Path | Should -Contain 'README.md'
    }
  }

  Context 'New-SprintEndHandoff' {
    It 'writes an idempotent handoff without secret or instance deletion' {
      $gitRoot = Join-Path $TestDrive 'gitroot'
      $worktree = Join-Path $gitRoot 'App-wt-42-Sprint-0010-work-items'
      New-Item -ItemType Directory -Path $worktree -Force | Out-Null
      $output = Join-Path $gitRoot 'HANDOFF.md'

      $first = New-SprintEndHandoff -GitRoot $gitRoot -WorktreePaths @($worktree) -OutputPath $output -Confirm:$false
      $second = New-SprintEndHandoff -GitRoot $gitRoot -WorktreePaths @($worktree) -OutputPath $output -Confirm:$false
      $text = Get-Content -Raw -LiteralPath $output

      $first.Changed | Should -BeTrue
      $second.Changed | Should -BeFalse
      $text | Should -Match 'git -C .* worktree remove'
      $text | Should -Match 'pull --ff-only'
      $text | Should -Match 'Test-SprintEndPullOverlap'
      $text | Should -Match 'branch -D'
      $text | Should -Match 'Remove-SprintDatabases'
      $text | Should -Not -Match 'Remove-SprintBitwardenSecrets'
      $text | Should -Not -Match 'Remove-DeveloperSqlServerInstances'
      $text | Should -Match ([regex]::Escape("Remove-Item -LiteralPath '$output' -Force"))
    }
  }

  Context 'Test-SprintEndPullOverlap' {
    It 'blocks a stable pull when a local path also changed remotely' {
      Mock Invoke-SprintEndNativeCommand {
        $argsText = $ArgumentList -join ' '
        $output = switch -Regex ($argsText) {
          'status --porcelain' { @(' M claude-settings.json', '?? local-only.txt'); break }
          'diff --name-only' { @('claude-settings.json', 'remote-only.txt'); break }
          default { @() }
        }
        [PSCustomObject]@{
          FilePath = $FilePath; ArgumentList = $ArgumentList; ExitCode = 0
          Output = $output; Succeeded = $true
        }
      }

      $repo = Join-Path $TestDrive 'stable'
      New-Item -ItemType Directory -Path $repo -Force | Out-Null
      $result = Test-SprintEndPullOverlap -RepoPath $repo

      $result.Ok | Should -BeFalse
      $result.Overlap | Should -Be @('claude-settings.json')
      $result.LocalPaths | Should -Contain 'local-only.txt'
    }
  }

  Context 'Invoke-SprintEndOverviewClose' {
    BeforeEach {
      Mock Update-OverviewWorkspaceStableInfo {
        [PSCustomObject]@{ errors = @(); wasChanged = $true }
      }
      Mock Remove-OverviewSprintWorkspace {
        [PSCustomObject]@{ WasArchived = $true; SourceRemoved = $true }
      }
    }

    It 'uses the parent overview files and real cmdlet contracts' {
      $planning = Join-Path $TestDrive '_Planning-wt-20-Sprint-0010-work-items'
      New-Item -ItemType Directory -Path $planning -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $TestDrive 'OverviewSprint0010.code-workspace') -Value '{}'

      $result = Invoke-SprintEndOverviewClose `
        -GitRoot $TestDrive -PlanningRoot $planning -SprintNumber 10 -Confirm:$false

      $result.Ok | Should -BeTrue
      $result.SourceWorkspacePath | Should -Be (Join-Path $TestDrive 'OverviewSprint0010.code-workspace')
      Should -Invoke Update-OverviewWorkspaceStableInfo -Times 1 -ParameterFilter {
        $RootWorkspacePath -eq (Join-Path $TestDrive 'Overview.code-workspace') -and
        $SourceWorkspacePath -eq (Join-Path $TestDrive 'OverviewSprint0010.code-workspace')
      }
      Should -Invoke Remove-OverviewSprintWorkspace -Times 1 -ParameterFilter {
        $SprintNumber -eq 10 -and $ArchiveDirectoryPath -like '*SprintRetrospective*WorkspaceArchive'
      }
    }
  }

  Context 'Save-SprintHistoryArtifacts' {
    It 'archives the dotted artifact set and is idempotent' {
      $planning = Join-Path $TestDrive '_Planning-wt-20-Sprint-0010-work-items'
      New-Item -ItemType Directory -Path $planning -Force | Out-Null
      foreach ($name in @(
          'Tasks.Sprint0010.md',
          'Tasks.Sprint0010.html',
          'Tasks.Sprint0010.Accomplished.html',
          'Tasks.Sprint0010.ProceduralDetails.html'
        )) {
        Set-Content -LiteralPath (Join-Path $planning $name) -Value $name
      }

      $first = Save-SprintHistoryArtifacts -PlanningRoot $planning -SprintNumber 10 -Confirm:$false
      $second = Save-SprintHistoryArtifacts -PlanningRoot $planning -SprintNumber 10 -Confirm:$false

      $first.Ok | Should -BeTrue
      $first.Files.Count | Should -Be 4
      @($first.Files | Where-Object Copied).Count | Should -Be 4
      @($second.Files | Where-Object Copied).Count | Should -Be 0
    }
  }

  Context 'Test-SprintEndBoundaryState' {
    It 'reports a prohibited process environment variable without exposing its value' {
      $name = 'TASK106_FAKE_SECRET'
      try {
        [Environment]::SetEnvironmentVariable($name, 'do-not-report', 'Process')
        $result = Test-SprintEndBoundaryState `
          -GitRoot $TestDrive `
          -SearchRoots @() `
          -ProfilePaths @() `
          -ProhibitedEnvironmentVariableNames @($name)

        $result.Ok | Should -BeFalse
        $result.Failures | Should -Contain 'SecretEnvironmentVariables'
        $result.SecretEnvironmentVariables[0].Name | Should -Be $name
        ($result | ConvertTo-Json -Depth 6) | Should -Not -Match 'do-not-report'
      } finally {
        [Environment]::SetEnvironmentVariable($name, $null, 'Process')
      }
    }

    It 'keeps secret-bearing settings out of the process-environment profile' {
      $resolvedModuleRoot = (Resolve-Path -LiteralPath $moduleRoot).Path
      $profileRoot = Join-Path (Split-Path $resolvedModuleRoot -Parent) 'ATAP.Utilities.PowerShell\Profiles'
      $environmentProfile = Get-Content -Raw -LiteralPath (Join-Path $profileRoot 'global_EnvironmentVariables.ps1')
      $userProfile = Get-Content -Raw -LiteralPath (Join-Path $profileRoot 'CurrentUserAllHostsV7CoreProfile.ps1')

      foreach ($secretKey in @(
          'DropboxAccessTokenConfigRootKey',
          'JENKINS_API_TOKENConfigRootKey',
          'BW_APP_PASSWORDConfigRootKey',
          'BW_MASTER_PASSWORDConfigRootKey',
          'VAULT_TOKENConfigRootKey',
          'CHATGPT_API_TOKENConfigRootKey',
          'PERPLEXITY_API_KEYConfigRootKey',
          'HYDRUS_ACCESS_KEYConfigRootKey'
        )) {
        $environmentProfile | Should -Not -Match ([regex]::Escape("['$secretKey']"))
      }
      $userProfile | Should -Match 'ATAP\.Utilities\.PowerShell'
      $userProfile | Should -Match 'Process environment setup was skipped'
    }
  }

  Context 'Invoke-SprintEndInfrastructureCleanup' {
    BeforeEach {
      Mock Test-SprintInfrastructureHealth {
        [PSCustomObject]@{ AllOk = $true; Failures = @() }
      }
      Mock Remove-SprintDatabases {
        @([PSCustomObject]@{ database = 'ATAPUtilities'; dropped = $true })
      }
      Mock Clear-BuildMasterSprintVariables {
        [PSCustomObject]@{ variablesCleared = @('App/SprintNumber'); errors = @() }
      }
      Mock Set-SprintBoundaryContext {
        [PSCustomObject]@{ Errors = @() }
      }
    }

    It 'runs database and BuildMaster cleanup but never secret or instance removal' {
      $result = Invoke-SprintEndInfrastructureCleanup -GitRoot $TestDrive -Apply -Confirm:$false

      $result.Ok | Should -BeTrue
      $result.BitwardenSecretsRemoved | Should -BeFalse
      $result.SqlInstancesRemoved | Should -BeFalse
      Should -Invoke Remove-SprintDatabases -Times 1
      Should -Invoke Clear-BuildMasterSprintVariables -Times 1
    }
  }

  Context 'Invoke-SprintEndGitHubClose' {
    It 'derives the issue from the branch and adds a closing keyword' {
      $script:editCalled = $false
      Mock Invoke-SprintEndNativeCommand {
        $argsText = $ArgumentList -join ' '
        $output = switch -Regex ($argsText) {
          'branch --show-current' { @('48-Sprint-0010-work-items'); break }
          'remote get-url origin' { @('https://github.com/BillHertzing/SharedVSCode.git'); break }
          'issue view 48' { @('{"number":48,"state":"OPEN","title":"Sprint 0010","url":"https://example/48"}'); break }
          'pr list' { @('[{"number":50,"state":"OPEN","title":"Sprint","body":"Summary","url":"https://example/pr/50","mergeable":"MERGEABLE","mergedAt":null}]'); break }
          'pr edit 50' { $script:editCalled = $true; @('ok'); break }
          'pr view 50' { @('{"number":50,"state":"OPEN","mergeable":"MERGEABLE","reviewDecision":"","isDraft":false,"statusCheckRollup":[{"name":"CodeSee Maps","conclusion":"SUCCESS","detailsUrl":"https://example/codesee"}],"url":"https://example/pr/50","headRefOid":"abc123"}'); break }
          'pr checks 50' { @('[]'); break }
          default { @('ok') }
        }
        [PSCustomObject]@{
          FilePath = $FilePath; ArgumentList = $ArgumentList; ExitCode = 0
          Output = $output; Succeeded = $true
        }
      }

      $repo = Join-Path $TestDrive 'SharedVSCode-wt-48-Sprint-0010-work-items'
      New-Item -ItemType Directory -Path $repo -Force | Out-Null
      $result = Invoke-SprintEndGitHubClose -RepoPath $repo -Confirm:$false

      $result.IssueNumber | Should -Be 48
      $result.Repository | Should -Be 'BillHertzing/SharedVSCode'
      $script:editCalled | Should -BeTrue
      $result.Actions | Should -Contain 'Added Closes #48.'
      $result.FinalCommit | Should -Be 'abc123'
      $result.CodeSee[0].Classification | Should -Be 'PlanningSignal'
      $result.PlanningPayload.CodeSeeClassification | Should -Be 'PlanningSignal'
    }
  }

  Context 'Invoke-SprintEndLifecycle' {
    BeforeEach {
      Mock Get-SprintEndContext {
        [PSCustomObject]@{
          Ok = $true; ClosedSprintNumber = '0010'; NextSprintNumber = '0011'; Detail = 'fixture'
        }
      }
      Mock Test-SprintEndCommandSurface { [PSCustomObject]@{ Ok = $true; Failures = @() } }
      Mock Test-SprintPrerequisites { [PSCustomObject]@{ AllOk = $true; Failures = @() } }
      Mock Test-SprintEndWorktreeState { [PSCustomObject]@{ Ok = $true; Failures = @() } }
    }

    It 'returns a non-mutating dry-run contract with safety invariants' {
      $planning = Join-Path $TestDrive '_Planning-wt-20-Sprint-0010-work-items'
      $shared = Join-Path $TestDrive 'SharedVSCode-wt-48-Sprint-0010-work-items'
      New-Item -ItemType Directory -Path $planning, $shared -Force | Out-Null

      $result = Invoke-SprintEndLifecycle `
        -GitRoot $TestDrive `
        -PlanningRoot $planning `
        -SharedVSCodeWorktreePath $shared `
        -WorktreePaths @($planning, $shared) `
        -WhatIf

      $result.Ok | Should -BeTrue
      $result.DryRun | Should -BeTrue
      $result.ClosedSprintNumber | Should -Be '0010'
      $result.NextSprintNumber | Should -Be '0011'
      $result.BitwardenSecretsRemoved | Should -BeFalse
      $result.SqlInstancesRemoved | Should -BeFalse
      $result.SyntheticTaskCompleted | Should -BeFalse
      $result.Phases.FinalBoundary.Skipped | Should -BeTrue
    }
  }
}

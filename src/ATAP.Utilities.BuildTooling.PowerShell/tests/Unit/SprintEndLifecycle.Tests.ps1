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
      'Restore-SprintHistoryArtifacts',
      'Save-SprintEndSessionTail',
      'Test-SprintCheckpointCoverage',
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

  Context 'Restore-SprintHistoryArtifacts' {
    It 'restores explicit historical content and preserves a different existing file' {
      $planning = Join-Path $TestDrive 'history-planning'
      New-Item -ItemType Directory -Path $planning -Force | Out-Null
      git -C $planning init --quiet --initial-branch=main
      git -C $planning config user.email 'test@example.invalid'
      git -C $planning config user.name 'Sprint History Test'
      Set-Content -LiteralPath (Join-Path $planning 'TASKS.md') -Value 'historical board'
      Set-Content -LiteralPath (Join-Path $planning 'Tasks.Accomplished.html') -Value 'historical accomplished'
      Set-Content -LiteralPath (Join-Path $planning 'TASKS_V2.md') -Value 'historical variant'
      git -C $planning add .
      git -C $planning commit --quiet -m seed
      $sourceRef = (git -C $planning rev-parse HEAD).Trim()

      $first = Restore-SprintHistoryArtifacts `
        -PlanningRoot $planning `
        -SprintNumber 9 `
        -SourceRef $sourceRef `
        -SourcePath @('TASKS.md', 'Tasks.Accomplished.html') `
        -NotebookPath 'SprintRetrospective/Sprint0009.ipynb' `
        -Confirm:$false

      $first.Ok | Should -BeTrue
      @($first.Files | Where-Object Status -eq 'Restored').Count | Should -Be 2
      Test-Path -LiteralPath $first.ManifestPath | Should -BeTrue

      $variant = Restore-SprintHistoryArtifacts `
        -PlanningRoot $planning `
        -SprintNumber 9 `
        -SourceRef $sourceRef `
        -SourcePath @('TASKS_V2.md') `
        -NotebookPath 'SprintRetrospective/Sprint0009.ipynb' `
        -Confirm:$false
      $variant.Ok | Should -BeTrue
      $variant.Files[0].Status | Should -Be 'Restored'
      $manifest = Get-Content -Raw -LiteralPath $first.ManifestPath | ConvertFrom-Json
      $manifest.SourcePaths.Count | Should -Be 3

      Set-Content -LiteralPath (Join-Path $first.HistoryRoot 'TASKS.md') -Value 'preserve me'
      $second = Restore-SprintHistoryArtifacts `
        -PlanningRoot $planning `
        -SprintNumber 9 `
        -SourceRef $sourceRef `
        -SourcePath @('TASKS.md') `
        -NotebookPath 'SprintRetrospective/Sprint0009.ipynb' `
        -Confirm:$false

      $second.Ok | Should -BeFalse
      $second.Files[0].Status | Should -Be 'PreservedConflict'
      Get-Content -Raw -LiteralPath (Join-Path $first.HistoryRoot 'TASKS.md') |
        Should -Match 'preserve me'
    }
  }

  Context 'Test-SprintCheckpointCoverage' {
    It 'discovers a final checkpoint using canonical Planning paths only' {
      $planning = Join-Path $TestDrive 'checkpoint-planning'
      $conversationRoot = Join-Path $planning 'SprintWorkSessionConversations'
      $rosterRoot = Join-Path $planning 'SprintWorkSessionRoster'
      $worktree = Join-Path $TestDrive 'SharedVSCode-wt-48-Sprint-0010-work-items'
      New-Item -ItemType Directory -Path $conversationRoot, $rosterRoot, $worktree -Force | Out-Null
      $archive = Join-Path $conversationRoot 'checkpoint.7z'
      Set-Content -LiteralPath $archive -Value 'reachable archive'
      $entry = [ordered]@{
        SprintN = '0010'
        RecordedAt = '2026-06-20T17:00:00-06:00'
        Agent = 'Codex'
        WorktreeName = Split-Path -Path $worktree -Leaf
        ConversationArchivePath = $archive
        MemorySnapshotCreated = $false
        MemorySkipReason = 'Agent has no on-disk memory store.'
      }
      $entry | ConvertTo-Json -Compress |
        Set-Content -LiteralPath (Join-Path $rosterRoot 'SprintWorkSessionRoster-0010.jsonl')

      $result = Test-SprintCheckpointCoverage `
        -PlanningRoot $planning -SprintNumber 10 -WorktreePaths @($worktree)

      $result.Ok | Should -BeTrue
      $result.PerWorktree[0].Agent | Should -Be 'Codex'
      $result.PerWorktree[0].ConversationArchiveReachable | Should -BeTrue
      $result.PerWorktree[0].MemoryState | Should -Be 'AgentHasNoMemorySnapshot'
      ($result | ConvertTo-Json -Depth 6) | Should -Not -Match '\\.codex|\\.claude|\\.gemini'
    }
  }

  Context 'Save-SprintEndSessionTail' {
    It 'stages only canonical checkpoint directories and records the stable commit' {
      $planning = Join-Path $TestDrive 'stable-planning'
      New-Item -ItemType Directory -Path $planning -Force | Out-Null
      $script:tailNativeCalls = [System.Collections.Generic.List[string]]::new()
      Mock Save-SprintWorkSession {}
      Mock Invoke-SprintEndNativeCommand {
        $argsText = $ArgumentList -join ' '
        [void]$script:tailNativeCalls.Add($argsText)
        $output = switch -Regex ($argsText) {
          'branch --show-current' { @('main'); break }
          'status --porcelain' { @('?? SprintWorkSessionRoster/entry.jsonl'); break }
          'rev-parse HEAD' { @('abc123'); break }
          default { @('ok') }
        }
        [PSCustomObject]@{
          FilePath = $FilePath
          ArgumentList = $ArgumentList
          ExitCode = 0
          Output = $output
          Succeeded = $true
        }
      }

      $result = Save-SprintEndSessionTail `
        -PlanningRoot $planning `
        -SprintNumber 10 `
        -Agent Codex `
        -SessionId 'session-id' `
        -Confirm:$false

      $result.Ok | Should -BeTrue
      $result.Committed | Should -BeTrue
      $result.CommitHash | Should -Be 'abc123'
      $result.Pushed | Should -BeFalse
      Should -Invoke Save-SprintWorkSession -Times 1 -ParameterFilter {
        $Agent -eq 'Codex' -and
        $SprintN -eq '0010' -and
        $PlanningRoot -eq $planning -and
        $AllowMainFallback
      }
      ($script:tailNativeCalls -join "`n") |
        Should -Match 'add -- SprintWorkSessionConversations SprintWorkSessionMemorys SprintWorkSessionRoster'
      ($script:tailNativeCalls -join "`n") | Should -Not -Match 'push'
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
      $result.DatabaseCleanupMode | Should -Be 'SprintDatabasesOnly'
      $result.SqlInstancesRetained | Should -BeTrue
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
      Mock Test-SprintCheckpointCoverage { [PSCustomObject]@{ Ok = $true; Failures = @() } }
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
      $result.DatabaseCleanupMode | Should -Be 'SprintDatabasesOnly'
      $result.SqlInstancesRetained | Should -BeTrue
      $result.SyntheticTaskCompleted | Should -BeFalse
      $result.Phases.FinalBoundary.Skipped | Should -BeTrue
    }

    It 'plans every selected mutation phase in a full-switch WhatIf run' {
      $planning = Join-Path $TestDrive '_Planning-wt-20-Sprint-0010-work-items-full'
      $shared = Join-Path $TestDrive 'SharedVSCode-wt-48-Sprint-0010-work-items-full'
      New-Item -ItemType Directory -Path $planning, $shared -Force | Out-Null
      Mock Set-SprintBoundaryContext { [PSCustomObject]@{ Errors = @() } }
      Mock Assert-MainBranchTemplateRef { [PSCustomObject]@{ Ok = $true } }
      Mock Invoke-SprintEndGitHubClose {
        [PSCustomObject]@{ Ok = $true; Repository = (Split-Path -Path $RepoPath -Leaf) }
      }
      Mock Save-SprintHistoryArtifacts { [PSCustomObject]@{ Ok = $true; Files = @() } }
      Mock Invoke-SprintEndOverviewClose { [PSCustomObject]@{ Ok = $true } }
      Mock New-SprintEndHandoff { [PSCustomObject]@{ Changed = $false; Planned = $true } }
      Mock Invoke-SprintEndInfrastructureCleanup {
        [PSCustomObject]@{
          Ok = $true
          DatabaseCleanupMode = 'SprintDatabasesOnly'
          SqlInstancesRetained = $true
        }
      }

      $result = Invoke-SprintEndLifecycle `
        -GitRoot $TestDrive `
        -PlanningRoot $planning `
        -SharedVSCodeWorktreePath $shared `
        -WorktreePaths @($planning, $shared) `
        -ApplyBoundary `
        -CreatePullRequests `
        -MergePullRequests `
        -ArchiveHistory `
        -VerifyCheckpoints `
        -CloseOverview `
        -WriteHandoff `
        -CleanupInfrastructure `
        -TestFreshShell `
        -WhatIf

      $result.Ok | Should -BeTrue
      $result.DryRun | Should -BeTrue
      $result.Phases.CheckpointCoverage.Ok | Should -BeTrue
      $result.Phases.BoundaryReset.Errors | Should -BeNullOrEmpty
      $result.Phases.GitHub.Count | Should -Be 2
      $result.Phases.History.Ok | Should -BeTrue
      $result.Phases.Overview.Ok | Should -BeTrue
      $result.Phases.Handoff.Planned | Should -BeTrue
      $result.Phases.InfrastructureCleanup.SqlInstancesRetained | Should -BeTrue
      $result.Phases.FinalBoundary.Planned | Should -BeTrue
      $result.Phases.FinalBoundary.TestFreshShell | Should -BeTrue
    }
  }
}

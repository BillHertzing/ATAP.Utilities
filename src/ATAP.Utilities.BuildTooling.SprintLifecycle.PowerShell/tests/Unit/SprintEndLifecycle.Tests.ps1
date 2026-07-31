#Requires -Version 7.0

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  . (Join-Path $moduleRoot 'private\Invoke-SprintEndNativeCommand.ps1')
  # Load the complete child-module public surface. A partial hand-maintained list
  # let commands already present in an interactive developer session mask missing
  # mock targets; the clean BuildMaster process correctly rejected those mocks.
  foreach ($publicFunction in Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'public') -Filter '*.ps1' -File) {
    . $publicFunction.FullName
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

    It 'requires the profiled-remoting policy on the boundary command' {
      $result = Test-SprintEndCommandSurface -CommandContracts @{
        'Set-SprintBoundaryContext' = @('ProfiledRemotingPolicy')
      }

      $result.Ok | Should -BeTrue
      $result.Commands[0].MissingParameters | Should -BeNullOrEmpty
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
    It 'writes an idempotent sprint-specific handoff without secret or instance deletion' {
      $gitRoot = Join-Path $TestDrive 'gitroot'
      $worktree = Join-Path $gitRoot 'App-wt-42-Sprint-0010-work-items'
      New-Item -ItemType Directory -Path $worktree -Force | Out-Null
      $output = Join-Path $gitRoot 'HANDOFF.Sprint0010.md'

      $first = New-SprintEndHandoff -GitRoot $gitRoot -WorktreePaths @($worktree) -Confirm:$false
      $second = New-SprintEndHandoff -GitRoot $gitRoot -WorktreePaths @($worktree) -Confirm:$false
      $text = Get-Content -Raw -LiteralPath $output
      $code = [regex]::Match($text, '(?s)```powershell\s*(.*?)\s*```').Groups[1].Value
      $tokens = $null
      $errors = $null
      [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$tokens, [ref]$errors) | Out-Null

      $first.Changed | Should -BeTrue
      $second.Changed | Should -BeFalse
      $first.Path | Should -Be $output
      $first.SprintNumber | Should -Be '0010'
      $errors | Should -BeNullOrEmpty
      $text | Should -Match 'Remove-SprintWorktreeSafely'
      $text | Should -Not -Match 'git -C .* worktree remove'
      $text | Should -Match 'pull --ff-only'
      $text | Should -Match 'Test-SprintEndPullOverlap'
      $text | Should -Match 'branch -D'
      $text | Should -Match 'Remove-SprintDatabases'
      $text | Should -Match 'Set-SprintBoundaryContext @boundaryParams'
      $text | Should -Match "ProfiledRemotingPolicy = 'Auto'"
      $text | Should -Match 'Test-SprintEndBoundaryState @boundaryTestParams'
      $text | Should -Not -Match 'Remove-SprintBitwardenSecrets'
      $text | Should -Not -Match 'Remove-DeveloperSqlServerInstances'
      $text | Should -Match 'Remove-Item @handoffRemovalParams'
      $text | Should -Match ([regex]::Escape("LiteralPath = '$output'"))
    }

    It 'carries the actual sprint WorktreePaths into the boundary reset call, BEFORE any worktree is removed (CP06-D01/D02, Task 13.20.a)' {
      # Regression for the Sprint 0012 close incident (CP06-D01): the generated
      # handoff previously omitted -WorktreePaths from the embedded
      # Set-SprintBoundaryContext call, so the resumed command had nothing to
      # retarget. It must now carry the exact worktree list this function was
      # called with, and the reset must happen before worktree removal so the
      # sprint worktrees still exist on disk when it runs.
      $gitRoot = Join-Path $TestDrive 'gitroot-worktreepaths'
      $worktreeOne = Join-Path $gitRoot 'App-wt-42-Sprint-0011-work-items'
      $worktreeTwo = Join-Path $gitRoot 'Other-wt-43-Sprint-0011-work-items'
      New-Item -ItemType Directory -Path $worktreeOne, $worktreeTwo -Force | Out-Null
      $output = Join-Path $gitRoot 'HANDOFF.Sprint0011.md'

      $result = New-SprintEndHandoff -GitRoot $gitRoot -WorktreePaths @($worktreeOne, $worktreeTwo) -Confirm:$false
      $text = Get-Content -Raw -LiteralPath $output
      $code = [regex]::Match($text, '(?s)```powershell\s*(.*?)\s*```').Groups[1].Value
      $tokens = $null
      $parseErrors = $null
      [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$tokens, [ref]$parseErrors) | Out-Null

      $result.Changed | Should -BeTrue
      $parseErrors | Should -BeNullOrEmpty

      # Both worktree paths must appear as literal entries inside the embedded
      # $boundaryParams.WorktreePaths array -- never omitted, never rediscovered
      # by a disk rescan.
      $text | Should -Match ([regex]::Escape("'$worktreeOne'"))
      $text | Should -Match ([regex]::Escape("'$worktreeTwo'"))
      $text | Should -Match 'WorktreePaths\s*=\s*@\('
      $text | Should -Match '\$boundaryResetResult = Set-SprintBoundaryContext @boundaryParams'
      $text | Should -Match 'if \(@\(\$boundaryResetResult\.Errors\)\.Count -gt 0\)'

      # Ordering: the boundary reset block must appear in the script BEFORE the
      # first safe teardown command.
      $boundaryResetIndex = $code.IndexOf('Set-SprintBoundaryContext @boundaryParams')
      $firstRemoveIndex = $code.IndexOf('Remove-SprintWorktreeSafely')
      $boundaryResetIndex | Should -BeGreaterThan -1
      $firstRemoveIndex | Should -BeGreaterThan -1
      $boundaryResetIndex | Should -BeLessThan $firstRemoveIndex
    }

    It 'requires WorktreePaths and rejects an omitted/empty list rather than silently generating a handoff with nothing to retarget (CP06-D01, Task 13.20.a)' {
      $gitRoot = Join-Path $TestDrive 'gitroot-omitted-worktreepaths'
      New-Item -ItemType Directory -Path $gitRoot -Force | Out-Null

      $worktreeParameter = (Get-Command New-SprintEndHandoff).Parameters['WorktreePaths']
      $parameterAttributes = @($worktreeParameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] })
      @($parameterAttributes | Where-Object Mandatory).Count | Should -Be 0

      { New-SprintEndHandoff -GitRoot $gitRoot -Confirm:$false } | Should -Throw '*requires at least one WorktreePaths entry*'
      { New-SprintEndHandoff -GitRoot $gitRoot -WorktreePaths @() -Confirm:$false } | Should -Throw '*requires at least one WorktreePaths entry*'
      { New-SprintEndHandoff -GitRoot $gitRoot -WorktreePaths @('') -Confirm:$false } | Should -Throw '*must not be null, empty, or whitespace*'
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
      Set-Content -LiteralPath (Join-Path $TestDrive 'Overview.Sprint0010.code-workspace') -Value '{}'

      $result = Invoke-SprintEndOverviewClose `
        -GitRoot $TestDrive -PlanningRoot $planning -SprintNumber 10 -Confirm:$false

      $result.Ok | Should -BeTrue
      $result.SourceWorkspacePath | Should -Be (Join-Path $TestDrive 'Overview.Sprint0010.code-workspace')
      Should -Invoke Update-OverviewWorkspaceStableInfo -Times 1 -ParameterFilter {
        $RootWorkspacePath -eq (Join-Path $TestDrive 'Overview.code-workspace') -and
        $SourceWorkspacePath -eq (Join-Path $TestDrive 'Overview.Sprint0010.code-workspace')
      }
      Should -Invoke Remove-OverviewSprintWorkspace -Times 1 -ParameterFilter {
        $SprintNumber -eq 10 -and $ArchiveDirectoryPath -like '*SprintRetrospective*WorkspaceArchive'
      }
    }

    It 'prefers the exact closing sprint workspace and ignores stale older overview artifacts' {
      $planning = Join-Path $TestDrive '_Planning-wt-52-Sprint-0011-work-items'
      New-Item -ItemType Directory -Path $planning -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $TestDrive 'Overview.Sprint0011.code-workspace') -Value '{}'
      Set-Content -LiteralPath (Join-Path $TestDrive 'OverviewSprint0008.code-workspace') -Value '{}'

      $result = Invoke-SprintEndOverviewClose `
        -GitRoot $TestDrive -PlanningRoot $planning -SprintNumber 11 -Confirm:$false

      $result.SourceWorkspacePath | Should -Be (Join-Path $TestDrive 'Overview.Sprint0011.code-workspace')
      Should -Invoke Update-OverviewWorkspaceStableInfo -Times 1 -ParameterFilter {
        $SourceWorkspacePath -eq (Join-Path $TestDrive 'Overview.Sprint0011.code-workspace')
      }
      Should -Invoke Remove-OverviewSprintWorkspace -Times 1 -ParameterFilter {
        $SourceWorkspacePath -eq (Join-Path $TestDrive 'Overview.Sprint0011.code-workspace')
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
      $utilitiesRepoRoot = Split-Path (Split-Path $resolvedModuleRoot -Parent) -Parent
      $githubRoot = Split-Path $utilitiesRepoRoot -Parent
      $sprintMatch = [regex]::Match((Split-Path $utilitiesRepoRoot -Leaf), 'Sprint-(?<Sprint>\d{4})')
      $iacRoot = if ($sprintMatch.Success) {
        Get-ChildItem -LiteralPath $githubRoot -Directory |
          Where-Object { $_.Name -match "^ATAP\.IAC-wt-\d+-Sprint-$($sprintMatch.Groups['Sprint'].Value)-work-items$" } |
          Select-Object -ExpandProperty FullName -First 1
      } else {
        Join-Path $githubRoot 'ATAP.IAC'
      }
      if (-not $iacRoot) {
        throw "Could not locate the Sprint $($sprintMatch.Groups['Sprint'].Value) ATAP.IAC worktree."
      }
      $userProfile = Get-Content -Raw -LiteralPath (Join-Path $iacRoot 'Windows\ProfileTemplates\CurrentUserAllHostsV7CoreProfile.ps1')

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

    It 'verifies managed developer and service-account profiles when ProfilePaths is not supplied' {
      $gitRoot = Join-Path $TestDrive 'gitroot-managed-profiles'
      $utilRoot = Join-Path $gitRoot 'ATAP.Utilities'
      $iacRoot = Join-Path $gitRoot 'ATAP.IAC'
      $developerHome = Join-Path $TestDrive 'alice-home'
      $serviceHome = Join-Path $TestDrive 'svc-home'
      $developerSource = Join-Path $iacRoot 'Windows\ProfileTemplates\CurrentUserAllHostsV7CoreProfile.ps1'
      $serviceSource = Join-Path $iacRoot 'Windows\ProfileTemplates\ProfileForServiceAccountUsers.ps1'
      $developerProfile = Join-Path $developerHome 'Documents\PowerShell\profile.ps1'
      $serviceProfile = Join-Path $serviceHome 'Documents\PowerShell\profile.ps1'
      New-Item -ItemType Directory -Path (Split-Path $developerSource -Parent), (Split-Path $developerProfile -Parent), (Split-Path $serviceProfile -Parent) -Force | Out-Null
      Set-Content -LiteralPath $developerSource -Value '# developer stable profile' -Encoding UTF8
      Set-Content -LiteralPath $serviceSource -Value '# service stable profile' -Encoding UTF8
      try {
        # Symbolic-link creation needs elevation or Developer Mode; restricted
        # accounts (e.g. SvcBuildmaster) cannot do it (Task 12.46 / exec 17480).
        New-Item -ItemType SymbolicLink -Path $developerProfile -Target $developerSource -Force -ErrorAction Stop | Out-Null
        New-Item -ItemType SymbolicLink -Path $serviceProfile -Target $serviceSource -Force -ErrorAction Stop | Out-Null
      } catch {
        Set-ItResult -Skipped -Because "symbolic-link creation is unavailable for this account: $($_.Exception.Message)"
        return
      }

      Mock Set-SprintBoundaryUserProfiles {
        [PSCustomObject]@{
          Ok = $true
          Profiles = @(
            [PSCustomObject]@{
              Kind = 'Developer'; Identity = 'alice'; ProfilePath = $developerProfile; SourcePath = $developerSource; Skipped = $false; Warning = $null
            },
            [PSCustomObject]@{
              Kind = 'ServiceAccount'; Identity = 'SvcBuildmaster'; ProfilePath = $serviceProfile; SourcePath = $serviceSource; Skipped = $false; Warning = $null
            }
          )
          Warnings = @()
          Failures = @()
        }
      }

      $result = Test-SprintEndBoundaryState `
        -GitRoot $gitRoot `
        -SearchRoots @() `
        -ATAPUtilitiesRoot $utilRoot `
        -ATAPIACRoot $iacRoot `
        -ProhibitedEnvironmentVariableNames @()

      $result.Ok | Should -BeTrue
      @($result.Profiles | Where-Object Kind -NE 'General').Count | Should -Be 2
      $result.ManagedProfileFailures | Should -BeNullOrEmpty
      Test-Path -LiteralPath (Join-Path $utilRoot 'src\ATAP.Utilities.PowerShell\Profiles') |
        Should -BeFalse
    }
  }

  Context 'Invoke-SprintEndInfrastructureCleanup' {
    BeforeEach {
      # SC-0288 / Task 13.66.b: the cleanup cmdlet's BuildMaster admin SecretName
      # is host-suffixed from the placement map and fails closed when placement
      # is unknown, so this context must declare placement.
      $script:oldConfigRootKeys = $global:configRootKeys
      $script:oldSettings = $global:Settings
      $global:configRootKeys = @{ ServicePlacementMapConfigRootKey = 'ServicePlacementMap' }
      $global:Settings = @{ ServicePlacementMap = @{ BuildMaster = 'utat022'; ProGet = 'utat022' } }

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

    AfterEach {
      $global:configRootKeys = $script:oldConfigRootKeys
      $global:Settings = $script:oldSettings
    }

    It 'runs database and BuildMaster cleanup but never secret or instance removal' {
      $result = Invoke-SprintEndInfrastructureCleanup -GitRoot $TestDrive -Apply -ProfiledRemotingPolicy Disabled -Confirm:$false

      $result.Ok | Should -BeTrue
      $result.BitwardenSecretsRemoved | Should -BeFalse
      $result.DatabaseCleanupMode | Should -Be 'SprintDatabasesOnly'
      $result.SqlInstancesRetained | Should -BeTrue
      Should -Invoke Remove-SprintDatabases -Times 1
      Should -Invoke Clear-BuildMasterSprintVariables -Times 1
      Should -Invoke Set-SprintBoundaryContext -Times 1 -ParameterFilter { $ProfiledRemotingPolicy -eq 'Disabled' }
    }

    It 'keeps ambient WhatIf out of read-only health and reports cleanup as planned' {
      $script:healthWhatIfPreference = $null
      $script:healthProcessBwsAccessToken = $null
      $priorProcessBwsAccessToken = [Environment]::GetEnvironmentVariable('BWS_ACCESS_TOKEN', 'Process')
      [Environment]::SetEnvironmentVariable('BWS_ACCESS_TOKEN', 'fixture-process-token', 'Process')
      Mock Test-SprintInfrastructureHealth {
        $script:healthWhatIfPreference = [bool]$WhatIfPreference
        $script:healthProcessBwsAccessToken = [Environment]::GetEnvironmentVariable('BWS_ACCESS_TOKEN', 'Process')
        [PSCustomObject]@{ AllOk = $true; Failures = @() }
      }

      try {
        $result = Invoke-SprintEndInfrastructureCleanup -GitRoot $TestDrive -Apply -WhatIf -Confirm:$false

        $script:healthWhatIfPreference | Should -BeFalse
        $script:healthProcessBwsAccessToken | Should -BeNullOrEmpty
        [Environment]::GetEnvironmentVariable('BWS_ACCESS_TOKEN', 'Process') | Should -Be 'fixture-process-token'
        $result.Ok | Should -BeTrue
        $result.Applied | Should -BeFalse
        $result.Planned | Should -BeTrue
        Should -Invoke Remove-SprintDatabases -Times 0
        Should -Invoke Clear-BuildMasterSprintVariables -Times 0
        Should -Invoke Set-SprintBoundaryContext -Times 0
      } finally {
        [Environment]::SetEnvironmentVariable('BWS_ACCESS_TOKEN', $priorProcessBwsAccessToken, 'Process')
      }
    }
  }

  Context 'Invoke-SprintEndGitHubClose' {
    It 'derives the issue from the branch and adds a closing keyword' {
      $script:editCalled = $false
      Mock Invoke-SprintEndNativeCommand {
        $argsText = $ArgumentList -join ' '
        $output = switch -Regex ($argsText) {
          '^api -i rate_limit$' { @('HTTP/1.1 200 OK', 'X-OAuth-Scopes: repo, read:org', '', '{}'); break }
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

    It 'derives a repository whose name contains dots from origin' {
      Mock Invoke-SprintEndNativeCommand {
        $argsText = $ArgumentList -join ' '
        $output = switch -Regex ($argsText) {
          '^api -i rate_limit$' { @('HTTP/1.1 200 OK', 'X-OAuth-Scopes: repo, read:discussion', '', '{}'); break }
          'branch --show-current' { @('11-Sprint-0010-work-items'); break }
          'remote get-url origin' { @('https://github.com/BillHertzing/ATAP.IAC.git'); break }
          'issue view 11' { @('{"number":11,"state":"OPEN","title":"Sprint 0010","url":"https://example/11"}'); break }
          'pr list' { @('[]'); break }
          default { @('ok') }
        }
        [PSCustomObject]@{
          FilePath = $FilePath; ArgumentList = $ArgumentList; ExitCode = 0
          Output = $output; Succeeded = $true
        }
      }

      $repo = Join-Path $TestDrive 'ATAP.IAC-wt-11-Sprint-0010-work-items'
      New-Item -ItemType Directory -Path $repo -Force | Out-Null
      $result = Invoke-SprintEndGitHubClose -RepoPath $repo -Confirm:$false

      $result.Repository | Should -Be 'BillHertzing/ATAP.IAC'
      $result.IssueNumber | Should -Be 11
    }

    It 'fails early with remediation when the gh token lacks the supplemental GraphQL scopes' {
      Mock Invoke-SprintEndNativeCommand {
        $argsText = $ArgumentList -join ' '
        $output = switch -Regex ($argsText) {
          'branch --show-current' { @('11-Sprint-0011-work-items'); break }
          'remote get-url origin' { @('https://github.com/BillHertzing/SharedVSCode.git'); break }
          '^api -i rate_limit$' { @('HTTP/1.1 200 OK', 'X-OAuth-Scopes: repo', '', '{}'); break }
          default { @('ok'); break }
        }
        [PSCustomObject]@{
          FilePath = $FilePath; ArgumentList = $ArgumentList; ExitCode = 0
          Output = $output; Succeeded = $true
        }
      }

      $repo = Join-Path $TestDrive 'SharedVSCode-wt-11-Sprint-0011-work-items'
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      {
        Invoke-SprintEndGitHubClose -RepoPath $repo -Confirm:$false
      } | Should -Throw '*read:org*read:discussion*'
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
      New-Item -ItemType Directory -Path (Join-Path $planning 'SprintRetrospective') -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $planning 'SprintRetrospective\Notebook-SprintWorkSession-0010-End.md') -Value '# Sprint 0010 End'

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
      $result.Phases.ClosePlan.WorktreePath | Should -Contain $planning
      $result.Phases.FinalBoundary.Skipped | Should -BeTrue
    }

    It 'plans every selected mutation phase in a full-switch WhatIf run' {
      $planning = Join-Path $TestDrive '_Planning-wt-20-Sprint-0010-work-items-full'
      $shared = Join-Path $TestDrive 'SharedVSCode-wt-48-Sprint-0010-work-items-full'
      New-Item -ItemType Directory -Path $planning, $shared -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $planning 'SprintRetrospective') -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $planning 'SprintRetrospective\Notebook-SprintWorkSession-0010-End.md') -Value '# Sprint 0010 End'
      foreach ($workspaceRoot in @($planning, $shared)) {
        @{
          folders = @(@{ path = '.' })
          settings = @{ 'atap.sharedVSCode.templateRef' = 'SharedVSCode-wt-48-Sprint-0010-work-items' }
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $workspaceRoot 'Fixture.code-workspace') -Encoding UTF8
      }
      Mock Set-SprintBoundaryContext { [PSCustomObject]@{ Errors = @() } }
      Mock Assert-MainBranchTemplateRef -ParameterFilter { $WhatIf } {
        [PSCustomObject]@{
          Ok = $false
          WhatIf = $true
          WouldThrow = $true
          Violations = @('fixture still points to a sprint ref before the planned boundary reset')
        }
      }
      Mock Assert-MainBranchTemplateRef -ParameterFilter { -not $WhatIf } {
        throw 'TemplateRef assertion was invoked live during a WhatIf lifecycle run.'
      }
      Mock Invoke-SprintEndGitHubClose {
        [PSCustomObject]@{
          Ok = $false
          Repository = (Split-Path -Path $RepoPath -Leaf)
          PullRequest = $null
          Actions = @('Would create draft PR.')
        }
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
        -ProfiledRemotingPolicy Disabled `
        -TestFreshShell `
        -WhatIf

      $result.Ok | Should -BeTrue
      $result.DryRun | Should -BeTrue
      $result.Phases.CheckpointCoverage.Ok | Should -BeTrue
      $result.Phases.BoundaryReset.Errors | Should -BeNullOrEmpty
      $result.Phases.TemplateRef.Count | Should -Be 2
      $result.Phases.TemplateRef.PlannedAfterBoundary | Should -Not -Contain $false
      $result.Phases.TemplateRef.CurrentStateWouldThrow | Should -Not -Contain $false
      $result.Phases.GitHub.Count | Should -Be 2
      $result.Phases.GitHub.PlannedAfterDryRun | Should -Not -Contain $false
      $result.Phases.GitHub.CurrentStateOk | Should -Not -Contain $true
      $result.Phases.GitHub.Actions | Should -Contain 'Would create draft PR.'
      $result.Phases.History.Ok | Should -BeTrue
      $result.Phases.Overview.Ok | Should -BeTrue
      $result.Phases.Handoff.Planned | Should -BeTrue
      $result.Phases.InfrastructureCleanup.SqlInstancesRetained | Should -BeTrue
      $result.Phases.FinalBoundary.Planned | Should -BeTrue
      $result.Phases.FinalBoundary.TestFreshShell | Should -BeTrue
      Should -Invoke Set-SprintBoundaryContext -Times 1 -ParameterFilter { $ProfiledRemotingPolicy -eq 'Disabled' }
      Should -Invoke New-SprintEndHandoff -Times 1 -ParameterFilter { $ProfiledRemotingPolicy -eq 'Disabled' }
      Should -Invoke Invoke-SprintEndInfrastructureCleanup -Times 1 -ParameterFilter { $ProfiledRemotingPolicy -eq 'Disabled' }
    }

    It 'adds the Planning worktree to the SprintEnd close plan when omitted by the caller' {
      $planning = Join-Path $TestDrive '_Planning-wt-20-Sprint-0010-work-items-omitted'
      $shared = Join-Path $TestDrive 'SharedVSCode-wt-48-Sprint-0010-work-items-omitted'
      New-Item -ItemType Directory -Path $planning, $shared -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $planning 'SprintRetrospective') -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $planning 'SprintRetrospective\Notebook-SprintWorkSession-0010-End.md') -Value '# Sprint 0010 End'
      Mock Invoke-SprintEndGitHubClose {
        [PSCustomObject]@{ Ok = $true; Repository = (Split-Path -Path $RepoPath -Leaf) }
      }
      Mock New-SprintEndHandoff {
        [PSCustomObject]@{
          Changed = $false
          Planned = $true
          Path = Join-Path $GitRoot 'HANDOFF.Sprint0010.md'
          WorktreePaths = $WorktreePaths
        }
      }

      $result = Invoke-SprintEndLifecycle `
        -GitRoot $TestDrive `
        -PlanningRoot $planning `
        -SharedVSCodeWorktreePath $shared `
        -WorktreePaths @($shared) `
        -CreatePullRequests `
        -MergePullRequests `
        -WriteHandoff `
        -WhatIf

      $result.Ok | Should -BeTrue
      $planningPlan = @($result.Phases.ClosePlan | Where-Object IsPlanningWorktree)
      $planningPlan.Count | Should -Be 1
      $planningPlan[0].PullRequestClosePlanned | Should -BeTrue
      $planningPlan[0].PullRequestMergePlanned | Should -BeTrue
      $planningPlan[0].BranchDeletePlanned | Should -BeTrue
      $planningPlan[0].WorktreeRemovalPlanned | Should -BeTrue
      $result.Phases.GitHub.Count | Should -Be 2
      $result.Phases.Handoff.WorktreePaths | Should -Contain $planning
    }

    It 'keeps a partial close resumable through generated safe teardown and idempotent re-entry' {
      $planning = Join-Path $TestDrive '_Planning-wt-20-Sprint-0010-work-items-recovery'
      $shared = Join-Path $TestDrive 'SharedVSCode-wt-48-Sprint-0010-work-items-recovery'
      New-Item -ItemType Directory -Path $planning, $shared -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $planning 'SprintRetrospective') -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $planning 'SprintRetrospective\Notebook-SprintWorkSession-0010-End.md') -Value '# Sprint 0010 End'

      # First live pass simulates a crash after the boundary reset but before handoff completion.
      Mock Set-SprintBoundaryContext { [PSCustomObject]@{ Errors = @() } }
      Mock Set-SprintBoundaryUserProfiles {
        [PSCustomObject]@{ Ok = $true; Profiles = @(); Warnings = @(); Failures = @() }
      }
      Mock Invoke-SprintEndInfrastructureCleanup {
        [PSCustomObject]@{ Ok = $true; DatabaseCleanupMode = 'SprintDatabasesOnly'; SqlInstancesRetained = $true }
      }
      Mock New-SprintEndHandoff { throw 'simulated process crash during handoff write' }

      $partial = Invoke-SprintEndLifecycle `
        -GitRoot $TestDrive -PlanningRoot $planning -SharedVSCodeWorktreePath $shared `
        -WorktreePaths @($planning, $shared) -ApplyBoundary -WriteHandoff -CleanupInfrastructure

      $partial.Ok | Should -BeFalse
      $partial.Phases.BoundaryReset.Errors | Should -BeNullOrEmpty
      $partial.Phases.InfrastructureCleanup | Should -BeNullOrEmpty

      # Resume uses the same inputs and only mocked destructive integrations.
      $handoffPath = Join-Path $TestDrive 'HANDOFF.Sprint0010.md'
      Mock New-SprintEndHandoff {
        [PSCustomObject]@{
          Changed = $true; Planned = $false; Path = $handoffPath
          WorktreePaths = $WorktreePaths
        }
      }
      Mock Test-SprintEndBoundaryState { [PSCustomObject]@{ Ok = $true; Failures = @() } }

      $resumed = Invoke-SprintEndLifecycle `
        -GitRoot $TestDrive -PlanningRoot $planning -SharedVSCodeWorktreePath $shared `
        -WorktreePaths @($shared) -ApplyBoundary -WriteHandoff -CleanupInfrastructure

      $resumed.Ok | Should -BeTrue
      $resumed.Phases.ClosePlan.WorktreePath | Should -Contain $planning
      $resumed.Phases.Handoff.WorktreePaths | Should -Contain $planning
      Should -Invoke Set-SprintBoundaryContext -Times 2
      Should -Invoke Invoke-SprintEndInfrastructureCleanup -Times 1
      Should -Invoke New-SprintEndHandoff -Times 2

      # The physical-teardown recipe is generated, bounded, and self-deletes only last.
      $handoffSource = Get-Content -Raw -LiteralPath (Join-Path $moduleRoot 'public\New-SprintEndHandoff.ps1')
      $handoffSource | Should -Match 'Remove-SprintWorktreeSafely'
      $handoffSource | Should -Not -Match 'worktree remove.*--force'
      $handoffSource | Should -Match 'pull --ff-only origin main'
      $handoffSource | Should -Match 'Remove-SprintDatabases'
      $handoffSource | Should -Match 'Set-SprintBoundaryContext'
      $handoffSource | Should -Match 'Remove-Item @handoffRemovalParams'
    }
  }
}

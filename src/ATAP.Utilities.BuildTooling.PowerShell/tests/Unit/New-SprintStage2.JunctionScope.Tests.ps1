# SC-0236 regression: Set-WorktreeJunctions' junction SOURCE SCAN must be filtered
# by -SourceRepoFolderNames at Start, not just the dev-redirect via
# -DevSourceRepoFolderNames. Without it, any junction physically present in a
# downstream stable repo (e.g. a stale .claude/.github junction) would be
# recreated unfiltered in the new sprint worktree. Also guards against the
# stale @('.claude', '.github', '.vscode') JunctionFolderNames default regressing.
# See _generated/Task-12.2-investigation-findings.md.
BeforeAll {
  Remove-Module 'ATAP.Utilities.BuildTooling.PowerShell' -Force -ErrorAction SilentlyContinue
  $script:priorModuleAutoLoad = $global:PSModuleAutoLoadingPreference
  $global:PSModuleAutoLoadingPreference = 'None'

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  $script:stubbedFunctionNames = @(
    'Assert-GitAvailable',
    'Confirm-WorktreeGitPointerOwnership',
    'gh',
    'git',
    'Set-WorktreeJunctions',
    'Initialize-DownstreamSprintFromSharedVSCode',
    'Invoke-SprintAIAdapterLifecycle',
    'Set-ClaudeSettingsSymlink',
    'Set-UserSettingsSymlink',
    'Get-SprintTaskRepositoryNames',
    'Initialize-ATAPConfigurationGlobals',
    'Set-BuildMasterSprintVariables',
    'Reset-SprintDatabases',
    'New-OverviewSprintWorkspace',
    'Build-AIInstructionsPerRepository'
  )

  function global:Assert-GitAvailable { }
  function global:Confirm-WorktreeGitPointerOwnership {
    [PSCustomObject]@{ Verified = $true; Repaired = $false }
  }

  function global:gh {
    $global:LASTEXITCODE = 0
    'https://github.com/owner/ATAP.Utilities/issues/321'
  }

  function global:git {
    $addIndex = [Array]::IndexOf($args, 'add')
    if ($addIndex -ge 0 -and $args.Count -gt ($addIndex + 1)) {
      $worktreePath = $args[$addIndex + 1]
      New-Item -ItemType Directory -Path $worktreePath -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $worktreePath '.git') `
        -Value 'gitdir: C:\fixture\worktrees\test' -NoNewline
    }
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
    $global:stage2JunctionCalls.Add([PSCustomObject]@{
        SourceRepoFolderNames = $SourceRepoFolderNames
      }) | Out-Null
    $global:stage2CallOrder.Add('junctions') | Out-Null
    [PSCustomObject]@{ Success = $true; JunctionsCreated = 3; Errors = @() }
  }

  function global:Initialize-DownstreamSprintFromSharedVSCode { }
  function global:Invoke-SprintAIAdapterLifecycle {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Boundary, [string]$TargetRoot, [string]$SharedVSCodeWorktreePath, [switch]$FixtureMode, [switch]$AllowUserGlobalWrite, [switch]$CheckpointConfirmed, [string]$EvidenceRoot, [switch]$OmitSprintWorktrees)
    $global:stage2CallOrder.Add('render') | Out-Null
    [PSCustomObject]@{ DriftClean = $true; Results = @(); ChangedCount = 0 }
  }
  function global:Set-ClaudeSettingsSymlink { }
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

  function global:New-OverviewSprintWorkspace {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
      [int]$SprintNumber,
      [string]$GitRoot,
      [string]$DeveloperUsername,
      [string]$BuildMasterBaseUrl,
      [string]$ProGetBaseUrl
    )
    $sprintText = '{0:D4}' -f $SprintNumber
    $outputPath = Join-Path $GitRoot ("OverviewSprint{0}.code-workspace" -f $sprintText)
    $ws = [PSCustomObject]@{
      folders = @(
        [PSCustomObject]@{ path = "_Planning-wt-456-Sprint-$sprintText-work-items" }
        [PSCustomObject]@{ path = "ATAP.Utilities-wt-321-Sprint-$sprintText-work-items" }
      )
    }
    Set-Content -LiteralPath $outputPath -Value ($ws | ConvertTo-Json -Depth 10) -Encoding UTF8
    [PSCustomObject]@{ OutputWorkspacePath = $outputPath; SprintNumber = $sprintText; FolderCount = 2 }
  }

  function global:Build-AIInstructionsPerRepository {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$WorktreeRoot, [string]$WorkspacePath)
    [PSCustomObject]@{
      Success                = $true
      WorkspacePath          = $WorkspacePath
      RepositoriesDiscovered = 2
      Builders               = [PSCustomObject]@{}
      Errors                 = @()
    }
  }

  . "$PSScriptRoot\..\..\public\New-SprintStage2Result.ps1"
  # Task 12.2.b: New-SprintStage2 delegates per-worktree provisioning to the
  # single Start entry point. Dot-source the REAL Set-SprintBoundaryContext so
  # the SC-0236 assertions still flow end-to-end into the Set-WorktreeJunctions
  # stub through the consolidated code path.
  . "$PSScriptRoot\..\..\public\Set-SprintBoundaryContext.ps1"
  . "$PSScriptRoot\..\..\public\New-SprintStage2.ps1"
}

AfterAll {
  foreach ($name in $script:stubbedFunctionNames) {
    Remove-Item -Path "Function:\$name" -Force -ErrorAction SilentlyContinue
  }
  $global:PSModuleAutoLoadingPreference = $script:priorModuleAutoLoad
}

Describe 'New-SprintStage2 junction scan scope (SC-0236)' -Tag 'Unit', 'PromotedModuleHostSensitive' {
  BeforeEach {
    $global:stage2JunctionCalls = [System.Collections.Generic.List[object]]::new()
    $global:stage2CallOrder = [System.Collections.Generic.List[string]]::new()

    $script:tempGitRoot = Join-Path ([System.IO.Path]::GetTempPath()) "stage2_junctionscope_$([guid]::NewGuid().ToString('N'))"
    $repoPath = Join-Path $script:tempGitRoot 'ATAP.Utilities'
    New-Item -ItemType Directory -Path (Join-Path $repoPath '.git') -Force | Out-Null

    $script:tasksPath = Join-Path $script:tempGitRoot 'TASKS.md'
    Set-Content -LiteralPath $script:tasksPath -Encoding UTF8 -Value @(
      '- [ ] **Task 9.1** [ATAP.Utilities] - Test junction scope wiring'
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
    Remove-Variable -Name stage2JunctionCalls -Scope Global -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name stage2CallOrder -Scope Global -Force -ErrorAction SilentlyContinue
  }

  It 'Passes -SourceRepoFolderNames matching JunctionFolderNames (default .vscode only)' {
    New-SprintStage2 `
      -Stage1Result $script:stage1 `
      -TasksFilePath $script:tasksPath `
      -GitRoot $script:tempGitRoot `
      -Owner 'owner' `
      -SkipDatabaseReset `
      -Confirm:$false | Out-Null

    $global:stage2JunctionCalls | Should -HaveCount 1
    (@($global:stage2JunctionCalls[0].SourceRepoFolderNames) -join ',') | Should -Be '.vscode'
  }

  It 'An explicit JunctionFolderNames override flows through to the source scan too' {
    New-SprintStage2 `
      -Stage1Result $script:stage1 `
      -TasksFilePath $script:tasksPath `
      -GitRoot $script:tempGitRoot `
      -Owner 'owner' `
      -JunctionFolderNames @('.claude', '.github', '.vscode') `
      -SkipDatabaseReset `
      -Confirm:$false | Out-Null

    $global:stage2JunctionCalls | Should -HaveCount 1
    @($global:stage2JunctionCalls[0].SourceRepoFolderNames) | Should -Contain '.claude'
  }

  It 'Provisions through the single Start entry point with junctions strictly before the adapter render (Task 12.2.b)' {
    New-SprintStage2 `
      -Stage1Result $script:stage1 `
      -TasksFilePath $script:tasksPath `
      -GitRoot $script:tempGitRoot `
      -Owner 'owner' `
      -SkipDatabaseReset `
      -Confirm:$false | Out-Null

    @($global:stage2CallOrder) | Should -Contain 'junctions'
    @($global:stage2CallOrder) | Should -Contain 'render'
    $global:stage2CallOrder.IndexOf('junctions') | Should -BeLessThan $global:stage2CallOrder.IndexOf('render')
  }
}

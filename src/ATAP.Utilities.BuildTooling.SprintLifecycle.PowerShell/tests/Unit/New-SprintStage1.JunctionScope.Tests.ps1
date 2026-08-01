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
  function global:Confirm-WorktreeGitPointerOwnership {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
      [string]$WorktreePath,
      [string]$InteractiveOperator,
      [bool]$RepairOwnership = $true
    )
    [PSCustomObject]@{ WorktreePath = $WorktreePath; Verified = $true; Repaired = $false }
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
    $global:stage1CallOrder.Add('junctions') | Out-Null
    [PSCustomObject]@{
      Success          = $true
      JunctionsCreated = 3
      Errors           = @()
    }
  }
  function global:Initialize-DownstreamSprintFromSharedVSCode {}
  function global:Invoke-SprintAIAdapterLifecycle {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Boundary, [string]$TargetRoot, [string]$SharedVSCodeWorktreePath, [switch]$FixtureMode, [switch]$AllowUserGlobalWrite, [switch]$CheckpointConfirmed, [string]$EvidenceRoot, [switch]$OmitSprintWorktrees)
    $global:stage1CallOrder.Add('render') | Out-Null
    [PSCustomObject]@{ DriftClean = $true; Results = @(); ChangedCount = 0 }
  }
  function global:Get-SprintHistoryReconstruction {
    param([string]$PlanningRoot)
    [PSCustomObject]@{
      LastCompletedSprintNumber = 9
      Warnings                  = @()
    }
  }

  . "$PSScriptRoot\..\..\public\Convert-TasksMdToSprintBoard.ps1"
  # Task 12.2.b: New-SprintStage1 delegates per-worktree provisioning to the
  # single Start entry point. Dot-source the REAL Set-SprintBoundaryContext so
  # the SC-0236 assertions still flow end-to-end into the Set-WorktreeJunctions
  # stub through the consolidated code path.
  . "$PSScriptRoot\..\..\public\Set-SprintBoundaryContext.ps1"
  . "$PSScriptRoot\..\..\public\New-SprintStage1.ps1"
}

AfterAll {
  @(
    'Assert-GitAvailable'
    'gh'
    'git'
    'Confirm-WorktreeGitPointerOwnership'
    'Set-WorktreeJunctions'
    'Initialize-DownstreamSprintFromSharedVSCode'
    'Invoke-SprintAIAdapterLifecycle'
    'Get-SprintHistoryReconstruction'
  ) | ForEach-Object {
    Remove-Item -Path "Function:\$_" -Force -ErrorAction SilentlyContinue
  }
}

Describe 'New-SprintStage1 junction scan scope (SC-0236)' -Tag 'Unit', 'PromotedModuleHostSensitive' {
  BeforeEach {
    $global:stage1JunctionCalls = [System.Collections.Generic.List[object]]::new()
    $global:stage1CallOrder = [System.Collections.Generic.List[string]]::new()

    # Required-module imports during the first example can replace a global
    # command stub with the dependency module's exported implementation. Restore
    # this fixture-local fake before every example so no test reaches a real git
    # repository or junction mutation.
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
      $global:stage1CallOrder.Add('junctions') | Out-Null
      [PSCustomObject]@{
        Success          = $true
        JunctionsCreated = 3
        Errors           = @()
      }
    }
    function global:Invoke-SprintAIAdapterLifecycle {
      [CmdletBinding(SupportsShouldProcess = $true)]
      param(
        [string]$Boundary,
        [string]$TargetRoot,
        [string]$SharedVSCodeWorktreePath,
        [switch]$FixtureMode,
        [switch]$AllowUserGlobalWrite,
        [switch]$CheckpointConfirmed,
        [string]$EvidenceRoot,
        [switch]$OmitSprintWorktrees
      )
      $global:stage1CallOrder.Add('render') | Out-Null
      [PSCustomObject]@{ DriftClean = $true; Results = @(); ChangedCount = 0 }
    }

    $script:tempGitRoot = Join-Path ([System.IO.Path]::GetTempPath()) "stage1_junctionscope_$([guid]::NewGuid().ToString('N'))"
    $script:sharedWorktree = Join-Path $script:tempGitRoot 'SharedVSCode-wt-999-Sprint-0010-work-items'
    $script:planningWorktree = Join-Path $script:tempGitRoot '_Planning-wt-999-Sprint-0010-work-items'

    New-Item -ItemType Directory -Path $script:sharedWorktree -Force | Out-Null
    New-Item -ItemType Directory -Path $script:planningWorktree -Force | Out-Null
    # Task 12.2.b: the real Set-SprintBoundaryContext derives and validates the
    # stable repo path from the worktree name, so the stable _Planning repo must exist.
    New-Item -ItemType Directory -Path (Join-Path $script:tempGitRoot '_Planning') -Force | Out-Null

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
    Remove-Variable -Name stage1CallOrder -Scope Global -Force -ErrorAction SilentlyContinue
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

  It 'Provisions through the single Start entry point with junctions strictly before the adapter render (Task 12.2.b)' {
    New-SprintStage1 `
      -GitRoot $script:tempGitRoot `
      -Owner 'owner' `
      -SprintNumber '0010' `
      -Confirm:$false | Out-Null

    @($global:stage1CallOrder) | Should -Contain 'junctions'
    @($global:stage1CallOrder) | Should -Contain 'render'
    $global:stage1CallOrder.IndexOf('junctions') | Should -BeLessThan $global:stage1CallOrder.IndexOf('render')
  }
}

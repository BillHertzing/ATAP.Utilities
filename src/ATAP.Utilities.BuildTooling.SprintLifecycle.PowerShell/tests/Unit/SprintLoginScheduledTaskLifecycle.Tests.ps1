#Requires -Version 7.0

BeforeAll {
  $moduleRoot = Join-Path $PSScriptRoot '../..'
  foreach ($path in @('private/Invoke-SprintEndNativeCommand.ps1',
      'private/Get-SprintWorktreeClassification.ps1', 'private/Get-SprintEndLockFileApplicability.ps1')) {
    . (Join-Path $moduleRoot $path)
  }
  foreach ($publicFunction in Get-ChildItem (Join-Path $moduleRoot 'public') -Filter '*.ps1' -File) {
    . $publicFunction.FullName
  }
  # A local, inert contract makes every mock independent of installed modules.
  function Set-SprintLoginScheduledTaskTarget {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Boundary, [string]$ATAPUtilitiesRoot, [string]$GitRoot,
      [string]$LoginScriptPath, [string[]]$WorktreePaths, [switch]$CheckOnly)
    throw 'A lifecycle test reached the unmocked login helper.'
  }
  function Set-WorktreeJunctions { param($SourceRepoPath, $WorktreePath, $DevSourceRepoPath, $DevSourceRepoFolderNames, $SourceRepoFolderNames) }
  function Initialize-DownstreamSprintFromSharedVSCode { param($WorktreePath, $SharedVSCodeRepoName, $TemplateRef, $Profile, $SharedHooksSubPath, $CommitTemplateRelativePath) }
  function Reset-DownstreamToSharedVSCodeMain { param($WorktreePath, $SharedVSCodeRepoName, $SharedHooksSubPath, $CommitTemplateRelativePath) }
  function Set-UserSettingsSymlink { param($SharedVSCodeWorktreePath) }
  # Exercise the production Stage2 selection/call block with adversarial
  # repoResults that the normal repo-discovery deduplication cannot produce.
  $tokens = $null; $parseErrors = $null
  $stage2Ast = [Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $moduleRoot 'public/New-SprintStage2.ps1'), [ref]$tokens, [ref]$parseErrors)
  $loginTry = @($stage2Ast.FindAll({ param($node)
        $node -is [Management.Automation.Language.TryStatementAst] -and
        $node.Body.Extent.Text -match '\$loginUtilitiesCandidates ='
      }, $true))
  if ($loginTry.Count -ne 1) { throw 'Expected one Stage2 login selection block.' }
  $loginBodyText = $loginTry[0].Body.Extent.Text
  $loginHarnessPrefix = @'
    [CmdletBinding(SupportsShouldProcess)]
    param($RepoResults, [string]$GitRoot, [string]$LoginScriptPath)
    $sprintNum = '0015'
'@
  $loginHarness = [scriptblock]::Create($loginHarnessPrefix + $loginBodyText.Substring(1, $loginBodyText.Length - 2) + '; $loginScheduledTasks')
  Set-Item Function:Invoke-Stage2LoginBlock -Value $loginHarness
}

Describe 'Login scheduled-task lifecycle integration' -Tag 'Unit' {
  BeforeEach {
    $script:gitRoot = Join-Path $TestDrive 'GitHub'
    $script:planning = Join-Path $script:gitRoot '_Planning-wt-35-Sprint-0015-work-items'
    $script:shared = Join-Path $script:gitRoot 'SharedVSCode-wt-64-Sprint-0015-work-items'
    $script:utilities = Join-Path $script:gitRoot 'ATAP.Utilities-wt-137-Sprint-0015-work-items'
    $script:override = Join-Path $TestDrive 'Development/LoginScript.ps1'
    New-Item -ItemType Directory -Path $script:gitRoot, $script:planning, $script:shared, $script:utilities,
      (Join-Path $script:gitRoot 'ATAP.Utilities'),
      (Join-Path $script:planning 'SprintRetrospective') -Force | Out-Null
    Set-Content (Join-Path $script:planning 'SprintRetrospective/Notebook-SprintWorkSession-0015-End.md') '# End'
    $script:loginCalls = [Collections.Generic.List[object]]::new()
    $script:trace = [Collections.Generic.List[string]]::new()
    Mock Set-SprintLoginScheduledTaskTarget {
      $script:loginCalls.Add([PSCustomObject]@{
          Boundary = $Boundary; GitRoot = $GitRoot; ATAPUtilitiesRoot = $ATAPUtilitiesRoot
          RootBound = $PesterBoundParameters.ContainsKey('ATAPUtilitiesRoot')
          OverrideBound = $PesterBoundParameters.ContainsKey('LoginScriptPath')
          LoginScriptPath = $LoginScriptPath; WorktreePaths = @($WorktreePaths)
          CheckOnly = [bool]$CheckOnly; WhatIf = [bool]$WhatIfPreference
        })
      $script:trace.Add('login')
      [PSCustomObject]@{ Ok = $true; Boundary = $Boundary; SelectionMode = 'StableDefault';
        TargetPath = $LoginScriptPath; TargetHash = 'fixture'; Planned = [bool]$WhatIfPreference;
        Changed = $false; Tasks = @(); Rollback = @{ Attempted = $false; Succeeded = $true; Failures = @() }; Failures = @() }
    }
    Mock Sync-SprintBoundaryPrimaryRoleMarker { [PSCustomObject]@{ Action = 'Unchanged' } }
    Mock Set-WorktreeJunctions { [PSCustomObject]@{ Success = $true; Errors = @() } }
    Mock Initialize-DownstreamSprintFromSharedVSCode { }
    Mock Reset-DownstreamToSharedVSCodeMain { }
    Mock Get-SprintEndContext { [PSCustomObject]@{ Ok = $true; ClosedSprintNumber = '0015'; NextSprintNumber = '0016' } }
    Mock Test-SprintEndWriteTarget { [PSCustomObject]@{ Ok = $true; BlockedPaths = @() } }
    Mock Get-SprintEndApprovalPlan { [PSCustomObject]@{ Ok = $true; Concerns = @(); RequiredPrompts = @() } }
    Mock Test-SprintEndCommandSurface { [PSCustomObject]@{ Ok = $true } }
    Mock Test-SprintPrerequisites { [PSCustomObject]@{ AllOk = $true } }
    Mock Test-SprintEndWorktreeState { [PSCustomObject]@{ Ok = $true } }
    Mock Test-SprintCheckpointCoverage { [PSCustomObject]@{ Ok = $true } }
    Mock Invoke-SprintEndInfrastructureCleanup { $script:trace.Add('cleanup'); [PSCustomObject]@{ Ok = $true } }
    Mock New-SprintEndHandoff { $script:trace.Add('handoff'); [PSCustomObject]@{ Ok = $true } }
    $script:boundaryParameters = @{
      Boundary = 'Start'; GitRoot = $script:gitRoot; SharedVSCodeWorktreePath = $script:shared
      SkipProfileSymlinks = $true; SkipSharedVSCodeSettings = $true; SkipServiceAccountGitTrust = $true
      SkipAIAdapterLifecycle = $true; Confirm = $false
    }
    $script:endParameters = @{
      GitRoot = $script:gitRoot; PlanningRoot = $script:planning; SharedVSCodeWorktreePath = $script:shared
      WorktreePaths = @($script:utilities, $script:shared); VerifyCheckpoints = $true; Confirm = $false
    }
  }

  It 'maintains login tasks even when profile processing is skipped, preserving explicit Start root input' {
    $result = Set-SprintBoundaryContext @script:boundaryParameters -ATAPUtilitiesRoot $script:utilities
    $script:loginCalls.Count | Should -Be 1
    $script:loginCalls[0].ATAPUtilitiesRoot | Should -Be $script:utilities
    $script:loginCalls[0].RootBound | Should -BeTrue
    $script:loginCalls[0].OverrideBound | Should -BeFalse
    $result.LoginScheduledTasks.Ok | Should -BeTrue
    ($result.Concerns | Where-Object Concern -EQ 'LoginScheduledTasks').Succeeded | Should -BeTrue
  }

  It 'passes Start worktree candidates to the helper without legacy stable profile fallback' {
    Set-SprintBoundaryContext @script:boundaryParameters -WorktreePaths @($script:utilities) | Out-Null
    $script:loginCalls[0].RootBound | Should -BeFalse
    $script:loginCalls[0].WorktreePaths | Should -Be @($script:utilities)
  }

  It 'forwards an invocation-only override and omits it on the next boundary call' {
    Set-SprintBoundaryContext @script:boundaryParameters -LoginScriptPath $script:override | Out-Null
    Set-SprintBoundaryContext @script:boundaryParameters | Out-Null
    $script:loginCalls[0].OverrideBound | Should -BeTrue
    $script:loginCalls[0].LoginScriptPath | Should -Be $script:override
    $script:loginCalls[1].OverrideBound | Should -BeFalse
  }

  It 'plans the login concern under WhatIf and forwards its planned result' {
    $result = Set-SprintBoundaryContext @script:boundaryParameters -WhatIf
    $script:loginCalls.Count | Should -Be 1
    $script:loginCalls[0].WhatIf | Should -BeTrue
    $result.LoginScheduledTasks.Planned | Should -BeTrue
    $result.LoginScheduledTasks.Changed | Should -BeFalse
  }

  It 'explicitly skips the global concern for internal provisioning' {
    $result = Set-SprintBoundaryContext @script:boundaryParameters -SkipLoginScheduledTasks
    Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 0
    ($result.Concerns | Where-Object Concern -EQ 'LoginScheduledTasks').Action | Should -Be 'Skipped'
    $result.LoginScheduledTasks | Should -BeNullOrEmpty
  }

  It 'propagates helper failure and rollback evidence as an independent boundary error' {
    Mock Set-SprintLoginScheduledTaskTarget { [PSCustomObject]@{
        Ok = $false; Failures = @('second task readback failed')
        Rollback = @{ Attempted = $true; Succeeded = $false; Failures = @('rollback failed') }
      } }
    $result = Set-SprintBoundaryContext @script:boundaryParameters
    $result.LoginScheduledTaskError | Should -Match 'second task readback failed'
    $result.Errors | Should -Contain $result.LoginScheduledTaskError
    $result.LoginScheduledTasks.Rollback.Succeeded | Should -BeFalse
    ($result.Concerns | Where-Object Concern -EQ 'LoginScheduledTasks').Succeeded | Should -BeFalse
  }

  It 'captures a terminating login maintenance failure in boundary Errors' {
    Mock Set-SprintLoginScheduledTaskTarget { throw 'task registration ambiguous' }
    $result = Set-SprintBoundaryContext @script:boundaryParameters
    $result.LoginScheduledTaskError | Should -Match 'task registration ambiguous'
    $result.Errors | Should -Contain $result.LoginScheduledTaskError
  }

  It 'preserves the structured login result and error in the Stage2 return contract' {
    $pair = [PSCustomObject]@{ Ok = $false; Tasks = @('first', 'second'); Rollback = @{ Attempted = $true } }
    $result = New-SprintStage2Result -LoginScheduledTasks $pair -LoginScheduledTaskError 'failed'
    $result.infrastructure.loginScheduledTasks | Should -Be $pair
    $result.infrastructure.loginScheduledTaskError | Should -Be 'failed'
    $result.infrastructure.PSObject.Properties.Name | Should -Contain 'profileSymlinkError'
    $result.repoResults | Should -BeNullOrEmpty
  }

  It 'rejects an explicitly empty override in every lifecycle entrypoint' {
    { Set-SprintBoundaryContext @script:boundaryParameters -LoginScriptPath '' } | Should -Throw
    { Invoke-SprintEndLifecycle @script:endParameters -LoginScriptPath '' } | Should -Throw
    { Test-SprintEndBoundaryState -GitRoot $script:gitRoot -LoginScriptPath '' } | Should -Throw
    { New-SprintStage2 -Stage1Result ([PSCustomObject]@{}) -SkipPowerShellProfileRetarget -LoginScriptPath '' } | Should -Throw
    Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 0
  }

  Context 'Stage2 active Utilities selection' {
    It 'selects one successful active Utilities path and forwards an explicit override' {
      $rows = @([PSCustomObject]@{ repoName = 'ATAP.Utilities'; worktreePath = $script:utilities; error = $null })
      Invoke-Stage2LoginBlock -RepoResults $rows -GitRoot $script:gitRoot -LoginScriptPath $script:override -Confirm:$false | Out-Null
      $script:loginCalls.Count | Should -Be 1
      $script:loginCalls[0].RootBound | Should -BeFalse
      $script:loginCalls[0].OverrideBound | Should -BeTrue
    }

    It 'rejects zero successful Utilities paths without stable fallback' {
      $rows = @([PSCustomObject]@{ repoName = 'ATAP.Utilities'; worktreePath = $script:utilities; error = 'provision failed' })
      { Invoke-Stage2LoginBlock -RepoResults $rows -GitRoot $script:gitRoot -Confirm:$false } | Should -Throw '*found 0*'
      Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 0
    }

    It 'rejects a Utilities path from a different sprint' {
      $rows = @([PSCustomObject]@{ repoName = 'ATAP.Utilities'; worktreePath = (Join-Path $script:gitRoot 'ATAP.Utilities-wt-137-Sprint-0014-work-items'); error = $null })
      { Invoke-Stage2LoginBlock -RepoResults $rows -GitRoot $script:gitRoot -Confirm:$false } | Should -Throw '*found 0*'
      Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 0
    }

    It 'rejects two distinct successful active Utilities roots' {
      $rows = @(
        [PSCustomObject]@{ repoName = 'ATAP.Utilities'; worktreePath = $script:utilities; error = $null },
        [PSCustomObject]@{ repoName = 'ATAP.Utilities'; worktreePath = (Join-Path $script:gitRoot 'ATAP.Utilities-wt-999-Sprint-0015-work-items'); error = $null })
      { Invoke-Stage2LoginBlock -RepoResults $rows -GitRoot $script:gitRoot -Confirm:$false } | Should -Throw '*found 2*'
      Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 0
    }

    It 'honors an explicit development override with zero Utilities candidates' {
      Invoke-Stage2LoginBlock -RepoResults @() -GitRoot $script:gitRoot -LoginScriptPath $script:override -Confirm:$false | Out-Null
      $script:loginCalls.Count | Should -Be 1
      $script:loginCalls[0].RootBound | Should -BeFalse
      $script:loginCalls[0].LoginScriptPath | Should -Be $script:override
    }

    It 'honors an explicit development override without guessing between Utilities candidates' {
      $rows = @(
        [PSCustomObject]@{ repoName = 'ATAP.Utilities'; worktreePath = $script:utilities; error = $null },
        [PSCustomObject]@{ repoName = 'ATAP.Utilities'; worktreePath = (Join-Path $script:gitRoot 'ATAP.Utilities-wt-999-Sprint-0015-work-items'); error = $null })
      Invoke-Stage2LoginBlock -RepoResults $rows -GitRoot $script:gitRoot -LoginScriptPath $script:override -Confirm:$false | Out-Null
      $script:loginCalls.Count | Should -Be 1
      $script:loginCalls[0].RootBound | Should -BeFalse
      $script:loginCalls[0].LoginScriptPath | Should -Be $script:override
    }

    It 'maintains the same normalized root only once and omits an unbound override' {
      $row = [PSCustomObject]@{ repoName = 'ATAP.Utilities'; worktreePath = $script:utilities; error = $null }
      Invoke-Stage2LoginBlock -RepoResults @($row, $row) -GitRoot $script:gitRoot -Confirm:$false | Out-Null
      $script:loginCalls.Count | Should -Be 1
      $script:loginCalls[0].OverrideBound | Should -BeFalse
    }

    It 'forwards a plan for a validated active root under WhatIf' {
      $rows = @([PSCustomObject]@{ repoName = 'ATAP.Utilities'; worktreePath = $script:utilities; error = $null })
      $result = Invoke-Stage2LoginBlock -RepoResults $rows -GitRoot $script:gitRoot -WhatIf
      $result.Planned | Should -BeTrue
      $script:loginCalls[0].WhatIf | Should -BeTrue
    }
  }

  Context 'Read-only final boundary audit' {
    It 'audits End with the actual GitRoot, removal roots and explicit override' {
      $result = Test-SprintEndBoundaryState -GitRoot $script:gitRoot -SearchRoots @() -ProfilePaths @() `
        -ProhibitedEnvironmentVariableNames @() -WorktreePaths @($script:utilities) -LoginScriptPath $script:override
      $result.Ok | Should -BeTrue
      $script:loginCalls[0].CheckOnly | Should -BeTrue
      $script:loginCalls[0].Boundary | Should -Be 'End'
      $script:loginCalls[0].GitRoot | Should -Be $script:gitRoot
      $script:loginCalls[0].WorktreePaths | Should -Be @($script:utilities)
      $script:loginCalls[0].LoginScriptPath | Should -Be $script:override
      $result.LoginScheduledTasks.TargetHash | Should -Be 'fixture'
    }

    It 'reports stale, missing or ambiguous task failures without repairing them' {
      Mock Set-SprintLoginScheduledTaskTarget { [PSCustomObject]@{ Ok = $false; Failures = @('stale binding') } }
      $result = Test-SprintEndBoundaryState -GitRoot $script:gitRoot -SearchRoots @() -ProfilePaths @() -ProhibitedEnvironmentVariableNames @()
      $result.Ok | Should -BeFalse
      $result.Failures | Should -Contain 'LoginScheduledTasks'
      $result.LoginScheduledTaskError | Should -Match 'stale binding'
      Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 1 -ParameterFilter { $CheckOnly }
    }

    It 'fails closed on an audit exception' {
      Mock Set-SprintLoginScheduledTaskTarget { throw 'scheduler unavailable' }
      $result = Test-SprintEndBoundaryState -GitRoot $script:gitRoot -SearchRoots @() -ProfilePaths @() -ProhibitedEnvironmentVariableNames @()
      $result.Failures | Should -Contain 'LoginScheduledTasks'
      $result.LoginScheduledTaskError | Should -Match 'scheduler unavailable'
    }
  }

  Context 'SprintEnd teardown gate' {
    BeforeEach {
      Mock Set-SprintBoundaryContext { [PSCustomObject]@{ Errors = @() } }
      Mock Test-SprintEndBoundaryState { [PSCustomObject]@{ Ok = $true } }
    }

    It 'forwards the actual root and override to the applied boundary and final audit' {
      $result = Invoke-SprintEndLifecycle @script:endParameters -ApplyBoundary -CleanupInfrastructure -LoginScriptPath $script:override
      $result.Ok | Should -BeTrue
      Should -Invoke Set-SprintBoundaryContext -Times 1 -ParameterFilter {
        $GitRoot -eq $script:gitRoot -and $LoginScriptPath -eq $script:override -and $WorktreePaths -contains $script:utilities
      }
      Should -Invoke Invoke-SprintEndInfrastructureCleanup -Times 1 -ParameterFilter {
        $LoginScriptPath -eq $script:override -and $WorktreePaths -contains $script:utilities
      }
      Should -Invoke Test-SprintEndBoundaryState -Times 1 -ParameterFilter {
        $GitRoot -eq $script:gitRoot -and $LoginScriptPath -eq $script:override -and $WorktreePaths -contains $script:utilities
      }
    }

    It 'blocks cleanup and handoff when applied pair maintenance failed' {
      Mock Set-SprintBoundaryContext { [PSCustomObject]@{ Errors = @('login rollback failed') } }
      $result = Invoke-SprintEndLifecycle @script:endParameters -ApplyBoundary -CleanupInfrastructure -WriteHandoff
      $result.Failures | Should -Contain 'BoundaryReset'
      Should -Invoke Invoke-SprintEndInfrastructureCleanup -Times 0
      Should -Invoke New-SprintEndHandoff -Times 0
    }

    It 'audits an already-correct pair before cleanup-only execution' {
      $result = Invoke-SprintEndLifecycle @script:endParameters -CleanupInfrastructure -LoginScriptPath $script:override
      $result.Ok | Should -BeTrue
      $result.Phases.LoginScheduledTasksPreCleanup.Ok | Should -BeTrue
      $script:trace | Should -Be @('login', 'cleanup')
      $script:loginCalls[0].CheckOnly | Should -BeTrue
      $script:loginCalls[0].LoginScriptPath | Should -Be $script:override
      $script:loginCalls[0].WorktreePaths | Should -Contain $script:utilities
    }

    It 'omits the override on default cleanup-only invocation' {
      Invoke-SprintEndLifecycle @script:endParameters -CleanupInfrastructure | Out-Null
      $script:loginCalls[0].OverrideBound | Should -BeFalse
      Should -Invoke Invoke-SprintEndInfrastructureCleanup -Times 1 -ParameterFilter { -not $PesterBoundParameters.ContainsKey('LoginScriptPath') }
    }

    It 'blocks every teardown phase on failed cleanup-only audit' {
      Mock Set-SprintLoginScheduledTaskTarget { [PSCustomObject]@{ Ok = $false; Failures = @('worktree-bound action') } }
      $result = Invoke-SprintEndLifecycle @script:endParameters -CleanupInfrastructure -WriteHandoff
      $result.Failures | Should -Contain 'LoginScheduledTasksPreCleanup'
      Should -Invoke Invoke-SprintEndInfrastructureCleanup -Times 0
      Should -Invoke New-SprintEndHandoff -Times 0
    }

    It 'blocks a GitHub-only close when the retained login pair audit fails' {
      Mock Invoke-SprintEndGitHubClose { throw 'GitHub close must not run' }
      Mock Set-SprintLoginScheduledTaskTarget { [PSCustomObject]@{ Ok = $false; Failures = @('stale pair') } }
      $result = Invoke-SprintEndLifecycle @script:endParameters -CreatePullRequests
      $result.Failures | Should -Contain 'LoginScheduledTasksPreCleanup'
      Should -Invoke Invoke-SprintEndGitHubClose -Times 0
      Should -Invoke Set-SprintLoginScheduledTaskTarget -Times 1 -ParameterFilter { $CheckOnly }
    }

    It 'blocks cleanup-only execution on a terminating audit error' {
      Mock Set-SprintLoginScheduledTaskTarget { throw 'missing task' }
      $result = Invoke-SprintEndLifecycle @script:endParameters -CleanupInfrastructure
      $result.Failures | Should -Contain 'LoginScheduledTasksPreCleanup'
      $result.Phases.LoginScheduledTasksPreCleanup.Failures | Should -Contain 'missing task'
      Should -Invoke Invoke-SprintEndInfrastructureCleanup -Times 0
    }

    It 'audits read-only during cleanup-only WhatIf and skips final live verification' {
      $result = Invoke-SprintEndLifecycle @script:endParameters -CleanupInfrastructure -WhatIf
      $result.Ok | Should -BeTrue
      $script:loginCalls[0].CheckOnly | Should -BeTrue
      Should -Invoke Test-SprintEndBoundaryState -Times 0
      $result.Phases.FinalBoundary.Skipped | Should -BeTrue
    }
  }
}

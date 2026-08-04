#Requires -Version 7.0

# Task 14.11. Focused coverage for the three SprintEnd approval messages the
# Sprint 0013 close raised redundantly: PR-specialist merge approval,
# delegated-agent relayed authorization, and optional NuGet lock-file runner
# availability. Each concern must carry a documented cause, behave
# deterministically from its inputs, and keep its authority boundary explicit.

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  . (Join-Path $moduleRoot 'private\Invoke-SprintEndNativeCommand.ps1')
  . (Join-Path $moduleRoot 'private\Get-SprintWorktreeClassification.ps1')
  . (Join-Path $moduleRoot 'private\Get-SprintEndLockFileApplicability.ps1')
  foreach ($publicFunction in Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'public') -Filter '*.ps1' -File) {
    . $publicFunction.FullName
  }

  function script:Get-Concern {
    param($Plan, [string]$Name)
    @($Plan.Concerns | Where-Object Concern -eq $Name) | Select-Object -First 1
  }
}

Describe 'SprintEnd approval plan' -Tag 'Unit' {
  Context 'Every concern documents its cause and stays deterministic' {
    It 'reports all three Sprint 0013 approval concerns with a non-empty documented cause' {
      $plan = Get-SprintEndApprovalPlan -LockFileApplicable:$false

      @($plan.Concerns.Concern) | Should -Be @(
        'PullRequestMerge', 'DelegatedAgentAuthorization', 'NuGetLockFileRunner'
      )
      foreach ($concern in $plan.Concerns) {
        $concern.Cause | Should -Not -BeNullOrEmpty
        $concern.Detail | Should -Not -BeNullOrEmpty
        $concern.Deterministic | Should -BeTrue
        $concern.Boundary | Should -BeIn @('Merge', 'ReadOnly', 'Secret', 'Irreversible', 'ExternalState')
      }
    }

    It 'returns the identical plan for identical inputs' {
      $arguments = @{
        MergePullRequests            = $true
        MergeAuthorizationConfirmed  = $true
        DelegationMode               = 'Delegated'
        DelegatedAuthorizationSource = 'Operator:2026-08-03T09:15:00-06:00'
        LockFileApplicable           = $false
      }
      $first = Get-SprintEndApprovalPlan @arguments
      $second = Get-SprintEndApprovalPlan @arguments

      ($first | ConvertTo-Json -Depth 6) | Should -Be ($second | ConvertTo-Json -Depth 6)
    }
  }

  Context 'PullRequestMerge' {
    It 'raises no prompt and exercises no merge authority when no merge is requested' {
      $concern = Get-Concern (Get-SprintEndApprovalPlan -LockFileApplicable:$false) 'PullRequestMerge'

      $concern.Decision | Should -Be 'NotRequested'
      $concern.PromptRequired | Should -BeFalse
      $concern.Boundary | Should -Be 'Merge'
    }

    It 'requires exactly one operator prompt when a merge is requested but not yet authorized' {
      $plan = Get-SprintEndApprovalPlan -MergePullRequests -LockFileApplicable:$false
      $concern = Get-Concern $plan 'PullRequestMerge'

      $concern.Decision | Should -Be 'OperatorGate'
      $concern.PromptRequired | Should -BeTrue
      $plan.PromptCount | Should -Be 1
      $plan.RequiredPrompts | Should -Be @('PullRequestMerge')
    }

    It 'suppresses every downstream re-prompt once the operator authorization is recorded' {
      $plan = Get-SprintEndApprovalPlan -MergePullRequests -MergeAuthorizationConfirmed -LockFileApplicable:$false
      $concern = Get-Concern $plan 'PullRequestMerge'

      $concern.Decision | Should -Be 'PreAuthorized'
      $concern.PromptRequired | Should -BeFalse
      $plan.PromptCount | Should -Be 0
      # The boundary stays explicit even when the prompt is gone.
      $concern.Boundary | Should -Be 'Merge'
      $concern.Detail | Should -Match 'Confirm:\$false'
    }

    It 'does not let a recorded authorization widen authority to a merge that was not requested' {
      $concern = Get-Concern (Get-SprintEndApprovalPlan -MergeAuthorizationConfirmed -LockFileApplicable:$false) 'PullRequestMerge'

      $concern.Decision | Should -Be 'NotRequested'
      $concern.PromptRequired | Should -BeFalse
    }
  }

  Context 'DelegatedAgentAuthorization' {
    It 'has no second authorization surface when the orchestrator acts for itself' {
      $concern = Get-Concern (Get-SprintEndApprovalPlan -LockFileApplicable:$false) 'DelegatedAgentAuthorization'

      $concern.Decision | Should -Be 'NotDelegated'
      $concern.PromptRequired | Should -BeFalse
    }

    It 'lets a delegate relay named authorization without re-prompting' {
      $plan = Get-SprintEndApprovalPlan `
        -MergePullRequests -MergeAuthorizationConfirmed `
        -DelegationMode Delegated `
        -DelegatedAuthorizationSource 'Operator:2026-08-03T09:15:00-06:00' `
        -LockFileApplicable:$false
      $concern = Get-Concern $plan 'DelegatedAgentAuthorization'

      $plan.Ok | Should -BeTrue
      $concern.Decision | Should -Be 'RelayedAuthorization'
      $concern.PromptRequired | Should -BeFalse
      $concern.Detail | Should -Match 'Operator:2026-08-03T09:15:00-06:00'
      $plan.PromptCount | Should -Be 0
    }

    It 'fails closed instead of prompting when a delegate has no authorization provenance' {
      $plan = Get-SprintEndApprovalPlan -DelegationMode Delegated -LockFileApplicable:$false
      $concern = Get-Concern $plan 'DelegatedAgentAuthorization'

      $plan.Ok | Should -BeFalse
      $plan.Failures | Should -Contain 'DelegatedAuthorizationSourceMissing'
      $concern.Decision | Should -Be 'AuthorizationMissing'
      # The correction is a hard stop, never a re-asked question.
      $concern.PromptRequired | Should -BeFalse
    }

    It 'treats a whitespace-only authorization source as missing rather than as provenance' {
      $plan = Get-SprintEndApprovalPlan -DelegationMode Delegated -DelegatedAuthorizationSource '   ' -LockFileApplicable:$false

      $plan.Ok | Should -BeFalse
      (Get-Concern $plan 'DelegatedAgentAuthorization').Decision | Should -Be 'AuthorizationMissing'
    }

    It 'throws with the failure list when ThrowOnFailure is supplied' {
      {
        Get-SprintEndApprovalPlan -DelegationMode Delegated -LockFileApplicable:$false -ThrowOnFailure
      } | Should -Throw '*DelegatedAuthorizationSourceMissing*'
    }
  }

  Context 'NuGetLockFileRunner' {
    It 'is never an operator prompt in any of its three states' {
      $states = @(
        Get-SprintEndApprovalPlan -LockFileApplicable:$false -LockFileRunnerAvailable:$false
        Get-SprintEndApprovalPlan -LockFileApplicable:$true -LockFileRunnerAvailable:$true
        Get-SprintEndApprovalPlan -LockFileApplicable:$true -LockFileRunnerAvailable:$false
      )

      foreach ($plan in $states) {
        (Get-Concern $plan 'NuGetLockFileRunner').PromptRequired | Should -BeFalse
      }
      @($states | ForEach-Object { (Get-Concern $_ 'NuGetLockFileRunner').Decision }) |
        Should -Be @('NotApplicable', 'Enforced', 'Blocked')
    }

    It 'is NotApplicable, and Ok, when no worktree tracks a lock file even with no runner' {
      $plan = Get-SprintEndApprovalPlan -LockFileApplicable:$false -LockFileRunnerAvailable:$false

      $plan.Ok | Should -BeTrue
      (Get-Concern $plan 'NuGetLockFileRunner').Detail | Should -Match 'not as an operator decision'
    }

    It 'is a hard failure, not a judgement call, when lock files are tracked and the runner is missing' {
      $plan = Get-SprintEndApprovalPlan -LockFileApplicable:$true -LockFileRunnerAvailable:$false

      $plan.Ok | Should -BeFalse
      $plan.Failures | Should -Contain 'NuGetLockFileRunnerUnavailable'
      $plan.PromptCount | Should -Be 0
    }

    It 'derives applicability from tracked lock files when it is not supplied' {
      Mock Get-SprintEndLockFileApplicability {
        [PSCustomObject]@{ Applicable = $true; TrackedLockFileCount = 7; PerWorktree = @(); Failures = @() }
      }

      $plan = Get-SprintEndApprovalPlan -WorktreePaths @('C:\Repos\App-wt-1-Sprint-0014-work-items') -LockFileRunnerAvailable:$true
      $concern = Get-Concern $plan 'NuGetLockFileRunner'

      $concern.Decision | Should -Be 'Enforced'
      $concern.Detail | Should -Match '7 tracked packages.lock.json'
      Should -Invoke Get-SprintEndLockFileApplicability -Times 1
    }
  }

  Context 'Get-SprintEndLockFileApplicability' {
    It 'reports zero tracked lock files as not applicable' {
      Mock Invoke-SprintEndNativeCommand {
        [PSCustomObject]@{ FilePath = $FilePath; ArgumentList = $ArgumentList; ExitCode = 0; Output = @(); Succeeded = $true }
      }
      $repo = Join-Path $TestDrive 'repo-nolocks'
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      $result = Get-SprintEndLockFileApplicability -WorktreePath @($repo)

      $result.Applicable | Should -BeFalse
      $result.TrackedLockFileCount | Should -Be 0
    }

    It 'counts tracked lock files across every supplied worktree' {
      Mock Invoke-SprintEndNativeCommand {
        [PSCustomObject]@{
          FilePath = $FilePath; ArgumentList = $ArgumentList; ExitCode = 0
          Output = @('src/A/packages.lock.json', '', 'src/B/packages.lock.json'); Succeeded = $true
        }
      }
      $repoOne = Join-Path $TestDrive 'repo-one'
      $repoTwo = Join-Path $TestDrive 'repo-two'
      New-Item -ItemType Directory -Path $repoOne, $repoTwo -Force | Out-Null

      $result = Get-SprintEndLockFileApplicability -WorktreePath @($repoOne, $repoTwo)

      $result.Applicable | Should -BeTrue
      $result.TrackedLockFileCount | Should -Be 4
      $result.PerWorktree.Count | Should -Be 2
    }

    It 'treats a nonexistent path as tracking no lock files without invoking git' {
      Mock Invoke-SprintEndNativeCommand { throw 'git must not be invoked for a nonexistent path' }

      $result = Get-SprintEndLockFileApplicability -WorktreePath @((Join-Path $TestDrive 'never-created'))

      $result.Applicable | Should -BeFalse
      Should -Invoke Invoke-SprintEndNativeCommand -Times 0
    }
  }

  Context 'Invoke-SprintEndLifecycle approval integration' {
    BeforeEach {
      $script:gitRoot = Join-Path $TestDrive 'GitHub'
      $script:planning = Join-Path $script:gitRoot '_Planning-wt-33-Sprint-0014-work-items'
      $script:shared = Join-Path $script:gitRoot 'SharedVSCode-wt-62-Sprint-0014-work-items'
      New-Item -ItemType Directory -Force -Path @($script:planning, $script:shared, (Join-Path $script:planning 'SprintRetrospective')) | Out-Null
      Set-Content -LiteralPath (Join-Path $script:planning 'SprintRetrospective\Notebook-SprintWorkSession-0014-End.md') -Value '# Sprint 0014 End'

      Mock Get-SprintEndContext {
        [PSCustomObject]@{ Ok = $true; ClosedSprintNumber = '0014'; NextSprintNumber = '0015'; Detail = 'fixture' }
      }
      Mock Test-SprintEndCommandSurface { [PSCustomObject]@{ Ok = $true; Failures = @() } }
      Mock Test-SprintPrerequisites { [PSCustomObject]@{ AllOk = $true; Failures = @() } }
      Mock Test-SprintEndWorktreeState { [PSCustomObject]@{ Ok = $true; Failures = @() } }
      Mock Test-SprintCheckpointCoverage { [PSCustomObject]@{ Ok = $true; Failures = @() } }
      Mock Invoke-SprintEndGitHubClose {
        [PSCustomObject]@{ Ok = $true; Repository = (Split-Path -Path $RepoPath -Leaf) }
      }
      Mock Get-SprintEndLockFileApplicability {
        [PSCustomObject]@{ Applicable = $false; TrackedLockFileCount = 0; PerWorktree = @(); Failures = @() }
      }
    }

    It 'skips the lock-file guard as not applicable rather than asking about runner availability' {
      $result = Invoke-SprintEndLifecycle `
        -GitRoot $script:gitRoot -PlanningRoot $script:planning `
        -SharedVSCodeWorktreePath $script:shared -WorktreePaths @($script:shared) -WhatIf

      $result.Ok | Should -BeTrue
      @($result.Phases.ApprovalPlan.Concerns | Where-Object Concern -eq 'NuGetLockFileRunner').Decision |
        Should -Be 'NotApplicable'
      Should -Invoke Test-SprintPrerequisites -Times 1 -ParameterFilter { $SkipLockFileGuard }
    }

    It 'enforces the lock-file guard when the selected worktrees track lock files' {
      Mock Get-SprintEndLockFileApplicability {
        [PSCustomObject]@{ Applicable = $true; TrackedLockFileCount = 3; PerWorktree = @(); Failures = @() }
      }

      $result = Invoke-SprintEndLifecycle `
        -GitRoot $script:gitRoot -PlanningRoot $script:planning `
        -SharedVSCodeWorktreePath $script:shared -WorktreePaths @($script:shared) -WhatIf

      @($result.Phases.ApprovalPlan.Concerns | Where-Object Concern -eq 'NuGetLockFileRunner').Decision |
        Should -Be 'Enforced'
      Should -Invoke Test-SprintPrerequisites -Times 1 -ParameterFilter { -not $SkipLockFileGuard }
    }

    It 'plans a merge in a dry run without demanding the live authorization' {
      $result = Invoke-SprintEndLifecycle `
        -GitRoot $script:gitRoot -PlanningRoot $script:planning `
        -SharedVSCodeWorktreePath $script:shared -WorktreePaths @($script:shared) `
        -CreatePullRequests -MergePullRequests -WhatIf

      $result.Ok | Should -BeTrue
      $result.Failures | Should -Not -Contain 'MergeAuthorizationRequired'
      $result.OperatorPromptsRequired | Should -Be @('PullRequestMerge')
    }

    It 'refuses a live merge that has no recorded operator authorization' {
      $result = Invoke-SprintEndLifecycle `
        -GitRoot $script:gitRoot -PlanningRoot $script:planning `
        -SharedVSCodeWorktreePath $script:shared -WorktreePaths @($script:shared) `
        -CreatePullRequests -MergePullRequests

      $result.Ok | Should -BeFalse
      $result.Failures | Should -Contain 'MergeAuthorizationRequired'
      Should -Invoke Invoke-SprintEndGitHubClose -Times 0
    }

    It 'runs a live merge once, non-interactively, when the authorization is recorded' {
      $result = Invoke-SprintEndLifecycle `
        -GitRoot $script:gitRoot -PlanningRoot $script:planning `
        -SharedVSCodeWorktreePath $script:shared -WorktreePaths @($script:shared) `
        -CreatePullRequests -MergePullRequests -MergeAuthorizationConfirmed

      $result.Failures | Should -Not -Contain 'MergeAuthorizationRequired'
      $result.OperatorPromptsRequired | Should -BeNullOrEmpty
      # The delegate is invoked exactly once and non-interactively: the operator
      # already answered this question at the orchestrator's gate.
      Should -Invoke Invoke-SprintEndGitHubClose -Times 1 -ParameterFilter {
        $Merge -eq $true -and $Confirm -eq $false
      }
    }

    It 'fails closed when a delegate is selected without authorization provenance' {
      $result = Invoke-SprintEndLifecycle `
        -GitRoot $script:gitRoot -PlanningRoot $script:planning `
        -SharedVSCodeWorktreePath $script:shared -WorktreePaths @($script:shared) `
        -CreatePullRequests -MergePullRequests -MergeAuthorizationConfirmed `
        -DelegationMode Delegated -WhatIf

      $result.Ok | Should -BeFalse
      $result.Failures | Should -Contain 'ApprovalPlan'
      $result.Phases.ApprovalPlan.Failures | Should -Contain 'DelegatedAuthorizationSourceMissing'
      Should -Invoke Invoke-SprintEndGitHubClose -Times 0
    }
  }
}

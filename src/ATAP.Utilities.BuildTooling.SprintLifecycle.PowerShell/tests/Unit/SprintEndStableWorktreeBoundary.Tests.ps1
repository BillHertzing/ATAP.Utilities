#Requires -Version 7.0

# Task 14.10 regression suite. The Sprint 0013 close wrote remediation changes
# into stable worktrees. These tests are the automated proof that SprintEnd
# cannot do that again: a stable path is rejected before any mutation runs, and
# a defect discovered against stable content is routed to a durable next-sprint
# input instead of being repaired in place.

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
}

Describe 'SprintEnd stable-worktree write boundary' -Tag 'Unit' {
  BeforeEach {
    $script:gitRoot = Join-Path $TestDrive 'GitHub'
    $script:sprintWorktree = Join-Path $script:gitRoot 'ATAP.Utilities-wt-132-Sprint-0014-work-items'
    $script:planningWorktree = Join-Path $script:gitRoot '_Planning-wt-33-Sprint-0014-work-items'
    $script:stableRepo = Join-Path $script:gitRoot 'ATAP.Utilities'
    $script:stablePlanning = Join-Path $script:gitRoot '_Planning'
    New-Item -ItemType Directory -Force -Path @(
      $script:sprintWorktree, $script:planningWorktree, $script:stableRepo, $script:stablePlanning
    ) | Out-Null
  }

  Context 'Get-SprintWorktreeClassification' {
    It 'classifies a sprint worktree and exposes its stable counterpart' {
      $result = Get-SprintWorktreeClassification -Path $script:sprintWorktree -GitRoot $script:gitRoot

      $result.Classification | Should -Be 'SprintWorktree'
      $result.RepositoryName | Should -Be 'ATAP.Utilities'
      $result.SprintNumber | Should -Be '0014'
      $result.IssueNumber | Should -Be 132
      $result.StableRepositoryPath | Should -Be $script:stableRepo
      $result.WriteAllowedDuringSprintEnd | Should -BeTrue
    }

    It 'classifies a stable repository root as not writable during SprintEnd' {
      $result = Get-SprintWorktreeClassification -Path $script:stableRepo -GitRoot $script:gitRoot

      $result.Classification | Should -Be 'StableWorktree'
      $result.WriteAllowedDuringSprintEnd | Should -BeFalse
      $result.Reason | Should -Match 'merging the sprint branch'
    }

    It 'classifies a file deep inside a stable worktree by its repository folder, not its leaf' {
      $deepFile = Join-Path $script:stableRepo 'src\Module\public\Some-Function.ps1'
      $result = Get-SprintWorktreeClassification -Path $deepFile -GitRoot $script:gitRoot

      $result.Classification | Should -Be 'StableWorktree'
      $result.RepositoryFolderName | Should -Be 'ATAP.Utilities'
      $result.WriteAllowedDuringSprintEnd | Should -BeFalse
    }

    It 'classifies a file deep inside a sprint worktree as writable' {
      $deepFile = Join-Path $script:sprintWorktree 'src\Module\public\Some-Function.ps1'
      $result = Get-SprintWorktreeClassification -Path $deepFile -GitRoot $script:gitRoot

      $result.Classification | Should -Be 'SprintWorktree'
      $result.WriteAllowedDuringSprintEnd | Should -BeTrue
    }

    It 'does not treat a path outside the Git root as a stable worktree' {
      $result = Get-SprintWorktreeClassification -Path (Join-Path $TestDrive 'Elsewhere\file.txt') -GitRoot $script:gitRoot

      $result.Classification | Should -Be 'OutsideGitRoot'
      $result.WriteAllowedDuringSprintEnd | Should -BeFalse
    }

    It 'does not mistake a sibling directory whose name merely starts with the Git root for a child of it' {
      $result = Get-SprintWorktreeClassification -Path ($script:gitRoot + 'Backup\ATAP.Utilities') -GitRoot $script:gitRoot

      $result.Classification | Should -Be 'OutsideGitRoot'
    }

    It 'resolves relative traversal before classifying, so a sprint-prefixed path that escapes into stable is blocked' {
      # The most plausible way a stable write is disguised as a sprint write.
      $escaped = Join-Path $script:sprintWorktree '..\ATAP.Utilities\src\Some-Function.ps1'
      $result = Get-SprintWorktreeClassification -Path $escaped -GitRoot $script:gitRoot

      $result.Classification | Should -Be 'StableWorktree'
      $result.WriteAllowedDuringSprintEnd | Should -BeFalse
    }

    It 'classifies case-insensitively, so a lowercased stable path is still stable' {
      $result = Get-SprintWorktreeClassification -Path $script:stableRepo.ToLowerInvariant() -GitRoot $script:gitRoot.ToUpperInvariant()

      $result.Classification | Should -Be 'StableWorktree'
      $result.WriteAllowedDuringSprintEnd | Should -BeFalse
    }

    It 'requires the full four-digit sprint token, so a near-miss name is treated as stable rather than waved through' {
      $nearMiss = Join-Path $script:gitRoot 'ATAP.Utilities-wt-132-Sprint-14-work-items'
      $result = Get-SprintWorktreeClassification -Path $nearMiss -GitRoot $script:gitRoot

      $result.Classification | Should -Be 'StableWorktree'
      $result.WriteAllowedDuringSprintEnd | Should -BeFalse
    }

    It 'classifies a path it has never seen on disk, so a planned write is gated like a real one' {
      $planned = Join-Path $script:stableRepo 'does\not\exist\yet.ps1'
      Test-Path -LiteralPath $planned | Should -BeFalse

      (Get-SprintWorktreeClassification -Path $planned -GitRoot $script:gitRoot).Classification |
        Should -Be 'StableWorktree'
    }
  }

  Context 'Test-SprintEndWriteTarget' {
    It 'accepts a close plan made entirely of sprint worktrees' {
      $result = Test-SprintEndWriteTarget `
        -Path @($script:sprintWorktree, $script:planningWorktree) `
        -GitRoot $script:gitRoot `
        -Operation 'BoundaryReset'

      $result.Ok | Should -BeTrue
      $result.BlockedPaths | Should -BeNullOrEmpty
      $result.PerPath.Count | Should -Be 2
    }

    It 'blocks a stable repository substituted into the close plan and names the operation' {
      $result = Test-SprintEndWriteTarget `
        -Path @($script:sprintWorktree, $script:stableRepo) `
        -GitRoot $script:gitRoot `
        -Operation 'BoundaryReset'

      $result.Ok | Should -BeFalse
      $result.BlockedPaths | Should -Contain ([IO.Path]::GetFullPath($script:stableRepo))
      $result.Failures[0] | Should -Match 'BoundaryReset'
      $result.Failures[0] | Should -Match 'StableWorktree'
    }

    It 'blocks the stable _Planning worktree just as firmly as any other stable repository' {
      $result = Test-SprintEndWriteTarget -Path $script:stablePlanning -GitRoot $script:gitRoot

      $result.Ok | Should -BeFalse
      $result.PerPath[0].Classification | Should -Be 'StableWorktree'
    }

    It 'throws with a remediation message when ThrowOnFailure is supplied' {
      {
        Test-SprintEndWriteTarget -Path $script:stableRepo -GitRoot $script:gitRoot `
          -Operation 'StableRepair' -ThrowOnFailure
      } | Should -Throw '*StableRepair*'
    }

    It 'allows an explicitly named machine-global path outside the Git root but nothing else outside it' {
      $allowed = Join-Path $TestDrive 'MachineGlobal'
      $notAllowed = Join-Path $TestDrive 'SomewhereElse'

      $allowedResult = Test-SprintEndWriteTarget `
        -Path (Join-Path $allowed 'profile.ps1') `
        -GitRoot $script:gitRoot `
        -AllowedOutsideGitRootPath @($allowed)
      $blockedResult = Test-SprintEndWriteTarget `
        -Path (Join-Path $notAllowed 'profile.ps1') `
        -GitRoot $script:gitRoot `
        -AllowedOutsideGitRootPath @($allowed)

      $allowedResult.Ok | Should -BeTrue
      $allowedResult.PerPath[0].Reason | Should -Match 'AllowedOutsideGitRootPath'
      $blockedResult.Ok | Should -BeFalse
    }

    It 'never allows a stable worktree even when the caller lists it as an allowance' {
      # The allowance exists for machine-global state, not to reopen the very
      # boundary this gate defends. A stable repo is inside GitRoot, so the
      # allowance branch is unreachable for it by construction.
      $result = Test-SprintEndWriteTarget `
        -Path $script:stableRepo `
        -GitRoot $script:gitRoot `
        -AllowedOutsideGitRootPath @($script:stableRepo)

      $result.Ok | Should -BeFalse
      $result.BlockedPaths | Should -Contain ([IO.Path]::GetFullPath($script:stableRepo))
    }
  }

  Context 'Invoke-SprintEndLifecycle write-target gate' {
    BeforeEach {
      New-Item -ItemType Directory -Force -Path (Join-Path $script:planningWorktree 'SprintRetrospective') | Out-Null
      Set-Content -LiteralPath (Join-Path $script:planningWorktree 'SprintRetrospective\Notebook-SprintWorkSession-0014-End.md') -Value '# Sprint 0014 End'
      $script:sharedWorktree = Join-Path $script:gitRoot 'SharedVSCode-wt-62-Sprint-0014-work-items'
      New-Item -ItemType Directory -Force -Path $script:sharedWorktree | Out-Null

      Mock Get-SprintEndContext {
        [PSCustomObject]@{ Ok = $true; ClosedSprintNumber = '0014'; NextSprintNumber = '0015'; Detail = 'fixture' }
      }
      Mock Test-SprintEndCommandSurface { [PSCustomObject]@{ Ok = $true; Failures = @() } }
      Mock Test-SprintPrerequisites { [PSCustomObject]@{ AllOk = $true; Failures = @() } }
      Mock Test-SprintEndWorktreeState { [PSCustomObject]@{ Ok = $true; Failures = @() } }
      Mock Test-SprintCheckpointCoverage { [PSCustomObject]@{ Ok = $true; Failures = @() } }
      Mock Get-SprintEndLockFileApplicability {
        [PSCustomObject]@{ Applicable = $false; TrackedLockFileCount = 0; PerWorktree = @(); Failures = @() }
      }
    }

    It 'passes the gate for a close plan of sprint worktrees only' {
      $result = Invoke-SprintEndLifecycle `
        -GitRoot $script:gitRoot `
        -PlanningRoot $script:planningWorktree `
        -SharedVSCodeWorktreePath $script:sharedWorktree `
        -WorktreePaths @($script:sprintWorktree, $script:sharedWorktree) `
        -WhatIf

      $result.Phases.WriteTargetBoundary.Ok | Should -BeTrue
      $result.StableWorktreeWritesPlanned | Should -BeNullOrEmpty
      $result.Failures | Should -Not -Contain 'WriteTargetBoundary'
    }

    It 'fails closed and runs no mutation phase when a stable worktree enters the close plan' {
      Mock Set-SprintBoundaryContext { throw 'boundary reset must not run for a stable close plan' }
      Mock Invoke-SprintEndGitHubClose { throw 'GitHub close must not run for a stable close plan' }
      Mock Invoke-SprintEndInfrastructureCleanup { throw 'cleanup must not run for a stable close plan' }
      Mock New-SprintEndHandoff { throw 'handoff must not run for a stable close plan' }

      $result = Invoke-SprintEndLifecycle `
        -GitRoot $script:gitRoot `
        -PlanningRoot $script:planningWorktree `
        -SharedVSCodeWorktreePath $script:sharedWorktree `
        -WorktreePaths @($script:sprintWorktree, $script:stableRepo) `
        -ApplyBoundary `
        -VerifyCheckpoints `
        -CreatePullRequests `
        -WriteHandoff `
        -CleanupInfrastructure `
        -WhatIf

      $result.Ok | Should -BeFalse
      $result.Failures | Should -Contain 'WriteTargetBoundary'
      $result.StableWorktreeWritesPlanned | Should -Contain ([IO.Path]::GetFullPath($script:stableRepo))
      Should -Invoke Set-SprintBoundaryContext -Times 0
      Should -Invoke Invoke-SprintEndGitHubClose -Times 0
      Should -Invoke Invoke-SprintEndInfrastructureCleanup -Times 0
      Should -Invoke New-SprintEndHandoff -Times 0
    }
  }

  Context 'New-SprintEndDefectRoute' {
    It 'routes a defect whose affected paths are all inside sprint worktrees to the sprint branch' {
      $result = New-SprintEndDefectRoute `
        -GitRoot $script:gitRoot `
        -PlanningRoot $script:planningWorktree `
        -SprintNumber 14 `
        -DefectId 'SE-0014-01' `
        -Title 'Handoff omitted WorktreePaths' `
        -Summary 'The generated handoff had nothing to retarget.' `
        -AffectedPath @((Join-Path $script:sprintWorktree 'src\Module\public\New-SprintEndHandoff.ps1')) `
        -Confirm:$false

      $result.Ok | Should -BeTrue
      $result.Route | Should -Be 'SprintWorktree'
      $result.RecordPath | Should -BeNullOrEmpty
      $result.SprintWorktreePaths | Should -Contain $script:sprintWorktree
      $result.BlockedPaths | Should -BeNullOrEmpty
    }

    It 'routes a defect against stable content to a durable next-sprint input instead of editing stable' {
      $stableFile = Join-Path $script:stableRepo 'src\Module\public\Broken-Function.ps1'

      $result = New-SprintEndDefectRoute `
        -GitRoot $script:gitRoot `
        -PlanningRoot $script:planningWorktree `
        -SprintNumber 14 `
        -DefectId 'SE-0014-02' `
        -Title 'Stable-only defect' `
        -Summary 'Found during close; cannot be fixed inside any active sprint worktree.' `
        -AffectedPath @($stableFile) `
        -Confirm:$false

      $result.Ok | Should -BeTrue
      $result.Route | Should -Be 'NextSprintInput'
      $result.Changed | Should -BeTrue
      $result.BlockedPaths | Should -Contain ([IO.Path]::GetFullPath($stableFile))
      $result.RecordPath | Should -Match 'InformationForTheFuture'
      $result.RecordPath | Should -Match 'Sprint0014'
      Test-Path -LiteralPath $result.RecordPath | Should -BeTrue

      # The record lives on the sprint branch, so it merges into stable _Planning
      # at close (repository rule R-38) rather than dying with _generated.
      $result.RecordPath | Should -BeLike "$script:planningWorktree*"
      # Nothing was written into any stable worktree.
      @(Get-ChildItem -LiteralPath $script:stableRepo -Recurse -File -ErrorAction SilentlyContinue).Count |
        Should -Be 0
    }

    It 'records a defect with no affected paths as a next-sprint input rather than assuming it is fixable in place' {
      $result = New-SprintEndDefectRoute `
        -GitRoot $script:gitRoot `
        -PlanningRoot $script:planningWorktree `
        -SprintNumber 14 `
        -DefectId 'SE-0014-03' `
        -Title 'Unlocated defect' `
        -Summary 'Symptom observed during close with no path identified yet.' `
        -Confirm:$false

      $result.Route | Should -Be 'NextSprintInput'
      $result.Changed | Should -BeTrue
    }

    It 'is idempotent for identical content and preserves a conflicting human-reviewed record' {
      $parameters = @{
        GitRoot      = $script:gitRoot
        PlanningRoot = $script:planningWorktree
        SprintNumber = 14
        DefectId     = 'SE-0014-04'
        Title        = 'Repeatable defect'
        Summary      = 'Original summary.'
        AffectedPath = @($script:stableRepo)
        Confirm      = $false
      }

      $first = New-SprintEndDefectRoute @parameters
      $second = New-SprintEndDefectRoute @parameters
      $first.Changed | Should -BeTrue
      $second.Changed | Should -BeFalse
      $second.Ok | Should -BeTrue

      $parameters.Summary = 'Different summary written by a later pass.'
      $conflict = New-SprintEndDefectRoute @parameters
      $conflict.Ok | Should -BeFalse
      $conflict.Conflict | Should -BeTrue
      (Get-Content -Raw -LiteralPath $first.RecordPath) | Should -Match 'Original summary'

      $forced = New-SprintEndDefectRoute @parameters -Force
      $forced.Ok | Should -BeTrue
      $forced.Changed | Should -BeTrue
      (Get-Content -Raw -LiteralPath $first.RecordPath) | Should -Match 'Different summary'
    }

    It 'refuses to write a next-sprint input into the stable _Planning worktree' {
      {
        New-SprintEndDefectRoute `
          -GitRoot $script:gitRoot `
          -PlanningRoot $script:stablePlanning `
          -SprintNumber 14 `
          -DefectId 'SE-0014-05' `
          -Title 'Wrong planning root' `
          -Summary 'PlanningRoot points at the stable checkout.' `
          -Confirm:$false
      } | Should -Throw '*StableWorktree*'

      Test-Path -LiteralPath (Join-Path $script:stablePlanning 'InformationForTheFuture') | Should -BeFalse
    }

    It 'writes nothing under -WhatIf' {
      $result = New-SprintEndDefectRoute `
        -GitRoot $script:gitRoot `
        -PlanningRoot $script:planningWorktree `
        -SprintNumber 14 `
        -DefectId 'SE-0014-06' `
        -Title 'Planned only' `
        -Summary 'Dry run.' `
        -AffectedPath @($script:stableRepo) `
        -WhatIf

      $result.Changed | Should -BeFalse
      Test-Path -LiteralPath $result.RecordPath | Should -BeFalse
    }
  }
}

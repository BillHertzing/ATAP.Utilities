#Requires -Version 7.0

# Task 14.12. Crash/resume, stable-boundary, dry-run, and full close rehearsal
# coverage. A rehearsal must complete without stable-worktree edits, synthetic
# task completion, credential deletion, or hidden external mutations -- and must
# fail loudly when any of those happens.

BeforeAll {
  # Task 15.208: isolate login maintenance from the host Task Scheduler.
  function Set-SprintLoginScheduledTaskTarget {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Boundary, [string]$ATAPUtilitiesRoot, [string]$GitRoot,
      [string]$LoginScriptPath, [string[]]$WorktreePaths, [switch]$CheckOnly)
    [PSCustomObject]@{ Ok = $true; Boundary = $Boundary; SelectionMode = 'SprintDefault';
      TargetPath = $LoginScriptPath; TargetHash = 'fixture'; Planned = [bool]$WhatIfPreference;
      Changed = $false; Tasks = @(); Rollback = @{ Attempted = $false; Succeeded = $true; Failures = @() }; Failures = @() }
  }
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

Describe 'SprintEnd close rehearsal' -Tag 'Unit' {
  BeforeEach {
    Mock Set-SprintLoginScheduledTaskTarget { [PSCustomObject]@{ Ok = $true; Planned = $false; Changed = $false; Tasks = @(); Failures = @() } }
  }
  BeforeEach {
    $script:gitRoot = Join-Path $TestDrive 'GitHub'
    $script:planning = Join-Path $script:gitRoot '_Planning-wt-33-Sprint-0014-work-items'
    $script:shared = Join-Path $script:gitRoot 'SharedVSCode-wt-62-Sprint-0014-work-items'
    $script:utilities = Join-Path $script:gitRoot 'ATAP.Utilities-wt-132-Sprint-0014-work-items'
    $script:stablePlanning = Join-Path $script:gitRoot '_Planning'
    New-Item -ItemType Directory -Force -Path @(
      $script:planning, $script:shared, $script:utilities, $script:stablePlanning,
      (Join-Path $script:planning 'SprintRetrospective')
    ) | Out-Null
    Set-Content -LiteralPath (Join-Path $script:planning 'SprintRetrospective\Notebook-SprintWorkSession-0014-End.md') -Value '# Sprint 0014 End'

    # Every stable repository reports a stable, unchanged Git state unless a
    # test deliberately makes it drift.
    $script:stableHead = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    $script:stableStatus = @()
    Mock Invoke-SprintEndNativeCommand {
      $argsText = $ArgumentList -join ' '
      $output = switch -Regex ($argsText) {
        'rev-parse HEAD' { @($script:stableHead); break }
        'status --porcelain' { @($script:stableStatus); break }
        default { @() }
      }
      [PSCustomObject]@{
        FilePath = $FilePath; ArgumentList = $ArgumentList; ExitCode = 0
        Output = $output; Succeeded = $true
      }
    }

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

    # Destructive integrations are mocked; the rehearsal must never reach them
    # live, and these mocks assert that by refusing to act when not in a dry run.
    Mock Set-SprintBoundaryContext { [PSCustomObject]@{ Errors = @() } }
    Mock Assert-MainBranchTemplateRef { [PSCustomObject]@{ Ok = $true; WouldThrow = $false; Violations = @() } }
    Mock Invoke-SprintEndGitHubClose {
      [PSCustomObject]@{ Ok = $true; Repository = (Split-Path -Path $RepoPath -Leaf) }
    }
    Mock Save-SprintHistoryArtifacts { [PSCustomObject]@{ Ok = $true; Files = @() } }
    Mock Invoke-SprintEndOverviewClose { [PSCustomObject]@{ Ok = $true } }
    Mock New-SprintEndHandoff { [PSCustomObject]@{ Changed = $false; Planned = $true; WorktreePaths = $WorktreePaths } }
    Mock Invoke-SprintEndInfrastructureCleanup {
      [PSCustomObject]@{ Ok = $true; DatabaseCleanupMode = 'SprintDatabasesOnly'; SqlInstancesRetained = $true }
    }
    Mock Test-SprintEndBoundaryState { throw 'final boundary verification must not run during a rehearsal' }

    $script:rehearsalParameters = @{
      GitRoot                  = $script:gitRoot
      PlanningRoot             = $script:planning
      SharedVSCodeWorktreePath = $script:shared
      WorktreePaths            = @($script:shared, $script:utilities)
    }
  }

  Context 'A clean rehearsal' {
    It 'passes all four scenarios and reports the close safety invariants' {
      $result = Invoke-SprintEndRehearsal @script:rehearsalParameters -SkipEvidence

      $result.Ok | Should -BeTrue
      $result.DryRun | Should -BeTrue
      @($result.Scenarios.Scenario) | Should -Be @('StableBoundary', 'DryRun', 'CrashResume', 'FullClose')
      @($result.Scenarios | Where-Object { -not $_.Ok }) | Should -BeNullOrEmpty

      $fullClose = @($result.Scenarios | Where-Object Scenario -eq 'FullClose')[0]
      $fullClose.Result.DatabaseCleanupIsSprintOnly | Should -BeTrue
      $fullClose.Result.SqlInstancesRetained | Should -BeTrue
      $fullClose.Result.NoBitwardenSecretRemoval | Should -BeTrue
      $fullClose.Result.NoSyntheticTaskCompletion | Should -BeTrue
      $fullClose.Result.NoStableWorktreeWrite | Should -BeTrue
    }

    It 'never performs a live mutation: every lifecycle pass is a dry run' {
      $result = Invoke-SprintEndRehearsal @script:rehearsalParameters -SkipEvidence

      $result.Ok | Should -BeTrue
      # Test-SprintEndBoundaryState is mocked to throw. It is only reached after
      # live mutations, so a passing rehearsal proves none occurred.
      Should -Invoke Test-SprintEndBoundaryState -Times 0
      @($result.Scenarios | Where-Object Scenario -eq 'DryRun')[0].Result.DryRun | Should -BeTrue
      @($result.Scenarios | Where-Object Scenario -eq 'CrashResume')[0].Result.DryRun | Should -BeTrue
    }

    It 'adds the Planning worktree to the rehearsed close plan when the caller omits it' {
      $result = Invoke-SprintEndRehearsal @script:rehearsalParameters -SkipEvidence

      $result.WorktreePaths | Should -Contain ([IO.Path]::GetFullPath($script:planning))
    }
  }

  Context 'Stable-boundary scenario' {
    It 'fails when a stable worktree is present in the rehearsed close plan' {
      $result = Invoke-SprintEndRehearsal `
        -GitRoot $script:gitRoot -PlanningRoot $script:planning `
        -SharedVSCodeWorktreePath $script:shared `
        -WorktreePaths @($script:shared, (Join-Path $script:gitRoot 'ATAP.Utilities')) `
        -SkipEvidence

      $result.Ok | Should -BeFalse
      $result.Failures | Should -Contain 'StableBoundary'
      @($result.Scenarios | Where-Object Scenario -eq 'StableBoundary')[0].Detail |
        Should -Match 'Blocked stable'
    }

    It 'detects a stable worktree that was mutated while the rehearsal ran' {
      # Only the stable _Planning repository exists on the fixture disk, so a
      # close plan of the Planning worktree alone snapshots exactly one
      # repository: status call 1 is the "before" pass and call 2 the "after".
      # The second pass sees a dirty stable worktree. Nothing in the rehearsal
      # should be able to cause that, which is precisely why it is checked
      # rather than assumed.
      $script:snapshotPass = 0
      Mock Invoke-SprintEndNativeCommand {
        $argsText = $ArgumentList -join ' '
        if ($argsText -match 'status --porcelain') {
          $script:snapshotPass++
          $output = if ($script:snapshotPass -le 1) { @() } else { @(' M src/Module/public/Some-Function.ps1') }
        } elseif ($argsText -match 'rev-parse HEAD') {
          $output = @('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')
        } else {
          $output = @()
        }
        [PSCustomObject]@{
          FilePath = $FilePath; ArgumentList = $ArgumentList; ExitCode = 0
          Output = $output; Succeeded = $true
        }
      }

      $result = Invoke-SprintEndRehearsal `
        -GitRoot $script:gitRoot -PlanningRoot $script:planning `
        -SharedVSCodeWorktreePath $script:shared `
        -WorktreePaths @($script:planning) `
        -SkipEvidence

      $result.Ok | Should -BeFalse
      $result.Failures | Should -Contain 'StableWorktreeMutated'
      $result.StableWorktreeSnapshots.Drift.Count | Should -BeGreaterThan 0
      $result.StableWorktreeSnapshots.Drift[0].StatusChanged | Should -BeTrue
    }
  }

  Context 'Crash/resume scenario' {
    It 'fails when re-entry does not reproduce the same close plan' {
      $script:lifecyclePass = 0
      Mock Invoke-SprintEndLifecycle {
        $script:lifecyclePass++
        $planPaths = if ($script:lifecyclePass -eq 1) {
          @($script:shared, $script:utilities, $script:planning)
        } else {
          @($script:shared)
        }
        [PSCustomObject]@{
          Ok = $true; DryRun = $true
          ClosedSprintNumber = '0014'; NextSprintNumber = '0015'
          Phases = [PSCustomObject]@{
            ClosePlan = @($planPaths | ForEach-Object { [PSCustomObject]@{ WorktreePath = $_ } })
            FinalBoundary = [PSCustomObject]@{ Skipped = $true }
          }
          Failures = @(); DatabaseCleanupMode = 'SprintDatabasesOnly'
          BitwardenSecretsRemoved = $false; SqlInstancesRetained = $true
          SyntheticTaskCompleted = $false; StableWorktreeWritesPlanned = @()
          OperatorPromptsRequired = @()
        }
      }

      $result = Invoke-SprintEndRehearsal @script:rehearsalParameters -SkipEvidence -Scenario CrashResume

      $result.Ok | Should -BeFalse
      $result.Failures | Should -Contain 'CrashResume'
      @($result.Scenarios | Where-Object Scenario -eq 'CrashResume')[0].Detail | Should -Match 'Re-entry diverged'
    }

    It 'passes when re-entry reproduces the same plan regardless of pass order' {
      $result = Invoke-SprintEndRehearsal @script:rehearsalParameters -SkipEvidence -Scenario CrashResume

      $result.Ok | Should -BeTrue
      @($result.Scenarios | Where-Object Scenario -eq 'CrashResume')[0].Detail | Should -Match 'identical'
    }
  }

  Context 'Full-close invariants' {
    It 'fails when the rehearsed close reports a synthetic task completion' {
      Mock Invoke-SprintEndLifecycle {
        [PSCustomObject]@{
          Ok = $true; DryRun = $true
          Phases = [PSCustomObject]@{
            ClosePlan = @([PSCustomObject]@{ WorktreePath = $script:shared })
            FinalBoundary = [PSCustomObject]@{ Skipped = $true }
          }
          Failures = @(); DatabaseCleanupMode = 'SprintDatabasesOnly'
          BitwardenSecretsRemoved = $false; SqlInstancesRetained = $true
          SyntheticTaskCompleted = $true; StableWorktreeWritesPlanned = @()
          OperatorPromptsRequired = @()
        }
      }

      $result = Invoke-SprintEndRehearsal @script:rehearsalParameters -SkipEvidence -Scenario FullClose

      $result.Ok | Should -BeFalse
      @($result.Scenarios | Where-Object Scenario -eq 'FullClose')[0].Detail |
        Should -Match 'NoSyntheticTaskCompletion'
    }

    It 'fails when the rehearsed close reports Bitwarden secret removal' {
      Mock Invoke-SprintEndLifecycle {
        [PSCustomObject]@{
          Ok = $true; DryRun = $true
          Phases = [PSCustomObject]@{
            ClosePlan = @([PSCustomObject]@{ WorktreePath = $script:shared })
            FinalBoundary = [PSCustomObject]@{ Skipped = $true }
          }
          Failures = @(); DatabaseCleanupMode = 'SprintDatabasesOnly'
          BitwardenSecretsRemoved = $true; SqlInstancesRetained = $true
          SyntheticTaskCompleted = $false; StableWorktreeWritesPlanned = @()
          OperatorPromptsRequired = @()
        }
      }

      $result = Invoke-SprintEndRehearsal @script:rehearsalParameters -SkipEvidence -Scenario FullClose

      $result.Ok | Should -BeFalse
      @($result.Scenarios | Where-Object Scenario -eq 'FullClose')[0].Detail |
        Should -Match 'NoBitwardenSecretRemoval'
    }

    It 'fails when the rehearsed close widens database cleanup beyond sprint databases' {
      Mock Invoke-SprintEndLifecycle {
        [PSCustomObject]@{
          Ok = $true; DryRun = $true
          Phases = [PSCustomObject]@{
            ClosePlan = @([PSCustomObject]@{ WorktreePath = $script:shared })
            FinalBoundary = [PSCustomObject]@{ Skipped = $true }
          }
          Failures = @(); DatabaseCleanupMode = 'AllDatabases'
          BitwardenSecretsRemoved = $false; SqlInstancesRetained = $false
          SyntheticTaskCompleted = $false; StableWorktreeWritesPlanned = @()
          OperatorPromptsRequired = @()
        }
      }

      $result = Invoke-SprintEndRehearsal @script:rehearsalParameters -SkipEvidence -Scenario FullClose

      $result.Ok | Should -BeFalse
      $detail = @($result.Scenarios | Where-Object Scenario -eq 'FullClose')[0].Detail
      $detail | Should -Match 'DatabaseCleanupIsSprintOnly'
      $detail | Should -Match 'SqlInstancesRetained'
    }
  }

  Context 'Checkpoint external-durability inputs (SE-0015-01)' {
    BeforeEach {
      $script:durabilityEvidence = @([PSCustomObject]@{ ReplicaKind = 'Primary'; Sha256 = 'fixture' }, [PSCustomObject]@{ ReplicaKind = 'DropboxMirror'; Sha256 = 'fixture' })
      $script:durabilityOverride = [PSCustomObject]@{ Name = 'OperatorException'; Reason = 'fixture' }
      # Coverage only confirms when snapshot evidence reaches it, so the
      # rehearsal can pass only if it forwarded the evidence.
      Mock Test-SprintCheckpointCoverage {
        $hasEvidence = @($ExternalDurabilityEvidence).Count -gt 0
        [PSCustomObject]@{ Ok = $hasEvidence; Failures = @(if (-not $hasEvidence) { 'ExternalDurabilityEvidenceMissing' }) }
      }
    }

    It 'forwards all three inputs unchanged, with -WhatIf, to every lifecycle pass' {
      $script:lifecycleCalls = [System.Collections.Generic.List[hashtable]]::new()
      Mock Invoke-SprintEndLifecycle {
        $script:lifecycleCalls.Add(@{} + $PesterBoundParameters)
        [PSCustomObject]@{
          Ok = $true; DryRun = $true
          Phases = [PSCustomObject]@{
            ClosePlan = @([PSCustomObject]@{ WorktreePath = $script:shared })
            FinalBoundary = [PSCustomObject]@{ Skipped = $true }
          }
          Failures = @(); DatabaseCleanupMode = 'SprintDatabasesOnly'
          BitwardenSecretsRemoved = $false; SqlInstancesRetained = $true
          SyntheticTaskCompleted = $false; StableWorktreeWritesPlanned = @()
          OperatorPromptsRequired = @()
        }
      }

      $result = Invoke-SprintEndRehearsal @script:rehearsalParameters -SkipEvidence `
        -ExternalDurabilityEvidence $script:durabilityEvidence `
        -RequiredExternalReplicaKind @('Primary') `
        -ExternalDurabilityOverride $script:durabilityOverride

      $result.Ok | Should -BeTrue
      # DryRun and CrashResume each drive one lifecycle pass.
      $script:lifecycleCalls.Count | Should -Be 2
      foreach ($call in $script:lifecycleCalls) {
        $call.WhatIf | Should -BeTrue
        $call.VerifyCheckpoints | Should -BeTrue
        @($call.ExternalDurabilityEvidence).Count | Should -Be 2
        [object]::ReferenceEquals($call.ExternalDurabilityEvidence[0], $script:durabilityEvidence[0]) | Should -BeTrue
        @($call.RequiredExternalReplicaKind) | Should -Be @('Primary')
        [object]::ReferenceEquals($call.ExternalDurabilityOverride, $script:durabilityOverride) | Should -BeTrue
      }
    }

    It 'does not invent an override when none is supplied' {
      $script:lifecycleCalls = [System.Collections.Generic.List[hashtable]]::new()
      Mock Invoke-SprintEndLifecycle {
        $script:lifecycleCalls.Add(@{} + $PesterBoundParameters)
        [PSCustomObject]@{
          Ok = $true; DryRun = $true
          Phases = [PSCustomObject]@{ ClosePlan = @(); FinalBoundary = [PSCustomObject]@{ Skipped = $true } }
          Failures = @(); DatabaseCleanupMode = 'SprintDatabasesOnly'
          BitwardenSecretsRemoved = $false; SqlInstancesRetained = $true
          SyntheticTaskCompleted = $false; StableWorktreeWritesPlanned = @()
          OperatorPromptsRequired = @()
        }
      }

      $null = Invoke-SprintEndRehearsal @script:rehearsalParameters -SkipEvidence -ExternalDurabilityEvidence $script:durabilityEvidence

      $script:lifecycleCalls.Count | Should -Be 2
      foreach ($call in $script:lifecycleCalls) {
        $call.ContainsKey('ExternalDurabilityOverride') | Should -BeFalse
        @($call.RequiredExternalReplicaKind) | Should -Be @('Primary', 'DropboxMirror')
      }
    }

    It 'passes CheckpointCoverage end to end when valid evidence is supplied' {
      $result = Invoke-SprintEndRehearsal @script:rehearsalParameters -SkipEvidence -ExternalDurabilityEvidence $script:durabilityEvidence

      $result.Ok | Should -BeTrue
      $result.Failures | Should -Not -Contain 'CheckpointCoverage'
      $result.Failures | Should -Not -Contain 'CheckpointCoverageRequiredForBoundary'
      $result.Failures | Should -Not -Contain 'ExternalDurabilityRequiredForTeardown'
      $dryRun = @($result.Scenarios | Where-Object Scenario -eq 'DryRun')[0]
      $dryRun.Result.Phases.CheckpointCoverage.Ok | Should -BeTrue
      Should -Invoke Test-SprintCheckpointCoverage -Times 2 -Exactly -ParameterFilter { @($ExternalDurabilityEvidence).Count -eq 2 }
      Should -Invoke Test-SprintEndBoundaryState -Times 0
    }

    It 'fails closed when no durability evidence is supplied' {
      $result = Invoke-SprintEndRehearsal @script:rehearsalParameters -SkipEvidence

      $result.Ok | Should -BeFalse
      $result.Failures | Should -Contain 'CheckpointCoverage'
      $result.Failures | Should -Contain 'CheckpointCoverageRequiredForBoundary'
      $result.Failures | Should -Contain 'ExternalDurabilityRequiredForTeardown'
      Should -Invoke Test-SprintEndBoundaryState -Times 0
    }

    It 'still fails closed and throws under ThrowOnFailure when evidence is missing' {
      { Invoke-SprintEndRehearsal @script:rehearsalParameters -SkipEvidence -ThrowOnFailure } |
        Should -Throw '*CheckpointCoverage*'
    }
  }

  Context 'Evidence' {
    It 'writes rehearsal evidence under a repository _generated folder by default' {
      $result = Invoke-SprintEndRehearsal @script:rehearsalParameters

      $result.EvidencePath | Should -Not -BeNullOrEmpty
      Test-Path -LiteralPath $result.EvidencePath | Should -BeTrue
      $result.EvidencePath | Should -Match '_generated'
      $result.EvidencePath | Should -BeLike "$script:planning*"

      $evidence = Get-Content -Raw -LiteralPath $result.EvidencePath | ConvertFrom-Json
      $evidence.Ok | Should -BeTrue
      @($evidence.Scenarios.Scenario) | Should -Contain 'CrashResume'
    }

    It 'honours an explicit evidence root' {
      $evidenceRoot = Join-Path $TestDrive 'explicit-evidence'

      $result = Invoke-SprintEndRehearsal @script:rehearsalParameters -EvidenceRoot $evidenceRoot

      $result.EvidencePath | Should -Be (Join-Path $evidenceRoot 'SprintEnd-Rehearsal.json')
      Test-Path -LiteralPath $result.EvidencePath | Should -BeTrue
    }

    It 'throws with the failure list when ThrowOnFailure is supplied' {
      {
        Invoke-SprintEndRehearsal `
          -GitRoot $script:gitRoot -PlanningRoot $script:planning `
          -SharedVSCodeWorktreePath $script:shared `
          -WorktreePaths @((Join-Path $script:gitRoot 'ATAP.Utilities')) `
          -SkipEvidence -ThrowOnFailure
      } | Should -Throw '*StableBoundary*'
    }
  }
}

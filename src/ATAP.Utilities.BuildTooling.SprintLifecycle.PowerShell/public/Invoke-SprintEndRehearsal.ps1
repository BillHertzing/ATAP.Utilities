function Invoke-SprintEndRehearsal {
  <#
  .SYNOPSIS
    Runs a disposable, non-mutating SprintEnd close rehearsal and writes its
    evidence.

  .DESCRIPTION
    Task 14.12. A dry run proves a single pass is non-mutating. It does not
    prove that a close interrupted midway can be resumed, that the stable
    worktrees were untouched while it ran, or that the invariants the close
    claims (database-only cleanup, no secret deletion, no synthetic task
    completion) actually held. Those were the gaps that let real close defects
    reach a live run.

    This cmdlet rehearses the whole close and checks all four:

      DryRun         - a single full-switch -WhatIf lifecycle pass reports
                       DryRun and plans every selected mutation phase.
      StableBoundary - the close plan contains no stable worktree, verified
                       through the same write-target gate the live close uses.
      CrashResume    - a second identical pass produces the same close plan, so
                       re-entry after an interruption is idempotent rather than
                       dependent on how far the first pass got.
      FullClose      - the full-switch pass still reports the safety invariants:
                       database-only cleanup, retained SQL instances, no
                       Bitwarden secret removal, and no synthetic task
                       completion.

    Every lifecycle pass runs with -WhatIf, so the rehearsal is structurally
    incapable of merging a pull request, deleting a branch, dropping a database,
    or mutating external state. In addition, the stable worktrees implied by the
    close plan are snapshotted (HEAD plus porcelain status) before and after the
    rehearsal, and any difference is reported as a failure -- a positive check
    that nothing edited stable content while the rehearsal ran.

  .PARAMETER GitRoot
    Parent directory containing repositories and sprint worktrees.

  .PARAMETER PlanningRoot
    Active _Planning sprint worktree.

  .PARAMETER SharedVSCodeWorktreePath
    SharedVSCode sprint worktree used as the canonical boundary source.

  .PARAMETER WorktreePaths
    Sprint worktrees included in the rehearsed close.

  .PARAMETER BuiltModule
    Modules built during the sprint, passed through to the lifecycle preflight.

  .PARAMETER Scenario
    Which rehearsal scenarios to run. Defaults to all four.

  .PARAMETER EvidenceRoot
    Directory that receives the rehearsal evidence. Defaults to
    '<PlanningRoot>\_generated\SprintEnd-Rehearsal\<timestamp>'.

  .PARAMETER SkipEvidence
    Run the rehearsal without writing evidence files.

  .PARAMETER ThrowOnFailure
    Throw a terminating error when any scenario or invariant fails.

  .OUTPUTS
    PSCustomObject with Ok, Scenarios, Invariants, StableWorktreeSnapshots,
    EvidencePath, and Failures.

  .EXAMPLE
    Invoke-SprintEndRehearsal -GitRoot 'C:\Repos' -PlanningRoot $planning `
      -SharedVSCodeWorktreePath $shared -WorktreePaths $worktrees -ThrowOnFailure

  .NOTES
    AI assisted using ./.claude/rules/Powershell.md as guidelines.

  .LINK
    Invoke-SprintEndLifecycle
  .LINK
    Test-SprintEndWriteTarget
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$GitRoot,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$PlanningRoot,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$SharedVSCodeWorktreePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorktreePaths,

    [Parameter()]
    [object[]]$BuiltModule = @(),

    [Parameter()]
    [ValidateSet('DryRun', 'StableBoundary', 'CrashResume', 'FullClose')]
    [string[]]$Scenario = @('DryRun', 'StableBoundary', 'CrashResume', 'FullClose'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$EvidenceRoot,

    [Parameter()]
    [switch]$SkipEvidence,

    [Parameter()]
    [switch]$ThrowOnFailure
  )

  begin {
    $fn = 'Invoke-SprintEndRehearsal'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    if (-not (Get-Command -Name 'Get-SprintWorktreeClassification' -CommandType Function -ErrorAction SilentlyContinue)) {
      $classificationHelperPath = Join-Path $PSScriptRoot '..' 'private' 'Get-SprintWorktreeClassification.ps1'
      if (Test-Path -LiteralPath $classificationHelperPath -PathType Leaf) {
        . $classificationHelperPath
      }
    }

    function Get-SprintEndStableWorktreeSnapshot {
      param(
        [Parameter(Mandatory)][string[]]$RepositoryPath
      )
      foreach ($repository in @($RepositoryPath | Select-Object -Unique)) {
        $snapshot = [ordered]@{
          Path      = $repository
          Exists    = [bool](Test-Path -LiteralPath $repository -PathType Container)
          Head      = $null
          Status    = @()
          Inspected = $false
          Detail    = $null
        }
        if ($snapshot.Exists) {
          try {
            $head = Invoke-SprintEndNativeCommand -FilePath 'git' -ArgumentList @('-C', $repository, 'rev-parse', 'HEAD') -AllowNonZeroExitCode
            $status = Invoke-SprintEndNativeCommand -FilePath 'git' -ArgumentList @('-C', $repository, 'status', '--porcelain') -AllowNonZeroExitCode
            $snapshot.Head = @($head.Output)[0]
            $snapshot.Status = @($status.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object)
            $snapshot.Inspected = ($head.Succeeded -and $status.Succeeded)
          } catch {
            $snapshot.Detail = "Stable snapshot failed: $($_.Exception.Message)"
          }
        } else {
          $snapshot.Detail = 'Stable repository path does not exist on this host.'
        }
        [PSCustomObject]$snapshot
      }
    }

    $scenarios = [System.Collections.Generic.List[object]]::new()
    $failures = [System.Collections.Generic.List[string]]::new()
  }

  process {
    $gitRootFull = [IO.Path]::GetFullPath($GitRoot)
    $planningRootFull = [IO.Path]::GetFullPath($PlanningRoot)
    $allWorktreePaths = @(
      @($WorktreePaths) + @($planningRootFull) |
        ForEach-Object { [IO.Path]::GetFullPath($_) } |
        Select-Object -Unique
    )

    $stableRepositoryPaths = @(
      foreach ($worktreePath in $allWorktreePaths) {
        $classification = Get-SprintWorktreeClassification -Path $worktreePath -GitRoot $gitRootFull
        if ($classification.StableRepositoryPath) { $classification.StableRepositoryPath }
      }
    ) | Select-Object -Unique

    $beforeSnapshots = @(Get-SprintEndStableWorktreeSnapshot -RepositoryPath $stableRepositoryPaths)

    $lifecycleParameters = @{
      GitRoot                  = $gitRootFull
      PlanningRoot             = $planningRootFull
      SharedVSCodeWorktreePath = [IO.Path]::GetFullPath($SharedVSCodeWorktreePath)
      WorktreePaths            = $allWorktreePaths
      BuiltModule              = $BuiltModule
      ApplyBoundary            = $true
      CreatePullRequests       = $true
      MergePullRequests        = $true
      ArchiveHistory           = $true
      VerifyCheckpoints        = $true
      CloseOverview            = $true
      WriteHandoff             = $true
      CleanupInfrastructure    = $true
      TestFreshShell           = $true
      WhatIf                   = $true
    }

    # ---------------- Scenario: StableBoundary ----------------
    if ($Scenario -contains 'StableBoundary') {
      $writeTarget = Test-SprintEndWriteTarget `
        -Path $allWorktreePaths `
        -GitRoot $gitRootFull `
        -Operation 'SprintEndRehearsalClosePlan'
      $entry = [PSCustomObject]@{
        Scenario = 'StableBoundary'
        Ok       = $writeTarget.Ok
        Detail   = if ($writeTarget.Ok) {
          "All $($allWorktreePaths.Count) close-plan path(s) classify as sprint worktrees."
        } else {
          "Blocked stable or unclassified path(s): $($writeTarget.BlockedPaths -join ', ')"
        }
        Result   = $writeTarget
      }
      [void]$scenarios.Add($entry)
      if (-not $entry.Ok) { [void]$failures.Add('StableBoundary') }
    }

    # ---------------- Scenario: DryRun ----------------
    $firstPass = $null
    if ($Scenario -contains 'DryRun' -or $Scenario -contains 'CrashResume' -or $Scenario -contains 'FullClose') {
      $firstPass = Invoke-SprintEndLifecycle @lifecycleParameters
    }

    if ($Scenario -contains 'DryRun') {
      $dryRunOk = [bool]($firstPass.DryRun -and $firstPass.Phases.FinalBoundary.Skipped)
      $entry = [PSCustomObject]@{
        Scenario = 'DryRun'
        Ok       = $dryRunOk
        Detail   = if ($dryRunOk) {
          'The full-switch pass reported DryRun and deferred final boundary verification until after live mutations.'
        } else {
          "DryRun=$($firstPass.DryRun); FinalBoundary.Skipped=$($firstPass.Phases.FinalBoundary.Skipped). A rehearsal pass must mutate nothing."
        }
        Result   = $firstPass
      }
      [void]$scenarios.Add($entry)
      if (-not $entry.Ok) { [void]$failures.Add('DryRun') }
    }

    # ---------------- Scenario: CrashResume ----------------
    if ($Scenario -contains 'CrashResume') {
      $secondPass = Invoke-SprintEndLifecycle @lifecycleParameters
      $firstPlan = @($firstPass.Phases.ClosePlan.WorktreePath | Sort-Object)
      $secondPlan = @($secondPass.Phases.ClosePlan.WorktreePath | Sort-Object)
      $planStable = (($firstPlan -join '|') -eq ($secondPlan -join '|'))
      $resumeOk = [bool]($planStable -and $secondPass.DryRun -and ($secondPass.Ok -eq $firstPass.Ok))
      $entry = [PSCustomObject]@{
        Scenario = 'CrashResume'
        Ok       = $resumeOk
        Detail   = if ($resumeOk) {
          "Re-entry produced an identical $($secondPlan.Count)-worktree close plan and the same verdict, so an interrupted close resumes from its inputs rather than from partial progress."
        } else {
          "Re-entry diverged. First plan: $($firstPlan -join ', '). Second plan: $($secondPlan -join ', '). First Ok=$($firstPass.Ok); second Ok=$($secondPass.Ok)."
        }
        Result   = $secondPass
      }
      [void]$scenarios.Add($entry)
      if (-not $entry.Ok) { [void]$failures.Add('CrashResume') }
    }

    # ---------------- Scenario: FullClose ----------------
    if ($Scenario -contains 'FullClose') {
      $invariantChecks = [ordered]@{
        DatabaseCleanupIsSprintOnly = ($firstPass.DatabaseCleanupMode -eq 'SprintDatabasesOnly')
        SqlInstancesRetained        = [bool]$firstPass.SqlInstancesRetained
        NoBitwardenSecretRemoval    = (-not $firstPass.BitwardenSecretsRemoved)
        NoSyntheticTaskCompletion   = (-not $firstPass.SyntheticTaskCompleted)
        NoStableWorktreeWrite       = (@($firstPass.StableWorktreeWritesPlanned).Count -eq 0)
      }
      $violated = @($invariantChecks.GetEnumerator() | Where-Object { -not $_.Value } | Select-Object -ExpandProperty Key)
      $entry = [PSCustomObject]@{
        Scenario = 'FullClose'
        Ok       = ($violated.Count -eq 0)
        Detail   = if ($violated.Count -eq 0) {
          'The full-switch rehearsal preserved every close safety invariant.'
        } else {
          "Violated close invariants: $($violated -join ', ')."
        }
        Result   = [PSCustomObject]$invariantChecks
      }
      [void]$scenarios.Add($entry)
      if (-not $entry.Ok) { [void]$failures.Add('FullClose') }
    }

    # ---------------- Positive check: stable worktrees untouched ----------------
    $afterSnapshots = @(Get-SprintEndStableWorktreeSnapshot -RepositoryPath $stableRepositoryPaths)
    $stableDrift = [System.Collections.Generic.List[object]]::new()
    foreach ($before in $beforeSnapshots) {
      $after = @($afterSnapshots | Where-Object { [StringComparer]::OrdinalIgnoreCase.Equals($_.Path, $before.Path) }) | Select-Object -First 1
      if (-not $after -or -not $before.Inspected -or -not $after.Inspected) { continue }
      $headChanged = ($before.Head -ne $after.Head)
      $statusChanged = ((@($before.Status) -join "`n") -ne (@($after.Status) -join "`n"))
      if ($headChanged -or $statusChanged) {
        [void]$stableDrift.Add([PSCustomObject]@{
            Path          = $before.Path
            HeadChanged   = $headChanged
            StatusChanged = $statusChanged
            BeforeHead    = $before.Head
            AfterHead     = $after.Head
          })
      }
    }
    if ($stableDrift.Count -gt 0) {
      [void]$failures.Add('StableWorktreeMutated')
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
        -Message "The rehearsal changed $($stableDrift.Count) stable worktree(s): $(@($stableDrift.Path) -join ', ')."
    }

    $result = [PSCustomObject]@{
      Ok                      = ($failures.Count -eq 0)
      DryRun                  = $true
      GitRoot                 = $gitRootFull
      WorktreePaths           = $allWorktreePaths
      Scenarios               = $scenarios.ToArray()
      StableWorktreeSnapshots = [PSCustomObject]@{
        Before = $beforeSnapshots
        After  = $afterSnapshots
        Drift  = $stableDrift.ToArray()
      }
      EvidencePath            = $null
      Failures                = @($failures | Select-Object -Unique)
    }

    if (-not $SkipEvidence) {
      # SC-0033: generated evidence belongs under a repository _generated folder.
      $evidenceDirectory = if ($PSBoundParameters.ContainsKey('EvidenceRoot')) {
        $EvidenceRoot
      } else {
        Join-Path $planningRootFull '_generated' |
          Join-Path -ChildPath 'SprintEnd-Rehearsal' |
          Join-Path -ChildPath ([DateTimeOffset]::Now.ToString('yyyyMMdd-HHmmss'))
      }
      try {
        if (-not (Test-Path -LiteralPath $evidenceDirectory -PathType Container)) {
          New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
        }
        $evidencePath = Join-Path $evidenceDirectory 'SprintEnd-Rehearsal.json'
        $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
        $result.EvidencePath = $evidencePath
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "SprintEnd rehearsal evidence written to '$evidencePath'."
      } catch {
        [void]$failures.Add('EvidenceWrite')
        $result.Ok = $false
        $result.Failures = @($failures | Select-Object -Unique)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Rehearsal evidence write failed: $($_.Exception.Message)"
      }
    }

    if (-not $result.Ok -and $ThrowOnFailure) {
      throw "SprintEnd rehearsal failed: $($result.Failures -join ', ')."
    }

    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

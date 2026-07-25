function Save-SprintRetrospectiveSnapshot {
  <#
  .SYNOPSIS
    Captures a point-in-time retrospective snapshot of a sprint and writes a
    structured JSON record to `_Planning/SprintRetrospective/Snapshots/<NNNN>/`.
  .DESCRIPTION
    Called from SprintEndAgent during the retrospective step. Gathers the
    sprint-close metrics the retrospective notebook relies on and emits both
    an on-disk JSON artifact and a structured PSCustomObject. Use it alongside
    the closing sprint task artifact set in `_Planning` — active board
    (`TASKS.html` or highest `TASKS_V*.html`), `Tasks.Accomplished.html`, and
    `Tasks.ProceduralDetails.html`; this snapshot supplements those files, not
    replaces them:

      - Merged-PR count for the sprint window across the configured worktree set.
      - Package promotions recorded in `_generated/audit/` (Promote-ProGetPackage
        and related ceiling-promotion cmdlets append one entry per promotion).
      - Pester / xUnit test statistics aggregated from `.trx` and Pester result
        XML files under `_generated/`.
      - Elapsed sprint duration (start timestamp -> snapshot timestamp).
      - Notable infrastructure changes summarised from commits touching paths
        under `Build/`, `Database/`, `src/ATAP.Utilities.BuildTooling.*/`,
        `src/ATAP.Utilities.DatabaseManagement.*/`, and any `*.ps1` file under
        `_Planning/Powershell/Public/` during the sprint window.
      - Optional interactive developer impressions captured via Read-Host when
        `-Interactive` is set (or a non-interactive caller supplies
        `-Impressions <string>`).

    The function is read-only against every repository worktree except for the
    snapshot file it writes under the supplied `-PlanningRoot`. ShouldProcess
    guards the disk write; `-WhatIf` produces the in-memory object without
    persisting it.

    Worktree discovery mirrors `Clear-SprintGeneratedArtifacts`: direct
    children of `-GitRoot` whose names match
    `*-wt-*-sprint-<SprintNumber>-work-items`.

    Idempotent: re-running on the same sprint number produces a new snapshot
    file whose name includes a UTC timestamp, so prior snapshots are never
    overwritten. The returned object's `snapshotPath` always points at the
    file that was (or would have been) written by this invocation.
  .PARAMETER SprintNumber
    Four-digit zero-padded sprint number (e.g. '0007'). Required.
  .PARAMETER SprintStart
    UTC timestamp marking the start of the sprint. Used to compute elapsed
    duration and to bound the git/promotion/test-result window. When omitted,
    defaults to the earliest commit-author date on a sprint branch (matching
    `^\d+-sprint-<SprintNumber>-.+$`) across the discovered worktrees, falling
    back to (Get-Date).AddDays(-14).
  .PARAMETER GitRoot
    Root directory that contains all worktree folders.
    Defaults to 'C:\Dropbox\whertzing\GitHub'.
  .PARAMETER PlanningRoot
    Root directory of the `_Planning` repo (or its sprint worktree). The
    snapshot file is written under
    `<PlanningRoot>\SprintRetrospective\Snapshots\<SprintNumber>\`.
    Defaults to the first sibling of `-GitRoot` matching
    `^_Planning-wt-\d+-sprint-<SprintNumber>`, falling back to
    `<GitRoot>\_Planning`.
  .PARAMETER Interactive
    When set, prompts via Read-Host for one or more developer impressions and
    records them in the snapshot. Ignored when `-Impressions` is also supplied.
  .PARAMETER Impressions
    Pre-supplied developer impressions. Useful for agent/pipeline invocations
    that cannot prompt interactively.
  .OUTPUTS
    [PSCustomObject] with fields:
      sprintNumber          [string]   — sprint passed in
      snapshotPath          [string]   — absolute path of the JSON artifact
      capturedAtUtc         [datetime] — snapshot timestamp (UTC)
      sprintStartUtc        [datetime] — sprint start used for duration
      elapsedDays           [double]   — (capturedAtUtc - sprintStartUtc).TotalDays
      workTreesScanned      [int]      — count of matching worktrees
      prCount               [int]      — merged PRs in sprint window
      packagePromotions     [object[]] — one entry per recorded promotion
      packagePromotionCount [int]      — total promotion entries
      testStats             [object]   — { totalTests, passed, failed, skipped, resultFiles }
      infraChangeSummaries  [string[]] — short subject lines from sprint commits
        whose touched paths intersect the infra path set
      infraChangeCount      [int]      — count of infra-relevant commits
      impressions           [string[]] — captured developer impressions (may be empty)
      errors                [string[]] — non-fatal collection errors
  .EXAMPLE
    Save-SprintRetrospectiveSnapshot -SprintNumber '0007'
    # Reads sprint metrics, writes a timestamped JSON snapshot, returns the object.
  .EXAMPLE
    Save-SprintRetrospectiveSnapshot -SprintNumber '0007' -WhatIf
    # Computes and returns the snapshot object without writing anything to disk.
  .EXAMPLE
    $snap = Save-SprintRetrospectiveSnapshot -SprintNumber '0007' `
      -Impressions @('Smoother package promotion','Flyway re-import still flaky')
    $snap.snapshotPath
  .NOTES
    Called from SprintEndAgent retrospective step.
    AI assisted using ./claude/Rules/Powershell.md as guidelines.
  .LINK
    Clear-SprintGeneratedArtifacts
  .LINK
    Save-SprintWorkSession
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{4}$')]
    [string]$SprintNumber,

    [Parameter(Mandatory = $false)]
    [Nullable[datetime]]$SprintStart,

    [Parameter(Mandatory = $false)]
    [string]$GitRoot = 'C:\Dropbox\whertzing\GitHub',

    [Parameter(Mandatory = $false)]
    [string]$PlanningRoot,

    [Parameter(Mandatory = $false)]
    [switch]$Interactive,

    [Parameter(Mandatory = $false)]
    [string[]]$Impressions
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    if (-not (Test-Path -LiteralPath $GitRoot -PathType Container)) {
      $msg = "GitRoot '$GitRoot' does not exist or is not a directory."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    if ([string]::IsNullOrWhiteSpace($PlanningRoot)) {
      $planningCandidates = @(Get-ChildItem -LiteralPath $GitRoot -Directory -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -match "^_Planning-wt-\d+-sprint-$SprintNumber" })
      if ($planningCandidates.Count -ge 1) {
        $PlanningRoot = $planningCandidates[0].FullName
      } else {
        $PlanningRoot = Join-Path $GitRoot '_Planning'
      }
    }

    # NOTE: snapshot output path under _Planning per SC-0033 (`_generated/` is for
    # transient build artifacts; SprintRetrospective is a permanent historical
    # record - see Clear-SprintGeneratedArtifacts notes).
    $snapshotDir = Join-Path $PlanningRoot 'SprintRetrospective' 'Snapshots' $SprintNumber
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $snapshotPath = Join-Path $snapshotDir "SprintRetrospectiveSnapshot-$SprintNumber-$stamp.json"

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Sprint=$SprintNumber GitRoot=$GitRoot PlanningRoot=$PlanningRoot Snapshot=$snapshotPath"
  }

  process {
    $errors = [System.Collections.Generic.List[string]]::new()
    $capturedAtUtc = (Get-Date).ToUniversalTime()

    # ── 1. Discover sprint worktrees ───────────────────────────────────────
    $workTreePattern = "*-wt-*-sprint-$SprintNumber-work-items"
    $workTrees = @(Get-ChildItem -LiteralPath $GitRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like $workTreePattern })

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Found $($workTrees.Count) sprint worktrees for sprint $SprintNumber"

    # ── 2. Resolve sprint start (auto-detect if not supplied) ─────────────
    $resolvedStart = $null
    if ($PSBoundParameters.ContainsKey('SprintStart') -and $null -ne $SprintStart) {
      $resolvedStart = ([datetime]$SprintStart).ToUniversalTime()
    } else {
      foreach ($wt in $workTrees) {
        try {
          $firstCommitIso = & git -C $wt.FullName log --reverse --format='%aI' --all `
            --grep="sprint-$SprintNumber" 2>$null | Select-Object -First 1
          if ([string]::IsNullOrWhiteSpace($firstCommitIso)) {
            $firstCommitIso = & git -C $wt.FullName log --reverse --format='%aI' 2>$null | Select-Object -First 1
          }
          if (-not [string]::IsNullOrWhiteSpace($firstCommitIso)) {
            $dt = [datetime]::Parse($firstCommitIso).ToUniversalTime()
            if ($null -eq $resolvedStart -or $dt -lt $resolvedStart) { $resolvedStart = $dt }
          }
        } catch {
          [void]$errors.Add("git-start-detect failed for $($wt.Name): $($_.Exception.Message)")
        }
      }
      if ($null -eq $resolvedStart) {
        $resolvedStart = $capturedAtUtc.AddDays(-14)
      }
    }
    $elapsedDays = [math]::Round(($capturedAtUtc - $resolvedStart).TotalDays, 3)
    $sinceArg = $resolvedStart.ToString('yyyy-MM-ddTHH:mm:ssZ')

    # ── 3. Merged PR count ─────────────────────────────────────────────────
    $prCount = 0
    foreach ($wt in $workTrees) {
      try {
        $merges = & git -C $wt.FullName log --merges --since="$sinceArg" --pretty=oneline 2>$null
        if ($null -ne $merges) {
          $prCount += @($merges).Count
        }
      } catch {
        [void]$errors.Add("pr-count failed for $($wt.Name): $($_.Exception.Message)")
      }
    }

    # ── 4. Package promotions ──────────────────────────────────────────────
    $promotionEntries = [System.Collections.Generic.List[object]]::new()
    foreach ($wt in $workTrees) {
      $auditDir = Join-Path $wt.FullName '_generated' 'audit'
      if (-not (Test-Path -LiteralPath $auditDir -PathType Container)) { continue }
      try {
        $promoFiles = @(Get-ChildItem -LiteralPath $auditDir -Filter 'promotion-*.json' `
            -Recurse -ErrorAction SilentlyContinue)
        foreach ($pf in $promoFiles) {
          if ($pf.LastWriteTimeUtc -lt $resolvedStart) { continue }
          try {
            $obj = Get-Content -LiteralPath $pf.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
            [void]$promotionEntries.Add($obj)
          } catch {
            [void]$errors.Add("promotion parse failed: $($pf.FullName) - $($_.Exception.Message)")
          }
        }
      } catch {
        [void]$errors.Add("promotion scan failed for $($wt.Name): $($_.Exception.Message)")
      }
    }

    # ── 5. Test stats from .trx and Pester XML ─────────────────────────────
    $totalTests = 0; $passed = 0; $failed = 0; $skipped = 0; $resultFiles = 0
    foreach ($wt in $workTrees) {
      $genDir = Join-Path $wt.FullName '_generated'
      if (-not (Test-Path -LiteralPath $genDir -PathType Container)) { continue }
      $resultCandidates = @(Get-ChildItem -LiteralPath $genDir -Recurse -ErrorAction SilentlyContinue `
          -Include '*.trx', 'pester-*.xml', 'TEST-*.xml', 'testResults.xml')
      foreach ($rf in $resultCandidates) {
        if ($rf.LastWriteTimeUtc -lt $resolvedStart) { continue }
        try {
          [xml]$doc = Get-Content -LiteralPath $rf.FullName -Raw
          $resultFiles++
          # .trx: <Counters total=.. passed=.. failed=.. ../>
          $counters = $doc.SelectSingleNode('//*[local-name()="Counters"]')
          if ($null -ne $counters) {
            if ($counters.Attributes['total']) { $totalTests += [int]$counters.Attributes['total'].Value }
            if ($counters.Attributes['passed']) { $passed += [int]$counters.Attributes['passed'].Value }
            if ($counters.Attributes['failed']) { $failed += [int]$counters.Attributes['failed'].Value }
            continue
          }
          # NUnit/Pester: <test-results total=.. failures=.. not-run=../>
          $tr = $doc.SelectSingleNode('//*[local-name()="test-results"]')
          if ($null -ne $tr) {
            if ($tr.Attributes['total']) { $totalTests += [int]$tr.Attributes['total'].Value }
            if ($tr.Attributes['failures']) { $failed += [int]$tr.Attributes['failures'].Value }
            if ($tr.Attributes['not-run']) { $skipped += [int]$tr.Attributes['not-run'].Value }
            continue
          }
          # JUnit/Pester5: <testsuites tests=.. failures=.. skipped=..>
          $ts = $doc.SelectSingleNode('//*[local-name()="testsuites"]')
          if ($null -ne $ts) {
            if ($ts.Attributes['tests']) { $totalTests += [int]$ts.Attributes['tests'].Value }
            if ($ts.Attributes['failures']) { $failed += [int]$ts.Attributes['failures'].Value }
            if ($ts.Attributes['skipped']) { $skipped += [int]$ts.Attributes['skipped'].Value }
          }
        } catch {
          [void]$errors.Add("test-result parse failed: $($rf.FullName) - $($_.Exception.Message)")
        }
      }
    }
    if ($passed -eq 0 -and $totalTests -gt 0) {
      $passed = [math]::Max(0, $totalTests - $failed - $skipped)
    }
    $testStats = [PSCustomObject]@{
      totalTests  = $totalTests
      passed      = $passed
      failed      = $failed
      skipped     = $skipped
      resultFiles = $resultFiles
    }

    # ── 6. Notable infrastructure changes (commit subjects) ────────────────
    $infraPathFilters = @(
      'Build/', 'Database/',
      'src/ATAP.Utilities.BuildTooling',
      'src/ATAP.Utilities.DatabaseManagement',
      '_Planning/Powershell/Public/'
    )
    $infraSubjects = [System.Collections.Generic.List[string]]::new()
    foreach ($wt in $workTrees) {
      try {
        $rawLog = & git -C $wt.FullName log --since="$sinceArg" --pretty=format:'%H%x09%s' --name-only 2>$null
        if ($null -eq $rawLog) { continue }
        $currentHash = $null; $currentSubject = $null; $matched = $false
        foreach ($line in @($rawLog)) {
          if ($line -match '^[0-9a-f]{40}\t(.*)$') {
            if ($null -ne $currentHash -and $matched) {
              [void]$infraSubjects.Add($currentSubject)
            }
            $currentHash = ($line -split '\t', 2)[0]
            $currentSubject = $Matches[1]
            $matched = $false
          } elseif (-not [string]::IsNullOrWhiteSpace($line)) {
            foreach ($pat in $infraPathFilters) {
              if ($line -like "*$pat*") { $matched = $true; break }
            }
          }
        }
        if ($null -ne $currentHash -and $matched) {
          [void]$infraSubjects.Add($currentSubject)
        }
      } catch {
        [void]$errors.Add("infra-scan failed for $($wt.Name): $($_.Exception.Message)")
      }
    }
    $infraUnique = @($infraSubjects | Select-Object -Unique)

    # ── 7. Developer impressions ───────────────────────────────────────────
    $capturedImpressions = @()
    if ($PSBoundParameters.ContainsKey('Impressions') -and $null -ne $Impressions -and $Impressions.Count -gt 0) {
      $capturedImpressions = @($Impressions | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    } elseif ($Interactive) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Enter developer impressions for sprint $SprintNumber - blank line ends input."
      while ($true) {
        $line = Read-Host -Prompt 'Impression'
        if ([string]::IsNullOrWhiteSpace($line)) { break }
        $capturedImpressions += $line
      }
    }

    # ── 8. Assemble structured result ──────────────────────────────────────
    $result = [PSCustomObject]@{
      sprintNumber          = $SprintNumber
      snapshotPath          = $snapshotPath
      capturedAtUtc         = $capturedAtUtc
      sprintStartUtc        = $resolvedStart
      elapsedDays           = $elapsedDays
      workTreesScanned      = $workTrees.Count
      prCount               = $prCount
      packagePromotions     = $promotionEntries.ToArray()
      packagePromotionCount = $promotionEntries.Count
      testStats             = $testStats
      infraChangeSummaries  = $infraUnique
      infraChangeCount      = $infraUnique.Count
      impressions           = $capturedImpressions
      errors                = $errors.ToArray()
    }

    # ── 9. Persist JSON (ShouldProcess-guarded) ────────────────────────────
    if ($PSCmdlet.ShouldProcess($snapshotPath, 'Write sprint retrospective snapshot JSON')) {
      try {
        if (-not (Test-Path -LiteralPath $snapshotDir -PathType Container)) {
          New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
        }
        $json = $result | ConvertTo-Json -Depth 8
        Set-Content -LiteralPath $snapshotPath -Value $json -Encoding UTF8
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Sprint retrospective snapshot written: $snapshotPath"
      } catch {
        $msg = "Failed to write snapshot file '$snapshotPath': $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        [void]$errors.Add($msg)
        $result.errors = $errors.ToArray()
      }
    }

    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}

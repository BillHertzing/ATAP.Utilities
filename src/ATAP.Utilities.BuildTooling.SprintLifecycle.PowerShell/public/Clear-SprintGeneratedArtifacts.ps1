function Clear-SprintGeneratedArtifacts {
  <#
  .SYNOPSIS
    Deletes the contents of the `_generated/` folder in every sprint worktree
    for the specified sprint number.
  .DESCRIPTION
    At sprint close, each repository worktree for the given sprint contains a
    `_generated/` directory that holds transient build artifacts and
    point-in-time evidence (R-38, SC-0033). Invoke-SprintEndLifecycle
    -ClearGeneratedArtifacts calls this cmdlet before any pull request is
    created or merged (Task 16.91.a, SC-0470).

    `_generated/` is `.gitignore`-listed in every repo and must never reach a
    stable branch. Evidence that must outlive the sprint belongs under
    `_Planning/InformationForTheFuture/` (R-38).

    Protected-evidence guard (fails closed): before removing anything this
    cmdlet runs Get-SprintGeneratedArtifactState over the selected worktrees.
    It removes nothing, and returns `blocked = $true` with the findings, when
    any `_generated/` file is tracked by git, or when a sprint board or an
    `InformationForTheFuture` document cites a `_generated/` path that exists.
    Relocate the cited evidence (or untrack the files) and run again.

    What is NOT deleted:
      - The `_generated/` directory itself (just the contents are removed).
      - Files outside `_generated/` (source code, committed assets, etc.).
      - `_Planning\SprintRetrospective\WorkspaceArchive\` — these are permanent
        historical records, not transient build outputs (see SprintEndAgent
        Step 10b.2).

    Worktree discovery:
      When -WorktreePaths is supplied, exactly those worktrees are used; each
      must be named `*-wt-<n>-Sprint-<SprintNumber>-work-items`, so a stable
      worktree is never cleared. Otherwise the cmdlet searches `$GitRoot` for
      directories whose names match the pattern
      `*-wt-*-sprint-<SprintNumber>-work-items`.  Only direct children of
      `$GitRoot` are examined (one level deep).

    Idempotent:  safe to call multiple times; already-absent directories are
    silently skipped.

    ConfirmImpact is Medium because the guard keeps cited or tracked content
    out of reach.  Pass -Force to suppress the confirmation prompt in
    agent/pipeline invocations.
  .PARAMETER SprintNumber
    Four-digit zero-padded sprint number (e.g. '0006').  Used to locate the
    matching set of workTrees under $GitRoot.
  .PARAMETER GitRoot
    Root directory that contains all worktree folders.
    Defaults to 'C:\Dropbox\whertzing\GitHub'.
  .PARAMETER WorktreePaths
    Optional explicit sprint worktrees to clear (the SprintEnd close set).
  .PARAMETER PlanningRoot
    _Planning sprint worktree whose boards and InformationForTheFuture are
    scanned for citations. Defaults to the single
    `_Planning-wt-*-Sprint-<SprintNumber>-work-items` folder under $GitRoot;
    the cmdlet throws when it cannot be resolved.
  .PARAMETER Force
    Bypasses the Medium-impact confirmation prompt.  Use for agent/pipeline
    invocations.
  .OUTPUTS
    [PSCustomObject] with fields:
      sprintNumber          [string]   — sprint passed in
      workTreesScanned      [int]      — total sprint workTrees found
      workTreesWithGenerated [int]     — workTrees that had a _generated/ dir
      filesRemoved          [int]      — total file count deleted
      directoriesRemoved    [int]      — total sub-directory count deleted
      errors                [string[]] — per-item error messages (empty if clean)
      blocked               [bool]     — true when the guard refused to clear
      generatedArtifactState [object]  — Get-SprintGeneratedArtifactState result
  .EXAMPLE
    Clear-SprintGeneratedArtifacts -SprintNumber '0006' -WhatIf
    # Lists what would be deleted without removing anything.
  .EXAMPLE
    $result = Clear-SprintGeneratedArtifacts -SprintNumber '0006' -Force
    $result | Format-List
  .EXAMPLE
    Clear-SprintGeneratedArtifacts -SprintNumber '0006' -GitRoot 'D:\Repos' -Force
  .NOTES
    Called from Invoke-SprintEndLifecycle -ClearGeneratedArtifacts (pre-merge).
    AI assisted using ./claude/Rules/Powershell.md as guidelines.
  .LINK
    New-SprintBitwardenSecrets
  .LINK
    Remove-SprintBitwardenSecrets
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{4}$')]
    [string]$SprintNumber,

    [Parameter(Mandatory = $false)]
    [string]$GitRoot = 'C:\Dropbox\whertzing\GitHub',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorktreePaths,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanningRoot,

    [Parameter(Mandatory = $false)]
    [switch]$Force
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Clearing _generated/ artifacts for sprint $SprintNumber under '$GitRoot'"

    if (-not (Test-Path -LiteralPath $GitRoot -PathType Container)) {
      $msg = "GitRoot '$GitRoot' does not exist or is not a directory."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    if ($Force -and -not $WhatIfPreference) {
      $ConfirmPreference = 'None'
    }

    if (-not (Get-Command -Name 'Get-SprintGeneratedArtifactState' -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '..\private\Get-SprintGeneratedArtifactState.ps1')
    }
  }

  process {
    $worktreePattern = "*-wt-*-sprint-$SprintNumber-work-items"
    if ($PSBoundParameters.ContainsKey('WorktreePaths')) {
      $workTrees = foreach ($worktreePath in $WorktreePaths) {
        $leaf = Split-Path -Path ([IO.Path]::GetFullPath($worktreePath)) -Leaf
        if ($leaf -notmatch "(?i)-wt-\d+-Sprint-$SprintNumber-work-items$") {
          $msg = "'$worktreePath' is not a Sprint $SprintNumber worktree; refusing to clear its _generated/."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
          throw $msg
        }
        if (Test-Path -LiteralPath $worktreePath -PathType Container) { Get-Item -LiteralPath $worktreePath }
      }
      $workTrees = @($workTrees)
    } else {
      $workTrees = @(Get-ChildItem -LiteralPath $GitRoot -Directory -Filter $worktreePattern)
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Found $($workTrees.Count) worktree(s) matching '$worktreePattern'"

    if (-not $PSBoundParameters.ContainsKey('PlanningRoot')) {
      $planningCandidates = @(Get-ChildItem -LiteralPath $GitRoot -Directory -Filter "_Planning-wt-*-Sprint-$SprintNumber-work-items")
      if ($planningCandidates.Count -ne 1) {
        $msg = "Expected exactly one _Planning Sprint $SprintNumber worktree under '$GitRoot' (found $($planningCandidates.Count)); pass -PlanningRoot."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }
      $PlanningRoot = $planningCandidates[0].FullName
    }

    $workTreesScanned = $workTrees.Count
    $workTreesWithGenerated = 0
    $filesRemoved = 0
    $directoriesRemoved = 0
    $errors = [System.Collections.Generic.List[string]]::new()

    # Task 16.91.a (SC-0470): tracked or cited _generated content blocks the
    # whole clear; nothing is removed from any worktree.
    $generatedArtifactState = $null
    if ($workTrees.Count -gt 0) {
      $generatedArtifactState = Get-SprintGeneratedArtifactState `
        -WorktreePaths @($workTrees.FullName) -PlanningRoot $PlanningRoot
      if (-not $generatedArtifactState.Ok) {
        $msg = "Refusing to clear _generated/: $($generatedArtifactState.Failures -join ', ') " +
          "($(@($generatedArtifactState.TrackedPaths).Count) tracked, $(@($generatedArtifactState.CitedPaths).Count) cited). " +
          'Relocate cited evidence to InformationForTheFuture (R-38) and untrack _generated files first.'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        $errors.Add($msg)
        return [PSCustomObject]@{
          sprintNumber           = $SprintNumber
          workTreesScanned       = $workTreesScanned
          workTreesWithGenerated = 0
          filesRemoved           = 0
          directoriesRemoved     = 0
          errors                 = $errors.ToArray()
          blocked                = $true
          generatedArtifactState = $generatedArtifactState
        }
      }
    }

    foreach ($wt in $workTrees) {
      $generatedPath = Join-Path -Path $wt.FullName -ChildPath '_generated'

      if (-not (Test-Path -LiteralPath $generatedPath -PathType Container)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
          -Message "No _generated/ found in '$($wt.Name)' — skipping"
        continue
      }

      $workTreesWithGenerated++

      # Enumerate all items directly under _generated/ (recursive deletion
      # via Remove-Item -Recurse on each top-level entry avoids the "directory
      # not empty" race condition on deeply-nested structures).
      $topLevelItems = Get-ChildItem -LiteralPath $generatedPath

      if ($topLevelItems.Count -eq 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
          -Message "'$($wt.Name)/_generated/' is already empty — skipping"
        continue
      }

      $target = "$($wt.Name)/_generated/ ($($topLevelItems.Count) item(s))"

      if (-not $PSCmdlet.ShouldProcess($target, 'Remove _generated/ contents')) {
        continue
      }

      foreach ($item in $topLevelItems) {
        try {
          if ($item.PSIsContainer) {
            # Count descendent files before removal so we can report accurately
            $descendentFiles = (Get-ChildItem -LiteralPath $item.FullName -Recurse -File).Count
            Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
            $filesRemoved += $descendentFiles
            $directoriesRemoved++
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
              -Message "Removed directory '$($item.FullName)' ($descendentFiles file(s))"
          } else {
            Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
            $filesRemoved++
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
              -Message "Removed file '$($item.FullName)'"
          }
        } catch {
          $errMsg = "Failed to remove '$($item.FullName)': $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
          $errors.Add($errMsg)
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Cleared _generated/ in '$($wt.Name)'"
    }

    [PSCustomObject]@{
      sprintNumber           = $SprintNumber
      workTreesScanned       = $workTreesScanned
      workTreesWithGenerated = $workTreesWithGenerated
      filesRemoved           = $filesRemoved
      directoriesRemoved     = $directoriesRemoved
      errors                 = $errors.ToArray()
      blocked                = $false
      generatedArtifactState = $generatedArtifactState
    }
  }
}

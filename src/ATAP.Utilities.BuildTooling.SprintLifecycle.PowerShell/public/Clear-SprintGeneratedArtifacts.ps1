function Clear-SprintGeneratedArtifacts {
  <#
  .SYNOPSIS
    Deletes the contents of the `_generated/` folder in every sprint worktree
    for the specified sprint number.
  .DESCRIPTION
    At sprint close (SprintEndAgent Step 10.7), each repository worktree for
    the given sprint contains a `_generated/` directory that holds transient
    build artifacts:  test-result XML files, PSScriptAnalyzer reports, compiled
    `.psm1` / `.psd1` manifests, compressed `.nupkg` / `.zip` packages, CI-hook
    scripts, and diagnostic one-off scripts.

    None of these files are committed to source control (`_generated/` is
    `.gitignore`-listed in every repo).  They can all be regenerated on demand
    by re-running the BuildTooling pipeline.  This cmdlet removes them to free
    disk space and prevent stale artifacts from polluting the next sprint.

    What is NOT deleted:
      - The `_generated/` directory itself (just the contents are removed).
      - Files outside `_generated/` (source code, committed assets, etc.).
      - `_Planning\SprintRetrospective\WorkspaceArchive\` — these are permanent
        historical records, not transient build outputs (see SprintEndAgent
        Step 10b.2).

    Worktree discovery:
      The cmdlet searches `$GitRoot` for directories whose names match the
      pattern  `*-wt-*-sprint-<SprintNumber>-work-items`.  Only direct children
      of `$GitRoot` are examined (one level deep).

    Idempotent:  safe to call multiple times; already-absent directories are
    silently skipped.

    ConfirmImpact is Medium because `_generated/` contents are always
    reproducible.  Pass -Force to suppress the confirmation prompt in
    agent/pipeline invocations.
  .PARAMETER SprintNumber
    Four-digit zero-padded sprint number (e.g. '0006').  Used to locate the
    matching set of workTrees under $GitRoot.
  .PARAMETER GitRoot
    Root directory that contains all worktree folders.
    Defaults to 'C:\Dropbox\whertzing\GitHub'.
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
  .EXAMPLE
    Clear-SprintGeneratedArtifacts -SprintNumber '0006' -WhatIf
    # Lists what would be deleted without removing anything.
  .EXAMPLE
    $result = Clear-SprintGeneratedArtifacts -SprintNumber '0006' -Force
    $result | Format-List
  .EXAMPLE
    Clear-SprintGeneratedArtifacts -SprintNumber '0006' -GitRoot 'D:\Repos' -Force
  .NOTES
    Called from SprintEndAgent Step 10.7.
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
  }

  process {
    $worktreePattern = "*-wt-*-sprint-$SprintNumber-work-items"
    $workTrees = Get-ChildItem -LiteralPath $GitRoot -Directory -Filter $worktreePattern

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Found $($workTrees.Count) worktree(s) matching '$worktreePattern'"

    $workTreesScanned = $workTrees.Count
    $workTreesWithGenerated = 0
    $filesRemoved = 0
    $directoriesRemoved = 0
    $errors = [System.Collections.Generic.List[string]]::new()

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
    }
  }
}

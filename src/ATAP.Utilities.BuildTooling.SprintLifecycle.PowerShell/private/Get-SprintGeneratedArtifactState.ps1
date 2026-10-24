function Get-SprintGeneratedArtifactState {
  <#
  .SYNOPSIS
  Reports tracked and cited `_generated/` content in sprint worktrees (SC-0470).

  .DESCRIPTION
  Read-only R-38 gate for SprintEnd. `_generated/` is ephemeral sprint output, so
  nothing under it may reach a stable branch, and nothing a planning artifact still
  cites may be cleared before it is relocated to InformationForTheFuture.

  Two findings fail the gate:

  - TrackedPaths: every path returned by `git ls-files -- _generated` in a selected
    worktree. Tracked `_generated/` files merge into the stable branch.
  - CitedPaths: every `_generated/...` path cited by a sprint board file
    (`Tasks.Sprint*` / `TASKS*` at the Planning root) or by a Markdown, HTML or
    JSON file under `InformationForTheFuture/`, when the cited path currently
    exists under a selected worktree's `_generated/`. Clearing would delete it.

  A citation whose text names a selected worktree folder is resolved only against
  that worktree; otherwise it is resolved against every selected worktree.
  Citations containing wildcards are not resolved. A worktree that git cannot
  list fails closed.

  .PARAMETER WorktreePaths
  Sprint worktrees to inspect.

  .PARAMETER PlanningRoot
  Active _Planning sprint worktree that holds the boards and InformationForTheFuture.

  .OUTPUTS
  PSCustomObject with Ok, TrackedPaths, CitedPaths and Failures.

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorktreePaths,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanningRoot
  )

  begin {
    $fn = 'Get-SprintGeneratedArtifactState'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
    if (-not (Get-Command -Name 'Invoke-SprintEndNativeCommand' -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot 'Invoke-SprintEndNativeCommand.ps1')
    }
  }

  process {
    $failures = [System.Collections.Generic.List[string]]::new()
    $trackedPaths = [System.Collections.Generic.List[object]]::new()
    $citedPaths = [System.Collections.Generic.List[object]]::new()
    $worktrees = @($WorktreePaths | ForEach-Object { [IO.Path]::GetFullPath($_) } | Select-Object -Unique)
    $planningRootFull = [IO.Path]::GetFullPath($PlanningRoot)

    foreach ($worktree in $worktrees) {
      try {
        $listResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
          -ArgumentList @('-C', $worktree, 'ls-files', '--', '_generated') -AllowNonZeroExitCode
        if (-not $listResult.Succeeded) { throw ($listResult.Output -join ' ') }
        foreach ($line in @($listResult.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
          [void]$trackedPaths.Add([PSCustomObject]@{ Worktree = $worktree; Path = $line.Trim() })
        }
      } catch {
        [void]$failures.Add("GitListFailed:$worktree")
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
          -Message "Could not list tracked _generated files in '$worktree': $($_.Exception.Message)"
      }
    }
    if ($trackedPaths.Count -gt 0) { [void]$failures.Add('TrackedGeneratedArtifacts') }

    $sourceFiles = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $planningRootFull -PathType Container) {
      foreach ($board in @(Get-ChildItem -LiteralPath $planningRootFull -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '(?i)^(?:Tasks\.Sprint|TASKS)' -and $_.Extension -match '(?i)^\.(?:md|html)$' })) {
        [void]$sourceFiles.Add($board.FullName)
      }
      $futureRoot = Join-Path $planningRootFull 'InformationForTheFuture'
      if (Test-Path -LiteralPath $futureRoot -PathType Container) {
        foreach ($doc in @(Get-ChildItem -LiteralPath $futureRoot -File -Recurse -ErrorAction SilentlyContinue |
              Where-Object { $_.Extension -match '(?i)^\.(?:md|html|json)$' })) {
          [void]$sourceFiles.Add($doc.FullName)
        }
      }
    } else {
      [void]$failures.Add('PlanningRootMissing')
    }

    # Index each worktree's _generated tree once (relative file and directory
    # paths, '/'-separated); resolving thousands of citations with Test-Path on a
    # synced volume is too slow for a SprintEnd gate.
    $generatedIndex = @{}
    foreach ($worktree in $worktrees) {
      $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      $generatedRoot = Join-Path $worktree '_generated'
      if (Test-Path -LiteralPath $generatedRoot -PathType Container) {
        foreach ($entry in [IO.Directory]::EnumerateFileSystemEntries($generatedRoot, '*', [IO.SearchOption]::AllDirectories)) {
          [void]$set.Add(([IO.Path]::GetRelativePath($generatedRoot, $entry) -replace '\\', '/'))
        }
      }
      $generatedIndex[$worktree] = $set
    }

    $tokenCharacters = '[^\s"''<>|()\[\]`*,;]'
    $citationRegex = [regex]::new("(?<prefix>$tokenCharacters*)_generated[\\/](?<tail>$tokenCharacters+)",
      [Text.RegularExpressions.RegexOptions]'IgnoreCase, Compiled')
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($sourceFile in $sourceFiles) {
      $lineNumber = 0
      foreach ($line in [IO.File]::ReadLines($sourceFile)) {
        $lineNumber++
        if ($line.IndexOf('_generated', [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
        foreach ($match in $citationRegex.Matches($line)) {
          # Collapse separator runs so JSON-escaped citations (`_generated\\a\\b`
          # in the HTML board) resolve like their Markdown twins.
          $tail = ($match.Groups['tail'].Value -replace '[\\/]+', '/').TrimEnd('.', ':', '/').TrimStart('/')
          if ([string]::IsNullOrWhiteSpace($tail) -or $tail -match '[?]') { continue }
          $prefix = $match.Groups['prefix'].Value
          $candidates = @($worktrees | Where-Object {
              $prefix.IndexOf((Split-Path -Path $_ -Leaf), [StringComparison]::OrdinalIgnoreCase) -ge 0
            })
          if ($candidates.Count -eq 0) { $candidates = $worktrees }
          foreach ($worktree in $candidates) {
            if (-not $generatedIndex[$worktree].Contains($tail)) { continue }
            $resolved = [IO.Path]::GetFullPath((Join-Path (Join-Path $worktree '_generated') $tail))
            if (-not $seen.Add("$sourceFile|$lineNumber|$resolved")) { continue }
            [void]$citedPaths.Add([PSCustomObject]@{
                SourcePath   = $sourceFile
                LineNumber   = $lineNumber
                Citation     = $match.Value
                ResolvedPath = $resolved
              })
          }
        }
      }
    }
    if ($citedPaths.Count -gt 0) { [void]$failures.Add('CitedGeneratedArtifacts') }

    [PSCustomObject]@{
      Ok           = ($failures.Count -eq 0)
      WorktreePaths = $worktrees
      PlanningRoot = $planningRootFull
      TrackedPaths = $trackedPaths.ToArray()
      CitedPaths   = $citedPaths.ToArray()
      Failures     = $failures.ToArray()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

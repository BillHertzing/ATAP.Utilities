function Get-SprintEndLockFileApplicability {
  <#
  .SYNOPSIS
    Determines whether the NuGet lock-file guard applies to the selected sprint
    worktrees.

  .DESCRIPTION
    Task 14.11. The lock-file concern was surfaced to the operator as an
    optional "the lock-file runner is not available -- proceed anyway?"
    question. That is the wrong shape: whether the guard is meaningful is a
    property of the repositories being closed, not a judgement call. A
    repository that tracks no packages.lock.json cannot have lock-file drift, so
    an unavailable runner is irrelevant; a repository that tracks lock files must
    have the guard run, so an unavailable runner is a hard fault, not a prompt.

    This helper answers the repository half of that question by asking Git which
    packages.lock.json files are tracked. It never restores, never writes, and
    never prompts.

  .PARAMETER WorktreePath
    Sprint worktrees to inspect.

    When a worktree cannot be inspected -- it is not a Git repository, git is
    unavailable, or the call fails -- applicability is indeterminate. The helper
    then reports Applicable, because a probe that is only an optimization must
    never be the reason a needed guard is skipped, and must never be the reason
    a close is blocked either.

  .OUTPUTS
    PSCustomObject with Applicable, TrackedLockFileCount, IndeterminatePaths,
    PerWorktree, and Failures.

  .EXAMPLE
    Get-SprintEndLockFileApplicability -WorktreePath $worktreePaths

  .NOTES
    AI assisted using ./.claude/rules/Powershell.md as guidelines.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [AllowEmptyCollection()]
    [string[]]$WorktreePath = @()
  )

  begin {
    $fn = 'Get-SprintEndLockFileApplicability'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
    $perWorktree = [System.Collections.Generic.List[object]]::new()
    $indeterminate = [System.Collections.Generic.List[string]]::new()
  }

  process {
    foreach ($candidate in @($WorktreePath)) {
      if ([string]::IsNullOrWhiteSpace($candidate)) { continue }

      $entry = [ordered]@{
        Path                 = $candidate
        TrackedLockFileCount = 0
        Inspected            = $false
        Indeterminate        = $false
        Detail               = $null
      }

      if (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
        $entry.Detail = 'Path does not exist; treated as tracking no lock files.'
        [void]$perWorktree.Add([PSCustomObject]$entry)
        continue
      }

      try {
        $lsFiles = Invoke-SprintEndNativeCommand -FilePath 'git' -ArgumentList @(
          '-C', $candidate, 'ls-files', '--', '*packages.lock.json'
        ) -AllowNonZeroExitCode
        if ($lsFiles.Succeeded) {
          $tracked = @($lsFiles.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
          $entry.TrackedLockFileCount = $tracked.Count
          $entry.Inspected = $true
          $entry.Detail = "$($tracked.Count) tracked packages.lock.json file(s)."
        } else {
          $entry.Detail = "git ls-files returned exit code $($lsFiles.ExitCode); lock-file applicability could not be determined."
          $entry.Indeterminate = $true
          [void]$indeterminate.Add($candidate)
        }
      } catch {
        $entry.Detail = "Lock-file applicability inspection failed: $($_.Exception.Message)"
        $entry.Indeterminate = $true
        [void]$indeterminate.Add($candidate)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $entry.Detail
      }

      [void]$perWorktree.Add([PSCustomObject]$entry)
    }
  }

  end {
    $totalTracked = ($perWorktree | Measure-Object -Property TrackedLockFileCount -Sum).Sum
    if ($null -eq $totalTracked) { $totalTracked = 0 }

    # Fail safe, not closed. An unreadable worktree (not a Git repository, git
    # unavailable, transient failure) means we cannot prove the guard is
    # irrelevant -- so we say it applies and let the guard itself report. The
    # opposite default would silently skip a guard that was needed, and treating
    # it as a hard error would block a close over a probe that is only an
    # optimization.
    $applicable = ([int]$totalTracked -gt 0) -or ($indeterminate.Count -gt 0)

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    return [PSCustomObject]@{
      Applicable           = $applicable
      TrackedLockFileCount = [int]$totalTracked
      IndeterminatePaths   = $indeterminate.ToArray()
      PerWorktree          = $perWorktree.ToArray()
      Failures             = @()
    }
  }
}

function Test-SprintEndWriteTarget {
  <#
  .SYNOPSIS
    Verifies that every path SprintEnd intends to write is inside a sprint
    worktree and never inside a stable worktree.

  .DESCRIPTION
    Task 14.10. During the Sprint 0013 close, remediation changes reached stable
    worktrees because no single gate ever asked "is this write target a sprint
    worktree?" before a mutation ran. Individual cmdlets each derived their own
    stable/sprint paths, so a stable path substituted into a worktree list --
    by a caller, by a post-deletion disk rescan, or by an agent "repairing" the
    stable copy directly -- was only rejected incidentally, deep inside a helper,
    after other work had already started.

    This cmdlet is the explicit gate. It classifies each supplied path with the
    single path-classification rule and blocks any path that is not a sprint
    worktree. Stable worktrees are always blocked. Paths outside GitRoot are
    blocked unless the caller names them in -AllowedOutsideGitRootPath (used for
    genuinely machine-global boundary state such as user profiles, which are not
    repository content and are governed by their own cmdlets).

    The cmdlet performs no filesystem mutation and no Git access. It is safe to
    call inside a dry run and it returns the same verdict for planned paths as
    for existing ones.

  .PARAMETER Path
    One or more intended write targets.

  .PARAMETER GitRoot
    Root directory that contains every repository and sprint worktree.

  .PARAMETER AllowedOutsideGitRootPath
    Paths outside GitRoot that this operation is explicitly permitted to write.
    A path is allowed when it equals, or is contained by, one of these entries.

  .PARAMETER Operation
    Short label for the operation being gated. Recorded in failures so a blocked
    write names what tried to perform it.

  .PARAMETER ThrowOnFailure
    Throw a terminating error when any path is blocked.

  .OUTPUTS
    PSCustomObject with Ok, Operation, GitRoot, PerPath, BlockedPaths, and
    Failures.

  .EXAMPLE
    Test-SprintEndWriteTarget -GitRoot 'C:\Repos' -Path $worktreePaths -Operation 'BoundaryReset' -ThrowOnFailure

  .EXAMPLE
    # A stable repository root is rejected before any mutation is attempted.
    Test-SprintEndWriteTarget -GitRoot 'C:\Repos' -Path 'C:\Repos\ATAP.Utilities'

  .NOTES
    AI assisted using ./.claude/rules/Powershell.md as guidelines.

  .LINK
    New-SprintEndDefectRoute
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Path,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$GitRoot,

    [Parameter()]
    [AllowEmptyCollection()]
    [string[]]$AllowedOutsideGitRootPath = @(),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Operation = 'SprintEndWrite',

    [Parameter()]
    [switch]$ThrowOnFailure
  )

  begin {
    $fn = 'Test-SprintEndWriteTarget'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    if (-not (Get-Command -Name 'Get-SprintWorktreeClassification' -CommandType Function -ErrorAction SilentlyContinue)) {
      $classificationHelperPath = Join-Path $PSScriptRoot '..' 'private' 'Get-SprintWorktreeClassification.ps1'
      if (Test-Path -LiteralPath $classificationHelperPath -PathType Leaf) {
        . $classificationHelperPath
      }
    }

    $normalizedAllowances = @(
      foreach ($allowance in @($AllowedOutsideGitRootPath)) {
        if (-not [string]::IsNullOrWhiteSpace($allowance)) {
          ([IO.Path]::GetFullPath($allowance)).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        }
      }
    )

    $perPath = [System.Collections.Generic.List[object]]::new()
    $failures = [System.Collections.Generic.List[string]]::new()
  }

  process {
    foreach ($candidate in @($Path)) {
      if ([string]::IsNullOrWhiteSpace($candidate)) {
        [void]$failures.Add("$Operation supplied a null, empty, or whitespace write target.")
        continue
      }

      $classification = Get-SprintWorktreeClassification -Path $candidate -GitRoot $GitRoot
      $allowed = $classification.WriteAllowedDuringSprintEnd
      $allowanceReason = $null

      if (-not $allowed -and $classification.Classification -eq 'OutsideGitRoot') {
        $matchedAllowance = @(
          $normalizedAllowances | Where-Object {
            [StringComparer]::OrdinalIgnoreCase.Equals($classification.Path, $_) -or
            $classification.Path.StartsWith($_ + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
          }
        ) | Select-Object -First 1
        if ($matchedAllowance) {
          $allowed = $true
          $allowanceReason = "Explicitly allowed by the caller through -AllowedOutsideGitRootPath entry '$matchedAllowance'."
        }
      }

      $entry = [PSCustomObject]@{
        Path                 = $classification.Path
        Classification       = $classification.Classification
        RepositoryName       = $classification.RepositoryName
        SprintNumber         = $classification.SprintNumber
        StableRepositoryPath = $classification.StableRepositoryPath
        Allowed              = $allowed
        Reason               = if ($allowanceReason) { $allowanceReason } else { $classification.Reason }
      }
      [void]$perPath.Add($entry)

      if (-not $allowed) {
        $failure = "$Operation would write to '$($entry.Path)' ($($entry.Classification)). $($entry.Reason)"
        [void]$failures.Add($failure)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $failure
      }
    }
  }

  end {
    $blocked = @($perPath | Where-Object { -not $_.Allowed } | Select-Object -ExpandProperty Path)
    $result = [PSCustomObject]@{
      Ok           = ($failures.Count -eq 0)
      Operation    = $Operation
      GitRoot      = ([IO.Path]::GetFullPath($GitRoot)).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
      PerPath      = $perPath.ToArray()
      BlockedPaths = $blocked
      Failures     = $failures.ToArray()
    }

    if (-not $result.Ok -and $ThrowOnFailure) {
      throw "SprintEnd write-target boundary rejected $($blocked.Count) path(s) for operation '$Operation': $($result.Failures -join ' ')"
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    return $result
  }
}

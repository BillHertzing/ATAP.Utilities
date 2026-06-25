function Test-SprintEndWorktreeState {
  <#
  .SYNOPSIS
  Performs one structured clean-state inspection across sprint worktrees.

  .DESCRIPTION
  Reads each repository branch, in-progress Git markers, and porcelain status.
  Paths matching ExpectedPathPattern are classified separately from unexpected
  user changes. The cmdlet never stages, commits, resets, or creates branches.

  .PARAMETER WorktreePaths
  Sprint worktree roots to inspect.

  .PARAMETER ExpectedPathPattern
  Relative-path wildcard patterns allowed as expected SprintEnd mutations.

  .PARAMETER ThrowOnUnexpected
  Throws when an in-progress Git operation or unexpected path is found.

  .OUTPUTS
  PSCustomObject with Ok, PerWorktree, and Failures.

  .EXAMPLE
  Test-SprintEndWorktreeState -WorktreePaths $paths

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorktreePaths,

    [Parameter()]
    [string[]]$ExpectedPathPattern = @(
      '*.code-workspace',
      '.gitattributes',
      '.gitconfig.shared',
      'Tasks.Sprint*.md',
      'Tasks.Sprint*.html',
      'Tasks.Sprint*.Accomplished.html',
      'Tasks.Sprint*.ProceduralDetails.html'
    ),

    [Parameter()]
    [switch]$ThrowOnUnexpected
  )

  begin {
    $fn = 'Test-SprintEndWorktreeState'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $perWorktree = [System.Collections.Generic.List[object]]::new()
    $failures = [System.Collections.Generic.List[string]]::new()

    foreach ($worktreePath in $WorktreePaths) {
      $resolved = [IO.Path]::GetFullPath($worktreePath)
      $gitDirResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
        -ArgumentList @('-C', $resolved, 'rev-parse', '--git-dir') -AllowNonZeroExitCode
      if (-not $gitDirResult.Succeeded) {
        [void]$failures.Add("$resolved is not a Git worktree.")
        [void]$perWorktree.Add([PSCustomObject]@{
            Path = $resolved; Branch = $null; InProgress = @(); ExpectedChanges = @()
            UnexpectedChanges = @(); Ok = $false; Detail = 'Not a Git worktree.'
          })
        continue
      }

      $gitDirText = ($gitDirResult.Output -join '').Trim()
      $gitDir = if ([IO.Path]::IsPathRooted($gitDirText)) {
        $gitDirText
      } else {
        [IO.Path]::GetFullPath((Join-Path $resolved $gitDirText))
      }
      $inProgress = @('MERGE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD', 'rebase-merge', 'rebase-apply') |
        Where-Object { Test-Path -LiteralPath (Join-Path $gitDir $_) }
      $branchResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
        -ArgumentList @('-C', $resolved, 'branch', '--show-current') -AllowNonZeroExitCode
      $statusResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
        -ArgumentList @('-C', $resolved, 'status', '--porcelain=v1', '--untracked-files=all') `
        -AllowNonZeroExitCode

      $changes = [System.Collections.Generic.List[object]]::new()
      foreach ($line in @($statusResult.Output | Where-Object { $_ })) {
        $status = if ($line.Length -ge 2) { $line.Substring(0, 2) } else { $line }
        $path = if ($line.Length -gt 3) { $line.Substring(3).Trim('"') } else { '' }
        if ($path -match ' -> ') { $path = ($path -split ' -> ')[-1].Trim('"') }
        $expected = $false
        foreach ($pattern in $ExpectedPathPattern) {
          if ($path -like $pattern) { $expected = $true; break }
        }
        [void]$changes.Add([PSCustomObject]@{
            Status = $status
            Path = $path
            Expected = $expected
          })
      }
      $expectedChanges = @($changes | Where-Object Expected)
      $unexpectedChanges = @($changes | Where-Object { -not $_.Expected })
      $ok = ($statusResult.Succeeded -and $inProgress.Count -eq 0 -and $unexpectedChanges.Count -eq 0)
      if (-not $ok) {
        [void]$failures.Add("$resolved has unresolved state: in-progress=$($inProgress -join ','); unexpected=$($unexpectedChanges.Path -join ',').")
      }
      [void]$perWorktree.Add([PSCustomObject]@{
          Path              = $resolved
          Branch            = ($branchResult.Output -join '').Trim()
          InProgress        = @($inProgress)
          ExpectedChanges   = $expectedChanges
          UnexpectedChanges = $unexpectedChanges
          IsClean           = ($changes.Count -eq 0)
          Ok                = $ok
          Detail            = if ($ok) { 'Worktree state accepted.' } else { 'Review failures.' }
        })
    }

    $result = [PSCustomObject]@{
      Ok          = ($failures.Count -eq 0)
      PerWorktree = $perWorktree.ToArray()
      Failures    = $failures.ToArray()
    }
    if (-not $result.Ok -and $ThrowOnUnexpected) {
      throw "SprintEnd worktree state failed: $($result.Failures -join '; ')"
    }
    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

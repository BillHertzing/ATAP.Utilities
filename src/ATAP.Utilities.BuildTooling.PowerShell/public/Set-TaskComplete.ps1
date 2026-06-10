function Set-TaskComplete {
  <#
.SYNOPSIS
  Marks one or more task items in TASKS.md as complete under an exclusive file lock.

.DESCRIPTION
  Multiple Claude Code agents running concurrently in separate VS Code windows may all
  attempt to write to the shared TASKS.md at the same time.  This script serialises those
  writes by acquiring an OS-level exclusive lock before reading or modifying the file.

  The script supports two ways to locate a task:

  - `-TaskText`  : match by description text using one of three modes
        Substring  (default) — any line containing the search text
        Exact      — the entire task line must equal the search text
        Regex      — the search text is treated as a .NET regular expression

  - `-TaskNumber`: match by the bold task-number marker at the start of the task body
        Supports current Sprint 0007 V3 format (e.g. 'A04', 'B10', 'C19', 'F01a')
        and legacy numeric format (e.g. '7.1', '7.105').

  Only lines whose checkbox is currently unchecked `[ ]` are modified.  Already-completed
  `[x]` lines are left untouched, so re-running is always safe (idempotent).

.PARAMETER TaskText
  Text to locate within TASKS.md.  Can be a unique fragment of the task description,
  the full task line, or a regex pattern depending on -MatchMode.

.PARAMETER TaskNumber
  The bold task-number marker at the start of the task body (e.g. 'A04', 'B10', '7.1').
  Matches lines of the form:
    - [ ] **<TaskNumber> [TAG]** description
    - [ ] **<TaskNumber>** description

.PARAMETER TasksFilePath
  Full path to TASKS.md.
  Default: C:/Dropbox/whertzing/github/_planning/TASKS.md

.PARAMETER MatchMode
  Substring | Exact | Regex   (default: Substring).  Only meaningful with -TaskText.

.PARAMETER DryRun
  If specified, prints the proposed change without writing to disk.

.OUTPUTS
  [int]  Number of task lines actually changed (0 if already complete or not found).

.EXAMPLE
  # Mark a task complete by fragment
  Set-TaskComplete -TaskText 'Add SignalR hub'

.EXAMPLE
  # Mark a task complete by current V3 task number
  Set-TaskComplete -TaskNumber 'A04'

.EXAMPLE
  # Mark a legacy numeric task complete
  Set-TaskComplete -TaskNumber '7.1' -TasksFilePath 'C:/path/to/TASKS_V2.md'

.EXAMPLE
  # Dry-run to preview the change
  Set-TaskComplete -TaskNumber 'B10' -DryRun

.NOTES
  AI assisted using Powershell.instructions.md as guidelines
  Calls Invoke-WithFileLock.ps1 (must be in the same Powershell/public/ directory).
#>
  [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByText')]
  param(
    [Parameter(Mandatory, ParameterSetName = 'ByText')]
    [string]$TaskText,

    [Parameter(Mandatory, ParameterSetName = 'ByNumber')]
    [ValidateNotNullOrEmpty()]
    [string]$TaskNumber,

    [Parameter()]
    [string]$TasksFilePath = 'C:/Dropbox/whertzing/github/_planning/TASKS.md',

    [Parameter(ParameterSetName = 'ByText')]
    [ValidateSet('Substring', 'Exact', 'Regex')]
    [string]$MatchMode = 'Substring',

    [Parameter()]
    [switch]$DryRun
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'SharedTools'

    # Load the locking helper from the same directory as this script
    $lockScript = Join-Path $PSScriptRoot 'Invoke-WithFileLock.ps1'
    if (-not (Test-Path $lockScript)) {
      throw "Set-TaskComplete: cannot find Invoke-WithFileLock.ps1 at '$lockScript'"
    }
    . $lockScript

    # Verify TASKS.md exists
    if (-not (Test-Path $TasksFilePath)) {
      throw "Set-TaskComplete: TASKS.md not found at '$TasksFilePath'"
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Set-TaskComplete invoked (parameter set: $($PSCmdlet.ParameterSetName))"
  }

  process {
    # Build all state as locals so .GetNewClosure() can capture them into the script block.
    # Without GetNewClosure(), variables referenced inside the script block resolve against
    # Invoke-WithFileLock's scope when it runs `& $Action`, not against this process scope.
    $counter      = @{ count = 0 }
    $localPath    = $TasksFilePath
    $localDryRun  = $DryRun.IsPresent
    $localFn      = $fn
    $localMn      = $mn
    $useNumber    = ($PSCmdlet.ParameterSetName -eq 'ByNumber')
    if ($useNumber) {
      # Anchor: optional indent, list marker, unchecked checkbox, optional space, opening **, the
      # task number (regex-escaped), then EITHER a space OR closing `**`. The lookahead ensures
      # 'A04' does not match '**A040**' or '**A04something**' — the next char must be whitespace
      # or the bold terminator.
      $numberPattern = '^\s*-\s*\[ \]\s+\*\*' + [regex]::Escape($TaskNumber) + '(?=\s|\*\*)'
      $localTaskNumber = $TaskNumber
      $localTaskText = $null
      $localMatchMode = $null
    } else {
      $numberPattern = $null
      $localTaskNumber = $null
      $localTaskText = $TaskText
      $localMatchMode = $MatchMode
    }

    $action = {
      $lines = [System.IO.File]::ReadAllLines($localPath)
      $newLines = for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Only act on unchecked task lines
        $isUnchecked = $line -match '^\s*-\s*\[ \]'

        $isMatch = if ($useNumber) {
          $line -match $numberPattern
        } else {
          switch ($localMatchMode) {
            'Substring' { $line.Contains($localTaskText) }
            'Exact'     { ($line.Trim() -eq $localTaskText.Trim()) }
            'Regex'     { $line -match $localTaskText }
          }
        }

        if ($isUnchecked -and $isMatch) {
          # Replace only the first `[ ]` on the line so that any `[ ]` substring elsewhere in the
          # task body (rare but possible) is left untouched.
          $newLine = [regex]::Replace($line, '\[ \]', '[x]', 1)
          Write-PSFMessage -FunctionName $localFn -ModuleName $localMn -Level Important `
            -Message "$(if ($localDryRun) {'[DRY RUN] Would mark'} else {'Marking'}) complete: $newLine"
          $newLine
          $counter.count++
        } else {
          $line
        }
      }

      if ($counter.count -gt 0 -and -not $localDryRun) {
        [System.IO.File]::WriteAllLines($localPath, $newLines, [System.Text.Encoding]::UTF8)
        Write-PSFMessage -FunctionName $localFn -ModuleName $localMn -Level Important `
          -Message "TASKS.md updated: $($counter.count) line(s) marked complete"
      } elseif ($counter.count -eq 0) {
        $what = if ($useNumber) { "task number '$localTaskNumber'" } else { "text '$localTaskText'" }
        Write-PSFMessage -FunctionName $localFn -ModuleName $localMn -Level Verbose `
          -Message "No matching unchecked tasks found for $what"
      }
    }.GetNewClosure()

    Invoke-WithFileLock -LockName 'TASKS.md' -Action $action

    return $counter.count
  }
}

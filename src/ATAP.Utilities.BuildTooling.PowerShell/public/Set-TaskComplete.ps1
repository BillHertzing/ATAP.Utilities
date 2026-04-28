function Set-TaskComplete {
  <#
.SYNOPSIS
  Marks one or more task items in TASKS.md as complete under an exclusive file lock.

.DESCRIPTION
  Multiple Claude Code agents running concurrently in separate VS Code windows may all
  attempt to write to the shared TASKS.md at the same time.  This script serialises those
  writes by acquiring an OS-level exclusive lock before reading or modifying the file.

  The script supports three match strategies:
    - Substring  (default) — any line containing the search text
    - Exact      — the entire task line must equal the search text
    - Regex      — the search text is treated as a .NET regular expression

  Only lines whose checkbox is currently unchecked `[ ]` are modified.  Already-completed
  `[x]` lines are left untouched, so re-running is always safe (idempotent).

.PARAMETER TaskText
  Text to locate within TASKS.md.  Can be a unique fragment of the task description,
  the full task line, or a regex pattern depending on -MatchMode.

.PARAMETER TasksFilePath
  Full path to TASKS.md.
  Default: C:/Dropbox/whertzing/github/_planning/TASKS.md

.PARAMETER MatchMode
  Substring | Exact | Regex   (default: Substring)

.PARAMETER DryRun
  If specified, prints the proposed change without writing to disk.

.OUTPUTS
  [int]  Number of task lines actually changed (0 if already complete or not found).

.EXAMPLE
  # Mark a task complete by fragment
  # The function is autoloaded from the installed module
  Set-TaskComplete -TaskText 'Add SignalR hub'

.EXAMPLE
  # Dry-run to preview the change
  Set-TaskComplete -TaskText 'Step 3' -DryRun

.NOTES
  AI assisted using Powershell.instructions.md as guidelines
  Calls Invoke-WithFileLock.ps1 (must be in the same Powershell/public/ directory).
#>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)]
    [string]$TaskText,

    [Parameter()]
    [string]$TasksFilePath = 'C:/Dropbox/whertzing/github/_planning/TASKS.md',

    [Parameter()]
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
      -Message "Will mark task (mode=$MatchMode): $TaskText"
  }

  process {
    $changed = 0

    Invoke-WithFileLock -LockName 'TASKS.md' -Action {

      $lines = [System.IO.File]::ReadAllLines($TasksFilePath)
      $newLines = for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Only act on unchecked task lines
        $isUnchecked = $line -match '^\s*-\s*\[ \]'

        $isMatch = switch ($MatchMode) {
          'Substring' { $line.Contains($TaskText) }
          'Exact' { ($line.Trim() -eq $TaskText.Trim()) }
          'Regex' { $line -match $TaskText }
        }

        if ($isUnchecked -and $isMatch) {
          $newLine = $line -replace '\[ \]', '[x]'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "$(if ($DryRun) {'[DRY RUN] Would mark'} else {'Marking'}) complete: $newLine"
          $newLine
          $script:changed++
        } else {
          $line
        }
      }

      if ($changed -gt 0 -and -not $DryRun) {
        [System.IO.File]::WriteAllLines($TasksFilePath, $newLines, [System.Text.Encoding]::UTF8)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "TASKS.md updated: $changed line(s) marked complete"
      } elseif ($changed -eq 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
          -Message "No matching unchecked tasks found for: $TaskText"
      }
    }

    return $changed
  }
}

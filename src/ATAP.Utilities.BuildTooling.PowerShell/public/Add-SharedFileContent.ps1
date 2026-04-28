function Add-SharedFileContent {
  <#
.SYNOPSIS
  Appends content to, or performs a regex find-and-replace within, a shared file under
  an exclusive file lock.

.DESCRIPTION
  Use this script whenever a Claude Code agent needs to add instructions to CLAUDE.md or
  any other file that multiple agents might edit concurrently.

  Two modes:
    Append  (default) — adds the supplied content at the end of the file, preceded by a
                        blank line.  Idempotent: if GuardText is supplied and already
                        present in the file, the operation is skipped.
    Replace           — performs a .NET Regex Replace on the entire file content.

.PARAMETER FilePath
  Full path to the shared file to modify.

.PARAMETER Content
  Text to append (Append mode) or the replacement string (Replace mode).

.PARAMETER GuardText
  (Append mode only) If this string already appears anywhere in the file, the append is
  skipped.  Use a distinctive phrase from the section you are about to add to prevent
  duplicate entries across agent runs.

.PARAMETER Mode
  Append | Replace   (default: Append)

.PARAMETER Pattern
  (Replace mode only) .NET Regex pattern to match.

.PARAMETER DryRun
  If specified, prints the proposed change without writing to disk.

.OUTPUTS
  [bool]  True if the file was modified, False if the operation was skipped (guard hit).

.EXAMPLE
  # Append a new rule to CLAUDE.md — guarded so it only appears once
  # The function is autoloaded from the installed module
  $rule = @'
  ## Locking Protocol (added by agent)
  Always use Set-TaskComplete function to mark tasks complete.
  '@
  Add-SharedFileContent -FilePath 'C:\Dropbox\whertzing\GitHub\AceCommander\CLAUDE.md' `
      -Content   $rule `
      -GuardText 'Locking Protocol'

.EXAMPLE
  # Replace a specific section using regex
  Add-SharedFileContent -FilePath 'C:\Dropbox\whertzing\GitHub\AceCommander\CLAUDE.md' `
      -Mode      Replace `
      -Pattern   '(?ms)^## Old Section.*?(?=^## |\Z)' `
      -Content   "## New Section`n`nupdated content`n`n"

.NOTES
  AI assisted using Powershell.instructions.md as guidelines
  Calls Invoke-WithFileLock.ps1 (must be in the same Powershell/public/ directory).
#>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)]
    [string]$FilePath,

    [Parameter(Mandatory)]
    [string]$Content,

    [Parameter()]
    [string]$GuardText,

    [Parameter()]
    [ValidateSet('Append', 'Replace')]
    [string]$Mode = 'Append',

    [Parameter()]
    [string]$Pattern,

    [Parameter()]
    [switch]$DryRun
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'SharedTools'

    $lockScript = Join-Path $PSScriptRoot 'Invoke-WithFileLock.ps1'
    if (-not (Test-Path $lockScript)) {
      throw "Add-SharedFileContent: cannot find Invoke-WithFileLock.ps1 at '$lockScript'"
    }
    . $lockScript

    if (-not (Test-Path $FilePath)) {
      throw "Add-SharedFileContent: target file not found at '$FilePath'"
    }

    if ($Mode -eq 'Replace' -and -not $PSBoundParameters.ContainsKey('Pattern')) {
      throw 'Add-SharedFileContent: -Pattern is required when -Mode Replace is specified.'
    }

    # Lock name = filename only, so lock is shared across agents pointing to the same file
    $lockName = [System.IO.Path]::GetFileName($FilePath)

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Add-SharedFileContent: mode=$Mode file=$FilePath"
  }

  process {
    $modified = $false

    Invoke-WithFileLock -LockName $lockName -Action {

      $current = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)

      switch ($Mode) {

        'Append' {
          # Guard check — skip if distinctive text already present
          if ($GuardText -and $current.Contains($GuardText)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
              -Message "Guard text found — skipping append to '$FilePath'"
            return
          }

          $newContent = $current.TrimEnd() + "`n`n" + $Content.TrimEnd() + "`n"

          if ($DryRun) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "[DRY RUN] Would append to '$FilePath':`n$Content"
          } else {
            [System.IO.File]::WriteAllText($FilePath, $newContent, [System.Text.Encoding]::UTF8)
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "Appended content to '$FilePath'"
            $script:modified = $true
          }
        }

        'Replace' {
          $newContent = [System.Text.RegularExpressions.Regex]::Replace(
            $current, $Pattern, $Content,
            [System.Text.RegularExpressions.RegexOptions]::Multiline
          )

          if ($newContent -eq $current) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
              -Message "Pattern matched nothing — no change to '$FilePath'"
            return
          }

          if ($DryRun) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "[DRY RUN] Would replace pattern '$Pattern' in '$FilePath'"
          } else {
            [System.IO.File]::WriteAllText($FilePath, $newContent, [System.Text.Encoding]::UTF8)
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "Replaced pattern in '$FilePath'"
            $script:modified = $true
          }
        }
      }
    }

    return $modified
  }
}

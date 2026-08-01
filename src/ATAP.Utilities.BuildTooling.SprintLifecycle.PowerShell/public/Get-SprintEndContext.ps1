# Load contract: dot-source this file to define Get-SprintEndContext. No top-level
# code executes on load — all side effects occur only when the function is called.
function Get-SprintEndContext {
  <#
  .SYNOPSIS
    Auto-detects the closed sprint number and computes the next sprint number
    for use by SprintEndAgent.

  .DESCRIPTION
    Derives the closing sprint number by parsing the current working directory
    path for a sprint worktree pattern (*-Sprint-NNNN-work-items). When the
    current path does not match, falls back to scanning all sprint worktrees
    under GitRoot and returning the most-common sprint number.

    The next sprint number is always computed as closedSprintNumber + 1.

    IMPORTANT — off-by-one guard: the next sprint number MUST be derived from
    closedSprintNumber + 1. Do NOT derive it from a planning branch (e.g.
    _Planning-wt-16-Sprint-0008-work-items) and add 1 again; that branch
    already encodes the next sprint, so adding 1 would overshoot by one.
    (Root-cause of the sprint-0007-close off-by-one, tracked in memory
    project_sprint_end_bugs Bug 1.)

  .PARAMETER GitRoot
    Root directory containing all Git repositories.
    Defaults to 'C:\Dropbox\whertzing\GitHub'.

  .PARAMETER CurrentPath
    Directory path to parse for the sprint number.
    Defaults to (Get-Location).Path.

  .OUTPUTS
    [PSCustomObject] with Ok [bool], ClosedSprintNumber [string],
    NextSprintNumber [string], Detail [string].

  .EXAMPLE
    $ctx = Get-SprintEndContext
    $ctx | ConvertTo-Json

  .EXAMPLE
    $ctx = Get-SprintEndContext -CurrentPath 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-107-Sprint-0008-work-items'
    $ctx.ClosedSprintNumber  # '0008'
    $ctx.NextSprintNumber    # '0009'

  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [string]$GitRoot = 'C:\Dropbox\whertzing\GitHub',

    [Parameter()]
    [string]$CurrentPath
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    if ([string]::IsNullOrWhiteSpace($CurrentPath)) {
      $CurrentPath = (Get-Location).Path
    }

    $closedSprintNumber = $null
    $source = $null

    # Primary: parse sprint number from the current working directory path.
    # Pattern: <repo>-wt-<issue>-Sprint-NNNN-work-items
    if ($CurrentPath -match '-Sprint-(\d{4})-work-items') {
      $closedSprintNumber = $Matches[1]
      $source = "current path '$CurrentPath'"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Sprint number '$closedSprintNumber' parsed from path: $CurrentPath"
    }

    # Fallback: scan worktrees under GitRoot and take the most-frequent sprint number.
    if ($null -eq $closedSprintNumber) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Current path does not match sprint pattern; scanning worktrees under $GitRoot"

      try {
        $wtDirs = Get-ChildItem -Path $GitRoot -Directory -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -match '-Sprint-(\d{4})-work-items' }

        if ($wtDirs) {
          $freq = $wtDirs.Name | ForEach-Object {
            if ($_ -match '-Sprint-(\d{4})-work-items') { $Matches[1] }
          } | Group-Object | Sort-Object Count -Descending

          if ($freq) {
            $closedSprintNumber = $freq[0].Name
            $source = "worktree scan under $GitRoot (count=$($freq[0].Count))"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
              -Message "Sprint number '$closedSprintNumber' detected from worktree scan"
          }
        }
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning `
          -Message "Worktree scan failed: $($_.Exception.Message)"
      }
    }

    if ($null -eq $closedSprintNumber) {
      $detail = "Could not detect sprint number from path '$CurrentPath' or worktrees under '$GitRoot'"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message $detail
      return [PSCustomObject]@{
        Ok                 = $false
        ClosedSprintNumber = $null
        NextSprintNumber   = $null
        Detail             = $detail
      }
    }

    # Compute next sprint number: closedSprintNumber + 1 (zero-padded 4 digits).
    # This is the ONLY correct derivation. See .DESCRIPTION for off-by-one guard.
    $nextN = [int]$closedSprintNumber + 1
    $nextSprintNumber = '{0:D4}' -f $nextN
    $detail = "Closed sprint: $closedSprintNumber; Next sprint: $nextSprintNumber (source: $source)"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $detail

    return [PSCustomObject]@{
      Ok                 = $true
      ClosedSprintNumber = $closedSprintNumber
      NextSprintNumber   = $nextSprintNumber
      Detail             = $detail
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

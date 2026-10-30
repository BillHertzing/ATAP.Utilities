function Get-CoordTask {
  <#
  .SYNOPSIS
    Reads one literal task from an explicitly selected planning board.
  .DESCRIPTION
    Returns a compact read-only snapshot. This does not establish caller
    authorization, board custody, or any mutation authority.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $PlanningRoot,
    [Parameter(Mandatory)][ValidateRange(1, 9999)][int] $SprintNumber,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $TaskId,
    [switch] $IncludeFullText
  )
  begin {
    if (-not (Get-Command -Name 'Read-CoordBoard' -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '../private/Read-CoordBoard.ps1')
    }
    $null = Get-Command -Name 'Read-CoordBoard' -ErrorAction Stop
  }
  process {
    $board = Read-CoordBoard -PlanningRoot $PlanningRoot -SprintNumber $SprintNumber
    $task = $null
    foreach ($candidate in $board.Tasks) {
      if ([string]::Equals($candidate.Id, $TaskId, [StringComparison]::Ordinal)) {
        $task = $candidate
        break
      }
    }
    [PSCustomObject]@{
      Outcome = if ($null -eq $task) { 'NotFound' } else { 'Found' }
      TaskId = $TaskId
      BoardPath = $board.Path
      BoardSha256 = $board.Sha256
      Checked = if ($null -eq $task) { $null } else { $task.Checked }
      Heading = if ($null -eq $task) { $null } else { $task.Heading }
      FullTextIncluded = ($null -ne $task -and $IncludeFullText.IsPresent)
      FullText = if ($null -ne $task -and $IncludeFullText.IsPresent) { $task.Text } else { $null }
    }
  }
}

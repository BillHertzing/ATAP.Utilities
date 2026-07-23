function Resolve-PlanningWorktreeRoot {
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [string]$PlanningRoot,

    [string[]]$ContextPath = @(),

    [string]$ReposParent
  )

  $childModule = Get-Module -Name 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell' |
    Sort-Object Version -Descending |
    Select-Object -First 1
  if (-not $childModule) {
    throw 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell must be loaded before calling Resolve-PlanningWorktreeRoot.'
  }

  & $childModule {
    param($BoundParameters)
    Resolve-PlanningWorktreeRoot @BoundParameters
  } $PSBoundParameters
}

function Resolve-PlanningWorktreeRoot {
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [string]$PlanningRoot,

    [string[]]$ContextPath = @(),

    [string]$ReposParent
  )

  $childModule = Get-Module -Name 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell' |
    Where-Object Version -ge ([version]'0.1.2') |
    Sort-Object Version -Descending |
    Select-Object -First 1
  if (-not $childModule) {
    $childModule = Import-Module -Name 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell' -MinimumVersion '0.1.2' -Force -PassThru -ErrorAction Stop
  }

  & $childModule {
    param($BoundParameters)
    Resolve-PlanningWorktreeRoot @BoundParameters
  } $PSBoundParameters
}

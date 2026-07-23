function Get-GitHubOwnerFromWorkspace {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$GitRoot,

    [string]$Fallback = $env:USERNAME
  )

  $childModule = Get-Module -Name 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell' |
    Sort-Object Version -Descending |
    Select-Object -First 1
  if (-not $childModule) {
    throw 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell must be loaded before calling Get-GitHubOwnerFromWorkspace.'
  }

  & $childModule {
    param($BoundParameters)
    Get-GitHubOwnerFromWorkspace @BoundParameters
  } $PSBoundParameters
}

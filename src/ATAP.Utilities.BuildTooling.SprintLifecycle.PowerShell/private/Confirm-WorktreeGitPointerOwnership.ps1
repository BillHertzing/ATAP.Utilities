function Confirm-WorktreeGitPointerOwnership {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$WorktreePath,

    [string]$InteractiveOperator = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,

    [bool]$RepairOwnership = $true
  )

  $childModule = Get-Module -Name 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell' |
    Where-Object Version -ge ([version]'0.1.3') |
    Sort-Object Version -Descending |
    Select-Object -First 1
  if (-not $childModule) {
    $childModule = Import-Module -Name 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell' -MinimumVersion '0.1.3' -Force -PassThru -ErrorAction Stop
  }

  & $childModule {
    param($BoundParameters)
    Confirm-WorktreeGitPointerOwnership @BoundParameters
  } $PSBoundParameters
}

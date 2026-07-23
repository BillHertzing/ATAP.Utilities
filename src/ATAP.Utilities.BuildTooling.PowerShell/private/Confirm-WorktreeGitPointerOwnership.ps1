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
    Sort-Object Version -Descending |
    Select-Object -First 1
  if (-not $childModule) {
    throw 'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell must be loaded before calling Confirm-WorktreeGitPointerOwnership.'
  }

  & $childModule {
    param($BoundParameters)
    Confirm-WorktreeGitPointerOwnership @BoundParameters
  } $PSBoundParameters
}

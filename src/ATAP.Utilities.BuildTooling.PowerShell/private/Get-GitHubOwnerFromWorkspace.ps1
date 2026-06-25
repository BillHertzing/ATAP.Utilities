function Get-GitHubOwnerFromWorkspace {
  <#
  .SYNOPSIS
    Resolves the GitHub owner from OverView.code-workspace githubOwner.
  .DESCRIPTION
    Reads the OverView.code-workspace file that lives in the folder above the
    stable worktrees (the Git root) and returns its 'githubOwner' value. This is
    the documented Owner default for sprint-start (Task 10.2): it lets a no-Owner
    dry run resolve the real organisation owner (e.g. 'BillHertzing') instead of
    the local Windows account name.

    The read is best-effort: if the workspace file is missing, unreadable, or has
    no non-empty 'githubOwner' key, the supplied -Fallback is returned rather than
    throwing, so sprint start degrades to the local account name instead of
    aborting. Get-PVal precedence still layers on top of this default
    (param > env > settings > this OverView-derived default).
  .PARAMETER GitRoot
    Root directory that contains all Git repositories and OverView.code-workspace.
  .PARAMETER Fallback
    Value returned when the workspace file or githubOwner key cannot be resolved.
    Defaults to the current Windows account name ($env:USERNAME).
  .OUTPUTS
    System.String — the resolved GitHub owner, or the fallback.
  .EXAMPLE
    Get-GitHubOwnerFromWorkspace -GitRoot 'C:\Dropbox\whertzing\GitHub'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$GitRoot,

    [string]$Fallback = $env:USERNAME
  )

  $fn = $MyInvocation.MyCommand.Name
  $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

  $workspaceFile = Join-Path $GitRoot 'OverView.code-workspace'
  if (-not (Test-Path -LiteralPath $workspaceFile)) {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "OverView.code-workspace not found at '$workspaceFile'; using fallback owner '$Fallback'."
    return $Fallback
  }

  try {
    $workspace = Get-WorkspaceJson -WorkspaceFile $workspaceFile
    $owner = $workspace.githubOwner
    if ([string]::IsNullOrWhiteSpace($owner)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "OverView.code-workspace has no non-empty 'githubOwner'; using fallback owner '$Fallback'."
      return $Fallback
    }
    return $owner.Trim()
  } catch {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Failed to read 'githubOwner' from '$workspaceFile'; using fallback owner '$Fallback'. Exception: $($_.Exception.Message)"
    return $Fallback
  }
}

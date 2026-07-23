#Requires -Version 7.0
function Get-LocalPowerShellModulePollerGitScalar {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoRoot,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Arguments
  )

  $lines = @(Invoke-LocalPowerShellModulePollerGit -RepoRoot $RepoRoot -Arguments $Arguments)
  if ($lines.Count -eq 0) {
    return ''
  }

  return ([string]$lines[0]).Trim()
}

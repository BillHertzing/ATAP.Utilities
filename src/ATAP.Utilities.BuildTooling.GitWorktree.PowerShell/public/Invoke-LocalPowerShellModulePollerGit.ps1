#Requires -Version 7.0
function Invoke-LocalPowerShellModulePollerGit {
  [CmdletBinding()]
  [OutputType([string[]])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoRoot,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Arguments
  )

  $output = & git -C $RepoRoot @Arguments 2>&1
  $exitCode = $LASTEXITCODE
  $lines = @($output | ForEach-Object { [string]$_ })
  if ($exitCode -ne 0) {
    $detail = ($lines -join [Environment]::NewLine).Trim()
    throw "git $($Arguments -join ' ') failed with exit code $exitCode in '$RepoRoot'. $detail"
  }

  return $lines
}

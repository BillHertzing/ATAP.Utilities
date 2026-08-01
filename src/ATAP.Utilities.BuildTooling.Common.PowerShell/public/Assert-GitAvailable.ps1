function Assert-GitAvailable {
  <#
  .SYNOPSIS
    Throws if git is not available on PATH.
  .DESCRIPTION
    Guard function used at the top of any operation that shells out to git.
    Uses Get-Command directly.
  #>
  [CmdletBinding()]
  param()

  if ($null -eq (Get-Command -Name 'git' -ErrorAction SilentlyContinue)) {
    throw "Required command 'git' was not found in PATH."
  }
}

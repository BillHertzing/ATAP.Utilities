function Assert-GitAvailable {
  <#
  .SYNOPSIS
    Throws if git is not available on PATH.
  .DESCRIPTION
    Guard function used at the top of any operation that shells out to git.
    Calls Test-CommandExists internally.
  #>
  [CmdletBinding()]
  param()

  if (-not (Test-CommandExists -Name 'git')) {
    throw "Required command 'git' was not found in PATH."
  }
}

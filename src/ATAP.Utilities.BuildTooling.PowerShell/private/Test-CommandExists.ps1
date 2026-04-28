function Test-CommandExists {
  <#
  .SYNOPSIS
    Checks whether a command is available in the current session.
  .DESCRIPTION
    Returns $true if the named command (cmdlet, function, alias, or external
    application) can be resolved, $false otherwise.  Internal helper used by
    Assert-GitAvailable.
  .PARAMETER Name
    The command name to look up.
  #>
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Name
  )

  $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Test-ParityAdministrator {
  <#
  .SYNOPSIS
    Reports whether the current Windows process token holds the Administrator role.
  .DESCRIPTION
    Used at the remediation entry point. Does not request elevation or change rights.
    Identity lookup failures propagate to the caller; they never grant permission.
  #>
  [CmdletBinding()]
  [OutputType([bool])]
  param()

  $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  try {
    $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
  } finally {
    if ($null -ne $identity) { $identity.Dispose() }
  }
}

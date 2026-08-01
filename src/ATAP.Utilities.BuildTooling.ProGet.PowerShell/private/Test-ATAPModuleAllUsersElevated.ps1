<#
.SYNOPSIS
Reports whether the current process holds the Administrator role.

.DESCRIPTION
An AllUsers install writes under Program Files, so Install-ATAPModuleAllUsers checks this first and
exits with a distinct status rather than failing partway through with an access-denied error.

Named ...Elevated rather than the standalone script's ...Installed: the original name read as
"is the module installed", which is not what it answers.

.OUTPUTS
System.Boolean

.EXAMPLE
if (-not (Test-ATAPModuleAllUsersElevated)) { throw 'Run elevated.' }

.NOTES
Task 13.76.c. Promoted from the _Planning CodexMisstepFixes standalone installer.
#>
function Test-ATAPModuleAllUsersElevated {
  [CmdletBinding()]
  [OutputType([bool])]
  param()

  begin {
    $fn = 'Test-ATAPModuleAllUsersElevated'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

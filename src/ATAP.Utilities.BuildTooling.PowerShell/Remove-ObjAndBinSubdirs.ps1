[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [string]$path
)

# The ATAP.Utilities.BuildTooling.psm1 Module contains all PowerShell code that assists MSBuild or Visual Studio / Visual Studio Code tasks
# If the solution uses the ATAP.Utilities.BuildTooling.psm1 module, it is typicallly found somewhere within the $PSModulePath.
write-verbose "psModulePath = $($env:psmodulepath.Split(';') -join [environment]::NewLine)"

Remove-ObjAndBinSubdirs $path -WhatIf:$WhatIfPreference -Verbose:$VerbosePreference

[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[parameter(mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$path
)

# The BuildTooling Module contains all PowerShell code that assists MSBild or Visual Studio tasks
# The standard place to find it is from the $solutiondir/.build/TBD
$splitpsModulePath = $env:psmodulepath.Split( ';')
write-verbose "psModulePath = $($splitpsModulePath -join [environment]::NewLine) "
Import-Module ATAP.Utilities.BuildTooling.psm1

Remove-ObjAndBinSubdirs $path -WhatIf:$WhatIfPreference -Verbose:$VerbosePreference




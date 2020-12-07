[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[parameter(mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$itempath
	,[parameter(mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$solutionpath
	,[parameter(mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$projectpath
)

# The BuildTooling Module contains all PowerShell code that assists MSBild or Visual Studio tasks
# The standard place to find it is from the $solutiondir/.build/TBD
Import-Module ATAP.Utilities.BuildTooling.psm1

Remove-ObjAndBinSubdirs $itempath $solutionpath




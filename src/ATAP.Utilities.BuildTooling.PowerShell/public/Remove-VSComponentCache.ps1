#
# Remove_VSComponentCache.ps1
#
[CmdletBinding(SupportsShouldProcess=$true)]

# The BuildTooling Module contains all PowerShell code that assists MSBild or Visual Studio tasks
# The standard place to find it is from the $solutiondir/.build/TBD
Import-Module ATAP.Utilities.BuildTooling.psm1

# Call the function of the same name in the module.
Empty-NuGetCaches.

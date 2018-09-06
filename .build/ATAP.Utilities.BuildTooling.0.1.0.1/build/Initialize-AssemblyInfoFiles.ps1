#
# Initialize-AssemblyInfoFiles.ps1
#

[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [string]$projlist = "",
    [string]$sourcepath = "C:\Dropbox\whertzing\GitHub\ATAP.Utilities"

)
function Initialize-AssemblyInfoFiles {
[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [string]$projlist = "",
    [string]$sourcepath = "C:\Dropbox\whertzing\GitHub\ATAP.Utilities"

)
  Write-Host "yep"
}

Initialize-AssemblyInfoFiles $projlist $sourcepath

[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [string]$basepath = "C:\Dropbox\whertzing\GitHub\ATAP.Utilities"

)


Function remove-objandBin {
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSet')]
    Param(
        [Parameter(Mandatory=$True)]
        [string]$path
    )


}



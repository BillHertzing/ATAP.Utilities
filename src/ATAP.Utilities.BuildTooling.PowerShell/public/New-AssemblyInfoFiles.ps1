
function New-AssemblyInfoFiles {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [string]$projlist = ''
    ,[string]$sourcepath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'
    ,[string]$AssemblyInfo = '*\Properties'
  )
}


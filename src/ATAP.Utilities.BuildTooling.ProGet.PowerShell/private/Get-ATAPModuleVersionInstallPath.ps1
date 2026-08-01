<#
.SYNOPSIS
Computes the immutable versioned AllUsers install path for a module.

.DESCRIPTION
PowerShell resolves installed modules as <ModulesRoot>\<Name>\<Version>. Install-ATAPModuleAllUsers
stages into that exact folder and refuses to overwrite an existing one, so this helper is the single
place the layout is expressed.

.PARAMETER ModuleName
Module name (the folder directly under the modules root).

.PARAMETER RequiredVersion
Exact version string; becomes the leaf folder name.

.PARAMETER ModulesRoot
Modules root. Defaults to the PowerShell 7 AllUsers root.

.OUTPUTS
System.String

.EXAMPLE
Get-ATAPModuleVersionInstallPath -ModuleName 'ATAP.Utilities.BuildTooling.Common.PowerShell' -RequiredVersion '0.1.8'

.NOTES
Task 13.76.c. Promoted from the _Planning CodexMisstepFixes standalone installer.
#>
function Get-ATAPModuleVersionInstallPath {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ModuleName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RequiredVersion,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ModulesRoot = 'C:\Program Files\PowerShell\Modules'
  )

  begin {
    $fn = 'Get-ATAPModuleVersionInstallPath'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    return (Join-Path -Path (Join-Path -Path $ModulesRoot -ChildPath $ModuleName) -ChildPath $RequiredVersion)
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

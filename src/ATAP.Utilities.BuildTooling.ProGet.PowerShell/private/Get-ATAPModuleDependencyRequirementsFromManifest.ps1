<#
.SYNOPSIS
Reads RequiredModules from a module manifest.

.DESCRIPTION
Uses Import-PowerShellDataFile, which parses the manifest as data and never executes it. A manifest
with no RequiredModules, or a null one, yields an empty array so the caller's floor check is a
clean no-op rather than an error.

.PARAMETER ModuleManifestPath
Path to the .psd1 inside the expanded package.

.OUTPUTS
System.Object[] of RequiredModules entries.

.EXAMPLE
Get-ATAPModuleDependencyRequirementsFromManifest -ModuleManifestPath $psd1

.NOTES
Task 13.76.c. Promoted from the _Planning CodexMisstepFixes standalone installer.
#>
function Get-ATAPModuleDependencyRequirementsFromManifest {
  [CmdletBinding()]
  [OutputType([object[]])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ModuleManifestPath
  )

  begin {
    $fn = 'Get-ATAPModuleDependencyRequirementsFromManifest'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $manifest = Import-PowerShellDataFile -Path $ModuleManifestPath
    if (-not $manifest.ContainsKey('RequiredModules')) { return @() }
    if ($null -eq $manifest.RequiredModules) { return @() }
    return @($manifest.RequiredModules)
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

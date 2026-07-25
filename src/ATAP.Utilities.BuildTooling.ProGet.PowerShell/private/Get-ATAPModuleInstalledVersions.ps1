<#
.SYNOPSIS
Maps every available module name to its highest installed version.

.DESCRIPTION
Builds the installed-version floor that Get-ATAPModuleDependencyFloorViolations checks a package's
RequiredModules against. Keeps the highest version per name because a dependency floor is satisfied
by the best available copy, wherever on PSModulePath it sits.

.OUTPUTS
System.Collections.Hashtable of module name to version string.

.EXAMPLE
$installed = Get-ATAPModuleInstalledVersions

.NOTES
Task 13.76.c. Promoted from the _Planning CodexMisstepFixes standalone installer.
#>
function Get-ATAPModuleInstalledVersions {
  [CmdletBinding()]
  [OutputType([hashtable])]
  param()

  begin {
    $fn = 'Get-ATAPModuleInstalledVersions'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $installed = @{}
    foreach ($module in (Get-Module -ListAvailable -ErrorAction SilentlyContinue)) {
      if (-not $module -or -not $module.Name) { continue }
      if (-not $installed.ContainsKey($module.Name) -or ([version]$module.Version -gt [version]$installed[$module.Name])) {
        $installed[$module.Name] = $module.Version.ToString()
      }
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Enumerated $($installed.Count) installed module name(s)."
    return $installed
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

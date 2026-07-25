<#
.SYNOPSIS
Reports declared dependencies that are absent or below their minimum version.

.DESCRIPTION
Checks each RequiredModules entry against what is already INSTALLED, rather than asking the feed to
resolve it. That distinction is the whole point of the canonical installer: the ATAP stable feed does
not carry external dependencies such as PSFramework, so PowerShellGet's own resolution fails there
(Sprint 0013 Task 13.76.e). Validating the installed floor lets a correct install proceed without
improvising -SkipDependencies, and still fails closed when a dependency really is missing.

Accepts both RequiredModules shapes: a bare string, or a hashtable/object with ModuleName/Name plus
ModuleVersion/RequiredVersion. An unparseable version is treated as 0.0.0 (no floor) rather than
throwing, because a malformed manifest entry must not masquerade as a satisfied dependency.

.PARAMETER DependencyRequirements
RequiredModules entries from the package manifest.

.PARAMETER InstalledModules
Map of module name to highest installed version string.

.OUTPUTS
System.Management.Automation.PSCustomObject[] with Dependency, RequiredMinimum, Installed, Status
('Missing' or 'BelowMinimum'). Empty when every floor is satisfied.

.EXAMPLE
Get-ATAPModuleDependencyFloorViolations -DependencyRequirements $reqs -InstalledModules $installed

.NOTES
Task 13.76.c. Promoted from the _Planning CodexMisstepFixes standalone installer.
#>
function Get-ATAPModuleDependencyFloorViolations {
  [CmdletBinding()]
  [OutputType([PSCustomObject[]])]
  param(
    # AllowNull as well as AllowEmptyCollection: a manifest with no RequiredModules yields an
    # empty array, which the pipeline unwraps to $null at the call site. A package without
    # dependencies must be installable, not a binding error.
    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [AllowEmptyCollection()]
    [array]$DependencyRequirements,

    [Parameter(Mandatory = $true)]
    [hashtable]$InstalledModules
  )

  begin {
    $fn = 'Get-ATAPModuleDependencyFloorViolations'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $violations = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($dependency in @($DependencyRequirements)) {
      $dependencyName = $null
      $minimumVersion = [version]'0.0.0'

      if ($dependency -is [string]) {
        $dependencyName = $dependency
      }
      else {
        if ($dependency.ModuleName) { $dependencyName = [string]$dependency.ModuleName }
        elseif ($dependency.Name) { $dependencyName = [string]$dependency.Name }

        if ($dependency.ModuleVersion) {
          try { $minimumVersion = [version]$dependency.ModuleVersion } catch { $minimumVersion = [version]'0.0.0' }
        }
        elseif ($dependency.RequiredVersion) {
          try { $minimumVersion = [version]$dependency.RequiredVersion } catch { $minimumVersion = [version]'0.0.0' }
        }
      }

      if (-not $dependencyName) { continue }

      if (-not $InstalledModules.ContainsKey($dependencyName)) {
        $violations.Add([pscustomobject]@{
            Dependency      = $dependencyName
            RequiredMinimum = $minimumVersion.ToString()
            Installed       = ''
            Status          = 'Missing'
          })
        continue
      }

      try { $installedVersion = [version]$InstalledModules[$dependencyName] }
      catch { $installedVersion = [version]'0.0.0' }

      if ($installedVersion -lt $minimumVersion) {
        $violations.Add([pscustomobject]@{
            Dependency      = $dependencyName
            RequiredMinimum = $minimumVersion.ToString()
            Installed       = $installedVersion.ToString()
            Status          = 'BelowMinimum'
          })
      }
    }

    return $violations.ToArray()
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

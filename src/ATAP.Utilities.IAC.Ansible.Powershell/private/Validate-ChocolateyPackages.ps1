<#
.SYNOPSIS
Validates installed Chocolatey packages against expected packages list.

.DESCRIPTION
Reads InstalledChocolateyPackages.json file and compares the expected packages
with actual installed Chocolatey packages on the system. Reports any differences
including missing packages, unexpected packages, and packages that should not
be installed but are present.

.PARAMETER JsonPath
Path to InstalledChocolateyPackages.json file.

.OUTPUTS
None. Displays comparison results via Write-PSFMessage and console output.

.EXAMPLE
Validate-ChocolateyPackages -JsonPath './InstalledChocolateyPackages.json'

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Validate-ChocolateyPackages {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string]$JsonPath = './InstalledChocolateyPackages.json'
  )

  BEGIN {
    $fn = 'Validate-ChocolateyPackages'
    $mn = 'ATAP.Utilities.IAC.Ansible.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Load required helper functions
    try {
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    # Snippet: Check and populate simple parameter
    #$JsonPath = Get-PVal JsonPath $PSBoundParameters JsonPath
  }

  PROCESS {
    # Snippet: Try-Catch-Finally
    try {
      # Read expected packages from JSON file
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Reading expected packages from $JsonPath"

      if (-not (Test-Path $JsonPath)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "JSON file not found: $JsonPath"
        throw "JSON file not found: $JsonPath"
      }

      $expectedPackages = Get-Content -Path $JsonPath -Raw | ConvertFrom-Json
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Loaded $($expectedPackages.Count) expected packages from JSON"

      # Get actually installed Chocolatey packages
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Retrieving installed Chocolatey packages"

      $installedPackagesRaw = & choco list 2>&1
      if ($LASTEXITCODE -ne 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to retrieve installed packages: $installedPackagesRaw"
        throw "Failed to retrieve installed packages"
      }

      # Parse choco list output (format: "packagename version")
      $installedPackages = @{}
      foreach ($line in $installedPackagesRaw) {
        # Skip summary lines like "184 packages installed." or lines without proper version format
        if ($line -match '^\s*\d+\s+packages?\s+installed') {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Skipping summary line: $line"
          continue
        }

        # Match package lines with valid package names (alphanumeric with hyphens/dots) and version numbers
        if ($line -match '^([a-zA-Z][a-zA-Z0-9\-\.]+)\s+(\d+[\.\d]*)') {
          $pkgName = $Matches[1]
          $pkgVersion = $Matches[2]
          $installedPackages[$pkgName] = $pkgVersion
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Found package: $pkgName = $pkgVersion"
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Found $($installedPackages.Count) installed Chocolatey packages"

      # Build expected package sets
      $expectedToInstall = @{}
      $expectedNotInstalled = @{}

      foreach ($pkg in $expectedPackages) {
        if ($pkg.Notes -and $pkg.Notes -match 'NOT INSTALLED') {
          $expectedNotInstalled[$pkg.PackageName] = $pkg
        }
        else {
          $expectedToInstall[$pkg.PackageName] = $pkg
        }
      }

      # Compare packages
      $missingPackages = @()
      $unexpectedPackages = @()
      $shouldNotBeInstalled = @()
      $correctlyInstalled = @()
      $correctlyNotInstalled = @()
      $dependentPackages = @()

      # Check for missing packages (expected to be installed but aren't)
      foreach ($pkgName in $expectedToInstall.Keys) {
        if (-not $installedPackages.ContainsKey($pkgName)) {
          $missingPackages += $expectedToInstall[$pkgName]
        }
        else {
          $correctlyInstalled += $pkgName
        }
      }

      # Check for packages that should not be installed but are
      foreach ($pkgName in $expectedNotInstalled.Keys) {
        if ($installedPackages.ContainsKey($pkgName)) {
          $shouldNotBeInstalled += [PSCustomObject]@{
            PackageName = $pkgName
            Version     = $installedPackages[$pkgName]
            Reason      = $expectedNotInstalled[$pkgName].Notes
          }
        }
        else {
          $correctlyNotInstalled += $pkgName
        }
      }

      # Helper function to check if a package is a dependent of an expected package
      function Test-IsDependentPackage {
        param($pkgName, $expectedPackages)

        # Common dependency suffixes
        $dependencySuffixes = @('.install', '.extension', '.portable', '.commandline')

        foreach ($suffix in $dependencySuffixes) {
          if ($pkgName -match "^(.+)$([regex]::Escape($suffix))$") {
            $basePackageName = $Matches[1]
            if ($expectedPackages.ContainsKey($basePackageName)) {
              return @{
                IsDependent = $true
                BasePackage = $basePackageName
                Suffix      = $suffix
              }
            }
          }
        }

        return @{ IsDependent = $false }
      }

      # Check for unexpected packages (installed but not in expected list)
      foreach ($pkgName in $installedPackages.Keys) {
        if (-not $expectedToInstall.ContainsKey($pkgName) -and -not $expectedNotInstalled.ContainsKey($pkgName)) {
          # Check if this is a dependent package
          $dependencyCheck = Test-IsDependentPackage -pkgName $pkgName -expectedPackages $expectedToInstall

          if ($dependencyCheck.IsDependent) {
            $dependentPackages += [PSCustomObject]@{
              PackageName = $pkgName
              Version     = $installedPackages[$pkgName]
              BasePackage = $dependencyCheck.BasePackage
              Suffix      = $dependencyCheck.Suffix
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Recognized dependent package: $pkgName (base: $($dependencyCheck.BasePackage))"
          }
          else {
            $unexpectedPackages += [PSCustomObject]@{
              PackageName = $pkgName
              Version     = $installedPackages[$pkgName]
            }
          }
        }
      }

      # Display results
      Write-Host "`n========================================" -ForegroundColor Cyan
      Write-Host "Chocolatey Package Validation Results" -ForegroundColor Cyan
      Write-Host "========================================" -ForegroundColor Cyan

      Write-Host "`nSummary:" -ForegroundColor White
      Write-Host "  Expected to install: $($expectedToInstall.Count)" -ForegroundColor Gray
      Write-Host "  Correctly installed: $($correctlyInstalled.Count)" -ForegroundColor Green
      Write-Host "  Missing packages: $($missingPackages.Count)" -ForegroundColor $(if ($missingPackages.Count -gt 0) { 'Red' } else { 'Green' })
      Write-Host "  Expected NOT installed: $($expectedNotInstalled.Count)" -ForegroundColor Gray
      Write-Host "  Correctly NOT installed: $($correctlyNotInstalled.Count)" -ForegroundColor Green
      Write-Host "  Should NOT be installed: $($shouldNotBeInstalled.Count)" -ForegroundColor $(if ($shouldNotBeInstalled.Count -gt 0) { 'Red' } else { 'Green' })
      Write-Host "  Dependent packages: $($dependentPackages.Count)" -ForegroundColor Cyan
      Write-Host "  Unexpected packages: $($unexpectedPackages.Count)" -ForegroundColor $(if ($unexpectedPackages.Count -gt 0) { 'Yellow' } else { 'Green' })
      Write-Host "  Total installed on system: $($installedPackages.Count)" -ForegroundColor Gray

      if ($missingPackages.Count -gt 0) {
        Write-Host "`nMissing Packages (Expected but NOT Installed):" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        foreach ($pkg in $missingPackages | Sort-Object PackageName) {
          Write-Host "  - $($pkg.PackageName)" -ForegroundColor Red
          if ($pkg.AddedParameters) {
            Write-Host "    Parameters: $($pkg.AddedParameters)" -ForegroundColor Gray
          }
          if ($pkg.Notes) {
            Write-Host "    Notes: $($pkg.Notes)" -ForegroundColor Gray
          }
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Found $($missingPackages.Count) missing packages"
      }

      if ($shouldNotBeInstalled.Count -gt 0) {
        Write-Host "`nPackages That Should NOT Be Installed:" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        foreach ($pkg in $shouldNotBeInstalled | Sort-Object PackageName) {
          Write-Host "  - $($pkg.PackageName) (Version: $($pkg.Version))" -ForegroundColor Red
          Write-Host "    Reason: $($pkg.Reason)" -ForegroundColor Gray
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Found $($shouldNotBeInstalled.Count) packages that should not be installed"
      }

      if ($dependentPackages.Count -gt 0) {
        Write-Host "`nDependent Packages (Automatically installed dependencies):" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        foreach ($pkg in $dependentPackages | Sort-Object PackageName) {
          Write-Host "  - $($pkg.PackageName) (Version: $($pkg.Version))" -ForegroundColor Cyan
          Write-Host "    Base package: $($pkg.BasePackage), Suffix: $($pkg.Suffix)" -ForegroundColor Gray
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Found $($dependentPackages.Count) dependent packages"
      }

      if ($unexpectedPackages.Count -gt 0) {
        Write-Host "`nUnexpected Packages (Installed but NOT in expected list):" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        foreach ($pkg in $unexpectedPackages | Sort-Object PackageName) {
          Write-Host "  - $($pkg.PackageName) (Version: $($pkg.Version))" -ForegroundColor Yellow
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Found $($unexpectedPackages.Count) unexpected packages"
      }

      if ($missingPackages.Count -eq 0 -and $shouldNotBeInstalled.Count -eq 0 -and $unexpectedPackages.Count -eq 0) {
        Write-Host "`n✓ All packages match expected configuration!" -ForegroundColor Green
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "All packages match expected configuration"
      }

      Write-Host "`n========================================`n" -ForegroundColor Cyan
    }
    catch {
      $errorMessage = "Failed to validate Chocolatey packages. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

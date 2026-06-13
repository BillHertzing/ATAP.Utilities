function Find-SqlServerSetupExe {
  <#
  .SYNOPSIS
    Locates SQL Server Setup.exe for use by sprint lifecycle cmdlets.
  .DESCRIPTION
    Queries the SQL Server installation registry for each known major version
    (2022, 2019, 2017, 2016, 2014) and returns the path to Setup.exe.
    Falls back to a list of known temp/staging directories if registry lookup
    yields nothing. Throws with a remediation message if Setup.exe cannot be found.
  .OUTPUTS
    [string] — full path to a verified Setup.exe
  .EXAMPLE
    $setupExe = Find-SqlServerSetupExe
  .LINK
    New-DeveloperSqlServerInstances
  .LINK
    Remove-DeveloperSqlServerInstances
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param()

  $fn = $MyInvocation.MyCommand.Name
  $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn"

  # Registry version keys, newest first (try newest SQL Server first)
  $versionMap = [ordered]@{
    '160' = 'SQL Server 2022'
    '150' = 'SQL Server 2019'
    '140' = 'SQL Server 2017'
    '130' = 'SQL Server 2016'
    '120' = 'SQL Server 2014'
  }

  foreach ($ver in $versionMap.Keys) {
    $regPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$ver\Tools\Setup"
    if (Test-Path $regPath) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Found registry key for $($versionMap[$ver]): $regPath"
      try {
        $sqlPath = Get-ItemPropertyValue -Path $regPath -Name 'SQLPath' -ErrorAction SilentlyContinue
        if ($sqlPath) {
          $candidate = Join-Path $sqlPath 'Setup.exe'
          if (Test-Path $candidate) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
              -Message "Found Setup.exe via registry ($($versionMap[$ver])): $candidate"
            return $candidate
          }
        }
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
          -Message "Registry key present but SQLPath value absent for $($versionMap[$ver])"
      }
    }
  }

  # Fallback: known local staging/temp paths
  $fallbackPaths = @(
    'D:\Temp\SQLExpr\extracted\SETUP.EXE'
    'D:\Temp\SQL\SETUP.EXE'
    'C:\Temp\SQLExpr\extracted\SETUP.EXE'
    'C:\Temp\SQL\SETUP.EXE'
  )

  foreach ($path in $fallbackPaths) {
    if (Test-Path $path) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Found Setup.exe at fallback path: $path"
      return $path
    }
  }

  throw @"
SQL Server Setup.exe was not found via registry or known fallback paths.

To resolve:
  1. Download the SQL Server Express installer from Microsoft.
  2. Extract it to D:\Temp\SQLExpr\extracted\ by running:
       SqlExpress.exe /x:D:\Temp\SQLExpr\extracted
  3. Verify that D:\Temp\SQLExpr\extracted\SETUP.EXE exists.

Alternatively, ensure a full SQL Server installation is present so the registry key
  HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\<version>\Tools\Setup
is populated with a valid SQLPath value.
"@
}

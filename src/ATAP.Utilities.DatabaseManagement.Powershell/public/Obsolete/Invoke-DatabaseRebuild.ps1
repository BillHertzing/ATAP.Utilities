<#
.SYNOPSIS
Generic database rebuild cmdlet - wrapper for Rebuild-DatabaseFromFlyway

.DESCRIPTION
This cmdlet provides a wrapper for the Rebuild-DatabaseFromFlyway cmdlet.
For database-specific rebuild scripts that include data loading, see individual projects:
- ATAP.Utilities.Tags\ATAP.Utilities.Tags.Powershell\public\Rebuild-All.ps1
- ATAP.Utilities.Gmail\ATAP.Utilities.Gmail.Powershell\public\Rebuild-All.ps1
- PCMSC\src\PCMSCAutomation\public\Rebuild-All.ps1

.PARAMETER DatabaseName
The name of the database to rebuild.

.PARAMETER Environment
The target environment: 'Development', 'Testing', 'Production', or 'Experimental'. Default is 'Experimental'.

.PARAMETER DatabaseHost
The SQL Server host. Default is 'localhost'.

.OUTPUTS
System.Object
Returns a result object with Success (bool), DatabaseName, Environment, Errors, StartTime, and EndTime.

.EXAMPLE
Invoke-DatabaseRebuild -DatabaseName 'MyDatabase' -Environment 'Development'

.EXAMPLE
Invoke-DatabaseRebuild -DatabaseName 'Tags' -DatabaseHost 'localhost' -Verbose

.NOTES
AI assisted using Powershell.instructions.md as guidelines
This is a generic wrapper - use database-specific scripts for complete rebuild with data loading.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Invoke-DatabaseRebuild {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [string]$DatabaseName,

    [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true)]
    [string]$Environment = 'Experimental',

    [Parameter(Mandatory = $false, Position = 2, ValueFromPipelineByPropertyName = $true)]
    [string]$DatabaseHost = 'localhost'
  )

  BEGIN {
    $fn = 'Invoke-DatabaseRebuild'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Load required helper functions
    try {
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
      if (-not (Get-Command -Name 'Rebuild-DatabaseFromFlyway' -CommandType Function -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'Rebuild-DatabaseFromFlyway.ps1')
      }
    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    # Validate Environment parameter using Get-PVal
    $Environment = Get-PVal -ParameterName 'Environment' -originalPSBoundParameters $PSBoundParameters -DefaultValue $Environment -ValidValues @('Development', 'Testing', 'Production', 'Experimental')
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Environment validated: $Environment"

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "=== Starting Database Rebuild ==="
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Database: $DatabaseName"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Environment: $Environment"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Host: $DatabaseHost"
  }

  PROCESS {
    try {
      if ($PSCmdlet.ShouldProcess($DatabaseName, 'Rebuild database')) {
        $result = Rebuild-DatabaseFromFlyway `
          -DatabaseName $DatabaseName `
          -Environment $Environment `
          -DatabaseHost $DatabaseHost `
          -Verbose:$VerbosePreference

        if ($result.Success) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "=== Database Rebuild Complete ==="
        }
        else {
          $errorMessage = "Database rebuild failed. Errors: $($result.Errors -join '; ')"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }

        return $result
      }
    }
    catch {
      $errorMessage = "Rebuild failed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
      throw
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

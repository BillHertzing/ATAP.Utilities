#r "nuget: Microsoft.Data.SqlClient, 6.1.1"
<#
.SYNOPSIS
Initializes SQL client types for database operations

.DESCRIPTION
Sets up and validates Microsoft.Data.SqlClient types for database connectivity.
Returns a hashtable containing Connection, Command, Parameter, and DbTypeEnum types.
Validates that the Microsoft.Data.SqlClient assembly is loaded before configuring types.

.EXAMPLE
$sqlTypes = Initialize-SQLClient
Initialize SQL client types and return the configured types hashtable

.EXAMPLE
$sqlTypes = Initialize-SQLClient
$connection = New-Object $sqlTypes.Connection
Create a new SQL connection using the initialized types

.INPUTS
None

.OUTPUTS
System.Collections.Hashtable

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Requires Microsoft.Data.SqlClient assembly to be loaded in the current domain

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Initialize-SQLClient {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([hashtable])]
  param ()

  BEGIN {
    $fn = 'Initialize-SQLClient'
    $mn = 'ATAP.Utilities.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Set up SQL client types
    $script:SqlTypes = @{
      Connection = $null
      Command    = $null
      Parameter  = $null
      DbTypeEnum = $null
    }
  }

  PROCESS {
    if ($PSCmdlet.ShouldProcess('Microsoft.Data.SqlClient', 'Initialize SQL client types')) {
      # SqlClient type (prefer Microsoft.Data.SqlClient)
      try {
        Add-Type -AssemblyName 'Microsoft.Data.SqlClient' -ErrorAction Stop
        $script:SqlTypes.Connection = [Microsoft.Data.SqlClient.SqlConnection]
        $script:SqlTypes.Command = [Microsoft.Data.SqlClient.SqlCommand]
        $script:SqlTypes.Parameter = [Microsoft.Data.SqlClient.SqlParameter]
        $script:SqlTypes.DbTypeEnum = [System.Data.SqlDbType]
        Write-PSFMessage -FunctionName $functionName -ModuleName $moduleName -Level Debug -Message 'Using Microsoft.Data.SqlClient'
      }
      catch {
        Add-Type -AssemblyName 'System.Data' -ErrorAction Stop
        $script:SqlTypes.Connection = [System.Data.SqlClient.SqlConnection]
        $script:SqlTypes.Command = [System.Data.SqlClient.SqlCommand]
        $script:SqlTypes.Parameter = [System.Data.SqlClient.SqlParameter]
        $script:SqlTypes.DbTypeEnum = [System.Data.SqlDbType]
        Write-PSFMessage -FunctionName $functionName -ModuleName $moduleName -Level Debug -Message 'Falling back to System.Data.SqlClient'
      }

      <#
      # Snippet used: "Try-Catch-Finally"
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Validating Microsoft.Data.SqlClient assembly"

        # Validate the assembly was loaded
        $sqlClientAssembly = [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.FullName -like '*Microsoft.Data.SqlClient*' }

        if (-not $sqlClientAssembly) {
          $errorMessage = "Microsoft.Data.SqlClient assembly not found in current domain. Exception: Assembly not loaded"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Configuring SQL client types"

        $script:SqlTypes.Connection = [Microsoft.Data.SqlClient.SqlConnection]
        $script:SqlTypes.Command = [Microsoft.Data.SqlClient.SqlCommand]
        $script:SqlTypes.Parameter = [Microsoft.Data.SqlClient.SqlParameter]
        $script:SqlTypes.DbTypeEnum = [System.Data.SqlDbType]

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Using Microsoft.Data.SqlClient'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Successfully initialized SQL client types"
    }
    catch {
      $errorMessage = "Failed to configure Microsoft.Data.SqlClient types. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw # the unadorned throw will throw the $_ exception and keep the stack trace intact
    }
#>
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
    return $script:SqlTypes
  }
}

<#
    # SqlClient type (prefer Microsoft.Data.SqlClient)
    $script:SqlTypes = @{
      Connection = $null
      Command    = $null
      Parameter  = $null
      DbTypeEnum = $null
    }
    try {
      Add-Type -AssemblyName 'Microsoft.Data.SqlClient' -ErrorAction Stop
      $script:SqlTypes.Connection = [Microsoft.Data.SqlClient.SqlConnection]
      $script:SqlTypes.Command = [Microsoft.Data.SqlClient.SqlCommand]
      $script:SqlTypes.Parameter = [Microsoft.Data.SqlClient.SqlParameter]
      $script:SqlTypes.DbTypeEnum = [System.Data.SqlDbType]
      Write-PSFMessage -FunctionName $functionName -ModuleName $moduleName -Level Debug -Message 'Using Microsoft.Data.SqlClient'
    }
    catch {
      Add-Type -AssemblyName 'System.Data' -ErrorAction Stop
      $script:SqlTypes.Connection = [System.Data.SqlClient.SqlConnection]
      $script:SqlTypes.Command = [System.Data.SqlClient.SqlCommand]
      $script:SqlTypes.Parameter = [System.Data.SqlClient.SqlParameter]
      $script:SqlTypes.DbTypeEnum = [System.Data.SqlDbType]
      Write-PSFMessage -FunctionName $functionName -ModuleName $moduleName -Level Debug -Message 'Falling back to System.Data.SqlClient'
    }
#>

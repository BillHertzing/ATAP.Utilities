<#
.SYNOPSIS
Builds SQL Server connection strings based on database host, name, connection method, and authentication parameters.

.DESCRIPTION
Creates properly formatted SQL Server connection strings supporting both integrated Windows authentication
and SQL Server authentication. Handles various connection methods (tcp, np, lpc) and retrieves passwords
from vault when using named logins. Can optionally format as JDBC connection strings for Flyway compatibility.

.PARAMETER DatabaseHost
The hostname or IP address of the database server.

.PARAMETER DatabaseName
The name of the database to connect to.

.PARAMETER ConnectionMethod
The connection method to use. Valid values are 'tcp', 'np', 'lpc', or 'default'.

.PARAMETER SqlInstance
Optional SQL Server instance name. When specified, will be appended to the hostname.

.PARAMETER UseNamedLogin
Boolean indicating whether to use SQL Server authentication instead of Windows authentication.

.PARAMETER LoginName
The login name for SQL Server authentication or Windows authentication.

.PARAMETER CredentialsKey
The vault key to retrieve the password for SQL Server authentication.

.PARAMETER AsJDBC
Switch parameter to format the connection string as JDBC for Flyway compatibility.

.OUTPUTS
System.String
Returns a properly formatted SQL Server connection string or JDBC connection string.

.EXAMPLE
$connStr = Get-ConnectionString -DatabaseHost 'sqlserver01' -DatabaseName 'MyDB' -ConnectionMethod 'tcp'
Creates a connection string using Windows authentication over TCP.

.EXAMPLE
$connStr = Get-ConnectionString -DatabaseHost 'sqlserver01' -DatabaseName 'MyDB' -ConnectionMethod 'tcp' -UseNamedLogin $true -LoginName 'sqluser' -CredentialsKey 'SqlUserPassword'
Creates a connection string using SQL Server authentication.

.EXAMPLE
$connStr = Get-ConnectionString -DatabaseHost 'sqlserver01' -DatabaseName 'MyDB' -ConnectionMethod 'tcp' -AsJDBC
Creates a JDBC connection string for Flyway using Windows authentication.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Get-ConnectionString {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
    [string]$DatabaseName,

    [Parameter(Mandatory = $true, Position = 2, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('tcp', 'np', 'lpc', 'default')]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false, Position = 3, ValueFromPipelineByPropertyName = $true)]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false, Position = 4, ValueFromPipelineByPropertyName = $true)]
    [bool]$UseNamedLogin = $false,

    [Parameter(Mandatory = $false, Position = 6, ValueFromPipelineByPropertyName = $true)]
    [string]$CredentialsKey,

    [Parameter(Mandatory = $false, Position = 7, ValueFromPipelineByPropertyName = $true)]
    [switch]$AsJDBC
  )

  BEGIN {
    $fn = 'Get-ConnectionString'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Check and populate simple parameter - DatabaseHost
    $DatabaseHost = Get-PVal -ParameterName 'DatabaseHost' -originalPSBoundParameters $PSBoundParameters -dottedPath 'DatabaseHost' -DefaultValue $DatabaseHost

    # Check and populate simple parameter - DatabaseName
    $DatabaseName = Get-PVal -ParameterName 'DatabaseName' -originalPSBoundParameters $PSBoundParameters -dottedPath 'DatabaseName' -DefaultValue $DatabaseName

    # Check and populate simple parameter - ConnectionMethod
    $ConnectionMethod = Get-PVal -ParameterName 'ConnectionMethod' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ConnectionMethod' -DefaultValue $ConnectionMethod

    # Check and populate simple parameter - SqlInstance (optional)
    if ($PSBoundParameters.ContainsKey('SqlInstance')) {
      $SqlInstance = Get-PVal -ParameterName 'SqlInstance' -originalPSBoundParameters $PSBoundParameters -dottedPath 'SqlInstance' -DefaultValue $SqlInstance
    }

    # Check and populate simple parameter - UseNamedLogin (optional)
    $UseNamedLogin = Get-PVal -ParameterName 'UseNamedLogin' -originalPSBoundParameters $PSBoundParameters -dottedPath 'UseNamedLogin' -DefaultValue $UseNamedLogin -AsType ([bool])

    # Check and populate simple parameter - CredentialsKey (optional when UseNamedLogin is true)
    if ($PSBoundParameters.ContainsKey('CredentialsKey')) {
      $CredentialsKey = Get-PVal -ParameterName 'CredentialsKey' -originalPSBoundParameters $PSBoundParameters -dottedPath 'CredentialsKey' -DefaultValue $CredentialsKey
    }

    # Check and populate simple parameter - AsJDBC (optional)
    #$AsJDBC = Get-PVal AsJDBC $PSBoundParameters AsJDBC -AsType bool

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Building connection string for Database: $DatabaseName on Host: $DatabaseHost$(if($AsJDBC){' as JDBC format'})"
  }

  PROCESS {
    try {
      # Determine authentication mode
      $isIntegrated = $false
      # Get Credentials from vault if needed
      if ($UseNamedLogin -and $CredentialsKey) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Retrieving credentials from vault using key: $CredentialsKey"
        # ToDo: rename to Get-CredentialsFromVault
        $script:credentials = Get-VaultPassword -VaultKey $CredentialsKey
        # ToDo: throw if $credentials are
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'credentials retrieved successfully from vault'
        $script:loginUser = $script:credentials.UserName
        $script:loginPassword = $script:credentials.Password
        # ToDo: add code to ensure loginUser is not null or empty, throw if null or empty
        $isIntegrated = $true
      }
      if (-not $UseNamedLogin) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Using integrated Windows authentication'
      }
      else {
        if (Test-WindowsLoginName $LoginName) {
          $isIntegrated = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Using Windows authentication for domain login'
        }
        else {
          $isIntegrated = $false
          $sQLUser = $LoginName
          $sQLUPwd = $script:loginPassword
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Using SQL Server authentication'
        }
      }

      # Determine if we should include the instance name
      # Default instances (MSSQLSERVER) or empty instance names should not be included
      $includeInstance = $false
      if (-not [string]::IsNullOrWhiteSpace($SqlInstance)) {
        # Check if it's not a default instance marker (case-insensitive comparison)
        $defaultInstanceMarkers = @('MSSQLSERVER', 'Default', '(default)', 'DEFAULT', 'SQLEXPRESS')
        if ($SqlInstance -notin $defaultInstanceMarkers -and $SqlInstance.ToLowerInvariant() -ne 'mssqlserver') {
          $includeInstance = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using named instance: $SqlInstance"
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Skipping default instance marker: $SqlInstance"
        }
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "No instance name specified, connecting to default instance"
      }

      if ($AsJDBC) {
        # Build JDBC connection string for Flyway
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Building JDBC connection string for Flyway'

        # Build server specification for JDBC
        # Only include instance name for named instances, not default instances
        $serverSpec = if ($includeInstance) {
          "${DatabaseHost};instanceName=$SqlInstance"
        }
        else {
          $DatabaseHost
        }

        $connStr = [System.Text.StringBuilder]::new()
        [void]$connStr.Append("jdbc:sqlserver://$serverSpec;databaseName=$DatabaseName;")

        if ($isIntegrated) {
          [void]$connStr.Append('integratedSecurity=true;trustServerCertificate=true;')
        }
        else {
          [void]$connStr.Append("user=$sQLUser;password=$sQLUPwd;encrypt=true;trustServerCertificate=true;")
        }

        $connectionString = $connStr.ToString()
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "JDBC server specification: jdbc:sqlserver://$serverSpec"
      }
      else {
        # Build standard .NET connection string
        $prefix = switch ($ConnectionMethod) {
          'tcp' { 'tcp:' }
          'np' { 'np:' }
          'lpc' { 'lpc:' }
          default { '' }
        }

        # Only include instance name for named instances
        $serverSpec = if ($includeInstance) {
          "$prefix$DatabaseHost\$SqlInstance"
        }
        else {
          "$prefix$DatabaseHost"
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Server specification: $serverSpec"

        $connStr = [System.Text.StringBuilder]::new()
        [void]$connStr.Append("Server=$serverSpec;Database=$DatabaseName;")
        if ($isIntegrated) {
          [void]$connStr.Append('Integrated Security=True;TrustServerCertificate=True;')
        }
        else {
          [void]$connStr.Append("User ID=$sQLUser;Password=$sQLUPwd;Encrypt=True;TrustServerCertificate=True;")
        }

        $connectionString = $connStr.ToString()
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Connection string built successfully (format: $(if($AsJDBC){'JDBC'}else{'.NET'}), authentication: $(if($isIntegrated){'Integrated'}else{'SQL'}))"

      if ($PSCmdlet.ShouldProcess($DatabaseHost, "Return $(if($AsJDBC){'JDBC '}else{''})connection string")) {
        return $connectionString
      }
    }
    catch {
      $errorMessage = "Failed to build connection string. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      # ToDo: accumulate the errors; potentially add to 'Problems'
      throw # the unadorned throw will throw the $_ exception and keep the stack trace intact
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }
  End {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }

}

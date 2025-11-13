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

.PARAMETER LoginPasswordVaultKey
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
$connStr = Get-ConnectionString -DatabaseHost 'sqlserver01' -DatabaseName 'MyDB' -ConnectionMethod 'tcp' -UseNamedLogin $true -LoginName 'sqluser' -LoginPasswordVaultKey 'SqlUserPassword'
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

    [Parameter(Mandatory = $false, Position = 5, ValueFromPipelineByPropertyName = $true)]
    [string]$LoginName,

    [Parameter(Mandatory = $false, Position = 6, ValueFromPipelineByPropertyName = $true)]
    [string]$LoginPasswordVaultKey,

    [Parameter(Mandatory = $false, Position = 7, ValueFromPipelineByPropertyName = $true)]
    [switch]$AsJDBC
  )

  BEGIN {
    $fn = 'Get-ConnectionString'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Check and populate simple parameter - DatabaseHost
    $DatabaseHost = Get-PVal DatabaseHost $PSBoundParameters DatabaseHost

    # Check and populate simple parameter - DatabaseName
    $DatabaseName = Get-PVal DatabaseName $PSBoundParameters DatabaseName

    # Check and populate simple parameter - ConnectionMethod
    $ConnectionMethod = Get-PVal ConnectionMethod $PSBoundParameters ConnectionMethod

    # Check and populate simple parameter - SqlInstance (optional)
    if ($PSBoundParameters.ContainsKey('SqlInstance')) {
      $SqlInstance = Get-PVal SqlInstance $PSBoundParameters SqlInstance
    }

    # Check and populate simple parameter - UseNamedLogin (optional)
    $UseNamedLogin = Get-PVal UseNamedLogin $PSBoundParameters UseNamedLogin -AsType bool

    # Check and populate simple parameter - LoginName (optional when UseNamedLogin is true)
    if ($UseNamedLogin -and $PSBoundParameters.ContainsKey('LoginName')) {
      $LoginName = Get-PVal LoginName $PSBoundParameters LoginName
    }

    # Check and populate simple parameter - LoginPasswordVaultKey (optional when UseNamedLogin is true)
    if ($PSBoundParameters.ContainsKey('LoginPasswordVaultKey')) {
      $LoginPasswordVaultKey = Get-PVal LoginPasswordVaultKey $PSBoundParameters LoginPasswordVaultKey
    }

    # Check and populate simple parameter - AsJDBC (optional)
    #$AsJDBC = Get-PVal AsJDBC $PSBoundParameters AsJDBC -AsType bool

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Building connection string for Database: $DatabaseName on Host: $DatabaseHost$(if($AsJDBC){' as JDBC format'})"
  }

  PROCESS {
    try {
      # Get password from vault if needed
      if ($UseNamedLogin -and $LoginPasswordVaultKey) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Retrieving password from vault using key: $LoginPasswordVaultKey"
        $script:loginPassword = Get-VaultPassword -VaultKey $LoginPasswordVaultKey
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Password retrieved successfully from vault'
      }

      # Determine authentication mode
      $isIntegrated = $false
      if (-not $UseNamedLogin) {
        $isIntegrated = $true
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

      if ($AsJDBC) {
        # Build JDBC connection string for Flyway
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Building JDBC connection string for Flyway'

        # Build server specification for JDBC
        $serverSpec = if ($SqlInstance) { "$DatabaseHost\$SqlInstance" } else { "$DatabaseHost" }

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
        $serverSpec = if ($SqlInstance) { "$prefix$DatabaseHost\$SqlInstance" } else { "$prefix$DatabaseHost" }

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

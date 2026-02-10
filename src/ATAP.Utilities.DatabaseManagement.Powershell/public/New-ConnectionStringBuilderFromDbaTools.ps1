function New-ConnectionStringBuilderFromDbaTools {
  <#
  .SYNOPSIS
  Wrapper around dbatools New-DbaConnectionStringBuilder with vault integration and JDBC support.

  .DESCRIPTION
  Uses New-DbaConnectionStringBuilder for robust connection string building. Supports two modes:
  - IntegratedSecurity: Uses current Windows credentials
  - CredentialsFromVault: Retrieves complete connection info from vault (username, password, and optionally host/instance/port)

  .PARAMETER DatabaseHost
  SQL Server host. Can be overridden by vault secret if CredentialsKey returns a HostName.

  .PARAMETER DatabaseName
  Database name.

  .PARAMETER ConnectionMethod
  Protocol prefix: tcp, np, lpc, or default.

  .PARAMETER CredentialsKey
  Key to retrieve credentials from vault. The secret object may contain:
  - UserName (required): SQL or Windows login
  - Password (required): Login password
  - HostName (optional): Overrides DatabaseHost parameter
  - SqlInstance (optional): Named instance
  - Port (optional): Non-default port

  .PARAMETER AsJDBC
  Output as JDBC connection string for Flyway.

  .PARAMETER ApplicationName
  Application identifier for SQL Server monitoring.

  .PARAMETER MultipleActiveResultSets
  Enable MARS.

  .PARAMETER NonPooledConnection
  Disable connection pooling.

  .EXAMPLE
  New-ConnectionStringBuilderFromDbaTools -DatabaseHost 'localhost' -DatabaseName 'aDatabaseName' -IntegratedSecurity
  Uses Windows integrated authentication.

  .EXAMPLE
  New-ConnectionStringBuilderFromDbaTools -DatabaseName 'aDatabaseName' -CredentialsKey 'aDatabaseName_Dev_Credentials'
  Retrieves host, instance, username, password from vault.

  .EXAMPLE
  New-ConnectionStringBuilderFromDbaTools -DatabaseHost 'sqlserver01' -DatabaseName 'aDatabaseName' -CredentialsKey 'aDatabaseName_SQL_Creds' -AsJDBC
  Uses vault credentials with explicit host, outputs JDBC format.

  .OUTPUTS
  PSCustomObject (ATAP.ConnectionStringBuilder)
  Returns an object with the following properties:
  - Builder: The underlying SqlConnectionStringBuilder object
  - JdbcConnectionString: JDBC format connection string (populated when -AsJDBC is used)
  - IsJdbc: Boolean indicating if JDBC format was requested
  - DataSource: The resolved data source string
  - DatabaseName: The database name
  - UseIntegratedSecurity: Boolean indicating if integrated security is used

  The object has a ToString() method that returns the appropriate connection string
  (JDBC format if -AsJDBC was specified, otherwise .NET format).

  .EXAMPLE
  $connBuilder = New-ConnectionStringBuilderFromDbaTools -DatabaseHost 'localhost' -DatabaseName 'MyDB' -IntegratedSecurity
  $connectionString = $connBuilder.ToString()
  Gets the connection string by calling ToString() on the returned object.
  #>
  [Alias('New-DBAConnStrBuilder')]
  [CmdletBinding(DefaultParameterSetName = 'IntegratedSecurity')]
  param(
    # Common parameters
    [Parameter(Mandatory = $false, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, ParameterSetName = 'CredentialsFromVault')]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $true, ParameterSetName = 'CredentialsFromVault')]
    [string]$DatabaseName,

    [Parameter(Mandatory = $false)]
    [ValidateSet('tcp', 'np', 'lpc', 'default')]
    [string]$ConnectionMethod = 'default',

    [Parameter(Mandatory = $false)]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false)]
    [int]$Port,

    # IntegratedSecurity parameter set
    [Parameter(Mandatory = $true, ParameterSetName = 'IntegratedSecurity')]
    [switch]$IntegratedSecurity,

    # CredentialsFromVault parameter set
    [Parameter(Mandatory = $true, ParameterSetName = 'CredentialsFromVault')]
    [string]$CredentialsKey,

    # Output format
    [Parameter(Mandatory = $false)]
    [switch]$AsJDBC,

    # Additional dbatools options
    [Parameter(Mandatory = $false)]
    [string]$ApplicationName = 'ATAP.Utilities',

    [Parameter(Mandatory = $false)]
    [switch]$MultipleActiveResultSets,

    [Parameter(Mandatory = $false)]
    [switch]$NonPooledConnection
  )

  BEGIN {
    $fn = 'New-ConnectionStringBuilderFromDbaTools'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Load required helper functions
    try {
      # Load utility functions
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
      if (-not (Get-Command -Name 'Get-BitWardenSecret' -CommandType Function -ErrorAction SilentlyContinue)) {
        # ToDo create Get-VaultSecret which is a shim that calls the specific vault implementation
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\Get-BitWardenSecret.ps1'
      }
      if (-not (Get-Command -Name 'New-DbaConnectionStringBuilder' -CommandType Function -ErrorAction SilentlyContinue)) {
        # Try to import dbatools module first
        if (Get-Module -ListAvailable -Name dbatools) {
          Import-Module dbatools -ErrorAction Stop
        }
        else {
          # Module not installed - attempt to install
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message 'dbatools module not found. Attempting to install...'
          Install-Module dbatools -Scope CurrentUser -Force -ErrorAction Stop
          Import-Module dbatools -ErrorAction Stop
        }
      }
    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  PROCESS {
    try {
      # Initialize connection properties
      $effectiveDataSource = $DatabaseHost
      $effectiveSqlInstance = $SqlInstance
      $effectivePort = $Port
      $userName = $null
      $password = $null
      $useIntegrated = $false

      switch ($PSCmdlet.ParameterSetName) {
        'IntegratedSecurity' {
          $useIntegrated = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Using integrated Windows authentication'

          # DatabaseHost is required for IntegratedSecurity
          if ([string]::IsNullOrWhiteSpace($effectiveDataSource)) {
            throw "DatabaseHost is required when using IntegratedSecurity"
          }
        }

        'CredentialsFromVault' {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Retrieving credentials from vault using key: $CredentialsKey"

          # Retrieve secret object from vault
          $secret = Get-BitWardenSecret -SecretName $CredentialsKey

          # Validate required properties
          if (-not $secret.UserName) {
            throw "Vault secret '$CredentialsKey' does not contain required 'UserName' property"
          }
          if (-not $secret.Password) {
            throw "Vault secret '$CredentialsKey' does not contain required 'Password' property"
          }

          $userName = $secret.UserName
          $password = $secret.Password

          # Override connection properties from vault if present
          if ($secret.HostName -and [string]::IsNullOrWhiteSpace($effectiveDataSource)) {
            $effectiveDataSource = $secret.HostName
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using HostName from vault as DatabaseHost: $effectiveDataSource"
          }

          if ($secret.SqlInstance -and [string]::IsNullOrWhiteSpace($effectiveSqlInstance)) {
            $effectiveSqlInstance = $secret.SqlInstance
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using SqlInstance from vault: $effectiveSqlInstance"
          }

          if ($secret.Port -and $effectivePort -eq 0) {
            $effectivePort = $secret.Port
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using Port from vault: $effectivePort"
          }

          # Check if Windows login (contains backslash)
          if ($userName -match '\\') {
            $useIntegrated = $true
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Vault credentials indicate Windows authentication'
          }
          else {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Using SQL Server authentication'
          }
        }
      }

      # Validate we have a data source
      if ([string]::IsNullOrWhiteSpace($effectiveDataSource)) {
        throw "DatabaseHost must be provided either as parameter or from vault secret"
      }

      # Build the full data source string
      # Format: [protocol:]hostname[\instance][,port]
      $prefix = switch ($ConnectionMethod) {
        'tcp' { 'tcp:' }
        'np' { 'np:' }
        'lpc' { 'lpc:' }
        default { '' }
      }

      $fullDataSource = "$prefix$effectiveDataSource"

      # Add instance name if specified
      if (-not [string]::IsNullOrWhiteSpace($effectiveSqlInstance)) {
        # Skip default instance markers
        $defaultInstanceMarkers = @('MSSQLSERVER', 'Default', '(default)')
        if ($effectiveSqlInstance -notin $defaultInstanceMarkers) {
          $fullDataSource += "\$effectiveSqlInstance"
        }
      }

      # Add port if specified
      if ($effectivePort -gt 0) {
        $fullDataSource += ",$effectivePort"
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Full DataSource: $fullDataSource"

      # Build parameters for New-DbaConnectionStringBuilder
      $dbaParams = @{
        DataSource      = $fullDataSource
        InitialCatalog  = $DatabaseName
        ApplicationName = $ApplicationName
      }

      if ($MultipleActiveResultSets) {
        $dbaParams['MultipleActiveResultSets'] = $true
      }

      if ($NonPooledConnection) {
        $dbaParams['NonPooledConnection'] = $true
      }

      # Handle authentication
      if ($useIntegrated) {
        if ($userName -and $password) {
          # Windows auth with explicit credentials from vault
          $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
          $credential = [PSCredential]::new($userName, $securePassword)
          $dbaParams['SqlCredential'] = $credential
        }
        else {
          # Current user's Windows credentials
          $dbaParams['IntegratedSecurity'] = $true
        }
      }
      else {
        # SQL Server authentication
        $dbaParams['UserName'] = $userName
        $dbaParams['Password'] = $password
      }

      # Build the connection string using dbatools
      $builder = New-DbaConnectionStringBuilder @dbaParams

      # Add TrustServerCertificate
      $builder.TrustServerCertificate = $true

      # Build JDBC connection string if requested
      $jdbcStr = $null
      if ($AsJDBC) {
        # Convert to JDBC format for Flyway
        # Format: jdbc:sqlserver://host[\instance][;instanceName=X];databaseName=DB;...
        $jdbcHost = $effectiveDataSource
        $jdbcStr = "jdbc:sqlserver://$jdbcHost"

        if ($effectivePort -gt 0) {
          $jdbcStr += ":$effectivePort"
        }

        $jdbcStr += ";databaseName=$DatabaseName;"

        if (-not [string]::IsNullOrWhiteSpace($effectiveSqlInstance)) {
          $defaultInstanceMarkers = @('MSSQLSERVER', 'Default', '(default)')
          if ($effectiveSqlInstance -notin $defaultInstanceMarkers) {
            $jdbcStr += "instanceName=$effectiveSqlInstance;"
          }
        }

        if ($useIntegrated -and -not $userName) {
          $jdbcStr += "integratedSecurity=true;trustServerCertificate=true;"
        }
        elseif ($useIntegrated -and $userName) {
          # Windows auth with explicit creds - JDBC uses integratedSecurity
          $jdbcStr += "integratedSecurity=true;trustServerCertificate=true;"
        }
        else {
          $jdbcStr += "user=$userName;password=$password;encrypt=true;trustServerCertificate=true;"
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Built JDBC connection string"
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Built .NET connection string"
      }

      # Return a PSCustomObject containing the builder and connection info
      # Add a ScriptMethod 'ToString' that returns the appropriate string representation
      $result = [PSCustomObject]@{
        PSTypeName            = 'ATAP.ConnectionStringBuilder'
        Builder               = $builder
        JdbcConnectionString  = $jdbcStr
        IsJdbc                = $AsJDBC.IsPresent
        DataSource            = $fullDataSource
        DatabaseName          = $DatabaseName
        UseIntegratedSecurity = $useIntegrated
      }

      # Add ToString() method that returns the connection string
      $result | Add-Member -MemberType ScriptMethod -Name 'ToString' -Value {
        if ($this.IsJdbc) {
          return $this.JdbcConnectionString
        }
        else {
          return $this.Builder.ToString()
        }
      } -Force

      return $result
    }
    catch {
      $errorMessage = "Failed to build connection string. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn"
    }
  }
}

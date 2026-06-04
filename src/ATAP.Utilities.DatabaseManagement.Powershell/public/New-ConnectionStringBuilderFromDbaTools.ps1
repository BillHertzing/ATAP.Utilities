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
  Key to retrieve credentials from vault.

  If the key starts with 'dbConnectionString', the vault item's Password field must hold a
  complete Microsoft.Data.SqlClient connection string (plain text or SecureString). The
  function parses it via SqlConnectionStringBuilder, extracts host/instance/port/auth, and
  uses the InitialCatalog as the effective database name.

  Otherwise the secret object must contain separate fields:
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
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialsKey',
    Justification = 'CredentialsKey is a vault lookup key name, not a credential')]
  [Alias('New-DBAConnStrBuilder')]
  [CmdletBinding(DefaultParameterSetName = 'IntegratedSecurity')]
  param(
    # region Database connection parameters
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [string]$DatabaseName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [string]$Environment,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [Alias('HostName')]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false)]
    [int]$Port,

    [Parameter(Mandatory = $true, ParameterSetName = 'IntegratedSecurity')]
    [switch]$IntegratedSecurity,

    [Parameter(Mandatory = $true, ParameterSetName = 'CredentialsFromVault')]
    [string]$CredentialsKey,
    # endregion Database connection parameters

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

  begin {
    $fn = 'New-ConnectionStringBuilderFromDbaTools'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Load required helper functions
    try {
      # Load utility functions
      if (-not (Get-Command -Name 'New-DbaConnectionStringBuilder' -CommandType Function -ErrorAction SilentlyContinue)) {
        # Try to import dbatools module first
        if (Get-Module -ListAvailable -Name dbatools) {
          Import-Module dbatools -ErrorAction Stop
        } else {
          # Module not installed - attempt to install
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message 'dbatools module not found. Attempting to install...'
          Install-Module dbatools -Scope CurrentUser -Force -ErrorAction Stop
          Import-Module dbatools -ErrorAction Stop
        }
      }
    } catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  process {
    try {
      # Initialize connection properties
      $effectiveDataSource = $DatabaseHost
      $effectiveSqlInstance = $SqlInstance
      $effectivePort = $Port
      $userName = $null
      $password = $null
      # Default to integrated security when no credentials key is supplied
      $useIntegratedSecurity = -not $PSBoundParameters.ContainsKey('CredentialsKey')

      switch ($PSCmdlet.ParameterSetName) {
        'IntegratedSecurity' {
          $useIntegratedSecurity = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Using integrated Windows authentication'

          # DatabaseHost is required for IntegratedSecurity
          if ([string]::IsNullOrWhiteSpace($effectiveDataSource)) {
            throw 'DatabaseHost is required when using IntegratedSecurity'
          }
        }

        'CredentialsFromVault' {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Retrieving credentials from ATAP secret store using key: $CredentialsKey"

          if ($CredentialsKey.StartsWith('dbConnectionString')) {
            # ---------------------------------------------------------------
            # The secret-store item holds a complete Microsoft.Data.SqlClient
            # connection string. dbConnectionString-* items are Secure Notes
            # whose body lives in the 'password' field by Get-SecretATAP's
            # mapping (Secure Notes default 'password' -> notes body).
            # ---------------------------------------------------------------
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
              -Message "CredentialsKey starts with 'dbConnectionString' — parsing full connection string from secret store"

            $rawConnStr = Get-SecretATAP -SecretName $CredentialsKey -SecretField 'password'

            if ([string]::IsNullOrWhiteSpace($rawConnStr)) {
              throw "Secret '$CredentialsKey' cannot be decoded or is null or whitespace"
            }

            # Parse with Microsoft.Data.SqlClient — handles all key synonyms
            try {
              $sqlCsb = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new($rawConnStr)
            } catch {
              throw "Failed to parse connection string from vault secret '$CredentialsKey': $($_.Exception.Message)"
            }

            # The connection string is authoritative for the database name
            if (-not [string]::IsNullOrWhiteSpace($sqlCsb.InitialCatalog)) {
              $DatabaseName = $sqlCsb.InitialCatalog
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                -Message "Using InitialCatalog from connection string: $DatabaseName"
            }

            # Parse DataSource: [protocol:]host[\instance][,port]
            $rawDs = $sqlCsb.DataSource
            if ($rawDs -match '^(tcp:|np:|lpc:)(.+)$') {
              if ([string]::IsNullOrWhiteSpace($ConnectionMethod)) {
                $ConnectionMethod = $Matches[1].TrimEnd(':')
              }
              $rawDs = $Matches[2]
            }
            if ($rawDs -match '^(.+),(\d+)$') {
              $rawDs = $Matches[1]
              if ($effectivePort -eq 0) { $effectivePort = [int]$Matches[2] }
            }
            if ($rawDs -match '^([^\\]+)\\(.+)$') {
              $effectiveDataSource = $Matches[1]
              if ([string]::IsNullOrWhiteSpace($effectiveSqlInstance)) {
                $effectiveSqlInstance = $Matches[2]
              }
            } else {
              $effectiveDataSource = $rawDs
            }

            # Authentication
            $useIntegratedSecurity = $sqlCsb.IntegratedSecurity
            if (-not $useIntegratedSecurity) {
              $userName = $sqlCsb.UserID
              $password = $sqlCsb.Password
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
              -Message "Parsed: Host=$effectiveDataSource  Instance=$effectiveSqlInstance  Port=$effectivePort  IntegratedSecurity=$useIntegratedSecurity"

          } else {
            # ---------------------------------------------------------------
            # Standard secret-store item — separate UserName / Password /
            # optional HostName / SqlInstance / Port / UseIntegratedSecurity
            # fields. Each field is fetched with its own Get-SecretATAP call
            # so the wrapper API can stay single-string.
            # ---------------------------------------------------------------

            $userName = Get-SecretATAP -SecretName $CredentialsKey -SecretField 'username'
            if ([string]::IsNullOrWhiteSpace($userName)) {
              throw "Secret '$CredentialsKey' does not contain a 'username' field"
            }

            $password = Get-SecretATAP -SecretName $CredentialsKey -SecretField 'password'
            if ([string]::IsNullOrWhiteSpace($password)) {
              throw "Secret '$CredentialsKey' does not contain a 'password' field"
            }

            # UseIntegratedSecurity: optional custom field; default $false on absence.
            $useIntegratedSecurity = $false
            try {
              $uisRaw = Get-SecretATAP -SecretName $CredentialsKey -SecretField 'UseIntegratedSecurity' -ErrorAction SilentlyContinue
              if (-not [string]::IsNullOrWhiteSpace($uisRaw)) {
                $useIntegratedSecurity = [System.Convert]::ToBoolean($uisRaw)
              }
            } catch {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                -Message "Optional field 'UseIntegratedSecurity' not present on '$CredentialsKey'; defaulting to false"
            }

            # Optional HostName/SqlInstance/Port custom fields.
            try {
              $hostFromVault = Get-SecretATAP -SecretName $CredentialsKey -SecretField 'HostName' -ErrorAction SilentlyContinue
              if (-not [string]::IsNullOrWhiteSpace($hostFromVault) -and [string]::IsNullOrWhiteSpace($effectiveDataSource)) {
                $effectiveDataSource = $hostFromVault
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                  -Message "Using HostName from secret store as DatabaseHost: $effectiveDataSource"
              }
            } catch {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                -Message "Optional field 'HostName' not present on '$CredentialsKey'"
            }

            try {
              $instFromVault = Get-SecretATAP -SecretName $CredentialsKey -SecretField 'SqlInstance' -ErrorAction SilentlyContinue
              if (-not [string]::IsNullOrWhiteSpace($instFromVault) -and [string]::IsNullOrWhiteSpace($effectiveSqlInstance)) {
                $effectiveSqlInstance = $instFromVault
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                  -Message "Using SqlInstance from secret store: $effectiveSqlInstance"
              }
            } catch {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                -Message "Optional field 'SqlInstance' not present on '$CredentialsKey'"
            }

            try {
              $portFromVault = Get-SecretATAP -SecretName $CredentialsKey -SecretField 'Port' -ErrorAction SilentlyContinue
              if (-not [string]::IsNullOrWhiteSpace($portFromVault) -and $effectivePort -eq 0) {
                $effectivePort = [int]$portFromVault
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                  -Message "Using Port from secret store: $effectivePort"
              }
            } catch {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                -Message "Optional field 'Port' not present on '$CredentialsKey'"
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
              -Message "Effective UseIntegratedSecurity: $useIntegratedSecurity"
          }
        }
      }

      # Validate we have a data source
      if ([string]::IsNullOrWhiteSpace($effectiveDataSource)) {
        throw 'DatabaseHost must be provided either as parameter or from vault secret'
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
      if ($useIntegratedSecurity) {
        if ($userName -and $password) {
          # Windows auth with explicit credentials from vault
          $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
          $credential = [PSCredential]::new($userName, $securePassword)
          $dbaParams['SqlCredential'] = $credential
        } else {
          # Current user's Windows credentials
          $dbaParams['IntegratedSecurity'] = $true
        }
      } else {
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

        if ($useIntegratedSecurity -and -not $userName) {
          $jdbcStr += 'integratedSecurity=true;trustServerCertificate=true;'
        } elseif ($useIntegratedSecurity -and $userName) {
          # Windows auth with explicit creds - JDBC uses integratedSecurity
          $jdbcStr += 'integratedSecurity=true;trustServerCertificate=true;'
        } else {
          $jdbcStr += "user=$userName;password=$password;encrypt=true;trustServerCertificate=true;"
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Built JDBC connection string'
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Built .NET connection string'
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
        UseIntegratedSecurity = $useIntegratedSecurity
      }

      # Add ToString() method that returns the connection string
      $result | Add-Member -MemberType ScriptMethod -Name 'ToString' -Value {
        if ($this.IsJdbc) {
          return $this.JdbcConnectionString
        } else {
          return $this.Builder.ToString()
        }
      } -Force

      return $result
    } catch {
      $errorMessage = "Failed to build connection string. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn"
    }
  }
}

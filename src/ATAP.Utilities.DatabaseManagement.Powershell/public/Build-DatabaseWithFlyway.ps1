function Build-DatabaseWithFlyway {
  <#
.SYNOPSIS
Builds a SQL Server database from scratch using Flyway migrations.

.DESCRIPTION
This cmdlet orchestrates the complete build of a SQL Server database:
1. Loads environment variables from .env files
2. Configures database connection settings
3. Drops and recreates the database using DatabaseProvisioning
4. Runs Flyway migrations to create schema and objects

This is a shared utility used by multiple database projects (PCMSC, Gmail, Tags, etc.).

.PARAMETER DatabaseName
The name of the database to build.

.PARAMETER Environment
The target environment: 'Development', 'Testing', 'Production', or 'Experimental'.

.PARAMETER DatabaseHost
The SQL Server host. Default is 'localhost'.

.PARAMETER FlywayBasePath
Path to the Flyway directory containing flyway.toml. If not specified, attempts to auto-detect.

.PARAMETER SqlMigrationsPath
Path to the SQL migrations directory. If not specified, defaults to FlywayBasePath\SQL.

.PARAMETER SharedSqlMigrationsPath
Path to the shared SQL scripts directory. Default is determined from repository structure.

.PARAMETER Force
Force database drop even if it exists. Default is $true.

.OUTPUTS
System.Object
Returns a result object with Success (bool) and any error messages.

.EXAMPLE
Build-DatabaseWithFlyway -DatabaseName 'Tags' -Environment 'Experimental' -DatabaseHost 'localhost'

.EXAMPLE
Build-DatabaseWithFlyway -DatabaseName 'PCMSC' -Environment 'Development'

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Requires dbatools module for database operations.
Requires Flyway CLI to be available in PATH or configured in environment variables.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ConnectionParameters')]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialsKey',
    Justification = 'CredentialsKey is a vault lookup key name, not a credential')]
  param(
    # region Database connection parameters
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [string]$Environment,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [Alias('HostName')]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [int]$Port,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ParameterSetName = 'ExistingConnection')]
    [switch]$IntegratedSecurity,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [string]$CredentialsKey,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
    [Microsoft.Data.SqlClient.SqlConnection]$SqlConnection,
    # endregion Database connection parameters

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ParameterSetName = 'ExistingConnection')]
    [string]$DatabasePath,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ParameterSetName = 'ExistingConnection')]
    [string]$ProvisioningScriptsPath,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ParameterSetName = 'ExistingConnection')]
    [string]$FlywayBasePath,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ParameterSetName = 'ExistingConnection')]
    [string]$flywaySqlMigrationsPath,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ParameterSetName = 'ExistingConnection')]
    [string]$flywaySharedSqlMigrationsPath,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ParameterSetName = 'ExistingConnection')]
    [string]$FlywayDataPath,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ParameterSetName = 'ExistingConnection')]
    [string]$FlywayTomlPath,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $false, ParameterSetName = 'ExistingConnection')]
    [switch]$Force
  )

  BEGIN {
    $fn = 'Build-DatabaseWithFlyway'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Load required helper functions
    try {
      # Import dbatools module for database operations
      if (-not (Get-Module -Name dbatools -ListAvailable)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "dbatools module not found. Installing..."
        Install-Module -Name dbatools -Scope CurrentUser -Force -AllowClobber
      }
      Import-Module dbatools -ErrorAction Stop
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
      if (-not (Get-Command -Name 'Get-RepositoryRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-RepositoryRoot.ps1'
      }
      if (-not (Get-Command -Name 'New-DBAConnStrBuilder' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\New-ConnectionStringBuilderFromDbaTools.ps1'
      }
      if (-not (Get-Command -Name 'DatabaseProvisioning' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\DatabaseProvisioning.ps1'
      }
      if (-not (Get-Command -Name 'Invoke-Flyway' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-Flyway.ps1'
      }
    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.Errors += $errorMessage
      throw
    }

    $usingExistingConnection = $PSCmdlet.ParameterSetName -eq 'ExistingConnection'
    # Parameter validation using Get-PVal pattern
    # region Database connection parameter validation
    $databasesCollection = $global:settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]
    $DatabaseName = Get-PVal -ParameterName "DatabaseName" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.DatabaseName" -Settings $databasesCollection -DefaultValue $DatabaseName
    $Environment = Get-PVal -ParameterName 'Environment' -originalPSBoundParameters $PSBoundParameters -DefaultValue $Environment -ValidValues @('Production', 'Testing', 'Development', 'Experimental')
    $DatabaseHost = Get-PVal -ParameterName "DatabaseHost" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.DatabaseHost" -Settings $databasesCollection -DefaultValue $DatabaseHost
    $SqlInstance = Get-PVal -ParameterName "SqlInstance" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.SqlInstance" -Settings $databasesCollection -DefaultValue $SqlInstance -AllowMissing
    $ConnectionMethod = Get-PVal -ParameterName "ConnectionMethod" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.ConnectionMethod" -Settings $databasesCollection -DefaultValue $ConnectionMethod -ValidValues @('tcp', 'np', 'lpc')
    $Port = Get-PVal -ParameterName "Port" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.Port" -Settings $databasesCollection -DefaultValue $Port -AllowMissing
    $CredentialsKey = Get-PVal -ParameterName "CredentialsKey" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.CredentialsKey" -Settings $databasesCollection -DefaultValue $CredentialsKey -AllowMissing
    # endregion Database connection parameter validation
    $DatabasePath = Get-PVal -ParameterName "DatabasePath" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.DatabasePath" -Settings $databasesCollection -DefaultValue $DatabasePath
    $FlywayBasePath = Get-PVal -ParameterName "FlywayBasePath" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywayBasePath" -Settings $databasesCollection -DefaultValue $FlywayBasePath
    $flywaySqlMigrationsPath = Get-PVal -ParameterName "SqlMigrationsPath" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.SqlMigrationsPath" -Settings $databasesCollection -DefaultValue $flywaySqlMigrationsPath
    $flywaySharedSqlMigrationsPath = Get-PVal -ParameterName "SharedSqlMigrationsPath" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.SharedSqlMigrationsPath" -Settings $databasesCollection -DefaultValue $flywaySharedSqlMigrationsPath
    $FlywayDataPath = Get-PVal -ParameterName "FlywayDataPath" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywayDataPath" -Settings $databasesCollection -DefaultValue $FlywayDataPath
    $FlywayTomlPath = Get-PVal -ParameterName "FlywayTomlPath" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywayTomlPath" -Settings $databasesCollection -DefaultValue $FlywayTomlPath

    # Determine the SqlInstance value based on the environment if it is not yet defined.
    if (-not $SqlInstance) {
      # Per Database Design: SqlInstance matches Environment, except 'Experimental', which uses default instance (blank)
      $SqlInstance = if ($Environment -eq 'Experimental') { $null } else { $Environment }
    }

    # If credentials are not supplied, default to IntegratedSecurity
    if (-not $CredentialsKey -and -not $IntegratedSecurity) {
      $IntegratedSecurity = $true
    }

    # Initialize result object
    $result = [PSCustomObject]@{
      Success      = $false
      DatabaseName = $DatabaseName
      Environment  = $Environment
      SqlInstance  = $SqlInstance
      Errors       = @()
      StartTime    = Get-Date
      EndTime      = $null
    }


    # Configure dbatools SSL/encryption settings
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Configuring dbatools to trust server certificates"
    Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -PassThru | Register-DbatoolsConfig
    Set-DbatoolsConfig -FullName sql.connection.encrypt -Value $false -PassThru | Register-DbatoolsConfig
  }

  PROCESS {
    try {

      # Change to Flyway directory
      $originalLocation = Get-Location
      Set-Location $FlywayBasePath

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Starting database provisioning..."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Target Server: $DatabaseHost"

      $sqlConnection = $null
      $sqlConnectionOpenedHere = $false
      $useIntegratedSecurityForFlyway = $IntegratedSecurity

      if ($usingExistingConnection) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Using provided SqlConnection object'

        if (-not ($SqlConnection.PSObject.Properties['State'] -and $SqlConnection.PSObject.Methods['Open'])) {
          $errorMessage = 'Provided SqlConnection object does not expose expected State/Open members'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }

        try {
          if ($SqlConnection.State -ne [System.Data.ConnectionState]::Open) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Opening provided SQL connection'
            $SqlConnection.Open()
            $sqlConnectionOpenedHere = $true
          }
          $sqlConnection = $SqlConnection
          $existingConnBuilder = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new($SqlConnection.ConnectionString)
          $useIntegratedSecurityForFlyway = $existingConnBuilder.IntegratedSecurity
        }
        catch {
          $errorMessage = "Failed to open provided SQL connection: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          $result.Errors += $errorMessage
          throw
        }
      }
      else {
        # Build connection string for provisioning (connect to master initially)
        $connStrBuilderParams = @{
          DatabaseName     = 'master'
          DatabaseHost     = $DatabaseHost
          ConnectionMethod = $ConnectionMethod
          SqlInstance      = $SqlInstance
        }

        if ($Port) { $connStrBuilderParams['Port'] = $Port }
        if ($CredentialsKey) { $connStrBuilderParams['CredentialsKey'] = $CredentialsKey }
        else { $connStrBuilderParams['IntegratedSecurity'] = $true }

        $connStrBuilderResult = New-DBAConnStrBuilder @connStrBuilderParams
        $useIntegratedSecurityForFlyway = $connStrBuilderResult.UseIntegratedSecurity

        # Get the underlying connection string builder for additional modifications
        $connectionStringBuilder = $connStrBuilderResult.Builder
        $connectionStringBuilder.TrustServerCertificate = $true
        $connectionStringBuilder.Encrypt = $false
        $connectionStringBuilder['Connect Timeout'] = 30

        # Create and open SQL connection
        $sqlConnection = New-Object Microsoft.Data.SqlClient.SqlConnection
        $sqlConnection.ConnectionString = $connStrBuilderResult.ToString()
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'SQL Connection String built (credentials hidden)'

        try {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Opening SQL connection...'
          $sqlConnection.Open()
          $sqlConnectionOpenedHere = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'SQL connection opened successfully'
        }
        catch {
          $errorMessage = "Failed to open SQL connection: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          $result.Errors += $errorMessage
          if ($sqlConnection) { $sqlConnection.Dispose() }
          throw
        }
      }

      # Verify connection
      try {
        $testCmd = $sqlConnection.CreateCommand()
        $testCmd.CommandText = "SELECT @@SERVERNAME AS ServerName, @@VERSION AS Version"
        $testReader = $testCmd.ExecuteReader()
        if ($testReader.Read()) {
          $serverName = $testReader['ServerName']
          $version = $testReader['Version']
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Connected to server: $serverName"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Server version: $version"
        }
        $testReader.Close()
        $testCmd.Dispose()
      }
      catch {
        $errorMessage = "Failed to open or test SQL connection: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        $result.Errors += $errorMessage
        if ($sqlConnection) {
          if ($sqlConnectionOpenedHere -and $sqlConnection.State -eq [System.Data.ConnectionState]::Open) { $sqlConnection.Close() }
          $sqlConnection.Dispose()
        }
        throw
      }

      # Call DatabaseProvisioning with SQL connection object
      $provisioningParams = @{
        DatabaseName            = $DatabaseName
        SqlConnection           = $sqlConnection
        DatabasePath            = $DatabasePath
        ProvisioningScriptsPath = $ProvisioningScriptsPath
        Force                   = $Force
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Calling DatabaseProvisioning with SqlConnection object"

      if ($PSCmdlet.ShouldProcess($DatabaseName, 'Provision database')) {
        $provisioningResult = $null
        try {
          $provisioningResult = DatabaseProvisioning @provisioningParams
        }
        finally {
          # Close the connection after provisioning if we opened it
          if ($sqlConnection -and $sqlConnectionOpenedHere -and $sqlConnection.State -eq [System.Data.ConnectionState]::Open) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Closing SQL connection'
            $sqlConnection.Close()
            $sqlConnection.Dispose()
          }
        }

        # Check provisioning result before continuing to Flyway
        if (-not $provisioningResult -or -not $provisioningResult.Success) {
          $errorMessage = "Database provisioning failed. Aborting before Flyway migrations."
          if ($provisioningResult -and $provisioningResult.Errors) {
            $errorMessage += " Errors: $($provisioningResult.Errors -join '; ')"
          }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          $result.Errors += $errorMessage
          throw $errorMessage
        }

        # Run Flyway migrations
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Running Flyway migrations..."
        $FlywayParams = @{
          DatabaseName                  = $DatabaseName
          Environment                   = $Environment
          DatabaseHost                  = $DatabaseHost
          SqlInstance                   = $SqlInstance
          ConnectionMethod              = $ConnectionMethod
          Port                          = $Port
          IntegratedSecurity            = $useIntegratedSecurityForFlyway
          FlywayCommand                 = 'migrate'
          FlywaySqlMigrationsPath       = $flywaySqlMigrationsPath
          FlywaySharedSqlMigrationsPath = $flywaySharedSqlMigrationsPath
          FlywayDataPath                = $flywayDataPath
          FlywayTomlPath                = $FlywayTomlPath
          PackageName                   = "$DatabaseName.Functions"
          PackageVersion                = 1
        }

        if ($CredentialsKey) { $FlywayParams['CredentialsKey'] = $CredentialsKey }
        Invoke-Flyway @FlywayParams

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Database build completed successfully"
        $result.Success = $true
      }
    }
    catch {
      $errorMessage = "Database build failed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
      $result.Errors += $errorMessage
      $result.Success = $false
      throw
    }
    finally {
      # Restore original location
      if ($originalLocation) {
        Set-Location $originalLocation
      }
      $result.EndTime = Get-Date
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    return $result
  }
}

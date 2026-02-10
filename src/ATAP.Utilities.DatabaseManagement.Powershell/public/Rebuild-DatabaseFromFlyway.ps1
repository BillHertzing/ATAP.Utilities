<#
.SYNOPSIS
Rebuilds a SQL Server database from scratch using Flyway migrations.

.DESCRIPTION
This cmdlet orchestrates the complete rebuild of a SQL Server database:
1. Loads environment variables from .env files
2. Configures database connection settings
3. Drops and recreates the database using DatabaseProvisioning
4. Runs Flyway migrations to create schema and objects

This is a shared utility used by multiple database projects (PCMSC, Gmail, Tags, etc.).

.PARAMETER DatabaseName
The name of the database to rebuild.

.PARAMETER Environment
The target environment: 'Development', 'Testing', 'Production', or 'Experimental'.

.PARAMETER DatabaseHost
The SQL Server host. Default is 'localhost'.

.PARAMETER FlywayBasePath
Path to the Flyway directory containing flyway.toml. If not specified, attempts to auto-detect.

.PARAMETER SqlMigrationsPath
Path to the SQL migrations directory. If not specified, defaults to FlywayBasePath\SQL.

.PARAMETER SharedSqlPath
Path to the shared SQL scripts directory. Default is determined from repository structure.

.PARAMETER Force
Force database drop even if it exists. Default is $true.

.OUTPUTS
System.Object
Returns a result object with Success (bool) and any error messages.

.EXAMPLE
Rebuild-DatabaseFromFlyway -DatabaseName 'Tags' -Environment 'Experimental' -DatabaseHost 'localhost'

.EXAMPLE
Rebuild-DatabaseFromFlyway -DatabaseName 'PCMSC' -Environment 'Development'

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Requires dbatools module for database operations.
Requires Flyway CLI to be available in PATH or configured in environment variables.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Rebuild-DatabaseFromFlyway {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$DatabaseName,

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$Environment = 'Experimental',

    [Parameter(Mandatory = $false, Position = 2)]
    [string]$DatabaseHost = 'localhost',

    [Parameter(Mandatory = $true)]
    [string]$FlywayBasePath,

    [Parameter(Mandatory = $false)]
    [string]$SqlMigrationsPath,

    [Parameter(Mandatory = $false)]
    [string]$SharedSqlPath,

    [Parameter(Mandatory = $false)]
    [bool]$Force = $true
  )

  BEGIN {
    $fn = 'Rebuild-DatabaseFromFlyway'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Initialize result object
    $result = [PSCustomObject]@{
      Success      = $false
      DatabaseName = $DatabaseName
      Environment  = $Environment
      Errors       = @()
      StartTime    = Get-Date
      EndTime      = $null
    }

    # Load required helper functions
    try {
      # Import dbatools module for database operations
      if (-not (Get-Module -Name dbatools -ListAvailable)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "dbatools module not found. Installing..."
        Install-Module -Name dbatools -Scope CurrentUser -Force -AllowClobber
      }
      Import-Module dbatools -ErrorAction Stop

      if (-not (Get-Command -Name 'Get-RepositoryRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-RepositoryRoot.ps1'
      }
      if (-not (Get-Command -Name 'Import-EnvFile' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.PowerShell\public\Import-EnvFile.ps1'
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

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Database: $DatabaseName"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Environment: $Environment"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Database host: $DatabaseHost"

    # # Get repository root
    # try {
    #   $repositoryRoot = Get-RepositoryRoot -ErrorAction Stop
    #   Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Repository root: $repositoryRoot"
    # }
    # catch {
    #   $errorMessage = "Failed to get repository root: $($_.Exception.Message)"
    #   Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
    #   $result.Errors += $errorMessage
    #   throw
    # }

    # Auto-detect paths if not provided
    # if (-not $EnvBasePath) {
    #   # Try ATAP.Utilities structure first
    #   $possiblePaths = @(
    #     (Join-Path $repositoryRoot 'src' "ATAP.Utilities.$DatabaseName" 'Database' 'Flyway'),
    #     (Join-Path $repositoryRoot 'Databases' 'Flyway')
    #   )
    #   foreach ($path in $possiblePaths) {
    #     if (Test-Path (Join-Path $path '.env')) {
    #       $EnvBasePath = $path
    #       break
    #     }
    #   }
    #   if (-not $EnvBasePath) {
    #     $errorMessage = "Could not auto-detect .env file location. Please specify -EnvBasePath"
    #     Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
    #     $result.Errors += $errorMessage
    #     throw $errorMessage
    #   }
    # }
    # Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "EnvBasePath: $EnvBasePath"

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "FlywayBasePath: $FlywayBasePath"

    if (-not $SqlMigrationsPath) {
      $SqlMigrationsPath = Join-Path $FlywayBasePath 'SQL'
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "SqlMigrationsPath: $SqlMigrationsPath"

    if (-not $SharedSqlPath) {
      $SharedSqlPath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement\SharedSQL'
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "SharedSqlPath: $SharedSqlPath"

    # Configure dbatools SSL/encryption settings
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Configuring dbatools to trust server certificates"
    Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -PassThru | Register-DbatoolsConfig
    Set-DbatoolsConfig -FullName sql.connection.encrypt -Value $false -PassThru | Register-DbatoolsConfig
  }

  PROCESS {
    try {
      # # Load .env files for non-connection settings
      # $envBaseFile = Join-Path $EnvBasePath '.env'
      # $envLocalFile = Join-Path $EnvBasePath '.env.local'

      # if (-not (Import-EnvFile -FilePath $envBaseFile -FileDescription ".env")) {
      #   throw ".env file not found at: $envBaseFile"
      # }

      # # Load .env.local file (optional, overrides base .env)
      # if (Import-EnvFile -FilePath $envLocalFile -FileDescription ".env.local") {
      #   Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Local environment overrides applied from .env.local"
      # }

      # Set FLYWAY_PLACEHOLDERS_DATA_DIR from FLYWAY_DATA_DIR
      if ($env:FLYWAY_DATA_DIR) {
        $env:FLYWAY_PLACEHOLDERS_DATA_DIR = $env:FLYWAY_DATA_DIR
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Set FLYWAY_PLACEHOLDERS_DATA_DIR = $env:FLYWAY_PLACEHOLDERS_DATA_DIR"
      }

      # Change to Flyway directory
      $originalLocation = Get-Location
      Set-Location $FlywayBasePath

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Starting database provisioning..."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Target Server: $DatabaseHost"

      # Build connection string for provisioning (connect to master initially)
      $connStrBuilderResult = New-DBAConnStrBuilder -DatabaseHost $DatabaseHost -DatabaseName 'master' -IntegratedSecurity

      # Get the underlying connection string builder for additional modifications
      $connectionStringBuilder = $connStrBuilderResult.Builder
      $connectionStringBuilder.TrustServerCertificate = $true
      $connectionStringBuilder.Encrypt = $false
      $connectionStringBuilder["Connect Timeout"] = 30

      # Create and open SQL connection
      $sqlConnection = New-Object Microsoft.Data.SqlClient.SqlConnection
      $sqlConnection.ConnectionString = $connStrBuilderResult.ToString()
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "SQL Connection String built (credentials hidden)"

      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Opening SQL connection..."
        $sqlConnection.Open()
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "SQL connection opened successfully"

        # Verify connection
        $testCmd = $sqlConnection.CreateCommand()
        $testCmd.CommandText = "SELECT @@SERVERNAME AS ServerName, @@VERSION AS Version"
        $testReader = $testCmd.ExecuteReader()
        if ($testReader.Read()) {
          $serverName = $testReader["ServerName"]
          $version = $testReader["Version"]
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
          $sqlConnection.Dispose()
        }
        throw
      }

      # Call DatabaseProvisioning with SQL connection object
      $databasePath = $null
      if ($global:settings -and $global:configRootKeys -and $global:settings.ContainsKey($global:configRootKeys['DatabasesCollectionConfigRootKey'])) {
        $dbCollection = $global:settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]
        if ($dbCollection.ContainsKey($DatabaseName) -and $dbCollection.$DatabaseName.ContainsKey($Environment)) {
          $databasePath = $dbCollection.$DatabaseName.$Environment.DatabasePath
        }
      }

      $provisioningParams = @{
        DatabaseName    = $DatabaseName
        SqlConnection   = $sqlConnection
        ScriptDirectory = $SharedSqlPath
        Force           = $Force
      }

      if ($databasePath) {
        $provisioningParams['DatabasePath'] = $databasePath
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "DatabasePath: $databasePath"
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Calling DatabaseProvisioning with SqlConnection object"

      if ($PSCmdlet.ShouldProcess($DatabaseName, 'Provision database')) {
        try {
          DatabaseProvisioning @provisioningParams
        }
        finally {
          # Close the connection after provisioning
          if ($sqlConnection -and $sqlConnection.State -eq [System.Data.ConnectionState]::Open) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Closing SQL connection"
            $sqlConnection.Close()
            $sqlConnection.Dispose()
          }
        }

        # Run Flyway migrations

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Running Flyway migrations..."
        Invoke-Flyway -DatabaseHost $DatabaseHost -Environment $Environment -DatabaseName $DatabaseName -IntegratedSecurity -FlywayCommand 'migrate' -PackageName "$DatabaseName.Functions" -PackageVersion 1 -SqlDir $SqlMigrationsPath -ConfigPath (Join-Path $FlywayBasePath 'flyway.toml')

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Database rebuild completed successfully"
        $result.Success = $true
      }
    }
    catch {
      $errorMessage = "Database rebuild failed: $($_.Exception.Message)"
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

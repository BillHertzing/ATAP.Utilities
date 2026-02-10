# Set the database name
$databaseName = 'GMAIL'
# Set the environment to use (this will be passed to databaseProvisioning and Invoke-Flyway)
$environment = 'Experimental'
# Set the database host (source of truth - no longer parsed from JDBC strings)
$databaseHost = 'localhost'

# Load required helper functions
try {
  # Import dbatools module for database operations (avoid SqlServer module to prevent assembly conflicts)
  if (-not (Get-Module -Name dbatools -ListAvailable)) {
    Write-PSFMessage -Level Warning -Message "dbatools module not found. Installing..."
    Install-Module -Name dbatools -Scope CurrentUser -Force -AllowClobber
  }
  Import-Module dbatools -ErrorAction Stop

  if (-not (Get-Command -Name 'Get-RepositoryRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
    . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-RepositoryRoot.ps1'
  }
  if (-not (Get-Command -Name 'Import-EnvFile' -CommandType Function -ErrorAction SilentlyContinue)) {
    . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.PowerShell\public\Import-EnvFile.ps1'
  }
  # Load the connection string builder function
  if (-not (Get-Command -Name 'New-DBAConnStrBuilder' -CommandType Function -ErrorAction SilentlyContinue)) {
    . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\New-ConnectionStringBuilderFromDbaTools.ps1'
  }
}
catch {
  $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
  Write-PSFMessage -Level Error -Message $errorMessage
  throw
}

# Load .env files for non-connection settings (FLYWAY_DATA_DIR, FLYWAY_SHARED_SQL_PATH, etc.)
$envBaseFile = "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.${databaseName}\Database\Flyway\.env"
$envLocalFile = "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.${databaseName}\Database\Flyway\.env.local"

# Load base .env file (required for placeholder values like FLYWAY_DATA_DIR)
if (-not (Import-EnvFile -FilePath $envBaseFile -FileDescription ".env")) {
  Write-PSFMessage -Level Error -Message ".env file not found at: $envBaseFile"
  throw ".env file is required"
}

# Load .env.local file (optional, overrides base .env)
if (Import-EnvFile -FilePath $envLocalFile -FileDescription ".env.local") {
  Write-PSFMessage -Level Important -Message "Local environment overrides applied from .env.local"
}

# Set FLYWAY_PLACEHOLDERS_DATA_DIR from FLYWAY_DATA_DIR
if ($env:FLYWAY_DATA_DIR) {
  $env:FLYWAY_PLACEHOLDERS_DATA_DIR = $env:FLYWAY_DATA_DIR
  Write-PSFMessage -Level Important -Message "Set FLYWAY_PLACEHOLDERS_DATA_DIR = $env:FLYWAY_PLACEHOLDERS_DATA_DIR"
}

Write-PSFMessage -Level Important -Message "Using environment: $environment"
Write-PSFMessage -Level Important -Message "Database host: $databaseHost"
Write-PSFMessage -Level Important -Message "Database: $databaseName"

# Configure dbatools SSL/encryption settings
Write-PSFMessage -Level Verbose -Message "Configuring dbatools to trust server certificates"
Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -PassThru | Register-DbatoolsConfig
Set-DbatoolsConfig -FullName sql.connection.encrypt -Value $false -PassThru | Register-DbatoolsConfig

$repositoryRoot = Get-RepositoryRoot -ErrorAction Stop

# Recreate the database from scratch using Flyway migrations
try {
  . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\DatabaseProvisioning.ps1' -verbose
  . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-Flyway.ps1'
  Set-Location (Join-Path $repositoryRoot 'src' "ATAP.Utilities.$databaseName" 'Database' 'Flyway')

  Write-PSFMessage -Level Important -Message "Starting database provisioning..."
  Write-PSFMessage -Level Important -Message "Target Server: $databaseHost"
  Write-PSFMessage -Level Important -Message "Database: $databaseName"
  Write-PSFMessage -Level Important -Message "Environment: $environment"

  # Build connection string for provisioning (connect to master initially)
  $connStrBuilderResult = New-DBAConnStrBuilder -DatabaseHost $databaseHost -DatabaseName 'master' -IntegratedSecurity

  # Get the underlying connection string builder for additional modifications
  $connectionStringBuilder = $connStrBuilderResult.Builder
  $connectionStringBuilder.TrustServerCertificate = $true
  $connectionStringBuilder.Encrypt = $false
  $connectionStringBuilder["Connect Timeout"] = 30

  # Create and open SQL connection
  $sqlConnection = New-Object Microsoft.Data.SqlClient.SqlConnection
  $sqlConnection.ConnectionString = $connStrBuilderResult.ToString()
  Write-PSFMessage -Level Verbose -Message "SQL Connection String built (credentials hidden)"

  try {
    Write-PSFMessage -Level Verbose -Message "Opening SQL connection..."
    $sqlConnection.Open()
    Write-PSFMessage -Level Important -Message "SQL connection opened successfully"

    # Verify connection
    $testCmd = $sqlConnection.CreateCommand()
    $testCmd.CommandText = "SELECT @@SERVERNAME AS ServerName, @@VERSION AS Version"
    $testReader = $testCmd.ExecuteReader()
    if ($testReader.Read()) {
      $serverName = $testReader["ServerName"]
      $version = $testReader["Version"]
      Write-PSFMessage -Level Important -Message "Connected to server: $serverName"
      Write-PSFMessage -Level Verbose -Message "Server version: $version"
    }
    $testReader.Close()
    $testCmd.Dispose()
  }
  catch {
    $errorMessage = "Failed to open or test SQL connection: $($_.Exception.Message)"
    Write-PSFMessage -Level Error -Message $errorMessage
    if ($sqlConnection) {
      $sqlConnection.Dispose()
    }
    throw
  }

  # Call databaseProvisioning with SQL connection object
  $provisioningParams = @{
    DatabaseName    = $databaseName
    SqlConnection   = $sqlConnection
    DatabasePath    = $global:settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']].$databaseName.$environment.DatabasePath
    ScriptDirectory = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement\SharedSQL'
    Force           = $true
  }

  Write-PSFMessage -Level Verbose -Message "Calling DatabaseProvisioning with SqlConnection object"
  Write-PSFMessage -Level Verbose -Message "DatabaseProvisioning parameters: $($provisioningParams.Keys -join ', ')"

  try {
    databaseProvisioning @provisioningParams
  }
  finally {
    # Close the connection after provisioning
    if ($sqlConnection -and $sqlConnection.State -eq [System.Data.ConnectionState]::Open) {
      Write-PSFMessage -Level Verbose -Message "Closing SQL connection"
      $sqlConnection.Close()
      $sqlConnection.Dispose()
    }
  }

  $pathToToml = '..\flyway.toml'
  if (-not (Test-Path $pathToToml)) {
    throw "Flyway configuration file not found: $pathToToml"
  }

  # Run Flyway migrations - Invoke-Flyway now builds its own JDBC URL from parameters
  Write-PSFMessage -Level Important -Message "Running Flyway migrations..."
  Invoke-Flyway -DatabaseHost $databaseHost -Environment $environment -DatabaseName $databaseName -IntegratedSecurity -FlywayCommand 'migrate' -PackageName "$databaseName.Functions" -PackageVersion 1 -SqlDir (Join-Path $repositoryRoot 'src' "ATAP.Utilities.$databaseName" 'Database' 'Flyway' 'SQL') -ConfigPath $pathToToml

  Write-PSFMessage -Level Important -Message "Database rebuild completed successfully"
}
catch {
  Write-PSFMessage -Level Error -Message "Database rebuild failed: $($_.Exception.Message)"
  Write-PSFMessage -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
  throw
}

# After successful rebuild, load the data into the database
try {
  Write-PSFMessage -Level Important -Message "Loading $databaseName data into database..."
  if (-not (Get-Command -Name 'Load-GmailToDatabase' -CommandType Function -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'Load-GmailToDatabase.ps1')
  }
  Load-GmailToDatabase -DatabaseHost $databaseHost -DatabaseName $databaseName -IntegratedSecurity -Environment $environment -ExtractPath 'D:/Temp/LoadGmail' -TakeoutZipPath 'C:\Dropbox\Apps\Google Download Your Takeout Data\takeout-20251021T153420Z-1-001 mail drafts.zip' -Verbose
}
catch {
  Write-PSFMessage -Level Error -Message "Load-GmailToDatabase failed: $($_.Exception.Message)"
  throw
}

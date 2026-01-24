# Load required helper functions
try {
  # Import SqlServer module for Invoke-Sqlcmd
  if (-not (Get-Module -Name SqlServer -ListAvailable)) {
    Write-PSFMessage -Level Warning -Message "SqlServer module not found. Installing..."
    Install-Module -Name SqlServer -Scope CurrentUser -Force -AllowClobber
  }
  Import-Module SqlServer -ErrorAction Stop

  # Load Get-RepositoryRoot helper
  if (-not (Get-Command -Name 'Get-RepositoryRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
    $getRepoRootPath = "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-RepositoryRoot.ps1"
    if (Test-Path $getRepoRootPath) {
      . $getRepoRootPath
    }
    else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Get-RepositoryRoot.ps1 not found at: $getRepoRootPath"
      throw "Required function Get-RepositoryRoot not found"
    }
  }

  # Load Import-EnvFile private helper
  $importEnvFilePath = Join-Path $PSScriptRoot '..\private\Import-EnvFile.ps1'
  if (Test-Path $importEnvFilePath) {
    . $importEnvFilePath
  }
  else {
    Write-PSFMessage -Level Error -Message "Import-EnvFile.ps1 not found at: $importEnvFilePath"
    throw "Required function Import-EnvFile not found"
  }
}
catch {
  $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
  throw
}

# Load .env file into environment variables, then override with .env.local if present
$envBaseFile = "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Gmail\Database\Flyway\.env"
$envLocalFile = "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Gmail\Database\Flyway\.env.local"

# Load base .env file (required)
if (-not (Import-EnvFile -FilePath $envBaseFile -FileDescription ".env")) {
  Write-PSFMessage -Level Error -Message ".env file not found at: $envBaseFile"
  throw ".env file is required"
}

# Check what the base file set for FLYWAY_EXP_URL
$baseExpUrl = [Environment]::GetEnvironmentVariable("FLYWAY_EXP_URL", [EnvironmentVariableTarget]::Process)
Write-PSFMessage -Level Verbose -Message "After loading .env: FLYWAY_EXP_URL = $baseExpUrl"

# Load .env.local file (optional, overrides base .env)
if (Import-EnvFile -FilePath $envLocalFile -FileDescription ".env.local") {
  Write-PSFMessage -Level Important -Message "Local environment overrides applied from .env.local"

  # Check what .env.local set for FLYWAY_EXP_URL
  $localExpUrl = [Environment]::GetEnvironmentVariable("FLYWAY_EXP_URL", [EnvironmentVariableTarget]::Process)
  Write-PSFMessage -Level Verbose -Message "After loading .env.local: FLYWAY_EXP_URL = $localExpUrl"
}

# Set the environment to use (this should match the environment passed to databaseProvisioning and invoke-Flyway)
$databaseName = 'GMAIL'
$environment = 'Experimental'
$envPrefix = switch ($environment) {
  'Development' { 'DEV' }
  'Experimental' { 'EXP' }
  'Test' { 'TEST' }
  'Production' { 'PROD' }
  default { throw "Unknown environment: $environment" }
}

Write-PSFMessage -Level Important -Message "Using environment: $environment (prefix: $envPrefix)"

# Map environment-specific variables to generic FLYWAY_* variables
$env:FLYWAY_URL = [Environment]::GetEnvironmentVariable("FLYWAY_${envPrefix}_URL", [EnvironmentVariableTarget]::Process)
$env:FLYWAY_USER = [Environment]::GetEnvironmentVariable("FLYWAY_${envPrefix}_USER", [EnvironmentVariableTarget]::Process)
$env:FLYWAY_PASSWORD = [Environment]::GetEnvironmentVariable("FLYWAY_${envPrefix}_PASSWORD", [EnvironmentVariableTarget]::Process)

Write-PSFMessage -Level Important -Message "Mapped FLYWAY_${envPrefix}_URL to FLYWAY_URL"
Write-PSFMessage -Level Important -Message "  Source value (FLYWAY_${envPrefix}_URL): $([Environment]::GetEnvironmentVariable("FLYWAY_${envPrefix}_URL", [EnvironmentVariableTarget]::Process))"
Write-PSFMessage -Level Important -Message "  Target value (FLYWAY_URL): $env:FLYWAY_URL"
Write-PSFMessage -Level Verbose -Message "Mapped FLYWAY_${envPrefix}_USER to FLYWAY_USER: $env:FLYWAY_USER"
Write-PSFMessage -Level Verbose -Message "Mapped FLYWAY_${envPrefix}_PASSWORD to FLYWAY_PASSWORD: $(if($env:FLYWAY_PASSWORD){'<set>'}else{'<not set>'})"

# Check if using integrated authentication
$usingIntegratedAuth = $env:FLYWAY_URL -match 'integratedSecurity=true'
if ($usingIntegratedAuth) {
  Write-PSFMessage -Level Important -Message "Using Windows Integrated Authentication"
}

# Validate critical environment variables
# FLYWAY_URL is always required
if ([string]::IsNullOrWhiteSpace($env:FLYWAY_URL)) {
  Write-PSFMessage -Level Error -Message "Required environment variable not set: FLYWAY_URL (from FLYWAY_${envPrefix}_URL)"
  Write-PSFMessage -Level Warning -Message "Checking all FLYWAY_* variables:"
  Get-ChildItem env: | Where-Object { $_.Name -like 'FLYWAY*' } | ForEach-Object {
    Write-PSFMessage -Level Warning -Message "  $($_.Name) = $($_.Value)"
  }
  throw "Missing required environment variable: FLYWAY_URL for environment $environment"
}

# FLYWAY_USER and FLYWAY_PASSWORD are only required if NOT using integrated authentication
if (-not $usingIntegratedAuth) {
  $requiredAuthVars = @('FLYWAY_USER', 'FLYWAY_PASSWORD')
  foreach ($envVar in $requiredAuthVars) {
    $value = [Environment]::GetEnvironmentVariable($envVar, [EnvironmentVariableTarget]::Process)
    if ([string]::IsNullOrWhiteSpace($value)) {
      Write-PSFMessage -Level Error -Message "Required environment variable not set: $envVar (from FLYWAY_${envPrefix}_$(($envVar -replace 'FLYWAY_','')))"
      Write-PSFMessage -Level Error -Message "SQL authentication requires both FLYWAY_USER and FLYWAY_PASSWORD"
      throw "Missing required environment variable: $envVar for environment $environment"
    }
    else {
      Write-PSFMessage -Level Verbose -Message "Validated environment variable: $envVar = $value"
    }
  }
}
else {
  Write-PSFMessage -Level Verbose -Message "Skipping FLYWAY_USER and FLYWAY_PASSWORD validation (using integrated authentication)"
}

# Extract SQL Server instance from FLYWAY_URL
# Expected format: jdbc:sqlserver://localhost:1433;databaseName=Gmail
if ($env:FLYWAY_URL -match 'sqlserver://([^:; ]+)(?::(\d+))?') {
  $SqlInstance = $matches[1]
  $sqlPort = if ($matches[2]) { $matches[2] } else { "1433" }
  Write-PSFMessage -Level Important -Message "Extracted SQL Server: $SqlInstance, Port: $sqlPort"

  # Check for trustServerCertificate setting in connection string
  $trustServerCert = $env:FLYWAY_URL -match 'trustServerCertificate=true'

  # Test SQL Server connectivity
  try {
    Write-PSFMessage -Level Important -Message "Testing SQL Server connection to $SqlInstance..."
    $testQuery = "SELECT @@VERSION AS Version"

    # Build test parameters based on authentication method
    if ($usingIntegratedAuth) {
      $testParams = @{
        ServerInstance         = $SqlInstance
        Query                  = $testQuery
        TrustServerCertificate = $trustServerCert
        ErrorAction            = 'Stop'
      }
      Write-PSFMessage -Level Verbose -Message "Using Windows Integrated Authentication for connection test"
    }
    else {
      $testParams = @{
        ServerInstance         = $SqlInstance
        Query                  = $testQuery
        Username               = $env:FLYWAY_USER
        Password               = $env:FLYWAY_PASSWORD
        TrustServerCertificate = $trustServerCert
        ErrorAction            = 'Stop'
      }
      Write-PSFMessage -Level Verbose -Message "Using SQL Authentication for connection test"
    }

    if ($trustServerCert) {
      Write-PSFMessage -Level Verbose -Message "TrustServerCertificate enabled"
    }

    $testResult = Invoke-Sqlcmd @testParams
    Write-PSFMessage -Level Important -Message "Successfully connected to SQL Server"
    Write-PSFMessage -Level Important -Message "SQL Server Version: $($testResult.Version)"
  }
  catch {
    Write-PSFMessage -Level Error -Message "Failed to connect to SQL Server instance '$SqlInstance'. Error: $($_.Exception.Message)"
    Write-PSFMessage -Level Error -Message "Please verify:"
    Write-PSFMessage -Level Error -Message "  1. SQL Server service is running"
    Write-PSFMessage -Level Error -Message "  2. Instance name is correct in FLYWAY_URL: $env:FLYWAY_URL"
    if ($usingIntegratedAuth) {
      Write-PSFMessage -Level Error -Message "  3. Windows user has appropriate SQL Server permissions"
      Write-PSFMessage -Level Error -Message "  4. SQL Server is configured to allow Windows Authentication"
    }
    else {
      Write-PSFMessage -Level Error -Message "  3. SQL Server is configured for SQL authentication"
      Write-PSFMessage -Level Error -Message "  4. Username and password are correct"
    }
    Write-PSFMessage -Level Error -Message "  5. Network connectivity and firewall rules allow connection"
    Write-PSFMessage -Level Error -Message "  6. If using self-signed certificates, ensure trustServerCertificate=true in connection string"
    throw "Cannot connect to SQL Server"
  }
}
else {
  Write-PSFMessage -Level Error -Message "Invalid FLYWAY_URL format: $env:FLYWAY_URL"
  throw "Cannot parse SQL Server instance from FLYWAY_URL"
}

# CRITICAL FIX: Flyway placeholders MUST be set as FLYWAY_PLACEHOLDERS_<PLACEHOLDER_NAME>
# The flyway.toml uses placeholder names: data_dir, PackageName, etc.
# Flyway automatically reads FLYWAY_PLACEHOLDERS_* environment variables
# We convert FLYWAY_DATA_DIR → FLYWAY_PLACEHOLDERS_DATA_DIR (uppercase with underscores)
if ($env:FLYWAY_DATA_DIR) {
  $env:FLYWAY_PLACEHOLDERS_DATA_DIR = $env:FLYWAY_DATA_DIR
  Write-PSFMessage -Level Important -Message "Set FLYWAY_PLACEHOLDERS_DATA_DIR = $env:FLYWAY_PLACEHOLDERS_DATA_DIR"
}

$repositoryRoot = Get-RepositoryRoot -ErrorAction Stop

# Recreate the Gmail database from scratch using Flyway migrations
try {
  . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\DatabaseProvisioning.ps1' -verbose
  . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-Flyway.ps1'
  Set-Location  (join-path $repositoryRoot "src\ATAP.Utilities.Gmail\Database\Flyway")

  Write-PSFMessage -Level Important -Message "Starting database provisioning..."
  Write-PSFMessage -Level Important -Message "Target Server: $SqlInstance"
  Write-PSFMessage -Level Important -Message "Database: Gmail"
  Write-PSFMessage -Level Important -Message "Environment: Experimental"

  # Create SQL connection object from FLYWAY_URL
  Write-PSFMessage -Level Verbose -Message "Creating SQL connection object"
  $sqlConnection = New-Object System.Data.SqlClient.SqlConnection

  # Build connection string for SQL connection
  # Convert JDBC URL format to ADO.NET connection string format
  # From: jdbc:sqlserver://UTAT01;databaseName=Gmail;integratedSecurity=true;encrypt=false;trustServerCertificate=true
  # To: Server=UTAT01;Database=master;Integrated Security=true;Encrypt=false;TrustServerCertificate=true

  $connectionStringBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
  $connectionStringBuilder["Server"] = $SqlInstance
  $connectionStringBuilder["Database"] = "master"  # Connect to master initially for provisioning

  if ($usingIntegratedAuth) {
    $connectionStringBuilder["Integrated Security"] = $true
  }
  else {
    $connectionStringBuilder["User ID"] = $env:FLYWAY_USER
    $connectionStringBuilder["Password"] = $env:FLYWAY_PASSWORD
  }

  # Set encryption settings based on FLYWAY_URL
  $encryptDisabled = $env:FLYWAY_URL -match 'encrypt=false'
  if ($encryptDisabled) {
    $connectionStringBuilder["Encrypt"] = $false
  }

  if ($trustServerCert) {
    $connectionStringBuilder["TrustServerCertificate"] = $true
  }

  $connectionStringBuilder["Connection Timeout"] = 30

  $sqlConnection.ConnectionString = $connectionStringBuilder.ConnectionString
  Write-PSFMessage -Level Verbose -Message "SQL Connection String built (credentials hidden)"

  # Open and test the connection
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
    DatabasePath    = $global:settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']].Gmail.$environment.DatabasePath
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

  # Ensure FLYWAY_URL doesn't include named instance for default SQL Server instance
  if ($env:FLYWAY_URL -match ';instanceName=SQLEXPRESS') {
    Write-PSFMessage -Level Warning -Message "Removing instanceName=SQLEXPRESS from FLYWAY_URL (connecting to default instance)"
    $env:FLYWAY_URL = $env:FLYWAY_URL -replace ';instanceName=SQLEXPRESS', ''
    Write-PSFMessage -Level Important -Message "Updated FLYWAY_URL: $env:FLYWAY_URL"
  }

  # Clear user/password environment variables when using integrated authentication
  if ($usingIntegratedAuth) {
    Write-PSFMessage -Level Important -Message "Clearing Flyway user/password environment variables for integrated authentication"

    $envVarsToRemove = @(
      'FLYWAY_USER',
      'FLYWAY_PASSWORD',
      'FLYWAY_EXP_USER',
      'FLYWAY_EXP_PASSWORD',
      'FLYWAY_DEV_USER',
      'FLYWAY_DEV_PASSWORD',
      'FLYWAY_TEST_USER',
      'FLYWAY_TEST_PASSWORD',
      'FLYWAY_PROD_USER',
      'FLYWAY_PROD_PASSWORD'
    )

    foreach ($envVar in $envVarsToRemove) {
      if (Test-Path "Env:$envVar") {
        Remove-Item "Env:$envVar" -ErrorAction SilentlyContinue
        Write-PSFMessage -Level Verbose -Message "Removed: $envVar"
      }
    }
  }

  $pathToToml = '..\flyway.toml'
  if (-not (Test-Path $pathToToml)) {
    throw "Flyway configuration file not found: $pathToToml"
  }

  Write-PSFMessage -Level Important -Message "Running Flyway migrations..."
  invoke-Flyway -DatabaseName Gmail -Environment $environment -PackageName Gmail.Functions -PackageVersion 1 -FlywayAdditionalArgs "" -FlywayCommand 'migrate' -SqlDir "C:\Dropbox\whertzing\GitHub\Gmail\Databases\Flyway\SQL" -ConfigPath $pathToToml

  Write-PSFMessage -Level Important -Message "Database rebuild completed successfully"
}
catch {
  Write-PSFMessage -Level Error -Message "Database rebuild failed: $($_.Exception.Message)"
  Write-PSFMessage -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
  throw
}

# invoke the OpenMetadata ingestion process

# Build-All script for Tags database
# This script builds the Tags database and loads initial data

# Set the database name
$databaseName = 'Tags'
# Set the database host
$databaseHost = 'localhost'
# Set the environment to use (this will be passed to databaseProvisioning and Invoke-Flyway)
$environment = 'Development'
# Set the ConnectionMethod
$connectionMethod = 'tcp'
# Set the path where the database files will be created
$databasePath = "C:\LocalDBs\$environment\$databaseName"
# Set the path to the provisioning scripts
$ProvisioningScriptsPath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement\SharedSQL'
# Set the FlywayBasePath
$flywayBasePath = "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.$databaseName\Database\Flyway"
# Set the path to the SQL migrations
$flywaySqlMigrationsPath = Join-Path $flywayBasePath 'SQL'
# Set the path to the shared SQL migration scripts
$flywaySharedSqlMigrationsPath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement\SharedSQL'
# Set the path to the Flyway Data directory
$flywayDataPath = Join-Path $flywayBasePath 'DATA'
# Set the path to the Flyway configuration file
$FlywayTomlPath = Join-Path $flywayBasePath 'flyway.toml'
# Force the database to be dropped and recreated
$Force = $true

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
  if (-not (Get-Command -Name 'Build-DatabaseWithFlyway' -CommandType Function -ErrorAction SilentlyContinue)) {
    . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Build-DatabaseWithFlyway.ps1'
  }
  # Load the data loading function
  if (-not (Get-Command -Name 'Load-Tags' -CommandType Function -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'Load-Tags.ps1')
  }
}
catch {
  $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
  Write-PSFMessage -Level Error -Message $errorMessage
  throw
}


# Set FLYWAY_PLACEHOLDERS_DATA_DIR from FLYWAY_DATA_DIR
if ($env:FLYWAY_DATA_DIR) {
  $env:FLYWAY_PLACEHOLDERS_DATA_DIR = $env:FLYWAY_DATA_DIR
  Write-PSFMessage -Level Important -Message "Set FLYWAY_PLACEHOLDERS_DATA_DIR = $env:FLYWAY_PLACEHOLDERS_DATA_DIR"
}

Write-PSFMessage -Level Important -Message "=== Starting $databaseName Database Build ==="
Write-PSFMessage -Level Important -Message "Database: $databaseName"
Write-PSFMessage -Level Important -Message "Database host: $databaseHost"
Write-PSFMessage -Level Important -Message "Using environment: $environment"
Write-PSFMessage -Level Important -Message "Connection method: $connectionMethod"
Write-PSFMessage -Level Important -Message "Database path: $databasePath"
Write-PSFMessage -Level Important -Message "Provisioning scripts path: $ProvisioningScriptsPath"
Write-PSFMessage -Level Important -Message "Flyway base path: $flywayBasePath"
Write-PSFMessage -Level Important -Message "Flyway SQL migrations path: $flywaySqlMigrationsPath"
Write-PSFMessage -Level Important -Message "Flyway  Shared SQL migrations path: $flywaySharedSqlMigrationsPath"
Write-PSFMessage -Level Important -Message "Flyway Data path: $flywayDataPath"
Write-PSFMessage -Level Important -Message "Flyway configuration file path: $FlywayTomlPath"

# Configure dbatools SSL/encryption settings
Write-PSFMessage -Level Verbose -Message "Configuring dbatools to trust server certificates"
Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -PassThru | Register-DbatoolsConfig
Set-DbatoolsConfig -FullName sql.connection.encrypt -Value $false -PassThru | Register-DbatoolsConfig

# Build the database using Flyway migrations
try {
  Write-PSFMessage -Level Important -Message "Building database from Flyway migrations..."

  $buildResult = Build-DatabaseWithFlyway `
    -DatabaseName $databaseName `
    -Environment $environment `
    -DatabaseHost $databaseHost `
    -ConnectionMethod $connectionMethod `
    -DatabasePath $databasePath `
    -ProvisioningScriptsPath $ProvisioningScriptsPath `
    -FlywayBasePath $FlywayBasePath `
    -FlywaySqlMigrationsPath $flywaySqlMigrationsPath `
    -FlywaySharedSqlMigrationsPath $flywaySharedSqlMigrationsPath `
    -FlywayDataPath $flywayDataPath `
    -FlywayTomlPath $FlywayTomlPath `
    -Force:$Force `
    -Verbose:$VerbosePreference

  if (-not $buildResult.Success) {
    throw "Database build failed. Errors: $($buildResult.Errors -join '; ')"
  }

  Write-PSFMessage -Level Important -Message "Database build completed successfully"
}
catch {
  Write-PSFMessage -Level Error -Message "Database build failed: $($_.Exception.Message)"
  Write-PSFMessage -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
  throw
}

# After successful build, load the data into the database
try {
  Write-PSFMessage -Level Important -Message "Loading $databaseName data into database..."

  Load-Tags `
    -DatabaseHost $databaseHost `
    -DatabaseName $databaseName `
    -Environment $environment `
    -IntegratedSecurity `
    -Verbose:$VerbosePreference

  Write-PSFMessage -Level Important -Message "=== $databaseName Database Build Complete ==="
}
catch {
  Write-PSFMessage -Level Error -Message "Load-Tags failed: $($_.Exception.Message)"
  throw
}

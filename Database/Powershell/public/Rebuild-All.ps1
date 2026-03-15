# Rebuild-All script for ATAPUtilities database
# This script builds the ATAPUtilities database and loads initial data

# Compute repo root from this script's known position in the tree:
#   <repo_root>\Database\Powershell\public\Rebuild-All.ps1  =>  3 levels up
# Using $PSScriptRoot makes this work regardless of the shell's current directory.
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

# Set the database name
$databaseName = 'ATAPUtilities'
# Set the database host
$databaseHost = 'localhost'
# Set the environment to use (this will be passed to databaseProvisioning and Invoke-Flyway)
$environment = 'Experimental'
# Set the ConnectionMethod
$connectionMethod = 'tcp'
# Set the path where the database files will be created (intentionally absolute - storage location)
$databasePath = "C:\LocalDBs\$environment\$databaseName"
# Set the path to the provisioning scripts
$ProvisioningScriptsPath = Join-Path $repositoryRoot 'src\ATAP.Utilities.DatabaseManagement\SharedSQL'
# Set the FlywayBasePath - using Database folder (singular) for the new structure
$flywayBasePath = Join-Path $repositoryRoot 'Database\Flyway'
# Set the path to the SQL migrations
$flywaySqlMigrationsPath = Join-Path $flywayBasePath 'SQL'
# Set the path to the shared SQL migration scripts
$flywaySharedSqlMigrationsPath = Join-Path $repositoryRoot 'src\ATAP.Utilities.DatabaseManagement\SharedSQL'
# Set the path to the Flyway Data directory
$flywayDataPath = Join-Path $flywayBasePath 'Data'
# Set the path to the Flyway configuration file
$FlywayTomlPath = Join-Path $flywayBasePath 'flyway.toml'
# Force the database to be dropped and recreated
$Force = $true

# Load required helper functions
# Pre-loading from $repositoryRoot ensures the -if already loaded- guards inside each function
# skip their own hardcoded dot-source paths (which point to the non-worktree repo).
try {
  # Import dbatools module for database operations (avoid SqlServer module to prevent assembly conflicts)
  if (-not (Get-Module -Name dbatools -ListAvailable)) {
    Write-PSFMessage -Level Warning -Message "dbatools module not found. Installing..."
    Install-Module -Name dbatools -Scope CurrentUser -Force -AllowClobber
  }
  Import-Module dbatools -ErrorAction Stop

  $helperScripts = @(
    'src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-RepositoryRoot.ps1',
    'src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1',
    'src\ATAP.Utilities.Security.Powershell\public\Get-BitWardenSecret.ps1',
    'src\ATAP.Utilities.DatabaseManagement.Powershell\public\New-ConnectionStringBuilderFromDbaTools.ps1',
    'src\ATAP.Utilities.DatabaseManagement.Powershell\public\DatabaseProvisioning.ps1',
    'src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-Flyway.ps1',
    'src\ATAP.Utilities.DatabaseManagement.Powershell\public\Build-DatabaseWithFlyway.ps1'
  )
  foreach ($script in $helperScripts) {
    $scriptPath = Join-Path $repositoryRoot $script
    if (-not (Test-Path $scriptPath)) {
      throw "Required helper script not found: $scriptPath"
    }
    . $scriptPath
  }
}
catch {
  $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
  Write-PSFMessage -Level Error -Message $errorMessage
  throw
}

Write-PSFMessage -Level Important -Message "=== Starting $databaseName Database Build ==="
Write-PSFMessage -Level Important -Message "Repository root: $repositoryRoot"
Write-PSFMessage -Level Important -Message "Database: $databaseName"
Write-PSFMessage -Level Important -Message "Database host: $databaseHost"
Write-PSFMessage -Level Important -Message "Using environment: $environment"
Write-PSFMessage -Level Important -Message "Connection method: $connectionMethod"
Write-PSFMessage -Level Important -Message "Database path: $databasePath"
Write-PSFMessage -Level Important -Message "Provisioning scripts path: $ProvisioningScriptsPath"
Write-PSFMessage -Level Important -Message "Flyway base path: $flywayBasePath"
Write-PSFMessage -Level Important -Message "Flyway SQL migrations path: $flywaySqlMigrationsPath"
Write-PSFMessage -Level Important -Message "Flyway Shared SQL migrations path: $flywaySharedSqlMigrationsPath"
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
    -FlywayBasePath $flywayBasePath `
    -FlywaySqlMigrationsPath $flywaySqlMigrationsPath `
    -FlywaySharedSqlMigrationsPath $flywaySharedSqlMigrationsPath `
    -FlywayDataPath $flywayDataPath `
    -FlywayTomlPath $FlywayTomlPath `
    -IntegratedSecurity `
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
# Note: Data loading via afterVersioned__ImportData.ps1 Flyway callback handles BCP file imports
# Future: Create Load-ATAPUtilities function if additional data loading is needed
try {
  Write-PSFMessage -Level Important -Message "=== $databaseName Database Build Complete ==="
  Write-PSFMessage -Level Important -Message "Note: Initial data loaded via Flyway migration callbacks"

  # Future data loading example:
  # Write-PSFMessage -Level Important -Message "Loading $databaseName data into database..."
  # Load-ATAPUtilities `
  #   -DatabaseHost $databaseHost `
  #   -DatabaseName $databaseName `
  #   -Environment $environment `
  #   -IntegratedSecurity `
  #   -Verbose:$VerbosePreference
}
catch {
  Write-PSFMessage -Level Error -Message "Post-build processing failed: $($_.Exception.Message)"
  throw
}

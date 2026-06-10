# Rebuild-All-AllInstances script for ATAPUtilities database
# Builds the ATAPUtilities database on all three named instances in sequence:
#   Testing  -> QA instance         (C:\LocalDBs\QA\ATAPUtilities)
#   Development -> Integration instance (C:\LocalDBs\Integration\ATAPUtilities)
#   Production  -> Production instance  (C:\LocalDBs\Production\ATAPUtilities)
#
# This is a top-level script - it has no parameters. All configuration is
# done via the variables defined below.

# Compute repo root from this script's known position in the tree:
#   <repo_root>\Database\Powershell\public\Rebuild-All-AllInstances.ps1  =>  3 levels up
# Using $PSScriptRoot makes this work regardless of the shell's current directory.
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

$databaseName = 'ATAPUtilities'
$databaseHost = 'localhost'
$connectionMethod = 'tcp'
$Force = $true

$ProvisioningScriptsPath = Join-Path $repositoryRoot 'src\ATAP.Utilities.DatabaseManagement\SharedSQL'
$flywayBasePath = Join-Path $repositoryRoot 'Database\Flyway'
$flywaySqlMigrationsPath = Join-Path $flywayBasePath 'SQL'
$flywaySharedSqlMigrationsPath = Join-Path $repositoryRoot 'src\ATAP.Utilities.DatabaseManagement\SharedSQL'
$flywayDataPath = Join-Path $flywayBasePath 'Data'
$FlywayTomlPath = Join-Path $flywayBasePath 'flyway.toml'

# Load required helper functions
try {
  if (-not (Get-Module -Name dbatools -ListAvailable)) {
    Write-PSFMessage -Level Warning -Message 'dbatools module not found. Installing...'
    Install-Module -Name dbatools -Scope CurrentUser -Force -AllowClobber
  }
  Import-Module dbatools -ErrorAction Stop

  $helperScripts = @(
    'src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-RepositoryRoot.ps1',
    'src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1',
    'src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-SecretATAPBitwarden.ps1',
    'src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-SecretATAP.ps1',
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
} catch {
  $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
  Write-PSFMessage -Level Error -Message $errorMessage
  throw
}

# Configure dbatools SSL/encryption settings
Write-PSFMessage -Level Verbose -Message 'Configuring dbatools to trust server certificates'
Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -PassThru | Register-DbatoolsConfig
Set-DbatoolsConfig -FullName sql.connection.encrypt -Value $false -PassThru | Register-DbatoolsConfig

# Define each instance to build
$instances = @(
  [PSCustomObject]@{ Environment = 'Testing'; SqlInstance = 'QA'; DatabasePath = "C:\LocalDBs\QA\$databaseName" }
  [PSCustomObject]@{ Environment = 'Development'; SqlInstance = 'Integration'; DatabasePath = "C:\LocalDBs\Integration\$databaseName" }
  [PSCustomObject]@{ Environment = 'Production'; SqlInstance = 'Production'; DatabasePath = "C:\LocalDBs\Production\$databaseName" }
)

$overallSuccess = $true

foreach ($inst in $instances) {
  Write-PSFMessage -Level Important -Message "=== Starting $databaseName on $($inst.SqlInstance) (Environment: $($inst.Environment)) ==="

  try {
    $buildResult = Build-DatabaseWithFlyway `
      -DatabaseName $databaseName `
      -Environment $inst.Environment `
      -DatabaseHost $databaseHost `
      -SqlInstance $inst.SqlInstance `
      -ConnectionMethod $connectionMethod `
      -DatabasePath $inst.DatabasePath `
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

    Write-PSFMessage -Level Important -Message "=== $databaseName on $($inst.SqlInstance) completed successfully ==="
  } catch {
    Write-PSFMessage -Level Error -Message "Build failed for $($inst.SqlInstance): $($_.Exception.Message)"
    Write-PSFMessage -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
    $overallSuccess = $false
    # Continue to next instance rather than aborting all
  }
}

if (-not $overallSuccess) {
  throw 'One or more instances failed to build. Review PSFMessage logs above.'
}

Write-PSFMessage -Level Important -Message '=== All instances built successfully ==='

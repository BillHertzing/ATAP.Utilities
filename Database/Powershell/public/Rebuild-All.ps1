# Rebuild-All.ps1 — Top-level script to build all ATAP databases across all environments.
# All configuration is via the variables below; this script accepts no parameters.
# AI assisted using Powershell.instructions.md as guidelines

# Compute repo root: script is at <repo_root>\Database\Powershell\public\Rebuild-All.ps1 => 3 levels up
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

# Environments to target
[string[]]$environments = @('Experimental', 'Development')

# Force drop-and-recreate even if database already exists
$force = $true

# Shared paths
$provisioningScriptsPath       = Join-Path $repositoryRoot 'src\ATAP.Utilities.DatabaseManagement\SharedSQL'
$flywaySharedSqlMigrationsPath = Join-Path $repositoryRoot 'src\ATAP.Utilities.DatabaseManagement\SharedSQL'

# ATAPUtilities-specific Flyway paths
$atapFlywayBasePath          = Join-Path $repositoryRoot 'Database\Flyway'
$atapFlywaySqlMigrationsPath = Join-Path $atapFlywayBasePath 'SQL'
$atapFlywayDataPath          = Join-Path $atapFlywayBasePath 'Data'
$atapFlywayTomlPath          = Join-Path $atapFlywayBasePath 'flyway.toml'

# Per-database configuration.
# SkipFlyway = $true for databases whose migrations live in a different repository.
$databaseConfigs = @(
  @{
    DatabaseName              = 'ATAPUtilities'
    SkipFlyway                = $false
    FlywayBasePath            = $atapFlywayBasePath
    FlywaySqlMigrationsPath   = $atapFlywaySqlMigrationsPath
    FlywayDataPath            = $atapFlywayDataPath
    FlywayTomlPath            = $atapFlywayTomlPath
  },
  @{
    DatabaseName              = 'AceCommander'
    SkipFlyway                = $true   # AceCommander migrations live in the AceCommander repo
    FlywayBasePath            = $null
    FlywaySqlMigrationsPath   = $null
    FlywayDataPath            = $null
    FlywayTomlPath            = $null
  }
)

# Pre-loading from $repositoryRoot ensures the -if already loaded- guards inside each function
# skip their own hardcoded dot-source paths (which point to the non-worktree repo).
try {
  if (-not (Get-Module -Name dbatools -ListAvailable)) {
    Write-PSFMessage -Level Warning -Message 'dbatools module not found. Installing...'
    Install-Module -Name dbatools -Scope CurrentUser -Force -AllowClobber
  }
  Import-Module dbatools -ErrorAction Stop

  $helperScripts = @(
    'src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-RepositoryRoot.ps1',
    'src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1',
    'src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-BWSAccessToken.ps1',
    'src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-SecretATAPBitwardenSecretsManager.ps1',
    'src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-SecretATAPBitwarden.ps1',
    'src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-SecretATAP.ps1',
    'src\ATAP.Utilities.DatabaseManagement.Powershell\public\New-ConnectionStringBuilderFromDbaTools.ps1',
    'src\ATAP.Utilities.DatabaseManagement.Powershell\public\Get-DatabaseCredentialsKey.ps1',
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

# Map full environment name to the 3-char tier abbreviation used in Bitwarden secret names
function get-tierAbbrev ([string]$envName) {
  switch ($envName) {
    'Development'  { return 'Dev' }
    'Experimental' { return 'Exp' }
    default        { return $envName }
  }
}

# Retrieve the master connection string for an environment from Bitwarden Secrets
# Manager and parse out DatabaseHost and SqlInstance. Secret name pattern:
#   dbConnectionString-master-localhost-<Dev|Exp>-<username>
function get-connectionInfoFromVault ([string]$envName) {
  $tierAbbrev = get-tierAbbrev -envName $envName
  $secretName = "dbConnectionString-master-localhost-${tierAbbrev}-$($env:USERNAME)"

  Write-PSFMessage -Level Verbose -Message "Retrieving connection info for '$envName' from secret '$secretName'"

  $rawConnStr = Get-SecretATAP `
    -SecretName $secretName `
    -SecretField 'notes' `
    -SecretStoreType 'BitwardenSecretsManager'

  if ([string]::IsNullOrWhiteSpace($rawConnStr)) {
    throw "Secret '$secretName' returned an empty connection string"
  }

  $csb = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new($rawConnStr)
  $rawDs = $csb.DataSource

  # Strip optional protocol prefix (tcp:, np:, lpc:)
  if ($rawDs -match '^(?:tcp:|np:|lpc:)(.+)$') { $rawDs = $Matches[1] }
  # Strip optional port suffix
  if ($rawDs -match '^(.+),\d+$') { $rawDs = $Matches[1] }
  # Split host\instance
  if ($rawDs -match '^([^\\]+)\\(.+)$') {
    return @{ DatabaseHost = $Matches[1]; SqlInstance = $Matches[2] }
  }
  return @{ DatabaseHost = $rawDs; SqlInstance = $null }
}

Write-PSFMessage -Level Important -Message '=== Starting Database Rebuild ==='
Write-PSFMessage -Level Important -Message "Repository root: $repositoryRoot"
Write-PSFMessage -Level Important -Message "Databases: $($databaseConfigs.DatabaseName -join ', ')"
Write-PSFMessage -Level Important -Message "Environments: $($environments -join ', ')"

$overallSuccess = $true
$buildResults = [System.Collections.ArrayList]::new()

foreach ($environment in $environments) {
  Write-PSFMessage -Level Important -Message "--- Environment: $environment ---"

  try {
    $connInfo     = get-connectionInfoFromVault -envName $environment
    $databaseHost = $connInfo.DatabaseHost
    $sqlInstance  = $connInfo.SqlInstance
    Write-PSFMessage -Level Important -Message "Connection info: Host='$databaseHost'  Instance='$sqlInstance'"
  } catch {
    $errMsg = $_.Exception.Message
    Write-PSFMessage -Level Error -Message "Failed to retrieve connection info for '$environment': $errMsg"
    $overallSuccess = $false
    foreach ($cfg in $databaseConfigs) {
      [void]$buildResults.Add([PSCustomObject]@{
          DatabaseName = $cfg.DatabaseName
          Environment  = $environment
          Success      = $false
          Error        = "Connection info lookup failed: $errMsg"
        })
    }
    continue
  }

  foreach ($cfg in $databaseConfigs) {
    $databaseName = $cfg.DatabaseName
    $databasePath = "C:\LocalDBs\$(get-tierAbbrev -envName $environment)$($env:USERNAME)\$databaseName"

    Write-PSFMessage -Level Important -Message "Building '$databaseName' in '$environment'$(if ($cfg.SkipFlyway) { ' (provision only)' })"
    Write-PSFMessage -Level Important -Message "  Server: $databaseHost\$sqlInstance"
    Write-PSFMessage -Level Important -Message "  Database path: $databasePath"

    try {
      $buildParams = @{
        DatabaseName              = $databaseName
        Environment               = $environment
        DatabaseHost              = $databaseHost
        SqlInstance               = $sqlInstance
        ConnectionMethod          = 'tcp'
        DatabasePath              = $databasePath
        ProvisioningScriptsPath   = $provisioningScriptsPath
        FlywaySharedSqlMigrationsPath = $flywaySharedSqlMigrationsPath
        IntegratedSecurity        = $true
        Force                     = $force
        SkipFlyway                = $cfg.SkipFlyway
        Verbose                   = $VerbosePreference
      }
      if (-not $cfg.SkipFlyway) {
        $buildParams['FlywayBasePath']          = $cfg.FlywayBasePath
        $buildParams['FlywaySqlMigrationsPath'] = $cfg.FlywaySqlMigrationsPath
        $buildParams['FlywayDataPath']          = $cfg.FlywayDataPath
        $buildParams['FlywayTomlPath']          = $cfg.FlywayTomlPath
      }

      $buildResult = Build-DatabaseWithFlyway @buildParams

      if (-not $buildResult.Success) {
        throw "Build-DatabaseWithFlyway reported failure: $($buildResult.Errors -join '; ')"
      }

      Write-PSFMessage -Level Important -Message "Successfully built '$databaseName' in '$environment'"
      [void]$buildResults.Add([PSCustomObject]@{
          DatabaseName = $databaseName
          Environment  = $environment
          Success      = $true
          Error        = $null
        })
    } catch {
      $errMsg = $_.Exception.Message
      Write-PSFMessage -Level Error -Message "Build failed for '$databaseName' / '$environment': $errMsg"
      Write-PSFMessage -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
      $overallSuccess = $false
      [void]$buildResults.Add([PSCustomObject]@{
          DatabaseName = $databaseName
          Environment  = $environment
          Success      = $false
          Error        = $errMsg
        })
    }
  }
}

Write-PSFMessage -Level Important -Message '=== Build Summary ==='
foreach ($r in $buildResults) {
  $status = if ($r.Success) { 'SUCCESS' } else { 'FAILED' }
  $detail = if ($r.Error) { " - $($r.Error)" } else { '' }
  Write-PSFMessage -Level Important -Message "$status  $($r.DatabaseName) / $($r.Environment)$detail"
}

if (-not $overallSuccess) {
  throw 'One or more database builds failed. See log for details.'
}

Write-PSFMessage -Level Important -Message '=== All database builds completed successfully ==='

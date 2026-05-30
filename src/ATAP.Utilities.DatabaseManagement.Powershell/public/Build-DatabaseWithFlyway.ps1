function Build-DatabaseWithFlyway {
  <#
.SYNOPSIS
Builds a SQL Server database from scratch using Flyway migrations.

.DESCRIPTION
This cmdlet orchestrates the complete build of a SQL Server database:
1. Resolves all connection and path settings from $global:settings via $global:configRootKeys
   (reads $global:settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']] —
   populated by HostSettings.IAC.Fragment.Databases.*.ps1 at session startup)
2. Configures database connection settings
3. Drops and recreates the database using DatabaseProvisioning
4. Runs Flyway migrations to create schema and objects

.PARAMETER DatabaseName
The name of the database to build (e.g. 'ATAPUtilities', 'PCMSC').

.PARAMETER Environment
The target environment: 'Production', 'QA', 'Integration', 'Development', or 'Experimental'.

.PARAMETER DatabaseHost
The SQL Server host. Resolved from $global:settings if not supplied; defaults to 'localhost'.

.PARAMETER SqlInstance
The SQL Server named instance (e.g. 'Production', 'Integration', 'Expwhertzing').
Resolved from $global:settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]
under the key path DatabaseName.Environment.SqlInstance.

IMPORTANT — Experimental environment: the HostSettings fragment stores a placeholder value
('Exp{username}') for the Experimental instance because it is an ephemeral per-sprint instance
created by New-SprintSqlServerInstances. When calling this function directly for Experimental,
you MUST supply -SqlInstance explicitly (e.g. -SqlInstance 'Expwhertzing'). The function will
throw if SqlInstance cannot be resolved to a non-empty value.

.PARAMETER FlywayBasePath
Path to the Flyway directory containing flyway.toml. Resolved from $global:settings if not supplied.

.PARAMETER SqlMigrationsPath
Path to the SQL migrations directory. Resolved from $global:settings if not supplied;
defaults to FlywayBasePath\SQL.

.PARAMETER SharedSqlMigrationsPath
Path to the shared SQL scripts directory. Resolved from $global:settings if not supplied.

.PARAMETER Force
Force database drop even if it exists. Default is $true.

.OUTPUTS
System.Object
Returns a result object with Success (bool) and any error messages.

.EXAMPLE
Build-DatabaseWithFlyway -DatabaseName 'ATAPUtilities' -Environment 'Experimental' -SqlInstance 'Expwhertzing'

.EXAMPLE
Build-DatabaseWithFlyway -DatabaseName 'ATAPUtilities' -Environment 'Integration'

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Requires dbatools module for database operations.
Requires Flyway CLI to be available in PATH or configured in environment variables.
Connection settings are NOT read from .env files — they are read from $global:settings.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ConnectionParts')]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialsKey',
    Justification = 'CredentialsKey is a vault lookup key name, not a credential')]
  param(
    # region Database connection parameters
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [string]$DatabaseName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$Environment,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [Alias('HostName')]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [Alias('InstanceName')]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [int]$Port,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParts')]
    [Parameter(Mandatory = $false, ParameterSetName = 'DBConnectionStringSecretName')]
    [switch]$IntegratedSecurity,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$CredentialsKey,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$ApplicationName,

    [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParts')]
    [switch]$UseTrustedConnection,

    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlConnection')]
    [Microsoft.Data.SqlClient.SqlConnection]$SqlConnection,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'DBConnectionStringSecretName')]
    [Alias('DBConnectionStringSecret', 'SecretName', 'BitwardenSecretName', 'BitwardenSecret')]
    [string]$DBConnectionStringSecretName,

    [Parameter(Mandatory = $false)]
    [hashtable]$Settings,
    # endregion Database connection parameters

    [Parameter(Mandatory = $false)]
    [string]$DatabasePath,

    [Parameter(Mandatory = $false)]
    [string]$ProvisioningScriptsPath,

    [Parameter(Mandatory = $false)]
    [string]$FlywayBasePath,

    [Parameter(Mandatory = $false)]
    [string]$flywaySqlMigrationsPath,

    [Parameter(Mandatory = $false)]
    [string]$flywaySharedSqlMigrationsPath,

    [Parameter(Mandatory = $false)]
    [string]$FlywayDataPath,

    [Parameter(Mandatory = $false)]
    [string]$FlywayTomlPath,

    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    # When set, run DatabaseProvisioning only and skip Flyway migrations.
    # Use for databases whose migrations live in a different repository.
    [Parameter(Mandatory = $false)]
    [switch]$SkipFlyway
  )

  begin {
    # Local helper: adjust a path so it is valid after Set-Location $FlywayBasePath.
    # Absolute paths are returned unchanged.
    # Relative paths were originally relative to $OriginalLocation; they are resolved
    # to an absolute path so they remain correct once the working directory changes.
    # Call syntax: adjust-path $originalLocation, $FlywayBasePath, $SomePath
    #   (the three values arrive as a single [string[]] array due to PowerShell comma syntax)
    function adjust-path {
      param([string[]]$PathArgs)
      $originalLoc = $PathArgs[0]
      # $PathArgs[1] ($FlywayBasePath) is accepted for call-site symmetry but not needed here
      $path = $PathArgs[2]
      if ([string]::IsNullOrWhiteSpace($path)) { return $null }
      if ([System.IO.Path]::IsPathRooted($path)) { return $path }
      # Resolve relative path against the original working directory
      return [System.IO.Path]::GetFullPath((Join-Path $originalLoc $path))
    }

    $fn = 'Build-DatabaseWithFlyway'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Load Helpers
    try {
      # ToDo: Remove this when packaging works
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1"
      }
    }
    catch {
      $errorMessage = "Failed to load Get-ParameterValueFromNeoConfigurationRoot function. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    # Load required helper functions
    try {
      # Import dbatools module for database operations
      if (-not (Get-Module -Name dbatools -ListAvailable)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message 'dbatools module not found. Installing...'
        Install-Module -Name dbatools -Scope CurrentUser -Force -AllowClobber
      }
      Import-Module dbatools -ErrorAction Stop
      if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        if (-not (Get-Command -Name 'Get-RepositoryRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
          . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-RepositoryRoot.ps1'
        }
        $repositoryRoot = Get-RepositoryRoot
      } else {
        $repositoryRoot = $RepositoryRoot
      }
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . (Join-Path $repositoryRoot 'src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1')
      }
      if (-not (Get-Command -Name 'Resolve-DatabaseSqlConnection' -CommandType Function -ErrorAction SilentlyContinue)) {
        . (Join-Path $repositoryRoot 'src\ATAP.Utilities.DatabaseManagement.Powershell\public\Resolve-DatabaseSqlConnection.ps1')
      }
      if (-not (Get-Command -Name 'DatabaseProvisioning' -CommandType Function -ErrorAction SilentlyContinue)) {
        . (Join-Path $repositoryRoot 'src\ATAP.Utilities.DatabaseManagement.Powershell\public\DatabaseProvisioning.ps1')
      }
      if (-not (Get-Command -Name 'Invoke-Flyway' -CommandType Function -ErrorAction SilentlyContinue)) {
        . (Join-Path $repositoryRoot 'src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-Flyway.ps1')
      }
    } catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.Errors += $errorMessage
      throw
    }

    $databasesCollection = if ($Settings) {
      $Settings
    }
    elseif ($global:settings -and $global:configRootKeys -and $global:configRootKeys['DatabasesCollectionConfigRootKey']) {
      $global:settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]
    }
    else {
      $null
    }

    $DatabaseName = Get-PVal -ParameterName 'DatabaseName' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.DatabaseName" -Settings $databasesCollection -DefaultValue $DatabaseName
    $Environment = Get-PVal -ParameterName 'Environment' -originalPSBoundParameters $PSBoundParameters -DefaultValue $Environment -ValidValues @('Production', 'QA', 'Integration', 'Development', 'Experimental') -AllowMissing
    $DatabasePath = Get-PVal -ParameterName 'DatabasePath' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.DatabasePath" -Settings $databasesCollection -DefaultValue $DatabasePath -AllowMissing
    $ProvisioningScriptsPath = Get-PVal -ParameterName 'ProvisioningScriptsPath' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.ProvisioningScriptsPath" -Settings $databasesCollection -DefaultValue $ProvisioningScriptsPath -AllowMissing
    $FlywayBasePath = Get-PVal -ParameterName 'FlywayBasePath' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywayBasePath" -Settings $databasesCollection -DefaultValue $FlywayBasePath
    $flywaySqlMigrationsPath = Get-PVal -ParameterName 'FlywaySqlMigrationsPath' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywaySqlMigrationsPath" -Settings $databasesCollection -DefaultValue $flywaySqlMigrationsPath -AllowMissing
    $flywaySharedSqlMigrationsPath = Get-PVal -ParameterName 'FlywaySharedSqlMigrationsPath' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywaySharedSqlMigrationsPath" -Settings $databasesCollection -DefaultValue $flywaySharedSqlMigrationsPath -AllowMissing
    $FlywayDataPath = Get-PVal -ParameterName 'FlywayDataPath' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywayDataPath" -Settings $databasesCollection -DefaultValue $FlywayDataPath -AllowMissing
    $FlywayTomlPath = Get-PVal -ParameterName 'FlywayTomlPath' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywayTomlPath" -Settings $databasesCollection -DefaultValue $FlywayTomlPath -AllowMissing

    $resolverBoundParameters = @{}
    foreach ($key in $PSBoundParameters.Keys) {
      $resolverBoundParameters[$key] = $PSBoundParameters[$key]
    }
    $resolverBoundParameters['DatabaseName'] = 'master'

    $resolution = Resolve-DatabaseSqlConnection `
      -OriginalPSBoundParameters $resolverBoundParameters `
      -SqlConnection $SqlConnection `
      -DBConnectionStringSecretName $DBConnectionStringSecretName `
      -DatabaseHost $DatabaseHost `
      -InstanceName $SqlInstance `
      -DatabaseName 'master' `
      -ConnectionMethod $ConnectionMethod `
      -CredentialsKey $CredentialsKey `
      -ApplicationName $ApplicationName `
      -UseTrustedConnection:$UseTrustedConnection `
      -IntegratedSecurity:$IntegratedSecurity `
      -Settings $databasesCollection `
      -DatabaseHostDottedPath "$databaseName.$Environment.DatabaseHost" `
      -InstanceNameDottedPath "$databaseName.$Environment.SqlInstance" `
      -ConnectionMethodDottedPath "$databaseName.$Environment.ConnectionMethod" `
      -CredentialsKeyDottedPath "$databaseName.$Environment.CredentialsKey" `
      -ApplicationNameDottedPath "$databaseName.$Environment.ApplicationName"

    $resolvedSqlConnection = $resolution.Connection
    $resolvedConnectionOwnedByFunction = -not [bool]$resolution.IsCallerOwned

    $resolvedConnectionStringBuilder = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new($resolvedSqlConnection.ConnectionString)
    $DatabaseHost = $resolvedSqlConnection.DataSource
    $SqlInstance = $resolvedSqlConnection.DataSource
    $useIntegratedSecurityForFlyway = [bool]($resolvedConnectionStringBuilder.IntegratedSecurity -or $IntegratedSecurity -or $UseTrustedConnection)

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
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Configuring dbatools to trust server certificates'
    Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -PassThru | Register-DbatoolsConfig
    Set-DbatoolsConfig -FullName sql.connection.encrypt -Value $false -PassThru | Register-DbatoolsConfig
  }

  process {
    try {

      # Change to Flyway directory
      $originalLocation = Get-Location
      # Any other paths paramters need to be adjusted
      #  absolute paths need no adjustments
      #  relative paths need to be adjusted to be relative to the FlywayBasePath, because
      #  that's where the Flyway command will be run from
      $DatabasePath = adjust-path $originalLocation, $FlywayBasePath, $DatabasePath
      $ProvisioningScriptsPath = adjust-path $originalLocation, $FlywayBasePath, $ProvisioningScriptsPath
      $flywaySharedSqlMigrationsPath = adjust-path $originalLocation, $FlywayBasePath, $flywaySharedSqlMigrationsPath
      $FlywayDataPath = adjust-path $originalLocation, $FlywayBasePath, $FlywayDataPath
      $FlywayTomlPath = adjust-path $originalLocation, $FlywayBasePath, $FlywayTomlPath

      $repoFlywayBasePath = Join-Path $repositoryRoot 'Database\Flyway'
      if ([string]::IsNullOrWhiteSpace($FlywayBasePath) -or -not (Test-Path -LiteralPath $FlywayBasePath -PathType Container)) {
        if (Test-Path -LiteralPath $repoFlywayBasePath -PathType Container) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "FlywayBasePath '$FlywayBasePath' is not valid. Falling back to '$repoFlywayBasePath'."
          $FlywayBasePath = $repoFlywayBasePath
        }
      }

      if ([string]::IsNullOrWhiteSpace($flywaySqlMigrationsPath) -or -not (Test-Path -LiteralPath $flywaySqlMigrationsPath -PathType Container)) {
        $candidateSqlMigrationsPath = Join-Path $FlywayBasePath 'SQL'
        if (Test-Path -LiteralPath $candidateSqlMigrationsPath -PathType Container) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "FlywaySqlMigrationsPath '$flywaySqlMigrationsPath' is not valid. Falling back to '$candidateSqlMigrationsPath'."
          $flywaySqlMigrationsPath = $candidateSqlMigrationsPath
        }
      }

      if ([string]::IsNullOrWhiteSpace($ProvisioningScriptsPath)) {
        $ProvisioningScriptsPath = Join-Path $repositoryRoot 'src\ATAP.Utilities.DatabaseManagement\SharedSQL'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "ProvisioningScriptsPath was empty; defaulting to '$ProvisioningScriptsPath'"
      }

      if ([string]::IsNullOrWhiteSpace($DatabasePath)) {
        $DatabasePath = Join-Path $env:LOCALAPPDATA ("ATAP.Utilities\\SQLData\\$Environment")
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "DatabasePath was empty; defaulting to '$DatabasePath'"
      }

      if ([string]::IsNullOrWhiteSpace($FlywayDataPath)) {
        $FlywayDataPath = Join-Path $FlywayBasePath 'Data'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "FlywayDataPath was empty; defaulting to '$FlywayDataPath'"
      }

      if (-not (Test-Path -LiteralPath $FlywayDataPath -PathType Container)) {
        $fallbackFlywayDataPath = Join-Path $FlywayBasePath 'Data'
        if ((-not [string]::IsNullOrWhiteSpace($fallbackFlywayDataPath)) -and (Test-Path -LiteralPath $fallbackFlywayDataPath -PathType Container)) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "FlywayDataPath '$FlywayDataPath' does not exist. Falling back to '$fallbackFlywayDataPath'."
          $FlywayDataPath = $fallbackFlywayDataPath
        }
      }

      if ([string]::IsNullOrWhiteSpace($FlywayTomlPath) -or -not (Test-Path -LiteralPath $FlywayTomlPath -PathType Leaf)) {
        $fallbackFlywayTomlPath = Join-Path $FlywayBasePath 'flyway.toml'
        if (Test-Path -LiteralPath $fallbackFlywayTomlPath -PathType Leaf) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "FlywayTomlPath '$FlywayTomlPath' is not valid. Falling back to '$fallbackFlywayTomlPath'."
          $FlywayTomlPath = $fallbackFlywayTomlPath
        }
      }

      $requiredProvisioningScripts = @(
        'DropAndCreateDatabase.sql',
        'CreateLoginAndUser.sql',
        'AddFlywaySchemaHistoryTable.sql'
      )
      $missingScripts = @($requiredProvisioningScripts | Where-Object {
          -not (Test-Path (Join-Path $ProvisioningScriptsPath $_))
        })
      if ($missingScripts.Count -gt 0) {
        $fallbackProvisioningScriptsPath = Join-Path $repositoryRoot 'src\ATAP.Utilities.DatabaseManagement\SharedSQL'
        if ($fallbackProvisioningScriptsPath -ne $ProvisioningScriptsPath) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "ProvisioningScriptsPath '$ProvisioningScriptsPath' is missing required scripts ($($missingScripts -join ', ')). Falling back to '$fallbackProvisioningScriptsPath'."
          $ProvisioningScriptsPath = $fallbackProvisioningScriptsPath
        }
      }

      Set-Location $FlywayBasePath

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Starting database provisioning...'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Target Server: $DatabaseHost"

      $sqlConnection = $resolvedSqlConnection
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Using SQL connection validated by Resolve-DatabaseSqlConnection'

      # Call DatabaseProvisioning with SQL connection object
      $provisioningParams = @{
        DatabaseName            = $DatabaseName
        SqlConnection           = $sqlConnection
        DatabasePath            = $DatabasePath
        ProvisioningScriptsPath = $ProvisioningScriptsPath
        Force                   = $Force
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Calling DatabaseProvisioning with SqlConnection object'

      if ($PSCmdlet.ShouldProcess($DatabaseName, 'Provision database')) {
        $provisioningResult = $null
        $provisioningResult = DatabaseProvisioning @provisioningParams

        # Check provisioning result before continuing to Flyway
        if (-not $provisioningResult -or -not $provisioningResult.Success) {
          $errorMessage = 'Database provisioning failed. Aborting before Flyway migrations.'
          if ($provisioningResult -and $provisioningResult.Errors) {
            $errorMessage += " Errors: $($provisioningResult.Errors -join '; ')"
          }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          $result.Errors += $errorMessage
          throw $errorMessage
        }

        if ($SkipFlyway) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Skipping Flyway migrations (-SkipFlyway set)'
        } else {
          # Run Flyway migrations
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Running Flyway migrations...'
          $FlywayParams = @{
            DatabaseName                  = $DatabaseName
            Environment                   = $Environment
            SqlConnection                 = $sqlConnection
            IntegratedSecurity            = $useIntegratedSecurityForFlyway
            FlywayCommand                 = 'migrate'
            FlywayBasePath                = $FlywayBasePath
            FlywaySqlMigrationsPath       = $flywaySqlMigrationsPath
            FlywaySharedSqlMigrationsPath = $flywaySharedSqlMigrationsPath
            FlywayDataPath                = $FlywayDataPath
            FlywayTomlPath                = $FlywayTomlPath
            PackageName                   = "$DatabaseName.Functions"
            PackageVersion                = 1
          }

          Invoke-Flyway @FlywayParams
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Database build completed successfully'
        $result.Success = $true
      }
    } catch {
      $errorMessage = "Database build failed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
      $result.Errors += $errorMessage
      $result.Success = $false
      throw
    } finally {
      # Restore original location
      if ($originalLocation) {
        Set-Location $originalLocation
      }
      if ($resolvedConnectionOwnedByFunction -and $resolvedSqlConnection) {
        if ($resolvedSqlConnection.State -eq [System.Data.ConnectionState]::Open) {
          $resolvedSqlConnection.Close()
        }
        $resolvedSqlConnection.Dispose()
      }
      $result.EndTime = Get-Date
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    return $result
  }
}

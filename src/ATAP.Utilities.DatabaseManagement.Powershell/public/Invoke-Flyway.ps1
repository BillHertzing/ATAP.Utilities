function Invoke-Flyway {
  <#
  .SYNOPSIS
  Builds a JDBC connection string from parameters, sets Flyway environment variables, and runs a Flyway command.

  .DESCRIPTION
  Uses New-ConnectionStringBuilderFromDbaTools with -AsJDBC to construct the Flyway JDBC URL from
  structured parameters (DatabaseHost, SqlInstance, etc.).

  Computes SHA256 hashes for specified migration/repeatable SQL files under -SqlMigrationsPath, builds a
  comma-separated (VALUES ...) list for insertion (ManifestValues), and exports these plus package /
  git metadata into environment variables using Flyway's placeholder naming convention
  (FLYWAY_PLACEHOLDERS_*). After exporting, it invokes 'flyway $FlywayCommand'.

  Uses parameter sets to determine authentication method:
  - IntegratedSecurity (default): Uses Windows Integrated Authentication
  - CredentialsFromVault: Retrieves credentials from vault using CredentialsKey

  Exported environment variables:
    FLYWAY_URL
    FLYWAY_ENCRYPT
    FLYWAY_TRUSTSERVERCERT
    FLYWAY_PLACEHOLDERS_MANIFESTVALUES
    FLYWAY_PLACEHOLDERS_PACKAGENAME
    FLYWAY_PLACEHOLDERS_PACKAGEVERSION
    FLYWAY_PLACEHOLDERS_GITTAG
    FLYWAY_PLACEHOLDERS_GITCOMMIT

  .PARAMETER DatabaseName
  The name of the database to migrate.

  .PARAMETER Environment
  The target environment: 'Development', 'Testing', 'Production', or 'Experimental'.
  This parameter drives the value of SqlInstance:
  - Development, Testing, Production: SqlInstance is set to match the Environment value
  - Experimental: SqlInstance is left blank (uses default instance)

  .PARAMETER DatabaseHost
  The SQL Server host. Can be overridden by vault secret if CredentialsKey returns a HostName. Alias: HostName

  .PARAMETER IntegratedSecurity
  Use Windows Integrated Authentication. Mandatory for the IntegratedSecurity parameter set.

  .PARAMETER CredentialsKey
  Key to retrieve credentials from vault. Mandatory for the CredentialsFromVault parameter set.
  The secret object may contain:
  - UserName (required): SQL or Windows login
  - Password (required): Login password
  - HostName (optional): Overrides DatabaseHost parameter
  - SqlInstance (optional): Named instance
  - Port (optional): Non-default port

    .PARAMETER FlywayExecutablePath
  Executable or path for the flyway CLI (default 'flyway').

  .PARAMETER FlywayCommand
  The Flyway command to run: validate, migrate, check, repair, info, baseline, clean, or undo.
  Defaults to 'validate'.

  .PARAMETER PackageName
  Logical package/component name.

  .PARAMETER PackageVersion
  Version string for the package.

  .PARAMETER FlywayTomlPath
  Path to flyway.toml (used for flyway -configFiles argument only; not parsed here).

  .PARAMETER SqlMigrationsPath
  Directory containing Flyway SQL scripts (default .\sql).

  .PARAMETER SqlInstance
  The SQL Server named instance.
  Typically derived from the Environment parameter.
  Can be explicitly specified to override the Environment-based value.

  .PARAMETER ConnectionMethod
  Protocol to use for connection: tcp, np (named pipes), lpc (shared memory), or default.

  .PARAMETER Files
  File names (relative to -SqlMigrationsPath) to include in the manifest values list.

  .PARAMETER GitTag
  Optional explicit Git tag (otherwise discovered from git).

  .PARAMETER GitCommit
  Optional explicit Git commit (otherwise discovered from git).

  .PARAMETER FlywayAdditionalArgs
  Additional raw arguments passed to flyway before the 'FlywayCommand' verb (e.g. '-X').

  .OUTPUTS
  PSCustomObject summarizing placeholders and flyway execution result.

  .EXAMPLE
  Invoke-Flyway -DatabaseName 'PCMSC' -Environment 'Experimental' -DatabaseHost 'localhost' -IntegratedSecurity -SqlMigrationsPath '.\sql' -FlywayTomlPath '.\flyway.toml' -FlywayCommand 'migrate' -PackageName 'PCMSC.Functions' -PackageVersion 1

  .EXAMPLE
  Invoke-Flyway -DatabaseName 'PCMSC' -Environment 'Development' -DatabaseHost 'utat022' -CredentialsKey 'PCMSC-Dev-Credential' -SqlMigrationsPath '.\sql' -FlywayTomlPath '.\flyway.toml' -FlywayCommand 'migrate' -PackageName 'PCMSC.Functions' -PackageVersion 1

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines
  Uses New-ConnectionStringBuilderFromDbaTools for JDBC connection string creation.
  Requires dbatools module for database operations.
  Requires Bitwarden CLI (bw) for vault authentication (CredentialsFromVault parameter set).
  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialsKey',
    Justification = 'CredentialsKey is a vault lookup key name, not a credential')]
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low', DefaultParameterSetName = 'ConnectionParameters')]
  param(
    # region Database connection parameters
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParameters')]
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ExistingConnection')]
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
    [ValidateNotNull()]
    [Microsoft.Data.SqlClient.SqlConnection]$SqlConnection,
    # endregion Database connection parameters

    # region Flyway parameters
    [Parameter(Mandatory = $false)]
    [string]$FlywayExecutablePath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('validate', 'migrate', 'check', 'repair', 'info', 'baseline', 'clean', 'undo')]
    [string]$FlywayCommand = 'validate',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$FlywayBasePath,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$flywaySqlMigrationsPath,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$flywaySharedSqlMigrationsPath,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$FlywayDataPath,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$FlywayTomlPath,

    [Parameter(Mandatory = $false)]
    [string[]]$FlywayAdditionalArgs,

    #endregion Flyway parameters

    # Optional metadata and execution tuning
    [Parameter(Mandatory = $false)]
    [string[]]$Files,

    [Parameter(Mandatory = $false)]
    [string]$GitTag,

    [Parameter(Mandatory = $false)]
    [string]$GitCommit,

    [Parameter(Mandatory = $false)]
    [string]$PackageName,

    [Parameter(Mandatory = $false)]
    [string]$PackageVersion

  )

  BEGIN {
    $fn = 'Invoke-Flyway'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Load required helper functions
    try {
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
      if (-not (Get-Command -Name 'New-ConnectionStringBuilderFromDbaTools' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\New-ConnectionStringBuilderFromDbaTools.ps1'
      }
    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

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
    # endregion Database connection parameters validation

    $usingExistingConnection = $PSCmdlet.ParameterSetName -eq 'ExistingConnection'

    if (-not $CredentialsKey -and -not $IntegratedSecurity) {
      $IntegratedSecurity = $true
    }

    if ($usingExistingConnection -and $SqlConnection) {
      $existingBuilder = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new($SqlConnection.ConnectionString)
      $dataSource = $existingBuilder.DataSource
      $dataSourceNoProto = if ($dataSource -match ':') { $dataSource.Split(':')[-1] } else { $dataSource }

      if (-not $DatabaseHost) {
        if ($dataSourceNoProto -match '\\') {
          $DatabaseHost = $dataSourceNoProto.Split('\\')[0]
          if (-not $SqlInstance -and $dataSourceNoProto.Split('\\').Count -gt 1) { $SqlInstance = $dataSourceNoProto.Split('\\')[1] }
        }
        elseif ($dataSourceNoProto -match ',') {
          $parts = $dataSourceNoProto.Split(',')
          $DatabaseHost = $parts[0]
          if (-not $Port -and $parts.Count -gt 1) { $Port = [int]$parts[1] }
        }
        else {
          $DatabaseHost = $dataSourceNoProto
        }
      }

      if (-not $SqlInstance -and $dataSourceNoProto -match '\\') {
        $SqlInstance = $dataSourceNoProto.Split('\\')[1]
      }

      if (-not $Port -and $dataSourceNoProto -match ',') {
        $Port = [int]$dataSourceNoProto.Split(',')[1]
      }

      if (-not $IntegratedSecurity) {
        $IntegratedSecurity = $existingBuilder.IntegratedSecurity
      }
    }
    $FlywayExecutablePath = Get-PVal -ParameterName "FlywayBasePath" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywayBasePath" -Settings $databasesCollection -DefaultValue $FlywayBasePath
    $FlywayBasePath = Get-PVal -ParameterName "FlywayBasePath" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywayBasePath" -Settings $databasesCollection -DefaultValue $FlywayBasePath
    $flywaySqlMigrationsPath = Get-PVal -ParameterName "SqlMigrationsPath" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.SqlMigrationsPath" -Settings $databasesCollection -DefaultValue $flywaySqlMigrationsPath
    $flywaySharedSqlMigrationsPath = Get-PVal -ParameterName "SharedSqlMigrationsPath" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.SharedSqlMigrationsPath" -Settings $databasesCollection -DefaultValue $flywaySharedSqlMigrationsPath
    $FlywayDataPath = Get-PVal -ParameterName "FlywayDataPath" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywayDataPath" -Settings $databasesCollection -DefaultValue $FlywayDataPath
    $FlywayTomlPath = Get-PVal -ParameterName "FlywayTomlPath" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywayTomlPath" -Settings $databasesCollection -DefaultValue $FlywayTomlPath
    $FlywayAdditionalArgs = Get-PVal -ParameterName "FlywayAdditionalArgs" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywayAdditionalArgs" -Settings $databasesCollection -DefaultValue $FlywayAdditionalArgs -AllowMissing
    $PackageName = Get-PVal -ParameterName "PackageName" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.PackageName" -Settings $databasesCollection -DefaultValue $PackageName -AllowMissing
    $PackageVersion = Get-PVal -ParameterName "PackageVersion" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.PackageVersion" -Settings $databasesCollection -DefaultValue $PackageVersion -AllowMissing

    $script:errors = [System.Collections.Generic.List[string]]::new()
    $script:success = $false


    # Git metadata
    function Get-GitMeta {
      param([string]$StartDir)
      $git = Get-Command git -ErrorAction SilentlyContinue
      if (-not $git) { return @{ Tag = '(no-git)'; Commit = '(no-git)' } }
      $tag = $null; try { $tag = (git -C $StartDir describe --tags --abbrev=0 2>$null).Trim() } catch {}
      if (-not $tag) { $tag = '(untagged)' }
      $commit = (git -C $StartDir rev-parse --short HEAD 2>$null).Trim(); if (-not $commit) { $commit = '(no-commit)' }
      @{ Tag = $tag; Commit = $commit }
    }

    try {
      $gitMeta = Get-GitMeta -StartDir (Resolve-Path .)
      if (-not $GitTag) { $GitTag = $gitMeta.Tag }
      if (-not $GitCommit) { $GitCommit = $gitMeta.Commit }
    }
    catch {
      $msg = "Failed obtaining git metadata. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message $msg
      $script:errors.Add($msg) | Out-Null
    }

    # Pre-compute manifest values list (used later as env var)
    $values = @()
    try {
      foreach ($name in $Files) {
        $full = Join-Path $flywaySqlMigrationsPath $name
        if (-not (Test-Path $full)) { throw "File not found: $full" }
        $sha = (Get-FileHash -Path $full -Algorithm SHA256).Hash.ToLower()
        $type = if ($name -like 'R__*') { 'R' } elseif ($name -like 'V*__*') { 'V' } else { 'R' }
        $fileNameSql = ($name -replace "'", "''")
        $values += "(N'$fileNameSql', '$type', N'$sha')"
      }
    }
    catch {
      $msg = "Failed hashing files. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      $script:errors.Add($msg) | Out-Null
      throw
    }
    $script:valuesList = ($values -join ',')

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'All parameters validated successfully'
  }

  PROCESS {
    try {
      $jdbcUrl = $null
      $dataSourceForLog = $DatabaseHost
      $useIntegratedSecurity = $false

      if ($usingExistingConnection) {
        $existingBuilder = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new($SqlConnection.ConnectionString)
        $dataSourceForLog = $existingBuilder.DataSource
        $serverSegment = $existingBuilder.DataSource
        if ($Port -and ($serverSegment -notmatch ',')) { $serverSegment = "$serverSegment,$Port" }

        $jdbcUrl = "jdbc:sqlserver://$serverSegment;databaseName=$DatabaseName;encrypt=false;trustServerCertificate=true"
        $useIntegratedSecurity = $existingBuilder.IntegratedSecurity -or $IntegratedSecurity
        if ($useIntegratedSecurity) {
          $jdbcUrl += ';integratedSecurity=true'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Using Windows Integrated Authentication (existing connection)'
        }
        else {
          $jdbcUrl += ";user=$($existingBuilder.UserID);password=$($existingBuilder.Password)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Using SQL authentication from existing connection'
        }
      }
      else {
        $connBuilderParams = @{
          DatabaseName = $DatabaseName
          AsJDBC       = $true
        }

        if (-not [string]::IsNullOrWhiteSpace($DatabaseHost)) { $connBuilderParams['DatabaseHost'] = $DatabaseHost }
        if (-not [string]::IsNullOrWhiteSpace($SqlInstance)) { $connBuilderParams['SqlInstance'] = $SqlInstance }
        if (-not [string]::IsNullOrWhiteSpace($ConnectionMethod) -and $ConnectionMethod -ne 'default') { $connBuilderParams['ConnectionMethod'] = $ConnectionMethod }
        if ($Port) { $connBuilderParams['Port'] = $Port }

        if ($CredentialsKey) {
          $connBuilderParams['CredentialsKey'] = $CredentialsKey
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Using vault credentials with key: $CredentialsKey"
        }
        else {
          $connBuilderParams['IntegratedSecurity'] = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Using Windows Integrated Authentication'
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Database: $DatabaseName"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "ConnectionMethod: $ConnectionMethod"

        $connectionStringBuilder = New-ConnectionStringBuilderFromDbaTools @connBuilderParams
        $jdbcUrl = $connectionStringBuilder.ToString()
        $dataSourceForLog = $connectionStringBuilder.DataSource
        $useIntegratedSecurity = $connectionStringBuilder.UseIntegratedSecurity
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'JDBC connection string built successfully'
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "DataSource: $dataSourceForLog"

      # Set Flyway environment variables

      # TLS defaults (adjust to policy)
      # ToDo: modify once trusted SSL certs are available
      $env:FLYWAY_ENCRYPT = 'false'
      $env:FLYWAY_TRUSTSERVERCERT = 'true'

      # Set FLYWAY_URL from the JDBC connection string
      $environmentKey = $Environment.ToLowerInvariant()
      $envPrefix = switch ($Environment) {
        'Production' { 'PROD' }
        'Testing' { 'TEST' }
        'Development' { 'DEV' }
        'Experimental' { 'EXP' }
      }

      # Set environment-specific URL that flyway.toml references
      [Environment]::SetEnvironmentVariable("FLYWAY_${envPrefix}_URL", $jdbcUrl, [EnvironmentVariableTarget]::Process)
      # Also set the generic FLYWAY_URL
      $env:FLYWAY_URL = $jdbcUrl

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Flyway URL: $($jdbcUrl -replace 'password=[^;]*', 'password=***')"

      # Configure authentication environment variables
      if ($useIntegratedSecurity) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Configuring Flyway for Windows Integrated Authentication'

        # Clear ALL Flyway user/password environment variables for all environments
        # This ensures Flyway doesn't try to use SQL authentication
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
            Remove-Item "Env:$envVar" -ErrorAction SilentlyContinue | Out-Null
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Removed environment variable: $envVar"
          }
        }
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Configuring Flyway for SQL Server Authentication'
        # Credentials are embedded in the JDBC URL by New-ConnectionStringBuilderFromDbaTools
        # No need to set separate FLYWAY_USER/FLYWAY_PASSWORD environment variables
      }

      # Export placeholder environment variables
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Exporting Flyway placeholder environment variables'
      $env:FLYWAY_PLACEHOLDERS_MANIFESTVALUES = $script:valuesList
      $env:FLYWAY_PLACEHOLDERS_PACKAGENAME = $PackageName
      $env:FLYWAY_PLACEHOLDERS_PACKAGEVERSION = $PackageVersion
      $env:FLYWAY_PLACEHOLDERS_GITTAG = $GitTag
      $env:FLYWAY_PLACEHOLDERS_GITCOMMIT = $GitCommit

      # Build flyway parameters and execute
      $flywayParams = @("-configFiles=$FlywayTomlPath", "-environment=$environmentKey")
      if ($FlywayAdditionalArgs) { $flywayParams += $FlywayAdditionalArgs }
      $flywayParams += $FlywayCommand

      if ($PSCmdlet.ShouldProcess($FlywayTomlPath, "flyway $FlywayCommand [$environmentKey]")) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Running flyway $FlywayCommand..."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling flyway with args: $($flywayParams -join ' ')"

        & $FlywayExecutablePath @flywayParams
        $exit = $LASTEXITCODE
        if ($exit -ne 0) { throw "flyway exited with code $exit" }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "flyway $FlywayCommand completed successfully"
        $script:success = $true
      }
    }
    catch {
      $errorMessage = "Invoke-Flyway failed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
      $script:errors.Add($errorMessage) | Out-Null
      throw
    }
  }

  END {
    # Build and return the summary object
    $summary = [PSCustomObject]@{
      PackageName    = $PackageName
      PackageVersion = $PackageVersion
      GitTag         = $GitTag
      GitCommit      = $GitCommit
      FileCount      = $Files.Count
      ManifestValues = $env:FLYWAY_PLACEHOLDERS_MANIFESTVALUES
      FlywayCommand  = $FlywayCommand
      FlywayUrl      = $env:FLYWAY_URL -replace 'password=[^;]*', 'password=***'
      Success        = ($script:errors.Count -eq 0 -and $script:success)
      Errors         = $script:errors.ToArray()
      TimestampUTC   = (Get-Date).ToUniversalTime()
    }
    $level = if ($summary.Success) { 'Important' } else { 'Error' }
    $statusText = if ($summary.Success) { 'succeeded' } else { 'failed' }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level $level -Message ("Invoke-Flyway {0}" -f $statusText)
    if (-not $summary.Success) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message ("Errors:`n" + ($summary.Errors -join [Environment]::NewLine)) }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function Invoke-Flyway'
    return $summary
  }
}

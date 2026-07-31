function Invoke-Flyway {
  <#
  .SYNOPSIS
  Builds a JDBC connection string from a validated SQL connection, sets Flyway environment variables, and runs a Flyway command.

  .DESCRIPTION
  Uses Resolve-DatabaseSqlConnection to validate SqlConnection, DBConnectionStringSecretName, or
  structured connection parts before deriving the Flyway JDBC URL.

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
  Uses Resolve-DatabaseSqlConnection for connection validation before JDBC URL creation.
  Requires dbatools module for database operations.
  Requires Bitwarden CLI (bw) for vault authentication (CredentialsFromVault parameter set).
  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialsKey',
    Justification = 'CredentialsKey is a vault lookup key name, not a credential')]
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low', DefaultParameterSetName = 'ConnectionParts')]
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

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [Alias('DBConnectionStringDatabaseSecretName', 'DBConnectionStringDatabaseSecret', 'DatabaseSecretName', 'DBSecretName')]
    [string]$DBConnectionStringDBSecretName,

    [Parameter(Mandatory = $false)]
    [hashtable]$Settings,
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
    [string]$FlywaySqlMigrationsPath,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$FlywaySharedSqlMigrationsPath,

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

  begin {
    $fn = 'Invoke-Flyway'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    function Get-FlywayJavaMajorVersion {
      param(
        [Parameter(Mandatory = $true)]
        [string]$JavaExecutablePath
      )

      try {
        $versionOutput = @(& $JavaExecutablePath -version 2>&1)
      } catch {
        return $null
      }

      $versionText = ($versionOutput -join [Environment]::NewLine)
      if ($versionText -match 'version "1\.(\d+)\.') {
        return [int]$Matches[1]
      }
      if ($versionText -match 'version "(\d+)(?:\.|")') {
        return [int]$Matches[1]
      }
      if ($versionText -match 'openjdk (\d+)(?:\.|")') {
        return [int]$Matches[1]
      }

      return $null
    }

    function Use-FlywayCompatibleJavaRuntime {
      $minimumJavaMajorVersion = 17
      $currentJavaMajorVersion = Get-FlywayJavaMajorVersion -JavaExecutablePath 'java'
      if ($currentJavaMajorVersion -ge $minimumJavaMajorVersion) {
        return
      }

      $candidateRoots = [System.Collections.Generic.List[string]]::new()
      if (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
        $candidateRoots.Add($env:JAVA_HOME)
      }

      foreach ($root in @(
          'C:\Program Files\Eclipse Adoptium',
          'C:\Program Files\Java',
          'C:\Program Files\Microsoft',
          'C:\Program Files\Zulu'
        )) {
        if (Test-Path -LiteralPath $root -PathType Container) {
          Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { $candidateRoots.Add($_.FullName) }
        }
      }

      $compatibleCandidates = @(
        $candidateRoots |
          Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
          Select-Object -Unique |
          ForEach-Object {
            $candidateJava = Join-Path $_ 'bin\java.exe'
            if (Test-Path -LiteralPath $candidateJava -PathType Leaf) {
              $majorVersion = Get-FlywayJavaMajorVersion -JavaExecutablePath $candidateJava
              if ($majorVersion -ge $minimumJavaMajorVersion) {
                [PSCustomObject]@{
                  Root         = $_
                  JavaPath     = $candidateJava
                  MajorVersion = $majorVersion
                }
              }
            }
          } |
          Sort-Object -Property MajorVersion -Descending
      )

      $selectedCandidate = $compatibleCandidates | Select-Object -First 1
      if ($null -eq $selectedCandidate) {
        throw "Flyway requires Java $minimumJavaMajorVersion or newer. Current java major version is '$currentJavaMajorVersion', and no compatible installed runtime was found."
      }

      $env:JAVA_HOME = $selectedCandidate.Root
      $env:PATH = (Join-Path $selectedCandidate.Root 'bin') + [System.IO.Path]::PathSeparator + $env:PATH
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Using Java $($selectedCandidate.MajorVersion) runtime for Flyway: $($selectedCandidate.Root)"
    }

    # Load required helper functions
    try {
      if (-not (Get-Command -Name 'Resolve-DatabaseSqlConnection' -CommandType Function -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'Resolve-DatabaseSqlConnection.ps1')
      }
    } catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    $databasesCollection = if ($Settings) {
      $Settings
    }
    elseif ($global:settings -and $global:configRootKeys -and $global:configRootKeys['DatabasesCollectionConfigRootKey']) {
      $global:settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]
    }
    elseif ($global:settings -is [System.Collections.IDictionary] -and $global:settings.Contains('DatabasesCollection')) {
      $global:settings['DatabasesCollection']
    }
    elseif ($global:settings -and $global:settings.PSObject.Properties['DatabasesCollection']) {
      $global:settings.DatabasesCollection
    }
    else {
      $null
    }

    $DatabaseName = Get-PVal -ParameterName 'DatabaseName' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.DatabaseName" -Settings $databasesCollection -DefaultValue $DatabaseName
    $Environment = Get-PVal -ParameterName 'Environment' -originalPSBoundParameters $PSBoundParameters -DefaultValue $Environment -ValidValues @('Production', 'Testing', 'Development', 'Experimental') -AllowMissing
    $DBConnectionStringSecretName = Get-PVal -ParameterName 'DBConnectionStringSecretName' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.DBConnectionStringSecretName" -Settings $databasesCollection -DefaultValue $DBConnectionStringSecretName -AllowMissing
    $DBConnectionStringDBSecretName = Get-PVal -ParameterName 'DBConnectionStringDBSecretName' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.DBConnectionStringDBSecretName" -Settings $databasesCollection -DefaultValue $DBConnectionStringDBSecretName -AllowMissing
    if ([string]::IsNullOrWhiteSpace($DBConnectionStringDBSecretName)) {
      $DBConnectionStringDBSecretName = $DBConnectionStringSecretName
    }

    $resolution = Resolve-DatabaseSqlConnection `
      -OriginalPSBoundParameters $PSBoundParameters `
      -SqlConnection $SqlConnection `
      -DBConnectionStringSecretName $DBConnectionStringSecretName `
      -DBConnectionStringDBSecretName $DBConnectionStringDBSecretName `
      -DatabaseHost $DatabaseHost `
      -InstanceName $SqlInstance `
      -DatabaseName $DatabaseName `
      -ConnectionMethod $ConnectionMethod `
      -CredentialsKey $CredentialsKey `
      -ApplicationName $ApplicationName `
      -UseTrustedConnection:$UseTrustedConnection `
      -IntegratedSecurity:$IntegratedSecurity `
      -Settings $databasesCollection `
      -DatabaseHostDottedPath "$databaseName.$Environment.DatabaseHost" `
      -DBConnectionStringSecretNameDottedPath "$databaseName.$Environment.DBConnectionStringSecretName" `
      -DBConnectionStringDBSecretNameDottedPath "$databaseName.$Environment.DBConnectionStringDBSecretName" `
      -InstanceNameDottedPath "$databaseName.$Environment.SqlInstance" `
      -ConnectionMethodDottedPath "$databaseName.$Environment.ConnectionMethod" `
      -CredentialsKeyDottedPath "$databaseName.$Environment.CredentialsKey" `
      -ApplicationNameDottedPath "$databaseName.$Environment.ApplicationName"

    $resolvedSqlConnection = $resolution.Connection
    $resolvedConnectionOwnedByFunction = -not [bool]$resolution.IsCallerOwned

    $resolvedConnectionStringBuilder = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new($resolvedSqlConnection.ConnectionString)
    $DatabaseHost = $resolvedSqlConnection.DataSource
    $FlywayExecutablePath = Get-PVal -ParameterName 'FlywayExecutablePath' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywayExecutablePath" -Settings $databasesCollection -DefaultValue $(if ($FlywayExecutablePath) { $FlywayExecutablePath } else { 'flyway' })
    $FlywayBasePath = Get-PVal -ParameterName 'FlywayBasePath' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywayBasePath" -Settings $databasesCollection -DefaultValue $FlywayBasePath
    $FlywaySqlMigrationsPath = Get-PVal -ParameterName 'FlywaySqlMigrationsPath' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywaySqlMigrationsPath" -Settings $databasesCollection -DefaultValue $FlywaySqlMigrationsPath
    $FlywaySharedSqlMigrationsPath = Get-PVal -ParameterName 'FlywaySharedSqlMigrationsPath' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.SharedSqlMigrationsPath" -Settings $databasesCollection -DefaultValue $FlywaySharedSqlMigrationsPath
    $FlywayDataPath = Get-PVal -ParameterName 'FlywayDataPath' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywayDataPath" -Settings $databasesCollection -DefaultValue $FlywayDataPath
    $FlywayTomlPath = Get-PVal -ParameterName 'FlywayTomlPath' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywayTomlPath" -Settings $databasesCollection -DefaultValue $FlywayTomlPath
    $FlywayAdditionalArgs = Get-PVal -ParameterName 'FlywayAdditionalArgs' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.FlywayAdditionalArgs" -Settings $databasesCollection -DefaultValue $FlywayAdditionalArgs -AllowMissing
    $PackageName = Get-PVal -ParameterName 'PackageName' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.PackageName" -Settings $databasesCollection -DefaultValue $PackageName -AllowMissing
    $PackageVersion = Get-PVal -ParameterName 'PackageVersion' -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.PackageVersion" -Settings $databasesCollection -DefaultValue $PackageVersion -AllowMissing

    $script:errors = [System.Collections.Generic.List[string]]::new()
    $script:success = $false

    $repoRootFromScript = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $repoFlywayBasePath = Join-Path $repoRootFromScript 'Database\Flyway'

    if ([string]::IsNullOrWhiteSpace($FlywayBasePath) -or -not (Test-Path -LiteralPath $FlywayBasePath -PathType Container)) {
      if (Test-Path -LiteralPath $repoFlywayBasePath -PathType Container) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "FlywayBasePath '$FlywayBasePath' is not valid. Falling back to '$repoFlywayBasePath'."
        $FlywayBasePath = $repoFlywayBasePath
      }
    }

    if ([string]::IsNullOrWhiteSpace($FlywaySqlMigrationsPath) -or -not (Test-Path -LiteralPath $FlywaySqlMigrationsPath -PathType Container)) {
      $candidateSqlMigrationsPath = Join-Path $FlywayBasePath 'SQL'
      if (Test-Path -LiteralPath $candidateSqlMigrationsPath -PathType Container) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "FlywaySqlMigrationsPath '$FlywaySqlMigrationsPath' is not valid. Falling back to '$candidateSqlMigrationsPath'."
        $FlywaySqlMigrationsPath = $candidateSqlMigrationsPath
      }
    }

    if ([string]::IsNullOrWhiteSpace($FlywayTomlPath) -or -not (Test-Path -LiteralPath $FlywayTomlPath -PathType Leaf)) {
      $fallbackFlywayTomlPath = Join-Path $FlywayBasePath 'flyway.toml'
      if (Test-Path -LiteralPath $fallbackFlywayTomlPath -PathType Leaf) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "FlywayTomlPath '$FlywayTomlPath' is not valid. Falling back to '$fallbackFlywayTomlPath'."
        $FlywayTomlPath = $fallbackFlywayTomlPath
      }
    }

    if ([string]::IsNullOrWhiteSpace($FlywayDataPath)) {
      $FlywayDataPath = Join-Path $FlywayBasePath 'Data'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "FlywayDataPath was empty; defaulting to '$FlywayDataPath'"
    }

    if (-not (Test-Path -LiteralPath $FlywayDataPath -PathType Container)) {
      $fallbackFlywayDataPath = Join-Path $FlywayBasePath 'Data'
      if ((-not [string]::IsNullOrWhiteSpace($fallbackFlywayDataPath)) -and (Test-Path -LiteralPath $fallbackFlywayDataPath -PathType Container)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Configured FlywayDataPath '$FlywayDataPath' was not found. Falling back to '$fallbackFlywayDataPath'."
        $FlywayDataPath = $fallbackFlywayDataPath
      }
    }

    if (-not (Test-Path -LiteralPath $FlywayDataPath -PathType Container)) {
      throw "FlywayDataPath does not exist: '$FlywayDataPath'"
    }


    # Git metadata
    function Get-GitMeta {
      param([string]$StartDir)
      $git = Get-Command git -ErrorAction SilentlyContinue
      if (-not $git) { return @{ Tag = '(no-git)'; Commit = '(no-git)' } }
      $tag = $null; try { $tag = (git -C $StartDir describe --tags --abbrev=0 2>$null).Trim() } catch { $null = $_ }
      if (-not $tag) { $tag = '(untagged)' }
      $commit = (git -C $StartDir rev-parse --short HEAD 2>$null).Trim(); if (-not $commit) { $commit = '(no-commit)' }
      @{ Tag = $tag; Commit = $commit }
    }

    try {
      $gitMeta = Get-GitMeta -StartDir (Resolve-Path .)
      if (-not $GitTag) { $GitTag = $gitMeta.Tag }
      if (-not $GitCommit) { $GitCommit = $gitMeta.Commit }
    } catch {
      $msg = "Failed obtaining git metadata. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message $msg
      $script:errors.Add($msg) | Out-Null
    }

    # Pre-compute manifest values list (used later as env var)
    $values = @()
    try {
      foreach ($name in $Files) {
        $full = Join-Path $FlywaySqlMigrationsPath $name
        if (-not (Test-Path $full)) { throw "File not found: $full" }
        $sha = (Get-FileHash -Path $full -Algorithm SHA256).Hash.ToLower()
        $type = if ($name -like 'R__*') { 'R' } elseif ($name -like 'V*__*') { 'V' } else { 'R' }
        $fileNameSql = ($name -replace "'", "''")
        $values += "(N'$fileNameSql', '$type', N'$sha')"
      }
    } catch {
      $msg = "Failed hashing files. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      $script:errors.Add($msg) | Out-Null
      throw
    }
    $script:valuesList = ($values -join ',')

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'All parameters validated successfully'
  }

  process {
    try {
      $jdbcUrl = $null
      $dataSourceForLog = $DatabaseHost
      $useIntegratedSecurity = $false

      $dataSourceForLog = $resolvedConnectionStringBuilder.DataSource
      $serverSegment = $resolvedConnectionStringBuilder.DataSource
      if ($Port -and ($serverSegment -notmatch ',')) { $serverSegment = "$serverSegment,$Port" }

      $jdbcUrl = "jdbc:sqlserver://$serverSegment;databaseName=$DatabaseName;encrypt=false;trustServerCertificate=true"
      $useIntegratedSecurity = $resolvedConnectionStringBuilder.IntegratedSecurity -or $IntegratedSecurity -or $UseTrustedConnection
      if ($useIntegratedSecurity) {
        $jdbcUrl += ';integratedSecurity=true'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Using Windows Integrated Authentication'
      } else {
        $jdbcUrl += ";user=$($resolvedConnectionStringBuilder.UserID);password=$($resolvedConnectionStringBuilder.Password)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Using SQL authentication from resolved connection'
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Database: $DatabaseName"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'JDBC connection string built from validated SqlConnection'

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
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Configuring Flyway for SQL Server Authentication'
        # Credentials are embedded in the JDBC URL derived from the validated connection string.
        # No need to set separate FLYWAY_USER/FLYWAY_PASSWORD environment variables
      }

      # Export placeholder environment variables
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Exporting Flyway placeholder environment variables'
      $env:FLYWAY_PLACEHOLDERS_MANIFESTVALUES = $script:valuesList
      $env:FLYWAY_PLACEHOLDERS_PACKAGENAME = $PackageName
      $env:FLYWAY_PLACEHOLDERS_PACKAGEVERSION = $PackageVersion
      $env:FLYWAY_PLACEHOLDERS_GITTAG = $GitTag
      $env:FLYWAY_PLACEHOLDERS_GITCOMMIT = $GitCommit
      $env:FLYWAY_PLACEHOLDERS_DATA_DIR = $FlywayDataPath
      $userPiiPassphrase = $env:AceCommander_UserPii__PassphraseV1
      if ([string]::IsNullOrWhiteSpace($userPiiPassphrase)) {
        $userPiiPassphrase = [System.Environment]::GetEnvironmentVariable('AceCommander_UserPii__PassphraseV1', 'User')
      }
      if ([string]::IsNullOrWhiteSpace($userPiiPassphrase)) {
        $userPiiPassphrase = $env:UserPii__PassphraseV1
      }
      if ([string]::IsNullOrWhiteSpace($userPiiPassphrase)) {
        $userPiiPassphrase = [System.Environment]::GetEnvironmentVariable('UserPii__PassphraseV1', 'User')
      }
      if (-not [string]::IsNullOrWhiteSpace($userPiiPassphrase)) {
        $env:FLYWAY_PLACEHOLDERS_USER_PII_PASSPHRASE = $userPiiPassphrase
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Flyway data directory: $FlywayDataPath"

      # Build flyway parameters and execute
      $flywayParams = @("-configFiles=$FlywayTomlPath", "-environment=$environmentKey", '-X')
      if ($FlywayAdditionalArgs) { $flywayParams += $FlywayAdditionalArgs }
      $flywayParams += $FlywayCommand

      if ($PSCmdlet.ShouldProcess($FlywayTomlPath, "flyway $FlywayCommand [$environmentKey]")) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Running flyway $FlywayCommand..."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling flyway with args: $($flywayParams -join ' ')"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Changing to FlywayBasePath: $FlywayBasePath"
        Use-FlywayCompatibleJavaRuntime

        if (-not (Test-Path -LiteralPath $FlywayBasePath -PathType Container)) {
          throw "FlywayBasePath does not exist: '$FlywayBasePath'"
        }
        Push-Location $FlywayBasePath -ErrorAction Stop
        try {
          & $FlywayExecutablePath @flywayParams
          $exit = $LASTEXITCODE
          if ($exit -ne 0) { throw "flyway exited with code $exit" }
        } finally {
          Pop-Location
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "flyway $FlywayCommand completed successfully"
        $script:success = $true
      }
    } catch {
      $errorMessage = "Invoke-Flyway failed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
      $script:errors.Add($errorMessage) | Out-Null
      throw
    }
  }

  end {
    # Build and return the summary object
    $summary = [PSCustomObject]@{
      PackageName    = $PackageName
      PackageVersion = $PackageVersion
      GitTag         = $GitTag
      GitCommit      = $GitCommit
      FileCount      = @($Files).Count
      ManifestValues = $env:FLYWAY_PLACEHOLDERS_MANIFESTVALUES
      FlywayCommand  = $FlywayCommand
      FlywayUrl      = $env:FLYWAY_URL -replace 'password=[^;]*', 'password=***'
      Success        = ($script:errors.Count -eq 0 -and $script:success)
      Errors         = $script:errors.ToArray()
      TimestampUTC   = (Get-Date).ToUniversalTime()
    }
    $level = if ($summary.Success) { 'Important' } else { 'Error' }
    $statusText = if ($summary.Success) { 'succeeded' } else { 'failed' }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level $level -Message ('Invoke-Flyway {0}' -f $statusText)
    if (-not $summary.Success) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message ("Errors:`n" + ($summary.Errors -join [Environment]::NewLine)) }
    if ($resolvedConnectionOwnedByFunction -and $resolvedSqlConnection) {
      if ($resolvedSqlConnection.State -eq [System.Data.ConnectionState]::Open) {
        $resolvedSqlConnection.Close()
      }
      $resolvedSqlConnection.Dispose()
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function Invoke-Flyway'
    return $summary
  }
}

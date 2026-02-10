function Invoke-Flyway {
  <#
  .SYNOPSIS
  Builds a JDBC connection string from parameters, sets Flyway environment variables, and runs a Flyway command.

  .DESCRIPTION
  Uses New-ConnectionStringBuilderFromDbaTools with -AsJDBC to construct the Flyway JDBC URL from
  structured parameters (DatabaseHost, SqlInstance, etc.) rather than parsing pre-built JDBC strings.

  Computes SHA256 hashes for specified migration/repeatable SQL files under -SqlDir, builds a
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

  .PARAMETER DatabaseHost
  The SQL Server host. Can be overridden by vault secret if CredentialsKey returns a HostName. Alias: HostName

  .PARAMETER Environment
  The target environment: 'Development', 'Testing', 'Production', or 'Experimental'.
  This parameter drives the value of SqlInstance:
  - Development, Testing, Production: SqlInstance is set to match the Environment value
  - Experimental: SqlInstance is left blank (uses default instance)

  .PARAMETER SqlInstance
  The SQL Server named instance.
  Typically derived from the Environment parameter.
  Can be explicitly specified to override the Environment-based value.

  .PARAMETER DatabaseName
  The name of the database to migrate.

  .PARAMETER ConnectionMethod
  Protocol to use for connection: tcp, np (named pipes), lpc (shared memory), or default.

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

  .PARAMETER FlywayCommand
  The Flyway command to run: validate, migrate, check, repair, info, baseline, clean, or undo.
  Defaults to 'validate'.

  .PARAMETER SqlDir
  Directory containing Flyway SQL scripts (default .\sql).

  .PARAMETER Files
  File names (relative to -SqlDir) to include in the manifest values list.

  .PARAMETER PackageName
  Logical package/component name.

  .PARAMETER PackageVersion
  Version string for the package.

  .PARAMETER ConfigPath
  Path to flyway.toml (used for flyway -configFiles argument only; not parsed here).

  .PARAMETER GitTag
  Optional explicit Git tag (otherwise discovered from git).

  .PARAMETER GitCommit
  Optional explicit Git commit (otherwise discovered from git).

  .PARAMETER FlywayPath
  Executable or path for the flyway CLI (default 'flyway').

  .PARAMETER FlywayAdditionalArgs
  Additional raw arguments passed to flyway before the 'FlywayCommand' verb (e.g. '-X').

  .OUTPUTS
  PSCustomObject summarizing placeholders and flyway execution result.

  .EXAMPLE
  Invoke-Flyway -DatabaseHost 'localhost' -Environment 'Experimental' -DatabaseName 'PCMSC' -IntegratedSecurity -FlywayCommand 'migrate' -PackageName 'PCMSC.Functions' -PackageVersion 1

  .EXAMPLE
  Invoke-Flyway -DatabaseHost 'utat022' -Environment 'Development' -DatabaseName 'PCMSC' -CredentialsKey 'PCMSC-Dev-Credential' -FlywayCommand 'migrate' -PackageName 'PCMSC.Functions' -PackageVersion 1

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines
  Uses New-ConnectionStringBuilderFromDbaTools for JDBC connection string creation.
  Requires dbatools module for database operations.
  Requires Bitwarden CLI (bw) for vault authentication (CredentialsFromVault parameter set).
  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialsKey',
    Justification = 'CredentialsKey is a vault lookup key name, not a credential')]
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low', DefaultParameterSetName = 'IntegratedSecurity')]
  param(
    [Parameter(Mandatory = $false, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [Alias('HostName')]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [string]$Environment,

    [Parameter(Mandatory = $false, Position = 2, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, Position = 2, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false, Position = 3, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
    [Parameter(Mandatory = $false, Position = 3, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName,

    [Parameter(Mandatory = $false, Position = 4, ValueFromPipelineByPropertyName = $true)]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $true, ParameterSetName = 'IntegratedSecurity')]
    [switch]$IntegratedSecurity,

    [Parameter(Mandatory = $true, ParameterSetName = 'CredentialsFromVault')]
    [string]$CredentialsKey,

    # Flyway command selector
    [Parameter(Mandatory = $false)]
    [ValidateSet('validate', 'migrate', 'check', 'repair', 'info', 'baseline', 'clean', 'undo')]
    [string]$FlywayCommand = 'validate',

    [Parameter(Mandatory = $false)]
    [string]$SqlDir = '.\sql',

    [Parameter(Mandatory = $false)]
    [string[]]$Files,

    [Parameter(Mandatory = $false)]
    [string]$PackageName,

    [Parameter(Mandatory = $false)]
    [string]$PackageVersion,

    [string]$ConfigPath = '.\flyway.toml',
    [string]$GitTag,
    [string]$GitCommit,
    [string]$FlywayPath = 'flyway',
    [string[]]$FlywayAdditionalArgs
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

    $script:errors = [System.Collections.Generic.List[string]]::new()
    $script:success = $false

    # Parameter validation using Get-PVal pattern (per Powershell.instructions.md)

    # Check and populate Environment parameter
    $Environment = Get-PVal -ParameterName 'Environment' -originalPSBoundParameters $PSBoundParameters -DefaultValue 'Experimental' -AllowMissing:$true -ValidValues @('Development', 'Testing', 'Production', 'Experimental')
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Environment: $Environment"

    # Check and populate DatabaseHost parameter
    $databasesCollection = $global:settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]
    $DatabaseHost = Get-PVal -ParameterName 'DatabaseHost' -originalPSBoundParameters $PSBoundParameters -dottedPath "$DatabaseName.$Environment.DatabaseHost" -Settings $databasesCollection -DefaultValue $DatabaseHost -AllowMissing:$true
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "DatabaseHost: $DatabaseHost"

    # Check and populate SqlInstance parameter
    # Per Database Design: SqlInstance matches Environment, except 'Experimental' uses default instance (blank)
    $sqlInstanceDefault = if ($Environment -eq 'Experimental') { $null } else { $Environment }
    $SqlInstance = Get-PVal -ParameterName 'SqlInstance' -originalPSBoundParameters $PSBoundParameters -dottedPath "$DatabaseName.$Environment.SqlInstance" -Settings $databasesCollection -DefaultValue $sqlInstanceDefault -AllowMissing:$true
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "SqlInstance: $SqlInstance"

    # Check and populate DatabaseName parameter
    $DatabaseName = Get-PVal -ParameterName 'DatabaseName' -originalPSBoundParameters $PSBoundParameters -dottedPath "$DatabaseName.DatabaseName" -DefaultValue $DatabaseName -AllowMissing:$true
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "DatabaseName: $DatabaseName"

    # Check and populate ConnectionMethod parameter
    $ConnectionMethod = Get-PVal -ParameterName 'ConnectionMethod' -originalPSBoundParameters $PSBoundParameters -dottedPath "$DatabaseName.$Environment.ConnectionMethod" -Settings $databasesCollection -DefaultValue 'default' -AllowMissing:$true -ValidValues @('tcp', 'np', 'lpc', 'default')
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "ConnectionMethod: $ConnectionMethod"

    # Check and populate CredentialsKey parameter (only for CredentialsFromVault parameter set)
    if ($PSCmdlet.ParameterSetName -eq 'CredentialsFromVault') {
      $CredentialsKey = Get-PVal -ParameterName 'CredentialsKey' -originalPSBoundParameters $PSBoundParameters -dottedPath "$DatabaseName.$Environment.CredentialsKey" -Settings $databasesCollection -DefaultValue $CredentialsKey -AllowMissing:$false
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "CredentialsKey: $CredentialsKey"
    }

    # Validate ConfigPath
    try {
      if ([string]::IsNullOrWhiteSpace($ConfigPath)) { throw 'ConfigPath is null or empty.' }
      if (-not (Test-Path -Path $ConfigPath)) { throw "ConfigPath not found: $ConfigPath" }
    }
    catch {
      $msg = "ConfigPath validation failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Validation', 'Error'
      $script:errors.Add($msg) | Out-Null; throw
    }

    # Validate PackageName
    try {
      if ([string]::IsNullOrWhiteSpace($PackageName)) { throw 'PackageName is null or empty.' }
    }
    catch {
      $msg = "PackageName validation failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Validation', 'Error'
      $script:errors.Add($msg) | Out-Null; throw
    }

    # Validate PackageVersion
    try {
      if ([string]::IsNullOrWhiteSpace($PackageVersion)) { throw 'PackageVersion is null or empty.' }
    }
    catch {
      $msg = "PackageVersion validation failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Validation', 'Error'
      $script:errors.Add($msg) | Out-Null; throw
    }

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
        $full = Join-Path $SqlDir $name
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
      # Build connection string using New-ConnectionStringBuilderFromDbaTools with -AsJDBC
      $connBuilderParams = @{
        DatabaseName = $DatabaseName
        AsJDBC       = $true
      }

      # Add DatabaseHost if specified
      if (-not [string]::IsNullOrWhiteSpace($DatabaseHost)) {
        $connBuilderParams['DatabaseHost'] = $DatabaseHost
      }

      # Add SqlInstance if specified
      if (-not [string]::IsNullOrWhiteSpace($SqlInstance)) {
        $connBuilderParams['SqlInstance'] = $SqlInstance
      }

      # Add ConnectionMethod if not default
      if (-not [string]::IsNullOrWhiteSpace($ConnectionMethod) -and $ConnectionMethod -ne 'default') {
        $connBuilderParams['ConnectionMethod'] = $ConnectionMethod
      }

      # Set authentication method based on parameter set
      if ($PSCmdlet.ParameterSetName -eq 'IntegratedSecurity') {
        $connBuilderParams['IntegratedSecurity'] = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Using Windows Integrated Authentication'
      }
      else {
        $connBuilderParams['CredentialsKey'] = $CredentialsKey
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Using vault credentials with key: $CredentialsKey"
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Database: $DatabaseName"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "ConnectionMethod: $ConnectionMethod"

      # Create the connection string builder - ToString() returns the JDBC URL
      $connectionStringBuilder = New-ConnectionStringBuilderFromDbaTools @connBuilderParams

      # Get the JDBC connection string by calling ToString()
      $jdbcUrl = $connectionStringBuilder.ToString()

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "DataSource: $($connectionStringBuilder.DataSource)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'JDBC connection string built successfully'

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
      if ($PSCmdlet.ParameterSetName -eq 'IntegratedSecurity') {
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
      $flywayParams = @("-configFiles=$ConfigPath", "-environment=$environmentKey")
      if ($FlywayAdditionalArgs) { $flywayParams += $FlywayAdditionalArgs }
      $flywayParams += $FlywayCommand

      if ($PSCmdlet.ShouldProcess($ConfigPath, "flyway $FlywayCommand [$environmentKey]")) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Running flyway $FlywayCommand..."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling flyway with args: $($flywayParams -join ' ')"

        & $FlywayPath @flywayParams
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

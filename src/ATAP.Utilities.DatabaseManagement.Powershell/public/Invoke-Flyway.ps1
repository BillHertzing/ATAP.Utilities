function Invoke-Flyway {
  <#
  .SYNOPSIS
  Generates Flyway manifest placeholder environment variables, then runs flyway $FlywayCommand.

  .DESCRIPTION
  Computes SHA256 hashes for specified migration/repeatable SQL files under -SqlDir, builds a comma‑separated
  (VALUES …) list for insertion (ManifestValues), and exports these plus package / git metadata into environment
  variables using Flyway's placeholder naming convention (FLYWAY_PLACEHOLDERS_*). After exporting, it invokes
  'flyway $FlywayCommand'

  Exported environment variables:
    FLYWAY_PLACEHOLDERS_MANIFESTVALUES
    FLYWAY_PLACEHOLDERS_PACKAGENAME
    FLYWAY_PLACEHOLDERS_PACKAGEVERSION
    FLYWAY_PLACEHOLDERS_GITTAG
    FLYWAY_PLACEHOLDERS_GITCOMMIT
    FLYWAY_PROD_BUILDSETS_USER
    FLYWAY_PROD_BUILDSETS_PWD

  .PARAMETER SqlDir
  Directory containing Flyway SQL scripts (default .\sql).

  .PARAMETER Files
  File names (relative to -SqlDir) to include in the manifest values list.

  .PARAMETER LoginName
  The SQL/Login name to create or ensure (passed to the CreateBuildSetsLoginAndUser.sql script via sqlcmd variables).

  .PARAMETER LoginPasswordEnvVar
  Name of the environment variable holding the password for the login. Its value is injected via the sqlcmd variable $(BuildSetsloginPassword).

  .PARAMETER PackageName
  Logical package/component name.

  .PARAMETER PackageVersion
  Version string for the package.

  .PARAMETER ConfigPath
  Path to flyway.conf (used for flyway -configFiles argument only; not parsed here).

  .PARAMETER GitTag
  Optional explicit Git tag (otherwise discovered).

  .PARAMETER GitCommit
  Optional explicit Git commit (otherwise discovered).

  .PARAMETER FlywayPath
  Executable or path for the flyway CLI (default 'flyway').

  .PARAMETER FlywayAdditionalArgs
  Additional raw arguments passed to flyway before the 'FlywayCommand' verb (e.g. '-X').

  .OUTPUTS
  PSCustomObject summarizing placeholders and (optionally) flyway execution result.

  .EXAMPLE
  Invoke-Flyway -PackageName BuildSets.Functions -PackageVersion 0.0.00008 -Files (Get-ChildItem .\sql -Filter 'V*__*.sql').Name

  .EXAMPLE
  Invoke-Flyway -PackageName BuildSets.Functions -PackageVersion 0.0.00008 -Files V00.01.000010__Init.sql

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName,

    [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('Production', 'Testing', 'Development', 'Experimental')]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $false)]
    [ValidateSet('tcp', 'np', 'lpc')]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Production', 'Testing', 'Development', 'SQLEXPRESS')]
    [string]$SqlInstance,

    [Parameter(Mandatory = $false)]
    [bool]$UseNamedLogin = $false,

    [Parameter(Mandatory = $false)]
    [string]$LoginName ,

    [Parameter(Mandatory = $false)]
    #[Securestring]$LoginPasswordVaultKey,
    [string]$LoginPasswordVaultKey,

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

    # Try-Catch-Finally snippet for loading Get-ParameterValueFromNeoConfigurationRoot function
    try {
      # ToDo: Remove this when packaging works
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
    }
    catch {
      $errorMessage = "Failed to load Get-ParameterValueFromNeoConfigurationRoot function. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    # Try-Catch-Finally snippet for loading Resolve-ParameterValueToList function
    try {
      # ToDo: Remove this when packaging works
      if (-not (Get-Command -Name 'Resolve-ParameterValueToList' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Resolve-ParameterValueToList.ps1'
      }
    }
    catch {
      $errorMessage = "Failed to load Resolve-ParameterValueToList function. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    # Try-Catch-Finally snippet for loading Initialize-SQLClient function
    try {
      # ToDo: Remove this when packaging works
      if (-not (Get-Command -Name 'Initialize-SQLClient' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Initialize-SQLClient.ps1'
      }
    }
    catch {
      $errorMessage = "Failed to load Initialize-SQLClient function. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    # Try-Catch-Finally snippet for loading Get-ConnectionString function
    try {
      # ToDo: Remove this when packaging works
      if (-not (Get-Command -Name 'Get-ConnectionString' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Get-ConnectionString.ps1'
      }
    }
    catch {
      $errorMessage = "Failed to load Get-ConnectionString function. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    $script:errors = [System.Collections.Generic.List[string]]::new()
    $script:success = $false

    function Get-Env([string]$key) {
      [Environment]::GetEnvironmentVariable($key, 'Process')
    }

    function Test-Blank([string]$s) { [string]::IsNullOrWhiteSpace($s) }

    function Resolve-FromSettings([string]$db, [string]$env, [string]$leafKey) {
      if ($settings.ContainsKey($global:configRootKeys['DatabasesCollectionConfigRootKey'])) {
        $root = $settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]
        if ($root.ContainsKey($db) -and $root[$db].ContainsKey($env) -and $root[$db][$env].ContainsKey($leafKey)) {
          $val = $root[$db][$env][$leafKey]
          if (-not (Test-Blank $val)) { return $val }
        }
      }
      return $null
    }

    function Test-WindowsLoginName {
      param([string]$Name)
      return ($Name -match '[\\@]')
    }

    function Get-GitMeta {
      param([string]$StartDir)
      $git = Get-Command git -ErrorAction SilentlyContinue
      if (-not $git) { return @{ Tag = '(no-git)'; Commit = '(no-git)' } }
      $tag = $null; try { $tag = (git -C $StartDir describe --tags --abbrev=0 2>$null).Trim() } catch {}
      if (-not $tag) { $tag = '(untagged)' }
      $commit = (git -C $StartDir rev-parse --short HEAD 2>$null).Trim(); if (-not $commit) { $commit = '(no-commit)' }
      @{ Tag = $tag; Commit = $commit }
    }

    # These may throw
    # ToDo: write a wrapper that catches and logs
    $databasesCollection = $global:settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]

    $Environment = Get-PVal 'Environment' $PSBoundParameters
    $SqlInstance = Get-PVal -ParameterName "SqlInstance" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.SqlInstance" -Settings $databasesCollection
    $DatabaseHost = Get-PVal -ParameterName "DatabaseHost"  -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.DatabaseHost" -Settings $databasesCollection
    $ConnectionMethod = Get-PVal -ParameterName "ConnectionMethod" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.ConnectionMethod" -Settings $databasesCollection
    $UseNamedLogin = Get-PVal -ParameterName "UseNamedLogin" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.UseNamedLogin" -Settings $databasesCollection -AsType ([bool])
    $LoginName = Get-PVal -ParameterName "LoginName" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.LoginName" -Settings $databasesCollection
    $LoginPasswordVaultKey = Get-PVal -ParameterName "LoginPasswordVaultKey" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.LoginPasswordVaultKey" -Settings $databasesCollection
    $UseNamedLogin = Get-PVal -ParameterName "UseNamedLogin" -originalPSBoundParameters $PSBoundParameters -dottedPath "$databaseName.$Environment.UseNamedLogin" -Settings $databasesCollection -AsType ([bool])

    # Validate Environment parameter
    $Environment = Resolve-PVal $Environment 'Production', 'Testing', 'Development', 'Experimental'
    # Validate ConnectionMethod parameter
    $ConnectionMethod = Resolve-PVal $ConnectionMethod 'tcp', 'np', 'lpc'

    # ParameterValidation snippet (templated) for ConfigPath
    try {
      if ([string]::IsNullOrWhiteSpace($ConfigPath)) { throw 'ConfigPath is null or empty.' }
      if (-not (Test-Path -Path $ConfigPath)) { throw "ConfigPath not found: $ConfigPath" }
    }
    catch {
      $msg = "ConfigPath validation failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Validation', 'Error'
      $script:errors.Add($msg) | Out-Null; throw
    }

    # ParameterValidation snippet (templated) for PackageName
    try {
      if ([string]::IsNullOrWhiteSpace($PackageName)) { throw 'PackageName is null or empty.' }
    }
    catch {
      $msg = "PackageName validation failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Validation', 'Error'
      $script:errors.Add($msg) | Out-Null; throw
    }

    # ParameterValidation snippet (templated) for PackageVersion
    try {
      if ([string]::IsNullOrWhiteSpace($PackageVersion)) { throw 'PackageVersion is null or empty.' }
    }
    catch {
      $msg = "PackageVersion validation failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Validation', 'Error'
      $script:errors.Add($msg) | Out-Null; throw
    }

    # Set up SQL client types
    $script:SqlTypes = Initialize-SQLClient

    # Build up the connection string
    $script:ConnectionString = Get-ConnectionString -DatabaseHost $DatabaseHost -DatabaseName $DatabaseName -ConnectionMethod $ConnectionMethod -SqlInstance $SqlInstance -UseNamedLogin $UseNamedLogin -LoginName $LoginName -LoginPasswordVaultKey $LoginPasswordVaultKey -AsJDBC

    $script:isIntegrated = $script:ConnectionString -match 'integratedSecurity=true'
    if (-not $script:isIntegrated) {

      $script:flywayUser = $script:ConnectionString -match 'User ID=([^;]+);' | Out-Null; $script:flywayUser = $Matches[1]
      $script:flywayPwd = $script:ConnectionString -match 'Password=([^;]+);' | Out-Null; $script:flywayPwd = $Matches[1]
      if (Test-Blank $script:flywayUser -or Test-Blank $script:flywayPwd) {
        $msg = "Failed extracting SQL login name or password from connection string"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        $script:errors.Add($msg) | Out-Null; throw
      }
    }
    # Git metadata
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

    # Ensure BEGIN contains only validation/preparation. Auth/env selection moved to PROCESS.
  }

  PROCESS {

    # TLS defaults (adjust to policy)
    # ToDo: modify once trusted SSL certs are available
    $env:FLYWAY_ENCRYPT = 'false'
    $env:FLYWAY_TRUSTSERVERCERT = 'true'

    # Export placeholder env vars and auth vars
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Exporting Flyway placeholder environment variables'
    $env:FLYWAY_PLACEHOLDERS_MANIFESTVALUES = $script:valuesList
    $env:FLYWAY_PLACEHOLDERS_PACKAGENAME = $PackageName
    $env:FLYWAY_PLACEHOLDERS_PACKAGEVERSION = $PackageVersion
    $env:FLYWAY_PLACEHOLDERS_GITTAG = $GitTag
    $env:FLYWAY_PLACEHOLDERS_GITCOMMIT = $GitCommit

    # Configure authentication based on connection string
    if ($script:isIntegrated) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Configuring Flyway for Windows Integrated Authentication"

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

      # Verify authentication settings in connection string
      if ($script:ConnectionString -notmatch 'integratedSecurity=true') {
        $msg = "Connection string does not contain 'integratedSecurity=true' but script detected integrated auth"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message $msg
      }
    }
    else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Configuring Flyway for SQL Server Authentication"

      # Set environment-specific credentials for SQL authentication
      $envPrefix = switch ($Environment) {
        'Production' { 'PROD' }
        'Testing' { 'TEST' }
        'Development' { 'DEV' }
        'Experimental' { 'EXP' }
      }

      # [Environment]::SetEnvironmentVariable("FLYWAY_${envPrefix}_USER", $script:flywayUser, [EnvironmentVariableTarget]::Process)
      # [Environment]::SetEnvironmentVariable("FLYWAY_${envPrefix}_PASSWORD", $script:flywayPwd, [EnvironmentVariableTarget]::Process)

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Set FLYWAY_${envPrefix}_USER and FLYWAY_${envPrefix}_PASSWORD"
    }

    $optionalIinstanceName = switch ($Environment) {
      'Production' { 'instanceName=Production;' }
      'Testing' { 'instanceName=Testing;' }
      'Development' { 'instanceName=Development;' }
      'Experimental' { '' }
      default {
        $message = "Unhandled environment '$Environment' in switch"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message
        throw $message
      }
    }
    # Create the URL, ensuring all placeholders are replaced with actual values
    $env:FLYWAY_URL = $script:ConnectionString

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Flyway URL: $($env:FLYWAY_URL -replace 'password=[^;]*', 'password=***')"

    # Build flyway parameters and execute (use lowercase environment key)
    $environmentKey = $Environment.ToLowerInvariant()
    $flywayParams = @("-configFiles=$ConfigPath", "-environment=$environmentKey")
    if ($FlywayAdditionalArgs) { $flywayParams += $FlywayAdditionalArgs }
    $flywayParams += $FlywayCommand

    if ($PSCmdlet.ShouldProcess($ConfigPath, "flyway $FlywayCommand [$environmentKey]")) {
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling flyway with args: $($flywayParams -join ' ')"
        & $FlywayPath @flywayParams
        $exit = $LASTEXITCODE
        if ($exit -ne 0) { throw "flyway exited with code $exit" }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from flyway $FlywayCommand"
        $script:success = $true
      }
      catch {
        $msg = "flyway $FlywayCommand failed. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        if ($_.Exception.StackTrace) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "StackTrace: $($_.Exception.StackTrace)" }
        $script:errors.Add($msg) | Out-Null
        throw
      }
      finally {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished flyway $FlywayCommand attempt"
      }
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
      Success        = ($script:errors.Count -eq 0 -and $script:success)
      Errors         = $script:errors.ToArray()
      TimestampUTC   = (Get-Date).ToUniversalTime()
    }
    $level = if ($summary.Success) { 'Important' } else { 'Error' }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level $level -Message ("Manifest variables generation {0}" -f $($summary.Success ? 'succeeded' :  'failed' ))
    if (-not $summary.Success) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message ("Errors:`n" + ($summary.Errors -join [Environment]::NewLine)) }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function Invoke-Flyway'
    return $summary
  }
}

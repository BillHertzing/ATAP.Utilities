#Requires -Version 7.0
function Invoke-FlywayRehearsal {
  <#
.SYNOPSIS
    Runs a Flyway migration rehearsal against an ephemeral database.

.DESCRIPTION
    Creates a per-run rehearsal database, invokes Invoke-Flyway against it, and
    drops the database in a finally block. The default database name is
    <App>-rehearsal-<BuildId>; callers can override it with -RehearsalDb for
    ad-hoc local runs.

.PARAMETER Application
    Application name used for the default rehearsal DB name. Required only when
    -RehearsalDb is omitted.

.PARAMETER BuildId
    Build or pipeline-run identifier used for the default rehearsal DB name.

.PARAMETER RehearsalDb
    Optional explicit database name override.

.PARAMETER SqlInstance
    SQL Server named instance. Defaults to EXPWHERTZING for the ATAP
    Experimental rehearsal environment.

.PARAMETER DatabaseHost
    SQL Server host used with named-instance values such as EXPWHERTZING.

.PARAMETER BundlePath
    Optional Release Bundle path recorded in the result/log for traceability.

.PARAMETER BackupPath
    Optional previous-production backup path recorded in the result/log for
    traceability. Restoring the backup remains environment-specific; this cmdlet
    owns the ephemeral rehearsal DB lifecycle around the Flyway run.

.PARAMETER LogPath
    Optional path where the rehearsal result summary is written as JSON.
#>
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ConnectionParts')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ParameterSetName = 'SqlConnection')]
    [object]$SqlConnection,

    [Parameter(
      Mandatory = $true,
      ValueFromPipelineByPropertyName = $true,
      ParameterSetName = 'DBConnectionStringSecretName')]
    [Alias('DBConnectionStringSecret', 'SecretName', 'BitwardenSecretName', 'BitwardenSecret')]
    [string]$DBConnectionStringSecretName,

    [Parameter(Mandatory = $false)]
    [string]$Application,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$BuildId = $(
      if ($env:BUILDMASTER_BUILD_NUMBER) { $env:BUILDMASTER_BUILD_NUMBER }
      elseif ($env:BUILD_BUILDID) { $env:BUILD_BUILDID }
      else { [DateTime]::UtcNow.ToString('yyyyMMddHHmmss') }
    ),

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$RehearsalDb,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$SqlInstance = 'EXPWHERTZING',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [Alias('HostName', 'ServerInstance')]
    [string]$DatabaseHost = 'localhost',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$DatabaseName = 'master',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$CredentialsKey,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$ApplicationName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [switch]$UseTrustedConnection,

    [Parameter(Mandatory = $false)]
    [string]$BundlePath,

    [Parameter(Mandatory = $false)]
    [string]$BackupPath,

    [Parameter(Mandatory = $false)]
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [string]$FlywayExecutablePath,

    [Parameter(Mandatory = $false)]
    [string]$FlywayBasePath,

    [Parameter(Mandatory = $false)]
    [string]$FlywaySqlMigrationsPath,

    [Parameter(Mandatory = $false)]
    [string]$FlywaySharedSqlMigrationsPath,

    [Parameter(Mandatory = $false)]
    [string]$FlywayDataPath,

    [Parameter(Mandatory = $false)]
    [string]$FlywayTomlPath,

    [Parameter(Mandatory = $false)]
    [string[]]$FlywayAdditionalArgs,

    [Parameter(Mandatory = $false)]
    [string[]]$Files,

    [Parameter(Mandatory = $false)]
    [string]$PackageName,

    [Parameter(Mandatory = $false)]
    [string]$PackageVersion,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [switch]$IntegratedSecurity = $true,

    [Parameter(Mandatory = $false)]
    [hashtable]$Settings
  )

  begin {
    $fn = 'Invoke-FlywayRehearsal'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'

    function Resolve-ServerInstance {
      param(
        [Parameter(Mandatory = $true)][string]$HostName,
        [Parameter(Mandatory = $true)][string]$InstanceName
      )

      if ($InstanceName -match '^(?i)(tcp|np|lpc):') { return $InstanceName }
      if ($InstanceName -match '^(?i)\(localdb\)\\') { return $InstanceName }
      if ($InstanceName -match '^[^\\]+\\[^\\]+$') { return $InstanceName }
      if ([string]::IsNullOrWhiteSpace($HostName)) { return $InstanceName }
      return '{0}\{1}' -f $HostName, $InstanceName
    }

    $privateDir = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'private'
    if (-not (Get-Command -Name New-DatabaseConnectionParameterMap -CommandType Function -ErrorAction SilentlyContinue)) {
      . (Join-Path -Path $privateDir -ChildPath 'DatabaseSqlConnection.Helpers.ps1')
    }
    if (-not (Get-Command -Name Invoke-DatabaseSqlNonQuery -CommandType Function -ErrorAction SilentlyContinue)) {
      . (Join-Path -Path $privateDir -ChildPath 'DatabaseSqlCommand.Helpers.ps1')
    }
    if (-not (Get-Command -Name Resolve-DatabaseSqlConnection -CommandType Function -ErrorAction SilentlyContinue)) {
      . (Join-Path -Path $PSScriptRoot -ChildPath 'Resolve-DatabaseSqlConnection.ps1')
    }
    if (-not (Get-Command -Name Invoke-Flyway -CommandType Function -ErrorAction SilentlyContinue)) {
      . (Join-Path -Path $PSScriptRoot -ChildPath 'Invoke-Flyway.ps1')
    }

    $resolvedSqlConnection = $null
    $resolvedConnectionOwnedByFunction = $false
    $connectionResolvedInBegin = $false
    $connectionDisplayName = $null

    $resolveMasterConnection = {
      $connectionBoundParameters = @{}
      foreach ($key in $PSBoundParameters.Keys) {
        $connectionBoundParameters[$key] = $PSBoundParameters[$key]
      }
      $connectionBoundParameters['DatabaseName'] = 'master'

      Resolve-DatabaseSqlConnection `
        -OriginalPSBoundParameters $connectionBoundParameters `
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
        -Settings $Settings
    }

    $getConnectionDisplayName = {
      param([object]$Connection)

      if ($null -ne $Connection) {
        $dataSourceProperty = $Connection.PSObject.Properties['DataSource']
        if ($dataSourceProperty -and -not [string]::IsNullOrWhiteSpace([string]$dataSourceProperty.Value)) {
          return [string]$dataSourceProperty.Value
        }
      }

      return Resolve-ServerInstance -HostName $DatabaseHost -InstanceName $SqlInstance
    }

    if (-not $MyInvocation.ExpectingInput -or
      $PSBoundParameters.ContainsKey('SqlConnection') -or
      $PSBoundParameters.ContainsKey('DBConnectionStringSecretName')) {
      $resolution = & $resolveMasterConnection
      $resolvedSqlConnection = $resolution.Connection
      $resolvedConnectionOwnedByFunction = -not [bool]$resolution.IsCallerOwned
      $connectionDisplayName = & $getConnectionDisplayName $resolvedSqlConnection
      $connectionResolvedInBegin = $true
    }
  }

  process {
    if (-not $connectionResolvedInBegin) {
      $resolution = & $resolveMasterConnection
      $resolvedSqlConnection = $resolution.Connection
      $resolvedConnectionOwnedByFunction = -not [bool]$resolution.IsCallerOwned
      $connectionDisplayName = & $getConnectionDisplayName $resolvedSqlConnection
    }

    if ([string]::IsNullOrWhiteSpace($RehearsalDb)) {
      if ([string]::IsNullOrWhiteSpace($Application)) {
        throw 'Application is required when RehearsalDb is not supplied.'
      }
      $normalizedBuildId = ($BuildId -replace '[^A-Za-z0-9-]', '-').Trim('-')
      if ([string]::IsNullOrWhiteSpace($normalizedBuildId)) {
        throw "BuildId '$BuildId' cannot be converted to a rehearsal DB name segment."
      }
      $RehearsalDb = '{0}-rehearsal-{1}' -f $Application, $normalizedBuildId
    }
    if ($RehearsalDb.Length -gt 64) {
      throw "RehearsalDb '$RehearsalDb' is $($RehearsalDb.Length) characters; DB names are capped at 64."
    }

    $safeLiteral = $RehearsalDb.Replace("'", "''")
    $safeIdentifier = $RehearsalDb.Replace(']', ']]')
    $serverInstance = $connectionDisplayName
    $created = $false
    $dropped = $false
    $flywayResult = $null
    $errorText = $null

    try {
      $createQuery = @"
USE [master];
IF DB_ID(N'$safeLiteral') IS NOT NULL
BEGIN
  ALTER DATABASE [$safeIdentifier] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE [$safeIdentifier];
END;
CREATE DATABASE [$safeIdentifier];
"@

      if ($PSCmdlet.ShouldProcess("$serverInstance/$RehearsalDb", 'Create ephemeral Flyway rehearsal database')) {
        [void](Invoke-DatabaseSqlNonQuery -SqlConnection $resolvedSqlConnection -CommandText $createQuery)
        $created = $true
      }

      $flywayParams = @{
        DatabaseName = $RehearsalDb
        Environment  = 'Experimental'
        FlywayCommand = 'migrate'
      }
      switch ($PSCmdlet.ParameterSetName) {
        'SqlConnection' {
          $flywayParams.SqlConnection = $resolvedSqlConnection
        }
        'DBConnectionStringSecretName' {
          $flywayParams.DBConnectionStringSecretName = $DBConnectionStringSecretName
        }
        default {
          $flywayParams.DatabaseHost = $DatabaseHost
          $flywayParams.SqlInstance = $SqlInstance
          if ($ConnectionMethod) { $flywayParams.ConnectionMethod = $ConnectionMethod }
          if ($CredentialsKey) { $flywayParams.CredentialsKey = $CredentialsKey }
          if ($ApplicationName) { $flywayParams.ApplicationName = $ApplicationName }
          if ($IntegratedSecurity) { $flywayParams.IntegratedSecurity = $true }
          if ($UseTrustedConnection) { $flywayParams.UseTrustedConnection = $true }
          if ($Settings) { $flywayParams.Settings = $Settings }
        }
      }
      if ($FlywayExecutablePath) { $flywayParams.FlywayExecutablePath = $FlywayExecutablePath }
      if ($FlywayBasePath) { $flywayParams.FlywayBasePath = $FlywayBasePath }
      if ($FlywaySqlMigrationsPath) { $flywayParams.FlywaySqlMigrationsPath = $FlywaySqlMigrationsPath }
      if ($FlywaySharedSqlMigrationsPath) { $flywayParams.FlywaySharedSqlMigrationsPath = $FlywaySharedSqlMigrationsPath }
      if ($FlywayDataPath) { $flywayParams.FlywayDataPath = $FlywayDataPath }
      if ($FlywayTomlPath) { $flywayParams.FlywayTomlPath = $FlywayTomlPath }
      if ($FlywayAdditionalArgs) { $flywayParams.FlywayAdditionalArgs = $FlywayAdditionalArgs }
      if ($Files) { $flywayParams.Files = $Files }
      if ($PackageName) { $flywayParams.PackageName = $PackageName }
      if ($PackageVersion) { $flywayParams.PackageVersion = $PackageVersion }

      if ($PSCmdlet.ShouldProcess($RehearsalDb, 'Run Flyway migrate rehearsal')) {
        $flywayResult = Invoke-Flyway @flywayParams
      }
    } catch {
      $errorText = $_.Exception.Message
      throw
    } finally {
      $dropQuery = @"
USE [master];
IF DB_ID(N'$safeLiteral') IS NOT NULL
BEGIN
  ALTER DATABASE [$safeIdentifier] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE [$safeIdentifier];
END
"@
      try {
        if ($PSCmdlet.ShouldProcess("$serverInstance/$RehearsalDb", 'Drop ephemeral Flyway rehearsal database')) {
          [void](Invoke-DatabaseSqlNonQuery -SqlConnection $resolvedSqlConnection -CommandText $dropQuery)
          $dropped = $true
        }
      } catch {
        $dropError = $_.Exception.Message
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to drop rehearsal database '$RehearsalDb': $dropError"
        if ($null -eq $errorText) { $errorText = $dropError }
      }

      if ($LogPath) {
        $logParent = Split-Path -Parent $LogPath
        if (-not [string]::IsNullOrWhiteSpace($logParent)) {
          New-Item -ItemType Directory -Path $logParent -Force | Out-Null
        }
        [PSCustomObject]@{
          OperationName = $fn
          Application   = $Application
          BuildId       = $BuildId
          RehearsalDb   = $RehearsalDb
          SqlInstance   = $SqlInstance
          ServerInstance = $serverInstance
          BundlePath    = $BundlePath
          BackupPath    = $BackupPath
          Created       = $created
          Dropped       = $dropped
          FlywayResult  = $flywayResult
          Error         = $errorText
          TimestampUtc  = (Get-Date).ToUniversalTime().ToString('o')
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $LogPath -Encoding UTF8
      }
    }

    return [PSCustomObject]@{
      OperationName   = $fn
      Application     = $Application
      BuildId         = $BuildId
      RehearsalDb     = $RehearsalDb
      SqlInstance     = $SqlInstance
      ServerInstance  = $serverInstance
      BundlePath      = $BundlePath
      BackupPath      = $BackupPath
      Created         = $created
      Dropped         = $dropped
      FlywayResult    = $flywayResult
      Success         = ($created -and $dropped -and ($null -eq $flywayResult -or $flywayResult.Success -ne $false))
      ResponseSummary = "ran Flyway rehearsal against ephemeral database '$RehearsalDb'"
    }
  }

  end {
    if ($resolvedConnectionOwnedByFunction -and $null -ne $resolvedSqlConnection) {
      try { $resolvedSqlConnection.Close() } catch { }
      try { $resolvedSqlConnection.Dispose() } catch { }
      $resolvedSqlConnection = $null
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}

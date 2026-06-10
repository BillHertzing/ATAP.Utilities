#Requires -Version 7.0
function New-DeveloperScratchDb {
  <#
.SYNOPSIS
    Creates an idempotent per-developer scratch SQL Server database.

.DESCRIPTION
    Resolves the database name with Resolve-DbInstanceName -Kind
    developer-scratch, checks whether it already exists, and creates it when
    absent. Existing databases are treated as success and are not modified.

.PARAMETER Application
    Application name used in the canonical DB name.

.PARAMETER GitHandle
    Developer GitHub handle used in the canonical DB name.

.PARAMETER SqlInstance
    SQL Server instance/server string. Defaults to (localdb)\MSSQLLocalDB.

.OUTPUTS
    [PSCustomObject] with Success, Created, DatabaseName, SqlInstance, and
    ResponseSummary.
#>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialsKey',
    Justification = 'CredentialsKey is a vault lookup key name, not a credential')]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidDefaultValueSwitchParameter', '',
    Justification = 'IntegratedSecurity defaults to $true for a secure-by-default posture')]
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

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Application,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$GitHandle,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [Alias('HostName', 'ServerInstance')]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$SqlInstance = '(localdb)\MSSQLLocalDB',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$InstanceName,

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

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [switch]$IntegratedSecurity = $true,

    [Parameter(Mandatory = $false)]
    [hashtable]$Settings
  )

  begin {
    $fn = 'New-DeveloperScratchDb'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'

    $privateDir = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'private'
    if (-not (Get-Command -Name New-DatabaseConnectionParameterMap -CommandType Function -ErrorAction SilentlyContinue)) {
      . (Join-Path -Path $privateDir -ChildPath 'DatabaseSqlConnection.Helpers.ps1')
    }
    if (-not (Get-Command -Name Invoke-DatabaseSqlScalar -CommandType Function -ErrorAction SilentlyContinue)) {
      . (Join-Path -Path $privateDir -ChildPath 'DatabaseSqlCommand.Helpers.ps1')
    }
    if (-not (Get-Command -Name Resolve-DatabaseSqlConnection -CommandType Function -ErrorAction SilentlyContinue)) {
      . (Join-Path -Path $PSScriptRoot -ChildPath 'Resolve-DatabaseSqlConnection.ps1')
    }
    if (-not (Get-Command -Name Resolve-DbInstanceName -CommandType Function -ErrorAction SilentlyContinue)) {
      . (Join-Path -Path $PSScriptRoot -ChildPath 'Resolve-DbInstanceName.ps1')
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

      $effectiveDatabaseHost = if (-not [string]::IsNullOrWhiteSpace($DatabaseHost)) { $DatabaseHost } else { $SqlInstance }
      $effectiveInstanceName = if (-not [string]::IsNullOrWhiteSpace($InstanceName)) {
        $InstanceName
      } elseif ($PSBoundParameters.ContainsKey('DatabaseHost') -and $PSBoundParameters.ContainsKey('SqlInstance')) {
        $SqlInstance
      } else {
        $null
      }

      [void]$connectionBoundParameters.Remove('SqlInstance')
      [void]$connectionBoundParameters.Remove('InstanceName')
      $connectionBoundParameters['DatabaseHost'] = $effectiveDatabaseHost
      $connectionBoundParameters['DatabaseName'] = 'master'
      if (-not [string]::IsNullOrWhiteSpace($effectiveInstanceName)) {
        $connectionBoundParameters['InstanceName'] = $effectiveInstanceName
      }

      Resolve-DatabaseSqlConnection `
        -OriginalPSBoundParameters $connectionBoundParameters `
        -SqlConnection $SqlConnection `
        -DBConnectionStringSecretName $DBConnectionStringSecretName `
        -DatabaseHost $effectiveDatabaseHost `
        -InstanceName $effectiveInstanceName `
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

      if (-not [string]::IsNullOrWhiteSpace($DatabaseHost)) {
        if (-not [string]::IsNullOrWhiteSpace($InstanceName)) { return '{0}\{1}' -f $DatabaseHost, $InstanceName }
        if ($PSBoundParameters.ContainsKey('SqlInstance') -and -not [string]::IsNullOrWhiteSpace($SqlInstance)) { return '{0}\{1}' -f $DatabaseHost, $SqlInstance }
        return $DatabaseHost
      }

      return $SqlInstance
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

    $databaseName = Resolve-DbInstanceName -Application $Application -Kind developer-scratch -GitHandle $GitHandle
    $safeLiteral = $databaseName.Replace("'", "''")
    $safeIdentifier = $databaseName.Replace(']', ']]')

    $existsQuery = @"
USE [master];
IF DB_ID(N'$safeLiteral') IS NULL
  SELECT CAST(0 AS bit) AS ExistsFlag;
ELSE
  SELECT CAST(1 AS bit) AS ExistsFlag;
"@

    $exists = [bool](Invoke-DatabaseSqlScalar -SqlConnection $resolvedSqlConnection -CommandText $existsQuery)

    if ($exists) {
      $summary = "Database '$databaseName' already present on '$connectionDisplayName'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $summary
      return [PSCustomObject]@{
        OperationName   = $fn
        Application     = $Application
        GitHandle       = $GitHandle
        DatabaseName    = $databaseName
        SqlInstance     = $connectionDisplayName
        Created         = $false
        Success         = $true
        ResponseSummary = 'already present'
      }
    }

    $created = $false
    if ($PSCmdlet.ShouldProcess("$connectionDisplayName/$databaseName", 'Create developer scratch database')) {
      $createQuery = "USE [master]; CREATE DATABASE [$safeIdentifier];"
      [void](Invoke-DatabaseSqlNonQuery -SqlConnection $resolvedSqlConnection -CommandText $createQuery)
      $created = $true
    }

    return [PSCustomObject]@{
      OperationName   = $fn
      Application     = $Application
      GitHandle       = $GitHandle
      DatabaseName    = $databaseName
      SqlInstance     = $connectionDisplayName
      Created         = $created
      Success         = $true
      ResponseSummary = if ($created) { "created database '$databaseName'" } else { "would create database '$databaseName'" }
    }
  }

  end {
    if ($resolvedConnectionOwnedByFunction -and $null -ne $resolvedSqlConnection) {
      try { $resolvedSqlConnection.Close() } catch { $null = $_ }
      try { $resolvedSqlConnection.Dispose() } catch { $null = $_ }
      $resolvedSqlConnection = $null
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}

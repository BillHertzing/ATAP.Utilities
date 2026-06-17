function Resolve-DatabaseSqlConnection {
  <#
  .SYNOPSIS
  Resolves the supported ATAP database connection inputs to one open SqlConnection plus an ownership flag.

  .DESCRIPTION
  Centralizes database connection validation for PowerShell functions that access SQL Server.
  The resolver evaluates the three supported connection methods in this priority order:

  1. SqlConnection         : highest priority. An already-open Microsoft.Data.SqlClient.SqlConnection.
                             The caller owns the connection lifecycle (IsCallerOwned = $true).
  2. DBConnectionStringSecretName : second priority. Names an ATAP secret whose 'notes' field is a
                             complete SQL connection string. The resolver reads it via
                             Get-SecretATAP -SecretField 'notes' and opens a new connection.
                             The function owns the lifecycle (IsCallerOwned = $false).
  3. ConnectionParts       : lowest priority (default). Structured host/instance/database parts
                             resolved through Get-ParameterValueFromNeoConfigurationRoot / Get-PVal,
                             with defaults from $global:settings. The resolver opens a new
                             connection. The function owns the lifecycle (IsCallerOwned = $false).

  Existing open SqlConnection objects take precedence over DBConnectionStringSecretName.
  DBConnectionStringSecretName takes precedence over ConnectionParts.

  .PARAMETER OriginalPSBoundParameters
  The caller's $PSBoundParameters hashtable. Pass this from database-accessing cmdlets so
  Get-PVal can distinguish values supplied by the caller from defaults passed to this helper.

  .OUTPUTS
  [pscustomobject] with properties:
    Connection    : the open Microsoft.Data.SqlClient.SqlConnection
    IsCallerOwned : [bool] true only when SqlConnection parameter set was used

  .EXAMPLE
  $resolution = Resolve-DatabaseSqlConnection -OriginalPSBoundParameters $PSBoundParameters -SqlConnection $SqlConnection -DBConnectionStringSecretName $DBConnectionStringSecretName -DatabaseHost $DatabaseHost -InstanceName $InstanceName -DatabaseName $DatabaseName -ConnectionMethod $ConnectionMethod -CredentialsKey $CredentialsKey -ApplicationName $ApplicationName -IntegratedSecurity:$IntegratedSecurity -UseTrustedConnection:$UseTrustedConnection -Settings $Settings
  $openSQLConnection      = $resolution.Connection
  $isCallerOwnedConnection = [bool]$resolution.IsCallerOwned

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines
  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialsKey',
    Justification = 'CredentialsKey is a vault lookup key name, not a credential')]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialsKeyDottedPath',
    Justification = 'CredentialsKeyDottedPath is a configuration path string, not a credential')]
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [AllowNull()]
    [object] $SqlConnection,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [Alias('DBConnectionStringSecret', 'SecretName', 'BitwardenSecretName', 'BitwardenSecret')]
    [string] $DBConnectionStringSecretName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [Alias('DBConnectionStringMasterSecret', 'MasterSecretName', 'DBMasterConnectionStringSecretName')]
    [string] $DBConnectionStringMasterSecretName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [Alias('DBConnectionStringDatabaseSecretName', 'DBConnectionStringDatabaseSecret', 'DatabaseSecretName', 'DBSecretName')]
    [string] $DBConnectionStringDBSecretName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [Alias('HostName', 'ServerInstance')]
    [string] $DatabaseHost,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [Alias('SqlInstance')]
    [string] $InstanceName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string] $DatabaseName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string] $ConnectionMethod,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string] $CredentialsKey,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string] $ApplicationName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [switch] $UseTrustedConnection,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [switch] $IntegratedSecurity,

    [Parameter(Mandatory = $false)]
    [hashtable] $Settings,

    [Parameter(Mandatory = $false)]
    [hashtable] $OriginalPSBoundParameters,

    [Parameter(Mandatory = $false)]
    [string] $DatabaseHostDottedPath = 'DatabaseHost',

    [Parameter(Mandatory = $false)]
    [string] $DBConnectionStringSecretNameDottedPath = 'DBConnectionStringSecretName',

    [Parameter(Mandatory = $false)]
    [string] $DBConnectionStringMasterSecretNameDottedPath = 'DBConnectionStringMasterSecretName',

    [Parameter(Mandatory = $false)]
    [string] $DBConnectionStringDBSecretNameDottedPath = 'DBConnectionStringDBSecretName',

    [Parameter(Mandatory = $false)]
    [string] $DatabaseNameDottedPath = 'DatabaseName',

    [Parameter(Mandatory = $false)]
    [string] $ConnectionMethodDottedPath = 'ConnectionMethod',

    [Parameter(Mandatory = $false)]
    [string] $CredentialsKeyDottedPath = 'CredentialsKey',

    [Parameter(Mandatory = $false)]
    [string] $ApplicationNameDottedPath = 'ApplicationName',

    [Parameter(Mandatory = $false)]
    [string] $InstanceNameDottedPath = 'InstanceName',

    [Parameter(Mandatory = $false)]
    [string] $IntegratedSecurityDottedPath = 'IntegratedSecurity',

    [Parameter(Mandatory = $false)]
    [string] $UseTrustedConnectionDottedPath = 'UseTrustedConnection'
  )

  begin {
    if (-not (Get-Command -Name 'New-DatabaseConnectionParameterMap' -CommandType Function -ErrorAction SilentlyContinue)) {
      $privateDir = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'private'
      . (Join-Path -Path $privateDir -ChildPath 'DatabaseSqlConnection.Helpers.ps1')
    }
  }

  process {
    $sourceBoundParameters = if ($OriginalPSBoundParameters -and $OriginalPSBoundParameters.Count -gt 0) {
      $OriginalPSBoundParameters
    }
    else {
      $PSBoundParameters
    }

    $normalizedBoundParameters = New-DatabaseConnectionParameterMap -BoundParameters $sourceBoundParameters

    # Priority 1: SqlConnection (caller-owned).
    $effectiveSqlConnection = $SqlConnection
    if ($null -eq $effectiveSqlConnection -and $normalizedBoundParameters.ContainsKey('SqlConnection')) {
      $effectiveSqlConnection = $normalizedBoundParameters['SqlConnection']
    }
    if ($null -ne $effectiveSqlConnection) {
      $verifiedConnection = Assert-DatabaseSqlConnectionIsOpen `
        -Connection $effectiveSqlConnection `
        -Source 'SqlConnection parameter'
      return [pscustomobject]@{
        Connection    = $verifiedConnection
        IsCallerOwned = $true
      }
    }

    # Priority 2: connection-string secret name (function-owned).
    $databaseNameForSecretSelection = $DatabaseName
    if ([string]::IsNullOrWhiteSpace($databaseNameForSecretSelection) -and $normalizedBoundParameters.ContainsKey('DatabaseName')) {
      $databaseNameForSecretSelection = [string] $normalizedBoundParameters['DatabaseName']
    }
    $useMasterSecret = [string]::Equals($databaseNameForSecretSelection, 'master', [System.StringComparison]::OrdinalIgnoreCase)

    $specificSecretParameterName = if ($useMasterSecret) { 'DBConnectionStringMasterSecretName' } else { 'DBConnectionStringDBSecretName' }
    $specificSecretDottedPath = if ($useMasterSecret) { $DBConnectionStringMasterSecretNameDottedPath } else { $DBConnectionStringDBSecretNameDottedPath }
    $effectiveSecretName = if ($useMasterSecret) { $DBConnectionStringMasterSecretName } else { $DBConnectionStringDBSecretName }
    if ([string]::IsNullOrWhiteSpace($effectiveSecretName) -and $normalizedBoundParameters.ContainsKey($specificSecretParameterName)) {
      $effectiveSecretName = [string] $normalizedBoundParameters[$specificSecretParameterName]
    }
    if ([string]::IsNullOrWhiteSpace($effectiveSecretName)) {
      Import-DatabaseConnectionHelperFunctions
      $effectiveSecretName = Invoke-DatabaseConnectionGetPVal `
        -ParameterName $specificSecretParameterName `
        -BoundParameters $normalizedBoundParameters `
        -DottedPath $specificSecretDottedPath `
        -Settings $Settings `
        -DefaultValue $null `
        -AllowMissing:$true `
        -AsType ([string])
    }
    if ([string]::IsNullOrWhiteSpace($effectiveSecretName)) {
      $effectiveSecretName = $DBConnectionStringSecretName
      if ([string]::IsNullOrWhiteSpace($effectiveSecretName) -and $normalizedBoundParameters.ContainsKey('DBConnectionStringSecretName')) {
        $effectiveSecretName = [string] $normalizedBoundParameters['DBConnectionStringSecretName']
      }
    }
    if ([string]::IsNullOrWhiteSpace($effectiveSecretName)) {
      Import-DatabaseConnectionHelperFunctions
      $effectiveSecretName = Invoke-DatabaseConnectionGetPVal `
        -ParameterName 'DBConnectionStringSecretName' `
        -BoundParameters $normalizedBoundParameters `
        -DottedPath $DBConnectionStringSecretNameDottedPath `
        -Settings $Settings `
        -DefaultValue $null `
        -AllowMissing:$true `
        -AsType ([string])
    }
    if (-not [string]::IsNullOrWhiteSpace($effectiveSecretName)) {
      $openedConnection = Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName `
        -SecretName $effectiveSecretName
      return [pscustomobject]@{
        Connection    = $openedConnection
        IsCallerOwned = $false
      }
    }

    # Priority 3: ConnectionParts (function-owned).
    if ([string]::IsNullOrWhiteSpace($DatabaseHost) -and $normalizedBoundParameters.ContainsKey('DatabaseHost')) {
      $DatabaseHost = [string] $normalizedBoundParameters['DatabaseHost']
    }
    if ([string]::IsNullOrWhiteSpace($InstanceName) -and $normalizedBoundParameters.ContainsKey('InstanceName')) {
      $InstanceName = [string] $normalizedBoundParameters['InstanceName']
    }
    if ([string]::IsNullOrWhiteSpace($DatabaseName) -and $normalizedBoundParameters.ContainsKey('DatabaseName')) {
      $DatabaseName = [string] $normalizedBoundParameters['DatabaseName']
    }
    if ([string]::IsNullOrWhiteSpace($ConnectionMethod) -and $normalizedBoundParameters.ContainsKey('ConnectionMethod')) {
      $ConnectionMethod = [string] $normalizedBoundParameters['ConnectionMethod']
    }
    if ([string]::IsNullOrWhiteSpace($CredentialsKey) -and $normalizedBoundParameters.ContainsKey('CredentialsKey')) {
      $CredentialsKey = [string] $normalizedBoundParameters['CredentialsKey']
    }
    if ([string]::IsNullOrWhiteSpace($ApplicationName) -and $normalizedBoundParameters.ContainsKey('ApplicationName')) {
      $ApplicationName = [string] $normalizedBoundParameters['ApplicationName']
    }

    $integratedSecurityValue = [bool] $IntegratedSecurity
    if ($normalizedBoundParameters.ContainsKey('IntegratedSecurity')) {
      $integratedSecurityValue = [bool] $normalizedBoundParameters['IntegratedSecurity']
    }

    $useTrustedConnectionValue = [bool] $UseTrustedConnection
    if ($normalizedBoundParameters.ContainsKey('UseTrustedConnection')) {
      $useTrustedConnectionValue = [bool] $normalizedBoundParameters['UseTrustedConnection']
    }

    $partsConnection = Resolve-DatabaseSqlConnectionFromConnectionParts `
      -BoundParameters $normalizedBoundParameters `
      -Settings $Settings `
      -DatabaseHost $DatabaseHost `
      -DatabaseName $DatabaseName `
      -ConnectionMethod $ConnectionMethod `
      -CredentialsKey $CredentialsKey `
      -ApplicationName $ApplicationName `
      -InstanceName $InstanceName `
      -IntegratedSecurity:$integratedSecurityValue `
      -UseTrustedConnection:$useTrustedConnectionValue `
      -DatabaseHostDottedPath $DatabaseHostDottedPath `
      -DatabaseNameDottedPath $DatabaseNameDottedPath `
      -ConnectionMethodDottedPath $ConnectionMethodDottedPath `
      -CredentialsKeyDottedPath $CredentialsKeyDottedPath `
      -ApplicationNameDottedPath $ApplicationNameDottedPath `
      -InstanceNameDottedPath $InstanceNameDottedPath `
      -IntegratedSecurityDottedPath $IntegratedSecurityDottedPath `
      -UseTrustedConnectionDottedPath $UseTrustedConnectionDottedPath

    return [pscustomobject]@{
      Connection    = $partsConnection
      IsCallerOwned = $false
    }
  }
}

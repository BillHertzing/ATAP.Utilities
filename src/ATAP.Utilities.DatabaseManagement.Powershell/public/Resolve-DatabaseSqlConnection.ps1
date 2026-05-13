function Resolve-DatabaseSqlConnection {
  <#
  .SYNOPSIS
  Resolves the supported ATAP database connection inputs to one open SqlConnection.

  .DESCRIPTION
  Centralizes database connection validation for PowerShell functions that access SQL Server.
  The resolver accepts the three supported connection methods:

  - An existing Microsoft.Data.SqlClient.SqlConnection object.
  - A Bitwarden secret name whose password value is a complete SQL connection string.
  - Structured connection parts resolved through Get-ParameterValueFromNeoConfigurationRoot / Get-PVal.

  Existing open SqlConnection objects take precedence over Bitwarden secret names. Bitwarden
  secret names take precedence over structured connection parts.

  .PARAMETER OriginalPSBoundParameters
  The caller's $PSBoundParameters hashtable. Pass this from database-accessing cmdlets so
  Get-PVal can distinguish values supplied by the caller from defaults passed to this helper.

  .OUTPUTS
  Microsoft.Data.SqlClient.SqlConnection

  .EXAMPLE
  $sqlConnection = Resolve-DatabaseSqlConnection -OriginalPSBoundParameters $PSBoundParameters -SqlConnection $SqlConnection -BitwardenSecretName $BitwardenSecretName -DatabaseHost $DatabaseHost -InstanceName $InstanceName -DatabaseName $DatabaseName -ConnectionMethod $ConnectionMethod -CredentialsKey $CredentialsKey -ApplicationName $ApplicationName -IntegratedSecurity:$IntegratedSecurity -UseTrustedConnection:$UseTrustedConnection -Settings $Settings
  #>
  [CmdletBinding()]
  [OutputType([object])]
  param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [AllowNull()]
    [object] $SqlConnection,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [Alias('BitwardenSecret', 'SecretName')]
    [string] $BitwardenSecretName,

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

  process {
    $sourceBoundParameters = if ($OriginalPSBoundParameters -and $OriginalPSBoundParameters.Count -gt 0) {
      $OriginalPSBoundParameters
    }
    else {
      $PSBoundParameters
    }

    $normalizedBoundParameters = New-DatabaseConnectionParameterMap -BoundParameters $sourceBoundParameters

    $effectiveSqlConnection = $SqlConnection
    if ($null -eq $effectiveSqlConnection -and $normalizedBoundParameters.ContainsKey('SqlConnection')) {
      $effectiveSqlConnection = $normalizedBoundParameters['SqlConnection']
    }
    if ($null -ne $effectiveSqlConnection) {
      return Assert-DatabaseSqlConnectionIsOpen `
        -Connection $effectiveSqlConnection `
        -Source 'SqlConnection parameter'
    }

    $effectiveBitwardenSecretName = $BitwardenSecretName
    if ([string]::IsNullOrWhiteSpace($effectiveBitwardenSecretName) -and $normalizedBoundParameters.ContainsKey('BitwardenSecretName')) {
      $effectiveBitwardenSecretName = [string] $normalizedBoundParameters['BitwardenSecretName']
    }
    if (-not [string]::IsNullOrWhiteSpace($effectiveBitwardenSecretName)) {
      return Resolve-DatabaseSqlConnectionFromBitwardenSecretName -SecretName $effectiveBitwardenSecretName
    }

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

    return Resolve-DatabaseSqlConnectionFromConnectionParts `
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
  }
}

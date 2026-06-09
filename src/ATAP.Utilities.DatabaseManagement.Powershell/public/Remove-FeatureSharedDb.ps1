#Requires -Version 7.0
function Remove-FeatureSharedDb {
  <#
.SYNOPSIS
    Drops disposable per-feature shared databases.

.DESCRIPTION
    Drops databases matching the Stream J feature-shared naming rule. When
    -Feature is supplied, the cmdlet drops the single
    <App>-<Feature>-shared database. Without -Feature, it targets all
    <App>-*-shared feature-shared databases.

    Data is NOT backed up. Feature shared databases are disposable lifecycle
    databases; durable schema and seed changes must be committed to source
    before this cmdlet is run.

.PARAMETER Application
    Application name used in the canonical DB names.

.PARAMETER Feature
    Optional feature slug filter.

.PARAMETER SqlInstance
    SQL Server instance/server string. Defaults to (localdb)\MSSQLLocalDB.

.PARAMETER Force
    Skips the confirmation prompt. -WhatIf still lists databases that would be
    dropped without dropping them.
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

    [Parameter(Mandatory = $false)]
    [Alias('FeatureSlug')]
    [string]$Feature,

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
    [hashtable]$Settings,

    [Parameter(Mandatory = $false)]
    [switch]$Force
  )

  begin {
    $fn = 'Remove-FeatureSharedDb'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'

    $privateDir = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'private'
    if (-not (Get-Command -Name New-DatabaseConnectionParameterMap -CommandType Function -ErrorAction SilentlyContinue)) {
      . (Join-Path -Path $privateDir -ChildPath 'DatabaseSqlConnection.Helpers.ps1')
    }
    if (-not (Get-Command -Name Invoke-DatabaseSqlQuery -CommandType Function -ErrorAction SilentlyContinue)) {
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

    $getDatabaseNames = {
      param([string]$Query)
      @(
        Invoke-DatabaseSqlQuery -SqlConnection $resolvedSqlConnection -CommandText $Query |
          ForEach-Object { [string]$_.Name }
      )
    }
  }

  process {
    if (-not $connectionResolvedInBegin) {
      $resolution = & $resolveMasterConnection
      $resolvedSqlConnection = $resolution.Connection
      $resolvedConnectionOwnedByFunction = -not [bool]$resolution.IsCallerOwned
      $connectionDisplayName = & $getConnectionDisplayName $resolvedSqlConnection
    }

    $databaseNames = @()

    if (-not [string]::IsNullOrWhiteSpace($Feature)) {
      $databaseNames = @(Resolve-DbInstanceName -Application $Application -Kind feature-shared -FeatureSlug $Feature)
    } else {
      $prefix = ($Application + '-').Replace("'", "''")
      $query = "USE [master]; SELECT [name] AS [Name] FROM sys.databases WHERE [name] LIKE N'$prefix%-shared' ORDER BY [name];"
      $databaseNames = & $getDatabaseNames $query
    }

    if ($databaseNames.Count -eq 0) {
      return [PSCustomObject]@{
        OperationName   = $fn
        Application     = $Application
        Feature         = $Feature
        DatabaseName    = $null
        SqlInstance     = $connectionDisplayName
        Dropped         = $false
        Success         = $true
        ResponseSummary = 'no matching databases found'
      }
    }

    foreach ($databaseName in $databaseNames) {
      $safeLiteral = $databaseName.Replace("'", "''")
      $safeIdentifier = $databaseName.Replace(']', ']]')
      $dropQuery = @"
USE [master];
IF DB_ID(N'$safeLiteral') IS NOT NULL
BEGIN
  ALTER DATABASE [$safeIdentifier] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE [$safeIdentifier];
END
"@

      if ($WhatIfPreference) {
        [void]$PSCmdlet.ShouldProcess("$connectionDisplayName/$databaseName", 'Drop feature shared database')
        [PSCustomObject]@{
          OperationName   = $fn
          Application     = $Application
          Feature         = $Feature
          DatabaseName    = $databaseName
          SqlInstance     = $connectionDisplayName
          Dropped         = $false
          Success         = $true
          ResponseSummary = "would drop feature shared database '$databaseName'"
        }
        continue
      }

      if ($PSCmdlet.ShouldProcess("$connectionDisplayName/$databaseName", 'Drop feature shared database')) {
        if (-not $Force) {
          $message = "Drop feature shared database '$databaseName' on '$connectionDisplayName'? Data is NOT backed up."
          if (-not $PSCmdlet.ShouldContinue($message, 'Confirm database drop')) {
            [PSCustomObject]@{
              OperationName   = $fn
              Application     = $Application
              Feature         = $Feature
              DatabaseName    = $databaseName
              SqlInstance     = $connectionDisplayName
              Dropped         = $false
              Success         = $true
              ResponseSummary = "skipped database '$databaseName'"
            }
            continue
          }
        }

        [void](Invoke-DatabaseSqlNonQuery -SqlConnection $resolvedSqlConnection -CommandText $dropQuery)
        [PSCustomObject]@{
          OperationName   = $fn
          Application     = $Application
          Feature         = $Feature
          DatabaseName    = $databaseName
          SqlInstance     = $connectionDisplayName
          Dropped         = $true
          Success         = $true
          ResponseSummary = "dropped feature shared database '$databaseName'"
        }
      }
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

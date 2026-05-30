#Requires -Version 7.0
function Remove-DeveloperScratchDb {
  <#
.SYNOPSIS
    Drops disposable developer scratch or per-feature-sprint databases.

.DESCRIPTION
    Drops databases matching the Stream J lifecycle naming rules. When
    -GitHandle is supplied, the cmdlet drops the single
    <App>-dev-<GitHandle> database. When -Feature is supplied, it drops
    matching per-feature-sprint databases named <App>-<Feature>-<GitHandle>.
    With neither filter, it targets all <App>-dev-* scratch databases.

    Data is NOT backed up. Scratch and per-feature-sprint databases are
    disposable by definition; migrations or test data that matter must be
    committed to source before this cmdlet is run.

.PARAMETER Application
    Application name used in the canonical DB names.

.PARAMETER GitHandle
    Optional developer GitHub handle filter for a single scratch DB.

.PARAMETER Feature
    Optional feature slug filter. Targets per-feature-sprint DBs for that
    feature rather than per-developer scratch DBs.

.PARAMETER SqlInstance
    SQL Server instance/server string. Defaults to (localdb)\MSSQLLocalDB.

.PARAMETER Force
    Skips the confirmation prompt. -WhatIf still lists databases that would be
    dropped without dropping them.
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

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Application,

    [Parameter(Mandatory = $false)]
    [string]$GitHandle,

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
    $fn = 'Remove-DeveloperScratchDb'
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
      [void](Resolve-DbInstanceName -Application $Application -Kind feature-sprint -FeatureSlug $Feature -GitHandle 'placeholder')
      $prefix = ('{0}-{1}-' -f $Application, $Feature).Replace("'", "''")
      $query = "USE [master]; SELECT [name] AS [Name] FROM sys.databases WHERE [name] LIKE N'$prefix%' AND [name] NOT LIKE N'%-shared' ORDER BY [name];"
      $databaseNames = & $getDatabaseNames $query
    } elseif (-not [string]::IsNullOrWhiteSpace($GitHandle)) {
      $databaseNames = @(Resolve-DbInstanceName -Application $Application -Kind developer-scratch -GitHandle $GitHandle)
    } else {
      $prefix = ('{0}-dev-' -f $Application).Replace("'", "''")
      $query = "USE [master]; SELECT [name] AS [Name] FROM sys.databases WHERE [name] LIKE N'$prefix%' ORDER BY [name];"
      $databaseNames = & $getDatabaseNames $query
    }

    if ($databaseNames.Count -eq 0) {
      return [PSCustomObject]@{
        OperationName   = $fn
        Application     = $Application
        Feature         = $Feature
        GitHandle       = $GitHandle
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
        [void]$PSCmdlet.ShouldProcess("$connectionDisplayName/$databaseName", 'Drop disposable database')
        [PSCustomObject]@{
          OperationName   = $fn
          Application     = $Application
          Feature         = $Feature
          GitHandle       = $GitHandle
          DatabaseName    = $databaseName
          SqlInstance     = $connectionDisplayName
          Dropped         = $false
          Success         = $true
          ResponseSummary = "would drop disposable database '$databaseName'"
        }
        continue
      }

      if ($PSCmdlet.ShouldProcess("$connectionDisplayName/$databaseName", 'Drop disposable database')) {
        if (-not $Force) {
          $message = "Drop disposable database '$databaseName' on '$connectionDisplayName'? Data is NOT backed up."
          if (-not $PSCmdlet.ShouldContinue($message, 'Confirm database drop')) {
            [PSCustomObject]@{
              OperationName   = $fn
              Application     = $Application
              Feature         = $Feature
              GitHandle       = $GitHandle
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
          GitHandle       = $GitHandle
          DatabaseName    = $databaseName
          SqlInstance     = $connectionDisplayName
          Dropped         = $true
          Success         = $true
          ResponseSummary = "dropped disposable database '$databaseName'"
        }
      }
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

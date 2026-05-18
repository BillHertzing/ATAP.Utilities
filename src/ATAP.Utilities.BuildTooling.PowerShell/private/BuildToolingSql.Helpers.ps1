function Import-BuildToolingDatabaseResolver {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string] $RepositoryRoot
  )

  if (Get-Command -Name 'Resolve-DatabaseSqlConnection' -CommandType Function -ErrorAction SilentlyContinue) {
    return
  }

  try {
    Import-Module ATAP.Utilities.DatabaseManagement.Powershell -ErrorAction Stop
    if (Get-Command -Name 'Resolve-DatabaseSqlConnection' -CommandType Function -ErrorAction SilentlyContinue) {
      return
    }
  }
  catch {
    # Fall through to source/package-layout imports below.
  }

  $candidateModuleRoots = @()
  if (-not [string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $candidateModuleRoots += Join-Path $RepositoryRoot 'src\ATAP.Utilities.DatabaseManagement.Powershell'
  }
  if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $moduleRoot = Split-Path -Parent $PSScriptRoot
    $sourceRoot = Split-Path -Parent $moduleRoot
    if (-not [string]::IsNullOrWhiteSpace($sourceRoot)) {
      $candidateModuleRoots += Join-Path $sourceRoot 'ATAP.Utilities.DatabaseManagement.Powershell'
    }

    $resolvedRepositoryRoot = (Resolve-Path -Path (Join-Path $moduleRoot '..\..') -ErrorAction SilentlyContinue).Path
    if (-not [string]::IsNullOrWhiteSpace($resolvedRepositoryRoot)) {
      $candidateModuleRoots += Join-Path $resolvedRepositoryRoot 'src\ATAP.Utilities.DatabaseManagement.Powershell'
    }
  }

  $lastImportError = $null
  foreach ($databaseModuleRoot in ($candidateModuleRoots | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
    $candidateModulePaths = @(
      (Join-Path $databaseModuleRoot 'ATAP.Utilities.DatabaseManagement.Powershell.psd1'),
      (Join-Path $databaseModuleRoot 'ATAP.Utilities.DatabaseManagement.Powershell.psm1')
    )

    foreach ($modulePath in ($candidateModulePaths | Select-Object -Unique)) {
      if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        continue
      }

      try {
        Import-Module -Name $modulePath -ErrorAction Stop
        if (Get-Command -Name 'Resolve-DatabaseSqlConnection' -CommandType Function -ErrorAction SilentlyContinue) {
          return
        }
      }
      catch {
        $lastImportError = $_
      }
    }
  }

  $errorSuffix = if ($null -ne $lastImportError) { " Last import error: $($lastImportError.Exception.Message)" } else { '' }
  throw "Resolve-DatabaseSqlConnection is not available. Import ATAP.Utilities.DatabaseManagement.Powershell, install it beside this module, or provide a repository root containing src\ATAP.Utilities.DatabaseManagement.Powershell.$errorSuffix"
}

function Split-BuildToolingSqlInstanceName {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string] $SqlInstance
  )

  if ([string]::IsNullOrWhiteSpace($SqlInstance)) {
    return [PSCustomObject]@{
      DatabaseHost = $null
      InstanceName = $null
    }
  }

  if ($SqlInstance -match '^([^\\]+)\\(.+)$') {
    return [PSCustomObject]@{
      DatabaseHost = $Matches[1]
      InstanceName = $Matches[2]
    }
  }

  return [PSCustomObject]@{
    DatabaseHost = $SqlInstance
    InstanceName = $null
  }
}

function Resolve-BuildToolingDatabaseSqlConnection {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [hashtable] $OriginalPSBoundParameters,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [object] $SqlConnection,

    [Parameter(Mandatory = $false)]
    [string] $BitwardenSecretName,

    [Parameter(Mandatory = $false)]
    [string] $DatabaseHost,

    [Parameter(Mandatory = $false)]
    [string] $SqlInstance,

    [Parameter(Mandatory = $false)]
    [string] $InstanceName,

    [Parameter(Mandatory = $false)]
    [string] $DatabaseName,

    [Parameter(Mandatory = $false)]
    [string] $ConnectionMethod,

    [Parameter(Mandatory = $false)]
    [string] $CredentialsKey,

    [Parameter(Mandatory = $false)]
    [string] $ApplicationName,

    [Parameter(Mandatory = $false)]
    [switch] $UseTrustedConnection,

    [Parameter(Mandatory = $false)]
    [switch] $IntegratedSecurity,

    [Parameter(Mandatory = $false)]
    [hashtable] $Settings,

    [Parameter(Mandatory = $false)]
    [string] $DefaultDatabaseHost,

    [Parameter(Mandatory = $false)]
    [string] $DefaultDatabaseName,

    [Parameter(Mandatory = $false)]
    [string] $DefaultApplicationName = 'ATAP.Utilities.BuildTooling.PowerShell',

    [Parameter(Mandatory = $false)]
    [string] $RepositoryRoot
  )

  Import-BuildToolingDatabaseResolver -RepositoryRoot $RepositoryRoot

  $effectiveDatabaseHost = if ([string]::IsNullOrWhiteSpace($DatabaseHost)) { $DefaultDatabaseHost } else { $DatabaseHost }
  $effectiveInstanceName = $InstanceName
  $effectiveDatabaseName = if ([string]::IsNullOrWhiteSpace($DatabaseName)) { $DefaultDatabaseName } else { $DatabaseName }
  $effectiveApplicationName = if ([string]::IsNullOrWhiteSpace($ApplicationName)) { $DefaultApplicationName } else { $ApplicationName }

  if (-not [string]::IsNullOrWhiteSpace($SqlInstance)) {
    $splitSqlInstance = Split-BuildToolingSqlInstanceName -SqlInstance $SqlInstance
    if (-not [string]::IsNullOrWhiteSpace($splitSqlInstance.InstanceName)) {
      if ([string]::IsNullOrWhiteSpace($DatabaseHost)) {
        $effectiveDatabaseHost = $splitSqlInstance.DatabaseHost
      }
      if ([string]::IsNullOrWhiteSpace($effectiveInstanceName)) {
        $effectiveInstanceName = $splitSqlInstance.InstanceName
      }
    }
    elseif ([string]::IsNullOrWhiteSpace($DatabaseHost)) {
      $effectiveDatabaseHost = $splitSqlInstance.DatabaseHost
    }
    elseif ([string]::IsNullOrWhiteSpace($effectiveInstanceName) -and $SqlInstance -ne $effectiveDatabaseHost) {
      $effectiveInstanceName = $SqlInstance
    }
  }

  $effectiveBoundParameters = @{}
  if ($OriginalPSBoundParameters) {
    foreach ($key in $OriginalPSBoundParameters.Keys) {
      $effectiveBoundParameters[$key] = $OriginalPSBoundParameters[$key]
    }
  }
  [void] $effectiveBoundParameters.Remove('SqlInstance')
  if (-not [string]::IsNullOrWhiteSpace($effectiveDatabaseHost)) {
    $effectiveBoundParameters['DatabaseHost'] = $effectiveDatabaseHost
  }
  if (-not [string]::IsNullOrWhiteSpace($effectiveInstanceName)) {
    $effectiveBoundParameters['InstanceName'] = $effectiveInstanceName
  }
  else {
    [void] $effectiveBoundParameters.Remove('InstanceName')
  }
  if (-not [string]::IsNullOrWhiteSpace($effectiveDatabaseName)) {
    $effectiveBoundParameters['DatabaseName'] = $effectiveDatabaseName
  }
  if (-not [string]::IsNullOrWhiteSpace($effectiveApplicationName)) {
    $effectiveBoundParameters['ApplicationName'] = $effectiveApplicationName
  }

  return Resolve-DatabaseSqlConnection `
    -OriginalPSBoundParameters $effectiveBoundParameters `
    -SqlConnection $SqlConnection `
    -BitwardenSecretName $BitwardenSecretName `
    -DatabaseHost $effectiveDatabaseHost `
    -InstanceName $effectiveInstanceName `
    -DatabaseName $effectiveDatabaseName `
    -ConnectionMethod $ConnectionMethod `
    -CredentialsKey $CredentialsKey `
    -ApplicationName $effectiveApplicationName `
    -UseTrustedConnection:$UseTrustedConnection `
    -IntegratedSecurity:$IntegratedSecurity `
    -Settings $Settings
}

function Invoke-BuildToolingSqlQuery {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [object] $SqlConnection,

    [Parameter(Mandatory = $true)]
    [string] $Query,

    [Parameter(Mandatory = $false)]
    [hashtable] $Parameters,

    [Parameter(Mandatory = $false)]
    [ValidateSet('DataTable', 'Scalar', 'NonQuery')]
    [string] $As = 'DataTable'
  )

  if ($null -eq $SqlConnection) {
    throw 'SqlConnection cannot be null.'
  }

  $command = $SqlConnection.CreateCommand()
  try {
    $command.CommandText = $Query

    if ($Parameters) {
      foreach ($parameterName in $Parameters.Keys) {
        $parameter = $command.CreateParameter()
        $parameter.ParameterName = if ($parameterName.StartsWith('@')) { $parameterName } else { "@$parameterName" }
        $value = $Parameters[$parameterName]
        $parameter.Value = if ($null -eq $value) { [DBNull]::Value } else { $value }
        [void] $command.Parameters.Add($parameter)
      }
    }

    switch ($As) {
      'Scalar' {
        return $command.ExecuteScalar()
      }
      'NonQuery' {
        return $command.ExecuteNonQuery()
      }
      default {
        $dataTable = [System.Data.DataTable]::new()
        $reader = $command.ExecuteReader()
        try {
          $dataTable.Load($reader)
        }
        finally {
          if ($null -ne $reader) {
            $reader.Dispose()
          }
        }
        return , $dataTable
      }
    }
  }
  finally {
    if ($null -ne $command) {
      $command.Dispose()
    }
  }
}

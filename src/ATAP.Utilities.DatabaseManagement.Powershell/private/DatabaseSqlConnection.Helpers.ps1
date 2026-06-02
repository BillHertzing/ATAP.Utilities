function Import-DatabaseSqlClientAssembly {
  [CmdletBinding()]
  param()

  $connectionTypeName = 'Microsoft.Data.SqlClient.SqlConnection'
  $connectionType = $connectionTypeName -as [type]
  if ($connectionType) {
    return $connectionType
  }

  try {
    Add-Type -AssemblyName 'Microsoft.Data.SqlClient' -ErrorAction Stop
  }
  catch {
    # dbatools ships and loads Microsoft.Data.SqlClient in many installed environments.
  }

  $connectionType = $connectionTypeName -as [type]
  if ($connectionType) {
    return $connectionType
  }

  try {
    if (Get-Module -ListAvailable -Name dbatools) {
      Import-Module dbatools -ErrorAction Stop
    }
  }
  catch {
    # Throw the clearer error below if the type is still unavailable.
  }

  $connectionType = $connectionTypeName -as [type]
  if ($connectionType) {
    return $connectionType
  }

  throw 'Microsoft.Data.SqlClient.SqlConnection is not available. Install Microsoft.Data.SqlClient or import a module that loads it, such as dbatools.'
}

function Assert-DatabaseSqlConnectionIsOpen {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [object] $Connection,

    [Parameter(Mandatory = $true)]
    [string] $Source
  )

  if ($null -eq $Connection) {
    throw "$Source did not provide a Microsoft.Data.SqlClient.SqlConnection."
  }

  $connectionType = Import-DatabaseSqlClientAssembly
  if ($Connection -isnot $connectionType) {
    throw "$Source provided '$($Connection.GetType().FullName)'. Expected Microsoft.Data.SqlClient.SqlConnection."
  }

  if ($Connection.State -ne [System.Data.ConnectionState]::Open) {
    throw "$Source provided a SqlConnection, but its State is '$($Connection.State)' instead of 'Open'."
  }

  return $Connection
}

function New-DatabaseSqlConnectionFromConnectionString {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $ConnectionString,

    [Parameter(Mandatory = $true)]
    [string] $Source
  )

  if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    throw "$Source returned an empty connection string."
  }

  $connectionType = Import-DatabaseSqlClientAssembly
  $connection = $null

  try {
    $connection = [Activator]::CreateInstance($connectionType, @($ConnectionString))
  }
  catch {
    throw "$Source returned a value that could not be used to create a Microsoft.Data.SqlClient.SqlConnection. $($_.Exception.Message)"
  }

  try {
    $connection.Open()
  }
  catch {
    if ($null -ne $connection) {
      $connection.Dispose()
    }
    throw "$Source returned a connection string, but opening the SQL connection failed. $($_.Exception.Message)"
  }

  return Assert-DatabaseSqlConnectionIsOpen -Connection $connection -Source $Source
}

function Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $SecretName
  )

  if ([string]::IsNullOrWhiteSpace($SecretName)) {
    throw 'DBConnectionStringSecretName cannot be null, empty, or whitespace.'
  }

  if (-not (Get-Command -Name 'Get-SecretATAP' -ErrorAction SilentlyContinue)) {
    throw "Get-SecretATAP is not available. Import ATAP.Utilities.BuildTooling.PowerShell or ensure Get-SecretATAP is on the function path."
  }

  $DBConnectionString = Get-SecretATAP -SecretName $SecretName -SecretField 'notes'

  if ($DBConnectionString -is [array]) {
    if ($DBConnectionString.Count -ne 1) {
      throw "ATAP secret '$SecretName' notes field returned multiple values. Expected exactly one connection string."
    }
    $DBConnectionString = $DBConnectionString[0]
  }

  if ($null -eq $DBConnectionString) {
    throw "ATAP secret '$SecretName' notes field returned null. Expected a connection-string value."
  }

  if ($DBConnectionString -isnot [string]) {
    throw "ATAP secret '$SecretName' notes field returned '$($DBConnectionString.GetType().FullName)'. Expected a string."
  }

  return New-DatabaseSqlConnectionFromConnectionString `
    -ConnectionString $DBConnectionString `
    -Source "ATAP secret '$SecretName' (notes field)"
}


function Import-DatabaseConnectionHelperFunctions {
  [CmdletBinding()]
  param()

  if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
    $powerShellModuleRoots = @()
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
      $databaseModuleRoot = Split-Path -Parent $PSScriptRoot
      $sourceRoot = Split-Path -Parent $databaseModuleRoot
      if (-not [string]::IsNullOrWhiteSpace($sourceRoot)) {
        $powerShellModuleRoots += Join-Path $sourceRoot 'ATAP.Utilities.PowerShell'
        $powerShellModuleRoots += Join-Path $sourceRoot 'ATAP.Utilities.Powershell'
      }
    }

    Import-DatabaseScriptCommand `
      -CommandName 'Get-ParameterValueFromNeoConfigurationRoot' `
      -ModuleNames @('ATAP.Utilities.PowerShell', 'ATAP.Utilities.Powershell') `
      -ModuleRoots $powerShellModuleRoots `
      -RelativeScriptPath 'public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
  }

  if (-not (Get-Command -Name 'New-ConnectionStringBuilderFromDbaTools' -CommandType Function -ErrorAction SilentlyContinue)) {
    $databaseModuleRoots = @()
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
      $databaseModuleRoots += Split-Path -Parent $PSScriptRoot
    }

    Import-DatabaseScriptCommand `
      -CommandName 'New-ConnectionStringBuilderFromDbaTools' `
      -ModuleNames @('ATAP.Utilities.DatabaseManagement.Powershell') `
      -ModuleRoots $databaseModuleRoots `
      -RelativeScriptPath 'public\New-ConnectionStringBuilderFromDbaTools.ps1'
  }
}

function Import-DatabaseScriptCommand {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $CommandName,

    [Parameter(Mandatory = $false)]
    [string[]] $ModuleNames,

    [Parameter(Mandatory = $false)]
    [string[]] $ModuleRoots,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $RelativeScriptPath
  )

  if (Get-Command -Name $CommandName -CommandType Function -ErrorAction SilentlyContinue) {
    return
  }

  $candidateScriptPaths = @()

  foreach ($moduleName in ($ModuleNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
    foreach ($moduleInfo in (Get-Module -ListAvailable -Name $moduleName -ErrorAction SilentlyContinue)) {
      if (-not [string]::IsNullOrWhiteSpace($moduleInfo.ModuleBase)) {
        $candidateScriptPaths += Join-Path $moduleInfo.ModuleBase $RelativeScriptPath
      }
    }
  }

  foreach ($moduleRoot in ($ModuleRoots | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
    $candidateScriptPaths += Join-Path $moduleRoot $RelativeScriptPath
  }

  $lastImportError = $null
  foreach ($scriptPath in ($candidateScriptPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
      continue
    }

    try {
      . $scriptPath
      $command = Get-Command -Name $CommandName -CommandType Function -ErrorAction SilentlyContinue
      if ($command) {
        Set-Item -Path "Function:script:$CommandName" -Value $command.ScriptBlock -Force
        return
      }
    }
    catch {
      $lastImportError = $_
    }
  }

  $errorSuffix = if ($null -ne $lastImportError) { " Last import error: $($lastImportError.Exception.Message)" } else { '' }
  throw "$CommandName is not available. Install the required ATAP.Utilities module or keep the dependent modules beside this module in the source/package layout.$errorSuffix"
}

function New-DatabaseConnectionParameterMap {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [hashtable] $BoundParameters
  )

  $result = @{}
  if ($BoundParameters) {
    foreach ($key in $BoundParameters.Keys) {
      $result[$key] = $BoundParameters[$key]
    }
  }

  $aliasesByCanonicalName = @{
    DBConnectionStringSecretName = @('DBConnectionStringSecret', 'SecretName', 'BitwardenSecretName', 'BitwardenSecret')
    DatabaseHost                 = @('HostName', 'ServerInstance')
    InstanceName                 = @('SqlInstance')
  }

  foreach ($canonicalName in $aliasesByCanonicalName.Keys) {
    if ($result.ContainsKey($canonicalName)) {
      continue
    }

    foreach ($aliasName in $aliasesByCanonicalName[$canonicalName]) {
      if ($result.ContainsKey($aliasName)) {
        $result[$canonicalName] = $result[$aliasName]
        break
      }
    }
  }

  return , $result
}

function Invoke-DatabaseConnectionGetPVal {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $ParameterName,

    [Parameter(Mandatory = $true)]
    [hashtable] $BoundParameters,

    [Parameter(Mandatory = $false)]
    [string] $DottedPath,

    [Parameter(Mandatory = $false)]
    [hashtable] $Settings,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [object] $DefaultValue,

    [Parameter(Mandatory = $false)]
    [switch] $AllowMissing,

    [Parameter(Mandatory = $false)]
    [type] $AsType,

    [Parameter(Mandatory = $false)]
    [string[]] $ValidValues
  )

  $getPValParameters = @{
    ParameterName             = $ParameterName
    originalPSBoundParameters = $BoundParameters
    AllowMissing              = $AllowMissing
  }

  if (-not [string]::IsNullOrWhiteSpace($DottedPath)) {
    $getPValParameters['dottedPath'] = $DottedPath
  }
  if ($null -ne $Settings) {
    $getPValParameters['Settings'] = $Settings
  }
  if ($PSBoundParameters.ContainsKey('DefaultValue')) {
    $getPValParameters['DefaultValue'] = $DefaultValue
  }
  if ($null -ne $AsType) {
    $getPValParameters['AsType'] = $AsType
  }
  if ($ValidValues -and $ValidValues.Count -gt 0) {
    $getPValParameters['ValidValues'] = $ValidValues
  }

  return Get-ParameterValueFromNeoConfigurationRoot @getPValParameters
}

function Resolve-DatabaseSqlConnectionFromConnectionParts {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [hashtable] $BoundParameters,

    [Parameter(Mandatory = $false)]
    [hashtable] $Settings,

    [Parameter(Mandatory = $false)]
    [string] $DatabaseHost,

    [Parameter(Mandatory = $false)]
    [string] $DatabaseName,

    [Parameter(Mandatory = $false)]
    [string] $ConnectionMethod,

    [Parameter(Mandatory = $false)]
    [string] $CredentialsKey,

    [Parameter(Mandatory = $false)]
    [string] $ApplicationName,

    [Parameter(Mandatory = $false)]
    [string] $InstanceName,

    [Parameter(Mandatory = $false)]
    [bool] $IntegratedSecurity,

    [Parameter(Mandatory = $false)]
    [bool] $UseTrustedConnection,

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

  Import-DatabaseConnectionHelperFunctions

  $databaseHostDefault = if ([string]::IsNullOrWhiteSpace($DatabaseHost)) { $null } else { $DatabaseHost }
  $databaseNameDefault = if ([string]::IsNullOrWhiteSpace($DatabaseName)) { $null } else { $DatabaseName }
  $connectionMethodDefault = if ([string]::IsNullOrWhiteSpace($ConnectionMethod)) { $null } else { $ConnectionMethod }
  $credentialsKeyDefault = if ([string]::IsNullOrWhiteSpace($CredentialsKey)) { $null } else { $CredentialsKey }
  $instanceNameDefault = if ([string]::IsNullOrWhiteSpace($InstanceName)) { $null } else { $InstanceName }

  $resolvedDatabaseHost = Invoke-DatabaseConnectionGetPVal `
    -ParameterName 'DatabaseHost' `
    -BoundParameters $BoundParameters `
    -DottedPath $DatabaseHostDottedPath `
    -Settings $Settings `
    -DefaultValue $databaseHostDefault `
    -AllowMissing:$false `
    -AsType ([string])

  $resolvedDatabaseName = Invoke-DatabaseConnectionGetPVal `
    -ParameterName 'DatabaseName' `
    -BoundParameters $BoundParameters `
    -DottedPath $DatabaseNameDottedPath `
    -Settings $Settings `
    -DefaultValue $databaseNameDefault `
    -AllowMissing:$false `
    -AsType ([string])

  if ([string]::IsNullOrWhiteSpace($resolvedDatabaseHost)) {
    throw 'DatabaseHost resolved to null, empty, or whitespace.'
  }

  if ([string]::IsNullOrWhiteSpace($resolvedDatabaseName)) {
    throw 'DatabaseName resolved to null, empty, or whitespace.'
  }

  $resolvedConnectionMethod = Invoke-DatabaseConnectionGetPVal `
    -ParameterName 'ConnectionMethod' `
    -BoundParameters $BoundParameters `
    -DottedPath $ConnectionMethodDottedPath `
    -Settings $Settings `
    -DefaultValue $connectionMethodDefault `
    -AllowMissing:$true `
    -AsType ([string]) `
    -ValidValues @('default', 'tcp', 'np', 'lpc')

  $resolvedCredentialsKey = Invoke-DatabaseConnectionGetPVal `
    -ParameterName 'CredentialsKey' `
    -BoundParameters $BoundParameters `
    -DottedPath $CredentialsKeyDottedPath `
    -Settings $Settings `
    -DefaultValue $credentialsKeyDefault `
    -AllowMissing:$true `
    -AsType ([string])

  $resolvedApplicationName = Invoke-DatabaseConnectionGetPVal `
    -ParameterName 'ApplicationName' `
    -BoundParameters $BoundParameters `
    -DottedPath $ApplicationNameDottedPath `
    -Settings $Settings `
    -DefaultValue $(if ([string]::IsNullOrWhiteSpace($ApplicationName)) { 'ATAP.Utilities' } else { $ApplicationName }) `
    -AllowMissing:$true `
    -AsType ([string])

  $resolvedInstanceName = Invoke-DatabaseConnectionGetPVal `
    -ParameterName 'InstanceName' `
    -BoundParameters $BoundParameters `
    -DottedPath $InstanceNameDottedPath `
    -Settings $Settings `
    -DefaultValue $instanceNameDefault `
    -AllowMissing:$true `
    -AsType ([string])

  $resolvedIntegratedSecurity = Invoke-DatabaseConnectionGetPVal `
    -ParameterName 'IntegratedSecurity' `
    -BoundParameters $BoundParameters `
    -DottedPath $IntegratedSecurityDottedPath `
    -Settings $Settings `
    -DefaultValue $IntegratedSecurity `
    -AllowMissing:$true `
    -AsType ([bool])

  $resolvedUseTrustedConnection = Invoke-DatabaseConnectionGetPVal `
    -ParameterName 'UseTrustedConnection' `
    -BoundParameters $BoundParameters `
    -DottedPath $UseTrustedConnectionDottedPath `
    -Settings $Settings `
    -DefaultValue $UseTrustedConnection `
    -AllowMissing:$true `
    -AsType ([bool])

  $builderParameters = @{
    DatabaseHost    = $resolvedDatabaseHost
    DatabaseName    = $resolvedDatabaseName
    ApplicationName = $resolvedApplicationName
  }

  if (-not [string]::IsNullOrWhiteSpace($resolvedConnectionMethod) -and $resolvedConnectionMethod -ne 'default') {
    $builderParameters['ConnectionMethod'] = $resolvedConnectionMethod
  }

  if (-not [string]::IsNullOrWhiteSpace($resolvedInstanceName)) {
    $builderParameters['SqlInstance'] = $resolvedInstanceName
  }

  if (-not [string]::IsNullOrWhiteSpace($resolvedCredentialsKey)) {
    $builderParameters['CredentialsKey'] = $resolvedCredentialsKey
  }
  elseif ($resolvedIntegratedSecurity -or $resolvedUseTrustedConnection) {
    $builderParameters['IntegratedSecurity'] = $true
  }
  else {
    throw 'ConnectionParts requires either CredentialsKey or IntegratedSecurity/UseTrustedConnection after Get-PVal resolution.'
  }

  $connectionStringBuilder = New-ConnectionStringBuilderFromDbaTools @builderParameters
  $connectionString = $connectionStringBuilder.ToString()

  return New-DatabaseSqlConnectionFromConnectionString `
    -ConnectionString $connectionString `
    -Source 'ConnectionParts'
}

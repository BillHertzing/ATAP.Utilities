function Reset-SprintDatabases {
  <#
  .SYNOPSIS
    Drops, recreates, and migrates sprint databases inside existing per-developer SQL Server instances.
  .DESCRIPTION
    Resets the sprint databases in the permanent per-developer SQL Server named
    instances used by the sprint lifecycle:

      - Dev<developer>
      - Exp<developer>

    The cmdlet does not create, install, uninstall, or delete SQL Server
    instances. It first verifies that every requested instance already exists,
    then delegates each database reset to Build-DatabaseWithFlyway with -Force so
    the database is rebuilt from scratch and Flyway migrations are applied.

    If any requested instance is missing, the cmdlet fails before resetting any
    database and reports onboarding remediation text.

    -WhatIf and -DryRun are true no-op paths: they still perform the instance
    preflight, but they do not call Build-DatabaseWithFlyway or perform
    destructive database work.
  .PARAMETER DeveloperNames
    Developer names used to derive Dev<developer> and Exp<developer> instance
    names. Defaults to Sprint.DeveloperNames from global settings when
    available, otherwise $env:USERNAME.
  .PARAMETER InstanceNames
    Explicit SQL Server named-instance names to reset. When supplied, this
    overrides DeveloperNames-derived instance names. Entries may be strings, or
    hashtables/objects with InstanceName plus optional per-instance secret-name
    fields such as DBConnectionStringMasterSecretName or SQLConnectionSecretName.
  .PARAMETER Databases
    Database names to reset on every instance. Defaults to ATAPUtilities and
    AceCommander.
  .PARAMETER DatabaseHost
    SQL Server host address. Defaults to localhost.
  .PARAMETER ConnectionMethod
    Connection protocol passed to Build-DatabaseWithFlyway. Defaults to tcp.
  .PARAMETER FlywayBasePath
    Root folder containing flyway.toml and SQL migrations. Defaults to
    <RepositoryRoot>\Database\Flyway, or global settings when available.
  .PARAMETER RepositoryRoot
    Root of the ATAP.Utilities repository worktree. Defaults to three levels
    above this script's location.
  .PARAMETER DryRun
    Performs preflight only and returns the reset plan without calling
    Build-DatabaseWithFlyway.
  .PARAMETER Force
    Bypasses confirmation prompts for non-interactive automation. Does not
    override -WhatIf.
  .OUTPUTS
    PSCustomObject[] with one row per instance/database pair.
  .EXAMPLE
    Reset-SprintDatabases -Confirm:$false
  .EXAMPLE
    Reset-SprintDatabases -DryRun
  .EXAMPLE
    Reset-SprintDatabases -WhatIf
  .LINK
    Build-DatabaseWithFlyway
  .LINK
    New-DeveloperSqlServerInstances
  .LINK
    Remove-DeveloperSqlServerInstances
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  param(
    [Parameter(Mandatory = $false)]
    [string[]]$DeveloperNames,

    [Parameter(Mandatory = $false)]
    [object[]]$InstanceNames,

    [Parameter(Mandatory = $false)]
    [string[]]$Databases,

    [Parameter(Mandatory = $false)]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $false)]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false)]
    [string]$CredentialsKey,

    [Parameter(Mandatory = $false)]
    [Alias('DBConnectionStringSecret', 'SecretName', 'BitwardenSecretName', 'BitwardenSecret')]
    [string]$DBConnectionStringSecretName,

    [Parameter(Mandatory = $false)]
    [Alias('DBConnectionStringMasterSecret', 'MasterSecretName', 'DBMasterConnectionStringSecretName')]
    [string]$DBConnectionStringMasterSecretName,

    [Parameter(Mandatory = $false)]
    [Alias('DBConnectionStringDatabaseSecretName', 'DBConnectionStringDatabaseSecret', 'DatabaseSecretName', 'DBSecretName')]
    [string]$DBConnectionStringDBSecretName,

    [Parameter(Mandatory = $false)]
    [string]$ApplicationName,

    [Parameter(Mandatory = $false)]
    [switch]$UseTrustedConnection,

    [Parameter(Mandatory = $false)]
    [switch]$IntegratedSecurity,

    [Parameter(Mandatory = $false)]
    [hashtable]$Settings,

    [Parameter(Mandatory = $false)]
    [string]$FlywayBasePath,

    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Force
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    if ($Force) {
      $ConfirmPreference = 'None'
    }

    if (-not $PSBoundParameters.ContainsKey('Databases') -or $null -eq $Databases -or $Databases.Count -eq 0) {
      $Databases = @('ATAPUtilities', 'AceCommander')
    }
    $Databases = @($Databases | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($Databases.Count -eq 0) {
      throw 'At least one database name is required.'
    }

    function Get-ResetSprintInputValue {
      param(
        [AllowNull()]
        [object]$InputObject,
        [Parameter(Mandatory = $true)]
        [string[]]$Names
      )

      if ($null -eq $InputObject) {
        return $null
      }

      if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($name in $Names) {
          foreach ($key in $InputObject.Keys) {
            if ([string]::Equals([string]$key, $name, [System.StringComparison]::OrdinalIgnoreCase)) {
              return $InputObject[$key]
            }
          }
        }
        return $null
      }

      foreach ($name in $Names) {
        $property = $InputObject.PSObject.Properties |
          Where-Object { [string]::Equals($_.Name, $name, [System.StringComparison]::OrdinalIgnoreCase) } |
          Select-Object -First 1
        if ($null -ne $property) {
          return $property.Value
        }
      }

      return $null
    }

    $instanceMasterSecretNamesByName = @{}
    $instanceDBSecretNamesByName = @{}

    if ($PSBoundParameters.ContainsKey('InstanceNames') -and $null -ne $InstanceNames -and $InstanceNames.Count -gt 0) {
      $normalizedInstanceNames = [System.Collections.Generic.List[string]]::new()
      foreach ($instanceInput in @($InstanceNames)) {
        if ($null -eq $instanceInput) {
          continue
        }

        $instanceName = if ($instanceInput -is [string]) {
          [string]$instanceInput
        } else {
          [string](Get-ResetSprintInputValue -InputObject $instanceInput -Names @('InstanceName', 'SqlInstance', 'Name'))
        }

        if ([string]::IsNullOrWhiteSpace($instanceName)) {
          throw 'Each non-string InstanceNames entry must include InstanceName, SqlInstance, or Name.'
        }

        if (-not $normalizedInstanceNames.Contains($instanceName)) {
          [void]$normalizedInstanceNames.Add($instanceName)
        }

        if ($instanceInput -isnot [string]) {
          $instanceMasterSecretName = [string](Get-ResetSprintInputValue -InputObject $instanceInput -Names @(
              'DBConnectionStringMasterSecretName',
              'DBConnectionStringMasterSecret',
              'DBMasterConnectionStringSecretName',
              'MasterConnectionStringSecretName',
              'MasterSecretName',
              'SQLConnectionSecretName',
              'DBConnectionStringSecretName',
              'SecretName',
              'BitwardenSecretName',
              'BitwardenSecret'
            ))
          if (-not [string]::IsNullOrWhiteSpace($instanceMasterSecretName)) {
            $instanceMasterSecretNamesByName[$instanceName] = $instanceMasterSecretName
          }

          $instanceDBSecretName = [string](Get-ResetSprintInputValue -InputObject $instanceInput -Names @(
              'DBConnectionStringDBSecretName',
              'DBConnectionStringDatabaseSecretName',
              'DBConnectionStringDatabaseSecret',
              'DatabaseConnectionStringSecretName',
              'DatabaseSecretName',
              'DBSecretName'
            ))
          if (-not [string]::IsNullOrWhiteSpace($instanceDBSecretName)) {
            $instanceDBSecretNamesByName[$instanceName] = $instanceDBSecretName
          }
        }
      }

      $InstanceNames = $normalizedInstanceNames.ToArray()
    }

    if (-not $PSBoundParameters.ContainsKey('InstanceNames') -or $null -eq $InstanceNames -or $InstanceNames.Count -eq 0) {
      if (-not $PSBoundParameters.ContainsKey('DeveloperNames') -or $null -eq $DeveloperNames -or $DeveloperNames.Count -eq 0) {
        $settingsKey = if ($global:configRootKeys -and $global:configRootKeys['SprintDeveloperNamesConfigRootKey']) {
          $global:configRootKeys['SprintDeveloperNamesConfigRootKey']
        } else {
          'Sprint.DeveloperNames'
        }

        if (Get-Command -Name 'Get-PVal' -ErrorAction SilentlyContinue) {
          try {
            $DeveloperNames = Get-PVal `
              -ParameterName 'DeveloperNames' `
              -originalPSBoundParameters $PSBoundParameters `
              -dottedPath $settingsKey `
              -DefaultValue @($env:USERNAME) `
              -AllowMissing
          } catch {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
              -Message "Optional DeveloperNames lookup failed; falling back to env:USERNAME. Exception: $($_.Exception.Message)"
            $DeveloperNames = @($env:USERNAME)
          }
        }

        if (-not $DeveloperNames) {
          $DeveloperNames = @($env:USERNAME)
        }
      }

      $DeveloperNames = @($DeveloperNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
      if ($DeveloperNames.Count -eq 0) {
        throw 'At least one developer name is required to derive sprint SQL Server instance names.'
      }

      $resolvedInstanceNames = [System.Collections.Generic.List[string]]::new()
      foreach ($developer in $DeveloperNames) {
        $resolvedInstanceNames.Add("Dev$developer")
        $resolvedInstanceNames.Add("Exp$developer")
      }
      $InstanceNames = $resolvedInstanceNames.ToArray()
    }

    $InstanceNames = @($InstanceNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($InstanceNames.Count -eq 0) {
      throw 'At least one SQL Server instance name is required.'
    }

    if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
      $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..') -ErrorAction SilentlyContinue)?.Path
      if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        throw 'RepositoryRoot could not be determined from $PSScriptRoot.'
      }
    }

    $databasesCollection = if ($Settings) {
      $Settings
    }
    elseif ($global:settings -and $global:configRootKeys -and $global:configRootKeys['DatabasesCollectionConfigRootKey']) {
      $global:settings[$global:configRootKeys['DatabasesCollectionConfigRootKey']]
    }
    elseif ($global:settings -is [System.Collections.IDictionary] -and $global:settings.Contains('DatabasesCollection')) {
      $global:settings['DatabasesCollection']
    }
    elseif ($global:settings -and $global:settings.PSObject.Properties['DatabasesCollection']) {
      $global:settings.DatabasesCollection
    }
    else {
      $null
    }

    $resetBoundParameters = @{}
    foreach ($key in $PSBoundParameters.Keys) {
      $resetBoundParameters[$key] = $PSBoundParameters[$key]
    }

    $isNoOp = [bool]($DryRun -or $WhatIfPreference)
    $buildDatabaseWithFlywayParameters = $null
    if (-not $isNoOp) {
      if (-not (Get-Command -Name 'Build-DatabaseWithFlyway' -CommandType Function -ErrorAction SilentlyContinue)) {
        $buildDbPath = Join-Path $RepositoryRoot 'src' 'ATAP.Utilities.DatabaseManagement.Powershell' 'public' 'Build-DatabaseWithFlyway.ps1'
        if (-not (Test-Path -LiteralPath $buildDbPath -PathType Leaf)) {
          throw "Build-DatabaseWithFlyway.ps1 not found at: $buildDbPath"
        }
        try {
          Import-Module -Name dbatools -ErrorAction Stop
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message 'Imported dbatools before loading Build-DatabaseWithFlyway.'
        } catch {
          $errorMessage = "Failed to import dbatools before loading Build-DatabaseWithFlyway. dbatools must be loaded first because Build-DatabaseWithFlyway declares a Microsoft.Data.SqlClient.SqlConnection parameter. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }

        try {
          . $buildDbPath
        } catch {
          $errorMessage = "Failed to load Build-DatabaseWithFlyway from '$buildDbPath' after importing dbatools. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
          -Message "Loaded Build-DatabaseWithFlyway from $buildDbPath"
      }

      $buildDatabaseWithFlywayParameters = (Get-Command -Name 'Build-DatabaseWithFlyway' -CommandType Function).Parameters.Keys
    }

    $getPValAvailable = [bool](Get-Command -Name 'Get-PVal' -ErrorAction SilentlyContinue)
    function Resolve-ResetSprintDatabaseSetting {
      param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$DottedPath,
        [AllowNull()]
        [object]$DefaultValue = $null,
        [switch]$AllowMissing,
        [type]$AsType
      )

      if (-not $getPValAvailable) {
        return $DefaultValue
      }

      $getPValParams = @{
        ParameterName             = $Name
        originalPSBoundParameters = $resetBoundParameters
        dottedPath                = $DottedPath
        Settings                  = $databasesCollection
        DefaultValue              = $DefaultValue
        AllowMissing              = $AllowMissing
      }
      if ($null -ne $AsType) {
        $getPValParams['AsType'] = $AsType
      }

      try {
        Get-PVal @getPValParams
      } catch {
        if ($AllowMissing -or $PSBoundParameters.ContainsKey('DefaultValue')) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message "Optional setting '$Name' at '$DottedPath' was not resolved; using default. Exception: $($_.Exception.Message)"
          return $DefaultValue
        }
        throw
      }
    }

    function Resolve-ResetSprintInstanceSecretName {
      param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceName,
        [Parameter(Mandatory = $true)]
        [string]$Environment,
        [Parameter(Mandatory = $true)]
        [ValidateSet('DBConnectionStringMasterSecretName', 'DBConnectionStringDBSecretName')]
        [string]$Name,
        [AllowNull()]
        [object]$DefaultValue = $null
      )

      $explicitMap = if ($Name -eq 'DBConnectionStringMasterSecretName') {
        $instanceMasterSecretNamesByName
      } else {
        $instanceDBSecretNamesByName
      }

      if ($explicitMap.ContainsKey($InstanceName) -and -not [string]::IsNullOrWhiteSpace([string]$explicitMap[$InstanceName])) {
        return [string]$explicitMap[$InstanceName]
      }

      foreach ($dottedPath in @(
          "Instances.$InstanceName.$Name",
          "SqlInstances.$InstanceName.$Name",
          "SQLInstances.$InstanceName.$Name",
          "SQLServerInstances.$InstanceName.$Name",
          "InstanceNames.$InstanceName.$Name",
          "$InstanceName.$Name",
          "$Environment.$Name"
        )) {
        $candidate = Resolve-ResetSprintDatabaseSetting `
          -Name $Name `
          -DottedPath $dottedPath `
          -DefaultValue $null `
          -AllowMissing `
          -AsType ([string])
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
          return $candidate
        }
      }

      return $DefaultValue
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Instances: $($InstanceNames -join ', ') | Databases: $($Databases -join ', ') | Host: $(if ([string]::IsNullOrWhiteSpace($DatabaseHost)) { '<settings>' } else { $DatabaseHost }) | DryRun: $DryRun"
  }

  process {
    $results = [System.Collections.Generic.List[object]]::new()
    $missingInstances = [System.Collections.Generic.List[string]]::new()

    foreach ($instanceName in $InstanceNames) {
      $serviceName = "MSSQL`$$instanceName"
      $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
      if ($null -eq $existingService) {
        $missingInstances.Add("$instanceName (service $serviceName)")
      }
    }

    if ($missingInstances.Count -gt 0) {
      $message = "Required SQL Server instance(s) not found: $($missingInstances -join ', '). " +
      'Run the developer onboarding SQL Server instance setup for this workstation, then rerun Reset-SprintDatabases. ' +
      'This cmdlet only resets databases; it never creates or removes SQL Server instances.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message
      throw $message
    }

    foreach ($instanceName in $InstanceNames) {
      $environment = if ($instanceName.StartsWith('Dev')) { 'Development' }
      elseif ($instanceName.StartsWith('Exp')) { 'Experimental' }
      else { $instanceName }

      $resolvedInstanceDBConnectionStringMasterSecretName = Resolve-ResetSprintInstanceSecretName `
        -InstanceName $instanceName `
        -Environment $environment `
        -Name 'DBConnectionStringMasterSecretName' `
        -DefaultValue $DBConnectionStringMasterSecretName

      $resolvedInstanceDBConnectionStringDBSecretName = Resolve-ResetSprintInstanceSecretName `
        -InstanceName $instanceName `
        -Environment $environment `
        -Name 'DBConnectionStringDBSecretName' `
        -DefaultValue $DBConnectionStringDBSecretName

      foreach ($db in $Databases) {
        $resolvedDatabaseHost = Resolve-ResetSprintDatabaseSetting `
          -Name 'DatabaseHost' `
          -DottedPath "$db.$environment.DatabaseHost" `
          -DefaultValue $DatabaseHost `
          -AllowMissing `
          -AsType ([string])
        if ([string]::IsNullOrWhiteSpace($resolvedDatabaseHost)) {
          $resolvedDatabaseHost = 'localhost'
        }

        $resolvedConnectionMethod = Resolve-ResetSprintDatabaseSetting `
          -Name 'ConnectionMethod' `
          -DottedPath "$db.$environment.ConnectionMethod" `
          -DefaultValue $ConnectionMethod `
          -AllowMissing `
          -AsType ([string])

        $resolvedDBConnectionStringSecretName = Resolve-ResetSprintDatabaseSetting `
          -Name 'DBConnectionStringSecretName' `
          -DottedPath "$db.$environment.DBConnectionStringSecretName" `
          -DefaultValue $DBConnectionStringSecretName `
          -AllowMissing `
          -AsType ([string])

        $resolvedDBConnectionStringMasterSecretName = Resolve-ResetSprintDatabaseSetting `
          -Name 'DBConnectionStringMasterSecretName' `
          -DottedPath "$db.$environment.DBConnectionStringMasterSecretName" `
          -DefaultValue $resolvedInstanceDBConnectionStringMasterSecretName `
          -AllowMissing `
          -AsType ([string])
        if ([string]::IsNullOrWhiteSpace($resolvedDBConnectionStringMasterSecretName)) {
          $resolvedDBConnectionStringMasterSecretName = $resolvedDBConnectionStringSecretName
        }

        $resolvedDBConnectionStringDBSecretName = Resolve-ResetSprintDatabaseSetting `
          -Name 'DBConnectionStringDBSecretName' `
          -DottedPath "$db.$environment.DBConnectionStringDBSecretName" `
          -DefaultValue $resolvedInstanceDBConnectionStringDBSecretName `
          -AllowMissing `
          -AsType ([string])
        if ([string]::IsNullOrWhiteSpace($resolvedDBConnectionStringDBSecretName)) {
          $resolvedDBConnectionStringDBSecretName = $resolvedDBConnectionStringSecretName
        }

        $resolvedCredentialsKey = Resolve-ResetSprintDatabaseSetting `
          -Name 'CredentialsKey' `
          -DottedPath "$db.$environment.CredentialsKey" `
          -DefaultValue $CredentialsKey `
          -AllowMissing `
          -AsType ([string])

        $resolvedApplicationName = Resolve-ResetSprintDatabaseSetting `
          -Name 'ApplicationName' `
          -DottedPath "$db.$environment.ApplicationName" `
          -DefaultValue $ApplicationName `
          -AllowMissing `
          -AsType ([string])

        $resolvedDatabasePath = Resolve-ResetSprintDatabaseSetting `
          -Name 'DatabasePath' `
          -DottedPath "$db.$environment.DatabasePath" `
          -DefaultValue $null `
          -AllowMissing `
          -AsType ([string])

        $resolvedProvisioningScriptsPath = Resolve-ResetSprintDatabaseSetting `
          -Name 'ProvisioningScriptsPath' `
          -DottedPath "$db.$environment.ProvisioningScriptsPath" `
          -DefaultValue $null `
          -AllowMissing `
          -AsType ([string])

        $resolvedFlywayBasePath = Resolve-ResetSprintDatabaseSetting `
          -Name 'FlywayBasePath' `
          -DottedPath "$db.$environment.FlywayBasePath" `
          -DefaultValue $FlywayBasePath `
          -AllowMissing `
          -AsType ([string])
        if ([string]::IsNullOrWhiteSpace($resolvedFlywayBasePath)) {
          $resolvedFlywayBasePath = Join-Path $RepositoryRoot 'Database' 'Flyway'
        }

        $resolvedFlywaySqlMigrationsPath = Resolve-ResetSprintDatabaseSetting `
          -Name 'FlywaySqlMigrationsPath' `
          -DottedPath "$db.$environment.FlywaySqlMigrationsPath" `
          -DefaultValue $(Join-Path $resolvedFlywayBasePath 'SQL') `
          -AllowMissing `
          -AsType ([string])

        $resolvedFlywaySharedSqlMigrationsPath = Resolve-ResetSprintDatabaseSetting `
          -Name 'FlywaySharedSqlMigrationsPath' `
          -DottedPath "$db.$environment.FlywaySharedSqlMigrationsPath" `
          -DefaultValue $null `
          -AllowMissing `
          -AsType ([string])

        $resolvedFlywayTomlPath = Resolve-ResetSprintDatabaseSetting `
          -Name 'FlywayTomlPath' `
          -DottedPath "$db.$environment.FlywayTomlPath" `
          -DefaultValue $(Join-Path $resolvedFlywayBasePath 'flyway.toml') `
          -AllowMissing `
          -AsType ([string])

        $usingConnectionStringSecret =
          (-not [string]::IsNullOrWhiteSpace($resolvedDBConnectionStringMasterSecretName)) -or
          (-not [string]::IsNullOrWhiteSpace($resolvedDBConnectionStringDBSecretName))
        $targetSecretName = if (-not [string]::IsNullOrWhiteSpace($resolvedDBConnectionStringMasterSecretName)) {
          $resolvedDBConnectionStringMasterSecretName
        } else {
          $resolvedDBConnectionStringDBSecretName
        }
        $targetHost = if ($usingConnectionStringSecret) {
          "<secret:$targetSecretName>"
        } elseif ([string]::IsNullOrWhiteSpace($resolvedDatabaseHost)) {
          '<settings>'
        } else {
          $resolvedDatabaseHost
        }
        $target = "$targetHost\$instanceName\$db"

        $entry = [ordered]@{
          instanceName  = $instanceName
          database      = $db
          environment   = $environment
          instanceReady = $true
          reset         = $false
          migrated      = $false
          dryRun        = [bool]$DryRun
          skipped       = $false
          error         = $null
        }

        if ($DryRun) {
          $entry.skipped = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "DryRun: would reset database '$db' on instance '$instanceName'."
          $results.Add([PSCustomObject]$entry)
          continue
        }

        if (-not $PSCmdlet.ShouldProcess($target, 'Drop, recreate, and migrate sprint database with Flyway')) {
          $entry.skipped = $true
          $results.Add([PSCustomObject]$entry)
          continue
        }

        try {
          $buildParams = @{
            DatabaseName            = $db
            Environment             = $environment
            FlywayBasePath          = $resolvedFlywayBasePath
            FlywayTomlPath          = $resolvedFlywayTomlPath
            FlywaySqlMigrationsPath = $resolvedFlywaySqlMigrationsPath
            RepositoryRoot          = $RepositoryRoot
            Force                   = $true
          }

          $canPassSplitConnectionStringSecrets = $usingConnectionStringSecret -and
            ($buildDatabaseWithFlywayParameters -contains 'DBConnectionStringMasterSecretName' -or
              $buildDatabaseWithFlywayParameters -contains 'DBConnectionStringDBSecretName')
          $canPassConnectionStringSecret = $usingConnectionStringSecret -and
            $buildDatabaseWithFlywayParameters -contains 'DBConnectionStringSecretName'
          $passConnectionParts = $true
          if ($canPassSplitConnectionStringSecrets) {
            if (-not [string]::IsNullOrWhiteSpace($resolvedDBConnectionStringMasterSecretName) -and
              $buildDatabaseWithFlywayParameters -contains 'DBConnectionStringMasterSecretName') {
              $buildParams['DBConnectionStringMasterSecretName'] = $resolvedDBConnectionStringMasterSecretName
            }
            if (-not [string]::IsNullOrWhiteSpace($resolvedDBConnectionStringDBSecretName) -and
              $buildDatabaseWithFlywayParameters -contains 'DBConnectionStringDBSecretName') {
              $buildParams['DBConnectionStringDBSecretName'] = $resolvedDBConnectionStringDBSecretName
            }
            $passConnectionParts = [string]::IsNullOrWhiteSpace($resolvedDBConnectionStringMasterSecretName)
          } elseif ($canPassConnectionStringSecret) {
            $buildParams['DBConnectionStringSecretName'] = $resolvedDBConnectionStringSecretName
            $passConnectionParts = $false
          }

          if ($passConnectionParts) {
            $buildParams['DatabaseHost'] = $resolvedDatabaseHost
            if (-not [string]::IsNullOrWhiteSpace($resolvedConnectionMethod)) {
              $buildParams['ConnectionMethod'] = $resolvedConnectionMethod
            }

            if ($buildDatabaseWithFlywayParameters -contains 'SqlInstance') {
              $buildParams['SqlInstance'] = $instanceName
            } else {
              $buildParams['InstanceName'] = $instanceName
            }

            if ($resolvedCredentialsKey -and $buildDatabaseWithFlywayParameters -contains 'CredentialsKey') {
              $buildParams['CredentialsKey'] = $resolvedCredentialsKey
            }
            elseif ($PSBoundParameters.ContainsKey('IntegratedSecurity') -and $buildDatabaseWithFlywayParameters -contains 'IntegratedSecurity') {
              $buildParams['IntegratedSecurity'] = $true
            }

            if ($PSBoundParameters.ContainsKey('UseTrustedConnection') -and $UseTrustedConnection -and $buildDatabaseWithFlywayParameters -contains 'UseTrustedConnection') {
              $buildParams['UseTrustedConnection'] = $true
            }
          }
          if (-not [string]::IsNullOrWhiteSpace($resolvedDatabasePath) -and $buildDatabaseWithFlywayParameters -contains 'DatabasePath') {
            $buildParams['DatabasePath'] = $resolvedDatabasePath
          }
          if (-not [string]::IsNullOrWhiteSpace($resolvedProvisioningScriptsPath) -and $buildDatabaseWithFlywayParameters -contains 'ProvisioningScriptsPath') {
            $buildParams['ProvisioningScriptsPath'] = $resolvedProvisioningScriptsPath
          }
          if (-not [string]::IsNullOrWhiteSpace($resolvedFlywaySharedSqlMigrationsPath) -and $buildDatabaseWithFlywayParameters -contains 'FlywaySharedSqlMigrationsPath') {
            $buildParams['FlywaySharedSqlMigrationsPath'] = $resolvedFlywaySharedSqlMigrationsPath
          }

          if ($resolvedApplicationName -and $buildDatabaseWithFlywayParameters -contains 'ApplicationName') {
            $buildParams['ApplicationName'] = $resolvedApplicationName
          }
          if ($PSBoundParameters.ContainsKey('Settings') -and $buildDatabaseWithFlywayParameters -contains 'Settings') {
            $buildParams['Settings'] = $Settings
          }

          $buildOutput = @(Build-DatabaseWithFlyway @buildParams)
          $buildResult = $buildOutput |
            Where-Object { $null -ne $_ -and $_.PSObject.Properties['Success'] } |
            Select-Object -Last 1
          $resultSuccess = $null -ne $buildResult -and $buildResult.PSObject.Properties['Success'] -and $buildResult.Success

          if ($resultSuccess) {
            $entry.reset = $true
            $entry.migrated = $true
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "Database reset successfully: instance=$instanceName db=$db"
          } else {
            $errorsDetail = if ($null -ne $buildResult -and $buildResult.PSObject.Properties['Errors'] -and $buildResult.Errors) {
              ($buildResult.Errors -join '; ')
            } else {
              'Build-DatabaseWithFlyway returned no Success=$true and no Errors collection.'
            }
            $entry.error = "Build-DatabaseWithFlyway failed for instance='$instanceName' db='$db': $errorsDetail"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $entry.error
          }
        } catch {
          $entry.error = "Build-DatabaseWithFlyway failed for instance='$instanceName' db='$db'. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $entry.error
        }

        $results.Add([PSCustomObject]$entry)
      }
    }

    return $results.ToArray()
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}

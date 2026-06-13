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
    overrides DeveloperNames-derived instance names.
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
    [string[]]$InstanceNames,

    [Parameter(Mandatory = $false)]
    [string[]]$Databases,

    [Parameter(Mandatory = $false)]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $false)]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false)]
    [string]$CredentialsKey,

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

    if ([string]::IsNullOrWhiteSpace($DatabaseHost)) {
      $DatabaseHost = 'localhost'
    }

    if ([string]::IsNullOrWhiteSpace($ConnectionMethod)) {
      $ConnectionMethod = 'tcp'
    }

    if (-not $PSBoundParameters.ContainsKey('Databases') -or $null -eq $Databases -or $Databases.Count -eq 0) {
      $Databases = @('ATAPUtilities', 'AceCommander')
    }
    $Databases = @($Databases | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($Databases.Count -eq 0) {
      throw 'At least one database name is required.'
    }

    if (-not $PSBoundParameters.ContainsKey('InstanceNames') -or $null -eq $InstanceNames -or $InstanceNames.Count -eq 0) {
      if (-not $PSBoundParameters.ContainsKey('DeveloperNames') -or $null -eq $DeveloperNames -or $DeveloperNames.Count -eq 0) {
        $settingsKey = if ($global:configRootKeys -and $global:configRootKeys['SprintDeveloperNamesConfigRootKey']) {
          $global:configRootKeys['SprintDeveloperNamesConfigRootKey']
        } else {
          'Sprint.DeveloperNames'
        }

        if (Get-Command -Name 'Get-PVal' -ErrorAction SilentlyContinue) {
          $DeveloperNames = Get-PVal `
            -ParameterName 'DeveloperNames' `
            -originalPSBoundParameters $PSBoundParameters `
            -dottedPath $settingsKey `
            -DefaultValue @($env:USERNAME) `
            -AllowMissing
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

    if ([string]::IsNullOrWhiteSpace($FlywayBasePath)) {
      $flywayKey = 'FlywayBasePathConfigRootKey'
      if ($null -ne $global:configRootKeys -and $global:configRootKeys.ContainsKey($flywayKey) -and
        $null -ne $global:settings -and -not [string]::IsNullOrWhiteSpace($global:settings[$global:configRootKeys[$flywayKey]])) {
        $FlywayBasePath = $global:settings[$global:configRootKeys[$flywayKey]]
      } else {
        $FlywayBasePath = Join-Path $RepositoryRoot 'Database' 'Flyway'
      }
    }

    $flywayTomlPath = Join-Path $FlywayBasePath 'flyway.toml'
    if (-not (Test-Path -LiteralPath $flywayTomlPath -PathType Leaf)) {
      throw "Flyway configuration file not found: $flywayTomlPath"
    }

    $isNoOp = [bool]($DryRun -or $WhatIfPreference)
    $buildDatabaseWithFlywayParameters = $null
    if (-not $isNoOp) {
      if (-not (Get-Command -Name 'Build-DatabaseWithFlyway' -CommandType Function -ErrorAction SilentlyContinue)) {
        $buildDbPath = Join-Path $RepositoryRoot 'src' 'ATAP.Utilities.DatabaseManagement.Powershell' 'public' 'Build-DatabaseWithFlyway.ps1'
        if (-not (Test-Path -LiteralPath $buildDbPath -PathType Leaf)) {
          throw "Build-DatabaseWithFlyway.ps1 not found at: $buildDbPath"
        }
        . $buildDbPath
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
          -Message "Loaded Build-DatabaseWithFlyway from $buildDbPath"
      }

      $buildDatabaseWithFlywayParameters = (Get-Command -Name 'Build-DatabaseWithFlyway' -CommandType Function).Parameters.Keys
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Instances: $($InstanceNames -join ', ') | Databases: $($Databases -join ', ') | Host: $DatabaseHost | DryRun: $DryRun"
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

      foreach ($db in $Databases) {
        $target = if ([string]::IsNullOrWhiteSpace($DatabaseHost) -or $DatabaseHost -eq 'localhost') {
          "localhost\$instanceName\$db"
        } else {
          "$DatabaseHost\$instanceName\$db"
        }

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
            DatabaseHost            = $DatabaseHost
            ConnectionMethod        = $ConnectionMethod
            FlywayBasePath          = $FlywayBasePath
            FlywayTomlPath          = $flywayTomlPath
            FlywaySqlMigrationsPath = (Join-Path $FlywayBasePath 'SQL')
            RepositoryRoot          = $RepositoryRoot
            Force                   = $true
          }

          if ($buildDatabaseWithFlywayParameters -contains 'SqlInstance') {
            $buildParams['SqlInstance'] = $instanceName
          } else {
            $buildParams['InstanceName'] = $instanceName
          }

          if ($CredentialsKey -and $buildDatabaseWithFlywayParameters -contains 'CredentialsKey') {
            $buildParams['CredentialsKey'] = $CredentialsKey
          }
          elseif ($buildDatabaseWithFlywayParameters -contains 'IntegratedSecurity') {
            $buildParams['IntegratedSecurity'] = $true
          }

          if ($ApplicationName -and $buildDatabaseWithFlywayParameters -contains 'ApplicationName') {
            $buildParams['ApplicationName'] = $ApplicationName
          }
          if ($UseTrustedConnection -and $buildDatabaseWithFlywayParameters -contains 'UseTrustedConnection') {
            $buildParams['UseTrustedConnection'] = $true
          }
          if ($PSBoundParameters.ContainsKey('Settings') -and $buildDatabaseWithFlywayParameters -contains 'Settings') {
            $buildParams['Settings'] = $Settings
          }

          $buildResult = Build-DatabaseWithFlyway @buildParams
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

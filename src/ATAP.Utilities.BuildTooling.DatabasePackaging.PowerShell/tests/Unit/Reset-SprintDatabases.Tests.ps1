BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  function Get-ParameterValueFromNeoConfigurationRoot {
    param(
      [string]$ParameterName,
      [hashtable]$originalPSBoundParameters,
      [string]$dottedPath,
      [hashtable]$Settings,
      [AllowNull()]$DefaultValue,
      [switch]$AllowMissing,
      [type]$AsType,
      [string[]]$ValidValues
    )

    if ($originalPSBoundParameters -and $originalPSBoundParameters.ContainsKey($ParameterName)) {
      return $originalPSBoundParameters[$ParameterName]
    }

    if ($Settings -and -not [string]::IsNullOrWhiteSpace($dottedPath)) {
      $current = $Settings
      $found = $true
      foreach ($part in ($dottedPath -split '\.')) {
        if ($current -is [System.Collections.IDictionary] -and $current.Contains($part)) {
          $current = $current[$part]
          continue
        }

        if ($null -ne $current -and $current.PSObject.Properties[$part]) {
          $current = $current.PSObject.Properties[$part].Value
          continue
        }

        $found = $false
        break
      }

      if ($found) {
        if ($null -ne $AsType -and $null -ne $current) {
          return ($current -as $AsType)
        }
        return $current
      }
    }

    if ($PSBoundParameters.ContainsKey('DefaultValue')) {
      if ($null -ne $AsType -and $null -ne $DefaultValue) {
        return ($DefaultValue -as $AsType)
      }
      return $DefaultValue
    }

    if ($AllowMissing) {
      return $null
    }

    throw "Missing test value for $ParameterName"
  }
  Set-Alias -Name Get-PVal -Value Get-ParameterValueFromNeoConfigurationRoot -Scope Script -Force

  # Reset-SprintDatabases inspects the delegated command's parameter metadata.
  # Use a real, full-signature stub (not a Pester mock wrapper) so the production
  # command forwards its complete parameter set; the global recorder is test-only.
  $global:DatabasePackagingFlywayCalls = [System.Collections.Generic.List[object]]::new()

  function Build-DatabaseWithFlyway {
    param(
      [string]$DatabaseName,
      [string]$Environment,
      [string]$DatabaseHost,
      [string]$SqlInstance,
      [string]$ConnectionMethod,
      [string]$CredentialsKey,
      [string]$DBConnectionStringSecretName,
      [string]$DBConnectionStringMasterSecretName,
      [string]$DBConnectionStringDBSecretName,
      [string]$ApplicationName,
      [switch]$UseTrustedConnection,
      [string]$DatabasePath,
      [string]$ProvisioningScriptsPath,
      [string]$FlywayBasePath,
      [string]$FlywayTomlPath,
      [string]$FlywaySqlMigrationsPath,
      [string]$FlywaySharedSqlMigrationsPath,
      [string]$RepositoryRoot,
      [switch]$IntegratedSecurity,
      [hashtable]$Settings,
      [switch]$Force
    )
    $snapshot = @{}
    foreach ($key in $PSBoundParameters.Keys) {
      $snapshot[$key] = $PSBoundParameters[$key]
    }
    $global:DatabasePackagingFlywayCalls.Add($snapshot)
    [PSCustomObject]@{ Success = $true; Errors = @() }
  }

  function Install-SqlServerInstance { throw 'Reset-SprintDatabases must not create SQL Server instances.' }
  function Remove-DbaDatabase { throw 'Reset-SprintDatabases delegates database reset to Build-DatabaseWithFlyway.' }

  . "$PSScriptRoot\..\..\public\Reset-SprintDatabases.ps1"

  $script:tempRepoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('rsd-test-' + [guid]::NewGuid().ToString('N'))
  $script:flywayBase = Join-Path $script:tempRepoRoot 'Database' 'Flyway'
  New-Item -ItemType Directory -Path (Join-Path $script:flywayBase 'SQL') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $script:flywayBase 'flyway.toml') -Value '# stub' -Encoding UTF8
  $script:hadGlobalSettings = Test-Path -LiteralPath 'Variable:global:settings'
  $script:originalGlobalSettings = $global:settings
}

AfterAll {
  Remove-Item -LiteralPath $script:tempRepoRoot -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Variable -Name DatabasePackagingFlywayCalls -Scope Global -ErrorAction SilentlyContinue
  if ($script:hadGlobalSettings) {
    $global:settings = $script:originalGlobalSettings
  } else {
    Remove-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue
  }
}

Describe 'Reset-SprintDatabases [public]' {
  BeforeEach {
    $global:DatabasePackagingFlywayCalls.Clear()
    $global:settings = @{}

    Mock -CommandName Get-Service -MockWith {
      [PSCustomObject]@{ Name = $Name; Status = 'Running' }
    } -ParameterFilter { $Name -like 'MSSQL$*' }

    Mock -CommandName Install-SqlServerInstance -MockWith { throw 'Must not be called.' }
    Mock -CommandName Remove-DbaDatabase -MockWith { throw 'Must not be called.' }
  }

  It 'function exists and is loaded' {
    Get-Command -Name 'Reset-SprintDatabases' -CommandType Function |
      Should -Not -BeNullOrEmpty
  }

  It 'calls Build-DatabaseWithFlyway once per instance and database with Force' {
    $results = Reset-SprintDatabases `
      -InstanceNames @('Devtester', 'Exptester') `
      -Databases @('ATAPUtilities', 'AceCommander') `
      -FlywayBasePath $script:flywayBase `
      -RepositoryRoot $script:tempRepoRoot `
      -Confirm:$false

    $results.Count | Should -Be 4
    $global:DatabasePackagingFlywayCalls.Count | Should -Be 4
    @($global:DatabasePackagingFlywayCalls | Where-Object { $_['Force'] }).Count | Should -Be 4
    Should -Invoke -CommandName Install-SqlServerInstance -Times 0 -Exactly
    Should -Invoke -CommandName Remove-DbaDatabase -Times 0 -Exactly
  }

  It 'passes the expected environment and SQL instance to Flyway builds' {
    Reset-SprintDatabases `
      -InstanceNames @('Devtester', 'Exptester') `
      -Databases @('ATAPUtilities') `
      -FlywayBasePath $script:flywayBase `
      -RepositoryRoot $script:tempRepoRoot `
      -Confirm:$false | Out-Null

    @($global:DatabasePackagingFlywayCalls | Where-Object { $_['SqlInstance'] -eq 'Devtester' -and $_['Environment'] -eq 'Development' }).Count | Should -Be 1
    @($global:DatabasePackagingFlywayCalls | Where-Object { $_['SqlInstance'] -eq 'Exptester' -and $_['Environment'] -eq 'Experimental' }).Count | Should -Be 1
  }

  It 'defaults connection-part resets to integrated security when no secret or credential key is supplied' {
    Reset-SprintDatabases `
      -InstanceNames @('Devtester') `
      -Databases @('ATAPUtilities') `
      -FlywayBasePath $script:flywayBase `
      -RepositoryRoot $script:tempRepoRoot `
      -Confirm:$false | Out-Null

    $global:DatabasePackagingFlywayCalls.Count | Should -Be 1
    $call = $global:DatabasePackagingFlywayCalls[0]
    $call['SqlInstance'] | Should -Be 'Devtester'
    $call['IntegratedSecurity'] | Should -BeTrue
    [string]::IsNullOrWhiteSpace($call['CredentialsKey']) | Should -BeTrue
    [string]::IsNullOrWhiteSpace($call['DBConnectionStringMasterSecretName']) | Should -BeTrue
    [string]::IsNullOrWhiteSpace($call['DBConnectionStringDBSecretName']) | Should -BeTrue
  }

  It 'uses an instance-scoped default database path when settings do not provide one' {
    Reset-SprintDatabases `
      -InstanceNames @('Devtester', 'Exptester') `
      -Databases @('ATAPUtilities') `
      -FlywayBasePath $script:flywayBase `
      -RepositoryRoot $script:tempRepoRoot `
      -Confirm:$false | Out-Null

    @($global:DatabasePackagingFlywayCalls | Where-Object { $_['SqlInstance'] -eq 'Devtester' -and $_['DatabasePath'] -eq 'C:\LocalDBs\Devtester\ATAPUtilities' }).Count | Should -Be 1
    @($global:DatabasePackagingFlywayCalls | Where-Object { $_['SqlInstance'] -eq 'Exptester' -and $_['DatabasePath'] -eq 'C:\LocalDBs\Exptester\ATAPUtilities' }).Count | Should -Be 1
  }

  It 'prefers an explicitly supplied current provisioning-script path over stale settings' {
    $currentProvisioningPath = Join-Path $script:tempRepoRoot 'src\ATAP.Utilities.DatabaseManagement\SharedSQL'
    $settings = @{
      ATAPUtilities = @{
        Development = @{
          ProvisioningScriptsPath = 'C:\stale-installed-module\SharedSQL'
        }
      }
    }

    Reset-SprintDatabases `
      -InstanceNames @('Devtester') `
      -Databases @('ATAPUtilities') `
      -Settings $settings `
      -FlywayBasePath $script:flywayBase `
      -ProvisioningScriptsPath $currentProvisioningPath `
      -RepositoryRoot $script:tempRepoRoot `
      -Confirm:$false | Out-Null

    @($global:DatabasePackagingFlywayCalls | Where-Object {
      $_['ProvisioningScriptsPath'] -eq $currentProvisioningPath -and
      $_['RepositoryRoot'] -eq $script:tempRepoRoot
    }).Count | Should -Be 1
  }

  It 'uses split master and database connection-string secret names from per-database settings' {
    $settingsProvisioningPath = Join-Path $script:tempRepoRoot 'settings-shared-sql'
    $settingsFlywayBasePath = Join-Path $script:tempRepoRoot 'settings-flyway'
    $settings = @{
      ATAPUtilities = @{
        Development = @{
          DatabaseHost                 = 'utat022'
          ConnectionMethod             = 'tcp'
          SqlInstance                  = 'Devtester'
          CredentialsKey               = 'legacy-credentials-key'
          DBConnectionStringMasterSecretName = 'ATAPUtilitiesDevelopmentMasterConnectionString'
          DBConnectionStringDBSecretName = 'ATAPUtilitiesDevelopmentDBConnectionString'
          DatabasePath                 = 'C:\LocalDBs\Development\ATAPUtilities'
          ProvisioningScriptsPath      = $settingsProvisioningPath
          FlywayBasePath               = $settingsFlywayBasePath
          FlywaySqlMigrationsPath      = (Join-Path $settingsFlywayBasePath 'SQL')
          FlywaySharedSqlMigrationsPath = (Join-Path $settingsFlywayBasePath 'Shared')
          FlywayTomlPath               = (Join-Path $settingsFlywayBasePath 'flyway.toml')
          ApplicationName              = 'ATAP.Utilities.Tests'
        }
      }
    }

    Reset-SprintDatabases `
      -InstanceNames @('Devtester') `
      -Databases @('ATAPUtilities') `
      -Settings $settings `
      -RepositoryRoot $script:tempRepoRoot `
      -IntegratedSecurity `
      -Confirm:$false | Out-Null

    $global:DatabasePackagingFlywayCalls.Count | Should -Be 1
    $call = $global:DatabasePackagingFlywayCalls[0]
    $call['DBConnectionStringMasterSecretName'] | Should -Be 'ATAPUtilitiesDevelopmentMasterConnectionString'
    $call['DBConnectionStringDBSecretName'] | Should -Be 'ATAPUtilitiesDevelopmentDBConnectionString'
    [string]::IsNullOrWhiteSpace($call['DBConnectionStringSecretName']) | Should -BeTrue
    $call['DatabasePath'] | Should -Be 'C:\LocalDBs\Development\ATAPUtilities'
    $call['ProvisioningScriptsPath'] | Should -Be $settingsProvisioningPath
    $call['FlywayBasePath'] | Should -Be $settingsFlywayBasePath
    $call['FlywaySqlMigrationsPath'] | Should -Be (Join-Path $settingsFlywayBasePath 'SQL')
    $call['FlywaySharedSqlMigrationsPath'] | Should -Be (Join-Path $settingsFlywayBasePath 'Shared')
    $call['FlywayTomlPath'] | Should -Be (Join-Path $settingsFlywayBasePath 'flyway.toml')
    $call['ApplicationName'] | Should -Be 'ATAP.Utilities.Tests'
    [string]::IsNullOrWhiteSpace($call['SqlInstance']) | Should -BeTrue
    [string]::IsNullOrWhiteSpace($call['DatabaseHost']) | Should -BeTrue
    [string]::IsNullOrWhiteSpace($call['ConnectionMethod']) | Should -BeTrue
    [string]::IsNullOrWhiteSpace($call['CredentialsKey']) | Should -BeTrue
    $call['IntegratedSecurity'] | Should -BeFalse
  }

  It 'accepts per-instance hashtable entries with master connection-string secret names' {
    $instanceSpecs = @(
      @{
        InstanceName                         = 'Devtester'
        DBConnectionStringMasterSecretName   = 'dbConnectionString.master.localhost.Dev.tester'
      },
      @{
        InstanceName                         = 'Exptester'
        SQLConnectionSecretName              = 'dbConnectionString.master.localhost.Exp.tester'
      }
    )

    Reset-SprintDatabases `
      -InstanceNames $instanceSpecs `
      -Databases @('ATAPUtilities') `
      -FlywayBasePath $script:flywayBase `
      -RepositoryRoot $script:tempRepoRoot `
      -Confirm:$false | Out-Null

    @($global:DatabasePackagingFlywayCalls | Where-Object {
      $_['Environment'] -eq 'Development' -and
      $_['DBConnectionStringMasterSecretName'] -eq 'dbConnectionString.master.localhost.Dev.tester' -and
      [string]::IsNullOrWhiteSpace($_['SqlInstance']) -and
      [string]::IsNullOrWhiteSpace($_['DatabaseHost'])
    }).Count | Should -Be 1
    @($global:DatabasePackagingFlywayCalls | Where-Object {
      $_['Environment'] -eq 'Experimental' -and
      $_['DBConnectionStringMasterSecretName'] -eq 'dbConnectionString.master.localhost.Exp.tester' -and
      [string]::IsNullOrWhiteSpace($_['SqlInstance']) -and
      [string]::IsNullOrWhiteSpace($_['DatabaseHost'])
    }).Count | Should -Be 1
  }

  It 'uses Get-PVal instance settings when InstanceNames are plain strings' {
    $settings = @{
      Instances = @{
        Devtester = @{
          DBConnectionStringMasterSecretName = 'settings-dev-master-secret'
        }
        Exptester = @{
          DBConnectionStringMasterSecretName = 'settings-exp-master-secret'
        }
      }
    }

    Reset-SprintDatabases `
      -InstanceNames @('Devtester', 'Exptester') `
      -Databases @('ATAPUtilities') `
      -Settings $settings `
      -FlywayBasePath $script:flywayBase `
      -RepositoryRoot $script:tempRepoRoot `
      -Confirm:$false | Out-Null

    @($global:DatabasePackagingFlywayCalls | Where-Object {
      $_['Environment'] -eq 'Development' -and
      $_['DBConnectionStringMasterSecretName'] -eq 'settings-dev-master-secret' -and
      [string]::IsNullOrWhiteSpace($_['SqlInstance']) -and
      [string]::IsNullOrWhiteSpace($_['DatabaseHost'])
    }).Count | Should -Be 1
    @($global:DatabasePackagingFlywayCalls | Where-Object {
      $_['Environment'] -eq 'Experimental' -and
      $_['DBConnectionStringMasterSecretName'] -eq 'settings-exp-master-secret' -and
      [string]::IsNullOrWhiteSpace($_['SqlInstance']) -and
      [string]::IsNullOrWhiteSpace($_['DatabaseHost'])
    }).Count | Should -Be 1
  }

  It 'fails with onboarding remediation and does not reset anything when an instance is missing' {
    Mock -CommandName Get-Service -MockWith {
      if ($Name -eq 'MSSQL$Devtester') {
        [PSCustomObject]@{ Name = $Name; Status = 'Running' }
      }
    } -ParameterFilter { $Name -like 'MSSQL$*' }

    {
      Reset-SprintDatabases `
        -InstanceNames @('Devtester', 'Exptester') `
        -Databases @('ATAPUtilities') `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot `
        -Confirm:$false
    } | Should -Throw -ExpectedMessage '*developer onboarding SQL Server instance setup*'

    $global:DatabasePackagingFlywayCalls.Count | Should -Be 0
  }

  It 'does not call Build-DatabaseWithFlyway when WhatIf is set' {
    $results = Reset-SprintDatabases `
      -InstanceNames @('Devtester', 'Exptester') `
      -Databases @('ATAPUtilities', 'AceCommander') `
      -FlywayBasePath $script:flywayBase `
      -RepositoryRoot $script:tempRepoRoot `
      -WhatIf

    $results.Count | Should -Be 4
    ($results | Where-Object { -not $_.skipped }).Count | Should -Be 0
    $global:DatabasePackagingFlywayCalls.Count | Should -Be 0
  }

  It 'does not call Build-DatabaseWithFlyway when DryRun is set' {
    $results = Reset-SprintDatabases `
      -InstanceNames @('Devtester') `
      -Databases @('ATAPUtilities', 'AceCommander') `
      -FlywayBasePath $script:flywayBase `
      -RepositoryRoot $script:tempRepoRoot `
      -DryRun

    $results.Count | Should -Be 2
    ($results | Where-Object { -not $_.dryRun -or -not $_.skipped -or $_.reset }).Count | Should -Be 0
    $global:DatabasePackagingFlywayCalls.Count | Should -Be 0
  }

  It 'uses Dev and Exp instance names for the current user by default' {
    Reset-SprintDatabases `
      -Databases @('ATAPUtilities') `
      -FlywayBasePath $script:flywayBase `
      -RepositoryRoot $script:tempRepoRoot `
      -DryRun | Out-Null

    Should -Invoke -CommandName Get-Service -Times 1 -ParameterFilter { $Name -eq "MSSQL`$Dev$($env:USERNAME)" }
    Should -Invoke -CommandName Get-Service -Times 1 -ParameterFilter { $Name -eq "MSSQL`$Exp$($env:USERNAME)" }
  }

  It 'imports dbatools before resolving or dot-sourcing Build-DatabaseWithFlyway' {
    $source = Get-Content -LiteralPath "$PSScriptRoot\..\..\public\Reset-SprintDatabases.ps1" -Raw
    $importIndex = $source.IndexOf('Import-Module -Name dbatools')
    $resolveIndex = $source.IndexOf("Get-Command -Name 'Build-DatabaseWithFlyway'")
    $dotSourceIndex = $source.IndexOf('. $buildDbPath')

    $importIndex | Should -BeGreaterOrEqual 0
    $resolveIndex | Should -BeGreaterThan $importIndex
    $dotSourceIndex | Should -BeGreaterThan $importIndex
  }
}

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  $script:hadGlobalGetPVal = Test-Path -Path 'Function:\global:Get-PVal'
  if ($script:hadGlobalGetPVal) {
    $script:oldGlobalGetPVal = (Get-Item -Path 'Function:\global:Get-PVal').ScriptBlock
  }
  function global:Get-PVal {
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
    [PSCustomObject]@{ Success = $true; Errors = @() }
  }

  function Install-SqlServerInstance { throw 'Reset-SprintDatabases must not create SQL Server instances.' }
  function Remove-DbaDatabase { throw 'Reset-SprintDatabases delegates database reset to Build-DatabaseWithFlyway.' }

  . "$PSScriptRoot\..\..\public\Reset-SprintDatabases.ps1"

  $script:tempRepoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('rsd-test-' + [guid]::NewGuid().ToString('N'))
  $script:flywayBase = Join-Path $script:tempRepoRoot 'Database' 'Flyway'
  New-Item -ItemType Directory -Path (Join-Path $script:flywayBase 'SQL') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $script:flywayBase 'flyway.toml') -Value '# stub' -Encoding UTF8
}

AfterAll {
  Remove-Item -LiteralPath $script:tempRepoRoot -Recurse -Force -ErrorAction SilentlyContinue
  if ($script:hadGlobalGetPVal) {
    Set-Item -Path 'Function:\global:Get-PVal' -Value $script:oldGlobalGetPVal
  } else {
    Remove-Item -Path 'Function:\global:Get-PVal' -ErrorAction SilentlyContinue
  }
}

Describe 'Reset-SprintDatabases [public]' {
  BeforeEach {
    Mock -CommandName Get-Service -MockWith {
      [PSCustomObject]@{ Name = $Name; Status = 'Running' }
    } -ParameterFilter { $Name -like 'MSSQL$*' }

    Mock -CommandName Build-DatabaseWithFlyway -MockWith {
      [PSCustomObject]@{ Success = $true; Errors = @() }
    }
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
    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 4 -Exactly -ParameterFilter { $Force }
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

    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 1 -ParameterFilter {
      $SqlInstance -eq 'Devtester' -and $Environment -eq 'Development'
    }
    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 1 -ParameterFilter {
      $SqlInstance -eq 'Exptester' -and $Environment -eq 'Experimental'
    }
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

    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 1 -Exactly -ParameterFilter {
      $DBConnectionStringMasterSecretName -eq 'ATAPUtilitiesDevelopmentMasterConnectionString' -and
      $DBConnectionStringDBSecretName -eq 'ATAPUtilitiesDevelopmentDBConnectionString' -and
      [string]::IsNullOrWhiteSpace($DBConnectionStringSecretName) -and
      $DatabasePath -eq 'C:\LocalDBs\Development\ATAPUtilities' -and
      $ProvisioningScriptsPath -eq $settingsProvisioningPath -and
      $FlywayBasePath -eq $settingsFlywayBasePath -and
      $FlywaySqlMigrationsPath -eq (Join-Path $settingsFlywayBasePath 'SQL') -and
      $FlywaySharedSqlMigrationsPath -eq (Join-Path $settingsFlywayBasePath 'Shared') -and
      $FlywayTomlPath -eq (Join-Path $settingsFlywayBasePath 'flyway.toml') -and
      $ApplicationName -eq 'ATAP.Utilities.Tests' -and
      [string]::IsNullOrWhiteSpace($SqlInstance) -and
      [string]::IsNullOrWhiteSpace($DatabaseHost) -and
      [string]::IsNullOrWhiteSpace($ConnectionMethod) -and
      [string]::IsNullOrWhiteSpace($CredentialsKey) -and
      -not $IntegratedSecurity
    }
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

    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 1 -Exactly -ParameterFilter {
      $Environment -eq 'Development' -and
      $DBConnectionStringMasterSecretName -eq 'dbConnectionString.master.localhost.Dev.tester' -and
      [string]::IsNullOrWhiteSpace($SqlInstance) -and
      [string]::IsNullOrWhiteSpace($DatabaseHost)
    }
    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 1 -Exactly -ParameterFilter {
      $Environment -eq 'Experimental' -and
      $DBConnectionStringMasterSecretName -eq 'dbConnectionString.master.localhost.Exp.tester' -and
      [string]::IsNullOrWhiteSpace($SqlInstance) -and
      [string]::IsNullOrWhiteSpace($DatabaseHost)
    }
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

    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 1 -Exactly -ParameterFilter {
      $Environment -eq 'Development' -and
      $DBConnectionStringMasterSecretName -eq 'settings-dev-master-secret' -and
      [string]::IsNullOrWhiteSpace($SqlInstance) -and
      [string]::IsNullOrWhiteSpace($DatabaseHost)
    }
    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 1 -Exactly -ParameterFilter {
      $Environment -eq 'Experimental' -and
      $DBConnectionStringMasterSecretName -eq 'settings-exp-master-secret' -and
      [string]::IsNullOrWhiteSpace($SqlInstance) -and
      [string]::IsNullOrWhiteSpace($DatabaseHost)
    }
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

    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 0 -Exactly
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
    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 0 -Exactly
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
    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 0 -Exactly
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

  It 'imports dbatools before dot-sourcing Build-DatabaseWithFlyway' {
    $source = Get-Content -LiteralPath "$PSScriptRoot\..\..\public\Reset-SprintDatabases.ps1" -Raw
    $importIndex = $source.IndexOf('Import-Module -Name dbatools')
    $dotSourceIndex = $source.IndexOf('. $buildDbPath')

    $importIndex | Should -BeGreaterOrEqual 0
    $dotSourceIndex | Should -BeGreaterThan $importIndex
  }
}

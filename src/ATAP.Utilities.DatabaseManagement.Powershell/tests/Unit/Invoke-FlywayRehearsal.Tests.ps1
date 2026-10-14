#Requires -Version 7.0
# Pester 5+ tests for Invoke-FlywayRehearsal (Stream J5).

BeforeAll {
  $script:createdResolveDatabaseSqlConnectionStub = $false
  $script:createdInvokeDatabaseSqlNonQueryStub = $false
  $script:createdInvokeFlywayStub = $false
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Invoke-FlywayRehearsal.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
  if (-not (Get-Command Resolve-DatabaseSqlConnection -ErrorAction SilentlyContinue)) {
    function global:Resolve-DatabaseSqlConnection {
      param(
        [hashtable]$OriginalPSBoundParameters,
        [object]$SqlConnection,
        [string]$DBConnectionStringSecretName,
        [string]$DatabaseHost,
        [string]$InstanceName,
        [string]$DatabaseName,
        [string]$ConnectionMethod,
        [string]$CredentialsKey,
        [string]$ApplicationName,
        [switch]$UseTrustedConnection,
        [switch]$IntegratedSecurity,
        [hashtable]$Settings
      )
    }
    $script:createdResolveDatabaseSqlConnectionStub = $true
  }
  if (-not (Get-Command Invoke-DatabaseSqlNonQuery -ErrorAction SilentlyContinue)) {
    function global:Invoke-DatabaseSqlNonQuery {
      param([object]$SqlConnection, [string]$CommandText, [hashtable]$Parameters, [int]$CommandTimeout)
    }
    $script:createdInvokeDatabaseSqlNonQueryStub = $true
  }
  if (-not (Get-Command Invoke-Flyway -ErrorAction SilentlyContinue)) {
    function global:Invoke-Flyway {
      param(
        [object]$SqlConnection,
        [string]$DBConnectionStringSecretName,
        [string]$DatabaseName,
        [string]$Environment,
        [string]$DatabaseHost,
        [string]$SqlInstance,
        [string]$FlywayCommand,
        [string]$ConnectionMethod,
        [string]$CredentialsKey,
        [string]$ApplicationName,
        [switch]$UseTrustedConnection,
        [switch]$IntegratedSecurity,
        [hashtable]$Settings,
        [string]$FlywayExecutablePath,
        [string]$FlywayBasePath,
        [string]$FlywaySqlMigrationsPath,
        [string]$FlywaySharedSqlMigrationsPath,
        [string]$FlywayDataPath,
        [string]$FlywayTomlPath,
        [string[]]$FlywayAdditionalArgs,
        [string[]]$Files,
        [string]$PackageName,
        [string]$PackageVersion
      )
    }
    $script:createdInvokeFlywayStub = $true
  }
}

AfterAll {
  if ($script:createdResolveDatabaseSqlConnectionStub) {
    Remove-Item Function:\Resolve-DatabaseSqlConnection -ErrorAction SilentlyContinue
  }
  if ($script:createdInvokeDatabaseSqlNonQueryStub) {
    Remove-Item Function:\Invoke-DatabaseSqlNonQuery -ErrorAction SilentlyContinue
  }
  if ($script:createdInvokeFlywayStub) {
    Remove-Item Function:\Invoke-Flyway -ErrorAction SilentlyContinue
  }
}

Describe 'Invoke-FlywayRehearsal' -Tag 'Unit' {
  BeforeEach {
    $script:fakeConnection = [PSCustomObject]@{ State = 'Open' }
    Mock Resolve-DatabaseSqlConnection { [pscustomobject]@{ Connection = $script:fakeConnection; IsCallerOwned = $false } }
    Mock Invoke-DatabaseSqlNonQuery { 0 }
    Mock Invoke-Flyway { [PSCustomObject]@{ Success = $true; FlywayCommand = 'migrate' } }
  }

  It 'uses the default application-rehearsal-build database name' {
    $result = Invoke-FlywayRehearsal -Application 'AceCommander' -BuildId '4271' -SqlInstance 'test-sql'

    $result.RehearsalDb | Should -Be 'AceCommander-rehearsal-4271'
    $result.Created | Should -BeTrue
    $result.Dropped | Should -BeTrue
    $result.Success | Should -BeTrue
    Assert-MockCalled Resolve-DatabaseSqlConnection -Times 1 -Exactly -Scope It -ParameterFilter {
      $DatabaseHost -eq 'localhost' -and $InstanceName -eq 'test-sql' -and $DatabaseName -eq 'master'
    }
    Assert-MockCalled Invoke-Flyway -Times 1 -Exactly -Scope It -ParameterFilter {
      $DatabaseName -eq 'AceCommander-rehearsal-4271' -and $FlywayCommand -eq 'migrate'
    }
  }

  It 'honors explicit RehearsalDb overrides for ad-hoc runs' {
    $result = Invoke-FlywayRehearsal -Application 'AceCommander' -BuildId '4271' -RehearsalDb 'custom-rehearsal' -SqlInstance 'test-sql'

    $result.RehearsalDb | Should -Be 'custom-rehearsal'
    Assert-MockCalled Invoke-DatabaseSqlNonQuery -Times 1 -Exactly -Scope It -ParameterFilter {
      $CommandText.Contains('CREATE DATABASE [custom-rehearsal]')
    }
  }

  It 'allows BuildMaster to supply RehearsalDb without Application' {
    $result = Invoke-FlywayRehearsal -BuildId '4271' -RehearsalDb 'release-rehearsal-4271' -SqlInstance 'test-sql'

    $result.RehearsalDb | Should -Be 'release-rehearsal-4271'
    $result.Success | Should -BeTrue
  }

  It 'uses DatabaseHost plus named SqlInstance for SQL setup and teardown' {
    $result = Invoke-FlywayRehearsal -Application 'AceCommander' -BuildId '4271' -DatabaseHost 'localhost' -SqlInstance 'EXPWHERTZING'

    $result.ServerInstance | Should -Be 'localhost\EXPWHERTZING'
    Assert-MockCalled Invoke-DatabaseSqlNonQuery -Times 2 -Exactly -Scope It -ParameterFilter {
      $SqlConnection -eq $script:fakeConnection
    }
    Assert-MockCalled Invoke-Flyway -Times 1 -Exactly -Scope It -ParameterFilter {
      $DatabaseHost -eq 'localhost' -and $SqlInstance -eq 'EXPWHERTZING'
    }
  }

  It 'drops the rehearsal database in finally when Flyway fails' {
    Mock Invoke-Flyway { throw 'flyway failed' }

    { Invoke-FlywayRehearsal -Application 'AceCommander' -BuildId '4271' -SqlInstance 'test-sql' } |
      Should -Throw -ExpectedMessage '*flyway failed*'

    Assert-MockCalled Invoke-DatabaseSqlNonQuery -Times 1 -Exactly -Scope It -ParameterFilter {
      $CommandText.Contains('DROP DATABASE [AceCommander-rehearsal-4271]') -and -not $CommandText.Contains('CREATE DATABASE')
    }
  }

  It 'passes DBConnectionStringSecretName through to Invoke-Flyway' {
    Invoke-FlywayRehearsal -Application 'AceCommander' -BuildId '4271' -DBConnectionStringSecretName 'db-secret' | Out-Null

    Assert-MockCalled Resolve-DatabaseSqlConnection -Times 1 -Exactly -Scope It -ParameterFilter {
      $DBConnectionStringSecretName -eq 'db-secret'
    }
    Assert-MockCalled Invoke-Flyway -Times 1 -Exactly -Scope It -ParameterFilter {
      $DBConnectionStringSecretName -eq 'db-secret' -and $DatabaseName -eq 'AceCommander-rehearsal-4271'
    }
  }

  It 'passes the resolved SqlConnection through to Invoke-Flyway' {
    # Use a real (unopened) Microsoft.Data.SqlClient.SqlConnection rather than a
    # [PSCustomObject]. The real Invoke-Flyway types its -SqlConnection parameter as
    # [Microsoft.Data.SqlClient.SqlConnection], and Pester mocks preserve the original
    # parameter types; binding a PSCustomObject to that typed parameter throws
    # "Cannot create object of type SqlConnection. State is a ReadOnly property." when
    # the real module is loaded (e.g. promoted-module tier tests). The type is only
    # available once the module's data-access assembly is loaded; when it is not
    # (from-source unit runs without the assembly) the test is inapplicable, so skip.
    if (-not ('Microsoft.Data.SqlClient.SqlConnection' -as [type])) {
      Set-ItResult -Skipped -Because 'Microsoft.Data.SqlClient.SqlConnection type is not loaded in this run.'
      return
    }

    $realConnection = [Microsoft.Data.SqlClient.SqlConnection]::new()
    try {
      $script:fakeConnection = $realConnection
      Mock Resolve-DatabaseSqlConnection { [pscustomobject]@{ Connection = $script:fakeConnection; IsCallerOwned = $true } }

      Invoke-FlywayRehearsal -Application 'AceCommander' -BuildId '4271' -SqlConnection $realConnection | Out-Null

      Assert-MockCalled Resolve-DatabaseSqlConnection -Times 1 -Exactly -Scope It -ParameterFilter {
        $SqlConnection -eq $realConnection
      }
      Assert-MockCalled Invoke-Flyway -Times 1 -Exactly -Scope It -ParameterFilter {
        $SqlConnection -eq $script:fakeConnection -and $DatabaseName -eq 'AceCommander-rehearsal-4271'
      }
    } finally {
      $realConnection.Dispose()
    }
  }

  It 'writes a JSON log when LogPath is supplied' {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('FlywayRehearsal_' + [Guid]::NewGuid().ToString('N'))
    $logPath = Join-Path $tempRoot 'rehearsal.json'
    try {
      Invoke-FlywayRehearsal -Application 'AceCommander' -BuildId '4271' -SqlInstance 'test-sql' -LogPath $logPath | Out-Null

      Test-Path -LiteralPath $logPath -PathType Leaf | Should -BeTrue
      $log = Get-Content -LiteralPath $logPath -Raw | ConvertFrom-Json
      $log.RehearsalDb | Should -Be 'AceCommander-rehearsal-4271'
      $log.Dropped | Should -BeTrue
    } finally {
      Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

#Requires -Version 7.0
# Pester 5+ tests for Resolve-DatabaseSqlConnection. These tests mock the
# connection-opening helpers so they do not require a running SQL Server.

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $publicDir = Join-Path $moduleRoot 'public'
  $privateDir = Join-Path $moduleRoot 'private'

  . (Join-Path $privateDir 'DatabaseSqlConnection.Helpers.ps1')
  . (Join-Path $publicDir 'Resolve-DatabaseSqlConnection.ps1')
}

Describe 'Resolve-DatabaseSqlConnection' -Tag 'Unit' {
  BeforeEach {
    Mock Assert-DatabaseSqlConnectionIsOpen { 'existing-connection' }
    Mock Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName { "bitwarden:$SecretName" }
    Mock Resolve-DatabaseSqlConnectionFromConnectionParts {
      [PSCustomObject]@{
        DatabaseHost         = $DatabaseHost
        DatabaseName         = $DatabaseName
        ConnectionMethod     = $ConnectionMethod
        CredentialsKey       = $CredentialsKey
        ApplicationName      = $ApplicationName
        InstanceName         = $InstanceName
        IntegratedSecurity   = $IntegratedSecurity
        UseTrustedConnection = $UseTrustedConnection
        BoundParameters      = $BoundParameters
      }
    }
  }

  It 'prefers an existing SqlConnection input over the secret and connection parts and marks IsCallerOwned' {
    $fakeConnection = [PSCustomObject]@{ State = 'Open' }

    $result = Resolve-DatabaseSqlConnection `
      -SqlConnection $fakeConnection `
      -DBConnectionStringSecretName 'db-secret' `
      -DatabaseHost 'localhost' `
      -DatabaseName 'ATAPUtilities' `
      -IntegratedSecurity

    $result.Connection | Should -Be 'existing-connection'
    $result.IsCallerOwned | Should -BeTrue
    Assert-MockCalled Assert-DatabaseSqlConnectionIsOpen -Times 1 -Exactly -Scope It
    Assert-MockCalled Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName -Times 0 -Exactly -Scope It
    Assert-MockCalled Resolve-DatabaseSqlConnectionFromConnectionParts -Times 0 -Exactly -Scope It
  }

  It 'uses DBConnectionStringSecretName before connection parts and marks IsCallerOwned false' {
    $result = Resolve-DatabaseSqlConnection `
      -DBConnectionStringSecretName 'db-secret' `
      -DatabaseHost 'localhost' `
      -DatabaseName 'ATAPUtilities' `
      -IntegratedSecurity

    $result.Connection | Should -Be 'bitwarden:db-secret'
    $result.IsCallerOwned | Should -BeFalse
    Assert-MockCalled Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName -Times 1 -Exactly -Scope It -ParameterFilter {
      $SecretName -eq 'db-secret'
    }
    Assert-MockCalled Resolve-DatabaseSqlConnectionFromConnectionParts -Times 0 -Exactly -Scope It
  }

  It 'normalizes SqlInstance from the caller bound-parameter map to InstanceName' {
    $callerBoundParameters = @{
      DatabaseHost       = 'localhost'
      DatabaseName       = 'ATAPUtilities'
      SqlInstance        = 'DEVWHERTZING'
      IntegratedSecurity = $true
    }

    $result = Resolve-DatabaseSqlConnection -OriginalPSBoundParameters $callerBoundParameters

    $result.IsCallerOwned | Should -BeFalse
    $result.Connection.DatabaseHost | Should -Be 'localhost'
    $result.Connection.DatabaseName | Should -Be 'ATAPUtilities'
    $result.Connection.InstanceName | Should -Be 'DEVWHERTZING'
    $result.Connection.IntegratedSecurity | Should -BeTrue
    $result.Connection.BoundParameters.ContainsKey('InstanceName') | Should -BeTrue
  }

  It 'normalizes SecretName from the caller bound-parameter map to DBConnectionStringSecretName' {
    $callerBoundParameters = @{
      SecretName   = 'db-secret'
      DatabaseHost = 'localhost'
      DatabaseName = 'ATAPUtilities'
    }

    $result = Resolve-DatabaseSqlConnection -OriginalPSBoundParameters $callerBoundParameters

    $result.Connection | Should -Be 'bitwarden:db-secret'
    $result.IsCallerOwned | Should -BeFalse
    Assert-MockCalled Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName -Times 1 -Exactly -Scope It -ParameterFilter {
      $SecretName -eq 'db-secret'
    }
  }

  Context 'helper loading fallbacks' {
    It 'does not contain hard-coded Dropbox fallback paths' {
      $helperText = Get-Content -LiteralPath (Join-Path $privateDir 'DatabaseSqlConnection.Helpers.ps1') -Raw
      $helperText | Should -Not -Match 'C:\\Dropbox'
      $helperText | Should -Not -Match 'ATAP\.Utilities-wt-\d+'
    }

    It 'loads helper commands from module-relative script paths when dot-sourced standalone' {
      Remove-Item Function:\Get-ParameterValueFromNeoConfigurationRoot -ErrorAction SilentlyContinue
      Remove-Item Function:\New-ConnectionStringBuilderFromDbaTools -ErrorAction SilentlyContinue

      Import-DatabaseConnectionHelperFunctions

      Get-Command -Name Get-ParameterValueFromNeoConfigurationRoot -CommandType Function -ErrorAction Stop |
        Should -Not -BeNullOrEmpty
      Get-Command -Name New-ConnectionStringBuilderFromDbaTools -CommandType Function -ErrorAction Stop |
        Should -Not -BeNullOrEmpty
    }
  }
}

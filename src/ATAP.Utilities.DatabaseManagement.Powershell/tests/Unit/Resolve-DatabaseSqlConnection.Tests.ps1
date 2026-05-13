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
    Mock Resolve-DatabaseSqlConnectionFromBitwardenSecretName { "bitwarden:$SecretName" }
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

  It 'prefers an existing SqlConnection input over Bitwarden and connection parts' {
    $fakeConnection = [PSCustomObject]@{ State = 'Open' }

    $result = Resolve-DatabaseSqlConnection `
      -SqlConnection $fakeConnection `
      -BitwardenSecretName 'db-secret' `
      -DatabaseHost 'localhost' `
      -DatabaseName 'ATAPUtilities' `
      -IntegratedSecurity

    $result | Should -Be 'existing-connection'
    Assert-MockCalled Assert-DatabaseSqlConnectionIsOpen -Times 1 -Exactly -Scope It
    Assert-MockCalled Resolve-DatabaseSqlConnectionFromBitwardenSecretName -Times 0 -Exactly -Scope It
    Assert-MockCalled Resolve-DatabaseSqlConnectionFromConnectionParts -Times 0 -Exactly -Scope It
  }

  It 'uses BitwardenSecretName before connection parts' {
    $result = Resolve-DatabaseSqlConnection `
      -BitwardenSecretName 'db-secret' `
      -DatabaseHost 'localhost' `
      -DatabaseName 'ATAPUtilities' `
      -IntegratedSecurity

    $result | Should -Be 'bitwarden:db-secret'
    Assert-MockCalled Resolve-DatabaseSqlConnectionFromBitwardenSecretName -Times 1 -Exactly -Scope It -ParameterFilter {
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

    $result.DatabaseHost | Should -Be 'localhost'
    $result.DatabaseName | Should -Be 'ATAPUtilities'
    $result.InstanceName | Should -Be 'DEVWHERTZING'
    $result.IntegratedSecurity | Should -BeTrue
    $result.BoundParameters.ContainsKey('InstanceName') | Should -BeTrue
  }

  It 'normalizes SecretName from the caller bound-parameter map to BitwardenSecretName' {
    $callerBoundParameters = @{
      SecretName   = 'db-secret'
      DatabaseHost = 'localhost'
      DatabaseName = 'ATAPUtilities'
    }

    $result = Resolve-DatabaseSqlConnection -OriginalPSBoundParameters $callerBoundParameters

    $result | Should -Be 'bitwarden:db-secret'
    Assert-MockCalled Resolve-DatabaseSqlConnectionFromBitwardenSecretName -Times 1 -Exactly -Scope It -ParameterFilter {
      $SecretName -eq 'db-secret'
    }
  }
}

#Requires -Version 7.0
# Pester 5+ tests for Remove-FeatureSharedDb (Stream J4).

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Resolve-DbInstanceName.ps1')
  . (Join-Path $publicDir 'Remove-FeatureSharedDb.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
  if (-not (Get-Command Resolve-DatabaseSqlConnection -ErrorAction SilentlyContinue)) {
    function global:Resolve-DatabaseSqlConnection {
      param(
        [hashtable]$OriginalPSBoundParameters,
        [object]$SqlConnection,
        [string]$BitwardenSecretName,
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
  if (-not (Get-Command Invoke-DatabaseSqlQuery -ErrorAction SilentlyContinue)) {
    function global:Invoke-DatabaseSqlQuery {
      param([object]$SqlConnection, [string]$CommandText, [hashtable]$Parameters, [int]$CommandTimeout)
    }
    $script:createdInvokeDatabaseSqlQueryStub = $true
  }
  if (-not (Get-Command Invoke-DatabaseSqlNonQuery -ErrorAction SilentlyContinue)) {
    function global:Invoke-DatabaseSqlNonQuery {
      param([object]$SqlConnection, [string]$CommandText, [hashtable]$Parameters, [int]$CommandTimeout)
    }
    $script:createdInvokeDatabaseSqlNonQueryStub = $true
  }
}

AfterAll {
  if ($script:createdResolveDatabaseSqlConnectionStub) {
    Remove-Item Function:\Resolve-DatabaseSqlConnection -ErrorAction SilentlyContinue
  }
  if ($script:createdInvokeDatabaseSqlQueryStub) {
    Remove-Item Function:\Invoke-DatabaseSqlQuery -ErrorAction SilentlyContinue
  }
  if ($script:createdInvokeDatabaseSqlNonQueryStub) {
    Remove-Item Function:\Invoke-DatabaseSqlNonQuery -ErrorAction SilentlyContinue
  }
}

Describe 'Remove-FeatureSharedDb' -Tag 'Unit' {
  BeforeEach {
    $script:fakeConnection = [PSCustomObject]@{ State = 'Open' }
    Mock Resolve-DatabaseSqlConnection { $script:fakeConnection }
    Mock Invoke-DatabaseSqlQuery {
      if ($CommandText -like '*sys.databases*%-shared*') {
        return @(
          [PSCustomObject]@{ Name = 'AceCommander-PaymentRefactor-shared' },
          [PSCustomObject]@{ Name = 'AceCommander-LongFeature-shared' }
        )
      }
      return $null
    }
    Mock Invoke-DatabaseSqlNonQuery { 0 }
  }

  It 'drops one canonical feature shared database when -Feature is supplied' {
    $result = Remove-FeatureSharedDb -Application 'AceCommander' -Feature 'PaymentRefactor' -SqlInstance 'test-sql' -Force

    $result.DatabaseName | Should -Be 'AceCommander-PaymentRefactor-shared'
    $result.SqlInstance | Should -Be 'test-sql'
    $result.Dropped | Should -BeTrue
    Assert-MockCalled Resolve-DatabaseSqlConnection -Times 1 -Exactly -Scope It -ParameterFilter {
      $DatabaseHost -eq 'test-sql' -and $DatabaseName -eq 'master'
    }
    Assert-MockCalled Invoke-DatabaseSqlNonQuery -Times 1 -Exactly -Scope It -ParameterFilter {
      $SqlConnection -eq $script:fakeConnection -and $CommandText.Contains('DROP DATABASE [AceCommander-PaymentRefactor-shared]')
    }
  }

  It 'accepts an omitted Feature filter and targets all feature shared databases' {
    $result = @(Remove-FeatureSharedDb -Application 'AceCommander' -SqlInstance 'test-sql' -Force)

    $result.DatabaseName | Should -Be @('AceCommander-PaymentRefactor-shared', 'AceCommander-LongFeature-shared')
    Assert-MockCalled Invoke-DatabaseSqlQuery -Times 1 -Exactly -Scope It -ParameterFilter {
      $CommandText.Contains("LIKE N'AceCommander-%-shared'")
    }
    Assert-MockCalled Invoke-DatabaseSqlNonQuery -Times 2 -Exactly -Scope It -ParameterFilter {
      $CommandText.Contains('DROP DATABASE [AceCommander-')
    }
  }

  It 'lists what would be dropped under -WhatIf without dropping' {
    $result = @(Remove-FeatureSharedDb -Application 'AceCommander' -SqlInstance 'test-sql' -WhatIf)

    $result.ResponseSummary | Should -Contain "would drop feature shared database 'AceCommander-PaymentRefactor-shared'"
    Assert-MockCalled Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
  }

  It 'accepts BitwardenSecretName as its own parameter set' {
    Remove-FeatureSharedDb -Application 'AceCommander' -Feature 'PaymentRefactor' -BitwardenSecretName 'db-secret' -Force | Out-Null

    Assert-MockCalled Resolve-DatabaseSqlConnection -Times 1 -Exactly -Scope It -ParameterFilter {
      $BitwardenSecretName -eq 'db-secret'
    }
  }
}

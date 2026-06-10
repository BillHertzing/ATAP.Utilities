#Requires -Version 7.0
# Pester 5+ tests for Remove-DeveloperScratchDb (Stream J4).

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Resolve-DbInstanceName.ps1')
  . (Join-Path $publicDir 'Remove-DeveloperScratchDb.ps1')

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

Describe 'Remove-DeveloperScratchDb' -Tag 'Unit' {
  BeforeEach {
    $script:fakeConnection = [PSCustomObject]@{ State = 'Open' }
    Mock Resolve-DatabaseSqlConnection { [pscustomobject]@{ Connection = $script:fakeConnection; IsCallerOwned = $false } }
    Mock Invoke-DatabaseSqlQuery {
      if ($CommandText -like '*sys.databases*AceCommander-dev-*') {
        return @(
          [PSCustomObject]@{ Name = 'AceCommander-dev-wh' },
          [PSCustomObject]@{ Name = 'AceCommander-dev-billh' }
        )
      }
      if ($CommandText -like '*sys.databases*AceCommander-PaymentRefactor-*') {
        return @(
          [PSCustomObject]@{ Name = 'AceCommander-PaymentRefactor-wh' },
          [PSCustomObject]@{ Name = 'AceCommander-PaymentRefactor-billh' }
        )
      }
      return $null
    }
    Mock Invoke-DatabaseSqlNonQuery { 0 }
  }

  It 'drops one canonical developer scratch database when GitHandle is supplied' {
    $result = Remove-DeveloperScratchDb -Application 'AceCommander' -GitHandle 'wh' -SqlInstance 'test-sql' -Force

    $result.DatabaseName | Should -Be 'AceCommander-dev-wh'
    $result.SqlInstance | Should -Be 'test-sql'
    $result.Dropped | Should -BeTrue
    Assert-MockCalled Resolve-DatabaseSqlConnection -Times 1 -Exactly -Scope It -ParameterFilter {
      $DatabaseHost -eq 'test-sql' -and $DatabaseName -eq 'master'
    }
    Assert-MockCalled Invoke-DatabaseSqlNonQuery -Times 1 -Exactly -Scope It -ParameterFilter {
      $SqlConnection -eq $script:fakeConnection -and $CommandText.Contains('DROP DATABASE [AceCommander-dev-wh]')
    }
  }

  It 'uses -Feature to filter per-feature-sprint databases' {
    $result = @(Remove-DeveloperScratchDb -Application 'AceCommander' -Feature 'PaymentRefactor' -SqlInstance 'test-sql' -Force)

    $result.DatabaseName | Should -Be @('AceCommander-PaymentRefactor-wh', 'AceCommander-PaymentRefactor-billh')
    Assert-MockCalled Invoke-DatabaseSqlQuery -Times 1 -Exactly -Scope It -ParameterFilter {
      $CommandText.Contains("LIKE N'AceCommander-PaymentRefactor-%'")
    }
    Assert-MockCalled Invoke-DatabaseSqlNonQuery -Times 2 -Exactly -Scope It -ParameterFilter {
      $CommandText.Contains('DROP DATABASE [AceCommander-PaymentRefactor-')
    }
  }

  It 'lists what would be dropped under -WhatIf without dropping' {
    $result = @(Remove-DeveloperScratchDb -Application 'AceCommander' -SqlInstance 'test-sql' -WhatIf)

    $result.ResponseSummary | Should -Contain "would drop disposable database 'AceCommander-dev-wh'"
    Assert-MockCalled Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
  }

  It 'accepts DBConnectionStringSecretName as its own parameter set' {
    Remove-DeveloperScratchDb -Application 'AceCommander' -GitHandle 'wh' -DBConnectionStringSecretName 'db-secret' -Force | Out-Null

    Assert-MockCalled Resolve-DatabaseSqlConnection -Times 1 -Exactly -Scope It -ParameterFilter {
      $DBConnectionStringSecretName -eq 'db-secret'
    }
  }
}

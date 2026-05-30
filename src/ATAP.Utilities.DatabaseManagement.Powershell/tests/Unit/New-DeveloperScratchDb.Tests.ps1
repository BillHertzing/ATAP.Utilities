#Requires -Version 7.0
# Pester 5+ tests for New-DeveloperScratchDb (Stream J2).

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Resolve-DbInstanceName.ps1')
  . (Join-Path $publicDir 'New-DeveloperScratchDb.ps1')

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
  if (-not (Get-Command Invoke-DatabaseSqlScalar -ErrorAction SilentlyContinue)) {
    function global:Invoke-DatabaseSqlScalar {
      param([object]$SqlConnection, [string]$CommandText, [hashtable]$Parameters, [int]$CommandTimeout)
    }
    $script:createdInvokeDatabaseSqlScalarStub = $true
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
  if ($script:createdInvokeDatabaseSqlScalarStub) {
    Remove-Item Function:\Invoke-DatabaseSqlScalar -ErrorAction SilentlyContinue
  }
  if ($script:createdInvokeDatabaseSqlNonQueryStub) {
    Remove-Item Function:\Invoke-DatabaseSqlNonQuery -ErrorAction SilentlyContinue
  }
}

Describe 'New-DeveloperScratchDb' -Tag 'Unit' {
  BeforeEach {
    $script:fakeConnection = [PSCustomObject]@{ State = 'Open' }
    Mock Resolve-DatabaseSqlConnection { [pscustomobject]@{ Connection = $script:fakeConnection; IsCallerOwned = $false } }
    Mock Invoke-DatabaseSqlScalar { $false }
    Mock Invoke-DatabaseSqlNonQuery { 0 }
  }

  It 'creates the canonical developer scratch database when absent' {
    $result = New-DeveloperScratchDb -Application 'AceCommander' -GitHandle 'BillHertzingTooLong' -SqlInstance 'test-sql'

    $result.DatabaseName | Should -Be 'AceCommander-dev-billhertzing'
    $result.SqlInstance | Should -Be 'test-sql'
    $result.Created | Should -BeTrue
    $result.Success | Should -BeTrue
    Assert-MockCalled Resolve-DatabaseSqlConnection -Times 1 -Exactly -Scope It -ParameterFilter {
      $DatabaseHost -eq 'test-sql' -and $DatabaseName -eq 'master'
    }
    Assert-MockCalled Invoke-DatabaseSqlNonQuery -Times 1 -Exactly -Scope It -ParameterFilter {
      $SqlConnection -eq $script:fakeConnection -and $CommandText.Contains('CREATE DATABASE [AceCommander-dev-billhertzing]')
    }
  }

  It 'is idempotent when the database is already present' {
    Mock Invoke-DatabaseSqlScalar { $true }

    $result = New-DeveloperScratchDb -Application 'AceCommander' -GitHandle 'wh' -SqlInstance 'test-sql'

    $result.Created | Should -BeFalse
    $result.ResponseSummary | Should -Be 'already present'
    Assert-MockCalled Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
  }

  It 'accepts DBConnectionStringSecretName as its own parameter set' {
    New-DeveloperScratchDb -Application 'AceCommander' -GitHandle 'wh' -DBConnectionStringSecretName 'db-secret' | Out-Null

    Assert-MockCalled Resolve-DatabaseSqlConnection -Times 1 -Exactly -Scope It -ParameterFilter {
      $DBConnectionStringSecretName -eq 'db-secret'
    }
  }

  It 'honors WhatIf without running CREATE DATABASE' {
    $result = New-DeveloperScratchDb -Application 'AceCommander' -GitHandle 'wh' -SqlInstance 'test-sql' -WhatIf

    $result.Created | Should -BeFalse
    $result.ResponseSummary | Should -Be "would create database 'AceCommander-dev-wh'"
    Assert-MockCalled Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
  }
}

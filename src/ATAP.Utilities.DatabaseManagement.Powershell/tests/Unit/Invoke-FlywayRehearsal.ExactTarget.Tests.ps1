#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }, dbatools, PSFramework

# All SQL/copy/Flyway effects are mocked. No database or fixture file is created.
BeforeAll {
  $public = Join-Path $PSScriptRoot '../../public'
  $private = Join-Path $PSScriptRoot '../../private'
  . (Join-Path $private 'DatabaseSqlConnection.Helpers.ps1')
  . (Join-Path $private 'DatabaseSqlCommand.Helpers.ps1')
  . (Join-Path $public 'Resolve-DatabaseSqlConnection.ps1')
  . (Join-Path $public 'Invoke-Flyway.ps1')
  . (Join-Path $public 'Invoke-FlywayRehearsal.ps1')
  function Invoke-ExactRehearsal553Fixture([hashtable]$Extra = @{}) {
    $parameters = @{
      Application = 'ATAPUtilities'; BuildId = '553'; DatabaseHost = 'fixture'; SqlInstance = 'fixture'
      SourceDatabaseName = 'ATAPUtilities'
    }
    foreach ($key in $Extra.Keys) { $parameters[$key] = $Extra[$key] }
    Invoke-FlywayRehearsal @parameters -Confirm:$false
  }
}

Describe 'Invoke-FlywayRehearsal exact source and clone safety' -Tag 'Unit' {
  BeforeEach {
    $script:oldStaging = $env:ATAP_DATABASE_PACKAGE_STAGING_ROOT
    $env:ATAP_DATABASE_PACKAGE_STAGING_ROOT = 'D:/ATAPArtifacts/Sprint0017/Task17.68.e/ExactTarget553/Virtual'
    $script:capturedFlyway = @{}
    Mock Write-PSFMessage {}
    Mock Resolve-DatabaseSqlConnection {
      [pscustomobject]@{ Connection = [pscustomobject]@{ State = 'Open'; DataSource = 'fixture' }; IsCallerOwned = $true }
    }
    Mock Invoke-DatabaseSqlNonQuery { 0 }
    Mock Connect-DbaInstance { 'synthetic-instance' }
    Mock Copy-DbaDatabase {}
    Mock Test-Path { $true }
    Mock Invoke-Flyway {
      $script:capturedFlyway = @{} + $PesterBoundParameters
      [pscustomobject]@{ Success = $true }
    }
  }
  AfterEach {
    $env:ATAP_DATABASE_PACKAGE_STAGING_ROOT = $script:oldStaging
  }

  It 'preserves generic source cloning without an implicit expected target' {
    $result = Invoke-ExactRehearsal553Fixture @{ Application = 'OtherApp'; SourceDatabaseName = 'OtherSource' }
    $result.Success | Should -BeTrue
    $script:capturedFlyway.DatabaseName | Should -BeExactly 'OtherApp-rehearsal-553'
    $script:capturedFlyway.ContainsKey('ExpectedDatabaseName') | Should -BeFalse
    Should -Invoke Copy-DbaDatabase -Times 1 -Exactly -Scope It -ParameterFilter {
      $Database -eq 'OtherSource' -and $NewName -eq 'OtherApp-rehearsal-553'
    }
  }

  It 'preserves generic empty-source rehearsal' {
    (Invoke-ExactRehearsal553Fixture @{ SourceDatabaseName = ''; Application = 'OtherApp' }).Success | Should -BeTrue
    $script:capturedFlyway.ContainsKey('ExpectedDatabaseName') | Should -BeFalse
    Should -Invoke Copy-DbaDatabase -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 1 -Exactly -Scope It -ParameterFilter {
      $CommandText.Contains('CREATE DATABASE [OtherApp-rehearsal-553]')
    }
  }

  It 'forwards the exact generated or explicit clone <Clone>' -ForEach @(
    @{ Clone = $null; ExpectedClone = 'ATAPUtilities-rehearsal-553' }
    @{ Clone = 'approved-copy-553'; ExpectedClone = 'approved-copy-553' }
  ) {
    $extra = @{ ExpectedSourceDatabaseName = 'ATAPUtilities' }
    if ($null -ne $Clone) { $extra.RehearsalDb = $Clone }
    $result = Invoke-ExactRehearsal553Fixture $extra
    $result.Success | Should -BeTrue
    $script:capturedFlyway.DatabaseName | Should -BeExactly $ExpectedClone
    $script:capturedFlyway.ExpectedDatabaseName | Should -BeExactly $ExpectedClone
    Should -Invoke Copy-DbaDatabase -Times 1 -Exactly -Scope It -ParameterFilter {
      $Database -eq 'ATAPUtilities' -and $NewName -eq $ExpectedClone
    }
  }

  It 'refuses original clone alias <Clone> before every DROP/copy/Flyway path even without binding' -ForEach @(
    @{ Clone = 'ATAPUtilities' }; @{ Clone = 'ataputilities' }; @{ Clone = 'ATAPUtilities ' }
  ) {
    { Invoke-ExactRehearsal553Fixture @{ RehearsalDb = $Clone } } | Should -Throw '*must differ from the source*'
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
    Should -Invoke Connect-DbaInstance -Times 0 -Exactly -Scope It
    Should -Invoke Copy-DbaDatabase -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-Flyway -Times 0 -Exactly -Scope It
  }

  It 'refuses mismatched or missing explicitly bound source <Source>' -ForEach @(
    @{ Source = 'OtherSource' }; @{ Source = 'ataputilities' }; @{ Source = '' }
  ) {
    { Invoke-ExactRehearsal553Fixture @{ SourceDatabaseName = $Source; ExpectedSourceDatabaseName = 'ATAPUtilities' } } |
      Should -Throw '*does not match ExpectedSourceDatabaseName*'
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
    Should -Invoke Copy-DbaDatabase -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-Flyway -Times 0 -Exactly -Scope It
  }

  It 'refuses unsafe bound clone before SQL or copy' {
    { Invoke-ExactRehearsal553Fixture @{ RehearsalDb = "unsafe'clone"; ExpectedSourceDatabaseName = 'ATAPUtilities' } } |
      Should -Throw '*safe exact catalog name*'
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
    Should -Invoke Copy-DbaDatabase -Times 0 -Exactly -Scope It
  }

  It 'retains cleanup of that same clone when the bound Flyway call fails' {
    Mock Invoke-Flyway { throw 'synthetic flyway failure' }
    { Invoke-ExactRehearsal553Fixture @{ ExpectedSourceDatabaseName = 'ATAPUtilities'; RehearsalDb = 'approved-copy-553' } } |
      Should -Throw '*synthetic flyway failure*'
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 2 -Exactly -Scope It -ParameterFilter {
      $CommandText.Contains('DROP DATABASE [approved-copy-553]') -and -not $CommandText.Contains('CREATE DATABASE')
    }
    # One initial DROP and one cleanup DROP occur in the clone path.
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 2 -Exactly -Scope It
  }
}

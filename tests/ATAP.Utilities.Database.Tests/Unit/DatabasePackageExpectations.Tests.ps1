#Requires -Version 7.0
#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

# Contract for Helpers/DatabasePackageExpectations.ps1 and Fixtures/AppliedMigrationLogicalHashes.json (plan B1-1).
BeforeAll {
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
  . (Join-Path $PSScriptRoot '..\Helpers\DatabasePackageExpectations.ps1')
  $package = Get-DatabasePackageExpectation -RepositoryRoot $repoRoot
  $applied = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Fixtures\AppliedMigrationLogicalHashes.json') -Raw | ConvertFrom-Json
  function New-SyntheticExpectation([string[]]$Names) {
    [pscustomobject]@{ Migrations = @($Names | ForEach-Object { [pscustomobject]@{ Name = $_ } }) }
  }
}

Describe 'Database package expectations helper' {
  It 'reads the package version from version.json and requires the allowlist to agree' {
    $version = (Get-Content -LiteralPath (Join-Path $repoRoot 'Database\Flyway\version.json') -Raw | ConvertFrom-Json).version
    $package.SourceVersion | Should -BeExactly $version
    $package.PackageId | Should -BeExactly 'ATAPUtilities.Database'
  }

  It 'binds every allowlisted migration and seed byte to the file on disk' {
    @(Get-DatabasePackageByteDrift -Expectation $package) | Should -BeNullOrEmpty
  }

  It 'orders migrations by unique ascending version and reports the head' {
    $versions = @($package.Migrations.Version)
    ($versions -join '|') | Should -BeExactly (@($versions | Sort-Object -Unique -CaseSensitive) -join '|')
    $package.HeadVersion | Should -BeExactly $versions[-1]
  }

  It 'refuses <Label>' -ForEach @(
    @{ Label = 'a missing owned migration'; Name = 'V00030__B.sql'; Predecessors = @(); Expect = '*exactly once*' }
    @{ Label = 'a predecessor inserted between'; Name = 'V00040__C.sql'; Predecessors = @('V00010__A.sql'); Expect = '*immediately follow*' }
    @{ Label = 'more predecessors than exist'; Name = 'V00010__A.sql'; Predecessors = @('V00005__Z.sql'); Expect = '*fewer predecessors*' }
  ) {
    $synthetic = New-SyntheticExpectation @('V00010__A.sql', 'V00020__X.sql', 'V00040__C.sql')
    { Assert-MigrationLineagePosition -Expectation $synthetic -Name $Name -Predecessors $Predecessors } | Should -Throw $Expect
  }

  It 'accepts a migration with later successors (the head is not frozen)' {
    $synthetic = New-SyntheticExpectation @('V00010__A.sql', 'V00020__X.sql', 'V00040__C.sql')
    { Assert-MigrationLineagePosition -Expectation $synthetic -Name 'V00020__X.sql' -Predecessors @('V00010__A.sql') } | Should -Not -Throw
  }

  It 'matches a frozen pin in either line-ending form and refuses any content change' {
    $path = Join-Path $TestDrive 'pin.sql'
    [IO.File]::WriteAllText($path, "SELECT 1;`nSELECT 2;`n")
    $crlfPin = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes("SELECT 1;`r`nSELECT 2;`r`n")))
    Test-LineEndingStableSha256 -LiteralPath $path -ExpectedSha256 $crlfPin | Should -BeTrue
    [IO.File]::WriteAllText($path, "SELECT 1;`nSELECT 3;`n")
    Test-LineEndingStableSha256 -LiteralPath $path -ExpectedSha256 $crlfPin | Should -BeFalse
  }
}

Describe 'Applied migration logical hashes' {
  It 'records every migration applied on the tiers, in package order, and nothing beyond appliedThrough' {
    $expected = @($package.Migrations | Where-Object { [string]::CompareOrdinal($_.Version, $applied.appliedThrough) -le 0 } | ForEach-Object Name)
    @($applied.migrations.name) | Should -Be $expected
  }

  It 'keeps the logical content of every applied migration unchanged' {
    foreach ($entry in $applied.migrations) {
      Get-LogicalContentSha256 -LiteralPath (Join-Path $repoRoot "Database\Flyway\SQL\$($entry.name)") |
        Should -BeExactly $entry.logicalSha256 -Because $entry.name
    }
  }
}

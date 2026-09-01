#Requires -Version 7.0
#Requires -Module Pester

BeforeAll {
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
  $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
  $expectedMigrations = [ordered]@{
    'V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql' = '401313150D8DCD68E86FDE5E51A6B45D6A03F91389C43EAB5206F8F4115EF962'
    'V00030__Create_AceOutpostContentSummaryPrototype.sql' = '98C0018A4A92A1A8095CA329D93706A4B426016C1C42B69BC3F7CFB865B38179'
  }
  $expectedActiveMigrationNames = @(
    'V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql'
    'V00030__Create_AceOutpostContentSummaryPrototype.sql'
    'V00040__Add_PhiloteValidityPeriod_SameIdentity_Key.sql'
    'V00050__Create_ATAPUtilities_Tag_Root.sql'
    'V00060__Create_Ace_GatherContent_Submission.sql'
  )
  $expectedV00010Tables = @(
    'BuildSet'
    'BuildSetRuleSet'
    'Instantiation'
    'Philote'
    'PhiloteValidityPeriod'
    'Rule'
    'RuleKind'
    'RulePrimitive'
    'RulePrimitiveInput'
    'RuleSet'
    'RuleSetRule'
  )
  $expectedV00010Routines = @(
    'CloseCurrentPhiloteValidityPeriod'
    'CorrectPhiloteValidityPeriodBoundary'
    'CreateFirstPhiloteValidityPeriod'
    'DeletePhiloteValidityPeriod'
    'MergeAdjacentPhiloteValidityPeriods'
    'ReactivatePhiloteValidityPeriod'
    'ReplacePhiloteValidityPeriodSet'
    'SplitPhiloteValidityPeriod'
  )
  $migrationFiles = @(Get-ChildItem -LiteralPath $sqlDirectory -Filter 'V*.sql' -File | Sort-Object Name)
  $migrationText = @{}
  foreach ($migration in $migrationFiles) {
    $migrationText[$migration.Name] = Get-Content -LiteralPath $migration.FullName -Raw
  }

  function Get-LogicalContentSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $LiteralPath)

    $text = [IO.File]::ReadAllText($LiteralPath)
    $normalizedText = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    $bytes = [Text.Encoding]::UTF8.GetBytes($normalizedText)
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
  }

  $fixtureContracts = @(
    [pscustomobject]@{
      Name = 'fresh-current-head'
      StartingVersion = $null
      ExpectedVersions = @('V00010', 'V00030')
      PreservedObject = $null
    }
    [pscustomobject]@{
      Name = 'upgrade-from-current-head'
      StartingVersion = 'V00030'
      ExpectedVersions = @('V00010', 'V00030')
      PreservedObject = 'ATAPUtilities.AceOutpostContentSummaryPrototype'
    }
  )
}

Describe 'Task 15.140.c.T0 immutable current migration baseline' {
  It 'has the exact ordered active migration inventory with unique versions' {
    # Arrange
    $expectedNames = $expectedActiveMigrationNames

    # Act
    $actualNames = @($migrationFiles.Name)
    $versions = @($actualNames | ForEach-Object {
        if ($_ -notmatch '^(V\d+)__') {
          throw "Invalid active migration name: $_"
        }
        $matches[1]
      })

    # Assert
    $actualNames | Should -Be $expectedNames
    @($versions | Group-Object | Where-Object Count -gt 1).Count | Should -Be 0
  }

  It 'pins immutable migration logical content independent of checkout line endings' {
    foreach ($migrationName in $expectedMigrations.Keys) {
      Get-LogicalContentSha256 -LiteralPath (Join-Path $sqlDirectory $migrationName) |
        Should -Be $expectedMigrations[$migrationName] -Because $migrationName
    }
  }

  It 'characterizes the exact V00010 table, table-type, and procedure inventory' {
    # Arrange
    $sql = $migrationText['V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql']

    # Act
    $tables = @([regex]::Matches($sql, '(?im)^\s*CREATE TABLE \[ATAPUtilities\]\.\[(?<name>[^\]]+)\]') |
        ForEach-Object { $_.Groups['name'].Value } | Sort-Object)
    $tableTypes = @([regex]::Matches($sql, "(?s)EXEC sys\.sp_executesql N'CREATE TYPE \[ATAPUtilities\]\.\[(?<name>[^\]]+)\]") |
        ForEach-Object { $_.Groups['name'].Value } | Sort-Object)
    $procedures = @([regex]::Matches($sql, "(?s)EXEC sys\.sp_executesql N'CREATE PROCEDURE \[ATAPUtilities\]\.\[(?<name>[^\]]+)\]") |
        ForEach-Object { $_.Groups['name'].Value } | Sort-Object)

    # Assert
    $tables | Should -Be @($expectedV00010Tables | Sort-Object)
    $tableTypes | Should -Be @('PhiloteValidityPeriodSetInput')
    $procedures | Should -Be @($expectedV00010Routines | Sort-Object)
  }

  It 'preserves V00030 as the isolated historical prototype migration without application writes' {
    # Arrange
    $sql = $migrationText['V00030__Create_AceOutpostContentSummaryPrototype.sql']

    # Act
    $createdTables = @([regex]::Matches($sql, '(?im)^\s*CREATE TABLE \[ATAPUtilities\]\.\[(?<name>[^\]]+)\]') |
        ForEach-Object { $_.Groups['name'].Value })

    # Assert
    $createdTables | Should -Be @('AceOutpostContentSummaryPrototype')
    $sql | Should -Not -Match '(?im)^\s*(INSERT|UPDATE|DELETE|MERGE)\b'
    $sql | Should -Not -Match '(?i)\[Ace\]\.|\[ATAPUtilities\]\.\[(Tag|TagNamespace|TagState)\]'
  }

  It 'contains no authoritative Tag objects in the characterized V00010/V00030 baseline' {
    $allSql = ($expectedMigrations.Keys | ForEach-Object { $migrationText[$_] }) -join "`n"

    foreach ($objectName in @('Tag', 'TagNamespace', 'TagState')) {
      $allSql | Should -Not -Match "(?i)\b(CREATE|ALTER)\s+(TABLE|VIEW|PROCEDURE|FUNCTION|TYPE)\s+\[ATAPUtilities\]\.\[$objectName\]"
    }
  }

  It 'defines deterministic fresh and current-head upgrade fixture expectations' {
    $fixtureContracts.Count | Should -Be 2
    $fixtureContracts[0].Name | Should -Be 'fresh-current-head'
    $fixtureContracts[0].StartingVersion | Should -BeNullOrEmpty
    $fixtureContracts[0].ExpectedVersions | Should -Be @('V00010', 'V00030')
    $fixtureContracts[1].Name | Should -Be 'upgrade-from-current-head'
    $fixtureContracts[1].StartingVersion | Should -Be 'V00030'
    $fixtureContracts[1].ExpectedVersions | Should -Be @('V00010', 'V00030')
    $fixtureContracts[1].PreservedObject | Should -Be 'ATAPUtilities.AceOutpostContentSummaryPrototype'
  }
}

Describe 'Task 15.140.c.T0 disposable database fixture gates' {
  It 'applies the exact V00010 and V00030 head to a fresh disposable database' -Skip {
    throw 'Coordinator must provide a separately authorized disposable-database runner.'
  }

  It 'validates a V00030 current-head database without data loss or prototype reinterpretation' -Skip {
    throw 'Coordinator must provide a separately authorized disposable-database runner.'
  }
}

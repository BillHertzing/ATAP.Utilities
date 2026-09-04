#Requires -Version 7.0
#Requires -Module Pester

BeforeAll {
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
  $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
  $dataDirectory = Join-Path $repoRoot 'Database\Flyway\Data'
  $migrationName = 'V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql'
  $expectedMigrationNames = @(
    'V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql'
    'V00030__Create_AceOutpostContentSummaryPrototype.sql'
    'V00040__Add_PhiloteValidityPeriod_SameIdentity_Key.sql'
    'V00050__Create_ATAPUtilities_Tag_Root.sql'
    'V00060__Create_Ace_GatherContent_Submission.sql'
    'V00070__Create_Ace_AISupervisor_Telemetry.sql'
    'V00080__Create_ATAPUtilities_V4_Core_Identity_And_Overlay.sql'
  )
  $migrationPath = Join-Path $sqlDirectory $migrationName
  $migrationSql = Get-Content -LiteralPath $migrationPath -Raw

  $expectedDataFiles = @(
    'BuildSet.csv'
    'BuildSetRuleSet.csv'
    'Instantiation.csv'
    'Philote.csv'
    'PhiloteValidityPeriod.csv'
    'Rule.csv'
    'RuleKind.csv'
    'RulePrimitive.csv'
    'RulePrimitiveInput.csv'
    'RuleSet.csv'
    'RuleSetRule.csv'
  )
  $expectedProcedureParameters = [ordered]@{
    ReplacePhiloteValidityPeriodSet = 2
    CreateFirstPhiloteValidityPeriod = 4
    CloseCurrentPhiloteValidityPeriod = 3
    ReactivatePhiloteValidityPeriod = 3
    CorrectPhiloteValidityPeriodBoundary = 6
    SplitPhiloteValidityPeriod = 6
    MergeAdjacentPhiloteValidityPeriods = 4
    DeletePhiloteValidityPeriod = 4
  }

  $scriptDomPath = 'C:\Program Files\PowerShell\Modules\SqlServer\22.3.0\coreclr\Microsoft.SqlServer.TransactSql.ScriptDom.dll'
  if (-not (Test-Path -LiteralPath $scriptDomPath -PathType Leaf)) {
    throw "SQL Server ScriptDom is required for source verification: $scriptDomPath"
  }
  Add-Type -LiteralPath $scriptDomPath

  function Parse-TemporalSql {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Sql)

    $errors = [Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
    $reader = [IO.StringReader]::new($Sql)
    $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
    $fragment = $parser.Parse($reader, [ref]$errors)
    [pscustomobject]@{ Fragment = $fragment; Errors = @($errors) }
  }

  function Get-DynamicDefinitions {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Sql)

    @(
      foreach ($match in [regex]::Matches($Sql, "(?s)EXEC sys\.sp_executesql N'(?<body>(?:''|[^'])*)';")) {
        $definition = $match.Groups['body'].Value.Replace("''", "'")
        $parsed = Parse-TemporalSql -Sql $definition
        $statement = $parsed.Fragment.Batches[0].Statements[0]
        $kind = $statement.GetType().Name
        $name = if ($kind -eq 'CreateProcedureStatement') {
          $statement.ProcedureReference.Name.BaseIdentifier.Value
        }
        elseif ($kind -eq 'CreateTypeTableStatement') {
          'PhiloteValidityPeriodSetInput'
        }
        else {
          $kind
        }
        [pscustomobject]@{
          Name = $name
          Kind = $kind
          Statement = $statement
          Definition = $definition
          Errors = $parsed.Errors
        }
      }
    )
  }

  function Get-LogicalContentSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $LiteralPath)

    $text = [IO.File]::ReadAllText($LiteralPath)
    $normalizedText = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    $bytes = [Text.Encoding]::UTF8.GetBytes($normalizedText)
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
  }

  $outerParse = Parse-TemporalSql -Sql $migrationSql
  $dynamicDefinitions = Get-DynamicDefinitions -Sql $migrationSql
}

Describe 'Philote temporal-validity active source contract' {
  It 'contains the exact ordered active migration inventory through V00060' {
    $migrations = @(Get-ChildItem -LiteralPath $sqlDirectory -Filter 'V*.sql' -File | Sort-Object Name)

    @($migrations.Name) | Should -Be $expectedMigrationNames
  }

  It 'contains the exact active seed-input inventory without TimeBlock' {
    $actual = @(Get-ChildItem -LiteralPath $dataDirectory -Filter '*.csv' -File | ForEach-Object Name | Sort-Object)

    $actual | Should -Be @($expectedDataFiles | Sort-Object)
    Test-Path -LiteralPath (Join-Path $dataDirectory 'TimeBlock.csv') | Should -BeFalse
  }

  It 'pins the line-ending-stable approved PhiloteValidityPeriod CSV contract' {
    $path = Join-Path $dataDirectory 'PhiloteValidityPeriod.csv'
    $rows = @(Import-Csv -LiteralPath $path)

    Get-LogicalContentSha256 -LiteralPath $path |
      Should -Be 'FA5EE83E5A9B67307E1BBE1BC38773681FB280F63952678A7F236152271DEF21'
    (Get-Content -LiteralPath $path -First 1) |
      Should -Be 'PhiloteValidityPeriodId,PhiloteId,PreviousValidToUtc,ValidFromUtc,ValidToUtc'
    $rows.Count | Should -Be 22
    @($rows.PhiloteValidityPeriodId | Sort-Object -Unique).Count | Should -Be 22
    @($rows.PhiloteId | Sort-Object -Unique).Count | Should -Be 22
    @($rows | Where-Object ValidFromUtc -NE '2026-08-08T00:00:00.0000000Z').Count | Should -Be 0
    @($rows | Where-Object { -not [string]::IsNullOrEmpty($_.PreviousValidToUtc) }).Count | Should -Be 0
    @($rows | Where-Object { -not [string]::IsNullOrEmpty($_.ValidToUtc) }).Count | Should -Be 0
  }

  It 'embeds the exact CSV period and Philote mappings in the migration' {
    $rows = @(Import-Csv -LiteralPath (Join-Path $dataDirectory 'PhiloteValidityPeriod.csv'))
    $matches = @([regex]::Matches(
      $migrationSql,
      "(?im)^\s*\('(?<period>[0-9a-f-]{36})', '(?<philote>[0-9a-f-]{36})', NULL, CONVERT\(datetime2\(7\), '2026-08-08T00:00:00\.0000000', 126\), NULL\)[,;]?"
    ))

    $migrationMappings = @($matches | ForEach-Object { '{0}|{1}' -f $_.Groups['period'].Value, $_.Groups['philote'].Value } | Sort-Object)
    $csvMappings = @($rows | ForEach-Object { '{0}|{1}' -f $_.PhiloteValidityPeriodId, $_.PhiloteId } | Sort-Object)
    $migrationMappings | Should -Be $csvMappings
  }

  It 'parses the outer migration and every dynamic definition' {
    $outerParse.Errors.Count | Should -Be 0
    $dynamicDefinitions.Count | Should -Be 10
    @($dynamicDefinitions | Where-Object { $_.Errors.Count -ne 0 }).Count | Should -Be 0
  }

  It 'creates the exact table type and eight procedure signatures' {
    $tableTypes = @($dynamicDefinitions | Where-Object Kind -EQ 'CreateTypeTableStatement')
    $procedures = @($dynamicDefinitions | Where-Object Kind -EQ 'CreateProcedureStatement')

    $tableTypes.Count | Should -Be 1
    $tableTypes[0].Name | Should -Be 'PhiloteValidityPeriodSetInput'
    $procedures.Count | Should -Be 8
    @($procedures.Name | Sort-Object) | Should -Be @($expectedProcedureParameters.Keys | Sort-Object)

    foreach ($procedure in $procedures) {
      $procedure.Statement.Parameters.Count | Should -Be $expectedProcedureParameters[$procedure.Name] -Because $procedure.Name
      @($procedure.Statement.Parameters | Where-Object { $null -ne $_.Value }).Count |
        Should -Be 0 -Because "$($procedure.Name) parameters have no defaults"
    }
  }

  It 'retains the exact temporal table and physical totals' {
    $migrationSql | Should -Match '(?s)CREATE TABLE \[ATAPUtilities\]\.\[PhiloteValidityPeriod\].*?\[PhiloteValidityPeriodId\] uniqueidentifier NOT NULL.*?\[PhiloteId\] uniqueidentifier NOT NULL.*?\[PreviousValidToUtc\] datetime2\(7\) NULL.*?\[ValidFromUtc\] datetime2\(7\) NOT NULL.*?\[ValidToUtc\] datetime2\(7\) NULL'
    ([regex]::Matches($migrationSql, '(?im)^\s*CREATE TABLE \[ATAPUtilities\]\.')).Count | Should -Be 11
    ([regex]::Matches($migrationSql, '(?im)^\s*CONSTRAINT \[(PK|FK|UQ|CK)_')).Count | Should -Be 72
  }

  It 'contains no prohibited lifecycle or runtime-seed operation' {
    $migrationSql | Should -Not -Match '(?im)^\s*(CREATE\s+DATABASE|USE\s+|CREATE\s+(LOGIN|USER)|DROP\s+SCHEMA|GRANT\s+|DENY\s+|REVOKE\s+)'
    $migrationSql | Should -Not -Match '(?i)\b(GETDATE|GETUTCDATE|SYSDATETIME|SYSUTCDATETIME|NEWID)\s*\('
  }
}

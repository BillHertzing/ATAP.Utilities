#Requires -Version 7.0
#Requires -Module Pester

<##
.SYNOPSIS
    Verifies the Philote temporal-validity schema, seed, and mutation contract in
    an explicitly supplied disposable database.

.DESCRIPTION
    This test is inert unless both PHILOTE_TEMPORAL_VALIDITY_DATABASE_NAME and
    PHILOTE_TEMPORAL_VALIDITY_DATABASE_SECRET_NAME are supplied by the
    coordinator. The secret is resolved only at execution time and is never
    written to test output. This file never creates or drops a database.
#>

BeforeAll {
  Import-Module -Name SqlServer -ErrorAction Stop

  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
  $dataDirectory = Join-Path $repoRoot 'Database\Flyway\Data'
  function Get-PhiloteTemporalValidityConnection {
    [CmdletBinding()]
    param()

    $secretResolverPath = Join-Path $repoRoot 'src\ATAP.Utilities.BuildTooling.Secrets.PowerShell\public\Get-SecretATAP.ps1'
    if (-not (Get-Command -Name 'Get-SecretATAP' -ErrorAction SilentlyContinue)) {
      . $secretResolverPath
    }

    $secretName = [Environment]::GetEnvironmentVariable('PHILOTE_TEMPORAL_VALIDITY_DATABASE_SECRET_NAME', 'Process')
    $databaseName = [Environment]::GetEnvironmentVariable('PHILOTE_TEMPORAL_VALIDITY_DATABASE_NAME', 'Process')
    $rawConnectionString = Get-SecretATAP -SecretName $secretName
    try {
      $builder = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new([string]$rawConnectionString)
      $builder['Database'] = $databaseName
      $builder['Application Name'] = 'Philote-Temporal-Validity-Disposable-Verification'
      $connection = [Microsoft.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
      $connection.Open()
      return $connection
    }
    finally {
      $rawConnectionString = $null
    }
  }

  function Invoke-PhiloteTemporalValidityScalar {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory)] [Microsoft.Data.SqlClient.SqlConnection] $Connection,
      [Parameter(Mandatory)] [string] $Query,
      [Microsoft.Data.SqlClient.SqlTransaction] $Transaction
    )

    $command = $Connection.CreateCommand()
    try {
      $command.CommandText = $Query
      $command.CommandTimeout = 60
      if ($null -ne $Transaction) {
        $command.Transaction = $Transaction
      }
      return $command.ExecuteScalar()
    }
    finally {
      $command.Dispose()
    }
  }

  function Invoke-PhiloteTemporalValidityRows {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory)] [Microsoft.Data.SqlClient.SqlConnection] $Connection,
      [Parameter(Mandatory)] [string] $Query,
      [Microsoft.Data.SqlClient.SqlTransaction] $Transaction
    )

    $command = $Connection.CreateCommand()
    try {
      $command.CommandText = $Query
      $command.CommandTimeout = 60
      if ($null -ne $Transaction) {
        $command.Transaction = $Transaction
      }
      $reader = $command.ExecuteReader()
      try {
        $rows = [System.Collections.Generic.List[object]]::new()
        while ($reader.Read()) {
          $row = [ordered]@{}
          for ($index = 0; $index -lt $reader.FieldCount; $index++) {
            $row[$reader.GetName($index)] = $reader.GetValue($index)
          }
          $rows.Add([pscustomobject]$row)
        }
        return @($rows)
      }
      finally {
        $reader.Dispose()
      }
    }
    finally {
      $command.Dispose()
    }
  }

  function Invoke-PhiloteTemporalValidityNonQuery {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory)] [Microsoft.Data.SqlClient.SqlConnection] $Connection,
      [Parameter(Mandatory)] [string] $Query,
      [Microsoft.Data.SqlClient.SqlTransaction] $Transaction
    )

    $command = $Connection.CreateCommand()
    try {
      $command.CommandText = $Query
      $command.CommandTimeout = 60
      if ($null -ne $Transaction) {
        $command.Transaction = $Transaction
      }
      return $command.ExecuteNonQuery()
    }
    finally {
      $command.Dispose()
    }
  }

  $expectedTables = @(
    'Philote', 'PhiloteValidityPeriod', 'RuleKind', 'RulePrimitive', 'RulePrimitiveInput',
    'Rule', 'RuleSet', 'RuleSetRule', 'BuildSet', 'BuildSetRuleSet', 'Instantiation'
  )
  $expectedSeedCounts = @{
    Philote            = 22
    PhiloteValidityPeriod = 22
    RuleKind           = 2
    RulePrimitive      = 15
    RulePrimitiveInput = 21
    Rule               = 2
    RuleSet            = 1
    RuleSetRule        = 2
    BuildSet           = 1
    BuildSetRuleSet    = 1
    Instantiation      = 1
  }
}

Describe 'Philote temporal-validity disposable-database verification' -Skip:(
  [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('PHILOTE_TEMPORAL_VALIDITY_DATABASE_NAME', 'Process')) -or
  [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('PHILOTE_TEMPORAL_VALIDITY_DATABASE_SECRET_NAME', 'Process'))
) {
  BeforeAll {
    $connection = Get-PhiloteTemporalValidityConnection
  }

  AfterAll {
    if ($null -ne $connection) {
      $connection.Dispose()
    }
  }

  It 'has exactly the approved object inventory and physical totals' {
    $actualTables = @(Invoke-PhiloteTemporalValidityRows -Connection $connection -Query @'
SELECT t.name AS TableName
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'ATAPUtilities'
ORDER BY t.name;
'@ | ForEach-Object TableName)
    $actualTables | Should -Be ($expectedTables | Sort-Object)

    (Invoke-PhiloteTemporalValidityScalar -Connection $connection -Query @'
SELECT COUNT(*)
FROM sys.columns AS c
JOIN sys.tables AS t ON t.object_id = c.object_id
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'ATAPUtilities';
'@) | Should -Be 45

    (Invoke-PhiloteTemporalValidityScalar -Connection $connection -Query @'
SELECT COUNT(*)
FROM sys.objects AS o
JOIN sys.schemas AS s ON s.schema_id = o.schema_id
WHERE s.name = N'ATAPUtilities'
  AND o.type IN (N'PK', N'F', N'UQ', N'C');
'@) | Should -Be 72

    (Invoke-PhiloteTemporalValidityScalar -Connection $connection -Query @'
SELECT COUNT(*)
FROM sys.procedures AS p
JOIN sys.schemas AS s ON s.schema_id = p.schema_id
WHERE s.name = N'ATAPUtilities'
  AND p.name IN
  (
      N'CreateFirstPhiloteValidityPeriod',
      N'CloseCurrentPhiloteValidityPeriod',
      N'ReactivatePhiloteValidityPeriod',
      N'CorrectPhiloteValidityPeriodBoundary',
      N'SplitPhiloteValidityPeriod',
      N'MergeAdjacentPhiloteValidityPeriods',
      N'DeletePhiloteValidityPeriod',
      N'ReplacePhiloteValidityPeriodSet'
  );
'@) | Should -Be 8

    (Invoke-PhiloteTemporalValidityScalar -Connection $connection -Query @'
SELECT COUNT(*)
FROM sys.table_types AS tt
JOIN sys.schemas AS s ON s.schema_id = tt.schema_id
WHERE s.name = N'ATAPUtilities'
  AND tt.name = N'PhiloteValidityPeriodSetInput';
'@) | Should -Be 1
  }

  It 'has the exact approved seed counts and semantic Philote mappings' {
    foreach ($tableName in $expectedSeedCounts.Keys) {
      $quotedTableName = $tableName.Replace(']', ']]')
      (Invoke-PhiloteTemporalValidityScalar -Connection $connection -Query "SELECT COUNT(*) FROM [ATAPUtilities].[$quotedTableName];") |
        Should -Be $expectedSeedCounts[$tableName]
    }

    (Invoke-PhiloteTemporalValidityScalar -Connection $connection -Query @'
SELECT COUNT(*)
FROM [ATAPUtilities].[Philote]
WHERE [AdditionalIdsStub] IS NOT NULL;
'@) | Should -Be 0

    (Invoke-PhiloteTemporalValidityScalar -Connection $connection -Query @'
SELECT COUNT(*)
FROM (
    SELECT [RuleKindId] AS EntityId, [PhiloteId] FROM [ATAPUtilities].[RuleKind]
    UNION ALL SELECT [RulePrimitiveId], [PhiloteId] FROM [ATAPUtilities].[RulePrimitive]
    UNION ALL SELECT [RuleId], [PhiloteId] FROM [ATAPUtilities].[Rule]
    UNION ALL SELECT [RuleSetId], [PhiloteId] FROM [ATAPUtilities].[RuleSet]
    UNION ALL SELECT [BuildSetId], [PhiloteId] FROM [ATAPUtilities].[BuildSet]
    UNION ALL SELECT [InstantiationId], [PhiloteId] FROM [ATAPUtilities].[Instantiation]
) AS entities
WHERE EntityId <> PhiloteId;
'@) | Should -Be 0

    $expectedPeriods = @(Import-Csv -LiteralPath (Join-Path $dataDirectory 'PhiloteValidityPeriod.csv') |
      Sort-Object PhiloteValidityPeriodId)
    $actualPeriods = @(Invoke-PhiloteTemporalValidityRows -Connection $connection -Query @'
SELECT
    LOWER(CONVERT(nvarchar(36), [PhiloteValidityPeriodId])) AS PhiloteValidityPeriodId,
    LOWER(CONVERT(nvarchar(36), [PhiloteId])) AS PhiloteId,
    [PreviousValidToUtc],
    CONVERT(nvarchar(33), [ValidFromUtc], 126) + N'Z' AS ValidFromUtc,
    [ValidToUtc]
FROM [ATAPUtilities].[PhiloteValidityPeriod]
ORDER BY [PhiloteValidityPeriodId];
'@)
    $actualPeriods.Count | Should -Be 22
    for ($index = 0; $index -lt $expectedPeriods.Count; $index++) {
      $actualPeriods[$index].PhiloteValidityPeriodId | Should -Be $expectedPeriods[$index].PhiloteValidityPeriodId
      $actualPeriods[$index].PhiloteId | Should -Be $expectedPeriods[$index].PhiloteId
      $actualPeriods[$index].PreviousValidToUtc | Should -Be ([DBNull]::Value)
      $actualPeriods[$index].ValidFromUtc | Should -Be $expectedPeriods[$index].ValidFromUtc
      $actualPeriods[$index].ValidToUtc | Should -Be ([DBNull]::Value)
    }
  }

  It 'uses exact half-open point-in-time boundaries' {
    $philoteId = '8e06f2af-52cf-47d5-872e-0d3912f4fda0'

    (Invoke-PhiloteTemporalValidityScalar -Connection $connection -Query @"
SELECT COUNT(*)
FROM [ATAPUtilities].[PhiloteValidityPeriod]
WHERE [PhiloteId] = '$philoteId'
  AND [ValidFromUtc] <= CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126)
  AND ([ValidToUtc] IS NULL OR CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126) < [ValidToUtc]);
"@) | Should -Be 1

    (Invoke-PhiloteTemporalValidityScalar -Connection $connection -Query @"
SELECT COUNT(*)
FROM [ATAPUtilities].[PhiloteValidityPeriod]
WHERE [PhiloteId] = '$philoteId'
  AND [ValidFromUtc] <= CONVERT(datetime2(7), '2026-08-07T23:59:59.9999999', 126)
  AND ([ValidToUtc] IS NULL OR CONVERT(datetime2(7), '2026-08-07T23:59:59.9999999', 126) < [ValidToUtc]);
"@) | Should -Be 0
  }

  It 'rejects every direct-DML invalid chain shape' -ForEach @(
    @{ Name = 'zero duration'; Rows = "('10000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, '2026-01-01T00:00:00', '2026-01-01T00:00:00')" }
    @{ Name = 'reversed endpoints'; Rows = "('10000000-0000-0000-0000-000000000002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, '2026-01-02T00:00:00', '2026-01-01T00:00:00')" }
    @{ Name = 'broken predecessor'; Rows = "('10000000-0000-0000-0000-000000000003', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-01-01T00:00:00', '2026-01-02T00:00:00', '2026-01-03T00:00:00')" }
    @{ Name = 'arbitrary overlap'; Rows = "('10000000-0000-0000-0000-000000000004', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, '2026-01-01T00:00:00', '2026-01-04T00:00:00'), ('10000000-0000-0000-0000-000000000005', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-01-04T00:00:00', '2026-01-03T00:00:00', '2026-01-05T00:00:00')" }
    @{ Name = 'duplicate starts'; Rows = "('10000000-0000-0000-0000-000000000006', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, '2026-01-01T00:00:00', '2026-01-02T00:00:00'), ('10000000-0000-0000-0000-000000000007', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-01-02T00:00:00', '2026-01-01T00:00:00', '2026-01-03T00:00:00')" }
    @{ Name = 'duplicate ends'; Rows = "('10000000-0000-0000-0000-000000000008', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, '2026-01-01T00:00:00', '2026-01-03T00:00:00'), ('10000000-0000-0000-0000-000000000009', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-01-03T00:00:00', '2026-01-02T00:00:00', '2026-01-03T00:00:00')" }
    @{ Name = 'two open ends'; Rows = "('10000000-0000-0000-0000-000000000010', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, '2026-01-01T00:00:00', NULL), ('10000000-0000-0000-0000-000000000011', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, '2026-02-01T00:00:00', NULL)" }
    @{ Name = 'open end followed by another row'; Rows = "('10000000-0000-0000-0000-000000000012', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, '2026-01-01T00:00:00', NULL), ('10000000-0000-0000-0000-000000000013', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, '2026-02-01T00:00:00', '2026-03-01T00:00:00')" }
    @{ Name = 'cycle'; Rows = "('10000000-0000-0000-0000-000000000014', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-01-04T00:00:00', '2026-01-01T00:00:00', '2026-01-02T00:00:00'), ('10000000-0000-0000-0000-000000000015', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2026-01-02T00:00:00', '2026-01-03T00:00:00', '2026-01-04T00:00:00')" }
  ) {
    $transaction = $connection.BeginTransaction()
    try {
      Invoke-PhiloteTemporalValidityNonQuery -Connection $connection -Transaction $transaction -Query @'
INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId], [AdditionalIdsStub])
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL);
'@ | Out-Null

      $action = {
        Invoke-PhiloteTemporalValidityNonQuery -Connection $connection -Transaction $transaction -Query @"
INSERT INTO [ATAPUtilities].[PhiloteValidityPeriod]
    ([PhiloteValidityPeriodId], [PhiloteId], [PreviousValidToUtc], [ValidFromUtc], [ValidToUtc])
VALUES $Rows;
"@
      }
      $action | Should -Throw -Because $Name
    }
    finally {
      $transaction.Rollback()
      $transaction.Dispose()
    }
  }

  It 'executes the complete mutation lifecycle with exact result metadata' {
    $transaction = $connection.BeginTransaction()
    try {
      Invoke-PhiloteTemporalValidityNonQuery -Connection $connection -Transaction $transaction -Query @'
INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId], [AdditionalIdsStub])
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', NULL);
'@ | Out-Null

      $rows = @(Invoke-PhiloteTemporalValidityRows -Connection $connection -Transaction $transaction -Query @'
EXEC [ATAPUtilities].[CreateFirstPhiloteValidityPeriod]
    @PhiloteId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    @PhiloteValidityPeriodId = '20000000-0000-0000-0000-000000000001',
    @ValidFromUtc = '2026-01-01T00:00:00',
    @ValidToUtc = '2026-02-01T00:00:00';
'@)
      $rows.Count | Should -Be 1
      @($rows[0].PSObject.Properties.Name) | Should -Be @(
        'PhiloteValidityPeriodId', 'PhiloteId', 'PreviousValidToUtc', 'ValidFromUtc', 'ValidToUtc'
      )

      $rows = @(Invoke-PhiloteTemporalValidityRows -Connection $connection -Transaction $transaction -Query @'
EXEC [ATAPUtilities].[SplitPhiloteValidityPeriod]
    @PhiloteId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    @PhiloteValidityPeriodId = '20000000-0000-0000-0000-000000000001',
    @ExpectedValidFromUtc = '2026-01-01T00:00:00',
    @ExpectedValidToUtc = '2026-02-01T00:00:00',
    @SplitUtc = '2026-01-15T00:00:00',
    @NewLaterPhiloteValidityPeriodId = '20000000-0000-0000-0000-000000000002';
'@)
      $rows.Count | Should -Be 2
      $rows[0].PhiloteValidityPeriodId | Should -Be ([guid]'20000000-0000-0000-0000-000000000001')
      $rows[1].PhiloteValidityPeriodId | Should -Be ([guid]'20000000-0000-0000-0000-000000000002')

      $rows = @(Invoke-PhiloteTemporalValidityRows -Connection $connection -Transaction $transaction -Query @'
EXEC [ATAPUtilities].[MergeAdjacentPhiloteValidityPeriods]
    @PhiloteId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    @EarlierPhiloteValidityPeriodId = '20000000-0000-0000-0000-000000000001',
    @LaterPhiloteValidityPeriodId = '20000000-0000-0000-0000-000000000002',
    @ExpectedBoundaryUtc = '2026-01-15T00:00:00';
'@)
      $rows.Count | Should -Be 1
      $rows[0].ValidToUtc | Should -Be ([datetime]'2026-02-01T00:00:00')

      $rows = @(Invoke-PhiloteTemporalValidityRows -Connection $connection -Transaction $transaction -Query @'
EXEC [ATAPUtilities].[CorrectPhiloteValidityPeriodBoundary]
    @PhiloteId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    @PhiloteValidityPeriodId = '20000000-0000-0000-0000-000000000001',
    @ExpectedValidFromUtc = '2026-01-01T00:00:00',
    @ExpectedValidToUtc = '2026-02-01T00:00:00',
    @NewValidFromUtc = '2026-01-02T00:00:00',
    @NewValidToUtc = '2026-02-02T00:00:00';
'@)
      $rows.Count | Should -Be 1
      $rows[0].ValidFromUtc | Should -Be ([datetime]'2026-01-02T00:00:00')
      $rows[0].ValidToUtc | Should -Be ([datetime]'2026-02-02T00:00:00')

      $rows = @(Invoke-PhiloteTemporalValidityRows -Connection $connection -Transaction $transaction -Query @'
EXEC [ATAPUtilities].[DeletePhiloteValidityPeriod]
    @PhiloteId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    @PhiloteValidityPeriodId = '20000000-0000-0000-0000-000000000001',
    @ExpectedValidFromUtc = '2026-01-02T00:00:00',
    @ExpectedValidToUtc = '2026-02-02T00:00:00';
'@)
      $rows.Count | Should -Be 0

      $rows = @(Invoke-PhiloteTemporalValidityRows -Connection $connection -Transaction $transaction -Query @'
EXEC [ATAPUtilities].[CreateFirstPhiloteValidityPeriod]
    @PhiloteId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    @PhiloteValidityPeriodId = '20000000-0000-0000-0000-000000000003',
    @ValidFromUtc = '2026-03-01T00:00:00',
    @ValidToUtc = NULL;
'@)
      $rows.Count | Should -Be 1
      $rows[0].ValidToUtc | Should -Be ([DBNull]::Value)

      $rows = @(Invoke-PhiloteTemporalValidityRows -Connection $connection -Transaction $transaction -Query @'
EXEC [ATAPUtilities].[CloseCurrentPhiloteValidityPeriod]
    @PhiloteId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    @ExpectedPhiloteValidityPeriodId = '20000000-0000-0000-0000-000000000003',
    @ValidToUtc = '2026-04-01T00:00:00';
'@)
      $rows.Count | Should -Be 1

      $rows = @(Invoke-PhiloteTemporalValidityRows -Connection $connection -Transaction $transaction -Query @'
EXEC [ATAPUtilities].[ReactivatePhiloteValidityPeriod]
    @PhiloteId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    @PhiloteValidityPeriodId = '20000000-0000-0000-0000-000000000004',
    @ValidFromUtc = '2026-05-01T00:00:00';
'@)
      $rows.Count | Should -Be 2
      $rows[1].PreviousValidToUtc | Should -Be ([datetime]'2026-04-01T00:00:00')

      $rows = @(Invoke-PhiloteTemporalValidityRows -Connection $connection -Transaction $transaction -Query @'
DECLARE @Periods [ATAPUtilities].[PhiloteValidityPeriodSetInput];
INSERT INTO @Periods
    ([PhiloteValidityPeriodId], [PreviousValidToUtc], [ValidFromUtc], [ValidToUtc])
VALUES
    ('20000000-0000-0000-0000-000000000005', NULL, '2027-01-01T00:00:00', '2027-02-01T00:00:00'),
    ('20000000-0000-0000-0000-000000000006', '2027-02-01T00:00:00', '2027-03-01T00:00:00', NULL);
EXEC [ATAPUtilities].[ReplacePhiloteValidityPeriodSet]
    @PhiloteId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    @Periods = @Periods;
'@)
      $rows.Count | Should -Be 2
      $rows[0].PhiloteValidityPeriodId | Should -Be ([guid]'20000000-0000-0000-0000-000000000005')
      $rows[1].PhiloteValidityPeriodId | Should -Be ([guid]'20000000-0000-0000-0000-000000000006')
    }
    finally {
      $transaction.Rollback()
      $transaction.Dispose()
    }
  }

  It 'rejects stale and invalid procedure mutations without changing the set' {
    $invalidCases = @(
      @{ Name = 'closing a bounded row'; Query = "EXEC [ATAPUtilities].[CloseCurrentPhiloteValidityPeriod] @PhiloteId='cccccccc-cccc-cccc-cccc-cccccccccccc', @ExpectedPhiloteValidityPeriodId='30000000-0000-0000-0000-000000000001', @ValidToUtc='2026-03-01T00:00:00';" }
      @{ Name = 'reactivation without a strict gap'; Query = "EXEC [ATAPUtilities].[ReactivatePhiloteValidityPeriod] @PhiloteId='cccccccc-cccc-cccc-cccc-cccccccccccc', @PhiloteValidityPeriodId='30000000-0000-0000-0000-000000000002', @ValidFromUtc='2026-02-01T00:00:00';" }
      @{ Name = 'split at the included start'; Query = "EXEC [ATAPUtilities].[SplitPhiloteValidityPeriod] @PhiloteId='cccccccc-cccc-cccc-cccc-cccccccccccc', @PhiloteValidityPeriodId='30000000-0000-0000-0000-000000000001', @ExpectedValidFromUtc='2026-01-01T00:00:00', @ExpectedValidToUtc='2026-02-01T00:00:00', @SplitUtc='2026-01-01T00:00:00', @NewLaterPhiloteValidityPeriodId='30000000-0000-0000-0000-000000000003';" }
      @{ Name = 'stale delete boundary'; Query = "EXEC [ATAPUtilities].[DeletePhiloteValidityPeriod] @PhiloteId='cccccccc-cccc-cccc-cccc-cccccccccccc', @PhiloteValidityPeriodId='30000000-0000-0000-0000-000000000001', @ExpectedValidFromUtc='2026-01-02T00:00:00', @ExpectedValidToUtc='2026-02-01T00:00:00';" }
    )

    foreach ($invalidCase in $invalidCases) {
      $transaction = $connection.BeginTransaction()
      try {
        Invoke-PhiloteTemporalValidityNonQuery -Connection $connection -Transaction $transaction -Query @'
INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId], [AdditionalIdsStub])
VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', NULL);
'@ | Out-Null

        Invoke-PhiloteTemporalValidityRows -Connection $connection -Transaction $transaction -Query @'
EXEC [ATAPUtilities].[CreateFirstPhiloteValidityPeriod]
    @PhiloteId = 'cccccccc-cccc-cccc-cccc-cccccccccccc',
    @PhiloteValidityPeriodId = '30000000-0000-0000-0000-000000000001',
    @ValidFromUtc = '2026-01-01T00:00:00',
    @ValidToUtc = '2026-02-01T00:00:00';
'@ | Out-Null

        $action = {
          Invoke-PhiloteTemporalValidityRows -Connection $connection -Transaction $transaction -Query $invalidCase.Query
        }
        $action | Should -Throw -Because $invalidCase.Name
      }
      finally {
        if ($transaction.Connection) {
          $transaction.Rollback()
        }
        $transaction.Dispose()
      }

      (Invoke-PhiloteTemporalValidityScalar -Connection $connection -Query @'
SELECT COUNT(*)
FROM [ATAPUtilities].[Philote]
WHERE [PhiloteId] = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
'@) | Should -Be 0
    }
  }

  It 'allows exactly one concurrent reactivation for the same Philote' {
    $testPhiloteId = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
    $cleanupSql = @"
DECLARE @DeleteId uniqueidentifier;
WHILE EXISTS
(
    SELECT 1
    FROM [ATAPUtilities].[PhiloteValidityPeriod]
    WHERE [PhiloteId] = '$testPhiloteId'
)
BEGIN
    SELECT TOP (1) @DeleteId = [PhiloteValidityPeriodId]
    FROM [ATAPUtilities].[PhiloteValidityPeriod]
    WHERE [PhiloteId] = '$testPhiloteId'
    ORDER BY [ValidFromUtc] DESC, [PhiloteValidityPeriodId] DESC;

    DELETE FROM [ATAPUtilities].[PhiloteValidityPeriod]
    WHERE [PhiloteValidityPeriodId] = @DeleteId;
END;
DELETE FROM [ATAPUtilities].[Philote]
WHERE [PhiloteId] = '$testPhiloteId';
"@

    Invoke-PhiloteTemporalValidityNonQuery -Connection $connection -Query $cleanupSql | Out-Null
    Invoke-PhiloteTemporalValidityNonQuery -Connection $connection -Query @"
INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId], [AdditionalIdsStub])
VALUES ('$testPhiloteId', NULL);
INSERT INTO [ATAPUtilities].[PhiloteValidityPeriod]
    ([PhiloteValidityPeriodId], [PhiloteId], [PreviousValidToUtc], [ValidFromUtc], [ValidToUtc])
VALUES
    ('40000000-0000-0000-0000-000000000001', '$testPhiloteId', NULL, '2026-01-01T00:00:00', '2026-02-01T00:00:00');
"@ | Out-Null

    $connections = @(
      [Microsoft.Data.SqlClient.SqlConnection]::new($connection.ConnectionString)
      [Microsoft.Data.SqlClient.SqlConnection]::new($connection.ConnectionString)
    )
    $commands = [Collections.Generic.List[Microsoft.Data.SqlClient.SqlCommand]]::new()
    $tasks = [Collections.Generic.List[System.Threading.Tasks.Task]]::new()

    try {
      foreach ($index in 0..1) {
        $connections[$index].Open()
        $command = $connections[$index].CreateCommand()
        $command.CommandTimeout = 60
        $command.CommandText = @"
EXEC [ATAPUtilities].[ReactivatePhiloteValidityPeriod]
    @PhiloteId = '$testPhiloteId',
    @PhiloteValidityPeriodId = '40000000-0000-0000-0000-00000000000$($index + 2)',
    @ValidFromUtc = '2026-03-01T00:00:00';
"@
        $commands.Add($command)
        $tasks.Add($command.ExecuteReaderAsync())
      }

      try {
        [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]$tasks.ToArray())
      }
      catch [AggregateException] {
        # One expected domain rejection faults its command task.
      }

      @($tasks | Where-Object Status -EQ 'RanToCompletion').Count | Should -Be 1
      @($tasks | Where-Object IsFaulted).Count | Should -Be 1

      foreach ($task in $tasks | Where-Object Status -EQ 'RanToCompletion') {
        $task.Result.Dispose()
      }

      (Invoke-PhiloteTemporalValidityScalar -Connection $connection -Query @"
SELECT COUNT(*)
FROM [ATAPUtilities].[PhiloteValidityPeriod]
WHERE [PhiloteId] = '$testPhiloteId'
  AND [ValidToUtc] IS NULL;
"@) | Should -Be 1
    }
    finally {
      foreach ($command in $commands) {
        $command.Dispose()
      }
      foreach ($secondaryConnection in $connections) {
        $secondaryConnection.Dispose()
      }
      Invoke-PhiloteTemporalValidityNonQuery -Connection $connection -Query $cleanupSql | Out-Null
    }
  }

  It 'has the exact connected HelloWorld graph and rendered content' {
    $graphRows = @(Invoke-PhiloteTemporalValidityRows -Connection $connection -Query @'
SELECT i.[InstantiationCode], bs.[BuildSetCode], rs.[RuleSetCode], rsr.[Ordinal],
       r.[RuleCode], r.[RuleBody], rk.[RuleKindCode], rp.[RulePrimitiveCode]
FROM [ATAPUtilities].[Instantiation] AS i
JOIN [ATAPUtilities].[BuildSet] AS bs ON bs.[BuildSetId] = i.[BuildSetId]
JOIN [ATAPUtilities].[BuildSetRuleSet] AS bsrs ON bsrs.[BuildSetId] = bs.[BuildSetId]
JOIN [ATAPUtilities].[RuleSet] AS rs ON rs.[RuleSetId] = bsrs.[RuleSetId]
JOIN [ATAPUtilities].[RuleSetRule] AS rsr ON rsr.[RuleSetId] = rs.[RuleSetId]
JOIN [ATAPUtilities].[Rule] AS r ON r.[RuleId] = rsr.[RuleId]
JOIN [ATAPUtilities].[RuleKind] AS rk ON rk.[RuleKindId] = r.[RuleKindId]
JOIN [ATAPUtilities].[RulePrimitive] AS rp ON rp.[RulePrimitiveId] = r.[RulePrimitiveId]
ORDER BY rsr.[Ordinal];
'@)
    $graphRows.Count | Should -Be 2
    $graphRows[0].Ordinal | Should -Be 0
    $graphRows[1].Ordinal | Should -Be 1
    $graphRows[0].RuleKindCode | Should -Be 'PowerShell'
    $graphRows[0].RulePrimitiveCode | Should -Be '<complete-powershell-cmdlet>'
    $graphRows[1].RuleKindCode | Should -Be 'Path'
    $graphRows[1].RulePrimitiveCode | Should -Be '<relative-path>'

    $expectedRules = @(Import-Csv -LiteralPath (Join-Path $dataDirectory 'Rule.csv') | Sort-Object RuleCode)
    $actualRules = @(Invoke-PhiloteTemporalValidityRows -Connection $connection -Query @'
SELECT [RuleCode], [RuleBody]
FROM [ATAPUtilities].[Rule]
ORDER BY [RuleCode];
'@)
    $actualRules.Count | Should -Be $expectedRules.Count
    for ($index = 0; $index -lt $expectedRules.Count; $index++) {
      $actualRules[$index].RuleCode | Should -Be $expectedRules[$index].RuleCode
      $actualRules[$index].RuleBody | Should -Be $expectedRules[$index].RuleBody
    }
  }

  It 'has only structured Path primitive-input definitions' {
    (Invoke-PhiloteTemporalValidityScalar -Connection $connection -Query @'
SELECT COUNT(*)
FROM [ATAPUtilities].[RulePrimitiveInput] AS rpi
JOIN [ATAPUtilities].[RulePrimitive] AS rp ON rp.[RulePrimitiveId] = rpi.[RulePrimitiveId]
JOIN [ATAPUtilities].[RuleKind] AS rk ON rk.[RuleKindId] = rp.[RuleKindId]
WHERE rk.[RuleKindCode] <> N'Path'
   OR rp.[RulePrimitiveCode] = N'<atap-utilities-secrets-csproj-path>';
'@) | Should -Be 0
  }
}

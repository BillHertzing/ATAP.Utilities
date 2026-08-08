#Requires -Version 7.0
#Requires -Module Pester

<##
.SYNOPSIS
    Verifies the exact RPRRSBSI V3 schema and initial graph in a disposable database.

.DESCRIPTION
    This test is inert unless both RPRRSBSI_V3_DATABASE_NAME and
    RPRRSBSI_V3_DATABASE_SECRET_NAME are supplied by the coordinator. The secret is
    resolved only at execution time and is never written to the test output.
#>

BeforeAll {
  Import-Module -Name SqlServer -ErrorAction Stop

  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
  $dataDirectory = Join-Path $repoRoot 'Database\Flyway\Data'
  function Get-RprrsbsiV3Connection {
    [CmdletBinding()]
    param()

    $secretResolverPath = Join-Path $repoRoot 'src\ATAP.Utilities.BuildTooling.Secrets.PowerShell\public\Get-SecretATAP.ps1'
    if (-not (Get-Command -Name 'Get-SecretATAP' -ErrorAction SilentlyContinue)) {
      . $secretResolverPath
    }

    $secretName = [Environment]::GetEnvironmentVariable('RPRRSBSI_V3_DATABASE_SECRET_NAME', 'Process')
    $databaseName = [Environment]::GetEnvironmentVariable('RPRRSBSI_V3_DATABASE_NAME', 'Process')
    $rawConnectionString = Get-SecretATAP -SecretName $secretName
    try {
      $builder = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new([string]$rawConnectionString)
      $builder['Database'] = $databaseName
      $builder['Application Name'] = 'RPRRSBSI-V3-Disposable-Verification'
      $connection = [Microsoft.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
      $connection.Open()
      return $connection
    }
    finally {
      $rawConnectionString = $null
    }
  }

  function Invoke-RprrsbsiV3Scalar {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory)] [Microsoft.Data.SqlClient.SqlConnection] $Connection,
      [Parameter(Mandatory)] [string] $Query
    )

    $command = $Connection.CreateCommand()
    try {
      $command.CommandText = $Query
      $command.CommandTimeout = 60
      return $command.ExecuteScalar()
    }
    finally {
      $command.Dispose()
    }
  }

  function Invoke-RprrsbsiV3Rows {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory)] [Microsoft.Data.SqlClient.SqlConnection] $Connection,
      [Parameter(Mandatory)] [string] $Query
    )

    $command = $Connection.CreateCommand()
    try {
      $command.CommandText = $Query
      $command.CommandTimeout = 60
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

  $expectedTables = @(
    'Philote', 'TimeBlock', 'RuleKind', 'RulePrimitive', 'RulePrimitiveInput',
    'Rule', 'RuleSet', 'RuleSetRule', 'BuildSet', 'BuildSetRuleSet', 'Instantiation'
  )
  $expectedSeedCounts = @{
    Philote            = 22
    TimeBlock          = 0
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

Describe 'RPRRSBSI V3 disposable-database verification' -Skip:(
  [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('RPRRSBSI_V3_DATABASE_NAME', 'Process')) -or
  [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('RPRRSBSI_V3_DATABASE_SECRET_NAME', 'Process'))
) {
  BeforeAll {
    $connection = Get-RprrsbsiV3Connection
  }

  AfterAll {
    if ($null -ne $connection) {
      $connection.Dispose()
    }
  }

  It 'has exactly the approved object inventory and physical totals' {
    $actualTables = @(Invoke-RprrsbsiV3Rows -Connection $connection -Query @'
SELECT t.name AS TableName
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'ATAPUtilities'
ORDER BY t.name;
'@ | ForEach-Object TableName)
    $actualTables | Should -Be ($expectedTables | Sort-Object)

    (Invoke-RprrsbsiV3Scalar -Connection $connection -Query @'
SELECT COUNT(*)
FROM sys.columns AS c
JOIN sys.tables AS t ON t.object_id = c.object_id
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'ATAPUtilities';
'@) | Should -Be 46

    (Invoke-RprrsbsiV3Scalar -Connection $connection -Query @'
SELECT COUNT(*)
FROM sys.objects AS o
JOIN sys.schemas AS s ON s.schema_id = o.schema_id
WHERE s.name = N'ATAPUtilities'
  AND o.type IN (N'PK', N'F', N'UQ', N'C');
'@) | Should -Be 70
  }

  It 'has the exact approved seed counts and semantic Philote mappings' {
    foreach ($tableName in $expectedSeedCounts.Keys) {
      $quotedTableName = $tableName.Replace(']', ']]')
      (Invoke-RprrsbsiV3Scalar -Connection $connection -Query "SELECT COUNT(*) FROM [ATAPUtilities].[$quotedTableName];") |
        Should -Be $expectedSeedCounts[$tableName]
    }

    (Invoke-RprrsbsiV3Scalar -Connection $connection -Query @'
SELECT COUNT(*)
FROM [ATAPUtilities].[Philote]
WHERE [AdditionalIdsStub] IS NOT NULL;
'@) | Should -Be 0

    (Invoke-RprrsbsiV3Scalar -Connection $connection -Query @'
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
  }

  It 'has the exact connected HelloWorld graph and rendered content' {
    $graphRows = @(Invoke-RprrsbsiV3Rows -Connection $connection -Query @'
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
    $actualRules = @(Invoke-RprrsbsiV3Rows -Connection $connection -Query @'
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
    (Invoke-RprrsbsiV3Scalar -Connection $connection -Query @'
SELECT COUNT(*)
FROM [ATAPUtilities].[RulePrimitiveInput] AS rpi
JOIN [ATAPUtilities].[RulePrimitive] AS rp ON rp.[RulePrimitiveId] = rpi.[RulePrimitiveId]
JOIN [ATAPUtilities].[RuleKind] AS rk ON rk.[RuleKindId] = rp.[RuleKindId]
WHERE rk.[RuleKindCode] <> N'Path'
   OR rp.[RulePrimitiveCode] = N'<atap-utilities-secrets-csproj-path>';
'@) | Should -Be 0
  }
}

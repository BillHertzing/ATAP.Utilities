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
    'V00070__Create_Ace_AISupervisor_Telemetry.sql'
    'V00080__Create_ATAPUtilities_V4_Core_Identity_And_Overlay.sql'
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


  function Assert-T0BaselinePreflight {
    param([object[]] $Inventory, [string[]] $ExistingObjects = @())
    $versions = @($Inventory | ForEach-Object {
        if ($_.Name -notmatch '^V(\d+)__.+\.sql$') { throw 'Invalid migration name.' }
        [int]$matches[1]
      })
    if (@($versions | Group-Object | Where-Object Count -gt 1).Count) { throw 'Duplicate migration version.' }
    if (($Inventory.Name -join '|') -cne ($expectedActiveMigrationNames -join '|')) { throw 'Unknown or missing migration.' }
    foreach ($entry in $Inventory) {
      if ($expectedMigrations.Contains($entry.Name) -and $entry.Hash -cne $expectedMigrations[$entry.Name]) {
        throw "Baseline checksum drift: $($entry.Name)"
      }
    }
    foreach ($name in $ExistingObjects) {
      if ($name -match '^(?i:ATAPUtilities\.Tag[^.]*|Tags\..+)$') {
        throw "Unapproved baseline Tag object: $name"
      }
    }
  }

  function Assert-T0DisposableTarget {
    param([string] $Marker, [string] $Instance, [string] $Name)
    if ($Marker -cne 'AUTHORIZE_TASK_15_140_C_T0_DISPOSABLE') { throw 'T0 explicit authorization marker required.' }
    $localHosts = @('.', 'localhost', '127.0.0.1', [Environment]::MachineName)
    $parts = $Instance.Split('\')
    if ($parts.Count -ne 2 -or $parts[0] -notin $localHosts -or $parts[1] -ine 'ExpWhertzing') {
      throw 'Only the local ExpWhertzing named instance is permitted.'
    }
    if ($Name -cnotmatch '^ATAPUtilities_Task15140cT0_[0-9a-f]{32}$') { throw 'Unsafe T0 database name.' }
  }

  $sourceInventory = @($migrationFiles | ForEach-Object {
      [pscustomobject]@{ Name = $_.Name; Hash = Get-LogicalContentSha256 $_.FullName }
    })

  # These are the immutable V00010/V00030 primary keys, including composite keys.
  $baselinePrimaryKeys = [ordered]@{
    BuildSet = '[BuildSetId]'
    BuildSetRuleSet = '[BuildSetId], [RuleSetId]'
    Instantiation = '[InstantiationId]'
    Philote = '[PhiloteId]'
    PhiloteValidityPeriod = '[PhiloteValidityPeriodId]'
    Rule = '[RuleId]'
    RuleKind = '[RuleKindId]'
    RulePrimitive = '[RulePrimitiveId]'
    RulePrimitiveInput = '[RulePrimitiveInputId]'
    RuleSet = '[RuleSetId]'
    RuleSetRule = '[RuleSetId], [RuleId]'
    AceOutpostContentSummaryPrototype = '[OperationId]'
  }
  $snapshotQuery = ($baselinePrimaryKeys.GetEnumerator() | ForEach-Object {
      "SELECT (SELECT * FROM [ATAPUtilities].[$($_.Key)] ORDER BY $($_.Value) FOR JSON PATH, INCLUDE_NULL_VALUES);"
    }) -join [Environment]::NewLine
  # Explicit CI collation matches the case-insensitive offline preflight even on a CS database.
  $tagObjectsQuery = "SELECT CONCAT(s.name,'.',o.name) FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id WHERE (s.name COLLATE Latin1_General_100_CI_AS=N'ATAPUtilities' AND o.name COLLATE Latin1_General_100_CI_AS LIKE N'Tag%') OR s.name COLLATE Latin1_General_100_CI_AS=N'Tags';"

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


Describe 'Task 15.140.c.T0 fail-closed fixture preflight' {
  It 'accepts the approved lineage while characterizing only the historical baseline' {
    { Assert-T0BaselinePreflight $sourceInventory } | Should -Not -Throw
  }

  It 'rejects an unknown migration before fixture execution' {
    $inventory = @($sourceInventory) + [pscustomobject]@{ Name = 'V00090__Unknown.sql'; Hash = 'unknown' }
    { Assert-T0BaselinePreflight $inventory } | Should -Throw '*Unknown or missing*'
  }

  It 'rejects duplicate numerical versions including alternate zero padding' {
    $inventory = @($sourceInventory) + [pscustomobject]@{ Name = 'V010__Duplicate.sql'; Hash = 'unknown' }
    { Assert-T0BaselinePreflight $inventory } | Should -Throw '*Duplicate migration*'
  }

  It 'rejects changed logical bytes of either applied baseline migration' {
    foreach ($name in $expectedMigrations.Keys) {
      $inventory = @($sourceInventory | ForEach-Object {
          [pscustomobject]@{ Name = $_.Name; Hash = $(if ($_.Name -eq $name) { 'drift' } else { $_.Hash }) }
        })
      { Assert-T0BaselinePreflight $inventory } | Should -Throw '*checksum drift*'
    }
  }

  It 'rejects every authoritative Tag object in a baseline database' {
    foreach ($name in @('ATAPUtilities.Tag', 'ATAPUtilities.TagNamespace', 'ATAPUtilities.TagState', 'ATAPUtilities.TagAlias', 'ATAPUtilities.TagNamespaceSteward', 'ataputilities.tAgALIAS', 'Tags.LegacyTag', 'tAgS.AnyObject')) {
      { Assert-T0BaselinePreflight $sourceInventory @($name) } | Should -Throw '*Unapproved baseline Tag*'
    }
  }

  It 'rejects missing migrations' {
    { Assert-T0BaselinePreflight @($sourceInventory | Select-Object -Skip 1) } | Should -Throw '*Unknown or missing*'
  }


  It 'pins complete snapshot ordering to each immutable primary key' {
    foreach ($entry in $baselinePrimaryKeys.GetEnumerator()) {
      $sql = if ($entry.Key -eq 'AceOutpostContentSummaryPrototype') {
        $migrationText['V00030__Create_AceOutpostContentSummaryPrototype.sql']
      } else { $migrationText['V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql'] }
      $table = [regex]::Match($sql, '(?is)CREATE TABLE \[ATAPUtilities\]\.\[' + [regex]::Escape($entry.Key) + '\](?<body>.*?)(?=\bCREATE TABLE\b|\z)').Value
      $key = [regex]::Match($table, '(?is)PRIMARY KEY\s*\((?<columns>[^)]+)\)').Groups['columns'].Value
      ($key -replace '\s', '') | Should -Be ($entry.Value -replace '\s', '')
    }
  }

  It 'parses the actual fixture SQL templates and generated full-key snapshot with ScriptDom' {
    $scriptDomPath = 'C:\Program Files\PowerShell\Modules\SqlServer\22.3.0\coreclr\Microsoft.SqlServer.TransactSql.ScriptDom.dll'
    if (-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])) {
      Add-Type -LiteralPath $scriptDomPath
    }
    $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($PSCommandPath, [ref]$tokens, [ref]$errors)
    # Capture query arguments directly from the fixture code, substituting only the
    # generated safe database identifier. Never evaluate source strings or contact SQL.
    $queries = @($snapshotQuery, $tagObjectsQuery) + @($ast.FindAll({
        param($node)
        ($node -is [Management.Automation.Language.StringConstantExpressionAst] -or
         $node -is [Management.Automation.Language.ExpandableStringExpressionAst]) -and
        $node.Value -match '^(CREATE DATABASE|ALTER DATABASE|INSERT INTO|SELECT name FROM|IF \(SELECT COUNT_BIG)'
      }, $true) | ForEach-Object { $_.Value.Replace('$name', 'ATAPUtilities_Task15140cT0_00000000000000000000000000000000') })
    $queries.Count | Should -BeGreaterOrEqual 8
    foreach ($query in $queries) {
      $reader = [IO.StringReader]::new($query)
      $sqlErrors = [Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
      try { $null = $parser.Parse($reader, [ref]$sqlErrors) }
      finally { $reader.Dispose() }
      @($sqlErrors | ForEach-Object { $_.Message }) | Should -BeNullOrEmpty -Because $query
    }
  }

  It 'requires a task-specific marker, local named instance and generated database name' {
    $name = 'ATAPUtilities_Task15140cT0_' + [guid]::NewGuid().ToString('N')
    $marker = 'AUTHORIZE_TASK_15_140_C_T0_DISPOSABLE'
    { Assert-T0DisposableTarget $marker '.\ExpWhertzing' $name } | Should -Not -Throw
    foreach ($badMarker in @('', 'true', '1')) {
      { Assert-T0DisposableTarget $badMarker '.\ExpWhertzing' $name } | Should -Throw '*marker required*'
    }
    foreach ($instance in @('remote\ExpWhertzing', 'localhost', '.\Production', 'localhost\ExpWhertzing;databaseName=other')) {
      { Assert-T0DisposableTarget $marker $instance $name } | Should -Throw '*local ExpWhertzing*'
    }
    foreach ($badName in @('ATAPUtilities', 'ATAPUtilities_Task15140cT0_existing', "$name];DROP DATABASE other")) {
      { Assert-T0DisposableTarget $marker '.\ExpWhertzing' $badName } | Should -Throw '*Unsafe T0*'
    }
  }
}

# A separately authorized run sets both T0-specific process variables. Invalid nonempty
# opt-in fails; a default offline run never resolves native tools or contacts SQL Server.
Describe 'Task 15.140.c.T0 disposable database fixture gates' {
  $requested = -not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable('ATAP_T0_DISPOSABLE_AUTHORIZATION', 'Process'))

  BeforeAll {
    $marker = [Environment]::GetEnvironmentVariable('ATAP_T0_DISPOSABLE_AUTHORIZATION', 'Process')
    $instance = [Environment]::GetEnvironmentVariable('ATAP_T0_DISPOSABLE_SQL_INSTANCE', 'Process')
    $createdDatabases = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)

    function Invoke-T0Sql {
      param([string] $Name, [string] $Query, [switch] $Master)
      Assert-T0DisposableTarget $marker $instance $Name
      if (-not $Master -and -not $createdDatabases.Contains($Name)) { throw 'Database is not owned by this fixture.' }
      $database = if ($Master) { 'master' } else { $Name }
      $output = & sqlcmd -S $instance -E -d $database -b -h -1 -y 0 -Q "SET NOCOUNT ON; $Query" 2>&1
      if ($LASTEXITCODE -ne 0) { throw "T0 SQL failed: $($output -join [Environment]::NewLine)" }
      $output
    }

    function Invoke-T0Flyway {
      param([string] $Name, [string] $Location, [ValidateSet('migrate', 'validate')][string] $Command)
      Assert-T0DisposableTarget $marker $instance $Name
      if (-not $createdDatabases.Contains($Name)) { throw 'Database is not owned by this fixture.' }
      $objects = @(Invoke-T0Sql $Name $tagObjectsQuery | ForEach-Object { "$($_)".Trim() })
      Assert-T0BaselinePreflight $sourceInventory $objects
      foreach ($migrationName in $expectedMigrations.Keys) {
        if ((Get-LogicalContentSha256 (Join-Path $Location $migrationName)) -cne $expectedMigrations[$migrationName]) { throw 'Staged baseline checksum drift.' }
      }
      $url = "jdbc:sqlserver://$instance;databaseName=$Name;integratedSecurity=true;encrypt=true;trustServerCertificate=true"
      $output = & flyway "-configFiles=$repoRoot/Database/Flyway/flyway.toml" "-locations=filesystem:$Location" "-url=$url" '-target=30' '-cleanDisabled=true' '-baselineOnMigrate=false' '-outOfOrder=false' '-validateOnMigrate=true' $Command 2>&1
      if ($LASTEXITCODE -ne 0) { throw "T0 Flyway $Command failed: $($output -join [Environment]::NewLine)" }
    }

    function Get-T0Snapshot {
      param([string] $Name)
      # Full rows, including the unchanged temporal seed, are compared as ordered JSON.
      @(Invoke-T0Sql $Name $snapshotQuery) -join [Environment]::NewLine
    }

    function Invoke-T0Fixture {
      param([switch] $Preserve)
      $name = 'ATAPUtilities_Task15140cT0_' + [guid]::NewGuid().ToString('N')
      Assert-T0DisposableTarget $marker $instance $name
      Assert-T0BaselinePreflight $sourceInventory
      $null = Get-Command sqlcmd -ErrorAction Stop
      $null = Get-Command flyway -ErrorAction Stop
      $location = Join-Path $repoRoot "_generated/Sprint0015/Task15.140/c/T0/completion-20260903/worker/fixtures/$name"
      $null = New-Item -ItemType Directory -Path $location -ErrorAction Stop
      foreach ($migrationName in $expectedMigrations.Keys) {
        Copy-Item -LiteralPath (Join-Path $sqlDirectory $migrationName) -Destination $location -ErrorAction Stop
      }
      try {
        # A successful CREATE alone grants ownership; an existing database is never adopted.
        $null = Invoke-T0Sql $name "CREATE DATABASE [$name];" -Master
        $null = $createdDatabases.Add($name)
        Invoke-T0Flyway $name $location migrate
        if ($Preserve) {
          $null = Invoke-T0Sql $name "INSERT INTO [ATAPUtilities].[AceOutpostContentSummaryPrototype] ([OperationId],[Payload]) VALUES ('15140000-0000-0000-0000-000000000001',N'T0 historical prototype sentinel');"
        }
        $before = Get-T0Snapshot $name
        if ($Preserve) { Invoke-T0Flyway $name $location migrate }
        Invoke-T0Flyway $name $location validate
        (Get-T0Snapshot $name) | Should -BeExactly $before
        $tables = @(Invoke-T0Sql $name "SELECT name FROM sys.tables WHERE schema_id=SCHEMA_ID(N'ATAPUtilities') ORDER BY name;" | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
        $tables | Should -Be @(@($expectedV00010Tables) + 'AceOutpostContentSummaryPrototype' | Sort-Object)
        $routines = @(Invoke-T0Sql $name "SELECT name FROM sys.procedures WHERE schema_id=SCHEMA_ID(N'ATAPUtilities') ORDER BY name;" | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
        $routines | Should -Be @($expectedV00010Routines | Sort-Object)
        $expectedConstraints = @($expectedMigrations.Keys | ForEach-Object {
            [regex]::Matches($migrationText[$_], '(?i)\bCONSTRAINT\s+\[([^\]]+)\]') |
              ForEach-Object { $_.Groups[1].Value }
          } | Sort-Object -Unique)
        $constraints = @(Invoke-T0Sql $name "SELECT name FROM sys.objects WHERE schema_id=SCHEMA_ID(N'ATAPUtilities') AND type IN ('PK','UQ','F','C') ORDER BY name;" | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
        $constraints | Should -Be $expectedConstraints
        $verify = @'
IF (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history])<>2
 OR (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history] WHERE [success]=1 AND TRY_CONVERT(int,[version])=10)<>1
 OR (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history] WHERE [success]=1 AND TRY_CONVERT(int,[version])=30)<>1
 THROW 51901,'Unexpected baseline migration history.',1;
IF TYPE_ID(N'ATAPUtilities.PhiloteValidityPeriodSetInput') IS NULL
 THROW 51902,'Missing baseline table type.',1;
IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Philote])
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PhiloteValidityPeriod])
 THROW 51903,'Baseline temporal seeds missing.',1;
'@
        $null = Invoke-T0Sql $name $verify
      }
      finally {
        if ($createdDatabases.Contains($name)) {
          Assert-T0DisposableTarget $marker $instance $name
          $null = Invoke-T0Sql $name "ALTER DATABASE [$name] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$name];" -Master
          $null = $createdDatabases.Remove($name)
        }
        # Keep exact staged bytes under _generated as execution evidence; no filesystem deletion.
      }
    }
  }

  It 'applies the exact historical V00010/V00030 baseline to a fresh disposable database' -Skip:(-not $requested) {
    Invoke-T0Fixture
  }

  It 'validates and re-migrates a V00030 baseline without changing any existing row' -Skip:(-not $requested) {
    Invoke-T0Fixture -Preserve
  }
}

#Requires -Version 7.0
#Requires -Module Pester

Set-StrictMode -Version Latest

Describe 'V00090 RPRRSBSI V4 Tags relation and assignment static contract' {
  BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $flywayRoot = Join-Path $repoRoot 'Database\Flyway'
    $sqlDirectory = Join-Path $flywayRoot 'SQL'
    $migrationName = 'V00090__Create_ATAPUtilities_Tag_Relations_Assignments_And_Rules.sql'
    $migrationPath = Join-Path $sqlDirectory $migrationName
    $migration = Get-Content -LiteralPath $migrationPath -Raw
    $fixture = Get-Content -LiteralPath (
      Join-Path $PSScriptRoot 'Fixtures\RPRRSBSI-V4-TagsRelationsAssignments.json') -Raw |
      ConvertFrom-Json -Depth 16
    $activeMigrations = @(Get-ChildItem -LiteralPath $sqlDirectory -File -Filter 'V*.sql' | Sort-Object Name)
    $dynamicBodies = @([regex]::Matches(
        $migration,
        "(?s)EXEC\s+sys\.sp_executesql\s+N'(?<body>(?:''|[^'])*)';") |
      ForEach-Object { $_.Groups['body'].Value.Replace("''", "'") })
    $scriptDomPath = 'C:\Program Files\PowerShell\Modules\SqlServer\22.3.0\coreclr\Microsoft.SqlServer.TransactSql.ScriptDom.dll'
    if (-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])) {
      Add-Type -LiteralPath $scriptDomPath
    }
  }

  It 'allocates V00090 as the unique current migration head' {
    @($activeMigrations.Name) | Should -Be @(
      'V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql'
      'V00030__Create_AceOutpostContentSummaryPrototype.sql'
      'V00040__Add_PhiloteValidityPeriod_SameIdentity_Key.sql'
      'V00050__Create_ATAPUtilities_Tag_Root.sql'
      'V00060__Create_Ace_GatherContent_Submission.sql'
      'V00070__Create_Ace_AISupervisor_Telemetry.sql'
      'V00080__Create_ATAPUtilities_V4_Core_Identity_And_Overlay.sql'
      $migrationName
    )
    @($activeMigrations.Name | ForEach-Object {
        if ($_ -notmatch '^(V\d+)__') { throw "Invalid migration name: $_" }
        $matches[1]
      } | Group-Object | Where-Object Count -gt 1).Count | Should -Be 0
  }

  It 'parses the migration and all ten dynamic SQL Server 2022 batches' {
    $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
    $dynamicBodies.Count | Should -Be 10
    foreach ($batch in @($migration) + $dynamicBodies) {
      $reader = [IO.StringReader]::new($batch)
      $errors = [Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
      try { $null = $parser.Parse($reader, [ref]$errors) }
      finally { $reader.Dispose() }
      @($errors | ForEach-Object { "Line $($_.Line), column $($_.Column): $($_.Message)" }) |
        Should -BeNullOrEmpty
    }
  }

  It 'creates the exact relation and assignment schema plus bounded query surface' {
    $tables = @([regex]::Matches($migration, '(?im)^\s*CREATE TABLE \[ATAPUtilities\]\.\[(?<name>[^]]+)\]') |
      ForEach-Object { $_.Groups['name'].Value })
    @($tables | Sort-Object) | Should -Be @($fixture.expectedTables | Sort-Object)
    foreach ($procedure in $fixture.expectedProcedures) {
      $migration | Should -Match "CREATE PROCEDURE \[ATAPUtilities\]\.\[$([regex]::Escape($procedure))\]"
    }
    $migration | Should -Match 'CREATE TYPE \[ATAPUtilities\]\.\[TagRelationRoleCodeInput\]'
    $migration | Should -Match 'IX_TagRelation_Source_Role_Weight_Target'
    $migration | Should -Match 'IX_TagAssignment_Entity_AsOf'
  }

  It 'seeds the exact reviewed role behavior and excludes synonym relations' {
    foreach ($role in $fixture.relationRoles) {
      $migration | Should -Match ([regex]::Escape("N'$($role.code)'"))
      $migration | Should -Match ([regex]::Escape("N'$($role.family)'"))
    }
    $fixture.relationRoles.Count | Should -Be 9
    @($fixture.relationRoles.code) | Should -Not -Contain 'REL_SYNONYM_OF'
    $migration | Should -Not -Match "N'REL_SYNONYM_OF'"
  }

  It 'enforces durable root endpoints, normalized weights and authoring invariants' {
    foreach ($pattern in @(
        'FK_TagRelation_Philote', 'FK_TagRelation_SourceTag', 'FK_TagRelation_TargetTag',
        'UQ_TagRelation_Source_Target_Type', 'CK_TagRelation_NoSelfReference',
        'CK_TagRelation_Weight', 'ATAPUtilities.TagRelationGraph',
        'symmetric mirror or inverse duplicate', 'cycle is prohibited within this Tag relation family',
        'active source-namespace steward'
      )) { $migration | Should -Match $pattern }
    $migration | Should -Match '\[Weight\] decimal\(5,4\) NOT NULL'
    $migration | Should -Match '\[Weight\] > 0\.0000 AND \[Weight\] <= 1\.0000'
  }

  It 'allow-lists only rule and instantiation assignment targets' {
    @($fixture.assignmentEntityTypes) | Should -Be @('rule', 'instantiation')
    $migration | Should -Match "i\.EntityTypeCode=N''rule''"
    $migration | Should -Match "i\.EntityTypeCode=N''instantiation''"
    $migration | Should -Match "i\.EntityTypeCode NOT IN \(N''rule'', N''instantiation''\)"
    $migration | Should -Not -Match "N'(?:ruleset|buildset|content|user)'"
  }

  It 'makes classification-only a database invariant and introduces no grant surface' {
    $migration | Should -Match 'CK_TagAssignment_ClassificationOnly'
    $migration | Should -Match 'CK_TagAssignmentEntityType_ClassificationOnly'
    $migration | Should -Match 'Tags classify and never authorize'
    $migration | Should -Not -Match '(?im)^\s*(?:GRANT|DENY|REVOKE)\b'
    $migration | Should -Not -Match '(?im)^\s*CREATE\s+(?:LOGIN|USER|ROLE)\b'
    $migration | Should -Not -Match '(?i)\b(?:Permission|Capability|Privilege|Authorization)Id\b'
  }

  It 'uses immutable append-close history and explicit provenance without confidence or tenancy' {
    foreach ($column in @('PrincipalId', 'SourceReference', 'OccurredAtUtc', 'RecordedAtUtc')) {
      $migration | Should -Match "\[$column\]"
    }
    $migration | Should -Match 'TagAssignment is append/close-only'
    $migration | Should -Match 'Published TagState deprecation is immutable'
    $migration | Should -Not -Match '(?i)\[(?:TenantId|Confidence|Relevance|Ordinal|SortOrder)\]'
  }

  It 'binds deterministic classification seed Tags to existing Rule and Instantiation roots' {
    foreach ($seed in $fixture.seedTags) {
      $migration | Should -Match ([regex]::Escape("'$($seed.tagId)'"))
      $migration | Should -Match ([regex]::Escape("N'$($seed.code)'"))
      $migration | Should -Match ([regex]::Escape("N'$($seed.entityType)'"))
      $migration | Should -Match ([regex]::Escape("'$($seed.entityId)'"))
    }
    $migration | Should -Match 'Classification only; never grants capability or authorization\.'
  }

  It 'binds package 0.1.8 to every exact migration and seed byte' {
    $version = Get-Content -LiteralPath (Join-Path $flywayRoot 'version.json') -Raw | ConvertFrom-Json
    $allowlist = Get-Content -LiteralPath (Join-Path $flywayRoot 'package-content-allowlist.json') -Raw | ConvertFrom-Json
    $expectedPaths = @(
      @($activeMigrations | ForEach-Object { 'SQL/' + $_.Name })
      @(Get-ChildItem -LiteralPath (Join-Path $flywayRoot 'Data') -File -Filter '*.csv' |
        Sort-Object Name | ForEach-Object { 'Data/' + $_.Name })
    )
    $version.version | Should -Be $fixture.packageVersion
    $allowlist.sourceVersion | Should -Be $version.version
    @($allowlist.files.path) | Should -Be $expectedPaths
    foreach ($entry in $allowlist.files) {
      $path = Join-Path $flywayRoot ($entry.path -replace '/', [IO.Path]::DirectorySeparatorChar)
      (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash | Should -Be $entry.sha256 -Because $entry.path
    }
  }
}

Describe 'V00090 guarded disposable fresh and V00080-upgrade acceptance' {
  $authorization = [Environment]::GetEnvironmentVariable('ATAP_TAGS_V90_DISPOSABLE_AUTHORIZATION', 'Process')
  $localInstance = [Environment]::GetEnvironmentVariable('ATAP_TAGS_V90_DISPOSABLE_SQL_INSTANCE', 'Process')
  $requested = -not [string]::IsNullOrEmpty($authorization)
  $canRun = $requested -and $authorization -ceq 'AUTHORIZE_TASK_15_50_CD_DISPOSABLE' -and
    $localInstance -and (Get-Command flyway -ErrorAction SilentlyContinue) -and
    (Get-Command sqlcmd -ErrorAction SilentlyContinue)

  BeforeAll {
    $authorization = [Environment]::GetEnvironmentVariable('ATAP_TAGS_V90_DISPOSABLE_AUTHORIZATION', 'Process')
    $localInstance = [Environment]::GetEnvironmentVariable('ATAP_TAGS_V90_DISPOSABLE_SQL_INSTANCE', 'Process')
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
    $flywayConfig = Join-Path $repoRoot 'Database\Flyway\flyway.toml'
    $created = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)

    function Assert-TagsV90Target {
      param([string] $Marker, [string] $Instance, [string] $Name)
      if ($Marker -cne 'AUTHORIZE_TASK_15_50_CD_DISPOSABLE') { throw 'V00090 authorization marker required.' }
      $parts = $Instance.Split('\')
      if ($parts.Count -ne 2 -or $parts[0] -notin @('.', 'localhost', '127.0.0.1', [Environment]::MachineName) -or
          $parts[1] -ine 'ExpWhertzing') { throw 'Only the local ExpWhertzing named instance is permitted.' }
      if ($Name -cnotmatch '^ATAPUtilities_Task1550cd_[0-9a-f]{32}$') { throw 'Unsafe V00090 database name.' }
    }

    function Invoke-TagsV90Sql {
      param([string] $Name, [string] $Query, [switch] $Master)
      Assert-TagsV90Target $authorization $localInstance $Name
      if (-not $Master -and -not $created.Contains($Name)) { throw 'Database is not owned by this fixture.' }
      $database = if ($Master) { 'master' } else { $Name }
      $sessionProfile = @(
        'SET ANSI_NULLS ON'
        'SET QUOTED_IDENTIFIER ON'
        'SET ANSI_PADDING ON'
        'SET ANSI_WARNINGS ON'
        'SET ARITHABORT ON'
        'SET CONCAT_NULL_YIELDS_NULL ON'
        'SET NUMERIC_ROUNDABORT OFF'
        'SET NOCOUNT ON'
        'SET XACT_ABORT ON'
      ) -join '; '
      $output = & sqlcmd -S $localInstance -E -d $database -b -h -1 -W -s '|' -Q (
        "$sessionProfile; $Query") 2>&1
      if ($LASTEXITCODE -ne 0) { throw "V00090 SQL failed: $($output -join [Environment]::NewLine)" }
      @($output | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    }

    function Invoke-TagsV90Flyway {
      param([string] $Name, [ValidateSet('80', '90')][string] $Target,
        [ValidateSet('migrate', 'validate')][string] $Command)
      Assert-TagsV90Target $authorization $localInstance $Name
      if (-not $created.Contains($Name)) { throw 'Database is not owned by this fixture.' }
      $jdbcInstance = if ($localInstance.StartsWith('.\')) {
        $localInstance.Replace('.', [Environment]::MachineName)
      } else { $localInstance }
      $url = "jdbc:sqlserver://$jdbcInstance;databaseName=$Name;integratedSecurity=true;encrypt=true;trustServerCertificate=true"
      $arguments = @(
        "-configFiles=$flywayConfig"
        "-locations=filesystem:$sqlDirectory"
        "-url=$url"
        "-target=$Target"
        '-cleanDisabled=true'
        '-baselineOnMigrate=false'
        '-outOfOrder=false'
        '-validateOnMigrate=true'
        $Command
      )
      $output = & flyway @arguments 2>&1
      if ($LASTEXITCODE -ne 0) { throw "V00090 Flyway $Command failed: $($output -join [Environment]::NewLine)" }
    }

    function Get-TagsV90Rows {
      param([string] $Name)
      Invoke-TagsV90Sql $Name @'
DECLARE @sql nvarchar(max)=N'';
SELECT @sql=STRING_AGG(CONVERT(nvarchar(max),N'SELECT N'''+s.name COLLATE DATABASE_DEFAULT+N'.'+t.name COLLATE DATABASE_DEFAULT+N''' AS [ObjectName],COUNT_BIG(*) AS [RowCount],COALESCE(CHECKSUM_AGG(BINARY_CHECKSUM(*)),0) AS [RowChecksum] FROM '+QUOTENAME(s.name)+N'.'+QUOTENAME(t.name)),N' UNION ALL ')
  WITHIN GROUP (ORDER BY s.name,t.name)
FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
WHERE s.name IN (N'ATAPUtilities',N'Ace') AND t.name<>N'flyway_schema_history';
EXEC sys.sp_executesql @sql;
'@
    }

    function Invoke-TagsV90Fixture {
      param([switch] $Upgrade)
      $name = 'ATAPUtilities_Task1550cd_' + [guid]::NewGuid().ToString('N')
      Assert-TagsV90Target $authorization $localInstance $name
      try {
        $null = Invoke-TagsV90Sql $name "CREATE DATABASE [$name];" -Master
        $null = $created.Add($name)
        $beforeRows = $null
        $beforeObjects = $null
        if ($Upgrade) {
          Invoke-TagsV90Flyway $name 80 migrate
          $beforeRows = @(Get-TagsV90Rows $name)
          $beforeObjects = @(Invoke-TagsV90Sql $name "SELECT CONCAT(s.name COLLATE DATABASE_DEFAULT,'.',o.name COLLATE DATABASE_DEFAULT,':',o.type COLLATE DATABASE_DEFAULT) FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id WHERE s.name IN (N'ATAPUtilities',N'Ace') ORDER BY s.name,o.name,o.type;")
        }
        Invoke-TagsV90Flyway $name 90 migrate
        Invoke-TagsV90Flyway $name 90 validate
        if ($Upgrade) {
          $afterRows = @(Get-TagsV90Rows $name)
          $afterByObject = @{}
          foreach ($row in $afterRows) {
            $parts = $row.Split('|')
            $afterByObject[$parts[0]] = [pscustomobject]@{ Count = [long]$parts[1]; Checksum = [int]$parts[2] }
          }
          $appendOnlyObjects = @(
            'ATAPUtilities.Philote', 'ATAPUtilities.PhiloteValidityPeriod',
            'ATAPUtilities.TagNamespace', 'ATAPUtilities.TagNamespaceSteward',
            'ATAPUtilities.Tag', 'ATAPUtilities.TagState'
          )
          foreach ($row in $beforeRows) {
            $parts = $row.Split('|')
            $objectName = $parts[0]
            $afterByObject.ContainsKey($objectName) | Should -BeTrue -Because $objectName
            if ($objectName -in $appendOnlyObjects) {
              $afterByObject[$objectName].Count | Should -BeGreaterOrEqual ([long]$parts[1]) -Because $objectName
            } else {
              $afterByObject[$objectName].Count | Should -Be ([long]$parts[1]) -Because $objectName
              $afterByObject[$objectName].Checksum | Should -Be ([int]$parts[2]) -Because $objectName
            }
          }
          $afterObjects = @(Invoke-TagsV90Sql $name "SELECT CONCAT(s.name COLLATE DATABASE_DEFAULT,'.',o.name COLLATE DATABASE_DEFAULT,':',o.type COLLATE DATABASE_DEFAULT) FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id WHERE s.name IN (N'ATAPUtilities',N'Ace') ORDER BY s.name,o.name,o.type;")
          foreach ($object in $beforeObjects) { $afterObjects | Should -Contain $object }
        }
        $null = Invoke-TagsV90Sql $name @'
IF (SELECT COUNT_BIG(*) FROM dbo.flyway_schema_history WHERE success=1 AND TRY_CONVERT(int,version)=90)<>1 THROW 59100,'V00090 history mismatch.',1;
IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[TagRelationType])<>9 THROW 59101,'Role seed mismatch.',1;
IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[TagAssignmentEntityType])<>2 THROW 59102,'Entity-type seed mismatch.',1;
IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[TagAssignment] WHERE IsClassificationOnly=1)<>2 THROW 59103,'Classification seed mismatch.',1;
IF EXISTS (SELECT 1 FROM [ATAPUtilities].[TagAssignment] WHERE IsClassificationOnly<>1) THROW 59104,'Authorization semantic leaked.',1;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[TagAssignment] ([TagAssignmentId],[TagId],[EntityTypeCode],[EntityId],[ValidFromUtc],[IsClassificationOnly],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
 VALUES ('99000000-0000-0000-0000-000000000001','90020000-0000-0000-0000-000000000010',N'rule','99000000-0000-0000-0000-000000000099','2026-09-04',1,'90000000-0000-0000-0000-000000000001',N'negative','2026-09-04','2026-09-04');
 THROW 59105,'Missing assignment target accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>59023 THROW; END CATCH;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[TagAssignment] ([TagAssignmentId],[TagId],[EntityTypeCode],[EntityId],[ValidFromUtc],[IsClassificationOnly],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
 VALUES ('99000000-0000-0000-0000-000000000002','90020000-0000-0000-0000-000000000010',N'rule','c5c1c63a-4364-4233-9aa1-2a1a5a2ba1f3','2027-01-01',0,'90000000-0000-0000-0000-000000000001',N'negative','2027-01-01','2027-01-01');
 THROW 59106,'Authorization-bearing assignment accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>547 THROW; END CATCH;
EXEC [ATAPUtilities].[CreateTagRelation]
 @TagRelationId='99010000-0000-0000-0000-000000000001',@PhiloteValidityPeriodId='99010000-0000-0000-0000-000000000011',
 @SourceTagId='90020000-0000-0000-0000-000000000010',@TargetTagId='90020000-0000-0000-0000-000000000020',
 @RoleCode=N'REL_RELATED_TO',@Weight=.7500,@EffectiveFromUtc='2026-09-04',
 @PrincipalId='90000000-0000-0000-0000-000000000001',@SourceReference=N'positive',@OccurredAtUtc='2026-09-04',@RecordedAtUtc='2026-09-04';
BEGIN TRY
 EXEC [ATAPUtilities].[CreateTagRelation]
  @TagRelationId='99010000-0000-0000-0000-000000000002',@PhiloteValidityPeriodId='99010000-0000-0000-0000-000000000012',
  @SourceTagId='90020000-0000-0000-0000-000000000020',@TargetTagId='90020000-0000-0000-0000-000000000010',
  @RoleCode=N'REL_RELATED_TO',@Weight=.7500,@EffectiveFromUtc='2026-09-04',
  @PrincipalId='90000000-0000-0000-0000-000000000001',@SourceReference=N'negative',@OccurredAtUtc='2026-09-04',@RecordedAtUtc='2026-09-04';
 THROW 59107,'Symmetric mirror accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>59018 THROW; END CATCH;
EXEC [ATAPUtilities].[CreateTagRelation]
 @TagRelationId='99010000-0000-0000-0000-000000000003',@PhiloteValidityPeriodId='99010000-0000-0000-0000-000000000013',
 @SourceTagId='90020000-0000-0000-0000-000000000010',@TargetTagId='90020000-0000-0000-0000-000000000020',
 @RoleCode=N'REL_BROADER_THAN',@Weight=.9000,@EffectiveFromUtc='2026-09-04',
 @PrincipalId='90000000-0000-0000-0000-000000000001',@SourceReference=N'positive',@OccurredAtUtc='2026-09-04',@RecordedAtUtc='2026-09-04';
BEGIN TRY
 EXEC [ATAPUtilities].[CreateTagRelation]
  @TagRelationId='99010000-0000-0000-0000-000000000004',@PhiloteValidityPeriodId='99010000-0000-0000-0000-000000000014',
  @SourceTagId='90020000-0000-0000-0000-000000000020',@TargetTagId='90020000-0000-0000-0000-000000000010',
  @RoleCode=N'REL_NARROWER_THAN',@Weight=.9000,@EffectiveFromUtc='2026-09-04',
  @PrincipalId='90000000-0000-0000-0000-000000000001',@SourceReference=N'negative',@OccurredAtUtc='2026-09-04',@RecordedAtUtc='2026-09-04';
 THROW 59109,'Inverse duplicate accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>59018 THROW; END CATCH;
BEGIN TRY
 EXEC [ATAPUtilities].[CreateTagRelation]
  @TagRelationId='99010000-0000-0000-0000-000000000005',@PhiloteValidityPeriodId='99010000-0000-0000-0000-000000000015',
  @SourceTagId='90020000-0000-0000-0000-000000000010',@TargetTagId='90020000-0000-0000-0000-000000000020',
  @RoleCode=N'REL_NARROWER_THAN',@Weight=.9000,@EffectiveFromUtc='2026-09-04',
  @PrincipalId='90000000-0000-0000-0000-000000000001',@SourceReference=N'negative',@OccurredAtUtc='2026-09-04',@RecordedAtUtc='2026-09-04';
 THROW 59110,'Prohibited-family cycle accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>59019 THROW; END CATCH;
BEGIN TRY
 EXEC [ATAPUtilities].[CreateTagRelation]
  @TagRelationId='99010000-0000-0000-0000-000000000006',@PhiloteValidityPeriodId='99010000-0000-0000-0000-000000000016',
  @SourceTagId='90020000-0000-0000-0000-000000000010',@TargetTagId='90020000-0000-0000-0000-000000000020',
  @RoleCode=N'REL_SEE_ALSO',@Weight=0,@EffectiveFromUtc='2026-09-04',
  @PrincipalId='90000000-0000-0000-0000-000000000001',@SourceReference=N'negative',@OccurredAtUtc='2026-09-04',@RecordedAtUtc='2026-09-04';
 THROW 59111,'Zero relation weight accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>547 THROW; END CATCH;
DECLARE @Roles [ATAPUtilities].[TagRelationRoleCodeInput];
INSERT INTO @Roles VALUES (N'REL_RELATED_TO');
CREATE TABLE #Edges(TagRelationId uniqueidentifier,SourceTagId uniqueidentifier,TargetTagId uniqueidentifier,RoleCode nvarchar(64),Projection nvarchar(16),Weight decimal(5,4),NamespaceCode nvarchar(128),TargetTagCode nvarchar(128),TagStateId uniqueidentifier,Label nvarchar(256),Description nvarchar(2048),IsDeprecated bit);
INSERT INTO #Edges EXEC [ATAPUtilities].[QueryTagLogicalEdgesAsOf] '90020000-0000-0000-0000-000000000020','2026-09-05',@Roles;
IF NOT EXISTS (SELECT 1 FROM #Edges WHERE Projection=N'symmetric' AND TargetTagId='90020000-0000-0000-0000-000000000010' AND Weight=.7500) THROW 59108,'Symmetric projection missing.',1;
DROP TABLE #Edges;
CREATE TABLE #Assignments(TagAssignmentId uniqueidentifier,EntityTypeCode nvarchar(64),EntityId uniqueidentifier,TagId uniqueidentifier,NamespaceCode nvarchar(128),TagCode nvarchar(128),TagStateId uniqueidentifier,Label nvarchar(256),Description nvarchar(2048),IsDeprecated bit,PrincipalId uniqueidentifier,SourceReference nvarchar(512),OccurredAtUtc datetime2(7),RecordedAtUtc datetime2(7),IsClassificationOnly bit);
INSERT INTO #Assignments EXEC [ATAPUtilities].[QueryTagAssignmentsAsOf] N'rule','616fb394-0b4d-486a-98af-48f1fe461af2','2026-09-05';
IF NOT EXISTS (SELECT 1 FROM #Assignments WHERE TagCode=N'RRSBS_RULE_DEFINITION' AND IsClassificationOnly=1) THROW 59112,'Rule classification query result missing.',1;
DROP TABLE #Assignments;
'@
      }
      finally {
        if ($created.Contains($name)) {
          $null = Invoke-TagsV90Sql $name "ALTER DATABASE [$name] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$name];" -Master
          $null = $created.Remove($name)
        }
      }
    }
  }

  It 'applies and validates V00090 from a fresh disposable database' -Skip:(-not $canRun) {
    Invoke-TagsV90Fixture
  }

  It 'upgrades V00080 while preserving every predecessor object and row fingerprint' -Skip:(-not $canRun) {
    Invoke-TagsV90Fixture -Upgrade
  }

  AfterAll {
    $created.Count | Should -Be 0
  }
}

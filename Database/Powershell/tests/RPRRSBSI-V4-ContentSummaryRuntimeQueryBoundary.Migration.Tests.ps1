#Requires -Version 7.0
#Requires -Module Pester

Set-StrictMode -Version Latest

Describe 'V00130 ContentSummary runtime query boundary source contract' {
  BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $flywayRoot = Join-Path $repoRoot 'Database\Flyway'
    $migrationPath = Join-Path $flywayRoot 'SQL\V00130__Create_ContentSummary_Runtime_Query_Boundary.sql'
    $migration = [IO.File]::ReadAllText($migrationPath)
    $dynamicBodies = @([regex]::Matches(
        $migration,
        "(?s)EXEC\s+sys\.sp_executesql\s+N'(?<body>(?:''|[^'])*)';") |
      ForEach-Object { $_.Groups['body'].Value.Replace("''", "'") })
    $resolver = @($dynamicBodies | Where-Object {
        $_ -match 'CREATE PROCEDURE \[ATAPUtilities\]\.\[ResolveContentSummaryTagCodeAsOfV1\]'
      })
    $scriptDomPath = 'C:\Program Files\PowerShell\Modules\SqlServer\22.3.0\coreclr\Microsoft.SqlServer.TransactSql.ScriptDom.dll'
    if (-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])) {
      Add-Type -LiteralPath $scriptDomPath
    }
  }

  It 'parses the migration and dynamic SQL as SQL Server 2022 syntax' {
    $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
    $dynamicBodies.Count | Should -Be 2
    foreach ($batch in @($migration) + $dynamicBodies) {
      $reader = [IO.StringReader]::new($batch)
      $errors = [Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
      try { $null = $parser.Parse($reader, [ref]$errors) }
      finally { $reader.Dispose() }
      @($errors | ForEach-Object { "Line $($_.Line), column $($_.Column): $($_.Message)" }) |
        Should -BeNullOrEmpty
    }
  }

  It 'returns exactly one ResolvedTagId column, preserves empty, and fails closed for ambiguity' {
    $resolver.Count | Should -Be 1
    $header = ($resolver[0] -split "(?m)^AS\s*$", 2)[0]
    @([regex]::Matches($header, '(?m)^\s*@(?<name>[A-Za-z0-9_]+)\s+') |
        ForEach-Object { $_.Groups['name'].Value }) | Should -Be @('CodeOrAlias', 'AsOfUtc')
    $resolver[0] | Should -Match 'SELECT \[ResolvedTagId\]\s+FROM #ResolvedTag;'
    $resolver[0] | Should -Not -Match 'SELECT \*'
    $resolver[0] | Should -Match 'SELECT DISTINCT resolved\.\[ResolvedTagId\]'
    $resolver[0] | Should -Not -Match 'THROW 60411'
    $resolver[0] | Should -Match 'THROW 60412'
    $resolver[0] | Should -Match "resolved\.\[ResolutionStatusCode\]='Resolved'"
    $resolver[0] | Should -Match 'aliasRow\.\[ValidFromUtc\]<=@AsOfUtc'
    $resolver[0] | Should -Match '@AsOfUtc<aliasRow\.\[ValidToUtc\]'
  }

  It 'creates one environment-neutral role with only the three query executions and required TVP references' {
    $migration | Should -Match 'CREATE ROLE \[ATAPContentSummaryRuntimeQuery\] AUTHORIZATION \[dbo\]'
    @([regex]::Matches($migration, '(?im)^\s*GRANT CONNECT TO \[ATAPContentSummaryRuntimeQuery\];')).Count |
      Should -Be 1
    @([regex]::Matches($migration, '(?im)^\s*GRANT EXECUTE ON OBJECT::')).Count | Should -Be 3
    foreach ($procedure in @(
        'ResolveContentSummaryTagCodeAsOfV1',
        'QueryTagLogicalEdgesAsOf',
        'QueryContentSummaryCandidatesAsOfV1')) {
      $migration | Should -Match ([regex]::Escape(
          "GRANT EXECUTE ON OBJECT::[ATAPUtilities].[$procedure]"))
    }
    @([regex]::Matches($migration, '(?im)^\s*GRANT REFERENCES ON TYPE::')).Count | Should -Be 3
    foreach ($type in @(
        'TagRelationRoleCodeInput',
        'ContentSummaryAuthorizedRepositoryInput',
        'ContentSummaryTagMatchInput')) {
      $migration | Should -Match ([regex]::Escape(
          "GRANT REFERENCES ON TYPE::[ATAPUtilities].[$type]"))
      $migration | Should -Match ([regex]::Escape(
          "GRANT EXECUTE ON TYPE::[ATAPUtilities].[$type]"))
    }
    $migration | Should -Match 'DENY SELECT, INSERT, UPDATE, DELETE, ALTER, VIEW DEFINITION'
    $migration | Should -Not -Match '(?im)^\s*CREATE\s+(?:LOGIN|USER)\b'
    $migration | Should -Not -Match '(?im)^\s*ALTER\s+ROLE.+ADD\s+MEMBER'
    $migration | Should -Not -Match '(?im)^\s*GRANT\s+SELECT\b'
  }

  It 'binds package 0.1.12 to every migration and seed byte' {
    $version = Get-Content -Raw (Join-Path $flywayRoot 'version.json') | ConvertFrom-Json
    $allowlist = Get-Content -Raw (Join-Path $flywayRoot 'package-content-allowlist.json') |
      ConvertFrom-Json -Depth 10
    $expectedPaths = @(
      @(Get-ChildItem (Join-Path $flywayRoot 'SQL') -File -Filter 'V*.sql' |
          Sort-Object Name | ForEach-Object { 'SQL/' + $_.Name })
      @(Get-ChildItem (Join-Path $flywayRoot 'Data') -File -Filter '*.csv' |
          Sort-Object Name | ForEach-Object { 'Data/' + $_.Name }))
    $version.version | Should -Be '0.1.12'
    $allowlist.sourceVersion | Should -Be $version.version
    @($allowlist.files.path) | Should -Be $expectedPaths
    foreach ($entry in $allowlist.files) {
      $path = Join-Path $flywayRoot ($entry.path -replace '/', [IO.Path]::DirectorySeparatorChar)
      (Get-FileHash $path -Algorithm SHA256).Hash | Should -Be $entry.sha256 -Because $entry.path
    }
  }
}

Describe 'V00130 guarded disposable fresh, V00120-upgrade, negative, and recovery acceptance' {
  $authorization = [Environment]::GetEnvironmentVariable(
    'ATAP_CONTENTSUMMARY_V130_DISPOSABLE_AUTHORIZATION', 'Process')
  $localInstance = [Environment]::GetEnvironmentVariable(
    'ATAP_CONTENTSUMMARY_V130_DISPOSABLE_SQL_INSTANCE', 'Process')
  $canRun = $authorization -ceq 'AUTHORIZE_TASK_15_60_E_RUNTIME_QUERY_DISPOSABLE' -and
    $localInstance -and (Get-Command flyway -ErrorAction SilentlyContinue) -and
    (Get-Command sqlcmd -ErrorAction SilentlyContinue)

  BeforeAll {
    $authorization = [Environment]::GetEnvironmentVariable(
      'ATAP_CONTENTSUMMARY_V130_DISPOSABLE_AUTHORIZATION', 'Process')
    $localInstance = [Environment]::GetEnvironmentVariable(
      'ATAP_CONTENTSUMMARY_V130_DISPOSABLE_SQL_INSTANCE', 'Process')
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
    $flywayConfig = Join-Path $repoRoot 'Database\Flyway\flyway.toml'
    $migrationPath = Join-Path $sqlDirectory 'V00130__Create_ContentSummary_Runtime_Query_Boundary.sql'
    $artifactRoot = 'C:\Users\whertzing\ATAPArtifacts\Sprint0015\Task15.60\e\runtime-query-boundary'
    $created = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    if ($canRun) { $null = New-Item -ItemType Directory -Path $artifactRoot -Force }

    function Assert-DisposableTarget {
      param([string] $Name)
      if ($authorization -cne 'AUTHORIZE_TASK_15_60_E_RUNTIME_QUERY_DISPOSABLE') {
        throw 'V00130 disposable authorization marker required.'
      }
      $parts = $localInstance.Split('\')
      if ($parts.Count -ne 2 -or
          $parts[0] -notin @('.', 'localhost', '127.0.0.1', [Environment]::MachineName) -or
          $parts[1] -ine 'ExpWhertzing') {
        throw 'Only the local ExpWhertzing named instance is permitted.'
      }
      if ($Name -cnotmatch '^ATAPUtilities_Task1560e130_[0-9a-f]{32}$') {
        throw 'Unsafe V00130 disposable database name.'
      }
    }

    function New-DisposableDatabase {
      $name = 'ATAPUtilities_Task1560e130_' + [guid]::NewGuid().ToString('N')
      Assert-DisposableTarget $name
      $output = & sqlcmd -S $localInstance -E -d master -b -Q "CREATE DATABASE [$name];" 2>&1
      if ($LASTEXITCODE -ne 0) { throw "Database creation failed: $($output -join [Environment]::NewLine)" }
      $null = $created.Add($name)
      $name
    }

    function Invoke-DisposableSql {
      param([string] $Name, [string] $Query, [switch] $ExpectFailure)
      Assert-DisposableTarget $Name
      if (-not $created.Contains($Name)) { throw 'Database is not owned by this fixture.' }
      $sessionProfile = @(
        'SET ANSI_NULLS ON', 'SET QUOTED_IDENTIFIER ON', 'SET ANSI_PADDING ON',
        'SET ANSI_WARNINGS ON', 'SET ARITHABORT ON', 'SET CONCAT_NULL_YIELDS_NULL ON',
        'SET NUMERIC_ROUNDABORT OFF', 'SET NOCOUNT ON', 'SET XACT_ABORT ON'
      ) -join '; '
      $output = & sqlcmd -S $localInstance -E -d $Name -b -h -1 -W -s '|' -Q (
        "$sessionProfile; $Query") 2>&1
      $failed = $LASTEXITCODE -ne 0
      if ($ExpectFailure -and -not $failed) { throw 'SQL unexpectedly succeeded.' }
      if (-not $ExpectFailure -and $failed) {
        throw "SQL failed: $($output -join [Environment]::NewLine)"
      }
      @($output | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    }

    function Invoke-DisposableFlyway {
      param([string] $Name, [ValidateSet('120', '130')][string] $Target,
        [ValidateSet('migrate', 'validate')][string] $Command)
      Assert-DisposableTarget $Name
      if (-not $created.Contains($Name)) { throw 'Database is not owned by this fixture.' }
      $jdbcInstance = if ($localInstance.StartsWith('.\')) {
        $localInstance.Replace('.', [Environment]::MachineName)
      } else { $localInstance }
      $url = "jdbc:sqlserver://$jdbcInstance;databaseName=$Name;integratedSecurity=true;encrypt=true;trustServerCertificate=true"
      $arguments = @(
        "-configFiles=$flywayConfig", "-locations=filesystem:$sqlDirectory", "-url=$url",
        "-target=$Target", '-cleanDisabled=true', '-baselineOnMigrate=false', '-outOfOrder=false',
        '-validateOnMigrate=true', $Command)
      $output = & flyway @arguments 2>&1
      $logPath = Join-Path $artifactRoot "$Name-$Target-$Command.log"
      [IO.File]::WriteAllLines($logPath, @($output))
      if ($LASTEXITCODE -ne 0) {
        throw "Flyway $Command failed: $($output -join [Environment]::NewLine)"
      }
    }

    function Invoke-MigrationFile {
      param([string] $Name, [switch] $ExpectFailure)
      Assert-DisposableTarget $Name
      if (-not $created.Contains($Name)) { throw 'Database is not owned by this fixture.' }
      $output = & sqlcmd -S $localInstance -E -d $Name -b -i $migrationPath 2>&1
      $failed = $LASTEXITCODE -ne 0
      if ($ExpectFailure -and -not $failed) { throw 'Migration unexpectedly succeeded.' }
      if (-not $ExpectFailure -and $failed) {
        throw "Migration failed: $($output -join [Environment]::NewLine)"
      }
      @($output)
    }
  }

  AfterAll {
    if ($canRun) {
      foreach ($name in $created) {
        Assert-DisposableTarget $name
        $null = & sqlcmd -S $localInstance -E -d master -b -Q (
          "ALTER DATABASE [$name] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$name];") 2>&1
      }
    }
  }

  It 'migrates and validates a fresh database with exact permissions and runtime behavior' -Skip:(-not $canRun) {
    $name = New-DisposableDatabase
    Invoke-DisposableFlyway $name 130 migrate
    Invoke-DisposableFlyway $name 130 validate

    $catalog = Invoke-DisposableSql $name @'
SELECT CONCAT(
  OBJECT_ID(N'[ATAPUtilities].[ResolveContentSummaryTagCodeAsOfV1]',N'P'),'|',
  DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryRuntimeQuery'),'|',
  (SELECT COUNT(*) FROM sys.database_role_members rm
   WHERE rm.role_principal_id=DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryRuntimeQuery')),'|',
  (SELECT COUNT(*) FROM sys.database_permissions p
   WHERE p.grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryRuntimeQuery')
     AND p.state_desc=N'GRANT' AND p.permission_name=N'EXECUTE'
     AND p.class_desc=N'OBJECT_OR_COLUMN'),'|',
  (SELECT COUNT(*) FROM sys.database_permissions p
   WHERE p.grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryRuntimeQuery')
     AND p.state_desc=N'GRANT' AND p.permission_name=N'EXECUTE'
     AND p.class_desc=N'TYPE'),'|',
  (SELECT COUNT(*) FROM sys.database_permissions p
   WHERE p.grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryRuntimeQuery')
     AND p.state_desc=N'GRANT' AND p.permission_name=N'REFERENCES'));
'@
    ($catalog | Select-Object -Last 1) | Should -Match '^\d+\|\d+\|0\|3\|3\|3$'

    $behavior = Invoke-DisposableSql $name @'
CREATE USER [Task1560e130Runtime] WITHOUT LOGIN;
ALTER ROLE [ATAPContentSummaryRuntimeQuery] ADD MEMBER [Task1560e130Runtime];
INSERT INTO [ATAPUtilities].[TagAliasType]
 ([TagAliasTypeId],[AliasTypeCode],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
VALUES ('e1300000-0000-0000-0000-000000000001',N'RuntimeFixture',
 '90000000-0000-0000-0000-000000000001',N'V00130 Pester fixture','2026-09-05','2026-09-05');
INSERT INTO [ATAPUtilities].[TagAlias]
 ([TagAliasId],[TagId],[TagAliasTypeId],[AliasCode],[ValidFromUtc],[ValidToUtc],
  [PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
VALUES ('e1300000-0000-0000-0000-000000000002','90020000-0000-0000-0000-000000000010',
 'e1300000-0000-0000-0000-000000000001',N'RULE_ALIAS','2026-09-05',NULL,
 '90000000-0000-0000-0000-000000000001',N'V00130 Pester fixture','2026-09-05','2026-09-05');
EXECUTE AS USER=N'Task1560e130Runtime';
DECLARE @Canonical table ([ResolvedTagId] uniqueidentifier NOT NULL);
DECLARE @Alias table ([ResolvedTagId] uniqueidentifier NOT NULL);
DECLARE @Unknown table ([ResolvedTagId] uniqueidentifier NOT NULL);
INSERT INTO @Canonical EXEC [ATAPUtilities].[ResolveContentSummaryTagCodeAsOfV1]
 @CodeOrAlias=N'RRSBS_RULE_DEFINITION',@AsOfUtc='2026-09-05T12:00:00';
INSERT INTO @Alias EXEC [ATAPUtilities].[ResolveContentSummaryTagCodeAsOfV1]
 @CodeOrAlias=N'RULE_ALIAS',@AsOfUtc='2026-09-05T12:00:00';
INSERT INTO @Unknown EXEC [ATAPUtilities].[ResolveContentSummaryTagCodeAsOfV1]
 @CodeOrAlias=N'NO_SUCH_TAG',@AsOfUtc='2026-09-05T12:00:00';
DECLARE @RoleCodes [ATAPUtilities].[TagRelationRoleCodeInput];
EXEC [ATAPUtilities].[QueryTagLogicalEdgesAsOf]
 @SourceTagId='90020000-0000-0000-0000-000000000010',
 @AsOfUtc='2026-09-05T12:00:00',@RoleCodes=@RoleCodes;
DECLARE @Repositories [ATAPUtilities].[ContentSummaryAuthorizedRepositoryInput];
DECLARE @Matches [ATAPUtilities].[ContentSummaryTagMatchInput];
EXEC [ATAPUtilities].[QueryContentSummaryCandidatesAsOfV1]
 @AuthorizedRepositories=@Repositories,@TagMatches=@Matches,@MatchMode='Any',
 @AsOfUtc='2026-09-05T12:00:00',@FreshnessMode='CurrentOnly',@Limit=1;
REVERT;
INSERT INTO [ATAPUtilities].[TagNamespace]
 ([TagNamespaceId],[NamespaceCode],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
VALUES ('e1300000-0000-0000-0000-000000000010',N'V00130.AMBIGUITY',
 '90000000-0000-0000-0000-000000000001',N'V00130 Pester fixture','2026-09-05','2026-09-05');
INSERT INTO [ATAPUtilities].[TagNamespaceSteward]
 ([TagNamespaceStewardId],[TagNamespaceId],[PrincipalId],[ValidFromUtc],[ValidToUtc],
  [SourceReference],[OccurredAtUtc],[RecordedAtUtc])
VALUES ('e1300000-0000-0000-0000-000000000014','e1300000-0000-0000-0000-000000000010',
 '90000000-0000-0000-0000-000000000001','2026-09-05',NULL,
 N'V00130 Pester fixture','2026-09-05','2026-09-05');
INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub])
VALUES ('e1300000-0000-0000-0000-000000000011',NULL);
INSERT INTO [ATAPUtilities].[PhiloteValidityPeriod]
 ([PhiloteValidityPeriodId],[PhiloteId],[PreviousValidToUtc],[ValidFromUtc],[ValidToUtc])
VALUES ('e1300000-0000-0000-0000-000000000012','e1300000-0000-0000-0000-000000000011',
 NULL,'2026-09-05',NULL);
INSERT INTO [ATAPUtilities].[Tag]
 ([TagId],[TagNamespaceId],[TagCode],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
VALUES ('e1300000-0000-0000-0000-000000000011','e1300000-0000-0000-0000-000000000010',
 N'RRSBS_RULE_DEFINITION','90000000-0000-0000-0000-000000000001',
 N'V00130 Pester fixture','2026-09-05','2026-09-05');
INSERT INTO [ATAPUtilities].[TagState]
 ([TagStateId],[TagId],[PhiloteValidityPeriodId],[ValidFromUtc],[ValidToUtc],[Label],[Description],
  [TagStateKindCode],[SuccessorTagId],[WithdrawalReason],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
VALUES ('e1300000-0000-0000-0000-000000000013','e1300000-0000-0000-0000-000000000011',
 'e1300000-0000-0000-0000-000000000012','2026-09-05',NULL,N'Ambiguous fixture',NULL,
 'Active',NULL,NULL,'90000000-0000-0000-0000-000000000001',N'V00130 Pester fixture','2026-09-05','2026-09-05');
EXECUTE AS USER=N'Task1560e130Runtime';
DECLARE @Denied int=0,@Ambiguous int=0;
BEGIN TRY SELECT TOP (1) * FROM [ATAPUtilities].[Tag];
END TRY BEGIN CATCH IF ERROR_NUMBER()=229 SET @Denied=1 ELSE THROW; END CATCH;
BEGIN TRY EXEC [ATAPUtilities].[ResolveContentSummaryTagCodeAsOfV1]
 @CodeOrAlias=N'RRSBS_RULE_DEFINITION',@AsOfUtc='2026-09-05T12:00:00';
END TRY BEGIN CATCH IF ERROR_NUMBER()=60412 SET @Ambiguous=1 ELSE THROW; END CATCH;
REVERT;
SELECT CONCAT((SELECT [ResolvedTagId] FROM @Canonical),'|',(SELECT [ResolvedTagId] FROM @Alias),'|',
 (SELECT COUNT(*) FROM @Unknown),'|',@Denied,'|',@Ambiguous);
'@
    ($behavior | Select-Object -Last 1) |
      Should -Be '90020000-0000-0000-0000-000000000010|90020000-0000-0000-0000-000000000010|0|1|1'
  }

  It 'upgrades a V00120 database without creating environment-specific membership' -Skip:(-not $canRun) {
    $name = New-DisposableDatabase
    Invoke-DisposableFlyway $name 120 migrate
    (Invoke-DisposableSql $name "SELECT COALESCE(DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryRuntimeQuery'),0);")[-1] |
      Should -Be '0'
    Invoke-DisposableFlyway $name 130 migrate
    Invoke-DisposableFlyway $name 130 validate
    (Invoke-DisposableSql $name @'
SELECT CONCAT(IIF(OBJECT_ID(N'[ATAPUtilities].[ResolveContentSummaryTagCodeAsOfV1]',N'P') IS NULL,0,1),'|',
 (SELECT COUNT(*) FROM sys.database_role_members rm
  WHERE rm.role_principal_id=DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryRuntimeQuery')));
'@ | Select-Object -Last 1) | Should -Be '1|0'
  }

  It 'rolls back on a role collision and recovers after the collision is removed' -Skip:(-not $canRun) {
    $name = New-DisposableDatabase
    Invoke-DisposableFlyway $name 120 migrate
    $null = Invoke-DisposableSql $name 'CREATE ROLE [ATAPContentSummaryRuntimeQuery] AUTHORIZATION [dbo];'
    $null = Invoke-MigrationFile $name -ExpectFailure
    (Invoke-DisposableSql $name @'
SELECT CONCAT(IIF(OBJECT_ID(N'[ATAPUtilities].[ResolveContentSummaryTagCodeAsOfV1]',N'P') IS NULL,0,1),'|',
 IIF(DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryRuntimeQuery') IS NULL,0,1));
'@ | Select-Object -Last 1) | Should -Be '0|1'
    $null = Invoke-DisposableSql $name 'DROP ROLE [ATAPContentSummaryRuntimeQuery];'
    $null = Invoke-MigrationFile $name
    (Invoke-DisposableSql $name @'
SELECT CONCAT(IIF(OBJECT_ID(N'[ATAPUtilities].[ResolveContentSummaryTagCodeAsOfV1]',N'P') IS NULL,0,1),'|',
 IIF(DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryRuntimeQuery') IS NULL,0,1));
'@ | Select-Object -Last 1) | Should -Be '1|1'
  }
}

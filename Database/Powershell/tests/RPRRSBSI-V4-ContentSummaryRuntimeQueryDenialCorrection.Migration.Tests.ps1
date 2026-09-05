#Requires -Version 7.0
#Requires -Module Pester

Set-StrictMode -Version Latest

Describe 'V00140 ContentSummary runtime query denial correction source contract' {
  BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $flywayRoot = Join-Path $repoRoot 'Database\Flyway'
    $migrationPath = Join-Path $flywayRoot 'SQL\V00140__Correct_ContentSummary_Runtime_Query_Denials.sql'
    $migration = [IO.File]::ReadAllText($migrationPath)
    $scriptDomPath = 'C:\Program Files\PowerShell\Modules\SqlServer\22.3.0\coreclr\Microsoft.SqlServer.TransactSql.ScriptDom.dll'
    if (-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])) {
      Add-Type -LiteralPath $scriptDomPath
    }
  }

  It 'parses as SQL Server 2022 syntax' {
    $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
    $reader = [IO.StringReader]::new($migration)
    $errors = [Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
    try { $null = $parser.Parse($reader, [ref]$errors) }
    finally { $reader.Dispose() }
    @($errors | ForEach-Object { "Line $($_.Line), column $($_.Column): $($_.Message)" }) |
      Should -BeNullOrEmpty
  }

  It 'revokes the inherited schema denial and denies only the three query-owned tables' {
    @([regex]::Matches($migration,
        '(?im)^\s*REVOKE SELECT, INSERT, UPDATE, DELETE, ALTER, VIEW DEFINITION\s+ON SCHEMA::\[ATAPUtilities\]')) |
      Should -HaveCount 1
    @([regex]::Matches($migration,
        '(?im)^\s*DENY SELECT, INSERT, UPDATE, DELETE, ALTER, VIEW DEFINITION\s+ON OBJECT::')) |
      Should -HaveCount 3
    foreach ($table in @('Tag', 'TagAlias', 'ContentSummary')) {
      $migration | Should -Match ([regex]::Escape(
          "ON OBJECT::[ATAPUtilities].[$table] TO [ATAPContentSummaryRuntimeQuery]"))
    }
    $migration | Should -Not -Match 'ON OBJECT::\[ATAPUtilities\]\.\[AceOutpostContentSummaryPrototype\] TO'
    $migration | Should -Not -Match '(?im)^\s*GRANT\b'
    $migration | Should -Not -Match '(?im)^\s*(?:CREATE|ALTER)\s+(?:LOGIN|USER)\b'
    $migration | Should -Not -Match '(?im)^\s*ALTER\s+ROLE.+ADD\s+MEMBER'
  }

  It 'binds package 0.1.13 to every migration and seed byte' {
    $version = Get-Content -Raw (Join-Path $flywayRoot 'version.json') | ConvertFrom-Json
    $allowlist = Get-Content -Raw (Join-Path $flywayRoot 'package-content-allowlist.json') |
      ConvertFrom-Json -Depth 10
    $expectedPaths = @(
      @(Get-ChildItem (Join-Path $flywayRoot 'SQL') -File -Filter 'V*.sql' |
          Sort-Object Name | ForEach-Object { 'SQL/' + $_.Name })
      @(Get-ChildItem (Join-Path $flywayRoot 'Data') -File -Filter '*.csv' |
          Sort-Object Name | ForEach-Object { 'Data/' + $_.Name }))
    $version.version | Should -Be '0.1.13'
    $allowlist.sourceVersion | Should -Be $version.version
    @($allowlist.files.path) | Should -Be $expectedPaths
    foreach ($entry in $allowlist.files) {
      $path = Join-Path $flywayRoot ($entry.path -replace '/', [IO.Path]::DirectorySeparatorChar)
      (Get-FileHash $path -Algorithm SHA256).Hash | Should -Be $entry.sha256 -Because $entry.path
    }
  }
}

Describe 'V00140 guarded disposable fresh, V00130-upgrade, and recovered-state acceptance' {
  $authorization = [Environment]::GetEnvironmentVariable(
    'ATAP_CONTENTSUMMARY_V140_DISPOSABLE_AUTHORIZATION', 'Process')
  $localInstance = [Environment]::GetEnvironmentVariable(
    'ATAP_CONTENTSUMMARY_V140_DISPOSABLE_SQL_INSTANCE', 'Process')
  $canRun = $authorization -ceq 'AUTHORIZE_TASK_15_60_E_V140_DISPOSABLE' -and
    $localInstance -and (Get-Command flyway -ErrorAction SilentlyContinue) -and
    (Get-Command sqlcmd -ErrorAction SilentlyContinue)

  BeforeAll {
    $authorization = [Environment]::GetEnvironmentVariable(
      'ATAP_CONTENTSUMMARY_V140_DISPOSABLE_AUTHORIZATION', 'Process')
    $localInstance = [Environment]::GetEnvironmentVariable(
      'ATAP_CONTENTSUMMARY_V140_DISPOSABLE_SQL_INSTANCE', 'Process')
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
    $flywayConfig = Join-Path $repoRoot 'Database\Flyway\flyway.toml'
    $artifactRoot = 'C:\Users\whertzing\ATAPArtifacts\Sprint0015\Task15.60\e\runtime-query-boundary\v00140'
    $created = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $null = New-Item -ItemType Directory -Path $artifactRoot -Force

    function Assert-Target {
      param([string] $Name)
      if ($authorization -cne 'AUTHORIZE_TASK_15_60_E_V140_DISPOSABLE') {
        throw 'V00140 disposable authorization marker required.'
      }
      $parts = $localInstance.Split('\')
      if ($parts.Count -ne 2 -or
          $parts[0] -notin @('.', 'localhost', '127.0.0.1', [Environment]::MachineName) -or
          $parts[1] -ine 'ExpWhertzing') {
        throw 'Only the local ExpWhertzing named instance is permitted.'
      }
      if ($Name -cnotmatch '^ATAPUtilities_Task1560e140_[0-9a-f]{32}$') {
        throw 'Unsafe V00140 disposable database name.'
      }
    }

    function New-Database {
      $name = 'ATAPUtilities_Task1560e140_' + [guid]::NewGuid().ToString('N')
      Assert-Target $name
      $output = & sqlcmd -S $localInstance -E -d master -b -Q "CREATE DATABASE [$name];" 2>&1
      if ($LASTEXITCODE -ne 0) { throw "Database creation failed: $($output -join [Environment]::NewLine)" }
      $null = $created.Add($name)
      $name
    }

    function Invoke-Sql {
      param([string] $Name, [string] $Query, [switch] $ExpectFailure)
      Assert-Target $Name
      if (-not $created.Contains($Name)) { throw 'Database is not owned by this fixture.' }
      $profile = @(
        'SET ANSI_NULLS ON', 'SET QUOTED_IDENTIFIER ON', 'SET ANSI_PADDING ON',
        'SET ANSI_WARNINGS ON', 'SET ARITHABORT ON', 'SET CONCAT_NULL_YIELDS_NULL ON',
        'SET NUMERIC_ROUNDABORT OFF', 'SET NOCOUNT ON', 'SET XACT_ABORT ON') -join '; '
      $output = & sqlcmd -S $localInstance -E -d $Name -b -h -1 -W -s '|' -Q (
        "$profile; $Query") 2>&1
      $failed = $LASTEXITCODE -ne 0
      if ($ExpectFailure -and -not $failed) { throw 'SQL unexpectedly succeeded.' }
      if (-not $ExpectFailure -and $failed) { throw "SQL failed: $($output -join [Environment]::NewLine)" }
      @($output | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    }

    function Invoke-Flyway {
      param([string] $Name, [ValidateSet('130', '140')][string] $Target,
        [ValidateSet('migrate', 'validate')][string] $Command)
      Assert-Target $Name
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
      [IO.File]::WriteAllLines((Join-Path $artifactRoot "$Name-$Target-$Command.log"), @($output))
      if ($LASTEXITCODE -ne 0) { throw "Flyway $Command failed: $($output -join [Environment]::NewLine)" }
    }

    function Add-RuntimeFixture {
      param([string] $Name)
      $null = Invoke-Sql $Name @'
CREATE USER [Task1560e140Runtime] WITHOUT LOGIN;
GRANT SELECT, INSERT ON OBJECT::[ATAPUtilities].[AceOutpostContentSummaryPrototype]
 TO [Task1560e140Runtime];
ALTER ROLE [ATAPContentSummaryRuntimeQuery] ADD MEMBER [Task1560e140Runtime];
'@
    }

    function Get-RuntimeProof {
      param([string] $Name)
      Invoke-Sql $Name @'
EXECUTE AS USER=N'Task1560e140Runtime';
DECLARE @Resolver table ([ResolvedTagId] uniqueidentifier NOT NULL);
INSERT INTO @Resolver EXEC [ATAPUtilities].[ResolveContentSummaryTagCodeAsOfV1]
 @CodeOrAlias=N'RRSBS_RULE_DEFINITION',@AsOfUtc='2026-09-05T12:00:00';
DECLARE @RoleCodes [ATAPUtilities].[TagRelationRoleCodeInput];
EXEC [ATAPUtilities].[QueryTagLogicalEdgesAsOf]
 @SourceTagId='90020000-0000-0000-0000-000000000010',
 @AsOfUtc='2026-09-05T12:00:00',@RoleCodes=@RoleCodes;
DECLARE @Repositories [ATAPUtilities].[ContentSummaryAuthorizedRepositoryInput];
DECLARE @Matches [ATAPUtilities].[ContentSummaryTagMatchInput];
EXEC [ATAPUtilities].[QueryContentSummaryCandidatesAsOfV1]
 @AuthorizedRepositories=@Repositories,@TagMatches=@Matches,@MatchMode='Any',
 @AsOfUtc='2026-09-05T12:00:00',@FreshnessMode='CurrentOnly',@Limit=1;
DECLARE @OperationId uniqueidentifier=NEWID(),@Denied int=0;
INSERT INTO [ATAPUtilities].[AceOutpostContentSummaryPrototype] ([OperationId],[Payload])
 VALUES (@OperationId,N'V00140 startup fixture');
IF (SELECT [Payload] FROM [ATAPUtilities].[AceOutpostContentSummaryPrototype]
 WHERE [OperationId]=@OperationId)=N'V00140 startup fixture' SET @Denied=0 ELSE THROW 60510,N'Prototype replay failed.',1;
BEGIN TRY SELECT TOP (1) * FROM [ATAPUtilities].[Tag];
END TRY BEGIN CATCH IF ERROR_NUMBER()=229 SET @Denied+=1 ELSE THROW; END CATCH;
BEGIN TRY SELECT TOP (1) * FROM [ATAPUtilities].[TagAlias];
END TRY BEGIN CATCH IF ERROR_NUMBER()=229 SET @Denied+=1 ELSE THROW; END CATCH;
BEGIN TRY SELECT TOP (1) * FROM [ATAPUtilities].[ContentSummary];
END TRY BEGIN CATCH IF ERROR_NUMBER()=229 SET @Denied+=1 ELSE THROW; END CATCH;
REVERT;
SELECT CONCAT((SELECT [ResolvedTagId] FROM @Resolver),'|',@Denied);
'@
    }
  }

  AfterAll {
    if ($canRun) {
      foreach ($name in $created) {
        Assert-Target $name
        $null = & sqlcmd -S $localInstance -E -d master -b -Q (
          "ALTER DATABASE [$name] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$name];") 2>&1
      }
    }
  }

  It 'preserves startup access and query confinement on a fresh V00140 database' -Skip:(-not $canRun) {
    $name = New-Database
    Invoke-Flyway $name 140 migrate
    Invoke-Flyway $name 140 validate
    Add-RuntimeFixture $name
    (Get-RuntimeProof $name | Select-Object -Last 1) |
      Should -Be '90020000-0000-0000-0000-000000000010|3'
  }

  It 'reproduces V00130 denial precedence and recovers through V00140' -Skip:(-not $canRun) {
    $name = New-Database
    Invoke-Flyway $name 130 migrate
    Add-RuntimeFixture $name
    $blocked = Invoke-Sql $name @'
EXECUTE AS USER=N'Task1560e140Runtime';
INSERT INTO [ATAPUtilities].[AceOutpostContentSummaryPrototype] ([OperationId],[Payload])
 VALUES (NEWID(),N'blocked by V00130');
REVERT;
'@ -ExpectFailure
    ($blocked -join [Environment]::NewLine) | Should -Match '(?i)permission was denied'
    Invoke-Flyway $name 140 migrate
    (Get-RuntimeProof $name | Select-Object -Last 1) |
      Should -Be '90020000-0000-0000-0000-000000000010|3'
  }

  It 'accepts and preserves the already-recovered emergency permission state' -Skip:(-not $canRun) {
    $name = New-Database
    Invoke-Flyway $name 130 migrate
    $null = Invoke-Sql $name @'
REVOKE SELECT, INSERT, UPDATE, DELETE, ALTER, VIEW DEFINITION
 ON SCHEMA::[ATAPUtilities] FROM [ATAPContentSummaryRuntimeQuery];
DENY SELECT, INSERT, UPDATE, DELETE, ALTER, VIEW DEFINITION
 ON OBJECT::[ATAPUtilities].[Tag] TO [ATAPContentSummaryRuntimeQuery];
DENY SELECT, INSERT, UPDATE, DELETE, ALTER, VIEW DEFINITION
 ON OBJECT::[ATAPUtilities].[TagAlias] TO [ATAPContentSummaryRuntimeQuery];
DENY SELECT, INSERT, UPDATE, DELETE, ALTER, VIEW DEFINITION
 ON OBJECT::[ATAPUtilities].[ContentSummary] TO [ATAPContentSummaryRuntimeQuery];
'@
    Invoke-Flyway $name 140 migrate
    Invoke-Flyway $name 140 validate
    $catalog = Invoke-Sql $name @'
SELECT CONCAT(
 (SELECT COUNT(*) FROM sys.database_permissions WHERE grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryRuntimeQuery') AND class_desc=N'SCHEMA' AND state_desc=N'DENY'),'|',
 (SELECT COUNT(*) FROM sys.database_permissions WHERE grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryRuntimeQuery') AND class_desc=N'OBJECT_OR_COLUMN' AND state_desc=N'DENY')); 
'@
    ($catalog | Select-Object -Last 1) | Should -Be '0|18'
  }
}

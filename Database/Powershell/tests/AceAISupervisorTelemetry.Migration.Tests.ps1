#Requires -Version 7.0
#Requires -Module Pester

Set-StrictMode -Version Latest

Describe 'V00070 Ace AISupervisor telemetry static contract' {
  BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
    $migrationName = 'V00070__Create_Ace_AISupervisor_Telemetry.sql'
    $migrationPath = Join-Path $sqlDirectory $migrationName
    $migration = Get-Content -LiteralPath $migrationPath -Raw
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

  It 'allocates the unique next active version after deployed V00060' {
    $names = @($activeMigrations.Name)
    $versions = @($names | ForEach-Object {
        if ($_ -notmatch '^(V\d+)__') { throw "Invalid migration name: $_" }
        $matches[1]
      })

    $names | Should -Be @(
      'V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql'
      'V00030__Create_AceOutpostContentSummaryPrototype.sql'
      'V00040__Add_PhiloteValidityPeriod_SameIdentity_Key.sql'
      'V00050__Create_ATAPUtilities_Tag_Root.sql'
      'V00060__Create_Ace_GatherContent_Submission.sql'
      $migrationName
    )
    @($versions | Group-Object | Where-Object Count -gt 1).Count | Should -Be 0
  }

  It 'parses the migration and each literal dynamic DDL batch as SQL Server 2022 T-SQL' {
    $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
    foreach ($batch in @($migration) + $dynamicBodies) {
      $reader = [IO.StringReader]::new($batch)
      $errors = [Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
      try {
        $null = $parser.Parse($reader, [ref]$errors)
      }
      finally {
        $reader.Dispose()
      }

      @($errors | ForEach-Object { "Line $($_.Line), column $($_.Column): $($_.Message)" }) |
        Should -BeNullOrEmpty
    }
  }

  It 'creates the exact bounded Ace-owned telemetry object set' {
    $tables = @([regex]::Matches(
        $migration,
        '(?im)^\s*CREATE TABLE \[Ace\]\.\[(?<name>[^]]+)\]') |
      ForEach-Object { $_.Groups['name'].Value })

    $tables | Should -Be @(
      'AISupervisorExchange'
      'AISupervisorPrompt'
      'AISupervisorExchangeTag'
      'AISupervisorAttempt'
      'AISupervisorUsage'
      'AISupervisorMetricCatalog'
      'AISupervisorMetric'
    )
    $migration | Should -Match 'CREATE TYPE \[Ace\]\.\[AISupervisorTagInput\] AS TABLE'
    $migration | Should -Match 'CREATE TYPE \[Ace\]\.\[AISupervisorMetricInput\] AS TABLE'
  }

  It 'preserves nullable telemetry and non-dense occurrence ordinals' {
    foreach ($nullableColumn in @(
        'HarnessVersion', 'Model', 'ModelVersion', 'Effort', 'ConversationId', 'SessionId',
        'ProviderStatusCode', 'ResponseByteCount', 'ResponseChunkCount',
        'RequestTokens', 'ResponseTokens', 'AvailabilityReason', 'SourceField'
      )) {
      $migration | Should -Match "\[$nullableColumn\][^,\r\n]+ NULL"
    }
    $migration | Should -Match '\[Ordinal\] int NOT NULL'
    $migration | Should -Match '\[AttemptOrdinal\] int NOT NULL'
    $migration | Should -Match '\[MetricOrdinal\] int NOT NULL'
    $migration | Should -Not -Match 'UNIQUE \(\[ExchangeId\], \[Ordinal\]\)'
    $migration | Should -Not -Match 'UNIQUE \(\[ExchangeId\], \[AttemptOrdinal\]\)'
    $migration | Should -Not -Match 'MIN\(\[Ordinal\]\)[\s\S]*?COUNT\(\*\)'
  }

  It 'enforces append-only idempotent procedure-only writes and controlled metrics' {
    foreach ($pattern in @(
        'UQ_Ace_AISupervisorExchange_IdempotencyKey',
        'Ace\.AISupervisorExchange:',
        'IF @ExistingExchangeId IS NOT NULL',
        'THROW 57010',
        'THROW 57014',
        'CREATE TRIGGER \[Ace\]\.\[TR_',
        'AISupervisorMetricCatalog',
        'catalog\.\[MetricCode\] IS NULL',
        'CREATE ROLE \[AceAISupervisorCaptureExecutor\]',
        'GRANT EXECUTE ON OBJECT::\[Ace\]\.\[CaptureAISupervisorAttempt\]'
      )) {
      $migration | Should -Match $pattern
    }
    $migration | Should -Not -Match '(?im)^\s*GRANT\s+(?:SELECT|INSERT|UPDATE|DELETE)\s+ON\s+(?:SCHEMA|OBJECT)::'
    $migration | Should -Not -Match '(?im)^\s*CREATE\s+(?:LOGIN|USER)\b'
    $migration | Should -Not -Match '(?i)\b(?:db_owner|db_datareader|db_datawriter|CONTROL SERVER)\b'
  }

  It 'provides bounded Commander reads without converting missing token counts to zero' {
    foreach ($procedure in @(
        'QueryGatherContentSubmissionTimeline',
        'QueryAISupervisorExchangeTimeline',
        'QueryAISupervisorTokenTimeline'
      )) {
      $migration | Should -Match "CREATE PROCEDURE \[Ace\]\.\[$procedure\]"
      $migration | Should -Match "GRANT EXECUTE ON OBJECT::\[Ace\]\.\[$procedure\] TO \[AceCommanderTimelineReader\]"
    }
    $migration | Should -Match '@PageSize NOT BETWEEN 1 AND 500'
    $migration | Should -Match 'DATEDIFF\(day, @FromUtc, @ToUtc\) > 366'
    $migration | Should -Match 'SUM\(\[RequestTokens\]\)'
    $migration | Should -Match 'SUM\(\[ResponseTokens\]\)'
    $migration | Should -Not -Match 'COALESCE\(\[RequestTokens\],\s*0\)'
    $migration | Should -Not -Match 'COALESCE\(\[ResponseTokens\],\s*0\)'
  }

  It 'excludes prohibited payload and authoritative Tag writes' {
    $migration | Should -Not -Match '(?im)^\s*(?:INSERT|UPDATE|DELETE|MERGE)\s+(?:INTO\s+|FROM\s+)?\[ATAPUtilities\]\.\[(?:Tag|TagNamespace|TagState|TagAlias)\]'
    foreach ($prohibitedColumn in @('RawPrompt', 'ResponseBody', 'ToolPayload', 'AuthorizationHeader', 'ApiKey', 'CookieValue')) {
      $migration | Should -Not -Match "\[$prohibitedColumn\]"
    }
  }

  It 'binds the exact active database content to the unbuilt 0.1.6 allowlist' {
    $flywayRoot = Join-Path $repoRoot 'Database\Flyway'
    $version = Get-Content -LiteralPath (Join-Path $flywayRoot 'version.json') -Raw | ConvertFrom-Json
    $allowlist = Get-Content -LiteralPath (Join-Path $flywayRoot 'package-content-allowlist.json') -Raw | ConvertFrom-Json
    $expectedPaths = @(
      @($activeMigrations | ForEach-Object { 'SQL/' + $_.Name })
      @(Get-ChildItem -LiteralPath (Join-Path $flywayRoot 'Data') -File -Filter '*.csv' |
        Sort-Object Name | ForEach-Object { 'Data/' + $_.Name })
    )

    $version.version | Should -Be '0.1.6'
    $allowlist.sourceVersion | Should -Be $version.version
    @($allowlist.files.path) | Should -Be $expectedPaths
    foreach ($entry in $allowlist.files) {
      $literalPath = Join-Path $flywayRoot ($entry.path -replace '/', [IO.Path]::DirectorySeparatorChar)
      Test-Path -LiteralPath $literalPath -PathType Leaf | Should -BeTrue -Because $entry.path
      (Get-FileHash -LiteralPath $literalPath -Algorithm SHA256).Hash |
        Should -Be $entry.sha256 -Because $entry.path
    }
    ($allowlist.files | Where-Object path -EQ 'SQL/V00070__Create_Ace_AISupervisor_Telemetry.sql').sha256 |
      Should -Be '501B2C9486C81C706C7C07BB8912053FBE91A5559865C43B57527DDB7E5453C8'
  }
}

Describe 'V00070 disposable database execution contract' {
  $discoveryInstance = [Environment]::GetEnvironmentVariable('ATAP_FLYWAY_DISPOSABLE_SQL_INSTANCE', 'Process')
  $isAuthorizedLocalInstance = $discoveryInstance -and
    (($discoveryInstance -match "(?i)^(?:\\.|localhost|127\.0\.0\.1|$([regex]::Escape($env:COMPUTERNAME)))(?:\\[^;]+)?$") -or
      ($discoveryInstance -eq "$env:COMPUTERNAME\EXPWHERTZING"))
  $canRun = $isAuthorizedLocalInstance -and
    (Get-Command flyway -ErrorAction SilentlyContinue) -and
    (Get-Command sqlcmd -ErrorAction SilentlyContinue)

  BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
    $flywayConfig = Join-Path $repoRoot 'Database\Flyway\flyway.toml'
    $localInstance = [Environment]::GetEnvironmentVariable('ATAP_FLYWAY_DISPOSABLE_SQL_INSTANCE', 'Process')

    function New-Task15185bV70DisposableDatabase {
      $name = 'ATAPUtilities_Task15185bV70_' + [guid]::NewGuid().ToString('N')
      if ($name -notmatch '^ATAPUtilities_Task15185bV70_[0-9a-f]{32}$') {
        throw 'Unsafe disposable database name.'
      }
      & sqlcmd -S $localInstance -E -d master -b -Q "CREATE DATABASE [$name];"
      if ($LASTEXITCODE -ne 0) { throw "Failed to create disposable database $name." }
      $name
    }

    function Remove-Task15185bV70DisposableDatabase {
      param([Parameter(Mandatory)][string] $Name)
      if ($Name -notmatch '^ATAPUtilities_Task15185bV70_[0-9a-f]{32}$') {
        throw 'Refusing to remove a database outside the Task 15.185.b V70 disposable prefix.'
      }
      & sqlcmd -S $localInstance -E -d master -b -Q "ALTER DATABASE [$Name] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$Name];"
      if ($LASTEXITCODE -ne 0) { throw "Failed to remove disposable database $Name." }
    }

    function Invoke-Task15185bV70Flyway {
      param(
        [Parameter(Mandatory)][string] $DatabaseName,
        [Parameter(Mandatory)][ValidateSet('migrate', 'validate')][string] $Command,
        [Parameter(Mandatory)][ValidateSet('60', '70')][string] $Target
      )
      $jdbcUrl = "jdbc:sqlserver://$localInstance;databaseName=$DatabaseName;integratedSecurity=true;encrypt=true;trustServerCertificate=true"
      $output = & flyway "-configFiles=$flywayConfig" "-locations=filesystem:$sqlDirectory" "-url=$jdbcUrl" "-target=$Target" $Command 2>&1
      if ($LASTEXITCODE -ne 0) {
        throw "Flyway $Command to V000$Target failed: $($output -join [Environment]::NewLine)"
      }
    }

    $functionalFixture = @'
SET NOCOUNT ON;
DECLARE @Exchange uniqueidentifier='61000000-0000-0000-0000-000000000001';
DECLARE @Key uniqueidentifier='61000000-0000-0000-0000-000000000002';
DECLARE @EnvelopeHash binary(32)=HASHBYTES('SHA2_256',N'fixture-envelope');
DECLARE @Attempt uniqueidentifier='62000000-0000-0000-0000-000000000001';
DECLARE @AttemptHash binary(32)=HASHBYTES('SHA2_256',N'fixture-attempt');
DECLARE @At datetime2(7)='2026-09-01T12:03:00.0000000';
DECLARE @Tags [Ace].[AISupervisorTagInput];
INSERT INTO @Tags ([ExchangeTagId],[Ordinal],[TagText]) VALUES
 ('63000000-0000-0000-0000-000000000001',2,N'agent:codex'),
 ('63000000-0000-0000-0000-000000000002',9,N'task:15.185');
DECLARE @Metrics [Ace].[AISupervisorMetricInput];
INSERT INTO @Metrics
 ([MetricId],[MetricOrdinal],[DirectionCode],[MetricCode],[NumericValue],[SourceField],[ProviderReported])
VALUES ('64000000-0000-0000-0000-000000000001',4,N'Response',N'reasoning_tokens',5,N'usage.reasoning_tokens',1);

EXEC [Ace].[CaptureAISupervisorAttempt]
 @ExchangeId=@Exchange,@IdempotencyKey=@Key,@CanonicalEnvelopeHash=@EnvelopeHash,
 @Harness=N'Codex',@HarnessVersion=NULL,@Provider=N'OpenAI',@Model=N'gpt-fixture',@ModelVersion=NULL,
 @Effort=N'high',@ConversationId=N'conversation-fixture',@SessionId=NULL,
 @CorrelationId=N'correlation-fixture',@EndpointClassification=N'openai-responses',@ConsentVersion=N'fixture-v1',
 @ExchangeStartedAtUtc=@At,@ExchangeRecordedAtUtc=@At,
 @SanitizedPrompt=N'Implement the bounded fixture.',@PromptHash=0x0101010101010101010101010101010101010101010101010101010101010101,
 @PromptClassificationCode=N'sanitized-v1',@AttemptId=@Attempt,@AttemptOrdinal=3,
 @CanonicalAttemptHash=@AttemptHash,@OutcomeCode=N'Completed',@ProviderStatusCode=200,
 @AttemptStartedAtUtc=@At,@AttemptCompletedAtUtc=@At,@ResponseByteCount=123,@ResponseChunkCount=7,
 @RequestTokens=10,@ResponseTokens=NULL,@AvailabilityCode=N'Partial',@AvailabilityReason=N'response count absent',
 @UsageProviderReported=1,@Tags=@Tags,@Metrics=@Metrics;

EXEC [Ace].[CaptureAISupervisorAttempt]
 @ExchangeId=@Exchange,@IdempotencyKey=@Key,@CanonicalEnvelopeHash=@EnvelopeHash,
 @Harness=N'Codex',@Provider=N'OpenAI',@CorrelationId=N'correlation-fixture',
 @EndpointClassification=N'openai-responses',@ConsentVersion=N'fixture-v1',
 @ExchangeStartedAtUtc=@At,@ExchangeRecordedAtUtc=@At,@AttemptId=@Attempt,@AttemptOrdinal=3,
 @CanonicalAttemptHash=@AttemptHash,@OutcomeCode=N'Completed',@ProviderStatusCode=200,
 @AttemptStartedAtUtc=@At,@AttemptCompletedAtUtc=@At,@ResponseByteCount=123,@ResponseChunkCount=7,
 @RequestTokens=10,@ResponseTokens=NULL,@AvailabilityCode=N'Partial',@AvailabilityReason=N'response count absent',
 @UsageProviderReported=1,@Tags=@Tags,@Metrics=@Metrics;

IF (SELECT COUNT_BIG(*) FROM [Ace].[AISupervisorExchange])<>1 THROW 57901,'Replay duplicated exchange.',1;
IF (SELECT COUNT_BIG(*) FROM [Ace].[AISupervisorAttempt])<>1 THROW 57902,'Replay duplicated attempt.',1;
IF (SELECT COUNT_BIG(*) FROM [Ace].[AISupervisorExchangeTag])<>2 THROW 57903,'Non-dense Tag occurrences were not preserved.',1;
IF NOT EXISTS (SELECT 1 FROM [Ace].[AISupervisorExchangeTag] WHERE [Ordinal]=2)
 OR NOT EXISTS (SELECT 1 FROM [Ace].[AISupervisorExchangeTag] WHERE [Ordinal]=9)
 THROW 57904,'Tag ordinals were rewritten or densified.',1;
IF NOT EXISTS (SELECT 1 FROM [Ace].[AISupervisorUsage]
 WHERE [RequestTokens]=10 AND [ResponseTokens] IS NULL AND [AvailabilityCode]=N'Partial')
 THROW 57905,'Nullable usage was not preserved.',1;
IF (SELECT COUNT_BIG(*) FROM [Ace].[AISupervisorMetric])<>1 THROW 57906,'Controlled metric was not captured exactly once.',1;

BEGIN TRY
 EXEC [Ace].[CaptureAISupervisorAttempt]
  @ExchangeId=@Exchange,@IdempotencyKey=@Key,@CanonicalEnvelopeHash=@EnvelopeHash,
  @Harness=N'Codex',@Provider=N'OpenAI',@CorrelationId=N'correlation-fixture',
  @EndpointClassification=N'openai-responses',@ConsentVersion=N'fixture-v1',
  @ExchangeStartedAtUtc=@At,@ExchangeRecordedAtUtc=@At,@AttemptId=@Attempt,@AttemptOrdinal=3,
  @CanonicalAttemptHash=0x0202020202020202020202020202020202020202020202020202020202020202,
  @OutcomeCode=N'Completed',@ProviderStatusCode=200,@AttemptStartedAtUtc=@At,@AttemptCompletedAtUtc=@At,
  @RequestTokens=10,@ResponseTokens=NULL,@AvailabilityCode=N'Partial',@AvailabilityReason=N'response count absent',
  @UsageProviderReported=1,@Tags=@Tags,@Metrics=@Metrics;
 THROW 57907,'Conflicting attempt replay was accepted.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>57014 THROW;
END CATCH;

DECLARE @AdversarialTags [Ace].[AISupervisorTagInput];
DECLARE @AdversarialMetrics [Ace].[AISupervisorMetricInput];
DECLARE @OtherExchange uniqueidentifier='61000000-0000-0000-0000-000000000002';
DECLARE @OtherKey uniqueidentifier='61000000-0000-0000-0000-000000000102';
BEGIN TRY
 EXEC [Ace].[CaptureAISupervisorAttempt]
  @ExchangeId=@OtherExchange,@IdempotencyKey=@OtherKey,@CanonicalEnvelopeHash=@EnvelopeHash,
  @Harness=N'Codex',@Provider=N'OpenAI',@CorrelationId=N'cross-exchange-fixture',
  @EndpointClassification=N'openai-responses',@ConsentVersion=N'fixture-v1',
  @ExchangeStartedAtUtc=@At,@ExchangeRecordedAtUtc=@At,@AttemptId=@Attempt,@AttemptOrdinal=3,
  @CanonicalAttemptHash=@AttemptHash,@OutcomeCode=N'Completed',@ProviderStatusCode=200,
  @AttemptStartedAtUtc=@At,@AttemptCompletedAtUtc=@At,
  @RequestTokens=NULL,@ResponseTokens=NULL,@AvailabilityCode=N'Missing',@AvailabilityReason=N'provider omitted usage',
  @UsageProviderReported=0,@Tags=@AdversarialTags,@Metrics=@AdversarialMetrics;
 THROW 57911,'Cross-exchange attempt replay was accepted.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>57014 THROW;
END CATCH;
IF EXISTS (SELECT 1 FROM [Ace].[AISupervisorExchange] WHERE [ExchangeId]=@OtherExchange)
 THROW 57912,'Rejected cross-exchange replay left a partial exchange.',1;

DECLARE @InvalidPartialAttempt uniqueidentifier='62000000-0000-0000-0000-000000000099';
BEGIN TRY
 EXEC [Ace].[CaptureAISupervisorAttempt]
  @ExchangeId=@Exchange,@IdempotencyKey=@Key,@CanonicalEnvelopeHash=@EnvelopeHash,
  @Harness=N'Codex',@Provider=N'OpenAI',@CorrelationId=N'correlation-fixture',
  @EndpointClassification=N'openai-responses',@ConsentVersion=N'fixture-v1',
  @ExchangeStartedAtUtc=@At,@ExchangeRecordedAtUtc=@At,@AttemptId=@InvalidPartialAttempt,@AttemptOrdinal=99,
  @CanonicalAttemptHash=0x0909090909090909090909090909090909090909090909090909090909090909,
  @OutcomeCode=N'Completed',@ProviderStatusCode=200,@AttemptStartedAtUtc=@At,@AttemptCompletedAtUtc=@At,
  @RequestTokens=10,@ResponseTokens=20,@AvailabilityCode=N'Partial',@AvailabilityReason=N'contradictory fixture',
  @UsageProviderReported=1,@Tags=@AdversarialTags,@Metrics=@AdversarialMetrics;
 THROW 57913,'Partial usage accepted two present token counts.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>57008 THROW;
END CATCH;
IF EXISTS (SELECT 1 FROM [Ace].[AISupervisorAttempt] WHERE [AttemptId]=@InvalidPartialAttempt)
 THROW 57914,'Rejected partial usage left a partial attempt.',1;

DECLARE @MissingAttempt uniqueidentifier='62000000-0000-0000-0000-000000000002';
DECLARE @NoTags [Ace].[AISupervisorTagInput];
DECLARE @NoMetrics [Ace].[AISupervisorMetricInput];
EXEC [Ace].[CaptureAISupervisorAttempt]
 @ExchangeId=@Exchange,@IdempotencyKey=@Key,@CanonicalEnvelopeHash=@EnvelopeHash,
 @Harness=N'Codex',@Provider=N'OpenAI',@CorrelationId=N'correlation-fixture',
 @EndpointClassification=N'openai-responses',@ConsentVersion=N'fixture-v1',
 @ExchangeStartedAtUtc=@At,@ExchangeRecordedAtUtc=@At,@AttemptId=@MissingAttempt,@AttemptOrdinal=11,
 @CanonicalAttemptHash=0x0303030303030303030303030303030303030303030303030303030303030303,
 @OutcomeCode=N'Abandoned',@AttemptStartedAtUtc=@At,@AttemptCompletedAtUtc=@At,
 @RequestTokens=NULL,@ResponseTokens=NULL,@AvailabilityCode=N'Missing',@AvailabilityReason=N'provider omitted usage',
 @UsageProviderReported=0,@Tags=@NoTags,@Metrics=@NoMetrics;

DECLARE @Timeline TABLE
 ([BucketStartUtc] datetime2(7),[BucketEndUtc] datetime2(7),[Harness] nvarchar(64),[Model] nvarchar(128),
  [Effort] nvarchar(64),[AttemptCount] bigint,[RequestTokens] bigint,[ResponseTokens] bigint,
  [MissingOrPartialCount] int,[CompletenessCode] nvarchar(16));
INSERT INTO @Timeline EXEC [Ace].[QueryAISupervisorTokenTimeline]
 @FromUtc='2026-09-01T12:00:00',@ToUtc='2026-09-01T13:00:00',@BucketMinutes=5,@Harness=N'Codex';
IF (SELECT COUNT_BIG(*) FROM @Timeline)<>1 THROW 57908,'Expected one token bucket.',1;
IF NOT EXISTS (SELECT 1 FROM @Timeline WHERE [RequestTokens]=10 AND [ResponseTokens] IS NULL
 AND [AttemptCount]=2 AND [MissingOrPartialCount]=2 AND [CompletenessCode]=N'Partial')
 THROW 57909,'Token completeness or null semantics are incorrect.',1;

BEGIN TRY
 UPDATE [Ace].[AISupervisorExchange] SET [CorrelationId]=N'changed' WHERE [ExchangeId]=@Exchange;
 THROW 57910,'Append-only exchange update was accepted.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>57020 THROW;
END CATCH;
'@
  }

  It 'applies fresh and exposes exactly the V00070 boundary' -Skip:(-not $canRun) {
    $databaseName = New-Task15185bV70DisposableDatabase
    try {
      Invoke-Task15185bV70Flyway -DatabaseName $databaseName -Command migrate -Target 70
      Invoke-Task15185bV70Flyway -DatabaseName $databaseName -Command validate -Target 70
      $verify = @'
SET NOCOUNT ON;
IF (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history] WHERE [success]=1)<>6
 THROW 57920,'Expected six successful migration rows.',1;
IF (SELECT COUNT_BIG(*) FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
 WHERE s.name='Ace' AND t.name LIKE 'AISupervisor%')<>7
 THROW 57921,'Expected seven AISupervisor tables.',1;
IF OBJECT_ID(N'[Ace].[CaptureAISupervisorAttempt]',N'P') IS NULL
 OR OBJECT_ID(N'[Ace].[QueryAISupervisorTokenTimeline]',N'P') IS NULL
 OR TYPE_ID(N'[Ace].[AISupervisorTagInput]') IS NULL
 OR TYPE_ID(N'[Ace].[AISupervisorMetricInput]') IS NULL
 THROW 57922,'Expected AISupervisor routines or types are missing.',1;
'@
      & sqlcmd -S $localInstance -E -d $databaseName -b -Q $verify
      $LASTEXITCODE | Should -Be 0
    }
    finally {
      Remove-Task15185bV70DisposableDatabase -Name $databaseName
    }
  }

  It 'upgrades V00060, preserves predecessors, and passes replay and timeline fixtures' -Skip:(-not $canRun) {
    $databaseName = New-Task15185bV70DisposableDatabase
    try {
      Invoke-Task15185bV70Flyway -DatabaseName $databaseName -Command migrate -Target 60
      $before = & sqlcmd -S $localInstance -E -d $databaseName -b -W -h -1 -Q "SET NOCOUNT ON; SELECT CONCAT((SELECT COUNT_BIG(*) FROM [Ace].[GatherContentSubmission]),'|',(SELECT COUNT_BIG(*) FROM [ATAPUtilities].[AceOutpostContentSummaryPrototype]));"
      $LASTEXITCODE | Should -Be 0

      Invoke-Task15185bV70Flyway -DatabaseName $databaseName -Command migrate -Target 70
      Invoke-Task15185bV70Flyway -DatabaseName $databaseName -Command validate -Target 70
      $after = & sqlcmd -S $localInstance -E -d $databaseName -b -W -h -1 -Q "SET NOCOUNT ON; SELECT CONCAT((SELECT COUNT_BIG(*) FROM [Ace].[GatherContentSubmission]),'|',(SELECT COUNT_BIG(*) FROM [ATAPUtilities].[AceOutpostContentSummaryPrototype]));"
      $LASTEXITCODE | Should -Be 0
      ($before | Where-Object { $_ -match '^\d+\|\d+$' }) |
        Should -Be ($after | Where-Object { $_ -match '^\d+\|\d+$' })

      & sqlcmd -S $localInstance -E -d $databaseName -b -Q $functionalFixture
      $LASTEXITCODE | Should -Be 0
    }
    finally {
      Remove-Task15185bV70DisposableDatabase -Name $databaseName
    }
  }
}

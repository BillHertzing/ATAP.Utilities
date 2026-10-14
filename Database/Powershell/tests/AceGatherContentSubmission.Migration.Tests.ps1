#Requires -Version 7.0
#Requires -Module Pester

Set-StrictMode -Version Latest

Describe 'V00060 Ace gather-content submission static contract' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
        $migrationName = 'V00060__Create_Ace_GatherContent_Submission.sql'
        $migrationPath = Join-Path $sqlDirectory $migrationName
        $migration = Get-Content -LiteralPath $migrationPath -Raw
        $migrationsThroughV00060 = @(Get-ChildItem -LiteralPath $sqlDirectory -File -Filter 'V*.sql' |
            Where-Object Name -LE $migrationName |
            Sort-Object Name)
        $dynamicBodies = @([regex]::Matches(
                $migration,
                "(?s)EXEC\s+sys\.sp_executesql\s+N'(?<body>(?:''|[^'])*)';") |
            ForEach-Object { $_.Groups['body'].Value.Replace("''", "'") })

        $scriptDomPath = 'C:\Program Files\PowerShell\Modules\SqlServer\22.3.0\coreclr\Microsoft.SqlServer.TransactSql.ScriptDom.dll'
        if (-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])) {
            Add-Type -LiteralPath $scriptDomPath
        }
    }

    It 'allocates the unique next active version after deployed V00050' {
        $names = @($migrationsThroughV00060.Name)
        $versions = @($names | ForEach-Object {
                if ($_ -notmatch '^(V\d+)__') { throw "Invalid migration name: $_" }
                $matches[1]
            })

        $names | Should -Be @(
            'V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql'
            'V00030__Create_AceOutpostContentSummaryPrototype.sql'
            'V00040__Add_PhiloteValidityPeriod_SameIdentity_Key.sql'
            'V00050__Create_ATAPUtilities_Tag_Root.sql'
            $migrationName
        )
        @($versions | Group-Object | Where-Object Count -gt 1).Count | Should -Be 0
    }

    It 'parses the migration and every dynamic DDL batch as SQL Server 2022 T-SQL' {
        $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
        $batches = @($migration) + $dynamicBodies
        foreach ($batch in $batches) {
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

    It 'creates only the four ratified Ace tables and one ordered Tag type' {
        $tables = @([regex]::Matches(
                $migration,
                '(?im)^\s*CREATE TABLE \[Ace\]\.\[(?<name>[^]]+)\]') |
            ForEach-Object { $_.Groups['name'].Value })

        $tables | Should -Be @(
            'TagNamespace'
            'Tag'
            'GatherContentSubmission'
            'GatherContentSubmissionTag'
        )
        $migration | Should -Match 'CREATE TYPE \[Ace\]\.\[GatherContentTagInput\] AS TABLE'
        $migration | Should -Match '\[Ordinal\] tinyint NOT NULL PRIMARY KEY'
        $migration | Should -Match '\[TagText\] nvarchar\(256\).*Latin1_General_100_CI_AS_SC NOT NULL'
    }

    It 'implements exact idempotency, append-only, ordering, and conflict behavior' {
        foreach ($pattern in @(
                '\[IdempotencyKey\] uniqueidentifier NOT NULL',
                '\[CanonicalRequestHash\] binary\(32\) NOT NULL',
                'UQ_Ace_GatherContentSubmission_IdempotencyKey',
                'sys\.sp_getapplock',
                'Ace\.GatherContentSubmission:',
                'IF @ExistingRequestHash <> @CanonicalRequestHash',
                'THROW 56008',
                'THROW 56009',
                'TR_TagNamespace_AppendOnly',
                'TR_Tag_AppendOnly',
                'TR_GatherContentSubmission_AppendOnly',
                'TR_GatherContentSubmissionTag_AppendOnly',
                'MIN\(\[Ordinal\]\)[\s\S]*?<> 0',
                'MAX\(\[Ordinal\]\)[\s\S]*?COUNT\(\*\) FROM @Tags'
            )) {
            $migration | Should -Match $pattern
        }
    }

    It 'creates the exact procedure-only least-privilege boundary' {
        foreach ($name in @('CaptureGatherContentSubmission', 'QueryGatherContentV1')) {
            $migration | Should -Match "CREATE PROCEDURE \[Ace\]\.\[$name\]"
        }
        foreach ($role in @(
                'AceGatherContentCaptureExecutor',
                'AceGatherContentQueryExecutor',
                'AceGatherContentSubmissionReader'
            )) {
            $migration | Should -Match "CREATE ROLE \[$role\]"
        }
        $migration | Should -Match 'GRANT EXECUTE ON OBJECT::\[Ace\]\.\[CaptureGatherContentSubmission\]'
        $migration | Should -Match 'GRANT EXECUTE ON OBJECT::\[Ace\]\.\[QueryGatherContentV1\]'
        $migration | Should -Not -Match '(?im)^\s*GRANT\s+(?:SELECT|INSERT|UPDATE|DELETE)\s+ON\s+(?:SCHEMA|OBJECT)::'
        $migration | Should -Not -Match '(?im)^\s*CREATE\s+(?:LOGIN|USER)\b'
        $migration | Should -Not -Match '(?i)\b(?:db_owner|db_datareader|db_datawriter|CONTROL SERVER)\b'
    }

    It 'keeps ATAPUtilities Tag objects read-only and excludes prompt and proxy breadth' {
        $migration | Should -Match '(?:FROM|JOIN) \[ATAPUtilities\]\.\[Tag\]'
        $migration | Should -Match 'INNER JOIN \[ATAPUtilities\]\.\[TagState\]'
        $migration | Should -Not -Match '(?im)^\s*(?:INSERT|UPDATE|DELETE|MERGE)\s+(?:INTO\s+|FROM\s+)?\[ATAPUtilities\]\.\[(?:Tag|TagNamespace|TagState|TagAlias)\]'
        foreach ($excluded in @('PromptText', 'AISupervisor', 'ProxyExchange', 'TokenUsage')) {
            $migration | Should -Not -Match ([regex]::Escape($excluded))
        }
    }

    It 'defines the direct current-Tag v1 DTO projection and fails closed on ambiguity' {
        foreach ($field in @(
                'ItemId', 'SourceKind', 'SourceReference', 'Text', 'MatchedTagsJson',
                'RankingContract', 'Rank', 'AssertedAtUtc', 'RecordedAtUtc',
                'ProducerId', 'ContentHash'
            )) {
            $migration | Should -Match "\[$field\]"
        }
        $migration | Should -Match "N''ATAPUtilities\.Tag''"
        $migration | Should -Match "N''tag-code-v1''"
        $migration | Should -Match "HASHBYTES[\s\S]*?''SHA2_256''"
        $migration | Should -Match 'HAVING COUNT\(DISTINCT tag\.\[TagId\]\) > 1'
        $migration | Should -Match 'THROW 56013'
    }
}

Describe 'V00060 disposable database execution contract' {
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

        function New-Task15185bDisposableDatabase {
            $name = 'ATAPUtilities_Task15185b_' + [guid]::NewGuid().ToString('N')
            if ($name -notmatch '^ATAPUtilities_Task15185b_[0-9a-f]{32}$') {
                throw 'Unsafe disposable database name.'
            }
            & sqlcmd -S $localInstance -E -d master -b -Q "CREATE DATABASE [$name];"
            if ($LASTEXITCODE -ne 0) { throw "Failed to create disposable database $name." }
            $name
        }

        function Remove-Task15185bDisposableDatabase {
            param([Parameter(Mandatory)][string] $Name)
            if ($Name -notmatch '^ATAPUtilities_Task15185b_[0-9a-f]{32}$') {
                throw 'Refusing to remove a database outside the Task 15.185.b disposable prefix.'
            }
            & sqlcmd -S $localInstance -E -d master -b -Q "ALTER DATABASE [$Name] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$Name];"
            if ($LASTEXITCODE -ne 0) { throw "Failed to remove disposable database $Name." }
        }

        function Invoke-Task15185bFlyway {
            param(
                [Parameter(Mandatory)][string] $DatabaseName,
                [Parameter(Mandatory)][ValidateSet('migrate', 'validate')][string] $Command,
                [Parameter(Mandatory)][ValidateSet('50', '60')][string] $Target
            )
            $jdbcUrl = "jdbc:sqlserver://$localInstance;databaseName=$DatabaseName;integratedSecurity=true;encrypt=true;trustServerCertificate=true"
            $output = & flyway "-configFiles=$flywayConfig" "-locations=filesystem:$sqlDirectory" "-url=$jdbcUrl" "-target=$Target" $Command 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Flyway $Command to V000$Target failed: $($output -join [Environment]::NewLine)"
            }
        }

        $functionalFixture = @'
SET NOCOUNT ON;
DECLARE @Actor uniqueidentifier='10000000-0000-0000-0000-000000000001';
DECLARE @Namespace uniqueidentifier='20000000-0000-0000-0000-000000000001';
DECLARE @Steward uniqueidentifier='20000000-0000-0000-0000-000000000002';
DECLARE @Tag uniqueidentifier='30000000-0000-0000-0000-000000000001';
DECLARE @Period uniqueidentifier='30000000-0000-0000-0000-000000000002';
DECLARE @State uniqueidentifier='30000000-0000-0000-0000-000000000003';
DECLARE @At datetime2(7)='2026-08-31T00:00:00.0000000';

EXEC [ATAPUtilities].[CreateTagNamespace]
  @TagNamespaceId=@Namespace, @TagNamespaceStewardId=@Steward,
  @NamespaceCode=N'GatherFixture', @ActorPrincipalId=@Actor,
  @SourceReference=N'Task15.185.b fixture', @OccurredAtUtc=@At, @RecordedAtUtc=@At;
INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub]) VALUES (@Tag,NULL);
EXEC [ATAPUtilities].[CreateFirstPhiloteValidityPeriod]
  @PhiloteId=@Tag, @PhiloteValidityPeriodId=@Period, @ValidFromUtc=@At, @ValidToUtc=NULL;
INSERT INTO [ATAPUtilities].[Tag]
  ([TagId],[TagNamespaceId],[TagCode],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
VALUES (@Tag,@Namespace,N'ace',@Actor,N'fixture',@At,@At);
INSERT INTO [ATAPUtilities].[TagState]
  ([TagStateId],[TagId],[PhiloteValidityPeriodId],[ValidFromUtc],[ValidToUtc],
   [Label],[Description],[TagStateKindCode],[SuccessorTagId],[WithdrawalReason],
   [PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
VALUES (@State,@Tag,@Period,@At,NULL,N'Ace',N'Fixture summary','Active',NULL,NULL,
        @Actor,N'fixture',@At,@At);

DECLARE @Tags [Ace].[GatherContentTagInput];
INSERT INTO @Tags ([Ordinal],[TagText]) VALUES (0,N'ace'),(1,N'Ace');
DECLARE @Submission uniqueidentifier='40000000-0000-0000-0000-000000000001';
DECLARE @Key uniqueidentifier='40000000-0000-0000-0000-000000000002';
DECLARE @Hash binary(32)=HASHBYTES('SHA2_256',N'fixture-request');
EXEC [Ace].[CaptureGatherContentSubmission]
  @GatherContentSubmissionId=@Submission, @IdempotencyKey=@Key,
  @CanonicalRequestHash=@Hash, @ApiVersion=1, @Instance=N'production',
  @Depth=3, @Width=2, @CallerPrincipalName=N'UTAT022\whertzing',
  @CorrelationId=N'fixture-correlation', @ReceivedAtUtc=@At, @Tags=@Tags;
EXEC [Ace].[CaptureGatherContentSubmission]
  @GatherContentSubmissionId=@Submission, @IdempotencyKey=@Key,
  @CanonicalRequestHash=@Hash, @ApiVersion=1, @Instance=N'production',
  @Depth=3, @Width=2, @CallerPrincipalName=N'UTAT022\whertzing',
  @CorrelationId=N'fixture-retry', @ReceivedAtUtc=@At, @Tags=@Tags;

IF (SELECT COUNT_BIG(*) FROM [Ace].[GatherContentSubmission])<>1 THROW 56901,'Replay duplicated submission.',1;
IF (SELECT COUNT_BIG(*) FROM [Ace].[Tag])<>1 THROW 56902,'Case variants did not canonicalize.',1;
IF (SELECT COUNT_BIG(*) FROM [Ace].[GatherContentSubmissionTag])<>2 THROW 56903,'Tag occurrences were not preserved.',1;
IF NOT EXISTS (SELECT 1 FROM [Ace].[GatherContentSubmissionTag] WHERE [Ordinal]=0 AND [SubmittedTagText]=N'ace')
   OR NOT EXISTS (SELECT 1 FROM [Ace].[GatherContentSubmissionTag] WHERE [Ordinal]=1 AND [SubmittedTagText]=N'Ace')
    THROW 56904,'Submitted spelling or order was not preserved.',1;

BEGIN TRY
  EXEC [Ace].[CaptureGatherContentSubmission]
    @GatherContentSubmissionId='40000000-0000-0000-0000-000000000003', @IdempotencyKey=@Key,
    @CanonicalRequestHash=0x0101010101010101010101010101010101010101010101010101010101010101,
    @ApiVersion=1, @Instance=N'production', @Depth=3, @Width=2,
    @CallerPrincipalName=N'UTAT022\whertzing', @CorrelationId=N'conflict',
    @ReceivedAtUtc=@At, @Tags=@Tags;
  THROW 56905,'Conflicting replay was accepted.',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()<>56008 THROW;
END CATCH;
IF (SELECT COUNT_BIG(*) FROM [Ace].[GatherContentSubmission])<>1 THROW 56906,'Conflict left a durable effect.',1;

DECLARE @Result TABLE
(
  [ItemId] uniqueidentifier, [SourceKind] nvarchar(64), [SourceReference] nvarchar(512),
  [Text] nvarchar(2048), [MatchedTagsJson] nvarchar(max), [RankingContract] nvarchar(64),
  [Rank] int, [AssertedAtUtc] datetime2(7), [RecordedAtUtc] datetime2(7),
  [ProducerId] uniqueidentifier, [ContentHash] varbinary(32)
);
INSERT INTO @Result EXEC [Ace].[QueryGatherContentV1] @Tags=@Tags;
IF (SELECT COUNT_BIG(*) FROM @Result)<>1 THROW 56907,'Expected one direct current-Tag item.',1;
IF NOT EXISTS
(
  SELECT 1 FROM @Result
  WHERE [ItemId]=@Tag AND [SourceKind]=N'ATAPUtilities.Tag'
    AND [Text]=N'Fixture summary' AND [RankingContract]=N'tag-code-v1'
    AND [Rank]=0 AND DATALENGTH([ContentHash])=32
    AND ISJSON([MatchedTagsJson])=1
    AND CHARINDEX(NCHAR(34)+N'ace'+NCHAR(34), [MatchedTagsJson] COLLATE Latin1_General_100_BIN2)>0
    AND CHARINDEX(NCHAR(34)+N'Ace'+NCHAR(34), [MatchedTagsJson] COLLATE Latin1_General_100_BIN2)>0
)
  THROW 56908,'The v1 DTO projection is incorrect.',1;

BEGIN TRY
  UPDATE [Ace].[GatherContentSubmission] SET [CorrelationId]=N'changed'
  WHERE [GatherContentSubmissionId]=@Submission;
  THROW 56909,'Append-only submission update was accepted.',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()<>56022 THROW;
END CATCH;
'@
    }

    It 'applies fresh and exposes exactly the ratified V00060 boundary' -Skip:(-not $canRun) {
        $databaseName = New-Task15185bDisposableDatabase
        try {
            Invoke-Task15185bFlyway -DatabaseName $databaseName -Command migrate -Target 60
            Invoke-Task15185bFlyway -DatabaseName $databaseName -Command validate -Target 60
            $verify = @'
SET NOCOUNT ON;
IF (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history] WHERE [success]=1)<>5
  THROW 56920,'Expected five successful migration rows.',1;
IF (SELECT COUNT_BIG(*) FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
    WHERE s.name='Ace' AND t.name IN ('TagNamespace','Tag','GatherContentSubmission','GatherContentSubmissionTag'))<>4
  THROW 56921,'Expected four Ace tables.',1;
IF OBJECT_ID(N'[Ace].[CaptureGatherContentSubmission]',N'P') IS NULL
   OR OBJECT_ID(N'[Ace].[QueryGatherContentV1]',N'P') IS NULL
   OR TYPE_ID(N'[Ace].[GatherContentTagInput]') IS NULL
  THROW 56922,'Expected Ace routines or type are missing.',1;
'@
            & sqlcmd -S $localInstance -E -d $databaseName -b -Q $verify
            $LASTEXITCODE | Should -Be 0
        }
        finally {
            Remove-Task15185bDisposableDatabase -Name $databaseName
        }
    }

    It 'upgrades V00050, preserves predecessors, and passes replay and query fixtures' -Skip:(-not $canRun) {
        $databaseName = New-Task15185bDisposableDatabase
        try {
            Invoke-Task15185bFlyway -DatabaseName $databaseName -Command migrate -Target 50
            $before = & sqlcmd -S $localInstance -E -d $databaseName -b -W -h -1 -Q "SET NOCOUNT ON; SELECT CONCAT((SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Philote]),'|',(SELECT COUNT_BIG(*) FROM [ATAPUtilities].[AceOutpostContentSummaryPrototype]));"
            $LASTEXITCODE | Should -Be 0

            Invoke-Task15185bFlyway -DatabaseName $databaseName -Command migrate -Target 60
            Invoke-Task15185bFlyway -DatabaseName $databaseName -Command validate -Target 60
            $after = & sqlcmd -S $localInstance -E -d $databaseName -b -W -h -1 -Q "SET NOCOUNT ON; SELECT CONCAT((SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Philote]),'|',(SELECT COUNT_BIG(*) FROM [ATAPUtilities].[AceOutpostContentSummaryPrototype]));"
            $LASTEXITCODE | Should -Be 0
            ($before | Where-Object { $_ -match '^\d+\|\d+$' }) |
                Should -Be ($after | Where-Object { $_ -match '^\d+\|\d+$' })

            & sqlcmd -S $localInstance -E -d $databaseName -b -Q $functionalFixture
            $LASTEXITCODE | Should -Be 0
        }
        finally {
            Remove-Task15185bDisposableDatabase -Name $databaseName
        }
    }
}

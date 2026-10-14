Set-StrictMode -Version Latest

Describe 'V00050 association-ready Tag root static contract' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
        $migrationName = 'V00050__Create_ATAPUtilities_Tag_Root.sql'
        $migrationPath = Join-Path $sqlDirectory $migrationName
        $migration = Get-Content -LiteralPath $migrationPath -Raw
        $retractProcedure = [regex]::Match(
            $migration,
            '(?s)CREATE PROCEDURE \[ATAPUtilities\]\.\[RetractTag\].*?\nEND;'';').Value
        $dynamicBodies = @([regex]::Matches(
                $migration,
                "(?s)EXEC\s+sys\.sp_executesql\s+N'(?<body>(?:''|[^'])*)';") |
            ForEach-Object { $_.Groups['body'].Value.Replace("''", "'") })
        $stewardTrigger = @($dynamicBodies | Where-Object { $_ -match 'CREATE TRIGGER \[ATAPUtilities\]\.\[TR_TagNamespaceSteward_History\]' })[0]
        $stateTrigger = @($dynamicBodies | Where-Object { $_ -match 'CREATE TRIGGER \[ATAPUtilities\]\.\[TR_TagState_TemporalAndSuccessor\]' })[0]
        $aliasTrigger = @($dynamicBodies | Where-Object { $_ -match 'CREATE TRIGGER \[ATAPUtilities\]\.\[TR_TagAlias_TemporalAndClaims\]' })[0]
        $resolverFunction = @($dynamicBodies | Where-Object { $_ -match 'CREATE FUNCTION \[ATAPUtilities\]\.\[ResolveTagAsOf\]' })[0]
        $migrationsThroughV00050 = @(Get-ChildItem -LiteralPath $sqlDirectory -File -Filter 'V*.sql' |
            Where-Object Name -LE $migrationName |
            Sort-Object Name)

        $scriptDomPath = 'C:\Program Files\PowerShell\Modules\SqlServer\22.3.0\coreclr\Microsoft.SqlServer.TransactSql.ScriptDom.dll'
        if (-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])) {
            Add-Type -LiteralPath $scriptDomPath
        }
    }

    It 'allocates V00050 after V00040 without a duplicate migration version' {
        $versions = @($migrationsThroughV00050 | ForEach-Object {
                if ($_.Name -notmatch '^(V\d+)__') {
                    throw "Invalid migration name: $($_.Name)"
                }
                $matches[1]
            })

        @($versions | Group-Object | Where-Object Count -gt 1).Count | Should -Be 0
        @($versions) | Should -Be @('V00010', 'V00030', 'V00040', 'V00050')
    }

    It 'parses as SQL Server 2022 T-SQL without errors' {
        $reader = [IO.StringReader]::new($migration)
        $errors = [Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
        $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
        try {
            $null = $parser.Parse($reader, [ref]$errors)
        }
        finally {
            $reader.Dispose()
        }

        @($errors | ForEach-Object { "Line $($_.Line), column $($_.Column): $($_.Message)" }) |
            Should -BeNullOrEmpty

        $dynamicBatches = @([regex]::Matches(
                $migration,
                "(?s)EXEC\s+sys\.sp_executesql\s+N'(?<body>(?:''|[^'])*)';"))
        $dynamicBatches.Count | Should -Be 10
        foreach ($dynamicBatch in $dynamicBatches) {
            $dynamicSql = $dynamicBatch.Groups['body'].Value.Replace("''", "'")
            $dynamicReader = [IO.StringReader]::new($dynamicSql)
            $dynamicErrors = [Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
            try {
                $null = $parser.Parse($dynamicReader, [ref]$dynamicErrors)
            }
            finally {
                $dynamicReader.Dispose()
            }
            @($dynamicErrors | ForEach-Object { "Dynamic line $($_.Line), column $($_.Column): $($_.Message)" }) |
                Should -BeNullOrEmpty
        }
    }

    It 'creates exactly the six PC-02 tables and no seed rows' {
        $tableNames = @([regex]::Matches(
                $migration,
                '(?im)^\s*CREATE\s+TABLE\s+\[ATAPUtilities\]\.\[(?<name>[^]]+)\]') |
            ForEach-Object { $_.Groups['name'].Value })

        $tableNames | Should -Be @(
            'TagNamespace',
            'TagNamespaceSteward',
            'Tag',
            'TagAliasType',
            'TagState',
            'TagAlias'
        )
        $migration | Should -Not -Match '(?im)^\s*INSERT\s+INTO\s+\[ATAPUtilities\]\.\[(?:TagNamespace|TagNamespaceSteward|Tag|TagAliasType|TagState|TagAlias)\]\s*\([^@]*\)\s*VALUES\s*\([^@]*\)'
    }

    It 'uses the exact PC-01 scalar and collation contract' {
        foreach ($pattern in @(
                '\[NamespaceCode\]\s+nvarchar\(128\)\s+COLLATE\s+Latin1_General_100_CI_AS_SC\s+NOT NULL',
                '\[TagCode\]\s+nvarchar\(128\)\s+COLLATE\s+Latin1_General_100_CI_AS_SC\s+NOT NULL',
                '\[AliasCode\]\s+nvarchar\(128\)\s+COLLATE\s+Latin1_General_100_CI_AS_SC\s+NOT NULL',
                '\[AliasTypeCode\]\s+nvarchar\(64\)\s+COLLATE\s+Latin1_General_100_CI_AS_SC\s+NOT NULL',
                '\[Label\]\s+nvarchar\(256\)\s+NOT NULL',
                '\[Description\]\s+nvarchar\(2048\)\s+NULL',
                '\[SourceReference\]\s+nvarchar\(512\)\s+NOT NULL',
                '\[WithdrawalReason\]\s+nvarchar\(1024\)\s+NULL',
                '\[OccurredAtUtc\]\s+datetime2\(7\)\s+NOT NULL',
                '\[RecordedAtUtc\]\s+datetime2\(7\)\s+NOT NULL'
            )) {
            $migration | Should -Match $pattern
        }
    }

    It 'binds TagId directly to Philote and state to the V00040 same-identity key' {
        $migration | Should -Match 'CONSTRAINT \[FK_Tag_Philote\][\s\S]*?FOREIGN KEY \(\[TagId\]\)[\s\S]*?REFERENCES \[ATAPUtilities\]\.\[Philote\] \(\[PhiloteId\]\)'
        $migration | Should -Match 'CONSTRAINT \[FK_TagState_PhiloteValidityPeriod_SameIdentity\][\s\S]*?FOREIGN KEY \(\[TagId\], \[PhiloteValidityPeriodId\]\)[\s\S]*?REFERENCES \[ATAPUtilities\]\.\[PhiloteValidityPeriod\] \(\[PhiloteId\], \[PhiloteValidityPeriodId\]\)'
        $migration | Should -Not -Match '(?im)^\s*\[PhiloteId\]\s+uniqueidentifier.*--.*Tag'
    }

    It 'implements active-state and zero-duration terminal-state checks' {
        $migration | Should -Match "\[TagStateKindCode\] = 'Active'[\s\S]*?\[ValidFromUtc\] < \[ValidToUtc\]"
        $migration | Should -Match "\[TagStateKindCode\] = 'RetractedSuccessor'[\s\S]*?\[SuccessorTagId\] IS NOT NULL[\s\S]*?\[ValidFromUtc\] = \[ValidToUtc\]"
        $migration | Should -Match "\[TagStateKindCode\] = 'RetractedErroneous'[\s\S]*?DATALENGTH\(\[WithdrawalReason\]\) > 0[\s\S]*?\[ValidFromUtc\] = \[ValidToUtc\]"
        $migration | Should -Match 'TR_TagState_TemporalAndSuccessor'
        $migration | Should -Match 'TR_PhiloteValidityPeriod_TagStateContainment'
        $migration | Should -Match 'Active TagState intervals cannot overlap'
        $migration | Should -Match 'Tag successor cycles are prohibited'
    }

    It 'implements stewardship authoring and permanent namespace-local code claims' {
        foreach ($triggerName in @(
                'TR_TagNamespace_ImmutableNoDelete',
                'TR_TagNamespaceSteward_History',
                'TR_Tag_AuthoringAndClaims',
                'TR_TagAliasType_ImmutableNoDelete',
                'TR_TagAlias_TemporalAndClaims'
            )) {
            $migration | Should -Match ([regex]::Escape($triggerName))
        }
        $migration | Should -Match 's\.ValidFromUtc <= i\.OccurredAtUtc'
        $migration | Should -Match 'i\.OccurredAtUtc < s\.ValidToUtc'
        $migration | Should -Match 'Canonical TagCode collides with a permanently claimed alias'
        $migration | Should -Match 'AliasCode cannot equal any canonical TagCode in its namespace'
        $migration | Should -Match 'An alias spelling is permanently claimed by another Tag in the namespace'
        $migration | Should -Match 'Alias intervals for the same Tag and spelling cannot overlap'
    }

    It 'creates the exact atomic namespace creation contract' {
        $migration | Should -Match 'CREATE PROCEDURE \[ATAPUtilities\]\.\[CreateTagNamespace\]'
        foreach ($parameter in @(
                '@TagNamespaceId uniqueidentifier',
                '@TagNamespaceStewardId uniqueidentifier',
                '@NamespaceCode nvarchar\(128\)',
                '@ActorPrincipalId uniqueidentifier',
                '@SourceReference nvarchar\(512\)',
                '@OccurredAtUtc datetime2\(7\)',
                '@RecordedAtUtc datetime2\(7\)'
            )) {
            $migration | Should -Match $parameter
        }
        $migration | Should -Match 'BEGIN TRANSACTION;[\s\S]*?INSERT INTO \[ATAPUtilities\]\.\[TagNamespace\][\s\S]*?INSERT INTO \[ATAPUtilities\]\.\[TagNamespaceSteward\][\s\S]*?COMMIT TRANSACTION;'
    }

    It 'creates the exact transactional retraction contract' {
        $migration | Should -Match 'CREATE PROCEDURE \[ATAPUtilities\]\.\[RetractTag\]'
        foreach ($parameter in @(
                '@ExpectedTagStateId uniqueidentifier',
                '@ExpectedPhiloteValidityPeriodId uniqueidentifier',
                '@TerminalTagStateId uniqueidentifier',
                '@EffectiveAtUtc datetime2\(7\)',
                '@RetractionKindCode varchar\(32\)',
                '@SuccessorTagId uniqueidentifier = NULL',
                '@WithdrawalReason nvarchar\(1024\) = NULL'
            )) {
            $migration | Should -Match $parameter
        }
        $retractProcedure | Should -Not -BeNullOrEmpty
        $retractProcedure | Should -Match 'sys\.sp_getapplock'
        $retractProcedure | Should -Match "IF @RetractionKindCode = ''RetractedSuccessor''[\s\S]*?@Resource = ''ATAPUtilities\.TagSuccessorGraph''[\s\S]*?THROW 55033"
        $retractProcedure | Should -Match "N''ATAPUtilities\.PhiloteValidityPeriod:''\s*\+\s*LOWER\(CONVERT\(nvarchar\(36\), @TagId\)\)"
        $graphLockPosition = $retractProcedure.IndexOf("@Resource = ''ATAPUtilities.TagSuccessorGraph''", [StringComparison]::Ordinal)
        $philoteLockPosition = $retractProcedure.IndexOf("N''ATAPUtilities.PhiloteValidityPeriod:''", [StringComparison]::Ordinal)
        $graphLockPosition | Should -BeGreaterOrEqual 0
        $philoteLockPosition | Should -BeGreaterThan $graphLockPosition
        $retractProcedure | Should -Match 'UPDATE \[ATAPUtilities\]\.\[TagState\][\s\S]*?SET ValidToUtc=@EffectiveAtUtc'
        $retractProcedure | Should -Match 'UPDATE \[ATAPUtilities\]\.\[PhiloteValidityPeriod\][\s\S]*?SET ValidToUtc=@EffectiveAtUtc[\s\S]*?PhiloteValidityPeriodId=@ExpectedPhiloteValidityPeriodId[\s\S]*?ValidToUtc IS NULL'
        $retractProcedure | Should -Not -Match '(?i)\b(?:EXEC|ALTER)\b[\s\S]*?\[ATAPUtilities\]\.\[(?:CloseCurrentPhiloteValidityPeriod|ReplacePhiloteValidityPeriodSet)\]'
        $retractProcedure | Should -Not -Match '(?i)DELETE\s+FROM\s+\[ATAPUtilities\]\.\[PhiloteValidityPeriod\]'
        $retractProcedure | Should -Match '@EffectiveAtUtc, @EffectiveAtUtc'
        foreach ($errorNumber in 55033, 55048, 55049, 55050, 55051, 55052, 55053, 55054, 55055, 55056, 55057, 55058, 55059) {
            $retractProcedure | Should -Match "THROW $errorNumber"
        }
    }

    It 'creates the exact sanctioned as-of and successor resolver contract' {
        $migration | Should -Match 'CREATE FUNCTION \[ATAPUtilities\]\.\[ResolveTagAsOf\]'
        $migration | Should -Match '@TagId uniqueidentifier,\s*@AsOfUtc datetime2\(7\)'
        foreach ($column in @(
                'RequestedTagId', 'ResolvedTagId', 'TagNamespaceId', 'NamespaceCode',
                'TagCode', 'TagStateId', 'Label', 'Description', 'ResolutionStatusCode', 'HopCount'
            )) {
            $migration | Should -Match "\b$column\b"
        }
        foreach ($status in @('Resolved', 'Inactive', 'RetractedErroneous', 'Cycle', 'DepthExceeded')) {
            $migration | Should -Match "''$status''"
        }
        $migration | Should -Match '@HopCount < 64'
        $migration | Should -Not -Match '@HopCount <= 64'
        $ordinaryCoveragePosition = $migration.IndexOf("s.TagStateKindCode=''Active''", [StringComparison]::Ordinal)
        $terminalFallbackPosition = $migration.IndexOf("s.TagStateKindCode IN (''RetractedSuccessor'',''RetractedErroneous'')", [StringComparison]::Ordinal)
        $ordinaryCoveragePosition | Should -BeGreaterOrEqual 0
        $terminalFallbackPosition | Should -BeGreaterThan $ordinaryCoveragePosition
    }

    It 'closes the R4 and R5 adversarial history terminal graph resolver and self-successor gaps' {
        foreach ($triggerContract in @(
                @{ Body = $stewardTrigger; Id = 'TagNamespaceStewardId'; Error = 'THROW 55060' },
                @{ Body = $stateTrigger; Id = 'TagStateId'; Error = 'THROW 55061' },
                @{ Body = $aliasTrigger; Id = 'TagAliasId'; Error = 'THROW 55062' }
            )) {
            $triggerContract.Body | Should -Match "EXISTS \(SELECT 1 FROM deleted\)[\s\S]*?EXISTS \(SELECT 1 FROM inserted\)[\s\S]*?UPDATE\(\[$($triggerContract.Id)\]\)"
            $errorPosition = $triggerContract.Body.IndexOf($triggerContract.Error, [StringComparison]::Ordinal)
            $idJoinPosition = $triggerContract.Body.IndexOf('INNER JOIN deleted AS d', [StringComparison]::Ordinal)
            $errorPosition | Should -BeGreaterOrEqual 0
            $idJoinPosition | Should -BeGreaterThan $errorPosition
        }

        $migration | Should -Match 'IX_TagState_TerminalBoundary'
        $stateTrigger | Should -Match 's\.TagId = i\.TagId[\s\S]*?s\.PhiloteValidityPeriodId = i\.PhiloteValidityPeriodId[\s\S]*?s\.ValidFromUtc = i\.ValidFromUtc'
        $stateTrigger | Should -Match 'Only one terminal event is permitted for a Tag validity-period boundary'
        $stateTrigger | Should -Match "sys\.sp_getapplock[\s\S]*?@Resource = 'ATAPUtilities\.TagSuccessorGraph'[\s\S]*?@LockOwner = 'Transaction'[\s\S]*?THROW 55033"
        $stateTrigger | Should -Match 'DECLARE successor_event_cursor[\s\S]*?SELECT TagStateId, TagId, SuccessorTagId[\s\S]*?FROM inserted[\s\S]*?TagStateKindCode = ''RetractedSuccessor'''
        $stateTrigger | Should -Match 'FETCH NEXT FROM successor_event_cursor[\s\S]*?@SourceTagStateId, @SourceTagId, @InitialSuccessorTagId'
        $stateTrigger | Should -Match 'DECLARE @Visited TABLE \(TagId uniqueidentifier NOT NULL PRIMARY KEY\)'
        $stateTrigger | Should -Match 'DECLARE @Frontier TABLE \(TagId uniqueidentifier NOT NULL PRIMARY KEY\)'
        $stateTrigger | Should -Match 'DELETE FROM @Visited;[\s\S]*?DELETE FROM @Frontier;[\s\S]*?INSERT INTO @Frontier'
        $stateTrigger | Should -Match 'WHILE EXISTS \(SELECT 1 FROM @Frontier\)[\s\S]*?DELETE FROM @Frontier WHERE TagId = @FrontierTagId'
        $stateTrigger | Should -Match 'SELECT DISTINCT edge\.SuccessorTagId[\s\S]*?FROM \[ATAPUtilities\]\.\[TagState\] AS edge[\s\S]*?edge\.TagId = @FrontierTagId'
        $stateTrigger | Should -Match 'NOT EXISTS[\s\S]*?FROM @Visited AS visited[\s\S]*?NOT EXISTS[\s\S]*?FROM @Frontier AS pending'
        $stateTrigger | Should -Not -Match '@Hop|exceeds the enforcement limit|<=\s*64|TOP \(1\) @NextTagId'

        $resolverFunction | Should -Match 'RequestedTagId uniqueidentifier NULL'
        $resolverFunction | Should -Match 'IF @TagId IS NULL OR NOT EXISTS[\s\S]*?VALUES \(@TagId, NULL, NULL, NULL, NULL, NULL, NULL, NULL, ''Inactive'', 0\)'
        $resolverFunction | Should -Match 'WHILE @CurrentTagId IS NOT NULL AND @HopCount < 64'
        $resolverFunction | Should -Not -Match '@HopCount <= 64'

        $retractProcedure | Should -Match 'THROW 55047'
        $selfSuccessorPosition = $retractProcedure.IndexOf("@SuccessorTagId = @TagId", [StringComparison]::Ordinal)
        $beginTryPosition = $retractProcedure.IndexOf('BEGIN TRY', [StringComparison]::Ordinal)
        $firstWritePosition = $retractProcedure.IndexOf('UPDATE [ATAPUtilities].[TagState]', [StringComparison]::Ordinal)
        $selfSuccessorPosition | Should -BeGreaterOrEqual 0
        $beginTryPosition | Should -BeGreaterThan $selfSuccessorPosition
        $firstWritePosition | Should -BeGreaterThan $selfSuccessorPosition
    }

    It 'keeps all explicitly excluded pending and security artifacts absent' {
        foreach ($pattern in @(
                '(?im)^\s*CREATE\s+SCHEMA\s+\[?Tags\]?',
                '(?im)^\s*CREATE\s+TABLE\s+.*(?:TagAssignment|TagRelation|Localization|Taxonomy)',
                '(?im)^\s*\[(?:TenantId|Ordinal|Weight|Confidence|Relevance)\]\s+',
                '(?im)^\s*(?:GRANT|REVOKE|DENY)\b',
                '(?im)^\s*CREATE\s+(?:LOGIN|USER|ROLE)\b',
                '(?im)^\s*(?:INSERT|MERGE)\s+INTO\s+.*(?:Seed|Registry)'
            )) {
            $migration | Should -Not -Match $pattern
        }
    }
}

Describe 'V00050 disposable and SQL Server Express execution gates' {
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

        function New-Task15140cT2DisposableDatabase {
            $name = 'ATAPUtilities_Task15140cT2_' + [guid]::NewGuid().ToString('N')
            if ($name -notmatch '^ATAPUtilities_Task15140cT2_[0-9a-f]{32}$') {
                throw 'Unsafe disposable database name.'
            }

            & sqlcmd -S $localInstance -E -d master -b -Q "CREATE DATABASE [$name];"
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create disposable database $name."
            }

            return $name
        }

        function Remove-Task15140cT2DisposableDatabase {
            param([Parameter(Mandatory)][string] $Name)

            if ($Name -notmatch '^ATAPUtilities_Task15140cT2_[0-9a-f]{32}$') {
                throw 'Refusing to remove a database outside the Task 15.140.c.T2 disposable prefix.'
            }

            & sqlcmd -S $localInstance -E -d master -b -Q "ALTER DATABASE [$Name] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$Name];"
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to remove disposable database $Name."
            }
        }

        function Invoke-Task15140cT2Flyway {
            param(
                [Parameter(Mandatory)][string] $DatabaseName,
                [Parameter(Mandatory)][ValidateSet('migrate', 'validate')][string] $Command,
                [Parameter(Mandatory)][ValidateSet('40', '50')][string] $Target
            )

            $jdbcUrl = "jdbc:sqlserver://$localInstance;databaseName=$DatabaseName;integratedSecurity=true;encrypt=true;trustServerCertificate=true"
            $flywayOutput = & flyway "-configFiles=$flywayConfig" "-locations=filesystem:$sqlDirectory" "-url=$jdbcUrl" "-target=$Target" $Command 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Flyway $Command to V000$Target failed for the disposable database: $($flywayOutput -join [Environment]::NewLine)"
            }
        }

        $tagFixture = @'
SET NOCOUNT ON;
DECLARE @ActorPrincipalId uniqueidentifier = '10000000-0000-0000-0000-000000000001';
DECLARE @UnauthorizedPrincipalId uniqueidentifier = '10000000-0000-0000-0000-000000000002';
DECLARE @TagNamespaceId uniqueidentifier = '20000000-0000-0000-0000-000000000001';
DECLARE @TagNamespaceStewardId uniqueidentifier = '20000000-0000-0000-0000-000000000002';
DECLARE @TagId uniqueidentifier = '30000000-0000-0000-0000-000000000001';
DECLARE @TagPeriodId uniqueidentifier = '30000000-0000-0000-0000-000000000002';
DECLARE @TagStateId uniqueidentifier = '30000000-0000-0000-0000-000000000003';
DECLARE @TerminalTagStateId uniqueidentifier = '30000000-0000-0000-0000-000000000004';
DECLARE @OtherTagId uniqueidentifier = '40000000-0000-0000-0000-000000000001';
DECLARE @OtherTagPeriodId uniqueidentifier = '40000000-0000-0000-0000-000000000002';
DECLARE @UnauthorizedTagId uniqueidentifier = '50000000-0000-0000-0000-000000000001';
DECLARE @UnauthorizedTagPeriodId uniqueidentifier = '50000000-0000-0000-0000-000000000002';
DECLARE @StartUtc datetime2(7) = '2026-08-31T00:00:00.0000000';
DECLARE @RetractUtc datetime2(7) = '2026-08-31T01:00:00.0000000';

EXEC [ATAPUtilities].[CreateTagNamespace]
    @TagNamespaceId=@TagNamespaceId,
    @TagNamespaceStewardId=@TagNamespaceStewardId,
    @NamespaceCode=N'AceOutpostFixture',
    @ActorPrincipalId=@ActorPrincipalId,
    @SourceReference=N'Task15.140.c.T2 disposable fixture',
    @OccurredAtUtc=@StartUtc,
    @RecordedAtUtc=@StartUtc;

INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId], [AdditionalIdsStub])
VALUES (@TagId, NULL), (@OtherTagId, NULL), (@UnauthorizedTagId, NULL);

EXEC [ATAPUtilities].[CreateFirstPhiloteValidityPeriod]
    @PhiloteId=@TagId, @PhiloteValidityPeriodId=@TagPeriodId,
    @ValidFromUtc=@StartUtc, @ValidToUtc=NULL;
EXEC [ATAPUtilities].[CreateFirstPhiloteValidityPeriod]
    @PhiloteId=@OtherTagId, @PhiloteValidityPeriodId=@OtherTagPeriodId,
    @ValidFromUtc=@StartUtc, @ValidToUtc=NULL;
EXEC [ATAPUtilities].[CreateFirstPhiloteValidityPeriod]
    @PhiloteId=@UnauthorizedTagId, @PhiloteValidityPeriodId=@UnauthorizedTagPeriodId,
    @ValidFromUtc=@StartUtc, @ValidToUtc=NULL;

INSERT INTO [ATAPUtilities].[Tag]
    ([TagId], [TagNamespaceId], [TagCode], [PrincipalId], [SourceReference], [OccurredAtUtc], [RecordedAtUtc])
VALUES
    (@TagId, @TagNamespaceId, N'ace', @ActorPrincipalId, N'fixture', @StartUtc, @StartUtc),
    (@OtherTagId, @TagNamespaceId, N'other', @ActorPrincipalId, N'fixture', @StartUtc, @StartUtc);

INSERT INTO [ATAPUtilities].[TagState]
    ([TagStateId], [TagId], [PhiloteValidityPeriodId], [ValidFromUtc], [ValidToUtc],
     [Label], [Description], [TagStateKindCode], [SuccessorTagId], [WithdrawalReason],
     [PrincipalId], [SourceReference], [OccurredAtUtc], [RecordedAtUtc])
VALUES
    (@TagStateId, @TagId, @TagPeriodId, @StartUtc, NULL,
     N'Ace', N'Disposable fixture', 'Active', NULL, NULL,
     @ActorPrincipalId, N'fixture', @StartUtc, @StartUtc);

IF NOT EXISTS
(
    SELECT 1 FROM [ATAPUtilities].[ResolveTagAsOf](@TagId, '2026-08-31T00:30:00.0000000')
    WHERE [ResolutionStatusCode]='Resolved' AND [ResolvedTagId]=@TagId AND [Label]=N'Ace'
)
    THROW 55901, 'The sanctioned as-of resolver did not return the active fixture Tag.', 1;

BEGIN TRY
    INSERT INTO [ATAPUtilities].[Tag]
        ([TagId], [TagNamespaceId], [TagCode], [PrincipalId], [SourceReference], [OccurredAtUtc], [RecordedAtUtc])
    VALUES
        (@UnauthorizedTagId, @TagNamespaceId, N'unauthorized', @UnauthorizedPrincipalId, N'fixture', @StartUtc, @StartUtc);
    THROW 55902, 'The unauthorized Tag author was accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 55015 THROW;
END CATCH;

BEGIN TRY
    INSERT INTO [ATAPUtilities].[TagState]
        ([TagStateId], [TagId], [PhiloteValidityPeriodId], [ValidFromUtc], [ValidToUtc],
         [Label], [Description], [TagStateKindCode], [SuccessorTagId], [WithdrawalReason],
         [PrincipalId], [SourceReference], [OccurredAtUtc], [RecordedAtUtc])
    VALUES
        ('40000000-0000-0000-0000-000000000003', @OtherTagId, @TagPeriodId, @StartUtc, NULL,
         N'Wrong period', NULL, 'Active', NULL, NULL,
         @ActorPrincipalId, N'fixture', @StartUtc, @StartUtc);
    THROW 55903, 'A TagState was allowed to reference another Tag identity period.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 547 THROW;
END CATCH;

EXEC [ATAPUtilities].[RetractTag]
    @TagId=@TagId,
    @ExpectedTagStateId=@TagStateId,
    @ExpectedPhiloteValidityPeriodId=@TagPeriodId,
    @TerminalTagStateId=@TerminalTagStateId,
    @EffectiveAtUtc=@RetractUtc,
    @ActorPrincipalId=@ActorPrincipalId,
    @SourceReference=N'fixture retraction',
    @OccurredAtUtc=@RetractUtc,
    @RecordedAtUtc=@RetractUtc,
    @RetractionKindCode='RetractedErroneous',
    @SuccessorTagId=NULL,
    @WithdrawalReason=N'fixture withdrawal';

IF NOT EXISTS
(
    SELECT 1 FROM [ATAPUtilities].[ResolveTagAsOf](@TagId, '2026-08-31T01:30:00.0000000')
    WHERE [ResolutionStatusCode]='RetractedErroneous' AND [ResolvedTagId]=@TagId
)
    THROW 55904, 'The sanctioned as-of resolver did not return the terminal fixture state.', 1;
'@
    }

    It 'applies V00050 from a fresh disposable database and exposes only the approved objects' -Skip:(-not $canRun) {
        $databaseName = New-Task15140cT2DisposableDatabase
        try {
            Invoke-Task15140cT2Flyway -DatabaseName $databaseName -Command migrate -Target 50
            Invoke-Task15140cT2Flyway -DatabaseName $databaseName -Command validate -Target 50

            $verificationSql = @'
SET NOCOUNT ON;
IF (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history] WHERE [success]=1) <> 4
    THROW 55910, 'Expected exactly four successful migration history rows.', 1;
IF (SELECT COUNT_BIG(*) FROM sys.tables AS t INNER JOIN sys.schemas AS s ON s.schema_id=t.schema_id
    WHERE s.name='ATAPUtilities' AND t.name IN ('TagNamespace','TagNamespaceSteward','Tag','TagAliasType','TagState','TagAlias')) <> 6
    THROW 55911, 'Expected exactly six approved Tag tables.', 1;
IF OBJECT_ID(N'[ATAPUtilities].[CreateTagNamespace]', N'P') IS NULL
   OR OBJECT_ID(N'[ATAPUtilities].[RetractTag]', N'P') IS NULL
   OR OBJECT_ID(N'[ATAPUtilities].[ResolveTagAsOf]') IS NULL
    THROW 55912, 'Expected Tag routines are missing.', 1;
'@
            & sqlcmd -S $localInstance -E -d $databaseName -b -Q $verificationSql
            $LASTEXITCODE | Should -Be 0
        }
        finally {
            Remove-Task15140cT2DisposableDatabase -Name $databaseName
        }
    }

    It 'upgrades V00040 to V00050, preserves predecessors, and passes negative and as-of fixtures' -Skip:(-not $canRun) {
        $databaseName = New-Task15140cT2DisposableDatabase
        try {
            Invoke-Task15140cT2Flyway -DatabaseName $databaseName -Command migrate -Target 40
            $before = & sqlcmd -S $localInstance -E -d $databaseName -b -W -h -1 -Q "SET NOCOUNT ON; SELECT CONCAT((SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Philote]), '|', (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[PhiloteValidityPeriod]), '|', (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[AceOutpostContentSummaryPrototype]));"
            $LASTEXITCODE | Should -Be 0

            Invoke-Task15140cT2Flyway -DatabaseName $databaseName -Command migrate -Target 50
            Invoke-Task15140cT2Flyway -DatabaseName $databaseName -Command validate -Target 50
            $after = & sqlcmd -S $localInstance -E -d $databaseName -b -W -h -1 -Q "SET NOCOUNT ON; SELECT CONCAT((SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Philote]), '|', (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[PhiloteValidityPeriod]), '|', (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[AceOutpostContentSummaryPrototype]));"
            $LASTEXITCODE | Should -Be 0
            ($before | Where-Object { $_ -match '^\d+\|\d+\|\d+$' }) | Should -Be ($after | Where-Object { $_ -match '^\d+\|\d+\|\d+$' })

            & sqlcmd -S $localInstance -E -d $databaseName -b -Q $tagFixture
            $LASTEXITCODE | Should -Be 0
        }
        finally {
            Remove-Task15140cT2DisposableDatabase -Name $databaseName
        }
    }

    It 'validates serialized collision triggers and their performance on SQL Server Express' -Skip {
        throw 'Requires separately authorized SQL Server Express execution and a ratified performance budget.'
    }
}

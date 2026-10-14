/*
  Ace AISupervisor fixture-backed telemetry and AceCommander read slice (Task 15.185.b).

  This forward-only migration writes only Ace-owned objects. It persists sanitized
  prompt envelopes, Tags, exchange/attempt provenance, provider-reported usage, and
  controlled numeric metrics. Raw prompts, response/tool bodies, credentials, header
  values, and the D2-EXC troubleshooting store are deliberately excluded.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'[Ace].[TagNamespace]', N'U') IS NULL
       OR OBJECT_ID(N'[Ace].[Tag]', N'U') IS NULL
       OR OBJECT_ID(N'[Ace].[GatherContentSubmission]', N'U') IS NULL
        THROW 57001, N'The deployed V00060 Ace gather-content boundary is required.', 1;

    IF OBJECT_ID(N'[Ace].[AISupervisorExchange]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[Ace].[AISupervisorPrompt]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[Ace].[AISupervisorExchangeTag]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[Ace].[AISupervisorAttempt]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[Ace].[AISupervisorUsage]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[Ace].[AISupervisorMetricCatalog]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[Ace].[AISupervisorMetric]', N'U') IS NOT NULL
       OR TYPE_ID(N'[Ace].[AISupervisorTagInput]') IS NOT NULL
       OR TYPE_ID(N'[Ace].[AISupervisorMetricInput]') IS NOT NULL
       OR OBJECT_ID(N'[Ace].[CaptureAISupervisorAttempt]', N'P') IS NOT NULL
       OR OBJECT_ID(N'[Ace].[QueryGatherContentSubmissionTimeline]', N'P') IS NOT NULL
       OR OBJECT_ID(N'[Ace].[QueryAISupervisorExchangeTimeline]', N'P') IS NOT NULL
       OR OBJECT_ID(N'[Ace].[QueryAISupervisorTokenTimeline]', N'P') IS NOT NULL
        THROW 57002, N'One or more V00070 target objects already exist.', 1;

    IF DATABASE_PRINCIPAL_ID(N'AceAISupervisorCaptureExecutor') IS NOT NULL
       OR DATABASE_PRINCIPAL_ID(N'AceCommanderTimelineReader') IS NOT NULL
        THROW 57003, N'One or more V00070 database roles already exist.', 1;

    CREATE TABLE [Ace].[AISupervisorExchange]
    (
        [ExchangeId] uniqueidentifier NOT NULL,
        [IdempotencyKey] uniqueidentifier NOT NULL,
        [CanonicalEnvelopeHash] binary(32) NOT NULL,
        [Harness] nvarchar(64) NOT NULL,
        [HarnessVersion] nvarchar(64) NULL,
        [Provider] nvarchar(64) NOT NULL,
        [Model] nvarchar(128) NULL,
        [ModelVersion] nvarchar(128) NULL,
        [Effort] nvarchar(64) NULL,
        [ConversationId] nvarchar(256) NULL,
        [SessionId] nvarchar(256) NULL,
        [CorrelationId] nvarchar(128) NOT NULL,
        [EndpointClassification] nvarchar(128) NOT NULL,
        [ConsentVersion] nvarchar(64) NOT NULL,
        [StartedAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_Ace_AISupervisorExchange] PRIMARY KEY ([ExchangeId]),
        CONSTRAINT [UQ_Ace_AISupervisorExchange_IdempotencyKey] UNIQUE ([IdempotencyKey]),
        CONSTRAINT [CK_Ace_AISupervisorExchange_Harness]
            CHECK (DATALENGTH([Harness]) BETWEEN 2 AND 128
                   AND [Harness] = LTRIM(RTRIM([Harness]))),
        CONSTRAINT [CK_Ace_AISupervisorExchange_Provider]
            CHECK (DATALENGTH([Provider]) BETWEEN 2 AND 128
                   AND [Provider] = LTRIM(RTRIM([Provider]))),
        CONSTRAINT [CK_Ace_AISupervisorExchange_CorrelationId]
            CHECK (DATALENGTH([CorrelationId]) BETWEEN 2 AND 256
                   AND [CorrelationId] = LTRIM(RTRIM([CorrelationId]))),
        CONSTRAINT [CK_Ace_AISupervisorExchange_EndpointClassification]
            CHECK (DATALENGTH([EndpointClassification]) BETWEEN 2 AND 256
                   AND [EndpointClassification] = LTRIM(RTRIM([EndpointClassification]))),
        CONSTRAINT [CK_Ace_AISupervisorExchange_ConsentVersion]
            CHECK (DATALENGTH([ConsentVersion]) BETWEEN 2 AND 128
                   AND [ConsentVersion] = LTRIM(RTRIM([ConsentVersion]))),
        CONSTRAINT [CK_Ace_AISupervisorExchange_OptionalDescriptors]
            CHECK (([HarnessVersion] IS NULL OR
                    (DATALENGTH([HarnessVersion]) BETWEEN 2 AND 128
                     AND [HarnessVersion] = LTRIM(RTRIM([HarnessVersion]))))
               AND ([Model] IS NULL OR
                    (DATALENGTH([Model]) BETWEEN 2 AND 256
                     AND [Model] = LTRIM(RTRIM([Model]))))
               AND ([ModelVersion] IS NULL OR
                    (DATALENGTH([ModelVersion]) BETWEEN 2 AND 256
                     AND [ModelVersion] = LTRIM(RTRIM([ModelVersion]))))
               AND ([Effort] IS NULL OR
                    (DATALENGTH([Effort]) BETWEEN 2 AND 128
                     AND [Effort] = LTRIM(RTRIM([Effort]))))
               AND ([ConversationId] IS NULL OR
                    (DATALENGTH([ConversationId]) BETWEEN 2 AND 512
                     AND [ConversationId] = LTRIM(RTRIM([ConversationId]))))
               AND ([SessionId] IS NULL OR
                    (DATALENGTH([SessionId]) BETWEEN 2 AND 512
                     AND [SessionId] = LTRIM(RTRIM([SessionId]))))),
        CONSTRAINT [CK_Ace_AISupervisorExchange_Times]
            CHECK ([RecordedAtUtc] >= [StartedAtUtc])
    );

    CREATE TABLE [Ace].[AISupervisorPrompt]
    (
        [ExchangeId] uniqueidentifier NOT NULL,
        [SanitizedPrompt] nvarchar(max) NOT NULL,
        [PromptHash] binary(32) NOT NULL,
        [ClassificationCode] nvarchar(64) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_Ace_AISupervisorPrompt] PRIMARY KEY ([ExchangeId]),
        CONSTRAINT [FK_Ace_AISupervisorPrompt_Exchange]
            FOREIGN KEY ([ExchangeId]) REFERENCES [Ace].[AISupervisorExchange] ([ExchangeId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [CK_Ace_AISupervisorPrompt_Text]
            CHECK (DATALENGTH([SanitizedPrompt]) BETWEEN 2 AND 16384),
        CONSTRAINT [CK_Ace_AISupervisorPrompt_Classification]
            CHECK (DATALENGTH([ClassificationCode]) BETWEEN 2 AND 128
                   AND [ClassificationCode] = LTRIM(RTRIM([ClassificationCode])))
    );

    CREATE TABLE [Ace].[AISupervisorExchangeTag]
    (
        [ExchangeTagId] uniqueidentifier NOT NULL,
        [ExchangeId] uniqueidentifier NOT NULL,
        [Ordinal] int NOT NULL,
        [TagId] uniqueidentifier NOT NULL,
        [SubmittedTagText] nvarchar(256) COLLATE Latin1_General_100_CI_AS_SC NOT NULL,
        CONSTRAINT [PK_Ace_AISupervisorExchangeTag] PRIMARY KEY ([ExchangeTagId]),
        CONSTRAINT [FK_Ace_AISupervisorExchangeTag_Exchange]
            FOREIGN KEY ([ExchangeId]) REFERENCES [Ace].[AISupervisorExchange] ([ExchangeId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_Ace_AISupervisorExchangeTag_Tag]
            FOREIGN KEY ([TagId]) REFERENCES [Ace].[Tag] ([TagId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [CK_Ace_AISupervisorExchangeTag_Ordinal]
            CHECK ([Ordinal] BETWEEN 0 AND 2147483646),
        CONSTRAINT [CK_Ace_AISupervisorExchangeTag_Text]
            CHECK (DATALENGTH([SubmittedTagText]) BETWEEN 2 AND 512
                   AND [SubmittedTagText] = LTRIM(RTRIM([SubmittedTagText])))
    );

    CREATE INDEX [IX_Ace_AISupervisorExchangeTag_ExchangeId_Ordinal]
        ON [Ace].[AISupervisorExchangeTag] ([ExchangeId], [Ordinal], [ExchangeTagId]);
    CREATE INDEX [IX_Ace_AISupervisorExchangeTag_TagId_ExchangeId]
        ON [Ace].[AISupervisorExchangeTag] ([TagId], [ExchangeId]);

    CREATE TABLE [Ace].[AISupervisorAttempt]
    (
        [AttemptId] uniqueidentifier NOT NULL,
        [ExchangeId] uniqueidentifier NOT NULL,
        [AttemptOrdinal] int NOT NULL,
        [CanonicalAttemptHash] binary(32) NOT NULL,
        [OutcomeCode] nvarchar(32) NOT NULL,
        [ProviderStatusCode] int NULL,
        [StartedAtUtc] datetime2(7) NOT NULL,
        [CompletedAtUtc] datetime2(7) NOT NULL,
        [ResponseByteCount] bigint NULL,
        [ResponseChunkCount] bigint NULL,
        CONSTRAINT [PK_Ace_AISupervisorAttempt] PRIMARY KEY ([AttemptId]),
        CONSTRAINT [FK_Ace_AISupervisorAttempt_Exchange]
            FOREIGN KEY ([ExchangeId]) REFERENCES [Ace].[AISupervisorExchange] ([ExchangeId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [CK_Ace_AISupervisorAttempt_Ordinal]
            CHECK ([AttemptOrdinal] BETWEEN 0 AND 2147483646),
        CONSTRAINT [CK_Ace_AISupervisorAttempt_Outcome]
            CHECK ([OutcomeCode] IN (N'Completed', N'Failed', N'Cancelled', N'Abandoned')),
        CONSTRAINT [CK_Ace_AISupervisorAttempt_Status]
            CHECK ([ProviderStatusCode] IS NULL OR [ProviderStatusCode] BETWEEN 100 AND 599),
        CONSTRAINT [CK_Ace_AISupervisorAttempt_Times]
            CHECK ([CompletedAtUtc] >= [StartedAtUtc]),
        CONSTRAINT [CK_Ace_AISupervisorAttempt_ResponseCounts]
            CHECK (([ResponseByteCount] IS NULL OR [ResponseByteCount] >= 0)
               AND ([ResponseChunkCount] IS NULL OR [ResponseChunkCount] >= 0))
    );

    CREATE INDEX [IX_Ace_AISupervisorAttempt_ExchangeId_StartedAtUtc]
        ON [Ace].[AISupervisorAttempt] ([ExchangeId], [StartedAtUtc], [AttemptId]);

    CREATE TABLE [Ace].[AISupervisorUsage]
    (
        [AttemptId] uniqueidentifier NOT NULL,
        [RequestTokens] bigint NULL,
        [ResponseTokens] bigint NULL,
        [AvailabilityCode] nvarchar(16) NOT NULL,
        [AvailabilityReason] nvarchar(256) NULL,
        [ProviderReported] bit NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_Ace_AISupervisorUsage] PRIMARY KEY ([AttemptId]),
        CONSTRAINT [FK_Ace_AISupervisorUsage_Attempt]
            FOREIGN KEY ([AttemptId]) REFERENCES [Ace].[AISupervisorAttempt] ([AttemptId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [CK_Ace_AISupervisorUsage_Counts]
            CHECK (([RequestTokens] IS NULL OR [RequestTokens] >= 0)
               AND ([ResponseTokens] IS NULL OR [ResponseTokens] >= 0)),
        CONSTRAINT [CK_Ace_AISupervisorUsage_Availability]
            CHECK (([AvailabilityCode] = N'Complete'
                    AND [RequestTokens] IS NOT NULL AND [ResponseTokens] IS NOT NULL)
                OR ([AvailabilityCode] = N'Partial'
                    AND (([RequestTokens] IS NOT NULL AND [ResponseTokens] IS NULL)
                      OR ([RequestTokens] IS NULL AND [ResponseTokens] IS NOT NULL)))
                OR ([AvailabilityCode] = N'Missing'
                    AND [RequestTokens] IS NULL AND [ResponseTokens] IS NULL)),
        CONSTRAINT [CK_Ace_AISupervisorUsage_Reason]
            CHECK (([AvailabilityCode] = N'Complete' AND [AvailabilityReason] IS NULL)
                OR ([AvailabilityCode] <> N'Complete'
                    AND [AvailabilityReason] IS NOT NULL
                    AND DATALENGTH([AvailabilityReason]) BETWEEN 2 AND 512
                    AND [AvailabilityReason] = LTRIM(RTRIM([AvailabilityReason]))))
    );

    CREATE TABLE [Ace].[AISupervisorMetricCatalog]
    (
        [MetricCode] nvarchar(64) NOT NULL,
        [UnitCode] nvarchar(32) NOT NULL,
        [Description] nvarchar(256) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_Ace_AISupervisorMetricCatalog] PRIMARY KEY ([MetricCode]),
        CONSTRAINT [CK_Ace_AISupervisorMetricCatalog_Code]
            CHECK (DATALENGTH([MetricCode]) BETWEEN 2 AND 128
                   AND [MetricCode] = LOWER(LTRIM(RTRIM([MetricCode])))),
        CONSTRAINT [CK_Ace_AISupervisorMetricCatalog_Unit]
            CHECK (DATALENGTH([UnitCode]) BETWEEN 2 AND 64
                   AND [UnitCode] = LOWER(LTRIM(RTRIM([UnitCode]))))
    );

    CREATE TABLE [Ace].[AISupervisorMetric]
    (
        [MetricId] uniqueidentifier NOT NULL,
        [AttemptId] uniqueidentifier NOT NULL,
        [MetricOrdinal] int NOT NULL,
        [DirectionCode] nvarchar(16) NOT NULL,
        [MetricCode] nvarchar(64) NOT NULL,
        [NumericValue] decimal(38, 9) NOT NULL,
        [SourceField] nvarchar(128) NULL,
        [ProviderReported] bit NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_Ace_AISupervisorMetric] PRIMARY KEY ([MetricId]),
        CONSTRAINT [FK_Ace_AISupervisorMetric_Attempt]
            FOREIGN KEY ([AttemptId]) REFERENCES [Ace].[AISupervisorAttempt] ([AttemptId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_Ace_AISupervisorMetric_Catalog]
            FOREIGN KEY ([MetricCode]) REFERENCES [Ace].[AISupervisorMetricCatalog] ([MetricCode])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [CK_Ace_AISupervisorMetric_Ordinal]
            CHECK ([MetricOrdinal] BETWEEN 0 AND 2147483646),
        CONSTRAINT [CK_Ace_AISupervisorMetric_Direction]
            CHECK ([DirectionCode] IN (N'Request', N'Response', N'Exchange'))
    );

    CREATE INDEX [IX_Ace_AISupervisorMetric_AttemptId_Code]
        ON [Ace].[AISupervisorMetric] ([AttemptId], [MetricCode], [MetricOrdinal]);

    INSERT INTO [Ace].[TagNamespace]
        ([TagNamespaceId], [NamespaceCode], [RecordedAtUtc])
    VALUES
        ('f037455a-ce98-4d9f-8f30-3d8bcc04f6cc',
         N'aisupervisor-classified',
         CONVERT(datetime2(7), '2026-09-01T00:00:00.0000000'));

    INSERT INTO [Ace].[AISupervisorMetricCatalog]
        ([MetricCode], [UnitCode], [Description], [RecordedAtUtc])
    VALUES
        (N'cache_read_tokens', N'tokens', N'Provider-reported cache-read token count.', CONVERT(datetime2(7), '2026-09-01T00:00:00.0000000')),
        (N'cache_write_tokens', N'tokens', N'Provider-reported cache-write token count.', CONVERT(datetime2(7), '2026-09-01T00:00:00.0000000')),
        (N'reasoning_tokens', N'tokens', N'Provider-reported thinking or reasoning token count.', CONVERT(datetime2(7), '2026-09-01T00:00:00.0000000')),
        (N'response_bytes', N'bytes', N'Observed response byte count.', CONVERT(datetime2(7), '2026-09-01T00:00:00.0000000')),
        (N'response_chunks', N'chunks', N'Observed response chunk count.', CONVERT(datetime2(7), '2026-09-01T00:00:00.0000000')),
        (N'tool_tokens', N'tokens', N'Provider-reported tool token count.', CONVERT(datetime2(7), '2026-09-01T00:00:00.0000000'));

    EXEC sys.sp_executesql N'CREATE TYPE [Ace].[AISupervisorTagInput] AS TABLE
    (
        [ExchangeTagId] uniqueidentifier NOT NULL PRIMARY KEY,
        [Ordinal] int NOT NULL,
        [TagText] nvarchar(256) COLLATE Latin1_General_100_CI_AS_SC NOT NULL
    );';

    EXEC sys.sp_executesql N'CREATE TYPE [Ace].[AISupervisorMetricInput] AS TABLE
    (
        [MetricId] uniqueidentifier NOT NULL PRIMARY KEY,
        [MetricOrdinal] int NOT NULL,
        [DirectionCode] nvarchar(16) NOT NULL,
        [MetricCode] nvarchar(64) NOT NULL,
        [NumericValue] decimal(38, 9) NOT NULL,
        [SourceField] nvarchar(128) NULL,
        [ProviderReported] bit NOT NULL
    );';

    DECLARE @AppendOnlyObjects TABLE ([ObjectName] sysname NOT NULL, [ErrorNumber] int NOT NULL);
    INSERT INTO @AppendOnlyObjects ([ObjectName], [ErrorNumber]) VALUES
        (N'AISupervisorExchange', 57020), (N'AISupervisorPrompt', 57021),
        (N'AISupervisorExchangeTag', 57022), (N'AISupervisorAttempt', 57023),
        (N'AISupervisorUsage', 57024), (N'AISupervisorMetricCatalog', 57025),
        (N'AISupervisorMetric', 57026);

    DECLARE @ObjectName sysname;
    DECLARE @ErrorNumber int;
    DECLARE AppendOnlyCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT [ObjectName], [ErrorNumber] FROM @AppendOnlyObjects;
    OPEN AppendOnlyCursor;
    FETCH NEXT FROM AppendOnlyCursor INTO @ObjectName, @ErrorNumber;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @TriggerSql nvarchar(max) =
            N'CREATE TRIGGER [Ace].[TR_' + @ObjectName + N'_AppendOnly] ON [Ace].[' +
            @ObjectName + N'] AFTER UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW ' +
            CONVERT(nvarchar(10), @ErrorNumber) + N', ''Ace AISupervisor rows are append-only.'', 1; END;';
        EXEC sys.sp_executesql @TriggerSql;
        FETCH NEXT FROM AppendOnlyCursor INTO @ObjectName, @ErrorNumber;
    END;
    CLOSE AppendOnlyCursor;
    DEALLOCATE AppendOnlyCursor;

    EXEC sys.sp_executesql N'CREATE PROCEDURE [Ace].[CaptureAISupervisorAttempt]
    @ExchangeId uniqueidentifier,
    @IdempotencyKey uniqueidentifier,
    @CanonicalEnvelopeHash binary(32),
    @Harness nvarchar(64),
    @HarnessVersion nvarchar(64) = NULL,
    @Provider nvarchar(64),
    @Model nvarchar(128) = NULL,
    @ModelVersion nvarchar(128) = NULL,
    @Effort nvarchar(64) = NULL,
    @ConversationId nvarchar(256) = NULL,
    @SessionId nvarchar(256) = NULL,
    @CorrelationId nvarchar(128),
    @EndpointClassification nvarchar(128),
    @ConsentVersion nvarchar(64),
    @ExchangeStartedAtUtc datetime2(7),
    @ExchangeRecordedAtUtc datetime2(7),
    @SanitizedPrompt nvarchar(max) = NULL,
    @PromptHash binary(32) = NULL,
    @PromptClassificationCode nvarchar(64) = NULL,
    @AttemptId uniqueidentifier,
    @AttemptOrdinal int,
    @CanonicalAttemptHash binary(32),
    @OutcomeCode nvarchar(32),
    @ProviderStatusCode int = NULL,
    @AttemptStartedAtUtc datetime2(7),
    @AttemptCompletedAtUtc datetime2(7),
    @ResponseByteCount bigint = NULL,
    @ResponseChunkCount bigint = NULL,
    @RequestTokens bigint = NULL,
    @ResponseTokens bigint = NULL,
    @AvailabilityCode nvarchar(16),
    @AvailabilityReason nvarchar(256) = NULL,
    @UsageProviderReported bit,
    @Tags [Ace].[AISupervisorTagInput] READONLY,
    @Metrics [Ace].[AISupervisorMetricInput] READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ExchangeId IS NULL OR @IdempotencyKey IS NULL OR @AttemptId IS NULL
       OR @CanonicalEnvelopeHash IS NULL OR DATALENGTH(@CanonicalEnvelopeHash) <> 32
       OR @CanonicalAttemptHash IS NULL OR DATALENGTH(@CanonicalAttemptHash) <> 32
       OR DATALENGTH(@Harness) NOT BETWEEN 2 AND 128 OR @Harness <> LTRIM(RTRIM(@Harness))
       OR DATALENGTH(@Provider) NOT BETWEEN 2 AND 128 OR @Provider <> LTRIM(RTRIM(@Provider))
       OR DATALENGTH(@CorrelationId) NOT BETWEEN 2 AND 256 OR @CorrelationId <> LTRIM(RTRIM(@CorrelationId))
       OR DATALENGTH(@EndpointClassification) NOT BETWEEN 2 AND 256 OR @EndpointClassification <> LTRIM(RTRIM(@EndpointClassification))
       OR DATALENGTH(@ConsentVersion) NOT BETWEEN 2 AND 128 OR @ConsentVersion <> LTRIM(RTRIM(@ConsentVersion))
       OR (@HarnessVersion IS NOT NULL AND
           (DATALENGTH(@HarnessVersion) NOT BETWEEN 2 AND 128 OR @HarnessVersion <> LTRIM(RTRIM(@HarnessVersion))))
       OR (@Model IS NOT NULL AND
           (DATALENGTH(@Model) NOT BETWEEN 2 AND 256 OR @Model <> LTRIM(RTRIM(@Model))))
       OR (@ModelVersion IS NOT NULL AND
           (DATALENGTH(@ModelVersion) NOT BETWEEN 2 AND 256 OR @ModelVersion <> LTRIM(RTRIM(@ModelVersion))))
       OR (@Effort IS NOT NULL AND
           (DATALENGTH(@Effort) NOT BETWEEN 2 AND 128 OR @Effort <> LTRIM(RTRIM(@Effort))))
       OR (@ConversationId IS NOT NULL AND
           (DATALENGTH(@ConversationId) NOT BETWEEN 2 AND 512 OR @ConversationId <> LTRIM(RTRIM(@ConversationId))))
       OR (@SessionId IS NOT NULL AND
           (DATALENGTH(@SessionId) NOT BETWEEN 2 AND 512 OR @SessionId <> LTRIM(RTRIM(@SessionId))))
       OR @ExchangeStartedAtUtc IS NULL OR @ExchangeRecordedAtUtc < @ExchangeStartedAtUtc
       OR @AttemptOrdinal NOT BETWEEN 0 AND 2147483646
       OR @OutcomeCode NOT IN (N''Completed'', N''Failed'', N''Cancelled'', N''Abandoned'')
       OR @AttemptStartedAtUtc IS NULL OR @AttemptCompletedAtUtc < @AttemptStartedAtUtc
       OR (@ProviderStatusCode IS NOT NULL AND @ProviderStatusCode NOT BETWEEN 100 AND 599)
       OR (@ResponseByteCount IS NOT NULL AND @ResponseByteCount < 0)
       OR (@ResponseChunkCount IS NOT NULL AND @ResponseChunkCount < 0)
        THROW 57004, ''Invalid AISupervisor exchange or attempt metadata.'', 1;

    IF (@SanitizedPrompt IS NULL AND (@PromptHash IS NOT NULL OR @PromptClassificationCode IS NOT NULL))
       OR (@SanitizedPrompt IS NOT NULL AND
           (DATALENGTH(@SanitizedPrompt) NOT BETWEEN 2 AND 16384
            OR @PromptHash IS NULL OR DATALENGTH(@PromptHash) <> 32
            OR DATALENGTH(@PromptClassificationCode) NOT BETWEEN 2 AND 128))
        THROW 57005, ''The sanitized prompt tuple is incomplete or out of range.'', 1;

    IF EXISTS (SELECT 1 FROM @Tags WHERE [Ordinal] NOT BETWEEN 0 AND 2147483646
       OR DATALENGTH([TagText]) NOT BETWEEN 2 AND 512 OR [TagText] <> LTRIM(RTRIM([TagText])))
        THROW 57006, ''One or more AISupervisor Tags are invalid.'', 1;

    IF EXISTS (SELECT 1 FROM @Metrics AS inputMetric
        LEFT JOIN [Ace].[AISupervisorMetricCatalog] AS catalog
          ON catalog.[MetricCode] = inputMetric.[MetricCode]
        WHERE inputMetric.[MetricOrdinal] NOT BETWEEN 0 AND 2147483646
           OR inputMetric.[DirectionCode] NOT IN (N''Request'', N''Response'', N''Exchange'')
           OR catalog.[MetricCode] IS NULL)
        THROW 57007, ''One or more AISupervisor metrics are invalid or uncontrolled.'', 1;

    IF (@RequestTokens IS NOT NULL AND @RequestTokens < 0)
       OR (@ResponseTokens IS NOT NULL AND @ResponseTokens < 0)
       OR NOT ((@AvailabilityCode = N''Complete'' AND @RequestTokens IS NOT NULL AND @ResponseTokens IS NOT NULL AND @AvailabilityReason IS NULL)
             OR (@AvailabilityCode = N''Partial''
                 AND ((@RequestTokens IS NOT NULL AND @ResponseTokens IS NULL)
                   OR (@RequestTokens IS NULL AND @ResponseTokens IS NOT NULL))
                 AND @AvailabilityReason IS NOT NULL AND DATALENGTH(@AvailabilityReason) BETWEEN 2 AND 512)
             OR (@AvailabilityCode = N''Missing'' AND @RequestTokens IS NULL AND @ResponseTokens IS NULL
                 AND @AvailabilityReason IS NOT NULL AND DATALENGTH(@AvailabilityReason) BETWEEN 2 AND 512))
        THROW 57008, ''AISupervisor usage availability does not match the supplied counts.'', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @LockResult int;
        DECLARE @LockResource nvarchar(255) =
            N''Ace.AISupervisorExchange:'' + LOWER(CONVERT(nvarchar(36), @IdempotencyKey));
        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = ''Exclusive'', @LockOwner = ''Transaction'', @LockTimeout = 25000,
            @DbPrincipal = ''public'';
        IF @LockResult < 0 THROW 57009, ''Unable to acquire the AISupervisor idempotency lock.'', 1;

        DECLARE @ExistingExchangeId uniqueidentifier;
        DECLARE @ExistingEnvelopeHash binary(32);
        SELECT @ExistingExchangeId = [ExchangeId], @ExistingEnvelopeHash = [CanonicalEnvelopeHash]
        FROM [Ace].[AISupervisorExchange] WITH (UPDLOCK, HOLDLOCK)
        WHERE [IdempotencyKey] = @IdempotencyKey;

        IF @ExistingExchangeId IS NOT NULL AND
           (@ExistingExchangeId <> @ExchangeId OR @ExistingEnvelopeHash <> @CanonicalEnvelopeHash)
            THROW 57010, ''The AISupervisor idempotency key is bound to another envelope.'', 1;

        IF @ExistingExchangeId IS NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM [Ace].[AISupervisorExchange] WITH (UPDLOCK, HOLDLOCK)
                       WHERE [ExchangeId] = @ExchangeId)
                THROW 57011, ''The AISupervisor exchange identity is already in use.'', 1;

            INSERT INTO [Ace].[AISupervisorExchange]
                ([ExchangeId], [IdempotencyKey], [CanonicalEnvelopeHash], [Harness], [HarnessVersion],
                 [Provider], [Model], [ModelVersion], [Effort], [ConversationId], [SessionId],
                 [CorrelationId], [EndpointClassification], [ConsentVersion], [StartedAtUtc], [RecordedAtUtc])
            VALUES
                (@ExchangeId, @IdempotencyKey, @CanonicalEnvelopeHash, @Harness, @HarnessVersion,
                 @Provider, @Model, @ModelVersion, @Effort, @ConversationId, @SessionId,
                 @CorrelationId, @EndpointClassification, @ConsentVersion, @ExchangeStartedAtUtc, @ExchangeRecordedAtUtc);

            IF @SanitizedPrompt IS NOT NULL
                INSERT INTO [Ace].[AISupervisorPrompt]
                    ([ExchangeId], [SanitizedPrompt], [PromptHash], [ClassificationCode], [RecordedAtUtc])
                VALUES
                    (@ExchangeId, @SanitizedPrompt, @PromptHash, @PromptClassificationCode, @ExchangeRecordedAtUtc);

            IF EXISTS (SELECT 1 FROM @Tags)
            BEGIN
                DECLARE @TagLockResult int;
                EXEC @TagLockResult = sys.sp_getapplock
                    @Resource = N''Ace.TagCanonicalization:aisupervisor-classified'',
                    @LockMode = ''Exclusive'', @LockOwner = ''Transaction'', @LockTimeout = 25000,
                    @DbPrincipal = ''public'';
                IF @TagLockResult < 0 THROW 57012, ''Unable to acquire the AISupervisor Tag lock.'', 1;

                ;WITH RankedTags AS
                (
                    SELECT [TagText], ROW_NUMBER() OVER (PARTITION BY [TagText] ORDER BY [ExchangeTagId]) AS [CanonicalOrdinal]
                    FROM @Tags
                )
                INSERT INTO [Ace].[Tag] ([TagId], [TagNamespaceId], [TagCode], [FirstRecordedAtUtc])
                SELECT NEWID(), CONVERT(uniqueidentifier, ''f037455a-ce98-4d9f-8f30-3d8bcc04f6cc''),
                       sourceTag.[TagText], @ExchangeRecordedAtUtc
                FROM RankedTags AS sourceTag
                WHERE sourceTag.[CanonicalOrdinal] = 1
                  AND NOT EXISTS
                  (
                      SELECT 1 FROM [Ace].[Tag] AS targetTag WITH (UPDLOCK, HOLDLOCK)
                      WHERE targetTag.[TagNamespaceId] = CONVERT(uniqueidentifier, ''f037455a-ce98-4d9f-8f30-3d8bcc04f6cc'')
                        AND targetTag.[TagCode] = sourceTag.[TagText]
                  );

                INSERT INTO [Ace].[AISupervisorExchangeTag]
                    ([ExchangeTagId], [ExchangeId], [Ordinal], [TagId], [SubmittedTagText])
                SELECT sourceTag.[ExchangeTagId], @ExchangeId, sourceTag.[Ordinal], targetTag.[TagId], sourceTag.[TagText]
                FROM @Tags AS sourceTag
                INNER JOIN [Ace].[Tag] AS targetTag
                  ON targetTag.[TagNamespaceId] = CONVERT(uniqueidentifier, ''f037455a-ce98-4d9f-8f30-3d8bcc04f6cc'')
                 AND targetTag.[TagCode] = sourceTag.[TagText];
                IF @@ROWCOUNT <> (SELECT COUNT(*) FROM @Tags)
                    THROW 57013, ''Not every AISupervisor Tag was captured.'', 1;
            END;
        END;

        DECLARE @ExistingAttemptHash binary(32);
        DECLARE @ExistingAttemptExchangeId uniqueidentifier;
        SELECT @ExistingAttemptHash = [CanonicalAttemptHash],
               @ExistingAttemptExchangeId = [ExchangeId]
        FROM [Ace].[AISupervisorAttempt] WITH (UPDLOCK, HOLDLOCK)
        WHERE [AttemptId] = @AttemptId;
        IF @ExistingAttemptHash IS NOT NULL
        BEGIN
            IF @ExistingAttemptHash <> @CanonicalAttemptHash OR @ExistingAttemptExchangeId <> @ExchangeId
                THROW 57014, ''The AISupervisor attempt identity is bound to another attempt.'', 1;
            SELECT @ExchangeId AS [ExchangeId], @AttemptId AS [AttemptId], CONVERT(bit, 1) AS [WasReplay];
            COMMIT TRANSACTION;
            RETURN;
        END;

        INSERT INTO [Ace].[AISupervisorAttempt]
            ([AttemptId], [ExchangeId], [AttemptOrdinal], [CanonicalAttemptHash], [OutcomeCode],
             [ProviderStatusCode], [StartedAtUtc], [CompletedAtUtc], [ResponseByteCount], [ResponseChunkCount])
        VALUES
            (@AttemptId, @ExchangeId, @AttemptOrdinal, @CanonicalAttemptHash, @OutcomeCode,
             @ProviderStatusCode, @AttemptStartedAtUtc, @AttemptCompletedAtUtc, @ResponseByteCount, @ResponseChunkCount);

        INSERT INTO [Ace].[AISupervisorUsage]
            ([AttemptId], [RequestTokens], [ResponseTokens], [AvailabilityCode],
             [AvailabilityReason], [ProviderReported], [RecordedAtUtc])
        VALUES
            (@AttemptId, @RequestTokens, @ResponseTokens, @AvailabilityCode,
             @AvailabilityReason, @UsageProviderReported, @AttemptCompletedAtUtc);

        INSERT INTO [Ace].[AISupervisorMetric]
            ([MetricId], [AttemptId], [MetricOrdinal], [DirectionCode], [MetricCode],
             [NumericValue], [SourceField], [ProviderReported], [RecordedAtUtc])
        SELECT [MetricId], @AttemptId, [MetricOrdinal], [DirectionCode], [MetricCode],
               [NumericValue], [SourceField], [ProviderReported], @AttemptCompletedAtUtc
        FROM @Metrics;

        SELECT @ExchangeId AS [ExchangeId], @AttemptId AS [AttemptId], CONVERT(bit, 0) AS [WasReplay];
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [Ace].[QueryGatherContentSubmissionTimeline]
    @FromUtc datetime2(7),
    @ToUtc datetime2(7),
    @PageSize int = 100
AS
BEGIN
    SET NOCOUNT ON;
    IF @FromUtc IS NULL OR @ToUtc <= @FromUtc OR @PageSize NOT BETWEEN 1 AND 500
        THROW 57015, ''Invalid gather-content timeline bounds.'', 1;

    SELECT TOP (@PageSize)
           submission.[GatherContentSubmissionId], submission.[IdempotencyKey], submission.[ApiVersion],
           submission.[Instance], submission.[Depth], submission.[Width], submission.[CallerPrincipalName],
           submission.[CorrelationId], submission.[ReceivedAtUtc], tags.[TagsJson]
    FROM [Ace].[GatherContentSubmission] AS submission
    CROSS APPLY
    (
        SELECT N''['' + STRING_AGG(
            N''{"ordinal":'' + CONVERT(nvarchar(12), item.[Ordinal]) +
            N'',"tag":"'' + STRING_ESCAPE(item.[SubmittedTagText], ''json'') + N''"}'', N'','')
            WITHIN GROUP (ORDER BY item.[Ordinal]) + N'']'' AS [TagsJson]
        FROM [Ace].[GatherContentSubmissionTag] AS item
        WHERE item.[GatherContentSubmissionId] = submission.[GatherContentSubmissionId]
    ) AS tags
    WHERE submission.[ReceivedAtUtc] >= @FromUtc AND submission.[ReceivedAtUtc] < @ToUtc
    ORDER BY submission.[ReceivedAtUtc], submission.[GatherContentSubmissionId];
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [Ace].[QueryAISupervisorExchangeTimeline]
    @FromUtc datetime2(7),
    @ToUtc datetime2(7),
    @PageSize int = 100
AS
BEGIN
    SET NOCOUNT ON;
    IF @FromUtc IS NULL OR @ToUtc <= @FromUtc OR @PageSize NOT BETWEEN 1 AND 500
        THROW 57016, ''Invalid AISupervisor exchange timeline bounds.'', 1;

    SELECT TOP (@PageSize)
           exchange.[ExchangeId], exchange.[Harness], exchange.[HarnessVersion], exchange.[Provider],
           exchange.[Model], exchange.[ModelVersion], exchange.[Effort], exchange.[ConversationId],
           exchange.[SessionId], exchange.[CorrelationId], exchange.[EndpointClassification],
           exchange.[ConsentVersion], exchange.[StartedAtUtc], exchange.[RecordedAtUtc],
           prompt.[SanitizedPrompt], prompt.[ClassificationCode] AS [PromptClassificationCode],
           tags.[TagsJson], attempt.[AttemptId], attempt.[AttemptOrdinal], attempt.[OutcomeCode],
           attempt.[ProviderStatusCode], attempt.[CompletedAtUtc], usage.[RequestTokens],
           usage.[ResponseTokens], usage.[AvailabilityCode], usage.[AvailabilityReason],
           usage.[ProviderReported]
    FROM [Ace].[AISupervisorExchange] AS exchange
    LEFT JOIN [Ace].[AISupervisorPrompt] AS prompt ON prompt.[ExchangeId] = exchange.[ExchangeId]
    LEFT JOIN [Ace].[AISupervisorAttempt] AS attempt ON attempt.[ExchangeId] = exchange.[ExchangeId]
    LEFT JOIN [Ace].[AISupervisorUsage] AS usage ON usage.[AttemptId] = attempt.[AttemptId]
    OUTER APPLY
    (
        SELECT N''['' + STRING_AGG(
            N''{"ordinal":'' + CONVERT(nvarchar(12), item.[Ordinal]) +
            N'',"tag":"'' + STRING_ESCAPE(item.[SubmittedTagText], ''json'') + N''"}'', N'','')
            WITHIN GROUP (ORDER BY item.[Ordinal], item.[ExchangeTagId]) + N'']'' AS [TagsJson]
        FROM [Ace].[AISupervisorExchangeTag] AS item
        WHERE item.[ExchangeId] = exchange.[ExchangeId]
    ) AS tags
    WHERE exchange.[StartedAtUtc] >= @FromUtc AND exchange.[StartedAtUtc] < @ToUtc
    ORDER BY exchange.[StartedAtUtc], exchange.[ExchangeId], attempt.[StartedAtUtc], attempt.[AttemptId];
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [Ace].[QueryAISupervisorTokenTimeline]
    @FromUtc datetime2(7),
    @ToUtc datetime2(7),
    @BucketMinutes int,
    @Harness nvarchar(64) = NULL,
    @Model nvarchar(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FromUtc IS NULL OR @ToUtc <= @FromUtc OR DATEDIFF(day, @FromUtc, @ToUtc) > 366
       OR @BucketMinutes NOT IN (1, 5, 15, 30, 60, 360, 1440)
        THROW 57017, ''Invalid AISupervisor token timeline bounds or bucket size.'', 1;

    ;WITH Bucketed AS
    (
        SELECT DATEADD(minute,
                       (DATEDIFF_BIG(minute, CONVERT(datetime2(7), ''2000-01-01T00:00:00''), attempt.[CompletedAtUtc]) / @BucketMinutes) * @BucketMinutes,
                       CONVERT(datetime2(7), ''2000-01-01T00:00:00'')) AS [BucketStartUtc],
               exchange.[Harness], exchange.[Model], exchange.[Effort], attempt.[AttemptId],
               usage.[RequestTokens], usage.[ResponseTokens], usage.[AvailabilityCode]
        FROM [Ace].[AISupervisorAttempt] AS attempt
        INNER JOIN [Ace].[AISupervisorExchange] AS exchange ON exchange.[ExchangeId] = attempt.[ExchangeId]
        INNER JOIN [Ace].[AISupervisorUsage] AS usage ON usage.[AttemptId] = attempt.[AttemptId]
        WHERE attempt.[CompletedAtUtc] >= @FromUtc AND attempt.[CompletedAtUtc] < @ToUtc
          AND (@Harness IS NULL OR exchange.[Harness] = @Harness)
          AND (@Model IS NULL OR exchange.[Model] = @Model)
    )
    SELECT [BucketStartUtc], DATEADD(minute, @BucketMinutes, [BucketStartUtc]) AS [BucketEndUtc],
           [Harness], [Model], [Effort], COUNT_BIG(*) AS [AttemptCount],
           SUM([RequestTokens]) AS [RequestTokens], SUM([ResponseTokens]) AS [ResponseTokens],
           SUM(CASE WHEN [AvailabilityCode] = N''Complete'' THEN 0 ELSE 1 END) AS [MissingOrPartialCount],
           CASE WHEN MIN(CASE WHEN [AvailabilityCode] = N''Complete'' THEN 1 ELSE 0 END) = 1
                THEN N''Complete''
                WHEN MAX(CASE WHEN [AvailabilityCode] = N''Missing'' THEN 0 ELSE 1 END) = 0
                THEN N''Missing''
                ELSE N''Partial'' END AS [CompletenessCode]
    FROM Bucketed
    GROUP BY [BucketStartUtc], [Harness], [Model], [Effort]
    ORDER BY [BucketStartUtc], [Harness], [Model], [Effort];
END;';

    EXEC sys.sp_executesql N'CREATE ROLE [AceAISupervisorCaptureExecutor] AUTHORIZATION [dbo];';
    EXEC sys.sp_executesql N'CREATE ROLE [AceCommanderTimelineReader] AUTHORIZATION [dbo];';

    GRANT EXECUTE ON OBJECT::[Ace].[CaptureAISupervisorAttempt] TO [AceAISupervisorCaptureExecutor];
    GRANT EXECUTE ON TYPE::[Ace].[AISupervisorTagInput] TO [AceAISupervisorCaptureExecutor];
    GRANT EXECUTE ON TYPE::[Ace].[AISupervisorMetricInput] TO [AceAISupervisorCaptureExecutor];
    GRANT EXECUTE ON OBJECT::[Ace].[QueryGatherContentSubmissionTimeline] TO [AceCommanderTimelineReader];
    GRANT EXECUTE ON OBJECT::[Ace].[QueryAISupervisorExchangeTimeline] TO [AceCommanderTimelineReader];
    GRANT EXECUTE ON OBJECT::[Ace].[QueryAISupervisorTokenTimeline] TO [AceCommanderTimelineReader];

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

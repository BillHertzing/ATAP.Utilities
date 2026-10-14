/*
  Ace gather-content submission and direct current-Tag query slice (Task 15.185.b).

  Authority: RestDatabasePhysicalContractDecision.md, ratified 2026-08-31.
  This forward-only migration writes only Ace-owned objects. ATAPUtilities.Tag*
  remains read-only. Prompt, metering telemetry, users, and role
  memberships are explicitly excluded.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'[ATAPUtilities].[TagNamespace]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[Tag]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[TagState]', N'U') IS NULL
        THROW 56001, N'The deployed V00050 ATAPUtilities Tag root is required.', 1;

    IF SCHEMA_ID(N'Ace') IS NULL
        EXEC sys.sp_executesql N'CREATE SCHEMA [Ace] AUTHORIZATION [dbo];';
    ELSE IF DATABASE_PRINCIPAL_ID(N'dbo') <>
            (SELECT [principal_id] FROM sys.schemas WHERE [name] = N'Ace')
        THROW 56002, N'The existing Ace schema is not owned by dbo.', 1;

    IF OBJECT_ID(N'[Ace].[TagNamespace]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[Ace].[Tag]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[Ace].[GatherContentSubmission]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[Ace].[GatherContentSubmissionTag]', N'U') IS NOT NULL
       OR TYPE_ID(N'[Ace].[GatherContentTagInput]') IS NOT NULL
       OR OBJECT_ID(N'[Ace].[CaptureGatherContentSubmission]', N'P') IS NOT NULL
       OR OBJECT_ID(N'[Ace].[QueryGatherContentV1]', N'P') IS NOT NULL
        THROW 56003, N'One or more V00060 target objects already exist.', 1;

    IF DATABASE_PRINCIPAL_ID(N'AceGatherContentCaptureExecutor') IS NOT NULL
       OR DATABASE_PRINCIPAL_ID(N'AceGatherContentQueryExecutor') IS NOT NULL
       OR DATABASE_PRINCIPAL_ID(N'AceGatherContentSubmissionReader') IS NOT NULL
        THROW 56004, N'One or more V00060 database roles already exist.', 1;

    CREATE TABLE [Ace].[TagNamespace]
    (
        [TagNamespaceId] uniqueidentifier NOT NULL,
        [NamespaceCode] nvarchar(128) COLLATE Latin1_General_100_CI_AS_SC NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_Ace_TagNamespace] PRIMARY KEY ([TagNamespaceId]),
        CONSTRAINT [UQ_Ace_TagNamespace_NamespaceCode] UNIQUE ([NamespaceCode]),
        CONSTRAINT [CK_Ace_TagNamespace_NamespaceCode]
            CHECK (DATALENGTH([NamespaceCode]) BETWEEN 2 AND 256
                   AND [NamespaceCode] = LTRIM(RTRIM([NamespaceCode])))
    );

    CREATE TABLE [Ace].[Tag]
    (
        [TagId] uniqueidentifier NOT NULL,
        [TagNamespaceId] uniqueidentifier NOT NULL,
        [TagCode] nvarchar(256) COLLATE Latin1_General_100_CI_AS_SC NOT NULL,
        [FirstRecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_Ace_Tag] PRIMARY KEY ([TagId]),
        CONSTRAINT [FK_Ace_Tag_TagNamespace]
            FOREIGN KEY ([TagNamespaceId]) REFERENCES [Ace].[TagNamespace] ([TagNamespaceId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_Ace_Tag_TagNamespaceId_TagCode]
            UNIQUE ([TagNamespaceId], [TagCode]),
        CONSTRAINT [CK_Ace_Tag_TagCode]
            CHECK (DATALENGTH([TagCode]) BETWEEN 2 AND 512
                   AND [TagCode] = LTRIM(RTRIM([TagCode])))
    );

    CREATE TABLE [Ace].[GatherContentSubmission]
    (
        [GatherContentSubmissionId] uniqueidentifier NOT NULL,
        [IdempotencyKey] uniqueidentifier NOT NULL,
        [CanonicalRequestHash] binary(32) NOT NULL,
        [ApiVersion] smallint NOT NULL,
        [Instance] nvarchar(64) NOT NULL,
        [Depth] int NOT NULL,
        [Width] int NOT NULL,
        [CallerPrincipalName] nvarchar(256) NOT NULL,
        [CorrelationId] nvarchar(128) NOT NULL,
        [ReceivedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_Ace_GatherContentSubmission]
            PRIMARY KEY ([GatherContentSubmissionId]),
        CONSTRAINT [UQ_Ace_GatherContentSubmission_IdempotencyKey]
            UNIQUE ([IdempotencyKey]),
        CONSTRAINT [CK_Ace_GatherContentSubmission_ApiVersion]
            CHECK ([ApiVersion] = 1),
        CONSTRAINT [CK_Ace_GatherContentSubmission_Instance]
            CHECK (DATALENGTH([Instance]) BETWEEN 2 AND 128
                   AND [Instance] = LTRIM(RTRIM([Instance]))),
        CONSTRAINT [CK_Ace_GatherContentSubmission_Depth]
            CHECK ([Depth] BETWEEN 1 AND 100),
        CONSTRAINT [CK_Ace_GatherContentSubmission_Width]
            CHECK ([Width] BETWEEN 1 AND 100),
        CONSTRAINT [CK_Ace_GatherContentSubmission_CallerPrincipalName]
            CHECK (DATALENGTH([CallerPrincipalName]) BETWEEN 2 AND 512
                   AND [CallerPrincipalName] = LTRIM(RTRIM([CallerPrincipalName]))),
        CONSTRAINT [CK_Ace_GatherContentSubmission_CorrelationId]
            CHECK (DATALENGTH([CorrelationId]) BETWEEN 2 AND 256
                   AND [CorrelationId] = LTRIM(RTRIM([CorrelationId])))
    );

    CREATE TABLE [Ace].[GatherContentSubmissionTag]
    (
        [GatherContentSubmissionId] uniqueidentifier NOT NULL,
        [Ordinal] tinyint NOT NULL,
        [TagId] uniqueidentifier NOT NULL,
        [SubmittedTagText] nvarchar(256) COLLATE Latin1_General_100_CI_AS_SC NOT NULL,
        CONSTRAINT [PK_Ace_GatherContentSubmissionTag]
            PRIMARY KEY ([GatherContentSubmissionId], [Ordinal]),
        CONSTRAINT [FK_Ace_GatherContentSubmissionTag_Submission]
            FOREIGN KEY ([GatherContentSubmissionId])
            REFERENCES [Ace].[GatherContentSubmission] ([GatherContentSubmissionId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_Ace_GatherContentSubmissionTag_Tag]
            FOREIGN KEY ([TagId]) REFERENCES [Ace].[Tag] ([TagId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [CK_Ace_GatherContentSubmissionTag_Ordinal]
            CHECK ([Ordinal] BETWEEN 0 AND 11),
        CONSTRAINT [CK_Ace_GatherContentSubmissionTag_SubmittedTagText]
            CHECK (DATALENGTH([SubmittedTagText]) BETWEEN 2 AND 512
                   AND [SubmittedTagText] = LTRIM(RTRIM([SubmittedTagText])))
    );

    CREATE INDEX [IX_Ace_GatherContentSubmissionTag_TagId_SubmissionId]
        ON [Ace].[GatherContentSubmissionTag]
            ([TagId], [GatherContentSubmissionId]);

    INSERT INTO [Ace].[TagNamespace]
        ([TagNamespaceId], [NamespaceCode], [RecordedAtUtc])
    VALUES
        ('c44cbf22-bdad-4695-9067-4adee6d586c5',
         N'gather-content-submitted',
         CONVERT(datetime2(7), '2026-08-31T00:00:00.0000000'));

    EXEC sys.sp_executesql N'CREATE TYPE [Ace].[GatherContentTagInput] AS TABLE
    (
        [Ordinal] tinyint NOT NULL PRIMARY KEY,
        [TagText] nvarchar(256) COLLATE Latin1_General_100_CI_AS_SC NOT NULL
    );';

    EXEC sys.sp_executesql N'CREATE TRIGGER [Ace].[TR_TagNamespace_AppendOnly]
ON [Ace].[TagNamespace]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 56020, ''Ace TagNamespace rows are append-only.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [Ace].[TR_Tag_AppendOnly]
ON [Ace].[Tag]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 56021, ''Ace Tag rows are append-only.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [Ace].[TR_GatherContentSubmission_AppendOnly]
ON [Ace].[GatherContentSubmission]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 56022, ''Gather-content submission rows are append-only.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [Ace].[TR_GatherContentSubmissionTag_AppendOnly]
ON [Ace].[GatherContentSubmissionTag]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 56023, ''Gather-content submission Tag rows are append-only.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [Ace].[CaptureGatherContentSubmission]
    @GatherContentSubmissionId uniqueidentifier,
    @IdempotencyKey uniqueidentifier,
    @CanonicalRequestHash binary(32),
    @ApiVersion smallint,
    @Instance nvarchar(64),
    @Depth int,
    @Width int,
    @CallerPrincipalName nvarchar(256),
    @CorrelationId nvarchar(128),
    @ReceivedAtUtc datetime2(7),
    @Tags [Ace].[GatherContentTagInput] READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @GatherContentSubmissionId IS NULL OR @IdempotencyKey IS NULL
       OR @CanonicalRequestHash IS NULL OR DATALENGTH(@CanonicalRequestHash) <> 32
       OR @ApiVersion <> 1
       OR DATALENGTH(@Instance) NOT BETWEEN 2 AND 128
       OR @Instance <> LTRIM(RTRIM(@Instance))
       OR @Depth NOT BETWEEN 1 AND 100
       OR @Width NOT BETWEEN 1 AND 100
       OR DATALENGTH(@CallerPrincipalName) NOT BETWEEN 2 AND 512
       OR @CallerPrincipalName <> LTRIM(RTRIM(@CallerPrincipalName))
       OR DATALENGTH(@CorrelationId) NOT BETWEEN 2 AND 256
       OR @CorrelationId <> LTRIM(RTRIM(@CorrelationId))
       OR @ReceivedAtUtc IS NULL
        THROW 56005, ''Invalid gather-content submission metadata.'', 1;

    IF (SELECT COUNT_BIG(*) FROM @Tags) NOT BETWEEN 1 AND 12
       OR EXISTS
          (
              SELECT 1 FROM @Tags
              WHERE [Ordinal] NOT BETWEEN 0 AND 11
                 OR DATALENGTH([TagText]) NOT BETWEEN 2 AND 512
                 OR [TagText] <> LTRIM(RTRIM([TagText]))
          )
       OR (SELECT MIN([Ordinal]) FROM @Tags) <> 0
       OR (SELECT MAX([Ordinal]) FROM @Tags) <>
            CONVERT(tinyint, (SELECT COUNT(*) FROM @Tags) - 1)
        THROW 56006, ''Gather-content Tags violate the ratified count, ordinal, or text limits.'', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IdempotencyLockResult int;
        DECLARE @IdempotencyLockResource nvarchar(255) =
            N''Ace.GatherContentSubmission:'' +
            LOWER(CONVERT(nvarchar(36), @IdempotencyKey));
        EXEC @IdempotencyLockResult = sys.sp_getapplock
            @Resource = @IdempotencyLockResource,
            @LockMode = ''Exclusive'',
            @LockOwner = ''Transaction'',
            @LockTimeout = 25000,
            @DbPrincipal = ''public'';
        IF @IdempotencyLockResult < 0
            THROW 56007, ''Unable to acquire the gather-content idempotency lock.'', 1;

        DECLARE @ExistingSubmissionId uniqueidentifier;
        DECLARE @ExistingRequestHash binary(32);
        SELECT
            @ExistingSubmissionId = [GatherContentSubmissionId],
            @ExistingRequestHash = [CanonicalRequestHash]
        FROM [Ace].[GatherContentSubmission] WITH (UPDLOCK, HOLDLOCK)
        WHERE [IdempotencyKey] = @IdempotencyKey;

        IF @ExistingSubmissionId IS NOT NULL
        BEGIN
            IF @ExistingRequestHash <> @CanonicalRequestHash
                THROW 56008, ''The idempotency key is already bound to a different canonical request.'', 1;

            SELECT @ExistingSubmissionId AS [GatherContentSubmissionId],
                   CONVERT(bit, 1) AS [WasReplay];
            COMMIT TRANSACTION;
            RETURN;
        END;

        IF EXISTS
        (
            SELECT 1 FROM [Ace].[GatherContentSubmission] WITH (UPDLOCK, HOLDLOCK)
            WHERE [GatherContentSubmissionId] = @GatherContentSubmissionId
        )
            THROW 56009, ''The submission identity is already bound to another request.'', 1;

        DECLARE @TagLockResult int;
        EXEC @TagLockResult = sys.sp_getapplock
            @Resource = N''Ace.TagCanonicalization:gather-content-submitted'',
            @LockMode = ''Exclusive'',
            @LockOwner = ''Transaction'',
            @LockTimeout = 25000,
            @DbPrincipal = ''public'';
        IF @TagLockResult < 0
            THROW 56010, ''Unable to acquire the Ace Tag canonicalization lock.'', 1;

        INSERT INTO [Ace].[GatherContentSubmission]
            ([GatherContentSubmissionId], [IdempotencyKey], [CanonicalRequestHash],
             [ApiVersion], [Instance], [Depth], [Width], [CallerPrincipalName],
             [CorrelationId], [ReceivedAtUtc])
        VALUES
            (@GatherContentSubmissionId, @IdempotencyKey, @CanonicalRequestHash,
             @ApiVersion, @Instance, @Depth, @Width, @CallerPrincipalName,
             @CorrelationId, @ReceivedAtUtc);

        ;WITH RankedTags AS
        (
            SELECT [TagText],
                  ROW_NUMBER() OVER
                  (
                      PARTITION BY [TagText]
                      ORDER BY [Ordinal]
                  ) AS [CanonicalOrdinal]
            FROM @Tags
        )
        INSERT INTO [Ace].[Tag]
            ([TagId], [TagNamespaceId], [TagCode], [FirstRecordedAtUtc])
        SELECT NEWID(),
               CONVERT(uniqueidentifier, ''c44cbf22-bdad-4695-9067-4adee6d586c5''),
               sourceTag.[TagText],
               @ReceivedAtUtc
        FROM RankedTags AS sourceTag
        WHERE sourceTag.[CanonicalOrdinal] = 1
          AND NOT EXISTS
        (
            SELECT 1
            FROM [Ace].[Tag] AS targetTag WITH (UPDLOCK, HOLDLOCK)
            WHERE targetTag.[TagNamespaceId] =
                    CONVERT(uniqueidentifier, ''c44cbf22-bdad-4695-9067-4adee6d586c5'')
              AND targetTag.[TagCode] = sourceTag.[TagText]
        );

        INSERT INTO [Ace].[GatherContentSubmissionTag]
            ([GatherContentSubmissionId], [Ordinal], [TagId], [SubmittedTagText])
        SELECT @GatherContentSubmissionId,
               sourceTag.[Ordinal],
               targetTag.[TagId],
               sourceTag.[TagText]
        FROM @Tags AS sourceTag
        INNER JOIN [Ace].[Tag] AS targetTag
            ON targetTag.[TagNamespaceId] =
                CONVERT(uniqueidentifier, ''c44cbf22-bdad-4695-9067-4adee6d586c5'')
           AND targetTag.[TagCode] = sourceTag.[TagText];

        IF @@ROWCOUNT <> (SELECT COUNT(*) FROM @Tags)
            THROW 56011, ''Not every submitted Tag was captured.'', 1;

        SELECT @GatherContentSubmissionId AS [GatherContentSubmissionId],
               CONVERT(bit, 0) AS [WasReplay];
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [Ace].[QueryGatherContentV1]
    @Tags [Ace].[GatherContentTagInput] READONLY
AS
BEGIN
    SET NOCOUNT ON;

    IF (SELECT COUNT_BIG(*) FROM @Tags) NOT BETWEEN 1 AND 12
       OR EXISTS
          (
              SELECT 1 FROM @Tags
              WHERE [Ordinal] NOT BETWEEN 0 AND 11
                 OR DATALENGTH([TagText]) NOT BETWEEN 2 AND 512
                 OR [TagText] <> LTRIM(RTRIM([TagText]))
          )
       OR (SELECT MIN([Ordinal]) FROM @Tags) <> 0
       OR (SELECT MAX([Ordinal]) FROM @Tags) <>
            CONVERT(tinyint, (SELECT COUNT(*) FROM @Tags) - 1)
        THROW 56012, ''Gather-content query Tags violate the ratified limits.'', 1;

    IF EXISTS
    (
        SELECT inputTag.[TagText]
        FROM @Tags AS inputTag
        INNER JOIN [ATAPUtilities].[Tag] AS tag
            ON tag.[TagCode] = inputTag.[TagText]
        INNER JOIN [ATAPUtilities].[TagState] AS state
            ON state.[TagId] = tag.[TagId]
           AND state.[TagStateKindCode] = ''Active''
           AND state.[ValidToUtc] IS NULL
        GROUP BY inputTag.[TagText]
        HAVING COUNT(DISTINCT tag.[TagId]) > 1
    )
        THROW 56013, ''A submitted TagCode resolves to multiple authoritative current Tags.'', 1;

    ;WITH DirectMatches AS
    (
        SELECT inputTag.[Ordinal],
               inputTag.[TagText] AS [MatchedTag],
               tag.[TagId],
               tag.[SourceReference],
               state.[Label],
               state.[Description],
               state.[ValidFromUtc],
               state.[RecordedAtUtc],
               state.[PrincipalId]
        FROM @Tags AS inputTag
        INNER JOIN [ATAPUtilities].[Tag] AS tag
            ON tag.[TagCode] = inputTag.[TagText]
        INNER JOIN [ATAPUtilities].[TagState] AS state
            ON state.[TagId] = tag.[TagId]
           AND state.[TagStateKindCode] = ''Active''
           AND state.[ValidToUtc] IS NULL
    ),
    RankedItems AS
    (
        SELECT match.[TagId],
               match.[SourceReference],
               match.[Label],
               match.[Description],
               match.[ValidFromUtc],
               match.[RecordedAtUtc],
               match.[PrincipalId],
               MIN(match.[Ordinal]) AS [FirstMatchOrdinal],
               ROW_NUMBER() OVER
               (
                   ORDER BY MIN(match.[Ordinal]), match.[TagId]
               ) - 1 AS [Rank]
        FROM DirectMatches AS match
        GROUP BY match.[TagId], match.[SourceReference], match.[Label],
                 match.[Description], match.[ValidFromUtc],
                 match.[RecordedAtUtc], match.[PrincipalId]
    )
    SELECT ranked.[TagId] AS [ItemId],
           N''ATAPUtilities.Tag'' AS [SourceKind],
           ranked.[SourceReference],
           COALESCE(ranked.[Description], ranked.[Label]) AS [Text],
           matched.[MatchedTagsJson],
           N''tag-code-v1'' AS [RankingContract],
           CONVERT(int, ranked.[Rank]) AS [Rank],
           ranked.[ValidFromUtc] AS [AssertedAtUtc],
           ranked.[RecordedAtUtc],
           ranked.[PrincipalId] AS [ProducerId],
           HASHBYTES
           (
               ''SHA2_256'',
               CONCAT
               (
                   N''gather-content-item-v1'', NCHAR(31),
                   LOWER(CONVERT(nvarchar(36), ranked.[TagId])), NCHAR(31),
                   ranked.[SourceReference], NCHAR(31),
                   COALESCE(ranked.[Description], ranked.[Label]), NCHAR(31),
                   matched.[MatchedTagsJson], NCHAR(31),
                   CONVERT(nvarchar(33), ranked.[ValidFromUtc], 126), NCHAR(31),
                   CONVERT(nvarchar(33), ranked.[RecordedAtUtc], 126), NCHAR(31),
                   LOWER(CONVERT(nvarchar(36), ranked.[PrincipalId]))
               )
           ) AS [ContentHash]
    FROM RankedItems AS ranked
    CROSS APPLY
    (
        SELECT N''['' +
               STRING_AGG(N''"'' + STRING_ESCAPE(distinctMatch.[MatchedTag], ''json'') + N''"'', N'','')
                   WITHIN GROUP (ORDER BY distinctMatch.[FirstOrdinal], distinctMatch.[MatchedTag]) +
               N'']'' AS [MatchedTagsJson]
        FROM
        (
            SELECT match.[MatchedTag] COLLATE Latin1_General_100_BIN2 AS [MatchedTag],
                   MIN(match.[Ordinal]) AS [FirstOrdinal]
            FROM DirectMatches AS match
            WHERE match.[TagId] = ranked.[TagId]
            GROUP BY match.[MatchedTag] COLLATE Latin1_General_100_BIN2
        ) AS distinctMatch
    ) AS matched
    ORDER BY ranked.[Rank], ranked.[TagId];
END;';

    EXEC sys.sp_executesql N'CREATE ROLE [AceGatherContentCaptureExecutor] AUTHORIZATION [dbo];';
    EXEC sys.sp_executesql N'CREATE ROLE [AceGatherContentQueryExecutor] AUTHORIZATION [dbo];';
    EXEC sys.sp_executesql N'CREATE ROLE [AceGatherContentSubmissionReader] AUTHORIZATION [dbo];';

    GRANT EXECUTE ON OBJECT::[Ace].[CaptureGatherContentSubmission]
        TO [AceGatherContentCaptureExecutor];
    GRANT EXECUTE ON TYPE::[Ace].[GatherContentTagInput]
        TO [AceGatherContentCaptureExecutor];
    GRANT EXECUTE ON OBJECT::[Ace].[QueryGatherContentV1]
        TO [AceGatherContentQueryExecutor];
    GRANT EXECUTE ON TYPE::[Ace].[GatherContentTagInput]
        TO [AceGatherContentQueryExecutor];

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

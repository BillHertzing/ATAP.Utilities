/*
  Association-ready ATAPUtilities Tag root (Task 15.140.c.T2).

  Authority: Task15.140c-T2-PhysicalContract.md PC-01 through PC-09.
  This forward-only migration creates no seeds, principals, grants, assignments,
  relations, localization, taxonomy, ordering, weighting, confidence, or tenancy.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'[ATAPUtilities].[Philote]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[PhiloteValidityPeriod]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[CloseCurrentPhiloteValidityPeriod]', N'P') IS NULL
        THROW 55001, N'The V00010 temporal baseline is required.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.key_constraints
        WHERE [parent_object_id] = OBJECT_ID(N'[ATAPUtilities].[PhiloteValidityPeriod]', N'U')
          AND [name] = N'UQ_PhiloteValidityPeriod_PhiloteId_PhiloteValidityPeriodId'
    )
        THROW 55002, N'The V00040 same-identity period key is required.', 1;

    IF OBJECT_ID(N'[ATAPUtilities].[TagNamespace]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[TagNamespaceSteward]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[Tag]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[TagState]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[TagAliasType]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[TagAlias]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[CreateTagNamespace]', N'P') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RetractTag]', N'P') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[ResolveTagAsOf]', N'IF') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[ResolveTagAsOf]', N'TF') IS NOT NULL
        THROW 55003, N'One or more V00050 target objects already exist.', 1;

    CREATE TABLE [ATAPUtilities].[TagNamespace]
    (
        [TagNamespaceId] uniqueidentifier NOT NULL,
        [NamespaceCode] nvarchar(128) COLLATE Latin1_General_100_CI_AS_SC NOT NULL,
        [PrincipalId] uniqueidentifier NOT NULL,
        [SourceReference] nvarchar(512) NOT NULL,
        [OccurredAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_TagNamespace] PRIMARY KEY ([TagNamespaceId]),
        CONSTRAINT [UQ_TagNamespace_NamespaceCode] UNIQUE ([NamespaceCode]),
        CONSTRAINT [CK_TagNamespace_NamespaceCode_NotEmpty]
            CHECK (DATALENGTH([NamespaceCode]) > 0),
        CONSTRAINT [CK_TagNamespace_SourceReference_NotEmpty]
            CHECK (DATALENGTH([SourceReference]) > 0)
    );

    CREATE TABLE [ATAPUtilities].[TagNamespaceSteward]
    (
        [TagNamespaceStewardId] uniqueidentifier NOT NULL,
        [TagNamespaceId] uniqueidentifier NOT NULL,
        [PrincipalId] uniqueidentifier NOT NULL,
        [ValidFromUtc] datetime2(7) NOT NULL,
        [ValidToUtc] datetime2(7) NULL,
        [SourceReference] nvarchar(512) NOT NULL,
        [OccurredAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_TagNamespaceSteward] PRIMARY KEY ([TagNamespaceStewardId]),
        CONSTRAINT [FK_TagNamespaceSteward_TagNamespace]
            FOREIGN KEY ([TagNamespaceId]) REFERENCES [ATAPUtilities].[TagNamespace] ([TagNamespaceId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [CK_TagNamespaceSteward_NonEmpty]
            CHECK ([ValidToUtc] IS NULL OR [ValidFromUtc] < [ValidToUtc]),
        CONSTRAINT [CK_TagNamespaceSteward_SourceReference_NotEmpty]
            CHECK (DATALENGTH([SourceReference]) > 0)
    );

    CREATE UNIQUE INDEX [UX_TagNamespaceSteward_Current]
        ON [ATAPUtilities].[TagNamespaceSteward] ([TagNamespaceId], [PrincipalId])
        WHERE [ValidToUtc] IS NULL;

    CREATE TABLE [ATAPUtilities].[Tag]
    (
        [TagId] uniqueidentifier NOT NULL,
        [TagNamespaceId] uniqueidentifier NOT NULL,
        [TagCode] nvarchar(128) COLLATE Latin1_General_100_CI_AS_SC NOT NULL,
        [PrincipalId] uniqueidentifier NOT NULL,
        [SourceReference] nvarchar(512) NOT NULL,
        [OccurredAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_Tag] PRIMARY KEY ([TagId]),
        CONSTRAINT [FK_Tag_Philote]
            FOREIGN KEY ([TagId]) REFERENCES [ATAPUtilities].[Philote] ([PhiloteId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_Tag_TagNamespace]
            FOREIGN KEY ([TagNamespaceId]) REFERENCES [ATAPUtilities].[TagNamespace] ([TagNamespaceId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_Tag_TagNamespaceId_TagCode] UNIQUE ([TagNamespaceId], [TagCode]),
        CONSTRAINT [CK_Tag_TagCode_NotEmpty] CHECK (DATALENGTH([TagCode]) > 0),
        CONSTRAINT [CK_Tag_SourceReference_NotEmpty] CHECK (DATALENGTH([SourceReference]) > 0)
    );

    CREATE TABLE [ATAPUtilities].[TagAliasType]
    (
        [TagAliasTypeId] uniqueidentifier NOT NULL,
        [AliasTypeCode] nvarchar(64) COLLATE Latin1_General_100_CI_AS_SC NOT NULL,
        [PrincipalId] uniqueidentifier NOT NULL,
        [SourceReference] nvarchar(512) NOT NULL,
        [OccurredAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_TagAliasType] PRIMARY KEY ([TagAliasTypeId]),
        CONSTRAINT [UQ_TagAliasType_AliasTypeCode] UNIQUE ([AliasTypeCode]),
        CONSTRAINT [CK_TagAliasType_AliasTypeCode_NotEmpty] CHECK (DATALENGTH([AliasTypeCode]) > 0),
        CONSTRAINT [CK_TagAliasType_SourceReference_NotEmpty] CHECK (DATALENGTH([SourceReference]) > 0)
    );

    CREATE TABLE [ATAPUtilities].[TagState]
    (
        [TagStateId] uniqueidentifier NOT NULL,
        [TagId] uniqueidentifier NOT NULL,
        [PhiloteValidityPeriodId] uniqueidentifier NOT NULL,
        [ValidFromUtc] datetime2(7) NOT NULL,
        [ValidToUtc] datetime2(7) NULL,
        [Label] nvarchar(256) NOT NULL,
        [Description] nvarchar(2048) NULL,
        [TagStateKindCode] varchar(32) NOT NULL,
        [SuccessorTagId] uniqueidentifier NULL,
        [WithdrawalReason] nvarchar(1024) NULL,
        [PrincipalId] uniqueidentifier NOT NULL,
        [SourceReference] nvarchar(512) NOT NULL,
        [OccurredAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_TagState] PRIMARY KEY ([TagStateId]),
        CONSTRAINT [FK_TagState_Tag]
            FOREIGN KEY ([TagId]) REFERENCES [ATAPUtilities].[Tag] ([TagId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_TagState_PhiloteValidityPeriod_SameIdentity]
            FOREIGN KEY ([TagId], [PhiloteValidityPeriodId])
            REFERENCES [ATAPUtilities].[PhiloteValidityPeriod] ([PhiloteId], [PhiloteValidityPeriodId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_TagState_SuccessorTag]
            FOREIGN KEY ([SuccessorTagId]) REFERENCES [ATAPUtilities].[Tag] ([TagId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [CK_TagState_Label_NotEmpty] CHECK (DATALENGTH([Label]) > 0),
        CONSTRAINT [CK_TagState_SourceReference_NotEmpty] CHECK (DATALENGTH([SourceReference]) > 0),
        CONSTRAINT [CK_TagState_KindAndTerminalPayload] CHECK
        (
            ([TagStateKindCode] = 'Active'
             AND [SuccessorTagId] IS NULL
             AND [WithdrawalReason] IS NULL
             AND ([ValidToUtc] IS NULL OR [ValidFromUtc] < [ValidToUtc]))
            OR
            ([TagStateKindCode] = 'RetractedSuccessor'
             AND [SuccessorTagId] IS NOT NULL
             AND [SuccessorTagId] <> [TagId]
             AND [WithdrawalReason] IS NULL
             AND [ValidFromUtc] = [ValidToUtc])
            OR
            ([TagStateKindCode] = 'RetractedErroneous'
             AND [SuccessorTagId] IS NULL
             AND DATALENGTH([WithdrawalReason]) > 0
             AND [ValidFromUtc] = [ValidToUtc])
        )
    );

    CREATE INDEX [IX_TagState_Tag_AsOf]
        ON [ATAPUtilities].[TagState] ([TagId], [ValidFromUtc], [ValidToUtc]);

    CREATE INDEX [IX_TagState_TerminalBoundary]
        ON [ATAPUtilities].[TagState]
            ([TagId], [PhiloteValidityPeriodId], [ValidFromUtc], [TagStateKindCode]);

    CREATE TABLE [ATAPUtilities].[TagAlias]
    (
        [TagAliasId] uniqueidentifier NOT NULL,
        [TagId] uniqueidentifier NOT NULL,
        [TagAliasTypeId] uniqueidentifier NOT NULL,
        [AliasCode] nvarchar(128) COLLATE Latin1_General_100_CI_AS_SC NOT NULL,
        [ValidFromUtc] datetime2(7) NOT NULL,
        [ValidToUtc] datetime2(7) NULL,
        [PrincipalId] uniqueidentifier NOT NULL,
        [SourceReference] nvarchar(512) NOT NULL,
        [OccurredAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_TagAlias] PRIMARY KEY ([TagAliasId]),
        CONSTRAINT [FK_TagAlias_Tag]
            FOREIGN KEY ([TagId]) REFERENCES [ATAPUtilities].[Tag] ([TagId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_TagAlias_TagAliasType]
            FOREIGN KEY ([TagAliasTypeId]) REFERENCES [ATAPUtilities].[TagAliasType] ([TagAliasTypeId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_TagAlias_TagId_AliasCode_ValidFromUtc]
            UNIQUE ([TagId], [AliasCode], [ValidFromUtc]),
        CONSTRAINT [CK_TagAlias_NonEmpty] CHECK ([ValidFromUtc] < [ValidToUtc] OR [ValidToUtc] IS NULL),
        CONSTRAINT [CK_TagAlias_AliasCode_NotEmpty] CHECK (DATALENGTH([AliasCode]) > 0),
        CONSTRAINT [CK_TagAlias_SourceReference_NotEmpty] CHECK (DATALENGTH([SourceReference]) > 0)
    );

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_TagNamespace_ImmutableNoDelete]
ON [ATAPUtilities].[TagNamespace]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 55010, ''TagNamespace rows are immutable and cannot be deleted.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_TagNamespaceSteward_History]
ON [ATAPUtilities].[TagNamespaceSteward]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
        THROW 55011, ''TagNamespaceSteward history cannot be deleted.'', 1;

    IF EXISTS (SELECT 1 FROM deleted) AND EXISTS (SELECT 1 FROM inserted)
       AND UPDATE([TagNamespaceStewardId])
        THROW 55060, ''TagNamespaceStewardId is immutable.'', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.TagNamespaceStewardId = i.TagNamespaceStewardId
        WHERE i.TagNamespaceId <> d.TagNamespaceId
           OR i.PrincipalId <> d.PrincipalId
           OR i.ValidFromUtc <> d.ValidFromUtc
           OR i.SourceReference <> d.SourceReference
           OR i.OccurredAtUtc <> d.OccurredAtUtc
           OR i.RecordedAtUtc <> d.RecordedAtUtc
           OR d.ValidToUtc IS NOT NULL
           OR i.ValidToUtc IS NULL
    )
        THROW 55012, ''Steward history is append-only; only an open interval may be closed.'', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN [ATAPUtilities].[TagNamespaceSteward] AS s WITH (UPDLOCK, HOLDLOCK)
            ON s.TagNamespaceId = i.TagNamespaceId
           AND s.PrincipalId = i.PrincipalId
           AND s.TagNamespaceStewardId <> i.TagNamespaceStewardId
           AND i.ValidFromUtc < COALESCE(s.ValidToUtc, CONVERT(datetime2(7), ''9999-12-31T23:59:59.9999999''))
           AND s.ValidFromUtc < COALESCE(i.ValidToUtc, CONVERT(datetime2(7), ''9999-12-31T23:59:59.9999999''))
    )
        THROW 55013, ''Stewardship intervals for one namespace and principal cannot overlap.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_Tag_AuthoringAndClaims]
ON [ATAPUtilities].[Tag]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 55014, ''Tag roots are immutable and cannot be deleted.'', 1;

    DECLARE @LockCount int;
    SELECT @LockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[TagNamespace] AS n WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN inserted AS i ON i.TagNamespaceId = n.TagNamespaceId;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [ATAPUtilities].[TagNamespaceSteward] AS s WITH (HOLDLOCK)
            WHERE s.TagNamespaceId = i.TagNamespaceId
              AND s.PrincipalId = i.PrincipalId
              AND s.ValidFromUtc <= i.OccurredAtUtc
              AND (s.ValidToUtc IS NULL OR i.OccurredAtUtc < s.ValidToUtc)
        )
    )
        THROW 55015, ''Tag author is not an active namespace steward at OccurredAtUtc.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN [ATAPUtilities].[TagAlias] AS a WITH (HOLDLOCK) ON a.AliasCode = i.TagCode
        INNER JOIN [ATAPUtilities].[Tag] AS ownerTag ON ownerTag.TagId = a.TagId
        WHERE ownerTag.TagNamespaceId = i.TagNamespaceId
    )
        THROW 55016, ''Canonical TagCode collides with a permanently claimed alias.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_TagAliasType_ImmutableNoDelete]
ON [ATAPUtilities].[TagAliasType]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 55017, ''TagAliasType rows are immutable and cannot be deleted.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_TagState_TemporalAndSuccessor]
ON [ATAPUtilities].[TagState]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
        THROW 55018, ''TagState history cannot be deleted.'', 1;

    IF EXISTS (SELECT 1 FROM deleted) AND EXISTS (SELECT 1 FROM inserted)
       AND UPDATE([TagStateId])
        THROW 55061, ''TagStateId is immutable.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN deleted AS d ON d.TagStateId = i.TagStateId
        WHERE i.TagId <> d.TagId
           OR i.PhiloteValidityPeriodId <> d.PhiloteValidityPeriodId
           OR i.ValidFromUtc <> d.ValidFromUtc
           OR i.Label <> d.Label
           OR i.Description <> d.Description
           OR (i.Description IS NULL AND d.Description IS NOT NULL)
           OR (i.Description IS NOT NULL AND d.Description IS NULL)
           OR i.TagStateKindCode <> d.TagStateKindCode
           OR i.SuccessorTagId <> d.SuccessorTagId
           OR (i.SuccessorTagId IS NULL AND d.SuccessorTagId IS NOT NULL)
           OR (i.SuccessorTagId IS NOT NULL AND d.SuccessorTagId IS NULL)
           OR i.WithdrawalReason <> d.WithdrawalReason
           OR (i.WithdrawalReason IS NULL AND d.WithdrawalReason IS NOT NULL)
           OR (i.WithdrawalReason IS NOT NULL AND d.WithdrawalReason IS NULL)
           OR i.PrincipalId <> d.PrincipalId
           OR i.SourceReference <> d.SourceReference
           OR i.OccurredAtUtc <> d.OccurredAtUtc
           OR i.RecordedAtUtc <> d.RecordedAtUtc
           OR d.TagStateKindCode <> ''Active''
           OR d.ValidToUtc IS NOT NULL
           OR i.ValidToUtc IS NULL
    )
        THROW 55019, ''TagState is append/close-only.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN [ATAPUtilities].[Tag] AS t ON t.TagId = i.TagId
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [ATAPUtilities].[TagNamespaceSteward] AS s WITH (HOLDLOCK)
            WHERE s.TagNamespaceId = t.TagNamespaceId
              AND s.PrincipalId = i.PrincipalId
              AND s.ValidFromUtc <= i.OccurredAtUtc
              AND (s.ValidToUtc IS NULL OR i.OccurredAtUtc < s.ValidToUtc)
        )
    )
        THROW 55020, ''TagState author is not an active namespace steward at OccurredAtUtc.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN [ATAPUtilities].[PhiloteValidityPeriod] AS p WITH (HOLDLOCK)
            ON p.PhiloteId = i.TagId AND p.PhiloteValidityPeriodId = i.PhiloteValidityPeriodId
        WHERE (i.TagStateKindCode = ''Active'' AND
               (i.ValidFromUtc < p.ValidFromUtc
                OR (p.ValidToUtc IS NOT NULL AND (i.ValidToUtc IS NULL OR i.ValidToUtc > p.ValidToUtc))))
           OR (i.TagStateKindCode <> ''Active'' AND
               (p.ValidToUtc IS NULL OR i.ValidFromUtc <> p.ValidToUtc OR i.ValidToUtc <> p.ValidToUtc))
    )
        THROW 55021, ''TagState is not contained by its same-identity validity period or terminal boundary.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN [ATAPUtilities].[TagState] AS s WITH (UPDLOCK, HOLDLOCK)
            ON s.TagId = i.TagId
           AND s.TagStateKindCode = ''Active''
           AND s.TagStateId <> i.TagStateId
           AND i.TagStateKindCode = ''Active''
           AND i.ValidFromUtc < COALESCE(s.ValidToUtc, CONVERT(datetime2(7), ''9999-12-31T23:59:59.9999999''))
           AND s.ValidFromUtc < COALESCE(i.ValidToUtc, CONVERT(datetime2(7), ''9999-12-31T23:59:59.9999999''))
    )
        THROW 55022, ''Active TagState intervals cannot overlap.'', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN [ATAPUtilities].[TagState] AS s WITH (UPDLOCK, HOLDLOCK)
            ON s.TagId = i.TagId
           AND s.PhiloteValidityPeriodId = i.PhiloteValidityPeriodId
           AND s.ValidFromUtc = i.ValidFromUtc
           AND s.TagStateId <> i.TagStateId
        WHERE i.TagStateKindCode IN (''RetractedSuccessor'', ''RetractedErroneous'')
          AND s.TagStateKindCode IN (''RetractedSuccessor'', ''RetractedErroneous'')
    )
        THROW 55032, ''Only one terminal event is permitted for a Tag validity-period boundary.'', 1;

    IF EXISTS (SELECT 1 FROM inserted WHERE TagStateKindCode = ''RetractedSuccessor'')
    BEGIN
        DECLARE @GraphLockResult int;
        EXEC @GraphLockResult = sys.sp_getapplock
            @Resource = ''ATAPUtilities.TagSuccessorGraph'',
            @LockMode = ''Exclusive'',
            @LockOwner = ''Transaction'',
            @LockTimeout = 15000,
            @DbPrincipal = ''public'';
        IF @GraphLockResult < 0
            THROW 55033, ''Unable to acquire the Tag successor-graph writer lock.'', 1;

        DECLARE @SourceTagStateId uniqueidentifier;
        DECLARE @SourceTagId uniqueidentifier;
        DECLARE @InitialSuccessorTagId uniqueidentifier;
        DECLARE @FrontierTagId uniqueidentifier;
        DECLARE @Visited TABLE (TagId uniqueidentifier NOT NULL PRIMARY KEY);
        DECLARE @Frontier TABLE (TagId uniqueidentifier NOT NULL PRIMARY KEY);

        DECLARE successor_event_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT TagStateId, TagId, SuccessorTagId
            FROM inserted
            WHERE TagStateKindCode = ''RetractedSuccessor''
            ORDER BY TagStateId;
        OPEN successor_event_cursor;
        FETCH NEXT FROM successor_event_cursor
            INTO @SourceTagStateId, @SourceTagId, @InitialSuccessorTagId;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            DELETE FROM @Visited;
            DELETE FROM @Frontier;
            INSERT INTO @Frontier (TagId) VALUES (@InitialSuccessorTagId);

            WHILE EXISTS (SELECT 1 FROM @Frontier)
            BEGIN
                SELECT TOP (1) @FrontierTagId = TagId
                FROM @Frontier
                ORDER BY TagId;
                DELETE FROM @Frontier WHERE TagId = @FrontierTagId;

                IF @FrontierTagId = @SourceTagId
                    THROW 55023, ''Tag successor cycles are prohibited.'', 1;

                IF NOT EXISTS (SELECT 1 FROM @Visited WHERE TagId = @FrontierTagId)
                BEGIN
                    INSERT INTO @Visited (TagId) VALUES (@FrontierTagId);
                    INSERT INTO @Frontier (TagId)
                    SELECT DISTINCT edge.SuccessorTagId
                    FROM [ATAPUtilities].[TagState] AS edge WITH (UPDLOCK, HOLDLOCK)
                    WHERE edge.TagId = @FrontierTagId
                      AND edge.TagStateKindCode = ''RetractedSuccessor''
                      AND edge.SuccessorTagId IS NOT NULL
                      AND NOT EXISTS
                      (
                          SELECT 1 FROM @Visited AS visited
                          WHERE visited.TagId = edge.SuccessorTagId
                      )
                      AND NOT EXISTS
                      (
                          SELECT 1 FROM @Frontier AS pending
                          WHERE pending.TagId = edge.SuccessorTagId
                      );
                END;
            END;

            FETCH NEXT FROM successor_event_cursor
                INTO @SourceTagStateId, @SourceTagId, @InitialSuccessorTagId;
        END;
        CLOSE successor_event_cursor;
        DEALLOCATE successor_event_cursor;
    END;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_TagAlias_TemporalAndClaims]
ON [ATAPUtilities].[TagAlias]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
        THROW 55025, ''TagAlias history cannot be deleted.'', 1;

    IF EXISTS (SELECT 1 FROM deleted) AND EXISTS (SELECT 1 FROM inserted)
       AND UPDATE([TagAliasId])
        THROW 55062, ''TagAliasId is immutable.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN deleted AS d ON d.TagAliasId = i.TagAliasId
        WHERE i.TagId <> d.TagId
           OR i.TagAliasTypeId <> d.TagAliasTypeId
           OR i.AliasCode <> d.AliasCode
           OR i.ValidFromUtc <> d.ValidFromUtc
           OR i.PrincipalId <> d.PrincipalId
           OR i.SourceReference <> d.SourceReference
           OR i.OccurredAtUtc <> d.OccurredAtUtc
           OR i.RecordedAtUtc <> d.RecordedAtUtc
           OR d.ValidToUtc IS NOT NULL
           OR i.ValidToUtc IS NULL
    )
        THROW 55026, ''TagAlias is append/close-only.'', 1;

    DECLARE @LockCount int;
    SELECT @LockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[TagNamespace] AS n WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN [ATAPUtilities].[Tag] AS t ON t.TagNamespaceId = n.TagNamespaceId
    INNER JOIN inserted AS i ON i.TagId = t.TagId;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN [ATAPUtilities].[Tag] AS t ON t.TagId = i.TagId
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [ATAPUtilities].[TagNamespaceSteward] AS s WITH (HOLDLOCK)
            WHERE s.TagNamespaceId = t.TagNamespaceId
              AND s.PrincipalId = i.PrincipalId
              AND s.ValidFromUtc <= i.OccurredAtUtc
              AND (s.ValidToUtc IS NULL OR i.OccurredAtUtc < s.ValidToUtc)
        )
    )
        THROW 55027, ''TagAlias author is not an active namespace steward at OccurredAtUtc.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN [ATAPUtilities].[Tag] AS ownerTag ON ownerTag.TagId = i.TagId
        INNER JOIN [ATAPUtilities].[Tag] AS canonical WITH (HOLDLOCK)
            ON canonical.TagNamespaceId = ownerTag.TagNamespaceId
           AND canonical.TagCode = i.AliasCode
    )
        THROW 55028, ''AliasCode cannot equal any canonical TagCode in its namespace.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN [ATAPUtilities].[Tag] AS ownerTag ON ownerTag.TagId = i.TagId
        INNER JOIN [ATAPUtilities].[TagAlias] AS a WITH (UPDLOCK, HOLDLOCK)
            ON a.AliasCode = i.AliasCode AND a.TagAliasId <> i.TagAliasId
        INNER JOIN [ATAPUtilities].[Tag] AS otherTag ON otherTag.TagId = a.TagId
        WHERE otherTag.TagNamespaceId = ownerTag.TagNamespaceId
          AND a.TagId <> i.TagId
    )
        THROW 55029, ''An alias spelling is permanently claimed by another Tag in the namespace.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN [ATAPUtilities].[TagAlias] AS a WITH (UPDLOCK, HOLDLOCK)
            ON a.TagId = i.TagId AND a.AliasCode = i.AliasCode AND a.TagAliasId <> i.TagAliasId
           AND i.ValidFromUtc < COALESCE(a.ValidToUtc, CONVERT(datetime2(7), ''9999-12-31T23:59:59.9999999''))
           AND a.ValidFromUtc < COALESCE(i.ValidToUtc, CONVERT(datetime2(7), ''9999-12-31T23:59:59.9999999''))
    )
        THROW 55030, ''Alias intervals for the same Tag and spelling cannot overlap.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_PhiloteValidityPeriod_TagStateContainment]
ON [ATAPUtilities].[PhiloteValidityPeriod]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS p
        INNER JOIN [ATAPUtilities].[TagState] AS s WITH (UPDLOCK, HOLDLOCK)
            ON s.TagId = p.PhiloteId AND s.PhiloteValidityPeriodId = p.PhiloteValidityPeriodId
        WHERE (s.TagStateKindCode = ''Active'' AND
               (s.ValidFromUtc < p.ValidFromUtc
                OR (p.ValidToUtc IS NOT NULL AND (s.ValidToUtc IS NULL OR s.ValidToUtc > p.ValidToUtc))))
           OR (s.TagStateKindCode <> ''Active'' AND
               (p.ValidToUtc IS NULL OR s.ValidFromUtc <> p.ValidToUtc OR s.ValidToUtc <> p.ValidToUtc))
    )
        THROW 55031, ''Validity-period change would violate TagState containment.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[CreateTagNamespace]
    @TagNamespaceId uniqueidentifier,
    @TagNamespaceStewardId uniqueidentifier,
    @NamespaceCode nvarchar(128),
    @ActorPrincipalId uniqueidentifier,
    @SourceReference nvarchar(512),
    @OccurredAtUtc datetime2(7),
    @RecordedAtUtc datetime2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @TagNamespaceId IS NULL OR @TagNamespaceStewardId IS NULL OR @ActorPrincipalId IS NULL
        THROW 55040, ''Namespace, steward, and actor identities are required.'', 1;
    IF NULLIF(@NamespaceCode, N'''') IS NULL OR NULLIF(@SourceReference, N'''') IS NULL
        THROW 55041, ''NamespaceCode and SourceReference are required.'', 1;
    IF @OccurredAtUtc IS NULL OR @RecordedAtUtc IS NULL
        THROW 55042, ''OccurredAtUtc and RecordedAtUtc are required.'', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO [ATAPUtilities].[TagNamespace]
            (TagNamespaceId, NamespaceCode, PrincipalId, SourceReference, OccurredAtUtc, RecordedAtUtc)
        VALUES
            (@TagNamespaceId, @NamespaceCode, @ActorPrincipalId, @SourceReference, @OccurredAtUtc, @RecordedAtUtc);
        INSERT INTO [ATAPUtilities].[TagNamespaceSteward]
            (TagNamespaceStewardId, TagNamespaceId, PrincipalId, ValidFromUtc, ValidToUtc,
             SourceReference, OccurredAtUtc, RecordedAtUtc)
        VALUES
            (@TagNamespaceStewardId, @TagNamespaceId, @ActorPrincipalId, @OccurredAtUtc, NULL,
             @SourceReference, @OccurredAtUtc, @RecordedAtUtc);
        COMMIT TRANSACTION;
        SELECT * FROM [ATAPUtilities].[TagNamespace] WHERE TagNamespaceId = @TagNamespaceId;
        SELECT * FROM [ATAPUtilities].[TagNamespaceSteward]
        WHERE TagNamespaceStewardId = @TagNamespaceStewardId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[RetractTag]
    @TagId uniqueidentifier,
    @ExpectedTagStateId uniqueidentifier,
    @ExpectedPhiloteValidityPeriodId uniqueidentifier,
    @TerminalTagStateId uniqueidentifier,
    @EffectiveAtUtc datetime2(7),
    @ActorPrincipalId uniqueidentifier,
    @SourceReference nvarchar(512),
    @OccurredAtUtc datetime2(7),
    @RecordedAtUtc datetime2(7),
    @RetractionKindCode varchar(32),
    @SuccessorTagId uniqueidentifier = NULL,
    @WithdrawalReason nvarchar(1024) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @TagId IS NULL OR @ExpectedTagStateId IS NULL
       OR @ExpectedPhiloteValidityPeriodId IS NULL OR @TerminalTagStateId IS NULL
       OR @EffectiveAtUtc IS NULL OR @ActorPrincipalId IS NULL
       OR @OccurredAtUtc IS NULL OR @RecordedAtUtc IS NULL
        THROW 55048, ''Required retraction identity, actor, and temporal parameters cannot be null.'', 1;
    IF NULLIF(@SourceReference, N'''') IS NULL OR NULLIF(@RetractionKindCode, '''') IS NULL
        THROW 55049, ''SourceReference and RetractionKindCode are required.'', 1;
    IF @RetractionKindCode NOT IN (''RetractedSuccessor'', ''RetractedErroneous'')
        THROW 55050, ''Unsupported retraction kind.'', 1;
    IF (@RetractionKindCode = ''RetractedSuccessor'' AND (@SuccessorTagId IS NULL OR @WithdrawalReason IS NOT NULL))
       OR (@RetractionKindCode = ''RetractedErroneous'' AND (@SuccessorTagId IS NOT NULL OR NULLIF(@WithdrawalReason, N'''') IS NULL))
        THROW 55051, ''Retraction payload does not match the requested kind.'', 1;
    IF @RetractionKindCode = ''RetractedSuccessor'' AND @SuccessorTagId = @TagId
        THROW 55047, ''A Tag cannot retract to itself.'', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @SuccessorGraphLockResult int;
        IF @RetractionKindCode = ''RetractedSuccessor''
        BEGIN
            EXEC @SuccessorGraphLockResult = sys.sp_getapplock
                @Resource = ''ATAPUtilities.TagSuccessorGraph'',
                @LockMode = ''Exclusive'',
                @LockOwner = ''Transaction'',
                @LockTimeout = 15000,
                @DbPrincipal = ''public'';
            IF @SuccessorGraphLockResult < 0
                THROW 55033, ''Unable to acquire the Tag successor-graph writer lock.'', 1;
        END;

        DECLARE @LockResult int;
        DECLARE @LockResource nvarchar(255) =
            N''ATAPUtilities.PhiloteValidityPeriod:'' + LOWER(CONVERT(nvarchar(36), @TagId));
        EXEC @LockResult = sys.sp_getapplock @Resource=@LockResource, @LockMode=''Exclusive'',
            @LockOwner=''Transaction'', @LockTimeout=15000, @DbPrincipal=''public'';
        IF @LockResult < 0 THROW 55052, ''Unable to acquire Tag retraction lock.'', 1;

        DECLARE @TagNamespaceId uniqueidentifier;
        SELECT @TagNamespaceId = TagNamespaceId FROM [ATAPUtilities].[Tag] WITH (UPDLOCK, HOLDLOCK)
        WHERE TagId = @TagId;
        IF @TagNamespaceId IS NULL THROW 55053, ''Tag does not exist.'', 1;
        IF EXISTS (SELECT 1 FROM [ATAPUtilities].[TagState] WITH (UPDLOCK, HOLDLOCK)
                   WHERE TagStateId=@TerminalTagStateId)
            THROW 55058, ''TerminalTagStateId already exists.'', 1;
        IF @RetractionKindCode = ''RetractedSuccessor''
           AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Tag] WITH (UPDLOCK, HOLDLOCK)
                           WHERE TagId=@SuccessorTagId)
            THROW 55059, ''Successor Tag does not exist.'', 1;
        IF NOT EXISTS
        (
            SELECT 1 FROM [ATAPUtilities].[TagNamespaceSteward] WITH (UPDLOCK, HOLDLOCK)
            WHERE TagNamespaceId = @TagNamespaceId AND PrincipalId = @ActorPrincipalId
              AND ValidFromUtc <= @OccurredAtUtc AND (ValidToUtc IS NULL OR @OccurredAtUtc < ValidToUtc)
        ) THROW 55054, ''Actor is not an active namespace steward.'', 1;

        DECLARE @Label nvarchar(256);
        DECLARE @Description nvarchar(2048);
        SELECT @Label=Label, @Description=Description
        FROM [ATAPUtilities].[TagState] WITH (UPDLOCK, HOLDLOCK)
        WHERE TagStateId=@ExpectedTagStateId AND TagId=@TagId
          AND PhiloteValidityPeriodId=@ExpectedPhiloteValidityPeriodId
          AND TagStateKindCode=''Active'' AND ValidToUtc IS NULL AND ValidFromUtc < @EffectiveAtUtc;
        IF @Label IS NULL THROW 55055, ''Expected active TagState is stale or absent.'', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM [ATAPUtilities].[PhiloteValidityPeriod] WITH (UPDLOCK, HOLDLOCK)
            WHERE PhiloteId=@TagId
              AND PhiloteValidityPeriodId=@ExpectedPhiloteValidityPeriodId
              AND ValidToUtc IS NULL
              AND ValidFromUtc < @EffectiveAtUtc
        ) THROW 55056, ''Expected open Philote validity period is stale or absent.'', 1;

        UPDATE [ATAPUtilities].[TagState]
        SET ValidToUtc=@EffectiveAtUtc
        WHERE TagStateId=@ExpectedTagStateId;

        UPDATE [ATAPUtilities].[PhiloteValidityPeriod]
        SET ValidToUtc=@EffectiveAtUtc
        WHERE PhiloteId=@TagId
          AND PhiloteValidityPeriodId=@ExpectedPhiloteValidityPeriodId
          AND ValidToUtc IS NULL;

        IF @@ROWCOUNT <> 1
            THROW 55057, ''Open Philote validity period changed during retraction.'', 1;

        INSERT INTO [ATAPUtilities].[TagState]
            (TagStateId, TagId, PhiloteValidityPeriodId, ValidFromUtc, ValidToUtc,
             Label, Description, TagStateKindCode, SuccessorTagId, WithdrawalReason,
             PrincipalId, SourceReference, OccurredAtUtc, RecordedAtUtc)
        VALUES
            (@TerminalTagStateId, @TagId, @ExpectedPhiloteValidityPeriodId, @EffectiveAtUtc, @EffectiveAtUtc,
             @Label, @Description, @RetractionKindCode, @SuccessorTagId, @WithdrawalReason,
             @ActorPrincipalId, @SourceReference, @OccurredAtUtc, @RecordedAtUtc);
        COMMIT TRANSACTION;
        SELECT * FROM [ATAPUtilities].[TagState] WHERE TagStateId=@TerminalTagStateId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE FUNCTION [ATAPUtilities].[ResolveTagAsOf]
(
    @TagId uniqueidentifier,
    @AsOfUtc datetime2(7)
)
RETURNS @Resolved TABLE
(
    RequestedTagId uniqueidentifier NULL,
    ResolvedTagId uniqueidentifier NULL,
    TagNamespaceId uniqueidentifier NULL,
    NamespaceCode nvarchar(128) NULL,
    TagCode nvarchar(128) NULL,
    TagStateId uniqueidentifier NULL,
    Label nvarchar(256) NULL,
    Description nvarchar(2048) NULL,
    ResolutionStatusCode varchar(32) NOT NULL,
    HopCount int NOT NULL
)
AS
BEGIN
    DECLARE @CurrentTagId uniqueidentifier = @TagId;
    DECLARE @CurrentStateId uniqueidentifier;
    DECLARE @CurrentKind varchar(32);
    DECLARE @SuccessorTagId uniqueidentifier;
    DECLARE @HopCount int = 0;
    DECLARE @Visited TABLE (TagId uniqueidentifier PRIMARY KEY);

    IF @TagId IS NULL OR NOT EXISTS
    (
        SELECT 1 FROM [ATAPUtilities].[Tag] WHERE TagId=@TagId
    )
    BEGIN
        INSERT INTO @Resolved
        (
            RequestedTagId, ResolvedTagId, TagNamespaceId, NamespaceCode, TagCode,
            TagStateId, Label, Description, ResolutionStatusCode, HopCount
        )
        VALUES (@TagId, NULL, NULL, NULL, NULL, NULL, NULL, NULL, ''Inactive'', 0);
        RETURN;
    END;

    WHILE @CurrentTagId IS NOT NULL AND @HopCount < 64
    BEGIN
        IF EXISTS (SELECT 1 FROM @Visited WHERE TagId=@CurrentTagId)
        BEGIN
            INSERT INTO @Resolved
            SELECT @TagId, @CurrentTagId, t.TagNamespaceId, n.NamespaceCode, t.TagCode,
                   NULL, NULL, NULL, ''Cycle'', @HopCount
            FROM [ATAPUtilities].[Tag] AS t
            INNER JOIN [ATAPUtilities].[TagNamespace] AS n ON n.TagNamespaceId=t.TagNamespaceId
            WHERE t.TagId=@CurrentTagId;
            RETURN;
        END;
        INSERT INTO @Visited VALUES (@CurrentTagId);

        SET @CurrentStateId=NULL;
        SELECT TOP (1) @CurrentStateId=s.TagStateId
        FROM [ATAPUtilities].[TagState] AS s
        INNER JOIN [ATAPUtilities].[PhiloteValidityPeriod] AS p
            ON p.PhiloteId=s.TagId AND p.PhiloteValidityPeriodId=s.PhiloteValidityPeriodId
        WHERE s.TagId=@CurrentTagId AND s.TagStateKindCode=''Active''
          AND p.ValidFromUtc <= @AsOfUtc AND (p.ValidToUtc IS NULL OR @AsOfUtc < p.ValidToUtc)
          AND s.ValidFromUtc <= @AsOfUtc AND (s.ValidToUtc IS NULL OR @AsOfUtc < s.ValidToUtc)
        ORDER BY s.ValidFromUtc DESC, s.TagStateId;

        IF @CurrentStateId IS NOT NULL
        BEGIN
            INSERT INTO @Resolved
            SELECT @TagId, t.TagId, t.TagNamespaceId, n.NamespaceCode, t.TagCode,
                   s.TagStateId, s.Label, s.Description, ''Resolved'', @HopCount
            FROM [ATAPUtilities].[Tag] AS t
            INNER JOIN [ATAPUtilities].[TagNamespace] AS n ON n.TagNamespaceId=t.TagNamespaceId
            INNER JOIN [ATAPUtilities].[TagState] AS s ON s.TagStateId=@CurrentStateId
            WHERE t.TagId=@CurrentTagId;
            RETURN;
        END;

        SET @CurrentStateId=NULL;
        SET @CurrentKind=NULL;
        SET @SuccessorTagId=NULL;
        SELECT TOP (1)
            @CurrentStateId=s.TagStateId,
            @CurrentKind=s.TagStateKindCode,
            @SuccessorTagId=s.SuccessorTagId
        FROM [ATAPUtilities].[TagState] AS s
        WHERE s.TagId=@CurrentTagId
          AND s.TagStateKindCode IN (''RetractedSuccessor'',''RetractedErroneous'')
          AND s.ValidFromUtc <= @AsOfUtc
        ORDER BY s.ValidFromUtc DESC, s.TagStateId DESC;

        IF @CurrentKind = ''RetractedErroneous''
        BEGIN
            INSERT INTO @Resolved
            SELECT @TagId, t.TagId, t.TagNamespaceId, n.NamespaceCode, t.TagCode,
                   s.TagStateId, s.Label, s.Description, ''RetractedErroneous'', @HopCount
            FROM [ATAPUtilities].[Tag] AS t
            INNER JOIN [ATAPUtilities].[TagNamespace] AS n ON n.TagNamespaceId=t.TagNamespaceId
            INNER JOIN [ATAPUtilities].[TagState] AS s ON s.TagStateId=@CurrentStateId
            WHERE t.TagId=@CurrentTagId;
            RETURN;
        END;
        IF @CurrentKind <> ''RetractedSuccessor'' OR @SuccessorTagId IS NULL
        BEGIN
            INSERT INTO @Resolved
            SELECT @TagId, t.TagId, t.TagNamespaceId, n.NamespaceCode, t.TagCode,
                   NULL, NULL, NULL, ''Inactive'', @HopCount
            FROM [ATAPUtilities].[Tag] AS t
            INNER JOIN [ATAPUtilities].[TagNamespace] AS n ON n.TagNamespaceId=t.TagNamespaceId
            WHERE t.TagId=@CurrentTagId;
            RETURN;
        END;
        SET @CurrentTagId=@SuccessorTagId;
        SET @HopCount += 1;
    END;

    INSERT INTO @Resolved
    SELECT @TagId, @CurrentTagId, t.TagNamespaceId, n.NamespaceCode, t.TagCode,
           NULL, NULL, NULL, ''DepthExceeded'', @HopCount
    FROM [ATAPUtilities].[Tag] AS t
    INNER JOIN [ATAPUtilities].[TagNamespace] AS n ON n.TagNamespaceId=t.TagNamespaceId
    WHERE t.TagId=@CurrentTagId;
    RETURN;
END;';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

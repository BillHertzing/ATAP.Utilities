/*
  Typed Tag relations and generic classification-only assignments (Tasks 15.50.c/.d).

  Authority: RPRRSBSI-V4-2 Tags, C-17 through C-27, and the frozen Task 15.50.b
  traversal contract at commit 142c1a76. This forward-only migration creates no
  principals, users, roles, grants, tenant boundary, authorization semantics, legacy
  taxonomy import, confidence score, or localization surface.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'[ATAPUtilities].[Tag]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[TagState]', N'U') IS NULL
       OR (OBJECT_ID(N'[ATAPUtilities].[ResolveTagAsOf]', N'IF') IS NULL
           AND OBJECT_ID(N'[ATAPUtilities].[ResolveTagAsOf]', N'TF') IS NULL)
       OR OBJECT_ID(N'[ATAPUtilities].[Rule]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[Instantiation]', N'U') IS NULL
        THROW 59001, N'The V00050 Tag root and V00010 Rule/Instantiation baseline are required.', 1;

    IF OBJECT_ID(N'[ATAPUtilities].[TagRelationType]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[TagRelation]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[TagAssignmentEntityType]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[TagAssignment]', N'U') IS NOT NULL
       OR TYPE_ID(N'[ATAPUtilities].[TagRelationRoleCodeInput]') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[CreateTagRelation]', N'P') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[CreateTagAssignment]', N'P') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[QueryTagLogicalEdgesAsOf]', N'P') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[QueryTagAssignmentsAsOf]', N'P') IS NOT NULL
       OR COL_LENGTH(N'ATAPUtilities.TagState', N'IsDeprecated') IS NOT NULL
        THROW 59002, N'One or more V00090 target objects already exist.', 1;

    ALTER TABLE [ATAPUtilities].[TagState]
        ADD [IsDeprecated] bit NOT NULL
            CONSTRAINT [DF_TagState_IsDeprecated] DEFAULT (0) WITH VALUES;

    CREATE TABLE [ATAPUtilities].[TagRelationType]
    (
        [TagRelationTypeId] uniqueidentifier NOT NULL,
        [RoleCode] nvarchar(64) COLLATE Latin1_General_100_CI_AS_SC NOT NULL,
        [InverseTagRelationTypeId] uniqueidentifier NOT NULL,
        [DirectionCode] varchar(16) NOT NULL,
        [RelationFamilyCode] nvarchar(64) COLLATE Latin1_General_100_CI_AS_SC NOT NULL,
        [CyclePolicyCode] varchar(16) NOT NULL,
        [IsTraversable] bit NOT NULL,
        [PrincipalId] uniqueidentifier NOT NULL,
        [SourceReference] nvarchar(512) NOT NULL,
        [OccurredAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_TagRelationType] PRIMARY KEY ([TagRelationTypeId]),
        CONSTRAINT [UQ_TagRelationType_RoleCode] UNIQUE ([RoleCode]),
        CONSTRAINT [FK_TagRelationType_Inverse]
            FOREIGN KEY ([InverseTagRelationTypeId])
            REFERENCES [ATAPUtilities].[TagRelationType] ([TagRelationTypeId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [CK_TagRelationType_Direction]
            CHECK ([DirectionCode] IN ('Symmetric', 'Canonical', 'Inverse')),
        CONSTRAINT [CK_TagRelationType_CyclePolicy]
            CHECK ([CyclePolicyCode] IN ('Allowed', 'Prohibited')),
        CONSTRAINT [CK_TagRelationType_Text]
            CHECK (DATALENGTH([RoleCode]) > 0 AND DATALENGTH([RelationFamilyCode]) > 0
                   AND DATALENGTH([SourceReference]) > 0)
    );

    CREATE TABLE [ATAPUtilities].[TagAssignmentEntityType]
    (
        [EntityTypeCode] nvarchar(64) COLLATE Latin1_General_100_CI_AS_SC NOT NULL,
        [TargetSchemaName] sysname NOT NULL,
        [TargetTableName] sysname NOT NULL,
        [TargetIdColumnName] sysname NOT NULL,
        [IsClassificationOnly] bit NOT NULL,
        [PrincipalId] uniqueidentifier NOT NULL,
        [SourceReference] nvarchar(512) NOT NULL,
        [OccurredAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_TagAssignmentEntityType] PRIMARY KEY ([EntityTypeCode]),
        CONSTRAINT [CK_TagAssignmentEntityType_ClassificationOnly]
            CHECK ([IsClassificationOnly] = 1),
        CONSTRAINT [CK_TagAssignmentEntityType_Text]
            CHECK (DATALENGTH([EntityTypeCode]) > 0 AND DATALENGTH([TargetSchemaName]) > 0
                   AND DATALENGTH([TargetTableName]) > 0 AND DATALENGTH([TargetIdColumnName]) > 0
                   AND DATALENGTH([SourceReference]) > 0)
    );

    CREATE TABLE [ATAPUtilities].[TagRelation]
    (
        [TagRelationId] uniqueidentifier NOT NULL,
        [SourceTagId] uniqueidentifier NOT NULL,
        [TargetTagId] uniqueidentifier NOT NULL,
        [TagRelationTypeId] uniqueidentifier NOT NULL,
        [Weight] decimal(5,4) NOT NULL CONSTRAINT [DF_TagRelation_Weight] DEFAULT (1.0000),
        [PrincipalId] uniqueidentifier NOT NULL,
        [SourceReference] nvarchar(512) NOT NULL,
        [OccurredAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_TagRelation] PRIMARY KEY ([TagRelationId]),
        CONSTRAINT [FK_TagRelation_Philote]
            FOREIGN KEY ([TagRelationId]) REFERENCES [ATAPUtilities].[Philote] ([PhiloteId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_TagRelation_SourceTag]
            FOREIGN KEY ([SourceTagId]) REFERENCES [ATAPUtilities].[Tag] ([TagId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_TagRelation_TargetTag]
            FOREIGN KEY ([TargetTagId]) REFERENCES [ATAPUtilities].[Tag] ([TagId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_TagRelation_Type]
            FOREIGN KEY ([TagRelationTypeId]) REFERENCES [ATAPUtilities].[TagRelationType] ([TagRelationTypeId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_TagRelation_Source_Target_Type]
            UNIQUE ([SourceTagId], [TargetTagId], [TagRelationTypeId]),
        CONSTRAINT [CK_TagRelation_NoSelfReference] CHECK ([SourceTagId] <> [TargetTagId]),
        CONSTRAINT [CK_TagRelation_Weight] CHECK ([Weight] > 0.0000 AND [Weight] <= 1.0000),
        CONSTRAINT [CK_TagRelation_SourceReference] CHECK (DATALENGTH([SourceReference]) > 0)
    );

    CREATE INDEX [IX_TagRelation_Source_Role_Weight_Target]
        ON [ATAPUtilities].[TagRelation]
            ([SourceTagId], [TagRelationTypeId], [Weight] DESC, [TargetTagId], [TagRelationId]);
    CREATE INDEX [IX_TagRelation_Target_Role_Source]
        ON [ATAPUtilities].[TagRelation]
            ([TargetTagId], [TagRelationTypeId], [SourceTagId], [TagRelationId]) INCLUDE ([Weight]);

    CREATE TABLE [ATAPUtilities].[TagAssignment]
    (
        [TagAssignmentId] uniqueidentifier NOT NULL,
        [TagId] uniqueidentifier NOT NULL,
        [EntityTypeCode] nvarchar(64) COLLATE Latin1_General_100_CI_AS_SC NOT NULL,
        [EntityId] uniqueidentifier NOT NULL,
        [ValidFromUtc] datetime2(7) NOT NULL,
        [ValidToUtc] datetime2(7) NULL,
        [IsClassificationOnly] bit NOT NULL CONSTRAINT [DF_TagAssignment_ClassificationOnly] DEFAULT (1),
        [PrincipalId] uniqueidentifier NOT NULL,
        [SourceReference] nvarchar(512) NOT NULL,
        [OccurredAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_TagAssignment] PRIMARY KEY ([TagAssignmentId]),
        CONSTRAINT [FK_TagAssignment_Tag]
            FOREIGN KEY ([TagId]) REFERENCES [ATAPUtilities].[Tag] ([TagId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_TagAssignment_EntityType]
            FOREIGN KEY ([EntityTypeCode]) REFERENCES [ATAPUtilities].[TagAssignmentEntityType] ([EntityTypeCode])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_TagAssignment_Identity]
            UNIQUE ([TagId], [EntityTypeCode], [EntityId], [ValidFromUtc]),
        CONSTRAINT [CK_TagAssignment_NonEmpty]
            CHECK ([ValidToUtc] IS NULL OR [ValidFromUtc] < [ValidToUtc]),
        CONSTRAINT [CK_TagAssignment_ClassificationOnly]
            CHECK ([IsClassificationOnly] = 1),
        CONSTRAINT [CK_TagAssignment_SourceReference]
            CHECK (DATALENGTH([SourceReference]) > 0)
    );

    CREATE UNIQUE INDEX [UX_TagAssignment_Current]
        ON [ATAPUtilities].[TagAssignment] ([TagId], [EntityTypeCode], [EntityId])
        WHERE [ValidToUtc] IS NULL;
    CREATE INDEX [IX_TagAssignment_Entity_AsOf]
        ON [ATAPUtilities].[TagAssignment]
            ([EntityTypeCode], [EntityId], [ValidFromUtc], [ValidToUtc], [TagId]);

    EXEC sys.sp_executesql N'CREATE TYPE [ATAPUtilities].[TagRelationRoleCodeInput] AS TABLE
    ([RoleCode] nvarchar(64) COLLATE Latin1_General_100_CI_AS_SC NOT NULL PRIMARY KEY);';

    DECLARE @SeedPrincipal uniqueidentifier = '90000000-0000-0000-0000-000000000001';
    DECLARE @SeedAt datetime2(7) = '2026-09-04T00:00:00';
    DECLARE @SeedSource nvarchar(512) = N'RPRRSBSI-V4 Task 15.50.c/.d deterministic seed';

    INSERT INTO [ATAPUtilities].[TagRelationType]
        ([TagRelationTypeId], [RoleCode], [InverseTagRelationTypeId], [DirectionCode],
         [RelationFamilyCode], [CyclePolicyCode], [IsTraversable], [PrincipalId],
         [SourceReference], [OccurredAtUtc], [RecordedAtUtc])
    VALUES
        ('90010000-0000-0000-0000-000000000001', N'REL_RELATED_TO',
         '90010000-0000-0000-0000-000000000001', 'Symmetric', N'associative', 'Allowed', 1,
         @SeedPrincipal, @SeedSource, @SeedAt, @SeedAt),
        ('90010000-0000-0000-0000-000000000002', N'REL_SEE_ALSO',
         '90010000-0000-0000-0000-000000000002', 'Symmetric', N'associative', 'Allowed', 1,
         @SeedPrincipal, @SeedSource, @SeedAt, @SeedAt),
        ('90010000-0000-0000-0000-000000000003', N'REL_OPPOSITE_OF',
         '90010000-0000-0000-0000-000000000003', 'Symmetric', N'semantic-opposition', 'Allowed', 1,
         @SeedPrincipal, @SeedSource, @SeedAt, @SeedAt),
        ('90010000-0000-0000-0000-000000000004', N'REL_BROADER_THAN',
         '90010000-0000-0000-0000-000000000005', 'Canonical', N'hierarchy-breadth', 'Prohibited', 1,
         @SeedPrincipal, @SeedSource, @SeedAt, @SeedAt),
        ('90010000-0000-0000-0000-000000000005', N'REL_NARROWER_THAN',
         '90010000-0000-0000-0000-000000000004', 'Inverse', N'hierarchy-breadth', 'Prohibited', 1,
         @SeedPrincipal, @SeedSource, @SeedAt, @SeedAt),
        ('90010000-0000-0000-0000-000000000006', N'REL_REPLACES',
         '90010000-0000-0000-0000-000000000007', 'Canonical', N'replacement', 'Prohibited', 1,
         @SeedPrincipal, @SeedSource, @SeedAt, @SeedAt),
        ('90010000-0000-0000-0000-000000000007', N'REL_REPLACED_BY',
         '90010000-0000-0000-0000-000000000006', 'Inverse', N'replacement', 'Prohibited', 1,
         @SeedPrincipal, @SeedSource, @SeedAt, @SeedAt),
        ('90010000-0000-0000-0000-000000000008', N'REL_PART_OF',
         '90010000-0000-0000-0000-000000000009', 'Canonical', N'hierarchy-composition', 'Prohibited', 1,
         @SeedPrincipal, @SeedSource, @SeedAt, @SeedAt),
        ('90010000-0000-0000-0000-000000000009', N'REL_HAS_PART',
         '90010000-0000-0000-0000-000000000008', 'Inverse', N'hierarchy-composition', 'Prohibited', 1,
         @SeedPrincipal, @SeedSource, @SeedAt, @SeedAt);

    INSERT INTO [ATAPUtilities].[TagAssignmentEntityType]
        ([EntityTypeCode], [TargetSchemaName], [TargetTableName], [TargetIdColumnName],
         [IsClassificationOnly], [PrincipalId], [SourceReference], [OccurredAtUtc], [RecordedAtUtc])
    VALUES
        (N'rule', N'ATAPUtilities', N'Rule', N'RuleId', 1,
         @SeedPrincipal, @SeedSource, @SeedAt, @SeedAt),
        (N'instantiation', N'ATAPUtilities', N'Instantiation', N'InstantiationId', 1,
         @SeedPrincipal, @SeedSource, @SeedAt, @SeedAt);

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_TagState_DeprecationImmutable]
ON [ATAPUtilities].[TagState]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN deleted AS d ON d.TagStateId=i.TagStateId
        WHERE i.IsDeprecated<>d.IsDeprecated
    )
        THROW 59010, ''Published TagState deprecation is immutable; append a new state.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_TagRelationType_Immutable]
ON [ATAPUtilities].[TagRelationType]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 59011, ''TagRelationType rows are immutable and cannot be deleted.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN [ATAPUtilities].[TagRelationType] AS inverseType
            ON inverseType.TagRelationTypeId=i.InverseTagRelationTypeId
        WHERE inverseType.InverseTagRelationTypeId<>i.TagRelationTypeId
           OR inverseType.RelationFamilyCode<>i.RelationFamilyCode
           OR (i.DirectionCode=''Symmetric'' AND
               (i.InverseTagRelationTypeId<>i.TagRelationTypeId OR inverseType.DirectionCode<>''Symmetric''))
           OR (i.DirectionCode=''Canonical'' AND inverseType.DirectionCode<>''Inverse'')
           OR (i.DirectionCode=''Inverse'' AND inverseType.DirectionCode<>''Canonical'')
           OR inverseType.CyclePolicyCode<>i.CyclePolicyCode
    )
        THROW 59012, ''Tag relation inverse, direction, family, or cycle metadata is inconsistent.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_TagAssignmentEntityType_Immutable]
ON [ATAPUtilities].[TagAssignmentEntityType]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 59013, ''TagAssignmentEntityType rows are immutable and cannot be deleted.'', 1;
    IF EXISTS (SELECT 1 FROM inserted WHERE IsClassificationOnly<>1)
        THROW 59014, ''Tag assignment endpoint types are classification-only.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_TagRelation_Authoring]
ON [ATAPUtilities].[TagRelation]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 59015, ''TagRelation roots are immutable and cannot be deleted; close Philote validity.'', 1;

    DECLARE @LockResult int;
    EXEC @LockResult=sys.sp_getapplock @Resource=''ATAPUtilities.TagRelationGraph'',
        @LockMode=''Exclusive'', @LockOwner=''Transaction'', @LockTimeout=15000,
        @DbPrincipal=''public'';
    IF @LockResult<0 THROW 59016, ''Unable to acquire the Tag relation graph writer lock.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN [ATAPUtilities].[Tag] AS sourceTag ON sourceTag.TagId=i.SourceTagId
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [ATAPUtilities].[TagNamespaceSteward] AS steward WITH (HOLDLOCK)
            WHERE steward.TagNamespaceId=sourceTag.TagNamespaceId
              AND steward.PrincipalId=i.PrincipalId
              AND steward.ValidFromUtc<=i.OccurredAtUtc
              AND (steward.ValidToUtc IS NULL OR i.OccurredAtUtc<steward.ValidToUtc)
        )
    )
        THROW 59017, ''Tag relation author is not an active source-namespace steward.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN [ATAPUtilities].[TagRelationType] AS it ON it.TagRelationTypeId=i.TagRelationTypeId
        INNER JOIN [ATAPUtilities].[TagRelation] AS existing WITH (UPDLOCK, HOLDLOCK)
            ON existing.SourceTagId=i.TargetTagId AND existing.TargetTagId=i.SourceTagId
           AND existing.TagRelationId<>i.TagRelationId
        INNER JOIN [ATAPUtilities].[TagRelationType] AS et
            ON et.TagRelationTypeId=existing.TagRelationTypeId
        WHERE (it.DirectionCode=''Symmetric'' AND et.TagRelationTypeId=it.TagRelationTypeId)
           OR (it.DirectionCode<>''Symmetric'' AND et.TagRelationTypeId=it.InverseTagRelationTypeId)
    )
        THROW 59018, ''A symmetric mirror or inverse duplicate is already stored.'', 1;

    DECLARE @CycleFound bit=0;
    ;WITH NormalizedEdges AS
    (
        SELECT rt.RelationFamilyCode,
               CASE WHEN rt.DirectionCode=''Inverse'' THEN r.TargetTagId ELSE r.SourceTagId END AS FromTagId,
               CASE WHEN rt.DirectionCode=''Inverse'' THEN r.SourceTagId ELSE r.TargetTagId END AS ToTagId
        FROM [ATAPUtilities].[TagRelation] AS r WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN [ATAPUtilities].[TagRelationType] AS rt
            ON rt.TagRelationTypeId=r.TagRelationTypeId
        WHERE rt.CyclePolicyCode=''Prohibited''
    ), Seeds AS
    (
        SELECT rt.RelationFamilyCode,
               CASE WHEN rt.DirectionCode=''Inverse'' THEN i.TargetTagId ELSE i.SourceTagId END AS StartTagId,
               CASE WHEN rt.DirectionCode=''Inverse'' THEN i.SourceTagId ELSE i.TargetTagId END AS CurrentTagId,
               CONVERT(nvarchar(max), N''|''+
                   CONVERT(nvarchar(36), CASE WHEN rt.DirectionCode=''Inverse'' THEN i.TargetTagId ELSE i.SourceTagId END)+N''|''+
                   CONVERT(nvarchar(36), CASE WHEN rt.DirectionCode=''Inverse'' THEN i.SourceTagId ELSE i.TargetTagId END)+N''|'') AS Visited
        FROM inserted AS i
        INNER JOIN [ATAPUtilities].[TagRelationType] AS rt
            ON rt.TagRelationTypeId=i.TagRelationTypeId
        WHERE rt.CyclePolicyCode=''Prohibited''
    ), Walk AS
    (
        SELECT RelationFamilyCode, StartTagId, CurrentTagId, Visited FROM Seeds
        UNION ALL
        SELECT w.RelationFamilyCode, w.StartTagId, edge.ToTagId,
               CONVERT(nvarchar(max), w.Visited+CONVERT(nvarchar(36), edge.ToTagId)+N''|'')
        FROM Walk AS w
        INNER JOIN NormalizedEdges AS edge
            ON edge.RelationFamilyCode=w.RelationFamilyCode AND edge.FromTagId=w.CurrentTagId
        WHERE edge.ToTagId=w.StartTagId
           OR CHARINDEX(N''|''+CONVERT(nvarchar(36), edge.ToTagId)+N''|'', w.Visited)=0
    )
    SELECT TOP (1) @CycleFound=1 FROM Walk WHERE CurrentTagId=StartTagId
    OPTION (MAXRECURSION 32767);
    IF @CycleFound=1 THROW 59019, ''A cycle is prohibited within this Tag relation family.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_TagAssignment_HistoryAndTarget]
ON [ATAPUtilities].[TagAssignment]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
        THROW 59020, ''TagAssignment history cannot be deleted.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i INNER JOIN deleted AS d ON d.TagAssignmentId=i.TagAssignmentId
        WHERE i.TagId<>d.TagId OR i.EntityTypeCode<>d.EntityTypeCode OR i.EntityId<>d.EntityId
           OR i.ValidFromUtc<>d.ValidFromUtc OR i.IsClassificationOnly<>d.IsClassificationOnly
           OR i.PrincipalId<>d.PrincipalId OR i.SourceReference<>d.SourceReference
           OR i.OccurredAtUtc<>d.OccurredAtUtc OR i.RecordedAtUtc<>d.RecordedAtUtc
           OR d.ValidToUtc IS NOT NULL OR i.ValidToUtc IS NULL
    )
        THROW 59021, ''TagAssignment is append/close-only.'', 1;
    IF EXISTS (SELECT 1 FROM inserted WHERE IsClassificationOnly<>1)
        THROW 59022, ''Tags classify and never authorize.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        WHERE (i.EntityTypeCode=N''rule'' AND
               NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleId=i.EntityId))
           OR (i.EntityTypeCode=N''instantiation'' AND
               NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Instantiation] WHERE InstantiationId=i.EntityId))
           OR i.EntityTypeCode NOT IN (N''rule'', N''instantiation'')
    )
        THROW 59023, ''Tag assignment target does not exist in its allow-listed entity type.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN [ATAPUtilities].[Tag] AS t ON t.TagId=i.TagId
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [ATAPUtilities].[TagNamespaceSteward] AS steward WITH (HOLDLOCK)
            WHERE steward.TagNamespaceId=t.TagNamespaceId AND steward.PrincipalId=i.PrincipalId
              AND steward.ValidFromUtc<=i.OccurredAtUtc
              AND (steward.ValidToUtc IS NULL OR i.OccurredAtUtc<steward.ValidToUtc)
        )
          OR NOT EXISTS
        (
            SELECT 1 FROM [ATAPUtilities].[ResolveTagAsOf](i.TagId, i.ValidFromUtc)
            WHERE ResolutionStatusCode=''Resolved''
        )
    )
        THROW 59024, ''Assignment requires an effective Tag and active namespace steward.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN [ATAPUtilities].[TagAssignment] AS other WITH (UPDLOCK, HOLDLOCK)
            ON other.TagId=i.TagId AND other.EntityTypeCode=i.EntityTypeCode
           AND other.EntityId=i.EntityId AND other.TagAssignmentId<>i.TagAssignmentId
           AND i.ValidFromUtc<COALESCE(other.ValidToUtc, CONVERT(datetime2(7),''9999-12-31T23:59:59.9999999''))
           AND other.ValidFromUtc<COALESCE(i.ValidToUtc, CONVERT(datetime2(7),''9999-12-31T23:59:59.9999999''))
    )
        THROW 59025, ''Tag assignment intervals for one target cannot overlap.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[CreateTagRelation]
    @TagRelationId uniqueidentifier,
    @PhiloteValidityPeriodId uniqueidentifier,
    @SourceTagId uniqueidentifier,
    @TargetTagId uniqueidentifier,
    @RoleCode nvarchar(64),
    @Weight decimal(5,4)=1.0000,
    @EffectiveFromUtc datetime2(7),
    @PrincipalId uniqueidentifier,
    @SourceReference nvarchar(512),
    @OccurredAtUtc datetime2(7),
    @RecordedAtUtc datetime2(7)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @TagRelationId IS NULL OR @PhiloteValidityPeriodId IS NULL OR @SourceTagId IS NULL
       OR @TargetTagId IS NULL OR NULLIF(@RoleCode,N'''') IS NULL OR @EffectiveFromUtc IS NULL
       OR @PrincipalId IS NULL OR NULLIF(@SourceReference,N'''') IS NULL
       OR @OccurredAtUtc IS NULL OR @RecordedAtUtc IS NULL
        THROW 59030, ''All Tag relation identity, role, time, actor, and source parameters are required.'', 1;
    DECLARE @TypeId uniqueidentifier=(SELECT TagRelationTypeId FROM [ATAPUtilities].[TagRelationType]
                                      WHERE RoleCode=@RoleCode AND IsTraversable=1);
    IF @TypeId IS NULL THROW 59031, ''Unknown or non-traversable Tag relation role.'', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub]) VALUES (@TagRelationId,NULL);
        EXEC [ATAPUtilities].[CreateFirstPhiloteValidityPeriod]
            @PhiloteId=@TagRelationId, @PhiloteValidityPeriodId=@PhiloteValidityPeriodId,
            @ValidFromUtc=@EffectiveFromUtc, @ValidToUtc=NULL;
        INSERT INTO [ATAPUtilities].[TagRelation]
            ([TagRelationId],[SourceTagId],[TargetTagId],[TagRelationTypeId],[Weight],
             [PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
        VALUES (@TagRelationId,@SourceTagId,@TargetTagId,@TypeId,@Weight,
                @PrincipalId,@SourceReference,@OccurredAtUtc,@RecordedAtUtc);
        COMMIT TRANSACTION;
        SELECT * FROM [ATAPUtilities].[TagRelation] WHERE TagRelationId=@TagRelationId;
    END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[CreateTagAssignment]
    @TagAssignmentId uniqueidentifier,
    @TagId uniqueidentifier,
    @EntityTypeCode nvarchar(64),
    @EntityId uniqueidentifier,
    @ValidFromUtc datetime2(7),
    @ValidToUtc datetime2(7)=NULL,
    @PrincipalId uniqueidentifier,
    @SourceReference nvarchar(512),
    @OccurredAtUtc datetime2(7),
    @RecordedAtUtc datetime2(7)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @TagAssignmentId IS NULL OR @TagId IS NULL OR NULLIF(@EntityTypeCode,N'''') IS NULL
       OR @EntityId IS NULL OR @ValidFromUtc IS NULL OR @PrincipalId IS NULL
       OR NULLIF(@SourceReference,N'''') IS NULL OR @OccurredAtUtc IS NULL OR @RecordedAtUtc IS NULL
        THROW 59032, ''All Tag assignment identity, target, time, actor, and source parameters are required.'', 1;
    INSERT INTO [ATAPUtilities].[TagAssignment]
        ([TagAssignmentId],[TagId],[EntityTypeCode],[EntityId],[ValidFromUtc],[ValidToUtc],
         [IsClassificationOnly],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
    VALUES (@TagAssignmentId,@TagId,@EntityTypeCode,@EntityId,@ValidFromUtc,@ValidToUtc,
            1,@PrincipalId,@SourceReference,@OccurredAtUtc,@RecordedAtUtc);
    SELECT * FROM [ATAPUtilities].[TagAssignment] WHERE TagAssignmentId=@TagAssignmentId;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[QueryTagLogicalEdgesAsOf]
    @SourceTagId uniqueidentifier,
    @AsOfUtc datetime2(7),
    @RoleCodes [ATAPUtilities].[TagRelationRoleCodeInput] READONLY
AS
BEGIN
    SET NOCOUNT ON;
    IF @SourceTagId IS NULL OR @AsOfUtc IS NULL
        THROW 59033, ''SourceTagId and AsOfUtc are required.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM @RoleCodes AS requested
        WHERE NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[TagRelationType]
                          WHERE RoleCode=requested.RoleCode AND IsTraversable=1)
    ) THROW 59034, ''Unknown or non-traversable role filter.'', 1;

    ;WITH LogicalEdges AS
    (
        SELECT r.TagRelationId, r.SourceTagId, r.TargetTagId, rt.RoleCode,
               CAST(N''stored'' AS nvarchar(16)) AS Projection, r.Weight
        FROM [ATAPUtilities].[TagRelation] AS r
        INNER JOIN [ATAPUtilities].[TagRelationType] AS rt ON rt.TagRelationTypeId=r.TagRelationTypeId
        WHERE r.SourceTagId=@SourceTagId
        UNION ALL
        SELECT r.TagRelationId, r.TargetTagId, r.SourceTagId, rt.RoleCode,
               CAST(N''symmetric'' AS nvarchar(16)), r.Weight
        FROM [ATAPUtilities].[TagRelation] AS r
        INNER JOIN [ATAPUtilities].[TagRelationType] AS rt ON rt.TagRelationTypeId=r.TagRelationTypeId
        WHERE r.TargetTagId=@SourceTagId AND rt.DirectionCode=''Symmetric''
        UNION ALL
        SELECT r.TagRelationId, r.TargetTagId, r.SourceTagId, inverseType.RoleCode,
               CAST(N''inverse'' AS nvarchar(16)), r.Weight
        FROM [ATAPUtilities].[TagRelation] AS r
        INNER JOIN [ATAPUtilities].[TagRelationType] AS rt ON rt.TagRelationTypeId=r.TagRelationTypeId
        INNER JOIN [ATAPUtilities].[TagRelationType] AS inverseType
            ON inverseType.TagRelationTypeId=rt.InverseTagRelationTypeId
        WHERE r.TargetTagId=@SourceTagId AND rt.DirectionCode<>''Symmetric''
    )
    SELECT edge.TagRelationId, edge.SourceTagId, edge.TargetTagId, edge.RoleCode,
           edge.Projection, edge.Weight, resolved.NamespaceCode,
           resolved.TagCode AS TargetTagCode, resolved.TagStateId,
           resolved.Label, resolved.Description, stateRow.IsDeprecated
    FROM LogicalEdges AS edge
    INNER JOIN [ATAPUtilities].[PhiloteValidityPeriod] AS relationPeriod
        ON relationPeriod.PhiloteId=edge.TagRelationId
       AND relationPeriod.ValidFromUtc<=@AsOfUtc
       AND (relationPeriod.ValidToUtc IS NULL OR @AsOfUtc<relationPeriod.ValidToUtc)
    CROSS APPLY [ATAPUtilities].[ResolveTagAsOf](edge.TargetTagId,@AsOfUtc) AS resolved
    INNER JOIN [ATAPUtilities].[TagState] AS stateRow ON stateRow.TagStateId=resolved.TagStateId
    WHERE resolved.ResolutionStatusCode=''Resolved''
      AND (NOT EXISTS (SELECT 1 FROM @RoleCodes)
           OR EXISTS (SELECT 1 FROM @RoleCodes AS requested WHERE requested.RoleCode=edge.RoleCode))
    ORDER BY edge.Weight DESC, edge.RoleCode COLLATE Latin1_General_100_BIN2,
             resolved.TagCode COLLATE Latin1_General_100_BIN2,
             CONVERT(binary(16),edge.TargetTagId), CONVERT(binary(16),edge.TagRelationId),
             CASE edge.Projection WHEN N''stored'' THEN 0 WHEN N''symmetric'' THEN 1 ELSE 2 END;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[QueryTagAssignmentsAsOf]
    @EntityTypeCode nvarchar(64),
    @EntityId uniqueidentifier,
    @AsOfUtc datetime2(7)
AS
BEGIN
    SET NOCOUNT ON;
    IF NULLIF(@EntityTypeCode,N'''') IS NULL OR @EntityId IS NULL OR @AsOfUtc IS NULL
        THROW 59035, ''EntityTypeCode, EntityId, and AsOfUtc are required.'', 1;
    SELECT a.TagAssignmentId, a.EntityTypeCode, a.EntityId, a.TagId,
           resolved.NamespaceCode, resolved.TagCode, resolved.TagStateId,
           resolved.Label, resolved.Description, s.IsDeprecated,
           a.PrincipalId, a.SourceReference, a.OccurredAtUtc, a.RecordedAtUtc,
           a.IsClassificationOnly
    FROM [ATAPUtilities].[TagAssignment] AS a
    CROSS APPLY [ATAPUtilities].[ResolveTagAsOf](a.TagId,@AsOfUtc) AS resolved
    INNER JOIN [ATAPUtilities].[TagState] AS s ON s.TagStateId=resolved.TagStateId
    WHERE a.EntityTypeCode=@EntityTypeCode AND a.EntityId=@EntityId
      AND a.ValidFromUtc<=@AsOfUtc AND (a.ValidToUtc IS NULL OR @AsOfUtc<a.ValidToUtc)
      AND resolved.ResolutionStatusCode=''Resolved''
    ORDER BY resolved.NamespaceCode COLLATE Latin1_General_100_BIN2,
             resolved.TagCode COLLATE Latin1_General_100_BIN2,
             CONVERT(binary(16),a.TagId);
END;';

    INSERT INTO [ATAPUtilities].[TagNamespace]
        ([TagNamespaceId],[NamespaceCode],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
    VALUES ('90020000-0000-0000-0000-000000000001',N'ATAP.SYSTEM',@SeedPrincipal,@SeedSource,@SeedAt,@SeedAt);
    INSERT INTO [ATAPUtilities].[TagNamespaceSteward]
        ([TagNamespaceStewardId],[TagNamespaceId],[PrincipalId],[ValidFromUtc],[ValidToUtc],
         [SourceReference],[OccurredAtUtc],[RecordedAtUtc])
    VALUES ('90020000-0000-0000-0000-000000000002','90020000-0000-0000-0000-000000000001',
            @SeedPrincipal,@SeedAt,NULL,@SeedSource,@SeedAt,@SeedAt);

    INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub]) VALUES
        ('90020000-0000-0000-0000-000000000010',NULL),
        ('90020000-0000-0000-0000-000000000020',NULL);
    INSERT INTO [ATAPUtilities].[PhiloteValidityPeriod]
        ([PhiloteValidityPeriodId],[PhiloteId],[PreviousValidToUtc],[ValidFromUtc],[ValidToUtc])
    VALUES
        ('90020000-0000-0000-0000-000000000011','90020000-0000-0000-0000-000000000010',NULL,@SeedAt,NULL),
        ('90020000-0000-0000-0000-000000000021','90020000-0000-0000-0000-000000000020',NULL,@SeedAt,NULL);
    INSERT INTO [ATAPUtilities].[Tag]
        ([TagId],[TagNamespaceId],[TagCode],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
    VALUES
        ('90020000-0000-0000-0000-000000000010','90020000-0000-0000-0000-000000000001',
         N'RRSBS_RULE_DEFINITION',@SeedPrincipal,@SeedSource,@SeedAt,@SeedAt),
        ('90020000-0000-0000-0000-000000000020','90020000-0000-0000-0000-000000000001',
         N'RRSBS_INSTANTIATION_DEFINITION',@SeedPrincipal,@SeedSource,@SeedAt,@SeedAt);
    INSERT INTO [ATAPUtilities].[TagState]
        ([TagStateId],[TagId],[PhiloteValidityPeriodId],[ValidFromUtc],[ValidToUtc],
         [Label],[Description],[TagStateKindCode],[SuccessorTagId],[WithdrawalReason],
         [PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
    VALUES
        ('90020000-0000-0000-0000-000000000012','90020000-0000-0000-0000-000000000010',
         '90020000-0000-0000-0000-000000000011',@SeedAt,NULL,N'RRSBS Rule definition',
         N'Classification only; never grants capability or authorization.','Active',NULL,NULL,
         @SeedPrincipal,@SeedSource,@SeedAt,@SeedAt),
        ('90020000-0000-0000-0000-000000000022','90020000-0000-0000-0000-000000000020',
         '90020000-0000-0000-0000-000000000021',@SeedAt,NULL,N'RRSBS Instantiation definition',
         N'Classification only; never grants capability or authorization.','Active',NULL,NULL,
         @SeedPrincipal,@SeedSource,@SeedAt,@SeedAt);

    INSERT INTO [ATAPUtilities].[TagAssignment]
        ([TagAssignmentId],[TagId],[EntityTypeCode],[EntityId],[ValidFromUtc],[ValidToUtc],
         [IsClassificationOnly],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
    VALUES
        ('90030000-0000-0000-0000-000000000001','90020000-0000-0000-0000-000000000010',
         N'rule','616fb394-0b4d-486a-98af-48f1fe461af2',@SeedAt,NULL,1,
         @SeedPrincipal,@SeedSource,@SeedAt,@SeedAt),
        ('90030000-0000-0000-0000-000000000002','90020000-0000-0000-0000-000000000020',
         N'instantiation','03e28494-998f-4fc2-ba5d-ad6e5832c8b7',@SeedAt,NULL,1,
         @SeedPrincipal,@SeedSource,@SeedAt,@SeedAt);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

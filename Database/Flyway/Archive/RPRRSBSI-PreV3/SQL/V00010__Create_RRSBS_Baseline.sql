/*
  RRSBS V2 immutable baseline, allocated by RDB-300 as V00010.
  Integrated solely by RDB-480 from the reviewed RDB-400 through RDB-470
  fragments. No USE statement, seed data, credentials, reset, or destructive
  operation belongs in this migration.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'RRSBS_RUN_RDB420_FIXTURES')) = 1
   OR TRY_CONVERT(bit, SESSION_CONTEXT(N'RRSBS_RUN_RDB430_FIXTURES')) = 1
   OR TRY_CONVERT(bit, SESSION_CONTEXT(N'RRSBS_RUN_RDB440_FIXTURES')) = 1
   OR TRY_CONVERT(bit, SESSION_CONTEXT(N'Rdb450RunFixtures')) = 1
   OR TRY_CONVERT(bit, SESSION_CONTEXT(N'RRSBS_RUN_RDB460_FIXTURES')) = 1
    THROW 54800, 'RDB-480 baseline refuses fixture-enabled session context.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.database_principals
    WHERE [name] = N'RrsbsPublisher'
      AND [type] <> 'R'
)
    THROW 54801, 'RDB-480 requires RrsbsPublisher to be absent or a database role.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

/* BEGIN INTEGRATED FRAGMENT: RDB-400-410__Foundation-Kind-Primitive.sql */
/*
  RDB-400/410 — RRSBS V2 foundation, RuleKind, Primitive, and ValueType fragment
  Target: SQL Server 2022 / compatibility level 160
  Integration owner: RDB-480

  This fragment creates only the 36 objects registered to RDB-200 and RDB-210.
  Cross-slice foreign keys whose parents are created by later fragments are
  intentionally recorded in RDB-400-410/Evidence.md for RDB-480.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF SCHEMA_ID(N'ATAPUtilities') IS NULL
BEGIN
    EXEC sys.sp_executesql N'CREATE SCHEMA [ATAPUtilities] AUTHORIZATION [dbo];';
END;

/* RDB-400: typed Entity foundation. */
IF OBJECT_ID(N'[ATAPUtilities].[EntityType]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[EntityType]
    (
        [EntityTypeId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_EntityType] PRIMARY KEY,
        [EntityTypeCode] varchar(64) NOT NULL,
        [OwningSliceCode] varchar(16) NOT NULL,
        [IsVersionType] bit NOT NULL,
        CONSTRAINT [UQ_EntityType_EntityTypeCode] UNIQUE ([EntityTypeCode]),
        CONSTRAINT [UQ_EntityType_EntityTypeId_EntityTypeCode]
            UNIQUE ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [CK_EntityType_CodeFormat]
            CHECK
            (
                [EntityTypeCode] = LOWER([EntityTypeCode])
                AND [EntityTypeCode] NOT LIKE '%[^a-z0-9-]%'
                AND LEN([EntityTypeCode]) BETWEEN 1 AND 64
            ),
        CONSTRAINT [CK_EntityType_OwningSliceCode]
            CHECK (LEN(LTRIM(RTRIM([OwningSliceCode]))) BETWEEN 1 AND 16)
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[Entity]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[Entity]
    (
        [EntityId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_Entity] PRIMARY KEY,
        [EntityTypeId] bigint NOT NULL,
        [EntityPhiloteId] uniqueidentifier NOT NULL,
        [CreatedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_Entity_EntityPhiloteId] UNIQUE ([EntityPhiloteId]),
        CONSTRAINT [UQ_Entity_EntityId_EntityTypeId]
            UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [UQ_Entity_EntityId_EntityTypeId_EntityPhiloteId]
            UNIQUE ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_Entity_EntityType_Type]
            FOREIGN KEY ([EntityTypeId])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId]),
        INDEX [IX_Entity_EntityTypeId] NONCLUSTERED ([EntityTypeId])
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[RelationshipRolePolicy]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[RelationshipRolePolicy]
    (
        [RelationshipRolePolicyId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_RelationshipRolePolicy] PRIMARY KEY,
        [RelationshipKindCode] varchar(64) NOT NULL,
        [RelationshipRoleCode] varchar(64) NOT NULL,
        [IsClassificationOnly] bit NOT NULL,
        [IsAuthorizationRole] bit NOT NULL,
        CONSTRAINT [UQ_RelationshipRolePolicy_RelationshipKindCode_RelationshipRoleCode]
            UNIQUE ([RelationshipKindCode], [RelationshipRoleCode]),
        CONSTRAINT [CK_RelationshipRolePolicy_NoAuthorization]
            CHECK ([IsAuthorizationRole] = CONVERT(bit, 0)),
        CONSTRAINT [CK_RelationshipRolePolicy_ClassificationKinds]
            CHECK
            (
                [RelationshipKindCode] NOT IN ('domain-assignment', 'tag-assignment')
                OR [IsClassificationOnly] = CONVERT(bit, 1)
            ),
        CONSTRAINT [CK_RelationshipRolePolicy_CodeFormat]
            CHECK
            (
                LEN(LTRIM(RTRIM([RelationshipKindCode]))) BETWEEN 1 AND 64
                AND LEN(LTRIM(RTRIM([RelationshipRoleCode]))) BETWEEN 1 AND 64
            )
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[RelationshipRoleEndpointEntityType]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[RelationshipRoleEndpointEntityType]
    (
        [RelationshipRolePolicyId] bigint NOT NULL,
        [EndpointCode] varchar(32) NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        CONSTRAINT [PK_RelationshipRoleEndpointEntityType]
            PRIMARY KEY ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId]),
        CONSTRAINT [FK_RelationshipRoleEndpointEntityType_RelationshipRolePolicy_Policy]
            FOREIGN KEY ([RelationshipRolePolicyId])
            REFERENCES [ATAPUtilities].[RelationshipRolePolicy] ([RelationshipRolePolicyId]),
        CONSTRAINT [FK_RelationshipRoleEndpointEntityType_EntityType_AllowedType]
            FOREIGN KEY ([EntityTypeId])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId]),
        CONSTRAINT [CK_RelationshipRoleEndpointEntityType_EndpointCode]
            CHECK (LEN(LTRIM(RTRIM([EndpointCode]))) BETWEEN 1 AND 32),
        INDEX [IX_RelationshipRoleEndpointEntityType_EntityTypeId]
            NONCLUSTERED ([EntityTypeId])
    );
END;

/* RDB-200 durable roots and immutable versions. Computed type-code columns
   bind each subtype to its exact frozen EntityTypeCode without relying on
   seed-time numeric identifiers. */
IF OBJECT_ID(N'[ATAPUtilities].[Authority]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[Authority]
    (
        [AuthorityId] bigint IDENTITY(1, 1) NOT NULL CONSTRAINT [PK_Authority] PRIMARY KEY,
        [AuthorityPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'authority')) PERSISTED,
        [AuthorityCode] varchar(128) NOT NULL,
        [CreatedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_Authority_AuthorityPhiloteId] UNIQUE ([AuthorityPhiloteId]),
        CONSTRAINT [UQ_Authority_AuthorityCode] UNIQUE ([AuthorityCode]),
        CONSTRAINT [UQ_Authority_EntityId_EntityTypeId] UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_Authority_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [AuthorityPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_Authority_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [CK_Authority_AuthorityCode]
            CHECK (LEN(LTRIM(RTRIM([AuthorityCode]))) BETWEEN 1 AND 128)
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[AuthorityVersion]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[AuthorityVersion]
    (
        [AuthorityVersionId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_AuthorityVersion] PRIMARY KEY,
        [AuthorityVersionPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'authority-version')) PERSISTED,
        [AuthorityId] bigint NOT NULL,
        [RevisionSequence] int NOT NULL,
        [PredecessorAuthorityVersionId] bigint NULL,
        [AuthorityKindCode] varchar(64) NOT NULL,
        [DisplayLabel] nvarchar(256) NOT NULL,
        [Description] nvarchar(2048) NULL,
        [PublishedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_AuthorityVersion_AuthorityVersionPhiloteId]
            UNIQUE ([AuthorityVersionPhiloteId]),
        CONSTRAINT [UQ_AuthorityVersion_EntityId_EntityTypeId]
            UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [UQ_AuthorityVersion_AuthorityVersionId_AuthorityId]
            UNIQUE ([AuthorityVersionId], [AuthorityId]),
        CONSTRAINT [UQ_AuthorityVersion_AuthorityId_RevisionSequence]
            UNIQUE ([AuthorityId], [RevisionSequence]),
        INDEX [UQ_AuthorityVersion_PredecessorAuthorityVersionId]
            UNIQUE NONCLUSTERED ([PredecessorAuthorityVersionId])
            WHERE [PredecessorAuthorityVersionId] IS NOT NULL,
        CONSTRAINT [FK_AuthorityVersion_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [AuthorityVersionPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_AuthorityVersion_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [FK_AuthorityVersion_Authority_Parent]
            FOREIGN KEY ([AuthorityId]) REFERENCES [ATAPUtilities].[Authority] ([AuthorityId]),
        CONSTRAINT [FK_AuthorityVersion_AuthorityVersion_Predecessor]
            FOREIGN KEY ([PredecessorAuthorityVersionId], [AuthorityId])
            REFERENCES [ATAPUtilities].[AuthorityVersion] ([AuthorityVersionId], [AuthorityId]),
        CONSTRAINT [CK_AuthorityVersion_RevisionSequence]
            CHECK ([RevisionSequence] > 0),
        CONSTRAINT [CK_AuthorityVersion_AuthorityKindCode]
            CHECK (LEN(LTRIM(RTRIM([AuthorityKindCode]))) BETWEEN 1 AND 64),
        CONSTRAINT [CK_AuthorityVersion_DisplayLabel]
            CHECK (LEN(LTRIM(RTRIM([DisplayLabel]))) BETWEEN 1 AND 256),
        INDEX [IX_AuthorityVersion_AuthorityId] NONCLUSTERED ([AuthorityId])
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[Expert]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[Expert]
    (
        [ExpertId] bigint IDENTITY(1, 1) NOT NULL CONSTRAINT [PK_Expert] PRIMARY KEY,
        [ExpertPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'expert')) PERSISTED,
        [ExpertCode] varchar(128) NOT NULL,
        [CreatedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_Expert_ExpertPhiloteId] UNIQUE ([ExpertPhiloteId]),
        CONSTRAINT [UQ_Expert_ExpertCode] UNIQUE ([ExpertCode]),
        CONSTRAINT [UQ_Expert_EntityId_EntityTypeId] UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_Expert_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [ExpertPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_Expert_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [CK_Expert_ExpertCode]
            CHECK (LEN(LTRIM(RTRIM([ExpertCode]))) BETWEEN 1 AND 128)
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[ExpertVersion]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[ExpertVersion]
    (
        [ExpertVersionId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_ExpertVersion] PRIMARY KEY,
        [ExpertVersionPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'expert-version')) PERSISTED,
        [ExpertId] bigint NOT NULL,
        [RevisionSequence] int NOT NULL,
        [PredecessorExpertVersionId] bigint NULL,
        [DisplayLabel] nvarchar(256) NOT NULL,
        [NonSecretDescription] nvarchar(2048) NULL,
        [PublishedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_ExpertVersion_ExpertVersionPhiloteId] UNIQUE ([ExpertVersionPhiloteId]),
        CONSTRAINT [UQ_ExpertVersion_EntityId_EntityTypeId] UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [UQ_ExpertVersion_ExpertVersionId_ExpertId]
            UNIQUE ([ExpertVersionId], [ExpertId]),
        CONSTRAINT [UQ_ExpertVersion_ExpertId_RevisionSequence]
            UNIQUE ([ExpertId], [RevisionSequence]),
        INDEX [UQ_ExpertVersion_PredecessorExpertVersionId]
            UNIQUE NONCLUSTERED ([PredecessorExpertVersionId])
            WHERE [PredecessorExpertVersionId] IS NOT NULL,
        CONSTRAINT [FK_ExpertVersion_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [ExpertVersionPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_ExpertVersion_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [FK_ExpertVersion_Expert_Parent]
            FOREIGN KEY ([ExpertId]) REFERENCES [ATAPUtilities].[Expert] ([ExpertId]),
        CONSTRAINT [FK_ExpertVersion_ExpertVersion_Predecessor]
            FOREIGN KEY ([PredecessorExpertVersionId], [ExpertId])
            REFERENCES [ATAPUtilities].[ExpertVersion] ([ExpertVersionId], [ExpertId]),
        CONSTRAINT [CK_ExpertVersion_RevisionSequence] CHECK ([RevisionSequence] > 0),
        CONSTRAINT [CK_ExpertVersion_DisplayLabel]
            CHECK (LEN(LTRIM(RTRIM([DisplayLabel]))) BETWEEN 1 AND 256),
        INDEX [IX_ExpertVersion_ExpertId] NONCLUSTERED ([ExpertId])
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[ExpertiseDomain]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[ExpertiseDomain]
    (
        [ExpertiseDomainId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_ExpertiseDomain] PRIMARY KEY,
        [ExpertiseDomainPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'expertise-domain')) PERSISTED,
        [ExpertiseDomainCode] varchar(128) NOT NULL,
        [CreatedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_ExpertiseDomain_ExpertiseDomainPhiloteId]
            UNIQUE ([ExpertiseDomainPhiloteId]),
        CONSTRAINT [UQ_ExpertiseDomain_ExpertiseDomainCode]
            UNIQUE ([ExpertiseDomainCode]),
        CONSTRAINT [UQ_ExpertiseDomain_EntityId_EntityTypeId]
            UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_ExpertiseDomain_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [ExpertiseDomainPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_ExpertiseDomain_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [CK_ExpertiseDomain_ExpertiseDomainCode]
            CHECK (LEN(LTRIM(RTRIM([ExpertiseDomainCode]))) BETWEEN 1 AND 128)
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[ExpertiseDomainVersion]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[ExpertiseDomainVersion]
    (
        [ExpertiseDomainVersionId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_ExpertiseDomainVersion] PRIMARY KEY,
        [ExpertiseDomainVersionPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'expertise-domain-version')) PERSISTED,
        [ExpertiseDomainId] bigint NOT NULL,
        [RevisionSequence] int NOT NULL,
        [PredecessorExpertiseDomainVersionId] bigint NULL,
        [ParentExpertiseDomainVersionId] bigint NULL,
        [ParentExpertiseDomainId] bigint NULL,
        [DisplayLabel] nvarchar(256) NOT NULL,
        [Description] nvarchar(2048) NULL,
        [PublishedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_ExpertiseDomainVersion_ExpertiseDomainVersionPhiloteId]
            UNIQUE ([ExpertiseDomainVersionPhiloteId]),
        CONSTRAINT [UQ_ExpertiseDomainVersion_EntityId_EntityTypeId]
            UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [UQ_ExpertiseDomainVersion_ExpertiseDomainVersionId_ExpertiseDomainId]
            UNIQUE ([ExpertiseDomainVersionId], [ExpertiseDomainId]),
        CONSTRAINT [UQ_ExpertiseDomainVersion_ExpertiseDomainId_RevisionSequence]
            UNIQUE ([ExpertiseDomainId], [RevisionSequence]),
        INDEX [UQ_ExpertiseDomainVersion_PredecessorExpertiseDomainVersionId]
            UNIQUE NONCLUSTERED ([PredecessorExpertiseDomainVersionId])
            WHERE [PredecessorExpertiseDomainVersionId] IS NOT NULL,
        CONSTRAINT [FK_ExpertiseDomainVersion_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [ExpertiseDomainVersionPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_ExpertiseDomainVersion_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [FK_ExpertiseDomainVersion_ExpertiseDomain_Parent]
            FOREIGN KEY ([ExpertiseDomainId])
            REFERENCES [ATAPUtilities].[ExpertiseDomain] ([ExpertiseDomainId]),
        CONSTRAINT [FK_ExpertiseDomainVersion_ExpertiseDomainVersion_Predecessor]
            FOREIGN KEY ([PredecessorExpertiseDomainVersionId], [ExpertiseDomainId])
            REFERENCES [ATAPUtilities].[ExpertiseDomainVersion]
                ([ExpertiseDomainVersionId], [ExpertiseDomainId]),
        CONSTRAINT [FK_ExpertiseDomainVersion_ExpertiseDomainVersion_HierarchyParent]
            FOREIGN KEY ([ParentExpertiseDomainVersionId], [ParentExpertiseDomainId])
            REFERENCES [ATAPUtilities].[ExpertiseDomainVersion]
                ([ExpertiseDomainVersionId], [ExpertiseDomainId]),
        CONSTRAINT [CK_ExpertiseDomainVersion_RevisionSequence]
            CHECK ([RevisionSequence] > 0),
        CONSTRAINT [CK_ExpertiseDomainVersion_ParentPair]
            CHECK
            (
                ([ParentExpertiseDomainVersionId] IS NULL AND [ParentExpertiseDomainId] IS NULL)
                OR
                ([ParentExpertiseDomainVersionId] IS NOT NULL
                 AND [ParentExpertiseDomainId] IS NOT NULL
                 AND [ParentExpertiseDomainId] <> [ExpertiseDomainId])
            ),
        INDEX [IX_ExpertiseDomainVersion_ExpertiseDomainId]
            NONCLUSTERED ([ExpertiseDomainId]),
        INDEX [IX_ExpertiseDomainVersion_ParentExpertiseDomainVersionId]
            NONCLUSTERED ([ParentExpertiseDomainVersionId])
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[Tag]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[Tag]
    (
        [TagId] bigint IDENTITY(1, 1) NOT NULL CONSTRAINT [PK_Tag] PRIMARY KEY,
        [TagPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'tag')) PERSISTED,
        [TagNamespaceCode] varchar(128) NOT NULL,
        [TagCode] varchar(128) NOT NULL,
        [CreatedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_Tag_TagPhiloteId] UNIQUE ([TagPhiloteId]),
        CONSTRAINT [UQ_Tag_TagNamespaceCode_TagCode]
            UNIQUE ([TagNamespaceCode], [TagCode]),
        CONSTRAINT [UQ_Tag_EntityId_EntityTypeId] UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_Tag_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [TagPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_Tag_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [CK_Tag_Codes]
            CHECK
            (
                LEN(LTRIM(RTRIM([TagNamespaceCode]))) BETWEEN 1 AND 128
                AND LEN(LTRIM(RTRIM([TagCode]))) BETWEEN 1 AND 128
            )
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[TagVersion]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[TagVersion]
    (
        [TagVersionId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_TagVersion] PRIMARY KEY,
        [TagVersionPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'tag-version')) PERSISTED,
        [TagId] bigint NOT NULL,
        [RevisionSequence] int NOT NULL,
        [PredecessorTagVersionId] bigint NULL,
        [DisplayLabel] nvarchar(256) NOT NULL,
        [Description] nvarchar(2048) NULL,
        [PublishedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_TagVersion_TagVersionPhiloteId] UNIQUE ([TagVersionPhiloteId]),
        CONSTRAINT [UQ_TagVersion_EntityId_EntityTypeId] UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [UQ_TagVersion_TagVersionId_TagId] UNIQUE ([TagVersionId], [TagId]),
        CONSTRAINT [UQ_TagVersion_TagId_RevisionSequence]
            UNIQUE ([TagId], [RevisionSequence]),
        INDEX [UQ_TagVersion_PredecessorTagVersionId]
            UNIQUE NONCLUSTERED ([PredecessorTagVersionId])
            WHERE [PredecessorTagVersionId] IS NOT NULL,
        CONSTRAINT [FK_TagVersion_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [TagVersionPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_TagVersion_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [FK_TagVersion_Tag_Parent]
            FOREIGN KEY ([TagId]) REFERENCES [ATAPUtilities].[Tag] ([TagId]),
        CONSTRAINT [FK_TagVersion_TagVersion_Predecessor]
            FOREIGN KEY ([PredecessorTagVersionId], [TagId])
            REFERENCES [ATAPUtilities].[TagVersion] ([TagVersionId], [TagId]),
        CONSTRAINT [CK_TagVersion_RevisionSequence] CHECK ([RevisionSequence] > 0),
        CONSTRAINT [CK_TagVersion_DisplayLabel]
            CHECK (LEN(LTRIM(RTRIM([DisplayLabel]))) BETWEEN 1 AND 256),
        INDEX [IX_TagVersion_TagId] NONCLUSTERED ([TagId])
    );
END;

/* RDB-200 immutable assertions. The three assignment tables are
   table-addressable only under the superseding RDB-270/RDB-320 registry. */
IF OBJECT_ID(N'[ATAPUtilities].[EntityAuthorityAssignment]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[EntityAuthorityAssignment]
    (
        [EntityAuthorityAssignmentId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_EntityAuthorityAssignment] PRIMARY KEY,
        [AssignmentPhiloteId] uniqueidentifier NOT NULL,
        [RelationshipRolePolicyId] bigint NOT NULL,
        [AuthorityEndpointCode] varchar(32) NOT NULL,
        [AuthorityEntityId] bigint NOT NULL,
        [AuthorityEntityTypeId] bigint NOT NULL,
        [SubjectEndpointCode] varchar(32) NOT NULL,
        [SubjectEntityId] bigint NOT NULL,
        [SubjectEntityTypeId] bigint NOT NULL,
        [SupersedesAssignmentId] bigint NULL,
        [IsRetraction] bit NOT NULL,
        [ActorEndpointCode] varchar(32) NOT NULL,
        [AssertedByEntityId] bigint NOT NULL,
        [AssertedByEntityTypeId] bigint NOT NULL,
        [AssertedAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        [ClaimKey] AS
        (
            CONVERT(varchar(512), CONCAT(
                [RelationshipRolePolicyId], '|', [AuthorityEndpointCode], '|',
                [AuthorityEntityId], '|', [AuthorityEntityTypeId], '|',
                [SubjectEndpointCode], '|', [SubjectEntityId], '|', [SubjectEntityTypeId]
            ))
        ) PERSISTED,
        CONSTRAINT [UQ_EntityAuthorityAssignment_AssignmentPhiloteId]
            UNIQUE ([AssignmentPhiloteId]),
        INDEX [UQ_EntityAuthorityAssignment_SupersedesAssignmentId]
            UNIQUE NONCLUSTERED ([SupersedesAssignmentId])
            WHERE [SupersedesAssignmentId] IS NOT NULL,
        CONSTRAINT [UQ_EntityAuthorityAssignment_EntityAuthorityAssignmentId_ClaimKey]
            UNIQUE ([EntityAuthorityAssignmentId], [ClaimKey]),
        CONSTRAINT [FK_EntityAuthorityAssignment_RelationshipRolePolicy_Role]
            FOREIGN KEY ([RelationshipRolePolicyId])
            REFERENCES [ATAPUtilities].[RelationshipRolePolicy] ([RelationshipRolePolicyId]),
        CONSTRAINT [FK_EntityAuthorityAssignment_Entity_Authority]
            FOREIGN KEY ([AuthorityEntityId], [AuthorityEntityTypeId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_EntityAuthorityAssignment_Entity_Subject]
            FOREIGN KEY ([SubjectEntityId], [SubjectEntityTypeId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_EntityAuthorityAssignment_Entity_Actor]
            FOREIGN KEY ([AssertedByEntityId], [AssertedByEntityTypeId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_EntityAuthorityAssignment_RelationshipRoleEndpointEntityType_AuthorityPolicy]
            FOREIGN KEY ([RelationshipRolePolicyId], [AuthorityEndpointCode], [AuthorityEntityTypeId])
            REFERENCES [ATAPUtilities].[RelationshipRoleEndpointEntityType]
                ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId]),
        CONSTRAINT [FK_EntityAuthorityAssignment_RelationshipRoleEndpointEntityType_SubjectPolicy]
            FOREIGN KEY ([RelationshipRolePolicyId], [SubjectEndpointCode], [SubjectEntityTypeId])
            REFERENCES [ATAPUtilities].[RelationshipRoleEndpointEntityType]
                ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId]),
        CONSTRAINT [FK_EntityAuthorityAssignment_RelationshipRoleEndpointEntityType_ActorPolicy]
            FOREIGN KEY ([RelationshipRolePolicyId], [ActorEndpointCode], [AssertedByEntityTypeId])
            REFERENCES [ATAPUtilities].[RelationshipRoleEndpointEntityType]
                ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId]),
        CONSTRAINT [FK_EntityAuthorityAssignment_EntityAuthorityAssignment_PredecessorClaim]
            FOREIGN KEY ([SupersedesAssignmentId], [ClaimKey])
            REFERENCES [ATAPUtilities].[EntityAuthorityAssignment]
                ([EntityAuthorityAssignmentId], [ClaimKey]),
        CONSTRAINT [CK_EntityAuthorityAssignment_EndpointCodes]
            CHECK
            (
                [AuthorityEndpointCode] = 'authority'
                AND [SubjectEndpointCode] = 'subject'
                AND [ActorEndpointCode] = 'actor'
            ),
        CONSTRAINT [CK_EntityAuthorityAssignment_Timestamps]
            CHECK ([RecordedAtUtc] >= [AssertedAtUtc]),
        CONSTRAINT [CK_EntityAuthorityAssignment_RetractionLineage]
            CHECK
            (
                ([IsRetraction] = 0 OR [SupersedesAssignmentId] IS NOT NULL)
                AND ([SupersedesAssignmentId] IS NULL
                     OR [SupersedesAssignmentId] <> [EntityAuthorityAssignmentId])
            ),
        INDEX [IX_EntityAuthorityAssignment_AuthorityEntityId_AuthorityEntityTypeId]
            NONCLUSTERED ([AuthorityEntityId], [AuthorityEntityTypeId]),
        INDEX [IX_EntityAuthorityAssignment_SubjectEntityId_SubjectEntityTypeId]
            NONCLUSTERED ([SubjectEntityId], [SubjectEntityTypeId])
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[EntityExpertiseDomainAssignment]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[EntityExpertiseDomainAssignment]
    (
        [EntityExpertiseDomainAssignmentId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_EntityExpertiseDomainAssignment] PRIMARY KEY,
        [AssignmentPhiloteId] uniqueidentifier NOT NULL,
        [RelationshipRolePolicyId] bigint NOT NULL,
        [DomainEndpointCode] varchar(32) NOT NULL,
        [DomainEntityId] bigint NOT NULL,
        [DomainEntityTypeId] bigint NOT NULL,
        [SubjectEndpointCode] varchar(32) NOT NULL,
        [SubjectEntityId] bigint NOT NULL,
        [SubjectEntityTypeId] bigint NOT NULL,
        [SupersedesAssignmentId] bigint NULL,
        [IsRetraction] bit NOT NULL,
        [ActorEndpointCode] varchar(32) NOT NULL,
        [AssertedByEntityId] bigint NOT NULL,
        [AssertedByEntityTypeId] bigint NOT NULL,
        [AssertedAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        [ClaimKey] AS
        (
            CONVERT(varchar(512), CONCAT(
                [RelationshipRolePolicyId], '|', [DomainEndpointCode], '|',
                [DomainEntityId], '|', [DomainEntityTypeId], '|',
                [SubjectEndpointCode], '|', [SubjectEntityId], '|', [SubjectEntityTypeId]
            ))
        ) PERSISTED,
        CONSTRAINT [UQ_EntityExpertiseDomainAssignment_AssignmentPhiloteId]
            UNIQUE ([AssignmentPhiloteId]),
        INDEX [UQ_EntityExpertiseDomainAssignment_SupersedesAssignmentId]
            UNIQUE NONCLUSTERED ([SupersedesAssignmentId])
            WHERE [SupersedesAssignmentId] IS NOT NULL,
        CONSTRAINT [UQ_EntityExpertiseDomainAssignment_EntityExpertiseDomainAssignmentId_ClaimKey]
            UNIQUE ([EntityExpertiseDomainAssignmentId], [ClaimKey]),
        CONSTRAINT [FK_EntityExpertiseDomainAssignment_RelationshipRolePolicy_Role]
            FOREIGN KEY ([RelationshipRolePolicyId])
            REFERENCES [ATAPUtilities].[RelationshipRolePolicy] ([RelationshipRolePolicyId]),
        CONSTRAINT [FK_EntityExpertiseDomainAssignment_Entity_Domain]
            FOREIGN KEY ([DomainEntityId], [DomainEntityTypeId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_EntityExpertiseDomainAssignment_Entity_Subject]
            FOREIGN KEY ([SubjectEntityId], [SubjectEntityTypeId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_EntityExpertiseDomainAssignment_Entity_Actor]
            FOREIGN KEY ([AssertedByEntityId], [AssertedByEntityTypeId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_EntityExpertiseDomainAssignment_RelationshipRoleEndpointEntityType_DomainPolicy]
            FOREIGN KEY ([RelationshipRolePolicyId], [DomainEndpointCode], [DomainEntityTypeId])
            REFERENCES [ATAPUtilities].[RelationshipRoleEndpointEntityType]
                ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId]),
        CONSTRAINT [FK_EntityExpertiseDomainAssignment_RelationshipRoleEndpointEntityType_SubjectPolicy]
            FOREIGN KEY ([RelationshipRolePolicyId], [SubjectEndpointCode], [SubjectEntityTypeId])
            REFERENCES [ATAPUtilities].[RelationshipRoleEndpointEntityType]
                ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId]),
        CONSTRAINT [FK_EntityExpertiseDomainAssignment_RelationshipRoleEndpointEntityType_ActorPolicy]
            FOREIGN KEY ([RelationshipRolePolicyId], [ActorEndpointCode], [AssertedByEntityTypeId])
            REFERENCES [ATAPUtilities].[RelationshipRoleEndpointEntityType]
                ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId]),
        CONSTRAINT [FK_EntityExpertiseDomainAssignment_EntityExpertiseDomainAssignment_PredecessorClaim]
            FOREIGN KEY ([SupersedesAssignmentId], [ClaimKey])
            REFERENCES [ATAPUtilities].[EntityExpertiseDomainAssignment]
                ([EntityExpertiseDomainAssignmentId], [ClaimKey]),
        CONSTRAINT [CK_EntityExpertiseDomainAssignment_EndpointCodes]
            CHECK
            (
                [DomainEndpointCode] = 'domain'
                AND [SubjectEndpointCode] = 'subject'
                AND [ActorEndpointCode] = 'actor'
            ),
        CONSTRAINT [CK_EntityExpertiseDomainAssignment_Timestamps]
            CHECK ([RecordedAtUtc] >= [AssertedAtUtc]),
        CONSTRAINT [CK_EntityExpertiseDomainAssignment_RetractionLineage]
            CHECK
            (
                ([IsRetraction] = 0 OR [SupersedesAssignmentId] IS NOT NULL)
                AND ([SupersedesAssignmentId] IS NULL
                     OR [SupersedesAssignmentId] <> [EntityExpertiseDomainAssignmentId])
            ),
        INDEX [IX_EntityExpertiseDomainAssignment_DomainEntityId_DomainEntityTypeId]
            NONCLUSTERED ([DomainEntityId], [DomainEntityTypeId]),
        INDEX [IX_EntityExpertiseDomainAssignment_SubjectEntityId_SubjectEntityTypeId]
            NONCLUSTERED ([SubjectEntityId], [SubjectEntityTypeId])
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[TagAssignment]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[TagAssignment]
    (
        [TagAssignmentId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_TagAssignment] PRIMARY KEY,
        [TagAssignmentPhiloteId] uniqueidentifier NOT NULL,
        [RelationshipRolePolicyId] bigint NOT NULL,
        [TagEndpointCode] varchar(32) NOT NULL,
        [TagEntityId] bigint NOT NULL,
        [TagEntityTypeId] bigint NOT NULL,
        [SubjectEndpointCode] varchar(32) NOT NULL,
        [SubjectEntityId] bigint NOT NULL,
        [SubjectEntityTypeId] bigint NOT NULL,
        [SupersedesTagAssignmentId] bigint NULL,
        [IsRetraction] bit NOT NULL,
        [ActorEndpointCode] varchar(32) NOT NULL,
        [AssertedByEntityId] bigint NOT NULL,
        [AssertedByEntityTypeId] bigint NOT NULL,
        [AssertedAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        [ClaimKey] AS
        (
            CONVERT(varchar(512), CONCAT(
                [RelationshipRolePolicyId], '|', [TagEndpointCode], '|',
                [TagEntityId], '|', [TagEntityTypeId], '|',
                [SubjectEndpointCode], '|', [SubjectEntityId], '|', [SubjectEntityTypeId]
            ))
        ) PERSISTED,
        CONSTRAINT [UQ_TagAssignment_TagAssignmentPhiloteId]
            UNIQUE ([TagAssignmentPhiloteId]),
        INDEX [UQ_TagAssignment_SupersedesTagAssignmentId]
            UNIQUE NONCLUSTERED ([SupersedesTagAssignmentId])
            WHERE [SupersedesTagAssignmentId] IS NOT NULL,
        CONSTRAINT [UQ_TagAssignment_TagAssignmentId_ClaimKey]
            UNIQUE ([TagAssignmentId], [ClaimKey]),
        CONSTRAINT [FK_TagAssignment_RelationshipRolePolicy_Role]
            FOREIGN KEY ([RelationshipRolePolicyId])
            REFERENCES [ATAPUtilities].[RelationshipRolePolicy] ([RelationshipRolePolicyId]),
        CONSTRAINT [FK_TagAssignment_Entity_Tag]
            FOREIGN KEY ([TagEntityId], [TagEntityTypeId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_TagAssignment_Entity_Subject]
            FOREIGN KEY ([SubjectEntityId], [SubjectEntityTypeId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_TagAssignment_Entity_Actor]
            FOREIGN KEY ([AssertedByEntityId], [AssertedByEntityTypeId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_TagAssignment_RelationshipRoleEndpointEntityType_TagPolicy]
            FOREIGN KEY ([RelationshipRolePolicyId], [TagEndpointCode], [TagEntityTypeId])
            REFERENCES [ATAPUtilities].[RelationshipRoleEndpointEntityType]
                ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId]),
        CONSTRAINT [FK_TagAssignment_RelationshipRoleEndpointEntityType_SubjectPolicy]
            FOREIGN KEY ([RelationshipRolePolicyId], [SubjectEndpointCode], [SubjectEntityTypeId])
            REFERENCES [ATAPUtilities].[RelationshipRoleEndpointEntityType]
                ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId]),
        CONSTRAINT [FK_TagAssignment_RelationshipRoleEndpointEntityType_ActorPolicy]
            FOREIGN KEY ([RelationshipRolePolicyId], [ActorEndpointCode], [AssertedByEntityTypeId])
            REFERENCES [ATAPUtilities].[RelationshipRoleEndpointEntityType]
                ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId]),
        CONSTRAINT [FK_TagAssignment_TagAssignment_PredecessorClaim]
            FOREIGN KEY ([SupersedesTagAssignmentId], [ClaimKey])
            REFERENCES [ATAPUtilities].[TagAssignment] ([TagAssignmentId], [ClaimKey]),
        CONSTRAINT [CK_TagAssignment_EndpointCodes]
            CHECK
            (
                [TagEndpointCode] = 'tag'
                AND [SubjectEndpointCode] = 'subject'
                AND [ActorEndpointCode] = 'actor'
            ),
        CONSTRAINT [CK_TagAssignment_Timestamps]
            CHECK ([RecordedAtUtc] >= [AssertedAtUtc]),
        CONSTRAINT [CK_TagAssignment_RetractionLineage]
            CHECK
            (
                ([IsRetraction] = 0 OR [SupersedesTagAssignmentId] IS NOT NULL)
                AND ([SupersedesTagAssignmentId] IS NULL
                     OR [SupersedesTagAssignmentId] <> [TagAssignmentId])
            ),
        INDEX [IX_TagAssignment_TagEntityId_TagEntityTypeId]
            NONCLUSTERED ([TagEntityId], [TagEntityTypeId]),
        INDEX [IX_TagAssignment_SubjectEntityId_SubjectEntityTypeId]
            NONCLUSTERED ([SubjectEntityId], [SubjectEntityTypeId])
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[Attribution]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[Attribution]
    (
        [AttributionId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_Attribution] PRIMARY KEY,
        [AttributionPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'attribution')) PERSISTED,
        [RelationshipRolePolicyId] bigint NOT NULL,
        [AttributedEndpointCode] varchar(32) NOT NULL,
        [AttributedEntityId] bigint NOT NULL,
        [AttributedEntityTypeId] bigint NOT NULL,
        [SubjectEndpointCode] varchar(32) NOT NULL,
        [SubjectEntityId] bigint NOT NULL,
        [SubjectEntityTypeId] bigint NOT NULL,
        [EvidenceEndpointCode] varchar(32) NULL,
        [EvidenceEntityId] bigint NULL,
        [EvidenceEntityTypeId] bigint NULL,
        [SupersedesAttributionId] bigint NULL,
        [IsRetraction] bit NOT NULL,
        [ActorEndpointCode] varchar(32) NOT NULL,
        [AssertedByEntityId] bigint NOT NULL,
        [AssertedByEntityTypeId] bigint NOT NULL,
        [AssertedAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        [ReasonReference] nvarchar(2048) NULL,
        [ClaimKey] AS
        (
            CONVERT(varchar(768), CONCAT(
                [RelationshipRolePolicyId], '|', [AttributedEndpointCode], '|',
                [AttributedEntityId], '|', [AttributedEntityTypeId], '|',
                [SubjectEndpointCode], '|', [SubjectEntityId], '|', [SubjectEntityTypeId], '|',
                COALESCE([EvidenceEndpointCode], '<null>'), '|',
                COALESCE(CONVERT(varchar(20), [EvidenceEntityId]), '<null>'), '|',
                COALESCE(CONVERT(varchar(20), [EvidenceEntityTypeId]), '<null>')
            ))
        ) PERSISTED,
        CONSTRAINT [UQ_Attribution_AttributionPhiloteId] UNIQUE ([AttributionPhiloteId]),
        CONSTRAINT [UQ_Attribution_EntityId_EntityTypeId] UNIQUE ([EntityId], [EntityTypeId]),
        INDEX [UQ_Attribution_SupersedesAttributionId]
            UNIQUE NONCLUSTERED ([SupersedesAttributionId])
            WHERE [SupersedesAttributionId] IS NOT NULL,
        CONSTRAINT [UQ_Attribution_AttributionId_ClaimKey]
            UNIQUE ([AttributionId], [ClaimKey]),
        CONSTRAINT [FK_Attribution_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [AttributionPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_Attribution_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [FK_Attribution_RelationshipRolePolicy_Role]
            FOREIGN KEY ([RelationshipRolePolicyId])
            REFERENCES [ATAPUtilities].[RelationshipRolePolicy] ([RelationshipRolePolicyId]),
        CONSTRAINT [FK_Attribution_Entity_Attributed]
            FOREIGN KEY ([AttributedEntityId], [AttributedEntityTypeId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_Attribution_Entity_Subject]
            FOREIGN KEY ([SubjectEntityId], [SubjectEntityTypeId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_Attribution_Entity_Evidence]
            FOREIGN KEY ([EvidenceEntityId], [EvidenceEntityTypeId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_Attribution_Entity_Actor]
            FOREIGN KEY ([AssertedByEntityId], [AssertedByEntityTypeId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_Attribution_RelationshipRoleEndpointEntityType_AttributedPolicy]
            FOREIGN KEY ([RelationshipRolePolicyId], [AttributedEndpointCode], [AttributedEntityTypeId])
            REFERENCES [ATAPUtilities].[RelationshipRoleEndpointEntityType]
                ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId]),
        CONSTRAINT [FK_Attribution_RelationshipRoleEndpointEntityType_SubjectPolicy]
            FOREIGN KEY ([RelationshipRolePolicyId], [SubjectEndpointCode], [SubjectEntityTypeId])
            REFERENCES [ATAPUtilities].[RelationshipRoleEndpointEntityType]
                ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId]),
        CONSTRAINT [FK_Attribution_RelationshipRoleEndpointEntityType_EvidencePolicy]
            FOREIGN KEY ([RelationshipRolePolicyId], [EvidenceEndpointCode], [EvidenceEntityTypeId])
            REFERENCES [ATAPUtilities].[RelationshipRoleEndpointEntityType]
                ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId]),
        CONSTRAINT [FK_Attribution_RelationshipRoleEndpointEntityType_ActorPolicy]
            FOREIGN KEY ([RelationshipRolePolicyId], [ActorEndpointCode], [AssertedByEntityTypeId])
            REFERENCES [ATAPUtilities].[RelationshipRoleEndpointEntityType]
                ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId]),
        CONSTRAINT [FK_Attribution_Attribution_PredecessorClaim]
            FOREIGN KEY ([SupersedesAttributionId], [ClaimKey])
            REFERENCES [ATAPUtilities].[Attribution] ([AttributionId], [ClaimKey]),
        CONSTRAINT [CK_Attribution_EndpointCodes]
            CHECK
            (
                [AttributedEndpointCode] = 'attributed'
                AND [SubjectEndpointCode] = 'subject'
                AND [ActorEndpointCode] = 'actor'
                AND
                (
                    ([EvidenceEndpointCode] IS NULL
                     AND [EvidenceEntityId] IS NULL
                     AND [EvidenceEntityTypeId] IS NULL)
                    OR
                    ([EvidenceEndpointCode] = 'evidence'
                     AND [EvidenceEntityId] IS NOT NULL
                     AND [EvidenceEntityTypeId] IS NOT NULL)
                )
            ),
        CONSTRAINT [CK_Attribution_Timestamps]
            CHECK ([RecordedAtUtc] >= [AssertedAtUtc]),
        CONSTRAINT [CK_Attribution_RetractionLineage]
            CHECK
            (
                ([IsRetraction] = 0 OR [SupersedesAttributionId] IS NOT NULL)
                AND ([SupersedesAttributionId] IS NULL
                     OR [SupersedesAttributionId] <> [AttributionId])
            ),
        INDEX [IX_Attribution_AttributedEntityId_AttributedEntityTypeId]
            NONCLUSTERED ([AttributedEntityId], [AttributedEntityTypeId]),
        INDEX [IX_Attribution_SubjectEntityId_SubjectEntityTypeId]
            NONCLUSTERED ([SubjectEntityId], [SubjectEntityTypeId])
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[AttributionDispute]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[AttributionDispute]
    (
        [AttributionDisputeId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_AttributionDispute] PRIMARY KEY,
        [AttributionDisputePhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'attribution-dispute')) PERSISTED,
        [AttributionId] bigint NOT NULL,
        [DisputeActorRolePolicyId] bigint NOT NULL,
        [RaisedByEndpointCode] varchar(32) NOT NULL,
        [RaisedByEntityId] bigint NOT NULL,
        [RaisedByEntityTypeId] bigint NOT NULL,
        [AuthorityEntityId] bigint NOT NULL,
        [AuthorityEntityTypeId] bigint NOT NULL,
        [RaisedAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        [ReasonReference] nvarchar(2048) NOT NULL,
        CONSTRAINT [UQ_AttributionDispute_AttributionDisputePhiloteId]
            UNIQUE ([AttributionDisputePhiloteId]),
        CONSTRAINT [UQ_AttributionDispute_EntityId_EntityTypeId]
            UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_AttributionDispute_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [AttributionDisputePhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_AttributionDispute_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [FK_AttributionDispute_Attribution_DisputedAssertion]
            FOREIGN KEY ([AttributionId])
            REFERENCES [ATAPUtilities].[Attribution] ([AttributionId]),
        CONSTRAINT [FK_AttributionDispute_RelationshipRolePolicy_ActorRole]
            FOREIGN KEY ([DisputeActorRolePolicyId])
            REFERENCES [ATAPUtilities].[RelationshipRolePolicy] ([RelationshipRolePolicyId]),
        CONSTRAINT [FK_AttributionDispute_Entity_RaisedBy]
            FOREIGN KEY ([RaisedByEntityId], [RaisedByEntityTypeId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_AttributionDispute_RelationshipRoleEndpointEntityType_RaisedByPolicy]
            FOREIGN KEY ([DisputeActorRolePolicyId], [RaisedByEndpointCode], [RaisedByEntityTypeId])
            REFERENCES [ATAPUtilities].[RelationshipRoleEndpointEntityType]
                ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId]),
        CONSTRAINT [FK_AttributionDispute_AuthorityVersion_GoverningAuthority]
            FOREIGN KEY ([AuthorityEntityId], [AuthorityEntityTypeId])
            REFERENCES [ATAPUtilities].[AuthorityVersion] ([EntityId], [EntityTypeId]),
        CONSTRAINT [CK_AttributionDispute_RaisedByEndpointCode]
            CHECK ([RaisedByEndpointCode] = 'raised-by'),
        CONSTRAINT [CK_AttributionDispute_Timestamps]
            CHECK ([RecordedAtUtc] >= [RaisedAtUtc]),
        CONSTRAINT [CK_AttributionDispute_ReasonReference]
            CHECK (LEN(LTRIM(RTRIM([ReasonReference]))) BETWEEN 1 AND 2048),
        INDEX [IX_AttributionDispute_AttributionId] NONCLUSTERED ([AttributionId])
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[AttributionDisputeEvent]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[AttributionDisputeEvent]
    (
        [AttributionDisputeEventId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_AttributionDisputeEvent] PRIMARY KEY,
        [AttributionDisputeEventPhiloteId] uniqueidentifier NOT NULL,
        [AttributionDisputeId] bigint NOT NULL,
        [EventSequence] int NOT NULL,
        [StatusCode] varchar(32) NOT NULL,
        [OutcomeCode] varchar(32) NULL,
        [CorrectedAttributionId] bigint NULL,
        [EventActorRolePolicyId] bigint NOT NULL,
        [ActingEndpointCode] varchar(32) NOT NULL,
        [ActingEntityId] bigint NOT NULL,
        [ActingEntityTypeId] bigint NOT NULL,
        [AuthorityEntityId] bigint NOT NULL,
        [AuthorityEntityTypeId] bigint NOT NULL,
        [OccurredAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        [ReasonReference] nvarchar(2048) NOT NULL,
        CONSTRAINT [UQ_AttributionDisputeEvent_AttributionDisputeEventPhiloteId]
            UNIQUE ([AttributionDisputeEventPhiloteId]),
        CONSTRAINT [UQ_AttributionDisputeEvent_AttributionDisputeId_EventSequence]
            UNIQUE ([AttributionDisputeId], [EventSequence]),
        CONSTRAINT [FK_AttributionDisputeEvent_AttributionDispute_Parent]
            FOREIGN KEY ([AttributionDisputeId])
            REFERENCES [ATAPUtilities].[AttributionDispute] ([AttributionDisputeId]),
        CONSTRAINT [FK_AttributionDisputeEvent_Attribution_CorrectedResult]
            FOREIGN KEY ([CorrectedAttributionId])
            REFERENCES [ATAPUtilities].[Attribution] ([AttributionId]),
        CONSTRAINT [FK_AttributionDisputeEvent_RelationshipRolePolicy_ActorRole]
            FOREIGN KEY ([EventActorRolePolicyId])
            REFERENCES [ATAPUtilities].[RelationshipRolePolicy] ([RelationshipRolePolicyId]),
        CONSTRAINT [FK_AttributionDisputeEvent_Entity_Acting]
            FOREIGN KEY ([ActingEntityId], [ActingEntityTypeId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_AttributionDisputeEvent_RelationshipRoleEndpointEntityType_ActingPolicy]
            FOREIGN KEY ([EventActorRolePolicyId], [ActingEndpointCode], [ActingEntityTypeId])
            REFERENCES [ATAPUtilities].[RelationshipRoleEndpointEntityType]
                ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId]),
        CONSTRAINT [FK_AttributionDisputeEvent_AuthorityVersion_GoverningAuthority]
            FOREIGN KEY ([AuthorityEntityId], [AuthorityEntityTypeId])
            REFERENCES [ATAPUtilities].[AuthorityVersion] ([EntityId], [EntityTypeId]),
        CONSTRAINT [CK_AttributionDisputeEvent_EventSequence]
            CHECK ([EventSequence] > 0),
        CONSTRAINT [CK_AttributionDisputeEvent_StatusOutcome]
            CHECK
            (
                [StatusCode] IN ('Raised', 'UnderReview', 'Resolved', 'Withdrawn')
                AND
                (
                    ([StatusCode] <> 'Resolved' AND [OutcomeCode] IS NULL
                     AND [CorrectedAttributionId] IS NULL)
                    OR
                    ([StatusCode] = 'Resolved'
                     AND [OutcomeCode] IN ('Upheld', 'Rejected')
                     AND [CorrectedAttributionId] IS NULL)
                    OR
                    ([StatusCode] = 'Resolved'
                     AND [OutcomeCode] = 'Corrected'
                     AND [CorrectedAttributionId] IS NOT NULL)
                )
            ),
        CONSTRAINT [CK_AttributionDisputeEvent_ActingEndpointCode]
            CHECK ([ActingEndpointCode] = 'acting'),
        CONSTRAINT [CK_AttributionDisputeEvent_Timestamps]
            CHECK ([RecordedAtUtc] >= [OccurredAtUtc]),
        CONSTRAINT [CK_AttributionDisputeEvent_ReasonReference]
            CHECK (LEN(LTRIM(RTRIM([ReasonReference]))) BETWEEN 1 AND 2048),
        INDEX [IX_AttributionDisputeEvent_CorrectedAttributionId]
            NONCLUSTERED ([CorrectedAttributionId])
    );
END;

/* RDB-410 finite catalogs. */
IF OBJECT_ID(N'[ATAPUtilities].[ExecutionClassification]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[ExecutionClassification]
    (
        [ExecutionClassificationCode] varchar(32) NOT NULL
            CONSTRAINT [PK_ExecutionClassification] PRIMARY KEY,
        [AllowsExecutorContract] bit NOT NULL,
        [RequiresPlanApproval] bit NOT NULL,
        [AllowsSideEffects] bit NOT NULL,
        [RequiresObservationOnly] bit NOT NULL,
        [RequiresFrozenOutput] bit NOT NULL,
        CONSTRAINT [UQ_ExecutionClassification_ExecutionClassificationCode_AllowsExecutorContract]
            UNIQUE ([ExecutionClassificationCode], [AllowsExecutorContract]),
        CONSTRAINT [CK_ExecutionClassification_Code]
            CHECK
            (
                [ExecutionClassificationCode] IN
                (
                    'deterministic', 'approved-ai-directed', 'observational',
                    'metadata-only', 'prohibited'
                )
            ),
        CONSTRAINT [CK_ExecutionClassification_FailClosed]
            CHECK
            (
                ([AllowsSideEffects] = 0 OR [AllowsExecutorContract] = 1)
                AND
                ([RequiresObservationOnly] = 0
                 OR ([AllowsExecutorContract] = 1 AND [AllowsSideEffects] = 0))
                AND
                ([ExecutionClassificationCode] NOT IN ('metadata-only', 'prohibited')
                 OR ([AllowsExecutorContract] = 0 AND [AllowsSideEffects] = 0))
            )
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[SecurityCapabilityClassification]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[SecurityCapabilityClassification]
    (
        [SecurityCapabilityCode] varchar(64) NOT NULL
            CONSTRAINT [PK_SecurityCapabilityClassification] PRIMARY KEY,
        [IsDefaultDeny] bit NOT NULL,
        [RequiresSeparateApproval] bit NOT NULL,
        CONSTRAINT [CK_SecurityCapabilityClassification_Code]
            CHECK
            (
                [SecurityCapabilityCode] IN
                (
                    'reference-safe', 'security-sensitive',
                    'offensive-metadata-only', 'legal-metadata-only',
                    'financial-metadata-only', 'prohibited'
                )
            ),
        CONSTRAINT [CK_SecurityCapabilityClassification_DefaultDeny]
            CHECK ([IsDefaultDeny] = CONVERT(bit, 1))
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[RoundTripPolicy]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[RoundTripPolicy]
    (
        [RoundTripPolicyCode] varchar(32) NOT NULL
            CONSTRAINT [PK_RoundTripPolicy] PRIMARY KEY,
        [RequiresByteHash] bit NOT NULL,
        [RequiresCanonicalization] bit NOT NULL,
        [RequiresFrozenObservation] bit NOT NULL,
        CONSTRAINT [CK_RoundTripPolicy_Code]
            CHECK
            (
                [RoundTripPolicyCode] IN
                ('byte-identical', 'semantic-equivalent', 'observational-freeze', 'not-applicable')
            )
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[ScalarStorageKind]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[ScalarStorageKind]
    (
        [ScalarStorageKindCode] varchar(64) NOT NULL
            CONSTRAINT [PK_ScalarStorageKind] PRIMARY KEY,
        [RelationalRepresentationCode] varchar(128) NOT NULL,
        [CanonicalSerializationCode] varchar(128) NOT NULL,
        CONSTRAINT [CK_ScalarStorageKind_Codes]
            CHECK
            (
                LEN(LTRIM(RTRIM([ScalarStorageKindCode]))) BETWEEN 1 AND 64
                AND LEN(LTRIM(RTRIM([RelationalRepresentationCode]))) BETWEEN 1 AND 128
                AND LEN(LTRIM(RTRIM([CanonicalSerializationCode]))) BETWEEN 1 AND 128
            )
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[SecretReferencePolicy]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[SecretReferencePolicy]
    (
        [SecretReferencePolicyId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_SecretReferencePolicy] PRIMARY KEY,
        [SecretReferencePolicyCode] varchar(64) NOT NULL,
        [ResolverCode] varchar(64) NOT NULL,
        [SecretNameSyntaxPolicyCode] varchar(64) NOT NULL,
        [AllowsNonSecretSelector] bit NOT NULL,
        [AllowsNameInPlanHash] bit NOT NULL,
        [ResolveDuringPublication] bit NOT NULL,
        CONSTRAINT [UQ_SecretReferencePolicy_SecretReferencePolicyCode]
            UNIQUE ([SecretReferencePolicyCode]),
        CONSTRAINT [CK_SecretReferencePolicy_ResolverCode]
            CHECK ([ResolverCode] = 'Get-SecretATAP'),
        CONSTRAINT [CK_SecretReferencePolicy_NoPublicationResolution]
            CHECK ([ResolveDuringPublication] = CONVERT(bit, 0)),
        CONSTRAINT [CK_SecretReferencePolicy_Codes]
            CHECK
            (
                LEN(LTRIM(RTRIM([SecretReferencePolicyCode]))) BETWEEN 1 AND 64
                AND LEN(LTRIM(RTRIM([SecretNameSyntaxPolicyCode]))) BETWEEN 1 AND 64
            )
    );
END;

/* Executor contracts. */
IF OBJECT_ID(N'[ATAPUtilities].[ExecutorContract]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[ExecutorContract]
    (
        [ExecutorContractId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_ExecutorContract] PRIMARY KEY,
        [ExecutorContractPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'executor-contract')) PERSISTED,
        [ExecutorContractCode] varchar(128) NOT NULL,
        [CreatedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_ExecutorContract_ExecutorContractPhiloteId]
            UNIQUE ([ExecutorContractPhiloteId]),
        CONSTRAINT [UQ_ExecutorContract_ExecutorContractCode]
            UNIQUE ([ExecutorContractCode]),
        CONSTRAINT [UQ_ExecutorContract_EntityId_EntityTypeId]
            UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_ExecutorContract_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [ExecutorContractPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_ExecutorContract_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [CK_ExecutorContract_ExecutorContractCode]
            CHECK (LEN(LTRIM(RTRIM([ExecutorContractCode]))) BETWEEN 1 AND 128)
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[ExecutorContractVersion]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[ExecutorContractVersion]
    (
        [ExecutorContractVersionId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_ExecutorContractVersion] PRIMARY KEY,
        [ExecutorContractVersionPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'executor-contract-version')) PERSISTED,
        [ExecutorContractId] bigint NOT NULL,
        [RevisionSequence] int NOT NULL,
        [PredecessorExecutorContractVersionId] bigint NULL,
        [ContractSchemaVersion] varchar(64) NOT NULL,
        [ExecutorInterfaceCode] varchar(128) NOT NULL,
        [ExecutorInterfaceVersion] varchar(64) NOT NULL,
        [EffectPolicyCode] varchar(64) NOT NULL,
        [EnvironmentContractCode] varchar(64) NOT NULL,
        [ValidationContractCode] varchar(64) NOT NULL,
        [PublishedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_ExecutorContractVersion_ExecutorContractVersionPhiloteId]
            UNIQUE ([ExecutorContractVersionPhiloteId]),
        CONSTRAINT [UQ_ExecutorContractVersion_EntityId_EntityTypeId]
            UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [UQ_ExecutorContractVersion_ExecutorContractVersionId_ExecutorContractId]
            UNIQUE ([ExecutorContractVersionId], [ExecutorContractId]),
        CONSTRAINT [UQ_ExecutorContractVersion_ExecutorContractId_RevisionSequence]
            UNIQUE ([ExecutorContractId], [RevisionSequence]),
        INDEX [UQ_ExecutorContractVersion_PredecessorExecutorContractVersionId]
            UNIQUE NONCLUSTERED ([PredecessorExecutorContractVersionId])
            WHERE [PredecessorExecutorContractVersionId] IS NOT NULL,
        CONSTRAINT [FK_ExecutorContractVersion_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [ExecutorContractVersionPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_ExecutorContractVersion_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [FK_ExecutorContractVersion_ExecutorContract_Parent]
            FOREIGN KEY ([ExecutorContractId])
            REFERENCES [ATAPUtilities].[ExecutorContract] ([ExecutorContractId]),
        CONSTRAINT [FK_ExecutorContractVersion_ExecutorContractVersion_Predecessor]
            FOREIGN KEY ([PredecessorExecutorContractVersionId], [ExecutorContractId])
            REFERENCES [ATAPUtilities].[ExecutorContractVersion]
                ([ExecutorContractVersionId], [ExecutorContractId]),
        CONSTRAINT [CK_ExecutorContractVersion_RevisionSequence]
            CHECK ([RevisionSequence] > 0),
        CONSTRAINT [CK_ExecutorContractVersion_RequiredCodes]
            CHECK
            (
                LEN(LTRIM(RTRIM([ContractSchemaVersion]))) BETWEEN 1 AND 64
                AND LEN(LTRIM(RTRIM([ExecutorInterfaceCode]))) BETWEEN 1 AND 128
                AND LEN(LTRIM(RTRIM([ExecutorInterfaceVersion]))) BETWEEN 1 AND 64
                AND LEN(LTRIM(RTRIM([EffectPolicyCode]))) BETWEEN 1 AND 64
                AND LEN(LTRIM(RTRIM([EnvironmentContractCode]))) BETWEEN 1 AND 64
                AND LEN(LTRIM(RTRIM([ValidationContractCode]))) BETWEEN 1 AND 64
            ),
        INDEX [IX_ExecutorContractVersion_ExecutorContractId]
            NONCLUSTERED ([ExecutorContractId])
    );
END;

/* RuleKind and immutable interpretation versions. */
IF OBJECT_ID(N'[ATAPUtilities].[RuleKind]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[RuleKind]
    (
        [RuleKindId] bigint IDENTITY(1, 1) NOT NULL CONSTRAINT [PK_RuleKind] PRIMARY KEY,
        [RuleKindPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'rule-kind')) PERSISTED,
        [RuleKindCode] varchar(128) NOT NULL,
        [CreatedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_RuleKind_RuleKindPhiloteId] UNIQUE ([RuleKindPhiloteId]),
        CONSTRAINT [UQ_RuleKind_RuleKindCode] UNIQUE ([RuleKindCode]),
        CONSTRAINT [UQ_RuleKind_EntityId_EntityTypeId] UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_RuleKind_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [RuleKindPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_RuleKind_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [CK_RuleKind_RuleKindCode]
            CHECK (LEN(LTRIM(RTRIM([RuleKindCode]))) BETWEEN 1 AND 128)
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[RuleKindVersion]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[RuleKindVersion]
    (
        [RuleKindVersionId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_RuleKindVersion] PRIMARY KEY,
        [RuleKindVersionPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'rule-kind-version')) PERSISTED,
        [RuleKindId] bigint NOT NULL,
        [RevisionSequence] int NOT NULL,
        [PredecessorRuleKindVersionId] bigint NULL,
        [GrammarSourceArtifactVersionId] bigint NOT NULL,
        [GrammarHashAlgorithmCode] varchar(32) NOT NULL,
        [GrammarContentHash] varbinary(64) NOT NULL,
        [CompendiumSourceArtifactVersionId] bigint NOT NULL,
        [CompendiumHashAlgorithmCode] varchar(32) NOT NULL,
        [CompendiumContentHash] varbinary(64) NOT NULL,
        [ExecutorContractVersionId] bigint NULL,
        [ExecutionClassificationCode] varchar(32) NOT NULL,
        [HasExecutorContract] AS
            (CONVERT(bit, CASE WHEN [ExecutorContractVersionId] IS NULL THEN 0 ELSE 1 END)) PERSISTED,
        [SecurityCapabilityCode] varchar(64) NOT NULL,
        [RoundTripPolicyCode] varchar(32) NOT NULL,
        [PublishedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_RuleKindVersion_RuleKindVersionPhiloteId]
            UNIQUE ([RuleKindVersionPhiloteId]),
        CONSTRAINT [UQ_RuleKindVersion_EntityId_EntityTypeId]
            UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [UQ_RuleKindVersion_RuleKindVersionId_RuleKindId]
            UNIQUE ([RuleKindVersionId], [RuleKindId]),
        CONSTRAINT [UQ_RuleKindVersion_RuleKindId_RevisionSequence]
            UNIQUE ([RuleKindId], [RevisionSequence]),
        INDEX [UQ_RuleKindVersion_PredecessorRuleKindVersionId]
            UNIQUE NONCLUSTERED ([PredecessorRuleKindVersionId])
            WHERE [PredecessorRuleKindVersionId] IS NOT NULL,
        CONSTRAINT [FK_RuleKindVersion_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [RuleKindVersionPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_RuleKindVersion_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [FK_RuleKindVersion_RuleKind_Parent]
            FOREIGN KEY ([RuleKindId]) REFERENCES [ATAPUtilities].[RuleKind] ([RuleKindId]),
        CONSTRAINT [FK_RuleKindVersion_RuleKindVersion_Predecessor]
            FOREIGN KEY ([PredecessorRuleKindVersionId], [RuleKindId])
            REFERENCES [ATAPUtilities].[RuleKindVersion] ([RuleKindVersionId], [RuleKindId]),
        CONSTRAINT [FK_RuleKindVersion_ExecutorContractVersion_Executor]
            FOREIGN KEY ([ExecutorContractVersionId])
            REFERENCES [ATAPUtilities].[ExecutorContractVersion] ([ExecutorContractVersionId]),
        CONSTRAINT [FK_RuleKindVersion_ExecutionClassification_Classification]
            FOREIGN KEY ([ExecutionClassificationCode], [HasExecutorContract])
            REFERENCES [ATAPUtilities].[ExecutionClassification]
                ([ExecutionClassificationCode], [AllowsExecutorContract]),
        CONSTRAINT [FK_RuleKindVersion_SecurityCapabilityClassification_Capability]
            FOREIGN KEY ([SecurityCapabilityCode])
            REFERENCES [ATAPUtilities].[SecurityCapabilityClassification] ([SecurityCapabilityCode]),
        CONSTRAINT [FK_RuleKindVersion_RoundTripPolicy_RoundTrip]
            FOREIGN KEY ([RoundTripPolicyCode])
            REFERENCES [ATAPUtilities].[RoundTripPolicy] ([RoundTripPolicyCode]),
        CONSTRAINT [CK_RuleKindVersion_RevisionSequence] CHECK ([RevisionSequence] > 0),
        CONSTRAINT [CK_RuleKindVersion_Hashes]
            CHECK
            (
                LEN(LTRIM(RTRIM([GrammarHashAlgorithmCode]))) BETWEEN 1 AND 32
                AND DATALENGTH([GrammarContentHash]) > 0
                AND LEN(LTRIM(RTRIM([CompendiumHashAlgorithmCode]))) BETWEEN 1 AND 32
                AND DATALENGTH([CompendiumContentHash]) > 0
            ),
        INDEX [IX_RuleKindVersion_RuleKindId] NONCLUSTERED ([RuleKindId]),
        INDEX [IX_RuleKindVersion_GrammarSourceArtifactVersionId]
            NONCLUSTERED ([GrammarSourceArtifactVersionId]),
        INDEX [IX_RuleKindVersion_CompendiumSourceArtifactVersionId]
            NONCLUSTERED ([CompendiumSourceArtifactVersionId])
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[RuleKindVersionCompatibility]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[RuleKindVersionCompatibility]
    (
        [FromRuleKindVersionId] bigint NOT NULL,
        [ToRuleKindVersionId] bigint NOT NULL,
        [RuleKindId] bigint NOT NULL,
        [CompatibilityDispositionCode] varchar(32) NOT NULL,
        [EvidenceEntityId] bigint NOT NULL,
        [EvidenceEntityTypeId] bigint NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_RuleKindVersionCompatibility]
            PRIMARY KEY ([FromRuleKindVersionId], [ToRuleKindVersionId]),
        CONSTRAINT [FK_RuleKindVersionCompatibility_RuleKindVersion_From]
            FOREIGN KEY ([FromRuleKindVersionId], [RuleKindId])
            REFERENCES [ATAPUtilities].[RuleKindVersion] ([RuleKindVersionId], [RuleKindId]),
        CONSTRAINT [FK_RuleKindVersionCompatibility_RuleKindVersion_To]
            FOREIGN KEY ([ToRuleKindVersionId], [RuleKindId])
            REFERENCES [ATAPUtilities].[RuleKindVersion] ([RuleKindVersionId], [RuleKindId]),
        CONSTRAINT [FK_RuleKindVersionCompatibility_Entity_Evidence]
            FOREIGN KEY ([EvidenceEntityId], [EvidenceEntityTypeId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
        CONSTRAINT [CK_RuleKindVersionCompatibility_DistinctVersions]
            CHECK ([FromRuleKindVersionId] <> [ToRuleKindVersionId]),
        CONSTRAINT [CK_RuleKindVersionCompatibility_Disposition]
            CHECK
            (
                [CompatibilityDispositionCode] IN
                ('byte-compatible', 'semantic-compatible', 'conversion-required', 'incompatible')
            ),
        INDEX [IX_RuleKindVersionCompatibility_ToRuleKindVersionId_RuleKindId]
            NONCLUSTERED ([ToRuleKindVersionId], [RuleKindId]),
        INDEX [IX_RuleKindVersionCompatibility_EvidenceEntityId_EvidenceEntityTypeId]
            NONCLUSTERED ([EvidenceEntityId], [EvidenceEntityTypeId])
    );
END;

/* Versioned structured-value contracts. */
IF OBJECT_ID(N'[ATAPUtilities].[StructuredValueContract]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[StructuredValueContract]
    (
        [StructuredValueContractId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_StructuredValueContract] PRIMARY KEY,
        [StructuredValueContractPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'structured-value-contract')) PERSISTED,
        [StructuredValueContractCode] varchar(128) NOT NULL,
        [CreatedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_StructuredValueContract_StructuredValueContractPhiloteId]
            UNIQUE ([StructuredValueContractPhiloteId]),
        CONSTRAINT [UQ_StructuredValueContract_StructuredValueContractCode]
            UNIQUE ([StructuredValueContractCode]),
        CONSTRAINT [UQ_StructuredValueContract_EntityId_EntityTypeId]
            UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_StructuredValueContract_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [StructuredValueContractPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_StructuredValueContract_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [CK_StructuredValueContract_StructuredValueContractCode]
            CHECK (LEN(LTRIM(RTRIM([StructuredValueContractCode]))) BETWEEN 1 AND 128)
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[StructuredValueContractVersion]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[StructuredValueContractVersion]
    (
        [StructuredValueContractVersionId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_StructuredValueContractVersion] PRIMARY KEY,
        [StructuredValueContractVersionPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'structured-value-contract-version')) PERSISTED,
        [StructuredValueContractId] bigint NOT NULL,
        [RevisionSequence] int NOT NULL,
        [PredecessorContractVersionId] bigint NULL,
        [ContractSchemaVersion] varchar(64) NOT NULL,
        [SerializerContextCode] varchar(256) NOT NULL,
        [DtoTypeCode] varchar(256) NOT NULL,
        [ValidationContractCode] varchar(64) NOT NULL,
        [CanonicalizationPolicyCode] varchar(64) NOT NULL,
        [FixtureContentHash] varbinary(64) NOT NULL,
        [PublishedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_StructuredValueContractVersion_StructuredValueContractVersionPhiloteId]
            UNIQUE ([StructuredValueContractVersionPhiloteId]),
        CONSTRAINT [UQ_StructuredValueContractVersion_EntityId_EntityTypeId]
            UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [UQ_StructuredValueContractVersion_StructuredValueContractVersionId_StructuredValueContractId]
            UNIQUE ([StructuredValueContractVersionId], [StructuredValueContractId]),
        CONSTRAINT [UQ_StructuredValueContractVersion_StructuredValueContractId_RevisionSequence]
            UNIQUE ([StructuredValueContractId], [RevisionSequence]),
        CONSTRAINT [UQ_StructuredValueContractVersion_StructuredValueContractId_ContractSchemaVersion]
            UNIQUE ([StructuredValueContractId], [ContractSchemaVersion]),
        INDEX [UQ_StructuredValueContractVersion_PredecessorContractVersionId]
            UNIQUE NONCLUSTERED ([PredecessorContractVersionId])
            WHERE [PredecessorContractVersionId] IS NOT NULL,
        CONSTRAINT [FK_StructuredValueContractVersion_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [StructuredValueContractVersionPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_StructuredValueContractVersion_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [FK_StructuredValueContractVersion_StructuredValueContract_Parent]
            FOREIGN KEY ([StructuredValueContractId])
            REFERENCES [ATAPUtilities].[StructuredValueContract] ([StructuredValueContractId]),
        CONSTRAINT [FK_StructuredValueContractVersion_StructuredValueContractVersion_Predecessor]
            FOREIGN KEY ([PredecessorContractVersionId], [StructuredValueContractId])
            REFERENCES [ATAPUtilities].[StructuredValueContractVersion]
                ([StructuredValueContractVersionId], [StructuredValueContractId]),
        CONSTRAINT [CK_StructuredValueContractVersion_RevisionSequence]
            CHECK ([RevisionSequence] > 0),
        CONSTRAINT [CK_StructuredValueContractVersion_RequiredContractFields]
            CHECK
            (
                LEN(LTRIM(RTRIM([ContractSchemaVersion]))) BETWEEN 1 AND 64
                AND LEN(LTRIM(RTRIM([SerializerContextCode]))) BETWEEN 1 AND 256
                AND LEN(LTRIM(RTRIM([DtoTypeCode]))) BETWEEN 1 AND 256
                AND LEN(LTRIM(RTRIM([ValidationContractCode]))) BETWEEN 1 AND 64
                AND LEN(LTRIM(RTRIM([CanonicalizationPolicyCode]))) BETWEEN 1 AND 64
                AND DATALENGTH([FixtureContentHash]) > 0
            ),
        INDEX [IX_StructuredValueContractVersion_StructuredValueContractId]
            NONCLUSTERED ([StructuredValueContractId])
    );
END;

/* ValueType roots and exact category shapes. */
IF OBJECT_ID(N'[ATAPUtilities].[ValueType]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[ValueType]
    (
        [ValueTypeId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_ValueType] PRIMARY KEY,
        [ValueTypePhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'value-type')) PERSISTED,
        [ValueTypeCode] varchar(128) NOT NULL,
        [CreatedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_ValueType_ValueTypePhiloteId] UNIQUE ([ValueTypePhiloteId]),
        CONSTRAINT [UQ_ValueType_ValueTypeCode] UNIQUE ([ValueTypeCode]),
        CONSTRAINT [UQ_ValueType_EntityId_EntityTypeId] UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [FK_ValueType_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [ValueTypePhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_ValueType_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [CK_ValueType_ValueTypeCode]
            CHECK (LEN(LTRIM(RTRIM([ValueTypeCode]))) BETWEEN 1 AND 128)
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[ValueTypeVersion]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[ValueTypeVersion]
    (
        [ValueTypeVersionId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_ValueTypeVersion] PRIMARY KEY,
        [ValueTypeVersionPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'value-type-version')) PERSISTED,
        [ValueTypeId] bigint NOT NULL,
        [RevisionSequence] int NOT NULL,
        [PredecessorValueTypeVersionId] bigint NULL,
        [ValueCategoryCode] varchar(32) NOT NULL,
        [ScalarStorageKindCode] varchar(64) NULL,
        [StructuredValueContractVersionId] bigint NULL,
        [ElementValueTypeVersionId] bigint NULL,
        [CollectionOrderingCode] varchar(32) NULL,
        [SecretReferencePolicyId] bigint NULL,
        [ValidationContractCode] varchar(64) NOT NULL,
        [PublishedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_ValueTypeVersion_ValueTypeVersionPhiloteId]
            UNIQUE ([ValueTypeVersionPhiloteId]),
        CONSTRAINT [UQ_ValueTypeVersion_EntityId_EntityTypeId]
            UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [UQ_ValueTypeVersion_ValueTypeVersionId_ValueTypeId]
            UNIQUE ([ValueTypeVersionId], [ValueTypeId]),
        CONSTRAINT [UQ_ValueTypeVersion_ValueTypeVersionId_ValueCategoryCode]
            UNIQUE ([ValueTypeVersionId], [ValueCategoryCode]),
        CONSTRAINT [UQ_ValueTypeVersion_ValueTypeId_RevisionSequence]
            UNIQUE ([ValueTypeId], [RevisionSequence]),
        INDEX [UQ_ValueTypeVersion_PredecessorValueTypeVersionId]
            UNIQUE NONCLUSTERED ([PredecessorValueTypeVersionId])
            WHERE [PredecessorValueTypeVersionId] IS NOT NULL,
        CONSTRAINT [FK_ValueTypeVersion_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [ValueTypeVersionPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_ValueTypeVersion_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [FK_ValueTypeVersion_ValueType_Parent]
            FOREIGN KEY ([ValueTypeId]) REFERENCES [ATAPUtilities].[ValueType] ([ValueTypeId]),
        CONSTRAINT [FK_ValueTypeVersion_ValueTypeVersion_Predecessor]
            FOREIGN KEY ([PredecessorValueTypeVersionId], [ValueTypeId])
            REFERENCES [ATAPUtilities].[ValueTypeVersion] ([ValueTypeVersionId], [ValueTypeId]),
        CONSTRAINT [FK_ValueTypeVersion_ScalarStorageKind_ScalarShape]
            FOREIGN KEY ([ScalarStorageKindCode])
            REFERENCES [ATAPUtilities].[ScalarStorageKind] ([ScalarStorageKindCode]),
        CONSTRAINT [FK_ValueTypeVersion_StructuredValueContractVersion_StructuredShape]
            FOREIGN KEY ([StructuredValueContractVersionId])
            REFERENCES [ATAPUtilities].[StructuredValueContractVersion]
                ([StructuredValueContractVersionId]),
        CONSTRAINT [FK_ValueTypeVersion_ValueTypeVersion_ElementType]
            FOREIGN KEY ([ElementValueTypeVersionId])
            REFERENCES [ATAPUtilities].[ValueTypeVersion] ([ValueTypeVersionId]),
        CONSTRAINT [FK_ValueTypeVersion_SecretReferencePolicy_SecretShape]
            FOREIGN KEY ([SecretReferencePolicyId])
            REFERENCES [ATAPUtilities].[SecretReferencePolicy] ([SecretReferencePolicyId]),
        CONSTRAINT [CK_ValueTypeVersion_RevisionSequence] CHECK ([RevisionSequence] > 0),
        CONSTRAINT [CK_ValueTypeVersion_ValueCategoryCode]
            CHECK
            (
                [ValueCategoryCode] IN
                ('scalar', 'structured', 'collection', 'secret-reference', 'entity-reference')
            ),
        CONSTRAINT [CK_ValueTypeVersion_ExactlyOneCategoryShape]
            CHECK
            (
                ([ValueCategoryCode] = 'scalar'
                 AND [ScalarStorageKindCode] IS NOT NULL
                 AND [StructuredValueContractVersionId] IS NULL
                 AND [ElementValueTypeVersionId] IS NULL
                 AND [CollectionOrderingCode] IS NULL
                 AND [SecretReferencePolicyId] IS NULL)
                OR
                ([ValueCategoryCode] = 'structured'
                 AND [ScalarStorageKindCode] IS NULL
                 AND [StructuredValueContractVersionId] IS NOT NULL
                 AND [ElementValueTypeVersionId] IS NULL
                 AND [CollectionOrderingCode] IS NULL
                 AND [SecretReferencePolicyId] IS NULL)
                OR
                ([ValueCategoryCode] = 'collection'
                 AND [ScalarStorageKindCode] IS NULL
                 AND [StructuredValueContractVersionId] IS NULL
                 AND [ElementValueTypeVersionId] IS NOT NULL
                 AND [CollectionOrderingCode] IS NOT NULL
                 AND [SecretReferencePolicyId] IS NULL)
                OR
                ([ValueCategoryCode] = 'secret-reference'
                 AND [ScalarStorageKindCode] IS NULL
                 AND [StructuredValueContractVersionId] IS NULL
                 AND [ElementValueTypeVersionId] IS NULL
                 AND [CollectionOrderingCode] IS NULL
                 AND [SecretReferencePolicyId] IS NOT NULL)
                OR
                ([ValueCategoryCode] = 'entity-reference'
                 AND [ScalarStorageKindCode] IS NULL
                 AND [StructuredValueContractVersionId] IS NULL
                 AND [ElementValueTypeVersionId] IS NULL
                 AND [CollectionOrderingCode] IS NULL
                 AND [SecretReferencePolicyId] IS NULL)
            ),
        CONSTRAINT [CK_ValueTypeVersion_NoDirectCollectionCycle]
            CHECK
            (
                [ElementValueTypeVersionId] IS NULL
                OR [ElementValueTypeVersionId] <> [ValueTypeVersionId]
            ),
        CONSTRAINT [CK_ValueTypeVersion_ValidationContractCode]
            CHECK (LEN(LTRIM(RTRIM([ValidationContractCode]))) BETWEEN 1 AND 64),
        INDEX [IX_ValueTypeVersion_ValueTypeId] NONCLUSTERED ([ValueTypeId]),
        INDEX [IX_ValueTypeVersion_StructuredValueContractVersionId]
            NONCLUSTERED ([StructuredValueContractVersionId]),
        INDEX [IX_ValueTypeVersion_ElementValueTypeVersionId]
            NONCLUSTERED ([ElementValueTypeVersionId])
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[ValueTypeAllowedEntityType]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[ValueTypeAllowedEntityType]
    (
        [ValueTypeVersionId] bigint NOT NULL,
        [ValueCategoryCode] AS (CONVERT(varchar(32), 'entity-reference')) PERSISTED,
        [EntityTypeId] bigint NOT NULL,
        CONSTRAINT [PK_ValueTypeAllowedEntityType]
            PRIMARY KEY ([ValueTypeVersionId], [EntityTypeId]),
        CONSTRAINT [FK_ValueTypeAllowedEntityType_ValueTypeVersion_EntityReferenceShape]
            FOREIGN KEY ([ValueTypeVersionId], [ValueCategoryCode])
            REFERENCES [ATAPUtilities].[ValueTypeVersion]
                ([ValueTypeVersionId], [ValueCategoryCode]),
        CONSTRAINT [FK_ValueTypeAllowedEntityType_EntityType_AllowedType]
            FOREIGN KEY ([EntityTypeId])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId]),
        INDEX [IX_ValueTypeAllowedEntityType_EntityTypeId]
            NONCLUSTERED ([EntityTypeId])
    );
END;

/* Primitive durable identity and immutable versions. */
IF OBJECT_ID(N'[ATAPUtilities].[Primitive]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[Primitive]
    (
        [PrimitiveId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_Primitive] PRIMARY KEY,
        [PrimitivePhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'primitive')) PERSISTED,
        [RuleKindId] bigint NOT NULL,
        [PrimitiveCode] varchar(128) NOT NULL,
        [CreatedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_Primitive_PrimitivePhiloteId] UNIQUE ([PrimitivePhiloteId]),
        CONSTRAINT [UQ_Primitive_EntityId_EntityTypeId] UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [UQ_Primitive_PrimitiveId_RuleKindId]
            UNIQUE ([PrimitiveId], [RuleKindId]),
        CONSTRAINT [UQ_Primitive_RuleKindId_PrimitiveCode]
            UNIQUE ([RuleKindId], [PrimitiveCode]),
        CONSTRAINT [FK_Primitive_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [PrimitivePhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_Primitive_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [FK_Primitive_RuleKind_Owner]
            FOREIGN KEY ([RuleKindId]) REFERENCES [ATAPUtilities].[RuleKind] ([RuleKindId]),
        CONSTRAINT [CK_Primitive_PrimitiveCode]
            CHECK (LEN(LTRIM(RTRIM([PrimitiveCode]))) BETWEEN 1 AND 128),
        INDEX [IX_Primitive_RuleKindId] NONCLUSTERED ([RuleKindId])
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[PrimitiveVersion]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[PrimitiveVersion]
    (
        [PrimitiveVersionId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_PrimitiveVersion] PRIMARY KEY,
        [PrimitiveVersionPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'primitive-version')) PERSISTED,
        [PrimitiveId] bigint NOT NULL,
        [RuleKindId] bigint NOT NULL,
        [RuleKindVersionId] bigint NOT NULL,
        [RevisionSequence] int NOT NULL,
        [PredecessorPrimitiveVersionId] bigint NULL,
        [GrammarProductionCode] varchar(128) NOT NULL,
        [DefinitionText] nvarchar(max) NOT NULL,
        [DefinitionHashAlgorithmCode] varchar(32) NOT NULL,
        [DefinitionContentHash] varbinary(64) NOT NULL,
        [OutputValueTypeVersionId] bigint NOT NULL,
        [OutputMinCardinality] int NOT NULL,
        [OutputMaxCardinality] int NULL,
        [PublishedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [UQ_PrimitiveVersion_PrimitiveVersionPhiloteId]
            UNIQUE ([PrimitiveVersionPhiloteId]),
        CONSTRAINT [UQ_PrimitiveVersion_EntityId_EntityTypeId]
            UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [UQ_PrimitiveVersion_PrimitiveVersionId_PrimitiveId]
            UNIQUE ([PrimitiveVersionId], [PrimitiveId]),
        CONSTRAINT [UQ_PrimitiveVersion_PrimitiveVersionId_RuleKindVersionId]
            UNIQUE ([PrimitiveVersionId], [RuleKindVersionId]),
        CONSTRAINT [UQ_PrimitiveVersion_PrimitiveId_RevisionSequence]
            UNIQUE ([PrimitiveId], [RevisionSequence]),
        INDEX [UQ_PrimitiveVersion_PredecessorPrimitiveVersionId]
            UNIQUE NONCLUSTERED ([PredecessorPrimitiveVersionId])
            WHERE [PredecessorPrimitiveVersionId] IS NOT NULL,
        CONSTRAINT [FK_PrimitiveVersion_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [PrimitiveVersionPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_PrimitiveVersion_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [FK_PrimitiveVersion_Primitive_SameKindParent]
            FOREIGN KEY ([PrimitiveId], [RuleKindId])
            REFERENCES [ATAPUtilities].[Primitive] ([PrimitiveId], [RuleKindId]),
        CONSTRAINT [FK_PrimitiveVersion_RuleKindVersion_ExactSameKind]
            FOREIGN KEY ([RuleKindVersionId], [RuleKindId])
            REFERENCES [ATAPUtilities].[RuleKindVersion] ([RuleKindVersionId], [RuleKindId]),
        CONSTRAINT [FK_PrimitiveVersion_PrimitiveVersion_Predecessor]
            FOREIGN KEY ([PredecessorPrimitiveVersionId], [PrimitiveId])
            REFERENCES [ATAPUtilities].[PrimitiveVersion] ([PrimitiveVersionId], [PrimitiveId]),
        CONSTRAINT [FK_PrimitiveVersion_ValueTypeVersion_OutputType]
            FOREIGN KEY ([OutputValueTypeVersionId])
            REFERENCES [ATAPUtilities].[ValueTypeVersion] ([ValueTypeVersionId]),
        CONSTRAINT [CK_PrimitiveVersion_RevisionSequence] CHECK ([RevisionSequence] > 0),
        CONSTRAINT [CK_PrimitiveVersion_OutputCardinality]
            CHECK
            (
                [OutputMinCardinality] >= 0
                AND ([OutputMaxCardinality] IS NULL
                     OR [OutputMaxCardinality] >= [OutputMinCardinality])
            ),
        CONSTRAINT [CK_PrimitiveVersion_Definition]
            CHECK
            (
                LEN(LTRIM(RTRIM([GrammarProductionCode]))) BETWEEN 1 AND 128
                AND LEN([DefinitionText]) > 0
                AND LEN(LTRIM(RTRIM([DefinitionHashAlgorithmCode]))) BETWEEN 1 AND 32
                AND DATALENGTH([DefinitionContentHash]) > 0
            ),
        INDEX [IX_PrimitiveVersion_PrimitiveId] NONCLUSTERED ([PrimitiveId]),
        INDEX [IX_PrimitiveVersion_RuleKindVersionId_RuleKindId]
            NONCLUSTERED ([RuleKindVersionId], [RuleKindId]),
        INDEX [IX_PrimitiveVersion_OutputValueTypeVersionId]
            NONCLUSTERED ([OutputValueTypeVersionId])
    );
END;

IF OBJECT_ID(N'[ATAPUtilities].[PrimitiveInputDefinition]', N'U') IS NULL
BEGIN
    CREATE TABLE [ATAPUtilities].[PrimitiveInputDefinition]
    (
        [PrimitiveInputDefinitionId] bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT [PK_PrimitiveInputDefinition] PRIMARY KEY,
        [PrimitiveInputDefinitionPhiloteId] uniqueidentifier NOT NULL,
        [EntityId] bigint NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        [EntityTypeCode] AS (CONVERT(varchar(64), 'primitive-input-definition')) PERSISTED,
        [PrimitiveVersionId] bigint NOT NULL,
        [InputCode] varchar(128) NOT NULL,
        [Ordinal] int NOT NULL,
        [ValueTypeVersionId] bigint NOT NULL,
        [MinCardinality] int NOT NULL,
        [MaxCardinality] int NULL,
        [AllowsNullElement] bit NOT NULL,
        [ValidationContractCode] varchar(64) NOT NULL,
        CONSTRAINT [UQ_PrimitiveInputDefinition_PrimitiveInputDefinitionPhiloteId]
            UNIQUE ([PrimitiveInputDefinitionPhiloteId]),
        CONSTRAINT [UQ_PrimitiveInputDefinition_EntityId_EntityTypeId]
            UNIQUE ([EntityId], [EntityTypeId]),
        CONSTRAINT [UQ_PrimitiveInputDefinition_PrimitiveVersionId_InputCode]
            UNIQUE ([PrimitiveVersionId], [InputCode]),
        CONSTRAINT [UQ_PrimitiveInputDefinition_PrimitiveVersionId_Ordinal]
            UNIQUE ([PrimitiveVersionId], [Ordinal]),
        CONSTRAINT [UQ_PrimitiveInputDefinition_PrimitiveInputDefinitionId_PrimitiveVersionId_ValueTypeVersionId]
            UNIQUE ([PrimitiveInputDefinitionId], [PrimitiveVersionId], [ValueTypeVersionId]),
        CONSTRAINT [FK_PrimitiveInputDefinition_Entity_Registration]
            FOREIGN KEY ([EntityId], [EntityTypeId], [PrimitiveInputDefinitionPhiloteId])
            REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
        CONSTRAINT [FK_PrimitiveInputDefinition_EntityType_ExactType]
            FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
            REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
        CONSTRAINT [FK_PrimitiveInputDefinition_PrimitiveVersion_Owner]
            FOREIGN KEY ([PrimitiveVersionId])
            REFERENCES [ATAPUtilities].[PrimitiveVersion] ([PrimitiveVersionId]),
        CONSTRAINT [FK_PrimitiveInputDefinition_ValueTypeVersion_InputType]
            FOREIGN KEY ([ValueTypeVersionId])
            REFERENCES [ATAPUtilities].[ValueTypeVersion] ([ValueTypeVersionId]),
        CONSTRAINT [CK_PrimitiveInputDefinition_Ordinal]
            CHECK ([Ordinal] >= 0),
        CONSTRAINT [CK_PrimitiveInputDefinition_Cardinality]
            CHECK
            (
                [MinCardinality] >= 0
                AND ([MaxCardinality] IS NULL OR [MaxCardinality] >= [MinCardinality])
            ),
        CONSTRAINT [CK_PrimitiveInputDefinition_Codes]
            CHECK
            (
                LEN(LTRIM(RTRIM([InputCode]))) BETWEEN 1 AND 128
                AND LEN(LTRIM(RTRIM([ValidationContractCode]))) BETWEEN 1 AND 64
            ),
        INDEX [IX_PrimitiveInputDefinition_ValueTypeVersionId]
            NONCLUSTERED ([ValueTypeVersionId])
    );
END;

/*
  Physical publication guards required by the RDB-200/RDB-210 contracts.

  RDB-480 must register these trigger names under the RDB-320 amendment rule.
  The metadata-driven bodies below are closed over explicit table/column lists;
  they do not discover or mutate arbitrary schema objects.
*/
EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_AuthorityVersion_LineageImmutable]
ON [ATAPUtilities].[AuthorityVersion]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51401, ''Published version rows are immutable.'', 1;

    DECLARE @LineageLockCount bigint;
    SELECT @LineageLockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[AuthorityVersion] AS [existing]
        WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN
    (
        SELECT DISTINCT [AuthorityId]
        FROM inserted
    ) AS [affected]
        ON [affected].[AuthorityId] = [existing].[AuthorityId];

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        WHERE ([RevisionSequence] = 1 AND [PredecessorAuthorityVersionId] IS NOT NULL)
           OR ([RevisionSequence] > 1 AND [PredecessorAuthorityVersionId] IS NULL)
    )
        THROW 51402, ''Revision one must be the only root; every later revision requires a predecessor.'', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS [candidate]
        LEFT JOIN [ATAPUtilities].[AuthorityVersion] AS [predecessor]
            ON [predecessor].[AuthorityVersionId] = [candidate].[PredecessorAuthorityVersionId]
           AND [predecessor].[AuthorityId] = [candidate].[AuthorityId]
        WHERE [candidate].[RevisionSequence] > 1
          AND
          (
              [predecessor].[AuthorityVersionId] IS NULL
              OR [candidate].[RevisionSequence] <> [predecessor].[RevisionSequence] + 1
          )
    )
        THROW 51403, ''A successor must be the contiguous next revision of its exact predecessor.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_ExpertVersion_LineageImmutable]
ON [ATAPUtilities].[ExpertVersion]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51401, ''Published version rows are immutable.'', 1;

    DECLARE @LineageLockCount bigint;
    SELECT @LineageLockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[ExpertVersion] AS [existing]
        WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN
    (
        SELECT DISTINCT [ExpertId]
        FROM inserted
    ) AS [affected]
        ON [affected].[ExpertId] = [existing].[ExpertId];

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        WHERE ([RevisionSequence] = 1 AND [PredecessorExpertVersionId] IS NOT NULL)
           OR ([RevisionSequence] > 1 AND [PredecessorExpertVersionId] IS NULL)
    )
        THROW 51402, ''Revision one must be the only root; every later revision requires a predecessor.'', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS [candidate]
        LEFT JOIN [ATAPUtilities].[ExpertVersion] AS [predecessor]
            ON [predecessor].[ExpertVersionId] = [candidate].[PredecessorExpertVersionId]
           AND [predecessor].[ExpertId] = [candidate].[ExpertId]
        WHERE [candidate].[RevisionSequence] > 1
          AND
          (
              [predecessor].[ExpertVersionId] IS NULL
              OR [candidate].[RevisionSequence] <> [predecessor].[RevisionSequence] + 1
          )
    )
        THROW 51403, ''A successor must be the contiguous next revision of its exact predecessor.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_ExpertiseDomainVersion_LineageImmutable]
ON [ATAPUtilities].[ExpertiseDomainVersion]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51401, ''Published version rows are immutable.'', 1;

    DECLARE @LineageLockCount bigint;
    SELECT @LineageLockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[ExpertiseDomainVersion] AS [existing]
        WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN
    (
        SELECT DISTINCT [ExpertiseDomainId]
        FROM inserted
    ) AS [affected]
        ON [affected].[ExpertiseDomainId] = [existing].[ExpertiseDomainId];

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        WHERE ([RevisionSequence] = 1 AND [PredecessorExpertiseDomainVersionId] IS NOT NULL)
           OR ([RevisionSequence] > 1 AND [PredecessorExpertiseDomainVersionId] IS NULL)
    )
        THROW 51402, ''Revision one must be the only root; every later revision requires a predecessor.'', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS [candidate]
        LEFT JOIN [ATAPUtilities].[ExpertiseDomainVersion] AS [predecessor]
            ON [predecessor].[ExpertiseDomainVersionId] = [candidate].[PredecessorExpertiseDomainVersionId]
           AND [predecessor].[ExpertiseDomainId] = [candidate].[ExpertiseDomainId]
        WHERE [candidate].[RevisionSequence] > 1
          AND
          (
              [predecessor].[ExpertiseDomainVersionId] IS NULL
              OR [candidate].[RevisionSequence] <> [predecessor].[RevisionSequence] + 1
          )
    )
        THROW 51403, ''A successor must be the contiguous next revision of its exact predecessor.'', 1;

    DECLARE @HasHierarchyCycle bit = CONVERT(bit, 0);
    ;WITH [HierarchyPath] AS
    (
        SELECT [candidate].[ExpertiseDomainVersionId] AS [StartVersionId],
               [candidate].[ParentExpertiseDomainVersionId] AS [NextVersionId]
        FROM inserted AS [candidate]
        WHERE [candidate].[ParentExpertiseDomainVersionId] IS NOT NULL

        UNION ALL

        SELECT [path].[StartVersionId], [parent].[ParentExpertiseDomainVersionId]
        FROM [HierarchyPath] AS [path]
        INNER JOIN [ATAPUtilities].[ExpertiseDomainVersion] AS [parent]
            ON [parent].[ExpertiseDomainVersionId] = [path].[NextVersionId]
        WHERE [path].[NextVersionId] <> [path].[StartVersionId]
          AND [parent].[ParentExpertiseDomainVersionId] IS NOT NULL
    )
    SELECT TOP (1) @HasHierarchyCycle = CONVERT(bit, 1)
    FROM [HierarchyPath]
    WHERE [NextVersionId] = [StartVersionId]
    OPTION (MAXRECURSION 32767);

    IF @HasHierarchyCycle = CONVERT(bit, 1)
        THROW 51404, ''ExpertiseDomain hierarchy cycles are prohibited.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_TagVersion_LineageImmutable]
ON [ATAPUtilities].[TagVersion]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51401, ''Published version rows are immutable.'', 1;

    DECLARE @LineageLockCount bigint;
    SELECT @LineageLockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[TagVersion] AS [existing]
        WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN
    (
        SELECT DISTINCT [TagId]
        FROM inserted
    ) AS [affected]
        ON [affected].[TagId] = [existing].[TagId];

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        WHERE ([RevisionSequence] = 1 AND [PredecessorTagVersionId] IS NOT NULL)
           OR ([RevisionSequence] > 1 AND [PredecessorTagVersionId] IS NULL)
    )
        THROW 51402, ''Revision one must be the only root; every later revision requires a predecessor.'', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS [candidate]
        LEFT JOIN [ATAPUtilities].[TagVersion] AS [predecessor]
            ON [predecessor].[TagVersionId] = [candidate].[PredecessorTagVersionId]
           AND [predecessor].[TagId] = [candidate].[TagId]
        WHERE [candidate].[RevisionSequence] > 1
          AND
          (
              [predecessor].[TagVersionId] IS NULL
              OR [candidate].[RevisionSequence] <> [predecessor].[RevisionSequence] + 1
          )
    )
        THROW 51403, ''A successor must be the contiguous next revision of its exact predecessor.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_ExecutorContractVersion_LineageImmutable]
ON [ATAPUtilities].[ExecutorContractVersion]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51401, ''Published version rows are immutable.'', 1;

    DECLARE @LineageLockCount bigint;
    SELECT @LineageLockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[ExecutorContractVersion] AS [existing]
        WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN
    (
        SELECT DISTINCT [ExecutorContractId]
        FROM inserted
    ) AS [affected]
        ON [affected].[ExecutorContractId] = [existing].[ExecutorContractId];

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        WHERE ([RevisionSequence] = 1 AND [PredecessorExecutorContractVersionId] IS NOT NULL)
           OR ([RevisionSequence] > 1 AND [PredecessorExecutorContractVersionId] IS NULL)
    )
        THROW 51402, ''Revision one must be the only root; every later revision requires a predecessor.'', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS [candidate]
        LEFT JOIN [ATAPUtilities].[ExecutorContractVersion] AS [predecessor]
            ON [predecessor].[ExecutorContractVersionId] = [candidate].[PredecessorExecutorContractVersionId]
           AND [predecessor].[ExecutorContractId] = [candidate].[ExecutorContractId]
        WHERE [candidate].[RevisionSequence] > 1
          AND
          (
              [predecessor].[ExecutorContractVersionId] IS NULL
              OR [candidate].[RevisionSequence] <> [predecessor].[RevisionSequence] + 1
          )
    )
        THROW 51403, ''A successor must be the contiguous next revision of its exact predecessor.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_RuleKindVersion_LineageImmutable]
ON [ATAPUtilities].[RuleKindVersion]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51401, ''Published version rows are immutable.'', 1;

    DECLARE @LineageLockCount bigint;
    SELECT @LineageLockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[RuleKindVersion] AS [existing]
        WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN
    (
        SELECT DISTINCT [RuleKindId]
        FROM inserted
    ) AS [affected]
        ON [affected].[RuleKindId] = [existing].[RuleKindId];

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        WHERE ([RevisionSequence] = 1 AND [PredecessorRuleKindVersionId] IS NOT NULL)
           OR ([RevisionSequence] > 1 AND [PredecessorRuleKindVersionId] IS NULL)
    )
        THROW 51402, ''Revision one must be the only root; every later revision requires a predecessor.'', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS [candidate]
        LEFT JOIN [ATAPUtilities].[RuleKindVersion] AS [predecessor]
            ON [predecessor].[RuleKindVersionId] = [candidate].[PredecessorRuleKindVersionId]
           AND [predecessor].[RuleKindId] = [candidate].[RuleKindId]
        WHERE [candidate].[RevisionSequence] > 1
          AND
          (
              [predecessor].[RuleKindVersionId] IS NULL
              OR [candidate].[RevisionSequence] <> [predecessor].[RevisionSequence] + 1
          )
    )
        THROW 51403, ''A successor must be the contiguous next revision of its exact predecessor.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_StructuredValueContractVersion_LineageImmutable]
ON [ATAPUtilities].[StructuredValueContractVersion]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51401, ''Published version rows are immutable.'', 1;

    DECLARE @LineageLockCount bigint;
    SELECT @LineageLockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[StructuredValueContractVersion] AS [existing]
        WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN
    (
        SELECT DISTINCT [StructuredValueContractId]
        FROM inserted
    ) AS [affected]
        ON [affected].[StructuredValueContractId] = [existing].[StructuredValueContractId];

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        WHERE ([RevisionSequence] = 1 AND [PredecessorContractVersionId] IS NOT NULL)
           OR ([RevisionSequence] > 1 AND [PredecessorContractVersionId] IS NULL)
    )
        THROW 51402, ''Revision one must be the only root; every later revision requires a predecessor.'', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS [candidate]
        LEFT JOIN [ATAPUtilities].[StructuredValueContractVersion] AS [predecessor]
            ON [predecessor].[StructuredValueContractVersionId] = [candidate].[PredecessorContractVersionId]
           AND [predecessor].[StructuredValueContractId] = [candidate].[StructuredValueContractId]
        WHERE [candidate].[RevisionSequence] > 1
          AND
          (
              [predecessor].[StructuredValueContractVersionId] IS NULL
              OR [candidate].[RevisionSequence] <> [predecessor].[RevisionSequence] + 1
          )
    )
        THROW 51403, ''A successor must be the contiguous next revision of its exact predecessor.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_ValueTypeVersion_LineageImmutable]
ON [ATAPUtilities].[ValueTypeVersion]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51401, ''Published version rows are immutable.'', 1;

    DECLARE @LineageLockCount bigint;
    SELECT @LineageLockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[ValueTypeVersion] AS [existing]
        WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN
    (
        SELECT DISTINCT [ValueTypeId]
        FROM inserted
    ) AS [affected]
        ON [affected].[ValueTypeId] = [existing].[ValueTypeId];

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        WHERE ([RevisionSequence] = 1 AND [PredecessorValueTypeVersionId] IS NOT NULL)
           OR ([RevisionSequence] > 1 AND [PredecessorValueTypeVersionId] IS NULL)
    )
        THROW 51402, ''Revision one must be the only root; every later revision requires a predecessor.'', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS [candidate]
        LEFT JOIN [ATAPUtilities].[ValueTypeVersion] AS [predecessor]
            ON [predecessor].[ValueTypeVersionId] = [candidate].[PredecessorValueTypeVersionId]
           AND [predecessor].[ValueTypeId] = [candidate].[ValueTypeId]
        WHERE [candidate].[RevisionSequence] > 1
          AND
          (
              [predecessor].[ValueTypeVersionId] IS NULL
              OR [candidate].[RevisionSequence] <> [predecessor].[RevisionSequence] + 1
          )
    )
        THROW 51403, ''A successor must be the contiguous next revision of its exact predecessor.'', 1;

    DECLARE @HasCollectionCycle bit = CONVERT(bit, 0);
    ;WITH [CollectionPath] AS
    (
        SELECT [candidate].[ValueTypeVersionId] AS [StartVersionId],
               [candidate].[ElementValueTypeVersionId] AS [NextVersionId]
        FROM inserted AS [candidate]
        WHERE [candidate].[ElementValueTypeVersionId] IS NOT NULL

        UNION ALL

        SELECT [path].[StartVersionId], [element].[ElementValueTypeVersionId]
        FROM [CollectionPath] AS [path]
        INNER JOIN [ATAPUtilities].[ValueTypeVersion] AS [element]
            ON [element].[ValueTypeVersionId] = [path].[NextVersionId]
        WHERE [path].[NextVersionId] <> [path].[StartVersionId]
          AND [element].[ElementValueTypeVersionId] IS NOT NULL
    )
    SELECT TOP (1) @HasCollectionCycle = CONVERT(bit, 1)
    FROM [CollectionPath]
    WHERE [NextVersionId] = [StartVersionId]
    OPTION (MAXRECURSION 32767);

    IF @HasCollectionCycle = CONVERT(bit, 1)
        THROW 51405, ''Recursive ValueType collection cycles are prohibited.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_PrimitiveVersion_LineageImmutable]
ON [ATAPUtilities].[PrimitiveVersion]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51401, ''Published version rows are immutable.'', 1;

    DECLARE @LineageLockCount bigint;
    SELECT @LineageLockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[PrimitiveVersion] AS [existing]
        WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN
    (
        SELECT DISTINCT [PrimitiveId]
        FROM inserted
    ) AS [affected]
        ON [affected].[PrimitiveId] = [existing].[PrimitiveId];

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        WHERE ([RevisionSequence] = 1 AND [PredecessorPrimitiveVersionId] IS NOT NULL)
           OR ([RevisionSequence] > 1 AND [PredecessorPrimitiveVersionId] IS NULL)
    )
        THROW 51402, ''Revision one must be the only root; every later revision requires a predecessor.'', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS [candidate]
        LEFT JOIN [ATAPUtilities].[PrimitiveVersion] AS [predecessor]
            ON [predecessor].[PrimitiveVersionId] = [candidate].[PredecessorPrimitiveVersionId]
           AND [predecessor].[PrimitiveId] = [candidate].[PrimitiveId]
        WHERE [candidate].[RevisionSequence] > 1
          AND
          (
              [predecessor].[PrimitiveVersionId] IS NULL
              OR [candidate].[RevisionSequence] <> [predecessor].[RevisionSequence] + 1
          )
    )
        THROW 51403, ''A successor must be the contiguous next revision of its exact predecessor.'', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS [candidate]
        INNER JOIN [ATAPUtilities].[PrimitiveVersion] AS [predecessor]
            ON [predecessor].[PrimitiveVersionId]
             = [candidate].[PredecessorPrimitiveVersionId]
        WHERE [predecessor].[RuleKindVersionId] <> [candidate].[RuleKindVersionId]
          AND NOT EXISTS
          (
              SELECT 1
              FROM [ATAPUtilities].[RuleKindVersionCompatibility] AS [compatibility]
              WHERE [compatibility].[FromRuleKindVersionId]
                    = [predecessor].[RuleKindVersionId]
                AND [compatibility].[ToRuleKindVersionId]
                    = [candidate].[RuleKindVersionId]
                AND [compatibility].[RuleKindId] = [candidate].[RuleKindId]
                AND [compatibility].[CompatibilityDispositionCode] IN
                    (''byte-compatible'', ''semantic-compatible'', ''conversion-required'')
          )
    )
        THROW 51406, ''A PrimitiveVersion kind-version change requires an approved forward compatibility decision.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_EntityAuthorityAssignment_LineageImmutable]
ON [ATAPUtilities].[EntityAuthorityAssignment]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51420, ''Published assertion rows are immutable.'', 1;

    DECLARE @ClaimLockCount bigint;
    SELECT @ClaimLockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[EntityAuthorityAssignment] AS [existing]
        WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN
    (
        SELECT DISTINCT [ClaimKey]
        FROM inserted
    ) AS [affected]
        ON [affected].[ClaimKey] = [existing].[ClaimKey];

    DECLARE @HasAssertionCycle bit = CONVERT(bit, 0);
    ;WITH [AssertionPath] AS
    (
        SELECT [candidate].[EntityAuthorityAssignmentId] AS [StartAssertionId],
               [candidate].[SupersedesAssignmentId] AS [NextAssertionId]
        FROM inserted AS [candidate]
        WHERE [candidate].[SupersedesAssignmentId] IS NOT NULL

        UNION ALL

        SELECT [path].[StartAssertionId],
               [predecessor].[SupersedesAssignmentId]
        FROM [AssertionPath] AS [path]
        INNER JOIN [ATAPUtilities].[EntityAuthorityAssignment] AS [predecessor]
            ON [predecessor].[EntityAuthorityAssignmentId] = [path].[NextAssertionId]
        WHERE [path].[NextAssertionId] <> [path].[StartAssertionId]
          AND [predecessor].[SupersedesAssignmentId] IS NOT NULL
    )
    SELECT TOP (1) @HasAssertionCycle = CONVERT(bit, 1)
    FROM [AssertionPath]
    WHERE [NextAssertionId] = [StartAssertionId]
    OPTION (MAXRECURSION 32767);

    IF @HasAssertionCycle = CONVERT(bit, 1)
        THROW 51421, ''Assertion predecessor cycles are prohibited.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_EntityExpertiseDomainAssignment_LineageImmutable]
ON [ATAPUtilities].[EntityExpertiseDomainAssignment]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51420, ''Published assertion rows are immutable.'', 1;

    DECLARE @ClaimLockCount bigint;
    SELECT @ClaimLockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[EntityExpertiseDomainAssignment] AS [existing]
        WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN
    (
        SELECT DISTINCT [ClaimKey]
        FROM inserted
    ) AS [affected]
        ON [affected].[ClaimKey] = [existing].[ClaimKey];

    DECLARE @HasAssertionCycle bit = CONVERT(bit, 0);
    ;WITH [AssertionPath] AS
    (
        SELECT [candidate].[EntityExpertiseDomainAssignmentId] AS [StartAssertionId],
               [candidate].[SupersedesAssignmentId] AS [NextAssertionId]
        FROM inserted AS [candidate]
        WHERE [candidate].[SupersedesAssignmentId] IS NOT NULL

        UNION ALL

        SELECT [path].[StartAssertionId],
               [predecessor].[SupersedesAssignmentId]
        FROM [AssertionPath] AS [path]
        INNER JOIN [ATAPUtilities].[EntityExpertiseDomainAssignment] AS [predecessor]
            ON [predecessor].[EntityExpertiseDomainAssignmentId] = [path].[NextAssertionId]
        WHERE [path].[NextAssertionId] <> [path].[StartAssertionId]
          AND [predecessor].[SupersedesAssignmentId] IS NOT NULL
    )
    SELECT TOP (1) @HasAssertionCycle = CONVERT(bit, 1)
    FROM [AssertionPath]
    WHERE [NextAssertionId] = [StartAssertionId]
    OPTION (MAXRECURSION 32767);

    IF @HasAssertionCycle = CONVERT(bit, 1)
        THROW 51421, ''Assertion predecessor cycles are prohibited.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_TagAssignment_LineageImmutable]
ON [ATAPUtilities].[TagAssignment]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51420, ''Published assertion rows are immutable.'', 1;

    DECLARE @ClaimLockCount bigint;
    SELECT @ClaimLockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[TagAssignment] AS [existing]
        WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN
    (
        SELECT DISTINCT [ClaimKey]
        FROM inserted
    ) AS [affected]
        ON [affected].[ClaimKey] = [existing].[ClaimKey];

    DECLARE @HasAssertionCycle bit = CONVERT(bit, 0);
    ;WITH [AssertionPath] AS
    (
        SELECT [candidate].[TagAssignmentId] AS [StartAssertionId],
               [candidate].[SupersedesTagAssignmentId] AS [NextAssertionId]
        FROM inserted AS [candidate]
        WHERE [candidate].[SupersedesTagAssignmentId] IS NOT NULL

        UNION ALL

        SELECT [path].[StartAssertionId],
               [predecessor].[SupersedesTagAssignmentId]
        FROM [AssertionPath] AS [path]
        INNER JOIN [ATAPUtilities].[TagAssignment] AS [predecessor]
            ON [predecessor].[TagAssignmentId] = [path].[NextAssertionId]
        WHERE [path].[NextAssertionId] <> [path].[StartAssertionId]
          AND [predecessor].[SupersedesTagAssignmentId] IS NOT NULL
    )
    SELECT TOP (1) @HasAssertionCycle = CONVERT(bit, 1)
    FROM [AssertionPath]
    WHERE [NextAssertionId] = [StartAssertionId]
    OPTION (MAXRECURSION 32767);

    IF @HasAssertionCycle = CONVERT(bit, 1)
        THROW 51421, ''Assertion predecessor cycles are prohibited.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_Attribution_LineageImmutable]
ON [ATAPUtilities].[Attribution]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51420, ''Published assertion rows are immutable.'', 1;

    DECLARE @ClaimLockCount bigint;
    SELECT @ClaimLockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[Attribution] AS [existing]
        WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN
    (
        SELECT DISTINCT [ClaimKey]
        FROM inserted
    ) AS [affected]
        ON [affected].[ClaimKey] = [existing].[ClaimKey];

    DECLARE @HasAssertionCycle bit = CONVERT(bit, 0);
    ;WITH [AssertionPath] AS
    (
        SELECT [candidate].[AttributionId] AS [StartAssertionId],
               [candidate].[SupersedesAttributionId] AS [NextAssertionId]
        FROM inserted AS [candidate]
        WHERE [candidate].[SupersedesAttributionId] IS NOT NULL

        UNION ALL

        SELECT [path].[StartAssertionId],
               [predecessor].[SupersedesAttributionId]
        FROM [AssertionPath] AS [path]
        INNER JOIN [ATAPUtilities].[Attribution] AS [predecessor]
            ON [predecessor].[AttributionId] = [path].[NextAssertionId]
        WHERE [path].[NextAssertionId] <> [path].[StartAssertionId]
          AND [predecessor].[SupersedesAttributionId] IS NOT NULL
    )
    SELECT TOP (1) @HasAssertionCycle = CONVERT(bit, 1)
    FROM [AssertionPath]
    WHERE [NextAssertionId] = [StartAssertionId]
    OPTION (MAXRECURSION 32767);

    IF @HasAssertionCycle = CONVERT(bit, 1)
        THROW 51421, ''Assertion predecessor cycles are prohibited.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_EntityType_UpdateDeleteImmutable]
ON [ATAPUtilities].[EntityType]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_Entity_UpdateDeleteImmutable]
ON [ATAPUtilities].[Entity]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_RelationshipRolePolicy_UpdateDeleteImmutable]
ON [ATAPUtilities].[RelationshipRolePolicy]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_RelationshipRoleEndpointEntityType_UpdateDeleteImmutable]
ON [ATAPUtilities].[RelationshipRoleEndpointEntityType]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_Authority_UpdateDeleteImmutable]
ON [ATAPUtilities].[Authority]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_Expert_UpdateDeleteImmutable]
ON [ATAPUtilities].[Expert]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_ExpertiseDomain_UpdateDeleteImmutable]
ON [ATAPUtilities].[ExpertiseDomain]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_Tag_UpdateDeleteImmutable]
ON [ATAPUtilities].[Tag]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_AttributionDispute_UpdateDeleteImmutable]
ON [ATAPUtilities].[AttributionDispute]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_ExecutionClassification_UpdateDeleteImmutable]
ON [ATAPUtilities].[ExecutionClassification]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_SecurityCapabilityClassification_UpdateDeleteImmutable]
ON [ATAPUtilities].[SecurityCapabilityClassification]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_RoundTripPolicy_UpdateDeleteImmutable]
ON [ATAPUtilities].[RoundTripPolicy]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_ScalarStorageKind_UpdateDeleteImmutable]
ON [ATAPUtilities].[ScalarStorageKind]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_SecretReferencePolicy_UpdateDeleteImmutable]
ON [ATAPUtilities].[SecretReferencePolicy]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_ExecutorContract_UpdateDeleteImmutable]
ON [ATAPUtilities].[ExecutorContract]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_RuleKind_UpdateDeleteImmutable]
ON [ATAPUtilities].[RuleKind]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_StructuredValueContract_UpdateDeleteImmutable]
ON [ATAPUtilities].[StructuredValueContract]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_ValueType_UpdateDeleteImmutable]
ON [ATAPUtilities].[ValueType]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_ValueTypeAllowedEntityType_UpdateDeleteImmutable]
ON [ATAPUtilities].[ValueTypeAllowedEntityType]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_Primitive_UpdateDeleteImmutable]
ON [ATAPUtilities].[Primitive]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 51440, ''Durable identities and catalog rows are immutable.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_RuleKindVersionCompatibility_ForwardImmutable]
ON [ATAPUtilities].[RuleKindVersionCompatibility]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51450, ''Compatibility decisions are immutable.'', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS [candidate]
        INNER JOIN [ATAPUtilities].[RuleKindVersion] AS [sourceVersion]
            ON [sourceVersion].[RuleKindVersionId] = [candidate].[FromRuleKindVersionId]
           AND [sourceVersion].[RuleKindId] = [candidate].[RuleKindId]
        INNER JOIN [ATAPUtilities].[RuleKindVersion] AS [targetVersion]
            ON [targetVersion].[RuleKindVersionId] = [candidate].[ToRuleKindVersionId]
           AND [targetVersion].[RuleKindId] = [candidate].[RuleKindId]
        WHERE [sourceVersion].[RevisionSequence] >= [targetVersion].[RevisionSequence]
    )
        THROW 51451, ''Compatibility decisions must move forward within one RuleKind.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_PrimitiveInputDefinition_OrdinalImmutable]
ON [ATAPUtilities].[PrimitiveInputDefinition]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51460, ''Published PrimitiveInputDefinition rows are immutable.'', 1;

    DECLARE @OrdinalLockCount bigint;
    SELECT @OrdinalLockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[PrimitiveInputDefinition] AS [existing]
        WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN
    (
        SELECT DISTINCT [PrimitiveVersionId]
        FROM inserted
    ) AS [affected]
        ON [affected].[PrimitiveVersionId] = [existing].[PrimitiveVersionId];

    IF EXISTS
    (
        SELECT 1
        FROM [ATAPUtilities].[PrimitiveInputDefinition] AS [definition]
        INNER JOIN
        (
            SELECT DISTINCT [PrimitiveVersionId]
            FROM inserted
        ) AS [affected]
            ON [affected].[PrimitiveVersionId] = [definition].[PrimitiveVersionId]
        GROUP BY [definition].[PrimitiveVersionId]
        HAVING MIN([definition].[Ordinal]) <> 0
            OR MAX([definition].[Ordinal]) <> COUNT_BIG(*) - 1
    )
        THROW 51461, ''Primitive input ordinals must be contiguous from zero.'', 1;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_AttributionDisputeEvent_StateLineageImmutable]
ON [ATAPUtilities].[AttributionDisputeEvent]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 51470, ''Attribution dispute events are immutable.'', 1;

    DECLARE @EventLockCount bigint;
    SELECT @EventLockCount = COUNT_BIG(*)
    FROM [ATAPUtilities].[AttributionDisputeEvent] AS [existing]
        WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN
    (
        SELECT DISTINCT [AttributionDisputeId]
        FROM inserted
    ) AS [affected]
        ON [affected].[AttributionDisputeId] = [existing].[AttributionDisputeId];

    IF EXISTS
    (
        SELECT 1
        FROM [ATAPUtilities].[AttributionDisputeEvent] AS [event]
        INNER JOIN
        (
            SELECT DISTINCT [AttributionDisputeId]
            FROM inserted
        ) AS [affected]
            ON [affected].[AttributionDisputeId] = [event].[AttributionDisputeId]
        GROUP BY [event].[AttributionDisputeId]
        HAVING MIN([event].[EventSequence]) <> 1
            OR MAX([event].[EventSequence]) <> COUNT_BIG(*)
    )
        THROW 51471, ''Dispute event sequences must be contiguous from one.'', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS [candidate]
        LEFT JOIN [ATAPUtilities].[AttributionDisputeEvent] AS [prior]
            ON [prior].[AttributionDisputeId] = [candidate].[AttributionDisputeId]
           AND [prior].[EventSequence] = [candidate].[EventSequence] - 1
        WHERE ([candidate].[EventSequence] = 1 AND [candidate].[StatusCode] <> ''Raised'')
           OR
           (
               [candidate].[EventSequence] > 1
               AND
               (
                   [prior].[AttributionDisputeEventId] IS NULL
                   OR [prior].[StatusCode] IN (''Resolved'', ''Withdrawn'')
                   OR ([prior].[StatusCode] = ''Raised''
                       AND [candidate].[StatusCode] NOT IN
                           (''UnderReview'', ''Resolved'', ''Withdrawn''))
                   OR ([prior].[StatusCode] = ''UnderReview''
                       AND [candidate].[StatusCode] NOT IN (''Resolved'', ''Withdrawn''))
               )
           )
    )
        THROW 51472, ''Illegal or post-terminal dispute state transition.'', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS [event]
        INNER JOIN [ATAPUtilities].[AttributionDispute] AS [dispute]
            ON [dispute].[AttributionDisputeId] = [event].[AttributionDisputeId]
        WHERE [event].[OutcomeCode] = ''Corrected''
          AND [event].[CorrectedAttributionId] = [dispute].[AttributionId]
    )
        THROW 51473, ''A corrected outcome must name a proper successor, not the disputed attribution itself.'', 1;

    DECLARE @MissingCorrectedLineage bit = CONVERT(bit, 0);
    ;WITH [CorrectedLineage] AS
    (
        SELECT [event].[AttributionDisputeEventId] AS [EventId],
               [event].[CorrectedAttributionId] AS [CurrentAttributionId],
               [dispute].[AttributionId] AS [DisputedAttributionId]
        FROM inserted AS [event]
        INNER JOIN [ATAPUtilities].[AttributionDispute] AS [dispute]
            ON [dispute].[AttributionDisputeId] = [event].[AttributionDisputeId]
        WHERE [event].[OutcomeCode] = ''Corrected''

        UNION ALL

        SELECT [lineage].[EventId], [attribution].[SupersedesAttributionId],
               [lineage].[DisputedAttributionId]
        FROM [CorrectedLineage] AS [lineage]
        INNER JOIN [ATAPUtilities].[Attribution] AS [attribution]
            ON [attribution].[AttributionId] = [lineage].[CurrentAttributionId]
        WHERE [lineage].[CurrentAttributionId] <> [lineage].[DisputedAttributionId]
          AND [attribution].[SupersedesAttributionId] IS NOT NULL
    ),
    [CorrectedEvents] AS
    (
        SELECT [AttributionDisputeEventId]
        FROM inserted
        WHERE [OutcomeCode] = ''Corrected''
    ),
    [ValidatedEvents] AS
    (
        SELECT DISTINCT [EventId]
        FROM [CorrectedLineage]
        WHERE [CurrentAttributionId] = [DisputedAttributionId]
    )
    SELECT TOP (1) @MissingCorrectedLineage = CONVERT(bit, 1)
    FROM [CorrectedEvents] AS [required]
    LEFT JOIN [ValidatedEvents] AS [valid]
        ON [valid].[EventId] = [required].[AttributionDisputeEventId]
    WHERE [valid].[EventId] IS NULL
    OPTION (MAXRECURSION 32767);

    IF @MissingCorrectedLineage = CONVERT(bit, 1)
        THROW 51474, ''Corrected attribution must descend from the disputed attribution.'', 1;
END;';

/* Trusted publication boundary.  The runtime role is execute-only; every
   operation owns its transaction and validates the complete child set before
   commit.  Single-row catalogs and versions without child-set completeness
   obligations remain deployment-created and receive no runtime entry point. */
IF DATABASE_PRINCIPAL_ID(N'RrsbsPublisher') IS NULL
BEGIN
    CREATE ROLE [RrsbsPublisher] AUTHORIZATION [dbo];
END;

EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [ATAPUtilities].[usp_PublishRelationshipRolePolicy]
    @RelationshipKindCode varchar(64),
    @RelationshipRoleCode varchar(64),
    @IsClassificationOnly bit,
    @EndpointEntityTypesJson nvarchar(max)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF ISJSON(@EndpointEntityTypesJson) <> 1
           OR LEFT(LTRIM(@EndpointEntityTypesJson), 1) <> N''[''
            THROW 51200, ''EndpointEntityTypesJson must be a JSON array.'', 1;

        DECLARE @Endpoints table
        (
            EndpointCode varchar(32) NULL,
            EntityTypeId bigint NULL
        );

        INSERT INTO @Endpoints (EndpointCode, EntityTypeId)
        SELECT EndpointCode, EntityTypeId
        FROM OPENJSON(@EndpointEntityTypesJson)
        WITH
        (
            EndpointCode varchar(32) ''$.EndpointCode'',
            EntityTypeId bigint ''$.EntityTypeId''
        );

        IF NOT EXISTS (SELECT 1 FROM @Endpoints)
           OR EXISTS
              (
                  SELECT 1
                  FROM @Endpoints
                  WHERE EndpointCode IS NULL OR EntityTypeId IS NULL
              )
           OR EXISTS
              (
                  SELECT EndpointCode, EntityTypeId
                  FROM @Endpoints
                  GROUP BY EndpointCode, EntityTypeId
                  HAVING COUNT_BIG(*) > 1
              )
            THROW 51201, ''A relationship-role policy requires a nonempty, valid, duplicate-free endpoint set.'', 1;

        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;

        INSERT INTO [ATAPUtilities].[RelationshipRolePolicy]
            ([RelationshipKindCode], [RelationshipRoleCode],
             [IsClassificationOnly], [IsAuthorizationRole])
        VALUES
            (@RelationshipKindCode, @RelationshipRoleCode,
             @IsClassificationOnly, CONVERT(bit, 0));

        DECLARE @RelationshipRolePolicyId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT INTO [ATAPUtilities].[RelationshipRoleEndpointEntityType]
            ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId])
        SELECT @RelationshipRolePolicyId, EndpointCode, EntityTypeId
        FROM @Endpoints;

        IF (SELECT COUNT_BIG(*)
            FROM [ATAPUtilities].[RelationshipRoleEndpointEntityType]
            WHERE [RelationshipRolePolicyId] = @RelationshipRolePolicyId)
           <> (SELECT COUNT_BIG(*) FROM @Endpoints)
            THROW 51202, ''Relationship-role endpoint publication was incomplete.'', 1;

        COMMIT TRANSACTION;
        SELECT @RelationshipRolePolicyId AS [RelationshipRolePolicyId];
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [ATAPUtilities].[usp_PublishRuleKindVersion]
    @RuleKindVersionPhiloteId uniqueidentifier,
    @RuleKindId bigint,
    @RevisionSequence int,
    @PredecessorRuleKindVersionId bigint = NULL,
    @GrammarSourceArtifactVersionId bigint,
    @GrammarHashAlgorithmCode varchar(32),
    @GrammarContentHash varbinary(64),
    @CompendiumSourceArtifactVersionId bigint,
    @CompendiumHashAlgorithmCode varchar(32),
    @CompendiumContentHash varbinary(64),
    @ExecutorContractVersionId bigint = NULL,
    @ExecutionClassificationCode varchar(32),
    @SecurityCapabilityCode varchar(64),
    @RoundTripPolicyCode varchar(32),
    @PublishedAtUtc datetime2(7)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @GrammarSourceArtifactVersionId <= 0
           OR @CompendiumSourceArtifactVersionId <= 0
           OR DATALENGTH(@GrammarContentHash) = 0
           OR DATALENGTH(@CompendiumContentHash) = 0
            THROW 51210, ''RuleKindVersion requires both exact source-version identities and nonempty hashes.'', 1;

        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;

        DECLARE @EntityTypeId bigint;
        SELECT @EntityTypeId = [EntityTypeId]
        FROM [ATAPUtilities].[EntityType] WITH (UPDLOCK, HOLDLOCK)
        WHERE [EntityTypeCode] = ''rule-kind-version'';

        IF @EntityTypeId IS NULL
            THROW 51211, ''The rule-kind-version EntityType is absent.'', 1;

        SELECT 1
        FROM [ATAPUtilities].[RuleKind] WITH (UPDLOCK, HOLDLOCK)
        WHERE [RuleKindId] = @RuleKindId;

        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@EntityTypeId, @RuleKindVersionPhiloteId, @PublishedAtUtc);

        DECLARE @EntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT INTO [ATAPUtilities].[RuleKindVersion]
            ([RuleKindVersionPhiloteId], [EntityId], [EntityTypeId], [RuleKindId],
             [RevisionSequence], [PredecessorRuleKindVersionId],
             [GrammarSourceArtifactVersionId], [GrammarHashAlgorithmCode], [GrammarContentHash],
             [CompendiumSourceArtifactVersionId], [CompendiumHashAlgorithmCode],
             [CompendiumContentHash], [ExecutorContractVersionId],
             [ExecutionClassificationCode], [SecurityCapabilityCode],
             [RoundTripPolicyCode], [PublishedAtUtc])
        VALUES
            (@RuleKindVersionPhiloteId, @EntityId, @EntityTypeId, @RuleKindId,
             @RevisionSequence, @PredecessorRuleKindVersionId,
             @GrammarSourceArtifactVersionId, @GrammarHashAlgorithmCode, @GrammarContentHash,
             @CompendiumSourceArtifactVersionId, @CompendiumHashAlgorithmCode,
             @CompendiumContentHash, @ExecutorContractVersionId,
             @ExecutionClassificationCode, @SecurityCapabilityCode,
             @RoundTripPolicyCode, @PublishedAtUtc);

        DECLARE @RuleKindVersionId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        IF NOT EXISTS
           (
               SELECT 1
               FROM [ATAPUtilities].[RuleKindVersion]
               WHERE [RuleKindVersionId] = @RuleKindVersionId
                 AND [GrammarSourceArtifactVersionId] = @GrammarSourceArtifactVersionId
                 AND [CompendiumSourceArtifactVersionId] = @CompendiumSourceArtifactVersionId
           )
            THROW 51212, ''RuleKindVersion publication was incomplete.'', 1;

        COMMIT TRANSACTION;
        SELECT @RuleKindVersionId AS [RuleKindVersionId], @EntityId AS [EntityId];
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [ATAPUtilities].[usp_PublishValueTypeVersion]
    @ValueTypeVersionPhiloteId uniqueidentifier,
    @ValueTypeId bigint,
    @RevisionSequence int,
    @PredecessorValueTypeVersionId bigint = NULL,
    @ValueCategoryCode varchar(32),
    @ScalarStorageKindCode varchar(64) = NULL,
    @StructuredValueContractVersionId bigint = NULL,
    @ElementValueTypeVersionId bigint = NULL,
    @CollectionOrderingCode varchar(32) = NULL,
    @SecretReferencePolicyId bigint = NULL,
    @ValidationContractCode varchar(64),
    @PublishedAtUtc datetime2(7),
    @AllowedEntityTypesJson nvarchar(max) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        DECLARE @AllowedEntityTypes table (EntityTypeId bigint NOT NULL PRIMARY KEY);

        IF @AllowedEntityTypesJson IS NOT NULL
        BEGIN
            IF ISJSON(@AllowedEntityTypesJson) <> 1
               OR LEFT(LTRIM(@AllowedEntityTypesJson), 1) <> N''[''
                THROW 51220, ''AllowedEntityTypesJson must be a JSON array when supplied.'', 1;

            IF EXISTS
               (
                   SELECT TRY_CONVERT(bigint, [value])
                   FROM OPENJSON(@AllowedEntityTypesJson)
                   GROUP BY TRY_CONVERT(bigint, [value])
                   HAVING TRY_CONVERT(bigint, [value]) IS NULL OR COUNT_BIG(*) > 1
               )
                THROW 51221, ''Allowed entity types must be valid and duplicate-free.'', 1;

            INSERT INTO @AllowedEntityTypes (EntityTypeId)
            SELECT CONVERT(bigint, [value])
            FROM OPENJSON(@AllowedEntityTypesJson);
        END;

        IF (@ValueCategoryCode = ''entity-reference'' AND NOT EXISTS (SELECT 1 FROM @AllowedEntityTypes))
           OR (@ValueCategoryCode <> ''entity-reference'' AND EXISTS (SELECT 1 FROM @AllowedEntityTypes))
            THROW 51222, ''Entity-reference versions require a nonempty allow-list; other categories prohibit it.'', 1;

        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;

        DECLARE @EntityTypeId bigint;
        SELECT @EntityTypeId = [EntityTypeId]
        FROM [ATAPUtilities].[EntityType] WITH (UPDLOCK, HOLDLOCK)
        WHERE [EntityTypeCode] = ''value-type-version'';

        IF @EntityTypeId IS NULL
            THROW 51223, ''The value-type-version EntityType is absent.'', 1;

        SELECT 1
        FROM [ATAPUtilities].[ValueType] WITH (UPDLOCK, HOLDLOCK)
        WHERE [ValueTypeId] = @ValueTypeId;

        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@EntityTypeId, @ValueTypeVersionPhiloteId, @PublishedAtUtc);

        DECLARE @EntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT INTO [ATAPUtilities].[ValueTypeVersion]
            ([ValueTypeVersionPhiloteId], [EntityId], [EntityTypeId], [ValueTypeId],
             [RevisionSequence], [PredecessorValueTypeVersionId], [ValueCategoryCode],
             [ScalarStorageKindCode], [StructuredValueContractVersionId],
             [ElementValueTypeVersionId], [CollectionOrderingCode],
             [SecretReferencePolicyId], [ValidationContractCode], [PublishedAtUtc])
        VALUES
            (@ValueTypeVersionPhiloteId, @EntityId, @EntityTypeId, @ValueTypeId,
             @RevisionSequence, @PredecessorValueTypeVersionId, @ValueCategoryCode,
             @ScalarStorageKindCode, @StructuredValueContractVersionId,
             @ElementValueTypeVersionId, @CollectionOrderingCode,
             @SecretReferencePolicyId, @ValidationContractCode, @PublishedAtUtc);

        DECLARE @ValueTypeVersionId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT INTO [ATAPUtilities].[ValueTypeAllowedEntityType]
            ([ValueTypeVersionId], [EntityTypeId])
        SELECT @ValueTypeVersionId, EntityTypeId
        FROM @AllowedEntityTypes;

        IF (@ValueCategoryCode = ''entity-reference''
            AND NOT EXISTS
                (
                    SELECT 1
                    FROM [ATAPUtilities].[ValueTypeAllowedEntityType]
                    WHERE [ValueTypeVersionId] = @ValueTypeVersionId
                ))
            THROW 51224, ''ValueTypeVersion publication omitted its entity-type allow-list.'', 1;

        COMMIT TRANSACTION;
        SELECT @ValueTypeVersionId AS [ValueTypeVersionId], @EntityId AS [EntityId];
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [ATAPUtilities].[usp_PublishPrimitiveVersion]
    @PrimitiveVersionPhiloteId uniqueidentifier,
    @PrimitiveId bigint,
    @RuleKindId bigint,
    @RuleKindVersionId bigint,
    @RevisionSequence int,
    @PredecessorPrimitiveVersionId bigint = NULL,
    @GrammarProductionCode varchar(128),
    @DefinitionText nvarchar(max),
    @DefinitionHashAlgorithmCode varchar(32),
    @DefinitionContentHash varbinary(64),
    @OutputValueTypeVersionId bigint,
    @OutputMinCardinality int,
    @OutputMaxCardinality int = NULL,
    @PublishedAtUtc datetime2(7),
    @InputDefinitionsJson nvarchar(max)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF ISJSON(@InputDefinitionsJson) <> 1
           OR LEFT(LTRIM(@InputDefinitionsJson), 1) <> N''[''
            THROW 51230, ''InputDefinitionsJson must be a JSON array.'', 1;

        DECLARE @Inputs table
        (
            InputPhiloteId uniqueidentifier NULL,
            InputCode varchar(128) NULL,
            Ordinal int NULL,
            ValueTypeVersionId bigint NULL,
            MinCardinality int NULL,
            MaxCardinality int NULL,
            AllowsNullElement bit NULL,
            ValidationContractCode varchar(64) NULL
        );

        INSERT INTO @Inputs
            (InputPhiloteId, InputCode, Ordinal, ValueTypeVersionId,
             MinCardinality, MaxCardinality, AllowsNullElement, ValidationContractCode)
        SELECT InputPhiloteId, InputCode, Ordinal, ValueTypeVersionId,
               MinCardinality, MaxCardinality, AllowsNullElement, ValidationContractCode
        FROM OPENJSON(@InputDefinitionsJson)
        WITH
        (
            InputPhiloteId uniqueidentifier ''$.PrimitiveInputDefinitionPhiloteId'',
            InputCode varchar(128) ''$.InputCode'',
            Ordinal int ''$.Ordinal'',
            ValueTypeVersionId bigint ''$.ValueTypeVersionId'',
            MinCardinality int ''$.MinCardinality'',
            MaxCardinality int ''$.MaxCardinality'',
            AllowsNullElement bit ''$.AllowsNullElement'',
            ValidationContractCode varchar(64) ''$.ValidationContractCode''
        );

        IF EXISTS
           (
               SELECT 1
               FROM @Inputs
               WHERE InputPhiloteId IS NULL OR InputCode IS NULL OR Ordinal IS NULL
                  OR ValueTypeVersionId IS NULL OR MinCardinality IS NULL
                  OR AllowsNullElement IS NULL OR ValidationContractCode IS NULL
           )
           OR EXISTS
              (
                  SELECT InputPhiloteId FROM @Inputs
                  GROUP BY InputPhiloteId HAVING COUNT_BIG(*) > 1
              )
           OR EXISTS
              (
                  SELECT InputCode FROM @Inputs
                  GROUP BY InputCode HAVING COUNT_BIG(*) > 1
              )
           OR EXISTS
              (
                  SELECT Ordinal FROM @Inputs
                  GROUP BY Ordinal HAVING COUNT_BIG(*) > 1
              )
           OR EXISTS
              (
                  SELECT 1 FROM @Inputs
                  HAVING COUNT_BIG(*) > 0
                     AND (MIN(Ordinal) <> 0 OR MAX(Ordinal) <> COUNT_BIG(*) - 1)
              )
            THROW 51231, ''Primitive inputs must be valid, unique, and contiguous from ordinal zero.'', 1;

        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;

        DECLARE @VersionEntityTypeId bigint;
        DECLARE @InputEntityTypeId bigint;

        SELECT @VersionEntityTypeId = [EntityTypeId]
        FROM [ATAPUtilities].[EntityType] WITH (UPDLOCK, HOLDLOCK)
        WHERE [EntityTypeCode] = ''primitive-version'';

        SELECT @InputEntityTypeId = [EntityTypeId]
        FROM [ATAPUtilities].[EntityType] WITH (UPDLOCK, HOLDLOCK)
        WHERE [EntityTypeCode] = ''primitive-input-definition'';

        IF @VersionEntityTypeId IS NULL OR @InputEntityTypeId IS NULL
            THROW 51232, ''Primitive publication EntityTypes are absent.'', 1;

        SELECT 1
        FROM [ATAPUtilities].[Primitive] WITH (UPDLOCK, HOLDLOCK)
        WHERE [PrimitiveId] = @PrimitiveId AND [RuleKindId] = @RuleKindId;

        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@VersionEntityTypeId, @PrimitiveVersionPhiloteId, @PublishedAtUtc);

        DECLARE @VersionEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT INTO [ATAPUtilities].[PrimitiveVersion]
            ([PrimitiveVersionPhiloteId], [EntityId], [EntityTypeId], [PrimitiveId],
             [RuleKindId], [RuleKindVersionId], [RevisionSequence],
             [PredecessorPrimitiveVersionId], [GrammarProductionCode], [DefinitionText],
             [DefinitionHashAlgorithmCode], [DefinitionContentHash],
             [OutputValueTypeVersionId], [OutputMinCardinality], [OutputMaxCardinality],
             [PublishedAtUtc])
        VALUES
            (@PrimitiveVersionPhiloteId, @VersionEntityId, @VersionEntityTypeId, @PrimitiveId,
             @RuleKindId, @RuleKindVersionId, @RevisionSequence,
             @PredecessorPrimitiveVersionId, @GrammarProductionCode, @DefinitionText,
             @DefinitionHashAlgorithmCode, @DefinitionContentHash,
             @OutputValueTypeVersionId, @OutputMinCardinality, @OutputMaxCardinality,
             @PublishedAtUtc);

        DECLARE @PrimitiveVersionId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        DECLARE @InputEntities table (Ordinal int NOT NULL PRIMARY KEY, EntityId bigint NOT NULL);

        MERGE [ATAPUtilities].[Entity] AS target
        USING @Inputs AS source
           ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
            VALUES (@InputEntityTypeId, source.InputPhiloteId, @PublishedAtUtc)
        OUTPUT source.Ordinal, inserted.EntityId
            INTO @InputEntities (Ordinal, EntityId);

        INSERT INTO [ATAPUtilities].[PrimitiveInputDefinition]
            ([PrimitiveInputDefinitionPhiloteId], [EntityId], [EntityTypeId],
             [PrimitiveVersionId], [InputCode], [Ordinal], [ValueTypeVersionId],
             [MinCardinality], [MaxCardinality], [AllowsNullElement],
             [ValidationContractCode])
        SELECT input.InputPhiloteId, entity.EntityId, @InputEntityTypeId,
               @PrimitiveVersionId, input.InputCode, input.Ordinal, input.ValueTypeVersionId,
               input.MinCardinality, input.MaxCardinality, input.AllowsNullElement,
               input.ValidationContractCode
        FROM @Inputs AS input
        INNER JOIN @InputEntities AS entity ON entity.Ordinal = input.Ordinal;

        IF (SELECT COUNT_BIG(*)
            FROM [ATAPUtilities].[PrimitiveInputDefinition]
            WHERE [PrimitiveVersionId] = @PrimitiveVersionId)
           <> (SELECT COUNT_BIG(*) FROM @Inputs)
            THROW 51233, ''PrimitiveVersion publication omitted one or more input definitions.'', 1;

        COMMIT TRANSACTION;
        SELECT @PrimitiveVersionId AS [PrimitiveVersionId], @VersionEntityId AS [EntityId];
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [ATAPUtilities].[usp_PublishEntityAuthorityAssignment]
    @AssignmentPhiloteId uniqueidentifier,
    @RelationshipRolePolicyId bigint,
    @AuthorityEntityId bigint,
    @AuthorityEntityTypeId bigint,
    @SubjectEntityId bigint,
    @SubjectEntityTypeId bigint,
    @SupersedesAssignmentId bigint = NULL,
    @IsRetraction bit,
    @AssertedByEntityId bigint,
    @AssertedByEntityTypeId bigint,
    @AssertedAtUtc datetime2(7),
    @RecordedAtUtc datetime2(7)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;
        SELECT 1 FROM [ATAPUtilities].[RelationshipRolePolicy] WITH (UPDLOCK, HOLDLOCK)
        WHERE [RelationshipRolePolicyId] = @RelationshipRolePolicyId;
        INSERT INTO [ATAPUtilities].[EntityAuthorityAssignment]
            ([AssignmentPhiloteId], [RelationshipRolePolicyId], [AuthorityEndpointCode],
             [AuthorityEntityId], [AuthorityEntityTypeId], [SubjectEndpointCode],
             [SubjectEntityId], [SubjectEntityTypeId], [SupersedesAssignmentId],
             [IsRetraction], [ActorEndpointCode], [AssertedByEntityId],
             [AssertedByEntityTypeId], [AssertedAtUtc], [RecordedAtUtc])
        VALUES
            (@AssignmentPhiloteId, @RelationshipRolePolicyId, ''authority'',
             @AuthorityEntityId, @AuthorityEntityTypeId, ''subject'',
             @SubjectEntityId, @SubjectEntityTypeId, @SupersedesAssignmentId,
             @IsRetraction, ''actor'', @AssertedByEntityId,
             @AssertedByEntityTypeId, @AssertedAtUtc, @RecordedAtUtc);
        DECLARE @EntityAuthorityAssignmentId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        COMMIT TRANSACTION;
        SELECT @EntityAuthorityAssignmentId AS [EntityAuthorityAssignmentId];
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [ATAPUtilities].[usp_PublishEntityExpertiseDomainAssignment]
    @AssignmentPhiloteId uniqueidentifier,
    @RelationshipRolePolicyId bigint,
    @DomainEntityId bigint,
    @DomainEntityTypeId bigint,
    @SubjectEntityId bigint,
    @SubjectEntityTypeId bigint,
    @SupersedesAssignmentId bigint = NULL,
    @IsRetraction bit,
    @AssertedByEntityId bigint,
    @AssertedByEntityTypeId bigint,
    @AssertedAtUtc datetime2(7),
    @RecordedAtUtc datetime2(7)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;
        SELECT 1 FROM [ATAPUtilities].[RelationshipRolePolicy] WITH (UPDLOCK, HOLDLOCK)
        WHERE [RelationshipRolePolicyId] = @RelationshipRolePolicyId;
        INSERT INTO [ATAPUtilities].[EntityExpertiseDomainAssignment]
            ([AssignmentPhiloteId], [RelationshipRolePolicyId], [DomainEndpointCode],
             [DomainEntityId], [DomainEntityTypeId], [SubjectEndpointCode],
             [SubjectEntityId], [SubjectEntityTypeId], [SupersedesAssignmentId],
             [IsRetraction], [ActorEndpointCode], [AssertedByEntityId],
             [AssertedByEntityTypeId], [AssertedAtUtc], [RecordedAtUtc])
        VALUES
            (@AssignmentPhiloteId, @RelationshipRolePolicyId, ''domain'',
             @DomainEntityId, @DomainEntityTypeId, ''subject'',
             @SubjectEntityId, @SubjectEntityTypeId, @SupersedesAssignmentId,
             @IsRetraction, ''actor'', @AssertedByEntityId,
             @AssertedByEntityTypeId, @AssertedAtUtc, @RecordedAtUtc);
        DECLARE @EntityExpertiseDomainAssignmentId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        COMMIT TRANSACTION;
        SELECT @EntityExpertiseDomainAssignmentId AS [EntityExpertiseDomainAssignmentId];
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [ATAPUtilities].[usp_PublishTagAssignment]
    @TagAssignmentPhiloteId uniqueidentifier,
    @RelationshipRolePolicyId bigint,
    @TagEntityId bigint,
    @TagEntityTypeId bigint,
    @SubjectEntityId bigint,
    @SubjectEntityTypeId bigint,
    @SupersedesTagAssignmentId bigint = NULL,
    @IsRetraction bit,
    @AssertedByEntityId bigint,
    @AssertedByEntityTypeId bigint,
    @AssertedAtUtc datetime2(7),
    @RecordedAtUtc datetime2(7)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;
        SELECT 1 FROM [ATAPUtilities].[RelationshipRolePolicy] WITH (UPDLOCK, HOLDLOCK)
        WHERE [RelationshipRolePolicyId] = @RelationshipRolePolicyId;
        INSERT INTO [ATAPUtilities].[TagAssignment]
            ([TagAssignmentPhiloteId], [RelationshipRolePolicyId], [TagEndpointCode],
             [TagEntityId], [TagEntityTypeId], [SubjectEndpointCode],
             [SubjectEntityId], [SubjectEntityTypeId], [SupersedesTagAssignmentId],
             [IsRetraction], [ActorEndpointCode], [AssertedByEntityId],
             [AssertedByEntityTypeId], [AssertedAtUtc], [RecordedAtUtc])
        VALUES
            (@TagAssignmentPhiloteId, @RelationshipRolePolicyId, ''tag'',
             @TagEntityId, @TagEntityTypeId, ''subject'',
             @SubjectEntityId, @SubjectEntityTypeId, @SupersedesTagAssignmentId,
             @IsRetraction, ''actor'', @AssertedByEntityId,
             @AssertedByEntityTypeId, @AssertedAtUtc, @RecordedAtUtc);
        DECLARE @TagAssignmentId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        COMMIT TRANSACTION;
        SELECT @TagAssignmentId AS [TagAssignmentId];
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [ATAPUtilities].[usp_PublishAttribution]
    @AttributionPhiloteId uniqueidentifier,
    @RelationshipRolePolicyId bigint,
    @AttributedEntityId bigint,
    @AttributedEntityTypeId bigint,
    @SubjectEntityId bigint,
    @SubjectEntityTypeId bigint,
    @EvidenceEntityId bigint = NULL,
    @EvidenceEntityTypeId bigint = NULL,
    @SupersedesAttributionId bigint = NULL,
    @IsRetraction bit,
    @AssertedByEntityId bigint,
    @AssertedByEntityTypeId bigint,
    @AssertedAtUtc datetime2(7),
    @RecordedAtUtc datetime2(7),
    @ReasonReference nvarchar(2048) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF (@EvidenceEntityId IS NULL AND @EvidenceEntityTypeId IS NOT NULL)
           OR (@EvidenceEntityId IS NOT NULL AND @EvidenceEntityTypeId IS NULL)
            THROW 51240, ''Attribution evidence identity must be wholly null or wholly present.'', 1;

        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;
        DECLARE @EntityTypeId bigint;
        SELECT @EntityTypeId = [EntityTypeId]
        FROM [ATAPUtilities].[EntityType] WITH (UPDLOCK, HOLDLOCK)
        WHERE [EntityTypeCode] = ''attribution'';
        IF @EntityTypeId IS NULL THROW 51241, ''The attribution EntityType is absent.'', 1;

        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@EntityTypeId, @AttributionPhiloteId, @RecordedAtUtc);
        DECLARE @EntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT INTO [ATAPUtilities].[Attribution]
            ([AttributionPhiloteId], [EntityId], [EntityTypeId], [RelationshipRolePolicyId],
             [AttributedEndpointCode], [AttributedEntityId], [AttributedEntityTypeId],
             [SubjectEndpointCode], [SubjectEntityId], [SubjectEntityTypeId],
             [EvidenceEndpointCode], [EvidenceEntityId], [EvidenceEntityTypeId],
             [SupersedesAttributionId], [IsRetraction], [ActorEndpointCode],
             [AssertedByEntityId], [AssertedByEntityTypeId], [AssertedAtUtc],
             [RecordedAtUtc], [ReasonReference])
        VALUES
            (@AttributionPhiloteId, @EntityId, @EntityTypeId, @RelationshipRolePolicyId,
             ''attributed'', @AttributedEntityId, @AttributedEntityTypeId,
             ''subject'', @SubjectEntityId, @SubjectEntityTypeId,
             CASE WHEN @EvidenceEntityId IS NULL THEN NULL ELSE ''evidence'' END,
             @EvidenceEntityId, @EvidenceEntityTypeId,
             @SupersedesAttributionId, @IsRetraction, ''actor'',
             @AssertedByEntityId, @AssertedByEntityTypeId, @AssertedAtUtc,
             @RecordedAtUtc, @ReasonReference);
        DECLARE @AttributionId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        COMMIT TRANSACTION;
        SELECT @AttributionId AS [AttributionId], @EntityId AS [EntityId];
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [ATAPUtilities].[usp_PublishRuleKindVersionCompatibility]
    @FromRuleKindVersionId bigint,
    @ToRuleKindVersionId bigint,
    @RuleKindId bigint,
    @CompatibilityDispositionCode varchar(32),
    @EvidenceEntityId bigint,
    @EvidenceEntityTypeId bigint,
    @RecordedAtUtc datetime2(7)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;
        SELECT 1 FROM [ATAPUtilities].[RuleKindVersion] WITH (UPDLOCK, HOLDLOCK)
        WHERE [RuleKindId] = @RuleKindId
          AND [RuleKindVersionId] IN (@FromRuleKindVersionId, @ToRuleKindVersionId);
        INSERT INTO [ATAPUtilities].[RuleKindVersionCompatibility]
            ([FromRuleKindVersionId], [ToRuleKindVersionId], [RuleKindId],
             [CompatibilityDispositionCode], [EvidenceEntityId], [EvidenceEntityTypeId],
             [RecordedAtUtc])
        VALUES
            (@FromRuleKindVersionId, @ToRuleKindVersionId, @RuleKindId,
             @CompatibilityDispositionCode, @EvidenceEntityId, @EvidenceEntityTypeId,
             @RecordedAtUtc);
        COMMIT TRANSACTION;
        SELECT @FromRuleKindVersionId AS [FromRuleKindVersionId],
               @ToRuleKindVersionId AS [ToRuleKindVersionId];
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [ATAPUtilities].[usp_PublishAttributionDispute]
    @AttributionDisputePhiloteId uniqueidentifier,
    @AttributionId bigint,
    @DisputeActorRolePolicyId bigint,
    @RaisedByEntityId bigint,
    @RaisedByEntityTypeId bigint,
    @AuthorityEntityId bigint,
    @AuthorityEntityTypeId bigint,
    @RaisedAtUtc datetime2(7),
    @RecordedAtUtc datetime2(7),
    @ReasonReference nvarchar(2048),
    @InitialEventPhiloteId uniqueidentifier,
    @EventActorRolePolicyId bigint,
    @ActingEntityId bigint,
    @ActingEntityTypeId bigint
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;
        DECLARE @EntityTypeId bigint;
        SELECT @EntityTypeId = [EntityTypeId]
        FROM [ATAPUtilities].[EntityType] WITH (UPDLOCK, HOLDLOCK)
        WHERE [EntityTypeCode] = ''attribution-dispute'';
        IF @EntityTypeId IS NULL THROW 51250, ''The attribution-dispute EntityType is absent.'', 1;

        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@EntityTypeId, @AttributionDisputePhiloteId, @RecordedAtUtc);
        DECLARE @EntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT INTO [ATAPUtilities].[AttributionDispute]
            ([AttributionDisputePhiloteId], [EntityId], [EntityTypeId], [AttributionId],
             [DisputeActorRolePolicyId], [RaisedByEndpointCode], [RaisedByEntityId],
             [RaisedByEntityTypeId], [AuthorityEntityId], [AuthorityEntityTypeId],
             [RaisedAtUtc], [RecordedAtUtc], [ReasonReference])
        VALUES
            (@AttributionDisputePhiloteId, @EntityId, @EntityTypeId, @AttributionId,
             @DisputeActorRolePolicyId, ''raised-by'', @RaisedByEntityId,
             @RaisedByEntityTypeId, @AuthorityEntityId, @AuthorityEntityTypeId,
             @RaisedAtUtc, @RecordedAtUtc, @ReasonReference);
        DECLARE @AttributionDisputeId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT INTO [ATAPUtilities].[AttributionDisputeEvent]
            ([AttributionDisputeEventPhiloteId], [AttributionDisputeId], [EventSequence],
             [StatusCode], [OutcomeCode], [CorrectedAttributionId],
             [EventActorRolePolicyId], [ActingEndpointCode], [ActingEntityId],
             [ActingEntityTypeId], [AuthorityEntityId], [AuthorityEntityTypeId],
             [OccurredAtUtc], [RecordedAtUtc], [ReasonReference])
        VALUES
            (@InitialEventPhiloteId, @AttributionDisputeId, 1,
             ''Raised'', NULL, NULL, @EventActorRolePolicyId, ''acting'',
             @ActingEntityId, @ActingEntityTypeId, @AuthorityEntityId,
             @AuthorityEntityTypeId, @RaisedAtUtc, @RecordedAtUtc, @ReasonReference);

        IF NOT EXISTS
           (
               SELECT 1 FROM [ATAPUtilities].[AttributionDisputeEvent]
               WHERE [AttributionDisputeId] = @AttributionDisputeId
                 AND [EventSequence] = 1 AND [StatusCode] = ''Raised''
           )
            THROW 51251, ''Attribution dispute publication omitted its initial Raised event.'', 1;

        COMMIT TRANSACTION;
        SELECT @AttributionDisputeId AS [AttributionDisputeId], @EntityId AS [EntityId];
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [ATAPUtilities].[usp_AppendAttributionDisputeEvent]
    @AttributionDisputeEventPhiloteId uniqueidentifier,
    @AttributionDisputeId bigint,
    @ExpectedPriorEventSequence int,
    @StatusCode varchar(32),
    @OutcomeCode varchar(32) = NULL,
    @CorrectedAttributionId bigint = NULL,
    @EventActorRolePolicyId bigint,
    @ActingEntityId bigint,
    @ActingEntityTypeId bigint,
    @AuthorityEntityId bigint,
    @AuthorityEntityTypeId bigint,
    @OccurredAtUtc datetime2(7),
    @RecordedAtUtc datetime2(7),
    @ReasonReference nvarchar(2048)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;
        DECLARE @ActualPriorEventSequence int;
        SELECT @ActualPriorEventSequence = MAX([EventSequence])
        FROM [ATAPUtilities].[AttributionDisputeEvent] WITH (UPDLOCK, HOLDLOCK)
        WHERE [AttributionDisputeId] = @AttributionDisputeId;

        IF @ActualPriorEventSequence IS NULL
           OR @ActualPriorEventSequence <> @ExpectedPriorEventSequence
            THROW 51260, ''The attribution-dispute event sequence changed or is absent.'', 1;

        INSERT INTO [ATAPUtilities].[AttributionDisputeEvent]
            ([AttributionDisputeEventPhiloteId], [AttributionDisputeId], [EventSequence],
             [StatusCode], [OutcomeCode], [CorrectedAttributionId],
             [EventActorRolePolicyId], [ActingEndpointCode], [ActingEntityId],
             [ActingEntityTypeId], [AuthorityEntityId], [AuthorityEntityTypeId],
             [OccurredAtUtc], [RecordedAtUtc], [ReasonReference])
        VALUES
            (@AttributionDisputeEventPhiloteId, @AttributionDisputeId,
             @ExpectedPriorEventSequence + 1, @StatusCode, @OutcomeCode,
             @CorrectedAttributionId, @EventActorRolePolicyId, ''acting'',
             @ActingEntityId, @ActingEntityTypeId, @AuthorityEntityId,
             @AuthorityEntityTypeId, @OccurredAtUtc, @RecordedAtUtc, @ReasonReference);

        DECLARE @AttributionDisputeEventId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        COMMIT TRANSACTION;
        SELECT @AttributionDisputeEventId AS [AttributionDisputeEventId];
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

DENY INSERT, UPDATE, DELETE ON SCHEMA::[ATAPUtilities] TO [RrsbsPublisher];

GRANT EXECUTE ON OBJECT::[ATAPUtilities].[usp_PublishRelationshipRolePolicy]
    TO [RrsbsPublisher];
GRANT EXECUTE ON OBJECT::[ATAPUtilities].[usp_PublishRuleKindVersion]
    TO [RrsbsPublisher];
GRANT EXECUTE ON OBJECT::[ATAPUtilities].[usp_PublishValueTypeVersion]
    TO [RrsbsPublisher];
GRANT EXECUTE ON OBJECT::[ATAPUtilities].[usp_PublishPrimitiveVersion]
    TO [RrsbsPublisher];
GRANT EXECUTE ON OBJECT::[ATAPUtilities].[usp_PublishEntityAuthorityAssignment]
    TO [RrsbsPublisher];
GRANT EXECUTE ON OBJECT::[ATAPUtilities].[usp_PublishEntityExpertiseDomainAssignment]
    TO [RrsbsPublisher];
GRANT EXECUTE ON OBJECT::[ATAPUtilities].[usp_PublishTagAssignment]
    TO [RrsbsPublisher];
GRANT EXECUTE ON OBJECT::[ATAPUtilities].[usp_PublishAttribution]
    TO [RrsbsPublisher];
GRANT EXECUTE ON OBJECT::[ATAPUtilities].[usp_PublishRuleKindVersionCompatibility]
    TO [RrsbsPublisher];
GRANT EXECUTE ON OBJECT::[ATAPUtilities].[usp_PublishAttributionDispute]
    TO [RrsbsPublisher];
GRANT EXECUTE ON OBJECT::[ATAPUtilities].[usp_AppendAttributionDisputeEvent]
    TO [RrsbsPublisher];

/*
  Rollback-safe source fixture.

  RDB-480 may set this flag to 1 only in a disposable local rehearsal. The
  fixture turns XACT_ABORT off only while it intentionally catches constraint
  failures, owns one transaction, and always rolls the transaction back.
*/
DECLARE @Rdb400410RunFixtures bit = CONVERT(bit, 0);

IF @Rdb400410RunFixtures = CONVERT(bit, 1)
BEGIN
    SET XACT_ABORT OFF;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO [ATAPUtilities].[EntityType]
            ([EntityTypeCode], [OwningSliceCode], [IsVersionType])
        SELECT [v].[EntityTypeCode], [v].[OwningSliceCode], [v].[IsVersionType]
        FROM
        (
            VALUES
                ('authority', 'RDB-200', CONVERT(bit, 0)),
                ('authority-version', 'RDB-200', CONVERT(bit, 1)),
                ('expert', 'RDB-200', CONVERT(bit, 0)),
                ('expert-version', 'RDB-200', CONVERT(bit, 1)),
                ('expertise-domain', 'RDB-200', CONVERT(bit, 0)),
                ('expertise-domain-version', 'RDB-200', CONVERT(bit, 1)),
                ('tag', 'RDB-200', CONVERT(bit, 0)),
                ('tag-version', 'RDB-200', CONVERT(bit, 1)),
                ('attribution', 'RDB-200', CONVERT(bit, 0)),
                ('attribution-dispute', 'RDB-200', CONVERT(bit, 0)),
                ('rule-kind', 'RDB-210', CONVERT(bit, 0)),
                ('rule-kind-version', 'RDB-210', CONVERT(bit, 1)),
                ('executor-contract', 'RDB-210', CONVERT(bit, 0)),
                ('executor-contract-version', 'RDB-210', CONVERT(bit, 1)),
                ('primitive', 'RDB-210', CONVERT(bit, 0)),
                ('primitive-version', 'RDB-210', CONVERT(bit, 1)),
                ('primitive-input-definition', 'RDB-210', CONVERT(bit, 1)),
                ('value-type', 'RDB-210', CONVERT(bit, 0)),
                ('value-type-version', 'RDB-210', CONVERT(bit, 1)),
                ('structured-value-contract', 'RDB-210', CONVERT(bit, 0)),
                ('structured-value-contract-version', 'RDB-210', CONVERT(bit, 1))
        ) AS [v] ([EntityTypeCode], [OwningSliceCode], [IsVersionType])
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM [ATAPUtilities].[EntityType] AS [et]
            WHERE [et].[EntityTypeCode] = [v].[EntityTypeCode]
        );

        IF NOT EXISTS
        (
            SELECT 1 FROM [ATAPUtilities].[ExecutionClassification]
            WHERE [ExecutionClassificationCode] = 'metadata-only'
        )
        BEGIN
            INSERT INTO [ATAPUtilities].[ExecutionClassification]
                ([ExecutionClassificationCode], [AllowsExecutorContract],
                 [RequiresPlanApproval], [AllowsSideEffects],
                 [RequiresObservationOnly], [RequiresFrozenOutput])
            VALUES ('metadata-only', 0, 0, 0, 0, 0);
        END;

        IF NOT EXISTS
        (
            SELECT 1 FROM [ATAPUtilities].[SecurityCapabilityClassification]
            WHERE [SecurityCapabilityCode] = 'reference-safe'
        )
        BEGIN
            INSERT INTO [ATAPUtilities].[SecurityCapabilityClassification]
                ([SecurityCapabilityCode], [IsDefaultDeny], [RequiresSeparateApproval])
            VALUES ('reference-safe', 1, 0);
        END;

        IF NOT EXISTS
        (
            SELECT 1 FROM [ATAPUtilities].[RoundTripPolicy]
            WHERE [RoundTripPolicyCode] = 'byte-identical'
        )
        BEGIN
            INSERT INTO [ATAPUtilities].[RoundTripPolicy]
                ([RoundTripPolicyCode], [RequiresByteHash],
                 [RequiresCanonicalization], [RequiresFrozenObservation])
            VALUES ('byte-identical', 1, 0, 0);
        END;

        IF NOT EXISTS
        (
            SELECT 1 FROM [ATAPUtilities].[ScalarStorageKind]
            WHERE [ScalarStorageKindCode] = 'bounded-unicode-text'
        )
        BEGIN
            INSERT INTO [ATAPUtilities].[ScalarStorageKind]
                ([ScalarStorageKindCode], [RelationalRepresentationCode],
                 [CanonicalSerializationCode])
            VALUES ('bounded-unicode-text', 'nvarchar', 'utf8-nfc-json-string');
        END;

        IF NOT EXISTS
        (
            SELECT 1 FROM [ATAPUtilities].[SecretReferencePolicy]
            WHERE [SecretReferencePolicyCode] = 'fixture-secret-name-only'
        )
        BEGIN
            INSERT INTO [ATAPUtilities].[SecretReferencePolicy]
                ([SecretReferencePolicyCode], [ResolverCode],
                 [SecretNameSyntaxPolicyCode], [AllowsNonSecretSelector],
                 [AllowsNameInPlanHash], [ResolveDuringPublication])
            VALUES
                ('fixture-secret-name-only', 'Get-SecretATAP',
                 'dotted-secret-name', 0, 1, 0);
        END;

        DECLARE @Now datetime2(7) = SYSUTCDATETIME();
        DECLARE @ExpertTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType]
             WHERE [EntityTypeCode] = 'expert');
        DECLARE @ExpertVersionTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType]
             WHERE [EntityTypeCode] = 'expert-version');
        DECLARE @AuthorityTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType]
             WHERE [EntityTypeCode] = 'authority');
        DECLARE @AuthorityVersionTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType]
             WHERE [EntityTypeCode] = 'authority-version');
        DECLARE @RuleKindTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType]
             WHERE [EntityTypeCode] = 'rule-kind');
        DECLARE @RuleKindVersionTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType]
             WHERE [EntityTypeCode] = 'rule-kind-version');
        DECLARE @ValueTypeTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType]
             WHERE [EntityTypeCode] = 'value-type');
        DECLARE @ValueTypeVersionTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType]
             WHERE [EntityTypeCode] = 'value-type-version');
        DECLARE @PrimitiveTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType]
             WHERE [EntityTypeCode] = 'primitive');
        DECLARE @PrimitiveVersionTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType]
             WHERE [EntityTypeCode] = 'primitive-version');
        DECLARE @PrimitiveInputTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType]
             WHERE [EntityTypeCode] = 'primitive-input-definition');
        DECLARE @AttributionTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType]
             WHERE [EntityTypeCode] = 'attribution');

        /* Positive fixture: exact subtype registrations, immutable kind/value/
           primitive versions, typed input, and same-claim attribution lineage. */
        DECLARE @ExpertPhilote uniqueidentifier = NEWID();
        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@ExpertTypeId, @ExpertPhilote, @Now);
        DECLARE @ExpertEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[Expert]
            ([ExpertPhiloteId], [EntityId], [EntityTypeId], [ExpertCode], [CreatedAtUtc])
        VALUES (@ExpertPhilote, @ExpertEntityId, @ExpertTypeId, 'fixture-expert', @Now);
        DECLARE @ExpertId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        DECLARE @ExpertVersionPhilote uniqueidentifier = NEWID();
        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@ExpertVersionTypeId, @ExpertVersionPhilote, @Now);
        DECLARE @ExpertVersionEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[ExpertVersion]
            ([ExpertVersionPhiloteId], [EntityId], [EntityTypeId], [ExpertId],
             [RevisionSequence], [PredecessorExpertVersionId], [DisplayLabel],
             [NonSecretDescription], [PublishedAtUtc])
        VALUES
            (@ExpertVersionPhilote, @ExpertVersionEntityId, @ExpertVersionTypeId,
             @ExpertId, 1, NULL, N'Fixture Expert', N'Non-secret fixture actor', @Now);

        DECLARE @AuthorityPhilote uniqueidentifier = NEWID();
        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@AuthorityTypeId, @AuthorityPhilote, @Now);
        DECLARE @AuthorityEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[Authority]
            ([AuthorityPhiloteId], [EntityId], [EntityTypeId], [AuthorityCode], [CreatedAtUtc])
        VALUES (@AuthorityPhilote, @AuthorityEntityId, @AuthorityTypeId, 'fixture-authority', @Now);
        DECLARE @AuthorityId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        DECLARE @AuthorityVersionPhilote uniqueidentifier = NEWID();
        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@AuthorityVersionTypeId, @AuthorityVersionPhilote, @Now);
        DECLARE @AuthorityVersionEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[AuthorityVersion]
            ([AuthorityVersionPhiloteId], [EntityId], [EntityTypeId], [AuthorityId],
             [RevisionSequence], [PredecessorAuthorityVersionId], [AuthorityKindCode],
             [DisplayLabel], [Description], [PublishedAtUtc])
        VALUES
            (@AuthorityVersionPhilote, @AuthorityVersionEntityId, @AuthorityVersionTypeId,
             @AuthorityId, 1, NULL, 'organization', N'Fixture Authority', NULL, @Now);

        DECLARE @ValueTypePhilote uniqueidentifier = NEWID();
        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@ValueTypeTypeId, @ValueTypePhilote, @Now);
        DECLARE @ValueTypeEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[ValueType]
            ([ValueTypePhiloteId], [EntityId], [EntityTypeId], [ValueTypeCode], [CreatedAtUtc])
        VALUES (@ValueTypePhilote, @ValueTypeEntityId, @ValueTypeTypeId, 'fixture-text', @Now);
        DECLARE @ValueTypeId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        DECLARE @ValueTypeVersionPhilote uniqueidentifier = NEWID();
        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@ValueTypeVersionTypeId, @ValueTypeVersionPhilote, @Now);
        DECLARE @ValueTypeVersionEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[ValueTypeVersion]
            ([ValueTypeVersionPhiloteId], [EntityId], [EntityTypeId], [ValueTypeId],
             [RevisionSequence], [PredecessorValueTypeVersionId], [ValueCategoryCode],
             [ScalarStorageKindCode], [StructuredValueContractVersionId],
             [ElementValueTypeVersionId], [CollectionOrderingCode],
             [SecretReferencePolicyId], [ValidationContractCode], [PublishedAtUtc])
        VALUES
            (@ValueTypeVersionPhilote, @ValueTypeVersionEntityId, @ValueTypeVersionTypeId,
             @ValueTypeId, 1, NULL, 'scalar', 'bounded-unicode-text', NULL, NULL, NULL,
             NULL, 'fixture-nonempty', @Now);
        DECLARE @ValueTypeVersionId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        DECLARE @RuleKindPhilote uniqueidentifier = NEWID();
        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@RuleKindTypeId, @RuleKindPhilote, @Now);
        DECLARE @RuleKindEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[RuleKind]
            ([RuleKindPhiloteId], [EntityId], [EntityTypeId], [RuleKindCode], [CreatedAtUtc])
        VALUES (@RuleKindPhilote, @RuleKindEntityId, @RuleKindTypeId, 'fixture-kind', @Now);
        DECLARE @RuleKindId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        DECLARE @RuleKindVersionPhilote uniqueidentifier = NEWID();
        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@RuleKindVersionTypeId, @RuleKindVersionPhilote, @Now);
        DECLARE @RuleKindVersionEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[RuleKindVersion]
            ([RuleKindVersionPhiloteId], [EntityId], [EntityTypeId], [RuleKindId],
             [RevisionSequence], [PredecessorRuleKindVersionId],
             [GrammarSourceArtifactVersionId],
             [GrammarHashAlgorithmCode], [GrammarContentHash],
             [CompendiumSourceArtifactVersionId],
             [CompendiumHashAlgorithmCode], [CompendiumContentHash],
             [ExecutorContractVersionId], [ExecutionClassificationCode],
             [SecurityCapabilityCode], [RoundTripPolicyCode], [PublishedAtUtc])
        VALUES
            (@RuleKindVersionPhilote, @RuleKindVersionEntityId, @RuleKindVersionTypeId,
             @RuleKindId, 1, NULL, @ExpertVersionEntityId,
             'SHA-256', 0x01, @ExpertVersionEntityId,
             'SHA-256', 0x02, NULL, 'metadata-only', 'reference-safe',
             'byte-identical', @Now);
        DECLARE @RuleKindVersionId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        DECLARE @PrimitivePhilote uniqueidentifier = NEWID();
        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@PrimitiveTypeId, @PrimitivePhilote, @Now);
        DECLARE @PrimitiveEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[Primitive]
            ([PrimitivePhiloteId], [EntityId], [EntityTypeId], [RuleKindId],
             [PrimitiveCode], [CreatedAtUtc])
        VALUES
            (@PrimitivePhilote, @PrimitiveEntityId, @PrimitiveTypeId,
             @RuleKindId, 'fixture-primitive', @Now);
        DECLARE @PrimitiveId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        DECLARE @PrimitiveVersionPhilote uniqueidentifier = NEWID();
        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@PrimitiveVersionTypeId, @PrimitiveVersionPhilote, @Now);
        DECLARE @PrimitiveVersionEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[PrimitiveVersion]
            ([PrimitiveVersionPhiloteId], [EntityId], [EntityTypeId], [PrimitiveId],
             [RuleKindId], [RuleKindVersionId], [RevisionSequence],
             [PredecessorPrimitiveVersionId], [GrammarProductionCode], [DefinitionText],
             [DefinitionHashAlgorithmCode], [DefinitionContentHash],
             [OutputValueTypeVersionId], [OutputMinCardinality], [OutputMaxCardinality],
             [PublishedAtUtc])
        VALUES
            (@PrimitiveVersionPhilote, @PrimitiveVersionEntityId,
             @PrimitiveVersionTypeId, @PrimitiveId, @RuleKindId, @RuleKindVersionId,
             1, NULL, 'FixtureProduction', N'FixtureProduction = "fixture" ;',
             'SHA-256', 0x03, @ValueTypeVersionId, 1, 1, @Now);
        DECLARE @PrimitiveVersionId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        DECLARE @InputPhilote uniqueidentifier = NEWID();
        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@PrimitiveInputTypeId, @InputPhilote, @Now);
        DECLARE @InputEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[PrimitiveInputDefinition]
            ([PrimitiveInputDefinitionPhiloteId], [EntityId], [EntityTypeId],
             [PrimitiveVersionId], [InputCode], [Ordinal], [ValueTypeVersionId],
             [MinCardinality], [MaxCardinality], [AllowsNullElement],
             [ValidationContractCode])
        VALUES
            (@InputPhilote, @InputEntityId, @PrimitiveInputTypeId,
             @PrimitiveVersionId, 'value', 0, @ValueTypeVersionId,
             1, 1, 0, 'fixture-nonempty');

        DECLARE @AttributionPolicyId bigint;
        INSERT INTO [ATAPUtilities].[RelationshipRolePolicy]
            ([RelationshipKindCode], [RelationshipRoleCode],
             [IsClassificationOnly], [IsAuthorizationRole])
        VALUES ('attribution', 'authored-by', 0, 0);
        SET @AttributionPolicyId = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[RelationshipRoleEndpointEntityType]
            ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId])
        VALUES
            (@AttributionPolicyId, 'attributed', @ExpertVersionTypeId),
            (@AttributionPolicyId, 'subject', @RuleKindVersionTypeId),
            (@AttributionPolicyId, 'actor', @ExpertVersionTypeId);

        DECLARE @AttributionPhilote uniqueidentifier = NEWID();
        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@AttributionTypeId, @AttributionPhilote, @Now);
        DECLARE @AttributionEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[Attribution]
            ([AttributionPhiloteId], [EntityId], [EntityTypeId],
             [RelationshipRolePolicyId], [AttributedEndpointCode],
             [AttributedEntityId], [AttributedEntityTypeId], [SubjectEndpointCode],
             [SubjectEntityId], [SubjectEntityTypeId], [EvidenceEndpointCode],
             [EvidenceEntityId], [EvidenceEntityTypeId], [SupersedesAttributionId],
             [IsRetraction], [ActorEndpointCode], [AssertedByEntityId],
             [AssertedByEntityTypeId], [AssertedAtUtc], [RecordedAtUtc], [ReasonReference])
        VALUES
            (@AttributionPhilote, @AttributionEntityId, @AttributionTypeId,
             @AttributionPolicyId, 'attributed', @ExpertVersionEntityId,
             @ExpertVersionTypeId, 'subject', @RuleKindVersionEntityId,
             @RuleKindVersionTypeId, NULL, NULL, NULL, NULL, 0, 'actor',
             @ExpertVersionEntityId, @ExpertVersionTypeId, @Now, @Now,
             N'Fixture attribution');
        DECLARE @AttributionId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        /* Negative I-01: correct Philote with the wrong frozen subtype code. */
        SAVE TRANSACTION [Rdb400410_I01];
        BEGIN TRY
            DECLARE @WrongAuthorityPhilote uniqueidentifier = NEWID();
            INSERT INTO [ATAPUtilities].[Entity]
                ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
            VALUES (@ExpertTypeId, @WrongAuthorityPhilote, @Now);
            DECLARE @WrongAuthorityEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
            INSERT INTO [ATAPUtilities].[Authority]
                ([AuthorityPhiloteId], [EntityId], [EntityTypeId],
                 [AuthorityCode], [CreatedAtUtc])
            VALUES
                (@WrongAuthorityPhilote, @WrongAuthorityEntityId, @ExpertTypeId,
                 'invalid-wrong-subtype', @Now);
            THROW 51001, 'I-01 fixture unexpectedly accepted a mismatched subtype.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 51001 THROW;
            ROLLBACK TRANSACTION [Rdb400410_I01];
        END CATCH;

        /* Negative I-02: a valid Entity type absent from the role endpoint policy. */
        SAVE TRANSACTION [Rdb400410_I02];
        BEGIN TRY
            DECLARE @BadAttributionPhilote uniqueidentifier = NEWID();
            INSERT INTO [ATAPUtilities].[Entity]
                ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
            VALUES (@AttributionTypeId, @BadAttributionPhilote, @Now);
            DECLARE @BadAttributionEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
            INSERT INTO [ATAPUtilities].[Attribution]
                ([AttributionPhiloteId], [EntityId], [EntityTypeId],
                 [RelationshipRolePolicyId], [AttributedEndpointCode],
                 [AttributedEntityId], [AttributedEntityTypeId], [SubjectEndpointCode],
                 [SubjectEntityId], [SubjectEntityTypeId], [EvidenceEndpointCode],
                 [EvidenceEntityId], [EvidenceEntityTypeId], [SupersedesAttributionId],
                 [IsRetraction], [ActorEndpointCode], [AssertedByEntityId],
                 [AssertedByEntityTypeId], [AssertedAtUtc], [RecordedAtUtc], [ReasonReference])
            VALUES
                (@BadAttributionPhilote, @BadAttributionEntityId, @AttributionTypeId,
                 @AttributionPolicyId, 'attributed', @AuthorityVersionEntityId,
                 @AuthorityVersionTypeId, 'subject', @RuleKindVersionEntityId,
                 @RuleKindVersionTypeId, NULL, NULL, NULL, NULL, 0, 'actor',
                 @ExpertVersionEntityId, @ExpertVersionTypeId, @Now, @Now,
                 N'Invalid endpoint type');
            THROW 51002, 'I-02 fixture unexpectedly accepted an unallow-listed endpoint.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 51002 THROW;
            ROLLBACK TRANSACTION [Rdb400410_I02];
        END CATCH;

        /* Negative I-04: PrimitiveVersion selects another durable kind's version. */
        SAVE TRANSACTION [Rdb400410_I04];
        BEGIN TRY
            DECLARE @OtherRuleKindPhilote uniqueidentifier = NEWID();
            INSERT INTO [ATAPUtilities].[Entity]
                ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
            VALUES (@RuleKindTypeId, @OtherRuleKindPhilote, @Now);
            DECLARE @OtherRuleKindEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
            INSERT INTO [ATAPUtilities].[RuleKind]
                ([RuleKindPhiloteId], [EntityId], [EntityTypeId], [RuleKindCode], [CreatedAtUtc])
            VALUES
                (@OtherRuleKindPhilote, @OtherRuleKindEntityId, @RuleKindTypeId,
                 'fixture-other-kind', @Now);
            DECLARE @OtherRuleKindId bigint = CONVERT(bigint, SCOPE_IDENTITY());
            DECLARE @OtherVersionPhilote uniqueidentifier = NEWID();
            INSERT INTO [ATAPUtilities].[Entity]
                ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
            VALUES (@RuleKindVersionTypeId, @OtherVersionPhilote, @Now);
            DECLARE @OtherVersionEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
            INSERT INTO [ATAPUtilities].[RuleKindVersion]
                ([RuleKindVersionPhiloteId], [EntityId], [EntityTypeId], [RuleKindId],
                 [RevisionSequence], [PredecessorRuleKindVersionId],
                 [GrammarSourceArtifactVersionId],
                 [GrammarHashAlgorithmCode], [GrammarContentHash],
                 [CompendiumSourceArtifactVersionId],
                 [CompendiumHashAlgorithmCode], [CompendiumContentHash],
                 [ExecutorContractVersionId], [ExecutionClassificationCode],
                 [SecurityCapabilityCode], [RoundTripPolicyCode], [PublishedAtUtc])
            VALUES
                (@OtherVersionPhilote, @OtherVersionEntityId, @RuleKindVersionTypeId,
                 @OtherRuleKindId, 1, NULL, @ExpertVersionEntityId,
                 'SHA-256', 0x04, @ExpertVersionEntityId,
                 'SHA-256', 0x05, NULL, 'metadata-only', 'reference-safe',
                 'byte-identical', @Now);
            DECLARE @OtherRuleKindVersionId bigint = CONVERT(bigint, SCOPE_IDENTITY());
            DECLARE @BadPrimitiveVersionPhilote uniqueidentifier = NEWID();
            INSERT INTO [ATAPUtilities].[Entity]
                ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
            VALUES (@PrimitiveVersionTypeId, @BadPrimitiveVersionPhilote, @Now);
            DECLARE @BadPrimitiveVersionEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
            INSERT INTO [ATAPUtilities].[PrimitiveVersion]
                ([PrimitiveVersionPhiloteId], [EntityId], [EntityTypeId], [PrimitiveId],
                 [RuleKindId], [RuleKindVersionId], [RevisionSequence],
                 [PredecessorPrimitiveVersionId], [GrammarProductionCode], [DefinitionText],
                 [DefinitionHashAlgorithmCode], [DefinitionContentHash],
                 [OutputValueTypeVersionId], [OutputMinCardinality], [OutputMaxCardinality],
                 [PublishedAtUtc])
            VALUES
                (@BadPrimitiveVersionPhilote, @BadPrimitiveVersionEntityId,
                 @PrimitiveVersionTypeId, @PrimitiveId, @RuleKindId,
                 @OtherRuleKindVersionId, 2, @PrimitiveVersionId, 'BadCrossKind',
                 N'BadCrossKind = "bad" ;', 'SHA-256', 0x06,
                 @ValueTypeVersionId, 1, 1, @Now);
            THROW 51004, 'I-04 fixture unexpectedly accepted a cross-kind version.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 51004 THROW;
            ROLLBACK TRANSACTION [Rdb400410_I04];
        END CATCH;

        /* Negative I-05: a ValueTypeVersion satisfies two category shapes. */
        SAVE TRANSACTION [Rdb400410_I05];
        BEGIN TRY
            DECLARE @BadValueVersionPhilote uniqueidentifier = NEWID();
            INSERT INTO [ATAPUtilities].[Entity]
                ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
            VALUES (@ValueTypeVersionTypeId, @BadValueVersionPhilote, @Now);
            DECLARE @BadValueVersionEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
            DECLARE @SecretReferencePolicyId bigint =
                (SELECT [SecretReferencePolicyId]
                 FROM [ATAPUtilities].[SecretReferencePolicy]
                 WHERE [SecretReferencePolicyCode] = 'fixture-secret-name-only');
            INSERT INTO [ATAPUtilities].[ValueTypeVersion]
                ([ValueTypeVersionPhiloteId], [EntityId], [EntityTypeId], [ValueTypeId],
                 [RevisionSequence], [PredecessorValueTypeVersionId], [ValueCategoryCode],
                 [ScalarStorageKindCode], [StructuredValueContractVersionId],
                 [ElementValueTypeVersionId], [CollectionOrderingCode],
                 [SecretReferencePolicyId], [ValidationContractCode], [PublishedAtUtc])
            VALUES
                (@BadValueVersionPhilote, @BadValueVersionEntityId,
                 @ValueTypeVersionTypeId, @ValueTypeId, 2, @ValueTypeVersionId,
                 'scalar', 'bounded-unicode-text', NULL, NULL, NULL,
                 @SecretReferencePolicyId, 'fixture-nonempty', @Now);
            THROW 51005, 'I-05 fixture unexpectedly accepted multiple value shapes.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 51005 THROW;
            ROLLBACK TRANSACTION [Rdb400410_I05];
        END CATCH;

        /* Negative RDB-210 cardinality: max cannot be less than min. */
        SAVE TRANSACTION [Rdb400410_Cardinality];
        BEGIN TRY
            DECLARE @BadCardinalityPhilote uniqueidentifier = NEWID();
            INSERT INTO [ATAPUtilities].[Entity]
                ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
            VALUES (@PrimitiveVersionTypeId, @BadCardinalityPhilote, @Now);
            DECLARE @BadCardinalityEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
            INSERT INTO [ATAPUtilities].[PrimitiveVersion]
                ([PrimitiveVersionPhiloteId], [EntityId], [EntityTypeId], [PrimitiveId],
                 [RuleKindId], [RuleKindVersionId], [RevisionSequence],
                 [PredecessorPrimitiveVersionId], [GrammarProductionCode], [DefinitionText],
                 [DefinitionHashAlgorithmCode], [DefinitionContentHash],
                 [OutputValueTypeVersionId], [OutputMinCardinality], [OutputMaxCardinality],
                 [PublishedAtUtc])
            VALUES
                (@BadCardinalityPhilote, @BadCardinalityEntityId,
                 @PrimitiveVersionTypeId, @PrimitiveId, @RuleKindId, @RuleKindVersionId,
                 2, @PrimitiveVersionId, 'BadCardinality', N'BadCardinality = "bad" ;',
                 'SHA-256', 0x07, @ValueTypeVersionId, 2, 1, @Now);
            THROW 51006, 'Cardinality fixture unexpectedly accepted max below min.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 51006 THROW;
            ROLLBACK TRANSACTION [Rdb400410_Cardinality];
        END CATCH;

        /* Negative I-22: one assertion cannot receive two direct successors. */
        DECLARE @SuccessorPhilote uniqueidentifier = NEWID();
        INSERT INTO [ATAPUtilities].[Entity]
            ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@AttributionTypeId, @SuccessorPhilote, @Now);
        DECLARE @SuccessorEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[Attribution]
            ([AttributionPhiloteId], [EntityId], [EntityTypeId],
             [RelationshipRolePolicyId], [AttributedEndpointCode],
             [AttributedEntityId], [AttributedEntityTypeId], [SubjectEndpointCode],
             [SubjectEntityId], [SubjectEntityTypeId], [EvidenceEndpointCode],
             [EvidenceEntityId], [EvidenceEntityTypeId], [SupersedesAttributionId],
             [IsRetraction], [ActorEndpointCode], [AssertedByEntityId],
             [AssertedByEntityTypeId], [AssertedAtUtc], [RecordedAtUtc], [ReasonReference])
        VALUES
            (@SuccessorPhilote, @SuccessorEntityId, @AttributionTypeId,
             @AttributionPolicyId, 'attributed', @ExpertVersionEntityId,
             @ExpertVersionTypeId, 'subject', @RuleKindVersionEntityId,
             @RuleKindVersionTypeId, NULL, NULL, NULL, @AttributionId, 1, 'actor',
             @ExpertVersionEntityId, @ExpertVersionTypeId, @Now, @Now,
             N'Fixture retraction');

        SAVE TRANSACTION [Rdb400410_I22];
        BEGIN TRY
            DECLARE @SecondSuccessorPhilote uniqueidentifier = NEWID();
            INSERT INTO [ATAPUtilities].[Entity]
                ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
            VALUES (@AttributionTypeId, @SecondSuccessorPhilote, @Now);
            DECLARE @SecondSuccessorEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
            INSERT INTO [ATAPUtilities].[Attribution]
                ([AttributionPhiloteId], [EntityId], [EntityTypeId],
                 [RelationshipRolePolicyId], [AttributedEndpointCode],
                 [AttributedEntityId], [AttributedEntityTypeId], [SubjectEndpointCode],
                 [SubjectEntityId], [SubjectEntityTypeId], [EvidenceEndpointCode],
                 [EvidenceEntityId], [EvidenceEntityTypeId], [SupersedesAttributionId],
                 [IsRetraction], [ActorEndpointCode], [AssertedByEntityId],
                 [AssertedByEntityTypeId], [AssertedAtUtc], [RecordedAtUtc], [ReasonReference])
            VALUES
                (@SecondSuccessorPhilote, @SecondSuccessorEntityId, @AttributionTypeId,
                 @AttributionPolicyId, 'attributed', @ExpertVersionEntityId,
                 @ExpertVersionTypeId, 'subject', @RuleKindVersionEntityId,
                 @RuleKindVersionTypeId, NULL, NULL, NULL, @AttributionId, 1, 'actor',
                 @ExpertVersionEntityId, @ExpertVersionTypeId, @Now, @Now,
                 N'Invalid competing retraction');
            THROW 51022, 'I-22 fixture unexpectedly accepted two direct successors.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 51022 THROW;
            ROLLBACK TRANSACTION [Rdb400410_I22];
        END CATCH;

        ROLLBACK TRANSACTION;
        SET XACT_ABORT ON;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET XACT_ABORT ON;
        THROW;
    END CATCH;
END;

/* RDB-480 postconditions are source-static here; database execution belongs
   to the disposable rehearsal. */
IF OBJECT_ID(N'[ATAPUtilities].[EntityType]', N'U') IS NULL
    OR OBJECT_ID(N'[ATAPUtilities].[AttributionDisputeEvent]', N'U') IS NULL
    OR OBJECT_ID(N'[ATAPUtilities].[RuleKindVersion]', N'U') IS NULL
    OR OBJECT_ID(N'[ATAPUtilities].[PrimitiveInputDefinition]', N'U') IS NULL
    OR OBJECT_ID(N'[ATAPUtilities].[ValueTypeAllowedEntityType]', N'U') IS NULL
BEGIN
    THROW 51100, 'RDB-400/410 postcondition failed: a registered table is absent.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM
    (
        VALUES
            (N'TR_AuthorityVersion_LineageImmutable'),
            (N'TR_ExpertVersion_LineageImmutable'),
            (N'TR_ExpertiseDomainVersion_LineageImmutable'),
            (N'TR_TagVersion_LineageImmutable'),
            (N'TR_ExecutorContractVersion_LineageImmutable'),
            (N'TR_RuleKindVersion_LineageImmutable'),
            (N'TR_StructuredValueContractVersion_LineageImmutable'),
            (N'TR_ValueTypeVersion_LineageImmutable'),
            (N'TR_PrimitiveVersion_LineageImmutable'),
            (N'TR_EntityAuthorityAssignment_LineageImmutable'),
            (N'TR_EntityExpertiseDomainAssignment_LineageImmutable'),
            (N'TR_TagAssignment_LineageImmutable'),
            (N'TR_Attribution_LineageImmutable'),
            (N'TR_AttributionDisputeEvent_StateLineageImmutable'),
            (N'TR_RuleKindVersionCompatibility_ForwardImmutable'),
            (N'TR_PrimitiveInputDefinition_OrdinalImmutable'),
            (N'TR_EntityType_UpdateDeleteImmutable'),
            (N'TR_Entity_UpdateDeleteImmutable'),
            (N'TR_RelationshipRolePolicy_UpdateDeleteImmutable'),
            (N'TR_RelationshipRoleEndpointEntityType_UpdateDeleteImmutable'),
            (N'TR_Authority_UpdateDeleteImmutable'),
            (N'TR_Expert_UpdateDeleteImmutable'),
            (N'TR_ExpertiseDomain_UpdateDeleteImmutable'),
            (N'TR_Tag_UpdateDeleteImmutable'),
            (N'TR_AttributionDispute_UpdateDeleteImmutable'),
            (N'TR_ExecutionClassification_UpdateDeleteImmutable'),
            (N'TR_SecurityCapabilityClassification_UpdateDeleteImmutable'),
            (N'TR_RoundTripPolicy_UpdateDeleteImmutable'),
            (N'TR_ScalarStorageKind_UpdateDeleteImmutable'),
            (N'TR_SecretReferencePolicy_UpdateDeleteImmutable'),
            (N'TR_ExecutorContract_UpdateDeleteImmutable'),
            (N'TR_RuleKind_UpdateDeleteImmutable'),
            (N'TR_StructuredValueContract_UpdateDeleteImmutable'),
            (N'TR_ValueType_UpdateDeleteImmutable'),
            (N'TR_ValueTypeAllowedEntityType_UpdateDeleteImmutable'),
            (N'TR_Primitive_UpdateDeleteImmutable')
    ) AS [expected] ([TriggerName])
    LEFT JOIN sys.triggers AS [actual]
        ON [actual].[name] = [expected].[TriggerName]
       AND OBJECT_SCHEMA_NAME([actual].[object_id]) = N'ATAPUtilities'
    WHERE [actual].[object_id] IS NULL
       OR [actual].[is_disabled] = CONVERT(bit, 1)
)
BEGIN
    THROW 51101, 'RDB-400/410 postcondition failed: a required trigger is absent or disabled.', 1;
END;

IF DATABASE_PRINCIPAL_ID(N'RrsbsPublisher') IS NULL
   OR EXISTS
      (
          SELECT 1
          FROM
          (
              VALUES
                  (N'usp_PublishRelationshipRolePolicy'),
                  (N'usp_PublishRuleKindVersion'),
                  (N'usp_PublishValueTypeVersion'),
                  (N'usp_PublishPrimitiveVersion'),
                  (N'usp_PublishEntityAuthorityAssignment'),
                  (N'usp_PublishEntityExpertiseDomainAssignment'),
                  (N'usp_PublishTagAssignment'),
                  (N'usp_PublishAttribution'),
                  (N'usp_PublishRuleKindVersionCompatibility'),
                  (N'usp_PublishAttributionDispute'),
                  (N'usp_AppendAttributionDisputeEvent')
          ) AS [expected] ([ProcedureName])
          LEFT JOIN sys.procedures AS [actual]
              ON [actual].[name] = [expected].[ProcedureName]
             AND OBJECT_SCHEMA_NAME([actual].[object_id]) = N'ATAPUtilities'
          WHERE [actual].[object_id] IS NULL
      )
BEGIN
    THROW 51102, 'RDB-400/410 postcondition failed: the publisher role or trusted procedure is absent.', 1;
END;
/* END INTEGRATED FRAGMENT: RDB-400-410__Foundation-Kind-Primitive.sql */

/* BEGIN INTEGRATED FRAGMENT: RDB-420__Rule-Composition.sql */
/*
  RDB-420 Rule-composition fragment (SQL Server 2022 / TSql160).

  Integration contract:
  - RDB-480 runs this fragment after RDB-400/410 in the same database selected
    by the runner. This fragment contains no USE, database, login, or history DDL.
  - RDB-200/210 prerequisite candidate keys are referenced explicitly below.
  - RuleVersionNode is Philote-bearing but is not an Entity subtype. RDB-270
    and frozen RDB-320 supersede the earlier RDB-220 wording on that point.
  - The fragment owns its transaction only when the caller has none. When it
    joins a caller transaction it uses a savepoint and never commits the caller.
  - Fixtures are opt-in (SESSION_CONTEXT RRSBS_RUN_RDB420_FIXTURES = 1), use
    only disposable data, and always roll back.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Rdb420OwnsTransaction bit = 0;
IF @@TRANCOUNT = 0
BEGIN
    BEGIN TRANSACTION;
    SET @Rdb420OwnsTransaction = 1;
END;
ELSE
    SAVE TRANSACTION Rdb420Fragment;

BEGIN TRY
    IF OBJECT_ID(N'[ATAPUtilities].[BindingShape]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[BindingShape]
        (
            [BindingShapeCode] varchar(32) NOT NULL,
            [RequiresConstant] bit NOT NULL,
            [RequiresRuleInput] bit NOT NULL,
            [RequiresDerivation] bit NOT NULL,
            CONSTRAINT [PK_BindingShape] PRIMARY KEY CLUSTERED ([BindingShapeCode]),
            CONSTRAINT [CK_BindingShape_ExactlyOneRequirement] CHECK
                (CONVERT(tinyint, [RequiresConstant]) + CONVERT(tinyint, [RequiresRuleInput]) + CONVERT(tinyint, [RequiresDerivation]) = 1),
            CONSTRAINT [CK_BindingShape_CodeMatchesRequirement] CHECK
                (([BindingShapeCode] = 'constant' AND [RequiresConstant] = 1)
                 OR ([BindingShapeCode] = 'rule-input' AND [RequiresRuleInput] = 1)
                 OR ([BindingShapeCode] = 'derivation' AND [RequiresDerivation] = 1))
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[DerivationContractVersion]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[DerivationContractVersion]
        (
            [DerivationContractVersionId] bigint IDENTITY(1,1) NOT NULL,
            [ExpressionLanguageCode] varchar(64) NOT NULL,
            [ExpressionLanguageVersion] varchar(64) NOT NULL,
            [SourceValueTypeVersionId] bigint NOT NULL,
            [TargetValueTypeVersionId] bigint NOT NULL,
            [SourceMinCardinality] int NOT NULL,
            [SourceMaxCardinality] int NULL,
            [TargetMinCardinality] int NOT NULL,
            [TargetMaxCardinality] int NULL,
            [ValidatorContractCode] varchar(128) NOT NULL,
            [ContractContentHash] binary(32) NOT NULL,
            [PublishedAtUtc] datetime2(7) NOT NULL,
            CONSTRAINT [PK_DerivationContractVersion] PRIMARY KEY CLUSTERED ([DerivationContractVersionId]),
            CONSTRAINT [UQ_DerivationContractVersion_ContractContentHash] UNIQUE ([ContractContentHash]),
            CONSTRAINT [UQ_DerivationContractVersion_DerivationContractVersionId_SourceValueTypeVersionId_TargetValueTypeVersionId]
                UNIQUE ([DerivationContractVersionId], [SourceValueTypeVersionId], [TargetValueTypeVersionId]),
            CONSTRAINT [FK_DerivationContractVersion_ValueTypeVersion_Source] FOREIGN KEY ([SourceValueTypeVersionId])
                REFERENCES [ATAPUtilities].[ValueTypeVersion] ([ValueTypeVersionId]),
            CONSTRAINT [FK_DerivationContractVersion_ValueTypeVersion_Target] FOREIGN KEY ([TargetValueTypeVersionId])
                REFERENCES [ATAPUtilities].[ValueTypeVersion] ([ValueTypeVersionId]),
            CONSTRAINT [CK_DerivationContractVersion_SourceCardinality] CHECK
                ([SourceMinCardinality] >= 0 AND ([SourceMaxCardinality] IS NULL OR [SourceMaxCardinality] >= [SourceMinCardinality])),
            CONSTRAINT [CK_DerivationContractVersion_TargetCardinality] CHECK
                ([TargetMinCardinality] >= 0 AND ([TargetMaxCardinality] IS NULL OR [TargetMaxCardinality] >= [TargetMinCardinality])),
            CONSTRAINT [CK_DerivationContractVersion_ClosedContract] CHECK
                (LEN([ExpressionLanguageCode]) > 0 AND LEN([ExpressionLanguageVersion]) > 0 AND LEN([ValidatorContractCode]) > 0)
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[Rule]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[Rule]
        (
            [RuleId] bigint IDENTITY(1,1) NOT NULL,
            [RulePhiloteId] uniqueidentifier NOT NULL,
            [EntityId] bigint NOT NULL,
            [EntityTypeId] bigint NOT NULL,
            [EntityTypeCode] AS CONVERT(varchar(64), 'rule') PERSISTED,
            [RuleKindId] bigint NOT NULL,
            [RuleCode] varchar(128) NOT NULL,
            [CreatedAtUtc] datetime2(7) NOT NULL,
            CONSTRAINT [PK_Rule] PRIMARY KEY CLUSTERED ([RuleId]),
            CONSTRAINT [UQ_Rule_RulePhiloteId] UNIQUE ([RulePhiloteId]),
            CONSTRAINT [UQ_Rule_RuleId_RuleKindId] UNIQUE ([RuleId], [RuleKindId]),
            CONSTRAINT [UQ_Rule_RuleKindId_RuleCode] UNIQUE ([RuleKindId], [RuleCode]),
            CONSTRAINT [FK_Rule_Entity_Registration] FOREIGN KEY ([EntityId], [EntityTypeId], [RulePhiloteId])
                REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
            CONSTRAINT [FK_Rule_EntityType_ClosedType] FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
                REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
            CONSTRAINT [FK_Rule_RuleKind_Owner] FOREIGN KEY ([RuleKindId])
                REFERENCES [ATAPUtilities].[RuleKind] ([RuleKindId]),
            CONSTRAINT [CK_Rule_RuleCode] CHECK (LEN([RuleCode]) > 0 AND [RuleCode] NOT LIKE '%[^A-Za-z0-9._-]%')
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[RuleVersion]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[RuleVersion]
        (
            [RuleVersionId] bigint IDENTITY(1,1) NOT NULL,
            [RuleVersionPhiloteId] uniqueidentifier NOT NULL,
            [EntityId] bigint NOT NULL,
            [EntityTypeId] bigint NOT NULL,
            [EntityTypeCode] AS CONVERT(varchar(64), 'rule-version') PERSISTED,
            [RuleId] bigint NOT NULL,
            [RuleKindId] bigint NOT NULL,
            [RuleKindVersionId] bigint NOT NULL,
            [RevisionSequence] int NOT NULL,
            [PredecessorRuleVersionId] bigint NULL,
            [CompositionHashAlgorithmCode] varchar(16) NOT NULL,
            [CompositionContentHash] binary(32) NOT NULL,
            [PublishedAtUtc] datetime2(7) NOT NULL,
            CONSTRAINT [PK_RuleVersion] PRIMARY KEY CLUSTERED ([RuleVersionId]),
            CONSTRAINT [UQ_RuleVersion_RuleVersionPhiloteId] UNIQUE ([RuleVersionPhiloteId]),
            CONSTRAINT [UQ_RuleVersion_RuleId_RevisionSequence] UNIQUE ([RuleId], [RevisionSequence]),
            CONSTRAINT [UQ_RuleVersion_PredecessorRuleVersionId] UNIQUE ([PredecessorRuleVersionId]),
            CONSTRAINT [UQ_RuleVersion_RuleVersionId_RuleId] UNIQUE ([RuleVersionId], [RuleId]),
            CONSTRAINT [UQ_RuleVersion_RuleVersionId_RuleKindVersionId] UNIQUE ([RuleVersionId], [RuleKindVersionId]),
            CONSTRAINT [FK_RuleVersion_Entity_Registration] FOREIGN KEY ([EntityId], [EntityTypeId], [RuleVersionPhiloteId])
                REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
            CONSTRAINT [FK_RuleVersion_EntityType_ClosedType] FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
                REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
            CONSTRAINT [FK_RuleVersion_Rule_OwnerKind] FOREIGN KEY ([RuleId], [RuleKindId])
                REFERENCES [ATAPUtilities].[Rule] ([RuleId], [RuleKindId]),
            CONSTRAINT [FK_RuleVersion_RuleKindVersion_ExactKind] FOREIGN KEY ([RuleKindVersionId], [RuleKindId])
                REFERENCES [ATAPUtilities].[RuleKindVersion] ([RuleKindVersionId], [RuleKindId]),
            CONSTRAINT [FK_RuleVersion_RuleVersion_Predecessor] FOREIGN KEY ([PredecessorRuleVersionId], [RuleId])
                REFERENCES [ATAPUtilities].[RuleVersion] ([RuleVersionId], [RuleId]),
            CONSTRAINT [CK_RuleVersion_RevisionSequence] CHECK ([RevisionSequence] > 0),
            CONSTRAINT [CK_RuleVersion_PredecessorNotSelf] CHECK ([PredecessorRuleVersionId] IS NULL OR [PredecessorRuleVersionId] <> [RuleVersionId]),
            CONSTRAINT [CK_RuleVersion_CompositionHash] CHECK ([CompositionHashAlgorithmCode] = 'SHA-256')
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[RuleInputDefinition]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[RuleInputDefinition]
        (
            [RuleInputDefinitionId] bigint IDENTITY(1,1) NOT NULL,
            [RuleInputDefinitionPhiloteId] uniqueidentifier NOT NULL,
            [EntityId] bigint NOT NULL,
            [EntityTypeId] bigint NOT NULL,
            [EntityTypeCode] AS CONVERT(varchar(64), 'rule-input-definition') PERSISTED,
            [RuleVersionId] bigint NOT NULL,
            [InputCode] varchar(128) NOT NULL,
            [Ordinal] int NOT NULL,
            [ValueTypeVersionId] bigint NOT NULL,
            [MinCardinality] int NOT NULL,
            [MaxCardinality] int NULL,
            [AllowsNullElement] bit NOT NULL,
            [ValidationContractCode] varchar(128) NOT NULL,
            CONSTRAINT [PK_RuleInputDefinition] PRIMARY KEY CLUSTERED ([RuleInputDefinitionId]),
            CONSTRAINT [UQ_RuleInputDefinition_RuleInputDefinitionPhiloteId] UNIQUE ([RuleInputDefinitionPhiloteId]),
            CONSTRAINT [UQ_RuleInputDefinition_RuleVersionId_InputCode] UNIQUE ([RuleVersionId], [InputCode]),
            CONSTRAINT [UQ_RuleInputDefinition_RuleVersionId_Ordinal] UNIQUE ([RuleVersionId], [Ordinal]),
            CONSTRAINT [UQ_RuleInputDefinition_RuleInputDefinitionId_RuleVersionId_ValueTypeVersionId]
                UNIQUE ([RuleInputDefinitionId], [RuleVersionId], [ValueTypeVersionId]),
            CONSTRAINT [FK_RuleInputDefinition_Entity_Registration] FOREIGN KEY ([EntityId], [EntityTypeId], [RuleInputDefinitionPhiloteId])
                REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
            CONSTRAINT [FK_RuleInputDefinition_EntityType_ClosedType] FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
                REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
            CONSTRAINT [FK_RuleInputDefinition_RuleVersion_Owner] FOREIGN KEY ([RuleVersionId])
                REFERENCES [ATAPUtilities].[RuleVersion] ([RuleVersionId]),
            CONSTRAINT [FK_RuleInputDefinition_ValueTypeVersion_Type] FOREIGN KEY ([ValueTypeVersionId])
                REFERENCES [ATAPUtilities].[ValueTypeVersion] ([ValueTypeVersionId]),
            CONSTRAINT [CK_RuleInputDefinition_Ordinal] CHECK ([Ordinal] >= 0),
            CONSTRAINT [CK_RuleInputDefinition_Cardinality] CHECK
                ([MinCardinality] >= 0 AND ([MaxCardinality] IS NULL OR [MaxCardinality] >= [MinCardinality])),
            CONSTRAINT [CK_RuleInputDefinition_Codes] CHECK (LEN([InputCode]) > 0 AND LEN([ValidationContractCode]) > 0)
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[RuleDefaultInputValue]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[RuleDefaultInputValue]
        (
            [RuleDefaultInputValueId] bigint IDENTITY(1,1) NOT NULL,
            [RuleDefaultInputValuePhiloteId] uniqueidentifier NOT NULL,
            [EntityId] bigint NOT NULL,
            [EntityTypeId] bigint NOT NULL,
            [EntityTypeCode] AS CONVERT(varchar(64), 'rule-default-input-value') PERSISTED,
            [RuleInputDefinitionId] bigint NOT NULL,
            [RuleVersionId] bigint NOT NULL,
            [ValueTypeVersionId] bigint NOT NULL,
            [CanonicalTextValue] nvarchar(4000) NULL,
            [CanonicalIntegerValue] bigint NULL,
            [CanonicalDecimalValue] decimal(38,18) NULL,
            [CanonicalBooleanValue] bit NULL,
            [CanonicalUtcValue] datetime2(7) NULL,
            [CanonicalIdentifierValue] uniqueidentifier NULL,
            [CanonicalBinaryValue] varbinary(max) NULL,
            [StructuredPayload] nvarchar(max) NULL,
            [SecretName] nvarchar(256) NULL,
            [CanonicalValueHash] binary(32) NOT NULL,
            [RationaleEntityId] bigint NOT NULL,
            [RationaleEntityTypeId] bigint NOT NULL,
            [PublishedAtUtc] datetime2(7) NOT NULL,
            CONSTRAINT [PK_RuleDefaultInputValue] PRIMARY KEY CLUSTERED ([RuleDefaultInputValueId]),
            CONSTRAINT [UQ_RuleDefaultInputValue_RuleDefaultInputValuePhiloteId] UNIQUE ([RuleDefaultInputValuePhiloteId]),
            CONSTRAINT [UQ_RuleDefaultInputValue_RuleInputDefinitionId] UNIQUE ([RuleInputDefinitionId]),
            CONSTRAINT [FK_RuleDefaultInputValue_Entity_Registration] FOREIGN KEY ([EntityId], [EntityTypeId], [RuleDefaultInputValuePhiloteId])
                REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
            CONSTRAINT [FK_RuleDefaultInputValue_EntityType_ClosedType] FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
                REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
            CONSTRAINT [FK_RuleDefaultInputValue_RuleInputDefinition_ExactInputType] FOREIGN KEY
                ([RuleInputDefinitionId], [RuleVersionId], [ValueTypeVersionId]) REFERENCES [ATAPUtilities].[RuleInputDefinition]
                ([RuleInputDefinitionId], [RuleVersionId], [ValueTypeVersionId]),
            CONSTRAINT [FK_RuleDefaultInputValue_Entity_Rationale] FOREIGN KEY ([RationaleEntityId], [RationaleEntityTypeId])
                REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
            CONSTRAINT [CK_RuleDefaultInputValue_ExactlyOneTypedValue] CHECK
                (CONVERT(tinyint, CASE WHEN [CanonicalTextValue] IS NULL THEN 0 ELSE 1 END)
                 + CONVERT(tinyint, CASE WHEN [CanonicalIntegerValue] IS NULL THEN 0 ELSE 1 END)
                 + CONVERT(tinyint, CASE WHEN [CanonicalDecimalValue] IS NULL THEN 0 ELSE 1 END)
                 + CONVERT(tinyint, CASE WHEN [CanonicalBooleanValue] IS NULL THEN 0 ELSE 1 END)
                 + CONVERT(tinyint, CASE WHEN [CanonicalUtcValue] IS NULL THEN 0 ELSE 1 END)
                 + CONVERT(tinyint, CASE WHEN [CanonicalIdentifierValue] IS NULL THEN 0 ELSE 1 END)
                 + CONVERT(tinyint, CASE WHEN [CanonicalBinaryValue] IS NULL THEN 0 ELSE 1 END)
                 + CONVERT(tinyint, CASE WHEN [StructuredPayload] IS NULL THEN 0 ELSE 1 END)
                 + CONVERT(tinyint, CASE WHEN [SecretName] IS NULL THEN 0 ELSE 1 END) = 1),
            CONSTRAINT [CK_RuleDefaultInputValue_StructuredPayloadJson] CHECK ([StructuredPayload] IS NULL OR ISJSON([StructuredPayload]) = 1),
            CONSTRAINT [CK_RuleDefaultInputValue_SecretNameOpaque] CHECK
                ([SecretName] IS NULL OR ([SecretName] NOT LIKE '%=%' AND [SecretName] NOT LIKE '%;%' AND LEN([SecretName]) BETWEEN 3 AND 256))
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[RuleOutputDefinition]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[RuleOutputDefinition]
        (
            [RuleOutputDefinitionId] bigint IDENTITY(1,1) NOT NULL,
            [RuleOutputDefinitionPhiloteId] uniqueidentifier NOT NULL,
            [EntityId] bigint NOT NULL,
            [EntityTypeId] bigint NOT NULL,
            [EntityTypeCode] AS CONVERT(varchar(64), 'rule-output-definition') PERSISTED,
            [RuleVersionId] bigint NOT NULL,
            [OutputCode] varchar(128) NOT NULL,
            [Ordinal] int NOT NULL,
            [ValueTypeVersionId] bigint NOT NULL,
            [MinCardinality] int NOT NULL,
            [MaxCardinality] int NULL,
            [OutputDispositionCode] varchar(32) NOT NULL,
            [MediaTypePolicyCode] varchar(32) NOT NULL,
            [ArtifactLocatorPolicyCode] varchar(32) NOT NULL,
            [HashExpectationPolicyCode] varchar(32) NOT NULL,
            CONSTRAINT [PK_RuleOutputDefinition] PRIMARY KEY CLUSTERED ([RuleOutputDefinitionId]),
            CONSTRAINT [UQ_RuleOutputDefinition_RuleOutputDefinitionPhiloteId] UNIQUE ([RuleOutputDefinitionPhiloteId]),
            CONSTRAINT [UQ_RuleOutputDefinition_RuleVersionId_OutputCode] UNIQUE ([RuleVersionId], [OutputCode]),
            CONSTRAINT [UQ_RuleOutputDefinition_RuleVersionId_Ordinal] UNIQUE ([RuleVersionId], [Ordinal]),
            CONSTRAINT [UQ_RuleOutputDefinition_RuleOutputDefinitionId_RuleVersionId_ValueTypeVersionId]
                UNIQUE ([RuleOutputDefinitionId], [RuleVersionId], [ValueTypeVersionId]),
            CONSTRAINT [FK_RuleOutputDefinition_Entity_Registration] FOREIGN KEY ([EntityId], [EntityTypeId], [RuleOutputDefinitionPhiloteId])
                REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
            CONSTRAINT [FK_RuleOutputDefinition_EntityType_ClosedType] FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
                REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
            CONSTRAINT [FK_RuleOutputDefinition_RuleVersion_Owner] FOREIGN KEY ([RuleVersionId])
                REFERENCES [ATAPUtilities].[RuleVersion] ([RuleVersionId]),
            CONSTRAINT [FK_RuleOutputDefinition_ValueTypeVersion_Type] FOREIGN KEY ([ValueTypeVersionId])
                REFERENCES [ATAPUtilities].[ValueTypeVersion] ([ValueTypeVersionId]),
            CONSTRAINT [CK_RuleOutputDefinition_Ordinal] CHECK ([Ordinal] >= 0),
            CONSTRAINT [CK_RuleOutputDefinition_Cardinality] CHECK
                ([MinCardinality] >= 0 AND ([MaxCardinality] IS NULL OR [MaxCardinality] >= [MinCardinality])),
            CONSTRAINT [CK_RuleOutputDefinition_ClosedPolicies] CHECK
                ([OutputDispositionCode] IN ('scalar','stream','artifact')
                 AND [MediaTypePolicyCode] IN ('declared','none')
                 AND [ArtifactLocatorPolicyCode] IN ('executor-assigned','none')
                 AND [HashExpectationPolicyCode] IN ('required','optional','none'))
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[RuleVersionNode]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[RuleVersionNode]
        (
            [RuleVersionNodeId] bigint IDENTITY(1,1) NOT NULL,
            [RuleVersionNodePhiloteId] uniqueidentifier NOT NULL,
            [RuleVersionId] bigint NOT NULL,
            [RuleKindVersionId] bigint NOT NULL,
            [ParentRuleVersionNodeId] bigint NULL,
            [Ordinal] int NOT NULL,
            [PrimitiveVersionId] bigint NOT NULL,
            [MinOccurs] int NOT NULL,
            [MaxOccurs] int NULL,
            [ChoiceDiscriminatorCode] varchar(64) NULL,
            [NodeLabel] nvarchar(256) NULL,
            CONSTRAINT [PK_RuleVersionNode] PRIMARY KEY CLUSTERED ([RuleVersionNodeId]),
            CONSTRAINT [UQ_RuleVersionNode_RuleVersionNodePhiloteId] UNIQUE ([RuleVersionNodePhiloteId]),
            CONSTRAINT [UQ_RuleVersionNode_RuleVersionNodeId_RuleVersionId] UNIQUE ([RuleVersionNodeId], [RuleVersionId]),
            CONSTRAINT [UQ_RuleVersionNode_RuleVersionNodeId_RuleVersionId_PrimitiveVersionId]
                UNIQUE ([RuleVersionNodeId], [RuleVersionId], [PrimitiveVersionId]),
            CONSTRAINT [UQ_RuleVersionNode_RuleVersionId_ParentRuleVersionNodeId_Ordinal]
                UNIQUE ([RuleVersionId], [ParentRuleVersionNodeId], [Ordinal]),
            CONSTRAINT [FK_RuleVersionNode_RuleVersion_ExactKind] FOREIGN KEY ([RuleVersionId], [RuleKindVersionId])
                REFERENCES [ATAPUtilities].[RuleVersion] ([RuleVersionId], [RuleKindVersionId]),
            CONSTRAINT [FK_RuleVersionNode_PrimitiveVersion_ExactKind] FOREIGN KEY ([PrimitiveVersionId], [RuleKindVersionId])
                REFERENCES [ATAPUtilities].[PrimitiveVersion] ([PrimitiveVersionId], [RuleKindVersionId]),
            CONSTRAINT [FK_RuleVersionNode_RuleVersionNode_Parent] FOREIGN KEY ([ParentRuleVersionNodeId], [RuleVersionId])
                REFERENCES [ATAPUtilities].[RuleVersionNode] ([RuleVersionNodeId], [RuleVersionId]),
            CONSTRAINT [CK_RuleVersionNode_RootAndOrdinal] CHECK
                (([ParentRuleVersionNodeId] IS NULL AND [Ordinal] = 0)
                 OR ([ParentRuleVersionNodeId] IS NOT NULL AND [Ordinal] >= 0)),
            CONSTRAINT [CK_RuleVersionNode_ParentNotSelf] CHECK
                ([ParentRuleVersionNodeId] IS NULL OR [ParentRuleVersionNodeId] <> [RuleVersionNodeId]),
            CONSTRAINT [CK_RuleVersionNode_OccurrenceBounds] CHECK
                ([MinOccurs] >= 0 AND ([MaxOccurs] IS NULL OR [MaxOccurs] >= [MinOccurs])),
            CONSTRAINT [CK_RuleVersionNode_ChoiceFailsClosed] CHECK ([ChoiceDiscriminatorCode] IS NULL)
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[RuleVersionNodeInput]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[RuleVersionNodeInput]
        (
            [RuleVersionNodeInputId] bigint IDENTITY(1,1) NOT NULL,
            [RuleVersionNodeId] bigint NOT NULL,
            [RuleVersionId] bigint NOT NULL,
            [PrimitiveVersionId] bigint NOT NULL,
            [PrimitiveInputDefinitionId] bigint NOT NULL,
            [BindingShapeCode] varchar(32) NOT NULL,
            [TargetValueTypeVersionId] bigint NOT NULL,
            [SourceValueTypeVersionId] bigint NULL,
            [ConstantValueTypeVersionId] bigint NULL,
            [RuleInputDefinitionId] bigint NULL,
            [DerivationContractVersionId] bigint NULL,
            [SourceRuleVersionNodeId] bigint NULL,
            [SourceRuleInputDefinitionId] bigint NULL,
            [SourceRuleOutputDefinitionId] bigint NULL,
            [ConversionPolicyCode] varchar(32) NULL,
            [CanonicalTextValue] nvarchar(4000) NULL,
            [CanonicalIntegerValue] bigint NULL,
            [CanonicalDecimalValue] decimal(38,18) NULL,
            [CanonicalBooleanValue] bit NULL,
            [CanonicalUtcValue] datetime2(7) NULL,
            [CanonicalIdentifierValue] uniqueidentifier NULL,
            [CanonicalBinaryValue] varbinary(max) NULL,
            [StructuredPayload] nvarchar(max) NULL,
            [SecretName] nvarchar(256) NULL,
            [CanonicalValueHash] binary(32) NOT NULL,
            CONSTRAINT [PK_RuleVersionNodeInput] PRIMARY KEY CLUSTERED ([RuleVersionNodeInputId]),
            CONSTRAINT [UQ_RuleVersionNodeInput_RuleVersionNodeId_PrimitiveInputDefinitionId]
                UNIQUE ([RuleVersionNodeId], [PrimitiveInputDefinitionId]),
            CONSTRAINT [FK_RuleVersionNodeInput_RuleVersionNode_Target] FOREIGN KEY
                ([RuleVersionNodeId], [RuleVersionId], [PrimitiveVersionId]) REFERENCES [ATAPUtilities].[RuleVersionNode]
                ([RuleVersionNodeId], [RuleVersionId], [PrimitiveVersionId]),
            CONSTRAINT [FK_RuleVersionNodeInput_PrimitiveInputDefinition_ExactTarget] FOREIGN KEY
                ([PrimitiveInputDefinitionId], [PrimitiveVersionId], [TargetValueTypeVersionId]) REFERENCES [ATAPUtilities].[PrimitiveInputDefinition]
                ([PrimitiveInputDefinitionId], [PrimitiveVersionId], [ValueTypeVersionId]),
            CONSTRAINT [FK_RuleVersionNodeInput_BindingShape_Shape] FOREIGN KEY ([BindingShapeCode])
                REFERENCES [ATAPUtilities].[BindingShape] ([BindingShapeCode]),
            CONSTRAINT [FK_RuleVersionNodeInput_ValueTypeVersion_ConstantType] FOREIGN KEY ([ConstantValueTypeVersionId])
                REFERENCES [ATAPUtilities].[ValueTypeVersion] ([ValueTypeVersionId]),
            CONSTRAINT [FK_RuleVersionNodeInput_RuleInputDefinition_ExactSource] FOREIGN KEY
                ([RuleInputDefinitionId], [RuleVersionId], [SourceValueTypeVersionId]) REFERENCES [ATAPUtilities].[RuleInputDefinition]
                ([RuleInputDefinitionId], [RuleVersionId], [ValueTypeVersionId]),
            CONSTRAINT [FK_RuleVersionNodeInput_DerivationContractVersion_ExactTypes] FOREIGN KEY
                ([DerivationContractVersionId], [SourceValueTypeVersionId], [TargetValueTypeVersionId]) REFERENCES [ATAPUtilities].[DerivationContractVersion]
                ([DerivationContractVersionId], [SourceValueTypeVersionId], [TargetValueTypeVersionId]),
            CONSTRAINT [FK_RuleVersionNodeInput_RuleVersionNode_Source] FOREIGN KEY ([SourceRuleVersionNodeId], [RuleVersionId])
                REFERENCES [ATAPUtilities].[RuleVersionNode] ([RuleVersionNodeId], [RuleVersionId]),
            CONSTRAINT [FK_RuleVersionNodeInput_RuleInputDefinition_Source] FOREIGN KEY ([SourceRuleInputDefinitionId], [RuleVersionId], [SourceValueTypeVersionId])
                REFERENCES [ATAPUtilities].[RuleInputDefinition] ([RuleInputDefinitionId], [RuleVersionId], [ValueTypeVersionId]),
            CONSTRAINT [FK_RuleVersionNodeInput_RuleOutputDefinition_Source] FOREIGN KEY ([SourceRuleOutputDefinitionId], [RuleVersionId], [SourceValueTypeVersionId])
                REFERENCES [ATAPUtilities].[RuleOutputDefinition] ([RuleOutputDefinitionId], [RuleVersionId], [ValueTypeVersionId]),
            CONSTRAINT [CK_RuleVersionNodeInput_DiscriminatedShape] CHECK
            (
                ([BindingShapeCode] = 'constant'
                 AND [ConstantValueTypeVersionId] = [TargetValueTypeVersionId]
                 AND [RuleInputDefinitionId] IS NULL AND [DerivationContractVersionId] IS NULL
                 AND [SourceValueTypeVersionId] IS NULL AND [ConversionPolicyCode] IS NULL
                 AND [SourceRuleVersionNodeId] IS NULL AND [SourceRuleInputDefinitionId] IS NULL AND [SourceRuleOutputDefinitionId] IS NULL)
                OR
                ([BindingShapeCode] = 'rule-input'
                 AND [ConstantValueTypeVersionId] IS NULL AND [RuleInputDefinitionId] IS NOT NULL
                 AND [DerivationContractVersionId] IS NULL AND [SourceValueTypeVersionId] = [TargetValueTypeVersionId]
                 AND [ConversionPolicyCode] = 'exact'
                 AND [SourceRuleVersionNodeId] IS NULL AND [SourceRuleInputDefinitionId] IS NULL AND [SourceRuleOutputDefinitionId] IS NULL)
                OR
                ([BindingShapeCode] = 'derivation'
                 AND [ConstantValueTypeVersionId] IS NULL AND [RuleInputDefinitionId] IS NULL
                 AND [DerivationContractVersionId] IS NOT NULL AND [SourceValueTypeVersionId] IS NOT NULL
                 AND [ConversionPolicyCode] = 'contract'
                 AND (CONVERT(tinyint, CASE WHEN [SourceRuleVersionNodeId] IS NULL THEN 0 ELSE 1 END)
                      + CONVERT(tinyint, CASE WHEN [SourceRuleInputDefinitionId] IS NULL THEN 0 ELSE 1 END)
                      + CONVERT(tinyint, CASE WHEN [SourceRuleOutputDefinitionId] IS NULL THEN 0 ELSE 1 END) = 1))
            ),
            CONSTRAINT [CK_RuleVersionNodeInput_ConstantTypedValue] CHECK
            (
                ([BindingShapeCode] <> 'constant'
                 AND [CanonicalTextValue] IS NULL AND [CanonicalIntegerValue] IS NULL AND [CanonicalDecimalValue] IS NULL
                 AND [CanonicalBooleanValue] IS NULL AND [CanonicalUtcValue] IS NULL AND [CanonicalIdentifierValue] IS NULL
                 AND [CanonicalBinaryValue] IS NULL AND [StructuredPayload] IS NULL AND [SecretName] IS NULL)
                OR
                ([BindingShapeCode] = 'constant'
                 AND CONVERT(tinyint, CASE WHEN [CanonicalTextValue] IS NULL THEN 0 ELSE 1 END)
                   + CONVERT(tinyint, CASE WHEN [CanonicalIntegerValue] IS NULL THEN 0 ELSE 1 END)
                   + CONVERT(tinyint, CASE WHEN [CanonicalDecimalValue] IS NULL THEN 0 ELSE 1 END)
                   + CONVERT(tinyint, CASE WHEN [CanonicalBooleanValue] IS NULL THEN 0 ELSE 1 END)
                   + CONVERT(tinyint, CASE WHEN [CanonicalUtcValue] IS NULL THEN 0 ELSE 1 END)
                   + CONVERT(tinyint, CASE WHEN [CanonicalIdentifierValue] IS NULL THEN 0 ELSE 1 END)
                   + CONVERT(tinyint, CASE WHEN [CanonicalBinaryValue] IS NULL THEN 0 ELSE 1 END)
                   + CONVERT(tinyint, CASE WHEN [StructuredPayload] IS NULL THEN 0 ELSE 1 END)
                   + CONVERT(tinyint, CASE WHEN [SecretName] IS NULL THEN 0 ELSE 1 END) = 1)
            ),
            CONSTRAINT [CK_RuleVersionNodeInput_StructuredPayloadJson] CHECK ([StructuredPayload] IS NULL OR ISJSON([StructuredPayload]) = 1),
            CONSTRAINT [CK_RuleVersionNodeInput_SecretNameOpaque] CHECK
                ([SecretName] IS NULL OR ([SecretName] NOT LIKE '%=%' AND [SecretName] NOT LIKE '%;%' AND LEN([SecretName]) BETWEEN 3 AND 256))
        );
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE [object_id] = OBJECT_ID(N'[ATAPUtilities].[RuleVersionNode]') AND [name] = N'IX_RuleVersionNode_RuleVersionId_PrimitiveVersionId')
        CREATE INDEX [IX_RuleVersionNode_RuleVersionId_PrimitiveVersionId]
            ON [ATAPUtilities].[RuleVersionNode] ([RuleVersionId], [PrimitiveVersionId]);
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE [object_id] = OBJECT_ID(N'[ATAPUtilities].[RuleVersionNodeInput]') AND [name] = N'IX_RuleVersionNodeInput_PrimitiveInputDefinitionId')
        CREATE INDEX [IX_RuleVersionNodeInput_PrimitiveInputDefinitionId]
            ON [ATAPUtilities].[RuleVersionNodeInput] ([PrimitiveInputDefinitionId]);
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE [object_id] = OBJECT_ID(N'[ATAPUtilities].[RuleInputDefinition]') AND [name] = N'IX_RuleInputDefinition_ValueTypeVersionId')
        CREATE INDEX [IX_RuleInputDefinition_ValueTypeVersionId]
            ON [ATAPUtilities].[RuleInputDefinition] ([ValueTypeVersionId]);
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE [object_id] = OBJECT_ID(N'[ATAPUtilities].[RuleOutputDefinition]') AND [name] = N'IX_RuleOutputDefinition_ValueTypeVersionId')
        CREATE INDEX [IX_RuleOutputDefinition_ValueTypeVersionId]
            ON [ATAPUtilities].[RuleOutputDefinition] ([ValueTypeVersionId]);

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_RuleVersionNode_CompositionIntegrity]
ON [ATAPUtilities].[RuleVersionNode]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 52420, ''Published RuleVersionNode rows are immutable.'', 1;

    IF EXISTS
    (
        SELECT n.RuleVersionId
        FROM [ATAPUtilities].[RuleVersionNode] AS n
        WHERE n.RuleVersionId IN (SELECT RuleVersionId FROM inserted)
        GROUP BY n.RuleVersionId
        HAVING SUM(CASE WHEN n.ParentRuleVersionNodeId IS NULL THEN 1 ELSE 0 END) <> 1
    ) THROW 52421, ''A RuleVersion composition must have exactly one root.'', 1;

    IF EXISTS
    (
        SELECT n.RuleVersionId, n.ParentRuleVersionNodeId
        FROM [ATAPUtilities].[RuleVersionNode] AS n
        WHERE n.RuleVersionId IN (SELECT RuleVersionId FROM inserted)
        GROUP BY n.RuleVersionId, n.ParentRuleVersionNodeId
        HAVING MIN(n.Ordinal) <> 0 OR MAX(n.Ordinal) <> COUNT_BIG(*) - 1
    ) THROW 52422, ''Sibling ordinals must be zero-based and gap-free.'', 1;

    ;WITH reachable AS
    (
        SELECT n.RuleVersionNodeId, n.RuleVersionId
        FROM [ATAPUtilities].[RuleVersionNode] AS n
        WHERE n.RuleVersionId IN (SELECT RuleVersionId FROM inserted)
          AND n.ParentRuleVersionNodeId IS NULL
        UNION ALL
        SELECT child.RuleVersionNodeId, child.RuleVersionId
        FROM [ATAPUtilities].[RuleVersionNode] AS child
        INNER JOIN reachable AS parent
            ON parent.RuleVersionNodeId = child.ParentRuleVersionNodeId
           AND parent.RuleVersionId = child.RuleVersionId
    )
    SELECT 1 AS TraversalComplete
    INTO #Rdb420Reachable
    FROM reachable
    OPTION (MAXRECURSION 32767);

    IF (SELECT COUNT_BIG(*) FROM #Rdb420Reachable) <
       (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionId IN (SELECT RuleVersionId FROM inserted))
        THROW 52423, ''RuleVersionNode graph contains a cycle or unreachable node.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_Rule_Immutable]
ON [ATAPUtilities].[Rule]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 52424, ''Published RDB-420 rows are immutable; publish a successor.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_RuleVersion_Immutable]
ON [ATAPUtilities].[RuleVersion]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 52424, ''Published RDB-420 rows are immutable; publish a successor.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_RuleVersionNodeInput_Immutable]
ON [ATAPUtilities].[RuleVersionNodeInput]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 52424, ''Published RDB-420 rows are immutable; publish a successor.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_BindingShape_Immutable]
ON [ATAPUtilities].[BindingShape]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 52424, ''Published RDB-420 rows are immutable; publish a successor.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_DerivationContractVersion_Immutable]
ON [ATAPUtilities].[DerivationContractVersion]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 52424, ''Published RDB-420 rows are immutable; publish a successor.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_RuleInputDefinition_Immutable]
ON [ATAPUtilities].[RuleInputDefinition]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 52424, ''Published RDB-420 rows are immutable; publish a successor.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_RuleDefaultInputValue_Immutable]
ON [ATAPUtilities].[RuleDefaultInputValue]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 52424, ''Published RDB-420 rows are immutable; publish a successor.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_RuleOutputDefinition_Immutable]
ON [ATAPUtilities].[RuleOutputDefinition]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 52424, ''Published RDB-420 rows are immutable; publish a successor.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [ATAPUtilities].[usp_PublishRuleVersionGraph]
    @RuleVersionPhiloteId uniqueidentifier,
    @EntityId bigint,
    @EntityTypeId bigint,
    @RuleId bigint,
    @RuleKindVersionId bigint,
    @RevisionSequence int,
    @PredecessorRuleVersionId bigint = NULL,
    @CompositionContentHash binary(32),
    @PublishedAtUtc datetime2(7),
    @RuleInputsJson nvarchar(max) = N''[]'',
    @RuleDefaultsJson nvarchar(max) = N''[]'',
    @RuleOutputsJson nvarchar(max) = N''[]'',
    @NodesJson nvarchar(max),
    @NodeInputsJson nvarchar(max) = N''[]'',
    @RuleVersionId bigint OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT <> 0 THROW 52433, ''Publication procedures require no ambient transaction.'', 1;

    DECLARE @RuleKindId bigint;
    DECLARE @RowsInserted int;
    DECLARE @NowUtc datetime2(7) = SYSUTCDATETIME();

    DECLARE @RuleInputs table
    (
        PhiloteId uniqueidentifier NOT NULL PRIMARY KEY, EntityId bigint NOT NULL, EntityTypeId bigint NOT NULL,
        InputCode varchar(128) NOT NULL, Ordinal int NOT NULL, ValueTypeVersionId bigint NOT NULL,
        MinCardinality int NOT NULL, MaxCardinality int NULL, AllowsNullElement bit NOT NULL,
        ValidationContractCode varchar(128) NOT NULL
    );
    DECLARE @RuleDefaults table
    (
        PhiloteId uniqueidentifier NOT NULL PRIMARY KEY, EntityId bigint NOT NULL, EntityTypeId bigint NOT NULL,
        RuleInputPhiloteId uniqueidentifier NOT NULL, CanonicalTextValue nvarchar(4000) NULL,
        CanonicalIntegerValue bigint NULL, CanonicalDecimalValue decimal(38,18) NULL,
        CanonicalBooleanValue bit NULL, CanonicalUtcValue datetime2(7) NULL,
        CanonicalIdentifierValue uniqueidentifier NULL, CanonicalBinaryHex varchar(max) NULL,
        StructuredPayload nvarchar(max) NULL, SecretName nvarchar(256) NULL,
        CanonicalValueHashHex varchar(64) NOT NULL, RationaleEntityId bigint NOT NULL,
        RationaleEntityTypeId bigint NOT NULL, PublishedAtUtc datetime2(7) NOT NULL
    );
    DECLARE @RuleOutputs table
    (
        PhiloteId uniqueidentifier NOT NULL PRIMARY KEY, EntityId bigint NOT NULL, EntityTypeId bigint NOT NULL,
        OutputCode varchar(128) NOT NULL, Ordinal int NOT NULL, ValueTypeVersionId bigint NOT NULL,
        MinCardinality int NOT NULL, MaxCardinality int NULL, OutputDispositionCode varchar(32) NOT NULL,
        MediaTypePolicyCode varchar(32) NOT NULL, ArtifactLocatorPolicyCode varchar(32) NOT NULL,
        HashExpectationPolicyCode varchar(32) NOT NULL
    );
    DECLARE @Nodes table
    (
        PhiloteId uniqueidentifier NOT NULL PRIMARY KEY, ParentPhiloteId uniqueidentifier NULL,
        Ordinal int NOT NULL, PrimitiveVersionId bigint NOT NULL, MinOccurs int NOT NULL,
        MaxOccurs int NULL, ChoiceDiscriminatorCode varchar(64) NULL, NodeLabel nvarchar(256) NULL
    );
    DECLARE @NodeInputs table
    (
        NodePhiloteId uniqueidentifier NOT NULL, PrimitiveInputDefinitionId bigint NOT NULL,
        BindingShapeCode varchar(32) NOT NULL, TargetValueTypeVersionId bigint NOT NULL,
        SourceValueTypeVersionId bigint NULL, ConstantValueTypeVersionId bigint NULL,
        RuleInputPhiloteId uniqueidentifier NULL, DerivationContractVersionId bigint NULL,
        SourceNodePhiloteId uniqueidentifier NULL, SourceRuleInputPhiloteId uniqueidentifier NULL,
        SourceRuleOutputPhiloteId uniqueidentifier NULL, ConversionPolicyCode varchar(32) NULL,
        CanonicalTextValue nvarchar(4000) NULL, CanonicalIntegerValue bigint NULL,
        CanonicalDecimalValue decimal(38,18) NULL, CanonicalBooleanValue bit NULL,
        CanonicalUtcValue datetime2(7) NULL, CanonicalIdentifierValue uniqueidentifier NULL,
        CanonicalBinaryHex varchar(max) NULL, StructuredPayload nvarchar(max) NULL,
        SecretName nvarchar(256) NULL, CanonicalValueHashHex varchar(64) NOT NULL,
        PRIMARY KEY (NodePhiloteId, PrimitiveInputDefinitionId)
    );

    IF ISJSON(@RuleInputsJson) <> 1 OR ISJSON(@RuleDefaultsJson) <> 1
       OR ISJSON(@RuleOutputsJson) <> 1 OR ISJSON(@NodesJson) <> 1 OR ISJSON(@NodeInputsJson) <> 1
        THROW 52425, ''RuleVersion publication payloads must be valid JSON arrays.'', 1;

    INSERT @RuleInputs
    SELECT * FROM OPENJSON(@RuleInputsJson) WITH
    (PhiloteId uniqueidentifier ''$.PhiloteId'', EntityId bigint ''$.EntityId'', EntityTypeId bigint ''$.EntityTypeId'',
     InputCode varchar(128) ''$.InputCode'', Ordinal int ''$.Ordinal'', ValueTypeVersionId bigint ''$.ValueTypeVersionId'',
     MinCardinality int ''$.MinCardinality'', MaxCardinality int ''$.MaxCardinality'', AllowsNullElement bit ''$.AllowsNullElement'',
     ValidationContractCode varchar(128) ''$.ValidationContractCode'');
    INSERT @RuleDefaults
    SELECT * FROM OPENJSON(@RuleDefaultsJson) WITH
    (PhiloteId uniqueidentifier ''$.PhiloteId'', EntityId bigint ''$.EntityId'', EntityTypeId bigint ''$.EntityTypeId'',
     RuleInputPhiloteId uniqueidentifier ''$.RuleInputPhiloteId'', CanonicalTextValue nvarchar(4000) ''$.CanonicalTextValue'',
     CanonicalIntegerValue bigint ''$.CanonicalIntegerValue'', CanonicalDecimalValue decimal(38,18) ''$.CanonicalDecimalValue'',
     CanonicalBooleanValue bit ''$.CanonicalBooleanValue'', CanonicalUtcValue datetime2(7) ''$.CanonicalUtcValue'',
     CanonicalIdentifierValue uniqueidentifier ''$.CanonicalIdentifierValue'', CanonicalBinaryHex varchar(max) ''$.CanonicalBinaryHex'',
     StructuredPayload nvarchar(max) ''$.StructuredPayload'' AS JSON, SecretName nvarchar(256) ''$.SecretName'',
     CanonicalValueHashHex varchar(64) ''$.CanonicalValueHashHex'', RationaleEntityId bigint ''$.RationaleEntityId'',
     RationaleEntityTypeId bigint ''$.RationaleEntityTypeId'', PublishedAtUtc datetime2(7) ''$.PublishedAtUtc'');
    INSERT @RuleOutputs
    SELECT * FROM OPENJSON(@RuleOutputsJson) WITH
    (PhiloteId uniqueidentifier ''$.PhiloteId'', EntityId bigint ''$.EntityId'', EntityTypeId bigint ''$.EntityTypeId'',
     OutputCode varchar(128) ''$.OutputCode'', Ordinal int ''$.Ordinal'', ValueTypeVersionId bigint ''$.ValueTypeVersionId'',
     MinCardinality int ''$.MinCardinality'', MaxCardinality int ''$.MaxCardinality'',
     OutputDispositionCode varchar(32) ''$.OutputDispositionCode'', MediaTypePolicyCode varchar(32) ''$.MediaTypePolicyCode'',
     ArtifactLocatorPolicyCode varchar(32) ''$.ArtifactLocatorPolicyCode'', HashExpectationPolicyCode varchar(32) ''$.HashExpectationPolicyCode'');
    INSERT @Nodes
    SELECT * FROM OPENJSON(@NodesJson) WITH
    (PhiloteId uniqueidentifier ''$.PhiloteId'', ParentPhiloteId uniqueidentifier ''$.ParentPhiloteId'', Ordinal int ''$.Ordinal'',
     PrimitiveVersionId bigint ''$.PrimitiveVersionId'', MinOccurs int ''$.MinOccurs'', MaxOccurs int ''$.MaxOccurs'',
     ChoiceDiscriminatorCode varchar(64) ''$.ChoiceDiscriminatorCode'', NodeLabel nvarchar(256) ''$.NodeLabel'');
    INSERT @NodeInputs
    SELECT * FROM OPENJSON(@NodeInputsJson) WITH
    (NodePhiloteId uniqueidentifier ''$.NodePhiloteId'', PrimitiveInputDefinitionId bigint ''$.PrimitiveInputDefinitionId'',
     BindingShapeCode varchar(32) ''$.BindingShapeCode'', TargetValueTypeVersionId bigint ''$.TargetValueTypeVersionId'',
     SourceValueTypeVersionId bigint ''$.SourceValueTypeVersionId'', ConstantValueTypeVersionId bigint ''$.ConstantValueTypeVersionId'',
     RuleInputPhiloteId uniqueidentifier ''$.RuleInputPhiloteId'', DerivationContractVersionId bigint ''$.DerivationContractVersionId'',
     SourceNodePhiloteId uniqueidentifier ''$.SourceNodePhiloteId'', SourceRuleInputPhiloteId uniqueidentifier ''$.SourceRuleInputPhiloteId'',
     SourceRuleOutputPhiloteId uniqueidentifier ''$.SourceRuleOutputPhiloteId'', ConversionPolicyCode varchar(32) ''$.ConversionPolicyCode'',
     CanonicalTextValue nvarchar(4000) ''$.CanonicalTextValue'', CanonicalIntegerValue bigint ''$.CanonicalIntegerValue'',
     CanonicalDecimalValue decimal(38,18) ''$.CanonicalDecimalValue'', CanonicalBooleanValue bit ''$.CanonicalBooleanValue'',
     CanonicalUtcValue datetime2(7) ''$.CanonicalUtcValue'', CanonicalIdentifierValue uniqueidentifier ''$.CanonicalIdentifierValue'',
     CanonicalBinaryHex varchar(max) ''$.CanonicalBinaryHex'', StructuredPayload nvarchar(max) ''$.StructuredPayload'' AS JSON,
     SecretName nvarchar(256) ''$.SecretName'', CanonicalValueHashHex varchar(64) ''$.CanonicalValueHashHex'');

    IF NOT EXISTS (SELECT 1 FROM @Nodes)
       OR (SELECT COUNT_BIG(*) FROM @Nodes WHERE ParentPhiloteId IS NULL) <> 1
       OR EXISTS (SELECT 1 FROM @Nodes AS n WHERE n.ParentPhiloteId = n.PhiloteId)
       OR EXISTS (SELECT 1 FROM @Nodes AS n WHERE n.ParentPhiloteId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM @Nodes AS p WHERE p.PhiloteId = n.ParentPhiloteId))
       OR EXISTS (SELECT ParentPhiloteId FROM @Nodes GROUP BY ParentPhiloteId HAVING MIN(Ordinal) <> 0 OR MAX(Ordinal) <> COUNT_BIG(*) - 1)
        THROW 52426, ''RuleVersion publication requires one complete, reachable, gap-free node graph.'', 1;

    IF EXISTS
    (
        SELECT n.PhiloteId, pid.PrimitiveInputDefinitionId
        FROM @Nodes AS n
        INNER JOIN [ATAPUtilities].[PrimitiveInputDefinition] AS pid ON pid.PrimitiveVersionId = n.PrimitiveVersionId
        LEFT JOIN @NodeInputs AS ni ON ni.NodePhiloteId = n.PhiloteId AND ni.PrimitiveInputDefinitionId = pid.PrimitiveInputDefinitionId
        GROUP BY n.PhiloteId, pid.PrimitiveInputDefinitionId
        HAVING COUNT(ni.PrimitiveInputDefinitionId) <> 1
    ) OR EXISTS
    (
        SELECT 1 FROM @NodeInputs AS ni
        LEFT JOIN @Nodes AS n ON n.PhiloteId = ni.NodePhiloteId
        LEFT JOIN [ATAPUtilities].[PrimitiveInputDefinition] AS pid
          ON pid.PrimitiveInputDefinitionId = ni.PrimitiveInputDefinitionId AND pid.PrimitiveVersionId = n.PrimitiveVersionId
        WHERE pid.PrimitiveInputDefinitionId IS NULL OR pid.ValueTypeVersionId <> ni.TargetValueTypeVersionId
    )
        THROW 52427, ''Every primitive input occurrence must have exactly one exact-version binding.'', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @RuleKindId = r.RuleKindId
        FROM [ATAPUtilities].[Rule] AS r WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN [ATAPUtilities].[RuleKindVersion] AS rkv ON rkv.RuleKindVersionId = @RuleKindVersionId AND rkv.RuleKindId = r.RuleKindId
        WHERE r.RuleId = @RuleId;
        IF @RuleKindId IS NULL THROW 52428, ''Rule and RuleKindVersion do not identify the same exact kind.'', 1;
        IF @PublishedAtUtc > @NowUtc THROW 52429, ''PublishedAtUtc cannot be in the future.'', 1;
        IF (@PredecessorRuleVersionId IS NULL AND @RevisionSequence <> 1)
           OR (@PredecessorRuleVersionId IS NOT NULL AND NOT EXISTS
              (SELECT 1 FROM [ATAPUtilities].[RuleVersion] WITH (UPDLOCK, HOLDLOCK)
               WHERE RuleVersionId = @PredecessorRuleVersionId AND RuleId = @RuleId
                 AND RevisionSequence + 1 = @RevisionSequence AND PublishedAtUtc < @PublishedAtUtc))
            THROW 52430, ''RuleVersion predecessor and revision lineage is invalid.'', 1;

        INSERT [ATAPUtilities].[RuleVersion]
            (RuleVersionPhiloteId, EntityId, EntityTypeId, RuleId, RuleKindId, RuleKindVersionId,
             RevisionSequence, PredecessorRuleVersionId, CompositionHashAlgorithmCode, CompositionContentHash, PublishedAtUtc)
        VALUES (@RuleVersionPhiloteId, @EntityId, @EntityTypeId, @RuleId, @RuleKindId, @RuleKindVersionId,
                @RevisionSequence, @PredecessorRuleVersionId, ''SHA-256'', @CompositionContentHash, @PublishedAtUtc);
        SET @RuleVersionId = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT [ATAPUtilities].[RuleInputDefinition]
            (RuleInputDefinitionPhiloteId, EntityId, EntityTypeId, RuleVersionId, InputCode, Ordinal,
             ValueTypeVersionId, MinCardinality, MaxCardinality, AllowsNullElement, ValidationContractCode)
        SELECT PhiloteId, EntityId, EntityTypeId, @RuleVersionId, InputCode, Ordinal,
               ValueTypeVersionId, MinCardinality, MaxCardinality, AllowsNullElement, ValidationContractCode
        FROM @RuleInputs;

        INSERT [ATAPUtilities].[RuleOutputDefinition]
            (RuleOutputDefinitionPhiloteId, EntityId, EntityTypeId, RuleVersionId, OutputCode, Ordinal,
             ValueTypeVersionId, MinCardinality, MaxCardinality, OutputDispositionCode, MediaTypePolicyCode,
             ArtifactLocatorPolicyCode, HashExpectationPolicyCode)
        SELECT PhiloteId, EntityId, EntityTypeId, @RuleVersionId, OutputCode, Ordinal,
               ValueTypeVersionId, MinCardinality, MaxCardinality, OutputDispositionCode, MediaTypePolicyCode,
               ArtifactLocatorPolicyCode, HashExpectationPolicyCode
        FROM @RuleOutputs;

        WHILE EXISTS
        (
            SELECT 1 FROM @Nodes AS source
            WHERE NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNode] AS target WHERE target.RuleVersionId = @RuleVersionId AND target.RuleVersionNodePhiloteId = source.PhiloteId)
        )
        BEGIN
            INSERT [ATAPUtilities].[RuleVersionNode]
                (RuleVersionNodePhiloteId, RuleVersionId, RuleKindVersionId, ParentRuleVersionNodeId,
                 Ordinal, PrimitiveVersionId, MinOccurs, MaxOccurs, ChoiceDiscriminatorCode, NodeLabel)
            SELECT source.PhiloteId, @RuleVersionId, @RuleKindVersionId, parent.RuleVersionNodeId,
                   source.Ordinal, source.PrimitiveVersionId, source.MinOccurs, source.MaxOccurs,
                   source.ChoiceDiscriminatorCode, source.NodeLabel
            FROM @Nodes AS source
            LEFT JOIN [ATAPUtilities].[RuleVersionNode] AS parent
              ON parent.RuleVersionId = @RuleVersionId AND parent.RuleVersionNodePhiloteId = source.ParentPhiloteId
            WHERE NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNode] AS target WHERE target.RuleVersionId = @RuleVersionId AND target.RuleVersionNodePhiloteId = source.PhiloteId)
              AND (source.ParentPhiloteId IS NULL OR parent.RuleVersionNodeId IS NOT NULL);
            SET @RowsInserted = @@ROWCOUNT;
            IF @RowsInserted = 0 THROW 52431, ''RuleVersion node graph contains a cycle or unreachable node.'', 1;
        END;

        INSERT [ATAPUtilities].[RuleVersionNodeInput]
            (RuleVersionNodeId, RuleVersionId, PrimitiveVersionId, PrimitiveInputDefinitionId, BindingShapeCode,
             TargetValueTypeVersionId, SourceValueTypeVersionId, ConstantValueTypeVersionId, RuleInputDefinitionId,
             DerivationContractVersionId, SourceRuleVersionNodeId, SourceRuleInputDefinitionId, SourceRuleOutputDefinitionId,
             ConversionPolicyCode, CanonicalTextValue, CanonicalIntegerValue, CanonicalDecimalValue, CanonicalBooleanValue,
             CanonicalUtcValue, CanonicalIdentifierValue, CanonicalBinaryValue, StructuredPayload, SecretName, CanonicalValueHash)
        SELECT node.RuleVersionNodeId, @RuleVersionId, node.PrimitiveVersionId, source.PrimitiveInputDefinitionId,
               source.BindingShapeCode, source.TargetValueTypeVersionId, source.SourceValueTypeVersionId,
               source.ConstantValueTypeVersionId, ruleInput.RuleInputDefinitionId, source.DerivationContractVersionId,
               sourceNode.RuleVersionNodeId, sourceRuleInput.RuleInputDefinitionId, sourceRuleOutput.RuleOutputDefinitionId,
               source.ConversionPolicyCode, source.CanonicalTextValue, source.CanonicalIntegerValue, source.CanonicalDecimalValue,
               source.CanonicalBooleanValue, source.CanonicalUtcValue, source.CanonicalIdentifierValue,
               CONVERT(varbinary(max), source.CanonicalBinaryHex, 2), source.StructuredPayload, source.SecretName,
               CONVERT(binary(32), source.CanonicalValueHashHex, 2)
        FROM @NodeInputs AS source
        INNER JOIN [ATAPUtilities].[RuleVersionNode] AS node ON node.RuleVersionId = @RuleVersionId AND node.RuleVersionNodePhiloteId = source.NodePhiloteId
        LEFT JOIN [ATAPUtilities].[RuleInputDefinition] AS ruleInput ON ruleInput.RuleVersionId = @RuleVersionId AND ruleInput.RuleInputDefinitionPhiloteId = source.RuleInputPhiloteId
        LEFT JOIN [ATAPUtilities].[RuleVersionNode] AS sourceNode ON sourceNode.RuleVersionId = @RuleVersionId AND sourceNode.RuleVersionNodePhiloteId = source.SourceNodePhiloteId
        LEFT JOIN [ATAPUtilities].[RuleInputDefinition] AS sourceRuleInput ON sourceRuleInput.RuleVersionId = @RuleVersionId AND sourceRuleInput.RuleInputDefinitionPhiloteId = source.SourceRuleInputPhiloteId
        LEFT JOIN [ATAPUtilities].[RuleOutputDefinition] AS sourceRuleOutput ON sourceRuleOutput.RuleVersionId = @RuleVersionId AND sourceRuleOutput.RuleOutputDefinitionPhiloteId = source.SourceRuleOutputPhiloteId;

        INSERT [ATAPUtilities].[RuleDefaultInputValue]
            (RuleDefaultInputValuePhiloteId, EntityId, EntityTypeId, RuleInputDefinitionId, RuleVersionId,
             ValueTypeVersionId, CanonicalTextValue, CanonicalIntegerValue, CanonicalDecimalValue, CanonicalBooleanValue,
             CanonicalUtcValue, CanonicalIdentifierValue, CanonicalBinaryValue, StructuredPayload, SecretName,
             CanonicalValueHash, RationaleEntityId, RationaleEntityTypeId, PublishedAtUtc)
        SELECT source.PhiloteId, source.EntityId, source.EntityTypeId, input.RuleInputDefinitionId, @RuleVersionId,
               input.ValueTypeVersionId, source.CanonicalTextValue, source.CanonicalIntegerValue, source.CanonicalDecimalValue,
               source.CanonicalBooleanValue, source.CanonicalUtcValue, source.CanonicalIdentifierValue,
               CONVERT(varbinary(max), source.CanonicalBinaryHex, 2), source.StructuredPayload, source.SecretName,
               CONVERT(binary(32), source.CanonicalValueHashHex, 2), source.RationaleEntityId,
               source.RationaleEntityTypeId, source.PublishedAtUtc
        FROM @RuleDefaults AS source
        INNER JOIN [ATAPUtilities].[RuleInputDefinition] AS input
          ON input.RuleVersionId = @RuleVersionId AND input.RuleInputDefinitionPhiloteId = source.RuleInputPhiloteId;

        IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleVersionNodeInput] WHERE RuleVersionId = @RuleVersionId) <> (SELECT COUNT_BIG(*) FROM @NodeInputs)
           OR (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleDefaultInputValue] WHERE RuleVersionId = @RuleVersionId) <> (SELECT COUNT_BIG(*) FROM @RuleDefaults)
            THROW 52432, ''RuleVersion publication did not materialize the complete supplied aggregate.'', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    IF DATABASE_PRINCIPAL_ID(N'RrsbsPublisher') IS NULL
        CREATE ROLE [RrsbsPublisher] AUTHORIZATION [dbo];

    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[BindingShape] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[DerivationContractVersion] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[Rule] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[RuleVersion] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[RuleInputDefinition] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[RuleDefaultInputValue] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[RuleOutputDefinition] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[RuleVersionNode] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[RuleVersionNodeInput] TO [RrsbsPublisher];
    GRANT EXECUTE ON OBJECT::[ATAPUtilities].[usp_PublishRuleVersionGraph] TO [RrsbsPublisher];

    IF @Rdb420OwnsTransaction = 1
        COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() = -1
        ROLLBACK TRANSACTION;
    ELSE IF XACT_STATE() = 1 AND @Rdb420OwnsTransaction = 1
        ROLLBACK TRANSACTION;
    ELSE IF XACT_STATE() = 1
        ROLLBACK TRANSACTION Rdb420Fragment;
    THROW;
END CATCH;

/*
  Rollback-only fixture contract. The integrated RDB-480 rehearsal supplies
  RDB-400/410 reference fixtures, then sets RRSBS_RUN_RDB420_FIXTURES = 1.
  Each case is a close variant of the positive row set. Constraint failures
  use errors 2601/2627/547; trigger failures use 52420-52424. The coordinator
  executes this only in a disposable local rehearsal database.
*/
IF TRY_CONVERT(bit, SESSION_CONTEXT(N'RRSBS_RUN_RDB420_FIXTURES')) = 1
BEGIN
    SET XACT_ABORT OFF;
    BEGIN TRANSACTION Rdb420Fixtures;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[BindingShape] WHERE [BindingShapeCode] = 'constant')
            INSERT [ATAPUtilities].[BindingShape]
                ([BindingShapeCode], [RequiresConstant], [RequiresRuleInput], [RequiresDerivation])
            VALUES ('constant', 1, 0, 0), ('rule-input', 0, 1, 0), ('derivation', 0, 0, 1);

        /* Positive catalog fixture: all closed shape and cardinality checks pass. */
        DECLARE @Rdb420ValueTypeVersionId bigint =
            (SELECT TOP (1) [ValueTypeVersionId] FROM [ATAPUtilities].[ValueTypeVersion] ORDER BY [ValueTypeVersionId]);
        IF @Rdb420ValueTypeVersionId IS NULL
            THROW 52425, 'RDB-420 fixtures require the RDB-410 reference fixture.', 1;

        DECLARE @Rdb420RuleKindId bigint;
        DECLARE @Rdb420RuleKindVersionId bigint;
        DECLARE @Rdb420PrimitiveVersionId bigint;
        DECLARE @Rdb420PrimitiveInputDefinitionId bigint;
        SELECT TOP (1)
            @Rdb420RuleKindId = rkv.[RuleKindId],
            @Rdb420RuleKindVersionId = pv.[RuleKindVersionId],
            @Rdb420PrimitiveVersionId = pv.[PrimitiveVersionId],
            @Rdb420PrimitiveInputDefinitionId = pid.[PrimitiveInputDefinitionId],
            @Rdb420ValueTypeVersionId = pid.[ValueTypeVersionId]
        FROM [ATAPUtilities].[PrimitiveVersion] AS pv
        INNER JOIN [ATAPUtilities].[RuleKindVersion] AS rkv
            ON rkv.[RuleKindVersionId] = pv.[RuleKindVersionId]
        INNER JOIN [ATAPUtilities].[PrimitiveInputDefinition] AS pid
            ON pid.[PrimitiveVersionId] = pv.[PrimitiveVersionId]
        ORDER BY pv.[PrimitiveVersionId], pid.[PrimitiveInputDefinitionId];
        IF @Rdb420PrimitiveInputDefinitionId IS NULL
            THROW 52431, 'RDB-420 fixtures require compatible RDB-410 RuleKind/Primitive/input rows.', 1;

        DECLARE @Rdb420RuleTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'rule');
        DECLARE @Rdb420RuleVersionTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'rule-version');
        DECLARE @Rdb420RuleInputTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'rule-input-definition');
        DECLARE @Rdb420RuleDefaultTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'rule-default-input-value');
        DECLARE @Rdb420RuleOutputTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'rule-output-definition');
        IF @Rdb420RuleTypeId IS NULL OR @Rdb420RuleVersionTypeId IS NULL OR @Rdb420RuleInputTypeId IS NULL
           OR @Rdb420RuleDefaultTypeId IS NULL OR @Rdb420RuleOutputTypeId IS NULL
            THROW 52432, 'RDB-420 fixtures require all five frozen RDB-320 EntityType rows.', 1;

        DECLARE @Rdb420RulePhilote uniqueidentifier = '7A685465-2EE2-5B50-A6AF-8A8D74E10201';
        DECLARE @Rdb420RuleVersionPhilote uniqueidentifier = '947425D4-0F83-5A93-9059-AAD021B10202';
        DECLARE @Rdb420RuleInputPhilote uniqueidentifier = 'A6D5284F-127D-5CDB-9199-2F65F0860203';
        DECLARE @Rdb420RuleDefaultPhilote uniqueidentifier = 'E54C2216-BA60-54CB-8E7E-D3BBE18F0204';
        DECLARE @Rdb420RuleOutputPhilote uniqueidentifier = '38A4269D-89D1-51A5-B31B-6D4C6BF20205';
        DECLARE @Rdb420RuleEntityId bigint;
        DECLARE @Rdb420RuleVersionEntityId bigint;
        DECLARE @Rdb420RuleInputEntityId bigint;
        DECLARE @Rdb420RuleDefaultEntityId bigint;
        DECLARE @Rdb420RuleOutputEntityId bigint;

        INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@Rdb420RuleTypeId, @Rdb420RulePhilote, SYSUTCDATETIME());
        SET @Rdb420RuleEntityId = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@Rdb420RuleVersionTypeId, @Rdb420RuleVersionPhilote, SYSUTCDATETIME());
        SET @Rdb420RuleVersionEntityId = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@Rdb420RuleInputTypeId, @Rdb420RuleInputPhilote, SYSUTCDATETIME());
        SET @Rdb420RuleInputEntityId = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@Rdb420RuleDefaultTypeId, @Rdb420RuleDefaultPhilote, SYSUTCDATETIME());
        SET @Rdb420RuleDefaultEntityId = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@Rdb420RuleOutputTypeId, @Rdb420RuleOutputPhilote, SYSUTCDATETIME());
        SET @Rdb420RuleOutputEntityId = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT [ATAPUtilities].[Rule]
            ([RulePhiloteId], [EntityId], [EntityTypeId], [RuleKindId], [RuleCode], [CreatedAtUtc])
        VALUES (@Rdb420RulePhilote, @Rdb420RuleEntityId, @Rdb420RuleTypeId, @Rdb420RuleKindId, 'rdb-420-positive', SYSUTCDATETIME());
        DECLARE @Rdb420RuleId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT [ATAPUtilities].[RuleVersion]
            ([RuleVersionPhiloteId], [EntityId], [EntityTypeId], [RuleId], [RuleKindId], [RuleKindVersionId],
             [RevisionSequence], [PredecessorRuleVersionId], [CompositionHashAlgorithmCode], [CompositionContentHash], [PublishedAtUtc])
        VALUES (@Rdb420RuleVersionPhilote, @Rdb420RuleVersionEntityId, @Rdb420RuleVersionTypeId, @Rdb420RuleId,
                @Rdb420RuleKindId, @Rdb420RuleKindVersionId, 1, NULL, 'SHA-256',
                HASHBYTES('SHA2_256', 'RDB-420-positive-composition'), SYSUTCDATETIME());
        DECLARE @Rdb420RuleVersionId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT [ATAPUtilities].[RuleInputDefinition]
            ([RuleInputDefinitionPhiloteId], [EntityId], [EntityTypeId], [RuleVersionId], [InputCode], [Ordinal],
             [ValueTypeVersionId], [MinCardinality], [MaxCardinality], [AllowsNullElement], [ValidationContractCode])
        VALUES (@Rdb420RuleInputPhilote, @Rdb420RuleInputEntityId, @Rdb420RuleInputTypeId, @Rdb420RuleVersionId,
                'input', 0, @Rdb420ValueTypeVersionId, 1, 1, 0, 'fixture-validator');
        DECLARE @Rdb420RuleInputDefinitionId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT [ATAPUtilities].[RuleDefaultInputValue]
            ([RuleDefaultInputValuePhiloteId], [EntityId], [EntityTypeId], [RuleInputDefinitionId], [RuleVersionId],
             [ValueTypeVersionId], [CanonicalTextValue], [CanonicalValueHash], [RationaleEntityId],
             [RationaleEntityTypeId], [PublishedAtUtc])
        VALUES (@Rdb420RuleDefaultPhilote, @Rdb420RuleDefaultEntityId, @Rdb420RuleDefaultTypeId,
                @Rdb420RuleInputDefinitionId, @Rdb420RuleVersionId, @Rdb420ValueTypeVersionId, N'fixture',
                HASHBYTES('SHA2_256', N'fixture'), @Rdb420RuleEntityId, @Rdb420RuleTypeId, SYSUTCDATETIME());

        INSERT [ATAPUtilities].[RuleOutputDefinition]
            ([RuleOutputDefinitionPhiloteId], [EntityId], [EntityTypeId], [RuleVersionId], [OutputCode], [Ordinal],
             [ValueTypeVersionId], [MinCardinality], [MaxCardinality], [OutputDispositionCode], [MediaTypePolicyCode],
             [ArtifactLocatorPolicyCode], [HashExpectationPolicyCode])
        VALUES (@Rdb420RuleOutputPhilote, @Rdb420RuleOutputEntityId, @Rdb420RuleOutputTypeId, @Rdb420RuleVersionId,
                'output', 0, @Rdb420ValueTypeVersionId, 1, 1, 'scalar', 'none', 'none', 'required');

        INSERT [ATAPUtilities].[RuleVersionNode]
            ([RuleVersionNodePhiloteId], [RuleVersionId], [RuleKindVersionId], [ParentRuleVersionNodeId], [Ordinal],
             [PrimitiveVersionId], [MinOccurs], [MaxOccurs], [ChoiceDiscriminatorCode], [NodeLabel])
        VALUES ('76504340-1BB6-5833-B772-5670751C0206', @Rdb420RuleVersionId, @Rdb420RuleKindVersionId,
                NULL, 0, @Rdb420PrimitiveVersionId, 1, 1, NULL, N'fixture-root');
        DECLARE @Rdb420RuleVersionNodeId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT [ATAPUtilities].[RuleVersionNodeInput]
            ([RuleVersionNodeId], [RuleVersionId], [PrimitiveVersionId], [PrimitiveInputDefinitionId],
             [BindingShapeCode], [TargetValueTypeVersionId], [SourceValueTypeVersionId], [ConstantValueTypeVersionId],
             [RuleInputDefinitionId], [DerivationContractVersionId], [ConversionPolicyCode], [CanonicalTextValue], [CanonicalValueHash])
        VALUES (@Rdb420RuleVersionNodeId, @Rdb420RuleVersionId, @Rdb420PrimitiveVersionId,
                @Rdb420PrimitiveInputDefinitionId, 'constant', @Rdb420ValueTypeVersionId, NULL,
                @Rdb420ValueTypeVersionId, NULL, NULL, NULL, N'fixture', HASHBYTES('SHA2_256', N'fixture'));

        INSERT [ATAPUtilities].[DerivationContractVersion]
            ([ExpressionLanguageCode], [ExpressionLanguageVersion], [SourceValueTypeVersionId], [TargetValueTypeVersionId],
             [SourceMinCardinality], [SourceMaxCardinality], [TargetMinCardinality], [TargetMaxCardinality],
             [ValidatorContractCode], [ContractContentHash], [PublishedAtUtc])
        VALUES ('rrsbs-expression', '1', @Rdb420ValueTypeVersionId, @Rdb420ValueTypeVersionId,
                1, 1, 1, 1, 'fixture-validator', HASHBYTES('SHA2_256', 'RDB-420-positive'), SYSUTCDATETIME());

        /* Invalid fixture: a catalog row cannot select zero/multiple shapes. */
        BEGIN TRY
            INSERT [ATAPUtilities].[BindingShape]
                ([BindingShapeCode], [RequiresConstant], [RequiresRuleInput], [RequiresDerivation])
            VALUES ('invalid', 0, 0, 0);
            THROW 52426, 'Expected BindingShape rejection did not occur.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 52426 THROW;
            IF ERROR_NUMBER() NOT IN (547) THROW;
        END CATCH;

        /* Invalid fixture: derivation cardinality cannot be negative/inverted. */
        BEGIN TRY
            INSERT [ATAPUtilities].[DerivationContractVersion]
                ([ExpressionLanguageCode], [ExpressionLanguageVersion], [SourceValueTypeVersionId], [TargetValueTypeVersionId],
                 [SourceMinCardinality], [SourceMaxCardinality], [TargetMinCardinality], [TargetMaxCardinality],
                 [ValidatorContractCode], [ContractContentHash], [PublishedAtUtc])
            VALUES ('rrsbs-expression', '1', @Rdb420ValueTypeVersionId, @Rdb420ValueTypeVersionId,
                    2, 1, 1, 1, 'fixture-validator', HASHBYTES('SHA2_256', 'RDB-420-invalid-cardinality'), SYSUTCDATETIME());
            THROW 52427, 'Expected cardinality rejection did not occur.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 52427 THROW;
            IF ERROR_NUMBER() NOT IN (547) THROW;
        END CATCH;

        /* Invalid fixture: immutable catalog update is rejected by its trigger. */
        BEGIN TRY
            UPDATE [ATAPUtilities].[BindingShape]
            SET [RequiresConstant] = [RequiresConstant]
            WHERE [BindingShapeCode] = 'constant';
            THROW 52428, 'Expected immutability rejection did not occur.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 52428 THROW;
            IF ERROR_NUMBER() NOT IN (52424) THROW;
        END CATCH;

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
    SET XACT_ABORT ON;
END;

/* Source-static postconditions; RDB-480 repeats them after integration. */
IF (SELECT COUNT_BIG(*) FROM sys.tables WHERE [schema_id] = SCHEMA_ID(N'ATAPUtilities')
    AND [name] IN (N'Rule', N'RuleVersion', N'RuleVersionNode', N'RuleVersionNodeInput', N'BindingShape',
                   N'DerivationContractVersion', N'RuleInputDefinition', N'RuleDefaultInputValue', N'RuleOutputDefinition')) <> 9
    THROW 52429, 'RDB-420 table postcondition failed.', 1;

IF (SELECT COUNT_BIG(*) FROM sys.triggers WHERE [parent_id] IN
    (OBJECT_ID(N'[ATAPUtilities].[Rule]'), OBJECT_ID(N'[ATAPUtilities].[RuleVersion]'),
     OBJECT_ID(N'[ATAPUtilities].[RuleVersionNode]'), OBJECT_ID(N'[ATAPUtilities].[RuleVersionNodeInput]'),
     OBJECT_ID(N'[ATAPUtilities].[BindingShape]'), OBJECT_ID(N'[ATAPUtilities].[DerivationContractVersion]'),
     OBJECT_ID(N'[ATAPUtilities].[RuleInputDefinition]'), OBJECT_ID(N'[ATAPUtilities].[RuleDefaultInputValue]'),
     OBJECT_ID(N'[ATAPUtilities].[RuleOutputDefinition]')) AND [is_disabled] = 0) <> 9
    THROW 52430, 'RDB-420 trigger postcondition failed.', 1;
/* END INTEGRATED FRAGMENT: RDB-420__Rule-Composition.sql */

/* BEGIN INTEGRATED FRAGMENT: RDB-430__RuleSet-BuildSet.sql */
/*
RDB-430 / Task 14.20.f.03
RuleSet and BuildSet physical fragment for SQL Server 2022.

Integration prerequisites (created by RDB-400/RDB-420):
  ATAPUtilities.EntityType(EntityTypeId, EntityTypeCode)
  ATAPUtilities.Entity(EntityId, EntityTypeId, EntityPhiloteId)
  ATAPUtilities.RuleVersion(RuleVersionId)

RDB-480 must preserve the named composite candidate keys because RDB-440 uses
them to prove the complete BuildSet-member -> RuleSet-member -> RuleVersion
occurrence path. The opt-in fixture section never commits fixture data.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'ATAPUtilities.RuleSetMembershipRole', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.RuleSetMembershipRole
        (
            MembershipRoleCode VARCHAR(128) NOT NULL,
            AllowsRepeatedChild BIT NOT NULL,
            CONSTRAINT PK_RuleSetMembershipRole PRIMARY KEY (MembershipRoleCode),
            CONSTRAINT CK_RuleSetMembershipRole_MembershipRoleCodeNormalized CHECK
            (
                MembershipRoleCode = LOWER(MembershipRoleCode) COLLATE Latin1_General_100_BIN2
                AND MembershipRoleCode NOT LIKE '%[^a-z0-9._-]%' COLLATE Latin1_General_100_BIN2
                AND LEFT(MembershipRoleCode, 1) LIKE '[a-z0-9]' COLLATE Latin1_General_100_BIN2
                AND RIGHT(MembershipRoleCode, 1) LIKE '[a-z0-9]' COLLATE Latin1_General_100_BIN2
            )
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.BuildSetMembershipRole', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.BuildSetMembershipRole
        (
            MembershipRoleCode VARCHAR(128) NOT NULL,
            AllowsRepeatedChild BIT NOT NULL,
            CONSTRAINT PK_BuildSetMembershipRole PRIMARY KEY (MembershipRoleCode),
            CONSTRAINT CK_BuildSetMembershipRole_MembershipRoleCodeNormalized CHECK
            (
                MembershipRoleCode = LOWER(MembershipRoleCode) COLLATE Latin1_General_100_BIN2
                AND MembershipRoleCode NOT LIKE '%[^a-z0-9._-]%' COLLATE Latin1_General_100_BIN2
                AND LEFT(MembershipRoleCode, 1) LIKE '[a-z0-9]' COLLATE Latin1_General_100_BIN2
                AND RIGHT(MembershipRoleCode, 1) LIKE '[a-z0-9]' COLLATE Latin1_General_100_BIN2
            )
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.RuleSet', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.RuleSet
        (
            RuleSetId BIGINT IDENTITY(1, 1) NOT NULL,
            RuleSetPhiloteId UNIQUEIDENTIFIER NOT NULL,
            EntityId BIGINT NOT NULL,
            EntityTypeId BIGINT NOT NULL,
            EntityTypeCode VARCHAR(64) NOT NULL,
            RuleSetCode VARCHAR(128) NOT NULL,
            CreatedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_RuleSet PRIMARY KEY (RuleSetId),
            CONSTRAINT UQ_RuleSet_RuleSetPhiloteId UNIQUE (RuleSetPhiloteId),
            CONSTRAINT UQ_RuleSet_RuleSetCode UNIQUE (RuleSetCode),
            CONSTRAINT CK_RuleSet_RuleSetCodeNormalized CHECK
            (
                RuleSetCode = LOWER(RuleSetCode) COLLATE Latin1_General_100_BIN2
                AND RuleSetCode NOT LIKE '%[^a-z0-9._-]%' COLLATE Latin1_General_100_BIN2
                AND LEFT(RuleSetCode, 1) LIKE '[a-z0-9]' COLLATE Latin1_General_100_BIN2
                AND RIGHT(RuleSetCode, 1) LIKE '[a-z0-9]' COLLATE Latin1_General_100_BIN2
            ),
            CONSTRAINT CK_RuleSet_EntityTypeCode CHECK (EntityTypeCode = 'rule-set'),
            CONSTRAINT FK_RuleSet_Entity_RuleSetEntity FOREIGN KEY
                (EntityId, EntityTypeId, RuleSetPhiloteId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId, EntityPhiloteId),
            CONSTRAINT FK_RuleSet_EntityType_RuleSetType FOREIGN KEY
                (EntityTypeId, EntityTypeCode)
                REFERENCES ATAPUtilities.EntityType (EntityTypeId, EntityTypeCode)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.RuleSetVersion', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.RuleSetVersion
        (
            RuleSetVersionId BIGINT IDENTITY(1, 1) NOT NULL,
            RuleSetVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            EntityId BIGINT NOT NULL,
            EntityTypeId BIGINT NOT NULL,
            EntityTypeCode VARCHAR(64) NOT NULL,
            RuleSetId BIGINT NOT NULL,
            RevisionSequence INT NOT NULL,
            PredecessorRuleSetVersionId BIGINT NULL,
            MembershipHashAlgorithmCode VARCHAR(128) NOT NULL,
            MembershipContentHash VARBINARY(64) NOT NULL,
            PublishedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_RuleSetVersion PRIMARY KEY (RuleSetVersionId),
            CONSTRAINT UQ_RuleSetVersion_RuleSetVersionPhiloteId UNIQUE (RuleSetVersionPhiloteId),
            CONSTRAINT UQ_RuleSetVersion_RuleSetId_RevisionSequence UNIQUE (RuleSetId, RevisionSequence),
            CONSTRAINT UQ_RuleSetVersion_RuleSetVersionId_RuleSetId UNIQUE (RuleSetVersionId, RuleSetId),
            CONSTRAINT CK_RuleSetVersion_RevisionSequencePositive CHECK (RevisionSequence > 0),
            CONSTRAINT CK_RuleSetVersion_EntityTypeCode CHECK (EntityTypeCode = 'rule-set-version'),
            CONSTRAINT CK_RuleSetVersion_MembershipHashSha256 CHECK
            (
                MembershipHashAlgorithmCode = 'sha256'
                AND DATALENGTH(MembershipContentHash) = 32
            ),
            CONSTRAINT FK_RuleSetVersion_Entity_RuleSetVersionEntity FOREIGN KEY
                (EntityId, EntityTypeId, RuleSetVersionPhiloteId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId, EntityPhiloteId),
            CONSTRAINT FK_RuleSetVersion_EntityType_RuleSetVersionType FOREIGN KEY
                (EntityTypeId, EntityTypeCode)
                REFERENCES ATAPUtilities.EntityType (EntityTypeId, EntityTypeCode),
            CONSTRAINT FK_RuleSetVersion_RuleSet_Parent FOREIGN KEY (RuleSetId)
                REFERENCES ATAPUtilities.RuleSet (RuleSetId),
            CONSTRAINT FK_RuleSetVersion_RuleSetVersion_PredecessorSameParent FOREIGN KEY
                (PredecessorRuleSetVersionId, RuleSetId)
                REFERENCES ATAPUtilities.RuleSetVersion (RuleSetVersionId, RuleSetId)
        );

        CREATE UNIQUE INDEX UQ_RuleSetVersion_PredecessorRuleSetVersionId
            ON ATAPUtilities.RuleSetVersion (PredecessorRuleSetVersionId)
            WHERE PredecessorRuleSetVersionId IS NOT NULL;
    END;

    IF OBJECT_ID(N'ATAPUtilities.RuleSetVersionMember', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.RuleSetVersionMember
        (
            RuleSetVersionMemberId BIGINT IDENTITY(1, 1) NOT NULL,
            RuleSetVersionMemberPhiloteId UNIQUEIDENTIFIER NOT NULL,
            RuleSetVersionId BIGINT NOT NULL,
            MemberOccurrenceKey VARCHAR(128) NOT NULL,
            Ordinal INT NOT NULL,
            RuleVersionId BIGINT NOT NULL,
            MembershipRoleCode VARCHAR(128) NOT NULL,
            MembershipRationaleEntityId BIGINT NULL,
            MembershipRationaleEntityTypeId BIGINT NULL,
            CONSTRAINT PK_RuleSetVersionMember PRIMARY KEY (RuleSetVersionMemberId),
            CONSTRAINT UQ_RuleSetVersionMember_RuleSetVersionMemberPhiloteId UNIQUE
                (RuleSetVersionMemberPhiloteId),
            CONSTRAINT UQ_RuleSetVersionMember_RuleSetVersionId_MemberOccurrenceKey UNIQUE
                (RuleSetVersionId, MemberOccurrenceKey),
            CONSTRAINT UQ_RuleSetVersionMember_RuleSetVersionId_Ordinal UNIQUE
                (RuleSetVersionId, Ordinal),
            CONSTRAINT UQ_RuleSetVersionMember_RuleSetVersionMemberId_RuleVersionId UNIQUE
                (RuleSetVersionMemberId, RuleVersionId),
            CONSTRAINT UQ_RuleSetVersionMember_RuleSetVersionMemberId_RuleSetVersionId_RuleVersionId UNIQUE
                (RuleSetVersionMemberId, RuleSetVersionId, RuleVersionId),
            CONSTRAINT CK_RuleSetVersionMember_MemberOccurrenceKeyNormalized CHECK
            (
                MemberOccurrenceKey = LOWER(MemberOccurrenceKey) COLLATE Latin1_General_100_BIN2
                AND MemberOccurrenceKey NOT LIKE '%[^a-z0-9._-]%' COLLATE Latin1_General_100_BIN2
                AND LEFT(MemberOccurrenceKey, 1) LIKE '[a-z0-9]' COLLATE Latin1_General_100_BIN2
                AND RIGHT(MemberOccurrenceKey, 1) LIKE '[a-z0-9]' COLLATE Latin1_General_100_BIN2
            ),
            CONSTRAINT CK_RuleSetVersionMember_OrdinalNonNegative CHECK (Ordinal >= 0),
            CONSTRAINT CK_RuleSetVersionMember_RationaleNullParity CHECK
            (
                (MembershipRationaleEntityId IS NULL AND MembershipRationaleEntityTypeId IS NULL)
                OR
                (MembershipRationaleEntityId IS NOT NULL AND MembershipRationaleEntityTypeId IS NOT NULL)
            ),
            CONSTRAINT FK_RuleSetVersionMember_RuleSetVersion_Parent FOREIGN KEY (RuleSetVersionId)
                REFERENCES ATAPUtilities.RuleSetVersion (RuleSetVersionId),
            CONSTRAINT FK_RuleSetVersionMember_RuleVersion_Child FOREIGN KEY (RuleVersionId)
                REFERENCES ATAPUtilities.RuleVersion (RuleVersionId),
            CONSTRAINT FK_RuleSetVersionMember_RuleSetMembershipRole_Role FOREIGN KEY
                (MembershipRoleCode)
                REFERENCES ATAPUtilities.RuleSetMembershipRole (MembershipRoleCode),
            CONSTRAINT FK_RuleSetVersionMember_Entity_Rationale FOREIGN KEY
                (MembershipRationaleEntityId, MembershipRationaleEntityTypeId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId)
        );

        CREATE INDEX IX_RuleSetVersionMember_RuleVersionId
            ON ATAPUtilities.RuleSetVersionMember (RuleVersionId);
        CREATE INDEX IX_RuleSetVersionMember_MembershipRationaleEntityId_MembershipRationaleEntityTypeId
            ON ATAPUtilities.RuleSetVersionMember
                (MembershipRationaleEntityId, MembershipRationaleEntityTypeId)
            WHERE MembershipRationaleEntityId IS NOT NULL;
    END;

    IF OBJECT_ID(N'ATAPUtilities.BuildSet', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.BuildSet
        (
            BuildSetId BIGINT IDENTITY(1, 1) NOT NULL,
            BuildSetPhiloteId UNIQUEIDENTIFIER NOT NULL,
            EntityId BIGINT NOT NULL,
            EntityTypeId BIGINT NOT NULL,
            EntityTypeCode VARCHAR(64) NOT NULL,
            BuildSetCode VARCHAR(128) NOT NULL,
            CreatedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_BuildSet PRIMARY KEY (BuildSetId),
            CONSTRAINT UQ_BuildSet_BuildSetPhiloteId UNIQUE (BuildSetPhiloteId),
            CONSTRAINT UQ_BuildSet_BuildSetCode UNIQUE (BuildSetCode),
            CONSTRAINT CK_BuildSet_BuildSetCodeNormalized CHECK
            (
                BuildSetCode = LOWER(BuildSetCode) COLLATE Latin1_General_100_BIN2
                AND BuildSetCode NOT LIKE '%[^a-z0-9._-]%' COLLATE Latin1_General_100_BIN2
                AND LEFT(BuildSetCode, 1) LIKE '[a-z0-9]' COLLATE Latin1_General_100_BIN2
                AND RIGHT(BuildSetCode, 1) LIKE '[a-z0-9]' COLLATE Latin1_General_100_BIN2
            ),
            CONSTRAINT CK_BuildSet_EntityTypeCode CHECK (EntityTypeCode = 'build-set'),
            CONSTRAINT FK_BuildSet_Entity_BuildSetEntity FOREIGN KEY
                (EntityId, EntityTypeId, BuildSetPhiloteId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId, EntityPhiloteId),
            CONSTRAINT FK_BuildSet_EntityType_BuildSetType FOREIGN KEY
                (EntityTypeId, EntityTypeCode)
                REFERENCES ATAPUtilities.EntityType (EntityTypeId, EntityTypeCode)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.BuildSetVersion', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.BuildSetVersion
        (
            BuildSetVersionId BIGINT IDENTITY(1, 1) NOT NULL,
            BuildSetVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            EntityId BIGINT NOT NULL,
            EntityTypeId BIGINT NOT NULL,
            EntityTypeCode VARCHAR(64) NOT NULL,
            BuildSetId BIGINT NOT NULL,
            RevisionSequence INT NOT NULL,
            PredecessorBuildSetVersionId BIGINT NULL,
            MembershipHashAlgorithmCode VARCHAR(128) NOT NULL,
            MembershipContentHash VARBINARY(64) NOT NULL,
            PublishedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_BuildSetVersion PRIMARY KEY (BuildSetVersionId),
            CONSTRAINT UQ_BuildSetVersion_BuildSetVersionPhiloteId UNIQUE (BuildSetVersionPhiloteId),
            CONSTRAINT UQ_BuildSetVersion_BuildSetId_RevisionSequence UNIQUE (BuildSetId, RevisionSequence),
            CONSTRAINT UQ_BuildSetVersion_BuildSetVersionId_BuildSetId UNIQUE (BuildSetVersionId, BuildSetId),
            CONSTRAINT CK_BuildSetVersion_RevisionSequencePositive CHECK (RevisionSequence > 0),
            CONSTRAINT CK_BuildSetVersion_EntityTypeCode CHECK (EntityTypeCode = 'build-set-version'),
            CONSTRAINT CK_BuildSetVersion_MembershipHashSha256 CHECK
            (
                MembershipHashAlgorithmCode = 'sha256'
                AND DATALENGTH(MembershipContentHash) = 32
            ),
            CONSTRAINT FK_BuildSetVersion_Entity_BuildSetVersionEntity FOREIGN KEY
                (EntityId, EntityTypeId, BuildSetVersionPhiloteId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId, EntityPhiloteId),
            CONSTRAINT FK_BuildSetVersion_EntityType_BuildSetVersionType FOREIGN KEY
                (EntityTypeId, EntityTypeCode)
                REFERENCES ATAPUtilities.EntityType (EntityTypeId, EntityTypeCode),
            CONSTRAINT FK_BuildSetVersion_BuildSet_Parent FOREIGN KEY (BuildSetId)
                REFERENCES ATAPUtilities.BuildSet (BuildSetId),
            CONSTRAINT FK_BuildSetVersion_BuildSetVersion_PredecessorSameParent FOREIGN KEY
                (PredecessorBuildSetVersionId, BuildSetId)
                REFERENCES ATAPUtilities.BuildSetVersion (BuildSetVersionId, BuildSetId)
        );

        CREATE UNIQUE INDEX UQ_BuildSetVersion_PredecessorBuildSetVersionId
            ON ATAPUtilities.BuildSetVersion (PredecessorBuildSetVersionId)
            WHERE PredecessorBuildSetVersionId IS NOT NULL;
    END;

    IF OBJECT_ID(N'ATAPUtilities.BuildSetVersionMember', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.BuildSetVersionMember
        (
            BuildSetVersionMemberId BIGINT IDENTITY(1, 1) NOT NULL,
            BuildSetVersionMemberPhiloteId UNIQUEIDENTIFIER NOT NULL,
            BuildSetVersionId BIGINT NOT NULL,
            MemberOccurrenceKey VARCHAR(128) NOT NULL,
            Ordinal INT NOT NULL,
            RuleSetVersionId BIGINT NOT NULL,
            MembershipRoleCode VARCHAR(128) NOT NULL,
            MembershipRationaleEntityId BIGINT NULL,
            MembershipRationaleEntityTypeId BIGINT NULL,
            CONSTRAINT PK_BuildSetVersionMember PRIMARY KEY (BuildSetVersionMemberId),
            CONSTRAINT UQ_BuildSetVersionMember_BuildSetVersionMemberPhiloteId UNIQUE
                (BuildSetVersionMemberPhiloteId),
            CONSTRAINT UQ_BuildSetVersionMember_BuildSetVersionId_MemberOccurrenceKey UNIQUE
                (BuildSetVersionId, MemberOccurrenceKey),
            CONSTRAINT UQ_BuildSetVersionMember_BuildSetVersionId_Ordinal UNIQUE
                (BuildSetVersionId, Ordinal),
            CONSTRAINT UQ_BuildSetVersionMember_BuildSetVersionMemberId_RuleSetVersionId UNIQUE
                (BuildSetVersionMemberId, RuleSetVersionId),
            CONSTRAINT UQ_BuildSetVersionMember_BuildSetVersionMemberId_BuildSetVersionId_RuleSetVersionId UNIQUE
                (BuildSetVersionMemberId, BuildSetVersionId, RuleSetVersionId),
            CONSTRAINT CK_BuildSetVersionMember_MemberOccurrenceKeyNormalized CHECK
            (
                MemberOccurrenceKey = LOWER(MemberOccurrenceKey) COLLATE Latin1_General_100_BIN2
                AND MemberOccurrenceKey NOT LIKE '%[^a-z0-9._-]%' COLLATE Latin1_General_100_BIN2
                AND LEFT(MemberOccurrenceKey, 1) LIKE '[a-z0-9]' COLLATE Latin1_General_100_BIN2
                AND RIGHT(MemberOccurrenceKey, 1) LIKE '[a-z0-9]' COLLATE Latin1_General_100_BIN2
            ),
            CONSTRAINT CK_BuildSetVersionMember_OrdinalNonNegative CHECK (Ordinal >= 0),
            CONSTRAINT CK_BuildSetVersionMember_RationaleNullParity CHECK
            (
                (MembershipRationaleEntityId IS NULL AND MembershipRationaleEntityTypeId IS NULL)
                OR
                (MembershipRationaleEntityId IS NOT NULL AND MembershipRationaleEntityTypeId IS NOT NULL)
            ),
            CONSTRAINT FK_BuildSetVersionMember_BuildSetVersion_Parent FOREIGN KEY (BuildSetVersionId)
                REFERENCES ATAPUtilities.BuildSetVersion (BuildSetVersionId),
            CONSTRAINT FK_BuildSetVersionMember_RuleSetVersion_Child FOREIGN KEY (RuleSetVersionId)
                REFERENCES ATAPUtilities.RuleSetVersion (RuleSetVersionId),
            CONSTRAINT FK_BuildSetVersionMember_BuildSetMembershipRole_Role FOREIGN KEY
                (MembershipRoleCode)
                REFERENCES ATAPUtilities.BuildSetMembershipRole (MembershipRoleCode),
            CONSTRAINT FK_BuildSetVersionMember_Entity_Rationale FOREIGN KEY
                (MembershipRationaleEntityId, MembershipRationaleEntityTypeId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId)
        );

        CREATE INDEX IX_BuildSetVersionMember_RuleSetVersionId
            ON ATAPUtilities.BuildSetVersionMember (RuleSetVersionId);
        CREATE INDEX IX_BuildSetVersionMember_MembershipRationaleEntityId_MembershipRationaleEntityTypeId
            ON ATAPUtilities.BuildSetVersionMember
                (MembershipRationaleEntityId, MembershipRationaleEntityTypeId)
            WHERE MembershipRationaleEntityId IS NOT NULL;
    END;

    /* Dynamic DDL keeps the fragment in one transaction and avoids GO batch separators. */
    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_RuleSetMembershipRole_UpdateDeleteImmutable
ON ATAPUtilities.RuleSetMembershipRole
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 53430, ''RuleSetMembershipRole rows are immutable.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_BuildSetMembershipRole_UpdateDeleteImmutable
ON ATAPUtilities.BuildSetMembershipRole
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 53431, ''BuildSetMembershipRole rows are immutable.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_RuleSet_UpdateDeleteImmutable
ON ATAPUtilities.RuleSet
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 53432, ''RuleSet rows and durable codes are immutable.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_BuildSet_UpdateDeleteImmutable
ON ATAPUtilities.BuildSet
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 53433, ''BuildSet rows and durable codes are immutable.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_RuleSetVersion_InsertLineage
ON ATAPUtilities.RuleSetVersion
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        LEFT JOIN ATAPUtilities.RuleSetVersion AS predecessor
            ON predecessor.RuleSetVersionId = i.PredecessorRuleSetVersionId
        WHERE
            (i.PredecessorRuleSetVersionId IS NULL AND i.RevisionSequence <> 1)
            OR
            (i.PredecessorRuleSetVersionId IS NOT NULL
                AND (predecessor.RuleSetId <> i.RuleSetId
                    OR predecessor.RevisionSequence + 1 <> i.RevisionSequence
                    OR predecessor.PublishedAtUtc >= i.PublishedAtUtc))
            OR i.PublishedAtUtc > SYSUTCDATETIME()
    )
    BEGIN
        THROW 53434, ''RuleSetVersion lineage, revision, or publication time is invalid.'', 1;
    END;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_BuildSetVersion_InsertLineage
ON ATAPUtilities.BuildSetVersion
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        LEFT JOIN ATAPUtilities.BuildSetVersion AS predecessor
            ON predecessor.BuildSetVersionId = i.PredecessorBuildSetVersionId
        WHERE
            (i.PredecessorBuildSetVersionId IS NULL AND i.RevisionSequence <> 1)
            OR
            (i.PredecessorBuildSetVersionId IS NOT NULL
                AND (predecessor.BuildSetId <> i.BuildSetId
                    OR predecessor.RevisionSequence + 1 <> i.RevisionSequence
                    OR predecessor.PublishedAtUtc >= i.PublishedAtUtc))
            OR i.PublishedAtUtc > SYSUTCDATETIME()
    )
    BEGIN
        THROW 53435, ''BuildSetVersion lineage, revision, or publication time is invalid.'', 1;
    END;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_RuleSetVersion_UpdateDeleteImmutable
ON ATAPUtilities.RuleSetVersion
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 53436, ''Published RuleSetVersion rows are immutable.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_BuildSetVersion_UpdateDeleteImmutable
ON ATAPUtilities.BuildSetVersion
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 53437, ''Published BuildSetVersion rows are immutable.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_RuleSetVersionMember_InsertContract
ON ATAPUtilities.RuleSetVersionMember
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM ATAPUtilities.RuleSetVersionMember AS memberRow
        INNER JOIN ATAPUtilities.RuleSetMembershipRole AS roleRow
            ON roleRow.MembershipRoleCode = memberRow.MembershipRoleCode
        WHERE memberRow.RuleSetVersionId IN (SELECT RuleSetVersionId FROM inserted)
        GROUP BY memberRow.RuleSetVersionId, memberRow.RuleVersionId
        HAVING COUNT_BIG(*) > 1
            AND MIN(CONVERT(INT, roleRow.AllowsRepeatedChild)) = 0
    )
    BEGIN
        THROW 53438, ''A RuleVersion repeat uses a role that forbids repeated children.'', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM ATAPUtilities.RuleSetVersionMember AS memberRow
        WHERE memberRow.RuleSetVersionId IN (SELECT RuleSetVersionId FROM inserted)
        GROUP BY memberRow.RuleSetVersionId
        HAVING MIN(memberRow.Ordinal) <> 0
            OR MAX(memberRow.Ordinal) <> COUNT_BIG(*) - 1
    )
    BEGIN
        THROW 53439, ''RuleSetVersion member ordinals must be zero-based and gap-free.'', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM ATAPUtilities.RuleSetVersion AS versionRow
        CROSS APPLY
        (
            SELECT HASHBYTES
            (
                ''SHA2_256'',
                CONVERT
                (
                    VARBINARY(MAX),
                    STRING_AGG
                    (
                        CONVERT
                        (
                            VARCHAR(MAX),
                            CONCAT
                            (
                                memberRow.MemberOccurrenceKey, '':'',
                                memberRow.RuleVersionId, '':'',
                                memberRow.MembershipRoleCode, '':'',
                                COALESCE(CONVERT(VARCHAR(20), memberRow.MembershipRationaleEntityId), ''-''), '':'',
                                COALESCE(CONVERT(VARCHAR(20), memberRow.MembershipRationaleEntityTypeId), ''-'')
                            )
                        ),
                        ''|''
                    ) WITHIN GROUP (ORDER BY memberRow.Ordinal)
                )
            ) AS CalculatedHash
            FROM ATAPUtilities.RuleSetVersionMember AS memberRow
            WHERE memberRow.RuleSetVersionId = versionRow.RuleSetVersionId
        ) AS hashValue
        WHERE versionRow.RuleSetVersionId IN (SELECT RuleSetVersionId FROM inserted)
            AND versionRow.MembershipContentHash <> hashValue.CalculatedHash
    )
    BEGIN
        THROW 53440, ''RuleSetVersion membership hash does not match its ordered occurrence payload.'', 1;
    END;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_BuildSetVersionMember_InsertContract
ON ATAPUtilities.BuildSetVersionMember
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM ATAPUtilities.BuildSetVersionMember AS memberRow
        INNER JOIN ATAPUtilities.BuildSetMembershipRole AS roleRow
            ON roleRow.MembershipRoleCode = memberRow.MembershipRoleCode
        WHERE memberRow.BuildSetVersionId IN (SELECT BuildSetVersionId FROM inserted)
        GROUP BY memberRow.BuildSetVersionId, memberRow.RuleSetVersionId
        HAVING COUNT_BIG(*) > 1
            AND MIN(CONVERT(INT, roleRow.AllowsRepeatedChild)) = 0
    )
    BEGIN
        THROW 53441, ''A RuleSetVersion repeat uses a role that forbids repeated children.'', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM ATAPUtilities.BuildSetVersionMember AS memberRow
        WHERE memberRow.BuildSetVersionId IN (SELECT BuildSetVersionId FROM inserted)
        GROUP BY memberRow.BuildSetVersionId
        HAVING MIN(memberRow.Ordinal) <> 0
            OR MAX(memberRow.Ordinal) <> COUNT_BIG(*) - 1
    )
    BEGIN
        THROW 53442, ''BuildSetVersion member ordinals must be zero-based and gap-free.'', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM ATAPUtilities.BuildSetVersion AS versionRow
        CROSS APPLY
        (
            SELECT HASHBYTES
            (
                ''SHA2_256'',
                CONVERT
                (
                    VARBINARY(MAX),
                    STRING_AGG
                    (
                        CONVERT
                        (
                            VARCHAR(MAX),
                            CONCAT
                            (
                                memberRow.MemberOccurrenceKey, '':'',
                                memberRow.RuleSetVersionId, '':'',
                                memberRow.MembershipRoleCode, '':'',
                                COALESCE(CONVERT(VARCHAR(20), memberRow.MembershipRationaleEntityId), ''-''), '':'',
                                COALESCE(CONVERT(VARCHAR(20), memberRow.MembershipRationaleEntityTypeId), ''-'')
                            )
                        ),
                        ''|''
                    ) WITHIN GROUP (ORDER BY memberRow.Ordinal)
                )
            ) AS CalculatedHash
            FROM ATAPUtilities.BuildSetVersionMember AS memberRow
            WHERE memberRow.BuildSetVersionId = versionRow.BuildSetVersionId
        ) AS hashValue
        WHERE versionRow.BuildSetVersionId IN (SELECT BuildSetVersionId FROM inserted)
            AND versionRow.MembershipContentHash <> hashValue.CalculatedHash
    )
    BEGIN
        THROW 53443, ''BuildSetVersion membership hash does not match its ordered occurrence payload.'', 1;
    END;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_RuleSetVersionMember_UpdateDeleteImmutable
ON ATAPUtilities.RuleSetVersionMember
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 53444, ''RuleSetVersionMember rows are immutable.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_BuildSetVersionMember_UpdateDeleteImmutable
ON ATAPUtilities.BuildSetVersionMember
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 53445, ''BuildSetVersionMember rows are immutable.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE ATAPUtilities.usp_PublishRuleSetVersion
    @RuleSetVersionPhiloteId uniqueidentifier,
    @EntityId bigint,
    @EntityTypeId bigint,
    @RuleSetId bigint,
    @RevisionSequence int,
    @PredecessorRuleSetVersionId bigint = NULL,
    @MembershipContentHash binary(32),
    @PublishedAtUtc datetime2(7),
    @MembersJson nvarchar(max),
    @RuleSetVersionId bigint OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT <> 0 THROW 53447, ''Publication procedures require no ambient transaction.'', 1;
    IF ISJSON(@MembersJson) <> 1 THROW 53448, ''RuleSet members must be a valid JSON array.'', 1;

    DECLARE @Members table
    (
        PhiloteId uniqueidentifier NOT NULL PRIMARY KEY,
        MemberOccurrenceKey varchar(128) NOT NULL,
        Ordinal int NOT NULL,
        RuleVersionId bigint NOT NULL,
        MembershipRoleCode varchar(128) NOT NULL,
        MembershipRationaleEntityId bigint NULL,
        MembershipRationaleEntityTypeId bigint NULL
    );
    INSERT @Members
    SELECT * FROM OPENJSON(@MembersJson) WITH
    (PhiloteId uniqueidentifier ''$.PhiloteId'', MemberOccurrenceKey varchar(128) ''$.MemberOccurrenceKey'',
     Ordinal int ''$.Ordinal'', RuleVersionId bigint ''$.RuleVersionId'', MembershipRoleCode varchar(128) ''$.MembershipRoleCode'',
     MembershipRationaleEntityId bigint ''$.MembershipRationaleEntityId'', MembershipRationaleEntityTypeId bigint ''$.MembershipRationaleEntityTypeId'');

    IF NOT EXISTS (SELECT 1 FROM @Members)
       OR EXISTS (SELECT 1 FROM @Members GROUP BY MemberOccurrenceKey HAVING COUNT_BIG(*) <> 1)
       OR (SELECT MIN(Ordinal) FROM @Members) <> 0
       OR (SELECT MAX(Ordinal) FROM @Members) <> (SELECT COUNT_BIG(*) - 1 FROM @Members)
        THROW 53449, ''RuleSet publication requires a nonempty, gap-free occurrence set.'', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.RuleSet WITH (UPDLOCK, HOLDLOCK) WHERE RuleSetId = @RuleSetId)
            THROW 53450, ''RuleSet does not exist.'', 1;
        IF @PublishedAtUtc > SYSUTCDATETIME()
           OR (@PredecessorRuleSetVersionId IS NULL AND @RevisionSequence <> 1)
           OR (@PredecessorRuleSetVersionId IS NOT NULL AND NOT EXISTS
              (SELECT 1 FROM ATAPUtilities.RuleSetVersion WITH (UPDLOCK, HOLDLOCK)
               WHERE RuleSetVersionId = @PredecessorRuleSetVersionId AND RuleSetId = @RuleSetId
                 AND RevisionSequence + 1 = @RevisionSequence AND PublishedAtUtc < @PublishedAtUtc))
            THROW 53451, ''RuleSetVersion lineage or publication time is invalid.'', 1;

        INSERT ATAPUtilities.RuleSetVersion
            (RuleSetVersionPhiloteId, EntityId, EntityTypeId, EntityTypeCode, RuleSetId, RevisionSequence,
             PredecessorRuleSetVersionId, MembershipHashAlgorithmCode, MembershipContentHash, PublishedAtUtc)
        VALUES (@RuleSetVersionPhiloteId, @EntityId, @EntityTypeId, ''rule-set-version'', @RuleSetId, @RevisionSequence,
                @PredecessorRuleSetVersionId, ''sha256'', @MembershipContentHash, @PublishedAtUtc);
        SET @RuleSetVersionId = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT ATAPUtilities.RuleSetVersionMember
            (RuleSetVersionMemberPhiloteId, RuleSetVersionId, MemberOccurrenceKey, Ordinal, RuleVersionId,
             MembershipRoleCode, MembershipRationaleEntityId, MembershipRationaleEntityTypeId)
        SELECT PhiloteId, @RuleSetVersionId, MemberOccurrenceKey, Ordinal, RuleVersionId,
               MembershipRoleCode, MembershipRationaleEntityId, MembershipRationaleEntityTypeId
        FROM @Members;

        IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.RuleSetVersionMember WHERE RuleSetVersionId = @RuleSetVersionId)
           <> (SELECT COUNT_BIG(*) FROM @Members)
            THROW 53452, ''RuleSetVersion publication did not materialize the complete supplied aggregate.'', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE ATAPUtilities.usp_PublishBuildSetVersion
    @BuildSetVersionPhiloteId uniqueidentifier,
    @EntityId bigint,
    @EntityTypeId bigint,
    @BuildSetId bigint,
    @RevisionSequence int,
    @PredecessorBuildSetVersionId bigint = NULL,
    @MembershipContentHash binary(32),
    @PublishedAtUtc datetime2(7),
    @MembersJson nvarchar(max),
    @BuildSetVersionId bigint OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT <> 0 THROW 53453, ''Publication procedures require no ambient transaction.'', 1;
    IF ISJSON(@MembersJson) <> 1 THROW 53454, ''BuildSet members must be a valid JSON array.'', 1;

    DECLARE @Members table
    (
        PhiloteId uniqueidentifier NOT NULL PRIMARY KEY,
        MemberOccurrenceKey varchar(128) NOT NULL,
        Ordinal int NOT NULL,
        RuleSetVersionId bigint NOT NULL,
        MembershipRoleCode varchar(128) NOT NULL,
        MembershipRationaleEntityId bigint NULL,
        MembershipRationaleEntityTypeId bigint NULL
    );
    INSERT @Members
    SELECT * FROM OPENJSON(@MembersJson) WITH
    (PhiloteId uniqueidentifier ''$.PhiloteId'', MemberOccurrenceKey varchar(128) ''$.MemberOccurrenceKey'',
     Ordinal int ''$.Ordinal'', RuleSetVersionId bigint ''$.RuleSetVersionId'', MembershipRoleCode varchar(128) ''$.MembershipRoleCode'',
     MembershipRationaleEntityId bigint ''$.MembershipRationaleEntityId'', MembershipRationaleEntityTypeId bigint ''$.MembershipRationaleEntityTypeId'');

    IF NOT EXISTS (SELECT 1 FROM @Members)
       OR EXISTS (SELECT 1 FROM @Members GROUP BY MemberOccurrenceKey HAVING COUNT_BIG(*) <> 1)
       OR (SELECT MIN(Ordinal) FROM @Members) <> 0
       OR (SELECT MAX(Ordinal) FROM @Members) <> (SELECT COUNT_BIG(*) - 1 FROM @Members)
        THROW 53455, ''BuildSet publication requires a nonempty, gap-free occurrence set.'', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.BuildSet WITH (UPDLOCK, HOLDLOCK) WHERE BuildSetId = @BuildSetId)
            THROW 53456, ''BuildSet does not exist.'', 1;
        IF @PublishedAtUtc > SYSUTCDATETIME()
           OR (@PredecessorBuildSetVersionId IS NULL AND @RevisionSequence <> 1)
           OR (@PredecessorBuildSetVersionId IS NOT NULL AND NOT EXISTS
              (SELECT 1 FROM ATAPUtilities.BuildSetVersion WITH (UPDLOCK, HOLDLOCK)
               WHERE BuildSetVersionId = @PredecessorBuildSetVersionId AND BuildSetId = @BuildSetId
                 AND RevisionSequence + 1 = @RevisionSequence AND PublishedAtUtc < @PublishedAtUtc))
            THROW 53457, ''BuildSetVersion lineage or publication time is invalid.'', 1;

        INSERT ATAPUtilities.BuildSetVersion
            (BuildSetVersionPhiloteId, EntityId, EntityTypeId, EntityTypeCode, BuildSetId, RevisionSequence,
             PredecessorBuildSetVersionId, MembershipHashAlgorithmCode, MembershipContentHash, PublishedAtUtc)
        VALUES (@BuildSetVersionPhiloteId, @EntityId, @EntityTypeId, ''build-set-version'', @BuildSetId, @RevisionSequence,
                @PredecessorBuildSetVersionId, ''sha256'', @MembershipContentHash, @PublishedAtUtc);
        SET @BuildSetVersionId = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT ATAPUtilities.BuildSetVersionMember
            (BuildSetVersionMemberPhiloteId, BuildSetVersionId, MemberOccurrenceKey, Ordinal, RuleSetVersionId,
             MembershipRoleCode, MembershipRationaleEntityId, MembershipRationaleEntityTypeId)
        SELECT PhiloteId, @BuildSetVersionId, MemberOccurrenceKey, Ordinal, RuleSetVersionId,
               MembershipRoleCode, MembershipRationaleEntityId, MembershipRationaleEntityTypeId
        FROM @Members;

        IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.BuildSetVersionMember WHERE BuildSetVersionId = @BuildSetVersionId)
           <> (SELECT COUNT_BIG(*) FROM @Members)
            THROW 53458, ''BuildSetVersion publication did not materialize the complete supplied aggregate.'', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    IF DATABASE_PRINCIPAL_ID(N'RrsbsPublisher') IS NULL
        CREATE ROLE RrsbsPublisher AUTHORIZATION dbo;

    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.RuleSetMembershipRole TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.BuildSetMembershipRole TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.RuleSet TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.RuleSetVersion TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.RuleSetVersionMember TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.BuildSet TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.BuildSetVersion TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.BuildSetVersionMember TO RrsbsPublisher;
    GRANT EXECUTE ON OBJECT::ATAPUtilities.usp_PublishRuleSetVersion TO RrsbsPublisher;
    GRANT EXECUTE ON OBJECT::ATAPUtilities.usp_PublishBuildSetVersion TO RrsbsPublisher;

    /* Fail closed on a partial or incompatible pre-existing schema. */
    IF EXISTS
    (
        SELECT requiredObject.ObjectName
        FROM
        (
            VALUES
                (N'ATAPUtilities.RuleSetMembershipRole', N'U'),
                (N'ATAPUtilities.BuildSetMembershipRole', N'U'),
                (N'ATAPUtilities.RuleSet', N'U'),
                (N'ATAPUtilities.RuleSetVersion', N'U'),
                (N'ATAPUtilities.RuleSetVersionMember', N'U'),
                (N'ATAPUtilities.BuildSet', N'U'),
                (N'ATAPUtilities.BuildSetVersion', N'U'),
                (N'ATAPUtilities.BuildSetVersionMember', N'U'),
                (N'ATAPUtilities.TR_RuleSetVersionMember_InsertContract', N'TR'),
                (N'ATAPUtilities.TR_BuildSetVersionMember_InsertContract', N'TR'),
                (N'ATAPUtilities.usp_PublishRuleSetVersion', N'P'),
                (N'ATAPUtilities.usp_PublishBuildSetVersion', N'P')
        ) AS requiredObject (ObjectName, ObjectType)
        WHERE OBJECT_ID(requiredObject.ObjectName, requiredObject.ObjectType) IS NULL
    )
    BEGIN
        THROW 53446, 'RDB-430 postcondition failed: a required table or trigger is absent.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM
        (
            VALUES
                (N'RuleSetMembershipRole', 1, 1, 0, 0, 1),
                (N'BuildSetMembershipRole', 1, 1, 0, 0, 1),
                (N'RuleSet', 3, 2, 2, 0, 1),
                (N'RuleSetVersion', 4, 3, 4, 1, 2),
                (N'RuleSetVersionMember', 5, 3, 4, 2, 2),
                (N'BuildSet', 3, 2, 2, 0, 1),
                (N'BuildSetVersion', 4, 3, 4, 1, 2),
                (N'BuildSetVersionMember', 5, 3, 4, 2, 2)
        ) AS expected
            (TableName, KeyConstraintCount, CheckConstraintCount,
             ForeignKeyCount, AdditionalIndexCount, TriggerCount)
        CROSS APPLY
        (
            SELECT OBJECT_ID(N'ATAPUtilities.' + expected.TableName, N'U') AS TableObjectId
        ) AS objectId
        WHERE
            (SELECT COUNT_BIG(*) FROM sys.key_constraints AS keyConstraint
             WHERE keyConstraint.parent_object_id = objectId.TableObjectId)
                < expected.KeyConstraintCount
            OR
            (SELECT COUNT_BIG(*) FROM sys.check_constraints AS checkConstraint
             WHERE checkConstraint.parent_object_id = objectId.TableObjectId
                AND checkConstraint.is_disabled = 0
                AND checkConstraint.is_not_trusted = 0)
                < expected.CheckConstraintCount
            OR
            (SELECT COUNT_BIG(*) FROM sys.foreign_keys AS foreignKey
             WHERE foreignKey.parent_object_id = objectId.TableObjectId
                AND foreignKey.is_disabled = 0
                AND foreignKey.is_not_trusted = 0)
                < expected.ForeignKeyCount
            OR
            (SELECT COUNT_BIG(*) FROM sys.indexes AS indexRow
             WHERE indexRow.object_id = objectId.TableObjectId
                AND indexRow.is_primary_key = 0
                AND indexRow.is_unique_constraint = 0
                AND indexRow.is_disabled = 0)
                < expected.AdditionalIndexCount
            OR
            (SELECT COUNT_BIG(*) FROM sys.triggers AS triggerRow
             WHERE triggerRow.parent_id = objectId.TableObjectId
                AND triggerRow.is_disabled = 0)
                < expected.TriggerCount
    )
    BEGIN
        THROW 53472, 'RDB-430 postcondition failed: constraint, index, or trigger coverage is incomplete.', 1;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;
    THROW;
END CATCH;

/*
Rollback-only fixture harness.

Enable only in a disposable, fully seeded rehearsal session:
  EXEC sys.sp_set_session_context @key=N'RRSBS_RUN_RDB430_FIXTURES', @value=1;
  EXEC sys.sp_set_session_context @key=N'RRSBS_RDB430_FIXTURE_CASE',
      @value=N'static';

Run each trigger case in a fresh session/transaction because SQL Server can
doom a transaction after a trigger rejects DML. Valid cases are `positive`,
`static`, `root-revision`, `future-publication`, `repeat-policy`, `hash`,
`gap`, `immutable-version`, and `immutable-member`.

The harness requires the four RDB-430 EntityType rows and at least one
published RuleVersion. It proves the positive repeated-child contract and
executes negative fixtures for normalization, FK, uniqueness, null-pair,
lineage, immutability, gap-free ordering, role repeat policy, and hash checks.
No fixture row is committed.
*/
IF TRY_CONVERT(BIT, SESSION_CONTEXT(N'RRSBS_RUN_RDB430_FIXTURES')) = 1
BEGIN
    SET XACT_ABORT OFF;
    BEGIN TRANSACTION;

    BEGIN TRY
        DECLARE @NowUtc DATETIME2(7) = SYSUTCDATETIME();
        DECLARE @FixtureCase VARCHAR(128) = COALESCE
        (
            TRY_CONVERT(VARCHAR(128), SESSION_CONTEXT(N'RRSBS_RDB430_FIXTURE_CASE')),
            'positive'
        );
        DECLARE @RuleVersionId BIGINT =
        (
            SELECT MIN(RuleVersionId)
            FROM ATAPUtilities.RuleVersion
        );
        DECLARE @RuleSetEntityTypeId BIGINT =
        (
            SELECT EntityTypeId FROM ATAPUtilities.EntityType WHERE EntityTypeCode = 'rule-set'
        );
        DECLARE @RuleSetVersionEntityTypeId BIGINT =
        (
            SELECT EntityTypeId FROM ATAPUtilities.EntityType WHERE EntityTypeCode = 'rule-set-version'
        );
        DECLARE @BuildSetEntityTypeId BIGINT =
        (
            SELECT EntityTypeId FROM ATAPUtilities.EntityType WHERE EntityTypeCode = 'build-set'
        );
        DECLARE @BuildSetVersionEntityTypeId BIGINT =
        (
            SELECT EntityTypeId FROM ATAPUtilities.EntityType WHERE EntityTypeCode = 'build-set-version'
        );

        IF @RuleVersionId IS NULL
            OR @RuleSetEntityTypeId IS NULL
            OR @RuleSetVersionEntityTypeId IS NULL
            OR @BuildSetEntityTypeId IS NULL
            OR @BuildSetVersionEntityTypeId IS NULL
        BEGIN
            THROW 53447, 'RDB-430 fixtures require seeded EntityTypes and one RuleVersion.', 1;
        END;

        INSERT ATAPUtilities.RuleSetMembershipRole (MembershipRoleCode, AllowsRepeatedChild)
        VALUES ('fixture-repeat', 1), ('fixture-single', 0);
        INSERT ATAPUtilities.BuildSetMembershipRole (MembershipRoleCode, AllowsRepeatedChild)
        VALUES ('fixture-repeat', 1), ('fixture-single', 0);

        DECLARE @RuleSetEntity TABLE (EntityId BIGINT NOT NULL);
        DECLARE @RuleSetVersionEntity TABLE (EntityId BIGINT NOT NULL);
        DECLARE @BuildSetEntity TABLE (EntityId BIGINT NOT NULL);
        DECLARE @BuildSetVersionEntity TABLE (EntityId BIGINT NOT NULL);

        INSERT ATAPUtilities.Entity (EntityTypeId, EntityPhiloteId, CreatedAtUtc)
            OUTPUT inserted.EntityId INTO @RuleSetEntity
        VALUES (@RuleSetEntityTypeId, '43000000-0000-0000-0000-000000000001', @NowUtc);
        INSERT ATAPUtilities.Entity (EntityTypeId, EntityPhiloteId, CreatedAtUtc)
            OUTPUT inserted.EntityId INTO @RuleSetVersionEntity
        VALUES (@RuleSetVersionEntityTypeId, '43000000-0000-0000-0000-000000000002', @NowUtc);
        INSERT ATAPUtilities.Entity (EntityTypeId, EntityPhiloteId, CreatedAtUtc)
            OUTPUT inserted.EntityId INTO @BuildSetEntity
        VALUES (@BuildSetEntityTypeId, '43000000-0000-0000-0000-000000000003', @NowUtc);
        INSERT ATAPUtilities.Entity (EntityTypeId, EntityPhiloteId, CreatedAtUtc)
            OUTPUT inserted.EntityId INTO @BuildSetVersionEntity
        VALUES (@BuildSetVersionEntityTypeId, '43000000-0000-0000-0000-000000000004', @NowUtc);

        DECLARE @RuleSetId BIGINT;
        INSERT ATAPUtilities.RuleSet
            (RuleSetPhiloteId, EntityId, EntityTypeId, EntityTypeCode, RuleSetCode, CreatedAtUtc)
        SELECT
            '43000000-0000-0000-0000-000000000001', EntityId,
            @RuleSetEntityTypeId, 'rule-set', 'rdb430-fixture-ruleset', @NowUtc
        FROM @RuleSetEntity;
        SET @RuleSetId = SCOPE_IDENTITY();

        DECLARE @RuleSetPayload VARCHAR(MAX) =
            CONCAT('compile-a:', @RuleVersionId, ':fixture-repeat:-:-|compile-b:',
                @RuleVersionId, ':fixture-repeat:-:-');
        DECLARE @RuleSetVersionId BIGINT;
        INSERT ATAPUtilities.RuleSetVersion
            (RuleSetVersionPhiloteId, EntityId, EntityTypeId, EntityTypeCode, RuleSetId,
             RevisionSequence, PredecessorRuleSetVersionId,
             MembershipHashAlgorithmCode, MembershipContentHash, PublishedAtUtc)
        SELECT
            '43000000-0000-0000-0000-000000000002', EntityId,
            @RuleSetVersionEntityTypeId, 'rule-set-version', @RuleSetId, 1, NULL,
            'sha256', HASHBYTES('SHA2_256', CONVERT(VARBINARY(MAX), @RuleSetPayload)), @NowUtc
        FROM @RuleSetVersionEntity;
        SET @RuleSetVersionId = SCOPE_IDENTITY();

        /* Positive fixture: the same RuleVersion occurs twice without identity collapse. */
        INSERT ATAPUtilities.RuleSetVersionMember
            (RuleSetVersionMemberPhiloteId, RuleSetVersionId, MemberOccurrenceKey,
             Ordinal, RuleVersionId, MembershipRoleCode)
        VALUES
            ('43000000-0000-0000-0000-000000000011', @RuleSetVersionId,
             'compile-a', 0, @RuleVersionId, 'fixture-repeat'),
            ('43000000-0000-0000-0000-000000000012', @RuleSetVersionId,
             'compile-b', 1, @RuleVersionId, 'fixture-repeat');

        DECLARE @BuildSetId BIGINT;
        INSERT ATAPUtilities.BuildSet
            (BuildSetPhiloteId, EntityId, EntityTypeId, EntityTypeCode, BuildSetCode, CreatedAtUtc)
        SELECT
            '43000000-0000-0000-0000-000000000003', EntityId,
            @BuildSetEntityTypeId, 'build-set', 'rdb430-fixture-buildset', @NowUtc
        FROM @BuildSetEntity;
        SET @BuildSetId = SCOPE_IDENTITY();

        DECLARE @BuildSetPayload VARCHAR(MAX) =
            CONCAT('phase-a:', @RuleSetVersionId, ':fixture-repeat:-:-|phase-b:',
                @RuleSetVersionId, ':fixture-repeat:-:-');
        DECLARE @BuildSetVersionId BIGINT;
        INSERT ATAPUtilities.BuildSetVersion
            (BuildSetVersionPhiloteId, EntityId, EntityTypeId, EntityTypeCode, BuildSetId,
             RevisionSequence, PredecessorBuildSetVersionId,
             MembershipHashAlgorithmCode, MembershipContentHash, PublishedAtUtc)
        SELECT
            '43000000-0000-0000-0000-000000000004', EntityId,
            @BuildSetVersionEntityTypeId, 'build-set-version', @BuildSetId, 1, NULL,
            'sha256', HASHBYTES('SHA2_256', CONVERT(VARBINARY(MAX), @BuildSetPayload)), @NowUtc
        FROM @BuildSetVersionEntity;
        SET @BuildSetVersionId = SCOPE_IDENTITY();

        /* Positive fixture: the same RuleSetVersion occurs twice with distinct keys. */
        INSERT ATAPUtilities.BuildSetVersionMember
            (BuildSetVersionMemberPhiloteId, BuildSetVersionId, MemberOccurrenceKey,
             Ordinal, RuleSetVersionId, MembershipRoleCode)
        VALUES
            ('43000000-0000-0000-0000-000000000021', @BuildSetVersionId,
             'phase-a', 0, @RuleSetVersionId, 'fixture-repeat'),
            ('43000000-0000-0000-0000-000000000022', @BuildSetVersionId,
             'phase-b', 1, @RuleSetVersionId, 'fixture-repeat');

        IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.RuleSetVersionMember
            WHERE RuleSetVersionId = @RuleSetVersionId AND RuleVersionId = @RuleVersionId) <> 2
            OR (SELECT COUNT_BIG(*) FROM ATAPUtilities.BuildSetVersionMember
            WHERE BuildSetVersionId = @BuildSetVersionId AND RuleSetVersionId = @RuleSetVersionId) <> 2
        BEGIN
            THROW 53448, 'RDB-430 positive repeated-occurrence fixture failed.', 1;
        END;

        /* Allocate prerequisite Entity rows for isolated negative fixtures. */
        DECLARE @FixtureEntities TABLE
        (
            PurposeCode VARCHAR(128) NOT NULL PRIMARY KEY,
            EntityId BIGINT NOT NULL,
            EntityPhiloteId UNIQUEIDENTIFIER NOT NULL
        );

        MERGE INTO ATAPUtilities.Entity AS target
        USING
        (
            VALUES
                ('ruleset-code-duplicate', @RuleSetEntityTypeId,
                    CONVERT(UNIQUEIDENTIFIER, '43000000-0000-0000-0000-000000000101'), @NowUtc),
                ('ruleset-code-normalized', @RuleSetEntityTypeId,
                    CONVERT(UNIQUEIDENTIFIER, '43000000-0000-0000-0000-000000000102'), @NowUtc),
                ('ruleset-second', @RuleSetEntityTypeId,
                    CONVERT(UNIQUEIDENTIFIER, '43000000-0000-0000-0000-000000000103'), @NowUtc),
                ('rulesetversion-hash', @RuleSetVersionEntityTypeId,
                    CONVERT(UNIQUEIDENTIFIER, '43000000-0000-0000-0000-000000000104'), @NowUtc),
                ('rulesetversion-second', @RuleSetVersionEntityTypeId,
                    CONVERT(UNIQUEIDENTIFIER, '43000000-0000-0000-0000-000000000105'), @NowUtc),
                ('rulesetversion-branch-a', @RuleSetVersionEntityTypeId,
                    CONVERT(UNIQUEIDENTIFIER, '43000000-0000-0000-0000-000000000106'), @NowUtc),
                ('rulesetversion-branch-b', @RuleSetVersionEntityTypeId,
                    CONVERT(UNIQUEIDENTIFIER, '43000000-0000-0000-0000-000000000107'), @NowUtc),
                ('buildset-code-normalized', @BuildSetEntityTypeId,
                    CONVERT(UNIQUEIDENTIFIER, '43000000-0000-0000-0000-000000000108'), @NowUtc),
                ('buildsetversion-lineage', @BuildSetVersionEntityTypeId,
                    CONVERT(UNIQUEIDENTIFIER, '43000000-0000-0000-0000-000000000109'), @NowUtc)
        ) AS source (PurposeCode, EntityTypeId, EntityPhiloteId, CreatedAtUtc)
        ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT (EntityTypeId, EntityPhiloteId, CreatedAtUtc)
            VALUES (source.EntityTypeId, source.EntityPhiloteId, source.CreatedAtUtc)
        OUTPUT source.PurposeCode, inserted.EntityId, inserted.EntityPhiloteId
            INTO @FixtureEntities (PurposeCode, EntityId, EntityPhiloteId);

        IF @FixtureCase = 'static'
        BEGIN
        /* Invalid catalog CK: role codes are normalized controlled values. */
        BEGIN TRY
            INSERT ATAPUtilities.RuleSetMembershipRole
                (MembershipRoleCode, AllowsRepeatedChild)
            VALUES ('Bad Role', 1);
            THROW 53460, 'Expected membership-role normalization CK rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53460 THROW;
            IF ERROR_NUMBER() <> 547 THROW;
        END CATCH;

        /* Invalid durable UQ: duplicate RuleSetCode with a valid distinct Entity. */
        BEGIN TRY
            INSERT ATAPUtilities.RuleSet
                (RuleSetPhiloteId, EntityId, EntityTypeId, EntityTypeCode, RuleSetCode, CreatedAtUtc)
            SELECT EntityPhiloteId, EntityId, @RuleSetEntityTypeId, 'rule-set',
                'rdb430-fixture-ruleset', @NowUtc
            FROM @FixtureEntities WHERE PurposeCode = 'ruleset-code-duplicate';
            THROW 53461, 'Expected durable-code UQ rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53461 THROW;
            IF ERROR_NUMBER() NOT IN (2601, 2627) THROW;
        END CATCH;

        /* Invalid durable UQ: one table-specific Philote cannot identify two rows. */
        BEGIN TRY
            INSERT ATAPUtilities.RuleSet
                (RuleSetPhiloteId, EntityId, EntityTypeId, EntityTypeCode, RuleSetCode, CreatedAtUtc)
            SELECT '43000000-0000-0000-0000-000000000001', EntityId,
                @RuleSetEntityTypeId, 'rule-set', 'rdb430-fixture-ruleset-alias', @NowUtc
            FROM @RuleSetEntity;
            THROW 53462, 'Expected RuleSet Philote UQ rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53462 THROW;
            IF ERROR_NUMBER() NOT IN (2601, 2627) THROW;
        END CATCH;

        /* Invalid durable CK: codes cannot use display-label normalization. */
        BEGIN TRY
            INSERT ATAPUtilities.RuleSet
                (RuleSetPhiloteId, EntityId, EntityTypeId, EntityTypeCode, RuleSetCode, CreatedAtUtc)
            SELECT EntityPhiloteId, EntityId, @RuleSetEntityTypeId, 'rule-set',
                'Bad RuleSet Code', @NowUtc
            FROM @FixtureEntities WHERE PurposeCode = 'ruleset-code-normalized';
            THROW 53463, 'Expected durable-code normalization CK rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53463 THROW;
            IF ERROR_NUMBER() <> 547 THROW;
        END CATCH;

        /* Invalid exact Entity triple: the subtype Philote must equal EntityPhiloteId. */
        BEGIN TRY
            INSERT ATAPUtilities.BuildSet
                (BuildSetPhiloteId, EntityId, EntityTypeId, EntityTypeCode, BuildSetCode, CreatedAtUtc)
            SELECT '43000000-0000-0000-0000-000000000199', EntityId,
                @BuildSetEntityTypeId, 'build-set', 'wrong-entity-triple', @NowUtc
            FROM @BuildSetEntity;
            THROW 53464, 'Expected exact Entity triple FK rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53464 THROW;
            IF ERROR_NUMBER() <> 547 THROW;
        END CATCH;

        /* Invalid version CK: only an exact 32-byte SHA-256 membership hash is valid. */
        BEGIN TRY
            INSERT ATAPUtilities.RuleSetVersion
                (RuleSetVersionPhiloteId, EntityId, EntityTypeId, EntityTypeCode, RuleSetId,
                 RevisionSequence, PredecessorRuleSetVersionId,
                 MembershipHashAlgorithmCode, MembershipContentHash, PublishedAtUtc)
            SELECT EntityPhiloteId, EntityId, @RuleSetVersionEntityTypeId, 'rule-set-version',
                @RuleSetId, 2, @RuleSetVersionId, 'sha1', 0x01, @NowUtc
            FROM @FixtureEntities WHERE PurposeCode = 'rulesetversion-hash';
            THROW 53465, 'Expected membership-hash CK rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53465 THROW;
            IF ERROR_NUMBER() <> 547 THROW;
        END CATCH;
        END;

        DECLARE @SecondRuleSetId BIGINT;
        INSERT ATAPUtilities.RuleSet
            (RuleSetPhiloteId, EntityId, EntityTypeId, EntityTypeCode, RuleSetCode, CreatedAtUtc)
        SELECT EntityPhiloteId, EntityId, @RuleSetEntityTypeId, 'rule-set',
            'rdb430-fixture-ruleset-second', @NowUtc
        FROM @FixtureEntities WHERE PurposeCode = 'ruleset-second';
        SET @SecondRuleSetId = SCOPE_IDENTITY();

        IF @FixtureCase = 'static'
        BEGIN
        /* Invalid composite FK: predecessor lineage cannot cross durable parents. */
        BEGIN TRY
            INSERT ATAPUtilities.RuleSetVersion
                (RuleSetVersionPhiloteId, EntityId, EntityTypeId, EntityTypeCode, RuleSetId,
                 RevisionSequence, PredecessorRuleSetVersionId,
                 MembershipHashAlgorithmCode, MembershipContentHash, PublishedAtUtc)
            SELECT EntityPhiloteId, EntityId, @RuleSetVersionEntityTypeId, 'rule-set-version',
                @SecondRuleSetId, 2, @RuleSetVersionId, 'sha256',
                HASHBYTES('SHA2_256', 0x), @NowUtc
            FROM @FixtureEntities WHERE PurposeCode = 'rulesetversion-second';
            THROW 53466, 'Expected same-parent predecessor FK rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53466 THROW;
            IF ERROR_NUMBER() <> 547 THROW;
        END CATCH;
        END;

        IF @FixtureCase = 'root-revision'
        BEGIN
        /* Invalid lineage trigger: a root must begin at revision one. */
        BEGIN TRY
            INSERT ATAPUtilities.RuleSetVersion
                (RuleSetVersionPhiloteId, EntityId, EntityTypeId, EntityTypeCode, RuleSetId,
                 RevisionSequence, PredecessorRuleSetVersionId,
                 MembershipHashAlgorithmCode, MembershipContentHash, PublishedAtUtc)
            SELECT EntityPhiloteId, EntityId, @RuleSetVersionEntityTypeId, 'rule-set-version',
                @SecondRuleSetId, 2, NULL, 'sha256', HASHBYTES('SHA2_256', 0x), @NowUtc
            FROM @FixtureEntities WHERE PurposeCode = 'rulesetversion-second';
            THROW 53467, 'Expected root revision-lineage trigger rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53467 THROW;
            IF ERROR_NUMBER() <> 53434 THROW;
        END CATCH;
        END;

        IF @FixtureCase = 'future-publication'
        BEGIN
        /* Invalid lineage trigger: future timestamps are not publication scheduling. */
        BEGIN TRY
            INSERT ATAPUtilities.BuildSetVersion
                (BuildSetVersionPhiloteId, EntityId, EntityTypeId, EntityTypeCode, BuildSetId,
                 RevisionSequence, PredecessorBuildSetVersionId,
                 MembershipHashAlgorithmCode, MembershipContentHash, PublishedAtUtc)
            SELECT EntityPhiloteId, EntityId, @BuildSetVersionEntityTypeId, 'build-set-version',
                @BuildSetId, 2, @BuildSetVersionId, 'sha256',
                HASHBYTES('SHA2_256', 0x), DATEADD(DAY, 1, @NowUtc)
            FROM @FixtureEntities WHERE PurposeCode = 'buildsetversion-lineage';
            THROW 53468, 'Expected future publication-time trigger rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53468 THROW;
            IF ERROR_NUMBER() <> 53435 THROW;
        END CATCH;
        END;

        IF @FixtureCase = 'repeat-policy'
        BEGIN
        /* Create a valid second root whose repeated-child policy is intentionally invalid. */
        DECLARE @SingleRolePayload VARCHAR(MAX) =
            CONCAT('single-a:', @RuleVersionId, ':fixture-single:-:-|single-b:',
                @RuleVersionId, ':fixture-single:-:-');
        DECLARE @SecondRuleSetVersionId BIGINT;
        INSERT ATAPUtilities.RuleSetVersion
            (RuleSetVersionPhiloteId, EntityId, EntityTypeId, EntityTypeCode, RuleSetId,
             RevisionSequence, PredecessorRuleSetVersionId,
             MembershipHashAlgorithmCode, MembershipContentHash, PublishedAtUtc)
        SELECT EntityPhiloteId, EntityId, @RuleSetVersionEntityTypeId, 'rule-set-version',
            @SecondRuleSetId, 1, NULL, 'sha256',
            HASHBYTES('SHA2_256', CONVERT(VARBINARY(MAX), @SingleRolePayload)), @NowUtc
        FROM @FixtureEntities WHERE PurposeCode = 'rulesetversion-second';
        SET @SecondRuleSetVersionId = SCOPE_IDENTITY();

        /* Invalid role policy: repeated child requires every occurrence role to allow it. */
        BEGIN TRY
            INSERT ATAPUtilities.RuleSetVersionMember
                (RuleSetVersionMemberPhiloteId, RuleSetVersionId, MemberOccurrenceKey,
                 Ordinal, RuleVersionId, MembershipRoleCode)
            VALUES
                ('43000000-0000-0000-0000-000000000141', @SecondRuleSetVersionId,
                 'single-a', 0, @RuleVersionId, 'fixture-single'),
                ('43000000-0000-0000-0000-000000000142', @SecondRuleSetVersionId,
                 'single-b', 1, @RuleVersionId, 'fixture-single');
            THROW 53469, 'Expected repeated-child role-policy rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53469 THROW;
            IF ERROR_NUMBER() <> 53438 THROW;
        END CATCH;
        END;

        IF @FixtureCase = 'static'
        BEGIN
        /* Invalid parent FK: a matching key in another parent cannot substitute. */
        BEGIN TRY
            INSERT ATAPUtilities.BuildSetVersionMember
                (BuildSetVersionMemberPhiloteId, BuildSetVersionId, MemberOccurrenceKey,
                 Ordinal, RuleSetVersionId, MembershipRoleCode)
            VALUES ('43000000-0000-0000-0000-000000000143', -430,
                'foreign-parent', 0, @RuleSetVersionId, 'fixture-repeat');
            THROW 53470, 'Expected exact parent-version FK rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53470 THROW;
            IF ERROR_NUMBER() <> 547 THROW;
        END CATCH;

        /* Invalid rationale FK: the typed pair must identify one exact Entity. */
        BEGIN TRY
            INSERT ATAPUtilities.RuleSetVersionMember
                (RuleSetVersionMemberPhiloteId, RuleSetVersionId, MemberOccurrenceKey,
                 Ordinal, RuleVersionId, MembershipRoleCode,
                 MembershipRationaleEntityId, MembershipRationaleEntityTypeId)
            VALUES ('43000000-0000-0000-0000-000000000144', @RuleSetVersionId,
                'bad-rationale', 2, @RuleVersionId, 'fixture-repeat', -430, -430);
            THROW 53471, 'Expected typed-rationale Entity FK rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53471 THROW;
            IF ERROR_NUMBER() <> 547 THROW;
        END CATCH;

        /* Invalid CK: unnormalized occurrence key. */
        BEGIN TRY
            INSERT ATAPUtilities.RuleSetVersionMember
                (RuleSetVersionMemberPhiloteId, RuleSetVersionId, MemberOccurrenceKey,
                 Ordinal, RuleVersionId, MembershipRoleCode)
            VALUES ('43000000-0000-0000-0000-000000000031', @RuleSetVersionId,
                'Bad Key', 2, @RuleVersionId, 'fixture-repeat');
            THROW 53449, 'Expected occurrence-key CK rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53449 THROW;
            IF ERROR_NUMBER() <> 547 THROW;
        END CATCH;

        /* Invalid CK: negative ordinal. */
        BEGIN TRY
            INSERT ATAPUtilities.BuildSetVersionMember
                (BuildSetVersionMemberPhiloteId, BuildSetVersionId, MemberOccurrenceKey,
                 Ordinal, RuleSetVersionId, MembershipRoleCode)
            VALUES ('43000000-0000-0000-0000-000000000032', @BuildSetVersionId,
                'negative', -1, @RuleSetVersionId, 'fixture-repeat');
            THROW 53450, 'Expected ordinal CK rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53450 THROW;
            IF ERROR_NUMBER() <> 547 THROW;
        END CATCH;

        /* Invalid UQ: duplicate parent-scoped occurrence key. */
        BEGIN TRY
            INSERT ATAPUtilities.RuleSetVersionMember
                (RuleSetVersionMemberPhiloteId, RuleSetVersionId, MemberOccurrenceKey,
                 Ordinal, RuleVersionId, MembershipRoleCode)
            VALUES ('43000000-0000-0000-0000-000000000033', @RuleSetVersionId,
                'compile-a', 2, @RuleVersionId, 'fixture-repeat');
            THROW 53451, 'Expected occurrence-key UQ rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53451 THROW;
            IF ERROR_NUMBER() NOT IN (2601, 2627) THROW;
        END CATCH;

        /* Invalid UQ: duplicate parent-scoped ordinal. */
        BEGIN TRY
            INSERT ATAPUtilities.BuildSetVersionMember
                (BuildSetVersionMemberPhiloteId, BuildSetVersionId, MemberOccurrenceKey,
                 Ordinal, RuleSetVersionId, MembershipRoleCode)
            VALUES ('43000000-0000-0000-0000-000000000034', @BuildSetVersionId,
                'phase-c', 1, @RuleSetVersionId, 'fixture-repeat');
            THROW 53452, 'Expected ordinal UQ rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53452 THROW;
            IF ERROR_NUMBER() NOT IN (2601, 2627) THROW;
        END CATCH;

        /* Invalid FK: unknown exact child RuleVersion. */
        BEGIN TRY
            INSERT ATAPUtilities.RuleSetVersionMember
                (RuleSetVersionMemberPhiloteId, RuleSetVersionId, MemberOccurrenceKey,
                 Ordinal, RuleVersionId, MembershipRoleCode)
            VALUES ('43000000-0000-0000-0000-000000000035', @RuleSetVersionId,
                'unknown-child', 2, -430, 'fixture-repeat');
            THROW 53453, 'Expected exact RuleVersion FK rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53453 THROW;
            IF ERROR_NUMBER() <> 547 THROW;
        END CATCH;

        /* Invalid FK: unknown role. */
        BEGIN TRY
            INSERT ATAPUtilities.BuildSetVersionMember
                (BuildSetVersionMemberPhiloteId, BuildSetVersionId, MemberOccurrenceKey,
                 Ordinal, RuleSetVersionId, MembershipRoleCode)
            VALUES ('43000000-0000-0000-0000-000000000036', @BuildSetVersionId,
                'unknown-role', 2, @RuleSetVersionId, 'missing-role');
            THROW 53454, 'Expected membership-role FK rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53454 THROW;
            IF ERROR_NUMBER() <> 547 THROW;
        END CATCH;

        /* Invalid CK: a typed rationale must supply both identity columns. */
        BEGIN TRY
            INSERT ATAPUtilities.RuleSetVersionMember
                (RuleSetVersionMemberPhiloteId, RuleSetVersionId, MemberOccurrenceKey,
                 Ordinal, RuleVersionId, MembershipRoleCode,
                 MembershipRationaleEntityId, MembershipRationaleEntityTypeId)
            VALUES ('43000000-0000-0000-0000-000000000037', @RuleSetVersionId,
                'half-rationale', 2, @RuleVersionId, 'fixture-repeat',
                (SELECT EntityId FROM @RuleSetEntity), NULL);
            THROW 53455, 'Expected rationale null-parity CK rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53455 THROW;
            IF ERROR_NUMBER() <> 547 THROW;
        END CATCH;
        END;

        IF @FixtureCase = 'hash'
        BEGIN
        /* Invalid trigger: a contiguous member with an uncommitted hash is rejected. */
        BEGIN TRY
            INSERT ATAPUtilities.BuildSetVersionMember
                (BuildSetVersionMemberPhiloteId, BuildSetVersionId, MemberOccurrenceKey,
                 Ordinal, RuleSetVersionId, MembershipRoleCode)
            VALUES ('43000000-0000-0000-0000-000000000038', @BuildSetVersionId,
                'phase-c', 2, @RuleSetVersionId, 'fixture-repeat');
            THROW 53456, 'Expected membership-hash trigger rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53456 THROW;
            IF ERROR_NUMBER() <> 53443 THROW;
        END CATCH;
        END;

        IF @FixtureCase = 'gap'
        BEGIN
        /* Invalid trigger: a gapped ordinal is rejected before hash validation. */
        BEGIN TRY
            INSERT ATAPUtilities.RuleSetVersionMember
                (RuleSetVersionMemberPhiloteId, RuleSetVersionId, MemberOccurrenceKey,
                 Ordinal, RuleVersionId, MembershipRoleCode)
            VALUES ('43000000-0000-0000-0000-000000000039', @RuleSetVersionId,
                'gap', 3, @RuleVersionId, 'fixture-repeat');
            THROW 53457, 'Expected gap-free ordinal trigger rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53457 THROW;
            IF ERROR_NUMBER() <> 53439 THROW;
        END CATCH;
        END;

        IF @FixtureCase = 'immutable-version'
        BEGIN
        /* Invalid trigger: published aggregate rows are immutable. */
        BEGIN TRY
            UPDATE ATAPUtilities.RuleSetVersion
            SET PublishedAtUtc = PublishedAtUtc
            WHERE RuleSetVersionId = @RuleSetVersionId;
            THROW 53458, 'Expected RuleSetVersion immutability rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53458 THROW;
            IF ERROR_NUMBER() <> 53436 THROW;
        END CATCH;
        END;

        IF @FixtureCase = 'immutable-member'
        BEGIN
        /* Invalid trigger: published member rows are immutable. */
        BEGIN TRY
            DELETE FROM ATAPUtilities.BuildSetVersionMember
            WHERE BuildSetVersionId = @BuildSetVersionId AND Ordinal = 0;
            THROW 53459, 'Expected BuildSetVersionMember immutability rejection.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 53459 THROW;
            IF ERROR_NUMBER() <> 53445 THROW;
        END CATCH;
        END;

        /* The transaction always rolls back, including successful positive rows. */
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;
        SET XACT_ABORT ON;
        THROW;
    END CATCH;

    SET XACT_ABORT ON;
END;
/* END INTEGRATED FRAGMENT: RDB-430__RuleSet-BuildSet.sql */

/* BEGIN INTEGRATED FRAGMENT: RDB-440__Instantiation-InputBlock.sql */
/*
  RDB-440 Instantiation/InputBlock fragment (SQL Server 2022 / TSql160).

  RDB-480 integration contract:
  - Run after RDB-400/410, RDB-420, and RDB-430. No database-context,
    history-table, package, credential, reset, or live-system action appears.
  - Frozen RDB-270/RDB-320 wins: only Instantiation,
    InstantiationVersion, InputBlock, and InputBlockVersion are Entity subtypes.
  - Closed values use CHECK allow-lists; no unregistered catalog is invented.
  - Revision one uses the approved trusted-operation bootstrap: its EditSession
    base is NULL only inside RollItUp. Every successor requires the exact,
    same-Instantiation current base.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Rdb440OwnsTransaction bit = 0;
IF @@TRANCOUNT = 0
BEGIN
    BEGIN TRANSACTION;
    SET @Rdb440OwnsTransaction = 1;
END;
ELSE
    SAVE TRANSACTION Rdb440Fragment;

BEGIN TRY
    IF OBJECT_ID(N'ATAPUtilities.PermissionVerb', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.PermissionVerb
        (
            PermissionVerbCode VARCHAR(32) NOT NULL,
            CONSTRAINT PK_PermissionVerb PRIMARY KEY (PermissionVerbCode),
            CONSTRAINT CK_PermissionVerb_ClosedVerb CHECK
            (
                PermissionVerbCode IN
                ('view', 'edit', 'publish', 'fork', 'plan', 'execute', 'approve', 'read-artifacts')
            )
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.Instantiation', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.Instantiation
        (
            InstantiationId BIGINT IDENTITY(1, 1) NOT NULL,
            InstantiationPhiloteId UNIQUEIDENTIFIER NOT NULL,
            EntityId BIGINT NOT NULL,
            EntityTypeId BIGINT NOT NULL,
            EntityTypeCode AS CONVERT(VARCHAR(64), 'instantiation') PERSISTED,
            OwnerAuthorityReference VARCHAR(256) NOT NULL,
            ForkedFromInstantiationVersionId BIGINT NULL,
            CreatedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_Instantiation PRIMARY KEY (InstantiationId),
            CONSTRAINT UQ_Instantiation_InstantiationPhiloteId UNIQUE (InstantiationPhiloteId),
            CONSTRAINT UQ_Instantiation_InstantiationId_OwnerAuthorityReference
                UNIQUE (InstantiationId, OwnerAuthorityReference),
            CONSTRAINT CK_Instantiation_OwnerAuthorityReference CHECK
            (
                LEN(OwnerAuthorityReference) BETWEEN 3 AND 256
                AND OwnerAuthorityReference LIKE 'authority:%'
                AND OwnerAuthorityReference NOT LIKE '%[ ;=]%'
            ),
            CONSTRAINT FK_Instantiation_Entity_Registration FOREIGN KEY
                (EntityId, EntityTypeId, InstantiationPhiloteId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId, EntityPhiloteId),
            CONSTRAINT FK_Instantiation_EntityType_ClosedType FOREIGN KEY
                (EntityTypeId, EntityTypeCode)
                REFERENCES ATAPUtilities.EntityType (EntityTypeId, EntityTypeCode)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.InstantiationVersion', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.InstantiationVersion
        (
            InstantiationVersionId BIGINT IDENTITY(1, 1) NOT NULL,
            InstantiationVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            EntityId BIGINT NOT NULL,
            EntityTypeId BIGINT NOT NULL,
            EntityTypeCode AS CONVERT(VARCHAR(64), 'instantiation-version') PERSISTED,
            InstantiationId BIGINT NOT NULL,
            BuildSetVersionId BIGINT NOT NULL,
            RevisionSequence INT NOT NULL,
            PredecessorInstantiationVersionId BIGINT NULL,
            GraphInputHashAlgorithmCode VARCHAR(16) NOT NULL,
            GraphInputContentHash VARBINARY(64) NOT NULL,
            PublishedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_InstantiationVersion PRIMARY KEY (InstantiationVersionId),
            CONSTRAINT UQ_InstantiationVersion_InstantiationVersionPhiloteId UNIQUE
                (InstantiationVersionPhiloteId),
            CONSTRAINT UQ_InstantiationVersion_InstantiationId_RevisionSequence UNIQUE
                (InstantiationId, RevisionSequence),
            CONSTRAINT UQ_InstantiationVersion_InstantiationVersionId_InstantiationId UNIQUE
                (InstantiationVersionId, InstantiationId),
            CONSTRAINT UQ_InstantiationVersion_InstantiationVersionId_InstantiationId_BuildSetVersionId UNIQUE
                (InstantiationVersionId, InstantiationId, BuildSetVersionId),
            CONSTRAINT CK_InstantiationVersion_RevisionSequencePositive CHECK (RevisionSequence > 0),
            CONSTRAINT CK_InstantiationVersion_HashSha256 CHECK
            (
                GraphInputHashAlgorithmCode = 'sha256'
                AND DATALENGTH(GraphInputContentHash) = 32
            ),
            CONSTRAINT FK_InstantiationVersion_Entity_Registration FOREIGN KEY
                (EntityId, EntityTypeId, InstantiationVersionPhiloteId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId, EntityPhiloteId),
            CONSTRAINT FK_InstantiationVersion_EntityType_ClosedType FOREIGN KEY
                (EntityTypeId, EntityTypeCode)
                REFERENCES ATAPUtilities.EntityType (EntityTypeId, EntityTypeCode),
            CONSTRAINT FK_InstantiationVersion_Instantiation_Parent FOREIGN KEY (InstantiationId)
                REFERENCES ATAPUtilities.Instantiation (InstantiationId),
            CONSTRAINT FK_InstantiationVersion_BuildSetVersion_ExactVersion FOREIGN KEY (BuildSetVersionId)
                REFERENCES ATAPUtilities.BuildSetVersion (BuildSetVersionId),
            CONSTRAINT FK_InstantiationVersion_InstantiationVersion_PredecessorSameParent FOREIGN KEY
                (PredecessorInstantiationVersionId, InstantiationId)
                REFERENCES ATAPUtilities.InstantiationVersion (InstantiationVersionId, InstantiationId)
        );

        CREATE UNIQUE INDEX UQ_InstantiationVersion_PredecessorInstantiationVersionId
            ON ATAPUtilities.InstantiationVersion (PredecessorInstantiationVersionId)
            WHERE PredecessorInstantiationVersionId IS NOT NULL;
    END;

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.foreign_keys
        WHERE name = N'FK_Instantiation_InstantiationVersion_ForkSource'
          AND parent_object_id = OBJECT_ID(N'ATAPUtilities.Instantiation')
    )
    BEGIN
        ALTER TABLE ATAPUtilities.Instantiation WITH CHECK
        ADD CONSTRAINT FK_Instantiation_InstantiationVersion_ForkSource
            FOREIGN KEY (ForkedFromInstantiationVersionId)
            REFERENCES ATAPUtilities.InstantiationVersion (InstantiationVersionId);
    END;

    IF OBJECT_ID(N'ATAPUtilities.BuildSetRuleOccurrence', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.BuildSetRuleOccurrence
        (
            BuildSetRuleOccurrenceId BIGINT IDENTITY(1, 1) NOT NULL,
            BuildSetVersionId BIGINT NOT NULL,
            BuildSetVersionMemberId BIGINT NOT NULL,
            RuleSetVersionId BIGINT NOT NULL,
            RuleSetVersionMemberId BIGINT NOT NULL,
            RuleVersionId BIGINT NOT NULL,
            OccurrenceKey BINARY(32) NOT NULL,
            CONSTRAINT PK_BuildSetRuleOccurrence PRIMARY KEY (BuildSetRuleOccurrenceId),
            CONSTRAINT UQ_BuildSetRuleOccurrence_BuildSetVersionId_OccurrenceKey UNIQUE
                (BuildSetVersionId, OccurrenceKey),
            CONSTRAINT UQ_BuildSetRuleOccurrence_BuildSetRuleOccurrenceId_BuildSetVersionId_OccurrenceKey_RuleVersionId
                UNIQUE (BuildSetRuleOccurrenceId, BuildSetVersionId, OccurrenceKey, RuleVersionId),
            CONSTRAINT FK_BuildSetRuleOccurrence_BuildSetVersionMember_ExactPath FOREIGN KEY
                (BuildSetVersionMemberId, BuildSetVersionId, RuleSetVersionId)
                REFERENCES ATAPUtilities.BuildSetVersionMember
                (BuildSetVersionMemberId, BuildSetVersionId, RuleSetVersionId),
            CONSTRAINT FK_BuildSetRuleOccurrence_RuleSetVersionMember_ExactPath FOREIGN KEY
                (RuleSetVersionMemberId, RuleSetVersionId, RuleVersionId)
                REFERENCES ATAPUtilities.RuleSetVersionMember
                (RuleSetVersionMemberId, RuleSetVersionId, RuleVersionId)
        );

        CREATE INDEX IX_BuildSetRuleOccurrence_RuleVersionId
            ON ATAPUtilities.BuildSetRuleOccurrence (RuleVersionId);
    END;

    IF OBJECT_ID(N'ATAPUtilities.InstantiationOccurrenceBinding', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.InstantiationOccurrenceBinding
        (
            InstantiationOccurrenceBindingId BIGINT IDENTITY(1, 1) NOT NULL,
            InstantiationId BIGINT NOT NULL,
            BuildSetRuleOccurrenceId BIGINT NOT NULL,
            BuildSetVersionId BIGINT NOT NULL,
            OccurrenceKey BINARY(32) NOT NULL,
            RuleVersionId BIGINT NOT NULL,
            BindingCompatibilityContractVersionId BIGINT NULL,
            CreatedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_InstantiationOccurrenceBinding PRIMARY KEY
                (InstantiationOccurrenceBindingId),
            CONSTRAINT UQ_InstantiationOccurrenceBinding_InstantiationId_OccurrenceKey UNIQUE
                (InstantiationId, OccurrenceKey),
            CONSTRAINT UQ_InstantiationOccurrenceBinding_InstantiationOccurrenceBindingId_InstantiationId UNIQUE
                (InstantiationOccurrenceBindingId, InstantiationId),
            CONSTRAINT UQ_InstantiationOccurrenceBinding_InstantiationOccurrenceBindingId_InstantiationId_RuleVersionId UNIQUE
                (InstantiationOccurrenceBindingId, InstantiationId, RuleVersionId),
            CONSTRAINT UQ_InstantiationOccurrenceBinding_InstantiationOccurrenceBindingId_InstantiationId_BuildSetVersionId_OccurrenceKey_RuleVersionId UNIQUE
                (InstantiationOccurrenceBindingId, InstantiationId, BuildSetVersionId, OccurrenceKey, RuleVersionId),
            CONSTRAINT FK_InstantiationOccurrenceBinding_Instantiation_Owner FOREIGN KEY (InstantiationId)
                REFERENCES ATAPUtilities.Instantiation (InstantiationId),
            CONSTRAINT FK_InstantiationOccurrenceBinding_BuildSetRuleOccurrence_ExactOccurrence FOREIGN KEY
                (BuildSetRuleOccurrenceId, BuildSetVersionId, OccurrenceKey, RuleVersionId)
                REFERENCES ATAPUtilities.BuildSetRuleOccurrence
                (BuildSetRuleOccurrenceId, BuildSetVersionId, OccurrenceKey, RuleVersionId),
            CONSTRAINT CK_InstantiationOccurrenceBinding_CompatibilityFailsClosed CHECK
                (BindingCompatibilityContractVersionId IS NULL)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.EditSession', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.EditSession
        (
            EditSessionId BIGINT IDENTITY(1, 1) NOT NULL,
            InstantiationId BIGINT NOT NULL,
            ActorAuthorityReference VARCHAR(256) NOT NULL,
            BaseInstantiationVersionId BIGINT NULL,
            ConcurrencyToken BINARY(32) NOT NULL,
            StateCode VARCHAR(16) NOT NULL,
            ProposedRevisionSequence INT NULL,
            StartedAtUtc DATETIME2(7) NOT NULL,
            LastHeartbeatAtUtc DATETIME2(7) NOT NULL,
            ClosedAtUtc DATETIME2(7) NULL,
            CONSTRAINT PK_EditSession PRIMARY KEY (EditSessionId),
            CONSTRAINT UQ_EditSession_ConcurrencyToken UNIQUE (ConcurrencyToken),
            CONSTRAINT UQ_EditSession_EditSessionId_InstantiationId UNIQUE
                (EditSessionId, InstantiationId),
            CONSTRAINT CK_EditSession_ClosedState CHECK
            (
                StateCode IN ('active', 'closed', 'abandoned', 'published')
                AND ((StateCode = 'active' AND ClosedAtUtc IS NULL)
                     OR (StateCode <> 'active' AND ClosedAtUtc IS NOT NULL))
                AND (StateCode <> 'published' OR ProposedRevisionSequence IS NOT NULL)
            ),
            CONSTRAINT CK_EditSession_TimeOrder CHECK
                (LastHeartbeatAtUtc >= StartedAtUtc
                 AND (ClosedAtUtc IS NULL OR ClosedAtUtc >= LastHeartbeatAtUtc)),
            CONSTRAINT CK_EditSession_ProposedRevision CHECK
                (ProposedRevisionSequence IS NULL OR ProposedRevisionSequence > 0),
            CONSTRAINT CK_EditSession_BaseRevisionShape CHECK
            (
                ProposedRevisionSequence IS NULL
                OR (ProposedRevisionSequence = 1 AND BaseInstantiationVersionId IS NULL)
                OR (ProposedRevisionSequence > 1 AND BaseInstantiationVersionId IS NOT NULL)
            ),
            CONSTRAINT CK_EditSession_AuthorityReference CHECK
                (LEN(ActorAuthorityReference) BETWEEN 3 AND 256
                 AND ActorAuthorityReference LIKE 'authority:%'
                 AND ActorAuthorityReference NOT LIKE '%[ ;=]%'),
            CONSTRAINT FK_EditSession_Instantiation_Owner FOREIGN KEY (InstantiationId)
                REFERENCES ATAPUtilities.Instantiation (InstantiationId),
            CONSTRAINT FK_EditSession_InstantiationVersion_BaseSameInstantiation FOREIGN KEY
                (BaseInstantiationVersionId, InstantiationId)
                REFERENCES ATAPUtilities.InstantiationVersion (InstantiationVersionId, InstantiationId)
        );

        CREATE UNIQUE INDEX UQ_EditSession_InstantiationId_ProposedRevisionSequence_Published
            ON ATAPUtilities.EditSession (InstantiationId, ProposedRevisionSequence)
            WHERE StateCode = 'published';
    END;

    IF OBJECT_ID(N'ATAPUtilities.InputBlock', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.InputBlock
        (
            InputBlockId BIGINT IDENTITY(1, 1) NOT NULL,
            InputBlockPhiloteId UNIQUEIDENTIFIER NOT NULL,
            EntityId BIGINT NOT NULL,
            EntityTypeId BIGINT NOT NULL,
            EntityTypeCode AS CONVERT(VARCHAR(64), 'input-block') PERSISTED,
            InstantiationOccurrenceBindingId BIGINT NOT NULL,
            InstantiationId BIGINT NOT NULL,
            CreatedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_InputBlock PRIMARY KEY (InputBlockId),
            CONSTRAINT UQ_InputBlock_InputBlockPhiloteId UNIQUE (InputBlockPhiloteId),
            CONSTRAINT UQ_InputBlock_InstantiationOccurrenceBindingId UNIQUE
                (InstantiationOccurrenceBindingId),
            CONSTRAINT UQ_InputBlock_InputBlockId_InstantiationOccurrenceBindingId_InstantiationId UNIQUE
                (InputBlockId, InstantiationOccurrenceBindingId, InstantiationId),
            CONSTRAINT FK_InputBlock_Entity_Registration FOREIGN KEY
                (EntityId, EntityTypeId, InputBlockPhiloteId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId, EntityPhiloteId),
            CONSTRAINT FK_InputBlock_EntityType_ClosedType FOREIGN KEY
                (EntityTypeId, EntityTypeCode)
                REFERENCES ATAPUtilities.EntityType (EntityTypeId, EntityTypeCode),
            CONSTRAINT FK_InputBlock_InstantiationOccurrenceBinding_ExactOwner FOREIGN KEY
                (InstantiationOccurrenceBindingId, InstantiationId)
                REFERENCES ATAPUtilities.InstantiationOccurrenceBinding
                (InstantiationOccurrenceBindingId, InstantiationId)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.InputBlockVersion', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.InputBlockVersion
        (
            InputBlockVersionId BIGINT IDENTITY(1, 1) NOT NULL,
            InputBlockVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            EntityId BIGINT NOT NULL,
            EntityTypeId BIGINT NOT NULL,
            EntityTypeCode AS CONVERT(VARCHAR(64), 'input-block-version') PERSISTED,
            InputBlockId BIGINT NOT NULL,
            InstantiationOccurrenceBindingId BIGINT NOT NULL,
            InstantiationId BIGINT NOT NULL,
            RuleVersionId BIGINT NOT NULL,
            RevisionSequence INT NOT NULL,
            PredecessorInputBlockVersionId BIGINT NULL,
            SourceEditSessionId BIGINT NOT NULL,
            ContentHashAlgorithmCode VARCHAR(16) NOT NULL,
            ContentHash VARBINARY(64) NOT NULL,
            PublishedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_InputBlockVersion PRIMARY KEY (InputBlockVersionId),
            CONSTRAINT UQ_InputBlockVersion_InputBlockVersionPhiloteId UNIQUE
                (InputBlockVersionPhiloteId),
            CONSTRAINT UQ_InputBlockVersion_InputBlockId_RevisionSequence UNIQUE
                (InputBlockId, RevisionSequence),
            CONSTRAINT UQ_InputBlockVersion_InputBlockVersionId_InputBlockId UNIQUE
                (InputBlockVersionId, InputBlockId),
            CONSTRAINT UQ_InputBlockVersion_InputBlockVersionId_InstantiationOccurrenceBindingId_RuleVersionId UNIQUE
                (InputBlockVersionId, InstantiationOccurrenceBindingId, RuleVersionId),
            CONSTRAINT CK_InputBlockVersion_RevisionSequencePositive CHECK (RevisionSequence > 0),
            CONSTRAINT CK_InputBlockVersion_HashSha256 CHECK
                (ContentHashAlgorithmCode = 'sha256' AND DATALENGTH(ContentHash) = 32),
            CONSTRAINT FK_InputBlockVersion_Entity_Registration FOREIGN KEY
                (EntityId, EntityTypeId, InputBlockVersionPhiloteId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId, EntityPhiloteId),
            CONSTRAINT FK_InputBlockVersion_EntityType_ClosedType FOREIGN KEY
                (EntityTypeId, EntityTypeCode)
                REFERENCES ATAPUtilities.EntityType (EntityTypeId, EntityTypeCode),
            CONSTRAINT FK_InputBlockVersion_InputBlock_ExactOwner FOREIGN KEY
                (InputBlockId, InstantiationOccurrenceBindingId, InstantiationId)
                REFERENCES ATAPUtilities.InputBlock
                (InputBlockId, InstantiationOccurrenceBindingId, InstantiationId),
            CONSTRAINT FK_InputBlockVersion_InstantiationOccurrenceBinding_ExactRule FOREIGN KEY
                (InstantiationOccurrenceBindingId, InstantiationId, RuleVersionId)
                REFERENCES ATAPUtilities.InstantiationOccurrenceBinding
                (InstantiationOccurrenceBindingId, InstantiationId, RuleVersionId),
            CONSTRAINT FK_InputBlockVersion_InputBlockVersion_PredecessorSameBlock FOREIGN KEY
                (PredecessorInputBlockVersionId, InputBlockId)
                REFERENCES ATAPUtilities.InputBlockVersion (InputBlockVersionId, InputBlockId),
            CONSTRAINT FK_InputBlockVersion_EditSession_SourceSameInstantiation FOREIGN KEY
                (SourceEditSessionId, InstantiationId)
                REFERENCES ATAPUtilities.EditSession (EditSessionId, InstantiationId)
        );

        CREATE UNIQUE INDEX UQ_InputBlockVersion_PredecessorInputBlockVersionId
            ON ATAPUtilities.InputBlockVersion (PredecessorInputBlockVersionId)
            WHERE PredecessorInputBlockVersionId IS NOT NULL;
    END;

    IF OBJECT_ID(N'ATAPUtilities.InputValue', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.InputValue
        (
            InputValueId BIGINT IDENTITY(1, 1) NOT NULL,
            InputBlockVersionId BIGINT NOT NULL,
            InstantiationOccurrenceBindingId BIGINT NOT NULL,
            RuleVersionId BIGINT NOT NULL,
            RuleInputDefinitionId BIGINT NOT NULL,
            ValueTypeVersionId BIGINT NOT NULL,
            ValueCategoryCode VARCHAR(32) NOT NULL,
            ScalarStorageKindCode VARCHAR(64) NULL,
            ValueCardinality INT NOT NULL,
            ContainsNullElement BIT NOT NULL,
            CanonicalTextValue NVARCHAR(4000) NULL,
            CanonicalIntegerValue BIGINT NULL,
            CanonicalDecimalValue DECIMAL(38, 18) NULL,
            CanonicalBooleanValue BIT NULL,
            CanonicalUtcValue DATETIME2(7) NULL,
            CanonicalIdentifierValue UNIQUEIDENTIFIER NULL,
            CanonicalBinaryValue VARBINARY(MAX) NULL,
            StructuredPayload NVARCHAR(MAX) NULL,
            SecretName NVARCHAR(256) NULL,
            ReferencedEntityId BIGINT NULL,
            ReferencedEntityTypeId BIGINT NULL,
            CanonicalValueHash BINARY(32) NOT NULL,
            CONSTRAINT PK_InputValue PRIMARY KEY (InputValueId),
            CONSTRAINT UQ_InputValue_InputBlockVersionId_RuleInputDefinitionId UNIQUE
                (InputBlockVersionId, RuleInputDefinitionId),
            CONSTRAINT FK_InputValue_InputBlockVersion_ExactBindingRule FOREIGN KEY
                (InputBlockVersionId, InstantiationOccurrenceBindingId, RuleVersionId)
                REFERENCES ATAPUtilities.InputBlockVersion
                (InputBlockVersionId, InstantiationOccurrenceBindingId, RuleVersionId),
            CONSTRAINT FK_InputValue_RuleInputDefinition_ExactRuleType FOREIGN KEY
                (RuleInputDefinitionId, RuleVersionId, ValueTypeVersionId)
                REFERENCES ATAPUtilities.RuleInputDefinition
                (RuleInputDefinitionId, RuleVersionId, ValueTypeVersionId),
            CONSTRAINT FK_InputValue_ValueTypeVersion_ExactCategory FOREIGN KEY
                (ValueTypeVersionId, ValueCategoryCode)
                REFERENCES ATAPUtilities.ValueTypeVersion
                (ValueTypeVersionId, ValueCategoryCode),
            CONSTRAINT FK_InputValue_ScalarStorageKind_ExactScalarShape FOREIGN KEY
                (ScalarStorageKindCode)
                REFERENCES ATAPUtilities.ScalarStorageKind (ScalarStorageKindCode),
            CONSTRAINT FK_InputValue_Entity_EntityReferenceValue FOREIGN KEY
                (ReferencedEntityId, ReferencedEntityTypeId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId),
            CONSTRAINT CK_InputValue_ValueCardinalityNonNegative CHECK (ValueCardinality >= 0),
            CONSTRAINT CK_InputValue_ExactlyOneTypedCategoryShape CHECK
            (
                (ValueCategoryCode = 'scalar' AND ScalarStorageKindCode IS NOT NULL
                 AND CONVERT(TINYINT, CASE WHEN CanonicalTextValue IS NULL THEN 0 ELSE 1 END)
                   + CONVERT(TINYINT, CASE WHEN CanonicalIntegerValue IS NULL THEN 0 ELSE 1 END)
                   + CONVERT(TINYINT, CASE WHEN CanonicalDecimalValue IS NULL THEN 0 ELSE 1 END)
                   + CONVERT(TINYINT, CASE WHEN CanonicalBooleanValue IS NULL THEN 0 ELSE 1 END)
                   + CONVERT(TINYINT, CASE WHEN CanonicalUtcValue IS NULL THEN 0 ELSE 1 END)
                   + CONVERT(TINYINT, CASE WHEN CanonicalIdentifierValue IS NULL THEN 0 ELSE 1 END)
                   + CONVERT(TINYINT, CASE WHEN CanonicalBinaryValue IS NULL THEN 0 ELSE 1 END) = 1
                 AND StructuredPayload IS NULL AND SecretName IS NULL
                 AND ReferencedEntityId IS NULL AND ReferencedEntityTypeId IS NULL)
                OR
                (ValueCategoryCode IN ('structured', 'collection')
                 AND ScalarStorageKindCode IS NULL AND StructuredPayload IS NOT NULL
                 AND CanonicalTextValue IS NULL AND CanonicalIntegerValue IS NULL
                 AND CanonicalDecimalValue IS NULL AND CanonicalBooleanValue IS NULL
                 AND CanonicalUtcValue IS NULL AND CanonicalIdentifierValue IS NULL
                 AND CanonicalBinaryValue IS NULL AND SecretName IS NULL
                 AND ReferencedEntityId IS NULL AND ReferencedEntityTypeId IS NULL)
                OR
                (ValueCategoryCode = 'secret-reference'
                 AND ScalarStorageKindCode IS NULL AND SecretName IS NOT NULL
                 AND CanonicalTextValue IS NULL AND CanonicalIntegerValue IS NULL
                 AND CanonicalDecimalValue IS NULL AND CanonicalBooleanValue IS NULL
                 AND CanonicalUtcValue IS NULL AND CanonicalIdentifierValue IS NULL
                 AND CanonicalBinaryValue IS NULL AND StructuredPayload IS NULL
                 AND ReferencedEntityId IS NULL AND ReferencedEntityTypeId IS NULL)
                OR
                (ValueCategoryCode = 'entity-reference'
                 AND ScalarStorageKindCode IS NULL
                 AND ReferencedEntityId IS NOT NULL AND ReferencedEntityTypeId IS NOT NULL
                 AND CanonicalTextValue IS NULL AND CanonicalIntegerValue IS NULL
                 AND CanonicalDecimalValue IS NULL AND CanonicalBooleanValue IS NULL
                 AND CanonicalUtcValue IS NULL AND CanonicalIdentifierValue IS NULL
                 AND CanonicalBinaryValue IS NULL AND StructuredPayload IS NULL
                 AND SecretName IS NULL)
            ),
            CONSTRAINT CK_InputValue_StructuredPayloadJson CHECK
                (StructuredPayload IS NULL OR ISJSON(StructuredPayload) = 1),
            CONSTRAINT CK_InputValue_SecretNameOpaque CHECK
                (SecretName IS NULL OR
                 (LEN(SecretName) BETWEEN 3 AND 256 AND SecretName NOT LIKE '%[;= ]%'))
        );

        CREATE INDEX IX_InputValue_RuleInputDefinitionId_ValueTypeVersionId
            ON ATAPUtilities.InputValue (RuleInputDefinitionId, ValueTypeVersionId);
    END;

    IF OBJECT_ID(N'ATAPUtilities.InstantiationVersionInputBlock', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.InstantiationVersionInputBlock
        (
            InstantiationVersionId BIGINT NOT NULL,
            InstantiationId BIGINT NOT NULL,
            BuildSetVersionId BIGINT NOT NULL,
            InstantiationOccurrenceBindingId BIGINT NOT NULL,
            OccurrenceKey BINARY(32) NOT NULL,
            RuleVersionId BIGINT NOT NULL,
            InputBlockVersionId BIGINT NOT NULL,
            SelectionContentHash BINARY(32) NOT NULL,
            CONSTRAINT PK_InstantiationVersionInputBlock PRIMARY KEY
                (InstantiationVersionId, InstantiationOccurrenceBindingId),
            CONSTRAINT UQ_InstantiationVersionInputBlock_InstantiationVersionId_InputBlockVersionId UNIQUE
                (InstantiationVersionId, InputBlockVersionId),
            CONSTRAINT FK_InstantiationVersionInputBlock_InstantiationVersion_ExactBuildSet FOREIGN KEY
                (InstantiationVersionId, InstantiationId, BuildSetVersionId)
                REFERENCES ATAPUtilities.InstantiationVersion
                (InstantiationVersionId, InstantiationId, BuildSetVersionId),
            CONSTRAINT FK_InstantiationVersionInputBlock_InstantiationOccurrenceBinding_ExactOccurrence FOREIGN KEY
                (InstantiationOccurrenceBindingId, InstantiationId, BuildSetVersionId, OccurrenceKey, RuleVersionId)
                REFERENCES ATAPUtilities.InstantiationOccurrenceBinding
                (InstantiationOccurrenceBindingId, InstantiationId, BuildSetVersionId, OccurrenceKey, RuleVersionId),
            CONSTRAINT FK_InstantiationVersionInputBlock_InputBlockVersion_ExactBindingRule FOREIGN KEY
                (InputBlockVersionId, InstantiationOccurrenceBindingId, RuleVersionId)
                REFERENCES ATAPUtilities.InputBlockVersion
                (InputBlockVersionId, InstantiationOccurrenceBindingId, RuleVersionId)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.BindingResolution', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.BindingResolution
        (
            BindingResolutionId BIGINT IDENTITY(1, 1) NOT NULL,
            SuccessorBindingId BIGINT NOT NULL,
            PredecessorBindingId BIGINT NULL,
            ResolutionVerbCode VARCHAR(32) NOT NULL,
            SelectedRuleDefaultInputValueId BIGINT NULL,
            MappingEvidenceEntityId BIGINT NULL,
            MappingEvidenceEntityTypeId BIGINT NULL,
            DecisionAuthorityReference VARCHAR(256) NOT NULL,
            ResolutionContentHash BINARY(32) NOT NULL,
            DecidedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_BindingResolution PRIMARY KEY (BindingResolutionId),
            CONSTRAINT UQ_BindingResolution_SuccessorBindingId_PredecessorBindingId UNIQUE
                (SuccessorBindingId, PredecessorBindingId),
            CONSTRAINT FK_BindingResolution_InstantiationOccurrenceBinding_Successor FOREIGN KEY
                (SuccessorBindingId)
                REFERENCES ATAPUtilities.InstantiationOccurrenceBinding
                (InstantiationOccurrenceBindingId),
            CONSTRAINT FK_BindingResolution_InstantiationOccurrenceBinding_Predecessor FOREIGN KEY
                (PredecessorBindingId)
                REFERENCES ATAPUtilities.InstantiationOccurrenceBinding
                (InstantiationOccurrenceBindingId),
            CONSTRAINT FK_BindingResolution_RuleDefaultInputValue_SelectedDefault FOREIGN KEY
                (SelectedRuleDefaultInputValueId)
                REFERENCES ATAPUtilities.RuleDefaultInputValue (RuleDefaultInputValueId),
            CONSTRAINT FK_BindingResolution_Entity_MappingEvidence FOREIGN KEY
                (MappingEvidenceEntityId, MappingEvidenceEntityTypeId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId),
            CONSTRAINT CK_BindingResolution_ClosedVerbAndShape CHECK
            (
                (ResolutionVerbCode = 'carry-forward'
                 AND PredecessorBindingId IS NOT NULL
                 AND SelectedRuleDefaultInputValueId IS NULL
                 AND MappingEvidenceEntityId IS NULL AND MappingEvidenceEntityTypeId IS NULL)
                OR
                (ResolutionVerbCode = 'map'
                 AND PredecessorBindingId IS NOT NULL
                 AND SelectedRuleDefaultInputValueId IS NULL
                 AND MappingEvidenceEntityId IS NOT NULL AND MappingEvidenceEntityTypeId IS NOT NULL)
                OR
                (ResolutionVerbCode = 'default'
                 AND SelectedRuleDefaultInputValueId IS NOT NULL
                 AND MappingEvidenceEntityId IS NULL AND MappingEvidenceEntityTypeId IS NULL)
                OR
                (ResolutionVerbCode = 'remove'
                 AND SelectedRuleDefaultInputValueId IS NULL
                 AND MappingEvidenceEntityId IS NULL AND MappingEvidenceEntityTypeId IS NULL)
            ),
            CONSTRAINT CK_BindingResolution_DecisionAuthorityReference CHECK
                (LEN(DecisionAuthorityReference) BETWEEN 3 AND 256
                 AND DecisionAuthorityReference LIKE 'authority:%'
                 AND DecisionAuthorityReference NOT LIKE '%[ ;=]%')
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.InstantiationPermissionGrant', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.InstantiationPermissionGrant
        (
            InstantiationPermissionGrantId BIGINT IDENTITY(1, 1) NOT NULL,
            InstantiationId BIGINT NOT NULL,
            AuthorityReference VARCHAR(256) NOT NULL,
            TenantScopeReference VARCHAR(256) NOT NULL,
            PermissionVerbCode VARCHAR(32) NOT NULL,
            EffectCode VARCHAR(16) NOT NULL,
            PrecedenceRank SMALLINT NOT NULL,
            ScopeReference VARCHAR(256) NOT NULL,
            EffectiveFromUtc DATETIME2(7) NOT NULL,
            EffectiveToUtc DATETIME2(7) NULL,
            DecisionAuditReference VARCHAR(256) NOT NULL,
            EvaluationContractVersion VARCHAR(64) NOT NULL,
            DecisionContentHash BINARY(32) NOT NULL,
            CONSTRAINT PK_InstantiationPermissionGrant PRIMARY KEY
                (InstantiationPermissionGrantId),
            CONSTRAINT UQ_InstantiationPermissionGrant_DecisionAuditReference UNIQUE
                (DecisionAuditReference),
            CONSTRAINT FK_InstantiationPermissionGrant_Instantiation_Securable FOREIGN KEY
                (InstantiationId) REFERENCES ATAPUtilities.Instantiation (InstantiationId),
            CONSTRAINT FK_InstantiationPermissionGrant_PermissionVerb_ExactVerb FOREIGN KEY
                (PermissionVerbCode) REFERENCES ATAPUtilities.PermissionVerb (PermissionVerbCode),
            CONSTRAINT CK_InstantiationPermissionGrant_ClosedEffect CHECK
                (EffectCode IN ('allow', 'deny', 'revoke')),
            CONSTRAINT CK_InstantiationPermissionGrant_Precedence CHECK
                (PrecedenceRank BETWEEN 0 AND 1000),
            CONSTRAINT CK_InstantiationPermissionGrant_EffectiveInterval CHECK
                (EffectiveToUtc IS NULL OR EffectiveToUtc > EffectiveFromUtc),
            CONSTRAINT CK_InstantiationPermissionGrant_OpaqueReferences CHECK
            (
                LEN(AuthorityReference) BETWEEN 3 AND 256
                AND LEN(TenantScopeReference) BETWEEN 3 AND 256
                AND LEN(ScopeReference) BETWEEN 3 AND 256
                AND LEN(DecisionAuditReference) BETWEEN 3 AND 256
                AND LEN(EvaluationContractVersion) BETWEEN 1 AND 64
                AND AuthorityReference LIKE 'authority:%'
                AND TenantScopeReference LIKE 'tenant:%'
                AND ScopeReference LIKE 'instantiation:%'
                AND DecisionAuditReference LIKE 'audit:%'
                AND AuthorityReference NOT LIKE '%[;=]%'
                AND TenantScopeReference NOT LIKE '%[;=]%'
                AND ScopeReference NOT LIKE '%[;=]%'
            )
        );

        CREATE INDEX IX_InstantiationPermissionGrant_InstantiationId_PermissionVerbCode_EffectiveFromUtc
            ON ATAPUtilities.InstantiationPermissionGrant
            (InstantiationId, PermissionVerbCode, EffectiveFromUtc);
    END;

    /* Literal trigger batches remain independently parseable by the RDB-480 gate. */
    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_PermissionVerb_UpdateDeleteImmutable
ON ATAPUtilities.PermissionVerb INSTEAD OF UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 54440, ''Published RDB-440 rows are immutable.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_Instantiation_UpdateDeleteImmutable
ON ATAPUtilities.Instantiation INSTEAD OF UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 54440, ''Published RDB-440 rows are immutable.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_InstantiationOccurrenceBinding_UpdateDeleteImmutable
ON ATAPUtilities.InstantiationOccurrenceBinding INSTEAD OF UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 54440, ''Published RDB-440 rows are immutable.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_InputBlock_UpdateDeleteImmutable
ON ATAPUtilities.InputBlock INSTEAD OF UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 54440, ''Published RDB-440 rows are immutable.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_InstantiationVersionInputBlock_UpdateDeleteImmutable
ON ATAPUtilities.InstantiationVersionInputBlock INSTEAD OF UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 54440, ''Published RDB-440 rows are immutable.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_BindingResolution_UpdateDeleteImmutable
ON ATAPUtilities.BindingResolution INSTEAD OF UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 54440, ''Published RDB-440 rows are immutable.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_InstantiationPermissionGrant_UpdateDeleteImmutable
ON ATAPUtilities.InstantiationPermissionGrant INSTEAD OF UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    THROW 54440, ''Published RDB-440 rows are immutable.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_BuildSetRuleOccurrence_DerivationImmutable
ON ATAPUtilities.BuildSetRuleOccurrence
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 54439, ''BuildSetRuleOccurrence rows are immutable.'', 1;
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        WHERE i.OccurrenceKey <> CONVERT(BINARY(32), HASHBYTES(''SHA2_256'',
            CONCAT(CONVERT(VARCHAR(20), i.BuildSetVersionMemberId), '':'',
                   CONVERT(VARCHAR(20), i.RuleSetVersionMemberId), '':'',
                   CONVERT(VARCHAR(20), i.RuleVersionId))))
    ) THROW 54438, ''OccurrenceKey does not match its immutable member path.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_InstantiationVersion_LineageImmutable
ON ATAPUtilities.InstantiationVersion
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 54441, ''InstantiationVersion rows are immutable.'', 1;
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        LEFT JOIN ATAPUtilities.InstantiationVersion AS p
          ON p.InstantiationVersionId = i.PredecessorInstantiationVersionId
        WHERE (i.RevisionSequence = 1 AND i.PredecessorInstantiationVersionId IS NOT NULL)
           OR (i.RevisionSequence > 1 AND
               (p.InstantiationVersionId IS NULL OR p.RevisionSequence <> i.RevisionSequence - 1))
    ) THROW 54442, ''InstantiationVersion lineage must be contiguous and same-parent.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_InputBlockVersion_LineageImmutable
ON ATAPUtilities.InputBlockVersion
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 54443, ''InputBlockVersion rows are immutable.'', 1;
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        LEFT JOIN ATAPUtilities.InputBlockVersion AS p
          ON p.InputBlockVersionId = i.PredecessorInputBlockVersionId
        WHERE (i.RevisionSequence = 1 AND i.PredecessorInputBlockVersionId IS NOT NULL)
           OR (i.RevisionSequence > 1 AND
               (p.InputBlockVersionId IS NULL OR p.RevisionSequence <> i.RevisionSequence - 1))
    ) THROW 54444, ''InputBlockVersion lineage must be contiguous and same-block.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_InputValue_TypeCardinalityImmutable
ON ATAPUtilities.InputValue
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 54445, ''InputValue rows are immutable.'', 1;
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN ATAPUtilities.RuleInputDefinition AS d
          ON d.RuleInputDefinitionId = i.RuleInputDefinitionId
         AND d.RuleVersionId = i.RuleVersionId
         AND d.ValueTypeVersionId = i.ValueTypeVersionId
        INNER JOIN ATAPUtilities.ValueTypeVersion AS vt
          ON vt.ValueTypeVersionId = i.ValueTypeVersionId
        WHERE i.ValueCardinality < d.MinCardinality
           OR (d.MaxCardinality IS NOT NULL AND i.ValueCardinality > d.MaxCardinality)
           OR (i.ContainsNullElement = 1 AND d.AllowsNullElement = 0)
           OR i.ValueCategoryCode <> vt.ValueCategoryCode
           OR ISNULL(i.ScalarStorageKindCode, '''') <> ISNULL(vt.ScalarStorageKindCode, '''')
    ) THROW 54446, ''InputValue cardinality/nullability is incompatible with its exact Rule input.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_EditSession_StateTransition
ON ATAPUtilities.EditSession
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted)
        THROW 54447, ''EditSession rows cannot be deleted.'', 1;
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        LEFT JOIN deleted AS priorSession ON priorSession.EditSessionId = i.EditSessionId
        LEFT JOIN ATAPUtilities.InstantiationVersion AS b
          ON b.InstantiationVersionId = i.BaseInstantiationVersionId
         AND b.InstantiationId = i.InstantiationId
        WHERE priorSession.EditSessionId IS NULL
          AND i.ProposedRevisionSequence IS NOT NULL
          AND ((i.ProposedRevisionSequence = 1
                AND (i.BaseInstantiationVersionId IS NOT NULL
                     OR EXISTS (SELECT 1 FROM ATAPUtilities.InstantiationVersion AS x
                                WHERE x.InstantiationId = i.InstantiationId)))
               OR (i.ProposedRevisionSequence > 1
                   AND (b.InstantiationVersionId IS NULL
                        OR b.RevisionSequence <> i.ProposedRevisionSequence - 1)))
    ) THROW 54460, ''EditSession base must be NULL only for revision one; successors require the exact prior revision.'', 1;
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN deleted AS d ON d.EditSessionId = i.EditSessionId
        WHERE d.StateCode <> ''active''
           OR i.InstantiationId <> d.InstantiationId
           OR i.ActorAuthorityReference <> d.ActorAuthorityReference
           OR EXISTS (SELECT i.BaseInstantiationVersionId
                      EXCEPT SELECT d.BaseInstantiationVersionId)
           OR EXISTS (SELECT i.ProposedRevisionSequence
                      EXCEPT SELECT d.ProposedRevisionSequence)
           OR i.ConcurrencyToken <> d.ConcurrencyToken
           OR i.StartedAtUtc <> d.StartedAtUtc
    ) THROW 54448, ''Terminal EditSession rows and immutable ownership fields cannot change.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE ATAPUtilities.usp_RollItUpInstantiation
    @InstantiationId BIGINT,
    @ExpectedRevision INT,
    @RequestedPublicationId UNIQUEIDENTIFIER,
    @InstantiationVersionEntityId BIGINT,
    @InstantiationVersionEntityTypeId BIGINT,
    @BuildSetVersionId BIGINT,
    @ActorAuthorityReference VARCHAR(256),
    @ConcurrencyToken BINARY(32),
    @GraphInputHashAlgorithmCode VARCHAR(16),
    @GraphInputContentHash BINARY(32),
    @PublishedAtUtc DATETIME2(7),
    @InputBlockVersionsJson NVARCHAR(MAX),
    @InputValuesJson NVARCHAR(MAX)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @@TRANCOUNT <> 0
        THROW 54461, ''RollItUp must own its transaction.'', 1;
    IF @ExpectedRevision < 0
        THROW 54462, ''ExpectedRevision cannot be negative.'', 1;
    IF @RequestedPublicationId IS NULL OR @PublishedAtUtc IS NULL
        THROW 54463, ''Requested publication identity and UTC time are required.'', 1;
    IF @GraphInputHashAlgorithmCode <> ''sha256'' OR DATALENGTH(@GraphInputContentHash) <> 32
        THROW 54464, ''The publication graph/input hash must be SHA-256.'', 1;
    IF ISJSON(@InputBlockVersionsJson) <> 1 OR ISJSON(@InputValuesJson) <> 1
        THROW 54465, ''Input snapshot and value payloads must be JSON arrays.'', 1;

    DECLARE @PriorIsolationLevel SMALLINT =
        (SELECT transaction_isolation_level FROM sys.dm_exec_sessions WHERE session_id = @@SPID);
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @LockResult INT;
        DECLARE @LockResource NVARCHAR(255) =
            CONCAT(N''RRSBS:Instantiation:'', CONVERT(NVARCHAR(20), @InstantiationId));
        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = ''Exclusive'', @LockOwner = ''Transaction'', @LockTimeout = 15000;
        IF @LockResult < 0
            THROW 54466, ''Unable to acquire the Instantiation publication lock.'', 1;

        IF NOT EXISTS
        (
            SELECT 1 FROM ATAPUtilities.Instantiation WITH (UPDLOCK, HOLDLOCK)
            WHERE InstantiationId = @InstantiationId
        ) THROW 54467, ''Instantiation does not exist.'', 1;

        DECLARE @ProposedRevision INT = @ExpectedRevision + 1;
        DECLARE @BaseInstantiationVersionId BIGINT;
        DECLARE @ActualRevision INT;
        SELECT TOP (1)
            @BaseInstantiationVersionId = v.InstantiationVersionId,
            @ActualRevision = v.RevisionSequence
        FROM ATAPUtilities.InstantiationVersion AS v WITH (UPDLOCK, HOLDLOCK)
        WHERE v.InstantiationId = @InstantiationId
        ORDER BY v.RevisionSequence DESC;

        DECLARE @ExistingPublicationId BIGINT;
        SELECT @ExistingPublicationId = v.InstantiationVersionId
        FROM ATAPUtilities.InstantiationVersion AS v WITH (UPDLOCK, HOLDLOCK)
        WHERE v.InstantiationVersionPhiloteId = @RequestedPublicationId
          AND v.InstantiationId = @InstantiationId
          AND v.BuildSetVersionId = @BuildSetVersionId
          AND v.RevisionSequence = @ProposedRevision
          AND v.GraphInputHashAlgorithmCode = @GraphInputHashAlgorithmCode
          AND v.GraphInputContentHash = @GraphInputContentHash;
        IF @ExistingPublicationId IS NOT NULL
        BEGIN
            COMMIT TRANSACTION;
            IF @PriorIsolationLevel = 1 SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
            ELSE IF @PriorIsolationLevel IN (0, 2) SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
            ELSE IF @PriorIsolationLevel = 3 SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
            ELSE IF @PriorIsolationLevel = 4 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
            ELSE IF @PriorIsolationLevel = 5 SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
            SELECT @ExistingPublicationId AS InstantiationVersionId,
                   @ProposedRevision AS RevisionSequence,
                   CONVERT(BIT, 1) AS WasIdempotentReplay;
            RETURN;
        END;

        IF @ExpectedRevision = 0
        BEGIN
            IF @BaseInstantiationVersionId IS NOT NULL OR @ActualRevision IS NOT NULL
                THROW 54468, ''Revision-one bootstrap requires an Instantiation with no published version.'', 1;
        END;
        ELSE IF @BaseInstantiationVersionId IS NULL OR @ActualRevision <> @ExpectedRevision
            THROW 54469, ''ExpectedRevision is stale; a successor requires the exact current base.'', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM ATAPUtilities.Entity AS e
            WHERE e.EntityId = @InstantiationVersionEntityId
              AND e.EntityTypeId = @InstantiationVersionEntityTypeId
              AND e.EntityPhiloteId = @RequestedPublicationId
        ) THROW 54470, ''Requested publication Entity registration is missing or inexact.'', 1;

        DECLARE @EditSessionId BIGINT;
        INSERT ATAPUtilities.EditSession
            (InstantiationId, ActorAuthorityReference, BaseInstantiationVersionId,
             ConcurrencyToken, StateCode, ProposedRevisionSequence, StartedAtUtc,
             LastHeartbeatAtUtc, ClosedAtUtc)
        VALUES
            (@InstantiationId, @ActorAuthorityReference, @BaseInstantiationVersionId,
             @ConcurrencyToken, ''active'', @ProposedRevision, @PublishedAtUtc,
             @PublishedAtUtc, NULL);
        SET @EditSessionId = CONVERT(BIGINT, SCOPE_IDENTITY());

        DECLARE @SnapshotInput TABLE
        (
            SnapshotKey UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            InputBlockVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            EntityId BIGINT NOT NULL,
            EntityTypeId BIGINT NOT NULL,
            InputBlockId BIGINT NOT NULL,
            InstantiationOccurrenceBindingId BIGINT NOT NULL,
            RuleVersionId BIGINT NOT NULL,
            RevisionSequence INT NOT NULL,
            PredecessorInputBlockVersionId BIGINT NULL,
            ContentHash BINARY(32) NOT NULL
        );
        INSERT @SnapshotInput
            (SnapshotKey, InputBlockVersionPhiloteId, EntityId, EntityTypeId,
             InputBlockId, InstantiationOccurrenceBindingId, RuleVersionId,
             RevisionSequence, PredecessorInputBlockVersionId, ContentHash)
        SELECT SnapshotKey, InputBlockVersionPhiloteId, EntityId, EntityTypeId,
               InputBlockId, InstantiationOccurrenceBindingId, RuleVersionId,
               RevisionSequence, PredecessorInputBlockVersionId,
               CONVERT(BINARY(32), ContentHashHex, 1)
        FROM OPENJSON(@InputBlockVersionsJson)
        WITH
        (
            SnapshotKey UNIQUEIDENTIFIER ''$.snapshotKey'',
            InputBlockVersionPhiloteId UNIQUEIDENTIFIER ''$.inputBlockVersionPhiloteId'',
            EntityId BIGINT ''$.entityId'',
            EntityTypeId BIGINT ''$.entityTypeId'',
            InputBlockId BIGINT ''$.inputBlockId'',
            InstantiationOccurrenceBindingId BIGINT ''$.instantiationOccurrenceBindingId'',
            RuleVersionId BIGINT ''$.ruleVersionId'',
            RevisionSequence INT ''$.revisionSequence'',
            PredecessorInputBlockVersionId BIGINT ''$.predecessorInputBlockVersionId'',
            ContentHashHex VARCHAR(66) ''$.contentHash''
        );

        IF NOT EXISTS (SELECT 1 FROM @SnapshotInput)
            THROW 54471, ''At least one InputBlockVersion snapshot is required.'', 1;
        IF (SELECT COUNT_BIG(*) FROM @SnapshotInput) <>
           (SELECT COUNT_BIG(*) FROM ATAPUtilities.BuildSetRuleOccurrence
            WHERE BuildSetVersionId = @BuildSetVersionId)
            THROW 54472, ''Snapshot count does not cover the exact BuildSet occurrence set.'', 1;
        IF EXISTS
        (
            SELECT 1
            FROM @SnapshotInput AS s
            LEFT JOIN ATAPUtilities.InstantiationOccurrenceBinding AS b
              ON b.InstantiationOccurrenceBindingId = s.InstantiationOccurrenceBindingId
             AND b.InstantiationId = @InstantiationId
             AND b.BuildSetVersionId = @BuildSetVersionId
             AND b.RuleVersionId = s.RuleVersionId
            LEFT JOIN ATAPUtilities.InputBlock AS ib
              ON ib.InputBlockId = s.InputBlockId
             AND ib.InstantiationOccurrenceBindingId = s.InstantiationOccurrenceBindingId
             AND ib.InstantiationId = @InstantiationId
            OUTER APPLY
            (
                SELECT TOP (1) v.InputBlockVersionId, v.RevisionSequence
                FROM ATAPUtilities.InputBlockVersion AS v WITH (UPDLOCK, HOLDLOCK)
                WHERE v.InputBlockId = s.InputBlockId
                ORDER BY v.RevisionSequence DESC
            ) AS prior
            WHERE b.InstantiationOccurrenceBindingId IS NULL OR ib.InputBlockId IS NULL
               OR (prior.InputBlockVersionId IS NULL
                   AND (s.RevisionSequence <> 1 OR s.PredecessorInputBlockVersionId IS NOT NULL))
               OR (prior.InputBlockVersionId IS NOT NULL
                   AND (s.RevisionSequence <> prior.RevisionSequence + 1
                        OR s.PredecessorInputBlockVersionId <> prior.InputBlockVersionId))
        ) THROW 54473, ''An InputBlockVersion snapshot has a foreign binding or inexact predecessor.'', 1;
        IF EXISTS
        (
            SELECT 1
            FROM ATAPUtilities.BuildSetRuleOccurrence AS o
            LEFT JOIN ATAPUtilities.InstantiationOccurrenceBinding AS b
              ON b.InstantiationId = @InstantiationId
             AND b.BuildSetRuleOccurrenceId = o.BuildSetRuleOccurrenceId
             AND b.BuildSetVersionId = o.BuildSetVersionId
             AND b.OccurrenceKey = o.OccurrenceKey
             AND b.RuleVersionId = o.RuleVersionId
            LEFT JOIN @SnapshotInput AS s
              ON s.InstantiationOccurrenceBindingId = b.InstantiationOccurrenceBindingId
             AND s.RuleVersionId = b.RuleVersionId
            WHERE o.BuildSetVersionId = @BuildSetVersionId
              AND (b.InstantiationOccurrenceBindingId IS NULL OR s.SnapshotKey IS NULL)
        ) THROW 54474, ''Every exact BuildSet occurrence requires one compatible binding and snapshot.'', 1;

        IF @BaseInstantiationVersionId IS NOT NULL
           AND EXISTS
           (
               SELECT 1
               FROM @SnapshotInput AS s
               INNER JOIN ATAPUtilities.InstantiationOccurrenceBinding AS successor
                 ON successor.InstantiationOccurrenceBindingId = s.InstantiationOccurrenceBindingId
               WHERE NOT EXISTS
               (
                   SELECT 1
                   FROM ATAPUtilities.InstantiationVersionInputBlock AS oldSelection
                   INNER JOIN ATAPUtilities.InstantiationOccurrenceBinding AS predecessor
                     ON predecessor.InstantiationOccurrenceBindingId = oldSelection.InstantiationOccurrenceBindingId
                   WHERE oldSelection.InstantiationVersionId = @BaseInstantiationVersionId
                     AND predecessor.OccurrenceKey = successor.OccurrenceKey
                     AND predecessor.RuleVersionId = successor.RuleVersionId
               )
                 AND NOT EXISTS
                 (
                     SELECT 1 FROM ATAPUtilities.BindingResolution AS resolution
                     WHERE resolution.SuccessorBindingId = successor.InstantiationOccurrenceBindingId
                 )
           ) THROW 54475, ''Added or incompatible successor occurrences require BindingResolution evidence.'', 1;
        IF @BaseInstantiationVersionId IS NOT NULL
           AND EXISTS
           (
               SELECT 1
               FROM ATAPUtilities.InstantiationVersionInputBlock AS oldSelection
               WHERE oldSelection.InstantiationVersionId = @BaseInstantiationVersionId
                 AND NOT EXISTS
                 (
                     SELECT 1
                     FROM @SnapshotInput AS s
                     INNER JOIN ATAPUtilities.InstantiationOccurrenceBinding AS successor
                       ON successor.InstantiationOccurrenceBindingId = s.InstantiationOccurrenceBindingId
                     INNER JOIN ATAPUtilities.InstantiationOccurrenceBinding AS predecessor
                       ON predecessor.InstantiationOccurrenceBindingId = oldSelection.InstantiationOccurrenceBindingId
                     WHERE successor.OccurrenceKey = predecessor.OccurrenceKey
                       AND successor.RuleVersionId = predecessor.RuleVersionId
                 )
                 AND NOT EXISTS
                 (
                     SELECT 1 FROM ATAPUtilities.BindingResolution AS resolution
                     WHERE resolution.PredecessorBindingId = oldSelection.InstantiationOccurrenceBindingId
                       AND resolution.ResolutionVerbCode = ''remove''
                 )
           ) THROW 54476, ''Removed predecessor occurrences require explicit remove resolution evidence.'', 1;

        DECLARE @InsertedSnapshots TABLE
        (
            SnapshotKey UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            InputBlockVersionId BIGINT NOT NULL,
            InstantiationOccurrenceBindingId BIGINT NOT NULL,
            RuleVersionId BIGINT NOT NULL,
            ContentHash BINARY(32) NOT NULL
        );
        INSERT ATAPUtilities.InputBlockVersion
            (InputBlockVersionPhiloteId, EntityId, EntityTypeId, InputBlockId,
             InstantiationOccurrenceBindingId, InstantiationId, RuleVersionId,
             RevisionSequence, PredecessorInputBlockVersionId, SourceEditSessionId,
             ContentHashAlgorithmCode, ContentHash, PublishedAtUtc)
        SELECT s.InputBlockVersionPhiloteId, s.EntityId, s.EntityTypeId, s.InputBlockId,
               s.InstantiationOccurrenceBindingId, @InstantiationId, s.RuleVersionId,
               s.RevisionSequence, s.PredecessorInputBlockVersionId, @EditSessionId,
               ''sha256'', s.ContentHash, @PublishedAtUtc
        FROM @SnapshotInput AS s;

        INSERT @InsertedSnapshots
            (SnapshotKey, InputBlockVersionId, InstantiationOccurrenceBindingId,
             RuleVersionId, ContentHash)
        SELECT s.SnapshotKey, v.InputBlockVersionId,
               v.InstantiationOccurrenceBindingId, v.RuleVersionId, v.ContentHash
        FROM @SnapshotInput AS s
        INNER JOIN ATAPUtilities.InputBlockVersion AS v
          ON v.InputBlockVersionPhiloteId = s.InputBlockVersionPhiloteId
         AND v.SourceEditSessionId = @EditSessionId;
        IF (SELECT COUNT_BIG(*) FROM @InsertedSnapshots) <> (SELECT COUNT_BIG(*) FROM @SnapshotInput)
            THROW 54481, ''Inserted snapshot identity mapping is incomplete.'', 1;

        INSERT ATAPUtilities.InputValue
            (InputBlockVersionId, InstantiationOccurrenceBindingId, RuleVersionId,
             RuleInputDefinitionId, ValueTypeVersionId, ValueCategoryCode,
             ScalarStorageKindCode, ValueCardinality, ContainsNullElement,
             CanonicalTextValue, CanonicalIntegerValue, CanonicalDecimalValue,
             CanonicalBooleanValue, CanonicalUtcValue, CanonicalIdentifierValue,
             CanonicalBinaryValue, StructuredPayload, SecretName,
             ReferencedEntityId, ReferencedEntityTypeId, CanonicalValueHash)
        SELECT snapshots.InputBlockVersionId,
               snapshots.InstantiationOccurrenceBindingId, snapshots.RuleVersionId,
               valueset.RuleInputDefinitionId, valueset.ValueTypeVersionId,
               valueset.ValueCategoryCode, valueset.ScalarStorageKindCode,
               valueset.ValueCardinality, valueset.ContainsNullElement,
               valueset.CanonicalTextValue, valueset.CanonicalIntegerValue,
               valueset.CanonicalDecimalValue, valueset.CanonicalBooleanValue,
               valueset.CanonicalUtcValue, valueset.CanonicalIdentifierValue,
               CONVERT(VARBINARY(MAX), valueset.CanonicalBinaryHex, 1),
               valueset.StructuredPayload, valueset.SecretName,
               valueset.ReferencedEntityId, valueset.ReferencedEntityTypeId,
               CONVERT(BINARY(32), valueset.CanonicalValueHashHex, 1)
        FROM OPENJSON(@InputValuesJson)
        WITH
        (
            SnapshotKey UNIQUEIDENTIFIER ''$.snapshotKey'',
            RuleInputDefinitionId BIGINT ''$.ruleInputDefinitionId'',
            ValueTypeVersionId BIGINT ''$.valueTypeVersionId'',
            ValueCategoryCode VARCHAR(32) ''$.valueCategoryCode'',
            ScalarStorageKindCode VARCHAR(64) ''$.scalarStorageKindCode'',
            ValueCardinality INT ''$.valueCardinality'',
            ContainsNullElement BIT ''$.containsNullElement'',
            CanonicalTextValue NVARCHAR(4000) ''$.canonicalTextValue'',
            CanonicalIntegerValue BIGINT ''$.canonicalIntegerValue'',
            CanonicalDecimalValue DECIMAL(38,18) ''$.canonicalDecimalValue'',
            CanonicalBooleanValue BIT ''$.canonicalBooleanValue'',
            CanonicalUtcValue DATETIME2(7) ''$.canonicalUtcValue'',
            CanonicalIdentifierValue UNIQUEIDENTIFIER ''$.canonicalIdentifierValue'',
            CanonicalBinaryHex VARCHAR(MAX) ''$.canonicalBinaryValue'',
            StructuredPayload NVARCHAR(MAX) ''$.structuredPayload'' AS JSON,
            SecretName NVARCHAR(256) ''$.secretName'',
            ReferencedEntityId BIGINT ''$.referencedEntityId'',
            ReferencedEntityTypeId BIGINT ''$.referencedEntityTypeId'',
            CanonicalValueHashHex VARCHAR(66) ''$.canonicalValueHash''
        ) AS valueset
        INNER JOIN @InsertedSnapshots AS snapshots
          ON snapshots.SnapshotKey = valueset.SnapshotKey;

        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@InputValuesJson)) <>
           (SELECT COUNT_BIG(*) FROM ATAPUtilities.InputValue AS valueRow
            INNER JOIN @InsertedSnapshots AS snapshots
              ON snapshots.InputBlockVersionId = valueRow.InputBlockVersionId)
            THROW 54477, ''Every supplied value must resolve to one inserted snapshot.'', 1;
        IF EXISTS
        (
            SELECT 1
            FROM @InsertedSnapshots AS snapshots
            INNER JOIN ATAPUtilities.RuleInputDefinition AS definition
              ON definition.RuleVersionId = snapshots.RuleVersionId
             AND definition.MinCardinality > 0
            LEFT JOIN ATAPUtilities.InputValue AS valueRow
              ON valueRow.InputBlockVersionId = snapshots.InputBlockVersionId
             AND valueRow.RuleInputDefinitionId = definition.RuleInputDefinitionId
            WHERE valueRow.InputValueId IS NULL
        ) THROW 54478, ''A required Rule input is absent from a publication snapshot.'', 1;

        INSERT ATAPUtilities.InstantiationVersion
            (InstantiationVersionPhiloteId, EntityId, EntityTypeId, InstantiationId,
             BuildSetVersionId, RevisionSequence, PredecessorInstantiationVersionId,
             GraphInputHashAlgorithmCode, GraphInputContentHash, PublishedAtUtc)
        VALUES
            (@RequestedPublicationId, @InstantiationVersionEntityId,
             @InstantiationVersionEntityTypeId, @InstantiationId,
             @BuildSetVersionId, @ProposedRevision, @BaseInstantiationVersionId,
             @GraphInputHashAlgorithmCode, @GraphInputContentHash, @PublishedAtUtc);
        DECLARE @InstantiationVersionId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());

        INSERT ATAPUtilities.InstantiationVersionInputBlock
            (InstantiationVersionId, InstantiationId, BuildSetVersionId,
             InstantiationOccurrenceBindingId, OccurrenceKey, RuleVersionId,
             InputBlockVersionId, SelectionContentHash)
        SELECT @InstantiationVersionId, @InstantiationId, @BuildSetVersionId,
               binding.InstantiationOccurrenceBindingId, binding.OccurrenceKey,
               binding.RuleVersionId, snapshots.InputBlockVersionId,
               CONVERT(BINARY(32), HASHBYTES(''SHA2_256'',
                   CONCAT(CONVERT(VARCHAR(20), binding.InstantiationOccurrenceBindingId), '':'',
                          CONVERT(VARCHAR(20), snapshots.InputBlockVersionId), '':'',
                          CONVERT(VARCHAR(130), snapshots.ContentHash, 1))))
        FROM @InsertedSnapshots AS snapshots
        INNER JOIN ATAPUtilities.InstantiationOccurrenceBinding AS binding
          ON binding.InstantiationOccurrenceBindingId = snapshots.InstantiationOccurrenceBindingId;

        IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.InstantiationVersionInputBlock
            WHERE InstantiationVersionId = @InstantiationVersionId) <>
           (SELECT COUNT_BIG(*) FROM ATAPUtilities.BuildSetRuleOccurrence
            WHERE BuildSetVersionId = @BuildSetVersionId)
            THROW 54479, ''Published selections are not complete at commit.'', 1;

        UPDATE ATAPUtilities.EditSession
        SET StateCode = ''published'', LastHeartbeatAtUtc = @PublishedAtUtc,
            ClosedAtUtc = @PublishedAtUtc
        WHERE EditSessionId = @EditSessionId AND StateCode = ''active'';
        IF @@ROWCOUNT <> 1
            THROW 54480, ''The publication EditSession did not close exactly once.'', 1;

        COMMIT TRANSACTION;
        IF @PriorIsolationLevel = 1 SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
        ELSE IF @PriorIsolationLevel IN (0, 2) SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
        ELSE IF @PriorIsolationLevel = 3 SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
        ELSE IF @PriorIsolationLevel = 4 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        ELSE IF @PriorIsolationLevel = 5 SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
        SELECT @InstantiationVersionId AS InstantiationVersionId,
               @ProposedRevision AS RevisionSequence,
               CONVERT(BIT, 0) AS WasIdempotentReplay;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF @PriorIsolationLevel = 1 SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
        ELSE IF @PriorIsolationLevel IN (0, 2) SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
        ELSE IF @PriorIsolationLevel = 3 SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
        ELSE IF @PriorIsolationLevel = 4 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        ELSE IF @PriorIsolationLevel = 5 SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
        THROW;
    END CATCH;
END;';

    IF DATABASE_PRINCIPAL_ID(N'RrsbsPublisher') IS NULL
        EXEC sys.sp_executesql N'CREATE ROLE RrsbsPublisher AUTHORIZATION dbo;';

    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.PermissionVerb TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.Instantiation TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.InstantiationVersion TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.BuildSetRuleOccurrence TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.InstantiationOccurrenceBinding TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.EditSession TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.InputBlock TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.InputBlockVersion TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.InputValue TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.InstantiationVersionInputBlock TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.BindingResolution TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.InstantiationPermissionGrant TO RrsbsPublisher;
    GRANT EXECUTE ON OBJECT::ATAPUtilities.usp_RollItUpInstantiation TO RrsbsPublisher;

    IF @Rdb440OwnsTransaction = 1
        COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() = -1
        ROLLBACK TRANSACTION;
    ELSE IF XACT_STATE() = 1 AND @Rdb440OwnsTransaction = 1
        ROLLBACK TRANSACTION;
    ELSE IF XACT_STATE() = 1
        ROLLBACK TRANSACTION Rdb440Fragment;
    THROW;
END CATCH;

/*
  Opt-in, rollback-only legacy row-constraint fixture. RDB-480 supplies
  compatible RDB-430 member-path rows, RDB-420 Rule input rows, and a
  pre-existing base InstantiationVersion. Trusted revision-one and aggregate
  publication behavior is owned by usp_RollItUpInstantiation and remains a
  database-execution obligation; this fixture does not impersonate the role.
*/
IF TRY_CONVERT(BIT, SESSION_CONTEXT(N'RRSBS_RUN_RDB440_FIXTURES')) = 1
BEGIN
    SET XACT_ABORT OFF;
    BEGIN TRANSACTION Rdb440Fixtures;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.PermissionVerb WHERE PermissionVerbCode = 'view')
        BEGIN
            INSERT ATAPUtilities.PermissionVerb (PermissionVerbCode) VALUES
                ('view'), ('edit'), ('publish'), ('fork'),
                ('plan'), ('execute'), ('approve'), ('read-artifacts');
        END;

        /* Positive migration/selection fixture prerequisites are explicit. */
        DECLARE @Rdb440BuildSetVersionMemberId BIGINT;
        DECLARE @Rdb440BuildSetVersionId BIGINT;
        DECLARE @Rdb440RuleSetVersionId BIGINT;
        DECLARE @Rdb440RuleSetVersionMemberId BIGINT;
        DECLARE @Rdb440RuleVersionId BIGINT;
        SELECT TOP (1)
            @Rdb440BuildSetVersionMemberId = bm.BuildSetVersionMemberId,
            @Rdb440BuildSetVersionId = bm.BuildSetVersionId,
            @Rdb440RuleSetVersionId = bm.RuleSetVersionId,
            @Rdb440RuleSetVersionMemberId = rm.RuleSetVersionMemberId,
            @Rdb440RuleVersionId = rm.RuleVersionId
        FROM ATAPUtilities.BuildSetVersionMember AS bm
        INNER JOIN ATAPUtilities.RuleSetVersionMember AS rm
          ON rm.RuleSetVersionId = bm.RuleSetVersionId
        ORDER BY bm.BuildSetVersionMemberId, rm.RuleSetVersionMemberId;
        IF @Rdb440RuleVersionId IS NULL
            THROW 54449, 'RDB-440 fixtures require the RDB-430 member-path fixture.', 1;

        INSERT ATAPUtilities.BuildSetRuleOccurrence
            (BuildSetVersionId, BuildSetVersionMemberId, RuleSetVersionId,
             RuleSetVersionMemberId, RuleVersionId, OccurrenceKey)
        VALUES (@Rdb440BuildSetVersionId, @Rdb440BuildSetVersionMemberId,
                @Rdb440RuleSetVersionId, @Rdb440RuleSetVersionMemberId,
                @Rdb440RuleVersionId,
                CONVERT(BINARY(32), HASHBYTES('SHA2_256',
                    CONCAT(CONVERT(VARCHAR(20), @Rdb440BuildSetVersionMemberId), ':',
                           CONVERT(VARCHAR(20), @Rdb440RuleSetVersionMemberId), ':',
                           CONVERT(VARCHAR(20), @Rdb440RuleVersionId)))));

        /* Invalid I-09 fixture: substitute a RuleSet member from another path. */
        BEGIN TRY
            INSERT ATAPUtilities.BuildSetRuleOccurrence
                (BuildSetVersionId, BuildSetVersionMemberId, RuleSetVersionId,
                 RuleSetVersionMemberId, RuleVersionId, OccurrenceKey)
            VALUES (@Rdb440BuildSetVersionId, @Rdb440BuildSetVersionMemberId,
                    @Rdb440RuleSetVersionId, -1, @Rdb440RuleVersionId,
                    CONVERT(BINARY(32), HASHBYTES('SHA2_256',
                        CONCAT(CONVERT(VARCHAR(20), @Rdb440BuildSetVersionMemberId), ':',
                               CONVERT(VARCHAR(20), -1), ':',
                               CONVERT(VARCHAR(20), @Rdb440RuleVersionId)))));
            THROW 54450, 'Expected exact occurrence-path rejection did not occur.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 54450 THROW;
            IF ERROR_NUMBER() <> 547 THROW;
        END CATCH;

        /* Invalid closed-verb fixture. */
        BEGIN TRY
            INSERT ATAPUtilities.PermissionVerb (PermissionVerbCode) VALUES ('*');
            THROW 54451, 'Expected wildcard verb rejection did not occur.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 54451 THROW;
            IF ERROR_NUMBER() <> 547 THROW;
        END CATCH;

        DECLARE @Rdb440OccurrenceId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());
        /* SCOPE_IDENTITY was changed by the failed insert; resolve by exact path. */
        SELECT @Rdb440OccurrenceId = BuildSetRuleOccurrenceId
        FROM ATAPUtilities.BuildSetRuleOccurrence
        WHERE BuildSetVersionId = @Rdb440BuildSetVersionId
          AND BuildSetVersionMemberId = @Rdb440BuildSetVersionMemberId
          AND RuleSetVersionMemberId = @Rdb440RuleSetVersionMemberId
          AND RuleVersionId = @Rdb440RuleVersionId;
        DECLARE @Rdb440OccurrenceKey BINARY(32) =
            (SELECT OccurrenceKey FROM ATAPUtilities.BuildSetRuleOccurrence
             WHERE BuildSetRuleOccurrenceId = @Rdb440OccurrenceId);

        DECLARE @Rdb440BaseInstantiationVersionId BIGINT;
        DECLARE @Rdb440InstantiationId BIGINT;
        DECLARE @Rdb440BaseRevision INT;
        SELECT TOP (1)
            @Rdb440BaseInstantiationVersionId = base.InstantiationVersionId,
            @Rdb440InstantiationId = base.InstantiationId,
            @Rdb440BaseRevision = base.RevisionSequence
        FROM ATAPUtilities.InstantiationVersion AS base
        LEFT JOIN ATAPUtilities.InstantiationVersion AS successor
          ON successor.PredecessorInstantiationVersionId = base.InstantiationVersionId
        WHERE base.BuildSetVersionId = @Rdb440BuildSetVersionId
          AND successor.InstantiationVersionId IS NULL
        ORDER BY base.InstantiationVersionId;
        IF @Rdb440BaseInstantiationVersionId IS NULL
            THROW 54454, 'RDB-440 successor fixture requires a pre-existing base InstantiationVersion.', 1;

        INSERT ATAPUtilities.InstantiationOccurrenceBinding
            (InstantiationId, BuildSetRuleOccurrenceId, BuildSetVersionId,
             OccurrenceKey, RuleVersionId, BindingCompatibilityContractVersionId, CreatedAtUtc)
        VALUES (@Rdb440InstantiationId, @Rdb440OccurrenceId, @Rdb440BuildSetVersionId,
                @Rdb440OccurrenceKey, @Rdb440RuleVersionId, NULL, SYSUTCDATETIME());
        DECLARE @Rdb440BindingId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());

        /* Positive migration decision fixture: explicitly remove an old mapping. */
        INSERT ATAPUtilities.BindingResolution
            (SuccessorBindingId, PredecessorBindingId, ResolutionVerbCode,
             SelectedRuleDefaultInputValueId, MappingEvidenceEntityId,
             MappingEvidenceEntityTypeId, DecisionAuthorityReference,
             ResolutionContentHash, DecidedAtUtc)
        VALUES (@Rdb440BindingId, NULL, 'remove', NULL, NULL, NULL,
                'authority:rdb440-fixture', HASHBYTES('SHA2_256', 'RDB-440-remove'),
                SYSUTCDATETIME());

        DECLARE @Rdb440InputBlockTypeId BIGINT =
            (SELECT EntityTypeId FROM ATAPUtilities.EntityType WHERE EntityTypeCode = 'input-block');
        DECLARE @Rdb440InputBlockVersionTypeId BIGINT =
            (SELECT EntityTypeId FROM ATAPUtilities.EntityType WHERE EntityTypeCode = 'input-block-version');
        DECLARE @Rdb440InstantiationVersionTypeId BIGINT =
            (SELECT EntityTypeId FROM ATAPUtilities.EntityType WHERE EntityTypeCode = 'instantiation-version');
        IF @Rdb440InputBlockTypeId IS NULL OR @Rdb440InputBlockVersionTypeId IS NULL
           OR @Rdb440InstantiationVersionTypeId IS NULL
            THROW 54455, 'RDB-440 fixtures require the frozen RDB-320 EntityType rows.', 1;

        DECLARE @Rdb440InputBlockPhilote UNIQUEIDENTIFIER =
            'A6F0E797-05A2-5B15-A0BB-7D1E19C40441';
        DECLARE @Rdb440InputBlockVersionPhilote UNIQUEIDENTIFIER =
            '91DCAAA1-83DE-5B66-9F9E-511783210442';
        DECLARE @Rdb440SuccessorVersionPhilote UNIQUEIDENTIFIER =
            '7211F680-F56F-5B24-8E14-C8C68B8A0443';
        DECLARE @Rdb440InputBlockEntityId BIGINT;
        DECLARE @Rdb440InputBlockVersionEntityId BIGINT;
        DECLARE @Rdb440SuccessorVersionEntityId BIGINT;

        INSERT ATAPUtilities.Entity (EntityTypeId, EntityPhiloteId, CreatedAtUtc)
        VALUES (@Rdb440InputBlockTypeId, @Rdb440InputBlockPhilote, SYSUTCDATETIME());
        SET @Rdb440InputBlockEntityId = CONVERT(BIGINT, SCOPE_IDENTITY());
        INSERT ATAPUtilities.Entity (EntityTypeId, EntityPhiloteId, CreatedAtUtc)
        VALUES (@Rdb440InputBlockVersionTypeId, @Rdb440InputBlockVersionPhilote, SYSUTCDATETIME());
        SET @Rdb440InputBlockVersionEntityId = CONVERT(BIGINT, SCOPE_IDENTITY());
        INSERT ATAPUtilities.Entity (EntityTypeId, EntityPhiloteId, CreatedAtUtc)
        VALUES (@Rdb440InstantiationVersionTypeId, @Rdb440SuccessorVersionPhilote, SYSUTCDATETIME());
        SET @Rdb440SuccessorVersionEntityId = CONVERT(BIGINT, SCOPE_IDENTITY());

        INSERT ATAPUtilities.InputBlock
            (InputBlockPhiloteId, EntityId, EntityTypeId,
             InstantiationOccurrenceBindingId, InstantiationId, CreatedAtUtc)
        VALUES (@Rdb440InputBlockPhilote, @Rdb440InputBlockEntityId,
                @Rdb440InputBlockTypeId, @Rdb440BindingId,
                @Rdb440InstantiationId, SYSUTCDATETIME());
        DECLARE @Rdb440InputBlockId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());

        INSERT ATAPUtilities.EditSession
            (InstantiationId, ActorAuthorityReference, BaseInstantiationVersionId,
             ConcurrencyToken, StateCode, ProposedRevisionSequence, StartedAtUtc,
             LastHeartbeatAtUtc, ClosedAtUtc)
        VALUES (@Rdb440InstantiationId, 'authority:rdb440-fixture',
                @Rdb440BaseInstantiationVersionId,
                HASHBYTES('SHA2_256', 'RDB-440-edit-session'), 'active',
                @Rdb440BaseRevision + 1, SYSUTCDATETIME(), SYSUTCDATETIME(), NULL);
        DECLARE @Rdb440EditSessionId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());

        INSERT ATAPUtilities.InputBlockVersion
            (InputBlockVersionPhiloteId, EntityId, EntityTypeId, InputBlockId,
             InstantiationOccurrenceBindingId, InstantiationId, RuleVersionId,
             RevisionSequence, PredecessorInputBlockVersionId, SourceEditSessionId,
             ContentHashAlgorithmCode, ContentHash, PublishedAtUtc)
        VALUES (@Rdb440InputBlockVersionPhilote, @Rdb440InputBlockVersionEntityId,
                @Rdb440InputBlockVersionTypeId, @Rdb440InputBlockId,
                @Rdb440BindingId, @Rdb440InstantiationId, @Rdb440RuleVersionId,
                1, NULL, @Rdb440EditSessionId, 'sha256',
                HASHBYTES('SHA2_256', 'RDB-440-input-block-version'), SYSUTCDATETIME());
        DECLARE @Rdb440InputBlockVersionId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());

        DECLARE @Rdb440RuleInputDefinitionId BIGINT;
        DECLARE @Rdb440ValueTypeVersionId BIGINT;
        DECLARE @Rdb440MinCardinality INT;
        DECLARE @Rdb440ScalarStorageKindCode VARCHAR(64);
        SELECT TOP (1)
            @Rdb440RuleInputDefinitionId = d.RuleInputDefinitionId,
            @Rdb440ValueTypeVersionId = d.ValueTypeVersionId,
            @Rdb440MinCardinality = CASE WHEN d.MinCardinality < 1 THEN 1 ELSE d.MinCardinality END,
            @Rdb440ScalarStorageKindCode = vt.ScalarStorageKindCode
        FROM ATAPUtilities.RuleInputDefinition AS d
        INNER JOIN ATAPUtilities.ValueTypeVersion AS vt
          ON vt.ValueTypeVersionId = d.ValueTypeVersionId
        WHERE d.RuleVersionId = @Rdb440RuleVersionId
          AND vt.ValueCategoryCode = 'scalar'
          AND (d.MaxCardinality IS NULL OR d.MaxCardinality >= 1)
        ORDER BY d.RuleInputDefinitionId;
        IF @Rdb440RuleInputDefinitionId IS NULL
            THROW 54456, 'RDB-440 fixture requires an RDB-420 Rule input for the occurrence RuleVersion.', 1;

        /* Invalid I-11/I-14 fixture: multiple typed shapes are rejected. */
        BEGIN TRY
            INSERT ATAPUtilities.InputValue
                (InputBlockVersionId, InstantiationOccurrenceBindingId, RuleVersionId,
                 RuleInputDefinitionId, ValueTypeVersionId, ValueCardinality,
                 ValueCategoryCode, ScalarStorageKindCode, ContainsNullElement,
                 CanonicalTextValue, CanonicalIntegerValue,
                 CanonicalValueHash)
            VALUES (@Rdb440InputBlockVersionId, @Rdb440BindingId, @Rdb440RuleVersionId,
                    @Rdb440RuleInputDefinitionId, @Rdb440ValueTypeVersionId,
                    @Rdb440MinCardinality, 'scalar', @Rdb440ScalarStorageKindCode,
                    0, N'invalid', 1,
                    HASHBYTES('SHA2_256', 'RDB-440-invalid-multiple-shapes'));
            THROW 54457, 'Expected typed-value shape rejection did not occur.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 54457 THROW;
            IF ERROR_NUMBER() <> 547 THROW;
        END CATCH;

        INSERT ATAPUtilities.InputValue
            (InputBlockVersionId, InstantiationOccurrenceBindingId, RuleVersionId,
             RuleInputDefinitionId, ValueTypeVersionId, ValueCardinality,
             ValueCategoryCode, ScalarStorageKindCode, ContainsNullElement,
             CanonicalTextValue, CanonicalValueHash)
        VALUES (@Rdb440InputBlockVersionId, @Rdb440BindingId, @Rdb440RuleVersionId,
                @Rdb440RuleInputDefinitionId, @Rdb440ValueTypeVersionId,
                @Rdb440MinCardinality, 'scalar', @Rdb440ScalarStorageKindCode,
                0, N'fixture',
                HASHBYTES('SHA2_256', 'RDB-440-valid-input'));

        INSERT ATAPUtilities.InstantiationVersion
            (InstantiationVersionPhiloteId, EntityId, EntityTypeId, InstantiationId,
             BuildSetVersionId, RevisionSequence, PredecessorInstantiationVersionId,
             GraphInputHashAlgorithmCode, GraphInputContentHash, PublishedAtUtc)
        VALUES (@Rdb440SuccessorVersionPhilote, @Rdb440SuccessorVersionEntityId,
                @Rdb440InstantiationVersionTypeId, @Rdb440InstantiationId,
                @Rdb440BuildSetVersionId, @Rdb440BaseRevision + 1,
                @Rdb440BaseInstantiationVersionId, 'sha256',
                HASHBYTES('SHA2_256', 'RDB-440-successor-graph'), SYSUTCDATETIME());
        DECLARE @Rdb440SuccessorVersionId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());

        INSERT ATAPUtilities.InstantiationVersionInputBlock
            (InstantiationVersionId, InstantiationId, BuildSetVersionId,
             InstantiationOccurrenceBindingId, OccurrenceKey, RuleVersionId,
             InputBlockVersionId, SelectionContentHash)
        VALUES (@Rdb440SuccessorVersionId, @Rdb440InstantiationId,
                @Rdb440BuildSetVersionId, @Rdb440BindingId,
                @Rdb440OccurrenceKey, @Rdb440RuleVersionId,
                @Rdb440InputBlockVersionId,
                HASHBYTES('SHA2_256', 'RDB-440-selection'));

        INSERT ATAPUtilities.InstantiationPermissionGrant
            (InstantiationId, AuthorityReference, TenantScopeReference,
             PermissionVerbCode, EffectCode, PrecedenceRank, ScopeReference,
             EffectiveFromUtc, EffectiveToUtc, DecisionAuditReference,
             EvaluationContractVersion, DecisionContentHash)
        VALUES (@Rdb440InstantiationId, 'authority:rdb440-fixture',
                'tenant:rdb440-fixture', 'publish', 'allow', 100,
                'instantiation:rdb440-fixture', SYSUTCDATETIME(), NULL,
                'audit:rdb440-fixture', '1',
                HASHBYTES('SHA2_256', 'RDB-440-permission'));

        /* Invalid I-10/I-17 fixture: a second selection for one binding fails. */
        BEGIN TRY
            INSERT ATAPUtilities.InstantiationVersionInputBlock
                (InstantiationVersionId, InstantiationId, BuildSetVersionId,
                 InstantiationOccurrenceBindingId, OccurrenceKey, RuleVersionId,
                 InputBlockVersionId, SelectionContentHash)
            VALUES (@Rdb440SuccessorVersionId, @Rdb440InstantiationId,
                    @Rdb440BuildSetVersionId, @Rdb440BindingId,
                    @Rdb440OccurrenceKey, @Rdb440RuleVersionId,
                    @Rdb440InputBlockVersionId,
                    HASHBYTES('SHA2_256', 'RDB-440-duplicate-selection'));
            THROW 54458, 'Expected duplicate selection rejection did not occur.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 54458 THROW;
            IF ERROR_NUMBER() NOT IN (2601, 2627) THROW;
        END CATCH;

        /* Invalid occurrence-key fixture; run last because trigger errors may doom the fixture transaction. */
        BEGIN TRY
            INSERT ATAPUtilities.BuildSetRuleOccurrence
                (BuildSetVersionId, BuildSetVersionMemberId, RuleSetVersionId,
                 RuleSetVersionMemberId, RuleVersionId, OccurrenceKey)
            VALUES (@Rdb440BuildSetVersionId, @Rdb440BuildSetVersionMemberId,
                    @Rdb440RuleSetVersionId, @Rdb440RuleSetVersionMemberId,
                    @Rdb440RuleVersionId, CONVERT(BINARY(32), 0x01));
            THROW 54459, 'Expected occurrence-key derivation rejection did not occur.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 54459 THROW;
            IF ERROR_NUMBER() <> 54438 THROW;
        END CATCH;

        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
    SET XACT_ABORT ON;
END;

/* Source-static postconditions; RDB-480 repeats them after integration. */
IF (SELECT COUNT_BIG(*) FROM sys.tables
    WHERE schema_id = SCHEMA_ID(N'ATAPUtilities')
      AND name IN
      (N'Instantiation', N'InstantiationVersion', N'BuildSetRuleOccurrence',
       N'InstantiationOccurrenceBinding', N'BindingResolution', N'InputBlock',
       N'InputBlockVersion', N'InputValue', N'InstantiationVersionInputBlock',
       N'PermissionVerb', N'InstantiationPermissionGrant', N'EditSession')) <> 12
    THROW 54452, 'RDB-440 table postcondition failed.', 1;

IF (SELECT COUNT_BIG(*) FROM sys.triggers
    WHERE parent_id IN
    (OBJECT_ID(N'ATAPUtilities.PermissionVerb'), OBJECT_ID(N'ATAPUtilities.Instantiation'),
     OBJECT_ID(N'ATAPUtilities.InstantiationVersion'), OBJECT_ID(N'ATAPUtilities.BuildSetRuleOccurrence'),
     OBJECT_ID(N'ATAPUtilities.InstantiationOccurrenceBinding'), OBJECT_ID(N'ATAPUtilities.BindingResolution'),
     OBJECT_ID(N'ATAPUtilities.InputBlock'), OBJECT_ID(N'ATAPUtilities.InputBlockVersion'),
     OBJECT_ID(N'ATAPUtilities.InputValue'), OBJECT_ID(N'ATAPUtilities.InstantiationVersionInputBlock'),
     OBJECT_ID(N'ATAPUtilities.InstantiationPermissionGrant'), OBJECT_ID(N'ATAPUtilities.EditSession'))
      AND is_disabled = 0) <> 12
    THROW 54453, 'RDB-440 trigger postcondition failed.', 1;

IF OBJECT_ID(N'ATAPUtilities.usp_RollItUpInstantiation', N'P') IS NULL
    THROW 54482, 'RDB-440 trusted publication procedure postcondition failed.', 1;

IF DATABASE_PRINCIPAL_ID(N'RrsbsPublisher') IS NULL
    THROW 54483, 'RDB-440 publisher role postcondition failed.', 1;

IF (SELECT COUNT_BIG(*)
    FROM sys.database_permissions AS permissionRow
    WHERE permissionRow.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'RrsbsPublisher')
      AND permissionRow.state = 'D'
      AND permissionRow.permission_name IN ('INSERT', 'UPDATE', 'DELETE')
      AND permissionRow.major_id IN
      (OBJECT_ID(N'ATAPUtilities.PermissionVerb'), OBJECT_ID(N'ATAPUtilities.Instantiation'),
       OBJECT_ID(N'ATAPUtilities.InstantiationVersion'), OBJECT_ID(N'ATAPUtilities.BuildSetRuleOccurrence'),
       OBJECT_ID(N'ATAPUtilities.InstantiationOccurrenceBinding'), OBJECT_ID(N'ATAPUtilities.EditSession'),
       OBJECT_ID(N'ATAPUtilities.InputBlock'), OBJECT_ID(N'ATAPUtilities.InputBlockVersion'),
       OBJECT_ID(N'ATAPUtilities.InputValue'), OBJECT_ID(N'ATAPUtilities.InstantiationVersionInputBlock'),
       OBJECT_ID(N'ATAPUtilities.BindingResolution'), OBJECT_ID(N'ATAPUtilities.InstantiationPermissionGrant'))) <> 36
    THROW 54484, 'RDB-440 publisher direct-DML denial postcondition failed.', 1;

IF NOT EXISTS
(
    SELECT 1 FROM sys.database_permissions AS permissionRow
    WHERE permissionRow.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'RrsbsPublisher')
      AND permissionRow.major_id = OBJECT_ID(N'ATAPUtilities.usp_RollItUpInstantiation')
      AND permissionRow.permission_name = 'EXECUTE'
      AND permissionRow.state IN ('G', 'W')
)
    THROW 54485, 'RDB-440 publisher EXECUTE grant postcondition failed.', 1;
/* END INTEGRATED FRAGMENT: RDB-440__Instantiation-InputBlock.sql */

/* BEGIN INTEGRATED FRAGMENT: RDB-450__Manifestation-Plan-Approval-Event.sql */
/*
  RDB-450 manifestation/plan/approval/event fragment.
  Target: SQL Server 2022 / compatibility level 160.

  Integration contract:
  - Run after RDB-400/410, RDB-420, RDB-430, and RDB-440.
  - Creates the eleven RDB-250 objects plus seven approved exact immutable
    parents. The four registered
    Entity subtypes use the frozen EntityType codes; the other seven objects
    remain table-addressable relations/catalogs and do not invent types.
  - TargetScope, TargetPolicyVersion, ExecutorBoundary,
    LocatorPolicyVersion, AuthorityPolicyVersion, AuthorizationScope, and
    ExecutorBuild are independent immutable parents with exact consumer FKs.
    ExecutorBoundary is expressly not ExecutorContractVersion.
  - No USE, seed, package, credential, reset, filesystem, or live-tier action.

  RDB-320 deterministic shortening:
  raw: UQ_ManifestationPlan_ManifestationPlanId_InstantiationVersionId_GraphSelectorHash_SelectedInputSnapshotHash_TargetScopeId_TargetPolicyVersionId_ExecutorBoundaryId_HashAlgorithmCode_PlanFingerprint
  physical: UQ_ManifestationPlan_ManifestationPlanId_InstantiationVersionId_GraphSelectorHash_SelectedInputSnapshotHash_Tar_00868EB31BD5FACD
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Rdb450OwnsTransaction bit = 0;
IF @@TRANCOUNT = 0
BEGIN
    BEGIN TRANSACTION;
    SET @Rdb450OwnsTransaction = 1;
END
ELSE
    SAVE TRANSACTION Rdb450Fragment;

BEGIN TRY
    IF OBJECT_ID(N'ATAPUtilities.TargetScope', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.TargetScope
        (
            TargetScopeId BIGINT IDENTITY(1, 1) NOT NULL,
            TargetScopePhiloteId UNIQUEIDENTIFIER NOT NULL,
            SupersedesTargetScopeId BIGINT NULL,
            HashAlgorithmCode VARCHAR(16) NOT NULL,
            ContractFingerprint BINARY(32) NOT NULL,
            DefinedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_TargetScope PRIMARY KEY (TargetScopeId),
            CONSTRAINT UQ_TargetScope_TargetScopePhiloteId UNIQUE (TargetScopePhiloteId),
            CONSTRAINT FK_TargetScope_TargetScope_Supersedes FOREIGN KEY (SupersedesTargetScopeId)
                REFERENCES ATAPUtilities.TargetScope (TargetScopeId),
            CONSTRAINT CK_TargetScope_HashAlgorithm CHECK (HashAlgorithmCode = 'sha256'),
            CONSTRAINT CK_TargetScope_SupersedesNotSelf CHECK
                (SupersedesTargetScopeId IS NULL OR SupersedesTargetScopeId <> TargetScopeId)
        );
        CREATE UNIQUE INDEX UQ_TargetScope_SupersedesTargetScopeId
            ON ATAPUtilities.TargetScope (SupersedesTargetScopeId)
            WHERE SupersedesTargetScopeId IS NOT NULL;
    END;

    IF OBJECT_ID(N'ATAPUtilities.TargetPolicyVersion', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.TargetPolicyVersion
        (
            TargetPolicyVersionId BIGINT IDENTITY(1, 1) NOT NULL,
            TargetPolicyVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            TargetScopeId BIGINT NOT NULL,
            SupersedesTargetPolicyVersionId BIGINT NULL,
            HashAlgorithmCode VARCHAR(16) NOT NULL,
            ContractFingerprint BINARY(32) NOT NULL,
            DefinedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_TargetPolicyVersion PRIMARY KEY (TargetPolicyVersionId),
            CONSTRAINT UQ_TargetPolicyVersion_TargetPolicyVersionPhiloteId UNIQUE
                (TargetPolicyVersionPhiloteId),
            CONSTRAINT UQ_TargetPolicyVersion_TargetPolicyVersionId_TargetScopeId UNIQUE
                (TargetPolicyVersionId, TargetScopeId),
            CONSTRAINT FK_TargetPolicyVersion_TargetScope_ExactScope FOREIGN KEY (TargetScopeId)
                REFERENCES ATAPUtilities.TargetScope (TargetScopeId),
            CONSTRAINT FK_TargetPolicyVersion_TargetPolicyVersion_Supersedes FOREIGN KEY
                (SupersedesTargetPolicyVersionId, TargetScopeId)
                REFERENCES ATAPUtilities.TargetPolicyVersion
                (TargetPolicyVersionId, TargetScopeId),
            CONSTRAINT CK_TargetPolicyVersion_HashAlgorithm CHECK (HashAlgorithmCode = 'sha256'),
            CONSTRAINT CK_TargetPolicyVersion_SupersedesNotSelf CHECK
                (SupersedesTargetPolicyVersionId IS NULL
                 OR SupersedesTargetPolicyVersionId <> TargetPolicyVersionId)
        );
        CREATE UNIQUE INDEX UQ_TargetPolicyVersion_SupersedesTargetPolicyVersionId
            ON ATAPUtilities.TargetPolicyVersion (SupersedesTargetPolicyVersionId)
            WHERE SupersedesTargetPolicyVersionId IS NOT NULL;
    END;

    IF OBJECT_ID(N'ATAPUtilities.ExecutorBoundary', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.ExecutorBoundary
        (
            ExecutorBoundaryId BIGINT IDENTITY(1, 1) NOT NULL,
            ExecutorBoundaryPhiloteId UNIQUEIDENTIFIER NOT NULL,
            SupersedesExecutorBoundaryId BIGINT NULL,
            HashAlgorithmCode VARCHAR(16) NOT NULL,
            ContractFingerprint BINARY(32) NOT NULL,
            DefinedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_ExecutorBoundary PRIMARY KEY (ExecutorBoundaryId),
            CONSTRAINT UQ_ExecutorBoundary_ExecutorBoundaryPhiloteId UNIQUE
                (ExecutorBoundaryPhiloteId),
            CONSTRAINT FK_ExecutorBoundary_ExecutorBoundary_Supersedes FOREIGN KEY
                (SupersedesExecutorBoundaryId) REFERENCES ATAPUtilities.ExecutorBoundary
                (ExecutorBoundaryId),
            CONSTRAINT CK_ExecutorBoundary_HashAlgorithm CHECK (HashAlgorithmCode = 'sha256'),
            CONSTRAINT CK_ExecutorBoundary_SupersedesNotSelf CHECK
                (SupersedesExecutorBoundaryId IS NULL OR SupersedesExecutorBoundaryId <> ExecutorBoundaryId)
        );
        CREATE UNIQUE INDEX UQ_ExecutorBoundary_SupersedesExecutorBoundaryId
            ON ATAPUtilities.ExecutorBoundary (SupersedesExecutorBoundaryId)
            WHERE SupersedesExecutorBoundaryId IS NOT NULL;
    END;

    IF OBJECT_ID(N'ATAPUtilities.LocatorPolicyVersion', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.LocatorPolicyVersion
        (
            LocatorPolicyVersionId BIGINT IDENTITY(1, 1) NOT NULL,
            LocatorPolicyVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            TargetScopeId BIGINT NOT NULL,
            SupersedesLocatorPolicyVersionId BIGINT NULL,
            HashAlgorithmCode VARCHAR(16) NOT NULL,
            ContractFingerprint BINARY(32) NOT NULL,
            DefinedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_LocatorPolicyVersion PRIMARY KEY (LocatorPolicyVersionId),
            CONSTRAINT UQ_LocatorPolicyVersion_LocatorPolicyVersionPhiloteId UNIQUE
                (LocatorPolicyVersionPhiloteId),
            CONSTRAINT UQ_LocatorPolicyVersion_LocatorPolicyVersionId_TargetScopeId UNIQUE
                (LocatorPolicyVersionId, TargetScopeId),
            CONSTRAINT FK_LocatorPolicyVersion_TargetScope_ExactScope FOREIGN KEY (TargetScopeId)
                REFERENCES ATAPUtilities.TargetScope (TargetScopeId),
            CONSTRAINT FK_LocatorPolicyVersion_LocatorPolicyVersion_Supersedes FOREIGN KEY
                (SupersedesLocatorPolicyVersionId, TargetScopeId)
                REFERENCES ATAPUtilities.LocatorPolicyVersion
                (LocatorPolicyVersionId, TargetScopeId),
            CONSTRAINT CK_LocatorPolicyVersion_HashAlgorithm CHECK (HashAlgorithmCode = 'sha256'),
            CONSTRAINT CK_LocatorPolicyVersion_SupersedesNotSelf CHECK
                (SupersedesLocatorPolicyVersionId IS NULL
                 OR SupersedesLocatorPolicyVersionId <> LocatorPolicyVersionId)
        );
        CREATE UNIQUE INDEX UQ_LocatorPolicyVersion_SupersedesLocatorPolicyVersionId
            ON ATAPUtilities.LocatorPolicyVersion (SupersedesLocatorPolicyVersionId)
            WHERE SupersedesLocatorPolicyVersionId IS NOT NULL;
    END;

    IF OBJECT_ID(N'ATAPUtilities.AuthorityPolicyVersion', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.AuthorityPolicyVersion
        (
            AuthorityPolicyVersionId BIGINT IDENTITY(1, 1) NOT NULL,
            AuthorityPolicyVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            SupersedesAuthorityPolicyVersionId BIGINT NULL,
            HashAlgorithmCode VARCHAR(16) NOT NULL,
            ContractFingerprint BINARY(32) NOT NULL,
            DefinedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_AuthorityPolicyVersion PRIMARY KEY (AuthorityPolicyVersionId),
            CONSTRAINT UQ_AuthorityPolicyVersion_AuthorityPolicyVersionPhiloteId UNIQUE
                (AuthorityPolicyVersionPhiloteId),
            CONSTRAINT FK_AuthorityPolicyVersion_AuthorityPolicyVersion_Supersedes FOREIGN KEY
                (SupersedesAuthorityPolicyVersionId) REFERENCES ATAPUtilities.AuthorityPolicyVersion
                (AuthorityPolicyVersionId),
            CONSTRAINT CK_AuthorityPolicyVersion_HashAlgorithm CHECK (HashAlgorithmCode = 'sha256'),
            CONSTRAINT CK_AuthorityPolicyVersion_SupersedesNotSelf CHECK
                (SupersedesAuthorityPolicyVersionId IS NULL
                 OR SupersedesAuthorityPolicyVersionId <> AuthorityPolicyVersionId)
        );
        CREATE UNIQUE INDEX UQ_AuthorityPolicyVersion_SupersedesAuthorityPolicyVersionId
            ON ATAPUtilities.AuthorityPolicyVersion (SupersedesAuthorityPolicyVersionId)
            WHERE SupersedesAuthorityPolicyVersionId IS NOT NULL;
    END;

    IF OBJECT_ID(N'ATAPUtilities.AuthorizationScope', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.AuthorizationScope
        (
            AuthorizationScopeId BIGINT IDENTITY(1, 1) NOT NULL,
            AuthorizationScopePhiloteId UNIQUEIDENTIFIER NOT NULL,
            SupersedesAuthorizationScopeId BIGINT NULL,
            HashAlgorithmCode VARCHAR(16) NOT NULL,
            ContractFingerprint BINARY(32) NOT NULL,
            DefinedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_AuthorizationScope PRIMARY KEY (AuthorizationScopeId),
            CONSTRAINT UQ_AuthorizationScope_AuthorizationScopePhiloteId UNIQUE
                (AuthorizationScopePhiloteId),
            CONSTRAINT FK_AuthorizationScope_AuthorizationScope_Supersedes FOREIGN KEY
                (SupersedesAuthorizationScopeId) REFERENCES ATAPUtilities.AuthorizationScope
                (AuthorizationScopeId),
            CONSTRAINT CK_AuthorizationScope_HashAlgorithm CHECK (HashAlgorithmCode = 'sha256'),
            CONSTRAINT CK_AuthorizationScope_SupersedesNotSelf CHECK
                (SupersedesAuthorizationScopeId IS NULL
                 OR SupersedesAuthorizationScopeId <> AuthorizationScopeId)
        );
        CREATE UNIQUE INDEX UQ_AuthorizationScope_SupersedesAuthorizationScopeId
            ON ATAPUtilities.AuthorizationScope (SupersedesAuthorizationScopeId)
            WHERE SupersedesAuthorizationScopeId IS NOT NULL;
    END;

    IF OBJECT_ID(N'ATAPUtilities.ExecutorBuild', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.ExecutorBuild
        (
            ExecutorBuildId BIGINT IDENTITY(1, 1) NOT NULL,
            ExecutorBuildPhiloteId UNIQUEIDENTIFIER NOT NULL,
            ExecutorBoundaryId BIGINT NOT NULL,
            SupersedesExecutorBuildId BIGINT NULL,
            HashAlgorithmCode VARCHAR(16) NOT NULL,
            ContractFingerprint BINARY(32) NOT NULL,
            DefinedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_ExecutorBuild PRIMARY KEY (ExecutorBuildId),
            CONSTRAINT UQ_ExecutorBuild_ExecutorBuildPhiloteId UNIQUE (ExecutorBuildPhiloteId),
            CONSTRAINT UQ_ExecutorBuild_ExecutorBuildId_ExecutorBoundaryId UNIQUE
                (ExecutorBuildId, ExecutorBoundaryId),
            CONSTRAINT FK_ExecutorBuild_ExecutorBoundary_ExactBoundary FOREIGN KEY (ExecutorBoundaryId)
                REFERENCES ATAPUtilities.ExecutorBoundary (ExecutorBoundaryId),
            CONSTRAINT FK_ExecutorBuild_ExecutorBuild_Supersedes FOREIGN KEY
                (SupersedesExecutorBuildId, ExecutorBoundaryId)
                REFERENCES ATAPUtilities.ExecutorBuild (ExecutorBuildId, ExecutorBoundaryId),
            CONSTRAINT CK_ExecutorBuild_HashAlgorithm CHECK (HashAlgorithmCode = 'sha256'),
            CONSTRAINT CK_ExecutorBuild_SupersedesNotSelf CHECK
                (SupersedesExecutorBuildId IS NULL OR SupersedesExecutorBuildId <> ExecutorBuildId)
        );
        CREATE UNIQUE INDEX UQ_ExecutorBuild_SupersedesExecutorBuildId
            ON ATAPUtilities.ExecutorBuild (SupersedesExecutorBuildId)
            WHERE SupersedesExecutorBuildId IS NOT NULL;
    END;

    IF OBJECT_ID(N'ATAPUtilities.ManifestationPlan', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.ManifestationPlan
        (
            ManifestationPlanId BIGINT IDENTITY(1, 1) NOT NULL,
            ManifestationPlanPhiloteId UNIQUEIDENTIFIER NOT NULL,
            EntityId BIGINT NOT NULL,
            EntityTypeId BIGINT NOT NULL,
            EntityTypeCode VARCHAR(64) NOT NULL CONSTRAINT DF_ManifestationPlan_EntityTypeCode DEFAULT ('manifestation-plan'),
            InstantiationVersionId BIGINT NOT NULL,
            GraphSelectorHash BINARY(32) NOT NULL,
            SelectedInputSnapshotHash BINARY(32) NOT NULL,
            TargetScopeId BIGINT NOT NULL,
            TargetPolicyVersionId BIGINT NOT NULL,
            ExecutorBoundaryId BIGINT NOT NULL,
            HashAlgorithmCode VARCHAR(16) NOT NULL,
            PlanFingerprint BINARY(32) NOT NULL,
            PlannedAtUtc DATETIME2(7) NOT NULL,
            CONSTRAINT PK_ManifestationPlan PRIMARY KEY (ManifestationPlanId),
            CONSTRAINT UQ_ManifestationPlan_ManifestationPlanPhiloteId UNIQUE (ManifestationPlanPhiloteId),
            CONSTRAINT UQ_ManifestationPlan_PlanFingerprint UNIQUE (PlanFingerprint),
            CONSTRAINT UQ_ManifestationPlan_ManifestationPlanId_TargetScopeId UNIQUE
                (ManifestationPlanId, TargetScopeId),
            CONSTRAINT UQ_ManifestationPlan_ManifestationPlanId_InstantiationVersionId_GraphSelectorHash_SelectedInputSnapshotHash_Tar_00868EB31BD5FACD
                UNIQUE (ManifestationPlanId, InstantiationVersionId, GraphSelectorHash,
                        SelectedInputSnapshotHash, TargetScopeId, TargetPolicyVersionId,
                        ExecutorBoundaryId, HashAlgorithmCode, PlanFingerprint),
            CONSTRAINT FK_ManifestationPlan_Entity_Registration FOREIGN KEY
                (EntityId, EntityTypeId, ManifestationPlanPhiloteId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId, EntityPhiloteId),
            CONSTRAINT FK_ManifestationPlan_EntityType_ClosedType FOREIGN KEY
                (EntityTypeId, EntityTypeCode)
                REFERENCES ATAPUtilities.EntityType (EntityTypeId, EntityTypeCode),
            CONSTRAINT FK_ManifestationPlan_InstantiationVersion_ExactVersion FOREIGN KEY
                (InstantiationVersionId)
                REFERENCES ATAPUtilities.InstantiationVersion (InstantiationVersionId),
            CONSTRAINT FK_ManifestationPlan_TargetScope_ExactScope FOREIGN KEY (TargetScopeId)
                REFERENCES ATAPUtilities.TargetScope (TargetScopeId),
            CONSTRAINT FK_ManifestationPlan_TargetPolicyVersion_ExactScope FOREIGN KEY
                (TargetPolicyVersionId, TargetScopeId)
                REFERENCES ATAPUtilities.TargetPolicyVersion (TargetPolicyVersionId, TargetScopeId),
            CONSTRAINT FK_ManifestationPlan_ExecutorBoundary_ExactBoundary FOREIGN KEY
                (ExecutorBoundaryId) REFERENCES ATAPUtilities.ExecutorBoundary (ExecutorBoundaryId),
            CONSTRAINT CK_ManifestationPlan_EntityTypeCode CHECK (EntityTypeCode = 'manifestation-plan'),
            CONSTRAINT CK_ManifestationPlan_HashAlgorithm CHECK (HashAlgorithmCode = 'sha256'),
            CONSTRAINT CK_ManifestationPlan_OpaqueParentsPositive CHECK
                (TargetScopeId > 0 AND TargetPolicyVersionId > 0 AND ExecutorBoundaryId > 0)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.PlanArtifact', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.PlanArtifact
        (
            PlanArtifactId BIGINT IDENTITY(1, 1) NOT NULL,
            ManifestationPlanId BIGINT NOT NULL,
            SlotOrdinal INT NOT NULL,
            CanonicalLocator VARCHAR(1024) NOT NULL,
            LocatorPolicyVersionId BIGINT NOT NULL,
            EffectClassCode VARCHAR(32) NOT NULL,
            ExpectedContentHash BINARY(32) NOT NULL,
            ExpectedByteCount BIGINT NOT NULL,
            TargetScopeId BIGINT NOT NULL,
            CONSTRAINT PK_PlanArtifact PRIMARY KEY (PlanArtifactId),
            CONSTRAINT UQ_PlanArtifact_ManifestationPlanId_SlotOrdinal UNIQUE
                (ManifestationPlanId, SlotOrdinal),
            CONSTRAINT UQ_PlanArtifact_ManifestationPlanId_CanonicalLocator UNIQUE
                (ManifestationPlanId, CanonicalLocator),
            CONSTRAINT UQ_PlanArtifact_PlanArtifactId_ManifestationPlanId_CanonicalLocator_ExpectedContentHash_ExpectedByteCount
                UNIQUE (PlanArtifactId, ManifestationPlanId, CanonicalLocator,
                        ExpectedContentHash, ExpectedByteCount),
            CONSTRAINT FK_PlanArtifact_ManifestationPlan_Parent FOREIGN KEY
                (ManifestationPlanId) REFERENCES ATAPUtilities.ManifestationPlan (ManifestationPlanId),
            CONSTRAINT FK_PlanArtifact_ManifestationPlan_ExactTargetScope FOREIGN KEY
                (ManifestationPlanId, TargetScopeId)
                REFERENCES ATAPUtilities.ManifestationPlan (ManifestationPlanId, TargetScopeId),
            CONSTRAINT FK_PlanArtifact_TargetScope_ExactScope FOREIGN KEY (TargetScopeId)
                REFERENCES ATAPUtilities.TargetScope (TargetScopeId),
            CONSTRAINT FK_PlanArtifact_LocatorPolicyVersion_ExactScope FOREIGN KEY
                (LocatorPolicyVersionId, TargetScopeId)
                REFERENCES ATAPUtilities.LocatorPolicyVersion (LocatorPolicyVersionId, TargetScopeId),
            CONSTRAINT CK_PlanArtifact_SlotOrdinal CHECK (SlotOrdinal >= 0),
            CONSTRAINT CK_PlanArtifact_EffectClassCode CHECK
                (EffectClassCode IN ('create', 'replace', 'delete', 'metadata-only')),
            CONSTRAINT CK_PlanArtifact_ExpectedByteCount CHECK (ExpectedByteCount >= 0),
            CONSTRAINT CK_PlanArtifact_OpaqueParentsPositive CHECK
                (LocatorPolicyVersionId > 0 AND TargetScopeId > 0),
            CONSTRAINT CK_PlanArtifact_CanonicalLocator CHECK
                (LEN(CanonicalLocator) BETWEEN 1 AND 1024 AND CanonicalLocator = LOWER(CanonicalLocator))
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.PlanApproval', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.PlanApproval
        (
            PlanApprovalId BIGINT IDENTITY(1, 1) NOT NULL,
            PlanApprovalPhiloteId UNIQUEIDENTIFIER NOT NULL,
            EntityId BIGINT NOT NULL,
            EntityTypeId BIGINT NOT NULL,
            EntityTypeCode VARCHAR(64) NOT NULL CONSTRAINT DF_PlanApproval_EntityTypeCode DEFAULT ('plan-approval'),
            ManifestationPlanId BIGINT NOT NULL,
            InstantiationVersionId BIGINT NOT NULL,
            GraphSelectorHash BINARY(32) NOT NULL,
            SelectedInputSnapshotHash BINARY(32) NOT NULL,
            TargetScopeId BIGINT NOT NULL,
            TargetPolicyVersionId BIGINT NOT NULL,
            ExecutorBoundaryId BIGINT NOT NULL,
            HashAlgorithmCode VARCHAR(16) NOT NULL,
            PlanFingerprint BINARY(32) NOT NULL,
            AuthorityEntityId BIGINT NOT NULL,
            AuthorityEntityTypeId BIGINT NOT NULL,
            AuthorityPolicyVersionId BIGINT NOT NULL,
            DecisionCode VARCHAR(16) NOT NULL,
            DecidedAtUtc DATETIME2(7) NOT NULL,
            ExpiresAtUtc DATETIME2(7) NULL,
            CONSTRAINT PK_PlanApproval PRIMARY KEY (PlanApprovalId),
            CONSTRAINT UQ_PlanApproval_PlanApprovalPhiloteId UNIQUE (PlanApprovalPhiloteId),
            CONSTRAINT UQ_PlanApproval_PlanApprovalId_ManifestationPlanId UNIQUE
                (PlanApprovalId, ManifestationPlanId),
            CONSTRAINT FK_PlanApproval_Entity_Registration FOREIGN KEY
                (EntityId, EntityTypeId, PlanApprovalPhiloteId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId, EntityPhiloteId),
            CONSTRAINT FK_PlanApproval_EntityType_ClosedType FOREIGN KEY
                (EntityTypeId, EntityTypeCode)
                REFERENCES ATAPUtilities.EntityType (EntityTypeId, EntityTypeCode),
            CONSTRAINT FK_PlanApproval_ManifestationPlan_ExactBoundary FOREIGN KEY
                (ManifestationPlanId, InstantiationVersionId, GraphSelectorHash,
                 SelectedInputSnapshotHash, TargetScopeId, TargetPolicyVersionId,
                 ExecutorBoundaryId, HashAlgorithmCode, PlanFingerprint)
                REFERENCES ATAPUtilities.ManifestationPlan
                (ManifestationPlanId, InstantiationVersionId, GraphSelectorHash,
                 SelectedInputSnapshotHash, TargetScopeId, TargetPolicyVersionId,
                 ExecutorBoundaryId, HashAlgorithmCode, PlanFingerprint),
            CONSTRAINT FK_PlanApproval_Entity_DecisionAuthority FOREIGN KEY
                (AuthorityEntityId, AuthorityEntityTypeId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId),
            CONSTRAINT FK_PlanApproval_TargetScope_ExactScope FOREIGN KEY (TargetScopeId)
                REFERENCES ATAPUtilities.TargetScope (TargetScopeId),
            CONSTRAINT FK_PlanApproval_TargetPolicyVersion_ExactScope FOREIGN KEY
                (TargetPolicyVersionId, TargetScopeId)
                REFERENCES ATAPUtilities.TargetPolicyVersion (TargetPolicyVersionId, TargetScopeId),
            CONSTRAINT FK_PlanApproval_ExecutorBoundary_ExactBoundary FOREIGN KEY
                (ExecutorBoundaryId) REFERENCES ATAPUtilities.ExecutorBoundary (ExecutorBoundaryId),
            CONSTRAINT FK_PlanApproval_AuthorityPolicyVersion_ExactPolicy FOREIGN KEY
                (AuthorityPolicyVersionId)
                REFERENCES ATAPUtilities.AuthorityPolicyVersion (AuthorityPolicyVersionId),
            CONSTRAINT CK_PlanApproval_EntityTypeCode CHECK (EntityTypeCode = 'plan-approval'),
            CONSTRAINT CK_PlanApproval_DecisionCode CHECK (DecisionCode IN ('approved', 'denied')),
            CONSTRAINT CK_PlanApproval_HashAlgorithm CHECK (HashAlgorithmCode = 'sha256'),
            CONSTRAINT CK_PlanApproval_Expiry CHECK (ExpiresAtUtc IS NULL OR ExpiresAtUtc > DecidedAtUtc),
            CONSTRAINT CK_PlanApproval_AuthorityPolicyVersionId CHECK (AuthorityPolicyVersionId > 0)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.PlanApprovalStateEvent', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.PlanApprovalStateEvent
        (
            PlanApprovalStateEventId BIGINT IDENTITY(1, 1) NOT NULL,
            PlanApprovalId BIGINT NOT NULL,
            StateEventCode VARCHAR(32) NOT NULL,
            AuthorityEntityId BIGINT NOT NULL,
            AuthorityEntityTypeId BIGINT NOT NULL,
            AuthorityPolicyVersionId BIGINT NOT NULL,
            RecordedAtUtc DATETIME2(7) NOT NULL,
            SuccessorPlanApprovalId BIGINT NULL,
            CONSTRAINT PK_PlanApprovalStateEvent PRIMARY KEY (PlanApprovalStateEventId),
            CONSTRAINT UQ_PlanApprovalStateEvent_Approval_State UNIQUE
                (PlanApprovalId, StateEventCode),
            CONSTRAINT FK_PlanApprovalStateEvent_PlanApproval_Parent FOREIGN KEY
                (PlanApprovalId) REFERENCES ATAPUtilities.PlanApproval (PlanApprovalId),
            CONSTRAINT FK_PlanApprovalStateEvent_PlanApproval_Successor FOREIGN KEY
                (SuccessorPlanApprovalId) REFERENCES ATAPUtilities.PlanApproval (PlanApprovalId),
            CONSTRAINT FK_PlanApprovalStateEvent_Entity_DecisionAuthority FOREIGN KEY
                (AuthorityEntityId, AuthorityEntityTypeId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId),
            CONSTRAINT FK_PlanApprovalStateEvent_AuthorityPolicyVersion_ExactPolicy FOREIGN KEY
                (AuthorityPolicyVersionId)
                REFERENCES ATAPUtilities.AuthorityPolicyVersion (AuthorityPolicyVersionId),
            CONSTRAINT CK_PlanApprovalStateEvent_StateEventCode CHECK
                (StateEventCode IN ('revoked', 'superseded', 'expired-observed')),
            CONSTRAINT CK_PlanApprovalStateEvent_SuccessorShape CHECK
                ((StateEventCode = 'superseded' AND SuccessorPlanApprovalId IS NOT NULL)
                 OR (StateEventCode <> 'superseded' AND SuccessorPlanApprovalId IS NULL)),
            CONSTRAINT CK_PlanApprovalStateEvent_AuthorityPolicyVersionId CHECK
                (AuthorityPolicyVersionId > 0),
            CONSTRAINT CK_PlanApprovalStateEvent_SuccessorNotSelf CHECK
                (SuccessorPlanApprovalId IS NULL OR SuccessorPlanApprovalId <> PlanApprovalId)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.Manifestation', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.Manifestation
        (
            ManifestationId BIGINT IDENTITY(1, 1) NOT NULL,
            ManifestationPhiloteId UNIQUEIDENTIFIER NOT NULL,
            EntityId BIGINT NOT NULL,
            EntityTypeId BIGINT NOT NULL,
            EntityTypeCode VARCHAR(64) NOT NULL CONSTRAINT DF_Manifestation_EntityTypeCode DEFAULT ('manifestation'),
            ManifestationPlanId BIGINT NOT NULL,
            PlanApprovalId BIGINT NOT NULL,
            AuthorizationScopeId BIGINT NOT NULL,
            CallerIdempotencyKey VARCHAR(128) NOT NULL,
            RequestFingerprint BINARY(32) NOT NULL,
            RequestedAtUtc DATETIME2(7) NOT NULL,
            StateCode VARCHAR(32) NOT NULL,
            CONSTRAINT PK_Manifestation PRIMARY KEY (ManifestationId),
            CONSTRAINT UQ_Manifestation_ManifestationPhiloteId UNIQUE (ManifestationPhiloteId),
            CONSTRAINT UQ_Manifestation_AuthorizationScopeId_CallerIdempotencyKey UNIQUE
                (AuthorizationScopeId, CallerIdempotencyKey),
            CONSTRAINT UQ_Manifestation_ManifestationId_ManifestationPlanId_PlanApprovalId UNIQUE
                (ManifestationId, ManifestationPlanId, PlanApprovalId),
            CONSTRAINT UQ_Manifestation_ManifestationId_ManifestationPlanId UNIQUE
                (ManifestationId, ManifestationPlanId),
            CONSTRAINT FK_Manifestation_Entity_Registration FOREIGN KEY
                (EntityId, EntityTypeId, ManifestationPhiloteId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId, EntityPhiloteId),
            CONSTRAINT FK_Manifestation_EntityType_ClosedType FOREIGN KEY
                (EntityTypeId, EntityTypeCode)
                REFERENCES ATAPUtilities.EntityType (EntityTypeId, EntityTypeCode),
            CONSTRAINT FK_Manifestation_PlanApproval_ExactPlan FOREIGN KEY
                (PlanApprovalId, ManifestationPlanId)
                REFERENCES ATAPUtilities.PlanApproval (PlanApprovalId, ManifestationPlanId),
            CONSTRAINT FK_Manifestation_AuthorizationScope_ExactScope FOREIGN KEY
                (AuthorizationScopeId)
                REFERENCES ATAPUtilities.AuthorizationScope (AuthorizationScopeId),
            CONSTRAINT CK_Manifestation_EntityTypeCode CHECK (EntityTypeCode = 'manifestation'),
            CONSTRAINT CK_Manifestation_AuthorizationScopeId CHECK (AuthorizationScopeId > 0),
            CONSTRAINT CK_Manifestation_CallerIdempotencyKey CHECK
                (LEN(CallerIdempotencyKey) BETWEEN 1 AND 128
                 AND CallerIdempotencyKey = LOWER(CallerIdempotencyKey)
                 AND CallerIdempotencyKey NOT LIKE '%[^a-z0-9._:-]%'),
            CONSTRAINT CK_Manifestation_StateCode CHECK
                (StateCode IN ('requested', 'running', 'succeeded', 'failed', 'cancelled', 'recovery-required'))
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.ManifestationAttempt', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.ManifestationAttempt
        (
            ManifestationAttemptId BIGINT IDENTITY(1, 1) NOT NULL,
            ManifestationId BIGINT NOT NULL,
            AttemptNumber INT NOT NULL,
            RetryOfManifestationAttemptId BIGINT NULL,
            ExecutorBuildId BIGINT NOT NULL,
            LeaseHolderReference VARCHAR(128) NOT NULL,
            LeaseToken UNIQUEIDENTIFIER NOT NULL,
            LeaseExpiresAtUtc DATETIME2(7) NOT NULL,
            LastHeartbeatAtUtc DATETIME2(7) NOT NULL,
            StartedAtUtc DATETIME2(7) NOT NULL,
            TerminalAtUtc DATETIME2(7) NULL,
            StateCode VARCHAR(32) NOT NULL,
            DiagnosticHash BINARY(32) NULL,
            CONSTRAINT PK_ManifestationAttempt PRIMARY KEY (ManifestationAttemptId),
            CONSTRAINT UQ_ManifestationAttempt_ManifestationId_AttemptNumber UNIQUE
                (ManifestationId, AttemptNumber),
            CONSTRAINT UQ_ManifestationAttempt_LeaseToken UNIQUE (LeaseToken),
            CONSTRAINT UQ_ManifestationAttempt_ManifestationAttemptId_ManifestationId UNIQUE
                (ManifestationAttemptId, ManifestationId),
            CONSTRAINT UQ_ManifestationAttempt_Attempt_Lease_Build UNIQUE
                (ManifestationAttemptId, LeaseHolderReference, LeaseToken, ExecutorBuildId),
            CONSTRAINT FK_ManifestationAttempt_Manifestation_Parent FOREIGN KEY
                (ManifestationId) REFERENCES ATAPUtilities.Manifestation (ManifestationId),
            CONSTRAINT FK_ManifestationAttempt_ManifestationAttempt_RetrySameManifestation FOREIGN KEY
                (RetryOfManifestationAttemptId, ManifestationId)
                REFERENCES ATAPUtilities.ManifestationAttempt (ManifestationAttemptId, ManifestationId),
            CONSTRAINT FK_ManifestationAttempt_ExecutorBuild_ExactBuild FOREIGN KEY (ExecutorBuildId)
                REFERENCES ATAPUtilities.ExecutorBuild (ExecutorBuildId),
            CONSTRAINT CK_ManifestationAttempt_AttemptNumber CHECK (AttemptNumber > 0),
            CONSTRAINT CK_ManifestationAttempt_ExecutorBuildId CHECK (ExecutorBuildId > 0),
            CONSTRAINT CK_ManifestationAttempt_LeaseTimes CHECK
                (LastHeartbeatAtUtc >= StartedAtUtc AND LeaseExpiresAtUtc > LastHeartbeatAtUtc),
            CONSTRAINT CK_ManifestationAttempt_TerminalTime CHECK
                (TerminalAtUtc IS NULL OR TerminalAtUtc >= StartedAtUtc),
            CONSTRAINT CK_ManifestationAttempt_StateShape CHECK
                ((StateCode IN ('succeeded', 'failed', 'cancelled', 'recovery-required') AND TerminalAtUtc IS NOT NULL)
                 OR (StateCode IN ('leased', 'running') AND TerminalAtUtc IS NULL)),
            CONSTRAINT CK_ManifestationAttempt_RetryNotSelf CHECK
                (RetryOfManifestationAttemptId IS NULL OR RetryOfManifestationAttemptId <> ManifestationAttemptId)
        );
    END;

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'ATAPUtilities.ManifestationAttempt')
          AND name = N'UQ_ManifestationAttempt_RetryOfManifestationAttemptId'
    )
    BEGIN
        CREATE UNIQUE INDEX UQ_ManifestationAttempt_RetryOfManifestationAttemptId
            ON ATAPUtilities.ManifestationAttempt (RetryOfManifestationAttemptId)
            WHERE RetryOfManifestationAttemptId IS NOT NULL;
    END;

    IF OBJECT_ID(N'ATAPUtilities.RuleExecution', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.RuleExecution
        (
            RuleExecutionId BIGINT IDENTITY(1, 1) NOT NULL,
            ManifestationAttemptId BIGINT NOT NULL,
            BuildSetRuleOccurrenceId BIGINT NOT NULL,
            BuildSetVersionId BIGINT NOT NULL,
            OccurrenceKey BINARY(32) NOT NULL,
            RuleVersionId BIGINT NOT NULL,
            ExecutionOrdinal INT NOT NULL,
            ExecutorBuildId BIGINT NOT NULL,
            LeaseHolderReference VARCHAR(128) NOT NULL,
            LeaseToken UNIQUEIDENTIFIER NOT NULL,
            OutcomeCode VARCHAR(32) NOT NULL,
            StartedAtUtc DATETIME2(7) NOT NULL,
            FinishedAtUtc DATETIME2(7) NULL,
            ExecutionFingerprint BINARY(32) NOT NULL,
            CONSTRAINT PK_RuleExecution PRIMARY KEY (RuleExecutionId),
            CONSTRAINT UQ_RuleExecution_Attempt_Occurrence_Ordinal UNIQUE
                (ManifestationAttemptId, OccurrenceKey, ExecutionOrdinal),
            CONSTRAINT UQ_RuleExecution_RuleExecutionId_ManifestationAttemptId_RuleVersionId_OutcomeCode UNIQUE
                (RuleExecutionId, ManifestationAttemptId, RuleVersionId, OutcomeCode),
            CONSTRAINT UQ_RuleExecution_RuleExecutionId_ManifestationAttemptId_RuleVersionId UNIQUE
                (RuleExecutionId, ManifestationAttemptId, RuleVersionId),
            CONSTRAINT UQ_RuleExecution_RuleExecutionId_ManifestationAttemptId UNIQUE
                (RuleExecutionId, ManifestationAttemptId),
            CONSTRAINT FK_RuleExecution_ManifestationAttempt_Parent FOREIGN KEY
                (ManifestationAttemptId)
                REFERENCES ATAPUtilities.ManifestationAttempt (ManifestationAttemptId),
            CONSTRAINT FK_RuleExecution_ManifestationAttempt_ExactLease FOREIGN KEY
                (ManifestationAttemptId, LeaseHolderReference, LeaseToken, ExecutorBuildId)
                REFERENCES ATAPUtilities.ManifestationAttempt
                (ManifestationAttemptId, LeaseHolderReference, LeaseToken, ExecutorBuildId),
            CONSTRAINT FK_RuleExecution_BuildSetRuleOccurrence_ExactOccurrence FOREIGN KEY
                (BuildSetRuleOccurrenceId, BuildSetVersionId, OccurrenceKey, RuleVersionId)
                REFERENCES ATAPUtilities.BuildSetRuleOccurrence
                (BuildSetRuleOccurrenceId, BuildSetVersionId, OccurrenceKey, RuleVersionId),
            CONSTRAINT FK_RuleExecution_ExecutorBuild_ExactBuild FOREIGN KEY (ExecutorBuildId)
                REFERENCES ATAPUtilities.ExecutorBuild (ExecutorBuildId),
            CONSTRAINT CK_RuleExecution_ExecutionOrdinal CHECK (ExecutionOrdinal >= 0),
            CONSTRAINT CK_RuleExecution_ExecutorBuildId CHECK (ExecutorBuildId > 0),
            CONSTRAINT CK_RuleExecution_OutcomeCode CHECK
                (OutcomeCode IN ('started', 'succeeded', 'failed', 'cancelled', 'recovery-required')),
            CONSTRAINT CK_RuleExecution_TimeShape CHECK
                ((OutcomeCode = 'started' AND FinishedAtUtc IS NULL)
                 OR (OutcomeCode <> 'started' AND FinishedAtUtc IS NOT NULL AND FinishedAtUtc >= StartedAtUtc))
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.ErrorTaxonomy', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.ErrorTaxonomy
        (
            ErrorTaxonomyCode VARCHAR(64) NOT NULL,
            CategoryCode VARCHAR(32) NOT NULL,
            RetryDispositionCode VARCHAR(32) NOT NULL,
            SafetyClassCode VARCHAR(32) NOT NULL,
            SupersedesErrorTaxonomyCode VARCHAR(64) NULL,
            RetiredAtUtc DATETIME2(7) NULL,
            CONSTRAINT PK_ErrorTaxonomy PRIMARY KEY (ErrorTaxonomyCode),
            CONSTRAINT FK_ErrorTaxonomy_ErrorTaxonomy_Supersedes FOREIGN KEY
                (SupersedesErrorTaxonomyCode)
                REFERENCES ATAPUtilities.ErrorTaxonomy (ErrorTaxonomyCode),
            CONSTRAINT CK_ErrorTaxonomy_CodeFormat CHECK
                (LEN(ErrorTaxonomyCode) BETWEEN 1 AND 64
                 AND ErrorTaxonomyCode = LOWER(ErrorTaxonomyCode)
                 AND ErrorTaxonomyCode NOT LIKE '%[^a-z0-9._-]%'),
            CONSTRAINT CK_ErrorTaxonomy_CategoryCode CHECK
                (CategoryCode IN ('validation', 'authorization', 'concurrency', 'executor', 'target', 'recovery')),
            CONSTRAINT CK_ErrorTaxonomy_RetryDispositionCode CHECK
                (RetryDispositionCode IN ('never', 'after-correction', 'safe', 'recovery-required')),
            CONSTRAINT CK_ErrorTaxonomy_SafetyClassCode CHECK
                (SafetyClassCode IN ('no-effect', 'effect-unknown', 'partial-effect', 'effect-confirmed')),
            CONSTRAINT CK_ErrorTaxonomy_SupersedesNotSelf CHECK
                (SupersedesErrorTaxonomyCode IS NULL OR SupersedesErrorTaxonomyCode <> ErrorTaxonomyCode)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.ManifestationEvent', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.ManifestationEvent
        (
            ManifestationEventId BIGINT IDENTITY(1, 1) NOT NULL,
            ManifestationAttemptId BIGINT NOT NULL,
            EventSequence INT NOT NULL,
            EventKindCode VARCHAR(32) NOT NULL,
            OccurredAtUtc DATETIME2(7) NOT NULL,
            RuleExecutionId BIGINT NULL,
            PlanArtifactId BIGINT NULL,
            ErrorTaxonomyCode VARCHAR(64) NULL,
            OutboxMessageId UNIQUEIDENTIFIER NULL,
            DiagnosticHash BINARY(32) NULL,
            CONSTRAINT PK_ManifestationEvent PRIMARY KEY (ManifestationEventId),
            CONSTRAINT UQ_ManifestationEvent_Attempt_Sequence UNIQUE
                (ManifestationAttemptId, EventSequence),
            CONSTRAINT FK_ManifestationEvent_ManifestationAttempt_Parent FOREIGN KEY
                (ManifestationAttemptId)
                REFERENCES ATAPUtilities.ManifestationAttempt (ManifestationAttemptId),
            CONSTRAINT FK_ManifestationEvent_RuleExecution_SameAttempt FOREIGN KEY
                (RuleExecutionId, ManifestationAttemptId)
                REFERENCES ATAPUtilities.RuleExecution (RuleExecutionId, ManifestationAttemptId),
            CONSTRAINT FK_ManifestationEvent_PlanArtifact_Reference FOREIGN KEY
                (PlanArtifactId) REFERENCES ATAPUtilities.PlanArtifact (PlanArtifactId),
            CONSTRAINT FK_ManifestationEvent_ErrorTaxonomy_KnownCode FOREIGN KEY
                (ErrorTaxonomyCode) REFERENCES ATAPUtilities.ErrorTaxonomy (ErrorTaxonomyCode),
            CONSTRAINT CK_ManifestationEvent_EventSequence CHECK (EventSequence > 0),
            CONSTRAINT CK_ManifestationEvent_EventKindCode CHECK
                (EventKindCode IN ('attempt-started', 'lease-heartbeat', 'rule-started',
                 'rule-succeeded', 'rule-failed', 'artifact-observed', 'outbox-pending',
                 'outbox-delivered', 'recovery-required', 'attempt-succeeded',
                 'attempt-failed', 'attempt-cancelled')),
            CONSTRAINT CK_ManifestationEvent_ReferenceShape CHECK
                ((EventKindCode IN ('rule-started', 'rule-succeeded', 'rule-failed') AND RuleExecutionId IS NOT NULL)
                 OR (EventKindCode NOT IN ('rule-started', 'rule-succeeded', 'rule-failed')))
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.ManifestationArtifact', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.ManifestationArtifact
        (
            ManifestationArtifactId BIGINT IDENTITY(1, 1) NOT NULL,
            ManifestationArtifactPhiloteId UNIQUEIDENTIFIER NOT NULL,
            EntityId BIGINT NOT NULL,
            EntityTypeId BIGINT NOT NULL,
            EntityTypeCode VARCHAR(64) NOT NULL CONSTRAINT DF_ManifestationArtifact_EntityTypeCode DEFAULT ('manifestation-artifact'),
            ManifestationId BIGINT NOT NULL,
            ManifestationPlanId BIGINT NOT NULL,
            ManifestationAttemptId BIGINT NOT NULL,
            RuleExecutionId BIGINT NOT NULL,
            RuleVersionId BIGINT NOT NULL,
            RuleExecutionOutcomeCode VARCHAR(32) NOT NULL,
            PlanArtifactId BIGINT NOT NULL,
            ObservedCanonicalLocator VARCHAR(1024) NOT NULL,
            ObservedContentHash BINARY(32) NOT NULL,
            ObservedByteCount BIGINT NOT NULL,
            ObservedAtUtc DATETIME2(7) NOT NULL,
            ArtifactStateCode VARCHAR(32) NOT NULL,
            ReusedFromManifestationArtifactId BIGINT NULL,
            CONSTRAINT PK_ManifestationArtifact PRIMARY KEY (ManifestationArtifactId),
            CONSTRAINT UQ_ManifestationArtifact_ManifestationArtifactPhiloteId UNIQUE
                (ManifestationArtifactPhiloteId),
            CONSTRAINT UQ_ManifestationArtifact_Attempt_PlanArtifact UNIQUE
                (ManifestationAttemptId, PlanArtifactId),
            CONSTRAINT UQ_ManifestationArtifact_ManifestationArtifactId_ManifestationPlanId UNIQUE
                (ManifestationArtifactId, ManifestationPlanId),
            CONSTRAINT FK_ManifestationArtifact_Entity_Registration FOREIGN KEY
                (EntityId, EntityTypeId, ManifestationArtifactPhiloteId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId, EntityPhiloteId),
            CONSTRAINT FK_ManifestationArtifact_EntityType_ClosedType FOREIGN KEY
                (EntityTypeId, EntityTypeCode)
                REFERENCES ATAPUtilities.EntityType (EntityTypeId, EntityTypeCode),
            CONSTRAINT FK_ManifestationArtifact_Manifestation_ExactPlan FOREIGN KEY
                (ManifestationId, ManifestationPlanId)
                REFERENCES ATAPUtilities.Manifestation (ManifestationId, ManifestationPlanId),
            CONSTRAINT FK_ManifestationArtifact_Attempt_SameManifestation FOREIGN KEY
                (ManifestationAttemptId, ManifestationId)
                REFERENCES ATAPUtilities.ManifestationAttempt (ManifestationAttemptId, ManifestationId),
            CONSTRAINT FK_ManifestationArtifact_RuleExecution_SuccessProducer FOREIGN KEY
                (RuleExecutionId, ManifestationAttemptId, RuleVersionId, RuleExecutionOutcomeCode)
                REFERENCES ATAPUtilities.RuleExecution
                (RuleExecutionId, ManifestationAttemptId, RuleVersionId, OutcomeCode),
            CONSTRAINT FK_ManifestationArtifact_PlanArtifact_ExactExpectedOutput FOREIGN KEY
                (PlanArtifactId, ManifestationPlanId, ObservedCanonicalLocator,
                 ObservedContentHash, ObservedByteCount)
                REFERENCES ATAPUtilities.PlanArtifact
                (PlanArtifactId, ManifestationPlanId, CanonicalLocator,
                 ExpectedContentHash, ExpectedByteCount),
            CONSTRAINT FK_ManifestationArtifact_ManifestationArtifact_ReusedFrom FOREIGN KEY
                (ReusedFromManifestationArtifactId, ManifestationPlanId)
                REFERENCES ATAPUtilities.ManifestationArtifact
                (ManifestationArtifactId, ManifestationPlanId),
            CONSTRAINT CK_ManifestationArtifact_EntityTypeCode CHECK
                (EntityTypeCode = 'manifestation-artifact'),
            CONSTRAINT CK_ManifestationArtifact_ObservedByteCount CHECK (ObservedByteCount >= 0),
            CONSTRAINT CK_ManifestationArtifact_ProducerSucceeded CHECK
                (RuleExecutionOutcomeCode = 'succeeded'),
            CONSTRAINT CK_ManifestationArtifact_StateShape CHECK
                ((ArtifactStateCode = 'produced' AND ReusedFromManifestationArtifactId IS NULL)
                 OR (ArtifactStateCode = 'cache-reused' AND ReusedFromManifestationArtifactId IS NOT NULL)),
            CONSTRAINT CK_ManifestationArtifact_ReusedFromNotSelf CHECK
                (ReusedFromManifestationArtifactId IS NULL
                 OR ReusedFromManifestationArtifactId <> ManifestationArtifactId)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.RuleUsage', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.RuleUsage
        (
            RuleUsageId BIGINT IDENTITY(1, 1) NOT NULL,
            SubjectEntityId BIGINT NOT NULL,
            SubjectEntityTypeId BIGINT NOT NULL,
            SubjectVersionId BIGINT NOT NULL,
            SubjectVersionEntityTypeId BIGINT NOT NULL,
            RuleVersionId BIGINT NOT NULL,
            UsageRoleCode VARCHAR(32) NOT NULL,
            ProvenanceKindCode VARCHAR(16) NOT NULL,
            ManifestationPlanId BIGINT NULL,
            ManifestationAttemptId BIGINT NULL,
            RuleExecutionId BIGINT NULL,
            RecordedAtUtc DATETIME2(7) NOT NULL,
            UsageFingerprint BINARY(32) NOT NULL,
            CONSTRAINT PK_RuleUsage PRIMARY KEY (RuleUsageId),
            CONSTRAINT UQ_RuleUsage_NaturalFact UNIQUE
                (SubjectEntityId, SubjectVersionId, RuleVersionId, UsageRoleCode,
                 ProvenanceKindCode, UsageFingerprint),
            CONSTRAINT FK_RuleUsage_Entity_Subject FOREIGN KEY
                (SubjectEntityId, SubjectEntityTypeId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId),
            CONSTRAINT FK_RuleUsage_Entity_SubjectVersion FOREIGN KEY
                (SubjectVersionId, SubjectVersionEntityTypeId)
                REFERENCES ATAPUtilities.Entity (EntityId, EntityTypeId),
            CONSTRAINT FK_RuleUsage_RuleVersion_ExactVersion FOREIGN KEY
                (RuleVersionId) REFERENCES ATAPUtilities.RuleVersion (RuleVersionId),
            CONSTRAINT FK_RuleUsage_ManifestationPlan_PlannedSource FOREIGN KEY
                (ManifestationPlanId) REFERENCES ATAPUtilities.ManifestationPlan (ManifestationPlanId),
            CONSTRAINT FK_RuleUsage_RuleExecution_ObservedSource FOREIGN KEY
                (RuleExecutionId, ManifestationAttemptId, RuleVersionId)
                REFERENCES ATAPUtilities.RuleExecution
                (RuleExecutionId, ManifestationAttemptId, RuleVersionId),
            CONSTRAINT CK_RuleUsage_UsageRoleCode CHECK
                (UsageRoleCode IN ('composition', 'selection', 'execution', 'validation', 'provenance')),
            CONSTRAINT CK_RuleUsage_ProvenanceKindCode CHECK
                (ProvenanceKindCode IN ('planned', 'observed')),
            CONSTRAINT CK_RuleUsage_ProvenanceShape CHECK
                ((ProvenanceKindCode = 'planned' AND ManifestationPlanId IS NOT NULL
                  AND ManifestationAttemptId IS NULL AND RuleExecutionId IS NULL)
                 OR (ProvenanceKindCode = 'observed' AND ManifestationPlanId IS NULL
                     AND ManifestationAttemptId IS NOT NULL AND RuleExecutionId IS NOT NULL))
        );
    END;

    /* Exact parents and every RDB-250 row are append-only. */
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_TargetScope_UpdateDeleteImmutable ON ATAPUtilities.TargetScope INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54560, ''TargetScope is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_TargetPolicyVersion_UpdateDeleteImmutable ON ATAPUtilities.TargetPolicyVersion INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54561, ''TargetPolicyVersion is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_ExecutorBoundary_UpdateDeleteImmutable ON ATAPUtilities.ExecutorBoundary INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54562, ''ExecutorBoundary is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_LocatorPolicyVersion_UpdateDeleteImmutable ON ATAPUtilities.LocatorPolicyVersion INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54563, ''LocatorPolicyVersion is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_AuthorityPolicyVersion_UpdateDeleteImmutable ON ATAPUtilities.AuthorityPolicyVersion INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54564, ''AuthorityPolicyVersion is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_AuthorizationScope_UpdateDeleteImmutable ON ATAPUtilities.AuthorizationScope INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54565, ''AuthorizationScope is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_ExecutorBuild_UpdateDeleteImmutable ON ATAPUtilities.ExecutorBuild INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54566, ''ExecutorBuild is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_ManifestationPlan_UpdateDeleteImmutable ON ATAPUtilities.ManifestationPlan INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54501, ''ManifestationPlan is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_PlanArtifact_UpdateDeleteImmutable ON ATAPUtilities.PlanArtifact INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54502, ''PlanArtifact is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_PlanApproval_UpdateDeleteImmutable ON ATAPUtilities.PlanApproval INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54503, ''PlanApproval is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_PlanApprovalStateEvent_UpdateDeleteImmutable ON ATAPUtilities.PlanApprovalStateEvent INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54504, ''PlanApprovalStateEvent is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_Manifestation_UpdateDeleteImmutable ON ATAPUtilities.Manifestation INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54505, ''Manifestation is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_ManifestationAttempt_UpdateDeleteImmutable ON ATAPUtilities.ManifestationAttempt INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54506, ''ManifestationAttempt is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_RuleExecution_UpdateDeleteImmutable ON ATAPUtilities.RuleExecution INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54507, ''RuleExecution is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_ManifestationEvent_UpdateDeleteImmutable ON ATAPUtilities.ManifestationEvent INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54508, ''ManifestationEvent is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_ManifestationArtifact_UpdateDeleteImmutable ON ATAPUtilities.ManifestationArtifact INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54509, ''ManifestationArtifact is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_ErrorTaxonomy_UpdateDeleteImmutable ON ATAPUtilities.ErrorTaxonomy INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54510, ''ErrorTaxonomy is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER ATAPUtilities.TR_RuleUsage_UpdateDeleteImmutable ON ATAPUtilities.RuleUsage INSTEAD OF UPDATE, DELETE AS BEGIN SET NOCOUNT ON; THROW 54511, ''RuleUsage is immutable.'', 1; END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_PlanApprovalStateEvent_InsertContract
ON ATAPUtilities.PlanApprovalStateEvent AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN ATAPUtilities.PlanApproval AS a ON a.PlanApprovalId = i.PlanApprovalId
        LEFT JOIN ATAPUtilities.PlanApproval AS successor
          ON successor.PlanApprovalId = i.SuccessorPlanApprovalId
        WHERE i.RecordedAtUtc < a.DecidedAtUtc
           OR (i.StateEventCode = ''expired-observed''
               AND (a.ExpiresAtUtc IS NULL OR i.RecordedAtUtc < a.ExpiresAtUtc))
           OR (i.StateEventCode = ''superseded''
               AND successor.ManifestationPlanId <> a.ManifestationPlanId)
    ) THROW 54520, ''Approval state event violates decision/expiry chronology.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_Manifestation_InsertApprovalEffective
ON ATAPUtilities.Manifestation AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN ATAPUtilities.PlanApproval AS a ON a.PlanApprovalId = i.PlanApprovalId
        WHERE a.DecisionCode <> ''approved''
           OR (a.ExpiresAtUtc IS NOT NULL AND a.ExpiresAtUtc <= i.RequestedAtUtc)
           OR EXISTS
              (SELECT 1 FROM ATAPUtilities.PlanApprovalStateEvent AS s
               WHERE s.PlanApprovalId = i.PlanApprovalId
                 AND s.RecordedAtUtc <= i.RequestedAtUtc
                 AND s.StateEventCode IN (''revoked'', ''superseded'', ''expired-observed''))
    ) THROW 54521, ''Manifestation requires an effective exact approval.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_ManifestationAttempt_InsertContract
ON ATAPUtilities.ManifestationAttempt AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        LEFT JOIN ATAPUtilities.ManifestationAttempt AS p
          ON p.ManifestationAttemptId = i.RetryOfManifestationAttemptId
        WHERE (i.AttemptNumber = 1 AND i.RetryOfManifestationAttemptId IS NOT NULL)
           OR (i.AttemptNumber > 1 AND
               (i.RetryOfManifestationAttemptId IS NULL OR p.AttemptNumber <> i.AttemptNumber - 1))
    ) THROW 54522, ''Attempt retry lineage must be same-manifestation and consecutive.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN ATAPUtilities.Manifestation AS m ON m.ManifestationId = i.ManifestationId
        INNER JOIN ATAPUtilities.PlanApproval AS a ON a.PlanApprovalId = m.PlanApprovalId
        INNER JOIN ATAPUtilities.ManifestationPlan AS p ON p.ManifestationPlanId = m.ManifestationPlanId
        INNER JOIN ATAPUtilities.ExecutorBuild AS eb ON eb.ExecutorBuildId = i.ExecutorBuildId
        WHERE eb.ExecutorBoundaryId <> p.ExecutorBoundaryId
           OR a.DecisionCode <> ''approved''
           OR (a.ExpiresAtUtc IS NOT NULL AND a.ExpiresAtUtc <= i.StartedAtUtc)
           OR EXISTS
              (SELECT 1 FROM ATAPUtilities.PlanApprovalStateEvent AS s
               WHERE s.PlanApprovalId = a.PlanApprovalId
                 AND s.RecordedAtUtc <= i.StartedAtUtc
                 AND s.StateEventCode IN (''revoked'', ''superseded'', ''expired-observed''))
    ) THROW 54523, ''Attempt creation/retry requires revalidated approval.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN ATAPUtilities.ManifestationAttempt AS a
          ON a.ManifestationId = i.ManifestationId
         AND a.ManifestationAttemptId <> i.ManifestationAttemptId
         AND a.TerminalAtUtc IS NULL
         AND a.StartedAtUtc < i.LeaseExpiresAtUtc
         AND i.StartedAtUtc < a.LeaseExpiresAtUtc
    ) THROW 54524, ''Overlapping active effect leases are forbidden.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_RuleExecution_InsertGraphContract
ON ATAPUtilities.RuleExecution AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN ATAPUtilities.ManifestationAttempt AS a
          ON a.ManifestationAttemptId = i.ManifestationAttemptId
        INNER JOIN ATAPUtilities.Manifestation AS m ON m.ManifestationId = a.ManifestationId
        INNER JOIN ATAPUtilities.ManifestationPlan AS p ON p.ManifestationPlanId = m.ManifestationPlanId
        INNER JOIN ATAPUtilities.InstantiationVersion AS iv
          ON iv.InstantiationVersionId = p.InstantiationVersionId
        WHERE iv.BuildSetVersionId <> i.BuildSetVersionId
           OR i.ExecutorBuildId <> a.ExecutorBuildId
           OR i.StartedAtUtc < a.StartedAtUtc
           OR i.StartedAtUtc >= a.LeaseExpiresAtUtc
           OR (i.FinishedAtUtc IS NOT NULL AND i.FinishedAtUtc > a.LeaseExpiresAtUtc)
    ) THROW 54525, ''RuleExecution is outside the approved graph, build, or lease.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_ManifestationEvent_InsertSequence
ON ATAPUtilities.ManifestationEvent AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        WHERE i.EventSequence <> 1 +
          (SELECT COUNT_BIG(*) FROM ATAPUtilities.ManifestationEvent AS e
           WHERE e.ManifestationAttemptId = i.ManifestationAttemptId
             AND e.ManifestationEventId <> i.ManifestationEventId
             AND e.EventSequence < i.EventSequence)
    ) THROW 54526, ''ManifestationEvent sequence must be gap-free from one.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted
        WHERE (EventKindCode = ''artifact-observed'' AND PlanArtifactId IS NULL)
           OR (EventKindCode IN (''rule-failed'', ''recovery-required'', ''attempt-failed'')
               AND ErrorTaxonomyCode IS NULL)
           OR (EventKindCode IN (''outbox-pending'', ''outbox-delivered'')
               AND OutboxMessageId IS NULL)
    ) THROW 54527, ''ManifestationEvent kind requires its typed evidence reference.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER ATAPUtilities.TR_ManifestationArtifact_InsertCacheContract
ON ATAPUtilities.ManifestationArtifact AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN ATAPUtilities.RuleExecution AS re ON re.RuleExecutionId = i.RuleExecutionId
        INNER JOIN ATAPUtilities.ManifestationAttempt AS a
          ON a.ManifestationAttemptId = i.ManifestationAttemptId
        WHERE a.StateCode <> ''succeeded''
           OR re.FinishedAtUtc IS NULL
           OR i.ObservedAtUtc < re.FinishedAtUtc
    ) THROW 54529, ''Observed artifact requires a succeeded attempt and finished producer.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN ATAPUtilities.ManifestationArtifact AS o
          ON o.ManifestationArtifactId = i.ReusedFromManifestationArtifactId
        INNER JOIN ATAPUtilities.RuleExecution AS ore ON ore.RuleExecutionId = o.RuleExecutionId
        INNER JOIN ATAPUtilities.ManifestationAttempt AS oa
          ON oa.ManifestationAttemptId = o.ManifestationAttemptId
        INNER JOIN ATAPUtilities.ManifestationAttempt AS ia
          ON ia.ManifestationAttemptId = i.ManifestationAttemptId
        WHERE i.ArtifactStateCode = ''cache-reused''
          AND (o.ObservedCanonicalLocator <> i.ObservedCanonicalLocator
               OR o.ObservedContentHash <> i.ObservedContentHash
               OR o.ObservedByteCount <> i.ObservedByteCount
               OR ore.OutcomeCode <> ''succeeded''
               OR oa.ExecutorBuildId <> ia.ExecutorBuildId)
    ) THROW 54528, ''Cache reuse requires an identical completed original producer.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE ATAPUtilities.usp_PublishManifestationPlan
    @ManifestationPlanPhiloteId UNIQUEIDENTIFIER,
    @EntityId BIGINT,
    @EntityTypeId BIGINT,
    @InstantiationVersionId BIGINT,
    @GraphSelectorHash BINARY(32),
    @SelectedInputSnapshotHash BINARY(32),
    @TargetScopeId BIGINT,
    @TargetPolicyVersionId BIGINT,
    @ExecutorBoundaryId BIGINT,
    @PlanFingerprint BINARY(32),
    @PlannedAtUtc DATETIME2(7),
    @PlanArtifactsJson NVARCHAR(MAX)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT <> 0 THROW 54570, ''Plan publication must own its transaction.'', 1;
    IF ISJSON(@PlanArtifactsJson) <> 1 THROW 54571, ''Plan artifacts must be a JSON array.'', 1;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @LockResult INT;
        DECLARE @LockResource NVARCHAR(255) =
            CONCAT(N''RRSBS:Plan:'', CONVERT(VARCHAR(66), @PlanFingerprint, 1));
        EXEC @LockResult = sys.sp_getapplock @Resource = @LockResource,
            @LockMode = ''Exclusive'', @LockOwner = ''Transaction'', @LockTimeout = 15000;
        IF @LockResult < 0 THROW 54572, ''Plan publication lock failed.'', 1;

        DECLARE @ExistingPlanId BIGINT;
        SELECT @ExistingPlanId = ManifestationPlanId
        FROM ATAPUtilities.ManifestationPlan WITH (UPDLOCK, HOLDLOCK)
        WHERE ManifestationPlanPhiloteId = @ManifestationPlanPhiloteId
          AND PlanFingerprint = @PlanFingerprint;
        IF @ExistingPlanId IS NOT NULL
        BEGIN
            COMMIT TRANSACTION;
            SELECT @ExistingPlanId AS ManifestationPlanId, CONVERT(BIT, 1) AS WasIdempotentReplay;
            RETURN;
        END;
        IF NOT EXISTS
        (
            SELECT 1 FROM ATAPUtilities.Entity
            WHERE EntityId = @EntityId AND EntityTypeId = @EntityTypeId
              AND EntityPhiloteId = @ManifestationPlanPhiloteId
        ) THROW 54573, ''Plan Entity registration is missing or inexact.'', 1;
        IF NOT EXISTS (SELECT 1 FROM OPENJSON(@PlanArtifactsJson))
            THROW 54574, ''A published plan requires at least one artifact slot.'', 1;

        INSERT ATAPUtilities.ManifestationPlan
            (ManifestationPlanPhiloteId, EntityId, EntityTypeId,
             InstantiationVersionId, GraphSelectorHash, SelectedInputSnapshotHash,
             TargetScopeId, TargetPolicyVersionId, ExecutorBoundaryId,
             HashAlgorithmCode, PlanFingerprint, PlannedAtUtc)
        VALUES
            (@ManifestationPlanPhiloteId, @EntityId, @EntityTypeId,
             @InstantiationVersionId, @GraphSelectorHash, @SelectedInputSnapshotHash,
             @TargetScopeId, @TargetPolicyVersionId, @ExecutorBoundaryId,
             ''sha256'', @PlanFingerprint, @PlannedAtUtc);
        DECLARE @ManifestationPlanId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());

        INSERT ATAPUtilities.PlanArtifact
            (ManifestationPlanId, SlotOrdinal, CanonicalLocator,
             LocatorPolicyVersionId, EffectClassCode, ExpectedContentHash,
             ExpectedByteCount, TargetScopeId)
        SELECT @ManifestationPlanId, artifact.SlotOrdinal, artifact.CanonicalLocator,
               artifact.LocatorPolicyVersionId, artifact.EffectClassCode,
               CONVERT(BINARY(32), artifact.ExpectedContentHashHex, 1),
               artifact.ExpectedByteCount, @TargetScopeId
        FROM OPENJSON(@PlanArtifactsJson)
        WITH
        (
            SlotOrdinal INT ''$.slotOrdinal'',
            CanonicalLocator VARCHAR(1024) ''$.canonicalLocator'',
            LocatorPolicyVersionId BIGINT ''$.locatorPolicyVersionId'',
            EffectClassCode VARCHAR(32) ''$.effectClassCode'',
            ExpectedContentHashHex VARCHAR(66) ''$.expectedContentHash'',
            ExpectedByteCount BIGINT ''$.expectedByteCount''
        ) AS artifact;
        IF @@ROWCOUNT <> (SELECT COUNT(*) FROM OPENJSON(@PlanArtifactsJson))
            THROW 54575, ''Plan artifact publication is incomplete.'', 1;
        COMMIT TRANSACTION;
        SELECT @ManifestationPlanId AS ManifestationPlanId, CONVERT(BIT, 0) AS WasIdempotentReplay;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE ATAPUtilities.usp_RecordPlanApproval
    @PlanApprovalPhiloteId UNIQUEIDENTIFIER,
    @EntityId BIGINT,
    @EntityTypeId BIGINT,
    @ManifestationPlanId BIGINT,
    @AuthorityEntityId BIGINT,
    @AuthorityEntityTypeId BIGINT,
    @AuthorityPolicyVersionId BIGINT,
    @DecisionCode VARCHAR(16),
    @DecidedAtUtc DATETIME2(7),
    @ExpiresAtUtc DATETIME2(7) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT <> 0 THROW 54576, ''Approval recording must own its transaction.'', 1;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @LockResult INT;
        DECLARE @LockResource NVARCHAR(255) =
            CONCAT(N''RRSBS:PlanApproval:'', CONVERT(NVARCHAR(20), @ManifestationPlanId));
        EXEC @LockResult = sys.sp_getapplock @Resource = @LockResource,
            @LockMode = ''Exclusive'', @LockOwner = ''Transaction'', @LockTimeout = 15000;
        IF @LockResult < 0 THROW 54577, ''Approval recording lock failed.'', 1;

        DECLARE @ExistingApprovalId BIGINT;
        SELECT @ExistingApprovalId = PlanApprovalId
        FROM ATAPUtilities.PlanApproval WITH (UPDLOCK, HOLDLOCK)
        WHERE PlanApprovalPhiloteId = @PlanApprovalPhiloteId
          AND ManifestationPlanId = @ManifestationPlanId
          AND AuthorityEntityId = @AuthorityEntityId
          AND AuthorityEntityTypeId = @AuthorityEntityTypeId
          AND AuthorityPolicyVersionId = @AuthorityPolicyVersionId
          AND DecisionCode = @DecisionCode;
        IF @ExistingApprovalId IS NOT NULL
        BEGIN
            COMMIT TRANSACTION;
            SELECT @ExistingApprovalId AS PlanApprovalId, CONVERT(BIT, 1) AS WasIdempotentReplay;
            RETURN;
        END;
        IF NOT EXISTS
        (
            SELECT 1 FROM ATAPUtilities.Entity
            WHERE EntityId = @EntityId AND EntityTypeId = @EntityTypeId
              AND EntityPhiloteId = @PlanApprovalPhiloteId
        ) THROW 54578, ''Approval Entity registration is missing or inexact.'', 1;

        INSERT ATAPUtilities.PlanApproval
            (PlanApprovalPhiloteId, EntityId, EntityTypeId, ManifestationPlanId,
             InstantiationVersionId, GraphSelectorHash, SelectedInputSnapshotHash,
             TargetScopeId, TargetPolicyVersionId, ExecutorBoundaryId,
             HashAlgorithmCode, PlanFingerprint, AuthorityEntityId,
             AuthorityEntityTypeId, AuthorityPolicyVersionId, DecisionCode,
             DecidedAtUtc, ExpiresAtUtc)
        SELECT @PlanApprovalPhiloteId, @EntityId, @EntityTypeId, p.ManifestationPlanId,
               p.InstantiationVersionId, p.GraphSelectorHash, p.SelectedInputSnapshotHash,
               p.TargetScopeId, p.TargetPolicyVersionId, p.ExecutorBoundaryId,
               p.HashAlgorithmCode, p.PlanFingerprint, @AuthorityEntityId,
               @AuthorityEntityTypeId, @AuthorityPolicyVersionId, @DecisionCode,
               @DecidedAtUtc, @ExpiresAtUtc
        FROM ATAPUtilities.ManifestationPlan AS p WITH (UPDLOCK, HOLDLOCK)
        WHERE p.ManifestationPlanId = @ManifestationPlanId;
        IF @@ROWCOUNT <> 1 THROW 54579, ''The exact plan was not found for approval.'', 1;
        DECLARE @PlanApprovalId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());
        COMMIT TRANSACTION;
        SELECT @PlanApprovalId AS PlanApprovalId, CONVERT(BIT, 0) AS WasIdempotentReplay;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE ATAPUtilities.usp_AppendPlanApprovalStateEvent
    @PlanApprovalId BIGINT,
    @StateEventCode VARCHAR(32),
    @AuthorityEntityId BIGINT,
    @AuthorityEntityTypeId BIGINT,
    @AuthorityPolicyVersionId BIGINT,
    @RecordedAtUtc DATETIME2(7),
    @SuccessorPlanApprovalId BIGINT = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT <> 0 THROW 54580, ''Approval-state append must own its transaction.'', 1;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @LockResult INT;
        DECLARE @LockResource NVARCHAR(255) =
            CONCAT(N''RRSBS:ApprovalState:'', CONVERT(NVARCHAR(20), @PlanApprovalId));
        EXEC @LockResult = sys.sp_getapplock @Resource = @LockResource,
            @LockMode = ''Exclusive'', @LockOwner = ''Transaction'', @LockTimeout = 15000;
        IF @LockResult < 0 THROW 54581, ''Approval-state lock failed.'', 1;
        IF EXISTS
        (
            SELECT 1 FROM ATAPUtilities.PlanApprovalStateEvent WITH (UPDLOCK, HOLDLOCK)
            WHERE PlanApprovalId = @PlanApprovalId AND StateEventCode = @StateEventCode
        ) THROW 54582, ''The approval state event already exists.'', 1;
        INSERT ATAPUtilities.PlanApprovalStateEvent
            (PlanApprovalId, StateEventCode, AuthorityEntityId, AuthorityEntityTypeId,
             AuthorityPolicyVersionId, RecordedAtUtc, SuccessorPlanApprovalId)
        VALUES
            (@PlanApprovalId, @StateEventCode, @AuthorityEntityId, @AuthorityEntityTypeId,
             @AuthorityPolicyVersionId, @RecordedAtUtc, @SuccessorPlanApprovalId);
        DECLARE @PlanApprovalStateEventId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());
        COMMIT TRANSACTION;
        SELECT @PlanApprovalStateEventId AS PlanApprovalStateEventId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE ATAPUtilities.usp_AppendManifestationAttemptJournal
    @ManifestationPhiloteId UNIQUEIDENTIFIER,
    @ManifestationEntityId BIGINT,
    @ManifestationEntityTypeId BIGINT,
    @PlanApprovalId BIGINT,
    @AuthorizationScopeId BIGINT,
    @CallerIdempotencyKey VARCHAR(128),
    @RequestFingerprint BINARY(32),
    @RequestedAtUtc DATETIME2(7),
    @AttemptNumber INT,
    @RetryOfManifestationAttemptId BIGINT = NULL,
    @ExecutorBuildId BIGINT,
    @LeaseHolderReference VARCHAR(128),
    @LeaseToken UNIQUEIDENTIFIER,
    @LeaseExpiresAtUtc DATETIME2(7),
    @StartedAtUtc DATETIME2(7),
    @TerminalAtUtc DATETIME2(7),
    @AttemptStateCode VARCHAR(32),
    @DiagnosticHash BINARY(32) = NULL,
    @RuleExecutionsJson NVARCHAR(MAX),
    @EventsJson NVARCHAR(MAX),
    @ArtifactsJson NVARCHAR(MAX)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT <> 0 THROW 54583, ''Manifestation journal append must own its transaction.'', 1;
    IF ISJSON(@RuleExecutionsJson) <> 1 OR ISJSON(@EventsJson) <> 1
       OR ISJSON(@ArtifactsJson) <> 1
        THROW 54584, ''Execution, event, and artifact journals must be JSON arrays.'', 1;
    IF @AttemptStateCode NOT IN (''succeeded'', ''failed'', ''cancelled'', ''recovery-required'')
        THROW 54585, ''The journal operation accepts only terminal attempts.'', 1;

    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @LockResult INT;
        DECLARE @LockResource NVARCHAR(255) = CONCAT(N''RRSBS:Manifestation:'',
            CONVERT(NVARCHAR(20), @AuthorizationScopeId), N'':'', @CallerIdempotencyKey);
        EXEC @LockResult = sys.sp_getapplock @Resource = @LockResource,
            @LockMode = ''Exclusive'', @LockOwner = ''Transaction'', @LockTimeout = 15000;
        IF @LockResult < 0 THROW 54586, ''Manifestation journal lock failed.'', 1;

        DECLARE @ManifestationPlanId BIGINT;
        SELECT @ManifestationPlanId = approval.ManifestationPlanId
        FROM ATAPUtilities.PlanApproval AS approval WITH (UPDLOCK, HOLDLOCK)
        WHERE approval.PlanApprovalId = @PlanApprovalId;
        IF @ManifestationPlanId IS NULL THROW 54587, ''The exact approval does not exist.'', 1;

        DECLARE @ManifestationId BIGINT;
        SELECT @ManifestationId = manifestation.ManifestationId
        FROM ATAPUtilities.Manifestation AS manifestation WITH (UPDLOCK, HOLDLOCK)
        WHERE manifestation.AuthorizationScopeId = @AuthorizationScopeId
          AND manifestation.CallerIdempotencyKey = @CallerIdempotencyKey;
        IF @ManifestationId IS NULL
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1 FROM ATAPUtilities.Entity
                WHERE EntityId = @ManifestationEntityId
                  AND EntityTypeId = @ManifestationEntityTypeId
                  AND EntityPhiloteId = @ManifestationPhiloteId
            ) THROW 54588, ''Manifestation Entity registration is missing or inexact.'', 1;
            INSERT ATAPUtilities.Manifestation
                (ManifestationPhiloteId, EntityId, EntityTypeId, ManifestationPlanId,
                 PlanApprovalId, AuthorizationScopeId, CallerIdempotencyKey,
                 RequestFingerprint, RequestedAtUtc, StateCode)
            VALUES
                (@ManifestationPhiloteId, @ManifestationEntityId, @ManifestationEntityTypeId,
                 @ManifestationPlanId, @PlanApprovalId, @AuthorizationScopeId,
                 @CallerIdempotencyKey, @RequestFingerprint, @RequestedAtUtc, ''requested'');
            SET @ManifestationId = CONVERT(BIGINT, SCOPE_IDENTITY());
        END;
        ELSE IF NOT EXISTS
        (
            SELECT 1 FROM ATAPUtilities.Manifestation
            WHERE ManifestationId = @ManifestationId
              AND ManifestationPhiloteId = @ManifestationPhiloteId
              AND ManifestationPlanId = @ManifestationPlanId
              AND PlanApprovalId = @PlanApprovalId
              AND RequestFingerprint = @RequestFingerprint
        ) THROW 54589, ''Idempotency key replay conflicts with the immutable request.'', 1;

        INSERT ATAPUtilities.ManifestationAttempt
            (ManifestationId, AttemptNumber, RetryOfManifestationAttemptId,
             ExecutorBuildId, LeaseHolderReference, LeaseToken, LeaseExpiresAtUtc,
             LastHeartbeatAtUtc, StartedAtUtc, TerminalAtUtc, StateCode, DiagnosticHash)
        VALUES
            (@ManifestationId, @AttemptNumber, @RetryOfManifestationAttemptId,
             @ExecutorBuildId, @LeaseHolderReference, @LeaseToken, @LeaseExpiresAtUtc,
             @TerminalAtUtc, @StartedAtUtc, @TerminalAtUtc, @AttemptStateCode, @DiagnosticHash);
        DECLARE @ManifestationAttemptId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());

        DECLARE @ExecutionInput TABLE
        (
            ExecutionKey UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            BuildSetRuleOccurrenceId BIGINT NOT NULL,
            BuildSetVersionId BIGINT NOT NULL,
            OccurrenceKey BINARY(32) NOT NULL,
            RuleVersionId BIGINT NOT NULL,
            ExecutionOrdinal INT NOT NULL,
            OutcomeCode VARCHAR(32) NOT NULL,
            StartedAtUtc DATETIME2(7) NOT NULL,
            FinishedAtUtc DATETIME2(7) NULL,
            ExecutionFingerprint BINARY(32) NOT NULL
        );
        INSERT @ExecutionInput
        SELECT executionRow.ExecutionKey, executionRow.BuildSetRuleOccurrenceId,
               executionRow.BuildSetVersionId,
               CONVERT(BINARY(32), executionRow.OccurrenceKeyHex, 1),
               executionRow.RuleVersionId, executionRow.ExecutionOrdinal,
               executionRow.OutcomeCode, executionRow.StartedAtUtc,
               executionRow.FinishedAtUtc,
               CONVERT(BINARY(32), executionRow.ExecutionFingerprintHex, 1)
        FROM OPENJSON(@RuleExecutionsJson)
        WITH
        (
            ExecutionKey UNIQUEIDENTIFIER ''$.executionKey'',
            BuildSetRuleOccurrenceId BIGINT ''$.buildSetRuleOccurrenceId'',
            BuildSetVersionId BIGINT ''$.buildSetVersionId'',
            OccurrenceKeyHex VARCHAR(66) ''$.occurrenceKey'',
            RuleVersionId BIGINT ''$.ruleVersionId'',
            ExecutionOrdinal INT ''$.executionOrdinal'',
            OutcomeCode VARCHAR(32) ''$.outcomeCode'',
            StartedAtUtc DATETIME2(7) ''$.startedAtUtc'',
            FinishedAtUtc DATETIME2(7) ''$.finishedAtUtc'',
            ExecutionFingerprintHex VARCHAR(66) ''$.executionFingerprint''
        ) AS executionRow;

        INSERT ATAPUtilities.RuleExecution
            (ManifestationAttemptId, BuildSetRuleOccurrenceId, BuildSetVersionId,
             OccurrenceKey, RuleVersionId, ExecutionOrdinal, ExecutorBuildId,
             LeaseHolderReference, LeaseToken, OutcomeCode, StartedAtUtc,
             FinishedAtUtc, ExecutionFingerprint)
        SELECT @ManifestationAttemptId, executionRow.BuildSetRuleOccurrenceId,
               executionRow.BuildSetVersionId, executionRow.OccurrenceKey,
               executionRow.RuleVersionId, executionRow.ExecutionOrdinal,
               @ExecutorBuildId, @LeaseHolderReference, @LeaseToken,
               executionRow.OutcomeCode, executionRow.StartedAtUtc,
               executionRow.FinishedAtUtc, executionRow.ExecutionFingerprint
        FROM @ExecutionInput AS executionRow;

        DECLARE @ExecutionMap TABLE
        (
            ExecutionKey UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
            RuleExecutionId BIGINT NOT NULL,
            RuleVersionId BIGINT NOT NULL,
            OutcomeCode VARCHAR(32) NOT NULL
        );
        INSERT @ExecutionMap
        SELECT inputRow.ExecutionKey, executionRow.RuleExecutionId,
               executionRow.RuleVersionId, executionRow.OutcomeCode
        FROM @ExecutionInput AS inputRow
        INNER JOIN ATAPUtilities.RuleExecution AS executionRow
          ON executionRow.ManifestationAttemptId = @ManifestationAttemptId
         AND executionRow.BuildSetRuleOccurrenceId = inputRow.BuildSetRuleOccurrenceId
         AND executionRow.ExecutionOrdinal = inputRow.ExecutionOrdinal;
        IF (SELECT COUNT(*) FROM @ExecutionMap) <> (SELECT COUNT(*) FROM @ExecutionInput)
            THROW 54590, ''Execution journal identity mapping is incomplete.'', 1;

        INSERT ATAPUtilities.ManifestationEvent
            (ManifestationAttemptId, EventSequence, EventKindCode, OccurredAtUtc,
             RuleExecutionId, PlanArtifactId, ErrorTaxonomyCode,
             OutboxMessageId, DiagnosticHash)
        SELECT @ManifestationAttemptId, eventRow.EventSequence, eventRow.EventKindCode,
               eventRow.OccurredAtUtc, executionMap.RuleExecutionId,
               eventRow.PlanArtifactId, eventRow.ErrorTaxonomyCode,
               eventRow.OutboxMessageId,
               CONVERT(BINARY(32), eventRow.DiagnosticHashHex, 1)
        FROM OPENJSON(@EventsJson)
        WITH
        (
            EventSequence INT ''$.eventSequence'',
            EventKindCode VARCHAR(32) ''$.eventKindCode'',
            OccurredAtUtc DATETIME2(7) ''$.occurredAtUtc'',
            ExecutionKey UNIQUEIDENTIFIER ''$.executionKey'',
            PlanArtifactId BIGINT ''$.planArtifactId'',
            ErrorTaxonomyCode VARCHAR(64) ''$.errorTaxonomyCode'',
            OutboxMessageId UNIQUEIDENTIFIER ''$.outboxMessageId'',
            DiagnosticHashHex VARCHAR(66) ''$.diagnosticHash''
        ) AS eventRow
        LEFT JOIN @ExecutionMap AS executionMap ON executionMap.ExecutionKey = eventRow.ExecutionKey;

        INSERT ATAPUtilities.ManifestationArtifact
            (ManifestationArtifactPhiloteId, EntityId, EntityTypeId,
             ManifestationId, ManifestationPlanId, ManifestationAttemptId,
             RuleExecutionId, RuleVersionId, RuleExecutionOutcomeCode,
             PlanArtifactId, ObservedCanonicalLocator, ObservedContentHash,
             ObservedByteCount, ObservedAtUtc, ArtifactStateCode,
             ReusedFromManifestationArtifactId)
        SELECT artifactRow.ManifestationArtifactPhiloteId, artifactRow.EntityId,
               artifactRow.EntityTypeId, @ManifestationId, @ManifestationPlanId,
               @ManifestationAttemptId, executionMap.RuleExecutionId,
               executionMap.RuleVersionId, executionMap.OutcomeCode,
               artifactRow.PlanArtifactId, artifactRow.ObservedCanonicalLocator,
               CONVERT(BINARY(32), artifactRow.ObservedContentHashHex, 1),
               artifactRow.ObservedByteCount, artifactRow.ObservedAtUtc,
               artifactRow.ArtifactStateCode, artifactRow.ReusedFromManifestationArtifactId
        FROM OPENJSON(@ArtifactsJson)
        WITH
        (
            ManifestationArtifactPhiloteId UNIQUEIDENTIFIER ''$.manifestationArtifactPhiloteId'',
            EntityId BIGINT ''$.entityId'',
            EntityTypeId BIGINT ''$.entityTypeId'',
            ExecutionKey UNIQUEIDENTIFIER ''$.executionKey'',
            PlanArtifactId BIGINT ''$.planArtifactId'',
            ObservedCanonicalLocator VARCHAR(1024) ''$.observedCanonicalLocator'',
            ObservedContentHashHex VARCHAR(66) ''$.observedContentHash'',
            ObservedByteCount BIGINT ''$.observedByteCount'',
            ObservedAtUtc DATETIME2(7) ''$.observedAtUtc'',
            ArtifactStateCode VARCHAR(32) ''$.artifactStateCode'',
            ReusedFromManifestationArtifactId BIGINT ''$.reusedFromManifestationArtifactId''
        ) AS artifactRow
        INNER JOIN @ExecutionMap AS executionMap ON executionMap.ExecutionKey = artifactRow.ExecutionKey;

        IF (SELECT COUNT(*) FROM ATAPUtilities.ManifestationEvent
            WHERE ManifestationAttemptId = @ManifestationAttemptId) <>
           (SELECT COUNT(*) FROM OPENJSON(@EventsJson))
            THROW 54591, ''Every supplied event must be journaled exactly once.'', 1;
        IF (SELECT COUNT(*) FROM ATAPUtilities.ManifestationArtifact
            WHERE ManifestationAttemptId = @ManifestationAttemptId) <>
           (SELECT COUNT(*) FROM OPENJSON(@ArtifactsJson))
            THROW 54592, ''Every supplied artifact must resolve to a successful execution.'', 1;
        IF NOT EXISTS
        (
            SELECT 1 FROM ATAPUtilities.ManifestationEvent
            WHERE ManifestationAttemptId = @ManifestationAttemptId
              AND EventSequence = 1 AND EventKindCode = ''attempt-started''
        ) THROW 54593, ''A terminal journal must begin with attempt-started.'', 1;
        DECLARE @ExpectedTerminalEvent VARCHAR(32) = CASE @AttemptStateCode
            WHEN ''succeeded'' THEN ''attempt-succeeded''
            WHEN ''failed'' THEN ''attempt-failed''
            WHEN ''cancelled'' THEN ''attempt-cancelled''
            ELSE ''recovery-required'' END;
        IF NOT EXISTS
        (
            SELECT 1 FROM ATAPUtilities.ManifestationEvent AS terminalEvent
            WHERE terminalEvent.ManifestationAttemptId = @ManifestationAttemptId
              AND terminalEvent.EventKindCode = @ExpectedTerminalEvent
              AND terminalEvent.EventSequence =
                  (SELECT MAX(allEvents.EventSequence)
                   FROM ATAPUtilities.ManifestationEvent AS allEvents
                   WHERE allEvents.ManifestationAttemptId = @ManifestationAttemptId)
        ) THROW 54594, ''The final event does not corroborate terminal attempt state.'', 1;

        IF @AttemptStateCode = ''succeeded''
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM ATAPUtilities.BuildSetRuleOccurrence AS occurrence
                INNER JOIN ATAPUtilities.InstantiationVersion AS versionRow
                  ON versionRow.BuildSetVersionId = occurrence.BuildSetVersionId
                INNER JOIN ATAPUtilities.ManifestationPlan AS planRow
                  ON planRow.InstantiationVersionId = versionRow.InstantiationVersionId
                WHERE planRow.ManifestationPlanId = @ManifestationPlanId
                  AND NOT EXISTS
                  (
                      SELECT 1 FROM ATAPUtilities.RuleExecution AS executionRow
                      WHERE executionRow.ManifestationAttemptId = @ManifestationAttemptId
                        AND executionRow.BuildSetRuleOccurrenceId = occurrence.BuildSetRuleOccurrenceId
                        AND executionRow.OutcomeCode = ''succeeded''
                  )
            ) THROW 54595, ''A succeeded attempt must journal every exact graph occurrence.'', 1;
            IF EXISTS
            (
                SELECT 1 FROM ATAPUtilities.PlanArtifact AS planned
                WHERE planned.ManifestationPlanId = @ManifestationPlanId
                  AND NOT EXISTS
                  (
                      SELECT 1 FROM ATAPUtilities.ManifestationArtifact AS observed
                      WHERE observed.ManifestationAttemptId = @ManifestationAttemptId
                        AND observed.PlanArtifactId = planned.PlanArtifactId
                  )
            ) THROW 54596, ''A succeeded attempt must observe every planned artifact.'', 1;
        END;
        ELSE IF EXISTS
        (
            SELECT 1 FROM ATAPUtilities.ManifestationArtifact
            WHERE ManifestationAttemptId = @ManifestationAttemptId
        ) THROW 54597, ''A non-succeeded attempt cannot publish observed artifacts.'', 1;

        COMMIT TRANSACTION;
        SELECT @ManifestationId AS ManifestationId,
               @ManifestationAttemptId AS ManifestationAttemptId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    IF DATABASE_PRINCIPAL_ID(N'RrsbsPublisher') IS NULL
        EXEC sys.sp_executesql N'CREATE ROLE RrsbsPublisher AUTHORIZATION dbo;';

    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.TargetScope TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.TargetPolicyVersion TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.ExecutorBoundary TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.LocatorPolicyVersion TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.AuthorityPolicyVersion TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.AuthorizationScope TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.ExecutorBuild TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.ManifestationPlan TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.PlanArtifact TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.PlanApproval TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.PlanApprovalStateEvent TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.Manifestation TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.ManifestationAttempt TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.RuleExecution TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.ManifestationEvent TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.ManifestationArtifact TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.ErrorTaxonomy TO RrsbsPublisher;
    DENY INSERT, UPDATE, DELETE ON OBJECT::ATAPUtilities.RuleUsage TO RrsbsPublisher;
    GRANT EXECUTE ON OBJECT::ATAPUtilities.usp_PublishManifestationPlan TO RrsbsPublisher;
    GRANT EXECUTE ON OBJECT::ATAPUtilities.usp_RecordPlanApproval TO RrsbsPublisher;
    GRANT EXECUTE ON OBJECT::ATAPUtilities.usp_AppendPlanApprovalStateEvent TO RrsbsPublisher;
    GRANT EXECUTE ON OBJECT::ATAPUtilities.usp_AppendManifestationAttemptJournal TO RrsbsPublisher;

    IF @Rdb450OwnsTransaction = 1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
        IF @Rdb450OwnsTransaction = 1 OR XACT_STATE() = -1
            ROLLBACK TRANSACTION;
        ELSE
            ROLLBACK TRANSACTION Rdb450Fragment;
    END;
    THROW;
END CATCH;

/* Optional, rollback-only fixtures. Never enabled by the baseline integrator. */
IF TRY_CONVERT(bit, SESSION_CONTEXT(N'Rdb450RunFixtures')) = 1
BEGIN
    SET XACT_ABORT OFF;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @Rdb450FixtureNow DATETIME2(7) = SYSUTCDATETIME();
        DECLARE @Rdb450FixtureCase VARCHAR(64) = COALESCE(
            TRY_CONVERT(VARCHAR(64), SESSION_CONTEXT(N'RDB450_FIXTURE_CASE')),
            'duplicate-slot');
        IF @Rdb450FixtureCase NOT IN ('duplicate-slot', 'gapped-event', 'immutable-plan')
            THROW 54545, 'Unknown RDB-450 fixture case.', 1;
        DECLARE @PlanTypeId BIGINT =
            (SELECT EntityTypeId FROM ATAPUtilities.EntityType WHERE EntityTypeCode = 'manifestation-plan');
        DECLARE @ApprovalTypeId BIGINT =
            (SELECT EntityTypeId FROM ATAPUtilities.EntityType WHERE EntityTypeCode = 'plan-approval');
        DECLARE @ManifestationTypeId BIGINT =
            (SELECT EntityTypeId FROM ATAPUtilities.EntityType WHERE EntityTypeCode = 'manifestation');
        DECLARE @Rdb450ArtifactTypeId BIGINT =
            (SELECT EntityTypeId FROM ATAPUtilities.EntityType WHERE EntityTypeCode = 'manifestation-artifact');
        IF @PlanTypeId IS NULL OR @ApprovalTypeId IS NULL OR @ManifestationTypeId IS NULL OR @Rdb450ArtifactTypeId IS NULL
            THROW 54540, 'RDB-450 fixture requires the four frozen EntityType rows.', 1;

        DECLARE @InstantiationVersionId BIGINT;
        DECLARE @Rdb450BuildSetVersionId BIGINT;
        DECLARE @OccurrenceId BIGINT;
        DECLARE @OccurrenceKey BINARY(32);
        DECLARE @Rdb450RuleVersionId BIGINT;
        SELECT TOP (1)
            @InstantiationVersionId = iv.InstantiationVersionId,
            @Rdb450BuildSetVersionId = o.BuildSetVersionId,
            @OccurrenceId = o.BuildSetRuleOccurrenceId,
            @OccurrenceKey = o.OccurrenceKey,
            @Rdb450RuleVersionId = o.RuleVersionId
        FROM ATAPUtilities.InstantiationVersion AS iv
        INNER JOIN ATAPUtilities.BuildSetRuleOccurrence AS o
          ON o.BuildSetVersionId = iv.BuildSetVersionId
        ORDER BY iv.InstantiationVersionId, o.BuildSetRuleOccurrenceId;
        IF @InstantiationVersionId IS NULL
            THROW 54541, 'RDB-450 fixture requires a compatible RDB-440 version and occurrence.', 1;

        DECLARE @Rdb450AuthorityEntityId BIGINT;
        DECLARE @AuthorityEntityTypeId BIGINT;
        SELECT TOP (1) @Rdb450AuthorityEntityId = EntityId, @AuthorityEntityTypeId = EntityTypeId
        FROM ATAPUtilities.Entity ORDER BY EntityId;

        INSERT ATAPUtilities.Entity (EntityTypeId, EntityPhiloteId, CreatedAtUtc)
        VALUES (@PlanTypeId, '45000000-0000-0000-0000-000000000001', @Rdb450FixtureNow);
        DECLARE @PlanEntityId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());
        INSERT ATAPUtilities.Entity (EntityTypeId, EntityPhiloteId, CreatedAtUtc)
        VALUES (@ApprovalTypeId, '45000000-0000-0000-0000-000000000002', @Rdb450FixtureNow);
        DECLARE @ApprovalEntityId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());
        INSERT ATAPUtilities.Entity (EntityTypeId, EntityPhiloteId, CreatedAtUtc)
        VALUES (@ManifestationTypeId, '45000000-0000-0000-0000-000000000003', @Rdb450FixtureNow);
        DECLARE @ManifestationEntityId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());
        INSERT ATAPUtilities.Entity (EntityTypeId, EntityPhiloteId, CreatedAtUtc)
        VALUES (@Rdb450ArtifactTypeId, '45000000-0000-0000-0000-000000000004', @Rdb450FixtureNow);
        DECLARE @ArtifactEntityId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());

        DECLARE @GraphHash BINARY(32) = HASHBYTES('SHA2_256', 'RDB-450-graph');
        DECLARE @InputHash BINARY(32) = HASHBYTES('SHA2_256', 'RDB-450-input');
        DECLARE @PlanFingerprint BINARY(32) = HASHBYTES('SHA2_256', 'RDB-450-plan');
        DECLARE @ExpectedHash BINARY(32) = HASHBYTES('SHA2_256', 'RDB-450-output');

        INSERT ATAPUtilities.ManifestationPlan
            (ManifestationPlanPhiloteId, EntityId, EntityTypeId, InstantiationVersionId,
             GraphSelectorHash, SelectedInputSnapshotHash, TargetScopeId,
             TargetPolicyVersionId, ExecutorBoundaryId, HashAlgorithmCode,
             PlanFingerprint, PlannedAtUtc)
        VALUES ('45000000-0000-0000-0000-000000000001', @PlanEntityId, @PlanTypeId,
                @InstantiationVersionId, @GraphHash, @InputHash, 450001, 450002,
                450003, 'sha256', @PlanFingerprint, @Rdb450FixtureNow);
        DECLARE @PlanId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());

        INSERT ATAPUtilities.PlanArtifact
            (ManifestationPlanId, SlotOrdinal, CanonicalLocator, LocatorPolicyVersionId,
             EffectClassCode, ExpectedContentHash, ExpectedByteCount, TargetScopeId)
        VALUES (@PlanId, 0, 'rdb450://fixture/output', 450004, 'create',
                @ExpectedHash, 8, 450001);
        DECLARE @PlanArtifactId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());

        INSERT ATAPUtilities.PlanApproval
            (PlanApprovalPhiloteId, EntityId, EntityTypeId, ManifestationPlanId,
             InstantiationVersionId, GraphSelectorHash, SelectedInputSnapshotHash,
             TargetScopeId, TargetPolicyVersionId, ExecutorBoundaryId,
             HashAlgorithmCode, PlanFingerprint, AuthorityEntityId,
             AuthorityEntityTypeId, AuthorityPolicyVersionId, DecisionCode,
             DecidedAtUtc, ExpiresAtUtc)
        VALUES ('45000000-0000-0000-0000-000000000002', @ApprovalEntityId,
                @ApprovalTypeId, @PlanId, @InstantiationVersionId, @GraphHash,
                @InputHash, 450001, 450002, 450003, 'sha256', @PlanFingerprint,
                @Rdb450AuthorityEntityId, @AuthorityEntityTypeId, 450005, 'approved',
                @Rdb450FixtureNow, DATEADD(hour, 1, @Rdb450FixtureNow));
        DECLARE @ApprovalId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());

        INSERT ATAPUtilities.Manifestation
            (ManifestationPhiloteId, EntityId, EntityTypeId, ManifestationPlanId,
             PlanApprovalId, AuthorizationScopeId, CallerIdempotencyKey,
             RequestFingerprint, RequestedAtUtc, StateCode)
        VALUES ('45000000-0000-0000-0000-000000000003', @ManifestationEntityId,
                @ManifestationTypeId, @PlanId, @ApprovalId, 450006,
                'rdb450.fixture', HASHBYTES('SHA2_256', 'RDB-450-request'),
                @Rdb450FixtureNow, 'requested');
        DECLARE @ManifestationId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());

        INSERT ATAPUtilities.ManifestationAttempt
            (ManifestationId, AttemptNumber, RetryOfManifestationAttemptId,
             ExecutorBuildId, LeaseHolderReference, LeaseToken, LeaseExpiresAtUtc,
             LastHeartbeatAtUtc, StartedAtUtc, TerminalAtUtc, StateCode,
             DiagnosticHash)
        VALUES (@ManifestationId, 1, NULL, 450007, 'rdb450-fixture',
                '45000000-0000-0000-0000-000000000005',
                DATEADD(minute, 10, @Rdb450FixtureNow), @Rdb450FixtureNow, @Rdb450FixtureNow,
                DATEADD(second, 1, @Rdb450FixtureNow), 'succeeded', NULL);
        DECLARE @AttemptId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());

        INSERT ATAPUtilities.RuleExecution
            (ManifestationAttemptId, BuildSetRuleOccurrenceId, BuildSetVersionId,
             OccurrenceKey, RuleVersionId, ExecutionOrdinal, ExecutorBuildId,
             LeaseHolderReference, LeaseToken, OutcomeCode, StartedAtUtc,
             FinishedAtUtc, ExecutionFingerprint)
        VALUES (@AttemptId, @OccurrenceId, @Rdb450BuildSetVersionId, @OccurrenceKey,
                @Rdb450RuleVersionId, 0, 450007, 'rdb450-fixture',
                '45000000-0000-0000-0000-000000000005', 'succeeded', @Rdb450FixtureNow,
                DATEADD(millisecond, 500, @Rdb450FixtureNow),
                HASHBYTES('SHA2_256', 'RDB-450-execution'));
        DECLARE @ExecutionId BIGINT = CONVERT(BIGINT, SCOPE_IDENTITY());

        INSERT ATAPUtilities.ErrorTaxonomy
            (ErrorTaxonomyCode, CategoryCode, RetryDispositionCode, SafetyClassCode,
             SupersedesErrorTaxonomyCode, RetiredAtUtc)
        VALUES ('rdb450.fixture', 'validation', 'never', 'no-effect', NULL, NULL);

        INSERT ATAPUtilities.ManifestationEvent
            (ManifestationAttemptId, EventSequence, EventKindCode, OccurredAtUtc,
             RuleExecutionId, PlanArtifactId, ErrorTaxonomyCode, OutboxMessageId,
             DiagnosticHash)
        VALUES (@AttemptId, 1, 'rule-succeeded', DATEADD(millisecond, 500, @Rdb450FixtureNow),
                @ExecutionId, NULL, NULL, NULL, NULL);

        INSERT ATAPUtilities.ManifestationArtifact
            (ManifestationArtifactPhiloteId, EntityId, EntityTypeId,
             ManifestationId, ManifestationPlanId, ManifestationAttemptId,
             RuleExecutionId, RuleVersionId, RuleExecutionOutcomeCode,
             PlanArtifactId, ObservedCanonicalLocator, ObservedContentHash,
             ObservedByteCount, ObservedAtUtc, ArtifactStateCode,
             ReusedFromManifestationArtifactId)
        VALUES ('45000000-0000-0000-0000-000000000004', @ArtifactEntityId,
                @Rdb450ArtifactTypeId, @ManifestationId, @PlanId, @AttemptId,
                @ExecutionId, @Rdb450RuleVersionId, 'succeeded', @PlanArtifactId,
                'rdb450://fixture/output', @ExpectedHash, 8,
                DATEADD(second, 1, @Rdb450FixtureNow), 'produced', NULL);

        DECLARE @SubjectEntityId BIGINT;
        DECLARE @SubjectEntityTypeId BIGINT;
        SELECT @SubjectEntityId = EntityId, @SubjectEntityTypeId = EntityTypeId
        FROM ATAPUtilities.RuleVersion WHERE RuleVersionId = @Rdb450RuleVersionId;
        INSERT ATAPUtilities.RuleUsage
            (SubjectEntityId, SubjectEntityTypeId, SubjectVersionId,
             SubjectVersionEntityTypeId, RuleVersionId, UsageRoleCode,
             ProvenanceKindCode, ManifestationPlanId, ManifestationAttemptId,
             RuleExecutionId, RecordedAtUtc, UsageFingerprint)
        VALUES (@SubjectEntityId, @SubjectEntityTypeId, @SubjectEntityId,
                @SubjectEntityTypeId, @Rdb450RuleVersionId, 'execution', 'observed',
                NULL, @AttemptId, @ExecutionId, DATEADD(second, 1, @Rdb450FixtureNow),
                HASHBYTES('SHA2_256', 'RDB-450-usage'));

        /* Each trigger-rejection case runs in its own fresh transaction. */
        IF @Rdb450FixtureCase = 'duplicate-slot'
        BEGIN
        BEGIN TRY
            INSERT ATAPUtilities.PlanArtifact
                (ManifestationPlanId, SlotOrdinal, CanonicalLocator,
                 LocatorPolicyVersionId, EffectClassCode, ExpectedContentHash,
                 ExpectedByteCount, TargetScopeId)
            VALUES (@PlanId, 0, 'rdb450://fixture/duplicate', 450004, 'create',
                    @ExpectedHash, 8, 450001);
            THROW 54542, 'Expected duplicate slot rejection did not occur.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 54542 THROW;
            IF ERROR_NUMBER() NOT IN (2601, 2627) THROW;
        END CATCH;
        END;

        IF @Rdb450FixtureCase = 'gapped-event'
        BEGIN
        BEGIN TRY
            INSERT ATAPUtilities.ManifestationEvent
                (ManifestationAttemptId, EventSequence, EventKindCode, OccurredAtUtc)
            VALUES (@AttemptId, 3, 'lease-heartbeat', DATEADD(second, 2, @Rdb450FixtureNow));
            THROW 54543, 'Expected gapped event rejection did not occur.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 54543 THROW;
            IF ERROR_NUMBER() <> 54526 THROW;
        END CATCH;
        END;

        IF @Rdb450FixtureCase = 'immutable-plan'
        BEGIN
        BEGIN TRY
            UPDATE ATAPUtilities.ManifestationPlan
            SET PlannedAtUtc = DATEADD(second, 1, PlannedAtUtc)
            WHERE ManifestationPlanId = @PlanId;
            THROW 54544, 'Expected immutable update rejection did not occur.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 54544 THROW;
            IF ERROR_NUMBER() <> 54501 THROW;
        END CATCH;
        END;

        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
    SET XACT_ABORT ON;
END;

/* Source-static postconditions; RDB-480 repeats these after integration. */
IF (SELECT COUNT_BIG(*) FROM sys.tables
    WHERE schema_id = SCHEMA_ID(N'ATAPUtilities')
      AND name IN
      (N'TargetScope', N'TargetPolicyVersion', N'ExecutorBoundary',
       N'LocatorPolicyVersion', N'AuthorityPolicyVersion', N'AuthorizationScope',
       N'ExecutorBuild', N'ManifestationPlan', N'PlanArtifact', N'PlanApproval',
       N'PlanApprovalStateEvent', N'Manifestation', N'ManifestationAttempt',
       N'RuleExecution', N'ManifestationEvent', N'ManifestationArtifact',
       N'ErrorTaxonomy', N'RuleUsage')) <> 18
    THROW 54550, 'RDB-450 table postcondition failed.', 1;

IF (SELECT COUNT_BIG(*) FROM sys.triggers
    WHERE parent_id IN
    (OBJECT_ID(N'ATAPUtilities.TargetScope'),
     OBJECT_ID(N'ATAPUtilities.TargetPolicyVersion'),
     OBJECT_ID(N'ATAPUtilities.ExecutorBoundary'),
     OBJECT_ID(N'ATAPUtilities.LocatorPolicyVersion'),
     OBJECT_ID(N'ATAPUtilities.AuthorityPolicyVersion'),
     OBJECT_ID(N'ATAPUtilities.AuthorizationScope'),
     OBJECT_ID(N'ATAPUtilities.ExecutorBuild'),
     OBJECT_ID(N'ATAPUtilities.ManifestationPlan'),
     OBJECT_ID(N'ATAPUtilities.PlanArtifact'),
     OBJECT_ID(N'ATAPUtilities.PlanApproval'),
     OBJECT_ID(N'ATAPUtilities.PlanApprovalStateEvent'),
     OBJECT_ID(N'ATAPUtilities.Manifestation'),
     OBJECT_ID(N'ATAPUtilities.ManifestationAttempt'),
     OBJECT_ID(N'ATAPUtilities.RuleExecution'),
     OBJECT_ID(N'ATAPUtilities.ManifestationEvent'),
     OBJECT_ID(N'ATAPUtilities.ManifestationArtifact'),
     OBJECT_ID(N'ATAPUtilities.ErrorTaxonomy'),
     OBJECT_ID(N'ATAPUtilities.RuleUsage'))
      AND is_disabled = 0) <> 24
    THROW 54551, 'RDB-450 trigger postcondition failed.', 1;

IF (SELECT COUNT_BIG(*) FROM sys.procedures
    WHERE schema_id = SCHEMA_ID(N'ATAPUtilities')
      AND name IN (N'usp_PublishManifestationPlan', N'usp_RecordPlanApproval',
                   N'usp_AppendPlanApprovalStateEvent',
                   N'usp_AppendManifestationAttemptJournal')) <> 4
    THROW 54598, 'RDB-450 trusted-operation postcondition failed.', 1;

IF (SELECT COUNT_BIG(*) FROM sys.database_permissions AS permissionRow
    WHERE permissionRow.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'RrsbsPublisher')
      AND permissionRow.state = 'D'
      AND permissionRow.permission_name IN ('INSERT', 'UPDATE', 'DELETE')
      AND permissionRow.major_id IN
      (OBJECT_ID(N'ATAPUtilities.TargetScope'), OBJECT_ID(N'ATAPUtilities.TargetPolicyVersion'),
       OBJECT_ID(N'ATAPUtilities.ExecutorBoundary'), OBJECT_ID(N'ATAPUtilities.LocatorPolicyVersion'),
       OBJECT_ID(N'ATAPUtilities.AuthorityPolicyVersion'), OBJECT_ID(N'ATAPUtilities.AuthorizationScope'),
       OBJECT_ID(N'ATAPUtilities.ExecutorBuild'), OBJECT_ID(N'ATAPUtilities.ManifestationPlan'),
       OBJECT_ID(N'ATAPUtilities.PlanArtifact'), OBJECT_ID(N'ATAPUtilities.PlanApproval'),
       OBJECT_ID(N'ATAPUtilities.PlanApprovalStateEvent'), OBJECT_ID(N'ATAPUtilities.Manifestation'),
       OBJECT_ID(N'ATAPUtilities.ManifestationAttempt'), OBJECT_ID(N'ATAPUtilities.RuleExecution'),
       OBJECT_ID(N'ATAPUtilities.ManifestationEvent'), OBJECT_ID(N'ATAPUtilities.ManifestationArtifact'),
       OBJECT_ID(N'ATAPUtilities.ErrorTaxonomy'), OBJECT_ID(N'ATAPUtilities.RuleUsage'))) <> 54
    THROW 54599, 'RDB-450 publisher direct-DML denial postcondition failed.', 1;
/* END INTEGRATED FRAGMENT: RDB-450__Manifestation-Plan-Approval-Event.sql */

/* BEGIN INTEGRATED FRAGMENT: RDB-460-470__Context-Content-Retained.sql */
/*
  RDB-460/470 context, content-summary, projection, and retained-object fragment.
  Target: SQL Server 2022 / TSql160.

  Integration contract:
  - RDB-480 selects the target database and runs RDB-400/410, RDB-420, and
    RDB-450 (which owns ErrorTaxonomy) first.
  - This fragment contains no USE, database, login, Flyway-history, or destructive DDL.
  - DDL joins a caller transaction through a savepoint and never commits that caller.
  - Fixtures are opt-in through SESSION_CONTEXT('RRSBS_RUN_RDB460_FIXTURES') = 1,
    operate only on disposable rows, and always roll back.
  - ExternalReference, the five policy kinds, and projection-selected-summary
    relational closure are owned and enforced by this fragment.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Rdb460OwnsTransaction bit = 0;
IF @@TRANCOUNT = 0
BEGIN
    BEGIN TRANSACTION;
    SET @Rdb460OwnsTransaction = 1;
END;
ELSE
    SAVE TRANSACTION Rdb460Fragment;

BEGIN TRY
    IF SCHEMA_ID(N'Tags') IS NULL EXEC sys.sp_executesql N'CREATE SCHEMA [Tags]';
    IF SCHEMA_ID(N'Gmail') IS NULL EXEC sys.sp_executesql N'CREATE SCHEMA [Gmail]';

    /* RDB-260: repository and source-context model. */
    IF OBJECT_ID(N'[ATAPUtilities].[PolicyVersion]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[PolicyVersion]
        (
            [PolicyVersionId] bigint IDENTITY(1,1) NOT NULL,
            [PolicyKindCode] varchar(32) NOT NULL,
            [PolicyCode] varchar(128) NOT NULL,
            [RevisionSequence] int NOT NULL,
            [PredecessorPolicyVersionId] bigint NULL,
            [PolicyContractHash] binary(32) NOT NULL,
            [PublishedAtUtc] datetime2(7) NOT NULL,
            CONSTRAINT [PK_PolicyVersion] PRIMARY KEY CLUSTERED ([PolicyVersionId]),
            CONSTRAINT [UQ_PolicyVersion_Id_Kind] UNIQUE ([PolicyVersionId], [PolicyKindCode]),
            CONSTRAINT [UQ_PolicyVersion_Id_Kind_Code] UNIQUE ([PolicyVersionId], [PolicyKindCode], [PolicyCode]),
            CONSTRAINT [UQ_PolicyVersion_Kind_Code_Revision] UNIQUE ([PolicyKindCode], [PolicyCode], [RevisionSequence]),
            CONSTRAINT [FK_PolicyVersion_PredecessorExactPolicy] FOREIGN KEY
                ([PredecessorPolicyVersionId], [PolicyKindCode], [PolicyCode])
                REFERENCES [ATAPUtilities].[PolicyVersion] ([PolicyVersionId], [PolicyKindCode], [PolicyCode]),
            CONSTRAINT [CK_PolicyVersion_Kind] CHECK
                ([PolicyKindCode] IN ('classification', 'selection', 'redaction', 'acceptance', 'projection-owner')),
            CONSTRAINT [CK_PolicyVersion_Revision] CHECK
                (([RevisionSequence] = 1 AND [PredecessorPolicyVersionId] IS NULL)
                 OR ([RevisionSequence] > 1 AND [PredecessorPolicyVersionId] IS NOT NULL))
        );
        CREATE UNIQUE INDEX [UX_PolicyVersion_Predecessor]
            ON [ATAPUtilities].[PolicyVersion] ([PredecessorPolicyVersionId])
            WHERE [PredecessorPolicyVersionId] IS NOT NULL;
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[ExternalReference]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[ExternalReference]
        (
            [ExternalReferenceId] bigint IDENTITY(1,1) NOT NULL,
            [AuthorityEntityId] bigint NOT NULL,
            [AuthorityEntityTypeId] bigint NOT NULL,
            [ReferenceKindCode] varchar(32) NOT NULL,
            [SchemeCode] varchar(32) NULL,
            [CanonicalIdentity] nvarchar(2048) COLLATE Latin1_General_100_BIN2 NULL,
            [CanonicalIdentityHash] binary(32) NULL,
            [ContentHashAlgorithmCode] varchar(16) NULL,
            [ContentHash] binary(32) NULL,
            [NormalizerIdentityReference] nvarchar(512) NOT NULL,
            [EvidenceIdentityReference] nvarchar(2048) NOT NULL,
            [PublishedAtUtc] datetime2(7) NOT NULL,
            CONSTRAINT [PK_ExternalReference] PRIMARY KEY CLUSTERED ([ExternalReferenceId]),
            CONSTRAINT [FK_ExternalReference_Authority] FOREIGN KEY ([AuthorityEntityId], [AuthorityEntityTypeId])
                REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
            CONSTRAINT [CK_ExternalReference_Kind] CHECK
                ([ReferenceKindCode] IN ('canonical-uri', 'opaque', 'content-hash')),
            CONSTRAINT [CK_ExternalReference_DiscriminatedIdentity] CHECK
                (([ReferenceKindCode] IN ('canonical-uri', 'opaque')
                  AND [SchemeCode] IS NOT NULL AND [CanonicalIdentity] IS NOT NULL
                  AND [CanonicalIdentityHash] IS NOT NULL
                  AND [ContentHashAlgorithmCode] IS NULL AND [ContentHash] IS NULL)
                 OR ([ReferenceKindCode] = 'content-hash'
                     AND [SchemeCode] IS NULL AND [CanonicalIdentity] IS NULL
                     AND [CanonicalIdentityHash] IS NULL
                     AND [ContentHashAlgorithmCode] = 'sha256' AND [ContentHash] IS NOT NULL)),
            CONSTRAINT [CK_ExternalReference_Evidence] CHECK
                (LEN([NormalizerIdentityReference]) > 0 AND LEN([EvidenceIdentityReference]) > 0
                 AND ([SchemeCode] IS NULL OR ([SchemeCode] = LOWER([SchemeCode])
                      AND [SchemeCode] NOT LIKE '%[^a-z0-9+.-]%')))
        );
        CREATE UNIQUE INDEX [UX_ExternalReference_CanonicalIdentityHash]
            ON [ATAPUtilities].[ExternalReference]
                ([AuthorityEntityId], [AuthorityEntityTypeId], [ReferenceKindCode], [SchemeCode], [CanonicalIdentityHash])
            WHERE [CanonicalIdentityHash] IS NOT NULL;
        CREATE UNIQUE INDEX [UX_ExternalReference_ContentHash]
            ON [ATAPUtilities].[ExternalReference]
                ([AuthorityEntityId], [AuthorityEntityTypeId], [ReferenceKindCode], [ContentHash])
            WHERE [ContentHash] IS NOT NULL;
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[Organization]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[Organization]
        (
            [OrganizationId] bigint IDENTITY(1,1) NOT NULL,
            [OrganizationPhiloteId] uniqueidentifier NOT NULL,
            [EntityId] bigint NOT NULL,
            [EntityTypeId] bigint NOT NULL,
            [EntityTypeCode] AS CONVERT(varchar(64), 'organization') PERSISTED,
            [CanonicalName] nvarchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
            [ClassificationPolicyVersionId] bigint NOT NULL,
            [ClassificationPolicyKindCode] AS CONVERT(varchar(32), 'classification') PERSISTED,
            [CreatedAtUtc] datetime2(7) NOT NULL,
            [RetiredAtUtc] datetime2(7) NULL,
            CONSTRAINT [PK_Organization] PRIMARY KEY CLUSTERED ([OrganizationId]),
            CONSTRAINT [UQ_Organization_Philote] UNIQUE ([OrganizationPhiloteId]),
            CONSTRAINT [UQ_Organization_Entity] UNIQUE ([EntityId], [EntityTypeId]),
            CONSTRAINT [UQ_Organization_CanonicalName] UNIQUE ([CanonicalName]),
            CONSTRAINT [FK_Organization_Entity] FOREIGN KEY ([EntityId], [EntityTypeId], [OrganizationPhiloteId])
                REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
            CONSTRAINT [FK_Organization_EntityType] FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
                REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
            CONSTRAINT [FK_Organization_ClassificationPolicy] FOREIGN KEY
                ([ClassificationPolicyVersionId], [ClassificationPolicyKindCode])
                REFERENCES [ATAPUtilities].[PolicyVersion] ([PolicyVersionId], [PolicyKindCode]),
            CONSTRAINT [CK_Organization_Name] CHECK (LEN([CanonicalName]) > 0),
            CONSTRAINT [CK_Organization_Lifetime] CHECK ([RetiredAtUtc] IS NULL OR [RetiredAtUtc] >= [CreatedAtUtc])
        );
    END;

    /* RDB-260: safe content-summary and agent-text projection model. */
    IF OBJECT_ID(N'[ATAPUtilities].[ContentSummary]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[ContentSummary]
        (
            [ContentSummaryId] bigint IDENTITY(1,1) NOT NULL,
            [ContentSummaryPhiloteId] uniqueidentifier NOT NULL,
            [EntityId] bigint NOT NULL,
            [EntityTypeId] bigint NOT NULL,
            [EntityTypeCode] AS CONVERT(varchar(64), 'content-summary') PERSISTED,
            [SourceArtifactId] bigint NOT NULL,
            [SummaryProfileCode] varchar(128) NOT NULL,
            [ClassificationPolicyVersionId] bigint NOT NULL,
            [ClassificationPolicyKindCode] AS CONVERT(varchar(32), 'classification') PERSISTED,
            [CreatedAtUtc] datetime2(7) NOT NULL,
            [RetiredAtUtc] datetime2(7) NULL,
            CONSTRAINT [PK_ContentSummary] PRIMARY KEY CLUSTERED ([ContentSummaryId]),
            CONSTRAINT [UQ_ContentSummary_Philote] UNIQUE ([ContentSummaryPhiloteId]),
            CONSTRAINT [UQ_ContentSummary_Entity] UNIQUE ([EntityId], [EntityTypeId]),
            CONSTRAINT [UQ_ContentSummary_Id_Artifact_Policy] UNIQUE
                ([ContentSummaryId], [SourceArtifactId], [ClassificationPolicyVersionId]),
            CONSTRAINT [UQ_ContentSummary_Artifact_Profile_Policy] UNIQUE
                ([SourceArtifactId], [SummaryProfileCode], [ClassificationPolicyVersionId]),
            CONSTRAINT [FK_ContentSummary_Entity] FOREIGN KEY ([EntityId], [EntityTypeId], [ContentSummaryPhiloteId])
                REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
            CONSTRAINT [FK_ContentSummary_EntityType] FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
                REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
            CONSTRAINT [FK_ContentSummary_ClassificationPolicy] FOREIGN KEY
                ([ClassificationPolicyVersionId], [ClassificationPolicyKindCode])
                REFERENCES [ATAPUtilities].[PolicyVersion] ([PolicyVersionId], [PolicyKindCode]),
            CONSTRAINT [CK_ContentSummary_Profile] CHECK (LEN([SummaryProfileCode]) > 0),
            CONSTRAINT [CK_ContentSummary_Lifetime] CHECK ([RetiredAtUtc] IS NULL OR [RetiredAtUtc] >= [CreatedAtUtc])
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[ContentSummaryVersion]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[ContentSummaryVersion]
        (
            [ContentSummaryVersionId] bigint IDENTITY(1,1) NOT NULL,
            [ContentSummaryId] bigint NOT NULL,
            [SourceArtifactId] bigint NOT NULL,
            [SourceArtifactVersionId] bigint NOT NULL,
            [ClassificationPolicyVersionId] bigint NOT NULL,
            [ClassificationPolicyKindCode] AS CONVERT(varchar(32), 'classification') PERSISTED,
            [VersionSequence] bigint NOT NULL,
            [PredecessorContentSummaryVersionId] bigint NULL,
            [LifecycleStateCode] varchar(16) NOT NULL,
            [PromptRuleVersionId] bigint NULL,
            [GeneratorIdentityReference] nvarchar(512) NULL,
            [GeneratorModelIdentity] nvarchar(512) NULL,
            [RedactionPolicyVersionId] bigint NULL,
            [RedactionPolicyKindCode] AS CONVERT(varchar(32), 'redaction') PERSISTED,
            [ExclusionEvidenceReference] nvarchar(2048) NULL,
            [SafeSummaryContentHash] binary(32) NULL,
            [SafeRenderedText] nvarchar(max) NULL,
            [GeneratedAtUtc] datetime2(7) NOT NULL,
            CONSTRAINT [PK_ContentSummaryVersion] PRIMARY KEY CLUSTERED ([ContentSummaryVersionId]),
            CONSTRAINT [UQ_ContentSummaryVersion_Id_Summary] UNIQUE
                ([ContentSummaryVersionId], [ContentSummaryId]),
            CONSTRAINT [UQ_ContentSummaryVersion_Summary_Sequence] UNIQUE
                ([ContentSummaryId], [VersionSequence]),
            CONSTRAINT [FK_ContentSummaryVersion_SummaryExact] FOREIGN KEY
                ([ContentSummaryId], [SourceArtifactId], [ClassificationPolicyVersionId])
                REFERENCES [ATAPUtilities].[ContentSummary]
                    ([ContentSummaryId], [SourceArtifactId], [ClassificationPolicyVersionId]),
            CONSTRAINT [FK_ContentSummaryVersion_PredecessorSameSummary] FOREIGN KEY
                ([PredecessorContentSummaryVersionId], [ContentSummaryId])
                REFERENCES [ATAPUtilities].[ContentSummaryVersion]
                    ([ContentSummaryVersionId], [ContentSummaryId]),
            CONSTRAINT [FK_ContentSummaryVersion_PromptRuleVersion] FOREIGN KEY ([PromptRuleVersionId])
                REFERENCES [ATAPUtilities].[RuleVersion] ([RuleVersionId]),
            CONSTRAINT [FK_ContentSummaryVersion_ClassificationPolicy] FOREIGN KEY
                ([ClassificationPolicyVersionId], [ClassificationPolicyKindCode])
                REFERENCES [ATAPUtilities].[PolicyVersion] ([PolicyVersionId], [PolicyKindCode]),
            CONSTRAINT [FK_ContentSummaryVersion_RedactionPolicy] FOREIGN KEY
                ([RedactionPolicyVersionId], [RedactionPolicyKindCode])
                REFERENCES [ATAPUtilities].[PolicyVersion] ([PolicyVersionId], [PolicyKindCode]),
            CONSTRAINT [CK_ContentSummaryVersion_Sequence] CHECK ([VersionSequence] > 0),
            CONSTRAINT [CK_ContentSummaryVersion_State] CHECK
                ([LifecycleStateCode] IN ('harvested', 'summarized', 'stale', 'excluded', 'retired')),
            CONSTRAINT [CK_ContentSummaryVersion_Predecessor] CHECK
                (([VersionSequence] = 1 AND [PredecessorContentSummaryVersionId] IS NULL)
                 OR ([VersionSequence] > 1 AND [PredecessorContentSummaryVersionId] IS NOT NULL)),
            CONSTRAINT [CK_ContentSummaryVersion_PredecessorNotSelf] CHECK
                ([PredecessorContentSummaryVersionId] IS NULL
                 OR [PredecessorContentSummaryVersionId] <> [ContentSummaryVersionId]),
            CONSTRAINT [CK_ContentSummaryVersion_StateShape] CHECK
                (([LifecycleStateCode] = 'harvested'
                  AND [PromptRuleVersionId] IS NULL AND [GeneratorIdentityReference] IS NULL
                  AND [GeneratorModelIdentity] IS NULL AND [RedactionPolicyVersionId] IS NULL
                  AND [ExclusionEvidenceReference] IS NULL
                  AND [SafeSummaryContentHash] IS NULL AND [SafeRenderedText] IS NULL)
                 OR ([LifecycleStateCode] = 'summarized'
                     AND [PromptRuleVersionId] IS NOT NULL AND [GeneratorIdentityReference] IS NOT NULL
                     AND [GeneratorModelIdentity] IS NOT NULL AND [RedactionPolicyVersionId] IS NOT NULL
                     AND [ExclusionEvidenceReference] IS NULL
                     AND ([SafeSummaryContentHash] IS NOT NULL OR [SafeRenderedText] IS NOT NULL))
                 OR ([LifecycleStateCode] = 'excluded'
                     AND [PromptRuleVersionId] IS NULL AND [GeneratorIdentityReference] IS NULL
                     AND [GeneratorModelIdentity] IS NULL AND [ExclusionEvidenceReference] IS NOT NULL
                     AND [SafeSummaryContentHash] IS NULL AND [SafeRenderedText] IS NULL)
                 OR ([LifecycleStateCode] IN ('stale', 'retired')
                     AND [PredecessorContentSummaryVersionId] IS NOT NULL
                     AND [ExclusionEvidenceReference] IS NULL
                     AND [SafeSummaryContentHash] IS NULL AND [SafeRenderedText] IS NULL)),
            CONSTRAINT [CK_ContentSummaryVersion_IdentityText] CHECK
                (([GeneratorIdentityReference] IS NULL OR LEN([GeneratorIdentityReference]) > 0)
                 AND ([GeneratorModelIdentity] IS NULL OR LEN([GeneratorModelIdentity]) > 0))
        );
        CREATE UNIQUE INDEX [UX_ContentSummaryVersion_Predecessor]
            ON [ATAPUtilities].[ContentSummaryVersion] ([PredecessorContentSummaryVersionId])
            WHERE [PredecessorContentSummaryVersionId] IS NOT NULL;
        CREATE INDEX [IX_ContentSummaryVersion_SourceVersion]
            ON [ATAPUtilities].[ContentSummaryVersion] ([SourceArtifactVersionId]);
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[ContentSummaryDependency]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[ContentSummaryDependency]
        (
            [ContentSummaryDependencyId] bigint IDENTITY(1,1) NOT NULL,
            [ContentSummaryVersionId] bigint NOT NULL,
            [DependencyOrdinal] int NOT NULL,
            [DependencyKindCode] varchar(64) NOT NULL,
            [SourceArtifactVersionId] bigint NULL,
            [ExternalReferenceId] bigint NULL,
            [ExternalReferenceEvidenceReference] nvarchar(2048) NULL,
            [CapturedAtUtc] datetime2(7) NOT NULL,
            [EvidenceIdentityReference] nvarchar(2048) NOT NULL,
            CONSTRAINT [PK_ContentSummaryDependency] PRIMARY KEY CLUSTERED ([ContentSummaryDependencyId]),
            CONSTRAINT [UQ_ContentSummaryDependency_Version_Ordinal] UNIQUE
                ([ContentSummaryVersionId], [DependencyOrdinal]),
            CONSTRAINT [FK_ContentSummaryDependency_SummaryVersion] FOREIGN KEY ([ContentSummaryVersionId])
                REFERENCES [ATAPUtilities].[ContentSummaryVersion] ([ContentSummaryVersionId]),
            CONSTRAINT [CK_ContentSummaryDependency_Ordinal] CHECK ([DependencyOrdinal] >= 0),
            CONSTRAINT [CK_ContentSummaryDependency_Kind] CHECK (LEN([DependencyKindCode]) > 0),
            CONSTRAINT [CK_ContentSummaryDependency_ExactlyOneTarget] CHECK
                ((CASE WHEN [SourceArtifactVersionId] IS NULL THEN 0 ELSE 1 END)
                 + (CASE WHEN [ExternalReferenceId] IS NULL THEN 0 ELSE 1 END) = 1),
            CONSTRAINT [CK_ContentSummaryDependency_ExternalEvidence] CHECK
                (([ExternalReferenceId] IS NULL AND [ExternalReferenceEvidenceReference] IS NULL)
                 OR ([ExternalReferenceId] IS NOT NULL AND [ExternalReferenceEvidenceReference] IS NOT NULL)),
            CONSTRAINT [CK_ContentSummaryDependency_Evidence] CHECK (LEN([EvidenceIdentityReference]) > 0)
        );
        CREATE INDEX [IX_ContentSummaryDependency_SourceVersion]
            ON [ATAPUtilities].[ContentSummaryDependency] ([SourceArtifactVersionId]);
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[AgentTextProjection]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[AgentTextProjection]
        (
            [AgentTextProjectionId] bigint IDENTITY(1,1) NOT NULL,
            [AgentTextProjectionPhiloteId] uniqueidentifier NOT NULL,
            [EntityId] bigint NOT NULL,
            [EntityTypeId] bigint NOT NULL,
            [EntityTypeCode] AS CONVERT(varchar(64), 'agent-text-projection') PERSISTED,
            [ProjectionName] nvarchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
            [ConsumerClassCode] varchar(128) NOT NULL,
            [ProjectionContractVersion] int NOT NULL,
            [ProjectionSchemaVersion] int NOT NULL,
            [SelectionPolicyVersionId] bigint NOT NULL,
            [SelectionPolicyKindCode] AS CONVERT(varchar(32), 'selection') PERSISTED,
            [RenderingRuleVersionId] bigint NOT NULL,
            [ClassificationPolicyVersionId] bigint NOT NULL,
            [ClassificationPolicyKindCode] AS CONVERT(varchar(32), 'classification') PERSISTED,
            [OwnerEntityId] bigint NOT NULL,
            [OwnerEntityTypeId] bigint NOT NULL,
            [OwnerPolicyVersionId] bigint NOT NULL,
            [OwnerPolicyKindCode] AS CONVERT(varchar(32), 'projection-owner') PERSISTED,
            [CreatedAtUtc] datetime2(7) NOT NULL,
            [RetiredAtUtc] datetime2(7) NULL,
            CONSTRAINT [PK_AgentTextProjection] PRIMARY KEY CLUSTERED ([AgentTextProjectionId]),
            CONSTRAINT [UQ_AgentTextProjection_Philote] UNIQUE ([AgentTextProjectionPhiloteId]),
            CONSTRAINT [UQ_AgentTextProjection_Entity] UNIQUE ([EntityId], [EntityTypeId]),
            CONSTRAINT [UQ_AgentTextProjection_ExactPolicies] UNIQUE
                ([AgentTextProjectionId], [RenderingRuleVersionId], [SelectionPolicyVersionId],
                 [ClassificationPolicyVersionId], [ProjectionContractVersion], [ProjectionSchemaVersion]),
            CONSTRAINT [FK_AgentTextProjection_Entity] FOREIGN KEY
                ([EntityId], [EntityTypeId], [AgentTextProjectionPhiloteId])
                REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
            CONSTRAINT [FK_AgentTextProjection_EntityType] FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
                REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
            CONSTRAINT [FK_AgentTextProjection_RenderingRule] FOREIGN KEY ([RenderingRuleVersionId])
                REFERENCES [ATAPUtilities].[RuleVersion] ([RuleVersionId]),
            CONSTRAINT [FK_AgentTextProjection_Owner] FOREIGN KEY ([OwnerEntityId], [OwnerEntityTypeId])
                REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
            CONSTRAINT [FK_AgentTextProjection_SelectionPolicy] FOREIGN KEY
                ([SelectionPolicyVersionId], [SelectionPolicyKindCode])
                REFERENCES [ATAPUtilities].[PolicyVersion] ([PolicyVersionId], [PolicyKindCode]),
            CONSTRAINT [FK_AgentTextProjection_ClassificationPolicy] FOREIGN KEY
                ([ClassificationPolicyVersionId], [ClassificationPolicyKindCode])
                REFERENCES [ATAPUtilities].[PolicyVersion] ([PolicyVersionId], [PolicyKindCode]),
            CONSTRAINT [FK_AgentTextProjection_OwnerPolicy] FOREIGN KEY
                ([OwnerPolicyVersionId], [OwnerPolicyKindCode])
                REFERENCES [ATAPUtilities].[PolicyVersion] ([PolicyVersionId], [PolicyKindCode]),
            CONSTRAINT [CK_AgentTextProjection_NameConsumer] CHECK
                (LEN([ProjectionName]) > 0 AND LEN([ConsumerClassCode]) > 0),
            CONSTRAINT [CK_AgentTextProjection_Versions] CHECK
                ([ProjectionContractVersion] > 0 AND [ProjectionSchemaVersion] > 0),
            CONSTRAINT [CK_AgentTextProjection_Lifetime] CHECK
                ([RetiredAtUtc] IS NULL OR [RetiredAtUtc] >= [CreatedAtUtc])
        );
        CREATE UNIQUE INDEX [UX_AgentTextProjection_ActiveNameConsumer]
            ON [ATAPUtilities].[AgentTextProjection] ([ProjectionName], [ConsumerClassCode])
            WHERE [RetiredAtUtc] IS NULL;
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[AgentTextProjectionVersion]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[AgentTextProjectionVersion]
        (
            [AgentTextProjectionVersionId] bigint IDENTITY(1,1) NOT NULL,
            [AgentTextProjectionId] bigint NOT NULL,
            [VersionSequence] bigint NOT NULL,
            [MaterializationStateCode] varchar(16) NOT NULL,
            [InputWatermarkUtc] datetime2(7) NOT NULL,
            [SourceVersionWatermark] bigint NOT NULL,
            [RenderingRuleVersionId] bigint NOT NULL,
            [SelectionPolicyVersionId] bigint NOT NULL,
            [SelectionPolicyKindCode] AS CONVERT(varchar(32), 'selection') PERSISTED,
            [ClassificationPolicyVersionId] bigint NOT NULL,
            [ClassificationPolicyKindCode] AS CONVERT(varchar(32), 'classification') PERSISTED,
            [ProjectionContractVersion] int NOT NULL,
            [ProjectionSchemaVersion] int NOT NULL,
            [SelectedSummarySetFingerprint] binary(32) NOT NULL,
            [ProjectionContentHash] binary(32) NULL,
            [SafeRenderedText] nvarchar(max) NULL,
            [GeneratedAtUtc] datetime2(7) NOT NULL,
            CONSTRAINT [PK_AgentTextProjectionVersion] PRIMARY KEY CLUSTERED ([AgentTextProjectionVersionId]),
            CONSTRAINT [UQ_AgentTextProjectionVersion_Id_Projection] UNIQUE
                ([AgentTextProjectionVersionId], [AgentTextProjectionId]),
            CONSTRAINT [UQ_AgentTextProjectionVersion_Projection_Sequence] UNIQUE
                ([AgentTextProjectionId], [VersionSequence]),
            CONSTRAINT [UQ_AgentTextProjectionVersion_Projection_Input] UNIQUE
                ([AgentTextProjectionId], [SelectedSummarySetFingerprint]),
            CONSTRAINT [FK_AgentTextProjectionVersion_ExactPolicies] FOREIGN KEY
                ([AgentTextProjectionId], [RenderingRuleVersionId], [SelectionPolicyVersionId],
                 [ClassificationPolicyVersionId], [ProjectionContractVersion], [ProjectionSchemaVersion])
                REFERENCES [ATAPUtilities].[AgentTextProjection]
                    ([AgentTextProjectionId], [RenderingRuleVersionId], [SelectionPolicyVersionId],
                     [ClassificationPolicyVersionId], [ProjectionContractVersion], [ProjectionSchemaVersion]),
            CONSTRAINT [FK_AgentTextProjectionVersion_RenderingRule] FOREIGN KEY ([RenderingRuleVersionId])
                REFERENCES [ATAPUtilities].[RuleVersion] ([RuleVersionId]),
            CONSTRAINT [FK_AgentTextProjectionVersion_SelectionPolicy] FOREIGN KEY
                ([SelectionPolicyVersionId], [SelectionPolicyKindCode])
                REFERENCES [ATAPUtilities].[PolicyVersion] ([PolicyVersionId], [PolicyKindCode]),
            CONSTRAINT [FK_AgentTextProjectionVersion_ClassificationPolicy] FOREIGN KEY
                ([ClassificationPolicyVersionId], [ClassificationPolicyKindCode])
                REFERENCES [ATAPUtilities].[PolicyVersion] ([PolicyVersionId], [PolicyKindCode]),
            CONSTRAINT [CK_AgentTextProjectionVersion_Sequence] CHECK ([VersionSequence] > 0),
            CONSTRAINT [CK_AgentTextProjectionVersion_State] CHECK
                ([MaterializationStateCode] IN ('Current', 'Stale', 'Rebuilding', 'Failed', 'Unavailable')),
            CONSTRAINT [CK_AgentTextProjectionVersion_StateShape] CHECK
                (([MaterializationStateCode] = 'Current'
                  AND [ProjectionContentHash] IS NOT NULL AND [SafeRenderedText] IS NOT NULL)
                 OR ([MaterializationStateCode] IN ('Stale', 'Rebuilding', 'Failed', 'Unavailable')
                     AND [ProjectionContentHash] IS NULL AND [SafeRenderedText] IS NULL)),
            CONSTRAINT [CK_AgentTextProjectionVersion_Watermarks] CHECK
                ([InputWatermarkUtc] <= [GeneratedAtUtc] AND [SourceVersionWatermark] >= 0),
            CONSTRAINT [CK_AgentTextProjectionVersion_Versions] CHECK
                ([ProjectionContractVersion] > 0 AND [ProjectionSchemaVersion] > 0)
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[AgentTextProjectionVersionContentSummaryVersion]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[AgentTextProjectionVersionContentSummaryVersion]
        (
            [AgentTextProjectionVersionId] bigint NOT NULL,
            [SelectionOrdinal] int NOT NULL,
            [ContentSummaryVersionId] bigint NOT NULL,
            CONSTRAINT [PK_AgentTextProjectionVersionContentSummaryVersion] PRIMARY KEY CLUSTERED
                ([AgentTextProjectionVersionId], [SelectionOrdinal]),
            CONSTRAINT [UQ_AgentTextProjectionVersionContentSummaryVersion_ExactMember] UNIQUE
                ([AgentTextProjectionVersionId], [ContentSummaryVersionId]),
            CONSTRAINT [FK_AgentTextProjectionVersionContentSummaryVersion_ProjectionVersion] FOREIGN KEY
                ([AgentTextProjectionVersionId]) REFERENCES [ATAPUtilities].[AgentTextProjectionVersion] ([AgentTextProjectionVersionId]),
            CONSTRAINT [FK_AgentTextProjectionVersionContentSummaryVersion_SummaryVersion] FOREIGN KEY
                ([ContentSummaryVersionId]) REFERENCES [ATAPUtilities].[ContentSummaryVersion] ([ContentSummaryVersionId]),
            CONSTRAINT [CK_AgentTextProjectionVersionContentSummaryVersion_Ordinal] CHECK ([SelectionOrdinal] >= 0)
        );
        CREATE INDEX [IX_AgentTextProjectionVersionContentSummaryVersion_SummaryVersion]
            ON [ATAPUtilities].[AgentTextProjectionVersionContentSummaryVersion] ([ContentSummaryVersionId]);
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[AgentTextProjectionRefresh]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[AgentTextProjectionRefresh]
        (
            [AgentTextProjectionRefreshId] bigint IDENTITY(1,1) NOT NULL,
            [AgentTextProjectionId] bigint NOT NULL,
            [RefreshSequence] bigint NOT NULL,
            [RequestedInputWatermarkUtc] datetime2(7) NOT NULL,
            [ResultCode] varchar(32) NOT NULL,
            [AgentTextProjectionVersionId] bigint NULL,
            [ErrorTaxonomyCode] varchar(64) NULL,
            [NonSecretDiagnosticHash] binary(32) NULL,
            [RequestedAtUtc] datetime2(7) NOT NULL,
            [StartedAtUtc] datetime2(7) NOT NULL,
            [CompletedAtUtc] datetime2(7) NOT NULL,
            CONSTRAINT [PK_AgentTextProjectionRefresh] PRIMARY KEY CLUSTERED ([AgentTextProjectionRefreshId]),
            CONSTRAINT [UQ_AgentTextProjectionRefresh_Projection_Sequence] UNIQUE
                ([AgentTextProjectionId], [RefreshSequence]),
            CONSTRAINT [FK_AgentTextProjectionRefresh_Projection] FOREIGN KEY ([AgentTextProjectionId])
                REFERENCES [ATAPUtilities].[AgentTextProjection] ([AgentTextProjectionId]),
            CONSTRAINT [FK_AgentTextProjectionRefresh_ProducedExact] FOREIGN KEY
                ([AgentTextProjectionVersionId], [AgentTextProjectionId])
                REFERENCES [ATAPUtilities].[AgentTextProjectionVersion]
                    ([AgentTextProjectionVersionId], [AgentTextProjectionId]),
            CONSTRAINT [FK_AgentTextProjectionRefresh_ErrorTaxonomy] FOREIGN KEY ([ErrorTaxonomyCode])
                REFERENCES [ATAPUtilities].[ErrorTaxonomy] ([ErrorTaxonomyCode]),
            CONSTRAINT [CK_AgentTextProjectionRefresh_Sequence] CHECK ([RefreshSequence] > 0),
            CONSTRAINT [CK_AgentTextProjectionRefresh_Result] CHECK
                ([ResultCode] IN ('succeeded', 'failed', 'stale-observed', 'superseded')),
            CONSTRAINT [CK_AgentTextProjectionRefresh_ResultShape] CHECK
                (([ResultCode] = 'succeeded' AND [AgentTextProjectionVersionId] IS NOT NULL
                  AND [ErrorTaxonomyCode] IS NULL)
                 OR ([ResultCode] = 'failed' AND [AgentTextProjectionVersionId] IS NULL
                     AND [ErrorTaxonomyCode] IS NOT NULL)
                 OR ([ResultCode] IN ('stale-observed', 'superseded')
                     AND [AgentTextProjectionVersionId] IS NULL
                     AND [ErrorTaxonomyCode] IS NULL)),
            CONSTRAINT [CK_AgentTextProjectionRefresh_TimeOrder] CHECK
                ([RequestedAtUtc] <= [StartedAtUtc] AND [StartedAtUtc] <= [CompletedAtUtc])
        );
        CREATE INDEX [IX_AgentTextProjectionRefresh_Projection_Result]
            ON [ATAPUtilities].[AgentTextProjectionRefresh] ([AgentTextProjectionId], [ResultCode]);
    END;

    /* RDB-310: exact retained Tags and Gmail table contract. */
    IF OBJECT_ID(N'[Tags].[Tags]', N'U') IS NULL
    BEGIN
        CREATE TABLE [Tags].[Tags]
        (
            [TagID] int IDENTITY(1,1) NOT NULL,
            [ParentTagID] int NULL,
            [ResourceKey] varchar(100) NOT NULL,
            [DefaultLabel] nvarchar(256) NULL,
            [IsActive] bit NOT NULL CONSTRAINT [DF_Tags_Tags_IsActive] DEFAULT (1),
            [SortOrder] int NOT NULL CONSTRAINT [DF_Tags_Tags_SortOrder] DEFAULT (0),
            [CreatedDate] datetime2(7) NOT NULL CONSTRAINT [DF_Tags_Tags_CreatedDate] DEFAULT (SYSUTCDATETIME()),
            [ModifiedDate] datetime2(7) NOT NULL CONSTRAINT [DF_Tags_Tags_ModifiedDate] DEFAULT (SYSUTCDATETIME()),
            CONSTRAINT [PK_Tags_Tags] PRIMARY KEY CLUSTERED ([TagID]),
            CONSTRAINT [UQ_Tags_Tags_ResourceKey] UNIQUE NONCLUSTERED ([ResourceKey]),
            CONSTRAINT [FK_Tags_Tags_ParentTag] FOREIGN KEY ([ParentTagID])
                REFERENCES [Tags].[Tags] ([TagID]) ON DELETE NO ACTION ON UPDATE NO ACTION
        );
        CREATE INDEX [IX_Tags_Tags_ParentTagID] ON [Tags].[Tags] ([ParentTagID])
            INCLUDE ([ResourceKey], [IsActive], [SortOrder]);
        CREATE INDEX [IX_Tags_Tags_IsActive] ON [Tags].[Tags] ([IsActive]) WHERE [IsActive] = 1;
    END;

    IF OBJECT_ID(N'[Tags].[TagAliases]', N'U') IS NULL
    BEGIN
        CREATE TABLE [Tags].[TagAliases]
        (
            [AliasID] int IDENTITY(1,1) NOT NULL,
            [TagID] int NOT NULL,
            [AliasResourceKey] varchar(100) NOT NULL,
            [AliasType] varchar(50) NOT NULL CONSTRAINT [DF_Tags_TagAliases_Type] DEFAULT ('Synonym'),
            [IsActive] bit NOT NULL CONSTRAINT [DF_Tags_TagAliases_IsActive] DEFAULT (1),
            [CreatedDate] datetime2(7) NOT NULL CONSTRAINT [DF_Tags_TagAliases_CreatedDate] DEFAULT (SYSUTCDATETIME()),
            CONSTRAINT [PK_Tags_TagAliases] PRIMARY KEY CLUSTERED ([AliasID]),
            CONSTRAINT [UQ_Tags_TagAliases_ResourceKey] UNIQUE NONCLUSTERED ([AliasResourceKey]),
            CONSTRAINT [FK_Tags_TagAliases_Tag] FOREIGN KEY ([TagID]) REFERENCES [Tags].[Tags] ([TagID]) ON DELETE CASCADE
        );
        CREATE INDEX [IX_Tags_TagAliases_TagID] ON [Tags].[TagAliases] ([TagID]);
    END;

    IF OBJECT_ID(N'[Tags].[RelationshipTypes]', N'U') IS NULL
    BEGIN
        CREATE TABLE [Tags].[RelationshipTypes]
        (
            [RelationshipTypeID] int IDENTITY(1,1) NOT NULL,
            [ResourceKey] varchar(100) NOT NULL,
            [IsBidirectionalDefault] bit NOT NULL CONSTRAINT [DF_Tags_RelType_Bidirectional] DEFAULT (0),
            [InverseTypeKey] varchar(100) NULL,
            [DefaultDescription] nvarchar(256) NULL,
            [IsActive] bit NOT NULL CONSTRAINT [DF_Tags_RelType_IsActive] DEFAULT (1),
            [SortOrder] int NOT NULL CONSTRAINT [DF_Tags_RelType_SortOrder] DEFAULT (0),
            [CreatedDate] datetime2(7) NOT NULL CONSTRAINT [DF_Tags_RelType_CreatedDate] DEFAULT (SYSUTCDATETIME()),
            CONSTRAINT [PK_Tags_RelationshipTypes] PRIMARY KEY CLUSTERED ([RelationshipTypeID]),
            CONSTRAINT [UQ_Tags_RelationshipTypes_ResourceKey] UNIQUE NONCLUSTERED ([ResourceKey])
        );
    END;

    IF OBJECT_ID(N'[Tags].[TagRelationships]', N'U') IS NULL
    BEGIN
        CREATE TABLE [Tags].[TagRelationships]
        (
            [RelationshipID] int IDENTITY(1,1) NOT NULL,
            [SourceTagID] int NOT NULL,
            [TargetTagID] int NOT NULL,
            [RelationshipTypeKey] varchar(100) NOT NULL,
            [IsBidirectional] bit NOT NULL CONSTRAINT [DF_Tags_TagRel_Bidirectional] DEFAULT (0),
            [Weight] decimal(5,2) NOT NULL CONSTRAINT [DF_Tags_TagRel_Weight] DEFAULT (1.0),
            [IsActive] bit NOT NULL CONSTRAINT [DF_Tags_TagRel_IsActive] DEFAULT (1),
            [CreatedDate] datetime2(7) NOT NULL CONSTRAINT [DF_Tags_TagRel_CreatedDate] DEFAULT (SYSUTCDATETIME()),
            CONSTRAINT [PK_Tags_TagRelationships] PRIMARY KEY CLUSTERED ([RelationshipID]),
            CONSTRAINT [UQ_Tags_TagRelationships] UNIQUE NONCLUSTERED
                ([SourceTagID], [TargetTagID], [RelationshipTypeKey]),
            CONSTRAINT [FK_Tags_TagRel_SourceTag] FOREIGN KEY ([SourceTagID])
                REFERENCES [Tags].[Tags] ([TagID]) ON DELETE NO ACTION,
            CONSTRAINT [FK_Tags_TagRel_TargetTag] FOREIGN KEY ([TargetTagID])
                REFERENCES [Tags].[Tags] ([TagID]) ON DELETE NO ACTION,
            CONSTRAINT [CK_Tags_TagRel_NoSelfRef] CHECK ([SourceTagID] <> [TargetTagID])
        );
        CREATE INDEX [IX_Tags_TagRel_SourceTag] ON [Tags].[TagRelationships] ([SourceTagID])
            INCLUDE ([TargetTagID], [RelationshipTypeKey]);
        CREATE INDEX [IX_Tags_TagRel_TargetTag] ON [Tags].[TagRelationships] ([TargetTagID])
            INCLUDE ([SourceTagID], [RelationshipTypeKey]);
    END;

    IF OBJECT_ID(N'[Gmail].[gmailMessages]', N'U') IS NULL
    BEGIN
        CREATE TABLE [Gmail].[gmailMessages]
        (
            [ID] int IDENTITY(1,1) NOT NULL,
            [Subject] nvarchar(400) NULL,
            [MessageId] nvarchar(400) NULL,
            [FromAddress] nvarchar(400) NULL,
            [ToAddress] nvarchar(400) NULL,
            [Date] datetime2(7) NULL,
            [Labels] nvarchar(1000) NULL,
            [Body] nvarchar(max) NULL,
            [URL] nvarchar(2000) NULL,
            CONSTRAINT [PK_Gmail_gmailMessages] PRIMARY KEY CLUSTERED ([ID])
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[Repository]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[Repository]
        (
            [RepositoryId] bigint IDENTITY(1,1) NOT NULL,
            [RepositoryPhiloteId] uniqueidentifier NOT NULL,
            [EntityId] bigint NOT NULL,
            [EntityTypeId] bigint NOT NULL,
            [EntityTypeCode] AS CONVERT(varchar(64), 'repository') PERSISTED,
            [OrganizationId] bigint NOT NULL,
            [CanonicalRepositoryName] nvarchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
            [ClassificationPolicyVersionId] bigint NOT NULL,
            [ClassificationPolicyKindCode] AS CONVERT(varchar(32), 'classification') PERSISTED,
            [RemoteIdentityEvidence] binary(32) NULL,
            [RemoteObservationEvidenceReference] nvarchar(2048) NULL,
            [CreatedAtUtc] datetime2(7) NOT NULL,
            [RetiredAtUtc] datetime2(7) NULL,
            CONSTRAINT [PK_Repository] PRIMARY KEY CLUSTERED ([RepositoryId]),
            CONSTRAINT [UQ_Repository_Philote] UNIQUE ([RepositoryPhiloteId]),
            CONSTRAINT [UQ_Repository_Entity] UNIQUE ([EntityId], [EntityTypeId]),
            CONSTRAINT [UQ_Repository_Organization_Name] UNIQUE ([OrganizationId], [CanonicalRepositoryName]),
            CONSTRAINT [FK_Repository_Entity] FOREIGN KEY ([EntityId], [EntityTypeId], [RepositoryPhiloteId])
                REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
            CONSTRAINT [FK_Repository_EntityType] FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
                REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
            CONSTRAINT [FK_Repository_Organization] FOREIGN KEY ([OrganizationId])
                REFERENCES [ATAPUtilities].[Organization] ([OrganizationId]),
            CONSTRAINT [FK_Repository_ClassificationPolicy] FOREIGN KEY
                ([ClassificationPolicyVersionId], [ClassificationPolicyKindCode])
                REFERENCES [ATAPUtilities].[PolicyVersion] ([PolicyVersionId], [PolicyKindCode]),
            CONSTRAINT [CK_Repository_Name] CHECK (LEN([CanonicalRepositoryName]) > 0),
            CONSTRAINT [CK_Repository_RemoteEvidence] CHECK
                ([RemoteIdentityEvidence] IS NULL OR [RemoteObservationEvidenceReference] IS NOT NULL),
            CONSTRAINT [CK_Repository_Lifetime] CHECK ([RetiredAtUtc] IS NULL OR [RetiredAtUtc] >= [CreatedAtUtc])
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[RepositoryRootRegistration]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[RepositoryRootRegistration]
        (
            [RepositoryRootRegistrationId] bigint IDENTITY(1,1) NOT NULL,
            [RepositoryId] bigint NOT NULL,
            [NormalizedAbsoluteRoot] nvarchar(2048) COLLATE Latin1_General_100_CI_AS NOT NULL,
            [NormalizedAbsoluteRootHash] binary(32) NOT NULL,
            [RootKindCode] varchar(32) NOT NULL,
            [RegisteredAtUtc] datetime2(7) NOT NULL,
            [RetiredAtUtc] datetime2(7) NULL,
            [RegistrarEvidenceReference] nvarchar(2048) NOT NULL,
            CONSTRAINT [PK_RepositoryRootRegistration] PRIMARY KEY CLUSTERED ([RepositoryRootRegistrationId]),
            CONSTRAINT [FK_RepositoryRootRegistration_Repository] FOREIGN KEY ([RepositoryId])
                REFERENCES [ATAPUtilities].[Repository] ([RepositoryId]),
            CONSTRAINT [CK_RepositoryRootRegistration_Kind] CHECK
                ([RootKindCode] IN ('stable', 'sprint', 'mirror', 'scanner-sandbox')),
            CONSTRAINT [CK_RepositoryRootRegistration_AbsoluteNormalized] CHECK
                (LEN([NormalizedAbsoluteRoot]) >= 3
                 AND [NormalizedAbsoluteRoot] NOT LIKE N'%/%'
                 AND [NormalizedAbsoluteRoot] NOT LIKE N'%\.%'
                 AND [NormalizedAbsoluteRoot] NOT LIKE N'%\..%'
                 AND RIGHT([NormalizedAbsoluteRoot], 1) <> N'\'
                 AND [NormalizedAbsoluteRoot] = LOWER([NormalizedAbsoluteRoot])
                 AND (SUBSTRING([NormalizedAbsoluteRoot], 2, 2) = N':\'
                      OR LEFT([NormalizedAbsoluteRoot], 2) = N'\\')),
            CONSTRAINT [CK_RepositoryRootRegistration_Lifetime] CHECK
                ([RetiredAtUtc] IS NULL OR [RetiredAtUtc] >= [RegisteredAtUtc])
        );
        CREATE UNIQUE INDEX [UX_RepositoryRootRegistration_ActiveRoot]
            ON [ATAPUtilities].[RepositoryRootRegistration] ([NormalizedAbsoluteRootHash])
            WHERE [RetiredAtUtc] IS NULL;
        CREATE INDEX [IX_RepositoryRootRegistration_Repository]
            ON [ATAPUtilities].[RepositoryRootRegistration] ([RepositoryId], [RootKindCode]);
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[SourceModule]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[SourceModule]
        (
            [SourceModuleId] bigint IDENTITY(1,1) NOT NULL,
            [RepositoryId] bigint NOT NULL,
            [ParentSourceModuleId] bigint NULL,
            [ModuleRelativePath] nvarchar(2048) COLLATE Latin1_General_100_BIN2 NOT NULL,
            [ModuleRelativePathHash] binary(32) NOT NULL,
            [ModuleKindCode] varchar(64) NOT NULL,
            [DiscoveredAtUtc] datetime2(7) NOT NULL,
            [RetiredAtUtc] datetime2(7) NULL,
            CONSTRAINT [PK_SourceModule] PRIMARY KEY CLUSTERED ([SourceModuleId]),
            CONSTRAINT [UQ_SourceModule_Id_Repository] UNIQUE ([SourceModuleId], [RepositoryId]),
            CONSTRAINT [UQ_SourceModule_Repository_PathHash] UNIQUE ([RepositoryId], [ModuleRelativePathHash]),
            CONSTRAINT [FK_SourceModule_Repository] FOREIGN KEY ([RepositoryId])
                REFERENCES [ATAPUtilities].[Repository] ([RepositoryId]),
            CONSTRAINT [FK_SourceModule_ParentSameRepository] FOREIGN KEY ([ParentSourceModuleId], [RepositoryId])
                REFERENCES [ATAPUtilities].[SourceModule] ([SourceModuleId], [RepositoryId]),
            CONSTRAINT [CK_SourceModule_Path] CHECK
                (LEN([ModuleRelativePath]) > 0 AND LEFT([ModuleRelativePath], 1) <> N'/'
                 AND [ModuleRelativePath] NOT LIKE N'%\%' AND [ModuleRelativePath] NOT LIKE N'%../%'
                 AND [ModuleRelativePath] NOT LIKE N'../%' AND [ModuleRelativePath] NOT LIKE N'%/..'),
            CONSTRAINT [CK_SourceModule_Kind] CHECK (LEN([ModuleKindCode]) > 0),
            CONSTRAINT [CK_SourceModule_ParentNotSelf] CHECK
                ([ParentSourceModuleId] IS NULL OR [ParentSourceModuleId] <> [SourceModuleId]),
            CONSTRAINT [CK_SourceModule_Lifetime] CHECK ([RetiredAtUtc] IS NULL OR [RetiredAtUtc] >= [DiscoveredAtUtc])
        );
        CREATE INDEX [IX_SourceModule_Parent] ON [ATAPUtilities].[SourceModule] ([ParentSourceModuleId]);
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[SourceArtifact]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[SourceArtifact]
        (
            [SourceArtifactId] bigint IDENTITY(1,1) NOT NULL,
            [SourceArtifactPhiloteId] uniqueidentifier NOT NULL,
            [EntityId] bigint NOT NULL,
            [EntityTypeId] bigint NOT NULL,
            [EntityTypeCode] AS CONVERT(varchar(64), 'source-artifact') PERSISTED,
            [RepositoryId] bigint NOT NULL,
            [SourceModuleId] bigint NULL,
            [LocatorTypeCode] varchar(32) NOT NULL,
            [RepoRelativePathOrExternalLocator] nvarchar(2048) COLLATE Latin1_General_100_BIN2 NOT NULL,
            [LocatorIdentityHash] binary(32) NOT NULL,
            [LocatorAuthorityNamespace] nvarchar(512) NULL,
            [LocatorNormalizerIdentityReference] nvarchar(512) NOT NULL,
            [ExternalObservationEvidenceReference] nvarchar(2048) NULL,
            [CreatedAtUtc] datetime2(7) NOT NULL,
            [RetiredAtUtc] datetime2(7) NULL,
            CONSTRAINT [PK_SourceArtifact] PRIMARY KEY CLUSTERED ([SourceArtifactId]),
            CONSTRAINT [UQ_SourceArtifact_Philote] UNIQUE ([SourceArtifactPhiloteId]),
            CONSTRAINT [UQ_SourceArtifact_Entity] UNIQUE ([EntityId], [EntityTypeId]),
            CONSTRAINT [UQ_SourceArtifact_Id_Repository] UNIQUE ([SourceArtifactId], [RepositoryId]),
            CONSTRAINT [UQ_SourceArtifact_Repository_Locator] UNIQUE
                ([RepositoryId], [LocatorTypeCode], [LocatorIdentityHash]),
            CONSTRAINT [FK_SourceArtifact_Entity] FOREIGN KEY ([EntityId], [EntityTypeId], [SourceArtifactPhiloteId])
                REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId], [EntityPhiloteId]),
            CONSTRAINT [FK_SourceArtifact_EntityType] FOREIGN KEY ([EntityTypeId], [EntityTypeCode])
                REFERENCES [ATAPUtilities].[EntityType] ([EntityTypeId], [EntityTypeCode]),
            CONSTRAINT [FK_SourceArtifact_Repository] FOREIGN KEY ([RepositoryId])
                REFERENCES [ATAPUtilities].[Repository] ([RepositoryId]),
            CONSTRAINT [FK_SourceArtifact_ModuleSameRepository] FOREIGN KEY ([SourceModuleId], [RepositoryId])
                REFERENCES [ATAPUtilities].[SourceModule] ([SourceModuleId], [RepositoryId]),
            CONSTRAINT [CK_SourceArtifact_LocatorType] CHECK
                ([LocatorTypeCode] IN ('RepositoryPath', 'ExternalUri', 'OpaqueExternalReference')),
            CONSTRAINT [CK_SourceArtifact_RepositoryPath] CHECK
                ([LocatorTypeCode] <> 'RepositoryPath'
                 OR (LEN([RepoRelativePathOrExternalLocator]) > 0
                     AND LEFT([RepoRelativePathOrExternalLocator], 1) <> N'/'
                     AND [RepoRelativePathOrExternalLocator] NOT LIKE N'%\%'
                     AND [RepoRelativePathOrExternalLocator] NOT LIKE N'%//%'
                     AND [RepoRelativePathOrExternalLocator] NOT LIKE N'./%'
                     AND [RepoRelativePathOrExternalLocator] NOT LIKE N'%/./%'
                     AND [RepoRelativePathOrExternalLocator] NOT LIKE N'%/.'
                     AND [RepoRelativePathOrExternalLocator] NOT LIKE N'%../%'
                     AND [RepoRelativePathOrExternalLocator] NOT LIKE N'../%'
                     AND [RepoRelativePathOrExternalLocator] NOT LIKE N'%/..'
                     AND [RepoRelativePathOrExternalLocator] NOT LIKE N'%' + NCHAR(9) + N'%'
                     AND [RepoRelativePathOrExternalLocator] NOT LIKE N'%' + NCHAR(10) + N'%'
                     AND [RepoRelativePathOrExternalLocator] NOT LIKE N'%' + NCHAR(13) + N'%')),
            CONSTRAINT [CK_SourceArtifact_ExternalLocatorEvidence] CHECK
                (([LocatorTypeCode] = 'RepositoryPath' AND [LocatorAuthorityNamespace] IS NULL
                  AND [ExternalObservationEvidenceReference] IS NULL)
                 OR ([LocatorTypeCode] <> 'RepositoryPath' AND [LocatorAuthorityNamespace] IS NOT NULL
                     AND LEN([LocatorAuthorityNamespace]) > 0
                     AND [ExternalObservationEvidenceReference] IS NOT NULL)),
            CONSTRAINT [CK_SourceArtifact_NormalizerEvidence] CHECK
                (LEN([LocatorNormalizerIdentityReference]) > 0),
            CONSTRAINT [CK_SourceArtifact_ExternalUriShape] CHECK
                ([LocatorTypeCode] <> 'ExternalUri'
                 OR [RepoRelativePathOrExternalLocator] LIKE N'%://%'),
            CONSTRAINT [CK_SourceArtifact_Lifetime] CHECK ([RetiredAtUtc] IS NULL OR [RetiredAtUtc] >= [CreatedAtUtc])
        );
        CREATE INDEX [IX_SourceArtifact_Module] ON [ATAPUtilities].[SourceArtifact] ([SourceModuleId]);
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[SourceArtifactVersion]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[SourceArtifactVersion]
        (
            [SourceArtifactVersionId] bigint IDENTITY(1,1) NOT NULL,
            [SourceArtifactId] bigint NOT NULL,
            [VersionSequence] bigint NOT NULL,
            [NormalizedContentSha256] char(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
            [ByteSha256] char(64) COLLATE Latin1_General_100_BIN2 NULL,
            [ByteCount] bigint NOT NULL,
            [EncodingCode] varchar(64) NOT NULL,
            [BomPresent] bit NOT NULL,
            [LineEndingCode] varchar(16) NOT NULL,
            [HasFinalNewline] bit NOT NULL,
            [ExtractorIdentityReference] nvarchar(512) NOT NULL,
            [HarvesterIdentity] nvarchar(512) NOT NULL,
            [ObservedAtUtc] datetime2(7) NOT NULL,
            [ProvenanceFingerprint] binary(32) NOT NULL,
            CONSTRAINT [PK_SourceArtifactVersion] PRIMARY KEY CLUSTERED ([SourceArtifactVersionId]),
            CONSTRAINT [UQ_SourceArtifactVersion_Id_Artifact] UNIQUE ([SourceArtifactVersionId], [SourceArtifactId]),
            CONSTRAINT [UQ_SourceArtifactVersion_Artifact_Sequence] UNIQUE ([SourceArtifactId], [VersionSequence]),
            CONSTRAINT [UQ_SourceArtifactVersion_Provenance] UNIQUE ([ProvenanceFingerprint]),
            CONSTRAINT [FK_SourceArtifactVersion_Artifact] FOREIGN KEY ([SourceArtifactId])
                REFERENCES [ATAPUtilities].[SourceArtifact] ([SourceArtifactId]),
            CONSTRAINT [CK_SourceArtifactVersion_Sequence] CHECK ([VersionSequence] > 0),
            CONSTRAINT [CK_SourceArtifactVersion_NormalizedHash] CHECK
                (LEN([NormalizedContentSha256]) = 64
                 AND [NormalizedContentSha256] = LOWER([NormalizedContentSha256])
                 AND [NormalizedContentSha256] NOT LIKE '%[^0-9a-f]%'),
            CONSTRAINT [CK_SourceArtifactVersion_ByteHash] CHECK
                ([ByteSha256] IS NULL
                 OR (LEN([ByteSha256]) = 64 AND [ByteSha256] = LOWER([ByteSha256])
                     AND [ByteSha256] NOT LIKE '%[^0-9a-f]%')),
            CONSTRAINT [CK_SourceArtifactVersion_ByteCount] CHECK ([ByteCount] >= 0),
            CONSTRAINT [CK_SourceArtifactVersion_LineEnding] CHECK
                ([LineEndingCode] IN ('none', 'lf', 'crlf', 'cr', 'mixed')),
            CONSTRAINT [CK_SourceArtifactVersion_Identities] CHECK
                (LEN([EncodingCode]) > 0 AND LEN([ExtractorIdentityReference]) > 0
                 AND LEN([HarvesterIdentity]) > 0)
        );
        CREATE INDEX [IX_SourceArtifactVersion_Artifact_Observed]
            ON [ATAPUtilities].[SourceArtifactVersion] ([SourceArtifactId], [ObservedAtUtc]);
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[SourceArtifactLineage]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[SourceArtifactLineage]
        (
            [SourceArtifactLineageId] bigint IDENTITY(1,1) NOT NULL,
            [PredecessorSourceArtifactId] bigint NOT NULL,
            [PredecessorRepositoryId] bigint NOT NULL,
            [SuccessorSourceArtifactId] bigint NOT NULL,
            [SuccessorRepositoryId] bigint NOT NULL,
            [RelationKindCode] varchar(32) NOT NULL,
            [AcceptancePolicyVersionId] bigint NOT NULL,
            [AcceptancePolicyKindCode] AS CONVERT(varchar(32), 'acceptance') PERSISTED,
            [AcceptedByEntityId] bigint NOT NULL,
            [AcceptedByEntityTypeId] bigint NOT NULL,
            [AcceptanceEvidenceReference] nvarchar(2048) NOT NULL,
            [ProposalEvidenceReference] nvarchar(2048) NULL,
            [CrossRepositoryAcceptanceEvidenceReference] nvarchar(2048) NULL,
            [AcceptedAtUtc] datetime2(7) NOT NULL,
            CONSTRAINT [PK_SourceArtifactLineage] PRIMARY KEY CLUSTERED ([SourceArtifactLineageId]),
            CONSTRAINT [UQ_SourceArtifactLineage_Edge] UNIQUE
                ([PredecessorSourceArtifactId], [SuccessorSourceArtifactId], [RelationKindCode]),
            CONSTRAINT [FK_SourceArtifactLineage_Predecessor] FOREIGN KEY
                ([PredecessorSourceArtifactId], [PredecessorRepositoryId])
                REFERENCES [ATAPUtilities].[SourceArtifact] ([SourceArtifactId], [RepositoryId]),
            CONSTRAINT [FK_SourceArtifactLineage_Successor] FOREIGN KEY
                ([SuccessorSourceArtifactId], [SuccessorRepositoryId])
                REFERENCES [ATAPUtilities].[SourceArtifact] ([SourceArtifactId], [RepositoryId]),
            CONSTRAINT [FK_SourceArtifactLineage_Acceptor] FOREIGN KEY
                ([AcceptedByEntityId], [AcceptedByEntityTypeId])
                REFERENCES [ATAPUtilities].[Entity] ([EntityId], [EntityTypeId]),
            CONSTRAINT [FK_SourceArtifactLineage_AcceptancePolicy] FOREIGN KEY
                ([AcceptancePolicyVersionId], [AcceptancePolicyKindCode])
                REFERENCES [ATAPUtilities].[PolicyVersion] ([PolicyVersionId], [PolicyKindCode]),
            CONSTRAINT [CK_SourceArtifactLineage_Relation] CHECK
                ([RelationKindCode] IN ('RenamedFrom', 'MovedFrom', 'CopiedFrom', 'Supersedes')),
            CONSTRAINT [CK_SourceArtifactLineage_NotSelf] CHECK
                ([PredecessorSourceArtifactId] <> [SuccessorSourceArtifactId]),
            CONSTRAINT [CK_SourceArtifactLineage_CrossRepositoryEvidence] CHECK
                ([PredecessorRepositoryId] = [SuccessorRepositoryId]
                 OR [CrossRepositoryAcceptanceEvidenceReference] IS NOT NULL)
        );
        CREATE INDEX [IX_SourceArtifactLineage_Successor]
            ON [ATAPUtilities].[SourceArtifactLineage] ([SuccessorSourceArtifactId]);
    END;

    /* These FKs are added after their source-context targets are available. */
    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE [name] = N'FK_ContentSummary_SourceArtifact')
        ALTER TABLE [ATAPUtilities].[ContentSummary] ADD CONSTRAINT [FK_ContentSummary_SourceArtifact]
            FOREIGN KEY ([SourceArtifactId]) REFERENCES [ATAPUtilities].[SourceArtifact] ([SourceArtifactId]);

    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE [name] = N'FK_ContentSummaryVersion_SourceVersionExact')
        ALTER TABLE [ATAPUtilities].[ContentSummaryVersion] ADD CONSTRAINT [FK_ContentSummaryVersion_SourceVersionExact]
            FOREIGN KEY ([SourceArtifactVersionId], [SourceArtifactId])
            REFERENCES [ATAPUtilities].[SourceArtifactVersion] ([SourceArtifactVersionId], [SourceArtifactId]);

    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE [name] = N'FK_ContentSummaryDependency_SourceVersion')
        ALTER TABLE [ATAPUtilities].[ContentSummaryDependency] ADD CONSTRAINT [FK_ContentSummaryDependency_SourceVersion]
            FOREIGN KEY ([SourceArtifactVersionId])
            REFERENCES [ATAPUtilities].[SourceArtifactVersion] ([SourceArtifactVersionId]);

    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE [name] = N'FK_ContentSummaryDependency_ExternalReference')
        ALTER TABLE [ATAPUtilities].[ContentSummaryDependency] ADD CONSTRAINT [FK_ContentSummaryDependency_ExternalReference]
            FOREIGN KEY ([ExternalReferenceId])
            REFERENCES [ATAPUtilities].[ExternalReference] ([ExternalReferenceId]);

    /* Cross-row invariants and append-only event/version rows. */
    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_PolicyVersion_Immutable]
ON [ATAPUtilities].[PolicyVersion]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 52490, ''PolicyVersion rows are immutable; publish a successor.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_ExternalReference_ImmutableControlled]
ON [ATAPUtilities].[ExternalReference]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [deleted])
        THROW 52491, ''ExternalReference rows are immutable.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM [inserted]
        WHERE [CanonicalIdentity] IS NOT NULL
          AND [CanonicalIdentityHash] <> HASHBYTES(''SHA2_256'', CONVERT(varbinary(max), [CanonicalIdentity]))
    )
        THROW 52492, ''ExternalReference canonical identity hash mismatch.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_SourceModule_ValidateHierarchy]
ON [ATAPUtilities].[SourceModule]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [deleted] AS [d] LEFT JOIN [inserted] AS [i]
               ON [i].[SourceModuleId] = [d].[SourceModuleId] WHERE [i].[SourceModuleId] IS NULL)
        THROW 52484, ''SourceModule rows cannot be deleted.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM [inserted]
        WHERE [ModuleRelativePathHash] <> HASHBYTES(''SHA2_256'', CONVERT(varbinary(max), [ModuleRelativePath]))
    )
        THROW 52493, ''SourceModule path hash mismatch.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM [inserted] AS [i]
        INNER JOIN [deleted] AS [d] ON [d].[SourceModuleId] = [i].[SourceModuleId]
        WHERE EXISTS
        (
            SELECT [i].[RepositoryId], [i].[ParentSourceModuleId], [i].[ModuleRelativePath], [i].[ModuleRelativePathHash],
                   [i].[ModuleKindCode], [i].[DiscoveredAtUtc]
            EXCEPT
            SELECT [d].[RepositoryId], [d].[ParentSourceModuleId], [d].[ModuleRelativePath], [d].[ModuleRelativePathHash],
                   [d].[ModuleKindCode], [d].[DiscoveredAtUtc]
        ) OR ([d].[RetiredAtUtc] IS NOT NULL
              AND ([i].[RetiredAtUtc] IS NULL OR [i].[RetiredAtUtc] <> [d].[RetiredAtUtc]))
    )
        THROW 52471, ''SourceModule identity is immutable; only first retirement is allowed.'', 1;
    ;WITH [Ancestors] AS
    (
        SELECT [i].[SourceModuleId] AS [StartId], [i].[ParentSourceModuleId] AS [AncestorId]
        FROM [inserted] AS [i]
        WHERE [i].[ParentSourceModuleId] IS NOT NULL
        UNION ALL
        SELECT [a].[StartId], [m].[ParentSourceModuleId]
        FROM [Ancestors] AS [a]
        INNER JOIN [ATAPUtilities].[SourceModule] AS [m]
            ON [m].[SourceModuleId] = [a].[AncestorId]
        WHERE [m].[ParentSourceModuleId] IS NOT NULL
    )
    SELECT TOP (1) 1 AS [CycleFound]
    INTO [#Rdb460ModuleCycle]
    FROM [Ancestors]
    WHERE [StartId] = [AncestorId]
    OPTION (MAXRECURSION 32767);
    IF EXISTS (SELECT 1 FROM [#Rdb460ModuleCycle])
        THROW 52460, ''SourceModule hierarchy must remain acyclic.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_Organization_ImmutableIdentity]
ON [ATAPUtilities].[Organization]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [deleted] AS [d] LEFT JOIN [inserted] AS [i]
               ON [i].[OrganizationId] = [d].[OrganizationId] WHERE [i].[OrganizationId] IS NULL)
        THROW 52472, ''Organization identity rows cannot be deleted.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM [inserted] AS [i]
        INNER JOIN [deleted] AS [d] ON [d].[OrganizationId] = [i].[OrganizationId]
        WHERE EXISTS
        (
            SELECT [i].[OrganizationPhiloteId], [i].[EntityId], [i].[EntityTypeId],
                   [i].[CanonicalName], [i].[ClassificationPolicyVersionId], [i].[CreatedAtUtc]
            EXCEPT
            SELECT [d].[OrganizationPhiloteId], [d].[EntityId], [d].[EntityTypeId],
                   [d].[CanonicalName], [d].[ClassificationPolicyVersionId], [d].[CreatedAtUtc]
        ) OR ([d].[RetiredAtUtc] IS NOT NULL
              AND ([i].[RetiredAtUtc] IS NULL OR [i].[RetiredAtUtc] <> [d].[RetiredAtUtc]))
    )
        THROW 52473, ''Organization identity is immutable; only first retirement is allowed.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_Repository_ImmutableIdentity]
ON [ATAPUtilities].[Repository]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [deleted] AS [d] LEFT JOIN [inserted] AS [i]
               ON [i].[RepositoryId] = [d].[RepositoryId] WHERE [i].[RepositoryId] IS NULL)
        THROW 52474, ''Repository identity rows cannot be deleted.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM [inserted] AS [i]
        INNER JOIN [deleted] AS [d] ON [d].[RepositoryId] = [i].[RepositoryId]
        WHERE EXISTS
        (
            SELECT [i].[RepositoryPhiloteId], [i].[EntityId], [i].[EntityTypeId], [i].[OrganizationId],
                   [i].[CanonicalRepositoryName], [i].[ClassificationPolicyVersionId], [i].[RemoteIdentityEvidence],
                   [i].[RemoteObservationEvidenceReference], [i].[CreatedAtUtc]
            EXCEPT
            SELECT [d].[RepositoryPhiloteId], [d].[EntityId], [d].[EntityTypeId], [d].[OrganizationId],
                   [d].[CanonicalRepositoryName], [d].[ClassificationPolicyVersionId], [d].[RemoteIdentityEvidence],
                   [d].[RemoteObservationEvidenceReference], [d].[CreatedAtUtc]
        ) OR ([d].[RetiredAtUtc] IS NOT NULL
              AND ([i].[RetiredAtUtc] IS NULL OR [i].[RetiredAtUtc] <> [d].[RetiredAtUtc]))
    )
        THROW 52475, ''Repository identity is immutable; only first retirement is allowed.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_RepositoryRootRegistration_Immutable]
ON [ATAPUtilities].[RepositoryRootRegistration]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [deleted] AS [d] LEFT JOIN [inserted] AS [i]
               ON [i].[RepositoryRootRegistrationId] = [d].[RepositoryRootRegistrationId]
               WHERE [i].[RepositoryRootRegistrationId] IS NULL)
        THROW 52476, ''RepositoryRootRegistration rows cannot be deleted.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM [inserted]
        WHERE [NormalizedAbsoluteRootHash] <> HASHBYTES(''SHA2_256'', CONVERT(varbinary(max), [NormalizedAbsoluteRoot]))
    )
        THROW 52494, ''Repository root hash mismatch.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM [inserted] AS [i]
        INNER JOIN [deleted] AS [d]
            ON [d].[RepositoryRootRegistrationId] = [i].[RepositoryRootRegistrationId]
        WHERE EXISTS
        (
            SELECT [i].[RepositoryId], [i].[NormalizedAbsoluteRoot], [i].[NormalizedAbsoluteRootHash], [i].[RootKindCode],
                   [i].[RegisteredAtUtc], [i].[RegistrarEvidenceReference]
            EXCEPT
            SELECT [d].[RepositoryId], [d].[NormalizedAbsoluteRoot], [d].[NormalizedAbsoluteRootHash], [d].[RootKindCode],
                   [d].[RegisteredAtUtc], [d].[RegistrarEvidenceReference]
        ) OR ([d].[RetiredAtUtc] IS NOT NULL
              AND ([i].[RetiredAtUtc] IS NULL OR [i].[RetiredAtUtc] <> [d].[RetiredAtUtc]))
    )
        THROW 52477, ''Root registration is immutable; only first retirement is allowed.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_SourceArtifact_ImmutableIdentity]
ON [ATAPUtilities].[SourceArtifact]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [deleted] AS [d] LEFT JOIN [inserted] AS [i]
               ON [i].[SourceArtifactId] = [d].[SourceArtifactId] WHERE [i].[SourceArtifactId] IS NULL)
        THROW 52478, ''SourceArtifact identity rows cannot be deleted.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM [inserted]
        WHERE [LocatorIdentityHash] <> HASHBYTES(''SHA2_256'', CONVERT(varbinary(max), [RepoRelativePathOrExternalLocator]))
    )
        THROW 52495, ''SourceArtifact locator hash mismatch.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM [inserted] AS [i]
        INNER JOIN [deleted] AS [d] ON [d].[SourceArtifactId] = [i].[SourceArtifactId]
        WHERE EXISTS
        (
            SELECT [i].[SourceArtifactPhiloteId], [i].[EntityId], [i].[EntityTypeId], [i].[RepositoryId],
                   [i].[SourceModuleId], [i].[LocatorTypeCode], [i].[RepoRelativePathOrExternalLocator], [i].[LocatorIdentityHash],
                   [i].[LocatorAuthorityNamespace], [i].[LocatorNormalizerIdentityReference],
                   [i].[ExternalObservationEvidenceReference], [i].[CreatedAtUtc]
            EXCEPT
            SELECT [d].[SourceArtifactPhiloteId], [d].[EntityId], [d].[EntityTypeId], [d].[RepositoryId],
                   [d].[SourceModuleId], [d].[LocatorTypeCode], [d].[RepoRelativePathOrExternalLocator], [d].[LocatorIdentityHash],
                   [d].[LocatorAuthorityNamespace], [d].[LocatorNormalizerIdentityReference],
                   [d].[ExternalObservationEvidenceReference], [d].[CreatedAtUtc]
        ) OR ([d].[RetiredAtUtc] IS NOT NULL
              AND ([i].[RetiredAtUtc] IS NULL OR [i].[RetiredAtUtc] <> [d].[RetiredAtUtc]))
    )
        THROW 52479, ''SourceArtifact identity is immutable; only first retirement is allowed.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_ContentSummary_ImmutableIdentity]
ON [ATAPUtilities].[ContentSummary]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [deleted] AS [d] LEFT JOIN [inserted] AS [i]
               ON [i].[ContentSummaryId] = [d].[ContentSummaryId] WHERE [i].[ContentSummaryId] IS NULL)
        THROW 52480, ''ContentSummary identity rows cannot be deleted.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM [inserted] AS [i]
        INNER JOIN [deleted] AS [d] ON [d].[ContentSummaryId] = [i].[ContentSummaryId]
        WHERE EXISTS
        (
            SELECT [i].[ContentSummaryPhiloteId], [i].[EntityId], [i].[EntityTypeId], [i].[SourceArtifactId],
                   [i].[SummaryProfileCode], [i].[ClassificationPolicyVersionId], [i].[CreatedAtUtc]
            EXCEPT
            SELECT [d].[ContentSummaryPhiloteId], [d].[EntityId], [d].[EntityTypeId], [d].[SourceArtifactId],
                   [d].[SummaryProfileCode], [d].[ClassificationPolicyVersionId], [d].[CreatedAtUtc]
        ) OR ([d].[RetiredAtUtc] IS NOT NULL
              AND ([i].[RetiredAtUtc] IS NULL OR [i].[RetiredAtUtc] <> [d].[RetiredAtUtc]))
    )
        THROW 52481, ''ContentSummary identity is immutable; only first retirement is allowed.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_AgentTextProjection_ImmutableIdentity]
ON [ATAPUtilities].[AgentTextProjection]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [deleted] AS [d] LEFT JOIN [inserted] AS [i]
               ON [i].[AgentTextProjectionId] = [d].[AgentTextProjectionId]
               WHERE [i].[AgentTextProjectionId] IS NULL)
        THROW 52482, ''AgentTextProjection identity rows cannot be deleted.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM [inserted] AS [i]
        INNER JOIN [deleted] AS [d] ON [d].[AgentTextProjectionId] = [i].[AgentTextProjectionId]
        WHERE EXISTS
        (
            SELECT [i].[AgentTextProjectionPhiloteId], [i].[EntityId], [i].[EntityTypeId],
                   [i].[ProjectionName], [i].[ConsumerClassCode], [i].[ProjectionContractVersion],
                   [i].[ProjectionSchemaVersion], [i].[SelectionPolicyVersionId], [i].[RenderingRuleVersionId],
                   [i].[ClassificationPolicyVersionId], [i].[OwnerEntityId], [i].[OwnerEntityTypeId],
                   [i].[OwnerPolicyVersionId], [i].[CreatedAtUtc]
            EXCEPT
            SELECT [d].[AgentTextProjectionPhiloteId], [d].[EntityId], [d].[EntityTypeId],
                   [d].[ProjectionName], [d].[ConsumerClassCode], [d].[ProjectionContractVersion],
                   [d].[ProjectionSchemaVersion], [d].[SelectionPolicyVersionId], [d].[RenderingRuleVersionId],
                   [d].[ClassificationPolicyVersionId], [d].[OwnerEntityId], [d].[OwnerEntityTypeId],
                   [d].[OwnerPolicyVersionId], [d].[CreatedAtUtc]
        ) OR ([d].[RetiredAtUtc] IS NOT NULL
              AND ([i].[RetiredAtUtc] IS NULL OR [i].[RetiredAtUtc] <> [d].[RetiredAtUtc]))
    )
        THROW 52483, ''AgentTextProjection identity is immutable; only first retirement is allowed.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_SourceArtifactVersion_AppendOnly]
ON [ATAPUtilities].[SourceArtifactVersion]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [deleted])
        THROW 52461, ''SourceArtifactVersion rows are append-only.'', 1;
    IF EXISTS
    (
        SELECT 1
        FROM [inserted] AS [i]
        GROUP BY [i].[SourceArtifactId]
        HAVING MIN([i].[VersionSequence]) <>
            COALESCE((SELECT MAX([v].[VersionSequence])
                      FROM [ATAPUtilities].[SourceArtifactVersion] AS [v]
                      WHERE [v].[SourceArtifactId] = [i].[SourceArtifactId]
                        AND NOT EXISTS (SELECT 1 FROM [inserted] AS [x]
                                        WHERE [x].[SourceArtifactVersionId] = [v].[SourceArtifactVersionId])), 0) + 1
            OR MAX([i].[VersionSequence]) - MIN([i].[VersionSequence]) + 1 <> COUNT_BIG(*)
    )
        THROW 52485, ''SourceArtifactVersion sequence must be gap-free and append at the tail.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_SourceArtifactLineage_AppendOnly]
ON [ATAPUtilities].[SourceArtifactLineage]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 52462, ''SourceArtifactLineage acceptance rows are append-only.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_ContentSummaryVersion_AppendOnlyIntegrity]
ON [ATAPUtilities].[ContentSummaryVersion]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [deleted])
        THROW 52463, ''ContentSummaryVersion rows are append-only.'', 1;
    IF EXISTS
    (
        SELECT 1
        FROM [inserted] AS [i]
        GROUP BY [i].[ContentSummaryId]
        HAVING MIN([i].[VersionSequence]) <>
            COALESCE((SELECT MAX([v].[VersionSequence])
                      FROM [ATAPUtilities].[ContentSummaryVersion] AS [v]
                      WHERE [v].[ContentSummaryId] = [i].[ContentSummaryId]
                        AND NOT EXISTS (SELECT 1 FROM [inserted] AS [x]
                                        WHERE [x].[ContentSummaryVersionId] = [v].[ContentSummaryVersionId])), 0) + 1
            OR MAX([i].[VersionSequence]) - MIN([i].[VersionSequence]) + 1 <> COUNT_BIG(*)
    )
        THROW 52486, ''ContentSummaryVersion sequence must be gap-free and append at the tail.'', 1;
    IF EXISTS
    (
        SELECT 1
        FROM [inserted] AS [i]
        INNER JOIN [ATAPUtilities].[SourceArtifactVersion] AS [v]
            ON [v].[SourceArtifactVersionId] = [i].[SourceArtifactVersionId]
        WHERE [v].[ObservedAtUtc] > [i].[GeneratedAtUtc]
    )
        THROW 52464, ''Summary generation cannot precede source observation.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_ContentSummaryDependency_AppendOnlyIntegrity]
ON [ATAPUtilities].[ContentSummaryDependency]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [deleted])
        THROW 52465, ''ContentSummaryDependency rows are append-only.'', 1;
    IF EXISTS
    (
        SELECT 1
        FROM [inserted] AS [i]
        GROUP BY [i].[ContentSummaryVersionId]
        HAVING MIN([i].[DependencyOrdinal]) <>
            COALESCE((SELECT MAX([d].[DependencyOrdinal])
                      FROM [ATAPUtilities].[ContentSummaryDependency] AS [d]
                      WHERE [d].[ContentSummaryVersionId] = [i].[ContentSummaryVersionId]
                        AND NOT EXISTS (SELECT 1 FROM [inserted] AS [x]
                                        WHERE [x].[ContentSummaryDependencyId] = [d].[ContentSummaryDependencyId])), -1) + 1
            OR MAX([i].[DependencyOrdinal]) - MIN([i].[DependencyOrdinal]) + 1 <> COUNT_BIG(*)
    )
        THROW 52487, ''ContentSummaryDependency ordinals must be gap-free and append at the tail.'', 1;
    IF EXISTS
    (
        SELECT 1
        FROM [inserted] AS [i]
        INNER JOIN [ATAPUtilities].[ContentSummaryVersion] AS [s]
            ON [s].[ContentSummaryVersionId] = [i].[ContentSummaryVersionId]
        LEFT JOIN [ATAPUtilities].[SourceArtifactVersion] AS [v]
            ON [v].[SourceArtifactVersionId] = [i].[SourceArtifactVersionId]
        WHERE [i].[CapturedAtUtc] > [s].[GeneratedAtUtc]
           OR ([v].[SourceArtifactVersionId] IS NOT NULL AND [v].[ObservedAtUtc] > [i].[CapturedAtUtc])
    )
        THROW 52466, ''Dependency evidence must be observed and captured by summary generation.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_AgentTextProjectionVersion_AppendOnly]
ON [ATAPUtilities].[AgentTextProjectionVersion]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [deleted])
        THROW 52467, ''AgentTextProjectionVersion rows are append-only.'', 1;
    IF EXISTS
    (
        SELECT 1
        FROM [inserted] AS [i]
        GROUP BY [i].[AgentTextProjectionId]
        HAVING MIN([i].[VersionSequence]) <>
            COALESCE((SELECT MAX([v].[VersionSequence])
                      FROM [ATAPUtilities].[AgentTextProjectionVersion] AS [v]
                      WHERE [v].[AgentTextProjectionId] = [i].[AgentTextProjectionId]
                        AND NOT EXISTS (SELECT 1 FROM [inserted] AS [x]
                                        WHERE [x].[AgentTextProjectionVersionId] = [v].[AgentTextProjectionVersionId])), 0) + 1
            OR MAX([i].[VersionSequence]) - MIN([i].[VersionSequence]) + 1 <> COUNT_BIG(*)
    )
        THROW 52488, ''AgentTextProjectionVersion sequence must be gap-free and append at the tail.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_AgentTextProjectionRefresh_AppendOnly]
ON [ATAPUtilities].[AgentTextProjectionRefresh]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [deleted])
        THROW 52468, ''AgentTextProjectionRefresh rows are append-only.'', 1;
    IF EXISTS
    (
        SELECT 1
        FROM [inserted] AS [i]
        GROUP BY [i].[AgentTextProjectionId]
        HAVING MIN([i].[RefreshSequence]) <>
            COALESCE((SELECT MAX([r].[RefreshSequence])
                      FROM [ATAPUtilities].[AgentTextProjectionRefresh] AS [r]
                      WHERE [r].[AgentTextProjectionId] = [i].[AgentTextProjectionId]
                        AND NOT EXISTS (SELECT 1 FROM [inserted] AS [x]
                                        WHERE [x].[AgentTextProjectionRefreshId] = [r].[AgentTextProjectionRefreshId])), 0) + 1
            OR MAX([i].[RefreshSequence]) - MIN([i].[RefreshSequence]) + 1 <> COUNT_BIG(*)
    )
        THROW 52489, ''AgentTextProjectionRefresh sequence must be gap-free and append at the tail.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER TRIGGER [ATAPUtilities].[TR_AgentTextProjectionVersionContentSummaryVersion_AppendOnly]
ON [ATAPUtilities].[AgentTextProjectionVersionContentSummaryVersion]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [deleted])
        THROW 52496, ''Projection summary selections are append-only.'', 1;
    IF EXISTS
    (
        SELECT [AgentTextProjectionVersionId]
        FROM [inserted]
        GROUP BY [AgentTextProjectionVersionId]
        HAVING MIN([SelectionOrdinal]) <> 0
            OR MAX([SelectionOrdinal]) <> COUNT_BIG(*) - 1
    )
        THROW 52497, ''Projection summary selection ordinals must be zero-based and gap-free.'', 1;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [ATAPUtilities].[usp_PublishAgentTextProjectionRefresh]
    @AgentTextProjectionId bigint,
    @RequestedInputWatermarkUtc datetime2(7),
    @SourceVersionWatermark bigint,
    @SelectedContentSummaryVersionsJson nvarchar(max),
    @ProjectionContentHash binary(32),
    @SafeRenderedText nvarchar(max),
    @RequestedAtUtc datetime2(7),
    @StartedAtUtc datetime2(7),
    @CompletedAtUtc datetime2(7),
    @AgentTextProjectionVersionId bigint OUTPUT,
    @AgentTextProjectionRefreshId bigint OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT <> 0 THROW 52498, ''Projection publication requires no ambient transaction.'', 1;
    IF ISJSON(@SelectedContentSummaryVersionsJson) <> 1
        THROW 52499, ''Selected summary versions must be a valid JSON array.'', 1;
    IF @SourceVersionWatermark < 0 OR @RequestedInputWatermarkUtc > @CompletedAtUtc
       OR @RequestedAtUtc > @StartedAtUtc OR @StartedAtUtc > @CompletedAtUtc
       OR @SafeRenderedText IS NULL
        THROW 52510, ''Projection refresh times, watermark, or rendered content are invalid.'', 1;

    DECLARE @Selected table
    (
        [SelectionOrdinal] int NOT NULL PRIMARY KEY,
        [ContentSummaryVersionId] bigint NOT NULL UNIQUE
    );
    INSERT @Selected
    SELECT * FROM OPENJSON(@SelectedContentSummaryVersionsJson) WITH
        ([SelectionOrdinal] int ''$.SelectionOrdinal'', [ContentSummaryVersionId] bigint ''$.ContentSummaryVersionId'');
    IF EXISTS (SELECT 1 FROM @Selected WHERE [SelectionOrdinal] < 0)
       OR (EXISTS (SELECT 1 FROM @Selected)
           AND ((SELECT MIN([SelectionOrdinal]) FROM @Selected) <> 0
                OR (SELECT MAX([SelectionOrdinal]) FROM @Selected) <> (SELECT COUNT_BIG(*) - 1 FROM @Selected)))
        THROW 52511, ''Selected summary ordinals must be zero-based and gap-free.'', 1;

    DECLARE @VersionSequence bigint;
    DECLARE @RefreshSequence bigint;
    DECLARE @RenderingRuleVersionId bigint;
    DECLARE @SelectionPolicyVersionId bigint;
    DECLARE @ClassificationPolicyVersionId bigint;
    DECLARE @ProjectionContractVersion int;
    DECLARE @ProjectionSchemaVersion int;
    DECLARE @SelectedSummarySetFingerprint binary(32);

    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @RenderingRuleVersionId = [RenderingRuleVersionId],
            @SelectionPolicyVersionId = [SelectionPolicyVersionId],
            @ClassificationPolicyVersionId = [ClassificationPolicyVersionId],
            @ProjectionContractVersion = [ProjectionContractVersion],
            @ProjectionSchemaVersion = [ProjectionSchemaVersion]
        FROM [ATAPUtilities].[AgentTextProjection] WITH (UPDLOCK, HOLDLOCK)
        WHERE [AgentTextProjectionId] = @AgentTextProjectionId
          AND ([RetiredAtUtc] IS NULL OR [RetiredAtUtc] > @CompletedAtUtc);
        IF @RenderingRuleVersionId IS NULL
            THROW 52512, ''Projection is absent or retired at publication time.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM @Selected AS [selected]
            LEFT JOIN [ATAPUtilities].[ContentSummaryVersion] AS [summaryVersion]
                ON [summaryVersion].[ContentSummaryVersionId] = [selected].[ContentSummaryVersionId]
            LEFT JOIN [ATAPUtilities].[ContentSummary] AS [summary]
                ON [summary].[ContentSummaryId] = [summaryVersion].[ContentSummaryId]
            LEFT JOIN [ATAPUtilities].[SourceArtifactVersion] AS [sourceVersion]
                ON [sourceVersion].[SourceArtifactVersionId] = [summaryVersion].[SourceArtifactVersionId]
            WHERE [summaryVersion].[ContentSummaryVersionId] IS NULL
               OR [summaryVersion].[LifecycleStateCode] <> ''summarized''
               OR [summaryVersion].[ClassificationPolicyVersionId] <> @ClassificationPolicyVersionId
               OR [summaryVersion].[GeneratedAtUtc] > @RequestedInputWatermarkUtc
               OR [sourceVersion].[SourceArtifactVersionId] IS NULL
               OR [sourceVersion].[SourceArtifactVersionId] > @SourceVersionWatermark
               OR [sourceVersion].[ObservedAtUtc] > @RequestedInputWatermarkUtc
               OR ([summary].[RetiredAtUtc] IS NOT NULL AND [summary].[RetiredAtUtc] <= @CompletedAtUtc)
        )
            THROW 52513, ''Selected summary is beyond the watermark or policy/state incompatible.'', 1;

        SELECT @SelectedSummarySetFingerprint = HASHBYTES
        (
            ''SHA2_256'',
            CONVERT(varbinary(max), COALESCE
            (
                STRING_AGG(CONVERT(varchar(max), CONCAT([SelectionOrdinal], '':'', [ContentSummaryVersionId])), ''|'')
                    WITHIN GROUP (ORDER BY [SelectionOrdinal]),
                ''''
            ))
        )
        FROM @Selected;

        SELECT @VersionSequence = COALESCE(MAX([VersionSequence]), 0) + 1
        FROM [ATAPUtilities].[AgentTextProjectionVersion] WITH (UPDLOCK, HOLDLOCK)
        WHERE [AgentTextProjectionId] = @AgentTextProjectionId;
        SELECT @RefreshSequence = COALESCE(MAX([RefreshSequence]), 0) + 1
        FROM [ATAPUtilities].[AgentTextProjectionRefresh] WITH (UPDLOCK, HOLDLOCK)
        WHERE [AgentTextProjectionId] = @AgentTextProjectionId;

        INSERT [ATAPUtilities].[AgentTextProjectionVersion]
            ([AgentTextProjectionId], [VersionSequence], [MaterializationStateCode], [InputWatermarkUtc],
             [SourceVersionWatermark], [RenderingRuleVersionId], [SelectionPolicyVersionId],
             [ClassificationPolicyVersionId], [ProjectionContractVersion], [ProjectionSchemaVersion],
             [SelectedSummarySetFingerprint], [ProjectionContentHash], [SafeRenderedText], [GeneratedAtUtc])
        VALUES
            (@AgentTextProjectionId, @VersionSequence, ''Current'', @RequestedInputWatermarkUtc,
             @SourceVersionWatermark, @RenderingRuleVersionId, @SelectionPolicyVersionId,
             @ClassificationPolicyVersionId, @ProjectionContractVersion, @ProjectionSchemaVersion,
             @SelectedSummarySetFingerprint, @ProjectionContentHash, @SafeRenderedText, @CompletedAtUtc);
        SET @AgentTextProjectionVersionId = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT [ATAPUtilities].[AgentTextProjectionVersionContentSummaryVersion]
            ([AgentTextProjectionVersionId], [SelectionOrdinal], [ContentSummaryVersionId])
        SELECT @AgentTextProjectionVersionId, [SelectionOrdinal], [ContentSummaryVersionId]
        FROM @Selected;

        IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[AgentTextProjectionVersionContentSummaryVersion]
            WHERE [AgentTextProjectionVersionId] = @AgentTextProjectionVersionId) <> (SELECT COUNT_BIG(*) FROM @Selected)
            THROW 52514, ''Projection publication did not materialize its exact selected-summary set.'', 1;

        INSERT [ATAPUtilities].[AgentTextProjectionRefresh]
            ([AgentTextProjectionId], [RefreshSequence], [RequestedInputWatermarkUtc], [ResultCode],
             [AgentTextProjectionVersionId], [ErrorTaxonomyCode], [NonSecretDiagnosticHash],
             [RequestedAtUtc], [StartedAtUtc], [CompletedAtUtc])
        VALUES
            (@AgentTextProjectionId, @RefreshSequence, @RequestedInputWatermarkUtc, ''succeeded'',
             @AgentTextProjectionVersionId, NULL, NULL, @RequestedAtUtc, @StartedAtUtc, @CompletedAtUtc);
        SET @AgentTextProjectionRefreshId = CONVERT(bigint, SCOPE_IDENTITY());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    IF DATABASE_PRINCIPAL_ID(N'RrsbsPublisher') IS NULL
        CREATE ROLE [RrsbsPublisher] AUTHORIZATION [dbo];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[PolicyVersion] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[ExternalReference] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[Organization] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[Repository] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[RepositoryRootRegistration] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[SourceModule] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[SourceArtifact] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[SourceArtifactVersion] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[SourceArtifactLineage] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[ContentSummary] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[ContentSummaryVersion] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[ContentSummaryDependency] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[AgentTextProjection] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[AgentTextProjectionVersion] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[AgentTextProjectionVersionContentSummaryVersion] TO [RrsbsPublisher];
    DENY INSERT, UPDATE, DELETE ON OBJECT::[ATAPUtilities].[AgentTextProjectionRefresh] TO [RrsbsPublisher];
    GRANT EXECUTE ON OBJECT::[ATAPUtilities].[usp_PublishAgentTextProjectionRefresh] TO [RrsbsPublisher];

    /* Exact RDB-310 retained routine contract, emitted as independent batches. */
    EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [Tags].[usp_GetTagTree]
    @RootTagID int = NULL,
    @MaxDepth int = 100,
    @ActiveOnly bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH [TagTree] AS
    (
        SELECT [TagID], [ParentTagID], [ResourceKey], [DefaultLabel], [IsActive], [SortOrder],
            0 AS [Level],
            CAST(RIGHT(''0000000000'' + CAST([SortOrder] AS varchar(10)), 10) + ''/''
                 + CAST([TagID] AS varchar(10)) AS varchar(max)) AS [TreePath]
        FROM [Tags].[Tags]
        WHERE (@RootTagID IS NULL AND [ParentTagID] IS NULL)
           OR (@RootTagID IS NOT NULL AND [TagID] = @RootTagID)
        UNION ALL
        SELECT [t].[TagID], [t].[ParentTagID], [t].[ResourceKey], [t].[DefaultLabel],
            [t].[IsActive], [t].[SortOrder], [tt].[Level] + 1,
            [tt].[TreePath] + ''/'' + RIGHT(''0000000000'' + CAST([t].[SortOrder] AS varchar(10)), 10)
                + ''/'' + CAST([t].[TagID] AS varchar(10))
        FROM [Tags].[Tags] AS [t]
        INNER JOIN [TagTree] AS [tt] ON [t].[ParentTagID] = [tt].[TagID]
        WHERE [tt].[Level] < @MaxDepth AND (@ActiveOnly = 0 OR [t].[IsActive] = 1)
    )
    SELECT [TagID], [ParentTagID], [ResourceKey], [DefaultLabel], [IsActive], [SortOrder], [Level], [TreePath]
    FROM [TagTree]
    WHERE @ActiveOnly = 0 OR [IsActive] = 1
    ORDER BY [TreePath];
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [Tags].[usp_GetTagAncestors]
    @TagID int,
    @IncludeSelf bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH [Ancestors] AS
    (
        SELECT [TagID], [ParentTagID], [ResourceKey], [DefaultLabel], [SortOrder], 0 AS [Level]
        FROM [Tags].[Tags] WHERE [TagID] = @TagID
        UNION ALL
        SELECT [t].[TagID], [t].[ParentTagID], [t].[ResourceKey], [t].[DefaultLabel],
            [t].[SortOrder], [a].[Level] + 1
        FROM [Tags].[Tags] AS [t]
        INNER JOIN [Ancestors] AS [a] ON [t].[TagID] = [a].[ParentTagID]
    )
    SELECT [TagID], [ParentTagID], [ResourceKey], [DefaultLabel], [SortOrder], [Level]
    FROM [Ancestors]
    WHERE @IncludeSelf = 1 OR [TagID] <> @TagID
    ORDER BY [Level] DESC;
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [Tags].[usp_GetTagDescendants]
    @TagID int,
    @MaxDepth int = 100,
    @IncludeSelf bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH [Descendants] AS
    (
        SELECT [TagID], [ParentTagID], [ResourceKey], [DefaultLabel], [IsActive], [SortOrder], 1 AS [Level]
        FROM [Tags].[Tags] WHERE [ParentTagID] = @TagID
        UNION ALL
        SELECT [t].[TagID], [t].[ParentTagID], [t].[ResourceKey], [t].[DefaultLabel],
            [t].[IsActive], [t].[SortOrder], [d].[Level] + 1
        FROM [Tags].[Tags] AS [t]
        INNER JOIN [Descendants] AS [d] ON [t].[ParentTagID] = [d].[TagID]
        WHERE [d].[Level] < @MaxDepth
    )
    SELECT [TagID], [ParentTagID], [ResourceKey], [DefaultLabel], [IsActive], [SortOrder], [Level]
    FROM [Descendants]
    UNION ALL
    SELECT [TagID], [ParentTagID], [ResourceKey], [DefaultLabel], [IsActive], [SortOrder], 0 AS [Level]
    FROM [Tags].[Tags] WHERE [TagID] = @TagID AND @IncludeSelf = 1
    ORDER BY [Level], [SortOrder];
END;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER VIEW [Tags].[vw_ActiveTags]
AS
SELECT [t].[TagID], [t].[ParentTagID], [t].[ResourceKey], [t].[DefaultLabel], [t].[SortOrder],
    [t].[CreatedDate], [t].[ModifiedDate], [p].[ResourceKey] AS [ParentResourceKey],
    [p].[DefaultLabel] AS [ParentDefaultLabel]
FROM [Tags].[Tags] AS [t]
LEFT JOIN [Tags].[Tags] AS [p] ON [t].[ParentTagID] = [p].[TagID]
WHERE [t].[IsActive] = 1;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER VIEW [Tags].[vw_RootTags]
AS
SELECT [TagID], [ResourceKey], [DefaultLabel], [SortOrder], [IsActive], [CreatedDate]
FROM [Tags].[Tags]
WHERE [ParentTagID] IS NULL AND [IsActive] = 1;';

    EXEC sys.sp_executesql N'
CREATE OR ALTER VIEW [Tags].[vw_TagsWithChildCount]
AS
SELECT [t].[TagID], [t].[ParentTagID], [t].[ResourceKey], [t].[DefaultLabel], [t].[IsActive], [t].[SortOrder],
    (SELECT COUNT(*) FROM [Tags].[Tags] AS [c]
     WHERE [c].[ParentTagID] = [t].[TagID] AND [c].[IsActive] = 1) AS [ChildCount],
    CASE WHEN EXISTS
        (SELECT 1 FROM [Tags].[Tags] AS [c]
         WHERE [c].[ParentTagID] = [t].[TagID] AND [c].[IsActive] = 1)
        THEN 1 ELSE 0 END AS [HasChildren]
FROM [Tags].[Tags] AS [t];';

    EXEC sys.sp_executesql N'
CREATE OR ALTER VIEW [Tags].[vw_TagRelationshipsExpanded]
AS
SELECT [r].[RelationshipID], [r].[SourceTagID], [s].[ResourceKey] AS [SourceResourceKey],
    [s].[DefaultLabel] AS [SourceDefaultLabel], [r].[TargetTagID],
    [t].[ResourceKey] AS [TargetResourceKey], [t].[DefaultLabel] AS [TargetDefaultLabel],
    [r].[RelationshipTypeKey], [r].[IsBidirectional], [r].[Weight], [r].[IsActive]
FROM [Tags].[TagRelationships] AS [r]
INNER JOIN [Tags].[Tags] AS [s] ON [r].[SourceTagID] = [s].[TagID]
INNER JOIN [Tags].[Tags] AS [t] ON [r].[TargetTagID] = [t].[TagID];';

    /* Object-existence postconditions; RDB-480 repeats these after integration. */
    IF EXISTS
    (
        SELECT 1
        FROM (VALUES
            (N'[ATAPUtilities].[PolicyVersion]', N'U'),
            (N'[ATAPUtilities].[ExternalReference]', N'U'),
            (N'[ATAPUtilities].[Organization]', N'U'),
            (N'[ATAPUtilities].[Repository]', N'U'),
            (N'[ATAPUtilities].[RepositoryRootRegistration]', N'U'),
            (N'[ATAPUtilities].[SourceModule]', N'U'),
            (N'[ATAPUtilities].[SourceArtifact]', N'U'),
            (N'[ATAPUtilities].[SourceArtifactVersion]', N'U'),
            (N'[ATAPUtilities].[SourceArtifactLineage]', N'U'),
            (N'[ATAPUtilities].[ContentSummary]', N'U'),
            (N'[ATAPUtilities].[ContentSummaryVersion]', N'U'),
            (N'[ATAPUtilities].[ContentSummaryDependency]', N'U'),
            (N'[ATAPUtilities].[AgentTextProjection]', N'U'),
            (N'[ATAPUtilities].[AgentTextProjectionVersion]', N'U'),
            (N'[ATAPUtilities].[AgentTextProjectionVersionContentSummaryVersion]', N'U'),
            (N'[ATAPUtilities].[AgentTextProjectionRefresh]', N'U'),
            (N'[Tags].[Tags]', N'U'),
            (N'[Tags].[TagAliases]', N'U'),
            (N'[Tags].[RelationshipTypes]', N'U'),
            (N'[Tags].[TagRelationships]', N'U'),
            (N'[Gmail].[gmailMessages]', N'U'),
            (N'[Tags].[vw_ActiveTags]', N'V'),
            (N'[Tags].[vw_RootTags]', N'V'),
            (N'[Tags].[vw_TagsWithChildCount]', N'V'),
            (N'[Tags].[vw_TagRelationshipsExpanded]', N'V'),
            (N'[Tags].[usp_GetTagTree]', N'P'),
            (N'[Tags].[usp_GetTagAncestors]', N'P'),
            (N'[Tags].[usp_GetTagDescendants]', N'P'),
            (N'[ATAPUtilities].[usp_PublishAgentTextProjectionRefresh]', N'P'),
            (N'[ATAPUtilities].[TR_PolicyVersion_Immutable]', N'TR'),
            (N'[ATAPUtilities].[TR_ExternalReference_ImmutableControlled]', N'TR'),
            (N'[ATAPUtilities].[TR_SourceModule_ValidateHierarchy]', N'TR'),
            (N'[ATAPUtilities].[TR_Organization_ImmutableIdentity]', N'TR'),
            (N'[ATAPUtilities].[TR_Repository_ImmutableIdentity]', N'TR'),
            (N'[ATAPUtilities].[TR_RepositoryRootRegistration_Immutable]', N'TR'),
            (N'[ATAPUtilities].[TR_SourceArtifact_ImmutableIdentity]', N'TR'),
            (N'[ATAPUtilities].[TR_ContentSummary_ImmutableIdentity]', N'TR'),
            (N'[ATAPUtilities].[TR_AgentTextProjection_ImmutableIdentity]', N'TR'),
            (N'[ATAPUtilities].[TR_SourceArtifactVersion_AppendOnly]', N'TR'),
            (N'[ATAPUtilities].[TR_SourceArtifactLineage_AppendOnly]', N'TR'),
            (N'[ATAPUtilities].[TR_ContentSummaryVersion_AppendOnlyIntegrity]', N'TR'),
            (N'[ATAPUtilities].[TR_ContentSummaryDependency_AppendOnlyIntegrity]', N'TR'),
            (N'[ATAPUtilities].[TR_AgentTextProjectionVersion_AppendOnly]', N'TR'),
            (N'[ATAPUtilities].[TR_AgentTextProjectionRefresh_AppendOnly]', N'TR'),
            (N'[ATAPUtilities].[TR_AgentTextProjectionVersionContentSummaryVersion_AppendOnly]', N'TR')
        ) AS [required] ([ObjectName], [ObjectType])
        WHERE OBJECT_ID([required].[ObjectName], [required].[ObjectType]) IS NULL
    )
        THROW 52470, 'RDB-460/470 postcondition failed: a required object is absent.', 1;

    IF @Rdb460OwnsTransaction = 1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @Rdb460OwnsTransaction = 1 AND XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    ELSE IF @Rdb460OwnsTransaction = 0 AND XACT_STATE() = 1
        ROLLBACK TRANSACTION Rdb460Fragment;
    THROW;
END CATCH;
/* RDB-480 approved isolated fixture topology. Trigger-rejection cases run one
   per fresh transaction so an expected trigger THROW cannot poison a shared
   schema or sibling-fixture transaction. */
DECLARE @RunRdb460Fixtures bit =
    CASE WHEN TRY_CONVERT(int, SESSION_CONTEXT(N'RRSBS_RUN_RDB460_FIXTURES')) = 1 THEN 1 ELSE 0 END;
IF @RunRdb460Fixtures = 1
BEGIN
    SET XACT_ABORT OFF;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @Rdb460FixtureCase varchar(64) = COALESCE(
            TRY_CONVERT(varchar(64), SESSION_CONTEXT(N'RRSBS_RDB460_FIXTURE_CASE')),
            'gap-version');
        IF @Rdb460FixtureCase NOT IN
           ('gap-version', 'duplicate-root', 'invalid-path', 'summary-source-mismatch',
            'excluded-content', 'append-only', 'tag-self')
            THROW 52507, 'Unknown RDB-460 fixture case.', 1;
        DECLARE @Rdb460FixtureNow datetime2(7) = SYSUTCDATETIME();
        INSERT INTO [ATAPUtilities].[EntityType]
            ([EntityTypeCode], [OwningSliceCode], [IsVersionType])
        SELECT [v].[EntityTypeCode], 'RDB-260', CONVERT(bit, 0)
        FROM (VALUES
            ('organization'),
            ('repository'),
            ('source-artifact'),
            ('content-summary'),
            ('agent-text-projection')
        ) AS [v] ([EntityTypeCode])
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [ATAPUtilities].[EntityType] AS [et]
            WHERE [et].[EntityTypeCode] = [v].[EntityTypeCode]
        );

        DECLARE @OrganizationTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'organization');
        DECLARE @RepositoryTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'repository');
        DECLARE @Rdb460ArtifactTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'source-artifact');
        DECLARE @SummaryTypeId bigint =
            (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'content-summary');

        IF @OrganizationTypeId IS NULL OR @RepositoryTypeId IS NULL
           OR @Rdb460ArtifactTypeId IS NULL OR @SummaryTypeId IS NULL
            THROW 52469, 'RDB-460 fixtures require frozen EntityType rows from RDB-400/410.', 1;

        INSERT INTO [ATAPUtilities].[PolicyVersion]
            ([PolicyKindCode], [PolicyCode], [RevisionSequence], [PolicyContractHash], [PublishedAtUtc])
        VALUES
            ('classification', 'rdb460-fixture', 1, HASHBYTES('SHA2_256', 'classification'), @Rdb460FixtureNow),
            ('selection', 'rdb460-fixture', 1, HASHBYTES('SHA2_256', 'selection'), @Rdb460FixtureNow),
            ('redaction', 'rdb460-fixture', 1, HASHBYTES('SHA2_256', 'redaction'), @Rdb460FixtureNow),
            ('acceptance', 'rdb460-fixture', 1, HASHBYTES('SHA2_256', 'acceptance'), @Rdb460FixtureNow),
            ('projection-owner', 'rdb460-fixture', 1, HASHBYTES('SHA2_256', 'projection-owner'), @Rdb460FixtureNow);
        DECLARE @ClassificationPolicyVersionId bigint =
            (SELECT [PolicyVersionId] FROM [ATAPUtilities].[PolicyVersion] WHERE [PolicyKindCode] = 'classification' AND [PolicyCode] = 'rdb460-fixture');
        DECLARE @RedactionPolicyVersionId bigint =
            (SELECT [PolicyVersionId] FROM [ATAPUtilities].[PolicyVersion] WHERE [PolicyKindCode] = 'redaction' AND [PolicyCode] = 'rdb460-fixture');
        DECLARE @AcceptancePolicyVersionId bigint =
            (SELECT [PolicyVersionId] FROM [ATAPUtilities].[PolicyVersion] WHERE [PolicyKindCode] = 'acceptance' AND [PolicyCode] = 'rdb460-fixture');

        DECLARE @OrganizationPhilote uniqueidentifier = '46000000-0000-0000-0000-000000000001';
        INSERT INTO [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@OrganizationTypeId, @OrganizationPhilote, @Rdb460FixtureNow);
        DECLARE @OrganizationEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[Organization]
            ([OrganizationPhiloteId], [EntityId], [EntityTypeId], [CanonicalName],
             [ClassificationPolicyVersionId], [CreatedAtUtc])
        VALUES (@OrganizationPhilote, @OrganizationEntityId, @OrganizationTypeId,
                N'rdb-460-fixture-organization', @ClassificationPolicyVersionId, @Rdb460FixtureNow);
        DECLARE @OrganizationId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        DECLARE @RepositoryPhilote uniqueidentifier = '46000000-0000-0000-0000-000000000002';
        INSERT INTO [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@RepositoryTypeId, @RepositoryPhilote, @Rdb460FixtureNow);
        DECLARE @RepositoryEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[Repository]
            ([RepositoryPhiloteId], [EntityId], [EntityTypeId], [OrganizationId],
             [CanonicalRepositoryName], [ClassificationPolicyVersionId], [CreatedAtUtc])
        VALUES (@RepositoryPhilote, @RepositoryEntityId, @RepositoryTypeId,
                @OrganizationId, N'rdb-460-fixture-repository', @ClassificationPolicyVersionId, @Rdb460FixtureNow);
        DECLARE @RepositoryId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        DECLARE @OtherRepositoryPhilote uniqueidentifier = '46000000-0000-0000-0000-000000000003';
        INSERT INTO [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@RepositoryTypeId, @OtherRepositoryPhilote, @Rdb460FixtureNow);
        DECLARE @OtherRepositoryEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[Repository]
            ([RepositoryPhiloteId], [EntityId], [EntityTypeId], [OrganizationId],
             [CanonicalRepositoryName], [ClassificationPolicyVersionId], [CreatedAtUtc])
        VALUES (@OtherRepositoryPhilote, @OtherRepositoryEntityId, @RepositoryTypeId,
                @OrganizationId, N'rdb-460-fixture-other-repository', @ClassificationPolicyVersionId, @Rdb460FixtureNow);
        DECLARE @OtherRepositoryId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT INTO [ATAPUtilities].[RepositoryRootRegistration]
            ([RepositoryId], [NormalizedAbsoluteRoot], [NormalizedAbsoluteRootHash], [RootKindCode], [RegisteredAtUtc], [RegistrarEvidenceReference])
        VALUES
            (@RepositoryId, N'c:\rdb460-fixture\stable', HASHBYTES('SHA2_256', CONVERT(varbinary(max), N'c:\rdb460-fixture\stable')), 'stable', @Rdb460FixtureNow, N'fixture:root:stable'),
            (@RepositoryId, N'c:\rdb460-fixture\sprint', HASHBYTES('SHA2_256', CONVERT(varbinary(max), N'c:\rdb460-fixture\sprint')), 'sprint', @Rdb460FixtureNow, N'fixture:root:sprint');

        INSERT INTO [ATAPUtilities].[SourceModule]
            ([RepositoryId], [ModuleRelativePath], [ModuleRelativePathHash], [ModuleKindCode], [DiscoveredAtUtc])
        VALUES (@RepositoryId, N'src/module', HASHBYTES('SHA2_256', CONVERT(varbinary(max), N'src/module')), 'source-module', @Rdb460FixtureNow);
        DECLARE @SourceModuleId bigint = CONVERT(bigint, SCOPE_IDENTITY());

        DECLARE @ArtifactPhiloteA uniqueidentifier = '46000000-0000-0000-0000-000000000004';
        INSERT INTO [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@Rdb460ArtifactTypeId, @ArtifactPhiloteA, @Rdb460FixtureNow);
        DECLARE @ArtifactEntityIdA bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[SourceArtifact]
            ([SourceArtifactPhiloteId], [EntityId], [EntityTypeId], [RepositoryId], [SourceModuleId],
             [LocatorTypeCode], [RepoRelativePathOrExternalLocator], [LocatorIdentityHash], [LocatorNormalizerIdentityReference],
             [CreatedAtUtc])
        VALUES (@ArtifactPhiloteA, @ArtifactEntityIdA, @Rdb460ArtifactTypeId, @RepositoryId, @SourceModuleId,
                'RepositoryPath', N'src/module/a.sql', HASHBYTES('SHA2_256', CONVERT(varbinary(max), N'src/module/a.sql')), N'fixture:path-normalizer:v1', @Rdb460FixtureNow);
        DECLARE @ArtifactIdA bigint = CONVERT(bigint, SCOPE_IDENTITY());

        DECLARE @ArtifactPhiloteB uniqueidentifier = '46000000-0000-0000-0000-000000000005';
        INSERT INTO [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@Rdb460ArtifactTypeId, @ArtifactPhiloteB, @Rdb460FixtureNow);
        DECLARE @ArtifactEntityIdB bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[SourceArtifact]
            ([SourceArtifactPhiloteId], [EntityId], [EntityTypeId], [RepositoryId], [SourceModuleId],
             [LocatorTypeCode], [RepoRelativePathOrExternalLocator], [LocatorIdentityHash], [LocatorNormalizerIdentityReference],
             [CreatedAtUtc])
        VALUES (@ArtifactPhiloteB, @ArtifactEntityIdB, @Rdb460ArtifactTypeId, @RepositoryId, @SourceModuleId,
                'RepositoryPath', N'src/module/b.sql', HASHBYTES('SHA2_256', CONVERT(varbinary(max), N'src/module/b.sql')), N'fixture:path-normalizer:v1', @Rdb460FixtureNow);
        DECLARE @ArtifactIdB bigint = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT INTO [ATAPUtilities].[SourceArtifactVersion]
            ([SourceArtifactId], [VersionSequence], [NormalizedContentSha256], [ByteSha256],
             [ByteCount], [EncodingCode], [BomPresent], [LineEndingCode], [HasFinalNewline],
             [ExtractorIdentityReference], [HarvesterIdentity], [ObservedAtUtc], [ProvenanceFingerprint])
        VALUES (@ArtifactIdA, 1, REPLICATE('a', 64), REPLICATE('c', 64), 1, 'utf-8', 0, 'lf', 1,
                N'fixture:extractor', N'fixture:harvester', @Rdb460FixtureNow, HASHBYTES('SHA2_256', N'rdb460:a'));
        DECLARE @ArtifactVersionIdA bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[SourceArtifactVersion]
            ([SourceArtifactId], [VersionSequence], [NormalizedContentSha256], [ByteSha256],
             [ByteCount], [EncodingCode], [BomPresent], [LineEndingCode], [HasFinalNewline],
             [ExtractorIdentityReference], [HarvesterIdentity], [ObservedAtUtc], [ProvenanceFingerprint])
        VALUES (@ArtifactIdB, 1, REPLICATE('b', 64), REPLICATE('d', 64), 1, 'utf-8', 0, 'lf', 1,
                N'fixture:extractor', N'fixture:harvester', @Rdb460FixtureNow, HASHBYTES('SHA2_256', N'rdb460:b'));
        DECLARE @ArtifactVersionIdB bigint = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT INTO [ATAPUtilities].[SourceArtifactLineage]
            ([PredecessorSourceArtifactId], [PredecessorRepositoryId], [SuccessorSourceArtifactId],
             [SuccessorRepositoryId], [RelationKindCode], [AcceptancePolicyVersionId],
             [AcceptedByEntityId], [AcceptedByEntityTypeId], [AcceptanceEvidenceReference],
             [ProposalEvidenceReference], [AcceptedAtUtc])
        VALUES (@ArtifactIdA, @RepositoryId, @ArtifactIdB, @RepositoryId, 'RenamedFrom', @AcceptancePolicyVersionId,
                @OrganizationEntityId, @OrganizationTypeId, N'fixture:lineage-acceptance',
                N'fixture:lineage-proposal', @Rdb460FixtureNow);

        DECLARE @SummaryPhilote uniqueidentifier = '46000000-0000-0000-0000-000000000006';
        INSERT INTO [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@SummaryTypeId, @SummaryPhilote, @Rdb460FixtureNow);
        DECLARE @SummaryEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[ContentSummary]
            ([ContentSummaryPhiloteId], [EntityId], [EntityTypeId], [SourceArtifactId],
             [SummaryProfileCode], [ClassificationPolicyVersionId], [CreatedAtUtc])
        VALUES (@SummaryPhilote, @SummaryEntityId, @SummaryTypeId, @ArtifactIdA,
                'fixture-safe', @ClassificationPolicyVersionId, @Rdb460FixtureNow);
        DECLARE @ContentSummaryId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[ContentSummaryVersion]
            ([ContentSummaryId], [SourceArtifactId], [SourceArtifactVersionId], [ClassificationPolicyVersionId],
             [VersionSequence], [LifecycleStateCode], [GeneratedAtUtc])
        VALUES (@ContentSummaryId, @ArtifactIdA, @ArtifactVersionIdA, @ClassificationPolicyVersionId, 1, 'harvested', @Rdb460FixtureNow);
        DECLARE @ContentSummaryVersionId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        INSERT INTO [ATAPUtilities].[ContentSummaryDependency]
            ([ContentSummaryVersionId], [DependencyOrdinal], [DependencyKindCode], [SourceArtifactVersionId],
             [CapturedAtUtc], [EvidenceIdentityReference])
        VALUES (@ContentSummaryVersionId, 0, 'primary-source', @ArtifactVersionIdA,
                @Rdb460FixtureNow, N'fixture:dependency-evidence');

        DECLARE @RootTagId int;
        INSERT INTO [Tags].[Tags] ([ResourceKey], [DefaultLabel])
        VALUES ('rdb460.fixture.root', N'RDB-460 fixture root');
        SET @RootTagId = CONVERT(int, SCOPE_IDENTITY());
        INSERT INTO [Tags].[Tags] ([ParentTagID], [ResourceKey], [DefaultLabel])
        VALUES (@RootTagId, 'rdb460.fixture.child', N'RDB-460 fixture child');
        DECLARE @ChildTagId int = CONVERT(int, SCOPE_IDENTITY());
        INSERT INTO [Tags].[RelationshipTypes] ([ResourceKey]) VALUES ('rdb460.fixture.related');
        INSERT INTO [Tags].[TagRelationships]
            ([SourceTagID], [TargetTagID], [RelationshipTypeKey])
        VALUES (@RootTagId, @ChildTagId, 'rdb460.fixture.related');
        INSERT INTO [Gmail].[gmailMessages]
            ([Subject], [MessageId], [FromAddress], [ToAddress], [Date], [Labels], [Body], [URL])
        VALUES (N'RDB-460 fixture', N'<rdb460@example.invalid>', N'sender@example.invalid',
                N'recipient@example.invalid', @Rdb460FixtureNow, N'fixture', N'rollback-only',
                N'https://example.invalid/rdb460');        IF @Rdb460FixtureCase = 'gap-version'
        BEGIN
BEGIN TRY
            INSERT INTO [ATAPUtilities].[SourceArtifactVersion]
                ([SourceArtifactId], [VersionSequence], [NormalizedContentSha256], [ByteCount],
                 [EncodingCode], [BomPresent], [LineEndingCode], [HasFinalNewline],
                 [ExtractorIdentityReference], [HarvesterIdentity], [ObservedAtUtc], [ProvenanceFingerprint])
            VALUES (@ArtifactIdA, 3, REPLICATE('e', 64), 1, 'utf-8', 0, 'lf', 1,
                    N'fixture:extractor', N'fixture:harvester', @Rdb460FixtureNow,
                    HASHBYTES('SHA2_256', N'rdb460:gap'));
            THROW 52506, 'Expected gap-free source-version rejection was not raised.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 52506 THROW;
        END CATCH;
        END;        IF @Rdb460FixtureCase = 'duplicate-root'
        BEGIN
/* Negative I-18: an active normalized root cannot identify two repositories. */
        BEGIN TRY
            INSERT INTO [ATAPUtilities].[RepositoryRootRegistration]
                ([RepositoryId], [NormalizedAbsoluteRoot], [NormalizedAbsoluteRootHash], [RootKindCode], [RegisteredAtUtc], [RegistrarEvidenceReference])
            VALUES (@OtherRepositoryId, N'c:\rdb460-fixture\stable', HASHBYTES('SHA2_256', CONVERT(varbinary(max), N'c:\rdb460-fixture\stable')), 'stable', @Rdb460FixtureNow, N'fixture:duplicate-root');
            THROW 52500, 'Expected duplicate active root rejection was not raised.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 52500 THROW;
        END CATCH;
        END;        IF @Rdb460FixtureCase = 'invalid-path'
        BEGIN
/* Negative path identity: repository paths cannot be rooted, traversing, or backslash-based. */
        DECLARE @InvalidArtifactPhilote uniqueidentifier = '46000000-0000-0000-0000-000000000099';
        INSERT INTO [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@Rdb460ArtifactTypeId, @InvalidArtifactPhilote, @Rdb460FixtureNow);
        DECLARE @InvalidArtifactEntityId bigint = CONVERT(bigint, SCOPE_IDENTITY());
        BEGIN TRY
            INSERT INTO [ATAPUtilities].[SourceArtifact]
                ([SourceArtifactPhiloteId], [EntityId], [EntityTypeId], [RepositoryId],
                 [LocatorTypeCode], [RepoRelativePathOrExternalLocator], [LocatorIdentityHash], [LocatorNormalizerIdentityReference],
                 [CreatedAtUtc])
            VALUES (@InvalidArtifactPhilote, @InvalidArtifactEntityId, @Rdb460ArtifactTypeId,
                    @RepositoryId, 'RepositoryPath', N'..\escape.sql', HASHBYTES('SHA2_256', CONVERT(varbinary(max), N'..\escape.sql')), N'fixture:path-normalizer:v1', @Rdb460FixtureNow);
            THROW 52501, 'Expected invalid repository path rejection was not raised.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 52501 THROW;
        END CATCH;
        END;        IF @Rdb460FixtureCase = 'summary-source-mismatch'
        BEGIN
/* Negative I-19: the selected source version must belong to the summary artifact. */
        BEGIN TRY
            INSERT INTO [ATAPUtilities].[ContentSummaryVersion]
                ([ContentSummaryId], [SourceArtifactId], [SourceArtifactVersionId], [ClassificationPolicyVersionId],
                 [VersionSequence], [PredecessorContentSummaryVersionId], [LifecycleStateCode],
                 [RedactionPolicyVersionId], [GeneratedAtUtc])
            VALUES (@ContentSummaryId, @ArtifactIdA, @ArtifactVersionIdB, @ClassificationPolicyVersionId, 2,
                    @ContentSummaryVersionId, 'retired', @RedactionPolicyVersionId, @Rdb460FixtureNow);
            THROW 52502, 'Expected summary/source mismatch rejection was not raised.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 52502 THROW;
        END CATCH;
        END;        IF @Rdb460FixtureCase = 'excluded-content'
        BEGIN
/* Negative I-20: excluded summaries carry evidence, never safe rendered content. */
        BEGIN TRY
            INSERT INTO [ATAPUtilities].[ContentSummaryVersion]
                ([ContentSummaryId], [SourceArtifactId], [SourceArtifactVersionId], [ClassificationPolicyVersionId],
                 [VersionSequence], [PredecessorContentSummaryVersionId], [LifecycleStateCode],
                 [RedactionPolicyVersionId], [ExclusionEvidenceReference], [SafeRenderedText], [GeneratedAtUtc])
            VALUES (@ContentSummaryId, @ArtifactIdA, @ArtifactVersionIdA, @ClassificationPolicyVersionId, 2,
                    @ContentSummaryVersionId, 'excluded', @RedactionPolicyVersionId, N'fixture:excluded', N'unsafe', @Rdb460FixtureNow);
            THROW 52503, 'Expected excluded-content rejection was not raised.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 52503 THROW;
        END CATCH;
        END;        IF @Rdb460FixtureCase = 'append-only'
        BEGIN
/* Negative append-only and retained no-self contracts. */
        BEGIN TRY
            UPDATE [ATAPUtilities].[SourceArtifactVersion]
            SET [ByteCount] = [ByteCount] + 1
            WHERE [SourceArtifactVersionId] = @ArtifactVersionIdA;
            THROW 52504, 'Expected append-only rejection was not raised.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 52504 THROW;
        END CATCH;
        END;        IF @Rdb460FixtureCase = 'tag-self'
        BEGIN
BEGIN TRY
            INSERT INTO [Tags].[TagRelationships]
                ([SourceTagID], [TargetTagID], [RelationshipTypeKey])
            VALUES (@RootTagId, @RootTagId, 'rdb460.fixture.related');
            THROW 52505, 'Expected tag self-relationship rejection was not raised.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 52505 THROW;
        END CATCH;
        END;


        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET XACT_ABORT ON;
        THROW;
    END CATCH;
    SET XACT_ABORT ON;
END;
/* END INTEGRATED FRAGMENT: RDB-460-470__Context-Content-Retained.sql */
/* RDB-480 deferred exact-version foreign keys: the consumer is created in
   RDB-400/410 and the table-addressable parent is created in RDB-460. */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE [name] = N'FK_RuleKindVersion_SourceArtifactVersion_Grammar'
      AND [parent_object_id] = OBJECT_ID(N'[ATAPUtilities].[RuleKindVersion]')
)
    ALTER TABLE [ATAPUtilities].[RuleKindVersion]
        ADD CONSTRAINT [FK_RuleKindVersion_SourceArtifactVersion_Grammar]
        FOREIGN KEY ([GrammarSourceArtifactVersionId])
        REFERENCES [ATAPUtilities].[SourceArtifactVersion] ([SourceArtifactVersionId]);

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE [name] = N'FK_RuleKindVersion_SourceArtifactVersion_Compendium'
      AND [parent_object_id] = OBJECT_ID(N'[ATAPUtilities].[RuleKindVersion]')
)
    ALTER TABLE [ATAPUtilities].[RuleKindVersion]
        ADD CONSTRAINT [FK_RuleKindVersion_SourceArtifactVersion_Compendium]
        FOREIGN KEY ([CompendiumSourceArtifactVersionId])
        REFERENCES [ATAPUtilities].[SourceArtifactVersion] ([SourceArtifactVersionId]);
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;


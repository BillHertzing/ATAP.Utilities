/*
  Sprint 0015 Tasks 15.60.c/.e: controlled ContentSummary provisioning and correction.
  V00100 and V00110 remain immutable. This forward boundary admits only catalogued
  operational identities, one immutable prompt RuleVariant, canonical Windows roots,
  procedure-only writers, and append/close retirement or correction.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'[ATAPUtilities].[Repository]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RepositoryRootRegistration]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[ContentSummaryVersion]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[CaptureContentSummaryObservationV1]', N'P') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[QueryContentSummaryCandidatesForMcpV1]', N'P') IS NULL
        THROW 60400, 'V00120 requires the successful V00010-V00110 predecessor chain.', 1;

    IF OBJECT_ID(N'[ATAPUtilities].[ContentSummaryOperationalIdentity]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RepositoryOriginEvidence]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RepositoryRootCanonicalIdentity]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[ContentSummaryRepositoryRootCorrection]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[ContentSummaryRepositoryRetirementEvidence]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[ContentSummaryAuthorizationRetirementEvidence]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[ProvisionContentSummaryRepositoryV1]', N'P') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[AssignContentSummaryVersionTagV1]', N'P') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[AuthorizeContentSummaryDatabasePrincipalRepositoryV1]', N'P') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RetireContentSummaryRepositoryV1]', N'P') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[CorrectContentSummaryRepositoryRootV1]', N'P') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RetireContentSummaryDatabasePrincipalRepositoryAuthorizationV1]', N'P') IS NOT NULL
       OR DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryProvisioner') IS NOT NULL
        THROW 60401, 'V00120 object or role collision detected.', 1;

    CREATE TABLE [ATAPUtilities].[ContentSummaryOperationalIdentity]
    (
        [OperationalIdentityId] uniqueidentifier NOT NULL,
        [PhiloteId] uniqueidentifier NOT NULL,
        [IdentityKindCode] varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [IdentityCode] nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [SourceReference] nvarchar(512) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_ContentSummaryOperationalIdentity] PRIMARY KEY ([OperationalIdentityId]),
        CONSTRAINT [FK_ContentSummaryOperationalIdentity_Philote] FOREIGN KEY ([PhiloteId])
            REFERENCES [ATAPUtilities].[Philote] ([PhiloteId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_ContentSummaryOperationalIdentity_Philote] UNIQUE ([PhiloteId]),
        CONSTRAINT [UQ_ContentSummaryOperationalIdentity_KindCode] UNIQUE ([IdentityKindCode], [IdentityCode]),
        CONSTRAINT [UQ_ContentSummaryOperationalIdentity_IdKind] UNIQUE ([OperationalIdentityId], [IdentityKindCode]),
        CONSTRAINT [CK_ContentSummaryOperationalIdentity_PhiloteEqualsId] CHECK ([OperationalIdentityId]=[PhiloteId]),
        CONSTRAINT [CK_ContentSummaryOperationalIdentity_Kind] CHECK
            ([IdentityKindCode] IN ('Organization','ClassificationPolicy','PrincipalRegistrar','Evidence','Harvester')),
        CONSTRAINT [CK_ContentSummaryOperationalIdentity_Text] CHECK
            (DATALENGTH([IdentityCode])>0 AND DATALENGTH([SourceReference])>0)
    );

    CREATE TABLE [ATAPUtilities].[RepositoryOriginEvidence]
    (
        [RepositoryId] uniqueidentifier NOT NULL,
        [CanonicalOriginUri] nvarchar(2048) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [EvidenceEntityId] uniqueidentifier NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_RepositoryOriginEvidence] PRIMARY KEY ([RepositoryId]),
        CONSTRAINT [FK_RepositoryOriginEvidence_Repository] FOREIGN KEY ([RepositoryId])
            REFERENCES [ATAPUtilities].[Repository] ([RepositoryId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_RepositoryOriginEvidence_Evidence] FOREIGN KEY ([EvidenceEntityId], [EvidenceKindCode])
            REFERENCES [ATAPUtilities].[ContentSummaryOperationalIdentity] ([OperationalIdentityId], [IdentityKindCode]),
        [EvidenceKindCode] AS (CONVERT(varchar(32),'Evidence') COLLATE Latin1_General_100_BIN2) PERSISTED,
        [CanonicalOriginUriSha256] AS CONVERT(binary(32),HASHBYTES('SHA2_256',CONVERT(varbinary(max),[CanonicalOriginUri]))) PERSISTED,
        CONSTRAINT [UQ_RepositoryOriginEvidence_UriHash] UNIQUE ([CanonicalOriginUriSha256]),
        CONSTRAINT [CK_RepositoryOriginEvidence_Uri] CHECK
            (DATALENGTH([CanonicalOriginUri])>0 AND [CanonicalOriginUri] LIKE N'https://%'
             AND RIGHT([CanonicalOriginUri],1)<>N'/')
    );

    CREATE TABLE [ATAPUtilities].[RepositoryRootCanonicalIdentity]
    (
        [RepositoryRootRegistrationId] uniqueidentifier NOT NULL,
        [CanonicalWindowsRoot] nvarchar(1024) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_RepositoryRootCanonicalIdentity] PRIMARY KEY ([RepositoryRootRegistrationId]),
        CONSTRAINT [FK_RepositoryRootCanonicalIdentity_Root] FOREIGN KEY ([RepositoryRootRegistrationId])
            REFERENCES [ATAPUtilities].[RepositoryRootRegistration] ([RepositoryRootRegistrationId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        [CanonicalWindowsRootSha256] AS CONVERT(binary(32),HASHBYTES('SHA2_256',CONVERT(varbinary(max),[CanonicalWindowsRoot]))) PERSISTED,
        CONSTRAINT [UQ_RepositoryRootCanonicalIdentity_RootHash] UNIQUE ([CanonicalWindowsRootSha256]),
        CONSTRAINT [CK_RepositoryRootCanonicalIdentity_WindowsRoot] CHECK
            ([CanonicalWindowsRoot] LIKE N'[a-z]:\%'
             AND CHARINDEX(N'/',[CanonicalWindowsRoot])=0
             AND CHARINDEX(N'\\',[CanonicalWindowsRoot])=0
             AND CHARINDEX(N'\.\',N'\'+[CanonicalWindowsRoot]+N'\')=0
             AND CHARINDEX(N'\..\',N'\'+[CanonicalWindowsRoot]+N'\')=0
             AND (LEN([CanonicalWindowsRoot])=3 OR RIGHT([CanonicalWindowsRoot],1)<>N'\'))
    );

    CREATE TABLE [ATAPUtilities].[ContentSummaryRepositoryRootCorrection]
    (
        [CorrectionId] uniqueidentifier NOT NULL,
        [RepositoryId] uniqueidentifier NOT NULL,
        [PriorRepositoryRootRegistrationId] uniqueidentifier NOT NULL,
        [SuccessorRepositoryRootRegistrationId] uniqueidentifier NOT NULL,
        [PrincipalId] uniqueidentifier NOT NULL,
        [EvidenceEntityId] uniqueidentifier NOT NULL,
        [Reason] nvarchar(1024) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_ContentSummaryRepositoryRootCorrection] PRIMARY KEY ([CorrectionId]),
        CONSTRAINT [FK_ContentSummaryRepositoryRootCorrection_Repository] FOREIGN KEY ([RepositoryId])
            REFERENCES [ATAPUtilities].[Repository] ([RepositoryId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummaryRepositoryRootCorrection_Prior] FOREIGN KEY ([PriorRepositoryRootRegistrationId])
            REFERENCES [ATAPUtilities].[RepositoryRootRegistration] ([RepositoryRootRegistrationId]),
        CONSTRAINT [FK_ContentSummaryRepositoryRootCorrection_Successor] FOREIGN KEY ([SuccessorRepositoryRootRegistrationId])
            REFERENCES [ATAPUtilities].[RepositoryRootRegistration] ([RepositoryRootRegistrationId]),
        CONSTRAINT [FK_ContentSummaryRepositoryRootCorrection_Principal] FOREIGN KEY ([PrincipalId], [PrincipalKindCode])
            REFERENCES [ATAPUtilities].[ContentSummaryOperationalIdentity] ([OperationalIdentityId], [IdentityKindCode]),
        CONSTRAINT [FK_ContentSummaryRepositoryRootCorrection_Evidence] FOREIGN KEY ([EvidenceEntityId], [EvidenceKindCode])
            REFERENCES [ATAPUtilities].[ContentSummaryOperationalIdentity] ([OperationalIdentityId], [IdentityKindCode]),
        [PrincipalKindCode] AS (CONVERT(varchar(32),'PrincipalRegistrar') COLLATE Latin1_General_100_BIN2) PERSISTED,
        [EvidenceKindCode] AS (CONVERT(varchar(32),'Evidence') COLLATE Latin1_General_100_BIN2) PERSISTED,
        CONSTRAINT [UQ_ContentSummaryRepositoryRootCorrection_Prior] UNIQUE ([PriorRepositoryRootRegistrationId]),
        CONSTRAINT [UQ_ContentSummaryRepositoryRootCorrection_Successor] UNIQUE ([SuccessorRepositoryRootRegistrationId]),
        CONSTRAINT [CK_ContentSummaryRepositoryRootCorrection_Distinct] CHECK
            ([PriorRepositoryRootRegistrationId]<>[SuccessorRepositoryRootRegistrationId]),
        CONSTRAINT [CK_ContentSummaryRepositoryRootCorrection_Reason] CHECK (DATALENGTH([Reason])>0)
    );

    CREATE TABLE [ATAPUtilities].[ContentSummaryRepositoryRetirementEvidence]
    (
        [RepositoryId] uniqueidentifier NOT NULL,
        [RetiredAtUtc] datetime2(7) NOT NULL,
        [PrincipalId] uniqueidentifier NOT NULL,
        [EvidenceEntityId] uniqueidentifier NOT NULL,
        [Reason] nvarchar(1024) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        [PrincipalKindCode] AS (CONVERT(varchar(32),'PrincipalRegistrar') COLLATE Latin1_General_100_BIN2) PERSISTED,
        [EvidenceKindCode] AS (CONVERT(varchar(32),'Evidence') COLLATE Latin1_General_100_BIN2) PERSISTED,
        CONSTRAINT [PK_ContentSummaryRepositoryRetirementEvidence] PRIMARY KEY ([RepositoryId]),
        CONSTRAINT [FK_ContentSummaryRepositoryRetirementEvidence_Repository] FOREIGN KEY ([RepositoryId])
            REFERENCES [ATAPUtilities].[Repository] ([RepositoryId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummaryRepositoryRetirementEvidence_Principal] FOREIGN KEY ([PrincipalId], [PrincipalKindCode])
            REFERENCES [ATAPUtilities].[ContentSummaryOperationalIdentity] ([OperationalIdentityId], [IdentityKindCode]),
        CONSTRAINT [FK_ContentSummaryRepositoryRetirementEvidence_Evidence] FOREIGN KEY ([EvidenceEntityId], [EvidenceKindCode])
            REFERENCES [ATAPUtilities].[ContentSummaryOperationalIdentity] ([OperationalIdentityId], [IdentityKindCode]),
        CONSTRAINT [CK_ContentSummaryRepositoryRetirementEvidence_Reason] CHECK (DATALENGTH([Reason])>0),
        CONSTRAINT [CK_ContentSummaryRepositoryRetirementEvidence_Time] CHECK ([RetiredAtUtc]=[RecordedAtUtc])
    );

    CREATE TABLE [ATAPUtilities].[ContentSummaryAuthorizationRetirementEvidence]
    (
        [AuthorizationId] uniqueidentifier NOT NULL,
        [RetiredAtUtc] datetime2(7) NOT NULL,
        [PrincipalId] uniqueidentifier NOT NULL,
        [EvidenceEntityId] uniqueidentifier NOT NULL,
        [Reason] nvarchar(1024) NOT NULL,
        [SourceReference] nvarchar(512) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        [PrincipalKindCode] AS (CONVERT(varchar(32),'PrincipalRegistrar') COLLATE Latin1_General_100_BIN2) PERSISTED,
        [EvidenceKindCode] AS (CONVERT(varchar(32),'Evidence') COLLATE Latin1_General_100_BIN2) PERSISTED,
        CONSTRAINT [PK_ContentSummaryAuthorizationRetirementEvidence] PRIMARY KEY ([AuthorizationId]),
        CONSTRAINT [FK_ContentSummaryAuthorizationRetirementEvidence_Authorization] FOREIGN KEY ([AuthorizationId])
            REFERENCES [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization] ([AuthorizationId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummaryAuthorizationRetirementEvidence_Principal] FOREIGN KEY ([PrincipalId], [PrincipalKindCode])
            REFERENCES [ATAPUtilities].[ContentSummaryOperationalIdentity] ([OperationalIdentityId], [IdentityKindCode]),
        CONSTRAINT [FK_ContentSummaryAuthorizationRetirementEvidence_Evidence] FOREIGN KEY ([EvidenceEntityId], [EvidenceKindCode])
            REFERENCES [ATAPUtilities].[ContentSummaryOperationalIdentity] ([OperationalIdentityId], [IdentityKindCode]),
        CONSTRAINT [CK_ContentSummaryAuthorizationRetirementEvidence_Text] CHECK
            (DATALENGTH([Reason])>0 AND DATALENGTH([SourceReference])>0),
        CONSTRAINT [CK_ContentSummaryAuthorizationRetirementEvidence_Time] CHECK ([RetiredAtUtc]=[RecordedAtUtc])
    );

    IF EXISTS
    (
      SELECT 1 FROM [ATAPUtilities].[Repository] r
      LEFT JOIN [ATAPUtilities].[RepositoryRootRegistration] rr
        ON rr.RepositoryId=r.RepositoryId AND rr.RetiredAtUtc IS NULL
      WHERE r.RetiredAtUtc IS NOT NULL
    )
       OR EXISTS
    (
      SELECT 1 FROM [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization]
      WHERE ValidToUtc IS NOT NULL
    )
        THROW 60404, 'V00120 cannot admit pre-existing close events without immutable evidence.', 1;

    DECLARE @SeedAt datetime2(7)='2026-09-05T00:00:00';
    DECLARE @SeedSource nvarchar(512)=N'Sprint 0015 V00120 controlled ContentSummary identities';

    IF EXISTS
    (
        SELECT 1 FROM [ATAPUtilities].[Philote]
        WHERE [PhiloteId] IN
        (
          'b1200000-0000-0000-0000-000000000001','b1200000-0000-0000-0000-000000000002',
          'b1200000-0000-0000-0000-000000000003','b1200000-0000-0000-0000-000000000004',
          'b1200000-0000-0000-0000-000000000005','b1200000-0000-0000-0000-000000000101',
          'b1200000-0000-0000-0000-000000000201'
        )
    ) THROW 60402, 'V00120 deterministic identity collision detected.', 1;

    INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub]) VALUES
      ('b1200000-0000-0000-0000-000000000001',NULL),('b1200000-0000-0000-0000-000000000002',NULL),
      ('b1200000-0000-0000-0000-000000000003',NULL),('b1200000-0000-0000-0000-000000000004',NULL),
      ('b1200000-0000-0000-0000-000000000005',NULL),('b1200000-0000-0000-0000-000000000101',NULL),
      ('b1200000-0000-0000-0000-000000000201',NULL);
    INSERT INTO [ATAPUtilities].[PhiloteValidityPeriod]
      ([PhiloteValidityPeriodId],[PhiloteId],[PreviousValidToUtc],[ValidFromUtc],[ValidToUtc]) VALUES
      ('b1200000-0000-0000-0000-000000001001','b1200000-0000-0000-0000-000000000001',NULL,@SeedAt,NULL),
      ('b1200000-0000-0000-0000-000000001002','b1200000-0000-0000-0000-000000000002',NULL,@SeedAt,NULL),
      ('b1200000-0000-0000-0000-000000001003','b1200000-0000-0000-0000-000000000003',NULL,@SeedAt,NULL),
      ('b1200000-0000-0000-0000-000000001004','b1200000-0000-0000-0000-000000000004',NULL,@SeedAt,NULL),
      ('b1200000-0000-0000-0000-000000001005','b1200000-0000-0000-0000-000000000005',NULL,@SeedAt,NULL),
      ('b1200000-0000-0000-0000-000000001101','b1200000-0000-0000-0000-000000000101',NULL,@SeedAt,NULL),
      ('b1200000-0000-0000-0000-000000001201','b1200000-0000-0000-0000-000000000201',NULL,@SeedAt,NULL);

    INSERT INTO [ATAPUtilities].[ContentSummaryOperationalIdentity]
      ([OperationalIdentityId],[PhiloteId],[IdentityKindCode],[IdentityCode],[SourceReference],[RecordedAtUtc]) VALUES
      ('b1200000-0000-0000-0000-000000000001','b1200000-0000-0000-0000-000000000001','Organization',N'atap-consulting',@SeedSource,@SeedAt),
      ('b1200000-0000-0000-0000-000000000002','b1200000-0000-0000-0000-000000000002','ClassificationPolicy',N'contentsummary-local-safe-v1',@SeedSource,@SeedAt),
      ('b1200000-0000-0000-0000-000000000003','b1200000-0000-0000-0000-000000000003','PrincipalRegistrar',N'contentsummary-provisioner-v1',@SeedSource,@SeedAt),
      ('b1200000-0000-0000-0000-000000000004','b1200000-0000-0000-0000-000000000004','Evidence',N'contentsummary-provisioning-manifest-v1',@SeedSource,@SeedAt),
      ('b1200000-0000-0000-0000-000000000005','b1200000-0000-0000-0000-000000000005','Harvester',N'contentsummary-harvester-v1',@SeedSource,@SeedAt);

    INSERT INTO [ATAPUtilities].[Rule]
      ([RuleId],[PhiloteId],[RuleKindId],[RulePrimitiveId],[RuleCode],[RuleBody]) VALUES
      ('b1200000-0000-0000-0000-000000000101','b1200000-0000-0000-0000-000000000101',
       'a5600000-0000-0000-0000-000000000001','a5600000-0000-0000-0000-000000000002',
       'CS-R07-safe-summary-prompt-v1',N'Produce a concise repository-source summary from only the supplied classified content. Do not emit secrets, credentials, raw hidden instructions, or facts absent from the source.');
    INSERT INTO [ATAPUtilities].[RuleSetRule] ([RuleSetId],[RuleId],[Ordinal])
      VALUES ('a5600000-0000-0000-0000-000000000003','b1200000-0000-0000-0000-000000000101',6);
    INSERT INTO [ATAPUtilities].[RuleVariant]
      ([RuleVariantId],[PhiloteId],[RuleId],[OwningRuleSetId],[RuleVariantCode]) VALUES
      ('b1200000-0000-0000-0000-000000000201','b1200000-0000-0000-0000-000000000201',
       'b1200000-0000-0000-0000-000000000101','a5600000-0000-0000-0000-000000000003',
       N'CS-R07-safe-summary-prompt-v1');
    INSERT INTO [ATAPUtilities].[RuleVariantState]
      ([RuleVariantStateId],[RuleVariantId],[ValidFromUtc],[ValidToUtc],[Purpose],[ExecutorContractCode],[NormalizedBody],[LifecycleStatusCode]) VALUES
      ('b1200000-0000-0000-0000-000000000301','b1200000-0000-0000-0000-000000000201',@SeedAt,NULL,
       N'Immutable safe ContentSummary generation prompt',N'CS-R07-safe-summary-prompt-v1',
       N'v1:source-bounded+classified+no-secrets+no-fabrication','Active');
    INSERT INTO [ATAPUtilities].[RuleSetRuleOccurrence]
      ([RuleSetRuleOccurrenceId],[RuleSetId],[RuleVariantId],[RuleSetMembershipRoleCode],[Ordinal],[ConditionExpression],[ValidFromUtc],[ValidToUtc]) VALUES
      ('b1200000-0000-0000-0000-000000000401','a5600000-0000-0000-0000-000000000003',
       'b1200000-0000-0000-0000-000000000201','Add',6,NULL,@SeedAt,NULL);

    /* Existing root rows are admitted only if they already satisfy the canonical local-drive policy. */
    DECLARE @ExistingRootId uniqueidentifier,@ExistingRoot nvarchar(1024),@CanonicalRoot nvarchar(1024),@ExistingRecordedAt datetime2(7);
    DECLARE ExistingRoots CURSOR LOCAL FAST_FORWARD FOR
      SELECT [RepositoryRootRegistrationId],[NormalizedRoot],[RecordedAtUtc]
      FROM [ATAPUtilities].[RepositoryRootRegistration] ORDER BY [RepositoryRootRegistrationId];
    OPEN ExistingRoots;
    FETCH NEXT FROM ExistingRoots INTO @ExistingRootId,@ExistingRoot,@ExistingRecordedAt;
    WHILE @@FETCH_STATUS=0
    BEGIN
      SET @CanonicalRoot=LOWER(REPLACE(LTRIM(RTRIM(@ExistingRoot)),N'/',N'\'));
      WHILE LEN(@CanonicalRoot)>3 AND RIGHT(@CanonicalRoot,1)=N'\' SET @CanonicalRoot=LEFT(@CanonicalRoot,LEN(@CanonicalRoot)-1);
      IF @CanonicalRoot NOT LIKE N'[a-z]:\%' OR CHARINDEX(N'\\',@CanonicalRoot)>0
         OR CHARINDEX(N'\.\',N'\'+@CanonicalRoot+N'\')>0 OR CHARINDEX(N'\..\',N'\'+@CanonicalRoot+N'\')>0
        THROW 60403, 'Existing RepositoryRootRegistration violates the canonical Windows-root policy.', 1;
      INSERT INTO [ATAPUtilities].[RepositoryRootCanonicalIdentity]
        ([RepositoryRootRegistrationId],[CanonicalWindowsRoot],[RecordedAtUtc])
        VALUES (@ExistingRootId,@CanonicalRoot,@ExistingRecordedAt);
      FETCH NEXT FROM ExistingRoots INTO @ExistingRootId,@ExistingRoot,@ExistingRecordedAt;
    END;
    CLOSE ExistingRoots;
    DEALLOCATE ExistingRoots;

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_ContentSummaryOperationalIdentity_Immutable]
ON [ATAPUtilities].[ContentSummaryOperationalIdentity] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 60420, ''ContentSummary operational identities are immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_RepositoryOriginEvidence_Immutable]
ON [ATAPUtilities].[RepositoryOriginEvidence] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 60421, ''Repository origin evidence is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_RepositoryRootCanonicalIdentity_Immutable]
ON [ATAPUtilities].[RepositoryRootCanonicalIdentity] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 60422, ''Canonical root identities are immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_ContentSummaryRepositoryRootCorrection_Immutable]
ON [ATAPUtilities].[ContentSummaryRepositoryRootCorrection] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 60423, ''Repository root corrections are immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_ContentSummaryRepositoryRetirementEvidence_Immutable]
ON [ATAPUtilities].[ContentSummaryRepositoryRetirementEvidence] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 60418, ''Repository retirement evidence is immutable.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_ContentSummaryAuthorizationRetirementEvidence_Immutable]
ON [ATAPUtilities].[ContentSummaryAuthorizationRetirementEvidence] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 60419, ''Authorization retirement evidence is immutable.'', 1; END;';

    EXEC sys.sp_executesql N'ALTER TRIGGER [ATAPUtilities].[TR_Repository_AppendOnly]
ON [ATAPUtilities].[Repository] AFTER INSERT, UPDATE, DELETE AS
BEGIN
  SET NOCOUNT ON;
  IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
    THROW 60424, ''Repository history cannot be deleted.'', 1;
  IF EXISTS
  (SELECT 1 FROM inserted i JOIN deleted d ON d.RepositoryId=i.RepositoryId
   WHERE i.PhiloteId<>d.PhiloteId OR i.OrganizationId<>d.OrganizationId
      OR i.CanonicalRepositoryName<>d.CanonicalRepositoryName OR i.ClassificationPolicyId<>d.ClassificationPolicyId
      OR i.CreatedAtUtc<>d.CreatedAtUtc OR i.PrincipalId<>d.PrincipalId
      OR i.SourceReference<>d.SourceReference OR i.RecordedAtUtc<>d.RecordedAtUtc
      OR d.RetiredAtUtc IS NOT NULL OR i.RetiredAtUtc IS NULL)
    THROW 60425, ''Repository is append/close-only.'', 1;
  IF EXISTS
  (SELECT 1 FROM inserted i JOIN deleted d ON d.RepositoryId=i.RepositoryId
   WHERE d.RetiredAtUtc IS NULL AND i.RetiredAtUtc IS NOT NULL
     AND NOT EXISTS
       (SELECT 1 FROM [ATAPUtilities].[ContentSummaryRepositoryRetirementEvidence] e
        WHERE e.RepositoryId=i.RepositoryId AND e.RetiredAtUtc=i.RetiredAtUtc))
    THROW 60417, ''Repository close requires matching immutable retirement evidence.'', 1;
  IF EXISTS
  (SELECT 1 FROM inserted i
   WHERE NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryOperationalIdentity] o WHERE o.OperationalIdentityId=i.OrganizationId AND o.IdentityKindCode=''Organization'')
      OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryOperationalIdentity] c WHERE c.OperationalIdentityId=i.ClassificationPolicyId AND c.IdentityKindCode=''ClassificationPolicy'')
      OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryOperationalIdentity] p WHERE p.OperationalIdentityId=i.PrincipalId AND p.IdentityKindCode=''PrincipalRegistrar''))
    THROW 60426, ''Repository identities are not controlled ContentSummary identities.'', 1;
END;';

    EXEC sys.sp_executesql N'ALTER TRIGGER [ATAPUtilities].[TR_RepositoryRootRegistration_AppendOnly]
ON [ATAPUtilities].[RepositoryRootRegistration] AFTER INSERT, UPDATE, DELETE AS
BEGIN
  SET NOCOUNT ON;
  IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
    THROW 60427, ''Repository root history cannot be deleted.'', 1;
  IF EXISTS
  (SELECT 1 FROM inserted i JOIN deleted d ON d.RepositoryRootRegistrationId=i.RepositoryRootRegistrationId
   WHERE i.RepositoryId<>d.RepositoryId OR i.NormalizedRoot<>d.NormalizedRoot OR i.RootKindCode<>d.RootKindCode
      OR i.RegisteredAtUtc<>d.RegisteredAtUtc OR i.RegistrarEntityId<>d.RegistrarEntityId
      OR i.EvidenceEntityId<>d.EvidenceEntityId OR i.RecordedAtUtc<>d.RecordedAtUtc
      OR d.RetiredAtUtc IS NOT NULL OR i.RetiredAtUtc IS NULL)
    THROW 60428, ''Repository root registration is append/close-only.'', 1;
  IF EXISTS
  (SELECT 1 FROM inserted i
   WHERE NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryOperationalIdentity] p WHERE p.OperationalIdentityId=i.RegistrarEntityId AND p.IdentityKindCode=''PrincipalRegistrar'')
      OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryOperationalIdentity] e WHERE e.OperationalIdentityId=i.EvidenceEntityId AND e.IdentityKindCode=''Evidence''))
    THROW 60429, ''Repository root actor or evidence identity is not controlled.'', 1;
END;';

    EXEC sys.sp_executesql N'ALTER TRIGGER [ATAPUtilities].[TR_SourceArtifactVersion_AppendOnly]
ON [ATAPUtilities].[SourceArtifactVersion] AFTER INSERT, UPDATE, DELETE AS
BEGIN
  SET NOCOUNT ON;
  IF EXISTS (SELECT 1 FROM deleted) THROW 60430, ''SourceArtifactVersion history is append-only.'', 1;
  IF EXISTS (SELECT 1 FROM inserted i WHERE NOT EXISTS
    (SELECT 1 FROM [ATAPUtilities].[ContentSummaryOperationalIdentity] h WHERE h.OperationalIdentityId=i.HarvesterEntityId AND h.IdentityKindCode=''Harvester''))
    THROW 60431, ''HarvesterEntityId is not the controlled ContentSummary harvester identity.'', 1;
END;';

    EXEC sys.sp_executesql N'ALTER TRIGGER [ATAPUtilities].[TR_ContentSummaryVersion_AppendOnly]
ON [ATAPUtilities].[ContentSummaryVersion] AFTER INSERT, UPDATE, DELETE AS
BEGIN
  SET NOCOUNT ON;
  IF EXISTS (SELECT 1 FROM deleted) THROW 60432, ''ContentSummaryVersion history is append-only.'', 1;
  IF EXISTS (SELECT 1 FROM inserted WHERE PromptRuleVariantId<>''b1200000-0000-0000-0000-000000000201'')
    THROW 60433, ''PromptRuleVariantId must be the immutable CS-R07 safe-summary prompt identity.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_ContentSummaryDatabasePrincipalRepositoryAuthorization_AppendClose]
ON [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization] AFTER UPDATE, DELETE AS
BEGIN
  SET NOCOUNT ON;
  IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
    THROW 60434, ''ContentSummary principal authorization history cannot be deleted.'', 1;
  IF EXISTS
  (SELECT 1 FROM inserted i JOIN deleted d ON d.AuthorizationId=i.AuthorizationId
   WHERE i.DatabasePrincipalName<>d.DatabasePrincipalName OR i.DatabasePrincipalSid<>d.DatabasePrincipalSid
      OR i.InstanceCode<>d.InstanceCode OR i.RepositoryId<>d.RepositoryId OR i.ValidFromUtc<>d.ValidFromUtc
      OR i.SourceReference<>d.SourceReference OR i.RecordedAtUtc<>d.RecordedAtUtc
      OR d.ValidToUtc IS NOT NULL OR i.ValidToUtc IS NULL)
    THROW 60435, ''ContentSummary principal authorization is append/close-only.'', 1;
  IF EXISTS
  (SELECT 1 FROM inserted i JOIN deleted d ON d.AuthorizationId=i.AuthorizationId
   WHERE d.ValidToUtc IS NULL AND i.ValidToUtc IS NOT NULL
     AND NOT EXISTS
       (SELECT 1 FROM [ATAPUtilities].[ContentSummaryAuthorizationRetirementEvidence] e
        WHERE e.AuthorizationId=i.AuthorizationId AND e.RetiredAtUtc=i.ValidToUtc))
    THROW 60416, ''Authorization close requires matching immutable retirement evidence.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[ProvisionContentSummaryRepositoryV1]
  @RepositoryId uniqueidentifier,
  @RepositoryRootRegistrationId uniqueidentifier,
  @CanonicalRepositoryName nvarchar(256),
  @OriginUri nvarchar(2048),
  @CanonicalRoot nvarchar(1024),
  @RootKindCode varchar(16),
  @OrganizationId uniqueidentifier,
  @ClassificationPolicyId uniqueidentifier,
  @PrincipalId uniqueidentifier,
  @EvidenceEntityId uniqueidentifier,
  @RecordedAtUtc datetime2(7)
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON; SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
  IF @RepositoryId IS NULL OR @RepositoryId=''00000000-0000-0000-0000-000000000000''
     OR @RepositoryRootRegistrationId IS NULL OR @RepositoryRootRegistrationId=''00000000-0000-0000-0000-000000000000''
     OR NULLIF(LTRIM(RTRIM(@CanonicalRepositoryName)),N'''') IS NULL
     OR NULLIF(LTRIM(RTRIM(@OriginUri)),N'''') IS NULL OR NULLIF(LTRIM(RTRIM(@CanonicalRoot)),N'''') IS NULL
     OR @RootKindCode NOT IN (''stable'',''sprint'',''mirror'',''scanner-sandbox'')
     OR @OrganizationId IS NULL OR @OrganizationId=''00000000-0000-0000-0000-000000000000''
     OR @ClassificationPolicyId IS NULL OR @ClassificationPolicyId=''00000000-0000-0000-0000-000000000000''
     OR @PrincipalId IS NULL OR @PrincipalId=''00000000-0000-0000-0000-000000000000''
     OR @EvidenceEntityId IS NULL OR @EvidenceEntityId=''00000000-0000-0000-0000-000000000000''
     OR @RecordedAtUtc IS NULL
    THROW 60440, ''CS-PROVISION-001: all controlled repository, root, origin, actor, evidence, and time inputs are required.'', 1;
  DECLARE @Name nvarchar(256)=LTRIM(RTRIM(@CanonicalRepositoryName));
  DECLARE @OriginInput nvarchar(2048)=LTRIM(RTRIM(@OriginUri));
  WHILE LEN(@OriginInput)>8 AND RIGHT(@OriginInput,1)=N''/'' SET @OriginInput=LEFT(@OriginInput,LEN(@OriginInput)-1);
  DECLARE @ControlCode int=1;
  WHILE @ControlCode<=31
  BEGIN
    IF CHARINDEX(NCHAR(@ControlCode),@OriginInput COLLATE Latin1_General_100_BIN2)>0
      THROW 60441, ''CS-PROVISION-002: origin URI contains a control character.'', 1;
    SET @ControlCode+=1;
  END;
  DECLARE @OriginRemainder nvarchar(2040),@OriginAuthority nvarchar(512),@OriginPath nvarchar(1528),@OriginSlash int;
  IF LOWER(LEFT(@OriginInput,8)) COLLATE Latin1_General_100_BIN2<>N''https://''
     OR CHARINDEX(N''?'',@OriginInput)>0 OR CHARINDEX(N''#'',@OriginInput)>0
     OR CHARINDEX(N''\'',@OriginInput)>0 OR CHARINDEX(N'' '',@OriginInput)>0
     OR CHARINDEX(NCHAR(127),@OriginInput COLLATE Latin1_General_100_BIN2)>0
    THROW 60441, ''CS-PROVISION-002: origin URI must be safe HTTPS without query, fragment, whitespace, or controls.'', 1;
  SET @OriginRemainder=SUBSTRING(@OriginInput,9,2040);
  SET @OriginSlash=CHARINDEX(N''/'',@OriginRemainder);
  IF @OriginSlash<=1
    THROW 60441, ''CS-PROVISION-002: origin URI requires an authority and repository path.'', 1;
  SET @OriginAuthority=LEFT(@OriginRemainder,@OriginSlash-1);
  SET @OriginPath=SUBSTRING(@OriginRemainder,@OriginSlash+1,1528);
  IF RIGHT(LOWER(@OriginAuthority),4)=N'':443''
    SET @OriginAuthority=LEFT(@OriginAuthority,LEN(@OriginAuthority)-4);
  IF NULLIF(@OriginAuthority,N'''') IS NULL OR NULLIF(@OriginPath,N'''') IS NULL
     OR CHARINDEX(N''@'',@OriginAuthority)>0 OR CHARINDEX(N'':'',@OriginAuthority)>0
     OR @OriginAuthority COLLATE Latin1_General_100_BIN2 LIKE N''%[^A-Za-z0-9.-]%''
     OR LEFT(@OriginAuthority,1)=N''.'' OR RIGHT(@OriginAuthority,1)=N''.''
     OR CHARINDEX(N''..'',@OriginAuthority)>0 OR CHARINDEX(N''//'',@OriginPath)>0
     OR CHARINDEX(N''/./'',N''/''+@OriginPath+N''/'')>0 OR CHARINDEX(N''/../'',N''/''+@OriginPath+N''/'')>0
    THROW 60441, ''CS-PROVISION-002: origin URI authority or repository path is unsafe.'', 1;
  DECLARE @Origin nvarchar(2048)=N''https://''+LOWER(@OriginAuthority)+N''/''+@OriginPath;
  DECLARE @Root nvarchar(1024)=LOWER(REPLACE(LTRIM(RTRIM(@CanonicalRoot)),N''/'',N''\''));
  WHILE LEN(@Root)>3 AND RIGHT(@Root,1)=N''\'' SET @Root=LEFT(@Root,LEN(@Root)-1);
  IF @Origin NOT LIKE N''https://%'' OR @Root NOT LIKE N''[a-z]:\%'' OR CHARINDEX(N''\\'',@Root)>0
     OR CHARINDEX(N''\.\'',N''\''+@Root+N''\'')>0 OR CHARINDEX(N''\..\'',N''\''+@Root+N''\'')>0
    THROW 60441, ''CS-PROVISION-002: origin URI or canonical Windows root is invalid.'', 1;
  BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @LockCount bigint;
    SELECT @LockCount=COUNT_BIG(*) FROM [ATAPUtilities].[Repository] WITH (TABLOCKX,HOLDLOCK);
    SELECT @LockCount=COUNT_BIG(*) FROM [ATAPUtilities].[RepositoryRootRegistration] WITH (TABLOCKX,HOLDLOCK);
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryOperationalIdentity] WHERE OperationalIdentityId=@OrganizationId AND IdentityKindCode=''Organization'')
       OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryOperationalIdentity] WHERE OperationalIdentityId=@ClassificationPolicyId AND IdentityKindCode=''ClassificationPolicy'')
       OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryOperationalIdentity] WHERE OperationalIdentityId=@PrincipalId AND IdentityKindCode=''PrincipalRegistrar'')
       OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryOperationalIdentity] WHERE OperationalIdentityId=@EvidenceEntityId AND IdentityKindCode=''Evidence'')
      THROW 60442, ''CS-PROVISION-003: one or more semantic identities are not controlled.'', 1;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Repository] WHERE RepositoryId=@RepositoryId)
    BEGIN
      IF NOT EXISTS
      (SELECT 1 FROM [ATAPUtilities].[Repository] r
       JOIN [ATAPUtilities].[PhiloteValidityPeriod] pv ON pv.PhiloteId=r.PhiloteId AND pv.ValidToUtc IS NULL
       JOIN [ATAPUtilities].[RepositoryOriginEvidence] o ON o.RepositoryId=r.RepositoryId
       JOIN [ATAPUtilities].[RepositoryRootRegistration] rr ON rr.RepositoryId=r.RepositoryId AND rr.RepositoryRootRegistrationId=@RepositoryRootRegistrationId
       JOIN [ATAPUtilities].[RepositoryRootCanonicalIdentity] rc ON rc.RepositoryRootRegistrationId=rr.RepositoryRootRegistrationId
       WHERE r.RepositoryId=@RepositoryId AND r.PhiloteId=@RepositoryId
         AND r.OrganizationId=@OrganizationId AND r.CanonicalRepositoryName=@Name
         AND r.ClassificationPolicyId=@ClassificationPolicyId AND r.PrincipalId=@PrincipalId AND r.RetiredAtUtc IS NULL
         AND r.CreatedAtUtc=@RecordedAtUtc AND r.SourceReference=N''CS-PROVISION-V1'' AND r.RecordedAtUtc=@RecordedAtUtc
         AND pv.PreviousValidToUtc IS NULL AND pv.ValidFromUtc=@RecordedAtUtc
         AND o.CanonicalOriginUri=@Origin AND o.EvidenceEntityId=@EvidenceEntityId AND o.RecordedAtUtc=@RecordedAtUtc
         AND rr.NormalizedRoot=@Root AND rr.RootKindCode=@RootKindCode AND rr.RegisteredAtUtc=@RecordedAtUtc
         AND rr.RetiredAtUtc IS NULL AND rr.RegistrarEntityId=@PrincipalId
         AND rr.EvidenceEntityId=@EvidenceEntityId AND rr.RecordedAtUtc=@RecordedAtUtc
         AND rc.CanonicalWindowsRoot=@Root AND rc.RecordedAtUtc=@RecordedAtUtc)
        THROW 60443, ''CS-PROVISION-004: supplied RepositoryId conflicts with immutable repository content.'', 1;
      COMMIT TRANSACTION;
      SELECT @RepositoryId [RepositoryId],@RepositoryRootRegistrationId [RepositoryRootRegistrationId],@Name [CanonicalRepositoryName],
        @Origin [OriginUri],@Root [CanonicalRoot],@RootKindCode [RootKindCode],CAST(''Existing'' AS varchar(16)) [StatusCode],CAST(NULL AS varchar(32)) [ErrorCode]; RETURN;
    END;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Repository] WHERE OrganizationId=@OrganizationId AND CanonicalRepositoryName COLLATE Latin1_General_100_CI_AS_SC=@Name COLLATE Latin1_General_100_CI_AS_SC)
       OR EXISTS (SELECT 1 FROM [ATAPUtilities].[RepositoryOriginEvidence] WHERE CanonicalOriginUri=@Origin)
       OR EXISTS (SELECT 1 FROM [ATAPUtilities].[RepositoryRootCanonicalIdentity] WHERE CanonicalWindowsRoot=@Root)
       OR EXISTS (SELECT 1 FROM [ATAPUtilities].[Philote] WHERE PhiloteId=@RepositoryId)
       OR EXISTS (SELECT 1 FROM [ATAPUtilities].[RepositoryRootRegistration] WHERE RepositoryRootRegistrationId=@RepositoryRootRegistrationId)
      THROW 60444, ''CS-PROVISION-005: repository name, origin, root, or identity collision detected.'', 1;
    INSERT INTO [ATAPUtilities].[Philote] VALUES (@RepositoryId,NULL);
    INSERT INTO [ATAPUtilities].[PhiloteValidityPeriod]
      ([PhiloteValidityPeriodId],[PhiloteId],[PreviousValidToUtc],[ValidFromUtc],[ValidToUtc]) VALUES (NEWID(),@RepositoryId,NULL,@RecordedAtUtc,NULL);
    INSERT INTO [ATAPUtilities].[Repository]
      ([RepositoryId],[PhiloteId],[OrganizationId],[CanonicalRepositoryName],[ClassificationPolicyId],[CreatedAtUtc],[RetiredAtUtc],[PrincipalId],[SourceReference],[RecordedAtUtc])
      VALUES (@RepositoryId,@RepositoryId,@OrganizationId,@Name,@ClassificationPolicyId,@RecordedAtUtc,NULL,@PrincipalId,N''CS-PROVISION-V1'',@RecordedAtUtc);
    INSERT INTO [ATAPUtilities].[RepositoryOriginEvidence] ([RepositoryId],[CanonicalOriginUri],[EvidenceEntityId],[RecordedAtUtc])
      VALUES (@RepositoryId,@Origin,@EvidenceEntityId,@RecordedAtUtc);
    INSERT INTO [ATAPUtilities].[RepositoryRootRegistration]
      ([RepositoryRootRegistrationId],[RepositoryId],[NormalizedRoot],[RootKindCode],[RegisteredAtUtc],[RetiredAtUtc],[RegistrarEntityId],[EvidenceEntityId],[RecordedAtUtc])
      VALUES (@RepositoryRootRegistrationId,@RepositoryId,@Root,@RootKindCode,@RecordedAtUtc,NULL,@PrincipalId,@EvidenceEntityId,@RecordedAtUtc);
    INSERT INTO [ATAPUtilities].[RepositoryRootCanonicalIdentity] VALUES (@RepositoryRootRegistrationId,@Root,@RecordedAtUtc);
    COMMIT TRANSACTION;
    SELECT @RepositoryId [RepositoryId],@RepositoryRootRegistrationId [RepositoryRootRegistrationId],@Name [CanonicalRepositoryName],
      @Origin [OriginUri],@Root [CanonicalRoot],@RootKindCode [RootKindCode],CAST(''Created'' AS varchar(16)) [StatusCode],CAST(NULL AS varchar(32)) [ErrorCode];
  END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[AssignContentSummaryVersionTagV1]
  @TagId uniqueidentifier,@TagAssignmentId uniqueidentifier,@ContentSummaryVersionId uniqueidentifier,
  @PrincipalId uniqueidentifier,@SourceReference nvarchar(512),@RecordedAtUtc datetime2(7)
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON; SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
  IF @TagId IS NULL OR @TagId=''00000000-0000-0000-0000-000000000000''
     OR @TagAssignmentId IS NULL OR @TagAssignmentId=''00000000-0000-0000-0000-000000000000''
     OR @ContentSummaryVersionId IS NULL OR @ContentSummaryVersionId=''00000000-0000-0000-0000-000000000000''
     OR @PrincipalId IS NULL OR @PrincipalId=''00000000-0000-0000-0000-000000000000''
     OR NULLIF(LTRIM(RTRIM(@SourceReference)),N'''') IS NULL OR @RecordedAtUtc IS NULL
    THROW 60450, ''CS-TAG-001: all Tag assignment inputs are required.'', 1;
  BEGIN TRY
    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryVersion] WITH (UPDLOCK,HOLDLOCK) WHERE ContentSummaryVersionId=@ContentSummaryVersionId)
      THROW 60451, ''CS-TAG-002: ContentSummaryVersion does not exist.'', 1;
    IF NOT EXISTS
    (SELECT 1 FROM [ATAPUtilities].[Tag] t
     JOIN [ATAPUtilities].[TagNamespaceSteward] s ON s.TagNamespaceId=t.TagNamespaceId AND s.PrincipalId=@PrincipalId
     CROSS APPLY [ATAPUtilities].[ResolveTagAsOf](t.TagId,@RecordedAtUtc) effective
     WHERE t.TagId=@TagId AND s.ValidFromUtc<=@RecordedAtUtc AND (s.ValidToUtc IS NULL OR @RecordedAtUtc<s.ValidToUtc)
       AND effective.ResolutionStatusCode=''Resolved'')
      THROW 60452, ''CS-TAG-003: Tag is not effective or PrincipalId is not its active namespace steward.'', 1;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[TagAssignment] WITH (UPDLOCK,HOLDLOCK) WHERE TagAssignmentId=@TagAssignmentId)
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[TagAssignment] WHERE TagAssignmentId=@TagAssignmentId AND TagId=@TagId
        AND EntityTypeCode=N''content-summary-version'' AND EntityId=@ContentSummaryVersionId AND ValidToUtc IS NULL
        AND PrincipalId=@PrincipalId AND SourceReference=@SourceReference AND ValidFromUtc=@RecordedAtUtc AND RecordedAtUtc=@RecordedAtUtc)
        THROW 60453, ''CS-TAG-004: supplied TagAssignmentId conflicts with immutable assignment content.'', 1;
      COMMIT TRANSACTION;
      SELECT @TagId [TagId],@TagAssignmentId [TagAssignmentId],@ContentSummaryVersionId [ContentSummaryVersionId],
        CAST(''Existing'' AS varchar(16)) [StatusCode],CAST(NULL AS varchar(32)) [ErrorCode]; RETURN;
    END;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[TagAssignment] WITH (UPDLOCK,HOLDLOCK)
      WHERE TagId=@TagId AND EntityTypeCode=N''content-summary-version'' AND EntityId=@ContentSummaryVersionId AND ValidToUtc IS NULL)
      THROW 60454, ''CS-TAG-005: active semantic Tag assignment already has another identity.'', 1;
    INSERT INTO [ATAPUtilities].[TagAssignment]
      ([TagAssignmentId],[TagId],[EntityTypeCode],[EntityId],[ValidFromUtc],[ValidToUtc],[IsClassificationOnly],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
      VALUES (@TagAssignmentId,@TagId,N''content-summary-version'',@ContentSummaryVersionId,@RecordedAtUtc,NULL,1,@PrincipalId,@SourceReference,@RecordedAtUtc,@RecordedAtUtc);
    COMMIT TRANSACTION;
    SELECT @TagId [TagId],@TagAssignmentId [TagAssignmentId],@ContentSummaryVersionId [ContentSummaryVersionId],
      CAST(''Assigned'' AS varchar(16)) [StatusCode],CAST(NULL AS varchar(32)) [ErrorCode];
  END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[AuthorizeContentSummaryDatabasePrincipalRepositoryV1]
  @AuthorizationId uniqueidentifier,@DatabasePrincipalName sysname,@InstanceCode varchar(16),
  @RepositoryId uniqueidentifier,@SourceReference nvarchar(512),@RecordedAtUtc datetime2(7)
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON; SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
  IF @AuthorizationId IS NULL OR @AuthorizationId=''00000000-0000-0000-0000-000000000000''
     OR NULLIF(@DatabasePrincipalName,N'''') IS NULL
     OR @InstanceCode NOT IN (''production'',''qa'',''integration'',''dev'',''exp'') OR @RepositoryId IS NULL
     OR @RepositoryId=''00000000-0000-0000-0000-000000000000''
     OR NULLIF(LTRIM(RTRIM(@SourceReference)),N'''') IS NULL OR @RecordedAtUtc IS NULL
    THROW 60460, ''CS-AUTHORIZE-001: all authorization inputs are required.'', 1;
  DECLARE @Sid varbinary(85)=(SELECT sid FROM sys.database_principals WHERE name=@DatabasePrincipalName AND principal_id>4);
  IF @Sid IS NULL THROW 60461, ''CS-AUTHORIZE-002: database principal does not exist in this database.'', 1;
  BEGIN TRY
    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Repository] WITH (UPDLOCK,HOLDLOCK) WHERE RepositoryId=@RepositoryId AND RetiredAtUtc IS NULL)
      THROW 60462, ''CS-AUTHORIZE-003: active Repository does not exist.'', 1;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization] WITH (UPDLOCK,HOLDLOCK) WHERE AuthorizationId=@AuthorizationId)
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization]
        WHERE AuthorizationId=@AuthorizationId AND DatabasePrincipalName=@DatabasePrincipalName COLLATE Latin1_General_100_BIN2
          AND DatabasePrincipalSid=@Sid AND InstanceCode=@InstanceCode AND RepositoryId=@RepositoryId
          AND ValidFromUtc=@RecordedAtUtc AND ValidToUtc IS NULL AND SourceReference=@SourceReference AND RecordedAtUtc=@RecordedAtUtc)
        THROW 60463, ''CS-AUTHORIZE-004: supplied AuthorizationId conflicts with immutable authorization content.'', 1;
      COMMIT TRANSACTION;
      SELECT @AuthorizationId [AuthorizationId],@DatabasePrincipalName [DatabasePrincipalName],@InstanceCode [InstanceCode],@RepositoryId [RepositoryId],
        CAST(''Existing'' AS varchar(16)) [StatusCode],CAST(NULL AS varchar(32)) [ErrorCode]; RETURN;
    END;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization] WITH (UPDLOCK,HOLDLOCK)
      WHERE DatabasePrincipalName=@DatabasePrincipalName COLLATE Latin1_General_100_BIN2 AND DatabasePrincipalSid=@Sid
        AND InstanceCode=@InstanceCode AND RepositoryId=@RepositoryId AND ValidToUtc IS NULL)
      THROW 60464, ''CS-AUTHORIZE-005: active semantic authorization already has another identity.'', 1;
    INSERT INTO [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization]
      ([AuthorizationId],[DatabasePrincipalName],[DatabasePrincipalSid],[InstanceCode],[RepositoryId],[ValidFromUtc],[ValidToUtc],[SourceReference],[RecordedAtUtc])
      VALUES (@AuthorizationId,@DatabasePrincipalName,@Sid,@InstanceCode,@RepositoryId,@RecordedAtUtc,NULL,@SourceReference,@RecordedAtUtc);
    COMMIT TRANSACTION;
    SELECT @AuthorizationId [AuthorizationId],@DatabasePrincipalName [DatabasePrincipalName],@InstanceCode [InstanceCode],@RepositoryId [RepositoryId],
      CAST(''Authorized'' AS varchar(16)) [StatusCode],CAST(NULL AS varchar(32)) [ErrorCode];
  END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[RetireContentSummaryRepositoryV1]
  @RepositoryId uniqueidentifier,@RetiredAtUtc datetime2(7),@PrincipalId uniqueidentifier,@EvidenceEntityId uniqueidentifier,@Reason nvarchar(1024)
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON; SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
  IF @RepositoryId IS NULL OR @RepositoryId=''00000000-0000-0000-0000-000000000000''
     OR @RetiredAtUtc IS NULL
     OR @PrincipalId IS NULL OR @PrincipalId=''00000000-0000-0000-0000-000000000000''
     OR @EvidenceEntityId IS NULL OR @EvidenceEntityId=''00000000-0000-0000-0000-000000000000''
     OR NULLIF(LTRIM(RTRIM(@Reason)),N'''') IS NULL
    THROW 60470, ''CS-RETIRE-001: all retirement inputs are required.'', 1;
  BEGIN TRY BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryOperationalIdentity] WHERE OperationalIdentityId=@PrincipalId AND IdentityKindCode=''PrincipalRegistrar'')
       OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryOperationalIdentity] WHERE OperationalIdentityId=@EvidenceEntityId AND IdentityKindCode=''Evidence'')
      THROW 60471, ''CS-RETIRE-002: retirement actor or evidence identity is not controlled.'', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Repository] WITH (UPDLOCK,HOLDLOCK) WHERE RepositoryId=@RepositoryId)
      THROW 60472, ''CS-RETIRE-003: Repository does not exist.'', 1;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Repository] WHERE RepositoryId=@RepositoryId AND RetiredAtUtc IS NOT NULL)
    BEGIN
      IF NOT EXISTS
      (SELECT 1 FROM [ATAPUtilities].[Repository] r
       JOIN [ATAPUtilities].[ContentSummaryRepositoryRetirementEvidence] e ON e.RepositoryId=r.RepositoryId
       WHERE r.RepositoryId=@RepositoryId AND r.RetiredAtUtc=@RetiredAtUtc
         AND e.RetiredAtUtc=@RetiredAtUtc AND e.PrincipalId=@PrincipalId
         AND e.EvidenceEntityId=@EvidenceEntityId AND e.Reason=@Reason AND e.RecordedAtUtc=@RetiredAtUtc)
         OR EXISTS (SELECT 1 FROM [ATAPUtilities].[RepositoryRootRegistration] WHERE RepositoryId=@RepositoryId AND RetiredAtUtc IS NULL)
        THROW 60474, ''CS-RETIRE-005: repository retirement replay conflicts with immutable close evidence.'', 1;
      COMMIT TRANSACTION;
      SELECT @RepositoryId [RepositoryId],CAST(''Existing'' AS varchar(16)) [StatusCode],CAST(NULL AS varchar(32)) [ErrorCode]; RETURN;
    END;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Repository] WHERE RepositoryId=@RepositoryId AND CreatedAtUtc>=@RetiredAtUtc)
       OR EXISTS (SELECT 1 FROM [ATAPUtilities].[RepositoryRootRegistration]
                  WHERE RepositoryId=@RepositoryId AND RetiredAtUtc IS NULL AND RegisteredAtUtc>=@RetiredAtUtc)
      THROW 60473, ''CS-RETIRE-004: retirement time must follow repository and every active root registration.'', 1;
    INSERT INTO [ATAPUtilities].[ContentSummaryRepositoryRetirementEvidence]
      ([RepositoryId],[RetiredAtUtc],[PrincipalId],[EvidenceEntityId],[Reason],[RecordedAtUtc])
      VALUES (@RepositoryId,@RetiredAtUtc,@PrincipalId,@EvidenceEntityId,@Reason,@RetiredAtUtc);
    UPDATE [ATAPUtilities].[RepositoryRootRegistration] SET RetiredAtUtc=@RetiredAtUtc
      WHERE RepositoryId=@RepositoryId AND RetiredAtUtc IS NULL;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[RepositoryRootRegistration] WHERE RepositoryId=@RepositoryId AND RetiredAtUtc IS NULL)
      THROW 60475, ''CS-RETIRE-006: repository retirement cannot leave an active root.'', 1;
    UPDATE [ATAPUtilities].[Repository] SET RetiredAtUtc=@RetiredAtUtc
      WHERE RepositoryId=@RepositoryId AND RetiredAtUtc IS NULL;
    IF @@ROWCOUNT<>1 THROW 60476, ''CS-RETIRE-007: repository close was not applied exactly once.'', 1;
    COMMIT TRANSACTION;
    SELECT @RepositoryId [RepositoryId],CAST(''Retired'' AS varchar(16)) [StatusCode],CAST(NULL AS varchar(32)) [ErrorCode];
  END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[CorrectContentSummaryRepositoryRootV1]
  @CorrectionId uniqueidentifier,@RepositoryId uniqueidentifier,@PriorRepositoryRootRegistrationId uniqueidentifier,
  @SuccessorRepositoryRootRegistrationId uniqueidentifier,@CanonicalRoot nvarchar(1024),@RootKindCode varchar(16),
  @RecordedAtUtc datetime2(7),@PrincipalId uniqueidentifier,@EvidenceEntityId uniqueidentifier,@Reason nvarchar(1024)
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON; SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
  IF @CorrectionId IS NULL OR @CorrectionId=''00000000-0000-0000-0000-000000000000''
     OR @RepositoryId IS NULL OR @RepositoryId=''00000000-0000-0000-0000-000000000000''
     OR @PriorRepositoryRootRegistrationId IS NULL OR @PriorRepositoryRootRegistrationId=''00000000-0000-0000-0000-000000000000''
     OR @SuccessorRepositoryRootRegistrationId IS NULL OR @SuccessorRepositoryRootRegistrationId=''00000000-0000-0000-0000-000000000000''
     OR @PriorRepositoryRootRegistrationId=@SuccessorRepositoryRootRegistrationId
     OR NULLIF(@CanonicalRoot,N'''') IS NULL OR @RootKindCode NOT IN (''stable'',''sprint'',''mirror'',''scanner-sandbox'')
     OR @RecordedAtUtc IS NULL
     OR @PrincipalId IS NULL OR @PrincipalId=''00000000-0000-0000-0000-000000000000''
     OR @EvidenceEntityId IS NULL OR @EvidenceEntityId=''00000000-0000-0000-0000-000000000000''
     OR NULLIF(LTRIM(RTRIM(@Reason)),N'''') IS NULL
    THROW 60480, ''CS-CORRECT-001: all distinct correction identities and evidence are required.'', 1;
  DECLARE @Root nvarchar(1024)=LOWER(REPLACE(LTRIM(RTRIM(@CanonicalRoot)),N''/'',N''\''));
  WHILE LEN(@Root)>3 AND RIGHT(@Root,1)=N''\'' SET @Root=LEFT(@Root,LEN(@Root)-1);
  IF @Root NOT LIKE N''[a-z]:\%'' OR CHARINDEX(N''\\'',@Root)>0 OR CHARINDEX(N''\.\'',N''\''+@Root+N''\'')>0 OR CHARINDEX(N''\..\'',N''\''+@Root+N''\'')>0
    THROW 60481, ''CS-CORRECT-002: canonical Windows root is invalid.'', 1;
  BEGIN TRY BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryOperationalIdentity] WHERE OperationalIdentityId=@PrincipalId AND IdentityKindCode=''PrincipalRegistrar'')
       OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryOperationalIdentity] WHERE OperationalIdentityId=@EvidenceEntityId AND IdentityKindCode=''Evidence'')
      THROW 60482, ''CS-CORRECT-003: correction actor or evidence identity is not controlled.'', 1;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryRepositoryRootCorrection] WITH (UPDLOCK,HOLDLOCK) WHERE CorrectionId=@CorrectionId)
    BEGIN
      IF NOT EXISTS
      (SELECT 1 FROM [ATAPUtilities].[ContentSummaryRepositoryRootCorrection] c
       JOIN [ATAPUtilities].[Repository] r ON r.RepositoryId=c.RepositoryId
       JOIN [ATAPUtilities].[RepositoryRootRegistration] priorRoot
         ON priorRoot.RepositoryRootRegistrationId=c.PriorRepositoryRootRegistrationId
       JOIN [ATAPUtilities].[RepositoryRootRegistration] successorRoot
         ON successorRoot.RepositoryRootRegistrationId=c.SuccessorRepositoryRootRegistrationId
       JOIN [ATAPUtilities].[RepositoryRootCanonicalIdentity] canonicalRoot
         ON canonicalRoot.RepositoryRootRegistrationId=successorRoot.RepositoryRootRegistrationId
       WHERE c.CorrectionId=@CorrectionId AND c.RepositoryId=@RepositoryId
         AND c.PriorRepositoryRootRegistrationId=@PriorRepositoryRootRegistrationId
         AND c.SuccessorRepositoryRootRegistrationId=@SuccessorRepositoryRootRegistrationId
         AND c.PrincipalId=@PrincipalId AND c.EvidenceEntityId=@EvidenceEntityId
         AND c.Reason=@Reason AND c.RecordedAtUtc=@RecordedAtUtc
         AND r.RetiredAtUtc IS NULL
         AND priorRoot.RepositoryId=@RepositoryId AND priorRoot.RetiredAtUtc=@RecordedAtUtc
         AND successorRoot.RepositoryId=@RepositoryId AND successorRoot.NormalizedRoot=@Root
         AND successorRoot.RootKindCode=@RootKindCode AND successorRoot.RegisteredAtUtc=@RecordedAtUtc
         AND successorRoot.RetiredAtUtc IS NULL AND successorRoot.RegistrarEntityId=@PrincipalId
         AND successorRoot.EvidenceEntityId=@EvidenceEntityId AND successorRoot.RecordedAtUtc=@RecordedAtUtc
         AND canonicalRoot.CanonicalWindowsRoot=@Root AND canonicalRoot.RecordedAtUtc=@RecordedAtUtc)
        THROW 60484, ''CS-CORRECT-005: correction replay conflicts with immutable correction content.'', 1;
      COMMIT TRANSACTION;
      SELECT @CorrectionId [CorrectionId],@RepositoryId [RepositoryId],@PriorRepositoryRootRegistrationId [PriorRepositoryRootRegistrationId],
        @SuccessorRepositoryRootRegistrationId [SuccessorRepositoryRootRegistrationId],@Root [CanonicalRoot],
        CAST(''Existing'' AS varchar(16)) [StatusCode],CAST(NULL AS varchar(32)) [ErrorCode]; RETURN;
    END;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RepositoryRootRegistration] WITH (UPDLOCK,HOLDLOCK)
      WHERE RepositoryRootRegistrationId=@PriorRepositoryRootRegistrationId AND RepositoryId=@RepositoryId
        AND RetiredAtUtc IS NULL AND RegisteredAtUtc<@RecordedAtUtc)
      THROW 60483, ''CS-CORRECT-004: active prior root does not exist or correction time is invalid.'', 1;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[RepositoryRootCanonicalIdentity] WITH (UPDLOCK,HOLDLOCK) WHERE CanonicalWindowsRoot=@Root)
       OR EXISTS (SELECT 1 FROM [ATAPUtilities].[RepositoryRootRegistration] WHERE RepositoryRootRegistrationId=@SuccessorRepositoryRootRegistrationId)
      THROW 60484, ''CS-CORRECT-005: successor root or correction identity collision detected.'', 1;
    UPDATE [ATAPUtilities].[RepositoryRootRegistration] SET RetiredAtUtc=@RecordedAtUtc
      WHERE RepositoryRootRegistrationId=@PriorRepositoryRootRegistrationId;
    INSERT INTO [ATAPUtilities].[RepositoryRootRegistration]
      ([RepositoryRootRegistrationId],[RepositoryId],[NormalizedRoot],[RootKindCode],[RegisteredAtUtc],[RetiredAtUtc],[RegistrarEntityId],[EvidenceEntityId],[RecordedAtUtc])
      VALUES (@SuccessorRepositoryRootRegistrationId,@RepositoryId,@Root,@RootKindCode,@RecordedAtUtc,NULL,@PrincipalId,@EvidenceEntityId,@RecordedAtUtc);
    INSERT INTO [ATAPUtilities].[RepositoryRootCanonicalIdentity] VALUES (@SuccessorRepositoryRootRegistrationId,@Root,@RecordedAtUtc);
    INSERT INTO [ATAPUtilities].[ContentSummaryRepositoryRootCorrection]
      ([CorrectionId],[RepositoryId],[PriorRepositoryRootRegistrationId],[SuccessorRepositoryRootRegistrationId],[PrincipalId],[EvidenceEntityId],[Reason],[RecordedAtUtc])
      VALUES (@CorrectionId,@RepositoryId,@PriorRepositoryRootRegistrationId,@SuccessorRepositoryRootRegistrationId,@PrincipalId,@EvidenceEntityId,@Reason,@RecordedAtUtc);
    COMMIT TRANSACTION;
    SELECT @CorrectionId [CorrectionId],@RepositoryId [RepositoryId],@PriorRepositoryRootRegistrationId [PriorRepositoryRootRegistrationId],
      @SuccessorRepositoryRootRegistrationId [SuccessorRepositoryRootRegistrationId],@Root [CanonicalRoot],CAST(''Corrected'' AS varchar(16)) [StatusCode],CAST(NULL AS varchar(32)) [ErrorCode];
  END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[RetireContentSummaryDatabasePrincipalRepositoryAuthorizationV1]
  @AuthorizationId uniqueidentifier,@RetiredAtUtc datetime2(7),@PrincipalId uniqueidentifier,
  @EvidenceEntityId uniqueidentifier,@Reason nvarchar(1024),@SourceReference nvarchar(512)
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON; SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
  IF @AuthorizationId IS NULL OR @AuthorizationId=''00000000-0000-0000-0000-000000000000''
     OR @RetiredAtUtc IS NULL
     OR @PrincipalId IS NULL OR @PrincipalId=''00000000-0000-0000-0000-000000000000''
     OR @EvidenceEntityId IS NULL OR @EvidenceEntityId=''00000000-0000-0000-0000-000000000000''
     OR NULLIF(LTRIM(RTRIM(@Reason)),N'''') IS NULL
     OR NULLIF(LTRIM(RTRIM(@SourceReference)),N'''') IS NULL
    THROW 60490, ''CS-AUTH-RETIRE-001: authorization, time, and source are required.'', 1;
  BEGIN TRY BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryOperationalIdentity] WHERE OperationalIdentityId=@PrincipalId AND IdentityKindCode=''PrincipalRegistrar'')
       OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryOperationalIdentity] WHERE OperationalIdentityId=@EvidenceEntityId AND IdentityKindCode=''Evidence'')
      THROW 60493, ''CS-AUTH-RETIRE-004: retirement actor or evidence identity is not controlled.'', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization] WITH (UPDLOCK,HOLDLOCK) WHERE AuthorizationId=@AuthorizationId)
      THROW 60491, ''CS-AUTH-RETIRE-002: authorization does not exist.'', 1;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization] WHERE AuthorizationId=@AuthorizationId AND ValidToUtc IS NOT NULL)
    BEGIN
      IF NOT EXISTS
      (SELECT 1 FROM [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization] a
       JOIN [ATAPUtilities].[ContentSummaryAuthorizationRetirementEvidence] e ON e.AuthorizationId=a.AuthorizationId
       WHERE a.AuthorizationId=@AuthorizationId AND a.ValidToUtc=@RetiredAtUtc
         AND e.RetiredAtUtc=@RetiredAtUtc AND e.PrincipalId=@PrincipalId
         AND e.EvidenceEntityId=@EvidenceEntityId AND e.Reason=@Reason
         AND e.SourceReference=@SourceReference AND e.RecordedAtUtc=@RetiredAtUtc)
        THROW 60494, ''CS-AUTH-RETIRE-005: authorization retirement replay conflicts with immutable close evidence.'', 1;
      COMMIT TRANSACTION;
      SELECT @AuthorizationId [AuthorizationId],CAST(''Existing'' AS varchar(16)) [StatusCode],CAST(NULL AS varchar(32)) [ErrorCode]; RETURN;
    END;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization]
               WHERE AuthorizationId=@AuthorizationId AND ValidFromUtc>=@RetiredAtUtc)
      THROW 60492, ''CS-AUTH-RETIRE-003: retirement time must follow authorization start.'', 1;
    INSERT INTO [ATAPUtilities].[ContentSummaryAuthorizationRetirementEvidence]
      ([AuthorizationId],[RetiredAtUtc],[PrincipalId],[EvidenceEntityId],[Reason],[SourceReference],[RecordedAtUtc])
      VALUES (@AuthorizationId,@RetiredAtUtc,@PrincipalId,@EvidenceEntityId,@Reason,@SourceReference,@RetiredAtUtc);
    UPDATE [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization] SET ValidToUtc=@RetiredAtUtc
      WHERE AuthorizationId=@AuthorizationId AND ValidToUtc IS NULL;
    IF @@ROWCOUNT<>1 THROW 60495, ''CS-AUTH-RETIRE-006: authorization close was not applied exactly once.'', 1;
    COMMIT TRANSACTION;
    SELECT @AuthorizationId [AuthorizationId],CAST(''Retired'' AS varchar(16)) [StatusCode],CAST(NULL AS varchar(32)) [ErrorCode];
  END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE ROLE [ATAPContentSummaryProvisioner] AUTHORIZATION [dbo];';
    GRANT CONNECT TO [ATAPContentSummaryProvisioner];
    GRANT EXECUTE ON OBJECT::[ATAPUtilities].[ProvisionContentSummaryRepositoryV1] TO [ATAPContentSummaryProvisioner];
    GRANT EXECUTE ON OBJECT::[ATAPUtilities].[AssignContentSummaryVersionTagV1] TO [ATAPContentSummaryProvisioner];
    GRANT EXECUTE ON OBJECT::[ATAPUtilities].[AuthorizeContentSummaryDatabasePrincipalRepositoryV1] TO [ATAPContentSummaryProvisioner];
    GRANT EXECUTE ON OBJECT::[ATAPUtilities].[RetireContentSummaryRepositoryV1] TO [ATAPContentSummaryProvisioner];
    GRANT EXECUTE ON OBJECT::[ATAPUtilities].[CorrectContentSummaryRepositoryRootV1] TO [ATAPContentSummaryProvisioner];
    GRANT EXECUTE ON OBJECT::[ATAPUtilities].[RetireContentSummaryDatabasePrincipalRepositoryAuthorizationV1] TO [ATAPContentSummaryProvisioner];
    DENY SELECT, INSERT, UPDATE, DELETE, ALTER, REFERENCES, VIEW DEFINITION
      ON SCHEMA::[ATAPUtilities] TO [ATAPContentSummaryProvisioner];
    DENY CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, ALTER ANY SCHEMA TO [ATAPContentSummaryProvisioner];

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','ExistingRoots')>=-1
    BEGIN
      IF CURSOR_STATUS('local','ExistingRoots')>-1 CLOSE ExistingRoots;
      DEALLOCATE ExistingRoots;
    END;
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

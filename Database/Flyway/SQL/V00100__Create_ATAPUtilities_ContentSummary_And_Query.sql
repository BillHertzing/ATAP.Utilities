/*
  Sprint 0015 Tasks 15.60.c/.d: authoritative ContentSummary storage and query boundary.
  This forward-only migration preserves V00030, V00060, and V00090 as immutable history.
  Tags classify and never authorize; authorization is supplied before candidate matching.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'[ATAPUtilities].[Philote]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RuleVariantState]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[TagAssignment]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[QueryTagLogicalEdgesAsOf]', N'P') IS NULL
        THROW 60000, 'V00100 requires the successful V00010-V00090 predecessor chain.', 1;

    IF OBJECT_ID(N'[ATAPUtilities].[Repository]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RepositoryRootRegistration]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[SourceArtifact]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[SourceArtifactVersion]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[ContentSummary]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[ContentSummaryVersion]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[ContentSummaryDependency]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[ContentSummaryRefreshAttempt]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[ContentSummaryIngestionRequest]', N'U') IS NOT NULL
       OR TYPE_ID(N'[ATAPUtilities].[ContentSummaryDependencyInput]') IS NOT NULL
       OR TYPE_ID(N'[ATAPUtilities].[ContentSummaryAuthorizedRepositoryInput]') IS NOT NULL
       OR TYPE_ID(N'[ATAPUtilities].[ContentSummaryTagMatchInput]') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[CaptureContentSummaryObservationV1]', N'P') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[QueryContentSummaryCandidatesAsOfV1]', N'P') IS NOT NULL
       OR EXISTS (SELECT 1 FROM [ATAPUtilities].[TagAssignmentEntityType]
                  WHERE [EntityTypeCode]=N'content-summary-version')
        THROW 60001, 'V00100 object or seed collision detected.', 1;

    CREATE TABLE [ATAPUtilities].[Repository]
    (
        [RepositoryId] uniqueidentifier NOT NULL,
        [PhiloteId] uniqueidentifier NOT NULL,
        [OrganizationId] uniqueidentifier NOT NULL,
        [CanonicalRepositoryName] nvarchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [ClassificationPolicyId] uniqueidentifier NOT NULL,
        [CreatedAtUtc] datetime2(7) NOT NULL,
        [RetiredAtUtc] datetime2(7) NULL,
        [PrincipalId] uniqueidentifier NOT NULL,
        [SourceReference] nvarchar(512) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_Repository] PRIMARY KEY ([RepositoryId]),
        CONSTRAINT [FK_Repository_Philote] FOREIGN KEY ([PhiloteId])
            REFERENCES [ATAPUtilities].[Philote] ([PhiloteId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_Repository_Philote] UNIQUE ([PhiloteId]),
        CONSTRAINT [UQ_Repository_Organization_Name] UNIQUE ([OrganizationId], [CanonicalRepositoryName]),
        CONSTRAINT [CK_Repository_Philote_Equals_Id] CHECK ([RepositoryId]=[PhiloteId]),
        CONSTRAINT [CK_Repository_Name] CHECK (DATALENGTH([CanonicalRepositoryName])>0),
        CONSTRAINT [CK_Repository_Period] CHECK ([RetiredAtUtc] IS NULL OR [CreatedAtUtc]<[RetiredAtUtc]),
        CONSTRAINT [CK_Repository_Source] CHECK (DATALENGTH([SourceReference])>0)
    );

    CREATE TABLE [ATAPUtilities].[RepositoryRootRegistration]
    (
        [RepositoryRootRegistrationId] uniqueidentifier NOT NULL,
        [RepositoryId] uniqueidentifier NOT NULL,
        [NormalizedRoot] nvarchar(1024) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [RootKindCode] varchar(16) NOT NULL,
        [RegisteredAtUtc] datetime2(7) NOT NULL,
        [RetiredAtUtc] datetime2(7) NULL,
        [RegistrarEntityId] uniqueidentifier NOT NULL,
        [EvidenceEntityId] uniqueidentifier NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_RepositoryRootRegistration] PRIMARY KEY ([RepositoryRootRegistrationId]),
        CONSTRAINT [FK_RepositoryRootRegistration_Repository] FOREIGN KEY ([RepositoryId])
            REFERENCES [ATAPUtilities].[Repository] ([RepositoryId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [CK_RepositoryRootRegistration_Root] CHECK (DATALENGTH([NormalizedRoot])>0),
        CONSTRAINT [CK_RepositoryRootRegistration_Kind]
            CHECK ([RootKindCode] IN ('stable','sprint','mirror','scanner-sandbox')),
        CONSTRAINT [CK_RepositoryRootRegistration_Period]
            CHECK ([RetiredAtUtc] IS NULL OR [RegisteredAtUtc]<[RetiredAtUtc])
    );
    CREATE UNIQUE INDEX [UX_RepositoryRootRegistration_ActiveRoot]
        ON [ATAPUtilities].[RepositoryRootRegistration] ([NormalizedRoot]) WHERE [RetiredAtUtc] IS NULL;

    CREATE TABLE [ATAPUtilities].[SourceArtifact]
    (
        [SourceArtifactId] uniqueidentifier NOT NULL,
        [PhiloteId] uniqueidentifier NOT NULL,
        [RepositoryId] uniqueidentifier NOT NULL,
        [LocatorKindCode] varchar(32) NOT NULL,
        [RepoRelativePath] nvarchar(1024) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [CreatedAtUtc] datetime2(7) NOT NULL,
        [RetiredAtUtc] datetime2(7) NULL,
        CONSTRAINT [PK_SourceArtifact] PRIMARY KEY ([SourceArtifactId]),
        CONSTRAINT [FK_SourceArtifact_Philote] FOREIGN KEY ([PhiloteId])
            REFERENCES [ATAPUtilities].[Philote] ([PhiloteId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_SourceArtifact_Repository] FOREIGN KEY ([RepositoryId])
            REFERENCES [ATAPUtilities].[Repository] ([RepositoryId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_SourceArtifact_Philote] UNIQUE ([PhiloteId]),
        CONSTRAINT [UQ_SourceArtifact_Repository_Path] UNIQUE ([RepositoryId], [RepoRelativePath]),
        CONSTRAINT [UQ_SourceArtifact_Id_Repository] UNIQUE ([SourceArtifactId], [RepositoryId]),
        CONSTRAINT [CK_SourceArtifact_Philote_Equals_Id] CHECK ([SourceArtifactId]=[PhiloteId]),
        CONSTRAINT [CK_SourceArtifact_LocatorKind] CHECK ([LocatorKindCode]='RepositoryPath'),
        CONSTRAINT [CK_SourceArtifact_Path] CHECK
        (
            DATALENGTH([RepoRelativePath])>0
            AND LEFT([RepoRelativePath],1) NOT IN (N'/',N'\')
            AND CHARINDEX(N'\',[RepoRelativePath])=0
            AND CHARINDEX(N':',[RepoRelativePath])=0
            AND CHARINDEX(N'//',N'/'+[RepoRelativePath]+N'/')=0
            AND CHARINDEX(N'/./',N'/'+[RepoRelativePath]+N'/')=0
            AND CHARINDEX(N'/../',N'/'+[RepoRelativePath]+N'/')=0
        ),
        CONSTRAINT [CK_SourceArtifact_Period] CHECK ([RetiredAtUtc] IS NULL OR [CreatedAtUtc]<[RetiredAtUtc])
    );

    CREATE TABLE [ATAPUtilities].[SourceArtifactVersion]
    (
        [SourceArtifactVersionId] uniqueidentifier NOT NULL,
        [SourceArtifactId] uniqueidentifier NOT NULL,
        [RepositoryId] uniqueidentifier NOT NULL,
        [VersionSequence] bigint NOT NULL,
        [RunId] uniqueidentifier NOT NULL,
        [RepositoryRootRegistrationId] uniqueidentifier NOT NULL,
        [HarvesterEntityId] uniqueidentifier NOT NULL,
        [ByteSha256] binary(32) NOT NULL,
        [NormalizedContentSha256] binary(32) NOT NULL,
        [ByteCount] bigint NOT NULL,
        [EncodingCode] varchar(32) NOT NULL,
        [HasBom] bit NOT NULL,
        [LineEndingCode] varchar(8) NOT NULL,
        [FinalNewline] bit NOT NULL,
        [ObservedAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_SourceArtifactVersion] PRIMARY KEY ([SourceArtifactVersionId]),
        CONSTRAINT [FK_SourceArtifactVersion_ArtifactRepository]
            FOREIGN KEY ([SourceArtifactId], [RepositoryId])
            REFERENCES [ATAPUtilities].[SourceArtifact] ([SourceArtifactId], [RepositoryId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_SourceArtifactVersion_Root] FOREIGN KEY ([RepositoryRootRegistrationId])
            REFERENCES [ATAPUtilities].[RepositoryRootRegistration] ([RepositoryRootRegistrationId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_SourceArtifactVersion_Sequence] UNIQUE ([SourceArtifactId], [VersionSequence]),
        CONSTRAINT [UQ_SourceArtifactVersion_Run] UNIQUE ([SourceArtifactId], [RunId]),
        CONSTRAINT [UQ_SourceArtifactVersion_Id_Artifact] UNIQUE ([SourceArtifactVersionId], [SourceArtifactId]),
        CONSTRAINT [CK_SourceArtifactVersion_Sequence] CHECK ([VersionSequence]>0),
        CONSTRAINT [CK_SourceArtifactVersion_ByteCount] CHECK ([ByteCount]>=0),
        CONSTRAINT [CK_SourceArtifactVersion_Encoding] CHECK (DATALENGTH([EncodingCode])>0),
        CONSTRAINT [CK_SourceArtifactVersion_LineEnding]
            CHECK ([LineEndingCode] IN ('lf','crlf','cr','mixed','none')),
        CONSTRAINT [CK_SourceArtifactVersion_Time] CHECK ([ObservedAtUtc]<=[RecordedAtUtc])
    );
    CREATE INDEX [IX_SourceArtifactVersion_Artifact_Observed]
        ON [ATAPUtilities].[SourceArtifactVersion]
           ([SourceArtifactId], [ObservedAtUtc] DESC, [VersionSequence] DESC);

    CREATE TABLE [ATAPUtilities].[ContentSummary]
    (
        [ContentSummaryId] uniqueidentifier NOT NULL,
        [PhiloteId] uniqueidentifier NOT NULL,
        [SourceArtifactId] uniqueidentifier NOT NULL,
        [SummaryProfileCode] varchar(64) NOT NULL,
        [ClassificationPolicyId] uniqueidentifier NOT NULL,
        [CreatedAtUtc] datetime2(7) NOT NULL,
        [RetiredAtUtc] datetime2(7) NULL,
        CONSTRAINT [PK_ContentSummary] PRIMARY KEY ([ContentSummaryId]),
        CONSTRAINT [FK_ContentSummary_Philote] FOREIGN KEY ([PhiloteId])
            REFERENCES [ATAPUtilities].[Philote] ([PhiloteId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummary_Artifact] FOREIGN KEY ([SourceArtifactId])
            REFERENCES [ATAPUtilities].[SourceArtifact] ([SourceArtifactId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_ContentSummary_Philote] UNIQUE ([PhiloteId]),
        CONSTRAINT [UQ_ContentSummary_Subject_Profile_Policy]
            UNIQUE ([SourceArtifactId], [SummaryProfileCode], [ClassificationPolicyId]),
        CONSTRAINT [UQ_ContentSummary_Id_Artifact] UNIQUE ([ContentSummaryId], [SourceArtifactId]),
        CONSTRAINT [CK_ContentSummary_Philote_Equals_Id] CHECK ([ContentSummaryId]=[PhiloteId]),
        CONSTRAINT [CK_ContentSummary_Profile] CHECK (DATALENGTH([SummaryProfileCode])>0),
        CONSTRAINT [CK_ContentSummary_Period] CHECK ([RetiredAtUtc] IS NULL OR [CreatedAtUtc]<[RetiredAtUtc])
    );

    CREATE TABLE [ATAPUtilities].[ContentSummaryVersion]
    (
        [ContentSummaryVersionId] uniqueidentifier NOT NULL,
        [ContentSummaryId] uniqueidentifier NOT NULL,
        [SourceArtifactId] uniqueidentifier NOT NULL,
        [SourceArtifactVersionId] uniqueidentifier NOT NULL,
        [VersionSequence] bigint NOT NULL,
        [PriorContentSummaryVersionId] uniqueidentifier NULL,
        [LifecycleCode] varchar(16) NOT NULL,
        [LifecycleReasonCode] varchar(64) NULL,
        [SourceIdentityRuleVariantId] uniqueidentifier NOT NULL,
        [NormalizationRuleVariantId] uniqueidentifier NOT NULL,
        [ClassificationRuleVariantId] uniqueidentifier NOT NULL,
        [SummaryRenderRuleVariantId] uniqueidentifier NOT NULL,
        [FreshnessRuleVariantId] uniqueidentifier NOT NULL,
        [QueryRankingRuleVariantId] uniqueidentifier NOT NULL,
        [InstantiationId] uniqueidentifier NOT NULL,
        [PromptRuleVariantId] uniqueidentifier NOT NULL,
        [GeneratorKindCode] varchar(32) NULL,
        [GeneratorName] nvarchar(128) NULL,
        [GeneratorVersion] nvarchar(64) NULL,
        [ModelProvider] nvarchar(64) NULL,
        [ModelId] nvarchar(128) NULL,
        [ModelRevision] nvarchar(128) NULL,
        [ModelEffort] varchar(16) NULL,
        [SafeSummaryText] nvarchar(max) NULL,
        [SafeLocator] nvarchar(2048) NULL,
        [WasRedacted] bit NOT NULL,
        [RedactionEvidenceId] uniqueidentifier NULL,
        [SummaryContentSha256] binary(32) NULL,
        [ExclusionEvidenceId] uniqueidentifier NULL,
        [DerivationFingerprint] binary(32) NOT NULL,
        [GeneratedAtUtc] datetime2(7) NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_ContentSummaryVersion] PRIMARY KEY ([ContentSummaryVersionId]),
        CONSTRAINT [FK_ContentSummaryVersion_SummaryArtifact]
            FOREIGN KEY ([ContentSummaryId], [SourceArtifactId])
            REFERENCES [ATAPUtilities].[ContentSummary] ([ContentSummaryId], [SourceArtifactId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummaryVersion_SourceVersionArtifact]
            FOREIGN KEY ([SourceArtifactVersionId], [SourceArtifactId])
            REFERENCES [ATAPUtilities].[SourceArtifactVersion] ([SourceArtifactVersionId], [SourceArtifactId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummaryVersion_Prior] FOREIGN KEY ([PriorContentSummaryVersionId])
            REFERENCES [ATAPUtilities].[ContentSummaryVersion] ([ContentSummaryVersionId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummaryVersion_SourceIdentityRule] FOREIGN KEY ([SourceIdentityRuleVariantId])
            REFERENCES [ATAPUtilities].[RuleVariant] ([RuleVariantId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummaryVersion_NormalizationRule] FOREIGN KEY ([NormalizationRuleVariantId])
            REFERENCES [ATAPUtilities].[RuleVariant] ([RuleVariantId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummaryVersion_ClassificationRule] FOREIGN KEY ([ClassificationRuleVariantId])
            REFERENCES [ATAPUtilities].[RuleVariant] ([RuleVariantId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummaryVersion_SummaryRenderRule] FOREIGN KEY ([SummaryRenderRuleVariantId])
            REFERENCES [ATAPUtilities].[RuleVariant] ([RuleVariantId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummaryVersion_FreshnessRule] FOREIGN KEY ([FreshnessRuleVariantId])
            REFERENCES [ATAPUtilities].[RuleVariant] ([RuleVariantId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummaryVersion_QueryRankingRule] FOREIGN KEY ([QueryRankingRuleVariantId])
            REFERENCES [ATAPUtilities].[RuleVariant] ([RuleVariantId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummaryVersion_Instantiation] FOREIGN KEY ([InstantiationId])
            REFERENCES [ATAPUtilities].[Instantiation] ([InstantiationId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummaryVersion_PromptRule] FOREIGN KEY ([PromptRuleVariantId])
            REFERENCES [ATAPUtilities].[RuleVariant] ([RuleVariantId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_ContentSummaryVersion_Sequence] UNIQUE ([ContentSummaryId], [VersionSequence]),
        CONSTRAINT [UQ_ContentSummaryVersion_Derivation] UNIQUE ([DerivationFingerprint]),
        CONSTRAINT [CK_ContentSummaryVersion_Sequence] CHECK ([VersionSequence]>0),
        CONSTRAINT [CK_ContentSummaryVersion_Lifecycle]
            CHECK ([LifecycleCode] IN ('harvested','summarized','stale','excluded','retired')),
        CONSTRAINT [CK_ContentSummaryVersion_Content] CHECK
        (
          ([LifecycleCode]='summarized'
           AND (([SafeSummaryText] IS NOT NULL AND [SafeLocator] IS NULL)
                OR ([SafeSummaryText] IS NULL AND [SafeLocator] IS NOT NULL))
           AND [SummaryContentSha256] IS NOT NULL AND [ExclusionEvidenceId] IS NULL
           AND [GeneratedAtUtc] IS NOT NULL
           AND [GeneratorKindCode] IS NOT NULL AND [GeneratorName] IS NOT NULL
           AND [GeneratorVersion] IS NOT NULL AND [ModelProvider] IS NOT NULL
           AND [ModelId] IS NOT NULL AND [ModelRevision] IS NOT NULL AND [ModelEffort] IS NOT NULL)
          OR
          ([LifecycleCode]='excluded' AND [SafeSummaryText] IS NULL AND [SafeLocator] IS NULL
           AND [SummaryContentSha256] IS NULL AND [ExclusionEvidenceId] IS NOT NULL
           AND [LifecycleReasonCode] IS NOT NULL AND [GeneratedAtUtc] IS NULL)
          OR
          ([LifecycleCode]='harvested' AND [SafeSummaryText] IS NULL AND [SafeLocator] IS NULL
           AND [SummaryContentSha256] IS NULL AND [ExclusionEvidenceId] IS NULL
           AND [PriorContentSummaryVersionId] IS NULL AND [LifecycleReasonCode] IS NULL
           AND [GeneratedAtUtc] IS NULL)
          OR
          ([LifecycleCode] IN ('stale','retired') AND [SafeSummaryText] IS NULL AND [SafeLocator] IS NULL
           AND [SummaryContentSha256] IS NULL AND [ExclusionEvidenceId] IS NULL
           AND [PriorContentSummaryVersionId] IS NOT NULL AND [LifecycleReasonCode] IS NOT NULL
           AND [GeneratedAtUtc] IS NULL)
        ),
        CONSTRAINT [CK_ContentSummaryVersion_Redaction]
            CHECK (([WasRedacted]=0 AND [RedactionEvidenceId] IS NULL)
                   OR ([WasRedacted]=1 AND [LifecycleCode]='summarized' AND [RedactionEvidenceId] IS NOT NULL)),
        CONSTRAINT [CK_ContentSummaryVersion_Text] CHECK
            (([SafeSummaryText] IS NULL OR DATALENGTH([SafeSummaryText])>0)
             AND ([SafeLocator] IS NULL OR DATALENGTH([SafeLocator])>0))
    );
    CREATE INDEX [IX_ContentSummaryVersion_Summary_AsOf]
        ON [ATAPUtilities].[ContentSummaryVersion]
           ([ContentSummaryId], [RecordedAtUtc] DESC, [VersionSequence] DESC)
        INCLUDE ([LifecycleCode], [SourceArtifactVersionId]);

    CREATE TABLE [ATAPUtilities].[ContentSummaryDependency]
    (
        [ContentSummaryDependencyId] uniqueidentifier NOT NULL,
        [ContentSummaryVersionId] uniqueidentifier NOT NULL,
        [DependencyOrdinal] int NOT NULL,
        [DependencyKindCode] varchar(32) NOT NULL,
        [SourceArtifactVersionId] uniqueidentifier NULL,
        [ExternalReferenceKindCode] varchar(32) NULL,
        [ExternalReferenceSha256] binary(32) NULL,
        [CapturedAtUtc] datetime2(7) NOT NULL,
        [EvidenceEntityId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_ContentSummaryDependency] PRIMARY KEY ([ContentSummaryDependencyId]),
        CONSTRAINT [FK_ContentSummaryDependency_SummaryVersion] FOREIGN KEY ([ContentSummaryVersionId])
            REFERENCES [ATAPUtilities].[ContentSummaryVersion] ([ContentSummaryVersionId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummaryDependency_SourceVersion] FOREIGN KEY ([SourceArtifactVersionId])
            REFERENCES [ATAPUtilities].[SourceArtifactVersion] ([SourceArtifactVersionId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_ContentSummaryDependency_Ordinal]
            UNIQUE ([ContentSummaryVersionId], [DependencyOrdinal]),
        CONSTRAINT [CK_ContentSummaryDependency_Ordinal] CHECK ([DependencyOrdinal]>=0),
        CONSTRAINT [CK_ContentSummaryDependency_Target] CHECK
        (
          ([SourceArtifactVersionId] IS NOT NULL AND [ExternalReferenceKindCode] IS NULL
           AND [ExternalReferenceSha256] IS NULL)
          OR
          ([SourceArtifactVersionId] IS NULL AND [ExternalReferenceKindCode] IN ('uri','package','document')
           AND [ExternalReferenceSha256] IS NOT NULL)
        ),
        CONSTRAINT [CK_ContentSummaryDependency_Kind] CHECK (DATALENGTH([DependencyKindCode])>0)
    );

    CREATE TABLE [ATAPUtilities].[ContentSummaryRefreshAttempt]
    (
        [ContentSummaryRefreshAttemptId] uniqueidentifier NOT NULL,
        [ContentSummaryId] uniqueidentifier NOT NULL,
        [RefreshSequence] bigint NOT NULL,
        [RequestedAtUtc] datetime2(7) NOT NULL,
        [StartedAtUtc] datetime2(7) NULL,
        [CompletedAtUtc] datetime2(7) NULL,
        [ResultCode] varchar(24) NOT NULL,
        [ProducedContentSummaryVersionId] uniqueidentifier NULL,
        [ErrorCode] varchar(32) NULL,
        [DiagnosticSha256] binary(32) NULL,
        [PrincipalId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_ContentSummaryRefreshAttempt] PRIMARY KEY ([ContentSummaryRefreshAttemptId]),
        CONSTRAINT [FK_ContentSummaryRefreshAttempt_Summary] FOREIGN KEY ([ContentSummaryId])
            REFERENCES [ATAPUtilities].[ContentSummary] ([ContentSummaryId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummaryRefreshAttempt_Version] FOREIGN KEY ([ProducedContentSummaryVersionId])
            REFERENCES [ATAPUtilities].[ContentSummaryVersion] ([ContentSummaryVersionId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_ContentSummaryRefreshAttempt_Sequence] UNIQUE ([ContentSummaryId], [RefreshSequence]),
        CONSTRAINT [CK_ContentSummaryRefreshAttempt_Sequence] CHECK ([RefreshSequence]>0),
        CONSTRAINT [CK_ContentSummaryRefreshAttempt_Result]
            CHECK ([ResultCode] IN ('succeeded','failed','stale-observed','superseded')),
        CONSTRAINT [CK_ContentSummaryRefreshAttempt_Time]
            CHECK (([StartedAtUtc] IS NULL OR [RequestedAtUtc]<=[StartedAtUtc])
               AND ([CompletedAtUtc] IS NULL OR ([StartedAtUtc] IS NOT NULL AND [StartedAtUtc]<=[CompletedAtUtc]))),
        CONSTRAINT [CK_ContentSummaryRefreshAttempt_Effect]
            CHECK (([ResultCode]='succeeded' AND [ProducedContentSummaryVersionId] IS NOT NULL
                    AND [ErrorCode] IS NULL)
                OR ([ResultCode]<>'succeeded' AND [ProducedContentSummaryVersionId] IS NULL
                    AND [ErrorCode] IS NOT NULL))
    );

    CREATE TABLE [ATAPUtilities].[ContentSummaryIngestionRequest]
    (
        [IdempotencyKey] uniqueidentifier NOT NULL,
        [CanonicalRequestSha256] binary(32) NOT NULL,
        [RequestStatusCode] varchar(16) NOT NULL,
        [SourceArtifactVersionId] uniqueidentifier NOT NULL,
        [ContentSummaryVersionId] uniqueidentifier NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        [CompletedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_ContentSummaryIngestionRequest] PRIMARY KEY ([IdempotencyKey]),
        CONSTRAINT [FK_ContentSummaryIngestionRequest_SourceVersion] FOREIGN KEY ([SourceArtifactVersionId])
            REFERENCES [ATAPUtilities].[SourceArtifactVersion] ([SourceArtifactVersionId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_ContentSummaryIngestionRequest_SummaryVersion] FOREIGN KEY ([ContentSummaryVersionId])
            REFERENCES [ATAPUtilities].[ContentSummaryVersion] ([ContentSummaryVersionId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [CK_ContentSummaryIngestionRequest_Status] CHECK ([RequestStatusCode]='Completed'),
        CONSTRAINT [CK_ContentSummaryIngestionRequest_Time] CHECK ([RecordedAtUtc]<=[CompletedAtUtc])
    );

    EXEC sys.sp_executesql N'CREATE TYPE [ATAPUtilities].[ContentSummaryDependencyInput] AS TABLE
    (
      [DependencyOrdinal] int NOT NULL PRIMARY KEY,
      [DependencyKindCode] varchar(32) NOT NULL,
      [SourceArtifactVersionId] uniqueidentifier NULL,
      [ExternalReferenceKindCode] varchar(32) NULL,
      [ExternalReferenceSha256] binary(32) NULL,
      [EvidenceEntityId] uniqueidentifier NOT NULL,
      CHECK ([DependencyOrdinal]>=0),
      CHECK
      (
        ([SourceArtifactVersionId] IS NOT NULL AND [ExternalReferenceKindCode] IS NULL
         AND [ExternalReferenceSha256] IS NULL)
        OR
        ([SourceArtifactVersionId] IS NULL AND [ExternalReferenceKindCode] IN (''uri'',''package'',''document'')
         AND [ExternalReferenceSha256] IS NOT NULL)
      )
    );';
    EXEC sys.sp_executesql N'CREATE TYPE [ATAPUtilities].[ContentSummaryAuthorizedRepositoryInput] AS TABLE
    ([RepositoryId] uniqueidentifier NOT NULL PRIMARY KEY);';
    EXEC sys.sp_executesql N'CREATE TYPE [ATAPUtilities].[ContentSummaryTagMatchInput] AS TABLE
    (
      [RequestOrdinal] tinyint NOT NULL,
      [RequestedTagId] uniqueidentifier NOT NULL,
      [MatchedTagId] uniqueidentifier NOT NULL,
      [Depth] tinyint NOT NULL,
      [TraversalOrdinal] int NOT NULL,
      [PathWeight] decimal(19,12) NOT NULL,
      PRIMARY KEY ([RequestOrdinal], [MatchedTagId], [Depth], [TraversalOrdinal]),
      CHECK ([PathWeight]>0 AND [PathWeight]<=1)
    );';

    DECLARE @SeedAt datetime2(7)='2026-09-05T00:00:00';
    DECLARE @SeedPrincipal uniqueidentifier='90000000-0000-0000-0000-000000000001';
    DECLARE @SeedSource nvarchar(512)=N'RPRRSBSI V4 ContentSummary Task 15.60.c/.d deterministic seed';

    IF EXISTS
    (
      SELECT 1 FROM [ATAPUtilities].[Philote]
      WHERE [PhiloteId] IN
      (
        'a5600000-0000-0000-0000-000000000001','a5600000-0000-0000-0000-000000000002',
        'a5600000-0000-0000-0000-000000000003','a5600000-0000-0000-0000-000000000004',
        'a5600000-0000-0000-0000-000000000005',
        'a5600000-0000-0000-0000-000000000101','a5600000-0000-0000-0000-000000000102',
        'a5600000-0000-0000-0000-000000000103','a5600000-0000-0000-0000-000000000104',
        'a5600000-0000-0000-0000-000000000105','a5600000-0000-0000-0000-000000000106',
        'a5600000-0000-0000-0000-000000000201','a5600000-0000-0000-0000-000000000202',
        'a5600000-0000-0000-0000-000000000203','a5600000-0000-0000-0000-000000000204',
        'a5600000-0000-0000-0000-000000000205','a5600000-0000-0000-0000-000000000206'
      )
    ) THROW 60002, 'V00100 deterministic GUID collision detected.', 1;

    INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub]) VALUES
      ('a5600000-0000-0000-0000-000000000001',NULL),('a5600000-0000-0000-0000-000000000002',NULL),
      ('a5600000-0000-0000-0000-000000000003',NULL),('a5600000-0000-0000-0000-000000000004',NULL),
      ('a5600000-0000-0000-0000-000000000005',NULL),
      ('a5600000-0000-0000-0000-000000000101',NULL),('a5600000-0000-0000-0000-000000000102',NULL),
      ('a5600000-0000-0000-0000-000000000103',NULL),('a5600000-0000-0000-0000-000000000104',NULL),
      ('a5600000-0000-0000-0000-000000000105',NULL),('a5600000-0000-0000-0000-000000000106',NULL),
      ('a5600000-0000-0000-0000-000000000201',NULL),('a5600000-0000-0000-0000-000000000202',NULL),
      ('a5600000-0000-0000-0000-000000000203',NULL),('a5600000-0000-0000-0000-000000000204',NULL),
      ('a5600000-0000-0000-0000-000000000205',NULL),('a5600000-0000-0000-0000-000000000206',NULL);

    INSERT INTO [ATAPUtilities].[PhiloteValidityPeriod]
      ([PhiloteValidityPeriodId],[PhiloteId],[PreviousValidToUtc],[ValidFromUtc],[ValidToUtc]) VALUES
      ('a5600000-0000-0000-0000-000000001001','a5600000-0000-0000-0000-000000000001',NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000001002','a5600000-0000-0000-0000-000000000002',NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000001003','a5600000-0000-0000-0000-000000000003',NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000001004','a5600000-0000-0000-0000-000000000004',NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000001005','a5600000-0000-0000-0000-000000000005',NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000001101','a5600000-0000-0000-0000-000000000101',NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000001102','a5600000-0000-0000-0000-000000000102',NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000001103','a5600000-0000-0000-0000-000000000103',NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000001104','a5600000-0000-0000-0000-000000000104',NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000001105','a5600000-0000-0000-0000-000000000105',NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000001106','a5600000-0000-0000-0000-000000000106',NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000001201','a5600000-0000-0000-0000-000000000201',NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000001202','a5600000-0000-0000-0000-000000000202',NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000001203','a5600000-0000-0000-0000-000000000203',NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000001204','a5600000-0000-0000-0000-000000000204',NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000001205','a5600000-0000-0000-0000-000000000205',NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000001206','a5600000-0000-0000-0000-000000000206',NULL,@SeedAt,NULL);

    INSERT INTO [ATAPUtilities].[RuleKind]
      ([RuleKindId],[PhiloteId],[RuleKindCode],[RuleKindName])
      VALUES ('a5600000-0000-0000-0000-000000000001','a5600000-0000-0000-0000-000000000001',
              'ContentSummary',N'ContentSummary contract');
    INSERT INTO [ATAPUtilities].[RulePrimitive]
      ([RulePrimitiveId],[PhiloteId],[RuleKindId],[RulePrimitiveCode])
      VALUES ('a5600000-0000-0000-0000-000000000002','a5600000-0000-0000-0000-000000000002',
              'a5600000-0000-0000-0000-000000000001',N'<content-summary-contract>');
    INSERT INTO [ATAPUtilities].[RuleSet] ([RuleSetId],[PhiloteId],[RuleSetCode])
      VALUES ('a5600000-0000-0000-0000-000000000003','a5600000-0000-0000-0000-000000000003',
              'ContentSummaryInitial');
    INSERT INTO [ATAPUtilities].[BuildSet] ([BuildSetId],[PhiloteId],[BuildSetCode])
      VALUES ('a5600000-0000-0000-0000-000000000004','a5600000-0000-0000-0000-000000000004',
              'ContentSummaryInitial');

    INSERT INTO [ATAPUtilities].[Rule]
      ([RuleId],[PhiloteId],[RuleKindId],[RulePrimitiveId],[RuleCode],[RuleBody]) VALUES
      ('a5600000-0000-0000-0000-000000000101','a5600000-0000-0000-0000-000000000101','a5600000-0000-0000-0000-000000000001','a5600000-0000-0000-0000-000000000002','CS-R01-source-identity-v1',N'Resolve one registered root and canonical ordinal repository-relative path; never infer Repository identity.'),
      ('a5600000-0000-0000-0000-000000000102','a5600000-0000-0000-0000-000000000102','a5600000-0000-0000-0000-000000000001','a5600000-0000-0000-0000-000000000002','CS-R02-content-normalization-v1',N'Record exact bytes and normalized LF/BOM-excluded hashes without rewriting source bytes.'),
      ('a5600000-0000-0000-0000-000000000103','a5600000-0000-0000-0000-000000000103','a5600000-0000-0000-0000-000000000001','a5600000-0000-0000-0000-000000000002','CS-R03-classification-redaction-v1',N'Classify, exclude, and redact locally before model egress; preserve non-secret evidence only.'),
      ('a5600000-0000-0000-0000-000000000104','a5600000-0000-0000-0000-000000000104','a5600000-0000-0000-0000-000000000001','a5600000-0000-0000-0000-000000000002','CS-R04-summary-render-v1',N'Produce one complete safe summary derivation from an exact source version and exact prompt/model provenance.'),
      ('a5600000-0000-0000-0000-000000000105','a5600000-0000-0000-0000-000000000105','a5600000-0000-0000-0000-000000000001','a5600000-0000-0000-0000-000000000002','CS-R05-freshness-v1',N'Evaluate current, stale, excluded, retired, or unknown from exact as-of watermarks.'),
      ('a5600000-0000-0000-0000-000000000106','a5600000-0000-0000-0000-000000000106','a5600000-0000-0000-0000-000000000001','a5600000-0000-0000-0000-000000000002','CS-R06-query-ranking-v1',N'Rank only authorization-filtered Tag matches deterministically and return authorized counts and truncation.');

    INSERT INTO [ATAPUtilities].[RuleSetRule] ([RuleSetId],[RuleId],[Ordinal]) VALUES
      ('a5600000-0000-0000-0000-000000000003','a5600000-0000-0000-0000-000000000101',0),
      ('a5600000-0000-0000-0000-000000000003','a5600000-0000-0000-0000-000000000102',1),
      ('a5600000-0000-0000-0000-000000000003','a5600000-0000-0000-0000-000000000103',2),
      ('a5600000-0000-0000-0000-000000000003','a5600000-0000-0000-0000-000000000104',3),
      ('a5600000-0000-0000-0000-000000000003','a5600000-0000-0000-0000-000000000105',4),
      ('a5600000-0000-0000-0000-000000000003','a5600000-0000-0000-0000-000000000106',5);
    INSERT INTO [ATAPUtilities].[BuildSetRuleSet] ([BuildSetId],[RuleSetId],[Ordinal])
      VALUES ('a5600000-0000-0000-0000-000000000004','a5600000-0000-0000-0000-000000000003',0);
    INSERT INTO [ATAPUtilities].[Instantiation]
      ([InstantiationId],[PhiloteId],[BuildSetId],[InstantiationCode])
      VALUES ('a5600000-0000-0000-0000-000000000005','a5600000-0000-0000-0000-000000000005','a5600000-0000-0000-0000-000000000004','CS-I01-contentsummary-initial-v1');

    INSERT INTO [ATAPUtilities].[RuleVariant]
      ([RuleVariantId],[PhiloteId],[RuleId],[OwningRuleSetId],[RuleVariantCode]) VALUES
      ('a5600000-0000-0000-0000-000000000201','a5600000-0000-0000-0000-000000000201','a5600000-0000-0000-0000-000000000101','a5600000-0000-0000-0000-000000000003',N'CS-R01-source-identity-v1'),
      ('a5600000-0000-0000-0000-000000000202','a5600000-0000-0000-0000-000000000202','a5600000-0000-0000-0000-000000000102','a5600000-0000-0000-0000-000000000003',N'CS-R02-content-normalization-v1'),
      ('a5600000-0000-0000-0000-000000000203','a5600000-0000-0000-0000-000000000203','a5600000-0000-0000-0000-000000000103','a5600000-0000-0000-0000-000000000003',N'CS-R03-classification-redaction-v1'),
      ('a5600000-0000-0000-0000-000000000204','a5600000-0000-0000-0000-000000000204','a5600000-0000-0000-0000-000000000104','a5600000-0000-0000-0000-000000000003',N'CS-R04-summary-render-v1'),
      ('a5600000-0000-0000-0000-000000000205','a5600000-0000-0000-0000-000000000205','a5600000-0000-0000-0000-000000000105','a5600000-0000-0000-0000-000000000003',N'CS-R05-freshness-v1'),
      ('a5600000-0000-0000-0000-000000000206','a5600000-0000-0000-0000-000000000206','a5600000-0000-0000-0000-000000000106','a5600000-0000-0000-0000-000000000003',N'CS-R06-query-ranking-v1');
    INSERT INTO [ATAPUtilities].[RuleVariantState]
      ([RuleVariantStateId],[RuleVariantId],[ValidFromUtc],[ValidToUtc],[Purpose],[ExecutorContractCode],[NormalizedBody],[LifecycleStatusCode]) VALUES
      ('a5600000-0000-0000-0000-000000000301','a5600000-0000-0000-0000-000000000201',@SeedAt,NULL,N'Frozen ContentSummary source identity contract',N'CS-R01-source-identity-v1',N'v1:registered-root+ordinal-relative-path','Active'),
      ('a5600000-0000-0000-0000-000000000302','a5600000-0000-0000-0000-000000000202',@SeedAt,NULL,N'Frozen ContentSummary normalization contract',N'CS-R02-content-normalization-v1',N'v1:exact-byte+lf-no-bom-sha256','Active'),
      ('a5600000-0000-0000-0000-000000000303','a5600000-0000-0000-0000-000000000203',@SeedAt,NULL,N'Frozen ContentSummary classification contract',N'CS-R03-classification-redaction-v1',N'v1:authorize+classify+redact-before-egress','Active'),
      ('a5600000-0000-0000-0000-000000000304','a5600000-0000-0000-0000-000000000204',@SeedAt,NULL,N'Frozen ContentSummary render contract',N'CS-R04-summary-render-v1',N'v1:exact-source+prompt+generator','Active'),
      ('a5600000-0000-0000-0000-000000000305','a5600000-0000-0000-0000-000000000205',@SeedAt,NULL,N'Frozen ContentSummary freshness contract',N'CS-R05-freshness-v1',N'v1:as-of-watermarks-fail-unknown','Active'),
      ('a5600000-0000-0000-0000-000000000306','a5600000-0000-0000-0000-000000000206',@SeedAt,NULL,N'Frozen ContentSummary query ranking contract',N'CS-R06-query-ranking-v1',N'v1:authorized-tag-rank-order-limit','Active');
    INSERT INTO [ATAPUtilities].[RuleSetRuleOccurrence]
      ([RuleSetRuleOccurrenceId],[RuleSetId],[RuleVariantId],[RuleSetMembershipRoleCode],[Ordinal],[ConditionExpression],[ValidFromUtc],[ValidToUtc]) VALUES
      ('a5600000-0000-0000-0000-000000000401','a5600000-0000-0000-0000-000000000003','a5600000-0000-0000-0000-000000000201','Add',0,NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000000402','a5600000-0000-0000-0000-000000000003','a5600000-0000-0000-0000-000000000202','Add',1,NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000000403','a5600000-0000-0000-0000-000000000003','a5600000-0000-0000-0000-000000000203','Add',2,NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000000404','a5600000-0000-0000-0000-000000000003','a5600000-0000-0000-0000-000000000204','Add',3,NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000000405','a5600000-0000-0000-0000-000000000003','a5600000-0000-0000-0000-000000000205','Add',4,NULL,@SeedAt,NULL),
      ('a5600000-0000-0000-0000-000000000406','a5600000-0000-0000-0000-000000000003','a5600000-0000-0000-0000-000000000206','Add',5,NULL,@SeedAt,NULL);
    INSERT INTO [ATAPUtilities].[BuildSetRuleSetOccurrence]
      ([BuildSetRuleSetOccurrenceId],[BuildSetId],[RuleSetId],[Ordinal],[ConditionExpression],[ValidFromUtc],[ValidToUtc])
      VALUES ('a5600000-0000-0000-0000-000000000501','a5600000-0000-0000-0000-000000000004','a5600000-0000-0000-0000-000000000003',0,NULL,@SeedAt,NULL);

    INSERT INTO [ATAPUtilities].[TagAssignmentEntityType]
      ([EntityTypeCode],[TargetSchemaName],[TargetTableName],[TargetIdColumnName],[IsClassificationOnly],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
      VALUES (N'content-summary-version',N'ATAPUtilities',N'ContentSummaryVersion',N'ContentSummaryVersionId',1,@SeedPrincipal,@SeedSource,@SeedAt,@SeedAt);

    EXEC sys.sp_executesql N'ALTER TRIGGER [ATAPUtilities].[TR_TagAssignment_HistoryAndTarget]
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
    ) THROW 59021, ''TagAssignment is append/close-only.'', 1;
    IF EXISTS (SELECT 1 FROM inserted WHERE IsClassificationOnly<>1)
        THROW 59022, ''Tags classify and never authorize.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        WHERE (i.EntityTypeCode=N''rule'' AND
               NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleId=i.EntityId))
           OR (i.EntityTypeCode=N''instantiation'' AND
               NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Instantiation] WHERE InstantiationId=i.EntityId))
           OR (i.EntityTypeCode=N''content-summary-version'' AND
               NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryVersion]
                           WHERE ContentSummaryVersionId=i.EntityId))
           OR i.EntityTypeCode NOT IN (N''rule'',N''instantiation'',N''content-summary-version'')
    ) THROW 59023, ''Tag assignment target does not exist in its allow-listed entity type.'', 1;
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
            SELECT 1 FROM [ATAPUtilities].[ResolveTagAsOf](i.TagId,i.ValidFromUtc)
            WHERE ResolutionStatusCode=''Resolved''
        )
    ) THROW 59024, ''Assignment requires an effective Tag and active namespace steward.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS i
        INNER JOIN [ATAPUtilities].[TagAssignment] AS other WITH (UPDLOCK,HOLDLOCK)
            ON other.TagId=i.TagId AND other.EntityTypeCode=i.EntityTypeCode
           AND other.EntityId=i.EntityId AND other.TagAssignmentId<>i.TagAssignmentId
           AND i.ValidFromUtc<COALESCE(other.ValidToUtc,CONVERT(datetime2(7),''9999-12-31T23:59:59.9999999''))
           AND other.ValidFromUtc<COALESCE(i.ValidToUtc,CONVERT(datetime2(7),''9999-12-31T23:59:59.9999999''))
    ) THROW 59025, ''Tag assignment intervals for one target cannot overlap.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_Repository_AppendOnly]
ON [ATAPUtilities].[Repository] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 60020, ''Repository history is append-only.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_RepositoryRootRegistration_AppendOnly]
ON [ATAPUtilities].[RepositoryRootRegistration] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 60021, ''Repository root registration history is append-only.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_SourceArtifact_AppendOnly]
ON [ATAPUtilities].[SourceArtifact] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 60022, ''SourceArtifact identity is append-only.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_SourceArtifactVersion_AppendOnly]
ON [ATAPUtilities].[SourceArtifactVersion] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 60023, ''SourceArtifactVersion history is append-only.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_ContentSummary_AppendOnly]
ON [ATAPUtilities].[ContentSummary] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 60024, ''ContentSummary identity is append-only.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_ContentSummaryVersion_AppendOnly]
ON [ATAPUtilities].[ContentSummaryVersion] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 60025, ''ContentSummaryVersion history is append-only.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_ContentSummaryDependency_AppendOnly]
ON [ATAPUtilities].[ContentSummaryDependency] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 60026, ''ContentSummary dependency history is append-only.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_ContentSummaryRefreshAttempt_AppendOnly]
ON [ATAPUtilities].[ContentSummaryRefreshAttempt] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 60027, ''ContentSummary refresh history is append-only.'', 1; END;';
    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_ContentSummaryIngestionRequest_AppendOnly]
ON [ATAPUtilities].[ContentSummaryIngestionRequest] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 60028, ''ContentSummary ingestion request history is append-only.'', 1; END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[CaptureContentSummaryObservationV1]
    @IdempotencyKey uniqueidentifier,
    @CanonicalRequestSha256 binary(32),
    @RunId uniqueidentifier,
    @RepositoryId uniqueidentifier,
    @RootRegistrationId uniqueidentifier,
    @RepoRelativePath nvarchar(1024),
    @SourceArtifactId uniqueidentifier,
    @SourceArtifactVersionId uniqueidentifier,
    @ContentSummaryId uniqueidentifier,
    @ContentSummaryVersionId uniqueidentifier,
    @PriorContentSummaryVersionId uniqueidentifier,
    @ObservedAtUtc datetime2(7),
    @RecordedAtUtc datetime2(7),
    @ByteSha256 binary(32),
    @NormalizedContentSha256 binary(32),
    @ByteCount bigint,
    @EncodingCode varchar(32),
    @HasBom bit,
    @LineEndingCode varchar(8),
    @FinalNewline bit,
    @HarvesterEntityId uniqueidentifier,
    @SummaryProfileCode varchar(64),
    @ClassificationPolicyId uniqueidentifier,
    @SourceIdentityRuleVariantId uniqueidentifier,
    @NormalizationRuleVariantId uniqueidentifier,
    @ClassificationRuleVariantId uniqueidentifier,
    @SummaryRenderRuleVariantId uniqueidentifier,
    @FreshnessRuleVariantId uniqueidentifier,
    @QueryRankingRuleVariantId uniqueidentifier,
    @InstantiationId uniqueidentifier,
    @PromptRuleVariantId uniqueidentifier,
    @GeneratorKindCode varchar(32),
    @GeneratorName nvarchar(128),
    @GeneratorVersion nvarchar(64),
    @ModelProvider nvarchar(64),
    @ModelId nvarchar(128),
    @ModelRevision nvarchar(128),
    @ModelEffort varchar(16),
    @LifecycleCode varchar(16),
    @SafeSummaryText nvarchar(max),
    @SafeLocator nvarchar(2048),
    @WasRedacted bit,
    @RedactionEvidenceId uniqueidentifier,
    @SummaryContentSha256 binary(32),
    @ExclusionEvidenceId uniqueidentifier,
    @LifecycleReasonCode varchar(64),
    @DerivationFingerprint binary(32),
    @Dependencies [ATAPUtilities].[ContentSummaryDependencyInput] READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    IF @IdempotencyKey IS NULL OR @CanonicalRequestSha256 IS NULL OR @RunId IS NULL OR @RepositoryId IS NULL
       OR @RootRegistrationId IS NULL OR @SourceArtifactId IS NULL
       OR @SourceArtifactVersionId IS NULL OR @ContentSummaryId IS NULL
       OR @ContentSummaryVersionId IS NULL OR @ObservedAtUtc IS NULL OR @RecordedAtUtc IS NULL
       OR @ByteSha256 IS NULL OR @NormalizedContentSha256 IS NULL OR @ByteCount IS NULL OR @ByteCount<0
       OR NULLIF(@EncodingCode,'''') IS NULL OR @HasBom IS NULL OR @FinalNewline IS NULL
       OR @LineEndingCode NOT IN (''lf'',''crlf'',''cr'',''mixed'',''none'')
       OR @HarvesterEntityId IS NULL OR NULLIF(@SummaryProfileCode,'''') IS NULL
       OR @ClassificationPolicyId IS NULL OR @SourceIdentityRuleVariantId IS NULL
       OR @NormalizationRuleVariantId IS NULL OR @ClassificationRuleVariantId IS NULL
       OR @SummaryRenderRuleVariantId IS NULL OR @FreshnessRuleVariantId IS NULL
       OR @QueryRankingRuleVariantId IS NULL OR @InstantiationId IS NULL
       OR @PromptRuleVariantId IS NULL OR @WasRedacted IS NULL OR @DerivationFingerprint IS NULL
       OR @ObservedAtUtc>@RecordedAtUtc
        THROW 60100, ''CS-REQ-001: required input, enum, size, or time contract failed.'', 1;

    DECLARE @WrappedPath nvarchar(1030)=N''/''+COALESCE(@RepoRelativePath,N'''')+N''/'';
    IF NULLIF(@RepoRelativePath,N'''') IS NULL OR LEFT(@RepoRelativePath,1) IN (N''/'',N''\'')
       OR CHARINDEX(N''\'',@RepoRelativePath)>0 OR CHARINDEX(N'':'',@RepoRelativePath)>0
       OR CHARINDEX(N''//'',@WrappedPath)>0 OR CHARINDEX(N''/./'',@WrappedPath)>0
       OR CHARINDEX(N''/../'',@WrappedPath)>0
        THROW 60101, ''CS-SRC-002: repository-relative path is not canonical.'', 1;
    DECLARE @PathOrdinal int=1;
    WHILE @PathOrdinal<=LEN(@RepoRelativePath)
    BEGIN
      IF UNICODE(SUBSTRING(@RepoRelativePath,@PathOrdinal,1))<32
        THROW 60102, ''CS-SRC-002: repository-relative path contains a control character.'', 1;
      SET @PathOrdinal+=1;
    END;

    IF @SourceIdentityRuleVariantId<>''a5600000-0000-0000-0000-000000000201''
       OR @NormalizationRuleVariantId<>''a5600000-0000-0000-0000-000000000202''
       OR @ClassificationRuleVariantId<>''a5600000-0000-0000-0000-000000000203''
       OR @SummaryRenderRuleVariantId<>''a5600000-0000-0000-0000-000000000204''
       OR @FreshnessRuleVariantId<>''a5600000-0000-0000-0000-000000000205''
       OR @QueryRankingRuleVariantId<>''a5600000-0000-0000-0000-000000000206''
       OR @InstantiationId<>''a5600000-0000-0000-0000-000000000005''
        THROW 60103, ''CS-RULE-001: frozen RuleVariant or Instantiation identity mismatch.'', 1;
    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleVariantState]
        WHERE [RuleVariantId] IN (@SourceIdentityRuleVariantId,@NormalizationRuleVariantId,
          @ClassificationRuleVariantId,@SummaryRenderRuleVariantId,@FreshnessRuleVariantId,
          @QueryRankingRuleVariantId,@PromptRuleVariantId)
          AND [LifecycleStatusCode]=''Active'' AND [ValidFromUtc]<=@RecordedAtUtc
          AND ([ValidToUtc] IS NULL OR @RecordedAtUtc<[ValidToUtc]))
       <> (SELECT COUNT_BIG(DISTINCT v.[RuleVariantId]) FROM (VALUES
          (@SourceIdentityRuleVariantId),(@NormalizationRuleVariantId),(@ClassificationRuleVariantId),
          (@SummaryRenderRuleVariantId),(@FreshnessRuleVariantId),(@QueryRankingRuleVariantId),
          (@PromptRuleVariantId)) v([RuleVariantId]))
        THROW 60104, ''CS-RULE-001: required RuleVariant is not active at RecordedAtUtc.'', 1;

    IF @LifecycleCode NOT IN (''harvested'',''summarized'',''stale'',''excluded'',''retired'')
        THROW 60105, ''CS-REQ-001: unsupported lifecycle code.'', 1;
    IF (@LifecycleCode=''summarized'' AND
        (((@SafeSummaryText IS NULL AND @SafeLocator IS NULL)
          OR (@SafeSummaryText IS NOT NULL AND @SafeLocator IS NOT NULL))
         OR @SummaryContentSha256 IS NULL OR @ExclusionEvidenceId IS NOT NULL
         OR NULLIF(@GeneratorKindCode,'''') IS NULL OR NULLIF(@GeneratorName,N'''') IS NULL
         OR NULLIF(@GeneratorVersion,N'''') IS NULL OR NULLIF(@ModelProvider,N'''') IS NULL
         OR NULLIF(@ModelId,N'''') IS NULL OR NULLIF(@ModelRevision,N'''') IS NULL
         OR NULLIF(@ModelEffort,'''') IS NULL))
       OR (@LifecycleCode=''excluded'' AND
           (@SafeSummaryText IS NOT NULL OR @SafeLocator IS NOT NULL OR @SummaryContentSha256 IS NOT NULL
            OR @ExclusionEvidenceId IS NULL OR NULLIF(@LifecycleReasonCode,'''') IS NULL))
       OR (@LifecycleCode=''harvested'' AND
           (@SafeSummaryText IS NOT NULL OR @SafeLocator IS NOT NULL OR @SummaryContentSha256 IS NOT NULL
            OR @ExclusionEvidenceId IS NOT NULL OR @PriorContentSummaryVersionId IS NOT NULL))
       OR (@LifecycleCode IN (''stale'',''retired'') AND
           (@SafeSummaryText IS NOT NULL OR @SafeLocator IS NOT NULL OR @SummaryContentSha256 IS NOT NULL
            OR @PriorContentSummaryVersionId IS NULL OR NULLIF(@LifecycleReasonCode,'''') IS NULL))
        THROW 60106, ''CS-REQ-001: lifecycle payload contract failed.'', 1;
    IF (@WasRedacted=1 AND (@LifecycleCode<>''summarized'' OR @RedactionEvidenceId IS NULL))
       OR (@WasRedacted=0 AND @RedactionEvidenceId IS NOT NULL)
       OR (@SafeSummaryText LIKE N''%ATAP_SECRET_CANARY%'')
        THROW 60107, ''CS-CLASS-002: redaction evidence or secret-canary contract failed.'', 1;

    IF EXISTS
    (
      SELECT 1 FROM @Dependencies d
      LEFT JOIN [ATAPUtilities].[SourceArtifactVersion] sv
        ON sv.[SourceArtifactVersionId]=d.[SourceArtifactVersionId]
      WHERE (d.[SourceArtifactVersionId] IS NOT NULL AND sv.[SourceArtifactVersionId] IS NULL)
         OR (sv.[ObservedAtUtc]>@ObservedAtUtc)
    ) THROW 60108, ''CS-REQ-001: dependency target is missing or later than the observation.'', 1;

    BEGIN TRY
      BEGIN TRANSACTION;
      DECLARE @LockResult int;
      DECLARE @LockResource nvarchar(255)=
        N''ATAPUtilities.ContentSummary:''+LOWER(CONVERT(nvarchar(36),@IdempotencyKey));
      EXEC @LockResult=sys.sp_getapplock
        @Resource=@LockResource,
        @LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=15000,@DbPrincipal=''public'';
      IF @LockResult<0 THROW 60109, ''CS-HARVEST-001: unable to acquire idempotency lock.'', 1;

      DECLARE @ExistingRequestHash binary(32), @ResolvedSourceArtifactId uniqueidentifier,
              @ResolvedSourceVersionId uniqueidentifier, @ResolvedSummaryId uniqueidentifier,
              @ResolvedSummaryVersionId uniqueidentifier, @SourceSequence bigint,
              @SummarySequence bigint, @ResolvedLifecycle varchar(16);
      SELECT @ExistingRequestHash=[CanonicalRequestSha256],
             @ResolvedSourceVersionId=[SourceArtifactVersionId],
             @ResolvedSummaryVersionId=[ContentSummaryVersionId]
      FROM [ATAPUtilities].[ContentSummaryIngestionRequest] WITH (UPDLOCK,HOLDLOCK)
      WHERE [IdempotencyKey]=@IdempotencyKey;
      IF @ExistingRequestHash IS NOT NULL
      BEGIN
        IF @ExistingRequestHash<>@CanonicalRequestSha256
          THROW 60110, ''CS-IDEMP-001: idempotency key is bound to a different canonical request hash.'', 1;
        SELECT @ResolvedSourceArtifactId=sv.[SourceArtifactId],@SourceSequence=sv.[VersionSequence]
          FROM [ATAPUtilities].[SourceArtifactVersion] sv WHERE sv.[SourceArtifactVersionId]=@ResolvedSourceVersionId;
        SELECT @ResolvedSummaryId=cv.[ContentSummaryId],@SummarySequence=cv.[VersionSequence],
               @ResolvedLifecycle=cv.[LifecycleCode]
          FROM [ATAPUtilities].[ContentSummaryVersion] cv WHERE cv.[ContentSummaryVersionId]=@ResolvedSummaryVersionId;
        COMMIT TRANSACTION;
        SELECT CAST(''Replayed'' AS varchar(32)) AS [ReplayStatus],@IdempotencyKey AS [IdempotencyKey],
               @ResolvedSourceArtifactId AS [SourceArtifactId],@ResolvedSourceVersionId AS [SourceArtifactVersionId],
               @ResolvedSummaryId AS [ContentSummaryId],@ResolvedSummaryVersionId AS [ContentSummaryVersionId],
               @SourceSequence AS [SourceArtifactVersionSequence],@SummarySequence AS [ContentSummaryVersionSequence],
               @ResolvedLifecycle AS [LifecycleCode],CAST(NULL AS varchar(32)) AS [ErrorCode];
        RETURN;
      END;

      IF NOT EXISTS
      (
        SELECT 1 FROM [ATAPUtilities].[Repository] r WITH (UPDLOCK,HOLDLOCK)
        JOIN [ATAPUtilities].[RepositoryRootRegistration] rr WITH (UPDLOCK,HOLDLOCK)
          ON rr.[RepositoryId]=r.[RepositoryId]
        WHERE r.[RepositoryId]=@RepositoryId AND r.[CreatedAtUtc]<=@ObservedAtUtc
          AND r.[RetiredAtUtc] IS NULL AND rr.[RepositoryRootRegistrationId]=@RootRegistrationId
          AND rr.[RegisteredAtUtc]<=@ObservedAtUtc AND rr.[RetiredAtUtc] IS NULL
      ) THROW 60111, ''CS-SRC-001: Repository/root registration is missing, retired, or ambiguous.'', 1;

      SELECT @ResolvedSummaryVersionId=cv.[ContentSummaryVersionId],
             @ResolvedSummaryId=cv.[ContentSummaryId],@SummarySequence=cv.[VersionSequence],
             @ResolvedLifecycle=cv.[LifecycleCode],@ResolvedSourceVersionId=cv.[SourceArtifactVersionId],
             @ResolvedSourceArtifactId=cv.[SourceArtifactId]
      FROM [ATAPUtilities].[ContentSummaryVersion] cv WITH (UPDLOCK,HOLDLOCK)
      WHERE cv.[DerivationFingerprint]=@DerivationFingerprint;
      IF @ResolvedSummaryVersionId IS NOT NULL
      BEGIN
        IF @ResolvedSummaryVersionId<>@ContentSummaryVersionId OR @ResolvedSummaryId<>@ContentSummaryId
           OR @ResolvedSourceVersionId<>@SourceArtifactVersionId OR @ResolvedSourceArtifactId<>@SourceArtifactId
          THROW 60112, ''CS-HASH-001: derivation fingerprint is bound to different durable identities.'', 1;
        IF EXISTS
        (
          SELECT d.[DependencyOrdinal],d.[DependencyKindCode],d.[SourceArtifactVersionId],d.[ExternalReferenceKindCode],d.[ExternalReferenceSha256],d.[EvidenceEntityId]
          FROM @Dependencies d
          EXCEPT
          SELECT d.[DependencyOrdinal],d.[DependencyKindCode],d.[SourceArtifactVersionId],d.[ExternalReferenceKindCode],d.[ExternalReferenceSha256],d.[EvidenceEntityId]
          FROM [ATAPUtilities].[ContentSummaryDependency] d WHERE d.[ContentSummaryVersionId]=@ResolvedSummaryVersionId
        ) OR EXISTS
        (
          SELECT d.[DependencyOrdinal],d.[DependencyKindCode],d.[SourceArtifactVersionId],d.[ExternalReferenceKindCode],d.[ExternalReferenceSha256],d.[EvidenceEntityId]
          FROM [ATAPUtilities].[ContentSummaryDependency] d WHERE d.[ContentSummaryVersionId]=@ResolvedSummaryVersionId
          EXCEPT
          SELECT d.[DependencyOrdinal],d.[DependencyKindCode],d.[SourceArtifactVersionId],d.[ExternalReferenceKindCode],d.[ExternalReferenceSha256],d.[EvidenceEntityId]
          FROM @Dependencies d
        ) THROW 60113, ''CS-HASH-001: derivation dependency set mismatch.'', 1;
        SELECT @SourceSequence=[VersionSequence] FROM [ATAPUtilities].[SourceArtifactVersion]
          WHERE [SourceArtifactVersionId]=@ResolvedSourceVersionId;
        INSERT INTO [ATAPUtilities].[ContentSummaryIngestionRequest]
          ([IdempotencyKey],[CanonicalRequestSha256],[RequestStatusCode],[SourceArtifactVersionId],[ContentSummaryVersionId],[RecordedAtUtc],[CompletedAtUtc])
          VALUES (@IdempotencyKey,@CanonicalRequestSha256,''Completed'',@ResolvedSourceVersionId,@ResolvedSummaryVersionId,@RecordedAtUtc,@RecordedAtUtc);
        COMMIT TRANSACTION;
        SELECT CAST(''DerivationReplay'' AS varchar(32)) AS [ReplayStatus],@IdempotencyKey AS [IdempotencyKey],
               @ResolvedSourceArtifactId AS [SourceArtifactId],@ResolvedSourceVersionId AS [SourceArtifactVersionId],
               @ResolvedSummaryId AS [ContentSummaryId],@ResolvedSummaryVersionId AS [ContentSummaryVersionId],
               @SourceSequence AS [SourceArtifactVersionSequence],@SummarySequence AS [ContentSummaryVersionSequence],
               @ResolvedLifecycle AS [LifecycleCode],CAST(NULL AS varchar(32)) AS [ErrorCode];
        RETURN;
      END;

      SELECT @ResolvedSourceArtifactId=[SourceArtifactId]
      FROM [ATAPUtilities].[SourceArtifact] WITH (UPDLOCK,HOLDLOCK)
      WHERE [RepositoryId]=@RepositoryId AND [RepoRelativePath]=@RepoRelativePath;
      IF @ResolvedSourceArtifactId IS NULL
      BEGIN
        IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Philote] WHERE [PhiloteId]=@SourceArtifactId)
          THROW 60114, ''CS-SRC-002: requested SourceArtifactId collides with another Philote.'', 1;
        INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub]) VALUES (@SourceArtifactId,NULL);
        INSERT INTO [ATAPUtilities].[PhiloteValidityPeriod]
          ([PhiloteValidityPeriodId],[PhiloteId],[PreviousValidToUtc],[ValidFromUtc],[ValidToUtc])
          VALUES (NEWID(),@SourceArtifactId,NULL,@RecordedAtUtc,NULL);
        INSERT INTO [ATAPUtilities].[SourceArtifact]
          ([SourceArtifactId],[PhiloteId],[RepositoryId],[LocatorKindCode],[RepoRelativePath],[CreatedAtUtc],[RetiredAtUtc])
          VALUES (@SourceArtifactId,@SourceArtifactId,@RepositoryId,''RepositoryPath'',@RepoRelativePath,@RecordedAtUtc,NULL);
        SET @ResolvedSourceArtifactId=@SourceArtifactId;
      END
      ELSE IF @ResolvedSourceArtifactId<>@SourceArtifactId
        THROW 60115, ''CS-SRC-002: repository path is bound to a different SourceArtifactId.'', 1;

      SELECT @ResolvedSourceVersionId=[SourceArtifactVersionId],@SourceSequence=[VersionSequence]
      FROM [ATAPUtilities].[SourceArtifactVersion] WITH (UPDLOCK,HOLDLOCK)
      WHERE [SourceArtifactId]=@ResolvedSourceArtifactId AND [RunId]=@RunId;
      IF @ResolvedSourceVersionId IS NULL
      BEGIN
        IF EXISTS (SELECT 1 FROM [ATAPUtilities].[SourceArtifactVersion]
                   WHERE [SourceArtifactVersionId]=@SourceArtifactVersionId)
          THROW 60116, ''CS-HASH-001: requested SourceArtifactVersionId already exists.'', 1;
        SELECT @SourceSequence=COALESCE(MAX([VersionSequence]),0)+1
          FROM [ATAPUtilities].[SourceArtifactVersion] WITH (UPDLOCK,HOLDLOCK)
          WHERE [SourceArtifactId]=@ResolvedSourceArtifactId;
        INSERT INTO [ATAPUtilities].[SourceArtifactVersion]
          ([SourceArtifactVersionId],[SourceArtifactId],[RepositoryId],[VersionSequence],[RunId],
           [RepositoryRootRegistrationId],[HarvesterEntityId],[ByteSha256],[NormalizedContentSha256],
           [ByteCount],[EncodingCode],[HasBom],[LineEndingCode],[FinalNewline],[ObservedAtUtc],[RecordedAtUtc])
          VALUES (@SourceArtifactVersionId,@ResolvedSourceArtifactId,@RepositoryId,@SourceSequence,@RunId,
                  @RootRegistrationId,@HarvesterEntityId,@ByteSha256,@NormalizedContentSha256,
                  @ByteCount,@EncodingCode,@HasBom,@LineEndingCode,@FinalNewline,@ObservedAtUtc,@RecordedAtUtc);
        SET @ResolvedSourceVersionId=@SourceArtifactVersionId;
      END
      ELSE IF @ResolvedSourceVersionId<>@SourceArtifactVersionId OR EXISTS
      (
        SELECT 1 FROM [ATAPUtilities].[SourceArtifactVersion]
        WHERE [SourceArtifactVersionId]=@ResolvedSourceVersionId
          AND ([RepositoryRootRegistrationId]<>@RootRegistrationId OR [HarvesterEntityId]<>@HarvesterEntityId
            OR [ByteSha256]<>@ByteSha256 OR [NormalizedContentSha256]<>@NormalizedContentSha256
            OR [ByteCount]<>@ByteCount OR [EncodingCode]<>@EncodingCode OR [HasBom]<>@HasBom
            OR [LineEndingCode]<>@LineEndingCode OR [FinalNewline]<>@FinalNewline
            OR [ObservedAtUtc]<>@ObservedAtUtc OR [RecordedAtUtc]<>@RecordedAtUtc)
      ) THROW 60117, ''CS-HASH-001: observation run is bound to different source facts.'', 1;

      SELECT @ResolvedSummaryId=[ContentSummaryId]
      FROM [ATAPUtilities].[ContentSummary] WITH (UPDLOCK,HOLDLOCK)
      WHERE [SourceArtifactId]=@ResolvedSourceArtifactId
        AND [SummaryProfileCode]=@SummaryProfileCode AND [ClassificationPolicyId]=@ClassificationPolicyId;
      IF @ResolvedSummaryId IS NULL
      BEGIN
        IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Philote] WHERE [PhiloteId]=@ContentSummaryId)
          THROW 60118, ''CS-REQ-001: requested ContentSummaryId collides with another Philote.'', 1;
        INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub]) VALUES (@ContentSummaryId,NULL);
        INSERT INTO [ATAPUtilities].[PhiloteValidityPeriod]
          ([PhiloteValidityPeriodId],[PhiloteId],[PreviousValidToUtc],[ValidFromUtc],[ValidToUtc])
          VALUES (NEWID(),@ContentSummaryId,NULL,@RecordedAtUtc,NULL);
        INSERT INTO [ATAPUtilities].[ContentSummary]
          ([ContentSummaryId],[PhiloteId],[SourceArtifactId],[SummaryProfileCode],[ClassificationPolicyId],[CreatedAtUtc],[RetiredAtUtc])
          VALUES (@ContentSummaryId,@ContentSummaryId,@ResolvedSourceArtifactId,@SummaryProfileCode,@ClassificationPolicyId,@RecordedAtUtc,NULL);
        SET @ResolvedSummaryId=@ContentSummaryId;
      END
      ELSE IF @ResolvedSummaryId<>@ContentSummaryId
        THROW 60119, ''CS-REQ-001: summary subject/profile/policy is bound to a different ContentSummaryId.'', 1;

      IF @PriorContentSummaryVersionId IS NOT NULL AND NOT EXISTS
      (
        SELECT 1 FROM [ATAPUtilities].[ContentSummaryVersion]
        WHERE [ContentSummaryVersionId]=@PriorContentSummaryVersionId
          AND [ContentSummaryId]=@ResolvedSummaryId AND [RecordedAtUtc]<=@RecordedAtUtc
      ) THROW 60120, ''CS-FRESH-001: prior summary version is missing, foreign, or later.'', 1;
      IF EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummaryVersion]
                 WHERE [ContentSummaryVersionId]=@ContentSummaryVersionId)
        THROW 60121, ''CS-HASH-001: requested ContentSummaryVersionId already exists.'', 1;
      SELECT @SummarySequence=COALESCE(MAX([VersionSequence]),0)+1
        FROM [ATAPUtilities].[ContentSummaryVersion] WITH (UPDLOCK,HOLDLOCK)
        WHERE [ContentSummaryId]=@ResolvedSummaryId;
      INSERT INTO [ATAPUtilities].[ContentSummaryVersion]
        ([ContentSummaryVersionId],[ContentSummaryId],[SourceArtifactId],[SourceArtifactVersionId],
         [VersionSequence],[PriorContentSummaryVersionId],[LifecycleCode],[LifecycleReasonCode],
         [SourceIdentityRuleVariantId],[NormalizationRuleVariantId],[ClassificationRuleVariantId],
         [SummaryRenderRuleVariantId],[FreshnessRuleVariantId],[QueryRankingRuleVariantId],
         [InstantiationId],[PromptRuleVariantId],[GeneratorKindCode],[GeneratorName],[GeneratorVersion],
         [ModelProvider],[ModelId],[ModelRevision],[ModelEffort],[SafeSummaryText],[SafeLocator],
         [WasRedacted],[RedactionEvidenceId],[SummaryContentSha256],[ExclusionEvidenceId],
         [DerivationFingerprint],[GeneratedAtUtc],[RecordedAtUtc])
      VALUES (@ContentSummaryVersionId,@ResolvedSummaryId,@ResolvedSourceArtifactId,@ResolvedSourceVersionId,
              @SummarySequence,@PriorContentSummaryVersionId,@LifecycleCode,@LifecycleReasonCode,
              @SourceIdentityRuleVariantId,@NormalizationRuleVariantId,@ClassificationRuleVariantId,
              @SummaryRenderRuleVariantId,@FreshnessRuleVariantId,@QueryRankingRuleVariantId,
              @InstantiationId,@PromptRuleVariantId,@GeneratorKindCode,@GeneratorName,@GeneratorVersion,
              @ModelProvider,@ModelId,@ModelRevision,@ModelEffort,@SafeSummaryText,@SafeLocator,
              @WasRedacted,@RedactionEvidenceId,@SummaryContentSha256,@ExclusionEvidenceId,
              @DerivationFingerprint,CASE WHEN @LifecycleCode=''summarized'' THEN @RecordedAtUtc END,@RecordedAtUtc);
      SET @ResolvedSummaryVersionId=@ContentSummaryVersionId;
      SET @ResolvedLifecycle=@LifecycleCode;

      INSERT INTO [ATAPUtilities].[ContentSummaryDependency]
        ([ContentSummaryDependencyId],[ContentSummaryVersionId],[DependencyOrdinal],[DependencyKindCode],
         [SourceArtifactVersionId],[ExternalReferenceKindCode],[ExternalReferenceSha256],[CapturedAtUtc],[EvidenceEntityId])
      SELECT NEWID(),@ResolvedSummaryVersionId,d.[DependencyOrdinal],d.[DependencyKindCode],
             d.[SourceArtifactVersionId],d.[ExternalReferenceKindCode],d.[ExternalReferenceSha256],
             @RecordedAtUtc,d.[EvidenceEntityId]
      FROM @Dependencies d;

      INSERT INTO [ATAPUtilities].[ContentSummaryIngestionRequest]
        ([IdempotencyKey],[CanonicalRequestSha256],[RequestStatusCode],[SourceArtifactVersionId],
         [ContentSummaryVersionId],[RecordedAtUtc],[CompletedAtUtc])
        VALUES (@IdempotencyKey,@CanonicalRequestSha256,''Completed'',@ResolvedSourceVersionId,
                @ResolvedSummaryVersionId,@RecordedAtUtc,@RecordedAtUtc);
      COMMIT TRANSACTION;

      SELECT CAST(''Created'' AS varchar(32)) AS [ReplayStatus],@IdempotencyKey AS [IdempotencyKey],
             @ResolvedSourceArtifactId AS [SourceArtifactId],@ResolvedSourceVersionId AS [SourceArtifactVersionId],
             @ResolvedSummaryId AS [ContentSummaryId],@ResolvedSummaryVersionId AS [ContentSummaryVersionId],
             @SourceSequence AS [SourceArtifactVersionSequence],@SummarySequence AS [ContentSummaryVersionSequence],
             @ResolvedLifecycle AS [LifecycleCode],CAST(NULL AS varchar(32)) AS [ErrorCode];
    END TRY
    BEGIN CATCH
      IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
      THROW;
    END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[QueryContentSummaryCandidatesAsOfV1]
    @AuthorizedRepositories [ATAPUtilities].[ContentSummaryAuthorizedRepositoryInput] READONLY,
    @TagMatches [ATAPUtilities].[ContentSummaryTagMatchInput] READONLY,
    @MatchMode varchar(3),
    @AsOfUtc datetime2(7),
    @FreshnessMode varchar(16),
    @Limit int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @AsOfUtc IS NULL OR @MatchMode NOT IN (''Any'',''All'')
       OR @FreshnessMode NOT IN (''CurrentOnly'',''IncludeStale'') OR @Limit NOT BETWEEN 1 AND 100
      THROW 60200, ''CS-QUERY-002: query mode, as-of, freshness mode, or limit is invalid.'', 1;

    DECLARE @RequestedCount int=(SELECT COUNT_BIG(DISTINCT [RequestOrdinal]) FROM @TagMatches);
    SELECT DISTINCT
      cv.[ContentSummaryVersionId],cv.[ContentSummaryId],cv.[SourceArtifactId],
      cv.[SourceArtifactVersionId],sa.[RepositoryId],sa.[RepoRelativePath],
      cv.[SafeSummaryText],cv.[SafeLocator],tm.[RequestOrdinal],tm.[RequestedTagId],
      tm.[MatchedTagId],tm.[Depth],tm.[TraversalOrdinal],tm.[PathWeight],
      sv.[ObservedAtUtc] AS [SourceObservedAtUtc],cv.[GeneratedAtUtc],cv.[RecordedAtUtc],
      sv.[HarvesterEntityId] AS [ProducerEntityId],sv.[NormalizedContentSha256],
      cv.[SummaryContentSha256],cv.[DerivationFingerprint],
      CASE WHEN EXISTS
        (SELECT 1 FROM [ATAPUtilities].[SourceArtifactVersion] newer
         WHERE newer.[SourceArtifactId]=cv.[SourceArtifactId]
           AND newer.[ObservedAtUtc]<=@AsOfUtc
           AND (newer.[ObservedAtUtc]>sv.[ObservedAtUtc]
                OR (newer.[ObservedAtUtc]=sv.[ObservedAtUtc]
                    AND newer.[VersionSequence]>sv.[VersionSequence])))
        OR EXISTS
        (SELECT 1 FROM [ATAPUtilities].[ContentSummaryVersion] later
         WHERE later.[ContentSummaryId]=cv.[ContentSummaryId]
           AND later.[RecordedAtUtc]<=@AsOfUtc AND later.[VersionSequence]>cv.[VersionSequence])
        OR EXISTS
        (SELECT required.[RuleVariantId] FROM (VALUES
          (cv.[SourceIdentityRuleVariantId]),(cv.[NormalizationRuleVariantId]),
          (cv.[ClassificationRuleVariantId]),(cv.[SummaryRenderRuleVariantId]),
          (cv.[FreshnessRuleVariantId]),(cv.[QueryRankingRuleVariantId]),
          (cv.[PromptRuleVariantId])) required([RuleVariantId])
         WHERE NOT EXISTS
           (SELECT 1 FROM [ATAPUtilities].[RuleVariantState] stateRow
            WHERE stateRow.[RuleVariantId]=required.[RuleVariantId]
              AND stateRow.[LifecycleStatusCode]=''Active'' AND stateRow.[ValidFromUtc]<=@AsOfUtc
              AND (stateRow.[ValidToUtc] IS NULL OR @AsOfUtc<stateRow.[ValidToUtc])))
        THEN CAST(''stale'' AS varchar(16)) ELSE CAST(''current'' AS varchar(16)) END AS [FreshnessCode]
    INTO #Matches
    FROM @AuthorizedRepositories authorized
    JOIN [ATAPUtilities].[SourceArtifact] sa ON sa.[RepositoryId]=authorized.[RepositoryId]
    JOIN [ATAPUtilities].[ContentSummary] cs ON cs.[SourceArtifactId]=sa.[SourceArtifactId]
    JOIN [ATAPUtilities].[ContentSummaryVersion] cv ON cv.[ContentSummaryId]=cs.[ContentSummaryId]
    JOIN [ATAPUtilities].[SourceArtifactVersion] sv
      ON sv.[SourceArtifactVersionId]=cv.[SourceArtifactVersionId]
     AND sv.[SourceArtifactId]=cv.[SourceArtifactId]
    JOIN [ATAPUtilities].[TagAssignment] assignment
      ON assignment.[EntityTypeCode]=N''content-summary-version''
     AND assignment.[EntityId]=cv.[ContentSummaryVersionId]
     AND assignment.[ValidFromUtc]<=@AsOfUtc
     AND (assignment.[ValidToUtc] IS NULL OR @AsOfUtc<assignment.[ValidToUtc])
     AND assignment.[IsClassificationOnly]=1
    JOIN @TagMatches tm ON tm.[MatchedTagId]=assignment.[TagId]
    CROSS APPLY [ATAPUtilities].[ResolveTagAsOf](assignment.[TagId],@AsOfUtc) resolvedTag
    WHERE cv.[LifecycleCode]=''summarized'' AND cv.[RecordedAtUtc]<=@AsOfUtc
      AND cv.[GeneratedAtUtc]<=@AsOfUtc AND sv.[ObservedAtUtc]<=@AsOfUtc
      AND sa.[RetiredAtUtc] IS NULL AND cs.[RetiredAtUtc] IS NULL
      AND resolvedTag.[ResolutionStatusCode]=''Resolved'';

    SELECT m.[ContentSummaryVersionId],m.[ContentSummaryId],m.[SourceArtifactId],
      m.[SourceArtifactVersionId],m.[RepositoryId],m.[RepoRelativePath],m.[SafeSummaryText],
      m.[SafeLocator],m.[FreshnessCode],m.[SourceObservedAtUtc],m.[GeneratedAtUtc],
      m.[RecordedAtUtc],m.[ProducerEntityId],m.[NormalizedContentSha256],
      m.[SummaryContentSha256],m.[DerivationFingerprint],
      COUNT_BIG(DISTINCT m.[RequestOrdinal]) AS [RequestedMatchCount],
      MIN(m.[Depth]) AS [MinimumTraversalDepth],MAX(m.[PathWeight]) AS [MaximumPathWeight]
    INTO #Aggregated
    FROM #Matches m
    GROUP BY m.[ContentSummaryVersionId],m.[ContentSummaryId],m.[SourceArtifactId],
      m.[SourceArtifactVersionId],m.[RepositoryId],m.[RepoRelativePath],m.[SafeSummaryText],
      m.[SafeLocator],m.[FreshnessCode],m.[SourceObservedAtUtc],m.[GeneratedAtUtc],
      m.[RecordedAtUtc],m.[ProducerEntityId],m.[NormalizedContentSha256],
      m.[SummaryContentSha256],m.[DerivationFingerprint]
    HAVING @MatchMode=''Any'' OR COUNT_BIG(DISTINCT m.[RequestOrdinal])=@RequestedCount;

    SELECT a.*,
      CAST(N''[''+COALESCE((SELECT STRING_AGG(N''"''+LOWER(CONVERT(nvarchar(36),q.[RequestedTagId]))+N''"'',N'','')
          WITHIN GROUP (ORDER BY q.[RequestOrdinal],CONVERT(binary(16),q.[RequestedTagId]))
          FROM (SELECT DISTINCT x.[RequestOrdinal],x.[RequestedTagId] FROM #Matches x
                WHERE x.[ContentSummaryVersionId]=a.[ContentSummaryVersionId]) q),N'''')+N'']'' AS nvarchar(max))
        AS [MatchedRequestedTagIdsJson],
      CAST(N''[''+COALESCE((SELECT STRING_AGG(N''"''+LOWER(CONVERT(nvarchar(36),q.[MatchedTagId]))+N''"'',N'','')
          WITHIN GROUP (ORDER BY q.[MatchedTagIdBinary])
          FROM (SELECT DISTINCT x.[MatchedTagId],CONVERT(binary(16),x.[MatchedTagId]) AS [MatchedTagIdBinary]
                FROM #Matches x WHERE x.[ContentSummaryVersionId]=a.[ContentSummaryVersionId]) q),N'''')+N'']'' AS nvarchar(max))
        AS [MatchedResolvedTagIdsJson]
    INTO #Eligible
    FROM #Aggregated a
    WHERE @FreshnessMode=''IncludeStale'' OR a.[FreshnessCode]=''current'';

    SELECT e.*,
      ROW_NUMBER() OVER (ORDER BY e.[RequestedMatchCount] DESC,e.[MinimumTraversalDepth] ASC,
        e.[MaximumPathWeight] DESC,e.[RepoRelativePath] COLLATE Latin1_General_100_BIN2 ASC,
        CONVERT(binary(16),e.[ContentSummaryVersionId]) ASC) AS [CandidateRank]
    INTO #Ranked FROM #Eligible e;

    DECLARE @AuthorizedMatchCount bigint=(SELECT COUNT_BIG(*) FROM #Ranked);
    DECLARE @ReturnedCount int=CASE WHEN @AuthorizedMatchCount>@Limit THEN @Limit
                                    ELSE CONVERT(int,@AuthorizedMatchCount) END;
    DECLARE @WatermarkUtc datetime2(7)=(SELECT MAX([RecordedAtUtc]) FROM #Ranked);
    SELECT @AsOfUtc AS [AsOfUtc],@MatchMode AS [MatchMode],@FreshnessMode AS [FreshnessMode],
      @AuthorizedMatchCount AS [AuthorizedMatchCount],@ReturnedCount AS [ReturnedCount],
      CONVERT(bit,CASE WHEN @AuthorizedMatchCount>@Limit THEN 1 ELSE 0 END) AS [Truncated],
      CAST(''content-summary-rank-v1'' AS varchar(64)) AS [RankingContractCode],
      @WatermarkUtc AS [WatermarkUtc];

    SELECT TOP (@Limit)
      r.[ContentSummaryVersionId],r.[ContentSummaryId],r.[SourceArtifactId],
      r.[SourceArtifactVersionId],r.[RepositoryId],r.[RepoRelativePath],
      r.[SafeSummaryText] AS [SafeText],r.[SafeLocator],r.[MatchedRequestedTagIdsJson],
      r.[MatchedResolvedTagIdsJson],r.[FreshnessCode],
      CAST(''content-summary-rank-v1'' AS varchar(64)) AS [RankingContractCode],
      CONVERT(bigint,r.[CandidateRank]) AS [Rank],r.[SourceObservedAtUtc],r.[GeneratedAtUtc],
      r.[RecordedAtUtc],r.[ProducerEntityId],r.[NormalizedContentSha256],
      r.[SummaryContentSha256],r.[DerivationFingerprint]
    FROM #Ranked r ORDER BY r.[CandidateRank];
END;';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

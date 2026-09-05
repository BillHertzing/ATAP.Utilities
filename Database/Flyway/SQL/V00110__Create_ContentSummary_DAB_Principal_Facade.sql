/*
  Sprint 0015 Task 15.60.e: scalar-input, one-result DAB/MCP facade.
  V00100 remains immutable. This forward migration preserves the exact public
  V1 signature and two-result contract while moving its query implementation
  into one shared internal core.
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
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'[ATAPUtilities].[Repository]', N'U') IS NULL
       OR TYPE_ID(N'[ATAPUtilities].[ContentSummaryAuthorizedRepositoryInput]') IS NULL
       OR TYPE_ID(N'[ATAPUtilities].[ContentSummaryTagMatchInput]') IS NULL
       OR TYPE_ID(N'[ATAPUtilities].[TagRelationRoleCodeInput]') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[QueryTagLogicalEdgesAsOf]', N'P') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[QueryContentSummaryCandidatesAsOfV1]', N'P') IS NULL
        THROW 60300, 'V00110 requires the successful V00010-V00100 predecessor chain.', 1;

    IF OBJECT_ID(N'[ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[PopulateContentSummaryCandidateResultV1]', N'P') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[QueryContentSummaryCandidatesForMcpV1]', N'P') IS NOT NULL
       OR DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryMcpReader') IS NOT NULL
        THROW 60301, 'V00110 object or role collision detected.', 1;

    CREATE TABLE [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization]
    (
        [AuthorizationId] uniqueidentifier NOT NULL,
        [DatabasePrincipalName] sysname COLLATE Latin1_General_100_BIN2 NOT NULL,
        [DatabasePrincipalSid] varbinary(85) NOT NULL,
        [InstanceCode] varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [RepositoryId] uniqueidentifier NOT NULL,
        [ValidFromUtc] datetime2(7) NOT NULL,
        [ValidToUtc] datetime2(7) NULL,
        [SourceReference] nvarchar(512) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        CONSTRAINT [PK_ContentSummaryDatabasePrincipalRepositoryAuthorization]
            PRIMARY KEY ([AuthorizationId]),
        CONSTRAINT [FK_ContentSummaryDatabasePrincipalRepositoryAuthorization_Repository]
            FOREIGN KEY ([RepositoryId]) REFERENCES [ATAPUtilities].[Repository] ([RepositoryId])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [CK_ContentSummaryDatabasePrincipalRepositoryAuthorization_Name]
            CHECK (DATALENGTH([DatabasePrincipalName])>0),
        CONSTRAINT [CK_ContentSummaryDatabasePrincipalRepositoryAuthorization_Sid]
            CHECK (DATALENGTH([DatabasePrincipalSid]) BETWEEN 1 AND 85),
        CONSTRAINT [CK_ContentSummaryDatabasePrincipalRepositoryAuthorization_Instance]
            CHECK ([InstanceCode] IN ('production','qa','integration','dev','exp')),
        CONSTRAINT [CK_ContentSummaryDatabasePrincipalRepositoryAuthorization_Period]
            CHECK ([ValidToUtc] IS NULL OR [ValidFromUtc]<[ValidToUtc]),
        CONSTRAINT [CK_ContentSummaryDatabasePrincipalRepositoryAuthorization_RecordTime]
            CHECK ([ValidFromUtc]<=[RecordedAtUtc]),
        CONSTRAINT [CK_ContentSummaryDatabasePrincipalRepositoryAuthorization_Source]
            CHECK (DATALENGTH([SourceReference])>0)
    );

    CREATE UNIQUE INDEX [UX_ContentSummaryDatabasePrincipalRepositoryAuthorization_Active]
        ON [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization]
           ([DatabasePrincipalName], [DatabasePrincipalSid], [InstanceCode], [RepositoryId])
        WHERE [ValidToUtc] IS NULL;

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[PopulateContentSummaryCandidateResultV1]
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
    IF OBJECT_ID(N''tempdb..#ContentSummaryMetadata'',N''U'') IS NULL
       OR OBJECT_ID(N''tempdb..#ContentSummaryItems'',N''U'') IS NULL
      THROW 60302, ''CS-INTERNAL-001: canonical result tables are missing.'', 1;
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
    INSERT INTO #ContentSummaryMetadata
      ([AsOfUtc],[MatchMode],[FreshnessMode],[AuthorizedMatchCount],[ReturnedCount],
       [Truncated],[RankingContractCode],[WatermarkUtc])
    VALUES (@AsOfUtc,@MatchMode,@FreshnessMode,@AuthorizedMatchCount,@ReturnedCount,
      CONVERT(bit,CASE WHEN @AuthorizedMatchCount>@Limit THEN 1 ELSE 0 END),
      ''content-summary-rank-v1'',@WatermarkUtc);

    INSERT INTO #ContentSummaryItems
      ([ContentSummaryVersionId],[ContentSummaryId],[SourceArtifactId],[SourceArtifactVersionId],
       [RepositoryId],[RepoRelativePath],[SafeText],[SafeLocator],[MatchedRequestedTagIdsJson],
       [MatchedResolvedTagIdsJson],[FreshnessCode],[RankingContractCode],[Rank],
       [SourceObservedAtUtc],[GeneratedAtUtc],[RecordedAtUtc],[ProducerEntityId],
       [NormalizedContentSha256],[SummaryContentSha256],[DerivationFingerprint])
    SELECT TOP (@Limit)
      r.[ContentSummaryVersionId],r.[ContentSummaryId],r.[SourceArtifactId],
      r.[SourceArtifactVersionId],r.[RepositoryId],r.[RepoRelativePath],
      r.[SafeSummaryText],r.[SafeLocator],r.[MatchedRequestedTagIdsJson],
      r.[MatchedResolvedTagIdsJson],r.[FreshnessCode],''content-summary-rank-v1'',
      CONVERT(bigint,r.[CandidateRank]),r.[SourceObservedAtUtc],r.[GeneratedAtUtc],
      r.[RecordedAtUtc],r.[ProducerEntityId],r.[NormalizedContentSha256],
      r.[SummaryContentSha256],r.[DerivationFingerprint]
    FROM #Ranked r ORDER BY r.[CandidateRank];
END;';

    EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [ATAPUtilities].[QueryContentSummaryCandidatesAsOfV1]
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
    CREATE TABLE #ContentSummaryMetadata
    (
      [AsOfUtc] datetime2(7) NOT NULL,[MatchMode] varchar(3) NOT NULL,
      [FreshnessMode] varchar(16) NOT NULL,[AuthorizedMatchCount] bigint NOT NULL,
      [ReturnedCount] int NOT NULL,[Truncated] bit NOT NULL,
      [RankingContractCode] varchar(64) NOT NULL,[WatermarkUtc] datetime2(7) NULL
    );
    CREATE TABLE #ContentSummaryItems
    (
      [ContentSummaryVersionId] uniqueidentifier NOT NULL,[ContentSummaryId] uniqueidentifier NOT NULL,
      [SourceArtifactId] uniqueidentifier NOT NULL,[SourceArtifactVersionId] uniqueidentifier NOT NULL,
      [RepositoryId] uniqueidentifier NOT NULL,[RepoRelativePath] nvarchar(1024) NOT NULL,
      [SafeText] nvarchar(max) NULL,[SafeLocator] nvarchar(2048) NULL,
      [MatchedRequestedTagIdsJson] nvarchar(max) NOT NULL,
      [MatchedResolvedTagIdsJson] nvarchar(max) NOT NULL,[FreshnessCode] varchar(16) NOT NULL,
      [RankingContractCode] varchar(64) NOT NULL,[Rank] bigint NOT NULL,
      [SourceObservedAtUtc] datetime2(7) NOT NULL,[GeneratedAtUtc] datetime2(7) NOT NULL,
      [RecordedAtUtc] datetime2(7) NOT NULL,[ProducerEntityId] uniqueidentifier NOT NULL,
      [NormalizedContentSha256] binary(32) NOT NULL,[SummaryContentSha256] binary(32) NOT NULL,
      [DerivationFingerprint] binary(32) NOT NULL
    );
    EXEC [ATAPUtilities].[PopulateContentSummaryCandidateResultV1]
      @AuthorizedRepositories=@AuthorizedRepositories,@TagMatches=@TagMatches,
      @MatchMode=@MatchMode,@AsOfUtc=@AsOfUtc,@FreshnessMode=@FreshnessMode,@Limit=@Limit;
    SELECT [AsOfUtc],[MatchMode],[FreshnessMode],[AuthorizedMatchCount],[ReturnedCount],
      [Truncated],[RankingContractCode],[WatermarkUtc]
    FROM #ContentSummaryMetadata;
    SELECT [ContentSummaryVersionId],[ContentSummaryId],[SourceArtifactId],
      [SourceArtifactVersionId],[RepositoryId],[RepoRelativePath],[SafeText],[SafeLocator],
      [MatchedRequestedTagIdsJson],[MatchedResolvedTagIdsJson],[FreshnessCode],
      [RankingContractCode],[Rank],[SourceObservedAtUtc],[GeneratedAtUtc],[RecordedAtUtc],
      [ProducerEntityId],[NormalizedContentSha256],[SummaryContentSha256],[DerivationFingerprint]
    FROM #ContentSummaryItems ORDER BY [Rank];
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[QueryContentSummaryCandidatesForMcpV1]
    @Tags nvarchar(4000),
    @Depth int=3,
    @Width int=2,
    @Instance nvarchar(64)=N''production''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @CorrelationId uniqueidentifier=NEWID();
    DECLARE @AsOfUtc datetime2(7)=SYSUTCDATETIME();
    DECLARE @MatchMode varchar(3)=''Any'';
    DECLARE @FreshnessMode varchar(16)=''CurrentOnly'';
    DECLARE @InstanceValue nvarchar(64)=LTRIM(RTRIM(@Instance));
    DECLARE @AuthorizedRepositoryCount int=0;

    BEGIN TRY
      IF ISJSON(@Tags,ARRAY)<>1 OR DATALENGTH(@Tags)>8000
        THROW 60310, ''CS-REQ-001: Tags must be a bounded JSON array.'', 1;
      IF @Depth NOT BETWEEN 1 AND 100 OR @Width NOT BETWEEN 1 AND 100
        THROW 60311, ''CS-REQ-001: Depth and Width must be between 1 and 100.'', 1;
      IF @InstanceValue COLLATE Latin1_General_100_BIN2 NOT IN
           (N''production'',N''qa'',N''integration'',N''dev'',N''exp'')
        THROW 60312, ''CS-REQ-001: Instance is not a canonical tier code.'', 1;

      DECLARE @RequestedTags table
      (
        [RequestOrdinal] tinyint NOT NULL PRIMARY KEY,
        [TagText] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL
      );
      INSERT INTO @RequestedTags ([RequestOrdinal],[TagText])
      SELECT TRY_CONVERT(tinyint,[key]),CONVERT(nvarchar(4000),[value])
      FROM OPENJSON(@Tags) WHERE [type]=1;
      IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Tags)) NOT BETWEEN 1 AND 12
         OR (SELECT COUNT_BIG(*) FROM @RequestedTags)<>(SELECT COUNT_BIG(*) FROM OPENJSON(@Tags))
         OR (SELECT COUNT_BIG(DISTINCT [TagText]) FROM @RequestedTags)<>(SELECT COUNT_BIG(*) FROM @RequestedTags)
         OR EXISTS
           (SELECT 1 FROM @RequestedTags
            WHERE NULLIF([TagText],N'''') IS NULL
               OR LEN([TagText])>128
               OR [TagText] COLLATE Latin1_General_100_BIN2 LIKE N''%[^-A-Za-z0-9_.:]%'' COLLATE Latin1_General_100_BIN2
               OR DATALENGTH(CONVERT(varchar(max),[TagText] COLLATE Latin1_General_100_BIN2_UTF8))>256)
        THROW 60313, ''CS-REQ-001: Tags must contain 1 to 12 unique bounded identifiers.'', 1;

      SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
      BEGIN TRANSACTION;
      DECLARE @DatabasePrincipalName sysname=USER_NAME();
      DECLARE @DatabasePrincipalSid varbinary(85)=
        (SELECT [sid] FROM sys.database_principals
         WHERE [principal_id]=DATABASE_PRINCIPAL_ID(@DatabasePrincipalName));
      DECLARE @AuthorizedRepositories [ATAPUtilities].[ContentSummaryAuthorizedRepositoryInput];
      INSERT INTO @AuthorizedRepositories ([RepositoryId])
      SELECT DISTINCT authorizationRow.[RepositoryId]
      FROM [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization] authorizationRow
      JOIN [ATAPUtilities].[Repository] repositoryRow
        ON repositoryRow.[RepositoryId]=authorizationRow.[RepositoryId]
      WHERE authorizationRow.[DatabasePrincipalName]=@DatabasePrincipalName COLLATE Latin1_General_100_BIN2
        AND authorizationRow.[DatabasePrincipalSid]=@DatabasePrincipalSid
        AND authorizationRow.[InstanceCode]=@InstanceValue COLLATE Latin1_General_100_BIN2
        AND authorizationRow.[ValidFromUtc]<=@AsOfUtc
        AND (authorizationRow.[ValidToUtc] IS NULL OR @AsOfUtc<authorizationRow.[ValidToUtc])
        AND repositoryRow.[CreatedAtUtc]<=@AsOfUtc
        AND (repositoryRow.[RetiredAtUtc] IS NULL OR @AsOfUtc<repositoryRow.[RetiredAtUtc]);
      SET @AuthorizedRepositoryCount=@@ROWCOUNT;
      IF @AuthorizedRepositoryCount=0
      BEGIN
        COMMIT TRANSACTION;
        SELECT @CorrelationId AS [CorrelationId],CAST(''Denied'' AS varchar(16)) AS [StatusCode],
          CAST(''CS-AUTH-002'' AS varchar(32)) AS [ErrorCode],@AsOfUtc AS [AsOfUtc],
          @InstanceValue AS [Instance],@Depth AS [Depth],@Width AS [Width],
          @MatchMode AS [MatchMode],@FreshnessMode AS [FreshnessMode],
          CONVERT(int,0) AS [AuthorizedRepositoryCount],CONVERT(bigint,0) AS [AuthorizedMatchCount],
          CONVERT(int,0) AS [ReturnedCount],CONVERT(bit,0) AS [Truncated],
          CAST(''content-summary-rank-v1'' AS varchar(64)) AS [RankingContractCode],
          CAST(NULL AS datetime2(7)) AS [WatermarkUtc],CAST(N''[]'' AS nvarchar(max)) AS [ItemsJson];
        RETURN;
      END;

      DECLARE @TagMatches [ATAPUtilities].[ContentSummaryTagMatchInput];
      DECLARE @RoleCodes [ATAPUtilities].[TagRelationRoleCodeInput];
      DECLARE @ResolvedTags table ([ResolvedTagId] uniqueidentifier NOT NULL PRIMARY KEY);
      DECLARE @Frontier table
      (
        [FrontierOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY,[TagId] uniqueidentifier NOT NULL,
        [PathWeight] decimal(19,12) NOT NULL,[VisitedPath] nvarchar(max) NOT NULL
      );
      DECLARE @NextFrontier table
      (
        [NextOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY,[TagId] uniqueidentifier NOT NULL,
        [PathWeight] decimal(19,12) NOT NULL,[VisitedPath] nvarchar(max) NOT NULL
      );
      DECLARE @Edges table
      (
        [EdgeOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [TagRelationId] uniqueidentifier NOT NULL,[SourceTagId] uniqueidentifier NOT NULL,
        [TargetTagId] uniqueidentifier NOT NULL,[RoleCode] nvarchar(64) NOT NULL,
        [Projection] nvarchar(16) NOT NULL,[Weight] decimal(5,4) NOT NULL,
        [NamespaceCode] nvarchar(128) NOT NULL,[TargetTagCode] nvarchar(128) NOT NULL,
        [TagStateId] uniqueidentifier NOT NULL,[Label] nvarchar(256) NOT NULL,
        [Description] nvarchar(2048) NULL,[IsDeprecated] bit NOT NULL
      );
      DECLARE @TraversalOrdinal int=0;
      DECLARE @RequestOrdinal tinyint;
      DECLARE @TagText nvarchar(128);
      DECLARE requested_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT [RequestOrdinal],[TagText] FROM @RequestedTags ORDER BY [RequestOrdinal];
      OPEN requested_cursor;
      FETCH NEXT FROM requested_cursor INTO @RequestOrdinal,@TagText;
      WHILE @@FETCH_STATUS=0
      BEGIN
        DELETE FROM @ResolvedTags;
        DELETE FROM @Frontier;
        DELETE FROM @NextFrontier;
        INSERT INTO @ResolvedTags ([ResolvedTagId])
        SELECT DISTINCT resolved.[ResolvedTagId]
        FROM
        (
          SELECT tagRow.[TagId] FROM [ATAPUtilities].[Tag] tagRow WHERE tagRow.[TagCode]=@TagText
          UNION
          SELECT aliasRow.[TagId] FROM [ATAPUtilities].[TagAlias] aliasRow
          WHERE aliasRow.[AliasCode]=@TagText
            AND aliasRow.[ValidFromUtc]<=@AsOfUtc
            AND (aliasRow.[ValidToUtc] IS NULL OR @AsOfUtc<aliasRow.[ValidToUtc])
        ) candidate
        CROSS APPLY [ATAPUtilities].[ResolveTagAsOf](candidate.[TagId],@AsOfUtc) resolved
        WHERE resolved.[ResolutionStatusCode]=''Resolved'';
        IF (SELECT COUNT_BIG(*) FROM @ResolvedTags)<>1
          THROW 60314, ''CS-QUERY-001: a requested Tag must resolve exactly once.'', 1;

        DECLARE @RequestedTagId uniqueidentifier=(SELECT MIN([ResolvedTagId]) FROM @ResolvedTags);
        IF @RequestedTagId IS NOT NULL
        BEGIN
          INSERT INTO @TagMatches
            ([RequestOrdinal],[RequestedTagId],[MatchedTagId],[Depth],[TraversalOrdinal],[PathWeight])
          VALUES (@RequestOrdinal,@RequestedTagId,@RequestedTagId,0,@TraversalOrdinal,1.000000000000);
          SET @TraversalOrdinal+=1;
          INSERT INTO @Frontier ([TagId],[PathWeight],[VisitedPath])
          VALUES (@RequestedTagId,1.000000000000,
                  N''|''+LOWER(CONVERT(nvarchar(36),@RequestedTagId))+N''|'');
          DECLARE @CurrentDepth int=1;
          WHILE @CurrentDepth<=@Depth AND EXISTS (SELECT 1 FROM @Frontier)
          BEGIN
            DELETE FROM @NextFrontier;
            DECLARE @FrontierTagId uniqueidentifier;
            DECLARE @FrontierWeight decimal(19,12);
            DECLARE @VisitedPath nvarchar(max);
            DECLARE frontier_cursor CURSOR LOCAL FAST_FORWARD FOR
              SELECT [TagId],[PathWeight],[VisitedPath] FROM @Frontier ORDER BY [FrontierOrdinal];
            OPEN frontier_cursor;
            FETCH NEXT FROM frontier_cursor INTO @FrontierTagId,@FrontierWeight,@VisitedPath;
            WHILE @@FETCH_STATUS=0
            BEGIN
              DELETE FROM @Edges;
              INSERT INTO @Edges
                ([TagRelationId],[SourceTagId],[TargetTagId],[RoleCode],[Projection],[Weight],
                 [NamespaceCode],[TargetTagCode],[TagStateId],[Label],[Description],[IsDeprecated])
              EXEC [ATAPUtilities].[QueryTagLogicalEdgesAsOf]
                @SourceTagId=@FrontierTagId,@AsOfUtc=@AsOfUtc,@RoleCodes=@RoleCodes;
              DECLARE @EdgeTargetTagId uniqueidentifier;
              DECLARE @EdgeWeight decimal(5,4);
              DECLARE edge_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT TOP (@Width) [TargetTagId],[Weight] FROM @Edges
                ORDER BY [EdgeOrdinal];
              OPEN edge_cursor;
              FETCH NEXT FROM edge_cursor INTO @EdgeTargetTagId,@EdgeWeight;
              WHILE @@FETCH_STATUS=0
              BEGIN
                IF CHARINDEX(N''|''+LOWER(CONVERT(nvarchar(36),@EdgeTargetTagId))+N''|'',@VisitedPath)=0
                BEGIN
                  DECLARE @NextWeight decimal(19,12)=CONVERT(decimal(19,12),@FrontierWeight*@EdgeWeight);
                  IF @NextWeight<=0 THROW 60315, ''CS-QUERY-002: traversal weight underflowed.'', 1;
                  IF (SELECT COUNT_BIG(*) FROM @TagMatches)>=10000
                    THROW 60316, ''CS-QUERY-002: traversal exceeded the bounded row budget.'', 1;
                  INSERT INTO @NextFrontier ([TagId],[PathWeight],[VisitedPath])
                  VALUES (@EdgeTargetTagId,@NextWeight,
                          @VisitedPath+LOWER(CONVERT(nvarchar(36),@EdgeTargetTagId))+N''|'');
                  INSERT INTO @TagMatches
                    ([RequestOrdinal],[RequestedTagId],[MatchedTagId],[Depth],[TraversalOrdinal],[PathWeight])
                  VALUES (@RequestOrdinal,@RequestedTagId,@EdgeTargetTagId,
                          CONVERT(tinyint,@CurrentDepth),@TraversalOrdinal,@NextWeight);
                  SET @TraversalOrdinal+=1;
                END;
                FETCH NEXT FROM edge_cursor INTO @EdgeTargetTagId,@EdgeWeight;
              END;
              CLOSE edge_cursor;
              DEALLOCATE edge_cursor;
              FETCH NEXT FROM frontier_cursor INTO @FrontierTagId,@FrontierWeight,@VisitedPath;
            END;
            CLOSE frontier_cursor;
            DEALLOCATE frontier_cursor;
            DELETE FROM @Frontier;
            INSERT INTO @Frontier ([TagId],[PathWeight],[VisitedPath])
              SELECT [TagId],[PathWeight],[VisitedPath] FROM @NextFrontier ORDER BY [NextOrdinal];
            SET @CurrentDepth+=1;
          END;
        END;
        FETCH NEXT FROM requested_cursor INTO @RequestOrdinal,@TagText;
      END;
      CLOSE requested_cursor;
      DEALLOCATE requested_cursor;

      CREATE TABLE #ContentSummaryMetadata
      (
        [AsOfUtc] datetime2(7) NOT NULL,[MatchMode] varchar(3) NOT NULL,
        [FreshnessMode] varchar(16) NOT NULL,[AuthorizedMatchCount] bigint NOT NULL,
        [ReturnedCount] int NOT NULL,[Truncated] bit NOT NULL,
        [RankingContractCode] varchar(64) NOT NULL,[WatermarkUtc] datetime2(7) NULL
      );
      CREATE TABLE #ContentSummaryItems
      (
        [ContentSummaryVersionId] uniqueidentifier NOT NULL,[ContentSummaryId] uniqueidentifier NOT NULL,
        [SourceArtifactId] uniqueidentifier NOT NULL,[SourceArtifactVersionId] uniqueidentifier NOT NULL,
        [RepositoryId] uniqueidentifier NOT NULL,[RepoRelativePath] nvarchar(1024) NOT NULL,
        [SafeText] nvarchar(max) NULL,[SafeLocator] nvarchar(2048) NULL,
        [MatchedRequestedTagIdsJson] nvarchar(max) NOT NULL,
        [MatchedResolvedTagIdsJson] nvarchar(max) NOT NULL,[FreshnessCode] varchar(16) NOT NULL,
        [RankingContractCode] varchar(64) NOT NULL,[Rank] bigint NOT NULL,
        [SourceObservedAtUtc] datetime2(7) NOT NULL,[GeneratedAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,[ProducerEntityId] uniqueidentifier NOT NULL,
        [NormalizedContentSha256] binary(32) NOT NULL,[SummaryContentSha256] binary(32) NOT NULL,
        [DerivationFingerprint] binary(32) NOT NULL
      );
      EXEC [ATAPUtilities].[PopulateContentSummaryCandidateResultV1]
        @AuthorizedRepositories=@AuthorizedRepositories,@TagMatches=@TagMatches,
        @MatchMode=@MatchMode,@AsOfUtc=@AsOfUtc,@FreshnessMode=@FreshnessMode,@Limit=@Width;
      IF (SELECT COUNT_BIG(*) FROM #ContentSummaryMetadata)<>1
        THROW 60317, ''CS-INTERNAL-001: canonical query returned an invalid envelope count.'', 1;

      COMMIT TRANSACTION;
      SELECT @CorrelationId AS [CorrelationId],CAST(''Success'' AS varchar(16)) AS [StatusCode],
        CAST(NULL AS varchar(32)) AS [ErrorCode],metadataRow.[AsOfUtc],
        @InstanceValue AS [Instance],@Depth AS [Depth],@Width AS [Width],
        metadataRow.[MatchMode],metadataRow.[FreshnessMode],
        @AuthorizedRepositoryCount AS [AuthorizedRepositoryCount],
        metadataRow.[AuthorizedMatchCount],metadataRow.[ReturnedCount],metadataRow.[Truncated],
        metadataRow.[RankingContractCode],metadataRow.[WatermarkUtc],
        COALESCE(CAST((SELECT [ContentSummaryVersionId],[ContentSummaryId],[SourceArtifactId],
          [SourceArtifactVersionId],[RepositoryId],[RepoRelativePath],[SafeText],[SafeLocator],
          [MatchedRequestedTagIdsJson],[MatchedResolvedTagIdsJson],[FreshnessCode],
          [RankingContractCode],[Rank],[SourceObservedAtUtc],[GeneratedAtUtc],[RecordedAtUtc],
          [ProducerEntityId],[NormalizedContentSha256],[SummaryContentSha256],[DerivationFingerprint]
        FROM #ContentSummaryItems ORDER BY [Rank] FOR JSON PATH) AS nvarchar(max)),
        CAST(N''[]'' AS nvarchar(max))) AS [ItemsJson]
      FROM #ContentSummaryMetadata metadataRow;
    END TRY
    BEGIN CATCH
      IF CURSOR_STATUS(''local'',''edge_cursor'')>=-1
      BEGIN
        IF CURSOR_STATUS(''local'',''edge_cursor'')>-1 CLOSE edge_cursor;
        DEALLOCATE edge_cursor;
      END;
      IF CURSOR_STATUS(''local'',''frontier_cursor'')>=-1
      BEGIN
        IF CURSOR_STATUS(''local'',''frontier_cursor'')>-1 CLOSE frontier_cursor;
        DEALLOCATE frontier_cursor;
      END;
      IF CURSOR_STATUS(''local'',''requested_cursor'')>=-1
      BEGIN
        IF CURSOR_STATUS(''local'',''requested_cursor'')>-1 CLOSE requested_cursor;
        DEALLOCATE requested_cursor;
      END;
      IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
      DECLARE @SafeErrorCode varchar(32)=CASE
        WHEN ERROR_NUMBER() BETWEEN 60310 AND 60313 THEN ''CS-REQ-001''
        WHEN ERROR_NUMBER()=60314 THEN ''CS-QUERY-001''
        WHEN ERROR_NUMBER() IN (59033,59034,60200,60315,60316) THEN ''CS-QUERY-002''
        ELSE ''CS-INTERNAL-001'' END;
      SELECT @CorrelationId AS [CorrelationId],CAST(''Error'' AS varchar(16)) AS [StatusCode],
        @SafeErrorCode AS [ErrorCode],@AsOfUtc AS [AsOfUtc],
        COALESCE(@InstanceValue,N'''') AS [Instance],@Depth AS [Depth],@Width AS [Width],
        @MatchMode AS [MatchMode],@FreshnessMode AS [FreshnessMode],
        CONVERT(int,0) AS [AuthorizedRepositoryCount],CONVERT(bigint,0) AS [AuthorizedMatchCount],
        CONVERT(int,0) AS [ReturnedCount],CONVERT(bit,0) AS [Truncated],
        CAST(''content-summary-rank-v1'' AS varchar(64)) AS [RankingContractCode],
        CAST(NULL AS datetime2(7)) AS [WatermarkUtc],CAST(N''[]'' AS nvarchar(max)) AS [ItemsJson];
    END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE ROLE [ATAPContentSummaryMcpReader] AUTHORIZATION [dbo];';
    GRANT CONNECT TO [ATAPContentSummaryMcpReader];
    GRANT EXECUTE ON OBJECT::[ATAPUtilities].[QueryContentSummaryCandidatesForMcpV1]
        TO [ATAPContentSummaryMcpReader];
    DENY SELECT, INSERT, UPDATE, DELETE, ALTER, REFERENCES, VIEW DEFINITION
        ON SCHEMA::[ATAPUtilities] TO [ATAPContentSummaryMcpReader];
    DENY CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, ALTER ANY SCHEMA
        TO [ATAPContentSummaryMcpReader];

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

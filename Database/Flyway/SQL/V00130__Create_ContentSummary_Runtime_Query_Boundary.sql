/*
  Least-privilege ContentSummary runtime query boundary (Task 15.60.e).

  The migration creates database objects and permissions that are identical in
  every environment. Deployment owns creation of the environment-specific
  database user and membership in ATAPContentSummaryRuntimeQuery.
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

    IF OBJECT_ID(N'[ATAPUtilities].[Tag]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[TagAlias]', N'U') IS NULL
       OR (OBJECT_ID(N'[ATAPUtilities].[ResolveTagAsOf]', N'IF') IS NULL
           AND OBJECT_ID(N'[ATAPUtilities].[ResolveTagAsOf]', N'TF') IS NULL)
       OR TYPE_ID(N'[ATAPUtilities].[TagRelationRoleCodeInput]') IS NULL
       OR TYPE_ID(N'[ATAPUtilities].[ContentSummaryAuthorizedRepositoryInput]') IS NULL
       OR TYPE_ID(N'[ATAPUtilities].[ContentSummaryTagMatchInput]') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[QueryTagLogicalEdgesAsOf]', N'P') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[QueryContentSummaryCandidatesAsOfV1]', N'P') IS NULL
        THROW 60400, N'V00130 requires the successful V00010-V00120 predecessor chain.', 1;

    IF OBJECT_ID(N'[ATAPUtilities].[ResolveContentSummaryTagCodeAsOfV1]', N'P') IS NOT NULL
       OR DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryRuntimeQuery') IS NOT NULL
        THROW 60401, N'V00130 object or role collision detected.', 1;

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[ResolveContentSummaryTagCodeAsOfV1]
    @CodeOrAlias nvarchar(128),
    @AsOfUtc datetime2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @CodeOrAlias IS NULL OR @AsOfUtc IS NULL OR DATALENGTH(@CodeOrAlias)=0
       OR DATALENGTH(@CodeOrAlias)>256 OR @CodeOrAlias<>LTRIM(RTRIM(@CodeOrAlias))
       OR UNICODE(LEFT(@CodeOrAlias,1)) IN (9,10,11,12,13,32,133,160,5760,8192,8193,8194,
                                        8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,
                                        8239,8287,12288)
       OR UNICODE(RIGHT(@CodeOrAlias,1)) IN (9,10,11,12,13,32,133,160,5760,8192,8193,8194,
                                         8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,
                                         8239,8287,12288)
        THROW 60410, ''CodeOrAlias and AsOfUtc are required, and CodeOrAlias must be an exact non-padded value of at most 128 characters.'', 1;

    CREATE TABLE #ResolvedTag
    (
        [ResolvedTagId] uniqueidentifier NOT NULL PRIMARY KEY
    );

    INSERT INTO #ResolvedTag ([ResolvedTagId])
    SELECT DISTINCT resolved.[ResolvedTagId]
    FROM
    (
        SELECT tagRow.[TagId]
        FROM [ATAPUtilities].[Tag] AS tagRow
        WHERE tagRow.[TagCode]=@CodeOrAlias

        UNION

        SELECT aliasRow.[TagId]
        FROM [ATAPUtilities].[TagAlias] AS aliasRow
        WHERE aliasRow.[AliasCode]=@CodeOrAlias
          AND aliasRow.[ValidFromUtc]<=@AsOfUtc
          AND (aliasRow.[ValidToUtc] IS NULL OR @AsOfUtc<aliasRow.[ValidToUtc])
    ) AS candidate
    CROSS APPLY [ATAPUtilities].[ResolveTagAsOf](candidate.[TagId],@AsOfUtc) AS resolved
    WHERE resolved.[ResolutionStatusCode]=''Resolved''
      AND resolved.[ResolvedTagId] IS NOT NULL;

    IF (SELECT COUNT(*) FROM #ResolvedTag)>1
        THROW 60412, ''CodeOrAlias resolves ambiguously to more than one active Tag as of AsOfUtc.'', 1;

    SELECT [ResolvedTagId]
    FROM #ResolvedTag;
END;';

    EXEC sys.sp_executesql
        N'CREATE ROLE [ATAPContentSummaryRuntimeQuery] AUTHORIZATION [dbo];';

    GRANT CONNECT TO [ATAPContentSummaryRuntimeQuery];
    GRANT EXECUTE ON OBJECT::[ATAPUtilities].[ResolveContentSummaryTagCodeAsOfV1]
        TO [ATAPContentSummaryRuntimeQuery];
    GRANT EXECUTE ON OBJECT::[ATAPUtilities].[QueryTagLogicalEdgesAsOf]
        TO [ATAPContentSummaryRuntimeQuery];
    GRANT EXECUTE ON OBJECT::[ATAPUtilities].[QueryContentSummaryCandidatesAsOfV1]
        TO [ATAPContentSummaryRuntimeQuery];
    GRANT EXECUTE ON TYPE::[ATAPUtilities].[TagRelationRoleCodeInput]
        TO [ATAPContentSummaryRuntimeQuery];
    GRANT REFERENCES ON TYPE::[ATAPUtilities].[TagRelationRoleCodeInput]
        TO [ATAPContentSummaryRuntimeQuery];
    GRANT EXECUTE ON TYPE::[ATAPUtilities].[ContentSummaryAuthorizedRepositoryInput]
        TO [ATAPContentSummaryRuntimeQuery];
    GRANT REFERENCES ON TYPE::[ATAPUtilities].[ContentSummaryAuthorizedRepositoryInput]
        TO [ATAPContentSummaryRuntimeQuery];
    GRANT EXECUTE ON TYPE::[ATAPUtilities].[ContentSummaryTagMatchInput]
        TO [ATAPContentSummaryRuntimeQuery];
    GRANT REFERENCES ON TYPE::[ATAPUtilities].[ContentSummaryTagMatchInput]
        TO [ATAPContentSummaryRuntimeQuery];

    DENY SELECT, INSERT, UPDATE, DELETE, ALTER, VIEW DEFINITION
        ON SCHEMA::[ATAPUtilities] TO [ATAPContentSummaryRuntimeQuery];
    DENY CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, ALTER ANY SCHEMA
        TO [ATAPContentSummaryRuntimeQuery];

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

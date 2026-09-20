/*
  Add the provider-reported cache-token data point to Ace AI-supervisor usage.

  Request/response/cache parsing remains an application concern. This migration
  makes the database contract forward-compatible while preserving existing callers:
  @CacheTokens defaults to NULL and usage availability continues to describe only
  the request/response token pair.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'[Ace].[AISupervisorUsage]', N'U') IS NULL
       OR OBJECT_ID(N'[Ace].[CaptureAISupervisorAttempt]', N'P') IS NULL
       OR OBJECT_ID(N'[Ace].[QueryAISupervisorExchangeTimeline]', N'P') IS NULL
       OR OBJECT_ID(N'[Ace].[QueryAISupervisorTokenTimeline]', N'P') IS NULL
       OR OBJECT_ID(N'[Ace].[AISupervisorAttempt]', N'U') IS NULL
        THROW 60600, N'V00150 requires the successful V00010-V00140 predecessor chain.', 1;

    IF COL_LENGTH(N'Ace.AISupervisorUsage', N'CacheTokens') IS NOT NULL
        THROW 60601, N'Ace.AISupervisorUsage.CacheTokens already exists.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.check_constraints
        WHERE [parent_object_id] = OBJECT_ID(N'[Ace].[AISupervisorUsage]', N'U')
          AND [name] = N'CK_Ace_AISupervisorUsage_Counts'
    )
        THROW 60602, N'The expected AISupervisorUsage count constraint is missing.', 1;

    ALTER TABLE [Ace].[AISupervisorUsage]
        DROP CONSTRAINT [CK_Ace_AISupervisorUsage_Counts];

    ALTER TABLE [Ace].[AISupervisorUsage]
        ADD [CacheTokens] bigint NULL;

    ALTER TABLE [Ace].[AISupervisorUsage]
        ADD CONSTRAINT [CK_Ace_AISupervisorUsage_Counts]
            CHECK (([RequestTokens] IS NULL OR [RequestTokens] >= 0)
               AND ([ResponseTokens] IS NULL OR [ResponseTokens] >= 0)
               AND ([CacheTokens] IS NULL OR [CacheTokens] >= 0));

    DECLARE @CaptureDefinition nvarchar(max) =
        OBJECT_DEFINITION(OBJECT_ID(N'[Ace].[CaptureAISupervisorAttempt]', N'P'));
    DECLARE @CaptureParameterAnchor nvarchar(4000) =
        N'    @Metrics [Ace].[AISupervisorMetricInput] READONLY' + NCHAR(13) + NCHAR(10) + N'AS';
    DECLARE @CaptureValidationAnchor nvarchar(4000) =
        N'       OR (@ResponseTokens IS NOT NULL AND @ResponseTokens < 0)';
    DECLARE @CaptureColumnsAnchor nvarchar(4000) =
        N'            ([AttemptId], [RequestTokens], [ResponseTokens], [AvailabilityCode],';
    DECLARE @CaptureValuesAnchor nvarchar(4000) =
        N'            (@AttemptId, @RequestTokens, @ResponseTokens, @AvailabilityCode,';

    IF @CaptureDefinition IS NULL
       OR (LEN(@CaptureDefinition) - LEN(REPLACE(@CaptureDefinition, @CaptureParameterAnchor, N''))) / LEN(@CaptureParameterAnchor) <> 1
       OR (LEN(@CaptureDefinition) - LEN(REPLACE(@CaptureDefinition, @CaptureValidationAnchor, N''))) / LEN(@CaptureValidationAnchor) <> 1
       OR (LEN(@CaptureDefinition) - LEN(REPLACE(@CaptureDefinition, @CaptureColumnsAnchor, N''))) / LEN(@CaptureColumnsAnchor) <> 1
       OR (LEN(@CaptureDefinition) - LEN(REPLACE(@CaptureDefinition, @CaptureValuesAnchor, N''))) / LEN(@CaptureValuesAnchor) <> 1
       OR @CaptureDefinition LIKE N'%@CacheTokens%'
        THROW 60603, N'CaptureAISupervisorAttempt does not match the V00070 contract.', 1;

    SET @CaptureDefinition = REPLACE(
        @CaptureDefinition,
        N'CREATE PROCEDURE [Ace].[CaptureAISupervisorAttempt]',
        N'ALTER PROCEDURE [Ace].[CaptureAISupervisorAttempt]');
    SET @CaptureDefinition = REPLACE(
        @CaptureDefinition,
        @CaptureParameterAnchor,
        N'    @Metrics [Ace].[AISupervisorMetricInput] READONLY,' + NCHAR(13) + NCHAR(10)
        + N'    @CacheTokens bigint = NULL' + NCHAR(13) + NCHAR(10) + N'AS');
    SET @CaptureDefinition = REPLACE(
        @CaptureDefinition,
        @CaptureValidationAnchor,
        @CaptureValidationAnchor + NCHAR(13) + NCHAR(10) + N'       OR (@CacheTokens IS NOT NULL AND @CacheTokens < 0)');
    SET @CaptureDefinition = REPLACE(
        @CaptureDefinition,
        @CaptureColumnsAnchor,
        N'            ([AttemptId], [RequestTokens], [ResponseTokens], [CacheTokens], [AvailabilityCode],');
    SET @CaptureDefinition = REPLACE(
        @CaptureDefinition,
        @CaptureValuesAnchor,
        N'            (@AttemptId, @RequestTokens, @ResponseTokens, @CacheTokens, @AvailabilityCode,');
    EXEC sys.sp_executesql @CaptureDefinition;

    DECLARE @ExchangeTimelineDefinition nvarchar(max) =
        OBJECT_DEFINITION(OBJECT_ID(N'[Ace].[QueryAISupervisorExchangeTimeline]', N'P'));
    DECLARE @ExchangeTimelineAnchor nvarchar(4000) =
        N'           usage.[ResponseTokens], usage.[AvailabilityCode], usage.[AvailabilityReason],';

    IF @ExchangeTimelineDefinition IS NULL
       OR (LEN(@ExchangeTimelineDefinition) - LEN(REPLACE(@ExchangeTimelineDefinition, @ExchangeTimelineAnchor, N''))) / LEN(@ExchangeTimelineAnchor) <> 1
       OR @ExchangeTimelineDefinition LIKE N'%usage.[CacheTokens]%'
        THROW 60604, N'QueryAISupervisorExchangeTimeline does not match the V00070 contract.', 1;

    SET @ExchangeTimelineDefinition = REPLACE(
        @ExchangeTimelineDefinition,
        N'CREATE PROCEDURE [Ace].[QueryAISupervisorExchangeTimeline]',
        N'ALTER PROCEDURE [Ace].[QueryAISupervisorExchangeTimeline]');
    SET @ExchangeTimelineDefinition = REPLACE(
        @ExchangeTimelineDefinition,
        @ExchangeTimelineAnchor,
        N'           usage.[ResponseTokens], usage.[CacheTokens], usage.[AvailabilityCode], usage.[AvailabilityReason],');
    EXEC sys.sp_executesql @ExchangeTimelineDefinition;

    DECLARE @TokenTimelineDefinition nvarchar(max) =
        OBJECT_DEFINITION(OBJECT_ID(N'[Ace].[QueryAISupervisorTokenTimeline]', N'P'));
    DECLARE @TokenBucketAnchor nvarchar(4000) =
        N'               usage.[RequestTokens], usage.[ResponseTokens], usage.[AvailabilityCode]';
    DECLARE @TokenSumAnchor nvarchar(4000) =
        N'           SUM([RequestTokens]) AS [RequestTokens], SUM([ResponseTokens]) AS [ResponseTokens],';

    IF @TokenTimelineDefinition IS NULL
       OR (LEN(@TokenTimelineDefinition) - LEN(REPLACE(@TokenTimelineDefinition, @TokenBucketAnchor, N''))) / LEN(@TokenBucketAnchor) <> 1
       OR (LEN(@TokenTimelineDefinition) - LEN(REPLACE(@TokenTimelineDefinition, @TokenSumAnchor, N''))) / LEN(@TokenSumAnchor) <> 1
       OR @TokenTimelineDefinition LIKE N'%[CacheTokens]%'
        THROW 60605, N'QueryAISupervisorTokenTimeline does not match the V00070 contract.', 1;

    SET @TokenTimelineDefinition = REPLACE(
        @TokenTimelineDefinition,
        N'CREATE PROCEDURE [Ace].[QueryAISupervisorTokenTimeline]',
        N'ALTER PROCEDURE [Ace].[QueryAISupervisorTokenTimeline]');
    SET @TokenTimelineDefinition = REPLACE(
        @TokenTimelineDefinition,
        @TokenBucketAnchor,
        N'               usage.[RequestTokens], usage.[ResponseTokens], usage.[CacheTokens], usage.[AvailabilityCode]');
    SET @TokenTimelineDefinition = REPLACE(
        @TokenTimelineDefinition,
        @TokenSumAnchor,
        N'           SUM([RequestTokens]) AS [RequestTokens], SUM([ResponseTokens]) AS [ResponseTokens], SUM([CacheTokens]) AS [CacheTokens],');
    EXEC sys.sp_executesql @TokenTimelineDefinition;

    IF COL_LENGTH(N'Ace.AISupervisorUsage', N'CacheTokens') IS NULL
       OR OBJECT_DEFINITION(OBJECT_ID(N'[Ace].[CaptureAISupervisorAttempt]', N'P')) NOT LIKE N'%@CacheTokens bigint = NULL%'
       OR OBJECT_DEFINITION(OBJECT_ID(N'[Ace].[CaptureAISupervisorAttempt]', N'P')) NOT LIKE N'%@AttemptId, @RequestTokens, @ResponseTokens, @CacheTokens, @AvailabilityCode%'
       OR OBJECT_DEFINITION(OBJECT_ID(N'[Ace].[QueryAISupervisorExchangeTimeline]', N'P')) NOT LIKE N'%usage.[ResponseTokens], usage.[CacheTokens], usage.[AvailabilityCode]%'
       OR OBJECT_DEFINITION(OBJECT_ID(N'[Ace].[QueryAISupervisorTokenTimeline]', N'P')) NOT LIKE N'%SUM([CacheTokens]) AS [CacheTokens]%'
        THROW 60606, N'V00150 postcondition verification failed.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

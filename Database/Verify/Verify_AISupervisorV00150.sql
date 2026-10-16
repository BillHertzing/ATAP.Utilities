/* Run only on an authorized local developer ATAPUtilities database.
   All capture fixtures are rolled back; no persistent telemetry is added. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME()<>N'ATAPUtilities' OR CONVERT(nvarchar(128),SERVERPROPERTY('InstanceName')) NOT IN(N'Devwhertzing',N'Expwhertzing')
    THROW 60630, N'Verification is restricted to developer ATAPUtilities targets.', 1;
IF (SELECT COUNT(*) FROM dbo.flyway_schema_history WHERE success=1)<>14
   OR EXISTS(SELECT 1 FROM dbo.flyway_schema_history WHERE success=0)
   OR NOT EXISTS(SELECT 1 FROM dbo.flyway_schema_history WHERE TRY_CONVERT(int,version)=150 AND success=1)
   OR COL_LENGTH(N'Ace.AISupervisorUsage',N'CacheTokens')<>8
   OR COLUMNPROPERTY(OBJECT_ID(N'Ace.AISupervisorUsage'),N'CacheTokens','AllowsNull')<>1
    THROW 60631, N'Complete V00150 schema/history required.', 1;
IF CHARINDEX(N'usage.[CacheTokens]',OBJECT_DEFINITION(OBJECT_ID(N'Ace.QueryAISupervisorExchangeTimeline'))) = 0
   OR CHARINDEX(N'SUM([CacheTokens]) AS [CacheTokens]',OBJECT_DEFINITION(OBJECT_ID(N'Ace.QueryAISupervisorTokenTimeline'))) = 0
    THROW 60632, N'CacheTokens timeline contracts missing.', 1;
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'Ace.AISupervisorUsage')
              AND name=N'CK_Ace_AISupervisorUsage_Counts' AND is_disabled=0 AND is_not_trusted=0
              AND CHARINDEX(N'[CacheTokens]',definition)>0)
    THROW 60636,N'Enabled and trusted CacheTokens constraint missing.',1;

DECLARE @i int=0;
WHILE @i<4
BEGIN
    DECLARE @cache bigint=CASE @i WHEN 0 THEN NULL WHEN 1 THEN 0 WHEN 2 THEN 17 ELSE -1 END;
    DECLARE @call nvarchar(max)=N'
DECLARE @exchange uniqueidentifier=NEWID(), @key uniqueidentifier=NEWID(), @attempt uniqueidentifier=NEWID();
DECLARE @now datetime2(7)=SYSUTCDATETIME();
DECLARE @hash binary(32)=HASHBYTES(''SHA2_256'',CONVERT(varbinary(16),@exchange));
DECLARE @tags Ace.AISupervisorTagInput, @metrics Ace.AISupervisorMetricInput;
EXEC Ace.CaptureAISupervisorAttempt
 @ExchangeId=@exchange,@IdempotencyKey=@key,@CanonicalEnvelopeHash=@hash,
 @Harness=N''V00150RecoveryVerification'',@Provider=N''Fixture'',
 @CorrelationId=N''Task16.59'',@EndpointClassification=N''SyntheticVerification'',@ConsentVersion=N''FixtureOnly'',
 @ExchangeStartedAtUtc=@now,@ExchangeRecordedAtUtc=@now,
 @AttemptId=@attempt,@AttemptOrdinal=0,@CanonicalAttemptHash=@hash,@OutcomeCode=N''Completed'',
 @AttemptStartedAtUtc=@now,@AttemptCompletedAtUtc=@now,
 @RequestTokens=10,@ResponseTokens=20,@AvailabilityCode=N''Complete'',@UsageProviderReported=1,
 @Tags=@tags,@Metrics=@metrics' + CASE WHEN @i=0 THEN N'' ELSE N',@CacheTokens=@value' END + N';
IF NOT EXISTS(SELECT 1 FROM Ace.AISupervisorUsage WHERE AttemptId=@attempt
 AND RequestTokens=10 AND ResponseTokens=20 AND AvailabilityCode=N''Complete''
 AND ((@value IS NULL AND CacheTokens IS NULL) OR CacheTokens=@value))
 THROW 60633,N''Capture usage round-trip failed.'',1;
';
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC sys.sp_executesql @call,N'@value bigint',@value=@cache;
        IF @i=3 THROW 60635,N'Negative cache count was accepted by capture.',1;
        IF XACT_STATE()<>0 ROLLBACK;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        IF NOT (@i=3 AND ERROR_NUMBER()=57008) THROW;
    END CATCH;
    SET @i+=1;
END;

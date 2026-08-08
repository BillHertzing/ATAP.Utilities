-- Loads the one exact approved RPRRSBSI V3 RuleSet from RuleSet.csv.
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'ATAPUtilities.Philote', N'U') IS NULL
    THROW 53800, 'V3 RuleSet loader aborted: ATAPUtilities.Philote does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.RuleSet', N'U') IS NULL
    THROW 53801, 'V3 RuleSet loader aborted: ATAPUtilities.RuleSet does not exist.', 1;

DECLARE @ExpectedHeader nvarchar(128) = N'RuleSetId,PhiloteId,RuleSetCode';
DECLARE @SourceFile nvarchar(max);

SELECT @SourceFile = SourceFile.BulkColumn
FROM OPENROWSET(
    BULK '${data_dir}\RuleSet.csv',
    SINGLE_CLOB,
    CODEPAGE = '65001'
) AS SourceFile;

IF LEFT(@SourceFile, 1) = NCHAR(65279)
    SET @SourceFile = SUBSTRING(@SourceFile, 2, LEN(@SourceFile));

DECLARE @FirstLineEnd int = CHARINDEX(CHAR(10), @SourceFile);
DECLARE @ActualHeader nvarchar(128) = CASE
    WHEN @FirstLineEnd = 0 THEN @SourceFile
    ELSE LEFT(@SourceFile, @FirstLineEnd - 1)
END;

IF RIGHT(@ActualHeader, 1) = CHAR(13)
    SET @ActualHeader = LEFT(@ActualHeader, LEN(@ActualHeader) - 1);

IF @ActualHeader <> @ExpectedHeader
    THROW 53802, 'V3 RuleSet loader aborted: RuleSet.csv header is not exact.', 1;

CREATE TABLE #RuleSetSeed (
    RuleSetId nvarchar(50) NULL,
    PhiloteId nvarchar(50) NULL,
    RuleSetCode nvarchar(256) NULL
);

BULK INSERT #RuleSetSeed
FROM '${data_dir}\RuleSet.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    TABLOCK
);

IF (SELECT COUNT_BIG(*) FROM #RuleSetSeed) <> 1
    THROW 53803, 'V3 RuleSet loader aborted: RuleSet.csv must contain exactly one data row.', 1;

IF EXISTS (
    SELECT 1
    FROM #RuleSetSeed AS source
    WHERE TRY_CONVERT(uniqueidentifier, source.RuleSetId) IS NULL
       OR TRY_CONVERT(uniqueidentifier, source.PhiloteId) IS NULL
       OR source.RuleSetId <> LOWER(CONVERT(nvarchar(36), TRY_CONVERT(uniqueidentifier, source.RuleSetId)))
       OR source.PhiloteId <> LOWER(CONVERT(nvarchar(36), TRY_CONVERT(uniqueidentifier, source.PhiloteId)))
       OR source.RuleSetId <> source.PhiloteId
       OR COALESCE(source.RuleSetCode, N'') = N''
)
    THROW 53804, 'V3 RuleSet loader aborted: source identifiers or required values are invalid.', 1;

DECLARE @ApprovedRuleSetId uniqueidentifier = '23ad4f37-2c70-4f34-9104-9868ec0f3823';
DECLARE @ApprovedRuleSetCode varchar(128) = 'HelloWorld';

IF EXISTS (
    SELECT 1
    FROM #RuleSetSeed AS source
    WHERE TRY_CONVERT(uniqueidentifier, source.RuleSetId) <> @ApprovedRuleSetId
       OR TRY_CONVERT(uniqueidentifier, source.PhiloteId) <> @ApprovedRuleSetId
       OR CONVERT(varbinary(256), CONVERT(varchar(128), source.RuleSetCode))
            <> CONVERT(varbinary(256), @ApprovedRuleSetCode)
)
    THROW 53805, 'V3 RuleSet loader aborted: RuleSet.csv differs from the exact approved registry row.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM ATAPUtilities.Philote AS philote
    WHERE philote.PhiloteId = @ApprovedRuleSetId
      AND philote.AdditionalIdsStub IS NULL
)
    THROW 53806, 'V3 RuleSet loader aborted: the exact null-stub Philote parent is missing.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ExistingRuleSetCount bigint = (SELECT COUNT_BIG(*) FROM ATAPUtilities.RuleSet);

    IF @ExistingRuleSetCount NOT IN (0, 1)
        THROW 53807, 'V3 RuleSet loader aborted: target state is neither empty nor the exact approved row.', 1;

    IF @ExistingRuleSetCount = 1
       AND NOT EXISTS (
            SELECT 1
            FROM ATAPUtilities.RuleSet AS target
            WHERE target.RuleSetId = @ApprovedRuleSetId
              AND target.PhiloteId = @ApprovedRuleSetId
              AND CONVERT(varbinary(256), target.RuleSetCode) = CONVERT(varbinary(256), @ApprovedRuleSetCode)
       )
        THROW 53808, 'V3 RuleSet loader aborted: existing target row differs from the exact approved row.', 1;

    IF @ExistingRuleSetCount = 0
    BEGIN
        INSERT INTO ATAPUtilities.RuleSet (RuleSetId, PhiloteId, RuleSetCode)
        VALUES (@ApprovedRuleSetId, @ApprovedRuleSetId, @ApprovedRuleSetCode);
    END;

    IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.RuleSet) <> 1
       OR NOT EXISTS (
            SELECT 1
            FROM ATAPUtilities.RuleSet AS target
            WHERE target.RuleSetId = @ApprovedRuleSetId
              AND target.PhiloteId = @ApprovedRuleSetId
              AND CONVERT(varbinary(256), target.RuleSetCode) = CONVERT(varbinary(256), @ApprovedRuleSetCode)
       )
        THROW 53809, 'V3 RuleSet loader aborted: target postcondition is not the exact approved row.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

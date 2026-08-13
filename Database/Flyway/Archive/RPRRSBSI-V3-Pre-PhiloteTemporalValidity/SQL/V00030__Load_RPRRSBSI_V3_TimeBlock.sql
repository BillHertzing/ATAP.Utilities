-- Validates the approved header-only TimeBlock.csv and its zero-row seed state.
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'ATAPUtilities.Philote', N'U') IS NULL
    THROW 53300, 'V3 TimeBlock loader aborted: ATAPUtilities.Philote does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.TimeBlock', N'U') IS NULL
    THROW 53301, 'V3 TimeBlock loader aborted: ATAPUtilities.TimeBlock does not exist.', 1;

DECLARE @ExpectedHeader nvarchar(256) = N'TimeBlockId,PhiloteId,Ordinal,StartUtc,DurationTicks,EndUtc';
DECLARE @SourceFile nvarchar(max);

SELECT @SourceFile = SourceFile.BulkColumn
FROM OPENROWSET(
    BULK '${data_dir}\TimeBlock.csv',
    SINGLE_CLOB,
    CODEPAGE = '65001'
) AS SourceFile;

IF LEFT(@SourceFile, 1) = NCHAR(65279)
    SET @SourceFile = SUBSTRING(@SourceFile, 2, LEN(@SourceFile));

SET @SourceFile = REPLACE(@SourceFile, CHAR(13) + CHAR(10), CHAR(10));

IF HASHBYTES('SHA2_256', CONVERT(varbinary(max), @SourceFile))
       <> 0x1512417fc92624700c5d82c16ddc76f7e2b5d720ac79974352757a0fc69e1c64
    THROW 53302, 'V3 TimeBlock loader aborted: TimeBlock.csv content is not the exact approved source.', 1;

IF @SourceFile NOT IN (@ExpectedHeader, @ExpectedHeader + CHAR(10))
    THROW 53302, 'V3 TimeBlock loader aborted: TimeBlock.csv must contain only its exact header and zero data rows.', 1;

CREATE TABLE #TimeBlockSeed (
    TimeBlockId nvarchar(50) NULL,
    PhiloteId nvarchar(50) NULL,
    Ordinal nvarchar(50) NULL,
    StartUtc nvarchar(50) NULL,
    DurationTicks nvarchar(50) NULL,
    EndUtc nvarchar(50) NULL
);

IF EXISTS (SELECT 1 FROM #TimeBlockSeed)
    THROW 53303, 'V3 TimeBlock loader aborted: TimeBlock.csv must contain zero data rows.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.Philote) <> 22
       OR EXISTS (
            SELECT 1
            FROM ATAPUtilities.Philote
            WHERE AdditionalIdsStub IS NOT NULL
       )
        THROW 53304, 'V3 TimeBlock loader aborted: the exact 22-row null-stub Philote parent seed is required.', 1;

    IF EXISTS (SELECT 1 FROM ATAPUtilities.TimeBlock)
        THROW 53305, 'V3 TimeBlock loader aborted: the initial TimeBlock collection must be empty for every Philote.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

-- Loads the one exact approved RPRRSBSI V3 BuildSet from BuildSet.csv.
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'ATAPUtilities.Philote', N'U') IS NULL
    THROW 54000, 'V3 BuildSet loader aborted: ATAPUtilities.Philote does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.BuildSet', N'U') IS NULL
    THROW 54001, 'V3 BuildSet loader aborted: ATAPUtilities.BuildSet does not exist.', 1;

DECLARE @ExpectedHeader nvarchar(128) = N'BuildSetId,PhiloteId,BuildSetCode';
DECLARE @SourceFile nvarchar(max);

SELECT @SourceFile = SourceFile.BulkColumn
FROM OPENROWSET(
    BULK '${data_dir}\BuildSet.csv',
    SINGLE_CLOB,
    CODEPAGE = '65001'
) AS SourceFile;

IF LEFT(@SourceFile, 1) = NCHAR(65279)
    SET @SourceFile = SUBSTRING(@SourceFile, 2, LEN(@SourceFile));

SET @SourceFile = REPLACE(@SourceFile, CHAR(13) + CHAR(10), CHAR(10));

IF HASHBYTES('SHA2_256', CONVERT(varbinary(max), @SourceFile))
       <> 0xb3199b7c606161f862bb250e75ae389517ff839698fbc9b4df128b1ed19cb037
    THROW 54002, 'V3 BuildSet loader aborted: BuildSet.csv content is not the exact approved source.', 1;

DECLARE @FirstLineEnd int = CHARINDEX(CHAR(10), @SourceFile);
DECLARE @ActualHeader nvarchar(128) = CASE
    WHEN @FirstLineEnd = 0 THEN @SourceFile
    ELSE LEFT(@SourceFile, @FirstLineEnd - 1)
END;

IF RIGHT(@ActualHeader, 1) = CHAR(13)
    SET @ActualHeader = LEFT(@ActualHeader, LEN(@ActualHeader) - 1);

IF @ActualHeader <> @ExpectedHeader
    THROW 54002, 'V3 BuildSet loader aborted: BuildSet.csv header is not exact.', 1;

CREATE TABLE #BuildSetSeed (
    BuildSetId nvarchar(50) NULL,
    PhiloteId nvarchar(50) NULL,
    BuildSetCode nvarchar(128) NULL
);

INSERT INTO #BuildSetSeed (BuildSetId, PhiloteId, BuildSetCode)
VALUES (
    N'550e7722-cb57-4e47-a94b-9212b451d6fb',
    N'550e7722-cb57-4e47-a94b-9212b451d6fb',
    N'HelloWorld'
);

IF (SELECT COUNT_BIG(*) FROM #BuildSetSeed) <> 1
    THROW 54003, 'V3 BuildSet loader aborted: BuildSet.csv must contain exactly one data row.', 1;

IF EXISTS (
    SELECT 1
    FROM #BuildSetSeed AS source
    CROSS APPLY (VALUES (source.BuildSetId), (source.PhiloteId)) AS identifier(Value)
    WHERE identifier.Value IS NULL
       OR TRY_CONVERT(uniqueidentifier, identifier.Value) IS NULL
       OR identifier.Value <> LOWER(CONVERT(nvarchar(36), TRY_CONVERT(uniqueidentifier, identifier.Value)))
)
    THROW 54004, 'V3 BuildSet loader aborted: every identifier must be a canonical lowercase GUID.', 1;

DECLARE @ApprovedBuildSet TABLE (
    BuildSetId uniqueidentifier NOT NULL PRIMARY KEY,
    PhiloteId uniqueidentifier NOT NULL UNIQUE,
    BuildSetCode varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL UNIQUE
);

INSERT INTO @ApprovedBuildSet (BuildSetId, PhiloteId, BuildSetCode)
VALUES (
    '550e7722-cb57-4e47-a94b-9212b451d6fb',
    '550e7722-cb57-4e47-a94b-9212b451d6fb',
    'HelloWorld'
);

IF EXISTS (
    SELECT
        TRY_CONVERT(uniqueidentifier, source.BuildSetId),
        TRY_CONVERT(uniqueidentifier, source.PhiloteId),
        CONVERT(varchar(128), source.BuildSetCode) COLLATE Latin1_General_100_BIN2
    FROM #BuildSetSeed AS source
    EXCEPT
    SELECT approved.BuildSetId, approved.PhiloteId, approved.BuildSetCode
    FROM @ApprovedBuildSet AS approved
) OR EXISTS (
    SELECT approved.BuildSetId, approved.PhiloteId, approved.BuildSetCode
    FROM @ApprovedBuildSet AS approved
    EXCEPT
    SELECT
        TRY_CONVERT(uniqueidentifier, source.BuildSetId),
        TRY_CONVERT(uniqueidentifier, source.PhiloteId),
        CONVERT(varchar(128), source.BuildSetCode) COLLATE Latin1_General_100_BIN2
    FROM #BuildSetSeed AS source
)
    THROW 54005, 'V3 BuildSet loader aborted: BuildSet.csv differs from the exact approved registry-backed BuildSet.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM ATAPUtilities.Philote AS parent
    WHERE parent.PhiloteId = '550e7722-cb57-4e47-a94b-9212b451d6fb'
      AND parent.AdditionalIdsStub IS NULL
)
    THROW 54006, 'V3 BuildSet loader aborted: the exact null-stub BuildSet Philote parent is missing.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ExistingBuildSetCount bigint = (
        SELECT COUNT_BIG(*)
        FROM ATAPUtilities.BuildSet
    );

    IF @ExistingBuildSetCount NOT IN (0, 1)
        THROW 54007, 'V3 BuildSet loader aborted: target state is neither empty nor the exact approved one-row seed.', 1;

    IF @ExistingBuildSetCount = 1
       AND (
            EXISTS (
                SELECT
                    target.BuildSetId,
                    target.PhiloteId,
                    target.BuildSetCode COLLATE Latin1_General_100_BIN2
                FROM ATAPUtilities.BuildSet AS target
                EXCEPT
                SELECT approved.BuildSetId, approved.PhiloteId, approved.BuildSetCode
                FROM @ApprovedBuildSet AS approved
            )
            OR EXISTS (
                SELECT approved.BuildSetId, approved.PhiloteId, approved.BuildSetCode
                FROM @ApprovedBuildSet AS approved
                EXCEPT
                SELECT
                    target.BuildSetId,
                    target.PhiloteId,
                    target.BuildSetCode COLLATE Latin1_General_100_BIN2
                FROM ATAPUtilities.BuildSet AS target
            )
       )
        THROW 54008, 'V3 BuildSet loader aborted: existing target row differs from the exact approved seed.', 1;

    IF @ExistingBuildSetCount = 0
    BEGIN
        INSERT INTO ATAPUtilities.BuildSet (BuildSetId, PhiloteId, BuildSetCode)
        SELECT approved.BuildSetId, approved.PhiloteId, approved.BuildSetCode
        FROM @ApprovedBuildSet AS approved;
    END;

    IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.BuildSet) <> 1
       OR EXISTS (
            SELECT 1
            FROM ATAPUtilities.BuildSet AS target
            WHERE target.BuildSetId <> target.PhiloteId
       )
        THROW 54009, 'V3 BuildSet loader aborted: target postcondition is not exactly one Philote-mirrored BuildSet.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

-- Loads the one exact approved RPRRSBSI V3 Instantiation from Instantiation.csv.
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'ATAPUtilities.Philote', N'U') IS NULL
    THROW 54200, 'V3 Instantiation loader aborted: ATAPUtilities.Philote does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.BuildSet', N'U') IS NULL
    THROW 54201, 'V3 Instantiation loader aborted: ATAPUtilities.BuildSet does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.Instantiation', N'U') IS NULL
    THROW 54202, 'V3 Instantiation loader aborted: ATAPUtilities.Instantiation does not exist.', 1;

DECLARE @ExpectedHeader nvarchar(256) =
    N'InstantiationId,PhiloteId,BuildSetId,InstantiationCode';
DECLARE @SourceFile nvarchar(max);

SELECT @SourceFile = SourceFile.BulkColumn
FROM OPENROWSET(
    BULK '${data_dir}\Instantiation.csv',
    SINGLE_CLOB,
    CODEPAGE = '65001'
) AS SourceFile;

IF LEFT(@SourceFile, 1) = NCHAR(65279)
    SET @SourceFile = SUBSTRING(@SourceFile, 2, LEN(@SourceFile));

DECLARE @FirstLineEnd int = CHARINDEX(CHAR(10), @SourceFile);
DECLARE @ActualHeader nvarchar(256) = CASE
    WHEN @FirstLineEnd = 0 THEN @SourceFile
    ELSE LEFT(@SourceFile, @FirstLineEnd - 1)
END;

IF RIGHT(@ActualHeader, 1) = CHAR(13)
    SET @ActualHeader = LEFT(@ActualHeader, LEN(@ActualHeader) - 1);

IF @ActualHeader <> @ExpectedHeader
    THROW 54203, 'V3 Instantiation loader aborted: Instantiation.csv header is not exact.', 1;

CREATE TABLE #InstantiationSeed (
    InstantiationId nvarchar(50) NULL,
    PhiloteId nvarchar(50) NULL,
    BuildSetId nvarchar(50) NULL,
    InstantiationCode nvarchar(128) NULL
);

BULK INSERT #InstantiationSeed
FROM '${data_dir}\Instantiation.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    TABLOCK
);

IF (SELECT COUNT_BIG(*) FROM #InstantiationSeed) <> 1
    THROW 54204, 'V3 Instantiation loader aborted: Instantiation.csv must contain exactly one data row.', 1;

IF EXISTS (
    SELECT 1
    FROM #InstantiationSeed AS source
    CROSS APPLY (VALUES
        (source.InstantiationId),
        (source.PhiloteId),
        (source.BuildSetId)
    ) AS identifier(Value)
    WHERE identifier.Value IS NULL
       OR TRY_CONVERT(uniqueidentifier, identifier.Value) IS NULL
       OR identifier.Value <> LOWER(CONVERT(nvarchar(36), TRY_CONVERT(uniqueidentifier, identifier.Value)))
)
    THROW 54205, 'V3 Instantiation loader aborted: every identifier must be a canonical lowercase non-null GUID.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM #InstantiationSeed AS source
    WHERE TRY_CONVERT(uniqueidentifier, source.InstantiationId) =
            '03e28494-998f-4fc2-ba5d-ad6e5832c8b7'
      AND TRY_CONVERT(uniqueidentifier, source.PhiloteId) =
            '03e28494-998f-4fc2-ba5d-ad6e5832c8b7'
      AND TRY_CONVERT(uniqueidentifier, source.BuildSetId) =
            '550e7722-cb57-4e47-a94b-9212b451d6fb'
      AND CONVERT(varchar(128), source.InstantiationCode) COLLATE Latin1_General_100_BIN2 =
            'HelloWorld' COLLATE Latin1_General_100_BIN2
)
    THROW 54206, 'V3 Instantiation loader aborted: Instantiation.csv differs from the exact approved registry-backed relationship.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM ATAPUtilities.Philote AS philote
    WHERE philote.PhiloteId = '03e28494-998f-4fc2-ba5d-ad6e5832c8b7'
      AND philote.AdditionalIdsStub IS NULL
)
    THROW 54207, 'V3 Instantiation loader aborted: the exact null-stub Instantiation Philote parent is missing.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM ATAPUtilities.BuildSet AS buildSet
    WHERE buildSet.BuildSetId = '550e7722-cb57-4e47-a94b-9212b451d6fb'
      AND buildSet.PhiloteId = '550e7722-cb57-4e47-a94b-9212b451d6fb'
      AND buildSet.BuildSetCode COLLATE Latin1_General_100_BIN2 =
            'HelloWorld' COLLATE Latin1_General_100_BIN2
)
    THROW 54208, 'V3 Instantiation loader aborted: the exact Philote-mirrored HelloWorld BuildSet parent is missing or drifted.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ExistingInstantiationCount bigint = (
        SELECT COUNT_BIG(*)
        FROM ATAPUtilities.Instantiation
    );

    IF @ExistingInstantiationCount NOT IN (0, 1)
        THROW 54209, 'V3 Instantiation loader aborted: target state is neither empty nor the exact approved one-row seed.', 1;

    IF @ExistingInstantiationCount = 1
       AND NOT EXISTS (
            SELECT 1
            FROM ATAPUtilities.Instantiation AS target
            WHERE target.InstantiationId = '03e28494-998f-4fc2-ba5d-ad6e5832c8b7'
              AND target.PhiloteId = '03e28494-998f-4fc2-ba5d-ad6e5832c8b7'
              AND target.BuildSetId = '550e7722-cb57-4e47-a94b-9212b451d6fb'
              AND target.InstantiationCode COLLATE Latin1_General_100_BIN2 =
                    'HelloWorld' COLLATE Latin1_General_100_BIN2
       )
        THROW 54210, 'V3 Instantiation loader aborted: existing target Instantiation differs from the exact approved seed.', 1;

    IF @ExistingInstantiationCount = 0
    BEGIN
        INSERT INTO ATAPUtilities.Instantiation (
            InstantiationId,
            PhiloteId,
            BuildSetId,
            InstantiationCode
        )
        VALUES (
            '03e28494-998f-4fc2-ba5d-ad6e5832c8b7',
            '03e28494-998f-4fc2-ba5d-ad6e5832c8b7',
            '550e7722-cb57-4e47-a94b-9212b451d6fb',
            'HelloWorld'
        );
    END;

    IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.Instantiation) <> 1
       OR NOT EXISTS (
            SELECT 1
            FROM ATAPUtilities.Instantiation AS target
            WHERE target.InstantiationId = '03e28494-998f-4fc2-ba5d-ad6e5832c8b7'
              AND target.PhiloteId = target.InstantiationId
              AND target.BuildSetId = '550e7722-cb57-4e47-a94b-9212b451d6fb'
              AND target.BuildSetId IS NOT NULL
              AND target.InstantiationCode COLLATE Latin1_General_100_BIN2 =
                    'HelloWorld' COLLATE Latin1_General_100_BIN2
       )
        THROW 54211, 'V3 Instantiation loader aborted: target postcondition is not exactly one non-null direct BuildSet relationship.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

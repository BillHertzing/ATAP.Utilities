-- Loads the exact two approved RPRRSBSI V3 RuleKinds from RuleKind.csv.
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'ATAPUtilities.Philote', N'U') IS NULL
    THROW 53400, 'V3 RuleKind loader aborted: ATAPUtilities.Philote does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.RuleKind', N'U') IS NULL
    THROW 53401, 'V3 RuleKind loader aborted: ATAPUtilities.RuleKind does not exist.', 1;

DECLARE @ExpectedHeader nvarchar(256) = N'RuleKindId,PhiloteId,RuleKindCode,RuleKindName';
DECLARE @SourceFile nvarchar(max);

SELECT @SourceFile = SourceFile.BulkColumn
FROM OPENROWSET(
    BULK '${data_dir}\RuleKind.csv',
    SINGLE_CLOB,
    CODEPAGE = '65001'
) AS SourceFile;

IF LEFT(@SourceFile, 1) = NCHAR(65279)
    SET @SourceFile = SUBSTRING(@SourceFile, 2, LEN(@SourceFile));

SET @SourceFile = REPLACE(@SourceFile, CHAR(13) + CHAR(10), CHAR(10));

IF HASHBYTES('SHA2_256', CONVERT(varbinary(max), @SourceFile))
       <> 0x4acf68df8ae7ab8bee138c153dfcad52461573f7328b04e3e3e0e0bd5154a2b4
    THROW 53402, 'V3 RuleKind loader aborted: RuleKind.csv content is not the exact approved source.', 1;

DECLARE @FirstLineEnd int = CHARINDEX(CHAR(10), @SourceFile);
DECLARE @ActualHeader nvarchar(256) = CASE
    WHEN @FirstLineEnd = 0 THEN @SourceFile
    ELSE LEFT(@SourceFile, @FirstLineEnd - 1)
END;

IF RIGHT(@ActualHeader, 1) = CHAR(13)
    SET @ActualHeader = LEFT(@ActualHeader, LEN(@ActualHeader) - 1);

IF @ActualHeader <> @ExpectedHeader
    THROW 53402, 'V3 RuleKind loader aborted: RuleKind.csv header is not exact.', 1;

CREATE TABLE #RuleKindSeed (
    RuleKindId nvarchar(50) NULL,
    PhiloteId nvarchar(50) NULL,
    RuleKindCode nvarchar(128) NULL,
    RuleKindName nvarchar(256) NULL
);

INSERT INTO #RuleKindSeed (RuleKindId, PhiloteId, RuleKindCode, RuleKindName)
VALUES
    (N'8e06f2af-52cf-47d5-872e-0d3912f4fda0', N'8e06f2af-52cf-47d5-872e-0d3912f4fda0', N'PowerShell', N'PowerShell'),
    (N'b32c60e0-86f3-40e6-893e-d3240ffea882', N'b32c60e0-86f3-40e6-893e-d3240ffea882', N'Path', N'Path');

IF (SELECT COUNT_BIG(*) FROM #RuleKindSeed) <> 2
    THROW 53403, 'V3 RuleKind loader aborted: RuleKind.csv must contain exactly two data rows.', 1;

IF EXISTS (
    SELECT 1
    FROM #RuleKindSeed AS source
    WHERE TRY_CONVERT(uniqueidentifier, source.RuleKindId) IS NULL
       OR TRY_CONVERT(uniqueidentifier, source.PhiloteId) IS NULL
       OR source.RuleKindId <> LOWER(CONVERT(nvarchar(36), TRY_CONVERT(uniqueidentifier, source.RuleKindId)))
       OR source.PhiloteId <> LOWER(CONVERT(nvarchar(36), TRY_CONVERT(uniqueidentifier, source.PhiloteId)))
       OR source.RuleKindId <> source.PhiloteId
       OR COALESCE(source.RuleKindCode, N'') = N''
       OR COALESCE(source.RuleKindName, N'') = N''
)
    THROW 53404, 'V3 RuleKind loader aborted: source identifiers or required values are invalid.', 1;

IF EXISTS (
    SELECT source.RuleKindId FROM #RuleKindSeed AS source GROUP BY source.RuleKindId HAVING COUNT_BIG(*) <> 1
) OR EXISTS (
    SELECT source.PhiloteId FROM #RuleKindSeed AS source GROUP BY source.PhiloteId HAVING COUNT_BIG(*) <> 1
) OR EXISTS (
    SELECT source.RuleKindCode FROM #RuleKindSeed AS source GROUP BY source.RuleKindCode HAVING COUNT_BIG(*) <> 1
) OR EXISTS (
    SELECT source.RuleKindName FROM #RuleKindSeed AS source GROUP BY source.RuleKindName HAVING COUNT_BIG(*) <> 1
)
    THROW 53405, 'V3 RuleKind loader aborted: source identifiers, codes, and names must be unique.', 1;

DECLARE @ApprovedRuleKind TABLE (
    RuleKindId uniqueidentifier NOT NULL PRIMARY KEY,
    PhiloteId uniqueidentifier NOT NULL UNIQUE,
    RuleKindCode varchar(64) NOT NULL UNIQUE,
    RuleKindName nvarchar(128) NOT NULL UNIQUE
);

INSERT INTO @ApprovedRuleKind (RuleKindId, PhiloteId, RuleKindCode, RuleKindName)
VALUES
    ('8e06f2af-52cf-47d5-872e-0d3912f4fda0', '8e06f2af-52cf-47d5-872e-0d3912f4fda0', 'PowerShell', N'PowerShell'),
    ('b32c60e0-86f3-40e6-893e-d3240ffea882', 'b32c60e0-86f3-40e6-893e-d3240ffea882', 'Path', N'Path');

IF EXISTS (
    SELECT
        TRY_CONVERT(uniqueidentifier, source.RuleKindId),
        TRY_CONVERT(uniqueidentifier, source.PhiloteId),
        CONVERT(varbinary(64), CONVERT(varchar(64), source.RuleKindCode)),
        CONVERT(varbinary(256), CONVERT(nvarchar(128), source.RuleKindName))
    FROM #RuleKindSeed AS source
    EXCEPT
    SELECT
        approved.RuleKindId,
        approved.PhiloteId,
        CONVERT(varbinary(64), approved.RuleKindCode),
        CONVERT(varbinary(256), approved.RuleKindName)
    FROM @ApprovedRuleKind AS approved
) OR EXISTS (
    SELECT
        approved.RuleKindId,
        approved.PhiloteId,
        CONVERT(varbinary(64), approved.RuleKindCode),
        CONVERT(varbinary(256), approved.RuleKindName)
    FROM @ApprovedRuleKind AS approved
    EXCEPT
    SELECT
        TRY_CONVERT(uniqueidentifier, source.RuleKindId),
        TRY_CONVERT(uniqueidentifier, source.PhiloteId),
        CONVERT(varbinary(64), CONVERT(varchar(64), source.RuleKindCode)),
        CONVERT(varbinary(256), CONVERT(nvarchar(128), source.RuleKindName))
    FROM #RuleKindSeed AS source
)
    THROW 53406, 'V3 RuleKind loader aborted: RuleKind.csv differs from the approved catalog.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS (
        SELECT approved.PhiloteId
        FROM @ApprovedRuleKind AS approved
        EXCEPT
        SELECT target.PhiloteId
        FROM ATAPUtilities.Philote AS target
    )
        THROW 53407, 'V3 RuleKind loader aborted: an approved Philote parent is missing.', 1;

    DECLARE @ExistingRuleKindCount bigint = (SELECT COUNT_BIG(*) FROM ATAPUtilities.RuleKind);

    IF @ExistingRuleKindCount NOT IN (0, 2)
        THROW 53408, 'V3 RuleKind loader aborted: target state is neither empty nor the exact approved catalog.', 1;

    IF @ExistingRuleKindCount = 2
       AND (
            EXISTS (
                SELECT
                    target.RuleKindId,
                    target.PhiloteId,
                    CONVERT(varbinary(64), target.RuleKindCode),
                    CONVERT(varbinary(256), target.RuleKindName)
                FROM ATAPUtilities.RuleKind AS target
                EXCEPT
                SELECT
                    approved.RuleKindId,
                    approved.PhiloteId,
                    CONVERT(varbinary(64), approved.RuleKindCode),
                    CONVERT(varbinary(256), approved.RuleKindName)
                FROM @ApprovedRuleKind AS approved
            )
            OR EXISTS (
                SELECT
                    approved.RuleKindId,
                    approved.PhiloteId,
                    CONVERT(varbinary(64), approved.RuleKindCode),
                    CONVERT(varbinary(256), approved.RuleKindName)
                FROM @ApprovedRuleKind AS approved
                EXCEPT
                SELECT
                    target.RuleKindId,
                    target.PhiloteId,
                    CONVERT(varbinary(64), target.RuleKindCode),
                    CONVERT(varbinary(256), target.RuleKindName)
                FROM ATAPUtilities.RuleKind AS target
            )
       )
        THROW 53409, 'V3 RuleKind loader aborted: existing target rows differ from the approved catalog.', 1;

    IF @ExistingRuleKindCount = 0
    BEGIN
        INSERT INTO ATAPUtilities.RuleKind (RuleKindId, PhiloteId, RuleKindCode, RuleKindName)
        SELECT approved.RuleKindId, approved.PhiloteId, approved.RuleKindCode, approved.RuleKindName
        FROM @ApprovedRuleKind AS approved;
    END;

    IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.RuleKind) <> 2
       OR EXISTS (
            SELECT
                target.RuleKindId,
                target.PhiloteId,
                CONVERT(varbinary(64), target.RuleKindCode),
                CONVERT(varbinary(256), target.RuleKindName)
            FROM ATAPUtilities.RuleKind AS target
            EXCEPT
            SELECT
                approved.RuleKindId,
                approved.PhiloteId,
                CONVERT(varbinary(64), approved.RuleKindCode),
                CONVERT(varbinary(256), approved.RuleKindName)
            FROM @ApprovedRuleKind AS approved
       )
        THROW 53410, 'V3 RuleKind loader aborted: target postcondition is not the exact approved catalog.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

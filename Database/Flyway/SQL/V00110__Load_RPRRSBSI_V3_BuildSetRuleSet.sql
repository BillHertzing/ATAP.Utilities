-- Loads the one exact approved RPRRSBSI V3 BuildSet-to-RuleSet membership.
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'ATAPUtilities.BuildSet', N'U') IS NULL
    THROW 54100, 'V3 BuildSetRuleSet loader aborted: ATAPUtilities.BuildSet does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.RuleSet', N'U') IS NULL
    THROW 54101, 'V3 BuildSetRuleSet loader aborted: ATAPUtilities.RuleSet does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.BuildSetRuleSet', N'U') IS NULL
    THROW 54102, 'V3 BuildSetRuleSet loader aborted: ATAPUtilities.BuildSetRuleSet does not exist.', 1;

DECLARE @ExpectedHeader nvarchar(128) = N'BuildSetId,RuleSetId,Ordinal';
DECLARE @SourceFile nvarchar(max);

SELECT @SourceFile = SourceFile.BulkColumn
FROM OPENROWSET(
    BULK '${data_dir}\BuildSetRuleSet.csv',
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
    THROW 54103, 'V3 BuildSetRuleSet loader aborted: BuildSetRuleSet.csv header is not exact.', 1;

CREATE TABLE #BuildSetRuleSetSeed (
    BuildSetId nvarchar(50) NULL,
    RuleSetId nvarchar(50) NULL,
    Ordinal nvarchar(20) NULL
);

BULK INSERT #BuildSetRuleSetSeed
FROM '${data_dir}\BuildSetRuleSet.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    TABLOCK
);

IF (SELECT COUNT_BIG(*) FROM #BuildSetRuleSetSeed) <> 1
    THROW 54104, 'V3 BuildSetRuleSet loader aborted: BuildSetRuleSet.csv must contain exactly one data row.', 1;

IF EXISTS (
    SELECT 1
    FROM #BuildSetRuleSetSeed AS source
    CROSS APPLY (VALUES (source.BuildSetId), (source.RuleSetId)) AS identifier(Value)
    WHERE identifier.Value IS NULL
       OR TRY_CONVERT(uniqueidentifier, identifier.Value) IS NULL
       OR identifier.Value <> LOWER(CONVERT(nvarchar(36), TRY_CONVERT(uniqueidentifier, identifier.Value)))
)
    THROW 54105, 'V3 BuildSetRuleSet loader aborted: every identifier must be a canonical lowercase GUID.', 1;

IF EXISTS (
    SELECT source.BuildSetId, source.RuleSetId
    FROM #BuildSetRuleSetSeed AS source
    GROUP BY source.BuildSetId, source.RuleSetId
    HAVING COUNT_BIG(*) <> 1
)
    THROW 54106, 'V3 BuildSetRuleSet loader aborted: BuildSetRuleSet.csv contains a duplicate membership.', 1;

IF EXISTS (
    SELECT source.BuildSetId, source.Ordinal
    FROM #BuildSetRuleSetSeed AS source
    GROUP BY source.BuildSetId, source.Ordinal
    HAVING COUNT_BIG(*) <> 1
)
    THROW 54107, 'V3 BuildSetRuleSet loader aborted: BuildSetRuleSet.csv contains a duplicate ordinal.', 1;

IF EXISTS (
    SELECT 1
    FROM #BuildSetRuleSetSeed AS source
    WHERE source.Ordinal <> N'0'
)
    THROW 54108, 'V3 BuildSetRuleSet loader aborted: the only approved membership ordinal is canonical zero.', 1;

DECLARE @ApprovedMembership TABLE (
    BuildSetId uniqueidentifier NOT NULL,
    RuleSetId uniqueidentifier NOT NULL,
    Ordinal int NOT NULL,
    PRIMARY KEY (BuildSetId, RuleSetId),
    UNIQUE (BuildSetId, Ordinal)
);

INSERT INTO @ApprovedMembership (BuildSetId, RuleSetId, Ordinal)
VALUES (
    '550e7722-cb57-4e47-a94b-9212b451d6fb',
    '23ad4f37-2c70-4f34-9104-9868ec0f3823',
    0
);

IF EXISTS (
    SELECT
        TRY_CONVERT(uniqueidentifier, source.BuildSetId),
        TRY_CONVERT(uniqueidentifier, source.RuleSetId),
        TRY_CONVERT(int, source.Ordinal)
    FROM #BuildSetRuleSetSeed AS source
    EXCEPT
    SELECT approved.BuildSetId, approved.RuleSetId, approved.Ordinal
    FROM @ApprovedMembership AS approved
) OR EXISTS (
    SELECT approved.BuildSetId, approved.RuleSetId, approved.Ordinal
    FROM @ApprovedMembership AS approved
    EXCEPT
    SELECT
        TRY_CONVERT(uniqueidentifier, source.BuildSetId),
        TRY_CONVERT(uniqueidentifier, source.RuleSetId),
        TRY_CONVERT(int, source.Ordinal)
    FROM #BuildSetRuleSetSeed AS source
)
    THROW 54109, 'V3 BuildSetRuleSet loader aborted: BuildSetRuleSet.csv differs from the exact approved membership.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM ATAPUtilities.BuildSet AS parent
    WHERE parent.BuildSetId = '550e7722-cb57-4e47-a94b-9212b451d6fb'
      AND parent.PhiloteId = parent.BuildSetId
      AND parent.BuildSetCode COLLATE Latin1_General_100_BIN2 = 'HelloWorld'
)
    THROW 54110, 'V3 BuildSetRuleSet loader aborted: the exact HelloWorld BuildSet parent is missing or mismatched.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM ATAPUtilities.RuleSet AS parent
    WHERE parent.RuleSetId = '23ad4f37-2c70-4f34-9104-9868ec0f3823'
      AND parent.PhiloteId = parent.RuleSetId
      AND parent.RuleSetCode COLLATE Latin1_General_100_BIN2 = 'HelloWorld'
)
    THROW 54111, 'V3 BuildSetRuleSet loader aborted: the exact HelloWorld RuleSet parent is missing or mismatched.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ExistingMembershipCount bigint = (
        SELECT COUNT_BIG(*)
        FROM ATAPUtilities.BuildSetRuleSet
    );

    IF @ExistingMembershipCount NOT IN (0, 1)
        THROW 54112, 'V3 BuildSetRuleSet loader aborted: target state is neither empty nor the exact approved one-row membership.', 1;

    IF @ExistingMembershipCount = 1
       AND (
            EXISTS (
                SELECT target.BuildSetId, target.RuleSetId, target.Ordinal
                FROM ATAPUtilities.BuildSetRuleSet AS target
                EXCEPT
                SELECT approved.BuildSetId, approved.RuleSetId, approved.Ordinal
                FROM @ApprovedMembership AS approved
            )
            OR EXISTS (
                SELECT approved.BuildSetId, approved.RuleSetId, approved.Ordinal
                FROM @ApprovedMembership AS approved
                EXCEPT
                SELECT target.BuildSetId, target.RuleSetId, target.Ordinal
                FROM ATAPUtilities.BuildSetRuleSet AS target
            )
       )
        THROW 54113, 'V3 BuildSetRuleSet loader aborted: existing target membership differs from the exact approved seed.', 1;

    IF @ExistingMembershipCount = 0
    BEGIN
        INSERT INTO ATAPUtilities.BuildSetRuleSet (BuildSetId, RuleSetId, Ordinal)
        SELECT approved.BuildSetId, approved.RuleSetId, approved.Ordinal
        FROM @ApprovedMembership AS approved;
    END;

    IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.BuildSetRuleSet) <> 1
       OR NOT EXISTS (
            SELECT 1
            FROM ATAPUtilities.BuildSetRuleSet AS target
            WHERE target.BuildSetId = '550e7722-cb57-4e47-a94b-9212b451d6fb'
              AND target.RuleSetId = '23ad4f37-2c70-4f34-9104-9868ec0f3823'
              AND target.Ordinal = 0
       )
        THROW 54114, 'V3 BuildSetRuleSet loader aborted: target postcondition is not the exact ordinal-zero membership.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

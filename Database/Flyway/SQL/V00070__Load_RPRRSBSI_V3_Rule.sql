-- Loads the two exact approved RPRRSBSI V3 Rules from Rule.csv.
-- RuleBody newline policy: normalize CRLF to LF, reject bare CR, and do not trim.
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'ATAPUtilities.Philote', N'U') IS NULL
    THROW 53700, 'V3 Rule loader aborted: ATAPUtilities.Philote does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.RuleKind', N'U') IS NULL
    THROW 53701, 'V3 Rule loader aborted: ATAPUtilities.RuleKind does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.RulePrimitive', N'U') IS NULL
    THROW 53702, 'V3 Rule loader aborted: ATAPUtilities.RulePrimitive does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.RulePrimitiveInput', N'U') IS NULL
    THROW 53703, 'V3 Rule loader aborted: ATAPUtilities.RulePrimitiveInput does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.Rule', N'U') IS NULL
    THROW 53704, 'V3 Rule loader aborted: ATAPUtilities.Rule does not exist.', 1;

DECLARE @ExpectedHeader nvarchar(256) =
    N'RuleId,PhiloteId,RuleKindId,RulePrimitiveId,RuleCode,RuleBody';
DECLARE @SourceFile nvarchar(max);

SELECT @SourceFile = SourceFile.BulkColumn
FROM OPENROWSET(
    BULK '${data_dir}\Rule.csv',
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
    THROW 53705, 'V3 Rule loader aborted: Rule.csv header is not exact.', 1;

CREATE TABLE #RuleSeed (
    RuleId nvarchar(50) NULL,
    PhiloteId nvarchar(50) NULL,
    RuleKindId nvarchar(50) NULL,
    RulePrimitiveId nvarchar(50) NULL,
    RuleCode nvarchar(128) NULL,
    RuleBody nvarchar(max) NULL
);

BULK INSERT #RuleSeed
FROM '${data_dir}\Rule.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    TABLOCK
);

IF (SELECT COUNT_BIG(*) FROM #RuleSeed) <> 2
    THROW 53706, 'V3 Rule loader aborted: Rule.csv must contain exactly two data rows.', 1;

UPDATE #RuleSeed
SET RuleBody = REPLACE(RuleBody, CHAR(13) + CHAR(10), CHAR(10));

IF EXISTS (
    SELECT 1
    FROM #RuleSeed AS source
    WHERE CHARINDEX(CHAR(13), source.RuleBody) > 0
)
    THROW 53707, 'V3 Rule loader aborted: RuleBody contains an unsupported bare CR newline.', 1;

IF EXISTS (
    SELECT 1
    FROM #RuleSeed AS source
    CROSS APPLY (VALUES
        (source.RuleId),
        (source.PhiloteId),
        (source.RuleKindId),
        (source.RulePrimitiveId)
    ) AS identifier(Value)
    WHERE identifier.Value IS NULL
       OR TRY_CONVERT(uniqueidentifier, identifier.Value) IS NULL
       OR identifier.Value <> LOWER(CONVERT(nvarchar(36), TRY_CONVERT(uniqueidentifier, identifier.Value)))
)
    THROW 53708, 'V3 Rule loader aborted: every identifier must be a canonical lowercase GUID.', 1;

IF EXISTS (
    SELECT source.RuleId
    FROM #RuleSeed AS source
    GROUP BY source.RuleId
    HAVING COUNT_BIG(*) <> 1
)
    THROW 53709, 'V3 Rule loader aborted: Rule.csv contains a duplicate RuleId.', 1;

DECLARE @ApprovedRule TABLE (
    RuleId uniqueidentifier NOT NULL PRIMARY KEY,
    PhiloteId uniqueidentifier NOT NULL,
    RuleKindId uniqueidentifier NOT NULL,
    RulePrimitiveId uniqueidentifier NOT NULL,
    RuleCode varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RuleBody nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL
);

INSERT INTO @ApprovedRule (
    RuleId,
    PhiloteId,
    RuleKindId,
    RulePrimitiveId,
    RuleCode,
    RuleBody
)
VALUES
    (
        '616fb394-0b4d-486a-98af-48f1fe461af2',
        '616fb394-0b4d-486a-98af-48f1fe461af2',
        '8e06f2af-52cf-47d5-872e-0d3912f4fda0',
        '9460f2f5-9957-4455-b6a6-8ee241b7ebb3',
        'HelloWorld.PowerShell',
        N'function HelloWorld {' + CHAR(10)
            + N'  Write-Host ''Hello World''' + CHAR(10)
            + N'}'
    ),
    (
        'c5c1c63a-4364-4233-9aa1-2a1a5a2ba1f3',
        'c5c1c63a-4364-4233-9aa1-2a1a5a2ba1f3',
        'b32c60e0-86f3-40e6-893e-d3240ffea882',
        '03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a',
        'HelloWorld.Path',
        N'HelloWorld.ps1'
    );

IF EXISTS (
    SELECT
        TRY_CONVERT(uniqueidentifier, source.RuleId),
        TRY_CONVERT(uniqueidentifier, source.PhiloteId),
        TRY_CONVERT(uniqueidentifier, source.RuleKindId),
        TRY_CONVERT(uniqueidentifier, source.RulePrimitiveId),
        CONVERT(varchar(128), source.RuleCode) COLLATE Latin1_General_100_BIN2,
        source.RuleBody COLLATE Latin1_General_100_BIN2
    FROM #RuleSeed AS source
    EXCEPT
    SELECT
        approved.RuleId,
        approved.PhiloteId,
        approved.RuleKindId,
        approved.RulePrimitiveId,
        approved.RuleCode,
        approved.RuleBody
    FROM @ApprovedRule AS approved
) OR EXISTS (
    SELECT
        approved.RuleId,
        approved.PhiloteId,
        approved.RuleKindId,
        approved.RulePrimitiveId,
        approved.RuleCode,
        approved.RuleBody
    FROM @ApprovedRule AS approved
    EXCEPT
    SELECT
        TRY_CONVERT(uniqueidentifier, source.RuleId),
        TRY_CONVERT(uniqueidentifier, source.PhiloteId),
        TRY_CONVERT(uniqueidentifier, source.RuleKindId),
        TRY_CONVERT(uniqueidentifier, source.RulePrimitiveId),
        CONVERT(varchar(128), source.RuleCode) COLLATE Latin1_General_100_BIN2,
        source.RuleBody COLLATE Latin1_General_100_BIN2
    FROM #RuleSeed AS source
)
    THROW 53710, 'V3 Rule loader aborted: Rule.csv differs from the exact approved Rule registry and content.', 1;

IF EXISTS (
    SELECT 1
    FROM @ApprovedRule AS approved
    LEFT JOIN ATAPUtilities.Philote AS philote
        ON philote.PhiloteId = approved.PhiloteId
       AND philote.AdditionalIdsStub IS NULL
    LEFT JOIN ATAPUtilities.RuleKind AS kind
        ON kind.RuleKindId = approved.RuleKindId
       AND kind.PhiloteId = approved.RuleKindId
    LEFT JOIN ATAPUtilities.RulePrimitive AS primitive
        ON primitive.RulePrimitiveId = approved.RulePrimitiveId
       AND primitive.PhiloteId = approved.RulePrimitiveId
       AND primitive.RuleKindId = approved.RuleKindId
    WHERE philote.PhiloteId IS NULL
       OR kind.RuleKindId IS NULL
       OR primitive.RulePrimitiveId IS NULL
)
    THROW 53711, 'V3 Rule loader aborted: an exact Philote, RuleKind, or matching-kind RulePrimitive parent is missing.', 1;

IF EXISTS (
    SELECT 1
    FROM ATAPUtilities.RulePrimitiveInput AS input
    WHERE input.RulePrimitiveId IN (
        '9460f2f5-9957-4455-b6a6-8ee241b7ebb3',
        'ff659102-d147-4f1d-bd31-21978858e5fb'
    )
)
    THROW 53712, 'V3 Rule loader aborted: PowerShell primitives must have zero RulePrimitiveInput rows.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ExistingRuleCount bigint = (
        SELECT COUNT_BIG(*)
        FROM ATAPUtilities.[Rule]
    );

    IF @ExistingRuleCount NOT IN (0, 2)
        THROW 53713, 'V3 Rule loader aborted: target Rule state is neither empty nor the exact approved two-row seed.', 1;

    IF @ExistingRuleCount = 2
       AND (
            EXISTS (
                SELECT
                    target.RuleId,
                    target.PhiloteId,
                    target.RuleKindId,
                    target.RulePrimitiveId,
                    target.RuleCode COLLATE Latin1_General_100_BIN2,
                    target.RuleBody COLLATE Latin1_General_100_BIN2
                FROM ATAPUtilities.[Rule] AS target
                EXCEPT
                SELECT
                    approved.RuleId,
                    approved.PhiloteId,
                    approved.RuleKindId,
                    approved.RulePrimitiveId,
                    approved.RuleCode,
                    approved.RuleBody
                FROM @ApprovedRule AS approved
            )
            OR EXISTS (
                SELECT
                    approved.RuleId,
                    approved.PhiloteId,
                    approved.RuleKindId,
                    approved.RulePrimitiveId,
                    approved.RuleCode,
                    approved.RuleBody
                FROM @ApprovedRule AS approved
                EXCEPT
                SELECT
                    target.RuleId,
                    target.PhiloteId,
                    target.RuleKindId,
                    target.RulePrimitiveId,
                    target.RuleCode COLLATE Latin1_General_100_BIN2,
                    target.RuleBody COLLATE Latin1_General_100_BIN2
                FROM ATAPUtilities.[Rule] AS target
            )
       )
        THROW 53714, 'V3 Rule loader aborted: existing target Rules differ from the exact approved seed.', 1;

    IF @ExistingRuleCount = 0
    BEGIN
        INSERT INTO ATAPUtilities.[Rule] (
            RuleId,
            PhiloteId,
            RuleKindId,
            RulePrimitiveId,
            RuleCode,
            RuleBody
        )
        SELECT
            approved.RuleId,
            approved.PhiloteId,
            approved.RuleKindId,
            approved.RulePrimitiveId,
            approved.RuleCode,
            approved.RuleBody
        FROM @ApprovedRule AS approved;
    END;

    IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.[Rule]) <> 2
       OR EXISTS (
            SELECT 1
            FROM ATAPUtilities.[Rule] AS target
            WHERE target.RuleId <> target.PhiloteId
       )
        THROW 53715, 'V3 Rule loader aborted: target postcondition is not exactly two Philote-mirrored Rules.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

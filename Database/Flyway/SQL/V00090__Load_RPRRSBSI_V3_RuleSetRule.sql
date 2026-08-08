-- Loads the exact ordered RPRRSBSI V3 RuleSet membership from RuleSetRule.csv.
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'ATAPUtilities.Rule', N'U') IS NULL
    THROW 53900, 'V3 RuleSetRule loader aborted: ATAPUtilities.Rule does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.RuleSet', N'U') IS NULL
    THROW 53901, 'V3 RuleSetRule loader aborted: ATAPUtilities.RuleSet does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.RuleSetRule', N'U') IS NULL
    THROW 53902, 'V3 RuleSetRule loader aborted: ATAPUtilities.RuleSetRule does not exist.', 1;

DECLARE @ExpectedHeader nvarchar(128) = N'RuleSetId,RuleId,Ordinal';
DECLARE @SourceFile nvarchar(max);

SELECT @SourceFile = SourceFile.BulkColumn
FROM OPENROWSET(
    BULK '${data_dir}\RuleSetRule.csv',
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
    THROW 53903, 'V3 RuleSetRule loader aborted: RuleSetRule.csv header is not exact.', 1;

CREATE TABLE #RuleSetRuleSeed (
    RuleSetId nvarchar(50) NULL,
    RuleId nvarchar(50) NULL,
    Ordinal nvarchar(50) NULL
);

BULK INSERT #RuleSetRuleSeed
FROM '${data_dir}\RuleSetRule.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    TABLOCK
);

IF (SELECT COUNT_BIG(*) FROM #RuleSetRuleSeed) <> 2
    THROW 53904, 'V3 RuleSetRule loader aborted: RuleSetRule.csv must contain exactly two data rows.', 1;

IF EXISTS (
    SELECT 1
    FROM #RuleSetRuleSeed AS source
    CROSS APPLY (VALUES (source.RuleSetId), (source.RuleId)) AS identifier(Value)
    WHERE identifier.Value IS NULL
       OR TRY_CONVERT(uniqueidentifier, identifier.Value) IS NULL
       OR identifier.Value <> LOWER(CONVERT(nvarchar(36), TRY_CONVERT(uniqueidentifier, identifier.Value)))
) OR EXISTS (
    SELECT 1
    FROM #RuleSetRuleSeed AS source
    WHERE TRY_CONVERT(int, source.Ordinal) IS NULL
       OR source.Ordinal <> CONVERT(nvarchar(50), TRY_CONVERT(int, source.Ordinal))
       OR TRY_CONVERT(int, source.Ordinal) < 0
)
    THROW 53905, 'V3 RuleSetRule loader aborted: source identifiers or ordinals are invalid or non-canonical.', 1;

IF EXISTS (
    SELECT source.RuleSetId, source.RuleId
    FROM #RuleSetRuleSeed AS source
    GROUP BY source.RuleSetId, source.RuleId
    HAVING COUNT_BIG(*) <> 1
) OR EXISTS (
    SELECT source.RuleSetId, source.Ordinal
    FROM #RuleSetRuleSeed AS source
    GROUP BY source.RuleSetId, source.Ordinal
    HAVING COUNT_BIG(*) <> 1
)
    THROW 53906, 'V3 RuleSetRule loader aborted: duplicate Rule membership or ordinal is not allowed.', 1;

DECLARE @ApprovedRuleSetId uniqueidentifier = '23ad4f37-2c70-4f34-9104-9868ec0f3823';
DECLARE @PowerShellRuleId uniqueidentifier = '616fb394-0b4d-486a-98af-48f1fe461af2';
DECLARE @PathRuleId uniqueidentifier = 'c5c1c63a-4364-4233-9aa1-2a1a5a2ba1f3';
DECLARE @ApprovedRuleSetRule TABLE (
    RuleSetId uniqueidentifier NOT NULL,
    RuleId uniqueidentifier NOT NULL,
    Ordinal int NOT NULL,
    PRIMARY KEY (RuleSetId, RuleId),
    UNIQUE (RuleSetId, Ordinal)
);

INSERT INTO @ApprovedRuleSetRule (RuleSetId, RuleId, Ordinal)
VALUES
    (@ApprovedRuleSetId, @PowerShellRuleId, 0),
    (@ApprovedRuleSetId, @PathRuleId, 1);

IF EXISTS (
    SELECT
        TRY_CONVERT(uniqueidentifier, source.RuleSetId),
        TRY_CONVERT(uniqueidentifier, source.RuleId),
        TRY_CONVERT(int, source.Ordinal)
    FROM #RuleSetRuleSeed AS source
    EXCEPT
    SELECT approved.RuleSetId, approved.RuleId, approved.Ordinal
    FROM @ApprovedRuleSetRule AS approved
) OR EXISTS (
    SELECT approved.RuleSetId, approved.RuleId, approved.Ordinal
    FROM @ApprovedRuleSetRule AS approved
    EXCEPT
    SELECT
        TRY_CONVERT(uniqueidentifier, source.RuleSetId),
        TRY_CONVERT(uniqueidentifier, source.RuleId),
        TRY_CONVERT(int, source.Ordinal)
    FROM #RuleSetRuleSeed AS source
)
    THROW 53907, 'V3 RuleSetRule loader aborted: RuleSetRule.csv differs from the exact approved ordering.', 1;

IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.RuleSet) <> 1
   OR NOT EXISTS (
        SELECT 1
        FROM ATAPUtilities.RuleSet AS target
        WHERE target.RuleSetId = @ApprovedRuleSetId
          AND target.PhiloteId = @ApprovedRuleSetId
          AND CONVERT(varbinary(256), target.RuleSetCode) = CONVERT(varbinary(256), CONVERT(varchar(128), 'HelloWorld'))
   )
    THROW 53908, 'V3 RuleSetRule loader aborted: the exact HelloWorld RuleSet parent is required.', 1;

IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.[Rule]) <> 2
   OR NOT EXISTS (
        SELECT 1
        FROM ATAPUtilities.[Rule] AS target
        WHERE target.RuleId = @PowerShellRuleId
          AND target.PhiloteId = @PowerShellRuleId
          AND target.RuleKindId = '8e06f2af-52cf-47d5-872e-0d3912f4fda0'
          AND target.RulePrimitiveId = '9460f2f5-9957-4455-b6a6-8ee241b7ebb3'
          AND CONVERT(varbinary(256), target.RuleCode) = CONVERT(varbinary(256), CONVERT(varchar(128), 'HelloWorld.PowerShell'))
   )
   OR NOT EXISTS (
        SELECT 1
        FROM ATAPUtilities.[Rule] AS target
        WHERE target.RuleId = @PathRuleId
          AND target.PhiloteId = @PathRuleId
          AND target.RuleKindId = 'b32c60e0-86f3-40e6-893e-d3240ffea882'
          AND target.RulePrimitiveId = '03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a'
          AND CONVERT(varbinary(256), target.RuleCode) = CONVERT(varbinary(256), CONVERT(varchar(128), 'HelloWorld.Path'))
   )
    THROW 53909, 'V3 RuleSetRule loader aborted: the exact PowerShell and Path Rule parents are required.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ExistingMembershipCount bigint = (SELECT COUNT_BIG(*) FROM ATAPUtilities.RuleSetRule);

    IF @ExistingMembershipCount NOT IN (0, 2)
        THROW 53910, 'V3 RuleSetRule loader aborted: target state is neither empty nor the exact approved membership.', 1;

    IF @ExistingMembershipCount = 2
       AND (
            EXISTS (
                SELECT target.RuleSetId, target.RuleId, target.Ordinal
                FROM ATAPUtilities.RuleSetRule AS target
                EXCEPT
                SELECT approved.RuleSetId, approved.RuleId, approved.Ordinal
                FROM @ApprovedRuleSetRule AS approved
            )
            OR EXISTS (
                SELECT approved.RuleSetId, approved.RuleId, approved.Ordinal
                FROM @ApprovedRuleSetRule AS approved
                EXCEPT
                SELECT target.RuleSetId, target.RuleId, target.Ordinal
                FROM ATAPUtilities.RuleSetRule AS target
            )
       )
        THROW 53911, 'V3 RuleSetRule loader aborted: existing target membership differs from the approved ordering.', 1;

    IF @ExistingMembershipCount = 0
    BEGIN
        INSERT INTO ATAPUtilities.RuleSetRule (RuleSetId, RuleId, Ordinal)
        SELECT approved.RuleSetId, approved.RuleId, approved.Ordinal
        FROM @ApprovedRuleSetRule AS approved;
    END;

    IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.RuleSetRule) <> 2
       OR EXISTS (
            SELECT target.RuleSetId, target.RuleId, target.Ordinal
            FROM ATAPUtilities.RuleSetRule AS target
            EXCEPT
            SELECT approved.RuleSetId, approved.RuleId, approved.Ordinal
            FROM @ApprovedRuleSetRule AS approved
       )
        THROW 53912, 'V3 RuleSetRule loader aborted: target postcondition is not the exact approved ordering.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

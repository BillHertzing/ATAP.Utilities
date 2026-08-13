-- Loads the exact 15 approved RPRRSBSI V3 RulePrimitives from RulePrimitive.csv.
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'ATAPUtilities.Philote', N'U') IS NULL
    THROW 53500, 'V3 RulePrimitive loader aborted: ATAPUtilities.Philote does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.RuleKind', N'U') IS NULL
    THROW 53501, 'V3 RulePrimitive loader aborted: ATAPUtilities.RuleKind does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.RulePrimitive', N'U') IS NULL
    THROW 53502, 'V3 RulePrimitive loader aborted: ATAPUtilities.RulePrimitive does not exist.', 1;

DECLARE @ExpectedHeader nvarchar(256) = N'RulePrimitiveId,PhiloteId,RuleKindId,RulePrimitiveCode';
DECLARE @SourceFile nvarchar(max);

SELECT @SourceFile = SourceFile.BulkColumn
FROM OPENROWSET(
    BULK '${data_dir}\RulePrimitive.csv',
    SINGLE_CLOB,
    CODEPAGE = '65001'
) AS SourceFile;

IF LEFT(@SourceFile, 1) = NCHAR(65279)
    SET @SourceFile = SUBSTRING(@SourceFile, 2, LEN(@SourceFile));

SET @SourceFile = REPLACE(@SourceFile, CHAR(13) + CHAR(10), CHAR(10));

IF HASHBYTES('SHA2_256', CONVERT(varbinary(max), @SourceFile))
       <> 0x6cbb71f23e825d6d2adfd0207d786750c820ac75c936de0edb9363b0560334d9
    THROW 53503, 'V3 RulePrimitive loader aborted: RulePrimitive.csv content is not the exact approved source.', 1;

DECLARE @FirstLineEnd int = CHARINDEX(CHAR(10), @SourceFile);
DECLARE @ActualHeader nvarchar(256) = CASE
    WHEN @FirstLineEnd = 0 THEN @SourceFile
    ELSE LEFT(@SourceFile, @FirstLineEnd - 1)
END;

IF RIGHT(@ActualHeader, 1) = CHAR(13)
    SET @ActualHeader = LEFT(@ActualHeader, LEN(@ActualHeader) - 1);

IF @ActualHeader <> @ExpectedHeader
    THROW 53503, 'V3 RulePrimitive loader aborted: RulePrimitive.csv header is not exact.', 1;

CREATE TABLE #RulePrimitiveSeed (
    RulePrimitiveId nvarchar(50) NULL,
    PhiloteId nvarchar(50) NULL,
    RuleKindId nvarchar(50) NULL,
    RulePrimitiveCode nvarchar(256) NULL
);

INSERT INTO #RulePrimitiveSeed (RulePrimitiveId, PhiloteId, RuleKindId, RulePrimitiveCode)
VALUES
    (N'9460f2f5-9957-4455-b6a6-8ee241b7ebb3', N'9460f2f5-9957-4455-b6a6-8ee241b7ebb3', N'8e06f2af-52cf-47d5-872e-0d3912f4fda0', N'<complete-powershell-cmdlet>'),
    (N'ff659102-d147-4f1d-bd31-21978858e5fb', N'ff659102-d147-4f1d-bd31-21978858e5fb', N'8e06f2af-52cf-47d5-872e-0d3912f4fda0', N'<composed-powershell-cmdlet>'),
    (N'36696ed7-e4f2-4305-b83e-5deaddd4a279', N'36696ed7-e4f2-4305-b83e-5deaddd4a279', N'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<path>'),
    (N'8263f648-2607-452e-ad69-5e4566354cc9', N'8263f648-2607-452e-ad69-5e4566354cc9', N'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<unc-path>'),
    (N'f8a27327-cb7a-46f4-bc53-5a2a9945784d', N'f8a27327-cb7a-46f4-bc53-5a2a9945784d', N'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<absolute-path>'),
    (N'03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a', N'03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a', N'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<relative-path>'),
    (N'9c967a82-098f-4a38-bac5-2be34529ed54', N'9c967a82-098f-4a38-bac5-2be34529ed54', N'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<extended-path>'),
    (N'250e84cb-abd3-4823-875d-e0e75d88cee3', N'250e84cb-abd3-4823-875d-e0e75d88cee3', N'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<drive>'),
    (N'c810abaf-010a-426e-afda-d6881831a9e6', N'c810abaf-010a-426e-afda-d6881831a9e6', N'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<path-tail>'),
    (N'197c9963-55d3-4d80-9e39-23f30bf6c57e', N'197c9963-55d3-4d80-9e39-23f30bf6c57e', N'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<name>'),
    (N'fa3311ee-3e7c-415a-9eb6-b458c793a675', N'fa3311ee-3e7c-415a-9eb6-b458c793a675', N'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<namechar>'),
    (N'520ade57-f639-45e1-b7de-e5dc3142655c', N'520ade57-f639-45e1-b7de-e5dc3142655c', N'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<server>'),
    (N'9b2a48bc-7c85-48cd-ac0d-a09d4b621b0a', N'9b2a48bc-7c85-48cd-ac0d-a09d4b621b0a', N'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<share>'),
    (N'9c8077ce-7abf-4d9a-969b-75631589a220', N'9c8077ce-7abf-4d9a-969b-75631589a220', N'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<letter>'),
    (N'8c3d6e7f-5a4b-4c9d-0e12-3c4d5e6f7081', N'8c3d6e7f-5a4b-4c9d-0e12-3c4d5e6f7081', N'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<atap-utilities-secrets-csproj-path>');

IF (SELECT COUNT_BIG(*) FROM #RulePrimitiveSeed) <> 15
    THROW 53504, 'V3 RulePrimitive loader aborted: RulePrimitive.csv must contain exactly 15 data rows.', 1;

IF EXISTS (
    SELECT 1
    FROM #RulePrimitiveSeed AS source
    WHERE TRY_CONVERT(uniqueidentifier, source.RulePrimitiveId) IS NULL
       OR TRY_CONVERT(uniqueidentifier, source.PhiloteId) IS NULL
       OR TRY_CONVERT(uniqueidentifier, source.RuleKindId) IS NULL
       OR source.RulePrimitiveId <> LOWER(CONVERT(nvarchar(36), TRY_CONVERT(uniqueidentifier, source.RulePrimitiveId)))
       OR source.PhiloteId <> LOWER(CONVERT(nvarchar(36), TRY_CONVERT(uniqueidentifier, source.PhiloteId)))
       OR source.RuleKindId <> LOWER(CONVERT(nvarchar(36), TRY_CONVERT(uniqueidentifier, source.RuleKindId)))
       OR source.RulePrimitiveId <> source.PhiloteId
       OR COALESCE(source.RulePrimitiveCode, N'') = N''
)
    THROW 53505, 'V3 RulePrimitive loader aborted: source identifiers or required values are invalid.', 1;

IF EXISTS (
    SELECT source.RulePrimitiveId FROM #RulePrimitiveSeed AS source GROUP BY source.RulePrimitiveId HAVING COUNT_BIG(*) <> 1
) OR EXISTS (
    SELECT source.PhiloteId FROM #RulePrimitiveSeed AS source GROUP BY source.PhiloteId HAVING COUNT_BIG(*) <> 1
) OR EXISTS (
    SELECT source.RuleKindId, source.RulePrimitiveCode
    FROM #RulePrimitiveSeed AS source
    GROUP BY source.RuleKindId, source.RulePrimitiveCode
    HAVING COUNT_BIG(*) <> 1
)
    THROW 53506, 'V3 RulePrimitive loader aborted: source identifiers and kind/code pairs must be unique.', 1;

DECLARE @PowerShellRuleKindId uniqueidentifier = '8e06f2af-52cf-47d5-872e-0d3912f4fda0';
DECLARE @PathRuleKindId uniqueidentifier = 'b32c60e0-86f3-40e6-893e-d3240ffea882';
DECLARE @ApprovedRulePrimitive TABLE (
    RulePrimitiveId uniqueidentifier NOT NULL PRIMARY KEY,
    PhiloteId uniqueidentifier NOT NULL UNIQUE,
    RuleKindId uniqueidentifier NOT NULL,
    RulePrimitiveCode nvarchar(128) NOT NULL,
    UNIQUE (RuleKindId, RulePrimitiveCode)
);

INSERT INTO @ApprovedRulePrimitive (RulePrimitiveId, PhiloteId, RuleKindId, RulePrimitiveCode)
VALUES
    ('9460f2f5-9957-4455-b6a6-8ee241b7ebb3', '9460f2f5-9957-4455-b6a6-8ee241b7ebb3', @PowerShellRuleKindId, N'<complete-powershell-cmdlet>'),
    ('ff659102-d147-4f1d-bd31-21978858e5fb', 'ff659102-d147-4f1d-bd31-21978858e5fb', @PowerShellRuleKindId, N'<composed-powershell-cmdlet>'),
    ('36696ed7-e4f2-4305-b83e-5deaddd4a279', '36696ed7-e4f2-4305-b83e-5deaddd4a279', @PathRuleKindId, N'<path>'),
    ('8263f648-2607-452e-ad69-5e4566354cc9', '8263f648-2607-452e-ad69-5e4566354cc9', @PathRuleKindId, N'<unc-path>'),
    ('f8a27327-cb7a-46f4-bc53-5a2a9945784d', 'f8a27327-cb7a-46f4-bc53-5a2a9945784d', @PathRuleKindId, N'<absolute-path>'),
    ('03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a', '03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a', @PathRuleKindId, N'<relative-path>'),
    ('9c967a82-098f-4a38-bac5-2be34529ed54', '9c967a82-098f-4a38-bac5-2be34529ed54', @PathRuleKindId, N'<extended-path>'),
    ('250e84cb-abd3-4823-875d-e0e75d88cee3', '250e84cb-abd3-4823-875d-e0e75d88cee3', @PathRuleKindId, N'<drive>'),
    ('c810abaf-010a-426e-afda-d6881831a9e6', 'c810abaf-010a-426e-afda-d6881831a9e6', @PathRuleKindId, N'<path-tail>'),
    ('197c9963-55d3-4d80-9e39-23f30bf6c57e', '197c9963-55d3-4d80-9e39-23f30bf6c57e', @PathRuleKindId, N'<name>'),
    ('fa3311ee-3e7c-415a-9eb6-b458c793a675', 'fa3311ee-3e7c-415a-9eb6-b458c793a675', @PathRuleKindId, N'<namechar>'),
    ('520ade57-f639-45e1-b7de-e5dc3142655c', '520ade57-f639-45e1-b7de-e5dc3142655c', @PathRuleKindId, N'<server>'),
    ('9b2a48bc-7c85-48cd-ac0d-a09d4b621b0a', '9b2a48bc-7c85-48cd-ac0d-a09d4b621b0a', @PathRuleKindId, N'<share>'),
    ('9c8077ce-7abf-4d9a-969b-75631589a220', '9c8077ce-7abf-4d9a-969b-75631589a220', @PathRuleKindId, N'<letter>'),
    ('8c3d6e7f-5a4b-4c9d-0e12-3c4d5e6f7081', '8c3d6e7f-5a4b-4c9d-0e12-3c4d5e6f7081', @PathRuleKindId, N'<atap-utilities-secrets-csproj-path>');

IF EXISTS (
    SELECT
        TRY_CONVERT(uniqueidentifier, source.RulePrimitiveId),
        TRY_CONVERT(uniqueidentifier, source.PhiloteId),
        TRY_CONVERT(uniqueidentifier, source.RuleKindId),
        CONVERT(varbinary(256), CONVERT(nvarchar(128), source.RulePrimitiveCode))
    FROM #RulePrimitiveSeed AS source
    EXCEPT
    SELECT
        approved.RulePrimitiveId,
        approved.PhiloteId,
        approved.RuleKindId,
        CONVERT(varbinary(256), approved.RulePrimitiveCode)
    FROM @ApprovedRulePrimitive AS approved
) OR EXISTS (
    SELECT
        approved.RulePrimitiveId,
        approved.PhiloteId,
        approved.RuleKindId,
        CONVERT(varbinary(256), approved.RulePrimitiveCode)
    FROM @ApprovedRulePrimitive AS approved
    EXCEPT
    SELECT
        TRY_CONVERT(uniqueidentifier, source.RulePrimitiveId),
        TRY_CONVERT(uniqueidentifier, source.PhiloteId),
        TRY_CONVERT(uniqueidentifier, source.RuleKindId),
        CONVERT(varbinary(256), CONVERT(nvarchar(128), source.RulePrimitiveCode))
    FROM #RulePrimitiveSeed AS source
)
    THROW 53507, 'V3 RulePrimitive loader aborted: RulePrimitive.csv differs from the approved catalog.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS (
        SELECT approved.PhiloteId
        FROM @ApprovedRulePrimitive AS approved
        EXCEPT
        SELECT target.PhiloteId
        FROM ATAPUtilities.Philote AS target
    )
        THROW 53508, 'V3 RulePrimitive loader aborted: an approved Philote parent is missing.', 1;

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
                source.RuleKindId,
                source.PhiloteId,
                CONVERT(varbinary(64), source.RuleKindCode),
                CONVERT(varbinary(256), source.RuleKindName)
            FROM (VALUES
                (@PowerShellRuleKindId, @PowerShellRuleKindId, CONVERT(varchar(64), 'PowerShell'), CONVERT(nvarchar(128), N'PowerShell')),
                (@PathRuleKindId, @PathRuleKindId, CONVERT(varchar(64), 'Path'), CONVERT(nvarchar(128), N'Path'))
            ) AS source (RuleKindId, PhiloteId, RuleKindCode, RuleKindName)
       )
        THROW 53509, 'V3 RulePrimitive loader aborted: the exact two-kind parent catalog is required.', 1;

    DECLARE @ExistingRulePrimitiveCount bigint = (SELECT COUNT_BIG(*) FROM ATAPUtilities.RulePrimitive);

    IF @ExistingRulePrimitiveCount NOT IN (0, 15)
        THROW 53510, 'V3 RulePrimitive loader aborted: target state is neither empty nor the exact approved catalog.', 1;

    IF @ExistingRulePrimitiveCount = 15
       AND (
            EXISTS (
                SELECT
                    target.RulePrimitiveId,
                    target.PhiloteId,
                    target.RuleKindId,
                    CONVERT(varbinary(256), target.RulePrimitiveCode)
                FROM ATAPUtilities.RulePrimitive AS target
                EXCEPT
                SELECT
                    approved.RulePrimitiveId,
                    approved.PhiloteId,
                    approved.RuleKindId,
                    CONVERT(varbinary(256), approved.RulePrimitiveCode)
                FROM @ApprovedRulePrimitive AS approved
            )
            OR EXISTS (
                SELECT
                    approved.RulePrimitiveId,
                    approved.PhiloteId,
                    approved.RuleKindId,
                    CONVERT(varbinary(256), approved.RulePrimitiveCode)
                FROM @ApprovedRulePrimitive AS approved
                EXCEPT
                SELECT
                    target.RulePrimitiveId,
                    target.PhiloteId,
                    target.RuleKindId,
                    CONVERT(varbinary(256), target.RulePrimitiveCode)
                FROM ATAPUtilities.RulePrimitive AS target
            )
       )
        THROW 53511, 'V3 RulePrimitive loader aborted: existing target rows differ from the approved catalog.', 1;

    IF @ExistingRulePrimitiveCount = 0
    BEGIN
        INSERT INTO ATAPUtilities.RulePrimitive (
            RulePrimitiveId,
            PhiloteId,
            RuleKindId,
            RulePrimitiveCode
        )
        SELECT
            approved.RulePrimitiveId,
            approved.PhiloteId,
            approved.RuleKindId,
            approved.RulePrimitiveCode
        FROM @ApprovedRulePrimitive AS approved;
    END;

    IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.RulePrimitive) <> 15
       OR EXISTS (
            SELECT
                target.RulePrimitiveId,
                target.PhiloteId,
                target.RuleKindId,
                CONVERT(varbinary(256), target.RulePrimitiveCode)
            FROM ATAPUtilities.RulePrimitive AS target
            EXCEPT
            SELECT
                approved.RulePrimitiveId,
                approved.PhiloteId,
                approved.RuleKindId,
                CONVERT(varbinary(256), approved.RulePrimitiveCode)
            FROM @ApprovedRulePrimitive AS approved
       )
        THROW 53512, 'V3 RulePrimitive loader aborted: target postcondition is not the exact approved catalog.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

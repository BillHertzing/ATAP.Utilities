-- Loads the exact approved RPRRSBSI V3 structured Path input declarations.
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'ATAPUtilities.RulePrimitive', N'U') IS NULL
    THROW 53600, 'V3 RulePrimitiveInput loader aborted: ATAPUtilities.RulePrimitive does not exist.', 1;

IF OBJECT_ID(N'ATAPUtilities.RulePrimitiveInput', N'U') IS NULL
    THROW 53601, 'V3 RulePrimitiveInput loader aborted: ATAPUtilities.RulePrimitiveInput does not exist.', 1;

DECLARE @ExpectedHeader nvarchar(512) = N'RulePrimitiveInputId,RulePrimitiveId,InputName,InputType,InputDescription,DefaultValue,IsRequired,Ordinal';
DECLARE @SourceFile nvarchar(max);

SELECT @SourceFile = SourceFile.BulkColumn
FROM OPENROWSET(
    BULK '${data_dir}\RulePrimitiveInput.csv',
    SINGLE_CLOB,
    CODEPAGE = '65001'
) AS SourceFile;

IF LEFT(@SourceFile, 1) = NCHAR(65279)
    SET @SourceFile = SUBSTRING(@SourceFile, 2, LEN(@SourceFile));

SET @SourceFile = REPLACE(@SourceFile, CHAR(13) + CHAR(10), CHAR(10));

IF HASHBYTES('SHA2_256', CONVERT(varbinary(max), @SourceFile))
       <> 0x0442cfd519d7711038fe3d171e219d379813d59962edbda32bc1304c3204790c
    THROW 53602, 'V3 RulePrimitiveInput loader aborted: RulePrimitiveInput.csv content is not the exact approved source.', 1;

DECLARE @FirstLineEnd int = CHARINDEX(CHAR(10), @SourceFile);
DECLARE @ActualHeader nvarchar(512) = CASE
    WHEN @FirstLineEnd = 0 THEN @SourceFile
    ELSE LEFT(@SourceFile, @FirstLineEnd - 1)
END;

IF RIGHT(@ActualHeader, 1) = CHAR(13)
    SET @ActualHeader = LEFT(@ActualHeader, LEN(@ActualHeader) - 1);

IF @ActualHeader <> @ExpectedHeader
    THROW 53602, 'V3 RulePrimitiveInput loader aborted: RulePrimitiveInput.csv header is not exact.', 1;

CREATE TABLE #RulePrimitiveInputSeed (
    RulePrimitiveInputId nvarchar(50) NULL,
    RulePrimitiveId nvarchar(50) NULL,
    InputName nvarchar(128) NULL,
    InputType nvarchar(256) NULL,
    InputDescription nvarchar(1024) NULL,
    DefaultValue nvarchar(4000) NULL,
    IsRequired nvarchar(10) NULL,
    Ordinal nvarchar(20) NULL
);

INSERT INTO #RulePrimitiveInputSeed (
    RulePrimitiveInputId,
    RulePrimitiveId,
    InputName,
    InputType,
    InputDescription,
    DefaultValue,
    IsRequired,
    Ordinal
)
VALUES
    (N'47cec849-5612-4a83-b916-a5ba8d36692b', N'36696ed7-e4f2-4305-b83e-5deaddd4a279', N'PathType', N'enum(UNC|Absolute|Relative|Extended)', N'Determines which path variant to render', N'', N'1', N'0'),
    (N'1a7ecff0-b6f4-4481-a9a0-81f298f42cc0', N'36696ed7-e4f2-4305-b83e-5deaddd4a279', N'PathContent', N'RulePrimitive', N'Provides the actual path structure selected by PathType', N'', N'1', N'1'),
    (N'7ef564cd-32dd-4319-aeb7-17a02c8a4f0f', N'8263f648-2607-452e-ad69-5e4566354cc9', N'Server', N'<server>', N'Provides the network server name or IP address', N'', N'1', N'0'),
    (N'cb3af1f3-e2c1-49fc-9376-a2b3dd41eff5', N'8263f648-2607-452e-ad69-5e4566354cc9', N'Share', N'<share>', N'Provides the shared resource name on the server', N'', N'1', N'1'),
    (N'bd8f280b-e7a0-45b0-b8cc-ace4cf3ada0e', N'8263f648-2607-452e-ad69-5e4566354cc9', N'PathTail', N'<path-tail>', N'Provides the optional directory or file path within the share', N'', N'0', N'2'),
    (N'84a7a08e-152d-4e4c-8bff-71791d16fef8', N'f8a27327-cb7a-46f4-bc53-5a2a9945784d', N'Drive', N'<drive>', N'Provides the optional drive letter and colon', N'', N'0', N'0'),
    (N'4680c930-c04b-47df-9c86-36d4b0c576c5', N'f8a27327-cb7a-46f4-bc53-5a2a9945784d', N'PathTail', N'<path-tail>', N'Provides the optional directory or file hierarchy', N'', N'0', N'1'),
    (N'0451e48e-5e94-47df-a94b-deaca7ea1675', N'03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a', N'PathTail', N'<path-tail>', N'Provides the relative directory or file hierarchy', N'', N'1', N'0'),
    (N'f37f15bc-683e-4ebe-a3aa-e293df4b2542', N'9c967a82-098f-4a38-bac5-2be34529ed54', N'PathVariant', N'enum(Local|UNC)', N'Determines whether the extended path is local or UNC', N'', N'1', N'0'),
    (N'50b2f135-8b28-4ede-840b-e90871124e3e', N'9c967a82-098f-4a38-bac5-2be34529ed54', N'AbsolutePath', N'<absolute-path>', N'Provides the absolute path for the Local variant', N'', N'0', N'1'),
    (N'9a74bda5-18cb-420b-b08c-f6db62777474', N'9c967a82-098f-4a38-bac5-2be34529ed54', N'Server', N'<server>', N'Provides the network server component for the UNC variant', N'', N'0', N'2'),
    (N'f5ae0c3c-eb4e-4d5d-b2ab-dc80468115c1', N'9c967a82-098f-4a38-bac5-2be34529ed54', N'Share', N'<share>', N'Provides the shared resource component for the UNC variant', N'', N'0', N'3'),
    (N'e4cb67dd-7db9-42ec-9914-0f98232a4ee3', N'9c967a82-098f-4a38-bac5-2be34529ed54', N'PathTail', N'<path-tail>', N'Provides the optional directory or file path for the UNC variant', N'', N'0', N'4'),
    (N'fd545856-9bc3-418f-b729-3b170e440230', N'250e84cb-abd3-4823-875d-e0e75d88cee3', N'Letter', N'<letter>', N'Provides one alphabetic drive letter', N'', N'1', N'0'),
    (N'105da8b3-6365-46cf-8231-31126df64b69', N'c810abaf-010a-426e-afda-d6881831a9e6', N'Name', N'<name>', N'Provides the first directory or file name', N'', N'1', N'0'),
    (N'6d6731ab-f47f-4fd6-b6e9-8d9a69711a6a', N'c810abaf-010a-426e-afda-d6881831a9e6', N'RestOfPath', N'<path-tail>', N'Provides the optional remainder of the path hierarchy', N'', N'0', N'1'),
    (N'18ee327e-0f41-406b-bfac-b99904739e82', N'197c9963-55d3-4d80-9e39-23f30bf6c57e', N'NameChars', N'list(<namechar>)', N'Provides the ordered characters composing the name', N'', N'1', N'0'),
    (N'32318390-c6ac-4f58-ba39-b542d1b3dd87', N'fa3311ee-3e7c-415a-9eb6-b458c793a675', N'Character', N'char', N'Provides the single path character to validate and render', N'', N'1', N'0'),
    (N'6847251f-24e9-453c-8848-5d43cc529dcf', N'520ade57-f639-45e1-b7de-e5dc3142655c', N'ServerIdentifier', N'<name>|IPAddressString', N'Provides the server name or IP address', N'', N'1', N'0'),
    (N'1b3ca37b-f095-47e7-9f96-8dd5f4735079', N'9b2a48bc-7c85-48cd-ac0d-a09d4b621b0a', N'ShareName', N'<name>', N'Provides the shared resource name', N'', N'1', N'0'),
    (N'ff932d94-61a4-4274-99a7-84229acbfb5b', N'9c8077ce-7abf-4d9a-969b-75631589a220', N'LetterChar', N'char', N'Provides one alphabetic character from A through Z or a through z', N'', N'1', N'0');

IF (SELECT COUNT_BIG(*) FROM #RulePrimitiveInputSeed) <> 21
    THROW 53603, 'V3 RulePrimitiveInput loader aborted: RulePrimitiveInput.csv must contain exactly 21 data rows.', 1;

IF EXISTS (
    SELECT 1
    FROM #RulePrimitiveInputSeed AS source
    WHERE TRY_CONVERT(uniqueidentifier, source.RulePrimitiveInputId) IS NULL
       OR source.RulePrimitiveInputId <> LOWER(CONVERT(nvarchar(36), TRY_CONVERT(uniqueidentifier, source.RulePrimitiveInputId)))
       OR TRY_CONVERT(uniqueidentifier, source.RulePrimitiveId) IS NULL
       OR source.RulePrimitiveId <> LOWER(CONVERT(nvarchar(36), TRY_CONVERT(uniqueidentifier, source.RulePrimitiveId)))
)
    THROW 53604, 'V3 RulePrimitiveInput loader aborted: every input and parent ID must be a canonical lowercase GUID.', 1;

IF EXISTS (
    SELECT source.RulePrimitiveInputId
    FROM #RulePrimitiveInputSeed AS source
    GROUP BY source.RulePrimitiveInputId
    HAVING COUNT_BIG(*) <> 1
)
    THROW 53605, 'V3 RulePrimitiveInput loader aborted: RulePrimitiveInput.csv contains a duplicate input ID.', 1;

IF EXISTS (
    SELECT source.RulePrimitiveId, source.InputName
    FROM #RulePrimitiveInputSeed AS source
    GROUP BY source.RulePrimitiveId, source.InputName
    HAVING COUNT_BIG(*) <> 1
)
    THROW 53606, 'V3 RulePrimitiveInput loader aborted: RulePrimitiveInput.csv contains a duplicate parent/name pair.', 1;

IF EXISTS (
    SELECT source.RulePrimitiveId, source.Ordinal
    FROM #RulePrimitiveInputSeed AS source
    GROUP BY source.RulePrimitiveId, source.Ordinal
    HAVING COUNT_BIG(*) <> 1
)
    THROW 53607, 'V3 RulePrimitiveInput loader aborted: RulePrimitiveInput.csv contains a duplicate parent/ordinal pair.', 1;

IF EXISTS (
    SELECT 1
    FROM #RulePrimitiveInputSeed AS source
    WHERE source.InputName IS NULL
       OR source.InputName = N''
       OR source.InputType IS NULL
       OR source.InputType = N''
       OR source.InputDescription IS NULL
       OR source.InputDescription = N''
       OR source.IsRequired NOT IN (N'0', N'1')
       OR TRY_CONVERT(int, source.Ordinal) IS NULL
       OR source.Ordinal <> CONVERT(nvarchar(20), TRY_CONVERT(int, source.Ordinal))
       OR TRY_CONVERT(int, source.Ordinal) < 0
       OR COALESCE(source.DefaultValue, N'') <> N''
)
    THROW 53608, 'V3 RulePrimitiveInput loader aborted: a required field, null default, required flag, or ordinal is invalid.', 1;

DECLARE @ApprovedSeed TABLE (
    RulePrimitiveInputId uniqueidentifier NOT NULL PRIMARY KEY,
    RulePrimitiveId uniqueidentifier NOT NULL,
    InputName nvarchar(128) NOT NULL,
    InputType nvarchar(256) NOT NULL,
    InputDescription nvarchar(1024) NOT NULL,
    DefaultValue nvarchar(4000) NULL,
    IsRequired bit NOT NULL,
    Ordinal int NOT NULL,
    UNIQUE (RulePrimitiveId, InputName),
    UNIQUE (RulePrimitiveId, Ordinal)
);

INSERT INTO @ApprovedSeed (
    RulePrimitiveInputId,
    RulePrimitiveId,
    InputName,
    InputType,
    InputDescription,
    DefaultValue,
    IsRequired,
    Ordinal
)
VALUES
    ('47cec849-5612-4a83-b916-a5ba8d36692b', '36696ed7-e4f2-4305-b83e-5deaddd4a279', N'PathType', N'enum(UNC|Absolute|Relative|Extended)', N'Determines which path variant to render', NULL, 1, 0),
    ('1a7ecff0-b6f4-4481-a9a0-81f298f42cc0', '36696ed7-e4f2-4305-b83e-5deaddd4a279', N'PathContent', N'RulePrimitive', N'Provides the actual path structure selected by PathType', NULL, 1, 1),
    ('7ef564cd-32dd-4319-aeb7-17a02c8a4f0f', '8263f648-2607-452e-ad69-5e4566354cc9', N'Server', N'<server>', N'Provides the network server name or IP address', NULL, 1, 0),
    ('cb3af1f3-e2c1-49fc-9376-a2b3dd41eff5', '8263f648-2607-452e-ad69-5e4566354cc9', N'Share', N'<share>', N'Provides the shared resource name on the server', NULL, 1, 1),
    ('bd8f280b-e7a0-45b0-b8cc-ace4cf3ada0e', '8263f648-2607-452e-ad69-5e4566354cc9', N'PathTail', N'<path-tail>', N'Provides the optional directory or file path within the share', NULL, 0, 2),
    ('84a7a08e-152d-4e4c-8bff-71791d16fef8', 'f8a27327-cb7a-46f4-bc53-5a2a9945784d', N'Drive', N'<drive>', N'Provides the optional drive letter and colon', NULL, 0, 0),
    ('4680c930-c04b-47df-9c86-36d4b0c576c5', 'f8a27327-cb7a-46f4-bc53-5a2a9945784d', N'PathTail', N'<path-tail>', N'Provides the optional directory or file hierarchy', NULL, 0, 1),
    ('0451e48e-5e94-47df-a94b-deaca7ea1675', '03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a', N'PathTail', N'<path-tail>', N'Provides the relative directory or file hierarchy', NULL, 1, 0),
    ('f37f15bc-683e-4ebe-a3aa-e293df4b2542', '9c967a82-098f-4a38-bac5-2be34529ed54', N'PathVariant', N'enum(Local|UNC)', N'Determines whether the extended path is local or UNC', NULL, 1, 0),
    ('50b2f135-8b28-4ede-840b-e90871124e3e', '9c967a82-098f-4a38-bac5-2be34529ed54', N'AbsolutePath', N'<absolute-path>', N'Provides the absolute path for the Local variant', NULL, 0, 1),
    ('9a74bda5-18cb-420b-b08c-f6db62777474', '9c967a82-098f-4a38-bac5-2be34529ed54', N'Server', N'<server>', N'Provides the network server component for the UNC variant', NULL, 0, 2),
    ('f5ae0c3c-eb4e-4d5d-b2ab-dc80468115c1', '9c967a82-098f-4a38-bac5-2be34529ed54', N'Share', N'<share>', N'Provides the shared resource component for the UNC variant', NULL, 0, 3),
    ('e4cb67dd-7db9-42ec-9914-0f98232a4ee3', '9c967a82-098f-4a38-bac5-2be34529ed54', N'PathTail', N'<path-tail>', N'Provides the optional directory or file path for the UNC variant', NULL, 0, 4),
    ('fd545856-9bc3-418f-b729-3b170e440230', '250e84cb-abd3-4823-875d-e0e75d88cee3', N'Letter', N'<letter>', N'Provides one alphabetic drive letter', NULL, 1, 0),
    ('105da8b3-6365-46cf-8231-31126df64b69', 'c810abaf-010a-426e-afda-d6881831a9e6', N'Name', N'<name>', N'Provides the first directory or file name', NULL, 1, 0),
    ('6d6731ab-f47f-4fd6-b6e9-8d9a69711a6a', 'c810abaf-010a-426e-afda-d6881831a9e6', N'RestOfPath', N'<path-tail>', N'Provides the optional remainder of the path hierarchy', NULL, 0, 1),
    ('18ee327e-0f41-406b-bfac-b99904739e82', '197c9963-55d3-4d80-9e39-23f30bf6c57e', N'NameChars', N'list(<namechar>)', N'Provides the ordered characters composing the name', NULL, 1, 0),
    ('32318390-c6ac-4f58-ba39-b542d1b3dd87', 'fa3311ee-3e7c-415a-9eb6-b458c793a675', N'Character', N'char', N'Provides the single path character to validate and render', NULL, 1, 0),
    ('6847251f-24e9-453c-8848-5d43cc529dcf', '520ade57-f639-45e1-b7de-e5dc3142655c', N'ServerIdentifier', N'<name>|IPAddressString', N'Provides the server name or IP address', NULL, 1, 0),
    ('1b3ca37b-f095-47e7-9f96-8dd5f4735079', '9b2a48bc-7c85-48cd-ac0d-a09d4b621b0a', N'ShareName', N'<name>', N'Provides the shared resource name', NULL, 1, 0),
    ('ff932d94-61a4-4274-99a7-84229acbfb5b', '9c8077ce-7abf-4d9a-969b-75631589a220', N'LetterChar', N'char', N'Provides one alphabetic character from A through Z or a through z', NULL, 1, 0);

IF EXISTS (
    SELECT
        TRY_CONVERT(uniqueidentifier, source.RulePrimitiveInputId),
        TRY_CONVERT(uniqueidentifier, source.RulePrimitiveId),
        source.InputName,
        source.InputType,
        source.InputDescription,
        NULLIF(source.DefaultValue, N''),
        TRY_CONVERT(bit, source.IsRequired),
        TRY_CONVERT(int, source.Ordinal)
    FROM #RulePrimitiveInputSeed AS source
    EXCEPT
    SELECT
        approved.RulePrimitiveInputId,
        approved.RulePrimitiveId,
        approved.InputName,
        approved.InputType,
        approved.InputDescription,
        approved.DefaultValue,
        approved.IsRequired,
        approved.Ordinal
    FROM @ApprovedSeed AS approved
) OR EXISTS (
    SELECT
        approved.RulePrimitiveInputId,
        approved.RulePrimitiveId,
        approved.InputName,
        approved.InputType,
        approved.InputDescription,
        approved.DefaultValue,
        approved.IsRequired,
        approved.Ordinal
    FROM @ApprovedSeed AS approved
    EXCEPT
    SELECT
        TRY_CONVERT(uniqueidentifier, source.RulePrimitiveInputId),
        TRY_CONVERT(uniqueidentifier, source.RulePrimitiveId),
        source.InputName,
        source.InputType,
        source.InputDescription,
        NULLIF(source.DefaultValue, N''),
        TRY_CONVERT(bit, source.IsRequired),
        TRY_CONVERT(int, source.Ordinal)
    FROM #RulePrimitiveInputSeed AS source
)
    THROW 53609, 'V3 RulePrimitiveInput loader aborted: RulePrimitiveInput.csv differs from the exact approved declaration contract.', 1;

DECLARE @ApprovedParent TABLE (
    RulePrimitiveId uniqueidentifier NOT NULL PRIMARY KEY,
    RulePrimitiveCode nvarchar(128) NOT NULL UNIQUE,
    ExpectedInputCount int NOT NULL
);

INSERT INTO @ApprovedParent (RulePrimitiveId, RulePrimitiveCode, ExpectedInputCount)
VALUES
    ('36696ed7-e4f2-4305-b83e-5deaddd4a279', N'<path>', 2),
    ('8263f648-2607-452e-ad69-5e4566354cc9', N'<unc-path>', 3),
    ('f8a27327-cb7a-46f4-bc53-5a2a9945784d', N'<absolute-path>', 2),
    ('03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a', N'<relative-path>', 1),
    ('9c967a82-098f-4a38-bac5-2be34529ed54', N'<extended-path>', 5),
    ('250e84cb-abd3-4823-875d-e0e75d88cee3', N'<drive>', 1),
    ('c810abaf-010a-426e-afda-d6881831a9e6', N'<path-tail>', 2),
    ('197c9963-55d3-4d80-9e39-23f30bf6c57e', N'<name>', 1),
    ('fa3311ee-3e7c-415a-9eb6-b458c793a675', N'<namechar>', 1),
    ('520ade57-f639-45e1-b7de-e5dc3142655c', N'<server>', 1),
    ('9b2a48bc-7c85-48cd-ac0d-a09d4b621b0a', N'<share>', 1),
    ('9c8077ce-7abf-4d9a-969b-75631589a220', N'<letter>', 1);

IF EXISTS (
    SELECT approved.RulePrimitiveId
    FROM @ApprovedParent AS approved
    LEFT JOIN ATAPUtilities.RulePrimitive AS parent
      ON parent.RulePrimitiveId = approved.RulePrimitiveId
     AND parent.PhiloteId = approved.RulePrimitiveId
     AND parent.RuleKindId = 'b32c60e0-86f3-40e6-893e-d3240ffea882'
     AND parent.RulePrimitiveCode = approved.RulePrimitiveCode
    WHERE parent.RulePrimitiveId IS NULL
)
    THROW 53610, 'V3 RulePrimitiveInput loader aborted: a structured Path parent is missing or mismatched.', 1;

IF EXISTS (
    SELECT approved.RulePrimitiveId
    FROM @ApprovedParent AS approved
    LEFT JOIN (
        SELECT seed.RulePrimitiveId, COUNT_BIG(*) AS InputCount
        FROM @ApprovedSeed AS seed
        GROUP BY seed.RulePrimitiveId
    ) AS actual
      ON actual.RulePrimitiveId = approved.RulePrimitiveId
    WHERE COALESCE(actual.InputCount, 0) <> approved.ExpectedInputCount
)
    THROW 53611, 'V3 RulePrimitiveInput loader aborted: the approved per-primitive input cardinality is invalid.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ExistingInputCount bigint = (
        SELECT COUNT_BIG(*)
        FROM ATAPUtilities.RulePrimitiveInput
    );

    IF @ExistingInputCount NOT IN (0, 21)
        THROW 53612, 'V3 RulePrimitiveInput loader aborted: target state is neither empty nor the exact approved 21-row seed.', 1;

    IF @ExistingInputCount = 21
       AND (
            EXISTS (
                SELECT
                    target.RulePrimitiveInputId,
                    target.RulePrimitiveId,
                    target.InputName,
                    target.InputType,
                    target.InputDescription,
                    target.DefaultValue,
                    target.IsRequired,
                    target.Ordinal
                FROM ATAPUtilities.RulePrimitiveInput AS target
                EXCEPT
                SELECT
                    approved.RulePrimitiveInputId,
                    approved.RulePrimitiveId,
                    approved.InputName,
                    approved.InputType,
                    approved.InputDescription,
                    approved.DefaultValue,
                    approved.IsRequired,
                    approved.Ordinal
                FROM @ApprovedSeed AS approved
            )
            OR EXISTS (
                SELECT
                    approved.RulePrimitiveInputId,
                    approved.RulePrimitiveId,
                    approved.InputName,
                    approved.InputType,
                    approved.InputDescription,
                    approved.DefaultValue,
                    approved.IsRequired,
                    approved.Ordinal
                FROM @ApprovedSeed AS approved
                EXCEPT
                SELECT
                    target.RulePrimitiveInputId,
                    target.RulePrimitiveId,
                    target.InputName,
                    target.InputType,
                    target.InputDescription,
                    target.DefaultValue,
                    target.IsRequired,
                    target.Ordinal
                FROM ATAPUtilities.RulePrimitiveInput AS target
            )
       )
        THROW 53613, 'V3 RulePrimitiveInput loader aborted: existing target rows differ from the exact approved seed.', 1;

    IF @ExistingInputCount = 0
    BEGIN
        INSERT INTO ATAPUtilities.RulePrimitiveInput (
            RulePrimitiveInputId,
            RulePrimitiveId,
            InputName,
            InputType,
            InputDescription,
            DefaultValue,
            IsRequired,
            Ordinal
        )
        SELECT
            approved.RulePrimitiveInputId,
            approved.RulePrimitiveId,
            approved.InputName,
            approved.InputType,
            approved.InputDescription,
            approved.DefaultValue,
            approved.IsRequired,
            approved.Ordinal
        FROM @ApprovedSeed AS approved;
    END;

    IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.RulePrimitiveInput) <> 21
       OR EXISTS (
            SELECT 1
            FROM ATAPUtilities.RulePrimitiveInput AS target
            WHERE target.RulePrimitiveId IN (
                '9460f2f5-9957-4455-b6a6-8ee241b7ebb3',
                'ff659102-d147-4f1d-bd31-21978858e5fb',
                '8c3d6e7f-5a4b-4c9d-0e12-3c4d5e6f7081'
            )
       )
        THROW 53614, 'V3 RulePrimitiveInput loader aborted: target postcondition violates approved input cardinality or zero-input primitives.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

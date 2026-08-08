-- Loads the exact approved RPRRSBSI V3 Philote registry from Philote.csv.
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'ATAPUtilities.Philote', N'U') IS NULL
    THROW 53200, 'V3 Philote loader aborted: ATAPUtilities.Philote does not exist.', 1;

DECLARE @ExpectedHeader nvarchar(128) = N'PhiloteId,AdditionalIdsStub';
DECLARE @SourceFile nvarchar(max);

SELECT @SourceFile = SourceFile.BulkColumn
FROM OPENROWSET(
    BULK '${data_dir}\Philote.csv',
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
    THROW 53201, 'V3 Philote loader aborted: Philote.csv header is not exactly PhiloteId,AdditionalIdsStub.', 1;

CREATE TABLE #PhiloteSeed (
    PhiloteId nvarchar(50) NULL,
    AdditionalIdsStub nvarchar(max) NULL
);

BULK INSERT #PhiloteSeed
FROM '${data_dir}\Philote.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    CODEPAGE = '65001',
    TABLOCK
);

IF (SELECT COUNT_BIG(*) FROM #PhiloteSeed) <> 22
    THROW 53202, 'V3 Philote loader aborted: Philote.csv must contain exactly 22 data rows.', 1;

IF EXISTS (
    SELECT 1
    FROM #PhiloteSeed AS source
    WHERE source.PhiloteId IS NULL
       OR TRY_CONVERT(uniqueidentifier, source.PhiloteId) IS NULL
       OR source.PhiloteId <> LOWER(CONVERT(nvarchar(36), TRY_CONVERT(uniqueidentifier, source.PhiloteId)))
)
    THROW 53203, 'V3 Philote loader aborted: every PhiloteId must be a canonical lowercase GUID.', 1;

IF EXISTS (
    SELECT source.PhiloteId
    FROM #PhiloteSeed AS source
    GROUP BY source.PhiloteId
    HAVING COUNT_BIG(*) <> 1
)
    THROW 53204, 'V3 Philote loader aborted: Philote.csv contains a duplicate PhiloteId.', 1;

IF EXISTS (
    SELECT 1
    FROM #PhiloteSeed AS source
    WHERE COALESCE(source.AdditionalIdsStub, N'') <> N''
)
    THROW 53205, 'V3 Philote loader aborted: every AdditionalIdsStub source value must be empty and seed as null.', 1;

DECLARE @ApprovedPhilote TABLE (
    PhiloteId uniqueidentifier NOT NULL PRIMARY KEY
);

INSERT INTO @ApprovedPhilote (PhiloteId)
VALUES
    ('8e06f2af-52cf-47d5-872e-0d3912f4fda0'),
    ('b32c60e0-86f3-40e6-893e-d3240ffea882'),
    ('9460f2f5-9957-4455-b6a6-8ee241b7ebb3'),
    ('ff659102-d147-4f1d-bd31-21978858e5fb'),
    ('36696ed7-e4f2-4305-b83e-5deaddd4a279'),
    ('8263f648-2607-452e-ad69-5e4566354cc9'),
    ('f8a27327-cb7a-46f4-bc53-5a2a9945784d'),
    ('03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a'),
    ('9c967a82-098f-4a38-bac5-2be34529ed54'),
    ('250e84cb-abd3-4823-875d-e0e75d88cee3'),
    ('c810abaf-010a-426e-afda-d6881831a9e6'),
    ('197c9963-55d3-4d80-9e39-23f30bf6c57e'),
    ('fa3311ee-3e7c-415a-9eb6-b458c793a675'),
    ('520ade57-f639-45e1-b7de-e5dc3142655c'),
    ('9b2a48bc-7c85-48cd-ac0d-a09d4b621b0a'),
    ('9c8077ce-7abf-4d9a-969b-75631589a220'),
    ('8c3d6e7f-5a4b-4c9d-0e12-3c4d5e6f7081'),
    ('616fb394-0b4d-486a-98af-48f1fe461af2'),
    ('c5c1c63a-4364-4233-9aa1-2a1a5a2ba1f3'),
    ('23ad4f37-2c70-4f34-9104-9868ec0f3823'),
    ('550e7722-cb57-4e47-a94b-9212b451d6fb'),
    ('03e28494-998f-4fc2-ba5d-ad6e5832c8b7');

IF EXISTS (
    SELECT TRY_CONVERT(uniqueidentifier, source.PhiloteId)
    FROM #PhiloteSeed AS source
    EXCEPT
    SELECT approved.PhiloteId
    FROM @ApprovedPhilote AS approved
) OR EXISTS (
    SELECT approved.PhiloteId
    FROM @ApprovedPhilote AS approved
    EXCEPT
    SELECT TRY_CONVERT(uniqueidentifier, source.PhiloteId)
    FROM #PhiloteSeed AS source
)
    THROW 53206, 'V3 Philote loader aborted: Philote.csv differs from the approved GUID registry.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ExistingPhiloteCount bigint = (
        SELECT COUNT_BIG(*)
        FROM ATAPUtilities.Philote
    );

    IF @ExistingPhiloteCount NOT IN (0, 22)
        THROW 53207, 'V3 Philote loader aborted: target Philote state is neither empty nor the exact approved registry.', 1;

    IF @ExistingPhiloteCount = 22
       AND (
            EXISTS (
                SELECT target.PhiloteId
                FROM ATAPUtilities.Philote AS target
                EXCEPT
                SELECT approved.PhiloteId
                FROM @ApprovedPhilote AS approved
            )
            OR EXISTS (
                SELECT approved.PhiloteId
                FROM @ApprovedPhilote AS approved
                EXCEPT
                SELECT target.PhiloteId
                FROM ATAPUtilities.Philote AS target
            )
            OR EXISTS (
                SELECT 1
                FROM ATAPUtilities.Philote AS target
                WHERE target.AdditionalIdsStub IS NOT NULL
            )
       )
        THROW 53208, 'V3 Philote loader aborted: existing target rows differ from the exact approved null-stub registry.', 1;

    IF @ExistingPhiloteCount = 0
    BEGIN
        INSERT INTO ATAPUtilities.Philote (PhiloteId, AdditionalIdsStub)
        SELECT
            TRY_CONVERT(uniqueidentifier, source.PhiloteId),
            NULL
        FROM #PhiloteSeed AS source;
    END;

    IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.Philote) <> 22
       OR EXISTS (
            SELECT 1
            FROM ATAPUtilities.Philote AS target
            WHERE target.AdditionalIdsStub IS NOT NULL
       )
        THROW 53209, 'V3 Philote loader aborted: target postcondition is not exactly 22 null-stub rows.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

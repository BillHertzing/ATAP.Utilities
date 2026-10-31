/*
  Immutable exact-catalog successor of the accepted Decrypt103 fixture.
  Source only; execution requires separate authorization on a disposable copy.
  The runner binds ATAP.AceCommander.Fixture.ExpectedCatalog read-only on one
  fresh dedicated verifier session. Run this file parameterless before and after
  V00170 on that same session; do not wrap its temp-table captures in an RPC.
  Only header/catalog guard differ from the historical fixture. All preservation,
  history and rollback-only synthetic decrypt assertions remain unchanged.
*/
SET NOCOUNT ON;

DECLARE @FixtureCatalogValue sql_variant = SESSION_CONTEXT(N'ATAP.AceCommander.Fixture.ExpectedCatalog');
IF @FixtureCatalogValue IS NULL
   OR ISNULL(CONVERT(nvarchar(128), SQL_VARIANT_PROPERTY(@FixtureCatalogValue, 'BaseType')), N'') <> N'nvarchar'
    THROW 61900, N'An explicit nvarchar fixture catalog binding is required.', 1;
DECLARE @FixtureExpectedCatalog nvarchar(4000) = CONVERT(nvarchar(4000), @FixtureCatalogValue);
IF DB_NAME() IS NULL OR DATALENGTH(@FixtureExpectedCatalog) = 0
   OR DB_NAME() COLLATE Latin1_General_100_BIN2 <> @FixtureExpectedCatalog COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(DB_NAME()) <> DATALENGTH(@FixtureExpectedCatalog)
   OR SCHEMA_ID(N'ACE') IS NULL
    THROW 61900, N'The verifier requires its exact bound disposable catalog.', 1;
IF @@TRANCOUNT <> 0
    THROW 61901, N'Fixture requires a verifier connection without an existing transaction.', 1;
IF ISNULL(HAS_PERMS_BY_NAME(DB_NAME(), N'DATABASE', N'VIEW DEFINITION'), 0) <> 1
    THROW 61902, N'Fixture requires visible metadata.', 1;
IF OBJECT_ID(N'[dbo].[flyway_schema_history]', N'U') IS NULL
   OR OBJECT_ID(N'[ACE].[UserInformation]', N'U') IS NULL
    THROW 61903, N'Fixture prerequisites are missing.', 1;
IF (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history] WHERE [version] = N'00160') <> 1
   OR (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history]
       WHERE [version] = N'00160'
         AND [script] = N'V00160__Create_AceCommander_Login_Schema_And_Guest.sql'
         AND [success] = 1) <> 1
    THROW 61904, N'Fixture requires successful V00160.', 1;

IF OBJECT_ID(N'tempdb..#Decrypt103_BeforeObjects') IS NULL
BEGIN
    IF OBJECT_ID(N'[ACE].[usp_GetDecryptedUserInformation]') IS NOT NULL
       OR EXISTS (SELECT 1 FROM [dbo].[flyway_schema_history] WHERE [version] = N'00170')
        THROW 61905, N'Before-state already contains the decrypt target or its history.', 1;
    IF EXISTS (SELECT 1 FROM sys.sql_modules WHERE [definition] IS NULL)
        THROW 61906, N'Hidden or encrypted module prevents preservation comparison.', 1;

    SELECT o.object_id, o.schema_id, o.[name], o.[type],
           HASHBYTES('SHA2_256', CONVERT(varbinary(max), OBJECT_DEFINITION(o.object_id))) AS DefinitionHash
    INTO #Decrypt103_BeforeObjects
    FROM sys.objects AS o WHERE o.is_ms_shipped = 0;

    SELECT c.object_id, c.column_id, c.[name], c.user_type_id,
           c.max_length, c.[precision], c.scale, c.is_nullable,
           c.is_identity, c.is_computed, c.collation_name, c.default_object_id
    INTO #Decrypt103_BeforeColumns
    FROM sys.columns AS c JOIN sys.tables AS t ON t.object_id = c.object_id
    WHERE t.is_ms_shipped = 0;

    SELECT [installed_rank], [version], [script], [checksum], [success]
    INTO #Decrypt103_BeforeHistory FROM [dbo].[flyway_schema_history];

    SELECT N'BeforeCaptured' AS FixturePhase;
    RETURN;
END;

IF EXISTS
(
    SELECT 1 FROM #Decrypt103_BeforeObjects AS b
    LEFT JOIN sys.objects AS o ON o.object_id = b.object_id
    WHERE o.object_id IS NULL OR o.schema_id <> b.schema_id OR o.[name] <> b.[name] OR o.[type] <> b.[type]
       OR ISNULL(HASHBYTES('SHA2_256', CONVERT(varbinary(max), OBJECT_DEFINITION(o.object_id))), 0x)
          <> ISNULL(b.DefinitionHash, 0x)
)
    THROW 61907, N'A retained object or definition changed.', 1;
IF EXISTS
(
    SELECT * FROM #Decrypt103_BeforeColumns
    EXCEPT
    SELECT c.object_id, c.column_id, c.[name], c.user_type_id,
           c.max_length, c.[precision], c.scale, c.is_nullable,
           c.is_identity, c.is_computed, c.collation_name, c.default_object_id
    FROM sys.columns AS c
    WHERE c.object_id IN (SELECT DISTINCT object_id FROM #Decrypt103_BeforeColumns)
)
OR EXISTS
(
    SELECT c.object_id, c.column_id, c.[name], c.user_type_id,
           c.max_length, c.[precision], c.scale, c.is_nullable,
           c.is_identity, c.is_computed, c.collation_name, c.default_object_id
    FROM sys.columns AS c
    WHERE c.object_id IN (SELECT DISTINCT object_id FROM #Decrypt103_BeforeColumns)
    EXCEPT SELECT * FROM #Decrypt103_BeforeColumns
)
    THROW 61908, N'A retained table column contract changed.', 1;
IF EXISTS
(
    SELECT * FROM #Decrypt103_BeforeHistory
    EXCEPT SELECT [installed_rank], [version], [script], [checksum], [success]
           FROM [dbo].[flyway_schema_history]
)
OR (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history])
   <> (SELECT COUNT_BIG(*) + 1 FROM #Decrypt103_BeforeHistory)
OR (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history]
    WHERE [version] = N'00170'
      AND [script] = N'V00170__Create_ACE_UserInformation_Decrypt_Procedure.sql'
      AND [success] = 1 AND [checksum] IS NOT NULL) <> 1
    THROW 61909, N'History preservation or successful V00170 differs.', 1;

DECLARE @ProcedureId int = OBJECT_ID(N'[ACE].[usp_GetDecryptedUserInformation]', N'P');
IF @ProcedureId IS NULL OR (SELECT COUNT_BIG(*) FROM sys.parameters WHERE object_id = @ProcedureId) <> 3
   OR NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = @ProcedureId AND parameter_id = 1
                  AND [name] = N'@UserId' AND TYPE_NAME(user_type_id) = N'uniqueidentifier' AND is_output = 0)
   OR NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = @ProcedureId AND parameter_id = 2
                  AND [name] = N'@Passphrase' AND TYPE_NAME(user_type_id) = N'nvarchar' AND max_length = 1000 AND is_output = 0)
   OR NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = @ProcedureId AND parameter_id = 3
                  AND [name] = N'@ExpectedEncryptionKeyVersion' AND TYPE_NAME(user_type_id) = N'tinyint' AND is_output = 0)
    THROW 61910, N'Decrypt procedure signature differs.', 1;
IF EXISTS
(
    SELECT o.object_id FROM sys.objects AS o
    WHERE o.is_ms_shipped = 0 AND o.object_id <> @ProcedureId
    EXCEPT SELECT object_id FROM #Decrypt103_BeforeObjects
)
    THROW 61911, N'An unexpected object was added.', 1;

-- Synthetic fixture constants, not operational secrets.
DECLARE @KeyV1 nvarchar(500) = N'Disposable fixture synthetic V1 passphrase';
DECLARE @KeyV2 nvarchar(500) = N'Disposable fixture synthetic V2 passphrase';
DECLARE @PhiloteV1 uniqueidentifier = NEWID(), @UserV1 uniqueidentifier = NEWID(),
        @PhiloteV2 uniqueidentifier = NEWID(), @UserV2 uniqueidentifier = NEWID(),
        @MissingProfile uniqueidentifier = NEWID();
DECLARE @Cases TABLE
(
    CaseId int PRIMARY KEY, CaseName nvarchar(80), UserId uniqueidentifier,
    Passphrase nvarchar(500), ExpectedVersion tinyint NULL,
    ExpectedError int NULL, CipherMutation tinyint NOT NULL
);
INSERT INTO @Cases VALUES
    (1, N'V1 and nullable fields', @UserV1, @KeyV1, 1, NULL, 0),
    (2, N'V2 and complementary nullable fields', @UserV2, @KeyV2, 2, NULL, 0),
    (3, N'Missing profile', @MissingProfile, @KeyV1, 1, NULL, 0),
    (4, N'Wrong key', @UserV1, @KeyV2, 1, 61813, 0),
    (5, N'Version mismatch before wrong-key decrypt', @UserV2, @KeyV1, 1, 61812, 0),
    (6, N'Unsupported expected version', @UserV1, @KeyV1, 3, 61810, 0),
    (7, N'Null expected version', @UserV1, @KeyV1, NULL, 61810, 0),
    (8, N'Null passphrase', @UserV1, NULL, 1, 61811, 0),
    (9, N'Empty passphrase', @UserV1, N'', 1, 61811, 0),
    (10, N'Unicode whitespace passphrase', @UserV1,
         NCHAR(9) + NCHAR(32) + NCHAR(160) + NCHAR(8195) + NCHAR(12288), 1, 61811, 0),
    (11, N'Corrupt nonnull ciphertext', @UserV1, @KeyV1, 1, 61813, 1),
    (12, N'Overlength decrypted field', @UserV1, @KeyV1, 1, 61813, 2),
    (13, N'Incomplete UTF16 code unit', @UserV1, @KeyV1, 1, 61813, 3);

DECLARE @Results TABLE
(
    UserId uniqueidentifier, FirstName nvarchar(200), LastName nvarchar(200),
    Email nvarchar(500), Phone nvarchar(50), Role nvarchar(200), EncryptionKeyVersion tinyint
);
DECLARE @CaseId int = 1, @Passed int = 0, @CaseUserId uniqueidentifier,
        @CasePassphrase nvarchar(500), @CaseVersion tinyint,
        @ExpectedError int, @ObservedError int, @Mutation tinyint;

WHILE @CaseId <= 13
BEGIN
    SELECT @CaseUserId = UserId, @CasePassphrase = Passphrase,
           @CaseVersion = ExpectedVersion, @ExpectedError = ExpectedError, @Mutation = CipherMutation
    FROM @Cases WHERE CaseId = @CaseId;
    DELETE FROM @Results;
    SET @ObservedError = NULL;
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId]) VALUES (@PhiloteV1), (@PhiloteV2);
        INSERT INTO [ACE].[User] ([PhiloteId], [UserId]) VALUES (@PhiloteV1, @UserV1), (@PhiloteV2, @UserV2);
        INSERT INTO [ACE].[UserInformation]
            ([UserId], [FirstName], [LastName], [Email], [Phone], [Role], [EncryptionKeyVersion])
        VALUES
            (@UserV1, ENCRYPTBYPASSPHRASE(@KeyV1, N'Fixture V1 given'), NULL,
             ENCRYPTBYPASSPHRASE(@KeyV1, N'v1@example.invalid'), NULL,
             ENCRYPTBYPASSPHRASE(@KeyV1, N'Synthetic V1 role'), 1),
            (@UserV2, NULL, ENCRYPTBYPASSPHRASE(@KeyV2, N'Fixture V2 family'), NULL,
             ENCRYPTBYPASSPHRASE(@KeyV2, N'+1-555-0102'), NULL, 2);

        IF @Mutation = 1
            UPDATE [ACE].[UserInformation] SET [FirstName] = 0x000102030405060708 WHERE [UserId] = @UserV1;
        IF @Mutation = 2
            UPDATE [ACE].[UserInformation] SET [FirstName] = ENCRYPTBYPASSPHRASE(@KeyV1, REPLICATE(N'x', 201))
            WHERE [UserId] = @UserV1;
        IF @Mutation = 3
            UPDATE [ACE].[UserInformation] SET [FirstName] = ENCRYPTBYPASSPHRASE(@KeyV1, 0x01)
            WHERE [UserId] = @UserV1;

        BEGIN TRY
            INSERT INTO @Results
            EXEC [ACE].[usp_GetDecryptedUserInformation]
                @UserId = @CaseUserId, @Passphrase = @CasePassphrase,
                @ExpectedEncryptionKeyVersion = @CaseVersion;
        END TRY
        BEGIN CATCH
            SET @ObservedError = ERROR_NUMBER();
        END CATCH;

        IF @ExpectedError IS NOT NULL
        BEGIN
            IF @ObservedError IS NULL OR @ObservedError <> @ExpectedError OR EXISTS (SELECT 1 FROM @Results)
                THROW 61912, N'Expected safe failure or empty failure result differs.', 1;
        END
        ELSE
        BEGIN
            IF @ObservedError IS NOT NULL
                THROW 61913, N'Expected successful profile result failed.', 1;
            IF @CaseId = 1 AND ((SELECT COUNT_BIG(*) FROM @Results) <> 1 OR NOT EXISTS
                (SELECT 1 FROM @Results WHERE UserId = @UserV1 AND FirstName = N'Fixture V1 given'
                 AND LastName IS NULL AND Email = N'v1@example.invalid' AND Phone IS NULL
                 AND Role = N'Synthetic V1 role' AND EncryptionKeyVersion = 1))
                THROW 61914, N'V1 result or nullable fields differ.', 1;
            IF @CaseId = 2 AND ((SELECT COUNT_BIG(*) FROM @Results) <> 1 OR NOT EXISTS
                (SELECT 1 FROM @Results WHERE UserId = @UserV2 AND FirstName IS NULL
                 AND LastName = N'Fixture V2 family' AND Email IS NULL AND Phone = N'+1-555-0102'
                 AND Role IS NULL AND EncryptionKeyVersion = 2))
                THROW 61915, N'V2 result or nullable fields differ.', 1;
            IF @CaseId = 3 AND EXISTS (SELECT 1 FROM @Results)
                THROW 61916, N'Missing profile returned a row.', 1;
        END;

        -- A THROW may doom this test's transaction; roll it back before the next case.
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Philote] WHERE PhiloteId IN (@PhiloteV1, @PhiloteV2))
           OR EXISTS (SELECT 1 FROM [ACE].[User] WHERE UserId IN (@UserV1, @UserV2))
           OR EXISTS (SELECT 1 FROM [ACE].[UserInformation] WHERE UserId IN (@UserV1, @UserV2))
            THROW 61917, N'Synthetic case rows were not rolled back.', 1;
        SET @Passed += 1;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW 61999, N'Disposable decrypt fixture failed; no sensitive result is emitted.', 1;
    END CATCH;
    SET @CaseId += 1;
END;

SELECT N'AfterAssertionsPassed' AS FixturePhase, @Passed AS SyntheticCasesPassed;

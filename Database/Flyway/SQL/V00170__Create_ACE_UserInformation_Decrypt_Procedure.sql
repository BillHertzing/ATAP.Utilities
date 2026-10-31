/*
  Source-only additive V00170; no execution is authorized by this file.
  Requires the existing ATAPUtilities.ACE login schema and successful V00160.
  The version/script/success guard makes no claim about actual applied status.
  V00160 and every preexisting object remain unchanged; no grants are added.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @RequiredCatalog nvarchar(128) = N'${atap_required_catalog}';
    IF @RequiredCatalog IS NULL OR DATALENGTH(@RequiredCatalog) = 0
       OR DB_NAME() IS NULL
       OR DB_NAME() COLLATE Latin1_General_100_BIN2 <> @RequiredCatalog COLLATE Latin1_General_100_BIN2
       OR DATALENGTH(DB_NAME()) <> DATALENGTH(@RequiredCatalog)
        THROW 61800, N'Exact approved catalog binding required.', 1;
    IF SCHEMA_ID(N'ACE') IS NULL
        THROW 61801, N'V00170 requires the existing ACE schema.', 1;
    IF OBJECT_ID(N'[dbo].[flyway_schema_history]', N'U') IS NULL
        THROW 61802, N'V00170 requires the bound existing history table.', 1;
    IF (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history]
        WHERE [version] = N'00160') <> 1
       OR (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history]
           WHERE [version] = N'00160'
             AND [script] = N'V00160__Create_AceCommander_Login_Schema_And_Guest.sql'
             AND [success] = 1) <> 1
        THROW 61803, N'V00170 requires the successful V00160 predecessor.', 1;
    IF OBJECT_ID(N'[ACE].[UserInformation]', N'U') IS NULL
        THROW 61804, N'V00170 requires the existing login profile table.', 1;
    IF OBJECT_ID(N'[ACE].[usp_GetDecryptedUserInformation]') IS NOT NULL
        THROW 61805, N'Existing decrypt target requires explicit disposition.', 1;
    IF EXISTS (SELECT 1 FROM [dbo].[flyway_schema_history] WHERE [version] = N'00170')
        THROW 61806, N'Existing V00170 history requires explicit disposition.', 1;

    DECLARE @ProcedureSql nvarchar(max) = N'CREATE PROCEDURE [ACE].[usp_GetDecryptedUserInformation]
    @UserId uniqueidentifier,
    @Passphrase nvarchar(500),
    @ExpectedEncryptionKeyVersion tinyint
AS
BEGIN
    SET NOCOUNT ON;

    IF @ExpectedEncryptionKeyVersion IS NULL
       OR @ExpectedEncryptionKeyVersion NOT IN (1, 2)
        THROW 61810, N''Unsupported profile encryption version.'', 1;

    -- Unicode White_Space code points; validate without trimming a valid key.
    DECLARE @Whitespace nvarchar(25) =
        NCHAR(9) + NCHAR(10) + NCHAR(11) + NCHAR(12) + NCHAR(13) + NCHAR(32)
        + NCHAR(133) + NCHAR(160) + NCHAR(5760)
        + NCHAR(8192) + NCHAR(8193) + NCHAR(8194) + NCHAR(8195) + NCHAR(8196)
        + NCHAR(8197) + NCHAR(8198) + NCHAR(8199) + NCHAR(8200) + NCHAR(8201) + NCHAR(8202)
        + NCHAR(8232) + NCHAR(8233) + NCHAR(8239) + NCHAR(8287) + NCHAR(12288);
    IF @Passphrase IS NULL
       OR LEN(TRANSLATE(@Passphrase COLLATE Latin1_General_100_BIN2,
                        @Whitespace, REPLICATE(N'' '', 25))) = 0
        THROW 61811, N''Profile decryption key is unavailable.'', 1;

    DECLARE @CapturedUserId uniqueidentifier, @StoredVersion tinyint;
    DECLARE @FirstNameCipher varbinary(max), @LastNameCipher varbinary(max),
            @EmailCipher varbinary(max), @PhoneCipher varbinary(max), @RoleCipher varbinary(max);
    DECLARE @FirstNamePlain varbinary(max), @LastNamePlain varbinary(max),
            @EmailPlain varbinary(max), @PhonePlain varbinary(max), @RolePlain varbinary(max);
    DECLARE @FirstNameResult nvarchar(200), @LastNameResult nvarchar(200),
            @EmailResult nvarchar(500), @PhoneResult nvarchar(50), @RoleResult nvarchar(200);

    -- One table read captures the complete selected profile; never re-read fields.
    SELECT @CapturedUserId = p.[UserId], @StoredVersion = p.[EncryptionKeyVersion],
           @FirstNameCipher = p.[FirstName], @LastNameCipher = p.[LastName],
           @EmailCipher = p.[Email], @PhoneCipher = p.[Phone], @RoleCipher = p.[Role]
    FROM [ACE].[UserInformation] AS p
    WHERE p.[UserId] = @UserId;
    DECLARE @CapturedRows int = @@ROWCOUNT;

    IF @CapturedRows > 1
        THROW 61813, N''Profile decryption failed.'', 1;

    IF @CapturedRows = 1
    BEGIN
        IF @StoredVersion IS NULL OR @StoredVersion NOT IN (1, 2)
           OR @StoredVersion <> @ExpectedEncryptionKeyVersion
            THROW 61812, N''Profile encryption version changed or is unsupported.'', 1;

        BEGIN TRY
            SET @FirstNamePlain = DECRYPTBYPASSPHRASE(@Passphrase, @FirstNameCipher);
            SET @LastNamePlain = DECRYPTBYPASSPHRASE(@Passphrase, @LastNameCipher);
            SET @EmailPlain = DECRYPTBYPASSPHRASE(@Passphrase, @EmailCipher);
            SET @PhonePlain = DECRYPTBYPASSPHRASE(@Passphrase, @PhoneCipher);
            SET @RolePlain = DECRYPTBYPASSPHRASE(@Passphrase, @RoleCipher);

            IF (@FirstNameCipher IS NOT NULL AND @FirstNamePlain IS NULL)
               OR (@LastNameCipher IS NOT NULL AND @LastNamePlain IS NULL)
               OR (@EmailCipher IS NOT NULL AND @EmailPlain IS NULL)
               OR (@PhoneCipher IS NOT NULL AND @PhonePlain IS NULL)
               OR (@RoleCipher IS NOT NULL AND @RolePlain IS NULL)
                THROW 61813, N''Profile decryption failed.'', 1;

            -- Do not silently truncate or accept an incomplete UTF-16 code unit.
            IF DATALENGTH(@FirstNamePlain) > 400 OR DATALENGTH(@FirstNamePlain) % 2 <> 0
               OR DATALENGTH(@LastNamePlain) > 400 OR DATALENGTH(@LastNamePlain) % 2 <> 0
               OR DATALENGTH(@EmailPlain) > 1000 OR DATALENGTH(@EmailPlain) % 2 <> 0
               OR DATALENGTH(@PhonePlain) > 100 OR DATALENGTH(@PhonePlain) % 2 <> 0
               OR DATALENGTH(@RolePlain) > 400 OR DATALENGTH(@RolePlain) % 2 <> 0
                THROW 61813, N''Profile decryption failed.'', 1;

            SELECT @FirstNameResult = CONVERT(nvarchar(200), @FirstNamePlain),
                   @LastNameResult = CONVERT(nvarchar(200), @LastNamePlain),
                   @EmailResult = CONVERT(nvarchar(500), @EmailPlain),
                   @PhoneResult = CONVERT(nvarchar(50), @PhonePlain),
                   @RoleResult = CONVERT(nvarchar(200), @RolePlain);
        END TRY
        BEGIN CATCH
            -- No raw crypto/conversion exception, key, ciphertext or plaintext.
            THROW 61813, N''Profile decryption failed.'', 1;
        END CATCH;
    END;

    -- Typed empty rowset for missing profiles; no partial plaintext result.
    SELECT @CapturedUserId AS [UserId],
           @FirstNameResult AS [FirstName],
           @LastNameResult AS [LastName],
           @EmailResult AS [Email],
           @PhoneResult AS [Phone],
           @RoleResult AS [Role],
           @StoredVersion AS [EncryptionKeyVersion]
    WHERE @CapturedRows = 1;
END;';
    EXEC sys.sp_executesql @ProcedureSql;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

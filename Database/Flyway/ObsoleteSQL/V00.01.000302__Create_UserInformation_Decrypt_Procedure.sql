-- =====================================================================
-- V00.01.000302__Create_UserInformation_Decrypt_Procedure.sql
--
-- Creates ATAPUtilities.usp_GetDecryptedUserInformation
--
-- Purpose:
--   Decrypts PII columns in UserInformation for a given user.
--   SQL Server ENCRYPTBYPASSPHRASE uses proprietary Triple-DES;
--   DECRYPTBYPASSPHRASE must be called in SQL — there is no .NET
--   equivalent.  The calling application supplies the passphrase
--   (loaded from env var UserPii__PassphraseV1 → IConfiguration
--   key UserPii:PassphraseV1).
--
-- Parameters:
--   @UserId     — the user whose PII to return
--   @Passphrase — the passphrase used at encryption time
--                 (matches the Flyway placeholder ${user_pii_passphrase})
--
-- Returns:
--   Single row: UserId, FirstName, LastName, Email, Phone, Role
--               (all plaintext NVARCHAR), EncryptionKeyVersion (TINYINT).
--   Returns no rows if UserId does not exist.
--   Returns NULL for any column that was stored as NULL ciphertext.
-- =====================================================================
USE ATAPUtilities;
GO

CREATE OR ALTER PROCEDURE ATAPUtilities.usp_GetDecryptedUserInformation
    @UserId     UNIQUEIDENTIFIER,
    @Passphrase NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        UserId,
        CAST(DECRYPTBYPASSPHRASE(@Passphrase, FirstName) AS NVARCHAR(200)) AS FirstName,
        CAST(DECRYPTBYPASSPHRASE(@Passphrase, LastName)  AS NVARCHAR(200)) AS LastName,
        CAST(DECRYPTBYPASSPHRASE(@Passphrase, Email)     AS NVARCHAR(500)) AS Email,
        CAST(DECRYPTBYPASSPHRASE(@Passphrase, Phone)     AS NVARCHAR(50))  AS Phone,
        CAST(DECRYPTBYPASSPHRASE(@Passphrase, Role)      AS NVARCHAR(200)) AS Role,
        EncryptionKeyVersion
    FROM ATAPUtilities.UserInformation
    WHERE UserId = @UserId;
END;
GO

-- =====================================================================
-- V00.01.000030__Load_ATAPUtilities_User_From_CSV.sql
--
-- Loads User, UserInformation, and UserSettings data from CSV files.
-- PII columns (FirstName, LastName, Email, Phone, Role) are encrypted
-- at load time using ENCRYPTBYPASSPHRASE with the Flyway placeholder
-- ${user_pii_passphrase}.  At query time use:
--   CAST(DECRYPTBYPASSPHRASE(N'<passphrase>', col) AS NVARCHAR(MAX))
-- =====================================================================
-- User_Users.csv            : PhiloteId, UserId, Comment
-- User_UserInformation.csv  : UserId, FirstName, LastName, Email, Phone, Role
-- User_UserSettings.csv     : UserId, Theme, DarkMode, OverlayColor
-- =====================================================================
SET XACT_ABORT ON;
SET NOCOUNT ON;

-- -----------------------------------------------------------------
-- Staging tables  (columns match CSV headers; dropped at end)
-- -----------------------------------------------------------------
CREATE TABLE ATAPUtilities._stg_User_Users (
    PhiloteId NVARCHAR(50)  NOT NULL,
    UserId    NVARCHAR(50)  NOT NULL,
    EmailHash NVARCHAR(64)      NULL,
    Comment   NVARCHAR(500)     NULL
);

CREATE TABLE ATAPUtilities._stg_User_UserInformation (
    UserId    NVARCHAR(50)  NOT NULL,
    FirstName NVARCHAR(200)     NULL,
    LastName  NVARCHAR(200)     NULL,
    Email     NVARCHAR(500)     NULL,
    Phone     NVARCHAR(50)      NULL,
    Role      NVARCHAR(200)     NULL
);

CREATE TABLE ATAPUtilities._stg_User_UserSettings (
    UserId       NVARCHAR(50)  NOT NULL,
    Theme        NVARCHAR(200)     NULL,
    DarkMode     NVARCHAR(5)       NULL,
    OverlayColor NVARCHAR(200)     NULL
);

-- -----------------------------------------------------------------
-- BULK LOAD staging tables
-- -----------------------------------------------------------------
BULK INSERT ATAPUtilities._stg_User_Users
FROM '${data_dir}\User_Users.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

BULK INSERT ATAPUtilities._stg_User_UserInformation
FROM '${data_dir}\User_UserInformation.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

BULK INSERT ATAPUtilities._stg_User_UserSettings
FROM '${data_dir}\User_UserSettings.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

-- -----------------------------------------------------------------
-- 1. Seed ATAPUtilities.Philote for every User PhiloteId
-- -----------------------------------------------------------------
INSERT INTO ATAPUtilities.Philote (PhiloteId)
SELECT DISTINCT
    TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId)))
FROM  ATAPUtilities._stg_User_Users AS s
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId))) IS NOT NULL
  AND NOT EXISTS (
          SELECT 1
          FROM   ATAPUtilities.Philote AS p
          WHERE  p.PhiloteId = TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId)))
      );

-- -----------------------------------------------------------------
-- 2. Insert User rows
-- -----------------------------------------------------------------
INSERT INTO ATAPUtilities.[User] (PhiloteId, UserId, EmailHash, HashAlgorithmName)
SELECT
    TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId))),
    TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.UserId))),
    NULLIF(LTRIM(RTRIM(s.EmailHash)), N''),
    N'Argon2id'
FROM  ATAPUtilities._stg_User_Users AS s
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId))) IS NOT NULL
  AND TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.UserId)))    IS NOT NULL
  AND NOT EXISTS (
          SELECT 1
          FROM   ATAPUtilities.[User] AS u
          WHERE  u.PhiloteId = TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId)))
      );

-- -----------------------------------------------------------------
-- 3. Insert UserInformation rows
--    Empty-string columns are coerced to NULL via NULLIF, then
--    non-NULL values are encrypted with ENCRYPTBYPASSPHRASE so
--    ciphertext (VARBINARY) is stored in the table.
--    ENCRYPTBYPASSPHRASE propagates NULL input as NULL output,
--    which correctly satisfies CK_UserInformation_EmailOrPhone.
-- -----------------------------------------------------------------
INSERT INTO ATAPUtilities.UserInformation (UserId, FirstName, LastName, Email, Phone, Role, EncryptionKeyVersion)
SELECT
    TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.UserId))),
    ENCRYPTBYPASSPHRASE(N'${user_pii_passphrase}', NULLIF(LTRIM(RTRIM(s.FirstName)), N'')),
    ENCRYPTBYPASSPHRASE(N'${user_pii_passphrase}', NULLIF(LTRIM(RTRIM(s.LastName)),  N'')),
    ENCRYPTBYPASSPHRASE(N'${user_pii_passphrase}', NULLIF(LTRIM(RTRIM(s.Email)),     N'')),
    ENCRYPTBYPASSPHRASE(N'${user_pii_passphrase}', NULLIF(LTRIM(RTRIM(s.Phone)),     N'')),
    ENCRYPTBYPASSPHRASE(N'${user_pii_passphrase}', NULLIF(LTRIM(RTRIM(s.Role)),      N'')),
    1
FROM  ATAPUtilities._stg_User_UserInformation AS s
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.UserId))) IS NOT NULL
  AND NOT EXISTS (
          SELECT 1
          FROM   ATAPUtilities.UserInformation AS ui
          WHERE  ui.UserId = TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.UserId)))
      );

-- -----------------------------------------------------------------
-- 4. Insert UserSettings rows
--    CSV columns Theme/DarkMode/OverlayColor are mapped to
--    PreferredTheme/IsDarkMode/Language in the table.
-- -----------------------------------------------------------------
INSERT INTO ATAPUtilities.UserSettings (UserId, PreferredTheme, IsDarkMode, Language)
SELECT
    TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.UserId))),
    NULLIF(LTRIM(RTRIM(s.Theme)),        N''),
    TRY_CONVERT(BIT, LTRIM(RTRIM(s.DarkMode))),
    NULLIF(LTRIM(RTRIM(s.OverlayColor)), N'')
FROM  ATAPUtilities._stg_User_UserSettings AS s
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.UserId))) IS NOT NULL
  AND NOT EXISTS (
          SELECT 1
          FROM   ATAPUtilities.UserSettings AS us
          WHERE  us.UserId = TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.UserId)))
      );

-- -----------------------------------------------------------------
-- Drop staging tables
-- -----------------------------------------------------------------
IF OBJECT_ID('ATAPUtilities._stg_User_Users',           'U') IS NOT NULL DROP TABLE ATAPUtilities._stg_User_Users;
IF OBJECT_ID('ATAPUtilities._stg_User_UserInformation', 'U') IS NOT NULL DROP TABLE ATAPUtilities._stg_User_UserInformation;
IF OBJECT_ID('ATAPUtilities._stg_User_UserSettings',    'U') IS NOT NULL DROP TABLE ATAPUtilities._stg_User_UserSettings;

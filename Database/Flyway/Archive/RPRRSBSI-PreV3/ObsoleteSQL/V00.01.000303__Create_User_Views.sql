USE ATAPUtilities;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================
   V00.01.000303 — Create User Views (cross-schema)

   Creates three views for user display and reconciliation:

     1. ATAPUtilities.vw_UserFull
        Full user row with LEFT JOINs to UserInformation and
        UserSettings within the ATAPUtilities schema.

     2. AceCommander.vw_UserFull
        Mirrors ATAPUtilities.vw_UserFull within AceCommander.

     3. AceCommander.vw_UserCrossSchema
        Joins AceCommander and ATAPUtilities user rows on the
        stable cross-schema key (EmailHash) to support
        reconciliation and combined display pages.

   Security posture:
     - Data at rest: PII columns (FirstName, LastName, Email,
       Phone, Role) are stored as VARBINARY ciphertext encrypted
       with ENCRYPTBYPASSPHRASE.  Views expose ciphertext as-is.
     - Data in transit: TLS enforced at the connection layer.
     - Clear-text display: callers decrypt via
       ATAPUtilities.usp_GetDecryptedUserInformation, supplying
       the passphrase from the application configuration.
       Non-PII settings columns (PreferredTheme, IsDarkMode,
       Language) are already clear text.

   LEFT JOIN rationale:
     All child joins (UserInformation, UserSettings) use LEFT JOIN
     so that base [User] rows are preserved even when related rows
     do not yet exist.  The cross-schema join also uses LEFT JOIN
     so that AceCommander users without a matching ATAPUtilities
     counterpart are still visible in vw_UserCrossSchema.
   ============================================================ */

-- ============================================================
-- 1. ATAPUtilities.vw_UserFull
-- ============================================================
IF OBJECT_ID(N'ATAPUtilities.vw_UserFull', N'V') IS NOT NULL
    DROP VIEW ATAPUtilities.vw_UserFull;
GO

CREATE VIEW ATAPUtilities.vw_UserFull AS
SELECT
    u.UserId,
    u.EmailHash,
    u.HashAlgorithmName,
    -- PII stored as ciphertext; decrypt via ATAPUtilities.usp_GetDecryptedUserInformation
    ui.FirstName,
    ui.LastName,
    ui.Email,
    ui.Phone,
    ui.Role,
    ui.EncryptionKeyVersion,
    -- Settings are clear text
    us.PreferredTheme,
    us.IsDarkMode,
    us.Language
FROM ATAPUtilities.[User]            AS u
LEFT JOIN ATAPUtilities.UserInformation AS ui ON ui.UserId = u.UserId
LEFT JOIN ATAPUtilities.UserSettings    AS us ON us.UserId = u.UserId;
GO

-- ============================================================
-- 2. AceCommander.vw_UserFull
-- ============================================================
IF OBJECT_ID(N'AceCommander.vw_UserFull', N'V') IS NOT NULL
    DROP VIEW AceCommander.vw_UserFull;
GO

CREATE VIEW AceCommander.vw_UserFull AS
SELECT
    u.UserId,
    u.EmailHash,
    u.HashAlgorithmName,
    -- PII stored as ciphertext; same passphrase as ATAPUtilities (copied in V00.01.000050)
    ui.FirstName,
    ui.LastName,
    ui.Email,
    ui.Phone,
    ui.Role,
    ui.EncryptionKeyVersion,
    -- Settings are clear text
    us.PreferredTheme,
    us.IsDarkMode,
    us.Language
FROM AceCommander.[User]            AS u
LEFT JOIN AceCommander.UserInformation AS ui ON ui.UserId = u.UserId
LEFT JOIN AceCommander.UserSettings    AS us ON us.UserId = u.UserId;
GO

-- ============================================================
-- 3. AceCommander.vw_UserCrossSchema
--    Base: AceCommander users; joined to ATAPUtilities users
--    using EmailHash as the stable cross-schema reconciliation key.
--    EmailHash NULLs are excluded from the join to avoid
--    incorrect cross-row matches.
-- ============================================================
IF OBJECT_ID(N'AceCommander.vw_UserCrossSchema', N'V') IS NOT NULL
    DROP VIEW AceCommander.vw_UserCrossSchema;
GO

CREATE VIEW AceCommander.vw_UserCrossSchema AS
SELECT
    -- Reconciliation key
    ac_u.EmailHash,

    -- AceCommander identity
    ac_u.UserId                  AS AC_UserId,
    ac_u.HashAlgorithmName       AS AC_HashAlgorithmName,
    -- AceCommander PII (ciphertext)
    ac_ui.FirstName              AS AC_FirstName,
    ac_ui.LastName               AS AC_LastName,
    ac_ui.Email                  AS AC_Email,
    ac_ui.Phone                  AS AC_Phone,
    ac_ui.Role                   AS AC_Role,
    ac_ui.EncryptionKeyVersion   AS AC_EncryptionKeyVersion,
    -- AceCommander settings (clear text)
    ac_us.PreferredTheme         AS AC_PreferredTheme,
    ac_us.IsDarkMode             AS AC_IsDarkMode,
    ac_us.Language               AS AC_Language,

    -- ATAPUtilities identity (NULL when no match)
    atu_u.UserId                 AS ATU_UserId,
    atu_u.HashAlgorithmName      AS ATU_HashAlgorithmName,
    -- ATAPUtilities PII (ciphertext)
    atu_ui.FirstName             AS ATU_FirstName,
    atu_ui.LastName              AS ATU_LastName,
    atu_ui.Email                 AS ATU_Email,
    atu_ui.Phone                 AS ATU_Phone,
    atu_ui.Role                  AS ATU_Role,
    atu_ui.EncryptionKeyVersion  AS ATU_EncryptionKeyVersion,
    -- ATAPUtilities settings (clear text)
    atu_us.PreferredTheme        AS ATU_PreferredTheme,
    atu_us.IsDarkMode            AS ATU_IsDarkMode,
    atu_us.Language              AS ATU_Language
FROM AceCommander.[User]               AS ac_u
LEFT JOIN AceCommander.UserInformation AS ac_ui  ON ac_ui.UserId  = ac_u.UserId
LEFT JOIN AceCommander.UserSettings    AS ac_us  ON ac_us.UserId  = ac_u.UserId
LEFT JOIN ATAPUtilities.[User]         AS atu_u  ON atu_u.EmailHash = ac_u.EmailHash
                                                AND ac_u.EmailHash IS NOT NULL
LEFT JOIN ATAPUtilities.UserInformation AS atu_ui ON atu_ui.UserId = atu_u.UserId
LEFT JOIN ATAPUtilities.UserSettings    AS atu_us ON atu_us.UserId = atu_u.UserId;
GO

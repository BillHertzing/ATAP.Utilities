USE ATAPUtilities;
GO
SET XACT_ABORT ON;
SET NOCOUNT ON;
GO

/* ============================================================
   V00.01.000050 - Populate AceCommander User Tables
   Copies ATAPUtilities user-related data into AceCommander using
   fresh GUIDs and a deterministic remap table per migration run.
   ============================================================ */

IF OBJECT_ID(N'tempdb..#guid_remap', N'U') IS NOT NULL DROP TABLE #guid_remap;

CREATE TABLE #guid_remap (
    OldGuid UNIQUEIDENTIFIER NOT NULL,
    NewGuid UNIQUEIDENTIFIER NOT NULL,
    CONSTRAINT PK_guid_remap PRIMARY KEY CLUSTERED (OldGuid),
    CONSTRAINT UQ_guid_remap_NewGuid UNIQUE (NewGuid)
);

INSERT INTO #guid_remap (OldGuid, NewGuid)
SELECT
    src.OldGuid,
    NEWID()
FROM (
    SELECT DISTINCT u.PhiloteId AS OldGuid
    FROM ATAPUtilities.[User] AS u
    UNION
    SELECT DISTINCT u.UserId AS OldGuid
    FROM ATAPUtilities.[User] AS u
) AS src;

-- Seed AceCommander.Philote for the user-related identities.
INSERT INTO AceCommander.Philote (PhiloteId, CreatedAt)
SELECT
    m.NewGuid,
    p.CreatedAt
FROM ATAPUtilities.[User] AS u
INNER JOIN ATAPUtilities.Philote AS p
    ON p.PhiloteId = u.PhiloteId
INNER JOIN #guid_remap AS m
    ON m.OldGuid = p.PhiloteId
WHERE NOT EXISTS (
    SELECT 1
    FROM AceCommander.Philote AS ap
    WHERE ap.PhiloteId = m.NewGuid
);

-- Copy users with remapped PhiloteId and UserId.
INSERT INTO AceCommander.[User] (PhiloteId, UserId, SaltedAndHashedPassword, EmailHash, HashAlgorithmName)
SELECT
    philoteMap.NewGuid,
    userMap.NewGuid,
    u.SaltedAndHashedPassword,
    u.EmailHash,
    u.HashAlgorithmName
FROM ATAPUtilities.[User] AS u
INNER JOIN #guid_remap AS philoteMap
    ON philoteMap.OldGuid = u.PhiloteId
INNER JOIN #guid_remap AS userMap
    ON userMap.OldGuid = u.UserId
WHERE NOT EXISTS (
    SELECT 1
    FROM AceCommander.[User] AS au
    WHERE au.PhiloteId = philoteMap.NewGuid
);

-- Copy encrypted PII payloads as-is; ciphertext remains decryptable with ${user_pii_passphrase}.
INSERT INTO AceCommander.UserInformation (UserId, FirstName, LastName, Email, Phone, Role, EncryptionKeyVersion)
SELECT
    userMap.NewGuid,
    ui.FirstName,
    ui.LastName,
    ui.Email,
    ui.Phone,
    ui.Role,
    ui.EncryptionKeyVersion
FROM ATAPUtilities.UserInformation AS ui
INNER JOIN #guid_remap AS userMap
    ON userMap.OldGuid = ui.UserId
WHERE NOT EXISTS (
    SELECT 1
    FROM AceCommander.UserInformation AS aui
    WHERE aui.UserId = userMap.NewGuid
);

INSERT INTO AceCommander.UserSettings (UserId, PreferredTheme, IsDarkMode, Language)
SELECT
    userMap.NewGuid,
    us.PreferredTheme,
    us.IsDarkMode,
    us.Language
FROM ATAPUtilities.UserSettings AS us
INNER JOIN #guid_remap AS userMap
    ON userMap.OldGuid = us.UserId
WHERE NOT EXISTS (
    SELECT 1
    FROM AceCommander.UserSettings AS aus
    WHERE aus.UserId = userMap.NewGuid
);

DROP TABLE #guid_remap;
GO

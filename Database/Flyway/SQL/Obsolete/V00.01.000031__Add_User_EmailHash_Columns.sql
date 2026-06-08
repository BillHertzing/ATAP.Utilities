-- =====================================================================
-- V00.01.000031__Add_User_EmailHash_Columns.sql
--
-- Adds EmailHash and HashAlgorithm columns to ATAPUtilities.[User].
-- These columns were designed as part of the Argon2id auth redesign
-- (V00.01.000010 edit) but could not be included in that migration
-- because it had already been applied to existing databases.
--
-- EmailHash    : SHA-256 hex of the normalised (trimmed, lowercase)
--                email address — enables indexed lookup without
--                exposing PII in queries.
-- HashAlgorithm: Records which algorithm produced SaltedAndHashedPassword.
--                Defaults to N'Argon2id'; reserved for future rotation.
--
-- Safe to run multiple times (IF NOT EXISTS guards each statement).
-- =====================================================================
USE ATAPUtilities;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'ATAPUtilities.[User]')
      AND name = N'EmailHash')
BEGIN
    ALTER TABLE ATAPUtilities.[User]
        ADD EmailHash CHAR(64) NULL;
    PRINT 'Added column ATAPUtilities.[User].EmailHash';
END
ELSE
    PRINT 'Column ATAPUtilities.[User].EmailHash already exists – skipped.';
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'ATAPUtilities.[User]')
      AND name = N'HashAlgorithm')
BEGIN
    ALTER TABLE ATAPUtilities.[User]
        ADD HashAlgorithm NVARCHAR(50) NOT NULL
            CONSTRAINT DF_User_HashAlgorithm DEFAULT N'Argon2id';
    PRINT 'Added column ATAPUtilities.[User].HashAlgorithm';
END
ELSE
    PRINT 'Column ATAPUtilities.[User].HashAlgorithm already exists – skipped.';
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'ATAPUtilities.[User]')
      AND name = N'IX_User_EmailHash')
BEGIN
    CREATE INDEX IX_User_EmailHash ON ATAPUtilities.[User] (EmailHash);
    PRINT 'Created index IX_User_EmailHash';
END
ELSE
    PRINT 'Index IX_User_EmailHash already exists – skipped.';
GO

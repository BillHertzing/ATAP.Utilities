-- =====================================================================
-- V00.01.000011__Add_Snippet_Language_Kind.sql
--
-- Adds Snippet as a new PrimitiveLanguageKind to support VS Code snippets
-- across multiple languages (YAML, PowerShell, SQL, etc.)
--
-- Prerequisites:
--   - V00.01.000010 (core schema)
-- =====================================================================

USE ATAPUtilities;
GO

SET XACT_ABORT ON;
SET NOCOUNT ON;

-- Add Snippet language kind if it doesn't already exist
IF NOT EXISTS (SELECT 1 FROM dbo.PrimitiveLanguageKind WHERE PrimitiveLanguageKindId = 5)
BEGIN
    INSERT INTO dbo.PrimitiveLanguageKind (PrimitiveLanguageKindId, Name, Description)
    VALUES (5, N'Snippet', N'VS Code snippet primitives and rules for code templates');

    PRINT 'Added Snippet language kind (ID=5)';
END
ELSE
BEGIN
    PRINT 'Snippet language kind already exists';
END
GO

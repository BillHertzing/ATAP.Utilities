-- =====================================================================
-- V00.01.000012__Add_Path_Language_Kind.sql
--
-- Adds "Path" as a new PrimitiveLanguageKind (ID=6) for representing
-- Windows filesystem path primitives following EBNF grammar.
--
-- Prerequisites:
--   - V00.01.000010 (core schema with PrimitiveLanguageKind table)
--
-- Usage:
--   Path primitives enable modeling Windows filesystem paths using
--   composable grammar elements: <path>, <unc-path>, <absolute-path>,
--   <relative-path>, <extended-path>, <drive>, <path-tail>, <name>,
--   <namechar>, <server>, <share>, <letter>
-- =====================================================================

SET XACT_ABORT ON;
SET NOCOUNT ON;

-- Check if Path language kind already exists
IF NOT EXISTS (SELECT 1 FROM dbo.PrimitiveLanguageKind WHERE PrimitiveLanguageKindId = 6)
BEGIN
    INSERT INTO dbo.PrimitiveLanguageKind (PrimitiveLanguageKindId, Name, Description)
    VALUES (
        6,
        'Path',
        'Windows filesystem path primitives following EBNF grammar for UNC, absolute, relative, and extended-length paths with validation rules'
    );
    PRINT 'Added PrimitiveLanguageKind: Path (ID=6)';
END
ELSE
BEGIN
    PRINT 'PrimitiveLanguageKind Path (ID=6) already exists, skipping insert.';
END

GO

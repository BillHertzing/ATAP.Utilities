/*
 * V00.01.000030__Load_LanguagePrimitives_Data.sql
 * 
 * Loads SLOWLY CHANGING reference data:
 *   - Languages (SQL, C#, PowerShell, etc.)
 *   - Rule Primitives (language constructs with Philote IDs)
 *
 * This data represents core language constructs that rarely change.
 * Separated from Rules data which changes more frequently.
 */

USE BuildSets;
GO

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @data_dir nvarchar(4000) = N'${data_dir}';
DECLARE @sql nvarchar(max);

/* --- Staging tables (all NVARCHAR for flexibility) --- */
IF OBJECT_ID('dbo._stg_Language','U')       IS NOT NULL DROP TABLE dbo._stg_Language;
IF OBJECT_ID('dbo._stg_RulePrimitive','U')  IS NOT NULL DROP TABLE dbo._stg_RulePrimitive;

CREATE TABLE dbo._stg_Language(
  ID          nvarchar(20)  NULL,
  Name        nvarchar(50)  NULL,
  Description nvarchar(500) NULL
);

CREATE TABLE dbo._stg_RulePrimitive(
  PhiloteID     nvarchar(40)   NULL,
  LanguageID    nvarchar(20)   NULL,
  SymbolicName  nvarchar(128)  NULL,
  Description   nvarchar(1000) NULL,
  BNFDefinition nvarchar(max)  NULL
);

/* --- BULK INSERT from CSV files --- */
SET @sql = N'
BULK INSERT dbo._stg_Language
FROM ''' + @data_dir + N'\Language.csv''
WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', CODEPAGE=''65001'', TABLOCK);';
EXEC (@sql);

SET @sql = N'
BULK INSERT dbo._stg_RulePrimitive
FROM ''' + @data_dir + N'\RulePrimitive.csv''
WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', CODEPAGE=''65001'', TABLOCK);';
EXEC (@sql);

/* --- Move to typed tables --- */
INSERT dbo.Language (ID, Name, Description)
SELECT 
  CAST(ID AS int), 
  Name,
  Description
FROM dbo._stg_Language;

INSERT dbo.RulePrimitive (PhiloteID, LanguageID, SymbolicName, Description, BNFDefinition)
SELECT
  CAST(PhiloteID AS uniqueidentifier),
  CAST(LanguageID AS int),
  SymbolicName,
  Description,
  BNFDefinition
FROM dbo._stg_RulePrimitive;

/* --- Data quality guardrails --- */
IF (SELECT COUNT(*) FROM dbo.Language) < 3
  THROW 50001, 'Language row count unexpected - expected at least 3 languages', 1;

IF (SELECT COUNT(*) FROM dbo.RulePrimitive) < 5
  THROW 50002, 'RulePrimitive row count unexpected - expected at least 5 primitives', 1;

-- Verify referential integrity
IF EXISTS (
  SELECT 1 FROM dbo.RulePrimitive rp
  WHERE NOT EXISTS (SELECT 1 FROM dbo.Language l WHERE l.ID = rp.LanguageID)
)
  THROW 50003, 'RulePrimitive referential integrity violation - orphaned LanguageID found', 1;

/* --- Cleanup staging tables --- */
DROP TABLE dbo._stg_RulePrimitive;
DROP TABLE dbo._stg_Language;

COMMIT;

PRINT 'Successfully loaded Language and RulePrimitive reference data (slowly changing)';
GO

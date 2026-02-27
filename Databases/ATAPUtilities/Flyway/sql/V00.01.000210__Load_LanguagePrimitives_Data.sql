/*
 * V00.01.000210__Load_LanguagePrimitives_Data.sql
 * 
 * Loads SLOWLY CHANGING reference data:
 *   - Philote identifiers
 *   - Languages (SQL, C#, PowerShell, etc.)
 *   - Rule Primitives (language constructs with Philote IDs)
 *
 * This data represents core language constructs that rarely change.
 * Separated from Rules data which changes more frequently.
 */

USE [ATAPUtilities];
GO

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @data_dir nvarchar(4000) = N'${data_dir}';
DECLARE @sql nvarchar(max);

PRINT '=== Loading Slowly Changing Data (Languages and Primitives) ===';

/* --- Staging tables (all NVARCHAR for flexibility) --- */
IF OBJECT_ID('dbo._stg_Philote','U')        IS NOT NULL DROP TABLE dbo._stg_Philote;
IF OBJECT_ID('dbo._stg_Language','U')       IS NOT NULL DROP TABLE dbo._stg_Language;
IF OBJECT_ID('dbo._stg_RulePrimitive','U')  IS NOT NULL DROP TABLE dbo._stg_RulePrimitive;

CREATE TABLE dbo._stg_Philote(
  PhiloteID   nvarchar(40)  NULL,
  EntityType  nvarchar(50)  NULL,
  EntityKey   nvarchar(128) NULL,
  Description nvarchar(500) NULL
);

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
  BNFDefinition nvarchar(max)  NULL,
  Attribution   nvarchar(max)  NULL
);

/* --- BULK INSERT from CSV files --- */
PRINT 'Loading Philote identifiers...';
SET @sql = N'
BULK INSERT dbo._stg_Philote
FROM ''' + @data_dir + N'\Philote.csv''
WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', CODEPAGE=''65001'', TABLOCK);';
EXEC (@sql);

PRINT 'Loading Languages...';
SET @sql = N'
BULK INSERT dbo._stg_Language
FROM ''' + @data_dir + N'\Language.csv''
WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', CODEPAGE=''65001'', TABLOCK);';
EXEC (@sql);

PRINT 'Loading RulePrimitives...';
SET @sql = N'
BULK INSERT dbo._stg_RulePrimitive
FROM ''' + @data_dir + N'\RulePrimitive.csv''
WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', CODEPAGE=''65001'', TABLOCK);';
EXEC (@sql);

/* --- Move to typed tables --- */
PRINT 'Inserting Philote records...';
INSERT dbo.Philote (PhiloteID, EntityType, EntityKey, Description)
SELECT 
  CAST(PhiloteID AS uniqueidentifier),
  EntityType,
  EntityKey,
  Description
FROM dbo._stg_Philote;

PRINT 'Inserting Language records...';
SET IDENTITY_INSERT dbo.Language ON;
INSERT dbo.Language (ID, Name, Description)
SELECT 
  CAST(ID AS int), 
  Name,
  Description
FROM dbo._stg_Language;
SET IDENTITY_INSERT dbo.Language OFF;

PRINT 'Inserting RulePrimitive records...';
INSERT dbo.RulePrimitive (PhiloteID, LanguageID, SymbolicName, Description, BNFDefinition, Attribution)
SELECT
  CAST(PhiloteID AS uniqueidentifier),
  CAST(LanguageID AS int),
  SymbolicName,
  Description,
  BNFDefinition,
  Attribution
FROM dbo._stg_RulePrimitive;

/* --- Data quality guardrails --- */
DECLARE @philoteCount int = (SELECT COUNT(*) FROM dbo.Philote WHERE EntityType = 'RulePrimitive');
DECLARE @langCount int = (SELECT COUNT(*) FROM dbo.Language);
DECLARE @primCount int = (SELECT COUNT(*) FROM dbo.RulePrimitive);

PRINT CONCAT('Loaded ', @philoteCount, ' Philote identifiers');
PRINT CONCAT('Loaded ', @langCount, ' Languages');
PRINT CONCAT('Loaded ', @primCount, ' Rule Primitives');

IF @langCount < 3
  THROW 50001, 'Language row count unexpected - expected at least 3 languages', 1;

IF @primCount < 5
  THROW 50002, 'RulePrimitive row count unexpected - expected at least 5 primitives', 1;

-- Verify referential integrity
IF EXISTS (
  SELECT 1 FROM dbo.RulePrimitive rp
  WHERE NOT EXISTS (SELECT 1 FROM dbo.Language l WHERE l.ID = rp.LanguageID)
)
  THROW 50003, 'RulePrimitive referential integrity violation - orphaned LanguageID found', 1;

-- Verify Philote linkage
IF EXISTS (
  SELECT 1 FROM dbo.RulePrimitive rp
  WHERE NOT EXISTS (SELECT 1 FROM dbo.Philote p WHERE p.PhiloteID = rp.PhiloteID)
)
  THROW 50004, 'RulePrimitive referential integrity violation - orphaned PhiloteID found', 1;

/* --- Cleanup staging tables --- */
DROP TABLE dbo._stg_RulePrimitive;
DROP TABLE dbo._stg_Language;
DROP TABLE dbo._stg_Philote;

COMMIT;

PRINT '=== Successfully loaded Language and RulePrimitive reference data (slowly changing) ===';
GO

-- =====================================================================
-- V00.01.000020__Load_ATAPUtilities_Data_From_BCP.sql
--
-- Loads RRSBS seed data from CSV files via BULK INSERT:
--   1. Philote_Primitives.csv   → dbo.Philote       (51 GUIDs)
--   2. RulePrimitive.csv         → dbo.RulePrimitive (51 primitives)
--   3. Philote_Rules.csv         → dbo.Philote       (24 GUIDs)
--   4. Rule.csv                  → dbo.Rule          (24 rules)
--
-- Prerequisites:
--   - All tables created by V00.01.000010
--   - PrimitiveLanguageKind already seeded with 4 languages
--   - CSV files present in ${data_dir}
-- =====================================================================

SET XACT_ABORT ON;
SET NOCOUNT ON;
BEGIN TRAN;

DECLARE @data_dir nvarchar(4000) = N'${data_dir}';
DECLARE @sql nvarchar(max);
DECLARE @philote_primitives_file nvarchar(4000) = @data_dir + N'\Philote_Primitives.csv';
DECLARE @rule_primitive_file nvarchar(4000) = @data_dir + N'\RulePrimitive.csv';
DECLARE @philote_rules_file nvarchar(4000) = @data_dir + N'\Philote_Rules.csv';
DECLARE @rule_file nvarchar(4000) = @data_dir + N'\Rule.csv';

-- =====================================================================
-- SECTION 1: Create Staging Tables
-- =====================================================================

IF OBJECT_ID('dbo._stg_Philote_Primitives','U') IS NOT NULL DROP TABLE dbo._stg_Philote_Primitives;
CREATE TABLE dbo._stg_Philote_Primitives (
    PhiloteId nvarchar(50) NOT NULL,
    Comment nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_RulePrimitive','U') IS NOT NULL DROP TABLE dbo._stg_RulePrimitive;
CREATE TABLE dbo._stg_RulePrimitive (
    PhiloteId nvarchar(50) NOT NULL,
    PrimitiveLanguageKindId nvarchar(10) NOT NULL,
    [Name] nvarchar(200) NOT NULL,
    [Description] nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_Philote_Rules','U') IS NOT NULL DROP TABLE dbo._stg_Philote_Rules;
CREATE TABLE dbo._stg_Philote_Rules (
    PhiloteId nvarchar(50) NOT NULL,
    Comment nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_Rule','U') IS NOT NULL DROP TABLE dbo._stg_Rule;
CREATE TABLE dbo._stg_Rule (
    PhiloteId nvarchar(50) NOT NULL,
    PrimitiveLanguageKindId nvarchar(10) NOT NULL,
    [Name] nvarchar(200) NOT NULL,
    Purpose nvarchar(500) NULL,
    SourceFileReference nvarchar(500) NULL
);

-- =====================================================================
-- SECTION 2: BULK INSERT from CSV Files
-- =====================================================================

/* --- Load Philote_Primitives --- */
PRINT 'Loading Philote_Primitives.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_Philote_Primitives
    FROM ' + QUOTENAME(@philote_primitives_file,'''') + N'
    WITH (
        DATAFILETYPE = ''char'',
        FIELDTERMINATOR = '','',
        ROWTERMINATOR = ''0x0A'',
        FIRSTROW = 2,
        TABLOCK
    );';
    EXEC sys.sp_executesql @sql;
    PRINT '  Loaded ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' rows into staging.';
END TRY
BEGIN CATCH
    DECLARE @ErrorMessage nvarchar(4000) = 'Philote_Primitives: ' + ERROR_MESSAGE();
    THROW 50001, @ErrorMessage, 1;
END CATCH

/* --- Load RulePrimitive --- */
PRINT 'Loading RulePrimitive.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_RulePrimitive
    FROM ' + QUOTENAME(@rule_primitive_file,'''') + N'
    WITH (
        DATAFILETYPE = ''char'',
        FIELDTERMINATOR = '','',
        ROWTERMINATOR = ''0x0A'',
        FIRSTROW = 2,
        TABLOCK
    );';
    EXEC sys.sp_executesql @sql;
    PRINT '  Loaded ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' rows into staging.';
END TRY
BEGIN CATCH
    SET @ErrorMessage = 'RulePrimitive: ' + ERROR_MESSAGE();
    THROW 50002, @ErrorMessage, 1;
END CATCH

/* --- Load Philote_Rules --- */
PRINT 'Loading Philote_Rules.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_Philote_Rules
    FROM ' + QUOTENAME(@philote_rules_file,'''') + N'
    WITH (
        DATAFILETYPE = ''char'',
        FIELDTERMINATOR = '','',
        ROWTERMINATOR = ''0x0A'',
        FIRSTROW = 2,
        TABLOCK
    );';
    EXEC sys.sp_executesql @sql;
    PRINT '  Loaded ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' rows into staging.';
END TRY
BEGIN CATCH
    SET @ErrorMessage = 'Philote_Rules: ' + ERROR_MESSAGE();
    THROW 50003, @ErrorMessage, 1;
END CATCH

/* --- Load Rule --- */
PRINT 'Loading Rule.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_Rule
    FROM ' + QUOTENAME(@rule_file,'''') + N'
    WITH (
        DATAFILETYPE = ''char'',
        FIELDTERMINATOR = '','',
        ROWTERMINATOR = ''0x0A'',
        FIRSTROW = 2,
        TABLOCK
    );';
    EXEC sys.sp_executesql @sql;
    PRINT '  Loaded ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' rows into staging.';
END TRY
BEGIN CATCH
    SET @ErrorMessage = 'Rule: ' + ERROR_MESSAGE();
    THROW 50004, @ErrorMessage, 1;
END CATCH

-- =====================================================================
-- SECTION 3: Clear Existing Data (respecting FK constraints)
-- =====================================================================

PRINT 'Clearing existing RRSBS data...';

-- Clear in dependency order (children first)
DELETE FROM dbo.RuleInstantiationBinding;
DELETE FROM dbo.RuleInstantiation;
DELETE FROM dbo.RuleSetMember;
DELETE FROM dbo.RuleSet;
DELETE FROM dbo.RulePrimitiveComposition;
DELETE FROM dbo.[Rule];
DELETE FROM dbo.RulePrimitiveInput;
DELETE FROM dbo.RulePrimitive;
DELETE FROM dbo.Philote;

-- =====================================================================
-- SECTION 4: Load Production Tables
-- =====================================================================

PRINT 'Inserting Philote entries for primitives (51 rows)...';
INSERT INTO dbo.Philote (PhiloteId)
SELECT TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId)))
FROM dbo._stg_Philote_Primitives
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL;
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' Philote GUIDs for primitives.';

PRINT 'Inserting RulePrimitive entries (51 rows)...';
INSERT INTO dbo.RulePrimitive (PhiloteId, PrimitiveLanguageKindId, [Name], [Description])
SELECT
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))),
    TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))),
    NULLIF(LTRIM(RTRIM([Name])),''),
    NULLIF(LTRIM(RTRIM([Description])),'')
FROM dbo._stg_RulePrimitive
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))) IS NOT NULL
  AND NULLIF(LTRIM(RTRIM([Name])),'') IS NOT NULL;
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' RulePrimitive records.';

PRINT 'Inserting Philote entries for rules (24 rows)...';
INSERT INTO dbo.Philote (PhiloteId)
SELECT TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId)))
FROM dbo._stg_Philote_Rules
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL;
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' Philote GUIDs for rules.';

PRINT 'Inserting Rule entries (24 rows)...';
INSERT INTO dbo.[Rule] (PhiloteId, PrimitiveLanguageKindId, [Name], Purpose, SourceFileReference)
SELECT
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))),
    TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))),
    NULLIF(LTRIM(RTRIM([Name])),''),
    NULLIF(LTRIM(RTRIM(Purpose)),''),
    NULLIF(LTRIM(RTRIM(SourceFileReference)),'')
FROM dbo._stg_Rule
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))) IS NOT NULL
  AND NULLIF(LTRIM(RTRIM([Name])),'') IS NOT NULL;
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' Rule records.';

-- =====================================================================
-- SECTION 5: Cleanup Staging Tables
-- =====================================================================

PRINT 'Cleaning up staging tables...';
IF OBJECT_ID('dbo._stg_Philote_Primitives','U') IS NOT NULL DROP TABLE dbo._stg_Philote_Primitives;
IF OBJECT_ID('dbo._stg_RulePrimitive','U') IS NOT NULL DROP TABLE dbo._stg_RulePrimitive;
IF OBJECT_ID('dbo._stg_Philote_Rules','U') IS NOT NULL DROP TABLE dbo._stg_Philote_Rules;
IF OBJECT_ID('dbo._stg_Rule','U') IS NOT NULL DROP TABLE dbo._stg_Rule;

-- =====================================================================
-- SECTION 6: Validation and Summary
-- =====================================================================

PRINT 'Validating row counts...';
DECLARE @PhiloteCount int = (SELECT COUNT(*) FROM dbo.Philote);
DECLARE @RulePrimitiveCount int = (SELECT COUNT(*) FROM dbo.RulePrimitive);
DECLARE @RuleCount int = (SELECT COUNT(*) FROM dbo.[Rule]);
DECLARE @LanguageCount int = (SELECT COUNT(*) FROM dbo.PrimitiveLanguageKind);

IF @PhiloteCount < 75
    THROW 50010, 'Philote row count below minimum expected (75 = 51 primitives + 24 rules)', 1;
IF @RulePrimitiveCount < 51
    THROW 50011, 'RulePrimitive row count below minimum expected (51)', 1;
IF @RuleCount < 24
    THROW 50012, 'Rule row count below minimum expected (24)', 1;
IF @LanguageCount < 4
    THROW 50013, 'PrimitiveLanguageKind row count below minimum expected (4)', 1;

PRINT '';
PRINT '========================================';
PRINT 'RRSBS Data Load Complete';
PRINT '========================================';
PRINT 'Languages:       ' + CAST(@LanguageCount AS nvarchar(10));
PRINT 'Philote GUIDs:   ' + CAST(@PhiloteCount AS nvarchar(10));
PRINT 'Rule Primitives: ' + CAST(@RulePrimitiveCount AS nvarchar(10));
PRINT 'Rules:           ' + CAST(@RuleCount AS nvarchar(10));
PRINT '========================================';

COMMIT;



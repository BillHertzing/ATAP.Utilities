-- =====================================================================
-- V00.01.000020__Load_ATAPUtilities_Data_From_BCP.sql
--
-- Loads all RRSBS seed data from CSV files via BULK INSERT:
--
-- CORE DATA (CSharp/Powershell/SQL/MSBuild):
--   1. Philote_Primitives.csv             → dbo.Philote       (51 GUIDs)
--   2. RulePrimitive.csv                  → dbo.RulePrimitive (51 primitives)
--   3. Philote_Rules.csv                  → dbo.Philote       (24 GUIDs)
--   4. Rule.csv                           → dbo.Rule          (24 rules)
--
-- SNIPPET DATA:
--   5. Philote_SnippetPrimitives.csv      → dbo.Philote       (6 GUIDs)
--   6. RulePrimitive_Snippets.csv         → dbo.RulePrimitive (6 primitives)
--   7. Philote_SnippetRules.csv           → dbo.Philote       (17 GUIDs)
--   8. Rule_Snippets.csv                  → dbo.Rule          (17 rules)
--   9. Philote_SnippetRuleSets.csv        → dbo.Philote       (3 GUIDs)
--  10. RuleSet_Snippets.csv               → dbo.RuleSet       (3 rule sets)
--
-- PATH DATA:
--  11. Philote_PathPrimitives.csv         → dbo.Philote                   (12 GUIDs)
--  12. RulePrimitive_Paths.csv            → dbo.RulePrimitive             (12 primitives)
--  13. Philote_PathRules.csv              → dbo.Philote                   (1 GUID)
--  14. Rule_Paths.csv                     → dbo.Rule                      (1 rule)
--  15. Philote_PathInstantiations.csv     → dbo.Philote                   (1 GUID)
--  16. RuleInstantiation_Paths.csv        → dbo.RuleInstantiation         (1 instantiation)
--  17. RuleInstantiationBinding_Paths.csv → dbo.RuleInstantiationBinding  (4 bindings)
--
-- TOTALS: 69 primitives, 42 rules, 3 rule sets, 1 instantiation, 4 bindings
--
-- Prerequisites:
--   - V00.01.000010 (core schema with 6 language kinds)
--   - CSV files present in ${data_dir}
-- =====================================================================

SET XACT_ABORT ON;
SET NOCOUNT ON;
BEGIN TRAN;

DECLARE @data_dir nvarchar(4000) = N'${data_dir}';
DECLARE @sql nvarchar(max);

-- Core data files
DECLARE @philote_primitives_file nvarchar(4000) = @data_dir + N'\Philote_Primitives.csv';
DECLARE @rule_primitive_file nvarchar(4000) = @data_dir + N'\RulePrimitive.csv';
DECLARE @philote_rules_file nvarchar(4000) = @data_dir + N'\Philote_Rules.csv';
DECLARE @rule_file nvarchar(4000) = @data_dir + N'\Rule.csv';

-- Snippet data files
DECLARE @philote_snippet_primitives_file nvarchar(4000) = @data_dir + N'\Philote_SnippetPrimitives.csv';
DECLARE @rule_primitive_snippets_file nvarchar(4000) = @data_dir + N'\RulePrimitive_Snippets.csv';
DECLARE @philote_snippet_rules_file nvarchar(4000) = @data_dir + N'\Philote_SnippetRules.csv';
DECLARE @rule_snippets_file nvarchar(4000) = @data_dir + N'\Rule_Snippets.csv';
DECLARE @philote_snippet_rulesets_file nvarchar(4000) = @data_dir + N'\Philote_SnippetRuleSets.csv';
DECLARE @ruleset_snippets_file nvarchar(4000) = @data_dir + N'\RuleSet_Snippets.csv';

-- Path data files
DECLARE @philote_path_primitives_file nvarchar(4000) = @data_dir + N'\Philote_PathPrimitives.csv';
DECLARE @rule_primitive_paths_file nvarchar(4000) = @data_dir + N'\RulePrimitive_Paths.csv';
DECLARE @philote_path_rules_file nvarchar(4000) = @data_dir + N'\Philote_PathRules.csv';
DECLARE @rule_paths_file nvarchar(4000) = @data_dir + N'\Rule_Paths.csv';
DECLARE @philote_path_instantiations_file nvarchar(4000) = @data_dir + N'\Philote_PathInstantiations.csv';
DECLARE @rule_instantiation_paths_file nvarchar(4000) = @data_dir + N'\RuleInstantiation_Paths.csv';
DECLARE @rule_instantiation_binding_paths_file nvarchar(4000) = @data_dir + N'\RuleInstantiationBinding_Paths.csv';

-- =====================================================================
-- SECTION 1: Create Staging Tables
-- =====================================================================

PRINT 'Creating staging tables...';

-- Core staging tables
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

-- Snippet staging tables
IF OBJECT_ID('dbo._stg_Philote_SnippetPrimitives','U') IS NOT NULL DROP TABLE dbo._stg_Philote_SnippetPrimitives;
CREATE TABLE dbo._stg_Philote_SnippetPrimitives (
    PhiloteId nvarchar(50) NOT NULL,
    Comment nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_RulePrimitive_Snippets','U') IS NOT NULL DROP TABLE dbo._stg_RulePrimitive_Snippets;
CREATE TABLE dbo._stg_RulePrimitive_Snippets (
    PhiloteId nvarchar(50) NOT NULL,
    PrimitiveLanguageKindId nvarchar(10) NOT NULL,
    [Name] nvarchar(200) NOT NULL,
    [Description] nvarchar(max) NULL
);

IF OBJECT_ID('dbo._stg_Philote_SnippetRules','U') IS NOT NULL DROP TABLE dbo._stg_Philote_SnippetRules;
CREATE TABLE dbo._stg_Philote_SnippetRules (
    PhiloteId nvarchar(50) NOT NULL,
    Comment nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_Rule_Snippets','U') IS NOT NULL DROP TABLE dbo._stg_Rule_Snippets;
CREATE TABLE dbo._stg_Rule_Snippets (
    PhiloteId nvarchar(50) NOT NULL,
    PrimitiveLanguageKindId nvarchar(10) NOT NULL,
    [Name] nvarchar(200) NOT NULL,
    Purpose nvarchar(max) NULL,
    SourceFileReference nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_Philote_SnippetRuleSets','U') IS NOT NULL DROP TABLE dbo._stg_Philote_SnippetRuleSets;
CREATE TABLE dbo._stg_Philote_SnippetRuleSets (
    PhiloteId nvarchar(50) NOT NULL,
    Comment nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_RuleSet_Snippets','U') IS NOT NULL DROP TABLE dbo._stg_RuleSet_Snippets;
CREATE TABLE dbo._stg_RuleSet_Snippets (
    PhiloteId nvarchar(50) NOT NULL,
    [Name] nvarchar(200) NOT NULL,
    [Description] nvarchar(max) NULL
);

-- Path staging tables
IF OBJECT_ID('dbo._stg_Philote_PathPrimitives','U') IS NOT NULL DROP TABLE dbo._stg_Philote_PathPrimitives;
CREATE TABLE dbo._stg_Philote_PathPrimitives (
    PhiloteId nvarchar(50) NOT NULL,
    Comment nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_RulePrimitive_Paths','U') IS NOT NULL DROP TABLE dbo._stg_RulePrimitive_Paths;
CREATE TABLE dbo._stg_RulePrimitive_Paths (
    PhiloteId nvarchar(50) NOT NULL,
    PrimitiveLanguageKindId nvarchar(10) NOT NULL,
    [Name] nvarchar(200) NOT NULL,
    [Description] nvarchar(max) NULL
);

IF OBJECT_ID('dbo._stg_Philote_PathRules','U') IS NOT NULL DROP TABLE dbo._stg_Philote_PathRules;
CREATE TABLE dbo._stg_Philote_PathRules (
    PhiloteId nvarchar(50) NOT NULL,
    Comment nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_Rule_Paths','U') IS NOT NULL DROP TABLE dbo._stg_Rule_Paths;
CREATE TABLE dbo._stg_Rule_Paths (
    PhiloteId nvarchar(50) NOT NULL,
    PrimitiveLanguageKindId nvarchar(10) NOT NULL,
    [Name] nvarchar(200) NOT NULL,
    Purpose nvarchar(max) NULL,
    SourceFileReference nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_Philote_PathInstantiations','U') IS NOT NULL DROP TABLE dbo._stg_Philote_PathInstantiations;
CREATE TABLE dbo._stg_Philote_PathInstantiations (
    PhiloteId nvarchar(50) NOT NULL,
    Comment nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_RuleInstantiation_Paths','U') IS NOT NULL DROP TABLE dbo._stg_RuleInstantiation_Paths;
CREATE TABLE dbo._stg_RuleInstantiation_Paths (
    PhiloteId nvarchar(50) NOT NULL,
    RulePhiloteId nvarchar(50) NOT NULL,
    Notes nvarchar(max) NULL
);

IF OBJECT_ID('dbo._stg_RuleInstantiationBinding_Paths','U') IS NOT NULL DROP TABLE dbo._stg_RuleInstantiationBinding_Paths;
CREATE TABLE dbo._stg_RuleInstantiationBinding_Paths (
    InstantiationPhiloteId nvarchar(50) NOT NULL,
    InputName nvarchar(200) NOT NULL,
    InputValue nvarchar(max) NULL
);

-- =====================================================================
-- SECTION 2: BULK INSERT from CSV Files
-- =====================================================================

PRINT '';
PRINT '========================================';
PRINT 'Loading Core RRSBS Data';
PRINT '========================================';

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

PRINT '';
PRINT '========================================';
PRINT 'Loading Snippet Data';
PRINT '========================================';

/* --- Load Philote_SnippetPrimitives --- */
PRINT 'Loading Philote_SnippetPrimitives.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_Philote_SnippetPrimitives
    FROM ' + QUOTENAME(@philote_snippet_primitives_file,'''') + N'
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
    SET @ErrorMessage = 'Philote_SnippetPrimitives: ' + ERROR_MESSAGE();
    THROW 50005, @ErrorMessage, 1;
END CATCH

/* --- Load RulePrimitive_Snippets --- */
PRINT 'Loading RulePrimitive_Snippets.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_RulePrimitive_Snippets
    FROM ' + QUOTENAME(@rule_primitive_snippets_file,'''') + N'
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
    SET @ErrorMessage = 'RulePrimitive_Snippets: ' + ERROR_MESSAGE();
    THROW 50006, @ErrorMessage, 1;
END CATCH

/* --- Load Philote_SnippetRules --- */
PRINT 'Loading Philote_SnippetRules.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_Philote_SnippetRules
    FROM ' + QUOTENAME(@philote_snippet_rules_file,'''') + N'
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
    SET @ErrorMessage = 'Philote_SnippetRules: ' + ERROR_MESSAGE();
    THROW 50007, @ErrorMessage, 1;
END CATCH

/* --- Load Rule_Snippets --- */
PRINT 'Loading Rule_Snippets.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_Rule_Snippets
    FROM ' + QUOTENAME(@rule_snippets_file,'''') + N'
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
    SET @ErrorMessage = 'Rule_Snippets: ' + ERROR_MESSAGE();
    THROW 50008, @ErrorMessage, 1;
END CATCH

/* --- Load Philote_SnippetRuleSets --- */
PRINT 'Loading Philote_SnippetRuleSets.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_Philote_SnippetRuleSets
    FROM ' + QUOTENAME(@philote_snippet_rulesets_file,'''') + N'
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
    SET @ErrorMessage = 'Philote_SnippetRuleSets: ' + ERROR_MESSAGE();
    THROW 50009, @ErrorMessage, 1;
END CATCH

/* --- Load RuleSet_Snippets --- */
PRINT 'Loading RuleSet_Snippets.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_RuleSet_Snippets
    FROM ' + QUOTENAME(@ruleset_snippets_file,'''') + N'
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
    SET @ErrorMessage = 'RuleSet_Snippets: ' + ERROR_MESSAGE();
    THROW 50010, @ErrorMessage, 1;
END CATCH

PRINT '';
PRINT '========================================';
PRINT 'Loading Path Data';
PRINT '========================================';

/* --- Load Philote_PathPrimitives --- */
PRINT 'Loading Philote_PathPrimitives.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_Philote_PathPrimitives
    FROM ' + QUOTENAME(@philote_path_primitives_file,'''') + N'
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
    SET @ErrorMessage = 'Philote_PathPrimitives: ' + ERROR_MESSAGE();
    THROW 50011, @ErrorMessage, 1;
END CATCH

/* --- Load RulePrimitive_Paths --- */
PRINT 'Loading RulePrimitive_Paths.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_RulePrimitive_Paths
    FROM ' + QUOTENAME(@rule_primitive_paths_file,'''') + N'
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
    SET @ErrorMessage = 'RulePrimitive_Paths: ' + ERROR_MESSAGE();
    THROW 50012, @ErrorMessage, 1;
END CATCH

/* --- Load Philote_PathRules --- */
PRINT 'Loading Philote_PathRules.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_Philote_PathRules
    FROM ' + QUOTENAME(@philote_path_rules_file,'''') + N'
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
    SET @ErrorMessage = 'Philote_PathRules: ' + ERROR_MESSAGE();
    THROW 50013, @ErrorMessage, 1;
END CATCH

/* --- Load Rule_Paths --- */
PRINT 'Loading Rule_Paths.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_Rule_Paths
    FROM ' + QUOTENAME(@rule_paths_file,'''') + N'
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
    SET @ErrorMessage = 'Rule_Paths: ' + ERROR_MESSAGE();
    THROW 50014, @ErrorMessage, 1;
END CATCH

/* --- Load Philote_PathInstantiations --- */
PRINT 'Loading Philote_PathInstantiations.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_Philote_PathInstantiations
    FROM ' + QUOTENAME(@philote_path_instantiations_file,'''') + N'
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
    SET @ErrorMessage = 'Philote_PathInstantiations: ' + ERROR_MESSAGE();
    THROW 50015, @ErrorMessage, 1;
END CATCH

/* --- Load RuleInstantiation_Paths --- */
PRINT 'Loading RuleInstantiation_Paths.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_RuleInstantiation_Paths
    FROM ' + QUOTENAME(@rule_instantiation_paths_file,'''') + N'
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
    SET @ErrorMessage = 'RuleInstantiation_Paths: ' + ERROR_MESSAGE();
    THROW 50016, @ErrorMessage, 1;
END CATCH

/* --- Load RuleInstantiationBinding_Paths --- */
PRINT 'Loading RuleInstantiationBinding_Paths.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_RuleInstantiationBinding_Paths
    FROM ' + QUOTENAME(@rule_instantiation_binding_paths_file,'''') + N'
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
    SET @ErrorMessage = 'RuleInstantiationBinding_Paths: ' + ERROR_MESSAGE();
    THROW 50017, @ErrorMessage, 1;
END CATCH

-- =====================================================================
-- SECTION 3: Clear Existing Data (respecting FK constraints)
-- =====================================================================

PRINT '';
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
-- SECTION 4: Load Production Tables (respecting FK constraints)
-- =====================================================================

PRINT '';
PRINT '========================================';
PRINT 'Inserting Core RRSBS Data';
PRINT '========================================';

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

PRINT '';
PRINT '========================================';
PRINT 'Inserting Snippet Data';
PRINT '========================================';

PRINT 'Inserting Philote entries for snippet primitives (6 rows)...';
INSERT INTO dbo.Philote (PhiloteId)
SELECT TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId)))
FROM dbo._stg_Philote_SnippetPrimitives
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.Philote WHERE PhiloteId = TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(dbo._stg_Philote_SnippetPrimitives.PhiloteId))));
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' Philote GUIDs for snippet primitives.';

PRINT 'Inserting RulePrimitive entries for snippets (6 rows)...';
INSERT INTO dbo.RulePrimitive (PhiloteId, PrimitiveLanguageKindId, [Name], [Description])
SELECT
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))),
    TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))),
    NULLIF(LTRIM(RTRIM([Name])),''),
    NULLIF(LTRIM(RTRIM([Description])),'')
FROM dbo._stg_RulePrimitive_Snippets
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))) IS NOT NULL
  AND NULLIF(LTRIM(RTRIM([Name])),'') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.RulePrimitive WHERE PhiloteId = TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(dbo._stg_RulePrimitive_Snippets.PhiloteId))));
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' RulePrimitive records for snippets.';

PRINT 'Inserting Philote entries for snippet rules (17 rows)...';
INSERT INTO dbo.Philote (PhiloteId)
SELECT TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId)))
FROM dbo._stg_Philote_SnippetRules
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.Philote WHERE PhiloteId = TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(dbo._stg_Philote_SnippetRules.PhiloteId))));
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' Philote GUIDs for snippet rules.';

PRINT 'Inserting Rule entries for snippets (17 rows)...';
INSERT INTO dbo.[Rule] (PhiloteId, PrimitiveLanguageKindId, [Name], Purpose, SourceFileReference)
SELECT
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))),
    TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))),
    NULLIF(LTRIM(RTRIM([Name])),''),
    NULLIF(LTRIM(RTRIM(Purpose)),''),
    NULLIF(LTRIM(RTRIM(SourceFileReference)),'')
FROM dbo._stg_Rule_Snippets
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))) IS NOT NULL
  AND NULLIF(LTRIM(RTRIM([Name])),'') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.[Rule] WHERE PhiloteId = TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(dbo._stg_Rule_Snippets.PhiloteId))));
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' Rule records for snippets.';

PRINT 'Inserting Philote entries for snippet rule sets (3 rows)...';
INSERT INTO dbo.Philote (PhiloteId)
SELECT TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId)))
FROM dbo._stg_Philote_SnippetRuleSets
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.Philote WHERE PhiloteId = TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(dbo._stg_Philote_SnippetRuleSets.PhiloteId))));
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' Philote GUIDs for snippet rule sets.';

PRINT 'Inserting RuleSet entries for snippets (3 rows)...';
INSERT INTO dbo.RuleSet (PhiloteId, [Name], [Description])
SELECT
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))),
    NULLIF(LTRIM(RTRIM([Name])),''),
    NULLIF(LTRIM(RTRIM([Description])),'')
FROM dbo._stg_RuleSet_Snippets
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND NULLIF(LTRIM(RTRIM([Name])),'') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.RuleSet WHERE PhiloteId = TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(dbo._stg_RuleSet_Snippets.PhiloteId))));
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' RuleSet records for snippets.';

PRINT '';
PRINT '========================================';
PRINT 'Inserting Path Data';
PRINT '========================================';

PRINT 'Inserting Philote entries for path primitives (12 rows)...';
INSERT INTO dbo.Philote (PhiloteId)
SELECT TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId)))
FROM dbo._stg_Philote_PathPrimitives
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.Philote WHERE PhiloteId = TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(dbo._stg_Philote_PathPrimitives.PhiloteId))));
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' Philote GUIDs for path primitives.';

PRINT 'Inserting RulePrimitive entries for paths (12 rows)...';
INSERT INTO dbo.RulePrimitive (PhiloteId, PrimitiveLanguageKindId, [Name], [Description])
SELECT
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))),
    TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))),
    NULLIF(LTRIM(RTRIM([Name])),''),
    NULLIF(LTRIM(RTRIM([Description])),'')
FROM dbo._stg_RulePrimitive_Paths
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))) IS NOT NULL
  AND NULLIF(LTRIM(RTRIM([Name])),'') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.RulePrimitive WHERE PhiloteId = TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(dbo._stg_RulePrimitive_Paths.PhiloteId))));
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' RulePrimitive records for paths.';

PRINT 'Inserting Philote entries for path rules (1 row)...';
INSERT INTO dbo.Philote (PhiloteId)
SELECT TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId)))
FROM dbo._stg_Philote_PathRules
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.Philote WHERE PhiloteId = TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(dbo._stg_Philote_PathRules.PhiloteId))));
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' Philote GUIDs for path rules.';

PRINT 'Inserting Rule entries for paths (1 row)...';
INSERT INTO dbo.[Rule] (PhiloteId, PrimitiveLanguageKindId, [Name], Purpose, SourceFileReference)
SELECT
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))),
    TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))),
    NULLIF(LTRIM(RTRIM([Name])),''),
    NULLIF(LTRIM(RTRIM(Purpose)),''),
    NULLIF(LTRIM(RTRIM(SourceFileReference)),'')
FROM dbo._stg_Rule_Paths
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))) IS NOT NULL
  AND NULLIF(LTRIM(RTRIM([Name])),'') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.[Rule] WHERE PhiloteId = TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(dbo._stg_Rule_Paths.PhiloteId))));
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' Rule records for paths.';

PRINT 'Inserting Philote entries for path instantiations (1 row)...';
INSERT INTO dbo.Philote (PhiloteId)
SELECT TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId)))
FROM dbo._stg_Philote_PathInstantiations
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.Philote WHERE PhiloteId = TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(dbo._stg_Philote_PathInstantiations.PhiloteId))));
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' Philote GUIDs for path instantiations.';

PRINT 'Inserting RuleInstantiation entries for paths (1 row)...';
INSERT INTO dbo.RuleInstantiation (PhiloteId, RulePhiloteId, Notes)
SELECT
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))),
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(RulePhiloteId))),
    NULLIF(LTRIM(RTRIM(Notes)),'')
FROM dbo._stg_RuleInstantiation_Paths
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(RulePhiloteId))) IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.RuleInstantiation WHERE PhiloteId = TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(dbo._stg_RuleInstantiation_Paths.PhiloteId))));
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' RuleInstantiation records for paths.';

PRINT 'Inserting RuleInstantiationBinding entries for paths (4 rows)...';
INSERT INTO dbo.RuleInstantiationBinding (InstantiationPhiloteId, InputName, InputValue)
SELECT
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(InstantiationPhiloteId))),
    NULLIF(LTRIM(RTRIM(InputName)),''),
    NULLIF(LTRIM(RTRIM(InputValue)),'')
FROM dbo._stg_RuleInstantiationBinding_Paths
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(InstantiationPhiloteId))) IS NOT NULL
  AND NULLIF(LTRIM(RTRIM(InputName)),'') IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM dbo.RuleInstantiationBinding
      WHERE InstantiationPhiloteId = TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(dbo._stg_RuleInstantiationBinding_Paths.InstantiationPhiloteId)))
        AND InputName = NULLIF(LTRIM(RTRIM(dbo._stg_RuleInstantiationBinding_Paths.InputName)),'')
  );
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' RuleInstantiationBinding records for paths.';

-- =====================================================================
-- SECTION 5: Cleanup Staging Tables
-- =====================================================================

PRINT '';
PRINT 'Cleaning up staging tables...';
IF OBJECT_ID('dbo._stg_Philote_Primitives','U') IS NOT NULL DROP TABLE dbo._stg_Philote_Primitives;
IF OBJECT_ID('dbo._stg_RulePrimitive','U') IS NOT NULL DROP TABLE dbo._stg_RulePrimitive;
IF OBJECT_ID('dbo._stg_Philote_Rules','U') IS NOT NULL DROP TABLE dbo._stg_Philote_Rules;
IF OBJECT_ID('dbo._stg_Rule','U') IS NOT NULL DROP TABLE dbo._stg_Rule;
IF OBJECT_ID('dbo._stg_Philote_SnippetPrimitives','U') IS NOT NULL DROP TABLE dbo._stg_Philote_SnippetPrimitives;
IF OBJECT_ID('dbo._stg_RulePrimitive_Snippets','U') IS NOT NULL DROP TABLE dbo._stg_RulePrimitive_Snippets;
IF OBJECT_ID('dbo._stg_Philote_SnippetRules','U') IS NOT NULL DROP TABLE dbo._stg_Philote_SnippetRules;
IF OBJECT_ID('dbo._stg_Rule_Snippets','U') IS NOT NULL DROP TABLE dbo._stg_Rule_Snippets;
IF OBJECT_ID('dbo._stg_Philote_SnippetRuleSets','U') IS NOT NULL DROP TABLE dbo._stg_Philote_SnippetRuleSets;
IF OBJECT_ID('dbo._stg_RuleSet_Snippets','U') IS NOT NULL DROP TABLE dbo._stg_RuleSet_Snippets;
IF OBJECT_ID('dbo._stg_Philote_PathPrimitives','U') IS NOT NULL DROP TABLE dbo._stg_Philote_PathPrimitives;
IF OBJECT_ID('dbo._stg_RulePrimitive_Paths','U') IS NOT NULL DROP TABLE dbo._stg_RulePrimitive_Paths;
IF OBJECT_ID('dbo._stg_Philote_PathRules','U') IS NOT NULL DROP TABLE dbo._stg_Philote_PathRules;
IF OBJECT_ID('dbo._stg_Rule_Paths','U') IS NOT NULL DROP TABLE dbo._stg_Rule_Paths;
IF OBJECT_ID('dbo._stg_Philote_PathInstantiations','U') IS NOT NULL DROP TABLE dbo._stg_Philote_PathInstantiations;
IF OBJECT_ID('dbo._stg_RuleInstantiation_Paths','U') IS NOT NULL DROP TABLE dbo._stg_RuleInstantiation_Paths;
IF OBJECT_ID('dbo._stg_RuleInstantiationBinding_Paths','U') IS NOT NULL DROP TABLE dbo._stg_RuleInstantiationBinding_Paths;

-- =====================================================================
-- SECTION 6: Validation and Summary
-- =====================================================================

PRINT '';
PRINT 'Validating row counts...';

-- Language and overall counts
DECLARE @LanguageCount int = (SELECT COUNT(*) FROM dbo.PrimitiveLanguageKind);
DECLARE @PhiloteCount int = (SELECT COUNT(*) FROM dbo.Philote);
DECLARE @RulePrimitiveCount int = (SELECT COUNT(*) FROM dbo.RulePrimitive);
DECLARE @RuleCount int = (SELECT COUNT(*) FROM dbo.[Rule]);
DECLARE @RuleSetCount int = (SELECT COUNT(*) FROM dbo.RuleSet);
DECLARE @InstantiationCount int = (SELECT COUNT(*) FROM dbo.RuleInstantiation);
DECLARE @BindingCount int = (SELECT COUNT(*) FROM dbo.RuleInstantiationBinding);

-- Per-language counts
DECLARE @CSharpPrimitiveCount int = (SELECT COUNT(*) FROM dbo.RulePrimitive WHERE PrimitiveLanguageKindId = 1);
DECLARE @PowershellPrimitiveCount int = (SELECT COUNT(*) FROM dbo.RulePrimitive WHERE PrimitiveLanguageKindId = 2);
DECLARE @SQLPrimitiveCount int = (SELECT COUNT(*) FROM dbo.RulePrimitive WHERE PrimitiveLanguageKindId = 3);
DECLARE @MSBuildPrimitiveCount int = (SELECT COUNT(*) FROM dbo.RulePrimitive WHERE PrimitiveLanguageKindId = 4);
DECLARE @SnippetPrimitiveCount int = (SELECT COUNT(*) FROM dbo.RulePrimitive WHERE PrimitiveLanguageKindId = 5);
DECLARE @PathPrimitiveCount int = (SELECT COUNT(*) FROM dbo.RulePrimitive WHERE PrimitiveLanguageKindId = 6);

DECLARE @SnippetRuleCount int = (SELECT COUNT(*) FROM dbo.[Rule] WHERE PrimitiveLanguageKindId = 5);
DECLARE @PathRuleCount int = (SELECT COUNT(*) FROM dbo.[Rule] WHERE PrimitiveLanguageKindId = 6);

-- Validation checks
IF @LanguageCount < 6
    THROW 50010, 'PrimitiveLanguageKind row count below expected (6)', 1;
IF @PhiloteCount < 101
    THROW 50011, 'Philote row count below minimum expected (101 = 69 primitives + 42 rules + 3 rulesets + 1 instantiation)', 1;
IF @RulePrimitiveCount < 69
    THROW 50012, 'RulePrimitive row count below minimum expected (69 = 51 core + 6 snippet + 12 path)', 1;
IF @RuleCount < 42
    THROW 50013, 'Rule row count below minimum expected (42 = 24 core + 17 snippet + 1 path)', 1;
IF @RuleSetCount < 3
    THROW 50014, 'RuleSet row count below minimum expected (3)', 1;
IF @InstantiationCount < 1
    THROW 50015, 'RuleInstantiation row count below minimum expected (1)', 1;
IF @BindingCount < 4
    THROW 50016, 'RuleInstantiationBinding row count below minimum expected (4)', 1;

-- Snippet validation
IF @SnippetPrimitiveCount < 6
    THROW 50020, 'Snippet RulePrimitive row count below minimum expected (6)', 1;
IF @SnippetRuleCount < 17
    THROW 50021, 'Snippet Rule row count below minimum expected (17)', 1;

-- Path validation
IF @PathPrimitiveCount < 12
    THROW 50030, 'Path RulePrimitive row count below minimum expected (12)', 1;
IF @PathRuleCount < 1
    THROW 50031, 'Path Rule row count below minimum expected (1)', 1;

PRINT '';
PRINT '========================================';
PRINT 'RRSBS Data Load Complete';
PRINT '========================================';
PRINT 'Languages:             ' + CAST(@LanguageCount AS nvarchar(10)) + ' (CSharp, Powershell, SQL, MSBuild, Snippet, Path)';
PRINT 'Total Philote GUIDs:   ' + CAST(@PhiloteCount AS nvarchar(10));
PRINT 'Total Rule Primitives: ' + CAST(@RulePrimitiveCount AS nvarchar(10));
PRINT '  - CSharp:            ' + CAST(@CSharpPrimitiveCount AS nvarchar(10));
PRINT '  - Powershell:        ' + CAST(@PowershellPrimitiveCount AS nvarchar(10));
PRINT '  - SQL:               ' + CAST(@SQLPrimitiveCount AS nvarchar(10));
PRINT '  - MSBuild:           ' + CAST(@MSBuildPrimitiveCount AS nvarchar(10));
PRINT '  - Snippet:           ' + CAST(@SnippetPrimitiveCount AS nvarchar(10));
PRINT '  - Path:              ' + CAST(@PathPrimitiveCount AS nvarchar(10));
PRINT 'Total Rules:           ' + CAST(@RuleCount AS nvarchar(10));
PRINT '  - Snippet Rules:     ' + CAST(@SnippetRuleCount AS nvarchar(10));
PRINT '  - Path Rules:        ' + CAST(@PathRuleCount AS nvarchar(10));
PRINT 'Total Rule Sets:       ' + CAST(@RuleSetCount AS nvarchar(10));
PRINT 'Total Instantiations:  ' + CAST(@InstantiationCount AS nvarchar(10));
PRINT 'Total Bindings:        ' + CAST(@BindingCount AS nvarchar(10));
PRINT '========================================';

COMMIT;
GO



-- =====================================================================
-- V00.01.000020__Load_ATAPUtilities_Data_From_BCP.sql
--
-- Loads all RRSBS seed data from CSV files via BULK INSERT:
--
-- LANGUAGE-SPECIFIC DATA:
-- CSHARP DATA:
--   1. CSharp_Philote_Primitives.csv      → dbo.Philote       (18 GUIDs)
--   2. CSharp_RulePrimitives.csv          → dbo.RulePrimitive (18 primitives)
--   3. CSharp_Philote_Rules.csv           → dbo.Philote       (7 GUIDs)
--   4. CSharp_Rules.csv                   → dbo.Rule          (7 rules)
--
-- POWERSHELL DATA:
--   5. Powershell_Philote_Primitives.csv  → dbo.Philote       (2 GUIDs)
--   6. Powershell_RulePrimitives.csv      → dbo.RulePrimitive (2 primitives)
--
-- SQL DATA:
--   7. SQL_Philote_Primitives.csv         → dbo.Philote       (23 GUIDs)
--   8. SQL_RulePrimitives.csv             → dbo.RulePrimitive (23 primitives)
--   9. SQL_Philote_Rules.csv              → dbo.Philote       (3 GUIDs)
--  10. SQL_Rules.csv                      → dbo.Rule          (3 rules)
--
-- MSBUILD DATA:
--  11. MSBuild_Philote_Primitives.csv     → dbo.Philote       (8 GUIDs)
--  12. MSBuild_RulePrimitives.csv         → dbo.RulePrimitive (8 primitives)
--  13. MSBuild_Philote_Rules.csv          → dbo.Philote       (14 GUIDs)
--  14. MSBuild_Rules.csv                  → dbo.Rule          (14 rules)
--
-- SNIPPET DATA:
--  15. Snippet_Philote_Primitives.csv     → dbo.Philote       (6 GUIDs)
--  16. Snippet_RulePrimitives.csv         → dbo.RulePrimitive (6 primitives)
--  17. Snippet_Philote_Rules.csv          → dbo.Philote       (17 GUIDs)
--  18. Snippet_Rules.csv                  → dbo.Rule          (17 rules)
--  19. Snippet_Philote_RuleSets.csv       → dbo.Philote       (3 GUIDs)
--  20. Snippet_RuleSets.csv               → dbo.RuleSet       (3 rule sets)
--
-- PATH DATA:
--  21. Path_Philote_Primitives.csv        → dbo.Philote                   (12 GUIDs)
--  22. Path_RulePrimitives.csv            → dbo.RulePrimitive             (12 primitives)
--  23. Path_Philote_Rules.csv             → dbo.Philote                   (1 GUID)
--  24. Path_Rules.csv                     → dbo.Rule                      (1 rule)
--  25. Path_Philote_Instantiations.csv    → dbo.Philote                   (1 GUID)
--  26. Path_Instantiations.csv            → dbo.RuleInstantiation         (1 instantiation)
--  27. Path_InstantiationBindings.csv     → dbo.RuleInstantiationBinding  (4 bindings)
--
-- TOTALS: 69 primitives (18+2+23+8+6+12), 42 rules (7+3+14+17+1), 3 rule sets, 1 instantiation, 4 bindings
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

-- CSharp data files
DECLARE @philote_csharp_primitives_file nvarchar(4000) = @data_dir + N'\CSharp_Philote_Primitives.csv';
DECLARE @rule_primitive_csharp_file nvarchar(4000) = @data_dir + N'\CSharp_RulePrimitives.csv';
DECLARE @philote_csharp_rules_file nvarchar(4000) = @data_dir + N'\CSharp_Philote_Rules.csv';
DECLARE @rule_csharp_file nvarchar(4000) = @data_dir + N'\CSharp_Rules.csv';

-- Powershell data files
DECLARE @philote_powershell_primitives_file nvarchar(4000) = @data_dir + N'\Powershell_Philote_Primitives.csv';
DECLARE @rule_primitive_powershell_file nvarchar(4000) = @data_dir + N'\Powershell_RulePrimitives.csv';
-- Note: No Powershell_Philote_Rules.csv or Powershell_Rules.csv (no rules exist for Powershell)

-- SQL data files
DECLARE @philote_sql_primitives_file nvarchar(4000) = @data_dir + N'\SQL_Philote_Primitives.csv';
DECLARE @rule_primitive_sql_file nvarchar(4000) = @data_dir + N'\SQL_RulePrimitives.csv';
DECLARE @philote_sql_rules_file nvarchar(4000) = @data_dir + N'\SQL_Philote_Rules.csv';
DECLARE @rule_sql_file nvarchar(4000) = @data_dir + N'\SQL_Rules.csv';

-- MSBuild data files
DECLARE @philote_msbuild_primitives_file nvarchar(4000) = @data_dir + N'\MSBuild_Philote_Primitives.csv';
DECLARE @rule_primitive_msbuild_file nvarchar(4000) = @data_dir + N'\MSBuild_RulePrimitives.csv';
DECLARE @philote_msbuild_rules_file nvarchar(4000) = @data_dir + N'\MSBuild_Philote_Rules.csv';
DECLARE @rule_msbuild_file nvarchar(4000) = @data_dir + N'\MSBuild_Rules.csv';

-- Snippet data files
DECLARE @philote_snippet_primitives_file nvarchar(4000) = @data_dir + N'\Snippet_Philote_Primitives.csv';
DECLARE @rule_primitive_snippets_file nvarchar(4000) = @data_dir + N'\Snippet_RulePrimitives.csv';
DECLARE @philote_snippet_rules_file nvarchar(4000) = @data_dir + N'\Snippet_Philote_Rules.csv';
DECLARE @rule_snippets_file nvarchar(4000) = @data_dir + N'\Snippet_Rules.csv';
DECLARE @philote_snippet_rulesets_file nvarchar(4000) = @data_dir + N'\Snippet_Philote_RuleSets.csv';
DECLARE @ruleset_snippets_file nvarchar(4000) = @data_dir + N'\Snippet_RuleSets.csv';

-- Path data files
DECLARE @philote_path_primitives_file nvarchar(4000) = @data_dir + N'\Path_Philote_Primitives.csv';
DECLARE @rule_primitive_paths_file nvarchar(4000) = @data_dir + N'\Path_RulePrimitives.csv';
DECLARE @philote_path_rules_file nvarchar(4000) = @data_dir + N'\Path_Philote_Rules.csv';
DECLARE @rule_paths_file nvarchar(4000) = @data_dir + N'\Path_Rules.csv';
DECLARE @philote_path_instantiations_file nvarchar(4000) = @data_dir + N'\Path_Philote_Instantiations.csv';
DECLARE @rule_instantiation_paths_file nvarchar(4000) = @data_dir + N'\Path_Instantiations.csv';
DECLARE @rule_instantiation_binding_paths_file nvarchar(4000) = @data_dir + N'\Path_InstantiationBindings.csv';

-- =====================================================================
-- SECTION 1: Create Staging Tables
-- =====================================================================

PRINT 'Creating staging tables...';

-- CSharp staging tables
IF OBJECT_ID('dbo._stg_CSharp_Philote_Primitives','U') IS NOT NULL DROP TABLE dbo._stg_CSharp_Philote_Primitives;
CREATE TABLE dbo._stg_CSharp_Philote_Primitives (
    PhiloteId nvarchar(50) NOT NULL,
    Comment nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_CSharp_RulePrimitive','U') IS NOT NULL DROP TABLE dbo._stg_CSharp_RulePrimitive;
CREATE TABLE dbo._stg_CSharp_RulePrimitive (
    PhiloteId nvarchar(50) NOT NULL,
    PrimitiveLanguageKindId nvarchar(10) NOT NULL,
    [Name] nvarchar(200) NOT NULL,
    [Description] nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_CSharp_Philote_Rules','U') IS NOT NULL DROP TABLE dbo._stg_CSharp_Philote_Rules;
CREATE TABLE dbo._stg_CSharp_Philote_Rules (
    PhiloteId nvarchar(50) NOT NULL,
    Comment nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_CSharp_Rule','U') IS NOT NULL DROP TABLE dbo._stg_CSharp_Rule;
CREATE TABLE dbo._stg_CSharp_Rule (
    PhiloteId nvarchar(50) NOT NULL,
    PrimitiveLanguageKindId nvarchar(10) NOT NULL,
    [Name] nvarchar(200) NOT NULL,
    Purpose nvarchar(500) NULL,
    SourceFileReference nvarchar(500) NULL
);

-- Powershell staging tables
IF OBJECT_ID('dbo._stg_Powershell_Philote_Primitives','U') IS NOT NULL DROP TABLE dbo._stg_Powershell_Philote_Primitives;
CREATE TABLE dbo._stg_Powershell_Philote_Primitives (
    PhiloteId nvarchar(50) NOT NULL,
    Comment nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_Powershell_RulePrimitive','U') IS NOT NULL DROP TABLE dbo._stg_Powershell_RulePrimitive;
CREATE TABLE dbo._stg_Powershell_RulePrimitive (
    PhiloteId nvarchar(50) NOT NULL,
    PrimitiveLanguageKindId nvarchar(10) NOT NULL,
    [Name] nvarchar(200) NOT NULL,
    [Description] nvarchar(500) NULL
);

-- SQL staging tables
IF OBJECT_ID('dbo._stg_SQL_Philote_Primitives','U') IS NOT NULL DROP TABLE dbo._stg_SQL_Philote_Primitives;
CREATE TABLE dbo._stg_SQL_Philote_Primitives (
    PhiloteId nvarchar(50) NOT NULL,
    Comment nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_SQL_RulePrimitive','U') IS NOT NULL DROP TABLE dbo._stg_SQL_RulePrimitive;
CREATE TABLE dbo._stg_SQL_RulePrimitive (
    PhiloteId nvarchar(50) NOT NULL,
    PrimitiveLanguageKindId nvarchar(10) NOT NULL,
    [Name] nvarchar(200) NOT NULL,
    [Description] nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_SQL_Philote_Rules','U') IS NOT NULL DROP TABLE dbo._stg_SQL_Philote_Rules;
CREATE TABLE dbo._stg_SQL_Philote_Rules (
    PhiloteId nvarchar(50) NOT NULL,
    Comment nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_SQL_Rule','U') IS NOT NULL DROP TABLE dbo._stg_SQL_Rule;
CREATE TABLE dbo._stg_SQL_Rule (
    PhiloteId nvarchar(50) NOT NULL,
    PrimitiveLanguageKindId nvarchar(10) NOT NULL,
    [Name] nvarchar(200) NOT NULL,
    Purpose nvarchar(500) NULL,
    SourceFileReference nvarchar(500) NULL
);

-- MSBuild staging tables
IF OBJECT_ID('dbo._stg_MSBuild_Philote_Primitives','U') IS NOT NULL DROP TABLE dbo._stg_MSBuild_Philote_Primitives;
CREATE TABLE dbo._stg_MSBuild_Philote_Primitives (
    PhiloteId nvarchar(50) NOT NULL,
    Comment nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_MSBuild_RulePrimitive','U') IS NOT NULL DROP TABLE dbo._stg_MSBuild_RulePrimitive;
CREATE TABLE dbo._stg_MSBuild_RulePrimitive (
    PhiloteId nvarchar(50) NOT NULL,
    PrimitiveLanguageKindId nvarchar(10) NOT NULL,
    [Name] nvarchar(200) NOT NULL,
    [Description] nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_MSBuild_Philote_Rules','U') IS NOT NULL DROP TABLE dbo._stg_MSBuild_Philote_Rules;
CREATE TABLE dbo._stg_MSBuild_Philote_Rules (
    PhiloteId nvarchar(50) NOT NULL,
    Comment nvarchar(500) NULL
);

IF OBJECT_ID('dbo._stg_MSBuild_Rule','U') IS NOT NULL DROP TABLE dbo._stg_MSBuild_Rule;
CREATE TABLE dbo._stg_MSBuild_Rule (
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
PRINT 'Loading CSharp RRSBS Data';
PRINT '========================================';

/* --- Load CSharp Philote_Primitives --- */
PRINT 'Loading CSharp_Philote_Primitives.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_CSharp_Philote_Primitives
    FROM ' + QUOTENAME(@philote_csharp_primitives_file,'''') + N'
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
    DECLARE @ErrorMessage nvarchar(4000) = 'CSharp_Philote_Primitives: ' + ERROR_MESSAGE();
    THROW 50001, @ErrorMessage, 1;
END CATCH

/* --- Load CSharp RulePrimitive --- */
PRINT 'Loading CSharp_RulePrimitives.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_CSharp_RulePrimitive
    FROM ' + QUOTENAME(@rule_primitive_csharp_file,'''') + N'
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
    SET @ErrorMessage = 'CSharp_RulePrimitives: ' + ERROR_MESSAGE();
    THROW 50002, @ErrorMessage, 1;
END CATCH

/* --- Load CSharp Philote_Rules --- */
PRINT 'Loading CSharp_Philote_Rules.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_CSharp_Philote_Rules
    FROM ' + QUOTENAME(@philote_csharp_rules_file,'''') + N'
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
    SET @ErrorMessage = 'CSharp_Philote_Rules: ' + ERROR_MESSAGE();
    THROW 50003, @ErrorMessage, 1;
END CATCH

/* --- Load CSharp Rule --- */
PRINT 'Loading CSharp_Rules.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_CSharp_Rule
    FROM ' + QUOTENAME(@rule_csharp_file,'''') + N'
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
    SET @ErrorMessage = 'CSharp_Rules: ' + ERROR_MESSAGE();
    THROW 50004, @ErrorMessage, 1;
END CATCH

PRINT '';
PRINT '========================================';
PRINT 'Loading Powershell RRSBS Data';
PRINT '========================================';

/* --- Load Powershell Philote_Primitives --- */
PRINT 'Loading Powershell_Philote_Primitives.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_Powershell_Philote_Primitives
    FROM ' + QUOTENAME(@philote_powershell_primitives_file,'''') + N'
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
    SET @ErrorMessage = 'Powershell_Philote_Primitives: ' + ERROR_MESSAGE();
    THROW 50005, @ErrorMessage, 1;
END CATCH

/* --- Load Powershell RulePrimitive --- */
PRINT 'Loading Powershell_RulePrimitives.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_Powershell_RulePrimitive
    FROM ' + QUOTENAME(@rule_primitive_powershell_file,'''') + N'
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
    SET @ErrorMessage = 'Powershell_RulePrimitives: ' + ERROR_MESSAGE();
    THROW 50006, @ErrorMessage, 1;
END CATCH

PRINT '';
PRINT '========================================';
PRINT 'Loading SQL RRSBS Data';
PRINT '========================================';

/* --- Load SQL Philote_Primitives --- */
PRINT 'Loading SQL_Philote_Primitives.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_SQL_Philote_Primitives
    FROM ' + QUOTENAME(@philote_sql_primitives_file,'''') + N'
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
    SET @ErrorMessage = 'SQL_Philote_Primitives: ' + ERROR_MESSAGE();
    THROW 50007, @ErrorMessage, 1;
END CATCH

/* --- Load SQL RulePrimitive --- */
PRINT 'Loading SQL_RulePrimitives.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_SQL_RulePrimitive
    FROM ' + QUOTENAME(@rule_primitive_sql_file,'''') + N'
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
    SET @ErrorMessage = 'SQL_RulePrimitives: ' + ERROR_MESSAGE();
    THROW 50008, @ErrorMessage, 1;
END CATCH

/* --- Load SQL Philote_Rules --- */
PRINT 'Loading SQL_Philote_Rules.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_SQL_Philote_Rules
    FROM ' + QUOTENAME(@philote_sql_rules_file,'''') + N'
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
    SET @ErrorMessage = 'SQL_Philote_Rules: ' + ERROR_MESSAGE();
    THROW 50009, @ErrorMessage, 1;
END CATCH

/* --- Load SQL Rule --- */
PRINT 'Loading SQL_Rules.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_SQL_Rule
    FROM ' + QUOTENAME(@rule_sql_file,'''') + N'
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
    SET @ErrorMessage = 'SQL_Rules: ' + ERROR_MESSAGE();
    THROW 50010, @ErrorMessage, 1;
END CATCH

PRINT '';
PRINT '========================================';
PRINT 'Loading MSBuild RRSBS Data';
PRINT '========================================';

/* --- Load MSBuild Philote_Primitives --- */
PRINT 'Loading MSBuild_Philote_Primitives.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_MSBuild_Philote_Primitives
    FROM ' + QUOTENAME(@philote_msbuild_primitives_file,'''') + N'
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
    SET @ErrorMessage = 'MSBuild_Philote_Primitives: ' + ERROR_MESSAGE();
    THROW 50011, @ErrorMessage, 1;
END CATCH

/* --- Load MSBuild RulePrimitive --- */
PRINT 'Loading MSBuild_RulePrimitives.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_MSBuild_RulePrimitive
    FROM ' + QUOTENAME(@rule_primitive_msbuild_file,'''') + N'
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
    SET @ErrorMessage = 'MSBuild_RulePrimitives: ' + ERROR_MESSAGE();
    THROW 50012, @ErrorMessage, 1;
END CATCH

/* --- Load MSBuild Philote_Rules --- */
PRINT 'Loading MSBuild_Philote_Rules.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_MSBuild_Philote_Rules
    FROM ' + QUOTENAME(@philote_msbuild_rules_file,'''') + N'
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
    SET @ErrorMessage = 'MSBuild_Philote_Rules: ' + ERROR_MESSAGE();
    THROW 50013, @ErrorMessage, 1;
END CATCH

/* --- Load MSBuild Rule --- */
PRINT 'Loading MSBuild_Rules.csv...';
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_MSBuild_Rule
    FROM ' + QUOTENAME(@rule_msbuild_file,'''') + N'
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
    SET @ErrorMessage = 'MSBuild_Rules: ' + ERROR_MESSAGE();
    THROW 50014, @ErrorMessage, 1;
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
    THROW 50015, @ErrorMessage, 1;
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
    THROW 50016, @ErrorMessage, 1;
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
    THROW 50017, @ErrorMessage, 1;
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
    THROW 50018, @ErrorMessage, 1;
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
    THROW 50019, @ErrorMessage, 1;
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
    THROW 50020, @ErrorMessage, 1;
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
    THROW 50021, @ErrorMessage, 1;
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
    THROW 50022, @ErrorMessage, 1;
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
    THROW 50023, @ErrorMessage, 1;
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
    THROW 50024, @ErrorMessage, 1;
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
    THROW 50025, @ErrorMessage, 1;
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
    THROW 50026, @ErrorMessage, 1;
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
    THROW 50027, @ErrorMessage, 1;
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
PRINT 'Inserting Language-Specific RRSBS Data';
PRINT '========================================';

PRINT 'Inserting Philote entries for primitives from all languages...';
INSERT INTO dbo.Philote (PhiloteId)
SELECT TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId)))
FROM dbo._stg_CSharp_Philote_Primitives
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
UNION ALL
SELECT TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId)))
FROM dbo._stg_Powershell_Philote_Primitives
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
UNION ALL
SELECT TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId)))
FROM dbo._stg_SQL_Philote_Primitives
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
UNION ALL
SELECT TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId)))
FROM dbo._stg_MSBuild_Philote_Primitives
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL;
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' Philote GUIDs for primitives.';

PRINT 'Inserting RulePrimitive entries from all languages...';
INSERT INTO dbo.RulePrimitive (PhiloteId, PrimitiveLanguageKindId, [Name], [Description])
SELECT
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))),
    TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))),
    NULLIF(LTRIM(RTRIM([Name])),''),
    NULLIF(LTRIM(RTRIM([Description])),'')
FROM dbo._stg_CSharp_RulePrimitive
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))) IS NOT NULL
  AND NULLIF(LTRIM(RTRIM([Name])),'') IS NOT NULL
UNION ALL
SELECT
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))),
    TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))),
    NULLIF(LTRIM(RTRIM([Name])),''),
    NULLIF(LTRIM(RTRIM([Description])),'')
FROM dbo._stg_Powershell_RulePrimitive
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))) IS NOT NULL
  AND NULLIF(LTRIM(RTRIM([Name])),'') IS NOT NULL
UNION ALL
SELECT
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))),
    TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))),
    NULLIF(LTRIM(RTRIM([Name])),''),
    NULLIF(LTRIM(RTRIM([Description])),'')
FROM dbo._stg_SQL_RulePrimitive
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))) IS NOT NULL
  AND NULLIF(LTRIM(RTRIM([Name])),'') IS NOT NULL
UNION ALL
SELECT
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))),
    TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))),
    NULLIF(LTRIM(RTRIM([Name])),''),
    NULLIF(LTRIM(RTRIM([Description])),'')
FROM dbo._stg_MSBuild_RulePrimitive
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))) IS NOT NULL
  AND NULLIF(LTRIM(RTRIM([Name])),'') IS NOT NULL;
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' RulePrimitive records.';

PRINT 'Inserting Philote entries for rules from all languages...';
INSERT INTO dbo.Philote (PhiloteId)
SELECT TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId)))
FROM dbo._stg_CSharp_Philote_Rules
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
UNION ALL
SELECT TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId)))
FROM dbo._stg_SQL_Philote_Rules
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
UNION ALL
SELECT TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId)))
FROM dbo._stg_MSBuild_Philote_Rules
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL;
PRINT '  Inserted: ' + CAST(@@ROWCOUNT AS nvarchar(10)) + ' Philote GUIDs for rules.';

PRINT 'Inserting Rule entries from all languages...';
INSERT INTO dbo.[Rule] (PhiloteId, PrimitiveLanguageKindId, [Name], Purpose, SourceFileReference)
SELECT
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))),
    TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))),
    NULLIF(LTRIM(RTRIM([Name])),''),
    NULLIF(LTRIM(RTRIM(Purpose)),''),
    NULLIF(LTRIM(RTRIM(SourceFileReference)),'')
FROM dbo._stg_CSharp_Rule
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))) IS NOT NULL
  AND NULLIF(LTRIM(RTRIM([Name])),'') IS NOT NULL
UNION ALL
SELECT
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))),
    TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))),
    NULLIF(LTRIM(RTRIM([Name])),''),
    NULLIF(LTRIM(RTRIM(Purpose)),''),
    NULLIF(LTRIM(RTRIM(SourceFileReference)),'')
FROM dbo._stg_SQL_Rule
WHERE TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))) IS NOT NULL
  AND TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))) IS NOT NULL
  AND NULLIF(LTRIM(RTRIM([Name])),'') IS NOT NULL
UNION ALL
SELECT
    TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(PhiloteId))),
    TRY_CONVERT(int, LTRIM(RTRIM(PrimitiveLanguageKindId))),
    NULLIF(LTRIM(RTRIM([Name])),''),
    NULLIF(LTRIM(RTRIM(Purpose)),''),
    NULLIF(LTRIM(RTRIM(SourceFileReference)),'')
FROM dbo._stg_MSBuild_Rule
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
IF @PhiloteCount < 115
    THROW 50011, 'Philote row count below minimum expected (115 = 69 primitives + 42 rules + 3 rulesets + 1 instantiation)', 1;
IF @RulePrimitiveCount < 69
    THROW 50012, 'RulePrimitive row count below minimum expected (69 = 18 CSharp + 2 Powershell + 23 SQL + 8 MSBuild + 6 snippet + 12 path)', 1;
IF @RuleCount < 42
    THROW 50013, 'Rule row count below minimum expected (42 = 7 CSharp + 3 SQL + 14 MSBuild + 17 snippet + 1 path)', 1;
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



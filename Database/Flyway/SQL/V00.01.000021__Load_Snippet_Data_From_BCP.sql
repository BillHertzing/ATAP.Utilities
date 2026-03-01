-- =====================================================================
-- V00.01.000021__Load_Snippet_Data_From_BCP.sql
--
-- Loads Snippet Rule data from CSV files via BULK INSERT:
--   1. Philote_SnippetPrimitives.csv  → dbo.Philote         (6 GUIDs)
--   2. RulePrimitive_Snippets.csv     → dbo.RulePrimitive   (6 primitives)
--   3. Philote_SnippetRules.csv       → dbo.Philote         (17 GUIDs)
--   4. Rule_Snippets.csv              → dbo.[Rule]          (17 rules)
--   5. Philote_SnippetRuleSets.csv    → dbo.Philote         (3 GUIDs)
--   6. RuleSet_Snippets.csv           → dbo.RuleSet         (3 rule sets)
--
-- Prerequisites:
--   - V00.01.000010 (core schema)
--   - V00.01.000011 (Snippet language kind added)
--   - CSV files present in ${data_dir}
-- =====================================================================

SET XACT_ABORT ON;
SET NOCOUNT ON;
BEGIN TRAN;

DECLARE @data_dir nvarchar(4000) = N'${data_dir}';
DECLARE @sql nvarchar(max);
DECLARE @philote_snippet_primitives_file nvarchar(4000) = @data_dir + N'\Philote_SnippetPrimitives.csv';
DECLARE @rule_primitive_snippets_file nvarchar(4000) = @data_dir + N'\RulePrimitive_Snippets.csv';
DECLARE @philote_snippet_rules_file nvarchar(4000) = @data_dir + N'\Philote_SnippetRules.csv';
DECLARE @rule_snippets_file nvarchar(4000) = @data_dir + N'\Rule_Snippets.csv';
DECLARE @philote_snippet_rulesets_file nvarchar(4000) = @data_dir + N'\Philote_SnippetRuleSets.csv';
DECLARE @ruleset_snippets_file nvarchar(4000) = @data_dir + N'\RuleSet_Snippets.csv';

-- =====================================================================
-- SECTION 1: Create Staging Tables
-- =====================================================================

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

-- =====================================================================
-- SECTION 2: BULK INSERT from CSV Files
-- =====================================================================

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
    DECLARE @ErrorMessage nvarchar(4000) = 'Philote_SnippetPrimitives: ' + ERROR_MESSAGE();
    THROW 50001, @ErrorMessage, 1;
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
    THROW 50002, @ErrorMessage, 1;
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
    THROW 50003, @ErrorMessage, 1;
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
    THROW 50004, @ErrorMessage, 1;
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
    THROW 50005, @ErrorMessage, 1;
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
    THROW 50006, @ErrorMessage, 1;
END CATCH

-- =====================================================================
-- SECTION 3: Load Production Tables
-- =====================================================================

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

-- =====================================================================
-- SECTION 4: Cleanup Staging Tables
-- =====================================================================

PRINT 'Cleaning up staging tables...';
IF OBJECT_ID('dbo._stg_Philote_SnippetPrimitives','U') IS NOT NULL DROP TABLE dbo._stg_Philote_SnippetPrimitives;
IF OBJECT_ID('dbo._stg_RulePrimitive_Snippets','U') IS NOT NULL DROP TABLE dbo._stg_RulePrimitive_Snippets;
IF OBJECT_ID('dbo._stg_Philote_SnippetRules','U') IS NOT NULL DROP TABLE dbo._stg_Philote_SnippetRules;
IF OBJECT_ID('dbo._stg_Rule_Snippets','U') IS NOT NULL DROP TABLE dbo._stg_Rule_Snippets;
IF OBJECT_ID('dbo._stg_Philote_SnippetRuleSets','U') IS NOT NULL DROP TABLE dbo._stg_Philote_SnippetRuleSets;
IF OBJECT_ID('dbo._stg_RuleSet_Snippets','U') IS NOT NULL DROP TABLE dbo._stg_RuleSet_Snippets;

-- =====================================================================
-- SECTION 5: Validation and Summary
-- =====================================================================

PRINT 'Validating row counts...';
DECLARE @SnippetPrimitiveCount int = (SELECT COUNT(*) FROM dbo.RulePrimitive WHERE PrimitiveLanguageKindId = 5);
DECLARE @SnippetRuleCount int = (SELECT COUNT(*) FROM dbo.[Rule] WHERE PrimitiveLanguageKindId = 5);
DECLARE @SnippetRuleSetCount int = (SELECT COUNT(*) FROM dbo.RuleSet);

IF @SnippetPrimitiveCount < 6
    THROW 50010, 'Snippet RulePrimitive row count below minimum expected (6)', 1;
IF @SnippetRuleCount < 17
    THROW 50011, 'Snippet Rule row count below minimum expected (17)', 1;
IF @SnippetRuleSetCount < 3
    THROW 50012, 'Snippet RuleSet row count below minimum expected (3)', 1;

PRINT '';
PRINT '========================================';
PRINT 'Snippet Data Load Complete';
PRINT '========================================';
PRINT 'Snippet Primitives: ' + CAST(@SnippetPrimitiveCount AS nvarchar(10));
PRINT 'Snippet Rules:      ' + CAST(@SnippetRuleCount AS nvarchar(10));
PRINT 'Snippet Rule Sets:  ' + CAST(@SnippetRuleSetCount AS nvarchar(10));
PRINT '========================================';

COMMIT;
GO

-- =====================================================================
-- V00.01.000022__Load_Path_Data_From_BCP.sql
--
-- Loads Path Rule data from CSV files via BULK INSERT:
--   1. Philote_PathPrimitives.csv         → dbo.Philote             (12 GUIDs)
--   2. RulePrimitive_Paths.csv            → dbo.RulePrimitive       (12 primitives)
--   3. Philote_PathRules.csv              → dbo.Philote             (1 GUID)
--   4. Rule_Paths.csv                     → dbo.[Rule]              (1 rule)
--   5. Philote_PathInstantiations.csv     → dbo.Philote             (1 GUID)
--   6. RuleInstantiation_Paths.csv        → dbo.RuleInstantiation   (1 instantiation)
--   7. RuleInstantiationBinding_Paths.csv → dbo.RuleInstantiationBinding (4 bindings)
--
-- Prerequisites:
--   - V00.01.000010 (core schema)
--   - V00.01.000012 (Path language kind added)
--   - CSV files present in ${data_dir}
-- =====================================================================

SET XACT_ABORT ON;
SET NOCOUNT ON;
BEGIN TRAN;

DECLARE @data_dir nvarchar(4000) = N'${data_dir}';
DECLARE @sql nvarchar(max);
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
    DECLARE @ErrorMessage nvarchar(4000) = 'Philote_PathPrimitives: ' + ERROR_MESSAGE();
    THROW 50001, @ErrorMessage, 1;
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
    THROW 50002, @ErrorMessage, 1;
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
    THROW 50003, @ErrorMessage, 1;
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
    THROW 50004, @ErrorMessage, 1;
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
    THROW 50005, @ErrorMessage, 1;
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
    THROW 50006, @ErrorMessage, 1;
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
    THROW 50007, @ErrorMessage, 1;
END CATCH

-- =====================================================================
-- SECTION 3: Load Production Tables
-- =====================================================================

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
-- SECTION 4: Cleanup Staging Tables
-- =====================================================================

PRINT 'Cleaning up staging tables...';
IF OBJECT_ID('dbo._stg_Philote_PathPrimitives','U') IS NOT NULL DROP TABLE dbo._stg_Philote_PathPrimitives;
IF OBJECT_ID('dbo._stg_RulePrimitive_Paths','U') IS NOT NULL DROP TABLE dbo._stg_RulePrimitive_Paths;
IF OBJECT_ID('dbo._stg_Philote_PathRules','U') IS NOT NULL DROP TABLE dbo._stg_Philote_PathRules;
IF OBJECT_ID('dbo._stg_Rule_Paths','U') IS NOT NULL DROP TABLE dbo._stg_Rule_Paths;
IF OBJECT_ID('dbo._stg_Philote_PathInstantiations','U') IS NOT NULL DROP TABLE dbo._stg_Philote_PathInstantiations;
IF OBJECT_ID('dbo._stg_RuleInstantiation_Paths','U') IS NOT NULL DROP TABLE dbo._stg_RuleInstantiation_Paths;
IF OBJECT_ID('dbo._stg_RuleInstantiationBinding_Paths','U') IS NOT NULL DROP TABLE dbo._stg_RuleInstantiationBinding_Paths;

-- =====================================================================
-- SECTION 5: Validation and Summary
-- =====================================================================

PRINT 'Validating row counts...';
DECLARE @PathPrimitiveCount int = (SELECT COUNT(*) FROM dbo.RulePrimitive WHERE PrimitiveLanguageKindId = 6);
DECLARE @PathRuleCount int = (SELECT COUNT(*) FROM dbo.[Rule] WHERE PrimitiveLanguageKindId = 6);
DECLARE @PathInstantiationCount int = (SELECT COUNT(*) FROM dbo.RuleInstantiation WHERE RulePhiloteId IN (
    SELECT PhiloteId FROM dbo.[Rule] WHERE PrimitiveLanguageKindId = 6
));
DECLARE @PathBindingCount int = (SELECT COUNT(*) FROM dbo.RuleInstantiationBinding WHERE InstantiationPhiloteId IN (
    SELECT PhiloteId FROM dbo.RuleInstantiation WHERE RulePhiloteId IN (
        SELECT PhiloteId FROM dbo.[Rule] WHERE PrimitiveLanguageKindId = 6
    )
));

IF @PathPrimitiveCount < 12
    THROW 50010, 'Path RulePrimitive row count below minimum expected (12)', 1;
IF @PathRuleCount < 1
    THROW 50011, 'Path Rule row count below minimum expected (1)', 1;
IF @PathInstantiationCount < 1
    THROW 50012, 'Path RuleInstantiation row count below minimum expected (1)', 1;
IF @PathBindingCount < 4
    THROW 50013, 'Path RuleInstantiationBinding row count below minimum expected (4)', 1;

PRINT '';
PRINT '========================================';
PRINT 'Path Data Load Complete';
PRINT '========================================';
PRINT 'Path Primitives:       ' + CAST(@PathPrimitiveCount AS nvarchar(10));
PRINT 'Path Rules:            ' + CAST(@PathRuleCount AS nvarchar(10));
PRINT 'Path Instantiations:   ' + CAST(@PathInstantiationCount AS nvarchar(10));
PRINT 'Path Bindings:         ' + CAST(@PathBindingCount AS nvarchar(10));
PRINT '========================================';

COMMIT;
GO

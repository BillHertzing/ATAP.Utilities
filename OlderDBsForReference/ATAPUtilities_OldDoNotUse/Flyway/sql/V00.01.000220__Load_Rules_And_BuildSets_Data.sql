/*
 * V00.01.000220__Load_Rules_And_BuildSets_Data.sql
 *
 * Loads SWIFTLY CHANGING data:
 *   - Rules (specific rule instances/configurations)
 *   - RuleSets
 *   - Map_RuleSet_Rule associations
 *   - BuildSets
 *   - BuildSetHavingRuleSet associations
 *
 * This data represents actual rules and their configurations that change
 * more frequently than the underlying language primitives.
 *
 * Rules may optionally reference RulePrimitives (loaded in V00.01.000210).
 */

USE [ATAPUtilities];
GO

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @data_dir nvarchar(4000) = N'${data_dir}';
DECLARE @sql nvarchar(max);

PRINT '=== Loading Swiftly Changing Data (Rules and BuildSets) ===';

/* --- Staging tables (all NVARCHAR) --- */
IF OBJECT_ID('dbo._stg_Rule','U')                      IS NOT NULL DROP TABLE dbo._stg_Rule;
IF OBJECT_ID('dbo._stg_RuleSet','U')                   IS NOT NULL DROP TABLE dbo._stg_RuleSet;
IF OBJECT_ID('dbo._stg_Map_RuleSet_Rule','U')          IS NOT NULL DROP TABLE dbo._stg_Map_RuleSet_Rule;
IF OBJECT_ID('dbo._stg_BuildSet','U')                  IS NOT NULL DROP TABLE dbo._stg_BuildSet;
IF OBJECT_ID('dbo._stg_BuildSetHavingRuleSet','U')     IS NOT NULL DROP TABLE dbo._stg_BuildSetHavingRuleSet;

CREATE TABLE dbo._stg_Rule(
  Id              nvarchar(20)  NULL,
  PhiloteID       nvarchar(40)  NULL,
  PrimitiveID     nvarchar(40)  NULL,
  ParentID        nvarchar(20)  NULL,
  PeerSortOrder   nvarchar(20)  NULL,
  SymbolicName    nvarchar(128) NULL,
  [Name]          nvarchar(512) NULL,
  Kind            nvarchar(512) NULL,
  Validity        nvarchar(50)  NULL,
  DisplayOrder    nvarchar(512) NULL,
  DisplayAction   nvarchar(512) NULL,
  InputAction     nvarchar(512) NULL,
  [Value]         nvarchar(512) NULL,
  Dirty           nvarchar(10)  NULL,
  IsActive        nvarchar(10)  NULL
);

CREATE TABLE dbo._stg_RuleSet(
  Id       nvarchar(20)  NULL,
  [Name]   nvarchar(512) NULL,
  Validity nvarchar(50)  NULL
);

CREATE TABLE dbo._stg_Map_RuleSet_Rule(
  Id         nvarchar(20) NULL,
  FK_RuleSet nvarchar(20) NULL,
  FK_Rule    nvarchar(20) NULL,
  SortOrder  nvarchar(20) NULL
);

CREATE TABLE dbo._stg_BuildSet(
  ID          nvarchar(20)  NULL,
  [Name]      nvarchar(100) NULL,
  Description nvarchar(500) NULL
);

CREATE TABLE dbo._stg_BuildSetHavingRuleSet(
  BuildSetID nvarchar(20) NULL,
  RuleSetID  nvarchar(20) NULL,
  SortOrder  nvarchar(20) NULL
);

/* --- BULK INSERTs --- */
PRINT 'Loading Rules...';
SET @sql = N'
BULK INSERT dbo._stg_Rule
FROM ''' + @data_dir + N'\Rule.csv''
WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', CODEPAGE=''65001'', TABLOCK);';
EXEC (@sql);

PRINT 'Loading RuleSets...';
SET @sql = N'
BULK INSERT dbo._stg_RuleSet
FROM ''' + @data_dir + N'\RuleSet.csv''
WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', CODEPAGE=''65001'', TABLOCK);';
EXEC (@sql);

PRINT 'Loading Rule-RuleSet mappings...';
SET @sql = N'
BULK INSERT dbo._stg_Map_RuleSet_Rule
FROM ''' + @data_dir + N'\Map_RuleSet_Rule.csv''
WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', CODEPAGE=''65001'', TABLOCK);';
EXEC (@sql);

PRINT 'Loading BuildSets...';
SET @sql = N'
BULK INSERT dbo._stg_BuildSet
FROM ''' + @data_dir + N'\BuildSet.csv''
WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', CODEPAGE=''65001'', TABLOCK);';
EXEC (@sql);

PRINT 'Loading BuildSet-RuleSet mappings...';
SET @sql = N'
BULK INSERT dbo._stg_BuildSetHavingRuleSet
FROM ''' + @data_dir + N'\BuildSetHavingRuleSet.csv''
WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', CODEPAGE=''65001'', TABLOCK);';
EXEC (@sql);

/* --- Move to typed tables --- */
PRINT 'Inserting Rule records...';
SET IDENTITY_INSERT dbo.[Rule] ON;
INSERT dbo.[Rule] (
  Id, PhiloteID, PrimitiveID, ParentID, PeerSortOrder, SymbolicName,
  [Name], Kind, Validity, DisplayOrder, DisplayAction, InputAction, [Value], Dirty, IsActive
)
SELECT
  CAST(Id AS int),
  CASE WHEN NULLIF(PhiloteID,'') IS NOT NULL THEN CAST(PhiloteID AS uniqueidentifier) ELSE NULL END,
  CASE WHEN NULLIF(PrimitiveID,'') IS NOT NULL THEN CAST(PrimitiveID AS uniqueidentifier) ELSE NULL END,
  CAST(NULLIF(ParentID,'') AS int),
  CAST(NULLIF(PeerSortOrder,'') AS int),
  SymbolicName,
  [Name],
  Kind,
  TRY_CAST(Validity AS datetime),
  DisplayOrder,
  DisplayAction,
  InputAction,
  [Value],
  CAST(ISNULL(Dirty,'0') AS bit),
  CAST(ISNULL(IsActive,'1') AS bit)
FROM dbo._stg_Rule;
SET IDENTITY_INSERT dbo.[Rule] OFF;

PRINT 'Inserting RuleSet records...';
SET IDENTITY_INSERT dbo.RuleSet ON;
INSERT dbo.RuleSet (Id, [Name], Validity)
SELECT
  CAST(Id AS int),
  [Name],
  TRY_CAST(Validity AS datetime)
FROM dbo._stg_RuleSet;
SET IDENTITY_INSERT dbo.RuleSet OFF;

PRINT 'Inserting RuleSet-Rule mappings...';
SET IDENTITY_INSERT dbo.Map_RuleSet_Rule ON;
INSERT dbo.Map_RuleSet_Rule (Id, FK_RuleSet, FK_Rule, SortOrder)
SELECT
  CAST(Id AS int),
  CAST(FK_RuleSet AS int),
  CAST(FK_Rule AS int),
  CAST(SortOrder AS int)
FROM dbo._stg_Map_RuleSet_Rule;
SET IDENTITY_INSERT dbo.Map_RuleSet_Rule OFF;

PRINT 'Inserting BuildSet records...';
SET IDENTITY_INSERT dbo.BuildSet ON;
INSERT dbo.BuildSet (ID, [Name], Description)
SELECT
  CAST(ID AS int),
  [Name],
  Description
FROM dbo._stg_BuildSet;
SET IDENTITY_INSERT dbo.BuildSet OFF;

PRINT 'Inserting BuildSet-RuleSet mappings...';
INSERT dbo.BuildSetHavingRuleSet (BuildSetID, RuleSetID, SortOrder)
SELECT
  CAST(BuildSetID AS int),
  CAST(RuleSetID AS int),
  CAST(SortOrder AS int)
FROM dbo._stg_BuildSetHavingRuleSet;

/* --- Data quality guardrails --- */
DECLARE @ruleCount int = (SELECT COUNT(*) FROM dbo.[Rule]);
DECLARE @ruleSetCount int = (SELECT COUNT(*) FROM dbo.RuleSet);
DECLARE @buildSetCount int = (SELECT COUNT(*) FROM dbo.BuildSet);

PRINT CONCAT('Loaded ', @ruleCount, ' Rules');
PRINT CONCAT('Loaded ', @ruleSetCount, ' RuleSets');
PRINT CONCAT('Loaded ', @buildSetCount, ' BuildSets');

IF @ruleCount < 1
  THROW 50101, 'Rule row count unexpected - no rules loaded', 1;

IF @ruleSetCount < 1
  THROW 50102, 'RuleSet row count unexpected - no rule sets loaded', 1;

-- Verify referential integrity for PrimitiveID (when present)
IF EXISTS (
  SELECT 1 FROM dbo.[Rule] r
  WHERE r.PrimitiveID IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM dbo.RulePrimitive rp WHERE rp.PhiloteID = r.PrimitiveID)
)
  THROW 50103, 'Rule referential integrity violation - invalid PrimitiveID found', 1;

-- Verify Philote linkage (when present)
IF EXISTS (
  SELECT 1 FROM dbo.[Rule] r
  WHERE r.PhiloteID IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM dbo.Philote p WHERE p.PhiloteID = r.PhiloteID)
)
  THROW 50104, 'Rule referential integrity violation - invalid PhiloteID found', 1;

-- Verify parent-child relationships
IF EXISTS (
  SELECT 1 FROM dbo.[Rule] r
  WHERE r.ParentID IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM dbo.[Rule] parent WHERE parent.Id = r.ParentID)
)
  THROW 50105, 'Rule referential integrity violation - invalid ParentID found', 1;

/* --- Cleanup staging tables --- */
DROP TABLE dbo._stg_BuildSetHavingRuleSet;
DROP TABLE dbo._stg_BuildSet;
DROP TABLE dbo._stg_Map_RuleSet_Rule;
DROP TABLE dbo._stg_RuleSet;
DROP TABLE dbo._stg_Rule;

COMMIT;

PRINT '=== Successfully loaded Rules, RuleSets, and BuildSets data (swiftly changing) ===';
GO

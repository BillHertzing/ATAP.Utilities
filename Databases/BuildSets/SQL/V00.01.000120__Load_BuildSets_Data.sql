/*
 * V00.01.000120__Load_BuildSets_Data.sql
 *
 * Loads BuildSet data:
 *   - BuildSets
 *   - BuildSetHavingRuleSet associations
 *
 * BuildSets are collections of RuleSets that define complete features/modules.
 * This data is loaded after RuleSets and Rules (V00.01.000040).
 */

USE BuildSets;
GO

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @data_dir nvarchar(4000) = N'${data_dir}';
DECLARE @sql nvarchar(max);

/* --- Staging tables (all NVARCHAR) --- */
IF OBJECT_ID('dbo._stg_BuildSet','U') IS NOT NULL DROP TABLE dbo._stg_BuildSet;
IF OBJECT_ID('dbo._stg_BuildSetHavingRuleSet','U') IS NOT NULL DROP TABLE dbo._stg_BuildSetHavingRuleSet;

CREATE TABLE dbo._stg_BuildSet(
  ID   nvarchar(20)  NULL,
  Name nvarchar(200) NULL
);

CREATE TABLE dbo._stg_BuildSetHavingRuleSet(
  BuildSetID nvarchar(20) NULL,
  RuleSetID  nvarchar(20) NULL
);

/* --- BULK INSERTs --- */
SET @sql = N'
BULK INSERT dbo._stg_BuildSet
FROM ''' + @data_dir + N'\BuildSet.csv''
WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', CODEPAGE=''65001'', TABLOCK);';
EXEC (@sql);

SET @sql = N'
BULK INSERT dbo._stg_BuildSetHavingRuleSet
FROM ''' + @data_dir + N'\BuildSetHavingRuleSet.csv''
WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', CODEPAGE=''65001'', TABLOCK);';
EXEC (@sql);

/* --- Move to typed tables --- */
INSERT dbo.BuildSet (ID, Name)
SELECT CAST(ID AS int), Name
FROM dbo._stg_BuildSet;

INSERT dbo.BuildSetHavingRuleSet (BuildSetID, RuleSetID)
SELECT CAST(BuildSetID AS int), CAST(RuleSetID AS int)
FROM dbo._stg_BuildSetHavingRuleSet;

/* --- Data quality guardrails --- */
IF (SELECT COUNT(*) FROM dbo.BuildSet) < 1
  THROW 51001, 'BuildSet row count unexpected (no rows inserted)', 1;

IF (SELECT COUNT(*) FROM dbo.BuildSetHavingRuleSet) < 0 -- replace with a >0 check or expected value when known
  THROW 51002, 'BuildSetHavingRuleSet row count unexpected', 1;

/* --- Cleanup staging --- */
DROP TABLE dbo._stg_BuildSetHavingRuleSet;
DROP TABLE dbo._stg_BuildSet;

COMMIT;

PRINT 'Successfully loaded BuildSet data';
GO


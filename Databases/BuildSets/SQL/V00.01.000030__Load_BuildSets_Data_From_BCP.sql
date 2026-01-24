SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @data_dir nvarchar(4000) = N'${data_dir}';
DECLARE @sql nvarchar(max);

/* --- Staging tables (all NVARCHAR) --- */
IF OBJECT_ID('dbo._stg_RuleSet','U')              IS NOT NULL DROP TABLE dbo._stg_RuleSet;
IF OBJECT_ID('dbo._stg_RuleItem','U')              IS NOT NULL DROP TABLE dbo._stg_RuleItem;
IF OBJECT_ID('dbo._stg_RuleSetHavingRuleItem','U')IS NOT NULL DROP TABLE dbo._stg_RuleSetHavingRuleItem;

CREATE TABLE dbo._stg_RuleSet(
  ID   nvarchar(20)  NULL,
  Name nvarchar(200) NULL
);

CREATE TABLE dbo._stg_RuleItem(
  ID            nvarchar(20)  NULL,
  ParentID      nvarchar(20)  NULL,
  PeerSortOrder nvarchar(20)  NULL,
  SymbolicName  nvarchar(128) NULL,
  ItemText      nvarchar(200) NULL
);

CREATE TABLE dbo._stg_RuleSetHavingRuleItem(
  RuleSetID  nvarchar(20) NULL,
  RuleItemID  nvarchar(20) NULL
);

/* --- BULK INSERTs --- */
SET @sql = N'
BULK INSERT dbo._stg_RuleSet
FROM ''' + @data_dir + N'\RuleSet.csv''
WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', CODEPAGE=''65001'', TABLOCK);';
EXEC (@sql);

SET @sql = N'
BULK INSERT dbo._stg_RuleItem
FROM ''' + @data_dir + N'\RuleItem.csv''
WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', CODEPAGE=''65001'', TABLOCK);';
EXEC (@sql);

SET @sql = N'
BULK INSERT dbo._stg_RuleSetHavingRuleItem
FROM ''' + @data_dir + N'\RuleSetHavingRuleItem.csv''
WITH (FIRSTROW=2, FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', CODEPAGE=''65001'', TABLOCK);';
EXEC (@sql);

/* --- Move to typed tables --- */
INSERT dbo.RuleSet (ID, Name)
SELECT CAST(ID AS int), Name
FROM dbo._stg_RuleSet;

INSERT dbo.RuleItem (ID, ParentID, PeerSortOrder, SymbolicName, ItemText)
SELECT
  CAST(ID AS int),
  CAST(NULLIF(ParentID,'')      AS int),
  CAST(NULLIF(PeerSortOrder,'') AS int),
  SymbolicName,
  ItemText
FROM dbo._stg_RuleItem;

INSERT dbo.RuleSetHavingRuleItem (RuleSetID, RuleItemID)
SELECT CAST(RuleSetID AS int), CAST(RuleItemID AS int)
FROM dbo._stg_RuleSetHavingRuleItem;

/* --- Guardrails --- */
IF (SELECT COUNT(*) FROM dbo.RuleSet) < 1
  THROW 50001, 'RuleSet row count unexpected', 1;

IF (SELECT COUNT(*) FROM dbo.RuleItem) <> 30
  THROW 50002, 'RuleItem row count unexpected', 1;

/* --- Cleanup staging --- */
DROP TABLE dbo._stg_RuleSetHavingRuleItem;
DROP TABLE dbo._stg_RuleItem;
DROP TABLE dbo._stg_RuleSet;

COMMIT;

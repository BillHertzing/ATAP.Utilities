-- =====================================================================
-- V00.01.000024__Load_ATAPUtilities_Snippet_From_CSV.sql
--
-- Loads Snippet Philote, RulePrimitive, Rule, RuleInstantiation,
-- and RuleInstantiationBinding data from CSV files.
-- =====================================================================
SET XACT_ABORT ON;
SET NOCOUNT ON;

-- -----------------------------------------------------------------
-- Staging tables  (columns match CSV headers; dropped at end)
-- Snippet_Philote_Primitives.csv     : PhiloteId, Comment
-- Snippet_RulePrimitives.csv         : PhiloteId, PrimitiveLanguageKindId, Name, Description
-- Snippet_Philote_Rules.csv          : PhiloteId, Comment
-- Snippet_Rules.csv                  : PhiloteId, PrimitiveLanguageKindId, Name, Purpose, SourceFileReference
-- Snippet_Philote_Instantiations.csv : PhiloteId, Comment
-- Snippet_Instantiations.csv         : PhiloteId, RulePhiloteId, Notes
-- Snippet_InstantiationBindings.csv  : InstantiationPhiloteId, InputName, InputValue
-- -----------------------------------------------------------------
CREATE TABLE dbo._stg_Snippet_Philote_Primitives (
    PhiloteId NVARCHAR(50)  NOT NULL,
    Comment   NVARCHAR(500)     NULL
);

CREATE TABLE dbo._stg_Snippet_RulePrimitives (
    PhiloteId               NVARCHAR(50)  NOT NULL,
    PrimitiveLanguageKindId NVARCHAR(10)  NOT NULL,
    [Name]                  NVARCHAR(200) NOT NULL,
    [Description]           NVARCHAR(MAX)     NULL
);

CREATE TABLE dbo._stg_Snippet_Philote_Rules (
    PhiloteId NVARCHAR(50)  NOT NULL,
    Comment   NVARCHAR(500)     NULL
);

CREATE TABLE dbo._stg_Snippet_Rules (
    PhiloteId               NVARCHAR(50)  NOT NULL,
    PrimitiveLanguageKindId NVARCHAR(10)  NOT NULL,
    [Name]                  NVARCHAR(200) NOT NULL,
    Purpose                 NVARCHAR(MAX)     NULL,
    SourceFileReference     NVARCHAR(500)     NULL
);

CREATE TABLE dbo._stg_Snippet_Philote_Instantiations (
    PhiloteId NVARCHAR(50)  NOT NULL,
    Comment   NVARCHAR(500)     NULL
);

CREATE TABLE dbo._stg_Snippet_Instantiations (
    PhiloteId     NVARCHAR(50)  NOT NULL,
    RulePhiloteId NVARCHAR(50)  NOT NULL,
    Notes         NVARCHAR(MAX)     NULL
);

CREATE TABLE dbo._stg_Snippet_InstantiationBindings (
    InstantiationPhiloteId NVARCHAR(50)  NOT NULL,
    InputName              NVARCHAR(200) NOT NULL,
    InputValue             NVARCHAR(MAX)     NULL
);

-- -----------------------------------------------------------------
-- BULK LOAD staging tables
-- -----------------------------------------------------------------
BULK INSERT dbo._stg_Snippet_Philote_Primitives
FROM '${data_dir}\Snippet_Philote_Primitives.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

BULK INSERT dbo._stg_Snippet_RulePrimitives
FROM '${data_dir}\Snippet_RulePrimitives.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

BULK INSERT dbo._stg_Snippet_Philote_Rules
FROM '${data_dir}\Snippet_Philote_Rules.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

BULK INSERT dbo._stg_Snippet_Rules
FROM '${data_dir}\Snippet_Rules.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

BULK INSERT dbo._stg_Snippet_Philote_Instantiations
FROM '${data_dir}\Snippet_Philote_Instantiations.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

BULK INSERT dbo._stg_Snippet_Instantiations
FROM '${data_dir}\Snippet_Instantiations.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

BULK INSERT dbo._stg_Snippet_InstantiationBindings
FROM '${data_dir}\Snippet_InstantiationBindings.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

-- -----------------------------------------------------------------
-- 1. Seed dbo.Philote for every RulePrimitive PhiloteId
-- -----------------------------------------------------------------
INSERT INTO dbo.Philote (PhiloteId)
SELECT DISTINCT
    TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId)))
FROM  dbo._stg_Snippet_Philote_Primitives AS s
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId))) IS NOT NULL
  AND NOT EXISTS (
          SELECT 1
          FROM   dbo.Philote AS p
          WHERE  p.PhiloteId = TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId)))
      );

-- -----------------------------------------------------------------
-- 2. Insert RulePrimitive rows
-- -----------------------------------------------------------------
INSERT INTO dbo.RulePrimitive (PhiloteId, PrimitiveLanguageKindId, [Name], [Description])
SELECT
    TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId))),
    TRY_CONVERT(TINYINT,          LTRIM(RTRIM(s.PrimitiveLanguageKindId))),
    NULLIF(LTRIM(RTRIM(s.[Name])),        N''),
    NULLIF(LTRIM(RTRIM(s.[Description])), N'')
FROM  dbo._stg_Snippet_RulePrimitives AS s
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId))) IS NOT NULL
  AND TRY_CONVERT(TINYINT,          LTRIM(RTRIM(s.PrimitiveLanguageKindId))) = 5
  AND NULLIF(LTRIM(RTRIM(s.[Name])), N'') IS NOT NULL
  AND NOT EXISTS (
          SELECT 1
          FROM   dbo.RulePrimitive AS rp
          WHERE  rp.PhiloteId = TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId)))
      );

-- -----------------------------------------------------------------
-- 3. Seed dbo.Philote for every Rule PhiloteId
-- -----------------------------------------------------------------
INSERT INTO dbo.Philote (PhiloteId)
SELECT DISTINCT
    TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId)))
FROM  dbo._stg_Snippet_Philote_Rules AS s
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId))) IS NOT NULL
  AND NOT EXISTS (
          SELECT 1
          FROM   dbo.Philote AS p
          WHERE  p.PhiloteId = TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId)))
      );

-- -----------------------------------------------------------------
-- 4. Insert Rule rows
-- -----------------------------------------------------------------
INSERT INTO dbo.[Rule] (PhiloteId, PrimitiveLanguageKindId, [Name], Purpose, SourceFileReference)
SELECT
    TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId))),
    TRY_CONVERT(TINYINT,          LTRIM(RTRIM(s.PrimitiveLanguageKindId))),
    NULLIF(LTRIM(RTRIM(s.[Name])),              N''),
    NULLIF(LTRIM(RTRIM(s.Purpose)),             N''),
    NULLIF(LTRIM(RTRIM(s.SourceFileReference)), N'')
FROM  dbo._stg_Snippet_Rules AS s
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId))) IS NOT NULL
  AND TRY_CONVERT(TINYINT,          LTRIM(RTRIM(s.PrimitiveLanguageKindId))) = 5
  AND NULLIF(LTRIM(RTRIM(s.[Name])), N'') IS NOT NULL
  AND NOT EXISTS (
          SELECT 1
          FROM   dbo.[Rule] AS r
          WHERE  r.PhiloteId = TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId)))
      );

-- -----------------------------------------------------------------
-- 5. Seed dbo.Philote for every RuleInstantiation PhiloteId
-- -----------------------------------------------------------------
INSERT INTO dbo.Philote (PhiloteId)
SELECT DISTINCT
    TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId)))
FROM  dbo._stg_Snippet_Philote_Instantiations AS s
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId))) IS NOT NULL
  AND NOT EXISTS (
          SELECT 1
          FROM   dbo.Philote AS p
          WHERE  p.PhiloteId = TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId)))
      );

-- -----------------------------------------------------------------
-- 6. Insert RuleInstantiation rows
-- -----------------------------------------------------------------
INSERT INTO dbo.RuleInstantiation (PhiloteId, RulePhiloteId, Notes)
SELECT
    TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId))),
    TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.RulePhiloteId))),
    NULLIF(LTRIM(RTRIM(s.Notes)), N'')
FROM  dbo._stg_Snippet_Instantiations AS s
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId)))     IS NOT NULL
  AND TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.RulePhiloteId))) IS NOT NULL
  AND NOT EXISTS (
          SELECT 1
          FROM   dbo.RuleInstantiation AS ri
          WHERE  ri.PhiloteId = TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.PhiloteId)))
      );

-- -----------------------------------------------------------------
-- 7. Insert RuleInstantiationBinding rows
-- -----------------------------------------------------------------
INSERT INTO dbo.RuleInstantiationBinding (InstantiationPhiloteId, InputName, InputValue)
SELECT
    TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.InstantiationPhiloteId))),
    NULLIF(LTRIM(RTRIM(s.InputName)),  N''),
    NULLIF(LTRIM(RTRIM(s.InputValue)), N'')
FROM  dbo._stg_Snippet_InstantiationBindings AS s
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.InstantiationPhiloteId))) IS NOT NULL
  AND NULLIF(LTRIM(RTRIM(s.InputName)), N'') IS NOT NULL
  AND NOT EXISTS (
          SELECT 1
          FROM   dbo.RuleInstantiationBinding AS rib
          WHERE  rib.InstantiationPhiloteId = TRY_CONVERT(UNIQUEIDENTIFIER, LTRIM(RTRIM(s.InstantiationPhiloteId)))
            AND  rib.InputName              = NULLIF(LTRIM(RTRIM(s.InputName)), N'')
      );

IF OBJECT_ID('dbo._stg_Snippet_Philote_Primitives',     'U') IS NOT NULL DROP TABLE dbo._stg_Snippet_Philote_Primitives;
IF OBJECT_ID('dbo._stg_Snippet_Philote_Rules',           'U') IS NOT NULL DROP TABLE dbo._stg_Snippet_Philote_Rules;
IF OBJECT_ID('dbo._stg_Snippet_RulePrimitives',          'U') IS NOT NULL DROP TABLE dbo._stg_Snippet_RulePrimitives;
IF OBJECT_ID('dbo._stg_Snippet_Rules',                   'U') IS NOT NULL DROP TABLE dbo._stg_Snippet_Rules;
IF OBJECT_ID('dbo._stg_Snippet_Philote_Instantiations',  'U') IS NOT NULL DROP TABLE dbo._stg_Snippet_Philote_Instantiations;
IF OBJECT_ID('dbo._stg_Snippet_Instantiations',          'U') IS NOT NULL DROP TABLE dbo._stg_Snippet_Instantiations;
IF OBJECT_ID('dbo._stg_Snippet_InstantiationBindings',   'U') IS NOT NULL DROP TABLE dbo._stg_Snippet_InstantiationBindings;

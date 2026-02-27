/*
 * V00.01.000200__Add_RRSBS_Core_Schema.sql
 *
 * Adds Rules, Rule Sets, and Build Sets (RRSBS) core schema to ATAPUtilities database.
 * This migration extends the existing Rule/RuleSet tables with:
 *   - Philote identity system
 *   - Language definitions
 *   - Rule Primitives (language constructs)
 *   - Parent-child relationships for rules
 *   - BuildSets for feature/module definitions
 *
 * This schema separates SLOWLY CHANGING data (languages, primitives)
 * from SWIFTLY CHANGING data (rules, rulesets, buildsets).
 */

USE [ATAPUtilities];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* === Philote Identity Table === */
/*
   Philote implements a stable identity system using GUIDs.
   All primitives and optionally rules can have a Philote ID.
*/

IF OBJECT_ID('dbo.Philote','U') IS NULL
BEGIN
  CREATE TABLE dbo.Philote
  (
    PhiloteID       uniqueidentifier NOT NULL DEFAULT NEWID(),
    EntityType      nvarchar(50)     NOT NULL,  -- 'RulePrimitive', 'Rule', etc.
    EntityKey       nvarchar(128)    NULL,      -- Optional symbolic reference
    CreatedDate     datetime2        NOT NULL DEFAULT SYSDATETIME(),
    Description     nvarchar(500)    NULL,
    CONSTRAINT PK_Philote PRIMARY KEY CLUSTERED (PhiloteID),
    CONSTRAINT UQ_Philote_EntityType_EntityKey UNIQUE (EntityType, EntityKey)
  );

  CREATE INDEX IX_Philote_EntityType
    ON dbo.Philote (EntityType);

  PRINT 'Created table: Philote';
END
GO

/* === Language Table === */
/* Defines programming/markup languages supported in the RRSBS system */

IF OBJECT_ID('dbo.Language','U') IS NULL
BEGIN
  CREATE TABLE dbo.Language
  (
    ID          int           NOT NULL IDENTITY(1,1),
    Name        nvarchar(50)  NOT NULL,
    Description nvarchar(500) NULL,
    IsActive    bit           NOT NULL DEFAULT 1,
    CreatedDate datetime2     NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Language PRIMARY KEY CLUSTERED (ID),
    CONSTRAINT UQ_Language_Name UNIQUE (Name)
  );

  PRINT 'Created table: Language';
END
GO

/* === RulePrimitive Table === */
/*
   Stores language construct primitives (BNF non-terminals).
   Each primitive has a stable Philote GUID identifier.
*/

IF OBJECT_ID('dbo.RulePrimitive','U') IS NULL
BEGIN
  CREATE TABLE dbo.RulePrimitive
  (
    PhiloteID      uniqueidentifier NOT NULL,  -- Stable GUID identifier
    LanguageID     int              NOT NULL,
    SymbolicName   nvarchar(128)    NOT NULL,  -- e.g., "<sql-script-file>"
    Description    nvarchar(1000)   NULL,
    BNFDefinition  nvarchar(max)    NULL,      -- BNF grammar definition
    Attribution    nvarchar(max)    NULL,      -- Source references/links
    IsActive       bit              NOT NULL DEFAULT 1,
    CreatedDate    datetime2        NOT NULL DEFAULT SYSDATETIME(),
    ModifiedDate   datetime2        NULL,
    CONSTRAINT PK_RulePrimitive PRIMARY KEY CLUSTERED (PhiloteID),
    CONSTRAINT FK_RulePrimitive_Language
      FOREIGN KEY (LanguageID) REFERENCES dbo.Language(ID),
    CONSTRAINT FK_RulePrimitive_Philote
      FOREIGN KEY (PhiloteID) REFERENCES dbo.Philote(PhiloteID),
    CONSTRAINT UQ_RulePrimitive_Language_Name
      UNIQUE (LanguageID, SymbolicName)
  );

  CREATE INDEX IX_RulePrimitive_Language
    ON dbo.RulePrimitive (LanguageID);

  CREATE INDEX IX_RulePrimitive_SymbolicName
    ON dbo.RulePrimitive (SymbolicName);

  PRINT 'Created table: RulePrimitive';
END
GO

/* === Extend Rule Table === */
/*
   Add columns to existing Rule table to support:
   - Optional Philote identity
   - Link to RulePrimitive
   - Parent-child hierarchy
   - Peer sort order
*/

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Rule') AND name = 'PhiloteID')
BEGIN
  ALTER TABLE dbo.[Rule]
    ADD PhiloteID uniqueidentifier NULL;

  ALTER TABLE dbo.[Rule]
    ADD CONSTRAINT FK_Rule_Philote
      FOREIGN KEY (PhiloteID) REFERENCES dbo.Philote(PhiloteID);

  CREATE INDEX IX_Rule_Philote
    ON dbo.[Rule] (PhiloteID);

  PRINT 'Added PhiloteID to Rule table';
END

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Rule') AND name = 'PrimitiveID')
BEGIN
  ALTER TABLE dbo.[Rule]
    ADD PrimitiveID uniqueidentifier NULL;

  ALTER TABLE dbo.[Rule]
    ADD CONSTRAINT FK_Rule_Primitive
      FOREIGN KEY (PrimitiveID) REFERENCES dbo.RulePrimitive(PhiloteID);

  CREATE INDEX IX_Rule_Primitive
    ON dbo.[Rule] (PrimitiveID);

  PRINT 'Added PrimitiveID to Rule table';
END

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Rule') AND name = 'ParentID')
BEGIN
  ALTER TABLE dbo.[Rule]
    ADD ParentID int NULL;

  ALTER TABLE dbo.[Rule]
    ADD CONSTRAINT FK_Rule_Parent
      FOREIGN KEY (ParentID) REFERENCES dbo.[Rule](Id);

  CREATE INDEX IX_Rule_Parent
    ON dbo.[Rule] (ParentID);

  PRINT 'Added ParentID to Rule table for hierarchy';
END

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Rule') AND name = 'PeerSortOrder')
BEGIN
  ALTER TABLE dbo.[Rule]
    ADD PeerSortOrder int NULL;

  CREATE INDEX IX_Rule_Parent_PeerSort
    ON dbo.[Rule] (ParentID, PeerSortOrder);

  PRINT 'Added PeerSortOrder to Rule table';
END

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Rule') AND name = 'SymbolicName')
BEGIN
  ALTER TABLE dbo.[Rule]
    ADD SymbolicName nvarchar(128) NULL;

  PRINT 'Added SymbolicName to Rule table';
END

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Rule') AND name = 'IsActive')
BEGIN
  ALTER TABLE dbo.[Rule]
    ADD IsActive bit NOT NULL DEFAULT 1;

  PRINT 'Added IsActive to Rule table';
END
GO

/* === BuildSet Table === */
/* BuildSets define complete features/modules as collections of RuleSets */

IF OBJECT_ID('dbo.BuildSet','U') IS NULL
BEGIN
  CREATE TABLE dbo.BuildSet
  (
    ID           int           NOT NULL IDENTITY(1,1),
    Name         nvarchar(100) NOT NULL,
    Description  nvarchar(500) NULL,
    IsActive     bit           NOT NULL DEFAULT 1,
    CreatedDate  datetime2     NOT NULL DEFAULT SYSDATETIME(),
    ModifiedDate datetime2     NULL,
    CONSTRAINT PK_BuildSet PRIMARY KEY CLUSTERED (ID),
    CONSTRAINT UQ_BuildSet_Name UNIQUE (Name)
  );

  PRINT 'Created table: BuildSet';
END
GO

/* === BuildSetHavingRuleSet Association Table === */
/* Many-to-many relationship between BuildSets and RuleSets */

IF OBJECT_ID('dbo.BuildSetHavingRuleSet','U') IS NULL
BEGIN
  CREATE TABLE dbo.BuildSetHavingRuleSet
  (
    BuildSetID int NOT NULL,
    RuleSetID  int NOT NULL,
    SortOrder  int NOT NULL DEFAULT 1,
    CONSTRAINT PK_BuildSetHavingRuleSet PRIMARY KEY CLUSTERED (BuildSetID, RuleSetID),
    CONSTRAINT FK_BuildSetHavingRuleSet_BuildSet
      FOREIGN KEY (BuildSetID) REFERENCES dbo.BuildSet(ID),
    CONSTRAINT FK_BuildSetHavingRuleSet_RuleSet
      FOREIGN KEY (RuleSetID) REFERENCES dbo.RuleSet(Id)
  );

  CREATE INDEX IX_BuildSetHavingRuleSet_RuleSet
    ON dbo.BuildSetHavingRuleSet (RuleSetID);

  PRINT 'Created table: BuildSetHavingRuleSet';
END
GO

/* === RuleRelationship Table === */
/*
   Defines typed relationships between rules beyond parent-child.
   Examples: depends-on, executes-before, executes-after, conflicts-with
*/

IF OBJECT_ID('dbo.RuleRelationship','U') IS NULL
BEGIN
  CREATE TABLE dbo.RuleRelationship
  (
    ID               int           NOT NULL IDENTITY(1,1),
    SourceRuleID     int           NOT NULL,
    TargetRuleID     int           NOT NULL,
    RelationshipType nvarchar(50)  NOT NULL,  -- 'depends-on', 'executes-before', etc.
    Description      nvarchar(500) NULL,
    IsActive         bit           NOT NULL DEFAULT 1,
    CreatedDate      datetime2     NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_RuleRelationship PRIMARY KEY CLUSTERED (ID),
    CONSTRAINT FK_RuleRelationship_Source
      FOREIGN KEY (SourceRuleID) REFERENCES dbo.[Rule](Id),
    CONSTRAINT FK_RuleRelationship_Target
      FOREIGN KEY (TargetRuleID) REFERENCES dbo.[Rule](Id),
    CONSTRAINT UQ_RuleRelationship_Source_Target_Type
      UNIQUE (SourceRuleID, TargetRuleID, RelationshipType)
  );

  CREATE INDEX IX_RuleRelationship_Source
    ON dbo.RuleRelationship (SourceRuleID);

  CREATE INDEX IX_RuleRelationship_Target
    ON dbo.RuleRelationship (TargetRuleID);

  CREATE INDEX IX_RuleRelationship_Type
    ON dbo.RuleRelationship (RelationshipType);

  PRINT 'Created table: RuleRelationship';
END
GO

PRINT '=== RRSBS Core Schema migration completed successfully ===';
GO

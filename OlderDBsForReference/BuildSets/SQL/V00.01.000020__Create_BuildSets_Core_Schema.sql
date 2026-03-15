USE BuildSets;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* Drop in dependency order if re-running on a dev box (optional safety) */
IF OBJECT_ID('dbo.RuleSetHavingRuleItem','U') IS NOT NULL DROP TABLE dbo.RuleSetHavingRuleItem;
IF OBJECT_ID('dbo.RuleItem','U')               IS NOT NULL DROP TABLE dbo.RuleItem;
IF OBJECT_ID('dbo.RulePrimitive','U')          IS NOT NULL DROP TABLE dbo.RulePrimitive;
IF OBJECT_ID('dbo.RuleSet','U')                IS NOT NULL DROP TABLE dbo.RuleSet;
IF OBJECT_ID('dbo.Language','U')               IS NOT NULL DROP TABLE dbo.Language;
GO

/* === Core Schema Tables === */
/*
   This script creates only the database objects (tables, indexes, constraints).
   Data is loaded separately via versioned data migration scripts.
*/

/* Language table - defines programming/markup languages (SQL, C#, PowerShell, etc.) */
CREATE TABLE dbo.Language
(
  ID          int           NOT NULL,
  Name        nvarchar(50)  NOT NULL,
  Description nvarchar(500) NULL,
  CONSTRAINT PK_Language PRIMARY KEY (ID),
  CONSTRAINT UQ_Language_Name UNIQUE (Name)
);

/* RulePrimitive table - defines language construct primitives (BNF non-terminals) */
CREATE TABLE dbo.RulePrimitive
(
  PhiloteID      uniqueidentifier NOT NULL,  -- Stable GUID identifier
  LanguageID     int              NOT NULL,
  SymbolicName   nvarchar(128)    NOT NULL,  -- e.g., "<sql-script-file>"
  Description    nvarchar(1000)   NULL,
  BNFDefinition  nvarchar(max)    NULL,      -- BNF grammar definition
  CreatedDate    datetime2        NOT NULL DEFAULT SYSDATETIME(),
  CONSTRAINT PK_RulePrimitive PRIMARY KEY (PhiloteID),
  CONSTRAINT FK_RulePrimitive_Language
    FOREIGN KEY (LanguageID) REFERENCES dbo.Language(ID),
  CONSTRAINT UQ_RulePrimitive_Language_Name
    UNIQUE (LanguageID, SymbolicName)
);

/* RuleSet table - groups of related rules */
CREATE TABLE dbo.RuleSet
(
  ID   int           NOT NULL,
  Name nvarchar(100) NOT NULL,
  CONSTRAINT PK_RuleSet PRIMARY KEY (ID)
);

/* RuleItem table - specific rule instances/configurations */
CREATE TABLE dbo.RuleItem
(
  ID              int              NOT NULL,
  ParentID        int              NULL,   -- self-reference for hierarchy
  PeerSortOrder   int              NULL,
  PrimitiveID     uniqueidentifier NULL,   -- links to RulePrimitive (optional)
  SymbolicName    nvarchar(128)    NOT NULL,
  ItemText        nvarchar(200)    NOT NULL,
  CONSTRAINT PK_RuleItem PRIMARY KEY (ID),
  CONSTRAINT FK_RuleItem_Parent
    FOREIGN KEY (ParentID) REFERENCES dbo.RuleItem(ID),
  CONSTRAINT FK_RuleItem_Primitive
    FOREIGN KEY (PrimitiveID) REFERENCES dbo.RulePrimitive(PhiloteID)
);

/* Association table - which rules belong to which rule sets */
CREATE TABLE dbo.RuleSetHavingRuleItem
(
  RuleSetID  int NOT NULL,
  RuleItemID int NOT NULL,
  CONSTRAINT PK_RuleSetHavingRuleItem PRIMARY KEY (RuleSetID, RuleItemID),
  CONSTRAINT FK_RuleSetHavingRuleItem_RuleSet
    FOREIGN KEY (RuleSetID) REFERENCES dbo.RuleSet(ID),
  CONSTRAINT FK_RuleSetHavingRuleItem_RuleItem
    FOREIGN KEY (RuleItemID) REFERENCES dbo.RuleItem(ID)
);

/* === Indexes for performance === */

CREATE INDEX IX_RulePrimitive_Language
  ON dbo.RulePrimitive (LanguageID);

CREATE INDEX IX_RulePrimitive_SymbolicName
  ON dbo.RulePrimitive (SymbolicName);

CREATE INDEX IX_RuleItem_Parent_PeerSort
  ON dbo.RuleItem (ParentID, PeerSortOrder);

CREATE INDEX IX_RuleItem_Primitive
  ON dbo.RuleItem (PrimitiveID);

CREATE INDEX IX_RuleSetHavingRuleItem_Item
  ON dbo.RuleSetHavingRuleItem (RuleItemID);
GO


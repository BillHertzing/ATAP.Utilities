USE BuildSets;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* Drop in dependency order if re-running on a dev box (optional safety) */
IF OBJECT_ID('dbo.RuleSetHavingRuleItem','U') IS NOT NULL DROP TABLE dbo.RuleSetHavingRuleItem;
IF OBJECT_ID('dbo.RuleItem','U')               IS NOT NULL DROP TABLE dbo.RuleItem;
IF OBJECT_ID('dbo.RuleSet','U')               IS NOT NULL DROP TABLE dbo.RuleSet;
GO

/* === Tables === */

CREATE TABLE dbo.RuleSet
(
  ID   int        NOT NULL,
  Name nvarchar(100) NOT NULL,
  CONSTRAINT PK_RuleSet PRIMARY KEY (ID)
);

CREATE TABLE dbo.RuleItem
(
  ID            int           NOT NULL,
  ParentID      int           NULL,   -- self-reference
  PeerSortOrder int           NULL,
  SymbolicName  nvarchar(128) NOT NULL,
  ItemText      nvarchar(200) NOT NULL,
  CONSTRAINT PK_RuleItem PRIMARY KEY (ID),
  CONSTRAINT FK_RuleItem_Parent
    FOREIGN KEY (ParentID) REFERENCES dbo.RuleItem(ID)
);

CREATE TABLE dbo.RuleSetHavingRuleItem
(
  RuleSetID int NOT NULL,
  RuleItemID int NOT NULL,
  CONSTRAINT PK_RuleSetHavingRuleItem PRIMARY KEY (RuleSetID, RuleItemID),
  CONSTRAINT FK_RuleSetHavingRuleItem_RuleSet
    FOREIGN KEY (RuleSetID) REFERENCES dbo.RuleSet(ID),
  CONSTRAINT FK_RuleSetHavingRuleItem_RuleItem
    FOREIGN KEY (RuleItemID) REFERENCES dbo.RuleItem(ID)
);

/* Helpful indexes for tree and membership lookups */
CREATE INDEX IX_RuleItem_Parent_PeerSort
  ON dbo.RuleItem (ParentID, PeerSortOrder);

CREATE INDEX IX_RuleSetHavingRuleItem_Item
  ON dbo.RuleSetHavingRuleItem (RuleItemID);
GO

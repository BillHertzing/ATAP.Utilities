USE BuildSets;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO


CREATE TABLE dbo.BuildSet
(
  ID   int            NOT NULL,
  Name nvarchar(100)  NOT NULL,
  CONSTRAINT PK_BuildSet PRIMARY KEY (ID)
);

CREATE TABLE dbo.BuildSetHavingRuleSet
(
  BuildSetID int NOT NULL,
  RuleSetID  int NOT NULL,
  CONSTRAINT PK_BuildSetHavingRuleSet PRIMARY KEY (BuildSetID, RuleSetID),
  CONSTRAINT FK_BuildSetHavingRuleSet_BuildSet
    FOREIGN KEY (BuildSetID) REFERENCES dbo.BuildSet(ID),
  CONSTRAINT FK_BuildSetHavingRuleSet_RuleSet
    FOREIGN KEY (RuleSetID)  REFERENCES dbo.RuleSet(ID)
);


CREATE INDEX IX_BuildSetHavingRuleSet_RuleSet
  ON dbo.BuildSetHavingRuleSet (RuleSetID);

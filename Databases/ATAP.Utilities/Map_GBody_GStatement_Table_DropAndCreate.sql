USE ATAPUtilities
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Map_GBody_GStatement') AND type in (N'U'))
BEGIN
  ALTER TABLE dbo.Map_GBody_GStatement DROP CONSTRAINT PK_Map_GBody_GStatement
  ALTER TABLE dbo.Map_GBody_GStatement DROP CONSTRAINT FK_Map_GComment_GStatement_GBody
  ALTER TABLE dbo.Map_GBody_GStatement DROP CONSTRAINT FK_Map_GComment_GStatement_GStatement
  ALTER TABLE dbo.Map_GBody_GStatement DROP CONSTRAINT DF_Map_GBody_GStatement_SortOrder
  DROP TABLE dbo.Map_GBody_GStatement
END
GO

CREATE TABLE dbo.Map_GBody_GStatement(
	Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Map_GBody_GStatement  PRIMARY KEY NONCLUSTERED
	, FK_GBody int NOT NULL CONSTRAINT FK_Map_GComment_GStatement_GBody  FOREIGN KEY (FK_GBody) REFERENCES dbo.GBody (Id)
	, FK_GStatement int NOT NULL CONSTRAINT FK_Map_GComment_GStatement_GStatement  FOREIGN KEY (FK_GStatement) REFERENCES dbo.GStatement (Id)
	, SortOrder int NOT NULL CONSTRAINT DF_Map_GBody_GStatement_SortOrder  DEFAULT 1
) ON [PRIMARY]
GO

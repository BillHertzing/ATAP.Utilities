USE ATAPUtilities
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.Map_GComment_GStatement') AND type in (N'U'))
BEGIN
  ALTER TABLE dbo.Map_GComment_GStatement DROP CONSTRAINT PK_Map_GComment_GStatement
  ALTER TABLE dbo.Map_GComment_GStatement DROP CONSTRAINT FK_GComment
  ALTER TABLE dbo.Map_GComment_GStatement DROP CONSTRAINT FK_GStatement
  ALTER TABLE dbo.Map_GComment_GStatement DROP CONSTRAINT DF_Map_GComment_GStatement_SortOrder
  DROP TABLE dbo.Map_GComment_GStatement
END
GO

CREATE TABLE dbo.Map_GComment_GStatement(
	Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Map_GComment_GStatement  PRIMARY KEY NONCLUSTERED
	, FK_GComment int NOT NULL CONSTRAINT FK_GComment  FOREIGN KEY (FK_GComment) REFERENCES dbo.GComment (Id)
	, FK_GStatement int NOT NULL CONSTRAINT FK_GStatement  FOREIGN KEY (FK_GStatement) REFERENCES dbo.GStatement (Id)
	, SortOrder int NOT NULL CONSTRAINT DF_Map_GComment_GStatement_SortOrder  DEFAULT 1
) ON [PRIMARY]
GO

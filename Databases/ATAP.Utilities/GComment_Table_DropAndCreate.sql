USE ATAPUtilities
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.GComment') AND type in (N'U'))
BEGIN
  ALTER TABLE dbo.GComment DROP CONSTRAINT PK_GComment
  DROP TABLE dbo.GComment
END
GO

CREATE TABLE dbo.GComment(
	Id int IDENTITY(1,1) NOT NULL,
	[Comment] nvarchar(512) NULL
  , CONSTRAINT PK_GComment PRIMARY KEY NONCLUSTERED (Id)
) ON [PRIMARY]
GO


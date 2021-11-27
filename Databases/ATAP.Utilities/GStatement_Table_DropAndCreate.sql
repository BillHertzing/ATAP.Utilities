USE ATAPUtilities
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.GStatement') AND type in (N'U'))
BEGIN
  ALTER TABLE dbo.GStatement DROP CONSTRAINT PK_GStatement
  DROP TABLE dbo.GStatement
END
GO

CREATE TABLE dbo.GStatement(
	Id int IDENTITY(1,1) NOT NULL,
	[Statement] nvarchar(512) NULL
  , CONSTRAINT PK_GStatement PRIMARY KEY NONCLUSTERED (Id)
) ON [PRIMARY]
GO


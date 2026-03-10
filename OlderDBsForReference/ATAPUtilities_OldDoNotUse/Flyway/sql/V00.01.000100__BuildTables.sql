USE [ATAPUtilities]
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE dbo.GPatternReplacement(
	Id int IDENTITY(1,1) NOT NULL
 ,	MatchPattern nvarchar(512) NULL
 ,	ReplacementPattern nvarchar(512) NULL
  , CONSTRAINT PK_GPatternReplacement PRIMARY KEY NONCLUSTERED (Id)
) ON [PRIMARY]

CREATE TABLE dbo.GStatement(
	Id int IDENTITY(1,1) NOT NULL
 ,	[Statement] nvarchar(512) NULL
  , CONSTRAINT PK_GStatement PRIMARY KEY NONCLUSTERED (Id)
) ON [PRIMARY]

CREATE TABLE dbo.GComment(
	Id int IDENTITY(1,1) NOT NULL
  , CONSTRAINT PK_GComment PRIMARY KEY NONCLUSTERED (Id)
) ON [PRIMARY]

CREATE TABLE dbo.GBody(
	Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_GBody PRIMARY KEY NONCLUSTERED (Id)
	, FK_GComment int CONSTRAINT FK_GBody_GComment  FOREIGN KEY (FK_GComment) REFERENCES dbo.GComment (Id)
) ON [PRIMARY]

CREATE TABLE dbo.GArgument(
	Id int IDENTITY(1,1) NOT NULL
  , GName nvarchar(512) NOT NULL
, GType nvarchar(512) NOT NULL
, IsRef bit NOT NULL
, IsOut bit NOT NULL
) ON [PRIMARY]

----------

CREATE TABLE dbo.GAssemblyUnit(
Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_GASsemblyUnit PRIMARY KEY NONCLUSTERED (Id)
, GName nvarchar(512) NOT NULL
, GRelativePath nvarchar(512) NOT NULL
, FK_GComment int CONSTRAINT FK_GAssemblyUnit_GComment  FOREIGN KEY (FK_GComment) REFERENCES dbo.GComment (Id)
, FK_GPatternReplacement int CONSTRAINT FK_GAssemblyUnit_GPatternReplacement  FOREIGN KEY (FK_GPatternReplacement) REFERENCES dbo.GPatternReplacement (Id)
-- , FK_GProjectUnit int CONSTRAINT FK_GAssemblyUnit_GProjectUnit  FOREIGN KEY (FK_GProjectUnit) REFERENCES dbo.GProjectUnit (Id)
)	ON [PRIMARY]

CREATE TABLE dbo.GSolutionFile(
Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_GSolution PRIMARY KEY NONCLUSTERED (Id)
, GName nvarchar(512) NOT NULL
, AbsolutePath nvarchar(512) NOT NULL UNIQUE
, CreationTimeUtc datetime NOT NULL
, LastWriteTimeUtc datetime NOT NULL
)	ON [PRIMARY]

--------
CREATE TABLE dbo.[Rule](
Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Rule PRIMARY KEY NONCLUSTERED (Id)
, [Name] nvarchar(512) NOT NULL
, Kind nvarchar(512) NOT NULL
, Validity datetime NOT NULL
, DisplayOrder nvarchar(512) NOT NULL
, DisplayAction nvarchar(512) NOT NULL
, InputAction nvarchar(512) NOT NULL
, [Value] nvarchar(512) NOT NULL
, [Dirty] bit NOT NULL
)	ON [PRIMARY]

CREATE TABLE dbo.RuleSet(
Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_RuleSet PRIMARY KEY NONCLUSTERED (Id)
, [Name] nvarchar(512) NOT NULL
, Validity datetime NOT NULL
)	ON [PRIMARY]

CREATE TABLE dbo.AppTemplate(
Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_AppTemplate PRIMARY KEY NONCLUSTERED (Id)
, Name nvarchar(512) NOT NULL
, Validity datetime NOT NULL
)	ON [PRIMARY]

CREATE TABLE dbo.AppInstance(
Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_AppInstance PRIMARY KEY NONCLUSTERED (Id)
, Name nvarchar(512) NOT NULL
, Validity datetime NOT NULL
)	ON [PRIMARY]

CREATE TABLE dbo.Map_GComment_GStatement(
	Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Map_GComment_GStatement  PRIMARY KEY NONCLUSTERED
	, FK_GComment int NOT NULL CONSTRAINT FK_GComment  FOREIGN KEY (FK_GComment) REFERENCES dbo.GComment (Id)
	, FK_GStatement int NOT NULL CONSTRAINT FK_GStatement  FOREIGN KEY (FK_GStatement) REFERENCES dbo.GStatement (Id)
	, SortOrder int NOT NULL CONSTRAINT DF_Map_GComment_GStatement_SortOrder  DEFAULT 1
) ON [PRIMARY]

CREATE TABLE dbo.Map_GBody_GStatement(
	Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Map_GBody_GStatement  PRIMARY KEY NONCLUSTERED
	, FK_GBody int NOT NULL CONSTRAINT FK_Map_GComment_GStatement_GBody  FOREIGN KEY (FK_GBody) REFERENCES dbo.GBody (Id)
	, FK_GStatement int NOT NULL CONSTRAINT FK_Map_GComment_GStatement_GStatement  FOREIGN KEY (FK_GStatement) REFERENCES dbo.GStatement (Id)
	, SortOrder int NOT NULL CONSTRAINT DF_Map_GBody_GStatement_SortOrder  DEFAULT 1
) ON [PRIMARY]

CREATE TABLE dbo.Map_RuleSet_Rule(
	Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Map_RuleSet_Rule PRIMARY KEY NONCLUSTERED
	, FK_RuleSet int NOT NULL CONSTRAINT FK_RuleSet FOREIGN KEY (FK_RuleSet) REFERENCES dbo.RuleSet (Id)
	, FK_Rule int NOT NULL CONSTRAINT FK_Rule  FOREIGN KEY (FK_Rule) REFERENCES dbo.[Rule] (Id)
	, SortOrder int NOT NULL CONSTRAINT DF_Map_RuleSet_Rule_SortOrder  DEFAULT 1
) ON [PRIMARY]

GO

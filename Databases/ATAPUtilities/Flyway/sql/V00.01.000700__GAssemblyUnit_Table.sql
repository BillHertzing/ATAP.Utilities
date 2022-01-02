USE [ATAPUtilities]
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE dbo.GAssemblyUnit(
Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_GASsemblyUnit PRIMARY KEY NONCLUSTERED (Id)
, GName nvarchar(512) NOT NULL
, GRelativePath nvarchar(512) NOT NULL
, FK_GComment int CONSTRAINT FK_GAssemblyUnit_GComment  FOREIGN KEY (FK_GComment) REFERENCES dbo.GComment (Id)
, FK_GPatternReplacement int CONSTRAINT FK_GAssemblyUnit_GPatternReplacement  FOREIGN KEY (FK_GPatternReplacement) REFERENCES dbo.GPatternReplacement (Id)
-- , FK_GProjectUnit int CONSTRAINT FK_GAssemblyUnit_GProjectUnit  FOREIGN KEY (FK_GProjectUnit) REFERENCES dbo.GProjectUnit (Id)
)	ON [PRIMARY]
GO

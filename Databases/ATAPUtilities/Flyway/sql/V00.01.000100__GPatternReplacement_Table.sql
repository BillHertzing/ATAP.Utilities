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
GO

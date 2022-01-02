USE [ATAPUtilities]
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE dbo.[Rule](
Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Rule PRIMARY KEY NONCLUSTERED (Id)
, Name nvarchar(512) NOT NULL
, Kind nvarchar(512) NOT NULL
, Validity datetime NOT NULL
, DisplayOrder nvarchar(512) NOT NULL
, DisplayAction nvarchar(512) NOT NULL
, InputAction nvarchar(512) NOT NULL
, [Value] nvarchar(512) NOT NULL
, [Dirty] bit NOT NULL
)	ON [PRIMARY]
GO

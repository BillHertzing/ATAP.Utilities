-- =========================================
-- Create Tables for the GenerateProgram Database
-- =========================================
USE GenerateProgram
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF  EXISTS (SELECT *
FROM sys.objects
WHERE object_id = OBJECT_ID(N'[dbo].[GHServices]') AND type in (N'U'))
DROP TABLE [dbo].[GHServices]
GO

CREATE TABLE [dbo].[GHServices]
(
    [ID] [int] IDENTITY(1,1) NOT NULL,
    [Name] [varchar](255) NOT NULL
) ON [PRIMARY]
GO

IF  EXISTS (SELECT *
FROM sys.objects
WHERE object_id = OBJECT_ID(N'[dbo].[Programs]') AND type in (N'U'))
DROP TABLE [dbo].[Programs]
GO

CREATE TABLE [dbo].[Programs](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ProgramName] [varchar](max) NOT NULL,
	[sourceRelativePath] [varchar](255) NOT NULL,
	[testRelativePath] [varchar](255) NOT NULL,
	[subDirectoryForGeneratedFiles] [varchar](255) NOT NULL,
	[baseNamespaceName] [varchar](max) NOT NULL,
	[isService] [bit] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


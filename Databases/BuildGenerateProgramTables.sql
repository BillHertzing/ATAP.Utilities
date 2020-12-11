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

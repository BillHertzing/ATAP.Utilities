USE [ATAPUtilities]
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

DROP FUNCTION IF EXISTS [dbo].[udfGetTableNamesFromBCPFilesInDirectory]
GO

CREATE FUNCTION [dbo].[udfGetTableNamesFromBCPFilesInDirectory](@path nvarchar(1000), @matchPattern nvarchar(1000), @replacePattern nvarchar(1000))
RETURNS TABLE
(tableName nvarchar(1000), fullFilePath nvarchar (1000))
AS
EXTERNAL NAME ATAPUtilitiesDatabaseManagement.udfGetTableNamesFromBCPFilesInDirectory.InitMethod;
GO

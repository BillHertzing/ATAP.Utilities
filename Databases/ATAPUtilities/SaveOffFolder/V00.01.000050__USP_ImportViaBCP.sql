USE [ATAPUtilities]
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[uspImportViaBCP];
GO

CREATE PROCEDURE [dbo].[uspImportViaBCP]
  @bCPInputFullFilePath VARCHAR(1000)
  ,@ServerName VARCHAR(1000)
  ,@DatabaseName VARCHAR(1000)
  ,@SchemaName VARCHAR(1000)
  ,@TableName VARCHAR(1000)
AS
  BEGIN
    Declare
      @sqlCommand   VARCHAR(1000)
      , @bCPFileNameTemplate     VARCHAR(1000)
      SET NOCOUNT ON
      SET  @sqlCommand = 'bcp [' + @SchemaName  +'].[' + @TableName + '] in "' +  @bCPInputFullFilePath + '" -S ('+@ServerName+') -T -d '+@DatabaseName+' -c'
      Print '@sqlcmd = ' + @sqlCommand
      EXEC master..xp_cmdshell @sqlCommand
  END
GO


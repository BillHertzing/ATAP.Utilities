USE [ATAPUtilities]
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[uspImportViaBCP];
GO

CREATE PROCEDURE [dbo].[uspImportViaBCP]
    @bCPFileInputPath     VARCHAR(1000)
    ,@SchemaName     VARCHAR(1000)
    ,@TableName     VARCHAR(1000)
    ,@Version     VARCHAR(1000)
AS    
  BEGIN
    Declare
      @sqlCommand   VARCHAR(1000)
      , @bCPInputFullFilePath   VARCHAR(1000)
      , @bCPFileNameTemplate     VARCHAR(1000)
      SET NOCOUNT ON
      SET  @bCPInputFullFilePath = @bCPFileInputPath + @TableName + '__Data_' + @Version + '.bcp'
      SET  @sqlCommand = 'bcp [' + @SchemaName  +'].[' + @TableName + '] in "' +  @bCPInputFullFilePath + '" -S (local) -T -d ATAPUtilities -c'
      EXEC master..xp_cmdshell @sqlCommand
  END
GO


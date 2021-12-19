USE [ATAPUtilities]
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[uspExportViaBCP]
GO

CREATE PROCEDURE [dbo].[uspExportViaBCP]
    @bCPFileOutputPath     VARCHAR(1000)
    ,@SchemaName     VARCHAR(1000)
    ,@TableName     VARCHAR(1000)
    ,@Version     VARCHAR(1000)
AS
  BEGIN
    Declare
      @sqlCommand   VARCHAR(1000)
      , @bCPOutputFullFilePath   VARCHAR(1000)
      , @bCPFileNameTemplate     VARCHAR(1000)
      SET NOCOUNT ON
      -- To allow advanced options to be changed.  
      EXECUTE sp_configure 'show advanced options', 1
      -- To update the currently configured value for advanced options.  
      RECONFIGURE
      -- To enable the xp_cmdshell feature.  
      EXECUTE sp_configure 'xp_cmdshell', 1
      -- To update the currently configured value for this feature.  
      RECONFIGURE;  

      SET  @bCPOutputFullFilePath = @bCPFileOutputPath + @TableName + '__Data_' + @Version + '.bcp'
      SET  @sqlCommand = 'bcp [' + @SchemaName  +'].[' + @TableName + '] out "' +  @bCPOutputFullFilePath + '" -S (local) -T -d ATAPUtilities -c'
      EXEC master..xp_cmdshell @sqlCommand
      -- To disable the xp_cmdshell feature.  
      EXECUTE sp_configure 'xp_cmdshell', 0;  
      -- To update the currently configured value for this feature.  
      RECONFIGURE;  
      -- To disallow advanced options to be changed.  
      EXECUTE sp_configure 'show advanced options', 0;  
      RECONFIGURE;  
END



USE [ATAPUtilities]

DROP PROCEDURE IF EXISTS [dbo].[uspExportAllTablesViaBCP]
GO

CREATE PROCEDURE [dbo].[uspExportAllTablesViaBCP]
    @bCPFileOutputPath     VARCHAR(1000)
    ,@SchemaName     VARCHAR(1000)
   , @Version VARCHAR(1000)
AS
  BEGIN
    DECLARE 
      @TableName VARCHAR(1000)
      , @InternalBCPFileOutputPath VARCHAR(1000)
      , @InternalSchemaName VARCHAR(1000)
      , @InternalVersion VARCHAR(1000)

      SET NOCOUNT ON
      IF ([dbo].[ufnIsNullOrEmpty](@bCPFileOutputPath) = 1) BEGIN
        SET @InternalBCPFileOutputPath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\Databases\ATAPUtilities\BCPData\'
      END ELSE BEGIN
        SET @InternalBCPFileOutputPath = @bCPFileOutputPath
      END
      IF ([dbo].[ufnIsNullOrEmpty](@SchemaName) = 1) BEGIN
        SET @InternalSchemaName = 'dbo'
      END ELSE BEGIN
        SET @InternalSchemaName = @SchemaName
      END
      IF ([dbo].[ufnIsNullOrEmpty](@Version) = 1) BEGIN
        SET @InternalVersion = CONVERT(VARCHAR, GETDATE(), 112) + '_' + CAST(DATEPART(HOUR, GETDATE()) AS VARCHAR) + '_' +  CAST(DATEPART(MINUTE,GETDATE()) AS VARCHAR)
      END ELSE BEGIN
        SET @InternalVersion = @Version
      END

      --PRINT @bCPFileOutputPath + ', ' + @SchemaName + ', ' + @Version 
    DECLARE cursor_TableName CURSOR FOR
      SELECT Table_Name
      FROM information_schema.tables;

    -- Get all Table names and loop
    OPEN cursor_TableName
    FETCH NEXT FROM cursor_TableName INTO @TableName
      WHILE @@FETCH_STATUS = 0  BEGIN
        EXECUTE uspExportViaBCP @InternalBCPFileOutputPath, @InternalSchemaName , @TableName , @InternalVersion
        FETCH NEXT FROM cursor_TableName INTO @TableName
      END
    CLOSE cursor_TableName
    DEALLOCATE cursor_TableName


  END
GO  

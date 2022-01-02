USE [ATAPUtilities]
DROP PROCEDURE IF EXISTS [dbo].[uspImportAllTablesViaBCP]
GO

CREATE PROCEDURE [dbo].[uspImportAllTablesViaBCP]
  @bCPFileInputPath VARCHAR(1000)
  , @serverName VARCHAR(1000)
  , @databaseName VARCHAR(1000)
  , @schemaName VARCHAR(1000)
  , @matchPattern VARCHAR(1000)
  , @replacePattern VARCHAR(1000)

AS
  BEGIN
    DECLARE
      @TableName VARCHAR(1000)
      , @FullFilePath VARCHAR(1000)
      , @internalBCPFileInputPath VARCHAR(1000)
      , @internalServerName VARCHAR(1000)
      , @internalDatabaseName VARCHAR(1000)
      , @internalSchemaName VARCHAR(1000)
      , @internalMatchPattern VARCHAR(1000)
      , @internalReplacePattern VARCHAR(1000)

      SET NOCOUNT ON
      IF ([dbo].[ufnIsNullOrEmpty](@bCPFileInputPath) = 1)
      -- ToDo: Get all default values from configuration
        SET @internalBCPFileInputPath = 'C:/Dropbox/whertzing/GitHub/ATAP.Utilities/Databases/ATAPUtilities/BCPData/'
       ELSE SET @internalBCPFileInputPath = @bCPFileInputPath

      IF ([dbo].[ufnIsNullOrEmpty](@serverName) = 1) SET @internalServerName = 'local'
       ELSE SET @internalServerName = @serverName

      IF ([dbo].[ufnIsNullOrEmpty](@databaseName) = 1) SET @internalDatabaseName = 'ATAPUtilities'
       ELSE SET @internalDatabaseName = @databaseName

      IF ([dbo].[ufnIsNullOrEmpty](@SchemaName) = 1) SET @internalSchemaName = 'dbo'
       ELSE SET @internalSchemaName = @SchemaName

      IF ([dbo].[ufnIsNullOrEmpty](@matchPattern) = 1) SET @internalMatchPattern = '(.*?)__Data'
       ELSE SET @internalMatchPattern = @matchPattern

      IF ([dbo].[ufnIsNullOrEmpty](@replacePattern) = 1) SET @internalReplacePattern = '$1'
       ELSE SET @internalReplacePattern = @replacePattern

    DECLARE cursor_TableName CURSOR FOR
      SELECT TableName, FullFilePath
      FROM udfGetTableNamesFromBCPFilesInDirectory(@internalBCPFileInputPath, @internalMatchPattern, @internalReplacePattern);

    -- Get all Table names and loop
    OPEN cursor_TableName
    FETCH NEXT FROM cursor_TableName INTO @TableName, @FullFilePath
      WHILE @@FETCH_STATUS = 0  BEGIN
        EXECUTE uspImportViaBCP @FullFilePath, @internalServerName, @internalDatabaseName, @internalSchemaName, @TableName
        FETCH NEXT FROM cursor_TableName INTO @TableName, @FullFilePAth
      END
    CLOSE cursor_TableName
    DEALLOCATE cursor_TableName
END
GO

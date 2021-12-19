USE [ATAPUtilities]
SET NOCOUNT ON
-- To allow advanced options to be changed.  
EXECUTE sp_configure 'show advanced options', 1;  
GO  
-- To update the currently configured value for advanced options.  
RECONFIGURE;  
GO  
-- To enable the xp_cmdshell feature.  
EXECUTE sp_configure 'xp_cmdshell', 1;  
GO  
-- To update the currently configured value for this feature.  
RECONFIGURE;  
GO

DECLARE 
  @TableName VARCHAR(1000)
  , @Now VARCHAR(1000)

  Set @Now = CONVERT(VARCHAR, GETDATE(), 112) + '_' + CAST(DATEPART(HOUR, GETDATE()) AS VARCHAR) + '_' +  CAST(DATEPART(MINUTE,GETDATE()) AS VARCHAR)
  DECLARE cursor_TableName CURSOR FOR
    SELECT Table_Name
    FROM information_schema.tables;

  -- Get all Table names and loop
  OPEN cursor_TableName
   FETCH NEXT FROM cursor_TableName INTO @TableName
    WHILE @@FETCH_STATUS = 0  BEGIN
      EXECUTE uspExportViaBCP 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\Databases\ATAPUtilities\Backups\', 'dbo',@TableName, @Now
      FETCH NEXT FROM cursor_TableName INTO @TableName
    END
  CLOSE cursor_TableName
  DEALLOCATE cursor_TableName


-- To disable the xp_cmdshell feature.  
EXECUTE sp_configure 'xp_cmdshell', 0;  
GO  
-- To update the currently configured value for this feature.  
RECONFIGURE;  
GO  
-- To disallow advanced options to be changed.  
EXECUTE sp_configure 'show advanced options', 0;  
GO  
RECONFIGURE;  
GO  

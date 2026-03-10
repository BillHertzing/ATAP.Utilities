/*
Database backup and creation script for ATAPUtilities Database
*/

SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO
DECLARE
  @DatabaseName nvarchar(4000),
  @BackupFilePath nvarchar(4000),
  @DatabaseDataFileFullPath nvarchar(4000),
  @DatabaseDataStatementsFileGroupFullPath nvarchar(4000),
  @DatabaseLogFileFullPath nvarchar(4000),
  @DatabaseIndexFileFullPath nvarchar(4000),
  @DatabaseIndexStatementsFileGroupFullPath nvarchar(4000)

:setvar DatabaseName "ATAPUtilities"
:setvar BackupFilePath "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\Databases\ATAPUtilities\Backups\\"
:setvar DatabaseDataFileFullPath "C:\LocalDBs\ATAPUtilities\Data\ATAPUtilities.mdf"
:setvar DatabaseDataStatementsFileGroupFullPath "C:\LocalDBs\ATAPUtilities\Data\ATAPUtilities_Statements.mdf"
:setvar DatabaseLogFileFullPath "C:\LocalDBs\ATAPUtilities\Log\ATAPUtilities_log.ldf"
:setvar DatabaseIndexFileFullPath "C:\LocalDBs\ATAPUtilities\Index\ATAPUtilitiesIDX.mdf"
:setvar DatabaseIndexStatementsFileGroupFullPath "C:\LocalDBs\ATAPUtilities\Index\ATAPUtilitiesIDX_Statements.mdf"
:ON error EXIT

-- Abort the current batch immediately if a statement raises a run-time error and rollback any open transaction(s)
SET XACT_ABORT ON;

IF N'$(DatabaseName)' = N'$' + N'(DatabaseName)' -- Is SQLCMD mode enabled within the execution context (eg. SSMS)
  BEGIN
    IF IS_SRVROLEMEMBER(N'sysadmin') = 1
      BEGIN
        -- User is sysadmin; abort execution by disconnect the script from the database server
        RAISERROR(N'This script must be run in SQLCMD Mode (under the Query menu in SSMS). Aborting connection to suppress subsequent errors.', 20, 127, N'UNKNOWN') WITH LOG;
      END
    ELSE
      BEGIN
        -- User is not sysadmin; abort execution by switching off statement execution (script will continue to the end without performing any actual deployment work)
        RAISERROR(N'This script must be run in SQLCMD Mode (under the Query menu in SSMS). Script execution has been halted.', 16, 127, N'UNKNOWN') WITH NOWAIT;
      END
  END
GO
IF @@ERROR != 0
  BEGIN
  SET NOEXEC ON;
-- SQLCMD is NOT enabled so prevent any further statements from executing
END
GO
-- Beyond this point, no further explicit error handling is required because it can be assumed that SQLCMD mode is enabled
IF DB_NAME() != 'master'
  BEGIN
  USE [master];
END
GO

IF (DB_ID(N'$(DatabaseName)') IS NOT NULL
  AND DATABASEPROPERTYEX(N'$(DatabaseName)','Status') <> N'ONLINE')
  BEGIN
  RAISERROR(N'The state of the target database, %s, is not set to ONLINE. To backup this database, its state must be set to ONLINE.', 16, 127,N'$(DatabaseName)') WITH NOWAIT
  RETURN
END
GO

-- Disallow any other users access to the database
IF (DB_ID(N'$(DatabaseName)') IS NOT NULL)
BEGIN
  ALTER DATABASE [$(DatabaseName)]
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
END
GO


IF (DB_ID(N'$(DatabaseName)') IS NOT NULL)
  BEGIN
  DECLARE @rc      int,                       -- return code
      @fn      nvarchar(4000),            -- file name to back up to
      @dir     nvarchar(4000)
  -- backup directory
  SELECT @dir = N'$(BackupFilePath)'
  -- ToDo: If BackupFilePath is not defined, use the default values as below
  --EXEC @rc = [master].[dbo].[xp_instance_regread] N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', @dir output, 'no_output'

  --IF (@dir IS NULL)
  --BEGIN
  --  EXEC @rc = [master].[dbo].[xp_instance_regread] N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', @dir output, 'no_output'
  --END

  --IF (@dir IS NULL)
  --BEGIN
  --  EXEC @rc = [master].[dbo].[xp_instance_regread] N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\Setup', N'SQLDataRoot', @dir output, 'no_output'
  --  SELECT @dir = @dir + N'\Backup'
  --END
  -- ToDo:  add a '\' to the default values from the registry + N'\'

  SELECT @fn = @dir + N'$(DatabaseName)' + N'-' +
      CONVERT(nchar(6), GETDATE(), 112) + N'-' +
      RIGHT(N'0' + RTRIM(CONVERT(nchar(2), DATEPART(hh, GETDATE()))), 2) +
      RIGHT(N'0' + RTRIM(CONVERT(nchar(2), DATEPART(mi, getdate()))), 2) +
      RIGHT(N'0' + RTRIM(CONVERT(nchar(2), DATEPART(ss, getdate()))), 2) +
      N'.bak'
  BACKUP DATABASE [$(DatabaseName)] TO DISK = @fn

END
GO

-- Writeout Bulkload .bcp files
USE [ATAPUtilities]
BEGIN
  DECLARE  @sqlCommand   VARCHAR(1000)
  DECLARE  @filePath     VARCHAR(100)
  DECLARE  @fileName     VARCHAR(100)
  DECLARE  @TableName    VARCHAR(100)

  SET @filePath = '$(BackupFilePath)'
  PRINT @FilePAth
  DECLARE cursor_TableName CURSOR FOR
    SELECT Table_Name
  FROM information_schema.tables;

  -- Get Table name

OPEN cursor_TableName
  FETCH NEXT FROM cursor_TableName INTO @TableName
  WHILE @@FETCH_STATUS = 0  BEGIN
    SET    @fileName = 'Data_Bulkload_'+@TableName+'.bcp'
    -- SET    @sqlCommand =
    --    'SQLCMD -S (local) -E -d ATAPUtilities -q "SELECT * FROM ['+@TableName+']" -o "' +
    --    @filePath + @fileName +'" -h-1'

    SET  @sqlCommand = 'bcp "SELECT * FROM ['+@TableName+']" queryout "' +   @filePath + @fileName + ' " -S (local) -T -d ATAPUtilities -c'
    PRINT       @sqlCommand
    --EXEC   master..xp_cmdshell @sqlCommand
    FETCH NEXT FROM cursor_TableName INTO @TableName
  END

  CLOSE cursor_TableName
  DEALLOCATE cursor_TableName
END
GO



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
:setvar BackupFilePath "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\Databases\ATAPUtilities\Backups\"
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

USE [master]
GO
GO



IF (DB_ID(N'$(DatabaseName)') IS NOT NULL
  AND DATABASEPROPERTYEX(N'$(DatabaseName)','Status') <> N'ONLINE')
BEGIN
  RAISERROR(N'The state of the target database, %s, is not set to ONLINE. To deploy to this database, its state must be set to ONLINE.', 16, 127,N'$(DatabaseName)') WITH NOWAIT
  RETURN
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

IF (DB_ID(N'$(DatabaseName)') IS NOT NULL)
BEGIN
  ALTER DATABASE [$(DatabaseName)]
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE [$(DatabaseName)];
END
GO

CREATE DATABASE [$(DatabaseName)]
   ON PRIMARY(NAME = [$(DatabaseName)], FILENAME = [$(DatabaseDataFileFullPath)], SIZE = 20, MAXSIZE = 1000 MB, FILEGROWTH = 20%)
   , FILEGROUP ATAPUtilitiesData_STATEMENTS( NAME = ATAPUtilitiesData_STATEMENTS, FILENAME = [$(DatabaseDataStatementsFileGroupFullPath)], SIZE = 20, MAXSIZE = 1000 MB, FILEGROWTH = 20% )
   , FILEGROUP ATAPUtilitiesIDX_STATEMENTS(  NAME = ATAPUtilitiesIDX_STATEMENTS,     FILENAME = [$(DatabaseIndexStatementsFileGroupFullPath)], SIZE = 20, MAXSIZE = 1000 MB, FILEGROWTH = 20% )
   LOG ON (NAME = [ATAP.Utilities_log], FILENAME = [$(DatabaseLogFileFullPath)], SIZE = 10, MAXSIZE = 1000 MB, FILEGROWTH = 20 %
  )
GO

-- EXECUTE sp_dbcmptlevel [$(DatabaseName)], 100;
-- GO

IF EXISTS (SELECT 1
FROM [master].[dbo].[sysdatabases]
WHERE  [name] = N'$(DatabaseName)')
  BEGIN
  ALTER DATABASE [$(DatabaseName)]
      SET ANSI_NULLS ON,
      ANSI_PADDING ON,
      ANSI_WARNINGS ON,
      ARITHABORT ON,
      CONCAT_NULL_YIELDS_NULL ON,
      NUMERIC_ROUNDABORT OFF,
      QUOTED_IDENTIFIER ON,
      ANSI_NULL_DEFAULT ON,
      CURSOR_DEFAULT LOCAL,
      RECOVERY SIMPLE,
      CURSOR_CLOSE_ON_COMMIT OFF,
      AUTO_CREATE_STATISTICS ON,
      AUTO_SHRINK ON,
      AUTO_UPDATE_STATISTICS ON,
      RECURSIVE_TRIGGERS OFF
    WITH ROLLBACK IMMEDIATE;
  ALTER DATABASE [$(DatabaseName)]
      SET AUTO_CLOSE OFF
      WITH ROLLBACK IMMEDIATE;
END
GO

IF EXISTS (SELECT 1
FROM [master].[dbo].[sysdatabases]
WHERE  [name] = N'$(DatabaseName)')
    BEGIN
  ALTER DATABASE [$(DatabaseName)]
            SET ALLOW_SNAPSHOT_ISOLATION OFF;
END
GO

IF EXISTS (SELECT 1
FROM [master].[dbo].[sysdatabases]
WHERE  [name] = N'$(DatabaseName)')
    BEGIN
  ALTER DATABASE [$(DatabaseName)]
            SET READ_COMMITTED_SNAPSHOT OFF;
END
GO

IF EXISTS (SELECT 1
FROM [master].[dbo].[sysdatabases]
WHERE  [name] = N'$(DatabaseName)')
    BEGIN
  ALTER DATABASE [$(DatabaseName)]
            SET AUTO_UPDATE_STATISTICS_ASYNC OFF,
                PAGE_VERIFY NONE,
                DATE_CORRELATION_OPTIMIZATION OFF,
                DISABLE_BROKER,
                PARAMETERIZATION SIMPLE
            WITH ROLLBACK IMMEDIATE;
END
GO

IF IS_SRVROLEMEMBER(N'sysadmin') = 1
    BEGIN
  IF EXISTS (SELECT 1
  FROM [master].[dbo].[sysdatabases]
  WHERE  [name] = N'$(DatabaseName)')
            BEGIN
    EXECUTE sp_executesql N'ALTER DATABASE [$(DatabaseName)]
    SET TRUSTWORTHY OFF,
        DB_CHAINING OFF
    WITH ROLLBACK IMMEDIATE';
  END
END
ELSE
    BEGIN
  PRINT N'The database settings for DB_CHAINING or TRUSTWORTHY cannot be modified. You must be a SysAdmin to apply these settings.';
END
GO

IF EXISTS (SELECT 1
FROM [master].[dbo].[sysdatabases]
WHERE  [name] = N'$(DatabaseName)')
    BEGIN
  ALTER DATABASE [$(DatabaseName)]
            SET HONOR_BROKER_PRIORITY OFF
            WITH ROLLBACK IMMEDIATE;
END
GO

USE [$(DatabaseName)]
GO
IF fulltextserviceproperty(N'IsFulltextInstalled') = 1
    EXECUTE sp_fulltext_database 'enable';
GO

/*
 Pre-Deployment Script Template
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be executed before the build script.
 Use SQLCMD syntax to include a file in the pre-deployment script.
 Example:      :r .\myfile.sql
 Use SQLCMD syntax to reference a variable in the pre-deployment script.
 Example:      :setvar TableName MyTable
               SELECT * FROM [$(TableName)]
--------------------------------------------------------------------------------------
*/
GO

--PRINT N'Creating AutoCreatedLocal...';
--GO
--CREATE ROUTE [AutoCreatedLocal]
--    AUTHORIZATION [dbo]
--    WITH ADDRESS = N'LOCAL';
--GO

/*
Post-Deployment Script Template
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be appended to the build script.
 Use SQLCMD syntax to include a file in the post-deployment script.
 Example:      :r .\myfile.sql
 Use SQLCMD syntax to reference a variable in the post-deployment script.
 Example:      :setvar TableName MyTable
               SELECT * FROM [$(TableName)]
--------------------------------------------------------------------------------------
*/
GO

IF EXISTS (SELECT 1
FROM [master].[dbo].[sysdatabases]
WHERE  [name] = N'$(DatabaseName)')
    BEGIN
  DECLARE @VarDecimalSupported AS BIT;
  SELECT @VarDecimalSupported = 0;
  IF ((ServerProperty(N'EngineEdition') = 3)
    AND (((@@microsoftversion / power(2, 24) = 9)
    AND (@@microsoftversion & 0xffff >= 3024))
    OR ((@@microsoftversion / power(2, 24) = 10)
    AND (@@microsoftversion & 0xffff >= 1600))))
            SELECT @VarDecimalSupported = 1;
  IF (@VarDecimalSupported > 0)
            BEGIN
    EXECUTE sp_db_vardecimal_storage_format N'$(DatabaseName)', 'ON';
  END
END
GO

ALTER DATABASE [$(DatabaseName)]
    SET MULTI_USER
    WITH ROLLBACK IMMEDIATE;
GO

-- Create a common User and an Admin User

IF NOT EXISTS( SELECT 1
FROM master.dbo.syslogins
WHERE [name] = 'AUADMIN')
  EXEC sp_addlogin 'AUADMIN', 'pass'
GO

IF NOT EXISTS(SELECT 1
FROM master.dbo.syslogins
WHERE [name] = 'AUUSER')
EXEC sp_addlogin 'AUUSER', 'pass'
GO

EXEC sp_grantdbaccess 'AUADMIN'
EXEC sp_addrolemember 'db_datareader', 'AUADMIN'
EXEC sp_addrolemember 'db_datawriter', 'AUADMIN'
EXEC sp_addrolemember 'db_ddladmin', 'AUADMIN'
GO

EXEC sp_grantdbaccess 'AUUSER'
EXEC sp_addrolemember 'db_datareader', 'AUUSER'
EXEC sp_addrolemember 'db_datawriter', 'AUUSER'
GO

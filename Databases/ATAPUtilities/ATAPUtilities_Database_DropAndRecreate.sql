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
:setvar DatabaseLogFileFullPath "C:\LocalDBs\ATAPUtilities\Log\ATAPUtilities_log.ldf"
:setvar DatabaseIndexFileFullPath "C:\LocalDBs\ATAPUtilities\Index\ATAPUtilitiesIDX.mdf"
:setvar DatabaseDataStatementsFileGroupFullPath "C:\LocalDBs\ATAPUtilities\Data\ATAPUtilities_Statements.mdf"
:setvar DatabaseIndexStatementsFileGroupFullPath "C:\LocalDBs\ATAPUtilities\Index\ATAPUtilitiesIDX_Statements.mdf"
:ON error EXIT

-- Abort the current batch immediately if a statement raises a run-time error and rollback any open transaction(s)
SET XACT_ABORT ON;

IF N'$(DatabaseName)' = N'$' + N'(DatabaseName)' -- Is SQLCMD mode enabled within the execution context (eg. SSMS)
  BEGIN
    IF IS_SRVROLEMEMBER(N'sysadmin') = 1 BEGIN
      -- User is sysadmin; abort execution by disconnect the script from the database server
      RAISERROR(N'This script must be run in SQLCMD Mode (under the Query menu in SSMS or via SQLCMD at a CLI prompt). Aborting connection to suppress subsequent errors.', 20, 127, N'UNKNOWN') WITH LOG;
      END
    ELSE
      BEGIN
      -- User is not sysadmin; abort execution by switching off statement execution (script will continue to the end without performing any actual deployment work)
      RAISERROR(N'This script must be run in SQLCMD Mode (under the Query menu in SSMor via SQLCMD at a CLI promptS). Script execution has been halted.', 16, 127, N'UNKNOWN') WITH NOWAIT;
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

-- Kick everyone else off the database and delete it
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
      SET
      -- Null Handling follows ANSI standard in this script
      ANSI_NULLS ON,
      -- Null Handling follows ANSI standard by default in all scripts
      --ANSI_NULL_DEFAULT ON,
      --ANSI_PADDING ON,
      --ANSI_WARNINGS ON,
      --ARITHABORT ON,
      -- Create statistics used to improve query execution plans
      --AUTO_CREATE_STATISTICS ON,
      -- allow the DB engine to shrink the sizes of some tables
      --AUTO_SHRINK ON,
      --AUTO_UPDATE_STATISTICS ON,
      --AUTO_UPDATE_STATISTICS_ASYNC OFF,
      -- The outcome when variable having a null value is string-concatenated
      --CONCAT_NULL_YIELDS_NULL ON,
      -- Leave cursors open after a commit so they can be reused
      --CURSOR_CLOSE_ON_COMMIT OFF,
      -- Declared cursors are local to the database
      --CURSOR_DEFAULT LOCAL,
      --??
      --DATE_CORRELATION_OPTIMIZATION OFF,
      --??
      --DISABLE_BROKER,
      --??
      --HONOR_BROKER_PRIORITY OFF,
      --NUMERIC_ROUNDABORT OFF,
      --PAGE_VERIFY NONE,
      --PARAMETERIZATION SIMPLE,
      --READ_COMMITTED_SNAPSHOT OFF,
      --
      --QUOTED_IDENTIFIER ON,
      --RECOVERY SIMPLE,
      TRUSTWORTHY OFF
      --RECURSIVE_TRIGGERS OFF
    WITH ROLLBACK IMMEDIATE;
  -- ALTER DATABASE [$(DatabaseName)]
      -- SET AUTO_CLOSE OFF
      -- WITH ROLLBACK IMMEDIATE;
END
GO

-- IF EXISTS (SELECT 1
  -- FROM [master].[dbo].[sysdatabases]
  -- WHERE  [name] = N'$(DatabaseName)')
    -- BEGIN
      -- ALTER DATABASE [$(DatabaseName)]
      -- SET ALLOW_SNAPSHOT_ISOLATION OFF;
    -- END
-- GO

-- Required for adding custom Net Common Language Runtime assemblies containing UDFs
-- IF EXISTS (SELECT 1
--   FROM [master].[dbo].[sysdatabases]
--   WHERE  [name] = N'$(DatabaseName)')
--     BEGIN
--       EXEC sp_configure 'clr enabled', 1;
--       RECONFIGURE
--     END
-- GO

-- IF EXISTS (SELECT 1
-- FROM [master].[dbo].[sysdatabases]
-- WHERE  [name] = N'$(DatabaseName)')
    -- BEGIN
  -- ALTER DATABASE [$(DatabaseName)]
            -- SET
                -- DISABLE_BROKER,
            -- WITH ROLLBACK IMMEDIATE;
-- END
-- GO


-- Change from attribution - Assemblies are loaded in the next migration, leave trustworthy ON
-- ToDo: Security analysis - what is the expansion on the attack surface
-- IF IS_SRVROLEMEMBER(N'sysadmin') = 1
  -- BEGIN
  -- IF EXISTS (SELECT 1
    -- FROM [master].[dbo].[sysdatabases]
    -- WHERE  [name] = N'$(DatabaseName)')
    -- BEGIN
      -- EXECUTE sp_executesql N'ALTER DATABASE [$(DatabaseName)]
      -- SET DB_CHAINING OFF
    -- WITH ROLLBACK IMMEDIATE';
  -- END
-- END
-- ELSE
    -- BEGIN
  -- PRINT N'The database settings for DB_CHAINING or TRUSTWORTHY cannot be modified. You must be a SysAdmin to apply these settings.';
-- END
-- GO


-- USE [$(DatabaseName)]
-- GO
-- IF fulltextserviceproperty(N'IsFulltextInstalled') = 1
    -- EXECUTE sp_fulltext_database 'enable';
-- GO

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

-- IF EXISTS (SELECT 1
-- FROM [master].[dbo].[sysdatabases]
-- WHERE  [name] = N'$(DatabaseName)')
    -- BEGIN
  -- DECLARE @VarDecimalSupported AS BIT;
  -- SELECT @VarDecimalSupported = 0;
  -- IF ((ServerProperty(N'EngineEdition') = 3)
    -- AND (((@@microsoftversion / power(2, 24) = 9)
    -- AND (@@microsoftversion & 0xffff >= 3024))
    -- OR ((@@microsoftversion / power(2, 24) = 10)
    -- AND (@@microsoftversion & 0xffff >= 1600))))
            -- SELECT @VarDecimalSupported = 1;
  -- IF (@VarDecimalSupported > 0)
            -- BEGIN
    -- EXECUTE sp_db_vardecimal_storage_format N'$(DatabaseName)', 'ON';
  -- END
-- END
-- GO

-- ALTER DATABASE [$(DatabaseName)]
    -- SET MULTI_USER
    -- WITH ROLLBACK IMMEDIATE;
-- GO

-- Create a common User and an Admin User

DROP LOGIN IF EXISTS 'AUADMIN'

-- IF NOT EXISTS( SELECT 1
-- FROM master.dbo.syslogins
-- WHERE [name] = 'AUADMIN')
  -- EXEC sp_addlogin 'AUADMIN', 'NotSecret'
-- GO

-- IF NOT EXISTS(SELECT 1
-- FROM master.dbo.syslogins
-- WHERE [name] = 'AUUSER')
-- EXEC sp_addlogin 'AUUSER', 'NotSecret'
-- GO

-- EXEC sp_grantdbaccess 'AUADMIN'
-- EXEC sp_addrolemember 'db_datareader', 'AUADMIN'
-- EXEC sp_addrolemember 'db_datawriter', 'AUADMIN'
-- EXEC sp_addrolemember 'db_ddladmin', 'AUADMIN'
-- GO

-- EXEC sp_grantdbaccess 'AUUSER'
-- EXEC sp_addrolemember 'db_datareader', 'AUUSER'
-- EXEC sp_addrolemember 'db_datawriter', 'AUUSER'
-- GO

USE [ATAPUtilities]
/*
 Add CLR Assemblies to the Database
*/

SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO

ALTER DATABASE [ATAPUtilities] SET TRUSTWORTHY ON;
DROP ASSEMBLY IF EXISTS [ATAPUtilitiesDatabaseManagement]
GO

    EXEC sp_configure 'clr enabled', 1;
    RECONFIGURE


--IF EXISTS (SELECT 1
--  FROM [master].[dbo].[sysdatabases]
--  WHERE  [name] = 'ATAPUtilities')
    --BEGIN
    CREATE ASSEMBLY [ATAPUtilitiesDatabaseManagement]
    -- ToDo: get this value from configuration, esp env var
    FROM 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement\bin\Debug\net48\ATAP.Utilities.DatabaseManagement.dll'
    WITH PERMISSION_SET = EXTERNAL_ACCESS;
--    END
GO

ALTER DATABASE  [ATAPUtilities] SET TRUSTWORTHY OFF;


--use master;
-- Replace SQL_Server_logon with your SQL Server user credentials.
--GRANT EXTERNAL ACCESS ASSEMBLY TO [SQL_Server_logon];
-- Modify the following line to specify a different database.
-- ALTER DATABASE [ATAPUtilities] SET TRUSTWORTHY ON;


--DROP ASSEMBLY IF EXISTS [ATAPUtilitiesDatabaseManagement]

-- Modify the next line to use the appropriate database.
-- CREATE ASSEMBLY [ATAPUtilitiesDatabaseManagement]
-- FROM 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement\bin\Debug\net48\ATAP.Utilities.DatabaseManagement.dll'
-- WITH PERMISSION_SET = EXTERNAL_ACCESS;
-- GO

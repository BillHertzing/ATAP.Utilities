/*
 Add CLR Assemblies to the Database
*/

SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO

:setvar DatabaseName "ATAPUtilities"
:setvar AssemblyName "ATAPUtilitiesDatabaseManagement"
:setvar AssemblyPath "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement\bin\Debug\net48\ATAP.Utilities.DatabaseManagement.dll"

ALTER DATABASE [ATAPUtilities] SET TRUSTWORTHY ON; -- N'$(DatabaseName)')
DROP ASSEMBLY IF EXISTS [ATAPUtilitiesDatabaseManagement]

IF EXISTS (SELECT 1
  FROM [master].[dbo].[sysdatabases]
  WHERE  [name] = 'ATAPUtilities')
    BEGIN
    CREATE ASSEMBLY [ATAPUtilitiesDatabaseManagement]
    -- ToDo: get this value from configuration, esp env var
    FROM 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement\bin\Debug\net48\ATAP.Utilities.DatabaseManagement.dll'
    WITH PERMISSION_SET = EXTERNAL_ACCESS;
    END
GO

ALTER DATABASE  [ATAPUtilities] SET TRUSTWORTHY OFF;


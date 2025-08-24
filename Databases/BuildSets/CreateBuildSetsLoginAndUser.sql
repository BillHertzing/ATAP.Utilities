/* Check current authentication mode:
   1 = Windows-only; 0 = Mixed Mode */
SELECT IsIntegratedSecurityOnly = SERVERPROPERTY('IsIntegratedSecurityOnly');
GO

/* Enable Mixed Mode (LoginMode = 2) */
EXEC master..xp_instance_regwrite
  N'HKEY_LOCAL_MACHINE',
  N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
  N'LoginMode',
  REG_DWORD,
  2;
GO

/* This script must be run by a windows user having permission to create databases and administer them */
/* Create an application login & user */
USE master;
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = N'FlywayAsBuildSetsDBOwner')
BEGIN
  CREATE LOGIN [FlywayAsBuildSetsDBOwner]
    WITH PASSWORD = N'ChangeMe_!234',
         CHECK_POLICY = ON, CHECK_EXPIRATION = ON;
END
GO

-- Ensure login exists (already created above) then set its default database
USE master;
IF DB_ID(N'BuildSets') IS NOT NULL
BEGIN
  -- Set Default Database
  ALTER LOGIN [FlywayAsBuildSetsDBOwner]
    WITH DEFAULT_DATABASE = [BuildSets];
ALTER SERVER ROLE [bulkadmin] ADD MEMBER [FlywayAsBuildSetsDBOwner];
END
ELSE
BEGIN
  THROW 51000, 'BuildSets database not found; default database not set for login FlywayAsBuildSetsDBOwner. Aborting script.', 1;
END
GO

/* This script must be run by a windows user having permission to administer databases */
USE BuildSets;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'FlywayAsBuildSetsDBOwner')
  CREATE USER [FlywayAsBuildSetsDBOwner] FOR LOGIN [FlywayAsBuildSetsDBOwner];

/* grant access to the DB */
EXEC sp_addrolemember N'db_datareader', N'FlywayAsBuildSetsDBOwner';
EXEC sp_addrolemember N'db_datawriter', N'FlywayAsBuildSetsDBOwner';
-- For convenience during exploration you can temporarily grant:
EXEC sp_addrolemember N'db_owner', N'FlywayAsBuildSetsDBOwner';
GO

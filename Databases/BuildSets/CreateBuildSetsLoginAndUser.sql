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

/* Create an application login & user */
USE master;
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = N'FlywayAsBuildSetsDBOwner')
BEGIN
  CREATE LOGIN [FlywayAsBuildSetsDBOwner]
    WITH PASSWORD = N'ChangeMe_!234',
         CHECK_POLICY = ON, CHECK_EXPIRATION = ON;
END
GO

USE BuildSets;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'FlywayAsBuildSetsDBOwner')
  CREATE USER [FlywayAsBuildSetsDBOwner] FOR LOGIN [FlywayAsBuildSetsDBOwner];

/* grant access to the DB */
EXEC sp_addrolemember N'db_datareader', N'FlywayAsBuildSetsDBOwner';
EXEC sp_addrolemember N'db_datawriter', N'FlywayAsBuildSetsDBOwner';
-- For convenience during exploration you can temporarily grant:
-- EXEC sp_addrolemember N'db_owner', N'FlywayAsBuildSetsDBOwner';
GO

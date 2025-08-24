/*
Purpose: Ensure server login + database user for BuildSets with least privileges.
Prerequisites: Database [BuildSets] already created by prior migration.
Password: Supply via sqlcmd VARIABLE or Flyway placeholder:
  :setvar BuildSetsLoginPwd  StrongP@ssw0rd!
  or flyway.placeholders.BuildSetsLoginPwd=StrongP@ssw0rd!
*/

SET NOCOUNT ON;
GO

-- Parameters (sqlcmd style) fall back to safe placeholders if not replaced
DECLARE @LoginName sysname = N'FlywayAsBuildSetsDBOwner';
DECLARE @DbName    sysname = N'BuildSets';
DECLARE @Pwd       nvarchar(256) = N'$(BuildSetsLoginPwd)';
-- EXPECTED TO BE REPLACED
DECLARE @GrantDbOwner bit = 0;
-- set to 1 only if absolutely required

IF @Pwd LIKE '%$(BuildSetsLoginPwd)%'
BEGIN
  RAISERROR('Password variable $(BuildSetsLoginPwd) was not replaced. Aborting.',16,1);
  RETURN;
END;

------------------------------------------------------------------
-- 1. Verify target database exists
------------------------------------------------------------------
IF DB_ID(@DbName) IS NULL
BEGIN
  RAISERROR('Target database %s does not exist. Run the create DB script first.',16,1,@DbName);
  RETURN;
END;

------------------------------------------------------------------
-- 2. Create or update login
------------------------------------------------------------------
IF NOT EXISTS (SELECT 1
FROM sys.server_principals
WHERE name = @LoginName)
BEGIN
  PRINT CONCAT('Creating login ', @LoginName);
  EXEC (N'CREATE LOGIN [' + REPLACE
  (@LoginName,']',']]') + N'] WITH PASSWORD = @p, CHECK_POLICY = ON, CHECK_EXPIRATION = ON')
       N'@p nvarchar(256)', @p=@Pwd;
END
ELSE
BEGIN
  PRINT CONCAT('Login ', @LoginName, ' already exists (no password change here).');
END;

------------------------------------------------------------------
-- 3. Set default database (only if different)
------------------------------------------------------------------
DECLARE @CurrentDefault sysname =
  (SELECT default_database_name
FROM sys.server_principals
WHERE name = @LoginName);
IF @CurrentDefault IS NULL
BEGIN
  RAISERROR('Unable to read current default database for %s.',16,1,@LoginName);
END
ELSE IF @CurrentDefault <> @DbName
BEGIN
  PRINT CONCAT('Setting default database for ', @LoginName, ' to ', @DbName);
  DECLARE @sql nvarchar(max) =
    N'ALTER LOGIN [' + REPLACE(@LoginName,']',']]') + N'] WITH DEFAULT_DATABASE = [' + REPLACE(@DbName,']',']]') + N'];';
  EXEC (@sql);
END;

------------------------------------------------------------------
-- 4. Add to bulkadmin if needed for BULK INSERT scenarios
------------------------------------------------------------------
IF NOT EXISTS (
  SELECT 1
FROM sys.server_role_members rm
  JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
  JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id
WHERE r.name = N'bulkadmin' AND m.name = @LoginName
)
BEGIN
  PRINT 'Adding login to server role bulkadmin';
  EXEC (N'ALTER SERVER ROLE [bulkadmin] ADD MEMBER [' + REPLACE
  (@LoginName,']',']]') + N'];');
END;

------------------------------------------------------------------
-- 5. Create database user if missing
------------------------------------------------------------------
USE [BuildSets];
IF NOT EXISTS (SELECT 1
FROM sys.database_principals
WHERE name = @LoginName)
BEGIN
  PRINT CONCAT('Creating user ', @LoginName, ' in ', DB_NAME());
  EXEC (N'CREATE USER [' + REPLACE
  (@LoginName,']',']]') + N'] FOR LOGIN [' + REPLACE
  (@LoginName,']',']]') + N'];');
END;

------------------------------------------------------------------
-- 6. Grant least privileges (data reader/writer)
------------------------------------------------------------------
IF NOT EXISTS (SELECT 1
FROM sys.database_role_members drm
  JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
  JOIN sys.database_principals u ON drm.member_principal_id = u.principal_id
WHERE r.name = N'db_datareader' AND u.name = @LoginName)
  EXEC (N'EXEC sp_addrolemember N''db_datareader'', N''' + REPLACE
(@LoginName,'''','''''') + N''';');

IF NOT EXISTS (SELECT 1
FROM sys.database_role_members drm
  JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
  JOIN sys.database_principals u ON drm.member_principal_id = u.principal_id
WHERE r.name = N'db_datawriter' AND u.name = @LoginName)
  EXEC (N'EXEC sp_addrolemember N''db_datawriter'', N''' + REPLACE
(@LoginName,'''','''''') + N''';');

------------------------------------------------------------------
-- 7. Optional elevated role (controlled flag)
------------------------------------------------------------------
IF @GrantDbOwner = 1
BEGIN
  IF NOT EXISTS (SELECT 1
  FROM sys.database_role_members drm
    JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
    JOIN sys.database_principals u ON drm.member_principal_id = u.principal_id
  WHERE r.name = N'db_owner' AND u.name = @LoginName)
  BEGIN
    PRINT 'Granting db_owner (flag enabled)';
    EXEC (N'EXEC sp_addrolemember N''db_owner'', N''' + REPLACE
    (@LoginName,'''','''''') + N''';');
  END;
END
ELSE
BEGIN
  PRINT 'db_owner not granted (least privilege default).';
END;

PRINT 'Provisioning complete.';

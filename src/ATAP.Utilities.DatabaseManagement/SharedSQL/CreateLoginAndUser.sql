/*
Purpose: Ensure server login + database user with least privileges.
Variables expected (sqlcmd / Flyway placeholders substituted before execution):
$(DatabaseName) - database name
$(UseNamedLogin) - server login / db user name (SQL or Windows domain\user)
$(LoginName) - server login / db user name (SQL or Windows domain\user)
$(loginPassword) - strong password for SQL login (ignored for Windows logins or if login already exists)
$(GrantDatabaseOwner) - optional 1/0 elevate to db_owner (default 0)
$(GrantBulkAdmin) - optional 1/0 add to server role bulkadmin (default 0; discouraged in prod)
Notes:

Idempotent.

Uses ALTER ROLE (not deprecated sp_addrolemember).

Uses THROW and QUOTENAME; limits dynamic SQL to identifier switching and executes with sp_executesql.
*/
SET
NOCOUNT ON;

DECLARE @DatabaseName SYSNAME = N'$(DatabaseName)';

DECLARE @UseNamedLogin bit = TRY_CAST('$(UseNamedLogin)' AS bit);

DECLARE @LoginName SYSNAME = N'$(LoginName)';

DECLARE @Pwd nvarchar(256) = N'$(loginPassword)';

DECLARE @GrantDatabaseOwner bit = TRY_CAST('$(GrantDatabaseOwner)' AS bit);

DECLARE @GrantBulkAdmin bit = TRY_CAST('$(GrantBulkAdmin)' AS bit);

IF @GrantDatabaseOwner IS NULL
SET
  @GrantDatabaseOwner = 0;

IF @GrantBulkAdmin IS NULL
SET
  @GrantBulkAdmin = 0;

-- SELECT [Info] = N'UseNamedLogin=' + CONVERT(nvarchar(1), @UseNamedLogin);
-- RAISERROR(N'UseNamedLogin=%d', 10, 1, @UseNamedLogin) WITH NOWAIT;

-- Validate DatabaseName IsNotNullOrEmpty
IF @DatabaseName IS NULL
OR LTRIM(RTRIM(@DatabaseName)) = N'' THROW 50001,
'DatabaseName variable not supplied.',
1;

-- Validate DatabaseName has been created
IF DB_ID(@DatabaseName) IS NULL
BEGIN
DECLARE @msg nvarchar(2048) = N'Target database ' + QUOTENAME(@DatabaseName) + N' does not exist.';
THROW 50002,
@msg,
1;
END

-- Login / User provisioning logic adjusted for @UseNamedLogin semantics
-- Cases:
--   @UseNamedLogin = 1 and @LoginName contains '\\' or '@'  => Windows (domain / UPN) login, ignore @Pwd
--   @UseNamedLogin = 1 and @LoginName contains neither        => SQL login, require @Pwd
--   @UseNamedLogin = 0                                       => Use ORIGINAL_LOGIN(), ignore passed @LoginName/@Pwd

DECLARE @IsWindowsStyle bit =
  CASE WHEN CHARINDEX(N'\', @LoginName) > 0 OR CHARINDEX(N'@', @LoginName) > 0 THEN 1 ELSE 0 END;

IF @UseNamedLogin = 1 BEGIN
  -- Basic presence validation
  IF @LoginName IS NULL  OR LTRIM(RTRIM(@LoginName)) = N'' THROW 50000,  N'LoginName variable not supplied when @UseNamedLogin = 1.',  1;

  DECLARE @ExistingType SYSNAME = (
    SELECT
      TYPE_DESC
    FROM
      SYS.SERVER_PRINCIPALS
    WHERE
      NAME = @LoginName
  );

  IF @IsWindowsStyle = 1 BEGIN
    -- Windows / AD principal path (ignore password)
    IF @ExistingType IS NULL BEGIN
      DECLARE @CreateWin nvarchar(MAX) = N'CREATE LOGIN ' + QUOTENAME(@LoginName) + N' FROM WINDOWS;';
      EXEC SYS.SP_EXECUTESQL @CreateWin;
      PRINT (N'Created Windows login ' + @LoginName + N'.');
    END ELSE
      PRINT (    N'Windows login ' + @LoginName + N' already exists; skipping creation.'  );
  END ELSE BEGIN
    -- SQL Login processing here
    -- SQL login must have a password
    IF @Pwd IS NULL  OR LTRIM(RTRIM(@Pwd)) = N'' THROW 50011,  N'Missing password for SQL login creation when @UseNamedLogin = 1.',  1;

    IF @ExistingType IS NULL BEGIN
      -- This is a new SQL login; create it
      DECLARE @PwdLiteral nvarchar(400) = N'PASSWORD = N''' + REPLACE(@Pwd, '''', '''''') + N''', CHECK_POLICY = ON, CHECK_EXPIRATION = ON';
      DECLARE @CreateSql nvarchar(MAX) = N'CREATE LOGIN ' + QUOTENAME(@LoginName) + N' WITH ' + @PwdLiteral + N';';
      EXEC (@CreateSql);
      PRINT (N'Created SQL login ' + @LoginName + N'.');
      -- Set default database for the new login
      DECLARE @SetDefault nvarchar(MAX) = N'ALTER LOGIN ' + QUOTENAME(@LoginName) + N' WITH DEFAULT_DATABASE = ' + QUOTENAME(@DatabaseName) + N';';
      EXEC  (@SetDefault);

    END ELSE
      PRINT (N'SQL login ' + @LoginName + N' already exists; skipping creation.');
      -- ToDo : Decide if provisioning an existing login should change its default database
      -- ToDo: Currently we will change it
      DECLARE @CurrentDefault SYSNAME = (
        SELECT
          DEFAULT_DATABASE_NAME
        FROM
          SYS.SERVER_PRINCIPALS
        WHERE
          NAME = @LoginName
      );
      IF @CurrentDefault IS NOT NULL AND @CurrentDefault <> @DatabaseName BEGIN
        DECLARE @SetDefault2  nvarchar(MAX) = N'ALTER LOGIN ' + QUOTENAME(@LoginName) + N' WITH DEFAULT_DATABASE = ' + QUOTENAME(@DatabaseName) + N';';
        EXEC  (@SetDefault2);
      END
  END
END ELSE BEGIN
  -- @UseNamedLogin = 0 : Use current session login; do not attempt creation
  DECLARE @SessionLogin SYSNAME = ORIGINAL_LOGIN();
  SET    @LoginName = @SessionLogin;
  PRINT (    N'@UseNamedLogin = 0; using current session login ' + @LoginName + N'.'  );

END;


-- Optional: Add to server role bulkadmin (discouraged unless required)
IF @GrantBulkAdmin = 1 AND NOT EXISTS (
  SELECT
    1
  FROM
    SYS.SERVER_ROLE_MEMBERS RM
    JOIN SYS.SERVER_PRINCIPALS R ON R.PRINCIPAL_ID = RM.ROLE_PRINCIPAL_ID
    AND R.NAME = N'bulkadmin'
    JOIN SYS.SERVER_PRINCIPALS M ON M.PRINCIPAL_ID = RM.MEMBER_PRINCIPAL_ID
    AND M.NAME = @LoginName
) BEGIN
  DECLARE @addBulk nvarchar(MAX) = N'ALTER SERVER ROLE [bulkadmin] ADD MEMBER ' + QUOTENAME(@LoginName) + N';';
  EXEC SYS.SP_EXECUTESQL @addBulk;
END

-- Database-level work (user + roles) executed in the target database context
DECLARE @dbBatch nvarchar(MAX) = N'
USE ' + QUOTENAME(@DatabaseName) + N';
SET NOCOUNT ON;

DECLARE @u     sysname = @UserIn;
DECLARE @login sysname = @LoginIn;
DECLARE @member sysname;
DECLARE @sql   nvarchar(MAX);

-- Find any existing user already mapped to this login (by SID)
DECLARE @existingForLogin sysname =
(
  SELECT dp.name
  FROM sys.database_principals dp
  WHERE dp.sid = SUSER_SID(@login)
    AND dp.type IN (''S'',''U'',''G'')
);

-- Also check whether a user already exists with the desired name
DECLARE @userNamedAsLogin sysname =
(
  SELECT dp.name
  FROM sys.database_principals dp
  WHERE dp.name = @u
);

IF @existingForLogin IS NULL
BEGIN
  -- No user currently mapped to this login
  IF @userNamedAsLogin IS NULL
  BEGIN
    SET @sql = N''CREATE USER '' + QUOTENAME(@u) + N'' FOR LOGIN '' + QUOTENAME(@login) + N'';'';
    EXEC (@sql);
    SET @member = @u;
  END
  ELSE
  BEGIN
    -- A user with the desired name exists; (re)map it to this login
    SET @sql = N''ALTER USER '' + QUOTENAME(@u) + N'' WITH LOGIN = '' + QUOTENAME(@login) + N'';'';
    EXEC (@sql);
    SET @member = @u;
  END
END
ELSE
BEGIN
  -- A user already maps to this login; use that name for role grants
  SET @member = @existingForLogin;
END;

-- Role grants: datareader, datawriter
IF IS_ROLEMEMBER(N''db_datareader'', @member) <> 1
BEGIN
  SET @sql = N''ALTER ROLE [db_datareader] ADD MEMBER '' + QUOTENAME(@member) + N'';'';
  EXEC (@sql);
END;
IF IS_ROLEMEMBER(N''db_datawriter'', @member) <> 1
BEGIN
  SET @sql = N''ALTER ROLE [db_datawriter] ADD MEMBER '' + QUOTENAME(@member) + N'';'';
  EXEC (@sql);
END;

-- Optional: db_owner elevation
' + CASE
  WHEN @GrantDatabaseOwner = 1 THEN N'
IF IS_ROLEMEMBER(N''db_owner'', @member) <> 1
BEGIN
  SET @sql = N''ALTER ROLE [db_owner] ADD MEMBER '' + QUOTENAME(@member) + N'';'';
  EXEC (@sql);
END;'
  ELSE N''
END + N'
';
EXEC sys.sp_executesql
  @dbBatch,
  N'@UserIn sysname, @LoginIn sysname',
  @UserIn = @LoginName, @LoginIn = @LoginName;

PRINT N'Provisioning complete.';

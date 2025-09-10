/* Create target folder (if missing) */
DECLARE @DatabaseName sysname       = N'$(DatabaseName)';
DECLARE @DatabasePath nvarchar(4000) = N'$(DatabasePath)';
DECLARE @DBExists nvarchar(4000) = N'$(DBExists)';
-- e.g. C:\LocalDBs\<environment>\BuildSets

IF @DatabaseName IS NULL OR LTRIM(RTRIM(@DatabaseName)) = ''
BEGIN
  RAISERROR('DatabaseName variable not supplied',16,1);
  RETURN;
END;
IF @DatabasePath IS NULL OR LTRIM(RTRIM(@DatabasePath)) = ''
BEGIN
  RAISERROR('DatabasePath variable not supplied',16,1);
  RETURN;
END;

-- Ensure path exists
EXEC master..xp_create_subdir @DatabasePath;
GO

-- See if SQL Server and external program agree
/* Recreate database cleanly (DEV/TEST routine) */
DECLARE @DatabaseName sysname       = N'$(DatabaseName)';
DECLARE @DatabasePath nvarchar(4000) = N'$(DatabasePath)';
IF DB_ID(@DatabaseName) IS NOT NULL
BEGIN
  DECLARE @sql nvarchar(max) = N'ALTER DATABASE ['+REPLACE(@DatabaseName,']',']]')+'] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE ['+REPLACE(@DatabaseName,']',']]')+'];';
  PRINT  (@sql );
  EXEC (@sql);
END
GO
DECLARE @DatabaseName sysname       = N'$(DatabaseName)';
DECLARE @DatabasePath nvarchar(4000) = N'$(DatabasePath)';
DECLARE @dataFile nvarchar(4000)= @DatabasePath + N'\\' + @DatabaseName + N'.mdf';
DECLARE @logFile  nvarchar(4000)= @DatabasePath + N'\\' + @DatabaseName + N'_log.ldf';
DECLARE @create nvarchar(max) = N'CREATE DATABASE ['+REPLACE(@DatabaseName,']',']]')+'] ON PRIMARY ( NAME=N'''+@DatabaseName+''', FILENAME=N'''+@dataFile+''', SIZE=128MB, FILEGROWTH=64MB, MAXSIZE=UNLIMITED ) LOG ON ( NAME=N'''+@DatabaseName+'_log'', FILENAME=N'''+@logFile+''', SIZE=64MB, FILEGROWTH=64MB );';
EXEC (@create);

DECLARE @sql nvarchar(max) = N'ALTER DATABASE ['+REPLACE(@DatabaseName,']',']]')+'] SET RECOVERY SIMPLE;';
EXEC (@sql);

GO

-- DropAndCreateDatabase.sql
-- SQLCMD variables (supplied via Invoke-Sqlcmd -Variable):
--   DatabaseName  - logical database name
--   DatabasePath  - folder where .mdf / .ldf files will be created
--   DBExists      - '0' or '1' (informational; not used in T-SQL logic here)

-- Batch 1: Validate inputs and create directory
DECLARE @DatabaseName  nvarchar(256)  = N'$(DatabaseName)';
DECLARE @DatabasePath  nvarchar(4000) = N'$(DatabasePath)';
DECLARE @DBExists      nvarchar(10)   = N'$(DBExists)';

IF @DatabaseName IS NULL OR LTRIM(RTRIM(@DatabaseName)) = ''
BEGIN
    RAISERROR('DatabaseName variable not supplied', 16, 1);
    RETURN;
END;

IF @DatabasePath IS NULL OR LTRIM(RTRIM(@DatabasePath)) = ''
BEGIN
    RAISERROR('DatabasePath variable not supplied', 16, 1);
    RETURN;
END;

-- Create directory; ignore 22048 (xp_create_subdir wraps Win32 183 = already exists).
BEGIN TRY
    EXEC master.dbo.xp_create_subdir @DatabasePath;
END TRY
BEGIN CATCH
    IF NOT (ERROR_NUMBER() = 22048 AND ERROR_MESSAGE() LIKE '%183%')
        THROW;
END CATCH;
GO

-- Batch 2: Drop database if it still exists (idempotent safety; caller may have dropped it already)
DECLARE @DatabaseName nvarchar(256) = N'$(DatabaseName)';

IF DB_ID(@DatabaseName) IS NOT NULL
BEGIN
    DECLARE @sql nvarchar(MAX) =
        N'ALTER DATABASE [' + REPLACE(@DatabaseName, N']', N']]') +
        N'] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [' +
        REPLACE(@DatabaseName, N']', N']]') + N'];';
    PRINT @sql;
    EXEC (@sql);
END;
GO

-- Batch 3: Create database with data and log files
DECLARE @DatabaseName nvarchar(256)  = N'$(DatabaseName)';
DECLARE @DatabasePath nvarchar(4000) = N'$(DatabasePath)';
DECLARE @dataFile     nvarchar(4000) = @DatabasePath + N'\' + @DatabaseName + N'.mdf';
DECLARE @logFile      nvarchar(4000) = @DatabasePath + N'\' + @DatabaseName + N'_log.ldf';

DECLARE @create nvarchar(MAX) =
    N'CREATE DATABASE [' + REPLACE(@DatabaseName, N']', N']]') + N'] ON PRIMARY ' +
    N'( NAME=N''' + @DatabaseName + N''', FILENAME=N''' + @dataFile +
    N''', SIZE=128MB, FILEGROWTH=64MB, MAXSIZE=UNLIMITED ) ' +
    N'LOG ON ( NAME=N''' + @DatabaseName + N'_log'', FILENAME=N''' + @logFile +
    N''', SIZE=64MB, FILEGROWTH=64MB );';

EXEC (@create);

DECLARE @sql nvarchar(MAX) =
    N'ALTER DATABASE [' + REPLACE(@DatabaseName, N']', N']]') + N'] SET RECOVERY SIMPLE;';
EXEC (@sql);
GO

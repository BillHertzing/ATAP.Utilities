-- DropAndCreateDatabase.sql
-- SQLCMD variables (supplied via Invoke-Sqlcmd -Variable):
--   DatabaseName  - logical database name
--   DatabasePath     - folder where .mdf files will be created
--   DatabaseLogPath  - folder where .ldf files will be created
--   DBExists      - '0' or '1' (informational; not used in T-SQL logic here)

-- Batch 1: Validate inputs and verify directory
DECLARE @DatabaseName  nvarchar(256)  = N'$(DatabaseName)';
DECLARE @DatabasePath  nvarchar(4000) = N'$(DatabasePath)';
DECLARE @DatabaseLogPath nvarchar(4000) = N'$(DatabaseLogPath)';
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
IF @DatabaseLogPath IS NULL OR LTRIM(RTRIM(@DatabaseLogPath)) = ''
BEGIN
    RAISERROR('DatabaseLogPath variable not supplied', 16, 1);
    RETURN;
END;

-- DatabaseProvisioning owns folder cleanup and creation before this SQL runs.
-- Keep SQL Server validation here so CREATE DATABASE fails early with a clear
-- message if the service account cannot see or access the target folder.
DECLARE @PathStatus TABLE (
    FileExists int,
    IsDirectory int,
    ParentDirectoryExists int
);
DECLARE @FileExists int = 0;
DECLARE @IsDirectory int = 0;

INSERT INTO @PathStatus
EXEC master.dbo.xp_fileexist @DatabasePath;

SELECT TOP (1)
    @FileExists = ISNULL(FileExists, 0),
    @IsDirectory = ISNULL(IsDirectory, 0)
FROM @PathStatus;

IF @FileExists = 1 AND @IsDirectory = 0
BEGIN
    RAISERROR('DatabasePath exists as a file, not a directory: %s', 16, 1, @DatabasePath);
    RETURN;
END;

IF @IsDirectory = 0
BEGIN
    RAISERROR('DatabasePath does not exist or SQL Server cannot access it: %s', 16, 1, @DatabasePath);
    RETURN;
END;

DELETE FROM @PathStatus;
SET @FileExists = 0;
SET @IsDirectory = 0;
INSERT INTO @PathStatus
EXEC master.dbo.xp_fileexist @DatabaseLogPath;
SELECT TOP (1)
    @FileExists = ISNULL(FileExists, 0),
    @IsDirectory = ISNULL(IsDirectory, 0)
FROM @PathStatus;
IF @FileExists = 1 AND @IsDirectory = 0
BEGIN
    RAISERROR('DatabaseLogPath exists as a file, not a directory: %s', 16, 1, @DatabaseLogPath);
    RETURN;
END;
IF @IsDirectory = 0
BEGIN
    RAISERROR('DatabaseLogPath does not exist or SQL Server cannot access it: %s', 16, 1, @DatabaseLogPath);
    RETURN;
END;
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
DECLARE @DatabaseLogPath nvarchar(4000) = N'$(DatabaseLogPath)';
DECLARE @dataFile     nvarchar(4000) = @DatabasePath + N'\' + @DatabaseName + N'.mdf';
DECLARE @logFile      nvarchar(4000) = @DatabaseLogPath + N'\' + @DatabaseName + N'_log.ldf';

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

/* Create target folder (if missing) */
EXEC master..xp_create_subdir 'C:\LocalDBs\BuildSets';
GO

/* Recreate database cleanly (DEV/TEST routine) */
IF DB_ID(N'BuildSets') IS NOT NULL
BEGIN
  ALTER DATABASE [BuildSets] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE [BuildSets];
END
GO

CREATE DATABASE [BuildSets]
ON PRIMARY
(
  NAME = N'BuildSets',
  FILENAME = N'C:\LocalDBs\BuildSets\BuildSets.mdf',
  SIZE = 128MB,
  FILEGROWTH = 64MB,
  MAXSIZE = UNLIMITED
)
LOG ON
(
  NAME = N'BuildSets_log',
  FILENAME = N'C:\LocalDBs\BuildSets\BuildSets_log.ldf',
  SIZE = 64MB,
  FILEGROWTH = 64MB
);
GO

ALTER DATABASE [BuildSets] SET RECOVERY SIMPLE;
GO

USE [ATAPUtilities]
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

SET IDENTITY_INSERT dbo.GSolution OFF
GO

BEGIN
DECLARE
  @Schemaname nvarchar(1024)
  , @Tablename nvarchar(1024)
  , @Filename nvarchar(1024)
  , @sql NVARCHAR(4000)

  SELECT @Schemaname = 'dbo' 
  SELECT @Tablename ='GSolution'
  SELECT @Filename = 'C:/Dropbox/whertzing/GitHub/ATAP.Utilities/Databases/ATAPUtilities/Flyway/sql/Data_GSolution_BulkLoad.bcp' 
  BEGIN TRANSACTION
    BEGIN TRY
      SELECT @sql = 'BULK INSERT [' + @Schemaname + '].['+ @Tablename + '] FROM ''' + @Filename + ''' WITH
        (FIRSTROW= 2, FIELDTERMINATOR='','', ROWTERMINATOR=''\n'' )'
      EXEC(@sql);
      COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
      ROLLBACK TRANSACTION
      -- ToDo: Return a Failure and an Error
    END CATCH
    -- ToDo: return Success
END
GO

SET IDENTITY_INSERT dbo.GSolution OFF
GO


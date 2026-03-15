SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @data_dir nvarchar(4000) = N'${data_dir}';
DECLARE @sql nvarchar(max);
DECLARE @philotesSeedData_file nvarchar(4000) = @data_dir + N'\PhilotesSeedData.csv';



-- PhilotesSeedData staging - match actual CSV structure
IF OBJECT_ID('dbo._stg_PhilotesSeedData','U') IS NOT NULL DROP TABLE dbo._stg_PhilotesSeedData;
CREATE TABLE dbo._stg_PhilotesSeedData
(
  ID nvarchar(50) NULL,
  [Name] nvarchar(400) NULL,
);

/* --- Load PhilotesSeedData --- */
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_PhilotesSeedData
    FROM ' + QUOTENAME(@philotesSeedData_file,'''') + N'
    WITH (
        DATAFILETYPE = ''char'',
        FIELDTERMINATOR = '','',
        ROWTERMINATOR = ''0x0A'',
        FIRSTROW = 2,
        TABLOCK
    );';
    EXEC sys.sp_executesql @sql;
END TRY
BEGIN CATCH
    DECLARE @ErrorMessage nvarchar(4000) = ERROR_MESSAGE();
    THROW 50001, @ErrorMessage, 1;
END CATCH


-- Clear existing data (respecting foreign key constraints)

DELETE FROM dbo.Philotes;

-- Load Philotes with IDENTITY_INSERT and correct column mapping
SET IDENTITY_INSERT dbo.Philotes ON;
INSERT INTO dbo.Philotes (ID, [Name])
SELECT
    TRY_CONVERT(int, NULLIF(LTRIM(RTRIM(ID)),'')) AS ID,
    NULLIF(LTRIM(RTRIM([Name])),'') AS [Name]
FROM dbo._stg_PhilotesSeedData
WHERE TRY_CONVERT(int, NULLIF(LTRIM(RTRIM(ID)),'')) IS NOT NULL;
SET IDENTITY_INSERT dbo.philotes OFF;

/* --- Cleanup staging --- */
IF OBJECT_ID('dbo._stg_PhilotesSeedData','U') IS NOT NULL DROP TABLE dbo._stg_PhilotesSeedData;

/* --- Validation and Summary --- */
DECLARE @philotesCount int = (SELECT COUNT(*) FROM dbo.Philotes);
IF @philotesCount < 1
  THROW 50004, 'Philotes row count below minimum expected (1)', 1;
COMMIT;



SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @data_dir nvarchar(4000) = N'${data_dir}';
DECLARE @sql nvarchar(max);
DECLARE @tagsSeedData_file nvarchar(4000) = @data_dir + N'\TagsSeedData.csv';



-- TagsSeedData staging - match actual CSV structure
IF OBJECT_ID('dbo._stg_TagsSeedData','U') IS NOT NULL DROP TABLE dbo._stg_TagsSeedData;
CREATE TABLE dbo._stg_TagsSeedData
(
  ID nvarchar(50) NULL,
  [Name] nvarchar(400) NULL,
);

/* --- Load TagsSeedData --- */
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_TagsSeedData
    FROM ' + QUOTENAME(@tagsSeedData_file,'''') + N'
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

DELETE FROM dbo.Tags;

-- Load Tags with IDENTITY_INSERT and correct column mapping
SET IDENTITY_INSERT dbo.Tags ON;
INSERT INTO dbo.Tags (ID, [Name])
SELECT
    TRY_CONVERT(int, NULLIF(LTRIM(RTRIM(ID)),'')) AS ID,
    NULLIF(LTRIM(RTRIM([Name])),'') AS [Name]
FROM dbo._stg_TagsSeedData
WHERE TRY_CONVERT(int, NULLIF(LTRIM(RTRIM(ID)),'')) IS NOT NULL;
SET IDENTITY_INSERT dbo.tags OFF;

/* --- Cleanup staging --- */
IF OBJECT_ID('dbo._stg_TagsSeedData','U') IS NOT NULL DROP TABLE dbo._stg_TagsSeedData;

/* --- Validation and Summary --- */
DECLARE @tagsCount int = (SELECT COUNT(*) FROM dbo.Tags);
IF @tagsCount < 1
  THROW 50004, 'Tags row count below minimum expected (1)', 1;
COMMIT;



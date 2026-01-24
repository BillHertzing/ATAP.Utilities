SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @data_dir nvarchar(4000) = N'${data_dir}';
DECLARE @sql nvarchar(max);
DECLARE @interest_categories_file nvarchar(4000) = @data_dir + N'\GmailSeedData.csv';
DECLARE @gmailSeedData_file nvarchar(4000) = @data_dir + N'\GmailSeedData.csv';

/* --- Staging tables for gmailSeedData-related data (all NVARCHAR) --- */

-- GmailSeedData staging - match actual CSV structure
IF OBJECT_ID('dbo._stg_GmailSeedData','U') IS NOT NULL DROP TABLE dbo._stg_GmailSeedData;
CREATE TABLE dbo._stg_GmailSeedData
(
  ID nvarchar(50) NULL,
  [Subject] nvarchar(400) NULL,
  [URL] nvarchar(400) NULL
);

/* --- Load GmailSeedData --- */
BEGIN TRY
    SET @sql = N'BULK INSERT dbo._stg_GmailSeedData
    FROM ' + QUOTENAME(@gmailSeedData_file,'''') + N'
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

DELETE FROM dbo.gmailMessages;

-- Load gmailMessages with IDENTITY_INSERT and correct column mapping
SET IDENTITY_INSERT dbo.gmailMessages ON;
INSERT INTO dbo.gmailMessages (ID, [Subject], [URL])
SELECT
    TRY_CONVERT(int, NULLIF(LTRIM(RTRIM(ID)),'')) AS ID,
    NULLIF(LTRIM(RTRIM([Subject])),'') AS [Subject],
    NULLIF(LTRIM(RTRIM([URL])),'') AS [URL]
FROM dbo._stg_GmailSeedData
WHERE TRY_CONVERT(int, NULLIF(LTRIM(RTRIM(ID)),'')) IS NOT NULL;
SET IDENTITY_INSERT dbo.gmailMessages OFF;

/* --- Cleanup staging --- */
IF OBJECT_ID('dbo._stg_GmailSeedData','U') IS NOT NULL DROP TABLE dbo._stg_GmailSeedData;

/* --- Validation and Summary --- */
DECLARE @gmailMessagesCount int = (SELECT COUNT(*) FROM dbo.gmailMessages);
IF @gmailMessagesCount < 1
  THROW 50004, 'gmailMessages row count below minimum expected (1)', 1;
COMMIT;



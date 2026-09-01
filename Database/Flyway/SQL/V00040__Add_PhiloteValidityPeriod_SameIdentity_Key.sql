/*
  Forward-only temporal-support hardening for same-identity state references.

  This migration adds only the composite candidate key required for a dependent
  row to prove that its validity period belongs to the expected Philote.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'[ATAPUtilities].[PhiloteValidityPeriod]', N'U') IS NULL
    BEGIN
        THROW 51040, N'Required table [ATAPUtilities].[PhiloteValidityPeriod] does not exist.', 1;
    END;

    IF COL_LENGTH(N'ATAPUtilities.PhiloteValidityPeriod', N'PhiloteId') IS NULL
       OR COL_LENGTH(N'ATAPUtilities.PhiloteValidityPeriod', N'PhiloteValidityPeriodId') IS NULL
    BEGIN
        THROW 51041, N'Required same-identity key columns are missing from [ATAPUtilities].[PhiloteValidityPeriod].', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.key_constraints
        WHERE [parent_object_id] = OBJECT_ID(N'[ATAPUtilities].[PhiloteValidityPeriod]', N'U')
          AND [name] = N'UQ_PhiloteValidityPeriod_PhiloteId_PhiloteValidityPeriodId'
    )
    BEGIN
        THROW 51042, N'Constraint [UQ_PhiloteValidityPeriod_PhiloteId_PhiloteValidityPeriodId] already exists; migration cannot safely continue.', 1;
    END;

    ALTER TABLE [ATAPUtilities].[PhiloteValidityPeriod]
        ADD CONSTRAINT [UQ_PhiloteValidityPeriod_PhiloteId_PhiloteValidityPeriodId]
            UNIQUE ([PhiloteId], [PhiloteValidityPeriodId]);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;
END CATCH;

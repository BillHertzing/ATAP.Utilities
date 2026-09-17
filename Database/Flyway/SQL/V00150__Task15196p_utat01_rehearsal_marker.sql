/*
  Task 15.196.p - utat01 build/promote/deploy rehearsal marker.

  Reversible rehearsal migration: records one database-level extended property
  and changes no schema, data, principal, or permission. It exists only so the
  ATAPUtilities.Database 0.1.14 package carries a real Flyway step through the
  DatabaseChangePackage-5Stage pipeline on utat01. It is withdrawn afterwards by
  dropping the property and removing the 00150 history row (see the task
  handoff in _Planning InformationForTheFuture/Sprint0015/Task15.196).
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'[ATAPUtilities].[ContentSummary]', N'U') IS NULL
        THROW 60600, N'V00150 requires the successful V00010-V00140 predecessor chain.', 1;

    DECLARE @RehearsalValue sql_variant =
        CONVERT(nvarchar(128), N'utat01 ' + CONVERT(nvarchar(30), SYSUTCDATETIME(), 126) + N'Z ' + @@SERVERNAME);

    IF EXISTS (
        SELECT 1 FROM sys.extended_properties
        WHERE class = 0 AND name = N'ATAP.Rehearsal.Task15196p')
        EXEC sys.sp_updateextendedproperty
            @name = N'ATAP.Rehearsal.Task15196p', @value = @RehearsalValue;
    ELSE
        EXEC sys.sp_addextendedproperty
            @name = N'ATAP.Rehearsal.Task15196p', @value = @RehearsalValue;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

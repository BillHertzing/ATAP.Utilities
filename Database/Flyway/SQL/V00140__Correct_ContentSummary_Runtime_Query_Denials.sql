/*
  Correct the V00130 runtime-query denials without widening query access.

  A schema-scoped DENY is inherited across all role memberships and therefore
  blocked AceOutpost's separately granted startup access to the historical
  AceOutpostContentSummaryPrototype table. Object-scoped denials retain the
  fail-closed query boundary without interfering with unrelated roles.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'[ATAPUtilities].[ResolveContentSummaryTagCodeAsOfV1]', N'P') IS NULL
       OR DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryRuntimeQuery') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[Tag]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[TagAlias]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[ContentSummary]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[AceOutpostContentSummaryPrototype]', N'U') IS NULL
        THROW 60500, N'V00140 requires the successful V00010-V00130 predecessor chain.', 1;

    REVOKE SELECT, INSERT, UPDATE, DELETE, ALTER, VIEW DEFINITION
        ON SCHEMA::[ATAPUtilities] FROM [ATAPContentSummaryRuntimeQuery];

    DENY SELECT, INSERT, UPDATE, DELETE, ALTER, VIEW DEFINITION
        ON OBJECT::[ATAPUtilities].[Tag] TO [ATAPContentSummaryRuntimeQuery];
    DENY SELECT, INSERT, UPDATE, DELETE, ALTER, VIEW DEFINITION
        ON OBJECT::[ATAPUtilities].[TagAlias] TO [ATAPContentSummaryRuntimeQuery];
    DENY SELECT, INSERT, UPDATE, DELETE, ALTER, VIEW DEFINITION
        ON OBJECT::[ATAPUtilities].[ContentSummary] TO [ATAPContentSummaryRuntimeQuery];

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

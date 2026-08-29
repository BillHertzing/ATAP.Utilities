/*
  Forward-only schema bridge for the ratified AceOutpost content-summary prototype.

  This migration deliberately creates no principals, grants, seed data, or other
  database objects. A pre-existing target object is a deployment conflict: fail
  closed rather than silently accepting an incompatible schema.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF SCHEMA_ID(N'ATAPUtilities') IS NULL
    BEGIN
        THROW 51030, N'Required schema [ATAPUtilities] does not exist.', 1;
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[AceOutpostContentSummaryPrototype]') IS NOT NULL
    BEGIN
        THROW 51031, N'Object [ATAPUtilities].[AceOutpostContentSummaryPrototype] already exists; migration cannot safely continue.', 1;
    END;

    CREATE TABLE [ATAPUtilities].[AceOutpostContentSummaryPrototype]
    (
        [OperationId] uniqueidentifier NOT NULL,
        [Payload] nvarchar(4000) NOT NULL,
        CONSTRAINT [PK_AceOutpostContentSummaryPrototype]
            PRIMARY KEY ([OperationId]),
        CONSTRAINT [CK_AceOutpostContentSummaryPrototype_Payload]
            CHECK (LEN([Payload]) BETWEEN 1 AND 4000)
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;
END CATCH;

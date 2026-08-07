-- =====================================================================
-- V00.02.000090__Assert_RulePrimitive_Rule_Identity_Invariant.sql
--
-- Sprint 0013 Task 13.78 follow-up. Forward-only re-expression of the
-- idempotency fix that commit c682e197b applied, incorrectly, by editing
-- the already-applied migrations V00.01.000022 and V00.01.000023.
--
-- WHY THIS MIGRATION ASSERTS RATHER THAN CHANGES
--   The fix being re-expressed did two things to each CSV loader: it added
--   duplicate-source THROW guards, and it changed the seed anti-join key
--   from PhiloteId to (PrimitiveLanguageKindId, Name). Neither is
--   re-expressible as a data or schema change, because:
--     * The identity invariant those guards protect is ALREADY enforced by
--       UQ_RulePrimitive_Language_Name and UQ_Rule_Language_Name, both
--       UNIQUE on (PrimitiveLanguageKindId, Name), created by the core
--       schema migration V00.01.000010 and verified present on all five
--       utat01 tiers on 2026-07-27.
--     * The edit was proven output-neutral on this data: row-set
--       fingerprints for RulePrimitive and Rule are identical across every
--       tier, and zero duplicate (KindId, Name) groups exist anywhere, so
--       the added guards could never have fired.
--   A migration that re-applied the constraint would therefore be a no-op,
--   and one that re-seeded rows would be a fabrication. What was actually
--   missing is an EXPLICIT, TIER-UNIFORM, RECORDED check that the invariant
--   holds. That is what this migration is.
--
--   Effect on a tier where the invariant holds: none, beyond a history row
--   proving the tier was checked. Effect where it does not hold: the
--   migration fails loudly and blocks promotion, which is the entire point.
--
-- CONTRACT
--   * Makes NO schema or data change. Assertions only.
--   * Idempotent and re-runnable.
--   * Runs identically on a from-scratch tier (which executed the guarded
--     loaders) and on a repaired tier (which executed the unguarded ones),
--     so both provably arrive at the same enforced state.
--
-- Durable finding: _Planning InformationForTheFuture/
--                  Task-13.78-Tier-Checksum-Drift-Finding.md
-- =====================================================================
SET XACT_ABORT ON;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

BEGIN TRANSACTION;

BEGIN TRY

    -- -----------------------------------------------------------------
    -- 1. The two durable identity tables must exist.
    -- -----------------------------------------------------------------
    IF OBJECT_ID(N'ATAPUtilities.RulePrimitive', N'U') IS NULL
        THROW 50090, 'V00.02.000090 aborted: ATAPUtilities.RulePrimitive is missing.', 1;

    IF OBJECT_ID(N'ATAPUtilities.[Rule]', N'U') IS NULL
        THROW 50090, 'V00.02.000090 aborted: ATAPUtilities.Rule is missing.', 1;

    -- -----------------------------------------------------------------
    -- 2. The identity invariant must be ENFORCED, not merely satisfied.
    --    A tier that happens to hold no duplicates but has lost the unique
    --    index is one bad insert away from divergence, so assert the index
    --    itself: unique, exactly two key columns, in the documented order.
    -- -----------------------------------------------------------------
    DECLARE @tableName SYSNAME;
    DECLARE @indexName SYSNAME;
    DECLARE @msg       NVARCHAR(400);

    DECLARE IdentityIndexCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT N'ATAPUtilities.RulePrimitive', N'UQ_RulePrimitive_Language_Name'
        UNION ALL
        SELECT N'ATAPUtilities.[Rule]',        N'UQ_Rule_Language_Name';

    OPEN IdentityIndexCursor;
    FETCH NEXT FROM IdentityIndexCursor INTO @tableName, @indexName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM sys.indexes AS i
            WHERE i.object_id = OBJECT_ID(@tableName)
              AND i.name      = @indexName
              AND i.is_unique = 1
        )
        BEGIN
            SET @msg = N'V00.02.000090 aborted: unique index ' + @indexName
                     + N' on ' + @tableName + N' is missing or is not unique. '
                     + N'The RulePrimitive/Rule identity invariant is unenforced on this tier.';
            THROW 50091, @msg, 1;
        END;

        -- Exactly (PrimitiveLanguageKindId, Name), key_ordinal 1 then 2.
        IF NOT EXISTS (
            SELECT 1
            FROM sys.indexes AS i
            WHERE i.object_id = OBJECT_ID(@tableName)
              AND i.name      = @indexName
              AND 2 = (SELECT COUNT(*) FROM sys.index_columns AS ic
                       WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id
                         AND ic.key_ordinal > 0)
              AND EXISTS (SELECT 1 FROM sys.index_columns AS ic
                          JOIN sys.columns AS c
                            ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                          WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id
                            AND ic.key_ordinal = 1 AND c.name = N'PrimitiveLanguageKindId')
              AND EXISTS (SELECT 1 FROM sys.index_columns AS ic
                          JOIN sys.columns AS c
                            ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                          WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id
                            AND ic.key_ordinal = 2 AND c.name = N'Name')
        )
        BEGIN
            SET @msg = N'V00.02.000090 aborted: unique index ' + @indexName + N' on ' + @tableName
                     + N' does not key exactly (PrimitiveLanguageKindId, Name) in that order.';
            THROW 50092, @msg, 1;
        END;

        FETCH NEXT FROM IdentityIndexCursor INTO @tableName, @indexName;
    END;

    CLOSE IdentityIndexCursor;
    DEALLOCATE IdentityIndexCursor;

    -- -----------------------------------------------------------------
    -- 3. The invariant must also HOLD in the data. Belt and braces: a
    --    unique index cannot be present and violated at the same time, so
    --    a failure here means the index was created WITH NOCHECK-like
    --    trickery, disabled, or the table was loaded around it.
    -- -----------------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM ATAPUtilities.RulePrimitive
        GROUP BY PrimitiveLanguageKindId, [Name]
        HAVING COUNT_BIG(*) > 1
    )
        THROW 50093, 'V00.02.000090 aborted: duplicate (PrimitiveLanguageKindId, Name) rows exist in ATAPUtilities.RulePrimitive.', 1;

    IF EXISTS (
        SELECT 1 FROM ATAPUtilities.[Rule]
        GROUP BY PrimitiveLanguageKindId, [Name]
        HAVING COUNT_BIG(*) > 1
    )
        THROW 50094, 'V00.02.000090 aborted: duplicate (PrimitiveLanguageKindId, Name) rows exist in ATAPUtilities.Rule.', 1;

    -- -----------------------------------------------------------------
    -- 4. Philote identity must remain one-to-one with each durable row.
    --    The pre-fix loaders keyed their anti-join on PhiloteId; if that
    --    ever admitted a second Philote for one logical identity, this is
    --    where it surfaces.
    -- -----------------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM ATAPUtilities.RulePrimitive
        GROUP BY PhiloteId HAVING COUNT_BIG(*) > 1
    )
        THROW 50095, 'V00.02.000090 aborted: duplicate PhiloteId rows exist in ATAPUtilities.RulePrimitive.', 1;

    IF EXISTS (
        SELECT 1 FROM ATAPUtilities.[Rule]
        GROUP BY PhiloteId HAVING COUNT_BIG(*) > 1
    )
        THROW 50096, 'V00.02.000090 aborted: duplicate PhiloteId rows exist in ATAPUtilities.Rule.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'IdentityIndexCursor') >= 0
    BEGIN
        CLOSE IdentityIndexCursor;
        DEALLOCATE IdentityIndexCursor;
    END;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

PRINT N'V00.02.000090 - RulePrimitive/Rule identity invariant asserted: unique indexes enforced, no duplicate identities, no duplicate Philotes.';

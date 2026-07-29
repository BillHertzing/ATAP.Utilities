-- =====================================================================
-- V00.02.000100__Add_RRSBS_Effective_Dating.sql
--
-- Makes effective dating the authoritative lifecycle model for the RRSBS
-- instantiation tree. A NULL EffectiveTo identifies the one current version
-- of a logical Philote-backed object; VersionNumber and VersionLabel remain
-- descriptive history, not the current-version selector.
-- =====================================================================
SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRANSACTION;

BEGIN TRY
    DECLARE @temporalTables TABLE (
        TableName SYSNAME NOT NULL PRIMARY KEY,
        CurrentKeyColumns NVARCHAR(500) NOT NULL
    );

    INSERT INTO @temporalTables (TableName, CurrentKeyColumns) VALUES
        (N'Philote', N'[PhiloteId]'),
        (N'RuleInstantiation', N'[PhiloteId]'),
        (N'RuleInstantiationBinding', N'[InstantiationPhiloteId], [InputName]'),
        (N'InstantiationVersion', N'[InstantiationPhiloteId]'),
        (N'RuleVersion', N'[RulePhiloteId]'),
        (N'RuleVersionPrimitiveComposition', N'[RuleVersionPhiloteId], [Position]'),
        (N'RuleSetVersion', N'[RuleSetPhiloteId]'),
        (N'RuleSetVersionMember', N'[RuleSetVersionPhiloteId], [RuleVersionPhiloteId]'),
        (N'BuildSetVersion', N'[BuildSetPhiloteId]'),
        (N'BuildSetVersionMember', N'[BuildSetVersionPhiloteId], [RuleSetVersionPhiloteId]'),
        (N'RuleInstantiationVersion', N'[RuleInstantiationPhiloteId]'),
        (N'InstantiationVersionRuleInstantiationVersion', N'[InstantiationVersionPhiloteId], [RuleInstantiationVersionPhiloteId]'),
        (N'ManifestationArtifact', N'[InstantiationVersionPhiloteId], [RelativePath]');

    DECLARE @tableName SYSNAME;
    DECLARE @currentKeyColumns NVARCHAR(500);
    DECLARE @sql NVARCHAR(MAX);

    DECLARE addColumns CURSOR LOCAL FAST_FORWARD FOR
        SELECT TableName, CurrentKeyColumns
        FROM @temporalTables
        WHERE OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(TableName), N'U') IS NOT NULL;

    OPEN addColumns;
    FETCH NEXT FROM addColumns INTO @tableName, @currentKeyColumns;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF COL_LENGTH(N'ATAPUtilities.' + QUOTENAME(@tableName), N'EffectiveFrom') IS NULL
        BEGIN
            SET @sql = N'ALTER TABLE ATAPUtilities.' + QUOTENAME(@tableName)
                + N' ADD EffectiveFrom DATETIME2(7) NULL;';
            EXEC sp_executesql @sql;
        END;

        IF COL_LENGTH(N'ATAPUtilities.' + QUOTENAME(@tableName), N'EffectiveTo') IS NULL
        BEGIN
            SET @sql = N'ALTER TABLE ATAPUtilities.' + QUOTENAME(@tableName)
                + N' ADD EffectiveTo DATETIME2(7) NULL;';
            EXEC sp_executesql @sql;
        END;

        SET @sql = N'UPDATE ATAPUtilities.' + QUOTENAME(@tableName)
            + N' SET EffectiveFrom = COALESCE(EffectiveFrom, '
            + CASE WHEN COL_LENGTH(N'ATAPUtilities.' + QUOTENAME(@tableName), N'CreatedAt') IS NOT NULL
                   THEN N'CreatedAt, '
                   ELSE N''
              END
            + N'SYSUTCDATETIME()) WHERE EffectiveFrom IS NULL;';
        EXEC sp_executesql @sql;

        IF NOT EXISTS (
            SELECT 1
            FROM sys.check_constraints
            WHERE parent_object_id = OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(@tableName))
              AND name = N'CK_' + @tableName + N'_EffectiveRange')
        BEGIN
            SET @sql = N'ALTER TABLE ATAPUtilities.' + QUOTENAME(@tableName)
                + N' ADD CONSTRAINT ' + QUOTENAME(N'CK_' + @tableName + N'_EffectiveRange')
                + N' CHECK (EffectiveTo IS NULL OR EffectiveTo > EffectiveFrom);';
            EXEC sp_executesql @sql;
        END;

        SET @sql = N'ALTER TABLE ATAPUtilities.' + QUOTENAME(@tableName)
            + N' ALTER COLUMN EffectiveFrom DATETIME2(7) NOT NULL;';
        EXEC sp_executesql @sql;

        FETCH NEXT FROM addColumns INTO @tableName, @currentKeyColumns;
    END;

    CLOSE addColumns;
    DEALLOCATE addColumns;

    -- Remove the pre-effective-date immutable triggers before closing seeded
    -- predecessor rows. They are recreated below with close-only semantics.
    DECLARE @existingImmutableTriggers TABLE (TriggerName SYSNAME NOT NULL PRIMARY KEY);
    INSERT INTO @existingImmutableTriggers (TriggerName) VALUES
        (N'TR_RuleVersion_Immutable'),
        (N'TR_RuleVersionPrimitiveComposition_Immutable'),
        (N'TR_RuleSetVersion_Immutable'),
        (N'TR_RuleSetVersionMember_Immutable'),
        (N'TR_BuildSetVersion_Immutable'),
        (N'TR_BuildSetVersionMember_Immutable'),
        (N'TR_RuleInstantiationVersion_Immutable'),
        (N'TR_IVRIV_Immutable');

    DECLARE @existingTriggerName SYSNAME;
    DECLARE removeExistingTriggers CURSOR LOCAL FAST_FORWARD FOR
        SELECT TriggerName FROM @existingImmutableTriggers
        WHERE OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(TriggerName), N'TR') IS NOT NULL;

    OPEN removeExistingTriggers;
    FETCH NEXT FROM removeExistingTriggers INTO @existingTriggerName;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = N'DROP TRIGGER ATAPUtilities.' + QUOTENAME(@existingTriggerName) + N';';
        EXEC sp_executesql @sql;
        FETCH NEXT FROM removeExistingTriggers INTO @existingTriggerName;
    END;
    CLOSE removeExistingTriggers;
    DEALLOCATE removeExistingTriggers;

    -- A logical object can have one, and only one, open version. The unique
    -- filtered index expresses the definition of "current" without relying
    -- on VersionNumber, VersionLabel, or insertion order.
    DECLARE addCurrentIndexes CURSOR LOCAL FAST_FORWARD FOR
        SELECT TableName, CurrentKeyColumns
        FROM @temporalTables
        WHERE OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(TableName), N'U') IS NOT NULL;

    OPEN addCurrentIndexes;
    FETCH NEXT FROM addCurrentIndexes INTO @tableName, @currentKeyColumns;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @indexName SYSNAME = N'UX_' + @tableName + N'_Current';
        DECLARE @primaryKeyColumns NVARCHAR(MAX);
        DECLARE @currentPrimaryKeyJoin NVARCHAR(MAX);

        SELECT @primaryKeyColumns = STRING_AGG(QUOTENAME(c.name), N', ')
        FROM sys.indexes AS i
        INNER JOIN sys.index_columns AS ic
            ON ic.object_id = i.object_id AND ic.index_id = i.index_id
        INNER JOIN sys.columns AS c
            ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE i.object_id = OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(@tableName))
          AND i.is_primary_key = 1;

        SELECT @currentPrimaryKeyJoin = STRING_AGG(N't.' + QUOTENAME(c.name) + N' = o.' + QUOTENAME(c.name), N' AND ')
        FROM sys.indexes AS i
        INNER JOIN sys.index_columns AS ic
            ON ic.object_id = i.object_id AND ic.index_id = i.index_id
        INNER JOIN sys.columns AS c
            ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE i.object_id = OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(@tableName))
          AND i.is_primary_key = 1;

        -- Existing seeded snapshot rows predate effective dating. Close every
        -- predecessor before installing the one-current-row index.
        SET @sql = N';WITH OrderedOpenRows AS (
                SELECT ' + @primaryKeyColumns + N', EffectiveFrom,
                       LEAD(EffectiveFrom) OVER (
                           PARTITION BY ' + @currentKeyColumns + N'
                           ORDER BY EffectiveFrom, ' + @primaryKeyColumns + N') AS NextEffectiveFrom
                FROM ATAPUtilities.' + QUOTENAME(@tableName) + N'
                WHERE EffectiveTo IS NULL
            )
            UPDATE t
            SET EffectiveTo = CASE
                WHEN o.NextEffectiveFrom <= t.EffectiveFrom THEN DATEADD(NANOSECOND, 100, t.EffectiveFrom)
                ELSE o.NextEffectiveFrom
            END
            FROM ATAPUtilities.' + QUOTENAME(@tableName) + N' AS t
            INNER JOIN OrderedOpenRows AS o ON ' + @currentPrimaryKeyJoin + N'
            WHERE o.NextEffectiveFrom IS NOT NULL
              AND t.EffectiveTo IS NULL;';
        EXEC sp_executesql @sql;

        IF NOT EXISTS (
            SELECT 1 FROM sys.indexes
            WHERE object_id = OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(@tableName))
              AND name = @indexName)
        BEGIN
            SET @sql = N'CREATE UNIQUE INDEX ' + QUOTENAME(@indexName)
                + N' ON ATAPUtilities.' + QUOTENAME(@tableName)
                + N' (' + @currentKeyColumns + N') WHERE EffectiveTo IS NULL;';
            EXEC sp_executesql @sql;
        END;

        FETCH NEXT FROM addCurrentIndexes INTO @tableName, @currentKeyColumns;
    END;

    CLOSE addCurrentIndexes;
    DEALLOCATE addCurrentIndexes;

    -- Version rows and their memberships are append-only except for closing
    -- an open interval. Rebuild the existing triggers to permit exactly that
    -- transition and to reject deletes, re-open attempts, and content edits.
    DECLARE @immutableTables TABLE (TableName SYSNAME NOT NULL PRIMARY KEY, TriggerName SYSNAME NOT NULL);
    INSERT INTO @immutableTables (TableName, TriggerName) VALUES
        (N'RuleVersion', N'TR_RuleVersion_Immutable'),
        (N'RuleVersionPrimitiveComposition', N'TR_RuleVersionPrimitiveComposition_Immutable'),
        (N'RuleSetVersion', N'TR_RuleSetVersion_Immutable'),
        (N'RuleSetVersionMember', N'TR_RuleSetVersionMember_Immutable'),
        (N'BuildSetVersion', N'TR_BuildSetVersion_Immutable'),
        (N'BuildSetVersionMember', N'TR_BuildSetVersionMember_Immutable'),
        (N'RuleInstantiationVersion', N'TR_RuleInstantiationVersion_Immutable'),
        (N'InstantiationVersionRuleInstantiationVersion', N'TR_IVRIV_Immutable');

    DECLARE immutableCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT TableName, TriggerName FROM @immutableTables
        WHERE OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(TableName), N'U') IS NOT NULL;

    OPEN immutableCursor;
    FETCH NEXT FROM immutableCursor INTO @tableName, @currentKeyColumns;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @triggerName SYSNAME = @currentKeyColumns;
        DECLARE @comparisonColumns NVARCHAR(MAX);
        DECLARE @primaryKeyJoin NVARCHAR(MAX);

        SELECT @comparisonColumns = STRING_AGG(QUOTENAME(c.name), N', ')
        FROM sys.columns AS c
        WHERE c.object_id = OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(@tableName))
          AND c.name <> N'EffectiveTo';

        SELECT @primaryKeyJoin = STRING_AGG(N'i.' + QUOTENAME(c.name) + N' = d.' + QUOTENAME(c.name), N' AND ')
        FROM sys.indexes AS i
        INNER JOIN sys.index_columns AS ic
            ON ic.object_id = i.object_id AND ic.index_id = i.index_id
        INNER JOIN sys.columns AS c
            ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE i.object_id = OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(@tableName))
          AND i.is_primary_key = 1;

        IF OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(@triggerName), N'TR') IS NOT NULL
        BEGIN
            SET @sql = N'DROP TRIGGER ATAPUtilities.' + QUOTENAME(@triggerName) + N';';
            EXEC sp_executesql @sql;
        END;

        SET @sql = N'CREATE TRIGGER ATAPUtilities.' + QUOTENAME(@triggerName)
            + N' ON ATAPUtilities.' + QUOTENAME(@tableName)
            + N' AFTER UPDATE, DELETE AS
               BEGIN
                   SET NOCOUNT ON;
                   IF (SELECT COUNT(*) FROM inserted) <> (SELECT COUNT(*) FROM deleted)
                       THROW 50100, N''Deleting an effective-dated RRSBS row is forbidden.'', 1;
                   IF EXISTS (SELECT ' + @comparisonColumns + N' FROM inserted EXCEPT SELECT ' + @comparisonColumns + N' FROM deleted)
                      OR EXISTS (SELECT ' + @comparisonColumns + N' FROM deleted EXCEPT SELECT ' + @comparisonColumns + N' FROM inserted)
                       THROW 50101, N''Only EffectiveTo may change on an effective-dated RRSBS row.'', 1;
                   IF EXISTS (
                       SELECT 1
                       FROM inserted AS i
                       INNER JOIN deleted AS d ON ' + @primaryKeyJoin + N'
                       WHERE d.EffectiveTo IS NOT NULL
                          OR i.EffectiveTo IS NULL
                          OR i.EffectiveTo <= i.EffectiveFrom
                          OR i.EffectiveTo > SYSUTCDATETIME())
                       THROW 50102, N''EffectiveTo may close an open RRSBS row only once, after EffectiveFrom, at a UTC timestamp.'', 1;
               END;';
        EXEC sp_executesql @sql;

        FETCH NEXT FROM immutableCursor INTO @tableName, @currentKeyColumns;
    END;

    CLOSE immutableCursor;
    DEALLOCATE immutableCursor;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

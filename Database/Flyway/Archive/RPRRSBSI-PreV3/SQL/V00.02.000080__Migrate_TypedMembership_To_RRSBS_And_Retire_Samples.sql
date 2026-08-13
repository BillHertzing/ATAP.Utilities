-- =====================================================================
-- V00.02.000080__Migrate_TypedMembership_To_RRSBS_And_Retire_Samples.sql
--
-- Sprint 0013 Tasks 13.78.h and 13.78.i.
--
-- 13.78.h  Copies the useful Repository and SourceModule path values that
--          were carried by the Sprint 0012 typed instantiation structures
--          into the durable RRSBS input model
--          (ATAPUtilities.[Rule] -> RuleInstantiation -> RuleInstantiationBinding),
--          verifies the copy in-transaction, and deprecates the typed
--          membership tables InstantiationVersionComputer,
--          InstantiationVersionRepository, and InstantiationVersionSourceModule
--          via extended properties. No table is dropped.
--
-- 13.78.i  Proves that no retained row depends on the Sprint 0012 v1/v2
--          sample InstantiationVersion rows, then removes those rows and
--          their dependents by exact GUID literal in FK-safe order.
--
-- Runs AFTER V00.02.000070 (durable RRSBS DDL). This is data movement and
-- deprecation, not DDL, so it is a separate forward-only migration version.
--
-- All new Philote-backed rows use stable caller-supplied GUID literals.
-- The whole migration is a single transaction: any verification failure
-- rolls back every change made here.
-- =====================================================================
SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRANSACTION;

BEGIN TRY
    -- =================================================================
    -- 1. Preconditions - fail loudly rather than silently under-migrate
    -- =================================================================
    DECLARE @ErrorMessage NVARCHAR(2000);

    IF OBJECT_ID(N'ATAPUtilities.Philote', N'U') IS NULL
        OR OBJECT_ID(N'ATAPUtilities.PrimitiveLanguageKind', N'U') IS NULL
        OR OBJECT_ID(N'ATAPUtilities.[Rule]', N'U') IS NULL
        OR OBJECT_ID(N'ATAPUtilities.RuleInstantiation', N'U') IS NULL
        OR OBJECT_ID(N'ATAPUtilities.RuleInstantiationBinding', N'U') IS NULL
        OR OBJECT_ID(N'ATAPUtilities.Repository', N'U') IS NULL
        OR OBJECT_ID(N'ATAPUtilities.SourceModule', N'U') IS NULL
        OR OBJECT_ID(N'ATAPUtilities.Instantiation', N'U') IS NULL
        OR OBJECT_ID(N'ATAPUtilities.InstantiationVersion', N'U') IS NULL
        OR OBJECT_ID(N'ATAPUtilities.InstantiationVersionComputer', N'U') IS NULL
        OR OBJECT_ID(N'ATAPUtilities.InstantiationVersionRepository', N'U') IS NULL
        OR OBJECT_ID(N'ATAPUtilities.InstantiationVersionSourceModule', N'U') IS NULL
        OR OBJECT_ID(N'ATAPUtilities.ManifestationArtifact', N'U') IS NULL
    BEGIN
        SET @ErrorMessage = N'V00.02.000080: a required ATAPUtilities table is missing. '
            + N'Expected the V00.01.000010 core schema and the V00.02.000060 instantiation tables to be applied first.';
        THROW 50080, @ErrorMessage, 1;
    END;

    -- The durable rule-input surface this migration writes into is the
    -- V00.01.000010 shape: RuleInstantiation (PhiloteId, RulePhiloteId, Notes)
    -- and RuleInstantiationBinding (InstantiationPhiloteId, InputName, InputValue).
    -- V00.02.000070 keeps that shape and only ADDs a nullable
    -- InstantiationPhiloteId column to RuleInstantiation; it explicitly does
    -- not reshape RuleInstantiationBinding. Assert the shape anyway rather
    -- than trusting the ordering of two separately authored migrations.
    IF COL_LENGTH(N'ATAPUtilities.RuleInstantiation', N'PhiloteId') IS NULL
        OR COL_LENGTH(N'ATAPUtilities.RuleInstantiation', N'RulePhiloteId') IS NULL
        OR COL_LENGTH(N'ATAPUtilities.RuleInstantiationBinding', N'InstantiationPhiloteId') IS NULL
        OR COL_LENGTH(N'ATAPUtilities.RuleInstantiationBinding', N'InputName') IS NULL
        OR COL_LENGTH(N'ATAPUtilities.RuleInstantiationBinding', N'InputValue') IS NULL
    BEGIN
        SET @ErrorMessage = N'V00.02.000080: ATAPUtilities.RuleInstantiation / RuleInstantiationBinding do not have the '
            + N'expected V00.01.000010 column shape. Resolve the RuleInstantiation shape conflict between '
            + N'V00.01.000010 and V00.02.000070 before running this migration.';
        THROW 50081, @ErrorMessage, 1;
    END;

    DECLARE @PathKindId TINYINT =
        (SELECT PrimitiveLanguageKindId FROM ATAPUtilities.PrimitiveLanguageKind WHERE [Name] = N'Path');

    IF @PathKindId IS NULL
    BEGIN
        SET @ErrorMessage = N'V00.02.000080: PrimitiveLanguageKind ''Path'' was not found. '
            + N'The migrated values are filesystem paths and require the Path rule kind.';
        THROW 50082, @ErrorMessage, 1;
    END;

    -- =================================================================
    -- 2. Migration plan - what is copied, from where, into which rows
    -- =================================================================
    DECLARE @SecurityModulePhiloteId       UNIQUEIDENTIFIER = '4786d272-3406-43a5-a2c7-8c044a2d5cd4';
    DECLARE @SecretsModulePhiloteId        UNIQUEIDENTIFIER = '33e208e8-3095-43c1-9981-d3ab0c8a8b29';
    DECLARE @SecretsPowerShellPhiloteId    UNIQUEIDENTIFIER = '636db902-4a63-4196-a85e-ca7df2f2d425';
    DECLARE @RepositoryPhiloteId           UNIQUEIDENTIFIER = '904de22d-1df6-481c-b5da-635a4b153e83';
    DECLARE @Version1PhiloteId             UNIQUEIDENTIFIER = 'f4d25915-a988-498c-be31-f28830c95310';
    DECLARE @Version2PhiloteId             UNIQUEIDENTIFIER = '78388d60-dc2d-48ce-a041-7d10c59e7f49';

    DECLARE @Plan TABLE (
        Ordinal                    INT              NOT NULL PRIMARY KEY,
        RulePhiloteId              UNIQUEIDENTIFIER NOT NULL,
        RuleInstantiationPhiloteId UNIQUEIDENTIFIER NOT NULL,
        RuleName                   NVARCHAR(200)    NOT NULL,
        RulePurpose                NVARCHAR(400)    NOT NULL,
        SourceTableName            NVARCHAR(200)    NOT NULL,
        SourceColumnName           NVARCHAR(200)    NOT NULL,
        SourceRowPhiloteId         UNIQUEIDENTIFIER NOT NULL,
        SourceVersionPhiloteId     UNIQUEIDENTIFIER     NULL,
        PathType                   NVARCHAR(20)     NOT NULL,
        PathValue                  NVARCHAR(500)        NULL
    );

    INSERT INTO @Plan
        (Ordinal, RulePhiloteId, RuleInstantiationPhiloteId, RuleName, RulePurpose,
         SourceTableName, SourceColumnName, SourceRowPhiloteId, SourceVersionPhiloteId, PathType)
    VALUES
        (1,  '0c5a55da-43f7-4643-b839-cffc4917a65a', 'e2105135-822d-437c-b1ff-f3370ee008c9',
             N'Instantiation.Repository.ATAP.Utilities.StableRootPath',
             N'Stable-branch worktree root path of the ATAP.Utilities repository.',
             N'ATAPUtilities.Repository', N'StableRootPath', @RepositoryPhiloteId, NULL, N'Absolute'),
        (2,  'd393423d-54cc-443e-9425-e4bef60c9743', '914d186b-77c8-4103-a8ce-2031c481f4d6',
             N'Instantiation.Repository.ATAP.Utilities.SprintRootPath',
             N'Sprint-branch worktree root path of the ATAP.Utilities repository.',
             N'ATAPUtilities.Repository', N'SprintRootPath', @RepositoryPhiloteId, NULL, N'Absolute'),
        (3,  'ce8cb081-085b-4440-96dc-06297557a161', '6447554e-1ce3-44d0-a8fb-79af02cf73f6',
             N'Instantiation.SourceModule.ATAP.Utilities.Security.Powershell.SourceRoot',
             N'Repository-relative source root of the ATAP.Utilities.Security.Powershell module.',
             N'ATAPUtilities.SourceModule', N'SourceRootRelativePath', @SecurityModulePhiloteId, NULL, N'Relative'),
        (4,  '0d280229-3154-4746-8847-d6a3c539b16d', '60c2ba37-b052-48a0-be08-a9ecd492fa0b',
             N'Instantiation.SourceModule.ATAP.Utilities.Security.Powershell.Manifest',
             N'Repository-relative module manifest path of ATAP.Utilities.Security.Powershell.',
             N'ATAPUtilities.SourceModule', N'ManifestRelativePath', @SecurityModulePhiloteId, NULL, N'Relative'),
        (5,  'feeb5ef5-0246-459f-abab-fda5975fd1d3', '19519d49-db33-4faa-97ad-a13a751227c7',
             N'Instantiation.SourceModule.ATAP.Utilities.Security.Powershell.PublicFunctions',
             N'Repository-relative public functions folder of ATAP.Utilities.Security.Powershell.',
             N'ATAPUtilities.SourceModule', N'PublicFunctionsRelativePath', @SecurityModulePhiloteId, NULL, N'Relative'),
        (6,  '43046161-82b9-440c-8d97-0992d98ffab5', '58a891fa-0fa7-47c9-af1a-6b47bb26dbb1',
             N'Instantiation.SourceModule.ATAP.Utilities.Security.Powershell.PrivateFunctions',
             N'Repository-relative private functions folder of ATAP.Utilities.Security.Powershell.',
             N'ATAPUtilities.SourceModule', N'PrivateFunctionsRelativePath', @SecurityModulePhiloteId, NULL, N'Relative'),
        (7,  '6ff6f212-4c72-48af-bd4d-0769b53ebc96', '4817614b-333f-46c3-a887-0517b1bb9994',
             N'Instantiation.SourceModule.ATAP.Utilities.Secrets.SourceRoot',
             N'Repository-relative source root of the ATAP.Utilities.Secrets C# project.',
             N'ATAPUtilities.SourceModule', N'SourceRootRelativePath', @SecretsModulePhiloteId, NULL, N'Relative'),
        (8,  'f16e9abb-4e5b-4c1e-88d6-ee341ba991c4', 'c2a960f9-fc5f-4ca7-9aea-0a627e01db07',
             N'Instantiation.SourceModule.ATAP.Utilities.Secrets.PowerShell.SourceRoot',
             N'Repository-relative source root of the planned ATAP.Utilities.Secrets.PowerShell module.',
             N'ATAPUtilities.SourceModule', N'SourceRootRelativePath', @SecretsPowerShellPhiloteId, NULL, N'Relative'),
        (9,  'bcfe7081-0cbb-4111-a765-a6096019489d', 'f2ad3d59-18b8-4c44-80d5-1abf36efe6cb',
             N'Instantiation.SourceModule.ATAP.Utilities.Secrets.PowerShell.Manifest',
             N'Repository-relative module manifest path of the planned ATAP.Utilities.Secrets.PowerShell module.',
             N'ATAPUtilities.SourceModule', N'ManifestRelativePath', @SecretsPowerShellPhiloteId, NULL, N'Relative'),
        (10, '72d2927e-8357-4584-8e47-9f7cc5f40bd1', 'a82eab0b-4e96-4b44-aba6-9332cc336a2f',
             N'Instantiation.SourceModule.ATAP.Utilities.Secrets.PowerShell.PublicFunctions',
             N'Repository-relative public functions folder of the planned ATAP.Utilities.Secrets.PowerShell module.',
             N'ATAPUtilities.SourceModule', N'PublicFunctionsRelativePath', @SecretsPowerShellPhiloteId, NULL, N'Relative'),
        (11, 'e08aee28-42e2-4bb8-8c73-ae2f990c0e69', 'c3db72ff-1950-4d43-a36d-5909134a692b',
             N'Instantiation.SourceModule.ATAP.Utilities.Secrets.PowerShell.PrivateFunctions',
             N'Repository-relative private functions folder of the planned ATAP.Utilities.Secrets.PowerShell module.',
             N'ATAPUtilities.SourceModule', N'PrivateFunctionsRelativePath', @SecretsPowerShellPhiloteId, NULL, N'Relative'),
        (12, '27127d67-5685-4716-8fbd-a53f2f00149b', 'a132213d-8df4-4df8-9eb7-b24166bc4ccd',
             N'Instantiation.SourceModuleOverride.ATAP.Utilities.Security.PowerShell.SourceRoot',
             N'Planned corrected (PowerShell casing) source root recorded by Sprint 0012 instantiation v2 for the Security module.',
             N'ATAPUtilities.InstantiationVersionSourceModule', N'SourceRootRelativePathOverride',
             @SecurityModulePhiloteId, @Version2PhiloteId, N'Relative');

    -- ---- copy the actual stored values (never re-typed literals) ----
    UPDATE p
       SET p.PathValue = r.StableRootPath
      FROM @Plan AS p
      INNER JOIN ATAPUtilities.Repository AS r ON r.RepositoryPhiloteId = p.SourceRowPhiloteId
     WHERE p.SourceTableName = N'ATAPUtilities.Repository'
       AND p.SourceColumnName = N'StableRootPath';

    UPDATE p
       SET p.PathValue = r.SprintRootPath
      FROM @Plan AS p
      INNER JOIN ATAPUtilities.Repository AS r ON r.RepositoryPhiloteId = p.SourceRowPhiloteId
     WHERE p.SourceTableName = N'ATAPUtilities.Repository'
       AND p.SourceColumnName = N'SprintRootPath';

    UPDATE p
       SET p.PathValue = sm.SourceRootRelativePath
      FROM @Plan AS p
      INNER JOIN ATAPUtilities.SourceModule AS sm ON sm.SourceModulePhiloteId = p.SourceRowPhiloteId
     WHERE p.SourceTableName = N'ATAPUtilities.SourceModule'
       AND p.SourceColumnName = N'SourceRootRelativePath';

    UPDATE p
       SET p.PathValue = sm.ManifestRelativePath
      FROM @Plan AS p
      INNER JOIN ATAPUtilities.SourceModule AS sm ON sm.SourceModulePhiloteId = p.SourceRowPhiloteId
     WHERE p.SourceTableName = N'ATAPUtilities.SourceModule'
       AND p.SourceColumnName = N'ManifestRelativePath';

    UPDATE p
       SET p.PathValue = sm.PublicFunctionsRelativePath
      FROM @Plan AS p
      INNER JOIN ATAPUtilities.SourceModule AS sm ON sm.SourceModulePhiloteId = p.SourceRowPhiloteId
     WHERE p.SourceTableName = N'ATAPUtilities.SourceModule'
       AND p.SourceColumnName = N'PublicFunctionsRelativePath';

    UPDATE p
       SET p.PathValue = sm.PrivateFunctionsRelativePath
      FROM @Plan AS p
      INNER JOIN ATAPUtilities.SourceModule AS sm ON sm.SourceModulePhiloteId = p.SourceRowPhiloteId
     WHERE p.SourceTableName = N'ATAPUtilities.SourceModule'
       AND p.SourceColumnName = N'PrivateFunctionsRelativePath';

    -- The v2 rearrange override lives on a typed membership row that
    -- section 6 deletes. It MUST be copied before that delete.
    UPDATE p
       SET p.PathValue = ivsm.SourceRootRelativePathOverride
      FROM @Plan AS p
      INNER JOIN ATAPUtilities.InstantiationVersionSourceModule AS ivsm
              ON ivsm.SourceModulePhiloteId = p.SourceRowPhiloteId
             AND ivsm.InstantiationVersionPhiloteId = p.SourceVersionPhiloteId
     WHERE p.SourceTableName = N'ATAPUtilities.InstantiationVersionSourceModule'
       AND p.SourceColumnName = N'SourceRootRelativePathOverride';

    -- ---- re-run detection and under-migration tripwire ----
    DECLARE @DeclaredExpectedCount INT = 12;

    DECLARE @AlreadyMigrated BIT =
        CASE WHEN EXISTS (
            SELECT 1
            FROM ATAPUtilities.RuleInstantiation AS ri
            INNER JOIN @Plan AS p ON p.RuleInstantiationPhiloteId = ri.PhiloteId
        ) THEN 1 ELSE 0 END;

    DECLARE @ResolvedCount INT = (SELECT COUNT(*) FROM @Plan WHERE PathValue IS NOT NULL);

    IF @AlreadyMigrated = 0 AND @ResolvedCount <> @DeclaredExpectedCount
    BEGIN
        SET @ErrorMessage = N'V00.02.000080: expected to resolve ' + CAST(@DeclaredExpectedCount AS NVARCHAR(10))
            + N' source values but resolved ' + CAST(@ResolvedCount AS NVARCHAR(10))
            + N'. Refusing to run a partial or silent no-op migration.';
        THROW 50083, @ErrorMessage, 1;
    END;

    -- An absolute path must actually start with a drive specifier, otherwise
    -- the Drive/PathTail decomposition below would silently produce garbage
    -- (for example a UNC path yielding Drive = '\\').
    IF EXISTS (
        SELECT 1 FROM @Plan
        WHERE PathValue IS NOT NULL
          AND PathType = N'Absolute'
          AND SUBSTRING(PathValue, 2, 2) <> N':\'
    )
    BEGIN
        SET @ErrorMessage = N'V00.02.000080: a value classified as an Absolute path does not begin with a drive specifier. '
            + N'Drive/PathTail decomposition would be wrong; aborting.';
        THROW 50084, @ErrorMessage, 1;
    END;

    -- A rule name collision under a different PhiloteId would break the
    -- UQ_Rule_Language_Name unique constraint with an opaque error.
    IF EXISTS (
        SELECT 1
        FROM ATAPUtilities.[Rule] AS r
        INNER JOIN @Plan AS p ON p.RuleName = r.[Name]
        WHERE r.PrimitiveLanguageKindId = @PathKindId
          AND r.PhiloteId <> p.RulePhiloteId
    )
    BEGIN
        SET @ErrorMessage = N'V00.02.000080: a Path rule with one of the migration rule names already exists under a '
            + N'different PhiloteId. Resolve the name collision before running this migration.';
        THROW 50085, @ErrorMessage, 1;
    END;

    -- =================================================================
    -- 3. Copy into the durable RRSBS input model
    -- =================================================================
    INSERT INTO ATAPUtilities.Philote (PhiloteId)
    SELECT g.PhiloteId
    FROM (
        SELECT RulePhiloteId AS PhiloteId FROM @Plan WHERE PathValue IS NOT NULL
        UNION
        SELECT RuleInstantiationPhiloteId FROM @Plan WHERE PathValue IS NOT NULL
    ) AS g
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.Philote AS existing WHERE existing.PhiloteId = g.PhiloteId
    );

    INSERT INTO ATAPUtilities.[Rule] (PhiloteId, PrimitiveLanguageKindId, [Name], Purpose, SourceFileReference)
    SELECT p.RulePhiloteId,
           @PathKindId,
           p.RuleName,
           p.RulePurpose,
           N'Database/ATAPUtilities/db/migrations/V00.02.000080__Migrate_TypedMembership_To_RRSBS_And_Retire_Samples.sql'
    FROM @Plan AS p
    WHERE p.PathValue IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ATAPUtilities.[Rule] AS existing WHERE existing.PhiloteId = p.RulePhiloteId
      );

    INSERT INTO ATAPUtilities.RuleInstantiation (PhiloteId, RulePhiloteId, Notes)
    SELECT p.RuleInstantiationPhiloteId,
           p.RulePhiloteId,
           N'Migrated by V00.02.000080 from ' + p.SourceTableName + N'.' + p.SourceColumnName + N'.'
    FROM @Plan AS p
    WHERE p.PathValue IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ATAPUtilities.RuleInstantiation AS existing
          WHERE existing.PhiloteId = p.RuleInstantiationPhiloteId
      );

    -- V00.02.000070 adds the nullable owning-Instantiation column to the
    -- durable RuleInstantiation table. Anchor every migrated rule instance to
    -- the durable 'ATAP Utilities Sprint 0012' Instantiation so the copied
    -- inputs live under the durable Instantiation -> RuleInstantiation ->
    -- RuleInstantiationBinding contract described by 13.77.g. Guarded so this
    -- migration still applies if that column is absent.
    DECLARE @DurableInstantiationPhiloteId UNIQUEIDENTIFIER = '4d8e6686-9772-4bcb-92ce-e49f0476196a';

    IF COL_LENGTH(N'ATAPUtilities.RuleInstantiation', N'InstantiationPhiloteId') IS NOT NULL
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM ATAPUtilities.Instantiation
            WHERE InstantiationPhiloteId = @DurableInstantiationPhiloteId
        )
        BEGIN
            SET @ErrorMessage = N'V00.02.000080: durable Instantiation 4d8e6686-9772-4bcb-92ce-e49f0476196a '
                + N'(ATAP Utilities Sprint 0012) is missing; migrated rule instances would have no owner.';
            THROW 50094, @ErrorMessage, 1;
        END;

        -- Dynamic because a static reference to InstantiationPhiloteId would
        -- fail to compile on a database where V00.02.000070 has not added it.
        -- The IN-list is built from UNIQUEIDENTIFIER values, so it cannot
        -- carry injected text.
        DECLARE @RuleInstantiationKeyList NVARCHAR(MAX) = (
            SELECT STRING_AGG(CAST(N'''' + CAST(RuleInstantiationPhiloteId AS NVARCHAR(36)) + N'''' AS NVARCHAR(MAX)), N',')
            FROM @Plan
            WHERE PathValue IS NOT NULL
        );

        IF @RuleInstantiationKeyList IS NOT NULL
        BEGIN
            DECLARE @OwnerUpdateSql NVARCHAR(MAX) =
                N'UPDATE ATAPUtilities.RuleInstantiation
                     SET InstantiationPhiloteId = @Owner
                   WHERE InstantiationPhiloteId IS NULL
                     AND PhiloteId IN (' + @RuleInstantiationKeyList + N');';

            EXEC sp_executesql @OwnerUpdateSql,
                 N'@Owner UNIQUEIDENTIFIER',
                 @Owner = @DurableInstantiationPhiloteId;
        END;
    END;

    INSERT INTO ATAPUtilities.RuleInstantiationBinding (InstantiationPhiloteId, InputName, InputValue)
    SELECT b.InstantiationPhiloteId, b.InputName, b.InputValue
    FROM (
        SELECT p.RuleInstantiationPhiloteId AS InstantiationPhiloteId,
               N'PathType' AS InputName,
               CAST(p.PathType AS NVARCHAR(MAX)) AS InputValue
        FROM @Plan AS p WHERE p.PathValue IS NOT NULL
        UNION ALL
        SELECT p.RuleInstantiationPhiloteId,
               N'FullPath',
               CAST(p.PathValue AS NVARCHAR(MAX))
        FROM @Plan AS p WHERE p.PathValue IS NOT NULL
        UNION ALL
        SELECT p.RuleInstantiationPhiloteId,
               N'PathTail',
               CAST(CASE WHEN p.PathType = N'Absolute'
                         THEN SUBSTRING(p.PathValue, 4, LEN(p.PathValue))
                         ELSE p.PathValue
                    END AS NVARCHAR(MAX))
        FROM @Plan AS p WHERE p.PathValue IS NOT NULL
        UNION ALL
        SELECT p.RuleInstantiationPhiloteId,
               N'Drive',
               CAST(LEFT(p.PathValue, 2) AS NVARCHAR(MAX))
        FROM @Plan AS p WHERE p.PathValue IS NOT NULL AND p.PathType = N'Absolute'
    ) AS b
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleInstantiationBinding AS existing
        WHERE existing.InstantiationPhiloteId = b.InstantiationPhiloteId
          AND existing.InputName = b.InputName
    );

    -- =================================================================
    -- 4. Verify the copy (in-transaction; any failure rolls everything back)
    -- =================================================================
    DECLARE @ExpectedInstantiations INT = (SELECT COUNT(*) FROM @Plan WHERE PathValue IS NOT NULL);

    DECLARE @ActualInstantiations INT = (
        SELECT COUNT(*)
        FROM @Plan AS p
        INNER JOIN ATAPUtilities.RuleInstantiation AS ri
                ON ri.PhiloteId = p.RuleInstantiationPhiloteId
               AND ri.RulePhiloteId = p.RulePhiloteId
        WHERE p.PathValue IS NOT NULL
    );

    IF @ActualInstantiations <> @ExpectedInstantiations
    BEGIN
        SET @ErrorMessage = N'V00.02.000080: RuleInstantiation copy incomplete. Expected '
            + CAST(@ExpectedInstantiations AS NVARCHAR(10)) + N', found '
            + CAST(@ActualInstantiations AS NVARCHAR(10)) + N'.';
        THROW 50086, @ErrorMessage, 1;
    END;

    DECLARE @ExpectedBindings INT = (
        SELECT SUM(CASE WHEN PathType = N'Absolute' THEN 4 ELSE 3 END)
        FROM @Plan WHERE PathValue IS NOT NULL
    );

    DECLARE @ActualBindings INT = (
        SELECT COUNT(*)
        FROM ATAPUtilities.RuleInstantiationBinding AS rib
        INNER JOIN @Plan AS p ON p.RuleInstantiationPhiloteId = rib.InstantiationPhiloteId
        WHERE p.PathValue IS NOT NULL
    );

    IF @ActualBindings <> @ExpectedBindings
    BEGIN
        SET @ErrorMessage = N'V00.02.000080: RuleInstantiationBinding copy incomplete. Expected '
            + CAST(@ExpectedBindings AS NVARCHAR(10)) + N', found '
            + CAST(@ActualBindings AS NVARCHAR(10)) + N'.';
        THROW 50087, @ErrorMessage, 1;
    END;

    -- Value identity, compared with a binary collation. The whole point of
    -- plan row 12 is a casing-only correction (Powershell -> PowerShell), so a
    -- case-insensitive comparison would pass on a wrong value.
    DECLARE @ValueMismatches INT = (
        SELECT COUNT(*)
        FROM @Plan AS p
        WHERE p.PathValue IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM ATAPUtilities.RuleInstantiationBinding AS rib
              WHERE rib.InstantiationPhiloteId = p.RuleInstantiationPhiloteId
                AND rib.InputName = N'FullPath'
                AND rib.InputValue COLLATE Latin1_General_BIN2 = p.PathValue COLLATE Latin1_General_BIN2
          )
    );

    IF @ValueMismatches <> 0
    BEGIN
        SET @ErrorMessage = N'V00.02.000080: ' + CAST(@ValueMismatches AS NVARCHAR(10))
            + N' migrated value(s) do not match their source exactly (binary comparison).';
        THROW 50088, @ErrorMessage, 1;
    END;

    -- Every migrated rule instance must be anchored to the durable
    -- Instantiation when V00.02.000070 has provided the column.
    IF COL_LENGTH(N'ATAPUtilities.RuleInstantiation', N'InstantiationPhiloteId') IS NOT NULL
       AND @RuleInstantiationKeyList IS NOT NULL
    BEGIN
        DECLARE @AnchoredCount INT;
        DECLARE @AnchorCheckSql NVARCHAR(MAX) =
            N'SELECT @CountOut = COUNT(*)
                FROM ATAPUtilities.RuleInstantiation
               WHERE InstantiationPhiloteId = @Owner
                 AND PhiloteId IN (' + @RuleInstantiationKeyList + N');';

        EXEC sp_executesql @AnchorCheckSql,
             N'@Owner UNIQUEIDENTIFIER, @CountOut INT OUTPUT',
             @Owner = @DurableInstantiationPhiloteId,
             @CountOut = @AnchoredCount OUTPUT;

        IF @AnchoredCount <> @ExpectedInstantiations
        BEGIN
            SET @ErrorMessage = N'V00.02.000080: only ' + CAST(@AnchoredCount AS NVARCHAR(10)) + N' of '
                + CAST(@ExpectedInstantiations AS NVARCHAR(10))
                + N' migrated rule instances are anchored to the durable Instantiation.';
            THROW 50095, @ErrorMessage, 1;
        END;
    END;

    -- =================================================================
    -- 5. Deprecate the typed membership structures (mark, never DROP)
    -- =================================================================
    DECLARE @DeprecationNote NVARCHAR(1000) =
        N'DEPRECATED by V00.02.000080 (Sprint 0013 Task 13.78.h). Not part of the supported surface. '
      + N'Useful path values were copied into the durable RRSBS input model '
      + N'(ATAPUtilities.[Rule] / RuleInstantiation / RuleInstantiationBinding). '
      + N'New membership must be recorded through '
      + N'ATAPUtilities.InstantiationVersionRuleInstantiationVersion, and the owning build set '
      + N'through the single-valued ATAPUtilities.InstantiationVersion.BuildSetVersionPhiloteId column. '
      + N'Retained read-only so existing consumers keep working; do not add new readers or writers.';

    DECLARE @DeprecatedTables TABLE (TableName SYSNAME NOT NULL PRIMARY KEY);
    INSERT INTO @DeprecatedTables (TableName)
    VALUES (N'InstantiationVersionComputer'),
           (N'InstantiationVersionRepository'),
           (N'InstantiationVersionSourceModule');

    DECLARE @DeprecatedTableName SYSNAME;
    DECLARE DeprecationCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT TableName FROM @DeprecatedTables ORDER BY TableName;

    OPEN DeprecationCursor;
    FETCH NEXT FROM DeprecationCursor INTO @DeprecatedTableName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF EXISTS (
            SELECT 1 FROM sys.extended_properties
            WHERE major_id = OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(@DeprecatedTableName))
              AND minor_id = 0
              AND [name] = N'ATAP_Deprecated'
        )
        BEGIN
            EXEC sys.sp_updateextendedproperty
                 @name       = N'ATAP_Deprecated',
                 @value      = @DeprecationNote,
                 @level0type = N'SCHEMA', @level0name = N'ATAPUtilities',
                 @level1type = N'TABLE',  @level1name = @DeprecatedTableName;
        END
        ELSE
        BEGIN
            EXEC sys.sp_addextendedproperty
                 @name       = N'ATAP_Deprecated',
                 @value      = @DeprecationNote,
                 @level0type = N'SCHEMA', @level0name = N'ATAPUtilities',
                 @level1type = N'TABLE',  @level1name = @DeprecatedTableName;
        END;

        FETCH NEXT FROM DeprecationCursor INTO @DeprecatedTableName;
    END;

    CLOSE DeprecationCursor;
    DEALLOCATE DeprecationCursor;

    DECLARE @DeprecationMarkerCount INT = (
        SELECT COUNT(*)
        FROM sys.extended_properties AS ep
        INNER JOIN @DeprecatedTables AS d
                ON ep.major_id = OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(d.TableName))
        WHERE ep.minor_id = 0 AND ep.[name] = N'ATAP_Deprecated'
    );

    IF @DeprecationMarkerCount <> 3
    BEGIN
        SET @ErrorMessage = N'V00.02.000080: expected 3 deprecation markers, found '
            + CAST(@DeprecationMarkerCount AS NVARCHAR(10)) + N'.';
        THROW 50089, @ErrorMessage, 1;
    END;

    -- =================================================================
    -- 6. Task 13.78.i - prove no retained row depends on the Sprint 0012
    --    v1/v2 sample rows, then remove them by exact GUID literal
    -- =================================================================
    DECLARE @SampleVersions TABLE (InstantiationVersionPhiloteId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY);
    INSERT INTO @SampleVersions (InstantiationVersionPhiloteId)
    VALUES (@Version1PhiloteId), (@Version2PhiloteId);

    DECLARE @SamplesPresent BIT =
        CASE WHEN EXISTS (
            SELECT 1
            FROM ATAPUtilities.InstantiationVersion AS iv
            INNER JOIN @SampleVersions AS s ON s.InstantiationVersionPhiloteId = iv.InstantiationVersionPhiloteId
        ) THEN 1 ELSE 0 END;

    -- 6a. The dependency proof is only valid if it covers every FK that can
    --     reference InstantiationVersion. Fail closed on an unknown one.
    DECLARE @UnknownReferencingTables NVARCHAR(MAX) = (
        SELECT STRING_AGG(CAST(SCHEMA_NAME(pt.schema_id) + N'.' + pt.[name] AS NVARCHAR(MAX)), N', ')
        FROM sys.foreign_keys AS fk
        INNER JOIN sys.tables AS pt ON pt.object_id = fk.parent_object_id
        WHERE fk.referenced_object_id = OBJECT_ID(N'ATAPUtilities.InstantiationVersion')
          AND pt.[name] NOT IN (
              N'InstantiationVersion',
              N'InstantiationVersionComputer',
              N'InstantiationVersionRepository',
              N'InstantiationVersionSourceModule',
              N'ManifestationArtifact',
              N'InstantiationVersionRuleInstantiationVersion'
          )
    );

    IF @UnknownReferencingTables IS NOT NULL
    BEGIN
        SET @ErrorMessage = N'V00.02.000080: unenumerated foreign key(s) reference ATAPUtilities.InstantiationVersion ('
            + @UnknownReferencingTables + N'). The dependency proof is incomplete; aborting sample-row removal.';
        THROW 50090, @ErrorMessage, 1;
    END;

    -- 6b. Retained-dependent proof across every referencing surface.
    --
    -- V00.02.000070 binds an InstantiationVersion to its BuildSetVersion
    -- through the single-valued nullable column
    -- InstantiationVersion.BuildSetVersionPhiloteId, NOT through a junction
    -- table. That column lives ON the rows being deleted, so it creates no
    -- inbound dependency and needs no check here.
    --
    -- InstantiationVersionRuleInstantiationVersion carries the
    -- TR_IVRIV_Immutable AFTER UPDATE, DELETE trigger from V00.02.000070.
    -- A retained row there could not be deleted even if we wanted to, so
    -- refusing to proceed is the only correct behaviour.
    DECLARE @RetainedDependents INT = 0;

    IF OBJECT_ID(N'ATAPUtilities.InstantiationVersionRuleInstantiationVersion', N'U') IS NOT NULL
        SET @RetainedDependents += (
            SELECT COUNT(*)
            FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion AS x
            INNER JOIN @SampleVersions AS s ON s.InstantiationVersionPhiloteId = x.InstantiationVersionPhiloteId
        );

    -- Retained InstantiationVersion rows parented on a sample version.
    SET @RetainedDependents += (
        SELECT COUNT(*)
        FROM ATAPUtilities.InstantiationVersion AS iv
        WHERE iv.ParentInstantiationVersionPhiloteId IN (SELECT InstantiationVersionPhiloteId FROM @SampleVersions)
          AND iv.InstantiationVersionPhiloteId NOT IN (SELECT InstantiationVersionPhiloteId FROM @SampleVersions)
    );

    -- Soft reference: ManifestationArtifact.SourceObjectPhiloteId is not FK
    -- enforced, so a retained artifact could still point at a sample version.
    SET @RetainedDependents += (
        SELECT COUNT(*)
        FROM ATAPUtilities.ManifestationArtifact AS ma
        WHERE ma.SourceObjectPhiloteId IN (SELECT InstantiationVersionPhiloteId FROM @SampleVersions)
          AND ma.InstantiationVersionPhiloteId NOT IN (SELECT InstantiationVersionPhiloteId FROM @SampleVersions)
    );

    -- Typed membership rows belonging to a NON-sample version are retained and
    -- are not touched by the deletes below, so they need no check here: the
    -- deletes are keyed to the two sample version GUIDs only.

    IF @RetainedDependents <> 0
    BEGIN
        SET @ErrorMessage = N'V00.02.000080: ' + CAST(@RetainedDependents AS NVARCHAR(10))
            + N' retained row(s) depend on the Sprint 0012 v1/v2 sample InstantiationVersion rows. '
            + N'Refusing to remove them.';
        THROW 50091, @ErrorMessage, 1;
    END;

    -- 6c. FK-safe removal by exact GUID literal (children first).
    --
    -- Immutability triggers: V00.02.000070 installs eight AFTER UPDATE, DELETE
    -- triggers that THROW 50071. They cover RuleVersion,
    -- RuleVersionPrimitiveComposition, RuleSetVersion, RuleSetVersionMember,
    -- BuildSetVersion, BuildSetVersionMember, RuleInstantiationVersion, and
    -- InstantiationVersionRuleInstantiationVersion. NONE of the five tables
    -- deleted below is on that list, and TR_ManifestationArtifact_Provenance
    -- is AFTER INSERT, UPDATE only. No trigger is disabled by this migration.
    DECLARE @DeletedManifestationArtifact INT = 0;
    DECLARE @DeletedSourceModuleMembers   INT = 0;
    DECLARE @DeletedRepositoryMembers     INT = 0;
    DECLARE @DeletedComputerMembers       INT = 0;
    DECLARE @DeletedVersions              INT = 0;

    DELETE ma
      FROM ATAPUtilities.ManifestationArtifact AS ma
     INNER JOIN @SampleVersions AS s ON s.InstantiationVersionPhiloteId = ma.InstantiationVersionPhiloteId;
    SET @DeletedManifestationArtifact = @@ROWCOUNT;

    DELETE x
      FROM ATAPUtilities.InstantiationVersionSourceModule AS x
     INNER JOIN @SampleVersions AS s ON s.InstantiationVersionPhiloteId = x.InstantiationVersionPhiloteId;
    SET @DeletedSourceModuleMembers = @@ROWCOUNT;

    DELETE x
      FROM ATAPUtilities.InstantiationVersionRepository AS x
     INNER JOIN @SampleVersions AS s ON s.InstantiationVersionPhiloteId = x.InstantiationVersionPhiloteId;
    SET @DeletedRepositoryMembers = @@ROWCOUNT;

    DELETE x
      FROM ATAPUtilities.InstantiationVersionComputer AS x
     INNER JOIN @SampleVersions AS s ON s.InstantiationVersionPhiloteId = x.InstantiationVersionPhiloteId;
    SET @DeletedComputerMembers = @@ROWCOUNT;

    -- v2 is the child of v1 through ParentInstantiationVersionPhiloteId.
    DELETE FROM ATAPUtilities.InstantiationVersion
     WHERE InstantiationVersionPhiloteId = @Version2PhiloteId;
    SET @DeletedVersions = @@ROWCOUNT;

    DELETE FROM ATAPUtilities.InstantiationVersion
     WHERE InstantiationVersionPhiloteId = @Version1PhiloteId;
    SET @DeletedVersions += @@ROWCOUNT;

    -- 6d. Post-removal verification.
    IF @SamplesPresent = 1
       AND (@DeletedManifestationArtifact <> 7
            OR @DeletedSourceModuleMembers <> 5
            OR @DeletedRepositoryMembers <> 2
            OR @DeletedComputerMembers <> 4
            OR @DeletedVersions <> 2)
    BEGIN
        SET @ErrorMessage = N'V00.02.000080: sample-row removal did not match the V00.02.000060 seed shape '
            + N'(ManifestationArtifact=' + CAST(@DeletedManifestationArtifact AS NVARCHAR(10))
            + N'/7, InstantiationVersionSourceModule=' + CAST(@DeletedSourceModuleMembers AS NVARCHAR(10))
            + N'/5, InstantiationVersionRepository=' + CAST(@DeletedRepositoryMembers AS NVARCHAR(10))
            + N'/2, InstantiationVersionComputer=' + CAST(@DeletedComputerMembers AS NVARCHAR(10))
            + N'/4, InstantiationVersion=' + CAST(@DeletedVersions AS NVARCHAR(10))
            + N'/2). The data drifted from the seed; a human must review before removal.';
        THROW 50092, @ErrorMessage, 1;
    END;

    DECLARE @RemainingSampleRows INT =
        (SELECT COUNT(*) FROM ATAPUtilities.InstantiationVersion AS iv
          INNER JOIN @SampleVersions AS s ON s.InstantiationVersionPhiloteId = iv.InstantiationVersionPhiloteId)
      + (SELECT COUNT(*) FROM ATAPUtilities.InstantiationVersionComputer AS x
          INNER JOIN @SampleVersions AS s ON s.InstantiationVersionPhiloteId = x.InstantiationVersionPhiloteId)
      + (SELECT COUNT(*) FROM ATAPUtilities.InstantiationVersionRepository AS x
          INNER JOIN @SampleVersions AS s ON s.InstantiationVersionPhiloteId = x.InstantiationVersionPhiloteId)
      + (SELECT COUNT(*) FROM ATAPUtilities.InstantiationVersionSourceModule AS x
          INNER JOIN @SampleVersions AS s ON s.InstantiationVersionPhiloteId = x.InstantiationVersionPhiloteId)
      + (SELECT COUNT(*) FROM ATAPUtilities.ManifestationArtifact AS ma
          INNER JOIN @SampleVersions AS s ON s.InstantiationVersionPhiloteId = ma.InstantiationVersionPhiloteId);

    IF @RemainingSampleRows <> 0
    BEGIN
        SET @ErrorMessage = N'V00.02.000080: ' + CAST(@RemainingSampleRows AS NVARCHAR(10))
            + N' Sprint 0012 sample row(s) remain after removal.';
        THROW 50093, @ErrorMessage, 1;
    END;

    -- Philote anchor rows for the removed sample rows are intentionally
    -- retained. Philote is the identity anchor of the system and removing
    -- anchors is out of scope for this migration.

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

PRINT N'V00.02.000080 - typed membership path values migrated into RRSBS inputs, typed membership tables deprecated, Sprint 0012 v1/v2 sample rows removed.';

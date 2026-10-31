/*
  Immutable exact-catalog successor of the accepted Login127 fixture.
  Source only; execution requires separate authorization on a disposable copy.
  The runner binds ATAP.AceCommander.Fixture.ExpectedCatalog read-only on one
  fresh dedicated verifier session. Run this file parameterless before and after
  V00160 on that same session; do not wrap its temp-table captures in an RPC.
  Only header/catalog guard differ from the historical fixture. All preservation,
  history and credential-free Guest assertions remain unchanged.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @FixtureCatalogValue sql_variant = SESSION_CONTEXT(N'ATAP.AceCommander.Fixture.ExpectedCatalog');
IF @FixtureCatalogValue IS NULL
   OR ISNULL(CONVERT(nvarchar(128), SQL_VARIANT_PROPERTY(@FixtureCatalogValue, 'BaseType')), N'') <> N'nvarchar'
    THROW 61700, N'An explicit nvarchar fixture catalog binding is required.', 1;
DECLARE @FixtureExpectedCatalog nvarchar(4000) = CONVERT(nvarchar(4000), @FixtureCatalogValue);
IF DB_NAME() IS NULL OR DATALENGTH(@FixtureExpectedCatalog) = 0
   OR DB_NAME() COLLATE Latin1_General_100_BIN2 <> @FixtureExpectedCatalog COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(DB_NAME()) <> DATALENGTH(@FixtureExpectedCatalog)
    THROW 61700, N'The verifier requires its exact bound disposable catalog.', 1;
IF SCHEMA_ID(N'ACE') IS NULL
    THROW 61718, N'Fixture requires the existing ACE schema in ATAPUtilities.', 1;
IF ISNULL(HAS_PERMS_BY_NAME(DB_NAME(), N'DATABASE', N'VIEW DEFINITION'), 0) <> 1
    THROW 61701, N'Fixture requires visible metadata.', 1;
IF OBJECT_ID(N'[dbo].[flyway_schema_history]', N'U') IS NULL
    THROW 61702, N'Explicit predecessor history binding is missing.', 1;

IF OBJECT_ID(N'tempdb..#Login127_BeforeObjects') IS NULL
BEGIN
    DECLARE @FixtureExpectedHistory TABLE
    (
        [Version] nvarchar(50) NOT NULL,
        [Script] nvarchar(1000) NOT NULL,
        [Checksum] int NOT NULL
    );
    INSERT INTO @FixtureExpectedHistory ([Version], [Script], [Checksum])
    VALUES
        (N'00010', N'V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql', 1708932941),
        (N'00030', N'V00030__Create_AceOutpostContentSummaryPrototype.sql', -2126084359),
        (N'00040', N'V00040__Add_PhiloteValidityPeriod_SameIdentity_Key.sql', 1681687671),
        (N'00050', N'V00050__Create_ATAPUtilities_Tag_Root.sql', -467224854),
        (N'00060', N'V00060__Create_Ace_GatherContent_Submission.sql', -1137084994),
        (N'00070', N'V00070__Create_Ace_AISupervisor_Telemetry.sql', -1143966941),
        (N'00080', N'V00080__Create_ATAPUtilities_V4_Core_Identity_And_Overlay.sql', -1623112334),
        (N'00090', N'V00090__Create_ATAPUtilities_Tag_Relations_Assignments_And_Rules.sql', -1553929770),
        (N'00100', N'V00100__Create_ATAPUtilities_ContentSummary_And_Query.sql', -1424720516),
        (N'00110', N'V00110__Create_ContentSummary_DAB_Principal_Facade.sql', 351768227),
        (N'00120', N'V00120__Add_ContentSummary_Provisioning_And_Correction.sql', -685970708),
        (N'00130', N'V00130__Create_ContentSummary_Runtime_Query_Boundary.sql', 2009181215),
        (N'00140', N'V00140__Correct_ContentSummary_Runtime_Query_Denials.sql', -1589047792),
        (N'00150', N'V00150__Add_AISupervisor_CacheTokens.sql', 910403273);
    IF EXISTS
    (
        SELECT 1 FROM @FixtureExpectedHistory AS e
        WHERE (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history] AS h
               WHERE h.[version] = e.[Version] AND h.[script] = e.[Script]
                 AND h.[checksum] = e.[Checksum] AND h.[success] = 1) <> 1
    )
        THROW 61716, N'Before-state predecessor identities or checksums differ.', 1;

    IF OBJECT_ID(N'[ACE].[User]') IS NOT NULL
       OR OBJECT_ID(N'[ACE].[UserInformation]') IS NOT NULL
       OR OBJECT_ID(N'[ACE].[UserSettings]') IS NOT NULL
       OR OBJECT_ID(N'[ACE].[UserPreferences]') IS NOT NULL
        THROW 61703, N'Before-state must have no login targets; conflicts are refusal cases.', 1;
    IF (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history]) <> 14
       OR EXISTS (SELECT 1 FROM [dbo].[flyway_schema_history] WHERE [success] <> 1)
        THROW 61704, N'Before-state must have fourteen successful predecessors.', 1;
    IF OBJECT_ID(N'[ATAPUtilities].[Philote]', N'U') IS NULL
        THROW 61705, N'Retained shared Philote is missing.', 1;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Philote]
               WHERE [PhiloteId] = '3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b')
        THROW 61719, N'Existing shared Guest parent requires disposition.', 1;
    IF EXISTS (SELECT 1 FROM sys.sql_modules WHERE [definition] IS NULL)
        THROW 61706, N'Hidden or encrypted module prevents definition comparison.', 1;

    SELECT o.object_id, o.schema_id, o.[name], o.[type],
           HASHBYTES('SHA2_256', CONVERT(varbinary(max), OBJECT_DEFINITION(o.object_id))) AS DefinitionHash
    INTO #Login127_BeforeObjects
    FROM sys.objects AS o
    WHERE o.is_ms_shipped = 0;

    SELECT c.object_id, c.column_id, c.[name], c.user_type_id,
           c.max_length, c.[precision], c.scale, c.is_nullable,
           c.is_identity, c.is_computed, c.collation_name, c.default_object_id
    INTO #Login127_BeforeColumns
    FROM sys.columns AS c
    JOIN sys.tables AS t ON t.object_id = c.object_id
    WHERE t.is_ms_shipped = 0;

    SELECT [PhiloteId], DATALENGTH([AdditionalIdsStub]) AS StubBytes,
           HASHBYTES('SHA2_256', CONVERT(varbinary(max), [AdditionalIdsStub])) AS StubHash
    INTO #Login127_BeforeSharedRows
    FROM [ATAPUtilities].[Philote];

    SELECT [installed_rank], [version], [script], [checksum], [success]
    INTO #Login127_BeforeHistory
    FROM [dbo].[flyway_schema_history];

    SELECT N'BeforeCaptured' AS FixturePhase;
    RETURN;
END;

-- Every original object keeps its identity/name/type and exact definition hash.
IF EXISTS
(
    SELECT 1 FROM #Login127_BeforeObjects AS b
    LEFT JOIN sys.objects AS o ON o.object_id = b.object_id
    WHERE o.object_id IS NULL OR o.schema_id <> b.schema_id OR o.[name] <> b.[name] OR o.[type] <> b.[type]
       OR ISNULL(HASHBYTES('SHA2_256', CONVERT(varbinary(max), OBJECT_DEFINITION(o.object_id))), 0x)
          <> ISNULL(b.DefinitionHash, 0x)
)
    THROW 61707, N'A retained non-user object or definition changed.', 1;

IF EXISTS
(
    SELECT * FROM #Login127_BeforeColumns
    EXCEPT
    SELECT c.object_id, c.column_id, c.[name], c.user_type_id,
           c.max_length, c.[precision], c.scale, c.is_nullable,
           c.is_identity, c.is_computed, c.collation_name, c.default_object_id
    FROM sys.columns AS c
    WHERE c.object_id IN (SELECT DISTINCT object_id FROM #Login127_BeforeColumns)
)
OR EXISTS
(
    SELECT c.object_id, c.column_id, c.[name], c.user_type_id,
           c.max_length, c.[precision], c.scale, c.is_nullable,
           c.is_identity, c.is_computed, c.collation_name, c.default_object_id
    FROM sys.columns AS c
    WHERE c.object_id IN (SELECT DISTINCT object_id FROM #Login127_BeforeColumns)
    EXCEPT SELECT * FROM #Login127_BeforeColumns
)
    THROW 61708, N'A retained table column contract changed.', 1;

IF EXISTS
(
    SELECT * FROM #Login127_BeforeHistory
    EXCEPT
    SELECT [installed_rank], [version], [script], [checksum], [success]
    FROM [dbo].[flyway_schema_history]
)
OR (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history]) <> 15
OR (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history]
    WHERE [version] = N'00160'
      AND [script] = N'V00160__Create_AceCommander_Login_Schema_And_Guest.sql'
      AND [checksum] IS NOT NULL AND [success] = 1) <> 1
    THROW 61709, N'Predecessor rows changed or successful V00160 record is missing.', 1;

-- Preserve every original shared-registry row and permit only the approved Guest addition.
IF EXISTS
(
    SELECT 1 FROM #Login127_BeforeSharedRows AS b
    LEFT JOIN [ATAPUtilities].[Philote] AS p ON p.[PhiloteId] = b.[PhiloteId]
    WHERE p.[PhiloteId] IS NULL
       OR ISNULL(DATALENGTH(p.[AdditionalIdsStub]), -1) <> ISNULL(b.StubBytes, -1)
       OR ISNULL(HASHBYTES('SHA2_256', CONVERT(varbinary(max), p.[AdditionalIdsStub])), 0x)
          <> ISNULL(b.StubHash, 0x)
)
OR (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Philote])
   <> (SELECT COUNT_BIG(*) + 1 FROM #Login127_BeforeSharedRows)
OR NOT EXISTS
(
    SELECT 1 FROM [ATAPUtilities].[Philote]
    WHERE [PhiloteId] = '3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b' AND [AdditionalIdsStub] IS NULL
)
OR EXISTS
(
    SELECT 1 FROM [ATAPUtilities].[Philote] AS p
    LEFT JOIN #Login127_BeforeSharedRows AS b ON b.[PhiloteId] = p.[PhiloteId]
    WHERE b.[PhiloteId] IS NULL AND p.[PhiloteId] <> '3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b'
)
    THROW 61720, N'Shared registry changed beyond the approved Guest addition.', 1;

DECLARE @Columns TABLE
(
    TableName sysname NOT NULL, ColumnName sysname NOT NULL,
    TypeName sysname NOT NULL, MaxLength smallint NOT NULL, Nullable bit NOT NULL
);
INSERT INTO @Columns VALUES
    (N'User', N'PhiloteId', N'uniqueidentifier', 16, 0),
    (N'User', N'UserId', N'uniqueidentifier', 16, 0),
    (N'User', N'SaltedAndHashedPassword', N'nvarchar', 1000, 1),
    (N'User', N'EmailHash', N'char', 64, 1),
    (N'User', N'HashAlgorithmName', N'nvarchar', 100, 0),
    (N'User', N'RowVersion', N'timestamp', 8, 0),
    (N'UserInformation', N'UserId', N'uniqueidentifier', 16, 0),
    (N'UserInformation', N'FirstName', N'varbinary', -1, 1),
    (N'UserInformation', N'LastName', N'varbinary', -1, 1),
    (N'UserInformation', N'Email', N'varbinary', -1, 1),
    (N'UserInformation', N'Phone', N'varbinary', -1, 1),
    (N'UserInformation', N'Role', N'varbinary', -1, 1),
    (N'UserInformation', N'EncryptionKeyVersion', N'tinyint', 1, 0),
    (N'UserInformation', N'RowVersion', N'timestamp', 8, 0),
    (N'UserSettings', N'UserId', N'uniqueidentifier', 16, 0),
    (N'UserSettings', N'PreferredTheme', N'nvarchar', 400, 1),
    (N'UserSettings', N'IsDarkMode', N'bit', 1, 0),
    (N'UserSettings', N'Language', N'nvarchar', 400, 1),
    (N'UserSettings', N'TimeZoneId', N'nvarchar', 200, 1),
    (N'UserSettings', N'RowVersion', N'timestamp', 8, 0),
    (N'UserPreferences', N'UserId', N'uniqueidentifier', 16, 0),
    (N'UserPreferences', N'ColorScheme', N'nvarchar', -1, 0),
    (N'UserPreferences', N'UpdatedUtc', N'datetime2', 8, 0),
    (N'UserPreferences', N'RowVersion', N'timestamp', 8, 0);

IF EXISTS
(
    SELECT 1 FROM @Columns AS e
    LEFT JOIN sys.tables AS t ON t.[name] = e.TableName AND t.schema_id = SCHEMA_ID(N'ACE')
    LEFT JOIN sys.columns AS c ON c.object_id = t.object_id AND c.[name] = e.ColumnName
    LEFT JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
    WHERE c.column_id IS NULL OR ty.[name] <> e.TypeName
       OR c.max_length <> e.MaxLength OR c.is_nullable <> e.Nullable
)
OR (SELECT COUNT_BIG(*) FROM sys.columns AS c JOIN sys.tables AS t ON t.object_id = c.object_id
    WHERE t.schema_id = SCHEMA_ID(N'ACE')
      AND t.[name] IN (N'User', N'UserInformation', N'UserSettings', N'UserPreferences')) <> 24
    THROW 61710, N'Exact login columns, physical types or nullability differ.', 1;

IF EXISTS
(
    SELECT 1 FROM sys.columns AS c
    WHERE c.object_id = OBJECT_ID(N'[ACE].[UserPreferences]') AND c.[name] = N'UpdatedUtc'
      AND c.scale <> 7
)
    THROW 61717, N'Timestamp precision differs from datetime2(7).', 1;

DECLARE @Keys TABLE (TableName sysname, ConstraintName sysname, ColumnName sysname, KeyType char(2));
INSERT INTO @Keys VALUES
    (N'User', N'AC_PK_User', N'PhiloteId', 'PK'),
    (N'User', N'AC_UQ_User_UserId', N'UserId', 'UQ'),
    (N'UserInformation', N'AC_PK_UserInformation', N'UserId', 'PK'),
    (N'UserSettings', N'AC_PK_UserSettings', N'UserId', 'PK'),
    (N'UserPreferences', N'AC_PK_UserPreferences', N'UserId', 'PK');
IF EXISTS
(
    SELECT 1 FROM @Keys AS e
    WHERE (SELECT COUNT_BIG(*) FROM sys.key_constraints AS k
           JOIN sys.tables AS t ON t.object_id = k.parent_object_id
           JOIN sys.index_columns AS ic ON ic.object_id = t.object_id AND ic.index_id = k.unique_index_id
           JOIN sys.columns AS c ON c.object_id = t.object_id AND c.column_id = ic.column_id
           WHERE t.schema_id = SCHEMA_ID(N'ACE') AND t.[name] = e.TableName
             AND k.[name] = e.ConstraintName AND k.[type] = e.KeyType
             AND c.[name] = e.ColumnName AND ic.key_ordinal = 1
             AND (SELECT COUNT_BIG(*) FROM sys.index_columns AS allkeys
                  WHERE allkeys.object_id = t.object_id AND allkeys.index_id = k.unique_index_id
                    AND allkeys.key_ordinal > 0) = 1) <> 1
)
    THROW 61711, N'Expected principal or one-to-one key is missing.', 1;

IF (SELECT COUNT_BIG(*) FROM sys.indexes AS i
    WHERE i.object_id = OBJECT_ID(N'[ACE].[User]')
      AND i.[name] = N'AC_UX_User_EmailHash' AND i.is_unique = 1 AND i.has_filter = 1 AND i.is_disabled = 0
      AND LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(i.filter_definition, N'[', N''), N']', N''), N'(', N''), N')', N''), N' ', N'')) = N'emailhashisnotnull'
      AND (SELECT COUNT_BIG(*) FROM sys.index_columns AS k
           JOIN sys.columns AS c ON c.object_id = k.object_id AND c.column_id = k.column_id
           WHERE k.object_id = i.object_id AND k.index_id = i.index_id
             AND k.key_ordinal > 0) = 1
      AND EXISTS (SELECT 1 FROM sys.index_columns AS k
                  JOIN sys.columns AS c ON c.object_id = k.object_id AND c.column_id = k.column_id
                  WHERE k.object_id = i.object_id AND k.index_id = i.index_id
                    AND k.key_ordinal = 1 AND c.[name] = N'EmailHash')) <> 1
    THROW 61712, N'Filtered unique email hash index differs.', 1;

DECLARE @ForeignKeys TABLE (Name sysname, ParentName sysname, ParentColumn sysname, ReferencedSchema sysname, ReferencedName sysname, ReferencedColumn sysname);
INSERT INTO @ForeignKeys VALUES
    (N'AC_FK_User_Philote', N'User', N'PhiloteId', N'ATAPUtilities', N'Philote', N'PhiloteId'),
    (N'AC_FK_UserInformation_User', N'UserInformation', N'UserId', N'ACE', N'User', N'UserId'),
    (N'AC_FK_UserSettings_User', N'UserSettings', N'UserId', N'ACE', N'User', N'UserId'),
    (N'AC_FK_UserPreferences_User', N'UserPreferences', N'UserId', N'ACE', N'User', N'UserId');
IF EXISTS
(
    SELECT 1 FROM @ForeignKeys AS e
    WHERE (SELECT COUNT_BIG(*) FROM sys.foreign_keys AS fk
           JOIN sys.foreign_key_columns AS fc ON fc.constraint_object_id = fk.object_id
           JOIN sys.tables AS p ON p.object_id = fk.parent_object_id
           JOIN sys.columns AS pc ON pc.object_id = p.object_id AND pc.column_id = fc.parent_column_id
           JOIN sys.tables AS r ON r.object_id = fk.referenced_object_id
           JOIN sys.columns AS rc ON rc.object_id = r.object_id AND rc.column_id = fc.referenced_column_id
           WHERE fk.[name] = e.Name AND p.schema_id = SCHEMA_ID(N'ACE')
             AND r.schema_id = SCHEMA_ID(e.ReferencedSchema)
             AND p.[name] = e.ParentName AND pc.[name] = e.ParentColumn
             AND r.[name] = e.ReferencedName AND rc.[name] = e.ReferencedColumn
             AND fk.is_disabled = 0 AND fk.is_not_trusted = 0
             AND (SELECT COUNT_BIG(*) FROM sys.foreign_key_columns AS allcolumns
                  WHERE allcolumns.constraint_object_id = fk.object_id) = 1) <> 1
)
    THROW 61713, N'Owned login FK contract differs.', 1;

IF (SELECT COUNT_BIG(*) FROM sys.check_constraints AS c
    WHERE c.parent_object_id IN (OBJECT_ID(N'[ACE].[User]'), OBJECT_ID(N'[ACE].[UserInformation]'))
      AND c.[name] IN (N'AC_CK_User_Nonempty', N'AC_CK_User_DistinctIdentity',
                      N'AC_CK_User_CredentialPair', N'AC_CK_User_EmailHashFormat', N'AC_CK_User_GuestCredentials',
                      N'AC_CK_User_GuestPhilote', N'AC_CK_UserInformation_KeyVersion', N'AC_CK_UserInformation_Contact')
      AND c.is_disabled = 0 AND c.is_not_trusted = 0) <> 8
    THROW 61714, N'Enabled trusted login checks are missing.', 1;

IF (SELECT COUNT_BIG(*) FROM [ACE].[User]) <> 1
OR NOT EXISTS
(
    SELECT 1 FROM [ACE].[User]
    WHERE [PhiloteId] = '3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b'
      AND [UserId] = '5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e'
      AND [EmailHash] IS NULL AND [SaltedAndHashedPassword] IS NULL
      AND [HashAlgorithmName] = N'Argon2id'
)
OR EXISTS (SELECT 1 FROM [ACE].[UserInformation])
OR (SELECT COUNT_BIG(*) FROM [ACE].[UserSettings]
    WHERE [UserId] = '5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e'
      AND [PreferredTheme] = N'Default' AND [IsDarkMode] = 0
      AND [Language] IS NULL AND [TimeZoneId] IS NULL) <> 1
OR (SELECT COUNT_BIG(*) FROM [ACE].[UserPreferences]
    WHERE [UserId] = '5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e'
      AND [ColorScheme] = N'default' AND [UpdatedUtc] IS NOT NULL) <> 1
    THROW 61715, N'Credential-free Guest post-state differs.', 1;

SELECT N'AfterAssertionsPassed' AS FixturePhase;

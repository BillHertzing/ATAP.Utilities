/*
  V00160 source draft: approved empty-drop Experimental login creation.
  No applied migration, existing registry row, non-user object or history row is changed.
  Future execution must bind dbo.flyway_schema_history and the approved target.
  Guest identities come from the archived credential-free Guest source row;
  their equality to any historically remapped AceCommander identity is not asserted.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @RequiredCatalog nvarchar(128) = N'${atap_required_catalog}';
    IF @RequiredCatalog IS NULL OR DATALENGTH(@RequiredCatalog) = 0
       OR DB_NAME() IS NULL
       OR DB_NAME() COLLATE Latin1_General_100_BIN2 <> @RequiredCatalog COLLATE Latin1_General_100_BIN2
       OR DATALENGTH(DB_NAME()) <> DATALENGTH(@RequiredCatalog)
        THROW 61600, N'Exact approved catalog binding required.', 1;

    IF OBJECT_ID(N'[dbo].[flyway_schema_history]', N'U') IS NULL
        THROW 61601, N'V00160 requires the explicitly bound existing history table.', 1;

    DECLARE @ExpectedHistory TABLE
    (
        [Version] nvarchar(50) NOT NULL,
        [Script] nvarchar(1000) NOT NULL,
        [Checksum] int NOT NULL
    );
    INSERT INTO @ExpectedHistory ([Version], [Script], [Checksum])
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
        (N'00150', N'V00150__Add_AISupervisor_CacheTokens.sql', 155333537);

    IF (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history]) <> 14
       OR EXISTS
       (
           SELECT 1 FROM @ExpectedHistory AS e
           WHERE (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history] AS h
                  WHERE h.[version] = e.[Version] AND h.[script] = e.[Script]
                    AND h.[checksum] = e.[Checksum] AND h.[success] = 1) <> 1
       )
        THROW 61602, N'V00160 predecessor history differs from the reviewed fourteen records.', 1;

    IF OBJECT_ID(N'[ATAPUtilities].[Philote]', N'U') IS NULL
        THROW 61603, N'The retained shared Philote predecessor is required.', 1;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Philote]
               WHERE [PhiloteId] = '3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b')
        THROW 61606, N'Existing shared Guest identity requires explicit disposition.', 1;

    -- A pre-existing ACE.Philote is unrelated and retained unchanged.
    -- Only four absent login targets may be created; no adoption or reset.
    IF OBJECT_ID(N'[ACE].[User]') IS NOT NULL
       OR OBJECT_ID(N'[ACE].[UserInformation]') IS NOT NULL
       OR OBJECT_ID(N'[ACE].[UserSettings]') IS NOT NULL
       OR OBJECT_ID(N'[ACE].[UserPreferences]') IS NOT NULL
        THROW 61604, N'Existing login target or Guest identity requires explicit disposition.', 1;

    IF SCHEMA_ID(N'ACE') IS NULL
        THROW 61605, N'V00160 requires the existing ACE schema in ATAPUtilities.', 1;

    CREATE TABLE [ACE].[User]
    (
        [PhiloteId] uniqueidentifier NOT NULL,
        [UserId] uniqueidentifier NOT NULL
            CONSTRAINT [AC_DF_User_UserId] DEFAULT NEWID(),
        [SaltedAndHashedPassword] nvarchar(500) NULL,
        [EmailHash] char(64) NULL,
        [HashAlgorithmName] nvarchar(50) NOT NULL
            CONSTRAINT [AC_DF_User_HashAlgorithmName] DEFAULT N'Argon2id',
        [RowVersion] rowversion NOT NULL,
        CONSTRAINT [AC_PK_User] PRIMARY KEY CLUSTERED ([PhiloteId]),
        CONSTRAINT [AC_UQ_User_UserId] UNIQUE ([UserId]),
        CONSTRAINT [AC_FK_User_Philote] FOREIGN KEY ([PhiloteId])
            REFERENCES [ATAPUtilities].[Philote] ([PhiloteId]),
        CONSTRAINT [AC_CK_User_Nonempty] CHECK
            ([PhiloteId] <> '00000000-0000-0000-0000-000000000000'
             AND [UserId] <> '00000000-0000-0000-0000-000000000000'),
        CONSTRAINT [AC_CK_User_DistinctIdentity] CHECK ([UserId] <> [PhiloteId]),
        CONSTRAINT [AC_CK_User_CredentialPair] CHECK
            (([EmailHash] IS NULL AND [SaltedAndHashedPassword] IS NULL)
             OR ([EmailHash] IS NOT NULL AND [SaltedAndHashedPassword] IS NOT NULL
                 AND DATALENGTH([SaltedAndHashedPassword]) > 0
                 AND [HashAlgorithmName] = N'Argon2id')),
        CONSTRAINT [AC_CK_User_EmailHashFormat] CHECK
            ([EmailHash] IS NULL
             OR (LEN([EmailHash]) = 64 AND [EmailHash] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^0-9A-Fa-f]%')),
        CONSTRAINT [AC_CK_User_GuestCredentials] CHECK
            ([UserId] <> '5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e'
             OR ([PhiloteId] = '3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b'
                 AND [EmailHash] IS NULL AND [SaltedAndHashedPassword] IS NULL)),
        CONSTRAINT [AC_CK_User_GuestPhilote] CHECK
            ([PhiloteId] <> '3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b'
             OR [UserId] = '5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e')
    );

    CREATE UNIQUE INDEX [AC_UX_User_EmailHash]
        ON [ACE].[User] ([EmailHash])
        WHERE [EmailHash] IS NOT NULL;

    CREATE TABLE [ACE].[UserInformation]
    (
        [UserId] uniqueidentifier NOT NULL,
        [FirstName] varbinary(max) NULL,
        [LastName] varbinary(max) NULL,
        [Email] varbinary(max) NULL,
        [Phone] varbinary(max) NULL,
        [Role] varbinary(max) NULL,
        [EncryptionKeyVersion] tinyint NOT NULL
            CONSTRAINT [AC_DF_UserInformation_EncryptionKeyVersion] DEFAULT 1,
        [RowVersion] rowversion NOT NULL,
        CONSTRAINT [AC_PK_UserInformation] PRIMARY KEY CLUSTERED ([UserId]),
        CONSTRAINT [AC_FK_UserInformation_User] FOREIGN KEY ([UserId])
            REFERENCES [ACE].[User] ([UserId]),
        CONSTRAINT [AC_CK_UserInformation_KeyVersion] CHECK ([EncryptionKeyVersion] IN (1, 2)),
        CONSTRAINT [AC_CK_UserInformation_Contact] CHECK
            (([Email] IS NOT NULL AND DATALENGTH([Email]) > 0)
             OR ([Phone] IS NOT NULL AND DATALENGTH([Phone]) > 0))
    );

    CREATE TABLE [ACE].[UserSettings]
    (
        [UserId] uniqueidentifier NOT NULL,
        [PreferredTheme] nvarchar(200) NULL,
        [IsDarkMode] bit NOT NULL
            CONSTRAINT [AC_DF_UserSettings_IsDarkMode] DEFAULT 0,
        [Language] nvarchar(200) NULL,
        [TimeZoneId] nvarchar(100) NULL,
        [RowVersion] rowversion NOT NULL,
        CONSTRAINT [AC_PK_UserSettings] PRIMARY KEY CLUSTERED ([UserId]),
        CONSTRAINT [AC_FK_UserSettings_User] FOREIGN KEY ([UserId])
            REFERENCES [ACE].[User] ([UserId])
    );

    CREATE TABLE [ACE].[UserPreferences]
    (
        [UserId] uniqueidentifier NOT NULL,
        [ColorScheme] nvarchar(max) NOT NULL
            CONSTRAINT [AC_DF_UserPreferences_ColorScheme] DEFAULT N'default',
        [UpdatedUtc] datetime2(7) NOT NULL
            CONSTRAINT [AC_DF_UserPreferences_UpdatedUtc] DEFAULT SYSUTCDATETIME(),
        [RowVersion] rowversion NOT NULL,
        CONSTRAINT [AC_PK_UserPreferences] PRIMARY KEY CLUSTERED ([UserId]),
        CONSTRAINT [AC_FK_UserPreferences_User] FOREIGN KEY ([UserId])
            REFERENCES [ACE].[User] ([UserId])
    );

    -- Tables are new; any conflicting existing Guest row was refused above.
    -- No encrypted profile or authentication material is needed for Guest.
    INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId])
    VALUES ('3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b');

    INSERT INTO [ACE].[User]
        ([PhiloteId], [UserId], [SaltedAndHashedPassword], [EmailHash], [HashAlgorithmName])
    VALUES
        ('3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b',
         '5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e', NULL, NULL, N'Argon2id');

    INSERT INTO [ACE].[UserSettings]
        ([UserId], [PreferredTheme], [IsDarkMode], [Language], [TimeZoneId])
    VALUES ('5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e', N'Default', 0, NULL, NULL);

    INSERT INTO [ACE].[UserPreferences] ([UserId], [ColorScheme])
    VALUES ('5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e', N'default');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

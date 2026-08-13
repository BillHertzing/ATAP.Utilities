-- =====================================================================
-- V00.02.000060__Add_Instantiation_Manifestation_Tables.sql
--
-- Adds Philote-backed ATAPUtilities instantiation inventory tables and
-- seeds the first two Sprint 0012 instantiation versions.
-- =====================================================================
SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRANSACTION;

BEGIN TRY
    IF OBJECT_ID(N'ATAPUtilities.Organization', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.Organization (
            OrganizationPhiloteId UNIQUEIDENTIFIER NOT NULL,
            OrganizationCode NVARCHAR(100) NOT NULL,
            DisplayName NVARCHAR(200) NOT NULL,
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_Organization PRIMARY KEY CLUSTERED (OrganizationPhiloteId),
            CONSTRAINT FK_Organization_Philote FOREIGN KEY (OrganizationPhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
            CONSTRAINT UQ_Organization_Code UNIQUE (OrganizationCode)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.OrganizationUser', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.OrganizationUser (
            UserPhiloteId UNIQUEIDENTIFIER NOT NULL,
            OrganizationPhiloteId UNIQUEIDENTIFIER NOT NULL,
            UserKey NVARCHAR(100) NOT NULL,
            DisplayName NVARCHAR(200) NOT NULL,
            RoleName NVARCHAR(100) NULL,
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_OrganizationUser PRIMARY KEY CLUSTERED (UserPhiloteId),
            CONSTRAINT FK_OrganizationUser_Philote FOREIGN KEY (UserPhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
            CONSTRAINT FK_OrganizationUser_Organization FOREIGN KEY (OrganizationPhiloteId) REFERENCES ATAPUtilities.Organization (OrganizationPhiloteId),
            CONSTRAINT UQ_OrganizationUser_Key UNIQUE (OrganizationPhiloteId, UserKey)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.Computer', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.Computer (
            ComputerPhiloteId UNIQUEIDENTIFIER NOT NULL,
            OrganizationPhiloteId UNIQUEIDENTIFIER NOT NULL,
            HostName NVARCHAR(128) NOT NULL,
            HardwareRole NVARCHAR(100) NULL,
            OperatingSystem NVARCHAR(200) NULL,
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_Computer PRIMARY KEY CLUSTERED (ComputerPhiloteId),
            CONSTRAINT FK_Computer_Philote FOREIGN KEY (ComputerPhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
            CONSTRAINT FK_Computer_Organization FOREIGN KEY (OrganizationPhiloteId) REFERENCES ATAPUtilities.Organization (OrganizationPhiloteId),
            CONSTRAINT UQ_Computer_HostName UNIQUE (OrganizationPhiloteId, HostName)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.Repository', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.Repository (
            RepositoryPhiloteId UNIQUEIDENTIFIER NOT NULL,
            OrganizationPhiloteId UNIQUEIDENTIFIER NOT NULL,
            RepositoryName NVARCHAR(200) NOT NULL,
            StableRootPath NVARCHAR(500) NULL,
            SprintRootPath NVARCHAR(500) NULL,
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_Repository PRIMARY KEY CLUSTERED (RepositoryPhiloteId),
            CONSTRAINT FK_Repository_Philote FOREIGN KEY (RepositoryPhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
            CONSTRAINT FK_Repository_Organization FOREIGN KEY (OrganizationPhiloteId) REFERENCES ATAPUtilities.Organization (OrganizationPhiloteId),
            CONSTRAINT UQ_Repository_Name UNIQUE (OrganizationPhiloteId, RepositoryName)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.SourceModule', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.SourceModule (
            SourceModulePhiloteId UNIQUEIDENTIFIER NOT NULL,
            RepositoryPhiloteId UNIQUEIDENTIFIER NOT NULL,
            ModuleName NVARCHAR(200) NOT NULL,
            ModuleKind NVARCHAR(50) NOT NULL,
            SourceRootRelativePath NVARCHAR(500) NOT NULL,
            ManifestRelativePath NVARCHAR(500) NULL,
            PublicFunctionsRelativePath NVARCHAR(500) NULL,
            PrivateFunctionsRelativePath NVARCHAR(500) NULL,
            IsPlanned BIT NOT NULL CONSTRAINT DF_SourceModule_IsPlanned DEFAULT (0),
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_SourceModule PRIMARY KEY CLUSTERED (SourceModulePhiloteId),
            CONSTRAINT FK_SourceModule_Philote FOREIGN KEY (SourceModulePhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
            CONSTRAINT FK_SourceModule_Repository FOREIGN KEY (RepositoryPhiloteId) REFERENCES ATAPUtilities.Repository (RepositoryPhiloteId),
            CONSTRAINT CK_SourceModule_ModuleKind CHECK (ModuleKind IN (N'PowerShell', N'CSharp', N'PlannedPowerShell')),
            CONSTRAINT UQ_SourceModule_Name UNIQUE (RepositoryPhiloteId, ModuleName)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.Instantiation', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.Instantiation (
            InstantiationPhiloteId UNIQUEIDENTIFIER NOT NULL,
            OrganizationPhiloteId UNIQUEIDENTIFIER NOT NULL,
            InstantiationName NVARCHAR(200) NOT NULL,
            Purpose NVARCHAR(MAX) NULL,
            CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Instantiation_CreatedAt DEFAULT SYSUTCDATETIME(),
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_Instantiation PRIMARY KEY CLUSTERED (InstantiationPhiloteId),
            CONSTRAINT FK_Instantiation_Philote FOREIGN KEY (InstantiationPhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
            CONSTRAINT FK_Instantiation_Organization FOREIGN KEY (OrganizationPhiloteId) REFERENCES ATAPUtilities.Organization (OrganizationPhiloteId),
            CONSTRAINT UQ_Instantiation_Name UNIQUE (OrganizationPhiloteId, InstantiationName)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.InstantiationVersion', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.InstantiationVersion (
            InstantiationVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            InstantiationPhiloteId UNIQUEIDENTIFIER NOT NULL,
            VersionNumber INT NOT NULL,
            VersionLabel NVARCHAR(100) NOT NULL,
            ParentInstantiationVersionPhiloteId UNIQUEIDENTIFIER NULL,
            CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_InstantiationVersion_CreatedAt DEFAULT SYSUTCDATETIME(),
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_InstantiationVersion PRIMARY KEY CLUSTERED (InstantiationVersionPhiloteId),
            CONSTRAINT FK_InstantiationVersion_Philote FOREIGN KEY (InstantiationVersionPhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
            CONSTRAINT FK_InstantiationVersion_Instantiation FOREIGN KEY (InstantiationPhiloteId) REFERENCES ATAPUtilities.Instantiation (InstantiationPhiloteId),
            CONSTRAINT FK_InstantiationVersion_Parent FOREIGN KEY (ParentInstantiationVersionPhiloteId) REFERENCES ATAPUtilities.InstantiationVersion (InstantiationVersionPhiloteId),
            CONSTRAINT CK_InstantiationVersion_Number CHECK (VersionNumber > 0),
            CONSTRAINT UQ_InstantiationVersion_Number UNIQUE (InstantiationPhiloteId, VersionNumber)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.InstantiationVersionComputer', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.InstantiationVersionComputer (
            InstantiationVersionComputerId INT IDENTITY(1,1) NOT NULL,
            InstantiationVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            ComputerPhiloteId UNIQUEIDENTIFIER NOT NULL,
            MemberRole NVARCHAR(100) NULL,
            SortOrder INT NOT NULL CONSTRAINT DF_InstantiationVersionComputer_SortOrder DEFAULT (0),
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_InstantiationVersionComputer PRIMARY KEY CLUSTERED (InstantiationVersionComputerId),
            CONSTRAINT FK_InstantiationVersionComputer_Version FOREIGN KEY (InstantiationVersionPhiloteId) REFERENCES ATAPUtilities.InstantiationVersion (InstantiationVersionPhiloteId),
            CONSTRAINT FK_InstantiationVersionComputer_Computer FOREIGN KEY (ComputerPhiloteId) REFERENCES ATAPUtilities.Computer (ComputerPhiloteId),
            CONSTRAINT UQ_InstantiationVersionComputer UNIQUE (InstantiationVersionPhiloteId, ComputerPhiloteId)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.InstantiationVersionRepository', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.InstantiationVersionRepository (
            InstantiationVersionRepositoryId INT IDENTITY(1,1) NOT NULL,
            InstantiationVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            RepositoryPhiloteId UNIQUEIDENTIFIER NOT NULL,
            MemberRole NVARCHAR(100) NULL,
            SortOrder INT NOT NULL CONSTRAINT DF_InstantiationVersionRepository_SortOrder DEFAULT (0),
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_InstantiationVersionRepository PRIMARY KEY CLUSTERED (InstantiationVersionRepositoryId),
            CONSTRAINT FK_InstantiationVersionRepository_Version FOREIGN KEY (InstantiationVersionPhiloteId) REFERENCES ATAPUtilities.InstantiationVersion (InstantiationVersionPhiloteId),
            CONSTRAINT FK_InstantiationVersionRepository_Repository FOREIGN KEY (RepositoryPhiloteId) REFERENCES ATAPUtilities.Repository (RepositoryPhiloteId),
            CONSTRAINT UQ_InstantiationVersionRepository UNIQUE (InstantiationVersionPhiloteId, RepositoryPhiloteId)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.InstantiationVersionSourceModule', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.InstantiationVersionSourceModule (
            InstantiationVersionSourceModuleId INT IDENTITY(1,1) NOT NULL,
            InstantiationVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            SourceModulePhiloteId UNIQUEIDENTIFIER NOT NULL,
            LifecycleAction NVARCHAR(50) NOT NULL,
            SourceRootRelativePathOverride NVARCHAR(500) NULL,
            SortOrder INT NOT NULL CONSTRAINT DF_InstantiationVersionSourceModule_SortOrder DEFAULT (0),
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_InstantiationVersionSourceModule PRIMARY KEY CLUSTERED (InstantiationVersionSourceModuleId),
            CONSTRAINT FK_InstantiationVersionSourceModule_Version FOREIGN KEY (InstantiationVersionPhiloteId) REFERENCES ATAPUtilities.InstantiationVersion (InstantiationVersionPhiloteId),
            CONSTRAINT FK_InstantiationVersionSourceModule_SourceModule FOREIGN KEY (SourceModulePhiloteId) REFERENCES ATAPUtilities.SourceModule (SourceModulePhiloteId),
            CONSTRAINT CK_InstantiationVersionSourceModule_Action CHECK (LifecycleAction IN (N'Present', N'Added', N'Rearranged', N'Removed')),
            CONSTRAINT UQ_InstantiationVersionSourceModule UNIQUE (InstantiationVersionPhiloteId, SourceModulePhiloteId)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.ManifestationArtifact', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.ManifestationArtifact (
            ManifestationArtifactPhiloteId UNIQUEIDENTIFIER NOT NULL,
            InstantiationVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            ArtifactKind NVARCHAR(50) NOT NULL,
            RelativePath NVARCHAR(500) NOT NULL,
            SourceObjectKind NVARCHAR(100) NULL,
            SourceObjectPhiloteId UNIQUEIDENTIFIER NULL,
            ContentSha256 CHAR(64) NULL,
            RenderPolicy NVARCHAR(50) NOT NULL,
            SortOrder INT NOT NULL CONSTRAINT DF_ManifestationArtifact_SortOrder DEFAULT (0),
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_ManifestationArtifact PRIMARY KEY CLUSTERED (ManifestationArtifactPhiloteId),
            CONSTRAINT FK_ManifestationArtifact_Philote FOREIGN KEY (ManifestationArtifactPhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
            CONSTRAINT FK_ManifestationArtifact_Version FOREIGN KEY (InstantiationVersionPhiloteId) REFERENCES ATAPUtilities.InstantiationVersion (InstantiationVersionPhiloteId),
            CONSTRAINT CK_ManifestationArtifact_ArtifactKind CHECK (ArtifactKind IN (N'Directory', N'ModuleSource', N'ModuleManifest', N'Report')),
            CONSTRAINT CK_ManifestationArtifact_RenderPolicy CHECK (RenderPolicy IN (N'InspectOnly', N'RenderFromModel', N'Planned')),
            CONSTRAINT UQ_ManifestationArtifact_Path UNIQUE (InstantiationVersionPhiloteId, RelativePath)
        );
    END;

    DECLARE @Philotes TABLE (
        PhiloteId UNIQUEIDENTIFIER NOT NULL
    );

    INSERT INTO @Philotes (PhiloteId)
    VALUES
        ('db5276a7-4859-44d8-9399-ebcac39c5481'),
        ('5e835f19-fb1d-4e70-bf9a-69b3f428bb56'),
        ('f3715ac8-6962-45c4-a6c5-52bbb0e72972'),
        ('18702735-f54d-47ec-bbde-985ae3bb6c27'),
        ('904de22d-1df6-481c-b5da-635a4b153e83'),
        ('4786d272-3406-43a5-a2c7-8c044a2d5cd4'),
        ('33e208e8-3095-43c1-9981-d3ab0c8a8b29'),
        ('636db902-4a63-4196-a85e-ca7df2f2d425'),
        ('4d8e6686-9772-4bcb-92ce-e49f0476196a'),
        ('f4d25915-a988-498c-be31-f28830c95310'),
        ('78388d60-dc2d-48ce-a041-7d10c59e7f49'),
        ('67ab6f8c-94bd-4a54-bf8d-7eeb32652e19'),
        ('a36500b6-c1dd-4005-b6ab-062e856d5bcc'),
        ('d8e76633-315e-4432-abad-f547f1e59749'),
        ('81122f62-f3ee-443c-b014-f4cb99c19b78'),
        ('43e3c395-0071-4808-b330-0d9f7d42253c'),
        ('70f1fb70-a7d5-4dda-b0a9-799f38217ae0'),
        ('14fe137d-197f-4fed-99cf-e4cebd1e0f4f'),
        ('e951d128-3bec-4c6a-9edc-e99a3c136835'),
        ('906117aa-c03c-41f8-aaa0-c3f9fb76dfd3');

    INSERT INTO ATAPUtilities.Philote (PhiloteId)
    SELECT p.PhiloteId
    FROM @Philotes AS p
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.Philote AS existing WHERE existing.PhiloteId = p.PhiloteId
    );

    DECLARE @OrganizationPhiloteId UNIQUEIDENTIFIER = 'db5276a7-4859-44d8-9399-ebcac39c5481';
    DECLARE @UserPhiloteId UNIQUEIDENTIFIER = '5e835f19-fb1d-4e70-bf9a-69b3f428bb56';
    DECLARE @Utat022PhiloteId UNIQUEIDENTIFIER = 'f3715ac8-6962-45c4-a6c5-52bbb0e72972';
    DECLARE @Utat01PhiloteId UNIQUEIDENTIFIER = '18702735-f54d-47ec-bbde-985ae3bb6c27';
    DECLARE @RepositoryPhiloteId UNIQUEIDENTIFIER = '904de22d-1df6-481c-b5da-635a4b153e83';
    DECLARE @SecurityModulePhiloteId UNIQUEIDENTIFIER = '4786d272-3406-43a5-a2c7-8c044a2d5cd4';
    DECLARE @SecretsModulePhiloteId UNIQUEIDENTIFIER = '33e208e8-3095-43c1-9981-d3ab0c8a8b29';
    DECLARE @SecretsPowerShellModulePhiloteId UNIQUEIDENTIFIER = '636db902-4a63-4196-a85e-ca7df2f2d425';
    DECLARE @InstantiationPhiloteId UNIQUEIDENTIFIER = '4d8e6686-9772-4bcb-92ce-e49f0476196a';
    DECLARE @Version1PhiloteId UNIQUEIDENTIFIER = 'f4d25915-a988-498c-be31-f28830c95310';
    DECLARE @Version2PhiloteId UNIQUEIDENTIFIER = '78388d60-dc2d-48ce-a041-7d10c59e7f49';

    IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.Organization WHERE OrganizationPhiloteId = @OrganizationPhiloteId)
    BEGIN
        INSERT INTO ATAPUtilities.Organization (OrganizationPhiloteId, OrganizationCode, DisplayName, Notes)
        VALUES (@OrganizationPhiloteId, N'ATAP', N'ATAP', N'Sprint 0012 seed organization for instantiation manifestation.');
    END;

    IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.OrganizationUser WHERE UserPhiloteId = @UserPhiloteId)
    BEGIN
        INSERT INTO ATAPUtilities.OrganizationUser (UserPhiloteId, OrganizationPhiloteId, UserKey, DisplayName, RoleName, Notes)
        VALUES (@UserPhiloteId, @OrganizationPhiloteId, N'primary-developer', N'Primary Developer', N'Owner', N'Non-PII user row for manifestation membership.');
    END;

    IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.Computer WHERE ComputerPhiloteId = @Utat022PhiloteId)
    BEGIN
        INSERT INTO ATAPUtilities.Computer (ComputerPhiloteId, OrganizationPhiloteId, HostName, HardwareRole, OperatingSystem, Notes)
        VALUES (@Utat022PhiloteId, @OrganizationPhiloteId, N'utat022', N'Primary workstation', N'Windows', N'Primary Sprint 0012 workstation.');
    END;

    IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.Computer WHERE ComputerPhiloteId = @Utat01PhiloteId)
    BEGIN
        INSERT INTO ATAPUtilities.Computer (ComputerPhiloteId, OrganizationPhiloteId, HostName, HardwareRole, OperatingSystem, Notes)
        VALUES (@Utat01PhiloteId, @OrganizationPhiloteId, N'UTAT01', N'Hot spare workstation', N'Windows', N'Hot-spare target referenced by Sprint 0012 Task 12.24.');
    END;

    IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.Repository WHERE RepositoryPhiloteId = @RepositoryPhiloteId)
    BEGIN
        INSERT INTO ATAPUtilities.Repository (RepositoryPhiloteId, OrganizationPhiloteId, RepositoryName, StableRootPath, SprintRootPath, Notes)
        VALUES (
            @RepositoryPhiloteId,
            @OrganizationPhiloteId,
            N'ATAP.Utilities',
            N'C:\Dropbox\whertzing\GitHub\ATAP.Utilities',
            N'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-120-Sprint-0012-work-items',
            N'Reusable library and database repository.'
        );
    END;

    INSERT INTO ATAPUtilities.SourceModule
        (SourceModulePhiloteId, RepositoryPhiloteId, ModuleName, ModuleKind, SourceRootRelativePath, ManifestRelativePath, PublicFunctionsRelativePath, PrivateFunctionsRelativePath, IsPlanned, Notes)
    SELECT v.SourceModulePhiloteId, v.RepositoryPhiloteId, v.ModuleName, v.ModuleKind, v.SourceRootRelativePath, v.ManifestRelativePath, v.PublicFunctionsRelativePath, v.PrivateFunctionsRelativePath, v.IsPlanned, v.Notes
    FROM (VALUES
        (@SecurityModulePhiloteId, @RepositoryPhiloteId, N'ATAP.Utilities.Security.Powershell', N'PowerShell', N'src\ATAP.Utilities.Security.Powershell', N'src\ATAP.Utilities.Security.Powershell\ATAP.Utilities.Security.Powershell.psd1', N'src\ATAP.Utilities.Security.Powershell\public', N'src\ATAP.Utilities.Security.Powershell\private', CAST(0 AS BIT), N'Existing module; v2 records planned casing/layout correction.'),
        (@SecretsModulePhiloteId, @RepositoryPhiloteId, N'ATAP.Utilities.Secrets', N'CSharp', N'src\ATAP.Utilities.Secrets', NULL, NULL, NULL, CAST(0 AS BIT), N'Existing C# Secrets library.'),
        (@SecretsPowerShellModulePhiloteId, @RepositoryPhiloteId, N'ATAP.Utilities.Secrets.PowerShell', N'PlannedPowerShell', N'src\ATAP.Utilities.Secrets.PowerShell', N'src\ATAP.Utilities.Secrets.PowerShell\ATAP.Utilities.Secrets.PowerShell.psd1', N'src\ATAP.Utilities.Secrets.PowerShell\public', N'src\ATAP.Utilities.Secrets.PowerShell\private', CAST(1 AS BIT), N'Planned PowerShell module added by instantiation v2.')
    ) AS v (SourceModulePhiloteId, RepositoryPhiloteId, ModuleName, ModuleKind, SourceRootRelativePath, ManifestRelativePath, PublicFunctionsRelativePath, PrivateFunctionsRelativePath, IsPlanned, Notes)
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.SourceModule AS existing WHERE existing.SourceModulePhiloteId = v.SourceModulePhiloteId
    );

    IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.Instantiation WHERE InstantiationPhiloteId = @InstantiationPhiloteId)
    BEGIN
        INSERT INTO ATAPUtilities.Instantiation (InstantiationPhiloteId, OrganizationPhiloteId, InstantiationName, Purpose, Notes)
        VALUES (@InstantiationPhiloteId, @OrganizationPhiloteId, N'ATAP Utilities Sprint 0012', N'Model organization, computers, repository, and source modules for manifestation rendering.', N'Seeded for Sprint 0012 Tasks 12.25 and 12.26.');
    END;

    IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.InstantiationVersion WHERE InstantiationVersionPhiloteId = @Version1PhiloteId)
    BEGIN
        INSERT INTO ATAPUtilities.InstantiationVersion (InstantiationVersionPhiloteId, InstantiationPhiloteId, VersionNumber, VersionLabel, ParentInstantiationVersionPhiloteId, Notes)
        VALUES (@Version1PhiloteId, @InstantiationPhiloteId, 1, N'v1-current-repository-state', NULL, N'Current organization, computers, ATAP.Utilities repository, Security PowerShell module, and Secrets C# module.');
    END;

    IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.InstantiationVersion WHERE InstantiationVersionPhiloteId = @Version2PhiloteId)
    BEGIN
        INSERT INTO ATAPUtilities.InstantiationVersion (InstantiationVersionPhiloteId, InstantiationPhiloteId, VersionNumber, VersionLabel, ParentInstantiationVersionPhiloteId, Notes)
        VALUES (@Version2PhiloteId, @InstantiationPhiloteId, 2, N'v2-secrets-powershell-and-security-rearrange', @Version1PhiloteId, N'Adds planned ATAP.Utilities.Secrets.PowerShell and records planned Security PowerShell casing/layout correction.');
    END;

    INSERT INTO ATAPUtilities.InstantiationVersionComputer (InstantiationVersionPhiloteId, ComputerPhiloteId, MemberRole, SortOrder, Notes)
    SELECT v.InstantiationVersionPhiloteId, v.ComputerPhiloteId, v.MemberRole, v.SortOrder, v.Notes
    FROM (VALUES
        (@Version1PhiloteId, @Utat022PhiloteId, N'Primary', 10, N'Primary workstation.'),
        (@Version1PhiloteId, @Utat01PhiloteId, N'HotSpare', 20, N'Hot-spare workstation.'),
        (@Version2PhiloteId, @Utat022PhiloteId, N'Primary', 10, N'Primary workstation.'),
        (@Version2PhiloteId, @Utat01PhiloteId, N'HotSpare', 20, N'Hot-spare workstation.')
    ) AS v (InstantiationVersionPhiloteId, ComputerPhiloteId, MemberRole, SortOrder, Notes)
    WHERE NOT EXISTS (
        SELECT 1
        FROM ATAPUtilities.InstantiationVersionComputer AS existing
        WHERE existing.InstantiationVersionPhiloteId = v.InstantiationVersionPhiloteId
          AND existing.ComputerPhiloteId = v.ComputerPhiloteId
    );

    INSERT INTO ATAPUtilities.InstantiationVersionRepository (InstantiationVersionPhiloteId, RepositoryPhiloteId, MemberRole, SortOrder, Notes)
    SELECT v.InstantiationVersionPhiloteId, v.RepositoryPhiloteId, v.MemberRole, v.SortOrder, v.Notes
    FROM (VALUES
        (@Version1PhiloteId, @RepositoryPhiloteId, N'PrimarySource', 10, N'Current ATAP.Utilities repository.'),
        (@Version2PhiloteId, @RepositoryPhiloteId, N'PrimarySource', 10, N'Current ATAP.Utilities repository.')
    ) AS v (InstantiationVersionPhiloteId, RepositoryPhiloteId, MemberRole, SortOrder, Notes)
    WHERE NOT EXISTS (
        SELECT 1
        FROM ATAPUtilities.InstantiationVersionRepository AS existing
        WHERE existing.InstantiationVersionPhiloteId = v.InstantiationVersionPhiloteId
          AND existing.RepositoryPhiloteId = v.RepositoryPhiloteId
    );

    INSERT INTO ATAPUtilities.InstantiationVersionSourceModule
        (InstantiationVersionPhiloteId, SourceModulePhiloteId, LifecycleAction, SourceRootRelativePathOverride, SortOrder, Notes)
    SELECT v.InstantiationVersionPhiloteId, v.SourceModulePhiloteId, v.LifecycleAction, v.SourceRootRelativePathOverride, v.SortOrder, v.Notes
    FROM (VALUES
        (@Version1PhiloteId, @SecurityModulePhiloteId, N'Present', NULL, 10, N'Existing Security PowerShell module.'),
        (@Version1PhiloteId, @SecretsModulePhiloteId, N'Present', NULL, 20, N'Existing Secrets C# module.'),
        (@Version2PhiloteId, @SecurityModulePhiloteId, N'Rearranged', N'src\ATAP.Utilities.Security.PowerShell', 10, N'Planned casing/layout correction from Powershell to PowerShell.'),
        (@Version2PhiloteId, @SecretsModulePhiloteId, N'Present', NULL, 20, N'Existing Secrets C# module remains.'),
        (@Version2PhiloteId, @SecretsPowerShellModulePhiloteId, N'Added', NULL, 30, N'New planned Secrets PowerShell module.')
    ) AS v (InstantiationVersionPhiloteId, SourceModulePhiloteId, LifecycleAction, SourceRootRelativePathOverride, SortOrder, Notes)
    WHERE NOT EXISTS (
        SELECT 1
        FROM ATAPUtilities.InstantiationVersionSourceModule AS existing
        WHERE existing.InstantiationVersionPhiloteId = v.InstantiationVersionPhiloteId
          AND existing.SourceModulePhiloteId = v.SourceModulePhiloteId
    );

    INSERT INTO ATAPUtilities.ManifestationArtifact
        (ManifestationArtifactPhiloteId, InstantiationVersionPhiloteId, ArtifactKind, RelativePath, SourceObjectKind, SourceObjectPhiloteId, ContentSha256, RenderPolicy, SortOrder, Notes)
    SELECT v.ManifestationArtifactPhiloteId, v.InstantiationVersionPhiloteId, v.ArtifactKind, v.RelativePath, v.SourceObjectKind, v.SourceObjectPhiloteId, NULL, v.RenderPolicy, v.SortOrder, v.Notes
    FROM (VALUES
        ('67ab6f8c-94bd-4a54-bf8d-7eeb32652e19', @Version1PhiloteId, N'Directory', N'src\ATAP.Utilities.Security.Powershell', N'SourceModule', @SecurityModulePhiloteId, N'InspectOnly', 10, N'Existing Security PowerShell module root.'),
        ('a36500b6-c1dd-4005-b6ab-062e856d5bcc', @Version1PhiloteId, N'Directory', N'src\ATAP.Utilities.Secrets', N'SourceModule', @SecretsModulePhiloteId, N'InspectOnly', 20, N'Existing Secrets C# project root.'),
        ('d8e76633-315e-4432-abad-f547f1e59749', @Version2PhiloteId, N'Directory', N'src\ATAP.Utilities.Security.PowerShell', N'SourceModule', @SecurityModulePhiloteId, N'Planned', 10, N'Planned Security PowerShell corrected root.'),
        ('81122f62-f3ee-443c-b014-f4cb99c19b78', @Version2PhiloteId, N'Directory', N'src\ATAP.Utilities.Secrets', N'SourceModule', @SecretsModulePhiloteId, N'InspectOnly', 20, N'Existing Secrets C# project root.'),
        ('43e3c395-0071-4808-b330-0d9f7d42253c', @Version2PhiloteId, N'Directory', N'src\ATAP.Utilities.Secrets.PowerShell', N'SourceModule', @SecretsPowerShellModulePhiloteId, N'Planned', 30, N'Planned Secrets PowerShell module root.'),
        ('70f1fb70-a7d5-4dda-b0a9-799f38217ae0', @Version2PhiloteId, N'ModuleManifest', N'src\ATAP.Utilities.Secrets.PowerShell\ATAP.Utilities.Secrets.PowerShell.psd1', N'SourceModule', @SecretsPowerShellModulePhiloteId, N'Planned', 40, N'Planned Secrets PowerShell manifest.'),
        ('14fe137d-197f-4fed-99cf-e4cebd1e0f4f', @Version2PhiloteId, N'Report', N'_generated\Instantiation\ATAP.Utilities-Sprint0012-v2.md', N'InstantiationVersion', @Version2PhiloteId, N'RenderFromModel', 50, N'Future report output path under repository _generated.')
    ) AS v (ManifestationArtifactPhiloteId, InstantiationVersionPhiloteId, ArtifactKind, RelativePath, SourceObjectKind, SourceObjectPhiloteId, RenderPolicy, SortOrder, Notes)
    WHERE NOT EXISTS (
        SELECT 1
        FROM ATAPUtilities.ManifestationArtifact AS existing
        WHERE existing.ManifestationArtifactPhiloteId = v.ManifestationArtifactPhiloteId
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

PRINT N'V00.02.000060 — ATAPUtilities instantiation manifestation tables added and seeded.';

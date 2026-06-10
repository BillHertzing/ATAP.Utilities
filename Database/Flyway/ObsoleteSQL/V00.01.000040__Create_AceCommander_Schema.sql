USE ATAPUtilities;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================
   V00.01.000040 - Create AceCommander Schema (Structure Only)
   Mirrors ATAPUtilities core schema tables in AceCommander.
   ============================================================ */

IF NOT EXISTS (
    SELECT 1 FROM sys.schemas WHERE name = N'AceCommander'
) EXEC (N'CREATE SCHEMA AceCommander');
GO

-- Drop in reverse dependency order to keep the script re-runnable.
IF OBJECT_ID(N'AceCommander.RuleInstantiationBinding', N'U') IS NOT NULL DROP TABLE AceCommander.RuleInstantiationBinding;
GO
IF OBJECT_ID(N'AceCommander.RuleInstantiation', N'U') IS NOT NULL DROP TABLE AceCommander.RuleInstantiation;
GO
IF OBJECT_ID(N'AceCommander.RuleSetMember', N'U') IS NOT NULL DROP TABLE AceCommander.RuleSetMember;
GO
IF OBJECT_ID(N'AceCommander.RuleSet', N'U') IS NOT NULL DROP TABLE AceCommander.RuleSet;
GO
IF OBJECT_ID(N'AceCommander.RulePrimitiveComposition', N'U') IS NOT NULL DROP TABLE AceCommander.RulePrimitiveComposition;
GO
IF OBJECT_ID(N'AceCommander.[Rule]', N'U') IS NOT NULL DROP TABLE AceCommander.[Rule];
GO
IF OBJECT_ID(N'AceCommander.RulePrimitiveInput', N'U') IS NOT NULL DROP TABLE AceCommander.RulePrimitiveInput;
GO
IF OBJECT_ID(N'AceCommander.RulePrimitive', N'U') IS NOT NULL DROP TABLE AceCommander.RulePrimitive;
GO
IF OBJECT_ID(N'AceCommander.PrimitiveLanguageKind', N'U') IS NOT NULL DROP TABLE AceCommander.PrimitiveLanguageKind;
GO
IF OBJECT_ID(N'AceCommander.UserSettings', N'U') IS NOT NULL DROP TABLE AceCommander.UserSettings;
GO
IF OBJECT_ID(N'AceCommander.UserInformation', N'U') IS NOT NULL DROP TABLE AceCommander.UserInformation;
GO
IF OBJECT_ID(N'AceCommander.[User]', N'U') IS NOT NULL DROP TABLE AceCommander.[User];
GO
IF OBJECT_ID(N'AceCommander.PhiloteTimeBlock', N'U') IS NOT NULL DROP TABLE AceCommander.PhiloteTimeBlock;
GO
IF OBJECT_ID(N'AceCommander.PhiloteAdditionalId', N'U') IS NOT NULL DROP TABLE AceCommander.PhiloteAdditionalId;
GO
IF OBJECT_ID(N'AceCommander.Philote', N'U') IS NOT NULL DROP TABLE AceCommander.Philote;
GO

CREATE TABLE AceCommander.Philote (
    PhiloteId UNIQUEIDENTIFIER NOT NULL CONSTRAINT AC_DF_Philote_PhiloteId DEFAULT NEWID(),
    CreatedAt DATETIME2 NOT NULL CONSTRAINT AC_DF_Philote_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT AC_PK_Philote PRIMARY KEY CLUSTERED (PhiloteId)
);
GO

CREATE TABLE AceCommander.PhiloteAdditionalId (
    PhiloteAdditionalIdId INT NOT NULL IDENTITY(1,1),
    PhiloteId UNIQUEIDENTIFIER NOT NULL,
    KeyName NVARCHAR(200) NOT NULL,
    ValueId UNIQUEIDENTIFIER NOT NULL,
    CONSTRAINT AC_PK_PhiloteAdditionalId PRIMARY KEY CLUSTERED (PhiloteAdditionalIdId),
    CONSTRAINT AC_FK_PhiloteAdditionalId_Philote FOREIGN KEY (PhiloteId) REFERENCES AceCommander.Philote (PhiloteId),
    CONSTRAINT AC_UQ_PhiloteAdditionalId_Key UNIQUE (PhiloteId, KeyName)
);
GO

CREATE TABLE AceCommander.PhiloteTimeBlock (
    PhiloteTimeBlockId INT NOT NULL IDENTITY(1,1),
    PhiloteId UNIQUEIDENTIFIER NOT NULL,
    StartAt DATETIME2 NOT NULL,
    EndAt DATETIME2 NULL,
    CONSTRAINT AC_PK_PhiloteTimeBlock PRIMARY KEY CLUSTERED (PhiloteTimeBlockId),
    CONSTRAINT AC_FK_PhiloteTimeBlock_Philote FOREIGN KEY (PhiloteId) REFERENCES AceCommander.Philote (PhiloteId)
);
GO

CREATE TABLE AceCommander.PrimitiveLanguageKind (
    PrimitiveLanguageKindId TINYINT NOT NULL,
    Name NVARCHAR(50) NOT NULL,
    Description NVARCHAR(200) NULL,
    CONSTRAINT AC_PK_PrimitiveLanguageKind PRIMARY KEY CLUSTERED (PrimitiveLanguageKindId),
    CONSTRAINT AC_UQ_PrimitiveLanguageKind_Name UNIQUE (Name)
);
GO

CREATE TABLE AceCommander.RulePrimitive (
    PhiloteId UNIQUEIDENTIFIER NOT NULL,
    PrimitiveLanguageKindId TINYINT NOT NULL,
    Name NVARCHAR(200) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    BnfDefinition NVARCHAR(MAX) NULL,
    Attribution NVARCHAR(MAX) NULL,
    CONSTRAINT AC_PK_RulePrimitive PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT AC_FK_RulePrimitive_Philote FOREIGN KEY (PhiloteId) REFERENCES AceCommander.Philote (PhiloteId),
    CONSTRAINT AC_FK_RulePrimitive_LanguageKind FOREIGN KEY (PrimitiveLanguageKindId) REFERENCES AceCommander.PrimitiveLanguageKind (PrimitiveLanguageKindId),
    CONSTRAINT AC_UQ_RulePrimitive_Language_Name UNIQUE (PrimitiveLanguageKindId, Name)
);
GO

CREATE TABLE AceCommander.RulePrimitiveInput (
    RulePrimitiveInputId INT NOT NULL IDENTITY(1,1),
    PhiloteId UNIQUEIDENTIFIER NOT NULL,
    InputName NVARCHAR(200) NOT NULL,
    TypeName NVARCHAR(200) NULL,
    Description NVARCHAR(MAX) NULL,
    DefaultValue NVARCHAR(MAX) NULL,
    IsRequired BIT NOT NULL CONSTRAINT AC_DF_RulePrimitiveInput_IsRequired DEFAULT 1,
    CONSTRAINT AC_PK_RulePrimitiveInput PRIMARY KEY CLUSTERED (RulePrimitiveInputId),
    CONSTRAINT AC_FK_RulePrimitiveInput_Primitive FOREIGN KEY (PhiloteId) REFERENCES AceCommander.RulePrimitive (PhiloteId),
    CONSTRAINT AC_UQ_RulePrimitiveInput_Name UNIQUE (PhiloteId, InputName)
);
GO

CREATE TABLE AceCommander.[Rule] (
    PhiloteId UNIQUEIDENTIFIER NOT NULL,
    PrimitiveLanguageKindId TINYINT NOT NULL,
    Name NVARCHAR(200) NOT NULL,
    Purpose NVARCHAR(MAX) NULL,
    SourceFileReference NVARCHAR(500) NULL,
    CONSTRAINT AC_PK_Rule PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT AC_FK_Rule_Philote FOREIGN KEY (PhiloteId) REFERENCES AceCommander.Philote (PhiloteId),
    CONSTRAINT AC_FK_Rule_LanguageKind FOREIGN KEY (PrimitiveLanguageKindId) REFERENCES AceCommander.PrimitiveLanguageKind (PrimitiveLanguageKindId),
    CONSTRAINT AC_UQ_Rule_Language_Name UNIQUE (PrimitiveLanguageKindId, Name)
);
GO

CREATE TABLE AceCommander.RulePrimitiveComposition (
    RulePrimitiveCompositionId INT NOT NULL IDENTITY(1,1),
    RulePhiloteId UNIQUEIDENTIFIER NOT NULL,
    SequenceKey NVARCHAR(20) NOT NULL,
    PrimitivePhiloteId UNIQUEIDENTIFIER NOT NULL,
    BoundInputsJson NVARCHAR(MAX) NULL,
    Notes NVARCHAR(MAX) NULL,
    CONSTRAINT AC_PK_RulePrimitiveComposition PRIMARY KEY CLUSTERED (RulePrimitiveCompositionId),
    CONSTRAINT AC_FK_RulePC_Rule FOREIGN KEY (RulePhiloteId) REFERENCES AceCommander.[Rule] (PhiloteId),
    CONSTRAINT AC_FK_RulePC_Primitive FOREIGN KEY (PrimitivePhiloteId) REFERENCES AceCommander.RulePrimitive (PhiloteId),
    CONSTRAINT AC_UQ_RulePC_Rule_Key UNIQUE (RulePhiloteId, SequenceKey)
);
GO

CREATE TABLE AceCommander.RuleSet (
    PhiloteId UNIQUEIDENTIFIER NOT NULL,
    Name NVARCHAR(200) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    CONSTRAINT AC_PK_RuleSet PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT AC_FK_RuleSet_Philote FOREIGN KEY (PhiloteId) REFERENCES AceCommander.Philote (PhiloteId),
    CONSTRAINT AC_UQ_RuleSet_Name UNIQUE (Name)
);
GO

CREATE TABLE AceCommander.RuleSetMember (
    RuleSetMemberId INT NOT NULL IDENTITY(1,1),
    RuleSetPhiloteId UNIQUEIDENTIFIER NOT NULL,
    RulePhiloteId UNIQUEIDENTIFIER NOT NULL,
    SequenceNumber INT NOT NULL,
    Notes NVARCHAR(MAX) NULL,
    CONSTRAINT AC_PK_RuleSetMember PRIMARY KEY CLUSTERED (RuleSetMemberId),
    CONSTRAINT AC_FK_RuleSetMember_RuleSet FOREIGN KEY (RuleSetPhiloteId) REFERENCES AceCommander.RuleSet (PhiloteId),
    CONSTRAINT AC_FK_RuleSetMember_Rule FOREIGN KEY (RulePhiloteId) REFERENCES AceCommander.[Rule] (PhiloteId),
    CONSTRAINT AC_UQ_RuleSetMember_Set_Seq UNIQUE (RuleSetPhiloteId, SequenceNumber)
);
GO

CREATE TABLE AceCommander.RuleInstantiation (
    PhiloteId UNIQUEIDENTIFIER NOT NULL,
    RulePhiloteId UNIQUEIDENTIFIER NOT NULL,
    CreatedAt DATETIME2 NOT NULL CONSTRAINT AC_DF_RuleInstantiation_CreatedAt DEFAULT SYSUTCDATETIME(),
    Notes NVARCHAR(MAX) NULL,
    CONSTRAINT AC_PK_RuleInstantiation PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT AC_FK_RuleInstantiation_Philote FOREIGN KEY (PhiloteId) REFERENCES AceCommander.Philote (PhiloteId),
    CONSTRAINT AC_FK_RuleInstantiation_Rule FOREIGN KEY (RulePhiloteId) REFERENCES AceCommander.[Rule] (PhiloteId)
);
GO

CREATE TABLE AceCommander.RuleInstantiationBinding (
    RuleInstantiationBindingId INT NOT NULL IDENTITY(1,1),
    InstantiationPhiloteId UNIQUEIDENTIFIER NOT NULL,
    InputName NVARCHAR(200) NOT NULL,
    InputValue NVARCHAR(MAX) NULL,
    CONSTRAINT AC_PK_RuleInstantiationBinding PRIMARY KEY CLUSTERED (RuleInstantiationBindingId),
    CONSTRAINT AC_FK_RuleInstantiationBinding_Instantiation FOREIGN KEY (InstantiationPhiloteId) REFERENCES AceCommander.RuleInstantiation (PhiloteId),
    CONSTRAINT AC_UQ_RuleInstantiationBinding_Name UNIQUE (InstantiationPhiloteId, InputName)
);
GO

CREATE TABLE AceCommander.[User] (
    PhiloteId UNIQUEIDENTIFIER NOT NULL,
    UserId UNIQUEIDENTIFIER NOT NULL CONSTRAINT AC_DF_User_UserId DEFAULT NEWID(),
    SaltedAndHashedPassword NVARCHAR(500) NULL,
    EmailHash CHAR(64) NULL,
    HashAlgorithmName NVARCHAR(50) NOT NULL CONSTRAINT AC_DF_User_HashAlgorithmName DEFAULT N'Argon2id',
    CONSTRAINT AC_PK_User PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT AC_FK_User_Philote FOREIGN KEY (PhiloteId) REFERENCES AceCommander.Philote (PhiloteId),
    CONSTRAINT AC_UQ_User_UserId UNIQUE (UserId)
);
GO

CREATE INDEX AC_IX_User_EmailHash ON AceCommander.[User] (EmailHash);
GO

CREATE TABLE AceCommander.UserInformation (
    UserId UNIQUEIDENTIFIER NOT NULL,
    FirstName VARBINARY(MAX) NULL,
    LastName VARBINARY(MAX) NULL,
    Email VARBINARY(MAX) NULL,
    Phone VARBINARY(MAX) NULL,
    Role VARBINARY(MAX) NULL,
    EncryptionKeyVersion TINYINT NOT NULL CONSTRAINT AC_DF_UserInformation_EncryptionKeyVersion DEFAULT 1,
    CONSTRAINT AC_PK_UserInformation PRIMARY KEY CLUSTERED (UserId),
    CONSTRAINT AC_FK_UserInformation_User FOREIGN KEY (UserId) REFERENCES AceCommander.[User] (UserId),
    CONSTRAINT AC_CK_UserInformation_Contact CHECK (
        (Email IS NOT NULL OR Phone IS NOT NULL)
        AND NOT (Email IS NOT NULL AND Phone IS NOT NULL)
    )
);
GO

CREATE TABLE AceCommander.UserSettings (
    UserId UNIQUEIDENTIFIER NOT NULL,
    PreferredTheme NVARCHAR(200) NULL,
    IsDarkMode BIT NOT NULL CONSTRAINT AC_DF_UserSettings_IsDarkMode DEFAULT 0,
    Language NVARCHAR(200) NULL,
    CONSTRAINT AC_PK_UserSettings PRIMARY KEY CLUSTERED (UserId),
    CONSTRAINT AC_FK_UserSettings_User FOREIGN KEY (UserId) REFERENCES AceCommander.[User] (UserId)
);
GO

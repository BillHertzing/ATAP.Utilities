USE ATAPUtilities;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
SET NOCOUNT ON;
GO

/* ============================================================
   V00.01.000010 — Create ATAPUtilities Core Schema (COMBINED)
   ============================================================
   Combined from source migrations:
     V00.01.000010  ATAPUtilities core schema
     V00.01.000031  EmailHash / HashAlgorithmName on [User]  (incorporated inline)
     V00.01.000040  AceCommander schema mirror
     V00.01.000060  BuildSet / BuildSetMember
     V00.01.000080  AceCommander.UserDesignerSettings  *** SOURCE FILE CORRUPT — see TODO in Section 4.9 ***
     V00.01.000302  ATAPUtilities.usp_GetDecryptedUserInformation
     V00.01.000303  User views (vw_UserFull, vw_UserCrossSchema)
     V00.02.000010  AceCommander ScheduledTask / ScheduledTaskRun
     V00.02.000020  Tags and Gmail schemas + seed data
     V00.02.000030  LastRun columns on ScheduledTask  (incorporated inline)

   Sections:
      1.  Schemas
      2.  DROP — full dependency order (re-runnable)
      3.  ATAPUtilities tables  (Philote → Rules → BuildSets → User)
      4.  AceCommander tables   (mirror + ScheduledTask)
      5.  Tags schema tables
      6.  Gmail schema table
      7.  Seed data             (PrimitiveLanguageKind, RelationshipTypes, Tags hierarchy)
      8.  Stored procedures
      9.  Views
   ============================================================ */


-- ===========================================================
-- SECTION 1 — Schemas
-- ===========================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'ATAPUtilities')
    EXEC (N'CREATE SCHEMA ATAPUtilities');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'AceCommander')
    EXEC (N'CREATE SCHEMA AceCommander');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Tags')
    EXEC (N'CREATE SCHEMA Tags');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Gmail')
    EXEC (N'CREATE SCHEMA Gmail');
GO


-- ===========================================================
-- SECTION 2 — DROP in full dependency order (re-runnable)
-- Views and procedures first, then tables deepest-child first.
-- ===========================================================

-- Views
IF OBJECT_ID(N'Tags.vw_TagRelationshipsExpanded',  N'V') IS NOT NULL DROP VIEW Tags.vw_TagRelationshipsExpanded;
GO
IF OBJECT_ID(N'Tags.vw_TagsWithChildCount',        N'V') IS NOT NULL DROP VIEW Tags.vw_TagsWithChildCount;
GO
IF OBJECT_ID(N'Tags.vw_RootTags',                  N'V') IS NOT NULL DROP VIEW Tags.vw_RootTags;
GO
IF OBJECT_ID(N'Tags.vw_ActiveTags',                N'V') IS NOT NULL DROP VIEW Tags.vw_ActiveTags;
GO
IF OBJECT_ID(N'AceCommander.vw_UserCrossSchema',   N'V') IS NOT NULL DROP VIEW AceCommander.vw_UserCrossSchema;
GO
IF OBJECT_ID(N'AceCommander.vw_UserFull',          N'V') IS NOT NULL DROP VIEW AceCommander.vw_UserFull;
GO
IF OBJECT_ID(N'ATAPUtilities.vw_UserFull',         N'V') IS NOT NULL DROP VIEW ATAPUtilities.vw_UserFull;
GO

-- Procedures
IF OBJECT_ID(N'Tags.usp_GetTagDescendants',        N'P') IS NOT NULL DROP PROCEDURE Tags.usp_GetTagDescendants;
GO
IF OBJECT_ID(N'Tags.usp_GetTagAncestors',          N'P') IS NOT NULL DROP PROCEDURE Tags.usp_GetTagAncestors;
GO
IF OBJECT_ID(N'Tags.usp_GetTagTree',               N'P') IS NOT NULL DROP PROCEDURE Tags.usp_GetTagTree;
GO
IF OBJECT_ID(N'ATAPUtilities.usp_GetDecryptedUserInformation', N'P') IS NOT NULL
    DROP PROCEDURE ATAPUtilities.usp_GetDecryptedUserInformation;
GO

-- Gmail
IF OBJECT_ID(N'Gmail.gmailMessages',               N'U') IS NOT NULL DROP TABLE Gmail.gmailMessages;
GO

-- Tags
IF OBJECT_ID(N'Tags.TagRelationships',             N'U') IS NOT NULL DROP TABLE Tags.TagRelationships;
GO
IF OBJECT_ID(N'Tags.TagAliases',                   N'U') IS NOT NULL DROP TABLE Tags.TagAliases;
GO
IF OBJECT_ID(N'Tags.RelationshipTypes',            N'U') IS NOT NULL DROP TABLE Tags.RelationshipTypes;
GO
IF OBJECT_ID(N'Tags.Tags',                         N'U') IS NOT NULL DROP TABLE Tags.Tags;
GO

-- AceCommander — deepest child first
IF OBJECT_ID(N'AceCommander.RuleInstantiationBinding', N'U') IS NOT NULL DROP TABLE AceCommander.RuleInstantiationBinding;
GO
IF OBJECT_ID(N'AceCommander.RuleInstantiation',        N'U') IS NOT NULL DROP TABLE AceCommander.RuleInstantiation;
GO
IF OBJECT_ID(N'AceCommander.RuleSetMember',            N'U') IS NOT NULL DROP TABLE AceCommander.RuleSetMember;
GO
IF OBJECT_ID(N'AceCommander.RuleSet',                  N'U') IS NOT NULL DROP TABLE AceCommander.RuleSet;
GO
IF OBJECT_ID(N'AceCommander.RulePrimitiveComposition', N'U') IS NOT NULL DROP TABLE AceCommander.RulePrimitiveComposition;
GO
IF OBJECT_ID(N'AceCommander.[Rule]',                   N'U') IS NOT NULL DROP TABLE AceCommander.[Rule];
GO
IF OBJECT_ID(N'AceCommander.RulePrimitiveInput',       N'U') IS NOT NULL DROP TABLE AceCommander.RulePrimitiveInput;
GO
IF OBJECT_ID(N'AceCommander.RulePrimitive',            N'U') IS NOT NULL DROP TABLE AceCommander.RulePrimitive;
GO
IF OBJECT_ID(N'AceCommander.PrimitiveLanguageKind',    N'U') IS NOT NULL DROP TABLE AceCommander.PrimitiveLanguageKind;
GO
IF OBJECT_ID(N'AceCommander.ScheduledTaskRun',         N'U') IS NOT NULL DROP TABLE AceCommander.ScheduledTaskRun;
GO
IF OBJECT_ID(N'AceCommander.ScheduledTask',            N'U') IS NOT NULL DROP TABLE AceCommander.ScheduledTask;
GO
IF OBJECT_ID(N'AceCommander.UserDesignerSettings',     N'U') IS NOT NULL DROP TABLE AceCommander.UserDesignerSettings;
GO
IF OBJECT_ID(N'AceCommander.UserSettings',             N'U') IS NOT NULL DROP TABLE AceCommander.UserSettings;
GO
IF OBJECT_ID(N'AceCommander.UserInformation',          N'U') IS NOT NULL DROP TABLE AceCommander.UserInformation;
GO
IF OBJECT_ID(N'AceCommander.[User]',                   N'U') IS NOT NULL DROP TABLE AceCommander.[User];
GO
IF OBJECT_ID(N'AceCommander.PhiloteTimeBlock',         N'U') IS NOT NULL DROP TABLE AceCommander.PhiloteTimeBlock;
GO
IF OBJECT_ID(N'AceCommander.PhiloteAdditionalId',      N'U') IS NOT NULL DROP TABLE AceCommander.PhiloteAdditionalId;
GO
IF OBJECT_ID(N'AceCommander.Philote',                  N'U') IS NOT NULL DROP TABLE AceCommander.Philote;
GO

-- ATAPUtilities — deepest child first
IF OBJECT_ID(N'ATAPUtilities.RuleInstantiationBinding', N'U') IS NOT NULL DROP TABLE ATAPUtilities.RuleInstantiationBinding;
GO
IF OBJECT_ID(N'ATAPUtilities.RuleInstantiation',        N'U') IS NOT NULL DROP TABLE ATAPUtilities.RuleInstantiation;
GO
IF OBJECT_ID(N'ATAPUtilities.RuleSetMember',            N'U') IS NOT NULL DROP TABLE ATAPUtilities.RuleSetMember;
GO
IF OBJECT_ID(N'ATAPUtilities.BuildSetMember',           N'U') IS NOT NULL DROP TABLE ATAPUtilities.BuildSetMember;
GO
IF OBJECT_ID(N'ATAPUtilities.BuildSet',                 N'U') IS NOT NULL DROP TABLE ATAPUtilities.BuildSet;
GO
IF OBJECT_ID(N'ATAPUtilities.RuleSet',                  N'U') IS NOT NULL DROP TABLE ATAPUtilities.RuleSet;
GO
IF OBJECT_ID(N'ATAPUtilities.RulePrimitiveComposition', N'U') IS NOT NULL DROP TABLE ATAPUtilities.RulePrimitiveComposition;
GO
IF OBJECT_ID(N'ATAPUtilities.[Rule]',                   N'U') IS NOT NULL DROP TABLE ATAPUtilities.[Rule];
GO
IF OBJECT_ID(N'ATAPUtilities.RulePrimitiveInput',       N'U') IS NOT NULL DROP TABLE ATAPUtilities.RulePrimitiveInput;
GO
IF OBJECT_ID(N'ATAPUtilities.RulePrimitive',            N'U') IS NOT NULL DROP TABLE ATAPUtilities.RulePrimitive;
GO
IF OBJECT_ID(N'ATAPUtilities.PrimitiveLanguageKind',    N'U') IS NOT NULL DROP TABLE ATAPUtilities.PrimitiveLanguageKind;
GO
IF OBJECT_ID(N'ATAPUtilities.UserSettings',             N'U') IS NOT NULL DROP TABLE ATAPUtilities.UserSettings;
GO
IF OBJECT_ID(N'ATAPUtilities.UserInformation',          N'U') IS NOT NULL DROP TABLE ATAPUtilities.UserInformation;
GO
IF OBJECT_ID(N'ATAPUtilities.[User]',                   N'U') IS NOT NULL DROP TABLE ATAPUtilities.[User];
GO
IF OBJECT_ID(N'ATAPUtilities.PhiloteTimeBlock',         N'U') IS NOT NULL DROP TABLE ATAPUtilities.PhiloteTimeBlock;
GO
IF OBJECT_ID(N'ATAPUtilities.PhiloteAdditionalId',      N'U') IS NOT NULL DROP TABLE ATAPUtilities.PhiloteAdditionalId;
GO
IF OBJECT_ID(N'ATAPUtilities.Philote',                  N'U') IS NOT NULL DROP TABLE ATAPUtilities.Philote;
GO


-- ===========================================================
-- SECTION 3 — ATAPUtilities Core Tables
-- ===========================================================

-- ── 3.1 Philote Foundation ──────────────────────────────────
-- Mirrors GuidPhilote<TId>: Id, AdditionalIds dictionary, TimeBlocks collection.

CREATE TABLE ATAPUtilities.Philote (
    PhiloteId UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_Philote_PhiloteId DEFAULT NEWID(),
    CreatedAt DATETIME2        NOT NULL CONSTRAINT DF_Philote_CreatedAt  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Philote PRIMARY KEY CLUSTERED (PhiloteId)
);
GO

CREATE TABLE ATAPUtilities.PhiloteAdditionalId (
    PhiloteAdditionalIdId INT              NOT NULL IDENTITY(1,1),
    PhiloteId             UNIQUEIDENTIFIER NOT NULL,
    KeyName               NVARCHAR(200)    NOT NULL,
    ValueId               UNIQUEIDENTIFIER NOT NULL,
    CONSTRAINT PK_PhiloteAdditionalId         PRIMARY KEY CLUSTERED (PhiloteAdditionalIdId),
    CONSTRAINT FK_PhiloteAdditionalId_Philote FOREIGN KEY (PhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
    CONSTRAINT UQ_PhiloteAdditionalId_Key     UNIQUE (PhiloteId, KeyName)
);
GO

CREATE TABLE ATAPUtilities.PhiloteTimeBlock (
    PhiloteTimeBlockId INT              NOT NULL IDENTITY(1,1),
    PhiloteId          UNIQUEIDENTIFIER NOT NULL,
    StartAt            DATETIME2        NOT NULL,
    EndAt              DATETIME2            NULL,
    CONSTRAINT PK_PhiloteTimeBlock         PRIMARY KEY CLUSTERED (PhiloteTimeBlockId),
    CONSTRAINT FK_PhiloteTimeBlock_Philote FOREIGN KEY (PhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId)
);
GO

-- ── 3.2 PrimitiveLanguageKind ──────────────────────────────

CREATE TABLE ATAPUtilities.PrimitiveLanguageKind (
    PrimitiveLanguageKindId TINYINT       NOT NULL,
    Name                    NVARCHAR(50)  NOT NULL,
    Description             NVARCHAR(200)     NULL,
    CONSTRAINT PK_PrimitiveLanguageKind      PRIMARY KEY CLUSTERED (PrimitiveLanguageKindId),
    CONSTRAINT UQ_PrimitiveLanguageKind_Name UNIQUE (Name)
);
GO

-- ── 3.3 Rule Primitives ────────────────────────────────────

CREATE TABLE ATAPUtilities.RulePrimitive (
    PhiloteId               UNIQUEIDENTIFIER NOT NULL,
    PrimitiveLanguageKindId TINYINT          NOT NULL,
    Name                    NVARCHAR(200)    NOT NULL,
    Description             NVARCHAR(MAX)        NULL,
    BnfDefinition           NVARCHAR(MAX)        NULL,
    Attribution             NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RulePrimitive               PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT FK_RulePrimitive_Philote       FOREIGN KEY (PhiloteId)               REFERENCES ATAPUtilities.Philote              (PhiloteId),
    CONSTRAINT FK_RulePrimitive_LanguageKind  FOREIGN KEY (PrimitiveLanguageKindId) REFERENCES ATAPUtilities.PrimitiveLanguageKind (PrimitiveLanguageKindId),
    CONSTRAINT UQ_RulePrimitive_Language_Name UNIQUE (PrimitiveLanguageKindId, Name)
);
GO

CREATE TABLE ATAPUtilities.RulePrimitiveInput (
    RulePrimitiveInputId INT              NOT NULL IDENTITY(1,1),
    PhiloteId            UNIQUEIDENTIFIER NOT NULL,
    InputName            NVARCHAR(200)    NOT NULL,
    TypeName             NVARCHAR(200)        NULL,
    Description          NVARCHAR(MAX)        NULL,
    DefaultValue         NVARCHAR(MAX)        NULL,
    IsRequired           BIT              NOT NULL CONSTRAINT DF_RulePrimitiveInput_IsRequired DEFAULT 1,
    CONSTRAINT PK_RulePrimitiveInput           PRIMARY KEY CLUSTERED (RulePrimitiveInputId),
    CONSTRAINT FK_RulePrimitiveInput_Primitive FOREIGN KEY (PhiloteId) REFERENCES ATAPUtilities.RulePrimitive (PhiloteId),
    CONSTRAINT UQ_RulePrimitiveInput_Name      UNIQUE (PhiloteId, InputName)
);
GO

-- ── 3.4 Rule Definitions ───────────────────────────────────

CREATE TABLE ATAPUtilities.[Rule] (
    PhiloteId               UNIQUEIDENTIFIER NOT NULL,
    PrimitiveLanguageKindId TINYINT          NOT NULL,
    Name                    NVARCHAR(200)    NOT NULL,
    Purpose                 NVARCHAR(MAX)        NULL,
    SourceFileReference     NVARCHAR(500)        NULL,
    CONSTRAINT PK_Rule              PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT FK_Rule_Philote      FOREIGN KEY (PhiloteId)               REFERENCES ATAPUtilities.Philote              (PhiloteId),
    CONSTRAINT FK_Rule_LanguageKind FOREIGN KEY (PrimitiveLanguageKindId) REFERENCES ATAPUtilities.PrimitiveLanguageKind (PrimitiveLanguageKindId),
    CONSTRAINT UQ_Rule_Language_Name UNIQUE (PrimitiveLanguageKindId, Name)
);
GO

CREATE TABLE ATAPUtilities.RulePrimitiveComposition (
    RulePrimitiveCompositionId INT              NOT NULL IDENTITY(1,1),
    RulePhiloteId              UNIQUEIDENTIFIER NOT NULL,
    SequenceKey                NVARCHAR(20)     NOT NULL,
    PrimitivePhiloteId         UNIQUEIDENTIFIER NOT NULL,
    BoundInputsJson            NVARCHAR(MAX)        NULL,
    Notes                      NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RulePrimitiveComposition PRIMARY KEY CLUSTERED (RulePrimitiveCompositionId),
    CONSTRAINT FK_RulePC_Rule              FOREIGN KEY (RulePhiloteId)      REFERENCES ATAPUtilities.[Rule]        (PhiloteId),
    CONSTRAINT FK_RulePC_Primitive         FOREIGN KEY (PrimitivePhiloteId) REFERENCES ATAPUtilities.RulePrimitive (PhiloteId),
    CONSTRAINT UQ_RulePC_Rule_Key          UNIQUE (RulePhiloteId, SequenceKey)
);
GO

-- ── 3.5 Rule Sets ──────────────────────────────────────────

CREATE TABLE ATAPUtilities.RuleSet (
    PhiloteId   UNIQUEIDENTIFIER NOT NULL,
    Name        NVARCHAR(200)    NOT NULL,
    Description NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RuleSet         PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT FK_RuleSet_Philote FOREIGN KEY (PhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
    CONSTRAINT UQ_RuleSet_Name    UNIQUE (Name)
);
GO

CREATE TABLE ATAPUtilities.RuleSetMember (
    RuleSetMemberId  INT              NOT NULL IDENTITY(1,1),
    RuleSetPhiloteId UNIQUEIDENTIFIER NOT NULL,
    RulePhiloteId    UNIQUEIDENTIFIER NOT NULL,
    SequenceNumber   INT              NOT NULL,
    Notes            NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RuleSetMember         PRIMARY KEY CLUSTERED (RuleSetMemberId),
    CONSTRAINT FK_RuleSetMember_RuleSet FOREIGN KEY (RuleSetPhiloteId) REFERENCES ATAPUtilities.RuleSet (PhiloteId),
    CONSTRAINT FK_RuleSetMember_Rule    FOREIGN KEY (RulePhiloteId)    REFERENCES ATAPUtilities.[Rule]   (PhiloteId),
    CONSTRAINT UQ_RuleSetMember_Set_Seq UNIQUE (RuleSetPhiloteId, SequenceNumber)
);
GO

-- ── 3.6 Build Sets (from V00.01.000060) ───────────────────

CREATE TABLE ATAPUtilities.BuildSet (
    PhiloteId   UNIQUEIDENTIFIER NOT NULL,
    Name        NVARCHAR(200)    NOT NULL,
    Description NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_BuildSet         PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT FK_BuildSet_Philote FOREIGN KEY (PhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
    CONSTRAINT UQ_BuildSet_Name    UNIQUE (Name)
);
GO

CREATE TABLE ATAPUtilities.BuildSetMember (
    BuildSetMemberId  INT              NOT NULL IDENTITY(1,1),
    BuildSetPhiloteId UNIQUEIDENTIFIER NOT NULL,
    RuleSetPhiloteId  UNIQUEIDENTIFIER NOT NULL,
    SequenceNumber    INT              NOT NULL,
    Notes             NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_BuildSetMember          PRIMARY KEY CLUSTERED (BuildSetMemberId),
    CONSTRAINT FK_BuildSetMember_BuildSet FOREIGN KEY (BuildSetPhiloteId) REFERENCES ATAPUtilities.BuildSet (PhiloteId),
    CONSTRAINT FK_BuildSetMember_RuleSet  FOREIGN KEY (RuleSetPhiloteId)  REFERENCES ATAPUtilities.RuleSet  (PhiloteId),
    CONSTRAINT UQ_BuildSetMember_Set_Seq  UNIQUE (BuildSetPhiloteId, SequenceNumber)
);
GO

-- ── 3.7 Rule Instantiations ────────────────────────────────

CREATE TABLE ATAPUtilities.RuleInstantiation (
    PhiloteId     UNIQUEIDENTIFIER NOT NULL,
    RulePhiloteId UNIQUEIDENTIFIER NOT NULL,
    CreatedAt     DATETIME2        NOT NULL CONSTRAINT DF_RuleInstantiation_CreatedAt DEFAULT SYSUTCDATETIME(),
    Notes         NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RuleInstantiation         PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT FK_RuleInstantiation_Philote FOREIGN KEY (PhiloteId)     REFERENCES ATAPUtilities.Philote (PhiloteId),
    CONSTRAINT FK_RuleInstantiation_Rule    FOREIGN KEY (RulePhiloteId) REFERENCES ATAPUtilities.[Rule]  (PhiloteId)
);
GO

CREATE TABLE ATAPUtilities.RuleInstantiationBinding (
    RuleInstantiationBindingId INT              NOT NULL IDENTITY(1,1),
    InstantiationPhiloteId     UNIQUEIDENTIFIER NOT NULL,
    InputName                  NVARCHAR(200)    NOT NULL,
    InputValue                 NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RuleInstantiationBinding               PRIMARY KEY CLUSTERED (RuleInstantiationBindingId),
    CONSTRAINT FK_RuleInstantiationBinding_Instantiation FOREIGN KEY (InstantiationPhiloteId) REFERENCES ATAPUtilities.RuleInstantiation (PhiloteId),
    CONSTRAINT UQ_RuleInstantiationBinding_Name          UNIQUE (InstantiationPhiloteId, InputName)
);
GO

-- ── 3.8 Users ──────────────────────────────────────────────
-- [User]          : Philote-backed identity + Argon2id PHC password hash +
--                   SHA-256 hex email hash for indexed PII-free lookup.
-- UserInformation : PII stored as VARBINARY ciphertext via ENCRYPTBYPASSPHRASE.
-- UserSettings    : UI preferences (clear text).
-- V00.01.000031 columns (EmailHash, HashAlgorithmName) incorporated inline here;
-- the standalone addendum migration is superseded by this combined script.

CREATE TABLE ATAPUtilities.[User] (
    PhiloteId               UNIQUEIDENTIFIER NOT NULL,
    UserId                  UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_User_UserId DEFAULT NEWID(),
    SaltedAndHashedPassword NVARCHAR(500)        NULL,
    EmailHash               CHAR(64)             NULL,
    HashAlgorithmName       NVARCHAR(50)     NOT NULL CONSTRAINT DF_User_HashAlgorithmName DEFAULT N'Argon2id',
    CONSTRAINT PK_User         PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT FK_User_Philote FOREIGN KEY (PhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
    CONSTRAINT UQ_User_UserId  UNIQUE (UserId)
);
GO

CREATE INDEX IX_User_EmailHash ON ATAPUtilities.[User] (EmailHash);
GO

CREATE TABLE ATAPUtilities.UserInformation (
    UserId               UNIQUEIDENTIFIER NOT NULL,
    FirstName            VARBINARY(MAX)       NULL,
    LastName             VARBINARY(MAX)       NULL,
    Email                VARBINARY(MAX)       NULL,
    Phone                VARBINARY(MAX)       NULL,
    Role                 VARBINARY(MAX)       NULL,
    EncryptionKeyVersion TINYINT          NOT NULL CONSTRAINT DF_UserInformation_EncryptionKeyVersion DEFAULT 1,
    CONSTRAINT PK_UserInformation         PRIMARY KEY CLUSTERED (UserId),
    CONSTRAINT FK_UserInformation_User    FOREIGN KEY (UserId) REFERENCES ATAPUtilities.[User] (UserId),
    CONSTRAINT CK_UserInformation_Contact CHECK (
        (Email IS NOT NULL OR Phone IS NOT NULL)
        AND NOT (Email IS NOT NULL AND Phone IS NOT NULL)
    )
);
GO

CREATE TABLE ATAPUtilities.UserSettings (
    UserId         UNIQUEIDENTIFIER NOT NULL,
    PreferredTheme NVARCHAR(200)        NULL,
    IsDarkMode     BIT              NOT NULL CONSTRAINT DF_UserSettings_IsDarkMode DEFAULT 0,
    Language       NVARCHAR(200)        NULL,
    CONSTRAINT PK_UserSettings      PRIMARY KEY CLUSTERED (UserId),
    CONSTRAINT FK_UserSettings_User FOREIGN KEY (UserId) REFERENCES ATAPUtilities.[User] (UserId)
);
GO


-- ===========================================================
-- SECTION 4 — AceCommander Tables
-- ===========================================================

-- ── 4.1 Philote ────────────────────────────────────────────

CREATE TABLE AceCommander.Philote (
    PhiloteId UNIQUEIDENTIFIER NOT NULL CONSTRAINT AC_DF_Philote_PhiloteId DEFAULT NEWID(),
    CreatedAt DATETIME2        NOT NULL CONSTRAINT AC_DF_Philote_CreatedAt  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT AC_PK_Philote PRIMARY KEY CLUSTERED (PhiloteId)
);
GO

CREATE TABLE AceCommander.PhiloteAdditionalId (
    PhiloteAdditionalIdId INT              NOT NULL IDENTITY(1,1),
    PhiloteId             UNIQUEIDENTIFIER NOT NULL,
    KeyName               NVARCHAR(200)    NOT NULL,
    ValueId               UNIQUEIDENTIFIER NOT NULL,
    CONSTRAINT AC_PK_PhiloteAdditionalId         PRIMARY KEY CLUSTERED (PhiloteAdditionalIdId),
    CONSTRAINT AC_FK_PhiloteAdditionalId_Philote FOREIGN KEY (PhiloteId) REFERENCES AceCommander.Philote (PhiloteId),
    CONSTRAINT AC_UQ_PhiloteAdditionalId_Key     UNIQUE (PhiloteId, KeyName)
);
GO

CREATE TABLE AceCommander.PhiloteTimeBlock (
    PhiloteTimeBlockId INT              NOT NULL IDENTITY(1,1),
    PhiloteId          UNIQUEIDENTIFIER NOT NULL,
    StartAt            DATETIME2        NOT NULL,
    EndAt              DATETIME2            NULL,
    CONSTRAINT AC_PK_PhiloteTimeBlock         PRIMARY KEY CLUSTERED (PhiloteTimeBlockId),
    CONSTRAINT AC_FK_PhiloteTimeBlock_Philote FOREIGN KEY (PhiloteId) REFERENCES AceCommander.Philote (PhiloteId)
);
GO

-- ── 4.2 PrimitiveLanguageKind ─────────────────────────────

CREATE TABLE AceCommander.PrimitiveLanguageKind (
    PrimitiveLanguageKindId TINYINT       NOT NULL,
    Name                    NVARCHAR(50)  NOT NULL,
    Description             NVARCHAR(200)     NULL,
    CONSTRAINT AC_PK_PrimitiveLanguageKind      PRIMARY KEY CLUSTERED (PrimitiveLanguageKindId),
    CONSTRAINT AC_UQ_PrimitiveLanguageKind_Name UNIQUE (Name)
);
GO

-- ── 4.3 Rule Primitives ────────────────────────────────────

CREATE TABLE AceCommander.RulePrimitive (
    PhiloteId               UNIQUEIDENTIFIER NOT NULL,
    PrimitiveLanguageKindId TINYINT          NOT NULL,
    Name                    NVARCHAR(200)    NOT NULL,
    Description             NVARCHAR(MAX)        NULL,
    BnfDefinition           NVARCHAR(MAX)        NULL,
    Attribution             NVARCHAR(MAX)        NULL,
    CONSTRAINT AC_PK_RulePrimitive               PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT AC_FK_RulePrimitive_Philote       FOREIGN KEY (PhiloteId)               REFERENCES AceCommander.Philote              (PhiloteId),
    CONSTRAINT AC_FK_RulePrimitive_LanguageKind  FOREIGN KEY (PrimitiveLanguageKindId) REFERENCES AceCommander.PrimitiveLanguageKind (PrimitiveLanguageKindId),
    CONSTRAINT AC_UQ_RulePrimitive_Language_Name UNIQUE (PrimitiveLanguageKindId, Name)
);
GO

CREATE TABLE AceCommander.RulePrimitiveInput (
    RulePrimitiveInputId INT              NOT NULL IDENTITY(1,1),
    PhiloteId            UNIQUEIDENTIFIER NOT NULL,
    InputName            NVARCHAR(200)    NOT NULL,
    TypeName             NVARCHAR(200)        NULL,
    Description          NVARCHAR(MAX)        NULL,
    DefaultValue         NVARCHAR(MAX)        NULL,
    IsRequired           BIT              NOT NULL CONSTRAINT AC_DF_RulePrimitiveInput_IsRequired DEFAULT 1,
    CONSTRAINT AC_PK_RulePrimitiveInput           PRIMARY KEY CLUSTERED (RulePrimitiveInputId),
    CONSTRAINT AC_FK_RulePrimitiveInput_Primitive FOREIGN KEY (PhiloteId) REFERENCES AceCommander.RulePrimitive (PhiloteId),
    CONSTRAINT AC_UQ_RulePrimitiveInput_Name      UNIQUE (PhiloteId, InputName)
);
GO

-- ── 4.4 Rule Definitions ───────────────────────────────────

CREATE TABLE AceCommander.[Rule] (
    PhiloteId               UNIQUEIDENTIFIER NOT NULL,
    PrimitiveLanguageKindId TINYINT          NOT NULL,
    Name                    NVARCHAR(200)    NOT NULL,
    Purpose                 NVARCHAR(MAX)        NULL,
    SourceFileReference     NVARCHAR(500)        NULL,
    CONSTRAINT AC_PK_Rule               PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT AC_FK_Rule_Philote       FOREIGN KEY (PhiloteId)               REFERENCES AceCommander.Philote              (PhiloteId),
    CONSTRAINT AC_FK_Rule_LanguageKind  FOREIGN KEY (PrimitiveLanguageKindId) REFERENCES AceCommander.PrimitiveLanguageKind (PrimitiveLanguageKindId),
    CONSTRAINT AC_UQ_Rule_Language_Name UNIQUE (PrimitiveLanguageKindId, Name)
);
GO

CREATE TABLE AceCommander.RulePrimitiveComposition (
    RulePrimitiveCompositionId INT              NOT NULL IDENTITY(1,1),
    RulePhiloteId              UNIQUEIDENTIFIER NOT NULL,
    SequenceKey                NVARCHAR(20)     NOT NULL,
    PrimitivePhiloteId         UNIQUEIDENTIFIER NOT NULL,
    BoundInputsJson            NVARCHAR(MAX)        NULL,
    Notes                      NVARCHAR(MAX)        NULL,
    CONSTRAINT AC_PK_RulePrimitiveComposition PRIMARY KEY CLUSTERED (RulePrimitiveCompositionId),
    CONSTRAINT AC_FK_RulePC_Rule              FOREIGN KEY (RulePhiloteId)      REFERENCES AceCommander.[Rule]        (PhiloteId),
    CONSTRAINT AC_FK_RulePC_Primitive         FOREIGN KEY (PrimitivePhiloteId) REFERENCES AceCommander.RulePrimitive (PhiloteId),
    CONSTRAINT AC_UQ_RulePC_Rule_Key          UNIQUE (RulePhiloteId, SequenceKey)
);
GO

-- ── 4.5 Rule Sets ──────────────────────────────────────────

CREATE TABLE AceCommander.RuleSet (
    PhiloteId   UNIQUEIDENTIFIER NOT NULL,
    Name        NVARCHAR(200)    NOT NULL,
    Description NVARCHAR(MAX)        NULL,
    CONSTRAINT AC_PK_RuleSet         PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT AC_FK_RuleSet_Philote FOREIGN KEY (PhiloteId) REFERENCES AceCommander.Philote (PhiloteId),
    CONSTRAINT AC_UQ_RuleSet_Name    UNIQUE (Name)
);
GO

CREATE TABLE AceCommander.RuleSetMember (
    RuleSetMemberId  INT              NOT NULL IDENTITY(1,1),
    RuleSetPhiloteId UNIQUEIDENTIFIER NOT NULL,
    RulePhiloteId    UNIQUEIDENTIFIER NOT NULL,
    SequenceNumber   INT              NOT NULL,
    Notes            NVARCHAR(MAX)        NULL,
    CONSTRAINT AC_PK_RuleSetMember         PRIMARY KEY CLUSTERED (RuleSetMemberId),
    CONSTRAINT AC_FK_RuleSetMember_RuleSet FOREIGN KEY (RuleSetPhiloteId) REFERENCES AceCommander.RuleSet (PhiloteId),
    CONSTRAINT AC_FK_RuleSetMember_Rule    FOREIGN KEY (RulePhiloteId)    REFERENCES AceCommander.[Rule]   (PhiloteId),
    CONSTRAINT AC_UQ_RuleSetMember_Set_Seq UNIQUE (RuleSetPhiloteId, SequenceNumber)
);
GO

-- ── 4.6 Rule Instantiations ────────────────────────────────

CREATE TABLE AceCommander.RuleInstantiation (
    PhiloteId     UNIQUEIDENTIFIER NOT NULL,
    RulePhiloteId UNIQUEIDENTIFIER NOT NULL,
    CreatedAt     DATETIME2        NOT NULL CONSTRAINT AC_DF_RuleInstantiation_CreatedAt DEFAULT SYSUTCDATETIME(),
    Notes         NVARCHAR(MAX)        NULL,
    CONSTRAINT AC_PK_RuleInstantiation         PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT AC_FK_RuleInstantiation_Philote FOREIGN KEY (PhiloteId)     REFERENCES AceCommander.Philote (PhiloteId),
    CONSTRAINT AC_FK_RuleInstantiation_Rule    FOREIGN KEY (RulePhiloteId) REFERENCES AceCommander.[Rule]  (PhiloteId)
);
GO

CREATE TABLE AceCommander.RuleInstantiationBinding (
    RuleInstantiationBindingId INT              NOT NULL IDENTITY(1,1),
    InstantiationPhiloteId     UNIQUEIDENTIFIER NOT NULL,
    InputName                  NVARCHAR(200)    NOT NULL,
    InputValue                 NVARCHAR(MAX)        NULL,
    CONSTRAINT AC_PK_RuleInstantiationBinding               PRIMARY KEY CLUSTERED (RuleInstantiationBindingId),
    CONSTRAINT AC_FK_RuleInstantiationBinding_Instantiation FOREIGN KEY (InstantiationPhiloteId) REFERENCES AceCommander.RuleInstantiation (PhiloteId),
    CONSTRAINT AC_UQ_RuleInstantiationBinding_Name          UNIQUE (InstantiationPhiloteId, InputName)
);
GO

-- ── 4.7 Users ──────────────────────────────────────────────

CREATE TABLE AceCommander.[User] (
    PhiloteId               UNIQUEIDENTIFIER NOT NULL,
    UserId                  UNIQUEIDENTIFIER NOT NULL CONSTRAINT AC_DF_User_UserId DEFAULT NEWID(),
    SaltedAndHashedPassword NVARCHAR(500)        NULL,
    EmailHash               CHAR(64)             NULL,
    HashAlgorithmName       NVARCHAR(50)     NOT NULL CONSTRAINT AC_DF_User_HashAlgorithmName DEFAULT N'Argon2id',
    CONSTRAINT AC_PK_User         PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT AC_FK_User_Philote FOREIGN KEY (PhiloteId) REFERENCES AceCommander.Philote (PhiloteId),
    CONSTRAINT AC_UQ_User_UserId  UNIQUE (UserId)
);
GO

CREATE INDEX AC_IX_User_EmailHash ON AceCommander.[User] (EmailHash);
GO

CREATE TABLE AceCommander.UserInformation (
    UserId               UNIQUEIDENTIFIER NOT NULL,
    FirstName            VARBINARY(MAX)       NULL,
    LastName             VARBINARY(MAX)       NULL,
    Email                VARBINARY(MAX)       NULL,
    Phone                VARBINARY(MAX)       NULL,
    Role                 VARBINARY(MAX)       NULL,
    EncryptionKeyVersion TINYINT          NOT NULL CONSTRAINT AC_DF_UserInformation_EncryptionKeyVersion DEFAULT 1,
    CONSTRAINT AC_PK_UserInformation         PRIMARY KEY CLUSTERED (UserId),
    CONSTRAINT AC_FK_UserInformation_User    FOREIGN KEY (UserId) REFERENCES AceCommander.[User] (UserId),
    CONSTRAINT AC_CK_UserInformation_Contact CHECK (
        (Email IS NOT NULL OR Phone IS NOT NULL)
        AND NOT (Email IS NOT NULL AND Phone IS NOT NULL)
    )
);
GO

CREATE TABLE AceCommander.UserSettings (
    UserId         UNIQUEIDENTIFIER NOT NULL,
    PreferredTheme NVARCHAR(200)        NULL,
    IsDarkMode     BIT              NOT NULL CONSTRAINT AC_DF_UserSettings_IsDarkMode DEFAULT 0,
    Language       NVARCHAR(200)        NULL,
    CONSTRAINT AC_PK_UserSettings      PRIMARY KEY CLUSTERED (UserId),
    CONSTRAINT AC_FK_UserSettings_User FOREIGN KEY (UserId) REFERENCES AceCommander.[User] (UserId)
);
GO

-- ── 4.8 ScheduledTask / ScheduledTaskRun ──────────────────
-- Source: V00.02.000010 (structure) + V00.02.000030 (LastRun* columns, relaxed CHECK)
-- LastRunUtc / LastRunStatus / LastExitCode and the relaxed schedule CHECK are
-- incorporated inline so no ALTER TABLE pass is needed on a fresh deploy.

CREATE TABLE AceCommander.ScheduledTask (
    Id              INT              NOT NULL IDENTITY(1,1),
    UserId          UNIQUEIDENTIFIER NOT NULL,
    [Name]          NVARCHAR(256)    NOT NULL,
    NextRunUtc      DATETIME2(7)         NULL,
    RepeatSchedule  NVARCHAR(256)        NULL,
    RunAs           NVARCHAR(128)        NULL,
    WithProfile     BIT              NOT NULL CONSTRAINT DF_AceCommander_ScheduledTask_WithProfile  DEFAULT (0),
    ScriptToRunPath NVARCHAR(1024)   NOT NULL,
    ExecutionMode   NVARCHAR(20)     NOT NULL,
    IsEnabled       BIT              NOT NULL CONSTRAINT DF_AceCommander_ScheduledTask_IsEnabled   DEFAULT (1),
    CreatedUtc      DATETIME2(7)     NOT NULL CONSTRAINT DF_AceCommander_ScheduledTask_CreatedUtc  DEFAULT (SYSUTCDATETIME()),
    ModifiedUtc     DATETIME2(7)     NOT NULL CONSTRAINT DF_AceCommander_ScheduledTask_ModifiedUtc DEFAULT (SYSUTCDATETIME()),
    LastRunUtc      DATETIME2(7)         NULL,
    LastRunStatus   NVARCHAR(20)         NULL,
    LastExitCode    INT                  NULL,
    CONSTRAINT PK_AceCommander_ScheduledTask             PRIMARY KEY CLUSTERED (Id ASC),
    CONSTRAINT FK_AceCommander_ScheduledTask_User        FOREIGN KEY (UserId)
        REFERENCES AceCommander.[User] (UserId),
    CONSTRAINT CK_AceCommander_ScheduledTask_ExecutionMode CHECK
        (ExecutionMode IN (N'AddToSystem', N'RunFromAce')),
    CONSTRAINT CK_AceCommander_ScheduledTask_LastRunStatus CHECK
        (LastRunStatus IS NULL
         OR LastRunStatus IN (N'Running', N'Succeeded', N'Failed', N'Cancelled')),
    -- Relaxed from V00.02.000030: completed one-shots have NextRunUtc=NULL,
    -- RepeatSchedule=NULL, but LastRunUtc set — the new predicate accepts that.
    CONSTRAINT CK_AceCommander_ScheduledTask_Schedule CHECK
        (NextRunUtc IS NOT NULL
         OR NULLIF(LTRIM(RTRIM(RepeatSchedule)), N'') IS NOT NULL
         OR LastRunUtc IS NOT NULL)
);
GO

CREATE INDEX IX_AceCommander_ScheduledTask_UserId
    ON AceCommander.ScheduledTask (UserId);
GO

CREATE INDEX IX_AceCommander_ScheduledTask_Due
    ON AceCommander.ScheduledTask (IsEnabled, ExecutionMode, NextRunUtc)
    INCLUDE ([Name], RepeatSchedule, ScriptToRunPath, WithProfile);
GO

CREATE INDEX IX_AceCommander_ScheduledTask_LastRunUtc
    ON AceCommander.ScheduledTask (LastRunUtc DESC)
    INCLUDE ([Name], LastRunStatus, LastExitCode);
GO

CREATE TABLE AceCommander.ScheduledTaskRun (
    Id              BIGINT           NOT NULL IDENTITY(1,1),
    ScheduledTaskId INT              NOT NULL,
    StartedUtc      DATETIME2(7)     NOT NULL CONSTRAINT DF_AceCommander_ScheduledTaskRun_StartedUtc DEFAULT (SYSUTCDATETIME()),
    CompletedUtc    DATETIME2(7)         NULL,
    ExitCode        INT                  NULL,
    [Status]        NVARCHAR(20)     NOT NULL,
    OutputSummary   NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_AceCommander_ScheduledTaskRun              PRIMARY KEY CLUSTERED (Id ASC),
    CONSTRAINT FK_AceCommander_ScheduledTaskRun_ScheduledTask FOREIGN KEY (ScheduledTaskId)
        REFERENCES AceCommander.ScheduledTask (Id)
        ON DELETE CASCADE,
    CONSTRAINT CK_AceCommander_ScheduledTaskRun_Status CHECK
        ([Status] IN (N'Running', N'Succeeded', N'Failed', N'Cancelled'))
);
GO

CREATE INDEX IX_AceCommander_ScheduledTaskRun_ScheduledTaskId_StartedUtc
    ON AceCommander.ScheduledTaskRun (ScheduledTaskId, StartedUtc DESC)
    INCLUDE ([Status], CompletedUtc, ExitCode);
GO

-- ── 4.9 UserDesignerSettings ───────────────────────────────
-- TODO: V00.01.000080 source file is corrupt — all column names are stripped.
--       The file header confirms AceCommander.UserDesignerSettings with an
--       INT IDENTITY PK, a UserId FK to AceCommander.[User], a NVARCHAR(40)
--       name column, two nullable columns, a NVARCHAR(64) value column, three
--       INT columns (defaults 0 / 0 / 100), a variable-length NVARCHAR, a
--       DATETIME2 audit column, and a three-column UNIQUE constraint.
--       Provide the correct column definitions to complete this table.


-- ===========================================================
-- SECTION 5 — Tags Schema Tables
-- ===========================================================

CREATE TABLE Tags.Tags (
    TagID        INT           NOT NULL IDENTITY(1,1),
    ParentTagID  INT               NULL,
    ResourceKey  VARCHAR(100)  NOT NULL,
    DefaultLabel NVARCHAR(256)     NULL,
    IsActive     BIT           NOT NULL CONSTRAINT DF_Tags_Tags_IsActive     DEFAULT (1),
    SortOrder    INT           NOT NULL CONSTRAINT DF_Tags_Tags_SortOrder    DEFAULT (0),
    CreatedDate  DATETIME2(7)  NOT NULL CONSTRAINT DF_Tags_Tags_CreatedDate  DEFAULT (SYSUTCDATETIME()),
    ModifiedDate DATETIME2(7)  NOT NULL CONSTRAINT DF_Tags_Tags_ModifiedDate DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Tags_Tags             PRIMARY KEY CLUSTERED (TagID),
    CONSTRAINT UQ_Tags_Tags_ResourceKey UNIQUE NONCLUSTERED (ResourceKey),
    CONSTRAINT FK_Tags_Tags_ParentTag   FOREIGN KEY (ParentTagID)
        REFERENCES Tags.Tags (TagID)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION
);
GO

CREATE NONCLUSTERED INDEX IX_Tags_Tags_ParentTagID
    ON Tags.Tags (ParentTagID)
    INCLUDE (ResourceKey, IsActive, SortOrder);
GO

CREATE NONCLUSTERED INDEX IX_Tags_Tags_IsActive
    ON Tags.Tags (IsActive)
    WHERE IsActive = 1;
GO

CREATE TABLE Tags.TagAliases (
    AliasID          INT           NOT NULL IDENTITY(1,1),
    TagID            INT           NOT NULL,
    AliasResourceKey VARCHAR(100)  NOT NULL,
    AliasType        VARCHAR(50)   NOT NULL CONSTRAINT DF_Tags_TagAliases_Type        DEFAULT ('Synonym'),
    IsActive         BIT           NOT NULL CONSTRAINT DF_Tags_TagAliases_IsActive    DEFAULT (1),
    CreatedDate      DATETIME2(7)  NOT NULL CONSTRAINT DF_Tags_TagAliases_CreatedDate DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Tags_TagAliases             PRIMARY KEY CLUSTERED (AliasID),
    CONSTRAINT UQ_Tags_TagAliases_ResourceKey UNIQUE NONCLUSTERED (AliasResourceKey),
    CONSTRAINT FK_Tags_TagAliases_Tag         FOREIGN KEY (TagID)
        REFERENCES Tags.Tags (TagID)
        ON DELETE CASCADE
);
GO

CREATE NONCLUSTERED INDEX IX_Tags_TagAliases_TagID
    ON Tags.TagAliases (TagID);
GO

CREATE TABLE Tags.RelationshipTypes (
    RelationshipTypeID     INT           NOT NULL IDENTITY(1,1),
    ResourceKey            VARCHAR(100)  NOT NULL,
    IsBidirectionalDefault BIT           NOT NULL CONSTRAINT DF_Tags_RelType_Bidirectional DEFAULT (0),
    InverseTypeKey         VARCHAR(100)      NULL,
    DefaultDescription     NVARCHAR(256)     NULL,
    IsActive               BIT           NOT NULL CONSTRAINT DF_Tags_RelType_IsActive    DEFAULT (1),
    SortOrder              INT           NOT NULL CONSTRAINT DF_Tags_RelType_SortOrder   DEFAULT (0),
    CreatedDate            DATETIME2(7)  NOT NULL CONSTRAINT DF_Tags_RelType_CreatedDate DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Tags_RelationshipTypes             PRIMARY KEY CLUSTERED (RelationshipTypeID),
    CONSTRAINT UQ_Tags_RelationshipTypes_ResourceKey UNIQUE NONCLUSTERED (ResourceKey)
);
GO

CREATE TABLE Tags.TagRelationships (
    RelationshipID      INT           NOT NULL IDENTITY(1,1),
    SourceTagID         INT           NOT NULL,
    TargetTagID         INT           NOT NULL,
    RelationshipTypeKey VARCHAR(100)  NOT NULL,
    IsBidirectional     BIT           NOT NULL CONSTRAINT DF_Tags_TagRel_Bidirectional DEFAULT (0),
    Weight              DECIMAL(5,2)  NOT NULL CONSTRAINT DF_Tags_TagRel_Weight        DEFAULT (1.0),
    IsActive            BIT           NOT NULL CONSTRAINT DF_Tags_TagRel_IsActive      DEFAULT (1),
    CreatedDate         DATETIME2(7)  NOT NULL CONSTRAINT DF_Tags_TagRel_CreatedDate   DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Tags_TagRelationships PRIMARY KEY CLUSTERED (RelationshipID),
    CONSTRAINT UQ_Tags_TagRelationships UNIQUE NONCLUSTERED (SourceTagID, TargetTagID, RelationshipTypeKey),
    CONSTRAINT FK_Tags_TagRel_SourceTag FOREIGN KEY (SourceTagID) REFERENCES Tags.Tags (TagID) ON DELETE NO ACTION,
    CONSTRAINT FK_Tags_TagRel_TargetTag FOREIGN KEY (TargetTagID) REFERENCES Tags.Tags (TagID) ON DELETE NO ACTION,
    CONSTRAINT CK_Tags_TagRel_NoSelfRef CHECK (SourceTagID <> TargetTagID)
);
GO

CREATE NONCLUSTERED INDEX IX_Tags_TagRel_SourceTag
    ON Tags.TagRelationships (SourceTagID)
    INCLUDE (TargetTagID, RelationshipTypeKey);
GO

CREATE NONCLUSTERED INDEX IX_Tags_TagRel_TargetTag
    ON Tags.TagRelationships (TargetTagID)
    INCLUDE (SourceTagID, RelationshipTypeKey);
GO


-- ===========================================================
-- SECTION 6 — Gmail Schema Table
-- ===========================================================

CREATE TABLE Gmail.gmailMessages (
    ID          INT            NOT NULL IDENTITY(1,1),
    [Subject]   NVARCHAR(400)      NULL,
    MessageId   NVARCHAR(400)      NULL,
    FromAddress NVARCHAR(400)      NULL,
    ToAddress   NVARCHAR(400)      NULL,
    [Date]      DATETIME2(7)       NULL,
    Labels      NVARCHAR(1000)     NULL,
    Body        NVARCHAR(MAX)      NULL,
    [URL]       NVARCHAR(2000)     NULL,
    CONSTRAINT PK_Gmail_gmailMessages PRIMARY KEY CLUSTERED (ID)
);
GO


-- ===========================================================
-- SECTION 7 — Seed Data
-- ===========================================================

-- ── 7.1 ATAPUtilities.PrimitiveLanguageKind ───────────────

INSERT INTO ATAPUtilities.PrimitiveLanguageKind (PrimitiveLanguageKindId, Name, Description)
VALUES
    (1, N'CSharp',     N'C# source language primitives and rules'),
    (2, N'Powershell', N'PowerShell script language primitives and rules'),
    (3, N'SQL',        N'T-SQL / SQL Server script primitives and rules'),
    (4, N'MSBuild',    N'MSBuild .csproj XML primitives and rules'),
    (5, N'Snippet',    N'VS Code snippet primitives and rules for code templates'),
    (6, N'Path',       N'Windows filesystem path primitives following EBNF grammar for UNC, absolute, relative, and extended-length paths with validation rules');
GO

-- ── 7.2 Tags.RelationshipTypes and Tags.Tags hierarchy ────

BEGIN TRANSACTION;

INSERT INTO Tags.RelationshipTypes (ResourceKey, IsBidirectionalDefault, InverseTypeKey, DefaultDescription, IsActive, SortOrder) VALUES
    (N'REL_RELATED_TO',    1, NULL,                 N'General relationship between tags',  1,  10),
    (N'REL_SEE_ALSO',      1, NULL,                 N'Suggested alternative tags',         1,  20),
    (N'REL_SYNONYM_OF',    1, NULL,                 N'Tags that mean the same thing',      1,  30),
    (N'REL_BROADER_THAN',  0, N'REL_NARROWER_THAN', N'Parent-like semantic relationship',  1,  40),
    (N'REL_NARROWER_THAN', 0, N'REL_BROADER_THAN',  N'Child-like semantic relationship',   1,  50),
    (N'REL_OPPOSITE_OF',   1, NULL,                 N'Antonym relationship',               1,  60),
    (N'REL_REPLACES',      0, N'REL_REPLACED_BY',   N'Tag supersedes another',             1,  70),
    (N'REL_REPLACED_BY',   0, N'REL_REPLACES',      N'Tag was superseded',                 1,  80),
    (N'REL_PART_OF',       0, N'REL_HAS_PART',      N'Component relationship',             1,  90),
    (N'REL_HAS_PART',      0, N'REL_PART_OF',       N'Contains component',                 1, 100);

-- Root tags
INSERT INTO Tags.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder) VALUES
    (NULL, N'TAG_ELECTRONICS', N'Electronics', 1, 100),
    (NULL, N'TAG_DOCUMENTS',   N'Documents',   1, 200),
    (NULL, N'TAG_MEDIA',       N'Media',       1, 300),
    (NULL, N'TAG_PROJECTS',    N'Projects',    1, 400),
    (NULL, N'TAG_REFERENCES',  N'References',  1, 500),
    (NULL, N'TAG_PERSONAL',    N'Personal',    1, 600);

-- Children of TAG_ELECTRONICS
INSERT INTO Tags.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder)
SELECT t.TagID, v.ResourceKey, v.DefaultLabel, 1, v.SortOrder
FROM Tags.Tags t
CROSS APPLY (VALUES
    (N'TAG_ELECTRONICS_COMPUTERS',   N'Computers',   10),
    (N'TAG_ELECTRONICS_PHONES',      N'Phones',      20),
    (N'TAG_ELECTRONICS_TABLETS',     N'Tablets',     30),
    (N'TAG_ELECTRONICS_PERIPHERALS', N'Peripherals', 40),
    (N'TAG_ELECTRONICS_NETWORKING',  N'Networking',  50)
) AS v (ResourceKey, DefaultLabel, SortOrder)
WHERE t.ResourceKey = N'TAG_ELECTRONICS';

-- Children of TAG_ELECTRONICS_COMPUTERS
INSERT INTO Tags.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder)
SELECT t.TagID, v.ResourceKey, v.DefaultLabel, 1, v.SortOrder
FROM Tags.Tags t
CROSS APPLY (VALUES
    (N'TAG_COMPUTERS_DESKTOPS',   N'Desktops',   10),
    (N'TAG_COMPUTERS_LAPTOPS',    N'Laptops',    20),
    (N'TAG_COMPUTERS_SERVERS',    N'Servers',    30),
    (N'TAG_COMPUTERS_COMPONENTS', N'Components', 40)
) AS v (ResourceKey, DefaultLabel, SortOrder)
WHERE t.ResourceKey = N'TAG_ELECTRONICS_COMPUTERS';

-- Children of TAG_DOCUMENTS
INSERT INTO Tags.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder)
SELECT t.TagID, v.ResourceKey, v.DefaultLabel, 1, v.SortOrder
FROM Tags.Tags t
CROSS APPLY (VALUES
    (N'TAG_DOCUMENTS_REPORTS',        N'Reports',        10),
    (N'TAG_DOCUMENTS_MANUALS',        N'Manuals',        20),
    (N'TAG_DOCUMENTS_SPECIFICATIONS', N'Specifications', 30),
    (N'TAG_DOCUMENTS_CONTRACTS',      N'Contracts',      40),
    (N'TAG_DOCUMENTS_CORRESPONDENCE', N'Correspondence', 50)
) AS v (ResourceKey, DefaultLabel, SortOrder)
WHERE t.ResourceKey = N'TAG_DOCUMENTS';

-- Children of TAG_MEDIA
INSERT INTO Tags.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder)
SELECT t.TagID, v.ResourceKey, v.DefaultLabel, 1, v.SortOrder
FROM Tags.Tags t
CROSS APPLY (VALUES
    (N'TAG_MEDIA_IMAGES', N'Images',  10),
    (N'TAG_MEDIA_VIDEO',  N'Video',   20),
    (N'TAG_MEDIA_AUDIO',  N'Audio',   30),
    (N'TAG_MEDIA_EBOOKS', N'E-Books', 40)
) AS v (ResourceKey, DefaultLabel, SortOrder)
WHERE t.ResourceKey = N'TAG_MEDIA';

-- Children of TAG_PROJECTS
INSERT INTO Tags.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder)
SELECT t.TagID, v.ResourceKey, v.DefaultLabel, 1, v.SortOrder
FROM Tags.Tags t
CROSS APPLY (VALUES
    (N'TAG_PROJECTS_ACTIVE',    N'Active',    10),
    (N'TAG_PROJECTS_COMPLETED', N'Completed', 20),
    (N'TAG_PROJECTS_ARCHIVED',  N'Archived',  30),
    (N'TAG_PROJECTS_TEMPLATES', N'Templates', 40)
) AS v (ResourceKey, DefaultLabel, SortOrder)
WHERE t.ResourceKey = N'TAG_PROJECTS';

-- Children of TAG_REFERENCES
INSERT INTO Tags.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder)
SELECT t.TagID, v.ResourceKey, v.DefaultLabel, 1, v.SortOrder
FROM Tags.Tags t
CROSS APPLY (VALUES
    (N'TAG_REFERENCES_TUTORIALS',     N'Tutorials',     10),
    (N'TAG_REFERENCES_DOCUMENTATION', N'Documentation', 20),
    (N'TAG_REFERENCES_SAMPLES',       N'Samples',       30),
    (N'TAG_REFERENCES_BOOKMARKS',     N'Bookmarks',     40)
) AS v (ResourceKey, DefaultLabel, SortOrder)
WHERE t.ResourceKey = N'TAG_REFERENCES';

-- Children of TAG_PERSONAL
INSERT INTO Tags.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder)
SELECT t.TagID, v.ResourceKey, v.DefaultLabel, 1, v.SortOrder
FROM Tags.Tags t
CROSS APPLY (VALUES
    (N'TAG_PERSONAL_FAVORITES', N'Favorites', 10),
    (N'TAG_PERSONAL_TODO',      N'To Do',     20),
    (N'TAG_PERSONAL_ARCHIVE',   N'Archive',   30)
) AS v (ResourceKey, DefaultLabel, SortOrder)
WHERE t.ResourceKey = N'TAG_PERSONAL';

COMMIT TRANSACTION;
GO


-- ===========================================================
-- SECTION 8 — Stored Procedures
-- ===========================================================

-- ── 8.1 ATAPUtilities.usp_GetDecryptedUserInformation ─────

CREATE OR ALTER PROCEDURE ATAPUtilities.usp_GetDecryptedUserInformation
    @UserId     UNIQUEIDENTIFIER,
    @Passphrase NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        UserId,
        CAST(DECRYPTBYPASSPHRASE(@Passphrase, FirstName) AS NVARCHAR(200)) AS FirstName,
        CAST(DECRYPTBYPASSPHRASE(@Passphrase, LastName)  AS NVARCHAR(200)) AS LastName,
        CAST(DECRYPTBYPASSPHRASE(@Passphrase, Email)     AS NVARCHAR(500)) AS Email,
        CAST(DECRYPTBYPASSPHRASE(@Passphrase, Phone)     AS NVARCHAR(50))  AS Phone,
        CAST(DECRYPTBYPASSPHRASE(@Passphrase, Role)      AS NVARCHAR(200)) AS Role,
        EncryptionKeyVersion
    FROM ATAPUtilities.UserInformation
    WHERE UserId = @UserId;
END;
GO

-- ── 8.2 Tags hierarchy traversal ──────────────────────────

EXEC (N'
CREATE OR ALTER PROCEDURE Tags.usp_GetTagTree
    @RootTagID  INT = NULL,
    @MaxDepth   INT = 100,
    @ActiveOnly BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH TagTree AS (
        SELECT
            TagID, ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder,
            0 AS [Level],
            CAST(RIGHT(''0000000000'' + CAST(SortOrder AS VARCHAR(10)), 10) + ''/'' + CAST(TagID AS VARCHAR(10)) AS VARCHAR(MAX)) AS TreePath
        FROM Tags.Tags
        WHERE (@RootTagID IS NULL AND ParentTagID IS NULL)
           OR (@RootTagID IS NOT NULL AND TagID = @RootTagID)

        UNION ALL

        SELECT
            t.TagID, t.ParentTagID, t.ResourceKey, t.DefaultLabel, t.IsActive, t.SortOrder,
            tt.[Level] + 1,
            tt.TreePath + ''/'' + RIGHT(''0000000000'' + CAST(t.SortOrder AS VARCHAR(10)), 10) + ''/'' + CAST(t.TagID AS VARCHAR(10))
        FROM Tags.Tags t
        INNER JOIN TagTree tt ON t.ParentTagID = tt.TagID
        WHERE tt.[Level] < @MaxDepth
          AND (@ActiveOnly = 0 OR t.IsActive = 1)
    )
    SELECT TagID, ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder, [Level], TreePath
    FROM TagTree
    WHERE @ActiveOnly = 0 OR IsActive = 1
    ORDER BY TreePath;
END
');
GO

EXEC (N'
CREATE OR ALTER PROCEDURE Tags.usp_GetTagAncestors
    @TagID       INT,
    @IncludeSelf BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Ancestors AS (
        SELECT TagID, ParentTagID, ResourceKey, DefaultLabel, SortOrder, 0 AS [Level]
        FROM Tags.Tags
        WHERE TagID = @TagID

        UNION ALL

        SELECT t.TagID, t.ParentTagID, t.ResourceKey, t.DefaultLabel, t.SortOrder, a.[Level] + 1
        FROM Tags.Tags t
        INNER JOIN Ancestors a ON t.TagID = a.ParentTagID
    )
    SELECT TagID, ParentTagID, ResourceKey, DefaultLabel, SortOrder, [Level]
    FROM Ancestors
    WHERE @IncludeSelf = 1 OR TagID <> @TagID
    ORDER BY [Level] DESC;
END
');
GO

EXEC (N'
CREATE OR ALTER PROCEDURE Tags.usp_GetTagDescendants
    @TagID       INT,
    @MaxDepth    INT = 100,
    @IncludeSelf BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Descendants AS (
        SELECT TagID, ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder, 1 AS [Level]
        FROM Tags.Tags
        WHERE ParentTagID = @TagID

        UNION ALL

        SELECT t.TagID, t.ParentTagID, t.ResourceKey, t.DefaultLabel, t.IsActive, t.SortOrder, d.[Level] + 1
        FROM Tags.Tags t
        INNER JOIN Descendants d ON t.ParentTagID = d.TagID
        WHERE d.[Level] < @MaxDepth
    )
    SELECT TagID, ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder, [Level]
    FROM Descendants

    UNION ALL

    SELECT TagID, ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder, 0 AS [Level]
    FROM Tags.Tags
    WHERE TagID = @TagID AND @IncludeSelf = 1

    ORDER BY [Level], SortOrder;
END
');
GO


-- ===========================================================
-- SECTION 9 — Views
-- ===========================================================

-- ── 9.1 ATAPUtilities.vw_UserFull ─────────────────────────

CREATE VIEW ATAPUtilities.vw_UserFull AS
SELECT
    u.UserId,
    u.EmailHash,
    u.HashAlgorithmName,
    ui.FirstName,
    ui.LastName,
    ui.Email,
    ui.Phone,
    ui.Role,
    ui.EncryptionKeyVersion,
    us.PreferredTheme,
    us.IsDarkMode,
    us.Language
FROM ATAPUtilities.[User]               AS u
LEFT JOIN ATAPUtilities.UserInformation AS ui ON ui.UserId = u.UserId
LEFT JOIN ATAPUtilities.UserSettings    AS us ON us.UserId = u.UserId;
GO

-- ── 9.2 AceCommander.vw_UserFull ──────────────────────────

CREATE VIEW AceCommander.vw_UserFull AS
SELECT
    u.UserId,
    u.EmailHash,
    u.HashAlgorithmName,
    ui.FirstName,
    ui.LastName,
    ui.Email,
    ui.Phone,
    ui.Role,
    ui.EncryptionKeyVersion,
    us.PreferredTheme,
    us.IsDarkMode,
    us.Language
FROM AceCommander.[User]               AS u
LEFT JOIN AceCommander.UserInformation AS ui ON ui.UserId = u.UserId
LEFT JOIN AceCommander.UserSettings    AS us ON us.UserId = u.UserId;
GO

-- ── 9.3 AceCommander.vw_UserCrossSchema ───────────────────
-- Joins AceCommander and ATAPUtilities user rows on EmailHash for reconciliation.
-- EmailHash NULLs are excluded from the join to avoid false cross-row matches.

CREATE VIEW AceCommander.vw_UserCrossSchema AS
SELECT
    ac_u.EmailHash,
    -- AceCommander identity
    ac_u.UserId                AS AC_UserId,
    ac_u.HashAlgorithmName     AS AC_HashAlgorithmName,
    ac_ui.FirstName            AS AC_FirstName,
    ac_ui.LastName             AS AC_LastName,
    ac_ui.Email                AS AC_Email,
    ac_ui.Phone                AS AC_Phone,
    ac_ui.Role                 AS AC_Role,
    ac_ui.EncryptionKeyVersion AS AC_EncryptionKeyVersion,
    ac_us.PreferredTheme       AS AC_PreferredTheme,
    ac_us.IsDarkMode           AS AC_IsDarkMode,
    ac_us.Language             AS AC_Language,
    -- ATAPUtilities identity (NULL when no match)
    atu_u.UserId               AS ATU_UserId,
    atu_u.HashAlgorithmName    AS ATU_HashAlgorithmName,
    atu_ui.FirstName           AS ATU_FirstName,
    atu_ui.LastName            AS ATU_LastName,
    atu_ui.Email               AS ATU_Email,
    atu_ui.Phone               AS ATU_Phone,
    atu_ui.Role                AS ATU_Role,
    atu_ui.EncryptionKeyVersion AS ATU_EncryptionKeyVersion,
    atu_us.PreferredTheme      AS ATU_PreferredTheme,
    atu_us.IsDarkMode          AS ATU_IsDarkMode,
    atu_us.Language            AS ATU_Language
FROM AceCommander.[User]                AS ac_u
LEFT JOIN AceCommander.UserInformation  AS ac_ui  ON ac_ui.UserId    = ac_u.UserId
LEFT JOIN AceCommander.UserSettings     AS ac_us  ON ac_us.UserId    = ac_u.UserId
LEFT JOIN ATAPUtilities.[User]          AS atu_u  ON atu_u.EmailHash = ac_u.EmailHash
                                                 AND ac_u.EmailHash  IS NOT NULL
LEFT JOIN ATAPUtilities.UserInformation AS atu_ui ON atu_ui.UserId   = atu_u.UserId
LEFT JOIN ATAPUtilities.UserSettings    AS atu_us ON atu_us.UserId   = atu_u.UserId;
GO

-- ── 9.4 Tags views ────────────────────────────────────────

EXEC (N'
CREATE OR ALTER VIEW Tags.vw_ActiveTags AS
SELECT
    t.TagID, t.ParentTagID, t.ResourceKey, t.DefaultLabel, t.SortOrder,
    t.CreatedDate, t.ModifiedDate,
    p.ResourceKey  AS ParentResourceKey,
    p.DefaultLabel AS ParentDefaultLabel
FROM Tags.Tags t
LEFT JOIN Tags.Tags p ON t.ParentTagID = p.TagID
WHERE t.IsActive = 1;
');
GO

EXEC (N'
CREATE OR ALTER VIEW Tags.vw_RootTags AS
SELECT TagID, ResourceKey, DefaultLabel, SortOrder, IsActive, CreatedDate
FROM Tags.Tags
WHERE ParentTagID IS NULL
  AND IsActive = 1;
');
GO

EXEC (N'
CREATE OR ALTER VIEW Tags.vw_TagsWithChildCount AS
SELECT
    t.TagID, t.ParentTagID, t.ResourceKey, t.DefaultLabel, t.IsActive, t.SortOrder,
    (SELECT COUNT(*) FROM Tags.Tags c WHERE c.ParentTagID = t.TagID AND c.IsActive = 1) AS ChildCount,
    CASE WHEN EXISTS (SELECT 1 FROM Tags.Tags c WHERE c.ParentTagID = t.TagID AND c.IsActive = 1)
         THEN 1 ELSE 0 END AS HasChildren
FROM Tags.Tags t;
');
GO

EXEC (N'
CREATE OR ALTER VIEW Tags.vw_TagRelationshipsExpanded AS
SELECT
    r.RelationshipID,
    r.SourceTagID, s.ResourceKey  AS SourceResourceKey, s.DefaultLabel AS SourceDefaultLabel,
    r.TargetTagID, tgt.ResourceKey AS TargetResourceKey, tgt.DefaultLabel AS TargetDefaultLabel,
    r.RelationshipTypeKey, r.IsBidirectional, r.Weight, r.IsActive
FROM Tags.TagRelationships r
INNER JOIN Tags.Tags s   ON r.SourceTagID = s.TagID
INNER JOIN Tags.Tags tgt ON r.TargetTagID = tgt.TagID;
');
GO

PRINT N'V00.01.000010 (COMBINED) — ATAPUtilities Core Schema created successfully.';
GO

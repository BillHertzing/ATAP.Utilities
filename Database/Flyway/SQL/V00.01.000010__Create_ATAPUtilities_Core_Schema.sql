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

/* =====================================================================
   Consolidated Sprint 0012/0013 baseline evolution.
   These scripts formerly lived in the retired secondary migrations tree.
   They are retained verbatim so a clean database reaches the same schema.
   ===================================================================== */

/* BEGIN legacy baseline component: V00.02.000060__Add_Instantiation_Manifestation_Tables.sql */
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
/* END legacy baseline component: V00.02.000060__Add_Instantiation_Manifestation_Tables.sql */

/* BEGIN legacy baseline component: V00.02.000070__Add_RRSBS_Durable_Versioned_Snapshots.sql */
-- =====================================================================
-- V00.02.000070__Add_RRSBS_Durable_Versioned_Snapshots.sql
--
-- Sprint 0013 Tasks 13.78.c - 13.78.g.
--
-- Adds the immutable version layer over the DURABLE RRSBS identities that
-- already exist from V00.01.000010 (ATAPUtilities.[Rule], RuleSet, BuildSet,
-- RuleInstantiation, RuleInstantiationBinding, RulePrimitive), plus the
-- ordered snapshot membership structures and ManifestationArtifact
-- provenance columns.
--
-- Layering (no Build or BuildVersion entity exists anywhere in this chain):
--
--   InstantiationVersion
--     -> BuildSetVersion            (InstantiationVersion.BuildSetVersionPhiloteId)
--         -> BuildSetVersionMember
--             -> RuleSetVersion
--                 -> RuleSetVersionMember
--                     -> RuleVersion
--                         -> RuleVersionPrimitiveComposition
--                             -> RulePrimitive
--
-- Forward-only and re-runnable: every object is guarded with OBJECT_ID /
-- COL_LENGTH existence checks. No seed rows are inserted here; Task 13.79
-- owns seeding. New Philote-backed rows must be created with stable
-- caller-supplied GUIDs.
-- =====================================================================
SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRANSACTION;

BEGIN TRY
    -- =================================================================
    -- Preconditions - durable identities created by V00.01.000010.
    --
    -- These durable tables are NOT re-created here. Re-creating them was
    -- the defect in the first draft of this migration: their guarded
    -- CREATE TABLE statements were skipped (the tables already exist) and
    -- the surrounding foreign keys then referenced column names
    -- (RulePhiloteId, RuleSetPhiloteId, BuildSetPhiloteId) that the
    -- deployed tables do not have. The deployed durable tables all key on
    -- a column literally named PhiloteId.
    -- =================================================================
    IF OBJECT_ID(N'ATAPUtilities.Philote', N'U') IS NULL
        THROW 50070, N'V00.02.000070 precondition failed: ATAPUtilities.Philote is missing.', 1;

    IF OBJECT_ID(N'ATAPUtilities.RulePrimitive', N'U') IS NULL
        THROW 50070, N'V00.02.000070 precondition failed: ATAPUtilities.RulePrimitive is missing.', 1;

    IF OBJECT_ID(N'ATAPUtilities.Rule', N'U') IS NULL
        THROW 50070, N'V00.02.000070 precondition failed: ATAPUtilities.[Rule] is missing.', 1;

    IF OBJECT_ID(N'ATAPUtilities.RuleSet', N'U') IS NULL
        THROW 50070, N'V00.02.000070 precondition failed: ATAPUtilities.RuleSet is missing.', 1;

    IF OBJECT_ID(N'ATAPUtilities.BuildSet', N'U') IS NULL
        THROW 50070, N'V00.02.000070 precondition failed: ATAPUtilities.BuildSet is missing.', 1;

    IF OBJECT_ID(N'ATAPUtilities.RuleInstantiation', N'U') IS NULL
        THROW 50070, N'V00.02.000070 precondition failed: ATAPUtilities.RuleInstantiation is missing.', 1;

    IF OBJECT_ID(N'ATAPUtilities.RuleInstantiationBinding', N'U') IS NULL
        THROW 50070, N'V00.02.000070 precondition failed: ATAPUtilities.RuleInstantiationBinding is missing.', 1;

    IF OBJECT_ID(N'ATAPUtilities.Instantiation', N'U') IS NULL
        THROW 50070, N'V00.02.000070 precondition failed: ATAPUtilities.Instantiation is missing (V00.02.000060).', 1;

    IF OBJECT_ID(N'ATAPUtilities.InstantiationVersion', N'U') IS NULL
        THROW 50070, N'V00.02.000070 precondition failed: ATAPUtilities.InstantiationVersion is missing (V00.02.000060).', 1;

    IF OBJECT_ID(N'ATAPUtilities.ManifestationArtifact', N'U') IS NULL
        THROW 50070, N'V00.02.000070 precondition failed: ATAPUtilities.ManifestationArtifact is missing (V00.02.000060).', 1;

    -- =================================================================
    -- 13.78.c - immutable RuleVersion and its ordered primitive composition
    -- =================================================================

    IF OBJECT_ID(N'ATAPUtilities.RuleVersion', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.RuleVersion (
            RuleVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            RulePhiloteId UNIQUEIDENTIFIER NOT NULL,
            VersionNumber INT NOT NULL,
            VersionLabel NVARCHAR(100) NOT NULL,
            ParentRuleVersionPhiloteId UNIQUEIDENTIFIER NULL,
            SortOrder INT NOT NULL CONSTRAINT DF_RuleVersion_SortOrder DEFAULT (0),
            ContentSha256 CHAR(64) NULL,
            CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_RuleVersion_CreatedAt DEFAULT SYSUTCDATETIME(),
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_RuleVersion PRIMARY KEY CLUSTERED (RuleVersionPhiloteId),
            CONSTRAINT FK_RuleVersion_Philote FOREIGN KEY (RuleVersionPhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
            CONSTRAINT FK_RuleVersion_Rule FOREIGN KEY (RulePhiloteId) REFERENCES ATAPUtilities.[Rule] (PhiloteId),
            CONSTRAINT FK_RuleVersion_Parent FOREIGN KEY (ParentRuleVersionPhiloteId) REFERENCES ATAPUtilities.RuleVersion (RuleVersionPhiloteId),
            CONSTRAINT CK_RuleVersion_Number CHECK (VersionNumber > 0),
            CONSTRAINT CK_RuleVersion_SortOrder CHECK (SortOrder >= 0),
            CONSTRAINT CK_RuleVersion_ParentNotSelf CHECK (ParentRuleVersionPhiloteId IS NULL OR ParentRuleVersionPhiloteId <> RuleVersionPhiloteId),
            CONSTRAINT UQ_RuleVersion_Number UNIQUE (RulePhiloteId, VersionNumber),
            CONSTRAINT UQ_RuleVersion_Label UNIQUE (RulePhiloteId, VersionLabel),
            -- Composite target that lets RuleInstantiationVersion prove a
            -- RuleVersion and a RuleInstantiation refer to the SAME durable Rule.
            CONSTRAINT UQ_RuleVersion_Version_Rule UNIQUE (RuleVersionPhiloteId, RulePhiloteId)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.RuleVersion', N'U') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_RuleVersion_Rule' AND object_id = OBJECT_ID(N'ATAPUtilities.RuleVersion'))
    BEGIN
        CREATE INDEX IX_RuleVersion_Rule ON ATAPUtilities.RuleVersion (RulePhiloteId, VersionNumber);
    END;

    -- RuleVersion-to-primitive composition. Position is the BNF production
    -- order and MUST be contiguous 1-based per RuleVersion (see the Rule
    -- Grammar Database Schema contract). Contiguity is enforced by
    -- TR_RuleVersionPrimitiveComposition_ContiguousPosition below; a CHECK
    -- constraint cannot express a cross-row invariant.
    IF OBJECT_ID(N'ATAPUtilities.RuleVersionPrimitiveComposition', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.RuleVersionPrimitiveComposition (
            RuleVersionPrimitiveCompositionId INT IDENTITY(1,1) NOT NULL,
            RuleVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            PrimitivePhiloteId UNIQUEIDENTIFIER NOT NULL,
            Position INT NOT NULL,
            IsOptional BIT NOT NULL CONSTRAINT DF_RuleVersionPrimitiveComposition_IsOptional DEFAULT (0),
            Cardinality NVARCHAR(20) NOT NULL CONSTRAINT DF_RuleVersionPrimitiveComposition_Cardinality DEFAULT (N'One'),
            BoundInputsJson NVARCHAR(MAX) NULL,
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_RuleVersionPrimitiveComposition PRIMARY KEY CLUSTERED (RuleVersionPrimitiveCompositionId),
            CONSTRAINT FK_RuleVersionPrimitiveComposition_RuleVersion FOREIGN KEY (RuleVersionPhiloteId) REFERENCES ATAPUtilities.RuleVersion (RuleVersionPhiloteId),
            CONSTRAINT FK_RuleVersionPrimitiveComposition_Primitive FOREIGN KEY (PrimitivePhiloteId) REFERENCES ATAPUtilities.RulePrimitive (PhiloteId),
            CONSTRAINT CK_RuleVersionPrimitiveComposition_Position CHECK (Position >= 1),
            CONSTRAINT CK_RuleVersionPrimitiveComposition_Cardinality CHECK (Cardinality IN (N'One', N'ZeroOrOne', N'ZeroOrMore', N'OneOrMore')),
            CONSTRAINT CK_RuleVersionPrimitiveComposition_BoundInputsJson CHECK (BoundInputsJson IS NULL OR ISJSON(BoundInputsJson) = 1),
            CONSTRAINT UQ_RuleVersionPrimitiveComposition_Position UNIQUE (RuleVersionPhiloteId, Position)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.RuleVersionPrimitiveComposition', N'U') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_RuleVersionPrimitiveComposition_Primitive' AND object_id = OBJECT_ID(N'ATAPUtilities.RuleVersionPrimitiveComposition'))
    BEGIN
        CREATE INDEX IX_RuleVersionPrimitiveComposition_Primitive ON ATAPUtilities.RuleVersionPrimitiveComposition (PrimitivePhiloteId);
    END;

    -- =================================================================
    -- 13.78.d - RuleSetVersion and ordered RuleSetVersion membership
    -- =================================================================

    IF OBJECT_ID(N'ATAPUtilities.RuleSetVersion', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.RuleSetVersion (
            RuleSetVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            RuleSetPhiloteId UNIQUEIDENTIFIER NOT NULL,
            VersionNumber INT NOT NULL,
            VersionLabel NVARCHAR(100) NOT NULL,
            ParentRuleSetVersionPhiloteId UNIQUEIDENTIFIER NULL,
            SortOrder INT NOT NULL CONSTRAINT DF_RuleSetVersion_SortOrder DEFAULT (0),
            CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_RuleSetVersion_CreatedAt DEFAULT SYSUTCDATETIME(),
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_RuleSetVersion PRIMARY KEY CLUSTERED (RuleSetVersionPhiloteId),
            CONSTRAINT FK_RuleSetVersion_Philote FOREIGN KEY (RuleSetVersionPhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
            CONSTRAINT FK_RuleSetVersion_RuleSet FOREIGN KEY (RuleSetPhiloteId) REFERENCES ATAPUtilities.RuleSet (PhiloteId),
            CONSTRAINT FK_RuleSetVersion_Parent FOREIGN KEY (ParentRuleSetVersionPhiloteId) REFERENCES ATAPUtilities.RuleSetVersion (RuleSetVersionPhiloteId),
            CONSTRAINT CK_RuleSetVersion_Number CHECK (VersionNumber > 0),
            CONSTRAINT CK_RuleSetVersion_SortOrder CHECK (SortOrder >= 0),
            CONSTRAINT CK_RuleSetVersion_ParentNotSelf CHECK (ParentRuleSetVersionPhiloteId IS NULL OR ParentRuleSetVersionPhiloteId <> RuleSetVersionPhiloteId),
            CONSTRAINT UQ_RuleSetVersion_Number UNIQUE (RuleSetPhiloteId, VersionNumber),
            CONSTRAINT UQ_RuleSetVersion_Label UNIQUE (RuleSetPhiloteId, VersionLabel)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.RuleSetVersion', N'U') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_RuleSetVersion_RuleSet' AND object_id = OBJECT_ID(N'ATAPUtilities.RuleSetVersion'))
    BEGIN
        CREATE INDEX IX_RuleSetVersion_RuleSet ON ATAPUtilities.RuleSetVersion (RuleSetPhiloteId, VersionNumber);
    END;

    -- Membership table name matches the deployed consumer query in
    -- Get-InstantiationVersionRuleGraph.ps1 (ATAPUtilities.RuleSetVersionMember).
    IF OBJECT_ID(N'ATAPUtilities.RuleSetVersionMember', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.RuleSetVersionMember (
            RuleSetVersionMemberId INT IDENTITY(1,1) NOT NULL,
            RuleSetVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            RuleVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            SortOrder INT NOT NULL,
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_RuleSetVersionMember PRIMARY KEY CLUSTERED (RuleSetVersionMemberId),
            CONSTRAINT FK_RuleSetVersionMember_RuleSetVersion FOREIGN KEY (RuleSetVersionPhiloteId) REFERENCES ATAPUtilities.RuleSetVersion (RuleSetVersionPhiloteId),
            CONSTRAINT FK_RuleSetVersionMember_RuleVersion FOREIGN KEY (RuleVersionPhiloteId) REFERENCES ATAPUtilities.RuleVersion (RuleVersionPhiloteId),
            CONSTRAINT CK_RuleSetVersionMember_SortOrder CHECK (SortOrder >= 0),
            CONSTRAINT UQ_RuleSetVersionMember_SortOrder UNIQUE (RuleSetVersionPhiloteId, SortOrder),
            CONSTRAINT UQ_RuleSetVersionMember_RuleVersion UNIQUE (RuleSetVersionPhiloteId, RuleVersionPhiloteId)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.RuleSetVersionMember', N'U') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_RuleSetVersionMember_RuleVersion' AND object_id = OBJECT_ID(N'ATAPUtilities.RuleSetVersionMember'))
    BEGIN
        CREATE INDEX IX_RuleSetVersionMember_RuleVersion ON ATAPUtilities.RuleSetVersionMember (RuleVersionPhiloteId);
    END;

    -- =================================================================
    -- 13.78.e - BuildSetVersion and ordered BuildSetVersion membership.
    --           A BuildSet contains RuleSets directly. No Build entity and
    --           no BuildVersion entity is created anywhere in this file.
    -- =================================================================

    IF OBJECT_ID(N'ATAPUtilities.BuildSetVersion', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.BuildSetVersion (
            BuildSetVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            BuildSetPhiloteId UNIQUEIDENTIFIER NOT NULL,
            VersionNumber INT NOT NULL,
            VersionLabel NVARCHAR(100) NOT NULL,
            ParentBuildSetVersionPhiloteId UNIQUEIDENTIFIER NULL,
            SortOrder INT NOT NULL CONSTRAINT DF_BuildSetVersion_SortOrder DEFAULT (0),
            CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_BuildSetVersion_CreatedAt DEFAULT SYSUTCDATETIME(),
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_BuildSetVersion PRIMARY KEY CLUSTERED (BuildSetVersionPhiloteId),
            CONSTRAINT FK_BuildSetVersion_Philote FOREIGN KEY (BuildSetVersionPhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
            CONSTRAINT FK_BuildSetVersion_BuildSet FOREIGN KEY (BuildSetPhiloteId) REFERENCES ATAPUtilities.BuildSet (PhiloteId),
            CONSTRAINT FK_BuildSetVersion_Parent FOREIGN KEY (ParentBuildSetVersionPhiloteId) REFERENCES ATAPUtilities.BuildSetVersion (BuildSetVersionPhiloteId),
            CONSTRAINT CK_BuildSetVersion_Number CHECK (VersionNumber > 0),
            CONSTRAINT CK_BuildSetVersion_SortOrder CHECK (SortOrder >= 0),
            CONSTRAINT CK_BuildSetVersion_ParentNotSelf CHECK (ParentBuildSetVersionPhiloteId IS NULL OR ParentBuildSetVersionPhiloteId <> BuildSetVersionPhiloteId),
            CONSTRAINT UQ_BuildSetVersion_Number UNIQUE (BuildSetPhiloteId, VersionNumber),
            CONSTRAINT UQ_BuildSetVersion_Label UNIQUE (BuildSetPhiloteId, VersionLabel)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.BuildSetVersion', N'U') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_BuildSetVersion_BuildSet' AND object_id = OBJECT_ID(N'ATAPUtilities.BuildSetVersion'))
    BEGIN
        CREATE INDEX IX_BuildSetVersion_BuildSet ON ATAPUtilities.BuildSetVersion (BuildSetPhiloteId, VersionNumber);
    END;

    IF OBJECT_ID(N'ATAPUtilities.BuildSetVersionMember', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.BuildSetVersionMember (
            BuildSetVersionMemberId INT IDENTITY(1,1) NOT NULL,
            BuildSetVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            RuleSetVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            SortOrder INT NOT NULL,
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_BuildSetVersionMember PRIMARY KEY CLUSTERED (BuildSetVersionMemberId),
            CONSTRAINT FK_BuildSetVersionMember_BuildSetVersion FOREIGN KEY (BuildSetVersionPhiloteId) REFERENCES ATAPUtilities.BuildSetVersion (BuildSetVersionPhiloteId),
            CONSTRAINT FK_BuildSetVersionMember_RuleSetVersion FOREIGN KEY (RuleSetVersionPhiloteId) REFERENCES ATAPUtilities.RuleSetVersion (RuleSetVersionPhiloteId),
            CONSTRAINT CK_BuildSetVersionMember_SortOrder CHECK (SortOrder >= 0),
            CONSTRAINT UQ_BuildSetVersionMember_SortOrder UNIQUE (BuildSetVersionPhiloteId, SortOrder),
            CONSTRAINT UQ_BuildSetVersionMember_RuleSetVersion UNIQUE (BuildSetVersionPhiloteId, RuleSetVersionPhiloteId)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.BuildSetVersionMember', N'U') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_BuildSetVersionMember_RuleSetVersion' AND object_id = OBJECT_ID(N'ATAPUtilities.BuildSetVersionMember'))
    BEGIN
        CREATE INDEX IX_BuildSetVersionMember_RuleSetVersion ON ATAPUtilities.BuildSetVersionMember (RuleSetVersionPhiloteId);
    END;

    -- =================================================================
    -- 13.78.f - InstantiationVersion -> BuildSetVersion FK,
    --           durable Instantiation -> RuleInstantiation relationship,
    --           RuleInstantiation bindings,
    --           immutable InstantiationVersion snapshot membership.
    -- =================================================================

    -- InstantiationVersion.BuildSetVersionPhiloteId is the exact column the
    -- deployed consumer joins on. It is NULLable because V00.02.000060
    -- already seeded two InstantiationVersion rows; a forward-only ALTER
    -- cannot add a NOT NULL FK column over existing rows without inventing
    -- a value. Task 13.79 backfills it.
    IF COL_LENGTH(N'ATAPUtilities.InstantiationVersion', N'BuildSetVersionPhiloteId') IS NULL
    BEGIN
        ALTER TABLE ATAPUtilities.InstantiationVersion
            ADD BuildSetVersionPhiloteId UNIQUEIDENTIFIER NULL;
    END;

    IF OBJECT_ID(N'ATAPUtilities.FK_InstantiationVersion_BuildSetVersion', N'F') IS NULL
    BEGIN
        EXEC sp_executesql N'
            ALTER TABLE ATAPUtilities.InstantiationVersion
                ADD CONSTRAINT FK_InstantiationVersion_BuildSetVersion
                FOREIGN KEY (BuildSetVersionPhiloteId)
                REFERENCES ATAPUtilities.BuildSetVersion (BuildSetVersionPhiloteId);';
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_InstantiationVersion_BuildSetVersion' AND object_id = OBJECT_ID(N'ATAPUtilities.InstantiationVersion'))
    BEGIN
        EXEC sp_executesql N'
            CREATE INDEX IX_InstantiationVersion_BuildSetVersion
                ON ATAPUtilities.InstantiationVersion (BuildSetVersionPhiloteId);';
    END;

    -- Durable Instantiation -> RuleInstantiation relationship. The durable
    -- RuleInstantiation table from V00.01.000010 has only RulePhiloteId; it
    -- has no owning Instantiation. Add it forward-only as NULLable.
    IF COL_LENGTH(N'ATAPUtilities.RuleInstantiation', N'InstantiationPhiloteId') IS NULL
    BEGIN
        ALTER TABLE ATAPUtilities.RuleInstantiation
            ADD InstantiationPhiloteId UNIQUEIDENTIFIER NULL;
    END;

    IF OBJECT_ID(N'ATAPUtilities.FK_RuleInstantiation_Instantiation', N'F') IS NULL
    BEGIN
        EXEC sp_executesql N'
            ALTER TABLE ATAPUtilities.RuleInstantiation
                ADD CONSTRAINT FK_RuleInstantiation_Instantiation
                FOREIGN KEY (InstantiationPhiloteId)
                REFERENCES ATAPUtilities.Instantiation (InstantiationPhiloteId);';
    END;

    -- One RuleInstantiation per (Instantiation, Rule) pair. Filtered so the
    -- pre-existing rows with NULL InstantiationPhiloteId do not collide.
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_RuleInstantiation_Instantiation_Rule' AND object_id = OBJECT_ID(N'ATAPUtilities.RuleInstantiation'))
    BEGIN
        EXEC sp_executesql N'
            CREATE UNIQUE INDEX UX_RuleInstantiation_Instantiation_Rule
                ON ATAPUtilities.RuleInstantiation (InstantiationPhiloteId, RulePhiloteId)
                WHERE InstantiationPhiloteId IS NOT NULL;';
    END;

    -- Composite target so RuleInstantiationVersion can prove that the
    -- RuleVersion it snapshots belongs to the same durable Rule as the
    -- RuleInstantiation it snapshots. PhiloteId is already the PK, so this
    -- UNIQUE constraint is trivially satisfiable over existing rows.
    IF OBJECT_ID(N'ATAPUtilities.UQ_RuleInstantiation_Instantiation_Rule', N'UQ') IS NULL
    BEGIN
        EXEC sp_executesql N'
            ALTER TABLE ATAPUtilities.RuleInstantiation
                ADD CONSTRAINT UQ_RuleInstantiation_Instantiation_Rule
                UNIQUE (PhiloteId, RulePhiloteId);';
    END;

    -- RuleInstantiation bindings: ATAPUtilities.RuleInstantiationBinding
    -- already exists from V00.01.000010 with the required shape
    -- (InstantiationPhiloteId -> RuleInstantiation.PhiloteId, InputName,
    -- InputValue, UQ per InputName). It is NOT re-created or reshaped here.
    -- Only the missing lookup index is added.
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_RuleInstantiationBinding_Instantiation' AND object_id = OBJECT_ID(N'ATAPUtilities.RuleInstantiationBinding'))
    BEGIN
        EXEC sp_executesql N'
            CREATE INDEX IX_RuleInstantiationBinding_Instantiation
                ON ATAPUtilities.RuleInstantiationBinding (InstantiationPhiloteId);';
    END;

    -- Immutable per-RuleInstantiation snapshot: which RuleVersion was bound.
    -- RulePhiloteId is carried redundantly ONLY to feed the two composite FKs
    -- that block cross-Rule binding.
    IF OBJECT_ID(N'ATAPUtilities.RuleInstantiationVersion', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.RuleInstantiationVersion (
            RuleInstantiationVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            RuleInstantiationPhiloteId UNIQUEIDENTIFIER NOT NULL,
            RuleVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            RulePhiloteId UNIQUEIDENTIFIER NOT NULL,
            VersionNumber INT NOT NULL,
            VersionLabel NVARCHAR(100) NOT NULL,
            ParentRuleInstantiationVersionPhiloteId UNIQUEIDENTIFIER NULL,
            CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_RuleInstantiationVersion_CreatedAt DEFAULT SYSUTCDATETIME(),
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_RuleInstantiationVersion PRIMARY KEY CLUSTERED (RuleInstantiationVersionPhiloteId),
            CONSTRAINT FK_RuleInstantiationVersion_Philote FOREIGN KEY (RuleInstantiationVersionPhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
            CONSTRAINT FK_RuleInstantiationVersion_RuleInstantiation FOREIGN KEY (RuleInstantiationPhiloteId, RulePhiloteId) REFERENCES ATAPUtilities.RuleInstantiation (PhiloteId, RulePhiloteId),
            CONSTRAINT FK_RuleInstantiationVersion_RuleVersion FOREIGN KEY (RuleVersionPhiloteId, RulePhiloteId) REFERENCES ATAPUtilities.RuleVersion (RuleVersionPhiloteId, RulePhiloteId),
            CONSTRAINT FK_RuleInstantiationVersion_Parent FOREIGN KEY (ParentRuleInstantiationVersionPhiloteId) REFERENCES ATAPUtilities.RuleInstantiationVersion (RuleInstantiationVersionPhiloteId),
            CONSTRAINT CK_RuleInstantiationVersion_Number CHECK (VersionNumber > 0),
            CONSTRAINT CK_RuleInstantiationVersion_ParentNotSelf CHECK (ParentRuleInstantiationVersionPhiloteId IS NULL OR ParentRuleInstantiationVersionPhiloteId <> RuleInstantiationVersionPhiloteId),
            CONSTRAINT UQ_RuleInstantiationVersion_Number UNIQUE (RuleInstantiationPhiloteId, VersionNumber),
            CONSTRAINT UQ_RuleInstantiationVersion_Label UNIQUE (RuleInstantiationPhiloteId, VersionLabel)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.RuleInstantiationVersion', N'U') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_RuleInstantiationVersion_RuleVersion' AND object_id = OBJECT_ID(N'ATAPUtilities.RuleInstantiationVersion'))
    BEGIN
        CREATE INDEX IX_RuleInstantiationVersion_RuleVersion ON ATAPUtilities.RuleInstantiationVersion (RuleVersionPhiloteId);
    END;

    -- Immutable ordered InstantiationVersion snapshot membership.
    IF OBJECT_ID(N'ATAPUtilities.InstantiationVersionRuleInstantiationVersion', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.InstantiationVersionRuleInstantiationVersion (
            InstantiationVersionRuleInstantiationVersionId INT IDENTITY(1,1) NOT NULL,
            InstantiationVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            RuleInstantiationVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            SortOrder INT NOT NULL,
            Notes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_InstantiationVersionRuleInstantiationVersion PRIMARY KEY CLUSTERED (InstantiationVersionRuleInstantiationVersionId),
            CONSTRAINT FK_IVRIV_InstantiationVersion FOREIGN KEY (InstantiationVersionPhiloteId) REFERENCES ATAPUtilities.InstantiationVersion (InstantiationVersionPhiloteId),
            CONSTRAINT FK_IVRIV_RuleInstantiationVersion FOREIGN KEY (RuleInstantiationVersionPhiloteId) REFERENCES ATAPUtilities.RuleInstantiationVersion (RuleInstantiationVersionPhiloteId),
            CONSTRAINT CK_IVRIV_SortOrder CHECK (SortOrder >= 0),
            CONSTRAINT UQ_IVRIV_SortOrder UNIQUE (InstantiationVersionPhiloteId, SortOrder),
            CONSTRAINT UQ_IVRIV_RuleInstantiationVersion UNIQUE (InstantiationVersionPhiloteId, RuleInstantiationVersionPhiloteId)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.InstantiationVersionRuleInstantiationVersion', N'U') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_IVRIV_RuleInstantiationVersion' AND object_id = OBJECT_ID(N'ATAPUtilities.InstantiationVersionRuleInstantiationVersion'))
    BEGIN
        CREATE INDEX IX_IVRIV_RuleInstantiationVersion ON ATAPUtilities.InstantiationVersionRuleInstantiationVersion (RuleInstantiationVersionPhiloteId);
    END;

    -- =================================================================
    -- 13.78.g - ManifestationArtifact provenance.
    --
    -- Every artifact must be traceable to (1) its InstantiationVersion,
    -- (2) the BuildSetVersion that was in force, and (3) the producing
    -- RuleInstantiation / RuleInstantiationVersion.
    --
    -- (1) already exists as FK_ManifestationArtifact_Version from
    -- V00.02.000060 and is asserted, not re-created.
    --
    -- There is NO RuleExecution table anywhere in this repository, so the
    -- "producing RuleInstantiation or RuleExecution" requirement is
    -- expressed against RuleInstantiation and its immutable
    -- RuleInstantiationVersion only. See the evidence file.
    -- =================================================================

    IF OBJECT_ID(N'ATAPUtilities.FK_ManifestationArtifact_Version', N'F') IS NULL
        THROW 50070, N'V00.02.000070 precondition failed: FK_ManifestationArtifact_Version (artifact -> InstantiationVersion) is missing.', 1;

    IF COL_LENGTH(N'ATAPUtilities.ManifestationArtifact', N'BuildSetVersionPhiloteId') IS NULL
    BEGIN
        ALTER TABLE ATAPUtilities.ManifestationArtifact
            ADD BuildSetVersionPhiloteId UNIQUEIDENTIFIER NULL;
    END;

    IF COL_LENGTH(N'ATAPUtilities.ManifestationArtifact', N'ProducingRuleInstantiationPhiloteId') IS NULL
    BEGIN
        ALTER TABLE ATAPUtilities.ManifestationArtifact
            ADD ProducingRuleInstantiationPhiloteId UNIQUEIDENTIFIER NULL;
    END;

    IF COL_LENGTH(N'ATAPUtilities.ManifestationArtifact', N'ProducingRuleInstantiationVersionPhiloteId') IS NULL
    BEGIN
        ALTER TABLE ATAPUtilities.ManifestationArtifact
            ADD ProducingRuleInstantiationVersionPhiloteId UNIQUEIDENTIFIER NULL;
    END;

    IF OBJECT_ID(N'ATAPUtilities.FK_ManifestationArtifact_BuildSetVersion', N'F') IS NULL
    BEGIN
        EXEC sp_executesql N'
            ALTER TABLE ATAPUtilities.ManifestationArtifact
                ADD CONSTRAINT FK_ManifestationArtifact_BuildSetVersion
                FOREIGN KEY (BuildSetVersionPhiloteId)
                REFERENCES ATAPUtilities.BuildSetVersion (BuildSetVersionPhiloteId);';
    END;

    IF OBJECT_ID(N'ATAPUtilities.FK_ManifestationArtifact_RuleInstantiation', N'F') IS NULL
    BEGIN
        EXEC sp_executesql N'
            ALTER TABLE ATAPUtilities.ManifestationArtifact
                ADD CONSTRAINT FK_ManifestationArtifact_RuleInstantiation
                FOREIGN KEY (ProducingRuleInstantiationPhiloteId)
                REFERENCES ATAPUtilities.RuleInstantiation (PhiloteId);';
    END;

    IF OBJECT_ID(N'ATAPUtilities.FK_ManifestationArtifact_RuleInstantiationVersion', N'F') IS NULL
    BEGIN
        EXEC sp_executesql N'
            ALTER TABLE ATAPUtilities.ManifestationArtifact
                ADD CONSTRAINT FK_ManifestationArtifact_RuleInstantiationVersion
                FOREIGN KEY (ProducingRuleInstantiationVersionPhiloteId)
                REFERENCES ATAPUtilities.RuleInstantiationVersion (RuleInstantiationVersionPhiloteId);';
    END;

    -- Rendered artifacts must carry full provenance. Added WITH NOCHECK so
    -- the RenderFromModel row seeded by V00.02.000060 (which predates these
    -- columns) is grandfathered; all subsequent INSERT/UPDATE is validated.
    IF OBJECT_ID(N'ATAPUtilities.CK_ManifestationArtifact_Provenance', N'C') IS NULL
    BEGIN
        EXEC sp_executesql N'
            ALTER TABLE ATAPUtilities.ManifestationArtifact WITH NOCHECK
                ADD CONSTRAINT CK_ManifestationArtifact_Provenance
                CHECK (
                    RenderPolicy <> N''RenderFromModel''
                    OR (
                        BuildSetVersionPhiloteId IS NOT NULL
                        AND ProducingRuleInstantiationPhiloteId IS NOT NULL
                    )
                );';
    END;

    -- A RuleInstantiationVersion may only be named as producer when the
    -- durable RuleInstantiation is named too, and they must agree.
    IF OBJECT_ID(N'ATAPUtilities.CK_ManifestationArtifact_ProducerPairing', N'C') IS NULL
    BEGIN
        EXEC sp_executesql N'
            ALTER TABLE ATAPUtilities.ManifestationArtifact WITH NOCHECK
                ADD CONSTRAINT CK_ManifestationArtifact_ProducerPairing
                CHECK (
                    ProducingRuleInstantiationVersionPhiloteId IS NULL
                    OR ProducingRuleInstantiationPhiloteId IS NOT NULL
                );';
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ManifestationArtifact_BuildSetVersion' AND object_id = OBJECT_ID(N'ATAPUtilities.ManifestationArtifact'))
    BEGIN
        EXEC sp_executesql N'
            CREATE INDEX IX_ManifestationArtifact_BuildSetVersion
                ON ATAPUtilities.ManifestationArtifact (BuildSetVersionPhiloteId);';
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ManifestationArtifact_Producer' AND object_id = OBJECT_ID(N'ATAPUtilities.ManifestationArtifact'))
    BEGIN
        EXEC sp_executesql N'
            CREATE INDEX IX_ManifestationArtifact_Producer
                ON ATAPUtilities.ManifestationArtifact (ProducingRuleInstantiationPhiloteId, ProducingRuleInstantiationVersionPhiloteId);';
    END;

    -- =================================================================
    -- Immutability enforcement.
    --
    -- "Immutable" is enforced, not merely documented: every version row and
    -- every version-membership row rejects UPDATE and DELETE. Change is
    -- expressed by inserting a NEW version row and pointing its Parent at
    -- the previous one. AFTER triggers are used (not INSTEAD OF) so the
    -- attempted statement is rolled back by the surrounding XACT_ABORT/
    -- THROW rather than silently discarded.
    --
    -- CREATE TRIGGER must be the first statement in its batch, and this
    -- migration is a single batch inside one transaction, so each trigger
    -- is created through sp_executesql.
    -- =================================================================
    DECLARE @ImmutableTables TABLE (
        TableName SYSNAME NOT NULL,
        TriggerName SYSNAME NOT NULL
    );

    INSERT INTO @ImmutableTables (TableName, TriggerName)
    VALUES
        (N'RuleVersion', N'TR_RuleVersion_Immutable'),
        (N'RuleVersionPrimitiveComposition', N'TR_RuleVersionPrimitiveComposition_Immutable'),
        (N'RuleSetVersion', N'TR_RuleSetVersion_Immutable'),
        (N'RuleSetVersionMember', N'TR_RuleSetVersionMember_Immutable'),
        (N'BuildSetVersion', N'TR_BuildSetVersion_Immutable'),
        (N'BuildSetVersionMember', N'TR_BuildSetVersionMember_Immutable'),
        (N'RuleInstantiationVersion', N'TR_RuleInstantiationVersion_Immutable'),
        (N'InstantiationVersionRuleInstantiationVersion', N'TR_IVRIV_Immutable');

    DECLARE @TableName SYSNAME;
    DECLARE @TriggerName SYSNAME;
    DECLARE @Sql NVARCHAR(MAX);

    DECLARE ImmutableCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT TableName, TriggerName FROM @ImmutableTables;

    OPEN ImmutableCursor;
    FETCH NEXT FROM ImmutableCursor INTO @TableName, @TriggerName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(@TriggerName), N'TR') IS NULL
           AND OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(@TableName), N'U') IS NOT NULL
        BEGIN
            SET @Sql = N'CREATE TRIGGER ATAPUtilities.' + QUOTENAME(@TriggerName)
                     + N' ON ATAPUtilities.' + QUOTENAME(@TableName)
                     + N' AFTER UPDATE, DELETE AS BEGIN'
                     + N' SET NOCOUNT ON;'
                     + N' IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;'
                     + N' THROW 50071, N''ATAPUtilities.' + @TableName
                     + N' is an immutable version/snapshot table. UPDATE and DELETE are rejected.'
                     + N' Record change by inserting a new version row and setting its parent pointer.'', 1;'
                     + N' END;';
            EXEC sp_executesql @Sql;
        END;

        FETCH NEXT FROM ImmutableCursor INTO @TableName, @TriggerName;
    END;

    CLOSE ImmutableCursor;
    DEALLOCATE ImmutableCursor;

    -- Contiguous 1-based Position per RuleVersion. UQ + CHECK already block
    -- duplicates and Position < 1; only the "no gaps" half needs a trigger.
    -- INSERT-only: UPDATE/DELETE are already blocked by the immutability
    -- trigger above. Rows for one RuleVersion must therefore be inserted in
    -- a single set-based statement, or one at a time in ascending Position.
    IF OBJECT_ID(N'ATAPUtilities.TR_RuleVersionPrimitiveComposition_ContiguousPosition', N'TR') IS NULL
       AND OBJECT_ID(N'ATAPUtilities.RuleVersionPrimitiveComposition', N'U') IS NOT NULL
    BEGIN
        EXEC sp_executesql N'
CREATE TRIGGER ATAPUtilities.TR_RuleVersionPrimitiveComposition_ContiguousPosition
ON ATAPUtilities.RuleVersionPrimitiveComposition
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM (
            SELECT c.RuleVersionPhiloteId,
                   MIN(c.Position) AS MinPosition,
                   MAX(c.Position) AS MaxPosition,
                   COUNT(*)        AS PositionCount
            FROM ATAPUtilities.RuleVersionPrimitiveComposition AS c
            WHERE c.RuleVersionPhiloteId IN (SELECT DISTINCT i.RuleVersionPhiloteId FROM inserted AS i)
            GROUP BY c.RuleVersionPhiloteId
        ) AS g
        WHERE g.MinPosition <> 1
           OR g.MaxPosition <> g.PositionCount
    )
    BEGIN
        THROW 50072, N''RuleVersionPrimitiveComposition.Position must be contiguous 1-based integers per RuleVersion (no gaps, no duplicates). Insert all composition rows for a RuleVersion in one set-based statement, or in ascending Position order.'', 1;
    END;
END;';
    END;

    -- Orphan-provenance guard: when an artifact names a BuildSetVersion and
    -- its InstantiationVersion also names one, they must be the same
    -- BuildSetVersion. Not expressible as a FK because
    -- InstantiationVersion.BuildSetVersionPhiloteId is NULLable.
    IF OBJECT_ID(N'ATAPUtilities.TR_ManifestationArtifact_Provenance', N'TR') IS NULL
    BEGIN
        EXEC sp_executesql N'
CREATE TRIGGER ATAPUtilities.TR_ManifestationArtifact_Provenance
ON ATAPUtilities.ManifestationArtifact
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        INNER JOIN ATAPUtilities.InstantiationVersion AS iv
            ON iv.InstantiationVersionPhiloteId = i.InstantiationVersionPhiloteId
        WHERE i.BuildSetVersionPhiloteId IS NOT NULL
          AND iv.BuildSetVersionPhiloteId IS NOT NULL
          AND i.BuildSetVersionPhiloteId <> iv.BuildSetVersionPhiloteId
    )
    BEGIN
        THROW 50073, N''ManifestationArtifact.BuildSetVersionPhiloteId must match the BuildSetVersion bound to its InstantiationVersion.'', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        INNER JOIN ATAPUtilities.RuleInstantiationVersion AS riv
            ON riv.RuleInstantiationVersionPhiloteId = i.ProducingRuleInstantiationVersionPhiloteId
        WHERE i.ProducingRuleInstantiationVersionPhiloteId IS NOT NULL
          AND i.ProducingRuleInstantiationPhiloteId IS NOT NULL
          AND riv.RuleInstantiationPhiloteId <> i.ProducingRuleInstantiationPhiloteId
    )
    BEGIN
        THROW 50074, N''ManifestationArtifact.ProducingRuleInstantiationVersionPhiloteId must be a version of ProducingRuleInstantiationPhiloteId.'', 1;
    END;
END;';
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

PRINT N'V00.02.000070 - RRSBS immutable version layer, ordered snapshot membership, and ManifestationArtifact provenance added.';
/* END legacy baseline component: V00.02.000070__Add_RRSBS_Durable_Versioned_Snapshots.sql */

/* BEGIN legacy baseline component: V00.02.000080__Migrate_TypedMembership_To_RRSBS_And_Retire_Samples.sql */
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
           N'Database/Flyway/SQL/V00.01.000010__Create_ATAPUtilities_Core_Schema.sql'
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
/* END legacy baseline component: V00.02.000080__Migrate_TypedMembership_To_RRSBS_And_Retire_Samples.sql */

/* BEGIN legacy baseline component: V00.02.000090__Assert_RulePrimitive_Rule_Identity_Invariant.sql */
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
/* END legacy baseline component: V00.02.000090__Assert_RulePrimitive_Rule_Identity_Invariant.sql */

/* BEGIN legacy baseline component: V00.02.000100__Add_RRSBS_Effective_Dating.sql */
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
/* END legacy baseline component: V00.02.000100__Add_RRSBS_Effective_Dating.sql */

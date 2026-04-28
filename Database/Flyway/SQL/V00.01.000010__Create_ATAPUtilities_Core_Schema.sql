USE ATAPUtilities;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================
   V00.01.000010 — Create ATAPUtilities Core Schema
   ============================================================
   Tables and seed data for:
     1. Philote (GuidPhilote identity, additional IDs, time blocks)
     2. PrimitiveLanguageKind lookup
     3. RulePrimitive  — atomic BNF building blocks
     4. RulePrimitiveInput — named inputs per primitive
     5. Rule             — named composition of primitives
     6. RulePrimitiveComposition — ordered primitives inside a rule
     7. RuleSet / RuleSetMember  — groupings of rules
     8. RuleInstantiation / RuleInstantiationBinding — concrete renderings
     9. User / UserInformation / UserSettings — identity and profile
   Seed rows for every primitive defined in the Rules Compendium
   markdown files (CSharp, Powershell, SQL, MSBuild).
   ============================================================ */

-- ===========================================================
-- Ensure the ATAPUtilities schema exists
-- ===========================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.schemas WHERE name = N'ATAPUtilities'
) EXEC ('CREATE SCHEMA ATAPUtilities');
GO

-- ===========================================================
-- DROP in full dependency order so this script is re-runnable
-- ===========================================================
IF OBJECT_ID(N'ATAPUtilities.RuleInstantiationBinding',  N'U') IS NOT NULL DROP TABLE ATAPUtilities.RuleInstantiationBinding;
GO
IF OBJECT_ID(N'ATAPUtilities.RuleInstantiation',         N'U') IS NOT NULL DROP TABLE ATAPUtilities.RuleInstantiation;
GO
IF OBJECT_ID(N'ATAPUtilities.RuleSetMember',             N'U') IS NOT NULL DROP TABLE ATAPUtilities.RuleSetMember;
GO
-- Tables from later migrations that reference RuleSet must be dropped first
IF OBJECT_ID(N'ATAPUtilities.BuildSetMember',            N'U') IS NOT NULL DROP TABLE ATAPUtilities.BuildSetMember;
GO
IF OBJECT_ID(N'ATAPUtilities.BuildSet',                  N'U') IS NOT NULL DROP TABLE ATAPUtilities.BuildSet;
GO
IF OBJECT_ID(N'ATAPUtilities.RuleSet',                   N'U') IS NOT NULL DROP TABLE ATAPUtilities.RuleSet;
GO
IF OBJECT_ID(N'ATAPUtilities.RulePrimitiveComposition',  N'U') IS NOT NULL DROP TABLE ATAPUtilities.RulePrimitiveComposition;
GO
IF OBJECT_ID(N'ATAPUtilities.[Rule]',                    N'U') IS NOT NULL DROP TABLE ATAPUtilities.[Rule];
GO
IF OBJECT_ID(N'ATAPUtilities.RulePrimitiveInput',        N'U') IS NOT NULL DROP TABLE ATAPUtilities.RulePrimitiveInput;
GO
IF OBJECT_ID(N'ATAPUtilities.RulePrimitive',             N'U') IS NOT NULL DROP TABLE ATAPUtilities.RulePrimitive;
GO
IF OBJECT_ID(N'ATAPUtilities.PrimitiveLanguageKind',     N'U') IS NOT NULL DROP TABLE ATAPUtilities.PrimitiveLanguageKind;
GO
IF OBJECT_ID(N'ATAPUtilities.UserSettings',              N'U') IS NOT NULL DROP TABLE ATAPUtilities.UserSettings;
GO
IF OBJECT_ID(N'ATAPUtilities.UserInformation',           N'U') IS NOT NULL DROP TABLE ATAPUtilities.UserInformation;
GO
IF OBJECT_ID(N'ATAPUtilities.[User]',                    N'U') IS NOT NULL DROP TABLE ATAPUtilities.[User];
GO
IF OBJECT_ID(N'ATAPUtilities.PhiloteTimeBlock',          N'U') IS NOT NULL DROP TABLE ATAPUtilities.PhiloteTimeBlock;
GO
IF OBJECT_ID(N'ATAPUtilities.PhiloteAdditionalId',       N'U') IS NOT NULL DROP TABLE ATAPUtilities.PhiloteAdditionalId;
GO
IF OBJECT_ID(N'ATAPUtilities.Philote',                   N'U') IS NOT NULL DROP TABLE ATAPUtilities.Philote;
GO

-- ===========================================================
-- SECTION 1 — Philote Foundation
-- Mirrors the C# GuidPhilote<TId> record:
--   public TId Id { get; init; }
--   public ConcurrentDictionary<string, IAbstractStronglyTypedId<Guid>>? AdditionalIds { get; init; }
--   public IEnumerable<ITimeBlock>? TimeBlocks { get; init; }
-- ===========================================================

CREATE TABLE ATAPUtilities.Philote (
    -- Stable GUID identity — maps to GuidPhilote<TId>.Id.Value
    PhiloteId   UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_Philote_PhiloteId DEFAULT NEWID(),
    CreatedAt   DATETIME2        NOT NULL CONSTRAINT DF_Philote_CreatedAt  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Philote PRIMARY KEY CLUSTERED (PhiloteId)
);
GO

-- Additional secondary IDs for a Philote (the AdditionalIds dictionary)
CREATE TABLE ATAPUtilities.PhiloteAdditionalId (
    PhiloteAdditionalIdId INT              NOT NULL IDENTITY(1,1),
    PhiloteId             UNIQUEIDENTIFIER NOT NULL,
    -- Dictionary key (the string key)
    KeyName               NVARCHAR(200)    NOT NULL,
    -- Dictionary value (GUID variant of IAbstractStronglyTypedId<Guid>)
    ValueId               UNIQUEIDENTIFIER NOT NULL,
    CONSTRAINT PK_PhiloteAdditionalId           PRIMARY KEY CLUSTERED (PhiloteAdditionalIdId),
    CONSTRAINT FK_PhiloteAdditionalId_Philote   FOREIGN KEY (PhiloteId)  REFERENCES ATAPUtilities.Philote (PhiloteId),
    CONSTRAINT UQ_PhiloteAdditionalId_Key       UNIQUE (PhiloteId, KeyName)
);
GO

-- Time blocks associated with a Philote (the TimeBlocks collection)
-- Itenso.TimePeriod.ITimeBlock has a Start and End
CREATE TABLE ATAPUtilities.PhiloteTimeBlock (
    PhiloteTimeBlockId INT              NOT NULL IDENTITY(1,1),
    PhiloteId          UNIQUEIDENTIFIER NOT NULL,
    StartAt            DATETIME2        NOT NULL,
    EndAt              DATETIME2            NULL,
    CONSTRAINT PK_PhiloteTimeBlock              PRIMARY KEY CLUSTERED (PhiloteTimeBlockId),
    CONSTRAINT FK_PhiloteTimeBlock_Philote      FOREIGN KEY (PhiloteId)  REFERENCES ATAPUtilities.Philote (PhiloteId)
);
GO

-- ===========================================================
-- SECTION 2 — Classification Lookup
-- ===========================================================

CREATE TABLE ATAPUtilities.PrimitiveLanguageKind (
    PrimitiveLanguageKindId TINYINT       NOT NULL,
    Name                    NVARCHAR(50)  NOT NULL,
    Description             NVARCHAR(200)     NULL,
    CONSTRAINT PK_PrimitiveLanguageKind      PRIMARY KEY CLUSTERED (PrimitiveLanguageKindId),
    CONSTRAINT UQ_PrimitiveLanguageKind_Name UNIQUE (Name)
);
GO

-- Static lookup data inserted directly (rarely changes)
INSERT INTO ATAPUtilities.PrimitiveLanguageKind (PrimitiveLanguageKindId, Name, Description)
VALUES
    (1, N'CSharp',     N'C# source language primitives and rules'),
    (2, N'Powershell', N'PowerShell script language primitives and rules'),
    (3, N'SQL',        N'T-SQL / SQL Server script primitives and rules'),
    (4, N'MSBuild',    N'MSBuild .csproj XML primitives and rules'),
    (5, N'Snippet',    N'VS Code snippet primitives and rules for code templates'),
    (6, N'Path',       N'Windows filesystem path primitives following EBNF grammar for UNC, absolute, relative, and extended-length paths with validation rules');
GO

-- ===========================================================
-- SECTION 3 — Rule Primitives
-- Holds the atomic BNF building blocks from the Rules Compendium
-- markdown files, each keyed by its stable Philote GUID.
-- Data loaded from CSV via V00.01.000020-000025__Load_ATAPUtilities_*_From_CSV.sql
-- ===========================================================

CREATE TABLE ATAPUtilities.RulePrimitive (
    -- PhiloteId is both the PK and a FK into ATAPUtilities.Philote
    PhiloteId               UNIQUEIDENTIFIER NOT NULL,
    PrimitiveLanguageKindId TINYINT          NOT NULL,
    -- BNF non-terminal name, e.g. '<cs-source-file>'
    Name                    NVARCHAR(200)    NOT NULL,
    Description             NVARCHAR(MAX)        NULL,
    BnfDefinition           NVARCHAR(MAX)        NULL,
    Attribution             NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RulePrimitive                  PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT FK_RulePrimitive_Philote          FOREIGN KEY (PhiloteId)               REFERENCES ATAPUtilities.Philote              (PhiloteId),
    CONSTRAINT FK_RulePrimitive_LanguageKind     FOREIGN KEY (PrimitiveLanguageKindId) REFERENCES ATAPUtilities.PrimitiveLanguageKind (PrimitiveLanguageKindId),
    CONSTRAINT UQ_RulePrimitive_Language_Name    UNIQUE (PrimitiveLanguageKindId, Name)
);
GO

-- Named inputs declared by each primitive
CREATE TABLE ATAPUtilities.RulePrimitiveInput (
    RulePrimitiveInputId INT              NOT NULL IDENTITY(1,1),
    PhiloteId            UNIQUEIDENTIFIER NOT NULL,  -- FK -> RulePrimitive
    InputName            NVARCHAR(200)    NOT NULL,
    TypeName             NVARCHAR(200)        NULL,
    Description          NVARCHAR(MAX)        NULL,
    DefaultValue         NVARCHAR(MAX)        NULL,
    IsRequired           BIT              NOT NULL CONSTRAINT DF_RulePrimitiveInput_IsRequired DEFAULT 1,
    CONSTRAINT PK_RulePrimitiveInput             PRIMARY KEY CLUSTERED (RulePrimitiveInputId),
    CONSTRAINT FK_RulePrimitiveInput_Primitive   FOREIGN KEY (PhiloteId)  REFERENCES ATAPUtilities.RulePrimitive (PhiloteId),
    CONSTRAINT UQ_RulePrimitiveInput_Name        UNIQUE (PhiloteId, InputName)
);
GO

-- ===========================================================
-- SECTION 4 — Rule Definitions
-- A Rule is a named composition of ordered RulePrimitives.
-- Data loaded from CSV via V00.01.000020-000025__Load_ATAPUtilities_*_From_CSV.sql
-- ===========================================================

CREATE TABLE ATAPUtilities.[Rule] (
    PhiloteId               UNIQUEIDENTIFIER NOT NULL,
    PrimitiveLanguageKindId TINYINT          NOT NULL,
    Name                    NVARCHAR(200)    NOT NULL,
    Purpose                 NVARCHAR(MAX)        NULL,
    SourceFileReference     NVARCHAR(500)        NULL,
    CONSTRAINT PK_Rule                           PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT FK_Rule_Philote                   FOREIGN KEY (PhiloteId)               REFERENCES ATAPUtilities.Philote              (PhiloteId),
    CONSTRAINT FK_Rule_LanguageKind              FOREIGN KEY (PrimitiveLanguageKindId) REFERENCES ATAPUtilities.PrimitiveLanguageKind (PrimitiveLanguageKindId),
    CONSTRAINT UQ_Rule_Language_Name             UNIQUE (PrimitiveLanguageKindId, Name)
);
GO

-- Ordered list of primitives composing a Rule, with their bound input values
CREATE TABLE ATAPUtilities.RulePrimitiveComposition (
    RulePrimitiveCompositionId INT              NOT NULL IDENTITY(1,1),
    RulePhiloteId              UNIQUEIDENTIFIER NOT NULL,  -- FK -> Rule
    -- Short label matching the composition table in the compendium (e.g. '1', '2a', '3b')
    SequenceKey                NVARCHAR(20)     NOT NULL,
    PrimitivePhiloteId         UNIQUEIDENTIFIER NOT NULL,  -- FK -> RulePrimitive
    -- JSON object: { "InputName": "BoundValue", ... }
    BoundInputsJson            NVARCHAR(MAX)        NULL,
    Notes                      NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RulePrimitiveComposition       PRIMARY KEY CLUSTERED (RulePrimitiveCompositionId),
    CONSTRAINT FK_RulePC_Rule                    FOREIGN KEY (RulePhiloteId)        REFERENCES ATAPUtilities.[Rule]        (PhiloteId),
    CONSTRAINT FK_RulePC_Primitive               FOREIGN KEY (PrimitivePhiloteId)   REFERENCES ATAPUtilities.RulePrimitive (PhiloteId),
    CONSTRAINT UQ_RulePC_Rule_Key                UNIQUE (RulePhiloteId, SequenceKey)
);
GO

-- ===========================================================
-- SECTION 5 — Rule Sets
-- An ordered collection of Rules that together implement a feature.
-- ===========================================================

CREATE TABLE ATAPUtilities.RuleSet (
    PhiloteId   UNIQUEIDENTIFIER NOT NULL,
    Name        NVARCHAR(200)    NOT NULL,
    Description NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RuleSet            PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT FK_RuleSet_Philote    FOREIGN KEY (PhiloteId)  REFERENCES ATAPUtilities.Philote (PhiloteId),
    CONSTRAINT UQ_RuleSet_Name       UNIQUE (Name)
);
GO

CREATE TABLE ATAPUtilities.RuleSetMember (
    RuleSetMemberId  INT              NOT NULL IDENTITY(1,1),
    RuleSetPhiloteId UNIQUEIDENTIFIER NOT NULL,  -- FK -> RuleSet
    RulePhiloteId    UNIQUEIDENTIFIER NOT NULL,  -- FK -> Rule
    SequenceNumber   INT              NOT NULL,
    Notes            NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RuleSetMember              PRIMARY KEY CLUSTERED (RuleSetMemberId),
    CONSTRAINT FK_RuleSetMember_RuleSet      FOREIGN KEY (RuleSetPhiloteId)  REFERENCES ATAPUtilities.RuleSet  (PhiloteId),
    CONSTRAINT FK_RuleSetMember_Rule         FOREIGN KEY (RulePhiloteId)     REFERENCES ATAPUtilities.[Rule]   (PhiloteId),
    CONSTRAINT UQ_RuleSetMember_Set_Seq      UNIQUE (RuleSetPhiloteId, SequenceNumber)
);
GO

-- ===========================================================
-- SECTION 6 — Rule Instantiations
-- A RuleInstantiation records a specific rendering / binding
-- of a Rule to concrete input values.
-- ===========================================================

CREATE TABLE ATAPUtilities.RuleInstantiation (
    PhiloteId       UNIQUEIDENTIFIER NOT NULL,
    RulePhiloteId   UNIQUEIDENTIFIER NOT NULL,  -- FK -> Rule
    CreatedAt       DATETIME2        NOT NULL CONSTRAINT DF_RuleInstantiation_CreatedAt DEFAULT SYSUTCDATETIME(),
    Notes           NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RuleInstantiation          PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT FK_RuleInstantiation_Philote  FOREIGN KEY (PhiloteId)     REFERENCES ATAPUtilities.Philote (PhiloteId),
    CONSTRAINT FK_RuleInstantiation_Rule     FOREIGN KEY (RulePhiloteId) REFERENCES ATAPUtilities.[Rule]  (PhiloteId)
);
GO

-- Individual input bindings for a RuleInstantiation
CREATE TABLE ATAPUtilities.RuleInstantiationBinding (
    RuleInstantiationBindingId INT              NOT NULL IDENTITY(1,1),
    InstantiationPhiloteId     UNIQUEIDENTIFIER NOT NULL,  -- FK -> RuleInstantiation
    InputName                  NVARCHAR(200)    NOT NULL,
    InputValue                 NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RuleInstantiationBinding                PRIMARY KEY CLUSTERED (RuleInstantiationBindingId),
    CONSTRAINT FK_RuleInstantiationBinding_Instantiation  FOREIGN KEY (InstantiationPhiloteId) REFERENCES ATAPUtilities.RuleInstantiation (PhiloteId),
    CONSTRAINT UQ_RuleInstantiationBinding_Name           UNIQUE (InstantiationPhiloteId, InputName)
);
GO

-- ===========================================================
-- SECTION 7 — Users
-- Three tables represent a user identity:
--   [User]          : binds a Philote to a stable UserId GUID;
--                     also stores the salted+hashed password (Argon2id PHC string),
--                     a SHA-256 hex email hash for indexed lookup, and the
--                     hash algorithm name.
--   UserInformation : PII profile columns keyed by UserId,
--                     stored encrypted (VARBINARY) via
--                     ENCRYPTBYPASSPHRASE / DECRYPTBYPASSPHRASE.
--                     EncryptionKeyVersion tracks which passphrase version
--                     was used (supports zero-downtime key rotation).
--   UserSettings    : UI preference columns keyed by UserId
--
-- PII encryption: all FirstName/LastName/Email/Phone/Role values
--   are stored as VARBINARY(MAX) ciphertext.  Callers decrypt via
--   ATAPUtilities.usp_GetDecryptedUserInformation (V00.01.000302).
--
-- Password storage: SaltedAndHashedPassword holds an Argon2id PHC string
--   of the form  $argon2id$v=19$m=65536,t=3,p=4$<base64_salt>$<base64_hash>
--   produced entirely in the .NET application layer.
--
-- Email lookup: EmailHash is SHA-256 hex of the normalised (trimmed, lowercase)
--   email address.  Allows indexed lookup without exposing PII in queries.
--
-- Constraint: exactly one of Email / Phone must be non-NULL
--   (either email or phone is required, but not both).
--   The CHECK operates on the ciphertext column – NULL means absent.
-- ===========================================================

CREATE TABLE ATAPUtilities.[User] (
    PhiloteId               UNIQUEIDENTIFIER NOT NULL,
    UserId                  UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_User_UserId DEFAULT NEWID(),
    SaltedAndHashedPassword NVARCHAR(500)        NULL,  -- Argon2id PHC string
    EmailHash               CHAR(64)             NULL,  -- SHA-256 hex of normalised email
    HashAlgorithmName       NVARCHAR(50)     NOT NULL CONSTRAINT DF_User_HashAlgorithmName DEFAULT N'Argon2id',
    CONSTRAINT PK_User            PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT FK_User_Philote    FOREIGN KEY (PhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
    CONSTRAINT UQ_User_UserId     UNIQUE (UserId)
);
GO

CREATE INDEX IX_User_EmailHash ON ATAPUtilities.[User] (EmailHash);
GO

CREATE TABLE ATAPUtilities.UserInformation (
    UserId               UNIQUEIDENTIFIER NOT NULL,
    -- PII stored as ciphertext; decrypt via usp_GetDecryptedUserInformation
    FirstName            VARBINARY(MAX)       NULL,
    LastName             VARBINARY(MAX)       NULL,
    Email                VARBINARY(MAX)       NULL,
    Phone                VARBINARY(MAX)       NULL,
    Role                 VARBINARY(MAX)       NULL,
    EncryptionKeyVersion TINYINT              NOT NULL CONSTRAINT DF_UserInformation_EncryptionKeyVersion DEFAULT 1,
    CONSTRAINT PK_UserInformation          PRIMARY KEY CLUSTERED (UserId),
    CONSTRAINT FK_UserInformation_User     FOREIGN KEY (UserId) REFERENCES ATAPUtilities.[User] (UserId),
    CONSTRAINT CK_UserInformation_Contact  CHECK (
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
    CONSTRAINT PK_UserSettings         PRIMARY KEY CLUSTERED (UserId),
    CONSTRAINT FK_UserSettings_User    FOREIGN KEY (UserId) REFERENCES ATAPUtilities.[User] (UserId)
);
GO

-- ===========================================================
-- All Philote, RulePrimitive, and Rule seed data is now loaded
-- from CSV files via V00.01.000020-000025__Load_ATAPUtilities_*_From_CSV.sql
-- User / UserInformation / UserSettings data loaded via V00.01.000030.
-- This keeps schema (DDL) separate from data (DML).
-- ===========================================================

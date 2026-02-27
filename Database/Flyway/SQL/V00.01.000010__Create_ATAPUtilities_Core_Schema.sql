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
   Seed rows for every primitive defined in the Rules Compendium
   markdown files (CSharp, Powershell, SQL, MSBuild).
   ============================================================ */

-- ===========================================================
-- DROP in full dependency order so this script is re-runnable
-- ===========================================================
IF OBJECT_ID(N'dbo.RuleInstantiationBinding',  N'U') IS NOT NULL DROP TABLE dbo.RuleInstantiationBinding;
GO
IF OBJECT_ID(N'dbo.RuleInstantiation',         N'U') IS NOT NULL DROP TABLE dbo.RuleInstantiation;
GO
IF OBJECT_ID(N'dbo.RuleSetMember',             N'U') IS NOT NULL DROP TABLE dbo.RuleSetMember;
GO
IF OBJECT_ID(N'dbo.RuleSet',                   N'U') IS NOT NULL DROP TABLE dbo.RuleSet;
GO
IF OBJECT_ID(N'dbo.RulePrimitiveComposition',  N'U') IS NOT NULL DROP TABLE dbo.RulePrimitiveComposition;
GO
IF OBJECT_ID(N'dbo.Rule',                      N'U') IS NOT NULL DROP TABLE dbo.Rule;
GO
IF OBJECT_ID(N'dbo.RulePrimitiveInput',        N'U') IS NOT NULL DROP TABLE dbo.RulePrimitiveInput;
GO
IF OBJECT_ID(N'dbo.RulePrimitive',             N'U') IS NOT NULL DROP TABLE dbo.RulePrimitive;
GO
IF OBJECT_ID(N'dbo.PrimitiveLanguageKind',     N'U') IS NOT NULL DROP TABLE dbo.PrimitiveLanguageKind;
GO
IF OBJECT_ID(N'dbo.PhiloteTimeBlock',          N'U') IS NOT NULL DROP TABLE dbo.PhiloteTimeBlock;
GO
IF OBJECT_ID(N'dbo.PhiloteAdditionalId',       N'U') IS NOT NULL DROP TABLE dbo.PhiloteAdditionalId;
GO
IF OBJECT_ID(N'dbo.Philote',                   N'U') IS NOT NULL DROP TABLE dbo.Philote;
GO

-- ===========================================================
-- SECTION 1 — Philote Foundation
-- Mirrors the C# GuidPhilote<TId> record:
--   public TId Id { get; init; }
--   public ConcurrentDictionary<string, IAbstractStronglyTypedId<Guid>>? AdditionalIds { get; init; }
--   public IEnumerable<ITimeBlock>? TimeBlocks { get; init; }
-- ===========================================================

CREATE TABLE dbo.Philote (
    -- Stable GUID identity — maps to GuidPhilote<TId>.Id.Value
    PhiloteId   UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_Philote_PhiloteId DEFAULT NEWID(),
    CreatedAt   DATETIME2        NOT NULL CONSTRAINT DF_Philote_CreatedAt  DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Philote PRIMARY KEY CLUSTERED (PhiloteId)
);
GO

-- Additional secondary IDs for a Philote (the AdditionalIds dictionary)
CREATE TABLE dbo.PhiloteAdditionalId (
    PhiloteAdditionalIdId INT              NOT NULL IDENTITY(1,1),
    PhiloteId             UNIQUEIDENTIFIER NOT NULL,
    -- Dictionary key (the string key)
    KeyName               NVARCHAR(200)    NOT NULL,
    -- Dictionary value (GUID variant of IAbstractStronglyTypedId<Guid>)
    ValueId               UNIQUEIDENTIFIER NOT NULL,
    CONSTRAINT PK_PhiloteAdditionalId           PRIMARY KEY CLUSTERED (PhiloteAdditionalIdId),
    CONSTRAINT FK_PhiloteAdditionalId_Philote   FOREIGN KEY (PhiloteId)  REFERENCES dbo.Philote (PhiloteId),
    CONSTRAINT UQ_PhiloteAdditionalId_Key       UNIQUE (PhiloteId, KeyName)
);
GO

-- Time blocks associated with a Philote (the TimeBlocks collection)
-- Itenso.TimePeriod.ITimeBlock has a Start and End
CREATE TABLE dbo.PhiloteTimeBlock (
    PhiloteTimeBlockId INT              NOT NULL IDENTITY(1,1),
    PhiloteId          UNIQUEIDENTIFIER NOT NULL,
    StartAt            DATETIME2        NOT NULL,
    EndAt              DATETIME2            NULL,
    CONSTRAINT PK_PhiloteTimeBlock              PRIMARY KEY CLUSTERED (PhiloteTimeBlockId),
    CONSTRAINT FK_PhiloteTimeBlock_Philote      FOREIGN KEY (PhiloteId)  REFERENCES dbo.Philote (PhiloteId)
);
GO

-- ===========================================================
-- SECTION 2 — Classification Lookup
-- ===========================================================

CREATE TABLE dbo.PrimitiveLanguageKind (
    PrimitiveLanguageKindId TINYINT       NOT NULL,
    Name                    NVARCHAR(50)  NOT NULL,
    Description             NVARCHAR(200)     NULL,
    CONSTRAINT PK_PrimitiveLanguageKind     PRIMARY KEY CLUSTERED (PrimitiveLanguageKindId),
    CONSTRAINT UQ_PrimitiveLanguageKind_Name UNIQUE (Name)
);
GO

-- Static lookup data inserted directly (rarely changes)
INSERT INTO dbo.PrimitiveLanguageKind (PrimitiveLanguageKindId, Name, Description)
VALUES
    (1, N'CSharp',     N'C# source language primitives and rules'),
    (2, N'Powershell', N'PowerShell script language primitives and rules'),
    (3, N'SQL',        N'T-SQL / SQL Server script primitives and rules'),
    (4, N'MSBuild',    N'MSBuild .csproj XML primitives and rules');
GO

-- ===========================================================
-- SECTION 3 — Rule Primitives
-- Holds the atomic BNF building blocks from the Rules Compendium
-- markdown files, each keyed by its stable Philote GUID.
-- Data loaded from CSV via V00.01.000020__Load_ATAPUtilities_Data_From_BCP.sql
-- ===========================================================

CREATE TABLE dbo.RulePrimitive (
    -- PhiloteId is both the PK and a FK into dbo.Philote
    PhiloteId               UNIQUEIDENTIFIER NOT NULL,
    PrimitiveLanguageKindId TINYINT          NOT NULL,
    -- BNF non-terminal name, e.g. '<cs-source-file>'
    Name                    NVARCHAR(200)    NOT NULL,
    Description             NVARCHAR(MAX)        NULL,
    BnfDefinition           NVARCHAR(MAX)        NULL,
    Attribution             NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RulePrimitive                  PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT FK_RulePrimitive_Philote          FOREIGN KEY (PhiloteId)               REFERENCES dbo.Philote             (PhiloteId),
    CONSTRAINT FK_RulePrimitive_LanguageKind     FOREIGN KEY (PrimitiveLanguageKindId) REFERENCES dbo.PrimitiveLanguageKind (PrimitiveLanguageKindId),
    CONSTRAINT UQ_RulePrimitive_Language_Name    UNIQUE (PrimitiveLanguageKindId, Name)
);
GO

-- Named inputs declared by each primitive
CREATE TABLE dbo.RulePrimitiveInput (
    RulePrimitiveInputId INT              NOT NULL IDENTITY(1,1),
    PhiloteId            UNIQUEIDENTIFIER NOT NULL,  -- FK -> RulePrimitive
    InputName            NVARCHAR(200)    NOT NULL,
    TypeName             NVARCHAR(200)        NULL,
    Description          NVARCHAR(MAX)        NULL,
    DefaultValue         NVARCHAR(MAX)        NULL,
    IsRequired           BIT              NOT NULL CONSTRAINT DF_RulePrimitiveInput_IsRequired DEFAULT 1,
    CONSTRAINT PK_RulePrimitiveInput             PRIMARY KEY CLUSTERED (RulePrimitiveInputId),
    CONSTRAINT FK_RulePrimitiveInput_Primitive   FOREIGN KEY (PhiloteId)  REFERENCES dbo.RulePrimitive (PhiloteId),
    CONSTRAINT UQ_RulePrimitiveInput_Name        UNIQUE (PhiloteId, InputName)
);
GO

-- ===========================================================
-- SECTION 4 — Rule Definitions
-- A Rule is a named composition of ordered RulePrimitives.
-- Data loaded from CSV via V00.01.000020__Load_ATAPUtilities_Data_From_BCP.sql
-- ===========================================================

CREATE TABLE dbo.Rule (
    PhiloteId               UNIQUEIDENTIFIER NOT NULL,
    PrimitiveLanguageKindId TINYINT          NOT NULL,
    Name                    NVARCHAR(200)    NOT NULL,
    Purpose                 NVARCHAR(MAX)        NULL,
    SourceFileReference     NVARCHAR(500)        NULL,
    CONSTRAINT PK_Rule                           PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT FK_Rule_Philote                   FOREIGN KEY (PhiloteId)               REFERENCES dbo.Philote             (PhiloteId),
    CONSTRAINT FK_Rule_LanguageKind              FOREIGN KEY (PrimitiveLanguageKindId) REFERENCES dbo.PrimitiveLanguageKind (PrimitiveLanguageKindId),
    CONSTRAINT UQ_Rule_Language_Name             UNIQUE (PrimitiveLanguageKindId, Name)
);
GO

-- Ordered list of primitives composing a Rule, with their bound input values
CREATE TABLE dbo.RulePrimitiveComposition (
    RulePrimitiveCompositionId INT              NOT NULL IDENTITY(1,1),
    RulePhiloteId              UNIQUEIDENTIFIER NOT NULL,  -- FK -> Rule
    -- Short label matching the composition table in the compendium (e.g. '1', '2a', '3b')
    SequenceKey                NVARCHAR(20)     NOT NULL,
    PrimitivePhiloteId         UNIQUEIDENTIFIER NOT NULL,  -- FK -> RulePrimitive
    -- JSON object: { "InputName": "BoundValue", ... }
    BoundInputsJson            NVARCHAR(MAX)        NULL,
    Notes                      NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RulePrimitiveComposition       PRIMARY KEY CLUSTERED (RulePrimitiveCompositionId),
    CONSTRAINT FK_RulePC_Rule                    FOREIGN KEY (RulePhiloteId)        REFERENCES dbo.Rule         (PhiloteId),
    CONSTRAINT FK_RulePC_Primitive               FOREIGN KEY (PrimitivePhiloteId)   REFERENCES dbo.RulePrimitive (PhiloteId),
    CONSTRAINT UQ_RulePC_Rule_Key                UNIQUE (RulePhiloteId, SequenceKey)
);
GO

-- ===========================================================
-- SECTION 5 — Rule Sets
-- An ordered collection of Rules that together implement a feature.
-- ===========================================================

CREATE TABLE dbo.RuleSet (
    PhiloteId   UNIQUEIDENTIFIER NOT NULL,
    Name        NVARCHAR(200)    NOT NULL,
    Description NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RuleSet            PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT FK_RuleSet_Philote    FOREIGN KEY (PhiloteId)  REFERENCES dbo.Philote (PhiloteId),
    CONSTRAINT UQ_RuleSet_Name       UNIQUE (Name)
);
GO

CREATE TABLE dbo.RuleSetMember (
    RuleSetMemberId  INT              NOT NULL IDENTITY(1,1),
    RuleSetPhiloteId UNIQUEIDENTIFIER NOT NULL,  -- FK -> RuleSet
    RulePhiloteId    UNIQUEIDENTIFIER NOT NULL,  -- FK -> Rule
    SequenceNumber   INT              NOT NULL,
    Notes            NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RuleSetMember              PRIMARY KEY CLUSTERED (RuleSetMemberId),
    CONSTRAINT FK_RuleSetMember_RuleSet      FOREIGN KEY (RuleSetPhiloteId)  REFERENCES dbo.RuleSet (PhiloteId),
    CONSTRAINT FK_RuleSetMember_Rule         FOREIGN KEY (RulePhiloteId)     REFERENCES dbo.Rule    (PhiloteId),
    CONSTRAINT UQ_RuleSetMember_Set_Seq      UNIQUE (RuleSetPhiloteId, SequenceNumber)
);
GO

-- ===========================================================
-- SECTION 6 — Rule Instantiations
-- A RuleInstantiation records a specific rendering / binding
-- of a Rule to concrete input values.
-- ===========================================================

CREATE TABLE dbo.RuleInstantiation (
    PhiloteId       UNIQUEIDENTIFIER NOT NULL,
    RulePhiloteId   UNIQUEIDENTIFIER NOT NULL,  -- FK -> Rule
    CreatedAt       DATETIME2        NOT NULL CONSTRAINT DF_RuleInstantiation_CreatedAt DEFAULT SYSUTCDATETIME(),
    Notes           NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RuleInstantiation          PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT FK_RuleInstantiation_Philote  FOREIGN KEY (PhiloteId)     REFERENCES dbo.Philote (PhiloteId),
    CONSTRAINT FK_RuleInstantiation_Rule     FOREIGN KEY (RulePhiloteId) REFERENCES dbo.Rule    (PhiloteId)
);
GO

-- Individual input bindings for a RuleInstantiation
CREATE TABLE dbo.RuleInstantiationBinding (
    RuleInstantiationBindingId INT              NOT NULL IDENTITY(1,1),
    InstantiationPhiloteId     UNIQUEIDENTIFIER NOT NULL,  -- FK -> RuleInstantiation
    InputName                  NVARCHAR(200)    NOT NULL,
    InputValue                 NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_RuleInstantiationBinding                PRIMARY KEY CLUSTERED (RuleInstantiationBindingId),
    CONSTRAINT FK_RuleInstantiationBinding_Instantiation  FOREIGN KEY (InstantiationPhiloteId) REFERENCES dbo.RuleInstantiation (PhiloteId),
    CONSTRAINT UQ_RuleInstantiationBinding_Name           UNIQUE (InstantiationPhiloteId, InputName)
);
GO

-- ===========================================================
-- All Philote, RulePrimitive, and Rule seed data is now loaded
-- from CSV files via V00.01.000020__Load_ATAPUtilities_Data_From_BCP.sql
-- This keeps schema (DDL) separate from data (DML).
-- ===========================================================

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

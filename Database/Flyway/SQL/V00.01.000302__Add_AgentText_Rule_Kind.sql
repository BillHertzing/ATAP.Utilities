-- =====================================================================
-- V00.01.000302__Add_AgentText_Rule_Kind.sql
--
-- Adds the AgentText RRSBS kind and pilot tables used to load and
-- instantiate AI agent/instruction adapter files.
-- =====================================================================
SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRANSACTION;

BEGIN TRY
    IF OBJECT_ID(N'ATAPUtilities.AgentAdapterTarget', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.AgentAdapterTarget (
            AgentAdapterTargetId INT IDENTITY(1,1) NOT NULL,
            AgentTextId UNIQUEIDENTIFIER NOT NULL,
            ToolName NVARCHAR(100) NOT NULL,
            TargetPath NVARCHAR(500) NOT NULL,
            Materialization NVARCHAR(50) NOT NULL,
            RenderedSha256 CHAR(64) NULL,
            RenderedBytes INT NULL,
            CONSTRAINT PK_AgentAdapterTarget PRIMARY KEY CLUSTERED (AgentAdapterTargetId)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.AgentToolSurface', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.AgentToolSurface (
            AgentToolSurfaceId INT IDENTITY(1,1) NOT NULL,
            AgentTextId UNIQUEIDENTIFIER NOT NULL,
            ToolName NVARCHAR(200) NOT NULL,
            CONSTRAINT PK_AgentToolSurface PRIMARY KEY CLUSTERED (AgentToolSurfaceId)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.AgentInstruction', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.AgentInstruction (
            AgentInstructionId INT IDENTITY(1,1) NOT NULL,
            AgentTextId UNIQUEIDENTIFIER NOT NULL,
            SequenceKey NVARCHAR(20) NOT NULL,
            SectionKind NVARCHAR(50) NOT NULL,
            SectionText NVARCHAR(MAX) NOT NULL,
            CONSTRAINT PK_AgentInstruction PRIMARY KEY CLUSTERED (AgentInstructionId)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.AgentTextRoundTrip', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.AgentTextRoundTrip (
            AgentTextId UNIQUEIDENTIFIER NOT NULL,
            RoundTripPolicy NVARCHAR(50) NOT NULL,
            NormalizationNotes NVARCHAR(MAX) NULL,
            CONSTRAINT PK_AgentTextRoundTrip PRIMARY KEY CLUSTERED (AgentTextId)
        );
    END;

    IF OBJECT_ID(N'ATAPUtilities.AgentText', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.AgentText (
            AgentTextId UNIQUEIDENTIFIER NOT NULL,
            SourceId NVARCHAR(200) NOT NULL,
            Kind NVARCHAR(100) NOT NULL,
            DisplayName NVARCHAR(200) NULL,
            SourcePath NVARCHAR(500) NOT NULL,
            BodyFormat NVARCHAR(50) NOT NULL,
            BodySha256 CHAR(64) NOT NULL,
            BodyText NVARCHAR(MAX) NOT NULL,
            CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_AgentText_CreatedAt DEFAULT SYSUTCDATETIME(),
            CONSTRAINT PK_AgentText PRIMARY KEY CLUSTERED (AgentTextId),
            CONSTRAINT UQ_AgentText_SourceId UNIQUE (SourceId)
        );
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_AgentInstruction_AgentText'
    )
    BEGIN
        ALTER TABLE ATAPUtilities.AgentInstruction
        ADD CONSTRAINT FK_AgentInstruction_AgentText
            FOREIGN KEY (AgentTextId) REFERENCES ATAPUtilities.AgentText (AgentTextId);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_AgentToolSurface_AgentText'
    )
    BEGIN
        ALTER TABLE ATAPUtilities.AgentToolSurface
        ADD CONSTRAINT FK_AgentToolSurface_AgentText
            FOREIGN KEY (AgentTextId) REFERENCES ATAPUtilities.AgentText (AgentTextId);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_AgentAdapterTarget_AgentText'
    )
    BEGIN
        ALTER TABLE ATAPUtilities.AgentAdapterTarget
        ADD CONSTRAINT FK_AgentAdapterTarget_AgentText
            FOREIGN KEY (AgentTextId) REFERENCES ATAPUtilities.AgentText (AgentTextId);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_AgentTextRoundTrip_AgentText'
    )
    BEGIN
        ALTER TABLE ATAPUtilities.AgentTextRoundTrip
        ADD CONSTRAINT FK_AgentTextRoundTrip_AgentText
            FOREIGN KEY (AgentTextId) REFERENCES ATAPUtilities.AgentText (AgentTextId);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM ATAPUtilities.PrimitiveLanguageKind
        WHERE PrimitiveLanguageKindId = 8 OR [Name] = N'AgentText'
    )
    BEGIN
        INSERT INTO ATAPUtilities.PrimitiveLanguageKind
            (PrimitiveLanguageKindId, [Name], [Description])
        VALUES
            (8, N'AgentText', N'AI agent and instruction text for generated tool adapters');
    END;

    DECLARE @PrimitiveLanguageKindId TINYINT =
        (SELECT PrimitiveLanguageKindId FROM ATAPUtilities.PrimitiveLanguageKind WHERE [Name] = N'AgentText');

    DECLARE @Primitives TABLE (
        PhiloteId UNIQUEIDENTIFIER NOT NULL,
        [Name] NVARCHAR(200) NOT NULL,
        [Description] NVARCHAR(MAX) NULL
    );

    INSERT INTO @Primitives (PhiloteId, [Name], [Description])
    VALUES
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4be01', N'agent-identity', N'Stable agent, skill, or instruction identity plus metadata.'),
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4be02', N'instruction-body', N'Markdown, TOML, or text body loaded from canonical source files.'),
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4be03', N'tool-surface', N'Minimal native tool declarations for an agent or skill.'),
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4be04', N'runbook-step', N'Ordered workflow step text.'),
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4be05', N'guardrail', N'Boundary, safety, or ownership instruction.'),
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4be06', N'return-contract', N'Structured result contract expected by an orchestrator.'),
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4be07', N'adapter-target', N'Native rendered target path and materialization mode.'),
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4be08', N'round-trip-policy', N'Byte-for-byte or semantic round-trip expectation.');

    INSERT INTO ATAPUtilities.Philote (PhiloteId)
    SELECT p.PhiloteId
    FROM @Primitives AS p
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.Philote AS existing WHERE existing.PhiloteId = p.PhiloteId
    );

    INSERT INTO ATAPUtilities.RulePrimitive
        (PhiloteId, PrimitiveLanguageKindId, [Name], [Description])
    SELECT p.PhiloteId, @PrimitiveLanguageKindId, p.[Name], p.[Description]
    FROM @Primitives AS p
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RulePrimitive AS existing WHERE existing.PhiloteId = p.PhiloteId
    );

    DECLARE @Inputs TABLE (
        PrimitiveName NVARCHAR(200) NOT NULL,
        InputName NVARCHAR(200) NOT NULL,
        TypeName NVARCHAR(200) NULL,
        [Description] NVARCHAR(MAX) NULL,
        DefaultValue NVARCHAR(MAX) NULL,
        IsRequired BIT NOT NULL
    );

    INSERT INTO @Inputs (PrimitiveName, InputName, TypeName, [Description], DefaultValue, IsRequired)
    VALUES
        (N'agent-identity', N'SourceId', N'string', N'Stable manifest or RRSBS identifier.', NULL, 1),
        (N'agent-identity', N'DisplayName', N'string', N'Human-readable name.', NULL, 0),
        (N'instruction-body', N'Body', N'string', N'Raw source body.', NULL, 1),
        (N'instruction-body', N'BodyFormat', N'string', N'markdown, toml, or text.', N'markdown', 1),
        (N'tool-surface', N'Tools', N'string[]', N'Minimal native tool list.', N'[]', 0),
        (N'runbook-step', N'SequenceKey', N'string', N'Ordered sequence key.', NULL, 1),
        (N'guardrail', N'Text', N'string', N'Guardrail text.', NULL, 1),
        (N'return-contract', N'SchemaRef', N'string', N'Return schema reference.', NULL, 0),
        (N'adapter-target', N'Tool', N'string', N'Native tool family.', NULL, 1),
        (N'adapter-target', N'Path', N'string', N'Rendered path relative to consuming repo.', NULL, 1),
        (N'adapter-target', N'Materialization', N'string', N'copy, symlink, junction, or generated-wrapper.', N'copy', 1),
        (N'round-trip-policy', N'Policy', N'string', N'byte-for-byte or semantic.', N'semantic', 1);

    INSERT INTO ATAPUtilities.RulePrimitiveInput
        (PhiloteId, InputName, TypeName, [Description], DefaultValue, IsRequired)
    SELECT rp.PhiloteId, i.InputName, i.TypeName, i.[Description], i.DefaultValue, i.IsRequired
    FROM @Inputs AS i
    INNER JOIN ATAPUtilities.RulePrimitive AS rp
        ON rp.PrimitiveLanguageKindId = @PrimitiveLanguageKindId
       AND rp.[Name] = i.PrimitiveName
    WHERE NOT EXISTS (
        SELECT 1
        FROM ATAPUtilities.RulePrimitiveInput AS existing
        WHERE existing.PhiloteId = rp.PhiloteId
          AND existing.InputName = i.InputName
    );

    DECLARE @RulePhiloteId UNIQUEIDENTIFIER = 'c3b4c3b8-7d41-41e4-8d85-793b83f4bf00';
    IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.Philote WHERE PhiloteId = @RulePhiloteId)
    BEGIN
        INSERT INTO ATAPUtilities.Philote (PhiloteId) VALUES (@RulePhiloteId);
    END;

    IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.[Rule] WHERE PhiloteId = @RulePhiloteId)
    BEGIN
        INSERT INTO ATAPUtilities.[Rule]
            (PhiloteId, PrimitiveLanguageKindId, [Name], Purpose, SourceFileReference)
        VALUES
            (@RulePhiloteId, @PrimitiveLanguageKindId, N'AgentTextDocument',
             N'Composes agent identity, instruction body, tool surface, runbook, guardrails, return contract, adapter targets, and round-trip policy.',
             N'SolutionDocumentation/Rules Compendium.AgentText.md#grammar');
    END;

    DECLARE @Composition TABLE (
        SequenceKey NVARCHAR(20) NOT NULL,
        PrimitiveName NVARCHAR(200) NOT NULL,
        Notes NVARCHAR(MAX) NULL
    );

    INSERT INTO @Composition (SequenceKey, PrimitiveName, Notes)
    VALUES
        (N'001', N'agent-identity', N'Required root identity.'),
        (N'002', N'instruction-body', N'Required body text.'),
        (N'003', N'tool-surface', N'Optional minimal tool list.'),
        (N'004', N'runbook-step', N'Zero or more ordered steps.'),
        (N'005', N'guardrail', N'Zero or more guardrails.'),
        (N'006', N'return-contract', N'Optional structured return contract.'),
        (N'007', N'adapter-target', N'Zero or more native output targets.'),
        (N'008', N'round-trip-policy', N'Required round-trip policy.');

    INSERT INTO ATAPUtilities.RulePrimitiveComposition
        (RulePhiloteId, SequenceKey, PrimitivePhiloteId, BoundInputsJson, Notes)
    SELECT @RulePhiloteId, c.SequenceKey, rp.PhiloteId, NULL, c.Notes
    FROM @Composition AS c
    INNER JOIN ATAPUtilities.RulePrimitive AS rp
        ON rp.PrimitiveLanguageKindId = @PrimitiveLanguageKindId
       AND rp.[Name] = c.PrimitiveName
    WHERE NOT EXISTS (
        SELECT 1
        FROM ATAPUtilities.RulePrimitiveComposition AS existing
        WHERE existing.RulePhiloteId = @RulePhiloteId
          AND existing.SequenceKey = c.SequenceKey
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

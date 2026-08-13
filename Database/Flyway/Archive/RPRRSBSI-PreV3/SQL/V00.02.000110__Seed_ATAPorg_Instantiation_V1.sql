-- =====================================================================
-- V00.02.000110__Seed_ATAPorg_Instantiation_V1.sql
--
-- Sprint 0013 Task 13.79.
-- Adds the approved immutable ordered-source-line model and seeds the first
-- corrected ATAP.org Instantiation graph. The graph reconstructs:
--
--   ATAP.Utilities\src\ATAP.Utilities.PowerShell\public\Write-ArrayIndented.ps1
--
-- and the file bytes whose SHA-256 is:
--   207425988293F2ACA9BAC4A9B72E7F18CA971EB3CF5AFE78FEB46130C219F63A
--
-- Forward-only and re-runnable. No applied migration is edited.
-- =====================================================================
SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRANSACTION;

BEGIN TRY
    IF OBJECT_ID(N'ATAPUtilities.RuleInstantiationVersion', N'U') IS NULL
        THROW 50110, N'V00.02.000110 requires V00.02.000070 RuleInstantiationVersion.', 1;

    IF COL_LENGTH(N'ATAPUtilities.RuleInstantiationVersion', N'EffectiveFrom') IS NULL
        THROW 50110, N'V00.02.000110 requires V00.02.000100 effective dating.', 1;

    -- Task 13.79.g approved model: source lines belong to the immutable
    -- RuleInstantiationVersion, not to mutable/durable bindings. Ordinal is
    -- contiguous, duplicates and blank LineText values are legal, and the
    -- exact terminator is recorded per line.
    IF OBJECT_ID(N'ATAPUtilities.RuleInstantiationVersionSourceLine', N'U') IS NULL
    BEGIN
        CREATE TABLE ATAPUtilities.RuleInstantiationVersionSourceLine (
            RuleInstantiationVersionSourceLineId BIGINT IDENTITY(1,1) NOT NULL,
            RuleInstantiationVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
            Ordinal INT NOT NULL,
            LineText NVARCHAR(MAX) NOT NULL,
            LineEnding NVARCHAR(4) NOT NULL,
            EffectiveFrom DATETIME2(7) NOT NULL CONSTRAINT DF_RIVSourceLine_EffectiveFrom DEFAULT SYSUTCDATETIME(),
            EffectiveTo DATETIME2(7) NULL,
            CONSTRAINT PK_RuleInstantiationVersionSourceLine
                PRIMARY KEY CLUSTERED (RuleInstantiationVersionSourceLineId),
            CONSTRAINT FK_RIVSourceLine_RuleInstantiationVersion
                FOREIGN KEY (RuleInstantiationVersionPhiloteId)
                REFERENCES ATAPUtilities.RuleInstantiationVersion (RuleInstantiationVersionPhiloteId),
            CONSTRAINT CK_RIVSourceLine_Ordinal CHECK (Ordinal >= 1),
            CONSTRAINT CK_RIVSourceLine_LineEnding CHECK (LineEnding IN (N'CRLF', N'LF', N'None')),
            CONSTRAINT CK_RIVSourceLine_EffectiveRange CHECK (EffectiveTo IS NULL OR EffectiveTo > EffectiveFrom),
            CONSTRAINT UQ_RIVSourceLine_Version_Ordinal
                UNIQUE (RuleInstantiationVersionPhiloteId, Ordinal, EffectiveFrom)
        );

        CREATE UNIQUE INDEX UX_RIVSourceLine_CurrentOrdinal
            ON ATAPUtilities.RuleInstantiationVersionSourceLine
                (RuleInstantiationVersionPhiloteId, Ordinal)
            WHERE EffectiveTo IS NULL;
    END;

    IF OBJECT_ID(N'ATAPUtilities.TR_RIVSourceLine_Immutable', N'TR') IS NULL
    BEGIN
        EXEC sp_executesql N'
            CREATE TRIGGER ATAPUtilities.TR_RIVSourceLine_Immutable
            ON ATAPUtilities.RuleInstantiationVersionSourceLine
            AFTER UPDATE, DELETE
            AS
            BEGIN
                SET NOCOUNT ON;
                THROW 50111, N''RuleInstantiationVersionSourceLine rows are immutable; create a new RuleInstantiationVersion.'', 1;
            END;';
    END;

    DECLARE @Now DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @OrganizationPhiloteId UNIQUEIDENTIFIER = 'DB5276A7-4859-44D8-9399-EBCAC39C5481';
    DECLARE @InstantiationPhiloteId UNIQUEIDENTIFIER = 'E2E9C1F7-2C11-4E34-BC72-636D7F5FA948';
    DECLARE @InstantiationVersionPhiloteId UNIQUEIDENTIFIER = '2AF23C2B-A98B-4701-8EFE-1C060C852D61';
    DECLARE @ContentHash CHAR(64) = '207425988293F2ACA9BAC4A9B72E7F18CA971EB3CF5AFE78FEB46130C219F63A';

    DECLARE @NewPhilotes TABLE (PhiloteId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY);
    INSERT INTO @NewPhilotes (PhiloteId)
    VALUES
        -- Reused primitive identities; Philote/primitive rows are inserted
        -- only when a tier's historical CSV load left them absent.
        ('E8F9A0B1-2C3D-4E5F-6A7B-8C9D0E1F2A3B'),
        ('A4B5C6D7-8E9F-0A1B-2C3D-4E5F6A7B8C9D'),
        ('E1A2B3C4-D5E6-4F78-9012-A3B4C5D6E7F8'),
        -- Durable Rule identities.
        ('07F51E62-AE73-45D5-AB14-26CBEC03DEFD'),
        ('5E3F25C1-17C8-4BAC-9EF0-F5825C27D8EC'),
        ('26340D5F-9C62-4896-A32A-F08A15423414'),
        ('6370FC0B-3354-41D8-894C-7D35D2DEE641'),
        ('A24B7319-719A-496F-A993-3C54ABB4ACE7'),
        ('F1B97B54-FC20-42EC-A5D3-554F6B9099DD'),
        ('EDA58265-3075-4D33-B068-2D71379551F3'),
        ('D84CF5C0-40A8-42C9-A0AD-BDDD4F2F74FF'),
        -- RuleVersion identities.
        ('C9680209-4A76-4939-B959-AD3818E3E5AB'),
        ('D62CD6B2-00B2-4405-8CC0-675BE8A39270'),
        ('FD38748F-7C8D-42AD-BAF7-0D6EEBAAB2F1'),
        ('14F66273-E198-4718-BE27-ED902353113E'),
        ('1859BE14-2EA7-496E-AAC9-A11A56D48C51'),
        ('17CDDE5D-2C86-40DD-90AF-A2066E1FC649'),
        ('51DFC62E-27F6-4653-9CDC-6905A363D159'),
        ('B39BC198-07CC-4F74-BA32-4139B2EDBE08'),
        -- RuleSet / RuleSetVersion / BuildSet / BuildSetVersion identities.
        ('41DF5B43-D6C9-4D47-91D4-86EEDB69E049'),
        ('7243902F-BBD5-4E58-BEFB-8987AFADD731'),
        ('2CDF0578-82CF-4574-B933-2CF796065128'),
        ('0A57D59C-C39C-4647-8BB1-52F1E916686E'),
        ('3405677E-CAA9-4ECC-B6E2-8FEC19130749'),
        ('C7B2B89F-7A41-445C-AD45-F5EE05D3B848'),
        -- RuleInstantiation identities.
        ('D7DD8FE3-1743-46CB-8EB2-6CBBCE4F423E'),
        ('0DBAABFB-2236-4DDC-87F7-6CF035C192CD'),
        ('4C667F0C-D121-459D-9E4C-9E816084DD92'),
        ('A78F3677-1E65-40A5-98CF-1CF42C8B7FB3'),
        ('54ED1656-25CD-4C48-9A2B-FF3194507FB9'),
        ('101FF079-68FA-4E1A-B2DA-441990912671'),
        ('B804DF3C-17E2-49CC-93B5-728A33C95B5E'),
        ('645D942A-D260-4A11-B202-70BAE0E0FEB2'),
        -- RuleInstantiationVersion identities.
        ('74A56DF7-E212-44C7-98D9-E77F8FD53A25'),
        ('84995233-3761-496D-9563-618B4763182D'),
        ('24475E3A-B1CE-400C-A328-9821731CD943'),
        ('9DB8871D-7637-4B07-9885-2FB67B449528'),
        ('FBD9676A-3677-4277-AA30-ED1359CB36AB'),
        ('4CC91316-B8B6-4E0F-B114-4F6B73A67653'),
        ('8AF4EB23-7E4D-4536-95E0-FB32885728EA'),
        ('5A1D2179-4E07-4F79-9F8C-3D024FAAFAAC'),
        -- Instantiation, version, and planned artifact identities.
        (@InstantiationPhiloteId),
        (@InstantiationVersionPhiloteId),
        ('A1CEB087-5FAA-4108-AFFF-B8095FB89CAE'),
        ('1DE332A3-13BC-4EA4-9B83-7F15F797DACC'),
        ('8BECCA74-DC45-4CD5-8F55-F3A00CAEF16C'),
        ('2F975D97-9929-4693-8AF7-0CAB1A8D9721'),
        ('AC22D423-7622-4D4E-B6D4-5A757A526635');

    INSERT INTO ATAPUtilities.Philote (PhiloteId, EffectiveFrom)
    SELECT p.PhiloteId, @Now
    FROM @NewPhilotes AS p
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.Philote AS existing
        WHERE existing.PhiloteId = p.PhiloteId
    );

    -- Reuse existing Path and PowerShell primitive identities. Some historical
    -- tiers recorded the loader migration while leaving RulePrimitive empty;
    -- insert only the three definitions required by this graph.
    INSERT INTO ATAPUtilities.RulePrimitive
        (PhiloteId, PrimitiveLanguageKindId, Name, Description, BnfDefinition, Attribution)
    SELECT v.PhiloteId, v.KindId, v.Name, v.Description, v.BnfDefinition,
           N'Sprint 0013 Task 13.79; canonical identities originate in the Path and Powershell CSV seed sets.'
    FROM (VALUES
        (CAST('E8F9A0B1-2C3D-4E5F-6A7B-8C9D0E1F2A3B' AS UNIQUEIDENTIFIER), CAST(6 AS TINYINT), N'<name>', N'File or directory name with exact casing.', N'<name> ::= <namechar>+'),
        (CAST('A4B5C6D7-8E9F-0A1B-2C3D-4E5F6A7B8C9D' AS UNIQUEIDENTIFIER), CAST(6 AS TINYINT), N'<relative-path>', N'Relative path from a manifestation root.', N'<relative-path> ::= <name> (''\'' <name>)*'),
        (CAST('E1A2B3C4-D5E6-4F78-9012-A3B4C5D6E7F8' AS UNIQUEIDENTIFIER), CAST(2 AS TINYINT), N'<complete-powershell-cmdlet>', N'Complete PowerShell source represented as exact ordered lines.', N'<complete-powershell-cmdlet> ::= <source-line>+')
    ) AS v (PhiloteId, KindId, Name, Description, BnfDefinition)
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RulePrimitive AS existing
        WHERE existing.PhiloteId = v.PhiloteId
    );

    -- Add only inputs required by the initial exact-byte model.
    INSERT INTO ATAPUtilities.RulePrimitiveInput
        (PhiloteId, InputName, TypeName, Description, DefaultValue, IsRequired)
    SELECT v.PhiloteId, v.InputName, v.TypeName, v.Description, v.DefaultValue, v.IsRequired
    FROM (VALUES
        (CAST('E8F9A0B1-2C3D-4E5F-6A7B-8C9D0E1F2A3B' AS UNIQUEIDENTIFIER), N'Value', N'string', N'Exact-case path component.', NULL, CAST(1 AS BIT)),
        (CAST('A4B5C6D7-8E9F-0A1B-2C3D-4E5F6A7B8C9D' AS UNIQUEIDENTIFIER), N'Value', N'string', N'Complete relative path using backslash separators.', NULL, CAST(1 AS BIT)),
        (CAST('E1A2B3C4-D5E6-4F78-9012-A3B4C5D6E7F8' AS UNIQUEIDENTIFIER), N'Encoding', N'string', N'Text encoding without normalization.', N'utf8', CAST(1 AS BIT)),
        (CAST('E1A2B3C4-D5E6-4F78-9012-A3B4C5D6E7F8' AS UNIQUEIDENTIFIER), N'Bom', N'string', N'Byte-order mark policy.', N'none', CAST(1 AS BIT)),
        (CAST('E1A2B3C4-D5E6-4F78-9012-A3B4C5D6E7F8' AS UNIQUEIDENTIFIER), N'FinalNewline', N'bool', N'Whether the final source line carries a terminator.', N'true', CAST(1 AS BIT))
    ) AS v (PhiloteId, InputName, TypeName, Description, DefaultValue, IsRequired)
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RulePrimitiveInput AS existing
        WHERE existing.PhiloteId = v.PhiloteId
          AND existing.InputName = v.InputName
    );

    DECLARE @Rules TABLE (
        RulePhiloteId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        KindId TINYINT NOT NULL,
        RuleName NVARCHAR(200) NOT NULL,
        Purpose NVARCHAR(MAX) NOT NULL,
        SourceReference NVARCHAR(500) NOT NULL,
        PrimitivePhiloteId UNIQUEIDENTIFIER NOT NULL
    );
    INSERT INTO @Rules VALUES
        ('07F51E62-AE73-45D5-AB14-26CBEC03DEFD', 6, N'ATAP.org Path Separator', N'Renders one backslash separator.', N'SolutionDocumentation/Rules Compendium.Path.md', 'E8F9A0B1-2C3D-4E5F-6A7B-8C9D0E1F2A3B'),
        ('5E3F25C1-17C8-4BAC-9EF0-F5825C27D8EC', 6, N'ATAP.Utilities Path Node', N'Renders the ATAP.Utilities root component.', N'SolutionDocumentation/Rules Compendium.Path.md', 'E8F9A0B1-2C3D-4E5F-6A7B-8C9D0E1F2A3B'),
        ('26340D5F-9C62-4896-A32A-F08A15423414', 6, N'src Path Node', N'Renders the src component.', N'SolutionDocumentation/Rules Compendium.Path.md', 'E8F9A0B1-2C3D-4E5F-6A7B-8C9D0E1F2A3B'),
        ('6370FC0B-3354-41D8-894C-7D35D2DEE641', 6, N'ATAP.Utilities.PowerShell Path Node', N'Renders the module component.', N'SolutionDocumentation/Rules Compendium.Path.md', 'E8F9A0B1-2C3D-4E5F-6A7B-8C9D0E1F2A3B'),
        ('A24B7319-719A-496F-A993-3C54ABB4ACE7', 6, N'public Path Node', N'Renders lowercase public with exact casing.', N'SolutionDocumentation/Rules Compendium.Path.md', 'E8F9A0B1-2C3D-4E5F-6A7B-8C9D0E1F2A3B'),
        ('F1B97B54-FC20-42EC-A5D3-554F6B9099DD', 6, N'Write-ArrayIndented.ps1 Path Node', N'Renders the file leaf.', N'SolutionDocumentation/Rules Compendium.Path.md', 'E8F9A0B1-2C3D-4E5F-6A7B-8C9D0E1F2A3B'),
        ('EDA58265-3075-4D33-B068-2D71379551F3', 6, N'Write-ArrayIndented Relative Path', N'Renders the complete relative path.', N'SolutionDocumentation/Rules Compendium.Path.md', 'A4B5C6D7-8E9F-0A1B-2C3D-4E5F6A7B8C9D'),
        ('D84CF5C0-40A8-42C9-A0AD-BDDD4F2F74FF', 2, N'Write-ArrayIndented.ps1 Exact Source', N'Renders the captured PowerShell source without byte normalization.', N'src/ATAP.Utilities.PowerShell/public/Write-ArrayIndented.ps1', 'E1A2B3C4-D5E6-4F78-9012-A3B4C5D6E7F8');

    INSERT INTO ATAPUtilities.[Rule]
        (PhiloteId, PrimitiveLanguageKindId, Name, Purpose, SourceFileReference)
    SELECT r.RulePhiloteId, r.KindId, r.RuleName, r.Purpose, r.SourceReference
    FROM @Rules AS r
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.[Rule] AS existing
        WHERE existing.PhiloteId = r.RulePhiloteId
    );

    INSERT INTO ATAPUtilities.RulePrimitiveComposition
        (RulePhiloteId, SequenceKey, PrimitivePhiloteId, BoundInputsJson, Notes)
    SELECT r.RulePhiloteId, N'001', r.PrimitivePhiloteId, NULL,
           N'Initial one-primitive rule; runtime values are supplied by the RuleInstantiation snapshot.'
    FROM @Rules AS r
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RulePrimitiveComposition AS existing
        WHERE existing.RulePhiloteId = r.RulePhiloteId
          AND existing.SequenceKey = N'001'
    );

    DECLARE @RuleVersions TABLE (
        RuleVersionPhiloteId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        RulePhiloteId UNIQUEIDENTIFIER NOT NULL,
        SortOrder INT NOT NULL,
        ContentSha256 CHAR(64) NULL
    );
    INSERT INTO @RuleVersions VALUES
        ('C9680209-4A76-4939-B959-AD3818E3E5AB', '07F51E62-AE73-45D5-AB14-26CBEC03DEFD', 10, NULL),
        ('D62CD6B2-00B2-4405-8CC0-675BE8A39270', '5E3F25C1-17C8-4BAC-9EF0-F5825C27D8EC', 20, NULL),
        ('FD38748F-7C8D-42AD-BAF7-0D6EEBAAB2F1', '26340D5F-9C62-4896-A32A-F08A15423414', 30, NULL),
        ('14F66273-E198-4718-BE27-ED902353113E', '6370FC0B-3354-41D8-894C-7D35D2DEE641', 40, NULL),
        ('1859BE14-2EA7-496E-AAC9-A11A56D48C51', 'A24B7319-719A-496F-A993-3C54ABB4ACE7', 50, NULL),
        ('17CDDE5D-2C86-40DD-90AF-A2066E1FC649', 'F1B97B54-FC20-42EC-A5D3-554F6B9099DD', 60, NULL),
        ('51DFC62E-27F6-4653-9CDC-6905A363D159', 'EDA58265-3075-4D33-B068-2D71379551F3', 70, NULL),
        ('B39BC198-07CC-4F74-BA32-4139B2EDBE08', 'D84CF5C0-40A8-42C9-A0AD-BDDD4F2F74FF', 80, @ContentHash);

    INSERT INTO ATAPUtilities.RuleVersion
        (RuleVersionPhiloteId, RulePhiloteId, VersionNumber, VersionLabel, ParentRuleVersionPhiloteId, SortOrder, ContentSha256, Notes, EffectiveFrom)
    SELECT rv.RuleVersionPhiloteId, rv.RulePhiloteId, 1, N'v1', NULL, rv.SortOrder,
           rv.ContentSha256, N'Sprint 0013 Task 13.79 initial immutable version.', @Now
    FROM @RuleVersions AS rv
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleVersion AS existing
        WHERE existing.RuleVersionPhiloteId = rv.RuleVersionPhiloteId
    );

    INSERT INTO ATAPUtilities.RuleVersionPrimitiveComposition
        (RuleVersionPhiloteId, PrimitivePhiloteId, Position, IsOptional, Cardinality, BoundInputsJson, Notes, EffectiveFrom)
    SELECT rv.RuleVersionPhiloteId, r.PrimitivePhiloteId, 1, 0, N'One', NULL,
           N'Initial immutable primitive composition.', @Now
    FROM @RuleVersions AS rv
    INNER JOIN @Rules AS r ON r.RulePhiloteId = rv.RulePhiloteId
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleVersionPrimitiveComposition AS existing
        WHERE existing.RuleVersionPhiloteId = rv.RuleVersionPhiloteId
          AND existing.Position = 1
    );

    INSERT INTO ATAPUtilities.RuleSet (PhiloteId, Name, Description)
    SELECT v.PhiloteId, v.Name, v.Description
    FROM (VALUES
        (CAST('41DF5B43-D6C9-4D47-91D4-86EEDB69E049' AS UNIQUEIDENTIFIER), N'ATAP.Utilities target path', N'Ordered Rules for the initial target path.'),
        (CAST('7243902F-BBD5-4E58-BEFB-8987AFADD731' AS UNIQUEIDENTIFIER), N'ATAP.Utilities PowerShell files', N'Rules for the initial PowerShell source file.')
    ) AS v (PhiloteId, Name, Description)
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleSet AS existing
        WHERE existing.PhiloteId = v.PhiloteId
    );

    INSERT INTO ATAPUtilities.RuleSetVersion
        (RuleSetVersionPhiloteId, RuleSetPhiloteId, VersionNumber, VersionLabel, ParentRuleSetVersionPhiloteId, SortOrder, Notes, EffectiveFrom)
    SELECT v.VersionId, v.SetId, 1, N'v1', NULL, v.SortOrder,
           N'Sprint 0013 Task 13.79 initial immutable RuleSetVersion.', @Now
    FROM (VALUES
        (CAST('2CDF0578-82CF-4574-B933-2CF796065128' AS UNIQUEIDENTIFIER), CAST('41DF5B43-D6C9-4D47-91D4-86EEDB69E049' AS UNIQUEIDENTIFIER), 10),
        (CAST('0A57D59C-C39C-4647-8BB1-52F1E916686E' AS UNIQUEIDENTIFIER), CAST('7243902F-BBD5-4E58-BEFB-8987AFADD731' AS UNIQUEIDENTIFIER), 20)
    ) AS v (VersionId, SetId, SortOrder)
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleSetVersion AS existing
        WHERE existing.RuleSetVersionPhiloteId = v.VersionId
    );

    INSERT INTO ATAPUtilities.RuleSetVersionMember
        (RuleSetVersionPhiloteId, RuleVersionPhiloteId, SortOrder, Notes, EffectiveFrom)
    SELECT v.SetVersionId, v.RuleVersionId, v.SortOrder,
           N'Sprint 0013 Task 13.79 ordered membership.', @Now
    FROM (VALUES
        (CAST('2CDF0578-82CF-4574-B933-2CF796065128' AS UNIQUEIDENTIFIER), CAST('C9680209-4A76-4939-B959-AD3818E3E5AB' AS UNIQUEIDENTIFIER), 10),
        ('2CDF0578-82CF-4574-B933-2CF796065128', 'D62CD6B2-00B2-4405-8CC0-675BE8A39270', 20),
        ('2CDF0578-82CF-4574-B933-2CF796065128', 'FD38748F-7C8D-42AD-BAF7-0D6EEBAAB2F1', 30),
        ('2CDF0578-82CF-4574-B933-2CF796065128', '14F66273-E198-4718-BE27-ED902353113E', 40),
        ('2CDF0578-82CF-4574-B933-2CF796065128', '1859BE14-2EA7-496E-AAC9-A11A56D48C51', 50),
        ('2CDF0578-82CF-4574-B933-2CF796065128', '17CDDE5D-2C86-40DD-90AF-A2066E1FC649', 60),
        ('2CDF0578-82CF-4574-B933-2CF796065128', '51DFC62E-27F6-4653-9CDC-6905A363D159', 70),
        ('0A57D59C-C39C-4647-8BB1-52F1E916686E', 'B39BC198-07CC-4F74-BA32-4139B2EDBE08', 10)
    ) AS v (SetVersionId, RuleVersionId, SortOrder)
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleSetVersionMember AS existing
        WHERE existing.RuleSetVersionPhiloteId = v.SetVersionId
          AND existing.RuleVersionPhiloteId = v.RuleVersionId
    );

    INSERT INTO ATAPUtilities.BuildSet (PhiloteId, Name, Description)
    SELECT '3405677E-CAA9-4ECC-B6E2-8FEC19130749',
           N'ATAP.Utilities Write-ArrayIndented manifestation',
           N'Initial path and file RuleSets; no Build entity exists.'
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.BuildSet
        WHERE PhiloteId = '3405677E-CAA9-4ECC-B6E2-8FEC19130749'
    );

    INSERT INTO ATAPUtilities.BuildSetVersion
        (BuildSetVersionPhiloteId, BuildSetPhiloteId, VersionNumber, VersionLabel, ParentBuildSetVersionPhiloteId, SortOrder, Notes, EffectiveFrom)
    SELECT 'C7B2B89F-7A41-445C-AD45-F5EE05D3B848',
           '3405677E-CAA9-4ECC-B6E2-8FEC19130749',
           1, N'v1', NULL, 10, N'Initial immutable BuildSetVersion.', @Now
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.BuildSetVersion
        WHERE BuildSetVersionPhiloteId = 'C7B2B89F-7A41-445C-AD45-F5EE05D3B848'
    );

    INSERT INTO ATAPUtilities.BuildSetVersionMember
        (BuildSetVersionPhiloteId, RuleSetVersionPhiloteId, SortOrder, Notes, EffectiveFrom)
    SELECT 'C7B2B89F-7A41-445C-AD45-F5EE05D3B848', v.RuleSetVersionId, v.SortOrder,
           N'Initial ordered RuleSetVersion membership.', @Now
    FROM (VALUES
        (CAST('2CDF0578-82CF-4574-B933-2CF796065128' AS UNIQUEIDENTIFIER), 10),
        (CAST('0A57D59C-C39C-4647-8BB1-52F1E916686E' AS UNIQUEIDENTIFIER), 20)
    ) AS v (RuleSetVersionId, SortOrder)
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.BuildSetVersionMember AS existing
        WHERE existing.BuildSetVersionPhiloteId = 'C7B2B89F-7A41-445C-AD45-F5EE05D3B848'
          AND existing.RuleSetVersionPhiloteId = v.RuleSetVersionId
    );

    INSERT INTO ATAPUtilities.Instantiation
        (InstantiationPhiloteId, OrganizationPhiloteId, InstantiationName, Purpose, Notes)
    SELECT @InstantiationPhiloteId, @OrganizationPhiloteId, N'ATAP.org Source Manifestation',
           N'Versioned RRSBS graph that manifests ATAP.Utilities source artifacts.',
           N'Sprint 0013 Task 13.79 corrected initial graph.'
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.Instantiation
        WHERE InstantiationPhiloteId = @InstantiationPhiloteId
    );

    INSERT INTO ATAPUtilities.InstantiationVersion
        (InstantiationVersionPhiloteId, InstantiationPhiloteId, VersionNumber, VersionLabel, ParentInstantiationVersionPhiloteId, Notes, BuildSetVersionPhiloteId, EffectiveFrom)
    SELECT @InstantiationVersionPhiloteId, @InstantiationPhiloteId, 1,
           N'v1-write-arrayindented', NULL,
           N'Initial exact-byte Write-ArrayIndented.ps1 manifestation.',
           'C7B2B89F-7A41-445C-AD45-F5EE05D3B848', @Now
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.InstantiationVersion
        WHERE InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
    );

    DECLARE @RuleInstantiations TABLE (
        RuleInstantiationPhiloteId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        RulePhiloteId UNIQUEIDENTIFIER NOT NULL,
        RuleVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
        RuleInstantiationVersionPhiloteId UNIQUEIDENTIFIER NOT NULL,
        SortOrder INT NOT NULL
    );
    INSERT INTO @RuleInstantiations VALUES
        ('D7DD8FE3-1743-46CB-8EB2-6CBBCE4F423E', '07F51E62-AE73-45D5-AB14-26CBEC03DEFD', 'C9680209-4A76-4939-B959-AD3818E3E5AB', '74A56DF7-E212-44C7-98D9-E77F8FD53A25', 10),
        ('0DBAABFB-2236-4DDC-87F7-6CF035C192CD', '5E3F25C1-17C8-4BAC-9EF0-F5825C27D8EC', 'D62CD6B2-00B2-4405-8CC0-675BE8A39270', '84995233-3761-496D-9563-618B4763182D', 20),
        ('4C667F0C-D121-459D-9E4C-9E816084DD92', '26340D5F-9C62-4896-A32A-F08A15423414', 'FD38748F-7C8D-42AD-BAF7-0D6EEBAAB2F1', '24475E3A-B1CE-400C-A328-9821731CD943', 30),
        ('A78F3677-1E65-40A5-98CF-1CF42C8B7FB3', '6370FC0B-3354-41D8-894C-7D35D2DEE641', '14F66273-E198-4718-BE27-ED902353113E', '9DB8871D-7637-4B07-9885-2FB67B449528', 40),
        ('54ED1656-25CD-4C48-9A2B-FF3194507FB9', 'A24B7319-719A-496F-A993-3C54ABB4ACE7', '1859BE14-2EA7-496E-AAC9-A11A56D48C51', 'FBD9676A-3677-4277-AA30-ED1359CB36AB', 50),
        ('101FF079-68FA-4E1A-B2DA-441990912671', 'F1B97B54-FC20-42EC-A5D3-554F6B9099DD', '17CDDE5D-2C86-40DD-90AF-A2066E1FC649', '4CC91316-B8B6-4E0F-B114-4F6B73A67653', 60),
        ('B804DF3C-17E2-49CC-93B5-728A33C95B5E', 'EDA58265-3075-4D33-B068-2D71379551F3', '51DFC62E-27F6-4653-9CDC-6905A363D159', '8AF4EB23-7E4D-4536-95E0-FB32885728EA', 70),
        ('645D942A-D260-4A11-B202-70BAE0E0FEB2', 'D84CF5C0-40A8-42C9-A0AD-BDDD4F2F74FF', 'B39BC198-07CC-4F74-BA32-4139B2EDBE08', '5A1D2179-4E07-4F79-9F8C-3D024FAAFAAC', 80);

    INSERT INTO ATAPUtilities.RuleInstantiation
        (PhiloteId, RulePhiloteId, Notes, InstantiationPhiloteId, EffectiveFrom)
    SELECT ri.RuleInstantiationPhiloteId, ri.RulePhiloteId,
           N'Sprint 0013 Task 13.79 durable RuleInstantiation.',
           @InstantiationPhiloteId, @Now
    FROM @RuleInstantiations AS ri
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleInstantiation AS existing
        WHERE existing.PhiloteId = ri.RuleInstantiationPhiloteId
    );

    INSERT INTO ATAPUtilities.RuleInstantiationBinding
        (InstantiationPhiloteId, InputName, InputValue, EffectiveFrom)
    SELECT v.RuleInstantiationPhiloteId, v.InputName, v.InputValue, @Now
    FROM (VALUES
        (CAST('D7DD8FE3-1743-46CB-8EB2-6CBBCE4F423E' AS UNIQUEIDENTIFIER), N'Value', N'\'),
        ('0DBAABFB-2236-4DDC-87F7-6CF035C192CD', N'Value', N'ATAP.Utilities'),
        ('4C667F0C-D121-459D-9E4C-9E816084DD92', N'Value', N'src'),
        ('A78F3677-1E65-40A5-98CF-1CF42C8B7FB3', N'Value', N'ATAP.Utilities.PowerShell'),
        ('54ED1656-25CD-4C48-9A2B-FF3194507FB9', N'Value', N'public'),
        ('101FF079-68FA-4E1A-B2DA-441990912671', N'Value', N'Write-ArrayIndented.ps1'),
        ('B804DF3C-17E2-49CC-93B5-728A33C95B5E', N'Value', N'ATAP.Utilities\src\ATAP.Utilities.PowerShell\public\Write-ArrayIndented.ps1'),
        ('645D942A-D260-4A11-B202-70BAE0E0FEB2', N'Encoding', N'utf8'),
        ('645D942A-D260-4A11-B202-70BAE0E0FEB2', N'Bom', N'none'),
        ('645D942A-D260-4A11-B202-70BAE0E0FEB2', N'FinalNewline', N'true')
    ) AS v (RuleInstantiationPhiloteId, InputName, InputValue)
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleInstantiationBinding AS existing
        WHERE existing.InstantiationPhiloteId = v.RuleInstantiationPhiloteId
          AND existing.InputName = v.InputName
          AND existing.EffectiveTo IS NULL
    );

    INSERT INTO ATAPUtilities.RuleInstantiationVersion
        (RuleInstantiationVersionPhiloteId, RuleInstantiationPhiloteId, RuleVersionPhiloteId, RulePhiloteId, VersionNumber, VersionLabel, ParentRuleInstantiationVersionPhiloteId, Notes, EffectiveFrom)
    SELECT ri.RuleInstantiationVersionPhiloteId, ri.RuleInstantiationPhiloteId,
           ri.RuleVersionPhiloteId, ri.RulePhiloteId, 1, N'v1', NULL,
           N'Sprint 0013 Task 13.79 immutable input snapshot.', @Now
    FROM @RuleInstantiations AS ri
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleInstantiationVersion AS existing
        WHERE existing.RuleInstantiationVersionPhiloteId = ri.RuleInstantiationVersionPhiloteId
    );

    INSERT INTO ATAPUtilities.InstantiationVersionRuleInstantiationVersion
        (InstantiationVersionPhiloteId, RuleInstantiationVersionPhiloteId, SortOrder, Notes, EffectiveFrom)
    SELECT @InstantiationVersionPhiloteId, ri.RuleInstantiationVersionPhiloteId,
           ri.SortOrder, N'Initial immutable InstantiationVersion snapshot.', @Now
    FROM @RuleInstantiations AS ri
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion AS existing
        WHERE existing.InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
          AND existing.RuleInstantiationVersionPhiloteId = ri.RuleInstantiationVersionPhiloteId
    );

    DECLARE @SourceLines TABLE (
        Ordinal INT NOT NULL PRIMARY KEY,
        LineText NVARCHAR(MAX) NOT NULL,
        LineEnding NVARCHAR(4) NOT NULL
    );
    INSERT INTO @SourceLines (Ordinal, LineText, LineEnding)
    VALUES
        (1, N'<#', N'CRLF'),
        (2, N'.SYNOPSIS', N'CRLF'),
        (3, N'  Formats an array as an indented string representation.', N'CRLF'),
        (4, N'.DESCRIPTION', N'CRLF'),
        (5, N'  Recursively converts an array to a multi-line indented string, expanding nested', N'CRLF'),
        (6, N'  arrays and hashtables at each level. Intended for diagnostic display of complex', N'CRLF'),
        (7, N'  data structures (e.g., inside the AllUsersAllHosts profile or diagnostic scripts).', N'CRLF'),
        (8, N'.PARAMETER Array', N'CRLF'),
        (9, N'  The array to format.', N'CRLF'),
        (10, N'.PARAMETER Indent', N'CRLF'),
        (11, N'  The current indentation level in spaces.', N'CRLF'),
        (12, N'.PARAMETER IndentIncrement', N'CRLF'),
        (13, N'  The number of additional spaces to add at each nesting level. Defaults to 2.', N'CRLF'),
        (14, N'.OUTPUTS', N'CRLF'),
        (15, N'  [string] An indented string representation of the array.', N'CRLF'),
        (16, N'.EXAMPLE', N'CRLF'),
        (17, N'  Write-ArrayIndented -Array @(''a'', ''b'', @{x=1}) -Indent 0 -IndentIncrement 2', N'CRLF'),
        (18, N'  Returns a multi-line string showing the array contents with nested structures indented.', N'CRLF'),
        (19, N'.NOTES', N'CRLF'),
        (20, N'  Moved from AllUsersAllHostsV7CoreProfile.ps1 into the ATAP.Utilities.PowerShell', N'CRLF'),
        (21, N'  module as part of SC-0183 (reduce profile loading times).', N'CRLF'),
        (22, N'.LINK', N'CRLF'),
        (23, N'  Write-HashIndented', N'CRLF'),
        (24, N'.LINK', N'CRLF'),
        (25, N'  Write-KVPIndented', N'CRLF'),
        (26, N'.LINK', N'CRLF'),
        (27, N'  Write-EnvironmentVariablesIndented', N'CRLF'),
        (28, N'#>', N'CRLF'),
        (29, N'function Write-ArrayIndented {', N'CRLF'),
        (30, N'  [CmdletBinding()]', N'CRLF'),
        (31, N'  param (', N'CRLF'),
        (32, N'    [Parameter(Position = 0)]', N'CRLF'),
        (33, N'    $Array,', N'CRLF'),
        (34, N'    [Parameter(Position = 1)]', N'CRLF'),
        (35, N'    [int] $Indent = 0,', N'CRLF'),
        (36, N'    [Parameter(Position = 2)]', N'CRLF'),
        (37, N'    [int] $IndentIncrement = 2', N'CRLF'),
        (38, N'  )', N'CRLF'),
        (39, N'  begin {', N'CRLF'),
        (40, N'    $fn = $MyInvocation.MyCommand.Name', N'CRLF'),
        (41, N'    $mn = ''ATAP.Utilities.PowerShell''', N'CRLF'),
        (42, N'    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message ''Starting Write-ArrayIndented''', N'CRLF'),
        (43, N'  }', N'CRLF'),
        (44, N'  process {', N'CRLF'),
        (45, N'    $outstr = ''''', N'CRLF'),
        (46, N'    foreach ($item in $Array) {', N'CRLF'),
        (47, N'      if ($null -eq $item) {', N'CRLF'),
        (48, N'        $outstr += '' '' * $Indent + ''(null)'' + [Environment]::NewLine', N'CRLF'),
        (49, N'      }', N'CRLF'),
        (50, N'      elseif ($item -is [System.Boolean]) {', N'CRLF'),
        (51, N'        $outstr += '' '' * $Indent + [string]$item + [Environment]::NewLine', N'CRLF'),
        (52, N'      }', N'CRLF'),
        (53, N'      elseif ($item -is [System.String]) {', N'CRLF'),
        (54, N'        $outstr += '' '' * $Indent + $item + [Environment]::NewLine', N'CRLF'),
        (55, N'      }', N'CRLF'),
        (56, N'      elseif ($item -is [System.Array]) {', N'CRLF'),
        (57, N'        $outstr += '' '' * $Indent + ''('' + [Environment]::NewLine', N'CRLF'),
        (58, N'        $outstr += Write-ArrayIndented -Array $item -Indent ($Indent + $IndentIncrement) -IndentIncrement $IndentIncrement', N'CRLF'),
        (59, N'        $outstr += '' '' * $Indent + '')'' + [Environment]::NewLine', N'CRLF'),
        (60, N'      }', N'CRLF'),
        (61, N'      elseif ($item -is [System.Collections.Hashtable]) {', N'CRLF'),
        (62, N'        $outstr += '' '' * $Indent + ''{'' + [Environment]::NewLine', N'CRLF'),
        (63, N'        $outstr += Write-HashIndented -Hash $item -InitialIndent ($Indent + $IndentIncrement) -IndentIncrement $IndentIncrement', N'CRLF'),
        (64, N'        $outstr += '' '' * $Indent + ''}'' + [Environment]::NewLine', N'CRLF'),
        (65, N'      }', N'CRLF'),
        (66, N'      else {', N'CRLF'),
        (67, N'        $outstr += '' '' * $Indent + [string]$item + [Environment]::NewLine', N'CRLF'),
        (68, N'      }', N'CRLF'),
        (69, N'    }', N'CRLF'),
        (70, N'    $outstr', N'CRLF'),
        (71, N'  }', N'CRLF'),
        (72, N'  end {', N'CRLF'),
        (73, N'    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message ''Completed Write-ArrayIndented''', N'CRLF'),
        (74, N'  }', N'CRLF'),
        (75, N'}', N'CRLF');

    INSERT INTO ATAPUtilities.RuleInstantiationVersionSourceLine
        (RuleInstantiationVersionPhiloteId, Ordinal, LineText, LineEnding, EffectiveFrom)
    SELECT '5A1D2179-4E07-4F79-9F8C-3D024FAAFAAC',
           s.Ordinal, s.LineText, s.LineEnding, @Now
    FROM @SourceLines AS s
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleInstantiationVersionSourceLine AS existing
        WHERE existing.RuleInstantiationVersionPhiloteId = '5A1D2179-4E07-4F79-9F8C-3D024FAAFAAC'
          AND existing.Ordinal = s.Ordinal
          AND existing.EffectiveTo IS NULL
    );

    -- Expected artifacts only. Task 13.83 separately approves the first
    -- filesystem write and records observed RenderFromModel provenance.
    INSERT INTO ATAPUtilities.ManifestationArtifact
        (ManifestationArtifactPhiloteId, InstantiationVersionPhiloteId, ArtifactKind, RelativePath,
         SourceObjectKind, SourceObjectPhiloteId, ContentSha256, RenderPolicy, SortOrder, Notes,
         BuildSetVersionPhiloteId, ProducingRuleInstantiationPhiloteId,
         ProducingRuleInstantiationVersionPhiloteId, EffectiveFrom)
    SELECT v.ArtifactId, @InstantiationVersionPhiloteId, v.ArtifactKind, v.RelativePath,
           v.SourceObjectKind, v.SourceObjectId, v.ContentSha256, N'Planned', v.SortOrder,
           N'Expected artifact; no filesystem write occurred in Task 13.79.',
           'C7B2B89F-7A41-445C-AD45-F5EE05D3B848',
           v.RuleInstantiationId, v.RuleInstantiationVersionId, @Now
    FROM (VALUES
        (CAST('A1CEB087-5FAA-4108-AFFF-B8095FB89CAE' AS UNIQUEIDENTIFIER), N'Directory', N'ATAP.Utilities', N'RuleInstantiationVersion', CAST('84995233-3761-496D-9563-618B4763182D' AS UNIQUEIDENTIFIER), CAST(NULL AS CHAR(64)), 10, CAST('0DBAABFB-2236-4DDC-87F7-6CF035C192CD' AS UNIQUEIDENTIFIER), CAST('84995233-3761-496D-9563-618B4763182D' AS UNIQUEIDENTIFIER)),
        ('1DE332A3-13BC-4EA4-9B83-7F15F797DACC', N'Directory', N'ATAP.Utilities\src', N'RuleInstantiationVersion', '24475E3A-B1CE-400C-A328-9821731CD943', NULL, 20, '4C667F0C-D121-459D-9E4C-9E816084DD92', '24475E3A-B1CE-400C-A328-9821731CD943'),
        ('8BECCA74-DC45-4CD5-8F55-F3A00CAEF16C', N'Directory', N'ATAP.Utilities\src\ATAP.Utilities.PowerShell', N'RuleInstantiationVersion', '9DB8871D-7637-4B07-9885-2FB67B449528', NULL, 30, 'A78F3677-1E65-40A5-98CF-1CF42C8B7FB3', '9DB8871D-7637-4B07-9885-2FB67B449528'),
        ('2F975D97-9929-4693-8AF7-0CAB1A8D9721', N'Directory', N'ATAP.Utilities\src\ATAP.Utilities.PowerShell\public', N'RuleInstantiationVersion', 'FBD9676A-3677-4277-AA30-ED1359CB36AB', NULL, 40, '54ED1656-25CD-4C48-9A2B-FF3194507FB9', 'FBD9676A-3677-4277-AA30-ED1359CB36AB'),
        ('AC22D423-7622-4D4E-B6D4-5A757A526635', N'ModuleSource', N'ATAP.Utilities\src\ATAP.Utilities.PowerShell\public\Write-ArrayIndented.ps1', N'RuleInstantiationVersion', '5A1D2179-4E07-4F79-9F8C-3D024FAAFAAC', @ContentHash, 50, '645D942A-D260-4A11-B202-70BAE0E0FEB2', '5A1D2179-4E07-4F79-9F8C-3D024FAAFAAC')
    ) AS v (ArtifactId, ArtifactKind, RelativePath, SourceObjectKind, SourceObjectId, ContentSha256, SortOrder, RuleInstantiationId, RuleInstantiationVersionId)
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.ManifestationArtifact AS existing
        WHERE existing.InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
          AND existing.RelativePath = v.RelativePath
          AND existing.EffectiveTo IS NULL
    );

    -- In-transaction seed acceptance.
    IF (SELECT COUNT(*) FROM ATAPUtilities.RuleInstantiationVersionSourceLine
        WHERE RuleInstantiationVersionPhiloteId = '5A1D2179-4E07-4F79-9F8C-3D024FAAFAAC'
          AND EffectiveTo IS NULL) <> 75
        THROW 50112, N'V00.02.000110 expected exactly 75 terminated source-line rows.', 1;

    IF EXISTS (
        SELECT 1
        FROM ATAPUtilities.RuleInstantiationVersionSourceLine
        WHERE RuleInstantiationVersionPhiloteId = '5A1D2179-4E07-4F79-9F8C-3D024FAAFAAC'
          AND EffectiveTo IS NULL
        GROUP BY RuleInstantiationVersionPhiloteId
        HAVING MIN(Ordinal) <> 1 OR MAX(Ordinal) <> COUNT(*) OR COUNT(DISTINCT Ordinal) <> COUNT(*)
    )
        THROW 50113, N'V00.02.000110 source-line ordinals are not contiguous and unique.', 1;

    IF (SELECT COUNT(*) FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion
        WHERE InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
          AND EffectiveTo IS NULL) <> 8
        THROW 50114, N'V00.02.000110 expected eight RuleInstantiationVersion snapshot members.', 1;

    IF (SELECT COUNT(*) FROM ATAPUtilities.ManifestationArtifact
        WHERE InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
          AND EffectiveTo IS NULL) <> 5
        THROW 50115, N'V00.02.000110 expected five planned artifacts.', 1;

    IF OBJECT_ID(N'ATAPUtilities.Build', N'U') IS NOT NULL
       OR OBJECT_ID(N'ATAPUtilities.BuildVersion', N'U') IS NOT NULL
        THROW 50116, N'V00.02.000110 forbids Build and BuildVersion entities.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

PRINT N'V00.02.000110 - ATAP.org InstantiationVersion 1 graph and exact Write-ArrayIndented.ps1 source seeded.';

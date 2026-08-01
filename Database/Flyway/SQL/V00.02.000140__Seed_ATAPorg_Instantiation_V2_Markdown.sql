-- =====================================================================
-- V00.02.000140__Seed_ATAPorg_Instantiation_V2_Markdown.sql
-- Sprint 0013 Task 13.85
-- Canonical migration approved 2026-07-30.
--
-- Adds immutable Markdown source Rules and InstantiationVersion 2.
-- InstantiationVersion 1 membership, bindings, source, and artifacts are
-- never updated or retired. Its version row and the predecessor RuleSet /
-- BuildSet version rows have only EffectiveTo closed, as required by the
-- one-current-version indexes installed by V00.02.000100.
-- =====================================================================
SET XACT_ABORT ON;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;

BEGIN TRANSACTION;

BEGIN TRY
    IF NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.PrimitiveLanguageKind
        WHERE PrimitiveLanguageKindId = 10 AND [Name] = N'Markdown'
    )
        THROW 50140, N'V00.02.000140 requires the Markdown Kind from V00.02.000130.', 1;

    IF NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.InstantiationVersion
        WHERE InstantiationVersionPhiloteId = '2AF23C2B-A98B-4701-8EFE-1C060C852D61'
    )
        THROW 50140, N'V00.02.000140 requires InstantiationVersion 1 from V00.02.000110.', 1;

    DECLARE @Now DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @InstantiationPhiloteId UNIQUEIDENTIFIER = 'E2E9C1F7-2C11-4E34-BC72-636D7F5FA948';
    DECLARE @ParentInstantiationVersionPhiloteId UNIQUEIDENTIFIER = '2AF23C2B-A98B-4701-8EFE-1C060C852D61';
    DECLARE @InstantiationVersionPhiloteId UNIQUEIDENTIFIER = '8E98B9B4-8AC2-4713-B11E-7A8D4071C0B0';
    DECLARE @IndexHash CHAR(64) = '5F55E818ABF0B688FFDA37BDDB7BBF8075F11E1EEF39C76B742290AC56C03BE5';
    DECLARE @WriteHash CHAR(64) = '1EFAA5653D8599CBAB47303BAC59FD0E8617BD1969874A4E6EF99EB114EFD807';

    DECLARE @NewPhilotes TABLE (PhiloteId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY);
    INSERT INTO @NewPhilotes (PhiloteId)
    VALUES
        ('4400C20B-6EE3-47E4-ABF8-49D135647803'),
        ('6928C46F-459C-4056-AAD4-01B02837C06B'),
        ('CA7DFAFA-7F72-4B71-BC54-34D0DBF03345'),
        ('0B4D2A2E-5A63-4371-99E3-73469D385E1D'),
        ('627E8299-D172-42FF-B26A-E986B5870A95'),
        ('ED4D3918-5EE3-4E69-AEDE-A18A6AEEF0A4'),
        ('CD159B80-0A4B-46BD-AE9C-6B5DBE2D99B4'),
        ('FC496F63-3C77-4623-BF10-7C21516F72B9'),
        ('ACA6C8EA-7646-4202-8B88-C9F10EF28B03'),
        ('5876C706-DDE3-4B5B-82BD-24E8FA8ABF9A'),
        ('8A5F60CA-8D7E-4DB9-8E4A-7DC274A41FDC'),
        ('C67E59A0-9BCC-4B90-949A-9294DB021B37'),
        ('EA8E2DF4-A556-4CDB-A424-9158D02F666D'),
        ('5F9857B0-BB9A-4A80-A8CC-3364607D33A1'),
        ('84FEC2AA-D0A9-4735-9F18-8B9BA72B5732'),
        ('09FC6BBB-B54C-4E83-915D-E64162AF7800'),
        ('ED4DD2F6-1A34-4851-A562-0B967DBAAD54'),
        ('57129F96-B843-4574-856E-FB34034D5F67'),
        ('D60EBDD1-5AB6-4740-B712-EADEB78AA96A'),
        ('06838A2C-B3E8-4230-B3A3-52AB7984EE85'),
        ('12AA90E6-D541-427F-A635-09F1C0DE96FA'),
        ('51C428DE-3591-4F46-8AFB-CDF7279446F5'),
        ('974E0B9D-12CA-4B84-9B7B-22CB691D4688'),
        ('4F243AF6-B297-4222-8503-8E8F273B704C'),
        ('91B76D60-E26C-41F7-9EA9-025916CDF4C6'),
        ('00698F6A-826A-417D-841D-CA23A9B944C8'),
        ('F54E2878-F7D6-41ED-883E-B02A16AC2567'),
        ('21738901-03B5-4143-88E8-3D93A3EEB4B7'),
        ('03BF1DD5-0341-4D22-B764-3887F55C9962'),
        ('AE97CAFC-0C76-46A5-8E1E-F986DD7ABC24'),
        ('BEFB3248-501F-4FE3-B6DA-825FB4B968B7'),
        (@InstantiationVersionPhiloteId),
        ('602FD59A-4332-44AE-9624-F3FE930C87A5'),
        ('22DB5CA7-BDFD-4366-806E-21A205280B4E'),
        ('6CC1F4E9-8C8D-4320-968E-D5A7CDDA3AF0');

    INSERT INTO ATAPUtilities.Philote (PhiloteId, EffectiveFrom)
    SELECT p.PhiloteId, @Now
    FROM @NewPhilotes AS p
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.Philote AS existing
        WHERE existing.PhiloteId = p.PhiloteId
    );

    DECLARE @Rules TABLE (
        RulePhiloteId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        KindId TINYINT NOT NULL,
        RuleName NVARCHAR(200) NOT NULL,
        Purpose NVARCHAR(MAX) NOT NULL,
        SourceReference NVARCHAR(500) NOT NULL,
        PrimitivePhiloteId UNIQUEIDENTIFIER NOT NULL,
        CompositionNotes NVARCHAR(MAX) NOT NULL
    );

    INSERT INTO @Rules VALUES
        ('4400C20B-6EE3-47E4-ABF8-49D135647803', 6, N'Documentation Path Node',
         N'Renders the exact-case Documentation directory component.',
         N'SolutionDocumentation/Rules Compendium.Path.md',
         'E8F9A0B1-2C3D-4E5F-6A7B-8C9D0E1F2A3B', N'Cardinality 1; exact-case path component.'),
        ('6928C46F-459C-4056-AAD4-01B02837C06B', 6, N'INDEX.md Path Node',
         N'Renders the exact-case INDEX.md file component.',
         N'SolutionDocumentation/Rules Compendium.Path.md',
         'E8F9A0B1-2C3D-4E5F-6A7B-8C9D0E1F2A3B', N'Cardinality 1; exact-case path component.'),
        ('CA7DFAFA-7F72-4B71-BC54-34D0DBF03345', 6, N'Write-ArrayIndented.md Path Node',
         N'Renders the exact-case Write-ArrayIndented.md file component.',
         N'SolutionDocumentation/Rules Compendium.Path.md',
         'E8F9A0B1-2C3D-4E5F-6A7B-8C9D0E1F2A3B', N'Cardinality 1; exact-case path component.'),
        ('0B4D2A2E-5A63-4371-99E3-73469D385E1D', 6, N'INDEX.md Relative Path',
         N'Renders the complete INDEX.md manifestation path.',
         N'SolutionDocumentation/Rules Compendium.Path.md',
         'A4B5C6D7-8E9F-0A1B-2C3D-4E5F6A7B8C9D', N'Cardinality 1; complete relative path.'),
        ('627E8299-D172-42FF-B26A-E986B5870A95', 6, N'Write-ArrayIndented.md Relative Path',
         N'Renders the complete Write-ArrayIndented.md manifestation path.',
         N'SolutionDocumentation/Rules Compendium.Path.md',
         'A4B5C6D7-8E9F-0A1B-2C3D-4E5F6A7B8C9D', N'Cardinality 1; complete relative path.'),
        ('ED4D3918-5EE3-4E69-AEDE-A18A6AEEF0A4', 10, N'INDEX.md Exact Markdown Source',
         N'Renders frozen INDEX.md bytes from ordered source lines.',
         N'src/ATAP.Utilities.PowerShell/Documentation/INDEX.md',
         '06999547-9C11-4F71-8350-763DE0C925DF', N'Cardinality +; ordered SourceLine rows preserve exact bytes.'),
        ('CD159B80-0A4B-46BD-AE9C-6B5DBE2D99B4', 10, N'Write-ArrayIndented.md Exact Markdown Source',
         N'Renders frozen Write-ArrayIndented.md bytes from ordered source lines.',
         N'src/ATAP.Utilities.PowerShell/Documentation/Write-ArrayIndented.md',
         '06999547-9C11-4F71-8350-763DE0C925DF', N'Cardinality +; ordered SourceLine rows preserve exact bytes.');

    INSERT INTO ATAPUtilities.[Rule]
        (PhiloteId, PrimitiveLanguageKindId, Name, Purpose, SourceFileReference)
    SELECT r.RulePhiloteId, r.KindId, r.RuleName, r.Purpose, r.SourceReference
    FROM @Rules AS r
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.[Rule] AS existing
        WHERE existing.PrimitiveLanguageKindId = r.KindId
          AND existing.[Name] = r.RuleName
    );

    INSERT INTO ATAPUtilities.RulePrimitiveComposition
        (RulePhiloteId, SequenceKey, PrimitivePhiloteId, BoundInputsJson, Notes)
    SELECT r.RulePhiloteId, N'001', r.PrimitivePhiloteId, NULL, r.CompositionNotes
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
        ContentSha256 CHAR(64) NULL,
        PrimitivePhiloteId UNIQUEIDENTIFIER NOT NULL,
        Cardinality NVARCHAR(20) NOT NULL
    );

    INSERT INTO @RuleVersions VALUES
        ('FC496F63-3C77-4623-BF10-7C21516F72B9', '4400C20B-6EE3-47E4-ABF8-49D135647803',  80, NULL, 'E8F9A0B1-2C3D-4E5F-6A7B-8C9D0E1F2A3B', N'One'),
        ('ACA6C8EA-7646-4202-8B88-C9F10EF28B03', '6928C46F-459C-4056-AAD4-01B02837C06B',  90, NULL, 'E8F9A0B1-2C3D-4E5F-6A7B-8C9D0E1F2A3B', N'One'),
        ('5876C706-DDE3-4B5B-82BD-24E8FA8ABF9A', 'CA7DFAFA-7F72-4B71-BC54-34D0DBF03345', 100, NULL, 'E8F9A0B1-2C3D-4E5F-6A7B-8C9D0E1F2A3B', N'One'),
        ('8A5F60CA-8D7E-4DB9-8E4A-7DC274A41FDC', '0B4D2A2E-5A63-4371-99E3-73469D385E1D', 110, NULL, 'A4B5C6D7-8E9F-0A1B-2C3D-4E5F6A7B8C9D', N'One'),
        ('C67E59A0-9BCC-4B90-949A-9294DB021B37', '627E8299-D172-42FF-B26A-E986B5870A95', 120, NULL, 'A4B5C6D7-8E9F-0A1B-2C3D-4E5F6A7B8C9D', N'One'),
        ('EA8E2DF4-A556-4CDB-A424-9158D02F666D', 'ED4D3918-5EE3-4E69-AEDE-A18A6AEEF0A4', 130, @IndexHash, '06999547-9C11-4F71-8350-763DE0C925DF', N'OneOrMore'),
        ('5F9857B0-BB9A-4A80-A8CC-3364607D33A1', 'CD159B80-0A4B-46BD-AE9C-6B5DBE2D99B4', 140, @WriteHash, '06999547-9C11-4F71-8350-763DE0C925DF', N'OneOrMore');

    INSERT INTO ATAPUtilities.RuleVersion
        (RuleVersionPhiloteId, RulePhiloteId, VersionNumber, VersionLabel,
         ParentRuleVersionPhiloteId, SortOrder, ContentSha256, Notes, EffectiveFrom)
    SELECT rv.RuleVersionPhiloteId, rv.RulePhiloteId, 1, N'v1', NULL,
           rv.SortOrder, rv.ContentSha256,
           N'Sprint 0013 Task 13.85 immutable Markdown slice.', @Now
    FROM @RuleVersions AS rv
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleVersion AS existing
        WHERE existing.RuleVersionPhiloteId = rv.RuleVersionPhiloteId
    );

    INSERT INTO ATAPUtilities.RuleVersionPrimitiveComposition
        (RuleVersionPhiloteId, PrimitivePhiloteId, Position, IsOptional,
         Cardinality, BoundInputsJson, Notes, EffectiveFrom)
    SELECT rv.RuleVersionPhiloteId, rv.PrimitivePhiloteId, 1, 0,
           rv.Cardinality, NULL,
           N'Position 1; exact source-line content is stored on the immutable RuleInstantiationVersion.',
           @Now
    FROM @RuleVersions AS rv
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleVersionPrimitiveComposition AS existing
        WHERE existing.RuleVersionPhiloteId = rv.RuleVersionPhiloteId
          AND existing.Position = 1
    );

    -- Close only the predecessor version intervals. V00.02.000100 permits
    -- this one transition while keeping every version payload and all
    -- historical membership rows immutable.
    UPDATE ATAPUtilities.RuleSetVersion
    SET EffectiveTo = @Now
    WHERE RuleSetVersionPhiloteId IN (
        '2CDF0578-82CF-4574-B933-2CF796065128',
        '0A57D59C-C39C-4647-8BB1-52F1E916686E'
    )
      AND EffectiveTo IS NULL;

    UPDATE ATAPUtilities.BuildSetVersion
    SET EffectiveTo = @Now
    WHERE BuildSetVersionPhiloteId = 'C7B2B89F-7A41-445C-AD45-F5EE05D3B848'
      AND EffectiveTo IS NULL;

    UPDATE ATAPUtilities.InstantiationVersion
    SET EffectiveTo = @Now
    WHERE InstantiationVersionPhiloteId = @ParentInstantiationVersionPhiloteId
      AND EffectiveTo IS NULL;

    INSERT INTO ATAPUtilities.RuleSetVersion
        (RuleSetVersionPhiloteId, RuleSetPhiloteId, VersionNumber, VersionLabel,
         ParentRuleSetVersionPhiloteId, SortOrder, Notes, EffectiveFrom)
    SELECT v.VersionId, v.SetId, 2, N'v2-markdown',
           v.ParentVersionId, v.SortOrder,
           N'Sprint 0013 Task 13.85 immutable successor RuleSetVersion.', @Now
    FROM (VALUES
        (CAST('03BF1DD5-0341-4D22-B764-3887F55C9962' AS UNIQUEIDENTIFIER),
         CAST('41DF5B43-D6C9-4D47-91D4-86EEDB69E049' AS UNIQUEIDENTIFIER),
         CAST('2CDF0578-82CF-4574-B933-2CF796065128' AS UNIQUEIDENTIFIER), 10),
        (CAST('AE97CAFC-0C76-46A5-8E1E-F986DD7ABC24' AS UNIQUEIDENTIFIER),
         CAST('7243902F-BBD5-4E58-BEFB-8987AFADD731' AS UNIQUEIDENTIFIER),
         CAST('0A57D59C-C39C-4647-8BB1-52F1E916686E' AS UNIQUEIDENTIFIER), 20)
    ) AS v (VersionId, SetId, ParentVersionId, SortOrder)
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleSetVersion AS existing
        WHERE existing.RuleSetVersionPhiloteId = v.VersionId
    );

    INSERT INTO ATAPUtilities.RuleSetVersionMember
        (RuleSetVersionPhiloteId, RuleVersionPhiloteId, SortOrder, Notes, EffectiveFrom)
    SELECT v.SetVersionId, v.RuleVersionId, v.SortOrder,
           N'Immutable Version 2 ordered membership.', @Now
    FROM (VALUES
        (CAST('03BF1DD5-0341-4D22-B764-3887F55C9962' AS UNIQUEIDENTIFIER), CAST('C9680209-4A76-4939-B959-AD3818E3E5AB' AS UNIQUEIDENTIFIER),  10),
        ('03BF1DD5-0341-4D22-B764-3887F55C9962', 'D62CD6B2-00B2-4405-8CC0-675BE8A39270',  20),
        ('03BF1DD5-0341-4D22-B764-3887F55C9962', 'FD38748F-7C8D-42AD-BAF7-0D6EEBAAB2F1',  30),
        ('03BF1DD5-0341-4D22-B764-3887F55C9962', '14F66273-E198-4718-BE27-ED902353113E',  40),
        ('03BF1DD5-0341-4D22-B764-3887F55C9962', '1859BE14-2EA7-496E-AAC9-A11A56D48C51',  50),
        ('03BF1DD5-0341-4D22-B764-3887F55C9962', '17CDDE5D-2C86-40DD-90AF-A2066E1FC649',  60),
        ('03BF1DD5-0341-4D22-B764-3887F55C9962', '51DFC62E-27F6-4653-9CDC-6905A363D159',  70),
        ('03BF1DD5-0341-4D22-B764-3887F55C9962', 'FC496F63-3C77-4623-BF10-7C21516F72B9',  80),
        ('03BF1DD5-0341-4D22-B764-3887F55C9962', 'ACA6C8EA-7646-4202-8B88-C9F10EF28B03',  90),
        ('03BF1DD5-0341-4D22-B764-3887F55C9962', '5876C706-DDE3-4B5B-82BD-24E8FA8ABF9A', 100),
        ('03BF1DD5-0341-4D22-B764-3887F55C9962', '8A5F60CA-8D7E-4DB9-8E4A-7DC274A41FDC', 110),
        ('03BF1DD5-0341-4D22-B764-3887F55C9962', 'C67E59A0-9BCC-4B90-949A-9294DB021B37', 120),
        ('AE97CAFC-0C76-46A5-8E1E-F986DD7ABC24', 'B39BC198-07CC-4F74-BA32-4139B2EDBE08',  10),
        ('AE97CAFC-0C76-46A5-8E1E-F986DD7ABC24', 'EA8E2DF4-A556-4CDB-A424-9158D02F666D',  20),
        ('AE97CAFC-0C76-46A5-8E1E-F986DD7ABC24', '5F9857B0-BB9A-4A80-A8CC-3364607D33A1',  30)
    ) AS v (SetVersionId, RuleVersionId, SortOrder)
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleSetVersionMember AS existing
        WHERE existing.RuleSetVersionPhiloteId = v.SetVersionId
          AND existing.RuleVersionPhiloteId = v.RuleVersionId
    );

    INSERT INTO ATAPUtilities.BuildSetVersion
        (BuildSetVersionPhiloteId, BuildSetPhiloteId, VersionNumber, VersionLabel,
         ParentBuildSetVersionPhiloteId, SortOrder, Notes, EffectiveFrom)
    SELECT 'BEFB3248-501F-4FE3-B6DA-825FB4B968B7',
           '3405677E-CAA9-4ECC-B6E2-8FEC19130749',
           2, N'v2-markdown', 'C7B2B89F-7A41-445C-AD45-F5EE05D3B848',
           20, N'Immutable BuildSetVersion adding the Markdown documentation slice.', @Now
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.BuildSetVersion
        WHERE BuildSetVersionPhiloteId = 'BEFB3248-501F-4FE3-B6DA-825FB4B968B7'
    );

    INSERT INTO ATAPUtilities.BuildSetVersionMember
        (BuildSetVersionPhiloteId, RuleSetVersionPhiloteId, SortOrder, Notes, EffectiveFrom)
    SELECT 'BEFB3248-501F-4FE3-B6DA-825FB4B968B7',
           v.RuleSetVersionId, v.SortOrder,
           N'Immutable Version 2 RuleSetVersion membership.', @Now
    FROM (VALUES
        (CAST('03BF1DD5-0341-4D22-B764-3887F55C9962' AS UNIQUEIDENTIFIER), 10),
        (CAST('AE97CAFC-0C76-46A5-8E1E-F986DD7ABC24' AS UNIQUEIDENTIFIER), 20)
    ) AS v (RuleSetVersionId, SortOrder)
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.BuildSetVersionMember AS existing
        WHERE existing.BuildSetVersionPhiloteId = 'BEFB3248-501F-4FE3-B6DA-825FB4B968B7'
          AND existing.RuleSetVersionPhiloteId = v.RuleSetVersionId
    );

    INSERT INTO ATAPUtilities.InstantiationVersion
        (InstantiationVersionPhiloteId, InstantiationPhiloteId, VersionNumber,
         VersionLabel, ParentInstantiationVersionPhiloteId, Notes,
         BuildSetVersionPhiloteId, EffectiveFrom)
    SELECT @InstantiationVersionPhiloteId, @InstantiationPhiloteId, 2,
           N'v2-markdown-documentation', @ParentInstantiationVersionPhiloteId,
           N'Adds exact-byte INDEX.md and Write-ArrayIndented.md; Version 1 payload and membership remain immutable.',
           'BEFB3248-501F-4FE3-B6DA-825FB4B968B7', @Now
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
        ('84FEC2AA-D0A9-4735-9F18-8B9BA72B5732', '4400C20B-6EE3-47E4-ABF8-49D135647803', 'FC496F63-3C77-4623-BF10-7C21516F72B9', '51C428DE-3591-4F46-8AFB-CDF7279446F5',  90),
        ('09FC6BBB-B54C-4E83-915D-E64162AF7800', '6928C46F-459C-4056-AAD4-01B02837C06B', 'ACA6C8EA-7646-4202-8B88-C9F10EF28B03', '974E0B9D-12CA-4B84-9B7B-22CB691D4688', 100),
        ('ED4DD2F6-1A34-4851-A562-0B967DBAAD54', 'CA7DFAFA-7F72-4B71-BC54-34D0DBF03345', '5876C706-DDE3-4B5B-82BD-24E8FA8ABF9A', '4F243AF6-B297-4222-8503-8E8F273B704C', 110),
        ('57129F96-B843-4574-856E-FB34034D5F67', '0B4D2A2E-5A63-4371-99E3-73469D385E1D', '8A5F60CA-8D7E-4DB9-8E4A-7DC274A41FDC', '91B76D60-E26C-41F7-9EA9-025916CDF4C6', 120),
        ('D60EBDD1-5AB6-4740-B712-EADEB78AA96A', '627E8299-D172-42FF-B26A-E986B5870A95', 'C67E59A0-9BCC-4B90-949A-9294DB021B37', '00698F6A-826A-417D-841D-CA23A9B944C8', 130),
        ('06838A2C-B3E8-4230-B3A3-52AB7984EE85', 'ED4D3918-5EE3-4E69-AEDE-A18A6AEEF0A4', 'EA8E2DF4-A556-4CDB-A424-9158D02F666D', 'F54E2878-F7D6-41ED-883E-B02A16AC2567', 140),
        ('12AA90E6-D541-427F-A635-09F1C0DE96FA', 'CD159B80-0A4B-46BD-AE9C-6B5DBE2D99B4', '5F9857B0-BB9A-4A80-A8CC-3364607D33A1', '21738901-03B5-4143-88E8-3D93A3EEB4B7', 150);

    INSERT INTO ATAPUtilities.RuleInstantiation
        (PhiloteId, RulePhiloteId, Notes, InstantiationPhiloteId, EffectiveFrom)
    SELECT ri.RuleInstantiationPhiloteId, ri.RulePhiloteId,
           N'Sprint 0013 Task 13.85 durable RuleInstantiation.',
           @InstantiationPhiloteId, @Now
    FROM @RuleInstantiations AS ri
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleInstantiation AS existing
        WHERE existing.PhiloteId = ri.RuleInstantiationPhiloteId
    );

    INSERT INTO ATAPUtilities.RuleInstantiationBinding
        (InstantiationPhiloteId, InputName, InputValue, EffectiveFrom)
    SELECT v.RuleInstantiationPhiloteId, N'Value', v.InputValue, @Now
    FROM (VALUES
        (CAST('84FEC2AA-D0A9-4735-9F18-8B9BA72B5732' AS UNIQUEIDENTIFIER), N'Documentation'),
        (CAST('09FC6BBB-B54C-4E83-915D-E64162AF7800' AS UNIQUEIDENTIFIER), N'INDEX.md'),
        (CAST('ED4DD2F6-1A34-4851-A562-0B967DBAAD54' AS UNIQUEIDENTIFIER), N'Write-ArrayIndented.md'),
        (CAST('57129F96-B843-4574-856E-FB34034D5F67' AS UNIQUEIDENTIFIER), N'ATAP.Utilities\src\ATAP.Utilities.PowerShell\Documentation\INDEX.md'),
        (CAST('D60EBDD1-5AB6-4740-B712-EADEB78AA96A' AS UNIQUEIDENTIFIER), N'ATAP.Utilities\src\ATAP.Utilities.PowerShell\Documentation\Write-ArrayIndented.md')
    ) AS v (RuleInstantiationPhiloteId, InputValue)
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleInstantiationBinding AS existing
        WHERE existing.InstantiationPhiloteId = v.RuleInstantiationPhiloteId
          AND existing.InputName = N'Value'
          AND existing.EffectiveTo IS NULL
    );

    INSERT INTO ATAPUtilities.RuleInstantiationVersion
        (RuleInstantiationVersionPhiloteId, RuleInstantiationPhiloteId,
         RuleVersionPhiloteId, RulePhiloteId, VersionNumber, VersionLabel,
         ParentRuleInstantiationVersionPhiloteId, Notes, EffectiveFrom)
    SELECT ri.RuleInstantiationVersionPhiloteId, ri.RuleInstantiationPhiloteId,
           ri.RuleVersionPhiloteId, ri.RulePhiloteId, 1, N'v1', NULL,
           N'Sprint 0013 Task 13.85 immutable input/source snapshot.', @Now
    FROM @RuleInstantiations AS ri
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleInstantiationVersion AS existing
        WHERE existing.RuleInstantiationVersionPhiloteId = ri.RuleInstantiationVersionPhiloteId
    );

    INSERT INTO ATAPUtilities.InstantiationVersionRuleInstantiationVersion
        (InstantiationVersionPhiloteId, RuleInstantiationVersionPhiloteId,
         SortOrder, Notes, EffectiveFrom)
    SELECT @InstantiationVersionPhiloteId, v.RuleInstantiationVersionPhiloteId,
           v.SortOrder, N'Immutable Version 2 snapshot membership.', @Now
    FROM (
        SELECT RuleInstantiationVersionPhiloteId, SortOrder
        FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion
        WHERE InstantiationVersionPhiloteId = @ParentInstantiationVersionPhiloteId
          AND EffectiveTo IS NULL
        UNION ALL
        SELECT RuleInstantiationVersionPhiloteId, SortOrder
        FROM @RuleInstantiations
    ) AS v
    WHERE NOT EXISTS (
        SELECT 1
        FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion AS existing
        WHERE existing.InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
          AND existing.RuleInstantiationVersionPhiloteId = v.RuleInstantiationVersionPhiloteId
    );

    DECLARE @IndexSourceLines TABLE (
        Ordinal INT NOT NULL PRIMARY KEY,
        LineText NVARCHAR(MAX) NOT NULL,
        LineEnding NVARCHAR(4) NOT NULL
    );

    INSERT INTO @IndexSourceLines (Ordinal, LineText, LineEnding)
    VALUES
        (1, N'# ATAP.Utilities.PowerShell — Documentation Index', N'CRLF'),
        (2, N'', N'CRLF'),
        (3, N'This folder holds the concept and reference documentation for the', N'CRLF'),
        (4, N'`ATAP.Utilities.PowerShell` module. It is the narrative counterpart to', N'CRLF'),
        (5, N'[../INDEX.md](../INDEX.md), which indexes the module''s scripts themselves.', N'CRLF'),
        (6, N'', N'CRLF'),
        (7, N'Use this page to find the right document; use the module script index to find the right', N'CRLF'),
        (8, N'function.', N'CRLF'),
        (9, N'', N'CRLF'),
        (10, N'## Concept documentation', N'CRLF'),
        (11, N'', N'CRLF'),
        (12, N'| Document | Covers |', N'CRLF'),
        (13, N'| -------- | ------ |', N'CRLF'),
        (14, N'| [ReadMe.md](ReadMe.md) | Profiles as the environment a PowerShell process executes in, the IAC-owned profile payloads, machine and user profile scopes, machine names and roles, nodes, testing, packaging, and a per-function narrative for the module''s public commands. |', N'CRLF'),
        (15, N'| [GettingStarted.md](GettingStarted.md) | The five-tier lifecycle flow — Experimental, Development, Integration, QA, Stable — and the promotion guidance that goes with it. |', N'CRLF'),
        (16, N'| [Powershell Useage in ATAP.Utilities.md](Powershell%20Useage%20in%20ATAP.Utilities.md) | House conventions for writing PowerShell here: Desktop 5 versus Core 7, settings, `Join-Path` over path strings, `[Environment]` over `$env`, `Out-File` over `Get-Content`, file encoding defaults, cross-platform environment variables, classes in modules, LINQ, and logging. |', N'CRLF'),
        (17, N'', N'CRLF'),
        (18, N'## Function reference', N'CRLF'),
        (19, N'', N'CRLF'),
        (20, N'| Document | Function |', N'CRLF'),
        (21, N'| -------- | -------- |', N'CRLF'),
        (22, N'| [Write-ArrayIndented.md](Write-ArrayIndented.md) | [`Write-ArrayIndented`](../public/Write-ArrayIndented.ps1) — formats an array as an indented, recursive string representation for diagnostic display. |', N'CRLF'),
        (23, N'', N'CRLF'),
        (24, N'Functions without a page here are documented by their comment-based help; run', N'CRLF'),
        (25, N'`Get-Help <FunctionName> -Full` against an imported module, or read the `.ps1` file', N'CRLF'),
        (26, N'listed in [../INDEX.md](../INDEX.md).', N'CRLF'),
        (27, N'', N'CRLF'),
        (28, N'## Diagrams', N'CRLF'),
        (29, N'', N'CRLF'),
        (30, N'| File | Covers |', N'CRLF'),
        (31, N'| ---- | ------ |', N'CRLF'),
        (32, N'| `GlobalSettingsRelationships.drawio` | Draw.io source for the relationships among `$global:configRootKeys`, `$global:settings`, and the ATAP.IAC host-settings fragments that populate them. |', N'CRLF'),
        (33, N'', N'CRLF'),
        (34, N'## Folder conventions', N'CRLF'),
        (35, N'', N'CRLF'),
        (36, N'- `toc.yml` lists the documents published by the documentation build. Add an entry there', N'CRLF'),
        (37, N'  when adding a page to this folder.', N'CRLF'),
        (38, N'- Diagram sources stay in this folder alongside the document that embeds them. Pass a', N'CRLF'),
        (39, N'  Markdown file to `Convert-DiagramsToImages` to render its diagrams to images.', N'CRLF'),
        (40, N'- Markdown here is linted against the repository `.markdownlint.yml`.', N'CRLF');

    DECLARE @WriteSourceLines TABLE (
        Ordinal INT NOT NULL PRIMARY KEY,
        LineText NVARCHAR(MAX) NOT NULL,
        LineEnding NVARCHAR(4) NOT NULL
    );

    INSERT INTO @WriteSourceLines (Ordinal, LineText, LineEnding)
    VALUES
        (1, N'# Write-ArrayIndented', N'CRLF'),
        (2, N'', N'CRLF'),
        (3, N'Formats an array as an indented string representation.', N'CRLF'),
        (4, N'', N'CRLF'),
        (5, N'## Synopsis', N'CRLF'),
        (6, N'', N'CRLF'),
        (7, N'`Write-ArrayIndented` recursively converts an array to a multi-line indented string,', N'CRLF'),
        (8, N'expanding nested arrays and hashtables at each level. It is intended for diagnostic', N'CRLF'),
        (9, N'display of complex data structures, such as a settings hashtable inspected from the', N'CRLF'),
        (10, N'`AllUsersAllHosts` profile or from a diagnostic script.', N'CRLF'),
        (11, N'', N'CRLF'),
        (12, N'## Syntax', N'CRLF'),
        (13, N'', N'CRLF'),
        (14, N'```powershell', N'CRLF'),
        (15, N'Write-ArrayIndented [[-Array] <Object>] [[-Indent] <Int32>] [[-IndentIncrement] <Int32>] [<CommonParameters>]', N'CRLF'),
        (16, N'```', N'CRLF'),
        (17, N'', N'CRLF'),
        (18, N'## Description', N'CRLF'),
        (19, N'', N'CRLF'),
        (20, N'The function walks the supplied array one element at a time and appends a line to an', N'CRLF'),
        (21, N'accumulating string for each element. Every line is prefixed with `-Indent` spaces, so', N'CRLF'),
        (22, N'the caller controls the absolute indentation of the whole block while the function', N'CRLF'),
        (23, N'controls the relative indentation of everything nested inside it.', N'CRLF'),
        (24, N'', N'CRLF'),
        (25, N'Element handling is decided by type, tested in this order:', N'CRLF'),
        (26, N'', N'CRLF'),
        (27, N'| Element type                     | Rendered as                                                                  |', N'CRLF'),
        (28, N'| -------------------------------- | ---------------------------------------------------------------------------- |', N'CRLF'),
        (29, N'| `$null`                          | the literal text `(null)`                                                    |', N'CRLF'),
        (30, N'| `[System.Boolean]`               | the string form of the value, `True` or `False`                              |', N'CRLF'),
        (31, N'| `[System.String]`                | the string itself                                                            |', N'CRLF'),
        (32, N'| `[System.Array]`                 | `(`, then the nested array indented by one increment, then `)`               |', N'CRLF'),
        (33, N'| `[System.Collections.Hashtable]` | `{`, then the delegated hashtable body indented by one increment, then `}`   |', N'CRLF'),
        (34, N'| anything else                    | the result of casting the element to `[string]`                              |', N'CRLF'),
        (35, N'', N'CRLF'),
        (36, N'Nested arrays are handled by recursing into `Write-ArrayIndented` itself with `-Indent`', N'CRLF'),
        (37, N'raised by `-IndentIncrement`. Nested hashtables are **not** handled here: the function', N'CRLF'),
        (38, N'delegates them to `Write-HashIndented`, passing the raised indent as that function''s', N'CRLF'),
        (39, N'`-InitialIndent`. `Write-HashIndented` must therefore be available in the session, which', N'CRLF'),
        (40, N'is why the three `*Indented` functions are normally dot-sourced or imported together.', N'CRLF'),
        (41, N'', N'CRLF'),
        (42, N'Because the `[System.String]` test precedes the `[System.Array]` test, a string element', N'CRLF'),
        (43, N'is emitted as one line rather than being enumerated character by character.', N'CRLF'),
        (44, N'', N'CRLF'),
        (45, N'Every line is terminated with `[Environment]::NewLine`, so output carries the line', N'CRLF'),
        (46, N'ending native to the running platform.', N'CRLF'),
        (47, N'', N'CRLF'),
        (48, N'## Parameters', N'CRLF'),
        (49, N'', N'CRLF'),
        (50, N'| Parameter          | Type     | Position | Required | Default | Description                                                                          |', N'CRLF'),
        (51, N'| ------------------ | -------- | -------- | -------- | ------- | ------------------------------------------------------------------------------------ |', N'CRLF'),
        (52, N'| `-Array`           | `Object` | 0        | No       | none    | The array to format. The parameter is untyped, so any enumerable or scalar may be passed. |', N'CRLF'),
        (53, N'| `-Indent`          | `Int32`  | 1        | No       | `0`     | The current indentation level, in spaces, applied to every line this call emits.     |', N'CRLF'),
        (54, N'| `-IndentIncrement` | `Int32`  | 2        | No       | `2`     | The number of additional spaces added at each nesting level.                         |', N'CRLF'),
        (55, N'', N'CRLF'),
        (56, N'The function is decorated with `[CmdletBinding()]`, so it also accepts the common', N'CRLF'),
        (57, N'parameters.', N'CRLF'),
        (58, N'', N'CRLF'),
        (59, N'## Outputs', N'CRLF'),
        (60, N'', N'CRLF'),
        (61, N'`[string]` — an indented, multi-line string representation of the array. The string is', N'CRLF'),
        (62, N'emitted from the `process` block as a single value, so one call returns one string', N'CRLF'),
        (63, N'containing every line, not one string per element. The returned string ends with a', N'CRLF'),
        (64, N'trailing newline, so splitting it on the line terminator yields a final empty element.', N'CRLF'),
        (65, N'', N'CRLF'),
        (66, N'## Examples', N'CRLF'),
        (67, N'', N'CRLF'),
        (68, N'Every example below shows output captured from the function itself, not a reconstruction.', N'CRLF'),
        (69, N'', N'CRLF'),
        (70, N'### Example 1: A flat array', N'CRLF'),
        (71, N'', N'CRLF'),
        (72, N'```powershell', N'CRLF'),
        (73, N'Write-ArrayIndented -Array @(''alpha'', ''beta'') -Indent 0 -IndentIncrement 2', N'CRLF'),
        (74, N'```', N'CRLF'),
        (75, N'', N'CRLF'),
        (76, N'```text', N'CRLF'),
        (77, N'alpha', N'CRLF'),
        (78, N'beta', N'CRLF'),
        (79, N'```', N'CRLF'),
        (80, N'', N'CRLF'),
        (81, N'### Example 2: Indenting a whole block', N'CRLF'),
        (82, N'', N'CRLF'),
        (83, N'```powershell', N'CRLF'),
        (84, N'Write-ArrayIndented -Array @(''item'') -Indent 4 -IndentIncrement 2', N'CRLF'),
        (85, N'```', N'CRLF'),
        (86, N'', N'CRLF'),
        (87, N'```text', N'CRLF'),
        (88, N'    item', N'CRLF'),
        (89, N'```', N'CRLF'),
        (90, N'', N'CRLF'),
        (91, N'### Example 3: A nested array', N'CRLF'),
        (92, N'', N'CRLF'),
        (93, N'```powershell', N'CRLF'),
        (94, N'Write-ArrayIndented -Array @(''a'', @(''b'', ''c''), ''d'') -Indent 0 -IndentIncrement 2', N'CRLF'),
        (95, N'```', N'CRLF'),
        (96, N'', N'CRLF'),
        (97, N'```text', N'CRLF'),
        (98, N'a', N'CRLF'),
        (99, N'(', N'CRLF'),
        (100, N'  b', N'CRLF'),
        (101, N'  c', N'CRLF'),
        (102, N')', N'CRLF'),
        (103, N'd', N'CRLF'),
        (104, N'```', N'CRLF'),
        (105, N'', N'CRLF'),
        (106, N'### Example 4: Null, booleans, and other scalars', N'CRLF'),
        (107, N'', N'CRLF'),
        (108, N'```powershell', N'CRLF'),
        (109, N'Write-ArrayIndented -Array @($null, $true, $false, 42) -Indent 0 -IndentIncrement 2', N'CRLF'),
        (110, N'```', N'CRLF'),
        (111, N'', N'CRLF'),
        (112, N'```text', N'CRLF'),
        (113, N'(null)', N'CRLF'),
        (114, N'True', N'CRLF'),
        (115, N'False', N'CRLF'),
        (116, N'42', N'CRLF'),
        (117, N'```', N'CRLF'),
        (118, N'', N'CRLF'),
        (119, N'### Example 5: A nested hashtable', N'CRLF'),
        (120, N'', N'CRLF'),
        (121, N'```powershell', N'CRLF'),
        (122, N'Write-ArrayIndented -Array @(''a'', ''b'', @{x = ''one''}) -Indent 0 -IndentIncrement 2', N'CRLF'),
        (123, N'```', N'CRLF'),
        (124, N'', N'CRLF'),
        (125, N'```text', N'CRLF'),
        (126, N'a', N'CRLF'),
        (127, N'b', N'CRLF'),
        (128, N'{', N'CRLF'),
        (129, N'  x = one', N'CRLF'),
        (130, N'}', N'CRLF'),
        (131, N'```', N'CRLF'),
        (132, N'', N'CRLF'),
        (133, N'The brace lines come from `Write-ArrayIndented`; the `x = one` line is produced by', N'CRLF'),
        (134, N'`Write-HashIndented`, called with `-InitialIndent 2`, which in turn calls', N'CRLF'),
        (135, N'`Write-KVPIndented` for each pair.', N'CRLF'),
        (136, N'', N'CRLF'),
        (137, N'## Known limitation: scalar hashtable values are dropped', N'CRLF'),
        (138, N'', N'CRLF'),
        (139, N'A hashtable value whose type is neither `[Boolean]`, `[String]`, `[Array]`, nor', N'CRLF'),
        (140, N'`[Hashtable]` renders as an empty value. `Write-KVPIndented` selects the value''s', N'CRLF'),
        (141, N'rendering with a `switch` that has no default case, so an integer, `DateTime`, enum, or', N'CRLF'),
        (142, N'`PSCustomObject` value produces the key, the ` = ` separator, and nothing after it:', N'CRLF'),
        (143, N'', N'CRLF'),
        (144, N'```powershell', N'CRLF'),
        (145, N'Write-ArrayIndented -Array @(''a'', ''b'', @{x = 1}) -Indent 0 -IndentIncrement 2', N'CRLF'),
        (146, N'```', N'CRLF'),
        (147, N'', N'CRLF'),
        (148, N'```text', N'CRLF'),
        (149, N'a', N'CRLF'),
        (150, N'b', N'CRLF'),
        (151, N'{', N'CRLF'),
        (152, N'  x =', N'CRLF'),
        (153, N'}', N'CRLF'),
        (154, N'```', N'CRLF'),
        (155, N'', N'CRLF'),
        (156, N'Note the asymmetry: at array level `Write-ArrayIndented` renders `42` correctly, because', N'CRLF'),
        (157, N'its own `if`/`elseif` chain ends with an `else` that casts to `[string]`. The loss occurs', N'CRLF'),
        (158, N'only for values reached through the hashtable delegation path. Callers diagnosing numeric', N'CRLF'),
        (159, N'settings should be aware that a blank right-hand side means *unhandled type*, not *empty', N'CRLF'),
        (160, N'value*. The fix belongs in `Write-KVPIndented`, not here.', N'CRLF'),
        (161, N'', N'CRLF'),
        (162, N'## Notes', N'CRLF'),
        (163, N'', N'CRLF'),
        (164, N'The function logs entry and exit at `Debug` level through PSFramework:', N'CRLF'),
        (165, N'', N'CRLF'),
        (166, N'```powershell', N'CRLF'),
        (167, N'Write-PSFMessage -FunctionName $fn -ModuleName ''ATAP.Utilities.PowerShell'' -Level Debug -Message ''Starting Write-ArrayIndented''', N'CRLF'),
        (168, N'```', N'CRLF'),
        (169, N'', N'CRLF'),
        (170, N'Both the `begin` and `end` messages are written on every call, including each recursive', N'CRLF'),
        (171, N'call, so a deeply nested structure produces two Debug messages per level.', N'CRLF'),
        (172, N'', N'CRLF'),
        (173, N'Edge cases confirmed by `tests/Unit/Write-ArrayIndented.Tests.ps1`: an empty array and a', N'CRLF'),
        (174, N'`$null` array each return without throwing, as do boolean elements and a nested', N'CRLF'),
        (175, N'hashtable. An empty array returns a string containing only the trailing newline.', N'CRLF'),
        (176, N'', N'CRLF'),
        (177, N'This function was moved out of `AllUsersAllHostsV7CoreProfile.ps1` into the', N'CRLF'),
        (178, N'`ATAP.Utilities.PowerShell` module as part of SC-0183, which reduced profile loading', N'CRLF'),
        (179, N'times.', N'CRLF'),
        (180, N'', N'CRLF'),
        (181, N'## Related', N'CRLF'),
        (182, N'', N'CRLF'),
        (183, N'- [Write-HashIndented](../public/Write-HashIndented.ps1) — formats a hashtable; called by this function for nested hashtable elements', N'CRLF'),
        (184, N'- [Write-KVPIndented](../public/Write-KVPIndented.ps1) — formats a single key/value pair; called in turn by `Write-HashIndented`, and calls back into this function for array values', N'CRLF'),
        (185, N'- [Write-EnvironmentVariablesIndented](../public/Write-EnvironmentVariablesIndented.ps1) — formats the environment variable collection', N'CRLF'),
        (186, N'', N'CRLF'),
        (187, N'## Source', N'CRLF'),
        (188, N'', N'CRLF'),
        (189, N'- Implementation: [Write-ArrayIndented.ps1](../public/Write-ArrayIndented.ps1)', N'CRLF'),
        (190, N'- Tests: [Write-ArrayIndented.Tests.ps1](../tests/Unit/Write-ArrayIndented.Tests.ps1)', N'CRLF');

    INSERT INTO ATAPUtilities.RuleInstantiationVersionSourceLine
        (RuleInstantiationVersionPhiloteId, Ordinal, LineText, LineEnding, EffectiveFrom)
    SELECT 'F54E2878-F7D6-41ED-883E-B02A16AC2567',
           s.Ordinal, s.LineText, s.LineEnding, @Now
    FROM @IndexSourceLines AS s
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleInstantiationVersionSourceLine AS existing
        WHERE existing.RuleInstantiationVersionPhiloteId = 'F54E2878-F7D6-41ED-883E-B02A16AC2567'
          AND existing.Ordinal = s.Ordinal
          AND existing.EffectiveTo IS NULL
    );

    INSERT INTO ATAPUtilities.RuleInstantiationVersionSourceLine
        (RuleInstantiationVersionPhiloteId, Ordinal, LineText, LineEnding, EffectiveFrom)
    SELECT '21738901-03B5-4143-88E8-3D93A3EEB4B7',
           s.Ordinal, s.LineText, s.LineEnding, @Now
    FROM @WriteSourceLines AS s
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RuleInstantiationVersionSourceLine AS existing
        WHERE existing.RuleInstantiationVersionPhiloteId = '21738901-03B5-4143-88E8-3D93A3EEB4B7'
          AND existing.Ordinal = s.Ordinal
          AND existing.EffectiveTo IS NULL
    );

    INSERT INTO ATAPUtilities.ManifestationArtifact
        (ManifestationArtifactPhiloteId, InstantiationVersionPhiloteId,
         ArtifactKind, RelativePath, SourceObjectKind, SourceObjectPhiloteId,
         ContentSha256, RenderPolicy, SortOrder, Notes, BuildSetVersionPhiloteId,
         ProducingRuleInstantiationPhiloteId,
         ProducingRuleInstantiationVersionPhiloteId, EffectiveFrom)
    SELECT v.ArtifactId, @InstantiationVersionPhiloteId, v.ArtifactKind,
           v.RelativePath, N'RuleInstantiationVersion', v.ProducerVersionId,
           v.ContentSha256, N'Planned', v.SortOrder,
           N'Sprint 0013 Task 13.85 planned Version 2 artifact.',
           'BEFB3248-501F-4FE3-B6DA-825FB4B968B7',
           v.ProducerId, v.ProducerVersionId, @Now
    FROM (VALUES
        (CAST('602FD59A-4332-44AE-9624-F3FE930C87A5' AS UNIQUEIDENTIFIER),
         N'Directory', N'ATAP.Utilities\src\ATAP.Utilities.PowerShell\Documentation',
         CAST(NULL AS CHAR(64)), 60,
         CAST('84FEC2AA-D0A9-4735-9F18-8B9BA72B5732' AS UNIQUEIDENTIFIER),
         CAST('51C428DE-3591-4F46-8AFB-CDF7279446F5' AS UNIQUEIDENTIFIER)),
        (CAST('22DB5CA7-BDFD-4366-806E-21A205280B4E' AS UNIQUEIDENTIFIER),
         N'Report', N'ATAP.Utilities\src\ATAP.Utilities.PowerShell\Documentation\INDEX.md',
         @IndexHash, 70,
         CAST('06838A2C-B3E8-4230-B3A3-52AB7984EE85' AS UNIQUEIDENTIFIER),
         CAST('F54E2878-F7D6-41ED-883E-B02A16AC2567' AS UNIQUEIDENTIFIER)),
        (CAST('6CC1F4E9-8C8D-4320-968E-D5A7CDDA3AF0' AS UNIQUEIDENTIFIER),
         N'Report', N'ATAP.Utilities\src\ATAP.Utilities.PowerShell\Documentation\Write-ArrayIndented.md',
         @WriteHash, 80,
         CAST('12AA90E6-D541-427F-A635-09F1C0DE96FA' AS UNIQUEIDENTIFIER),
         CAST('21738901-03B5-4143-88E8-3D93A3EEB4B7' AS UNIQUEIDENTIFIER))
    ) AS v (ArtifactId, ArtifactKind, RelativePath, ContentSha256, SortOrder,
            ProducerId, ProducerVersionId)
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.ManifestationArtifact AS existing
        WHERE existing.ManifestationArtifactPhiloteId = v.ArtifactId
    );

    IF (SELECT COUNT(*) FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion
        WHERE InstantiationVersionPhiloteId = @ParentInstantiationVersionPhiloteId
          AND EffectiveTo IS NULL) <> 8
        THROW 50141, N'V00.02.000140 detected Version 1 snapshot drift.', 1;

    IF (SELECT COUNT(*) FROM ATAPUtilities.ManifestationArtifact
        WHERE InstantiationVersionPhiloteId = @ParentInstantiationVersionPhiloteId
          AND EffectiveTo IS NULL) <> 5
        THROW 50142, N'V00.02.000140 detected Version 1 artifact drift.', 1;

    IF (SELECT COUNT(*) FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion
        WHERE InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
          AND EffectiveTo IS NULL) <> 15
        THROW 50143, N'V00.02.000140 expected fifteen Version 2 snapshot members.', 1;

    IF (SELECT COUNT(*) FROM ATAPUtilities.ManifestationArtifact
        WHERE InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
          AND EffectiveTo IS NULL) <> 3
        THROW 50144, N'V00.02.000140 expected one directory and two Markdown files.', 1;

    IF (SELECT COUNT(*) FROM ATAPUtilities.RuleInstantiationVersionSourceLine
        WHERE RuleInstantiationVersionPhiloteId = 'F54E2878-F7D6-41ED-883E-B02A16AC2567'
          AND EffectiveTo IS NULL) <> 40
        THROW 50145, N'V00.02.000140 expected forty INDEX.md source lines.', 1;

    IF (SELECT COUNT(*) FROM ATAPUtilities.RuleInstantiationVersionSourceLine
        WHERE RuleInstantiationVersionPhiloteId = '21738901-03B5-4143-88E8-3D93A3EEB4B7'
          AND EffectiveTo IS NULL) <> 190
        THROW 50146, N'V00.02.000140 expected 190 Write-ArrayIndented.md source lines.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

PRINT N'V00.02.000140 - InstantiationVersion 2 Markdown documentation slice seeded.';

-- =====================================================================
-- V00.02.000130__Add_Markdown_Rule_Kind.sql
-- Sprint 0013 Task 13.85
-- Canonical migration approved 2026-07-30.
--
-- Adds the Markdown PrimitiveLanguageKind, the corpus-derived primitives
-- and inputs, and the operator-approved MarkdownDocument composition.
-- ContentSummary owns version 000120 and PrimitiveLanguageKindId 9.
-- =====================================================================
SET XACT_ABORT ON;
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;

BEGIN TRANSACTION;

BEGIN TRY
    IF OBJECT_ID(N'ATAPUtilities.Philote', N'U') IS NULL
        THROW 50130, N'V00.02.000130 requires ATAPUtilities.Philote.', 1;
    IF OBJECT_ID(N'ATAPUtilities.PrimitiveLanguageKind', N'U') IS NULL
        THROW 50130, N'V00.02.000130 requires ATAPUtilities.PrimitiveLanguageKind.', 1;
    IF OBJECT_ID(N'ATAPUtilities.RulePrimitive', N'U') IS NULL
        THROW 50130, N'V00.02.000130 requires ATAPUtilities.RulePrimitive.', 1;
    IF OBJECT_ID(N'ATAPUtilities.RulePrimitiveInput', N'U') IS NULL
        THROW 50130, N'V00.02.000130 requires ATAPUtilities.RulePrimitiveInput.', 1;
    IF OBJECT_ID(N'ATAPUtilities.Rule', N'U') IS NULL
        THROW 50130, N'V00.02.000130 requires ATAPUtilities.[Rule].', 1;
    IF OBJECT_ID(N'ATAPUtilities.RulePrimitiveComposition', N'U') IS NULL
        THROW 50130, N'V00.02.000130 requires ATAPUtilities.RulePrimitiveComposition.', 1;

    IF EXISTS (
        SELECT 1
        FROM ATAPUtilities.PrimitiveLanguageKind
        WHERE PrimitiveLanguageKindId = 10
          AND [Name] <> N'Markdown'
    )
        THROW 50131, N'V00.02.000130 aborted: Kind id 10 belongs to a different Kind.', 1;

    IF EXISTS (
        SELECT 1
        FROM ATAPUtilities.PrimitiveLanguageKind
        WHERE [Name] = N'Markdown'
          AND PrimitiveLanguageKindId <> 10
    )
        THROW 50132, N'V00.02.000130 aborted: Markdown exists under an id other than 10.', 1;

    DECLARE @PrimitiveLanguageKindId TINYINT = 10;
    DECLARE @RulePhiloteId UNIQUEIDENTIFIER = '181D5E43-F2E2-4A29-B720-45991D52EF6E';

    DECLARE @Primitives TABLE (
        PhiloteId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        [Name] NVARCHAR(200) NOT NULL,
        [Description] NVARCHAR(MAX) NOT NULL,
        BnfDefinition NVARCHAR(MAX) NOT NULL
    );

    INSERT INTO @Primitives (PhiloteId, [Name], [Description], BnfDefinition)
    VALUES
        ('BECC038A-3127-478D-A8F1-DA29BBD76B64', N'MarkdownBlock',
         N'Routing primitive selecting one block-level Markdown construct.',
         N'<markdown-block> ::= <atx-heading> | <paragraph> | <blank-line> | <fenced-code-block> | <unordered-list> | <pipe-table> | <source-line>'),
        ('AB94EB3A-A47C-4531-933D-C5497DDC6A14', N'AtxHeading',
         N'A # prefixed heading with a level from 1 through 6.',
         N'<atx-heading> ::= ("#" | "##" | "###" | "####" | "#####" | "######") " " <inline-content> <line-ending>'),
        ('D4D087C6-4DEC-4226-BCA7-7B04CF516ADD', N'Paragraph',
         N'A run of inline content terminated by a blank line.',
         N'<paragraph> ::= <inline-content> <line-ending> (<inline-content> <line-ending>)*'),
        ('8DC53FBF-24DD-4BD1-BCD0-23784FB10820', N'BlankLine',
         N'One or more empty lines separating blocks.',
         N'<blank-line> ::= <line-ending>'),
        ('3D3CEB05-7705-4BA5-B001-13D020045859', N'FencedCodeBlock',
         N'A backtick-fenced block carrying an info string and verbatim body.',
         N'<fenced-code-block> ::= <fence> <info-string> <line-ending> <code-body> <fence> <line-ending>'),
        ('00BDECF8-FFEB-4DD2-B523-323FEBCB27D8', N'UnorderedList',
         N'A contiguous run of unordered list items sharing one marker.',
         N'<unordered-list> ::= <list-item>+'),
        ('B769E3ED-2479-48B9-B84E-49FA8DA89E4A', N'ListItem',
         N'One unordered list item with optional continuation lines.',
         N'<list-item> ::= <list-marker> " " <inline-content> <line-ending> <continuation-line>*'),
        ('F5F18FC7-0BDC-42D1-9477-121C06FB4A84', N'PipeTable',
         N'A GFM pipe table with header, delimiter, and body rows.',
         N'<pipe-table> ::= <table-row> <delimiter-row> <table-row>+'),
        ('C927ED45-32A5-4913-8433-97C6ED541F9B', N'TableRow',
         N'One pipe-delimited table row.',
         N'<table-row> ::= "|" (<cell> "|")+ <line-ending>'),
        ('41C7B5E2-2282-4CCC-AFA9-5D8497D0AD74', N'InlineCode',
         N'A backtick-delimited inline code span.',
         N'<inline-code> ::= "`" <code-text> "`"'),
        ('468E634B-7A44-4D0B-9078-CD17C8E196CE', N'Link',
         N'An inline Markdown link.',
         N'<link> ::= "[" <link-text> "]" "(" <link-target> ")"'),
        ('5872CD5B-9860-4A5A-AC81-A83E74FEE445', N'Emphasis',
         N'Emphasized or strongly emphasized inline content.',
         N'<emphasis> ::= "*" <text-run> "*" | "**" <text-run> "**"'),
        ('6A6E508C-3D00-4B99-80E3-A8B76FD42BDC', N'TextRun',
         N'Literal inline text including Unicode characters.',
         N'<text-run> ::= <character>+'),
        ('06999547-9C11-4F71-8350-763DE0C925DF', N'SourceLine',
         N'One verbatim source line with its ordinal and line-ending policy.',
         N'<source-line> ::= <character>* <line-ending>');

    INSERT INTO ATAPUtilities.Philote (PhiloteId, EffectiveFrom)
    SELECT v.PhiloteId, SYSUTCDATETIME()
    FROM (
        SELECT PhiloteId FROM @Primitives
        UNION ALL
        SELECT @RulePhiloteId
    ) AS v
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.Philote AS existing
        WHERE existing.PhiloteId = v.PhiloteId
    );

    IF NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.PrimitiveLanguageKind
        WHERE PrimitiveLanguageKindId = @PrimitiveLanguageKindId
    )
    BEGIN
        INSERT INTO ATAPUtilities.PrimitiveLanguageKind
            (PrimitiveLanguageKindId, [Name], [Description])
        VALUES
            (@PrimitiveLanguageKindId, N'Markdown',
             N'CommonMark and GFM document primitives for byte-exact source documentation');
    END;

    INSERT INTO ATAPUtilities.RulePrimitive
        (PhiloteId, PrimitiveLanguageKindId, [Name], [Description], BnfDefinition, Attribution)
    SELECT p.PhiloteId, @PrimitiveLanguageKindId, p.[Name], p.[Description],
           p.BnfDefinition, N'Sprint 0013 Task 13.85; Rules Compendium.Markdown.'
    FROM @Primitives AS p
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RulePrimitive AS existing
        WHERE existing.PrimitiveLanguageKindId = @PrimitiveLanguageKindId
          AND existing.[Name] = p.[Name]
    );

    DECLARE @Inputs TABLE (
        PrimitiveName NVARCHAR(200) NOT NULL,
        InputName NVARCHAR(200) NOT NULL,
        TypeName NVARCHAR(200) NULL,
        [Description] NVARCHAR(MAX) NOT NULL,
        DefaultValue NVARCHAR(MAX) NULL,
        IsRequired BIT NOT NULL
    );

    INSERT INTO @Inputs
        (PrimitiveName, InputName, TypeName, [Description], DefaultValue, IsRequired)
    VALUES
        (N'MarkdownBlock', N'BlockType', N'string', N'Block production selected by the routing primitive.', NULL, 1),
        (N'MarkdownBlock', N'BlockContent', N'object', N'Instance of the selected block primitive.', NULL, 1),
        (N'AtxHeading', N'Level', N'int', N'ATX heading level from 1 through 6.', NULL, 1),
        (N'AtxHeading', N'Text', N'string', N'Inline heading text after the marker.', NULL, 1),
        (N'Paragraph', N'Text', N'string', N'Inline paragraph content preserved without rewrapping.', NULL, 1),
        (N'BlankLine', N'Count', N'int', N'Number of consecutive blank lines.', N'1', 0),
        (N'FencedCodeBlock', N'InfoString', N'string', N'Non-empty language tag.', N'text', 1),
        (N'FencedCodeBlock', N'Body', N'string', N'Verbatim fenced-code body; may be empty.', NULL, 1),
        (N'FencedCodeBlock', N'FenceChar', N'string', N'Fence character.', N'`', 0),
        (N'FencedCodeBlock', N'FenceLength', N'int', N'Fence-character count.', N'3', 0),
        (N'UnorderedList', N'Marker', N'string', N'Uniform list marker.', N'-', 0),
        (N'ListItem', N'Text', N'string', N'List-item content.', NULL, 1),
        (N'ListItem', N'IndentSpaces', N'int', N'Nesting indentation.', N'0', 0),
        (N'ListItem', N'ContinuationText', N'string', N'Indented continuation text.', NULL, 0),
        (N'PipeTable', N'Alignments', N'string[]', N'Per-column alignment values.', NULL, 0),
        (N'TableRow', N'Cells', N'string[]', N'Cell contents in source order.', NULL, 1),
        (N'TableRow', N'IsHeader', N'bit', N'Whether the row is the header row.', N'0', 0),
        (N'InlineCode', N'Text', N'string', N'Inline-code text without delimiters.', NULL, 1),
        (N'Link', N'Text', N'string', N'Link label.', NULL, 1),
        (N'Link', N'Target', N'string', N'Destination stored exactly as authored.', NULL, 1),
        (N'Link', N'IsPercentEncoded', N'bit', N'Whether the destination contains percent encoding.', N'0', 0),
        (N'Emphasis', N'Text', N'string', N'Emphasized content.', NULL, 1),
        (N'Emphasis', N'Strength', N'string', N'Emphasis or strong.', N'strong', 1),
        (N'TextRun', N'Text', N'string', N'Literal Unicode text.', NULL, 1),
        (N'SourceLine', N'Ordinal', N'int', N'One-based gap-free source-line ordinal.', NULL, 1),
        (N'SourceLine', N'Text', N'string', N'Verbatim source-line content; may be empty.', NULL, 1),
        (N'SourceLine', N'LineEnding', N'string', N'CRLF, LF, or None.', N'CRLF', 0);

    INSERT INTO ATAPUtilities.RulePrimitiveInput
        (PhiloteId, InputName, TypeName, [Description], DefaultValue, IsRequired)
    SELECT rp.PhiloteId, i.InputName, i.TypeName, i.[Description],
           i.DefaultValue, i.IsRequired
    FROM @Inputs AS i
    INNER JOIN ATAPUtilities.RulePrimitive AS rp
        ON rp.PrimitiveLanguageKindId = @PrimitiveLanguageKindId
       AND rp.[Name] = i.PrimitiveName
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RulePrimitiveInput AS existing
        WHERE existing.PhiloteId = rp.PhiloteId
          AND existing.InputName = i.InputName
    );

    IF NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.[Rule]
        WHERE PrimitiveLanguageKindId = @PrimitiveLanguageKindId
          AND [Name] = N'MarkdownDocument'
    )
    BEGIN
        INSERT INTO ATAPUtilities.[Rule]
            (PhiloteId, PrimitiveLanguageKindId, [Name], Purpose, SourceFileReference)
        VALUES
            (@RulePhiloteId, @PrimitiveLanguageKindId, N'MarkdownDocument',
             N'Required ATX root heading followed by zero or more interleaved Markdown blocks.',
             N'SolutionDocumentation/Rules Compendium.Markdown.md#grammar');
    END;

    INSERT INTO ATAPUtilities.RulePrimitiveComposition
        (RulePhiloteId, SequenceKey, PrimitivePhiloteId, BoundInputsJson, Notes)
    SELECT @RulePhiloteId, v.SequenceKey, rp.PhiloteId, NULL, v.Notes
    FROM (VALUES
        (N'001', N'AtxHeading', N'Cardinality 1; required root anchor; operator approved 2026-07-30.'),
        (N'002', N'MarkdownBlock', N'Cardinality *; optional repeated blocks in source order; operator approved 2026-07-30.')
    ) AS v (SequenceKey, PrimitiveName, Notes)
    INNER JOIN ATAPUtilities.RulePrimitive AS rp
        ON rp.PrimitiveLanguageKindId = @PrimitiveLanguageKindId
       AND rp.[Name] = v.PrimitiveName
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.RulePrimitiveComposition AS existing
        WHERE existing.RulePhiloteId = @RulePhiloteId
          AND existing.SequenceKey = v.SequenceKey
    );

    IF (SELECT COUNT(*) FROM ATAPUtilities.RulePrimitive
        WHERE PrimitiveLanguageKindId = @PrimitiveLanguageKindId) <> 14
        THROW 50133, N'V00.02.000130 expected exactly 14 Markdown primitives.', 1;

    IF (SELECT COUNT(*) FROM ATAPUtilities.RulePrimitiveInput AS i
        INNER JOIN ATAPUtilities.RulePrimitive AS p ON p.PhiloteId = i.PhiloteId
        WHERE p.PrimitiveLanguageKindId = @PrimitiveLanguageKindId) <> 27
        THROW 50134, N'V00.02.000130 expected exactly 27 Markdown primitive inputs.', 1;

    IF (SELECT COUNT(*) FROM ATAPUtilities.RulePrimitiveComposition
        WHERE RulePhiloteId = @RulePhiloteId) <> 2
        THROW 50135, N'V00.02.000130 expected exactly two MarkdownDocument composition rows.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM ATAPUtilities.RulePrimitiveComposition AS c1
        INNER JOIN ATAPUtilities.RulePrimitive AS p1 ON p1.PhiloteId = c1.PrimitivePhiloteId
        INNER JOIN ATAPUtilities.RulePrimitiveComposition AS c2 ON c2.RulePhiloteId = c1.RulePhiloteId
        INNER JOIN ATAPUtilities.RulePrimitive AS p2 ON p2.PhiloteId = c2.PrimitivePhiloteId
        WHERE c1.RulePhiloteId = @RulePhiloteId
          AND c1.SequenceKey = N'001' AND p1.[Name] = N'AtxHeading'
          AND c2.SequenceKey = N'002' AND p2.[Name] = N'MarkdownBlock'
    )
        THROW 50136, N'V00.02.000130 composition order does not match the approved grammar.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

PRINT N'V00.02.000130 - Markdown Kind, primitives, inputs, Rule, and approved composition added.';

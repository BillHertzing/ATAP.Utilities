-- Verifies Sprint 0013 Task 13.85: Markdown Kind and immutable
-- ATAP.org InstantiationVersion 2 documentation slice.
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Failures TABLE (
    Area NVARCHAR(80) NOT NULL,
    Finding NVARCHAR(500) NOT NULL
);

DECLARE @MarkdownKindId TINYINT = 10;
DECLARE @MarkdownDocumentRule UNIQUEIDENTIFIER = '181D5E43-F2E2-4A29-B720-45991D52EF6E';
DECLARE @InstantiationV1 UNIQUEIDENTIFIER = '2AF23C2B-A98B-4701-8EFE-1C060C852D61';
DECLARE @InstantiationV2 UNIQUEIDENTIFIER = '8E98B9B4-8AC2-4713-B11E-7A8D4071C0B0';
DECLARE @PathRuleSetV2 UNIQUEIDENTIFIER = '03BF1DD5-0341-4D22-B764-3887F55C9962';
DECLARE @FilesRuleSetV2 UNIQUEIDENTIFIER = 'AE97CAFC-0C76-46A5-8E1E-F986DD7ABC24';
DECLARE @BuildSetV2 UNIQUEIDENTIFIER = 'BEFB3248-501F-4FE3-B6DA-825FB4B968B7';
DECLARE @IndexRiv UNIQUEIDENTIFIER = 'F54E2878-F7D6-41ED-883E-B02A16AC2567';
DECLARE @WriteRiv UNIQUEIDENTIFIER = '21738901-03B5-4143-88E8-3D93A3EEB4B7';

IF (SELECT COUNT(*) FROM ATAPUtilities.PrimitiveLanguageKind
    WHERE PrimitiveLanguageKindId = @MarkdownKindId AND [Name] = N'Markdown') <> 1
    INSERT INTO @Failures VALUES (N'Kind', N'Expected Markdown PrimitiveLanguageKindId 10 exactly once.');

IF (SELECT COUNT(*) FROM ATAPUtilities.RulePrimitive
    WHERE PrimitiveLanguageKindId = @MarkdownKindId) <> 14
    INSERT INTO @Failures VALUES (N'Primitives', N'Expected exactly 14 Markdown RulePrimitive rows.');

IF (SELECT COUNT(*)
    FROM ATAPUtilities.RulePrimitiveInput AS i
    INNER JOIN ATAPUtilities.RulePrimitive AS p ON p.PhiloteId = i.PhiloteId
    WHERE p.PrimitiveLanguageKindId = @MarkdownKindId) <> 27
    INSERT INTO @Failures VALUES (N'Inputs', N'Expected exactly 27 Markdown RulePrimitiveInput rows.');

IF (SELECT COUNT(*) FROM ATAPUtilities.RulePrimitiveComposition
    WHERE RulePhiloteId = @MarkdownDocumentRule) <> 2
    INSERT INTO @Failures VALUES (N'Composition', N'Expected exactly two MarkdownDocument composition rows.');

IF EXISTS (
    SELECT SequenceKey
    FROM ATAPUtilities.RulePrimitiveComposition
    WHERE RulePhiloteId = @MarkdownDocumentRule
    GROUP BY SequenceKey
    HAVING COUNT(*) <> 1
)
    INSERT INTO @Failures VALUES (N'Composition', N'MarkdownDocument SequenceKey values are not unique.');

IF NOT EXISTS (
    SELECT 1
    FROM ATAPUtilities.RulePrimitiveComposition AS c1
    INNER JOIN ATAPUtilities.RulePrimitive AS p1 ON p1.PhiloteId = c1.PrimitivePhiloteId
    INNER JOIN ATAPUtilities.RulePrimitiveComposition AS c2 ON c2.RulePhiloteId = c1.RulePhiloteId
    INNER JOIN ATAPUtilities.RulePrimitive AS p2 ON p2.PhiloteId = c2.PrimitivePhiloteId
    WHERE c1.RulePhiloteId = @MarkdownDocumentRule
      AND c1.SequenceKey = N'001' AND p1.[Name] = N'AtxHeading'
      AND c2.SequenceKey = N'002' AND p2.[Name] = N'MarkdownBlock'
)
    INSERT INTO @Failures VALUES (N'Composition', N'Expected gap-free 001 AtxHeading, 002 MarkdownBlock ordering.');

IF (SELECT COUNT(*) FROM ATAPUtilities.RuleSetVersionMember
    WHERE RuleSetVersionPhiloteId = @PathRuleSetV2 AND EffectiveTo IS NULL) <> 12
    INSERT INTO @Failures VALUES (N'Path membership', N'Expected 12 current RuleVersions in Path RuleSetVersion 2.');

IF EXISTS (
    SELECT 1
    FROM ATAPUtilities.RuleSetVersionMember
    WHERE RuleSetVersionPhiloteId = @PathRuleSetV2 AND EffectiveTo IS NULL
    GROUP BY SortOrder
    HAVING COUNT(*) <> 1
)
    INSERT INTO @Failures VALUES (N'Path membership', N'Path RuleSetVersion 2 SortOrder values are not unique.');

IF (SELECT MIN(SortOrder) FROM ATAPUtilities.RuleSetVersionMember
    WHERE RuleSetVersionPhiloteId = @PathRuleSetV2 AND EffectiveTo IS NULL) <> 10
 OR (SELECT MAX(SortOrder) FROM ATAPUtilities.RuleSetVersionMember
    WHERE RuleSetVersionPhiloteId = @PathRuleSetV2 AND EffectiveTo IS NULL) <> 120
    INSERT INTO @Failures VALUES (N'Path membership', N'Path RuleSetVersion 2 ordering must span 10 through 120.');

IF (SELECT COUNT(*) FROM ATAPUtilities.RuleSetVersionMember
    WHERE RuleSetVersionPhiloteId = @FilesRuleSetV2 AND EffectiveTo IS NULL) <> 3
    INSERT INTO @Failures VALUES (N'File membership', N'Expected three current RuleVersions in File RuleSetVersion 2.');

IF (SELECT COUNT(DISTINCT SortOrder) FROM ATAPUtilities.RuleSetVersionMember
    WHERE RuleSetVersionPhiloteId = @FilesRuleSetV2 AND EffectiveTo IS NULL) <> 3
 OR (SELECT MIN(SortOrder) FROM ATAPUtilities.RuleSetVersionMember
    WHERE RuleSetVersionPhiloteId = @FilesRuleSetV2 AND EffectiveTo IS NULL) <> 10
 OR (SELECT MAX(SortOrder) FROM ATAPUtilities.RuleSetVersionMember
    WHERE RuleSetVersionPhiloteId = @FilesRuleSetV2 AND EffectiveTo IS NULL) <> 30
    INSERT INTO @Failures VALUES (N'File membership', N'File RuleSetVersion 2 ordering must be unique and span 10 through 30.');

IF (SELECT COUNT(*) FROM ATAPUtilities.BuildSetVersionMember
    WHERE BuildSetVersionPhiloteId = @BuildSetV2 AND EffectiveTo IS NULL) <> 2
    INSERT INTO @Failures VALUES (N'BuildSet membership', N'Expected two current RuleSetVersions in BuildSetVersion 2.');

IF (SELECT COUNT(*) FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion
    WHERE InstantiationVersionPhiloteId = @InstantiationV2 AND EffectiveTo IS NULL) <> 15
    INSERT INTO @Failures VALUES (N'V2 snapshot', N'Expected 15 current RuleInstantiationVersions in InstantiationVersion 2.');

IF (SELECT COUNT(DISTINCT SortOrder) FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion
    WHERE InstantiationVersionPhiloteId = @InstantiationV2 AND EffectiveTo IS NULL) <> 15
 OR (SELECT MIN(SortOrder) FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion
    WHERE InstantiationVersionPhiloteId = @InstantiationV2 AND EffectiveTo IS NULL) <> 10
 OR (SELECT MAX(SortOrder) FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion
    WHERE InstantiationVersionPhiloteId = @InstantiationV2 AND EffectiveTo IS NULL) <> 150
    INSERT INTO @Failures VALUES (N'V2 snapshot', N'InstantiationVersion 2 ordering must be unique and span 10 through 150.');

IF EXISTS (
    SELECT 1
    FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion AS m
    INNER JOIN ATAPUtilities.RuleInstantiationVersion AS riv
        ON riv.RuleInstantiationVersionPhiloteId = m.RuleInstantiationVersionPhiloteId
    INNER JOIN ATAPUtilities.RuleVersionPrimitiveComposition AS c
        ON c.RuleVersionPhiloteId = riv.RuleVersionPhiloteId
    INNER JOIN ATAPUtilities.RulePrimitive AS p
        ON p.PhiloteId = c.PrimitivePhiloteId
    INNER JOIN ATAPUtilities.RulePrimitiveInput AS i
        ON i.PhiloteId = c.PrimitivePhiloteId
    WHERE m.InstantiationVersionPhiloteId = @InstantiationV2
      AND p.[Name] <> N'SourceLine'
      AND i.IsRequired = 1
      AND i.DefaultValue IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM ATAPUtilities.RuleInstantiationBinding AS b
          WHERE b.InstantiationPhiloteId = riv.RuleInstantiationPhiloteId
            AND b.InputName = i.InputName
            AND b.EffectiveFrom <= riv.EffectiveFrom
            AND (b.EffectiveTo IS NULL OR b.EffectiveTo > riv.EffectiveFrom)
      )
)
    INSERT INTO @Failures VALUES (N'Input completeness', N'At least one required non-SourceLine input lacks a snapshot-effective binding.');

IF (SELECT COUNT(*) FROM ATAPUtilities.RuleInstantiationVersionSourceLine
    WHERE RuleInstantiationVersionPhiloteId = @IndexRiv AND EffectiveTo IS NULL) <> 40
    INSERT INTO @Failures VALUES (N'INDEX.md source', N'Expected exactly 40 immutable INDEX.md source lines.');

IF (SELECT COUNT(*) FROM ATAPUtilities.RuleInstantiationVersionSourceLine
    WHERE RuleInstantiationVersionPhiloteId = @WriteRiv AND EffectiveTo IS NULL) <> 190
    INSERT INTO @Failures VALUES (N'Write-ArrayIndented.md source', N'Expected exactly 190 immutable Write-ArrayIndented.md source lines.');

IF EXISTS (
    SELECT RuleInstantiationVersionPhiloteId
    FROM ATAPUtilities.RuleInstantiationVersionSourceLine
    WHERE RuleInstantiationVersionPhiloteId IN (@IndexRiv, @WriteRiv)
      AND EffectiveTo IS NULL
    GROUP BY RuleInstantiationVersionPhiloteId
    HAVING MIN(Ordinal) <> 1 OR MAX(Ordinal) <> COUNT(*) OR COUNT(DISTINCT Ordinal) <> COUNT(*)
)
    INSERT INTO @Failures VALUES (N'Markdown source', N'Markdown source-line ordinals are not unique and gap-free from one.');

IF (SELECT COUNT(*) FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion
    WHERE InstantiationVersionPhiloteId = @InstantiationV1 AND EffectiveTo IS NULL) <> 8
    INSERT INTO @Failures VALUES (N'V1 immutability', N'InstantiationVersion 1 snapshot membership drifted from eight rows.');

IF (SELECT COUNT(*) FROM ATAPUtilities.ManifestationArtifact
    WHERE InstantiationVersionPhiloteId = @InstantiationV1 AND EffectiveTo IS NULL) <> 5
    INSERT INTO @Failures VALUES (N'V1 immutability', N'InstantiationVersion 1 artifacts drifted from five rows.');

IF (SELECT COUNT(*) FROM ATAPUtilities.RuleInstantiationVersionSourceLine
    WHERE RuleInstantiationVersionPhiloteId = '5A1D2179-4E07-4F79-9F8C-3D024FAAFAAC'
      AND EffectiveTo IS NULL) <> 75
    INSERT INTO @Failures VALUES (N'V1 immutability', N'InstantiationVersion 1 PowerShell source drifted from 75 rows.');

IF (SELECT COUNT(*) FROM ATAPUtilities.ManifestationArtifact
    WHERE InstantiationVersionPhiloteId = @InstantiationV2 AND EffectiveTo IS NULL) <> 3
    INSERT INTO @Failures VALUES (N'V2 artifacts', N'Expected one directory and two Markdown file artifacts.');

IF EXISTS (SELECT 1 FROM @Failures)
BEGIN
    SELECT Area, Finding FROM @Failures ORDER BY Area, Finding;
    DECLARE @Message NVARCHAR(2048) = CONCAT(
        N'Task 13.85 verification failed with ',
        (SELECT COUNT(*) FROM @Failures),
        N' finding(s).'
    );
    THROW 50185, @Message, 1;
END;

SELECT
    N'PASS' AS Result,
    14 AS MarkdownPrimitiveCount,
    27 AS MarkdownInputCount,
    2 AS MarkdownCompositionCount,
    15 AS InstantiationV2SnapshotCount,
    3 AS InstantiationV2ArtifactCount,
    40 AS IndexSourceLineCount,
    190 AS WriteSourceLineCount;

-- Task 13.79 verification: corrected ATAP.org InstantiationVersion 1.
-- Read-only against ATAPUtilities; tempdb objects only.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @InstantiationVersionPhiloteId UNIQUEIDENTIFIER =
    '2AF23C2B-A98B-4701-8EFE-1C060C852D61';
DECLARE @FileRuleInstantiationVersionPhiloteId UNIQUEIDENTIFIER =
    '5A1D2179-4E07-4F79-9F8C-3D024FAAFAAC';
DECLARE @ExpectedPath NVARCHAR(500) =
    N'ATAP.Utilities\src\ATAP.Utilities.PowerShell\public\Write-ArrayIndented.ps1';
DECLARE @ExpectedSha256 CHAR(64) =
    '207425988293F2ACA9BAC4A9B72E7F18CA971EB3CF5AFE78FEB46130C219F63A';
DECLARE @Failure TABLE (
    CheckName NVARCHAR(200) NOT NULL,
    Detail NVARCHAR(MAX) NOT NULL
);

IF OBJECT_ID(N'ATAPUtilities.RuleInstantiationVersionSourceLine', N'U') IS NULL
    INSERT INTO @Failure VALUES
        (N'Schema.SourceLineTable', N'RuleInstantiationVersionSourceLine is missing.');

IF NOT EXISTS (
    SELECT 1
    FROM ATAPUtilities.InstantiationVersion
    WHERE InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
      AND BuildSetVersionPhiloteId = 'C7B2B89F-7A41-445C-AD45-F5EE05D3B848'
      AND EffectiveTo IS NULL
)
    INSERT INTO @Failure VALUES
        (N'Graph.Root', N'InstantiationVersion 1 is absent or not bound to the expected BuildSetVersion.');

IF (
    SELECT COUNT(*)
    FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion
    WHERE InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
      AND EffectiveTo IS NULL
) <> 8
    INSERT INTO @Failure VALUES
        (N'Graph.SnapshotCount', N'Expected exactly eight current RuleInstantiationVersion members.');

IF EXISTS (
    SELECT 1
    FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion
    WHERE InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
      AND EffectiveTo IS NULL
    GROUP BY InstantiationVersionPhiloteId
    HAVING COUNT(*) <> COUNT(DISTINCT SortOrder)
)
    INSERT INTO @Failure VALUES
        (N'Graph.SnapshotOrdering', N'RuleInstantiationVersion snapshot SortOrder contains duplicates.');

IF EXISTS (
    SELECT 1
    FROM ATAPUtilities.RuleInstantiationVersionSourceLine
    WHERE RuleInstantiationVersionPhiloteId = @FileRuleInstantiationVersionPhiloteId
      AND EffectiveTo IS NULL
    GROUP BY RuleInstantiationVersionPhiloteId
    HAVING COUNT(*) <> 75
        OR MIN(Ordinal) <> 1
        OR MAX(Ordinal) <> 75
        OR COUNT(*) <> COUNT(DISTINCT Ordinal)
)
    INSERT INTO @Failure VALUES
        (N'SourceLine.Ordering', N'Expected 75 unique contiguous current source lines numbered 1..75.');

IF NOT EXISTS (
    SELECT 1
    FROM ATAPUtilities.RuleInstantiationVersionSourceLine
    WHERE RuleInstantiationVersionPhiloteId = @FileRuleInstantiationVersionPhiloteId
      AND EffectiveTo IS NULL
)
    INSERT INTO @Failure VALUES
        (N'SourceLine.NonVacuous', N'No current source lines were found.');

IF EXISTS (
    SELECT 1
    FROM ATAPUtilities.RuleInstantiationVersionSourceLine
    WHERE RuleInstantiationVersionPhiloteId = @FileRuleInstantiationVersionPhiloteId
      AND EffectiveTo IS NULL
      AND LineEnding <> N'CRLF'
)
    INSERT INTO @Failure VALUES
        (N'SourceLine.LineEnding', N'Every version-1 source line must retain CRLF.');

DECLARE @RenderedText NVARCHAR(MAX);
SELECT @RenderedText =
    STRING_AGG(
        CAST(LineText
             + CASE LineEnding
                   WHEN N'CRLF' THEN NCHAR(13) + NCHAR(10)
                   WHEN N'LF' THEN NCHAR(10)
                   ELSE N''
               END AS NVARCHAR(MAX)),
        N''
    ) WITHIN GROUP (ORDER BY Ordinal)
FROM ATAPUtilities.RuleInstantiationVersionSourceLine
WHERE RuleInstantiationVersionPhiloteId = @FileRuleInstantiationVersionPhiloteId
  AND EffectiveTo IS NULL;

DECLARE @RenderedBytes VARBINARY(MAX) =
    CONVERT(VARBINARY(MAX),
        CONVERT(VARCHAR(MAX), @RenderedText COLLATE Latin1_General_100_BIN2_UTF8));
DECLARE @RenderedSha256 CHAR(64) =
    CONVERT(CHAR(64), HASHBYTES('SHA2_256', @RenderedBytes), 2);

IF @RenderedSha256 <> @ExpectedSha256
    INSERT INTO @Failure VALUES
        (N'SourceLine.Sha256',
         N'Rendered SHA-256 ' + COALESCE(@RenderedSha256, N'<null>')
         + N' does not equal ' + @ExpectedSha256 + N'.');

DECLARE @RenderedPath NVARCHAR(MAX) = (
    SELECT rib.InputValue
    FROM ATAPUtilities.RuleInstantiationBinding AS rib
    WHERE rib.InstantiationPhiloteId = 'B804DF3C-17E2-49CC-93B5-728A33C95B5E'
      AND rib.InputName = N'Value'
      AND rib.EffectiveTo IS NULL
);

IF @RenderedPath COLLATE Latin1_General_100_BIN2
   <> @ExpectedPath COLLATE Latin1_General_100_BIN2
    INSERT INTO @Failure VALUES
        (N'Path.ExactCase',
         N'Rendered path differs from the exact expected path: ' + COALESCE(@RenderedPath, N'<null>'));

IF EXISTS (
    SELECT 1
    FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion AS ivriv
    INNER JOIN ATAPUtilities.RuleInstantiationVersion AS riv
        ON riv.RuleInstantiationVersionPhiloteId = ivriv.RuleInstantiationVersionPhiloteId
       AND riv.EffectiveTo IS NULL
    INNER JOIN ATAPUtilities.RuleVersionPrimitiveComposition AS rvpc
        ON rvpc.RuleVersionPhiloteId = riv.RuleVersionPhiloteId
       AND rvpc.EffectiveTo IS NULL
    INNER JOIN ATAPUtilities.RulePrimitiveInput AS rpi
        ON rpi.PhiloteId = rvpc.PrimitivePhiloteId
       AND rpi.IsRequired = 1
    LEFT JOIN ATAPUtilities.RuleInstantiationBinding AS rib
        ON rib.InstantiationPhiloteId = riv.RuleInstantiationPhiloteId
       AND rib.InputName = rpi.InputName
       AND rib.EffectiveTo IS NULL
    WHERE ivriv.InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
      AND ivriv.EffectiveTo IS NULL
      AND rib.RuleInstantiationBindingId IS NULL
)
    INSERT INTO @Failure VALUES
        (N'Input.RequiredCompleteness', N'At least one required primitive input lacks a current binding.');

IF EXISTS (
    SELECT 1
    FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion AS ivriv
    INNER JOIN ATAPUtilities.RuleInstantiationVersion AS riv
        ON riv.RuleInstantiationVersionPhiloteId = ivriv.RuleInstantiationVersionPhiloteId
       AND riv.EffectiveTo IS NULL
    INNER JOIN ATAPUtilities.RuleInstantiationBinding AS rib
        ON rib.InstantiationPhiloteId = riv.RuleInstantiationPhiloteId
       AND rib.EffectiveTo IS NULL
    WHERE ivriv.InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
      AND ivriv.EffectiveTo IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM ATAPUtilities.RuleVersionPrimitiveComposition AS rvpc
          INNER JOIN ATAPUtilities.RulePrimitiveInput AS rpi
              ON rpi.PhiloteId = rvpc.PrimitivePhiloteId
             AND rpi.InputName = rib.InputName
          WHERE rvpc.RuleVersionPhiloteId = riv.RuleVersionPhiloteId
            AND rvpc.EffectiveTo IS NULL
      )
)
    INSERT INTO @Failure VALUES
        (N'Input.Undeclared', N'At least one current binding is not declared by an in-graph primitive.');

IF (
    SELECT COUNT(*)
    FROM ATAPUtilities.ManifestationArtifact
    WHERE InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
      AND EffectiveTo IS NULL
      AND RenderPolicy = N'Planned'
) <> 5
    INSERT INTO @Failure VALUES
        (N'Artifacts.Planned', N'Expected four planned directories and one planned file.');

IF OBJECT_ID(N'ATAPUtilities.Build', N'U') IS NOT NULL
   OR OBJECT_ID(N'ATAPUtilities.BuildVersion', N'U') IS NOT NULL
    INSERT INTO @Failure VALUES
        (N'Graph.NoBuildLayer', N'Build or BuildVersion exists; the corrected graph forbids both.');

IF EXISTS (SELECT 1 FROM @Failure)
BEGIN
    SELECT CheckName, Detail FROM @Failure ORDER BY CheckName;
    DECLARE @FailureCount INT = (SELECT COUNT(*) FROM @Failure);
    RAISERROR(N'Verify_ATAPorg_Instantiation_V1 failed with %d finding(s).', 16, 1, @FailureCount);
    RETURN;
END;

SELECT
    N'PASS' AS Result,
    @InstantiationVersionPhiloteId AS InstantiationVersionPhiloteId,
    @RenderedPath AS RelativePath,
    DATALENGTH(@RenderedBytes) AS RenderedByteCount,
    @RenderedSha256 AS RenderedSha256,
    (SELECT COUNT(*)
     FROM ATAPUtilities.RuleInstantiationVersionSourceLine
     WHERE RuleInstantiationVersionPhiloteId = @FileRuleInstantiationVersionPhiloteId
       AND EffectiveTo IS NULL) AS SourceLineCount,
    (SELECT COUNT(*)
     FROM ATAPUtilities.ManifestationArtifact
     WHERE InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
       AND EffectiveTo IS NULL) AS PlannedArtifactCount;
GO

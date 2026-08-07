<#
.SYNOPSIS
Builds the tracked RDB-510 reference-catalog Flyway migration from reviewed Wave 6 fragments.

.DESCRIPTION
This is a deterministic source-to-source assembler.  It neither connects to SQL
Server nor resolves any secret.  It validates that each fragment's recorded
source hash still matches the referenced repository source before producing the
migration.  The generated migration is the reviewed delivery artifact; this
tool is retained so a later fragment correction can be integrated mechanically.
#>
function New-Rdb510SeedMigration {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string] $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,

        [Parameter()]
        [string] $OutputPath
    )

    begin {
        $fn = 'New-Rdb510SeedMigration'
        $mn = 'ATAP.Utilities.Database.Tools'
        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            $OutputPath = Join-Path $RepositoryRoot 'Database\Flyway\SQL\V00020__Seed_RRSBS_Reference_Catalog.sql'
        }
        $fragmentRoot = Join-Path $RepositoryRoot '_generated\RRSBS-V2\fragments'
        $directFragments = @(
            'RDB-500A__CSharp.sql',
            'RDB-500B__PowerShell.sql',
            'RDB-500C__SQL-MSBuild.sql',
            'RDB-500D__Path.sql',
            'RDB-500E__OtterScript.sql',
            'RDB-500F__AgentText.sql',
            'RDB-500H__Markdown.sql',
            'RDB-500I__ManimScene.sql'
        )
        # H/I were finalized as direct, idempotent DML fragments.  Keep this
        # array only for a future fragment whose reviewed contract is genuinely
        # declarative and has a dedicated materializer.
        $declarativeFragments = @()
        $tailFragments = @('RDB-500O__ExpertiseDomain.sql', 'RDB-500P__AttributionMetadata.sql')
    }

    process {
        try {
            $allFragments = @($directFragments + $declarativeFragments + $tailFragments)
            foreach ($fragment in $allFragments) {
                $fragmentPath = Join-Path $fragmentRoot $fragment
                if (-not (Test-Path -LiteralPath $fragmentPath -PathType Leaf)) {
                    throw "Required RDB-510 fragment is absent: $fragmentPath"
                }
            }

            $sources = [ordered]@{}
            foreach ($fragment in $directFragments) {
                $text = Get-Content -LiteralPath (Join-Path $fragmentRoot $fragment) -Raw
                $pathMatches = [regex]::Matches($text, "RepoRelativePathOrExternalLocator = N'(?<path>[^']+)'(?s:.*?)NormalizedContentSha256 = '(?<hash>[0-9a-f]{64})'")
                foreach ($match in $pathMatches) {
                    $path = $match.Groups['path'].Value
                    $hash = $match.Groups['hash'].Value
                    if ($sources.Contains($path) -and $sources[$path] -ne $hash) {
                        throw "Conflicting expected source hashes for '$path'."
                    }
                    $sources[$path] = $hash
                }
            }
            foreach ($task in @('RDB-500H', 'RDB-500I')) {
                $manifestPath = Join-Path $RepositoryRoot "_generated\RRSBS-V2\$task\SeedManifest.json"
                if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
                    throw "Required declarative seed manifest is absent: $manifestPath"
                }
                $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 32
                foreach ($source in $manifest.sources) {
                    if ($sources.Contains($source.path) -and $sources[$source.path] -ne $source.sha256) {
                        throw "Conflicting expected source hashes for '$($source.path)'."
                    }
                    $sources[$source.path] = $source.sha256
                }
            }
            if ($sources.Count -ne 18) {
                throw "Expected 18 exact grammar/compendium source inputs, found $($sources.Count)."
            }

            $sourceRows = [Collections.Generic.List[string]]::new()
            foreach ($path in $sources.Keys | Sort-Object) {
                $literalPath = Join-Path $RepositoryRoot $path
                if (-not (Test-Path -LiteralPath $literalPath -PathType Leaf)) {
                    throw "Required RDB-510 source is absent: $literalPath"
                }
                $bytes = [IO.File]::ReadAllBytes($literalPath)
                $actualHash = (Get-FileHash -LiteralPath $literalPath -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($actualHash -ne $sources[$path]) {
                    throw "Frozen source hash mismatch for '$path': expected $($sources[$path]), actual $actualHash."
                }
                $bom = [int]($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
                $text = [Text.Encoding]::UTF8.GetString($bytes)
                $hasCrLf = $text.Contains("`r`n")
                $hasLf = $text.Contains("`n")
                $hasCr = $text.Contains("`r")
                $lineEnding = if ($hasCrLf -and (($text -replace "`r`n", '').Contains("`n") -or ($text -replace "`r`n", '').Contains("`r"))) { 'mixed' } elseif ($hasCrLf) { 'crlf' } elseif ($hasLf) { 'lf' } elseif ($hasCr) { 'cr' } else { 'none' }
                $hasFinalNewline = [int]($bytes.Length -gt 0 -and ($bytes[$bytes.Length - 1] -eq 0x0A -or $bytes[$bytes.Length - 1] -eq 0x0D))
                $safePath = $path.Replace("'", "''")
                $sourceRows.Add("        (N'$safePath', '$actualHash', '$actualHash', $($bytes.Length), $bom, '$lineEnding', $hasFinalNewline)")
            }

            $header = @'
/*
  RDB-510 — Wave 6 reference-catalog integration.
  Generated mechanically from RDB-500A-F/H/I/O/P fragments by
  Database/Tools/New-Rdb510SeedMigration.ps1.  Do not hand-edit the assembled
  fragment bodies; correct their owner fragment and regenerate.

  G (ContentSummary) is deliberately zero-row: RDB-190/RDB-320 allocation is
  still blocked.  J-N are deliberately absent pending their individual RDB-185
  and policy approvals.  No observed Manifestation is seeded.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Rdb510PublishedAtUtc datetime2(7) = CONVERT(datetime2(7), '2026-08-06T00:00:00.0000000Z', 127);

    DECLARE @Rdb510EntityTypes table
    (
        EntityTypeCode varchar(64) NOT NULL PRIMARY KEY,
        OwningSliceCode varchar(16) NOT NULL,
        IsVersionType bit NOT NULL
    );
    INSERT @Rdb510EntityTypes VALUES
        ('authority', 'RDB-200', 0), ('authority-version', 'RDB-200', 1),
        ('expert', 'RDB-200', 0), ('expert-version', 'RDB-200', 1),
        ('expertise-domain', 'RDB-200', 0), ('expertise-domain-version', 'RDB-200', 1),
        ('tag', 'RDB-200', 0), ('tag-version', 'RDB-200', 1),
        ('attribution', 'RDB-200', 0), ('attribution-dispute', 'RDB-200', 0),
        ('rule-kind', 'RDB-210', 0), ('rule-kind-version', 'RDB-210', 1),
        ('executor-contract', 'RDB-210', 0), ('executor-contract-version', 'RDB-210', 1),
        ('primitive', 'RDB-210', 0), ('primitive-version', 'RDB-210', 1),
        ('primitive-input-definition', 'RDB-210', 1), ('value-type', 'RDB-210', 0),
        ('value-type-version', 'RDB-210', 1), ('structured-value-contract', 'RDB-210', 0),
        ('structured-value-contract-version', 'RDB-210', 1),
        ('rule', 'RDB-220', 0), ('rule-version', 'RDB-220', 1),
        ('rule-input-definition', 'RDB-220', 1), ('rule-default-input-value', 'RDB-220', 1),
        ('rule-output-definition', 'RDB-220', 1),
        ('rule-set', 'RDB-230', 0), ('rule-set-version', 'RDB-230', 1),
        ('build-set', 'RDB-230', 0), ('build-set-version', 'RDB-230', 1),
        ('instantiation', 'RDB-240', 0), ('instantiation-version', 'RDB-240', 1),
        ('input-block', 'RDB-240', 0), ('input-block-version', 'RDB-240', 1),
        ('manifestation-plan', 'RDB-250', 0), ('plan-approval', 'RDB-250', 0),
        ('manifestation', 'RDB-250', 0), ('manifestation-artifact', 'RDB-250', 0),
        ('organization', 'RDB-260', 0), ('repository', 'RDB-260', 0),
        ('source-artifact', 'RDB-260', 0), ('content-summary', 'RDB-260', 0),
        ('agent-text-projection', 'RDB-260', 0);
    IF (SELECT COUNT(*) FROM @Rdb510EntityTypes) <> 43
        THROW 55550, 'RDB-510 EntityType catalog must contain exactly 43 rows.', 1;
    IF EXISTS
    (
        SELECT 1 FROM @Rdb510EntityTypes AS [seed]
        INNER JOIN [ATAPUtilities].[EntityType] AS [existing]
            ON [existing].[EntityTypeCode] = [seed].[EntityTypeCode]
        WHERE [existing].[OwningSliceCode] <> [seed].[OwningSliceCode]
           OR [existing].[IsVersionType] <> [seed].[IsVersionType]
    ) THROW 55551, 'RDB-510 EntityType catalog collision.', 1;
    INSERT [ATAPUtilities].[EntityType] ([EntityTypeCode], [OwningSliceCode], [IsVersionType])
    SELECT [EntityTypeCode], [OwningSliceCode], [IsVersionType]
    FROM @Rdb510EntityTypes AS [seed]
    WHERE NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[EntityType] AS [existing]
                      WHERE [existing].[EntityTypeCode] = [seed].[EntityTypeCode]);

    INSERT [ATAPUtilities].[ExecutionClassification]
        ([ExecutionClassificationCode], [AllowsExecutorContract], [RequiresPlanApproval], [AllowsSideEffects], [RequiresObservationOnly], [RequiresFrozenOutput])
    SELECT [Code], [AllowsExecutorContract], [RequiresPlanApproval], [AllowsSideEffects], [RequiresObservationOnly], [RequiresFrozenOutput]
    FROM (VALUES
        ('metadata-only', CONVERT(bit,0), CONVERT(bit,0), CONVERT(bit,0), CONVERT(bit,0), CONVERT(bit,0)),
        ('deterministic', CONVERT(bit,0), CONVERT(bit,0), CONVERT(bit,0), CONVERT(bit,0), CONVERT(bit,1))
    ) AS [seed] ([Code], [AllowsExecutorContract], [RequiresPlanApproval], [AllowsSideEffects], [RequiresObservationOnly], [RequiresFrozenOutput])
    WHERE NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ExecutionClassification] AS [existing] WHERE [existing].[ExecutionClassificationCode] = [seed].[Code]);
    INSERT [ATAPUtilities].[SecurityCapabilityClassification] ([SecurityCapabilityCode], [IsDefaultDeny], [RequiresSeparateApproval])
    SELECT 'reference-safe', CONVERT(bit,1), CONVERT(bit,0)
    WHERE NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[SecurityCapabilityClassification] WHERE [SecurityCapabilityCode] = 'reference-safe');
    INSERT [ATAPUtilities].[RoundTripPolicy] ([RoundTripPolicyCode], [RequiresByteHash], [RequiresCanonicalization], [RequiresFrozenObservation])
    SELECT [Code], [ByteHash], [Canonical], [Frozen]
    FROM (VALUES
        ('byte-identical', CONVERT(bit,1), CONVERT(bit,0), CONVERT(bit,0)),
        ('semantic-equivalent', CONVERT(bit,0), CONVERT(bit,1), CONVERT(bit,0))
    ) AS [seed] ([Code], [ByteHash], [Canonical], [Frozen])
    WHERE NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RoundTripPolicy] AS [existing] WHERE [existing].[RoundTripPolicyCode] = [seed].[Code]);
    INSERT [ATAPUtilities].[ScalarStorageKind] ([ScalarStorageKindCode], [RelationalRepresentationCode], [CanonicalSerializationCode])
    SELECT 'bounded-unicode-text', 'nvarchar', 'utf8-nfc-json-string'
    WHERE NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ScalarStorageKind] WHERE [ScalarStorageKindCode] = 'bounded-unicode-text');
    INSERT [ATAPUtilities].[BindingShape] ([BindingShapeCode], [RequiresConstant], [RequiresRuleInput], [RequiresDerivation])
    SELECT 'constant', CONVERT(bit,1), CONVERT(bit,0), CONVERT(bit,0)
    WHERE NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[BindingShape] WHERE [BindingShapeCode] = 'constant');

    INSERT [ATAPUtilities].[PolicyVersion] ([PolicyKindCode], [PolicyCode], [RevisionSequence], [PolicyContractHash], [PublishedAtUtc])
    SELECT 'classification', 'rdb510-reference-seed', 1, HASHBYTES('SHA2_256', N'rdb510-reference-seed-classification-v1'), @Rdb510PublishedAtUtc
    WHERE NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PolicyVersion]
                      WHERE [PolicyKindCode] = 'classification' AND [PolicyCode] = 'rdb510-reference-seed' AND [RevisionSequence] = 1);
    DECLARE @Rdb510ClassificationPolicyVersionId bigint =
        (SELECT [PolicyVersionId] FROM [ATAPUtilities].[PolicyVersion]
         WHERE [PolicyKindCode] = 'classification' AND [PolicyCode] = 'rdb510-reference-seed' AND [RevisionSequence] = 1);

    DECLARE @Rdb510OrganizationTypeId bigint = (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'organization');
    DECLARE @Rdb510RepositoryTypeId bigint = (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'repository');
    DECLARE @Rdb510ArtifactTypeId bigint = (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'source-artifact');
    DECLARE @Rdb510OrganizationPhilote uniqueidentifier = CONVERT(uniqueidentifier, SUBSTRING(HASHBYTES('SHA2_256', N'rrsbs-v2/seed-organization/atap'), 1, 16));
    DECLARE @Rdb510RepositoryPhilote uniqueidentifier = CONVERT(uniqueidentifier, SUBSTRING(HASHBYTES('SHA2_256', N'rrsbs-v2/seed-repository/atap-utilities'), 1, 16));
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] WHERE [EntityPhiloteId] = @Rdb510OrganizationPhilote)
        INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc]) VALUES (@Rdb510OrganizationTypeId, @Rdb510OrganizationPhilote, @Rdb510PublishedAtUtc);
    DECLARE @Rdb510OrganizationEntityId bigint = (SELECT [EntityId] FROM [ATAPUtilities].[Entity] WHERE [EntityPhiloteId] = @Rdb510OrganizationPhilote AND [EntityTypeId] = @Rdb510OrganizationTypeId);
    IF @Rdb510OrganizationEntityId IS NULL THROW 55552, 'RDB-510 organization Philote type collision.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Organization] WHERE [CanonicalName] = N'ATAP reference catalog')
        INSERT [ATAPUtilities].[Organization] ([OrganizationPhiloteId], [EntityId], [EntityTypeId], [CanonicalName], [ClassificationPolicyVersionId], [CreatedAtUtc])
        VALUES (@Rdb510OrganizationPhilote, @Rdb510OrganizationEntityId, @Rdb510OrganizationTypeId, N'ATAP reference catalog', @Rdb510ClassificationPolicyVersionId, @Rdb510PublishedAtUtc);
    DECLARE @Rdb510OrganizationId bigint = (SELECT [OrganizationId] FROM [ATAPUtilities].[Organization] WHERE [CanonicalName] = N'ATAP reference catalog');
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] WHERE [EntityPhiloteId] = @Rdb510RepositoryPhilote)
        INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc]) VALUES (@Rdb510RepositoryTypeId, @Rdb510RepositoryPhilote, @Rdb510PublishedAtUtc);
    DECLARE @Rdb510RepositoryEntityId bigint = (SELECT [EntityId] FROM [ATAPUtilities].[Entity] WHERE [EntityPhiloteId] = @Rdb510RepositoryPhilote AND [EntityTypeId] = @Rdb510RepositoryTypeId);
    IF @Rdb510RepositoryEntityId IS NULL THROW 55553, 'RDB-510 repository Philote type collision.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Repository] WHERE [OrganizationId] = @Rdb510OrganizationId AND [CanonicalRepositoryName] = N'ATAP.Utilities')
        INSERT [ATAPUtilities].[Repository] ([RepositoryPhiloteId], [EntityId], [EntityTypeId], [OrganizationId], [CanonicalRepositoryName], [ClassificationPolicyVersionId], [CreatedAtUtc])
        VALUES (@Rdb510RepositoryPhilote, @Rdb510RepositoryEntityId, @Rdb510RepositoryTypeId, @Rdb510OrganizationId, N'ATAP.Utilities', @Rdb510ClassificationPolicyVersionId, @Rdb510PublishedAtUtc);
    DECLARE @Rdb510RepositoryId bigint = (SELECT [RepositoryId] FROM [ATAPUtilities].[Repository] WHERE [OrganizationId] = @Rdb510OrganizationId AND [CanonicalRepositoryName] = N'ATAP.Utilities');

    DECLARE @Rdb510Sources table
    (
        RepoPath nvarchar(2048) NOT NULL PRIMARY KEY,
        NormalizedContentSha256 char(64) NOT NULL,
        ByteSha256 char(64) NOT NULL,
        ByteCount bigint NOT NULL,
        BomPresent bit NOT NULL,
        LineEndingCode varchar(16) NOT NULL,
        HasFinalNewline bit NOT NULL
    );
    INSERT @Rdb510Sources ([RepoPath], [NormalizedContentSha256], [ByteSha256], [ByteCount], [BomPresent], [LineEndingCode], [HasFinalNewline]) VALUES
'@
            $header += ($sourceRows -join ",`r`n") + ";`r`n"
            $header += @'

    IF EXISTS
    (
        SELECT 1 FROM @Rdb510Sources AS [seed]
        INNER JOIN [ATAPUtilities].[SourceArtifact] AS [artifact]
            ON [artifact].[RepositoryId] = @Rdb510RepositoryId
           AND [artifact].[LocatorTypeCode] = 'RepositoryPath'
           AND [artifact].[RepoRelativePathOrExternalLocator] = [seed].[RepoPath]
        INNER JOIN [ATAPUtilities].[SourceArtifactVersion] AS [version]
            ON [version].[SourceArtifactId] = [artifact].[SourceArtifactId]
           AND [version].[VersionSequence] = 1
        WHERE [version].[NormalizedContentSha256] <> [seed].[NormalizedContentSha256]
    ) THROW 55554, 'RDB-510 source-artifact version collision.', 1;

    INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
    SELECT @Rdb510ArtifactTypeId, CONVERT(uniqueidentifier, SUBSTRING(HASHBYTES('SHA2_256', N'rrsbs-v2/seed-source/' + [seed].[RepoPath]), 1, 16)), @Rdb510PublishedAtUtc
    FROM @Rdb510Sources AS [seed]
    WHERE NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] AS [entity]
                      WHERE [entity].[EntityPhiloteId] = CONVERT(uniqueidentifier, SUBSTRING(HASHBYTES('SHA2_256', N'rrsbs-v2/seed-source/' + [seed].[RepoPath]), 1, 16)));
    INSERT [ATAPUtilities].[SourceArtifact]
        ([SourceArtifactPhiloteId], [EntityId], [EntityTypeId], [RepositoryId], [SourceModuleId], [LocatorTypeCode], [RepoRelativePathOrExternalLocator], [LocatorIdentityHash], [LocatorNormalizerIdentityReference], [CreatedAtUtc])
    SELECT CONVERT(uniqueidentifier, SUBSTRING(HASHBYTES('SHA2_256', N'rrsbs-v2/seed-source/' + [seed].[RepoPath]), 1, 16)), [entity].[EntityId], @Rdb510ArtifactTypeId,
           @Rdb510RepositoryId, NULL, 'RepositoryPath', [seed].[RepoPath], HASHBYTES('SHA2_256', CONVERT(varbinary(max), [seed].[RepoPath])), N'rdb510-seed-path-normalizer:v1', @Rdb510PublishedAtUtc
    FROM @Rdb510Sources AS [seed]
    INNER JOIN [ATAPUtilities].[Entity] AS [entity]
      ON [entity].[EntityPhiloteId] = CONVERT(uniqueidentifier, SUBSTRING(HASHBYTES('SHA2_256', N'rrsbs-v2/seed-source/' + [seed].[RepoPath]), 1, 16))
     AND [entity].[EntityTypeId] = @Rdb510ArtifactTypeId
    WHERE NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[SourceArtifact] AS [existing]
                      WHERE [existing].[RepositoryId] = @Rdb510RepositoryId AND [existing].[LocatorTypeCode] = 'RepositoryPath'
                        AND [existing].[RepoRelativePathOrExternalLocator] = [seed].[RepoPath]);
    INSERT [ATAPUtilities].[SourceArtifactVersion]
        ([SourceArtifactId], [VersionSequence], [NormalizedContentSha256], [ByteSha256], [ByteCount], [EncodingCode], [BomPresent], [LineEndingCode], [HasFinalNewline], [ExtractorIdentityReference], [HarvesterIdentity], [ObservedAtUtc], [ProvenanceFingerprint])
    SELECT [artifact].[SourceArtifactId], 1, [seed].[NormalizedContentSha256], [seed].[ByteSha256], [seed].[ByteCount], 'utf-8', [seed].[BomPresent], [seed].[LineEndingCode], [seed].[HasFinalNewline],
           N'rdb510-seed-catalog-extractor:v1', N'rdb510-reference-catalog', @Rdb510PublishedAtUtc,
           HASHBYTES('SHA2_256', CONVERT(varbinary(max), N'rdb510-source-version/' + [seed].[RepoPath] + N'/' + [seed].[NormalizedContentSha256]))
    FROM @Rdb510Sources AS [seed]
    INNER JOIN [ATAPUtilities].[SourceArtifact] AS [artifact]
      ON [artifact].[RepositoryId] = @Rdb510RepositoryId AND [artifact].[LocatorTypeCode] = 'RepositoryPath'
     AND [artifact].[RepoRelativePathOrExternalLocator] = [seed].[RepoPath]
    WHERE NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[SourceArtifactVersion] AS [existing]
                      WHERE [existing].[SourceArtifactId] = [artifact].[SourceArtifactId] AND [existing].[VersionSequence] = 1);
    IF (SELECT COUNT(*) FROM @Rdb510Sources) <> 18 OR
       (SELECT COUNT(*) FROM [ATAPUtilities].[SourceArtifact] WHERE [RepositoryId] = @Rdb510RepositoryId AND [LocatorTypeCode] = 'RepositoryPath') < 18
        THROW 55555, 'RDB-510 source-artifact prerequisite count failed.', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

/* BEGIN MECHANICALLY INTEGRATED RDB-500A-F FRAGMENTS */
'@
            $body = [Text.StringBuilder]::new()
            [void]$body.Append($header)
            foreach ($fragment in $directFragments) {
                [void]$body.Append("`r`n/* BEGIN INTEGRATED FRAGMENT: $fragment */`r`n")
                [void]$body.Append((Get-Content -LiteralPath (Join-Path $fragmentRoot $fragment) -Raw))
                [void]$body.Append("`r`n/* END INTEGRATED FRAGMENT: $fragment */`r`n")
            }
            if ($declarativeFragments.Count -gt 0) {
                [void]$body.Append("`r`n/* BEGIN RDB-510 DECLARATIVE CATALOG MATERIALIZATION */`r`n")
                foreach ($fragment in $declarativeFragments) {
                    [void]$body.Append((Get-Content -LiteralPath (Join-Path $fragmentRoot $fragment) -Raw))
                    [void]$body.Append("`r`n")
                }
                [void]$body.Append(@'
/* RDB-510 materializes, rather than merely stages, the H/I catalog rows. */
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF (SELECT COUNT(*) FROM #Rdb510SeedCatalog WHERE TaskId = 'RDB-500H') <> 33
       OR (SELECT COUNT(*) FROM #Rdb510SeedCatalog WHERE TaskId = 'RDB-500I') <> 9
       OR EXISTS (SELECT 1 FROM #Rdb510SeedCatalog GROUP BY PhiloteId HAVING COUNT(*) > 1)
        THROW 55560, 'RDB-510 declarative H/I catalog count or GUID uniqueness failed.', 1;
    IF EXISTS (SELECT 1 FROM #Rdb510SeedCatalog WHERE TaskId = 'RDB-500G')
        THROW 55561, 'RDB-500G ContentSummary is allocation-blocked and must remain zero-row.', 1;

    DECLARE @Rdb510ValueTypeTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode = 'value-type');
    DECLARE @Rdb510ValueTypeVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode = 'value-type-version');
    DECLARE @Rdb510RuleKindTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode = 'rule-kind');
    DECLARE @Rdb510RuleKindVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode = 'rule-kind-version');
    DECLARE @Rdb510PrimitiveTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode = 'primitive');
    DECLARE @Rdb510PrimitiveVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode = 'primitive-version');
    DECLARE @Rdb510PrimitiveInputTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode = 'primitive-input-definition');
    DECLARE @Rdb510RuleTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode = 'rule');
    DECLARE @Rdb510RuleVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode = 'rule-version');
    DECLARE @Rdb510RuleInputTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode = 'rule-input-definition');
    DECLARE @Rdb510RuleDefaultTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode = 'rule-default-input-value');
    DECLARE @Rdb510Utf8TextPhilote uniqueidentifier = '0198e3d9-487d-5f07-95a2-664984bcba27';
    DECLARE @Rdb510Utf8TextVersionPhilote uniqueidentifier = '6e1f6145-6a9c-5e7e-8ceb-1d6195a4699b';
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] WHERE EntityPhiloteId = @Rdb510Utf8TextPhilote)
        INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc]) VALUES (@Rdb510ValueTypeTypeId, @Rdb510Utf8TextPhilote, @Rdb510PublishedAtUtc);
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode = 'utf8-text')
        INSERT [ATAPUtilities].[ValueType] ([ValueTypePhiloteId], [EntityId], [EntityTypeId], [ValueTypeCode], [CreatedAtUtc])
        SELECT @Rdb510Utf8TextPhilote, EntityId, @Rdb510ValueTypeTypeId, 'utf8-text', @Rdb510PublishedAtUtc FROM [ATAPUtilities].[Entity] WHERE EntityPhiloteId = @Rdb510Utf8TextPhilote AND EntityTypeId = @Rdb510ValueTypeTypeId;
    DECLARE @Rdb510Utf8TextId bigint = (SELECT ValueTypeId FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode = 'utf8-text');
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] WHERE EntityPhiloteId = @Rdb510Utf8TextVersionPhilote)
        INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc]) VALUES (@Rdb510ValueTypeVersionTypeId, @Rdb510Utf8TextVersionPhilote, @Rdb510PublishedAtUtc);
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId = @Rdb510Utf8TextId AND RevisionSequence = 1)
        INSERT [ATAPUtilities].[ValueTypeVersion] ([ValueTypeVersionPhiloteId], [EntityId], [EntityTypeId], [ValueTypeId], [RevisionSequence], [PredecessorValueTypeVersionId], [ValueCategoryCode], [ScalarStorageKindCode], [StructuredValueContractVersionId], [ElementValueTypeVersionId], [CollectionOrderingCode], [SecretReferencePolicyId], [ValidationContractCode], [PublishedAtUtc])
        SELECT @Rdb510Utf8TextVersionPhilote, EntityId, @Rdb510ValueTypeVersionTypeId, @Rdb510Utf8TextId, 1, NULL, 'scalar', 'bounded-unicode-text', NULL, NULL, NULL, NULL, 'non-empty-text', @Rdb510PublishedAtUtc FROM [ATAPUtilities].[Entity] WHERE EntityPhiloteId = @Rdb510Utf8TextVersionPhilote AND EntityTypeId = @Rdb510ValueTypeVersionTypeId;
    DECLARE @Rdb510Utf8TextVersionId bigint = (SELECT ValueTypeVersionId FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId = @Rdb510Utf8TextId AND RevisionSequence = 1);

    INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
    SELECT @Rdb510RuleKindTypeId, PhiloteId, @Rdb510PublishedAtUtc FROM #Rdb510SeedCatalog AS seed
    WHERE RecordType = 'RuleKind' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] AS entity WHERE entity.EntityPhiloteId = seed.PhiloteId);
    INSERT [ATAPUtilities].[RuleKind] ([RuleKindPhiloteId], [EntityId], [EntityTypeId], [RuleKindCode], [CreatedAtUtc])
    SELECT seed.PhiloteId, entity.EntityId, @Rdb510RuleKindTypeId, seed.KindCode, @Rdb510PublishedAtUtc FROM #Rdb510SeedCatalog AS seed
    JOIN [ATAPUtilities].[Entity] AS entity ON entity.EntityPhiloteId = seed.PhiloteId AND entity.EntityTypeId = @Rdb510RuleKindTypeId
    WHERE seed.RecordType = 'RuleKind' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKind] AS existing WHERE existing.RuleKindCode = seed.KindCode);

    INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
    SELECT @Rdb510RuleKindVersionTypeId, PhiloteId, @Rdb510PublishedAtUtc FROM #Rdb510SeedCatalog AS seed
    WHERE RecordType = 'RuleKindVersion' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] AS entity WHERE entity.EntityPhiloteId = seed.PhiloteId);
    INSERT [ATAPUtilities].[RuleKindVersion] ([RuleKindVersionPhiloteId], [EntityId], [EntityTypeId], [RuleKindId], [RevisionSequence], [PredecessorRuleKindVersionId], [GrammarSourceArtifactVersionId], [GrammarHashAlgorithmCode], [GrammarContentHash], [CompendiumSourceArtifactVersionId], [CompendiumHashAlgorithmCode], [CompendiumContentHash], [ExecutorContractVersionId], [ExecutionClassificationCode], [SecurityCapabilityCode], [RoundTripPolicyCode], [PublishedAtUtc])
    SELECT seed.PhiloteId, entity.EntityId, @Rdb510RuleKindVersionTypeId, kind.RuleKindId, seed.RevisionSequence, NULL,
           grammarVersion.SourceArtifactVersionId, 'SHA-256', CONVERT(varbinary(64), '0x' + JSON_VALUE(seed.PayloadJson, '$.grammarSha256'), 1),
           compendiumVersion.SourceArtifactVersionId, 'SHA-256', CONVERT(varbinary(64), '0x' + JSON_VALUE(seed.PayloadJson, '$.compendiumSha256'), 1), NULL,
           JSON_VALUE(seed.PayloadJson, '$.executionClassification'), JSON_VALUE(seed.PayloadJson, '$.securityCapability'), JSON_VALUE(seed.PayloadJson, '$.roundTripPolicy'), @Rdb510PublishedAtUtc
    FROM #Rdb510SeedCatalog AS seed
    JOIN [ATAPUtilities].[Entity] AS entity ON entity.EntityPhiloteId = seed.PhiloteId AND entity.EntityTypeId = @Rdb510RuleKindVersionTypeId
    JOIN [ATAPUtilities].[RuleKind] AS kind ON kind.RuleKindCode = seed.KindCode
    JOIN [ATAPUtilities].[SourceArtifact] AS grammarArtifact ON grammarArtifact.RepositoryId = @Rdb510RepositoryId AND grammarArtifact.RepoRelativePathOrExternalLocator = seed.SourceReference
    JOIN [ATAPUtilities].[SourceArtifactVersion] AS grammarVersion ON grammarVersion.SourceArtifactId = grammarArtifact.SourceArtifactId AND grammarVersion.NormalizedContentSha256 = JSON_VALUE(seed.PayloadJson, '$.grammarSha256')
    JOIN [ATAPUtilities].[SourceArtifact] AS compendiumArtifact ON compendiumArtifact.RepositoryId = @Rdb510RepositoryId AND compendiumArtifact.RepoRelativePathOrExternalLocator = REPLACE(REPLACE(seed.SourceReference, 'grammers/', 'Rules Compendium.'), '.grammar.ebnf', '.md')
    JOIN [ATAPUtilities].[SourceArtifactVersion] AS compendiumVersion ON compendiumVersion.SourceArtifactId = compendiumArtifact.SourceArtifactId AND compendiumVersion.NormalizedContentSha256 = JSON_VALUE(seed.PayloadJson, '$.compendiumSha256')
    WHERE seed.RecordType = 'RuleKindVersion' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKindVersion] AS existing WHERE existing.RuleKindId = kind.RuleKindId AND existing.RevisionSequence = seed.RevisionSequence);
    IF EXISTS (SELECT 1 FROM #Rdb510SeedCatalog AS seed WHERE seed.RecordType = 'RuleKindVersion' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKindVersion] AS version JOIN [ATAPUtilities].[RuleKind] AS kind ON kind.RuleKindId = version.RuleKindId WHERE kind.RuleKindCode = seed.KindCode AND version.RevisionSequence = seed.RevisionSequence AND version.RuleKindVersionPhiloteId = seed.PhiloteId))
        THROW 55562, 'RDB-510 H/I RuleKindVersion materialization failed closed.', 1;

    INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
    SELECT @Rdb510PrimitiveTypeId, PhiloteId, @Rdb510PublishedAtUtc FROM #Rdb510SeedCatalog AS seed WHERE seed.RecordType = 'primitive' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] AS entity WHERE entity.EntityPhiloteId = seed.PhiloteId);
    INSERT [ATAPUtilities].[Primitive] ([PrimitivePhiloteId], [EntityId], [EntityTypeId], [RuleKindId], [PrimitiveCode], [CreatedAtUtc])
    SELECT seed.PhiloteId, entity.EntityId, @Rdb510PrimitiveTypeId, kind.RuleKindId, PARSENAME(REPLACE(seed.NaturalKey, '|', '.'), 2), @Rdb510PublishedAtUtc
    FROM #Rdb510SeedCatalog AS seed JOIN [ATAPUtilities].[Entity] AS entity ON entity.EntityPhiloteId = seed.PhiloteId AND entity.EntityTypeId = @Rdb510PrimitiveTypeId JOIN [ATAPUtilities].[RuleKind] AS kind ON kind.RuleKindCode = seed.KindCode
    WHERE seed.RecordType = 'primitive' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] AS existing WHERE existing.RuleKindId = kind.RuleKindId AND existing.PrimitiveCode = PARSENAME(REPLACE(seed.NaturalKey, '|', '.'), 2));
    INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
    SELECT @Rdb510PrimitiveVersionTypeId, PhiloteId, @Rdb510PublishedAtUtc FROM #Rdb510SeedCatalog AS seed WHERE seed.RecordType = 'primitive-version' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] AS entity WHERE entity.EntityPhiloteId = seed.PhiloteId);
    INSERT [ATAPUtilities].[PrimitiveVersion] ([PrimitiveVersionPhiloteId], [EntityId], [EntityTypeId], [PrimitiveId], [RuleKindId], [RuleKindVersionId], [RevisionSequence], [PredecessorPrimitiveVersionId], [GrammarProductionCode], [DefinitionText], [DefinitionHashAlgorithmCode], [DefinitionContentHash], [OutputValueTypeVersionId], [OutputMinCardinality], [OutputMaxCardinality], [PublishedAtUtc])
    SELECT seed.PhiloteId, entity.EntityId, @Rdb510PrimitiveVersionTypeId, primitive.PrimitiveId, kind.RuleKindId, kindVersion.RuleKindVersionId, seed.RevisionSequence, NULL, JSON_VALUE(seed.PayloadJson, '$.grammarProduction'), N'RDB-510 reference grammar production: ' + JSON_VALUE(seed.PayloadJson, '$.grammarProduction'), 'SHA-256', HASHBYTES('SHA2_256', N'RDB-510 reference grammar production: ' + JSON_VALUE(seed.PayloadJson, '$.grammarProduction')), @Rdb510Utf8TextVersionId, 1, 1, @Rdb510PublishedAtUtc
    FROM #Rdb510SeedCatalog AS seed JOIN [ATAPUtilities].[Entity] AS entity ON entity.EntityPhiloteId = seed.PhiloteId AND entity.EntityTypeId = @Rdb510PrimitiveVersionTypeId JOIN [ATAPUtilities].[RuleKind] AS kind ON kind.RuleKindCode = seed.KindCode JOIN [ATAPUtilities].[RuleKindVersion] AS kindVersion ON kindVersion.RuleKindId = kind.RuleKindId AND kindVersion.RevisionSequence = 1 JOIN [ATAPUtilities].[Primitive] AS primitive ON primitive.RuleKindId = kind.RuleKindId AND primitive.PrimitiveCode = PARSENAME(REPLACE(seed.NaturalKey, '|', '.'), 2)
    WHERE seed.RecordType = 'primitive-version' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] AS existing WHERE existing.PrimitiveId = primitive.PrimitiveId AND existing.RevisionSequence = seed.RevisionSequence);

    INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
    SELECT @Rdb510PrimitiveInputTypeId, PhiloteId, @Rdb510PublishedAtUtc FROM #Rdb510SeedCatalog AS seed WHERE seed.RecordType = 'PrimitiveInputDefinition' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] AS entity WHERE entity.EntityPhiloteId = seed.PhiloteId);
    INSERT [ATAPUtilities].[PrimitiveInputDefinition] ([PrimitiveInputDefinitionPhiloteId], [EntityId], [EntityTypeId], [PrimitiveVersionId], [InputCode], [Ordinal], [ValueTypeVersionId], [MinCardinality], [MaxCardinality], [AllowsNullElement], [ValidationContractCode])
    SELECT seed.PhiloteId, entity.EntityId, @Rdb510PrimitiveInputTypeId, primitiveVersion.PrimitiveVersionId, PARSENAME(REPLACE(seed.NaturalKey, '|', '.'), 1), TRY_CONVERT(int, JSON_VALUE(seed.PayloadJson, '$.ordinal')), @Rdb510Utf8TextVersionId, 1, 1, 0, 'non-empty-text'
    FROM #Rdb510SeedCatalog AS seed JOIN [ATAPUtilities].[Entity] AS entity ON entity.EntityPhiloteId = seed.PhiloteId AND entity.EntityTypeId = @Rdb510PrimitiveInputTypeId JOIN [ATAPUtilities].[RuleKind] AS kind ON kind.RuleKindCode = seed.KindCode JOIN [ATAPUtilities].[Primitive] AS primitive ON primitive.RuleKindId = kind.RuleKindId AND primitive.PrimitiveCode = PARSENAME(REPLACE(seed.NaturalKey, '|', '.'), 2) JOIN [ATAPUtilities].[PrimitiveVersion] AS primitiveVersion ON primitiveVersion.PrimitiveId = primitive.PrimitiveId AND primitiveVersion.RevisionSequence = 1
    WHERE seed.RecordType = 'PrimitiveInputDefinition' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] AS existing WHERE existing.PrimitiveVersionId = primitiveVersion.PrimitiveVersionId AND existing.InputCode = PARSENAME(REPLACE(seed.NaturalKey, '|', '.'), 1));

    INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
    SELECT @Rdb510RuleTypeId, PhiloteId, @Rdb510PublishedAtUtc FROM #Rdb510SeedCatalog AS seed WHERE seed.RecordType = 'Rule' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] AS entity WHERE entity.EntityPhiloteId = seed.PhiloteId);
    INSERT [ATAPUtilities].[Rule] ([RulePhiloteId], [EntityId], [EntityTypeId], [RuleKindId], [RuleCode], [CreatedAtUtc])
    SELECT seed.PhiloteId, entity.EntityId, @Rdb510RuleTypeId, kind.RuleKindId, PARSENAME(REPLACE(seed.NaturalKey, '|', '.'), 1), @Rdb510PublishedAtUtc FROM #Rdb510SeedCatalog AS seed JOIN [ATAPUtilities].[Entity] AS entity ON entity.EntityPhiloteId = seed.PhiloteId AND entity.EntityTypeId = @Rdb510RuleTypeId JOIN [ATAPUtilities].[RuleKind] AS kind ON kind.RuleKindCode = seed.KindCode WHERE seed.RecordType = 'Rule' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] AS existing WHERE existing.RuleKindId = kind.RuleKindId AND existing.RuleCode = PARSENAME(REPLACE(seed.NaturalKey, '|', '.'), 1));
    INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
    SELECT @Rdb510RuleVersionTypeId, PhiloteId, @Rdb510PublishedAtUtc FROM #Rdb510SeedCatalog AS seed WHERE seed.RecordType = 'RuleVersion' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] AS entity WHERE entity.EntityPhiloteId = seed.PhiloteId);
    INSERT [ATAPUtilities].[RuleVersion] ([RuleVersionPhiloteId], [EntityId], [EntityTypeId], [RuleId], [RuleKindId], [RuleKindVersionId], [RevisionSequence], [PredecessorRuleVersionId], [CompositionHashAlgorithmCode], [CompositionContentHash], [PublishedAtUtc])
    SELECT seed.PhiloteId, entity.EntityId, @Rdb510RuleVersionTypeId, rule.RuleId, kind.RuleKindId, kindVersion.RuleKindVersionId, seed.RevisionSequence, NULL, 'SHA-256', HASHBYTES('SHA2_256', CONVERT(varbinary(max), seed.NaturalKey)), @Rdb510PublishedAtUtc FROM #Rdb510SeedCatalog AS seed JOIN [ATAPUtilities].[Entity] AS entity ON entity.EntityPhiloteId = seed.PhiloteId AND entity.EntityTypeId = @Rdb510RuleVersionTypeId JOIN [ATAPUtilities].[RuleKind] AS kind ON kind.RuleKindCode = seed.KindCode JOIN [ATAPUtilities].[RuleKindVersion] AS kindVersion ON kindVersion.RuleKindId = kind.RuleKindId AND kindVersion.RevisionSequence = 1 JOIN [ATAPUtilities].[Rule] AS rule ON rule.RuleKindId = kind.RuleKindId AND rule.RuleCode = PARSENAME(REPLACE(seed.NaturalKey, '|', '.'), 2) WHERE seed.RecordType = 'RuleVersion' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersion] AS existing WHERE existing.RuleId = rule.RuleId AND existing.RevisionSequence = seed.RevisionSequence);
    INSERT [ATAPUtilities].[RuleVersionNode] ([RuleVersionNodePhiloteId], [RuleVersionId], [RuleKindVersionId], [ParentRuleVersionNodeId], [Ordinal], [PrimitiveVersionId], [MinOccurs], [MaxOccurs], [ChoiceDiscriminatorCode], [NodeLabel])
    SELECT CONVERT(uniqueidentifier, SUBSTRING(HASHBYTES('SHA2_256', N'rrsbs-v2/rule-node/' + CONVERT(nvarchar(36), ruleVersion.RuleVersionPhiloteId)), 1, 16)), ruleVersion.RuleVersionId, kindVersion.RuleKindVersionId, NULL, 0, primitiveVersion.PrimitiveVersionId, 1, 1, NULL, N'RDB-510 reference root'
    FROM #Rdb510SeedCatalog AS seed JOIN [ATAPUtilities].[RuleKind] AS kind ON kind.RuleKindCode = seed.KindCode JOIN [ATAPUtilities].[RuleKindVersion] AS kindVersion ON kindVersion.RuleKindId = kind.RuleKindId AND kindVersion.RevisionSequence = 1 JOIN [ATAPUtilities].[Rule] AS rule ON rule.RuleKindId = kind.RuleKindId AND rule.RuleCode = PARSENAME(REPLACE(seed.NaturalKey, '|', '.'), 2) JOIN [ATAPUtilities].[RuleVersion] AS ruleVersion ON ruleVersion.RuleId = rule.RuleId AND ruleVersion.RevisionSequence = seed.RevisionSequence JOIN [ATAPUtilities].[Primitive] AS primitive ON primitive.RuleKindId = kind.RuleKindId AND primitive.PrimitiveCode = PARSENAME(REPLACE(JSON_VALUE(seed.PayloadJson, '$.rootPrimitiveNaturalKey'), '|', '.'), 2) JOIN [ATAPUtilities].[PrimitiveVersion] AS primitiveVersion ON primitiveVersion.PrimitiveId = primitive.PrimitiveId AND primitiveVersion.RevisionSequence = 1 WHERE seed.RecordType = 'RuleVersion' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNode] AS node WHERE node.RuleVersionId = ruleVersion.RuleVersionId AND node.ParentRuleVersionNodeId IS NULL);

    INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
    SELECT @Rdb510RuleInputTypeId, PhiloteId, @Rdb510PublishedAtUtc FROM #Rdb510SeedCatalog AS seed WHERE seed.RecordType = 'RuleInputDefinition' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] AS entity WHERE entity.EntityPhiloteId = seed.PhiloteId);
    INSERT [ATAPUtilities].[RuleInputDefinition] ([RuleInputDefinitionPhiloteId], [EntityId], [EntityTypeId], [RuleVersionId], [InputCode], [Ordinal], [ValueTypeVersionId], [MinCardinality], [MaxCardinality], [AllowsNullElement], [ValidationContractCode])
    SELECT seed.PhiloteId, entity.EntityId, @Rdb510RuleInputTypeId, ruleVersion.RuleVersionId, PARSENAME(REPLACE(seed.NaturalKey, '|', '.'), 1), TRY_CONVERT(int, JSON_VALUE(seed.PayloadJson, '$.ordinal')), @Rdb510Utf8TextVersionId, 1, 1, 0, 'non-empty-text' FROM #Rdb510SeedCatalog AS seed JOIN [ATAPUtilities].[Entity] AS entity ON entity.EntityPhiloteId = seed.PhiloteId AND entity.EntityTypeId = @Rdb510RuleInputTypeId JOIN [ATAPUtilities].[RuleKind] AS kind ON kind.RuleKindCode = seed.KindCode JOIN [ATAPUtilities].[Rule] AS rule ON rule.RuleKindId = kind.RuleKindId AND rule.RuleCode = PARSENAME(REPLACE(seed.NaturalKey, '|', '.'), 2) JOIN [ATAPUtilities].[RuleVersion] AS ruleVersion ON ruleVersion.RuleId = rule.RuleId AND ruleVersion.RevisionSequence = 1 WHERE seed.RecordType = 'RuleInputDefinition' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleInputDefinition] AS existing WHERE existing.RuleVersionId = ruleVersion.RuleVersionId AND existing.InputCode = PARSENAME(REPLACE(seed.NaturalKey, '|', '.'), 1));
    INSERT [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
    SELECT @Rdb510RuleDefaultTypeId, PhiloteId, @Rdb510PublishedAtUtc FROM #Rdb510SeedCatalog AS seed WHERE seed.RecordType = 'RuleDefaultInputValue' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] AS entity WHERE entity.EntityPhiloteId = seed.PhiloteId);
    INSERT [ATAPUtilities].[RuleDefaultInputValue] ([RuleDefaultInputValuePhiloteId], [EntityId], [EntityTypeId], [RuleInputDefinitionId], [RuleVersionId], [ValueTypeVersionId], [CanonicalTextValue], [CanonicalValueHash], [RationaleEntityId], [RationaleEntityTypeId], [PublishedAtUtc])
    SELECT seed.PhiloteId, entity.EntityId, @Rdb510RuleDefaultTypeId, inputDefinition.RuleInputDefinitionId, ruleVersion.RuleVersionId, @Rdb510Utf8TextVersionId, JSON_VALUE(seed.PayloadJson, '$.canonicalText'), HASHBYTES('SHA2_256', CONVERT(varbinary(max), JSON_VALUE(seed.PayloadJson, '$.canonicalText'))), ruleVersion.EntityId, @Rdb510RuleVersionTypeId, @Rdb510PublishedAtUtc FROM #Rdb510SeedCatalog AS seed JOIN [ATAPUtilities].[Entity] AS entity ON entity.EntityPhiloteId = seed.PhiloteId AND entity.EntityTypeId = @Rdb510RuleDefaultTypeId JOIN [ATAPUtilities].[RuleKind] AS kind ON kind.RuleKindCode = seed.KindCode JOIN [ATAPUtilities].[Rule] AS rule ON rule.RuleKindId = kind.RuleKindId AND rule.RuleCode = PARSENAME(REPLACE(seed.NaturalKey, '|', '.'), 2) JOIN [ATAPUtilities].[RuleVersion] AS ruleVersion ON ruleVersion.RuleId = rule.RuleId AND ruleVersion.RevisionSequence = 1 JOIN [ATAPUtilities].[RuleInputDefinition] AS inputDefinition ON inputDefinition.RuleVersionId = ruleVersion.RuleVersionId AND inputDefinition.InputCode = PARSENAME(REPLACE(seed.NaturalKey, '|', '.'), 1) WHERE seed.RecordType = 'RuleDefaultInputValue' AND NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleDefaultInputValue] AS existing WHERE existing.RuleInputDefinitionId = inputDefinition.RuleInputDefinitionId);

    IF (SELECT COUNT(*) FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode IN ('Markdown', 'ManimScene')) <> 2
       OR (SELECT COUNT(*) FROM [ATAPUtilities].[RuleVersion] AS rv JOIN [ATAPUtilities].[Rule] AS r ON r.RuleId = rv.RuleId JOIN [ATAPUtilities].[RuleKind] AS rk ON rk.RuleKindId = r.RuleKindId WHERE rk.RuleKindCode IN ('Markdown', 'ManimScene') AND rv.RevisionSequence = 1) <> 2
       OR EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummary])
        THROW 55563, 'RDB-510 H/I materialization postcondition failed.', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
/* END RDB-510 DECLARATIVE CATALOG MATERIALIZATION */
'@)
            }
            foreach ($fragment in $tailFragments) {
                [void]$body.Append("`r`n/* BEGIN INTEGRATED FRAGMENT: $fragment */`r`n")
                [void]$body.Append((Get-Content -LiteralPath (Join-Path $fragmentRoot $fragment) -Raw))
                [void]$body.Append("`r`n/* END INTEGRATED FRAGMENT: $fragment */`r`n")
            }
            [void]$body.Append(@'
/* RDB-500G ContentSummary is allocation-blocked and must remain zero-row. */
/* RDB-510 final coordinator transaction and fail-closed assertions. */
BEGIN TRY
    BEGIN TRANSACTION;
IF EXISTS (SELECT 1 FROM [ATAPUtilities].[ContentSummary])
    THROW 55570, 'RDB-510 must not seed ContentSummary rows.', 1;
IF EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE [RuleKindCode] IN ('BillOfMaterials', 'PKIArtifact', 'LegalEntityFiling', 'FinancialLedger', 'GPX'))
    THROW 55571, 'RDB-510 seeded a policy-gated or unapproved RuleKind.', 1;
IF (SELECT COUNT(*) FROM [ATAPUtilities].[EntityType]) <> 43
    THROW 55572, 'RDB-510 EntityType count drifted from frozen RDB-270 closure.', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
'@)
            $outputDirectory = Split-Path -Parent $OutputPath
            if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
                throw "Output directory does not exist: $outputDirectory"
            }
            [IO.File]::WriteAllText($OutputPath, $body.ToString(), [Text.UTF8Encoding]::new($false))
            return [pscustomobject]@{
                OutputPath = $OutputPath
                SourceArtifacts = $sources.Count
                DirectFragments = $directFragments.Count
                DeclarativeFragments = $declarativeFragments.Count
                TailFragments = $tailFragments.Count
                Sha256 = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        } catch {
            if (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $_.Exception.Message
            }
            throw
        }
    }

    end {
    }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
    New-Rdb510SeedMigration @args
}

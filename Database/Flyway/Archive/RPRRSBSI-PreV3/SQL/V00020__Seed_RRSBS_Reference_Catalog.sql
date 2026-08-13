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
    INSERT @Rdb510Sources ([RepoPath], [NormalizedContentSha256], [ByteSha256], [ByteCount], [BomPresent], [LineEndingCode], [HasFinalNewline]) VALUES        (N'SolutionDocumentation/grammers/AgentText.grammar.ebnf', '46605f3ca3e00f790a0de010c853f0f028b6a71e0436bdbe38eaf19869ff2183', '46605f3ca3e00f790a0de010c853f0f028b6a71e0436bdbe38eaf19869ff2183', 2489, 0, 'lf', 1),
        (N'SolutionDocumentation/grammers/CSharp.grammar.ebnf', 'df9a196a8dbfdaef3047cfa033e98ad783d8a2bb15e23a3bb6bd4b9b1ae40ddd', 'df9a196a8dbfdaef3047cfa033e98ad783d8a2bb15e23a3bb6bd4b9b1ae40ddd', 5417, 0, 'lf', 1),
        (N'SolutionDocumentation/grammers/ManimScene.grammar.ebnf', 'a014d68279e1c241773aecd0541ec0caf1e7796e48f1c77ed5659c6da0ca1b71', 'a014d68279e1c241773aecd0541ec0caf1e7796e48f1c77ed5659c6da0ca1b71', 5698, 0, 'lf', 1),
        (N'SolutionDocumentation/grammers/Markdown.grammar.ebnf', '111445bc94197d1acdd9924e46a9287f54e6f28df7d2104a6d1ea7f422a29d27', '111445bc94197d1acdd9924e46a9287f54e6f28df7d2104a6d1ea7f422a29d27', 2094, 0, 'lf', 1),
        (N'SolutionDocumentation/grammers/MSBuild.grammar.ebnf', 'c2ca634b02d8d36995adbd7910d3c4409602a8fdf59051edb509854f127fb907', 'c2ca634b02d8d36995adbd7910d3c4409602a8fdf59051edb509854f127fb907', 2928, 0, 'lf', 1),
        (N'SolutionDocumentation/grammers/OtterScript.grammar.ebnf', '0290a5895028efb2d40f9709f39639753b78d742d96876eaebd747f212f0fcee', '0290a5895028efb2d40f9709f39639753b78d742d96876eaebd747f212f0fcee', 3346, 0, 'lf', 1),
        (N'SolutionDocumentation/grammers/Path.grammar.ebnf', '277a0ceeace69edd2c806528dac212db9a69cfd9e74afe7d15ba13578b3f4bc6', '277a0ceeace69edd2c806528dac212db9a69cfd9e74afe7d15ba13578b3f4bc6', 1043, 0, 'lf', 1),
        (N'SolutionDocumentation/grammers/PowerShell.grammar.ebnf', '74406ace55f1b8c7328ee5a299bfe904d535163f87319e74dc6e72b3b1f2b102', '74406ace55f1b8c7328ee5a299bfe904d535163f87319e74dc6e72b3b1f2b102', 3989, 0, 'lf', 1),
        (N'SolutionDocumentation/grammers/SQL.grammar.ebnf', 'ea1fb29eb49e889cf3eff7920a50f8c9cc102dc327be0412106a13d61968f06f', 'ea1fb29eb49e889cf3eff7920a50f8c9cc102dc327be0412106a13d61968f06f', 6677, 0, 'lf', 1),
        (N'SolutionDocumentation/Rules Compendium.AgentText.md', '9db875d19db9192648cc0f096d2fc60236cb95858711da98f0a7769aef8b720d', '9db875d19db9192648cc0f096d2fc60236cb95858711da98f0a7769aef8b720d', 11436, 0, 'lf', 1),
        (N'SolutionDocumentation/Rules Compendium.CSharp.md', '779e400aea9dc2163e53c888000f66402a7bcd71ec555d4cb4d5fdf18d2ef5d9', '779e400aea9dc2163e53c888000f66402a7bcd71ec555d4cb4d5fdf18d2ef5d9', 62874, 0, 'lf', 1),
        (N'SolutionDocumentation/Rules Compendium.Manim.md', 'f3c223ff8f7d608774fa2420601857356ea691db0b7cb90e037cf561e2199643', 'f3c223ff8f7d608774fa2420601857356ea691db0b7cb90e037cf561e2199643', 5876, 0, 'lf', 1),
        (N'SolutionDocumentation/Rules Compendium.Markdown.md', 'fdde05d18e94d3b93a5fc83478a033a72e4856189030807a7a2bed82af4b75e7', 'fdde05d18e94d3b93a5fc83478a033a72e4856189030807a7a2bed82af4b75e7', 16735, 0, 'mixed', 1),
        (N'SolutionDocumentation/Rules Compendium.MSBuild.md', 'b89efd6626a54e8af8ce7d14390d2f639d963b1da718212ed8d22bdd43a8487e', 'b89efd6626a54e8af8ce7d14390d2f639d963b1da718212ed8d22bdd43a8487e', 11109, 0, 'lf', 1),
        (N'SolutionDocumentation/Rules Compendium.OtterScript.md', '4560874096cc1375971579735f85eafcc495bf5adbc51596e8baac47d7fb5f1b', '4560874096cc1375971579735f85eafcc495bf5adbc51596e8baac47d7fb5f1b', 6611, 0, 'lf', 1),
        (N'SolutionDocumentation/Rules Compendium.Path.md', '434ddbc5b3589c45f6c67dc8e890e66f777fddde78558dd45b9c1da5021bfeee', '434ddbc5b3589c45f6c67dc8e890e66f777fddde78558dd45b9c1da5021bfeee', 17155, 0, 'mixed', 1),
        (N'SolutionDocumentation/Rules Compendium.Powershell.md', 'b74a013c5a610431950151e74e17e51e0f5a4f945eb7cd17166134717f8d11ad', 'b74a013c5a610431950151e74e17e51e0f5a4f945eb7cd17166134717f8d11ad', 9984, 0, 'lf', 1),
        (N'SolutionDocumentation/Rules Compendium.SQL.md', '7feaf8e407e235f8b007168a07c35737ed9e03221d0a3dea275a6b2f16535d76', '7feaf8e407e235f8b007168a07c35737ed9e03221d0a3dea275a6b2f16535d76', 10493, 0, 'lf', 1);

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
/* BEGIN INTEGRATED FRAGMENT: RDB-500A__CSharp.sql */
/* Generated RRSBS Wave 6 seed fragment: RDB-500A.
   Owner boundary: RDB-500A only. Do not integrate by editing this file;
   RDB-510 is the sole final seed integrator. Deferred kinds: . */
/* RDB-500A / CSharp reference seed.
   Positive: A CSharp rule with a non-empty repository-relative source reference.
   Negative (declarative; exercised by RDB-510): A CSharp rule with an empty content input or a cross-kind primitive version.
   Integration prerequisites are coordinator-owned and fail closed below. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @RDB500ACSharpNow datetime2(7) = CONVERT(datetime2(7), '2026-08-06T00:00:00.0000000Z', 127);
DECLARE @RDB500ACSharpGrammarSourceArtifactVersionId bigint;
DECLARE @RDB500ACSharpCompendiumSourceArtifactVersionId bigint;
SELECT @RDB500ACSharpGrammarSourceArtifactVersionId = sav.SourceArtifactVersionId
FROM [ATAPUtilities].[SourceArtifact] sa
JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId = sa.SourceArtifactId
WHERE sa.LocatorTypeCode = 'RepositoryPath'
  AND sa.RepoRelativePathOrExternalLocator = N'SolutionDocumentation/grammers/CSharp.grammar.ebnf'
  AND sav.NormalizedContentSha256 = 'df9a196a8dbfdaef3047cfa033e98ad783d8a2bb15e23a3bb6bd4b9b1ae40ddd';
SELECT @RDB500ACSharpCompendiumSourceArtifactVersionId = sav.SourceArtifactVersionId
FROM [ATAPUtilities].[SourceArtifact] sa
JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId = sa.SourceArtifactId
WHERE sa.LocatorTypeCode = 'RepositoryPath'
  AND sa.RepoRelativePathOrExternalLocator = N'SolutionDocumentation/Rules Compendium.CSharp.md'
  AND sav.NormalizedContentSha256 = '779e400aea9dc2163e53c888000f66402a7bcd71ec555d4cb4d5fdf18d2ef5d9';
IF @RDB500ACSharpGrammarSourceArtifactVersionId IS NULL OR @RDB500ACSharpCompendiumSourceArtifactVersionId IS NULL
    THROW 55500, 'RDB-500A requires exact grammar and compendium SourceArtifactVersion rows.', 1;

DECLARE @RDB500ACSharpRuleKindTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind');
DECLARE @RDB500ACSharpRuleKindVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind-version');
DECLARE @RDB500ACSharpValueTypeTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type');
DECLARE @RDB500ACSharpValueTypeVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type-version');
DECLARE @RDB500ACSharpPrimitiveTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive');
DECLARE @RDB500ACSharpPrimitiveVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-version');
DECLARE @RDB500ACSharpPrimitiveInputTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-input-definition');
DECLARE @RDB500ACSharpRuleTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule');
DECLARE @RDB500ACSharpRuleVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-version');
DECLARE @RDB500ACSharpRuleInputTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-input-definition');
DECLARE @RDB500ACSharpRuleDefaultTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-default-input-value');
IF @RDB500ACSharpRuleKindTypeId IS NULL OR @RDB500ACSharpRuleDefaultTypeId IS NULL
    THROW 55501, 'RDB-500A requires the frozen RDB-320 EntityType catalog.', 1;
IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ExecutionClassification] WHERE ExecutionClassificationCode='metadata-only' AND AllowsExecutorContract=0)
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[SecurityCapabilityClassification] WHERE SecurityCapabilityCode='reference-safe')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RoundTripPolicy] WHERE RoundTripPolicyCode='byte-identical')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ScalarStorageKind] WHERE ScalarStorageKindCode='bounded-unicode-text')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[BindingShape] WHERE BindingShapeCode='constant')
    THROW 55502, 'RDB-500A requires coordinator-owned closed catalog rows.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @RDB500ACSharpEntityId bigint;
    DECLARE @RDB500ACSharpRuleKindId bigint;
    DECLARE @RDB500ACSharpRuleKindVersionId bigint;
    DECLARE @RDB500ACSharpValueTypeId bigint;
    DECLARE @RDB500ACSharpValueTypeVersionId bigint;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'CSharp')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500ACSharpRuleKindTypeId,'f05bda7e-31c9-5d60-af2a-d9a9dc2f5bbd',@RDB500ACSharpNow);
        SET @RDB500ACSharpEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleKind](RuleKindPhiloteId,EntityId,EntityTypeId,RuleKindCode,CreatedAtUtc)
        VALUES('f05bda7e-31c9-5d60-af2a-d9a9dc2f5bbd',@RDB500ACSharpEntityId,@RDB500ACSharpRuleKindTypeId,N'CSharp',@RDB500ACSharpNow);
    END;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'CSharp' AND RuleKindPhiloteId<>'f05bda7e-31c9-5d60-af2a-d9a9dc2f5bbd')
        THROW 55503, 'RDB-500A RuleKind natural key maps to a different Philote.', 1;
    SELECT @RDB500ACSharpRuleKindId=RuleKindId FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'CSharp';

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500ACSharpRuleKindId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500ACSharpRuleKindVersionTypeId,'ea0edee3-6da8-5c94-b237-5f51f675e8b3',@RDB500ACSharpNow);
        SET @RDB500ACSharpEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleKindVersion]
          (RuleKindVersionPhiloteId,EntityId,EntityTypeId,RuleKindId,RevisionSequence,PredecessorRuleKindVersionId,
           GrammarSourceArtifactVersionId,GrammarHashAlgorithmCode,GrammarContentHash,CompendiumSourceArtifactVersionId,
           CompendiumHashAlgorithmCode,CompendiumContentHash,ExecutorContractVersionId,ExecutionClassificationCode,
           SecurityCapabilityCode,RoundTripPolicyCode,PublishedAtUtc)
        VALUES('ea0edee3-6da8-5c94-b237-5f51f675e8b3',@RDB500ACSharpEntityId,@RDB500ACSharpRuleKindVersionTypeId,@RDB500ACSharpRuleKindId,1,NULL,
          @RDB500ACSharpGrammarSourceArtifactVersionId,'SHA-256',0xdf9a196a8dbfdaef3047cfa033e98ad783d8a2bb15e23a3bb6bd4b9b1ae40ddd,@RDB500ACSharpCompendiumSourceArtifactVersionId,
          'SHA-256',0x779e400aea9dc2163e53c888000f66402a7bcd71ec555d4cb4d5fdf18d2ef5d9,NULL,'metadata-only','reference-safe','byte-identical',@RDB500ACSharpNow);
    END;
    SELECT @RDB500ACSharpRuleKindVersionId=RuleKindVersionId FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500ACSharpRuleKindId AND RevisionSequence=1;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-csharp-text')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500ACSharpValueTypeTypeId,'7cebcb26-c34c-5189-b014-a30dd0403201',@RDB500ACSharpNow);
        SET @RDB500ACSharpEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[ValueType](ValueTypePhiloteId,EntityId,EntityTypeId,ValueTypeCode,CreatedAtUtc)
        VALUES('7cebcb26-c34c-5189-b014-a30dd0403201',@RDB500ACSharpEntityId,@RDB500ACSharpValueTypeTypeId,'seed-csharp-text',@RDB500ACSharpNow);
    END;
    SELECT @RDB500ACSharpValueTypeId=ValueTypeId FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-csharp-text';
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500ACSharpValueTypeId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500ACSharpValueTypeVersionTypeId,'cf6f8bd9-5a0a-533c-842f-d58e5acd198a',@RDB500ACSharpNow);
        SET @RDB500ACSharpEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[ValueTypeVersion]
          (ValueTypeVersionPhiloteId,EntityId,EntityTypeId,ValueTypeId,RevisionSequence,PredecessorValueTypeVersionId,
           ValueCategoryCode,ScalarStorageKindCode,StructuredValueContractVersionId,ElementValueTypeVersionId,
           CollectionOrderingCode,SecretReferencePolicyId,ValidationContractCode,PublishedAtUtc)
        VALUES('cf6f8bd9-5a0a-533c-842f-d58e5acd198a',@RDB500ACSharpEntityId,@RDB500ACSharpValueTypeVersionTypeId,@RDB500ACSharpValueTypeId,1,NULL,
          'scalar','bounded-unicode-text',NULL,NULL,NULL,NULL,'non-empty-text',@RDB500ACSharpNow);
    END;
    SELECT @RDB500ACSharpValueTypeVersionId=ValueTypeVersionId FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500ACSharpValueTypeId AND RevisionSequence=1;

    DECLARE @RDB500ACSharpPrimitives TABLE(PrimitivePhiloteId uniqueidentifier,PrimitiveVersionPhiloteId uniqueidentifier,
      InputPhiloteId uniqueidentifier,PrimitiveCode varchar(128),DefinitionText nvarchar(max));
    INSERT @RDB500ACSharpPrimitives VALUES
        ('4f6dbde9-52f2-4d3f-82a1-7b9f3a6c4d85', '0b94ddc7-6c68-589e-9084-44e5f0728dd2', 'fbc559c4-2931-5afd-94e1-4a5ec500b39a', N'<cs-source-file>', N'Top-level container for a .cs file'),
        ('8b9e0f19-5272-4c1f-90db-e1e6b0c5d3f2', '25369419-29eb-5bdf-ad2d-9521a32e09e6', '029e7b0c-d5bd-5f4a-9086-a670418205e0', N'<using-directive>', N'Imports a namespace, static members, or creates an alias'),
        ('d3f0f6b9-1eae-4a8d-9a6f-5d8f2410c8a4', 'e3fdd494-57aa-50f2-a11f-85f1e4ec3c1b', '007ae925-9590-56a7-bcd3-259ab2dad43b', N'<namespace-block-declaration>', N'Declares a namespace using block syntax'),
        ('2f4a8073-b7c8-432e-aac7-65f6063a1e2a', '295c0b47-f3f6-5a34-9723-8916c5dce9b3', 'e67fcf75-96cc-5244-a2f9-0b7679d2e160', N'<single-line-comment>', N'Single-line C# comment (//)'),
        ('0fbb4f0d-917d-4b60-8db1-9d9e3de5712f', 'cfdea570-be6a-5040-9257-50d5f3542e94', 'd01a8e6e-c7af-5ad0-a808-2419b9c4c874', N'<access-modifier>', N'Visibility modifier (public, protected, internal, private)'),
        ('a4efb6e5-58f0-4603-94ae-45b62c323d0b', '4a5adda0-83be-5fa3-aae0-84b8b3815148', '09b54e05-ccb9-52e4-aad4-0b1297f8507c', N'<type-parameter-list>', N'Generic type parameter list <T1, T2, ...>'),
        ('8ad77df8-8366-40f8-99b5-ff2a2a8d5da9', '3c31afde-1d86-5d64-a799-253749e30691', '404d01ee-6a23-569b-9477-880a147234af', N'<type-constraint-clause>', N'Generic where constraint clause'),
        ('3e8eac46-1e1a-4b80-a5f1-406cc6f5d0f1', '0fb0bd67-b7ad-5d09-8ca6-f35714a1989c', 'ef3926c7-f6ce-5453-94c6-e2035829fd1b', N'<base-type-list>', N'Base class and interface inheritance list'),
        ('b7f87746-72af-4632-9dd9-05f833b3a8e8', 'b680f847-d9ca-5755-86f8-2737bb0503bd', 'fca18975-c98b-5990-996c-417591aa5b43', N'<type-reference>', N'Reference to a named type'),
        ('6a972b5b-5da7-4a73-b5d6-564e1b305a0b', 'a394a924-21cc-5936-b120-87a6f5f92e20', '0a3f8035-eebd-5818-a876-bc15e0a46d5e', N'<interface-declaration>', N'Declares a C# interface'),
        ('6d2e4c24-4f59-487f-9e6d-2e65f97a6dd0', 'ede9e095-2ece-5bf6-b609-97daffb7bfcf', '7fd52988-3c0b-50af-9ab6-0e0e5c6bf142', N'<property-declaration>', N'Auto or full property declaration'),
        ('2c75c902-3a6c-4c28-8f0f-1b8d6f45fefa', '9a926d53-d0aa-578a-8c15-886f87514eaa', '6a00e48e-2ef1-59a7-b3ad-158c44a4c2f3', N'<attribute-list>', N'Attribute annotation [...] list'),
        ('5c1f93b8-6db5-4aaf-94ef-7b3d8b8a9d3a', '581624fe-6f15-505c-b1c9-d99105c92d1f', 'af240ba5-d58c-5402-91da-2449c3644a46', N'<class-declaration>', N'Declares a C# class'),
        ('1b5b9a87-9b4b-4d64-8720-3d7d8f3a6f5e', '4db95812-1c5e-53f5-a954-2f060a50c7c1', '3775ab76-2593-5391-b71d-ff51384437ef', N'<record-declaration>', N'Declares a C# record or record struct'),
        ('c81c5942-0918-42b4-bc4c-1b1c9e7192cb', '4aa1df31-2f2f-57f7-9940-8ead23e2da42', '992edebd-ef50-52da-83b2-5b6a49ff82ff', N'<field-declaration>', N'Declares a field inside a class or struct'),
        ('0e7a4a44-71d4-46cd-8bf1-ff7e1aa02a8d', '7e9743fe-80e3-5b91-9f86-852a03f1cab2', '02ec73c7-bdc9-5303-9ac1-c382f28d211b', N'<parameter-list>', N'Method or constructor parameter list'),
        ('a8234b2e-17dc-4b18-9d6d-2f8ed2f4123c', '57fe6e1f-160f-54ec-ac61-6238b3fdea71', 'a7142df7-ecd2-5c2b-8390-cc7e9ef1f694', N'<constructor-declaration>', N'Declares a constructor (block or expression body)'),
        ('cb1f3a32-bf40-4b35-97cf-36e5c8b08e31', 'ddf96492-9eec-5b27-9f36-2eb10b4009f7', 'ad40912a-b732-5c8c-8250-c39dd430d844', N'<method-declaration>', N'Declares a method (block or expression body)');
    DECLARE @RDB500ACSharpPrimitivePhiloteId uniqueidentifier,@RDB500ACSharpPrimitiveVersionPhiloteId uniqueidentifier,
      @RDB500ACSharpInputPhiloteId uniqueidentifier,@RDB500ACSharpPrimitiveCode varchar(128),@RDB500ACSharpDefinitionText nvarchar(max),
      @RDB500ACSharpPrimitiveId bigint,@RDB500ACSharpPrimitiveVersionId bigint;
    DECLARE RDB500ACSharpPrimitiveCursor CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @RDB500ACSharpPrimitives ORDER BY PrimitiveCode;
    OPEN RDB500ACSharpPrimitiveCursor;
    FETCH NEXT FROM RDB500ACSharpPrimitiveCursor INTO @RDB500ACSharpPrimitivePhiloteId,@RDB500ACSharpPrimitiveVersionPhiloteId,@RDB500ACSharpInputPhiloteId,@RDB500ACSharpPrimitiveCode,@RDB500ACSharpDefinitionText;
    WHILE @@FETCH_STATUS=0
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500ACSharpRuleKindId AND PrimitiveCode=@RDB500ACSharpPrimitiveCode)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500ACSharpPrimitiveTypeId,@RDB500ACSharpPrimitivePhiloteId,@RDB500ACSharpNow);
        SET @RDB500ACSharpEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500ACSharpPrimitivePhiloteId,@RDB500ACSharpEntityId,@RDB500ACSharpPrimitiveTypeId,@RDB500ACSharpRuleKindId,@RDB500ACSharpPrimitiveCode,@RDB500ACSharpNow);
      END;
      IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500ACSharpRuleKindId AND PrimitiveCode=@RDB500ACSharpPrimitiveCode AND PrimitivePhiloteId<>@RDB500ACSharpPrimitivePhiloteId)
        THROW 55504, 'RDB-500A Primitive natural key maps to a different Philote.', 1;
      SELECT @RDB500ACSharpPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500ACSharpRuleKindId AND PrimitiveCode=@RDB500ACSharpPrimitiveCode;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500ACSharpPrimitiveId AND RevisionSequence=1)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500ACSharpPrimitiveVersionTypeId,@RDB500ACSharpPrimitiveVersionPhiloteId,@RDB500ACSharpNow);
        SET @RDB500ACSharpEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,
           PredecessorPrimitiveVersionId,GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,
           DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500ACSharpPrimitiveVersionPhiloteId,@RDB500ACSharpEntityId,@RDB500ACSharpPrimitiveVersionTypeId,@RDB500ACSharpPrimitiveId,
          @RDB500ACSharpRuleKindId,@RDB500ACSharpRuleKindVersionId,1,NULL,@RDB500ACSharpPrimitiveCode,@RDB500ACSharpDefinitionText,'SHA-256',
          HASHBYTES('SHA2_256',@RDB500ACSharpDefinitionText),@RDB500ACSharpValueTypeVersionId,1,1,@RDB500ACSharpNow);
      END;
      SELECT @RDB500ACSharpPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500ACSharpPrimitiveId AND RevisionSequence=1;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500ACSharpPrimitiveVersionId AND InputCode='content')
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500ACSharpPrimitiveInputTypeId,@RDB500ACSharpInputPhiloteId,@RDB500ACSharpNow);
        SET @RDB500ACSharpEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,
           ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500ACSharpInputPhiloteId,@RDB500ACSharpEntityId,@RDB500ACSharpPrimitiveInputTypeId,@RDB500ACSharpPrimitiveVersionId,
          'content',0,@RDB500ACSharpValueTypeVersionId,1,1,0,'non-empty-text');
      END;
      FETCH NEXT FROM RDB500ACSharpPrimitiveCursor INTO @RDB500ACSharpPrimitivePhiloteId,@RDB500ACSharpPrimitiveVersionPhiloteId,@RDB500ACSharpInputPhiloteId,@RDB500ACSharpPrimitiveCode,@RDB500ACSharpDefinitionText;
    END;
    CLOSE RDB500ACSharpPrimitiveCursor; DEALLOCATE RDB500ACSharpPrimitiveCursor;

    DECLARE @RDB500ACSharpRootPrimitiveVersionId bigint,@RDB500ACSharpRootPrimitiveInputId bigint;
    SELECT @RDB500ACSharpRootPrimitiveVersionId=pv.PrimitiveVersionId,@RDB500ACSharpRootPrimitiveInputId=pid.PrimitiveInputDefinitionId
    FROM [ATAPUtilities].[Primitive] p JOIN [ATAPUtilities].[PrimitiveVersion] pv ON pv.PrimitiveId=p.PrimitiveId AND pv.RevisionSequence=1
    JOIN [ATAPUtilities].[PrimitiveInputDefinition] pid ON pid.PrimitiveVersionId=pv.PrimitiveVersionId AND pid.InputCode='content'
    WHERE p.RuleKindId=@RDB500ACSharpRuleKindId AND p.PrimitiveCode=N'<cs-source-file>';
    IF @RDB500ACSharpRootPrimitiveInputId IS NULL THROW 55505, 'RDB-500A top primitive/input was not materialized.', 1;

    DECLARE @RDB500ACSharpRules TABLE(RulePhiloteId uniqueidentifier,RuleVersionPhiloteId uniqueidentifier,
      RuleInputPhiloteId uniqueidentifier,DefaultPhiloteId uniqueidentifier,NodePhiloteId uniqueidentifier,
      RuleCode varchar(128),Purpose nvarchar(max),DefaultValue nvarchar(max),SourceFileReference nvarchar(2048));
    INSERT @RDB500ACSharpRules VALUES
        ('f1f9a5d5-5e5a-4a44-8c48-1544a6d1c5ee', 'b3cb359f-5ffd-5256-95cf-cbb7a7aa3695', 'efb3f51c-e7cc-562c-b716-dd36cf8e04bc', 'ffa8f343-ba5e-560e-9929-5d87cdd6543b', '7aaad85d-328f-548b-b35e-471ad2b2a89a', N'IStronglyTypedIds', N'Generate IAbstractStronglyTypedId<TValue>, IGuidStronglyTypedId, and IIntStronglyTypedId interfaces.', N'src/ATAP.Utilities.StronglyTypedIds.Interfaces/IStronglyTypedIds.cs', N'src/ATAP.Utilities.StronglyTypedIds.Interfaces/IStronglyTypedIds.cs'),
        ('a8e3b1d0-1c6f-4f6f-9c7b-3c5d72e1b944', '3bce2870-fe0b-5707-82c5-1aa54b61dcbc', 'ce3f8d79-e74c-5dfe-bbe5-5478ec3c09cb', 'd62dd5e1-f53e-51ff-8cef-a6f6bce0ee40', 'eae5f94d-1c4e-5c5e-afe3-1dca67ee0b3b', N'IPhilote', N'Generate the Philote identity interfaces (IGuidPhilote<TId>, IIntPhilote<TId>, and IAbstractPhilote<TId, TValue>).', N'src/ATAP.Utilities.Philote.Interfaces/IPhilote.cs', N'src/ATAP.Utilities.Philote.Interfaces/IPhilote.cs'),
        ('c4a4b59f-1f8e-4bdb-9c8d-7a23f3b3d6e2', 'e84bb7ee-bf8e-54f8-af72-5f28c97ff70d', '265fc1aa-41ca-5498-8180-14917348f9bc', 'ccb8b88a-5fde-522c-8236-04be76475e3e', '4b4621b5-469e-5c5f-b5b0-a67850d43525', N'StronglyTypedIds', N'Generate records GuidStronglyTypedId, IntStronglyTypedId, AbstractStronglyTypedId<TValue>, converters, and helper utilities.', N'src/ATAP.Utilities.StronglyTypedIds/StronglyTypedIds.cs', N'src/ATAP.Utilities.StronglyTypedIds/StronglyTypedIds.cs'),
        ('5a2a7d5f-017d-4c89-98c5-7d4ab0f4ec3b', '54d77609-d2c8-5575-8245-ed74b1bd6619', '18d1f6bf-abee-58e4-bd0b-99605d83917a', 'fa7a2bee-7539-58d1-942b-4aba8dc77802', 'f074c4de-1435-57bd-8eed-494e5644bebf', N'PhiloteRecords', N'Generate AbstractPhilote<TId, TValue>, IntPhilote<TId>, and GuidPhilote<TId> record implementations.', N'src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/Philote.cs', N'src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/Philote.cs'),
        ('01d7c067-65b8-4370-bacf-2abf5ca7f7b8', '0d59466e-0aaf-5f01-babc-9500ba1be722', '4bfbf410-f14e-5763-8696-caaac35022d5', '982ec2f2-1177-58bf-9fb7-75b325ccf66d', 'cbdabf7b-83d0-5cb4-a15a-7ebd52a7fa9d', N'ActivatorReplacement', N'Generate InstanceFactory and InstanceFactoryGeneric<...> classes that cache expression-compiled constructors.', N'src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/ActivatorReplacement.cs', N'src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/ActivatorReplacement.cs'),
        ('6e7f54c4-0b7d-4f0a-8d57-5f1f96c4d7b8', 'd9454d5e-f479-56ad-9032-4ea7f4604596', '69c6e308-463b-586b-8ccf-437d7d93a9eb', 'a1e46423-9217-5915-89d7-b2bfb8262516', '39664945-ace2-5b58-8a27-bb33cb9ea6a8', N'StronglyTypedIdJsonConverterSystemTextJson', N'Render generic System.Text.Json converter and factory for StronglyTypedId records.', N'src/ATAP.Utilities.StronglyTypedId/JsonConverter.Shim.SystemTextJson/StronglyTypedIdJsonConverterSystemTextJson.cs', N'src/ATAP.Utilities.StronglyTypedId/JsonConverter.Shim.SystemTextJson/StronglyTypedIdJsonConverterSystemTextJson.cs'),
        ('7d1a3b4c-2f5e-4c9f-9a64-5c7d8e9f0a1b', '63985de3-1103-5fd6-9fbe-86eb1c53e74e', '6538204a-7451-5e57-85d5-b95a28ddbfdd', 'fbd36039-63af-501d-88ca-0d42221d0f76', '7d3853e4-6a0d-50cb-aaf2-97c144cf3bd6', N'PhiloteJsonConverterSystemTextJson', N'Capture current Philote JsonConverter factory scaffold for System.Text.Json.', N'src/ATAP.Utilities.Philote/JsonConverter.Shim.SystemTextJson/JsonConverter.Shim.SystemTextJson.cs', N'src/ATAP.Utilities.Philote/JsonConverter.Shim.SystemTextJson/JsonConverter.Shim.SystemTextJson.cs');
    DECLARE @RDB500ACSharpRulePhiloteId uniqueidentifier,@RDB500ACSharpRuleVersionPhiloteId uniqueidentifier,
      @RDB500ACSharpRuleInputPhiloteId uniqueidentifier,@RDB500ACSharpDefaultPhiloteId uniqueidentifier,@RDB500ACSharpNodePhiloteId uniqueidentifier,
      @RDB500ACSharpRuleCode varchar(128),@RDB500ACSharpPurpose nvarchar(max),@RDB500ACSharpDefaultValue nvarchar(max),@RDB500ACSharpSourceFileReference nvarchar(2048),
      @RDB500ACSharpRuleId bigint,@RDB500ACSharpRuleVersionId bigint,@RDB500ACSharpRuleInputId bigint,@RDB500ACSharpNodeId bigint;
    DECLARE RDB500ACSharpRuleCursor CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @RDB500ACSharpRules ORDER BY RuleCode;
    OPEN RDB500ACSharpRuleCursor;
    FETCH NEXT FROM RDB500ACSharpRuleCursor INTO @RDB500ACSharpRulePhiloteId,@RDB500ACSharpRuleVersionPhiloteId,@RDB500ACSharpRuleInputPhiloteId,@RDB500ACSharpDefaultPhiloteId,@RDB500ACSharpNodePhiloteId,@RDB500ACSharpRuleCode,@RDB500ACSharpPurpose,@RDB500ACSharpDefaultValue,@RDB500ACSharpSourceFileReference;
    WHILE @@FETCH_STATUS=0
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500ACSharpRuleKindId AND RuleCode=@RDB500ACSharpRuleCode)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500ACSharpRuleTypeId,@RDB500ACSharpRulePhiloteId,@RDB500ACSharpNow);
        SET @RDB500ACSharpEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Rule](RulePhiloteId,EntityId,EntityTypeId,RuleKindId,RuleCode,CreatedAtUtc)
        VALUES(@RDB500ACSharpRulePhiloteId,@RDB500ACSharpEntityId,@RDB500ACSharpRuleTypeId,@RDB500ACSharpRuleKindId,@RDB500ACSharpRuleCode,@RDB500ACSharpNow);
      END;
      IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500ACSharpRuleKindId AND RuleCode=@RDB500ACSharpRuleCode AND RulePhiloteId<>@RDB500ACSharpRulePhiloteId)
        THROW 55506, 'RDB-500A Rule natural key maps to a different Philote.', 1;
      SELECT @RDB500ACSharpRuleId=RuleId FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500ACSharpRuleKindId AND RuleCode=@RDB500ACSharpRuleCode;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500ACSharpRuleId AND RevisionSequence=1)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500ACSharpRuleVersionTypeId,@RDB500ACSharpRuleVersionPhiloteId,@RDB500ACSharpNow);
        SET @RDB500ACSharpEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleVersion]
          (RuleVersionPhiloteId,EntityId,EntityTypeId,RuleId,RuleKindId,RuleKindVersionId,RevisionSequence,
           PredecessorRuleVersionId,CompositionHashAlgorithmCode,CompositionContentHash,PublishedAtUtc)
        VALUES(@RDB500ACSharpRuleVersionPhiloteId,@RDB500ACSharpEntityId,@RDB500ACSharpRuleVersionTypeId,@RDB500ACSharpRuleId,@RDB500ACSharpRuleKindId,
          @RDB500ACSharpRuleKindVersionId,1,NULL,'SHA-256',HASHBYTES('SHA2_256',CONCAT(@RDB500ACSharpRuleCode,N'|',@RDB500ACSharpPurpose,N'|',@RDB500ACSharpSourceFileReference)),@RDB500ACSharpNow);
      END;
      SELECT @RDB500ACSharpRuleVersionId=RuleVersionId FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500ACSharpRuleId AND RevisionSequence=1;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500ACSharpRuleVersionId AND InputCode='content')
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500ACSharpRuleInputTypeId,@RDB500ACSharpRuleInputPhiloteId,@RDB500ACSharpNow);
        SET @RDB500ACSharpEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleInputDefinition]
          (RuleInputDefinitionPhiloteId,EntityId,EntityTypeId,RuleVersionId,InputCode,Ordinal,ValueTypeVersionId,
           MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500ACSharpRuleInputPhiloteId,@RDB500ACSharpEntityId,@RDB500ACSharpRuleInputTypeId,@RDB500ACSharpRuleVersionId,
          'content',0,@RDB500ACSharpValueTypeVersionId,1,1,0,'non-empty-text');
      END;
      SELECT @RDB500ACSharpRuleInputId=RuleInputDefinitionId FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500ACSharpRuleVersionId AND InputCode='content';
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleDefaultInputValue] WHERE RuleInputDefinitionId=@RDB500ACSharpRuleInputId)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500ACSharpRuleDefaultTypeId,@RDB500ACSharpDefaultPhiloteId,@RDB500ACSharpNow);
        SET @RDB500ACSharpEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleDefaultInputValue]
          (RuleDefaultInputValuePhiloteId,EntityId,EntityTypeId,RuleInputDefinitionId,RuleVersionId,ValueTypeVersionId,
           CanonicalTextValue,CanonicalValueHash,RationaleEntityId,RationaleEntityTypeId,PublishedAtUtc)
        VALUES(@RDB500ACSharpDefaultPhiloteId,@RDB500ACSharpEntityId,@RDB500ACSharpRuleDefaultTypeId,@RDB500ACSharpRuleInputId,@RDB500ACSharpRuleVersionId,
          @RDB500ACSharpValueTypeVersionId,@RDB500ACSharpDefaultValue,HASHBYTES('SHA2_256',@RDB500ACSharpDefaultValue),
          (SELECT EntityId FROM [ATAPUtilities].[Rule] WHERE RuleId=@RDB500ACSharpRuleId),@RDB500ACSharpRuleTypeId,@RDB500ACSharpNow);
      END;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId=@RDB500ACSharpNodePhiloteId)
        INSERT [ATAPUtilities].[RuleVersionNode]
          (RuleVersionNodePhiloteId,RuleVersionId,RuleKindVersionId,ParentRuleVersionNodeId,Ordinal,PrimitiveVersionId,
           MinOccurs,MaxOccurs,ChoiceDiscriminatorCode,NodeLabel)
        VALUES(@RDB500ACSharpNodePhiloteId,@RDB500ACSharpRuleVersionId,@RDB500ACSharpRuleKindVersionId,NULL,0,@RDB500ACSharpRootPrimitiveVersionId,1,1,NULL,N'root');
      SELECT @RDB500ACSharpNodeId=RuleVersionNodeId FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId=@RDB500ACSharpNodePhiloteId;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNodeInput] WHERE RuleVersionNodeId=@RDB500ACSharpNodeId AND PrimitiveInputDefinitionId=@RDB500ACSharpRootPrimitiveInputId)
        INSERT [ATAPUtilities].[RuleVersionNodeInput]
          (RuleVersionNodeId,RuleVersionId,PrimitiveVersionId,PrimitiveInputDefinitionId,BindingShapeCode,
           TargetValueTypeVersionId,SourceValueTypeVersionId,ConstantValueTypeVersionId,RuleInputDefinitionId,
           DerivationContractVersionId,ConversionPolicyCode,CanonicalTextValue,CanonicalValueHash)
        VALUES(@RDB500ACSharpNodeId,@RDB500ACSharpRuleVersionId,@RDB500ACSharpRootPrimitiveVersionId,@RDB500ACSharpRootPrimitiveInputId,
          'constant',@RDB500ACSharpValueTypeVersionId,NULL,@RDB500ACSharpValueTypeVersionId,NULL,NULL,NULL,@RDB500ACSharpDefaultValue,
          HASHBYTES('SHA2_256',@RDB500ACSharpDefaultValue));
      FETCH NEXT FROM RDB500ACSharpRuleCursor INTO @RDB500ACSharpRulePhiloteId,@RDB500ACSharpRuleVersionPhiloteId,@RDB500ACSharpRuleInputPhiloteId,@RDB500ACSharpDefaultPhiloteId,@RDB500ACSharpNodePhiloteId,@RDB500ACSharpRuleCode,@RDB500ACSharpPurpose,@RDB500ACSharpDefaultValue,@RDB500ACSharpSourceFileReference;
    END;
    CLOSE RDB500ACSharpRuleCursor; DEALLOCATE RDB500ACSharpRuleCursor;

    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500ACSharpRuleKindId) < 18
      THROW 55507, 'RDB-500A primitive row-count postcondition failed.', 1;
    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500ACSharpRuleKindId) < 7
      THROW 55508, 'RDB-500A rule row-count postcondition failed.', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','RDB500ACSharpPrimitiveCursor') >= -1 BEGIN CLOSE RDB500ACSharpPrimitiveCursor; DEALLOCATE RDB500ACSharpPrimitiveCursor; END;
    IF CURSOR_STATUS('local','RDB500ACSharpRuleCursor') >= -1 BEGIN CLOSE RDB500ACSharpRuleCursor; DEALLOCATE RDB500ACSharpRuleCursor; END;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
/* END INTEGRATED FRAGMENT: RDB-500A__CSharp.sql */

/* BEGIN INTEGRATED FRAGMENT: RDB-500B__PowerShell.sql */
/* Generated RRSBS Wave 6 seed fragment: RDB-500B.
   Owner boundary: RDB-500B only. Do not integrate by editing this file;
   RDB-510 is the sole final seed integrator. Deferred kinds: PlainText. */
/* RDB-500B / PowerShell reference seed.
   Positive: A PowerShell rule with a non-empty repository-relative source reference.
   Negative (declarative; exercised by RDB-510): A PowerShell rule with an empty content input or a cross-kind primitive version.
   Integration prerequisites are coordinator-owned and fail closed below. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @RDB500BPowerShellNow datetime2(7) = CONVERT(datetime2(7), '2026-08-06T00:00:00.0000000Z', 127);
DECLARE @RDB500BPowerShellGrammarSourceArtifactVersionId bigint;
DECLARE @RDB500BPowerShellCompendiumSourceArtifactVersionId bigint;
SELECT @RDB500BPowerShellGrammarSourceArtifactVersionId = sav.SourceArtifactVersionId
FROM [ATAPUtilities].[SourceArtifact] sa
JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId = sa.SourceArtifactId
WHERE sa.LocatorTypeCode = 'RepositoryPath'
  AND sa.RepoRelativePathOrExternalLocator = N'SolutionDocumentation/grammers/PowerShell.grammar.ebnf'
  AND sav.NormalizedContentSha256 = '74406ace55f1b8c7328ee5a299bfe904d535163f87319e74dc6e72b3b1f2b102';
SELECT @RDB500BPowerShellCompendiumSourceArtifactVersionId = sav.SourceArtifactVersionId
FROM [ATAPUtilities].[SourceArtifact] sa
JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId = sa.SourceArtifactId
WHERE sa.LocatorTypeCode = 'RepositoryPath'
  AND sa.RepoRelativePathOrExternalLocator = N'SolutionDocumentation/Rules Compendium.Powershell.md'
  AND sav.NormalizedContentSha256 = 'b74a013c5a610431950151e74e17e51e0f5a4f945eb7cd17166134717f8d11ad';
IF @RDB500BPowerShellGrammarSourceArtifactVersionId IS NULL OR @RDB500BPowerShellCompendiumSourceArtifactVersionId IS NULL
    THROW 55500, 'RDB-500B requires exact grammar and compendium SourceArtifactVersion rows.', 1;

DECLARE @RDB500BPowerShellRuleKindTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind');
DECLARE @RDB500BPowerShellRuleKindVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind-version');
DECLARE @RDB500BPowerShellValueTypeTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type');
DECLARE @RDB500BPowerShellValueTypeVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type-version');
DECLARE @RDB500BPowerShellPrimitiveTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive');
DECLARE @RDB500BPowerShellPrimitiveVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-version');
DECLARE @RDB500BPowerShellPrimitiveInputTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-input-definition');
DECLARE @RDB500BPowerShellRuleTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule');
DECLARE @RDB500BPowerShellRuleVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-version');
DECLARE @RDB500BPowerShellRuleInputTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-input-definition');
DECLARE @RDB500BPowerShellRuleDefaultTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-default-input-value');
IF @RDB500BPowerShellRuleKindTypeId IS NULL OR @RDB500BPowerShellRuleDefaultTypeId IS NULL
    THROW 55501, 'RDB-500B requires the frozen RDB-320 EntityType catalog.', 1;
IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ExecutionClassification] WHERE ExecutionClassificationCode='metadata-only' AND AllowsExecutorContract=0)
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[SecurityCapabilityClassification] WHERE SecurityCapabilityCode='reference-safe')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RoundTripPolicy] WHERE RoundTripPolicyCode='byte-identical')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ScalarStorageKind] WHERE ScalarStorageKindCode='bounded-unicode-text')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[BindingShape] WHERE BindingShapeCode='constant')
    THROW 55502, 'RDB-500B requires coordinator-owned closed catalog rows.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @RDB500BPowerShellEntityId bigint;
    DECLARE @RDB500BPowerShellRuleKindId bigint;
    DECLARE @RDB500BPowerShellRuleKindVersionId bigint;
    DECLARE @RDB500BPowerShellValueTypeId bigint;
    DECLARE @RDB500BPowerShellValueTypeVersionId bigint;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'PowerShell')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500BPowerShellRuleKindTypeId,'b3e50625-5ffa-5bca-8f1e-53ceeb087bc1',@RDB500BPowerShellNow);
        SET @RDB500BPowerShellEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleKind](RuleKindPhiloteId,EntityId,EntityTypeId,RuleKindCode,CreatedAtUtc)
        VALUES('b3e50625-5ffa-5bca-8f1e-53ceeb087bc1',@RDB500BPowerShellEntityId,@RDB500BPowerShellRuleKindTypeId,N'PowerShell',@RDB500BPowerShellNow);
    END;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'PowerShell' AND RuleKindPhiloteId<>'b3e50625-5ffa-5bca-8f1e-53ceeb087bc1')
        THROW 55503, 'RDB-500B RuleKind natural key maps to a different Philote.', 1;
    SELECT @RDB500BPowerShellRuleKindId=RuleKindId FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'PowerShell';

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500BPowerShellRuleKindId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500BPowerShellRuleKindVersionTypeId,'096d6dc5-a94f-5d96-a28c-f242c15f4718',@RDB500BPowerShellNow);
        SET @RDB500BPowerShellEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleKindVersion]
          (RuleKindVersionPhiloteId,EntityId,EntityTypeId,RuleKindId,RevisionSequence,PredecessorRuleKindVersionId,
           GrammarSourceArtifactVersionId,GrammarHashAlgorithmCode,GrammarContentHash,CompendiumSourceArtifactVersionId,
           CompendiumHashAlgorithmCode,CompendiumContentHash,ExecutorContractVersionId,ExecutionClassificationCode,
           SecurityCapabilityCode,RoundTripPolicyCode,PublishedAtUtc)
        VALUES('096d6dc5-a94f-5d96-a28c-f242c15f4718',@RDB500BPowerShellEntityId,@RDB500BPowerShellRuleKindVersionTypeId,@RDB500BPowerShellRuleKindId,1,NULL,
          @RDB500BPowerShellGrammarSourceArtifactVersionId,'SHA-256',0x74406ace55f1b8c7328ee5a299bfe904d535163f87319e74dc6e72b3b1f2b102,@RDB500BPowerShellCompendiumSourceArtifactVersionId,
          'SHA-256',0xb74a013c5a610431950151e74e17e51e0f5a4f945eb7cd17166134717f8d11ad,NULL,'metadata-only','reference-safe','byte-identical',@RDB500BPowerShellNow);
    END;
    SELECT @RDB500BPowerShellRuleKindVersionId=RuleKindVersionId FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500BPowerShellRuleKindId AND RevisionSequence=1;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-powershell-text')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500BPowerShellValueTypeTypeId,'1afb2f84-bf40-5f8a-89f9-760fda229b59',@RDB500BPowerShellNow);
        SET @RDB500BPowerShellEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[ValueType](ValueTypePhiloteId,EntityId,EntityTypeId,ValueTypeCode,CreatedAtUtc)
        VALUES('1afb2f84-bf40-5f8a-89f9-760fda229b59',@RDB500BPowerShellEntityId,@RDB500BPowerShellValueTypeTypeId,'seed-powershell-text',@RDB500BPowerShellNow);
    END;
    SELECT @RDB500BPowerShellValueTypeId=ValueTypeId FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-powershell-text';
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500BPowerShellValueTypeId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500BPowerShellValueTypeVersionTypeId,'b94229fb-6f69-50db-90af-c4b2d144ee06',@RDB500BPowerShellNow);
        SET @RDB500BPowerShellEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[ValueTypeVersion]
          (ValueTypeVersionPhiloteId,EntityId,EntityTypeId,ValueTypeId,RevisionSequence,PredecessorValueTypeVersionId,
           ValueCategoryCode,ScalarStorageKindCode,StructuredValueContractVersionId,ElementValueTypeVersionId,
           CollectionOrderingCode,SecretReferencePolicyId,ValidationContractCode,PublishedAtUtc)
        VALUES('b94229fb-6f69-50db-90af-c4b2d144ee06',@RDB500BPowerShellEntityId,@RDB500BPowerShellValueTypeVersionTypeId,@RDB500BPowerShellValueTypeId,1,NULL,
          'scalar','bounded-unicode-text',NULL,NULL,NULL,NULL,'non-empty-text',@RDB500BPowerShellNow);
    END;
    SELECT @RDB500BPowerShellValueTypeVersionId=ValueTypeVersionId FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500BPowerShellValueTypeId AND RevisionSequence=1;

    DECLARE @RDB500BPowerShellPrimitives TABLE(PrimitivePhiloteId uniqueidentifier,PrimitiveVersionPhiloteId uniqueidentifier,
      InputPhiloteId uniqueidentifier,PrimitiveCode varchar(128),DefinitionText nvarchar(max));
    INSERT @RDB500BPowerShellPrimitives VALUES
        ('e1a2b3c4-d5e6-4f78-9012-a3b4c5d6e7f8', '0abbde2e-1b62-561b-8cd3-6cef184886c2', '617f6dfc-a1b0-59f9-ad4e-b0f38db0018b', N'<complete-powershell-cmdlet>', N'Holds an entire PowerShell cmdlet as a single text block'),
        ('f2b3c4d5-e6f7-4089-a123-b4c5d6e7f8a9', '5344d4e4-dcd9-58db-823f-972b8d2dae09', '4efc7e6e-348e-5cab-821a-5e5e0875c429', N'<composed-powershell-cmdlet>', N'Container into which PowerShell cmdlet sections (param, begin, process, end) are inserted via BNF derivation');
    DECLARE @RDB500BPowerShellPrimitivePhiloteId uniqueidentifier,@RDB500BPowerShellPrimitiveVersionPhiloteId uniqueidentifier,
      @RDB500BPowerShellInputPhiloteId uniqueidentifier,@RDB500BPowerShellPrimitiveCode varchar(128),@RDB500BPowerShellDefinitionText nvarchar(max),
      @RDB500BPowerShellPrimitiveId bigint,@RDB500BPowerShellPrimitiveVersionId bigint;
    DECLARE RDB500BPowerShellPrimitiveCursor CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @RDB500BPowerShellPrimitives ORDER BY PrimitiveCode;
    OPEN RDB500BPowerShellPrimitiveCursor;
    FETCH NEXT FROM RDB500BPowerShellPrimitiveCursor INTO @RDB500BPowerShellPrimitivePhiloteId,@RDB500BPowerShellPrimitiveVersionPhiloteId,@RDB500BPowerShellInputPhiloteId,@RDB500BPowerShellPrimitiveCode,@RDB500BPowerShellDefinitionText;
    WHILE @@FETCH_STATUS=0
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500BPowerShellRuleKindId AND PrimitiveCode=@RDB500BPowerShellPrimitiveCode)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500BPowerShellPrimitiveTypeId,@RDB500BPowerShellPrimitivePhiloteId,@RDB500BPowerShellNow);
        SET @RDB500BPowerShellEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500BPowerShellPrimitivePhiloteId,@RDB500BPowerShellEntityId,@RDB500BPowerShellPrimitiveTypeId,@RDB500BPowerShellRuleKindId,@RDB500BPowerShellPrimitiveCode,@RDB500BPowerShellNow);
      END;
      IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500BPowerShellRuleKindId AND PrimitiveCode=@RDB500BPowerShellPrimitiveCode AND PrimitivePhiloteId<>@RDB500BPowerShellPrimitivePhiloteId)
        THROW 55504, 'RDB-500B Primitive natural key maps to a different Philote.', 1;
      SELECT @RDB500BPowerShellPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500BPowerShellRuleKindId AND PrimitiveCode=@RDB500BPowerShellPrimitiveCode;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500BPowerShellPrimitiveId AND RevisionSequence=1)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500BPowerShellPrimitiveVersionTypeId,@RDB500BPowerShellPrimitiveVersionPhiloteId,@RDB500BPowerShellNow);
        SET @RDB500BPowerShellEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,
           PredecessorPrimitiveVersionId,GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,
           DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500BPowerShellPrimitiveVersionPhiloteId,@RDB500BPowerShellEntityId,@RDB500BPowerShellPrimitiveVersionTypeId,@RDB500BPowerShellPrimitiveId,
          @RDB500BPowerShellRuleKindId,@RDB500BPowerShellRuleKindVersionId,1,NULL,@RDB500BPowerShellPrimitiveCode,@RDB500BPowerShellDefinitionText,'SHA-256',
          HASHBYTES('SHA2_256',@RDB500BPowerShellDefinitionText),@RDB500BPowerShellValueTypeVersionId,1,1,@RDB500BPowerShellNow);
      END;
      SELECT @RDB500BPowerShellPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500BPowerShellPrimitiveId AND RevisionSequence=1;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500BPowerShellPrimitiveVersionId AND InputCode='content')
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500BPowerShellPrimitiveInputTypeId,@RDB500BPowerShellInputPhiloteId,@RDB500BPowerShellNow);
        SET @RDB500BPowerShellEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,
           ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500BPowerShellInputPhiloteId,@RDB500BPowerShellEntityId,@RDB500BPowerShellPrimitiveInputTypeId,@RDB500BPowerShellPrimitiveVersionId,
          'content',0,@RDB500BPowerShellValueTypeVersionId,1,1,0,'non-empty-text');
      END;
      FETCH NEXT FROM RDB500BPowerShellPrimitiveCursor INTO @RDB500BPowerShellPrimitivePhiloteId,@RDB500BPowerShellPrimitiveVersionPhiloteId,@RDB500BPowerShellInputPhiloteId,@RDB500BPowerShellPrimitiveCode,@RDB500BPowerShellDefinitionText;
    END;
    CLOSE RDB500BPowerShellPrimitiveCursor; DEALLOCATE RDB500BPowerShellPrimitiveCursor;

    DECLARE @RDB500BPowerShellRootPrimitiveVersionId bigint,@RDB500BPowerShellRootPrimitiveInputId bigint;
    SELECT @RDB500BPowerShellRootPrimitiveVersionId=pv.PrimitiveVersionId,@RDB500BPowerShellRootPrimitiveInputId=pid.PrimitiveInputDefinitionId
    FROM [ATAPUtilities].[Primitive] p JOIN [ATAPUtilities].[PrimitiveVersion] pv ON pv.PrimitiveId=p.PrimitiveId AND pv.RevisionSequence=1
    JOIN [ATAPUtilities].[PrimitiveInputDefinition] pid ON pid.PrimitiveVersionId=pv.PrimitiveVersionId AND pid.InputCode='content'
    WHERE p.RuleKindId=@RDB500BPowerShellRuleKindId AND p.PrimitiveCode=N'<complete-powershell-cmdlet>';
    IF @RDB500BPowerShellRootPrimitiveInputId IS NULL THROW 55505, 'RDB-500B top primitive/input was not materialized.', 1;

    DECLARE @RDB500BPowerShellRules TABLE(RulePhiloteId uniqueidentifier,RuleVersionPhiloteId uniqueidentifier,
      RuleInputPhiloteId uniqueidentifier,DefaultPhiloteId uniqueidentifier,NodePhiloteId uniqueidentifier,
      RuleCode varchar(128),Purpose nvarchar(max),DefaultValue nvarchar(max),SourceFileReference nvarchar(2048));
    INSERT @RDB500BPowerShellRules VALUES
        ('a1b2c3d4-e5f6-4a78-9012-b3c4d5e6f7a8', 'b4a3d6a2-f59b-5ad9-8780-bcdcc7645130', '15ab0dd6-3dc5-560d-b96e-6f0edc9f6417', 'fad95f6b-c11e-57de-be56-27a74c6ecffd', '9aff1d22-f4d0-5b23-bbda-3bf13d65485b', N'Build-ImageFromPlantUML', N'Walks a directory tree and generates PlantUML images (SVG/PNG) from diagram source files with various extensions, mirroring directory structure to output location.', N'src/ATAP.Utilities.BuildTooling.PowerShell/public/Build-ImageFromPlantUML.ps1', N'src/ATAP.Utilities.BuildTooling.PowerShell/public/Build-ImageFromPlantUML.ps1'),
        ('b2c3d4e5-f6a7-4b89-a123-c4d5e6f7a8b9', '0e7301ed-c25e-550e-9154-cf8ad3f75bdf', '2bd2ab22-37e1-577d-bac8-2a6c9e90d2a0', 'e8a73d03-81d9-5163-a1d3-6b403436d418', 'acb1275d-c595-5afa-b4c0-7a20f4cb00ca', N'Test-PowerShellSyntax', N'Validates PowerShell script syntax using the AST parser to detect parse errors before execution.', N'src/ATAP.Utilities.BuildTooling.PowerShell/public/check-syntax.ps1', N'src/ATAP.Utilities.BuildTooling.PowerShell/public/check-syntax.ps1'),
        ('c3d4e5f6-a7b8-4c90-b234-d5e6f7a8b9c0', 'ca1a727f-f78a-524d-a359-4b691e07eae3', '8e5bbbc8-392e-5963-8c12-48ff58d3e8cc', '2e3b2ef3-06cf-5ed1-8166-8cff1a35a10c', 'f15f4406-3de1-5d28-8eb0-3240dd53c13c', N'New-MCPServerJunction', N'Creates a directory junction from repository root to SharedVSCode MCP servers folder, making MCP servers accessible throughout the repository.', N'src/ATAP.Utilities.BuildTooling.PowerShell/public/Create-MCPJunction.ps1', N'src/ATAP.Utilities.BuildTooling.PowerShell/public/Create-MCPJunction.ps1'),
        ('d4e5f6a7-b8c9-4d01-c345-e6f7a8b9c0d1', '788e076e-aa32-5597-8f4d-a2249d970013', '83bb33f1-b1df-55a0-a752-b16f787e744c', '9c17035a-ee9b-58f8-86c7-2ad8b1a1dcae', '92e8c425-7974-5e96-9bda-2f278f98b2fe', N'Get-RepositoryRoot', N'Finds and returns the repository root directory by searching upward through the directory tree for a .git folder.', N'src/ATAP.Utilities.BuildTooling.PowerShell/public/Get-RepositoryRoot.ps1', N'src/ATAP.Utilities.BuildTooling.PowerShell/public/Get-RepositoryRoot.ps1'),
        ('e5f6a7b8-c9d0-4e12-d456-f7a8b9c0d1e2', '65e9bf7e-edfd-5fce-8320-70dbcfe0ba0b', '6bb74136-8f48-5bc8-b3e6-c83d8259909a', '39529b67-44fb-5fec-be9d-6a611c823f76', '09e1a800-34dd-5dd8-a5b1-0a3b89854cb3', N'Remove-ObjAndBinSubDirectories', N'Recursively searches for and removes obj and bin subdirectories from a specified path to clean build artifacts.', N'src/ATAP.Utilities.BuildTooling.PowerShell/public/Remove-ObjAndBinSubDirectories.ps1', N'src/ATAP.Utilities.BuildTooling.PowerShell/public/Remove-ObjAndBinSubDirectories.ps1'),
        ('f6a7b8c9-d0e1-4f23-e567-a8b9c0d1e2f3', '9d743ed3-6889-5899-ad57-259cb785ecaa', '494af9ea-2fae-5435-a424-c23fdc48e9dc', 'b54e4bd9-6091-50b3-a6fb-82b061937582', 'dcde85e3-b2b5-573d-8732-397c2a1f0c95', N'Sync-RulesToCSV', N'Exports Rules, RulePrimitives, and related RRSBS tables from the database to CSV files for version control and backup.', N'src/ATAP.Utilities.BuildTooling.PowerShell/public/Sync-RulesToCSV.ps1', N'src/ATAP.Utilities.BuildTooling.PowerShell/public/Sync-RulesToCSV.ps1'),
        ('a7b8c9d0-e1f2-4034-f678-b9c0d1e2f3a4', 'c30a93a9-7fde-5508-8ed5-d713b7d196bf', 'e3072395-8043-5001-9b6d-255927b013dd', '2a197b95-ff5f-5c90-913f-5445140dddbb', '02541c63-d33d-53ec-b635-1953bb8ccbe1', N'Read-SourceAndCreateRules', N'AI-assisted extraction of Rules metadata from source code files (PowerShell, C#, MSBuild, SQL) with parsing of function declarations and comment-based help.', N'src/ATAP.Utilities.BuildTooling.PowerShell/public/Read-SourceAndCreateRules.ps1', N'src/ATAP.Utilities.BuildTooling.PowerShell/public/Read-SourceAndCreateRules.ps1'),
        ('fefa78dd-2291-44b1-96b7-14a0bb857a5c', '9b5e5b6d-7bcd-59e4-9dca-63f0f7ccdc97', '03115838-dd9c-5127-b8c0-d6378398b390', '86d5c1f8-d633-5a74-b53a-6c9db9545771', 'ae670c74-a3fd-5ee3-8a4b-94ee97710a6d', N'Write-ArrayIndented', N'Formats an array as an indented multi-line string, recursively rendering nested arrays and hashtables for diagnostic display.', N'src/ATAP.Utilities.BuildTooling.PowerShell/public/Write-ArrayIndented.ps1', N'src/ATAP.Utilities.BuildTooling.PowerShell/public/Write-ArrayIndented.ps1');
    DECLARE @RDB500BPowerShellRulePhiloteId uniqueidentifier,@RDB500BPowerShellRuleVersionPhiloteId uniqueidentifier,
      @RDB500BPowerShellRuleInputPhiloteId uniqueidentifier,@RDB500BPowerShellDefaultPhiloteId uniqueidentifier,@RDB500BPowerShellNodePhiloteId uniqueidentifier,
      @RDB500BPowerShellRuleCode varchar(128),@RDB500BPowerShellPurpose nvarchar(max),@RDB500BPowerShellDefaultValue nvarchar(max),@RDB500BPowerShellSourceFileReference nvarchar(2048),
      @RDB500BPowerShellRuleId bigint,@RDB500BPowerShellRuleVersionId bigint,@RDB500BPowerShellRuleInputId bigint,@RDB500BPowerShellNodeId bigint;
    DECLARE RDB500BPowerShellRuleCursor CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @RDB500BPowerShellRules ORDER BY RuleCode;
    OPEN RDB500BPowerShellRuleCursor;
    FETCH NEXT FROM RDB500BPowerShellRuleCursor INTO @RDB500BPowerShellRulePhiloteId,@RDB500BPowerShellRuleVersionPhiloteId,@RDB500BPowerShellRuleInputPhiloteId,@RDB500BPowerShellDefaultPhiloteId,@RDB500BPowerShellNodePhiloteId,@RDB500BPowerShellRuleCode,@RDB500BPowerShellPurpose,@RDB500BPowerShellDefaultValue,@RDB500BPowerShellSourceFileReference;
    WHILE @@FETCH_STATUS=0
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500BPowerShellRuleKindId AND RuleCode=@RDB500BPowerShellRuleCode)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500BPowerShellRuleTypeId,@RDB500BPowerShellRulePhiloteId,@RDB500BPowerShellNow);
        SET @RDB500BPowerShellEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Rule](RulePhiloteId,EntityId,EntityTypeId,RuleKindId,RuleCode,CreatedAtUtc)
        VALUES(@RDB500BPowerShellRulePhiloteId,@RDB500BPowerShellEntityId,@RDB500BPowerShellRuleTypeId,@RDB500BPowerShellRuleKindId,@RDB500BPowerShellRuleCode,@RDB500BPowerShellNow);
      END;
      IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500BPowerShellRuleKindId AND RuleCode=@RDB500BPowerShellRuleCode AND RulePhiloteId<>@RDB500BPowerShellRulePhiloteId)
        THROW 55506, 'RDB-500B Rule natural key maps to a different Philote.', 1;
      SELECT @RDB500BPowerShellRuleId=RuleId FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500BPowerShellRuleKindId AND RuleCode=@RDB500BPowerShellRuleCode;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500BPowerShellRuleId AND RevisionSequence=1)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500BPowerShellRuleVersionTypeId,@RDB500BPowerShellRuleVersionPhiloteId,@RDB500BPowerShellNow);
        SET @RDB500BPowerShellEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleVersion]
          (RuleVersionPhiloteId,EntityId,EntityTypeId,RuleId,RuleKindId,RuleKindVersionId,RevisionSequence,
           PredecessorRuleVersionId,CompositionHashAlgorithmCode,CompositionContentHash,PublishedAtUtc)
        VALUES(@RDB500BPowerShellRuleVersionPhiloteId,@RDB500BPowerShellEntityId,@RDB500BPowerShellRuleVersionTypeId,@RDB500BPowerShellRuleId,@RDB500BPowerShellRuleKindId,
          @RDB500BPowerShellRuleKindVersionId,1,NULL,'SHA-256',HASHBYTES('SHA2_256',CONCAT(@RDB500BPowerShellRuleCode,N'|',@RDB500BPowerShellPurpose,N'|',@RDB500BPowerShellSourceFileReference)),@RDB500BPowerShellNow);
      END;
      SELECT @RDB500BPowerShellRuleVersionId=RuleVersionId FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500BPowerShellRuleId AND RevisionSequence=1;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500BPowerShellRuleVersionId AND InputCode='content')
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500BPowerShellRuleInputTypeId,@RDB500BPowerShellRuleInputPhiloteId,@RDB500BPowerShellNow);
        SET @RDB500BPowerShellEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleInputDefinition]
          (RuleInputDefinitionPhiloteId,EntityId,EntityTypeId,RuleVersionId,InputCode,Ordinal,ValueTypeVersionId,
           MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500BPowerShellRuleInputPhiloteId,@RDB500BPowerShellEntityId,@RDB500BPowerShellRuleInputTypeId,@RDB500BPowerShellRuleVersionId,
          'content',0,@RDB500BPowerShellValueTypeVersionId,1,1,0,'non-empty-text');
      END;
      SELECT @RDB500BPowerShellRuleInputId=RuleInputDefinitionId FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500BPowerShellRuleVersionId AND InputCode='content';
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleDefaultInputValue] WHERE RuleInputDefinitionId=@RDB500BPowerShellRuleInputId)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500BPowerShellRuleDefaultTypeId,@RDB500BPowerShellDefaultPhiloteId,@RDB500BPowerShellNow);
        SET @RDB500BPowerShellEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleDefaultInputValue]
          (RuleDefaultInputValuePhiloteId,EntityId,EntityTypeId,RuleInputDefinitionId,RuleVersionId,ValueTypeVersionId,
           CanonicalTextValue,CanonicalValueHash,RationaleEntityId,RationaleEntityTypeId,PublishedAtUtc)
        VALUES(@RDB500BPowerShellDefaultPhiloteId,@RDB500BPowerShellEntityId,@RDB500BPowerShellRuleDefaultTypeId,@RDB500BPowerShellRuleInputId,@RDB500BPowerShellRuleVersionId,
          @RDB500BPowerShellValueTypeVersionId,@RDB500BPowerShellDefaultValue,HASHBYTES('SHA2_256',@RDB500BPowerShellDefaultValue),
          (SELECT EntityId FROM [ATAPUtilities].[Rule] WHERE RuleId=@RDB500BPowerShellRuleId),@RDB500BPowerShellRuleTypeId,@RDB500BPowerShellNow);
      END;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId=@RDB500BPowerShellNodePhiloteId)
        INSERT [ATAPUtilities].[RuleVersionNode]
          (RuleVersionNodePhiloteId,RuleVersionId,RuleKindVersionId,ParentRuleVersionNodeId,Ordinal,PrimitiveVersionId,
           MinOccurs,MaxOccurs,ChoiceDiscriminatorCode,NodeLabel)
        VALUES(@RDB500BPowerShellNodePhiloteId,@RDB500BPowerShellRuleVersionId,@RDB500BPowerShellRuleKindVersionId,NULL,0,@RDB500BPowerShellRootPrimitiveVersionId,1,1,NULL,N'root');
      SELECT @RDB500BPowerShellNodeId=RuleVersionNodeId FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId=@RDB500BPowerShellNodePhiloteId;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNodeInput] WHERE RuleVersionNodeId=@RDB500BPowerShellNodeId AND PrimitiveInputDefinitionId=@RDB500BPowerShellRootPrimitiveInputId)
        INSERT [ATAPUtilities].[RuleVersionNodeInput]
          (RuleVersionNodeId,RuleVersionId,PrimitiveVersionId,PrimitiveInputDefinitionId,BindingShapeCode,
           TargetValueTypeVersionId,SourceValueTypeVersionId,ConstantValueTypeVersionId,RuleInputDefinitionId,
           DerivationContractVersionId,ConversionPolicyCode,CanonicalTextValue,CanonicalValueHash)
        VALUES(@RDB500BPowerShellNodeId,@RDB500BPowerShellRuleVersionId,@RDB500BPowerShellRootPrimitiveVersionId,@RDB500BPowerShellRootPrimitiveInputId,
          'constant',@RDB500BPowerShellValueTypeVersionId,NULL,@RDB500BPowerShellValueTypeVersionId,NULL,NULL,NULL,@RDB500BPowerShellDefaultValue,
          HASHBYTES('SHA2_256',@RDB500BPowerShellDefaultValue));
      FETCH NEXT FROM RDB500BPowerShellRuleCursor INTO @RDB500BPowerShellRulePhiloteId,@RDB500BPowerShellRuleVersionPhiloteId,@RDB500BPowerShellRuleInputPhiloteId,@RDB500BPowerShellDefaultPhiloteId,@RDB500BPowerShellNodePhiloteId,@RDB500BPowerShellRuleCode,@RDB500BPowerShellPurpose,@RDB500BPowerShellDefaultValue,@RDB500BPowerShellSourceFileReference;
    END;
    CLOSE RDB500BPowerShellRuleCursor; DEALLOCATE RDB500BPowerShellRuleCursor;

    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500BPowerShellRuleKindId) < 2
      THROW 55507, 'RDB-500B primitive row-count postcondition failed.', 1;
    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500BPowerShellRuleKindId) < 8
      THROW 55508, 'RDB-500B rule row-count postcondition failed.', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','RDB500BPowerShellPrimitiveCursor') >= -1 BEGIN CLOSE RDB500BPowerShellPrimitiveCursor; DEALLOCATE RDB500BPowerShellPrimitiveCursor; END;
    IF CURSOR_STATUS('local','RDB500BPowerShellRuleCursor') >= -1 BEGIN CLOSE RDB500BPowerShellRuleCursor; DEALLOCATE RDB500BPowerShellRuleCursor; END;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
/* END INTEGRATED FRAGMENT: RDB-500B__PowerShell.sql */

/* BEGIN INTEGRATED FRAGMENT: RDB-500C__SQL-MSBuild.sql */
/* Generated RRSBS Wave 6 seed fragment: RDB-500C.
   Owner boundary: RDB-500C only. Do not integrate by editing this file;
   RDB-510 is the sole final seed integrator. Deferred kinds: . */
/* RDB-500C / SQL reference seed.
   Positive: A SQL rule with a non-empty repository-relative source reference.
   Negative (declarative; exercised by RDB-510): A SQL rule with an empty content input or a cross-kind primitive version.
   Integration prerequisites are coordinator-owned and fail closed below. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @RDB500CSQLNow datetime2(7) = CONVERT(datetime2(7), '2026-08-06T00:00:00.0000000Z', 127);
DECLARE @RDB500CSQLGrammarSourceArtifactVersionId bigint;
DECLARE @RDB500CSQLCompendiumSourceArtifactVersionId bigint;
SELECT @RDB500CSQLGrammarSourceArtifactVersionId = sav.SourceArtifactVersionId
FROM [ATAPUtilities].[SourceArtifact] sa
JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId = sa.SourceArtifactId
WHERE sa.LocatorTypeCode = 'RepositoryPath'
  AND sa.RepoRelativePathOrExternalLocator = N'SolutionDocumentation/grammers/SQL.grammar.ebnf'
  AND sav.NormalizedContentSha256 = 'ea1fb29eb49e889cf3eff7920a50f8c9cc102dc327be0412106a13d61968f06f';
SELECT @RDB500CSQLCompendiumSourceArtifactVersionId = sav.SourceArtifactVersionId
FROM [ATAPUtilities].[SourceArtifact] sa
JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId = sa.SourceArtifactId
WHERE sa.LocatorTypeCode = 'RepositoryPath'
  AND sa.RepoRelativePathOrExternalLocator = N'SolutionDocumentation/Rules Compendium.SQL.md'
  AND sav.NormalizedContentSha256 = '7feaf8e407e235f8b007168a07c35737ed9e03221d0a3dea275a6b2f16535d76';
IF @RDB500CSQLGrammarSourceArtifactVersionId IS NULL OR @RDB500CSQLCompendiumSourceArtifactVersionId IS NULL
    THROW 55500, 'RDB-500C requires exact grammar and compendium SourceArtifactVersion rows.', 1;

DECLARE @RDB500CSQLRuleKindTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind');
DECLARE @RDB500CSQLRuleKindVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind-version');
DECLARE @RDB500CSQLValueTypeTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type');
DECLARE @RDB500CSQLValueTypeVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type-version');
DECLARE @RDB500CSQLPrimitiveTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive');
DECLARE @RDB500CSQLPrimitiveVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-version');
DECLARE @RDB500CSQLPrimitiveInputTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-input-definition');
DECLARE @RDB500CSQLRuleTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule');
DECLARE @RDB500CSQLRuleVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-version');
DECLARE @RDB500CSQLRuleInputTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-input-definition');
DECLARE @RDB500CSQLRuleDefaultTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-default-input-value');
IF @RDB500CSQLRuleKindTypeId IS NULL OR @RDB500CSQLRuleDefaultTypeId IS NULL
    THROW 55501, 'RDB-500C requires the frozen RDB-320 EntityType catalog.', 1;
IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ExecutionClassification] WHERE ExecutionClassificationCode='metadata-only' AND AllowsExecutorContract=0)
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[SecurityCapabilityClassification] WHERE SecurityCapabilityCode='reference-safe')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RoundTripPolicy] WHERE RoundTripPolicyCode='byte-identical')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ScalarStorageKind] WHERE ScalarStorageKindCode='bounded-unicode-text')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[BindingShape] WHERE BindingShapeCode='constant')
    THROW 55502, 'RDB-500C requires coordinator-owned closed catalog rows.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @RDB500CSQLEntityId bigint;
    DECLARE @RDB500CSQLRuleKindId bigint;
    DECLARE @RDB500CSQLRuleKindVersionId bigint;
    DECLARE @RDB500CSQLValueTypeId bigint;
    DECLARE @RDB500CSQLValueTypeVersionId bigint;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'SQL')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CSQLRuleKindTypeId,'f986e3b3-121c-5437-80ef-0b05d0c7d55e',@RDB500CSQLNow);
        SET @RDB500CSQLEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleKind](RuleKindPhiloteId,EntityId,EntityTypeId,RuleKindCode,CreatedAtUtc)
        VALUES('f986e3b3-121c-5437-80ef-0b05d0c7d55e',@RDB500CSQLEntityId,@RDB500CSQLRuleKindTypeId,N'SQL',@RDB500CSQLNow);
    END;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'SQL' AND RuleKindPhiloteId<>'f986e3b3-121c-5437-80ef-0b05d0c7d55e')
        THROW 55503, 'RDB-500C RuleKind natural key maps to a different Philote.', 1;
    SELECT @RDB500CSQLRuleKindId=RuleKindId FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'SQL';

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500CSQLRuleKindId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CSQLRuleKindVersionTypeId,'2333169b-3c34-5f86-b9be-c7d3503c80f7',@RDB500CSQLNow);
        SET @RDB500CSQLEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleKindVersion]
          (RuleKindVersionPhiloteId,EntityId,EntityTypeId,RuleKindId,RevisionSequence,PredecessorRuleKindVersionId,
           GrammarSourceArtifactVersionId,GrammarHashAlgorithmCode,GrammarContentHash,CompendiumSourceArtifactVersionId,
           CompendiumHashAlgorithmCode,CompendiumContentHash,ExecutorContractVersionId,ExecutionClassificationCode,
           SecurityCapabilityCode,RoundTripPolicyCode,PublishedAtUtc)
        VALUES('2333169b-3c34-5f86-b9be-c7d3503c80f7',@RDB500CSQLEntityId,@RDB500CSQLRuleKindVersionTypeId,@RDB500CSQLRuleKindId,1,NULL,
          @RDB500CSQLGrammarSourceArtifactVersionId,'SHA-256',0xea1fb29eb49e889cf3eff7920a50f8c9cc102dc327be0412106a13d61968f06f,@RDB500CSQLCompendiumSourceArtifactVersionId,
          'SHA-256',0x7feaf8e407e235f8b007168a07c35737ed9e03221d0a3dea275a6b2f16535d76,NULL,'metadata-only','reference-safe','byte-identical',@RDB500CSQLNow);
    END;
    SELECT @RDB500CSQLRuleKindVersionId=RuleKindVersionId FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500CSQLRuleKindId AND RevisionSequence=1;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-sql-text')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CSQLValueTypeTypeId,'419bf646-54db-5c99-a8ce-9708b587b293',@RDB500CSQLNow);
        SET @RDB500CSQLEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[ValueType](ValueTypePhiloteId,EntityId,EntityTypeId,ValueTypeCode,CreatedAtUtc)
        VALUES('419bf646-54db-5c99-a8ce-9708b587b293',@RDB500CSQLEntityId,@RDB500CSQLValueTypeTypeId,'seed-sql-text',@RDB500CSQLNow);
    END;
    SELECT @RDB500CSQLValueTypeId=ValueTypeId FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-sql-text';
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500CSQLValueTypeId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CSQLValueTypeVersionTypeId,'fdaaa60b-f6ca-550b-b5eb-b914c652f404',@RDB500CSQLNow);
        SET @RDB500CSQLEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[ValueTypeVersion]
          (ValueTypeVersionPhiloteId,EntityId,EntityTypeId,ValueTypeId,RevisionSequence,PredecessorValueTypeVersionId,
           ValueCategoryCode,ScalarStorageKindCode,StructuredValueContractVersionId,ElementValueTypeVersionId,
           CollectionOrderingCode,SecretReferencePolicyId,ValidationContractCode,PublishedAtUtc)
        VALUES('fdaaa60b-f6ca-550b-b5eb-b914c652f404',@RDB500CSQLEntityId,@RDB500CSQLValueTypeVersionTypeId,@RDB500CSQLValueTypeId,1,NULL,
          'scalar','bounded-unicode-text',NULL,NULL,NULL,NULL,'non-empty-text',@RDB500CSQLNow);
    END;
    SELECT @RDB500CSQLValueTypeVersionId=ValueTypeVersionId FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500CSQLValueTypeId AND RevisionSequence=1;

    DECLARE @RDB500CSQLPrimitives TABLE(PrimitivePhiloteId uniqueidentifier,PrimitiveVersionPhiloteId uniqueidentifier,
      InputPhiloteId uniqueidentifier,PrimitiveCode varchar(128),DefinitionText nvarchar(max));
    INSERT @RDB500CSQLPrimitives VALUES
        ('a3f2e1d0-1b2c-4a5b-8c9d-0e1f2a3b4c5d', '71eecbb9-87f2-5556-ae13-1dbd160d2306', '67b3455c-3266-51f3-9750-475ff8446434', N'<sql-script-file>', N'Top-level container for a .sql file'),
        ('b4e3f2c1-2c3d-4b6c-9d0e-1f2a3b4c5d6e', '41f5384a-f4c9-507d-9b9a-87c3934c7a23', '6a39d19a-cb21-5c01-9322-fa7cabf6f702', N'<batch>', N'Sequence of T-SQL statements sent to SQL Server as a unit'),
        ('c5d4e3b2-3d4e-4c7d-ae1f-2a3b4c5d6e7f', 'b76165e7-7c46-5ba9-9cc4-36a5b8bda213', '9db0218d-7e24-55f5-b608-f1852643351b', N'<go-separator>', N'GO batch separator recognized by SSMS and sqlcmd'),
        ('d6c5d4a3-4e5f-4d8e-bf20-3b4c5d6e7f80', '7a8486ef-e612-5d91-9824-8d02c27aba40', 'bbf1bb58-dfee-50b0-b90e-6746680ecc19', N'<use-statement>', N'Changes the current database context (USE <db>)'),
        ('e7b6c5f4-5f60-4e9f-c031-4c5d6e7f8091', '3db80cae-f8b1-5ac3-8838-541966d1d984', 'ca710e85-e09e-534e-9012-bb5234ab60fb', N'<set-option-statement>', N'Configures a session-level behavior flag (e.g. ANSI_NULLS)'),
        ('f8a7d6e5-6071-4f0a-d142-5d6e7f809102', '29c77b9d-b8ca-51b1-b2f9-ad0c407cc461', 'bec02e84-79c0-5d4d-b84b-31b3d0cbc291', N'<single-line-comment>', N'Single-line T-SQL comment (--)'),
        ('09b8e7f6-7182-4a1b-e253-6e7f8091a234', '57a8b52c-90a2-58e5-bbb2-a836cace370d', '703270b7-db0c-54a5-bbc5-5ddfa93212d9', N'<block-comment>', N'Multi-line block comment (/* ... */)'),
        ('1ac9f8e7-8293-4b2c-f364-7f8091ab2345', '90be3d4b-2d2c-5a19-99c7-237140661533', 'e348c5dd-3608-56bf-858f-731cd83a0d1d', N'<separator-comment-block>', N'Visual separator comment block (=== ... ===)'),
        ('2bdae9f8-93a4-4c3d-a475-8091a2bc3456', 'a8f946e2-5dfe-53b2-a1f6-2a17b1760be2', 'ec9bb1cd-b3e3-5dfc-a898-8ff9284ede41', N'<object-existence-guard>', N'IF OBJECT_ID(...) IS NOT NULL guard before DDL'),
        ('3cebfa09-a4b5-4d4e-b586-91a2b3cd4567', 'c1bb3eaf-5b9f-5b45-9602-31d763d065e3', 'de2ef22a-b29e-5a7d-86e6-e398eb709ac0', N'<declare-statement>', N'DECLARE local variable statement'),
        ('4dfc0b1a-b5c6-4e5f-c697-a2b3c4de5678', '1ed55929-f3b3-598c-a970-59ddd9c53d78', 'b6fa55b3-5233-5c5a-90b4-a6433e8a0957', N'<set-variable-statement>', N'SET @variable = value statement'),
        ('5e0d1c2b-c6d7-4f60-d7a8-b3c4d5ef6789', '5845d365-8801-596f-963f-a708b86c9f4f', '1e777fcf-814c-56e0-9918-0b3e139f8b8d', N'<select-from-order-statement>', N'SELECT ... FROM ... ORDER BY statement'),
        ('70a3e4d4-e8f9-4182-f9ca-d5e6f7a14901', '2a4822b7-4327-502d-8ded-d486f87837d1', '9d3c7562-3172-52ee-9dc9-e800e846d444', N'<function-parameter>', N'Scalar parameter declaration in a function or procedure'),
        ('81b4f5e5-f9a0-4293-aadb-e6f7081b5a12', '0e776c1f-52c4-50c1-8cce-350c9e141662', 'cd672278-1bd7-5390-aa21-387103fe8372', N'<returns-table-clause>', N'RETURNS TABLE clause of a multi-statement or inline TVF'),
        ('6f1e2d3c-d7e8-4071-e8b9-c4d5e6f07890', '7e7e306f-55b1-5c6f-8aec-043213b8f08d', '44c4c21a-bd35-51d0-a89f-fc31ae3699c0', N'<create-function-tvf-statement>', N'CREATE FUNCTION ... RETURNS TABLE DDL statement'),
        ('92c5a6f6-0ab1-43a4-bbec-f7081c2c6b23', 'df2373ea-97bf-5c98-bac6-928d0d47dc2b', '3670e42a-9375-5ba5-9333-dbfcd9e2d01b', N'<cte-clause>', N'Common Table Expression (WITH <name> AS (...))'),
        ('a3d6b7e7-1bc2-44b5-ccfd-081d2d3d7c34', '251deb42-31e7-5d9d-8951-41cc6ae3b176', 'f5073e8c-dc57-57f1-97a4-f9d59a38c5fb', N'<insert-into-select-statement>', N'INSERT INTO ... SELECT ... statement'),
        ('b4e7c8f8-2cd3-45c6-ddae-192e3e4e8d45', '70c734ef-3c74-581d-b6f9-f7e2177c0553', 'c2ad3666-74ce-56b8-a0af-9db40e44d0e1', N'<case-when-expression>', N'CASE WHEN ... THEN ... ELSE ... END expression'),
        ('c5f8d9a9-3de4-46d7-eebf-2a3f4f5f9e56', '057ec0db-4432-576a-86d1-fa167b5e1e10', '27e5c178-509c-56b3-b2fb-1d538feb7511', N'<query-hint-clause>', N'OPTION (...) query hint clause'),
        ('091cdecd-7128-4abb-22f3-6e7383939290', 'f7c44f98-b017-5698-b97c-484eba1c797a', 'b062855c-f462-5837-9547-be270b3b332b', N'<return-statement>', N'RETURN [value] statement'),
        ('d6e9eaba-4ef5-47e8-ffc0-3b405060af67', '3b4538c2-6b3d-5b23-b6c5-8710331ff662', 'ddc0bc95-9157-5865-88fe-672f60afba07', N'<create-table-statement>', N'CREATE TABLE DDL statement'),
        ('e7fabcbb-5f06-48f9-00d1-4c5161717078', 'e0e89145-a3a2-5118-863a-cf69b47c11e9', '0f9eae1b-c211-53d4-8d4f-f222e9b7b775', N'<column-definition>', N'Column definition inside CREATE TABLE'),
        ('f80bcdcc-6017-49ea-11e2-5d6272828189', 'd886eb47-bdb4-5243-940b-cc9b280a4387', '004e487b-0df6-57b5-b7b6-1e888a997a5b', N'<inline-table-constraint>', N'Inline or table-level constraint (PK, UQ, FK, DEFAULT, CHECK)');
    DECLARE @RDB500CSQLPrimitivePhiloteId uniqueidentifier,@RDB500CSQLPrimitiveVersionPhiloteId uniqueidentifier,
      @RDB500CSQLInputPhiloteId uniqueidentifier,@RDB500CSQLPrimitiveCode varchar(128),@RDB500CSQLDefinitionText nvarchar(max),
      @RDB500CSQLPrimitiveId bigint,@RDB500CSQLPrimitiveVersionId bigint;
    DECLARE RDB500CSQLPrimitiveCursor CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @RDB500CSQLPrimitives ORDER BY PrimitiveCode;
    OPEN RDB500CSQLPrimitiveCursor;
    FETCH NEXT FROM RDB500CSQLPrimitiveCursor INTO @RDB500CSQLPrimitivePhiloteId,@RDB500CSQLPrimitiveVersionPhiloteId,@RDB500CSQLInputPhiloteId,@RDB500CSQLPrimitiveCode,@RDB500CSQLDefinitionText;
    WHILE @@FETCH_STATUS=0
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500CSQLRuleKindId AND PrimitiveCode=@RDB500CSQLPrimitiveCode)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CSQLPrimitiveTypeId,@RDB500CSQLPrimitivePhiloteId,@RDB500CSQLNow);
        SET @RDB500CSQLEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500CSQLPrimitivePhiloteId,@RDB500CSQLEntityId,@RDB500CSQLPrimitiveTypeId,@RDB500CSQLRuleKindId,@RDB500CSQLPrimitiveCode,@RDB500CSQLNow);
      END;
      IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500CSQLRuleKindId AND PrimitiveCode=@RDB500CSQLPrimitiveCode AND PrimitivePhiloteId<>@RDB500CSQLPrimitivePhiloteId)
        THROW 55504, 'RDB-500C Primitive natural key maps to a different Philote.', 1;
      SELECT @RDB500CSQLPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500CSQLRuleKindId AND PrimitiveCode=@RDB500CSQLPrimitiveCode;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500CSQLPrimitiveId AND RevisionSequence=1)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CSQLPrimitiveVersionTypeId,@RDB500CSQLPrimitiveVersionPhiloteId,@RDB500CSQLNow);
        SET @RDB500CSQLEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,
           PredecessorPrimitiveVersionId,GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,
           DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500CSQLPrimitiveVersionPhiloteId,@RDB500CSQLEntityId,@RDB500CSQLPrimitiveVersionTypeId,@RDB500CSQLPrimitiveId,
          @RDB500CSQLRuleKindId,@RDB500CSQLRuleKindVersionId,1,NULL,@RDB500CSQLPrimitiveCode,@RDB500CSQLDefinitionText,'SHA-256',
          HASHBYTES('SHA2_256',@RDB500CSQLDefinitionText),@RDB500CSQLValueTypeVersionId,1,1,@RDB500CSQLNow);
      END;
      SELECT @RDB500CSQLPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500CSQLPrimitiveId AND RevisionSequence=1;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500CSQLPrimitiveVersionId AND InputCode='content')
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CSQLPrimitiveInputTypeId,@RDB500CSQLInputPhiloteId,@RDB500CSQLNow);
        SET @RDB500CSQLEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,
           ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500CSQLInputPhiloteId,@RDB500CSQLEntityId,@RDB500CSQLPrimitiveInputTypeId,@RDB500CSQLPrimitiveVersionId,
          'content',0,@RDB500CSQLValueTypeVersionId,1,1,0,'non-empty-text');
      END;
      FETCH NEXT FROM RDB500CSQLPrimitiveCursor INTO @RDB500CSQLPrimitivePhiloteId,@RDB500CSQLPrimitiveVersionPhiloteId,@RDB500CSQLInputPhiloteId,@RDB500CSQLPrimitiveCode,@RDB500CSQLDefinitionText;
    END;
    CLOSE RDB500CSQLPrimitiveCursor; DEALLOCATE RDB500CSQLPrimitiveCursor;

    DECLARE @RDB500CSQLRootPrimitiveVersionId bigint,@RDB500CSQLRootPrimitiveInputId bigint;
    SELECT @RDB500CSQLRootPrimitiveVersionId=pv.PrimitiveVersionId,@RDB500CSQLRootPrimitiveInputId=pid.PrimitiveInputDefinitionId
    FROM [ATAPUtilities].[Primitive] p JOIN [ATAPUtilities].[PrimitiveVersion] pv ON pv.PrimitiveId=p.PrimitiveId AND pv.RevisionSequence=1
    JOIN [ATAPUtilities].[PrimitiveInputDefinition] pid ON pid.PrimitiveVersionId=pv.PrimitiveVersionId AND pid.InputCode='content'
    WHERE p.RuleKindId=@RDB500CSQLRuleKindId AND p.PrimitiveCode=N'<sql-script-file>';
    IF @RDB500CSQLRootPrimitiveInputId IS NULL THROW 55505, 'RDB-500C top primitive/input was not materialized.', 1;

    DECLARE @RDB500CSQLRules TABLE(RulePhiloteId uniqueidentifier,RuleVersionPhiloteId uniqueidentifier,
      RuleInputPhiloteId uniqueidentifier,DefaultPhiloteId uniqueidentifier,NodePhiloteId uniqueidentifier,
      RuleCode varchar(128),Purpose nvarchar(max),DefaultValue nvarchar(max),SourceFileReference nvarchar(2048));
    INSERT @RDB500CSQLRules VALUES
        ('7a1b2c3d-4e5f-4061-8273-a4b5c6d7e8f9', 'fc85870a-c479-5219-bfc1-38e58fd0b558', 'bc86785d-67bf-513d-99d1-b3250096c0c2', '04f0772a-036f-5402-ae12-3c6b17a9d10e', 'd28ab64e-f33b-548b-943f-3a7de7d8edbe', N'Test_udf_dateperiod', N'Generate a runnable T-SQL query script that exercises the dbo.udf_dateperiod table-valued function.', N'src/ATAP.Utilities.Philote/Database/Queries/Test_udf_dateperiod.sql', N'src/ATAP.Utilities.Philote/Database/Queries/Test_udf_dateperiod.sql'),
        ('8b2c3d4e-5f60-4172-9384-b5c6d7e8f9a0', '398b40c3-a4ba-5af0-a3de-b72e7b4760b7', '68bdf977-5dc0-548e-b66a-9a1f785dfa2a', 'c846158e-3d20-5f22-8c34-a350434b1a27', '7cd9675c-6dc5-5ed7-8d57-dc2edd3ed10e', N'Create_udf_dateperiod', N'Generate the DDL script that conditionally drops then creates the [dbo].[udf_dateperiod] multi-statement table-valued function.', N'src/ATAP.Utilities.Philote/Database/Queries/Create_udf_dateperiod.sql', N'src/ATAP.Utilities.Philote/Database/Queries/Create_udf_dateperiod.sql'),
        ('9c3d4e5f-60a1-4283-a495-c6d7e8f9b0a1', 'db057f63-b7dc-5ee0-9ee6-824703c213ff', '0b713d7f-4b49-5de3-8aee-38a9de959ae1', 'b99e97ba-98b4-5fd4-ba0a-7632c7f863bf', 'de32f12c-ddb1-5b20-9944-746b50ba59a9', N'V00.01.000010__Create_Philote_Core_Schema', N'Generate the Flyway versioned migration script for the Philote core schema.', N'src/ATAP.Utilities.Philote/Database/Flyway/DATA/V00.01.000010__Create_Philote_Core_Schema.sql', N'src/ATAP.Utilities.Philote/Database/Flyway/DATA/V00.01.000010__Create_Philote_Core_Schema.sql');
    DECLARE @RDB500CSQLRulePhiloteId uniqueidentifier,@RDB500CSQLRuleVersionPhiloteId uniqueidentifier,
      @RDB500CSQLRuleInputPhiloteId uniqueidentifier,@RDB500CSQLDefaultPhiloteId uniqueidentifier,@RDB500CSQLNodePhiloteId uniqueidentifier,
      @RDB500CSQLRuleCode varchar(128),@RDB500CSQLPurpose nvarchar(max),@RDB500CSQLDefaultValue nvarchar(max),@RDB500CSQLSourceFileReference nvarchar(2048),
      @RDB500CSQLRuleId bigint,@RDB500CSQLRuleVersionId bigint,@RDB500CSQLRuleInputId bigint,@RDB500CSQLNodeId bigint;
    DECLARE RDB500CSQLRuleCursor CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @RDB500CSQLRules ORDER BY RuleCode;
    OPEN RDB500CSQLRuleCursor;
    FETCH NEXT FROM RDB500CSQLRuleCursor INTO @RDB500CSQLRulePhiloteId,@RDB500CSQLRuleVersionPhiloteId,@RDB500CSQLRuleInputPhiloteId,@RDB500CSQLDefaultPhiloteId,@RDB500CSQLNodePhiloteId,@RDB500CSQLRuleCode,@RDB500CSQLPurpose,@RDB500CSQLDefaultValue,@RDB500CSQLSourceFileReference;
    WHILE @@FETCH_STATUS=0
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500CSQLRuleKindId AND RuleCode=@RDB500CSQLRuleCode)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CSQLRuleTypeId,@RDB500CSQLRulePhiloteId,@RDB500CSQLNow);
        SET @RDB500CSQLEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Rule](RulePhiloteId,EntityId,EntityTypeId,RuleKindId,RuleCode,CreatedAtUtc)
        VALUES(@RDB500CSQLRulePhiloteId,@RDB500CSQLEntityId,@RDB500CSQLRuleTypeId,@RDB500CSQLRuleKindId,@RDB500CSQLRuleCode,@RDB500CSQLNow);
      END;
      IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500CSQLRuleKindId AND RuleCode=@RDB500CSQLRuleCode AND RulePhiloteId<>@RDB500CSQLRulePhiloteId)
        THROW 55506, 'RDB-500C Rule natural key maps to a different Philote.', 1;
      SELECT @RDB500CSQLRuleId=RuleId FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500CSQLRuleKindId AND RuleCode=@RDB500CSQLRuleCode;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500CSQLRuleId AND RevisionSequence=1)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CSQLRuleVersionTypeId,@RDB500CSQLRuleVersionPhiloteId,@RDB500CSQLNow);
        SET @RDB500CSQLEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleVersion]
          (RuleVersionPhiloteId,EntityId,EntityTypeId,RuleId,RuleKindId,RuleKindVersionId,RevisionSequence,
           PredecessorRuleVersionId,CompositionHashAlgorithmCode,CompositionContentHash,PublishedAtUtc)
        VALUES(@RDB500CSQLRuleVersionPhiloteId,@RDB500CSQLEntityId,@RDB500CSQLRuleVersionTypeId,@RDB500CSQLRuleId,@RDB500CSQLRuleKindId,
          @RDB500CSQLRuleKindVersionId,1,NULL,'SHA-256',HASHBYTES('SHA2_256',CONCAT(@RDB500CSQLRuleCode,N'|',@RDB500CSQLPurpose,N'|',@RDB500CSQLSourceFileReference)),@RDB500CSQLNow);
      END;
      SELECT @RDB500CSQLRuleVersionId=RuleVersionId FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500CSQLRuleId AND RevisionSequence=1;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500CSQLRuleVersionId AND InputCode='content')
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CSQLRuleInputTypeId,@RDB500CSQLRuleInputPhiloteId,@RDB500CSQLNow);
        SET @RDB500CSQLEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleInputDefinition]
          (RuleInputDefinitionPhiloteId,EntityId,EntityTypeId,RuleVersionId,InputCode,Ordinal,ValueTypeVersionId,
           MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500CSQLRuleInputPhiloteId,@RDB500CSQLEntityId,@RDB500CSQLRuleInputTypeId,@RDB500CSQLRuleVersionId,
          'content',0,@RDB500CSQLValueTypeVersionId,1,1,0,'non-empty-text');
      END;
      SELECT @RDB500CSQLRuleInputId=RuleInputDefinitionId FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500CSQLRuleVersionId AND InputCode='content';
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleDefaultInputValue] WHERE RuleInputDefinitionId=@RDB500CSQLRuleInputId)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CSQLRuleDefaultTypeId,@RDB500CSQLDefaultPhiloteId,@RDB500CSQLNow);
        SET @RDB500CSQLEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleDefaultInputValue]
          (RuleDefaultInputValuePhiloteId,EntityId,EntityTypeId,RuleInputDefinitionId,RuleVersionId,ValueTypeVersionId,
           CanonicalTextValue,CanonicalValueHash,RationaleEntityId,RationaleEntityTypeId,PublishedAtUtc)
        VALUES(@RDB500CSQLDefaultPhiloteId,@RDB500CSQLEntityId,@RDB500CSQLRuleDefaultTypeId,@RDB500CSQLRuleInputId,@RDB500CSQLRuleVersionId,
          @RDB500CSQLValueTypeVersionId,@RDB500CSQLDefaultValue,HASHBYTES('SHA2_256',@RDB500CSQLDefaultValue),
          (SELECT EntityId FROM [ATAPUtilities].[Rule] WHERE RuleId=@RDB500CSQLRuleId),@RDB500CSQLRuleTypeId,@RDB500CSQLNow);
      END;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId=@RDB500CSQLNodePhiloteId)
        INSERT [ATAPUtilities].[RuleVersionNode]
          (RuleVersionNodePhiloteId,RuleVersionId,RuleKindVersionId,ParentRuleVersionNodeId,Ordinal,PrimitiveVersionId,
           MinOccurs,MaxOccurs,ChoiceDiscriminatorCode,NodeLabel)
        VALUES(@RDB500CSQLNodePhiloteId,@RDB500CSQLRuleVersionId,@RDB500CSQLRuleKindVersionId,NULL,0,@RDB500CSQLRootPrimitiveVersionId,1,1,NULL,N'root');
      SELECT @RDB500CSQLNodeId=RuleVersionNodeId FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId=@RDB500CSQLNodePhiloteId;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNodeInput] WHERE RuleVersionNodeId=@RDB500CSQLNodeId AND PrimitiveInputDefinitionId=@RDB500CSQLRootPrimitiveInputId)
        INSERT [ATAPUtilities].[RuleVersionNodeInput]
          (RuleVersionNodeId,RuleVersionId,PrimitiveVersionId,PrimitiveInputDefinitionId,BindingShapeCode,
           TargetValueTypeVersionId,SourceValueTypeVersionId,ConstantValueTypeVersionId,RuleInputDefinitionId,
           DerivationContractVersionId,ConversionPolicyCode,CanonicalTextValue,CanonicalValueHash)
        VALUES(@RDB500CSQLNodeId,@RDB500CSQLRuleVersionId,@RDB500CSQLRootPrimitiveVersionId,@RDB500CSQLRootPrimitiveInputId,
          'constant',@RDB500CSQLValueTypeVersionId,NULL,@RDB500CSQLValueTypeVersionId,NULL,NULL,NULL,@RDB500CSQLDefaultValue,
          HASHBYTES('SHA2_256',@RDB500CSQLDefaultValue));
      FETCH NEXT FROM RDB500CSQLRuleCursor INTO @RDB500CSQLRulePhiloteId,@RDB500CSQLRuleVersionPhiloteId,@RDB500CSQLRuleInputPhiloteId,@RDB500CSQLDefaultPhiloteId,@RDB500CSQLNodePhiloteId,@RDB500CSQLRuleCode,@RDB500CSQLPurpose,@RDB500CSQLDefaultValue,@RDB500CSQLSourceFileReference;
    END;
    CLOSE RDB500CSQLRuleCursor; DEALLOCATE RDB500CSQLRuleCursor;

    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500CSQLRuleKindId) < 23
      THROW 55507, 'RDB-500C primitive row-count postcondition failed.', 1;
    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500CSQLRuleKindId) < 3
      THROW 55508, 'RDB-500C rule row-count postcondition failed.', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','RDB500CSQLPrimitiveCursor') >= -1 BEGIN CLOSE RDB500CSQLPrimitiveCursor; DEALLOCATE RDB500CSQLPrimitiveCursor; END;
    IF CURSOR_STATUS('local','RDB500CSQLRuleCursor') >= -1 BEGIN CLOSE RDB500CSQLRuleCursor; DEALLOCATE RDB500CSQLRuleCursor; END;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

/* RDB-500C / MSBuild reference seed.
   Positive: A MSBuild rule with a non-empty repository-relative source reference.
   Negative (declarative; exercised by RDB-510): A MSBuild rule with an empty content input or a cross-kind primitive version.
   Integration prerequisites are coordinator-owned and fail closed below. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @RDB500CMSBuildNow datetime2(7) = CONVERT(datetime2(7), '2026-08-06T00:00:00.0000000Z', 127);
DECLARE @RDB500CMSBuildGrammarSourceArtifactVersionId bigint;
DECLARE @RDB500CMSBuildCompendiumSourceArtifactVersionId bigint;
SELECT @RDB500CMSBuildGrammarSourceArtifactVersionId = sav.SourceArtifactVersionId
FROM [ATAPUtilities].[SourceArtifact] sa
JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId = sa.SourceArtifactId
WHERE sa.LocatorTypeCode = 'RepositoryPath'
  AND sa.RepoRelativePathOrExternalLocator = N'SolutionDocumentation/grammers/MSBuild.grammar.ebnf'
  AND sav.NormalizedContentSha256 = 'c2ca634b02d8d36995adbd7910d3c4409602a8fdf59051edb509854f127fb907';
SELECT @RDB500CMSBuildCompendiumSourceArtifactVersionId = sav.SourceArtifactVersionId
FROM [ATAPUtilities].[SourceArtifact] sa
JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId = sa.SourceArtifactId
WHERE sa.LocatorTypeCode = 'RepositoryPath'
  AND sa.RepoRelativePathOrExternalLocator = N'SolutionDocumentation/Rules Compendium.MSBuild.md'
  AND sav.NormalizedContentSha256 = 'b89efd6626a54e8af8ce7d14390d2f639d963b1da718212ed8d22bdd43a8487e';
IF @RDB500CMSBuildGrammarSourceArtifactVersionId IS NULL OR @RDB500CMSBuildCompendiumSourceArtifactVersionId IS NULL
    THROW 55500, 'RDB-500C requires exact grammar and compendium SourceArtifactVersion rows.', 1;

DECLARE @RDB500CMSBuildRuleKindTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind');
DECLARE @RDB500CMSBuildRuleKindVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind-version');
DECLARE @RDB500CMSBuildValueTypeTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type');
DECLARE @RDB500CMSBuildValueTypeVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type-version');
DECLARE @RDB500CMSBuildPrimitiveTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive');
DECLARE @RDB500CMSBuildPrimitiveVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-version');
DECLARE @RDB500CMSBuildPrimitiveInputTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-input-definition');
DECLARE @RDB500CMSBuildRuleTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule');
DECLARE @RDB500CMSBuildRuleVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-version');
DECLARE @RDB500CMSBuildRuleInputTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-input-definition');
DECLARE @RDB500CMSBuildRuleDefaultTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-default-input-value');
IF @RDB500CMSBuildRuleKindTypeId IS NULL OR @RDB500CMSBuildRuleDefaultTypeId IS NULL
    THROW 55501, 'RDB-500C requires the frozen RDB-320 EntityType catalog.', 1;
IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ExecutionClassification] WHERE ExecutionClassificationCode='metadata-only' AND AllowsExecutorContract=0)
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[SecurityCapabilityClassification] WHERE SecurityCapabilityCode='reference-safe')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RoundTripPolicy] WHERE RoundTripPolicyCode='byte-identical')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ScalarStorageKind] WHERE ScalarStorageKindCode='bounded-unicode-text')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[BindingShape] WHERE BindingShapeCode='constant')
    THROW 55502, 'RDB-500C requires coordinator-owned closed catalog rows.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @RDB500CMSBuildEntityId bigint;
    DECLARE @RDB500CMSBuildRuleKindId bigint;
    DECLARE @RDB500CMSBuildRuleKindVersionId bigint;
    DECLARE @RDB500CMSBuildValueTypeId bigint;
    DECLARE @RDB500CMSBuildValueTypeVersionId bigint;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'MSBuild')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CMSBuildRuleKindTypeId,'b298f73e-80ac-52cb-8ec9-7acc65c66469',@RDB500CMSBuildNow);
        SET @RDB500CMSBuildEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleKind](RuleKindPhiloteId,EntityId,EntityTypeId,RuleKindCode,CreatedAtUtc)
        VALUES('b298f73e-80ac-52cb-8ec9-7acc65c66469',@RDB500CMSBuildEntityId,@RDB500CMSBuildRuleKindTypeId,N'MSBuild',@RDB500CMSBuildNow);
    END;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'MSBuild' AND RuleKindPhiloteId<>'b298f73e-80ac-52cb-8ec9-7acc65c66469')
        THROW 55503, 'RDB-500C RuleKind natural key maps to a different Philote.', 1;
    SELECT @RDB500CMSBuildRuleKindId=RuleKindId FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'MSBuild';

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500CMSBuildRuleKindId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CMSBuildRuleKindVersionTypeId,'41d11157-1c94-56cf-9a3d-f2565326d194',@RDB500CMSBuildNow);
        SET @RDB500CMSBuildEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleKindVersion]
          (RuleKindVersionPhiloteId,EntityId,EntityTypeId,RuleKindId,RevisionSequence,PredecessorRuleKindVersionId,
           GrammarSourceArtifactVersionId,GrammarHashAlgorithmCode,GrammarContentHash,CompendiumSourceArtifactVersionId,
           CompendiumHashAlgorithmCode,CompendiumContentHash,ExecutorContractVersionId,ExecutionClassificationCode,
           SecurityCapabilityCode,RoundTripPolicyCode,PublishedAtUtc)
        VALUES('41d11157-1c94-56cf-9a3d-f2565326d194',@RDB500CMSBuildEntityId,@RDB500CMSBuildRuleKindVersionTypeId,@RDB500CMSBuildRuleKindId,1,NULL,
          @RDB500CMSBuildGrammarSourceArtifactVersionId,'SHA-256',0xc2ca634b02d8d36995adbd7910d3c4409602a8fdf59051edb509854f127fb907,@RDB500CMSBuildCompendiumSourceArtifactVersionId,
          'SHA-256',0xb89efd6626a54e8af8ce7d14390d2f639d963b1da718212ed8d22bdd43a8487e,NULL,'metadata-only','reference-safe','byte-identical',@RDB500CMSBuildNow);
    END;
    SELECT @RDB500CMSBuildRuleKindVersionId=RuleKindVersionId FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500CMSBuildRuleKindId AND RevisionSequence=1;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-msbuild-text')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CMSBuildValueTypeTypeId,'90add015-7dbc-5cd5-8093-552d44b89437',@RDB500CMSBuildNow);
        SET @RDB500CMSBuildEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[ValueType](ValueTypePhiloteId,EntityId,EntityTypeId,ValueTypeCode,CreatedAtUtc)
        VALUES('90add015-7dbc-5cd5-8093-552d44b89437',@RDB500CMSBuildEntityId,@RDB500CMSBuildValueTypeTypeId,'seed-msbuild-text',@RDB500CMSBuildNow);
    END;
    SELECT @RDB500CMSBuildValueTypeId=ValueTypeId FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-msbuild-text';
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500CMSBuildValueTypeId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CMSBuildValueTypeVersionTypeId,'538dc2d0-9bd4-5f1e-a073-74e4a16dcf7a',@RDB500CMSBuildNow);
        SET @RDB500CMSBuildEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[ValueTypeVersion]
          (ValueTypeVersionPhiloteId,EntityId,EntityTypeId,ValueTypeId,RevisionSequence,PredecessorValueTypeVersionId,
           ValueCategoryCode,ScalarStorageKindCode,StructuredValueContractVersionId,ElementValueTypeVersionId,
           CollectionOrderingCode,SecretReferencePolicyId,ValidationContractCode,PublishedAtUtc)
        VALUES('538dc2d0-9bd4-5f1e-a073-74e4a16dcf7a',@RDB500CMSBuildEntityId,@RDB500CMSBuildValueTypeVersionTypeId,@RDB500CMSBuildValueTypeId,1,NULL,
          'scalar','bounded-unicode-text',NULL,NULL,NULL,NULL,'non-empty-text',@RDB500CMSBuildNow);
    END;
    SELECT @RDB500CMSBuildValueTypeVersionId=ValueTypeVersionId FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500CMSBuildValueTypeId AND RevisionSequence=1;

    DECLARE @RDB500CMSBuildPrimitives TABLE(PrimitivePhiloteId uniqueidentifier,PrimitiveVersionPhiloteId uniqueidentifier,
      InputPhiloteId uniqueidentifier,PrimitiveCode varchar(128),DefinitionText nvarchar(max));
    INSERT @RDB500CMSBuildPrimitives VALUES
        ('f0c6f7bf-0a91-402c-8d0a-0e9d828b1b4d', '1dce820e-4a96-526b-8dbc-19d024b2f253', 'f51c1431-9218-56ef-9155-f9a426f6e821', N'<csproj-file>', N'Root project document with Sdk attribute and child groups'),
        ('5f8f4a2d-5c8a-4f71-8b27-7ff6a72f5f1c', '27815cb0-6975-59a0-b4a4-ff798f0faea0', '981e2896-24e1-5d42-8761-c8d869644d9b', N'<property-group>', N'Groups properties under <PropertyGroup>'),
        ('f5e6df38-0c63-4b3c-8a53-72d5f6ad2962', '2f380f1f-1407-5858-b702-0249829b59a0', 'c78cedee-4097-5055-a138-7969d1bacdd4', N'<property>', N'A single MSBuild property element'),
        ('b87e6f6c-9f2c-4e4c-9f54-2da53a46c7f6', '167c8993-6258-5100-b84c-dc2b67bdac6f', '235fdcf4-d332-5fac-84fb-2c99719cb0e9', N'<item-group>', N'Groups item declarations (references, analyzers, etc.)'),
        ('6a4c6e4e-5035-4c74-9d08-47e0a5b6c17e', 'e5d378be-10d2-5926-86bb-e19f60782279', '89e6a96f-7199-5f22-a67a-616fe979cf85', N'<project-reference>', N'Reference to another project'),
        ('bc63c4a9-e2ab-4e6f-83b6-8f8a5f09341a', 'a1f1196a-9627-593f-b3b4-8d6ecd73f6a2', 'f1e63dca-4438-5845-89d7-b01acf228c89', N'<package-reference>', N'NuGet package reference'),
        ('0d7df833-9bdb-4f4b-a2c8-9e27863cfe26', '0e2f69aa-709b-54c8-8b1c-a4f7ed5e225a', 'cdccaa1f-0f2c-54d0-97b5-ed7195d3ca20', N'<xml-comment>', N'XML comment node'),
        ('5c4b6d7a-3f5d-4a8d-90d6-0f3cf0f9b6aa', '6552ac1e-7e45-5c48-acd1-0209f64e4291', '46ec47e0-3000-5b22-aa65-dab869855f85', N'<compile-remove>', N'Removes files from the Compile item set via Remove="glob"');
    DECLARE @RDB500CMSBuildPrimitivePhiloteId uniqueidentifier,@RDB500CMSBuildPrimitiveVersionPhiloteId uniqueidentifier,
      @RDB500CMSBuildInputPhiloteId uniqueidentifier,@RDB500CMSBuildPrimitiveCode varchar(128),@RDB500CMSBuildDefinitionText nvarchar(max),
      @RDB500CMSBuildPrimitiveId bigint,@RDB500CMSBuildPrimitiveVersionId bigint;
    DECLARE RDB500CMSBuildPrimitiveCursor CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @RDB500CMSBuildPrimitives ORDER BY PrimitiveCode;
    OPEN RDB500CMSBuildPrimitiveCursor;
    FETCH NEXT FROM RDB500CMSBuildPrimitiveCursor INTO @RDB500CMSBuildPrimitivePhiloteId,@RDB500CMSBuildPrimitiveVersionPhiloteId,@RDB500CMSBuildInputPhiloteId,@RDB500CMSBuildPrimitiveCode,@RDB500CMSBuildDefinitionText;
    WHILE @@FETCH_STATUS=0
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500CMSBuildRuleKindId AND PrimitiveCode=@RDB500CMSBuildPrimitiveCode)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CMSBuildPrimitiveTypeId,@RDB500CMSBuildPrimitivePhiloteId,@RDB500CMSBuildNow);
        SET @RDB500CMSBuildEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500CMSBuildPrimitivePhiloteId,@RDB500CMSBuildEntityId,@RDB500CMSBuildPrimitiveTypeId,@RDB500CMSBuildRuleKindId,@RDB500CMSBuildPrimitiveCode,@RDB500CMSBuildNow);
      END;
      IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500CMSBuildRuleKindId AND PrimitiveCode=@RDB500CMSBuildPrimitiveCode AND PrimitivePhiloteId<>@RDB500CMSBuildPrimitivePhiloteId)
        THROW 55504, 'RDB-500C Primitive natural key maps to a different Philote.', 1;
      SELECT @RDB500CMSBuildPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500CMSBuildRuleKindId AND PrimitiveCode=@RDB500CMSBuildPrimitiveCode;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500CMSBuildPrimitiveId AND RevisionSequence=1)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CMSBuildPrimitiveVersionTypeId,@RDB500CMSBuildPrimitiveVersionPhiloteId,@RDB500CMSBuildNow);
        SET @RDB500CMSBuildEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,
           PredecessorPrimitiveVersionId,GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,
           DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500CMSBuildPrimitiveVersionPhiloteId,@RDB500CMSBuildEntityId,@RDB500CMSBuildPrimitiveVersionTypeId,@RDB500CMSBuildPrimitiveId,
          @RDB500CMSBuildRuleKindId,@RDB500CMSBuildRuleKindVersionId,1,NULL,@RDB500CMSBuildPrimitiveCode,@RDB500CMSBuildDefinitionText,'SHA-256',
          HASHBYTES('SHA2_256',@RDB500CMSBuildDefinitionText),@RDB500CMSBuildValueTypeVersionId,1,1,@RDB500CMSBuildNow);
      END;
      SELECT @RDB500CMSBuildPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500CMSBuildPrimitiveId AND RevisionSequence=1;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500CMSBuildPrimitiveVersionId AND InputCode='content')
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CMSBuildPrimitiveInputTypeId,@RDB500CMSBuildInputPhiloteId,@RDB500CMSBuildNow);
        SET @RDB500CMSBuildEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,
           ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500CMSBuildInputPhiloteId,@RDB500CMSBuildEntityId,@RDB500CMSBuildPrimitiveInputTypeId,@RDB500CMSBuildPrimitiveVersionId,
          'content',0,@RDB500CMSBuildValueTypeVersionId,1,1,0,'non-empty-text');
      END;
      FETCH NEXT FROM RDB500CMSBuildPrimitiveCursor INTO @RDB500CMSBuildPrimitivePhiloteId,@RDB500CMSBuildPrimitiveVersionPhiloteId,@RDB500CMSBuildInputPhiloteId,@RDB500CMSBuildPrimitiveCode,@RDB500CMSBuildDefinitionText;
    END;
    CLOSE RDB500CMSBuildPrimitiveCursor; DEALLOCATE RDB500CMSBuildPrimitiveCursor;

    DECLARE @RDB500CMSBuildRootPrimitiveVersionId bigint,@RDB500CMSBuildRootPrimitiveInputId bigint;
    SELECT @RDB500CMSBuildRootPrimitiveVersionId=pv.PrimitiveVersionId,@RDB500CMSBuildRootPrimitiveInputId=pid.PrimitiveInputDefinitionId
    FROM [ATAPUtilities].[Primitive] p JOIN [ATAPUtilities].[PrimitiveVersion] pv ON pv.PrimitiveId=p.PrimitiveId AND pv.RevisionSequence=1
    JOIN [ATAPUtilities].[PrimitiveInputDefinition] pid ON pid.PrimitiveVersionId=pv.PrimitiveVersionId AND pid.InputCode='content'
    WHERE p.RuleKindId=@RDB500CMSBuildRuleKindId AND p.PrimitiveCode=N'<csproj-file>';
    IF @RDB500CMSBuildRootPrimitiveInputId IS NULL THROW 55505, 'RDB-500C top primitive/input was not materialized.', 1;

    DECLARE @RDB500CMSBuildRules TABLE(RulePhiloteId uniqueidentifier,RuleVersionPhiloteId uniqueidentifier,
      RuleInputPhiloteId uniqueidentifier,DefaultPhiloteId uniqueidentifier,NodePhiloteId uniqueidentifier,
      RuleCode varchar(128),Purpose nvarchar(max),DefaultValue nvarchar(max),SourceFileReference nvarchar(2048));
    INSERT @RDB500CMSBuildRules VALUES
        ('2f8b8c1b-3e25-44a0-9c6d-6b2f9f3f5e6c', '927cdf3f-27b0-5f66-9fbe-b75bdec83a44', '790c4d47-dbc1-57bd-8ec6-5343f5276c36', '9927bba6-36f1-5486-b3e2-0d83a59c29af', 'a944c182-d098-513e-909f-8246e895524d', N'ATAP.Utilities.StronglyTypedIds.Interfaces.csproj', N'Render the project file for the StronglyTypedIds interfaces library.', N'src/ATAP.Utilities.StronglyTypedIds.Interfaces/ATAP.Utilities.StronglyTypedIds.Interfaces.csproj', N'src/ATAP.Utilities.StronglyTypedIds.Interfaces/ATAP.Utilities.StronglyTypedIds.Interfaces.csproj'),
        ('8d6a0bf9-4ed6-4a4d-8e9d-7f1f0cfad3e3', '422c48e2-813a-537d-bead-0fa4deb32568', '15516549-5d13-5c1a-bd8a-07c69e596659', '65f7c96d-2455-5a66-8f0d-5f225fbe26bd', '7e556f32-5baf-574e-ab66-5c62f4a0b7c7', N'ATAP.Utilities.StronglyTypedIds.csproj', N'Render the StronglyTypedIds implementation project.', N'src/ATAP.Utilities.StronglyTypedIds/ATAP.Utilities.StronglyTypedIds.csproj', N'src/ATAP.Utilities.StronglyTypedIds/ATAP.Utilities.StronglyTypedIds.csproj'),
        ('12df4c1d-7f30-4a3c-b0fd-83f6de6a2c38', '9a7fe073-8110-5c72-b87b-b62bb0c4ed97', '9f04b28d-a876-561b-b947-0b215f21e6f0', 'f0113642-9cfa-552e-94c7-2786d5fe830f', '0fe69d37-59f9-5ee1-9f10-46410fad7292', N'ATAP.Utilities.Philote.Interfaces.csproj', N'Render the Philote interfaces project.', N'src/ATAP.Utilities.Philote.Interfaces/ATAP.Utilities.Philote.Interfaces.csproj', N'src/ATAP.Utilities.Philote.Interfaces/ATAP.Utilities.Philote.Interfaces.csproj'),
        ('6c7dbe32-3c6a-4ea8-bc10-5a1b1d0584db', '8e3a17e2-9290-5711-b06d-32e7bcfe560e', '2c352e02-8b46-54b7-bc76-3376134f9c96', '2c3f36c8-e188-59a0-8911-95e75fddafab', '9b179408-55dc-54b4-9ff4-8b5c8f0a2b14', N'ATAP.Utilities.Philote.csproj', N'Render the Philote implementation project with package and project references.', N'src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/ATAP.Utilities.Philote.csproj', N'src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/ATAP.Utilities.Philote.csproj'),
        ('1c8b8c57-0d64-4e4a-8e60-5f8a3f7f7d3a', 'de783978-7208-5714-917b-78a196c73761', 'a49abcdb-266c-5048-8950-a5047d644ff0', '3d7fdc33-86ce-5595-9362-dc48e64887cb', '63297636-3dc2-5c25-96ff-30442f2ed172', N'ATAP.Utilities.StronglyTypedId.csproj (aggregator)', N'Aggregate child StronglyTypedId projects without compiling their sources.', N'src/ATAP.Utilities.StronglyTypedId/ATAP.Utilities.StronglyTypedId.csproj', N'src/ATAP.Utilities.StronglyTypedId/ATAP.Utilities.StronglyTypedId.csproj'),
        ('54bfa6f5-7be2-4a5b-94a4-3f4c2b5e6a1d', 'f7b40fef-34da-5de8-855e-da50b79031dd', 'ae22424b-88b9-5c8c-94fe-44c5e24b0576', 'd0e1f9d7-9e1f-5386-9207-50f862cfe716', 'bf3e7d0b-65fe-5adb-be0a-e3e2c9bf2793', N'ATAP.Utilities.StronglyTypedId.Interfaces.csproj', N'Interfaces project for StronglyTypedId.', N'src/ATAP.Utilities.StronglyTypedId/Interfaces/ATAP.Utilities.StronglyTypedId.Interfaces.csproj', N'src/ATAP.Utilities.StronglyTypedId/Interfaces/ATAP.Utilities.StronglyTypedId.Interfaces.csproj'),
        ('c2cbb8dd-2a7a-4c2e-9e31-3bc8d2db1f44', '9e3f546b-eb5a-5578-b81d-0c804f3c7191', '2e4f552d-ac7a-53b1-936e-128c44ad32e6', '19e52ac5-e602-5576-8a85-9e749ba44385', '4a8e8e6c-9f4c-51e2-b31d-423acc2a0d46', N'ATAP.Utilities.StronglyTypedId.Models.csproj', N'Models project for StronglyTypedId.', N'src/ATAP.Utilities.StronglyTypedId/Models/ATAP.Utilities.StronglyTypedId.Models.csproj', N'src/ATAP.Utilities.StronglyTypedId/Models/ATAP.Utilities.StronglyTypedId.Models.csproj'),
        ('9f4b5a1c-2d71-4d8c-87d2-7d7ab6e9c2c1', '5842c292-c4e7-52b9-bb7d-491c0e979acc', '29f345b2-5d20-535a-a6ab-e8215492fbf1', '91c89d26-6fda-5b0b-89ea-8c1f7985560b', '86134fd1-9d6d-5d55-90f8-84409da74550', N'ATAP.Utilities.StronglyTypedId.JsonConverter.Shim.SystemTextJson.csproj', N'System.Text.Json shim converters for StronglyTypedId.', N'src/ATAP.Utilities.StronglyTypedId/JsonConverter.Shim.SystemTextJson/ATAP.Utilities.StronglyTypedId.JsonConverter.Shim.SystemTextJson.csproj', N'src/ATAP.Utilities.StronglyTypedId/JsonConverter.Shim.SystemTextJson/ATAP.Utilities.StronglyTypedId.JsonConverter.Shim.SystemTextJson.csproj'),
        ('f5a4f28a-2f21-4d0c-9939-6a9d5e6b7c3f', 'b8b63b6b-b2ab-5194-b16c-03dfb47b992c', '55f42d56-5430-58b1-a8e7-0197276c563e', 'c3a94e6d-f912-50a9-a56c-c2803f5954a5', '495cecf5-245c-58f5-add6-1b4f56913d54', N'ATAP.Utilities.Philote.csproj (aggregator)', N'Aggregate Philote child projects.', N'src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.csproj', N'src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.csproj'),
        ('7a3f1d5c-9c14-4df5-8a6b-3f1a4b2c7d9e', '6fdde7dd-c682-5dfb-820e-fd49ea4fba19', '913b7c21-d862-5bb6-a1da-0a24877927d4', 'd40d0f57-d0a0-519c-92af-c35b19f001a5', '14487344-cebb-5123-b00c-4b4363903a07', N'ATAP.Utilities.Philote.DefaultConfiguration.csproj', N'Default configuration project for Philote.', N'src/ATAP.Utilities.Philote/DefaultConfiguration/ATAP.Utilities.Philote.DefaultConfiguration.csproj', N'src/ATAP.Utilities.Philote/DefaultConfiguration/ATAP.Utilities.Philote.DefaultConfiguration.csproj'),
        ('f6b8c8d2-9c91-4a1c-9f5e-2e7b5c2d6a1f', 'a1f39fa6-0203-54d0-81e8-a46b771bd862', '4d3e18de-93d0-5d17-bdae-e706eb76d5c7', 'c6cea403-008f-590e-96f8-1088e59d1915', '4a215207-300d-5669-ad05-d7c7c8fb9f88', N'ATAP.Utilities.Philote.Models.csproj', N'Models project for Philote.', N'src/ATAP.Utilities.Philote/Models/ATAP.Utilities.Philote.Models.csproj', N'src/ATAP.Utilities.Philote/Models/ATAP.Utilities.Philote.Models.csproj'),
        ('2a5d8b1c-7e6f-4c0b-b2d4-9b2c5e1d7f4a', '0c615fcd-a994-5699-9862-12944ccb34e9', '709628cc-63a4-5933-bf1e-11c3a868e636', 'f7a103c2-84c0-5739-8169-d85c4166e9e5', 'a376052e-f468-518c-8cbb-c210a9f053c5', N'ATAP.Utilities.Philote.Interfaces.csproj (sub-folder)', N'Interfaces project for Philote.', N'src/ATAP.Utilities.Philote/Interfaces/ATAP.Utilities.Philote.Interfaces.csproj', N'src/ATAP.Utilities.Philote/Interfaces/ATAP.Utilities.Philote.Interfaces.csproj'),
        ('4f6c9e5d-1b62-4a42-8a8c-7e4f3c6a9d1e', '275a14b3-3773-5f0f-a433-65fbba552714', '8c098f10-1b3a-5d81-b2c2-f3dc224df66b', '20110ed9-7aac-5a2d-baf8-53911df7be96', '96f59a83-cf89-56f9-be2b-2b2e9c199eb9', N'ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson.csproj', N'System.Text.Json shim converters for Philote.', N'src/ATAP.Utilities.Philote/JsonConverter.Shim.SystemTextJson/ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson.csproj', N'src/ATAP.Utilities.Philote/JsonConverter.Shim.SystemTextJson/ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson.csproj'),
        ('b5c9d7f1-1c8f-4d1e-8bba-2f7b2e6d5a10', '0812c902-3470-56f7-afd3-9208b6e38c6d', '9a0b8d00-14b1-5fc8-8091-9aa09dfc70e3', '19a7957d-4d9c-5439-bb14-2a4c16df0906', 'f3e55e74-07a6-5b4d-b954-3ff9e162bb1b', N'ATAP.Utilities.Philote.Converters.Interfaces.csproj', N'Converter interfaces for Philote serializers.', N'src/ATAP.Utilities.Philote/Converters.Interfaces.Save/ATAP.Utilities.Philote.Converters.Interfaces.csproj', N'src/ATAP.Utilities.Philote/Converters.Interfaces.Save/ATAP.Utilities.Philote.Converters.Interfaces.csproj');
    DECLARE @RDB500CMSBuildRulePhiloteId uniqueidentifier,@RDB500CMSBuildRuleVersionPhiloteId uniqueidentifier,
      @RDB500CMSBuildRuleInputPhiloteId uniqueidentifier,@RDB500CMSBuildDefaultPhiloteId uniqueidentifier,@RDB500CMSBuildNodePhiloteId uniqueidentifier,
      @RDB500CMSBuildRuleCode varchar(128),@RDB500CMSBuildPurpose nvarchar(max),@RDB500CMSBuildDefaultValue nvarchar(max),@RDB500CMSBuildSourceFileReference nvarchar(2048),
      @RDB500CMSBuildRuleId bigint,@RDB500CMSBuildRuleVersionId bigint,@RDB500CMSBuildRuleInputId bigint,@RDB500CMSBuildNodeId bigint;
    DECLARE RDB500CMSBuildRuleCursor CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @RDB500CMSBuildRules ORDER BY RuleCode;
    OPEN RDB500CMSBuildRuleCursor;
    FETCH NEXT FROM RDB500CMSBuildRuleCursor INTO @RDB500CMSBuildRulePhiloteId,@RDB500CMSBuildRuleVersionPhiloteId,@RDB500CMSBuildRuleInputPhiloteId,@RDB500CMSBuildDefaultPhiloteId,@RDB500CMSBuildNodePhiloteId,@RDB500CMSBuildRuleCode,@RDB500CMSBuildPurpose,@RDB500CMSBuildDefaultValue,@RDB500CMSBuildSourceFileReference;
    WHILE @@FETCH_STATUS=0
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500CMSBuildRuleKindId AND RuleCode=@RDB500CMSBuildRuleCode)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CMSBuildRuleTypeId,@RDB500CMSBuildRulePhiloteId,@RDB500CMSBuildNow);
        SET @RDB500CMSBuildEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Rule](RulePhiloteId,EntityId,EntityTypeId,RuleKindId,RuleCode,CreatedAtUtc)
        VALUES(@RDB500CMSBuildRulePhiloteId,@RDB500CMSBuildEntityId,@RDB500CMSBuildRuleTypeId,@RDB500CMSBuildRuleKindId,@RDB500CMSBuildRuleCode,@RDB500CMSBuildNow);
      END;
      IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500CMSBuildRuleKindId AND RuleCode=@RDB500CMSBuildRuleCode AND RulePhiloteId<>@RDB500CMSBuildRulePhiloteId)
        THROW 55506, 'RDB-500C Rule natural key maps to a different Philote.', 1;
      SELECT @RDB500CMSBuildRuleId=RuleId FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500CMSBuildRuleKindId AND RuleCode=@RDB500CMSBuildRuleCode;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500CMSBuildRuleId AND RevisionSequence=1)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CMSBuildRuleVersionTypeId,@RDB500CMSBuildRuleVersionPhiloteId,@RDB500CMSBuildNow);
        SET @RDB500CMSBuildEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleVersion]
          (RuleVersionPhiloteId,EntityId,EntityTypeId,RuleId,RuleKindId,RuleKindVersionId,RevisionSequence,
           PredecessorRuleVersionId,CompositionHashAlgorithmCode,CompositionContentHash,PublishedAtUtc)
        VALUES(@RDB500CMSBuildRuleVersionPhiloteId,@RDB500CMSBuildEntityId,@RDB500CMSBuildRuleVersionTypeId,@RDB500CMSBuildRuleId,@RDB500CMSBuildRuleKindId,
          @RDB500CMSBuildRuleKindVersionId,1,NULL,'SHA-256',HASHBYTES('SHA2_256',CONCAT(@RDB500CMSBuildRuleCode,N'|',@RDB500CMSBuildPurpose,N'|',@RDB500CMSBuildSourceFileReference)),@RDB500CMSBuildNow);
      END;
      SELECT @RDB500CMSBuildRuleVersionId=RuleVersionId FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500CMSBuildRuleId AND RevisionSequence=1;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500CMSBuildRuleVersionId AND InputCode='content')
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CMSBuildRuleInputTypeId,@RDB500CMSBuildRuleInputPhiloteId,@RDB500CMSBuildNow);
        SET @RDB500CMSBuildEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleInputDefinition]
          (RuleInputDefinitionPhiloteId,EntityId,EntityTypeId,RuleVersionId,InputCode,Ordinal,ValueTypeVersionId,
           MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500CMSBuildRuleInputPhiloteId,@RDB500CMSBuildEntityId,@RDB500CMSBuildRuleInputTypeId,@RDB500CMSBuildRuleVersionId,
          'content',0,@RDB500CMSBuildValueTypeVersionId,1,1,0,'non-empty-text');
      END;
      SELECT @RDB500CMSBuildRuleInputId=RuleInputDefinitionId FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500CMSBuildRuleVersionId AND InputCode='content';
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleDefaultInputValue] WHERE RuleInputDefinitionId=@RDB500CMSBuildRuleInputId)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500CMSBuildRuleDefaultTypeId,@RDB500CMSBuildDefaultPhiloteId,@RDB500CMSBuildNow);
        SET @RDB500CMSBuildEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleDefaultInputValue]
          (RuleDefaultInputValuePhiloteId,EntityId,EntityTypeId,RuleInputDefinitionId,RuleVersionId,ValueTypeVersionId,
           CanonicalTextValue,CanonicalValueHash,RationaleEntityId,RationaleEntityTypeId,PublishedAtUtc)
        VALUES(@RDB500CMSBuildDefaultPhiloteId,@RDB500CMSBuildEntityId,@RDB500CMSBuildRuleDefaultTypeId,@RDB500CMSBuildRuleInputId,@RDB500CMSBuildRuleVersionId,
          @RDB500CMSBuildValueTypeVersionId,@RDB500CMSBuildDefaultValue,HASHBYTES('SHA2_256',@RDB500CMSBuildDefaultValue),
          (SELECT EntityId FROM [ATAPUtilities].[Rule] WHERE RuleId=@RDB500CMSBuildRuleId),@RDB500CMSBuildRuleTypeId,@RDB500CMSBuildNow);
      END;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId=@RDB500CMSBuildNodePhiloteId)
        INSERT [ATAPUtilities].[RuleVersionNode]
          (RuleVersionNodePhiloteId,RuleVersionId,RuleKindVersionId,ParentRuleVersionNodeId,Ordinal,PrimitiveVersionId,
           MinOccurs,MaxOccurs,ChoiceDiscriminatorCode,NodeLabel)
        VALUES(@RDB500CMSBuildNodePhiloteId,@RDB500CMSBuildRuleVersionId,@RDB500CMSBuildRuleKindVersionId,NULL,0,@RDB500CMSBuildRootPrimitiveVersionId,1,1,NULL,N'root');
      SELECT @RDB500CMSBuildNodeId=RuleVersionNodeId FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId=@RDB500CMSBuildNodePhiloteId;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNodeInput] WHERE RuleVersionNodeId=@RDB500CMSBuildNodeId AND PrimitiveInputDefinitionId=@RDB500CMSBuildRootPrimitiveInputId)
        INSERT [ATAPUtilities].[RuleVersionNodeInput]
          (RuleVersionNodeId,RuleVersionId,PrimitiveVersionId,PrimitiveInputDefinitionId,BindingShapeCode,
           TargetValueTypeVersionId,SourceValueTypeVersionId,ConstantValueTypeVersionId,RuleInputDefinitionId,
           DerivationContractVersionId,ConversionPolicyCode,CanonicalTextValue,CanonicalValueHash)
        VALUES(@RDB500CMSBuildNodeId,@RDB500CMSBuildRuleVersionId,@RDB500CMSBuildRootPrimitiveVersionId,@RDB500CMSBuildRootPrimitiveInputId,
          'constant',@RDB500CMSBuildValueTypeVersionId,NULL,@RDB500CMSBuildValueTypeVersionId,NULL,NULL,NULL,@RDB500CMSBuildDefaultValue,
          HASHBYTES('SHA2_256',@RDB500CMSBuildDefaultValue));
      FETCH NEXT FROM RDB500CMSBuildRuleCursor INTO @RDB500CMSBuildRulePhiloteId,@RDB500CMSBuildRuleVersionPhiloteId,@RDB500CMSBuildRuleInputPhiloteId,@RDB500CMSBuildDefaultPhiloteId,@RDB500CMSBuildNodePhiloteId,@RDB500CMSBuildRuleCode,@RDB500CMSBuildPurpose,@RDB500CMSBuildDefaultValue,@RDB500CMSBuildSourceFileReference;
    END;
    CLOSE RDB500CMSBuildRuleCursor; DEALLOCATE RDB500CMSBuildRuleCursor;

    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500CMSBuildRuleKindId) < 8
      THROW 55507, 'RDB-500C primitive row-count postcondition failed.', 1;
    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500CMSBuildRuleKindId) < 14
      THROW 55508, 'RDB-500C rule row-count postcondition failed.', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','RDB500CMSBuildPrimitiveCursor') >= -1 BEGIN CLOSE RDB500CMSBuildPrimitiveCursor; DEALLOCATE RDB500CMSBuildPrimitiveCursor; END;
    IF CURSOR_STATUS('local','RDB500CMSBuildRuleCursor') >= -1 BEGIN CLOSE RDB500CMSBuildRuleCursor; DEALLOCATE RDB500CMSBuildRuleCursor; END;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
/* END INTEGRATED FRAGMENT: RDB-500C__SQL-MSBuild.sql */

/* BEGIN INTEGRATED FRAGMENT: RDB-500D__Path.sql */
/* Generated RRSBS Wave 6 seed fragment: RDB-500D.
   Owner boundary: RDB-500D only. Do not integrate by editing this file;
   RDB-510 is the sole final seed integrator. Deferred kinds: Snippet. */
/* RDB-500D / Path reference seed.
   Positive: A Path rule with a non-empty repository-relative source reference.
   Negative (declarative; exercised by RDB-510): A Path rule with an empty content input or a cross-kind primitive version.
   Integration prerequisites are coordinator-owned and fail closed below. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @RDB500DPathNow datetime2(7) = CONVERT(datetime2(7), '2026-08-06T00:00:00.0000000Z', 127);
DECLARE @RDB500DPathGrammarSourceArtifactVersionId bigint;
DECLARE @RDB500DPathCompendiumSourceArtifactVersionId bigint;
SELECT @RDB500DPathGrammarSourceArtifactVersionId = sav.SourceArtifactVersionId
FROM [ATAPUtilities].[SourceArtifact] sa
JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId = sa.SourceArtifactId
WHERE sa.LocatorTypeCode = 'RepositoryPath'
  AND sa.RepoRelativePathOrExternalLocator = N'SolutionDocumentation/grammers/Path.grammar.ebnf'
  AND sav.NormalizedContentSha256 = '277a0ceeace69edd2c806528dac212db9a69cfd9e74afe7d15ba13578b3f4bc6';
SELECT @RDB500DPathCompendiumSourceArtifactVersionId = sav.SourceArtifactVersionId
FROM [ATAPUtilities].[SourceArtifact] sa
JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId = sa.SourceArtifactId
WHERE sa.LocatorTypeCode = 'RepositoryPath'
  AND sa.RepoRelativePathOrExternalLocator = N'SolutionDocumentation/Rules Compendium.Path.md'
  AND sav.NormalizedContentSha256 = '434ddbc5b3589c45f6c67dc8e890e66f777fddde78558dd45b9c1da5021bfeee';
IF @RDB500DPathGrammarSourceArtifactVersionId IS NULL OR @RDB500DPathCompendiumSourceArtifactVersionId IS NULL
    THROW 55500, 'RDB-500D requires exact grammar and compendium SourceArtifactVersion rows.', 1;

DECLARE @RDB500DPathRuleKindTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind');
DECLARE @RDB500DPathRuleKindVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind-version');
DECLARE @RDB500DPathValueTypeTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type');
DECLARE @RDB500DPathValueTypeVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type-version');
DECLARE @RDB500DPathPrimitiveTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive');
DECLARE @RDB500DPathPrimitiveVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-version');
DECLARE @RDB500DPathPrimitiveInputTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-input-definition');
DECLARE @RDB500DPathRuleTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule');
DECLARE @RDB500DPathRuleVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-version');
DECLARE @RDB500DPathRuleInputTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-input-definition');
DECLARE @RDB500DPathRuleDefaultTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-default-input-value');
IF @RDB500DPathRuleKindTypeId IS NULL OR @RDB500DPathRuleDefaultTypeId IS NULL
    THROW 55501, 'RDB-500D requires the frozen RDB-320 EntityType catalog.', 1;
IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ExecutionClassification] WHERE ExecutionClassificationCode='metadata-only' AND AllowsExecutorContract=0)
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[SecurityCapabilityClassification] WHERE SecurityCapabilityCode='reference-safe')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RoundTripPolicy] WHERE RoundTripPolicyCode='byte-identical')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ScalarStorageKind] WHERE ScalarStorageKindCode='bounded-unicode-text')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[BindingShape] WHERE BindingShapeCode='constant')
    THROW 55502, 'RDB-500D requires coordinator-owned closed catalog rows.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @RDB500DPathEntityId bigint;
    DECLARE @RDB500DPathRuleKindId bigint;
    DECLARE @RDB500DPathRuleKindVersionId bigint;
    DECLARE @RDB500DPathValueTypeId bigint;
    DECLARE @RDB500DPathValueTypeVersionId bigint;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'Path')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500DPathRuleKindTypeId,'1de3097c-9885-5724-958e-2e68913f89a6',@RDB500DPathNow);
        SET @RDB500DPathEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleKind](RuleKindPhiloteId,EntityId,EntityTypeId,RuleKindCode,CreatedAtUtc)
        VALUES('1de3097c-9885-5724-958e-2e68913f89a6',@RDB500DPathEntityId,@RDB500DPathRuleKindTypeId,N'Path',@RDB500DPathNow);
    END;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'Path' AND RuleKindPhiloteId<>'1de3097c-9885-5724-958e-2e68913f89a6')
        THROW 55503, 'RDB-500D RuleKind natural key maps to a different Philote.', 1;
    SELECT @RDB500DPathRuleKindId=RuleKindId FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'Path';

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500DPathRuleKindId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500DPathRuleKindVersionTypeId,'fd5c76e9-fa1e-5941-92e9-f1cfa959f5ef',@RDB500DPathNow);
        SET @RDB500DPathEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleKindVersion]
          (RuleKindVersionPhiloteId,EntityId,EntityTypeId,RuleKindId,RevisionSequence,PredecessorRuleKindVersionId,
           GrammarSourceArtifactVersionId,GrammarHashAlgorithmCode,GrammarContentHash,CompendiumSourceArtifactVersionId,
           CompendiumHashAlgorithmCode,CompendiumContentHash,ExecutorContractVersionId,ExecutionClassificationCode,
           SecurityCapabilityCode,RoundTripPolicyCode,PublishedAtUtc)
        VALUES('fd5c76e9-fa1e-5941-92e9-f1cfa959f5ef',@RDB500DPathEntityId,@RDB500DPathRuleKindVersionTypeId,@RDB500DPathRuleKindId,1,NULL,
          @RDB500DPathGrammarSourceArtifactVersionId,'SHA-256',0x277a0ceeace69edd2c806528dac212db9a69cfd9e74afe7d15ba13578b3f4bc6,@RDB500DPathCompendiumSourceArtifactVersionId,
          'SHA-256',0x434ddbc5b3589c45f6c67dc8e890e66f777fddde78558dd45b9c1da5021bfeee,NULL,'metadata-only','reference-safe','byte-identical',@RDB500DPathNow);
    END;
    SELECT @RDB500DPathRuleKindVersionId=RuleKindVersionId FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500DPathRuleKindId AND RevisionSequence=1;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-path-text')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500DPathValueTypeTypeId,'26be5180-92fe-5e0a-960b-3d5acd20a42a',@RDB500DPathNow);
        SET @RDB500DPathEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[ValueType](ValueTypePhiloteId,EntityId,EntityTypeId,ValueTypeCode,CreatedAtUtc)
        VALUES('26be5180-92fe-5e0a-960b-3d5acd20a42a',@RDB500DPathEntityId,@RDB500DPathValueTypeTypeId,'seed-path-text',@RDB500DPathNow);
    END;
    SELECT @RDB500DPathValueTypeId=ValueTypeId FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-path-text';
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500DPathValueTypeId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500DPathValueTypeVersionTypeId,'00d85880-d8ca-5b50-b64e-d5815ed0d08f',@RDB500DPathNow);
        SET @RDB500DPathEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[ValueTypeVersion]
          (ValueTypeVersionPhiloteId,EntityId,EntityTypeId,ValueTypeId,RevisionSequence,PredecessorValueTypeVersionId,
           ValueCategoryCode,ScalarStorageKindCode,StructuredValueContractVersionId,ElementValueTypeVersionId,
           CollectionOrderingCode,SecretReferencePolicyId,ValidationContractCode,PublishedAtUtc)
        VALUES('00d85880-d8ca-5b50-b64e-d5815ed0d08f',@RDB500DPathEntityId,@RDB500DPathValueTypeVersionTypeId,@RDB500DPathValueTypeId,1,NULL,
          'scalar','bounded-unicode-text',NULL,NULL,NULL,NULL,'non-empty-text',@RDB500DPathNow);
    END;
    SELECT @RDB500DPathValueTypeVersionId=ValueTypeVersionId FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500DPathValueTypeId AND RevisionSequence=1;

    DECLARE @RDB500DPathPrimitives TABLE(PrimitivePhiloteId uniqueidentifier,PrimitiveVersionPhiloteId uniqueidentifier,
      InputPhiloteId uniqueidentifier,PrimitiveCode varchar(128),DefinitionText nvarchar(max));
    INSERT @RDB500DPathPrimitives VALUES
        ('d1e2f3a4-5b6c-7d8e-9f0a-1b2c3d4e5f6a', 'bacd2296-3595-5c56-bad3-373268757e09', 'f6583d13-20bf-5fb8-9fbd-18d4eb67efd2', N'<path>', N'Top-level path primitive routing to UNC/absolute/relative/extended paths'),
        ('e2f3a4b5-6c7d-8e9f-0a1b-2c3d4e5f6a7b', 'e28f5f75-c836-5b5c-b45a-225a8a474dd8', 'f282acf6-4c80-59ab-9103-db0b48b2e3e1', N'<unc-path>', N'Universal Naming Convention path for network resources (\\server\share\path)'),
        ('f3a4b5c6-7d8e-9f0a-1b2c-3d4e5f6a7b8c', 'b43864a9-9780-5dbb-bf91-ae01739939b9', 'bf89320e-572e-5eba-a3a2-5f29b4920445', N'<absolute-path>', N'Absolute path with drive letter or root directory (C:\path or \path)'),
        ('a4b5c6d7-8e9f-0a1b-2c3d-4e5f6a7b8c9d', 'afbda3ce-02a6-5ad7-931c-5ed6721f290b', 'bb288804-bcf2-58a1-b5c7-d6911b8f63eb', N'<relative-path>', N'Relative path from current working directory'),
        ('b5c6d7e8-9f0a-1b2c-3d4e-5f6a7b8c9d0e', 'b358af02-d5a6-5397-a1bb-92b8406baae2', '27869a91-ded6-591e-b10c-c5abfbdc77b2', N'<extended-path>', N'Extended-length path with \\?\ prefix for paths exceeding MAX_PATH'),
        ('c6d7e8f9-0a1b-2c3d-4e5f-6a7b8c9d0e1f', '7a5845f8-862e-506c-b0ff-38d0031789f9', '3cf1a999-5921-54e1-bf0e-1171cfb77af7', N'<drive>', N'Drive letter followed by colon (e.g. C: D: Z:)'),
        ('d7e8f9a0-1b2c-3d4e-5f6a-7b8c9d0e1f2a', '6d7c30fb-505e-5e36-a202-1397e2bbb176', 'd85d321a-e918-5c9f-b47b-b1e735a014af', N'<path-tail>', N'Recursive path segment structure (folder\subfolder\file)'),
        ('e8f9a0b1-2c3d-4e5f-6a7b-8c9d0e1f2a3b', '4c56bd3b-0f45-59c3-bb7c-bfca9163272e', '829c3c8c-c490-5d67-ac53-bd08db8fb376', N'<name>', N'File or directory name with reserved name validation'),
        ('f9a0b1c2-3d4e-5f6a-7b8c-9d0e1f2a3b4c', '9ff4164a-7cd5-53ae-96a9-ec0b3cdfc344', '21e7511d-c746-5683-a553-411ca26baee7', N'<namechar>', N'Valid path character excluding \ / : * ? " < > |'),
        ('a0b1c2d3-4e5f-6a7b-8c9d-0e1f2a3b4c5d', '16ba0ae6-9fed-52de-b1c2-69777e7ae796', 'ca4b8d7b-050c-59d8-a90d-0b1fc390d2ff', N'<server>', N'UNC server name (hostname/FQDN/IP address)'),
        ('b1c2d3e4-5f6a-7b8c-9d0e-1f2a3b4c5d6e', '7f395548-a056-5d03-93e7-d10cb3c32581', '76b5cdfd-13c8-52c3-b5fb-e91ea0ce15c8', N'<share>', N'UNC share name identifying shared resource'),
        ('c2d3e4f5-6a7b-8c9d-0e1f-2a3b4c5d6e7f', '8edb2d5d-9429-58f5-aef9-d873d5279474', '39aa1efa-1b51-50b4-aae9-0c8aef05c17a', N'<letter>', N'Alphabetic drive letter character (A-Z or a-z)'),
        ('8c3d6e7f-5a4b-4c9d-0e12-3c4d5e6f7081', '31390963-2351-56a6-88d6-e15c18f7cda3', '8f6e6a95-aac1-5294-a4b7-c7a4e2ddcf54', N'<atap-utilities-secrets-csproj-path>', N'Specialized absolute path primitive for the ATAP.Utilities.Secrets.csproj file instantiation');
    DECLARE @RDB500DPathPrimitivePhiloteId uniqueidentifier,@RDB500DPathPrimitiveVersionPhiloteId uniqueidentifier,
      @RDB500DPathInputPhiloteId uniqueidentifier,@RDB500DPathPrimitiveCode varchar(128),@RDB500DPathDefinitionText nvarchar(max),
      @RDB500DPathPrimitiveId bigint,@RDB500DPathPrimitiveVersionId bigint;
    DECLARE RDB500DPathPrimitiveCursor CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @RDB500DPathPrimitives ORDER BY PrimitiveCode;
    OPEN RDB500DPathPrimitiveCursor;
    FETCH NEXT FROM RDB500DPathPrimitiveCursor INTO @RDB500DPathPrimitivePhiloteId,@RDB500DPathPrimitiveVersionPhiloteId,@RDB500DPathInputPhiloteId,@RDB500DPathPrimitiveCode,@RDB500DPathDefinitionText;
    WHILE @@FETCH_STATUS=0
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500DPathRuleKindId AND PrimitiveCode=@RDB500DPathPrimitiveCode)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500DPathPrimitiveTypeId,@RDB500DPathPrimitivePhiloteId,@RDB500DPathNow);
        SET @RDB500DPathEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500DPathPrimitivePhiloteId,@RDB500DPathEntityId,@RDB500DPathPrimitiveTypeId,@RDB500DPathRuleKindId,@RDB500DPathPrimitiveCode,@RDB500DPathNow);
      END;
      IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500DPathRuleKindId AND PrimitiveCode=@RDB500DPathPrimitiveCode AND PrimitivePhiloteId<>@RDB500DPathPrimitivePhiloteId)
        THROW 55504, 'RDB-500D Primitive natural key maps to a different Philote.', 1;
      SELECT @RDB500DPathPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500DPathRuleKindId AND PrimitiveCode=@RDB500DPathPrimitiveCode;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500DPathPrimitiveId AND RevisionSequence=1)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500DPathPrimitiveVersionTypeId,@RDB500DPathPrimitiveVersionPhiloteId,@RDB500DPathNow);
        SET @RDB500DPathEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,
           PredecessorPrimitiveVersionId,GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,
           DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500DPathPrimitiveVersionPhiloteId,@RDB500DPathEntityId,@RDB500DPathPrimitiveVersionTypeId,@RDB500DPathPrimitiveId,
          @RDB500DPathRuleKindId,@RDB500DPathRuleKindVersionId,1,NULL,@RDB500DPathPrimitiveCode,@RDB500DPathDefinitionText,'SHA-256',
          HASHBYTES('SHA2_256',@RDB500DPathDefinitionText),@RDB500DPathValueTypeVersionId,1,1,@RDB500DPathNow);
      END;
      SELECT @RDB500DPathPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500DPathPrimitiveId AND RevisionSequence=1;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500DPathPrimitiveVersionId AND InputCode='content')
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500DPathPrimitiveInputTypeId,@RDB500DPathInputPhiloteId,@RDB500DPathNow);
        SET @RDB500DPathEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,
           ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500DPathInputPhiloteId,@RDB500DPathEntityId,@RDB500DPathPrimitiveInputTypeId,@RDB500DPathPrimitiveVersionId,
          'content',0,@RDB500DPathValueTypeVersionId,1,1,0,'non-empty-text');
      END;
      FETCH NEXT FROM RDB500DPathPrimitiveCursor INTO @RDB500DPathPrimitivePhiloteId,@RDB500DPathPrimitiveVersionPhiloteId,@RDB500DPathInputPhiloteId,@RDB500DPathPrimitiveCode,@RDB500DPathDefinitionText;
    END;
    CLOSE RDB500DPathPrimitiveCursor; DEALLOCATE RDB500DPathPrimitiveCursor;

    DECLARE @RDB500DPathRootPrimitiveVersionId bigint,@RDB500DPathRootPrimitiveInputId bigint;
    SELECT @RDB500DPathRootPrimitiveVersionId=pv.PrimitiveVersionId,@RDB500DPathRootPrimitiveInputId=pid.PrimitiveInputDefinitionId
    FROM [ATAPUtilities].[Primitive] p JOIN [ATAPUtilities].[PrimitiveVersion] pv ON pv.PrimitiveId=p.PrimitiveId AND pv.RevisionSequence=1
    JOIN [ATAPUtilities].[PrimitiveInputDefinition] pid ON pid.PrimitiveVersionId=pv.PrimitiveVersionId AND pid.InputCode='content'
    WHERE p.RuleKindId=@RDB500DPathRuleKindId AND p.PrimitiveCode=N'<path>';
    IF @RDB500DPathRootPrimitiveInputId IS NULL THROW 55505, 'RDB-500D top primitive/input was not materialized.', 1;

    DECLARE @RDB500DPathRules TABLE(RulePhiloteId uniqueidentifier,RuleVersionPhiloteId uniqueidentifier,
      RuleInputPhiloteId uniqueidentifier,DefaultPhiloteId uniqueidentifier,NodePhiloteId uniqueidentifier,
      RuleCode varchar(128),Purpose nvarchar(max),DefaultValue nvarchar(max),SourceFileReference nvarchar(2048));
    INSERT @RDB500DPathRules VALUES
        ('3c4d5e6f-7a8b-9c0d-1e2f-3a4b5c6d7e8f', '499ecf87-8c29-5c31-b952-739377efc330', '26515b49-ba54-560e-bc3d-55d5a9b02a34', '22de26c8-67f8-559c-9fb5-687be80ed492', '591838ec-e08a-5ff5-9321-8a123f2ea027', N'ATAP.Utilities Repository Path', N'Absolute path to ATAP.Utilities repository root directory', N'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-branch63\SolutionDocumentation\Rules Compendium.Path.md', N'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-branch63\SolutionDocumentation\Rules Compendium.Path.md'),
        ('6a1f4e0d-3b2c-4d5e-8f90-1a2b3c4d5e6f', '3534c769-5c54-55ef-aaab-be8ecbecbaf1', '2fcc1316-225c-5a8d-8cd0-ef5147bcb1ba', '0e96d426-4b29-54a9-a685-655b7f88fd95', '52766932-6d11-57bd-bb98-2152d2139fe7', N'ATAP.Utilities.Secrets.csproj Path', N'Absolute path to the ATAP.Utilities.Secrets project file', N'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-96-sprint-0005-work-items\src\ATAP.Utilities.Secrets\ATAP.Utilities.Secrets.csproj', N'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-96-sprint-0005-work-items\src\ATAP.Utilities.Secrets\ATAP.Utilities.Secrets.csproj'),
        ('2159a341-8a9f-40a3-ae0a-e41e40c9523f', '670c0d46-466d-5dc9-a788-61d55fecd560', '1afbac71-e443-5f47-a625-9952571991c6', '78054128-6ee8-58a1-a0fa-8666894db13c', 'bd86d7f8-850f-5422-b522-de8388956aee', N'ATAP.Utilities', N'Absolute path to ATAP.Utilities repository directory from C:\Dropbox\whertzing\GitHub (recursive component)', N'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\SolutionDocumentation\Rules Compendium.Path.md', N'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\SolutionDocumentation\Rules Compendium.Path.md'),
        ('9a076a35-3b77-464f-ab8c-dd5792c4f407', 'dd6c7517-e563-5f75-91c8-032d8c93f8a2', '0ef4bf91-3a73-5571-9dc0-041423a2b34d', '4f4abfe8-cadc-5b6b-a520-e898b19df7c3', 'a040f165-d522-5c04-bcf3-1fb30346a865', N'ATAP.Utilities\src', N'Absolute path to src subtree for ATAP.Utilities at C:\Dropbox\whertzing\GitHub', N'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\SolutionDocumentation\Rules Compendium.Path.md', N'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\SolutionDocumentation\Rules Compendium.Path.md'),
        ('70b816a0-ca8a-4bb2-ae5b-8e3288f9a0ab', 'ef4d86e9-52da-5b30-90c0-041d0f525d59', '1a995da1-5848-5113-9ccb-ca1f57c23dda', '996d5015-5880-51f4-b2e1-7d368a9cb458', '64e71789-a3ee-535e-8354-968a3876da66', N'ATAP.Utilities\src\ATAP.Utilities.PowerShell', N'Absolute path to ATAP.Utilities.PowerShell subtree under src', N'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\SolutionDocumentation\Rules Compendium.Path.md', N'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\SolutionDocumentation\Rules Compendium.Path.md'),
        ('6cefb781-c916-428a-a653-5b7cf3098c2f', 'd7dd5053-945e-59d4-b519-9a4a13428603', '4e8fd049-6bf5-5b7b-9363-4d8084f242dc', '99296d00-eed9-5d81-8068-b962b57ccd23', '7c50ed9c-4cf7-5862-9b64-30b129cb24ac', N'ATAP.Utilities\src\ATAP.Utilities.PowerShell\public', N'Absolute path to public folder for ATAP.Utilities PowerShell', N'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\SolutionDocumentation\Rules Compendium.Path.md', N'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\SolutionDocumentation\Rules Compendium.Path.md'),
        ('1fc23f7e-e18e-4004-a93e-246fde7073e9', '775f0ab4-e9dc-55f4-a860-826b8ea8273b', '47ba3d2c-ca4a-5e61-8ba3-664b281ab450', '8436ccf1-215d-550d-868e-3298e3554a92', '0f79f790-52a8-5965-b845-bd1f5e4314b0', N'ATAP.Utilities\src\ATAP.Utilities.PowerShell\public\Write-ArrayIndented.ps1', N'Absolute path to Write-ArrayIndented.ps1 in ATAP.Utilities.PowerShell public folder', N'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\SolutionDocumentation\Rules Compendium.Path.md', N'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\SolutionDocumentation\Rules Compendium.Path.md');
    DECLARE @RDB500DPathRulePhiloteId uniqueidentifier,@RDB500DPathRuleVersionPhiloteId uniqueidentifier,
      @RDB500DPathRuleInputPhiloteId uniqueidentifier,@RDB500DPathDefaultPhiloteId uniqueidentifier,@RDB500DPathNodePhiloteId uniqueidentifier,
      @RDB500DPathRuleCode varchar(128),@RDB500DPathPurpose nvarchar(max),@RDB500DPathDefaultValue nvarchar(max),@RDB500DPathSourceFileReference nvarchar(2048),
      @RDB500DPathRuleId bigint,@RDB500DPathRuleVersionId bigint,@RDB500DPathRuleInputId bigint,@RDB500DPathNodeId bigint;
    DECLARE RDB500DPathRuleCursor CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @RDB500DPathRules ORDER BY RuleCode;
    OPEN RDB500DPathRuleCursor;
    FETCH NEXT FROM RDB500DPathRuleCursor INTO @RDB500DPathRulePhiloteId,@RDB500DPathRuleVersionPhiloteId,@RDB500DPathRuleInputPhiloteId,@RDB500DPathDefaultPhiloteId,@RDB500DPathNodePhiloteId,@RDB500DPathRuleCode,@RDB500DPathPurpose,@RDB500DPathDefaultValue,@RDB500DPathSourceFileReference;
    WHILE @@FETCH_STATUS=0
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500DPathRuleKindId AND RuleCode=@RDB500DPathRuleCode)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500DPathRuleTypeId,@RDB500DPathRulePhiloteId,@RDB500DPathNow);
        SET @RDB500DPathEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Rule](RulePhiloteId,EntityId,EntityTypeId,RuleKindId,RuleCode,CreatedAtUtc)
        VALUES(@RDB500DPathRulePhiloteId,@RDB500DPathEntityId,@RDB500DPathRuleTypeId,@RDB500DPathRuleKindId,@RDB500DPathRuleCode,@RDB500DPathNow);
      END;
      IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500DPathRuleKindId AND RuleCode=@RDB500DPathRuleCode AND RulePhiloteId<>@RDB500DPathRulePhiloteId)
        THROW 55506, 'RDB-500D Rule natural key maps to a different Philote.', 1;
      SELECT @RDB500DPathRuleId=RuleId FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500DPathRuleKindId AND RuleCode=@RDB500DPathRuleCode;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500DPathRuleId AND RevisionSequence=1)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500DPathRuleVersionTypeId,@RDB500DPathRuleVersionPhiloteId,@RDB500DPathNow);
        SET @RDB500DPathEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleVersion]
          (RuleVersionPhiloteId,EntityId,EntityTypeId,RuleId,RuleKindId,RuleKindVersionId,RevisionSequence,
           PredecessorRuleVersionId,CompositionHashAlgorithmCode,CompositionContentHash,PublishedAtUtc)
        VALUES(@RDB500DPathRuleVersionPhiloteId,@RDB500DPathEntityId,@RDB500DPathRuleVersionTypeId,@RDB500DPathRuleId,@RDB500DPathRuleKindId,
          @RDB500DPathRuleKindVersionId,1,NULL,'SHA-256',HASHBYTES('SHA2_256',CONCAT(@RDB500DPathRuleCode,N'|',@RDB500DPathPurpose,N'|',@RDB500DPathSourceFileReference)),@RDB500DPathNow);
      END;
      SELECT @RDB500DPathRuleVersionId=RuleVersionId FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500DPathRuleId AND RevisionSequence=1;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500DPathRuleVersionId AND InputCode='content')
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500DPathRuleInputTypeId,@RDB500DPathRuleInputPhiloteId,@RDB500DPathNow);
        SET @RDB500DPathEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleInputDefinition]
          (RuleInputDefinitionPhiloteId,EntityId,EntityTypeId,RuleVersionId,InputCode,Ordinal,ValueTypeVersionId,
           MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500DPathRuleInputPhiloteId,@RDB500DPathEntityId,@RDB500DPathRuleInputTypeId,@RDB500DPathRuleVersionId,
          'content',0,@RDB500DPathValueTypeVersionId,1,1,0,'non-empty-text');
      END;
      SELECT @RDB500DPathRuleInputId=RuleInputDefinitionId FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500DPathRuleVersionId AND InputCode='content';
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleDefaultInputValue] WHERE RuleInputDefinitionId=@RDB500DPathRuleInputId)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500DPathRuleDefaultTypeId,@RDB500DPathDefaultPhiloteId,@RDB500DPathNow);
        SET @RDB500DPathEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleDefaultInputValue]
          (RuleDefaultInputValuePhiloteId,EntityId,EntityTypeId,RuleInputDefinitionId,RuleVersionId,ValueTypeVersionId,
           CanonicalTextValue,CanonicalValueHash,RationaleEntityId,RationaleEntityTypeId,PublishedAtUtc)
        VALUES(@RDB500DPathDefaultPhiloteId,@RDB500DPathEntityId,@RDB500DPathRuleDefaultTypeId,@RDB500DPathRuleInputId,@RDB500DPathRuleVersionId,
          @RDB500DPathValueTypeVersionId,@RDB500DPathDefaultValue,HASHBYTES('SHA2_256',@RDB500DPathDefaultValue),
          (SELECT EntityId FROM [ATAPUtilities].[Rule] WHERE RuleId=@RDB500DPathRuleId),@RDB500DPathRuleTypeId,@RDB500DPathNow);
      END;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId=@RDB500DPathNodePhiloteId)
        INSERT [ATAPUtilities].[RuleVersionNode]
          (RuleVersionNodePhiloteId,RuleVersionId,RuleKindVersionId,ParentRuleVersionNodeId,Ordinal,PrimitiveVersionId,
           MinOccurs,MaxOccurs,ChoiceDiscriminatorCode,NodeLabel)
        VALUES(@RDB500DPathNodePhiloteId,@RDB500DPathRuleVersionId,@RDB500DPathRuleKindVersionId,NULL,0,@RDB500DPathRootPrimitiveVersionId,1,1,NULL,N'root');
      SELECT @RDB500DPathNodeId=RuleVersionNodeId FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId=@RDB500DPathNodePhiloteId;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNodeInput] WHERE RuleVersionNodeId=@RDB500DPathNodeId AND PrimitiveInputDefinitionId=@RDB500DPathRootPrimitiveInputId)
        INSERT [ATAPUtilities].[RuleVersionNodeInput]
          (RuleVersionNodeId,RuleVersionId,PrimitiveVersionId,PrimitiveInputDefinitionId,BindingShapeCode,
           TargetValueTypeVersionId,SourceValueTypeVersionId,ConstantValueTypeVersionId,RuleInputDefinitionId,
           DerivationContractVersionId,ConversionPolicyCode,CanonicalTextValue,CanonicalValueHash)
        VALUES(@RDB500DPathNodeId,@RDB500DPathRuleVersionId,@RDB500DPathRootPrimitiveVersionId,@RDB500DPathRootPrimitiveInputId,
          'constant',@RDB500DPathValueTypeVersionId,NULL,@RDB500DPathValueTypeVersionId,NULL,NULL,NULL,@RDB500DPathDefaultValue,
          HASHBYTES('SHA2_256',@RDB500DPathDefaultValue));
      FETCH NEXT FROM RDB500DPathRuleCursor INTO @RDB500DPathRulePhiloteId,@RDB500DPathRuleVersionPhiloteId,@RDB500DPathRuleInputPhiloteId,@RDB500DPathDefaultPhiloteId,@RDB500DPathNodePhiloteId,@RDB500DPathRuleCode,@RDB500DPathPurpose,@RDB500DPathDefaultValue,@RDB500DPathSourceFileReference;
    END;
    CLOSE RDB500DPathRuleCursor; DEALLOCATE RDB500DPathRuleCursor;

    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500DPathRuleKindId) < 13
      THROW 55507, 'RDB-500D primitive row-count postcondition failed.', 1;
    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500DPathRuleKindId) < 7
      THROW 55508, 'RDB-500D rule row-count postcondition failed.', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','RDB500DPathPrimitiveCursor') >= -1 BEGIN CLOSE RDB500DPathPrimitiveCursor; DEALLOCATE RDB500DPathPrimitiveCursor; END;
    IF CURSOR_STATUS('local','RDB500DPathRuleCursor') >= -1 BEGIN CLOSE RDB500DPathRuleCursor; DEALLOCATE RDB500DPathRuleCursor; END;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
/* END INTEGRATED FRAGMENT: RDB-500D__Path.sql */

/* BEGIN INTEGRATED FRAGMENT: RDB-500E__OtterScript.sql */
/* Generated RRSBS Wave 6 seed fragment: RDB-500E.
   Owner boundary: RDB-500E only. Do not integrate by editing this file;
   RDB-510 is the sole final seed integrator. Deferred kinds: Workflow. */
/* RDB-500E / OtterScript reference seed.
   Positive: A package plan references a dotted SecretName and never embeds a credential.
   Negative (declarative; exercised by RDB-510): A package plan containing an API key, decrypted value, or direct credential is rejected.
   Integration prerequisites are coordinator-owned and fail closed below. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @RDB500EOtterScriptNow datetime2(7) = CONVERT(datetime2(7), '2026-08-06T00:00:00.0000000Z', 127);
DECLARE @RDB500EOtterScriptGrammarSourceArtifactVersionId bigint;
DECLARE @RDB500EOtterScriptCompendiumSourceArtifactVersionId bigint;
SELECT @RDB500EOtterScriptGrammarSourceArtifactVersionId = sav.SourceArtifactVersionId
FROM [ATAPUtilities].[SourceArtifact] sa
JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId = sa.SourceArtifactId
WHERE sa.LocatorTypeCode = 'RepositoryPath'
  AND sa.RepoRelativePathOrExternalLocator = N'SolutionDocumentation/grammers/OtterScript.grammar.ebnf'
  AND sav.NormalizedContentSha256 = '0290a5895028efb2d40f9709f39639753b78d742d96876eaebd747f212f0fcee';
SELECT @RDB500EOtterScriptCompendiumSourceArtifactVersionId = sav.SourceArtifactVersionId
FROM [ATAPUtilities].[SourceArtifact] sa
JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId = sa.SourceArtifactId
WHERE sa.LocatorTypeCode = 'RepositoryPath'
  AND sa.RepoRelativePathOrExternalLocator = N'SolutionDocumentation/Rules Compendium.OtterScript.md'
  AND sav.NormalizedContentSha256 = '4560874096cc1375971579735f85eafcc495bf5adbc51596e8baac47d7fb5f1b';
IF @RDB500EOtterScriptGrammarSourceArtifactVersionId IS NULL OR @RDB500EOtterScriptCompendiumSourceArtifactVersionId IS NULL
    THROW 55500, 'RDB-500E requires exact grammar and compendium SourceArtifactVersion rows.', 1;

DECLARE @RDB500EOtterScriptRuleKindTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind');
DECLARE @RDB500EOtterScriptRuleKindVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind-version');
DECLARE @RDB500EOtterScriptValueTypeTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type');
DECLARE @RDB500EOtterScriptValueTypeVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type-version');
DECLARE @RDB500EOtterScriptPrimitiveTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive');
DECLARE @RDB500EOtterScriptPrimitiveVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-version');
DECLARE @RDB500EOtterScriptPrimitiveInputTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-input-definition');
DECLARE @RDB500EOtterScriptRuleTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule');
DECLARE @RDB500EOtterScriptRuleVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-version');
DECLARE @RDB500EOtterScriptRuleInputTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-input-definition');
DECLARE @RDB500EOtterScriptRuleDefaultTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-default-input-value');
IF @RDB500EOtterScriptRuleKindTypeId IS NULL OR @RDB500EOtterScriptRuleDefaultTypeId IS NULL
    THROW 55501, 'RDB-500E requires the frozen RDB-320 EntityType catalog.', 1;
IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ExecutionClassification] WHERE ExecutionClassificationCode='metadata-only' AND AllowsExecutorContract=0)
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[SecurityCapabilityClassification] WHERE SecurityCapabilityCode='reference-safe')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RoundTripPolicy] WHERE RoundTripPolicyCode='semantic')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ScalarStorageKind] WHERE ScalarStorageKindCode='bounded-unicode-text')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[BindingShape] WHERE BindingShapeCode='constant')
    THROW 55502, 'RDB-500E requires coordinator-owned closed catalog rows.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @RDB500EOtterScriptEntityId bigint;
    DECLARE @RDB500EOtterScriptRuleKindId bigint;
    DECLARE @RDB500EOtterScriptRuleKindVersionId bigint;
    DECLARE @RDB500EOtterScriptValueTypeId bigint;
    DECLARE @RDB500EOtterScriptValueTypeVersionId bigint;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'OtterScript')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500EOtterScriptRuleKindTypeId,'18cb04cd-2bc2-5e1c-a94e-71ecd54c5e89',@RDB500EOtterScriptNow);
        SET @RDB500EOtterScriptEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleKind](RuleKindPhiloteId,EntityId,EntityTypeId,RuleKindCode,CreatedAtUtc)
        VALUES('18cb04cd-2bc2-5e1c-a94e-71ecd54c5e89',@RDB500EOtterScriptEntityId,@RDB500EOtterScriptRuleKindTypeId,N'OtterScript',@RDB500EOtterScriptNow);
    END;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'OtterScript' AND RuleKindPhiloteId<>'18cb04cd-2bc2-5e1c-a94e-71ecd54c5e89')
        THROW 55503, 'RDB-500E RuleKind natural key maps to a different Philote.', 1;
    SELECT @RDB500EOtterScriptRuleKindId=RuleKindId FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'OtterScript';

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500EOtterScriptRuleKindId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500EOtterScriptRuleKindVersionTypeId,'b39da92f-b183-5792-a1f9-53e62b1505f5',@RDB500EOtterScriptNow);
        SET @RDB500EOtterScriptEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleKindVersion]
          (RuleKindVersionPhiloteId,EntityId,EntityTypeId,RuleKindId,RevisionSequence,PredecessorRuleKindVersionId,
           GrammarSourceArtifactVersionId,GrammarHashAlgorithmCode,GrammarContentHash,CompendiumSourceArtifactVersionId,
           CompendiumHashAlgorithmCode,CompendiumContentHash,ExecutorContractVersionId,ExecutionClassificationCode,
           SecurityCapabilityCode,RoundTripPolicyCode,PublishedAtUtc)
        VALUES('b39da92f-b183-5792-a1f9-53e62b1505f5',@RDB500EOtterScriptEntityId,@RDB500EOtterScriptRuleKindVersionTypeId,@RDB500EOtterScriptRuleKindId,1,NULL,
          @RDB500EOtterScriptGrammarSourceArtifactVersionId,'SHA-256',0x0290a5895028efb2d40f9709f39639753b78d742d96876eaebd747f212f0fcee,@RDB500EOtterScriptCompendiumSourceArtifactVersionId,
          'SHA-256',0x4560874096cc1375971579735f85eafcc495bf5adbc51596e8baac47d7fb5f1b,NULL,'metadata-only','reference-safe','semantic',@RDB500EOtterScriptNow);
    END;
    SELECT @RDB500EOtterScriptRuleKindVersionId=RuleKindVersionId FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500EOtterScriptRuleKindId AND RevisionSequence=1;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-otterscript-text')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500EOtterScriptValueTypeTypeId,'f5ec2b7f-64a0-5317-ad85-bfdab9f737b5',@RDB500EOtterScriptNow);
        SET @RDB500EOtterScriptEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[ValueType](ValueTypePhiloteId,EntityId,EntityTypeId,ValueTypeCode,CreatedAtUtc)
        VALUES('f5ec2b7f-64a0-5317-ad85-bfdab9f737b5',@RDB500EOtterScriptEntityId,@RDB500EOtterScriptValueTypeTypeId,'seed-otterscript-text',@RDB500EOtterScriptNow);
    END;
    SELECT @RDB500EOtterScriptValueTypeId=ValueTypeId FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-otterscript-text';
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500EOtterScriptValueTypeId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500EOtterScriptValueTypeVersionTypeId,'dbbadb32-a8d2-56c8-8e30-3ea247b9bf55',@RDB500EOtterScriptNow);
        SET @RDB500EOtterScriptEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[ValueTypeVersion]
          (ValueTypeVersionPhiloteId,EntityId,EntityTypeId,ValueTypeId,RevisionSequence,PredecessorValueTypeVersionId,
           ValueCategoryCode,ScalarStorageKindCode,StructuredValueContractVersionId,ElementValueTypeVersionId,
           CollectionOrderingCode,SecretReferencePolicyId,ValidationContractCode,PublishedAtUtc)
        VALUES('dbbadb32-a8d2-56c8-8e30-3ea247b9bf55',@RDB500EOtterScriptEntityId,@RDB500EOtterScriptValueTypeVersionTypeId,@RDB500EOtterScriptValueTypeId,1,NULL,
          'scalar','bounded-unicode-text',NULL,NULL,NULL,NULL,'non-empty-text',@RDB500EOtterScriptNow);
    END;
    SELECT @RDB500EOtterScriptValueTypeVersionId=ValueTypeVersionId FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500EOtterScriptValueTypeId AND RevisionSequence=1;

    DECLARE @RDB500EOtterScriptPrimitives TABLE(PrimitivePhiloteId uniqueidentifier,PrimitiveVersionPhiloteId uniqueidentifier,
      InputPhiloteId uniqueidentifier,PrimitiveCode varchar(128),DefinitionText nvarchar(max));
    INSERT @RDB500EOtterScriptPrimitives VALUES
        ('99bdfd9a-f48a-4398-add4-003dc1877751', '1f7b5817-d36d-5b56-84f2-162e744e762c', '287e4c92-0a81-54c7-9c0c-dc41113110ea', N'<otter-plan>', N'Top-level OtterScript plan containing ordered statements and blocks.'),
        ('416f4f37-2f36-4a60-b90a-a41e4407bab3', 'd3232a53-42c7-53b9-a910-afc1e69a027c', 'f19c108b-e7f0-5ce9-820f-1fbe740ba7f5', N'<otter-set-variable>', N'Variable assignment using OtterScript set syntax.'),
        ('db4c13a8-90d9-4413-b817-dcb38613de5c', 'a1fedb6f-7d01-51e0-967a-26eb6ee448da', '81f2c501-3834-5aec-822d-3bab443a74b9', N'<otter-if-block>', N'Conditional execution block for tier-specific pipeline stages.'),
        ('d7f33ea3-fb8d-4394-b281-2696e13e815b', 'f1144539-b1fe-5912-9806-2ef8544d5c9f', '9dba5b5a-66aa-5b00-8f7d-b2968270bc89', N'<otter-foreach-block>', N'Foreach loop over a collection expression.'),
        ('0fdc4fcc-7434-4160-baa6-db89e530044a', 'f0172a42-f6ee-5e80-a028-eedee589c993', '86b95363-798d-5957-9289-fdb98f3b00b8', N'<otter-exec-step>', N'Generic Exec operation that invokes an external command.'),
        ('5283f51b-1b3e-48b2-baed-d42e57979603', '55aae2b0-e554-5a4e-a868-85cf843d2e9e', '47617a25-e9cf-5a2e-8206-287c08371a9a', N'<dotnet-pack-step>', N'Dotnet pack Exec operation for producing NuGet packages.'),
        ('25c22691-48da-4f46-a4ea-ac0b5b5f50bc', 'e0ccfdc9-ae27-59bf-a638-5cd9027aecf1', '9c73fba7-2530-5f3b-aff6-e5e1f86e1b9b', N'<proget-nuget-push-step>', N'SecretName-only ProGet feed publication operation.'),
        ('77ecc33b-bf1b-434b-b972-6371dbc09f37', '78c57c2a-0487-514d-9fb5-0f35297b9ce4', 'daf13a9f-06c1-5e82-9c1b-b0d855b4464b', N'<create-artifact-step>', N'BuildMaster Create-Artifact operation.'),
        ('c12eeb76-53ad-45dd-8d05-8ab773c30a22', '9eff3236-3433-580b-b8b0-c5d8d0a656da', 'dadf4793-f930-5025-9dab-9040a82fc3e1', N'<otter-log-step>', N'BuildMaster diagnostic log statement.');
    DECLARE @RDB500EOtterScriptPrimitivePhiloteId uniqueidentifier,@RDB500EOtterScriptPrimitiveVersionPhiloteId uniqueidentifier,
      @RDB500EOtterScriptInputPhiloteId uniqueidentifier,@RDB500EOtterScriptPrimitiveCode varchar(128),@RDB500EOtterScriptDefinitionText nvarchar(max),
      @RDB500EOtterScriptPrimitiveId bigint,@RDB500EOtterScriptPrimitiveVersionId bigint;
    DECLARE RDB500EOtterScriptPrimitiveCursor CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @RDB500EOtterScriptPrimitives ORDER BY PrimitiveCode;
    OPEN RDB500EOtterScriptPrimitiveCursor;
    FETCH NEXT FROM RDB500EOtterScriptPrimitiveCursor INTO @RDB500EOtterScriptPrimitivePhiloteId,@RDB500EOtterScriptPrimitiveVersionPhiloteId,@RDB500EOtterScriptInputPhiloteId,@RDB500EOtterScriptPrimitiveCode,@RDB500EOtterScriptDefinitionText;
    WHILE @@FETCH_STATUS=0
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500EOtterScriptRuleKindId AND PrimitiveCode=@RDB500EOtterScriptPrimitiveCode)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500EOtterScriptPrimitiveTypeId,@RDB500EOtterScriptPrimitivePhiloteId,@RDB500EOtterScriptNow);
        SET @RDB500EOtterScriptEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500EOtterScriptPrimitivePhiloteId,@RDB500EOtterScriptEntityId,@RDB500EOtterScriptPrimitiveTypeId,@RDB500EOtterScriptRuleKindId,@RDB500EOtterScriptPrimitiveCode,@RDB500EOtterScriptNow);
      END;
      IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500EOtterScriptRuleKindId AND PrimitiveCode=@RDB500EOtterScriptPrimitiveCode AND PrimitivePhiloteId<>@RDB500EOtterScriptPrimitivePhiloteId)
        THROW 55504, 'RDB-500E Primitive natural key maps to a different Philote.', 1;
      SELECT @RDB500EOtterScriptPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500EOtterScriptRuleKindId AND PrimitiveCode=@RDB500EOtterScriptPrimitiveCode;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500EOtterScriptPrimitiveId AND RevisionSequence=1)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500EOtterScriptPrimitiveVersionTypeId,@RDB500EOtterScriptPrimitiveVersionPhiloteId,@RDB500EOtterScriptNow);
        SET @RDB500EOtterScriptEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,
           PredecessorPrimitiveVersionId,GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,
           DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500EOtterScriptPrimitiveVersionPhiloteId,@RDB500EOtterScriptEntityId,@RDB500EOtterScriptPrimitiveVersionTypeId,@RDB500EOtterScriptPrimitiveId,
          @RDB500EOtterScriptRuleKindId,@RDB500EOtterScriptRuleKindVersionId,1,NULL,@RDB500EOtterScriptPrimitiveCode,@RDB500EOtterScriptDefinitionText,'SHA-256',
          HASHBYTES('SHA2_256',@RDB500EOtterScriptDefinitionText),@RDB500EOtterScriptValueTypeVersionId,1,1,@RDB500EOtterScriptNow);
      END;
      SELECT @RDB500EOtterScriptPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500EOtterScriptPrimitiveId AND RevisionSequence=1;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500EOtterScriptPrimitiveVersionId AND InputCode='content')
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500EOtterScriptPrimitiveInputTypeId,@RDB500EOtterScriptInputPhiloteId,@RDB500EOtterScriptNow);
        SET @RDB500EOtterScriptEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,
           ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500EOtterScriptInputPhiloteId,@RDB500EOtterScriptEntityId,@RDB500EOtterScriptPrimitiveInputTypeId,@RDB500EOtterScriptPrimitiveVersionId,
          'content',0,@RDB500EOtterScriptValueTypeVersionId,1,1,0,'non-empty-text');
      END;
      FETCH NEXT FROM RDB500EOtterScriptPrimitiveCursor INTO @RDB500EOtterScriptPrimitivePhiloteId,@RDB500EOtterScriptPrimitiveVersionPhiloteId,@RDB500EOtterScriptInputPhiloteId,@RDB500EOtterScriptPrimitiveCode,@RDB500EOtterScriptDefinitionText;
    END;
    CLOSE RDB500EOtterScriptPrimitiveCursor; DEALLOCATE RDB500EOtterScriptPrimitiveCursor;

    DECLARE @RDB500EOtterScriptRootPrimitiveVersionId bigint,@RDB500EOtterScriptRootPrimitiveInputId bigint;
    SELECT @RDB500EOtterScriptRootPrimitiveVersionId=pv.PrimitiveVersionId,@RDB500EOtterScriptRootPrimitiveInputId=pid.PrimitiveInputDefinitionId
    FROM [ATAPUtilities].[Primitive] p JOIN [ATAPUtilities].[PrimitiveVersion] pv ON pv.PrimitiveId=p.PrimitiveId AND pv.RevisionSequence=1
    JOIN [ATAPUtilities].[PrimitiveInputDefinition] pid ON pid.PrimitiveVersionId=pv.PrimitiveVersionId AND pid.InputCode='content'
    WHERE p.RuleKindId=@RDB500EOtterScriptRuleKindId AND p.PrimitiveCode=N'<otter-plan>';
    IF @RDB500EOtterScriptRootPrimitiveInputId IS NULL THROW 55505, 'RDB-500E top primitive/input was not materialized.', 1;

    DECLARE @RDB500EOtterScriptRules TABLE(RulePhiloteId uniqueidentifier,RuleVersionPhiloteId uniqueidentifier,
      RuleInputPhiloteId uniqueidentifier,DefaultPhiloteId uniqueidentifier,NodePhiloteId uniqueidentifier,
      RuleCode varchar(128),Purpose nvarchar(max),DefaultValue nvarchar(max),SourceFileReference nvarchar(2048));
    INSERT @RDB500EOtterScriptRules VALUES
        ('308163fe-e4e2-5b69-9437-ee583895232b', '6715023a-99f1-55a4-9781-58a3faaf7194', '4f8a7dba-38da-5039-8d82-0faea07011f8', '9df0929e-f691-5d34-9ce4-4d509574ff2c', '2ab062df-5fbf-55f1-8413-eceeff1f38d0', N'SafePackagePlan', N'Render an approval-gated package plan using SecretName references only.', N'PlanName=ReferencePackagePlan', N'SolutionDocumentation/Rules Compendium.OtterScript.md#worked-example');
    DECLARE @RDB500EOtterScriptRulePhiloteId uniqueidentifier,@RDB500EOtterScriptRuleVersionPhiloteId uniqueidentifier,
      @RDB500EOtterScriptRuleInputPhiloteId uniqueidentifier,@RDB500EOtterScriptDefaultPhiloteId uniqueidentifier,@RDB500EOtterScriptNodePhiloteId uniqueidentifier,
      @RDB500EOtterScriptRuleCode varchar(128),@RDB500EOtterScriptPurpose nvarchar(max),@RDB500EOtterScriptDefaultValue nvarchar(max),@RDB500EOtterScriptSourceFileReference nvarchar(2048),
      @RDB500EOtterScriptRuleId bigint,@RDB500EOtterScriptRuleVersionId bigint,@RDB500EOtterScriptRuleInputId bigint,@RDB500EOtterScriptNodeId bigint;
    DECLARE RDB500EOtterScriptRuleCursor CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @RDB500EOtterScriptRules ORDER BY RuleCode;
    OPEN RDB500EOtterScriptRuleCursor;
    FETCH NEXT FROM RDB500EOtterScriptRuleCursor INTO @RDB500EOtterScriptRulePhiloteId,@RDB500EOtterScriptRuleVersionPhiloteId,@RDB500EOtterScriptRuleInputPhiloteId,@RDB500EOtterScriptDefaultPhiloteId,@RDB500EOtterScriptNodePhiloteId,@RDB500EOtterScriptRuleCode,@RDB500EOtterScriptPurpose,@RDB500EOtterScriptDefaultValue,@RDB500EOtterScriptSourceFileReference;
    WHILE @@FETCH_STATUS=0
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500EOtterScriptRuleKindId AND RuleCode=@RDB500EOtterScriptRuleCode)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500EOtterScriptRuleTypeId,@RDB500EOtterScriptRulePhiloteId,@RDB500EOtterScriptNow);
        SET @RDB500EOtterScriptEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Rule](RulePhiloteId,EntityId,EntityTypeId,RuleKindId,RuleCode,CreatedAtUtc)
        VALUES(@RDB500EOtterScriptRulePhiloteId,@RDB500EOtterScriptEntityId,@RDB500EOtterScriptRuleTypeId,@RDB500EOtterScriptRuleKindId,@RDB500EOtterScriptRuleCode,@RDB500EOtterScriptNow);
      END;
      IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500EOtterScriptRuleKindId AND RuleCode=@RDB500EOtterScriptRuleCode AND RulePhiloteId<>@RDB500EOtterScriptRulePhiloteId)
        THROW 55506, 'RDB-500E Rule natural key maps to a different Philote.', 1;
      SELECT @RDB500EOtterScriptRuleId=RuleId FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500EOtterScriptRuleKindId AND RuleCode=@RDB500EOtterScriptRuleCode;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500EOtterScriptRuleId AND RevisionSequence=1)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500EOtterScriptRuleVersionTypeId,@RDB500EOtterScriptRuleVersionPhiloteId,@RDB500EOtterScriptNow);
        SET @RDB500EOtterScriptEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleVersion]
          (RuleVersionPhiloteId,EntityId,EntityTypeId,RuleId,RuleKindId,RuleKindVersionId,RevisionSequence,
           PredecessorRuleVersionId,CompositionHashAlgorithmCode,CompositionContentHash,PublishedAtUtc)
        VALUES(@RDB500EOtterScriptRuleVersionPhiloteId,@RDB500EOtterScriptEntityId,@RDB500EOtterScriptRuleVersionTypeId,@RDB500EOtterScriptRuleId,@RDB500EOtterScriptRuleKindId,
          @RDB500EOtterScriptRuleKindVersionId,1,NULL,'SHA-256',HASHBYTES('SHA2_256',CONCAT(@RDB500EOtterScriptRuleCode,N'|',@RDB500EOtterScriptPurpose,N'|',@RDB500EOtterScriptSourceFileReference)),@RDB500EOtterScriptNow);
      END;
      SELECT @RDB500EOtterScriptRuleVersionId=RuleVersionId FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500EOtterScriptRuleId AND RevisionSequence=1;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500EOtterScriptRuleVersionId AND InputCode='content')
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500EOtterScriptRuleInputTypeId,@RDB500EOtterScriptRuleInputPhiloteId,@RDB500EOtterScriptNow);
        SET @RDB500EOtterScriptEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleInputDefinition]
          (RuleInputDefinitionPhiloteId,EntityId,EntityTypeId,RuleVersionId,InputCode,Ordinal,ValueTypeVersionId,
           MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500EOtterScriptRuleInputPhiloteId,@RDB500EOtterScriptEntityId,@RDB500EOtterScriptRuleInputTypeId,@RDB500EOtterScriptRuleVersionId,
          'content',0,@RDB500EOtterScriptValueTypeVersionId,1,1,0,'non-empty-text');
      END;
      SELECT @RDB500EOtterScriptRuleInputId=RuleInputDefinitionId FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500EOtterScriptRuleVersionId AND InputCode='content';
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleDefaultInputValue] WHERE RuleInputDefinitionId=@RDB500EOtterScriptRuleInputId)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500EOtterScriptRuleDefaultTypeId,@RDB500EOtterScriptDefaultPhiloteId,@RDB500EOtterScriptNow);
        SET @RDB500EOtterScriptEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleDefaultInputValue]
          (RuleDefaultInputValuePhiloteId,EntityId,EntityTypeId,RuleInputDefinitionId,RuleVersionId,ValueTypeVersionId,
           CanonicalTextValue,CanonicalValueHash,RationaleEntityId,RationaleEntityTypeId,PublishedAtUtc)
        VALUES(@RDB500EOtterScriptDefaultPhiloteId,@RDB500EOtterScriptEntityId,@RDB500EOtterScriptRuleDefaultTypeId,@RDB500EOtterScriptRuleInputId,@RDB500EOtterScriptRuleVersionId,
          @RDB500EOtterScriptValueTypeVersionId,@RDB500EOtterScriptDefaultValue,HASHBYTES('SHA2_256',@RDB500EOtterScriptDefaultValue),
          (SELECT EntityId FROM [ATAPUtilities].[Rule] WHERE RuleId=@RDB500EOtterScriptRuleId),@RDB500EOtterScriptRuleTypeId,@RDB500EOtterScriptNow);
      END;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId=@RDB500EOtterScriptNodePhiloteId)
        INSERT [ATAPUtilities].[RuleVersionNode]
          (RuleVersionNodePhiloteId,RuleVersionId,RuleKindVersionId,ParentRuleVersionNodeId,Ordinal,PrimitiveVersionId,
           MinOccurs,MaxOccurs,ChoiceDiscriminatorCode,NodeLabel)
        VALUES(@RDB500EOtterScriptNodePhiloteId,@RDB500EOtterScriptRuleVersionId,@RDB500EOtterScriptRuleKindVersionId,NULL,0,@RDB500EOtterScriptRootPrimitiveVersionId,1,1,NULL,N'root');
      SELECT @RDB500EOtterScriptNodeId=RuleVersionNodeId FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId=@RDB500EOtterScriptNodePhiloteId;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNodeInput] WHERE RuleVersionNodeId=@RDB500EOtterScriptNodeId AND PrimitiveInputDefinitionId=@RDB500EOtterScriptRootPrimitiveInputId)
        INSERT [ATAPUtilities].[RuleVersionNodeInput]
          (RuleVersionNodeId,RuleVersionId,PrimitiveVersionId,PrimitiveInputDefinitionId,BindingShapeCode,
           TargetValueTypeVersionId,SourceValueTypeVersionId,ConstantValueTypeVersionId,RuleInputDefinitionId,
           DerivationContractVersionId,ConversionPolicyCode,CanonicalTextValue,CanonicalValueHash)
        VALUES(@RDB500EOtterScriptNodeId,@RDB500EOtterScriptRuleVersionId,@RDB500EOtterScriptRootPrimitiveVersionId,@RDB500EOtterScriptRootPrimitiveInputId,
          'constant',@RDB500EOtterScriptValueTypeVersionId,NULL,@RDB500EOtterScriptValueTypeVersionId,NULL,NULL,NULL,@RDB500EOtterScriptDefaultValue,
          HASHBYTES('SHA2_256',@RDB500EOtterScriptDefaultValue));
      FETCH NEXT FROM RDB500EOtterScriptRuleCursor INTO @RDB500EOtterScriptRulePhiloteId,@RDB500EOtterScriptRuleVersionPhiloteId,@RDB500EOtterScriptRuleInputPhiloteId,@RDB500EOtterScriptDefaultPhiloteId,@RDB500EOtterScriptNodePhiloteId,@RDB500EOtterScriptRuleCode,@RDB500EOtterScriptPurpose,@RDB500EOtterScriptDefaultValue,@RDB500EOtterScriptSourceFileReference;
    END;
    CLOSE RDB500EOtterScriptRuleCursor; DEALLOCATE RDB500EOtterScriptRuleCursor;

    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500EOtterScriptRuleKindId) < 9
      THROW 55507, 'RDB-500E primitive row-count postcondition failed.', 1;
    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500EOtterScriptRuleKindId) < 1
      THROW 55508, 'RDB-500E rule row-count postcondition failed.', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','RDB500EOtterScriptPrimitiveCursor') >= -1 BEGIN CLOSE RDB500EOtterScriptPrimitiveCursor; DEALLOCATE RDB500EOtterScriptPrimitiveCursor; END;
    IF CURSOR_STATUS('local','RDB500EOtterScriptRuleCursor') >= -1 BEGIN CLOSE RDB500EOtterScriptRuleCursor; DEALLOCATE RDB500EOtterScriptRuleCursor; END;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
/* END INTEGRATED FRAGMENT: RDB-500E__OtterScript.sql */

/* BEGIN INTEGRATED FRAGMENT: RDB-500F__AgentText.sql */
/* Generated RRSBS Wave 6 seed fragment: RDB-500F.
   Owner boundary: RDB-500F only. Do not integrate by editing this file;
   RDB-510 is the sole final seed integrator. Deferred kinds: . */
/* RDB-500F / AgentText reference seed.
   Positive: A generated-wrapper adapter records its canonical source identity and semantic round-trip policy.
   Negative (declarative; exercised by RDB-510): An adapter with an absolute user path, embedded secret, or undeclared materialization mode is rejected.
   Integration prerequisites are coordinator-owned and fail closed below. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @RDB500FAgentTextNow datetime2(7) = CONVERT(datetime2(7), '2026-08-06T00:00:00.0000000Z', 127);
DECLARE @RDB500FAgentTextGrammarSourceArtifactVersionId bigint;
DECLARE @RDB500FAgentTextCompendiumSourceArtifactVersionId bigint;
SELECT @RDB500FAgentTextGrammarSourceArtifactVersionId = sav.SourceArtifactVersionId
FROM [ATAPUtilities].[SourceArtifact] sa
JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId = sa.SourceArtifactId
WHERE sa.LocatorTypeCode = 'RepositoryPath'
  AND sa.RepoRelativePathOrExternalLocator = N'SolutionDocumentation/grammers/AgentText.grammar.ebnf'
  AND sav.NormalizedContentSha256 = '46605f3ca3e00f790a0de010c853f0f028b6a71e0436bdbe38eaf19869ff2183';
SELECT @RDB500FAgentTextCompendiumSourceArtifactVersionId = sav.SourceArtifactVersionId
FROM [ATAPUtilities].[SourceArtifact] sa
JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId = sa.SourceArtifactId
WHERE sa.LocatorTypeCode = 'RepositoryPath'
  AND sa.RepoRelativePathOrExternalLocator = N'SolutionDocumentation/Rules Compendium.AgentText.md'
  AND sav.NormalizedContentSha256 = '9db875d19db9192648cc0f096d2fc60236cb95858711da98f0a7769aef8b720d';
IF @RDB500FAgentTextGrammarSourceArtifactVersionId IS NULL OR @RDB500FAgentTextCompendiumSourceArtifactVersionId IS NULL
    THROW 55500, 'RDB-500F requires exact grammar and compendium SourceArtifactVersion rows.', 1;

DECLARE @RDB500FAgentTextRuleKindTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind');
DECLARE @RDB500FAgentTextRuleKindVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind-version');
DECLARE @RDB500FAgentTextValueTypeTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type');
DECLARE @RDB500FAgentTextValueTypeVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type-version');
DECLARE @RDB500FAgentTextPrimitiveTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive');
DECLARE @RDB500FAgentTextPrimitiveVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-version');
DECLARE @RDB500FAgentTextPrimitiveInputTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-input-definition');
DECLARE @RDB500FAgentTextRuleTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule');
DECLARE @RDB500FAgentTextRuleVersionTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-version');
DECLARE @RDB500FAgentTextRuleInputTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-input-definition');
DECLARE @RDB500FAgentTextRuleDefaultTypeId bigint = (SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-default-input-value');
IF @RDB500FAgentTextRuleKindTypeId IS NULL OR @RDB500FAgentTextRuleDefaultTypeId IS NULL
    THROW 55501, 'RDB-500F requires the frozen RDB-320 EntityType catalog.', 1;
IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ExecutionClassification] WHERE ExecutionClassificationCode='metadata-only' AND AllowsExecutorContract=0)
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[SecurityCapabilityClassification] WHERE SecurityCapabilityCode='reference-safe')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RoundTripPolicy] WHERE RoundTripPolicyCode='semantic')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ScalarStorageKind] WHERE ScalarStorageKindCode='bounded-unicode-text')
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[BindingShape] WHERE BindingShapeCode='constant')
    THROW 55502, 'RDB-500F requires coordinator-owned closed catalog rows.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @RDB500FAgentTextEntityId bigint;
    DECLARE @RDB500FAgentTextRuleKindId bigint;
    DECLARE @RDB500FAgentTextRuleKindVersionId bigint;
    DECLARE @RDB500FAgentTextValueTypeId bigint;
    DECLARE @RDB500FAgentTextValueTypeVersionId bigint;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'AgentText')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500FAgentTextRuleKindTypeId,'831c7624-d9d5-5e0c-803b-49781822a8dd',@RDB500FAgentTextNow);
        SET @RDB500FAgentTextEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleKind](RuleKindPhiloteId,EntityId,EntityTypeId,RuleKindCode,CreatedAtUtc)
        VALUES('831c7624-d9d5-5e0c-803b-49781822a8dd',@RDB500FAgentTextEntityId,@RDB500FAgentTextRuleKindTypeId,N'AgentText',@RDB500FAgentTextNow);
    END;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'AgentText' AND RuleKindPhiloteId<>'831c7624-d9d5-5e0c-803b-49781822a8dd')
        THROW 55503, 'RDB-500F RuleKind natural key maps to a different Philote.', 1;
    SELECT @RDB500FAgentTextRuleKindId=RuleKindId FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode=N'AgentText';

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500FAgentTextRuleKindId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500FAgentTextRuleKindVersionTypeId,'27668824-831f-5030-a518-dfa34a22bdac',@RDB500FAgentTextNow);
        SET @RDB500FAgentTextEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleKindVersion]
          (RuleKindVersionPhiloteId,EntityId,EntityTypeId,RuleKindId,RevisionSequence,PredecessorRuleKindVersionId,
           GrammarSourceArtifactVersionId,GrammarHashAlgorithmCode,GrammarContentHash,CompendiumSourceArtifactVersionId,
           CompendiumHashAlgorithmCode,CompendiumContentHash,ExecutorContractVersionId,ExecutionClassificationCode,
           SecurityCapabilityCode,RoundTripPolicyCode,PublishedAtUtc)
        VALUES('27668824-831f-5030-a518-dfa34a22bdac',@RDB500FAgentTextEntityId,@RDB500FAgentTextRuleKindVersionTypeId,@RDB500FAgentTextRuleKindId,1,NULL,
          @RDB500FAgentTextGrammarSourceArtifactVersionId,'SHA-256',0x46605f3ca3e00f790a0de010c853f0f028b6a71e0436bdbe38eaf19869ff2183,@RDB500FAgentTextCompendiumSourceArtifactVersionId,
          'SHA-256',0x9db875d19db9192648cc0f096d2fc60236cb95858711da98f0a7769aef8b720d,NULL,'metadata-only','reference-safe','semantic',@RDB500FAgentTextNow);
    END;
    SELECT @RDB500FAgentTextRuleKindVersionId=RuleKindVersionId FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500FAgentTextRuleKindId AND RevisionSequence=1;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-agenttext-text')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500FAgentTextValueTypeTypeId,'a50c038e-93c6-5cd9-8592-1b6c60d658d3',@RDB500FAgentTextNow);
        SET @RDB500FAgentTextEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[ValueType](ValueTypePhiloteId,EntityId,EntityTypeId,ValueTypeCode,CreatedAtUtc)
        VALUES('a50c038e-93c6-5cd9-8592-1b6c60d658d3',@RDB500FAgentTextEntityId,@RDB500FAgentTextValueTypeTypeId,'seed-agenttext-text',@RDB500FAgentTextNow);
    END;
    SELECT @RDB500FAgentTextValueTypeId=ValueTypeId FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-agenttext-text';
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500FAgentTextValueTypeId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500FAgentTextValueTypeVersionTypeId,'7d88758d-c693-53b0-ab34-bb8b11d1d448',@RDB500FAgentTextNow);
        SET @RDB500FAgentTextEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[ValueTypeVersion]
          (ValueTypeVersionPhiloteId,EntityId,EntityTypeId,ValueTypeId,RevisionSequence,PredecessorValueTypeVersionId,
           ValueCategoryCode,ScalarStorageKindCode,StructuredValueContractVersionId,ElementValueTypeVersionId,
           CollectionOrderingCode,SecretReferencePolicyId,ValidationContractCode,PublishedAtUtc)
        VALUES('7d88758d-c693-53b0-ab34-bb8b11d1d448',@RDB500FAgentTextEntityId,@RDB500FAgentTextValueTypeVersionTypeId,@RDB500FAgentTextValueTypeId,1,NULL,
          'scalar','bounded-unicode-text',NULL,NULL,NULL,NULL,'non-empty-text',@RDB500FAgentTextNow);
    END;
    SELECT @RDB500FAgentTextValueTypeVersionId=ValueTypeVersionId FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500FAgentTextValueTypeId AND RevisionSequence=1;

    DECLARE @RDB500FAgentTextPrimitives TABLE(PrimitivePhiloteId uniqueidentifier,PrimitiveVersionPhiloteId uniqueidentifier,
      InputPhiloteId uniqueidentifier,PrimitiveCode varchar(128),DefinitionText nvarchar(max));
    INSERT @RDB500FAgentTextPrimitives VALUES
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4be01', '6d653b62-c98d-5de7-97e0-0ed69ded3a0b', '64592ace-9e82-5a22-aecb-daf9a5362755', N'agent-identity', N'Retained AgentText agent-identity grammar production.'),
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4be02', 'd1cb97fd-4411-50cd-9012-9603fe9f74ab', '653b23ff-f166-5cdd-ad01-23df43f2d80f', N'instruction-body', N'Retained AgentText instruction-body grammar production.'),
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4be03', '694007c7-900d-5dac-abbc-a776b7d0f707', '7ce1a7e4-7a14-5baf-b0d0-002fe98796f5', N'tool-surface', N'Retained AgentText tool-surface grammar production.'),
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4be04', 'b49f7a63-514a-5a8b-bafa-aac385c6e6ac', '0966e373-3be8-5bba-95ba-c6d4e19b86ab', N'runbook-step', N'Retained AgentText runbook-step grammar production.'),
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4be05', 'fe3a61d5-0273-5dcb-9872-bf22c70b4f15', '2712666f-c7eb-52fb-802f-5ffcdaef97da', N'guardrail', N'Retained AgentText guardrail grammar production.'),
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4be06', '25fc0d2f-ebcb-57d0-8220-d1fb034ed98b', '5124e24a-c0b5-5250-b5d7-cc58dedbf40b', N'return-contract', N'Retained AgentText return-contract grammar production.'),
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4be07', '635acdfb-8942-5727-af94-f1865c8a9bfa', 'e76c53d7-f469-5eb9-8e8b-be8c2e50bff7', N'adapter-target', N'Retained AgentText adapter-target grammar production.'),
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4be08', '8353af3b-f2db-563b-9961-7c8d8e64c7a6', '8fe9b3c3-0269-5213-965b-a2a3a208e9fb', N'round-trip-policy', N'Retained AgentText round-trip-policy grammar production.');
    DECLARE @RDB500FAgentTextPrimitivePhiloteId uniqueidentifier,@RDB500FAgentTextPrimitiveVersionPhiloteId uniqueidentifier,
      @RDB500FAgentTextInputPhiloteId uniqueidentifier,@RDB500FAgentTextPrimitiveCode varchar(128),@RDB500FAgentTextDefinitionText nvarchar(max),
      @RDB500FAgentTextPrimitiveId bigint,@RDB500FAgentTextPrimitiveVersionId bigint;
    DECLARE RDB500FAgentTextPrimitiveCursor CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @RDB500FAgentTextPrimitives ORDER BY PrimitiveCode;
    OPEN RDB500FAgentTextPrimitiveCursor;
    FETCH NEXT FROM RDB500FAgentTextPrimitiveCursor INTO @RDB500FAgentTextPrimitivePhiloteId,@RDB500FAgentTextPrimitiveVersionPhiloteId,@RDB500FAgentTextInputPhiloteId,@RDB500FAgentTextPrimitiveCode,@RDB500FAgentTextDefinitionText;
    WHILE @@FETCH_STATUS=0
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500FAgentTextRuleKindId AND PrimitiveCode=@RDB500FAgentTextPrimitiveCode)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500FAgentTextPrimitiveTypeId,@RDB500FAgentTextPrimitivePhiloteId,@RDB500FAgentTextNow);
        SET @RDB500FAgentTextEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500FAgentTextPrimitivePhiloteId,@RDB500FAgentTextEntityId,@RDB500FAgentTextPrimitiveTypeId,@RDB500FAgentTextRuleKindId,@RDB500FAgentTextPrimitiveCode,@RDB500FAgentTextNow);
      END;
      IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500FAgentTextRuleKindId AND PrimitiveCode=@RDB500FAgentTextPrimitiveCode AND PrimitivePhiloteId<>@RDB500FAgentTextPrimitivePhiloteId)
        THROW 55504, 'RDB-500F Primitive natural key maps to a different Philote.', 1;
      SELECT @RDB500FAgentTextPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500FAgentTextRuleKindId AND PrimitiveCode=@RDB500FAgentTextPrimitiveCode;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500FAgentTextPrimitiveId AND RevisionSequence=1)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500FAgentTextPrimitiveVersionTypeId,@RDB500FAgentTextPrimitiveVersionPhiloteId,@RDB500FAgentTextNow);
        SET @RDB500FAgentTextEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,
           PredecessorPrimitiveVersionId,GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,
           DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500FAgentTextPrimitiveVersionPhiloteId,@RDB500FAgentTextEntityId,@RDB500FAgentTextPrimitiveVersionTypeId,@RDB500FAgentTextPrimitiveId,
          @RDB500FAgentTextRuleKindId,@RDB500FAgentTextRuleKindVersionId,1,NULL,@RDB500FAgentTextPrimitiveCode,@RDB500FAgentTextDefinitionText,'SHA-256',
          HASHBYTES('SHA2_256',@RDB500FAgentTextDefinitionText),@RDB500FAgentTextValueTypeVersionId,1,1,@RDB500FAgentTextNow);
      END;
      SELECT @RDB500FAgentTextPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500FAgentTextPrimitiveId AND RevisionSequence=1;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500FAgentTextPrimitiveVersionId AND InputCode='content')
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500FAgentTextPrimitiveInputTypeId,@RDB500FAgentTextInputPhiloteId,@RDB500FAgentTextNow);
        SET @RDB500FAgentTextEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,
           ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500FAgentTextInputPhiloteId,@RDB500FAgentTextEntityId,@RDB500FAgentTextPrimitiveInputTypeId,@RDB500FAgentTextPrimitiveVersionId,
          'content',0,@RDB500FAgentTextValueTypeVersionId,1,1,0,'non-empty-text');
      END;
      FETCH NEXT FROM RDB500FAgentTextPrimitiveCursor INTO @RDB500FAgentTextPrimitivePhiloteId,@RDB500FAgentTextPrimitiveVersionPhiloteId,@RDB500FAgentTextInputPhiloteId,@RDB500FAgentTextPrimitiveCode,@RDB500FAgentTextDefinitionText;
    END;
    CLOSE RDB500FAgentTextPrimitiveCursor; DEALLOCATE RDB500FAgentTextPrimitiveCursor;

    DECLARE @RDB500FAgentTextRootPrimitiveVersionId bigint,@RDB500FAgentTextRootPrimitiveInputId bigint;
    SELECT @RDB500FAgentTextRootPrimitiveVersionId=pv.PrimitiveVersionId,@RDB500FAgentTextRootPrimitiveInputId=pid.PrimitiveInputDefinitionId
    FROM [ATAPUtilities].[Primitive] p JOIN [ATAPUtilities].[PrimitiveVersion] pv ON pv.PrimitiveId=p.PrimitiveId AND pv.RevisionSequence=1
    JOIN [ATAPUtilities].[PrimitiveInputDefinition] pid ON pid.PrimitiveVersionId=pv.PrimitiveVersionId AND pid.InputCode='content'
    WHERE p.RuleKindId=@RDB500FAgentTextRuleKindId AND p.PrimitiveCode=N'agent-identity';
    IF @RDB500FAgentTextRootPrimitiveInputId IS NULL THROW 55505, 'RDB-500F top primitive/input was not materialized.', 1;

    DECLARE @RDB500FAgentTextRules TABLE(RulePhiloteId uniqueidentifier,RuleVersionPhiloteId uniqueidentifier,
      RuleInputPhiloteId uniqueidentifier,DefaultPhiloteId uniqueidentifier,NodePhiloteId uniqueidentifier,
      RuleCode varchar(128),Purpose nvarchar(max),DefaultValue nvarchar(max),SourceFileReference nvarchar(2048));
    INSERT @RDB500FAgentTextRules VALUES
        ('c3b4c3b8-7d41-41e4-8d85-793b83f4bf00', '23f46381-8023-544b-a184-3f3a319c78e0', 'a4609d7e-1eca-5de0-9969-f414ec8fdbce', 'e19fc4de-b1de-5c35-83a1-49bde1936cf1', 'a574ac65-7e7d-5f72-8fb4-cde9b2dc90dc', N'AgentTextDocument', N'Compose identity, instructions, tool surface, runbook, guardrails, return contract, adapter targets, and round-trip policy.', N'roundtrip semantic', N'SolutionDocumentation/Rules Compendium.AgentText.md#grammar');
    DECLARE @RDB500FAgentTextRulePhiloteId uniqueidentifier,@RDB500FAgentTextRuleVersionPhiloteId uniqueidentifier,
      @RDB500FAgentTextRuleInputPhiloteId uniqueidentifier,@RDB500FAgentTextDefaultPhiloteId uniqueidentifier,@RDB500FAgentTextNodePhiloteId uniqueidentifier,
      @RDB500FAgentTextRuleCode varchar(128),@RDB500FAgentTextPurpose nvarchar(max),@RDB500FAgentTextDefaultValue nvarchar(max),@RDB500FAgentTextSourceFileReference nvarchar(2048),
      @RDB500FAgentTextRuleId bigint,@RDB500FAgentTextRuleVersionId bigint,@RDB500FAgentTextRuleInputId bigint,@RDB500FAgentTextNodeId bigint;
    DECLARE RDB500FAgentTextRuleCursor CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @RDB500FAgentTextRules ORDER BY RuleCode;
    OPEN RDB500FAgentTextRuleCursor;
    FETCH NEXT FROM RDB500FAgentTextRuleCursor INTO @RDB500FAgentTextRulePhiloteId,@RDB500FAgentTextRuleVersionPhiloteId,@RDB500FAgentTextRuleInputPhiloteId,@RDB500FAgentTextDefaultPhiloteId,@RDB500FAgentTextNodePhiloteId,@RDB500FAgentTextRuleCode,@RDB500FAgentTextPurpose,@RDB500FAgentTextDefaultValue,@RDB500FAgentTextSourceFileReference;
    WHILE @@FETCH_STATUS=0
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500FAgentTextRuleKindId AND RuleCode=@RDB500FAgentTextRuleCode)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500FAgentTextRuleTypeId,@RDB500FAgentTextRulePhiloteId,@RDB500FAgentTextNow);
        SET @RDB500FAgentTextEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Rule](RulePhiloteId,EntityId,EntityTypeId,RuleKindId,RuleCode,CreatedAtUtc)
        VALUES(@RDB500FAgentTextRulePhiloteId,@RDB500FAgentTextEntityId,@RDB500FAgentTextRuleTypeId,@RDB500FAgentTextRuleKindId,@RDB500FAgentTextRuleCode,@RDB500FAgentTextNow);
      END;
      IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500FAgentTextRuleKindId AND RuleCode=@RDB500FAgentTextRuleCode AND RulePhiloteId<>@RDB500FAgentTextRulePhiloteId)
        THROW 55506, 'RDB-500F Rule natural key maps to a different Philote.', 1;
      SELECT @RDB500FAgentTextRuleId=RuleId FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500FAgentTextRuleKindId AND RuleCode=@RDB500FAgentTextRuleCode;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500FAgentTextRuleId AND RevisionSequence=1)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500FAgentTextRuleVersionTypeId,@RDB500FAgentTextRuleVersionPhiloteId,@RDB500FAgentTextNow);
        SET @RDB500FAgentTextEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleVersion]
          (RuleVersionPhiloteId,EntityId,EntityTypeId,RuleId,RuleKindId,RuleKindVersionId,RevisionSequence,
           PredecessorRuleVersionId,CompositionHashAlgorithmCode,CompositionContentHash,PublishedAtUtc)
        VALUES(@RDB500FAgentTextRuleVersionPhiloteId,@RDB500FAgentTextEntityId,@RDB500FAgentTextRuleVersionTypeId,@RDB500FAgentTextRuleId,@RDB500FAgentTextRuleKindId,
          @RDB500FAgentTextRuleKindVersionId,1,NULL,'SHA-256',HASHBYTES('SHA2_256',CONCAT(@RDB500FAgentTextRuleCode,N'|',@RDB500FAgentTextPurpose,N'|',@RDB500FAgentTextSourceFileReference)),@RDB500FAgentTextNow);
      END;
      SELECT @RDB500FAgentTextRuleVersionId=RuleVersionId FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500FAgentTextRuleId AND RevisionSequence=1;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500FAgentTextRuleVersionId AND InputCode='content')
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500FAgentTextRuleInputTypeId,@RDB500FAgentTextRuleInputPhiloteId,@RDB500FAgentTextNow);
        SET @RDB500FAgentTextEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleInputDefinition]
          (RuleInputDefinitionPhiloteId,EntityId,EntityTypeId,RuleVersionId,InputCode,Ordinal,ValueTypeVersionId,
           MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500FAgentTextRuleInputPhiloteId,@RDB500FAgentTextEntityId,@RDB500FAgentTextRuleInputTypeId,@RDB500FAgentTextRuleVersionId,
          'content',0,@RDB500FAgentTextValueTypeVersionId,1,1,0,'non-empty-text');
      END;
      SELECT @RDB500FAgentTextRuleInputId=RuleInputDefinitionId FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500FAgentTextRuleVersionId AND InputCode='content';
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleDefaultInputValue] WHERE RuleInputDefinitionId=@RDB500FAgentTextRuleInputId)
      BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500FAgentTextRuleDefaultTypeId,@RDB500FAgentTextDefaultPhiloteId,@RDB500FAgentTextNow);
        SET @RDB500FAgentTextEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[RuleDefaultInputValue]
          (RuleDefaultInputValuePhiloteId,EntityId,EntityTypeId,RuleInputDefinitionId,RuleVersionId,ValueTypeVersionId,
           CanonicalTextValue,CanonicalValueHash,RationaleEntityId,RationaleEntityTypeId,PublishedAtUtc)
        VALUES(@RDB500FAgentTextDefaultPhiloteId,@RDB500FAgentTextEntityId,@RDB500FAgentTextRuleDefaultTypeId,@RDB500FAgentTextRuleInputId,@RDB500FAgentTextRuleVersionId,
          @RDB500FAgentTextValueTypeVersionId,@RDB500FAgentTextDefaultValue,HASHBYTES('SHA2_256',@RDB500FAgentTextDefaultValue),
          (SELECT EntityId FROM [ATAPUtilities].[Rule] WHERE RuleId=@RDB500FAgentTextRuleId),@RDB500FAgentTextRuleTypeId,@RDB500FAgentTextNow);
      END;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId=@RDB500FAgentTextNodePhiloteId)
        INSERT [ATAPUtilities].[RuleVersionNode]
          (RuleVersionNodePhiloteId,RuleVersionId,RuleKindVersionId,ParentRuleVersionNodeId,Ordinal,PrimitiveVersionId,
           MinOccurs,MaxOccurs,ChoiceDiscriminatorCode,NodeLabel)
        VALUES(@RDB500FAgentTextNodePhiloteId,@RDB500FAgentTextRuleVersionId,@RDB500FAgentTextRuleKindVersionId,NULL,0,@RDB500FAgentTextRootPrimitiveVersionId,1,1,NULL,N'root');
      SELECT @RDB500FAgentTextNodeId=RuleVersionNodeId FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId=@RDB500FAgentTextNodePhiloteId;
      IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVersionNodeInput] WHERE RuleVersionNodeId=@RDB500FAgentTextNodeId AND PrimitiveInputDefinitionId=@RDB500FAgentTextRootPrimitiveInputId)
        INSERT [ATAPUtilities].[RuleVersionNodeInput]
          (RuleVersionNodeId,RuleVersionId,PrimitiveVersionId,PrimitiveInputDefinitionId,BindingShapeCode,
           TargetValueTypeVersionId,SourceValueTypeVersionId,ConstantValueTypeVersionId,RuleInputDefinitionId,
           DerivationContractVersionId,ConversionPolicyCode,CanonicalTextValue,CanonicalValueHash)
        VALUES(@RDB500FAgentTextNodeId,@RDB500FAgentTextRuleVersionId,@RDB500FAgentTextRootPrimitiveVersionId,@RDB500FAgentTextRootPrimitiveInputId,
          'constant',@RDB500FAgentTextValueTypeVersionId,NULL,@RDB500FAgentTextValueTypeVersionId,NULL,NULL,NULL,@RDB500FAgentTextDefaultValue,
          HASHBYTES('SHA2_256',@RDB500FAgentTextDefaultValue));
      FETCH NEXT FROM RDB500FAgentTextRuleCursor INTO @RDB500FAgentTextRulePhiloteId,@RDB500FAgentTextRuleVersionPhiloteId,@RDB500FAgentTextRuleInputPhiloteId,@RDB500FAgentTextDefaultPhiloteId,@RDB500FAgentTextNodePhiloteId,@RDB500FAgentTextRuleCode,@RDB500FAgentTextPurpose,@RDB500FAgentTextDefaultValue,@RDB500FAgentTextSourceFileReference;
    END;
    CLOSE RDB500FAgentTextRuleCursor; DEALLOCATE RDB500FAgentTextRuleCursor;

    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500FAgentTextRuleKindId) < 8
      THROW 55507, 'RDB-500F primitive row-count postcondition failed.', 1;
    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500FAgentTextRuleKindId) < 1
      THROW 55508, 'RDB-500F rule row-count postcondition failed.', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','RDB500FAgentTextPrimitiveCursor') >= -1 BEGIN CLOSE RDB500FAgentTextPrimitiveCursor; DEALLOCATE RDB500FAgentTextPrimitiveCursor; END;
    IF CURSOR_STATUS('local','RDB500FAgentTextRuleCursor') >= -1 BEGIN CLOSE RDB500FAgentTextRuleCursor; DEALLOCATE RDB500FAgentTextRuleCursor; END;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
/* END INTEGRATED FRAGMENT: RDB-500F__AgentText.sql */

/* BEGIN INTEGRATED FRAGMENT: RDB-500H__Markdown.sql */
/* RDB-500H / Markdown direct idempotent reference seed. RDB-510 is the sole final integrator. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @RDB500HMarkdownNow datetime2(7)=CONVERT(datetime2(7),'2026-08-06T00:00:00.0000000Z',127);
DECLARE @RDB500HMarkdownGrammarSourceArtifactVersionId bigint,@RDB500HMarkdownCompendiumSourceArtifactVersionId bigint;
SELECT @RDB500HMarkdownGrammarSourceArtifactVersionId=sav.SourceArtifactVersionId FROM [ATAPUtilities].[SourceArtifact] sa JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId=sa.SourceArtifactId WHERE sa.LocatorTypeCode='RepositoryPath' AND sa.RepoRelativePathOrExternalLocator=N'SolutionDocumentation/grammers/Markdown.grammar.ebnf' AND sav.NormalizedContentSha256='111445bc94197d1acdd9924e46a9287f54e6f28df7d2104a6d1ea7f422a29d27';
SELECT @RDB500HMarkdownCompendiumSourceArtifactVersionId=sav.SourceArtifactVersionId FROM [ATAPUtilities].[SourceArtifact] sa JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId=sa.SourceArtifactId WHERE sa.LocatorTypeCode='RepositoryPath' AND sa.RepoRelativePathOrExternalLocator=N'SolutionDocumentation/Rules Compendium.Markdown.md' AND sav.NormalizedContentSha256='fdde05d18e94d3b93a5fc83478a033a72e4856189030807a7a2bed82af4b75e7';
IF @RDB500HMarkdownGrammarSourceArtifactVersionId IS NULL OR @RDB500HMarkdownCompendiumSourceArtifactVersionId IS NULL THROW 55600,'RDB-500H requires exact grammar and compendium SourceArtifactVersion rows.',1;
DECLARE @RDB500HMarkdownRuleKindTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind'),
 @RDB500HMarkdownRuleKindVersionTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind-version'),
 @RDB500HMarkdownValueTypeTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type'),
 @RDB500HMarkdownValueTypeVersionTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type-version'),
 @RDB500HMarkdownPrimitiveTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive'),
 @RDB500HMarkdownPrimitiveVersionTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-version'),
 @RDB500HMarkdownPrimitiveInputTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-input-definition'),
 @RDB500HMarkdownRuleTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule'),
 @RDB500HMarkdownRuleVersionTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-version'),
 @RDB500HMarkdownRuleInputTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-input-definition'),
 @RDB500HMarkdownRuleDefaultTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-default-input-value');
IF @RDB500HMarkdownRuleKindTypeId IS NULL OR @RDB500HMarkdownRuleDefaultTypeId IS NULL THROW 55601,'RDB-500H requires the frozen EntityType catalog.',1;
IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[ExecutionClassification] WHERE ExecutionClassificationCode='metadata-only' AND AllowsExecutorContract=0)
 OR NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[SecurityCapabilityClassification] WHERE SecurityCapabilityCode='reference-safe')
 OR NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[RoundTripPolicy] WHERE RoundTripPolicyCode='byte-identical')
 OR NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[ScalarStorageKind] WHERE ScalarStorageKindCode='bounded-unicode-text')
 OR NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[BindingShape] WHERE BindingShapeCode='constant') THROW 55602,'RDB-500H requires coordinator-owned closed catalogs.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @RDB500HMarkdownEntityId bigint,@RDB500HMarkdownRuleKindId bigint,@RDB500HMarkdownRuleKindVersionId bigint,@RDB500HMarkdownValueTypeId bigint,@RDB500HMarkdownValueTypeVersionId bigint,
  @RDB500HMarkdownPrimitiveId bigint,@RDB500HMarkdownPrimitiveVersionId bigint,@RDB500HMarkdownRuleId bigint,@RDB500HMarkdownRuleVersionId bigint,@RDB500HMarkdownRuleInputId bigint,@RDB500HMarkdownNodeId bigint;
 DECLARE @RDB500HMarkdownPrimitiveCode varchar(128),@RDB500HMarkdownPrimitivePhilote uniqueidentifier,@RDB500HMarkdownPrimitiveVersionPhilote uniqueidentifier,@RDB500HMarkdownPrimitiveInputPhilote uniqueidentifier;
 IF EXISTS(SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode='Markdown' AND RuleKindPhiloteId<>'8d889de1-9915-5630-a6eb-ec9a65283cc0') THROW 55603,'RDB-500H RuleKind natural key maps to a different Philote.',1;
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode='Markdown') BEGIN INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownRuleKindTypeId,'8d889de1-9915-5630-a6eb-ec9a65283cc0',@RDB500HMarkdownNow); SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY()); INSERT [ATAPUtilities].[RuleKind](RuleKindPhiloteId,EntityId,EntityTypeId,RuleKindCode,CreatedAtUtc) VALUES('8d889de1-9915-5630-a6eb-ec9a65283cc0',@RDB500HMarkdownEntityId,@RDB500HMarkdownRuleKindTypeId,'Markdown',@RDB500HMarkdownNow); END;
 SELECT @RDB500HMarkdownRuleKindId=RuleKindId FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode='Markdown';
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND RevisionSequence=1) BEGIN INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownRuleKindVersionTypeId,'fb36066e-2232-5824-973d-82bd1b4a2886',@RDB500HMarkdownNow); SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY()); INSERT [ATAPUtilities].[RuleKindVersion](RuleKindVersionPhiloteId,EntityId,EntityTypeId,RuleKindId,RevisionSequence,PredecessorRuleKindVersionId,GrammarSourceArtifactVersionId,GrammarHashAlgorithmCode,GrammarContentHash,CompendiumSourceArtifactVersionId,CompendiumHashAlgorithmCode,CompendiumContentHash,ExecutorContractVersionId,ExecutionClassificationCode,SecurityCapabilityCode,RoundTripPolicyCode,PublishedAtUtc) VALUES('fb36066e-2232-5824-973d-82bd1b4a2886',@RDB500HMarkdownEntityId,@RDB500HMarkdownRuleKindVersionTypeId,@RDB500HMarkdownRuleKindId,1,NULL,@RDB500HMarkdownGrammarSourceArtifactVersionId,'SHA-256',0x111445bc94197d1acdd9924e46a9287f54e6f28df7d2104a6d1ea7f422a29d27,@RDB500HMarkdownCompendiumSourceArtifactVersionId,'SHA-256',0xfdde05d18e94d3b93a5fc83478a033a72e4856189030807a7a2bed82af4b75e7,NULL,'metadata-only','reference-safe','byte-identical',@RDB500HMarkdownNow); END;
 SELECT @RDB500HMarkdownRuleKindVersionId=RuleKindVersionId FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND RevisionSequence=1;
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-markdown-text') BEGIN INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownValueTypeTypeId,'cefa56b4-3a02-5d59-b3b9-a0366bbcd3c8',@RDB500HMarkdownNow); SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY()); INSERT [ATAPUtilities].[ValueType](ValueTypePhiloteId,EntityId,EntityTypeId,ValueTypeCode,CreatedAtUtc) VALUES('cefa56b4-3a02-5d59-b3b9-a0366bbcd3c8',@RDB500HMarkdownEntityId,@RDB500HMarkdownValueTypeTypeId,'seed-markdown-text',@RDB500HMarkdownNow); END;
 SELECT @RDB500HMarkdownValueTypeId=ValueTypeId FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-markdown-text';
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500HMarkdownValueTypeId AND RevisionSequence=1) BEGIN INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownValueTypeVersionTypeId,'ab2b5adc-86fc-5a9f-9c7b-ec007cc55037',@RDB500HMarkdownNow); SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY()); INSERT [ATAPUtilities].[ValueTypeVersion](ValueTypeVersionPhiloteId,EntityId,EntityTypeId,ValueTypeId,RevisionSequence,PredecessorValueTypeVersionId,ValueCategoryCode,ScalarStorageKindCode,StructuredValueContractVersionId,ElementValueTypeVersionId,CollectionOrderingCode,SecretReferencePolicyId,ValidationContractCode,PublishedAtUtc) VALUES('ab2b5adc-86fc-5a9f-9c7b-ec007cc55037',@RDB500HMarkdownEntityId,@RDB500HMarkdownValueTypeVersionTypeId,@RDB500HMarkdownValueTypeId,1,NULL,'scalar','bounded-unicode-text',NULL,NULL,NULL,NULL,'non-empty-text',@RDB500HMarkdownNow); END;
 SELECT @RDB500HMarkdownValueTypeVersionId=ValueTypeVersionId FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500HMarkdownValueTypeId AND RevisionSequence=1;
    SET @RDB500HMarkdownPrimitiveCode = N'AtxHeading';
    SET @RDB500HMarkdownPrimitivePhilote = 'ab94eb3a-a47c-4531-933d-c5497ddc6a14';
    SET @RDB500HMarkdownPrimitiveVersionPhilote = '27c7031e-fdd1-526e-a66e-0e51f6b25931';
    SET @RDB500HMarkdownPrimitiveInputPhilote = '8945db7a-9757-5e06-b129-0180c1e60a19';
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode AND PrimitivePhiloteId<>@RDB500HMarkdownPrimitivePhilote)
        THROW 55604, 'RDB-500H Primitive natural key maps to a different Philote.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownPrimitiveCode,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,PredecessorPrimitiveVersionId,
           GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownRuleKindVersionId,
          1,NULL,@RDB500HMarkdownPrimitiveCode,N'Reference-safe Markdown grammar production AtxHeading.','SHA-256',HASHBYTES('SHA2_256',N'Reference-safe Markdown grammar production AtxHeading.'),@RDB500HMarkdownValueTypeVersionId,1,1,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500HMarkdownPrimitiveVersionId AND InputCode='content')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveVersionId,'content',0,@RDB500HMarkdownValueTypeVersionId,1,1,0,'non-empty-text');
    END;
    SET @RDB500HMarkdownPrimitiveCode = N'BlankLine';
    SET @RDB500HMarkdownPrimitivePhilote = '8dc53fbf-24dd-4bd1-bcd0-23784fb10820';
    SET @RDB500HMarkdownPrimitiveVersionPhilote = '99f17ec3-4a50-5981-bd42-1a072c059ac5';
    SET @RDB500HMarkdownPrimitiveInputPhilote = 'd66e80fe-179d-5fbd-ae44-aabb1f93277f';
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode AND PrimitivePhiloteId<>@RDB500HMarkdownPrimitivePhilote)
        THROW 55604, 'RDB-500H Primitive natural key maps to a different Philote.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownPrimitiveCode,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,PredecessorPrimitiveVersionId,
           GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownRuleKindVersionId,
          1,NULL,@RDB500HMarkdownPrimitiveCode,N'Reference-safe Markdown grammar production BlankLine.','SHA-256',HASHBYTES('SHA2_256',N'Reference-safe Markdown grammar production BlankLine.'),@RDB500HMarkdownValueTypeVersionId,1,1,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500HMarkdownPrimitiveVersionId AND InputCode='content')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveVersionId,'content',0,@RDB500HMarkdownValueTypeVersionId,1,1,0,'non-empty-text');
    END;
    SET @RDB500HMarkdownPrimitiveCode = N'Emphasis';
    SET @RDB500HMarkdownPrimitivePhilote = '5872cd5b-9860-4a5a-ac81-a83e74fee445';
    SET @RDB500HMarkdownPrimitiveVersionPhilote = '5aec6450-53cf-5158-8adb-e221e98b7e57';
    SET @RDB500HMarkdownPrimitiveInputPhilote = '33bd1df9-43e7-5c8d-9823-07b4abaa5ab3';
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode AND PrimitivePhiloteId<>@RDB500HMarkdownPrimitivePhilote)
        THROW 55604, 'RDB-500H Primitive natural key maps to a different Philote.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownPrimitiveCode,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,PredecessorPrimitiveVersionId,
           GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownRuleKindVersionId,
          1,NULL,@RDB500HMarkdownPrimitiveCode,N'Reference-safe Markdown grammar production Emphasis.','SHA-256',HASHBYTES('SHA2_256',N'Reference-safe Markdown grammar production Emphasis.'),@RDB500HMarkdownValueTypeVersionId,1,1,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500HMarkdownPrimitiveVersionId AND InputCode='content')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveVersionId,'content',0,@RDB500HMarkdownValueTypeVersionId,1,1,0,'non-empty-text');
    END;
    SET @RDB500HMarkdownPrimitiveCode = N'FencedCodeBlock';
    SET @RDB500HMarkdownPrimitivePhilote = '3d3ceb05-7705-4ba5-b001-13d020045859';
    SET @RDB500HMarkdownPrimitiveVersionPhilote = '254c001d-4930-58a7-8ce2-7d1c9cb31722';
    SET @RDB500HMarkdownPrimitiveInputPhilote = '8546eba3-4eef-5bfb-96e6-1080f5ad3133';
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode AND PrimitivePhiloteId<>@RDB500HMarkdownPrimitivePhilote)
        THROW 55604, 'RDB-500H Primitive natural key maps to a different Philote.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownPrimitiveCode,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,PredecessorPrimitiveVersionId,
           GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownRuleKindVersionId,
          1,NULL,@RDB500HMarkdownPrimitiveCode,N'Reference-safe Markdown grammar production FencedCodeBlock.','SHA-256',HASHBYTES('SHA2_256',N'Reference-safe Markdown grammar production FencedCodeBlock.'),@RDB500HMarkdownValueTypeVersionId,1,1,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500HMarkdownPrimitiveVersionId AND InputCode='content')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveVersionId,'content',0,@RDB500HMarkdownValueTypeVersionId,1,1,0,'non-empty-text');
    END;
    SET @RDB500HMarkdownPrimitiveCode = N'InlineCode';
    SET @RDB500HMarkdownPrimitivePhilote = '41c7b5e2-2282-4ccc-afa9-5d8497d0ad74';
    SET @RDB500HMarkdownPrimitiveVersionPhilote = '16c38569-3cbc-55da-a0be-21d8928c7287';
    SET @RDB500HMarkdownPrimitiveInputPhilote = 'f8696a9b-6afa-557a-8d91-395e3727d52c';
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode AND PrimitivePhiloteId<>@RDB500HMarkdownPrimitivePhilote)
        THROW 55604, 'RDB-500H Primitive natural key maps to a different Philote.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownPrimitiveCode,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,PredecessorPrimitiveVersionId,
           GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownRuleKindVersionId,
          1,NULL,@RDB500HMarkdownPrimitiveCode,N'Reference-safe Markdown grammar production InlineCode.','SHA-256',HASHBYTES('SHA2_256',N'Reference-safe Markdown grammar production InlineCode.'),@RDB500HMarkdownValueTypeVersionId,1,1,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500HMarkdownPrimitiveVersionId AND InputCode='content')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveVersionId,'content',0,@RDB500HMarkdownValueTypeVersionId,1,1,0,'non-empty-text');
    END;
    SET @RDB500HMarkdownPrimitiveCode = N'Link';
    SET @RDB500HMarkdownPrimitivePhilote = '468e634b-7a44-4d0b-9078-cd17c8e196ce';
    SET @RDB500HMarkdownPrimitiveVersionPhilote = '8b6e4746-7336-55c7-ac95-0cd0a5f83eda';
    SET @RDB500HMarkdownPrimitiveInputPhilote = '4db6d6ad-ac3f-5110-a081-77783cb3bb1e';
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode AND PrimitivePhiloteId<>@RDB500HMarkdownPrimitivePhilote)
        THROW 55604, 'RDB-500H Primitive natural key maps to a different Philote.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownPrimitiveCode,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,PredecessorPrimitiveVersionId,
           GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownRuleKindVersionId,
          1,NULL,@RDB500HMarkdownPrimitiveCode,N'Reference-safe Markdown grammar production Link.','SHA-256',HASHBYTES('SHA2_256',N'Reference-safe Markdown grammar production Link.'),@RDB500HMarkdownValueTypeVersionId,1,1,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500HMarkdownPrimitiveVersionId AND InputCode='content')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveVersionId,'content',0,@RDB500HMarkdownValueTypeVersionId,1,1,0,'non-empty-text');
    END;
    SET @RDB500HMarkdownPrimitiveCode = N'ListItem';
    SET @RDB500HMarkdownPrimitivePhilote = 'b769e3ed-2479-48b9-b84e-49fa8da89e4a';
    SET @RDB500HMarkdownPrimitiveVersionPhilote = '3d80cca7-8b4f-54ff-a82a-6d5a4e9540f9';
    SET @RDB500HMarkdownPrimitiveInputPhilote = 'c89c59bd-9cec-5dcb-8ea2-dd58cb0bfcbb';
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode AND PrimitivePhiloteId<>@RDB500HMarkdownPrimitivePhilote)
        THROW 55604, 'RDB-500H Primitive natural key maps to a different Philote.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownPrimitiveCode,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,PredecessorPrimitiveVersionId,
           GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownRuleKindVersionId,
          1,NULL,@RDB500HMarkdownPrimitiveCode,N'Reference-safe Markdown grammar production ListItem.','SHA-256',HASHBYTES('SHA2_256',N'Reference-safe Markdown grammar production ListItem.'),@RDB500HMarkdownValueTypeVersionId,1,1,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500HMarkdownPrimitiveVersionId AND InputCode='content')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveVersionId,'content',0,@RDB500HMarkdownValueTypeVersionId,1,1,0,'non-empty-text');
    END;
    SET @RDB500HMarkdownPrimitiveCode = N'MarkdownBlock';
    SET @RDB500HMarkdownPrimitivePhilote = 'becc038a-3127-478d-a8f1-da29bbd76b64';
    SET @RDB500HMarkdownPrimitiveVersionPhilote = 'ddc6c706-ab6a-506d-bcbd-7d98b0171dea';
    SET @RDB500HMarkdownPrimitiveInputPhilote = 'c4ceada1-3f87-5e2f-a438-338f25887694';
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode AND PrimitivePhiloteId<>@RDB500HMarkdownPrimitivePhilote)
        THROW 55604, 'RDB-500H Primitive natural key maps to a different Philote.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownPrimitiveCode,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,PredecessorPrimitiveVersionId,
           GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownRuleKindVersionId,
          1,NULL,@RDB500HMarkdownPrimitiveCode,N'Reference-safe Markdown grammar production MarkdownBlock.','SHA-256',HASHBYTES('SHA2_256',N'Reference-safe Markdown grammar production MarkdownBlock.'),@RDB500HMarkdownValueTypeVersionId,1,1,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500HMarkdownPrimitiveVersionId AND InputCode='content')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveVersionId,'content',0,@RDB500HMarkdownValueTypeVersionId,1,1,0,'non-empty-text');
    END;
    SET @RDB500HMarkdownPrimitiveCode = N'Paragraph';
    SET @RDB500HMarkdownPrimitivePhilote = 'd4d087c6-4dec-4226-bca7-7b04cf516add';
    SET @RDB500HMarkdownPrimitiveVersionPhilote = '84f08fe1-917e-5701-ab0e-673d34464138';
    SET @RDB500HMarkdownPrimitiveInputPhilote = '2bb64aa7-98ec-5fe3-820d-4d79d3c71a72';
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode AND PrimitivePhiloteId<>@RDB500HMarkdownPrimitivePhilote)
        THROW 55604, 'RDB-500H Primitive natural key maps to a different Philote.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownPrimitiveCode,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,PredecessorPrimitiveVersionId,
           GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownRuleKindVersionId,
          1,NULL,@RDB500HMarkdownPrimitiveCode,N'Reference-safe Markdown grammar production Paragraph.','SHA-256',HASHBYTES('SHA2_256',N'Reference-safe Markdown grammar production Paragraph.'),@RDB500HMarkdownValueTypeVersionId,1,1,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500HMarkdownPrimitiveVersionId AND InputCode='content')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveVersionId,'content',0,@RDB500HMarkdownValueTypeVersionId,1,1,0,'non-empty-text');
    END;
    SET @RDB500HMarkdownPrimitiveCode = N'PipeTable';
    SET @RDB500HMarkdownPrimitivePhilote = 'f5f18fc7-0bdc-42d1-9477-121c06fb4a84';
    SET @RDB500HMarkdownPrimitiveVersionPhilote = '62def2cb-c80a-5d0d-8023-69bd2d3c932e';
    SET @RDB500HMarkdownPrimitiveInputPhilote = '374ee88b-490a-563f-a961-ba140441c038';
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode AND PrimitivePhiloteId<>@RDB500HMarkdownPrimitivePhilote)
        THROW 55604, 'RDB-500H Primitive natural key maps to a different Philote.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownPrimitiveCode,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,PredecessorPrimitiveVersionId,
           GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownRuleKindVersionId,
          1,NULL,@RDB500HMarkdownPrimitiveCode,N'Reference-safe Markdown grammar production PipeTable.','SHA-256',HASHBYTES('SHA2_256',N'Reference-safe Markdown grammar production PipeTable.'),@RDB500HMarkdownValueTypeVersionId,1,1,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500HMarkdownPrimitiveVersionId AND InputCode='content')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveVersionId,'content',0,@RDB500HMarkdownValueTypeVersionId,1,1,0,'non-empty-text');
    END;
    SET @RDB500HMarkdownPrimitiveCode = N'TableRow';
    SET @RDB500HMarkdownPrimitivePhilote = 'c927ed45-32a5-4913-8433-97c6ed541f9b';
    SET @RDB500HMarkdownPrimitiveVersionPhilote = 'ffb13149-1d72-5a77-a04b-fa533b259515';
    SET @RDB500HMarkdownPrimitiveInputPhilote = 'd874c723-b5d0-51f7-b020-47e6f1a0744c';
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode AND PrimitivePhiloteId<>@RDB500HMarkdownPrimitivePhilote)
        THROW 55604, 'RDB-500H Primitive natural key maps to a different Philote.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownPrimitiveCode,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,PredecessorPrimitiveVersionId,
           GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownRuleKindVersionId,
          1,NULL,@RDB500HMarkdownPrimitiveCode,N'Reference-safe Markdown grammar production TableRow.','SHA-256',HASHBYTES('SHA2_256',N'Reference-safe Markdown grammar production TableRow.'),@RDB500HMarkdownValueTypeVersionId,1,1,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500HMarkdownPrimitiveVersionId AND InputCode='content')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveVersionId,'content',0,@RDB500HMarkdownValueTypeVersionId,1,1,0,'non-empty-text');
    END;
    SET @RDB500HMarkdownPrimitiveCode = N'TextRun';
    SET @RDB500HMarkdownPrimitivePhilote = '6a6e508c-3d00-4b99-80e3-a8b76fd42bdc';
    SET @RDB500HMarkdownPrimitiveVersionPhilote = 'b705d43f-5935-518d-b844-749835017074';
    SET @RDB500HMarkdownPrimitiveInputPhilote = '42e90d29-3d61-5ac8-a0a9-11bd76e2f56f';
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode AND PrimitivePhiloteId<>@RDB500HMarkdownPrimitivePhilote)
        THROW 55604, 'RDB-500H Primitive natural key maps to a different Philote.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownPrimitiveCode,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,PredecessorPrimitiveVersionId,
           GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownRuleKindVersionId,
          1,NULL,@RDB500HMarkdownPrimitiveCode,N'Reference-safe Markdown grammar production TextRun.','SHA-256',HASHBYTES('SHA2_256',N'Reference-safe Markdown grammar production TextRun.'),@RDB500HMarkdownValueTypeVersionId,1,1,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500HMarkdownPrimitiveVersionId AND InputCode='content')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveVersionId,'content',0,@RDB500HMarkdownValueTypeVersionId,1,1,0,'non-empty-text');
    END;
    SET @RDB500HMarkdownPrimitiveCode = N'UnorderedList';
    SET @RDB500HMarkdownPrimitivePhilote = '00bdecf8-ffeb-4dd2-b523-323febcb27d8';
    SET @RDB500HMarkdownPrimitiveVersionPhilote = '5d5f2242-e6ab-5225-a30a-cf4db30cfc45';
    SET @RDB500HMarkdownPrimitiveInputPhilote = '026542bf-af01-5d32-8e0b-2c3a90abca7f';
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode AND PrimitivePhiloteId<>@RDB500HMarkdownPrimitivePhilote)
        THROW 55604, 'RDB-500H Primitive natural key maps to a different Philote.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500HMarkdownPrimitivePhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveTypeId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownPrimitiveCode,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND PrimitiveCode=@RDB500HMarkdownPrimitiveCode;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,PredecessorPrimitiveVersionId,
           GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500HMarkdownPrimitiveVersionPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveVersionTypeId,@RDB500HMarkdownPrimitiveId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownRuleKindVersionId,
          1,NULL,@RDB500HMarkdownPrimitiveCode,N'Reference-safe Markdown grammar production UnorderedList.','SHA-256',HASHBYTES('SHA2_256',N'Reference-safe Markdown grammar production UnorderedList.'),@RDB500HMarkdownValueTypeVersionId,1,1,@RDB500HMarkdownNow);
    END;
    SELECT @RDB500HMarkdownPrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500HMarkdownPrimitiveId AND RevisionSequence=1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500HMarkdownPrimitiveVersionId AND InputCode='content')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownNow);
        SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500HMarkdownPrimitiveInputPhilote,@RDB500HMarkdownEntityId,@RDB500HMarkdownPrimitiveInputTypeId,@RDB500HMarkdownPrimitiveVersionId,'content',0,@RDB500HMarkdownValueTypeVersionId,1,1,0,'non-empty-text');
    END;
 SELECT @RDB500HMarkdownPrimitiveVersionId=pv.PrimitiveVersionId,@RDB500HMarkdownPrimitiveId=pid.PrimitiveInputDefinitionId FROM [ATAPUtilities].[Primitive] p JOIN [ATAPUtilities].[PrimitiveVersion] pv ON pv.PrimitiveId=p.PrimitiveId AND pv.RevisionSequence=1 JOIN [ATAPUtilities].[PrimitiveInputDefinition] pid ON pid.PrimitiveVersionId=pv.PrimitiveVersionId AND pid.InputCode='content' WHERE p.RuleKindId=@RDB500HMarkdownRuleKindId AND p.PrimitiveCode='MarkdownBlock';
 IF @RDB500HMarkdownPrimitiveId IS NULL THROW 55605,'RDB-500H root primitive input was not materialized.',1;
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND RuleCode='ReferenceDocument') BEGIN INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownRuleTypeId,'4e299e0a-a956-548a-8703-9e94e84c676a',@RDB500HMarkdownNow); SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY()); INSERT [ATAPUtilities].[Rule](RulePhiloteId,EntityId,EntityTypeId,RuleKindId,RuleCode,CreatedAtUtc) VALUES('4e299e0a-a956-548a-8703-9e94e84c676a',@RDB500HMarkdownEntityId,@RDB500HMarkdownRuleTypeId,@RDB500HMarkdownRuleKindId,'ReferenceDocument',@RDB500HMarkdownNow); END;
 SELECT @RDB500HMarkdownRuleId=RuleId FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND RuleCode='ReferenceDocument';
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500HMarkdownRuleId AND RevisionSequence=1) BEGIN INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownRuleVersionTypeId,'3977d3b4-8c3b-59df-8641-a1e9093b18e3',@RDB500HMarkdownNow); SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY()); INSERT [ATAPUtilities].[RuleVersion](RuleVersionPhiloteId,EntityId,EntityTypeId,RuleId,RuleKindId,RuleKindVersionId,RevisionSequence,PredecessorRuleVersionId,CompositionHashAlgorithmCode,CompositionContentHash,PublishedAtUtc) VALUES('3977d3b4-8c3b-59df-8641-a1e9093b18e3',@RDB500HMarkdownEntityId,@RDB500HMarkdownRuleVersionTypeId,@RDB500HMarkdownRuleId,@RDB500HMarkdownRuleKindId,@RDB500HMarkdownRuleKindVersionId,1,NULL,'SHA-256',HASHBYTES('SHA2_256',N'Markdown|ReferenceDocument|# Reference-safe document'),@RDB500HMarkdownNow); END;
 SELECT @RDB500HMarkdownRuleVersionId=RuleVersionId FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500HMarkdownRuleId AND RevisionSequence=1;
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500HMarkdownRuleVersionId AND InputCode='body') BEGIN INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownRuleInputTypeId,'3f4f4d5c-c9f2-56b5-b2da-dbefdbf1d8d6',@RDB500HMarkdownNow); SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY()); INSERT [ATAPUtilities].[RuleInputDefinition](RuleInputDefinitionPhiloteId,EntityId,EntityTypeId,RuleVersionId,InputCode,Ordinal,ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode) VALUES('3f4f4d5c-c9f2-56b5-b2da-dbefdbf1d8d6',@RDB500HMarkdownEntityId,@RDB500HMarkdownRuleInputTypeId,@RDB500HMarkdownRuleVersionId,'body',0,@RDB500HMarkdownValueTypeVersionId,1,1,0,'non-empty-text'); END;
 SELECT @RDB500HMarkdownRuleInputId=RuleInputDefinitionId FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500HMarkdownRuleVersionId AND InputCode='body';
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[RuleDefaultInputValue] WHERE RuleInputDefinitionId=@RDB500HMarkdownRuleInputId) BEGIN INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500HMarkdownRuleDefaultTypeId,'d4ab460e-a00d-55e2-80d9-0f3ab61cc9d6',@RDB500HMarkdownNow); SET @RDB500HMarkdownEntityId=CONVERT(bigint,SCOPE_IDENTITY()); INSERT [ATAPUtilities].[RuleDefaultInputValue](RuleDefaultInputValuePhiloteId,EntityId,EntityTypeId,RuleInputDefinitionId,RuleVersionId,ValueTypeVersionId,CanonicalTextValue,CanonicalValueHash,RationaleEntityId,RationaleEntityTypeId,PublishedAtUtc) VALUES('d4ab460e-a00d-55e2-80d9-0f3ab61cc9d6',@RDB500HMarkdownEntityId,@RDB500HMarkdownRuleDefaultTypeId,@RDB500HMarkdownRuleInputId,@RDB500HMarkdownRuleVersionId,@RDB500HMarkdownValueTypeVersionId,N'# Reference-safe document',HASHBYTES('SHA2_256',N'# Reference-safe document'),(SELECT EntityId FROM [ATAPUtilities].[Rule] WHERE RuleId=@RDB500HMarkdownRuleId),@RDB500HMarkdownRuleTypeId,@RDB500HMarkdownNow); END;
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId='41de4d47-2a21-544e-9e80-c9de4df10b10') INSERT [ATAPUtilities].[RuleVersionNode](RuleVersionNodePhiloteId,RuleVersionId,RuleKindVersionId,ParentRuleVersionNodeId,Ordinal,PrimitiveVersionId,MinOccurs,MaxOccurs,ChoiceDiscriminatorCode,NodeLabel) VALUES('41de4d47-2a21-544e-9e80-c9de4df10b10',@RDB500HMarkdownRuleVersionId,@RDB500HMarkdownRuleKindVersionId,NULL,0,@RDB500HMarkdownPrimitiveVersionId,1,1,NULL,N'root');
 SELECT @RDB500HMarkdownNodeId=RuleVersionNodeId FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId='41de4d47-2a21-544e-9e80-c9de4df10b10';
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[RuleVersionNodeInput] WHERE RuleVersionNodeId=@RDB500HMarkdownNodeId AND PrimitiveInputDefinitionId=@RDB500HMarkdownPrimitiveId) INSERT [ATAPUtilities].[RuleVersionNodeInput](RuleVersionNodeId,RuleVersionId,PrimitiveVersionId,PrimitiveInputDefinitionId,BindingShapeCode,TargetValueTypeVersionId,SourceValueTypeVersionId,ConstantValueTypeVersionId,RuleInputDefinitionId,DerivationContractVersionId,ConversionPolicyCode,CanonicalTextValue,CanonicalValueHash) VALUES(@RDB500HMarkdownNodeId,@RDB500HMarkdownRuleVersionId,@RDB500HMarkdownPrimitiveVersionId,@RDB500HMarkdownPrimitiveId,'constant',@RDB500HMarkdownValueTypeVersionId,NULL,@RDB500HMarkdownValueTypeVersionId,NULL,NULL,NULL,N'# Reference-safe document',HASHBYTES('SHA2_256',N'# Reference-safe document'));
 IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500HMarkdownRuleKindId) < 13 THROW 55606,'RDB-500H primitive row-count postcondition failed.',1;
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500HMarkdownRuleKindId AND RuleCode='ReferenceDocument') THROW 55607,'RDB-500H rule postcondition failed.',1;
 COMMIT TRANSACTION;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;

/* END INTEGRATED FRAGMENT: RDB-500H__Markdown.sql */

/* BEGIN INTEGRATED FRAGMENT: RDB-500I__ManimScene.sql */
/* RDB-500I / ManimScene direct idempotent reference seed. RDB-510 is the sole final integrator. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @RDB500IManimSceneNow datetime2(7)=CONVERT(datetime2(7),'2026-08-06T00:00:00.0000000Z',127);
DECLARE @RDB500IManimSceneGrammarSourceArtifactVersionId bigint,@RDB500IManimSceneCompendiumSourceArtifactVersionId bigint;
SELECT @RDB500IManimSceneGrammarSourceArtifactVersionId=sav.SourceArtifactVersionId FROM [ATAPUtilities].[SourceArtifact] sa JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId=sa.SourceArtifactId WHERE sa.LocatorTypeCode='RepositoryPath' AND sa.RepoRelativePathOrExternalLocator=N'SolutionDocumentation/grammers/ManimScene.grammar.ebnf' AND sav.NormalizedContentSha256='a014d68279e1c241773aecd0541ec0caf1e7796e48f1c77ed5659c6da0ca1b71';
SELECT @RDB500IManimSceneCompendiumSourceArtifactVersionId=sav.SourceArtifactVersionId FROM [ATAPUtilities].[SourceArtifact] sa JOIN [ATAPUtilities].[SourceArtifactVersion] sav ON sav.SourceArtifactId=sa.SourceArtifactId WHERE sa.LocatorTypeCode='RepositoryPath' AND sa.RepoRelativePathOrExternalLocator=N'SolutionDocumentation/Rules Compendium.Manim.md' AND sav.NormalizedContentSha256='f3c223ff8f7d608774fa2420601857356ea691db0b7cb90e037cf561e2199643';
IF @RDB500IManimSceneGrammarSourceArtifactVersionId IS NULL OR @RDB500IManimSceneCompendiumSourceArtifactVersionId IS NULL THROW 55600,'RDB-500I requires exact grammar and compendium SourceArtifactVersion rows.',1;
DECLARE @RDB500IManimSceneRuleKindTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind'),
 @RDB500IManimSceneRuleKindVersionTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-kind-version'),
 @RDB500IManimSceneValueTypeTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type'),
 @RDB500IManimSceneValueTypeVersionTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='value-type-version'),
 @RDB500IManimScenePrimitiveTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive'),
 @RDB500IManimScenePrimitiveVersionTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-version'),
 @RDB500IManimScenePrimitiveInputTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='primitive-input-definition'),
 @RDB500IManimSceneRuleTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule'),
 @RDB500IManimSceneRuleVersionTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-version'),
 @RDB500IManimSceneRuleInputTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-input-definition'),
 @RDB500IManimSceneRuleDefaultTypeId bigint=(SELECT EntityTypeId FROM [ATAPUtilities].[EntityType] WHERE EntityTypeCode='rule-default-input-value');
IF @RDB500IManimSceneRuleKindTypeId IS NULL OR @RDB500IManimSceneRuleDefaultTypeId IS NULL THROW 55601,'RDB-500I requires the frozen EntityType catalog.',1;
IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[ExecutionClassification] WHERE ExecutionClassificationCode='metadata-only' AND AllowsExecutorContract=0)
 OR NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[SecurityCapabilityClassification] WHERE SecurityCapabilityCode='reference-safe')
 OR NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[RoundTripPolicy] WHERE RoundTripPolicyCode='semantic-equivalent')
 OR NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[ScalarStorageKind] WHERE ScalarStorageKindCode='bounded-unicode-text')
 OR NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[BindingShape] WHERE BindingShapeCode='constant') THROW 55602,'RDB-500I requires coordinator-owned closed catalogs.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @RDB500IManimSceneEntityId bigint,@RDB500IManimSceneRuleKindId bigint,@RDB500IManimSceneRuleKindVersionId bigint,@RDB500IManimSceneValueTypeId bigint,@RDB500IManimSceneValueTypeVersionId bigint,
  @RDB500IManimScenePrimitiveId bigint,@RDB500IManimScenePrimitiveVersionId bigint,@RDB500IManimSceneRuleId bigint,@RDB500IManimSceneRuleVersionId bigint,@RDB500IManimSceneRuleInputId bigint,@RDB500IManimSceneNodeId bigint;
 DECLARE @RDB500IManimScenePrimitiveCode varchar(128),@RDB500IManimScenePrimitivePhilote uniqueidentifier,@RDB500IManimScenePrimitiveVersionPhilote uniqueidentifier,@RDB500IManimScenePrimitiveInputPhilote uniqueidentifier;
 IF EXISTS(SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode='ManimScene' AND RuleKindPhiloteId<>'c493f0e8-0c3d-5716-b951-d0bb2ac41742') THROW 55603,'RDB-500I RuleKind natural key maps to a different Philote.',1;
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode='ManimScene') BEGIN INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500IManimSceneRuleKindTypeId,'c493f0e8-0c3d-5716-b951-d0bb2ac41742',@RDB500IManimSceneNow); SET @RDB500IManimSceneEntityId=CONVERT(bigint,SCOPE_IDENTITY()); INSERT [ATAPUtilities].[RuleKind](RuleKindPhiloteId,EntityId,EntityTypeId,RuleKindCode,CreatedAtUtc) VALUES('c493f0e8-0c3d-5716-b951-d0bb2ac41742',@RDB500IManimSceneEntityId,@RDB500IManimSceneRuleKindTypeId,'ManimScene',@RDB500IManimSceneNow); END;
 SELECT @RDB500IManimSceneRuleKindId=RuleKindId FROM [ATAPUtilities].[RuleKind] WHERE RuleKindCode='ManimScene';
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500IManimSceneRuleKindId AND RevisionSequence=1) BEGIN INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500IManimSceneRuleKindVersionTypeId,'a6d19b1d-6ae1-5109-b2cc-dff38d9bde7b',@RDB500IManimSceneNow); SET @RDB500IManimSceneEntityId=CONVERT(bigint,SCOPE_IDENTITY()); INSERT [ATAPUtilities].[RuleKindVersion](RuleKindVersionPhiloteId,EntityId,EntityTypeId,RuleKindId,RevisionSequence,PredecessorRuleKindVersionId,GrammarSourceArtifactVersionId,GrammarHashAlgorithmCode,GrammarContentHash,CompendiumSourceArtifactVersionId,CompendiumHashAlgorithmCode,CompendiumContentHash,ExecutorContractVersionId,ExecutionClassificationCode,SecurityCapabilityCode,RoundTripPolicyCode,PublishedAtUtc) VALUES('a6d19b1d-6ae1-5109-b2cc-dff38d9bde7b',@RDB500IManimSceneEntityId,@RDB500IManimSceneRuleKindVersionTypeId,@RDB500IManimSceneRuleKindId,1,NULL,@RDB500IManimSceneGrammarSourceArtifactVersionId,'SHA-256',0xa014d68279e1c241773aecd0541ec0caf1e7796e48f1c77ed5659c6da0ca1b71,@RDB500IManimSceneCompendiumSourceArtifactVersionId,'SHA-256',0xf3c223ff8f7d608774fa2420601857356ea691db0b7cb90e037cf561e2199643,NULL,'metadata-only','reference-safe','semantic-equivalent',@RDB500IManimSceneNow); END;
 SELECT @RDB500IManimSceneRuleKindVersionId=RuleKindVersionId FROM [ATAPUtilities].[RuleKindVersion] WHERE RuleKindId=@RDB500IManimSceneRuleKindId AND RevisionSequence=1;
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-manimscene-text') BEGIN INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500IManimSceneValueTypeTypeId,'0d8dc419-ec05-52d8-9007-aeb7a5311e42',@RDB500IManimSceneNow); SET @RDB500IManimSceneEntityId=CONVERT(bigint,SCOPE_IDENTITY()); INSERT [ATAPUtilities].[ValueType](ValueTypePhiloteId,EntityId,EntityTypeId,ValueTypeCode,CreatedAtUtc) VALUES('0d8dc419-ec05-52d8-9007-aeb7a5311e42',@RDB500IManimSceneEntityId,@RDB500IManimSceneValueTypeTypeId,'seed-manimscene-text',@RDB500IManimSceneNow); END;
 SELECT @RDB500IManimSceneValueTypeId=ValueTypeId FROM [ATAPUtilities].[ValueType] WHERE ValueTypeCode='seed-manimscene-text';
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500IManimSceneValueTypeId AND RevisionSequence=1) BEGIN INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500IManimSceneValueTypeVersionTypeId,'f62d1540-67e6-54e4-a92a-fdc2ace17edb',@RDB500IManimSceneNow); SET @RDB500IManimSceneEntityId=CONVERT(bigint,SCOPE_IDENTITY()); INSERT [ATAPUtilities].[ValueTypeVersion](ValueTypeVersionPhiloteId,EntityId,EntityTypeId,ValueTypeId,RevisionSequence,PredecessorValueTypeVersionId,ValueCategoryCode,ScalarStorageKindCode,StructuredValueContractVersionId,ElementValueTypeVersionId,CollectionOrderingCode,SecretReferencePolicyId,ValidationContractCode,PublishedAtUtc) VALUES('f62d1540-67e6-54e4-a92a-fdc2ace17edb',@RDB500IManimSceneEntityId,@RDB500IManimSceneValueTypeVersionTypeId,@RDB500IManimSceneValueTypeId,1,NULL,'scalar','bounded-unicode-text',NULL,NULL,NULL,NULL,'non-empty-text',@RDB500IManimSceneNow); END;
 SELECT @RDB500IManimSceneValueTypeVersionId=ValueTypeVersionId FROM [ATAPUtilities].[ValueTypeVersion] WHERE ValueTypeId=@RDB500IManimSceneValueTypeId AND RevisionSequence=1;
    SET @RDB500IManimScenePrimitiveCode = N'SimpleScene';
    SET @RDB500IManimScenePrimitivePhilote = '667f2821-a49c-5939-94cc-a3341ecc9074';
    SET @RDB500IManimScenePrimitiveVersionPhilote = 'd8e01dde-5106-52fd-8cd6-9ad3768dbf12';
    SET @RDB500IManimScenePrimitiveInputPhilote = '46b7acca-046d-573c-849e-6cc0da92f9fc';
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500IManimSceneRuleKindId AND PrimitiveCode=@RDB500IManimScenePrimitiveCode AND PrimitivePhiloteId<>@RDB500IManimScenePrimitivePhilote)
        THROW 55604, 'RDB-500I Primitive natural key maps to a different Philote.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500IManimSceneRuleKindId AND PrimitiveCode=@RDB500IManimScenePrimitiveCode)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500IManimScenePrimitiveTypeId,@RDB500IManimScenePrimitivePhilote,@RDB500IManimSceneNow);
        SET @RDB500IManimSceneEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[Primitive](PrimitivePhiloteId,EntityId,EntityTypeId,RuleKindId,PrimitiveCode,CreatedAtUtc)
        VALUES(@RDB500IManimScenePrimitivePhilote,@RDB500IManimSceneEntityId,@RDB500IManimScenePrimitiveTypeId,@RDB500IManimSceneRuleKindId,@RDB500IManimScenePrimitiveCode,@RDB500IManimSceneNow);
    END;
    SELECT @RDB500IManimScenePrimitiveId=PrimitiveId FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500IManimSceneRuleKindId AND PrimitiveCode=@RDB500IManimScenePrimitiveCode;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500IManimScenePrimitiveId AND RevisionSequence=1)
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500IManimScenePrimitiveVersionTypeId,@RDB500IManimScenePrimitiveVersionPhilote,@RDB500IManimSceneNow);
        SET @RDB500IManimSceneEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveVersion]
          (PrimitiveVersionPhiloteId,EntityId,EntityTypeId,PrimitiveId,RuleKindId,RuleKindVersionId,RevisionSequence,PredecessorPrimitiveVersionId,
           GrammarProductionCode,DefinitionText,DefinitionHashAlgorithmCode,DefinitionContentHash,OutputValueTypeVersionId,OutputMinCardinality,OutputMaxCardinality,PublishedAtUtc)
        VALUES(@RDB500IManimScenePrimitiveVersionPhilote,@RDB500IManimSceneEntityId,@RDB500IManimScenePrimitiveVersionTypeId,@RDB500IManimScenePrimitiveId,@RDB500IManimSceneRuleKindId,@RDB500IManimSceneRuleKindVersionId,
          1,NULL,@RDB500IManimScenePrimitiveCode,N'Reference-safe ManimScene grammar production SimpleScene.','SHA-256',HASHBYTES('SHA2_256',N'Reference-safe ManimScene grammar production SimpleScene.'),@RDB500IManimSceneValueTypeVersionId,1,1,@RDB500IManimSceneNow);
    END;
    SELECT @RDB500IManimScenePrimitiveVersionId=PrimitiveVersionId FROM [ATAPUtilities].[PrimitiveVersion] WHERE PrimitiveId=@RDB500IManimScenePrimitiveId AND RevisionSequence=1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PrimitiveInputDefinition] WHERE PrimitiveVersionId=@RDB500IManimScenePrimitiveVersionId AND InputCode='content')
    BEGIN
        INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500IManimScenePrimitiveInputTypeId,@RDB500IManimScenePrimitiveInputPhilote,@RDB500IManimSceneNow);
        SET @RDB500IManimSceneEntityId=CONVERT(bigint,SCOPE_IDENTITY());
        INSERT [ATAPUtilities].[PrimitiveInputDefinition]
          (PrimitiveInputDefinitionPhiloteId,EntityId,EntityTypeId,PrimitiveVersionId,InputCode,Ordinal,ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode)
        VALUES(@RDB500IManimScenePrimitiveInputPhilote,@RDB500IManimSceneEntityId,@RDB500IManimScenePrimitiveInputTypeId,@RDB500IManimScenePrimitiveVersionId,'content',0,@RDB500IManimSceneValueTypeVersionId,1,1,0,'non-empty-text');
    END;
 SELECT @RDB500IManimScenePrimitiveVersionId=pv.PrimitiveVersionId,@RDB500IManimScenePrimitiveId=pid.PrimitiveInputDefinitionId FROM [ATAPUtilities].[Primitive] p JOIN [ATAPUtilities].[PrimitiveVersion] pv ON pv.PrimitiveId=p.PrimitiveId AND pv.RevisionSequence=1 JOIN [ATAPUtilities].[PrimitiveInputDefinition] pid ON pid.PrimitiveVersionId=pv.PrimitiveVersionId AND pid.InputCode='content' WHERE p.RuleKindId=@RDB500IManimSceneRuleKindId AND p.PrimitiveCode='SimpleScene';
 IF @RDB500IManimScenePrimitiveId IS NULL THROW 55605,'RDB-500I root primitive input was not materialized.',1;
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500IManimSceneRuleKindId AND RuleCode='ReferenceScene') BEGIN INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500IManimSceneRuleTypeId,'b571a56f-bc2f-598b-8017-0500d1ee49ab',@RDB500IManimSceneNow); SET @RDB500IManimSceneEntityId=CONVERT(bigint,SCOPE_IDENTITY()); INSERT [ATAPUtilities].[Rule](RulePhiloteId,EntityId,EntityTypeId,RuleKindId,RuleCode,CreatedAtUtc) VALUES('b571a56f-bc2f-598b-8017-0500d1ee49ab',@RDB500IManimSceneEntityId,@RDB500IManimSceneRuleTypeId,@RDB500IManimSceneRuleKindId,'ReferenceScene',@RDB500IManimSceneNow); END;
 SELECT @RDB500IManimSceneRuleId=RuleId FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500IManimSceneRuleKindId AND RuleCode='ReferenceScene';
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500IManimSceneRuleId AND RevisionSequence=1) BEGIN INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500IManimSceneRuleVersionTypeId,'0eb2f78d-a71a-5191-813a-05d566752f1d',@RDB500IManimSceneNow); SET @RDB500IManimSceneEntityId=CONVERT(bigint,SCOPE_IDENTITY()); INSERT [ATAPUtilities].[RuleVersion](RuleVersionPhiloteId,EntityId,EntityTypeId,RuleId,RuleKindId,RuleKindVersionId,RevisionSequence,PredecessorRuleVersionId,CompositionHashAlgorithmCode,CompositionContentHash,PublishedAtUtc) VALUES('0eb2f78d-a71a-5191-813a-05d566752f1d',@RDB500IManimSceneEntityId,@RDB500IManimSceneRuleVersionTypeId,@RDB500IManimSceneRuleId,@RDB500IManimSceneRuleKindId,@RDB500IManimSceneRuleKindVersionId,1,NULL,'SHA-256',HASHBYTES('SHA2_256',N'ManimScene|ReferenceScene|ReferenceSafeScene'),@RDB500IManimSceneNow); END;
 SELECT @RDB500IManimSceneRuleVersionId=RuleVersionId FROM [ATAPUtilities].[RuleVersion] WHERE RuleId=@RDB500IManimSceneRuleId AND RevisionSequence=1;
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500IManimSceneRuleVersionId AND InputCode='scene_title') BEGIN INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500IManimSceneRuleInputTypeId,'57a8a5db-85e3-5105-84e2-ba2d0657fcae',@RDB500IManimSceneNow); SET @RDB500IManimSceneEntityId=CONVERT(bigint,SCOPE_IDENTITY()); INSERT [ATAPUtilities].[RuleInputDefinition](RuleInputDefinitionPhiloteId,EntityId,EntityTypeId,RuleVersionId,InputCode,Ordinal,ValueTypeVersionId,MinCardinality,MaxCardinality,AllowsNullElement,ValidationContractCode) VALUES('57a8a5db-85e3-5105-84e2-ba2d0657fcae',@RDB500IManimSceneEntityId,@RDB500IManimSceneRuleInputTypeId,@RDB500IManimSceneRuleVersionId,'scene_title',0,@RDB500IManimSceneValueTypeVersionId,1,1,0,'non-empty-text'); END;
 SELECT @RDB500IManimSceneRuleInputId=RuleInputDefinitionId FROM [ATAPUtilities].[RuleInputDefinition] WHERE RuleVersionId=@RDB500IManimSceneRuleVersionId AND InputCode='scene_title';
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[RuleDefaultInputValue] WHERE RuleInputDefinitionId=@RDB500IManimSceneRuleInputId) BEGIN INSERT [ATAPUtilities].[Entity](EntityTypeId,EntityPhiloteId,CreatedAtUtc) VALUES(@RDB500IManimSceneRuleDefaultTypeId,'1a2ba277-02ad-55db-ae21-f9a13a5f8aaa',@RDB500IManimSceneNow); SET @RDB500IManimSceneEntityId=CONVERT(bigint,SCOPE_IDENTITY()); INSERT [ATAPUtilities].[RuleDefaultInputValue](RuleDefaultInputValuePhiloteId,EntityId,EntityTypeId,RuleInputDefinitionId,RuleVersionId,ValueTypeVersionId,CanonicalTextValue,CanonicalValueHash,RationaleEntityId,RationaleEntityTypeId,PublishedAtUtc) VALUES('1a2ba277-02ad-55db-ae21-f9a13a5f8aaa',@RDB500IManimSceneEntityId,@RDB500IManimSceneRuleDefaultTypeId,@RDB500IManimSceneRuleInputId,@RDB500IManimSceneRuleVersionId,@RDB500IManimSceneValueTypeVersionId,N'ReferenceSafeScene',HASHBYTES('SHA2_256',N'ReferenceSafeScene'),(SELECT EntityId FROM [ATAPUtilities].[Rule] WHERE RuleId=@RDB500IManimSceneRuleId),@RDB500IManimSceneRuleTypeId,@RDB500IManimSceneNow); END;
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId='12af40d7-19c8-52f2-88c8-05c06aa6217c') INSERT [ATAPUtilities].[RuleVersionNode](RuleVersionNodePhiloteId,RuleVersionId,RuleKindVersionId,ParentRuleVersionNodeId,Ordinal,PrimitiveVersionId,MinOccurs,MaxOccurs,ChoiceDiscriminatorCode,NodeLabel) VALUES('12af40d7-19c8-52f2-88c8-05c06aa6217c',@RDB500IManimSceneRuleVersionId,@RDB500IManimSceneRuleKindVersionId,NULL,0,@RDB500IManimScenePrimitiveVersionId,1,1,NULL,N'root');
 SELECT @RDB500IManimSceneNodeId=RuleVersionNodeId FROM [ATAPUtilities].[RuleVersionNode] WHERE RuleVersionNodePhiloteId='12af40d7-19c8-52f2-88c8-05c06aa6217c';
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[RuleVersionNodeInput] WHERE RuleVersionNodeId=@RDB500IManimSceneNodeId AND PrimitiveInputDefinitionId=@RDB500IManimScenePrimitiveId) INSERT [ATAPUtilities].[RuleVersionNodeInput](RuleVersionNodeId,RuleVersionId,PrimitiveVersionId,PrimitiveInputDefinitionId,BindingShapeCode,TargetValueTypeVersionId,SourceValueTypeVersionId,ConstantValueTypeVersionId,RuleInputDefinitionId,DerivationContractVersionId,ConversionPolicyCode,CanonicalTextValue,CanonicalValueHash) VALUES(@RDB500IManimSceneNodeId,@RDB500IManimSceneRuleVersionId,@RDB500IManimScenePrimitiveVersionId,@RDB500IManimScenePrimitiveId,'constant',@RDB500IManimSceneValueTypeVersionId,NULL,@RDB500IManimSceneValueTypeVersionId,NULL,NULL,NULL,N'ReferenceSafeScene',HASHBYTES('SHA2_256',N'ReferenceSafeScene'));
 IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Primitive] WHERE RuleKindId=@RDB500IManimSceneRuleKindId) < 1 THROW 55606,'RDB-500I primitive row-count postcondition failed.',1;
 IF NOT EXISTS(SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleKindId=@RDB500IManimSceneRuleKindId AND RuleCode='ReferenceScene') THROW 55607,'RDB-500I rule postcondition failed.',1;
 COMMIT TRANSACTION;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;

/* END INTEGRATED FRAGMENT: RDB-500I__ManimScene.sql */

/* BEGIN INTEGRATED FRAGMENT: RDB-500O__ExpertiseDomain.sql */
/*
  RDB-500O draft reference seed: ExpertiseDomain hierarchy.

  Assumptions:
  - RDB-510 seeds the frozen RDB-270 EntityType catalog first.
  - The fixed publication timestamp is seed identity metadata, not an observation.
  - ExpertiseDomain classification never grants authorization.
*/
SET XACT_ABORT ON;
SET NOCOUNT ON;

DECLARE @Rdb500OOwnsTransaction bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
IF @Rdb500OOwnsTransaction = 1 BEGIN TRANSACTION;
ELSE SAVE TRANSACTION Rdb500OFragment;

BEGIN TRY
    DECLARE @Rdb500OPublishedAtUtc datetime2(7) = CONVERT(datetime2(7), '2026-08-06T00:00:00.0000000');
    DECLARE @Rdb500ODomainTypeId bigint =
        (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType]
         WHERE [EntityTypeCode] = 'expertise-domain');
    DECLARE @Rdb500ODomainVersionTypeId bigint =
        (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType]
         WHERE [EntityTypeCode] = 'expertise-domain-version');

    IF @Rdb500ODomainTypeId IS NULL OR @Rdb500ODomainVersionTypeId IS NULL
        THROW 55000, 'RDB-500O requires the frozen expertise-domain EntityType rows.', 1;

    DECLARE @Rdb500ODomains table
    (
        [ExpertiseDomainCode] varchar(128) NOT NULL PRIMARY KEY,
        [ExpertiseDomainPhiloteId] uniqueidentifier NOT NULL UNIQUE,
        [ExpertiseDomainVersionPhiloteId] uniqueidentifier NOT NULL UNIQUE,
        [ParentExpertiseDomainCode] varchar(128) NULL,
        [DisplayLabel] nvarchar(256) NOT NULL,
        [Description] nvarchar(2048) NOT NULL
    );

    INSERT INTO @Rdb500ODomains
        ([ExpertiseDomainCode], [ExpertiseDomainPhiloteId],
         [ExpertiseDomainVersionPhiloteId], [ParentExpertiseDomainCode],
         [DisplayLabel], [Description])
    VALUES
        ('software-production', '80b431f6-a2db-5cfe-8f86-51c6d77cdd1f', '154d7348-b607-5b6d-9bf1-5f2625e133ab', NULL, N'Software Production', N'Software construction and delivery; classification only.'),
        ('sprint-lifecycle', 'fc17e5e9-129c-5d51-a8fe-4979d124bf85', '216810b8-a5ba-5d2f-9923-240cf634409f', 'software-production', N'Sprint Lifecycle', N'Sprint start, execution, checkpoint, and close workflows.'),
        ('ai-canonical-configuration', '63db4d83-0b14-53d4-866a-79b6cd26ec89', '11448af8-2b47-55d9-8df9-7018dcb78984', 'software-production', N'AI Canonical Configuration', N'Canonical AI instructions, adapters, skills, and rendered surfaces.'),
        ('software-history', '350cc36e-834e-5fce-84e3-2b823f4cac54', 'fa509051-85a8-5774-9edf-f1df176c3901', 'software-production', N'Software History', N'Historical constrained rebuild and version lineage.'),
        ('storage-and-git-forensics', 'fdf4c30f-eb1e-50dc-98e5-fce33057fe2b', '79beac8a-d083-5db1-8191-58b4a683131a', 'software-production', N'Storage and Git Forensics', N'Disc, repository, and source reconstruction evidence.'),
        ('documentation-and-gazette', 'c3647bb0-818a-5da6-b4f4-0db0003aa1a5', 'a47cbe70-cd26-5d36-9e7f-d38621716a76', 'software-production', N'Documentation and Gazette', N'Content navigation, summaries, and durable documentation.'),
        ('security', '4387c249-cef7-5c87-b036-e2f03451233a', '00303abb-1ee4-5889-a88d-b48f9078785b', NULL, N'Security', N'Security subject classification; never an authorization grant.'),
        ('pki', 'cd173efd-151a-5889-bc8c-1724e603ae10', '02d608f2-627a-515f-9bd6-ab0e5d386a7b', 'security', N'PKI', N'Public-key-infrastructure metadata and acceptance workflows; no private keys.'),
        ('security-defensive', '31f681f5-9720-55bc-8776-652f141cafdb', '175010d2-5558-5c8e-8010-2fdcc592a527', 'security', N'Security / Defensive', N'Defensive-security metadata; execution remains separately authorized.'),
        ('security-offensive', '38444d55-2d96-52ea-9292-133860219215', '6eb6dc7b-1c8a-56ad-b7b2-b28ba7893366', 'security', N'Security / Offensive', N'Metadata only; execution disabled absent separate policy and approval.'),
        ('legal-entity', 'f717dd6d-71f4-5919-91f2-9880eab1a463', 'd373630a-6f06-5396-aafe-9a77d2216784', NULL, N'Legal Entity', N'Synthetic legal-entity filing and governance concepts.'),
        ('open-source-foundation', '98515d64-aed9-5ec8-bf7b-352838966695', 'c9ba7465-2508-5d08-9de1-07abb81f1d71', 'legal-entity', N'Open Source Foundation', N'Open-source foundation organizational concepts.'),
        ('for-profit-corporation', 'ea4e7e3d-16ce-5ac3-89b3-f1c1860247f3', 'f5af3364-cf95-5a79-b126-b22e8ad6167c', 'legal-entity', N'For-Profit Corporation', N'For-profit corporate organizational concepts.'),
        ('attribution', '6ba0fb07-cf6a-567c-9caf-d24af487d711', '68818fce-8add-5d1e-9a0a-c58ed1fa326f', NULL, N'Attribution', N'Authorship, contribution, license, and verification metadata.'),
        ('finance-and-reimbursement', 'a346f5dd-8cd9-5692-9c79-6ff86483d3c7', 'f259e5ec-62fe-5e41-bda0-5684993e3f1f', NULL, N'Finance and Reimbursement', N'Synthetic accounting and reimbursement concepts.'),
        ('usage-accounting', '86f9923d-7bbe-52cf-bebc-fc3bdcf0f041', 'bafdb51c-e638-5545-9e5c-e367b78751e0', 'finance-and-reimbursement', N'Usage Accounting', N'Usage measurement and accounting-event metadata.'),
        ('blender-and-texture-production', '64c86e53-f6cc-50b3-be8f-bd7032d87ff1', '58f50656-3dc5-5833-80ed-a1e72311f1b7', NULL, N'Blender and Texture Production', N'Blender setup, render, and texture-production workflows.'),
        ('hiking-and-gpx-reconciliation', '194784f0-b2c4-57f9-b357-128cf8e219d8', '8d9f3dc7-de5d-5bb1-a521-2501189319d6', NULL, N'Hiking and GPX Reconciliation', N'Hiking, device, track, and provenance reconciliation.'),
        ('recipe', 'f2aa28f4-e9ae-5b3f-b417-a69f174475f6', '1f997915-5a6e-51b0-a827-323699256ff5', NULL, N'Recipe', N'Recipe composition and manifested-output concepts.'),
        ('plant-and-wildflower', '1d9e5ffa-5088-5878-9147-d748c6b91ba4', '8765f741-4d36-5d46-a8f0-db1e8619494f', NULL, N'Plant and Wildflower', N'Plant and wildflower classification metadata.'),
        ('music', '4347c17d-1d19-51fe-be6a-274afab8c784', 'cbf3e290-085e-5ef5-a1d2-01037cb8a789', NULL, N'Music', N'Music catalog, attribution, and classification metadata.'),
        ('marketing', '76892fd3-fe57-5b52-b8f0-cb729fd5d3cf', '67bc417e-eab3-525f-9451-1dd2b3328b61', NULL, N'Marketing', N'Marketing content, workflow, usage, and measurement.'),
        ('advertising', 'd252d07c-cb2e-5b73-8fca-fd4153fd2604', '21d01455-7b22-58fd-9648-484cd1743465', 'marketing', N'Advertising', N'Advertising content and workflow metadata.'),
        ('social-media-and-trends', '4fd3a835-15b9-52b6-8a40-ae65abd00fe8', '5e43a1f8-88fe-5649-94e2-43061eb84ac9', 'marketing', N'Social Media and Trends', N'Social-media trend content and measurement metadata.'),
        ('commercial-feature-attribution', 'fad024e9-55a8-5db2-be7f-2e1e407fbf46', 'e5d525d5-b031-5668-a73f-cfdb4914f96e', 'marketing', N'Commercial Feature Attribution', N'Commercial feature provenance and attribution metadata.'),
        ('game-strategy', '1353d10f-2fa0-578a-b09d-840649290e58', '57277773-49eb-5967-880f-b587f74b5324', NULL, N'Game Strategy', N'Game strategy and expert-attribution concepts.'),
        ('bill-of-materials', '3c2b18c5-8539-5c4f-9aa7-eda6ce417412', '85e3f727-902c-5ab4-b0bb-13d707a9ed82', NULL, N'Bill of Materials', N'Item, quantity, unit, and substitution concepts.'),
        ('chemical-process', 'beca48bc-5696-5d91-92a2-573e90f9970d', '99c17fa7-4dd8-5e93-bf49-681b068d0a23', NULL, N'Chemical Process', N'Chemical-process metadata subject to separate safety and approval gates.');

    IF EXISTS
    (
        SELECT 1
        FROM @Rdb500ODomains AS [seed]
        INNER JOIN [ATAPUtilities].[ExpertiseDomain] AS [existing]
            ON [existing].[ExpertiseDomainCode] = [seed].[ExpertiseDomainCode]
        WHERE [existing].[ExpertiseDomainPhiloteId] <> [seed].[ExpertiseDomainPhiloteId]
    )
        THROW 55001, 'RDB-500O natural-key/Philote collision.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Rdb500ODomains AS [seed]
        INNER JOIN [ATAPUtilities].[ExpertiseDomain] AS [existing]
            ON [existing].[ExpertiseDomainPhiloteId] = [seed].[ExpertiseDomainPhiloteId]
        WHERE [existing].[ExpertiseDomainCode] <> [seed].[ExpertiseDomainCode]
    )
        THROW 55002, 'RDB-500O Philote/natural-key collision.', 1;

    INSERT INTO [ATAPUtilities].[Entity]
        ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
    SELECT @Rdb500ODomainTypeId, [seed].[ExpertiseDomainPhiloteId], @Rdb500OPublishedAtUtc
    FROM @Rdb500ODomains AS [seed]
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [ATAPUtilities].[Entity] AS [entity]
        WHERE [entity].[EntityPhiloteId] = [seed].[ExpertiseDomainPhiloteId]
    );

    INSERT INTO [ATAPUtilities].[ExpertiseDomain]
        ([ExpertiseDomainPhiloteId], [EntityId], [EntityTypeId],
         [ExpertiseDomainCode], [CreatedAtUtc])
    SELECT [seed].[ExpertiseDomainPhiloteId], [entity].[EntityId],
           @Rdb500ODomainTypeId, [seed].[ExpertiseDomainCode], @Rdb500OPublishedAtUtc
    FROM @Rdb500ODomains AS [seed]
    INNER JOIN [ATAPUtilities].[Entity] AS [entity]
        ON [entity].[EntityPhiloteId] = [seed].[ExpertiseDomainPhiloteId]
       AND [entity].[EntityTypeId] = @Rdb500ODomainTypeId
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [ATAPUtilities].[ExpertiseDomain] AS [existing]
        WHERE [existing].[ExpertiseDomainCode] = [seed].[ExpertiseDomainCode]
    );

    IF EXISTS
    (
        SELECT 1
        FROM @Rdb500ODomains AS [seed]
        INNER JOIN [ATAPUtilities].[ExpertiseDomain] AS [domain]
            ON [domain].[ExpertiseDomainCode] = [seed].[ExpertiseDomainCode]
        INNER JOIN [ATAPUtilities].[ExpertiseDomainVersion] AS [existing]
            ON [existing].[ExpertiseDomainId] = [domain].[ExpertiseDomainId]
           AND [existing].[RevisionSequence] = 1
        WHERE [existing].[ExpertiseDomainVersionPhiloteId]
              <> [seed].[ExpertiseDomainVersionPhiloteId]
    )
        THROW 55005, 'RDB-500O version natural-key/Philote collision.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Rdb500ODomains AS [seed]
        INNER JOIN [ATAPUtilities].[ExpertiseDomainVersion] AS [existing]
            ON [existing].[ExpertiseDomainVersionPhiloteId]
               = [seed].[ExpertiseDomainVersionPhiloteId]
        INNER JOIN [ATAPUtilities].[ExpertiseDomain] AS [domain]
            ON [domain].[ExpertiseDomainId] = [existing].[ExpertiseDomainId]
        WHERE [domain].[ExpertiseDomainCode] <> [seed].[ExpertiseDomainCode]
           OR [existing].[RevisionSequence] <> 1
    )
        THROW 55006, 'RDB-500O version Philote/natural-key collision.', 1;

    INSERT INTO [ATAPUtilities].[Entity]
        ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
    SELECT @Rdb500ODomainVersionTypeId, [seed].[ExpertiseDomainVersionPhiloteId], @Rdb500OPublishedAtUtc
    FROM @Rdb500ODomains AS [seed]
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [ATAPUtilities].[Entity] AS [entity]
        WHERE [entity].[EntityPhiloteId] = [seed].[ExpertiseDomainVersionPhiloteId]
    );

    /* Roots precede children so every exact parent version already exists. */
    INSERT INTO [ATAPUtilities].[ExpertiseDomainVersion]
        ([ExpertiseDomainVersionPhiloteId], [EntityId], [EntityTypeId],
         [ExpertiseDomainId], [RevisionSequence], [PredecessorExpertiseDomainVersionId],
         [ParentExpertiseDomainVersionId], [ParentExpertiseDomainId],
         [DisplayLabel], [Description], [PublishedAtUtc])
    SELECT [seed].[ExpertiseDomainVersionPhiloteId], [entity].[EntityId],
           @Rdb500ODomainVersionTypeId, [domain].[ExpertiseDomainId], 1, NULL,
           NULL, NULL, [seed].[DisplayLabel], [seed].[Description], @Rdb500OPublishedAtUtc
    FROM @Rdb500ODomains AS [seed]
    INNER JOIN [ATAPUtilities].[ExpertiseDomain] AS [domain]
        ON [domain].[ExpertiseDomainCode] = [seed].[ExpertiseDomainCode]
    INNER JOIN [ATAPUtilities].[Entity] AS [entity]
        ON [entity].[EntityPhiloteId] = [seed].[ExpertiseDomainVersionPhiloteId]
       AND [entity].[EntityTypeId] = @Rdb500ODomainVersionTypeId
    WHERE [seed].[ParentExpertiseDomainCode] IS NULL
      AND NOT EXISTS
      (
          SELECT 1 FROM [ATAPUtilities].[ExpertiseDomainVersion] AS [existing]
          WHERE [existing].[ExpertiseDomainId] = [domain].[ExpertiseDomainId]
            AND [existing].[RevisionSequence] = 1
      );

    INSERT INTO [ATAPUtilities].[ExpertiseDomainVersion]
        ([ExpertiseDomainVersionPhiloteId], [EntityId], [EntityTypeId],
         [ExpertiseDomainId], [RevisionSequence], [PredecessorExpertiseDomainVersionId],
         [ParentExpertiseDomainVersionId], [ParentExpertiseDomainId],
         [DisplayLabel], [Description], [PublishedAtUtc])
    SELECT [seed].[ExpertiseDomainVersionPhiloteId], [entity].[EntityId],
           @Rdb500ODomainVersionTypeId, [domain].[ExpertiseDomainId], 1, NULL,
           [parentVersion].[ExpertiseDomainVersionId], [parent].[ExpertiseDomainId],
           [seed].[DisplayLabel], [seed].[Description], @Rdb500OPublishedAtUtc
    FROM @Rdb500ODomains AS [seed]
    INNER JOIN [ATAPUtilities].[ExpertiseDomain] AS [domain]
        ON [domain].[ExpertiseDomainCode] = [seed].[ExpertiseDomainCode]
    INNER JOIN [ATAPUtilities].[Entity] AS [entity]
        ON [entity].[EntityPhiloteId] = [seed].[ExpertiseDomainVersionPhiloteId]
       AND [entity].[EntityTypeId] = @Rdb500ODomainVersionTypeId
    INNER JOIN [ATAPUtilities].[ExpertiseDomain] AS [parent]
        ON [parent].[ExpertiseDomainCode] = [seed].[ParentExpertiseDomainCode]
    INNER JOIN [ATAPUtilities].[ExpertiseDomainVersion] AS [parentVersion]
        ON [parentVersion].[ExpertiseDomainId] = [parent].[ExpertiseDomainId]
       AND [parentVersion].[RevisionSequence] = 1
    WHERE [seed].[ParentExpertiseDomainCode] IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1 FROM [ATAPUtilities].[ExpertiseDomainVersion] AS [existing]
          WHERE [existing].[ExpertiseDomainId] = [domain].[ExpertiseDomainId]
            AND [existing].[RevisionSequence] = 1
      );

    IF (SELECT COUNT(*) FROM [ATAPUtilities].[ExpertiseDomain] AS [domain]
        INNER JOIN @Rdb500ODomains AS [seed]
            ON [seed].[ExpertiseDomainCode] = [domain].[ExpertiseDomainCode]
           AND [seed].[ExpertiseDomainPhiloteId] = [domain].[ExpertiseDomainPhiloteId]) <> 28
        THROW 55003, 'RDB-500O domain row-count postcondition failed.', 1;

    IF (SELECT COUNT(*) FROM [ATAPUtilities].[ExpertiseDomainVersion] AS [version]
        INNER JOIN @Rdb500ODomains AS [seed]
            ON [seed].[ExpertiseDomainVersionPhiloteId] = [version].[ExpertiseDomainVersionPhiloteId]
        WHERE [version].[RevisionSequence] = 1) <> 28
        THROW 55004, 'RDB-500O version row-count postcondition failed.', 1;

    IF @Rdb500OOwnsTransaction = 1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @Rdb500OOwnsTransaction = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    ELSE IF @Rdb500OOwnsTransaction = 0 AND XACT_STATE() = 1
        ROLLBACK TRANSACTION Rdb500OFragment;
    THROW;
END CATCH;

/* END INTEGRATED FRAGMENT: RDB-500O__ExpertiseDomain.sql */

/* BEGIN INTEGRATED FRAGMENT: RDB-500P__AttributionMetadata.sql */
/*
  RDB-500P draft reference seed: synthetic attribution/license/contributor metadata.

  No person, private contact, credential, private key, or observed artifact is
  seeded. The current physical model has no standalone AttributionSource or
  License table; source/license metadata is therefore expressed through typed
  attribution roles and a non-secret synthetic ReasonReference.
*/
SET XACT_ABORT ON;
SET NOCOUNT ON;

DECLARE @Rdb500POwnsTransaction bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
IF @Rdb500POwnsTransaction = 1 BEGIN TRANSACTION;
ELSE SAVE TRANSACTION Rdb500PFragment;

BEGIN TRY
    DECLARE @Rdb500PPublishedAtUtc datetime2(7) = CONVERT(datetime2(7), '2026-08-06T00:00:00.0000000');
    DECLARE @Rdb500PAuthorityTypeId bigint =
        (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'authority');
    DECLARE @Rdb500PAuthorityVersionTypeId bigint =
        (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'authority-version');
    DECLARE @Rdb500PExpertTypeId bigint =
        (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'expert');
    DECLARE @Rdb500PExpertVersionTypeId bigint =
        (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'expert-version');
    DECLARE @Rdb500PAttributionTypeId bigint =
        (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'attribution');
    DECLARE @Rdb500PDomainVersionTypeId bigint =
        (SELECT [EntityTypeId] FROM [ATAPUtilities].[EntityType] WHERE [EntityTypeCode] = 'expertise-domain-version');

    IF @Rdb500PAuthorityTypeId IS NULL OR @Rdb500PAuthorityVersionTypeId IS NULL
       OR @Rdb500PExpertTypeId IS NULL OR @Rdb500PExpertVersionTypeId IS NULL
       OR @Rdb500PAttributionTypeId IS NULL OR @Rdb500PDomainVersionTypeId IS NULL
        THROW 55100, 'RDB-500P requires the frozen RDB-200 EntityType rows.', 1;

    DECLARE @Rdb500PAuthorityPhilote uniqueidentifier = 'ebcf50f0-4c83-5ef4-9a5e-d9c415114529';
    DECLARE @Rdb500PAuthorityVersionPhilote uniqueidentifier = 'b1b7462d-6e62-590d-a1c2-918ab41f7660';
    DECLARE @Rdb500PExpertPhilote uniqueidentifier = '5a726b05-99a8-5821-991f-5ed6787e5318';
    DECLARE @Rdb500PExpertVersionPhilote uniqueidentifier = '9644745f-b936-5f51-8841-184db2b1fab9';

    IF EXISTS
    (
        SELECT 1 FROM [ATAPUtilities].[Authority]
        WHERE ([AuthorityCode] = 'synthetic-reference-publisher'
               AND [AuthorityPhiloteId] <> @Rdb500PAuthorityPhilote)
           OR ([AuthorityPhiloteId] = @Rdb500PAuthorityPhilote
               AND [AuthorityCode] <> 'synthetic-reference-publisher')
    )
        THROW 55101, 'RDB-500P Authority natural-key/Philote collision.', 1;

    IF EXISTS
    (
        SELECT 1 FROM [ATAPUtilities].[Expert]
        WHERE ([ExpertCode] = 'synthetic-contributor'
               AND [ExpertPhiloteId] <> @Rdb500PExpertPhilote)
           OR ([ExpertPhiloteId] = @Rdb500PExpertPhilote
               AND [ExpertCode] <> 'synthetic-contributor')
    )
        THROW 55102, 'RDB-500P Expert natural-key/Philote collision.', 1;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] WHERE [EntityPhiloteId] = @Rdb500PAuthorityPhilote)
        INSERT INTO [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@Rdb500PAuthorityTypeId, @Rdb500PAuthorityPhilote, @Rdb500PPublishedAtUtc);
    DECLARE @Rdb500PAuthorityEntityId bigint =
        (SELECT [EntityId] FROM [ATAPUtilities].[Entity]
         WHERE [EntityPhiloteId] = @Rdb500PAuthorityPhilote AND [EntityTypeId] = @Rdb500PAuthorityTypeId);
    IF @Rdb500PAuthorityEntityId IS NULL
        THROW 55103, 'RDB-500P Authority Philote is registered to the wrong EntityType.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Authority] WHERE [AuthorityCode] = 'synthetic-reference-publisher')
        INSERT INTO [ATAPUtilities].[Authority]
            ([AuthorityPhiloteId], [EntityId], [EntityTypeId], [AuthorityCode], [CreatedAtUtc])
        VALUES
            (@Rdb500PAuthorityPhilote, @Rdb500PAuthorityEntityId, @Rdb500PAuthorityTypeId,
             'synthetic-reference-publisher', @Rdb500PPublishedAtUtc);
    DECLARE @Rdb500PAuthorityId bigint =
        (SELECT [AuthorityId] FROM [ATAPUtilities].[Authority]
         WHERE [AuthorityCode] = 'synthetic-reference-publisher');

    IF EXISTS
    (
        SELECT 1 FROM [ATAPUtilities].[AuthorityVersion]
        WHERE ([AuthorityId] = @Rdb500PAuthorityId AND [RevisionSequence] = 1
               AND [AuthorityVersionPhiloteId] <> @Rdb500PAuthorityVersionPhilote)
           OR ([AuthorityVersionPhiloteId] = @Rdb500PAuthorityVersionPhilote
               AND ([AuthorityId] <> @Rdb500PAuthorityId OR [RevisionSequence] <> 1))
    )
        THROW 55109, 'RDB-500P AuthorityVersion natural-key/Philote collision.', 1;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] WHERE [EntityPhiloteId] = @Rdb500PAuthorityVersionPhilote)
        INSERT INTO [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@Rdb500PAuthorityVersionTypeId, @Rdb500PAuthorityVersionPhilote, @Rdb500PPublishedAtUtc);
    DECLARE @Rdb500PAuthorityVersionEntityId bigint =
        (SELECT [EntityId] FROM [ATAPUtilities].[Entity]
         WHERE [EntityPhiloteId] = @Rdb500PAuthorityVersionPhilote
           AND [EntityTypeId] = @Rdb500PAuthorityVersionTypeId);
    IF @Rdb500PAuthorityVersionEntityId IS NULL
        THROW 55104, 'RDB-500P AuthorityVersion Philote is registered to the wrong EntityType.', 1;
    IF NOT EXISTS
       (SELECT 1 FROM [ATAPUtilities].[AuthorityVersion]
        WHERE [AuthorityId] = @Rdb500PAuthorityId AND [RevisionSequence] = 1)
        INSERT INTO [ATAPUtilities].[AuthorityVersion]
            ([AuthorityVersionPhiloteId], [EntityId], [EntityTypeId], [AuthorityId],
             [RevisionSequence], [PredecessorAuthorityVersionId], [AuthorityKindCode],
             [DisplayLabel], [Description], [PublishedAtUtc])
        VALUES
            (@Rdb500PAuthorityVersionPhilote, @Rdb500PAuthorityVersionEntityId,
             @Rdb500PAuthorityVersionTypeId, @Rdb500PAuthorityId, 1, NULL,
             'synthetic-reference-publisher', N'Synthetic Reference Publisher',
             N'Non-person reference identity used only by the RDB-500 seed catalog.',
             @Rdb500PPublishedAtUtc);

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] WHERE [EntityPhiloteId] = @Rdb500PExpertPhilote)
        INSERT INTO [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@Rdb500PExpertTypeId, @Rdb500PExpertPhilote, @Rdb500PPublishedAtUtc);
    DECLARE @Rdb500PExpertEntityId bigint =
        (SELECT [EntityId] FROM [ATAPUtilities].[Entity]
         WHERE [EntityPhiloteId] = @Rdb500PExpertPhilote AND [EntityTypeId] = @Rdb500PExpertTypeId);
    IF @Rdb500PExpertEntityId IS NULL
        THROW 55105, 'RDB-500P Expert Philote is registered to the wrong EntityType.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Expert] WHERE [ExpertCode] = 'synthetic-contributor')
        INSERT INTO [ATAPUtilities].[Expert]
            ([ExpertPhiloteId], [EntityId], [EntityTypeId], [ExpertCode], [CreatedAtUtc])
        VALUES
            (@Rdb500PExpertPhilote, @Rdb500PExpertEntityId, @Rdb500PExpertTypeId,
             'synthetic-contributor', @Rdb500PPublishedAtUtc);
    DECLARE @Rdb500PExpertId bigint =
        (SELECT [ExpertId] FROM [ATAPUtilities].[Expert]
         WHERE [ExpertCode] = 'synthetic-contributor');

    IF EXISTS
    (
        SELECT 1 FROM [ATAPUtilities].[ExpertVersion]
        WHERE ([ExpertId] = @Rdb500PExpertId AND [RevisionSequence] = 1
               AND [ExpertVersionPhiloteId] <> @Rdb500PExpertVersionPhilote)
           OR ([ExpertVersionPhiloteId] = @Rdb500PExpertVersionPhilote
               AND ([ExpertId] <> @Rdb500PExpertId OR [RevisionSequence] <> 1))
    )
        THROW 55110, 'RDB-500P ExpertVersion natural-key/Philote collision.', 1;

    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Entity] WHERE [EntityPhiloteId] = @Rdb500PExpertVersionPhilote)
        INSERT INTO [ATAPUtilities].[Entity] ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
        VALUES (@Rdb500PExpertVersionTypeId, @Rdb500PExpertVersionPhilote, @Rdb500PPublishedAtUtc);
    DECLARE @Rdb500PExpertVersionEntityId bigint =
        (SELECT [EntityId] FROM [ATAPUtilities].[Entity]
         WHERE [EntityPhiloteId] = @Rdb500PExpertVersionPhilote
           AND [EntityTypeId] = @Rdb500PExpertVersionTypeId);
    IF @Rdb500PExpertVersionEntityId IS NULL
        THROW 55106, 'RDB-500P ExpertVersion Philote is registered to the wrong EntityType.', 1;
    IF NOT EXISTS
       (SELECT 1 FROM [ATAPUtilities].[ExpertVersion]
        WHERE [ExpertId] = @Rdb500PExpertId AND [RevisionSequence] = 1)
        INSERT INTO [ATAPUtilities].[ExpertVersion]
            ([ExpertVersionPhiloteId], [EntityId], [EntityTypeId], [ExpertId],
             [RevisionSequence], [PredecessorExpertVersionId], [DisplayLabel],
             [NonSecretDescription], [PublishedAtUtc])
        VALUES
            (@Rdb500PExpertVersionPhilote, @Rdb500PExpertVersionEntityId,
             @Rdb500PExpertVersionTypeId, @Rdb500PExpertId, 1, NULL,
             N'Synthetic Contributor',
             N'Non-person, non-contact fixture identity; contains no PII or credential.',
             @Rdb500PPublishedAtUtc);

    DECLARE @Rdb500PSubjectEntityId bigint =
        (SELECT [version].[EntityId]
         FROM [ATAPUtilities].[ExpertiseDomainVersion] AS [version]
         INNER JOIN [ATAPUtilities].[ExpertiseDomain] AS [domain]
             ON [domain].[ExpertiseDomainId] = [version].[ExpertiseDomainId]
         WHERE [domain].[ExpertiseDomainCode] = 'software-production'
           AND [version].[RevisionSequence] = 1);
    IF @Rdb500PSubjectEntityId IS NULL
        THROW 55107, 'RDB-500P requires the RDB-500O software-production domain version.', 1;

    DECLARE @Rdb500PAttributionSeed table
    (
        [RelationshipRoleCode] varchar(64) NOT NULL PRIMARY KEY,
        [AttributionPhiloteId] uniqueidentifier NOT NULL UNIQUE,
        [AttributedEntityId] bigint NOT NULL,
        [AttributedEntityTypeId] bigint NOT NULL,
        [ReasonReference] nvarchar(2048) NOT NULL
    );
    INSERT INTO @Rdb500PAttributionSeed
        ([RelationshipRoleCode], [AttributionPhiloteId], [AttributedEntityId],
         [AttributedEntityTypeId], [ReasonReference])
    VALUES
        ('authored-by', '69540ce0-dbf5-53b8-a4ee-244c7c580ec9',
         @Rdb500PExpertVersionEntityId, @Rdb500PExpertVersionTypeId,
         N'repo:SolutionDocumentation/Attribution.md;sha256:C4BDE2025B28B038707F13D1C92FCBE7DF33D6E482FDC0966807A5F9FA80A36C;assertion=synthetic-authorship'),
        ('contributed-by', '763899f8-a218-5b23-981c-de170be16796',
         @Rdb500PExpertVersionEntityId, @Rdb500PExpertVersionTypeId,
         N'repo:SolutionDocumentation/Attribution.md;sha256:C4BDE2025B28B038707F13D1C92FCBE7DF33D6E482FDC0966807A5F9FA80A36C;assertion=synthetic-contribution'),
        ('licensed-by', '3e5fdd29-2fec-517b-af75-97a20f973e40',
         @Rdb500PAuthorityVersionEntityId, @Rdb500PAuthorityVersionTypeId,
         N'repo:LICENSE;sha256:184E5732B2EC7984A606EB598CA88AA30F6DFBA3575093FF4802CC812FBF6596;license=repository-license');

    INSERT INTO [ATAPUtilities].[RelationshipRolePolicy]
        ([RelationshipKindCode], [RelationshipRoleCode],
         [IsClassificationOnly], [IsAuthorizationRole])
    SELECT 'attribution', [seed].[RelationshipRoleCode], CONVERT(bit, 0), CONVERT(bit, 0)
    FROM @Rdb500PAttributionSeed AS [seed]
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [ATAPUtilities].[RelationshipRolePolicy] AS [policy]
        WHERE [policy].[RelationshipKindCode] = 'attribution'
          AND [policy].[RelationshipRoleCode] = [seed].[RelationshipRoleCode]
    );

    DECLARE @Rdb500PEndpointSeed table
    (
        [RelationshipRoleCode] varchar(64) NOT NULL,
        [EndpointCode] varchar(32) NOT NULL,
        [EntityTypeId] bigint NOT NULL,
        PRIMARY KEY ([RelationshipRoleCode], [EndpointCode], [EntityTypeId])
    );
    INSERT INTO @Rdb500PEndpointSeed
        ([RelationshipRoleCode], [EndpointCode], [EntityTypeId])
    VALUES
        ('authored-by', 'attributed', @Rdb500PExpertVersionTypeId),
        ('authored-by', 'subject', @Rdb500PDomainVersionTypeId),
        ('authored-by', 'actor', @Rdb500PExpertVersionTypeId),
        ('contributed-by', 'attributed', @Rdb500PExpertVersionTypeId),
        ('contributed-by', 'subject', @Rdb500PDomainVersionTypeId),
        ('contributed-by', 'actor', @Rdb500PExpertVersionTypeId),
        ('licensed-by', 'attributed', @Rdb500PAuthorityVersionTypeId),
        ('licensed-by', 'subject', @Rdb500PDomainVersionTypeId),
        ('licensed-by', 'actor', @Rdb500PExpertVersionTypeId);

    INSERT INTO [ATAPUtilities].[RelationshipRoleEndpointEntityType]
        ([RelationshipRolePolicyId], [EndpointCode], [EntityTypeId])
    SELECT [policy].[RelationshipRolePolicyId], [seed].[EndpointCode], [seed].[EntityTypeId]
    FROM @Rdb500PEndpointSeed AS [seed]
    INNER JOIN [ATAPUtilities].[RelationshipRolePolicy] AS [policy]
        ON [policy].[RelationshipKindCode] = 'attribution'
       AND [policy].[RelationshipRoleCode] = [seed].[RelationshipRoleCode]
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [ATAPUtilities].[RelationshipRoleEndpointEntityType] AS [existing]
        WHERE [existing].[RelationshipRolePolicyId] = [policy].[RelationshipRolePolicyId]
          AND [existing].[EndpointCode] = [seed].[EndpointCode]
          AND [existing].[EntityTypeId] = [seed].[EntityTypeId]
    );

    INSERT INTO [ATAPUtilities].[Entity]
        ([EntityTypeId], [EntityPhiloteId], [CreatedAtUtc])
    SELECT @Rdb500PAttributionTypeId, [seed].[AttributionPhiloteId], @Rdb500PPublishedAtUtc
    FROM @Rdb500PAttributionSeed AS [seed]
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [ATAPUtilities].[Entity] AS [entity]
        WHERE [entity].[EntityPhiloteId] = [seed].[AttributionPhiloteId]
    );

    INSERT INTO [ATAPUtilities].[Attribution]
        ([AttributionPhiloteId], [EntityId], [EntityTypeId],
         [RelationshipRolePolicyId], [AttributedEndpointCode],
         [AttributedEntityId], [AttributedEntityTypeId], [SubjectEndpointCode],
         [SubjectEntityId], [SubjectEntityTypeId], [EvidenceEndpointCode],
         [EvidenceEntityId], [EvidenceEntityTypeId], [SupersedesAttributionId],
         [IsRetraction], [ActorEndpointCode], [AssertedByEntityId],
         [AssertedByEntityTypeId], [AssertedAtUtc], [RecordedAtUtc], [ReasonReference])
    SELECT [seed].[AttributionPhiloteId], [entity].[EntityId], @Rdb500PAttributionTypeId,
           [policy].[RelationshipRolePolicyId], 'attributed',
           [seed].[AttributedEntityId], [seed].[AttributedEntityTypeId], 'subject',
           @Rdb500PSubjectEntityId, @Rdb500PDomainVersionTypeId, NULL, NULL, NULL,
           NULL, CONVERT(bit, 0), 'actor', @Rdb500PExpertVersionEntityId,
           @Rdb500PExpertVersionTypeId, @Rdb500PPublishedAtUtc,
           @Rdb500PPublishedAtUtc, [seed].[ReasonReference]
    FROM @Rdb500PAttributionSeed AS [seed]
    INNER JOIN [ATAPUtilities].[Entity] AS [entity]
        ON [entity].[EntityPhiloteId] = [seed].[AttributionPhiloteId]
       AND [entity].[EntityTypeId] = @Rdb500PAttributionTypeId
    INNER JOIN [ATAPUtilities].[RelationshipRolePolicy] AS [policy]
        ON [policy].[RelationshipKindCode] = 'attribution'
       AND [policy].[RelationshipRoleCode] = [seed].[RelationshipRoleCode]
    WHERE NOT EXISTS
    (
        SELECT 1 FROM [ATAPUtilities].[Attribution] AS [existing]
        WHERE [existing].[AttributionPhiloteId] = [seed].[AttributionPhiloteId]
    );

    IF EXISTS
    (
        SELECT 1
        FROM @Rdb500PAttributionSeed AS [seed]
        INNER JOIN [ATAPUtilities].[Attribution] AS [existing]
            ON [existing].[AttributionPhiloteId] = [seed].[AttributionPhiloteId]
        INNER JOIN [ATAPUtilities].[RelationshipRolePolicy] AS [policy]
            ON [policy].[RelationshipRolePolicyId] = [existing].[RelationshipRolePolicyId]
        WHERE [policy].[RelationshipKindCode] <> 'attribution'
           OR [policy].[RelationshipRoleCode] <> [seed].[RelationshipRoleCode]
           OR [existing].[AttributedEntityId] <> [seed].[AttributedEntityId]
           OR [existing].[AttributedEntityTypeId] <> [seed].[AttributedEntityTypeId]
           OR [existing].[SubjectEntityId] <> @Rdb500PSubjectEntityId
           OR [existing].[SubjectEntityTypeId] <> @Rdb500PDomainVersionTypeId
    )
        THROW 55111, 'RDB-500P attribution Philote/claim collision.', 1;

    IF (SELECT COUNT(*) FROM [ATAPUtilities].[Attribution] AS [attribution]
        INNER JOIN @Rdb500PAttributionSeed AS [seed]
            ON [seed].[AttributionPhiloteId] = [attribution].[AttributionPhiloteId]) <> 3
        THROW 55108, 'RDB-500P attribution row-count postcondition failed.', 1;

    IF @Rdb500POwnsTransaction = 1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @Rdb500POwnsTransaction = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    ELSE IF @Rdb500POwnsTransaction = 0 AND XACT_STATE() = 1
        ROLLBACK TRANSACTION Rdb500PFragment;
    THROW;
END CATCH;

/* END INTEGRATED FRAGMENT: RDB-500P__AttributionMetadata.sql */
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
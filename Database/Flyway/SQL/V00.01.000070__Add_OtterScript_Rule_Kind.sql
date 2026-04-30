-- =====================================================================
-- V00.01.000070__Add_OtterScript_Rule_Kind.sql
--
-- Adds the OtterScript primitive language kind and the first set of
-- primitives needed to compose the CSharpPackage-PerProject BuildMaster
-- pipeline from rules.
-- =====================================================================
SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRANSACTION;

BEGIN TRY
    IF NOT EXISTS (
        SELECT 1
        FROM ATAPUtilities.PrimitiveLanguageKind
        WHERE PrimitiveLanguageKindId = 7 OR [Name] = N'OtterScript'
    )
    BEGIN
        INSERT INTO ATAPUtilities.PrimitiveLanguageKind
            (PrimitiveLanguageKindId, [Name], [Description])
        VALUES
            (7, N'OtterScript', N'BuildMaster OtterScript primitives and rules for deployment plan composition');
    END;

    DECLARE @PrimitiveLanguageKindId TINYINT =
        (SELECT PrimitiveLanguageKindId FROM ATAPUtilities.PrimitiveLanguageKind WHERE [Name] = N'OtterScript');

    DECLARE @Primitives TABLE (
        PhiloteId UNIQUEIDENTIFIER NOT NULL,
        [Name] NVARCHAR(200) NOT NULL,
        [Description] NVARCHAR(MAX) NULL
    );

    INSERT INTO @Primitives (PhiloteId, [Name], [Description])
    VALUES
        ('99bdfd9a-f48a-4398-add4-003dc1877751', N'<otter-plan>', N'Top-level OtterScript plan containing ordered statements and blocks.'),
        ('416f4f37-2f36-4a60-b90a-a41e4407bab3', N'<otter-set-variable>', N'Variable assignment using OtterScript set syntax.'),
        ('db4c13a8-90d9-4413-b817-dcb38613de5c', N'<otter-if-block>', N'Conditional execution block for tier-specific pipeline stages.'),
        ('d7f33ea3-fb8d-4394-b281-2696e13e815b', N'<otter-foreach-block>', N'Foreach loop over a collection expression.'),
        ('0fdc4fcc-7434-4160-baa6-db89e530044a', N'<otter-exec-step>', N'Generic Exec operation that invokes an external command.'),
        ('5283f51b-1b3e-48b2-baed-d42e57979603', N'<dotnet-pack-step>', N'Dotnet pack Exec operation for producing NuGet packages.'),
        ('25c22691-48da-4f46-a4ea-ac0b5b5f50bc', N'<proget-nuget-push-step>', N'Dotnet nuget push Exec operation targeting a ProGet feed.'),
        ('77ecc33b-bf1b-434b-b972-6371dbc09f37', N'<create-artifact-step>', N'BuildMaster Create-Artifact operation for publishing generated files.'),
        ('c12eeb76-53ad-45dd-8d05-8ab773c30a22', N'<otter-log-step>', N'BuildMaster log statement for diagnostic output.');

    INSERT INTO ATAPUtilities.Philote (PhiloteId)
    SELECT p.PhiloteId
    FROM @Primitives AS p
    WHERE NOT EXISTS (
        SELECT 1 FROM ATAPUtilities.Philote AS existing WHERE existing.PhiloteId = p.PhiloteId
    );

    INSERT INTO ATAPUtilities.RulePrimitive
        (PhiloteId, PrimitiveLanguageKindId, [Name], [Description])
    SELECT
        p.PhiloteId,
        @PrimitiveLanguageKindId,
        p.[Name],
        p.[Description]
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
        (N'<otter-plan>', N'Statements', N'ordered OtterScript statement list', N'Ordered statements and blocks rendered into the plan.', NULL, 1),
        (N'<otter-set-variable>', N'VariableName', N'string', N'Name of the OtterScript variable without the leading dollar sign.', NULL, 1),
        (N'<otter-set-variable>', N'ValueExpression', N'string', N'Literal or expression assigned to the variable.', NULL, 1),
        (N'<otter-if-block>', N'ConditionExpression', N'string', N'OtterScript condition expression after the if keyword.', NULL, 1),
        (N'<otter-if-block>', N'Body', N'ordered OtterScript statement list', N'Statements rendered inside the conditional block.', NULL, 1),
        (N'<otter-foreach-block>', N'ItemVariableName', N'string', N'Loop variable name without the leading dollar sign.', NULL, 1),
        (N'<otter-foreach-block>', N'CollectionExpression', N'string', N'Collection expression iterated by the loop.', NULL, 1),
        (N'<otter-foreach-block>', N'Body', N'ordered OtterScript statement list', N'Statements rendered inside the loop body.', NULL, 1),
        (N'<otter-exec-step>', N'ExecutableName', N'string', N'Command or executable invoked by Exec.', NULL, 1),
        (N'<otter-exec-step>', N'Arguments', N'string', N'Command-line arguments passed to the executable.', NULL, 1),
        (N'<otter-exec-step>', N'WorkingDirectory', N'string', N'Working directory used for the command.', N'$SourcePath', 0),
        (N'<otter-exec-step>', N'SuccessExitCode', N'int', N'Exit code treated as success by BuildMaster.', N'0', 0),
        (N'<dotnet-pack-step>', N'ProjectPath', N'string', N'Project or solution path passed to dotnet pack.', NULL, 1),
        (N'<dotnet-pack-step>', N'Configuration', N'string', N'Dotnet build configuration.', N'Release', 0),
        (N'<dotnet-pack-step>', N'OutputPath', N'string', N'Output folder for generated packages.', NULL, 1),
        (N'<dotnet-pack-step>', N'WorkingDirectory', N'string', N'Working directory for dotnet pack.', N'$SourcePath', 0),
        (N'<proget-nuget-push-step>', N'PackageGlob', N'string', N'Glob for packages to push.', NULL, 1),
        (N'<proget-nuget-push-step>', N'ProGetUrl', N'string', N'Base URL for the ProGet server.', N'$ProGetUrl', 0),
        (N'<proget-nuget-push-step>', N'FeedName', N'string', N'ProGet feed name resolved for the current tier.', N'$FeedName', 0),
        (N'<proget-nuget-push-step>', N'ProGetApiKey', N'string', N'BuildMaster secret expression for the ProGet API key.', N'$Decrypt($ProGetApiKey)', 0),
        (N'<proget-nuget-push-step>', N'SkipDuplicate', N'bool', N'Adds --skip-duplicate when true.', N'true', 0),
        (N'<create-artifact-step>', N'ArtifactName', N'string', N'Name of the BuildMaster artifact.', NULL, 1),
        (N'<create-artifact-step>', N'FromPath', N'string', N'Folder containing artifact files.', NULL, 1),
        (N'<create-artifact-step>', N'IncludePattern', N'string', N'BuildMaster Include pattern.', N'@(*)', 0),
        (N'<otter-log-step>', N'Level', N'string', N'BuildMaster log level, such as Debug or Information.', N'Debug', 0),
        (N'<otter-log-step>', N'Message', N'string', N'Message expression to log.', NULL, 1);

    INSERT INTO ATAPUtilities.RulePrimitiveInput
        (PhiloteId, InputName, TypeName, [Description], DefaultValue, IsRequired)
    SELECT
        rp.PhiloteId,
        i.InputName,
        i.TypeName,
        i.[Description],
        i.DefaultValue,
        i.IsRequired
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

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

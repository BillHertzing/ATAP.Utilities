#Requires -Version 7.0
#Requires -Module Pester

Set-StrictMode -Version Latest

BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
    $flywayConfig = Join-Path $repoRoot 'Database\Flyway\flyway.toml'
    $fixturePath = Join-Path $PSScriptRoot 'Fixtures\RPRRSBSI-V4-CoreIdentityOverlay.DatabaseFixtures.json'
    $fixtureText = Get-Content -LiteralPath $fixturePath -Raw
    $fixture = $fixtureText | ConvertFrom-Json -Depth 20
    $targetMigrationPath = Join-Path $sqlDirectory $fixture.target.migration
    $targetMigrationText = Get-Content -LiteralPath $targetMigrationPath -Raw
    $authorization = [Environment]::GetEnvironmentVariable(
        $fixture.safety.authorizationEnvironmentVariable,
        'Process')
    $localInstance = [Environment]::GetEnvironmentVariable(
        $fixture.safety.instanceEnvironmentVariable,
        'Process')
    $createdDatabases = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $canonicalGuidPattern = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    $migrationHashes = [ordered]@{}
    foreach ($entry in @($fixture.predecessors)) {
        $migrationHashes[$entry.migration] = $entry.sha256
    }
    if (-not [string]::IsNullOrWhiteSpace($fixture.target.sha256)) {
        $migrationHashes[$fixture.target.migration] = $fixture.target.sha256
    }

    function Assert-V4DisposableTarget {
        param(
            [Parameter(Mandatory)][AllowEmptyString()][string] $Marker,
            [Parameter(Mandatory)][AllowEmptyString()][string] $Instance,
            [Parameter(Mandatory)][string] $Name
        )

        if ($Marker -cne $fixture.safety.authorizationMarker) {
            throw 'Task 15.140.c V4 disposable authorization marker required.'
        }
        $parts = $Instance.Split('\')
        if ($parts.Count -ne 2 -or
            $parts[0] -notin @('.', 'localhost', '127.0.0.1', [Environment]::MachineName) -or
            $parts[1] -ine $fixture.safety.requiredInstanceName) {
            throw 'Only the local ExpWhertzing instance is permitted.'
        }
        if ($Name -cnotmatch $fixture.safety.databaseNamePattern) {
            throw 'Unsafe Task 15.140.c V4 disposable database name.'
        }
    }

    function Assert-V4MigrationBytes {
        param([Parameter(Mandatory)][string] $Directory)

        foreach ($name in $migrationHashes.Keys) {
            $path = Join-Path $Directory $name
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                throw "Required migration is absent: $name"
            }
            $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
            if ($actual -cne $migrationHashes[$name]) {
                throw "Immutable migration drift: $name"
            }
        }
    }

    function New-V4StagedMigrationDirectory {
        param([Parameter(Mandatory)][string] $DatabaseName)

        Assert-V4DisposableTarget -Marker $authorization -Instance $localInstance -Name $DatabaseName
        Assert-V4MigrationBytes -Directory $sqlDirectory
        $directory = Join-Path $repoRoot (
            '_generated\Sprint0015\Task15.140\c\stream-b-v4-database-acceptance-20260904\runs\' +
            $DatabaseName + '\migrations')
        $null = New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop
        foreach ($name in $migrationHashes.Keys) {
            Copy-Item -LiteralPath (Join-Path $sqlDirectory $name) -Destination $directory -ErrorAction Stop
        }
        Assert-V4MigrationBytes -Directory $directory
        $directory
    }

    function New-V4DisposableDatabase {
        $name = 'ATAPUtilities_Task15140cV4_' + [guid]::NewGuid().ToString('N')
        Assert-V4DisposableTarget -Marker $authorization -Instance $localInstance -Name $name
        $null = Get-Command sqlcmd -ErrorAction Stop
        & sqlcmd -S $localInstance -E -d master -b -Q "CREATE DATABASE [$name];"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create disposable database $name."
        }
        if (-not $createdDatabases.Add($name)) {
            throw "Disposable database ownership was not recorded for $name."
        }
        $name
    }

    function Remove-V4DisposableDatabase {
        param([Parameter(Mandatory)][string] $Name)

        Assert-V4DisposableTarget -Marker $authorization -Instance $localInstance -Name $Name
        if (-not $createdDatabases.Contains($Name)) {
            throw 'Refusing to remove an unowned disposable database.'
        }
        & sqlcmd -S $localInstance -E -d master -b -Q (
            "ALTER DATABASE [$Name] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$Name];")
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to remove disposable database $Name."
        }
        $null = $createdDatabases.Remove($Name)
    }

    function Invoke-V4Sql {
        param(
            [Parameter(Mandatory)][string] $DatabaseName,
            [Parameter(Mandatory)][string] $Query,
            [switch] $Master
        )

        Assert-V4DisposableTarget -Marker $authorization -Instance $localInstance -Name $DatabaseName
        if (-not $Master -and -not $createdDatabases.Contains($DatabaseName)) {
            throw 'Refusing SQL execution against an unowned disposable database.'
        }
        $database = if ($Master) { 'master' } else { $DatabaseName }
        $sessionProfile = @(
            'SET ANSI_NULLS ON'
            'SET QUOTED_IDENTIFIER ON'
            'SET ANSI_PADDING ON'
            'SET ANSI_WARNINGS ON'
            'SET ARITHABORT ON'
            'SET CONCAT_NULL_YIELDS_NULL ON'
            'SET NUMERIC_ROUNDABORT OFF'
            'SET NOCOUNT ON'
        ) -join '; '
        $queryDirectory = Join-Path $repoRoot (
            '_generated\Sprint0015\Task15.140\c\stream-b-v4-database-acceptance-20260904\queries')
        $null = New-Item -ItemType Directory -Path $queryDirectory -Force -ErrorAction Stop
        $queryPath = Join-Path $queryDirectory (
            'query-' + [guid]::NewGuid().ToString('N') + '.sql')
        [IO.File]::WriteAllText(
            $queryPath,
            "$sessionProfile; $Query",
            [Text.UTF8Encoding]::new($false))
        $output = & sqlcmd -S $localInstance -E -d $database -b -y 0 -i $queryPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Disposable SQL execution failed: $($output -join [Environment]::NewLine)"
        }
        ($output | ForEach-Object { "$_".TrimEnd() } | Where-Object { $_ }) -join [Environment]::NewLine
    }

    function Invoke-V4Flyway {
        param(
            [Parameter(Mandatory)][string] $DatabaseName,
            [Parameter(Mandatory)][string] $MigrationDirectory,
            [Parameter(Mandatory)][ValidateSet('70', '80')][string] $Target,
            [Parameter(Mandatory)][ValidateSet('migrate', 'validate')][string] $Command
        )

        Assert-V4DisposableTarget -Marker $authorization -Instance $localInstance -Name $DatabaseName
        if (-not $createdDatabases.Contains($DatabaseName)) {
            throw 'Refusing Flyway execution against an unowned disposable database.'
        }
        Assert-V4MigrationBytes -Directory $MigrationDirectory
        $null = Get-Command flyway -ErrorAction Stop
        $jdbcUrl = "jdbc:sqlserver://$localInstance;databaseName=$DatabaseName;integratedSecurity=true;encrypt=true;trustServerCertificate=true"
        $flywayArguments = @(
            "-configFiles=$flywayConfig"
            "-locations=filesystem:$MigrationDirectory"
            "-url=$jdbcUrl"
            "-target=$Target"
            '-cleanDisabled=true'
            '-baselineOnMigrate=false'
            '-outOfOrder=false'
            '-validateOnMigrate=true'
            $Command
        )
        $output = & flyway @flywayArguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Flyway $Command to V000$Target failed: $($output -join [Environment]::NewLine)"
        }
    }

    $surfaceAndGuidSql = @'
IF (SELECT COUNT_BIG(*) FROM [dbo].[flyway_schema_history] WHERE [success]=1)<>7
 THROW 58920,'Expected exactly seven successful migrations through V00080.',1;
IF EXISTS
(
 SELECT expected.Name FROM (VALUES
  ('ValueType'),('InputNormalizationContract'),('RuleInputDefinition'),('RuleInputDefinitionState'),('RuleDefaultInputValue'),
  ('RuleOutputDefinition'),('RuleOutputDefinitionState'),('RuleValueConstraint'),('RuleVariant'),('RuleVariantState'),
  ('RuleVariantInputDefinition'),('RuleVariantOutputDefinition'),
  ('RuleSetMembershipRole'),('RuleSetRuleOccurrence'),('BuildSetRuleSetOccurrence')) expected(Name)
 WHERE OBJECT_ID(N'[ATAPUtilities].['+expected.Name+N']',N'U') IS NULL
)
 THROW 58921,'A required V00080 table is absent.',1;
IF OBJECT_ID(N'[ATAPUtilities].[ResolveBuildSetRulesAsOf]',N'P') IS NULL
 THROW 58922,'The V00080 resolver is absent.',1;
IF EXISTS
(
 SELECT expected.Code FROM (VALUES ('Add'),('Override'),('Suppress')) expected(Code)
 WHERE NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleSetMembershipRole] actual
                   WHERE actual.RuleSetMembershipRoleCode=expected.Code)
)
 THROW 58923,'The controlled membership roles are incomplete.',1;
DECLARE @Canonical uniqueidentifier=CONVERT(uniqueidentifier,'abcdef01-2345-4678-9abc-def012345678');
DECLARE @Upper uniqueidentifier=CONVERT(uniqueidentifier,'ABCDEF01-2345-4678-9ABC-DEF012345678');
DECLARE @Braced uniqueidentifier=CONVERT(uniqueidentifier,'{abcdef01-2345-4678-9abc-def012345678}');
DECLARE @Different uniqueidentifier=CONVERT(uniqueidentifier,'abcdef01-2345-4678-9abc-def012345679');
IF @Canonical<>@Upper OR @Canonical<>@Braced OR @Canonical=@Different
 THROW 58924,'Native uniqueidentifier equality is not value-based.',1;
'@

    $identitySql = @'
DECLARE @RuleId uniqueidentifier=(SELECT TOP(1) RuleId FROM [ATAPUtilities].[Rule] ORDER BY RuleId);
DECLARE @RuleSetId uniqueidentifier=(SELECT TOP(1) RuleSetId FROM [ATAPUtilities].[RuleSet] ORDER BY RuleSetId);
DECLARE @TextType uniqueidentifier='80000000-0000-0000-0000-000000000004';
DECLARE @GuidType uniqueidentifier='80000000-0000-0000-0000-000000000005';
DECLARE @At datetime2(7)='2026-01-01T00:00:00';
IF @RuleId IS NULL OR @RuleSetId IS NULL THROW 58930,'V00010 Rule/RuleSet parents are absent.',1;
DECLARE @Cases table (N int NOT NULL PRIMARY KEY, Name varchar(64) NOT NULL);
INSERT INTO @Cases VALUES
 (1,'scalar-to-different-scalar'),(2,'scalar-object-boundary'),(3,'heap-object-type'),
 (4,'same-scalar-nullability'),(5,'same-scalar-precision-scale'),(6,'collection-element-type'),
 (7,'declared-contract-type-rename'),(8,'combined-type-default'),(9,'container-cardinality-shape'),
 (10,'string-length-domain-constraint'),(11,'code-fixture-contract-text');
INSERT INTO [ATAPUtilities].[RuleInputDefinition]
 ([RuleInputDefinitionId],[RuleId],[InputCode],[ValueTypeId],[StorageKindCode],[IsRequired],[AllowsNull],[Ordinal],[InputNormalizationContractId],[SecretPolicyCode])
SELECT CONVERT(uniqueidentifier,'92000000-0000-0000-0000-'+RIGHT('000000000000'+CONVERT(varchar(12),N),12)),
 @RuleId,Name+'.before',@TextType,'Text',1,0,100+N*2,'80000000-0000-0000-0000-000000000101','NotSecret' FROM @Cases;
INSERT INTO [ATAPUtilities].[RuleInputDefinition]
 ([RuleInputDefinitionId],[RuleId],[InputCode],[ValueTypeId],[StorageKindCode],[IsRequired],[AllowsNull],[Ordinal],[InputNormalizationContractId],[SecretPolicyCode])
SELECT CONVERT(uniqueidentifier,'93000000-0000-0000-0000-'+RIGHT('000000000000'+CONVERT(varchar(12),N),12)),
 @RuleId,Name+'.after',@GuidType,'Guid',1,1,101+N*2,'80000000-0000-0000-0000-000000000101','NotSecret' FROM @Cases;
INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub])
SELECT CONVERT(uniqueidentifier,'94000000-0000-0000-0000-'+RIGHT('000000000000'+CONVERT(varchar(12),N),12)),NULL FROM @Cases;
INSERT INTO [ATAPUtilities].[RuleVariant]
 ([RuleVariantId],[PhiloteId],[RuleId],[OwningRuleSetId],[RuleVariantCode])
SELECT CONVERT(uniqueidentifier,'94000000-0000-0000-0000-'+RIGHT('000000000000'+CONVERT(varchar(12),N),12)),
 CONVERT(uniqueidentifier,'94000000-0000-0000-0000-'+RIGHT('000000000000'+CONVERT(varchar(12),N),12)),
 @RuleId,@RuleSetId,Name+'.replacement' FROM @Cases;
IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleInputDefinition] WHERE Ordinal BETWEEN 102 AND 123)<>22
 THROW 58931,'Material definition replacements were not retained as distinct rows.',1;
IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleVariant] WHERE RuleVariantCode LIKE '%.replacement')<>11
 THROW 58932,'Material replacement variants were not allocated.',1;
BEGIN TRY
 UPDATE [ATAPUtilities].[RuleInputDefinition] SET ValueTypeId=@GuidType,StorageKindCode='Guid'
 WHERE RuleInputDefinitionId='92000000-0000-0000-0000-000000000001';
 THROW 58933,'Input material mutation was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58010 THROW; END CATCH;
IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleInputDefinition]
 WHERE RuleInputDefinitionId='92000000-0000-0000-0000-000000000001' AND ValueTypeId=@TextType AND StorageKindCode='Text')
 THROW 58934,'Rejected input mutation changed prior history.',1;
INSERT INTO [ATAPUtilities].[RuleOutputDefinition]
 ([RuleOutputDefinitionId],[RuleId],[OutputCode],[ValueTypeId],[StorageKindCode],[AllowsNull],[Ordinal],[DispositionCode])
VALUES ('95000000-0000-0000-0000-000000000001',@RuleId,N'output.before',@TextType,'Text',0,100,'Return'),
       ('95000000-0000-0000-0000-000000000002',@RuleId,N'output.after',@GuidType,'Guid',1,101,'Return');
BEGIN TRY
 UPDATE [ATAPUtilities].[RuleOutputDefinition] SET ValueTypeId=@GuidType,StorageKindCode='Guid'
 WHERE RuleOutputDefinitionId='95000000-0000-0000-0000-000000000001';
 THROW 58935,'Output material mutation was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58011 THROW; END CATCH;
INSERT INTO [ATAPUtilities].[RuleValueConstraint]
 ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[NumericPrecision],[NumericScale]) VALUES
 ('95100000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000005','PrecisionScale',18,4);
INSERT INTO [ATAPUtilities].[RuleValueConstraint]
 ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[MaximumTextLength]) VALUES
 ('95100000-0000-0000-0000-000000000002','93000000-0000-0000-0000-000000000010','TextLength',200);
INSERT INTO [ATAPUtilities].[RuleValueConstraint]
 ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[ElementValueTypeId]) VALUES
 ('95100000-0000-0000-0000-000000000003','93000000-0000-0000-0000-000000000006','ElementType',@TextType);
INSERT INTO [ATAPUtilities].[RuleValueConstraint]
 ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[MinimumCardinality],[MaximumCardinality],[CollectionShapeCode]) VALUES
 ('95100000-0000-0000-0000-000000000004','93000000-0000-0000-0000-000000000009','CardinalityShape',0,10,N'List');
INSERT INTO [ATAPUtilities].[RuleValueConstraint]
 ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[DeclaredContractTypeCode]) VALUES
 ('95100000-0000-0000-0000-000000000005','93000000-0000-0000-0000-000000000007','DeclaredContract',N'New.Contract');
INSERT INTO [ATAPUtilities].[RuleValueConstraint]
 ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[DomainConstraintCode]) VALUES
 ('95100000-0000-0000-0000-000000000006','93000000-0000-0000-0000-000000000010','DeclaredDomain',N'Text.Max200');
INSERT INTO [ATAPUtilities].[RuleValueConstraint]
 ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[ContractText]) VALUES
 ('95100000-0000-0000-0000-000000000007','93000000-0000-0000-0000-000000000011','ContractText',N'generator-contract-v2');
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleValueConstraint]
  ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[NumericPrecision],[NumericScale])
 VALUES ('95100000-0000-0000-0000-000000000098','93000000-0000-0000-0000-000000000005','PrecisionScale',20,6);
 THROW 58950,'Duplicate owner and constraint kind was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER() NOT IN (2601,2627) THROW; END CATCH;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleValueConstraint]
  ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[MaximumTextLength],[ContractText])
 VALUES ('95100000-0000-0000-0000-000000000099','93000000-0000-0000-0000-000000000008','TextLength',50,N'irrelevant');
 THROW 58951,'Mixed constraint payload was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>547 THROW; END CATCH;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleValueConstraint]
  ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[DomainConstraintCode])
 VALUES ('95100000-0000-0000-0000-000000000097','93000000-0000-0000-0000-000000000008','DeclaredDomain',N'');
 THROW 58952,'Empty semantic constraint payload was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>547 THROW; END CATCH;
INSERT INTO [ATAPUtilities].[RuleVariantInputDefinition]
 ([RuleVariantId],[RuleInputDefinitionId],[RuleId],[InputCode],[Ordinal])
SELECT CONVERT(uniqueidentifier,'94000000-0000-0000-0000-'+RIGHT('000000000000'+CONVERT(varchar(12),N),12)),
 CONVERT(uniqueidentifier,'93000000-0000-0000-0000-'+RIGHT('000000000000'+CONVERT(varchar(12),N),12)),
 @RuleId,Name+'.after',101+N*2 FROM @Cases;
INSERT INTO [ATAPUtilities].[RuleVariantOutputDefinition]
 ([RuleVariantId],[RuleOutputDefinitionId],[RuleId],[OutputCode],[Ordinal])
SELECT CONVERT(uniqueidentifier,'94000000-0000-0000-0000-'+RIGHT('000000000000'+CONVERT(varchar(12),N),12)),
 '95000000-0000-0000-0000-000000000002',@RuleId,N'output.after',101 FROM @Cases;
IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleVariantInputDefinition])<11
 OR (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleVariantOutputDefinition])<11
 THROW 58953,'Replacement variants are not relationally bound to registered definitions.',1;
DECLARE @AlternateRuleKindId uniqueidentifier;
DECLARE @AlternateRulePrimitiveId uniqueidentifier;
SELECT TOP(1) @AlternateRuleKindId=rp.RuleKindId,@AlternateRulePrimitiveId=rp.RulePrimitiveId
FROM [ATAPUtilities].[RulePrimitive] rp
WHERE rp.RuleKindId<>(SELECT RuleKindId FROM [ATAPUtilities].[Rule] WHERE RuleId=@RuleId)
ORDER BY rp.RuleKindId,rp.RulePrimitiveId;
IF @AlternateRuleKindId IS NULL THROW 58960,'An alternate RuleKind fixture is absent.',1;
INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub]) VALUES
 ('91000000-0000-0000-0000-000000000001',NULL),('91000000-0000-0000-0000-000000000004',NULL);
INSERT INTO [ATAPUtilities].[Rule]
 ([RuleId],[PhiloteId],[RuleKindId],[RulePrimitiveId],[RuleCode],[RuleBody]) VALUES
 ('91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001',
  @AlternateRuleKindId,@AlternateRulePrimitiveId,'V4.Acceptance.RuleKindReplacement',N'rule-kind replacement body');
INSERT INTO [ATAPUtilities].[RuleInputDefinition]
 ([RuleInputDefinitionId],[RuleId],[InputCode],[ValueTypeId],[StorageKindCode],[IsRequired],[AllowsNull],[Ordinal],[InputNormalizationContractId],[SecretPolicyCode]) VALUES
 ('91000000-0000-0000-0000-000000000002','91000000-0000-0000-0000-000000000001',N'rule-kind.input',@TextType,'Text',1,0,0,'80000000-0000-0000-0000-000000000101','NotSecret');
INSERT INTO [ATAPUtilities].[RuleOutputDefinition]
 ([RuleOutputDefinitionId],[RuleId],[OutputCode],[ValueTypeId],[StorageKindCode],[AllowsNull],[Ordinal],[DispositionCode]) VALUES
 ('91000000-0000-0000-0000-000000000003','91000000-0000-0000-0000-000000000001',N'rule-kind.output',@TextType,'Text',0,0,'Return');
INSERT INTO [ATAPUtilities].[RuleVariant]
 ([RuleVariantId],[PhiloteId],[RuleId],[OwningRuleSetId],[RuleVariantCode]) VALUES
 ('91000000-0000-0000-0000-000000000004','91000000-0000-0000-0000-000000000004',
  '91000000-0000-0000-0000-000000000001',@RuleSetId,N'rule-kind.replacement');
INSERT INTO [ATAPUtilities].[RuleVariantInputDefinition]
 ([RuleVariantId],[RuleInputDefinitionId],[RuleId],[InputCode],[Ordinal]) VALUES
 ('91000000-0000-0000-0000-000000000004','91000000-0000-0000-0000-000000000002',
  '91000000-0000-0000-0000-000000000001',N'rule-kind.input',0);
INSERT INTO [ATAPUtilities].[RuleVariantOutputDefinition]
 ([RuleVariantId],[RuleOutputDefinitionId],[RuleId],[OutputCode],[Ordinal]) VALUES
 ('91000000-0000-0000-0000-000000000004','91000000-0000-0000-0000-000000000003',
  '91000000-0000-0000-0000-000000000001',N'rule-kind.output',0);
IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleId='91000000-0000-0000-0000-000000000001'
               AND RuleKindId=@AlternateRuleKindId)
 OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Rule] WHERE RuleId=@RuleId)
 THROW 58961,'Rule-kind replacement did not preserve the prior Rule and allocate a new graph.',1;
INSERT INTO [ATAPUtilities].[RuleInputDefinitionState]
 ([RuleInputDefinitionStateId],[RuleInputDefinitionId],[ValidFromUtc],[ValidToUtc],[DisplayName],[Description]) VALUES
 ('96000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001',@At,'2026-02-01',N'Original',N'Original display'),
 ('96000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','2026-02-01',NULL,N'Revised',N'Revised display');
INSERT INTO [ATAPUtilities].[RuleDefaultInputValue]
 ([RuleDefaultInputValueId],[RuleInputDefinitionId],[ValueTypeId],[StorageKindCode],[ValidFromUtc],[ValidToUtc],[TextValue]) VALUES
 ('97000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001',@TextType,'Text',@At,'2026-02-01',N'old'),
 ('97000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001',@TextType,'Text','2026-02-01',NULL,N'new');
IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleInputDefinitionState]
    WHERE RuleInputDefinitionId='92000000-0000-0000-0000-000000000001')<>2
 OR (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleDefaultInputValue]
    WHERE RuleInputDefinitionId='92000000-0000-0000-0000-000000000001')<>2
 THROW 58936,'Non-material history rows were not retained.',1;
BEGIN TRY
 UPDATE [ATAPUtilities].[RuleInputDefinitionState] SET DisplayName=N'overwritten'
 WHERE RuleInputDefinitionStateId='96000000-0000-0000-0000-000000000001';
 THROW 58954,'Closed display history overwrite was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58030 THROW; END CATCH;
BEGIN TRY
 UPDATE [ATAPUtilities].[RuleDefaultInputValue] SET TextValue=N'overwritten'
 WHERE RuleDefaultInputValueId='97000000-0000-0000-0000-000000000001';
 THROW 58955,'Closed default history overwrite was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58032 THROW; END CATCH;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleInputDefinitionState]
  ([RuleInputDefinitionStateId],[RuleInputDefinitionId],[ValidFromUtc],[ValidToUtc],[DisplayName],[Description])
 VALUES ('96000000-0000-0000-0000-000000000099','92000000-0000-0000-0000-000000000001',
         '2026-01-15','2026-01-20',N'Overlap',N'Overlap');
 THROW 58956,'Overlapping display history was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58040 THROW; END CATCH;
BEGIN TRY
 UPDATE [ATAPUtilities].[ValueType] SET ValueTypeCode=ValueTypeCode
 WHERE ValueTypeId=@TextType;
 THROW 58957,'ValueType mutation was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58014 THROW; END CATCH;
BEGIN TRY
 UPDATE [ATAPUtilities].[Rule] SET RuleCode=RuleCode WHERE RuleId=@RuleId;
 THROW 58958,'Rule semantic mutation was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58013 THROW; END CATCH;
BEGIN TRY
 UPDATE [ATAPUtilities].[InputNormalizationContract] SET ContractText=ContractText
 WHERE InputNormalizationContractId='80000000-0000-0000-0000-000000000101';
 THROW 58959,'Normalization contract mutation was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58015 THROW; END CATCH;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleInputDefinition]
  ([RuleInputDefinitionId],[RuleId],[InputCode],[ValueTypeId],[StorageKindCode],[IsRequired],[AllowsNull],[Ordinal],[InputNormalizationContractId],[SecretPolicyCode])
 VALUES ('98000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-000000000099',N'unregistered',@TextType,'Text',1,0,999,'80000000-0000-0000-0000-000000000101','NotSecret');
 THROW 58937,'Unregistered replacement parent was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>547 THROW; END CATCH;
'@

    $overlaySql = @'
DECLARE @RuleId uniqueidentifier=(
 SELECT RuleId FROM [ATAPUtilities].[RuleInputDefinition]
 WHERE RuleInputDefinitionId='92000000-0000-0000-0000-000000000001');
DECLARE @BuildSetId uniqueidentifier=(SELECT TOP(1) BuildSetId FROM [ATAPUtilities].[BuildSet] ORDER BY BuildSetId);
DECLARE @At0 datetime2(7)='2026-01-01T00:00:00';
DECLARE @At1 datetime2(7)='2026-02-01T00:00:00';
DECLARE @At2 datetime2(7)='2026-03-01T00:00:00';
DECLARE @At3 datetime2(7)='2026-04-01T00:00:00';
IF @RuleId IS NULL OR @BuildSetId IS NULL THROW 58940,'V00010 Rule/BuildSet parents are absent.',1;
INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub]) VALUES
 ('a1000000-0000-0000-0000-000000000001',NULL),('a1000000-0000-0000-0000-000000000002',NULL),
 ('a1000000-0000-0000-0000-000000000003',NULL),('a1000000-0000-0000-0000-000000000004',NULL),
 ('a2000000-0000-0000-0000-000000000001',NULL),('a2000000-0000-0000-0000-000000000002',NULL),
 ('a2000000-0000-0000-0000-000000000003',NULL),('a2000000-0000-0000-0000-000000000004',NULL);
INSERT INTO [ATAPUtilities].[RuleSet] ([RuleSetId],[PhiloteId],[RuleSetCode]) VALUES
 ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','V4.Acceptance.Base'),
 ('a1000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000002','V4.Acceptance.Override1500'),
 ('a1000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000003','V4.Acceptance.Override1200'),
 ('a1000000-0000-0000-0000-000000000004','a1000000-0000-0000-0000-000000000004','V4.Acceptance.Suppress');
INSERT INTO [ATAPUtilities].[RuleVariant]
 ([RuleVariantId],[PhiloteId],[RuleId],[OwningRuleSetId],[RuleVariantCode]) VALUES
 ('a2000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001',@RuleId,'a1000000-0000-0000-0000-000000000001',N'budget-1000'),
 ('a2000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000002',@RuleId,'a1000000-0000-0000-0000-000000000002',N'budget-1500'),
 ('a2000000-0000-0000-0000-000000000003','a2000000-0000-0000-0000-000000000003',@RuleId,'a1000000-0000-0000-0000-000000000003',N'budget-1200'),
 ('a2000000-0000-0000-0000-000000000004','a2000000-0000-0000-0000-000000000004',@RuleId,'a1000000-0000-0000-0000-000000000004',N'budget-suppress');
INSERT INTO [ATAPUtilities].[RuleVariantInputDefinition]
 ([RuleVariantId],[RuleInputDefinitionId],[RuleId],[InputCode],[Ordinal]) VALUES
 ('a2000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001',@RuleId,N'scalar-to-different-scalar.before',102),
 ('a2000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001',@RuleId,N'scalar-to-different-scalar.before',102),
 ('a2000000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000001',@RuleId,N'scalar-to-different-scalar.before',102),
 ('a2000000-0000-0000-0000-000000000004','92000000-0000-0000-0000-000000000001',@RuleId,N'scalar-to-different-scalar.before',102);
INSERT INTO [ATAPUtilities].[RuleVariantOutputDefinition]
 ([RuleVariantId],[RuleOutputDefinitionId],[RuleId],[OutputCode],[Ordinal]) VALUES
 ('a2000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000001',@RuleId,N'output.before',100),
 ('a2000000-0000-0000-0000-000000000002','95000000-0000-0000-0000-000000000001',@RuleId,N'output.before',100),
 ('a2000000-0000-0000-0000-000000000003','95000000-0000-0000-0000-000000000001',@RuleId,N'output.before',100),
 ('a2000000-0000-0000-0000-000000000004','95000000-0000-0000-0000-000000000001',@RuleId,N'output.before',100);
INSERT INTO [ATAPUtilities].[RuleVariantState]
 ([RuleVariantStateId],[RuleVariantId],[ValidFromUtc],[Purpose],[ExecutorContractCode],[NormalizedBody],[LifecycleStatusCode]) VALUES
 ('a3000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001',@At0,N'budget',N'deterministic-v1',N'{"value":1000}','Active'),
 ('a3000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000002',@At1,N'budget',N'deterministic-v1',N'{"value":1500}','Active'),
 ('a3000000-0000-0000-0000-000000000003','a2000000-0000-0000-0000-000000000003',@At2,N'budget',N'deterministic-v1',N'{"value":1200}','Active'),
 ('a3000000-0000-0000-0000-000000000004','a2000000-0000-0000-0000-000000000004',@At3,N'budget',N'deterministic-v1',N'{"suppress":true}','Active');
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleVariantInputDefinition]
  ([RuleVariantId],[RuleInputDefinitionId],[RuleId],[InputCode],[Ordinal]) VALUES
  ('a2000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001',@RuleId,N'scalar-to-different-scalar.after',103);
 THROW 58962,'Late input-definition binding was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58038 THROW; END CATCH;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleVariantOutputDefinition]
  ([RuleVariantId],[RuleOutputDefinitionId],[RuleId],[OutputCode],[Ordinal]) VALUES
  ('a2000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000002',@RuleId,N'output.after',101);
 THROW 58963,'Late output-definition binding was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58039 THROW; END CATCH;
BEGIN TRY
 UPDATE [ATAPUtilities].[RuleVariantInputDefinition] SET Ordinal=Ordinal
 WHERE RuleVariantId='a2000000-0000-0000-0000-000000000001';
 THROW 58964,'Input-definition binding mutation was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58034 THROW; END CATCH;
BEGIN TRY
 DELETE FROM [ATAPUtilities].[RuleVariantOutputDefinition]
 WHERE RuleVariantId='a2000000-0000-0000-0000-000000000001';
 THROW 58965,'Output-definition binding deletion was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58035 THROW; END CATCH;
INSERT INTO [ATAPUtilities].[RuleSetRuleOccurrence]
 ([RuleSetRuleOccurrenceId],[RuleSetId],[RuleVariantId],[RuleSetMembershipRoleCode],[Ordinal],[ValidFromUtc]) VALUES
 ('a4000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','Add',0,@At0),
 ('a4000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000002','Override',0,@At1),
 ('a4000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000003','a2000000-0000-0000-0000-000000000003','Override',0,@At2),
 ('a4000000-0000-0000-0000-000000000004','a1000000-0000-0000-0000-000000000004','a2000000-0000-0000-0000-000000000004','Suppress',0,@At3);
INSERT INTO [ATAPUtilities].[BuildSetRuleSetOccurrence]
 ([BuildSetRuleSetOccurrenceId],[BuildSetId],[RuleSetId],[Ordinal],[ValidFromUtc]) VALUES
 ('a5000000-0000-0000-0000-000000000001',@BuildSetId,'a1000000-0000-0000-0000-000000000001',10,@At0),
 ('a5000000-0000-0000-0000-000000000002',@BuildSetId,'a1000000-0000-0000-0000-000000000002',20,@At1),
 ('a5000000-0000-0000-0000-000000000003',@BuildSetId,'a1000000-0000-0000-0000-000000000003',30,@At2),
 ('a5000000-0000-0000-0000-000000000004',@BuildSetId,'a1000000-0000-0000-0000-000000000004',40,@At3);
DECLARE @Resolved table
 (RuleId uniqueidentifier,RuleVariantId uniqueidentifier,RuleVariantStateId uniqueidentifier,
  RuleSetMembershipRoleCode varchar(16),ResolutionDisposition varchar(10),PrecedenceRank bigint,
  BuildSetId uniqueidentifier,BuildSetRuleSetOccurrenceId uniqueidentifier,BuildSetOrdinal int,
  RuleSetId uniqueidentifier,RuleSetRuleOccurrenceId uniqueidentifier,RuleSetOrdinal int);
INSERT INTO @Resolved EXEC [ATAPUtilities].[ResolveBuildSetRulesAsOf] @BuildSetId,'2026-01-15';
IF (SELECT COUNT_BIG(*) FROM @Resolved WHERE ResolutionDisposition='Selected' AND BuildSetOrdinal=10)<>1
 THROW 58941,'Baseline resolution failed.',1;
DELETE FROM @Resolved;
INSERT INTO @Resolved EXEC [ATAPUtilities].[ResolveBuildSetRulesAsOf] @BuildSetId,'2026-02-15';
IF (SELECT COUNT_BIG(*) FROM @Resolved WHERE ResolutionDisposition='Selected' AND BuildSetOrdinal=20)<>1
 OR (SELECT COUNT_BIG(*) FROM @Resolved WHERE ResolutionDisposition='Shadowed' AND BuildSetOrdinal=10)<>1
 THROW 58942,'1500 override or provenance failed.',1;
DELETE FROM @Resolved;
INSERT INTO @Resolved EXEC [ATAPUtilities].[ResolveBuildSetRulesAsOf] @BuildSetId,'2026-03-15';
IF (SELECT COUNT_BIG(*) FROM @Resolved WHERE ResolutionDisposition='Selected' AND BuildSetOrdinal=30)<>1
 OR (SELECT COUNT_BIG(*) FROM @Resolved WHERE ResolutionDisposition='Shadowed')<>2
 THROW 58943,'1200 higher-ordinal override or provenance failed.',1;
DELETE FROM @Resolved;
INSERT INTO @Resolved EXEC [ATAPUtilities].[ResolveBuildSetRulesAsOf] @BuildSetId,'2026-04-15';
IF (SELECT COUNT_BIG(*) FROM @Resolved WHERE ResolutionDisposition='Suppressed' AND BuildSetOrdinal=40)<>1
 OR (SELECT COUNT_BIG(*) FROM @Resolved WHERE ResolutionDisposition='Shadowed')<>3
 THROW 58944,'Suppress resolution or provenance failed.',1;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleSetRuleOccurrence]
  ([RuleSetRuleOccurrenceId],[RuleSetId],[RuleVariantId],[RuleSetMembershipRoleCode],[Ordinal],[ValidFromUtc])
 VALUES ('a4000000-0000-0000-0000-000000000099','a1000000-0000-0000-0000-000000000002',
         'a2000000-0000-0000-0000-000000000001','Override',99,@At0);
 THROW 58945,'Cross-owner occurrence was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>547 THROW; END CATCH;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleSetRuleOccurrence]
  ([RuleSetRuleOccurrenceId],[RuleSetId],[RuleVariantId],[RuleSetMembershipRoleCode],[Ordinal],[ValidFromUtc])
 VALUES ('a4000000-0000-0000-0000-000000000098','a1000000-0000-0000-0000-000000000001',
         'a2000000-0000-0000-0000-000000000001','Add',0,@At0);
 THROW 58946,'Duplicate RuleSet ordinal was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER() NOT IN (2601,2627) THROW; END CATCH;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[BuildSetRuleSetOccurrence]
  ([BuildSetRuleSetOccurrenceId],[BuildSetId],[RuleSetId],[Ordinal],[ValidFromUtc])
 VALUES ('a5000000-0000-0000-0000-000000000099',@BuildSetId,
         'a1000000-0000-0000-0000-000000000004',30,@At3);
 THROW 58947,'Duplicate BuildSet ordinal was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER() NOT IN (2601,2627) THROW; END CATCH;
INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub])
 VALUES ('b1000000-0000-0000-0000-000000000001',NULL);
INSERT INTO [ATAPUtilities].[BuildSet] ([BuildSetId],[PhiloteId],[BuildSetCode])
 VALUES ('b1000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','V4.Acceptance.NoBaseline');
INSERT INTO [ATAPUtilities].[BuildSetRuleSetOccurrence]
 ([BuildSetRuleSetOccurrenceId],[BuildSetId],[RuleSetId],[Ordinal],[ValidFromUtc]) VALUES
 ('b5000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000002',10,@At1);
BEGIN TRY
 EXEC [ATAPUtilities].[ResolveBuildSetRulesAsOf] 'b1000000-0000-0000-0000-000000000001','2026-03-15';
 THROW 58966,'Override without a baseline was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58022 THROW; END CATCH;
INSERT INTO [ATAPUtilities].[RuleSetRuleOccurrence]
 ([RuleSetRuleOccurrenceId],[RuleSetId],[RuleVariantId],[RuleSetMembershipRoleCode],[Ordinal],[ValidFromUtc]) VALUES
 ('a4000000-0000-0000-0000-000000000097','a1000000-0000-0000-0000-000000000003',
  'a2000000-0000-0000-0000-000000000003','Add',1,@At2);
BEGIN TRY
 EXEC [ATAPUtilities].[ResolveBuildSetRulesAsOf] @BuildSetId,'2026-03-15';
 THROW 58948,'Add collision was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58023 THROW; END CATCH;
BEGIN TRY
 UPDATE [ATAPUtilities].[RuleSetRuleOccurrence] SET RuleSetMembershipRoleCode=RuleSetMembershipRoleCode
 WHERE RuleSetRuleOccurrenceId='a4000000-0000-0000-0000-000000000001';
 THROW 58967,'RuleSet occurrence mutation was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58036 THROW; END CATCH;
BEGIN TRY
 DELETE FROM [ATAPUtilities].[RuleSetRuleOccurrence]
 WHERE RuleSetRuleOccurrenceId='a4000000-0000-0000-0000-000000000001';
 THROW 58968,'RuleSet occurrence deletion was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58036 THROW; END CATCH;
BEGIN TRY
 UPDATE [ATAPUtilities].[BuildSetRuleSetOccurrence] SET Ordinal=Ordinal
 WHERE BuildSetRuleSetOccurrenceId='a5000000-0000-0000-0000-000000000001';
 THROW 58969,'BuildSet occurrence mutation was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58037 THROW; END CATCH;
BEGIN TRY
 DELETE FROM [ATAPUtilities].[BuildSetRuleSetOccurrence]
 WHERE BuildSetRuleSetOccurrenceId='a5000000-0000-0000-0000-000000000001';
 THROW 58970,'BuildSet occurrence deletion was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58037 THROW; END CATCH;
UPDATE [ATAPUtilities].[RuleVariantState] SET ValidToUtc=@At2
 WHERE RuleVariantStateId='a3000000-0000-0000-0000-000000000001';
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleVariantState]
  ([RuleVariantStateId],[RuleVariantId],[ValidFromUtc],[ValidToUtc],[Purpose],[ExecutorContractCode],[NormalizedBody],[LifecycleStatusCode]) VALUES
  ('a3000000-0000-0000-0000-000000000099','a2000000-0000-0000-0000-000000000001',
   @At1,@At3,N'overlap',N'deterministic-v1',N'{"value":999}','Active');
 THROW 58971,'Overlapping RuleVariant state was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58043 THROW; END CATCH;
BEGIN TRY
 UPDATE [ATAPUtilities].[RuleVariant] SET RuleVariantCode=N'mutated'
 WHERE RuleVariantId='a2000000-0000-0000-0000-000000000001';
 THROW 58949,'RuleVariant mutation was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58012 THROW; END CATCH;
'@

    $predecessorSnapshotSql = @'
SELECT
 (SELECT s.name AS [schema],o.name,o.type,CONVERT(varchar(64),HASHBYTES('SHA2_256',COALESCE(OBJECT_DEFINITION(o.object_id),N'')),2) AS definitionHash
  FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
  WHERE s.name IN ('ATAPUtilities','Ace') AND o.is_ms_shipped=0
    AND o.name NOT IN ('ValueType','InputNormalizationContract','RuleInputDefinition','RuleInputDefinitionState',
      'RuleDefaultInputValue','RuleOutputDefinition','RuleOutputDefinitionState','RuleValueConstraint',
      'RuleVariant','RuleVariantState','RuleVariantInputDefinition','RuleVariantOutputDefinition',
      'RuleSetMembershipRole','RuleSetRuleOccurrence','BuildSetRuleSetOccurrence',
      'TR_Rule_SemanticIdentity_Immutable','TR_ValueType_Immutable','TR_InputNormalizationContract_Immutable',
      'TR_RuleInputDefinition_Immutable','TR_RuleOutputDefinition_Immutable','TR_RuleVariant_Immutable',
      'TR_RuleValueConstraint_Frozen','TR_RuleVariantInputDefinition_Immutable',
      'TR_RuleVariantOutputDefinition_Immutable','TR_RuleInputDefinitionState_History',
      'TR_RuleOutputDefinitionState_History','TR_RuleDefaultInputValue_History','TR_RuleVariantState_History',
      'TR_RuleSetRuleOccurrence_History','TR_BuildSetRuleSetOccurrence_History','ResolveBuildSetRulesAsOf')
    AND NOT EXISTS
    (
      SELECT 1
      FROM sys.tables v4t
      JOIN sys.schemas v4s ON v4s.schema_id=v4t.schema_id
      WHERE v4s.name='ATAPUtilities'
        AND v4t.name IN ('ValueType','InputNormalizationContract','RuleInputDefinition','RuleInputDefinitionState',
          'RuleDefaultInputValue','RuleOutputDefinition','RuleOutputDefinitionState','RuleValueConstraint',
          'RuleVariant','RuleVariantState','RuleVariantInputDefinition','RuleVariantOutputDefinition',
          'RuleSetMembershipRole','RuleSetRuleOccurrence','BuildSetRuleSetOccurrence')
        AND (o.object_id=v4t.object_id OR o.parent_object_id=v4t.object_id)
    )
  ORDER BY s.name,o.name,o.type FOR JSON PATH,INCLUDE_NULL_VALUES)
 +N'|'+
 (SELECT s.name AS [schema],t.name AS [table],SUM(p.rows) AS [rows]
  FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
  JOIN sys.partitions p ON p.object_id=t.object_id AND p.index_id IN (0,1)
  WHERE s.name IN ('ATAPUtilities','Ace')
    AND t.name NOT IN ('ValueType','InputNormalizationContract','RuleInputDefinition','RuleInputDefinitionState',
      'RuleDefaultInputValue','RuleOutputDefinition','RuleOutputDefinitionState','RuleValueConstraint',
      'RuleVariant','RuleVariantState','RuleVariantInputDefinition','RuleVariantOutputDefinition',
      'RuleSetMembershipRole','RuleSetRuleOccurrence','BuildSetRuleSetOccurrence')
  GROUP BY s.name,t.name ORDER BY s.name,t.name FOR JSON PATH,INCLUDE_NULL_VALUES);
'@
}

Describe 'V00080 database acceptance fixture offline contract' {
    It 'loads a deterministic fixture bound to the frozen migration lineage' {
        $fixture.schemaVersion | Should -Be '1.0'
        $fixture.target.migration | Should -Be 'V00080__Create_ATAPUtilities_V4_Core_Identity_And_Overlay.sql'
        $fixture.target.version | Should -Be '80'
        $fixture.target.status | Should -Be 'frozen-offline-candidate'
        $fixture.target.sha256 | Should -Be 'F7BDAA9688D081DCD61E57466AFAD8AEDB1C256F0223BE6C9C8B5C2FE2B01763'
        @($fixture.predecessors).Count | Should -Be 6
        @($migrationHashes.Keys).Count | Should -Be 7
        { Assert-V4MigrationBytes -Directory $sqlDirectory } | Should -Not -Throw
    }

    It 'defines the exact frozen objects roles errors and resolver result columns' {
        @($fixture.surface.tables).Count | Should -Be 15
        @($fixture.surface.triggers).Count | Should -Be 15
        $fixture.surface.procedure | Should -Be 'ResolveBuildSetRulesAsOf'
        @($fixture.surface.procedureParameters) | Should -Be @('BuildSetId', 'AsOfUtc')
        @($fixture.surface.resultColumns).Count | Should -Be 12
        @($fixture.surface.roles) | Should -Be @('Add', 'Override', 'Suppress')
        @($fixture.surface.constraintIndexes) | Should -Be @(
            'UX_RuleValueConstraint_Input_Kind', 'UX_RuleValueConstraint_Output_Kind')
        @($fixture.surface.expectedErrors).Count | Should -Be 28
    }

    It 'binds the fixture to the actual 15-table 15-trigger V00080 surface' {
        $actualTables = @([regex]::Matches(
                $targetMigrationText,
                '(?im)^\s*CREATE TABLE \[ATAPUtilities\]\.\[(?<name>[^]]+)\]') |
            ForEach-Object { $_.Groups['name'].Value })
        $actualTriggers = @([regex]::Matches(
                $targetMigrationText,
                'CREATE TRIGGER \[ATAPUtilities\]\.\[(?<name>[^]]+)\]') |
            ForEach-Object { $_.Groups['name'].Value })
        $actualTables | Should -Be @($fixture.surface.tables)
        $actualTriggers | Should -Be @($fixture.surface.triggers)
        foreach ($errorNumber in $fixture.surface.expectedErrors) {
            $targetMigrationText | Should -Match "THROW $errorNumber\b"
        }
    }

    It 'enforces relational same-Rule variant-definition selection and freezes late binding' {
        $targetMigrationText | Should -Match 'FK_RuleVariantInputDefinition_VariantRule[\s\S]*?FOREIGN KEY \(\[RuleVariantId\], \[RuleId\]\)[\s\S]*?REFERENCES \[ATAPUtilities\]\.\[RuleVariant\] \(\[RuleVariantId\], \[RuleId\]\)'
        $targetMigrationText | Should -Match 'FK_RuleVariantInputDefinition_RegisteredDefinition[\s\S]*?FOREIGN KEY \(\[RuleInputDefinitionId\], \[RuleId\], \[InputCode\], \[Ordinal\]\)'
        $targetMigrationText | Should -Match 'FK_RuleVariantOutputDefinition_VariantRule[\s\S]*?FOREIGN KEY \(\[RuleVariantId\], \[RuleId\]\)[\s\S]*?REFERENCES \[ATAPUtilities\]\.\[RuleVariant\] \(\[RuleVariantId\], \[RuleId\]\)'
        $targetMigrationText | Should -Match 'FK_RuleVariantOutputDefinition_RegisteredDefinition[\s\S]*?FOREIGN KEY \(\[RuleOutputDefinitionId\], \[RuleId\], \[OutputCode\], \[Ordinal\]\)'
        $targetMigrationText | Should -Match 'TR_RuleVariantInputDefinition_Immutable[\s\S]*?AFTER INSERT, UPDATE, DELETE[\s\S]*?THROW 58038'
        $targetMigrationText | Should -Match 'TR_RuleVariantOutputDefinition_Immutable[\s\S]*?AFTER INSERT, UPDATE, DELETE[\s\S]*?THROW 58039'
    }

    It 'enforces immutable semantic catalogs definitions states defaults variants and occurrences' {
        foreach ($errorNumber in 58010, 58011, 58012, 58013, 58014, 58015, 58016, 58030, 58031, 58032, 58033, 58034, 58035, 58036, 58037) {
            $targetMigrationText | Should -Match "THROW $errorNumber\b"
        }
        $targetMigrationText | Should -Match 'TR_RuleSetRuleOccurrence_History[\s\S]*?AFTER UPDATE, DELETE[\s\S]*?only an open period may be closed'
        $targetMigrationText | Should -Match 'TR_BuildSetRuleSetOccurrence_History[\s\S]*?AFTER UPDATE, DELETE[\s\S]*?only an open period may be closed'
        $targetMigrationText | Should -Match 'RuleOutputDefinitionId[\s\S]*?\[AllowsNull\] bit NOT NULL'
    }

    It 'enforces constraint owner-kind uniqueness exact payload discrimination and non-empty semantic text' {
        foreach ($indexName in $fixture.surface.constraintIndexes) {
            $targetMigrationText | Should -Match ([regex]::Escape($indexName))
        }
        foreach ($columnName in 'CollectionShapeCode', 'DeclaredContractTypeCode', 'DomainConstraintCode', 'ContractText') {
            $targetMigrationText | Should -Match "DATALENGTH\(\[$columnName\]\) > 0"
        }
        foreach ($irrelevantColumn in 'NumericPrecision', 'MaximumTextLength', 'ElementValueTypeId', 'MinimumCardinality', 'DeclaredContractTypeCode', 'DomainConstraintCode', 'ContractText') {
            $targetMigrationText | Should -Match "\[$irrelevantColumn\] IS NULL"
        }
    }

    It 'rejects half-open overlap for every state and default history owner' {
        foreach ($errorNumber in 58040, 58041, 58042, 58043) {
            $targetMigrationText | Should -Match "THROW $errorNumber\b"
        }
        foreach ($triggerName in
            'TR_RuleInputDefinitionState_History',
            'TR_RuleOutputDefinitionState_History',
            'TR_RuleDefaultInputValue_History',
            'TR_RuleVariantState_History') {
            $targetMigrationText | Should -Match "$triggerName[\s\S]*?AFTER INSERT, UPDATE, DELETE[\s\S]*?ValidFromUtc[\s\S]*?ValidToUtc"
        }
    }

    It 'covers every ratified D-3 material class and both non-material controls' {
        @($fixture.identityScenarios).Count | Should -Be 14
        @($fixture.identityScenarios | Where-Object classification -EQ 'material').Count | Should -Be 12
        @($fixture.identityScenarios | Where-Object classification -EQ 'non-material-control').Count | Should -Be 2
        foreach ($scenario in $fixture.identityScenarios | Where-Object classification -EQ 'material') {
            $scenario.newVariant | Should -BeTrue
            $scenario.newDefinition | Should -BeTrue
        }
        @($fixture.identityScenarios | Where-Object classification -EQ 'non-material-control').history |
            Should -Be @('RuleDefaultInputValue', 'DefinitionState')
    }

    It 'separates canonical boundary spelling from native GUID equality' {
        foreach ($value in $fixture.guidCases.canonicalBoundary) {
            ($value -cmatch $canonicalGuidPattern) | Should -BeTrue
            ([guid] $value).ToString('D') | Should -BeExactly $value
        }
        foreach ($value in $fixture.guidCases.rejectedBoundary) {
            { [guid]::Parse($value.Trim()) } | Should -Not -Throw
            ($value -cnotmatch $canonicalGuidPattern) | Should -BeTrue
        }
        foreach ($comparison in $fixture.guidCases.nativeComparisons) {
            (([guid] $comparison.left) -eq ([guid] $comparison.right)) | Should -Be $comparison.equal
        }
    }

    It 'enumerates complete overlay ordering provenance and negative coverage' {
        @($fixture.overlay.valuesByOrdinal.ordinal) | Should -Be @(10, 20, 30, 40)
        @($fixture.overlay.valuesByOrdinal.role) | Should -Be @('Add', 'Override', 'Override', 'Suppress')
        @($fixture.overlay.expectedDispositions) | Should -Be @('Selected', 'Shadowed', 'Suppressed')
        @($fixture.overlay.negativeCases).Count | Should -Be 13
        @($fixture.executionPaths) | Should -Be @(
            'fresh-through-v00080', 'v00070-upgrade', 'repeat-migrate-validate')
    }

    It 'fails closed for wrong markers instances names and unowned databases' {
        $safeName = 'ATAPUtilities_Task15140cV4_00000000000000000000000000000000'
        { Assert-V4DisposableTarget -Marker $fixture.safety.authorizationMarker -Instance '.\ExpWhertzing' -Name $safeName } |
            Should -Not -Throw
        foreach ($badMarker in @('', 'true', 'AUTHORIZE_TASK_15_140_C_T2_DISPOSABLE')) {
            { Assert-V4DisposableTarget -Marker $badMarker -Instance '.\ExpWhertzing' -Name $safeName } |
                Should -Throw '*authorization marker required*'
        }
        foreach ($badInstance in @('remote\ExpWhertzing', '.\Production', 'localhost', '.\ExpWhertzing;other')) {
            { Assert-V4DisposableTarget -Marker $fixture.safety.authorizationMarker -Instance $badInstance -Name $safeName } |
                Should -Throw '*local ExpWhertzing*'
        }
        foreach ($badName in @('ATAPUtilities', 'ATAPUtilities_Task15140cV4_existing', "$safeName];DROP DATABASE other")) {
            { Assert-V4DisposableTarget -Marker $fixture.safety.authorizationMarker -Instance '.\ExpWhertzing' -Name $badName } |
                Should -Throw '*Unsafe*'
        }
        $savedAuthorization = $authorization
        $savedInstance = $localInstance
        try {
            $authorization = $fixture.safety.authorizationMarker
            $localInstance = '.\ExpWhertzing'
            { Invoke-V4Sql -DatabaseName $safeName -Query 'SELECT 1;' } | Should -Throw '*unowned*'
        }
        finally {
            $authorization = $savedAuthorization
            $localInstance = $savedInstance
        }
    }

    It 'parses every database fixture batch as SQL Server 2022 T-SQL' {
        $scriptDomPath = 'C:\Program Files\PowerShell\Modules\SqlServer\22.3.0\coreclr\Microsoft.SqlServer.TransactSql.ScriptDom.dll'
        if (-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])) {
            Add-Type -LiteralPath $scriptDomPath
        }
        $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
        $dynamicMigrationBodies = @([regex]::Matches(
                $targetMigrationText,
                "(?s)EXEC\s+sys\.sp_executesql\s+N'(?<body>(?:''|[^'])*)';") |
            ForEach-Object { $_.Groups['body'].Value.Replace("''", "'") })
        foreach ($sql in @($targetMigrationText) + $dynamicMigrationBodies +
            @($surfaceAndGuidSql, $identitySql, $overlaySql, $predecessorSnapshotSql)) {
            $reader = [IO.StringReader]::new($sql)
            $errors = [Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
            try { $null = $parser.Parse($reader, [ref] $errors) }
            finally { $reader.Dispose() }
            @($errors | ForEach-Object { "Line $($_.Line), column $($_.Column): $($_.Message)" }) |
                Should -BeNullOrEmpty
        }
    }
}

Describe 'V00080 guarded disposable database acceptance' {
    $requested = -not [string]::IsNullOrEmpty(
        [Environment]::GetEnvironmentVariable('ATAP_TASK15140C_V4_DISPOSABLE_AUTHORIZATION', 'Process'))

    It 'migrates a fresh database through V00080 and executes identity overlay and negative fixtures' -Skip:(-not $requested) {
        $fixture.target.sha256 | Should -BeExactly 'F7BDAA9688D081DCD61E57466AFAD8AEDB1C256F0223BE6C9C8B5C2FE2B01763'
        $databaseName = New-V4DisposableDatabase
        $migrationDirectory = New-V4StagedMigrationDirectory -DatabaseName $databaseName
        try {
            Invoke-V4Flyway -DatabaseName $databaseName -MigrationDirectory $migrationDirectory -Target 80 -Command migrate
            Invoke-V4Flyway -DatabaseName $databaseName -MigrationDirectory $migrationDirectory -Target 80 -Command validate
            $null = Invoke-V4Sql -DatabaseName $databaseName -Query $surfaceAndGuidSql
            $null = Invoke-V4Sql -DatabaseName $databaseName -Query $identitySql
            $null = Invoke-V4Sql -DatabaseName $databaseName -Query $overlaySql
            Invoke-V4Flyway -DatabaseName $databaseName -MigrationDirectory $migrationDirectory -Target 80 -Command migrate
            Invoke-V4Flyway -DatabaseName $databaseName -MigrationDirectory $migrationDirectory -Target 80 -Command validate
        }
        finally {
            if ($createdDatabases.Contains($databaseName)) {
                Remove-V4DisposableDatabase -Name $databaseName
            }
        }
    }

    It 'upgrades V00070 to V00080 without changing predecessor objects or rows' -Skip:(-not $requested) {
        $fixture.target.sha256 | Should -BeExactly 'F7BDAA9688D081DCD61E57466AFAD8AEDB1C256F0223BE6C9C8B5C2FE2B01763'
        $databaseName = New-V4DisposableDatabase
        $migrationDirectory = New-V4StagedMigrationDirectory -DatabaseName $databaseName
        try {
            Invoke-V4Flyway -DatabaseName $databaseName -MigrationDirectory $migrationDirectory -Target 70 -Command migrate
            $before = Invoke-V4Sql -DatabaseName $databaseName -Query $predecessorSnapshotSql
            Invoke-V4Flyway -DatabaseName $databaseName -MigrationDirectory $migrationDirectory -Target 80 -Command migrate
            Invoke-V4Flyway -DatabaseName $databaseName -MigrationDirectory $migrationDirectory -Target 80 -Command validate
            $after = Invoke-V4Sql -DatabaseName $databaseName -Query $predecessorSnapshotSql
            $after | Should -BeExactly $before
            $null = Invoke-V4Sql -DatabaseName $databaseName -Query $surfaceAndGuidSql
            $null = Invoke-V4Sql -DatabaseName $databaseName -Query $identitySql
            $null = Invoke-V4Sql -DatabaseName $databaseName -Query $overlaySql
        }
        finally {
            if ($createdDatabases.Contains($databaseName)) {
                Remove-V4DisposableDatabase -Name $databaseName
            }
        }
    }
}

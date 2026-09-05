#Requires -Version 7.0
#Requires -Module Pester

Set-StrictMode -Version Latest

Describe 'V00080 RPRRSBSI V4 core identity and overlay static contract' {
  BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $flywayRoot = Join-Path $repoRoot 'Database\Flyway'
    $sqlDirectory = Join-Path $flywayRoot 'SQL'
    $migrationName = 'V00080__Create_ATAPUtilities_V4_Core_Identity_And_Overlay.sql'
    $migrationPath = Join-Path $sqlDirectory $migrationName
    $migration = Get-Content -LiteralPath $migrationPath -Raw
    $activeMigrations = @(Get-ChildItem -LiteralPath $sqlDirectory -File -Filter 'V*.sql' | Sort-Object Name)
    $dynamicBodies = @([regex]::Matches(
        $migration,
        "(?s)EXEC\s+sys\.sp_executesql\s+N'(?<body>(?:''|[^'])*)';") |
      ForEach-Object { $_.Groups['body'].Value.Replace("''", "'") })

    $scriptDomPath = 'C:\Program Files\PowerShell\Modules\SqlServer\22.3.0\coreclr\Microsoft.SqlServer.TransactSql.ScriptDom.dll'
    if (-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])) {
      Add-Type -LiteralPath $scriptDomPath
    }
  }

  It 'allocates the unique next active version after V00070' {
    @($activeMigrations.Name) | Should -Be @(
      'V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql'
      'V00030__Create_AceOutpostContentSummaryPrototype.sql'
      'V00040__Add_PhiloteValidityPeriod_SameIdentity_Key.sql'
      'V00050__Create_ATAPUtilities_Tag_Root.sql'
      'V00060__Create_Ace_GatherContent_Submission.sql'
      'V00070__Create_Ace_AISupervisor_Telemetry.sql'
      $migrationName
      'V00090__Create_ATAPUtilities_Tag_Relations_Assignments_And_Rules.sql'
    )
    @($activeMigrations.Name | ForEach-Object {
        if ($_ -notmatch '^(V\d+)__') { throw "Invalid migration name: $_" }
        $matches[1]
      } | Group-Object | Where-Object Count -gt 1).Count | Should -Be 0
  }

  It 'parses the migration and every dynamic routine or trigger batch as SQL Server 2022 T-SQL' {
    $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
    foreach ($batch in @($migration) + $dynamicBodies) {
      $reader = [IO.StringReader]::new($batch)
      $errors = [Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
      try { $null = $parser.Parse($reader, [ref]$errors) }
      finally { $reader.Dispose() }
      @($errors | ForEach-Object { "Line $($_.Line), column $($_.Column): $($_.Message)" }) |
        Should -BeNullOrEmpty
    }
  }

  It 'creates the exact bounded core table set and one resolver' {
    $tables = @([regex]::Matches($migration, '(?im)^\s*CREATE TABLE \[ATAPUtilities\]\.\[(?<name>[^]]+)\]') |
      ForEach-Object { $_.Groups['name'].Value })
    $tables | Should -Be @(
      'ValueType'
      'InputNormalizationContract'
      'RuleInputDefinition'
      'RuleInputDefinitionState'
      'RuleDefaultInputValue'
      'RuleOutputDefinition'
      'RuleOutputDefinitionState'
      'RuleValueConstraint'
      'RuleVariant'
      'RuleVariantState'
      'RuleVariantInputDefinition'
      'RuleVariantOutputDefinition'
      'RuleSetMembershipRole'
      'RuleSetRuleOccurrence'
      'BuildSetRuleSetOccurrence'
    )
    $migration | Should -Match 'CREATE PROCEDURE \[ATAPUtilities\]\.\[ResolveBuildSetRulesAsOf\]'
    $migration | Should -Not -Match '(?im)^\s*(?:ALTER|DROP)\s+(?:TABLE|PROCEDURE|FUNCTION|VIEW)\b'
  }

  It 'enforces typed immutable identities and temporal display/default state' {
    foreach ($pattern in @(
        'FK_RuleDefaultInputValue_DefinitionType',
        'CK_RuleDefaultInputValue_ExactlyOne',
        'CK_RuleDefaultInputValue_Discriminant',
        'UX_RuleDefaultInputValue_Current',
        'UX_RuleInputDefinitionState_Current',
        'UX_RuleOutputDefinitionState_Current',
        'TR_ValueType_Immutable',
        'TR_InputNormalizationContract_Immutable',
        'TR_RuleInputDefinition_Immutable',
        'TR_RuleOutputDefinition_Immutable',
        'TR_RuleValueConstraint_Frozen',
        'UX_RuleValueConstraint_Input_Kind',
        'UX_RuleValueConstraint_Output_Kind',
        'CK_RuleValueConstraint_RequiredPayload',
        'TR_RuleInputDefinitionState_History',
        'TR_RuleOutputDefinitionState_History',
        'TR_RuleDefaultInputValue_History',
        'Input definition state periods may not overlap',
        'Output definition state periods may not overlap',
        'Default value periods may not overlap',
        'RuleVariant state periods may not overlap',
        'TR_RuleSetRuleOccurrence_History',
        'TR_BuildSetRuleSetOccurrence_History',
        'create a new definition'
      )) { $migration | Should -Match $pattern }
    $migration | Should -Match "SecretReferenceOnly"
    $migration | Should -Not -Match '(?i)\b(?:ApiKey|Password|ConnectionString)Value\b'
  }

  It 'represents all twelve material change classes and both retained-history controls' {
    $materialClassPatterns = [ordered]@{
      'rule-kind' = 'TR_Rule_SemanticIdentity_Immutable'
      'different-scalar' = 'TR_RuleInputDefinition_Immutable'
      'scalar-object-boundary' = 'StorageKindCode'
      'object-or-collection-type' = 'ElementValueTypeId'
      'nullability' = 'AllowsNull'
      'precision-scale' = 'NumericPrecision'
      'collection-element' = 'ElementValueTypeId'
      'container-cardinality-shape' = 'CollectionShapeCode'
      'declared-contract-rename' = 'DeclaredContractTypeCode'
      'simultaneous-type-default' = 'FK_RuleDefaultInputValue_DefinitionType'
      'length-or-domain' = 'DomainConstraintCode'
      'contract-consumed-text' = 'ContractText'
    }
    $materialClassPatterns.Count | Should -Be 12
    foreach ($pattern in $materialClassPatterns.Values) { $migration | Should -Match $pattern }
    $migration | Should -Match 'Default value history is append-only'
    $migration | Should -Match 'definition state history is append-only'
    foreach ($column in @('CollectionShapeCode','DeclaredContractTypeCode','DomainConstraintCode','ContractText')) {
      $migration | Should -Match "DATALENGTH\(\[$column\]\) > 0"
    }
  }

  It 'registers exact variant definition sets with same-Rule integrity' {
    foreach ($pattern in @(
        'RuleVariantInputDefinition', 'RuleVariantOutputDefinition',
        'FK_RuleVariantInputDefinition_VariantRule', 'FK_RuleVariantInputDefinition_RegisteredDefinition',
        'FK_RuleVariantOutputDefinition_VariantRule', 'FK_RuleVariantOutputDefinition_RegisteredDefinition',
        'UQ_RuleVariantInputDefinition_Code', 'UQ_RuleVariantInputDefinition_Ordinal',
        'UQ_RuleVariantOutputDefinition_Code', 'UQ_RuleVariantOutputDefinition_Ordinal',
        'Constraints cannot be added after a definition is bound'
      )) { $migration | Should -Match $pattern }
    $migration | Should -Not -Match 'UQ_RuleInputDefinition_Code\] UNIQUE \(\[RuleId\]'
    $migration | Should -Not -Match 'UQ_RuleOutputDefinition_Code\] UNIQUE \(\[RuleId\]'
  }

  It 'binds variants to their owning RuleSet and controls all membership roles' {
    $migration | Should -Match 'UQ_RuleVariant_Id_Owner'
    $migration | Should -Match 'FK_RuleSetRuleOccurrence_OwnedVariant'
    $migration | Should -Match 'REFERENCES \[ATAPUtilities\]\.\[RuleVariant\] \(\[RuleVariantId\], \[OwningRuleSetId\]\)'
    $migration | Should -Match "VALUES \('Add'\), \('Override'\), \('Suppress'\)"
    $migration | Should -Match 'UQ_RuleSetRuleOccurrence_Ordinal'
    $migration | Should -Match 'UQ_BuildSetRuleSetOccurrence_Ordinal'
  }

  It 'resolves higher BuildSet ordinals first with validation and explicit provenance' {
    $migration | Should -Match 'ORDER BY bo\.\[Ordinal\] DESC, ro\.\[Ordinal\] ASC'
    $migration | Should -Match "Override and Suppress require a lower-precedence baseline with the same RuleId"
    $migration | Should -Match "Add collides with a lower-precedence candidate for the same RuleId"
    foreach ($column in @('ResolutionDisposition','PrecedenceRank','BuildSetRuleSetOccurrenceId','RuleSetRuleOccurrenceId','RuleVariantStateId')) {
      $migration | Should -Match "\[$column\]"
    }
    $migration | Should -Match "'Suppressed'"
    $migration | Should -Match "'Selected'"
    $migration | Should -Match "'Shadowed'"
  }

  It 'binds the exact active package content to version 0.1.8' {
    $version = Get-Content -LiteralPath (Join-Path $flywayRoot 'version.json') -Raw | ConvertFrom-Json
    $allowlist = Get-Content -LiteralPath (Join-Path $flywayRoot 'package-content-allowlist.json') -Raw | ConvertFrom-Json
    $expectedPaths = @(
      @($activeMigrations | ForEach-Object { 'SQL/' + $_.Name })
      @(Get-ChildItem -LiteralPath (Join-Path $flywayRoot 'Data') -File -Filter '*.csv' |
        Sort-Object Name | ForEach-Object { 'Data/' + $_.Name })
    )
    $version.version | Should -Be '0.1.8'
    $allowlist.sourceVersion | Should -Be $version.version
    @($allowlist.files.path) | Should -Be $expectedPaths
    foreach ($entry in $allowlist.files) {
      $literalPath = Join-Path $flywayRoot ($entry.path -replace '/', [IO.Path]::DirectorySeparatorChar)
      Test-Path -LiteralPath $literalPath -PathType Leaf | Should -BeTrue -Because $entry.path
      (Get-FileHash -LiteralPath $literalPath -Algorithm SHA256).Hash | Should -Be $entry.sha256 -Because $entry.path
    }
  }
}

Describe 'V00080 disposable database execution contract' {
  $discoveryInstance = [Environment]::GetEnvironmentVariable('ATAP_FLYWAY_DISPOSABLE_SQL_INSTANCE', 'Process')
  $isAuthorizedLocalInstance = $discoveryInstance -and
    (($discoveryInstance -match "(?i)^(?:\\.|localhost|127\.0\.0\.1|$([regex]::Escape($env:COMPUTERNAME)))(?:\\[^;]+)?$") -or
      ($discoveryInstance -eq "$env:COMPUTERNAME\EXPWHERTZING"))
  $canRun = $isAuthorizedLocalInstance -and
    (Get-Command flyway -ErrorAction SilentlyContinue) -and
    (Get-Command sqlcmd -ErrorAction SilentlyContinue)

  BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
    $flywayConfig = Join-Path $repoRoot 'Database\Flyway\flyway.toml'
    $localInstance = [Environment]::GetEnvironmentVariable('ATAP_FLYWAY_DISPOSABLE_SQL_INSTANCE', 'Process')

    function New-Task15140cV80DisposableDatabase {
      $name = 'ATAPUtilities_Task15140cV80_' + [guid]::NewGuid().ToString('N')
      if ($name -notmatch '^ATAPUtilities_Task15140cV80_[0-9a-f]{32}$') { throw 'Unsafe disposable database name.' }
      & sqlcmd -S $localInstance -E -d master -b -Q "CREATE DATABASE [$name];"
      if ($LASTEXITCODE -ne 0) { throw "Failed to create disposable database $name." }
      $name
    }

    function Remove-Task15140cV80DisposableDatabase {
      param([Parameter(Mandatory)][string] $Name)
      if ($Name -notmatch '^ATAPUtilities_Task15140cV80_[0-9a-f]{32}$') {
        throw 'Refusing to remove a database outside the Task 15.140.c V80 disposable prefix.'
      }
      & sqlcmd -S $localInstance -E -d master -b -Q "ALTER DATABASE [$Name] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$Name];"
      if ($LASTEXITCODE -ne 0) { throw "Failed to remove disposable database $Name." }
    }

    function Invoke-Task15140cV80Flyway {
      param(
        [Parameter(Mandatory)][string] $DatabaseName,
        [Parameter(Mandatory)][ValidateSet('migrate','validate')][string] $Command,
        [Parameter(Mandatory)][ValidateSet('10','70','80')][string] $Target
      )
      $jdbcUrl = "jdbc:sqlserver://$localInstance;databaseName=$DatabaseName;integratedSecurity=true;encrypt=true;trustServerCertificate=true"
      $output = & flyway "-configFiles=$flywayConfig" "-locations=filesystem:$sqlDirectory" "-url=$jdbcUrl" "-target=$Target" $Command 2>&1
      if ($LASTEXITCODE -ne 0) { throw "Flyway $Command to V000$Target failed: $($output -join [Environment]::NewLine)" }
    }

    $functionalFixture = @'
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
DECLARE @At datetime2(7)='2026-09-04T12:00:00';
DECLARE @Rule uniqueidentifier=(SELECT TOP (1) [RuleId] FROM [ATAPUtilities].[Rule] ORDER BY [RuleId]);
DECLARE @BaseSet uniqueidentifier='88800000-0000-0000-0000-000000000101';
DECLARE @OverlaySet uniqueidentifier='88800000-0000-0000-0000-000000000102';
DECLARE @AddSet uniqueidentifier='88800000-0000-0000-0000-000000000103';
DECLARE @Build uniqueidentifier='88800000-0000-0000-0000-000000000201';
DECLARE @OtherRule uniqueidentifier=(SELECT TOP (1) [RuleId] FROM [ATAPUtilities].[Rule] WHERE [RuleId]<>@Rule ORDER BY [RuleId]);
DECLARE @BaseVariant uniqueidentifier='88000000-0000-0000-0000-000000000001';
DECLARE @OverlayVariant uniqueidentifier='88000000-0000-0000-0000-000000000002';
DECLARE @AddVariant uniqueidentifier='88000000-0000-0000-0000-000000000003';
DECLARE @BaseInput uniqueidentifier='88400000-0000-0000-0000-000000000001';
DECLARE @ReplacementInput uniqueidentifier='88400000-0000-0000-0000-000000000002';
DECLARE @OtherInput uniqueidentifier='88400000-0000-0000-0000-000000000003';
DECLARE @LateInput uniqueidentifier='88400000-0000-0000-0000-000000000004';
DECLARE @LateOutput uniqueidentifier='88400000-0000-0000-0000-000000000005';
DECLARE @TextType uniqueidentifier='80000000-0000-0000-0000-000000000004';
DECLARE @GuidType uniqueidentifier='80000000-0000-0000-0000-000000000005';
DECLARE @Normalization uniqueidentifier='80000000-0000-0000-0000-000000000101';
DECLARE @Later datetime2(7)=DATEADD(hour,1,@At);
IF @Rule IS NULL OR @OtherRule IS NULL THROW 58900,'V00010 fixture rows missing.',1;

INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub]) VALUES
 (@BaseSet,NULL),(@OverlaySet,NULL),(@AddSet,NULL),(@Build,NULL),(@BaseVariant,NULL),(@OverlayVariant,NULL);
INSERT INTO [ATAPUtilities].[RuleSet] ([RuleSetId],[PhiloteId],[RuleSetCode]) VALUES
 (@BaseSet,@BaseSet,'v80-fixture-baseline'),(@OverlaySet,@OverlaySet,'v80-fixture-overlay'),(@AddSet,@AddSet,'v80-fixture-add');
INSERT INTO [ATAPUtilities].[BuildSet] ([BuildSetId],[PhiloteId],[BuildSetCode])
 VALUES (@Build,@Build,'v80-fixture-build');
INSERT INTO [ATAPUtilities].[RuleVariant] ([RuleVariantId],[PhiloteId],[RuleId],[OwningRuleSetId],[RuleVariantCode]) VALUES
 (@BaseVariant,@BaseVariant,@Rule,@BaseSet,N'baseline'),(@OverlayVariant,@OverlayVariant,@Rule,@OverlaySet,N'ace-budget-override');
INSERT INTO [ATAPUtilities].[RuleInputDefinition]
 ([RuleInputDefinitionId],[RuleId],[InputCode],[ValueTypeId],[StorageKindCode],[IsRequired],[AllowsNull],[Ordinal],[InputNormalizationContractId],[SecretPolicyCode]) VALUES
 (@BaseInput,@Rule,N'budget',@TextType,'Text',1,0,0,@Normalization,'NotSecret'),
 (@ReplacementInput,@Rule,N'budget',@GuidType,'Guid',1,0,0,@Normalization,'NotSecret'),
 (@OtherInput,@OtherRule,N'budget',@TextType,'Text',1,0,0,@Normalization,'NotSecret'),
 (@LateInput,@Rule,N'late-input',@TextType,'Text',0,1,1,@Normalization,'NotSecret');
INSERT INTO [ATAPUtilities].[RuleOutputDefinition]
 ([RuleOutputDefinitionId],[RuleId],[OutputCode],[ValueTypeId],[StorageKindCode],[AllowsNull],[Ordinal],[DispositionCode])
 VALUES (@LateOutput,@Rule,N'late-output',@TextType,'Text',1,0,'Return');
INSERT INTO [ATAPUtilities].[RuleOutputDefinitionState]
 ([RuleOutputDefinitionStateId],[RuleOutputDefinitionId],[ValidFromUtc],[DisplayName],[Description])
 VALUES ('88500000-0000-0000-0000-000000000101',@LateOutput,@At,N'Late output',N'Output state');
INSERT INTO [ATAPUtilities].[RuleInputDefinitionState]
 ([RuleInputDefinitionStateId],[RuleInputDefinitionId],[ValidFromUtc],[DisplayName],[Description])
 VALUES ('88500000-0000-0000-0000-000000000001',@BaseInput,@At,N'Budget',N'Baseline display state');
INSERT INTO [ATAPUtilities].[RuleDefaultInputValue]
 ([RuleDefaultInputValueId],[RuleInputDefinitionId],[ValueTypeId],[StorageKindCode],[ValidFromUtc],[TextValue])
 VALUES ('88600000-0000-0000-0000-000000000001',@BaseInput,@TextType,'Text',@At,N'1500');
INSERT INTO [ATAPUtilities].[RuleValueConstraint]
 ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[MaximumTextLength])
VALUES ('88700000-0000-0000-0000-000000000001',@BaseInput,'TextLength',4);
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleValueConstraint]
  ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[MaximumTextLength])
 VALUES ('88700000-0000-0000-0000-000000000010',@BaseInput,'TextLength',8);
 THROW 58917,'Duplicate owner constraint kind was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER() NOT IN (2601,2627) THROW; END CATCH;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleValueConstraint]
  ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[MaximumTextLength],[DomainConstraintCode])
 VALUES ('88700000-0000-0000-0000-000000000011',@ReplacementInput,'TextLength',8,N'irrelevant-mixed-payload');
 THROW 58918,'Mixed constraint discriminant payload was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>547 THROW; END CATCH;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleValueConstraint]
  ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[MinimumCardinality],[CollectionShapeCode])
 VALUES ('88700000-0000-0000-0000-000000000012',@ReplacementInput,'CardinalityShape',0,N'');
 THROW 58923,'Empty collection shape was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>547 THROW; END CATCH;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleValueConstraint]
  ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[DeclaredContractTypeCode])
 VALUES ('88700000-0000-0000-0000-000000000013',@ReplacementInput,'DeclaredContract',N'');
 THROW 58924,'Empty declared contract was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>547 THROW; END CATCH;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleValueConstraint]
  ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[DomainConstraintCode])
 VALUES ('88700000-0000-0000-0000-000000000014',@ReplacementInput,'DeclaredDomain',N'');
 THROW 58925,'Empty declared domain was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>547 THROW; END CATCH;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleValueConstraint]
  ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[ContractText])
 VALUES ('88700000-0000-0000-0000-000000000015',@ReplacementInput,'ContractText',N'');
 THROW 58926,'Empty contract text was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>547 THROW; END CATCH;
INSERT INTO [ATAPUtilities].[RuleVariantInputDefinition]
 ([RuleVariantId],[RuleInputDefinitionId],[RuleId],[InputCode],[Ordinal]) VALUES
 (@BaseVariant,@BaseInput,@Rule,N'budget',0),(@OverlayVariant,@ReplacementInput,@Rule,N'budget',0);
INSERT INTO [ATAPUtilities].[RuleVariantState]
 ([RuleVariantStateId],[RuleVariantId],[ValidFromUtc],[ValidToUtc],[Purpose],[ExecutorContractCode],[NormalizedBody],[LifecycleStatusCode]) VALUES
 ('88100000-0000-0000-0000-000000000001',@BaseVariant,@At,NULL,N'baseline',N'deterministic-v1',N'budget=1500',N'Active'),
 ('88100000-0000-0000-0000-000000000002',@OverlayVariant,@At,NULL,N'overlay',N'deterministic-v1',N'budget=1200',N'Active');

BEGIN TRY INSERT INTO [ATAPUtilities].[RuleInputDefinitionState]
 ([RuleInputDefinitionStateId],[RuleInputDefinitionId],[ValidFromUtc],[DisplayName],[Description])
 VALUES ('88500000-0000-0000-0000-000000000010',@BaseInput,DATEADD(minute,10,@At),N'open overlap',N'negative');
 THROW 58930,'Open input state overlap was accepted.',1; END TRY BEGIN CATCH IF ERROR_NUMBER() NOT IN (2601,2627) THROW; END CATCH;
BEGIN TRY INSERT INTO [ATAPUtilities].[RuleInputDefinitionState]
 ([RuleInputDefinitionStateId],[RuleInputDefinitionId],[ValidFromUtc],[ValidToUtc],[DisplayName],[Description])
 VALUES ('88500000-0000-0000-0000-000000000011',@BaseInput,DATEADD(minute,10,@At),DATEADD(minute,20,@At),N'closed overlap',N'negative');
 THROW 58931,'Closed input state overlap was accepted.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>58040 THROW; END CATCH;
BEGIN TRY INSERT INTO [ATAPUtilities].[RuleOutputDefinitionState]
 ([RuleOutputDefinitionStateId],[RuleOutputDefinitionId],[ValidFromUtc],[DisplayName],[Description])
 VALUES ('88500000-0000-0000-0000-000000000110',@LateOutput,DATEADD(minute,10,@At),N'open overlap',N'negative');
 THROW 58932,'Open output state overlap was accepted.',1; END TRY BEGIN CATCH IF ERROR_NUMBER() NOT IN (2601,2627) THROW; END CATCH;
BEGIN TRY INSERT INTO [ATAPUtilities].[RuleOutputDefinitionState]
 ([RuleOutputDefinitionStateId],[RuleOutputDefinitionId],[ValidFromUtc],[ValidToUtc],[DisplayName],[Description])
 VALUES ('88500000-0000-0000-0000-000000000111',@LateOutput,DATEADD(minute,10,@At),DATEADD(minute,20,@At),N'closed overlap',N'negative');
 THROW 58933,'Closed output state overlap was accepted.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>58041 THROW; END CATCH;
BEGIN TRY INSERT INTO [ATAPUtilities].[RuleDefaultInputValue]
 ([RuleDefaultInputValueId],[RuleInputDefinitionId],[ValueTypeId],[StorageKindCode],[ValidFromUtc],[TextValue])
 VALUES ('88600000-0000-0000-0000-000000000010',@BaseInput,@TextType,'Text',DATEADD(minute,10,@At),N'open');
 THROW 58934,'Open default overlap was accepted.',1; END TRY BEGIN CATCH IF ERROR_NUMBER() NOT IN (2601,2627) THROW; END CATCH;
BEGIN TRY INSERT INTO [ATAPUtilities].[RuleDefaultInputValue]
 ([RuleDefaultInputValueId],[RuleInputDefinitionId],[ValueTypeId],[StorageKindCode],[ValidFromUtc],[ValidToUtc],[TextValue])
 VALUES ('88600000-0000-0000-0000-000000000011',@BaseInput,@TextType,'Text',DATEADD(minute,10,@At),DATEADD(minute,20,@At),N'closed');
 THROW 58935,'Closed default overlap was accepted.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>58042 THROW; END CATCH;
BEGIN TRY INSERT INTO [ATAPUtilities].[RuleVariantState]
 ([RuleVariantStateId],[RuleVariantId],[ValidFromUtc],[Purpose],[ExecutorContractCode],[NormalizedBody],[LifecycleStatusCode])
 VALUES ('88100000-0000-0000-0000-000000000010',@BaseVariant,DATEADD(minute,10,@At),N'open overlap',N'deterministic-v1',N'negative',N'Active');
 THROW 58936,'Open variant state overlap was accepted.',1; END TRY BEGIN CATCH IF ERROR_NUMBER() NOT IN (2601,2627) THROW; END CATCH;
BEGIN TRY INSERT INTO [ATAPUtilities].[RuleVariantState]
 ([RuleVariantStateId],[RuleVariantId],[ValidFromUtc],[ValidToUtc],[Purpose],[ExecutorContractCode],[NormalizedBody],[LifecycleStatusCode])
 VALUES ('88100000-0000-0000-0000-000000000011',@BaseVariant,DATEADD(minute,10,@At),DATEADD(minute,20,@At),N'closed overlap',N'deterministic-v1',N'negative',N'Active');
 THROW 58937,'Closed variant state overlap was accepted.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>58043 THROW; END CATCH;
IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleVariantInputDefinition] WHERE [InputCode]=N'budget')<>2
 THROW 58909,'Replacement definition binding did not retain the prior binding.',1;
INSERT INTO [ATAPUtilities].[RuleSetRuleOccurrence]
 ([RuleSetRuleOccurrenceId],[RuleSetId],[RuleVariantId],[RuleSetMembershipRoleCode],[Ordinal],[ValidFromUtc]) VALUES
 ('88200000-0000-0000-0000-000000000001',@BaseSet,@BaseVariant,'Add',0,@At),
 ('88200000-0000-0000-0000-000000000002',@OverlaySet,@OverlayVariant,'Override',0,@At);
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleVariantInputDefinition]
  ([RuleVariantId],[RuleInputDefinitionId],[RuleId],[InputCode],[Ordinal])
 VALUES (@BaseVariant,@LateInput,@Rule,N'late-input',1);
 THROW 58919,'Input binding was added after variant activation.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58038 THROW; END CATCH;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleVariantOutputDefinition]
  ([RuleVariantId],[RuleOutputDefinitionId],[RuleId],[OutputCode],[Ordinal])
 VALUES (@BaseVariant,@LateOutput,@Rule,N'late-output',0);
 THROW 58920,'Output binding was added after variant activation.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58039 THROW; END CATCH;
INSERT INTO [ATAPUtilities].[BuildSetRuleSetOccurrence]
 ([BuildSetRuleSetOccurrenceId],[BuildSetId],[RuleSetId],[Ordinal],[ValidFromUtc]) VALUES
 ('88300000-0000-0000-0000-000000000001',@Build,@BaseSet,10,@At),
 ('88300000-0000-0000-0000-000000000002',@Build,@OverlaySet,20,@At);

DECLARE @Resolved TABLE
 ([RuleId] uniqueidentifier,[RuleVariantId] uniqueidentifier,[RuleVariantStateId] uniqueidentifier,
  [RuleSetMembershipRoleCode] varchar(16),[ResolutionDisposition] varchar(10),[PrecedenceRank] bigint,
  [BuildSetId] uniqueidentifier,[BuildSetRuleSetOccurrenceId] uniqueidentifier,[BuildSetOrdinal] int,
  [RuleSetId] uniqueidentifier,[RuleSetRuleOccurrenceId] uniqueidentifier,[RuleSetOrdinal] int);
INSERT INTO @Resolved EXEC [ATAPUtilities].[ResolveBuildSetRulesAsOf] @Build,@At;
IF (SELECT COUNT_BIG(*) FROM @Resolved)<>2 THROW 58901,'Expected selected and shadowed provenance.',1;
IF NOT EXISTS (SELECT 1 FROM @Resolved WHERE [RuleVariantId]=@OverlayVariant AND [ResolutionDisposition]='Selected' AND [PrecedenceRank]=1)
 THROW 58902,'Higher-ordinal override did not win.',1;
IF NOT EXISTS (SELECT 1 FROM @Resolved WHERE [RuleVariantId]=@BaseVariant AND [ResolutionDisposition]='Shadowed' AND [PrecedenceRank]=2)
 THROW 58903,'Baseline provenance was not retained.',1;

BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleSetRuleOccurrence]
  ([RuleSetRuleOccurrenceId],[RuleSetId],[RuleVariantId],[RuleSetMembershipRoleCode],[Ordinal],[ValidFromUtc])
 VALUES ('88200000-0000-0000-0000-000000000099',@OverlaySet,@BaseVariant,'Add',99,@At);
 THROW 58904,'Cross-owner occurrence was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>547 THROW; END CATCH;

BEGIN TRY
 INSERT INTO [ATAPUtilities].[BuildSetRuleSetOccurrence]
  ([BuildSetRuleSetOccurrenceId],[BuildSetId],[RuleSetId],[Ordinal],[ValidFromUtc])
 VALUES ('88300000-0000-0000-0000-000000000099',@Build,@OverlaySet,10,@At);
 THROW 58905,'Duplicate BuildSet ordinal was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER() NOT IN (2601,2627) THROW; END CATCH;

BEGIN TRY UPDATE [ATAPUtilities].[RuleSetRuleOccurrence] SET [Ordinal]=1
 WHERE [RuleSetRuleOccurrenceId]='88200000-0000-0000-0000-000000000002';
 THROW 58921,'RuleSet occurrence provenance was edited.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>58036 THROW; END CATCH;
BEGIN TRY UPDATE [ATAPUtilities].[BuildSetRuleSetOccurrence] SET [Ordinal]=30
 WHERE [BuildSetRuleSetOccurrenceId]='88300000-0000-0000-0000-000000000002';
 THROW 58922,'BuildSet occurrence provenance was edited.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>58037 THROW; END CATCH;

UPDATE [ATAPUtilities].[BuildSetRuleSetOccurrence] SET [ValidToUtc]=@Later
 WHERE [BuildSetRuleSetOccurrenceId]='88300000-0000-0000-0000-000000000001';
BEGIN TRY EXEC [ATAPUtilities].[ResolveBuildSetRulesAsOf] @Build,@Later; THROW 58907,'Override without baseline was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58022 THROW; END CATCH;

INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub]) VALUES (@AddVariant,NULL);
INSERT INTO [ATAPUtilities].[RuleVariant] ([RuleVariantId],[PhiloteId],[RuleId],[OwningRuleSetId],[RuleVariantCode])
 VALUES (@AddVariant,@AddVariant,@Rule,@AddSet,N'colliding-add');
INSERT INTO [ATAPUtilities].[RuleVariantState]
 ([RuleVariantStateId],[RuleVariantId],[ValidFromUtc],[Purpose],[ExecutorContractCode],[NormalizedBody],[LifecycleStatusCode])
 VALUES ('88100000-0000-0000-0000-000000000003',@AddVariant,@At,N'collision',N'deterministic-v1',N'budget=999',N'Active');
INSERT INTO [ATAPUtilities].[RuleSetRuleOccurrence]
 ([RuleSetRuleOccurrenceId],[RuleSetId],[RuleVariantId],[RuleSetMembershipRoleCode],[Ordinal],[ValidFromUtc])
 VALUES ('88200000-0000-0000-0000-000000000003',@AddSet,@AddVariant,'Add',0,@At);
INSERT INTO [ATAPUtilities].[BuildSetRuleSetOccurrence]
 ([BuildSetRuleSetOccurrenceId],[BuildSetId],[RuleSetId],[Ordinal],[ValidFromUtc])
 VALUES ('88300000-0000-0000-0000-000000000003',@Build,@AddSet,30,@At);
BEGIN TRY EXEC [ATAPUtilities].[ResolveBuildSetRulesAsOf] @Build,@At; THROW 58906,'Add collision was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58023 THROW; END CATCH;

BEGIN TRY
 UPDATE [ATAPUtilities].[RuleInputDefinition] SET [ValueTypeId]=@TextType,[StorageKindCode]='Text'
  WHERE [RuleInputDefinitionId]=@ReplacementInput;
 THROW 58908,'Material type mutation was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58010 THROW; END CATCH;
BEGIN TRY UPDATE [ATAPUtilities].[ValueType] SET [ValueTypeCode]=N'TextChanged' WHERE [ValueTypeId]=@TextType;
 THROW 58910,'ValueType mutation was accepted.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>58014 THROW; END CATCH;
BEGIN TRY UPDATE [ATAPUtilities].[Rule] SET [RuleKindId]=[RuleKindId] WHERE [RuleId]=@Rule;
 THROW 58911,'Rule-kind in-place update was accepted.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>58013 THROW; END CATCH;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleVariantInputDefinition] ([RuleVariantId],[RuleInputDefinitionId],[RuleId],[InputCode],[Ordinal])
 VALUES (@BaseVariant,@OtherInput,@OtherRule,N'other',1);
 THROW 58912,'Cross-Rule variant-definition binding was accepted.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>547 THROW; END CATCH;
BEGIN TRY
 INSERT INTO [ATAPUtilities].[RuleValueConstraint]
  ([RuleValueConstraintId],[RuleInputDefinitionId],[ConstraintKindCode],[DomainConstraintCode])
 VALUES ('88700000-0000-0000-0000-000000000002',@BaseInput,'DeclaredDomain',N'positive-budget');
 THROW 58913,'Constraint added after variant binding.',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>58018 THROW; END CATCH;

UPDATE [ATAPUtilities].[RuleInputDefinitionState] SET [ValidToUtc]=@Later
 WHERE [RuleInputDefinitionStateId]='88500000-0000-0000-0000-000000000001';
INSERT INTO [ATAPUtilities].[RuleInputDefinitionState]
 ([RuleInputDefinitionStateId],[RuleInputDefinitionId],[ValidFromUtc],[DisplayName],[Description])
 VALUES ('88500000-0000-0000-0000-000000000002',@BaseInput,@Later,N'Budget limit',N'Changed display only');
UPDATE [ATAPUtilities].[RuleDefaultInputValue] SET [ValidToUtc]=@Later
 WHERE [RuleDefaultInputValueId]='88600000-0000-0000-0000-000000000001';
INSERT INTO [ATAPUtilities].[RuleDefaultInputValue]
 ([RuleDefaultInputValueId],[RuleInputDefinitionId],[ValueTypeId],[StorageKindCode],[ValidFromUtc],[TextValue])
 VALUES ('88600000-0000-0000-0000-000000000002',@BaseInput,@TextType,'Text',@Later,N'1200');
IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleInputDefinitionState] WHERE [RuleInputDefinitionId]=@BaseInput)<>2
 OR (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleDefaultInputValue] WHERE [RuleInputDefinitionId]=@BaseInput)<>2
 THROW 58914,'Non-material history was not retained.',1;
BEGIN TRY UPDATE [ATAPUtilities].[RuleInputDefinitionState] SET [DisplayName]=N'overwrite'
 WHERE [RuleInputDefinitionStateId]='88500000-0000-0000-0000-000000000001';
 THROW 58915,'Closed display history was overwritten.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>58030 THROW; END CATCH;
BEGIN TRY UPDATE [ATAPUtilities].[RuleDefaultInputValue] SET [TextValue]=N'overwrite'
 WHERE [RuleDefaultInputValueId]='88600000-0000-0000-0000-000000000001';
 THROW 58916,'Closed default history was overwritten.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>58032 THROW; END CATCH;
'@
  }

  It 'applies fresh from V00010 through V00080 and exposes the frozen object boundary' -Skip:(-not $canRun) {
    $databaseName = New-Task15140cV80DisposableDatabase
    try {
      Invoke-Task15140cV80Flyway -DatabaseName $databaseName -Command migrate -Target 10
      Invoke-Task15140cV80Flyway -DatabaseName $databaseName -Command migrate -Target 80
      Invoke-Task15140cV80Flyway -DatabaseName $databaseName -Command validate -Target 80
      $verify = "SET NOCOUNT ON; IF (SELECT COUNT_BIG(*) FROM dbo.flyway_schema_history WHERE success=1)<>7 THROW 58920,'Expected seven migrations.',1; IF OBJECT_ID(N'[ATAPUtilities].[RuleVariant]',N'U') IS NULL OR OBJECT_ID(N'[ATAPUtilities].[ResolveBuildSetRulesAsOf]',N'P') IS NULL THROW 58921,'V00080 boundary missing.',1;"
      & sqlcmd -S $localInstance -E -d $databaseName -b -Q $verify
      $LASTEXITCODE | Should -Be 0
    }
    finally { Remove-Task15140cV80DisposableDatabase -Name $databaseName }
  }

  It 'upgrades V00070 to V00080 and passes positive and adversarial overlay fixtures' -Skip:(-not $canRun) {
    $databaseName = New-Task15140cV80DisposableDatabase
    try {
      Invoke-Task15140cV80Flyway -DatabaseName $databaseName -Command migrate -Target 70
      Invoke-Task15140cV80Flyway -DatabaseName $databaseName -Command migrate -Target 80
      Invoke-Task15140cV80Flyway -DatabaseName $databaseName -Command validate -Target 80
      $fixtureOutput = & sqlcmd -S $localInstance -E -d $databaseName -b -Q $functionalFixture 2>&1
      $LASTEXITCODE | Should -Be 0 -Because ($fixtureOutput -join [Environment]::NewLine)
    }
    finally { Remove-Task15140cV80DisposableDatabase -Name $databaseName }
  }
}

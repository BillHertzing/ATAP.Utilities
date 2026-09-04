/*
  RPRRSBSI V4 core identity and overlay acceptance slice (Task 15.140.c).

  This forward-only migration preserves every V00010 through V00070 object. It
  adds immutable typed definition identities, temporal state/default history,
  owner-bound RuleVariants, ordered RuleSet/BuildSet occurrences, and a
  deterministic resolver with explicit provenance.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'[ATAPUtilities].[Rule]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RuleSet]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[BuildSet]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[Philote]', N'U') IS NULL
        THROW 58001, N'The V00010 RPRRSBSI baseline is required.', 1;

    IF OBJECT_ID(N'[ATAPUtilities].[ValueType]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RuleInputDefinition]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RuleInputDefinitionState]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RuleDefaultInputValue]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RuleOutputDefinition]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RuleOutputDefinitionState]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[InputNormalizationContract]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RuleValueConstraint]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RuleVariant]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RuleVariantState]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RuleVariantInputDefinition]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RuleVariantOutputDefinition]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RuleSetMembershipRole]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RuleSetRuleOccurrence]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[BuildSetRuleSetOccurrence]', N'U') IS NOT NULL
       OR OBJECT_ID(N'[ATAPUtilities].[ResolveBuildSetRulesAsOf]', N'P') IS NOT NULL
        THROW 58002, N'One or more V00080 target objects already exist.', 1;

    CREATE TABLE [ATAPUtilities].[ValueType]
    (
        [ValueTypeId] uniqueidentifier NOT NULL,
        [ValueTypeCode] nvarchar(64) NOT NULL,
        [StorageKindCode] varchar(16) NOT NULL,
        [IsCollection] bit NOT NULL,
        [ObjectTypeCode] nvarchar(256) NULL,
        CONSTRAINT [PK_ValueType] PRIMARY KEY ([ValueTypeId]),
        CONSTRAINT [UQ_ValueType_Code] UNIQUE ([ValueTypeCode]),
        CONSTRAINT [UQ_ValueType_Id_StorageKind] UNIQUE ([ValueTypeId], [StorageKindCode]),
        CONSTRAINT [CK_ValueType_Code_NotEmpty] CHECK (DATALENGTH([ValueTypeCode]) > 0),
        CONSTRAINT [CK_ValueType_StorageKind]
            CHECK ([StorageKindCode] IN ('Bit','Int64','Decimal','Text','Guid','DateTimeUtc','Duration','Json')),
        CONSTRAINT [CK_ValueType_ObjectShape]
            CHECK (([StorageKindCode] = 'Json' AND [ObjectTypeCode] IS NOT NULL AND DATALENGTH([ObjectTypeCode]) > 0)
                OR ([StorageKindCode] <> 'Json' AND [ObjectTypeCode] IS NULL))
    );

    CREATE TABLE [ATAPUtilities].[InputNormalizationContract]
    (
        [InputNormalizationContractId] uniqueidentifier NOT NULL,
        [NormalizationContractCode] nvarchar(128) NOT NULL,
        [ContractText] nvarchar(max) NOT NULL,
        CONSTRAINT [PK_InputNormalizationContract] PRIMARY KEY ([InputNormalizationContractId]),
        CONSTRAINT [UQ_InputNormalizationContract_Code] UNIQUE ([NormalizationContractCode]),
        CONSTRAINT [CK_InputNormalizationContract_Code] CHECK (DATALENGTH([NormalizationContractCode]) > 0),
        CONSTRAINT [CK_InputNormalizationContract_Text] CHECK (DATALENGTH([ContractText]) > 0)
    );
    INSERT INTO [ATAPUtilities].[InputNormalizationContract]
        ([InputNormalizationContractId], [NormalizationContractCode], [ContractText])
    VALUES ('80000000-0000-0000-0000-000000000101', N'identity-v1', N'Return the declared value unchanged.');

    INSERT INTO [ATAPUtilities].[ValueType]
        ([ValueTypeId], [ValueTypeCode], [StorageKindCode], [IsCollection], [ObjectTypeCode])
    VALUES
        ('80000000-0000-0000-0000-000000000001', N'Boolean',     'Bit',         0, NULL),
        ('80000000-0000-0000-0000-000000000002', N'Integer',     'Int64',       0, NULL),
        ('80000000-0000-0000-0000-000000000003', N'Decimal',     'Decimal',     0, NULL),
        ('80000000-0000-0000-0000-000000000004', N'Text',        'Text',        0, NULL),
        ('80000000-0000-0000-0000-000000000005', N'Guid',        'Guid',        0, NULL),
        ('80000000-0000-0000-0000-000000000006', N'Uri',         'Text',        0, NULL),
        ('80000000-0000-0000-0000-000000000007', N'DateTimeUtc', 'DateTimeUtc', 0, NULL),
        ('80000000-0000-0000-0000-000000000008', N'Duration',    'Duration',    0, NULL),
        ('80000000-0000-0000-0000-000000000009', N'Quantity',    'Decimal',     0, NULL),
        ('80000000-0000-0000-0000-00000000000a', N'JsonDocument','Json',        0, N'json-document');

    CREATE TABLE [ATAPUtilities].[RuleInputDefinition]
    (
        [RuleInputDefinitionId] uniqueidentifier NOT NULL,
        [RuleId] uniqueidentifier NOT NULL,
        [InputCode] nvarchar(128) NOT NULL,
        [ValueTypeId] uniqueidentifier NOT NULL,
        [StorageKindCode] varchar(16) NOT NULL,
        [IsRequired] bit NOT NULL,
        [AllowsNull] bit NOT NULL,
        [Ordinal] int NOT NULL,
        [InputNormalizationContractId] uniqueidentifier NOT NULL,
        [SecretPolicyCode] varchar(24) NOT NULL,
        CONSTRAINT [PK_RuleInputDefinition] PRIMARY KEY ([RuleInputDefinitionId]),
        CONSTRAINT [FK_RuleInputDefinition_Rule] FOREIGN KEY ([RuleId])
            REFERENCES [ATAPUtilities].[Rule] ([RuleId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_RuleInputDefinition_ValueType] FOREIGN KEY ([ValueTypeId], [StorageKindCode])
            REFERENCES [ATAPUtilities].[ValueType] ([ValueTypeId], [StorageKindCode]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_RuleInputDefinition_Normalization] FOREIGN KEY ([InputNormalizationContractId])
            REFERENCES [ATAPUtilities].[InputNormalizationContract] ([InputNormalizationContractId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_RuleInputDefinition_Id_Type]
            UNIQUE ([RuleInputDefinitionId], [ValueTypeId], [StorageKindCode]),
        CONSTRAINT [UQ_RuleInputDefinition_Registration]
            UNIQUE ([RuleInputDefinitionId], [RuleId], [InputCode], [Ordinal]),
        CONSTRAINT [CK_RuleInputDefinition_Code_NotEmpty] CHECK (DATALENGTH([InputCode]) > 0),
        CONSTRAINT [CK_RuleInputDefinition_Ordinal] CHECK ([Ordinal] >= 0),
        CONSTRAINT [CK_RuleInputDefinition_SecretPolicy]
            CHECK ([SecretPolicyCode] IN ('NotSecret','SecretReferenceOnly'))
    );

    CREATE TABLE [ATAPUtilities].[RuleInputDefinitionState]
    (
        [RuleInputDefinitionStateId] uniqueidentifier NOT NULL,
        [RuleInputDefinitionId] uniqueidentifier NOT NULL,
        [ValidFromUtc] datetime2(7) NOT NULL,
        [ValidToUtc] datetime2(7) NULL,
        [DisplayName] nvarchar(256) NOT NULL,
        [Description] nvarchar(2048) NOT NULL,
        CONSTRAINT [PK_RuleInputDefinitionState] PRIMARY KEY ([RuleInputDefinitionStateId]),
        CONSTRAINT [FK_RuleInputDefinitionState_Definition] FOREIGN KEY ([RuleInputDefinitionId])
            REFERENCES [ATAPUtilities].[RuleInputDefinition] ([RuleInputDefinitionId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_RuleInputDefinitionState_From] UNIQUE ([RuleInputDefinitionId], [ValidFromUtc]),
        CONSTRAINT [CK_RuleInputDefinitionState_Period] CHECK ([ValidToUtc] IS NULL OR [ValidFromUtc] < [ValidToUtc]),
        CONSTRAINT [CK_RuleInputDefinitionState_DisplayName] CHECK (DATALENGTH([DisplayName]) > 0)
    );
    CREATE UNIQUE INDEX [UX_RuleInputDefinitionState_Current]
        ON [ATAPUtilities].[RuleInputDefinitionState] ([RuleInputDefinitionId]) WHERE [ValidToUtc] IS NULL;

    CREATE TABLE [ATAPUtilities].[RuleDefaultInputValue]
    (
        [RuleDefaultInputValueId] uniqueidentifier NOT NULL,
        [RuleInputDefinitionId] uniqueidentifier NOT NULL,
        [ValueTypeId] uniqueidentifier NOT NULL,
        [StorageKindCode] varchar(16) NOT NULL,
        [ValidFromUtc] datetime2(7) NOT NULL,
        [ValidToUtc] datetime2(7) NULL,
        [BitValue] bit NULL,
        [Int64Value] bigint NULL,
        [DecimalValue] decimal(38,12) NULL,
        [TextValue] nvarchar(4000) NULL,
        [GuidValue] uniqueidentifier NULL,
        [DateTimeUtcValue] datetime2(7) NULL,
        [DurationTicksValue] bigint NULL,
        [JsonValue] nvarchar(max) NULL,
        CONSTRAINT [PK_RuleDefaultInputValue] PRIMARY KEY ([RuleDefaultInputValueId]),
        CONSTRAINT [FK_RuleDefaultInputValue_DefinitionType]
            FOREIGN KEY ([RuleInputDefinitionId], [ValueTypeId], [StorageKindCode])
            REFERENCES [ATAPUtilities].[RuleInputDefinition]
                ([RuleInputDefinitionId], [ValueTypeId], [StorageKindCode])
            ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_RuleDefaultInputValue_From] UNIQUE ([RuleInputDefinitionId], [ValidFromUtc]),
        CONSTRAINT [CK_RuleDefaultInputValue_Period] CHECK ([ValidToUtc] IS NULL OR [ValidFromUtc] < [ValidToUtc]),
        CONSTRAINT [CK_RuleDefaultInputValue_ExactlyOne]
            CHECK (CONVERT(int,CASE WHEN [BitValue] IS NULL THEN 0 ELSE 1 END)
                 + CONVERT(int,CASE WHEN [Int64Value] IS NULL THEN 0 ELSE 1 END)
                 + CONVERT(int,CASE WHEN [DecimalValue] IS NULL THEN 0 ELSE 1 END)
                 + CONVERT(int,CASE WHEN [TextValue] IS NULL THEN 0 ELSE 1 END)
                 + CONVERT(int,CASE WHEN [GuidValue] IS NULL THEN 0 ELSE 1 END)
                 + CONVERT(int,CASE WHEN [DateTimeUtcValue] IS NULL THEN 0 ELSE 1 END)
                 + CONVERT(int,CASE WHEN [DurationTicksValue] IS NULL THEN 0 ELSE 1 END)
                 + CONVERT(int,CASE WHEN [JsonValue] IS NULL THEN 0 ELSE 1 END) = 1),
        CONSTRAINT [CK_RuleDefaultInputValue_Discriminant]
            CHECK (([StorageKindCode]='Bit' AND [BitValue] IS NOT NULL)
                OR ([StorageKindCode]='Int64' AND [Int64Value] IS NOT NULL)
                OR ([StorageKindCode]='Decimal' AND [DecimalValue] IS NOT NULL)
                OR ([StorageKindCode]='Text' AND [TextValue] IS NOT NULL)
                OR ([StorageKindCode]='Guid' AND [GuidValue] IS NOT NULL)
                OR ([StorageKindCode]='DateTimeUtc' AND [DateTimeUtcValue] IS NOT NULL)
                OR ([StorageKindCode]='Duration' AND [DurationTicksValue] IS NOT NULL)
                OR ([StorageKindCode]='Json' AND [JsonValue] IS NOT NULL AND ISJSON([JsonValue])=1))
    );
    CREATE UNIQUE INDEX [UX_RuleDefaultInputValue_Current]
        ON [ATAPUtilities].[RuleDefaultInputValue] ([RuleInputDefinitionId]) WHERE [ValidToUtc] IS NULL;

    CREATE TABLE [ATAPUtilities].[RuleOutputDefinition]
    (
        [RuleOutputDefinitionId] uniqueidentifier NOT NULL,
        [RuleId] uniqueidentifier NOT NULL,
        [OutputCode] nvarchar(128) NOT NULL,
        [ValueTypeId] uniqueidentifier NOT NULL,
        [StorageKindCode] varchar(16) NOT NULL,
        [AllowsNull] bit NOT NULL,
        [Ordinal] int NOT NULL,
        [DispositionCode] varchar(24) NOT NULL,
        CONSTRAINT [PK_RuleOutputDefinition] PRIMARY KEY ([RuleOutputDefinitionId]),
        CONSTRAINT [FK_RuleOutputDefinition_Rule] FOREIGN KEY ([RuleId])
            REFERENCES [ATAPUtilities].[Rule] ([RuleId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_RuleOutputDefinition_ValueType] FOREIGN KEY ([ValueTypeId], [StorageKindCode])
            REFERENCES [ATAPUtilities].[ValueType] ([ValueTypeId], [StorageKindCode]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_RuleOutputDefinition_Registration]
            UNIQUE ([RuleOutputDefinitionId], [RuleId], [OutputCode], [Ordinal]),
        CONSTRAINT [CK_RuleOutputDefinition_Code_NotEmpty] CHECK (DATALENGTH([OutputCode]) > 0),
        CONSTRAINT [CK_RuleOutputDefinition_Ordinal] CHECK ([Ordinal] >= 0),
        CONSTRAINT [CK_RuleOutputDefinition_Disposition] CHECK ([DispositionCode] IN ('Return','Persist','Diagnostic'))
    );

    CREATE TABLE [ATAPUtilities].[RuleOutputDefinitionState]
    (
        [RuleOutputDefinitionStateId] uniqueidentifier NOT NULL,
        [RuleOutputDefinitionId] uniqueidentifier NOT NULL,
        [ValidFromUtc] datetime2(7) NOT NULL,
        [ValidToUtc] datetime2(7) NULL,
        [DisplayName] nvarchar(256) NOT NULL,
        [Description] nvarchar(2048) NOT NULL,
        CONSTRAINT [PK_RuleOutputDefinitionState] PRIMARY KEY ([RuleOutputDefinitionStateId]),
        CONSTRAINT [FK_RuleOutputDefinitionState_Definition] FOREIGN KEY ([RuleOutputDefinitionId])
            REFERENCES [ATAPUtilities].[RuleOutputDefinition] ([RuleOutputDefinitionId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_RuleOutputDefinitionState_From] UNIQUE ([RuleOutputDefinitionId], [ValidFromUtc]),
        CONSTRAINT [CK_RuleOutputDefinitionState_Period] CHECK ([ValidToUtc] IS NULL OR [ValidFromUtc] < [ValidToUtc]),
        CONSTRAINT [CK_RuleOutputDefinitionState_DisplayName] CHECK (DATALENGTH([DisplayName]) > 0)
    );
    CREATE UNIQUE INDEX [UX_RuleOutputDefinitionState_Current]
        ON [ATAPUtilities].[RuleOutputDefinitionState] ([RuleOutputDefinitionId]) WHERE [ValidToUtc] IS NULL;

    CREATE TABLE [ATAPUtilities].[RuleValueConstraint]
    (
        [RuleValueConstraintId] uniqueidentifier NOT NULL,
        [RuleInputDefinitionId] uniqueidentifier NULL,
        [RuleOutputDefinitionId] uniqueidentifier NULL,
        [ConstraintKindCode] varchar(32) NOT NULL,
        [NumericPrecision] tinyint NULL,
        [NumericScale] tinyint NULL,
        [MaximumTextLength] int NULL,
        [ElementValueTypeId] uniqueidentifier NULL,
        [MinimumCardinality] int NULL,
        [MaximumCardinality] int NULL,
        [CollectionShapeCode] nvarchar(128) NULL,
        [DeclaredContractTypeCode] nvarchar(256) NULL,
        [DomainConstraintCode] nvarchar(256) NULL,
        [ContractText] nvarchar(max) NULL,
        CONSTRAINT [PK_RuleValueConstraint] PRIMARY KEY ([RuleValueConstraintId]),
        CONSTRAINT [FK_RuleValueConstraint_Input] FOREIGN KEY ([RuleInputDefinitionId])
            REFERENCES [ATAPUtilities].[RuleInputDefinition] ([RuleInputDefinitionId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_RuleValueConstraint_Output] FOREIGN KEY ([RuleOutputDefinitionId])
            REFERENCES [ATAPUtilities].[RuleOutputDefinition] ([RuleOutputDefinitionId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_RuleValueConstraint_ElementType] FOREIGN KEY ([ElementValueTypeId])
            REFERENCES [ATAPUtilities].[ValueType] ([ValueTypeId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [CK_RuleValueConstraint_OneOwner]
            CHECK (([RuleInputDefinitionId] IS NULL AND [RuleOutputDefinitionId] IS NOT NULL)
                OR ([RuleInputDefinitionId] IS NOT NULL AND [RuleOutputDefinitionId] IS NULL)),
        CONSTRAINT [CK_RuleValueConstraint_Kind]
            CHECK ([ConstraintKindCode] IN ('PrecisionScale','TextLength','ElementType','CardinalityShape','DeclaredContract','DeclaredDomain','ContractText')),
        CONSTRAINT [CK_RuleValueConstraint_Precision]
            CHECK ([NumericPrecision] IS NULL OR ([NumericPrecision] BETWEEN 1 AND 38 AND [NumericScale] BETWEEN 0 AND [NumericPrecision])),
        CONSTRAINT [CK_RuleValueConstraint_TextLength] CHECK ([MaximumTextLength] IS NULL OR [MaximumTextLength] > 0),
        CONSTRAINT [CK_RuleValueConstraint_Cardinality]
            CHECK (([MinimumCardinality] IS NULL OR [MinimumCardinality] >= 0)
               AND ([MaximumCardinality] IS NULL OR [MaximumCardinality] >= [MinimumCardinality])),
        CONSTRAINT [CK_RuleValueConstraint_RequiredPayload]
            CHECK (([ConstraintKindCode]='PrecisionScale' AND [NumericPrecision] IS NOT NULL AND [NumericScale] IS NOT NULL
                    AND [MaximumTextLength] IS NULL AND [ElementValueTypeId] IS NULL AND [MinimumCardinality] IS NULL
                    AND [MaximumCardinality] IS NULL AND [CollectionShapeCode] IS NULL AND [DeclaredContractTypeCode] IS NULL
                    AND [DomainConstraintCode] IS NULL AND [ContractText] IS NULL)
                OR ([ConstraintKindCode]='TextLength' AND [MaximumTextLength] IS NOT NULL
                    AND [NumericPrecision] IS NULL AND [NumericScale] IS NULL AND [ElementValueTypeId] IS NULL
                    AND [MinimumCardinality] IS NULL AND [MaximumCardinality] IS NULL AND [CollectionShapeCode] IS NULL
                    AND [DeclaredContractTypeCode] IS NULL AND [DomainConstraintCode] IS NULL AND [ContractText] IS NULL)
                OR ([ConstraintKindCode]='ElementType' AND [ElementValueTypeId] IS NOT NULL
                    AND [NumericPrecision] IS NULL AND [NumericScale] IS NULL AND [MaximumTextLength] IS NULL
                    AND [MinimumCardinality] IS NULL AND [MaximumCardinality] IS NULL AND [CollectionShapeCode] IS NULL
                    AND [DeclaredContractTypeCode] IS NULL AND [DomainConstraintCode] IS NULL AND [ContractText] IS NULL)
                OR ([ConstraintKindCode]='CardinalityShape' AND [MinimumCardinality] IS NOT NULL AND [CollectionShapeCode] IS NOT NULL AND DATALENGTH([CollectionShapeCode]) > 0
                    AND [NumericPrecision] IS NULL AND [NumericScale] IS NULL AND [MaximumTextLength] IS NULL
                    AND [ElementValueTypeId] IS NULL AND [DeclaredContractTypeCode] IS NULL
                    AND [DomainConstraintCode] IS NULL AND [ContractText] IS NULL)
                OR ([ConstraintKindCode]='DeclaredContract' AND [DeclaredContractTypeCode] IS NOT NULL AND DATALENGTH([DeclaredContractTypeCode]) > 0
                    AND [NumericPrecision] IS NULL AND [NumericScale] IS NULL AND [MaximumTextLength] IS NULL
                    AND [ElementValueTypeId] IS NULL AND [MinimumCardinality] IS NULL AND [MaximumCardinality] IS NULL
                    AND [CollectionShapeCode] IS NULL AND [DomainConstraintCode] IS NULL AND [ContractText] IS NULL)
                OR ([ConstraintKindCode]='DeclaredDomain' AND [DomainConstraintCode] IS NOT NULL AND DATALENGTH([DomainConstraintCode]) > 0
                    AND [NumericPrecision] IS NULL AND [NumericScale] IS NULL AND [MaximumTextLength] IS NULL
                    AND [ElementValueTypeId] IS NULL AND [MinimumCardinality] IS NULL AND [MaximumCardinality] IS NULL
                    AND [CollectionShapeCode] IS NULL AND [DeclaredContractTypeCode] IS NULL AND [ContractText] IS NULL)
                OR ([ConstraintKindCode]='ContractText' AND [ContractText] IS NOT NULL AND DATALENGTH([ContractText]) > 0
                    AND [NumericPrecision] IS NULL AND [NumericScale] IS NULL AND [MaximumTextLength] IS NULL
                    AND [ElementValueTypeId] IS NULL AND [MinimumCardinality] IS NULL AND [MaximumCardinality] IS NULL
                    AND [CollectionShapeCode] IS NULL AND [DeclaredContractTypeCode] IS NULL AND [DomainConstraintCode] IS NULL))
    );
    CREATE UNIQUE INDEX [UX_RuleValueConstraint_Input_Kind]
        ON [ATAPUtilities].[RuleValueConstraint] ([RuleInputDefinitionId], [ConstraintKindCode])
        WHERE [RuleInputDefinitionId] IS NOT NULL;
    CREATE UNIQUE INDEX [UX_RuleValueConstraint_Output_Kind]
        ON [ATAPUtilities].[RuleValueConstraint] ([RuleOutputDefinitionId], [ConstraintKindCode])
        WHERE [RuleOutputDefinitionId] IS NOT NULL;

    CREATE TABLE [ATAPUtilities].[RuleVariant]
    (
        [RuleVariantId] uniqueidentifier NOT NULL,
        [PhiloteId] uniqueidentifier NOT NULL,
        [RuleId] uniqueidentifier NOT NULL,
        [OwningRuleSetId] uniqueidentifier NOT NULL,
        [RuleVariantCode] nvarchar(128) NOT NULL,
        CONSTRAINT [PK_RuleVariant] PRIMARY KEY ([RuleVariantId]),
        CONSTRAINT [FK_RuleVariant_Philote] FOREIGN KEY ([PhiloteId])
            REFERENCES [ATAPUtilities].[Philote] ([PhiloteId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_RuleVariant_Rule] FOREIGN KEY ([RuleId])
            REFERENCES [ATAPUtilities].[Rule] ([RuleId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_RuleVariant_OwningRuleSet] FOREIGN KEY ([OwningRuleSetId])
            REFERENCES [ATAPUtilities].[RuleSet] ([RuleSetId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_RuleVariant_Philote] UNIQUE ([PhiloteId]),
        CONSTRAINT [UQ_RuleVariant_Owner_Code] UNIQUE ([OwningRuleSetId], [RuleVariantCode]),
        CONSTRAINT [UQ_RuleVariant_Id_Owner] UNIQUE ([RuleVariantId], [OwningRuleSetId]),
        CONSTRAINT [UQ_RuleVariant_Id_Rule] UNIQUE ([RuleVariantId], [RuleId]),
        CONSTRAINT [CK_RuleVariant_Philote_Equals_Id] CHECK ([RuleVariantId] = [PhiloteId]),
        CONSTRAINT [CK_RuleVariant_Code_NotEmpty] CHECK (DATALENGTH([RuleVariantCode]) > 0)
    );

    CREATE TABLE [ATAPUtilities].[RuleVariantState]
    (
        [RuleVariantStateId] uniqueidentifier NOT NULL,
        [RuleVariantId] uniqueidentifier NOT NULL,
        [ValidFromUtc] datetime2(7) NOT NULL,
        [ValidToUtc] datetime2(7) NULL,
        [Purpose] nvarchar(1024) NOT NULL,
        [ExecutorContractCode] nvarchar(128) NOT NULL,
        [NormalizedBody] nvarchar(max) NOT NULL,
        [LifecycleStatusCode] varchar(16) NOT NULL,
        CONSTRAINT [PK_RuleVariantState] PRIMARY KEY ([RuleVariantStateId]),
        CONSTRAINT [FK_RuleVariantState_Variant] FOREIGN KEY ([RuleVariantId])
            REFERENCES [ATAPUtilities].[RuleVariant] ([RuleVariantId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_RuleVariantState_From] UNIQUE ([RuleVariantId], [ValidFromUtc]),
        CONSTRAINT [CK_RuleVariantState_Period] CHECK ([ValidToUtc] IS NULL OR [ValidFromUtc] < [ValidToUtc]),
        CONSTRAINT [CK_RuleVariantState_Purpose] CHECK (DATALENGTH([Purpose]) > 0),
        CONSTRAINT [CK_RuleVariantState_Executor] CHECK (DATALENGTH([ExecutorContractCode]) > 0),
        CONSTRAINT [CK_RuleVariantState_Body] CHECK (DATALENGTH([NormalizedBody]) > 0),
        CONSTRAINT [CK_RuleVariantState_Lifecycle] CHECK ([LifecycleStatusCode] IN ('Draft','Active','Retired'))
    );
    CREATE UNIQUE INDEX [UX_RuleVariantState_Current]
        ON [ATAPUtilities].[RuleVariantState] ([RuleVariantId]) WHERE [ValidToUtc] IS NULL;

    CREATE TABLE [ATAPUtilities].[RuleVariantInputDefinition]
    (
        [RuleVariantId] uniqueidentifier NOT NULL,
        [RuleInputDefinitionId] uniqueidentifier NOT NULL,
        [RuleId] uniqueidentifier NOT NULL,
        [InputCode] nvarchar(128) NOT NULL,
        [Ordinal] int NOT NULL,
        CONSTRAINT [PK_RuleVariantInputDefinition] PRIMARY KEY ([RuleVariantId], [RuleInputDefinitionId]),
        CONSTRAINT [FK_RuleVariantInputDefinition_VariantRule]
            FOREIGN KEY ([RuleVariantId], [RuleId])
            REFERENCES [ATAPUtilities].[RuleVariant] ([RuleVariantId], [RuleId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_RuleVariantInputDefinition_RegisteredDefinition]
            FOREIGN KEY ([RuleInputDefinitionId], [RuleId], [InputCode], [Ordinal])
            REFERENCES [ATAPUtilities].[RuleInputDefinition]
                ([RuleInputDefinitionId], [RuleId], [InputCode], [Ordinal]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_RuleVariantInputDefinition_Code] UNIQUE ([RuleVariantId], [InputCode]),
        CONSTRAINT [UQ_RuleVariantInputDefinition_Ordinal] UNIQUE ([RuleVariantId], [Ordinal])
    );

    CREATE TABLE [ATAPUtilities].[RuleVariantOutputDefinition]
    (
        [RuleVariantId] uniqueidentifier NOT NULL,
        [RuleOutputDefinitionId] uniqueidentifier NOT NULL,
        [RuleId] uniqueidentifier NOT NULL,
        [OutputCode] nvarchar(128) NOT NULL,
        [Ordinal] int NOT NULL,
        CONSTRAINT [PK_RuleVariantOutputDefinition] PRIMARY KEY ([RuleVariantId], [RuleOutputDefinitionId]),
        CONSTRAINT [FK_RuleVariantOutputDefinition_VariantRule]
            FOREIGN KEY ([RuleVariantId], [RuleId])
            REFERENCES [ATAPUtilities].[RuleVariant] ([RuleVariantId], [RuleId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_RuleVariantOutputDefinition_RegisteredDefinition]
            FOREIGN KEY ([RuleOutputDefinitionId], [RuleId], [OutputCode], [Ordinal])
            REFERENCES [ATAPUtilities].[RuleOutputDefinition]
                ([RuleOutputDefinitionId], [RuleId], [OutputCode], [Ordinal]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_RuleVariantOutputDefinition_Code] UNIQUE ([RuleVariantId], [OutputCode]),
        CONSTRAINT [UQ_RuleVariantOutputDefinition_Ordinal] UNIQUE ([RuleVariantId], [Ordinal])
    );

    CREATE TABLE [ATAPUtilities].[RuleSetMembershipRole]
    (
        [RuleSetMembershipRoleCode] varchar(16) NOT NULL,
        CONSTRAINT [PK_RuleSetMembershipRole] PRIMARY KEY ([RuleSetMembershipRoleCode]),
        CONSTRAINT [CK_RuleSetMembershipRole_Code] CHECK ([RuleSetMembershipRoleCode] IN ('Add','Override','Suppress'))
    );
    INSERT INTO [ATAPUtilities].[RuleSetMembershipRole] ([RuleSetMembershipRoleCode])
        VALUES ('Add'), ('Override'), ('Suppress');

    CREATE TABLE [ATAPUtilities].[RuleSetRuleOccurrence]
    (
        [RuleSetRuleOccurrenceId] uniqueidentifier NOT NULL,
        [RuleSetId] uniqueidentifier NOT NULL,
        [RuleVariantId] uniqueidentifier NOT NULL,
        [RuleSetMembershipRoleCode] varchar(16) NOT NULL,
        [Ordinal] int NOT NULL,
        [ConditionExpression] nvarchar(2048) NULL,
        [ValidFromUtc] datetime2(7) NOT NULL,
        [ValidToUtc] datetime2(7) NULL,
        CONSTRAINT [PK_RuleSetRuleOccurrence] PRIMARY KEY ([RuleSetRuleOccurrenceId]),
        CONSTRAINT [FK_RuleSetRuleOccurrence_OwnedVariant] FOREIGN KEY ([RuleVariantId], [RuleSetId])
            REFERENCES [ATAPUtilities].[RuleVariant] ([RuleVariantId], [OwningRuleSetId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_RuleSetRuleOccurrence_Role] FOREIGN KEY ([RuleSetMembershipRoleCode])
            REFERENCES [ATAPUtilities].[RuleSetMembershipRole] ([RuleSetMembershipRoleCode]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_RuleSetRuleOccurrence_Ordinal] UNIQUE ([RuleSetId], [Ordinal]),
        CONSTRAINT [CK_RuleSetRuleOccurrence_Ordinal] CHECK ([Ordinal] >= 0),
        CONSTRAINT [CK_RuleSetRuleOccurrence_Period] CHECK ([ValidToUtc] IS NULL OR [ValidFromUtc] < [ValidToUtc])
    );

    CREATE TABLE [ATAPUtilities].[BuildSetRuleSetOccurrence]
    (
        [BuildSetRuleSetOccurrenceId] uniqueidentifier NOT NULL,
        [BuildSetId] uniqueidentifier NOT NULL,
        [RuleSetId] uniqueidentifier NOT NULL,
        [Ordinal] int NOT NULL,
        [ConditionExpression] nvarchar(2048) NULL,
        [ValidFromUtc] datetime2(7) NOT NULL,
        [ValidToUtc] datetime2(7) NULL,
        CONSTRAINT [PK_BuildSetRuleSetOccurrence] PRIMARY KEY ([BuildSetRuleSetOccurrenceId]),
        CONSTRAINT [FK_BuildSetRuleSetOccurrence_BuildSet] FOREIGN KEY ([BuildSetId])
            REFERENCES [ATAPUtilities].[BuildSet] ([BuildSetId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [FK_BuildSetRuleSetOccurrence_RuleSet] FOREIGN KEY ([RuleSetId])
            REFERENCES [ATAPUtilities].[RuleSet] ([RuleSetId]) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT [UQ_BuildSetRuleSetOccurrence_Ordinal] UNIQUE ([BuildSetId], [Ordinal]),
        CONSTRAINT [CK_BuildSetRuleSetOccurrence_Ordinal] CHECK ([Ordinal] >= 0),
        CONSTRAINT [CK_BuildSetRuleSetOccurrence_Period] CHECK ([ValidToUtc] IS NULL OR [ValidFromUtc] < [ValidToUtc])
    );

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_Rule_SemanticIdentity_Immutable]
ON [ATAPUtilities].[Rule] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 58013, ''Rule semantic identity is immutable; create a replacement Rule graph.'', 1; END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_ValueType_Immutable]
ON [ATAPUtilities].[ValueType] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 58014, ''ValueType semantics are immutable; register a new ValueType.'', 1; END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_InputNormalizationContract_Immutable]
ON [ATAPUtilities].[InputNormalizationContract] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 58015, ''InputNormalizationContract is immutable; register a new contract.'', 1; END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_RuleInputDefinition_Immutable]
ON [ATAPUtilities].[RuleInputDefinition] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 58010, ''RuleInputDefinition is immutable; create a new definition.'', 1; END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_RuleOutputDefinition_Immutable]
ON [ATAPUtilities].[RuleOutputDefinition] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 58011, ''RuleOutputDefinition is immutable; create a new definition.'', 1; END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_RuleVariant_Immutable]
ON [ATAPUtilities].[RuleVariant] AFTER UPDATE, DELETE AS
BEGIN SET NOCOUNT ON; THROW 58012, ''RuleVariant identity and owning RuleSet are immutable; create a new variant.'', 1; END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_RuleValueConstraint_Frozen]
ON [ATAPUtilities].[RuleValueConstraint] AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 58016, ''RuleValueConstraint is immutable; create a replacement definition.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM inserted i
        WHERE (i.RuleInputDefinitionId IS NOT NULL AND EXISTS
               (SELECT 1 FROM [ATAPUtilities].[RuleVariantInputDefinition] b
                WHERE b.RuleInputDefinitionId=i.RuleInputDefinitionId))
           OR (i.RuleOutputDefinitionId IS NOT NULL AND EXISTS
               (SELECT 1 FROM [ATAPUtilities].[RuleVariantOutputDefinition] b
                WHERE b.RuleOutputDefinitionId=i.RuleOutputDefinitionId))
    )
        THROW 58018, ''Constraints cannot be added after a definition is bound to a RuleVariant.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_RuleVariantInputDefinition_Immutable]
ON [ATAPUtilities].[RuleVariantInputDefinition] AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 58034, ''RuleVariant input-definition bindings are immutable.'', 1;
    IF EXISTS (SELECT 1 FROM inserted i
               WHERE EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVariantState] s WHERE s.RuleVariantId=i.RuleVariantId)
                  OR EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleSetRuleOccurrence] o WHERE o.RuleVariantId=i.RuleVariantId))
        THROW 58038, ''Input definitions must be completely bound before variant state or occurrence history exists.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_RuleVariantOutputDefinition_Immutable]
ON [ATAPUtilities].[RuleVariantOutputDefinition] AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 58035, ''RuleVariant output-definition bindings are immutable.'', 1;
    IF EXISTS (SELECT 1 FROM inserted i
               WHERE EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleVariantState] s WHERE s.RuleVariantId=i.RuleVariantId)
                  OR EXISTS (SELECT 1 FROM [ATAPUtilities].[RuleSetRuleOccurrence] o WHERE o.RuleVariantId=i.RuleVariantId))
        THROW 58039, ''Output definitions must be completely bound before variant state or occurrence history exists.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_RuleInputDefinitionState_History]
ON [ATAPUtilities].[RuleInputDefinitionState] AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted) AND
       (NOT EXISTS (SELECT 1 FROM inserted) OR UPDATE(RuleInputDefinitionStateId) OR UPDATE(RuleInputDefinitionId)
        OR UPDATE(ValidFromUtc) OR UPDATE(DisplayName) OR UPDATE(Description)
        OR EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.RuleInputDefinitionStateId=i.RuleInputDefinitionStateId
                   WHERE d.ValidToUtc IS NOT NULL OR i.ValidToUtc IS NULL))
        THROW 58030, ''Input definition state history is append-only; only an open period may be closed.'', 1;
    IF EXISTS (SELECT 1 FROM inserted i JOIN [ATAPUtilities].[RuleInputDefinitionState] e
               ON e.RuleInputDefinitionId=i.RuleInputDefinitionId AND e.RuleInputDefinitionStateId<>i.RuleInputDefinitionStateId
              WHERE i.ValidFromUtc<COALESCE(e.ValidToUtc,CONVERT(datetime2(7),''9999-12-31T23:59:59.9999999''))
                AND e.ValidFromUtc<COALESCE(i.ValidToUtc,CONVERT(datetime2(7),''9999-12-31T23:59:59.9999999'')))
        THROW 58040, ''Input definition state periods may not overlap.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_RuleOutputDefinitionState_History]
ON [ATAPUtilities].[RuleOutputDefinitionState] AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted) AND
       (NOT EXISTS (SELECT 1 FROM inserted) OR UPDATE(RuleOutputDefinitionStateId) OR UPDATE(RuleOutputDefinitionId)
        OR UPDATE(ValidFromUtc) OR UPDATE(DisplayName) OR UPDATE(Description)
        OR EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.RuleOutputDefinitionStateId=i.RuleOutputDefinitionStateId
                   WHERE d.ValidToUtc IS NOT NULL OR i.ValidToUtc IS NULL))
        THROW 58031, ''Output definition state history is append-only; only an open period may be closed.'', 1;
    IF EXISTS (SELECT 1 FROM inserted i JOIN [ATAPUtilities].[RuleOutputDefinitionState] e
               ON e.RuleOutputDefinitionId=i.RuleOutputDefinitionId AND e.RuleOutputDefinitionStateId<>i.RuleOutputDefinitionStateId
              WHERE i.ValidFromUtc<COALESCE(e.ValidToUtc,CONVERT(datetime2(7),''9999-12-31T23:59:59.9999999''))
                AND e.ValidFromUtc<COALESCE(i.ValidToUtc,CONVERT(datetime2(7),''9999-12-31T23:59:59.9999999'')))
        THROW 58041, ''Output definition state periods may not overlap.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_RuleDefaultInputValue_History]
ON [ATAPUtilities].[RuleDefaultInputValue] AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted) AND
       (NOT EXISTS (SELECT 1 FROM inserted) OR UPDATE(RuleDefaultInputValueId) OR UPDATE(RuleInputDefinitionId)
        OR UPDATE(ValueTypeId) OR UPDATE(StorageKindCode) OR UPDATE(ValidFromUtc) OR UPDATE(BitValue)
        OR UPDATE(Int64Value) OR UPDATE(DecimalValue) OR UPDATE(TextValue) OR UPDATE(GuidValue)
        OR UPDATE(DateTimeUtcValue) OR UPDATE(DurationTicksValue) OR UPDATE(JsonValue)
        OR EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.RuleDefaultInputValueId=i.RuleDefaultInputValueId
                   WHERE d.ValidToUtc IS NOT NULL OR i.ValidToUtc IS NULL))
        THROW 58032, ''Default value history is append-only; only an open period may be closed.'', 1;
    IF EXISTS (SELECT 1 FROM inserted i JOIN [ATAPUtilities].[RuleDefaultInputValue] e
               ON e.RuleInputDefinitionId=i.RuleInputDefinitionId AND e.RuleDefaultInputValueId<>i.RuleDefaultInputValueId
              WHERE i.ValidFromUtc<COALESCE(e.ValidToUtc,CONVERT(datetime2(7),''9999-12-31T23:59:59.9999999''))
                AND e.ValidFromUtc<COALESCE(i.ValidToUtc,CONVERT(datetime2(7),''9999-12-31T23:59:59.9999999'')))
        THROW 58042, ''Default value periods may not overlap.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_RuleVariantState_History]
ON [ATAPUtilities].[RuleVariantState] AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted) AND
       (NOT EXISTS (SELECT 1 FROM inserted) OR UPDATE(RuleVariantStateId) OR UPDATE(RuleVariantId)
        OR UPDATE(ValidFromUtc) OR UPDATE(Purpose) OR UPDATE(ExecutorContractCode)
        OR UPDATE(NormalizedBody) OR UPDATE(LifecycleStatusCode)
        OR EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.RuleVariantStateId=i.RuleVariantStateId
                   WHERE d.ValidToUtc IS NOT NULL OR i.ValidToUtc IS NULL))
        THROW 58033, ''RuleVariant state history is append-only; only an open period may be closed.'', 1;
    IF EXISTS (SELECT 1 FROM inserted i JOIN [ATAPUtilities].[RuleVariantState] e
               ON e.RuleVariantId=i.RuleVariantId AND e.RuleVariantStateId<>i.RuleVariantStateId
              WHERE i.ValidFromUtc<COALESCE(e.ValidToUtc,CONVERT(datetime2(7),''9999-12-31T23:59:59.9999999''))
                AND e.ValidFromUtc<COALESCE(i.ValidToUtc,CONVERT(datetime2(7),''9999-12-31T23:59:59.9999999'')))
        THROW 58043, ''RuleVariant state periods may not overlap.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_RuleSetRuleOccurrence_History]
ON [ATAPUtilities].[RuleSetRuleOccurrence] AFTER UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) OR UPDATE(RuleSetRuleOccurrenceId) OR UPDATE(RuleSetId)
       OR UPDATE(RuleVariantId) OR UPDATE(RuleSetMembershipRoleCode) OR UPDATE(Ordinal)
       OR UPDATE(ConditionExpression) OR UPDATE(ValidFromUtc)
       OR EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.RuleSetRuleOccurrenceId=i.RuleSetRuleOccurrenceId
                  WHERE d.ValidToUtc IS NOT NULL OR i.ValidToUtc IS NULL)
        THROW 58036, ''RuleSet occurrence history is append-only; only an open period may be closed.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE TRIGGER [ATAPUtilities].[TR_BuildSetRuleSetOccurrence_History]
ON [ATAPUtilities].[BuildSetRuleSetOccurrence] AFTER UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) OR UPDATE(BuildSetRuleSetOccurrenceId) OR UPDATE(BuildSetId)
       OR UPDATE(RuleSetId) OR UPDATE(Ordinal) OR UPDATE(ConditionExpression) OR UPDATE(ValidFromUtc)
       OR EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.BuildSetRuleSetOccurrenceId=i.BuildSetRuleSetOccurrenceId
                  WHERE d.ValidToUtc IS NOT NULL OR i.ValidToUtc IS NULL)
        THROW 58037, ''BuildSet occurrence history is append-only; only an open period may be closed.'', 1;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[ResolveBuildSetRulesAsOf]
        @BuildSetId uniqueidentifier,
        @AsOfUtc datetime2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @BuildSetId IS NULL OR @AsOfUtc IS NULL
        THROW 58020, ''BuildSetId and AsOfUtc are required.'', 1;
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[BuildSet] WHERE [BuildSetId]=@BuildSetId)
        THROW 58021, ''BuildSet does not exist.'', 1;

    SELECT bo.[BuildSetRuleSetOccurrenceId], bo.[BuildSetId], bo.[RuleSetId], bo.[Ordinal] AS [BuildSetOrdinal],
           ro.[RuleSetRuleOccurrenceId], ro.[Ordinal] AS [RuleSetOrdinal], ro.[RuleSetMembershipRoleCode],
           rv.[RuleVariantId], rv.[RuleId], rvs.[RuleVariantStateId],
           ROW_NUMBER() OVER (PARTITION BY rv.[RuleId]
                              ORDER BY bo.[Ordinal] DESC, ro.[Ordinal] ASC,
                                       bo.[BuildSetRuleSetOccurrenceId], ro.[RuleSetRuleOccurrenceId]) AS [PrecedenceRank]
    INTO #Candidates
    FROM [ATAPUtilities].[BuildSetRuleSetOccurrence] bo
    JOIN [ATAPUtilities].[RuleSetRuleOccurrence] ro ON ro.[RuleSetId]=bo.[RuleSetId]
    JOIN [ATAPUtilities].[RuleVariant] rv ON rv.[RuleVariantId]=ro.[RuleVariantId] AND rv.[OwningRuleSetId]=ro.[RuleSetId]
    JOIN [ATAPUtilities].[RuleVariantState] rvs ON rvs.[RuleVariantId]=rv.[RuleVariantId]
    WHERE bo.[BuildSetId]=@BuildSetId
      AND bo.[ConditionExpression] IS NULL AND ro.[ConditionExpression] IS NULL
      AND bo.[ValidFromUtc]<=@AsOfUtc AND (bo.[ValidToUtc] IS NULL OR @AsOfUtc<bo.[ValidToUtc])
      AND ro.[ValidFromUtc]<=@AsOfUtc AND (ro.[ValidToUtc] IS NULL OR @AsOfUtc<ro.[ValidToUtc])
      AND rvs.[ValidFromUtc]<=@AsOfUtc AND (rvs.[ValidToUtc] IS NULL OR @AsOfUtc<rvs.[ValidToUtc])
      AND rvs.[LifecycleStatusCode]=''Active'';

    IF EXISTS
    (
        SELECT 1 FROM #Candidates c
        WHERE c.[RuleSetMembershipRoleCode] IN (''Override'',''Suppress'')
          AND NOT EXISTS (SELECT 1 FROM #Candidates lowerCandidate
                          WHERE lowerCandidate.[RuleId]=c.[RuleId]
                            AND lowerCandidate.[PrecedenceRank]>c.[PrecedenceRank])
    )
        THROW 58022, ''Override and Suppress require a lower-precedence baseline with the same RuleId.'', 1;

    IF EXISTS
    (
        SELECT 1 FROM #Candidates c
        WHERE c.[RuleSetMembershipRoleCode]=''Add''
          AND EXISTS (SELECT 1 FROM #Candidates lowerCandidate
                      WHERE lowerCandidate.[RuleId]=c.[RuleId]
                        AND lowerCandidate.[PrecedenceRank]>c.[PrecedenceRank])
    )
        THROW 58023, ''Add collides with a lower-precedence candidate for the same RuleId.'', 1;

    SELECT c.[RuleId], c.[RuleVariantId], c.[RuleVariantStateId], c.[RuleSetMembershipRoleCode],
           CASE WHEN c.[PrecedenceRank]=1 AND c.[RuleSetMembershipRoleCode]=''Suppress'' THEN ''Suppressed''
                WHEN c.[PrecedenceRank]=1 THEN ''Selected'' ELSE ''Shadowed'' END AS [ResolutionDisposition],
           c.[PrecedenceRank], c.[BuildSetId], c.[BuildSetRuleSetOccurrenceId], c.[BuildSetOrdinal],
           c.[RuleSetId], c.[RuleSetRuleOccurrenceId], c.[RuleSetOrdinal]
    FROM #Candidates c
    ORDER BY c.[RuleId], c.[PrecedenceRank];
END;';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

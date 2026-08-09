/*
  ATAPUtilities consolidated initial schema and seed baseline.

  This reset-lineage migration preserves the approved RPRRSBSI V3 graph while
  replacing TimeBlock with the PTV-G0-ratified PhiloteValidityPeriod contract.
  It intentionally performs no database creation, USE, principal creation,
  Flyway-history mutation, schema drop, package publication, or deployment.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF SCHEMA_ID(N'ATAPUtilities') IS NULL
    BEGIN
        EXEC sys.sp_executesql N'CREATE SCHEMA [ATAPUtilities] AUTHORIZATION [dbo];';
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[Philote]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[Philote]
        (
            [PhiloteId] uniqueidentifier NOT NULL,
            [AdditionalIdsStub] nvarchar(max) NULL,
            CONSTRAINT [PK_Philote]
                PRIMARY KEY ([PhiloteId]),
            CONSTRAINT [CK_Philote_AdditionalIdsStubIsNull]
                CHECK ([AdditionalIdsStub] IS NULL)
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[PhiloteValidityPeriod]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[PhiloteValidityPeriod]
        (
            [PhiloteValidityPeriodId] uniqueidentifier NOT NULL,
            [PhiloteId] uniqueidentifier NOT NULL,
            [PreviousValidToUtc] datetime2(7) NULL,
            [ValidFromUtc] datetime2(7) NOT NULL,
            [ValidToUtc] datetime2(7) NULL,
            CONSTRAINT [PK_PhiloteValidityPeriod]
                PRIMARY KEY ([PhiloteValidityPeriodId]),
            CONSTRAINT [FK_PhiloteValidityPeriod_Philote]
                FOREIGN KEY ([PhiloteId])
                REFERENCES [ATAPUtilities].[Philote] ([PhiloteId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [CK_PhiloteValidityPeriod_NonEmpty]
                CHECK ([ValidToUtc] IS NULL OR [ValidFromUtc] < [ValidToUtc]),
            CONSTRAINT [CK_PhiloteValidityPeriod_PredecessorNotAfterStart]
                CHECK ([PreviousValidToUtc] IS NULL OR [PreviousValidToUtc] <= [ValidFromUtc]),
            CONSTRAINT [UQ_PhiloteValidityPeriod_Philote_ValidFromUtc]
                UNIQUE ([PhiloteId], [ValidFromUtc]),
            CONSTRAINT [UQ_PhiloteValidityPeriod_Philote_ValidToUtc]
                UNIQUE ([PhiloteId], [ValidToUtc]),
            CONSTRAINT [UQ_PhiloteValidityPeriod_Philote_PreviousValidToUtc]
                UNIQUE ([PhiloteId], [PreviousValidToUtc]),
            CONSTRAINT [FK_PhiloteValidityPeriod_Predecessor]
                FOREIGN KEY ([PhiloteId], [PreviousValidToUtc])
                REFERENCES [ATAPUtilities].[PhiloteValidityPeriod] ([PhiloteId], [ValidToUtc])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION
        );
    END;
    IF OBJECT_ID(N'[ATAPUtilities].[RuleKind]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[RuleKind]
        (
            [RuleKindId] uniqueidentifier NOT NULL,
            [PhiloteId] uniqueidentifier NOT NULL,
            [RuleKindCode] varchar(64) NOT NULL,
            [RuleKindName] nvarchar(128) NOT NULL,
            CONSTRAINT [PK_RuleKind]
                PRIMARY KEY ([RuleKindId]),
            CONSTRAINT [FK_RuleKind_Philote]
                FOREIGN KEY ([PhiloteId])
                REFERENCES [ATAPUtilities].[Philote] ([PhiloteId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [UQ_RuleKind_Philote]
                UNIQUE ([PhiloteId]),
            CONSTRAINT [UQ_RuleKind_Code]
                UNIQUE ([RuleKindCode]),
            CONSTRAINT [UQ_RuleKind_Name]
                UNIQUE ([RuleKindName]),
            CONSTRAINT [CK_RuleKind_Philote_Equals_Id]
                CHECK ([RuleKindId] = [PhiloteId]),
            CONSTRAINT [CK_RuleKind_Code_NotEmpty]
                CHECK (DATALENGTH([RuleKindCode]) > 0),
            CONSTRAINT [CK_RuleKind_Name_NotEmpty]
                CHECK (DATALENGTH([RuleKindName]) > 0)
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[RulePrimitive]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[RulePrimitive]
        (
            [RulePrimitiveId] uniqueidentifier NOT NULL,
            [PhiloteId] uniqueidentifier NOT NULL,
            [RuleKindId] uniqueidentifier NOT NULL,
            [RulePrimitiveCode] nvarchar(128) NOT NULL,
            CONSTRAINT [PK_RulePrimitive]
                PRIMARY KEY ([RulePrimitiveId]),
            CONSTRAINT [FK_RulePrimitive_Philote]
                FOREIGN KEY ([PhiloteId])
                REFERENCES [ATAPUtilities].[Philote] ([PhiloteId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [FK_RulePrimitive_RuleKind]
                FOREIGN KEY ([RuleKindId])
                REFERENCES [ATAPUtilities].[RuleKind] ([RuleKindId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [UQ_RulePrimitive_Philote]
                UNIQUE ([PhiloteId]),
            CONSTRAINT [UQ_RulePrimitive_RuleKind_Code]
                UNIQUE ([RuleKindId], [RulePrimitiveCode]),
            CONSTRAINT [UQ_RulePrimitive_Id_RuleKind]
                UNIQUE ([RulePrimitiveId], [RuleKindId]),
            CONSTRAINT [CK_RulePrimitive_Philote_Equals_Id]
                CHECK ([RulePrimitiveId] = [PhiloteId]),
            CONSTRAINT [CK_RulePrimitive_Code_NotEmpty]
                CHECK (DATALENGTH([RulePrimitiveCode]) > 0)
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[RulePrimitiveInput]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[RulePrimitiveInput]
        (
            [RulePrimitiveInputId] uniqueidentifier NOT NULL,
            [RulePrimitiveId] uniqueidentifier NOT NULL,
            [InputName] nvarchar(128) NOT NULL,
            [InputType] nvarchar(256) NOT NULL,
            [InputDescription] nvarchar(1024) NOT NULL,
            [DefaultValue] nvarchar(4000) NULL,
            [IsRequired] bit NOT NULL,
            [Ordinal] int NOT NULL,
            CONSTRAINT [PK_RulePrimitiveInput]
                PRIMARY KEY ([RulePrimitiveInputId]),
            CONSTRAINT [FK_RulePrimitiveInput_RulePrimitive]
                FOREIGN KEY ([RulePrimitiveId])
                REFERENCES [ATAPUtilities].[RulePrimitive] ([RulePrimitiveId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [UQ_RulePrimitiveInput_Name]
                UNIQUE ([RulePrimitiveId], [InputName]),
            CONSTRAINT [UQ_RulePrimitiveInput_Ordinal]
                UNIQUE ([RulePrimitiveId], [Ordinal]),
            CONSTRAINT [CK_RulePrimitiveInput_Name_NotEmpty]
                CHECK (DATALENGTH([InputName]) > 0),
            CONSTRAINT [CK_RulePrimitiveInput_Type_NotEmpty]
                CHECK (DATALENGTH([InputType]) > 0),
            CONSTRAINT [CK_RulePrimitiveInput_Description_NotEmpty]
                CHECK (DATALENGTH([InputDescription]) > 0),
            CONSTRAINT [CK_RulePrimitiveInput_Ordinal_NonNegative]
                CHECK ([Ordinal] >= 0)
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[Rule]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[Rule]
        (
            [RuleId] uniqueidentifier NOT NULL,
            [PhiloteId] uniqueidentifier NOT NULL,
            [RuleKindId] uniqueidentifier NOT NULL,
            [RulePrimitiveId] uniqueidentifier NOT NULL,
            [RuleCode] varchar(128) NOT NULL,
            [RuleBody] nvarchar(max) NOT NULL,
            CONSTRAINT [PK_Rule]
                PRIMARY KEY ([RuleId]),
            CONSTRAINT [FK_Rule_Philote]
                FOREIGN KEY ([PhiloteId])
                REFERENCES [ATAPUtilities].[Philote] ([PhiloteId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [FK_Rule_RuleKind]
                FOREIGN KEY ([RuleKindId])
                REFERENCES [ATAPUtilities].[RuleKind] ([RuleKindId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [FK_Rule_RulePrimitive_MatchingKind]
                FOREIGN KEY ([RulePrimitiveId], [RuleKindId])
                REFERENCES [ATAPUtilities].[RulePrimitive] ([RulePrimitiveId], [RuleKindId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [UQ_Rule_Philote]
                UNIQUE ([PhiloteId]),
            CONSTRAINT [UQ_Rule_RuleKind_Code]
                UNIQUE ([RuleKindId], [RuleCode]),
            CONSTRAINT [CK_Rule_Philote_Equals_Id]
                CHECK ([RuleId] = [PhiloteId]),
            CONSTRAINT [CK_Rule_Code_NotEmpty]
                CHECK (DATALENGTH([RuleCode]) > 0),
            CONSTRAINT [CK_Rule_Body_NotEmpty]
                CHECK (DATALENGTH([RuleBody]) > 0)
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[RuleSet]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[RuleSet]
        (
            [RuleSetId] uniqueidentifier NOT NULL,
            [PhiloteId] uniqueidentifier NOT NULL,
            [RuleSetCode] varchar(128) NOT NULL,
            CONSTRAINT [PK_RuleSet]
                PRIMARY KEY ([RuleSetId]),
            CONSTRAINT [FK_RuleSet_Philote]
                FOREIGN KEY ([PhiloteId])
                REFERENCES [ATAPUtilities].[Philote] ([PhiloteId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [UQ_RuleSet_Philote]
                UNIQUE ([PhiloteId]),
            CONSTRAINT [UQ_RuleSet_Code]
                UNIQUE ([RuleSetCode]),
            CONSTRAINT [CK_RuleSet_Philote_Equals_Id]
                CHECK ([RuleSetId] = [PhiloteId]),
            CONSTRAINT [CK_RuleSet_Code_NotEmpty]
                CHECK (DATALENGTH([RuleSetCode]) > 0)
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[RuleSetRule]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[RuleSetRule]
        (
            [RuleSetId] uniqueidentifier NOT NULL,
            [RuleId] uniqueidentifier NOT NULL,
            [Ordinal] int NOT NULL,
            CONSTRAINT [PK_RuleSetRule]
                PRIMARY KEY ([RuleSetId], [RuleId]),
            CONSTRAINT [FK_RuleSetRule_RuleSet]
                FOREIGN KEY ([RuleSetId])
                REFERENCES [ATAPUtilities].[RuleSet] ([RuleSetId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [FK_RuleSetRule_Rule]
                FOREIGN KEY ([RuleId])
                REFERENCES [ATAPUtilities].[Rule] ([RuleId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [UQ_RuleSetRule_Ordinal]
                UNIQUE ([RuleSetId], [Ordinal]),
            CONSTRAINT [CK_RuleSetRule_Ordinal_NonNegative]
                CHECK ([Ordinal] >= 0)
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[BuildSet]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[BuildSet]
        (
            [BuildSetId] uniqueidentifier NOT NULL,
            [PhiloteId] uniqueidentifier NOT NULL,
            [BuildSetCode] varchar(128) NOT NULL,
            CONSTRAINT [PK_BuildSet]
                PRIMARY KEY ([BuildSetId]),
            CONSTRAINT [FK_BuildSet_Philote]
                FOREIGN KEY ([PhiloteId])
                REFERENCES [ATAPUtilities].[Philote] ([PhiloteId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [UQ_BuildSet_Philote]
                UNIQUE ([PhiloteId]),
            CONSTRAINT [UQ_BuildSet_Code]
                UNIQUE ([BuildSetCode]),
            CONSTRAINT [CK_BuildSet_Philote_Equals_Id]
                CHECK ([BuildSetId] = [PhiloteId]),
            CONSTRAINT [CK_BuildSet_Code_NotEmpty]
                CHECK (DATALENGTH([BuildSetCode]) > 0)
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[BuildSetRuleSet]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[BuildSetRuleSet]
        (
            [BuildSetId] uniqueidentifier NOT NULL,
            [RuleSetId] uniqueidentifier NOT NULL,
            [Ordinal] int NOT NULL,
            CONSTRAINT [PK_BuildSetRuleSet]
                PRIMARY KEY ([BuildSetId], [RuleSetId]),
            CONSTRAINT [FK_BuildSetRuleSet_BuildSet]
                FOREIGN KEY ([BuildSetId])
                REFERENCES [ATAPUtilities].[BuildSet] ([BuildSetId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [FK_BuildSetRuleSet_RuleSet]
                FOREIGN KEY ([RuleSetId])
                REFERENCES [ATAPUtilities].[RuleSet] ([RuleSetId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [UQ_BuildSetRuleSet_Ordinal]
                UNIQUE ([BuildSetId], [Ordinal]),
            CONSTRAINT [CK_BuildSetRuleSet_Ordinal_NonNegative]
                CHECK ([Ordinal] >= 0)
        );
    END;

    IF OBJECT_ID(N'[ATAPUtilities].[Instantiation]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[Instantiation]
        (
            [InstantiationId] uniqueidentifier NOT NULL,
            [PhiloteId] uniqueidentifier NOT NULL,
            [BuildSetId] uniqueidentifier NOT NULL,
            [InstantiationCode] varchar(128) NOT NULL,
            CONSTRAINT [PK_Instantiation]
                PRIMARY KEY ([InstantiationId]),
            CONSTRAINT [FK_Instantiation_Philote]
                FOREIGN KEY ([PhiloteId])
                REFERENCES [ATAPUtilities].[Philote] ([PhiloteId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [FK_Instantiation_BuildSet]
                FOREIGN KEY ([BuildSetId])
                REFERENCES [ATAPUtilities].[BuildSet] ([BuildSetId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [UQ_Instantiation_Philote]
                UNIQUE ([PhiloteId]),
            CONSTRAINT [UQ_Instantiation_Code]
                UNIQUE ([InstantiationCode]),
            CONSTRAINT [CK_Instantiation_Philote_Equals_Id]
                CHECK ([InstantiationId] = [PhiloteId]),
            CONSTRAINT [CK_Instantiation_Code_NotEmpty]
                CHECK (DATALENGTH([InstantiationCode]) > 0)
        );
    END;


    INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId], [AdditionalIdsStub])
    VALUES
        ('8e06f2af-52cf-47d5-872e-0d3912f4fda0', NULL),
        ('b32c60e0-86f3-40e6-893e-d3240ffea882', NULL),
        ('9460f2f5-9957-4455-b6a6-8ee241b7ebb3', NULL),
        ('ff659102-d147-4f1d-bd31-21978858e5fb', NULL),
        ('36696ed7-e4f2-4305-b83e-5deaddd4a279', NULL),
        ('8263f648-2607-452e-ad69-5e4566354cc9', NULL),
        ('f8a27327-cb7a-46f4-bc53-5a2a9945784d', NULL),
        ('03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a', NULL),
        ('9c967a82-098f-4a38-bac5-2be34529ed54', NULL),
        ('250e84cb-abd3-4823-875d-e0e75d88cee3', NULL),
        ('c810abaf-010a-426e-afda-d6881831a9e6', NULL),
        ('197c9963-55d3-4d80-9e39-23f30bf6c57e', NULL),
        ('fa3311ee-3e7c-415a-9eb6-b458c793a675', NULL),
        ('520ade57-f639-45e1-b7de-e5dc3142655c', NULL),
        ('9b2a48bc-7c85-48cd-ac0d-a09d4b621b0a', NULL),
        ('9c8077ce-7abf-4d9a-969b-75631589a220', NULL),
        ('8c3d6e7f-5a4b-4c9d-0e12-3c4d5e6f7081', NULL),
        ('616fb394-0b4d-486a-98af-48f1fe461af2', NULL),
        ('c5c1c63a-4364-4233-9aa1-2a1a5a2ba1f3', NULL),
        ('23ad4f37-2c70-4f34-9104-9868ec0f3823', NULL),
        ('550e7722-cb57-4e47-a94b-9212b451d6fb', NULL),
        ('03e28494-998f-4fc2-ba5d-ad6e5832c8b7', NULL);

    DECLARE @ApprovedPhiloteValidityPeriod TABLE
    (
        [PhiloteValidityPeriodId] uniqueidentifier NOT NULL PRIMARY KEY,
        [PhiloteId] uniqueidentifier NOT NULL UNIQUE,
        [PreviousValidToUtc] datetime2(7) NULL,
        [ValidFromUtc] datetime2(7) NOT NULL,
        [ValidToUtc] datetime2(7) NULL
    );

    INSERT INTO @ApprovedPhiloteValidityPeriod
    (
        [PhiloteValidityPeriodId],
        [PhiloteId],
        [PreviousValidToUtc],
        [ValidFromUtc],
        [ValidToUtc]
    )
    VALUES
        ('593610e7-21e2-5963-9ee5-78884cf66bb3', '8e06f2af-52cf-47d5-872e-0d3912f4fda0', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('f36cbcc7-a7b2-5535-8159-8d3d248258e0', 'b32c60e0-86f3-40e6-893e-d3240ffea882', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('9bf6184c-5bc9-516e-9474-d03e795c3bdd', '9460f2f5-9957-4455-b6a6-8ee241b7ebb3', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('09e5213f-aa30-5702-8e70-bf53f9ecce1b', 'ff659102-d147-4f1d-bd31-21978858e5fb', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('9ae30592-b6ac-5e9a-b186-98ca958a7da8', '36696ed7-e4f2-4305-b83e-5deaddd4a279', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('c2df9ac8-1b37-55ff-a0d0-698bc323a9c9', '8263f648-2607-452e-ad69-5e4566354cc9', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('d81f0221-c994-539e-bfc9-beff669cae9c', 'f8a27327-cb7a-46f4-bc53-5a2a9945784d', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('53184270-16ae-5b72-bc75-9a4dafdf9d75', '03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('fc3c5625-7923-5f3f-bbdf-dc373014e14d', '9c967a82-098f-4a38-bac5-2be34529ed54', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('9e3f90f5-6ba7-55ec-9d32-917233b401c5', '250e84cb-abd3-4823-875d-e0e75d88cee3', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('76b47e27-1170-5eed-b690-8af5e9b69363', 'c810abaf-010a-426e-afda-d6881831a9e6', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('71f8eb3b-fce8-5f11-88a2-b66ad12f9e26', '197c9963-55d3-4d80-9e39-23f30bf6c57e', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('972f58b5-a7f8-5894-9a17-2bf4722f9ee1', 'fa3311ee-3e7c-415a-9eb6-b458c793a675', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('4c6d68c6-3c1a-5b51-8aec-da7fb2ccd7a8', '520ade57-f639-45e1-b7de-e5dc3142655c', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('bdfa134e-b4be-5a3b-867e-7dc11fb68530', '9b2a48bc-7c85-48cd-ac0d-a09d4b621b0a', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('d003f29d-5bc1-5bf6-9643-8f094bd553a3', '9c8077ce-7abf-4d9a-969b-75631589a220', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('7ce930d3-2aa4-5463-b1b8-2777593d12f5', '8c3d6e7f-5a4b-4c9d-0e12-3c4d5e6f7081', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('117890ef-22a2-5203-8b33-b9f2f2c5ba3e', '616fb394-0b4d-486a-98af-48f1fe461af2', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('f43b7c35-de69-5760-bef8-1defce36286e', 'c5c1c63a-4364-4233-9aa1-2a1a5a2ba1f3', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('fc3915e5-c57e-5dbc-a030-bb882d83cad6', '23ad4f37-2c70-4f34-9104-9868ec0f3823', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('65c64d30-04ec-5f85-9d72-a86e015f7e0d', '550e7722-cb57-4e47-a94b-9212b451d6fb', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL),
        ('c22bebda-2395-5a94-be89-a1a12e3d9712', '03e28494-998f-4fc2-ba5d-ad6e5832c8b7', NULL, CONVERT(datetime2(7), '2026-08-08T00:00:00.0000000', 126), NULL);

    INSERT INTO [ATAPUtilities].[PhiloteValidityPeriod]
    (
        [PhiloteValidityPeriodId],
        [PhiloteId],
        [PreviousValidToUtc],
        [ValidFromUtc],
        [ValidToUtc]
    )
    SELECT
        [PhiloteValidityPeriodId],
        [PhiloteId],
        [PreviousValidToUtc],
        [ValidFromUtc],
        [ValidToUtc]
    FROM @ApprovedPhiloteValidityPeriod;

    INSERT INTO [ATAPUtilities].[RuleKind] ([RuleKindId], [PhiloteId], [RuleKindCode], [RuleKindName])
    VALUES
        ('8e06f2af-52cf-47d5-872e-0d3912f4fda0', '8e06f2af-52cf-47d5-872e-0d3912f4fda0', 'PowerShell', N'PowerShell'),
        ('b32c60e0-86f3-40e6-893e-d3240ffea882', 'b32c60e0-86f3-40e6-893e-d3240ffea882', 'Path', N'Path');
    INSERT INTO [ATAPUtilities].[RulePrimitive] ([RulePrimitiveId], [PhiloteId], [RuleKindId], [RulePrimitiveCode])
    VALUES
        ('9460f2f5-9957-4455-b6a6-8ee241b7ebb3', '9460f2f5-9957-4455-b6a6-8ee241b7ebb3', '8e06f2af-52cf-47d5-872e-0d3912f4fda0', N'<complete-powershell-cmdlet>'),
        ('ff659102-d147-4f1d-bd31-21978858e5fb', 'ff659102-d147-4f1d-bd31-21978858e5fb', '8e06f2af-52cf-47d5-872e-0d3912f4fda0', N'<composed-powershell-cmdlet>'),
        ('36696ed7-e4f2-4305-b83e-5deaddd4a279', '36696ed7-e4f2-4305-b83e-5deaddd4a279', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<path>'),
        ('8263f648-2607-452e-ad69-5e4566354cc9', '8263f648-2607-452e-ad69-5e4566354cc9', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<unc-path>'),
        ('f8a27327-cb7a-46f4-bc53-5a2a9945784d', 'f8a27327-cb7a-46f4-bc53-5a2a9945784d', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<absolute-path>'),
        ('03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a', '03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<relative-path>'),
        ('9c967a82-098f-4a38-bac5-2be34529ed54', '9c967a82-098f-4a38-bac5-2be34529ed54', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<extended-path>'),
        ('250e84cb-abd3-4823-875d-e0e75d88cee3', '250e84cb-abd3-4823-875d-e0e75d88cee3', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<drive>'),
        ('c810abaf-010a-426e-afda-d6881831a9e6', 'c810abaf-010a-426e-afda-d6881831a9e6', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<path-tail>'),
        ('197c9963-55d3-4d80-9e39-23f30bf6c57e', '197c9963-55d3-4d80-9e39-23f30bf6c57e', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<name>'),
        ('fa3311ee-3e7c-415a-9eb6-b458c793a675', 'fa3311ee-3e7c-415a-9eb6-b458c793a675', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<namechar>'),
        ('520ade57-f639-45e1-b7de-e5dc3142655c', '520ade57-f639-45e1-b7de-e5dc3142655c', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<server>'),
        ('9b2a48bc-7c85-48cd-ac0d-a09d4b621b0a', '9b2a48bc-7c85-48cd-ac0d-a09d4b621b0a', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<share>'),
        ('9c8077ce-7abf-4d9a-969b-75631589a220', '9c8077ce-7abf-4d9a-969b-75631589a220', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<letter>'),
        ('8c3d6e7f-5a4b-4c9d-0e12-3c4d5e6f7081', '8c3d6e7f-5a4b-4c9d-0e12-3c4d5e6f7081', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<atap-utilities-secrets-csproj-path>');
    INSERT INTO [ATAPUtilities].[RulePrimitiveInput] ([RulePrimitiveInputId], [RulePrimitiveId], [InputName], [InputType], [InputDescription], [DefaultValue], [IsRequired], [Ordinal])
    VALUES
        ('47cec849-5612-4a83-b916-a5ba8d36692b', '36696ed7-e4f2-4305-b83e-5deaddd4a279', N'PathType', N'enum(UNC|Absolute|Relative|Extended)', N'Determines which path variant to render', NULL, 1, 0),
        ('1a7ecff0-b6f4-4481-a9a0-81f298f42cc0', '36696ed7-e4f2-4305-b83e-5deaddd4a279', N'PathContent', N'RulePrimitive', N'Provides the actual path structure selected by PathType', NULL, 1, 1),
        ('7ef564cd-32dd-4319-aeb7-17a02c8a4f0f', '8263f648-2607-452e-ad69-5e4566354cc9', N'Server', N'<server>', N'Provides the network server name or IP address', NULL, 1, 0),
        ('cb3af1f3-e2c1-49fc-9376-a2b3dd41eff5', '8263f648-2607-452e-ad69-5e4566354cc9', N'Share', N'<share>', N'Provides the shared resource name on the server', NULL, 1, 1),
        ('bd8f280b-e7a0-45b0-b8cc-ace4cf3ada0e', '8263f648-2607-452e-ad69-5e4566354cc9', N'PathTail', N'<path-tail>', N'Provides the optional directory or file path within the share', NULL, 0, 2),
        ('84a7a08e-152d-4e4c-8bff-71791d16fef8', 'f8a27327-cb7a-46f4-bc53-5a2a9945784d', N'Drive', N'<drive>', N'Provides the optional drive letter and colon', NULL, 0, 0),
        ('4680c930-c04b-47df-9c86-36d4b0c576c5', 'f8a27327-cb7a-46f4-bc53-5a2a9945784d', N'PathTail', N'<path-tail>', N'Provides the optional directory or file hierarchy', NULL, 0, 1),
        ('0451e48e-5e94-47df-a94b-deaca7ea1675', '03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a', N'PathTail', N'<path-tail>', N'Provides the relative directory or file hierarchy', NULL, 1, 0),
        ('f37f15bc-683e-4ebe-a3aa-e293df4b2542', '9c967a82-098f-4a38-bac5-2be34529ed54', N'PathVariant', N'enum(Local|UNC)', N'Determines whether the extended path is local or UNC', NULL, 1, 0),
        ('50b2f135-8b28-4ede-840b-e90871124e3e', '9c967a82-098f-4a38-bac5-2be34529ed54', N'AbsolutePath', N'<absolute-path>', N'Provides the absolute path for the Local variant', NULL, 0, 1),
        ('9a74bda5-18cb-420b-b08c-f6db62777474', '9c967a82-098f-4a38-bac5-2be34529ed54', N'Server', N'<server>', N'Provides the network server component for the UNC variant', NULL, 0, 2),
        ('f5ae0c3c-eb4e-4d5d-b2ab-dc80468115c1', '9c967a82-098f-4a38-bac5-2be34529ed54', N'Share', N'<share>', N'Provides the shared resource component for the UNC variant', NULL, 0, 3),
        ('e4cb67dd-7db9-42ec-9914-0f98232a4ee3', '9c967a82-098f-4a38-bac5-2be34529ed54', N'PathTail', N'<path-tail>', N'Provides the optional directory or file path for the UNC variant', NULL, 0, 4),
        ('fd545856-9bc3-418f-b729-3b170e440230', '250e84cb-abd3-4823-875d-e0e75d88cee3', N'Letter', N'<letter>', N'Provides one alphabetic drive letter', NULL, 1, 0),
        ('105da8b3-6365-46cf-8231-31126df64b69', 'c810abaf-010a-426e-afda-d6881831a9e6', N'Name', N'<name>', N'Provides the first directory or file name', NULL, 1, 0),
        ('6d6731ab-f47f-4fd6-b6e9-8d9a69711a6a', 'c810abaf-010a-426e-afda-d6881831a9e6', N'RestOfPath', N'<path-tail>', N'Provides the optional remainder of the path hierarchy', NULL, 0, 1),
        ('18ee327e-0f41-406b-bfac-b99904739e82', '197c9963-55d3-4d80-9e39-23f30bf6c57e', N'NameChars', N'list(<namechar>)', N'Provides the ordered characters composing the name', NULL, 1, 0),
        ('32318390-c6ac-4f58-ba39-b542d1b3dd87', 'fa3311ee-3e7c-415a-9eb6-b458c793a675', N'Character', N'char', N'Provides the single path character to validate and render', NULL, 1, 0),
        ('6847251f-24e9-453c-8848-5d43cc529dcf', '520ade57-f639-45e1-b7de-e5dc3142655c', N'ServerIdentifier', N'<name>|IPAddressString', N'Provides the server name or IP address', NULL, 1, 0),
        ('1b3ca37b-f095-47e7-9f96-8dd5f4735079', '9b2a48bc-7c85-48cd-ac0d-a09d4b621b0a', N'ShareName', N'<name>', N'Provides the shared resource name', NULL, 1, 0),
        ('ff932d94-61a4-4274-99a7-84229acbfb5b', '9c8077ce-7abf-4d9a-969b-75631589a220', N'LetterChar', N'char', N'Provides one alphabetic character from A through Z or a through z', NULL, 1, 0);
    INSERT INTO [ATAPUtilities].[Rule] ([RuleId], [PhiloteId], [RuleKindId], [RulePrimitiveId], [RuleCode], [RuleBody])
    VALUES
        ('616fb394-0b4d-486a-98af-48f1fe461af2', '616fb394-0b4d-486a-98af-48f1fe461af2', '8e06f2af-52cf-47d5-872e-0d3912f4fda0', '9460f2f5-9957-4455-b6a6-8ee241b7ebb3', 'HelloWorld.PowerShell', N'function HelloWorld {
  Write-Host ''Hello World''
}'),
        ('c5c1c63a-4364-4233-9aa1-2a1a5a2ba1f3', 'c5c1c63a-4364-4233-9aa1-2a1a5a2ba1f3', 'b32c60e0-86f3-40e6-893e-d3240ffea882', '03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a', 'HelloWorld.Path', N'HelloWorld.ps1');
    INSERT INTO [ATAPUtilities].[RuleSet] ([RuleSetId], [PhiloteId], [RuleSetCode])
    VALUES
        ('23ad4f37-2c70-4f34-9104-9868ec0f3823', '23ad4f37-2c70-4f34-9104-9868ec0f3823', 'HelloWorld');
    INSERT INTO [ATAPUtilities].[RuleSetRule] ([RuleSetId], [RuleId], [Ordinal])
    VALUES
        ('23ad4f37-2c70-4f34-9104-9868ec0f3823', '616fb394-0b4d-486a-98af-48f1fe461af2', 0),
        ('23ad4f37-2c70-4f34-9104-9868ec0f3823', 'c5c1c63a-4364-4233-9aa1-2a1a5a2ba1f3', 1);
    INSERT INTO [ATAPUtilities].[BuildSet] ([BuildSetId], [PhiloteId], [BuildSetCode])
    VALUES
        ('550e7722-cb57-4e47-a94b-9212b451d6fb', '550e7722-cb57-4e47-a94b-9212b451d6fb', 'HelloWorld');
    INSERT INTO [ATAPUtilities].[BuildSetRuleSet] ([BuildSetId], [RuleSetId], [Ordinal])
    VALUES
        ('550e7722-cb57-4e47-a94b-9212b451d6fb', '23ad4f37-2c70-4f34-9104-9868ec0f3823', 0);
    INSERT INTO [ATAPUtilities].[Instantiation] ([InstantiationId], [PhiloteId], [BuildSetId], [InstantiationCode])
    VALUES
        ('03e28494-998f-4fc2-ba5d-ad6e5832c8b7', '03e28494-998f-4fc2-ba5d-ad6e5832c8b7', '550e7722-cb57-4e47-a94b-9212b451d6fb', 'HelloWorld');

    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Philote]) <> 22
        THROW 55400, 'Initial baseline assertion failed: Philote count is not 22.', 1;
    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[PhiloteValidityPeriod]) <> 22
        THROW 55401, 'Initial baseline assertion failed: PhiloteValidityPeriod count is not 22.', 1;
    IF EXISTS
    (
        SELECT [PhiloteValidityPeriodId], [PhiloteId], [PreviousValidToUtc], [ValidFromUtc], [ValidToUtc]
        FROM [ATAPUtilities].[PhiloteValidityPeriod]
        EXCEPT
        SELECT [PhiloteValidityPeriodId], [PhiloteId], [PreviousValidToUtc], [ValidFromUtc], [ValidToUtc]
        FROM @ApprovedPhiloteValidityPeriod
    ) OR EXISTS
    (
        SELECT [PhiloteValidityPeriodId], [PhiloteId], [PreviousValidToUtc], [ValidFromUtc], [ValidToUtc]
        FROM @ApprovedPhiloteValidityPeriod
        EXCEPT
        SELECT [PhiloteValidityPeriodId], [PhiloteId], [PreviousValidToUtc], [ValidFromUtc], [ValidToUtc]
        FROM [ATAPUtilities].[PhiloteValidityPeriod]
    )
        THROW 55402, 'Initial baseline assertion failed: validity registry differs from PTV-G0.', 1;

    IF (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleKind]) <> 2
       OR (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RulePrimitive]) <> 15
       OR (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RulePrimitiveInput]) <> 21
       OR (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Rule]) <> 2
       OR (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleSet]) <> 1
       OR (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleSetRule]) <> 2
       OR (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[BuildSet]) <> 1
       OR (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[BuildSetRuleSet]) <> 1
       OR (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Instantiation]) <> 1
        THROW 55403, 'Initial baseline assertion failed: RPRRSBSI graph counts differ from the approved seed.', 1;

    IF EXISTS
    (
        SELECT [PhiloteId]
        FROM [ATAPUtilities].[Philote]
        EXCEPT
        SELECT [PhiloteId]
        FROM @ApprovedPhiloteValidityPeriod
    ) OR EXISTS
    (
        SELECT [PhiloteId]
        FROM @ApprovedPhiloteValidityPeriod
        EXCEPT
        SELECT [PhiloteId]
        FROM [ATAPUtilities].[Philote]
    )
        THROW 55404, 'Initial baseline assertion failed: seeded Philotes and validity periods are not one-to-one.', 1;

    /* PTV-430: aggregate-owned temporal mutation boundary. */
    IF TYPE_ID(N'ATAPUtilities.PhiloteValidityPeriodSetInput') IS NULL
    BEGIN
    EXEC sys.sp_executesql N'CREATE TYPE [ATAPUtilities].[PhiloteValidityPeriodSetInput] AS TABLE
(
    [PhiloteValidityPeriodId] uniqueidentifier NOT NULL,
    [PreviousValidToUtc] datetime2(7) NULL,
    [ValidFromUtc] datetime2(7) NOT NULL,
    [ValidToUtc] datetime2(7) NULL,
    PRIMARY KEY ([PhiloteValidityPeriodId]),
    UNIQUE ([ValidFromUtc]),
    UNIQUE ([ValidToUtc]),
    UNIQUE ([PreviousValidToUtc])
);';
    END;

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[ReplacePhiloteValidityPeriodSet]
    @PhiloteId uniqueidentifier,
    @Periods [ATAPUtilities].[PhiloteValidityPeriodSetInput] READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PhiloteId IS NULL
        THROW 55200, ''PhiloteId is required.'', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @LockResult int;
        DECLARE @LockResource nvarchar(255) =
            N''ATAPUtilities.PhiloteValidityPeriod:''
            + LOWER(CONVERT(nvarchar(36), @PhiloteId));

        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = ''Exclusive'',
            @LockOwner = ''Transaction'',
            @LockTimeout = 15000,
            @DbPrincipal = ''public'';

        IF @LockResult < 0
            THROW 55201, ''Unable to acquire the Philote temporal-validity writer lock.'', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM [ATAPUtilities].[Philote] WITH (UPDLOCK, HOLDLOCK)
            WHERE [PhiloteId] = @PhiloteId
        )
            THROW 55202, ''The parent Philote does not exist.'', 1;

        DECLARE @Current TABLE
        (
            [PhiloteValidityPeriodId] uniqueidentifier NOT NULL PRIMARY KEY,
            [PreviousValidToUtc] datetime2(7) NULL,
            [ValidFromUtc] datetime2(7) NOT NULL,
            [ValidToUtc] datetime2(7) NULL
        );

        INSERT INTO @Current
        SELECT
            [PhiloteValidityPeriodId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM [ATAPUtilities].[PhiloteValidityPeriod] WITH (UPDLOCK, HOLDLOCK)
        WHERE [PhiloteId] = @PhiloteId;

        IF EXISTS
        (
            SELECT 1
            FROM @Periods
            WHERE [ValidToUtc] IS NOT NULL
              AND [ValidFromUtc] >= [ValidToUtc]
        )
            THROW 55203, ''Every bounded period must be non-empty and forward.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM @Periods
            WHERE [PreviousValidToUtc] IS NOT NULL
              AND [PreviousValidToUtc] > [ValidFromUtc]
        )
            THROW 55204, ''A predecessor end cannot be after the period start.'', 1;

        IF (SELECT COUNT_BIG(*) FROM @Periods) > 0
           AND (SELECT COUNT_BIG(*) FROM @Periods WHERE [PreviousValidToUtc] IS NULL) <> 1
            THROW 55205, ''A non-empty period set must contain exactly one first row.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM @Periods AS successor
            WHERE successor.[PreviousValidToUtc] IS NOT NULL
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM @Periods AS predecessor
                  WHERE predecessor.[ValidToUtc] = successor.[PreviousValidToUtc]
              )
        )
            THROW 55206, ''Every non-first period must reference an existing predecessor end.'', 1;

        DECLARE @DeleteId uniqueidentifier;
        WHILE EXISTS
        (
            SELECT 1
            FROM [ATAPUtilities].[PhiloteValidityPeriod]
            WHERE [PhiloteId] = @PhiloteId
        )
        BEGIN
            SELECT TOP (1) @DeleteId = [PhiloteValidityPeriodId]
            FROM [ATAPUtilities].[PhiloteValidityPeriod]
            WHERE [PhiloteId] = @PhiloteId
            ORDER BY [ValidFromUtc] DESC, [PhiloteValidityPeriodId] DESC;

            DELETE FROM [ATAPUtilities].[PhiloteValidityPeriod]
            WHERE [PhiloteValidityPeriodId] = @DeleteId;
        END;

        DECLARE @Pending TABLE
        (
            [PhiloteValidityPeriodId] uniqueidentifier NOT NULL PRIMARY KEY,
            [PreviousValidToUtc] datetime2(7) NULL,
            [ValidFromUtc] datetime2(7) NOT NULL,
            [ValidToUtc] datetime2(7) NULL
        );

        INSERT INTO @Pending
        SELECT
            [PhiloteValidityPeriodId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM @Periods;

        DECLARE @InsertId uniqueidentifier;
        DECLARE @PreviousValidToUtc datetime2(7);
        DECLARE @ValidFromUtc datetime2(7);
        DECLARE @ValidToUtc datetime2(7);

        WHILE EXISTS (SELECT 1 FROM @Pending)
        BEGIN
            SELECT TOP (1)
                @InsertId = [PhiloteValidityPeriodId],
                @PreviousValidToUtc = [PreviousValidToUtc],
                @ValidFromUtc = [ValidFromUtc],
                @ValidToUtc = [ValidToUtc]
            FROM @Pending
            ORDER BY [ValidFromUtc], [PhiloteValidityPeriodId];

            INSERT INTO [ATAPUtilities].[PhiloteValidityPeriod]
            (
                [PhiloteValidityPeriodId],
                [PhiloteId],
                [PreviousValidToUtc],
                [ValidFromUtc],
                [ValidToUtc]
            )
            VALUES
            (
                @InsertId,
                @PhiloteId,
                @PreviousValidToUtc,
                @ValidFromUtc,
                @ValidToUtc
            );

            DELETE FROM @Pending
            WHERE [PhiloteValidityPeriodId] = @InsertId;
        END;

        IF EXISTS
        (
            SELECT [PhiloteValidityPeriodId], [PreviousValidToUtc], [ValidFromUtc], [ValidToUtc]
            FROM [ATAPUtilities].[PhiloteValidityPeriod]
            WHERE [PhiloteId] = @PhiloteId
            EXCEPT
            SELECT [PhiloteValidityPeriodId], [PreviousValidToUtc], [ValidFromUtc], [ValidToUtc]
            FROM @Periods
        ) OR EXISTS
        (
            SELECT [PhiloteValidityPeriodId], [PreviousValidToUtc], [ValidFromUtc], [ValidToUtc]
            FROM @Periods
            EXCEPT
            SELECT [PhiloteValidityPeriodId], [PreviousValidToUtc], [ValidFromUtc], [ValidToUtc]
            FROM [ATAPUtilities].[PhiloteValidityPeriod]
            WHERE [PhiloteId] = @PhiloteId
        )
            THROW 55207, ''The persisted period set differs from the validated desired set.'', 1;

        COMMIT TRANSACTION;

        SELECT
            [PhiloteValidityPeriodId],
            [PhiloteId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM [ATAPUtilities].[PhiloteValidityPeriod]
        WHERE [PhiloteId] = @PhiloteId
        ORDER BY [ValidFromUtc], [PhiloteValidityPeriodId];

        RETURN 0;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[CreateFirstPhiloteValidityPeriod]
    @PhiloteId uniqueidentifier,
    @PhiloteValidityPeriodId uniqueidentifier,
    @ValidFromUtc datetime2(7),
    @ValidToUtc datetime2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PhiloteId IS NULL
        THROW 55230, ''PhiloteId is required.'', 1;
    IF @PhiloteValidityPeriodId IS NULL
        THROW 55231, ''PhiloteValidityPeriodId is required.'', 1;
    IF @ValidFromUtc IS NULL
        THROW 55232, ''ValidFromUtc is required.'', 1;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @LockResult int;
        DECLARE @LockResource nvarchar(255) =
            N''ATAPUtilities.PhiloteValidityPeriod:''
            + LOWER(CONVERT(nvarchar(36), @PhiloteId));

        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = ''Exclusive'',
            @LockOwner = ''Transaction'',
            @LockTimeout = 15000,
            @DbPrincipal = ''public'';

        IF @LockResult < 0
            THROW 55220, ''Unable to acquire the Philote temporal-validity writer lock.'', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM [ATAPUtilities].[Philote] WITH (UPDLOCK, HOLDLOCK)
            WHERE [PhiloteId] = @PhiloteId
        )
            THROW 55221, ''The parent Philote does not exist.'', 1;

        DECLARE @Desired [ATAPUtilities].[PhiloteValidityPeriodSetInput];

        INSERT INTO @Desired
        (
            [PhiloteValidityPeriodId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        )
        SELECT
            [PhiloteValidityPeriodId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM [ATAPUtilities].[PhiloteValidityPeriod] WITH (UPDLOCK, HOLDLOCK)
        WHERE [PhiloteId] = @PhiloteId;

        IF EXISTS (SELECT 1 FROM @Desired)
            THROW 55233, ''The Philote already has a validity period.'', 1;

        INSERT INTO @Desired
        (
            [PhiloteValidityPeriodId], [PreviousValidToUtc], [ValidFromUtc], [ValidToUtc]
        )
        VALUES
        (
            @PhiloteValidityPeriodId, NULL, @ValidFromUtc, @ValidToUtc
        );

        DECLARE @Result TABLE
        (
            [PhiloteValidityPeriodId] uniqueidentifier NOT NULL,
            [PhiloteId] uniqueidentifier NOT NULL,
            [PreviousValidToUtc] datetime2(7) NULL,
            [ValidFromUtc] datetime2(7) NOT NULL,
            [ValidToUtc] datetime2(7) NULL
        );
        DECLARE @ReturnCode int;

        INSERT INTO @Result
        EXEC @ReturnCode = [ATAPUtilities].[ReplacePhiloteValidityPeriodSet]
            @PhiloteId = @PhiloteId,
            @Periods = @Desired;

        COMMIT TRANSACTION;

        SELECT
            [PhiloteValidityPeriodId],
            [PhiloteId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM @Result
        ORDER BY [ValidFromUtc], [PhiloteValidityPeriodId];

        RETURN @ReturnCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[CloseCurrentPhiloteValidityPeriod]
    @PhiloteId uniqueidentifier,
    @ExpectedPhiloteValidityPeriodId uniqueidentifier,
    @ValidToUtc datetime2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PhiloteId IS NULL
        THROW 55240, ''PhiloteId is required.'', 1;
    IF @ExpectedPhiloteValidityPeriodId IS NULL
        THROW 55241, ''ExpectedPhiloteValidityPeriodId is required.'', 1;
    IF @ValidToUtc IS NULL
        THROW 55242, ''ValidToUtc is required.'', 1;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @LockResult int;
        DECLARE @LockResource nvarchar(255) =
            N''ATAPUtilities.PhiloteValidityPeriod:''
            + LOWER(CONVERT(nvarchar(36), @PhiloteId));

        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = ''Exclusive'',
            @LockOwner = ''Transaction'',
            @LockTimeout = 15000,
            @DbPrincipal = ''public'';

        IF @LockResult < 0
            THROW 55220, ''Unable to acquire the Philote temporal-validity writer lock.'', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM [ATAPUtilities].[Philote] WITH (UPDLOCK, HOLDLOCK)
            WHERE [PhiloteId] = @PhiloteId
        )
            THROW 55221, ''The parent Philote does not exist.'', 1;

        DECLARE @Desired [ATAPUtilities].[PhiloteValidityPeriodSetInput];

        INSERT INTO @Desired
        (
            [PhiloteValidityPeriodId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        )
        SELECT
            [PhiloteValidityPeriodId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM [ATAPUtilities].[PhiloteValidityPeriod] WITH (UPDLOCK, HOLDLOCK)
        WHERE [PhiloteId] = @PhiloteId;

        IF NOT EXISTS
        (
            SELECT 1
            FROM @Desired
            WHERE [PhiloteValidityPeriodId] = @ExpectedPhiloteValidityPeriodId
              AND [ValidToUtc] IS NULL
        )
            THROW 55243, ''The expected open validity period was not found.'', 1;

        UPDATE @Desired
        SET [ValidToUtc] = @ValidToUtc
        WHERE [PhiloteValidityPeriodId] = @ExpectedPhiloteValidityPeriodId;

        DECLARE @Result TABLE
        (
            [PhiloteValidityPeriodId] uniqueidentifier NOT NULL,
            [PhiloteId] uniqueidentifier NOT NULL,
            [PreviousValidToUtc] datetime2(7) NULL,
            [ValidFromUtc] datetime2(7) NOT NULL,
            [ValidToUtc] datetime2(7) NULL
        );
        DECLARE @ReturnCode int;

        INSERT INTO @Result
        EXEC @ReturnCode = [ATAPUtilities].[ReplacePhiloteValidityPeriodSet]
            @PhiloteId = @PhiloteId,
            @Periods = @Desired;

        COMMIT TRANSACTION;

        SELECT
            [PhiloteValidityPeriodId],
            [PhiloteId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM @Result
        ORDER BY [ValidFromUtc], [PhiloteValidityPeriodId];

        RETURN @ReturnCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[ReactivatePhiloteValidityPeriod]
    @PhiloteId uniqueidentifier,
    @PhiloteValidityPeriodId uniqueidentifier,
    @ValidFromUtc datetime2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PhiloteId IS NULL
        THROW 55250, ''PhiloteId is required.'', 1;
    IF @PhiloteValidityPeriodId IS NULL
        THROW 55251, ''PhiloteValidityPeriodId is required.'', 1;
    IF @ValidFromUtc IS NULL
        THROW 55252, ''ValidFromUtc is required.'', 1;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @LockResult int;
        DECLARE @LockResource nvarchar(255) =
            N''ATAPUtilities.PhiloteValidityPeriod:''
            + LOWER(CONVERT(nvarchar(36), @PhiloteId));

        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = ''Exclusive'',
            @LockOwner = ''Transaction'',
            @LockTimeout = 15000,
            @DbPrincipal = ''public'';

        IF @LockResult < 0
            THROW 55220, ''Unable to acquire the Philote temporal-validity writer lock.'', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM [ATAPUtilities].[Philote] WITH (UPDLOCK, HOLDLOCK)
            WHERE [PhiloteId] = @PhiloteId
        )
            THROW 55221, ''The parent Philote does not exist.'', 1;

        DECLARE @Desired [ATAPUtilities].[PhiloteValidityPeriodSetInput];

        INSERT INTO @Desired
        (
            [PhiloteValidityPeriodId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        )
        SELECT
            [PhiloteValidityPeriodId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM [ATAPUtilities].[PhiloteValidityPeriod] WITH (UPDLOCK, HOLDLOCK)
        WHERE [PhiloteId] = @PhiloteId;

        IF NOT EXISTS (SELECT 1 FROM @Desired)
            THROW 55253, ''Reactivation requires an existing bounded period.'', 1;
        IF EXISTS (SELECT 1 FROM @Desired WHERE [ValidToUtc] IS NULL)
            THROW 55254, ''The Philote already has an open validity period.'', 1;

        DECLARE @LastValidToUtc datetime2(7) =
        (
            SELECT MAX([ValidToUtc])
            FROM @Desired
        );

        IF @ValidFromUtc <= @LastValidToUtc
            THROW 55255, ''Reactivation must begin after a strict gap.'', 1;

        INSERT INTO @Desired
        (
            [PhiloteValidityPeriodId], [PreviousValidToUtc], [ValidFromUtc], [ValidToUtc]
        )
        VALUES
        (
            @PhiloteValidityPeriodId, @LastValidToUtc, @ValidFromUtc, NULL
        );

        DECLARE @Result TABLE
        (
            [PhiloteValidityPeriodId] uniqueidentifier NOT NULL,
            [PhiloteId] uniqueidentifier NOT NULL,
            [PreviousValidToUtc] datetime2(7) NULL,
            [ValidFromUtc] datetime2(7) NOT NULL,
            [ValidToUtc] datetime2(7) NULL
        );
        DECLARE @ReturnCode int;

        INSERT INTO @Result
        EXEC @ReturnCode = [ATAPUtilities].[ReplacePhiloteValidityPeriodSet]
            @PhiloteId = @PhiloteId,
            @Periods = @Desired;

        COMMIT TRANSACTION;

        SELECT
            [PhiloteValidityPeriodId],
            [PhiloteId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM @Result
        ORDER BY [ValidFromUtc], [PhiloteValidityPeriodId];

        RETURN @ReturnCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[CorrectPhiloteValidityPeriodBoundary]
    @PhiloteId uniqueidentifier,
    @PhiloteValidityPeriodId uniqueidentifier,
    @ExpectedValidFromUtc datetime2(7),
    @ExpectedValidToUtc datetime2(7),
    @NewValidFromUtc datetime2(7),
    @NewValidToUtc datetime2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PhiloteId IS NULL
        THROW 55260, ''PhiloteId is required.'', 1;
    IF @PhiloteValidityPeriodId IS NULL
        THROW 55261, ''PhiloteValidityPeriodId is required.'', 1;
    IF @ExpectedValidFromUtc IS NULL
        THROW 55262, ''ExpectedValidFromUtc is required.'', 1;
    IF @NewValidFromUtc IS NULL
        THROW 55263, ''NewValidFromUtc is required.'', 1;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @LockResult int;
        DECLARE @LockResource nvarchar(255) =
            N''ATAPUtilities.PhiloteValidityPeriod:''
            + LOWER(CONVERT(nvarchar(36), @PhiloteId));

        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = ''Exclusive'',
            @LockOwner = ''Transaction'',
            @LockTimeout = 15000,
            @DbPrincipal = ''public'';

        IF @LockResult < 0
            THROW 55220, ''Unable to acquire the Philote temporal-validity writer lock.'', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM [ATAPUtilities].[Philote] WITH (UPDLOCK, HOLDLOCK)
            WHERE [PhiloteId] = @PhiloteId
        )
            THROW 55221, ''The parent Philote does not exist.'', 1;

        DECLARE @Desired [ATAPUtilities].[PhiloteValidityPeriodSetInput];

        INSERT INTO @Desired
        (
            [PhiloteValidityPeriodId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        )
        SELECT
            [PhiloteValidityPeriodId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM [ATAPUtilities].[PhiloteValidityPeriod] WITH (UPDLOCK, HOLDLOCK)
        WHERE [PhiloteId] = @PhiloteId;

        IF NOT EXISTS
        (
            SELECT 1
            FROM @Desired
            WHERE [PhiloteValidityPeriodId] = @PhiloteValidityPeriodId
              AND [ValidFromUtc] = @ExpectedValidFromUtc
              AND
              (
                  [ValidToUtc] = @ExpectedValidToUtc
                  OR ([ValidToUtc] IS NULL AND @ExpectedValidToUtc IS NULL)
              )
        )
            THROW 55264, ''The expected validity-period boundaries are stale or absent.'', 1;

        IF @ExpectedValidToUtc IS NOT NULL
        BEGIN
            UPDATE @Desired
            SET [PreviousValidToUtc] = @NewValidToUtc
            WHERE [PreviousValidToUtc] = @ExpectedValidToUtc
              AND [PhiloteValidityPeriodId] <> @PhiloteValidityPeriodId;
        END;

        UPDATE @Desired
        SET
            [ValidFromUtc] = @NewValidFromUtc,
            [ValidToUtc] = @NewValidToUtc
        WHERE [PhiloteValidityPeriodId] = @PhiloteValidityPeriodId;

        DECLARE @Result TABLE
        (
            [PhiloteValidityPeriodId] uniqueidentifier NOT NULL,
            [PhiloteId] uniqueidentifier NOT NULL,
            [PreviousValidToUtc] datetime2(7) NULL,
            [ValidFromUtc] datetime2(7) NOT NULL,
            [ValidToUtc] datetime2(7) NULL
        );
        DECLARE @ReturnCode int;

        INSERT INTO @Result
        EXEC @ReturnCode = [ATAPUtilities].[ReplacePhiloteValidityPeriodSet]
            @PhiloteId = @PhiloteId,
            @Periods = @Desired;

        COMMIT TRANSACTION;

        SELECT
            [PhiloteValidityPeriodId],
            [PhiloteId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM @Result
        ORDER BY [ValidFromUtc], [PhiloteValidityPeriodId];

        RETURN @ReturnCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[SplitPhiloteValidityPeriod]
    @PhiloteId uniqueidentifier,
    @PhiloteValidityPeriodId uniqueidentifier,
    @ExpectedValidFromUtc datetime2(7),
    @ExpectedValidToUtc datetime2(7),
    @SplitUtc datetime2(7),
    @NewLaterPhiloteValidityPeriodId uniqueidentifier
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PhiloteId IS NULL
        THROW 55270, ''PhiloteId is required.'', 1;
    IF @PhiloteValidityPeriodId IS NULL
        THROW 55271, ''PhiloteValidityPeriodId is required.'', 1;
    IF @ExpectedValidFromUtc IS NULL
        THROW 55272, ''ExpectedValidFromUtc is required.'', 1;
    IF @ExpectedValidToUtc IS NULL
        THROW 55273, ''ExpectedValidToUtc is required.'', 1;
    IF @SplitUtc IS NULL
        THROW 55274, ''SplitUtc is required.'', 1;
    IF @NewLaterPhiloteValidityPeriodId IS NULL
        THROW 55275, ''NewLaterPhiloteValidityPeriodId is required.'', 1;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @LockResult int;
        DECLARE @LockResource nvarchar(255) =
            N''ATAPUtilities.PhiloteValidityPeriod:''
            + LOWER(CONVERT(nvarchar(36), @PhiloteId));

        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = ''Exclusive'',
            @LockOwner = ''Transaction'',
            @LockTimeout = 15000,
            @DbPrincipal = ''public'';

        IF @LockResult < 0
            THROW 55220, ''Unable to acquire the Philote temporal-validity writer lock.'', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM [ATAPUtilities].[Philote] WITH (UPDLOCK, HOLDLOCK)
            WHERE [PhiloteId] = @PhiloteId
        )
            THROW 55221, ''The parent Philote does not exist.'', 1;

        DECLARE @Desired [ATAPUtilities].[PhiloteValidityPeriodSetInput];

        INSERT INTO @Desired
        (
            [PhiloteValidityPeriodId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        )
        SELECT
            [PhiloteValidityPeriodId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM [ATAPUtilities].[PhiloteValidityPeriod] WITH (UPDLOCK, HOLDLOCK)
        WHERE [PhiloteId] = @PhiloteId;

        IF NOT EXISTS
        (
            SELECT 1
            FROM @Desired
            WHERE [PhiloteValidityPeriodId] = @PhiloteValidityPeriodId
              AND [ValidFromUtc] = @ExpectedValidFromUtc
              AND [ValidToUtc] = @ExpectedValidToUtc
        )
            THROW 55276, ''The expected bounded validity period is stale or absent.'', 1;

        IF @SplitUtc <= @ExpectedValidFromUtc OR @SplitUtc >= @ExpectedValidToUtc
            THROW 55277, ''SplitUtc must be strictly inside the bounded period.'', 1;

        UPDATE @Desired
        SET [ValidToUtc] = @SplitUtc
        WHERE [PhiloteValidityPeriodId] = @PhiloteValidityPeriodId;

        INSERT INTO @Desired
        (
            [PhiloteValidityPeriodId], [PreviousValidToUtc], [ValidFromUtc], [ValidToUtc]
        )
        VALUES
        (
            @NewLaterPhiloteValidityPeriodId, @SplitUtc, @SplitUtc, @ExpectedValidToUtc
        );

        DECLARE @Result TABLE
        (
            [PhiloteValidityPeriodId] uniqueidentifier NOT NULL,
            [PhiloteId] uniqueidentifier NOT NULL,
            [PreviousValidToUtc] datetime2(7) NULL,
            [ValidFromUtc] datetime2(7) NOT NULL,
            [ValidToUtc] datetime2(7) NULL
        );
        DECLARE @ReturnCode int;

        INSERT INTO @Result
        EXEC @ReturnCode = [ATAPUtilities].[ReplacePhiloteValidityPeriodSet]
            @PhiloteId = @PhiloteId,
            @Periods = @Desired;

        COMMIT TRANSACTION;

        SELECT
            [PhiloteValidityPeriodId],
            [PhiloteId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM @Result
        ORDER BY [ValidFromUtc], [PhiloteValidityPeriodId];

        RETURN @ReturnCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[MergeAdjacentPhiloteValidityPeriods]
    @PhiloteId uniqueidentifier,
    @EarlierPhiloteValidityPeriodId uniqueidentifier,
    @LaterPhiloteValidityPeriodId uniqueidentifier,
    @ExpectedBoundaryUtc datetime2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PhiloteId IS NULL
        THROW 55280, ''PhiloteId is required.'', 1;
    IF @EarlierPhiloteValidityPeriodId IS NULL
        THROW 55281, ''EarlierPhiloteValidityPeriodId is required.'', 1;
    IF @LaterPhiloteValidityPeriodId IS NULL
        THROW 55282, ''LaterPhiloteValidityPeriodId is required.'', 1;
    IF @ExpectedBoundaryUtc IS NULL
        THROW 55283, ''ExpectedBoundaryUtc is required.'', 1;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @LockResult int;
        DECLARE @LockResource nvarchar(255) =
            N''ATAPUtilities.PhiloteValidityPeriod:''
            + LOWER(CONVERT(nvarchar(36), @PhiloteId));

        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = ''Exclusive'',
            @LockOwner = ''Transaction'',
            @LockTimeout = 15000,
            @DbPrincipal = ''public'';

        IF @LockResult < 0
            THROW 55220, ''Unable to acquire the Philote temporal-validity writer lock.'', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM [ATAPUtilities].[Philote] WITH (UPDLOCK, HOLDLOCK)
            WHERE [PhiloteId] = @PhiloteId
        )
            THROW 55221, ''The parent Philote does not exist.'', 1;

        DECLARE @Desired [ATAPUtilities].[PhiloteValidityPeriodSetInput];

        INSERT INTO @Desired
        (
            [PhiloteValidityPeriodId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        )
        SELECT
            [PhiloteValidityPeriodId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM [ATAPUtilities].[PhiloteValidityPeriod] WITH (UPDLOCK, HOLDLOCK)
        WHERE [PhiloteId] = @PhiloteId;

        DECLARE @LaterValidToUtc datetime2(7);

        SELECT @LaterValidToUtc = later.[ValidToUtc]
        FROM @Desired AS earlier
        INNER JOIN @Desired AS later
            ON later.[PhiloteValidityPeriodId] = @LaterPhiloteValidityPeriodId
           AND later.[PreviousValidToUtc] = earlier.[ValidToUtc]
        WHERE earlier.[PhiloteValidityPeriodId] = @EarlierPhiloteValidityPeriodId
          AND earlier.[ValidToUtc] = @ExpectedBoundaryUtc
          AND later.[ValidFromUtc] = @ExpectedBoundaryUtc;

        IF @@ROWCOUNT <> 1
            THROW 55284, ''The periods are not the expected consecutive adjacent pair.'', 1;

        DELETE FROM @Desired
        WHERE [PhiloteValidityPeriodId] = @LaterPhiloteValidityPeriodId;

        UPDATE @Desired
        SET [ValidToUtc] = @LaterValidToUtc
        WHERE [PhiloteValidityPeriodId] = @EarlierPhiloteValidityPeriodId;

        DECLARE @Result TABLE
        (
            [PhiloteValidityPeriodId] uniqueidentifier NOT NULL,
            [PhiloteId] uniqueidentifier NOT NULL,
            [PreviousValidToUtc] datetime2(7) NULL,
            [ValidFromUtc] datetime2(7) NOT NULL,
            [ValidToUtc] datetime2(7) NULL
        );
        DECLARE @ReturnCode int;

        INSERT INTO @Result
        EXEC @ReturnCode = [ATAPUtilities].[ReplacePhiloteValidityPeriodSet]
            @PhiloteId = @PhiloteId,
            @Periods = @Desired;

        COMMIT TRANSACTION;

        SELECT
            [PhiloteValidityPeriodId],
            [PhiloteId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM @Result
        ORDER BY [ValidFromUtc], [PhiloteValidityPeriodId];

        RETURN @ReturnCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

    EXEC sys.sp_executesql N'CREATE PROCEDURE [ATAPUtilities].[DeletePhiloteValidityPeriod]
    @PhiloteId uniqueidentifier,
    @PhiloteValidityPeriodId uniqueidentifier,
    @ExpectedValidFromUtc datetime2(7),
    @ExpectedValidToUtc datetime2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PhiloteId IS NULL
        THROW 55290, ''PhiloteId is required.'', 1;
    IF @PhiloteValidityPeriodId IS NULL
        THROW 55291, ''PhiloteValidityPeriodId is required.'', 1;
    IF @ExpectedValidFromUtc IS NULL
        THROW 55292, ''ExpectedValidFromUtc is required.'', 1;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @LockResult int;
        DECLARE @LockResource nvarchar(255) =
            N''ATAPUtilities.PhiloteValidityPeriod:''
            + LOWER(CONVERT(nvarchar(36), @PhiloteId));

        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = ''Exclusive'',
            @LockOwner = ''Transaction'',
            @LockTimeout = 15000,
            @DbPrincipal = ''public'';

        IF @LockResult < 0
            THROW 55220, ''Unable to acquire the Philote temporal-validity writer lock.'', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM [ATAPUtilities].[Philote] WITH (UPDLOCK, HOLDLOCK)
            WHERE [PhiloteId] = @PhiloteId
        )
            THROW 55221, ''The parent Philote does not exist.'', 1;

        DECLARE @Desired [ATAPUtilities].[PhiloteValidityPeriodSetInput];

        INSERT INTO @Desired
        (
            [PhiloteValidityPeriodId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        )
        SELECT
            [PhiloteValidityPeriodId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM [ATAPUtilities].[PhiloteValidityPeriod] WITH (UPDLOCK, HOLDLOCK)
        WHERE [PhiloteId] = @PhiloteId;

        DECLARE @DeletedPreviousValidToUtc datetime2(7);
        DECLARE @DeletedValidToUtc datetime2(7);

        SELECT
            @DeletedPreviousValidToUtc = [PreviousValidToUtc],
            @DeletedValidToUtc = [ValidToUtc]
        FROM @Desired
        WHERE [PhiloteValidityPeriodId] = @PhiloteValidityPeriodId
          AND [ValidFromUtc] = @ExpectedValidFromUtc
          AND
          (
              [ValidToUtc] = @ExpectedValidToUtc
              OR ([ValidToUtc] IS NULL AND @ExpectedValidToUtc IS NULL)
          );

        IF @@ROWCOUNT <> 1
            THROW 55293, ''The expected validity period is stale or absent.'', 1;

        DELETE FROM @Desired
        WHERE [PhiloteValidityPeriodId] = @PhiloteValidityPeriodId;

        IF @DeletedValidToUtc IS NOT NULL
        BEGIN
            UPDATE @Desired
            SET [PreviousValidToUtc] = @DeletedPreviousValidToUtc
            WHERE [PreviousValidToUtc] = @DeletedValidToUtc;
        END;

        DECLARE @Result TABLE
        (
            [PhiloteValidityPeriodId] uniqueidentifier NOT NULL,
            [PhiloteId] uniqueidentifier NOT NULL,
            [PreviousValidToUtc] datetime2(7) NULL,
            [ValidFromUtc] datetime2(7) NOT NULL,
            [ValidToUtc] datetime2(7) NULL
        );
        DECLARE @ReturnCode int;

        INSERT INTO @Result
        EXEC @ReturnCode = [ATAPUtilities].[ReplacePhiloteValidityPeriodSet]
            @PhiloteId = @PhiloteId,
            @Periods = @Desired;

        COMMIT TRANSACTION;

        SELECT
            [PhiloteValidityPeriodId],
            [PhiloteId],
            [PreviousValidToUtc],
            [ValidFromUtc],
            [ValidToUtc]
        FROM @Result
        ORDER BY [ValidFromUtc], [PhiloteValidityPeriodId];

        RETURN @ReturnCode;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
/*
  RPRRSBSI V3 core schema.

  This migration implements only the ratified V3 physical data dictionary:
  11 tables, 46 columns, and its 70 explicitly named constraints.
  Seed data, loaders, excluded domains, and database lifecycle operations are
  intentionally outside this migration.
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

    IF OBJECT_ID(N'[ATAPUtilities].[TimeBlock]', N'U') IS NULL
    BEGIN
        CREATE TABLE [ATAPUtilities].[TimeBlock]
        (
            [TimeBlockId] uniqueidentifier NOT NULL,
            [PhiloteId] uniqueidentifier NOT NULL,
            [Ordinal] int NOT NULL,
            [StartUtc] datetime2(7) NOT NULL,
            [DurationTicks] bigint NOT NULL,
            [EndUtc] datetime2(7) NOT NULL,
            CONSTRAINT [PK_TimeBlock]
                PRIMARY KEY ([TimeBlockId]),
            CONSTRAINT [FK_TimeBlock_Philote]
                FOREIGN KEY ([PhiloteId])
                REFERENCES [ATAPUtilities].[Philote] ([PhiloteId])
                ON DELETE NO ACTION
                ON UPDATE NO ACTION,
            CONSTRAINT [UQ_TimeBlock_Philote_Ordinal]
                UNIQUE ([PhiloteId], [Ordinal]),
            CONSTRAINT [CK_TimeBlock_Ordinal_NonNegative]
                CHECK ([Ordinal] >= 0),
            CONSTRAINT [CK_TimeBlock_DurationTicks_Positive]
                CHECK ([DurationTicks] > 0),
            CONSTRAINT [CK_TimeBlock_EndUtc_Exact]
                CHECK
                (
                    [EndUtc] > [StartUtc]
                    AND [DurationTicks] =
                          DATEDIFF_BIG(DAY, CONVERT(date, [StartUtc]), CONVERT(date, [EndUtc]))
                            * CONVERT(bigint, 864000000000)
                        + DATEDIFF_BIG
                          (
                              NANOSECOND,
                              CONVERT(datetime2(7), CONVERT(date, [EndUtc])),
                              [EndUtc]
                          ) / 100
                        - DATEDIFF_BIG
                          (
                              NANOSECOND,
                              CONVERT(datetime2(7), CONVERT(date, [StartUtc])),
                              [StartUtc]
                          ) / 100
                )
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

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;

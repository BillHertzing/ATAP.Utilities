-- Read-only assertions for the exact approved RPRRSBSI V3 initial graph.
-- This migration intentionally contains only IF/EXISTS/SELECT/THROW validation logic.

IF SCHEMA_ID(N'ATAPUtilities') IS NULL
    THROW 54000, 'V3 assertion failed: ATAPUtilities schema is absent.', 1;

IF (SELECT COUNT_BIG(*) FROM sys.tables AS table_object INNER JOIN sys.schemas AS schema_object ON schema_object.schema_id = table_object.schema_id WHERE schema_object.name = N'ATAPUtilities') <> 11
    THROW 54001, 'V3 assertion failed: ATAPUtilities must contain exactly eleven tables.', 1;

IF EXISTS (
    SELECT 1
    FROM sys.tables AS table_object
    INNER JOIN sys.schemas AS schema_object ON schema_object.schema_id = table_object.schema_id
    WHERE schema_object.name = N'ATAPUtilities'
      AND table_object.name NOT IN (N'Philote', N'TimeBlock', N'RuleKind', N'RulePrimitive', N'RulePrimitiveInput', N'Rule', N'RuleSet', N'RuleSetRule', N'BuildSet', N'BuildSetRuleSet', N'Instantiation')
)
    THROW 54002, 'V3 assertion failed: ATAPUtilities contains a table outside the approved allowlist.', 1;

IF EXISTS (
    SELECT 1
    FROM sys.objects AS object_record
    INNER JOIN sys.schemas AS schema_object ON schema_object.schema_id = object_record.schema_id
    WHERE schema_object.name = N'ATAPUtilities'
      AND object_record.is_ms_shipped = 0
      AND object_record.type NOT IN ('U', 'PK', 'UQ', 'F', 'C')
)
    THROW 54003, 'V3 assertion failed: ATAPUtilities contains a non-table executable or compatibility object.', 1;

IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.Philote) <> 22
 OR (SELECT COUNT_BIG(*) FROM ATAPUtilities.TimeBlock) <> 0
 OR (SELECT COUNT_BIG(*) FROM ATAPUtilities.RuleKind) <> 2
 OR (SELECT COUNT_BIG(*) FROM ATAPUtilities.RulePrimitive) <> 15
 OR (SELECT COUNT_BIG(*) FROM ATAPUtilities.RulePrimitiveInput) <> 21
 OR (SELECT COUNT_BIG(*) FROM ATAPUtilities.[Rule]) <> 2
 OR (SELECT COUNT_BIG(*) FROM ATAPUtilities.RuleSet) <> 1
 OR (SELECT COUNT_BIG(*) FROM ATAPUtilities.RuleSetRule) <> 2
 OR (SELECT COUNT_BIG(*) FROM ATAPUtilities.BuildSet) <> 1
 OR (SELECT COUNT_BIG(*) FROM ATAPUtilities.BuildSetRuleSet) <> 1
 OR (SELECT COUNT_BIG(*) FROM ATAPUtilities.Instantiation) <> 1
    THROW 54004, 'V3 assertion failed: one or more table row counts differ from the approved 22/0/2/15/21/2/1/2/1/1/1 contract.', 1;

IF EXISTS (SELECT 1 FROM ATAPUtilities.Philote WHERE AdditionalIdsStub IS NOT NULL)
 OR EXISTS (SELECT 1 FROM ATAPUtilities.RuleKind WHERE RuleKindId <> PhiloteId)
 OR EXISTS (SELECT 1 FROM ATAPUtilities.RulePrimitive WHERE RulePrimitiveId <> PhiloteId)
 OR EXISTS (SELECT 1 FROM ATAPUtilities.[Rule] WHERE RuleId <> PhiloteId)
 OR EXISTS (SELECT 1 FROM ATAPUtilities.RuleSet WHERE RuleSetId <> PhiloteId)
 OR EXISTS (SELECT 1 FROM ATAPUtilities.BuildSet WHERE BuildSetId <> PhiloteId)
 OR EXISTS (SELECT 1 FROM ATAPUtilities.Instantiation WHERE InstantiationId <> PhiloteId)
    THROW 54005, 'V3 assertion failed: a Philote stub or entity/Philote identity differs from the approved contract.', 1;

IF EXISTS (
    SELECT semantic.EntityId
    FROM (
        SELECT RuleKindId AS EntityId FROM ATAPUtilities.RuleKind
        UNION ALL SELECT RulePrimitiveId FROM ATAPUtilities.RulePrimitive
        UNION ALL SELECT RuleId FROM ATAPUtilities.[Rule]
        UNION ALL SELECT RuleSetId FROM ATAPUtilities.RuleSet
        UNION ALL SELECT BuildSetId FROM ATAPUtilities.BuildSet
        UNION ALL SELECT InstantiationId FROM ATAPUtilities.Instantiation
    ) AS semantic
    GROUP BY semantic.EntityId
    HAVING COUNT_BIG(*) <> 1
) OR EXISTS (
    SELECT philote.PhiloteId FROM ATAPUtilities.Philote AS philote
    EXCEPT
    SELECT semantic.EntityId
    FROM (
        SELECT RuleKindId AS EntityId FROM ATAPUtilities.RuleKind
        UNION ALL SELECT RulePrimitiveId FROM ATAPUtilities.RulePrimitive
        UNION ALL SELECT RuleId FROM ATAPUtilities.[Rule]
        UNION ALL SELECT RuleSetId FROM ATAPUtilities.RuleSet
        UNION ALL SELECT BuildSetId FROM ATAPUtilities.BuildSet
        UNION ALL SELECT InstantiationId FROM ATAPUtilities.Instantiation
    ) AS semantic
) OR EXISTS (
    SELECT semantic.EntityId
    FROM (
        SELECT RuleKindId AS EntityId FROM ATAPUtilities.RuleKind
        UNION ALL SELECT RulePrimitiveId FROM ATAPUtilities.RulePrimitive
        UNION ALL SELECT RuleId FROM ATAPUtilities.[Rule]
        UNION ALL SELECT RuleSetId FROM ATAPUtilities.RuleSet
        UNION ALL SELECT BuildSetId FROM ATAPUtilities.BuildSet
        UNION ALL SELECT InstantiationId FROM ATAPUtilities.Instantiation
    ) AS semantic
    EXCEPT
    SELECT philote.PhiloteId FROM ATAPUtilities.Philote AS philote
)
    THROW 54006, 'V3 assertion failed: semantic GUIDs are reused or differ from the exact Philote set.', 1;

IF EXISTS (
    SELECT target.RuleKindId, target.PhiloteId, CONVERT(varbinary(64), target.RuleKindCode), CONVERT(varbinary(256), target.RuleKindName)
    FROM ATAPUtilities.RuleKind AS target
    EXCEPT
    SELECT expected.RuleKindId, expected.PhiloteId, CONVERT(varbinary(64), expected.RuleKindCode), CONVERT(varbinary(256), expected.RuleKindName)
    FROM (VALUES
        (CONVERT(uniqueidentifier, '8e06f2af-52cf-47d5-872e-0d3912f4fda0'), CONVERT(uniqueidentifier, '8e06f2af-52cf-47d5-872e-0d3912f4fda0'), CONVERT(varchar(64), 'PowerShell'), CONVERT(nvarchar(128), N'PowerShell')),
        (CONVERT(uniqueidentifier, 'b32c60e0-86f3-40e6-893e-d3240ffea882'), CONVERT(uniqueidentifier, 'b32c60e0-86f3-40e6-893e-d3240ffea882'), CONVERT(varchar(64), 'Path'), CONVERT(nvarchar(128), N'Path'))
    ) AS expected (RuleKindId, PhiloteId, RuleKindCode, RuleKindName)
) OR EXISTS (
    SELECT expected.RuleKindId, expected.PhiloteId, CONVERT(varbinary(64), expected.RuleKindCode), CONVERT(varbinary(256), expected.RuleKindName)
    FROM (VALUES
        (CONVERT(uniqueidentifier, '8e06f2af-52cf-47d5-872e-0d3912f4fda0'), CONVERT(uniqueidentifier, '8e06f2af-52cf-47d5-872e-0d3912f4fda0'), CONVERT(varchar(64), 'PowerShell'), CONVERT(nvarchar(128), N'PowerShell')),
        (CONVERT(uniqueidentifier, 'b32c60e0-86f3-40e6-893e-d3240ffea882'), CONVERT(uniqueidentifier, 'b32c60e0-86f3-40e6-893e-d3240ffea882'), CONVERT(varchar(64), 'Path'), CONVERT(nvarchar(128), N'Path'))
    ) AS expected (RuleKindId, PhiloteId, RuleKindCode, RuleKindName)
    EXCEPT
    SELECT target.RuleKindId, target.PhiloteId, CONVERT(varbinary(64), target.RuleKindCode), CONVERT(varbinary(256), target.RuleKindName)
    FROM ATAPUtilities.RuleKind AS target
)
    THROW 54007, 'V3 assertion failed: RuleKind rows differ from the exact approved catalog.', 1;

IF EXISTS (
    SELECT target.RulePrimitiveId, target.PhiloteId, target.RuleKindId, CONVERT(varbinary(256), target.RulePrimitiveCode)
    FROM ATAPUtilities.RulePrimitive AS target
    EXCEPT
    SELECT expected.RulePrimitiveId, expected.RulePrimitiveId, expected.RuleKindId, CONVERT(varbinary(256), expected.RulePrimitiveCode)
    FROM (VALUES
        ('9460f2f5-9957-4455-b6a6-8ee241b7ebb3', '8e06f2af-52cf-47d5-872e-0d3912f4fda0', N'<complete-powershell-cmdlet>'),
        ('ff659102-d147-4f1d-bd31-21978858e5fb', '8e06f2af-52cf-47d5-872e-0d3912f4fda0', N'<composed-powershell-cmdlet>'),
        ('36696ed7-e4f2-4305-b83e-5deaddd4a279', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<path>'),
        ('8263f648-2607-452e-ad69-5e4566354cc9', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<unc-path>'),
        ('f8a27327-cb7a-46f4-bc53-5a2a9945784d', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<absolute-path>'),
        ('03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<relative-path>'),
        ('9c967a82-098f-4a38-bac5-2be34529ed54', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<extended-path>'),
        ('250e84cb-abd3-4823-875d-e0e75d88cee3', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<drive>'),
        ('c810abaf-010a-426e-afda-d6881831a9e6', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<path-tail>'),
        ('197c9963-55d3-4d80-9e39-23f30bf6c57e', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<name>'),
        ('fa3311ee-3e7c-415a-9eb6-b458c793a675', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<namechar>'),
        ('520ade57-f639-45e1-b7de-e5dc3142655c', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<server>'),
        ('9b2a48bc-7c85-48cd-ac0d-a09d4b621b0a', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<share>'),
        ('9c8077ce-7abf-4d9a-969b-75631589a220', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<letter>'),
        ('8c3d6e7f-5a4b-4c9d-0e12-3c4d5e6f7081', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<atap-utilities-secrets-csproj-path>')
    ) AS expected (RulePrimitiveId, RuleKindId, RulePrimitiveCode)
) OR EXISTS (
    SELECT expected.RulePrimitiveId, expected.RulePrimitiveId, expected.RuleKindId, CONVERT(varbinary(256), expected.RulePrimitiveCode)
    FROM (VALUES
        ('9460f2f5-9957-4455-b6a6-8ee241b7ebb3', '8e06f2af-52cf-47d5-872e-0d3912f4fda0', N'<complete-powershell-cmdlet>'),
        ('ff659102-d147-4f1d-bd31-21978858e5fb', '8e06f2af-52cf-47d5-872e-0d3912f4fda0', N'<composed-powershell-cmdlet>'),
        ('36696ed7-e4f2-4305-b83e-5deaddd4a279', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<path>'),
        ('8263f648-2607-452e-ad69-5e4566354cc9', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<unc-path>'),
        ('f8a27327-cb7a-46f4-bc53-5a2a9945784d', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<absolute-path>'),
        ('03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<relative-path>'),
        ('9c967a82-098f-4a38-bac5-2be34529ed54', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<extended-path>'),
        ('250e84cb-abd3-4823-875d-e0e75d88cee3', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<drive>'),
        ('c810abaf-010a-426e-afda-d6881831a9e6', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<path-tail>'),
        ('197c9963-55d3-4d80-9e39-23f30bf6c57e', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<name>'),
        ('fa3311ee-3e7c-415a-9eb6-b458c793a675', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<namechar>'),
        ('520ade57-f639-45e1-b7de-e5dc3142655c', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<server>'),
        ('9b2a48bc-7c85-48cd-ac0d-a09d4b621b0a', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<share>'),
        ('9c8077ce-7abf-4d9a-969b-75631589a220', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<letter>'),
        ('8c3d6e7f-5a4b-4c9d-0e12-3c4d5e6f7081', 'b32c60e0-86f3-40e6-893e-d3240ffea882', N'<atap-utilities-secrets-csproj-path>')
    ) AS expected (RulePrimitiveId, RuleKindId, RulePrimitiveCode)
    EXCEPT
    SELECT target.RulePrimitiveId, target.PhiloteId, target.RuleKindId, CONVERT(varbinary(256), target.RulePrimitiveCode)
    FROM ATAPUtilities.RulePrimitive AS target
)
    THROW 54008, 'V3 assertion failed: RulePrimitive rows differ from the exact approved 2 PowerShell and 13 Path catalog.', 1;

IF EXISTS (
    SELECT target.RulePrimitiveInputId, target.RulePrimitiveId,
        CONVERT(varbinary(256), target.InputName), CONVERT(varbinary(512), target.InputType),
        CONVERT(varbinary(2048), target.InputDescription), target.DefaultValue,
        target.IsRequired, target.Ordinal
    FROM ATAPUtilities.RulePrimitiveInput AS target
    EXCEPT
    SELECT expected.RulePrimitiveInputId, expected.RulePrimitiveId,
        CONVERT(varbinary(256), expected.InputName), CONVERT(varbinary(512), expected.InputType),
        CONVERT(varbinary(2048), expected.InputDescription), expected.DefaultValue,
        expected.IsRequired, expected.Ordinal
    FROM (VALUES
        ('47cec849-5612-4a83-b916-a5ba8d36692b','36696ed7-e4f2-4305-b83e-5deaddd4a279',N'PathType',N'enum(UNC|Absolute|Relative|Extended)',N'Determines which path variant to render',CONVERT(nvarchar(4000),NULL),CONVERT(bit,1),0),
        ('1a7ecff0-b6f4-4481-a9a0-81f298f42cc0','36696ed7-e4f2-4305-b83e-5deaddd4a279',N'PathContent',N'RulePrimitive',N'Provides the actual path structure selected by PathType',NULL,1,1),
        ('7ef564cd-32dd-4319-aeb7-17a02c8a4f0f','8263f648-2607-452e-ad69-5e4566354cc9',N'Server',N'<server>',N'Provides the network server name or IP address',NULL,1,0),
        ('cb3af1f3-e2c1-49fc-9376-a2b3dd41eff5','8263f648-2607-452e-ad69-5e4566354cc9',N'Share',N'<share>',N'Provides the shared resource name on the server',NULL,1,1),
        ('bd8f280b-e7a0-45b0-b8cc-ace4cf3ada0e','8263f648-2607-452e-ad69-5e4566354cc9',N'PathTail',N'<path-tail>',N'Provides the optional directory or file path within the share',NULL,0,2),
        ('84a7a08e-152d-4e4c-8bff-71791d16fef8','f8a27327-cb7a-46f4-bc53-5a2a9945784d',N'Drive',N'<drive>',N'Provides the optional drive letter and colon',NULL,0,0),
        ('4680c930-c04b-47df-9c86-36d4b0c576c5','f8a27327-cb7a-46f4-bc53-5a2a9945784d',N'PathTail',N'<path-tail>',N'Provides the optional directory or file hierarchy',NULL,0,1),
        ('0451e48e-5e94-47df-a94b-deaca7ea1675','03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a',N'PathTail',N'<path-tail>',N'Provides the relative directory or file hierarchy',NULL,1,0),
        ('f37f15bc-683e-4ebe-a3aa-e293df4b2542','9c967a82-098f-4a38-bac5-2be34529ed54',N'PathVariant',N'enum(Local|UNC)',N'Determines whether the extended path is local or UNC',NULL,1,0),
        ('50b2f135-8b28-4ede-840b-e90871124e3e','9c967a82-098f-4a38-bac5-2be34529ed54',N'AbsolutePath',N'<absolute-path>',N'Provides the absolute path for the Local variant',NULL,0,1),
        ('9a74bda5-18cb-420b-b08c-f6db62777474','9c967a82-098f-4a38-bac5-2be34529ed54',N'Server',N'<server>',N'Provides the network server component for the UNC variant',NULL,0,2),
        ('f5ae0c3c-eb4e-4d5d-b2ab-dc80468115c1','9c967a82-098f-4a38-bac5-2be34529ed54',N'Share',N'<share>',N'Provides the shared resource component for the UNC variant',NULL,0,3),
        ('e4cb67dd-7db9-42ec-9914-0f98232a4ee3','9c967a82-098f-4a38-bac5-2be34529ed54',N'PathTail',N'<path-tail>',N'Provides the optional directory or file path for the UNC variant',NULL,0,4),
        ('fd545856-9bc3-418f-b729-3b170e440230','250e84cb-abd3-4823-875d-e0e75d88cee3',N'Letter',N'<letter>',N'Provides one alphabetic drive letter',NULL,1,0),
        ('105da8b3-6365-46cf-8231-31126df64b69','c810abaf-010a-426e-afda-d6881831a9e6',N'Name',N'<name>',N'Provides the first directory or file name',NULL,1,0),
        ('6d6731ab-f47f-4fd6-b6e9-8d9a69711a6a','c810abaf-010a-426e-afda-d6881831a9e6',N'RestOfPath',N'<path-tail>',N'Provides the optional remainder of the path hierarchy',NULL,0,1),
        ('18ee327e-0f41-406b-bfac-b99904739e82','197c9963-55d3-4d80-9e39-23f30bf6c57e',N'NameChars',N'list(<namechar>)',N'Provides the ordered characters composing the name',NULL,1,0),
        ('32318390-c6ac-4f58-ba39-b542d1b3dd87','fa3311ee-3e7c-415a-9eb6-b458c793a675',N'Character',N'char',N'Provides the single path character to validate and render',NULL,1,0),
        ('6847251f-24e9-453c-8848-5d43cc529dcf','520ade57-f639-45e1-b7de-e5dc3142655c',N'ServerIdentifier',N'<name>|IPAddressString',N'Provides the server name or IP address',NULL,1,0),
        ('1b3ca37b-f095-47e7-9f96-8dd5f4735079','9b2a48bc-7c85-48cd-ac0d-a09d4b621b0a',N'ShareName',N'<name>',N'Provides the shared resource name',NULL,1,0),
        ('ff932d94-61a4-4274-99a7-84229acbfb5b','9c8077ce-7abf-4d9a-969b-75631589a220',N'LetterChar',N'char',N'Provides one alphabetic character from A through Z or a through z',NULL,1,0)
    ) AS expected (RulePrimitiveInputId,RulePrimitiveId,InputName,InputType,InputDescription,DefaultValue,IsRequired,Ordinal)
)
    THROW 54009, 'V3 assertion failed: RulePrimitiveInput rows differ from the exact 21-declaration contract.', 1;

IF (SELECT COUNT_BIG(*) FROM ATAPUtilities.RulePrimitiveInput WHERE IsRequired = 1) <> 13
 OR (SELECT COUNT_BIG(*) FROM ATAPUtilities.RulePrimitiveInput WHERE IsRequired = 0) <> 8
 OR EXISTS (SELECT 1 FROM ATAPUtilities.RulePrimitiveInput WHERE DefaultValue IS NOT NULL)
 OR EXISTS (
    SELECT 1
    FROM ATAPUtilities.RulePrimitiveInput AS input
    WHERE input.RulePrimitiveId IN ('9460f2f5-9957-4455-b6a6-8ee241b7ebb3','ff659102-d147-4f1d-bd31-21978858e5fb','8c3d6e7f-5a4b-4c9d-0e12-3c4d5e6f7081')
 )
    THROW 54010, 'V3 assertion failed: required/optional/default or zero-input primitive policy differs.', 1;

IF EXISTS (
    SELECT 1
    FROM ATAPUtilities.[Rule] AS target
    WHERE target.RuleId = '616fb394-0b4d-486a-98af-48f1fe461af2'
      AND (target.PhiloteId <> target.RuleId
        OR target.RuleKindId <> '8e06f2af-52cf-47d5-872e-0d3912f4fda0'
        OR target.RulePrimitiveId <> '9460f2f5-9957-4455-b6a6-8ee241b7ebb3'
        OR CONVERT(varbinary(256), target.RuleCode) <> CONVERT(varbinary(256), CONVERT(varchar(128), 'HelloWorld.PowerShell'))
        OR CONVERT(varbinary(max), target.RuleBody) <> CONVERT(varbinary(max), N'function HelloWorld {' + CHAR(10) + N'  Write-Host ''Hello World''' + CHAR(10) + N'}'))
) OR NOT EXISTS (SELECT 1 FROM ATAPUtilities.[Rule] WHERE RuleId = '616fb394-0b4d-486a-98af-48f1fe461af2')
 OR EXISTS (
    SELECT 1
    FROM ATAPUtilities.[Rule] AS target
    WHERE target.RuleId = 'c5c1c63a-4364-4233-9aa1-2a1a5a2ba1f3'
      AND (target.PhiloteId <> target.RuleId
        OR target.RuleKindId <> 'b32c60e0-86f3-40e6-893e-d3240ffea882'
        OR target.RulePrimitiveId <> '03c6c7a1-f6f8-4fcc-a1aa-9239dc96109a'
        OR CONVERT(varbinary(256), target.RuleCode) <> CONVERT(varbinary(256), CONVERT(varchar(128), 'HelloWorld.Path'))
        OR CONVERT(varbinary(max), target.RuleBody) <> CONVERT(varbinary(max), N'HelloWorld.ps1'))
) OR NOT EXISTS (SELECT 1 FROM ATAPUtilities.[Rule] WHERE RuleId = 'c5c1c63a-4364-4233-9aa1-2a1a5a2ba1f3')
    THROW 54011, 'V3 assertion failed: exact Rule identity, parent, code, or body content differs.', 1;

IF NOT EXISTS (
    SELECT 1 FROM ATAPUtilities.RuleSet
    WHERE RuleSetId = '23ad4f37-2c70-4f34-9104-9868ec0f3823'
      AND PhiloteId = RuleSetId
      AND CONVERT(varbinary(256), RuleSetCode) = CONVERT(varbinary(256), CONVERT(varchar(128), 'HelloWorld'))
) OR EXISTS (
    SELECT target.RuleSetId, target.RuleId, target.Ordinal FROM ATAPUtilities.RuleSetRule AS target
    EXCEPT
    SELECT expected.RuleSetId, expected.RuleId, expected.Ordinal
    FROM (VALUES
        ('23ad4f37-2c70-4f34-9104-9868ec0f3823','616fb394-0b4d-486a-98af-48f1fe461af2',0),
        ('23ad4f37-2c70-4f34-9104-9868ec0f3823','c5c1c63a-4364-4233-9aa1-2a1a5a2ba1f3',1)
    ) AS expected (RuleSetId,RuleId,Ordinal)
)
    THROW 54012, 'V3 assertion failed: RuleSet identity or PowerShell-then-Path membership order differs.', 1;

IF NOT EXISTS (
    SELECT 1 FROM ATAPUtilities.BuildSet
    WHERE BuildSetId = '550e7722-cb57-4e47-a94b-9212b451d6fb'
      AND PhiloteId = BuildSetId
      AND CONVERT(varbinary(256), BuildSetCode) = CONVERT(varbinary(256), CONVERT(varchar(128), 'HelloWorld'))
) OR NOT EXISTS (
    SELECT 1 FROM ATAPUtilities.BuildSetRuleSet
    WHERE BuildSetId = '550e7722-cb57-4e47-a94b-9212b451d6fb'
      AND RuleSetId = '23ad4f37-2c70-4f34-9104-9868ec0f3823'
      AND Ordinal = 0
) OR NOT EXISTS (
    SELECT 1 FROM ATAPUtilities.Instantiation
    WHERE InstantiationId = '03e28494-998f-4fc2-ba5d-ad6e5832c8b7'
      AND PhiloteId = InstantiationId
      AND BuildSetId = '550e7722-cb57-4e47-a94b-9212b451d6fb'
      AND CONVERT(varbinary(256), InstantiationCode) = CONVERT(varbinary(256), CONVERT(varchar(128), 'HelloWorld'))
)
    THROW 54013, 'V3 assertion failed: BuildSet, ordered RuleSet membership, or Instantiation selection differs.', 1;

IF (SELECT COUNT_BIG(*)
    FROM ATAPUtilities.Instantiation AS instantiation
    INNER JOIN ATAPUtilities.BuildSet AS build_set ON build_set.BuildSetId = instantiation.BuildSetId
    INNER JOIN ATAPUtilities.BuildSetRuleSet AS build_membership ON build_membership.BuildSetId = build_set.BuildSetId
    INNER JOIN ATAPUtilities.RuleSet AS rule_set ON rule_set.RuleSetId = build_membership.RuleSetId
    INNER JOIN ATAPUtilities.RuleSetRule AS rule_membership ON rule_membership.RuleSetId = rule_set.RuleSetId
    INNER JOIN ATAPUtilities.[Rule] AS rule_record ON rule_record.RuleId = rule_membership.RuleId
    WHERE instantiation.InstantiationId = '03e28494-998f-4fc2-ba5d-ad6e5832c8b7'
      AND build_membership.Ordinal = 0
      AND ((rule_record.RuleId = '616fb394-0b4d-486a-98af-48f1fe461af2' AND rule_membership.Ordinal = 0)
        OR (rule_record.RuleId = 'c5c1c63a-4364-4233-9aa1-2a1a5a2ba1f3' AND rule_membership.Ordinal = 1))) <> 2
    THROW 54014, 'V3 assertion failed: the Instantiation does not reach both Rules through the exact ordered graph.', 1;

IF EXISTS (
    SELECT 1
    FROM sys.objects AS object_record
    WHERE object_record.is_ms_shipped = 0
      AND (
        object_record.name LIKE N'%Version%'
        OR object_record.name LIKE N'%Manifestation%'
        OR object_record.name LIKE N'%Execution%'
        OR object_record.name LIKE N'%Ingestion%'
        OR object_record.name LIKE N'%SourceArtifact%'
        OR object_record.name LIKE N'%SourceObservation%'
        OR object_record.name LIKE N'%SourceLocator%'
        OR object_record.name LIKE N'%Provenance%'
        OR object_record.name LIKE N'%InputBlock%'
        OR object_record.name LIKE N'%RuleInput%'
        OR object_record.name LIKE N'%ParameterValue%'
        OR object_record.name IN (N'ContentSummary',N'AgentText',N'PKIArtifact',N'Organization',N'Repository',N'User',N'Gmail',N'Tags',N'BuildMaster',N'ProGet',N'AceCommander')
      )
)
    THROW 54015, 'V3 assertion failed: an explicitly excluded object family is present.', 1;

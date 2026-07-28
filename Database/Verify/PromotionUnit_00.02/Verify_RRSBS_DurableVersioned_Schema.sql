-- Verify_RRSBS_DurableVersioned_Schema.sql
--
-- Sprint 0013 Task 13.78.j. Verifies the RRSBS durable/versioned snapshot
-- layer included in the consolidated baseline:
--   Database/Flyway/SQL/V00.01.000010__Create_ATAPUtilities_Core_Schema.sql
-- (the baseline incorporates the former durable-snapshot, membership-migration,
-- and instantiation schema components).
--
-- Five verification areas, one clearly labelled section each:
--   1. Expected schema objects   (tables, columns, PK/FK/CHECK/UNIQUE, indexes, triggers)
--   2. Input scope               (RuleInstantiation / RuleInstantiationBinding durable scope)
--   3. Unique ordering           (SortOrder unique per parent; Position contiguous 1-based)
--   4. Immutable membership      (immutability triggers exist AND are enabled)
--   5. Manifestation provenance  (every artifact resolves; no orphan provenance)
--
-- CONTRACT
--   * READ-ONLY. SELECT and system-catalog reads only. It creates one tempdb
--     scratch table for failure accumulation and drops it. It never modifies
--     ATAPUtilities data or schema, and it never runs a migration.
--   * IDEMPOTENT. Running it twice produces the same result.
--   * Every failure names the check that failed and why. There is no bare
--     pass/fail total; the total is emitted in addition to the detail.
--   * Fails loudly: each failure is RAISERROR severity 16, and a final
--     severity-16 aggregate is raised, so sqlcmd -b / Invoke-Sqlcmd exits
--     non-zero and a pipeline can gate on it.
--
-- DELIBERATE NON-ASSERTIONS (each of these is CORRECT, not a defect):
--   * InstantiationVersion.BuildSetVersionPhiloteId is NULLable. V00.02.000060
--     pre-seeded rows; a forward-only NOT NULL FK add is impossible. Existence
--     is asserted; nullability is NOT asserted.
--   * There is no InstantiationVersionBuildSetVersion junction table. Its
--     ABSENCE is asserted (section 1f).
--   * CK_ManifestationArtifact_Provenance and CK_ManifestationArtifact_ProducerPairing
--     are added WITH NOCHECK and therefore report is_not_trusted = 1. That is
--     expected. Their trust state is reported as INFO, never as a failure, so
--     that a later re-trust by Task 13.79 also passes.
--   * SortOrder is sparse (V00.02.000060 seeds 10/20/30). Contiguity of
--     SortOrder is NOT asserted; only >= 0 and uniqueness per parent.
--     Contiguity is asserted ONLY for RuleVersionPrimitiveComposition.Position.
--
-- DO NOT auto-format. SQL formatters strip "sys." from system-catalog
-- references and rewrite the guarded dynamic SQL.
-- Run via sqlcmd / Invoke-Sqlcmd targeting ATAPUtilities directly; no USE.

-- QUOTED_IDENTIFIER must be ON explicitly, not inherited from the caller.
-- sqlcmd defaults it OFF, and any INSERT touching a table that carries a
-- filtered index then fails with Msg 1934 before a single check has run.
-- Setting it here makes the artifact independent of how it is invoked.
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'tempdb..#VerifyFailure') IS NOT NULL DROP TABLE #VerifyFailure;
IF OBJECT_ID(N'tempdb..#VerifySkip') IS NOT NULL DROP TABLE #VerifySkip;
IF OBJECT_ID(N'tempdb..#VerifyInfo') IS NOT NULL DROP TABLE #VerifyInfo;

CREATE TABLE #VerifyFailure (
    FailureId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Area      NVARCHAR(40)   NOT NULL,
    CheckName NVARCHAR(80)   NOT NULL,
    Detail    NVARCHAR(1000) NOT NULL
);

CREATE TABLE #VerifySkip (
    SkipId    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Area      NVARCHAR(40)   NOT NULL,
    CheckName NVARCHAR(80)   NOT NULL,
    Reason    NVARCHAR(1000) NOT NULL
);

CREATE TABLE #VerifyInfo (
    InfoId  INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Area    NVARCHAR(40)   NOT NULL,
    Detail  NVARCHAR(1000) NOT NULL
);

DECLARE @errCount   INT = 0;
DECLARE @msg        NVARCHAR(1200);
DECLARE @name       SYSNAME;
DECLARE @otherName  SYSNAME;
DECLARE @kind       NVARCHAR(20);

-- =====================================================================
-- SECTION 0 - schema and prerequisite objects
--
-- These must exist before any later section can mean anything. Later
-- sections that query a missing table are SKIPPED (recorded in #VerifySkip)
-- rather than aborting the batch with error 208.
-- =====================================================================

IF SCHEMA_ID(N'ATAPUtilities') IS NULL
    INSERT INTO #VerifyFailure (Area, CheckName, Detail)
    VALUES (N'0-Prerequisite', N'Schema', N'schema [ATAPUtilities] is missing');

DECLARE @prereqTables TABLE (TableName SYSNAME PRIMARY KEY, Origin NVARCHAR(40) NOT NULL);
INSERT INTO @prereqTables (TableName, Origin) VALUES
    (N'Philote',                  N'V00.01.000010'),
    (N'RulePrimitive',            N'V00.01.000010'),
    (N'Rule',                     N'V00.01.000010'),
    (N'RuleSet',                  N'V00.01.000010'),
    (N'BuildSet',                 N'V00.01.000010'),
    (N'RuleInstantiation',        N'V00.01.000010'),
    (N'RuleInstantiationBinding', N'V00.01.000010'),
    (N'Instantiation',            N'V00.02.000060'),
    (N'InstantiationVersion',     N'V00.02.000060'),
    (N'ManifestationArtifact',    N'V00.02.000060');

INSERT INTO #VerifyFailure (Area, CheckName, Detail)
SELECT N'0-Prerequisite', N'PrerequisiteTable',
       N'prerequisite table [ATAPUtilities].[' + p.TableName + N'] is missing (expected from ' + p.Origin + N')'
FROM @prereqTables AS p
WHERE OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(p.TableName), N'U') IS NULL;

-- Provenance leg 1 predates V00.02.000070 and is asserted, not created, by it.
IF OBJECT_ID(N'ATAPUtilities.FK_ManifestationArtifact_Version', N'F') IS NULL
    INSERT INTO #VerifyFailure (Area, CheckName, Detail)
    VALUES (N'0-Prerequisite', N'PrerequisiteForeignKey',
            N'FK_ManifestationArtifact_Version (ManifestationArtifact -> InstantiationVersion) is missing; provenance leg 1 is absent');

-- =====================================================================
-- SECTION 1 - EXPECTED SCHEMA OBJECTS
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1a. New tables (8)
-- ---------------------------------------------------------------------
DECLARE @expectedTables TABLE (TableName SYSNAME PRIMARY KEY);
INSERT INTO @expectedTables (TableName) VALUES
    (N'RuleVersion'),
    (N'RuleVersionPrimitiveComposition'),
    (N'RuleSetVersion'),
    (N'RuleSetVersionMember'),
    (N'BuildSetVersion'),
    (N'BuildSetVersionMember'),
    (N'RuleInstantiationVersion'),
    (N'InstantiationVersionRuleInstantiationVersion');

INSERT INTO #VerifyFailure (Area, CheckName, Detail)
SELECT N'1-Objects', N'Table',
       N'table [ATAPUtilities].[' + e.TableName + N'] is missing (V00.02.000070 not applied?)'
FROM @expectedTables AS e
WHERE OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(e.TableName), N'U') IS NULL;

-- ---------------------------------------------------------------------
-- 1b. Expected columns, including the columns the deployed consumer
--     Get-InstantiationVersionRuleGraph.ps1 joins and orders on.
-- ---------------------------------------------------------------------
DECLARE @expectedColumns TABLE (TableName SYSNAME NOT NULL, ColumnName SYSNAME NOT NULL,
    PRIMARY KEY (TableName, ColumnName));
INSERT INTO @expectedColumns (TableName, ColumnName) VALUES
    (N'RuleVersion', N'RuleVersionPhiloteId'),
    (N'RuleVersion', N'RulePhiloteId'),
    (N'RuleVersion', N'VersionNumber'),
    (N'RuleVersion', N'VersionLabel'),
    (N'RuleVersion', N'ParentRuleVersionPhiloteId'),
    (N'RuleVersion', N'SortOrder'),
    (N'RuleVersion', N'ContentSha256'),
    (N'RuleVersion', N'CreatedAt'),
    (N'RuleVersion', N'Notes'),

    (N'RuleVersionPrimitiveComposition', N'RuleVersionPrimitiveCompositionId'),
    (N'RuleVersionPrimitiveComposition', N'RuleVersionPhiloteId'),
    (N'RuleVersionPrimitiveComposition', N'PrimitivePhiloteId'),
    (N'RuleVersionPrimitiveComposition', N'Position'),
    (N'RuleVersionPrimitiveComposition', N'IsOptional'),
    (N'RuleVersionPrimitiveComposition', N'Cardinality'),
    (N'RuleVersionPrimitiveComposition', N'BoundInputsJson'),
    (N'RuleVersionPrimitiveComposition', N'Notes'),

    (N'RuleSetVersion', N'RuleSetVersionPhiloteId'),
    (N'RuleSetVersion', N'RuleSetPhiloteId'),
    (N'RuleSetVersion', N'VersionNumber'),
    (N'RuleSetVersion', N'VersionLabel'),
    (N'RuleSetVersion', N'ParentRuleSetVersionPhiloteId'),
    (N'RuleSetVersion', N'SortOrder'),
    (N'RuleSetVersion', N'CreatedAt'),
    (N'RuleSetVersion', N'Notes'),

    (N'RuleSetVersionMember', N'RuleSetVersionMemberId'),
    (N'RuleSetVersionMember', N'RuleSetVersionPhiloteId'),
    (N'RuleSetVersionMember', N'RuleVersionPhiloteId'),
    (N'RuleSetVersionMember', N'SortOrder'),
    (N'RuleSetVersionMember', N'Notes'),

    (N'BuildSetVersion', N'BuildSetVersionPhiloteId'),
    (N'BuildSetVersion', N'BuildSetPhiloteId'),
    (N'BuildSetVersion', N'VersionNumber'),
    (N'BuildSetVersion', N'VersionLabel'),
    (N'BuildSetVersion', N'ParentBuildSetVersionPhiloteId'),
    (N'BuildSetVersion', N'SortOrder'),
    (N'BuildSetVersion', N'CreatedAt'),
    (N'BuildSetVersion', N'Notes'),

    (N'BuildSetVersionMember', N'BuildSetVersionMemberId'),
    (N'BuildSetVersionMember', N'BuildSetVersionPhiloteId'),
    (N'BuildSetVersionMember', N'RuleSetVersionPhiloteId'),
    (N'BuildSetVersionMember', N'SortOrder'),
    (N'BuildSetVersionMember', N'Notes'),

    (N'RuleInstantiationVersion', N'RuleInstantiationVersionPhiloteId'),
    (N'RuleInstantiationVersion', N'RuleInstantiationPhiloteId'),
    (N'RuleInstantiationVersion', N'RuleVersionPhiloteId'),
    (N'RuleInstantiationVersion', N'RulePhiloteId'),
    (N'RuleInstantiationVersion', N'VersionNumber'),
    (N'RuleInstantiationVersion', N'VersionLabel'),
    (N'RuleInstantiationVersion', N'ParentRuleInstantiationVersionPhiloteId'),
    (N'RuleInstantiationVersion', N'CreatedAt'),
    (N'RuleInstantiationVersion', N'Notes'),

    (N'InstantiationVersionRuleInstantiationVersion', N'InstantiationVersionRuleInstantiationVersionId'),
    (N'InstantiationVersionRuleInstantiationVersion', N'InstantiationVersionPhiloteId'),
    (N'InstantiationVersionRuleInstantiationVersion', N'RuleInstantiationVersionPhiloteId'),
    (N'InstantiationVersionRuleInstantiationVersion', N'SortOrder'),
    (N'InstantiationVersionRuleInstantiationVersion', N'Notes'),

    -- forward-only additions to pre-existing tables
    (N'InstantiationVersion', N'BuildSetVersionPhiloteId'),
    (N'RuleInstantiation', N'PhiloteId'),
    (N'RuleInstantiation', N'RulePhiloteId'),
    (N'RuleInstantiation', N'InstantiationPhiloteId'),
    (N'RuleInstantiationBinding', N'InstantiationPhiloteId'),
    (N'RuleInstantiationBinding', N'InputName'),
    (N'RuleInstantiationBinding', N'InputValue'),
    (N'ManifestationArtifact', N'InstantiationVersionPhiloteId'),
    (N'ManifestationArtifact', N'RenderPolicy'),
    (N'ManifestationArtifact', N'BuildSetVersionPhiloteId'),
    (N'ManifestationArtifact', N'ProducingRuleInstantiationPhiloteId'),
    (N'ManifestationArtifact', N'ProducingRuleInstantiationVersionPhiloteId');

INSERT INTO #VerifyFailure (Area, CheckName, Detail)
SELECT N'1-Objects', N'Column',
       N'column [ATAPUtilities].[' + e.TableName + N'].[' + e.ColumnName + N'] is missing'
FROM @expectedColumns AS e
WHERE OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(e.TableName), N'U') IS NOT NULL
  AND COL_LENGTH(N'ATAPUtilities.' + QUOTENAME(e.TableName), e.ColumnName) IS NULL;

-- ---------------------------------------------------------------------
-- 1c. Expected constraints: 8 PK, 27 FK, 19 CHECK, 17 UNIQUE
-- ---------------------------------------------------------------------
DECLARE @expectedConstraints TABLE (ConstraintName SYSNAME PRIMARY KEY, ObjectType NVARCHAR(2) NOT NULL,
    Description NVARCHAR(40) NOT NULL);
INSERT INTO @expectedConstraints (ConstraintName, ObjectType, Description) VALUES
    -- primary keys
    (N'PK_RuleVersion',                                    N'PK', N'primary key'),
    (N'PK_RuleVersionPrimitiveComposition',                N'PK', N'primary key'),
    (N'PK_RuleSetVersion',                                 N'PK', N'primary key'),
    (N'PK_RuleSetVersionMember',                           N'PK', N'primary key'),
    (N'PK_BuildSetVersion',                                N'PK', N'primary key'),
    (N'PK_BuildSetVersionMember',                          N'PK', N'primary key'),
    (N'PK_RuleInstantiationVersion',                       N'PK', N'primary key'),
    (N'PK_InstantiationVersionRuleInstantiationVersion',   N'PK', N'primary key'),
    -- foreign keys
    (N'FK_RuleVersion_Philote',                            N'F',  N'foreign key'),
    (N'FK_RuleVersion_Rule',                               N'F',  N'foreign key'),
    (N'FK_RuleVersion_Parent',                             N'F',  N'foreign key'),
    (N'FK_RuleVersionPrimitiveComposition_RuleVersion',    N'F',  N'foreign key'),
    (N'FK_RuleVersionPrimitiveComposition_Primitive',      N'F',  N'foreign key'),
    (N'FK_RuleSetVersion_Philote',                         N'F',  N'foreign key'),
    (N'FK_RuleSetVersion_RuleSet',                         N'F',  N'foreign key'),
    (N'FK_RuleSetVersion_Parent',                          N'F',  N'foreign key'),
    (N'FK_RuleSetVersionMember_RuleSetVersion',            N'F',  N'foreign key'),
    (N'FK_RuleSetVersionMember_RuleVersion',               N'F',  N'foreign key'),
    (N'FK_BuildSetVersion_Philote',                        N'F',  N'foreign key'),
    (N'FK_BuildSetVersion_BuildSet',                       N'F',  N'foreign key'),
    (N'FK_BuildSetVersion_Parent',                         N'F',  N'foreign key'),
    (N'FK_BuildSetVersionMember_BuildSetVersion',          N'F',  N'foreign key'),
    (N'FK_BuildSetVersionMember_RuleSetVersion',           N'F',  N'foreign key'),
    (N'FK_InstantiationVersion_BuildSetVersion',           N'F',  N'foreign key'),
    (N'FK_RuleInstantiation_Instantiation',                N'F',  N'foreign key'),
    (N'FK_RuleInstantiationVersion_Philote',               N'F',  N'foreign key'),
    (N'FK_RuleInstantiationVersion_RuleInstantiation',     N'F',  N'foreign key'),
    (N'FK_RuleInstantiationVersion_RuleVersion',           N'F',  N'foreign key'),
    (N'FK_RuleInstantiationVersion_Parent',                N'F',  N'foreign key'),
    (N'FK_IVRIV_InstantiationVersion',                     N'F',  N'foreign key'),
    (N'FK_IVRIV_RuleInstantiationVersion',                 N'F',  N'foreign key'),
    (N'FK_ManifestationArtifact_BuildSetVersion',          N'F',  N'foreign key'),
    (N'FK_ManifestationArtifact_RuleInstantiation',        N'F',  N'foreign key'),
    (N'FK_ManifestationArtifact_RuleInstantiationVersion', N'F',  N'foreign key'),
    -- check constraints
    (N'CK_RuleVersion_Number',                             N'C',  N'check constraint'),
    (N'CK_RuleVersion_SortOrder',                          N'C',  N'check constraint'),
    (N'CK_RuleVersion_ParentNotSelf',                      N'C',  N'check constraint'),
    (N'CK_RuleVersionPrimitiveComposition_Position',       N'C',  N'check constraint'),
    (N'CK_RuleVersionPrimitiveComposition_Cardinality',    N'C',  N'check constraint'),
    (N'CK_RuleVersionPrimitiveComposition_BoundInputsJson', N'C', N'check constraint'),
    (N'CK_RuleSetVersion_Number',                          N'C',  N'check constraint'),
    (N'CK_RuleSetVersion_SortOrder',                       N'C',  N'check constraint'),
    (N'CK_RuleSetVersion_ParentNotSelf',                   N'C',  N'check constraint'),
    (N'CK_RuleSetVersionMember_SortOrder',                 N'C',  N'check constraint'),
    (N'CK_BuildSetVersion_Number',                         N'C',  N'check constraint'),
    (N'CK_BuildSetVersion_SortOrder',                      N'C',  N'check constraint'),
    (N'CK_BuildSetVersion_ParentNotSelf',                  N'C',  N'check constraint'),
    (N'CK_BuildSetVersionMember_SortOrder',                N'C',  N'check constraint'),
    (N'CK_RuleInstantiationVersion_Number',                N'C',  N'check constraint'),
    (N'CK_RuleInstantiationVersion_ParentNotSelf',         N'C',  N'check constraint'),
    (N'CK_IVRIV_SortOrder',                                N'C',  N'check constraint'),
    (N'CK_ManifestationArtifact_Provenance',               N'C',  N'check constraint'),
    (N'CK_ManifestationArtifact_ProducerPairing',          N'C',  N'check constraint'),
    -- unique constraints
    (N'UQ_RuleVersion_Number',                             N'UQ', N'unique constraint'),
    (N'UQ_RuleVersion_Label',                              N'UQ', N'unique constraint'),
    (N'UQ_RuleVersion_Version_Rule',                       N'UQ', N'unique constraint'),
    (N'UQ_RuleVersionPrimitiveComposition_Position',       N'UQ', N'unique constraint'),
    (N'UQ_RuleSetVersion_Number',                          N'UQ', N'unique constraint'),
    (N'UQ_RuleSetVersion_Label',                           N'UQ', N'unique constraint'),
    (N'UQ_RuleSetVersionMember_SortOrder',                 N'UQ', N'unique constraint'),
    (N'UQ_RuleSetVersionMember_RuleVersion',               N'UQ', N'unique constraint'),
    (N'UQ_BuildSetVersion_Number',                         N'UQ', N'unique constraint'),
    (N'UQ_BuildSetVersion_Label',                          N'UQ', N'unique constraint'),
    (N'UQ_BuildSetVersionMember_SortOrder',                N'UQ', N'unique constraint'),
    (N'UQ_BuildSetVersionMember_RuleSetVersion',           N'UQ', N'unique constraint'),
    (N'UQ_RuleInstantiationVersion_Number',                N'UQ', N'unique constraint'),
    (N'UQ_RuleInstantiationVersion_Label',                 N'UQ', N'unique constraint'),
    (N'UQ_IVRIV_SortOrder',                                N'UQ', N'unique constraint'),
    (N'UQ_IVRIV_RuleInstantiationVersion',                 N'UQ', N'unique constraint'),
    (N'UQ_RuleInstantiation_Instantiation_Rule',           N'UQ', N'unique constraint');

INSERT INTO #VerifyFailure (Area, CheckName, Detail)
SELECT N'1-Objects', N'Constraint',
       e.Description + N' [ATAPUtilities].[' + e.ConstraintName + N'] is missing'
FROM @expectedConstraints AS e
WHERE OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(e.ConstraintName), e.ObjectType) IS NULL;

-- The two cross-Rule guards only work if they really are COMPOSITE (2-column)
-- foreign keys. A single-column rewrite would silently stop blocking a
-- RuleInstantiationVersion that binds a RuleVersion of a different Rule.
DECLARE @compositeForeignKeys TABLE (ConstraintName SYSNAME PRIMARY KEY, ExpectedColumnCount INT NOT NULL);
INSERT INTO @compositeForeignKeys (ConstraintName, ExpectedColumnCount) VALUES
    (N'FK_RuleInstantiationVersion_RuleInstantiation', 2),
    (N'FK_RuleInstantiationVersion_RuleVersion',       2);

INSERT INTO #VerifyFailure (Area, CheckName, Detail)
SELECT N'1-Objects', N'CompositeForeignKey',
       N'foreign key [' + c.ConstraintName + N'] has '
       + CAST(ISNULL((SELECT COUNT(*) FROM sys.foreign_key_columns AS fkc
                      WHERE fkc.constraint_object_id = OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(c.ConstraintName))), 0) AS NVARCHAR(10))
       + N' column(s); expected ' + CAST(c.ExpectedColumnCount AS NVARCHAR(10))
       + N'. A non-composite form no longer blocks cross-Rule binding.'
FROM @compositeForeignKeys AS c
WHERE OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(c.ConstraintName), N'F') IS NOT NULL
  AND ISNULL((SELECT COUNT(*) FROM sys.foreign_key_columns AS fkc
              WHERE fkc.constraint_object_id = OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(c.ConstraintName))), 0) <> c.ExpectedColumnCount;

-- ---------------------------------------------------------------------
-- 1d. Expected indexes (13)
-- ---------------------------------------------------------------------
DECLARE @expectedIndexes TABLE (TableName SYSNAME NOT NULL, IndexName SYSNAME NOT NULL,
    PRIMARY KEY (TableName, IndexName));
INSERT INTO @expectedIndexes (TableName, IndexName) VALUES
    (N'RuleVersion',                                  N'IX_RuleVersion_Rule'),
    (N'RuleVersionPrimitiveComposition',              N'IX_RuleVersionPrimitiveComposition_Primitive'),
    (N'RuleSetVersion',                               N'IX_RuleSetVersion_RuleSet'),
    (N'RuleSetVersionMember',                         N'IX_RuleSetVersionMember_RuleVersion'),
    (N'BuildSetVersion',                              N'IX_BuildSetVersion_BuildSet'),
    (N'BuildSetVersionMember',                        N'IX_BuildSetVersionMember_RuleSetVersion'),
    (N'RuleInstantiationVersion',                     N'IX_RuleInstantiationVersion_RuleVersion'),
    (N'InstantiationVersionRuleInstantiationVersion', N'IX_IVRIV_RuleInstantiationVersion'),
    (N'InstantiationVersion',                         N'IX_InstantiationVersion_BuildSetVersion'),
    (N'RuleInstantiation',                            N'UX_RuleInstantiation_Instantiation_Rule'),
    (N'RuleInstantiationBinding',                     N'IX_RuleInstantiationBinding_Instantiation'),
    (N'ManifestationArtifact',                        N'IX_ManifestationArtifact_BuildSetVersion'),
    (N'ManifestationArtifact',                        N'IX_ManifestationArtifact_Producer');

INSERT INTO #VerifyFailure (Area, CheckName, Detail)
SELECT N'1-Objects', N'Index',
       N'index [' + e.IndexName + N'] on [ATAPUtilities].[' + e.TableName + N'] is missing'
FROM @expectedIndexes AS e
WHERE INDEXPROPERTY(OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(e.TableName)), e.IndexName, N'IndexID') IS NULL;

-- UX_RuleInstantiation_Instantiation_Rule must be UNIQUE and FILTERED. If the
-- filter were dropped, the pre-existing rows with NULL InstantiationPhiloteId
-- would collide; if uniqueness were dropped, two RuleInstantiations of the
-- same Rule could exist in one Instantiation.
INSERT INTO #VerifyFailure (Area, CheckName, Detail)
SELECT N'1-Objects', N'FilteredUniqueIndex',
       N'index [UX_RuleInstantiation_Instantiation_Rule] must be unique and filtered; is_unique='
       + CAST(i.is_unique AS NVARCHAR(2)) + N', has_filter=' + CAST(i.has_filter AS NVARCHAR(2))
FROM sys.indexes AS i
WHERE i.object_id = OBJECT_ID(N'ATAPUtilities.RuleInstantiation')
  AND i.[name] = N'UX_RuleInstantiation_Instantiation_Rule'
  AND (i.is_unique = 0 OR i.has_filter = 0);

-- ---------------------------------------------------------------------
-- 1e. Expected triggers (10) - existence only here; enabled-state and
--     event coverage are asserted in section 4.
-- ---------------------------------------------------------------------
DECLARE @expectedTriggers TABLE (TriggerName SYSNAME PRIMARY KEY, TableName SYSNAME NOT NULL,
    TriggerRole NVARCHAR(20) NOT NULL);
INSERT INTO @expectedTriggers (TriggerName, TableName, TriggerRole) VALUES
    (N'TR_RuleVersion_Immutable',                         N'RuleVersion',                                  N'Immutability'),
    (N'TR_RuleVersionPrimitiveComposition_Immutable',     N'RuleVersionPrimitiveComposition',              N'Immutability'),
    (N'TR_RuleSetVersion_Immutable',                      N'RuleSetVersion',                               N'Immutability'),
    (N'TR_RuleSetVersionMember_Immutable',                N'RuleSetVersionMember',                         N'Immutability'),
    (N'TR_BuildSetVersion_Immutable',                     N'BuildSetVersion',                              N'Immutability'),
    (N'TR_BuildSetVersionMember_Immutable',               N'BuildSetVersionMember',                        N'Immutability'),
    (N'TR_RuleInstantiationVersion_Immutable',            N'RuleInstantiationVersion',                     N'Immutability'),
    (N'TR_IVRIV_Immutable',                               N'InstantiationVersionRuleInstantiationVersion', N'Immutability'),
    (N'TR_RuleVersionPrimitiveComposition_ContiguousPosition', N'RuleVersionPrimitiveComposition',         N'Ordering'),
    (N'TR_ManifestationArtifact_Provenance',              N'ManifestationArtifact',                        N'Provenance');

INSERT INTO #VerifyFailure (Area, CheckName, Detail)
SELECT N'1-Objects', N'Trigger',
       N'trigger [ATAPUtilities].[' + e.TriggerName + N'] on [' + e.TableName + N'] is missing ('
       + e.TriggerRole + N' enforcement absent)'
FROM @expectedTriggers AS e
WHERE OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(e.TriggerName), N'TR') IS NULL;

-- ---------------------------------------------------------------------
-- 1f. Objects that must NOT exist.
--     The InstantiationVersion -> BuildSetVersion relationship is a single
--     nullable FK column, not a junction table; and a BuildSetVersion
--     contains RuleSetVersions directly, so no Build/BuildVersion entity
--     and no *VersionRuleVersion / *VersionRuleSetVersion membership names.
-- ---------------------------------------------------------------------
DECLARE @forbiddenTables TABLE (TableName SYSNAME PRIMARY KEY, Reason NVARCHAR(200) NOT NULL);
INSERT INTO @forbiddenTables (TableName, Reason) VALUES
    (N'InstantiationVersionBuildSetVersion',
        N'the relationship is the single nullable FK column InstantiationVersion.BuildSetVersionPhiloteId, not a junction table'),
    (N'Build',
        N'no Build entity exists in the RRSBS layering'),
    (N'BuildVersion',
        N'no BuildVersion entity exists; a BuildSetVersion contains RuleSetVersions directly'),
    (N'RuleSetVersionRuleVersion',
        N'membership table is named RuleSetVersionMember'),
    (N'BuildSetVersionRuleSetVersion',
        N'membership table is named BuildSetVersionMember');

INSERT INTO #VerifyFailure (Area, CheckName, Detail)
SELECT N'1-Objects', N'ForbiddenTable',
       N'table [ATAPUtilities].[' + f.TableName + N'] must NOT exist: ' + f.Reason
FROM @forbiddenTables AS f
WHERE OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(f.TableName), N'U') IS NOT NULL;

-- ---------------------------------------------------------------------
-- 1g. INFO only: trust state of the two WITH NOCHECK constraints.
--     is_not_trusted = 1 is the expected post-V00.02.000070 state and is
--     NOT a failure. Task 13.79 may re-trust them; that is also not a
--     failure. Reported so the operator can see which state is in force.
-- ---------------------------------------------------------------------
INSERT INTO #VerifyInfo (Area, Detail)
SELECT N'1-Objects',
       N'CHECK [' + cc.[name] + N'] is_not_trusted=' + CAST(cc.is_not_trusted AS NVARCHAR(2))
       + N' (WITH NOCHECK at creation is expected; either state passes)'
FROM sys.check_constraints AS cc
WHERE cc.[name] IN (N'CK_ManifestationArtifact_Provenance', N'CK_ManifestationArtifact_ProducerPairing');

-- =====================================================================
-- SECTION 2 - INPUT SCOPE
--
-- Every RuleInstantiation and RuleInstantiationBinding row that belongs to
-- the durable Instantiation scope of 13.77.g must resolve cleanly. These are
-- run as guarded dynamic SQL so a missing table skips the check instead of
-- aborting the batch with "invalid object name".
-- =====================================================================

IF OBJECT_ID(N'ATAPUtilities.RuleInstantiation', N'U') IS NOT NULL
   AND OBJECT_ID(N'ATAPUtilities.RuleInstantiationBinding', N'U') IS NOT NULL
BEGIN
    -- IS-1: binding rows must resolve to a RuleInstantiation.
    EXEC sp_executesql N'
        INSERT INTO #VerifyFailure (Area, CheckName, Detail)
        SELECT N''2-InputScope'', N''BindingOrphan'',
               N''RuleInstantiationBinding InstantiationPhiloteId '' + CAST(rib.InstantiationPhiloteId AS NVARCHAR(36))
               + N'' (InputName '' + rib.InputName + N'') has no RuleInstantiation parent''
        FROM ATAPUtilities.RuleInstantiationBinding AS rib
        WHERE NOT EXISTS (
            SELECT 1 FROM ATAPUtilities.RuleInstantiation AS ri
            WHERE ri.PhiloteId = rib.InstantiationPhiloteId
        );';

    -- IS-2: a RuleInstantiation must name a real durable Rule.
    EXEC sp_executesql N'
        INSERT INTO #VerifyFailure (Area, CheckName, Detail)
        SELECT N''2-InputScope'', N''RuleInstantiationRuleOrphan'',
               N''RuleInstantiation '' + CAST(ri.PhiloteId AS NVARCHAR(36))
               + N'' names RulePhiloteId '' + CAST(ri.RulePhiloteId AS NVARCHAR(36)) + N'' which is not in ATAPUtilities.[Rule]''
        FROM ATAPUtilities.RuleInstantiation AS ri
        WHERE NOT EXISTS (
            SELECT 1 FROM ATAPUtilities.[Rule] AS r WHERE r.PhiloteId = ri.RulePhiloteId
        );';
END
ELSE
    INSERT INTO #VerifySkip (Area, CheckName, Reason)
    VALUES (N'2-InputScope', N'BindingOrphan/RuleInstantiationRuleOrphan',
            N'skipped: ATAPUtilities.RuleInstantiation or RuleInstantiationBinding is missing');

IF OBJECT_ID(N'ATAPUtilities.RuleInstantiation', N'U') IS NOT NULL
   AND OBJECT_ID(N'ATAPUtilities.Instantiation', N'U') IS NOT NULL
   AND COL_LENGTH(N'ATAPUtilities.RuleInstantiation', N'InstantiationPhiloteId') IS NOT NULL
BEGIN
    -- IS-3: a named owning Instantiation must exist.
    EXEC sp_executesql N'
        INSERT INTO #VerifyFailure (Area, CheckName, Detail)
        SELECT N''2-InputScope'', N''InstantiationOwnerOrphan'',
               N''RuleInstantiation '' + CAST(ri.PhiloteId AS NVARCHAR(36))
               + N'' names InstantiationPhiloteId '' + CAST(ri.InstantiationPhiloteId AS NVARCHAR(36))
               + N'' which is not in ATAPUtilities.Instantiation''
        FROM ATAPUtilities.RuleInstantiation AS ri
        WHERE ri.InstantiationPhiloteId IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM ATAPUtilities.Instantiation AS i
              WHERE i.InstantiationPhiloteId = ri.InstantiationPhiloteId
          );';

    -- IS-4: at most one RuleInstantiation per (Instantiation, Rule) pair.
    --       Duplicate-detection independent of the filtered unique index, so
    --       dropping that index is caught here rather than passing silently.
    EXEC sp_executesql N'
        INSERT INTO #VerifyFailure (Area, CheckName, Detail)
        SELECT N''2-InputScope'', N''DuplicateRuleInstantiation'',
               N''Instantiation '' + CAST(ri.InstantiationPhiloteId AS NVARCHAR(36))
               + N'' has '' + CAST(COUNT(*) AS NVARCHAR(10)) + N'' RuleInstantiation rows for Rule ''
               + CAST(ri.RulePhiloteId AS NVARCHAR(36)) + N''; expected at most 1''
        FROM ATAPUtilities.RuleInstantiation AS ri
        WHERE ri.InstantiationPhiloteId IS NOT NULL
        GROUP BY ri.InstantiationPhiloteId, ri.RulePhiloteId
        HAVING COUNT(*) > 1;';

    -- IS-5: anything V00.02.000080 migrated into the durable input model must
    --       be anchored to an owning Instantiation. Keyed on the Notes marker
    --       that migration writes, so this stays decoupled from its GUID list.
    EXEC sp_executesql N'
        INSERT INTO #VerifyFailure (Area, CheckName, Detail)
        SELECT N''2-InputScope'', N''MigratedRowUnanchored'',
               N''RuleInstantiation '' + CAST(ri.PhiloteId AS NVARCHAR(36))
               + N'' was migrated by V00.02.000080 but has a NULL InstantiationPhiloteId; ''
               + N''it is outside the durable Instantiation scope''
        FROM ATAPUtilities.RuleInstantiation AS ri
        WHERE ri.InstantiationPhiloteId IS NULL
          AND ri.Notes LIKE N''Migrated by V00.02.000080%'';';

    -- INFO: legacy rows that predate the durable owning-Instantiation column.
    -- These are NOT a failure; they are pre-V00.02.000070 seed rows outside
    -- the durable Instantiation scope. Reported so the count is visible.
    EXEC sp_executesql N'
        INSERT INTO #VerifyInfo (Area, Detail)
        SELECT N''2-InputScope'',
               N''RuleInstantiation rows with NULL InstantiationPhiloteId (outside durable Instantiation scope): ''
               + CAST(COUNT(*) AS NVARCHAR(10))
        FROM ATAPUtilities.RuleInstantiation
        WHERE InstantiationPhiloteId IS NULL;';
END
ELSE
    INSERT INTO #VerifySkip (Area, CheckName, Reason)
    VALUES (N'2-InputScope', N'InstantiationOwner*',
            N'skipped: RuleInstantiation.InstantiationPhiloteId or ATAPUtilities.Instantiation is missing');

IF OBJECT_ID(N'ATAPUtilities.RuleInstantiationVersion', N'U') IS NOT NULL
   AND OBJECT_ID(N'ATAPUtilities.RuleInstantiation', N'U') IS NOT NULL
   AND OBJECT_ID(N'ATAPUtilities.RuleVersion', N'U') IS NOT NULL
BEGIN
    -- IS-6: a RuleInstantiationVersion must snapshot a RuleVersion of the SAME
    --       durable Rule as the RuleInstantiation it snapshots. Enforced by two
    --       composite FKs; verified here independently so a weakened FK is caught.
    EXEC sp_executesql N'
        INSERT INTO #VerifyFailure (Area, CheckName, Detail)
        SELECT N''2-InputScope'', N''CrossRuleBinding'',
               N''RuleInstantiationVersion '' + CAST(riv.RuleInstantiationVersionPhiloteId AS NVARCHAR(36))
               + N'' binds a RuleVersion of Rule '' + CAST(ISNULL(rv.RulePhiloteId, ri.RulePhiloteId) AS NVARCHAR(36))
               + N'' to a RuleInstantiation of Rule '' + CAST(ri.RulePhiloteId AS NVARCHAR(36))
        FROM ATAPUtilities.RuleInstantiationVersion AS riv
        LEFT JOIN ATAPUtilities.RuleInstantiation AS ri ON ri.PhiloteId = riv.RuleInstantiationPhiloteId
        LEFT JOIN ATAPUtilities.RuleVersion AS rv ON rv.RuleVersionPhiloteId = riv.RuleVersionPhiloteId
        WHERE ri.PhiloteId IS NULL
           OR rv.RuleVersionPhiloteId IS NULL
           OR ri.RulePhiloteId <> riv.RulePhiloteId
           OR rv.RulePhiloteId <> riv.RulePhiloteId;';
END
ELSE
    INSERT INTO #VerifySkip (Area, CheckName, Reason)
    VALUES (N'2-InputScope', N'CrossRuleBinding',
            N'skipped: RuleInstantiationVersion, RuleInstantiation or RuleVersion is missing');

-- =====================================================================
-- SECTION 3 - UNIQUE ORDERING
--
-- Two DIFFERENT contracts, asserted differently on purpose:
--   * SortOrder  -> sparse, >= 0, unique within its parent. NOT contiguous.
--   * Position   -> contiguous 1-based per RuleVersion, no gaps, no duplicates.
-- =====================================================================

-- 3a. SortOrder >= 0 on every table that carries one.
DECLARE @sortOrderTables TABLE (TableName SYSNAME PRIMARY KEY);
INSERT INTO @sortOrderTables (TableName) VALUES
    (N'RuleVersion'),
    (N'RuleSetVersion'),
    (N'RuleSetVersionMember'),
    (N'BuildSetVersion'),
    (N'BuildSetVersionMember'),
    (N'InstantiationVersionRuleInstantiationVersion');

DECLARE @sortSql NVARCHAR(MAX);

DECLARE sortOrder_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT TableName FROM @sortOrderTables
    WHERE OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(TableName), N'U') IS NOT NULL
      AND COL_LENGTH(N'ATAPUtilities.' + QUOTENAME(TableName), N'SortOrder') IS NOT NULL;
OPEN sortOrder_cur;
FETCH NEXT FROM sortOrder_cur INTO @name;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sortSql =
        N'INSERT INTO #VerifyFailure (Area, CheckName, Detail)
          SELECT N''3-Ordering'', N''NegativeSortOrder'',
                 N''[ATAPUtilities].[' + @name + N'] has '' + CAST(COUNT(*) AS NVARCHAR(10))
                 + N'' row(s) with SortOrder < 0; SortOrder must be >= 0''
          FROM ATAPUtilities.' + QUOTENAME(@name) + N'
          WHERE SortOrder < 0
          HAVING COUNT(*) > 0;';
    EXEC sp_executesql @sortSql;
    FETCH NEXT FROM sortOrder_cur INTO @name;
END;
CLOSE sortOrder_cur;
DEALLOCATE sortOrder_cur;

INSERT INTO #VerifySkip (Area, CheckName, Reason)
SELECT N'3-Ordering', N'NegativeSortOrder',
       N'skipped for [ATAPUtilities].[' + s.TableName + N']: table or SortOrder column is missing'
FROM @sortOrderTables AS s
WHERE OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(s.TableName), N'U') IS NULL
   OR COL_LENGTH(N'ATAPUtilities.' + QUOTENAME(s.TableName), N'SortOrder') IS NULL;

-- 3b. No duplicate SortOrder within one parent, on each membership table.
--     Backed by UNIQUE constraints; verified independently so dropping one
--     is detected rather than silently tolerated.
DECLARE @orderedMembership TABLE (TableName SYSNAME PRIMARY KEY, ParentColumn SYSNAME NOT NULL);
INSERT INTO @orderedMembership (TableName, ParentColumn) VALUES
    (N'RuleSetVersionMember',                         N'RuleSetVersionPhiloteId'),
    (N'BuildSetVersionMember',                        N'BuildSetVersionPhiloteId'),
    (N'InstantiationVersionRuleInstantiationVersion', N'InstantiationVersionPhiloteId');

DECLARE dupSortOrder_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT TableName, ParentColumn FROM @orderedMembership
    WHERE OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(TableName), N'U') IS NOT NULL;
OPEN dupSortOrder_cur;
FETCH NEXT FROM dupSortOrder_cur INTO @name, @otherName;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sortSql =
        N'INSERT INTO #VerifyFailure (Area, CheckName, Detail)
          SELECT N''3-Ordering'', N''DuplicateSortOrder'',
                 N''[ATAPUtilities].[' + @name + N'] parent '' + CAST(t.' + QUOTENAME(@otherName) + N' AS NVARCHAR(36))
                 + N'' has '' + CAST(COUNT(*) AS NVARCHAR(10)) + N'' members sharing SortOrder ''
                 + CAST(t.SortOrder AS NVARCHAR(10)) + N''; ordering is ambiguous''
          FROM ATAPUtilities.' + QUOTENAME(@name) + N' AS t
          GROUP BY t.' + QUOTENAME(@otherName) + N', t.SortOrder
          HAVING COUNT(*) > 1;';
    EXEC sp_executesql @sortSql;
    FETCH NEXT FROM dupSortOrder_cur INTO @name, @otherName;
END;
CLOSE dupSortOrder_cur;
DEALLOCATE dupSortOrder_cur;

-- 3c. RuleVersionPrimitiveComposition.Position: contiguous 1-based per
--     RuleVersion. Position IS the BNF production order, so a gap or a
--     duplicate produces incorrect code generation at runtime and must be a
--     hard failure here, not a warning.
IF OBJECT_ID(N'ATAPUtilities.RuleVersionPrimitiveComposition', N'U') IS NOT NULL
BEGIN
    EXEC sp_executesql N'
        INSERT INTO #VerifyFailure (Area, CheckName, Detail)
        SELECT N''3-Ordering'', N''PositionNotContiguous'',
               N''RuleVersion '' + CAST(g.RuleVersionPhiloteId AS NVARCHAR(36))
               + N'' has composition Positions MIN='' + CAST(g.MinPosition AS NVARCHAR(10))
               + N'', MAX='' + CAST(g.MaxPosition AS NVARCHAR(10))
               + N'', DISTINCT='' + CAST(g.DistinctPositions AS NVARCHAR(10))
               + N'', COUNT='' + CAST(g.PositionCount AS NVARCHAR(10))
               + N''; Position must be contiguous 1-based with no gaps and no duplicates''
        FROM (
            SELECT c.RuleVersionPhiloteId,
                   MIN(c.Position)          AS MinPosition,
                   MAX(c.Position)          AS MaxPosition,
                   COUNT(*)                 AS PositionCount,
                   COUNT(DISTINCT c.Position) AS DistinctPositions
            FROM ATAPUtilities.RuleVersionPrimitiveComposition AS c
            GROUP BY c.RuleVersionPhiloteId
        ) AS g
        WHERE g.MinPosition <> 1
           OR g.MaxPosition <> g.PositionCount
           OR g.DistinctPositions <> g.PositionCount;';
END
ELSE
    INSERT INTO #VerifySkip (Area, CheckName, Reason)
    VALUES (N'3-Ordering', N'PositionNotContiguous',
            N'skipped: ATAPUtilities.RuleVersionPrimitiveComposition is missing');

-- =====================================================================
-- SECTION 4 - IMMUTABLE MEMBERSHIP
--
-- The eight immutability triggers are the ONLY mechanism preventing a
-- published version or membership row from being rewritten. Existence alone
-- is not enough: a disabled trigger enforces nothing. V00.02.000080 performs
-- DELETEs against ManifestationArtifact and the typed membership tables; if
-- any operator or migration ever disables an immutability trigger to do such
-- work, this section fails until it is re-enabled.
-- =====================================================================

DECLARE @immutableTriggers TABLE (TriggerName SYSNAME PRIMARY KEY, TableName SYSNAME NOT NULL);
INSERT INTO @immutableTriggers (TriggerName, TableName) VALUES
    (N'TR_RuleVersion_Immutable',                     N'RuleVersion'),
    (N'TR_RuleVersionPrimitiveComposition_Immutable', N'RuleVersionPrimitiveComposition'),
    (N'TR_RuleSetVersion_Immutable',                  N'RuleSetVersion'),
    (N'TR_RuleSetVersionMember_Immutable',            N'RuleSetVersionMember'),
    (N'TR_BuildSetVersion_Immutable',                 N'BuildSetVersion'),
    (N'TR_BuildSetVersionMember_Immutable',           N'BuildSetVersionMember'),
    (N'TR_RuleInstantiationVersion_Immutable',        N'RuleInstantiationVersion'),
    (N'TR_IVRIV_Immutable',                           N'InstantiationVersionRuleInstantiationVersion');

-- 4a. Every trigger in section 1e must be ENABLED. This includes the two
--     non-immutability triggers, which are equally load-bearing.
INSERT INTO #VerifyFailure (Area, CheckName, Detail)
SELECT N'4-Immutability', N'TriggerDisabled',
       N'trigger [' + t.[name] + N'] on [ATAPUtilities].[' + OBJECT_NAME(t.parent_id)
       + N'] exists but is_disabled = 1; it enforces nothing in this state'
FROM sys.triggers AS t
INNER JOIN @expectedTriggers AS e ON e.TriggerName = t.[name]
WHERE t.is_disabled = 1;

-- 4b. Immutability triggers must be AFTER triggers, never INSTEAD OF. An
--     INSTEAD OF trigger would report the offending UPDATE as successful
--     while discarding it - silent corruption, strictly worse than mutation.
INSERT INTO #VerifyFailure (Area, CheckName, Detail)
SELECT N'4-Immutability', N'TriggerInsteadOf',
       N'trigger [' + t.[name] + N'] is an INSTEAD OF trigger; immutability must be AFTER + THROW '
       + N'so the offending statement is rolled back rather than silently discarded'
FROM sys.triggers AS t
INNER JOIN @immutableTriggers AS e ON e.TriggerName = t.[name]
WHERE t.is_instead_of_trigger = 1;

-- 4c. Each immutability trigger must be registered for BOTH UPDATE and DELETE.
--     Covering only one leaves the other path open.
INSERT INTO #VerifyFailure (Area, CheckName, Detail)
SELECT N'4-Immutability', N'TriggerEventCoverage',
       N'trigger [' + e.TriggerName + N'] on [' + e.TableName + N'] does not cover both UPDATE and DELETE (covers: '
       + ISNULL(STUFF((SELECT N', ' + te2.type_desc
                       FROM sys.trigger_events AS te2
                       WHERE te2.object_id = OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(e.TriggerName))
                       ORDER BY te2.type_desc
                       FOR XML PATH(N''), TYPE).value(N'.', N'NVARCHAR(200)'), 1, 2, N''), N'none') + N')'
FROM @immutableTriggers AS e
WHERE OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(e.TriggerName), N'TR') IS NOT NULL
  AND (SELECT COUNT(*)
       FROM sys.trigger_events AS te
       WHERE te.object_id = OBJECT_ID(N'ATAPUtilities.' + QUOTENAME(e.TriggerName))
         AND te.type_desc IN (N'UPDATE', N'DELETE')) <> 2;

-- 4d. Each immutability trigger must sit on its own table, not on some other
--     table with a matching name.
INSERT INTO #VerifyFailure (Area, CheckName, Detail)
SELECT N'4-Immutability', N'TriggerParentTable',
       N'trigger [' + e.TriggerName + N'] is attached to [' + OBJECT_NAME(t.parent_id)
       + N'] but must be attached to [' + e.TableName + N']'
FROM @immutableTriggers AS e
INNER JOIN sys.triggers AS t ON t.[name] = e.TriggerName
WHERE OBJECT_NAME(t.parent_id) <> e.TableName;

-- =====================================================================
-- SECTION 5 - COMPLETE MANIFESTATION PROVENANCE
--
-- Every ManifestationArtifact row must resolve to:
--   (1) its InstantiationVersion,
--   (2) the BuildSetVersion in force, and
--   (3) a producing RuleInstantiation / RuleInstantiationVersion,
-- with no orphans anywhere in the chain. There is no RuleExecution entity in
-- this schema; the producing side is RuleInstantiation plus its immutable
-- RuleInstantiationVersion.
-- =====================================================================

IF OBJECT_ID(N'ATAPUtilities.ManifestationArtifact', N'U') IS NOT NULL
   AND OBJECT_ID(N'ATAPUtilities.InstantiationVersion', N'U') IS NOT NULL
   AND COL_LENGTH(N'ATAPUtilities.ManifestationArtifact', N'BuildSetVersionPhiloteId') IS NOT NULL
   AND COL_LENGTH(N'ATAPUtilities.ManifestationArtifact', N'ProducingRuleInstantiationPhiloteId') IS NOT NULL
   AND COL_LENGTH(N'ATAPUtilities.ManifestationArtifact', N'ProducingRuleInstantiationVersionPhiloteId') IS NOT NULL
BEGIN
    -- P-1: leg (1) - artifact must resolve to an InstantiationVersion.
    EXEC sp_executesql N'
        INSERT INTO #VerifyFailure (Area, CheckName, Detail)
        SELECT N''5-Provenance'', N''ArtifactVersionOrphan'',
               N''ManifestationArtifact '' + CAST(ma.ManifestationArtifactPhiloteId AS NVARCHAR(36))
               + N'' names InstantiationVersion '' + CAST(ma.InstantiationVersionPhiloteId AS NVARCHAR(36))
               + N'' which does not exist''
        FROM ATAPUtilities.ManifestationArtifact AS ma
        WHERE NOT EXISTS (
            SELECT 1 FROM ATAPUtilities.InstantiationVersion AS iv
            WHERE iv.InstantiationVersionPhiloteId = ma.InstantiationVersionPhiloteId
        );';

    -- P-2: rendered artifacts must carry full provenance.
    EXEC sp_executesql N'
        INSERT INTO #VerifyFailure (Area, CheckName, Detail)
        SELECT N''5-Provenance'', N''IncompleteProvenance'',
               N''ManifestationArtifact '' + CAST(ma.ManifestationArtifactPhiloteId AS NVARCHAR(36))
               + N'' ('' + ma.RelativePath + N'') has RenderPolicy=RenderFromModel but ''
               + CASE WHEN ma.BuildSetVersionPhiloteId IS NULL
                           AND ma.ProducingRuleInstantiationPhiloteId IS NULL
                      THEN N''names neither a BuildSetVersion nor a producing RuleInstantiation''
                      WHEN ma.BuildSetVersionPhiloteId IS NULL
                      THEN N''names no BuildSetVersion''
                      ELSE N''names no producing RuleInstantiation'' END
        FROM ATAPUtilities.ManifestationArtifact AS ma
        WHERE ma.RenderPolicy = N''RenderFromModel''
          AND (ma.BuildSetVersionPhiloteId IS NULL OR ma.ProducingRuleInstantiationPhiloteId IS NULL);';

    -- P-3: producer pairing - a version may only be named alongside its durable row.
    EXEC sp_executesql N'
        INSERT INTO #VerifyFailure (Area, CheckName, Detail)
        SELECT N''5-Provenance'', N''UnpairedProducer'',
               N''ManifestationArtifact '' + CAST(ma.ManifestationArtifactPhiloteId AS NVARCHAR(36))
               + N'' names a producing RuleInstantiationVersion but no durable ProducingRuleInstantiationPhiloteId''
        FROM ATAPUtilities.ManifestationArtifact AS ma
        WHERE ma.ProducingRuleInstantiationVersionPhiloteId IS NOT NULL
          AND ma.ProducingRuleInstantiationPhiloteId IS NULL;';
END
ELSE
    INSERT INTO #VerifySkip (Area, CheckName, Reason)
    VALUES (N'5-Provenance', N'ArtifactVersionOrphan/IncompleteProvenance/UnpairedProducer',
            N'skipped: ManifestationArtifact provenance columns from V00.02.000070 are missing');

IF OBJECT_ID(N'ATAPUtilities.ManifestationArtifact', N'U') IS NOT NULL
   AND OBJECT_ID(N'ATAPUtilities.BuildSetVersion', N'U') IS NOT NULL
   AND COL_LENGTH(N'ATAPUtilities.ManifestationArtifact', N'BuildSetVersionPhiloteId') IS NOT NULL
   AND COL_LENGTH(N'ATAPUtilities.InstantiationVersion', N'BuildSetVersionPhiloteId') IS NOT NULL
BEGIN
    -- P-4: leg (2) - a named BuildSetVersion must exist.
    EXEC sp_executesql N'
        INSERT INTO #VerifyFailure (Area, CheckName, Detail)
        SELECT N''5-Provenance'', N''ArtifactBuildSetVersionOrphan'',
               N''ManifestationArtifact '' + CAST(ma.ManifestationArtifactPhiloteId AS NVARCHAR(36))
               + N'' names BuildSetVersion '' + CAST(ma.BuildSetVersionPhiloteId AS NVARCHAR(36))
               + N'' which does not exist''
        FROM ATAPUtilities.ManifestationArtifact AS ma
        WHERE ma.BuildSetVersionPhiloteId IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM ATAPUtilities.BuildSetVersion AS bsv
              WHERE bsv.BuildSetVersionPhiloteId = ma.BuildSetVersionPhiloteId
          );';

    -- P-5: the artifact BuildSetVersion must agree with the one bound to its
    --      InstantiationVersion.
    EXEC sp_executesql N'
        INSERT INTO #VerifyFailure (Area, CheckName, Detail)
        SELECT N''5-Provenance'', N''BuildSetVersionDisagreement'',
               N''ManifestationArtifact '' + CAST(ma.ManifestationArtifactPhiloteId AS NVARCHAR(36))
               + N'' names BuildSetVersion '' + CAST(ma.BuildSetVersionPhiloteId AS NVARCHAR(36))
               + N'' but its InstantiationVersion is bound to ''
               + CAST(iv.BuildSetVersionPhiloteId AS NVARCHAR(36))
        FROM ATAPUtilities.ManifestationArtifact AS ma
        INNER JOIN ATAPUtilities.InstantiationVersion AS iv
                ON iv.InstantiationVersionPhiloteId = ma.InstantiationVersionPhiloteId
        WHERE ma.BuildSetVersionPhiloteId IS NOT NULL
          AND iv.BuildSetVersionPhiloteId IS NOT NULL
          AND ma.BuildSetVersionPhiloteId <> iv.BuildSetVersionPhiloteId;';

    -- P-6: closes the gap the TR_ManifestationArtifact_Provenance trigger
    --      cannot close. That trigger is vacuous whenever the
    --      InstantiationVersion has a NULL BuildSetVersionPhiloteId. Provenance
    --      is only COMPLETE when the InstantiationVersion behind a rendered
    --      artifact is itself bound to a BuildSetVersion. Fails until the
    --      Task 13.79 backfill is done - which is the correct signal.
    EXEC sp_executesql N'
        INSERT INTO #VerifyFailure (Area, CheckName, Detail)
        SELECT N''5-Provenance'', N''UnboundInstantiationVersion'',
               N''InstantiationVersion '' + CAST(iv.InstantiationVersionPhiloteId AS NVARCHAR(36))
               + N'' has '' + CAST(COUNT(*) AS NVARCHAR(10))
               + N'' RenderFromModel artifact(s) but its own BuildSetVersionPhiloteId is NULL; ''
               + N''provenance leg 2 is unverifiable for those artifacts (backfill not applied?)''
        FROM ATAPUtilities.InstantiationVersion AS iv
        INNER JOIN ATAPUtilities.ManifestationArtifact AS ma
                ON ma.InstantiationVersionPhiloteId = iv.InstantiationVersionPhiloteId
        WHERE iv.BuildSetVersionPhiloteId IS NULL
          AND ma.RenderPolicy = N''RenderFromModel''
        GROUP BY iv.InstantiationVersionPhiloteId;';
END
ELSE
    INSERT INTO #VerifySkip (Area, CheckName, Reason)
    VALUES (N'5-Provenance', N'BuildSetVersion provenance leg',
            N'skipped: ATAPUtilities.BuildSetVersion or a BuildSetVersionPhiloteId column is missing');

IF OBJECT_ID(N'ATAPUtilities.ManifestationArtifact', N'U') IS NOT NULL
   AND OBJECT_ID(N'ATAPUtilities.RuleInstantiation', N'U') IS NOT NULL
   AND OBJECT_ID(N'ATAPUtilities.RuleInstantiationVersion', N'U') IS NOT NULL
   AND COL_LENGTH(N'ATAPUtilities.ManifestationArtifact', N'ProducingRuleInstantiationPhiloteId') IS NOT NULL
BEGIN
    -- P-7: leg (3) - a named producing RuleInstantiation must exist.
    EXEC sp_executesql N'
        INSERT INTO #VerifyFailure (Area, CheckName, Detail)
        SELECT N''5-Provenance'', N''ProducerOrphan'',
               N''ManifestationArtifact '' + CAST(ma.ManifestationArtifactPhiloteId AS NVARCHAR(36))
               + N'' names producing RuleInstantiation '' + CAST(ma.ProducingRuleInstantiationPhiloteId AS NVARCHAR(36))
               + N'' which does not exist''
        FROM ATAPUtilities.ManifestationArtifact AS ma
        WHERE ma.ProducingRuleInstantiationPhiloteId IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM ATAPUtilities.RuleInstantiation AS ri
              WHERE ri.PhiloteId = ma.ProducingRuleInstantiationPhiloteId
          );';

    -- P-8: a named producing RuleInstantiationVersion must exist AND must be a
    --      version of the named durable RuleInstantiation.
    EXEC sp_executesql N'
        INSERT INTO #VerifyFailure (Area, CheckName, Detail)
        SELECT N''5-Provenance'', N''ProducerVersionMismatch'',
               N''ManifestationArtifact '' + CAST(ma.ManifestationArtifactPhiloteId AS NVARCHAR(36))
               + N'' names producing RuleInstantiationVersion '' + CAST(ma.ProducingRuleInstantiationVersionPhiloteId AS NVARCHAR(36))
               + CASE WHEN riv.RuleInstantiationVersionPhiloteId IS NULL
                      THEN N'' which does not exist''
                      ELSE N'' which is a version of RuleInstantiation '' + CAST(riv.RuleInstantiationPhiloteId AS NVARCHAR(36))
                           + N'', not of the named producer '' + CAST(ma.ProducingRuleInstantiationPhiloteId AS NVARCHAR(36)) END
        FROM ATAPUtilities.ManifestationArtifact AS ma
        LEFT JOIN ATAPUtilities.RuleInstantiationVersion AS riv
               ON riv.RuleInstantiationVersionPhiloteId = ma.ProducingRuleInstantiationVersionPhiloteId
        WHERE ma.ProducingRuleInstantiationVersionPhiloteId IS NOT NULL
          AND (riv.RuleInstantiationVersionPhiloteId IS NULL
               OR riv.RuleInstantiationPhiloteId <> ma.ProducingRuleInstantiationPhiloteId);';
END
ELSE
    INSERT INTO #VerifySkip (Area, CheckName, Reason)
    VALUES (N'5-Provenance', N'Producer provenance leg',
            N'skipped: ATAPUtilities.RuleInstantiationVersion or a producer column is missing');

IF OBJECT_ID(N'ATAPUtilities.ManifestationArtifact', N'U') IS NOT NULL
   AND OBJECT_ID(N'ATAPUtilities.InstantiationVersionRuleInstantiationVersion', N'U') IS NOT NULL
   AND COL_LENGTH(N'ATAPUtilities.ManifestationArtifact', N'ProducingRuleInstantiationVersionPhiloteId') IS NOT NULL
BEGIN
    -- P-9: the producing RuleInstantiationVersion must actually be a member of
    --      its artifact's InstantiationVersion snapshot. Without this an
    --      artifact could cite a real, correctly-paired producer that was never
    --      part of the snapshot it claims to have been rendered from.
    EXEC sp_executesql N'
        INSERT INTO #VerifyFailure (Area, CheckName, Detail)
        SELECT N''5-Provenance'', N''ProducerNotInSnapshot'',
               N''ManifestationArtifact '' + CAST(ma.ManifestationArtifactPhiloteId AS NVARCHAR(36))
               + N'' cites producing RuleInstantiationVersion '' + CAST(ma.ProducingRuleInstantiationVersionPhiloteId AS NVARCHAR(36))
               + N'' which is not a member of its InstantiationVersion ''
               + CAST(ma.InstantiationVersionPhiloteId AS NVARCHAR(36)) + N'' snapshot''
        FROM ATAPUtilities.ManifestationArtifact AS ma
        WHERE ma.ProducingRuleInstantiationVersionPhiloteId IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion AS ivriv
              WHERE ivriv.InstantiationVersionPhiloteId = ma.InstantiationVersionPhiloteId
                AND ivriv.RuleInstantiationVersionPhiloteId = ma.ProducingRuleInstantiationVersionPhiloteId
          );';

    -- INFO: artifact population, so a vacuous pass (zero artifact rows, which
    -- is the expected state right after V00.02.000080 removes the Sprint 0012
    -- samples) is never mistaken for verified provenance.
    EXEC sp_executesql N'
        INSERT INTO #VerifyInfo (Area, Detail)
        SELECT N''5-Provenance'',
               N''ManifestationArtifact rows: '' + CAST(COUNT(*) AS NVARCHAR(10))
               + N'' (RenderFromModel: '' + CAST(ISNULL(SUM(CASE WHEN RenderPolicy = N''RenderFromModel'' THEN 1 ELSE 0 END), 0) AS NVARCHAR(10))
               + N''). Zero rows means the provenance checks passed vacuously.''
        FROM ATAPUtilities.ManifestationArtifact;';
END
ELSE
    INSERT INTO #VerifySkip (Area, CheckName, Reason)
    VALUES (N'5-Provenance', N'ProducerNotInSnapshot',
            N'skipped: ATAPUtilities.InstantiationVersionRuleInstantiationVersion is missing');

-- =====================================================================
-- REPORT
-- =====================================================================

DECLARE @infoDetail NVARCHAR(400);
DECLARE info_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT Area, Detail FROM #VerifyInfo ORDER BY InfoId;
OPEN info_cur;
FETCH NEXT FROM info_cur INTO @kind, @infoDetail;
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT N'INFO [' + @kind + N']: ' + @infoDetail;
    FETCH NEXT FROM info_cur INTO @kind, @infoDetail;
END;
CLOSE info_cur;
DEALLOCATE info_cur;

DECLARE @skipCheck NVARCHAR(80);
DECLARE @skipReason NVARCHAR(400);
DECLARE skip_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT Area, CheckName, Reason FROM #VerifySkip ORDER BY SkipId;
OPEN skip_cur;
FETCH NEXT FROM skip_cur INTO @kind, @skipCheck, @skipReason;
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT N'SKIP [' + @kind + N'.' + @skipCheck + N']: ' + @skipReason;
    FETCH NEXT FROM skip_cur INTO @kind, @skipCheck, @skipReason;
END;
CLOSE skip_cur;
DEALLOCATE skip_cur;

DECLARE @failCheck NVARCHAR(80);
DECLARE @failDetail NVARCHAR(400);
DECLARE fail_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT Area, CheckName, Detail FROM #VerifyFailure ORDER BY FailureId;
OPEN fail_cur;
FETCH NEXT FROM fail_cur INTO @kind, @failCheck, @failDetail;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @errCount = @errCount + 1;
    SET @msg = N'FAIL [' + @kind + N'.' + @failCheck + N']: ' + @failDetail;
    RAISERROR(@msg, 16, 1);
    FETCH NEXT FROM fail_cur INTO @kind, @failCheck, @failDetail;
END;
CLOSE fail_cur;
DEALLOCATE fail_cur;

-- Per-area totals, so a reader sees which of the five areas is red without
-- re-reading every individual failure line.
DECLARE @areaName NVARCHAR(40);
DECLARE @areaCount INT;
DECLARE area_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT Area, COUNT(*) FROM #VerifyFailure GROUP BY Area ORDER BY Area;
OPEN area_cur;
FETCH NEXT FROM area_cur INTO @areaName, @areaCount;
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT N'AREA ' + @areaName + N': ' + CAST(@areaCount AS NVARCHAR(10)) + N' failure(s)';
    FETCH NEXT FROM area_cur INTO @areaName, @areaCount;
END;
CLOSE area_cur;
DEALLOCATE area_cur;

DROP TABLE #VerifyFailure;
DROP TABLE #VerifySkip;
DROP TABLE #VerifyInfo;

IF @errCount > 0
BEGIN
    SET @msg = N'RRSBS durable/versioned schema verification: ' + CAST(@errCount AS NVARCHAR(10)) + N' failure(s)';
    RAISERROR(@msg, 16, 1);
END
ELSE
BEGIN
    PRINT N'RRSBS durable/versioned schema verification: OK';
END;
GO

USE ATAPUtilities;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
SET NOCOUNT ON;
GO

/* ============================================================
   V00.02.000020 - Replicate Tags and Gmail schemas into ATAPUtilities
   ============================================================
   Source databases (to be deleted after this migration applies):
     - Tags  -> mirrored into the [Tags]  schema in ATAPUtilities
     - GMail -> mirrored into the [Gmail] schema in ATAPUtilities

   Source artifacts:
     OlderDBsForReference/Tags/Flyway/SQL/*
     OlderDBsForReference/Tags/Flyway/Data/*
     src/ATAP.Utilities.Gmail/Database/Flyway/SQL/V00.01.000010__Create_Gmail_Core_Schema.sql

   Sections:
     1. Schema creation (Tags, Gmail)
     2. Tags schema tables (Tags, TagAliases, TagRelationships, RelationshipTypes)
     3. Tags hierarchy stored procedures
     4. Tags views
     5. Gmail schema tables (gmailMessages)
     6. Seed data (RelationshipTypes, Tags)
   ============================================================ */

-- ============================================================
-- SECTION 1 - Schemas
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Tags')
    EXEC (N'CREATE SCHEMA Tags');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Gmail')
    EXEC (N'CREATE SCHEMA Gmail');
GO

-- Drop in reverse dependency order to keep the script re-runnable
IF OBJECT_ID(N'Tags.vw_TagRelationshipsExpanded', N'V') IS NOT NULL DROP VIEW Tags.vw_TagRelationshipsExpanded;
GO
IF OBJECT_ID(N'Tags.vw_TagsWithChildCount',       N'V') IS NOT NULL DROP VIEW Tags.vw_TagsWithChildCount;
GO
IF OBJECT_ID(N'Tags.vw_RootTags',                 N'V') IS NOT NULL DROP VIEW Tags.vw_RootTags;
GO
IF OBJECT_ID(N'Tags.vw_ActiveTags',               N'V') IS NOT NULL DROP VIEW Tags.vw_ActiveTags;
GO
IF OBJECT_ID(N'Tags.usp_GetTagDescendants',       N'P') IS NOT NULL DROP PROCEDURE Tags.usp_GetTagDescendants;
GO
IF OBJECT_ID(N'Tags.usp_GetTagAncestors',         N'P') IS NOT NULL DROP PROCEDURE Tags.usp_GetTagAncestors;
GO
IF OBJECT_ID(N'Tags.usp_GetTagTree',              N'P') IS NOT NULL DROP PROCEDURE Tags.usp_GetTagTree;
GO
IF OBJECT_ID(N'Tags.TagRelationships',            N'U') IS NOT NULL DROP TABLE Tags.TagRelationships;
GO
IF OBJECT_ID(N'Tags.TagAliases',                  N'U') IS NOT NULL DROP TABLE Tags.TagAliases;
GO
IF OBJECT_ID(N'Tags.RelationshipTypes',           N'U') IS NOT NULL DROP TABLE Tags.RelationshipTypes;
GO
IF OBJECT_ID(N'Tags.Tags',                        N'U') IS NOT NULL DROP TABLE Tags.Tags;
GO
IF OBJECT_ID(N'Gmail.gmailMessages',              N'U') IS NOT NULL DROP TABLE Gmail.gmailMessages;
GO

-- ============================================================
-- SECTION 2 - Tags schema tables
-- ============================================================

CREATE TABLE Tags.Tags (
    TagID         INT             IDENTITY(1,1) NOT NULL,
    ParentTagID   INT             NULL,
    ResourceKey   VARCHAR(100)    NOT NULL,
    DefaultLabel  NVARCHAR(256)   NULL,
    IsActive      BIT             NOT NULL CONSTRAINT DF_Tags_Tags_IsActive     DEFAULT (1),
    SortOrder     INT             NOT NULL CONSTRAINT DF_Tags_Tags_SortOrder    DEFAULT (0),
    CreatedDate   DATETIME2(7)    NOT NULL CONSTRAINT DF_Tags_Tags_CreatedDate  DEFAULT (SYSUTCDATETIME()),
    ModifiedDate  DATETIME2(7)    NOT NULL CONSTRAINT DF_Tags_Tags_ModifiedDate DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Tags_Tags                PRIMARY KEY CLUSTERED (TagID),
    CONSTRAINT UQ_Tags_Tags_ResourceKey    UNIQUE NONCLUSTERED (ResourceKey),
    CONSTRAINT FK_Tags_Tags_ParentTag      FOREIGN KEY (ParentTagID)
        REFERENCES Tags.Tags (TagID)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION
);
GO

CREATE NONCLUSTERED INDEX IX_Tags_Tags_ParentTagID
    ON Tags.Tags (ParentTagID)
    INCLUDE (ResourceKey, IsActive, SortOrder);
GO

CREATE NONCLUSTERED INDEX IX_Tags_Tags_IsActive
    ON Tags.Tags (IsActive)
    WHERE IsActive = 1;
GO

CREATE TABLE Tags.TagAliases (
    AliasID           INT             IDENTITY(1,1) NOT NULL,
    TagID             INT             NOT NULL,
    AliasResourceKey  VARCHAR(100)    NOT NULL,
    AliasType         VARCHAR(50)     NOT NULL CONSTRAINT DF_Tags_TagAliases_Type        DEFAULT ('Synonym'),
    IsActive          BIT             NOT NULL CONSTRAINT DF_Tags_TagAliases_IsActive    DEFAULT (1),
    CreatedDate       DATETIME2(7)    NOT NULL CONSTRAINT DF_Tags_TagAliases_CreatedDate DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Tags_TagAliases             PRIMARY KEY CLUSTERED (AliasID),
    CONSTRAINT UQ_Tags_TagAliases_ResourceKey UNIQUE NONCLUSTERED (AliasResourceKey),
    CONSTRAINT FK_Tags_TagAliases_Tag         FOREIGN KEY (TagID)
        REFERENCES Tags.Tags (TagID)
        ON DELETE CASCADE
);
GO

CREATE NONCLUSTERED INDEX IX_Tags_TagAliases_TagID
    ON Tags.TagAliases (TagID);
GO

CREATE TABLE Tags.RelationshipTypes (
    RelationshipTypeID      INT             IDENTITY(1,1) NOT NULL,
    ResourceKey             VARCHAR(100)    NOT NULL,
    IsBidirectionalDefault  BIT             NOT NULL CONSTRAINT DF_Tags_RelType_Bidirectional DEFAULT (0),
    InverseTypeKey          VARCHAR(100)    NULL,
    DefaultDescription      NVARCHAR(256)   NULL,
    IsActive                BIT             NOT NULL CONSTRAINT DF_Tags_RelType_IsActive    DEFAULT (1),
    SortOrder               INT             NOT NULL CONSTRAINT DF_Tags_RelType_SortOrder   DEFAULT (0),
    CreatedDate             DATETIME2(7)    NOT NULL CONSTRAINT DF_Tags_RelType_CreatedDate DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Tags_RelationshipTypes             PRIMARY KEY CLUSTERED (RelationshipTypeID),
    CONSTRAINT UQ_Tags_RelationshipTypes_ResourceKey UNIQUE NONCLUSTERED (ResourceKey)
);
GO

CREATE TABLE Tags.TagRelationships (
    RelationshipID       INT             IDENTITY(1,1) NOT NULL,
    SourceTagID          INT             NOT NULL,
    TargetTagID          INT             NOT NULL,
    RelationshipTypeKey  VARCHAR(100)    NOT NULL,
    IsBidirectional      BIT             NOT NULL CONSTRAINT DF_Tags_TagRel_Bidirectional DEFAULT (0),
    Weight               DECIMAL(5,2)    NOT NULL CONSTRAINT DF_Tags_TagRel_Weight        DEFAULT (1.0),
    IsActive             BIT             NOT NULL CONSTRAINT DF_Tags_TagRel_IsActive      DEFAULT (1),
    CreatedDate          DATETIME2(7)    NOT NULL CONSTRAINT DF_Tags_TagRel_CreatedDate   DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Tags_TagRelationships    PRIMARY KEY CLUSTERED (RelationshipID),
    CONSTRAINT UQ_Tags_TagRelationships    UNIQUE NONCLUSTERED (SourceTagID, TargetTagID, RelationshipTypeKey),
    CONSTRAINT FK_Tags_TagRel_SourceTag    FOREIGN KEY (SourceTagID) REFERENCES Tags.Tags (TagID) ON DELETE NO ACTION,
    CONSTRAINT FK_Tags_TagRel_TargetTag    FOREIGN KEY (TargetTagID) REFERENCES Tags.Tags (TagID) ON DELETE NO ACTION,
    CONSTRAINT CK_Tags_TagRel_NoSelfRef    CHECK (SourceTagID <> TargetTagID)
);
GO

CREATE NONCLUSTERED INDEX IX_Tags_TagRel_SourceTag
    ON Tags.TagRelationships (SourceTagID)
    INCLUDE (TargetTagID, RelationshipTypeKey);
GO

CREATE NONCLUSTERED INDEX IX_Tags_TagRel_TargetTag
    ON Tags.TagRelationships (TargetTagID)
    INCLUDE (SourceTagID, RelationshipTypeKey);
GO

-- ============================================================
-- SECTION 3 - Tags hierarchy traversal stored procedures
-- ============================================================

EXEC (N'
CREATE OR ALTER PROCEDURE Tags.usp_GetTagTree
    @RootTagID INT = NULL,
    @MaxDepth  INT = 100,
    @ActiveOnly BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH TagTree AS (
        SELECT
            TagID, ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder,
            0 AS [Level],
            CAST(RIGHT(''0000000000'' + CAST(SortOrder AS VARCHAR(10)), 10) + ''/'' + CAST(TagID AS VARCHAR(10)) AS VARCHAR(MAX)) AS TreePath
        FROM Tags.Tags
        WHERE (@RootTagID IS NULL AND ParentTagID IS NULL)
           OR (@RootTagID IS NOT NULL AND TagID = @RootTagID)

        UNION ALL

        SELECT
            t.TagID, t.ParentTagID, t.ResourceKey, t.DefaultLabel, t.IsActive, t.SortOrder,
            tt.[Level] + 1,
            tt.TreePath + ''/'' + RIGHT(''0000000000'' + CAST(t.SortOrder AS VARCHAR(10)), 10) + ''/'' + CAST(t.TagID AS VARCHAR(10))
        FROM Tags.Tags t
        INNER JOIN TagTree tt ON t.ParentTagID = tt.TagID
        WHERE tt.[Level] < @MaxDepth
          AND (@ActiveOnly = 0 OR t.IsActive = 1)
    )
    SELECT TagID, ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder, [Level], TreePath
    FROM TagTree
    WHERE @ActiveOnly = 0 OR IsActive = 1
    ORDER BY TreePath;
END
');
GO

EXEC (N'
CREATE OR ALTER PROCEDURE Tags.usp_GetTagAncestors
    @TagID       INT,
    @IncludeSelf BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Ancestors AS (
        SELECT TagID, ParentTagID, ResourceKey, DefaultLabel, SortOrder, 0 AS [Level]
        FROM Tags.Tags
        WHERE TagID = @TagID

        UNION ALL

        SELECT t.TagID, t.ParentTagID, t.ResourceKey, t.DefaultLabel, t.SortOrder, a.[Level] + 1
        FROM Tags.Tags t
        INNER JOIN Ancestors a ON t.TagID = a.ParentTagID
    )
    SELECT TagID, ParentTagID, ResourceKey, DefaultLabel, SortOrder, [Level]
    FROM Ancestors
    WHERE @IncludeSelf = 1 OR TagID <> @TagID
    ORDER BY [Level] DESC;
END
');
GO

EXEC (N'
CREATE OR ALTER PROCEDURE Tags.usp_GetTagDescendants
    @TagID       INT,
    @MaxDepth    INT = 100,
    @IncludeSelf BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Descendants AS (
        SELECT TagID, ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder, 1 AS [Level]
        FROM Tags.Tags
        WHERE ParentTagID = @TagID

        UNION ALL

        SELECT t.TagID, t.ParentTagID, t.ResourceKey, t.DefaultLabel, t.IsActive, t.SortOrder, d.[Level] + 1
        FROM Tags.Tags t
        INNER JOIN Descendants d ON t.ParentTagID = d.TagID
        WHERE d.[Level] < @MaxDepth
    )
    SELECT TagID, ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder, [Level]
    FROM Descendants

    UNION ALL

    SELECT TagID, ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder, 0 AS [Level]
    FROM Tags.Tags
    WHERE TagID = @TagID AND @IncludeSelf = 1

    ORDER BY [Level], SortOrder;
END
');
GO

-- ============================================================
-- SECTION 4 - Tags views
-- ============================================================

EXEC (N'
CREATE OR ALTER VIEW Tags.vw_ActiveTags
AS
SELECT
    t.TagID, t.ParentTagID, t.ResourceKey, t.DefaultLabel, t.SortOrder,
    t.CreatedDate, t.ModifiedDate,
    p.ResourceKey  AS ParentResourceKey,
    p.DefaultLabel AS ParentDefaultLabel
FROM Tags.Tags t
LEFT JOIN Tags.Tags p ON t.ParentTagID = p.TagID
WHERE t.IsActive = 1;
');
GO

EXEC (N'
CREATE OR ALTER VIEW Tags.vw_RootTags
AS
SELECT TagID, ResourceKey, DefaultLabel, SortOrder, IsActive, CreatedDate
FROM Tags.Tags
WHERE ParentTagID IS NULL
  AND IsActive = 1;
');
GO

EXEC (N'
CREATE OR ALTER VIEW Tags.vw_TagsWithChildCount
AS
SELECT
    t.TagID, t.ParentTagID, t.ResourceKey, t.DefaultLabel, t.IsActive, t.SortOrder,
    (SELECT COUNT(*) FROM Tags.Tags c WHERE c.ParentTagID = t.TagID AND c.IsActive = 1) AS ChildCount,
    CASE WHEN EXISTS (SELECT 1 FROM Tags.Tags c WHERE c.ParentTagID = t.TagID AND c.IsActive = 1)
         THEN 1 ELSE 0 END AS HasChildren
FROM Tags.Tags t;
');
GO

EXEC (N'
CREATE OR ALTER VIEW Tags.vw_TagRelationshipsExpanded
AS
SELECT
    r.RelationshipID,
    r.SourceTagID, s.ResourceKey  AS SourceResourceKey, s.DefaultLabel AS SourceDefaultLabel,
    r.TargetTagID, t.ResourceKey  AS TargetResourceKey, t.DefaultLabel AS TargetDefaultLabel,
    r.RelationshipTypeKey, r.IsBidirectional, r.Weight, r.IsActive
FROM Tags.TagRelationships r
INNER JOIN Tags.Tags s ON r.SourceTagID = s.TagID
INNER JOIN Tags.Tags t ON r.TargetTagID = t.TagID;
');
GO

-- ============================================================
-- SECTION 5 - Gmail schema tables
-- ============================================================

CREATE TABLE Gmail.gmailMessages (
    ID            INT             IDENTITY(1,1) NOT NULL,
    [Subject]     NVARCHAR(400)   NULL,
    MessageId     NVARCHAR(400)   NULL,
    FromAddress   NVARCHAR(400)   NULL,
    ToAddress     NVARCHAR(400)   NULL,
    [Date]        DATETIME2(7)    NULL,
    Labels        NVARCHAR(1000)  NULL,
    Body          NVARCHAR(MAX)   NULL,
    [URL]         NVARCHAR(2000)  NULL,
    CONSTRAINT PK_Gmail_gmailMessages PRIMARY KEY CLUSTERED (ID)
);
GO

-- ============================================================
-- SECTION 6 - Seed data
-- Source: OlderDBsForReference/Tags/Flyway/Data/*.csv
-- ============================================================

BEGIN TRANSACTION;

-- RelationshipTypes seed (10 rows)
INSERT INTO Tags.RelationshipTypes (ResourceKey, IsBidirectionalDefault, InverseTypeKey, DefaultDescription, IsActive, SortOrder) VALUES
    (N'REL_RELATED_TO',    1, NULL,                  N'General relationship between tags',     1,  10),
    (N'REL_SEE_ALSO',      1, NULL,                  N'Suggested alternative tags',            1,  20),
    (N'REL_SYNONYM_OF',    1, NULL,                  N'Tags that mean the same thing',         1,  30),
    (N'REL_BROADER_THAN',  0, N'REL_NARROWER_THAN',  N'Parent-like semantic relationship',     1,  40),
    (N'REL_NARROWER_THAN', 0, N'REL_BROADER_THAN',   N'Child-like semantic relationship',      1,  50),
    (N'REL_OPPOSITE_OF',   1, NULL,                  N'Antonym relationship',                  1,  60),
    (N'REL_REPLACES',      0, N'REL_REPLACED_BY',    N'Tag supersedes another',                1,  70),
    (N'REL_REPLACED_BY',   0, N'REL_REPLACES',       N'Tag was superseded',                    1,  80),
    (N'REL_PART_OF',       0, N'REL_HAS_PART',       N'Component relationship',                1,  90),
    (N'REL_HAS_PART',      0, N'REL_PART_OF',        N'Contains component',                    1, 100);

-- Tags seed - root level (ParentTagID NULL)
INSERT INTO Tags.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder) VALUES
    (NULL, N'TAG_ELECTRONICS', N'Electronics', 1, 100),
    (NULL, N'TAG_DOCUMENTS',   N'Documents',   1, 200),
    (NULL, N'TAG_MEDIA',       N'Media',       1, 300),
    (NULL, N'TAG_PROJECTS',    N'Projects',    1, 400),
    (NULL, N'TAG_REFERENCES',  N'References',  1, 500),
    (NULL, N'TAG_PERSONAL',    N'Personal',    1, 600);

-- Tags seed - children of TAG_ELECTRONICS
INSERT INTO Tags.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder)
SELECT t.TagID, v.ResourceKey, v.DefaultLabel, 1, v.SortOrder
FROM Tags.Tags t
CROSS APPLY (VALUES
    (N'TAG_ELECTRONICS_COMPUTERS',   N'Computers',   10),
    (N'TAG_ELECTRONICS_PHONES',      N'Phones',      20),
    (N'TAG_ELECTRONICS_TABLETS',     N'Tablets',     30),
    (N'TAG_ELECTRONICS_PERIPHERALS', N'Peripherals', 40),
    (N'TAG_ELECTRONICS_NETWORKING',  N'Networking',  50)
) AS v (ResourceKey, DefaultLabel, SortOrder)
WHERE t.ResourceKey = N'TAG_ELECTRONICS';

-- Tags seed - children of TAG_ELECTRONICS_COMPUTERS
INSERT INTO Tags.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder)
SELECT t.TagID, v.ResourceKey, v.DefaultLabel, 1, v.SortOrder
FROM Tags.Tags t
CROSS APPLY (VALUES
    (N'TAG_COMPUTERS_DESKTOPS',   N'Desktops',   10),
    (N'TAG_COMPUTERS_LAPTOPS',    N'Laptops',    20),
    (N'TAG_COMPUTERS_SERVERS',    N'Servers',    30),
    (N'TAG_COMPUTERS_COMPONENTS', N'Components', 40)
) AS v (ResourceKey, DefaultLabel, SortOrder)
WHERE t.ResourceKey = N'TAG_ELECTRONICS_COMPUTERS';

-- Tags seed - children of TAG_DOCUMENTS
INSERT INTO Tags.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder)
SELECT t.TagID, v.ResourceKey, v.DefaultLabel, 1, v.SortOrder
FROM Tags.Tags t
CROSS APPLY (VALUES
    (N'TAG_DOCUMENTS_REPORTS',        N'Reports',        10),
    (N'TAG_DOCUMENTS_MANUALS',        N'Manuals',        20),
    (N'TAG_DOCUMENTS_SPECIFICATIONS', N'Specifications', 30),
    (N'TAG_DOCUMENTS_CONTRACTS',      N'Contracts',      40),
    (N'TAG_DOCUMENTS_CORRESPONDENCE', N'Correspondence', 50)
) AS v (ResourceKey, DefaultLabel, SortOrder)
WHERE t.ResourceKey = N'TAG_DOCUMENTS';

-- Tags seed - children of TAG_MEDIA
INSERT INTO Tags.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder)
SELECT t.TagID, v.ResourceKey, v.DefaultLabel, 1, v.SortOrder
FROM Tags.Tags t
CROSS APPLY (VALUES
    (N'TAG_MEDIA_IMAGES', N'Images',  10),
    (N'TAG_MEDIA_VIDEO',  N'Video',   20),
    (N'TAG_MEDIA_AUDIO',  N'Audio',   30),
    (N'TAG_MEDIA_EBOOKS', N'E-Books', 40)
) AS v (ResourceKey, DefaultLabel, SortOrder)
WHERE t.ResourceKey = N'TAG_MEDIA';

-- Tags seed - children of TAG_PROJECTS
INSERT INTO Tags.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder)
SELECT t.TagID, v.ResourceKey, v.DefaultLabel, 1, v.SortOrder
FROM Tags.Tags t
CROSS APPLY (VALUES
    (N'TAG_PROJECTS_ACTIVE',    N'Active',    10),
    (N'TAG_PROJECTS_COMPLETED', N'Completed', 20),
    (N'TAG_PROJECTS_ARCHIVED',  N'Archived',  30),
    (N'TAG_PROJECTS_TEMPLATES', N'Templates', 40)
) AS v (ResourceKey, DefaultLabel, SortOrder)
WHERE t.ResourceKey = N'TAG_PROJECTS';

-- Tags seed - children of TAG_REFERENCES
INSERT INTO Tags.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder)
SELECT t.TagID, v.ResourceKey, v.DefaultLabel, 1, v.SortOrder
FROM Tags.Tags t
CROSS APPLY (VALUES
    (N'TAG_REFERENCES_TUTORIALS',     N'Tutorials',     10),
    (N'TAG_REFERENCES_DOCUMENTATION', N'Documentation', 20),
    (N'TAG_REFERENCES_SAMPLES',       N'Samples',       30),
    (N'TAG_REFERENCES_BOOKMARKS',     N'Bookmarks',     40)
) AS v (ResourceKey, DefaultLabel, SortOrder)
WHERE t.ResourceKey = N'TAG_REFERENCES';

-- Tags seed - children of TAG_PERSONAL
INSERT INTO Tags.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder)
SELECT t.TagID, v.ResourceKey, v.DefaultLabel, 1, v.SortOrder
FROM Tags.Tags t
CROSS APPLY (VALUES
    (N'TAG_PERSONAL_FAVORITES', N'Favorites', 10),
    (N'TAG_PERSONAL_TODO',      N'To Do',     20),
    (N'TAG_PERSONAL_ARCHIVE',   N'Archive',   30)
) AS v (ResourceKey, DefaultLabel, SortOrder)
WHERE t.ResourceKey = N'TAG_PERSONAL';

COMMIT TRANSACTION;
GO

PRINT 'V00.02.000020 - Tags and Gmail schemas created in ATAPUtilities';
GO

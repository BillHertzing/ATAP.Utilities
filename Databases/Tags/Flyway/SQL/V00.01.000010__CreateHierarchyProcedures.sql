/*
 * Tags Database - Stored Procedures for Hierarchy Traversal
 * Version: 00.01.000010
 *
 * Provides efficient recursive CTE-based procedures for:
 * - Getting full tag tree
 * - Getting ancestors (breadcrumb trail)
 * - Getting descendants
 */

USE [Tags]
GO

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================================
-- Procedure: usp_GetTagTree
-- Purpose: Returns the complete tag hierarchy as a tree structure
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_GetTagTree
    @RootTagID INT = NULL,  -- NULL = all trees, specific ID = subtree from that node
    @MaxDepth INT = 100,    -- Safety limit for recursion
    @ActiveOnly BIT = 1     -- Filter to active tags only
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH TagTree AS (
        -- Anchor: Get root level tags (or specific subtree root)
        SELECT
            TagID,
            ParentTagID,
            ResourceKey,
            DefaultLabel,
            IsActive,
            SortOrder,
            0 AS [Level],
            CAST(RIGHT('0000000000' + CAST(SortOrder AS VARCHAR(10)), 10) + '/' + CAST(TagID AS VARCHAR(10)) AS VARCHAR(MAX)) AS TreePath
        FROM dbo.Tags
        WHERE (@RootTagID IS NULL AND ParentTagID IS NULL)
           OR (@RootTagID IS NOT NULL AND TagID = @RootTagID)

        UNION ALL

        -- Recursive: Get children
        SELECT
            t.TagID,
            t.ParentTagID,
            t.ResourceKey,
            t.DefaultLabel,
            t.IsActive,
            t.SortOrder,
            tt.[Level] + 1,
            tt.TreePath + '/' + RIGHT('0000000000' + CAST(t.SortOrder AS VARCHAR(10)), 10) + '/' + CAST(t.TagID AS VARCHAR(10))
        FROM dbo.Tags t
        INNER JOIN TagTree tt ON t.ParentTagID = tt.TagID
        WHERE tt.[Level] < @MaxDepth
          AND (@ActiveOnly = 0 OR t.IsActive = 1)
    )
    SELECT
        TagID,
        ParentTagID,
        ResourceKey,
        DefaultLabel,
        IsActive,
        SortOrder,
        [Level],
        TreePath
    FROM TagTree
    WHERE @ActiveOnly = 0 OR IsActive = 1
    ORDER BY TreePath;
END
GO

-- ============================================================================
-- Procedure: usp_GetTagAncestors
-- Purpose: Returns all ancestors of a tag (for breadcrumb navigation)
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_GetTagAncestors
    @TagID INT,
    @IncludeSelf BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Ancestors AS (
        -- Anchor: Start with the specified tag
        SELECT
            TagID,
            ParentTagID,
            ResourceKey,
            DefaultLabel,
            SortOrder,
            0 AS [Level]
        FROM dbo.Tags
        WHERE TagID = @TagID

        UNION ALL

        -- Recursive: Get parent
        SELECT
            t.TagID,
            t.ParentTagID,
            t.ResourceKey,
            t.DefaultLabel,
            t.SortOrder,
            a.[Level] + 1
        FROM dbo.Tags t
        INNER JOIN Ancestors a ON t.TagID = a.ParentTagID
    )
    SELECT
        TagID,
        ParentTagID,
        ResourceKey,
        DefaultLabel,
        SortOrder,
        [Level]
    FROM Ancestors
    WHERE @IncludeSelf = 1 OR TagID <> @TagID
    ORDER BY [Level] DESC;  -- Root first, then down to the tag
END
GO

-- ============================================================================
-- Procedure: usp_GetTagDescendants
-- Purpose: Returns all descendants of a tag
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_GetTagDescendants
    @TagID INT,
    @MaxDepth INT = 100,
    @IncludeSelf BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Descendants AS (
        -- Anchor: Start with children of the specified tag
        SELECT
            TagID,
            ParentTagID,
            ResourceKey,
            DefaultLabel,
            IsActive,
            SortOrder,
            1 AS [Level]
        FROM dbo.Tags
        WHERE ParentTagID = @TagID

        UNION ALL

        -- Recursive: Get children
        SELECT
            t.TagID,
            t.ParentTagID,
            t.ResourceKey,
            t.DefaultLabel,
            t.IsActive,
            t.SortOrder,
            d.[Level] + 1
        FROM dbo.Tags t
        INNER JOIN Descendants d ON t.ParentTagID = d.TagID
        WHERE d.[Level] < @MaxDepth
    )
    SELECT
        TagID,
        ParentTagID,
        ResourceKey,
        DefaultLabel,
        IsActive,
        SortOrder,
        [Level]
    FROM Descendants

    UNION ALL

    -- Optionally include self
    SELECT
        TagID,
        ParentTagID,
        ResourceKey,
        DefaultLabel,
        IsActive,
        SortOrder,
        0 AS [Level]
    FROM dbo.Tags
    WHERE TagID = @TagID AND @IncludeSelf = 1

    ORDER BY [Level], SortOrder;
END
GO

PRINT 'Created stored procedures: usp_GetTagTree, usp_GetTagAncestors, usp_GetTagDescendants'
GO

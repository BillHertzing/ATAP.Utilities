/*
 * Tags Database - Views for Common Queries
 * Version: 00.01.000020
 *
 * Provides views for common data access patterns
 */

USE [Tags]
GO

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================================
-- View: vw_ActiveTags
-- Purpose: Returns only active tags with parent info
-- ============================================================================
CREATE OR ALTER VIEW dbo.vw_ActiveTags
AS
SELECT
    t.TagID,
    t.ParentTagID,
    t.ResourceKey,
    t.DefaultLabel,
    t.SortOrder,
    t.CreatedDate,
    t.ModifiedDate,
    p.ResourceKey AS ParentResourceKey,
    p.DefaultLabel AS ParentDefaultLabel
FROM dbo.Tags t
LEFT JOIN dbo.Tags p ON t.ParentTagID = p.TagID
WHERE t.IsActive = 1;
GO

-- ============================================================================
-- View: vw_RootTags
-- Purpose: Returns only top-level (root) tags
-- ============================================================================
CREATE OR ALTER VIEW dbo.vw_RootTags
AS
SELECT
    TagID,
    ResourceKey,
    DefaultLabel,
    SortOrder,
    IsActive,
    CreatedDate
FROM dbo.Tags
WHERE ParentTagID IS NULL
  AND IsActive = 1;
GO

-- ============================================================================
-- View: vw_TagsWithChildCount
-- Purpose: Returns tags with count of direct children
-- ============================================================================
CREATE OR ALTER VIEW dbo.vw_TagsWithChildCount
AS
SELECT
    t.TagID,
    t.ParentTagID,
    t.ResourceKey,
    t.DefaultLabel,
    t.IsActive,
    t.SortOrder,
    (SELECT COUNT(*) FROM dbo.Tags c WHERE c.ParentTagID = t.TagID AND c.IsActive = 1) AS ChildCount,
    CASE WHEN EXISTS (SELECT 1 FROM dbo.Tags c WHERE c.ParentTagID = t.TagID AND c.IsActive = 1)
         THEN 1 ELSE 0 END AS HasChildren
FROM dbo.Tags t;
GO

-- ============================================================================
-- View: vw_TagRelationshipsExpanded
-- Purpose: Returns relationships with resource keys for both sides
-- ============================================================================
CREATE OR ALTER VIEW dbo.vw_TagRelationshipsExpanded
AS
SELECT
    r.RelationshipID,
    r.SourceTagID,
    s.ResourceKey AS SourceResourceKey,
    s.DefaultLabel AS SourceDefaultLabel,
    r.TargetTagID,
    t.ResourceKey AS TargetResourceKey,
    t.DefaultLabel AS TargetDefaultLabel,
    r.RelationshipTypeKey,
    r.IsBidirectional,
    r.Weight,
    r.IsActive
FROM dbo.TagRelationships r
INNER JOIN dbo.Tags s ON r.SourceTagID = s.TagID
INNER JOIN dbo.Tags t ON r.TargetTagID = t.TagID;
GO

PRINT 'Created views: vw_ActiveTags, vw_RootTags, vw_TagsWithChildCount, vw_TagRelationshipsExpanded'
GO

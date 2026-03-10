/*
 * Tags Database - Initial Schema Creation
 * Version: 00.01.000001
 *
 * Creates the core Tags table with hierarchical parent/child relationships
 * using the Adjacency List model and ResourceKey for I18N support.
 *
 * Architecture:
 * - Database stores structure (relationships) only
 * - Text content resides in language-specific DLLs
 * - Application layer bridges DB ↔ DLL via ResourceKey
 */

USE [Tags]
GO

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================================
-- Table: dbo.Tags
-- Purpose: Core tag storage with hierarchical relationships and I18N support
-- ============================================================================
CREATE TABLE dbo.Tags (
    -- Primary key
    TagID INT IDENTITY(1,1) NOT NULL,

    -- Hierarchical parent/child relationship (Adjacency List model)
    -- NULL = root/top-level tag
    ParentTagID INT NULL,

    -- I18N Resource Key - links to language-specific DLL entries
    -- Convention: Use namespace prefixes (e.g., 'TAG_ELECTRONICS', 'TAXONOMY_COMPUTERS')
    -- IMPORTANT: Treat as immutable API contract - never change after creation
    ResourceKey VARCHAR(100) NOT NULL,

    -- Optional fallback label for admin/debugging (English default)
    -- Use only when in-memory caching is not feasible
    DefaultLabel NVARCHAR(256) NULL,

    -- Metadata
    IsActive BIT NOT NULL CONSTRAINT DF_Tags_IsActive DEFAULT (1),
    SortOrder INT NOT NULL CONSTRAINT DF_Tags_SortOrder DEFAULT (0),
    CreatedDate DATETIME2(7) NOT NULL CONSTRAINT DF_Tags_CreatedDate DEFAULT (GETUTCDATE()),
    ModifiedDate DATETIME2(7) NOT NULL CONSTRAINT DF_Tags_ModifiedDate DEFAULT (GETUTCDATE()),

    -- Constraints
    CONSTRAINT PK_Tags PRIMARY KEY CLUSTERED (TagID),
    CONSTRAINT UQ_Tags_ResourceKey UNIQUE NONCLUSTERED (ResourceKey),
    CONSTRAINT FK_Tags_ParentTag FOREIGN KEY (ParentTagID)
        REFERENCES dbo.Tags (TagID)
        ON DELETE NO ACTION  -- Prevent cascade delete of hierarchies
        ON UPDATE NO ACTION
) ON [PRIMARY]
GO

-- Index for efficient hierarchy traversal
CREATE NONCLUSTERED INDEX IX_Tags_ParentTagID
    ON dbo.Tags (ParentTagID)
    INCLUDE (ResourceKey, IsActive, SortOrder)
GO

-- Index for active tags lookup
CREATE NONCLUSTERED INDEX IX_Tags_IsActive
    ON dbo.Tags (IsActive)
    WHERE IsActive = 1
GO

PRINT 'Created table: dbo.Tags'
GO

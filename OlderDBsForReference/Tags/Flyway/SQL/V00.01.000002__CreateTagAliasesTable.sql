/*
 * Tags Database - Tag Aliases Table
 * Version: 00.01.000002
 *
 * Supports alternative resource keys for the same tag
 * Useful for synonyms, abbreviations, or legacy key mappings
 */

USE [Tags]
GO

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================================
-- Table: dbo.TagAliases
-- Purpose: Alternative resource keys mapping to the same tag
-- ============================================================================
CREATE TABLE dbo.TagAliases (
    AliasID INT IDENTITY(1,1) NOT NULL,
    TagID INT NOT NULL,

    -- Alternative resource key (e.g., 'TAG_LAPTOP' → 'TAG_NOTEBOOKS')
    AliasResourceKey VARCHAR(100) NOT NULL,

    -- Type of alias for categorization
    AliasType VARCHAR(50) NOT NULL CONSTRAINT DF_TagAliases_Type DEFAULT ('Synonym'),

    IsActive BIT NOT NULL CONSTRAINT DF_TagAliases_IsActive DEFAULT (1),
    CreatedDate DATETIME2(7) NOT NULL CONSTRAINT DF_TagAliases_CreatedDate DEFAULT (GETUTCDATE()),

    CONSTRAINT PK_TagAliases PRIMARY KEY CLUSTERED (AliasID),
    CONSTRAINT UQ_TagAliases_ResourceKey UNIQUE NONCLUSTERED (AliasResourceKey),
    CONSTRAINT FK_TagAliases_Tag FOREIGN KEY (TagID)
        REFERENCES dbo.Tags (TagID)
        ON DELETE CASCADE
) ON [PRIMARY]
GO

-- Index for tag lookup by alias
CREATE NONCLUSTERED INDEX IX_TagAliases_TagID
    ON dbo.TagAliases (TagID)
GO

PRINT 'Created table: dbo.TagAliases'
GO

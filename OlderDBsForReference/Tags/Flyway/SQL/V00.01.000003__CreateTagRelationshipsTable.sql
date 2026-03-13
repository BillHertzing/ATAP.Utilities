/*
 * Tags Database - Tag Relationships Table
 * Version: 00.01.000003
 *
 * Supports non-hierarchical tag relationships (related tags, see-also, etc.)
 * Separate from parent/child hierarchy in main Tags table
 */

USE [Tags]
GO

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================================
-- Table: dbo.TagRelationships
-- Purpose: Non-hierarchical relationships between tags
-- ============================================================================
CREATE TABLE dbo.TagRelationships (
    RelationshipID INT IDENTITY(1,1) NOT NULL,

    SourceTagID INT NOT NULL,
    TargetTagID INT NOT NULL,

    -- Relationship type resource key (for I18N of relationship names)
    -- Examples: 'REL_RELATED_TO', 'REL_SEE_ALSO', 'REL_OPPOSITE_OF', 'REL_BROADER_THAN'
    RelationshipTypeKey VARCHAR(100) NOT NULL,

    -- Is the relationship bidirectional?
    IsBidirectional BIT NOT NULL CONSTRAINT DF_TagRel_Bidirectional DEFAULT (0),

    -- Relationship strength/weight (for relevance scoring)
    Weight DECIMAL(5,2) NOT NULL CONSTRAINT DF_TagRel_Weight DEFAULT (1.0),

    IsActive BIT NOT NULL CONSTRAINT DF_TagRel_IsActive DEFAULT (1),
    CreatedDate DATETIME2(7) NOT NULL CONSTRAINT DF_TagRel_CreatedDate DEFAULT (GETUTCDATE()),

    CONSTRAINT PK_TagRelationships PRIMARY KEY CLUSTERED (RelationshipID),
    CONSTRAINT UQ_TagRelationships UNIQUE NONCLUSTERED (SourceTagID, TargetTagID, RelationshipTypeKey),
    CONSTRAINT FK_TagRel_SourceTag FOREIGN KEY (SourceTagID)
        REFERENCES dbo.Tags (TagID)
        ON DELETE NO ACTION,
    CONSTRAINT FK_TagRel_TargetTag FOREIGN KEY (TargetTagID)
        REFERENCES dbo.Tags (TagID)
        ON DELETE NO ACTION,
    CONSTRAINT CK_TagRel_NoSelfRef CHECK (SourceTagID <> TargetTagID)
) ON [PRIMARY]
GO

-- Indexes for relationship traversal
CREATE NONCLUSTERED INDEX IX_TagRel_SourceTag
    ON dbo.TagRelationships (SourceTagID)
    INCLUDE (TargetTagID, RelationshipTypeKey)
GO

CREATE NONCLUSTERED INDEX IX_TagRel_TargetTag
    ON dbo.TagRelationships (TargetTagID)
    INCLUDE (SourceTagID, RelationshipTypeKey)
GO

PRINT 'Created table: dbo.TagRelationships'
GO

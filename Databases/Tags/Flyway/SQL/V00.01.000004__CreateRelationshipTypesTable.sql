/*
 * Tags Database - Relationship Types Lookup Table
 * Version: 00.01.000004
 *
 * Defines valid relationship types for TagRelationships
 * Also uses ResourceKey for I18N of relationship type names
 */

USE [Tags]
GO

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================================
-- Table: dbo.RelationshipTypes
-- Purpose: Lookup table for valid relationship types
-- ============================================================================
CREATE TABLE dbo.RelationshipTypes (
    RelationshipTypeID INT IDENTITY(1,1) NOT NULL,

    -- Resource key linking to DLL for localized name
    ResourceKey VARCHAR(100) NOT NULL,

    -- Semantic properties
    IsBidirectionalDefault BIT NOT NULL CONSTRAINT DF_RelType_Bidirectional DEFAULT (0),
    InverseTypeKey VARCHAR(100) NULL,  -- For directional relationships, the inverse key

    -- Fallback description (English)
    DefaultDescription NVARCHAR(256) NULL,

    IsActive BIT NOT NULL CONSTRAINT DF_RelType_IsActive DEFAULT (1),
    SortOrder INT NOT NULL CONSTRAINT DF_RelType_SortOrder DEFAULT (0),
    CreatedDate DATETIME2(7) NOT NULL CONSTRAINT DF_RelType_CreatedDate DEFAULT (GETUTCDATE()),

    CONSTRAINT PK_RelationshipTypes PRIMARY KEY CLUSTERED (RelationshipTypeID),
    CONSTRAINT UQ_RelTypes_ResourceKey UNIQUE NONCLUSTERED (ResourceKey)
) ON [PRIMARY]
GO

PRINT 'Created table: dbo.RelationshipTypes'
GO

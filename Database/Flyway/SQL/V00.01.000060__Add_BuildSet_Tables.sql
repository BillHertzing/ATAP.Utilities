USE ATAPUtilities;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================
   V00.01.000060 — Add BuildSet and BuildSetMember Tables
   ============================================================
   Extends the ATAPUtilities core schema with two tables:
     1. BuildSet       — a named, Philote-backed collection of RuleSets
     2. BuildSetMember — ordered membership linking a BuildSet to its RuleSets
   A BuildSet is composed of one or more RuleSets, analogous to how
   a RuleSet is composed of one or more Rules.
   ============================================================ */

-- ===========================================================
-- DROP in dependency order so this script is re-runnable
-- ===========================================================
IF OBJECT_ID(N'ATAPUtilities.BuildSetMember', N'U') IS NOT NULL DROP TABLE ATAPUtilities.BuildSetMember;
GO
IF OBJECT_ID(N'ATAPUtilities.BuildSet',       N'U') IS NOT NULL DROP TABLE ATAPUtilities.BuildSet;
GO

-- ===========================================================
-- SECTION 1 — BuildSet
-- An ordered collection of RuleSets that together define a
-- complete build configuration.  Mirrors the RuleSet pattern.
-- ===========================================================

CREATE TABLE ATAPUtilities.BuildSet (
    PhiloteId   UNIQUEIDENTIFIER NOT NULL,
    Name        NVARCHAR(200)    NOT NULL,
    Description NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_BuildSet         PRIMARY KEY CLUSTERED (PhiloteId),
    CONSTRAINT FK_BuildSet_Philote FOREIGN KEY (PhiloteId) REFERENCES ATAPUtilities.Philote (PhiloteId),
    CONSTRAINT UQ_BuildSet_Name    UNIQUE (Name)
);
GO

-- ===========================================================
-- SECTION 2 — BuildSetMember
-- Each row records one RuleSet that belongs to a BuildSet,
-- with an explicit sequence number to control application order.
-- ===========================================================

CREATE TABLE ATAPUtilities.BuildSetMember (
    BuildSetMemberId    INT              NOT NULL IDENTITY(1,1),
    BuildSetPhiloteId   UNIQUEIDENTIFIER NOT NULL,  -- FK -> BuildSet
    RuleSetPhiloteId    UNIQUEIDENTIFIER NOT NULL,  -- FK -> RuleSet
    SequenceNumber      INT              NOT NULL,
    Notes               NVARCHAR(MAX)        NULL,
    CONSTRAINT PK_BuildSetMember                PRIMARY KEY CLUSTERED (BuildSetMemberId),
    CONSTRAINT FK_BuildSetMember_BuildSet       FOREIGN KEY (BuildSetPhiloteId) REFERENCES ATAPUtilities.BuildSet (PhiloteId),
    CONSTRAINT FK_BuildSetMember_RuleSet        FOREIGN KEY (RuleSetPhiloteId)  REFERENCES ATAPUtilities.RuleSet  (PhiloteId),
    CONSTRAINT UQ_BuildSetMember_Set_Seq        UNIQUE (BuildSetPhiloteId, SequenceNumber)
);
GO

USE GMail;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* Drop in dependency order if re-running on a dev box (optional safety) */

/* Drop triggers first (depend on tables) */
GO

/* Drop views (depend on tables) */
GO

/* Drop stored procedures */
GO

/* Drop tables in dependency order */
GO

/* === Tables === */
-- Create referenced tables FIRST (no foreign key dependencies)
CREATE TABLE dbo.gmailMessageIDs
(
  ID               int           IDENTITY(1,1) NOT NULL
  ,GmailMessageID   nvarchar(255) NOT NULL
  ,ProcessedAt      datetime2(7)  NOT NULL DEFAULT SYSDATETIME()
  ,CONSTRAINT PK_gmailMessageIDs PRIMARY KEY (ID)
  ,CONSTRAINT UQ_gmailMessageIDs_GmailMessageID UNIQUE (GmailMessageID)
);

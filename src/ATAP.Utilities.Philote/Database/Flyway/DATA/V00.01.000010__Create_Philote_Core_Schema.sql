USE Philotes;
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
IF OBJECT_ID('dbo.Philotes','U') IS NOT NULL DROP TABLE dbo.Philotes;
GO

/* === Tables === */
-- Create referenced tables FIRST (no foreign key dependencies)
CREATE TABLE dbo.Philotes
(
  ID               int            IDENTITY(1,1) NOT NULL
  ,[Name]       nvarchar(400)  NULL
  ,CONSTRAINT PK_Philotes PRIMARY KEY (ID)
);

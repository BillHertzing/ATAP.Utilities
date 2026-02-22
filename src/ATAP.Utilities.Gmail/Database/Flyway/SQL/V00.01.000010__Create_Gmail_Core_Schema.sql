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
IF OBJECT_ID('dbo.gmailMessages','U') IS NOT NULL DROP TABLE dbo.gmailMessages;
GO

/* === Tables === */
-- Create referenced tables FIRST (no foreign key dependencies)
CREATE TABLE dbo.gmailMessages
(
  ID               int            IDENTITY(1,1) NOT NULL
  ,[Subject]       nvarchar(400)  NULL
  ,[MessageId]     nvarchar(400)  NULL
  ,[FromAddress]   nvarchar(400)  NULL
  ,[ToAddress]     nvarchar(400)  NULL
  ,[Date]          datetime2      NULL
  ,[Labels]        nvarchar(1000) NULL
  ,[Body]          nvarchar(MAX)  NULL
  ,[URL]           nvarchar(2000) NULL
  ,CONSTRAINT PK_gmailMessages PRIMARY KEY (ID)
);

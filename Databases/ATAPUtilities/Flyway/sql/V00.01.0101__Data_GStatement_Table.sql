USE [ATAPUtilities]
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

SET IDENTITY_INSERT dbo.GStatement ON
Insert into GStatement (Id, [Statement]) Values
  (1, 'Comment 1 Statement 1'),
  (2, 'Comment 1 Statement 2'),
  (3, 'Comment 2 Statement 1'),
  (4, 'Comment 2 Statement 2'),
  (5, 'Comment 2 Statement 3')
;
SET IDENTITY_INSERT dbo.GStatement OFF
GO

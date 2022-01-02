USE [ATAPUtilities]
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

DROP FUNCTION IF EXISTS [dbo].[udfIsNullOrEmpty]
GO

CREATE FUNCTION [dbo].[udfIsNullOrEmpty](@x varchar(max)) returns bit as
BEGIN
DECLARE
  @retVal bit
  IF @x IS NOT NULL AND LEN(@x) > 0
    SET @retVal = 0
  ELSE
    SET @retVal = 1
  RETURN @retVal
END

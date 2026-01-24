
-- Purpose: Provide a reusable verification procedure instead of ad-hoc SELECT statements in the migration.
-- The original direct SELECT calls are encapsulated in dbo.VerifyRuleSets. Set @ExecuteNow = 1 to run immediately.

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.VerifyRuleSets
  @MaxDepth int = -1,      -- pass depth to underlying function
  @IncludeRulesOnly bit = 0
AS
BEGIN
  SET NOCOUNT ON;

  -- Return hierarchical listings per RuleSetID (0..9) mirroring original checks
  DECLARE @RuleSetID int = 0;
  WHILE @RuleSetID <= 9
  BEGIN
    IF EXISTS (SELECT 1 FROM dbo.RuleSet WHERE ID = @RuleSetID)
    BEGIN
      SELECT @RuleSetID AS RuleSetID,
             *
      FROM dbo.SORTED_RULEITEMID_RULESETID_Is_VALUE(0, @MaxDepth, @RuleSetID, @IncludeRulesOnly);
    END
    SET @RuleSetID += 1;
  END

  -- Summary counts
  SELECT COUNT(*) AS RuleSetCount FROM dbo.RuleSet; -- (expected ~11 per original comment)
  SELECT COUNT(*) AS ItemsInRuleSet8 FROM dbo.RuleSetHavingRuleItem WHERE RuleSetID = 8; -- (expected 30)
END
GO

-- Optional immediate execution (disabled by default to avoid noisy result sets during Flyway migrate)
DECLARE @ExecuteNow bit = 0; -- change to 1 locally if you want it to run automatically
IF @ExecuteNow = 1
BEGIN
  EXEC dbo.VerifyRuleSets @MaxDepth = -1, @IncludeRulesOnly = 0;
END
GO

/*  This file is a repeatable migration script for creating or altering
    SQL functions used by the BuildSets database

    It is intended to be idempotent, so it can be run multiple times without
    error, and will update existing functions if they have changed.

    The functions here are used to retrieve hierarchical rule items from
    the database .
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* Constant helper (default RuleSet to use if omitted) */
CREATE OR ALTER FUNCTION dbo.CURRENTRULESETID_CONSTANT()
RETURNS int
AS
BEGIN
  RETURN 8;
-- matches the largest sample set from the screenshots
END
GO

CREATE OR ALTER FUNCTION dbo.RULEITEMS_RULESETID_Is_VALUE(@RuleSetID int)
RETURNS TABLE
AS
RETURN
WITH
  setitems
  AS
  (
    SELECT ri.ID ,ri.ParentID ,ri.PeerSortOrder ,ri.SymbolicName ,ri.ItemText
    FROM dbo.RuleItem ri
      JOIN dbo.RuleSetHavingRuleItem x ON x.RuleItemID = ri.ID
    WHERE x.RuleSetID = @RuleSetID
  )
SELECT
  si.ItemText
  ,si.ID
  -- Re-root any node whose parent is not present in the set
  ,CASE WHEN p.ID IS NULL THEN NULL ELSE si.ParentID END AS ParentID
  ,si.PeerSortOrder
  ,si.SymbolicName
FROM setitems si
  LEFT JOIN setitems p ON p.ID = si.ParentID;
GO

/* Sorted recursive TVF (fixed type mismatch for pathstr) */
CREATE OR ALTER FUNCTION dbo.SORTED_RULEITEMID_RULESETID_Is_VALUE
(
  @InitItemID int = 0,
  @depth      int = -1,
  @RuleSetID  int = NULL,         -- allow NULL then substitute inside query
  @rulesOnly  bit = 1
)
RETURNS TABLE
AS
RETURN
WITH
  baseSet
  AS
  (
    SELECT *
    FROM dbo.RULEITEMS_RULESETID_Is_VALUE(COALESCE(@RuleSetID, dbo.CURRENTRULESETID_CONSTANT()))
  )
  ,ret (ItemText ,ID ,depth ,pathstr)
  AS
  (
    -- roots are those with ParentID NULL after re-rooting
          SELECT b.ItemText ,b.ID ,0 ,CAST(N'' AS nvarchar(max)) AS pathstr
      FROM baseSet b
      WHERE b.ParentID IS NULL
    UNION ALL
      SELECT v.ItemText ,v.ID ,t.depth + 1 ,CAST(t.pathstr + N'::' + v.ItemText AS nvarchar(max))
      FROM baseSet v
        JOIN ret t ON v.ParentID = t.ID
      WHERE (@depth < 0 OR t.depth + 1 <= @depth)
  )
SELECT TOP (100) PERCENT
  SPACE(depth) + ItemText AS ItemText ,ID ,depth ,pathstr
FROM ret
ORDER BY pathstr, ID;
GO

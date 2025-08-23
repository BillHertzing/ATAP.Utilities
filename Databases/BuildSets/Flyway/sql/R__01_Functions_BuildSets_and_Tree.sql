-- file: R__01_Functions_BuildSets_and_Tree.sql
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* Constant helper (default RuleSet to use if omitted) */

CREATE OR ALTER FUNCTION dbo.CURRENTRULESETID_CONSTANT()
RETURNS int
AS
BEGIN
  RETURN 8;  -- matches the largest sample set from the screenshots
END
GO

CREATE OR ALTER FUNCTION dbo.RULEITEMS_RULESETID_Is_VALUE(@RuleSetID int)
RETURNS TABLE
AS
RETURN
WITH setitems AS (
  SELECT ri.ID, ri.ParentID, ri.PeerSortOrder, ri.SymbolicName, ri.ItemText
  FROM dbo.RuleItem ri
  JOIN dbo.RuleSetHavingRuleItem x ON x.RuleItemID = ri.ID
  WHERE x.RuleSetID = @RuleSetID
)
SELECT
  si.ItemText,
  si.ID,
    /* Re-root any node whose parent is not present in the set */
  CASE WHEN p.ID IS NULL THEN NULL ELSE si.ParentID END AS ParentID,
  si.PeerSortOrder,
  si.SymbolicName
FROM setitems si
LEFT JOIN setitems p ON p.ID = si.ParentID;
GO

/* Sorted recursive TVF, per your “udf” screenshot */CREATE OR ALTER FUNCTION dbo.SORTED_RULEITEMID_RULESETID_Is_VALUE
(
  @InitItemID int = 0,
  @depth      int = -1,
  @RuleSetID int = dbo.CURRENTRULESETID_CONSTANT(),
  @rulesOnly  bit = 1
)
RETURNS TABLE
AS
RETURN
WITH ret (ItemText, ID, depth, pathstr) AS
(
  /* roots are those with ParentID NULL *after* re-rooting */
  SELECT s.ItemText, s.ID, 0, CAST('' AS varchar(max))
  FROM dbo.RULEITEMS_RULESETID_Is_VALUE(@RuleSetID) s
  WHERE s.ParentID IS NULL
  UNION ALL
  SELECT v.ItemText, v.ID, t.depth + 1, t.pathstr + '::' + v.ItemText
  FROM dbo.RULEITEMS_RULESETID_Is_VALUE(@RuleSetID) v
  JOIN ret t ON v.ParentID = t.ID
)
SELECT TOP (100) PERCENT SPACE(depth) + ItemText AS ItemText, ID, depth, pathstr
FROM ret
ORDER BY pathstr, ID;
GO

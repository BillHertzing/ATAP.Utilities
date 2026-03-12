USE ATAPUtilities;
GO

/* ============================================================
   Query_Generate_HelloWorld_From_Rules.sql
   ============================================================
   Reads rule instantiation bindings for a HelloWorld example and
   returns normalized artifact rows that can be materialized by
   a caller (PowerShell/Pester) under Database/_generated.
   ============================================================ */

DECLARE @ProgramRuleName NVARCHAR(200) = N'Example.HelloWorld.Program.cs';
DECLARE @ClassRuleName NVARCHAR(200) = N'Example.HelloWorld.HelloWorld.cs';
DECLARE @ProjectRuleName NVARCHAR(200) = N'Example.HelloWorld.HelloWorld.csproj';
DECLARE @FolderRuleName NVARCHAR(200) = N'Example.HelloWorld.Folder';

WITH RuleBindings AS (
  SELECT
    r.[Name] AS RuleName,
    rib.InputName,
    rib.InputValue
  FROM ATAPUtilities.[Rule] AS r
    INNER JOIN ATAPUtilities.RuleInstantiation AS ri
      ON ri.RulePhiloteId = r.PhiloteId
    INNER JOIN ATAPUtilities.RuleInstantiationBinding AS rib
      ON rib.InstantiationPhiloteId = ri.PhiloteId
  WHERE r.[Name] IN (@ProgramRuleName, @ClassRuleName, @ProjectRuleName, @FolderRuleName)
),
FolderArtifact AS (
  SELECT
    10 AS SortOrder,
    N'Directory' AS ItemType,
    MAX(CASE WHEN InputName = N'RelativePath' THEN InputValue END) AS RelativePath,
    CAST(NULL AS NVARCHAR(260)) AS FileName,
    CAST(NULL AS NVARCHAR(MAX)) AS FileContent
  FROM RuleBindings
  WHERE RuleName = @FolderRuleName
),
FileArtifacts AS (
  SELECT
    CASE RuleName
      WHEN @ProgramRuleName THEN 20
      WHEN @ClassRuleName THEN 30
      WHEN @ProjectRuleName THEN 40
      ELSE 90
    END AS SortOrder,
    N'File' AS ItemType,
    MAX(CASE WHEN InputName = N'RelativePath' THEN InputValue END) AS RelativePath,
    MAX(CASE WHEN InputName = N'FileName' THEN InputValue END) AS FileName,
    MAX(CASE WHEN InputName = N'FileContent' THEN InputValue END) AS FileContent
  FROM RuleBindings
  WHERE RuleName IN (@ProgramRuleName, @ClassRuleName, @ProjectRuleName)
  GROUP BY RuleName
)
SELECT
  SortOrder,
  ItemType,
  RelativePath,
  FileName,
  FileContent
FROM FolderArtifact
UNION ALL
SELECT
  SortOrder,
  ItemType,
  RelativePath,
  FileName,
  FileContent
FROM FileArtifacts
ORDER BY SortOrder;

GO

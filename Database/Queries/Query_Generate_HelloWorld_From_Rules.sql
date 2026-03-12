USE ;

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

WITH
   AS (
    SELECT
      .[Name] AS ,
      .[Name] AS ,
      . AS ,
      .,
      .
    FROM
      .[Rule] 
      INNER JOIN .  ON . = .
      INNER JOIN .  ON . = .
      INNER JOIN .  ON . = .
    WHERE
      .[Name] IN (@ProgramRuleName, @ClassRuleName, @ProjectRuleName, @FolderRuleName)
  ),
   AS (
    SELECT
      10 AS ,
      N'Directory' AS ,
      MAX(
        CASE
          WHEN  = N'RelativePath' THEN 
        END
      ) AS ,
      CAST(NULL AS NVARCHAR(260)) AS ,
      CAST(NULL AS NVARCHAR()) AS 
    FROM
      
    WHERE
       = @FolderRuleName
  ),
   AS (
    SELECT
      CASE 
        WHEN @ProgramRuleName THEN 20
        WHEN @ClassRuleName THEN 30
        WHEN @ProjectRuleName THEN 40
        ELSE 90
      END AS ,
      N'File' AS ,
      MAX(
        CASE
          WHEN  = N'RelativePath' THEN 
        END
      ) AS ,
      MAX(
        CASE
          WHEN  = N'FileName' THEN 
        END
      ) AS ,
      MAX(
        CASE
          WHEN  = N'FileContent' THEN 
        END
      ) AS 
    FROM
      
    WHERE
       IN (@ProgramRuleName, @ClassRuleName, @ProjectRuleName)
    GROUP BY
      
  )
SELECT
  ,
  ,
  ,
  ,
  
FROM
  
UNION ALL
SELECT
  ,
  ,
  ,
  ,
  
FROM
  
ORDER BY
  ;

GO

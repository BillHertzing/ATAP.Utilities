USE ATAPUtilities;
GO

/* ============================================================
   Query_Rule_By_Name.sql
   ============================================================
   Standalone SQL script to query a Rule and all its metadata.
   This script can be run directly in SQL Server Management Studio
   or called from other tools.

   Usage:
   1. Update the @RuleName variable below with your desired rule name
   2. Optionally update @LanguageKind to filter by language
   3. Execute the script
   ============================================================ */

-- ============================================================
-- CONFIGURATION PARAMETERS
-- ============================================================
DECLARE @RuleName NVARCHAR(200) = N'<cs-source-file>';  -- Change this to your desired rule name
DECLARE @LanguageKind NVARCHAR(50) = N'CSharp';          -- Change to NULL to see all languages, or 'CSharp', 'Powershell', 'SQL', 'MSBuild'

-- ============================================================
-- QUERY EXECUTION
-- ============================================================
PRINT '===============================================================================';
PRINT 'Rule Query Report';
PRINT 'Generated: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '===============================================================================';
PRINT '';

-- Display search parameters
PRINT 'SEARCH PARAMETERS:';
PRINT '  Rule Name: ' + @RuleName;
PRINT '  Language Kind: ' + ISNULL(@LanguageKind, 'ALL');
PRINT '';

-- ============================================================
-- QUERY 1: Rule Basic Information
-- ============================================================
PRINT '===============================================================================';
PRINT 'RULE INFORMATION';
PRINT '===============================================================================';

SELECT
    r.PhiloteId AS [PhiloteID],
    r.Name AS [Rule Name],
    plk.Name AS [Language Kind],
    r.Purpose,
    r.SourceFileReference AS [Source Reference],
    p.CreatedAt AS [Created At]
FROM
    dbo.[Rule] r
    INNER JOIN dbo.Philote p ON r.PhiloteId = p.PhiloteId
    INNER JOIN dbo.PrimitiveLanguageKind plk ON r.PrimitiveLanguageKindId = plk.PrimitiveLanguageKindId
WHERE
    r.Name = @RuleName
    AND (@LanguageKind IS NULL OR plk.Name = @LanguageKind);

IF @@ROWCOUNT = 0
BEGIN
    PRINT '';
    PRINT 'WARNING: No Rule found matching the specified criteria.';
    PRINT '';
    RETURN;
END

PRINT '';

-- ============================================================
-- QUERY 2: Rule Primitive Composition
-- ============================================================
PRINT '===============================================================================';
PRINT 'RULE COMPOSITION (Ordered Primitives)';
PRINT '===============================================================================';

SELECT
    rpc.SequenceKey AS [Seq],
    rp.Name AS [Primitive Name],
    rp.Description AS [Description],
    rp.BnfDefinition AS [BNF Definition],
    rpc.BoundInputsJson AS [Bound Inputs (JSON)],
    rpc.Notes AS [Notes],
    rp.Attribution AS [Attribution]
FROM
    dbo.[Rule] r
    INNER JOIN dbo.RulePrimitiveComposition rpc ON r.PhiloteId = rpc.RulePhiloteId
    INNER JOIN dbo.RulePrimitive rp ON rpc.PrimitivePhiloteId = rp.PhiloteId
    INNER JOIN dbo.PrimitiveLanguageKind plk ON r.PrimitiveLanguageKindId = plk.PrimitiveLanguageKindId
WHERE
    r.Name = @RuleName
    AND (@LanguageKind IS NULL OR plk.Name = @LanguageKind)
ORDER BY
    rpc.SequenceKey;

IF @@ROWCOUNT = 0
    PRINT '  (No primitives in composition)';

PRINT '';

-- ============================================================
-- QUERY 3: Additional Philote IDs
-- ============================================================
PRINT '===============================================================================';
PRINT 'ADDITIONAL PHILOTE IDs';
PRINT '===============================================================================';

SELECT
    pai.KeyName AS [Key Name],
    pai.ValueId AS [Value ID]
FROM
    dbo.[Rule] r
    INNER JOIN dbo.PhiloteAdditionalId pai ON r.PhiloteId = pai.PhiloteId
    INNER JOIN dbo.PrimitiveLanguageKind plk ON r.PrimitiveLanguageKindId = plk.PrimitiveLanguageKindId
WHERE
    r.Name = @RuleName
    AND (@LanguageKind IS NULL OR plk.Name = @LanguageKind);

IF @@ROWCOUNT = 0
    PRINT '  (No additional IDs)';

PRINT '';

-- ============================================================
-- QUERY 4: Time Blocks
-- ============================================================
PRINT '===============================================================================';
PRINT 'TIME BLOCKS';
PRINT '===============================================================================';

SELECT
    ptb.StartAt AS [Start At],
    ISNULL(CONVERT(VARCHAR, ptb.EndAt, 120), 'Ongoing') AS [End At]
FROM
    dbo.[Rule] r
    INNER JOIN dbo.PhiloteTimeBlock ptb ON r.PhiloteId = ptb.PhiloteId
    INNER JOIN dbo.PrimitiveLanguageKind plk ON r.PrimitiveLanguageKindId = plk.PrimitiveLanguageKindId
WHERE
    r.Name = @RuleName
    AND (@LanguageKind IS NULL OR plk.Name = @LanguageKind);

IF @@ROWCOUNT = 0
    PRINT '  (No time blocks)';

PRINT '';

-- ============================================================
-- QUERY 5: Rules in Rule Sets (if applicable)
-- ============================================================
PRINT '===============================================================================';
PRINT 'RULE SETS CONTAINING THIS RULE';
PRINT '===============================================================================';

SELECT
    rs.Name AS [Rule Set Name],
    rs.Description AS [Rule Set Description],
    rsm.SequenceNumber AS [Position in Set],
    rsm.Notes AS [Notes]
FROM
    dbo.[Rule] r
    INNER JOIN dbo.RuleSetMember rsm ON r.PhiloteId = rsm.RulePhiloteId
    INNER JOIN dbo.RuleSet rs ON rsm.RuleSetPhiloteId = rs.PhiloteId
    INNER JOIN dbo.PrimitiveLanguageKind plk ON r.PrimitiveLanguageKindId = plk.PrimitiveLanguageKindId
WHERE
    r.Name = @RuleName
    AND (@LanguageKind IS NULL OR plk.Name = @LanguageKind)
ORDER BY
    rs.Name, rsm.SequenceNumber;

IF @@ROWCOUNT = 0
    PRINT '  (Not a member of any Rule Sets)';

PRINT '';
PRINT '===============================================================================';
PRINT 'End of Report';
PRINT '===============================================================================';
GO

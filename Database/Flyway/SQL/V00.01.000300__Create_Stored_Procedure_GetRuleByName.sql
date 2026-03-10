USE ATAPUtilities;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================
   V00.01.000300 — Create Stored Procedure: GetRuleByName
   ============================================================
   Retrieves a Rule by Name and returns all metadata including:
   - PhiloteID
   - Name
   - Purpose
   - PrimitiveLanguageKind
   - SourceFileReference
   - CreatedAt timestamp from Philote
   - Associated RulePrimitives in the composition
   ============================================================ */

-- Drop procedure if it exists
IF OBJECT_ID(N'dbo.GetRuleByName', N'P') IS NOT NULL
    DROP PROCEDURE dbo.GetRuleByName;
GO

CREATE PROCEDURE dbo.GetRuleByName
    @RuleName NVARCHAR(200),
    @LanguageKindName NVARCHAR(50) = NULL  -- Optional: filter by language (e.g., 'CSharp', 'Powershell', 'SQL', 'MSBuild')
AS
BEGIN
    SET NOCOUNT ON;

    -- Main Rule information
    SELECT
        r.PhiloteId,
        r.Name AS RuleName,
        r.Purpose,
        plk.Name AS PrimitiveLanguageKind,
        r.SourceFileReference,
        p.CreatedAt
    FROM
        dbo.[Rule] r
        INNER JOIN dbo.Philote p ON r.PhiloteId = p.PhiloteId
        INNER JOIN dbo.PrimitiveLanguageKind plk ON r.PrimitiveLanguageKindId = plk.PrimitiveLanguageKindId
    WHERE
        r.Name = @RuleName
        AND (@LanguageKindName IS NULL OR plk.Name = @LanguageKindName);

    -- Rule Primitive Composition details
    SELECT
        rpc.SequenceKey,
        rp.Name AS PrimitiveName,
        rp.Description AS PrimitiveDescription,
        rp.BnfDefinition,
        rp.Attribution AS PrimitiveAttribution,
        rpc.BoundInputsJson,
        rpc.Notes
    FROM
        dbo.[Rule] r
        INNER JOIN dbo.RulePrimitiveComposition rpc ON r.PhiloteId = rpc.RulePhiloteId
        INNER JOIN dbo.RulePrimitive rp ON rpc.PrimitivePhiloteId = rp.PhiloteId
        INNER JOIN dbo.PrimitiveLanguageKind plk ON r.PrimitiveLanguageKindId = plk.PrimitiveLanguageKindId
    WHERE
        r.Name = @RuleName
        AND (@LanguageKindName IS NULL OR plk.Name = @LanguageKindName)
    ORDER BY
        rpc.SequenceKey;

    -- Philote Additional IDs (if any)
    SELECT
        pai.KeyName,
        pai.ValueId
    FROM
        dbo.[Rule] r
        INNER JOIN dbo.PhiloteAdditionalId pai ON r.PhiloteId = pai.PhiloteId
        INNER JOIN dbo.PrimitiveLanguageKind plk ON r.PrimitiveLanguageKindId = plk.PrimitiveLanguageKindId
    WHERE
        r.Name = @RuleName
        AND (@LanguageKindName IS NULL OR plk.Name = @LanguageKindName);

    -- Philote Time Blocks (if any)
    SELECT
        ptb.StartAt,
        ptb.EndAt
    FROM
        dbo.[Rule] r
        INNER JOIN dbo.PhiloteTimeBlock ptb ON r.PhiloteId = ptb.PhiloteId
        INNER JOIN dbo.PrimitiveLanguageKind plk ON r.PrimitiveLanguageKindId = plk.PrimitiveLanguageKindId
    WHERE
        r.Name = @RuleName
        AND (@LanguageKindName IS NULL OR plk.Name = @LanguageKindName);
END
GO

-- Grant execute permissions (adjust as needed for your security model)
-- GRANT EXECUTE ON dbo.GetRuleByName TO [YourApplicationRole];
-- GO

PRINT 'Stored procedure dbo.GetRuleByName created successfully';
GO

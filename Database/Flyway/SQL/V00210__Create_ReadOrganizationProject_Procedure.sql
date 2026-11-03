/*
  V00210__Create_ReadOrganizationProject_Procedure.sql: forward organization migration.
  Body copied from Database/Schema/ACE/ReadOrganizationProject.sql without semantic changes.
  No DROP, enrollment execution, grants or existing shared-identity adoption.
  Release/execution authority remains separately bound to the Experimental target.
*/
CREATE PROCEDURE [ACE].[ReadOrganizationProject]
    @ProjectId uniqueidentifier,
    @PersonId uniqueidentifier,
    @EffectiveAtUtc datetime2(7)
AS
BEGIN
    SET NOCOUNT ON;
    IF DB_NAME() <> N'ATAPUtilities' OR @@TRANCOUNT <> 1 OR XACT_STATE() <> 1
        THROW 62800, N'Project read requires the qualified caller-owned eligibility transaction.', 1;
    IF @ProjectId IS NULL OR @PersonId IS NULL OR @EffectiveAtUtc IS NULL
        THROW 62801, N'Explicit project, server-resolved Person and effective instant are required.', 1;

    SELECT p.[ProjectId], p.[ProjectCode], p.[DisplayName],
           pp.[ValidFromUtc] AS ProjectFromUtc, pp.[ValidToUtc] AS ProjectToUtc,
           s.[ProjectStateId], s.[StatusCode], s.[ValidFromUtc] AS StateFromUtc, s.[ValidToUtc] AS StateToUtc,
           sp.[ValidFromUtc] AS StateParentFromUtc, sp.[ValidToUtc] AS StateParentToUtc,
           o.[ProjectOwnershipId] AS OwnershipId, o.[OwnerPersonId], owner.[DisplayName] AS OwnerDisplayName,
           op.[ValidFromUtc] AS OwnershipFromUtc, op.[ValidToUtc] AS OwnershipToUtc,
           ownerp.[ValidFromUtc] AS OwnerFromUtc, ownerp.[ValidToUtc] AS OwnerToUtc,
           g.[RoleAssignmentId], g.[PersonId] AS RolePersonId, g.[ProjectId] AS RoleProjectId, g.[RoleCode],
           g.[ValidFromUtc] AS RoleFromUtc, g.[ValidToUtc] AS RoleToUtc
    FROM [ACE].[Project] p WITH (HOLDLOCK)
    JOIN [ATAPUtilities].[PhiloteValidityPeriod] pp WITH (HOLDLOCK)
      ON pp.[PhiloteId] = p.[ProjectId] AND pp.[ValidFromUtc] <= @EffectiveAtUtc AND (pp.[ValidToUtc] IS NULL OR @EffectiveAtUtc < pp.[ValidToUtc])
    JOIN [ACE].[ProjectState] s WITH (HOLDLOCK)
      ON s.[ProjectId] = p.[ProjectId] AND s.[ValidFromUtc] <= @EffectiveAtUtc AND (s.[ValidToUtc] IS NULL OR @EffectiveAtUtc < s.[ValidToUtc])
    JOIN [ATAPUtilities].[PhiloteValidityPeriod] sp WITH (HOLDLOCK)
      ON sp.[PhiloteId] = p.[ProjectId] AND sp.[PhiloteValidityPeriodId] = s.[PhiloteValidityPeriodId]
    JOIN [ACE].[ProjectOwnership] o WITH (HOLDLOCK) ON o.[ProjectId] = p.[ProjectId]
    JOIN [ATAPUtilities].[PhiloteValidityPeriod] op WITH (HOLDLOCK)
      ON op.[PhiloteId] = o.[ProjectOwnershipId] AND op.[ValidFromUtc] <= @EffectiveAtUtc AND (op.[ValidToUtc] IS NULL OR @EffectiveAtUtc < op.[ValidToUtc])
    JOIN [ACE].[Person] owner WITH (HOLDLOCK) ON owner.[PersonId] = o.[OwnerPersonId]
    JOIN [ATAPUtilities].[PhiloteValidityPeriod] ownerp WITH (HOLDLOCK)
      ON ownerp.[PhiloteId] = owner.[PersonId] AND ownerp.[ValidFromUtc] <= @EffectiveAtUtc AND (ownerp.[ValidToUtc] IS NULL OR @EffectiveAtUtc < ownerp.[ValidToUtc])
    LEFT JOIN (
        SELECT r.[RoleAssignmentId], r.[PersonId], r.[ProjectId], r.[RoleCode], rp.[ValidFromUtc], rp.[ValidToUtc]
        FROM [ACE].[RoleAssignment] r WITH (HOLDLOCK)
        JOIN [ATAPUtilities].[PhiloteValidityPeriod] rp WITH (HOLDLOCK)
          ON rp.[PhiloteId] = r.[RoleAssignmentId] AND rp.[ValidFromUtc] <= @EffectiveAtUtc AND (rp.[ValidToUtc] IS NULL OR @EffectiveAtUtc < rp.[ValidToUtc])
        WHERE r.[PersonId] = @PersonId AND r.[ProjectId] = @ProjectId AND r.[HouseholdId] IS NULL
          AND r.[RoleCode] IN ('Developer','Administrator')
    ) g ON g.[ProjectId] = p.[ProjectId]
    WHERE p.[ProjectId] = @ProjectId AND p.[ProjectCode] = 'Ace';
    -- Preserve all covering state/owner/role combinations. The consumer rejects ambiguity;
    -- zero roles remains explicit and never turns ownership into permission.
END;

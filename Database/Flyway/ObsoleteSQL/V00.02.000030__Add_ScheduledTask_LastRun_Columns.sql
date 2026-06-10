USE ATAPUtilities;
GO

SET XACT_ABORT ON;
SET NOCOUNT ON;
GO

/* ============================================================
   V00.02.000020 — Split Next run / Last run on ScheduledTask
   ============================================================
   Adds three columns that record the *most recent* run's
   summary directly on ScheduledTask, so the list view does
   not have to fan out to ScheduledTaskRun for every row.

     [LastRunUtc]    DATETIME2(7)  NULL   — when the last run completed
     [LastRunStatus] NVARCHAR(20)  NULL   — Running | Succeeded | Failed | Cancelled
     [LastExitCode]  INT           NULL   — process exit code, if recorded

   Backfill: copies values from the most recent ScheduledTaskRun
   for each task (by StartedUtc desc) — uses an APPLY for clarity
   and to avoid a temp table.

   Relaxes the CHECK constraint that required NextRunUtc OR
   RepeatSchedule to be non-null. Completed one-shots now have
   NextRunUtc=NULL AND RepeatSchedule=NULL AND LastRunUtc set —
   the new predicate accepts that.
   ============================================================ */

-- ── 1. Add columns ────────────────────────────────────────
ALTER TABLE [AceCommander].[ScheduledTask] ADD
    [LastRunUtc]    DATETIME2(7)  NULL,
    [LastRunStatus] NVARCHAR(20)  NULL,
    [LastExitCode]  INT           NULL;
GO

-- ── 2. Constrain LastRunStatus to the enum domain ─────────
ALTER TABLE [AceCommander].[ScheduledTask] WITH CHECK ADD
    CONSTRAINT [CK_AceCommander_ScheduledTask_LastRunStatus] CHECK
        ([LastRunStatus] IS NULL
         OR [LastRunStatus] IN (N'Running', N'Succeeded', N'Failed', N'Cancelled'));
GO

-- ── 3. Backfill from the latest ScheduledTaskRun ──────────
UPDATE  T
SET     T.[LastRunUtc]    = R.[CompletedUtc],
        T.[LastRunStatus] = R.[Status],
        T.[LastExitCode]  = R.[ExitCode]
FROM    [AceCommander].[ScheduledTask] AS T
CROSS APPLY (
    SELECT TOP (1) R2.[CompletedUtc], R2.[Status], R2.[ExitCode]
    FROM   [AceCommander].[ScheduledTaskRun] AS R2
    WHERE  R2.[ScheduledTaskId] = T.[Id]
       AND R2.[CompletedUtc]    IS NOT NULL
    ORDER BY R2.[StartedUtc] DESC
) AS R;
GO

-- ── 4. Relax CK_AceCommander_ScheduledTask_Schedule ───────
IF OBJECT_ID(N'[AceCommander].[CK_AceCommander_ScheduledTask_Schedule]', N'C') IS NOT NULL
    ALTER TABLE [AceCommander].[ScheduledTask] DROP CONSTRAINT [CK_AceCommander_ScheduledTask_Schedule];
GO

ALTER TABLE [AceCommander].[ScheduledTask] WITH CHECK ADD
    CONSTRAINT [CK_AceCommander_ScheduledTask_Schedule] CHECK
        ([NextRunUtc]     IS NOT NULL
      OR NULLIF(LTRIM(RTRIM([RepeatSchedule])), N'') IS NOT NULL
      OR [LastRunUtc]     IS NOT NULL);
GO

-- ── 5. Re-enable previously auto-disabled completed one-shots ────
--      The old service set IsEnabled=0 on one-shots after they ran
--      (to satisfy the old CHECK).  Now that they're allowed to have
--      NULL NextRunUtc + NULL RepeatSchedule with a LastRunUtc, we
--      flip them back to Enabled=1 so the UI can show them under
--      "Completed" (Enabled, but with no Next run) rather than
--      "Disabled".  The due-tasks poller filters on NextRunUtc so
--      they won't re-fire.
UPDATE [AceCommander].[ScheduledTask]
SET    [IsEnabled] = 1
WHERE  [IsEnabled] = 0
   AND [NextRunUtc]     IS NULL
   AND NULLIF(LTRIM(RTRIM([RepeatSchedule])), N'') IS NULL
   AND [LastRunUtc]     IS NOT NULL;
GO

-- ── 6. Add an index for "by Last run desc" sort ───────────
CREATE INDEX [IX_AceCommander_ScheduledTask_LastRunUtc]
    ON [AceCommander].[ScheduledTask] ([LastRunUtc] DESC)
    INCLUDE ([Name], [LastRunStatus], [LastExitCode]);
GO

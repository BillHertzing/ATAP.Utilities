-- Verify_ScheduledTask_Schema.sql -- See README in this folder.
-- DO NOT auto-format. SQL formatters strip the database name from USE and
-- strip "sys." from system-catalog references.
-- Run via sqlcmd / Invoke-Sqlcmd targeting ATAPUtilities directly; no USE.

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @errCount INT = 0;
DECLARE @msg NVARCHAR(400);
DECLARE @missingCol SYSNAME;

IF SCHEMA_ID(N'AceCommander') IS NULL
BEGIN
    SET @errCount = @errCount + 1;
    RAISERROR(N'FAIL: schema [AceCommander] is missing', 16, 1);
END;

IF OBJECT_ID(N'[AceCommander].[ScheduledTask]', N'U') IS NULL
BEGIN
    SET @errCount = @errCount + 1;
    RAISERROR(N'FAIL: table [AceCommander].[ScheduledTask] is missing', 16, 1);
END;

IF OBJECT_ID(N'[AceCommander].[ScheduledTaskRun]', N'U') IS NULL
BEGIN
    SET @errCount = @errCount + 1;
    RAISERROR(N'FAIL: table [AceCommander].[ScheduledTaskRun] is missing', 16, 1);
END;

DECLARE @expectedTaskCols TABLE (col SYSNAME PRIMARY KEY);
INSERT INTO @expectedTaskCols(col) VALUES
    (N'Id'), (N'UserId'), (N'Name'), (N'NextRunUtc'),
    (N'RepeatSchedule'), (N'RunAs'), (N'WithProfile'),
    (N'ScriptToRunPath'), (N'ExecutionMode'), (N'IsEnabled'),
    (N'CreatedUtc'), (N'ModifiedUtc'),
    (N'LastRunUtc'), (N'LastRunStatus'), (N'LastExitCode');

DECLARE missingCol_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT e.col FROM @expectedTaskCols AS e
    WHERE COL_LENGTH(N'[AceCommander].[ScheduledTask]', e.col) IS NULL;
OPEN missingCol_cur;
FETCH NEXT FROM missingCol_cur INTO @missingCol;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @errCount = @errCount + 1;
    SET @msg = N'FAIL: column [AceCommander].[ScheduledTask].[' + @missingCol + N'] is missing';
    RAISERROR(@msg, 16, 1);
    FETCH NEXT FROM missingCol_cur INTO @missingCol;
END;
CLOSE missingCol_cur;
DEALLOCATE missingCol_cur;

DECLARE @expectedRunCols TABLE (col SYSNAME PRIMARY KEY);
INSERT INTO @expectedRunCols(col) VALUES
    (N'Id'), (N'ScheduledTaskId'), (N'StartedUtc'),
    (N'CompletedUtc'), (N'ExitCode'), (N'Status'), (N'OutputSummary');

DECLARE missingRunCol_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT e.col FROM @expectedRunCols AS e
    WHERE COL_LENGTH(N'[AceCommander].[ScheduledTaskRun]', e.col) IS NULL;
OPEN missingRunCol_cur;
FETCH NEXT FROM missingRunCol_cur INTO @missingCol;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @errCount = @errCount + 1;
    SET @msg = N'FAIL: column [AceCommander].[ScheduledTaskRun].[' + @missingCol + N'] is missing';
    RAISERROR(@msg, 16, 1);
    FETCH NEXT FROM missingRunCol_cur INTO @missingCol;
END;
CLOSE missingRunCol_cur;
DEALLOCATE missingRunCol_cur;

IF OBJECT_ID(N'[AceCommander].[PK_AceCommander_ScheduledTask]', N'PK') IS NULL
BEGIN SET @errCount = @errCount + 1; RAISERROR(N'FAIL: PK_AceCommander_ScheduledTask is missing', 16, 1); END;
IF OBJECT_ID(N'[AceCommander].[PK_AceCommander_ScheduledTaskRun]', N'PK') IS NULL
BEGIN SET @errCount = @errCount + 1; RAISERROR(N'FAIL: PK_AceCommander_ScheduledTaskRun is missing', 16, 1); END;

IF OBJECT_ID(N'[AceCommander].[FK_AceCommander_ScheduledTask_User]', N'F') IS NULL
BEGIN SET @errCount = @errCount + 1; RAISERROR(N'FAIL: FK_AceCommander_ScheduledTask_User is missing', 16, 1); END;
IF OBJECT_ID(N'[AceCommander].[FK_AceCommander_ScheduledTaskRun_ScheduledTask]', N'F') IS NULL
BEGIN SET @errCount = @errCount + 1; RAISERROR(N'FAIL: FK_AceCommander_ScheduledTaskRun_ScheduledTask is missing', 16, 1); END;

IF OBJECT_ID(N'[AceCommander].[CK_AceCommander_ScheduledTask_ExecutionMode]', N'C') IS NULL
BEGIN SET @errCount = @errCount + 1; RAISERROR(N'FAIL: CK_AceCommander_ScheduledTask_ExecutionMode is missing', 16, 1); END;
IF OBJECT_ID(N'[AceCommander].[CK_AceCommander_ScheduledTask_Schedule]', N'C') IS NULL
BEGIN SET @errCount = @errCount + 1; RAISERROR(N'FAIL: CK_AceCommander_ScheduledTask_Schedule is missing', 16, 1); END;
IF OBJECT_ID(N'[AceCommander].[CK_AceCommander_ScheduledTask_LastRunStatus]', N'C') IS NULL
BEGIN SET @errCount = @errCount + 1; RAISERROR(N'FAIL: CK_AceCommander_ScheduledTask_LastRunStatus is missing (V00.02.000030 not applied?)', 16, 1); END;
IF OBJECT_ID(N'[AceCommander].[CK_AceCommander_ScheduledTaskRun_Status]', N'C') IS NULL
BEGIN SET @errCount = @errCount + 1; RAISERROR(N'FAIL: CK_AceCommander_ScheduledTaskRun_Status is missing', 16, 1); END;

IF INDEXPROPERTY(OBJECT_ID(N'[AceCommander].[ScheduledTask]'), N'IX_AceCommander_ScheduledTask_UserId', N'IndexID') IS NULL
BEGIN SET @errCount = @errCount + 1; RAISERROR(N'FAIL: index IX_AceCommander_ScheduledTask_UserId is missing', 16, 1); END;
IF INDEXPROPERTY(OBJECT_ID(N'[AceCommander].[ScheduledTask]'), N'IX_AceCommander_ScheduledTask_Due', N'IndexID') IS NULL
BEGIN SET @errCount = @errCount + 1; RAISERROR(N'FAIL: index IX_AceCommander_ScheduledTask_Due is missing', 16, 1); END;
IF INDEXPROPERTY(OBJECT_ID(N'[AceCommander].[ScheduledTask]'), N'IX_AceCommander_ScheduledTask_LastRunUtc', N'IndexID') IS NULL
BEGIN SET @errCount = @errCount + 1; RAISERROR(N'FAIL: index IX_AceCommander_ScheduledTask_LastRunUtc is missing (V00.02.000030 not applied?)', 16, 1); END;
IF INDEXPROPERTY(OBJECT_ID(N'[AceCommander].[ScheduledTaskRun]'), N'IX_AceCommander_ScheduledTaskRun_ScheduledTaskId_StartedUtc', N'IndexID') IS NULL
BEGIN SET @errCount = @errCount + 1; RAISERROR(N'FAIL: index IX_AceCommander_ScheduledTaskRun_ScheduledTaskId_StartedUtc is missing', 16, 1); END;

IF COL_LENGTH(N'[AceCommander].[ScheduledTask]', N'ExecutionMode') <> 40
BEGIN SET @errCount = @errCount + 1; RAISERROR(N'FAIL: [AceCommander].[ScheduledTask].[ExecutionMode] is not NVARCHAR(20)', 16, 1); END;

IF @errCount > 0
BEGIN
    SET @msg = N'ScheduledTask schema verification: ' + CAST(@errCount AS NVARCHAR(10)) + N' failure(s)';
    RAISERROR(@msg, 16, 1);
END
ELSE
BEGIN
    PRINT N'ScheduledTask schema verification: OK';
END;
GO

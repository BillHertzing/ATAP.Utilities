USE ATAPUtilities;
GO

SET XACT_ABORT ON;
SET NOCOUNT ON;
GO

CREATE TABLE [AceCommander].[ScheduledTask]
(
    [Id] INT IDENTITY(1,1) NOT NULL,
    [UserId] UNIQUEIDENTIFIER NOT NULL,
    [Name] NVARCHAR(256) NOT NULL,
    [NextRunUtc] DATETIME2(7) NULL,
    [RepeatSchedule] NVARCHAR(256) NULL,
    [RunAs] NVARCHAR(128) NULL,
    [WithProfile] BIT NOT NULL
        CONSTRAINT [DF_AceCommander_ScheduledTask_WithProfile] DEFAULT (0),
    [ScriptToRunPath] NVARCHAR(1024) NOT NULL,
    [ExecutionMode] NVARCHAR(20) NOT NULL,
    [IsEnabled] BIT NOT NULL
        CONSTRAINT [DF_AceCommander_ScheduledTask_IsEnabled] DEFAULT (1),
    [CreatedUtc] DATETIME2(7) NOT NULL
        CONSTRAINT [DF_AceCommander_ScheduledTask_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
    [ModifiedUtc] DATETIME2(7) NOT NULL
        CONSTRAINT [DF_AceCommander_ScheduledTask_ModifiedUtc] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_AceCommander_ScheduledTask] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_AceCommander_ScheduledTask_User] FOREIGN KEY ([UserId])
        REFERENCES [AceCommander].[User] ([UserId]),
    CONSTRAINT [CK_AceCommander_ScheduledTask_ExecutionMode] CHECK
        ([ExecutionMode] IN (N'AddToSystem', N'RunFromAce')),
    CONSTRAINT [CK_AceCommander_ScheduledTask_Schedule] CHECK
        ([NextRunUtc] IS NOT NULL OR NULLIF(LTRIM(RTRIM([RepeatSchedule])), N'') IS NOT NULL)
);
GO

CREATE INDEX [IX_AceCommander_ScheduledTask_UserId]
    ON [AceCommander].[ScheduledTask] ([UserId]);
GO

CREATE INDEX [IX_AceCommander_ScheduledTask_Due]
    ON [AceCommander].[ScheduledTask] ([IsEnabled], [ExecutionMode], [NextRunUtc])
    INCLUDE ([Name], [RepeatSchedule], [ScriptToRunPath], [WithProfile]);
GO

CREATE TABLE [AceCommander].[ScheduledTaskRun]
(
    [Id] BIGINT IDENTITY(1,1) NOT NULL,
    [ScheduledTaskId] INT NOT NULL,
    [StartedUtc] DATETIME2(7) NOT NULL
        CONSTRAINT [DF_AceCommander_ScheduledTaskRun_StartedUtc] DEFAULT (SYSUTCDATETIME()),
    [CompletedUtc] DATETIME2(7) NULL,
    [ExitCode] INT NULL,
    [Status] NVARCHAR(20) NOT NULL,
    [OutputSummary] NVARCHAR(MAX) NULL,
    CONSTRAINT [PK_AceCommander_ScheduledTaskRun] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_AceCommander_ScheduledTaskRun_ScheduledTask] FOREIGN KEY ([ScheduledTaskId])
        REFERENCES [AceCommander].[ScheduledTask] ([Id])
        ON DELETE CASCADE,
    CONSTRAINT [CK_AceCommander_ScheduledTaskRun_Status] CHECK
        ([Status] IN (N'Running', N'Succeeded', N'Failed', N'Cancelled'))
);
GO

CREATE INDEX [IX_AceCommander_ScheduledTaskRun_ScheduledTaskId_StartedUtc]
    ON [AceCommander].[ScheduledTaskRun] ([ScheduledTaskId], [StartedUtc] DESC)
    INCLUDE ([Status], [CompletedUtc], [ExitCode]);
GO

/*
  V00200__Create_Organization_Bootstrap.sql: forward organization migration.
  Body copied from Database/Schema/ACE/BootstrapOrganization.sql without semantic changes.
  No DROP, enrollment execution, grants or existing shared-identity adoption.
  Release/execution authority remains separately bound to the Experimental target.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF DB_NAME() <> N'ATAPUtilities' OR OBJECT_ID(N'ACE.OrganizationFactProvenance', N'U') IS NULL
       OR OBJECT_ID(N'ACE.UserIdentityBindingState', N'U') IS NULL OR COL_LENGTH(N'ACE.User', N'PersonId') IS NULL
        THROW 62700, N'The selected organization eligibility schema is required.', 1;
    IF OBJECT_ID(N'ACE.Household') IS NOT NULL OR OBJECT_ID(N'ACE.CombinedHouseholdLink') IS NOT NULL
       OR OBJECT_ID(N'ACE.Project') IS NOT NULL OR OBJECT_ID(N'ACE.ProjectState') IS NOT NULL
       OR OBJECT_ID(N'ACE.ProjectOwnership') IS NOT NULL OR OBJECT_ID(N'ACE.RoleAssignment') IS NOT NULL
       OR OBJECT_ID(N'ACE.OrganizationBootstrapReceipt') IS NOT NULL OR OBJECT_ID(N'ACE.BootstrapOrganization') IS NOT NULL
        THROW 62701, N'Bootstrap objects already exist; explicit forward disposition is required.', 1;
    CREATE TABLE [ACE].[Household] (
        [HouseholdId] uniqueidentifier NOT NULL PRIMARY KEY REFERENCES [ACE].[Organization] ([OrganizationId]),
        [EntityTypeCode] AS (CAST('Household' AS varchar(32)) COLLATE Latin1_General_100_BIN2) PERSISTED,
        CONSTRAINT [AC_FK_Household_Entity] FOREIGN KEY ([HouseholdId], [EntityTypeCode])
            REFERENCES [ACE].[OrganizationEntity] ([EntityId], [EntityTypeCode])
    );
    CREATE TABLE [ACE].[CombinedHouseholdLink] (
        [HouseholdLinkId] uniqueidentifier NOT NULL PRIMARY KEY
            REFERENCES [ACE].[OrganizationFactProvenance] ([PhiloteId]),
        [SourceHouseholdId] uniqueidentifier NOT NULL REFERENCES [ACE].[Household] ([HouseholdId]),
        [TargetHouseholdId] uniqueidentifier NOT NULL REFERENCES [ACE].[Household] ([HouseholdId]),
        CONSTRAINT [AC_CK_CombinedHouseholdLink_NoSelf] CHECK ([SourceHouseholdId] <> [TargetHouseholdId])
    );
    CREATE TABLE [ACE].[Project] (
        [ProjectId] uniqueidentifier NOT NULL PRIMARY KEY,
        [EntityTypeCode] AS (CAST('Project' AS varchar(32)) COLLATE Latin1_General_100_BIN2) PERSISTED,
        [ProjectCode] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL UNIQUE,
        [DisplayName] nvarchar(256) NOT NULL,
        CONSTRAINT [AC_FK_Project_Entity] FOREIGN KEY ([ProjectId], [EntityTypeCode])
            REFERENCES [ACE].[OrganizationEntity] ([EntityId], [EntityTypeCode]),
        CONSTRAINT [AC_CK_Project_Names] CHECK (LEN([ProjectCode]) > 0 AND LEN([DisplayName]) > 0)
    );
    CREATE TABLE [ACE].[ProjectState] (
        [ProjectStateId] uniqueidentifier NOT NULL PRIMARY KEY
            REFERENCES [ACE].[OrganizationFactProvenance] ([PhiloteId]),
        [ProjectId] uniqueidentifier NOT NULL REFERENCES [ACE].[Project] ([ProjectId]),
        [PhiloteValidityPeriodId] uniqueidentifier NOT NULL,
        [ValidFromUtc] datetime2(7) NOT NULL, [ValidToUtc] datetime2(7) NULL,
        [StatusCode] varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
        CONSTRAINT [AC_FK_ProjectState_Period] FOREIGN KEY ([ProjectId], [PhiloteValidityPeriodId])
            REFERENCES [ATAPUtilities].[PhiloteValidityPeriod] ([PhiloteId], [PhiloteValidityPeriodId]),
        CONSTRAINT [AC_CK_ProjectState_Period] CHECK ([ValidToUtc] IS NULL OR [ValidFromUtc] < [ValidToUtc]),
        CONSTRAINT [AC_CK_ProjectState_Status] CHECK ([StatusCode] IN ('Planned','Active','Retired'))
    );
    CREATE INDEX [AC_IX_ProjectState_Effective] ON [ACE].[ProjectState] ([ProjectId], [ValidFromUtc]);
    CREATE TABLE [ACE].[ProjectOwnership] (
        [ProjectOwnershipId] uniqueidentifier NOT NULL PRIMARY KEY
            REFERENCES [ACE].[OrganizationFactProvenance] ([PhiloteId]),
        [ProjectId] uniqueidentifier NOT NULL REFERENCES [ACE].[Project] ([ProjectId]),
        [OwnerPersonId] uniqueidentifier NOT NULL REFERENCES [ACE].[Person] ([PersonId])
    );
    CREATE INDEX [AC_IX_ProjectOwnership_Project] ON [ACE].[ProjectOwnership] ([ProjectId]);
    CREATE TABLE [ACE].[RoleAssignment] (
        [RoleAssignmentId] uniqueidentifier NOT NULL PRIMARY KEY
            REFERENCES [ACE].[OrganizationFactProvenance] ([PhiloteId]),
        [PersonId] uniqueidentifier NOT NULL REFERENCES [ACE].[Person] ([PersonId]),
        [RoleCode] varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [HouseholdId] uniqueidentifier NULL REFERENCES [ACE].[Household] ([HouseholdId]),
        [ProjectId] uniqueidentifier NULL REFERENCES [ACE].[Project] ([ProjectId]),
        CONSTRAINT [AC_CK_RoleAssignment_Scope] CHECK (
            ([RoleCode] = 'Head' AND [HouseholdId] IS NOT NULL AND [ProjectId] IS NULL)
            OR ([RoleCode] IN ('Developer','Administrator') AND [ProjectId] IS NOT NULL AND [HouseholdId] IS NULL))
    );
    CREATE INDEX [AC_IX_RoleAssignment_PersonProject] ON [ACE].[RoleAssignment] ([PersonId], [ProjectId], [RoleCode]);
    CREATE TABLE [ACE].[OrganizationBootstrapReceipt] (
        [RequestId] uniqueidentifier NOT NULL PRIMARY KEY,
        [PayloadHash] binary(32) NOT NULL,
        [UserId] uniqueidentifier NOT NULL REFERENCES [ACE].[User] ([UserId]),
        [AccountPhiloteId] uniqueidentifier NOT NULL REFERENCES [ATAPUtilities].[Philote] ([PhiloteId]),
        [PersonId] uniqueidentifier NOT NULL REFERENCES [ACE].[Person] ([PersonId]),
        [HostId] uniqueidentifier NOT NULL REFERENCES [ACE].[Host] ([HostId]),
        [BindingId] uniqueidentifier NOT NULL REFERENCES [ACE].[UserIdentityBinding] ([BindingId]),
        [EffectiveAtUtc] datetime2(7) NOT NULL,
        [UserRowVersion] binary(8) NOT NULL,
        [SettingsRowVersion] binary(8) NOT NULL
    );
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
CREATE PROCEDURE [ACE].[BootstrapOrganization]
    @Payload nvarchar(max),
    @ObservedHostId uniqueidentifier,
    @ObservedSid nvarchar(184),
    @ObservationReference nvarchar(512),
    @ActorPhiloteId uniqueidentifier,
    @VerifiedAtUtc datetime2(7),
    @ResolvedWindowsTimeZone nvarchar(128)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF DB_NAME() <> N'ATAPUtilities' OR @@TRANCOUNT <> 1 OR XACT_STATE() <> 1
        THROW 62702, N'Bootstrap requires its own caller transaction in the qualified catalog.', 1;
    IF ISNULL(HAS_PERMS_BY_NAME(DB_NAME(), N'DATABASE', N'CONTROL'), 0) <> 1
        THROW 62703, N'Bootstrap requires the separately authorized provisioning principal.', 1;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    DECLARE @RecordedAtUtc datetime2(7) = SYSUTCDATETIME();
    IF ISJSON(@Payload) <> 1 OR @Payload IS NULL OR DATALENGTH(@Payload) > 65536
       OR @ObservedHostId IS NULL OR @ObservedSid IS NULL OR LEN(@ObservedSid) = 0
       OR @ObservationReference IS NULL OR LEN(@ObservationReference) = 0
       OR @ActorPhiloteId IS NULL OR @ActorPhiloteId IN
          ('00000000-0000-0000-0000-000000000000','3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b','5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e')
       OR @VerifiedAtUtc IS NULL OR @VerifiedAtUtc > @RecordedAtUtc
       OR NOT EXISTS (SELECT 1 FROM sys.time_zone_info WHERE [name] = @ResolvedWindowsTimeZone)
        THROW 62704, N'Complete trusted observation, UTC instant and resolved time zone are required.', 1;
    IF ISNULL(JSON_VALUE(@Payload, '$.version'), N'') <> N'1'
        THROW 62705, N'Unsupported bootstrap command version.', 1;

    DECLARE @RequestId uniqueidentifier = TRY_CONVERT(uniqueidentifier, JSON_VALUE(@Payload, '$.requestId')),
            @UserId uniqueidentifier = TRY_CONVERT(uniqueidentifier, JSON_VALUE(@Payload, '$.userId')),
            @AccountId uniqueidentifier = TRY_CONVERT(uniqueidentifier, JSON_VALUE(@Payload, '$.accountPhiloteId')),
            @PersonId uniqueidentifier = TRY_CONVERT(uniqueidentifier, JSON_VALUE(@Payload, '$.accountPersonId')),
            @HostId uniqueidentifier = TRY_CONVERT(uniqueidentifier, JSON_VALUE(@Payload, '$.hostId')),
            @BindingId uniqueidentifier = TRY_CONVERT(uniqueidentifier, JSON_VALUE(@Payload, '$.bindingId')),
            @UserStateId uniqueidentifier = TRY_CONVERT(uniqueidentifier, JSON_VALUE(@Payload, '$.userStateId')),
            @BindingStateId uniqueidentifier = TRY_CONVERT(uniqueidentifier, JSON_VALUE(@Payload, '$.bindingStateId')),
            @TimeZone nvarchar(4000) = JSON_VALUE(@Payload, '$.timeZoneId'),
            @HostName nvarchar(4000) = JSON_VALUE(@Payload, '$.hostDisplayName'),
            @UserVersionHex nvarchar(4000) = JSON_VALUE(@Payload, '$.expectedUserRowVersion'),
            @SettingsVersionHex nvarchar(4000) = JSON_VALUE(@Payload, '$.expectedSettingsRowVersion');
    DECLARE @UserVersion binary(8) = TRY_CONVERT(binary(8), @UserVersionHex, 2),
            @SettingsVersion binary(8) = TRY_CONVERT(binary(8), @SettingsVersionHex, 2);
    IF @RequestId IS NULL OR @RequestId = '00000000-0000-0000-0000-000000000000'
       OR @UserId IS NULL OR @AccountId IS NULL OR @UserId = @AccountId
       OR @UserId IN ('00000000-0000-0000-0000-000000000000','5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e')
       OR @AccountId IN ('00000000-0000-0000-0000-000000000000','3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b')
       OR @HostId IS NULL OR @HostId <> @ObservedHostId OR @PersonId IS NULL
       OR @HostName IS NULL OR LEN(@HostName) = 0 OR DATALENGTH(@HostName) > 512
       OR @TimeZone IS NULL OR LEN(@TimeZone) = 0 OR DATALENGTH(@TimeZone) > 200
       OR DATALENGTH(@UserVersionHex) <> 32 OR DATALENGTH(@SettingsVersionHex) <> 32
       OR @UserVersion IS NULL OR @SettingsVersion IS NULL
        THROW 62705, N'Explicit identities, expected versions and complete bootstrap command are required.', 1;

    -- Fresh observation reference/time are evidence for this attempt, not part of retry identity.
    DECLARE @TrustedIdentity nvarchar(max) = (SELECT @ObservedHostId AS HostId, @ObservedSid AS Sid,
        @ActorPhiloteId AS ActorId, @ResolvedWindowsTimeZone AS ResolvedTimeZone FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    DECLARE @Digest binary(32) = HASHBYTES('SHA2_256', CONVERT(varbinary(max), @Payload) + CONVERT(varbinary(max), @TrustedIdentity));
    IF EXISTS (SELECT 1 FROM [ACE].[OrganizationBootstrapReceipt] WITH (UPDLOCK, HOLDLOCK) WHERE [RequestId] = @RequestId)
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM [ACE].[OrganizationBootstrapReceipt] WHERE [RequestId] = @RequestId AND [PayloadHash] = @Digest)
            THROW 62706, N'The request key already belongs to a different bootstrap payload or principal.', 1;
        SELECT [RequestId], CAST(1 AS bit) AS [Replayed], [EffectiveAtUtc], [UserRowVersion], [SettingsRowVersion]
        FROM [ACE].[OrganizationBootstrapReceipt] WHERE [RequestId] = @RequestId;
        RETURN;
    END;

    DECLARE @People TABLE (Id uniqueidentifier, DisplayName nvarchar(max), ClaimStatusCode nvarchar(max));
    DECLARE @Homes TABLE (Id uniqueidentifier, DisplayName nvarchar(max));
    DECLARE @Members TABLE (Id uniqueidentifier, PersonId uniqueidentifier, HouseholdId uniqueidentifier, IsPrimary bit);
    DECLARE @Heads TABLE (Id uniqueidentifier, PersonId uniqueidentifier, HouseholdId uniqueidentifier);
    DECLARE @Links TABLE (Id uniqueidentifier, SourceHouseholdId uniqueidentifier, TargetHouseholdId uniqueidentifier);
    DECLARE @Affiliations TABLE (Id uniqueidentifier, HouseholdId uniqueidentifier, Kind nvarchar(max));
    INSERT @People SELECT * FROM OPENJSON(@Payload, '$.people') WITH
        (Id uniqueidentifier '$.id', DisplayName nvarchar(max) '$.displayName', ClaimStatusCode nvarchar(max) '$.claimStatusCode');
    INSERT @Homes SELECT * FROM OPENJSON(@Payload, '$.households') WITH (Id uniqueidentifier '$.id', DisplayName nvarchar(max) '$.displayName');
    INSERT @Members SELECT * FROM OPENJSON(@Payload, '$.memberships') WITH
        (Id uniqueidentifier '$.id', PersonId uniqueidentifier '$.personId', HouseholdId uniqueidentifier '$.householdId', IsPrimary bit '$.isPrimary');
    INSERT @Heads SELECT * FROM OPENJSON(@Payload, '$.heads') WITH
        (Id uniqueidentifier '$.id', PersonId uniqueidentifier '$.personId', HouseholdId uniqueidentifier '$.householdId');
    INSERT @Links SELECT * FROM OPENJSON(@Payload, '$.combinedLinks') WITH
        (Id uniqueidentifier '$.id', SourceHouseholdId uniqueidentifier '$.sourceHouseholdId', TargetHouseholdId uniqueidentifier '$.targetHouseholdId');
    INSERT @Affiliations SELECT * FROM OPENJSON(@Payload, '$.affiliations') WITH
        (Id uniqueidentifier '$.id', HouseholdId uniqueidentifier '$.householdId', Kind nvarchar(max) '$.kind');
    DECLARE @ProjectId uniqueidentifier = TRY_CONVERT(uniqueidentifier, JSON_VALUE(@Payload, '$.project.id')),
            @ProjectCode nvarchar(4000) = JSON_VALUE(@Payload, '$.project.code'),
            @ProjectName nvarchar(4000) = JSON_VALUE(@Payload, '$.project.displayName'),
            @OwnerId uniqueidentifier = TRY_CONVERT(uniqueidentifier, JSON_VALUE(@Payload, '$.project.ownerPersonId')),
            @OwnershipId uniqueidentifier = TRY_CONVERT(uniqueidentifier, JSON_VALUE(@Payload, '$.project.ownershipId')),
            @ProjectStateId uniqueidentifier = TRY_CONVERT(uniqueidentifier, JSON_VALUE(@Payload, '$.project.stateId')),
            @DeveloperId uniqueidentifier = TRY_CONVERT(uniqueidentifier, JSON_VALUE(@Payload, '$.project.developerRoleId')),
            @AdministratorId uniqueidentifier = TRY_CONVERT(uniqueidentifier, JSON_VALUE(@Payload, '$.project.administratorRoleId'));

    IF (SELECT COUNT(*) FROM @People) <> 2 OR (SELECT COUNT(*) FROM @Homes) <> 3
       OR (SELECT COUNT(*) FROM @Members) <> 4 OR (SELECT COUNT(*) FROM @Heads) <> 4
       OR (SELECT COUNT(*) FROM @Links) <> 2 OR (SELECT COUNT(*) FROM @Affiliations) <> 2
       OR NOT EXISTS (SELECT 1 FROM @People WHERE Id = @PersonId) OR @OwnerId IS NULL OR @OwnerId <> @PersonId
       OR @ProjectCode IS NULL OR @ProjectCode COLLATE Latin1_General_100_BIN2 <> N'Ace'
       OR @ProjectName IS NULL OR LEN(@ProjectName) = 0 OR DATALENGTH(@ProjectName) > 512
       OR EXISTS (SELECT 1 FROM @People WHERE DisplayName IS NULL OR LEN(DisplayName) = 0 OR DATALENGTH(DisplayName) > 512
           OR ClaimStatusCode IS NULL OR ClaimStatusCode COLLATE Latin1_General_100_BIN2 <> CASE WHEN Id = @PersonId THEN N'Self' ELSE N'Placeholder' END)
       OR EXISTS (SELECT 1 FROM @Homes WHERE DisplayName IS NULL OR LEN(DisplayName) = 0 OR DATALENGTH(DisplayName) > 512)
        THROW 62707, N'The selected S1 people, households and person-owned Ace project must be explicit.', 1;

    DECLARE @Facts TABLE (Id uniqueidentifier, EntityType varchar(32) NULL);
    INSERT @Facts SELECT Id, 'Person' FROM @People UNION ALL SELECT Id, 'Household' FROM @Homes
        UNION ALL SELECT Id, NULL FROM @Members UNION ALL SELECT Id, NULL FROM @Heads
        UNION ALL SELECT Id, NULL FROM @Links UNION ALL SELECT Id, NULL FROM @Affiliations
        UNION ALL SELECT @HostId, 'Host' UNION ALL SELECT @ProjectId, 'Project'
        UNION ALL SELECT @BindingId, NULL UNION ALL SELECT @UserStateId, NULL UNION ALL SELECT @BindingStateId, NULL
        UNION ALL SELECT @OwnershipId, NULL UNION ALL SELECT @ProjectStateId, NULL
        UNION ALL SELECT @DeveloperId, NULL UNION ALL SELECT @AdministratorId, NULL;
    IF EXISTS (SELECT 1 FROM @Facts WHERE Id IS NULL OR Id IN (@UserId, @AccountId,
           '00000000-0000-0000-0000-000000000000','3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b','5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e'))
       OR EXISTS (SELECT Id FROM @Facts GROUP BY Id HAVING COUNT(*) <> 1)
        THROW 62708, N'All new identities must be nonempty, distinct and separate from account and Guest identities.', 1;

    IF EXISTS (SELECT 1 FROM @Members m WHERE PersonId IS NULL OR HouseholdId IS NULL OR IsPrimary IS NULL
           OR NOT EXISTS (SELECT 1 FROM @People p WHERE p.Id = m.PersonId)
           OR NOT EXISTS (SELECT 1 FROM @Homes h WHERE h.Id = m.HouseholdId))
       OR EXISTS (SELECT PersonId, HouseholdId FROM @Members GROUP BY PersonId, HouseholdId HAVING COUNT(*) <> 1)
       OR EXISTS (SELECT 1 FROM @People p WHERE (SELECT COUNT(*) FROM @Members m WHERE m.PersonId = p.Id AND m.IsPrimary = 1) <> 1
           OR (SELECT COUNT(*) FROM @Members m WHERE m.PersonId = p.Id) <> 2)
       OR EXISTS (SELECT 1 FROM @Homes h WHERE NOT EXISTS (SELECT 1 FROM @Members m WHERE m.HouseholdId = h.Id)
           OR NOT EXISTS (SELECT 1 FROM @Heads r WHERE r.HouseholdId = h.Id))
       OR EXISTS (SELECT 1 FROM @Heads r WHERE NOT EXISTS (SELECT 1 FROM @Members m WHERE m.PersonId = r.PersonId AND m.HouseholdId = r.HouseholdId))
       OR EXISTS (SELECT PersonId, HouseholdId FROM @Heads GROUP BY PersonId, HouseholdId HAVING COUNT(*) <> 1)
        THROW 62709, N'Every person needs one own and one primary combined membership; every household needs its member and head.', 1;

    DECLARE @CombinedId uniqueidentifier;
    SELECT TOP (1) @CombinedId = TargetHouseholdId FROM @Links;
    IF @CombinedId IS NULL OR (SELECT COUNT(DISTINCT TargetHouseholdId) FROM @Links) <> 1
       OR (SELECT COUNT(DISTINCT SourceHouseholdId) FROM @Links) <> 2
       OR EXISTS (SELECT 1 FROM @Links l WHERE SourceHouseholdId IS NULL OR TargetHouseholdId IS NULL
           OR SourceHouseholdId = TargetHouseholdId OR NOT EXISTS (SELECT 1 FROM @Homes h WHERE h.Id = l.SourceHouseholdId)
           OR NOT EXISTS (SELECT 1 FROM @Homes h WHERE h.Id = l.TargetHouseholdId))
       OR EXISTS (SELECT 1 FROM @Members WHERE IsPrimary <> CASE WHEN HouseholdId = @CombinedId THEN 1 ELSE 0 END)
       OR EXISTS (SELECT 1 FROM @Homes h WHERE h.Id <> @CombinedId AND (SELECT COUNT(*) FROM @Members m WHERE m.HouseholdId = h.Id) <> 1)
       OR EXISTS (SELECT 1 FROM @Affiliations a WHERE HouseholdId IS NULL OR Kind IS NULL
           OR Kind COLLATE Latin1_General_100_BIN2 NOT IN (N'Owner',N'SharedWith') OR NOT EXISTS (SELECT 1 FROM @Homes h WHERE h.Id = a.HouseholdId))
       OR (SELECT COUNT(*) FROM @Affiliations WHERE Kind COLLATE Latin1_General_100_BIN2 = N'Owner') <> 1
       OR (SELECT COUNT(*) FROM @Affiliations WHERE Kind COLLATE Latin1_General_100_BIN2 = N'SharedWith' AND HouseholdId = @CombinedId) <> 1
       OR NOT EXISTS (SELECT 1 FROM @Affiliations a JOIN @Members m ON m.HouseholdId = a.HouseholdId
           WHERE a.Kind COLLATE Latin1_General_100_BIN2 = N'Owner' AND a.HouseholdId <> @CombinedId AND m.PersonId = @PersonId)
        THROW 62710, N'Combined links must be acyclic and owner/shared host support must match the selected memberships.', 1;

    -- Serialize the selected account, principal and all new identities. No existing graph is adopted.
    IF NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[Philote] WITH (UPDLOCK, HOLDLOCK) WHERE [PhiloteId] = @ActorPhiloteId)
        THROW 62711, N'The authorized provenance actor must already be registered.', 1;
    IF NOT EXISTS (SELECT 1 FROM [ACE].[User] WITH (UPDLOCK, HOLDLOCK)
        WHERE [UserId] = @UserId AND [PhiloteId] = @AccountId AND [RowVersion] = @UserVersion AND [PersonId] IS NULL
          AND [EmailHash] IS NOT NULL AND [SaltedAndHashedPassword] IS NOT NULL AND [HashAlgorithmName] = N'Argon2id')
       OR NOT EXISTS (SELECT 1 FROM [ACE].[UserSettings] WITH (UPDLOCK, HOLDLOCK) WHERE [UserId] = @UserId AND [RowVersion] = @SettingsVersion)
        THROW 62712, N'The explicitly selected credential account/settings changed or cannot be initially linked.', 1;
    IF EXISTS (SELECT 1 FROM @Facts f JOIN [ATAPUtilities].[Philote] p WITH (UPDLOCK, HOLDLOCK) ON p.[PhiloteId] = f.Id)
       OR EXISTS (SELECT 1 FROM @Facts f JOIN [ACE].[User] u WITH (UPDLOCK, HOLDLOCK) ON f.Id = u.[PhiloteId] OR f.Id = u.[UserId])
       OR EXISTS (SELECT 1 FROM [ACE].[UserIdentityBinding] WITH (UPDLOCK, HOLDLOCK)
                  WHERE [HostId] = @HostId AND [SecurityIdentifier] = @ObservedSid COLLATE Latin1_General_100_BIN2)
       OR EXISTS (SELECT 1 FROM [ACE].[Project] WITH (UPDLOCK, HOLDLOCK) WHERE [ProjectCode] = @ProjectCode COLLATE Latin1_General_100_BIN2)
       OR EXISTS (SELECT 1 FROM [ACE].[UserState] WITH (UPDLOCK, HOLDLOCK) WHERE [UserId] = @UserId)
        THROW 62713, N'An identity, principal, project or state already exists; bootstrap never adopts or overwrites it.', 1;

    DECLARE @AccountPeriodId uniqueidentifier;
    IF EXISTS (SELECT 1 FROM [ATAPUtilities].[PhiloteValidityPeriod] WITH (UPDLOCK, HOLDLOCK) WHERE [PhiloteId] = @AccountId)
    BEGIN
        IF (SELECT COUNT(*) FROM [ATAPUtilities].[PhiloteValidityPeriod]
            WHERE [PhiloteId] = @AccountId AND [ValidFromUtc] <= @VerifiedAtUtc AND ([ValidToUtc] IS NULL OR @VerifiedAtUtc < [ValidToUtc])) <> 1
           OR NOT EXISTS (SELECT 1 FROM [ATAPUtilities].[PhiloteValidityPeriod]
                          WHERE [PhiloteId] = @AccountId AND [ValidFromUtc] <= @VerifiedAtUtc AND [ValidToUtc] IS NULL)
            THROW 62714, N'Existing account validity must uniquely cover enrollment and remain unbounded; no silent extension.', 1;
        SELECT @AccountPeriodId = [PhiloteValidityPeriodId] FROM [ATAPUtilities].[PhiloteValidityPeriod]
        WHERE [PhiloteId] = @AccountId AND [ValidFromUtc] <= @VerifiedAtUtc AND [ValidToUtc] IS NULL;
        IF EXISTS (SELECT 1 FROM [ATAPUtilities].[PhiloteValidityPeriod]
            WHERE [PhiloteId] = @AccountId AND [PhiloteValidityPeriodId] <> @AccountPeriodId
              AND ([ValidToUtc] IS NULL OR @VerifiedAtUtc < [ValidToUtc]))
            THROW 62714, N'Another account period conflicts with the proposed unbounded enrollment.', 1;
    END;

    -- All permanent effects occur after validation, still inside the caller's atomic transaction.
    INSERT [ATAPUtilities].[Philote] ([PhiloteId]) SELECT Id FROM @Facts;
    INSERT [ACE].[OrganizationFactProvenance]
        ([PhiloteId],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc],[OriginKind])
    SELECT Id, @ActorPhiloteId, @ObservationReference, @VerifiedAtUtc, @RecordedAtUtc, 'Manual' FROM @Facts;
    DECLARE @Periods TABLE (Id uniqueidentifier PRIMARY KEY, PeriodId uniqueidentifier NOT NULL);
    INSERT @Periods SELECT Id, NEWID() FROM @Facts;
    INSERT [ATAPUtilities].[PhiloteValidityPeriod] ([PhiloteValidityPeriodId],[PhiloteId],[PreviousValidToUtc],[ValidFromUtc],[ValidToUtc])
    SELECT PeriodId, Id, NULL, @VerifiedAtUtc, NULL FROM @Periods;
    IF @AccountPeriodId IS NULL
    BEGIN
        SET @AccountPeriodId = NEWID();
        INSERT [ATAPUtilities].[PhiloteValidityPeriod] ([PhiloteValidityPeriodId],[PhiloteId],[PreviousValidToUtc],[ValidFromUtc],[ValidToUtc])
        VALUES (@AccountPeriodId,@AccountId,NULL,@VerifiedAtUtc,NULL);
    END;
    INSERT [ACE].[OrganizationEntity] ([EntityId],[EntityTypeCode]) SELECT Id, EntityType FROM @Facts WHERE EntityType IS NOT NULL;
    INSERT [ACE].[Person] ([PersonId],[DisplayName],[ClaimStatusCode]) SELECT Id, DisplayName, ClaimStatusCode FROM @People;
    INSERT [ACE].[Organization] ([OrganizationId],[EntityTypeCode],[DisplayName]) SELECT Id, 'Household', DisplayName FROM @Homes;
    INSERT [ACE].[Household] ([HouseholdId]) SELECT Id FROM @Homes;
    INSERT [ACE].[Host] ([HostId],[DisplayName]) VALUES (@HostId,@HostName);
    INSERT [ACE].[Membership] ([MembershipId],[PersonId],[OrganizationId],[IsPrimary],[MembershipKindCode])
    SELECT Id, PersonId, HouseholdId, IsPrimary, 'Unspecified' FROM @Members;
    INSERT [ACE].[RoleAssignment] ([RoleAssignmentId],[PersonId],[RoleCode],[HouseholdId],[ProjectId])
    SELECT Id, PersonId, 'Head', HouseholdId, NULL FROM @Heads;
    INSERT [ACE].[CombinedHouseholdLink] ([HouseholdLinkId],[SourceHouseholdId],[TargetHouseholdId])
    SELECT Id, SourceHouseholdId, TargetHouseholdId FROM @Links;
    INSERT [ACE].[HostAffiliation] ([HostAffiliationId],[HostId],[OrganizationId],[AffiliationKindCode])
    SELECT Id, @HostId, HouseholdId, Kind FROM @Affiliations;
    INSERT [ACE].[Project] ([ProjectId],[ProjectCode],[DisplayName]) VALUES (@ProjectId,@ProjectCode,@ProjectName);
    INSERT [ACE].[ProjectOwnership] ([ProjectOwnershipId],[ProjectId],[OwnerPersonId]) VALUES (@OwnershipId,@ProjectId,@PersonId);
    INSERT [ACE].[RoleAssignment] ([RoleAssignmentId],[PersonId],[RoleCode],[HouseholdId],[ProjectId])
    VALUES (@DeveloperId,@PersonId,'Developer',NULL,@ProjectId),(@AdministratorId,@PersonId,'Administrator',NULL,@ProjectId);
    INSERT [ACE].[ProjectState] ([ProjectStateId],[ProjectId],[PhiloteValidityPeriodId],[ValidFromUtc],[ValidToUtc],[StatusCode])
    SELECT @ProjectStateId,@ProjectId,PeriodId,@VerifiedAtUtc,NULL,'Active' FROM @Periods WHERE Id = @ProjectId;

    UPDATE [ACE].[User] SET [PersonId] = @PersonId
    WHERE [UserId] = @UserId AND [PhiloteId] = @AccountId AND [PersonId] IS NULL AND [RowVersion] = @UserVersion;
    IF @@ROWCOUNT <> 1 THROW 62715, N'Account concurrency conflict.', 1;
    UPDATE [ACE].[UserSettings] SET [TimeZoneId] = @TimeZone WHERE [UserId] = @UserId AND [RowVersion] = @SettingsVersion;
    IF @@ROWCOUNT <> 1 THROW 62715, N'Settings concurrency conflict.', 1;
    INSERT [ACE].[UserIdentityBinding] ([BindingId],[UserId],[IdentityKindCode],[HostId],[SecurityIdentifier],[RequestedAccountName])
    VALUES (@BindingId,@UserId,'LocalAccount',@HostId,@ObservedSid,NULL);
    INSERT [ACE].[UserState] ([UserStateId],[UserId],[AccountPhiloteId],[PhiloteValidityPeriodId],[ValidFromUtc],[ValidToUtc],[StatusCode])
    VALUES (@UserStateId,@UserId,@AccountId,@AccountPeriodId,@VerifiedAtUtc,NULL,'Active');
    INSERT [ACE].[UserIdentityBindingState]
        ([BindingStateId],[BindingId],[PhiloteValidityPeriodId],[ValidFromUtc],[ValidToUtc],[StatusCode],[ObservationReference],[VerifiedByActorId],[VerifiedAtUtc])
    SELECT @BindingStateId,@BindingId,PeriodId,@VerifiedAtUtc,NULL,'Verified',@ObservationReference,@ActorPhiloteId,@VerifiedAtUtc
    FROM @Periods WHERE Id = @BindingId;
    INSERT [ACE].[OrganizationBootstrapReceipt]
        ([RequestId],[PayloadHash],[UserId],[AccountPhiloteId],[PersonId],[HostId],[BindingId],[EffectiveAtUtc],[UserRowVersion],[SettingsRowVersion])
    SELECT @RequestId,@Digest,@UserId,@AccountId,@PersonId,@HostId,@BindingId,@VerifiedAtUtc,u.[RowVersion],s.[RowVersion]
    FROM [ACE].[User] u JOIN [ACE].[UserSettings] s ON s.[UserId] = u.[UserId] WHERE u.[UserId] = @UserId;
    SELECT [RequestId], CAST(0 AS bit) AS [Replayed], [EffectiveAtUtc], [UserRowVersion], [SettingsRowVersion]
    FROM [ACE].[OrganizationBootstrapReceipt] WHERE [RequestId] = @RequestId;
END;

/*
  V00180__Create_Organization_Eligibility_Schema.sql: forward organization migration.
  Body copied from Database/Schema/ACE/OrganizationEligibility.sql with an exact caller-bound DDL catalog guard.
  No DROP, enrollment execution, grants or existing shared-identity adoption.
  Release/execution authority remains separately bound to the Experimental target.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;
    IF (DB_NAME() IS NULL OR DB_NAME() COLLATE Latin1_General_100_BIN2 <> N'${atap_required_catalog}' COLLATE Latin1_General_100_BIN2 OR DATALENGTH(DB_NAME()) <> DATALENGTH(N'${atap_required_catalog}')) OR SCHEMA_ID(N'ACE') IS NULL
       OR OBJECT_ID(N'ACE.User', N'U') IS NULL
       OR OBJECT_ID(N'ATAPUtilities.Philote', N'U') IS NULL
       OR OBJECT_ID(N'ATAPUtilities.PhiloteValidityPeriod', N'U') IS NULL
        THROW 62600, N'ACE login and shared identity/validity prerequisites are required.', 1;

    -- Refuse partial adoption. The selected trusted Person/link producer must create new
    -- identities and enforce disjointness across ALL retained User rows, including Guest.
    IF OBJECT_ID(N'ACE.Person') IS NOT NULL OR COL_LENGTH(N'ACE.User', N'PersonId') IS NOT NULL
       OR OBJECT_ID(N'ACE.OrganizationEntity') IS NOT NULL OR OBJECT_ID(N'ACE.Organization') IS NOT NULL
       OR OBJECT_ID(N'ACE.Host') IS NOT NULL OR OBJECT_ID(N'ACE.Membership') IS NOT NULL
       OR OBJECT_ID(N'ACE.HostAffiliation') IS NOT NULL OR OBJECT_ID(N'ACE.UserState') IS NOT NULL
       OR OBJECT_ID(N'ACE.UserIdentityBinding') IS NOT NULL
       OR OBJECT_ID(N'ACE.UserIdentityBindingState') IS NOT NULL
       OR OBJECT_ID(N'ACE.OrganizationFactProvenance') IS NOT NULL
        THROW 62601, N'Organization eligibility targets already exist; explicit forward disposition required.', 1;

    -- One provenance record per domain fact; distinct from verification observation evidence.
    CREATE TABLE [ACE].[OrganizationFactProvenance] (
        [PhiloteId] uniqueidentifier NOT NULL PRIMARY KEY
            REFERENCES [ATAPUtilities].[Philote] ([PhiloteId]),
        [PrincipalId] uniqueidentifier NOT NULL,
        [SourceReference] nvarchar(512) NOT NULL,
        [OccurredAtUtc] datetime2(7) NOT NULL,
        [RecordedAtUtc] datetime2(7) NOT NULL,
        [OriginKind] varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [TemplateId] uniqueidentifier NULL,
        [TemplateRevision] nvarchar(64) NULL,
        [TemplateSchemaVersion] nvarchar(64) NULL,
        [TemplateVocabularyVersion] nvarchar(64) NULL,
        [TemplateContentHash] binary(32) NULL,
        CONSTRAINT [AC_CK_OrgFact_Provenance] CHECK (
            [PrincipalId] <> '00000000-0000-0000-0000-000000000000'
            AND LEN([SourceReference]) > 0 AND [OccurredAtUtc] <= [RecordedAtUtc]),
        CONSTRAINT [AC_CK_OrgFact_Lineage] CHECK (
            ([OriginKind] = 'Manual' AND [TemplateId] IS NULL AND [TemplateRevision] IS NULL
             AND [TemplateSchemaVersion] IS NULL AND [TemplateVocabularyVersion] IS NULL
             AND [TemplateContentHash] IS NULL)
            OR ([OriginKind] = 'Template' AND [TemplateId] IS NOT NULL
             AND [TemplateId] <> '00000000-0000-0000-0000-000000000000'
             AND [TemplateRevision] IS NOT NULL AND LEN([TemplateRevision]) > 0
             AND [TemplateSchemaVersion] IS NOT NULL AND LEN([TemplateSchemaVersion]) > 0
             AND [TemplateVocabularyVersion] IS NOT NULL AND LEN([TemplateVocabularyVersion]) > 0
             AND [TemplateContentHash] IS NOT NULL))
    );
    CREATE TABLE [ACE].[OrganizationEntity] (
        [EntityId] uniqueidentifier NOT NULL PRIMARY KEY
            REFERENCES [ACE].[OrganizationFactProvenance] ([PhiloteId]),
        [EntityTypeCode] varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
        CONSTRAINT [AC_UQ_OrgEntity_Type] UNIQUE ([EntityId], [EntityTypeCode]),
        CONSTRAINT [AC_CK_OrgEntity_Type] CHECK ([EntityTypeCode] IN ('Person','Household','Organization','Host','Project')),
        CONSTRAINT [AC_CK_OrgEntity_Nonempty] CHECK ([EntityId] <> '00000000-0000-0000-0000-000000000000')
    );
    CREATE TABLE [ACE].[Person] (
        [PersonId] uniqueidentifier NOT NULL PRIMARY KEY,
        [EntityTypeCode] AS (CAST('Person' AS varchar(32)) COLLATE Latin1_General_100_BIN2) PERSISTED,
        [DisplayName] nvarchar(256) NOT NULL,
        [ClaimStatusCode] varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
        CONSTRAINT [AC_FK_Person_Entity] FOREIGN KEY ([PersonId], [EntityTypeCode])
            REFERENCES [ACE].[OrganizationEntity] ([EntityId], [EntityTypeCode]),
        CONSTRAINT [AC_CK_Person_DisplayName] CHECK (LEN([DisplayName]) > 0),
        CONSTRAINT [AC_CK_Person_Claim] CHECK ([ClaimStatusCode] IN ('Self','Placeholder','Invited','Claimed')),
        CONSTRAINT [AC_CK_Person_NotGuest] CHECK (
            [PersonId] <> '3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b'
            AND [PersonId] <> '5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e')
    );
    ALTER TABLE [ACE].[User] ADD [PersonId] uniqueidentifier NULL;
    EXEC sys.sp_executesql N'
        ALTER TABLE [ACE].[User] ADD
            CONSTRAINT [AC_FK_User_Person] FOREIGN KEY ([PersonId]) REFERENCES [ACE].[Person] ([PersonId]),
            CONSTRAINT [AC_CK_User_PersonDistinct] CHECK ([PersonId] IS NULL OR
                ([PersonId] <> [UserId] AND [PersonId] <> [PhiloteId])),
            CONSTRAINT [AC_CK_User_GuestPerson] CHECK
                ([UserId] <> ''5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e'' OR [PersonId] IS NULL);
        CREATE UNIQUE INDEX [AC_UX_User_PersonId] ON [ACE].[User] ([PersonId]) WHERE [PersonId] IS NOT NULL;
        ALTER TABLE [ACE].[User] ADD CONSTRAINT [AC_UQ_User_AccountIdentity] UNIQUE ([UserId], [PhiloteId]);';

    CREATE TABLE [ACE].[Organization] (
        [OrganizationId] uniqueidentifier NOT NULL PRIMARY KEY,
        [EntityTypeCode] varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [DisplayName] nvarchar(256) NOT NULL,
        CONSTRAINT [AC_FK_Organization_Entity] FOREIGN KEY ([OrganizationId], [EntityTypeCode])
            REFERENCES [ACE].[OrganizationEntity] ([EntityId], [EntityTypeCode]),
        CONSTRAINT [AC_CK_Organization_Type] CHECK ([EntityTypeCode] IN ('Household','Organization')),
        CONSTRAINT [AC_CK_Organization_Name] CHECK (LEN([DisplayName]) > 0)
    );
    CREATE TABLE [ACE].[Host] (
        [HostId] uniqueidentifier NOT NULL PRIMARY KEY,
        [EntityTypeCode] AS (CAST('Host' AS varchar(32)) COLLATE Latin1_General_100_BIN2) PERSISTED,
        [DisplayName] nvarchar(256) NOT NULL,
        CONSTRAINT [AC_FK_Host_Entity] FOREIGN KEY ([HostId], [EntityTypeCode])
            REFERENCES [ACE].[OrganizationEntity] ([EntityId], [EntityTypeCode]),
        CONSTRAINT [AC_CK_Host_Name] CHECK (LEN([DisplayName]) > 0)
    );
    CREATE TABLE [ACE].[Membership] (
        [MembershipId] uniqueidentifier NOT NULL PRIMARY KEY
            REFERENCES [ACE].[OrganizationFactProvenance] ([PhiloteId]),
        [PersonId] uniqueidentifier NOT NULL REFERENCES [ACE].[Person] ([PersonId]),
        [OrganizationId] uniqueidentifier NOT NULL REFERENCES [ACE].[Organization] ([OrganizationId]),
        [IsPrimary] bit NOT NULL,
        [MembershipKindCode] varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
        CONSTRAINT [AC_CK_Membership_Kind] CHECK ([MembershipKindCode] = 'Unspecified')
    );
    CREATE INDEX [AC_IX_Membership_Person] ON [ACE].[Membership] ([PersonId], [OrganizationId]);
    CREATE TABLE [ACE].[HostAffiliation] (
        [HostAffiliationId] uniqueidentifier NOT NULL PRIMARY KEY
            REFERENCES [ACE].[OrganizationFactProvenance] ([PhiloteId]),
        [HostId] uniqueidentifier NOT NULL REFERENCES [ACE].[Host] ([HostId]),
        [OrganizationId] uniqueidentifier NOT NULL REFERENCES [ACE].[Organization] ([OrganizationId]),
        [AffiliationKindCode] varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
        CONSTRAINT [AC_CK_HostAffiliation_Kind] CHECK ([AffiliationKindCode] IN ('Owner','SharedWith'))
    );
    CREATE INDEX [AC_IX_HostAffiliation_Host] ON [ACE].[HostAffiliation] ([HostId], [OrganizationId]);

    CREATE TABLE [ACE].[UserState] (
        [UserStateId] uniqueidentifier NOT NULL PRIMARY KEY
            REFERENCES [ACE].[OrganizationFactProvenance] ([PhiloteId]),
        [UserId] uniqueidentifier NOT NULL,
        [AccountPhiloteId] uniqueidentifier NOT NULL,
        [PhiloteValidityPeriodId] uniqueidentifier NOT NULL,
        [ValidFromUtc] datetime2(7) NOT NULL,
        [ValidToUtc] datetime2(7) NULL,
        [StatusCode] varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
        CONSTRAINT [AC_FK_UserState_Account] FOREIGN KEY ([UserId], [AccountPhiloteId])
            REFERENCES [ACE].[User] ([UserId], [PhiloteId]),
        CONSTRAINT [AC_FK_UserState_Period] FOREIGN KEY ([AccountPhiloteId], [PhiloteValidityPeriodId])
            REFERENCES [ATAPUtilities].[PhiloteValidityPeriod] ([PhiloteId], [PhiloteValidityPeriodId]),
        CONSTRAINT [AC_CK_UserState_Period] CHECK ([ValidToUtc] IS NULL OR [ValidFromUtc] < [ValidToUtc]),
        CONSTRAINT [AC_CK_UserState_Status] CHECK ([StatusCode] IN ('Pending','Active','Suspended','Closed'))
    );
    CREATE INDEX [AC_IX_UserState_Effective] ON [ACE].[UserState] ([UserId], [ValidFromUtc]) INCLUDE ([ValidToUtc]);
    CREATE TABLE [ACE].[UserIdentityBinding] (
        [BindingId] uniqueidentifier NOT NULL PRIMARY KEY
            REFERENCES [ACE].[OrganizationFactProvenance] ([PhiloteId]),
        [UserId] uniqueidentifier NOT NULL REFERENCES [ACE].[User] ([UserId]),
        [IdentityKindCode] varchar(24) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [HostId] uniqueidentifier NOT NULL REFERENCES [ACE].[Host] ([HostId]),
        [SecurityIdentifier] nvarchar(184) COLLATE Latin1_General_100_BIN2 NULL,
        [RequestedAccountName] nvarchar(256) NULL,
        CONSTRAINT [AC_CK_UserIdentityBinding_Kind] CHECK ([IdentityKindCode] = 'LocalAccount'),
        CONSTRAINT [AC_CK_UserIdentityBinding_Sid] CHECK ([SecurityIdentifier] IS NULL OR LEN([SecurityIdentifier]) > 0)
    );
    CREATE INDEX [AC_IX_UserIdentityBinding_UserHost] ON [ACE].[UserIdentityBinding] ([UserId], [HostId]);
    CREATE INDEX [AC_IX_UserIdentityBinding_Principal] ON [ACE].[UserIdentityBinding] ([HostId], [SecurityIdentifier]);
    CREATE TABLE [ACE].[UserIdentityBindingState] (
        [BindingStateId] uniqueidentifier NOT NULL PRIMARY KEY
            REFERENCES [ACE].[OrganizationFactProvenance] ([PhiloteId]),
        [BindingId] uniqueidentifier NOT NULL REFERENCES [ACE].[UserIdentityBinding] ([BindingId]),
        [PhiloteValidityPeriodId] uniqueidentifier NOT NULL,
        [ValidFromUtc] datetime2(7) NOT NULL,
        [ValidToUtc] datetime2(7) NULL,
        [StatusCode] varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [ObservationReference] nvarchar(512) NULL,
        [VerifiedByActorId] uniqueidentifier NULL,
        [VerifiedAtUtc] datetime2(7) NULL,
        CONSTRAINT [AC_FK_UserIdentityBindingState_Period] FOREIGN KEY ([BindingId], [PhiloteValidityPeriodId])
            REFERENCES [ATAPUtilities].[PhiloteValidityPeriod] ([PhiloteId], [PhiloteValidityPeriodId]),
        CONSTRAINT [AC_CK_UserIdentityBindingState_Period] CHECK ([ValidToUtc] IS NULL OR [ValidFromUtc] < [ValidToUtc]),
        CONSTRAINT [AC_CK_UserIdentityBindingState_Status] CHECK ([StatusCode] IN ('Pending','Verified','Revoked')),
        CONSTRAINT [AC_CK_UserIdentityBindingState_Verified] CHECK ([StatusCode] <> 'Verified' OR (
            [ObservationReference] IS NOT NULL AND LEN([ObservationReference]) > 0
            AND [VerifiedByActorId] IS NOT NULL AND [VerifiedByActorId] <> '00000000-0000-0000-0000-000000000000'
            AND [VerifiedAtUtc] IS NOT NULL AND [VerifiedAtUtc] <= [ValidFromUtc]))
    );
    CREATE INDEX [AC_IX_UserIdentityBindingState_Effective]
        ON [ACE].[UserIdentityBindingState] ([BindingId], [ValidFromUtc]) INCLUDE ([ValidToUtc]);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

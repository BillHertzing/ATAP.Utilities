/*
  V00220__Create_AceCommander_Role.sql: forward, additive security migration.
  Sprint 0017 Task 17.68.dev, Plan r4 (operator design decision 2026-11-15).

  Creates ONE database role, [AceCommander], holding the least privilege that
  AceCommanderService uses, and makes the host's Windows account
  <MachineName>\SvcAceCommander a member. The grant set is the reviewed contract
  Database/Verify/AceCommander/AceCommanderRole.Contract.json (source file:line per
  grant). Identical bytes on every tier: the member account is derived at run time
  from SERVERPROPERTY('MachineName'); no server login is created (instances admit the
  account through their existing Windows group login). The catalog guard is the V00160
  guard on the atap_required_catalog Flyway placeholder, which Invoke-Flyway binds to
  the expected catalog: ATAPUtilities on a tier, the clone name in a rehearsal.

  No DROP, no REVOKE, no data change. The pre-existing roles AceCommanderTimelineReader,
  AceCommanderGraphReader and AceCommanderTagsTraversalReader are left untouched; a
  later, separately approved migration retires them.
*/
SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @RequiredCatalog nvarchar(128) = N'${atap_required_catalog}';
    IF @RequiredCatalog IS NULL OR DATALENGTH(@RequiredCatalog) = 0
       OR DB_NAME() IS NULL
       OR DB_NAME() COLLATE Latin1_General_100_BIN2 <> @RequiredCatalog COLLATE Latin1_General_100_BIN2
       OR DATALENGTH(DB_NAME()) <> DATALENGTH(@RequiredCatalog)
        THROW 62200, N'V00220 requires the exact approved catalog binding.', 1;

    -- Preconditions: every securable in the contract exists (lineage through V00210).
    IF OBJECT_ID(N'[Ace].[User]', N'U') IS NULL OR OBJECT_ID(N'[Ace].[UserInformation]', N'U') IS NULL
       OR OBJECT_ID(N'[Ace].[UserSettings]', N'U') IS NULL OR OBJECT_ID(N'[Ace].[UserPreferences]', N'U') IS NULL
       OR OBJECT_ID(N'[Ace].[OrganizationBootstrapReceipt]', N'U') IS NULL OR OBJECT_ID(N'[Ace].[UserIdentityBinding]', N'U') IS NULL
       OR OBJECT_ID(N'[Ace].[UserState]', N'U') IS NULL
       OR OBJECT_ID(N'[Ace].[usp_GetDecryptedUserInformation]', N'P') IS NULL
       OR OBJECT_ID(N'[Ace].[ReadOrganizationEligibility]', N'P') IS NULL OR OBJECT_ID(N'[Ace].[ReadOrganizationProject]', N'P') IS NULL
       OR OBJECT_ID(N'[Ace].[QueryGatherContentSubmissionTimeline]', N'P') IS NULL
       OR OBJECT_ID(N'[Ace].[QueryAISupervisorExchangeTimeline]', N'P') IS NULL
       OR OBJECT_ID(N'[Ace].[QueryAISupervisorTokenTimeline]', N'P') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[Philote]', N'U') IS NULL OR OBJECT_ID(N'[ATAPUtilities].[Rule]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RuleSet]', N'U') IS NULL OR OBJECT_ID(N'[ATAPUtilities].[RulePrimitive]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RulePrimitiveInput]', N'U') IS NULL OR OBJECT_ID(N'[ATAPUtilities].[BuildSet]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[BuildSetRuleSet]', N'U') IS NULL OR OBJECT_ID(N'[ATAPUtilities].[Instantiation]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[PhiloteValidityPeriod]', N'U') IS NULL OR OBJECT_ID(N'[ATAPUtilities].[RuleKind]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[RuleSetRule]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[QueryTagLogicalEdgesAsOf]', N'P') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[ResolveTagAsOf]') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[Tag]', N'U') IS NULL OR OBJECT_ID(N'[ATAPUtilities].[TagAlias]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[TagNamespace]', N'U') IS NULL OR OBJECT_ID(N'[ATAPUtilities].[TagRelationType]', N'U') IS NULL
       OR OBJECT_ID(N'[ATAPUtilities].[TagState]', N'U') IS NULL
       OR TYPE_ID(N'[ATAPUtilities].[TagRelationRoleCodeInput]') IS NULL
        THROW 62201, N'V00220 requires the V00210 lineage objects named in the AceCommander role contract.', 1;

    -- Role: create once; refuse a non-role principal already holding the name.
    IF DATABASE_PRINCIPAL_ID(N'AceCommander') IS NULL
        EXEC sys.sp_executesql N'CREATE ROLE [AceCommander] AUTHORIZATION [dbo];';
    ELSE IF NOT EXISTS (SELECT 1 FROM sys.database_principals
                        WHERE [name] = N'AceCommander' AND [type] = 'R' AND [is_fixed_role] = 0)
        THROW 62202, N'Principal AceCommander exists but is not a user-defined database role.', 1;

    DECLARE @ExpectedPermissionRows int = 65;

    -- Ace login, profile, settings and preferences.
    GRANT SELECT, INSERT ON OBJECT::[Ace].[User] TO [AceCommander];
    GRANT SELECT, INSERT, UPDATE ON OBJECT::[Ace].[UserInformation] TO [AceCommander];
    GRANT SELECT, INSERT, UPDATE ON OBJECT::[Ace].[UserSettings] TO [AceCommander];
    GRANT SELECT, INSERT, UPDATE ON OBJECT::[Ace].[UserPreferences] TO [AceCommander];
    GRANT SELECT ON OBJECT::[Ace].[OrganizationBootstrapReceipt] TO [AceCommander];
    GRANT SELECT ON OBJECT::[Ace].[UserIdentityBinding] TO [AceCommander];
    GRANT SELECT ON OBJECT::[Ace].[UserState] TO [AceCommander];
    GRANT EXECUTE ON OBJECT::[Ace].[usp_GetDecryptedUserInformation] TO [AceCommander];
    GRANT EXECUTE ON OBJECT::[Ace].[ReadOrganizationEligibility] TO [AceCommander];
    GRANT EXECUTE ON OBJECT::[Ace].[ReadOrganizationProject] TO [AceCommander];

    -- Timelines (fold of AceCommanderTimelineReader, V00070).
    GRANT EXECUTE ON OBJECT::[Ace].[QueryGatherContentSubmissionTimeline] TO [AceCommander];
    GRANT EXECUTE ON OBJECT::[Ace].[QueryAISupervisorExchangeTimeline] TO [AceCommander];
    GRANT EXECUTE ON OBJECT::[Ace].[QueryAISupervisorTokenTimeline] TO [AceCommander];

    -- Shared identity registry and RRSBS reference reads.
    GRANT SELECT, INSERT ON OBJECT::[ATAPUtilities].[Philote] TO [AceCommander];
    GRANT SELECT ON OBJECT::[ATAPUtilities].[Rule] TO [AceCommander];
    GRANT SELECT ON OBJECT::[ATAPUtilities].[RuleSet] TO [AceCommander];
    GRANT SELECT ON OBJECT::[ATAPUtilities].[RulePrimitive] TO [AceCommander];
    GRANT SELECT ON OBJECT::[ATAPUtilities].[RulePrimitiveInput] TO [AceCommander];

    -- Graph reads (fold of AceCommanderGraphReader; exact column lists).
    GRANT SELECT ON OBJECT::[ATAPUtilities].[BuildSet] ([BuildSetCode], [BuildSetId], [PhiloteId]) TO [AceCommander];
    GRANT SELECT ON OBJECT::[ATAPUtilities].[BuildSetRuleSet] ([BuildSetId], [Ordinal], [RuleSetId]) TO [AceCommander];
    GRANT SELECT ON OBJECT::[ATAPUtilities].[Instantiation] ([BuildSetId], [InstantiationCode], [InstantiationId], [PhiloteId]) TO [AceCommander];
    GRANT SELECT ON OBJECT::[ATAPUtilities].[PhiloteValidityPeriod] ([PhiloteId], [PhiloteValidityPeriodId], [PreviousValidToUtc], [ValidFromUtc], [ValidToUtc]) TO [AceCommander];
    GRANT SELECT ON OBJECT::[ATAPUtilities].[RuleKind] ([PhiloteId], [RuleKindCode], [RuleKindId], [RuleKindName]) TO [AceCommander];
    GRANT SELECT ON OBJECT::[ATAPUtilities].[RuleSetRule] ([Ordinal], [RuleId], [RuleSetId]) TO [AceCommander];

    -- Tag traversal (fold of AceCommanderTagsTraversalReader; exact column lists).
    GRANT EXECUTE ON OBJECT::[ATAPUtilities].[QueryTagLogicalEdgesAsOf] TO [AceCommander];
    GRANT SELECT ON OBJECT::[ATAPUtilities].[ResolveTagAsOf] TO [AceCommander];
    GRANT SELECT ON OBJECT::[ATAPUtilities].[Tag] ([TagCode], [TagId], [TagNamespaceId]) TO [AceCommander];
    GRANT SELECT ON OBJECT::[ATAPUtilities].[TagAlias] ([AliasCode], [TagId], [ValidFromUtc], [ValidToUtc]) TO [AceCommander];
    GRANT SELECT ON OBJECT::[ATAPUtilities].[TagNamespace] ([NamespaceCode], [TagNamespaceId]) TO [AceCommander];
    GRANT SELECT ON OBJECT::[ATAPUtilities].[TagRelationType] ([IsTraversable], [RoleCode]) TO [AceCommander];
    GRANT SELECT ON OBJECT::[ATAPUtilities].[TagState] ([IsDeprecated], [TagStateId]) TO [AceCommander];
    GRANT EXECUTE, REFERENCES ON TYPE::[ATAPUtilities].[TagRelationRoleCodeInput] TO [AceCommander];

    -- BEGIN OPTIONAL GATE G6: VIEW DEFINITION (metadata only) for the selected-metadata viewer.
    -- Default include, pending explicit operator confirmation. To remove before release,
    -- delete every line from BEGIN OPTIONAL GATE G6 through END OPTIONAL GATE G6, and
    -- remove the two SCHEMA entries marked optionalGate G6 from AceCommanderRole.Contract.json.
    GRANT VIEW DEFINITION ON SCHEMA::[Ace] TO [AceCommander];
    GRANT VIEW DEFINITION ON SCHEMA::[ATAPUtilities] TO [AceCommander];
    SET @ExpectedPermissionRows += 2;
    -- END OPTIONAL GATE G6

    -- Member: this host's Windows account <MachineName>\SvcAceCommander, matched by SID.
    DECLARE @Account sysname = CONVERT(sysname, SERVERPROPERTY('MachineName')) + N'\SvcAceCommander';
    DECLARE @AccountSid varbinary(85) = SUSER_SID(@Account);
    DECLARE @MemberName sysname;
    DECLARE @Statement nvarchar(max);
    IF @AccountSid IS NULL
        THROW 62203, N'The Windows account <MachineName>\SvcAceCommander does not resolve on this host.', 1;
    SELECT @MemberName = [name] FROM sys.database_principals WHERE [sid] = @AccountSid;
    IF @MemberName IS NULL
    BEGIN
        SET @Statement = N'CREATE USER ' + QUOTENAME(@Account) + N';';
        EXEC sys.sp_executesql @Statement;
        SELECT @MemberName = [name] FROM sys.database_principals WHERE [sid] = @AccountSid;
    END
    ELSE IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE [sid] = @AccountSid AND [type] = 'U')
        THROW 62204, N'The SvcAceCommander SID is mapped to a database principal that is not a Windows user.', 1;
    IF NOT EXISTS (SELECT 1 FROM sys.database_role_members AS rm
                   WHERE rm.[role_principal_id] = DATABASE_PRINCIPAL_ID(N'AceCommander')
                     AND rm.[member_principal_id] = DATABASE_PRINCIPAL_ID(@MemberName))
    BEGIN
        SET @Statement = N'ALTER ROLE [AceCommander] ADD MEMBER ' + QUOTENAME(@MemberName) + N';';
        EXEC sys.sp_executesql @Statement;
    END

    -- Postconditions: exact grant row count, owner dbo, member present, no DENY rows.
    IF (SELECT COUNT(*) FROM sys.database_permissions
        WHERE [grantee_principal_id] = DATABASE_PRINCIPAL_ID(N'AceCommander') AND [state] = 'G') <> @ExpectedPermissionRows
       OR EXISTS (SELECT 1 FROM sys.database_permissions
                  WHERE [grantee_principal_id] = DATABASE_PRINCIPAL_ID(N'AceCommander') AND [state] <> 'G')
       OR (SELECT [owning_principal_id] FROM sys.database_principals WHERE [name] = N'AceCommander') <> DATABASE_PRINCIPAL_ID(N'dbo')
       OR NOT EXISTS (SELECT 1 FROM sys.database_role_members AS rm
                      WHERE rm.[role_principal_id] = DATABASE_PRINCIPAL_ID(N'AceCommander')
                        AND rm.[member_principal_id] = DATABASE_PRINCIPAL_ID(@MemberName))
        THROW 62209, N'V00220 postcondition failed: AceCommander role grants, owner or membership differ from the contract.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

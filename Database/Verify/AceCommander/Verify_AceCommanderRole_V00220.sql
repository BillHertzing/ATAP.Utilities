/* Clone-only, two-phase verifier for V00220 (AceCommander database role).
   Admitted baselines: the exact twenty-row V210 history (V00220 pending) or the exact
   twenty-one-row V220 history (re-verification; nothing pending).
   The same dedicated connection owns all temporary snapshots across the
   validate/migrate220/validate sequence. Read-only: no product writes.
   Rehearsal contract: Database/Verify/RehearsalBoundaries.json (boundary 00220).
   @ExpectedPermissionRows and the 00220 checksum are pinned to V00220 by
   tests/Unit/Verify_AceCommanderRole_V00220.Tests.ps1 (DatabaseManagement module tests). */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @ExpectedCatalog nvarchar(128)=TRY_CONVERT(nvarchar(128),SESSION_CONTEXT(N'ATAP.AceCommanderRole220.ExpectedCatalog'));
IF @ExpectedCatalog IS NULL OR DB_NAME() COLLATE Latin1_General_100_BIN2 <> @ExpectedCatalog COLLATE Latin1_General_100_BIN2
   OR @ExpectedCatalog NOT LIKE N'ATAPUtilities-rehearsal-%' OR DB_NAME() = N'ATAPUtilities'
   OR @@TRANCOUNT <> 0 OR @VerificationPhase IS NULL OR @VerificationPhase NOT IN (N'Before', N'After')
    THROW 62920, N'Explicit isolated AceCommander role clone and phase required.', 1;

-- 65 grant rows plus 2 for optional gate G6 (VIEW DEFINITION on two schemas).
DECLARE @ExpectedPermissionRows int = 67;
DECLARE @BaselineVersion smallint;
DECLARE @MemberAccount sysname = CONVERT(sysname, SERVERPROPERTY('MachineName')) + N'\SvcAceCommander';
DECLARE @MemberSid varbinary(85) = SUSER_SID(@MemberAccount);
DECLARE @Expected TABLE ([version] nvarchar(50), [script] nvarchar(1000), [checksum] int);
INSERT @Expected VALUES
      (N'00010',N'V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql',1708932941),
      (N'00030',N'V00030__Create_AceOutpostContentSummaryPrototype.sql',-2126084359),
      (N'00040',N'V00040__Add_PhiloteValidityPeriod_SameIdentity_Key.sql',1681687671),
      (N'00050',N'V00050__Create_ATAPUtilities_Tag_Root.sql',-467224854),
      (N'00060',N'V00060__Create_Ace_GatherContent_Submission.sql',-1137084994),
      (N'00070',N'V00070__Create_Ace_AISupervisor_Telemetry.sql',-1143966941),
      (N'00080',N'V00080__Create_ATAPUtilities_V4_Core_Identity_And_Overlay.sql',-1623112334),
      (N'00090',N'V00090__Create_ATAPUtilities_Tag_Relations_Assignments_And_Rules.sql',-1553929770),
      (N'00100',N'V00100__Create_ATAPUtilities_ContentSummary_And_Query.sql',-1424720516),
      (N'00110',N'V00110__Create_ContentSummary_DAB_Principal_Facade.sql',351768227),
      (N'00120',N'V00120__Add_ContentSummary_Provisioning_And_Correction.sql',-685970708),
      (N'00130',N'V00130__Create_ContentSummary_Runtime_Query_Boundary.sql',2009181215),
      (N'00140',N'V00140__Correct_ContentSummary_Runtime_Query_Denials.sql',-1589047792),
      (N'00150',N'V00150__Add_AISupervisor_CacheTokens.sql',155333537),
      (N'00160',N'V00160__Create_AceCommander_Login_Schema_And_Guest.sql',1767772950),
      (N'00170',N'V00170__Create_ACE_UserInformation_Decrypt_Procedure.sql',-2076115585),
      (N'00180',N'V00180__Create_Organization_Eligibility_Schema.sql',902861142),
      (N'00190',N'V00190__Create_ReadOrganizationEligibility_Procedure.sql',-507530288),
      (N'00200',N'V00200__Create_Organization_Bootstrap.sql',2085240197),
      (N'00210',N'V00210__Create_ReadOrganizationProject_Procedure.sql',-1323700875),
      (N'00220',N'V00220__Create_AceCommander_Role.sql',-1500945638);

IF @VerificationPhase = N'Before'
BEGIN
    IF OBJECT_ID(N'tempdb..#Role220History') IS NOT NULL OR OBJECT_ID(N'tempdb..#Role220Session') IS NOT NULL
       OR OBJECT_ID(N'tempdb..#Role220Principals') IS NOT NULL
        THROW 62921, N'Fresh verifier session required.', 1;
    DECLARE @HistoryRows bigint = (SELECT COUNT_BIG(*) FROM dbo.flyway_schema_history);
    SET @BaselineVersion = CASE @HistoryRows WHEN 20 THEN 210 WHEN 21 THEN 220 END;
    IF @BaselineVersion IS NULL
       OR EXISTS (SELECT 1 FROM dbo.flyway_schema_history WHERE [success] IS NULL OR [success] <> 1)
       OR EXISTS (SELECT [version],[script],[checksum] FROM @Expected WHERE CONVERT(int,[version]) <= @BaselineVersion
                  EXCEPT SELECT [version],[script],[checksum] FROM dbo.flyway_schema_history)
       OR EXISTS (SELECT [version],[script],[checksum] FROM dbo.flyway_schema_history
                  EXCEPT SELECT [version],[script],[checksum] FROM @Expected WHERE CONVERT(int,[version]) <= @BaselineVersion)
        THROW 62922, N'Exact twenty-row V210 or twenty-one-row V220 history/checksums required.', 1;
    IF @BaselineVersion = 210 AND DATABASE_PRINCIPAL_ID(N'AceCommander') IS NOT NULL
        THROW 62923, N'The AceCommander principal must be absent before V00220.', 1;
    IF @MemberSid IS NULL
        THROW 62924, N'The Windows account <MachineName>\SvcAceCommander must resolve on this host.', 1;
    SELECT * INTO #Role220History FROM dbo.flyway_schema_history;
    SELECT [principal_id],[name],[type],[sid],[owning_principal_id],[default_schema_name],[is_fixed_role]
      INTO #Role220Principals FROM sys.database_principals;
    SELECT [role_principal_id],[member_principal_id] INTO #Role220Members FROM sys.database_role_members;
    SELECT [class],[major_id],[minor_id],[grantee_principal_id],[grantor_principal_id],[type],[state]
      INTO #Role220Permissions FROM sys.database_permissions;
    CREATE TABLE #Role220Session (SessionId int NOT NULL, Catalog nvarchar(128) NOT NULL, BaselineVersion smallint NOT NULL);
    INSERT #Role220Session VALUES (@@SPID, DB_NAME(), @BaselineVersion);
END
ELSE
BEGIN
    IF OBJECT_ID(N'tempdb..#Role220History') IS NULL OR OBJECT_ID(N'tempdb..#Role220Session') IS NULL
       OR OBJECT_ID(N'tempdb..#Role220Principals') IS NULL OR OBJECT_ID(N'tempdb..#Role220Members') IS NULL
       OR OBJECT_ID(N'tempdb..#Role220Permissions') IS NULL
        THROW 62925, N'The original dedicated verifier session is required.', 1;
    IF (SELECT COUNT_BIG(*) FROM #Role220Session) <> 1
       OR NOT EXISTS (SELECT 1 FROM #Role220Session WHERE SessionId = @@SPID AND Catalog = DB_NAME() AND BaselineVersion IN (210,220))
        THROW 62925, N'The original dedicated verifier session is required.', 1;
    SELECT @BaselineVersion = BaselineVersion FROM #Role220Session;
    IF (SELECT COUNT_BIG(*) FROM dbo.flyway_schema_history) <> 21
       OR EXISTS (SELECT 1 FROM dbo.flyway_schema_history WHERE [success] IS NULL OR [success] <> 1)
       OR EXISTS (SELECT * FROM #Role220History EXCEPT SELECT * FROM dbo.flyway_schema_history)
       OR EXISTS (SELECT [version],[script],[checksum] FROM @Expected EXCEPT SELECT [version],[script],[checksum] FROM dbo.flyway_schema_history)
       OR EXISTS (SELECT [version],[script],[checksum] FROM dbo.flyway_schema_history EXCEPT SELECT [version],[script],[checksum] FROM @Expected)
        THROW 62926, N'Exactly one successful V00220 row and unchanged predecessors required.', 1;
    IF @BaselineVersion = 220 AND EXISTS (SELECT * FROM dbo.flyway_schema_history EXCEPT SELECT * FROM #Role220History)
        THROW 62926, N'Already-V220 history changed.', 1;

    -- Every pre-existing principal, membership and permission is unchanged. The only additions
    -- admitted are the AceCommander role, the <MachineName>\SvcAceCommander user (when V00220
    -- created it), that user's CONNECT grant, its membership and the role's own grants.
    IF EXISTS (SELECT * FROM #Role220Principals
               EXCEPT SELECT [principal_id],[name],[type],[sid],[owning_principal_id],[default_schema_name],[is_fixed_role] FROM sys.database_principals)
       OR EXISTS (SELECT 1 FROM sys.database_principals AS p
                  WHERE NOT EXISTS (SELECT 1 FROM #Role220Principals AS b WHERE b.[principal_id] = p.[principal_id])
                    AND (@BaselineVersion = 220
                         OR NOT ((p.[name] = N'AceCommander' AND p.[type] = 'R')
                                 OR (p.[sid] = @MemberSid AND p.[type] = 'U'))))
        THROW 62927, N'Database principals changed beyond the AceCommander role and its member.', 1;
    IF EXISTS (SELECT * FROM #Role220Members EXCEPT SELECT [role_principal_id],[member_principal_id] FROM sys.database_role_members)
       OR EXISTS (SELECT [role_principal_id],[member_principal_id] FROM sys.database_role_members
                  EXCEPT SELECT * FROM #Role220Members
                  EXCEPT SELECT DATABASE_PRINCIPAL_ID(N'AceCommander'), p.[principal_id]
                         FROM sys.database_principals AS p WHERE @BaselineVersion = 210 AND p.[sid] = @MemberSid)
        THROW 62928, N'Role memberships changed beyond the AceCommander member.', 1;
    IF EXISTS (SELECT * FROM #Role220Permissions
               EXCEPT SELECT [class],[major_id],[minor_id],[grantee_principal_id],[grantor_principal_id],[type],[state] FROM sys.database_permissions)
       OR EXISTS (SELECT 1 FROM sys.database_permissions AS dp
                  WHERE NOT EXISTS (SELECT 1 FROM #Role220Permissions AS b
                                    WHERE b.[class] = dp.[class] AND b.[major_id] = dp.[major_id] AND b.[minor_id] = dp.[minor_id]
                                      AND b.[grantee_principal_id] = dp.[grantee_principal_id] AND b.[grantor_principal_id] = dp.[grantor_principal_id]
                                      AND b.[type] = dp.[type] AND b.[state] = dp.[state])
                    AND (@BaselineVersion = 220
                         OR NOT (dp.[grantee_principal_id] = DATABASE_PRINCIPAL_ID(N'AceCommander')
                                 OR (dp.[class] = 0 AND dp.[type] = 'CO' AND dp.[state] = 'G'
                                     AND dp.[grantee_principal_id] IN (SELECT p.[principal_id] FROM sys.database_principals AS p
                                                                       WHERE p.[sid] = @MemberSid AND p.[type] = 'U'
                                                                         AND NOT EXISTS (SELECT 1 FROM #Role220Principals AS b WHERE b.[principal_id] = p.[principal_id]))))))
        THROW 62929, N'Database permissions changed beyond the AceCommander grants and its new member''s CONNECT.', 1;
END;

IF @VerificationPhase = N'After' OR @BaselineVersion = 220
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals
                   WHERE [name] = N'AceCommander' AND [type] = 'R' AND [is_fixed_role] = 0
                     AND [owning_principal_id] = DATABASE_PRINCIPAL_ID(N'dbo'))
       OR (SELECT COUNT_BIG(*) FROM sys.database_permissions
           WHERE [grantee_principal_id] = DATABASE_PRINCIPAL_ID(N'AceCommander') AND [state] = 'G') <> @ExpectedPermissionRows
       OR EXISTS (SELECT 1 FROM sys.database_permissions
                  WHERE [grantee_principal_id] = DATABASE_PRINCIPAL_ID(N'AceCommander') AND [state] <> 'G')
       OR NOT EXISTS (SELECT 1 FROM sys.database_role_members AS rm
                      JOIN sys.database_principals AS p ON p.[principal_id] = rm.[member_principal_id]
                      WHERE rm.[role_principal_id] = DATABASE_PRINCIPAL_ID(N'AceCommander')
                        AND p.[sid] = @MemberSid AND p.[type] = 'U')
        THROW 62930, N'AceCommander role post-shape (owner, grant rows, member) differs from the contract.', 1;
END;
SELECT CASE @VerificationPhase WHEN N'Before' THEN N'Before220' ELSE N'After220' END AS FixturePhase;

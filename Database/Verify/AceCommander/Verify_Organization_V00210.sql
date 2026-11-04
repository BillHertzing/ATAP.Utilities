/* Clone-only, two-phase verifier: exact V170 upgrade or already-V210 preservation.
   The same dedicated connection owns all temporary snapshots across the existing
   validate/migrate210/validate sequence. No product writes or bootstrap invocation. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @ExpectedCatalog nvarchar(128)=TRY_CONVERT(nvarchar(128),SESSION_CONTEXT(N'ATAP.Organization210.ExpectedCatalog'));
IF @ExpectedCatalog IS NULL OR DB_NAME() COLLATE Latin1_General_100_BIN2 <> @ExpectedCatalog COLLATE Latin1_General_100_BIN2
   OR @ExpectedCatalog NOT LIKE N'ATAPUtilities-rehearsal-%' OR DB_NAME() = N'ATAPUtilities'
   OR @@TRANCOUNT <> 0 OR @VerificationPhase IS NULL OR @VerificationPhase NOT IN (N'Before', N'After')
    THROW 62900, N'Explicit isolated organization clone and phase required.', 1;

DECLARE @BaselineVersion smallint;
DECLARE @OrganizationTables TABLE (Name sysname NOT NULL PRIMARY KEY);
INSERT @OrganizationTables VALUES
  (N'OrganizationFactProvenance'),(N'OrganizationEntity'),(N'Person'),(N'Organization'),(N'Host'),
  (N'Membership'),(N'HostAffiliation'),(N'UserState'),(N'UserIdentityBinding'),(N'UserIdentityBindingState'),
  (N'Household'),(N'CombinedHouseholdLink'),(N'Project'),(N'ProjectState'),(N'ProjectOwnership'),
  (N'RoleAssignment'),(N'OrganizationBootstrapReceipt');
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
      (N'00150',N'V00150__Add_AISupervisor_CacheTokens.sql',910403273),
      (N'00160',N'V00160__Create_AceCommander_Login_Schema_And_Guest.sql',-421944029),
      (N'00170',N'V00170__Create_ACE_UserInformation_Decrypt_Procedure.sql',-2076115585),
      (N'00180',N'V00180__Create_Organization_Eligibility_Schema.sql',902861142),
      (N'00190',N'V00190__Create_ReadOrganizationEligibility_Procedure.sql',-507530288),
      (N'00200',N'V00200__Create_Organization_Bootstrap.sql',2085240197),
      (N'00210',N'V00210__Create_ReadOrganizationProject_Procedure.sql',-1323700875);

IF @VerificationPhase = N'Before'
BEGIN
    IF OBJECT_ID(N'tempdb..#Organization210History') IS NOT NULL
       OR OBJECT_ID(N'tempdb..#Organization210Session') IS NOT NULL
       OR OBJECT_ID(N'tempdb..#Organization210Data') IS NOT NULL
        THROW 62901, N'Fresh verifier session required.', 1;
    DECLARE @HistoryRows bigint = (SELECT COUNT_BIG(*) FROM dbo.flyway_schema_history);
    SET @BaselineVersion = CASE @HistoryRows WHEN 16 THEN 170 WHEN 20 THEN 210 END;
    IF @BaselineVersion IS NULL
       OR EXISTS (SELECT 1 FROM dbo.flyway_schema_history WHERE [success] IS NULL OR [success] <> 1)
       OR EXISTS (SELECT [version],[script],[checksum] FROM @Expected WHERE CONVERT(int,[version]) <= @BaselineVersion
                  EXCEPT SELECT [version],[script],[checksum] FROM dbo.flyway_schema_history)
       OR EXISTS (SELECT [version],[script],[checksum] FROM dbo.flyway_schema_history
                  EXCEPT SELECT [version],[script],[checksum] FROM @Expected WHERE CONVERT(int,[version]) <= @BaselineVersion)
        THROW 62902, N'Exact sixteen-row V170 or twenty-row V210 history/checksums required.', 1;
    IF @BaselineVersion = 170 AND
       (OBJECT_ID(N'ACE.Person') IS NOT NULL OR COL_LENGTH(N'ACE.User', N'PersonId') IS NOT NULL
        OR EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
                   JOIN @OrganizationTables o ON o.Name=t.name WHERE s.name=N'ACE')
        OR OBJECT_ID(N'ACE.ReadOrganizationEligibility') IS NOT NULL
        OR OBJECT_ID(N'ACE.BootstrapOrganization') IS NOT NULL OR OBJECT_ID(N'ACE.ReadOrganizationProject') IS NOT NULL)
        THROW 62901, N'Exact V170 predecessor shape required.', 1;
    IF (SELECT COUNT_BIG(*) FROM ACE.[User] WHERE UserId = '5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e'
        AND PhiloteId = '3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b' AND EmailHash IS NULL AND SaltedAndHashedPassword IS NULL) <> 1
       OR (SELECT COUNT_BIG(*) FROM ATAPUtilities.Philote WHERE PhiloteId='3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b') <> 1
       OR (SELECT COUNT_BIG(*) FROM ACE.UserSettings WHERE UserId='5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e') <> 1
       OR (SELECT COUNT_BIG(*) FROM ACE.UserPreferences WHERE UserId='5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e') <> 1
       OR EXISTS (SELECT 1 FROM ACE.UserInformation WHERE UserId='5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e')
        THROW 62903, N'Credential-free Guest predecessor required.', 1;
    SELECT * INTO #Organization210History FROM dbo.flyway_schema_history;
    SELECT * INTO #Organization210Philote FROM ATAPUtilities.Philote;
    SELECT * INTO #Organization210Periods FROM ATAPUtilities.PhiloteValidityPeriod;
    SELECT PhiloteId,UserId,SaltedAndHashedPassword,EmailHash,HashAlgorithmName,RowVersion INTO #Organization210Users FROM ACE.[User];
    SELECT * INTO #Organization210Settings FROM ACE.UserSettings;
    SELECT * INTO #Organization210Preferences FROM ACE.UserPreferences;
    SELECT * INTO #Organization210Information FROM ACE.UserInformation;
    CREATE TABLE #Organization210Session (SessionId int NOT NULL, Catalog nvarchar(128) NOT NULL, BaselineVersion smallint NOT NULL);
    INSERT #Organization210Session VALUES (@@SPID, DB_NAME(), @BaselineVersion);
    -- Full populated rows stay only in this owned verifier session, never in output/logs.
    CREATE TABLE #Organization210Data (TableName sysname NOT NULL PRIMARY KEY, PrimaryKeyOrder nvarchar(max) NOT NULL,
        ShapeJson nvarchar(max) NOT NULL, RowsJson nvarchar(max) NOT NULL);
END
ELSE
BEGIN
    IF OBJECT_ID(N'tempdb..#Organization210History') IS NULL
       OR OBJECT_ID(N'tempdb..#Organization210Session') IS NULL OR OBJECT_ID(N'tempdb..#Organization210Data') IS NULL
        THROW 62904, N'The original dedicated verifier session is required.', 1;
    IF (SELECT COUNT_BIG(*) FROM #Organization210Session) <> 1
       OR NOT EXISTS (SELECT 1 FROM #Organization210Session WHERE SessionId = @@SPID AND Catalog = DB_NAME() AND BaselineVersion IN (170,210))
        THROW 62904, N'The original dedicated verifier session is required.', 1;
    SELECT @BaselineVersion = BaselineVersion FROM #Organization210Session;
    IF (SELECT COUNT_BIG(*) FROM dbo.flyway_schema_history) <> 20
       OR EXISTS (SELECT 1 FROM dbo.flyway_schema_history WHERE [success] IS NULL OR [success] <> 1)
       OR EXISTS (SELECT * FROM #Organization210History EXCEPT SELECT * FROM dbo.flyway_schema_history)
       OR EXISTS (SELECT [version],[script],[checksum] FROM @Expected EXCEPT SELECT [version],[script],[checksum] FROM dbo.flyway_schema_history)
       OR EXISTS (SELECT [version],[script],[checksum] FROM dbo.flyway_schema_history EXCEPT SELECT [version],[script],[checksum] FROM @Expected)
        THROW 62905, N'Exactly four successful organization migrations and unchanged predecessors required.', 1;
    IF @BaselineVersion = 210 AND EXISTS (SELECT * FROM dbo.flyway_schema_history EXCEPT SELECT * FROM #Organization210History)
        THROW 62905, N'Already-V210 history changed.', 1;

    IF EXISTS (SELECT * FROM #Organization210Philote EXCEPT SELECT * FROM ATAPUtilities.Philote)
       OR EXISTS (SELECT * FROM ATAPUtilities.Philote EXCEPT SELECT * FROM #Organization210Philote)
       OR EXISTS (SELECT * FROM #Organization210Periods EXCEPT SELECT * FROM ATAPUtilities.PhiloteValidityPeriod)
       OR EXISTS (SELECT * FROM ATAPUtilities.PhiloteValidityPeriod EXCEPT SELECT * FROM #Organization210Periods)
       OR EXISTS (SELECT * FROM #Organization210Users EXCEPT SELECT PhiloteId,UserId,SaltedAndHashedPassword,EmailHash,HashAlgorithmName,RowVersion FROM ACE.[User])
       OR EXISTS (SELECT PhiloteId,UserId,SaltedAndHashedPassword,EmailHash,HashAlgorithmName,RowVersion FROM ACE.[User] EXCEPT SELECT * FROM #Organization210Users)
       OR EXISTS (SELECT * FROM #Organization210Settings EXCEPT SELECT * FROM ACE.UserSettings)
       OR EXISTS (SELECT * FROM ACE.UserSettings EXCEPT SELECT * FROM #Organization210Settings)
       OR EXISTS (SELECT * FROM #Organization210Preferences EXCEPT SELECT * FROM ACE.UserPreferences)
       OR EXISTS (SELECT * FROM ACE.UserPreferences EXCEPT SELECT * FROM #Organization210Preferences)
       OR EXISTS (SELECT * FROM #Organization210Information EXCEPT SELECT * FROM ACE.UserInformation)
       OR EXISTS (SELECT * FROM ACE.UserInformation EXCEPT SELECT * FROM #Organization210Information)
        THROW 62906, N'Shared identity, account or Guest-related rows changed.', 1;
END;

IF @VerificationPhase = N'After' OR @BaselineVersion = 210
BEGIN
    IF COL_LENGTH(N'ACE.User', N'PersonId') IS NULL
       OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'ACE.User') AND name=N'PersonId' AND is_nullable=1 AND system_type_id=36)
       OR OBJECT_ID(N'ACE.AC_FK_User_Person',N'F') IS NULL
       OR NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'ACE.User') AND name=N'AC_UX_User_PersonId' AND is_unique=1 AND has_filter=1)
       OR OBJECT_ID(N'ACE.ReadOrganizationEligibility',N'P') IS NULL
       OR OBJECT_ID(N'ACE.BootstrapOrganization',N'P') IS NULL
       OR OBJECT_ID(N'ACE.ReadOrganizationProject',N'P') IS NULL
        THROW 62907, N'Organization account link or procedure post-shape missing.', 1;
    IF @BaselineVersion = 210 INSERT @OrganizationTables VALUES (N'User');
    IF @BaselineVersion = 210 AND @VerificationPhase = N'After'
       AND (SELECT COUNT_BIG(*) FROM #Organization210Data) <> (SELECT COUNT_BIG(*) FROM @OrganizationTables)
        THROW 62912, N'Complete populated-state snapshot required.', 1;
    DECLARE @TableName sysname, @Check nvarchar(max), @OrderBy nvarchar(max), @Shape nvarchar(max), @Rows nvarchar(max);
    DECLARE OrganizationTables CURSOR LOCAL FAST_FORWARD FOR SELECT Name FROM @OrganizationTables ORDER BY Name;
    OPEN OrganizationTables;
    FETCH NEXT FROM OrganizationTables INTO @TableName;
    WHILE @@FETCH_STATUS=0
    BEGIN
        IF OBJECT_ID(N'ACE.'+@TableName,N'U') IS NULL THROW 62908, N'Organization table missing.', 1;
        IF @BaselineVersion = 170
        BEGIN
            SET @Check=N'IF EXISTS (SELECT 1 FROM ACE.'+QUOTENAME(@TableName)+N') THROW 62909, N''Schema deployment must not bootstrap data.'', 1;';
            EXEC sys.sp_executesql @Check;
        END
        ELSE
        BEGIN
            -- A primary-key order makes full-row JSON deterministic, including binary/rowversion,
            -- NULL, account links and receipt payloads. Bind column types/shape as well as values.
            SELECT @OrderBy=STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(c.name)),N',') WITHIN GROUP (ORDER BY ic.key_ordinal)
            FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
            JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
            WHERE i.object_id=OBJECT_ID(N'ACE.'+@TableName) AND i.is_primary_key=1 AND ic.key_ordinal>0;
            IF @OrderBy IS NULL THROW 62912, N'Populated-state primary key required.', 1;
            SET @Shape=(SELECT c.column_id,c.name,c.system_type_id,c.user_type_id,c.max_length,c.precision,c.scale,
                c.collation_name,c.is_nullable,c.is_identity,c.is_computed
                FROM sys.columns c WHERE c.object_id=OBJECT_ID(N'ACE.'+@TableName)
                ORDER BY c.column_id FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Rows=NULL;
            SET @Check=N'SELECT @Rows=(SELECT * FROM ACE.'+QUOTENAME(@TableName)+N' ORDER BY '+@OrderBy+N' FOR JSON PATH,INCLUDE_NULL_VALUES);';
            EXEC sys.sp_executesql @Check,N'@Rows nvarchar(max) OUTPUT',@Rows=@Rows OUTPUT;
            IF @Rows IS NULL OR @Shape IS NULL THROW 62912, N'Complete populated-state rows and shape required.', 1;
            IF @VerificationPhase = N'Before'
                INSERT #Organization210Data VALUES (@TableName,@OrderBy,@Shape,@Rows);
            ELSE IF NOT EXISTS (SELECT 1 FROM #Organization210Data WHERE TableName=@TableName
                AND PrimaryKeyOrder COLLATE Latin1_General_100_BIN2 = @OrderBy COLLATE Latin1_General_100_BIN2
                AND ShapeJson COLLATE Latin1_General_100_BIN2 = @Shape COLLATE Latin1_General_100_BIN2
                AND RowsJson COLLATE Latin1_General_100_BIN2 = @Rows COLLATE Latin1_General_100_BIN2
                AND DATALENGTH(PrimaryKeyOrder)=DATALENGTH(@OrderBy) AND DATALENGTH(ShapeJson)=DATALENGTH(@Shape)
                AND DATALENGTH(RowsJson)=DATALENGTH(@Rows))
                THROW 62913, N'Populated organization or account state changed.', 1;
        END;
        FETCH NEXT FROM OrganizationTables INTO @TableName;
    END;
    CLOSE OrganizationTables;
    DEALLOCATE OrganizationTables;
    IF @BaselineVersion = 170
        EXEC sys.sp_executesql N'IF EXISTS (SELECT 1 FROM ACE.[User] WHERE PersonId IS NOT NULL) THROW 62910, N''Schema deployment must leave accounts unlinked.'', 1;';
END;
SELECT CASE @VerificationPhase WHEN N'Before' THEN N'Before210' ELSE N'After210' END AS FixturePhase;

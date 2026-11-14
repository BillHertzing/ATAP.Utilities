-- Database maintenance window, step (a): read-only writer/consumer, permission and name check.
-- Tier-parameterized port of senior1-backup-r3 WindowPrecheck.sql (891F31C5). Read-only: DMVs and
-- catalog views only; nothing is written. Executed by Invoke-MaintenanceSqlDataSet with these
-- parameters, all bound from the hashed window binding and the module's fixed tier map:
--   @ExpectedMachine, @ExpectedInstance, @ExpectedLogin, @ExpectedSid (varbinary), @Catalog,
--   @CloneName, @ClonePrefix (ATAPUtilities_<OperationSet>Clone_), @CloneDataPath, @CloneLogPath, @RehearsalName.
-- Connection: Integrated Security, Initial Catalog = master.
SET NOCOUNT ON;

IF ISNULL(UPPER(CONVERT(nvarchar(128), SERVERPROPERTY(N'MachineName'))), N'') <> UPPER(@ExpectedMachine)
  OR ISNULL(UPPER(CONVERT(nvarchar(128), SERVERPROPERTY(N'InstanceName'))), N'') <> UPPER(@ExpectedInstance)
  OR ISNULL(DB_NAME(), N'') <> N'master'
  THROW 63021, N'Exact approved host/instance and master connection required.', 1;
IF ISNULL(ORIGINAL_LOGIN(), N'') COLLATE Latin1_General_100_CI_AS <> @ExpectedLogin COLLATE Latin1_General_100_CI_AS
  OR SUSER_SID(ORIGINAL_LOGIN()) IS NULL OR SUSER_SID(ORIGINAL_LOGIN()) <> @ExpectedSid
  THROW 63031, N'Approved runner identity required.', 1;
-- Without VIEW SERVER STATE the DMVs show only this session, so an empty result would be a false
-- all-clear. Refuse instead of passing.
IF ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1 AND ISNULL(HAS_PERMS_BY_NAME(NULL, NULL, N'VIEW SERVER STATE'), 0) <> 1
  THROW 63060, N'VIEW SERVER STATE (or sysadmin) required; otherwise other sessions are invisible.', 1;
IF DB_ID(@Catalog) IS NULL
  THROW 63033, N'Source database not found.', 1;

DECLARE @source int = DB_ID(@Catalog);

-- Writer and consumer check. A session counts if its current database is the source, or if it
-- holds any lock in the source (every connection using a database holds a DATABASE lock).
DECLARE @others TABLE (session_id int PRIMARY KEY);
INSERT INTO @others (session_id)
SELECT s.session_id FROM sys.dm_exec_sessions s
WHERE s.is_user_process = 1 AND s.session_id <> @@SPID AND s.database_id = @source
UNION
SELECT l.request_session_id FROM sys.dm_tran_locks l
WHERE l.resource_database_id = @source AND l.request_session_id <> @@SPID AND l.request_session_id > 0;

SELECT N'WindowOpen' AS EvidenceSet, SYSUTCDATETIME() AS ObservedUtc, @@SPID AS RunnerSessionId,
  (SELECT COUNT(*) FROM @others) AS OtherSessionCount,
  d.state_desc, d.user_access_desc, d.is_read_only, d.is_auto_close_on, d.recovery_model_desc
FROM sys.databases d WHERE d.database_id = @source;

-- Identifies any other session so the operator can find and pause its owner.
SELECT N'OtherSessions' AS EvidenceSet, s.session_id, s.login_name, s.host_name, s.program_name,
  s.status, s.login_time, s.last_request_end_time, DB_NAME(s.database_id) AS CurrentDatabase
FROM @others o JOIN sys.dm_exec_sessions s ON s.session_id = o.session_id
ORDER BY s.session_id;

-- Rights the later steps need. Reported here; the PrecheckOnly verdict fails on any 0.
SELECT N'RunnerRights' AS EvidenceSet,
  ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) AS IsSysadmin,
  ISNULL(HAS_PERMS_BY_NAME(NULL, NULL, N'VIEW SERVER STATE'), 0) AS ViewServerState,
  ISNULL(HAS_PERMS_BY_NAME(NULL, NULL, N'CREATE ANY DATABASE'), 0) AS CreateAnyDatabase,
  ISNULL(HAS_PERMS_BY_NAME(N'msdb.dbo.backupset', N'OBJECT', N'SELECT'), 0) AS MsdbBackupsetSelect,
  ISNULL(HAS_PERMS_BY_NAME(N'msdb.dbo.restorehistory', N'OBJECT', N'SELECT'), 0) AS MsdbRestoreHistorySelect,
  ISNULL(HAS_PERMS_BY_NAME(@Catalog, N'DATABASE', N'CONTROL'), 0) AS CatalogControl;

-- Source size, for the runner's disk-space check (sizes in 8 KB pages).
SELECT N'SourceFiles' AS EvidenceSet, mf.type_desc, mf.name AS LogicalName, mf.size AS SizePages
FROM sys.master_files mf WHERE mf.database_id = @source
ORDER BY mf.type_desc, mf.name;

-- Name check: every database that could collide with this window's clone, or with the gate's
-- rehearsal clone for this build and tier.
SELECT N'NameCheck' AS EvidenceSet, d.name, d.database_id, d.state_desc, d.create_date
FROM sys.databases d
WHERE d.name = @CloneName OR LEFT(d.name, LEN(@ClonePrefix)) = @ClonePrefix
   OR d.name LIKE N'ATAPUtilities-rehearsal-%'
ORDER BY d.name;

SELECT N'ClonePathCheck' AS EvidenceSet, mf.database_id, DB_NAME(mf.database_id) AS DatabaseName, mf.type_desc,
  CONVERT(varchar(64), HASHBYTES(N'SHA2_256', CONVERT(varbinary(max), UPPER(mf.physical_name))), 2) AS PhysicalNameSha256
FROM sys.master_files mf
WHERE mf.physical_name IN (@CloneDataPath, @CloneLogPath);

-- Refusals come after the evidence sets, so the caller sees what caused them.
IF EXISTS (SELECT 1 FROM @others)
  THROW 63061, N'Other sessions use the source; pause their writers and consumers, then start a new window.', 1;
IF DB_ID(@CloneName) IS NOT NULL
  THROW 63041, N'Clone name already in use.', 1;
IF EXISTS (SELECT 1 FROM sys.master_files WHERE physical_name IN (@CloneDataPath, @CloneLogPath))
  THROW 63042, N'Clone file path already in use.', 1;
IF DB_ID(@RehearsalName) IS NOT NULL
  THROW 63062, N'Gate rehearsal clone for this build and tier already exists; hold for operator.', 1;

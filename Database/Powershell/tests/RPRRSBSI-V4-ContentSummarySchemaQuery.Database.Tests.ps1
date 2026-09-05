#Requires -Version 7.0
#Requires -Module Pester

Set-StrictMode -Version Latest

Describe 'V00110 guarded disposable fresh, V00100-upgrade, and recovery acceptance' {
  $authorization = [Environment]::GetEnvironmentVariable('ATAP_CONTENTSUMMARY_V110_DISPOSABLE_AUTHORIZATION', 'Process')
  $localInstance = [Environment]::GetEnvironmentVariable('ATAP_CONTENTSUMMARY_V110_DISPOSABLE_SQL_INSTANCE', 'Process')
  $requested = -not [string]::IsNullOrEmpty($authorization)
  $canRun = $requested -and $authorization -ceq 'AUTHORIZE_TASK_15_60_E_DAB_FACADE_DISPOSABLE' -and
    $localInstance -and (Get-Command flyway -ErrorAction SilentlyContinue) -and
    (Get-Command sqlcmd -ErrorAction SilentlyContinue)

  BeforeAll {
    $authorization = [Environment]::GetEnvironmentVariable('ATAP_CONTENTSUMMARY_V110_DISPOSABLE_AUTHORIZATION', 'Process')
    $localInstance = [Environment]::GetEnvironmentVariable('ATAP_CONTENTSUMMARY_V110_DISPOSABLE_SQL_INSTANCE', 'Process')
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
    $flywayConfig = Join-Path $repoRoot 'Database\Flyway\flyway.toml'
    $v110Migration = Join-Path $sqlDirectory 'V00110__Create_ContentSummary_DAB_Principal_Facade.sql'
    $created = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)

    function Assert-ContentSummaryTarget {
      param([string] $Marker, [string] $Instance, [string] $Name)
      if ($Marker -cne 'AUTHORIZE_TASK_15_60_E_DAB_FACADE_DISPOSABLE') {
        throw 'V00110 disposable authorization marker required.'
      }
      $parts = $Instance.Split('\')
      if ($parts.Count -ne 2 -or $parts[0] -notin @('.', 'localhost', '127.0.0.1', [Environment]::MachineName) -or
          $parts[1] -ine 'ExpWhertzing') {
        throw 'Only the local ExpWhertzing named instance is permitted.'
      }
      if ($Name -cnotmatch '^ATAPUtilities_Task1560e_[0-9a-f]{32}$') {
        throw 'Unsafe V00110 disposable database name.'
      }
    }

    function Invoke-ContentSummarySql {
      param([string] $Name, [string] $Query, [switch] $Master)
      Assert-ContentSummaryTarget $authorization $localInstance $Name
      if (-not $Master -and -not $created.Contains($Name)) {
        throw 'Database is not owned by this fixture.'
      }
      $database = if ($Master) { 'master' } else { $Name }
      $sessionProfile = @(
        'SET ANSI_NULLS ON', 'SET QUOTED_IDENTIFIER ON', 'SET ANSI_PADDING ON',
        'SET ANSI_WARNINGS ON', 'SET ARITHABORT ON', 'SET CONCAT_NULL_YIELDS_NULL ON',
        'SET NUMERIC_ROUNDABORT OFF', 'SET NOCOUNT ON', 'SET XACT_ABORT ON'
      ) -join '; '
      $output = & sqlcmd -S $localInstance -E -d $database -b -h -1 -W -s '|' -Q (
        "$sessionProfile; $Query") 2>&1
      if ($LASTEXITCODE -ne 0) {
        throw "V00110 SQL failed: $($output -join [Environment]::NewLine)"
      }
      @($output | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    }

    function Invoke-ContentSummaryFlyway {
      param(
        [string] $Name,
        [ValidateSet('100', '110')][string] $Target,
        [ValidateSet('migrate', 'validate')][string] $Command
      )
      Assert-ContentSummaryTarget $authorization $localInstance $Name
      if (-not $created.Contains($Name)) { throw 'Database is not owned by this fixture.' }
      $jdbcInstance = if ($localInstance.StartsWith('.\')) {
        $localInstance.Replace('.', [Environment]::MachineName)
      } else { $localInstance }
      $url = "jdbc:sqlserver://$jdbcInstance;databaseName=$Name;integratedSecurity=true;encrypt=true;trustServerCertificate=true"
      $arguments = @(
        "-configFiles=$flywayConfig", "-locations=filesystem:$sqlDirectory", "-url=$url",
        "-target=$Target", '-cleanDisabled=true', '-baselineOnMigrate=false',
        '-outOfOrder=false', '-validateOnMigrate=true', $Command
      )
      $output = & flyway @arguments 2>&1
      if ($LASTEXITCODE -ne 0) {
        throw "V00110 Flyway $Command failed: $($output -join [Environment]::NewLine)"
      }
    }

    function Invoke-ContentSummaryMigrationFile {
      param([string] $Name, [switch] $ExpectFailure)
      Assert-ContentSummaryTarget $authorization $localInstance $Name
      if (-not $created.Contains($Name)) { throw 'Database is not owned by this fixture.' }
      $output = & sqlcmd -S $localInstance -E -d $Name -b -i $v110Migration 2>&1
      $failed = $LASTEXITCODE -ne 0
      if ($ExpectFailure -and -not $failed) {
        throw 'V00110 migration unexpectedly succeeded during the rollback fixture.'
      }
      if (-not $ExpectFailure -and $failed) {
        throw "V00110 migration file failed: $($output -join [Environment]::NewLine)"
      }
      @($output)
    }

    function Invoke-ContentSummaryQuery {
      param(
        [string] $Name,
        [guid[]] $AuthorizedRepositoryIds,
        [object[]] $TagRows,
        [ValidateSet('Any', 'All')][string] $MatchMode,
        [ValidateSet('CurrentOnly', 'IncludeStale')][string] $FreshnessMode,
        [int] $Limit
      )
      Assert-ContentSummaryTarget $authorization $localInstance $Name
      if (-not $created.Contains($Name)) { throw 'Database is not owned by this fixture.' }
      $connectionString = "Server=$localInstance;Database=$Name;Integrated Security=True;Encrypt=True;TrustServerCertificate=True"
      $connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)
      try {
        $command = $connection.CreateCommand()
        $command.CommandType = [System.Data.CommandType]::StoredProcedure
        $command.CommandText = 'ATAPUtilities.QueryContentSummaryCandidatesAsOfV1'
        $command.CommandTimeout = 30

        $repositories = [System.Data.DataTable]::new()
        $null = $repositories.Columns.Add('RepositoryId', [guid])
        foreach ($id in @($AuthorizedRepositoryIds)) { $null = $repositories.Rows.Add($id) }
        $repositoryParameter = $command.Parameters.Add('@AuthorizedRepositories', [System.Data.SqlDbType]::Structured)
        $repositoryParameter.TypeName = 'ATAPUtilities.ContentSummaryAuthorizedRepositoryInput'
        $repositoryParameter.Value = $repositories

        $matches = [System.Data.DataTable]::new()
        $null = $matches.Columns.Add('RequestOrdinal', [byte])
        $null = $matches.Columns.Add('RequestedTagId', [guid])
        $null = $matches.Columns.Add('MatchedTagId', [guid])
        $null = $matches.Columns.Add('Depth', [byte])
        $null = $matches.Columns.Add('TraversalOrdinal', [int])
        $null = $matches.Columns.Add('PathWeight', [decimal])
        foreach ($row in @($TagRows)) {
          $null = $matches.Rows.Add(
            [byte]$row.RequestOrdinal, [guid]$row.RequestedTagId, [guid]$row.MatchedTagId,
            [byte]$row.Depth, [int]$row.TraversalOrdinal, [decimal]$row.PathWeight)
        }
        $matchParameter = $command.Parameters.Add('@TagMatches', [System.Data.SqlDbType]::Structured)
        $matchParameter.TypeName = 'ATAPUtilities.ContentSummaryTagMatchInput'
        $matchParameter.Value = $matches
        $null = $command.Parameters.Add('@MatchMode', [System.Data.SqlDbType]::VarChar, 3)
        $command.Parameters['@MatchMode'].Value = $MatchMode
        $null = $command.Parameters.Add('@AsOfUtc', [System.Data.SqlDbType]::DateTime2)
        # SQL datetime2 has no offset. Preserve the already-normalized UTC wall-clock value.
        $command.Parameters['@AsOfUtc'].Value = [datetime]::SpecifyKind(
          [datetime]'2026-09-05T03:00:00', [DateTimeKind]::Unspecified)
        $null = $command.Parameters.Add('@FreshnessMode', [System.Data.SqlDbType]::VarChar, 16)
        $command.Parameters['@FreshnessMode'].Value = $FreshnessMode
        $null = $command.Parameters.Add('@Limit', [System.Data.SqlDbType]::Int)
        $command.Parameters['@Limit'].Value = $Limit

        $connection.Open()
        $reader = $command.ExecuteReader()
        try {
          $sets = @()
          do {
            $rows = @()
            while ($reader.Read()) {
              $values = [ordered]@{}
              for ($index = 0; $index -lt $reader.FieldCount; $index++) {
                $value = $reader.GetValue($index)
                $values[$reader.GetName($index)] = if ($value -is [DBNull]) { $null } else { $value }
              }
              $rows += [pscustomobject]$values
            }
            $sets += ,$rows
          } while ($reader.NextResult())
        }
        finally { $reader.Dispose() }
        [pscustomobject]@{ Metadata = @($sets[0]); Items = @($sets[1]) }
      }
      finally { $connection.Dispose() }
    }

    function Invoke-ContentSummaryFacade {
      param(
        [string] $Name,
        [ValidateSet('Task1560eMappedReader', 'Task1560eUnmappedReader', 'Task1560eNoRole')]
        [string] $User,
        [string] $Tags,
        [int] $Depth=3,
        [int] $Width=2,
        [string] $Instance='production'
      )
      Assert-ContentSummaryTarget $authorization $localInstance $Name
      if (-not $created.Contains($Name)) { throw 'Database is not owned by this fixture.' }
      $connectionString = "Server=$localInstance;Database=$Name;Integrated Security=True;Encrypt=True;TrustServerCertificate=True"
      $connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)
      try {
        $command = $connection.CreateCommand()
        $command.CommandType = [System.Data.CommandType]::Text
        $command.CommandText = @"
EXECUTE AS USER = N'$User';
BEGIN TRY
  EXEC [ATAPUtilities].[QueryContentSummaryCandidatesForMcpV1]
    @Tags=@Tags,@Depth=@Depth,@Width=@Width,@Instance=@Instance;
  REVERT;
END TRY
BEGIN CATCH
  REVERT;
  THROW;
END CATCH;
"@
        $command.CommandTimeout = 30
        $null = $command.Parameters.Add('@Tags', [System.Data.SqlDbType]::NVarChar, 4000)
        $command.Parameters['@Tags'].Value = $Tags
        $null = $command.Parameters.Add('@Depth', [System.Data.SqlDbType]::Int)
        $command.Parameters['@Depth'].Value = $Depth
        $null = $command.Parameters.Add('@Width', [System.Data.SqlDbType]::Int)
        $command.Parameters['@Width'].Value = $Width
        $null = $command.Parameters.Add('@Instance', [System.Data.SqlDbType]::NVarChar, 64)
        $command.Parameters['@Instance'].Value = $Instance

        $connection.Open()
        $isolationCommand = $connection.CreateCommand()
        try {
          $isolationCommand.CommandText =
            'SELECT [transaction_isolation_level] FROM sys.dm_exec_sessions WHERE [session_id]=@@SPID;'
          $beforeIsolationLevel = [int]$isolationCommand.ExecuteScalar()
        }
        finally { $isolationCommand.Dispose() }
        $reader = $command.ExecuteReader()
        try {
          $columns = @()
          for ($index = 0; $index -lt $reader.FieldCount; $index++) {
            $columns += $reader.GetName($index)
          }
          $rows = @()
          while ($reader.Read()) {
            $values = [ordered]@{}
            for ($index = 0; $index -lt $reader.FieldCount; $index++) {
              $value = $reader.GetValue($index)
              $values[$reader.GetName($index)] = if ($value -is [DBNull]) { $null } else { $value }
            }
            $rows += [pscustomobject]$values
          }
          $additionalResultSet = $reader.NextResult()
        }
        finally { $reader.Dispose() }
        $isolationCommand = $connection.CreateCommand()
        try {
          $isolationCommand.CommandText =
            'SELECT [transaction_isolation_level] FROM sys.dm_exec_sessions WHERE [session_id]=@@SPID;'
          $afterIsolationLevel = [int]$isolationCommand.ExecuteScalar()
        }
        finally { $isolationCommand.Dispose() }
        [pscustomobject]@{
          Columns = $columns
          Rows = $rows
          HasAdditionalResultSet = $additionalResultSet
          BeforeIsolationLevel = $beforeIsolationLevel
          AfterIsolationLevel = $afterIsolationLevel
        }
      }
      finally { $connection.Dispose() }
    }

    function New-ContentSummaryCaptureSql {
      param(
        [guid] $Key,
        [string] $RequestHashHex,
        [guid] $Run,
        [guid] $Repository,
        [guid] $Root,
        [string] $Path,
        [guid] $Artifact,
        [guid] $SourceVersion,
        [guid] $Summary,
        [guid] $SummaryVersion,
        [datetime] $RecordedAtUtc,
        [string] $DerivationHex,
        [ValidateSet('summarized', 'harvested')][string] $Lifecycle,
        [AllowNull()][string] $SafeText,
        [AllowNull()][Nullable[guid]] $PriorSummaryVersion
      )
      $escapedPath = $Path.Replace("'", "''")
      $priorSql = if ($null -eq $PriorSummaryVersion -or $PriorSummaryVersion -eq [guid]::Empty) {
        'NULL'
      } else { "'$PriorSummaryVersion'" }
      if ($Lifecycle -eq 'summarized') {
        $escapedText = $SafeText.Replace("'", "''")
        $generatorValues = @{
          Kind = "'fixture'"; Name = "N'Pester fixture'"; Version = "N'1'"
          Provider = "N'fixture'"; Model = "N'fixture-model'"; Revision = "N'1'"; Effort = "'none'"
          Text = "N'$escapedText'"; SummaryHash = "0x$('33' * 32)"
        }
      } else {
        $generatorValues = @{
          Kind = 'NULL'; Name = 'NULL'; Version = 'NULL'; Provider = 'NULL'; Model = 'NULL'
          Revision = 'NULL'; Effort = 'NULL'; Text = 'NULL'; SummaryHash = 'NULL'
        }
      }
      $recorded = $RecordedAtUtc.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffff')
      @"
DECLARE @Dependencies [ATAPUtilities].[ContentSummaryDependencyInput];
EXEC [ATAPUtilities].[CaptureContentSummaryObservationV1]
  @IdempotencyKey='$Key',
  @CanonicalRequestSha256=0x$RequestHashHex,
  @RunId='$Run',
  @RepositoryId='$Repository',
  @RootRegistrationId='$Root',
  @RepoRelativePath=N'$escapedPath',
  @SourceArtifactId='$Artifact',
  @SourceArtifactVersionId='$SourceVersion',
  @ContentSummaryId='$Summary',
  @ContentSummaryVersionId='$SummaryVersion',
  @PriorContentSummaryVersionId=$priorSql,
  @ObservedAtUtc='$recorded',
  @RecordedAtUtc='$recorded',
  @ByteSha256=0x$('11' * 32),
  @NormalizedContentSha256=0x$('22' * 32),
  @ByteCount=10,
  @EncodingCode='utf-8',
  @HasBom=0,
  @LineEndingCode='lf',
  @FinalNewline=1,
  @HarvesterEntityId='b5600000-0000-0000-0000-000000000901',
  @SummaryProfileCode='initial',
  @ClassificationPolicyId='b5600000-0000-0000-0000-000000000701',
  @SourceIdentityRuleVariantId='a5600000-0000-0000-0000-000000000201',
  @NormalizationRuleVariantId='a5600000-0000-0000-0000-000000000202',
  @ClassificationRuleVariantId='a5600000-0000-0000-0000-000000000203',
  @SummaryRenderRuleVariantId='a5600000-0000-0000-0000-000000000204',
  @FreshnessRuleVariantId='a5600000-0000-0000-0000-000000000205',
  @QueryRankingRuleVariantId='a5600000-0000-0000-0000-000000000206',
  @InstantiationId='a5600000-0000-0000-0000-000000000005',
  @PromptRuleVariantId='a5600000-0000-0000-0000-000000000204',
  @GeneratorKindCode=$($generatorValues.Kind),
  @GeneratorName=$($generatorValues.Name),
  @GeneratorVersion=$($generatorValues.Version),
  @ModelProvider=$($generatorValues.Provider),
  @ModelId=$($generatorValues.Model),
  @ModelRevision=$($generatorValues.Revision),
  @ModelEffort=$($generatorValues.Effort),
  @LifecycleCode='$Lifecycle',
  @SafeSummaryText=$($generatorValues.Text),
  @SafeLocator=NULL,
  @WasRedacted=0,
  @RedactionEvidenceId=NULL,
  @SummaryContentSha256=$($generatorValues.SummaryHash),
  @ExclusionEvidenceId=NULL,
  @LifecycleReasonCode=NULL,
  @DerivationFingerprint=0x$DerivationHex,
  @Dependencies=@Dependencies;
"@
    }

    function New-ExpectedContentSummaryFailureSql {
      param([string] $CaptureSql, [string] $ExpectedCode)
      @"
DECLARE @Caught bit=0;
BEGIN TRY
$CaptureSql
END TRY
BEGIN CATCH
  IF ERROR_MESSAGE() LIKE '%$ExpectedCode%' SET @Caught=1 ELSE THROW;
END CATCH;
IF @Caught=0 THROW 60999,'Expected ContentSummary failure was not raised.',1;
"@
    }

    function Add-ContentSummaryFixtureRepository {
      param([string] $Name)
      $null = Invoke-ContentSummarySql $Name @'
INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub]) VALUES
 ('b5600000-0000-0000-0000-000000000001',NULL),
 ('b5600000-0000-0000-0000-000000000002',NULL);
INSERT INTO [ATAPUtilities].[PhiloteValidityPeriod]
 ([PhiloteValidityPeriodId],[PhiloteId],[PreviousValidToUtc],[ValidFromUtc],[ValidToUtc]) VALUES
 ('b5600000-0000-0000-0000-000000001001','b5600000-0000-0000-0000-000000000001',NULL,'2026-09-01',NULL),
 ('b5600000-0000-0000-0000-000000001002','b5600000-0000-0000-0000-000000000002',NULL,'2026-09-01',NULL);
INSERT INTO [ATAPUtilities].[Repository]
 ([RepositoryId],[PhiloteId],[OrganizationId],[CanonicalRepositoryName],[ClassificationPolicyId],
  [CreatedAtUtc],[RetiredAtUtc],[PrincipalId],[SourceReference],[RecordedAtUtc]) VALUES
 ('b5600000-0000-0000-0000-000000000001','b5600000-0000-0000-0000-000000000001',
  'b5600000-0000-0000-0000-000000000801',N'authorized-repository','b5600000-0000-0000-0000-000000000701',
  '2026-09-01',NULL,'90000000-0000-0000-0000-000000000001',N'Pester fixture','2026-09-01'),
 ('b5600000-0000-0000-0000-000000000002','b5600000-0000-0000-0000-000000000002',
  'b5600000-0000-0000-0000-000000000802',N'unauthorized-repository','b5600000-0000-0000-0000-000000000701',
  '2026-09-01',NULL,'90000000-0000-0000-0000-000000000001',N'Pester fixture','2026-09-01');
INSERT INTO [ATAPUtilities].[RepositoryRootRegistration]
 ([RepositoryRootRegistrationId],[RepositoryId],[NormalizedRoot],[RootKindCode],[RegisteredAtUtc],
  [RetiredAtUtc],[RegistrarEntityId],[EvidenceEntityId],[RecordedAtUtc]) VALUES
 ('b5600000-0000-0000-0000-000000000011','b5600000-0000-0000-0000-000000000001',N'C:\fixture\authorized','scanner-sandbox','2026-09-01',NULL,
  'b5600000-0000-0000-0000-000000000901','b5600000-0000-0000-0000-000000000902','2026-09-01'),
 ('b5600000-0000-0000-0000-000000000012','b5600000-0000-0000-0000-000000000002',N'C:\fixture\unauthorized','scanner-sandbox','2026-09-01',NULL,
  'b5600000-0000-0000-0000-000000000901','b5600000-0000-0000-0000-000000000902','2026-09-01');
'@
    }

    function Invoke-ContentSummaryFixture {
      param([ValidateSet('fresh', 'upgrade')][string] $Mode)

      $name = "ATAPUtilities_Task1560e_$([guid]::NewGuid().ToString('N'))"
      Assert-ContentSummaryTarget $authorization $localInstance $name
      try {
        $null = Invoke-ContentSummarySql $name "CREATE DATABASE [$name];" -Master
        $null = $created.Add($name)

        if ($Mode -eq 'upgrade') {
          Invoke-ContentSummaryFlyway $name '100' 'migrate'
          $predecessor = Invoke-ContentSummarySql $name @'
SELECT CONCAT(
  (SELECT COUNT_BIG(*) FROM [flyway_schema_history] WHERE [success]=1 AND [version] IN
    ('00010','00030','00040','00050','00060','00070','00080','00090','00100')),'|',
  CASE WHEN OBJECT_ID(N'[ATAPUtilities].[QueryContentSummaryCandidatesAsOfV1]',N'P') IS NOT NULL THEN 1 ELSE 0 END,'|',
  CASE WHEN OBJECT_ID(N'[ATAPUtilities].[QueryContentSummaryCandidatesForMcpV1]',N'P') IS NULL THEN 1 ELSE 0 END);
'@
          ($predecessor | Select-Object -Last 1) | Should -Be '9|1|1'
        }

        Invoke-ContentSummaryFlyway $name '110' 'migrate'
        Invoke-ContentSummaryFlyway $name '110' 'validate'

        $shape = Invoke-ContentSummarySql $name @'
SELECT CONCAT(
  (SELECT COUNT_BIG(*) FROM [flyway_schema_history] WHERE [success]=1 AND [version] IN ('00010','00030','00040','00050','00060','00070','00080','00090','00100','00110')),'|',
  (SELECT COUNT_BIG(*) FROM sys.tables WHERE [schema_id]=SCHEMA_ID(N'ATAPUtilities') AND [name] IN
    (N'Repository',N'RepositoryRootRegistration',N'SourceArtifact',N'SourceArtifactVersion',N'ContentSummary',
     N'ContentSummaryVersion',N'ContentSummaryDependency',N'ContentSummaryRefreshAttempt',N'ContentSummaryIngestionRequest',
     N'ContentSummaryDatabasePrincipalRepositoryAuthorization')),'|',
  (SELECT COUNT_BIG(*) FROM sys.table_types WHERE [schema_id]=SCHEMA_ID(N'ATAPUtilities') AND [name] IN
    (N'ContentSummaryDependencyInput',N'ContentSummaryAuthorizedRepositoryInput',N'ContentSummaryTagMatchInput')),'|',
  (SELECT COUNT_BIG(*) FROM sys.procedures WHERE [schema_id]=SCHEMA_ID(N'ATAPUtilities') AND [name] IN
    (N'CaptureContentSummaryObservationV1',N'QueryContentSummaryCandidatesAsOfV1',
     N'PopulateContentSummaryCandidateResultV1',N'QueryContentSummaryCandidatesForMcpV1')),'|',
  (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Rule] WHERE [RuleId] BETWEEN
    'a5600000-0000-0000-0000-000000000101' AND 'a5600000-0000-0000-0000-000000000106'),'|',
  (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleVariant] WHERE [RuleVariantId] BETWEEN
    'a5600000-0000-0000-0000-000000000201' AND 'a5600000-0000-0000-0000-000000000206'),'|',
  (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleVariantState] WHERE [RuleVariantId] BETWEEN
    'a5600000-0000-0000-0000-000000000201' AND 'a5600000-0000-0000-0000-000000000206'
    AND [LifecycleStatusCode]='Active'),'|',
  (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Instantiation] WHERE [InstantiationId]='a5600000-0000-0000-0000-000000000005'),'|',
  (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[TagAssignmentEntityType]
    WHERE [EntityTypeCode]=N'content-summary-version' AND [IsClassificationOnly]=1),'|',
  (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization]),'|',
  CASE WHEN DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryMcpReader') IS NOT NULL THEN 1 ELSE 0 END,'|',
  (SELECT COUNT_BIG(*) FROM sys.parameters WHERE [object_id]=OBJECT_ID(N'[ATAPUtilities].[QueryContentSummaryCandidatesAsOfV1]')),'|',
  (SELECT COUNT_BIG(*) FROM sys.parameters WHERE [object_id]=OBJECT_ID(N'[ATAPUtilities].[QueryContentSummaryCandidatesForMcpV1]')));
'@
        ($shape | Select-Object -Last 1) | Should -Be '10|10|3|4|6|6|6|1|1|0|1|6|4'

        Add-ContentSummaryFixtureRepository $name
        $repo1 = [guid]'b5600000-0000-0000-0000-000000000001'
        $repo2 = [guid]'b5600000-0000-0000-0000-000000000002'
        $root1 = [guid]'b5600000-0000-0000-0000-000000000011'
        $root2 = [guid]'b5600000-0000-0000-0000-000000000012'
        $at = [datetime]'2026-09-05T01:00:00Z'
        $captures = @(
          @{ Key='b5600000-0000-0000-0000-000000000501'; Hash=('aa' * 32); Run='b5600000-0000-0000-0000-000000000601'; Repo=$repo1; Root=$root1; Path='a.md'; Artifact='b5600000-0000-0000-0000-000000000101'; Source='b5600000-0000-0000-0000-000000000201'; Summary='b5600000-0000-0000-0000-000000000301'; Version='b5600000-0000-0000-0000-000000000401'; Derivation=('da' * 32); Text='Summary A' },
          @{ Key='b5600000-0000-0000-0000-000000000502'; Hash=('ab' * 32); Run='b5600000-0000-0000-0000-000000000602'; Repo=$repo1; Root=$root1; Path='b.md'; Artifact='b5600000-0000-0000-0000-000000000102'; Source='b5600000-0000-0000-0000-000000000202'; Summary='b5600000-0000-0000-0000-000000000302'; Version='b5600000-0000-0000-0000-000000000402'; Derivation=('db' * 32); Text='Summary B' },
          @{ Key='b5600000-0000-0000-0000-000000000503'; Hash=('ac' * 32); Run='b5600000-0000-0000-0000-000000000603'; Repo=$repo2; Root=$root2; Path='hidden.md'; Artifact='b5600000-0000-0000-0000-000000000103'; Source='b5600000-0000-0000-0000-000000000203'; Summary='b5600000-0000-0000-0000-000000000303'; Version='b5600000-0000-0000-0000-000000000403'; Derivation=('dc' * 32); Text='Summary Hidden' }
        )
        foreach ($capture in $captures) {
          $sql = New-ContentSummaryCaptureSql -Key $capture.Key -RequestHashHex $capture.Hash -Run $capture.Run `
            -Repository $capture.Repo -Root $capture.Root -Path $capture.Path -Artifact $capture.Artifact `
            -SourceVersion $capture.Source -Summary $capture.Summary -SummaryVersion $capture.Version `
            -RecordedAtUtc $at -DerivationHex $capture.Derivation -Lifecycle summarized -SafeText $capture.Text `
            -PriorSummaryVersion $null
          $result = Invoke-ContentSummarySql $name $sql
          ($result -join '|') | Should -Match 'Created'
        }

        $replay = New-ContentSummaryCaptureSql -Key $captures[0].Key -RequestHashHex $captures[0].Hash `
          -Run $captures[0].Run -Repository $repo1 -Root $root1 -Path 'a.md' -Artifact $captures[0].Artifact `
          -SourceVersion $captures[0].Source -Summary $captures[0].Summary -SummaryVersion $captures[0].Version `
          -RecordedAtUtc $at -DerivationHex $captures[0].Derivation -Lifecycle summarized -SafeText 'Summary A' `
          -PriorSummaryVersion $null
        ((Invoke-ContentSummarySql $name $replay) -join '|') | Should -Match 'Replayed'

        $conflict = New-ContentSummaryCaptureSql -Key $captures[0].Key -RequestHashHex ('ad' * 32) `
          -Run $captures[0].Run -Repository $repo1 -Root $root1 -Path 'a.md' -Artifact $captures[0].Artifact `
          -SourceVersion $captures[0].Source -Summary $captures[0].Summary -SummaryVersion $captures[0].Version `
          -RecordedAtUtc $at -DerivationHex $captures[0].Derivation -Lifecycle summarized -SafeText 'Summary A' `
          -PriorSummaryVersion $null
        $null = Invoke-ContentSummarySql $name (New-ExpectedContentSummaryFailureSql $conflict 'CS-IDEMP-001')

        $badPath = New-ContentSummaryCaptureSql -Key 'b5600000-0000-0000-0000-000000000511' -RequestHashHex ('b1' * 32) `
          -Run 'b5600000-0000-0000-0000-000000000611' -Repository $repo1 -Root $root1 -Path '../bad.md' `
          -Artifact 'b5600000-0000-0000-0000-000000000111' -SourceVersion 'b5600000-0000-0000-0000-000000000211' `
          -Summary 'b5600000-0000-0000-0000-000000000311' -SummaryVersion 'b5600000-0000-0000-0000-000000000411' `
          -RecordedAtUtc $at -DerivationHex ('e1' * 32) -Lifecycle summarized -SafeText 'Safe' -PriorSummaryVersion $null
        $null = Invoke-ContentSummarySql $name (New-ExpectedContentSummaryFailureSql $badPath 'CS-SRC-002')

        $secret = New-ContentSummaryCaptureSql -Key 'b5600000-0000-0000-0000-000000000512' -RequestHashHex ('b2' * 32) `
          -Run 'b5600000-0000-0000-0000-000000000612' -Repository $repo1 -Root $root1 -Path 'secret.md' `
          -Artifact 'b5600000-0000-0000-0000-000000000112' -SourceVersion 'b5600000-0000-0000-0000-000000000212' `
          -Summary 'b5600000-0000-0000-0000-000000000312' -SummaryVersion 'b5600000-0000-0000-0000-000000000412' `
          -RecordedAtUtc $at -DerivationHex ('e2' * 32) -Lifecycle summarized -SafeText 'ATAP_SECRET_CANARY' -PriorSummaryVersion $null
        $null = Invoke-ContentSummarySql $name (New-ExpectedContentSummaryFailureSql $secret 'CS-CLASS-002')

        $missingRepo = New-ContentSummaryCaptureSql -Key 'b5600000-0000-0000-0000-000000000513' -RequestHashHex ('b3' * 32) `
          -Run 'b5600000-0000-0000-0000-000000000613' -Repository 'b5600000-0000-0000-0000-000000000099' -Root $root1 -Path 'missing.md' `
          -Artifact 'b5600000-0000-0000-0000-000000000113' -SourceVersion 'b5600000-0000-0000-0000-000000000213' `
          -Summary 'b5600000-0000-0000-0000-000000000313' -SummaryVersion 'b5600000-0000-0000-0000-000000000413' `
          -RecordedAtUtc $at -DerivationHex ('e3' * 32) -Lifecycle summarized -SafeText 'Safe' -PriorSummaryVersion $null
        $null = Invoke-ContentSummarySql $name (New-ExpectedContentSummaryFailureSql $missingRepo 'CS-SRC-001')

        $atomicity = Invoke-ContentSummarySql $name @'
SELECT CONCAT(
  (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[SourceArtifact]),'|',
  (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[SourceArtifactVersion]),'|',
  (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[ContentSummary]),'|',
  (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[ContentSummaryVersion]),'|',
  (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[ContentSummaryIngestionRequest]));
'@
        ($atomicity | Select-Object -Last 1) | Should -Be '3|3|3|3|3'

        $appendOnly = @'
DECLARE @Caught bit=0;
BEGIN TRY
  UPDATE [ATAPUtilities].[ContentSummaryVersion] SET [SafeSummaryText]=N'mutated'
  WHERE [ContentSummaryVersionId]='b5600000-0000-0000-0000-000000000401';
END TRY BEGIN CATCH
  IF ERROR_MESSAGE() LIKE '%ContentSummaryVersion history is append-only.%' SET @Caught=1 ELSE THROW;
END CATCH;
IF @Caught=0 THROW 60998,'Expected append-only failure was not raised.',1;
IF (SELECT [SafeSummaryText] FROM [ATAPUtilities].[ContentSummaryVersion]
    WHERE [ContentSummaryVersionId]='b5600000-0000-0000-0000-000000000401')<>N'Summary A'
  THROW 60997,'Append-only rejection changed the row.',1;
'@
        $null = Invoke-ContentSummarySql $name $appendOnly

        $assignmentSql = @'
EXEC [ATAPUtilities].[CreateTagAssignment]
 @TagAssignmentId='b5600000-0000-0000-0000-000000000701',@TagId='90020000-0000-0000-0000-000000000010',
 @EntityTypeCode=N'content-summary-version',@EntityId='b5600000-0000-0000-0000-000000000401',
 @ValidFromUtc='2026-09-05',@ValidToUtc=NULL,@PrincipalId='90000000-0000-0000-0000-000000000001',
 @SourceReference=N'Pester fixture',@OccurredAtUtc='2026-09-05',@RecordedAtUtc='2026-09-05';
EXEC [ATAPUtilities].[CreateTagAssignment]
 @TagAssignmentId='b5600000-0000-0000-0000-000000000702',@TagId='90020000-0000-0000-0000-000000000020',
 @EntityTypeCode=N'content-summary-version',@EntityId='b5600000-0000-0000-0000-000000000401',
 @ValidFromUtc='2026-09-05',@ValidToUtc=NULL,@PrincipalId='90000000-0000-0000-0000-000000000001',
 @SourceReference=N'Pester fixture',@OccurredAtUtc='2026-09-05',@RecordedAtUtc='2026-09-05';
EXEC [ATAPUtilities].[CreateTagAssignment]
 @TagAssignmentId='b5600000-0000-0000-0000-000000000703',@TagId='90020000-0000-0000-0000-000000000010',
 @EntityTypeCode=N'content-summary-version',@EntityId='b5600000-0000-0000-0000-000000000402',
 @ValidFromUtc='2026-09-05',@ValidToUtc=NULL,@PrincipalId='90000000-0000-0000-0000-000000000001',
 @SourceReference=N'Pester fixture',@OccurredAtUtc='2026-09-05',@RecordedAtUtc='2026-09-05';
EXEC [ATAPUtilities].[CreateTagAssignment]
 @TagAssignmentId='b5600000-0000-0000-0000-000000000704',@TagId='90020000-0000-0000-0000-000000000010',
 @EntityTypeCode=N'content-summary-version',@EntityId='b5600000-0000-0000-0000-000000000403',
 @ValidFromUtc='2026-09-05',@ValidToUtc=NULL,@PrincipalId='90000000-0000-0000-0000-000000000001',
 @SourceReference=N'Pester fixture',@OccurredAtUtc='2026-09-05',@RecordedAtUtc='2026-09-05';
'@
        $null = Invoke-ContentSummarySql $name $assignmentSql

        $principalSql = @'
CREATE USER [Task1560eMappedReader] WITHOUT LOGIN;
CREATE USER [Task1560eUnmappedReader] WITHOUT LOGIN;
CREATE USER [Task1560eNoRole] WITHOUT LOGIN;
ALTER ROLE [ATAPContentSummaryMcpReader] ADD MEMBER [Task1560eMappedReader];
ALTER ROLE [ATAPContentSummaryMcpReader] ADD MEMBER [Task1560eUnmappedReader];
INSERT INTO [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization]
 ([AuthorizationId],[DatabasePrincipalName],[DatabasePrincipalSid],[InstanceCode],[RepositoryId],
  [ValidFromUtc],[ValidToUtc],[SourceReference],[RecordedAtUtc])
SELECT 'b5600000-0000-0000-0000-000000000801',principalRow.[name],principalRow.[sid],'production',
  'b5600000-0000-0000-0000-000000000001','2026-09-01',NULL,N'Pester principal fixture','2026-09-01'
FROM sys.database_principals principalRow WHERE principalRow.[name]=N'Task1560eMappedReader';
IF @@ROWCOUNT<>1 THROW 60996,'Mapped-reader principal fixture was not unique.',1;
'@
        $null = Invoke-ContentSummarySql $name $principalSql

        $expectedFacadeColumns = @(
          'CorrelationId', 'StatusCode', 'ErrorCode', 'AsOfUtc', 'Instance', 'Depth', 'Width',
          'MatchMode', 'FreshnessMode', 'AuthorizedRepositoryCount', 'AuthorizedMatchCount',
          'ReturnedCount', 'Truncated', 'RankingContractCode', 'WatermarkUtc', 'ItemsJson')
        $mapped = Invoke-ContentSummaryFacade $name Task1560eMappedReader `
          '["RRSBS_RULE_DEFINITION","RRSBS_INSTANTIATION_DEFINITION"]' 3 1 production
        $mapped.Columns | Should -Be $expectedFacadeColumns
        $mapped.Rows.Count | Should -Be 1
        $mapped.HasAdditionalResultSet | Should -BeFalse
        $mapped.Rows[0].StatusCode | Should -Be 'Success'
        $mapped.Rows[0].ErrorCode | Should -BeNullOrEmpty
        [int]$mapped.Rows[0].AuthorizedRepositoryCount | Should -Be 1
        [int64]$mapped.Rows[0].AuthorizedMatchCount | Should -Be 2
        [int]$mapped.Rows[0].ReturnedCount | Should -Be 1
        [bool]$mapped.Rows[0].Truncated | Should -BeTrue
        $mappedItems = @($mapped.Rows[0].ItemsJson | ConvertFrom-Json)
        $mappedItems.Count | Should -Be 1
        $mappedItems[0].RepoRelativePath | Should -Be 'a.md'
        $mappedItems[0].RepositoryId | Should -Be 'b5600000-0000-0000-0000-000000000001'
        $mapped.Rows[0].ItemsJson | Should -Not -Match 'hidden.md|Summary Hidden|b5600000-0000-0000-0000-000000000002'
        $mapped.BeforeIsolationLevel | Should -Be $mapped.AfterIsolationLevel

        $mappedRepeat = Invoke-ContentSummaryFacade $name Task1560eMappedReader `
          '["RRSBS_RULE_DEFINITION","RRSBS_INSTANTIATION_DEFINITION"]' 3 1 production
        $mappedRepeat.Rows[0].ItemsJson | Should -Be $mapped.Rows[0].ItemsJson
        $mappedRepeat.Rows[0].AuthorizedMatchCount | Should -Be $mapped.Rows[0].AuthorizedMatchCount
        $mappedRepeat.Rows[0].ReturnedCount | Should -Be $mapped.Rows[0].ReturnedCount
        $mappedRepeat.Rows[0].Truncated | Should -Be $mapped.Rows[0].Truncated

        $unresolved = Invoke-ContentSummaryFacade $name Task1560eMappedReader '["DOES_NOT_EXIST"]' 3 2 production
        $unresolved.Rows.Count | Should -Be 1
        $unresolved.Rows[0].StatusCode | Should -Be 'Error'
        $unresolved.Rows[0].ErrorCode | Should -Be 'CS-QUERY-001'
        [int64]$unresolved.Rows[0].AuthorizedMatchCount | Should -Be 0
        [int]$unresolved.Rows[0].ReturnedCount | Should -Be 0
        $unresolved.Rows[0].ItemsJson | Should -Be '[]'
        $unresolved.BeforeIsolationLevel | Should -Be $unresolved.AfterIsolationLevel

        $unmapped = Invoke-ContentSummaryFacade $name Task1560eUnmappedReader '["RRSBS_RULE_DEFINITION"]' 3 2 production
        $unmapped.Rows.Count | Should -Be 1
        $unmapped.Rows[0].StatusCode | Should -Be 'Denied'
        $unmapped.Rows[0].ErrorCode | Should -Be 'CS-AUTH-002'
        [int]$unmapped.Rows[0].AuthorizedRepositoryCount | Should -Be 0
        $unmapped.Rows[0].ItemsJson | Should -Be '[]'
        $unmapped.BeforeIsolationLevel | Should -Be $unmapped.AfterIsolationLevel

        $tierMismatch = Invoke-ContentSummaryFacade $name Task1560eMappedReader '["RRSBS_RULE_DEFINITION"]' 3 2 qa
        $tierMismatch.Rows.Count | Should -Be 1
        $tierMismatch.Rows[0].StatusCode | Should -Be 'Denied'
        $tierMismatch.Rows[0].ErrorCode | Should -Be 'CS-AUTH-002'
        [int]$tierMismatch.Rows[0].AuthorizedRepositoryCount | Should -Be 0
        $tierMismatch.Rows[0].ItemsJson | Should -Be '[]'
        $tierMismatch.BeforeIsolationLevel | Should -Be $tierMismatch.AfterIsolationLevel

        $invalidRequests = @(
          @{ Label='malformed JSON'; Tags='not-json'; Depth=3; Width=2; Instance='production' },
          @{ Label='thirteen Tags'; Tags='["A","B","C","D","E","F","G","H","I","J","K","L","M"]'; Depth=3; Width=2; Instance='production' },
          @{ Label='duplicate Tags'; Tags='["RRSBS_RULE_DEFINITION","RRSBS_RULE_DEFINITION"]'; Depth=3; Width=2; Instance='production' },
          @{ Label='overlong Tag'; Tags=('[' + ('"' + ('A' * 129) + '"') + ']'); Depth=3; Width=2; Instance='production' },
          @{ Label='zero Depth'; Tags='["RRSBS_RULE_DEFINITION"]'; Depth=0; Width=2; Instance='production' },
          @{ Label='Width above bound'; Tags='["RRSBS_RULE_DEFINITION"]'; Depth=3; Width=101; Instance='production' },
          @{ Label='unsafe Instance'; Tags='["RRSBS_RULE_DEFINITION"]'; Depth=3; Width=2; Instance='bad/instance' }
        )
        foreach ($invalidRequest in $invalidRequests) {
          $invalid = Invoke-ContentSummaryFacade $name Task1560eMappedReader `
            $invalidRequest.Tags $invalidRequest.Depth $invalidRequest.Width $invalidRequest.Instance
          $invalid.Rows.Count | Should -Be 1
          $invalid.Rows[0].StatusCode | Should -Be 'Error' -Because $invalidRequest.Label
          $invalid.Rows[0].ErrorCode | Should -Be 'CS-REQ-001' -Because $invalidRequest.Label
          $invalid.Rows[0].ItemsJson | Should -Be '[]' -Because $invalidRequest.Label
          $invalid.BeforeIsolationLevel | Should -Be $invalid.AfterIsolationLevel -Because $invalidRequest.Label
        }

        $noRoleError = $null
        try {
          $null = Invoke-ContentSummaryFacade $name Task1560eNoRole '["RRSBS_RULE_DEFINITION"]' 3 2 production
        }
        catch { $noRoleError = $_.Exception }
        $noRoleError | Should -Not -BeNullOrEmpty
        $noRoleError.Message | Should -Match '(?i)execute permission was denied'

        $permissionInventory = Invoke-ContentSummarySql $name @'
EXECUTE AS USER=N'Task1560eMappedReader';
SELECT CONCAT(
  HAS_PERMS_BY_NAME(N'ATAPUtilities.QueryContentSummaryCandidatesForMcpV1',N'OBJECT',N'EXECUTE'),'|',
  HAS_PERMS_BY_NAME(N'ATAPUtilities.QueryContentSummaryCandidatesAsOfV1',N'OBJECT',N'EXECUTE'),'|',
  HAS_PERMS_BY_NAME(N'ATAPUtilities.ContentSummary',N'OBJECT',N'SELECT'),'|',
  HAS_PERMS_BY_NAME(N'ATAPUtilities',N'SCHEMA',N'ALTER'));
REVERT;
'@
        ($permissionInventory | Select-Object -Last 1) | Should -Be '1|0|0|0'

        $actualDenials = Invoke-ContentSummarySql $name @'
DECLARE @Denied int=0;
EXECUTE AS USER=N'Task1560eMappedReader';
BEGIN TRY SELECT TOP (1) * FROM [ATAPUtilities].[ContentSummary];
END TRY BEGIN CATCH IF ERROR_NUMBER() IN (229,262) SET @Denied+=1 ELSE THROW; END CATCH;
BEGIN TRY UPDATE [ATAPUtilities].[ContentSummary] SET [RetiredAtUtc]=NULL;
END TRY BEGIN CATCH IF ERROR_NUMBER() IN (229,262) SET @Denied+=1 ELSE THROW; END CATCH;
BEGIN TRY CREATE TABLE [ATAPUtilities].[Task1560eForbidden] ([Id] int NOT NULL);
END TRY BEGIN CATCH IF ERROR_NUMBER() IN (229,262,2760) SET @Denied+=1 ELSE THROW; END CATCH;
BEGIN TRY EXEC [ATAPUtilities].[QueryContentSummaryCandidatesAsOfV1];
END TRY BEGIN CATCH IF ERROR_NUMBER() IN (229,262) SET @Denied+=1 ELSE THROW; END CATCH;
REVERT;
SELECT @Denied;
'@
        [int]($actualDenials | Select-Object -Last 1) | Should -Be 4

        $edgeFixtureSql = @'
INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub])
VALUES ('c5600000-0000-0000-0000-000000000030',NULL);
INSERT INTO [ATAPUtilities].[PhiloteValidityPeriod]
 ([PhiloteValidityPeriodId],[PhiloteId],[PreviousValidToUtc],[ValidFromUtc],[ValidToUtc])
VALUES ('c5600000-0000-0000-0000-000000000031','c5600000-0000-0000-0000-000000000030',NULL,'2026-09-05',NULL);
INSERT INTO [ATAPUtilities].[Tag]
 ([TagId],[TagNamespaceId],[TagCode],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
VALUES ('c5600000-0000-0000-0000-000000000030','90020000-0000-0000-0000-000000000001',
 N'EDGE_ORDER_ROOT','90000000-0000-0000-0000-000000000001',N'Pester edge-order fixture','2026-09-05','2026-09-05');
INSERT INTO [ATAPUtilities].[TagState]
 ([TagStateId],[TagId],[PhiloteValidityPeriodId],[ValidFromUtc],[ValidToUtc],[Label],[Description],
  [TagStateKindCode],[SuccessorTagId],[WithdrawalReason],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
VALUES ('c5600000-0000-0000-0000-000000000032','c5600000-0000-0000-0000-000000000030',
 'c5600000-0000-0000-0000-000000000031','2026-09-05',NULL,N'Edge order root',NULL,
 'Active',NULL,NULL,'90000000-0000-0000-0000-000000000001',N'Pester edge-order fixture','2026-09-05','2026-09-05');
EXEC [ATAPUtilities].[CreateTagRelation]
 @TagRelationId='c5600000-0000-0000-0000-000000000101',
 @PhiloteValidityPeriodId='c5600000-0000-0000-0000-000000000201',
 @SourceTagId='c5600000-0000-0000-0000-000000000030',
 @TargetTagId='90020000-0000-0000-0000-000000000010',@RoleCode=N'REL_RELATED_TO',@Weight=1.0000,
 @EffectiveFromUtc='2026-09-05',@PrincipalId='90000000-0000-0000-0000-000000000001',
 @SourceReference=N'Pester edge-order fixture',@OccurredAtUtc='2026-09-05',@RecordedAtUtc='2026-09-05';
EXEC [ATAPUtilities].[CreateTagRelation]
 @TagRelationId='c5600000-0000-0000-0000-000000000102',
 @PhiloteValidityPeriodId='c5600000-0000-0000-0000-000000000202',
 @SourceTagId='c5600000-0000-0000-0000-000000000030',
 @TargetTagId='90020000-0000-0000-0000-000000000020',@RoleCode=N'REL_RELATED_TO',@Weight=1.0000,
 @EffectiveFromUtc='2026-09-05',@PrincipalId='90000000-0000-0000-0000-000000000001',
 @SourceReference=N'Pester edge-order fixture',@OccurredAtUtc='2026-09-05',@RecordedAtUtc='2026-09-05';
'@
        $null = Invoke-ContentSummarySql $name $edgeFixtureSql
        $edgeOrderProof = Invoke-ContentSummarySql $name @'
DECLARE @RoleCodes [ATAPUtilities].[TagRelationRoleCodeInput];
DECLARE @Edges table
(
 [EdgeOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY,
 [TagRelationId] uniqueidentifier NOT NULL,[SourceTagId] uniqueidentifier NOT NULL,
 [TargetTagId] uniqueidentifier NOT NULL,[RoleCode] nvarchar(64) NOT NULL,
 [Projection] nvarchar(16) NOT NULL,[Weight] decimal(5,4) NOT NULL,
 [NamespaceCode] nvarchar(128) NOT NULL,[TargetTagCode] nvarchar(128) NOT NULL,
 [TagStateId] uniqueidentifier NOT NULL,[Label] nvarchar(256) NOT NULL,
 [Description] nvarchar(2048) NULL,[IsDeprecated] bit NOT NULL
);
INSERT INTO @Edges
 ([TagRelationId],[SourceTagId],[TargetTagId],[RoleCode],[Projection],[Weight],
  [NamespaceCode],[TargetTagCode],[TagStateId],[Label],[Description],[IsDeprecated])
EXEC [ATAPUtilities].[QueryTagLogicalEdgesAsOf]
 @SourceTagId='c5600000-0000-0000-0000-000000000030',@AsOfUtc='2026-09-05T05:00:00',@RoleCodes=@RoleCodes;
SELECT CONCAT(
 (SELECT TOP (1) [TargetTagCode] FROM @Edges ORDER BY [EdgeOrdinal]),'|',
 (SELECT TOP (1) [TargetTagCode] FROM @Edges ORDER BY [Weight] DESC,CONVERT(binary(16),[TargetTagId])));
'@
        ($edgeOrderProof | Select-Object -Last 1) | Should -Be 'RRSBS_INSTANTIATION_DEFINITION|RRSBS_RULE_DEFINITION'
        $edgeOrdered = Invoke-ContentSummaryFacade $name Task1560eMappedReader '["EDGE_ORDER_ROOT"]' 1 1 production
        $edgeOrdered.Rows[0].StatusCode | Should -Be 'Success'
        [int64]$edgeOrdered.Rows[0].AuthorizedMatchCount | Should -Be 1
        (@($edgeOrdered.Rows[0].ItemsJson | ConvertFrom-Json)[0]).RepoRelativePath | Should -Be 'a.md'
        $edgeOrdered.BeforeIsolationLevel | Should -Be $edgeOrdered.AfterIsolationLevel

        $ambiguityFixtureSql = @'
INSERT INTO [ATAPUtilities].[TagNamespace]
 ([TagNamespaceId],[NamespaceCode],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
VALUES ('c5600000-0000-0000-0000-000000000401',N'FIXTURE.AMBIGUITY',
 '90000000-0000-0000-0000-000000000001',N'Pester ambiguity fixture','2026-09-05','2026-09-05');
INSERT INTO [ATAPUtilities].[TagNamespaceSteward]
 ([TagNamespaceStewardId],[TagNamespaceId],[PrincipalId],[ValidFromUtc],[ValidToUtc],
  [SourceReference],[OccurredAtUtc],[RecordedAtUtc])
VALUES ('c5600000-0000-0000-0000-000000000405','c5600000-0000-0000-0000-000000000401',
 '90000000-0000-0000-0000-000000000001','2026-09-05',NULL,
 N'Pester ambiguity fixture','2026-09-05','2026-09-05');
INSERT INTO [ATAPUtilities].[Philote] ([PhiloteId],[AdditionalIdsStub])
VALUES ('c5600000-0000-0000-0000-000000000402',NULL);
INSERT INTO [ATAPUtilities].[PhiloteValidityPeriod]
 ([PhiloteValidityPeriodId],[PhiloteId],[PreviousValidToUtc],[ValidFromUtc],[ValidToUtc])
VALUES ('c5600000-0000-0000-0000-000000000403','c5600000-0000-0000-0000-000000000402',NULL,'2026-09-05',NULL);
INSERT INTO [ATAPUtilities].[Tag]
 ([TagId],[TagNamespaceId],[TagCode],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
VALUES ('c5600000-0000-0000-0000-000000000402','c5600000-0000-0000-0000-000000000401',
 N'RRSBS_RULE_DEFINITION','90000000-0000-0000-0000-000000000001',N'Pester ambiguity fixture','2026-09-05','2026-09-05');
INSERT INTO [ATAPUtilities].[TagState]
 ([TagStateId],[TagId],[PhiloteValidityPeriodId],[ValidFromUtc],[ValidToUtc],[Label],[Description],
  [TagStateKindCode],[SuccessorTagId],[WithdrawalReason],[PrincipalId],[SourceReference],[OccurredAtUtc],[RecordedAtUtc])
VALUES ('c5600000-0000-0000-0000-000000000404','c5600000-0000-0000-0000-000000000402',
 'c5600000-0000-0000-0000-000000000403','2026-09-05',NULL,N'Ambiguous rule definition',NULL,
 'Active',NULL,NULL,'90000000-0000-0000-0000-000000000001',N'Pester ambiguity fixture','2026-09-05','2026-09-05');
'@
        $null = Invoke-ContentSummarySql $name $ambiguityFixtureSql
        $ambiguous = Invoke-ContentSummaryFacade $name Task1560eMappedReader '["RRSBS_RULE_DEFINITION"]' 3 2 production
        $ambiguous.Rows.Count | Should -Be 1
        $ambiguous.Rows[0].StatusCode | Should -Be 'Error'
        $ambiguous.Rows[0].ErrorCode | Should -Be 'CS-QUERY-001'
        [int]$ambiguous.Rows[0].ReturnedCount | Should -Be 0
        $ambiguous.Rows[0].ItemsJson | Should -Be '[]'
        $ambiguous.BeforeIsolationLevel | Should -Be $ambiguous.AfterIsolationLevel

        $tag1 = [guid]'90020000-0000-0000-0000-000000000010'
        $tag2 = [guid]'90020000-0000-0000-0000-000000000020'
        $tagRows = @(
          [pscustomobject]@{ RequestOrdinal=0; RequestedTagId=$tag1; MatchedTagId=$tag1; Depth=0; TraversalOrdinal=0; PathWeight=1.0 },
          [pscustomobject]@{ RequestOrdinal=0; RequestedTagId=$tag1; MatchedTagId=$tag1; Depth=2; TraversalOrdinal=1; PathWeight=0.5 },
          [pscustomobject]@{ RequestOrdinal=1; RequestedTagId=$tag2; MatchedTagId=$tag2; Depth=0; TraversalOrdinal=0; PathWeight=1.0 }
        )
        $anyLimited = Invoke-ContentSummaryQuery $name @($repo1) $tagRows Any CurrentOnly 1
        [int64]$anyLimited.Metadata[0].AuthorizedMatchCount | Should -Be 2
        [int]$anyLimited.Metadata[0].ReturnedCount | Should -Be 1
        [bool]$anyLimited.Metadata[0].Truncated | Should -BeTrue
        $anyLimited.Items[0].RepoRelativePath | Should -Be 'a.md'

        $all = Invoke-ContentSummaryQuery $name @($repo1) $tagRows All CurrentOnly 100
        $all.Items.Count | Should -Be 1
        $all.Items[0].RepoRelativePath | Should -Be 'a.md'
        $all.Items[0].MatchedRequestedTagIdsJson | Should -Be '["90020000-0000-0000-0000-000000000010","90020000-0000-0000-0000-000000000020"]'

        $none = Invoke-ContentSummaryQuery $name @() $tagRows Any CurrentOnly 100
        [int64]$none.Metadata[0].AuthorizedMatchCount | Should -Be 0
        $none.Items.Count | Should -Be 0

        $reordered = Invoke-ContentSummaryQuery $name @($repo1) @($tagRows[2],$tagRows[1],$tagRows[0]) Any CurrentOnly 100
        (@($reordered.Items.RepoRelativePath) -join ',') | Should -Be 'a.md,b.md'
        @($reordered.Items.RepositoryId | Select-Object -Unique).Count | Should -Be 1
        $reordered.Items[0].Rank | Should -Be 1
        $reordered.Items[1].Rank | Should -Be 2

        $harvested = New-ContentSummaryCaptureSql -Key 'b5600000-0000-0000-0000-000000000504' -RequestHashHex ('ae' * 32) `
          -Run 'b5600000-0000-0000-0000-000000000604' -Repository $repo1 -Root $root1 -Path 'a.md' `
          -Artifact 'b5600000-0000-0000-0000-000000000101' -SourceVersion 'b5600000-0000-0000-0000-000000000204' `
          -Summary 'b5600000-0000-0000-0000-000000000301' -SummaryVersion 'b5600000-0000-0000-0000-000000000404' `
          -RecordedAtUtc ([datetime]'2026-09-05T02:00:00Z') -DerivationHex ('dd' * 32) -Lifecycle harvested `
          -SafeText $null -PriorSummaryVersion $null
        ((Invoke-ContentSummarySql $name $harvested) -join '|') | Should -Match 'Created'

        $current = Invoke-ContentSummaryQuery $name @($repo1) $tagRows Any CurrentOnly 100
        (@($current.Items.RepoRelativePath) -join ',') | Should -Be 'b.md'
        $includeStale = Invoke-ContentSummaryQuery $name @($repo1) $tagRows Any IncludeStale 100
        (@($includeStale.Items.RepoRelativePath) -join ',') | Should -Be 'a.md,b.md'
        ($includeStale.Items | Where-Object RepoRelativePath -EQ 'a.md').FreshnessCode | Should -Be 'stale'
        ($includeStale.Items | Where-Object RepoRelativePath -EQ 'b.md').FreshnessCode | Should -Be 'current'
        $allCurrent = Invoke-ContentSummaryQuery $name @($repo1) $tagRows All CurrentOnly 100
        $allCurrent.Items.Count | Should -Be 0

        [pscustomobject]@{
          Mode=$Mode; FlywaySuccessCount=10; Tables=10; TableTypes=3; Procedures=4; Rules=6
          AuthorizedAnyCount=2; LimitedReturnedCount=1; AllCount=1; CurrentAfterNewSourceCount=1
          IncludeStaleCount=2; FailureCases=3; FacadeInvalidCases=7
          FacadeAuthorizationVerified=$true; FacadeLeastPrivilegeVerified=$true
          FacadeInstanceBindingVerified=$true; FacadeTagResolutionVerified=$true
          FacadeEdgeOrderVerified=$true; FacadeIsolationRestorationVerified=$true
          ReplayVerified=$true; AppendOnlyVerified=$true
        }
      }
      finally {
        if ($created.Contains($name)) {
          $null = Invoke-ContentSummarySql $name @"
IF DB_ID(N'$name') IS NOT NULL
BEGIN
  ALTER DATABASE [$name] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE [$name];
END;
"@ -Master
          $null = $created.Remove($name)
        }
      }
    }

    function Invoke-ContentSummaryRecoveryFixture {
      $name = "ATAPUtilities_Task1560e_$([guid]::NewGuid().ToString('N'))"
      Assert-ContentSummaryTarget $authorization $localInstance $name
      try {
        $null = Invoke-ContentSummarySql $name "CREATE DATABASE [$name];" -Master
        $null = $created.Add($name)
        Invoke-ContentSummaryFlyway $name '100' 'migrate'
        Invoke-ContentSummaryFlyway $name '100' 'validate'

        $null = Invoke-ContentSummarySql $name @'
CREATE TABLE [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization]
(
  [CollisionSentinel] int NOT NULL,
  [DatabasePrincipalName] sysname NULL,
  [DatabasePrincipalSid] varbinary(85) NULL,
  [InstanceCode] varchar(16) NULL,
  [RepositoryId] uniqueidentifier NULL,
  [ValidToUtc] datetime2(7) NULL
);
'@
        $failureOutput = Invoke-ContentSummaryMigrationFile $name -ExpectFailure
        ($failureOutput -join [Environment]::NewLine) | Should -Match '60301|object or role collision'
        $rolledBack = Invoke-ContentSummarySql $name @'
SELECT CONCAT(
  CASE WHEN COL_LENGTH(N'ATAPUtilities.ContentSummaryDatabasePrincipalRepositoryAuthorization',N'CollisionSentinel') IS NOT NULL THEN 1 ELSE 0 END,'|',
  CASE WHEN OBJECT_ID(N'[ATAPUtilities].[PopulateContentSummaryCandidateResultV1]',N'P') IS NULL THEN 1 ELSE 0 END,'|',
  CASE WHEN OBJECT_ID(N'[ATAPUtilities].[QueryContentSummaryCandidatesForMcpV1]',N'P') IS NULL THEN 1 ELSE 0 END,'|',
  CASE WHEN DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryMcpReader') IS NULL THEN 1 ELSE 0 END,'|',
  (SELECT COUNT_BIG(*) FROM sys.parameters WHERE [object_id]=OBJECT_ID(N'[ATAPUtilities].[QueryContentSummaryCandidatesAsOfV1]')));
'@
        ($rolledBack | Select-Object -Last 1) | Should -Be '1|1|1|1|6'

        $null = Invoke-ContentSummarySql $name `
          'DROP TABLE [ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization];'
        $null = Invoke-ContentSummaryMigrationFile $name
        $recovered = Invoke-ContentSummarySql $name @'
SELECT CONCAT(
  CASE WHEN OBJECT_ID(N'[ATAPUtilities].[ContentSummaryDatabasePrincipalRepositoryAuthorization]',N'U') IS NOT NULL THEN 1 ELSE 0 END,'|',
  CASE WHEN OBJECT_ID(N'[ATAPUtilities].[PopulateContentSummaryCandidateResultV1]',N'P') IS NOT NULL THEN 1 ELSE 0 END,'|',
  CASE WHEN OBJECT_ID(N'[ATAPUtilities].[QueryContentSummaryCandidatesForMcpV1]',N'P') IS NOT NULL THEN 1 ELSE 0 END,'|',
  CASE WHEN DATABASE_PRINCIPAL_ID(N'ATAPContentSummaryMcpReader') IS NOT NULL THEN 1 ELSE 0 END,'|',
  (SELECT COUNT_BIG(*) FROM sys.parameters WHERE [object_id]=OBJECT_ID(N'[ATAPUtilities].[QueryContentSummaryCandidatesAsOfV1]')),'|',
  (SELECT COUNT_BIG(*) FROM sys.parameters WHERE [object_id]=OBJECT_ID(N'[ATAPUtilities].[QueryContentSummaryCandidatesForMcpV1]')));
'@
        ($recovered | Select-Object -Last 1) | Should -Be '1|1|1|1|6|4'
        [pscustomobject]@{ RollbackVerified=$true; RetryVerified=$true }
      }
      finally {
        if ($created.Contains($name)) {
          $null = Invoke-ContentSummarySql $name @"
IF DB_ID(N'$name') IS NOT NULL
BEGIN
  ALTER DATABASE [$name] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE [$name];
END;
"@ -Master
          $null = $created.Remove($name)
        }
      }
    }
  }

  It 'proves V00110 from an empty database' -Skip:(-not $canRun) {
    $result = Invoke-ContentSummaryFixture fresh
    $result.Mode | Should -Be 'fresh'
    $result.FailureCases | Should -Be 3
    $result.FacadeAuthorizationVerified | Should -BeTrue
    $result.FacadeInstanceBindingVerified | Should -BeTrue
    $result.FacadeTagResolutionVerified | Should -BeTrue
    $result.FacadeEdgeOrderVerified | Should -BeTrue
    $result.FacadeIsolationRestorationVerified | Should -BeTrue
  }

  It 'proves V00100 to V00110 upgrade without weakening predecessor behavior' -Skip:(-not $canRun) {
    $result = Invoke-ContentSummaryFixture upgrade
    $result.Mode | Should -Be 'upgrade'
    $result.FlywaySuccessCount | Should -Be 10
    $result.FacadeLeastPrivilegeVerified | Should -BeTrue
    $result.FacadeIsolationRestorationVerified | Should -BeTrue
  }

  It 'rolls V00110 back atomically on collision and succeeds after recovery' -Skip:(-not $canRun) {
    $result = Invoke-ContentSummaryRecoveryFixture
    $result.RollbackVerified | Should -BeTrue
    $result.RetryVerified | Should -BeTrue
  }

  It 'leaves no disposable database residue' -Skip:(-not $canRun) {
    $probe = "ATAPUtilities_Task1560e_$([guid]::NewGuid().ToString('N'))"
    $residue = Invoke-ContentSummarySql $probe @'
SELECT COUNT_BIG(*) FROM sys.databases WHERE [name] LIKE N'ATAPUtilities[_]Task1560e[_]%';
'@ -Master
    [int64]($residue | Select-Object -Last 1) | Should -Be 0
  }
}

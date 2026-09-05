#Requires -Version 7.0
#Requires -Module Pester

Set-StrictMode -Version Latest

Describe 'V00100 guarded disposable fresh and V00090-upgrade acceptance' {
  $authorization = [Environment]::GetEnvironmentVariable('ATAP_CONTENTSUMMARY_V100_DISPOSABLE_AUTHORIZATION', 'Process')
  $localInstance = [Environment]::GetEnvironmentVariable('ATAP_CONTENTSUMMARY_V100_DISPOSABLE_SQL_INSTANCE', 'Process')
  $requested = -not [string]::IsNullOrEmpty($authorization)
  $canRun = $requested -and $authorization -ceq 'AUTHORIZE_TASK_15_60_CD_DISPOSABLE' -and
    $localInstance -and (Get-Command flyway -ErrorAction SilentlyContinue) -and
    (Get-Command sqlcmd -ErrorAction SilentlyContinue)

  BeforeAll {
    $authorization = [Environment]::GetEnvironmentVariable('ATAP_CONTENTSUMMARY_V100_DISPOSABLE_AUTHORIZATION', 'Process')
    $localInstance = [Environment]::GetEnvironmentVariable('ATAP_CONTENTSUMMARY_V100_DISPOSABLE_SQL_INSTANCE', 'Process')
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
    $flywayConfig = Join-Path $repoRoot 'Database\Flyway\flyway.toml'
    $created = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)

    function Assert-ContentSummaryTarget {
      param([string] $Marker, [string] $Instance, [string] $Name)
      if ($Marker -cne 'AUTHORIZE_TASK_15_60_CD_DISPOSABLE') {
        throw 'V00100 disposable authorization marker required.'
      }
      $parts = $Instance.Split('\')
      if ($parts.Count -ne 2 -or $parts[0] -notin @('.', 'localhost', '127.0.0.1', [Environment]::MachineName) -or
          $parts[1] -ine 'ExpWhertzing') {
        throw 'Only the local ExpWhertzing named instance is permitted.'
      }
      if ($Name -cnotmatch '^ATAPUtilities_Task1560cd_[0-9a-f]{32}$') {
        throw 'Unsafe V00100 disposable database name.'
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
        throw "V00100 SQL failed: $($output -join [Environment]::NewLine)"
      }
      @($output | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    }

    function Invoke-ContentSummaryFlyway {
      param(
        [string] $Name,
        [ValidateSet('90', '100')][string] $Target,
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
        throw "V00100 Flyway $Command failed: $($output -join [Environment]::NewLine)"
      }
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
 ('b5600000-0000-0000-0000-000000001001','b5600000-0000-0000-0000-000000000001',NULL,'2026-09-05',NULL),
 ('b5600000-0000-0000-0000-000000001002','b5600000-0000-0000-0000-000000000002',NULL,'2026-09-05',NULL);
INSERT INTO [ATAPUtilities].[Repository]
 ([RepositoryId],[PhiloteId],[OrganizationId],[CanonicalRepositoryName],[ClassificationPolicyId],
  [CreatedAtUtc],[RetiredAtUtc],[PrincipalId],[SourceReference],[RecordedAtUtc]) VALUES
 ('b5600000-0000-0000-0000-000000000001','b5600000-0000-0000-0000-000000000001',
  'b5600000-0000-0000-0000-000000000801',N'authorized-repository','b5600000-0000-0000-0000-000000000701',
  '2026-09-05',NULL,'90000000-0000-0000-0000-000000000001',N'Pester fixture','2026-09-05'),
 ('b5600000-0000-0000-0000-000000000002','b5600000-0000-0000-0000-000000000002',
  'b5600000-0000-0000-0000-000000000802',N'unauthorized-repository','b5600000-0000-0000-0000-000000000701',
  '2026-09-05',NULL,'90000000-0000-0000-0000-000000000001',N'Pester fixture','2026-09-05');
INSERT INTO [ATAPUtilities].[RepositoryRootRegistration]
 ([RepositoryRootRegistrationId],[RepositoryId],[NormalizedRoot],[RootKindCode],[RegisteredAtUtc],
  [RetiredAtUtc],[RegistrarEntityId],[EvidenceEntityId],[RecordedAtUtc]) VALUES
 ('b5600000-0000-0000-0000-000000000011','b5600000-0000-0000-0000-000000000001',N'C:\fixture\authorized','scanner-sandbox','2026-09-05',NULL,
  'b5600000-0000-0000-0000-000000000901','b5600000-0000-0000-0000-000000000902','2026-09-05'),
 ('b5600000-0000-0000-0000-000000000012','b5600000-0000-0000-0000-000000000002',N'C:\fixture\unauthorized','scanner-sandbox','2026-09-05',NULL,
  'b5600000-0000-0000-0000-000000000901','b5600000-0000-0000-0000-000000000902','2026-09-05');
'@
    }

    function Invoke-ContentSummaryFixture {
      param([ValidateSet('fresh', 'upgrade')][string] $Mode)

      $name = "ATAPUtilities_Task1560cd_$([guid]::NewGuid().ToString('N'))"
      Assert-ContentSummaryTarget $authorization $localInstance $name
      try {
        $null = Invoke-ContentSummarySql $name "CREATE DATABASE [$name];" -Master
        $null = $created.Add($name)

        if ($Mode -eq 'upgrade') {
          Invoke-ContentSummaryFlyway $name '90' 'migrate'
          $predecessor = Invoke-ContentSummarySql $name @'
SELECT CONCAT(
  (SELECT COUNT_BIG(*) FROM [flyway_schema_history] WHERE [success]=1 AND [version] IN ('00010','00030','00040','00050','00060','00070','00080','00090')),'|',
  CASE WHEN OBJECT_ID(N'[ATAPUtilities].[TagAssignment]',N'U') IS NOT NULL THEN 1 ELSE 0 END,'|',
  CASE WHEN OBJECT_ID(N'[ATAPUtilities].[ContentSummary]',N'U') IS NULL THEN 1 ELSE 0 END);
'@
          ($predecessor | Select-Object -Last 1) | Should -Be '8|1|1'
        }

        Invoke-ContentSummaryFlyway $name '100' 'migrate'
        Invoke-ContentSummaryFlyway $name '100' 'validate'

        $shape = Invoke-ContentSummarySql $name @'
SELECT CONCAT(
  (SELECT COUNT_BIG(*) FROM [flyway_schema_history] WHERE [success]=1 AND [version] IN ('00010','00030','00040','00050','00060','00070','00080','00090','00100')),'|',
  (SELECT COUNT_BIG(*) FROM sys.tables WHERE [schema_id]=SCHEMA_ID(N'ATAPUtilities') AND [name] IN
    (N'Repository',N'RepositoryRootRegistration',N'SourceArtifact',N'SourceArtifactVersion',N'ContentSummary',
     N'ContentSummaryVersion',N'ContentSummaryDependency',N'ContentSummaryRefreshAttempt',N'ContentSummaryIngestionRequest')),'|',
  (SELECT COUNT_BIG(*) FROM sys.table_types WHERE [schema_id]=SCHEMA_ID(N'ATAPUtilities') AND [name] IN
    (N'ContentSummaryDependencyInput',N'ContentSummaryAuthorizedRepositoryInput',N'ContentSummaryTagMatchInput')),'|',
  (SELECT COUNT_BIG(*) FROM sys.procedures WHERE [schema_id]=SCHEMA_ID(N'ATAPUtilities') AND [name] IN
    (N'CaptureContentSummaryObservationV1',N'QueryContentSummaryCandidatesAsOfV1')),'|',
  (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Rule] WHERE [RuleId] BETWEEN
    'a5600000-0000-0000-0000-000000000101' AND 'a5600000-0000-0000-0000-000000000106'),'|',
  (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleVariant] WHERE [RuleVariantId] BETWEEN
    'a5600000-0000-0000-0000-000000000201' AND 'a5600000-0000-0000-0000-000000000206'),'|',
  (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[RuleVariantState] WHERE [RuleVariantId] BETWEEN
    'a5600000-0000-0000-0000-000000000201' AND 'a5600000-0000-0000-0000-000000000206'
    AND [LifecycleStatusCode]='Active'),'|',
  (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[Instantiation] WHERE [InstantiationId]='a5600000-0000-0000-0000-000000000005'),'|',
  (SELECT COUNT_BIG(*) FROM [ATAPUtilities].[TagAssignmentEntityType]
    WHERE [EntityTypeCode]=N'content-summary-version' AND [IsClassificationOnly]=1));
'@
        ($shape | Select-Object -Last 1) | Should -Be '9|9|3|2|6|6|6|1|1'

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
          Mode=$Mode; FlywaySuccessCount=9; Tables=9; TableTypes=3; Procedures=2; Rules=6
          AuthorizedAnyCount=2; LimitedReturnedCount=1; AllCount=1; CurrentAfterNewSourceCount=1
          IncludeStaleCount=2; FailureCases=3; ReplayVerified=$true; AppendOnlyVerified=$true
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
  }

  It 'proves V00100 from an empty database' -Skip:(-not $canRun) {
    $result = Invoke-ContentSummaryFixture fresh
    $result.Mode | Should -Be 'fresh'
    $result.FailureCases | Should -Be 3
  }

  It 'proves V00090 to V00100 upgrade without weakening predecessor behavior' -Skip:(-not $canRun) {
    $result = Invoke-ContentSummaryFixture upgrade
    $result.Mode | Should -Be 'upgrade'
    $result.FlywaySuccessCount | Should -Be 9
  }

  It 'leaves no disposable database residue' -Skip:(-not $canRun) {
    $probe = "ATAPUtilities_Task1560cd_$([guid]::NewGuid().ToString('N'))"
    $residue = Invoke-ContentSummarySql $probe @'
SELECT COUNT_BIG(*) FROM sys.databases WHERE [name] LIKE N'ATAPUtilities[_]Task1560cd[_]%';
'@ -Master
    [int64]($residue | Select-Object -Last 1) | Should -Be 0
  }
}

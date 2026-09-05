#Requires -Version 7.0
#Requires -Module Pester

Set-StrictMode -Version Latest

Describe 'V00100 ContentSummary schema and query static contract' {
  BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $flywayRoot = Join-Path $repoRoot 'Database\Flyway'
    $sqlDirectory = Join-Path $flywayRoot 'SQL'
    $migrationName = 'V00100__Create_ATAPUtilities_ContentSummary_And_Query.sql'
    $migrationPath = Join-Path $sqlDirectory $migrationName
    $migration = Get-Content -LiteralPath $migrationPath -Raw
    $facadeMigrationName = 'V00110__Create_ContentSummary_DAB_Principal_Facade.sql'
    $fixture = Get-Content -LiteralPath (
      Join-Path $PSScriptRoot 'Fixtures\ContentSummaryContract.V1.json') -Raw |
      ConvertFrom-Json -Depth 20
    $activeMigrations = @(Get-ChildItem -LiteralPath $sqlDirectory -File -Filter 'V*.sql' | Sort-Object Name)
    $dynamicBodies = @([regex]::Matches(
        $migration,
        "(?s)EXEC\s+sys\.sp_executesql\s+N'(?<body>(?:''|[^'])*)';") |
      ForEach-Object { $_.Groups['body'].Value.Replace("''", "'") })
    $scriptDomPath = 'C:\Program Files\PowerShell\Modules\SqlServer\22.3.0\coreclr\Microsoft.SqlServer.TransactSql.ScriptDom.dll'
    if (-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])) {
      Add-Type -LiteralPath $scriptDomPath
    }
  }

  It 'preserves V00100 and allocates V00110 as the unique active migration head' {
    $activeMigrations[-1].Name | Should -Be $facadeMigrationName
    (Get-FileHash -LiteralPath $migrationPath -Algorithm SHA256).Hash |
      Should -Be '0C2CD88699304D7CC9EF10303CFB4900969159A4A2E90B52C2A175AA1C69262C'
    @($activeMigrations.Name | ForEach-Object {
        if ($_ -notmatch '^(V\d+)__') { throw "Invalid migration name: $_" }
        $Matches[1]
      } | Group-Object | Where-Object Count -gt 1).Count | Should -Be 0
    Test-Path -LiteralPath (Join-Path $sqlDirectory 'V01000__Synthetic_Unknown.sql') | Should -BeFalse
  }

  It 'parses the migration and every dynamic SQL Server 2022 batch' {
    $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
    $dynamicBodies.Count | Should -Be 15
    foreach ($batch in @($migration) + $dynamicBodies) {
      $reader = [IO.StringReader]::new($batch)
      $errors = [Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
      try { $null = $parser.Parse($reader, [ref]$errors) }
      finally { $reader.Dispose() }
      @($errors | ForEach-Object { "Line $($_.Line), column $($_.Column): $($_.Message)" }) |
        Should -BeNullOrEmpty
    }
  }

  It 'creates the exact authoritative tables, types, and procedures' {
    $tables = @([regex]::Matches($migration, '(?im)^\s*CREATE TABLE \[ATAPUtilities\]\.\[(?<name>[^]]+)\]') |
      ForEach-Object { $_.Groups['name'].Value })
    @($tables | Sort-Object) | Should -Be @($fixture.implementationContract.tables | Sort-Object)
    foreach ($type in $fixture.implementationContract.tableTypes) {
      $migration | Should -Match "CREATE TYPE \[ATAPUtilities\]\.\[$([regex]::Escape($type))\]"
    }
    foreach ($procedure in $fixture.implementationContract.procedures) {
      $migration | Should -Match "CREATE PROCEDURE \[ATAPUtilities\]\.\[$([regex]::Escape($procedure))\]"
    }
  }

  It 'binds the exact 48-parameter loader and ordered result contract' {
    $loader = @($dynamicBodies | Where-Object { $_ -match 'CREATE PROCEDURE \[ATAPUtilities\]\.\[CaptureContentSummaryObservationV1\]' })
    $loader.Count | Should -Be 1
    $header = ($loader[0] -split "(?m)^AS\s*$", 2)[0]
    $parameters = @([regex]::Matches($header, '(?m)^\s*@(?<name>[A-Za-z0-9_]+)\s+') |
      ForEach-Object { $_.Groups['name'].Value })
    $parameters | Should -Be @($fixture.loaderContract.parameters)
    $parameters.Count | Should -Be 48
    foreach ($column in $fixture.loaderContract.resultColumns) {
      $loader[0] | Should -Match "\[$([regex]::Escape($column))\]"
    }
    foreach ($status in $fixture.loaderContract.replayStatuses) {
      $loader[0] | Should -Match ([regex]::Escape("'$status'"))
    }
  }

  It 'binds the exact authorized query parameter and result-column order' {
    $query = @($dynamicBodies | Where-Object { $_ -match 'CREATE PROCEDURE \[ATAPUtilities\]\.\[QueryContentSummaryCandidatesAsOfV1\]' })
    $query.Count | Should -Be 1
    $header = ($query[0] -split "(?m)^AS\s*$", 2)[0]
    $parameters = @([regex]::Matches($header, '(?m)^\s*@(?<name>[A-Za-z0-9_]+)\s+') |
      ForEach-Object { $_.Groups['name'].Value })
    $parameters | Should -Be @($fixture.queryContract.procedure.parameters)
    foreach ($column in $fixture.queryContract.procedure.metadataColumns +
      $fixture.queryContract.procedure.itemColumns) {
      $query[0] | Should -Match "\[$([regex]::Escape($column))\]"
    }
  }

  It 'registers the six exact active RuleVariants and CS-I01 composition' {
    foreach ($index in 0..5) {
      $migration | Should -Match ([regex]::Escape($fixture.ruleContractCodes[$index]))
      $migration | Should -Match ([regex]::Escape($fixture.implementationContract.ruleVariantIds[$index]))
    }
    $migration | Should -Match ([regex]::Escape($fixture.instantiationContractCode))
    $migration | Should -Match ([regex]::Escape($fixture.implementationContract.instantiationId))
    $migration | Should -Match 'RuleSetRuleOccurrence'
    $migration | Should -Match 'BuildSetRuleSetOccurrence'
  }

  It 'enforces append-only, redaction, provenance, freshness, idempotency, and typed dependency boundaries' {
    foreach ($token in @(
        'TR_Repository_AppendOnly', 'TR_RepositoryRootRegistration_AppendOnly',
        'TR_SourceArtifact_AppendOnly', 'TR_SourceArtifactVersion_AppendOnly',
        'TR_ContentSummary_AppendOnly', 'TR_ContentSummaryVersion_AppendOnly',
        'TR_ContentSummaryDependency_AppendOnly', 'TR_ContentSummaryRefreshAttempt_AppendOnly',
        'TR_ContentSummaryIngestionRequest_AppendOnly', 'WasRedacted', 'RedactionEvidenceId',
        'ExclusionEvidenceId', 'DerivationFingerprint', 'CS-IDEMP-001', 'CS-CLASS-002',
        'CS-FRESH-001', 'ContentSummaryDependencyInput'
      )) { $migration | Should -Match $token }
    $migration | Should -Not -Match '(?im)^\s*(?:GRANT|DENY|REVOKE)\b'
    $migration | Should -Not -Match '(?im)^\s*CREATE\s+(?:LOGIN|USER|ROLE)\b'
    $loader = $dynamicBodies | Where-Object { $_ -match 'CaptureContentSummaryObservationV1' }
    $loader | Should -Not -Match '@(?:Raw|Source)(?:Text|Bytes|Content)'
  }

  It 'extends Tags only with a classification-only ContentSummaryVersion target' {
    $migration | Should -Match "N'content-summary-version'"
    $migration | Should -Match "N'ContentSummaryVersionId'"
    $migration | Should -Match 'Tags classify and never authorize'
    $migration | Should -Not -Match '(?i)\[(?:Confidence|Relevance|Permission|Capability|Privilege|Authorization)Id\]'
  }
}

Describe 'V00110 ContentSummary DAB facade static contract' {
  BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
    $migrationName = 'V00110__Create_ContentSummary_DAB_Principal_Facade.sql'
    $migrationPath = Join-Path $sqlDirectory $migrationName
    $migration = Get-Content -LiteralPath $migrationPath -Raw
    $dynamicBodies = @([regex]::Matches(
        $migration,
        "(?s)EXEC\s+sys\.sp_executesql\s+N'(?<body>(?:''|[^'])*)';") |
      ForEach-Object { $_.Groups['body'].Value.Replace("''", "'") })
    $core = @($dynamicBodies | Where-Object {
        $_ -match 'CREATE PROCEDURE \[ATAPUtilities\]\.\[PopulateContentSummaryCandidateResultV1\]'
      })
    $v1 = @($dynamicBodies | Where-Object {
        $_ -match 'CREATE OR ALTER PROCEDURE \[ATAPUtilities\]\.\[QueryContentSummaryCandidatesAsOfV1\]'
      })
    $facade = @($dynamicBodies | Where-Object {
        $_ -match 'CREATE PROCEDURE \[ATAPUtilities\]\.\[QueryContentSummaryCandidatesForMcpV1\]'
      })
    $scriptDomPath = 'C:\Program Files\PowerShell\Modules\SqlServer\22.3.0\coreclr\Microsoft.SqlServer.TransactSql.ScriptDom.dll'
    if (-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])) {
      Add-Type -LiteralPath $scriptDomPath
    }
  }

  It 'parses the migration and every dynamic SQL Server 2022 batch' {
    $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
    $dynamicBodies.Count | Should -Be 4
    foreach ($batch in @($migration) + $dynamicBodies) {
      $reader = [IO.StringReader]::new($batch)
      $errors = [Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
      try { $null = $parser.Parse($reader, [ref]$errors) }
      finally { $reader.Dispose() }
      @($errors | ForEach-Object { "Line $($_.Line), column $($_.Column): $($_.Message)" }) |
        Should -BeNullOrEmpty
    }
  }

  It 'preserves the exact V1 parameter and ordered two-result contract through one shared core' {
    $core.Count | Should -Be 1
    $v1.Count | Should -Be 1
    $v1Header = ($v1[0] -split "(?m)^AS\s*$", 2)[0]
    @([regex]::Matches($v1Header, '(?m)^\s*@(?<name>[A-Za-z0-9_]+)\s+') |
        ForEach-Object { $_.Groups['name'].Value }) | Should -Be @(
      'AuthorizedRepositories', 'TagMatches', 'MatchMode', 'AsOfUtc', 'FreshnessMode', 'Limit')
    $v1[0] | Should -Match 'EXEC \[ATAPUtilities\]\.\[PopulateContentSummaryCandidateResultV1\]'
    $v1[0] | Should -Not -Match 'JOIN \[ATAPUtilities\]\.\[(?:ContentSummary|SourceArtifact|TagAssignment)\]'
    $core[0] | Should -Match 'FROM @AuthorizedRepositories authorized'
    $core[0] | Should -Match 'JOIN \[ATAPUtilities\]\.\[ContentSummary\]'
    $core[0] | Should -Match 'ROW_NUMBER\(\) OVER'
    $core[0] | Should -Match 'INSERT INTO #ContentSummaryMetadata'
    $core[0] | Should -Match 'INSERT INTO #ContentSummaryItems'
    $metadataSelect = $v1[0].IndexOf('SELECT [AsOfUtc],[MatchMode],[FreshnessMode]', [StringComparison]::Ordinal)
    $itemSelect = $v1[0].IndexOf('SELECT [ContentSummaryVersionId],[ContentSummaryId]', [StringComparison]::Ordinal)
    $metadataSelect | Should -BeGreaterThan -1
    $itemSelect | Should -BeGreaterThan $metadataSelect
  }

  It 'exposes exactly four bounded scalar facade parameters with no caller authorization input' {
    $facade.Count | Should -Be 1
    $header = ($facade[0] -split "(?m)^AS\s*$", 2)[0]
    @([regex]::Matches($header, '(?m)^\s*@(?<name>[A-Za-z0-9_]+)\s+') |
        ForEach-Object { $_.Groups['name'].Value }) | Should -Be @('Tags', 'Depth', 'Width', 'Instance')
    $header | Should -Match '@Tags nvarchar\(4000\)'
    $header | Should -Match '@Depth int=3'
    $header | Should -Match '@Width int=2'
    $header | Should -Match "@Instance nvarchar\(64\)=N'production'"
    $header | Should -Not -Match '@(?:Authorized|Repository|Principal|Caller|Role)'
    $facade[0] | Should -Match 'ISJSON\(@Tags,ARRAY\)'
    $facade[0] | Should -Match 'BETWEEN 1 AND 12'
    $facade[0] | Should -Match 'COUNT_BIG\(DISTINCT \[TagText\]\)'
    $facade[0] | Should -Match 'LEN\(\[TagText\]\)>128'
    $facade[0] | Should -Match '@Depth NOT BETWEEN 1 AND 100'
    $facade[0] | Should -Match '@Width NOT BETWEEN 1 AND 100'
    $facade[0] | Should -Match "@InstanceValue COLLATE Latin1_General_100_BIN2 NOT IN\s*\(N'production',N'qa',N'integration',N'dev',N'exp'\)"
  }

  It 'authorizes by the executing database principal before resolving Tags' {
    $facade[0] | Should -Match 'DECLARE @DatabasePrincipalName sysname=USER_NAME\(\)'
    $facade[0] | Should -Match 'DATABASE_PRINCIPAL_ID\(@DatabasePrincipalName\)'
    $facade[0] | Should -Match 'authorizationRow\.\[DatabasePrincipalSid\]=@DatabasePrincipalSid'
    $facade[0] | Should -Match 'authorizationRow\.\[InstanceCode\]=@InstanceValue COLLATE Latin1_General_100_BIN2'
    $facade[0] | Should -Not -Match '(?i)simulator'
    $authorizationIndex = $facade[0].IndexOf('INSERT INTO @AuthorizedRepositories', [StringComparison]::Ordinal)
    $tagIndex = $facade[0].IndexOf('INSERT INTO @ResolvedTags', [StringComparison]::Ordinal)
    $authorizationIndex | Should -BeGreaterThan -1
    $tagIndex | Should -BeGreaterThan $authorizationIndex
    $facade[0] | Should -Match "CAST\('Denied' AS varchar\(16\)\)"
    $facade[0] | Should -Match "CAST\('CS-AUTH-002' AS varchar\(32\)\)"
    $facade[0] | Should -Match "WHEN ERROR_NUMBER\(\)=60314 THEN 'CS-QUERY-001'"
  }

  It 'returns one deterministic safe envelope through the same canonical core' {
    $facade[0] | Should -Match 'EXEC \[ATAPUtilities\]\.\[PopulateContentSummaryCandidateResultV1\]'
    $facade[0] | Should -Not -Match 'JOIN \[ATAPUtilities\]\.\[(?:ContentSummary|SourceArtifact|TagAssignment)\]'
    $expectedColumns = @(
      'CorrelationId', 'StatusCode', 'ErrorCode', 'AsOfUtc', 'Instance', 'Depth', 'Width',
      'MatchMode', 'FreshnessMode', 'AuthorizedRepositoryCount', 'AuthorizedMatchCount',
      'ReturnedCount', 'Truncated', 'RankingContractCode', 'WatermarkUtc', 'ItemsJson')
    $successSelectStart = $facade[0].IndexOf(
      "SELECT @CorrelationId AS [CorrelationId],CAST('Success' AS varchar(16))",
      [StringComparison]::Ordinal)
    $successSelectStart | Should -BeGreaterThan -1
    $success = $facade[0].Substring($successSelectStart)
    $lastIndex = -1
    foreach ($column in $expectedColumns) {
      $index = $success.IndexOf("[$column]", [StringComparison]::Ordinal)
      $index | Should -BeGreaterThan $lastIndex -Because $column
      $lastIndex = $index
    }
    $facade[0] | Should -Match 'FROM #ContentSummaryItems ORDER BY \[Rank\] FOR JSON PATH'
    $facade[0] | Should -Match 'SELECT TOP \(@Width\) \[TargetTagId\],\[Weight\] FROM @Edges\s+ORDER BY \[EdgeOrdinal\]'
    $facade[0] | Should -Not -Match 'SELECT TOP \(@Width\) \[TargetTagId\],\[Weight\] FROM @Edges\s+ORDER BY \[Weight\]'
    $facade[0] | Should -Match "CAST\(N'\[\]' AS nvarchar\(max\)\) AS \[ItemsJson\]"
    $facade[0] | Should -Not -Match 'ERROR_MESSAGE\(\)'
    $facade[0] | Should -Not -Match '@(?:Raw|Source)(?:Text|Bytes|Content)'
  }

  It 'creates an unseeded principal mapping and a single execute-only reader grant' {
    $migration | Should -Match 'CREATE TABLE \[ATAPUtilities\]\.\[ContentSummaryDatabasePrincipalRepositoryAuthorization\]'
    $migration | Should -Match '\[DatabasePrincipalName\] sysname COLLATE Latin1_General_100_BIN2'
    $migration | Should -Match '\[DatabasePrincipalSid\] varbinary\(85\)'
    $migration | Should -Match '\[InstanceCode\] varchar\(16\) COLLATE Latin1_General_100_BIN2 NOT NULL'
    $migration | Should -Match "CHECK \(\[InstanceCode\] IN \('production','qa','integration','dev','exp'\)\)"
    $migration | Should -Not -Match 'INSERT INTO \[ATAPUtilities\]\.\[ContentSummaryDatabasePrincipalRepositoryAuthorization\]'
    $migration | Should -Match 'CREATE ROLE \[ATAPContentSummaryMcpReader\] AUTHORIZATION \[dbo\]'
    @([regex]::Matches($migration, '(?im)^\s*GRANT EXECUTE ON OBJECT::')).Count | Should -Be 1
    $migration | Should -Match 'GRANT EXECUTE ON OBJECT::\[ATAPUtilities\]\.\[QueryContentSummaryCandidatesForMcpV1\]'
    $migration | Should -Match 'DENY SELECT, INSERT, UPDATE, DELETE, ALTER, REFERENCES, VIEW DEFINITION'
    $migration | Should -Match 'DENY CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, ALTER ANY SCHEMA'
    $migration | Should -Not -Match '(?im)^\s*CREATE\s+(?:LOGIN|USER)\b'
  }
}

Describe 'V00110 package binding' {
  It 'binds package 0.1.10 to every exact migration and seed byte' {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $flywayRoot = Join-Path $repoRoot 'Database\Flyway'
    $version = Get-Content -LiteralPath (Join-Path $flywayRoot 'version.json') -Raw | ConvertFrom-Json
    $allowlist = Get-Content -LiteralPath (Join-Path $flywayRoot 'package-content-allowlist.json') -Raw |
      ConvertFrom-Json -Depth 10
    $expectedPaths = @(
      @(Get-ChildItem -LiteralPath (Join-Path $flywayRoot 'SQL') -File -Filter 'V*.sql' |
        Sort-Object Name | ForEach-Object { 'SQL/' + $_.Name })
      @(Get-ChildItem -LiteralPath (Join-Path $flywayRoot 'Data') -File -Filter '*.csv' |
        Sort-Object Name | ForEach-Object { 'Data/' + $_.Name })
    )
    $version.version | Should -Be '0.1.10'
    $allowlist.sourceVersion | Should -Be $version.version
    @($allowlist.files.path) | Should -Be $expectedPaths
    foreach ($entry in $allowlist.files) {
      $path = Join-Path $flywayRoot ($entry.path -replace '/', [IO.Path]::DirectorySeparatorChar)
      (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash | Should -Be $entry.sha256 -Because $entry.path
    }
  }
}

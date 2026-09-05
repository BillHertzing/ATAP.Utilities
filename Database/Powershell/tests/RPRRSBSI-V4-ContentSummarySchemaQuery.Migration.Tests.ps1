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

  It 'allocates V00100 as the unique active migration head' {
    $activeMigrations[-1].Name | Should -Be $migrationName
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

Describe 'V00100 package binding' {
  It 'binds package 0.1.9 to every exact migration and seed byte' {
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
    $version.version | Should -Be '0.1.9'
    $allowlist.sourceVersion | Should -Be $version.version
    @($allowlist.files.path) | Should -Be $expectedPaths
    foreach ($entry in $allowlist.files) {
      $path = Join-Path $flywayRoot ($entry.path -replace '/', [IO.Path]::DirectorySeparatorChar)
      (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash | Should -Be $entry.sha256 -Because $entry.path
    }
  }
}

BeforeAll {
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
  $adrPath = Join-Path $repoRoot 'SolutionDocumentation\RRSBS-ADR-190-ContentSummary-Reconciliation.md'
  $contractPath = Join-Path $repoRoot 'Database\Documentation\RPRRSBSI-V4-2-25-ContentSummary-Data-Contract.md'
  $fixturePath = Join-Path $PSScriptRoot 'Fixtures\ContentSummaryContract.V1.json'

  $adr = Get-Content -LiteralPath $adrPath -Raw
  $contract = Get-Content -LiteralPath $contractPath -Raw
  $fixture = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json -Depth 20
}

Describe 'ContentSummary frozen phase-two contract' {
  It 'binds the fixture to Task 15.60 and schema version 1' {
    $fixture.schemaVersion | Should -Be 1
    $fixture.task | Should -Be '15.60.ab-stream-a-contentsummary-contract'
  }

  It 'preserves every immutable authority hash' {
    foreach ($authority in $fixture.authority) {
      $path = Join-Path $repoRoot ($authority.path -replace '/', '\')
      Test-Path -LiteralPath $path | Should -BeTrue
      (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash | Should -Be $authority.sha256
      $adr + $contract | Should -Match ([regex]::Escape($authority.sha256))
    }
  }

  It 'keeps V00090 as the head and V01000 as a synthetic unknown' {
    $versions = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'Database\Flyway\SQL') -File -Filter 'V*.sql' |
      ForEach-Object {
        if ($_.Name -match '^V(?<version>\d{5})__') {
          [int]$Matches.version
        }
      }

    ($versions | Measure-Object -Maximum).Maximum | Should -Be 90
    $fixture.migrationBoundary.currentHead | Should -Be 'V00090'
    $fixture.migrationBoundary.nextAllocatedVersion | Should -BeNullOrEmpty
    $fixture.migrationBoundary.expectedCandidateOnly | Should -Be 'V00100'
    $fixture.migrationBoundary.syntheticUnknownVersion | Should -Be 'V01000'
    Test-Path -LiteralPath (Join-Path $repoRoot 'Database\Flyway\SQL\V01000__Synthetic_Unknown.sql') | Should -BeFalse
    $adr | Should -Match 'synthetic unknown migration fixture is V01000'
    $contract | Should -Match 'V01000 is the synthetic unknown-version fixture'
  }

  It 'freezes exactly six Rule contracts and one Instantiation' {
    @($fixture.ruleContractCodes).Count | Should -Be 6
    @($fixture.ruleContractCodes | Select-Object -Unique).Count | Should -Be 6
    foreach ($code in $fixture.ruleContractCodes) {
      $adr | Should -Match ([regex]::Escape($code))
      $contract | Should -Match ([regex]::Escape($code))
    }

    $fixture.instantiationContractCode | Should -Be 'CS-I01-contentsummary-initial-v1'
    $adr | Should -Match ([regex]::Escape($fixture.instantiationContractCode))
    $contract | Should -Match ([regex]::Escape($fixture.instantiationContractCode))
  }

  It 'preserves the exact public request and response surface' {
    @($fixture.publicContract.requestParameters) | Should -Be @(
      'Tags', 'Depth', 'Width', 'Instance', 'Scheme', 'HostName', 'Port', 'Path',
      'AgentName', 'WorktreeRoot', 'TaskId', 'Prompt'
    )
    @($fixture.publicContract.requestBodyFields) | Should -Be @('tags', 'depth', 'width', 'instance')
    @($fixture.publicContract.responseFields) | Should -Be @('agent', 'status', 'query', 'items', 'truncated', 'error')

    foreach ($field in $fixture.publicContract.requestParameters + $fixture.publicContract.responseFields) {
      $contract | Should -Match ([regex]::Escape($field))
    }
  }

  It 'freezes the SQL boundary names, parameter order, and result ordinals' {
    $fixture.queryContract.authorizedRepositoryType.name | Should -Be '[ATAPUtilities].[ContentSummaryAuthorizedRepositoryInput]'
    @($fixture.queryContract.authorizedRepositoryType.columns) | Should -Be @('RepositoryId')
    $fixture.queryContract.tagMatchType.name | Should -Be '[ATAPUtilities].[ContentSummaryTagMatchInput]'
    @($fixture.queryContract.tagMatchType.columns) | Should -Be @(
      'RequestOrdinal', 'RequestedTagId', 'MatchedTagId', 'Depth', 'TraversalOrdinal', 'PathWeight'
    )
    $fixture.queryContract.procedure.name | Should -Be '[ATAPUtilities].[QueryContentSummaryCandidatesAsOfV1]'
    @($fixture.queryContract.procedure.parameters) | Should -Be @(
      'AuthorizedRepositories', 'TagMatches', 'MatchMode', 'AsOfUtc', 'FreshnessMode', 'Limit'
    )
    @($fixture.queryContract.procedure.metadataColumns) | Should -Be @(
      'AsOfUtc', 'MatchMode', 'FreshnessMode', 'AuthorizedMatchCount', 'ReturnedCount',
      'Truncated', 'RankingContractCode', 'WatermarkUtc'
    )
    @($fixture.queryContract.procedure.itemColumns) | Should -Be @(
      'ContentSummaryVersionId', 'ContentSummaryId', 'SourceArtifactId',
      'SourceArtifactVersionId', 'RepositoryId', 'RepoRelativePath', 'SafeText', 'SafeLocator',
      'MatchedRequestedTagIdsJson', 'MatchedResolvedTagIdsJson', 'FreshnessCode',
      'RankingContractCode', 'Rank', 'SourceObservedAtUtc', 'GeneratedAtUtc', 'RecordedAtUtc',
      'ProducerEntityId', 'NormalizedContentSha256', 'SummaryContentSha256',
      'DerivationFingerprint'
    )

    foreach ($token in @(
        $fixture.queryContract.authorizedRepositoryType.name,
        $fixture.queryContract.tagMatchType.name,
        $fixture.queryContract.procedure.name
      ) + $fixture.queryContract.procedure.parameters +
      $fixture.queryContract.procedure.metadataColumns + $fixture.queryContract.procedure.itemColumns) {
      $contract | Should -Match ([regex]::Escape($token))
    }
  }

  It 'freezes unique error and acceptance identifiers' {
    @($fixture.errorCodes).Count | Should -Be 17
    @($fixture.errorCodes | Select-Object -Unique).Count | Should -Be 17
    foreach ($code in $fixture.errorCodes) {
      $contract | Should -Match ([regex]::Escape($code))
    }

    @($fixture.acceptanceIds).Count | Should -Be 16
    @($fixture.acceptanceIds | Select-Object -Unique).Count | Should -Be 16
    foreach ($id in $fixture.acceptanceIds) {
      $contract | Should -Match ([regex]::Escape($id))
    }
  }

  It 'requires authorization and redaction before disclosure or model egress' {
    $adr | Should -Match 'authenticate and authorize the caller'
    $adr | Should -Match 'redact locally before any model egress'
    $contract | Should -Match 'classify and redact locally'
    $contract | Should -Match 'only then permit model egress'
    $contract | Should -Match 'authenticate and authorize Repository/summary scope'
    $contract | Should -Match 'traverse only the authorized Tag graph'
    $contract | Should -Match 'never zero or fabricated'
  }

  It 'keeps immutable migrations and later phases outside this claim' {
    $adr | Should -Match 'Never extend, relabel, backfill, read as the new model, or drop it'
    $contract | Should -Match 'without editing the migration'
    $contract | Should -Match 'does not allocate a GUID, physical migration filename, package version'
    $contract | Should -Match 'does not\s+authorize writing Ace/SharedVSCode/Planning'
  }
}

BeforeAll {
  $script:moduleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
  $script:moduleName = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
  Import-Module -Name 'PSFramework' -MinimumVersion '1.14.457' -Force
  Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
  Import-Module -Name (Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell.psd1') -Force -ErrorAction Stop
  foreach ($sourceFile in @(
      'private\Get-ContentSummarySha256.ps1',
      'private\Get-ContentSummarySourceObservation.ps1',
      'private\Protect-ContentSummaryText.ps1',
      'private\ConvertTo-ContentSummaryHarvestError.ps1',
      'private\ConvertTo-ContentSummaryHarvestEnvelope.ps1',
      'public\Invoke-ContentSummaryHarvest.ps1'
    )) {
    . (Join-Path $script:moduleRoot $sourceFile)
  }
}

Describe 'Invoke-ContentSummaryHarvest deterministic boundary' -Tag 'Unit', 'Task15.60.c' {
    BeforeAll {
      function New-TestRepositoryAdapter {
        {
          param(
            $IdempotencyKey,
            $CanonicalRequestSha256,
            $RunId,
            $RepositoryId,
            $RootRegistrationId,
            $RepoRelativePath,
            $SourceArtifactId,
            $SourceArtifactVersionId,
            $ContentSummaryId,
            $ContentSummaryVersionId,
            $PriorContentSummaryVersionId,
            $ObservedAtUtc,
            $RecordedAtUtc,
            $ByteSha256,
            $NormalizedContentSha256,
            $ByteCount,
            $EncodingCode,
            $HasBom,
            $LineEndingCode,
            $FinalNewline,
            $HarvesterEntityId,
            $SummaryProfileCode,
            $ClassificationPolicyId,
            $SourceIdentityRuleVariantId,
            $NormalizationRuleVariantId,
            $ClassificationRuleVariantId,
            $SummaryRenderRuleVariantId,
            $FreshnessRuleVariantId,
            $QueryRankingRuleVariantId,
            $InstantiationId,
            $PromptRuleVariantId,
            $GeneratorKindCode,
            $GeneratorName,
            $GeneratorVersion,
            $ModelProvider,
            $ModelId,
            $ModelRevision,
            $ModelEffort,
            $LifecycleCode,
            $SafeSummaryText,
            $SafeLocator,
            $WasRedacted,
            $RedactionEvidenceId,
            $SummaryContentSha256,
            $ExclusionEvidenceId,
            $LifecycleReasonCode,
            $DerivationFingerprint,
            $Dependencies
          )

          $script:repositoryCalls++
          $script:lastLoaderArguments = [ordered]@{}
          foreach ($key in $PSBoundParameters.Keys) {
            $script:lastLoaderArguments[$key] = $PSBoundParameters[$key]
          }
          $requestHash = -join ($CanonicalRequestSha256 | ForEach-Object { $_.ToString('x2') })
          $derivationHash = -join ($DerivationFingerprint | ForEach-Object { $_.ToString('x2') })
          $key = ([guid]$IdempotencyKey).ToString('D')

          if ($script:repositoryByKey.ContainsKey($key)) {
            $existing = $script:repositoryByKey[$key]
            if ($existing.RequestHash -ne $requestHash) {
              throw 'CS-IDEMP-001: idempotency conflict'
            }
            $replayStatus = 'Replayed'
            $stored = $existing
          } elseif ($script:repositoryByDerivation.ContainsKey($derivationHash)) {
            $stored = $script:repositoryByDerivation[$derivationHash]
            $script:repositoryByKey[$key] = [pscustomobject]@{
              RequestHash = $requestHash
              SourceArtifactId = $stored.SourceArtifactId
              SourceArtifactVersionId = $stored.SourceArtifactVersionId
              ContentSummaryId = $stored.ContentSummaryId
              ContentSummaryVersionId = $stored.ContentSummaryVersionId
            }
            $replayStatus = 'DerivationReplay'
          } else {
            $stored = [pscustomobject]@{
              RequestHash = $requestHash
              SourceArtifactId = $SourceArtifactId
              SourceArtifactVersionId = $SourceArtifactVersionId
              ContentSummaryId = $ContentSummaryId
              ContentSummaryVersionId = $ContentSummaryVersionId
            }
            $script:repositoryByKey[$key] = $stored
            $script:repositoryByDerivation[$derivationHash] = $stored
            $script:repositoryEffects++
            $replayStatus = 'Created'
          }

          $acknowledgement = [pscustomobject][ordered]@{
            ReplayStatus = $replayStatus
            IdempotencyKey = if ($script:repositoryMode -eq 'invalid-ack') { [guid]::Empty } else { $IdempotencyKey }
            SourceArtifactId = $stored.SourceArtifactId
            SourceArtifactVersionId = $stored.SourceArtifactVersionId
            ContentSummaryId = $stored.ContentSummaryId
            ContentSummaryVersionId = $stored.ContentSummaryVersionId
            SourceArtifactVersionSequence = 1
            ContentSummaryVersionSequence = 1
            LifecycleCode = $LifecycleCode
            ErrorCode = $null
          }
          if ($script:repositoryMode -eq 'cancel-after-commit') {
            $script:cancellationSource.Cancel()
          }
          $acknowledgement
        }
      }

      function New-HarvestTestArguments {
        $ruleVariantIds = @{
          'CS-R06-query-ranking-v1' = [guid]'a5600000-0000-0000-0000-000000000206'
          'CS-R02-content-normalization-v1' = [guid]'a5600000-0000-0000-0000-000000000202'
          'CS-R04-summary-render-v1' = [guid]'a5600000-0000-0000-0000-000000000204'
          'CS-R01-source-identity-v1' = [guid]'a5600000-0000-0000-0000-000000000201'
          'CS-R05-freshness-v1' = [guid]'a5600000-0000-0000-0000-000000000205'
          'CS-R03-classification-redaction-v1' = [guid]'a5600000-0000-0000-0000-000000000203'
        }
        $generator = [pscustomobject][ordered]@{
          modelRevision = '2026-09-04'
          modelId = 'fixture-model'
          kind = 'local'
          name = 'fixture-generator'
          modelProvider = 'fixture'
          version = '1.0.0'
          modelEffort = 'none'
        }
        $dependencies = @(
          [pscustomobject][ordered]@{
            ExternalReferenceSha256 = ('ab' * 32)
            EvidenceEntityId = [guid]'22222222-2222-2222-2222-222222222202'
            DependencyKindCode = 'external'
            SourceArtifactVersionId = $null
            DependencyOrdinal = 1
            ExternalReferenceKindCode = 'package'
          },
          [pscustomobject][ordered]@{
            ExternalReferenceKindCode = $null
            SourceArtifactVersionId = [guid]'22222222-2222-2222-2222-222222222201'
            EvidenceEntityId = [guid]'22222222-2222-2222-2222-222222222203'
            ExternalReferenceSha256 = $null
            DependencyOrdinal = 0
            DependencyKindCode = 'source-artifact-version'
          }
        )

        @{
          SourceBytes = [System.Text.UTF8Encoding]::new($false).GetBytes("alpha`r`nbeta`r`n")
          EncodingCode = 'utf-8'
          RunId = [guid]'30000000-0000-0000-0000-000000000001'
          IdempotencyKey = [guid]'30000000-0000-0000-0000-000000000002'
          RepositoryId = [guid]'30000000-0000-0000-0000-000000000003'
          RootRegistrationId = [guid]'30000000-0000-0000-0000-000000000004'
          SourceArtifactId = [guid]'30000000-0000-0000-0000-000000000005'
          SourceArtifactVersionId = [guid]'30000000-0000-0000-0000-000000000006'
          ContentSummaryId = [guid]'30000000-0000-0000-0000-000000000007'
          ContentSummaryVersionId = [guid]'30000000-0000-0000-0000-000000000008'
          RepoRelativePath = 'src/example.ps1'
          ObservedAtUtc = [datetimeoffset]::Parse('2026-09-04T12:34:56.1234567Z')
          RecordedAtUtc = [datetimeoffset]::Parse('2026-09-04T12:35:00.0000000Z')
          HarvesterEntityId = [guid]'30000000-0000-0000-0000-000000000009'
          SummaryProfileCode = 'default'
          ClassificationPolicyId = [guid]'30000000-0000-0000-0000-000000000010'
          RuleVariantIds = $ruleVariantIds
          InstantiationId = [guid]'a5600000-0000-0000-0000-000000000005'
          PromptRuleVariantId = [guid]'30000000-0000-0000-0000-000000000012'
          Generator = $generator
          Dependencies = $dependencies
          SummaryGenerator = {
            param($SafeContent, $Context, $CancellationToken)
            $CancellationToken.ThrowIfCancellationRequested()
            $script:generatorCalls++
            $script:lastSafeContent = $SafeContent
            $script:lastGeneratorContext = $Context
            [pscustomobject]@{ SafeSummaryText = 'deterministic safe summary'; SafeLocator = $null }
          }
          RepositoryAdapter = New-TestRepositoryAdapter
          Confirm = $false
        }
      }
    }

    BeforeEach {
      Mock -CommandName Write-PSFMessage
      $script:repositoryCalls = 0
      $script:repositoryEffects = 0
      $script:repositoryByKey = @{}
      $script:repositoryByDerivation = @{}
      $script:repositoryMode = 'normal'
      $script:cancellationSource = $null
      $script:lastLoaderArguments = $null
      $script:generatorCalls = 0
      $script:lastSafeContent = $null
      $script:lastGeneratorContext = $null
      $script:arguments = New-HarvestTestArguments
    }

    It 'binds exactly the final 48-parameter loader signature and six-column dependency TVP' {
      $result = Invoke-ContentSummaryHarvest @script:arguments

      $result.status | Should -BeExactly 'ok'
      $result.outcome | Should -BeExactly 'created'
      $result.freshnessCode | Should -BeExactly 'unknown'
      $script:lastLoaderArguments.Count | Should -Be 48
      @($script:lastLoaderArguments.Keys)[41] | Should -BeExactly 'WasRedacted'
      @($script:lastLoaderArguments.Keys)[42] | Should -BeExactly 'RedactionEvidenceId'
      @($script:lastLoaderArguments.Keys)[47] | Should -BeExactly 'Dependencies'
      $script:lastLoaderArguments.Contains('SourceBytes') | Should -BeFalse
      $script:lastLoaderArguments.CanonicalRequestSha256.GetType().FullName | Should -BeExactly 'System.Byte[]'
      $script:lastLoaderArguments.CanonicalRequestSha256.Count | Should -Be 32
      $script:lastLoaderArguments.DerivationFingerprint.Count | Should -Be 32
      @($script:lastLoaderArguments.Dependencies).Count | Should -Be 2
      ($script:lastLoaderArguments.Dependencies[0].PSObject.Properties.Name -join ',') |
        Should -BeExactly 'DependencyOrdinal,DependencyKindCode,SourceArtifactVersionId,ExternalReferenceKindCode,ExternalReferenceSha256,EvidenceEntityId'
      $script:lastLoaderArguments.Dependencies[0].DependencyOrdinal | Should -Be 0
      $script:lastLoaderArguments.Dependencies[1].DependencyOrdinal | Should -Be 1
    }

    It 'produces the same canonical and derivation hashes for reordered equivalent inputs' {
      $first = Invoke-ContentSummaryHarvest @script:arguments
      $reordered = @{} + $script:arguments
      $reordered.RuleVariantIds = [pscustomobject][ordered]@{
        'CS-R03-classification-redaction-v1' = [guid]'a5600000-0000-0000-0000-000000000203'
        'CS-R05-freshness-v1' = [guid]'a5600000-0000-0000-0000-000000000205'
        'CS-R01-source-identity-v1' = [guid]'a5600000-0000-0000-0000-000000000201'
        'CS-R04-summary-render-v1' = [guid]'a5600000-0000-0000-0000-000000000204'
        'CS-R02-content-normalization-v1' = [guid]'a5600000-0000-0000-0000-000000000202'
        'CS-R06-query-ranking-v1' = [guid]'a5600000-0000-0000-0000-000000000206'
      }
      $reordered.Generator = [pscustomobject]@{
        kind = 'local'
        modelEffort = 'none'
        modelRevision = '2026-09-04'
        version = '1.0.0'
        modelProvider = 'fixture'
        name = 'fixture-generator'
        modelId = 'fixture-model'
      }
      $reordered.Dependencies = @($script:arguments.Dependencies[1], $script:arguments.Dependencies[0])

      $second = Invoke-ContentSummaryHarvest @reordered

      $second.replayStatus | Should -BeExactly 'Replayed'
      $second.canonicalRequestHash | Should -BeExactly $first.canonicalRequestHash
      $second.derivationFingerprint | Should -BeExactly $first.derivationFingerprint
      $script:repositoryEffects | Should -Be 1
    }

    It 'normalizes LF and CRLF to one normalized content hash while exact byte hashes differ' {
      $lf = Get-ContentSummarySourceObservation -SourceBytes ([System.Text.UTF8Encoding]::new($false).GetBytes("a`nb`n")) -EncodingCode utf-8
      $crlf = Get-ContentSummarySourceObservation -SourceBytes ([System.Text.UTF8Encoding]::new($false).GetBytes("a`r`nb`r`n")) -EncodingCode utf-8

      $lf.ByteSha256 | Should -Not -BeExactly $crlf.ByteSha256
      $lf.NormalizedContentSha256 | Should -BeExactly $crlf.NormalizedContentSha256
      $lf.LineEndingCode | Should -BeExactly 'lf'
      $crlf.LineEndingCode | Should -BeExactly 'crlf'
      $lf.FinalNewline | Should -BeTrue
      $crlf.FinalNewline | Should -BeTrue
    }

    It 'canonicalizes an empty dependency set as an empty array' {
      $script:arguments.Dependencies = @()

      $result = Invoke-ContentSummaryHarvest @script:arguments

      $result.status | Should -BeExactly 'ok'
      @($script:lastLoaderArguments.Dependencies).Count | Should -Be 0
      $result.canonicalRequestHash | Should -Match '^[0-9a-f]{64}$'
      $result.derivationFingerprint | Should -Match '^[0-9a-f]{64}$'
    }

    It 'redacts secret and PII-like input before generator and repository boundaries' {
      $secretText = 'password=hunter2 email jane@example.com SSN 123-45-6789 ATAP_SECRET_CANARY_ABCD'
      $script:arguments.SourceBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($secretText)
      $script:arguments.RedactionEvidenceId = [guid]'40000000-0000-0000-0000-000000000001'
      $script:arguments.SummaryGenerator = {
        param($SafeContent, $Context, $CancellationToken)
        $script:generatorCalls++
        $script:lastSafeContent = $SafeContent
        [pscustomobject]@{ SafeSummaryText = "safe summary: $SafeContent"; SafeLocator = $null }
      }

      $result = Invoke-ContentSummaryHarvest @script:arguments
      $serializedBoundary = $script:lastLoaderArguments | ConvertTo-Json -Depth 20 -Compress
      $serializedResult = $result | ConvertTo-Json -Depth 20 -Compress

      $result.status | Should -BeExactly 'ok'
      $result.classificationCode | Should -BeExactly 'redacted'
      $script:lastLoaderArguments.WasRedacted | Should -BeTrue
      $script:lastLoaderArguments.RedactionEvidenceId | Should -Be ([guid]'40000000-0000-0000-0000-000000000001')
      $script:lastSafeContent | Should -Match '\[REDACTED:'
      $script:lastSafeContent | Should -Not -Match 'hunter2|jane@example.com|123-45-6789|ATAP_SECRET_CANARY_ABCD'
      $serializedBoundary | Should -Not -Match 'hunter2|jane@example.com|123-45-6789|ATAP_SECRET_CANARY_ABCD'
      $serializedResult | Should -Not -Match 'hunter2|jane@example.com|123-45-6789|ATAP_SECRET_CANARY_ABCD'
    }

    It 'fails closed before generator and repository when redaction verification fails' {
      $script:arguments.SourceBytes = [System.Text.UTF8Encoding]::new($false).GetBytes('token=super-secret-value')
      $script:arguments.RedactionEvidenceId = [guid]'40000000-0000-0000-0000-000000000002'
      $script:arguments.Redactor = {
        param($Text, $CancellationToken)
        [pscustomobject]@{ Text = $Text; Count = 0 }
      }

      $result = Invoke-ContentSummaryHarvest @script:arguments

      $result.status | Should -BeExactly 'Error'
      $result.error.code | Should -BeExactly 'CS-CLASS-002'
      $result.error.diagnosticHash | Should -Match '^[0-9a-f]{64}$'
      $script:generatorCalls | Should -Be 0
      $script:repositoryCalls | Should -Be 0
      ($result | ConvertTo-Json -Depth 10 -Compress) | Should -Not -Match 'super-secret-value'
    }

    It 'rejects a redactor that silently deletes all nonempty content' {
      $script:arguments.RedactionEvidenceId = [guid]'40000000-0000-0000-0000-000000000004'
      $script:arguments.Redactor = {
        param($Text, $CancellationToken)
        [pscustomobject]@{ Text = ''; Count = 1 }
      }

      $result = Invoke-ContentSummaryHarvest @script:arguments

      $result.status | Should -BeExactly 'Error'
      $result.error.code | Should -BeExactly 'CS-CLASS-002'
      $script:generatorCalls | Should -Be 0
      $script:repositoryCalls | Should -Be 0
    }

    It 'records unsupported source as excluded without model invocation or source content' {
      $script:arguments.RepoRelativePath = 'assets/image.png'
      $script:arguments.SourceBytes = [byte[]](1, 2, 3, 4)
      $script:arguments.EncodingCode = 'us-ascii'
      $script:arguments.ExclusionEvidenceId = [guid]'40000000-0000-0000-0000-000000000003'

      $result = Invoke-ContentSummaryHarvest @script:arguments

      $result.status | Should -BeExactly 'Excluded'
      $result.classificationCode | Should -BeExactly 'excluded'
      $script:generatorCalls | Should -Be 0
      $script:repositoryCalls | Should -Be 1
      $script:lastLoaderArguments.LifecycleCode | Should -BeExactly 'excluded'
      $script:lastLoaderArguments.SafeSummaryText | Should -BeNullOrEmpty
      $script:lastLoaderArguments.SafeLocator | Should -BeNullOrEmpty
      $script:lastLoaderArguments.ExclusionEvidenceId | Should -Be ([guid]'40000000-0000-0000-0000-000000000003')
    }

    It 'returns the existing result on exact idempotent replay with one durable effect' {
      $first = Invoke-ContentSummaryHarvest @script:arguments
      $second = Invoke-ContentSummaryHarvest @script:arguments

      $first.replayStatus | Should -BeExactly 'Created'
      $second.replayStatus | Should -BeExactly 'Replayed'
      $second.repositoryResult.ContentSummaryVersionId | Should -Be $first.repositoryResult.ContentSummaryVersionId
      $script:repositoryCalls | Should -Be 2
      $script:repositoryEffects | Should -Be 1
    }

    It 'maps same idempotency key with a different canonical hash to CS-IDEMP-001 without a second effect' {
      Invoke-ContentSummaryHarvest @script:arguments | Out-Null
      $conflict = @{} + $script:arguments
      $conflict.SourceBytes = [System.Text.UTF8Encoding]::new($false).GetBytes('different source content')

      $result = Invoke-ContentSummaryHarvest @conflict

      $result.status | Should -BeExactly 'Error'
      $result.outcome | Should -BeExactly 'conflict'
      $result.error.code | Should -BeExactly 'CS-IDEMP-001'
      $script:repositoryEffects | Should -Be 1
      $result.repositoryResult | Should -BeNullOrEmpty
    }

    It 'returns DerivationReplay for a new request identity with the same derivation' {
      $first = Invoke-ContentSummaryHarvest @script:arguments
      $replay = @{} + $script:arguments
      $replay.RunId = [guid]'30000000-0000-0000-0000-000000000101'
      $replay.IdempotencyKey = [guid]'30000000-0000-0000-0000-000000000102'

      $second = Invoke-ContentSummaryHarvest @replay

      $first.replayStatus | Should -BeExactly 'Created'
      $second.replayStatus | Should -BeExactly 'DerivationReplay'
      $second.derivationFingerprint | Should -BeExactly $first.derivationFingerprint
      $second.canonicalRequestHash | Should -Not -BeExactly $first.canonicalRequestHash
      $script:repositoryEffects | Should -Be 1
    }

    It 'returns controlled cancellation without generator repository or partial result' {
      $cancellation = [System.Threading.CancellationTokenSource]::new()
      $cancellation.Cancel()
      $script:arguments.CancellationToken = $cancellation.Token

      $result = Invoke-ContentSummaryHarvest @script:arguments

      $result.status | Should -BeExactly 'Cancelled'
      $result.error.code | Should -BeExactly 'CS-HARVEST-001'
      $result.error.retryable | Should -BeTrue
      $result.repositoryResult | Should -BeNullOrEmpty
      $script:generatorCalls | Should -Be 0
      $script:repositoryCalls | Should -Be 0
    }

    It 'maps repository exceptions to a secret-safe internal error without fabricated output' {
      $script:arguments.RepositoryAdapter = {
        param(
          $IdempotencyKey, $CanonicalRequestSha256, $RunId, $RepositoryId,
          $RootRegistrationId, $RepoRelativePath, $SourceArtifactId,
          $SourceArtifactVersionId, $ContentSummaryId, $ContentSummaryVersionId,
          $PriorContentSummaryVersionId, $ObservedAtUtc, $RecordedAtUtc, $ByteSha256,
          $NormalizedContentSha256, $ByteCount, $EncodingCode, $HasBom,
          $LineEndingCode, $FinalNewline, $HarvesterEntityId, $SummaryProfileCode,
          $ClassificationPolicyId, $SourceIdentityRuleVariantId,
          $NormalizationRuleVariantId, $ClassificationRuleVariantId,
          $SummaryRenderRuleVariantId, $FreshnessRuleVariantId,
          $QueryRankingRuleVariantId, $InstantiationId, $PromptRuleVariantId,
          $GeneratorKindCode, $GeneratorName, $GeneratorVersion, $ModelProvider,
          $ModelId, $ModelRevision, $ModelEffort, $LifecycleCode, $SafeSummaryText,
          $SafeLocator, $WasRedacted, $RedactionEvidenceId, $SummaryContentSha256,
          $ExclusionEvidenceId, $LifecycleReasonCode, $DerivationFingerprint,
          $Dependencies
        )
        $script:repositoryCalls++
        throw 'database secret password=hunter2'
      }

      $result = Invoke-ContentSummaryHarvest @script:arguments
      $serialized = $result | ConvertTo-Json -Depth 10 -Compress

      $result.status | Should -BeExactly 'Error'
      $result.error.code | Should -BeExactly 'CS-INTERNAL-001'
      $result.repositoryResult | Should -BeNullOrEmpty
      $serialized | Should -Not -Match 'hunter2|database secret'
      $script:repositoryCalls | Should -Be 1
    }

    It 'rejects an invalid repository acknowledgement without fabricating a result' {
      $script:repositoryMode = 'invalid-ack'

      $result = Invoke-ContentSummaryHarvest @script:arguments

      $result.status | Should -BeExactly 'Error'
      $result.error.code | Should -BeExactly 'CS-INTERNAL-001'
      $result.repositoryInvoked | Should -BeTrue
      $result.repositoryResult | Should -BeNullOrEmpty
    }

    It 'returns the committed acknowledgement when cancellation arrives after repository commit' {
      $script:cancellationSource = [System.Threading.CancellationTokenSource]::new()
      $script:repositoryMode = 'cancel-after-commit'
      $script:arguments.CancellationToken = $script:cancellationSource.Token

      $result = Invoke-ContentSummaryHarvest @script:arguments

      $script:cancellationSource.IsCancellationRequested | Should -BeTrue
      $result.status | Should -BeExactly 'ok'
      $result.replayStatus | Should -BeExactly 'Created'
      $result.repositoryResult | Should -Not -BeNullOrEmpty
      $script:repositoryEffects | Should -Be 1
    }

    It 'does not fabricate or persist a summary when the generator returns no result' {
      $script:arguments.SummaryGenerator = {
        param($SafeContent, $Context, $CancellationToken)
        $script:generatorCalls++
        $null
      }

      $result = Invoke-ContentSummaryHarvest @script:arguments

      $result.status | Should -BeExactly 'Error'
      $result.error.code | Should -BeExactly 'CS-SUMMARY-001'
      $result.summaryContentSha256 | Should -BeNullOrEmpty
      $result.repositoryResult | Should -BeNullOrEmpty
      $script:generatorCalls | Should -Be 1
      $script:repositoryCalls | Should -Be 0
    }

    It 'rejects secret-shaped generator output instead of persisting or redacting it silently' {
      $script:arguments.SummaryGenerator = {
        param($SafeContent, $Context, $CancellationToken)
        $script:generatorCalls++
        [pscustomobject]@{ SafeSummaryText = 'token=generator-secret-value'; SafeLocator = $null }
      }

      $result = Invoke-ContentSummaryHarvest @script:arguments

      $result.status | Should -BeExactly 'Error'
      $result.error.code | Should -BeExactly 'CS-CLASS-002'
      $result.summaryContentSha256 | Should -BeNullOrEmpty
      $script:repositoryCalls | Should -Be 0
      ($result | ConvertTo-Json -Depth 10 -Compress) | Should -Not -Match 'generator-secret-value'
    }

    It 'fails closed on a supplied byte hash mismatch before model or repository use' {
      $script:arguments.ExpectedByteSha256 = ('00' * 32)

      $result = Invoke-ContentSummaryHarvest @script:arguments

      $result.status | Should -BeExactly 'Error'
      $result.error.code | Should -BeExactly 'CS-HASH-001'
      $script:generatorCalls | Should -Be 0
      $script:repositoryCalls | Should -Be 0
    }

    It 'does not invoke generator or repository under WhatIf' {
      $script:arguments.WhatIf = $true

      $result = Invoke-ContentSummaryHarvest @script:arguments

      $result.status | Should -BeExactly 'WhatIf'
      $script:generatorCalls | Should -Be 0
      $script:repositoryCalls | Should -Be 0
    }
}

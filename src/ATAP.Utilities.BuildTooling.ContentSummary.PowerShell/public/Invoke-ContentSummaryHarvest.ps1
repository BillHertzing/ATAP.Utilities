function Invoke-ContentSummaryHarvest {
  <#
  .SYNOPSIS
    Classifies, redacts, summarizes, and captures one ContentSummary observation.

  .DESCRIPTION
    Implements the Task 15.60.c local harvester boundary. Exact source bytes are decoded
    and hashed locally. Classification, redaction, and a post-redaction secret scan run
    before the supplied summary generator can receive content. The resulting safe,
    canonical harvest envelope is submitted through a repository adapter whose named
    arguments exactly match ATAPUtilities.CaptureContentSummaryObservationV1.

    No raw source bytes or unredacted text are passed to the generator or repository.
    Empty generator output, redaction failure, cancellation, malformed repository output,
    and repository exceptions fail closed without a fabricated result.

  .PARAMETER SourceBytes
    Exact source bytes observed locally.

  .PARAMETER EncodingCode
    Controlled encoding used to decode SourceBytes.

  .PARAMETER RepoRelativePath
    Canonical forward-slash repository-relative source path.

  .PARAMETER RuleVariantIds
    Object containing exactly the six frozen CS-R01 through CS-R06 RuleVariant GUIDs.

  .PARAMETER Generator
    Object containing exactly kind, name, version, modelProvider, modelId, modelRevision,
    and modelEffort controlled identity fields.

  .PARAMETER Dependencies
    Rows matching the frozen ContentSummaryDependencyInput TVP.

  .PARAMETER SummaryGenerator
    Injectable generator seam. It receives only SafeContent, Context, and
    CancellationToken named arguments.

  .PARAMETER RepositoryAdapter
    Injectable repository seam. It receives exactly the final 48 named loader
    parameters, including the six-column Dependencies value.

  .PARAMETER Redactor
    Optional injectable redaction seam. Omit it to use the deterministic built-in
    fail-closed redactor.

  .OUTPUTS
    PSCustomObject with stable status, hashes, replay state, safe identifiers, and error.
    Source and summary text are never returned.

  .EXAMPLE
    Invoke-ContentSummaryHarvest @harvestArguments

    Prepares and captures one observation through the supplied adapters.

  .NOTES
    Task 15.60.c Stream B. This source function is intentionally not added to the module
    manifest by this claim; manifest/version/package integration belongs to the
    coordinator.

  .LINK
    RPRRSBSI-V4-2-25-ContentSummary-Data-Contract.md
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyCollection()]
    [byte[]] $SourceBytes,

    [Parameter(Mandatory = $true)]
    [ValidateSet('utf-8', 'utf-8-bom', 'us-ascii', 'utf-16le', 'utf-16be')]
    [string] $EncodingCode,

    [Parameter(Mandatory = $true)]
    [guid] $RunId,

    [Parameter(Mandatory = $true)]
    [guid] $IdempotencyKey,

    [Parameter(Mandatory = $true)]
    [guid] $RepositoryId,

    [Parameter(Mandatory = $true)]
    [guid] $RootRegistrationId,

    [Parameter(Mandatory = $true)]
    [guid] $SourceArtifactId,

    [Parameter(Mandatory = $true)]
    [guid] $SourceArtifactVersionId,

    [Parameter(Mandatory = $true)]
    [guid] $ContentSummaryId,

    [Parameter(Mandatory = $true)]
    [guid] $ContentSummaryVersionId,

    [AllowNull()]
    [Nullable[guid]] $PriorContentSummaryVersionId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 1024)]
    [string] $RepoRelativePath,

    [Parameter(Mandatory = $true)]
    [datetimeoffset] $ObservedAtUtc,

    [Parameter(Mandatory = $true)]
    [datetimeoffset] $RecordedAtUtc,

    [Parameter(Mandatory = $true)]
    [guid] $HarvesterEntityId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9.-]{0,63}$')]
    [string] $SummaryProfileCode,

    [Parameter(Mandatory = $true)]
    [guid] $ClassificationPolicyId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [object] $RuleVariantIds,

    [Parameter(Mandatory = $true)]
    [guid] $InstantiationId,

    [Parameter(Mandatory = $true)]
    [guid] $PromptRuleVariantId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [object] $Generator,

    [AllowEmptyCollection()]
    [object[]] $Dependencies = @(),

    [AllowNull()]
    [Nullable[guid]] $RedactionEvidenceId,

    [AllowNull()]
    [Nullable[guid]] $ExclusionEvidenceId,

    [ValidatePattern('^[0-9a-f]{64}$')]
    [string] $ExpectedByteSha256,

    [ValidatePattern('^[0-9a-f]{64}$')]
    [string] $ExpectedNormalizedContentSha256,

    [Parameter(Mandatory = $true)]
    [scriptblock] $SummaryGenerator,

    [Parameter(Mandatory = $true)]
    [scriptblock] $RepositoryAdapter,

    [scriptblock] $Redactor,

    [System.Threading.CancellationToken] $CancellationToken = [System.Threading.CancellationToken]::None
  )

  begin {
    $fn = 'Invoke-ContentSummaryHarvest'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'

    $loaderParameterOrder = @(
      'IdempotencyKey', 'CanonicalRequestSha256', 'RunId', 'RepositoryId',
      'RootRegistrationId', 'RepoRelativePath', 'SourceArtifactId',
      'SourceArtifactVersionId', 'ContentSummaryId', 'ContentSummaryVersionId',
      'PriorContentSummaryVersionId', 'ObservedAtUtc', 'RecordedAtUtc', 'ByteSha256',
      'NormalizedContentSha256', 'ByteCount', 'EncodingCode', 'HasBom',
      'LineEndingCode', 'FinalNewline', 'HarvesterEntityId', 'SummaryProfileCode',
      'ClassificationPolicyId', 'SourceIdentityRuleVariantId',
      'NormalizationRuleVariantId', 'ClassificationRuleVariantId',
      'SummaryRenderRuleVariantId', 'FreshnessRuleVariantId',
      'QueryRankingRuleVariantId', 'InstantiationId', 'PromptRuleVariantId',
      'GeneratorKindCode', 'GeneratorName', 'GeneratorVersion', 'ModelProvider',
      'ModelId', 'ModelRevision', 'ModelEffort', 'LifecycleCode', 'SafeSummaryText',
      'SafeLocator', 'WasRedacted', 'RedactionEvidenceId', 'SummaryContentSha256',
      'ExclusionEvidenceId', 'LifecycleReasonCode', 'DerivationFingerprint',
      'Dependencies'
    )
    $repositoryResultOrder = @(
      'ReplayStatus', 'IdempotencyKey', 'SourceArtifactId', 'SourceArtifactVersionId',
      'ContentSummaryId', 'ContentSummaryVersionId', 'SourceArtifactVersionSequence',
      'ContentSummaryVersionSequence', 'LifecycleCode', 'ErrorCode'
    )
  }

  process {
    $modelInvoked = $false
    $repositoryInvoked = $false
    $observation = $null
    $classification = $null
    $canonical = $null
    $hasPriorContentSummaryVersion = $null -ne $PriorContentSummaryVersionId -and [guid]$PriorContentSummaryVersionId -ne [guid]::Empty
    $hasRedactionEvidence = $null -ne $RedactionEvidenceId -and [guid]$RedactionEvidenceId -ne [guid]::Empty
    $hasExclusionEvidence = $null -ne $ExclusionEvidenceId -and [guid]$ExclusionEvidenceId -ne [guid]::Empty

    try {
      foreach ($loaderIdentity in @(
          $SourceArtifactId, $SourceArtifactVersionId, $ContentSummaryId,
          $ContentSummaryVersionId
        )) {
        if ($loaderIdentity -eq [guid]::Empty) {
          throw [System.ArgumentException]::new('CS-REQ-001: loader identities must be non-empty GUIDs.')
        }
      }
      if ($RecordedAtUtc.Offset -ne [timespan]::Zero -or $RecordedAtUtc -lt $ObservedAtUtc) {
        throw [System.ArgumentException]::new('CS-REQ-001: recordedAtUtc must be UTC and not precede observedAtUtc.')
      }
      $CancellationToken.ThrowIfCancellationRequested()
      $observationArguments = @{
        SourceBytes = $SourceBytes
        EncodingCode = $EncodingCode
        CancellationToken = $CancellationToken
      }
      if ($ExpectedByteSha256) {
        $observationArguments.ExpectedByteSha256 = $ExpectedByteSha256
      }
      if ($ExpectedNormalizedContentSha256) {
        $observationArguments.ExpectedNormalizedContentSha256 = $ExpectedNormalizedContentSha256
      }
      $observation = Get-ContentSummarySourceObservation @observationArguments

      $classificationArguments = @{
        Text = $observation.NormalizedText
        RepoRelativePath = $RepoRelativePath
        CancellationToken = $CancellationToken
      }
      if ($null -ne $Redactor) {
        $classificationArguments.Redactor = $Redactor
      }
      $classification = Protect-ContentSummaryText @classificationArguments
      if ($classification.Status -eq 'Error') {
        return [pscustomobject][ordered]@{
          schemaVersion = 1
          status = 'Error'
          outcome = 'rejected'
          classificationCode = $null
          modelInvoked = $false
          repositoryInvoked = $false
          replayStatus = $null
          freshnessCode = 'unknown'
          canonicalRequestHash = $null
          byteSha256 = $observation.ByteSha256
          normalizedContentSha256 = $observation.NormalizedContentSha256
          summaryContentSha256 = $null
          derivationFingerprint = $null
          repositoryResult = $null
          error = ConvertTo-ContentSummaryHarvestError -Code $classification.ErrorCode -Message $classification.ErrorMessage -ReasonCode $classification.EvidenceCodes[0]
        }
      }

      $safeSummaryText = $null
      $safeLocator = $null
      $lifecycleCode = 'excluded'
      $lifecycleReasonCode = 'classification.unsupported-source'
      $wasRedacted = $false

      if ($classification.Status -eq 'Excluded') {
        if (-not $hasExclusionEvidence) {
          return [pscustomobject][ordered]@{
            schemaVersion = 1
            status = 'Error'
            outcome = 'rejected'
            classificationCode = 'excluded'
            modelInvoked = $false
            repositoryInvoked = $false
            replayStatus = $null
            freshnessCode = 'excluded'
            canonicalRequestHash = $null
            byteSha256 = $observation.ByteSha256
            normalizedContentSha256 = $observation.NormalizedContentSha256
            summaryContentSha256 = $null
            derivationFingerprint = $null
            repositoryResult = $null
            error = ConvertTo-ContentSummaryHarvestError -Code 'CS-REQ-001' -Message 'Excluded content requires an evidence identity.' -ReasonCode 'classification.exclusion-evidence-missing'
          }
        }
      } else {
        $wasRedacted = $classification.ClassificationCode -eq 'redacted'
        if ($wasRedacted -and -not $hasRedactionEvidence) {
          return [pscustomobject][ordered]@{
            schemaVersion = 1
            status = 'Error'
            outcome = 'rejected'
            classificationCode = 'redacted'
            modelInvoked = $false
            repositoryInvoked = $false
            replayStatus = $null
            freshnessCode = 'unknown'
            canonicalRequestHash = $null
            byteSha256 = $observation.ByteSha256
            normalizedContentSha256 = $observation.NormalizedContentSha256
            summaryContentSha256 = $null
            derivationFingerprint = $null
            repositoryResult = $null
            error = ConvertTo-ContentSummaryHarvestError -Code 'CS-REQ-001' -Message 'Redacted content requires an evidence identity.' -ReasonCode 'classification.redaction-evidence-missing'
          }
        }
        if (-not $wasRedacted -and $hasRedactionEvidence) {
          return [pscustomobject][ordered]@{
            schemaVersion = 1
            status = 'Error'
            outcome = 'rejected'
            classificationCode = 'admitted'
            modelInvoked = $false
            repositoryInvoked = $false
            replayStatus = $null
            freshnessCode = 'unknown'
            canonicalRequestHash = $null
            byteSha256 = $observation.ByteSha256
            normalizedContentSha256 = $observation.NormalizedContentSha256
            summaryContentSha256 = $null
            derivationFingerprint = $null
            repositoryResult = $null
            error = ConvertTo-ContentSummaryHarvestError -Code 'CS-REQ-001' -Message 'Unredacted content cannot carry redaction evidence.' -ReasonCode 'classification.unexpected-redaction-evidence'
          }
        }

        if (-not $PSCmdlet.ShouldProcess($RepoRelativePath, 'Generate and capture ContentSummary')) {
          return [pscustomobject][ordered]@{
            schemaVersion = 1
            status = 'WhatIf'
            outcome = 'not-run'
            classificationCode = $classification.ClassificationCode
            modelInvoked = $false
            repositoryInvoked = $false
            replayStatus = $null
            freshnessCode = 'unknown'
            canonicalRequestHash = $null
            byteSha256 = $observation.ByteSha256
            normalizedContentSha256 = $observation.NormalizedContentSha256
            summaryContentSha256 = $null
            derivationFingerprint = $null
            repositoryResult = $null
            error = $null
          }
        }

        $generatorContext = [pscustomobject][ordered]@{
          repositoryId = $RepositoryId.ToString('D').ToLowerInvariant()
          repoRelativePath = $RepoRelativePath
          sourceArtifactVersionId = $SourceArtifactVersionId.ToString('D').ToLowerInvariant()
          byteSha256 = $observation.ByteSha256
          normalizedContentSha256 = $observation.NormalizedContentSha256
          classificationCode = $classification.ClassificationCode
        }
        $modelInvoked = $true
        $generated = & $SummaryGenerator -SafeContent $classification.SafeText -Context $generatorContext -CancellationToken $CancellationToken
        $CancellationToken.ThrowIfCancellationRequested()
        if ($null -eq $generated) {
          throw [System.InvalidOperationException]::new('CS-SUMMARY-001: generator returned no complete result.')
        }
        if ($generated -is [string]) {
          $safeSummaryText = [string]$generated
        } else {
          if ($null -ne $generated.PSObject.Properties['SafeSummaryText'] -and $null -ne $generated.SafeSummaryText) {
            $safeSummaryText = [string]$generated.SafeSummaryText
          }
          if ($null -ne $generated.PSObject.Properties['SafeLocator'] -and $null -ne $generated.SafeLocator) {
            $safeLocator = [string]$generated.SafeLocator
          }
        }
        $hasSafeSummary = -not [string]::IsNullOrWhiteSpace($safeSummaryText)
        $hasSafeLocator = -not [string]::IsNullOrWhiteSpace($safeLocator)
        if ($hasSafeSummary -eq $hasSafeLocator) {
          throw [System.InvalidOperationException]::new('CS-SUMMARY-001: generator must return exactly one complete safe output.')
        }
        if (-not $hasSafeSummary) { $safeSummaryText = $null }
        if (-not $hasSafeLocator) { $safeLocator = $null }
        if ($hasSafeLocator -and $safeLocator.Length -gt 2048) {
          throw [System.InvalidOperationException]::new('CS-REQ-001: safe locator exceeds the frozen loader limit.')
        }

        $generatedValue = if ($hasSafeSummary) { $safeSummaryText } else { $safeLocator }
        $identityRedactor = {
          param(
            [string] $Text,
            [System.Threading.CancellationToken] $CancellationToken
          )
          $CancellationToken.ThrowIfCancellationRequested()
          [pscustomobject]@{ Text = $Text; Count = 0 }
        }
        $generatedSafety = Protect-ContentSummaryText -Text $generatedValue -RepoRelativePath $RepoRelativePath -Redactor $identityRedactor -CancellationToken $CancellationToken
        if ($generatedSafety.Status -ne 'Ready') {
          throw [System.InvalidOperationException]::new('CS-CLASS-002: generated output failed secret verification.')
        }
        $lifecycleCode = 'summarized'
        $lifecycleReasonCode = if ($wasRedacted) { 'classification.redacted' } else { 'classification.admitted' }
      }

      $canonicalArguments = @{
        RunId = $RunId
        IdempotencyKey = $IdempotencyKey
        RepositoryId = $RepositoryId
        RootRegistrationId = $RootRegistrationId
        SourceArtifactVersionId = $SourceArtifactVersionId
        HarvesterEntityId = $HarvesterEntityId
        InstantiationId = $InstantiationId
        ClassificationPolicyId = $ClassificationPolicyId
        PromptRuleVariantId = $PromptRuleVariantId
        RepoRelativePath = $RepoRelativePath
        ObservedAtUtc = $ObservedAtUtc
        Observation = $observation
        RuleVariantIds = $RuleVariantIds
        Generator = $Generator
        Dependencies = $Dependencies
        SafeSummaryText = $safeSummaryText
        SafeLocator = $safeLocator
      }
      if ($lifecycleCode -eq 'excluded') {
        $canonicalArguments.AllowNoSafePayload = $true
      }
      $canonical = ConvertTo-ContentSummaryHarvestEnvelope @canonicalArguments
      $ruleIds = $canonical.HarvestEnvelope.ruleVariantIds
      $generatorIdentity = $canonical.HarvestEnvelope.generator

      $loaderArguments = [ordered]@{
        IdempotencyKey = $IdempotencyKey
        CanonicalRequestSha256 = [Convert]::FromHexString($canonical.CanonicalRequestHash)
        RunId = $RunId
        RepositoryId = $RepositoryId
        RootRegistrationId = $RootRegistrationId
        RepoRelativePath = $RepoRelativePath
        SourceArtifactId = $SourceArtifactId
        SourceArtifactVersionId = $SourceArtifactVersionId
        ContentSummaryId = $ContentSummaryId
        ContentSummaryVersionId = $ContentSummaryVersionId
        PriorContentSummaryVersionId = if ($hasPriorContentSummaryVersion) { [guid]$PriorContentSummaryVersionId } else { $null }
        ObservedAtUtc = $ObservedAtUtc
        RecordedAtUtc = $RecordedAtUtc
        ByteSha256 = [Convert]::FromHexString($observation.ByteSha256)
        NormalizedContentSha256 = [Convert]::FromHexString($observation.NormalizedContentSha256)
        ByteCount = [long]$observation.ByteCount
        EncodingCode = $observation.EncodingCode
        HasBom = [bool]$observation.BomExcluded
        LineEndingCode = $observation.LineEndingCode
        FinalNewline = [bool]$observation.FinalNewline
        HarvesterEntityId = $HarvesterEntityId
        SummaryProfileCode = $SummaryProfileCode
        ClassificationPolicyId = $ClassificationPolicyId
        SourceIdentityRuleVariantId = [guid]$ruleIds.'CS-R01-source-identity-v1'
        NormalizationRuleVariantId = [guid]$ruleIds.'CS-R02-content-normalization-v1'
        ClassificationRuleVariantId = [guid]$ruleIds.'CS-R03-classification-redaction-v1'
        SummaryRenderRuleVariantId = [guid]$ruleIds.'CS-R04-summary-render-v1'
        FreshnessRuleVariantId = [guid]$ruleIds.'CS-R05-freshness-v1'
        QueryRankingRuleVariantId = [guid]$ruleIds.'CS-R06-query-ranking-v1'
        InstantiationId = $InstantiationId
        PromptRuleVariantId = $PromptRuleVariantId
        GeneratorKindCode = $generatorIdentity.kind
        GeneratorName = $generatorIdentity.name
        GeneratorVersion = $generatorIdentity.version
        ModelProvider = $generatorIdentity.modelProvider
        ModelId = $generatorIdentity.modelId
        ModelRevision = $generatorIdentity.modelRevision
        ModelEffort = $generatorIdentity.modelEffort
        LifecycleCode = $lifecycleCode
        SafeSummaryText = $safeSummaryText
        SafeLocator = $safeLocator
        WasRedacted = $wasRedacted
        RedactionEvidenceId = if ($wasRedacted) { [guid]$RedactionEvidenceId } else { $null }
        SummaryContentSha256 = if ($null -ne $canonical.SummaryContentSha256) { [Convert]::FromHexString($canonical.SummaryContentSha256) } else { $null }
        ExclusionEvidenceId = if ($lifecycleCode -eq 'excluded') { [guid]$ExclusionEvidenceId } else { $null }
        LifecycleReasonCode = $lifecycleReasonCode
        DerivationFingerprint = [Convert]::FromHexString($canonical.DerivationFingerprint)
        Dependencies = @($canonical.DependencyRows)
      }
      if ($loaderArguments.Count -ne 48 -or ($loaderArguments.Keys -join ',') -ne ($loaderParameterOrder -join ',')) {
        throw [System.InvalidOperationException]::new('CS-INTERNAL-001: repository adapter arguments do not match the frozen loader order.')
      }

      if ($lifecycleCode -eq 'excluded' -and -not $PSCmdlet.ShouldProcess($RepoRelativePath, 'Capture excluded ContentSummary observation')) {
        return [pscustomobject][ordered]@{
          schemaVersion = 1
          status = 'WhatIf'
          outcome = 'not-run'
          classificationCode = 'excluded'
          modelInvoked = $false
          repositoryInvoked = $false
          replayStatus = $null
          freshnessCode = 'excluded'
          canonicalRequestHash = $canonical.CanonicalRequestHash
          byteSha256 = $observation.ByteSha256
          normalizedContentSha256 = $observation.NormalizedContentSha256
          summaryContentSha256 = $null
          derivationFingerprint = $canonical.DerivationFingerprint
          repositoryResult = $null
          error = $null
        }
      }

      $CancellationToken.ThrowIfCancellationRequested()
      $repositoryInvoked = $true
      $repositoryResult = & $RepositoryAdapter @loaderArguments
      if ($null -eq $repositoryResult -or ($repositoryResult.PSObject.Properties.Name -join ',') -ne ($repositoryResultOrder -join ',')) {
        throw [System.InvalidOperationException]::new('CS-INTERNAL-001: repository adapter returned an invalid result shape.')
      }
      if ($repositoryResult.ReplayStatus -notin @('Created', 'Replayed', 'DerivationReplay')) {
        throw [System.InvalidOperationException]::new('CS-INTERNAL-001: repository adapter returned an unknown replay status.')
      }
      if ($null -ne $repositoryResult.ErrorCode -and -not [string]::IsNullOrWhiteSpace([string]$repositoryResult.ErrorCode)) {
        throw [System.InvalidOperationException]::new(([string]$repositoryResult.ErrorCode + ': repository rejected the harvest.'))
      }
      if (-not [string]::Equals([string]$repositoryResult.LifecycleCode, $lifecycleCode, [StringComparison]::Ordinal)) {
        throw [System.InvalidOperationException]::new('CS-INTERNAL-001: repository lifecycle does not match the submitted lifecycle.')
      }
      if ([guid]$repositoryResult.IdempotencyKey -ne $IdempotencyKey -or
        [guid]$repositoryResult.SourceArtifactId -eq [guid]::Empty -or
        [guid]$repositoryResult.SourceArtifactVersionId -eq [guid]::Empty -or
        [guid]$repositoryResult.ContentSummaryId -eq [guid]::Empty -or
        [guid]$repositoryResult.ContentSummaryVersionId -eq [guid]::Empty -or
        [long]$repositoryResult.SourceArtifactVersionSequence -lt 1 -or
        [long]$repositoryResult.ContentSummaryVersionSequence -lt 1) {
        throw [System.InvalidOperationException]::new('CS-INTERNAL-001: repository adapter returned invalid acknowledgement values.')
      }

      [pscustomobject][ordered]@{
        schemaVersion = 1
        status = if ($lifecycleCode -eq 'excluded') { 'Excluded' } else { 'ok' }
        outcome = ([string]$repositoryResult.ReplayStatus).ToLowerInvariant()
        classificationCode = $classification.ClassificationCode
        modelInvoked = $modelInvoked
        repositoryInvoked = $repositoryInvoked
        replayStatus = [string]$repositoryResult.ReplayStatus
        freshnessCode = if ($lifecycleCode -eq 'excluded') { 'excluded' } else { 'unknown' }
        canonicalRequestHash = $canonical.CanonicalRequestHash
        byteSha256 = $observation.ByteSha256
        normalizedContentSha256 = $observation.NormalizedContentSha256
        summaryContentSha256 = $canonical.SummaryContentSha256
        derivationFingerprint = $canonical.DerivationFingerprint
        repositoryResult = $repositoryResult
        error = $null
      }
    } catch [System.OperationCanceledException] {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'ContentSummary harvesting was cancelled.'
      [pscustomobject][ordered]@{
        schemaVersion = 1
        status = 'Cancelled'
        outcome = 'cancelled'
        classificationCode = if ($null -ne $classification) { $classification.ClassificationCode } else { $null }
        modelInvoked = $modelInvoked
        repositoryInvoked = $repositoryInvoked
        replayStatus = $null
        freshnessCode = 'unknown'
        canonicalRequestHash = if ($null -ne $canonical) { $canonical.CanonicalRequestHash } else { $null }
        byteSha256 = if ($null -ne $observation) { $observation.ByteSha256 } else { $null }
        normalizedContentSha256 = if ($null -ne $observation) { $observation.NormalizedContentSha256 } else { $null }
        summaryContentSha256 = $null
        derivationFingerprint = if ($null -ne $canonical) { $canonical.DerivationFingerprint } else { $null }
        repositoryResult = $null
        error = ConvertTo-ContentSummaryHarvestError -Code 'CS-HARVEST-001' -Message 'ContentSummary harvesting was cancelled.' -ReasonCode 'harvest.cancelled' -Retryable $true
      }
    } catch {
      $exceptionType = $_.Exception.GetType().FullName
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "ContentSummary harvesting failed with exception type $exceptionType."
      $matchedCode = [regex]::Match($_.Exception.Message, 'CS-[A-Z]+-[0-9]{3}').Value
      $code = if ([string]::IsNullOrWhiteSpace($matchedCode)) { 'CS-INTERNAL-001' } else { $matchedCode }
      $safeMessage = switch ($code) {
        'CS-REQ-001' { 'The harvest request is invalid.' }
        'CS-SRC-002' { 'The source locator is invalid.' }
        'CS-HASH-001' { 'The source hash does not match.' }
        'CS-IDEMP-001' { 'The idempotency key is already bound to different content.' }
        'CS-CLASS-002' { 'Classification or redaction verification failed.' }
        'CS-RULE-001' { 'The ContentSummary rule binding is invalid.' }
        'CS-HARVEST-001' { 'The source could not be harvested.' }
        'CS-SUMMARY-001' { 'The summary generator did not produce a complete result.' }
        default { 'The ContentSummary harvest failed.' }
      }
      $reasonCode = switch ($code) {
        'CS-IDEMP-001' { 'repository.idempotency-conflict' }
        'CS-SUMMARY-001' { 'summary.incomplete' }
        'CS-CLASS-002' { 'classification.verification-failed' }
        'CS-HASH-001' { 'source.hash-mismatch' }
        'CS-RULE-001' { 'rules.binding-invalid' }
        'CS-REQ-001' { 'request.invalid' }
        default { 'repository.or-harvest-failure' }
      }
      [pscustomobject][ordered]@{
        schemaVersion = 1
        status = 'Error'
        outcome = if ($code -eq 'CS-IDEMP-001') { 'conflict' } else { 'failed' }
        classificationCode = if ($null -ne $classification) { $classification.ClassificationCode } else { $null }
        modelInvoked = $modelInvoked
        repositoryInvoked = $repositoryInvoked
        replayStatus = $null
        freshnessCode = 'unknown'
        canonicalRequestHash = if ($null -ne $canonical) { $canonical.CanonicalRequestHash } else { $null }
        byteSha256 = if ($null -ne $observation) { $observation.ByteSha256 } else { $null }
        normalizedContentSha256 = if ($null -ne $observation) { $observation.NormalizedContentSha256 } else { $null }
        summaryContentSha256 = if ($null -ne $canonical) { $canonical.SummaryContentSha256 } else { $null }
        derivationFingerprint = if ($null -ne $canonical) { $canonical.DerivationFingerprint } else { $null }
        repositoryResult = $null
        error = ConvertTo-ContentSummaryHarvestError -Code $code -Message $safeMessage -ReasonCode $reasonCode -Retryable ($code -in @('CS-HARVEST-001', 'CS-SUMMARY-001'))
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}

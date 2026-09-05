function ConvertTo-ContentSummaryHarvestEnvelope {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [guid] $RunId,

    [Parameter(Mandatory = $true)]
    [guid] $IdempotencyKey,

    [Parameter(Mandatory = $true)]
    [guid] $RepositoryId,

    [Parameter(Mandatory = $true)]
    [guid] $RootRegistrationId,

    [Parameter(Mandatory = $true)]
    [guid] $SourceArtifactVersionId,

    [Parameter(Mandatory = $true)]
    [guid] $HarvesterEntityId,

    [Parameter(Mandatory = $true)]
    [guid] $InstantiationId,

    [Parameter(Mandatory = $true)]
    [guid] $ClassificationPolicyId,

    [Parameter(Mandatory = $true)]
    [guid] $PromptRuleVariantId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $RepoRelativePath,

    [Parameter(Mandatory = $true)]
    [datetimeoffset] $ObservedAtUtc,

    [Parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [object] $Observation,

    [Parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [object] $RuleVariantIds,

    [Parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [object] $Generator,

    [AllowEmptyCollection()]
    [object[]] $Dependencies = @(),

    [AllowNull()]
    [AllowEmptyString()]
    [string] $SafeSummaryText,

    [AllowNull()]
    [AllowEmptyString()]
    [string] $SafeLocator,

    [switch] $AllowNoSafePayload
  )

  begin {
    $fn = 'ConvertTo-ContentSummaryHarvestEnvelope'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'

    function Get-CanonicalMemberValue {
      param(
        [Parameter(Mandatory = $true)]
        [object] $InputObject,

        [Parameter(Mandatory = $true)]
        [string] $Name
      )

      if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
          return $InputObject[$Name]
        }
        return $null
      }
      $property = $InputObject.PSObject.Properties[$Name]
      if ($null -ne $property) {
        return $property.Value
      }
      return $null
    }

    function Get-CanonicalMemberNames {
      param([Parameter(Mandatory = $true)][object] $InputObject)

      if ($InputObject -is [System.Collections.IDictionary]) {
        return @($InputObject.Keys | ForEach-Object { [string]$_ })
      }
      return @($InputObject.PSObject.Properties.Name)
    }
  }

  process {
    foreach ($identity in @(
        $RunId, $IdempotencyKey, $RepositoryId, $RootRegistrationId,
        $SourceArtifactVersionId, $HarvesterEntityId, $InstantiationId,
        $ClassificationPolicyId, $PromptRuleVariantId
      )) {
      if ($identity -eq [guid]::Empty) {
        throw [System.ArgumentException]::new('CS-REQ-001: harvest identities must be non-empty canonical GUIDs.')
      }
    }
    if ($ObservedAtUtc.Offset -ne [timespan]::Zero) {
      throw [System.ArgumentException]::new('CS-REQ-001: observedAtUtc must be UTC.')
    }

    $ruleCodes = @(
      'CS-R01-source-identity-v1',
      'CS-R02-content-normalization-v1',
      'CS-R03-classification-redaction-v1',
      'CS-R04-summary-render-v1',
      'CS-R05-freshness-v1',
      'CS-R06-query-ranking-v1'
    )
    $providedRuleNames = @(Get-CanonicalMemberNames -InputObject $RuleVariantIds)
    if ($providedRuleNames.Count -ne $ruleCodes.Count -or @($providedRuleNames | Where-Object { $_ -notin $ruleCodes }).Count -gt 0) {
      throw [System.ArgumentException]::new('CS-RULE-001: ruleVariantIds must contain exactly CS-R01 through CS-R06.')
    }
    $canonicalRuleVariantIds = [ordered]@{}
    foreach ($ruleCode in $ruleCodes) {
      $ruleVariantId = [guid](Get-CanonicalMemberValue -InputObject $RuleVariantIds -Name $ruleCode)
      if ($ruleVariantId -eq [guid]::Empty) {
        throw [System.ArgumentException]::new('CS-RULE-001: every RuleVariant identity must be a non-empty GUID.')
      }
      $canonicalRuleVariantIds[$ruleCode] = $ruleVariantId.ToString('D').ToLowerInvariant()
    }

    $generatorFields = @('kind', 'name', 'version', 'modelProvider', 'modelId', 'modelRevision', 'modelEffort')
    $generatorMaximumLengths = @{
      kind = 32
      name = 128
      version = 64
      modelProvider = 64
      modelId = 128
      modelRevision = 128
      modelEffort = 16
    }
    $providedGeneratorNames = @(Get-CanonicalMemberNames -InputObject $Generator)
    if ($providedGeneratorNames.Count -ne $generatorFields.Count -or @($providedGeneratorNames | Where-Object { $_ -notin $generatorFields }).Count -gt 0) {
      throw [System.ArgumentException]::new('CS-RULE-001: generator must contain exactly the frozen identity fields.')
    }
    $canonicalGenerator = [ordered]@{}
    foreach ($field in $generatorFields) {
      $value = [string](Get-CanonicalMemberValue -InputObject $Generator -Name $field)
      if ([string]::IsNullOrWhiteSpace($value) -or $value.Length -gt $generatorMaximumLengths[$field] -or $value -notmatch '^[A-Za-z0-9][A-Za-z0-9._:/+\-]*$') {
        throw [System.ArgumentException]::new('CS-RULE-001: generator identity contains an invalid controlled value.')
      }
      $canonicalGenerator[$field] = $value
    }

    $canonicalDependencies = @(
      foreach ($dependency in @($Dependencies | Sort-Object { [int](Get-CanonicalMemberValue -InputObject $_ -Name 'DependencyOrdinal') })) {
        $allowedDependencyFields = @(
          'DependencyOrdinal',
          'DependencyKindCode',
          'SourceArtifactVersionId',
          'ExternalReferenceKindCode',
          'ExternalReferenceSha256',
          'EvidenceEntityId'
        )
        $providedDependencyNames = @(Get-CanonicalMemberNames -InputObject $dependency)
        if ($providedDependencyNames.Count -ne $allowedDependencyFields.Count -or @($providedDependencyNames | Where-Object { $_ -notin $allowedDependencyFields }).Count -gt 0) {
          throw [System.ArgumentException]::new('CS-REQ-001: dependency must contain exactly the frozen TVP fields.')
        }

        $ordinal = [int](Get-CanonicalMemberValue -InputObject $dependency -Name 'DependencyOrdinal')
        $kind = [string](Get-CanonicalMemberValue -InputObject $dependency -Name 'DependencyKindCode')
        $sourceVersionValue = Get-CanonicalMemberValue -InputObject $dependency -Name 'SourceArtifactVersionId'
        $externalReferenceKindCode = [string](Get-CanonicalMemberValue -InputObject $dependency -Name 'ExternalReferenceKindCode')
        $externalReferenceSha256 = [string](Get-CanonicalMemberValue -InputObject $dependency -Name 'ExternalReferenceSha256')
        $evidenceId = [guid](Get-CanonicalMemberValue -InputObject $dependency -Name 'EvidenceEntityId')
        if ($ordinal -lt 0 -or $kind -notin @('source-artifact-version', 'external') -or $evidenceId -eq [guid]::Empty) {
          throw [System.ArgumentException]::new('CS-REQ-001: dependency identity is invalid.')
        }

        $sourceArtifactVersionValue = $null
        if ($null -ne $sourceVersionValue -and -not [string]::IsNullOrWhiteSpace([string]$sourceVersionValue)) {
          $sourceArtifactVersionIdentity = [guid]$sourceVersionValue
          if ($sourceArtifactVersionIdentity -eq [guid]::Empty) {
            throw [System.ArgumentException]::new('CS-REQ-001: dependency source identity is invalid.')
          }
          $sourceArtifactVersionValue = $sourceArtifactVersionIdentity.ToString('D').ToLowerInvariant()
        }
        $hasSourceVersion = $null -ne $sourceArtifactVersionValue
        $hasExternalReference = -not [string]::IsNullOrWhiteSpace($externalReferenceKindCode) -or -not [string]::IsNullOrWhiteSpace($externalReferenceSha256)
        if ($hasSourceVersion -eq $hasExternalReference) {
          throw [System.ArgumentException]::new('CS-REQ-001: dependency must identify exactly one source version or external reference.')
        }
        if (($kind -eq 'source-artifact-version' -and -not $hasSourceVersion) -or ($kind -eq 'external' -and -not $hasExternalReference)) {
          throw [System.ArgumentException]::new('CS-REQ-001: dependency kind does not match its reference.')
        }
        if ($kind -eq 'source-artifact-version' -and (-not [string]::IsNullOrWhiteSpace($externalReferenceKindCode) -or -not [string]::IsNullOrWhiteSpace($externalReferenceSha256))) {
          throw [System.ArgumentException]::new('CS-REQ-001: source-version dependency cannot carry external reference fields.')
        }
        if ($kind -eq 'external' -and ($externalReferenceKindCode -notin @('uri', 'package', 'document') -or $externalReferenceSha256 -notmatch '^[0-9a-f]{64}$')) {
          throw [System.ArgumentException]::new('CS-REQ-001: external dependency requires a controlled kind and lowercase SHA-256.')
        }

        [pscustomobject][ordered]@{
          dependencyOrdinal = $ordinal
          dependencyKindCode = $kind
          sourceArtifactVersionId = $sourceArtifactVersionValue
          externalReferenceKindCode = if ($kind -eq 'external') { $externalReferenceKindCode } else { $null }
          externalReferenceSha256 = if ($kind -eq 'external') { $externalReferenceSha256 } else { $null }
          evidenceEntityId = $evidenceId.ToString('D').ToLowerInvariant()
        }
      }
    )
    for ($dependencyIndex = 0; $dependencyIndex -lt $canonicalDependencies.Count; $dependencyIndex++) {
      if ($canonicalDependencies[$dependencyIndex].dependencyOrdinal -ne $dependencyIndex) {
        throw [System.ArgumentException]::new('CS-REQ-001: dependency ordinals must be unique and contiguous from zero.')
      }
    }

    $hasSafeSummaryText = -not [string]::IsNullOrWhiteSpace($SafeSummaryText)
    $hasSafeLocator = -not [string]::IsNullOrWhiteSpace($SafeLocator)
    if ($hasSafeSummaryText -and $hasSafeLocator) {
      throw [System.ArgumentException]::new('CS-REQ-001: safeSummaryText and safeLocator are mutually exclusive.')
    }
    if (-not $AllowNoSafePayload -and -not $hasSafeSummaryText -and -not $hasSafeLocator) {
      throw [System.ArgumentException]::new('CS-SUMMARY-001: summarized output requires safe text or a safe locator.')
    }

    $observedAtCanonical = $ObservedAtUtc.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'", [System.Globalization.CultureInfo]::InvariantCulture)
    $envelope = [pscustomobject][ordered]@{
      envelopeVersion = 1
      runId = $RunId.ToString('D').ToLowerInvariant()
      idempotencyKey = $IdempotencyKey.ToString('D').ToLowerInvariant()
      repositoryId = $RepositoryId.ToString('D').ToLowerInvariant()
      rootRegistrationId = $RootRegistrationId.ToString('D').ToLowerInvariant()
      repoRelativePath = $RepoRelativePath
      observedAtUtc = $observedAtCanonical
      byteSha256 = [string]$Observation.ByteSha256
      normalizedContentSha256 = [string]$Observation.NormalizedContentSha256
      byteCount = [long]$Observation.ByteCount
      encodingCode = [string]$Observation.EncodingCode
      lineEndingCode = [string]$Observation.LineEndingCode
      finalNewline = [bool]$Observation.FinalNewline
      harvesterEntityId = $HarvesterEntityId.ToString('D').ToLowerInvariant()
      ruleVariantIds = [pscustomobject]$canonicalRuleVariantIds
      instantiationId = $InstantiationId.ToString('D').ToLowerInvariant()
      classificationPolicyId = $ClassificationPolicyId.ToString('D').ToLowerInvariant()
      promptRuleVariantId = $PromptRuleVariantId.ToString('D').ToLowerInvariant()
      generator = [pscustomobject]$canonicalGenerator
      dependencies = $canonicalDependencies
      safeSummaryText = if ($hasSafeSummaryText) { $SafeSummaryText } else { $null }
      safeLocator = if ($hasSafeLocator) { $SafeLocator } else { $null }
    }
    $canonicalJson = $envelope | ConvertTo-Json -Depth 20 -Compress
    $canonicalRequestHash = Get-ContentSummarySha256 -Text $canonicalJson
    $dependencyJson = ConvertTo-Json -InputObject @($canonicalDependencies) -Depth 10 -Compress
    $dependencyFingerprint = Get-ContentSummarySha256 -Text $dependencyJson
    $generatorIdentity = @($generatorFields | ForEach-Object { [string]$canonicalGenerator[$_] }) -join '/'
    $derivationParts = @(
      $RepositoryId.ToString('D').ToLowerInvariant(),
      $RepoRelativePath,
      $SourceArtifactVersionId.ToString('D').ToLowerInvariant(),
      [string]$Observation.ByteSha256,
      [string]$Observation.NormalizedContentSha256
    ) + @($ruleCodes | ForEach-Object { [string]$canonicalRuleVariantIds[$_] }) + @(
      $ClassificationPolicyId.ToString('D').ToLowerInvariant(),
      $PromptRuleVariantId.ToString('D').ToLowerInvariant(),
      $generatorIdentity,
      $dependencyFingerprint,
      $InstantiationId.ToString('D').ToLowerInvariant()
    )
    $derivationFingerprint = Get-ContentSummarySha256 -Text ($derivationParts -join [char]0x001f)
    $summaryContentSha256 = if ($hasSafeSummaryText) {
      Get-ContentSummarySha256 -Text $SafeSummaryText
    } elseif ($hasSafeLocator) {
      Get-ContentSummarySha256 -Text $SafeLocator
    } else {
      $null
    }

    [pscustomobject][ordered]@{
      HarvestEnvelope = $envelope
      CanonicalRequestJson = $canonicalJson
      CanonicalRequestHash = $canonicalRequestHash
      DependencyFingerprint = $dependencyFingerprint
      DerivationFingerprint = $derivationFingerprint
      SummaryContentSha256 = $summaryContentSha256
      DependencyRows = @(
        foreach ($dependency in $canonicalDependencies) {
          [pscustomobject][ordered]@{
            DependencyOrdinal = $dependency.dependencyOrdinal
            DependencyKindCode = $dependency.dependencyKindCode
            SourceArtifactVersionId = if ($null -ne $dependency.sourceArtifactVersionId) { [guid]$dependency.sourceArtifactVersionId } else { $null }
            ExternalReferenceKindCode = $dependency.externalReferenceKindCode
            ExternalReferenceSha256 = if ($null -ne $dependency.externalReferenceSha256) { [Convert]::FromHexString($dependency.externalReferenceSha256) } else { $null }
            EvidenceEntityId = [guid]$dependency.evidenceEntityId
          }
        }
      )
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}

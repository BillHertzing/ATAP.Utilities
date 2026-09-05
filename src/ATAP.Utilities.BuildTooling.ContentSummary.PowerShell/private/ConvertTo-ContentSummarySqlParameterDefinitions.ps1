function ConvertTo-ContentSummarySqlParameterDefinitions {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Capture', 'ProvisionRepository', 'AssignVersionTag', 'AuthorizeRepository')]
    [string] $Contract,

    [Parameter(Mandatory = $true)]
    [System.Collections.Specialized.OrderedDictionary] $Values
  )

  begin {
    $fn = 'ConvertTo-ContentSummarySqlParameterDefinitions'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'
  }

  process {
    $schemas = @{
      ProvisionRepository = [ordered]@{
        RepositoryId='UniqueIdentifier'; RepositoryRootRegistrationId='UniqueIdentifier'; CanonicalRepositoryName='NVarChar:256'; OriginUri='NVarChar:2048'; CanonicalRoot='NVarChar:1024'; RootKindCode='VarChar:16'; OrganizationId='UniqueIdentifier'; ClassificationPolicyId='UniqueIdentifier'; PrincipalId='UniqueIdentifier'; EvidenceEntityId='UniqueIdentifier'; RecordedAtUtc='DateTime2'
      }
      AssignVersionTag = [ordered]@{
        TagId='UniqueIdentifier'; TagAssignmentId='UniqueIdentifier'; ContentSummaryVersionId='UniqueIdentifier'; PrincipalId='UniqueIdentifier'; SourceReference='NVarChar:512'; RecordedAtUtc='DateTime2'
      }
      AuthorizeRepository = [ordered]@{
        AuthorizationId='UniqueIdentifier'; DatabasePrincipalName='NVarChar:128'; InstanceCode='VarChar:16'; RepositoryId='UniqueIdentifier'; SourceReference='NVarChar:512'; RecordedAtUtc='DateTime2'
      }
      Capture = [ordered]@{
        IdempotencyKey='UniqueIdentifier'; CanonicalRequestSha256='Binary:32'; RunId='UniqueIdentifier'; RepositoryId='UniqueIdentifier'; RootRegistrationId='UniqueIdentifier'; RepoRelativePath='NVarChar:1024'; SourceArtifactId='UniqueIdentifier'; SourceArtifactVersionId='UniqueIdentifier'; ContentSummaryId='UniqueIdentifier'; ContentSummaryVersionId='UniqueIdentifier'; PriorContentSummaryVersionId='UniqueIdentifier'; ObservedAtUtc='DateTime2'; RecordedAtUtc='DateTime2'; ByteSha256='Binary:32'; NormalizedContentSha256='Binary:32'; ByteCount='BigInt'; EncodingCode='VarChar:32'; HasBom='Bit'; LineEndingCode='VarChar:8'; FinalNewline='Bit'; HarvesterEntityId='UniqueIdentifier'; SummaryProfileCode='VarChar:64'; ClassificationPolicyId='UniqueIdentifier'; SourceIdentityRuleVariantId='UniqueIdentifier'; NormalizationRuleVariantId='UniqueIdentifier'; ClassificationRuleVariantId='UniqueIdentifier'; SummaryRenderRuleVariantId='UniqueIdentifier'; FreshnessRuleVariantId='UniqueIdentifier'; QueryRankingRuleVariantId='UniqueIdentifier'; InstantiationId='UniqueIdentifier'; PromptRuleVariantId='UniqueIdentifier'; GeneratorKindCode='VarChar:32'; GeneratorName='NVarChar:128'; GeneratorVersion='NVarChar:64'; ModelProvider='NVarChar:64'; ModelId='NVarChar:128'; ModelRevision='NVarChar:128'; ModelEffort='VarChar:16'; LifecycleCode='VarChar:16'; SafeSummaryText='NVarChar:-1'; SafeLocator='NVarChar:2048'; WasRedacted='Bit'; RedactionEvidenceId='UniqueIdentifier'; SummaryContentSha256='Binary:32'; ExclusionEvidenceId='UniqueIdentifier'; LifecycleReasonCode='VarChar:64'; DerivationFingerprint='Binary:32'; Dependencies='Structured::ATAPUtilities.ContentSummaryDependencyInput'
      }
    }
    $schema = $schemas[$Contract]
    if (($Values.Keys -join ',') -ne ($schema.Keys -join ',')) {
      throw 'CS-INTERNAL-001: adapter values do not match the frozen SQL parameter order.'
    }
    $definitions = [ordered]@{}
    foreach ($name in $schema.Keys) {
      $parts = ([string]$schema[$name]).Split(':', 3)
      $parameterValue = $Values[$name]
      if ($parts[0] -eq 'DateTime2' -and $parameterValue -is [datetimeoffset]) {
        $parameterValue = ([datetimeoffset]$parameterValue).UtcDateTime
      } elseif ($parts[0] -eq 'Binary' -and $null -ne $parameterValue) {
        try {
          $parameterValue = [byte[]]$parameterValue
        } catch {
          throw "CS-REQ-001: $name must be binary data."
        }
        if ($parts.Count -gt 1 -and $parts[1] -and $parameterValue.Length -ne [int]$parts[1]) {
          throw "CS-REQ-001: $name must contain exactly $($parts[1]) bytes."
        }
      }
      $definition = [pscustomobject]@{
        SqlDbType = $parts[0]
        Size = if ($parts.Count -gt 1 -and $parts[1]) { [int]$parts[1] } else { $null }
        TypeName = if ($parts.Count -gt 2 -and $parts[2]) { [string]$parts[2] } else { $null }
        Value = $null
      }
      $definition.Value = $parameterValue
      $definitions[$name] = $definition
    }
    return $definitions
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}

function New-ContentSummarySqlAdapterSet {
  <#
  .SYNOPSIS
    Creates procedure-only SqlClient adapters for ContentSummary production harvesting.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object] $SqlConnection,

    [ValidateRange(1, 300)]
    [int] $CommandTimeoutSeconds = 30
  )

  begin {
    $fn = 'New-ContentSummarySqlAdapterSet'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'
  }

  process {
    if ($null -eq $SqlConnection -or
      -not [string]::Equals($SqlConnection.GetType().FullName, 'Microsoft.Data.SqlClient.SqlConnection', [StringComparison]::Ordinal) -or
      [string]$SqlConnection.State -ne 'Open') {
      throw 'CS-SQL-001: an open Microsoft.Data.SqlClient.SqlConnection is required.'
    }
    $connection = $SqlConnection
    $timeout = $CommandTimeoutSeconds

    $provisionRepository = {
      param($RepositoryId,$RepositoryRootRegistrationId,$CanonicalRepositoryName,$OriginUri,$CanonicalRoot,$RootKindCode,$OrganizationId,$ClassificationPolicyId,$PrincipalId,$EvidenceEntityId,$RecordedAtUtc)
      $canonicalOrigin = ConvertTo-ContentSummaryCanonicalOriginUri -OriginUri $OriginUri
      $values = [ordered]@{RepositoryId=$RepositoryId;RepositoryRootRegistrationId=$RepositoryRootRegistrationId;CanonicalRepositoryName=$CanonicalRepositoryName;OriginUri=$canonicalOrigin;CanonicalRoot=$CanonicalRoot;RootKindCode=$RootKindCode;OrganizationId=$OrganizationId;ClassificationPolicyId=$ClassificationPolicyId;PrincipalId=$PrincipalId;EvidenceEntityId=$EvidenceEntityId;RecordedAtUtc=$RecordedAtUtc}
      $parameters = ConvertTo-ContentSummarySqlParameterDefinitions -Contract ProvisionRepository -Values $values
      $result = Invoke-ContentSummarySqlStoredProcedure -SqlConnection $connection -ProcedureName 'ATAPUtilities.ProvisionContentSummaryRepositoryV1' -Parameters $parameters -ResultPropertyOrder @('RepositoryId','RepositoryRootRegistrationId','CanonicalRepositoryName','OriginUri','CanonicalRoot','RootKindCode','StatusCode','ErrorCode') -AllowedStatusCodes @('Created','Existing') -CommandTimeoutSeconds $timeout
      $expectedOrigin = $canonicalOrigin
      $expectedRoot = ([string]$CanonicalRoot).Trim().Replace('/','\').ToLowerInvariant()
      while ($expectedRoot.Length -gt 3 -and $expectedRoot.EndsWith('\')) { $expectedRoot = $expectedRoot.Substring(0,$expectedRoot.Length-1) }
      if ([guid]$result.RepositoryId -ne [guid]$RepositoryId -or [guid]$result.RepositoryRootRegistrationId -ne [guid]$RepositoryRootRegistrationId -or $result.CanonicalRepositoryName -cne $CanonicalRepositoryName -or $result.OriginUri -cne $expectedOrigin -or $result.CanonicalRoot -cne $expectedRoot -or $result.RootKindCode -cne $RootKindCode) { throw 'CS-SQL-002: repository acknowledgement does not match the request.' }
      $result
    }.GetNewClosure()

    $assignVersionTag = {
      param($TagId,$TagAssignmentId,$ContentSummaryVersionId,$PrincipalId,$SourceReference,$RecordedAtUtc)
      $values = [ordered]@{TagId=$TagId;TagAssignmentId=$TagAssignmentId;ContentSummaryVersionId=$ContentSummaryVersionId;PrincipalId=$PrincipalId;SourceReference=$SourceReference;RecordedAtUtc=$RecordedAtUtc}
      $parameters = ConvertTo-ContentSummarySqlParameterDefinitions -Contract AssignVersionTag -Values $values
      $result = Invoke-ContentSummarySqlStoredProcedure -SqlConnection $connection -ProcedureName 'ATAPUtilities.AssignContentSummaryVersionTagV1' -Parameters $parameters -ResultPropertyOrder @('TagId','TagAssignmentId','ContentSummaryVersionId','StatusCode','ErrorCode') -AllowedStatusCodes @('Assigned','Existing') -CommandTimeoutSeconds $timeout
      if ([guid]$result.TagId -ne [guid]$TagId -or [guid]$result.TagAssignmentId -ne [guid]$TagAssignmentId -or [guid]$result.ContentSummaryVersionId -ne [guid]$ContentSummaryVersionId) { throw 'CS-SQL-002: tag acknowledgement does not match the request.' }
      $result
    }.GetNewClosure()

    $authorizeRepository = {
      param($AuthorizationId,$DatabasePrincipalName,$InstanceCode,$RepositoryId,$SourceReference,$RecordedAtUtc)
      $values = [ordered]@{AuthorizationId=$AuthorizationId;DatabasePrincipalName=$DatabasePrincipalName;InstanceCode=$InstanceCode;RepositoryId=$RepositoryId;SourceReference=$SourceReference;RecordedAtUtc=$RecordedAtUtc}
      $parameters = ConvertTo-ContentSummarySqlParameterDefinitions -Contract AuthorizeRepository -Values $values
      $result = Invoke-ContentSummarySqlStoredProcedure -SqlConnection $connection -ProcedureName 'ATAPUtilities.AuthorizeContentSummaryDatabasePrincipalRepositoryV1' -Parameters $parameters -ResultPropertyOrder @('AuthorizationId','DatabasePrincipalName','InstanceCode','RepositoryId','StatusCode','ErrorCode') -AllowedStatusCodes @('Authorized','Existing') -CommandTimeoutSeconds $timeout
      if ([guid]$result.AuthorizationId -ne [guid]$AuthorizationId -or $result.DatabasePrincipalName -cne $DatabasePrincipalName -or $result.InstanceCode -cne $InstanceCode -or [guid]$result.RepositoryId -ne [guid]$RepositoryId) { throw 'CS-SQL-002: authorization acknowledgement does not match the request.' }
      $result
    }.GetNewClosure()

    $capture = {
      param($IdempotencyKey,$CanonicalRequestSha256,$RunId,$RepositoryId,$RootRegistrationId,$RepoRelativePath,$SourceArtifactId,$SourceArtifactVersionId,$ContentSummaryId,$ContentSummaryVersionId,$PriorContentSummaryVersionId,$ObservedAtUtc,$RecordedAtUtc,$ByteSha256,$NormalizedContentSha256,$ByteCount,$EncodingCode,$HasBom,$LineEndingCode,$FinalNewline,$HarvesterEntityId,$SummaryProfileCode,$ClassificationPolicyId,$SourceIdentityRuleVariantId,$NormalizationRuleVariantId,$ClassificationRuleVariantId,$SummaryRenderRuleVariantId,$FreshnessRuleVariantId,$QueryRankingRuleVariantId,$InstantiationId,$PromptRuleVariantId,$GeneratorKindCode,$GeneratorName,$GeneratorVersion,$ModelProvider,$ModelId,$ModelRevision,$ModelEffort,$LifecycleCode,$SafeSummaryText,$SafeLocator,$WasRedacted,$RedactionEvidenceId,$SummaryContentSha256,$ExclusionEvidenceId,$LifecycleReasonCode,$DerivationFingerprint,$Dependencies)
      $dependencyTable = ConvertTo-ContentSummaryDependencyDataTable -Dependencies $Dependencies
      $values = [ordered]@{IdempotencyKey=$IdempotencyKey;CanonicalRequestSha256=$CanonicalRequestSha256;RunId=$RunId;RepositoryId=$RepositoryId;RootRegistrationId=$RootRegistrationId;RepoRelativePath=$RepoRelativePath;SourceArtifactId=$SourceArtifactId;SourceArtifactVersionId=$SourceArtifactVersionId;ContentSummaryId=$ContentSummaryId;ContentSummaryVersionId=$ContentSummaryVersionId;PriorContentSummaryVersionId=$PriorContentSummaryVersionId;ObservedAtUtc=$ObservedAtUtc;RecordedAtUtc=$RecordedAtUtc;ByteSha256=$ByteSha256;NormalizedContentSha256=$NormalizedContentSha256;ByteCount=$ByteCount;EncodingCode=$EncodingCode;HasBom=$HasBom;LineEndingCode=$LineEndingCode;FinalNewline=$FinalNewline;HarvesterEntityId=$HarvesterEntityId;SummaryProfileCode=$SummaryProfileCode;ClassificationPolicyId=$ClassificationPolicyId;SourceIdentityRuleVariantId=$SourceIdentityRuleVariantId;NormalizationRuleVariantId=$NormalizationRuleVariantId;ClassificationRuleVariantId=$ClassificationRuleVariantId;SummaryRenderRuleVariantId=$SummaryRenderRuleVariantId;FreshnessRuleVariantId=$FreshnessRuleVariantId;QueryRankingRuleVariantId=$QueryRankingRuleVariantId;InstantiationId=$InstantiationId;PromptRuleVariantId=$PromptRuleVariantId;GeneratorKindCode=$GeneratorKindCode;GeneratorName=$GeneratorName;GeneratorVersion=$GeneratorVersion;ModelProvider=$ModelProvider;ModelId=$ModelId;ModelRevision=$ModelRevision;ModelEffort=$ModelEffort;LifecycleCode=$LifecycleCode;SafeSummaryText=$SafeSummaryText;SafeLocator=$SafeLocator;WasRedacted=$WasRedacted;RedactionEvidenceId=$RedactionEvidenceId;SummaryContentSha256=$SummaryContentSha256;ExclusionEvidenceId=$ExclusionEvidenceId;LifecycleReasonCode=$LifecycleReasonCode;DerivationFingerprint=$DerivationFingerprint;Dependencies=$dependencyTable}
      $parameters = ConvertTo-ContentSummarySqlParameterDefinitions -Contract Capture -Values $values
      $result = Invoke-ContentSummarySqlStoredProcedure -SqlConnection $connection -ProcedureName 'ATAPUtilities.CaptureContentSummaryObservationV1' -Parameters $parameters -ResultPropertyOrder @('ReplayStatus','IdempotencyKey','SourceArtifactId','SourceArtifactVersionId','ContentSummaryId','ContentSummaryVersionId','SourceArtifactVersionSequence','ContentSummaryVersionSequence','LifecycleCode','ErrorCode') -AllowedStatusCodes @('Created','Replayed','DerivationReplay') -StatusPropertyName ReplayStatus -CommandTimeoutSeconds $timeout
      Assert-ContentSummaryCaptureAcknowledgement -Result $result -IdempotencyKey $IdempotencyKey -SourceArtifactId $SourceArtifactId -SourceArtifactVersionId $SourceArtifactVersionId -ContentSummaryId $ContentSummaryId -ContentSummaryVersionId $ContentSummaryVersionId
    }.GetNewClosure()

    [pscustomobject][ordered]@{
      SchemaVersion = 1
      Capture = $capture
      ProvisionRepository = $provisionRepository
      AssignContentSummaryVersionTag = $assignVersionTag
      AuthorizeRepository = $authorizeRepository
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}

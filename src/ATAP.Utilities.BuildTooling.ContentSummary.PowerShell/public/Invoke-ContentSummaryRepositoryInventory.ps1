function Invoke-ContentSummaryRepositoryInventory {
  <#
  .SYNOPSIS
    Applies a hash-approved repository inventory through controlled V00120 procedures.
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{64}$')]
    [string] $ExpectedSha256,

    [Parameter(Mandatory = $true)]
    [object] $AdapterSet
  )

  begin {
    $fn = 'Invoke-ContentSummaryRepositoryInventory'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'
  }

  process {
    $expectedAdapterProperties = @('SchemaVersion','Capture','ProvisionRepository','AssignContentSummaryVersionTag','AuthorizeRepository')
    if ($null -eq $AdapterSet -or ($AdapterSet.PSObject.Properties.Name -join ',') -ne ($expectedAdapterProperties -join ',') -or
      $AdapterSet.SchemaVersion -ne 1 -or $AdapterSet.ProvisionRepository -isnot [scriptblock] -or $AdapterSet.AuthorizeRepository -isnot [scriptblock]) {
      throw 'CS-INVENTORY-001: adapter set does not match the production contract.'
    }
    $inventory = Read-ContentSummaryRepositoryInventory -Path $Path -ExpectedSha256 $ExpectedSha256
    $repositoryResults = [Collections.Generic.List[object]]::new()
    $authorizationResults = [Collections.Generic.List[object]]::new()
    $plannedRepositoryCount = 0
    $plannedAuthorizationCount = 0
    foreach ($repository in $inventory.Repositories) {
      $target = "repository/$($repository.repositoryId)"
      if ($PSCmdlet.ShouldProcess($target, 'Provision ContentSummary repository and canonical root')) {
        $result = & $AdapterSet.ProvisionRepository `
          -RepositoryId ([guid]$repository.repositoryId) `
          -RepositoryRootRegistrationId ([guid]$repository.repositoryRootRegistrationId) `
          -CanonicalRepositoryName ([string]$repository.canonicalRepositoryName) `
          -OriginUri ([string]$repository.originUri) `
          -CanonicalRoot ([string]$repository.canonicalRoot) `
          -RootKindCode ([string]$repository.rootKindCode) `
          -OrganizationId ([guid]$repository.organizationId) `
          -ClassificationPolicyId ([guid]$repository.classificationPolicyId) `
          -PrincipalId ([guid]$repository.principalId) `
          -EvidenceEntityId ([guid]$repository.evidenceEntityId) `
          -RecordedAtUtc ([datetimeoffset]$repository.recordedAtUtc)
        [void]$repositoryResults.Add($result)
      } else { $plannedRepositoryCount++ }

      foreach ($authorization in @($repository.authorizations)) {
        $authorizationTarget = "authorization/$($authorization.authorizationId)"
        if ($PSCmdlet.ShouldProcess($authorizationTarget, 'Authorize database principal for ContentSummary repository')) {
          $result = & $AdapterSet.AuthorizeRepository `
            -AuthorizationId ([guid]$authorization.authorizationId) `
            -DatabasePrincipalName ([string]$authorization.databasePrincipalName) `
            -InstanceCode ([string]$authorization.instanceCode) `
            -RepositoryId ([guid]$repository.repositoryId) `
            -SourceReference ([string]$authorization.sourceReference) `
            -RecordedAtUtc ([datetimeoffset]$authorization.recordedAtUtc)
          [void]$authorizationResults.Add($result)
        } else { $plannedAuthorizationCount++ }
      }
    }
    [pscustomobject][ordered]@{
      SchemaVersion = 1
      Status = if ($WhatIfPreference) { 'WhatIf' } else { 'Applied' }
      InventorySha256 = $inventory.InventorySha256
      InventoryId = $inventory.InventoryId
      RepositoryResultCount = $repositoryResults.Count
      AuthorizationResultCount = $authorizationResults.Count
      PlannedRepositoryCount = $plannedRepositoryCount
      PlannedAuthorizationCount = $plannedAuthorizationCount
      RepositoryResults = @($repositoryResults)
      AuthorizationResults = @($authorizationResults)
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}

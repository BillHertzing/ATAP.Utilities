<#
.SYNOPSIS
    Loads the ordered BuildSetVersion-to-RuleSetVersion-to-RuleVersion graph for one InstantiationVersion.

.DESCRIPTION
    Reads versioned manifestation rows from ATAPUtilities and returns a nested graph object in
    BuildSetVersion order, then RuleSetVersion order, then RuleVersion order. The function
    follows the corrected Stream J Instantiation model (no Build layer).

.PARAMETER InstantiationVersionPhiloteId
    The InstantiationVersion.philote identifier used as the graph root.

.PARAMETER SqlConnection
    Existing open Microsoft.Data.SqlClient.SqlConnection to read from. Caller-owned; this function
    does not close it.

.PARAMETER DBConnectionStringSecretName
    Secret name that resolves to a SQL connection string. Function-owned connection is closed on
    completion.

.PARAMETER DatabaseHost
    SQL Server host name used when resolving a ConnectionParts connection.

.PARAMETER InstanceName
    SQL Server instance name used when resolving a ConnectionParts connection.

.PARAMETER DatabaseName
    Database name used when resolving a ConnectionParts connection.

.PARAMETER ConnectionMethod
    Connection method used when resolving a ConnectionParts connection.

.PARAMETER CredentialsKey
    Optional credential lookup key for ConnectionParts resolution.

.PARAMETER IntegratedSecurity
    Use Windows Integrated Security when resolving a ConnectionParts connection.

.PARAMETER UseTrustedConnection
    Alias for Trusted_Connection behavior.

.OUTPUTS
    [PSCustomObject] with InstantiationVersion root and nested BuildSetVersion/RuleSetVersion/RuleVersion graph.

.EXAMPLE
    Get-InstantiationVersionRuleGraph -InstantiationVersionPhiloteId '6f3c1fb6-842e-4502-a416-88205983ed35' -DatabaseHost localhost -DatabaseName ATAPUtilities
#>
[CmdletBinding(DefaultParameterSetName = 'ConnectionParts')]
[OutputType([PSCustomObject])]
param(
  [Parameter(Mandatory = $true)]
  [guid]$InstantiationVersionPhiloteId,

  [Parameter(Mandatory = $true, ParameterSetName = 'SqlConnection', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
  [object]$SqlConnection,

  [Parameter(Mandatory = $false, ParameterSetName = 'DBConnectionStringSecretName', ValueFromPipelineByPropertyName = $true)]
  [Alias('DBConnectionStringSecret', 'SecretName', 'BitwardenSecretName', 'BitwardenSecret')]
  [string]$DBConnectionStringSecretName,

  [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParts', ValueFromPipelineByPropertyName = $true)]
  [Alias('HostName', 'ServerInstance')]
  [string]$DatabaseHost,

  [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParts', ValueFromPipelineByPropertyName = $true)]
  [Alias('SqlInstance')]
  [string]$InstanceName,

  [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
  [string]$DatabaseName,

  [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParts', ValueFromPipelineByPropertyName = $true)]
  [string]$ConnectionMethod,

  [Parameter(Mandatory = $false, ParameterSetName = 'ConnectionParts', ValueFromPipelineByPropertyName = $true)]
  [string]$CredentialsKey,

  [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
  [switch]$IntegratedSecurity,

  [Parameter(Mandatory = $false)]
  [switch]$UseTrustedConnection,

  [Parameter(Mandatory = $false)]
  [hashtable]$Settings,

  [Parameter(Mandatory = $false)]
  [hashtable]$OriginalPSBoundParameters
)

begin {
  $fn = 'Get-InstantiationVersionRuleGraph'
  $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'
}

process {
  $toInt = {
    param($value)
    if ($null -eq $value) {
      return 0
    }
    try {
      [int]$value
    } catch {
      0
    }
  }

  if (-not $PSCmdlet.ShouldProcess("InstantiationVersion $InstantiationVersionPhiloteId", 'Load BuildSetVersion->RuleSetVersion->RuleVersion graph')) {
    return
  }

  $resolution = Resolve-DatabaseSqlConnection `
    -OriginalPSBoundParameters $PSBoundParameters `
    -SqlConnection $SqlConnection `
    -DBConnectionStringSecretName $DBConnectionStringSecretName `
    -DatabaseHost $DatabaseHost `
    -InstanceName $InstanceName `
    -DatabaseName $DatabaseName `
    -ConnectionMethod $ConnectionMethod `
    -CredentialsKey $CredentialsKey `
    -IntegratedSecurity:$IntegratedSecurity `
    -UseTrustedConnection:$UseTrustedConnection `
    -Settings $Settings

  $resolvedConnection = $resolution.Connection
  $isCallerOwned = [bool]$resolution.IsCallerOwned

  $query = @'
SELECT
    bsv.BuildSetVersionPhiloteId,
    bsv.SortOrder AS BuildSetSortOrder,
    bsvm.SortOrder AS RuleSetMembershipSortOrder,
    rsv.RuleSetVersionPhiloteId,
    rsv.SortOrder AS RuleSetVersionSortOrder,
    rsvm.SortOrder AS RuleVersionMembershipSortOrder,
    rv.RuleVersionPhiloteId,
    rv.SortOrder AS RuleVersionSortOrder
FROM ATAPUtilities.InstantiationVersion AS iv
INNER JOIN ATAPUtilities.BuildSetVersion AS bsv
    ON bsv.BuildSetVersionPhiloteId = iv.BuildSetVersionPhiloteId
LEFT JOIN ATAPUtilities.BuildSetVersionMember AS bsvm
    ON bsvm.BuildSetVersionPhiloteId = bsv.BuildSetVersionPhiloteId
LEFT JOIN ATAPUtilities.RuleSetVersion AS rsv
    ON rsv.RuleSetVersionPhiloteId = bsvm.RuleSetVersionPhiloteId
LEFT JOIN ATAPUtilities.RuleSetVersionMember AS rsvm
    ON rsvm.RuleSetVersionPhiloteId = rsv.RuleSetVersionPhiloteId
LEFT JOIN ATAPUtilities.RuleVersion AS rv
    ON rv.RuleVersionPhiloteId = rsvm.RuleVersionPhiloteId
WHERE iv.InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId;
'@

  $rows = @(
    Invoke-DatabaseSqlQuery `
      -SqlConnection $resolvedConnection `
      -CommandText $query `
      -Parameters @{ InstantiationVersionPhiloteId = $InstantiationVersionPhiloteId.ToString() }
  )

  if ($rows.Count -eq 0) {
    $msg = "No BuildSetVersion-to-RuleSetVersion-to-RuleVersion graph rows found for InstantiationVersion '$InstantiationVersionPhiloteId'. Verify the corrected Instantiation schema and FK chain are deployed."
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Error'
    throw $msg
  }

  $buildSetRows = @(
    $rows |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_.BuildSetVersionPhiloteId) } |
      Group-Object BuildSetVersionPhiloteId
  )
  if ($buildSetRows.Count -eq 0) {
    $msg = "No BuildSetVersion rows were found for InstantiationVersion '$InstantiationVersionPhiloteId'. Verify corrected InstantiationVersion to BuildSetVersion linkage."
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Error'
    throw $msg
  }

  $buildSetVersions = [System.Collections.Generic.List[object]]::new()
  foreach ($buildSetGroup in ($buildSetRows | Sort-Object { & $toInt $_.Group[0].BuildSetSortOrder }, { $_.Name })) {
    $ruleSetGroups = @(
      $buildSetGroup.Group |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_.RuleSetVersionPhiloteId) } |
        Group-Object RuleSetVersionPhiloteId
    )
    $ruleSetVersions = [System.Collections.Generic.List[object]]::new()
    foreach ($ruleSetGroup in ($ruleSetGroups | Sort-Object { & $toInt $_.Group[0].RuleSetMembershipSortOrder }, { $_.Name })) {
      $ruleVersionRows = @($ruleSetGroup.Group | Where-Object { -not [string]::IsNullOrWhiteSpace($_.RuleVersionPhiloteId) })
      $ruleVersions = [System.Collections.Generic.List[object]]::new()
      foreach ($ruleVersionRow in ($ruleVersionRows | Sort-Object { & $toInt $_.RuleVersionMembershipSortOrder })) {
        $ruleVersions.Add([PSCustomObject]@{
            RuleVersionPhiloteId = [guid]$ruleVersionRow.RuleVersionPhiloteId
            SortOrder           = & $toInt $ruleVersionRow.RuleVersionMembershipSortOrder
            RuleVersionSortOrder = & $toInt $ruleVersionRow.RuleVersionSortOrder
          })
      }

      $ruleSetVersions.Add([PSCustomObject]@{
          RuleSetVersionPhiloteId = [guid]$ruleSetGroup.Name
          SortOrder              = & $toInt $ruleSetGroup.Group[0].RuleSetMembershipSortOrder
          RuleSetVersionSortOrder = & $toInt $ruleSetGroup.Group[0].RuleSetVersionSortOrder
          RuleVersions           = @($ruleVersions)
        })
    }

    $buildSetVersions.Add([PSCustomObject]@{
        BuildSetVersionPhiloteId = [guid]$buildSetGroup.Name
        SortOrder               = & $toInt $buildSetGroup.Group[0].BuildSetSortOrder
        RuleSetVersions         = @($ruleSetVersions)
      })
  }

  Write-Output [PSCustomObject]@{
    InstantiationVersionPhiloteId = $InstantiationVersionPhiloteId
    BuildSetVersions             = @($buildSetVersions)
  }
}

finally {
  if (-not $isCallerOwned -and $null -ne $resolvedConnection) {
    try {
      $resolvedConnection.Close()
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Ignoring close failure on non-caller-owned SQL connection.' -Tag 'DatabaseConnection'
    }
    try {
      $resolvedConnection.Dispose()
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Ignoring dispose failure on non-caller-owned SQL connection.' -Tag 'DatabaseConnection'
    }
  }

  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
}

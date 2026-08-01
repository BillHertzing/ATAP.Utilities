<#
.SYNOPSIS
    Loads one immutable InstantiationVersion graph and its resolved RuleInstantiation snapshots.

.DESCRIPTION
    Returns the ordered BuildSetVersion-to-RuleSetVersion-to-RuleVersion graph (there is no
    Build layer), the ordered RuleInstantiationVersion snapshot, declared inputs, bindings as
    they existed when each snapshot was created, exact source lines, and planned artifacts.
    Missing, duplicate, undeclared, or out-of-graph inputs fail closed.
#>
function Get-InstantiationVersionRuleGraph {
  [CmdletBinding(DefaultParameterSetName = 'ConnectionParts', SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [guid]$InstantiationVersionPhiloteId,

    [Parameter(Mandatory = $true, ParameterSetName = 'SqlConnection', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [object]$SqlConnection,

    [Parameter(ParameterSetName = 'DBConnectionStringSecretName', ValueFromPipelineByPropertyName = $true)]
    [Alias('DBConnectionStringSecret', 'SecretName', 'BitwardenSecretName', 'BitwardenSecret')]
    [string]$DBConnectionStringSecretName,

    [Parameter(ParameterSetName = 'ConnectionParts', ValueFromPipelineByPropertyName = $true)]
    [Alias('HostName', 'ServerInstance')]
    [string]$DatabaseHost,

    [Parameter(ParameterSetName = 'ConnectionParts', ValueFromPipelineByPropertyName = $true)]
    [Alias('SqlInstance')]
    [string]$InstanceName,

    [Parameter(ValueFromPipelineByPropertyName = $true)]
    [string]$DatabaseName,

    [Parameter(ParameterSetName = 'ConnectionParts', ValueFromPipelineByPropertyName = $true)]
    [string]$ConnectionMethod,

    [Parameter(ParameterSetName = 'ConnectionParts', ValueFromPipelineByPropertyName = $true)]
    [string]$CredentialsKey,

    [Parameter(ValueFromPipelineByPropertyName = $true)]
    [switch]$IntegratedSecurity,

    [Parameter()]
    [switch]$UseTrustedConnection,

    [Parameter()]
    [hashtable]$Settings,

    [Parameter()]
    [hashtable]$OriginalPSBoundParameters
  )

  begin {
    $fn = 'Get-InstantiationVersionRuleGraph'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'
  }

  process {
    $resolvedConnection = $null
    $isCallerOwned = $false
    try {
      if (-not $PSCmdlet.ShouldProcess("InstantiationVersion $InstantiationVersionPhiloteId", 'Load immutable corrected manifestation graph')) {
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
      $parameters = @{ InstantiationVersionPhiloteId = $InstantiationVersionPhiloteId.ToString() }

      $graphRows = @(Invoke-DatabaseSqlQuery -SqlConnection $resolvedConnection -Parameters $parameters -CommandText @'
/* Task13.80:Graph */
SELECT iv.InstantiationPhiloteId, iv.VersionNumber AS InstantiationVersionNumber,
       iv.VersionLabel AS InstantiationVersionLabel, iv.BuildSetVersionPhiloteId,
       bsv.SortOrder AS BuildSetSortOrder, bsvm.SortOrder AS RuleSetMembershipSortOrder,
       rsv.RuleSetVersionPhiloteId, rsv.SortOrder AS RuleSetVersionSortOrder,
       rsvm.SortOrder AS RuleVersionMembershipSortOrder, rv.RuleVersionPhiloteId,
       rv.RulePhiloteId, rv.SortOrder AS RuleVersionSortOrder, rv.ContentSha256
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
'@)

      if ($graphRows.Count -eq 0) {
        throw "No BuildSetVersion-to-RuleSetVersion-to-RuleVersion graph rows found for InstantiationVersion '$InstantiationVersionPhiloteId'."
      }

      $snapshotRows = @(Invoke-DatabaseSqlQuery -SqlConnection $resolvedConnection -Parameters $parameters -CommandText @'
/* Task13.80:Snapshots */
SELECT m.SortOrder, riv.RuleInstantiationVersionPhiloteId,
       riv.RuleInstantiationPhiloteId, riv.RuleVersionPhiloteId, riv.RulePhiloteId,
       riv.VersionNumber, riv.VersionLabel, riv.EffectiveFrom
FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion AS m
INNER JOIN ATAPUtilities.RuleInstantiationVersion AS riv
  ON riv.RuleInstantiationVersionPhiloteId = m.RuleInstantiationVersionPhiloteId
WHERE m.InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
ORDER BY m.SortOrder, riv.RuleInstantiationVersionPhiloteId;
'@)

      $compositionRows = @(Invoke-DatabaseSqlQuery -SqlConnection $resolvedConnection -Parameters $parameters -CommandText @'
/* Task13.80:Declarations */
SELECT DISTINCT riv.RuleInstantiationVersionPhiloteId, c.Position,
       c.PrimitivePhiloteId, p.[Name] AS PrimitiveName,
       c.IsOptional, c.Cardinality,
       i.InputName, i.TypeName, i.DefaultValue, i.IsRequired
FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion AS m
INNER JOIN ATAPUtilities.RuleInstantiationVersion AS riv
  ON riv.RuleInstantiationVersionPhiloteId = m.RuleInstantiationVersionPhiloteId
INNER JOIN ATAPUtilities.RuleVersionPrimitiveComposition AS c
  ON c.RuleVersionPhiloteId = riv.RuleVersionPhiloteId
INNER JOIN ATAPUtilities.RulePrimitive AS p
  ON p.PhiloteId = c.PrimitivePhiloteId
LEFT JOIN ATAPUtilities.RulePrimitiveInput AS i
  ON i.PhiloteId = c.PrimitivePhiloteId
WHERE m.InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
ORDER BY riv.RuleInstantiationVersionPhiloteId, c.Position, i.InputName;
'@)

      $bindingRows = @(Invoke-DatabaseSqlQuery -SqlConnection $resolvedConnection -Parameters $parameters -CommandText @'
/* Task13.80:BindingsAsOfSnapshot */
SELECT riv.RuleInstantiationVersionPhiloteId, b.InputName, b.InputValue,
       b.EffectiveFrom, b.EffectiveTo
FROM ATAPUtilities.InstantiationVersionRuleInstantiationVersion AS m
INNER JOIN ATAPUtilities.RuleInstantiationVersion AS riv
  ON riv.RuleInstantiationVersionPhiloteId = m.RuleInstantiationVersionPhiloteId
INNER JOIN ATAPUtilities.RuleInstantiationBinding AS b
  ON b.InstantiationPhiloteId = riv.RuleInstantiationPhiloteId
 AND b.EffectiveFrom <= riv.EffectiveFrom
 AND (b.EffectiveTo IS NULL OR b.EffectiveTo > riv.EffectiveFrom)
WHERE m.InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
ORDER BY riv.RuleInstantiationVersionPhiloteId, b.InputName, b.EffectiveFrom;
'@)

      $sourceLineRows = @(Invoke-DatabaseSqlQuery -SqlConnection $resolvedConnection -Parameters $parameters -CommandText @'
/* Task13.80:SourceLines */
SELECT l.RuleInstantiationVersionPhiloteId, l.Ordinal, l.LineText, l.LineEnding
FROM ATAPUtilities.RuleInstantiationVersionSourceLine AS l
INNER JOIN ATAPUtilities.InstantiationVersionRuleInstantiationVersion AS m
  ON m.RuleInstantiationVersionPhiloteId = l.RuleInstantiationVersionPhiloteId
WHERE m.InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
  AND l.EffectiveTo IS NULL
ORDER BY l.RuleInstantiationVersionPhiloteId, l.Ordinal;
'@)

      $artifactRows = @(Invoke-DatabaseSqlQuery -SqlConnection $resolvedConnection -Parameters $parameters -CommandText @'
/* Task13.80:Artifacts */
SELECT ManifestationArtifactPhiloteId, ArtifactKind, RelativePath, ContentSha256,
       RenderPolicy, SortOrder, BuildSetVersionPhiloteId,
       ProducingRuleInstantiationPhiloteId,
       ProducingRuleInstantiationVersionPhiloteId
FROM ATAPUtilities.ManifestationArtifact
WHERE InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
  AND EffectiveTo IS NULL
ORDER BY SortOrder, RelativePath;
'@)

      $toInt = { param($value) if ($null -eq $value) { 0 } else { [int]$value } }
      $ruleVersionIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
      foreach ($row in $graphRows) {
        if (-not [string]::IsNullOrWhiteSpace([string]$row.RuleVersionPhiloteId)) {
          [void]$ruleVersionIds.Add(([guid]$row.RuleVersionPhiloteId).ToString())
        }
      }

      $buildSetVersions = [System.Collections.Generic.List[object]]::new()
      foreach ($buildSetGroup in ($graphRows | Group-Object BuildSetVersionPhiloteId | Sort-Object { & $toInt $_.Group[0].BuildSetSortOrder }, Name)) {
        $ruleSetVersions = [System.Collections.Generic.List[object]]::new()
        foreach ($ruleSetGroup in ($buildSetGroup.Group | Where-Object RuleSetVersionPhiloteId | Group-Object RuleSetVersionPhiloteId | Sort-Object { & $toInt $_.Group[0].RuleSetMembershipSortOrder }, Name)) {
          $ruleVersions = @($ruleSetGroup.Group | Where-Object RuleVersionPhiloteId | Sort-Object { & $toInt $_.RuleVersionMembershipSortOrder } | ForEach-Object {
              [PSCustomObject]@{
                RuleVersionPhiloteId = [guid]$_.RuleVersionPhiloteId
                RulePhiloteId = [guid]$_.RulePhiloteId
                SortOrder = & $toInt $_.RuleVersionMembershipSortOrder
                RuleVersionSortOrder = & $toInt $_.RuleVersionSortOrder
                ContentSha256 = [string]$_.ContentSha256
              }
            })
          $ruleSetVersions.Add([PSCustomObject]@{
              RuleSetVersionPhiloteId = [guid]$ruleSetGroup.Name
              SortOrder = & $toInt $ruleSetGroup.Group[0].RuleSetMembershipSortOrder
              RuleSetVersionSortOrder = & $toInt $ruleSetGroup.Group[0].RuleSetVersionSortOrder
              RuleVersions = $ruleVersions
            })
        }
        $buildSetVersions.Add([PSCustomObject]@{
            BuildSetVersionPhiloteId = [guid]$buildSetGroup.Name
            SortOrder = & $toInt $buildSetGroup.Group[0].BuildSetSortOrder
            RuleSetVersions = @($ruleSetVersions)
          })
      }

      $snapshots = [System.Collections.Generic.List[object]]::new()
      foreach ($snapshot in ($snapshotRows | Sort-Object { & $toInt $_.SortOrder })) {
        $snapshotId = ([guid]$snapshot.RuleInstantiationVersionPhiloteId).ToString()
        $ruleVersionId = ([guid]$snapshot.RuleVersionPhiloteId).ToString()
        if (-not $ruleVersionIds.Contains($ruleVersionId)) {
          throw "RuleInstantiationVersion '$snapshotId' references out-of-graph RuleVersion '$ruleVersionId'."
        }

        $declarations = @($compositionRows | Where-Object { ([guid]$_.RuleInstantiationVersionPhiloteId).ToString() -eq $snapshotId })
        $declaredInputs = @($declarations | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.InputName) } |
            Group-Object InputName | ForEach-Object {
              $first = $_.Group[0]
              [PSCustomObject]@{
                PrimitiveName = [string]$first.PrimitiveName
                InputName = [string]$first.InputName
                TypeName = [string]$first.TypeName
                DefaultValue = $first.DefaultValue
                IsRequired = [bool]$first.IsRequired
              }
            } | Sort-Object InputName)
        $bindingInputs = @($declaredInputs | Where-Object PrimitiveName -CNE 'SourceLine')
        $bindings = @($bindingRows | Where-Object { ([guid]$_.RuleInstantiationVersionPhiloteId).ToString() -eq $snapshotId })
        foreach ($duplicate in @($bindings | Group-Object InputName | Where-Object Count -gt 1)) {
          throw "RuleInstantiationVersion '$snapshotId' has duplicate binding '$($duplicate.Name)'."
        }

        $declaredNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($declared in $bindingInputs) { [void]$declaredNames.Add($declared.InputName) }
        foreach ($binding in $bindings) {
          if (-not $declaredNames.Contains([string]$binding.InputName)) {
            throw "RuleInstantiationVersion '$snapshotId' has undeclared binding '$($binding.InputName)'."
          }
        }

        $resolvedBindings = [System.Collections.Generic.List[object]]::new()
        foreach ($declared in $bindingInputs) {
          $binding = @($bindings | Where-Object { $_.InputName -ceq $declared.InputName })
          $value = if ($binding.Count -eq 1) { $binding[0].InputValue } else { $declared.DefaultValue }
          if ([bool]$declared.IsRequired -and $null -eq $value) {
            throw "RuleInstantiationVersion '$snapshotId' is missing required binding '$($declared.InputName)'."
          }
          $resolvedBindings.Add([PSCustomObject]@{
              InputName = $declared.InputName
              InputValue = $value
              TypeName = $declared.TypeName
              UsedDefault = ($binding.Count -eq 0)
            })
        }

        $lines = @($sourceLineRows | Where-Object { ([guid]$_.RuleInstantiationVersionPhiloteId).ToString() -eq $snapshotId } | Sort-Object { & $toInt $_.Ordinal })
        for ($index = 0; $index -lt $lines.Count; $index++) {
          if ((& $toInt $lines[$index].Ordinal) -ne ($index + 1)) {
            throw "RuleInstantiationVersion '$snapshotId' has non-contiguous or duplicate source-line ordinals."
          }
        }
        foreach ($sourceLineDeclaration in @($declarations | Where-Object PrimitiveName -CEQ 'SourceLine' |
            Group-Object PrimitivePhiloteId | ForEach-Object { $_.Group[0] })) {
          $cardinality = [string]$sourceLineDeclaration.Cardinality
          $validCount = switch ($cardinality) {
            'One' { $lines.Count -eq 1 }
            'ZeroOrOne' { $lines.Count -le 1 }
            'OneOrMore' { $lines.Count -ge 1 }
            'ZeroOrMore' { $true }
            default { throw "RuleInstantiationVersion '$snapshotId' has unsupported SourceLine cardinality '$cardinality'." }
          }
          if (-not $validCount) {
            throw "RuleInstantiationVersion '$snapshotId' has $($lines.Count) source lines, violating SourceLine cardinality '$cardinality'."
          }
        }

        $snapshots.Add([PSCustomObject]@{
            RuleInstantiationVersionPhiloteId = [guid]$snapshot.RuleInstantiationVersionPhiloteId
            RuleInstantiationPhiloteId = [guid]$snapshot.RuleInstantiationPhiloteId
            RuleVersionPhiloteId = [guid]$snapshot.RuleVersionPhiloteId
            RulePhiloteId = [guid]$snapshot.RulePhiloteId
            VersionNumber = & $toInt $snapshot.VersionNumber
            VersionLabel = [string]$snapshot.VersionLabel
            SortOrder = & $toInt $snapshot.SortOrder
            EffectiveFrom = $snapshot.EffectiveFrom
            DeclaredInputs = $declaredInputs
            Bindings = @($resolvedBindings)
            SourceLines = @($lines | ForEach-Object {
                [PSCustomObject]@{ Ordinal = & $toInt $_.Ordinal; LineText = [string]$_.LineText; LineEnding = [string]$_.LineEnding }
              })
          })
      }

      [PSCustomObject]@{
        InstantiationVersionPhiloteId = $InstantiationVersionPhiloteId
        InstantiationPhiloteId = [guid]$graphRows[0].InstantiationPhiloteId
        VersionNumber = & $toInt $graphRows[0].InstantiationVersionNumber
        VersionLabel = [string]$graphRows[0].InstantiationVersionLabel
        BuildSetVersions = @($buildSetVersions)
        RuleInstantiations = @($snapshots)
        ManifestationArtifacts = @($artifactRows)
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $_.Exception.Message -Tag 'Error'
      throw
    } finally {
      if (-not $isCallerOwned -and $null -ne $resolvedConnection) {
        try { $resolvedConnection.Close() } catch { }
        try { $resolvedConnection.Dispose() } catch { }
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
  }
}

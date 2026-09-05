function ConvertTo-ContentSummaryDependencyDataTable {
  [CmdletBinding()]
  param(
    [AllowEmptyCollection()]
    [object[]] $Dependencies = @()
  )

  begin {
    $fn = 'ConvertTo-ContentSummaryDependencyDataTable'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'
  }

  process {
    $table = [System.Data.DataTable]::new()
    [void]$table.Columns.Add('DependencyOrdinal', [int])
    [void]$table.Columns.Add('DependencyKindCode', [string])
    [void]$table.Columns.Add('SourceArtifactVersionId', [guid])
    [void]$table.Columns.Add('ExternalReferenceKindCode', [string])
    [void]$table.Columns.Add('ExternalReferenceSha256', [byte[]])
    [void]$table.Columns.Add('EvidenceEntityId', [guid])
    foreach ($dependency in @($Dependencies)) {
      $names = @($dependency.PSObject.Properties.Name)
      $expected = @(
        'DependencyOrdinal', 'DependencyKindCode', 'SourceArtifactVersionId',
        'ExternalReferenceKindCode', 'ExternalReferenceSha256', 'EvidenceEntityId'
      )
      if (($names -join ',') -ne ($expected -join ',')) {
        throw 'CS-REQ-001: dependency row does not match the frozen TVP shape.'
      }
      $row = $table.NewRow()
      foreach ($name in $expected) {
        $row[$name] = if ($null -eq $dependency.$name) { [DBNull]::Value } else { $dependency.$name }
      }
      [void]$table.Rows.Add($row)
    }
    return ,$table
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}

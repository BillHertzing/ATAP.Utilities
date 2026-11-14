function ConvertFrom-MaintenanceWindowDataReader {
  <#
  .SYNOPSIS
    Reads every result set of an open IDataReader into the shared capture shape.
  .DESCRIPTION
    Same row rule as the reviewed read-only reader (senior1\Successor\Invoke-ReadOnlyBeforeSample.ps1,
    lines 186-191), so outputs are interchangeable with the packets' captures and comparers:
      - one ordered dictionary per row, keyed by the reader's column names in column order;
      - DBNull becomes $null; every other value is the reader's GetValue result, unconverted;
      - one array per result set, in order (an empty set stays an empty array).
    Rows are appended to the caller's ResultSets list as they are read, so the sets read before a
    SQL error (for example a THROW after the evidence sets) survive the exception.
  .PARAMETER Reader
    An open System.Data.IDataReader positioned before its first result set.
  .PARAMETER ResultSets
    The list to fill (System.Collections.Generic.List[object]).
  .OUTPUTS
    None; fills ResultSets.
  .EXAMPLE
    ConvertFrom-MaintenanceWindowDataReader -Reader $r -ResultSets $list
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines. DB-Runner-S1-Foundation.
  .LINK
    Invoke-MaintenanceSqlDataSet
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][System.Data.IDataReader]$Reader,
    [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$ResultSets
  )
  begin { $fn = 'ConvertFrom-MaintenanceWindowDataReader'; $mn = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell' }
  process {
    do {
      $rows = [System.Collections.Generic.List[object]]::new()
      $ResultSets.Add($rows)
      while ($Reader.Read()) {
        $row = [ordered]@{}
        for ($i = 0; $i -lt $Reader.FieldCount; $i++) {
          $row[$Reader.GetName($i)] = if ($Reader.IsDBNull($i)) { $null } else { $Reader.GetValue($i) }
        }
        $rows.Add($row)
      }
    } while ($Reader.NextResult())
  }
  end {}
}

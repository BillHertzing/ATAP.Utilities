function New-CoordRecoverySnapshot {
  # Pure extraction of the existing lossless Coordination-export-v1 construction.
  [CmdletBinding()]
  [OutputType([byte[]])]
  param(
    [Parameter(Mandatory)][byte[]]$StateBytes,
    [Parameter(Mandatory)][byte[]]$CustodyBytes,
    [Parameter(Mandatory)][System.Collections.IDictionary]$ObservedOutputs
  )
  $record = ConvertFrom-CoordElement (Read-CoordJsonBytes $CustodyBytes)
  $state = Read-CoordJsonBytes $StateBytes
  $snapshot = ConvertTo-CoordElement @{
    schemaVersion = 'Coordination-export-v1'; resourceId = $record.resourceId; lineageId = $record.lineageId
    generation = $record.generation; committedRevision = $state.GetProperty('committedRevision').GetString()
    stateBytesBase64 = [Convert]::ToBase64String($StateBytes); stateDigest = Get-CoordHash $StateBytes
    custodyBytesBase64 = [Convert]::ToBase64String($CustodyBytes); custodyDigest = Get-CoordHash $CustodyBytes
    observedOutputs = $ObservedOutputs
  }
  return ,(ConvertTo-CoordStateBytes $snapshot)
}

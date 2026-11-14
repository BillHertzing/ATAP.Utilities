function ConvertTo-MaintenanceWindowCaptureJson {
  <#
  .SYNOPSIS
    Serializes a capture document exactly as the shared readers do: ConvertTo-Json -Depth 24, LF line endings.
  .DESCRIPTION
    The comparers (Compare-SourceToClone and the others) read {ResultSets:[[row,...],...]} produced by the
    reviewed reader with ConvertTo-Json -Depth 24 and CRLF replaced by LF. Using the same call keeps the
    captures from the runner and from the operator's by-hand capture byte-compatible in shape. The
    caller writes the returned text as UTF-8 without a BOM.
  .PARAMETER Document
    An ordered dictionary containing at least ResultSets.
  .OUTPUTS
    System.String
  .EXAMPLE
    ConvertTo-MaintenanceWindowCaptureJson -Document $doc
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines. DB-Runner-S1-Foundation.
  .LINK
    Write-MaintenanceWindowEvidenceFile
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param([Parameter(Mandatory)][Collections.IDictionary]$Document)
  begin { $fn = 'ConvertTo-MaintenanceWindowCaptureJson'; $mn = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell' }
  process {
    if (-not $Document.Contains('ResultSets')) { throw 'MaintenanceWindowCaptureShapeInvalid|ResultSets' }
    ($Document | ConvertTo-Json -Depth 24).Replace("`r`n", "`n")
  }
  end {}
}

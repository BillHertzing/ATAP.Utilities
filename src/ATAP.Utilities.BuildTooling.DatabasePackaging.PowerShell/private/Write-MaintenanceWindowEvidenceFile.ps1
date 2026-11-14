function Write-MaintenanceWindowEvidenceFile {
  <#
  .SYNOPSIS
    Writes one evidence file once (CreateNew, UTF-8 without BOM) and returns its SHA-256.
  .DESCRIPTION
    Refuses to overwrite: an existing file throws (MaintenanceWindowEvidenceExists). The hash is computed
    from the bytes written, straight after writing, so receipts can pin it.
  .PARAMETER Path
    Target file path.
  .PARAMETER Text
    File content.
  .OUTPUTS
    PSCustomObject with Path, Sha256, Length.
  .EXAMPLE
    Write-MaintenanceWindowEvidenceFile -Path $p -Text $json
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines. DB-Runner-S1-Foundation.
  .LINK
    ConvertTo-MaintenanceWindowCaptureJson
  #>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([pscustomobject])]
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][AllowEmptyString()][string]$Text)
  begin { $fn = 'Write-MaintenanceWindowEvidenceFile'; $mn = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell' }
  process {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $sha = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
    if (-not $PSCmdlet.ShouldProcess($Path, 'Write once-only LF maintenance evidence file')) { return [pscustomobject]@{ Path = $Path; Sha256 = $sha; Length = $bytes.Length; Written = $false } }
    try { $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None) }
    catch [IO.IOException] { throw "MaintenanceWindowEvidenceExists|$Path" }
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Wrote evidence $Path ($sha)"
    [pscustomobject]@{ Path = $Path; Sha256 = $sha; Length = $bytes.Length; Written = $true }
  }
  end {}
}

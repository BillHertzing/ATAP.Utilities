function Get-EnvelopeMember {
  <#
  .SYNOPSIS
    Reads one named member from a response envelope that may be a hashtable or an object.

  .DESCRIPTION
    Task 15.183.B02 extracted this from the `begin` block of Write-GatherCallRecord
    unchanged. `gather-content-summary` responses reach the recorder as a PSCustomObject,
    a hashtable, or a parsed JSON string depending on the caller, so member access needs
    one path that handles all three and returns `$null` for an absent member rather than
    throwing.

    Returning `$null` for absent is what lets the recorder record absence AS absence: a
    missing envelope key becomes a null record field, never an inferred or placeholder
    value.

  .PARAMETER Envelope
    The envelope. `$null` yields `$null`.

  .PARAMETER Name
    The member name to read.

  .OUTPUTS
    The member value, or `$null` when the envelope is null or has no such member.

  .EXAMPLE
    Get-EnvelopeMember -Envelope $response -Name 'status'

  .NOTES
    Task 15.183.B02 (Sprint 0015, Stream M). Private helper for Write-GatherCallRecord.
  #>
  param(
    [Parameter(Mandatory = $true)][AllowNull()][object]$Envelope,
    [Parameter(Mandatory = $true)][string]$Name
  )
  if ($null -eq $Envelope) { return $null }
  if ($Envelope -is [System.Collections.IDictionary]) {
    if ($Envelope.Contains($Name)) { return $Envelope[$Name] }
    return $null
  }
  $prop = $Envelope.PSObject.Properties[$Name]
  if ($null -eq $prop) { return $null }
  return $prop.Value
}

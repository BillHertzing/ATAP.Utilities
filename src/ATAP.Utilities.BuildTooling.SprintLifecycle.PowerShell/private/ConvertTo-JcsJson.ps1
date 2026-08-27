function ConvertTo-JcsJson {
  <#
  .SYNOPSIS
    Serializes a value to RFC 8785 (JCS) canonical JSON.

  .DESCRIPTION
    Task 15.183.B02 extracted this from the `begin` block of Write-GatherCallRecord,
    where it lived only because `private/` was outside the implementing unit's writable
    scope. Its behaviour is unchanged, byte for byte: this is a relocation, not a rewrite.

    Covers the value subset a gather-call record uses: null, boolean, integer, floating
    point, string, array, and object. Object keys are sorted by UTF-16 code unit
    (`StringComparer.Ordinal`), which is both the JCS rule and the rule that makes a
    record line reproducible by a caller that has no serializer at all - the
    `gather-content-summary` agent authors its records with create-file and no terminal,
    so key order has to be derivable by hand rather than emergent from a library.

    The output is the format's source of truth. Changing it changes the record format,
    which `gather-call-record.contract.v1.md` governs.

  .PARAMETER Value
    The value to serialize. `$null` serializes to the literal `null`.

  .OUTPUTS
    [string] - the canonical JSON text, minified.

  .EXAMPLE
    ConvertTo-JcsJson -Value ([ordered]@{ b = 1; a = 'x' })

    Returns `{"a":"x","b":1}` - keys ordinally sorted regardless of insertion order.

  .NOTES
    Task 15.183.B02 (Sprint 0015, Stream M). Private helper for Write-GatherCallRecord.
    Throws for NaN and Infinity, which have no JSON representation.
  #>
  param([Parameter(Mandatory = $false)][AllowNull()][object]$Value)

  if ($null -eq $Value) { return 'null' }

  if ($Value -is [string]) {
    # if/elseif rather than switch: `continue` inside a switch nested in a loop has
    # loop-continuation semantics that are easy to get subtly wrong, and a mis-escaped
    # control character would produce an unparseable record line.
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('"')
    foreach ($ch in $Value.ToCharArray()) {
      $code = [int]$ch
      if ($code -eq 0x22) { [void]$sb.Append('\"') }
      elseif ($code -eq 0x5C) { [void]$sb.Append('\\') }
      elseif ($code -eq 0x08) { [void]$sb.Append('\b') }
      elseif ($code -eq 0x09) { [void]$sb.Append('\t') }
      elseif ($code -eq 0x0A) { [void]$sb.Append('\n') }
      elseif ($code -eq 0x0C) { [void]$sb.Append('\f') }
      elseif ($code -eq 0x0D) { [void]$sb.Append('\r') }
      elseif ($code -lt 0x20) { [void]$sb.Append(('\u{0:x4}' -f $code)) }
      else { [void]$sb.Append($ch) }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
  }

  if ($Value -is [bool]) { return $(if ($Value) { 'true' } else { 'false' }) }

  if ($Value -is [int] -or $Value -is [long] -or $Value -is [int16] -or $Value -is [byte]) {
    return ([long]$Value).ToString([System.Globalization.CultureInfo]::InvariantCulture)
  }

  if ($Value -is [double] -or $Value -is [single] -or $Value -is [decimal]) {
    $d = [double]$Value
    if ([double]::IsNaN($d) -or [double]::IsInfinity($d)) {
      throw "ConvertTo-JcsJson: NaN and Infinity have no JSON representation."
    }
    if ($d -eq [Math]::Floor($d) -and [Math]::Abs($d) -lt 1e15) {
      return ([long]$d).ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }
    return $d.ToString('R', [System.Globalization.CultureInfo]::InvariantCulture)
  }

  if ($Value -is [System.Collections.IDictionary]) {
    $keys = [string[]]@($Value.Keys)
    [array]::Sort($keys, [System.StringComparer]::Ordinal)
    $parts = foreach ($k in $keys) {
      '{0}:{1}' -f (ConvertTo-JcsJson -Value $k), (ConvertTo-JcsJson -Value $Value[$k])
    }
    return '{' + ($parts -join ',') + '}'
  }

  # Compared by full type name rather than with -is, because -is unwraps the PSObject
  # adapter and the result for a PSCustomObject is not dependable across hosts.
  if ($Value.GetType().FullName -eq 'System.Management.Automation.PSCustomObject') {
    $keys = [string[]]@($Value.PSObject.Properties.Name)
    [array]::Sort($keys, [System.StringComparer]::Ordinal)
    $parts = foreach ($k in $keys) {
      '{0}:{1}' -f (ConvertTo-JcsJson -Value $k), (ConvertTo-JcsJson -Value $Value.$k)
    }
    return '{' + ($parts -join ',') + '}'
  }

  if ($Value -is [System.Collections.IEnumerable]) {
    $parts = foreach ($item in $Value) { ConvertTo-JcsJson -Value $item }
    return '[' + ($parts -join ',') + ']'
  }

  # Anything else is recorded by its invariant string form rather than dropped, so an
  # unexpected type degrades to a readable value instead of a silent null.
  return (ConvertTo-JcsJson -Value ([string]$Value))
}

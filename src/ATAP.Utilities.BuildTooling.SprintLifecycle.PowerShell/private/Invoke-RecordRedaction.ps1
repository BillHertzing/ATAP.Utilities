function Invoke-RecordRedaction {
  <#
  .SYNOPSIS
    Replaces detected secret values in text with a visible `[REDACTED:<kind>]` marker.

  .DESCRIPTION
    Task 15.183.B02 extracted this from the `begin` block of Write-GatherCallRecord
    unchanged, including its pattern list and its single-pass overlap resolution.

    Implements `gather-call-record.contract.v1.md` section 5. Redaction is VISIBLE: a
    detected value becomes the literal `[REDACTED:<kind>]` and is never silently deleted,
    because a silently shortened prompt is indistinguishable from a short one. Detection
    is deliberately biased toward over-redaction - a false redaction costs one unreadable
    fragment, a false pass writes a secret into a durable artifact. That asymmetry got
    sharper at Task 15.183.B02: these records now live in `_Planning` and merge to stable
    rather than being deleted with `_generated` at sprint end, so a missed secret persists
    indefinitely.

    Patterns run most-specific first over the ORIGINAL text, collecting spans and
    resolving overlaps first-pattern-wins, so a token is counted once and keeps the kind
    of the most specific pattern that claimed it.

  .PARAMETER Text
    The text to scan. Null and empty are returned unchanged with a count of 0.

  .OUTPUTS
    [PSCustomObject] with `Text` (the redacted text) and `Count` (distinct secrets found).

  .EXAMPLE
    (Invoke-RecordRedaction -Text 'Password=hunter2 and more').Text

    Returns '[REDACTED:connection-string] and more' - the trailing text survives.

  .NOTES
    Task 15.183.B02 (Sprint 0015, Stream M). Private helper for Write-GatherCallRecord.
    SecretNames are permitted; secret VALUES are not.
  #>
  param([Parameter(Mandatory = $false)][AllowNull()][AllowEmptyString()][string]$Text)

  if ([string]::IsNullOrEmpty($Text)) {
    return [PSCustomObject]@{ Text = $Text; Count = 0 }
  }

  $patterns = @(
    @{ Kind = 'key'; Pattern = '-----BEGIN[A-Z ]*PRIVATE KEY-----[\s\S]*?-----END[A-Z ]*PRIVATE KEY-----' },
    @{ Kind = 'key'; Pattern = '-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----' },
    # Only the genuinely sensitive keys of a connection string. `Server`, `Data
    # Source`, `Initial Catalog`, and `User Id` are not secret VALUES, and matching
    # them bought no safety while causing real collateral: the value class runs to the
    # next `;` or end of line, so a match on a trailing non-secret segment swallowed
    # the rest of the prompt — including text a later pattern would have classified
    # more precisely. Over-redaction is the correct direction, but not at the cost of
    # mislabelling every following token as part of a connection string.
    # The value class stops at whitespace as well as at `;`. Running to the next `;` or
    # end of line meant a prompt like `prefix Password=x suffix` lost ` suffix` along
    # with the secret — a silent deletion, which contract 5.2 forbids: redaction must be
    # VISIBLE, because a silently shortened prompt is indistinguishable from a short
    # one. Secret values in connection strings do not contain spaces, so bounding at
    # whitespace costs no coverage; a value that genuinely contained a space would have
    # its leading portion redacted and the remainder is caught by the credential
    # pattern below.
    @{ Kind = 'connection-string'; Pattern = '(?i)\b(?:password|pwd|accountkey|shared\s*access\s*key)\s*=\s*[^;''"\s\r\n]+' },
    @{ Kind = 'token'; Pattern = '(?i)\bbearer\s+[A-Za-z0-9._~+/\-]{16,}=*' },
    @{ Kind = 'token'; Pattern = '\bgh[pousr]_[A-Za-z0-9]{16,}' },
    @{ Kind = 'token'; Pattern = '\beyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}' },
    @{ Kind = 'token'; Pattern = '(?i)\bxox[baprs]-[A-Za-z0-9\-]{10,}' },
    @{ Kind = 'credential'; Pattern = '(?i)\b(?:password|passwd|pass|secret|apikey|api[_\-]?key|access[_\-]?key|client[_\-]?secret|token|credential)\s*[:=]\s*["'']?[^\s"''`;,\r\n]{6,}' },
    @{ Kind = 'secret'; Pattern = '(?i)\b(?:AKIA|ASIA)[A-Z0-9]{16}\b' }
  )

  # SINGLE PASS over the ORIGINAL text, first-pattern-wins on overlap.
  #
  # Applying the patterns in sequence, each to the output of the last, double-counts
  # and mislabels: a `token: ghp_xxx` fragment is redacted once by the token pattern,
  # and the generic credential pattern then matches the SURVIVING `token: [REDACTED..]`
  # and redacts it again. That inflates `redactionCount` — which consumers use to
  # decide whether a record needs review — and overwrites the precise `token` kind with
  # the vague `credential` one. Collecting spans against the original text and
  # resolving overlaps in pattern order fixes both: the count is exactly the number of
  # distinct secrets found, and each span keeps the kind of the most specific pattern
  # that claimed it.
  $spans = [System.Collections.Generic.List[object]]::new()
  foreach ($p in $patterns) {
    foreach ($m in [regex]::Matches($Text, $p.Pattern)) {
      $start = $m.Index
      $end = $m.Index + $m.Length
      $overlaps = $false
      foreach ($s in $spans) {
        if ($start -lt $s.End -and $end -gt $s.Start) { $overlaps = $true; break }
      }
      if (-not $overlaps) {
        [void]$spans.Add([PSCustomObject]@{ Start = $start; End = $end; Kind = $p.Kind })
      }
    }
  }

  if ($spans.Count -eq 0) {
    return [PSCustomObject]@{ Text = $Text; Count = 0 }
  }

  $ordered = @($spans | Sort-Object -Property Start)
  $sb = [System.Text.StringBuilder]::new()
  $cursor = 0
  foreach ($s in $ordered) {
    [void]$sb.Append($Text.Substring($cursor, $s.Start - $cursor))
    [void]$sb.Append('[REDACTED:{0}]' -f $s.Kind)
    $cursor = $s.End
  }
  [void]$sb.Append($Text.Substring($cursor))

  return [PSCustomObject]@{ Text = $sb.ToString(); Count = $ordered.Count }
}

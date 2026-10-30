function ConvertTo-CoordCanonicalRequest {
  <#
  .SYNOPSIS
    Strictly validates and canonicalizes one request envelope without admitting it.
  .DESCRIPTION
    Uses the module-owned, byte-pinned accepted Draft7 request-v1 schema. Only the
    request object is canonicalized; digest and transport are excluded. Rejects
    invalid UTF-8/JSON, escaped unpaired surrogates, duplicate decoded object names,
    noninteger numeric lexemes, schema violations and unequal lowercase SHA256.

    Returns one Stage=CanonicalizedNotAdmitted snapshot with an independent cloned
    JsonElement Request, CanonicalBytes, Digest and SchemaSha256. Does not authorize,
    register, resolve paths, validate revision/causality/custody, queue or persist.
    MaxRequestBytes is supplied by the caller; no production limit is selected here.
    Errors contain a fixed local failure code, never input or schema diagnostics.

    The accepted v1 schema permits no numeric, boolean or null value positions.
    Primitive serialization follows S1 (including -0 to 0), but cannot bypass schema.
    Object names sort by uppercase encoded-byte hex with Ordinal comparison, which
    gives unsigned UTF-8 lexicographic ordering. Arrays preserve their original order.
    Valid scalar strings are literal except quote/backslash and lowercase six-character
    control escapes. No Unicode normalization, case folding or path rewriting occurs.
  .PARAMETER EnvelopeBytes
    Exact UTF-8 envelope bytes. A private copy is parsed. JSON comments, BOM, trailing
    commas/values and malformed byte sequences are rejected rather than normalized.
  .PARAMETER MaxRequestBytes
    Positive caller-supplied maximum envelope byte length. Not a measured host default.
  .PARAMETER DeferDigestComparison
    Private retry-classifier use only. Default remains strict. When set, schema and
    canonical checks still run; return SuppliedDigest/DigestMatches without rejecting
    a mismatch so S3 existing-key identity comparison can run first.
  .OUTPUTS
    PSCustomObject: Stage, Request (JsonElement clone), CanonicalBytes (byte[]),
    Digest (lowercase SHA256), SchemaSha256 (lowercase accepted schema byte hash).
  .EXAMPLE
    ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $callerLimit
  .NOTES
    Private source slice only. Fixed failure codes are local diagnostics, not queue
    outcomes or the complete Test-CoordRequest admission/retained-retry protocol.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [AllowEmptyCollection()]
    [byte[]]$EnvelopeBytes,

    [Parameter(Mandatory)]
    [ValidateRange(1, 9223372036854775807)]
    [long]$MaxRequestBytes,

    [Parameter()]
    [switch]$DeferDigestComparison
  )

  begin {
    $fn = 'ConvertTo-CoordCanonicalRequest'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $null = Get-Command -Name 'Write-PSFMessage' -ErrorAction Stop
    $null = Get-Command -Name 'Test-Json' -ErrorAction Stop
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Canonicalizing request without admission'
    $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
    $schemaPath = Join-Path $PSScriptRoot '../schemas/request-v1.schema.json'
    if ($null -ne $MyInvocation.MyCommand.Module -and $MyInvocation.MyCommand.Module.Name -ceq $mn) {
      $schemaPath = Join-Path $MyInvocation.MyCommand.Module.ModuleBase 'schemas/request-v1.schema.json'
    }
  }

  process {
    $document = $null
    $failureCode = 'SizeExceeded'
    try {
      if ($EnvelopeBytes.LongLength -gt $MaxRequestBytes) { throw 'Envelope byte limit exceeded.' }
      [byte[]]$inputBytes = $EnvelopeBytes.Clone()
      $failureCode = 'InvalidUtf8'
      $text = $utf8.GetString($inputBytes)
      $failureCode = 'InvalidJson'
      $jsonOptions = [System.Text.Json.JsonDocumentOptions]::new()
      $jsonOptions.AllowTrailingCommas = $false
      $jsonOptions.CommentHandling = [System.Text.Json.JsonCommentHandling]::Disallow
      $document = [System.Text.Json.JsonDocument]::Parse($text, $jsonOptions)

      # JsonDocument preserves escape lexemes. Validate surrogate pairs before any
      # decoded name/value access, including names and transport strings.
      $failureCode = 'InvalidUnicode'
      foreach ($token in [regex]::Matches($text, '"(?:[^"\\\x00-\x1f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*"')) {
        $raw = $token.Value
        for ($i = 1; $i -lt $raw.Length - 1; $i++) {
          if ($raw[$i] -ne [char]0x5C) { continue }
          $i++
          if ($raw[$i] -cne 'u') { continue }
          $unit = [System.Convert]::ToInt32($raw.Substring($i + 1, 4), 16)
          $i += 4
          if ($unit -ge 0xD800 -and $unit -le 0xDBFF) {
            if ($i + 6 -ge $raw.Length -or $raw.Substring($i + 1, 2) -cne '\u') {
              throw 'Unpaired high surrogate.'
            }
            $low = [System.Convert]::ToInt32($raw.Substring($i + 3, 4), 16)
            if ($low -lt 0xDC00 -or $low -gt 0xDFFF) { throw 'Unpaired high surrogate.' }
            $i += 6
          } elseif ($unit -ge 0xDC00 -and $unit -le 0xDFFF) {
            throw 'Unpaired low surrogate.'
          }
        }
      }

      $pending = [System.Collections.Generic.Stack[System.Text.Json.JsonElement]]::new()
      $pending.Push($document.RootElement)
      while ($pending.Count -gt 0) {
        $element = $pending.Pop()
        switch ($element.ValueKind.ToString()) {
          'Object' {
            $failureCode = 'DuplicateMember'
            $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
            foreach ($property in $element.EnumerateObject()) {
              if (-not $names.Add($property.Name)) { throw 'Duplicate decoded member.' }
              $pending.Push($property.Value)
            }
          }
          'Array' {
            foreach ($item in $element.EnumerateArray()) { $pending.Push($item) }
          }
          'Number' {
            $failureCode = 'InvalidNumber'
            if (-not [regex]::IsMatch($element.GetRawText(), '\A-?(?:0|[1-9][0-9]*)\z')) {
              throw 'Noninteger JSON numeric lexeme.'
            }
          }
        }
      }

      $failureCode = 'SchemaUnavailable'
      $schemaBytes = [System.IO.File]::ReadAllBytes($schemaPath)
      $schemaSha256 = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($schemaBytes)).ToLowerInvariant()
      if ($schemaSha256 -cne '6266286dccf7a499ff332e0cc2384b7807eee477aecb9f9da4b7f45bfa261cde') {
        throw 'Accepted schema bytes do not match.'
      }
      $schemaText = $utf8.GetString($schemaBytes)
      $failureCode = 'SchemaInvalid'
      $schemaErrors = @()
      $shapeValid = Test-Json -Json $text -Schema $schemaText -ErrorAction SilentlyContinue -ErrorVariable schemaErrors
      if ($shapeValid -ne $true -or $schemaErrors.Count -gt 0) { throw 'Envelope does not satisfy schema.' }

      $failureCode = 'CanonicalizationFailed'
      $request = $document.RootElement.GetProperty('request')
      $builder = [System.Text.StringBuilder]::new()
      $appendString = {
        param([string]$value)
        $null = $builder.Append('"')
        foreach ($character in $value.ToCharArray()) {
          $code = [int]$character
          if ($code -lt 0x20) {
            $null = $builder.Append('\u' + $code.ToString('x4', [System.Globalization.CultureInfo]::InvariantCulture))
          } elseif ($character -eq [char]0x22) {
            $null = $builder.Append('\"')
          } elseif ($character -eq [char]0x5C) {
            $null = $builder.Append('\\')
          } else {
            $null = $builder.Append($character)
          }
        }
        $null = $builder.Append('"')
      }
      $writeCanonical = {
        param([System.Text.Json.JsonElement]$value)
        switch ($value.ValueKind.ToString()) {
          'Object' {
            $properties = [System.Collections.Generic.Dictionary[string, System.Text.Json.JsonProperty]]::new([System.StringComparer]::Ordinal)
            foreach ($property in $value.EnumerateObject()) {
              $key = [System.Convert]::ToHexString($utf8.GetBytes($property.Name))
              $properties.Add($key, $property)
            }
            [string[]]$keys = @($properties.Keys)
            [System.Array]::Sort($keys, [System.StringComparer]::Ordinal)
            $null = $builder.Append('{')
            $first = $true
            foreach ($key in $keys) {
              if (-not $first) { $null = $builder.Append(',') }
              $first = $false
              $property = $properties[$key]
              & $appendString $property.Name
              $null = $builder.Append(':')
              & $writeCanonical $property.Value
            }
            $null = $builder.Append('}')
          }
          'Array' {
            $null = $builder.Append('[')
            $first = $true
            foreach ($item in $value.EnumerateArray()) {
              if (-not $first) { $null = $builder.Append(',') }
              $first = $false
              & $writeCanonical $item
            }
            $null = $builder.Append(']')
          }
          'String' { & $appendString ($value.GetString()) }
          'Number' {
            $number = $value.GetRawText()
            if ($number -ceq '-0') { $number = '0' }
            $null = $builder.Append($number)
          }
          'True' { $null = $builder.Append('true') }
          'False' { $null = $builder.Append('false') }
          'Null' { $null = $builder.Append('null') }
          default { throw 'Unsupported JSON value.' }
        }
      }
      & $writeCanonical $request
      [byte[]]$canonicalBytes = $utf8.GetBytes($builder.ToString())
      $digest = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($canonicalBytes)).ToLowerInvariant()
      $failureCode = 'DigestMismatch'
      $suppliedDigest = $document.RootElement.GetProperty('digest').GetString()
      $digestMatches = $suppliedDigest -ceq $digest
      if (-not $DeferDigestComparison -and -not $digestMatches) { throw 'Digest mismatch.' }

      $canonicalResult = [PSCustomObject]@{
        Stage = 'CanonicalizedNotAdmitted'
        Request = $request.Clone()
        CanonicalBytes = $canonicalBytes
        Digest = $digest
        SchemaSha256 = $schemaSha256
      }
      if ($DeferDigestComparison) {
        $canonicalResult.PSObject.Properties.Add([PSNoteProperty]::new('SuppliedDigest', $suppliedDigest))
        $canonicalResult.PSObject.Properties.Add([PSNoteProperty]::new('DigestMatches', $digestMatches))
      }
      $canonicalResult
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Request canonicalization rejected'
      throw [System.IO.InvalidDataException]::new("Coordination request rejected ($failureCode).")
    } finally {
      if ($null -ne $document) { $document.Dispose() }
    }
  }

  end {}
}

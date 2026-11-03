function Get-CoordHash {
  param([Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Bytes)
  [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
}
function ConvertFrom-CoordElement {
  param([Parameter(Mandatory)][Text.Json.JsonElement]$Element)
  switch ($Element.ValueKind.ToString()) {
    'Object' {
      $value = [ordered]@{}
      foreach ($p in $Element.EnumerateObject()) { $value.Add($p.Name, (ConvertFrom-CoordElement $p.Value)) }
      return $value
    }
    'Array' {
      $value = @(foreach ($item in $Element.EnumerateArray()) { ConvertFrom-CoordElement $item })
      return ,$value
    }
    'String' { return $Element.GetString() }
    'Number' { return $Element.GetInt64() }
    'True' { return $true }
    'False' { return $false }
    'Null' { return $null }
    default { throw 'UnsupportedJsonValue' }
  }
}

function ConvertTo-CoordElement {
  param([Parameter(Mandatory)][AllowNull()]$Value)
  function encode($item) {
    if ($null -eq $item) { return 'null' }
    if ($item -is [Text.Json.JsonElement]) { return $item.GetRawText() }
    if ($item -is [Collections.IDictionary]) {
      $pairs = foreach ($key in $item.Keys) {
        (ConvertTo-Json -InputObject ([string]$key) -Compress) + ':' + (encode $item[$key])
      }
      return '{' + ($pairs -join ',') + '}'
    }
    if ($item -is [Collections.IEnumerable] -and $item -isnot [string]) {
      $items = foreach ($child in $item) { encode $child }
      return '[' + ($items -join ',') + ']'
    }
    ConvertTo-Json -InputObject $item -Depth 100 -Compress
  }
  $doc = [Text.Json.JsonDocument]::Parse((encode $Value))
  try { return $doc.RootElement.Clone() } finally { $doc.Dispose() }
}

function Read-CoordJsonBytes {
  param([Parameter(Mandatory)][byte[]]$Bytes)
  $utf8 = [Text.UTF8Encoding]::new($false, $true)
  function check($element) {
    if ($element.ValueKind -eq [Text.Json.JsonValueKind]::Object) {
      $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($p in $element.EnumerateObject()) {
        $null = $utf8.GetBytes($p.Name)
        if (-not $seen.Add($p.Name)) { throw 'DuplicateJsonMember' }
        check $p.Value
      }
    } elseif ($element.ValueKind -eq [Text.Json.JsonValueKind]::Array) {
      foreach ($v in $element.EnumerateArray()) { check $v }
    } elseif ($element.ValueKind -eq [Text.Json.JsonValueKind]::String) {
      $null = $utf8.GetBytes($element.GetString())
    }
  }
  $doc = [Text.Json.JsonDocument]::Parse($utf8.GetString($Bytes))
  try { check $doc.RootElement; $doc.RootElement.Clone() } finally { $doc.Dispose() }
}

function Get-CoordMembers {
  param([Parameter(Mandatory)][Text.Json.JsonElement]$Element)
  $result = [ordered]@{}
  foreach ($p in $Element.EnumerateObject()) { $result.Add($p.Name, $p.Value.Clone()) }
  return $result
}

function ConvertTo-CoordStateBytes {
  # Same fourteen-field projection, UTF8 name order and scalar rules as Save/Complete.
  param([Parameter(Mandatory)][Text.Json.JsonElement]$Element, [switch]$Logical)
  $utf8 = [Text.UTF8Encoding]::new($false, $true)
  $builder = [Text.StringBuilder]::new()
  function quoted([string]$value) {
    $null = $builder.Append('"')
    foreach ($ch in $value.ToCharArray()) {
      switch ([int]$ch) {
        34 { $null = $builder.Append('\"') }
        92 { $null = $builder.Append('\\') }
        default {
          if ([int]$ch -lt 32) { $null = $builder.Append('\u' + ([int]$ch).ToString('x4')) }
          else { $null = $builder.Append($ch) }
        }
      }
    }
    $null = $builder.Append('"')
  }
  function emit($value, $topNames) {
    switch ($value.ValueKind.ToString()) {
      'Object' {
        $names = [Collections.Generic.SortedDictionary[string, string]]::new([StringComparer]::Ordinal)
        foreach ($p in $value.EnumerateObject()) { $names.Add([Convert]::ToHexString($utf8.GetBytes($p.Name)), $p.Name) }
        $keys = if ($null -ne $topNames) { $topNames } else { $names.Values }
        $null = $builder.Append('{'); $separator = ''
        foreach ($key in $keys) {
          $null = $builder.Append($separator); quoted $key; $null = $builder.Append(':')
          emit ($value.GetProperty($key)) $null; $separator = ','
        }
        $null = $builder.Append('}')
      }
      'Array' {
        $null = $builder.Append('['); $separator = ''
        foreach ($v in $value.EnumerateArray()) { $null = $builder.Append($separator); emit $v $null; $separator = ',' }
        $null = $builder.Append(']')
      }
      'String' { quoted ($value.GetString()) }
      default { $null = $builder.Append($value.GetRawText()) }
    }
  }
  $fields = if ($Logical) {
    @('schemaVersion', 'resourceId', 'lineageId', 'registeredRoots', 'generation',
      'committedRevision', 'committedOutputManifest', 'custodyEvidence',
      'compatibilityEvidence', 'admissionEvidence', 'requests', 'claims', 'reservations', 'mutationAdmission')
  } else { $null }
  emit $Element $fields
  $null = $builder.Append([char]10)
  return ,$utf8.GetBytes($builder.ToString())
}

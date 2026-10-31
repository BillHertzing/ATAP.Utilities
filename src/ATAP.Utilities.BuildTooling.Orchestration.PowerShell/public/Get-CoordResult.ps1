function Get-CoordResult {
  <#
  .SYNOPSIS
    Reads an exact retained request and its original local journal evidence.
  .DESCRIPTION
    Caller first proves current result-read permission for the resource and all
    returned referenced data, authentic state lineage/grammar/custody and physical
    containment. This function checks retained integrity, not authenticity.

    StatePath is explicit and established. Found/NotFound are local observations,
    not result-v1 responses, admission, permission to reuse an ID or proof of the
    current published quartet. RecordedHead is stored data, separate from history.
    Historical Rejected requests need not satisfy executable-request grammar;
    their original JSON correspondence and terminal identity/digest are checked.
    External evidence is never resolved. No state, output or journal is written.

    Record, Operation and CommitReceipt are independently cloned JsonElements.
    Identity comparisons are ordinal. Needed codec helpers are exact copies from
    vetted Complete/Save; no numeric conversion or Unicode normalization occurs.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$StatePath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ResourceId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$RequestId
  )
  begin {
    $fn = 'Get-CoordResult'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $null = Get-Command Write-PSFMessage -ErrorAction Stop
    $null = Get-Command Test-Json -ErrorAction Stop
    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    $fields = @('schemaVersion', 'resourceId', 'lineageId', 'registeredRoots', 'generation',
      'committedRevision', 'committedOutputManifest', 'custodyEvidence',
      'compatibilityEvidence', 'admissionEvidence', 'requests', 'claims',
      'reservations', 'mutationAdmission')
    $schemaRoot = if ((Split-Path $PSScriptRoot -Leaf) -ieq 'public') { Split-Path $PSScriptRoot -Parent } else { $PSScriptRoot }
    function sameText([string]$Left, [string]$Right) {
      [string]::Equals($Left, $Right, [StringComparison]::Ordinal)
    }
    function sameBytes([byte[]]$Left, [byte[]]$Right) {
      sameText ([Convert]::ToBase64String($Left)) ([Convert]::ToBase64String($Right))
    }
    function sha([byte[]]$Bytes) {
      [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
    }
    function checkTree([System.Text.Json.JsonElement]$Element) {
      switch ($Element.ValueKind.ToString()) {
        'Object' {
          $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
          foreach ($property in $Element.EnumerateObject()) {
            $null = $utf8.GetBytes($property.Name)
            if (-not $seen.Add($property.Name)) { throw 'InvalidPreparedOperation' }
            checkTree $property.Value
          }
        }
        'Array' { foreach ($item in $Element.EnumerateArray()) { checkTree $item } }
        'String' { $null = $utf8.GetBytes($Element.GetString()) }
        'Undefined' { throw 'InvalidPreparedOperation' }
      }
    }
    function parseBytes([byte[]]$Bytes) {
      $document = $null
      try {
        $options = [System.Text.Json.JsonDocumentOptions]::new()
        $options.MaxDepth = [int]::MaxValue
        $document = [System.Text.Json.JsonDocument]::Parse($utf8.GetString($Bytes), $options)
        checkTree $document.RootElement
        return $document.RootElement.Clone()
      } catch { throw 'InvalidPreparedOperation' }
      finally { if ($null -ne $document) { $document.Dispose() } }
    }
    function shape([System.Text.Json.JsonElement]$Element, [string]$Schema) {
      checkTree $Element
      if (-not (Test-Json -Json $Element.GetRawText() -Schema $Schema -ErrorAction SilentlyContinue)) {
        throw 'InvalidPreparedOperation'
      }
    }
    function sortedNames([System.Text.Json.JsonElement]$Element) {
      $names = [Collections.Generic.List[string]]::new()
      foreach ($property in $Element.EnumerateObject()) { $names.Add($property.Name) }
      $names.Sort([Comparison[string]]{
        param($left, $right)
        $l = $utf8.GetBytes($left); $r = $utf8.GetBytes($right)
        for ($i = 0; $i -lt [Math]::Min($l.Length, $r.Length); $i++) {
          if ($l[$i] -ne $r[$i]) { return [int]$l[$i] - [int]$r[$i] }
        }
        return $l.Length - $r.Length
      })
      return $names.ToArray()
    }
    function jsonBytes([System.Text.Json.JsonElement]$Element, [string[]]$TopNames) {
      $builder = [Text.StringBuilder]::new()
      function quoted([string]$Value) {
        $null = $builder.Append('"')
        foreach ($ch in $Value.ToCharArray()) {
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
      function emit([System.Text.Json.JsonElement]$Value, [string[]]$Names) {
        switch ($Value.ValueKind.ToString()) {
          'Object' {
            $null = $builder.Append('{')
            $keys = if ($null -ne $Names) { @($Names) } else { @(sortedNames $Value) }
            $separator = ''
            foreach ($key in $keys) {
              $null = $builder.Append($separator); quoted $key
              $null = $builder.Append(':'); emit $Value.GetProperty($key) $null
              $separator = ','
            }
            $null = $builder.Append('}')
          }
          'Array' {
            $null = $builder.Append('['); $separator = ''
            foreach ($item in $Value.EnumerateArray()) {
              $null = $builder.Append($separator); emit $item $null; $separator = ','
            }
            $null = $builder.Append(']')
          }
          'String' { quoted $Value.GetString() }
          default { $null = $builder.Append($Value.GetRawText()) }
        }
      }
      emit $Element $TopNames
      $null = $builder.Append([char]10)
      return ,($utf8.GetBytes($builder.ToString()))
    }
    function equalValue([System.Text.Json.JsonElement]$Left, [System.Text.Json.JsonElement]$Right) {
      sameBytes (jsonBytes $Left $null) (jsonBytes $Right $null)
    }
    function imageBytes([System.Text.Json.JsonElement]$Image) {
      try {
        $text = $Image.GetProperty('bytesBase64').GetString()
        [byte[]]$bytes = [Convert]::FromBase64String($text)
        if (-not (sameText ([Convert]::ToBase64String($bytes)) $text) -or
            -not (sameText (sha $bytes) $Image.GetProperty('digest').GetString())) { throw 'ImageDigestMismatch' }
        return ,$bytes
      } catch { throw 'ImageDigestMismatch' }
    }
    function logicalImage([System.Text.Json.JsonElement]$Image) {
      [byte[]]$bytes = imageBytes $Image
      $element = parseBytes $bytes
      shape $element $imageSchema
      if (-not (sameBytes $bytes (jsonBytes $element $fields))) { throw 'ImageDigestMismatch' }
      return $element
    }
    try {
      [byte[]]$schemaBytes = [IO.File]::ReadAllBytes((Join-Path $schemaRoot 'schemas/state-v1.schema.json'))
      if (-not (sameText (sha $schemaBytes) '4f148321844e3f2970c7190d79fb4371e609a62bef093e43a7adb855c9bb9bfa')) { throw 'UnsupportedSchema' }
      $schemaText = $utf8.GetString($schemaBytes)
      # Only the trusted schema is converted to PowerShell objects, never state data.
      $schema = $schemaText | ConvertFrom-Json -AsHashtable -Depth 100 -ErrorAction Stop
      $properties = [ordered]@{}
      foreach ($field in $fields) { $properties[$field] = $schema.properties[$field] }
      $imageSchema = @{
        '$schema' = $schema.'$schema'; type = 'object'; required = $fields
        additionalProperties = $false; properties = $properties; definitions = $schema.definitions
      } | ConvertTo-Json -Depth 100 -Compress
    } catch { throw 'Get-CoordResult: InvalidSchema' }

    function requestMap([System.Text.Json.JsonElement]$Records) {
      $map = [Collections.Generic.Dictionary[string, System.Text.Json.JsonElement]]::new([StringComparer]::Ordinal)
      foreach ($item in $Records.EnumerateArray()) {
        $request = $item.GetProperty('request')
        $id = $request.GetProperty('requestId').GetString()
        if (-not (sameText $request.GetProperty('resourceId').GetString() $ResourceId) -or $map.ContainsKey($id)) { throw 'InconsistentRetainedState' }
        $map.Add($id, $item)
      }
      return ,$map
    }
    function checkRecord([System.Text.Json.JsonElement]$Record) {
      $request = $Record.GetProperty('request')
      $id = $request.GetProperty('requestId').GetString()
      $status = $Record.GetProperty('status').GetString()
      $digest = $Record.GetProperty('digest').GetString()
      $original = parseBytes ($utf8.GetBytes($Record.GetProperty('originalRequestJson').GetString()))
      if (-not (equalValue $original $request)) { throw 'InconsistentRetainedState' }
      if ($status -cne 'Rejected') {
        # Executable request schema has no numeric positions. S1 excludes the LF
        # added by the generic state codec. Rejected history uses retained bindings.
        [byte[]]$canonical = jsonBytes $request $null
        [byte[]]$requestBytes = [byte[]]::new($canonical.Length - 1)
        [Array]::Copy($canonical, $requestBytes, $requestBytes.Length)
        if (-not (sameText (sha $requestBytes) $digest)) { throw 'InconsistentRetainedState' }
      }
      if ($status -cin @('Applied', 'Rejected')) {
        $terminal = $Record.GetProperty('terminalEvidence')
        if (-not (sameText $terminal.GetProperty('resourceId').GetString() $ResourceId) -or
            -not (sameText $terminal.GetProperty('requestId').GetString() $id) -or
            -not (sameText $terminal.GetProperty('status').GetString() $status) -or
            -not (sameText $terminal.GetProperty('digest').GetString() $digest)) { throw 'InconsistentRetainedState' }
      }
    }
  }
  process {
    $failure = 'UnavailableState'
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Reading retained local result snapshot'
      if (-not [IO.Path]::IsPathFullyQualified($StatePath) -or
          -not (Test-Path -LiteralPath $StatePath -PathType Leaf -ErrorAction Stop) -or
          (Get-Item -LiteralPath $StatePath -Force -ErrorAction Stop).LinkType) { throw 'UnavailableState' }
      [byte[]]$bytes = [IO.File]::ReadAllBytes($StatePath)
      $failure = 'InvalidState'
      $state = parseBytes $bytes
      shape $state $schemaText
      $failure = 'ResourceMismatch'
      if (-not (sameText $state.GetProperty('resourceId').GetString() $ResourceId)) { throw 'ResourceMismatch' }
      $failure = 'InconsistentRetainedState'
      $records = requestMap $state.GetProperty('requests')
      foreach ($item in $records.Values) { checkRecord $item }
      $plans = [Collections.Generic.Dictionary[string, System.Text.Json.JsonElement]]::new([StringComparer]::Ordinal)
      $memberOperations = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
      foreach ($plan in $state.GetProperty('preparedOperations').EnumerateArray()) {
        $id = $plan.GetProperty('operationId').GetString()
        if ($plans.ContainsKey($id) -or -not (sameText $plan.GetProperty('resourceId').GetString() $ResourceId)) { throw 'InconsistentRetainedState' }
        $plans.Add($id, $plan)
        foreach ($member in $plan.GetProperty('requestIds').EnumerateArray()) {
          if ($memberOperations.ContainsKey($member.GetString())) { throw 'InconsistentRetainedState' }
          $memberOperations.Add($member.GetString(), $id)
        }
      }
      $receipts = [Collections.Generic.Dictionary[string, System.Text.Json.JsonElement]]::new([StringComparer]::Ordinal)
      $receiptOperations = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($receipt in $state.GetProperty('commitReceipts').EnumerateArray()) {
        $id = $receipt.GetProperty('receiptId').GetString()
        if ($receipts.ContainsKey($id) -or -not $receiptOperations.Add($receipt.GetProperty('operationId').GetString()) -or
            -not (sameText $receipt.GetProperty('resourceId').GetString() $ResourceId)) { throw 'InconsistentRetainedState' }
        $receipts.Add($id, $receipt)
        foreach ($member in $receipt.GetProperty('requestIds').EnumerateArray()) {
          if (-not $records.ContainsKey($member.GetString())) { throw 'InconsistentRetainedState' }
        }
      }
      $record = $null; $operation = $null; $commitReceipt = $null; $status = $null
      if ($records.ContainsKey($RequestId)) {
        $record = $records[$RequestId]
        $status = $record.GetProperty('status').GetString()
      }
      # Any retained Applied receipt naming this exact request must be its own
      # selected Applied receipt. Also inspect terminal-only claims so a corrupt
      # foreign member list cannot hide contradictory selected result evidence.
      foreach ($receipt in $receipts.Values) {
        $namesSelected = $false
        foreach ($member in $receipt.GetProperty('requestIds').EnumerateArray()) {
          if (sameText $member.GetString() $RequestId) { $namesSelected = $true }
        }
        foreach ($terminal in $receipt.GetProperty('terminalEvidence').EnumerateArray()) {
          if (sameText $terminal.GetProperty('requestId').GetString() $RequestId) { $namesSelected = $true }
        }
        if (-not $namesSelected) { continue }
        if ($status -cne 'Applied') { throw 'InconsistentRetainedState' }
        $selectedOperationId = $record.GetProperty('preparedOperationId').GetString()
        if (-not $plans.ContainsKey($selectedOperationId) -or
            -not (sameText $receipt.GetProperty('operationId').GetString() $selectedOperationId) -or
            -not (sameText $receipt.GetProperty('receiptId').GetString() $plans[$selectedOperationId].GetProperty('commitReceiptId').GetString())) { throw 'InconsistentRetainedState' }
      }
      if ($null -ne $record) {
        if ($status -cin @('Pending', 'Rejected')) {
          if ($memberOperations.ContainsKey($RequestId)) { throw 'InconsistentRetainedState' }
        } else {
          $operationId = $record.GetProperty('preparedOperationId').GetString()
          if (-not $plans.ContainsKey($operationId) -or -not $memberOperations.ContainsKey($RequestId) -or
              -not (sameText $memberOperations[$RequestId] $operationId)) { throw 'InconsistentRetainedState' }
          $operation = $plans[$operationId]
          if (-not (sameText $operation.GetProperty('status').GetString() $status)) { throw 'InconsistentRetainedState' }
          # Decode only the retained plan's embedded logical images; no output paths
          # are read or published, and historical heads are never rebased to present.
          $before = logicalImage $operation.GetProperty('beforeStateImage')
          $after = logicalImage $operation.GetProperty('afterStateImage')
          $base = $operation.GetProperty('baseHead')
          if (-not (sameText $before.GetProperty('resourceId').GetString() $ResourceId) -or
              -not (sameText $after.GetProperty('resourceId').GetString() $ResourceId) -or
              -not (sameText $before.GetProperty('generation').GetString() $base.GetProperty('generation').GetString()) -or
              -not (sameText $before.GetProperty('committedRevision').GetString() $base.GetProperty('committedRevision').GetString()) -or
              -not (equalValue $before.GetProperty('committedOutputManifest') $base.GetProperty('outputManifest')) -or
              -not (sameText $after.GetProperty('generation').GetString() $base.GetProperty('generation').GetString()) -or
              -not (sameText $after.GetProperty('committedRevision').GetString() $operation.GetProperty('nextRevision').GetString()) -or
              -not (equalValue $after.GetProperty('committedOutputManifest') $operation.GetProperty('outputManifest'))) { throw 'InconsistentRetainedState' }
          $beforeRecords = requestMap $before.GetProperty('requests')
          $afterRecords = requestMap $after.GetProperty('requests')
          if ($status -ceq 'Applied') {
            $receiptId = $operation.GetProperty('commitReceiptId').GetString()
            if (-not $receipts.ContainsKey($receiptId)) { throw 'InconsistentRetainedState' }
            $commitReceipt = $receipts[$receiptId]
            if (-not (sameText $commitReceipt.GetProperty('operationId').GetString() $operationId) -or
                -not (sameText $commitReceipt.GetProperty('generation').GetString() $base.GetProperty('generation').GetString()) -or
                -not (sameText $commitReceipt.GetProperty('committedRevision').GetString() $operation.GetProperty('nextRevision').GetString()) -or
                -not (equalValue $commitReceipt.GetProperty('requestIds') $operation.GetProperty('requestIds')) -or
                -not (equalValue $commitReceipt.GetProperty('outputManifest') $operation.GetProperty('outputManifest')) -or
                -not (equalValue $commitReceipt.GetProperty('reservations') $operation.GetProperty('reservations'))) { throw 'InconsistentRetainedState' }
            $terminals = [Collections.Generic.Dictionary[string, System.Text.Json.JsonElement]]::new([StringComparer]::Ordinal)
            foreach ($terminal in $commitReceipt.GetProperty('terminalEvidence').EnumerateArray()) {
              $id = $terminal.GetProperty('requestId').GetString()
              if ($terminals.ContainsKey($id)) { throw 'InconsistentRetainedState' }
              $terminals.Add($id, $terminal)
            }
            if ($terminals.Count -ne $operation.GetProperty('requestIds').GetArrayLength()) { throw 'InconsistentRetainedState' }
          } elseif ($receiptOperations.Contains($operationId)) { throw 'InconsistentRetainedState' }
          foreach ($member in $operation.GetProperty('requestIds').EnumerateArray()) {
            $id = $member.GetString()
            if (-not $records.ContainsKey($id) -or -not $beforeRecords.ContainsKey($id) -or -not $afterRecords.ContainsKey($id)) { throw 'InconsistentRetainedState' }
            $current = $records[$id]; $old = $beforeRecords[$id]; $next = $afterRecords[$id]
            checkRecord $old; checkRecord $next
            if (-not (sameText $current.GetProperty('status').GetString() $status) -or
                -not (sameText $current.GetProperty('preparedOperationId').GetString() $operationId) -or
                -not (sameText $old.GetProperty('status').GetString() 'Pending') -or
                -not (sameText $next.GetProperty('status').GetString() 'Applied') -or
                -not (sameText $next.GetProperty('preparedOperationId').GetString() $operationId)) { throw 'InconsistentRetainedState' }
            foreach ($key in @('request', 'digest', 'originalRequestJson', 'queueOrdinal')) {
              if (-not (equalValue $current.GetProperty($key) $old.GetProperty($key)) -or
                  -not (equalValue $current.GetProperty($key) $next.GetProperty($key))) { throw 'InconsistentRetainedState' }
            }
            if ($status -ceq 'Applied') {
              if (-not $terminals.ContainsKey($id) -or
                  -not (equalValue $terminals[$id] $current.GetProperty('terminalEvidence')) -or
                  -not (equalValue $terminals[$id] $next.GetProperty('terminalEvidence'))) { throw 'InconsistentRetainedState' }
            } elseif ($status -ceq 'NeedsRecovery') {
              if (-not (equalValue $current.GetProperty('recoveryEvidence') $operation.GetProperty('recoveryEvidence'))) { throw 'InconsistentRetainedState' }
            }
          }
        }
      } elseif ($memberOperations.ContainsKey($RequestId)) { throw 'InconsistentRetainedState' }
      [PSCustomObject]@{
        Outcome = if ($null -eq $record) { 'NotFound' } else { 'Found' }
        ResourceId = $ResourceId; RequestId = $RequestId; RetainedStatus = $status
        StateSha256 = sha $bytes
        RecordedHead = [PSCustomObject]@{
          generation = $state.GetProperty('generation').GetString()
          committedRevision = $state.GetProperty('committedRevision').GetString()
          outputManifest = $state.GetProperty('committedOutputManifest').Clone()
        }
        Record = if ($null -eq $record) { $null } else { $record.Clone() }
        Operation = if ($null -eq $operation) { $null } else { $operation.Clone() }
        CommitReceipt = if ($null -eq $commitReceipt) { $null } else { $commitReceipt.Clone() }
      }
    } catch { throw ('Get-CoordResult: ' + $failure) }
  }
}

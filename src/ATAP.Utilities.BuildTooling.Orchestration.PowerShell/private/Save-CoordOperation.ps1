function Invoke-CoordOperationFileIo {
  # Internal, finite I/O seam for Save-CoordOperation tests; never request-supplied code.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateSet('Stage', 'Replace', 'ReadBack')][string]$Phase,
    [Parameter(Mandatory)][string]$StatePath,
    [string]$StagePath,
    [byte[]]$Bytes
  )
  begin {
    $fn = 'Invoke-CoordOperationFileIo'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
  }
  process {
    switch ($Phase) {
      'Stage' {
        $stream = $null
        try {
          $stream = [IO.FileStream]::new($StagePath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
          $stream.Write($Bytes, 0, $Bytes.Length)
          $stream.Flush($true)
        } finally { if ($null -ne $stream) { $stream.Dispose() } }
      }
      'Replace' { [IO.File]::Replace($StagePath, $StatePath, [NullString]::Value) }
      'ReadBack' { return ,([IO.File]::ReadAllBytes($StatePath)) }
    }
  }
  end {}
}

function Save-CoordOperation {
  <#
  .SYNOPSIS
    Persists one immutable prepared plan without publishing its quartet.
  .DESCRIPTION
    Approved private 280/285 boundary. Caller MUST prove current authority,
    registered resource/lineage, resolved physical containment, complete evidence,
    eligible request causality/batch membership and sole-writer custody. Hold that
    custody from snapshot/candidate construction through publication/completion.
    Schema labels, a path or a local lock do not grant distributed authority.

    StatePath and all four image paths must be caller-resolved absolute paths.
    No configured root is created. Operation is a complete caller-validated
    statePreparedOperation, including all four supplied after-images. The pure
    Markdown preview alone cannot produce it. No IDs or after-images are invented.

    Logical images contain exactly the fourteen business/custody fields, excluding
    preparedOperations/commitReceipts. Top-level order is fixed below; nested names
    sort by unsigned UTF8 bytes. Arrays/numeric lexemes/string scalar content are
    lossless. Compact UTF8-noBOM JSON ends with one LF included in its digest.
    Outer preparation retains all history, adds one plan and changes only member
    Pending bookkeeping to Prepared. It does not apply the logical after-image.

    Equal-plan retry returns retained lifecycle without rewriting or resetting it.
    New preparation uses same-directory staging, Flush(true), File.Replace and
    verified readback. Uncertain staging evidence is retained; no delete fallback.
    No board writes, renderer, Applied result or commit receipt is produced.
    Future completion must merge verified business fields with retained journals
    and recognize deterministic Prepared bookkeeping; never restore an image as
    the complete outer state. This primitive proves no power-loss durability.
  .PARAMETER StatePath
    Absolute existing outer Coordination-state-v1 file under caller custody.
  .PARAMETER ExpectedStateBytes
    Exact caller-validated outer raw preimage; compared before new persistence.
  .PARAMETER Operation
    Strict caller-validated JsonElement plan, initially status Prepared.
  .OUTPUTS
    Private Stage/Action/identity/head/hash object. WhatIf is ProposedNotPrepared.
  .EXAMPLE
    Save-CoordOperation -StatePath $path -ExpectedStateBytes $raw -Operation $plan -WhatIf
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$StatePath,
    [Parameter(Mandatory)][ValidateNotNull()][byte[]]$ExpectedStateBytes,
    [Parameter(Mandatory)][System.Text.Json.JsonElement]$Operation
  )

  begin {
    $fn = 'Save-CoordOperation'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $null = Get-Command Write-PSFMessage -ErrorAction Stop
    $null = Get-Command Test-Json -ErrorAction Stop
    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    $fields = @('schemaVersion', 'resourceId', 'lineageId', 'registeredRoots', 'generation',
      'committedRevision', 'committedOutputManifest', 'custodyEvidence',
      'compatibilityEvidence', 'admissionEvidence', 'requests', 'claims',
      'reservations', 'mutationAdmission')
    $slots = @('markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml')
    # Source files live in private/; a built module may concatenate them at its root.
    $schemaRoot = if ((Split-Path $PSScriptRoot -Leaf) -ieq 'private') { Split-Path $PSScriptRoot -Parent } else { $PSScriptRoot }
    $schemaText = Get-Content -LiteralPath (Join-Path $schemaRoot 'schemas/state-v1.schema.json') -Raw -ErrorAction Stop
    $schema = $schemaText | ConvertFrom-Json -AsHashtable -Depth 100
    $operationSchema = @{
      '$schema' = $schema.'$schema'; '$ref' = '#/definitions/statePreparedOperation'
      definitions = $schema.definitions
    } | ConvertTo-Json -Depth 100 -Compress
    $properties = [ordered]@{}
    foreach ($field in $fields) { $properties[$field] = $schema.properties[$field] }
    $imageSchema = @{
      '$schema' = $schema.'$schema'; type = 'object'; required = $fields
      additionalProperties = $false; properties = $properties; definitions = $schema.definitions
    } | ConvertTo-Json -Depth 100 -Compress

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
    function immutableBytes([System.Text.Json.JsonElement]$Plan) {
      $names = @(sortedNames $Plan | Where-Object { $_ -cnotin @('status', 'recoveryEvidence', 'commitReceiptId') })
      return ,(jsonBytes $Plan $names)
    }
    function replaceMembers([System.Text.Json.JsonElement]$Element, [hashtable]$Replace, [string[]]$Remove) {
      $stream = [IO.MemoryStream]::new()
      $writer = [System.Text.Json.Utf8JsonWriter]::new($stream)
      try {
        $writer.WriteStartObject()
        foreach ($property in $Element.EnumerateObject()) {
          if ($property.Name -cin $Remove -or $Replace.ContainsKey($property.Name)) { continue }
          $writer.WritePropertyName($property.Name)
          $writer.WriteRawValue($property.Value.GetRawText(), $false)
        }
        foreach ($key in $Replace.Keys) {
          $writer.WritePropertyName($key); $writer.WriteRawValue([string]$Replace[$key], $false)
        }
        $writer.WriteEndObject(); $writer.Flush()
        return (parseBytes $stream.ToArray())
      } finally { $writer.Dispose(); $stream.Dispose() }
    }
    function result([string]$Stage, [string]$Action, [string]$Status, [string]$Hash) {
      [PSCustomObject]@{
        Stage = $Stage; Action = $Action
        OperationId = $Operation.GetProperty('operationId').GetString()
        OperationStatus = $Status; ResourceId = $Operation.GetProperty('resourceId').GetString()
        Generation = $Operation.GetProperty('baseHead').GetProperty('generation').GetString()
        BaseRevision = $Operation.GetProperty('baseHead').GetProperty('committedRevision').GetString()
        NextRevision = $Operation.GetProperty('nextRevision').GetString()
        PersistedStateSha256 = $Hash
      }
    }
  }

  process {
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Validating prepared operation'
      if (-not [IO.Path]::IsPathFullyQualified($StatePath) -or
          -not (Test-Path -LiteralPath (Split-Path $StatePath -Parent) -PathType Container) -or
          -not (Test-Path -LiteralPath $StatePath -PathType Leaf)) { throw 'MissingEstablishedState' }
      if ((Get-Item -LiteralPath $StatePath -Force).LinkType) { throw 'InvalidPreparedOperation' }
      [byte[]]$currentBytes = [IO.File]::ReadAllBytes($StatePath)
      $state = parseBytes $currentBytes
      shape $state $schemaText
      shape $Operation $operationSchema
      if (-not (sameText $Operation.GetProperty('status').GetString() 'Prepared')) { throw 'InvalidPreparedOperation' }
      $operationId = $Operation.GetProperty('operationId').GetString()
      $resourceId = $Operation.GetProperty('resourceId').GetString()
      if (-not (sameText $resourceId $state.GetProperty('resourceId').GetString())) { throw 'InvalidPreparedOperation' }
      $before = logicalImage $Operation.GetProperty('beforeStateImage')
      $after = logicalImage $Operation.GetProperty('afterStateImage')
      foreach ($slot in $slots) {
        $null = imageBytes $Operation.GetProperty('beforeOutputs').GetProperty($slot)
        $null = imageBytes $Operation.GetProperty('afterOutputs').GetProperty($slot)
      }

      $existing = $null
      $seenOperations = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($old in $state.GetProperty('preparedOperations').EnumerateArray()) {
        $id = $old.GetProperty('operationId').GetString()
        if (-not $seenOperations.Add($id)) { throw 'OperationConflict' }
        if (sameText $id $operationId) { $existing = $old }
      }
      if ($null -ne $existing) {
        if (-not (sameBytes (immutableBytes $existing) (immutableBytes $Operation))) { throw 'OperationConflict' }
        return (result 'Retained' 'Unchanged' $existing.GetProperty('status').GetString() (sha $currentBytes))
      }
      if (-not (sameBytes $currentBytes $ExpectedStateBytes)) { throw 'SnapshotMismatch' }
      $recovery = [System.Text.Json.JsonElement]::new()
      if ($Operation.TryGetProperty('recoveryEvidence', [ref]$recovery)) { throw 'InvalidPreparedOperation' }
      if (-not (sameText $state.GetProperty('mutationAdmission').GetProperty('status').GetString() 'Admitted')) { throw 'ResourceHeld' }
      foreach ($old in $state.GetProperty('preparedOperations').EnumerateArray()) {
        if ($old.GetProperty('status').GetString() -cin @('Prepared', 'NeedsRecovery')) { throw 'ResourceHeld' }
      }
      $base = $Operation.GetProperty('baseHead')
      foreach ($key in @('generation', 'committedRevision')) {
        if (-not (sameText $base.GetProperty($key).GetString() $state.GetProperty($key).GetString())) { throw 'SnapshotMismatch' }
      }
      if (-not (equalValue $base.GetProperty('outputManifest') $state.GetProperty('committedOutputManifest')) -or
          (sameText $Operation.GetProperty('nextRevision').GetString() $base.GetProperty('committedRevision').GetString())) { throw 'InvalidPreparedOperation' }
      if (-not (sameBytes (jsonBytes $state $fields) (imageBytes $Operation.GetProperty('beforeStateImage')))) { throw 'SnapshotMismatch' }
      foreach ($key in $fields | Where-Object { $_ -cnotin @('committedRevision', 'committedOutputManifest', 'requests', 'claims') }) {
        if (-not (equalValue $state.GetProperty($key) $after.GetProperty($key))) { throw 'InvalidPreparedOperation' }
      }
      if (-not (sameText $after.GetProperty('committedRevision').GetString() $Operation.GetProperty('nextRevision').GetString()) -or
          -not (equalValue $after.GetProperty('committedOutputManifest') $Operation.GetProperty('outputManifest')) -or
          -not (equalValue $Operation.GetProperty('reservations') $state.GetProperty('reservations'))) { throw 'InvalidPreparedOperation' }

      $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($slot in $slots) {
        $b = $Operation.GetProperty('beforeOutputs').GetProperty($slot)
        $a = $Operation.GetProperty('afterOutputs').GetProperty($slot)
        $oldManifest = $base.GetProperty('outputManifest').GetProperty($slot)
        $manifest = $Operation.GetProperty('outputManifest').GetProperty($slot)
        $path = $b.GetProperty('path').GetString()
        if (-not [IO.Path]::IsPathFullyQualified($path) -or -not $paths.Add([IO.Path]::GetFullPath($path)) -or
            -not (sameText $path $a.GetProperty('path').GetString()) -or
            -not (sameText $path $oldManifest.GetProperty('path').GetString()) -or
            -not (sameText $path $manifest.GetProperty('path').GetString()) -or
            -not (sameText $b.GetProperty('digest').GetString() $oldManifest.GetProperty('digest').GetString()) -or
            -not (sameText $a.GetProperty('digest').GetString() $manifest.GetProperty('digest').GetString())) { throw 'InvalidPreparedOperation' }
        try {
          if ((Get-Item -LiteralPath $path -Force -ErrorAction Stop).LinkType -or
              -not (sameBytes ([IO.File]::ReadAllBytes($path)) (imageBytes $b))) { throw 'SnapshotMismatch' }
        } catch { throw 'SnapshotMismatch' }
      }
      if ($paths.Contains([IO.Path]::GetFullPath($StatePath))) { throw 'InvalidPreparedOperation' }

      $members = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($id in $Operation.GetProperty('requestIds').EnumerateArray()) { $null = $members.Add($id.GetString()) }
      $seenRequests = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      $requestValues = [Collections.Generic.List[string]]::new()
      $requestIndex = 0
      $afterRequests = $after.GetProperty('requests')
      if ($afterRequests.GetArrayLength() -ne $state.GetProperty('requests').GetArrayLength()) { throw 'InvalidPreparedOperation' }
      foreach ($record in $state.GetProperty('requests').EnumerateArray()) {
        $request = $record.GetProperty('request')
        $id = $request.GetProperty('requestId').GetString()
        if (-not $seenRequests.Add($id)) { throw 'InvalidPreparedOperation' }
        $afterRecord = $afterRequests[$requestIndex]; $requestIndex++
        if ($members.Contains($id)) {
          if (-not (sameText $record.GetProperty('status').GetString() 'Pending') -or
              -not (sameText $request.GetProperty('resourceId').GetString() $resourceId) -or
              -not (sameText $request.GetProperty('generation').GetString() $base.GetProperty('generation').GetString()) -or
              -not (sameText $request.GetProperty('expectedRevision').GetString() $base.GetProperty('committedRevision').GetString()) -or
              -not (sameText $afterRecord.GetProperty('status').GetString() 'Applied') -or
              -not (sameText $afterRecord.GetProperty('preparedOperationId').GetString() $operationId)) { throw 'InvalidPreparedOperation' }
          foreach ($key in @('request', 'digest', 'originalRequestJson', 'queueOrdinal')) {
            if (-not (equalValue $record.GetProperty($key) $afterRecord.GetProperty($key))) { throw 'InvalidPreparedOperation' }
          }
          $terminal = $afterRecord.GetProperty('terminalEvidence')
          if (-not (sameText $terminal.GetProperty('resourceId').GetString() $resourceId) -or
              -not (sameText $terminal.GetProperty('requestId').GetString() $id) -or
              -not (sameText $terminal.GetProperty('digest').GetString() $record.GetProperty('digest').GetString())) { throw 'InvalidPreparedOperation' }
          $prepared = replaceMembers $record @{
            status = '"Prepared"'; preparedOperationId = (ConvertTo-Json -InputObject $operationId -Compress)
          } @('pendingEvidence')
          $requestValues.Add($prepared.GetRawText())
        } else {
          if (-not (equalValue $record $afterRecord)) { throw 'InvalidPreparedOperation' }
          $requestValues.Add($record.GetRawText())
        }
      }
      foreach ($id in $members) { if (-not $seenRequests.Contains($id)) { throw 'InvalidPreparedOperation' } }
      $plans = @($state.GetProperty('preparedOperations').EnumerateArray() | ForEach-Object { $_.GetRawText() }) + @($Operation.GetRawText())
      $preparedState = replaceMembers $state @{
        requests = '[' + ($requestValues -join ',') + ']'
        preparedOperations = '[' + ($plans -join ',') + ']'
      } @()
      shape $preparedState $schemaText
      [byte[]]$newBytes = jsonBytes $preparedState $null
      if (-not $PSCmdlet.ShouldProcess($StatePath, 'Persist immutable prepared operation without publishing outputs')) {
        return (result 'ProposedNotPrepared' 'WhatIf' $null $null)
      }
      $stagePath = Join-Path (Split-Path $StatePath -Parent) ('.' + (Split-Path $StatePath -Leaf) + '.' + [guid]::NewGuid().ToString('N') + '.prepared.tmp')
      try {
        $null = Invoke-CoordOperationFileIo -Phase Stage -StatePath $StatePath -StagePath $stagePath -Bytes $newBytes
        if (-not (sameBytes ([IO.File]::ReadAllBytes($StatePath)) $ExpectedStateBytes)) { throw 'SnapshotMismatch' }
        foreach ($slot in $slots) {
          $preimage = $Operation.GetProperty('beforeOutputs').GetProperty($slot)
          if (-not (sameBytes ([IO.File]::ReadAllBytes($preimage.GetProperty('path').GetString())) (imageBytes $preimage))) {
            throw 'SnapshotMismatch'
          }
        }
        $null = Invoke-CoordOperationFileIo -Phase Replace -StatePath $StatePath -StagePath $stagePath
        [byte[]]$readback = Invoke-CoordOperationFileIo -Phase ReadBack -StatePath $StatePath
        if (-not (sameBytes $readback $newBytes)) { throw 'PersistenceFailed' }
        $verified = parseBytes $readback
        shape $verified $schemaText
      } catch {
        if (sameText $_.Exception.Message 'SnapshotMismatch') { throw 'SnapshotMismatch' }
        throw 'PersistenceFailed'
      }
      result 'Prepared' 'Saved' 'Prepared' (sha $readback)
    } catch {
      $code = $_.Exception.Message
      if ($code -cnotin @('MissingEstablishedState', 'InvalidPreparedOperation', 'ImageDigestMismatch',
          'OperationConflict', 'SnapshotMismatch', 'ResourceHeld', 'PersistenceFailed')) { $code = 'InvalidPreparedOperation' }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Prepared operation refused; no publication performed'
      throw [InvalidOperationException]::new("Save-CoordOperation: $code.")
    }
  }
  end {}
}

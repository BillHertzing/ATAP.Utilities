function Complete-CoordOperation {
  <#
  .SYNOPSIS
    Completes one retained immutable plan under continuous caller custody.
  .DESCRIPTION
    Private317 binding. Caller proves strict state/evidence/request validity,
    authority, physical containment and sole-writer custody for state and quartet.
    Resume expresses reconciled recovery intent; it grants no authority.
    Four sequential file publications precede one coherent outer state commit.
    No cross-file atomicity or power-loss durability is claimed. Applied retry
    returns immutable history, never replays historical outputs or rebases head.
    Source helpers are exact copies from vetted Save303; keep codec copies aligned.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$StatePath,
    [Parameter(Mandatory)][ValidateNotNull()][byte[]]$ExpectedStateBytes,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$OperationId,
    [switch]$Resume
  )
  begin {
    $fn = 'Complete-CoordOperation'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $null = Get-Command Write-PSFMessage -ErrorAction Stop
    $null = Get-Command Test-Json -ErrorAction Stop
    $null = Get-Command Invoke-CoordOperationFileIo -ErrorAction Stop
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

    function completedResult([string]$Stage, [string]$Action, [string]$Status, [string]$ReceiptId, [string]$Hash) {
      [PSCustomObject]@{
        Stage = $Stage; Action = $Action; OperationId = $OperationId
        OperationStatus = $Status; ResourceId = $operation.GetProperty('resourceId').GetString()
        Generation = $operation.GetProperty('baseHead').GetProperty('generation').GetString()
        BaseRevision = $operation.GetProperty('baseHead').GetProperty('committedRevision').GetString()
        NextRevision = $operation.GetProperty('nextRevision').GetString()
        CommitReceiptId = $ReceiptId; PersistedStateSha256 = $Hash
      }
    }
    function quotedValue([string]$Value) { ConvertTo-Json -InputObject $Value -Compress }
    function mergeOuter($Outer, $Projection, $Plan, $Receipt) {
      if (-not (sameBytes (immutableBytes $operation) (immutableBytes $Plan))) { throw 'OperationConflict' }
      $replacement = @{}
      foreach ($field in $fields) { $replacement[$field] = $Projection.GetProperty($field).GetRawText() }
      $plans = foreach ($old in $Outer.GetProperty('preparedOperations').EnumerateArray()) {
        if (sameText $old.GetProperty('operationId').GetString() $OperationId) { $Plan.GetRawText() } else { $old.GetRawText() }
      }
      $replacement.preparedOperations = '[' + (@($plans) -join ',') + ']'
      if ($null -ne $Receipt) {
        $receipts = @($Outer.GetProperty('commitReceipts').EnumerateArray() | ForEach-Object { $_.GetRawText() }) + @($Receipt.GetRawText())
        $replacement.commitReceipts = '[' + ($receipts -join ',') + ']'
      }
      $merged = replaceMembers $Outer $replacement @()
      shape $merged $schemaText
      return $merged
    }
    function observeQuartet {
      $values = @{}
      foreach ($slot in $slots) {
        $path = $operation.GetProperty('beforeOutputs').GetProperty($slot).GetProperty('path').GetString()
        try {
          if ((Get-Item -LiteralPath $path -Force -ErrorAction Stop).LinkType) { throw 'OutputUnavailable' }
          [byte[]]$bytes = Invoke-CoordOperationFileIo -Phase ReadBack -StatePath $path
          $kind = if (sameBytes $bytes $afterBytes[$slot]) { 'After' } elseif (sameBytes $bytes $beforeBytes[$slot]) { 'Before' } else { 'Third' }
          $values[$slot] = @{ Kind = $kind; Bytes = $bytes; Path = $path }
        } catch { $values[$slot] = @{ Kind = 'Unknown'; Bytes = $null; Path = $path } }
      }
      return $values
    }
    function allAfter {
      $seen = observeQuartet
      foreach ($slot in $slots) { if ($seen[$slot].Kind -cne 'After') { return $false } }
      return $true
    }
    function persistOuter($Candidate, [byte[]]$Expected, [switch]$RequireAfter) {
      shape $Candidate $schemaText
      [byte[]]$bytes = jsonBytes $Candidate $null
      $stage = Join-Path (Split-Path $StatePath -Parent) ('.' + (Split-Path $StatePath -Leaf) + '.' + [guid]::NewGuid().ToString('N') + '.complete.tmp')
      $null = Invoke-CoordOperationFileIo -Phase Stage -StatePath $StatePath -StagePath $stage -Bytes $bytes
      if (-not (sameBytes ([IO.File]::ReadAllBytes($StatePath)) $Expected)) { throw 'SnapshotMismatch' }
      if ($RequireAfter -and -not (allAfter)) { throw 'OutputsChangedBeforeCommit' }
      # No recovery write may follow an uncertain Replace/readback: it could overwrite a commit.
      try {
        $null = Invoke-CoordOperationFileIo -Phase Replace -StatePath $StatePath -StagePath $stage
        [byte[]]$readback = Invoke-CoordOperationFileIo -Phase ReadBack -StatePath $StatePath
        if (-not (sameBytes $readback $bytes)) { throw 'PersistenceFailed' }
        $verified = parseBytes $readback
        shape $verified $schemaText
        return @{ State = $verified; Bytes = $readback }
      } catch { throw 'PersistenceFailed' }
    }
    function persistRecovery([string]$Reason) {
      if (-not (sameBytes ([IO.File]::ReadAllBytes($StatePath)) $currentBytes)) { throw 'SnapshotMismatch' }
      $observed = observeQuartet
      $known = foreach ($slot in $slots) {
        if ($null -ne $observed[$slot].Bytes) {
          '{"path":' + (quotedValue $observed[$slot].Path) + ',"bytesBase64":' +
            (quotedValue ([Convert]::ToBase64String($observed[$slot].Bytes))) + ',"digest":' +
            (quotedValue (sha $observed[$slot].Bytes)) + '}'
        }
      }
      $evidence = parseBytes ($utf8.GetBytes('{"reason":' + (quotedValue $Reason) + ',"observedOutputs":[' + (@($known) -join ',') + ']}'))
      $requests = foreach ($record in $preparedProjection.GetProperty('requests').EnumerateArray()) {
        if ($members.Contains($record.GetProperty('request').GetProperty('requestId').GetString())) {
          (replaceMembers $record @{ status = '"NeedsRecovery"'; recoveryEvidence = $evidence.GetRawText() } @()).GetRawText()
        } else { $record.GetRawText() }
      }
      $projection = replaceMembers $preparedProjection @{
        requests = '[' + (@($requests) -join ',') + ']'
        mutationAdmission = (replaceMembers $evidence @{ status = '"NeedsRecovery"' } @()).GetRawText()
      } @()
      $plan = replaceMembers $operation @{ status = '"NeedsRecovery"'; recoveryEvidence = $evidence.GetRawText() } @()
      $candidate = mergeOuter $state $projection $plan $null
      try { $saved = persistOuter $candidate $currentBytes } catch { throw 'PersistenceFailed' }
      return (completedResult 'NeedsRecovery' 'Held' 'NeedsRecovery' $null (sha $saved.Bytes))
    }
  }
  process {
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Validating retained completion plan'
      if (-not [IO.Path]::IsPathFullyQualified($StatePath) -or
          -not (Test-Path -LiteralPath (Split-Path $StatePath -Parent) -PathType Container) -or
          -not (Test-Path -LiteralPath $StatePath -PathType Leaf)) { throw 'MissingEstablishedState' }
      if ((Get-Item -LiteralPath $StatePath -Force).LinkType) { throw 'InvalidPreparedOperation' }
      [byte[]]$currentBytes = [IO.File]::ReadAllBytes($StatePath)
      $state = parseBytes $currentBytes
      shape $state $schemaText
      $operation = $null
      $seenPlans = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($plan in $state.GetProperty('preparedOperations').EnumerateArray()) {
        $id = $plan.GetProperty('operationId').GetString()
        if (-not $seenPlans.Add($id)) { throw 'OperationConflict' }
        if (sameText $id $OperationId) { $operation = $plan }
      }
      if ($null -eq $operation) { throw 'InvalidPreparedOperation' }
      $seenReceipts = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      $receiptOperations = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($old in $state.GetProperty('commitReceipts').EnumerateArray()) {
        if (-not $seenReceipts.Add($old.GetProperty('receiptId').GetString()) -or
            -not $receiptOperations.Add($old.GetProperty('operationId').GetString())) { throw 'OperationConflict' }
      }
      $resourceId = $operation.GetProperty('resourceId').GetString()
      if (-not (sameText $resourceId $state.GetProperty('resourceId').GetString())) { throw 'InvalidPreparedOperation' }
      $before = logicalImage $operation.GetProperty('beforeStateImage')
      $after = logicalImage $operation.GetProperty('afterStateImage')
      $base = $operation.GetProperty('baseHead')
      if (-not (sameText $before.GetProperty('mutationAdmission').GetProperty('status').GetString() 'Admitted') -or
          -not (sameText $before.GetProperty('resourceId').GetString() $resourceId) -or
          -not (sameText $before.GetProperty('generation').GetString() $base.GetProperty('generation').GetString()) -or
          -not (sameText $before.GetProperty('committedRevision').GetString() $base.GetProperty('committedRevision').GetString()) -or
          -not (equalValue $before.GetProperty('committedOutputManifest') $base.GetProperty('outputManifest')) -or
          (sameText $operation.GetProperty('nextRevision').GetString() $base.GetProperty('committedRevision').GetString())) { throw 'InvalidPreparedOperation' }
      foreach ($field in $fields | Where-Object { $_ -cnotin @('committedRevision', 'committedOutputManifest', 'requests', 'claims') }) {
        if (-not (equalValue $before.GetProperty($field) $after.GetProperty($field))) { throw 'InvalidPreparedOperation' }
      }
      if (-not (sameText $after.GetProperty('committedRevision').GetString() $operation.GetProperty('nextRevision').GetString()) -or
          -not (equalValue $after.GetProperty('committedOutputManifest') $operation.GetProperty('outputManifest')) -or
          -not (equalValue $before.GetProperty('reservations') $operation.GetProperty('reservations'))) { throw 'InvalidPreparedOperation' }
      $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      $beforeBytes = @{}; $afterBytes = @{}
      foreach ($slot in $slots) {
        $b = $operation.GetProperty('beforeOutputs').GetProperty($slot)
        $a = $operation.GetProperty('afterOutputs').GetProperty($slot)
        $path = $b.GetProperty('path').GetString()
        if (-not [IO.Path]::IsPathFullyQualified($path) -or -not $paths.Add([IO.Path]::GetFullPath($path)) -or
            -not (sameText $path $a.GetProperty('path').GetString()) -or
            -not (sameText $path $base.GetProperty('outputManifest').GetProperty($slot).GetProperty('path').GetString()) -or
            -not (sameText $path $operation.GetProperty('outputManifest').GetProperty($slot).GetProperty('path').GetString()) -or
            -not (sameText $b.GetProperty('digest').GetString() $base.GetProperty('outputManifest').GetProperty($slot).GetProperty('digest').GetString()) -or
            -not (sameText $a.GetProperty('digest').GetString() $operation.GetProperty('outputManifest').GetProperty($slot).GetProperty('digest').GetString())) { throw 'InvalidPreparedOperation' }
        $beforeBytes[$slot] = imageBytes $b; $afterBytes[$slot] = imageBytes $a
      }
      if ($paths.Contains([IO.Path]::GetFullPath($StatePath))) { throw 'InvalidPreparedOperation' }
      $members = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($id in $operation.GetProperty('requestIds').EnumerateArray()) { $null = $members.Add($id.GetString()) }
      $terminals = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
      $appliedMembers = [Collections.Generic.Dictionary[string, System.Text.Json.JsonElement]]::new([StringComparer]::Ordinal)
      $preparedRecords = [Collections.Generic.List[string]]::new()
      $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      $afterRequests = $after.GetProperty('requests')
      if ($before.GetProperty('requests').GetArrayLength() -ne $afterRequests.GetArrayLength()) { throw 'InvalidPreparedOperation' }
      $index = 0
      foreach ($record in $before.GetProperty('requests').EnumerateArray()) {
        $request = $record.GetProperty('request'); $id = $request.GetProperty('requestId').GetString()
        if (-not $seen.Add($id)) { throw 'InvalidPreparedOperation' }
        $next = $afterRequests[$index]; $index++
        if ($members.Contains($id)) {
          if (-not (sameText $record.GetProperty('status').GetString() 'Pending') -or
              -not (sameText $request.GetProperty('resourceId').GetString() $resourceId) -or
              -not (sameText $request.GetProperty('generation').GetString() $base.GetProperty('generation').GetString()) -or
              -not (sameText $request.GetProperty('expectedRevision').GetString() $base.GetProperty('committedRevision').GetString()) -or
              -not (sameText $next.GetProperty('status').GetString() 'Applied') -or
              -not (sameText $next.GetProperty('preparedOperationId').GetString() $OperationId)) { throw 'InvalidPreparedOperation' }
          foreach ($key in @('request', 'digest', 'originalRequestJson', 'queueOrdinal')) {
            if (-not (equalValue $record.GetProperty($key) $next.GetProperty($key))) { throw 'InvalidPreparedOperation' }
          }
          $terminal = $next.GetProperty('terminalEvidence')
          if (-not (sameText $terminal.GetProperty('resourceId').GetString() $resourceId) -or
              -not (sameText $terminal.GetProperty('requestId').GetString() $id) -or
              -not (sameText $terminal.GetProperty('digest').GetString() $record.GetProperty('digest').GetString()) -or
              -not (sameText $terminal.GetProperty('status').GetString() 'Applied')) { throw 'InvalidPreparedOperation' }
          $terminals[$id] = $terminal.GetRawText(); $appliedMembers[$id] = $next
          $preparedRecords.Add((replaceMembers $record @{ status = '"Prepared"'; preparedOperationId = (quotedValue $OperationId) } @('pendingEvidence')).GetRawText())
        } else {
          if (-not (equalValue $record $next)) { throw 'InvalidPreparedOperation' }
          $preparedRecords.Add($record.GetRawText())
        }
      }
      foreach ($id in $members) { if (-not $seen.Contains($id)) { throw 'InvalidPreparedOperation' } }
      $preparedProjection = replaceMembers $before @{ requests = '[' + ($preparedRecords -join ',') + ']' } @()
      $orderedTerminals = foreach ($id in $operation.GetProperty('requestIds').EnumerateArray()) { $terminals[$id.GetString()] }
      $receiptId = if (sameText $operation.GetProperty('status').GetString() 'Applied') { $operation.GetProperty('commitReceiptId').GetString() } else { $OperationId }
      $receipt = parseBytes ($utf8.GetBytes('{"receiptId":' + (quotedValue $receiptId) + ',"resourceId":' + (quotedValue $resourceId) +
        ',"operationId":' + (quotedValue $OperationId) + ',"generation":' + $base.GetProperty('generation').GetRawText() +
        ',"committedRevision":' + $operation.GetProperty('nextRevision').GetRawText() + ',"requestIds":' + $operation.GetProperty('requestIds').GetRawText() +
        ',"outputManifest":' + $operation.GetProperty('outputManifest').GetRawText() + ',"reservations":' + $operation.GetProperty('reservations').GetRawText() +
        ',"terminalEvidence":[' + (@($orderedTerminals) -join ',') + ']}'))
      if (sameText $operation.GetProperty('status').GetString() 'Applied') {
        $matches = @($state.GetProperty('commitReceipts').EnumerateArray() | Where-Object { sameText $_.GetProperty('receiptId').GetString() $receiptId })
        if ($matches.Count -ne 1 -or -not (equalValue $matches[0] $receipt)) { throw 'OperationConflict' }
        $remaining = [Collections.Generic.HashSet[string]]::new($members, [StringComparer]::Ordinal)
        foreach ($record in $state.GetProperty('requests').EnumerateArray()) {
          $id = $record.GetProperty('request').GetProperty('requestId').GetString()
          if ($members.Contains($id)) {
            if (-not $remaining.Remove($id) -or -not (equalValue $record $appliedMembers[$id])) { throw 'OperationConflict' }
          }
        }
        if ($remaining.Count) { throw 'OperationConflict' }
        return (completedResult 'Retained' 'Unchanged' 'Applied' $receiptId (sha $currentBytes))
      }
      if (sameText $operation.GetProperty('status').GetString() 'NeedsRecovery') {
        if (-not $Resume) { return (completedResult 'Retained' 'Held' 'NeedsRecovery' $null (sha $currentBytes)) }
      }
      if (-not (sameBytes $currentBytes $ExpectedStateBytes)) { throw 'SnapshotMismatch' }
      if ($seenReceipts.Contains($OperationId) -or $receiptOperations.Contains($OperationId)) { throw 'OperationConflict' }
      foreach ($plan in $state.GetProperty('preparedOperations').EnumerateArray()) {
        if (-not (sameText $plan.GetProperty('operationId').GetString() $OperationId) -and
            $plan.GetProperty('status').GetString() -cin @('Prepared', 'NeedsRecovery')) { throw 'ResourceHeld' }
      }
      $expectedProjection = $preparedProjection
      if (sameText $operation.GetProperty('status').GetString() 'NeedsRecovery') {
        $evidence = $operation.GetProperty('recoveryEvidence')
        $records = foreach ($record in $preparedProjection.GetProperty('requests').EnumerateArray()) {
          if ($members.Contains($record.GetProperty('request').GetProperty('requestId').GetString())) {
            (replaceMembers $record @{ status = '"NeedsRecovery"'; recoveryEvidence = $evidence.GetRawText() } @()).GetRawText()
          } else { $record.GetRawText() }
        }
        $expectedProjection = replaceMembers $preparedProjection @{
          requests = '[' + (@($records) -join ',') + ']'
          mutationAdmission = (replaceMembers $evidence @{ status = '"NeedsRecovery"' } @()).GetRawText()
        } @()
      } elseif (-not (sameText $state.GetProperty('mutationAdmission').GetProperty('status').GetString() 'Admitted')) { throw 'ResourceHeld' }
      if (-not (sameBytes (jsonBytes $state $fields) (jsonBytes $expectedProjection $fields))) { throw 'SnapshotMismatch' }
      $observed = observeQuartet
      if (-not $PSCmdlet.ShouldProcess($StatePath, 'Complete retained plan: sequential quartet and coherent state receipt/head commit')) {
        return (completedResult 'ProposedNotCompleted' 'WhatIf' $null $null $null)
      }
      foreach ($slot in $slots) {
        if ($observed[$slot].Kind -cin @('Third', 'Unknown')) { return (persistRecovery 'OutputPreflightMismatch') }
      }
      if (sameText $operation.GetProperty('status').GetString() 'NeedsRecovery') {
        $resumedPlan = replaceMembers $operation @{ status = '"Prepared"' } @()
        try { $saved = persistOuter (mergeOuter $state $preparedProjection $resumedPlan $null) $currentBytes } catch { throw 'PersistenceFailed' }
        $state = $saved.State; [byte[]]$currentBytes = $saved.Bytes; $operation = $resumedPlan
      }
      try {
        foreach ($slot in $slots) {
          if ($observed[$slot].Kind -ceq 'After') { continue }
          $path = $observed[$slot].Path
          $stage = Join-Path (Split-Path $path -Parent) ('.' + (Split-Path $path -Leaf) + '.' + [guid]::NewGuid().ToString('N') + '.output.tmp')
          $null = Invoke-CoordOperationFileIo -Phase Stage -StatePath $path -StagePath $stage -Bytes $afterBytes[$slot]
          if (-not (sameBytes ([IO.File]::ReadAllBytes($StatePath)) $currentBytes)) { throw 'SnapshotMismatch' }
          [byte[]]$now = Invoke-CoordOperationFileIo -Phase ReadBack -StatePath $path
          if (-not (sameBytes $now $beforeBytes[$slot])) { throw 'OutputConflict' }
          $null = Invoke-CoordOperationFileIo -Phase Replace -StatePath $path -StagePath $stage
          [byte[]]$now = Invoke-CoordOperationFileIo -Phase ReadBack -StatePath $path
          if (-not (sameBytes $now $afterBytes[$slot])) { throw 'OutputConflict' }
        }
      } catch {
        if (-not (sameBytes ([IO.File]::ReadAllBytes($StatePath)) $currentBytes)) { throw 'SnapshotMismatch' }
        return (persistRecovery 'OutputPublicationInterrupted')
      }
      if (-not (allAfter)) { return (persistRecovery 'OutputChangedBeforeCommit') }
      $appliedPlan = replaceMembers $operation @{ status = '"Applied"'; commitReceiptId = (quotedValue $OperationId) } @()
      $final = mergeOuter $state $after $appliedPlan $receipt
      try { $saved = persistOuter $final $currentBytes -RequireAfter } catch {
        if (sameText $_.Exception.Message 'OutputsChangedBeforeCommit') { return (persistRecovery 'OutputChangedBeforeCommit') }
        if (sameText $_.Exception.Message 'SnapshotMismatch') { throw 'SnapshotMismatch' }
        throw 'PersistenceFailed'
      }
      if (-not (allAfter)) { throw 'PersistenceFailed' }
      completedResult 'Applied' 'Completed' 'Applied' $OperationId (sha $saved.Bytes)
    } catch {
      $code = $_.Exception.Message
      if ($code -cnotin @('MissingEstablishedState', 'InvalidPreparedOperation', 'ImageDigestMismatch',
          'OperationConflict', 'SnapshotMismatch', 'ResourceHeld', 'PersistenceFailed')) { $code = 'InvalidPreparedOperation' }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Completion refused or held; no complete generation asserted'
      throw [InvalidOperationException]::new("Complete-CoordOperation: $code.")
    }
  }
  end {}
}

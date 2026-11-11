function Test-CoordRestoreBundle {
  # Pure G1 preflight. The approved state schema is supplied in memory.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$BundleBytes,
    [Parameter(Mandatory)][ValidatePattern('\A[0-9a-fA-F]{64}\z')][string]$ExpectedSha256,
    [Parameter(Mandatory)][string]$ExpectedResourceId,
    [Parameter(Mandatory)][string]$ExpectedLineageId,
    [Parameter(Mandatory)][string]$ExpectedGeneration,
    [Parameter(Mandatory)][string]$ExpectedCommittedRevision,
    [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$MaxBundleBytes,
    [Parameter(Mandatory)][byte[]]$StateSchemaBytes
  )

  begin {
    $ordinal = [StringComparer]::Ordinal
    $objectKind = [Text.Json.JsonValueKind]::Object

    function getMember([Text.Json.JsonElement]$Element, [string]$Name) {
      $value = [Text.Json.JsonElement]::new()
      if ($Element.ValueKind -ne $objectKind -or -not $Element.TryGetProperty($Name, [ref]$value)) {
        throw "InvalidBundleMember:$Name"
      }
      return $value
    }

    function requireMembers([Text.Json.JsonElement]$Element, [string[]]$Names) {
      foreach ($name in $Names) { $null = getMember $Element $name }
      if (@($Element.EnumerateObject()).Count -ne $Names.Count) { throw 'UnexpectedBundleMember' }
    }

    function getText([Text.Json.JsonElement]$Element, [string]$Name, [switch]$AllowEmpty) {
      $value = getMember $Element $Name
      if ($value.ValueKind -ne [Text.Json.JsonValueKind]::String) { throw "InvalidBundleString:$Name" }
      $text = $value.GetString()
      if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($text)) { throw "InvalidBundleString:$Name" }
      return $text
    }

    function readImage([Text.Json.JsonElement]$Element, [string]$BytesMember, [string]$DigestMember) {
      $encoded = getText $Element $BytesMember -AllowEmpty
      try { $bytes = [Convert]::FromBase64String($encoded) }
      catch [FormatException] { throw "NoncanonicalBundleBase64:$BytesMember" }
      if (-not $ordinal.Equals([Convert]::ToBase64String($bytes), $encoded)) {
        throw "NoncanonicalBundleBase64:$BytesMember"
      }
      $digest = getText $Element $DigestMember
      if (-not $ordinal.Equals((Get-CoordHash $bytes), $digest)) { throw "BundleImageDigestMismatch:$BytesMember" }
      [pscustomobject]@{ Bytes = $bytes; Sha256 = $digest }
    }

    function sameValue([Text.Json.JsonElement]$Left, [Text.Json.JsonElement]$Right) {
      $ordinal.Equals((Get-CoordHash (ConvertTo-CoordStateBytes $Left)), (Get-CoordHash (ConvertTo-CoordStateBytes $Right)))
    }

    function requireHistoricalApplied([Text.Json.JsonElement]$Operation, $Before, $After) {
      $operationId = getText $Operation 'operationId'
      $base = getMember $Operation 'baseHead'
      $oldGeneration = getText $base 'generation'
      $fields = @('schemaVersion','resourceId','lineageId','registeredRoots','generation','committedRevision',
        'committedOutputManifest','custodyEvidence','compatibilityEvidence','admissionEvidence','requests','claims','reservations','mutationAdmission')
      requireMembers $Before $fields
      requireMembers $After $fields
      foreach ($key in $fields | Where-Object { $_ -cnotin @('committedRevision','committedOutputManifest','requests','claims') }) {
        if (-not (sameValue (getMember $Before $key) (getMember $After $key))) { throw 'HistoricalAppliedImageMismatch' }
      }
      $receiptId = getText $Operation 'commitReceiptId'
      $receipts = @($state.GetProperty('commitReceipts').EnumerateArray() | Where-Object {
        (getText $_ 'receiptId') -ceq $receiptId -or (getText $_ 'operationId') -ceq $operationId
      })
      if ($receipts.Count -ne 1) { throw 'HistoricalAppliedReceiptMismatch' }
      $receipt = $receipts[0]
      foreach ($pair in @(@('receiptId',$receiptId),@('operationId',$operationId),@('resourceId',$ExpectedResourceId),
          @('generation',$oldGeneration),@('committedRevision',(getText $Operation 'nextRevision')))) {
        if (-not $ordinal.Equals((getText $receipt $pair[0]),$pair[1])) { throw 'HistoricalAppliedReceiptMismatch' }
      }
      foreach ($key in 'requestIds','outputManifest','reservations') {
        if (-not (sameValue (getMember $receipt $key) (getMember $Operation $key))) { throw 'HistoricalAppliedReceiptMismatch' }
      }
      if ((getText $Before 'committedRevision') -cne (getText $base 'committedRevision') -or
          (getText $After 'committedRevision') -cne (getText $Operation 'nextRevision') -or
          -not (sameValue (getMember $Before 'committedOutputManifest') (getMember $base 'outputManifest')) -or
          -not (sameValue (getMember $After 'committedOutputManifest') (getMember $Operation 'outputManifest')) -or
          -not (sameValue (getMember $Before 'reservations') (getMember $Operation 'reservations'))) {
        throw 'HistoricalAppliedImageMismatch'
      }
      $members = @($Operation.GetProperty('requestIds').EnumerateArray())
      $terminals = @($receipt.GetProperty('terminalEvidence').EnumerateArray())
      $seen = [Collections.Generic.HashSet[string]]::new($ordinal)
      if ($members.Count -eq 0 -or $terminals.Count -ne $members.Count) { throw 'HistoricalAppliedRequestMismatch' }
      $beforeRequests = @($Before.GetProperty('requests').EnumerateArray())
      $afterRequests = @($After.GetProperty('requests').EnumerateArray())
      if ($beforeRequests.Count -ne $afterRequests.Count) { throw 'HistoricalAppliedRequestMismatch' }
      $memberIds = @($members | ForEach-Object { $_.GetString() })
      for ($index=0; $index -lt $beforeRequests.Count; $index++) {
        $recordId = getText (getMember $beforeRequests[$index] 'request') 'requestId'
        if ((getText (getMember $afterRequests[$index] 'request') 'requestId') -cne $recordId -or
            ($recordId -cnotin $memberIds -and -not (sameValue $beforeRequests[$index] $afterRequests[$index]))) {
          throw 'HistoricalAppliedRequestMismatch'
        }
      }
      for ($i=0; $i -lt $members.Count; $i++) {
        $requestId = $members[$i].GetString()
        if (-not $seen.Add($requestId)) { throw 'HistoricalAppliedRequestMismatch' }
        $outer = @($state.GetProperty('requests').EnumerateArray() | Where-Object { (getText (getMember $_ 'request') 'requestId') -ceq $requestId })
        $beforeRecords = @($Before.GetProperty('requests').EnumerateArray() | Where-Object { (getText (getMember $_ 'request') 'requestId') -ceq $requestId })
        $afterRecords = @($After.GetProperty('requests').EnumerateArray() | Where-Object { (getText (getMember $_ 'request') 'requestId') -ceq $requestId })
        if ($outer.Count -ne 1 -or $beforeRecords.Count -ne 1 -or $afterRecords.Count -ne 1) { throw 'HistoricalAppliedRequestMismatch' }
        $prior=$beforeRecords[0]; $applied=$afterRecords[0]; $request=getMember $prior 'request'
        if ((getText $prior 'status') -cne 'Pending' -or (getText $applied 'status') -cne 'Applied' -or
            (getText $applied 'preparedOperationId') -cne $operationId -or
            (getText $request 'resourceId') -cne $ExpectedResourceId -or (getText $request 'generation') -cne $oldGeneration -or
            (getText $request 'expectedRevision') -cne (getText $base 'committedRevision') -or
            -not (sameValue $outer[0] $applied)) { throw 'HistoricalAppliedRequestMismatch' }
        foreach ($key in 'request','digest','originalRequestJson','queueOrdinal') {
          if (-not (sameValue (getMember $prior $key) (getMember $applied $key))) { throw 'HistoricalAppliedRequestMismatch' }
        }
        $terminal=getMember $applied 'terminalEvidence'
        if ((getText $terminal 'resourceId') -cne $ExpectedResourceId -or (getText $terminal 'requestId') -cne $requestId -or
            (getText $terminal 'status') -cne 'Applied' -or (getText $terminal 'digest') -cne (getText $prior 'digest') -or
            -not (sameValue $terminal $terminals[$i])) { throw 'HistoricalAppliedRequestMismatch' }
      }
    }
  }

  process {
    if ($BundleBytes.Length -gt $MaxBundleBytes) { throw 'BundleByteLimitExceeded' }
    $bytes = [byte[]]$BundleBytes.Clone()
    $digest = Get-CoordHash $bytes
    if (-not $ordinal.Equals($digest, $ExpectedSha256.ToLowerInvariant())) { throw 'BundleDigestMismatch' }

    $bundle = Read-CoordJsonBytes $bytes
    $identity = [ordered]@{
      resourceId = $ExpectedResourceId
      lineageId = $ExpectedLineageId
      generation = $ExpectedGeneration
      committedRevision = $ExpectedCommittedRevision
    }
    requireMembers $bundle (@('schemaVersion', 'stateBytesBase64', 'stateDigest', 'custodyBytesBase64',
        'custodyDigest', 'observedOutputs') + @($identity.Keys))
    if (-not $ordinal.Equals((getText $bundle 'schemaVersion'), 'Coordination-export-v1')) { throw 'UnsupportedExportSchema' }
    foreach ($name in $identity.Keys) {
      if (-not $ordinal.Equals((getText $bundle $name), $identity[$name])) { throw "BundleIdentityMismatch:$name" }
    }

    $stateImage = readImage $bundle 'stateBytesBase64' 'stateDigest'
    $custodyImage = readImage $bundle 'custodyBytesBase64' 'custodyDigest'
    $observed = getMember $bundle 'observedOutputs'
    $slots = @('markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml')
    requireMembers $observed $slots
    $outputs = [ordered]@{}
    foreach ($slot in $slots) {
      $item = getMember $observed $slot
      requireMembers $item @('path', 'digest', 'bytesBase64')
      $image = readImage $item 'bytesBase64' 'digest'
      $outputs[$slot] = [pscustomobject]@{
        Path = getText $item 'path'
        Bytes = $image.Bytes
        Sha256 = $image.Sha256
      }
    }

    $state = Read-CoordJsonBytes $stateImage.Bytes
    $schema = [byte[]]$StateSchemaBytes.Clone()
    if ((Get-CoordHash $schema) -cne '4f148321844e3f2970c7190d79fb4371e609a62bef093e43a7adb855c9bb9bfa') {
      throw 'UnexpectedPinnedStateSchema'
    }
    $schemaText = [Text.UTF8Encoding]::new($false, $true).GetString($schema)
    try { $valid = Test-Json -Json $state.GetRawText() -Schema $schemaText -ErrorAction Stop }
    catch { throw 'InvalidStateSchema' }
    if (-not $valid) { throw 'InvalidStateSchema' }

    $custody = Read-CoordJsonBytes $custodyImage.Bytes
    if (-not $ordinal.Equals((getText $custody 'schemaVersion'), 'Coordination-custody-v1')) { throw 'UnsupportedCustodySchema' }
    foreach ($name in $identity.Keys) {
      if (-not $ordinal.Equals((getText $state $name), $identity[$name])) { throw "StateIdentityMismatch:$name" }
    }
    foreach ($name in @('resourceId', 'lineageId', 'generation')) {
      if (-not $ordinal.Equals((getText $custody $name), $identity[$name])) { throw "CustodyIdentityMismatch:$name" }
    }

    $pending = getMember $custody 'pendingWrite'
    $operations = @($state.GetProperty('preparedOperations').EnumerateArray())
    $retainedIds = [Collections.Generic.HashSet[string]]::new($ordinal)
    foreach ($operation in $operations) {
      if (-not $retainedIds.Add((getText $operation 'operationId'))) { throw 'DuplicatePreparedOperation' }
    }
    $journalOperationId = $null
    if ($pending.ValueKind -ne [Text.Json.JsonValueKind]::Null) {
      switch -CaseSensitive (getText $pending 'kind') {
        'State' {
          requireMembers $pending @('kind','beforeDigest','afterDigest','afterBytesBase64')
          $after = readImage $pending 'afterBytesBase64' 'afterDigest'
          $afterState = Read-CoordJsonBytes $after.Bytes
          if (-not (Test-Json -Json $afterState.GetRawText() -Schema $schemaText -ErrorAction Stop)) { throw 'InvalidStateSchema' }
          foreach ($key in 'resourceId','lineageId','generation') {
            if ((getText $afterState $key) -cne $identity[$key]) { throw 'PendingStateIdentityMismatch' }
          }
          if ($stateImage.Sha256 -cnotin @((getText $pending 'beforeDigest'), $after.Sha256) -or
              (getText $custody 'stateSha256') -cne (getText $pending 'beforeDigest')) { throw 'PendingStateDigestMismatch' }
        }
        'Prepare' {
          requireMembers $pending @('kind','operationJson')
          $operation = Read-CoordJsonBytes ([Text.Encoding]::UTF8.GetBytes((getText $pending 'operationJson')))
          $journalOperationId = getText $operation 'operationId'
          $schemaObject = $schemaText | ConvertFrom-Json -AsHashtable -Depth 100
          $operationSchema = @{ '$ref' = '#/definitions/statePreparedOperation'; definitions = $schemaObject.definitions } | ConvertTo-Json -Depth 100
          if (-not (Test-Json -Json $operation.GetRawText() -Schema $operationSchema -ErrorAction Stop)) { throw 'InvalidPreparedOperation' }
          $operations += $operation
        }
        'Complete' {
          requireMembers $pending @('kind','operationId')
          $journalOperationId = getText $pending 'operationId'
          if (@($operations | Where-Object { (getText $_ 'operationId') -ceq (getText $pending 'operationId') }).Count -ne 1) {
            throw 'MissingPendingOperation'
          }
        }
        default { throw 'UnsupportedRecoveryJournal' }
      }
    } elseif (-not $ordinal.Equals((getText $custody 'stateSha256'), $stateImage.Sha256)) { throw 'CustodyWatermarkMismatch' }
    if ($pending.ValueKind -ne [Text.Json.JsonValueKind]::Null -and (getText $pending 'kind') -cne 'State' -and
        (getText $custody 'stateSha256') -cne $stateImage.Sha256) {
      # A completed state image may precede the final custody watermark write.
      # Only a retained exact operation image can account for that state below.
      if ($operations.Count -eq 0) { throw 'CustodyWatermarkMismatch' }
    }
    $recoveryImages = @{}
    foreach ($operation in $operations) {
      $operationId = getText $operation 'operationId'
      $baseGeneration = getText (getMember $operation 'baseHead') 'generation'
      $historical = -not $ordinal.Equals($baseGeneration,$ExpectedGeneration)
      if ((getText $operation 'resourceId') -cne $ExpectedResourceId -or ($historical -and
          ((getText $operation 'status') -cne 'Applied' -or -not $retainedIds.Contains($operationId) -or
           $ordinal.Equals($journalOperationId,$operationId)))) {
        throw 'PreparedOperationIdentityMismatch'
      }
      $logicalImages = @{}
      foreach ($imageName in 'beforeStateImage','afterStateImage') {
        $logicalImage = readImage (getMember $operation $imageName) 'bytesBase64' 'digest'
        $logicalState = Read-CoordJsonBytes $logicalImage.Bytes
        $logicalImages[$imageName] = $logicalState
        foreach ($key in 'resourceId','lineageId','generation') {
          $expected = if ($key -ceq 'generation' -and $historical) { $baseGeneration } else { $identity[$key] }
          if ((getText $logicalState $key) -cne $expected) { throw 'PreparedImageIdentityMismatch' }
        }
      }
      if ($historical) { requireHistoricalApplied $operation $logicalImages.beforeStateImage $logicalImages.afterStateImage }
      foreach ($slot in $slots) {
        foreach ($side in 'beforeOutputs','afterOutputs') {
          $item = (getMember $operation $side).GetProperty($slot)
          $image = readImage $item 'bytesBase64' 'digest'
          if ((getText $item 'path') -cne $outputs[$slot].Path) { throw 'RecoveryOutputPathMismatch' }
          # Old terminal images are retained evidence, never authority to accept
          # drift from the current committed quartet in a later generation.
          if (-not $historical) { $recoveryImages["$slot/$($image.Sha256)"] = $true }
        }
      }
    }
    if ($ordinal.Equals($state.GetProperty('mutationAdmission').GetProperty('status').GetString(), 'NeedsRecovery') -and
        $operations.Count -eq 0 -and $pending.ValueKind -eq [Text.Json.JsonValueKind]::Null) { throw 'StateRequiresJournalProof' }
    foreach ($request in $state.GetProperty('requests').EnumerateArray()) {
      if ($request.GetProperty('status').GetString() -cin @('Prepared', 'NeedsRecovery') -and
          @($operations | Where-Object {
            @($_.GetProperty('requestIds').EnumerateArray() | ForEach-Object { $_.GetString() }) -ccontains $request.GetProperty('request').GetProperty('requestId').GetString()
          }).Count -eq 0) {
        throw 'MissingPreparedRequestPlan'
      }
    }

    $manifest = getMember $state 'committedOutputManifest'
    foreach ($slot in $slots) {
      $entry = getMember $manifest $slot
      if (-not $ordinal.Equals($outputs[$slot].Path, (getText $entry 'path')) -or
          (-not $ordinal.Equals($outputs[$slot].Sha256, (getText $entry 'digest')) -and
           -not $recoveryImages.ContainsKey("$slot/$($outputs[$slot].Sha256)"))) {
        throw "QuartetDriftRequiresJournalProof:$slot"
      }
    }

    [pscustomobject]@{
      Status = 'VerifiedBundleEvidence'
      BundleSha256 = $digest
      ResourceId = $ExpectedResourceId
      LineageId = $ExpectedLineageId
      Generation = $ExpectedGeneration
      CommittedRevision = $ExpectedCommittedRevision
      State = $stateImage
      Custody = $custodyImage
      ObservedOutputs = $outputs
    }
  }

  end {}
}

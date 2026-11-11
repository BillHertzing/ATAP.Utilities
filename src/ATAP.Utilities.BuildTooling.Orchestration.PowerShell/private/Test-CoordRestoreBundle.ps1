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
          $schemaObject = $schemaText | ConvertFrom-Json -AsHashtable -Depth 100
          $operationSchema = @{ '$ref' = '#/definitions/statePreparedOperation'; definitions = $schemaObject.definitions } | ConvertTo-Json -Depth 100
          if (-not (Test-Json -Json $operation.GetRawText() -Schema $operationSchema -ErrorAction Stop)) { throw 'InvalidPreparedOperation' }
          $operations += $operation
        }
        'Complete' {
          requireMembers $pending @('kind','operationId')
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
      if ((getText $operation 'resourceId') -cne $ExpectedResourceId -or
          (getText (getMember $operation 'baseHead') 'generation') -cne $ExpectedGeneration) {
        throw 'PreparedOperationIdentityMismatch'
      }
      foreach ($imageName in 'beforeStateImage','afterStateImage') {
        $logicalImage = readImage (getMember $operation $imageName) 'bytesBase64' 'digest'
        $logicalState = Read-CoordJsonBytes $logicalImage.Bytes
        foreach ($key in 'resourceId','lineageId','generation') {
          if ((getText $logicalState $key) -cne $identity[$key]) { throw 'PreparedImageIdentityMismatch' }
        }
      }
      foreach ($slot in $slots) {
        foreach ($side in 'beforeOutputs','afterOutputs') {
          $item = (getMember $operation $side).GetProperty($slot)
          $image = readImage $item 'bytesBase64' 'digest'
          if ((getText $item 'path') -cne $outputs[$slot].Path) { throw 'RecoveryOutputPathMismatch' }
          $recoveryImages["$slot/$($image.Sha256)"] = $true
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

function Update-CoordWitness {
  <#
  .SYNOPSIS
    Appends one reviewed actor or exact-request grant to an established witness.
  .DESCRIPTION
    Requires the existing custodian/coordinator context and both resource locks.
    ApprovalReference records independently established authority; it grants none.
    Only one array append is allowed. All other raw JSON subtrees and prior array
    entries/order are frozen. This never establishes custody, changes package pins,
    transfers the active writer, recovers pending work or changes state.
  .PARAMETER HolderId
    Existing registered Coordinator, also the witness coordinatorId.
  .PARAMETER SessionId
    Exact registered session of that coordinator.
  .PARAMETER ExpectedWitnessBytes
    Exact reviewed existing witness bytes; stale snapshots refuse without merging.
  .PARAMETER ProposedWitnessBytes
    Strict JSON image with exactly one actor OR authorization appended.
  .PARAMETER UpdateId
    Nonempty unique GUID for retained CreateNew sidecars beside the witness.
  .PARAMETER ApprovalReference
    Audit correlation for the separately verified approval of this exact delta.
  .OUTPUTS
    Updated with image digests and evidence paths, or unvalidated ProposedOnly.
  .EXAMPLE
    Update-CoordWitness -HolderId $holder -SessionId $session -ExpectedWitnessBytes $before -ProposedWitnessBytes $after -UpdateId $id -ApprovalReference $approval -WhatIf
  .NOTES
    Unknown top-level fields are preserved, not interpreted. Nested JSON whitespace,
    number lexemes and string escapes are compared literally for frozen subtrees.
    The existing atomic helper reports no failure phase: any failure after entering
    it is conservatively uncertain, including a possible pre-replacement failure.
    Preserve evidence and reconcile under custody; never blindly retry or restore.
  .LINK
    ../Documentation/Producer-v1.md
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$HolderId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SessionId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][byte[]]$ExpectedWitnessBytes,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][byte[]]$ProposedWitnessBytes,
    [Parameter(Mandatory)][guid]$UpdateId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApprovalReference
  )
  begin {
    $fn = 'Update-CoordWitness'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $ordinal = [StringComparer]::Ordinal
    function sameBytes([byte[]]$Left, [byte[]]$Right) {
      $ordinal.Equals([Convert]::ToBase64String($Left), [Convert]::ToBase64String($Right))
    }
    function requiredText([Text.Json.JsonElement]$Object, [string]$Name) {
      $v = [Text.Json.JsonElement]::new()
      if (-not $Object.TryGetProperty($Name, [ref]$v) -or
          $v.ValueKind -ne [Text.Json.JsonValueKind]::String -or [string]::IsNullOrWhiteSpace($v.GetString())) {
        throw 'InvalidWitnessDelta'
      }
      return $v.GetString()
    }
    function checkEntries([Text.Json.JsonElement]$Array, [string]$Kind, [string]$Sid) {
      $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      $requests = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($entry in $Array.EnumerateArray()) {
        if ($entry.ValueKind -ne [Text.Json.JsonValueKind]::Object) { throw 'InvalidWitnessDelta' }
        $propertyCount = @($entry.EnumerateObject()).Count
        if ($ordinal.Equals($Kind, 'actors')) {
          if ($propertyCount -ne 4) { throw 'InvalidWitnessDelta' }
          $holder = requiredText $entry 'holderId'; $session = requiredText $entry 'sessionId'
          $role = requiredText $entry 'role'
          if (-not $ordinal.Equals((requiredText $entry 'windowsSid'), $Sid) -or
              (-not $ordinal.Equals($role, 'Coordinator') -and -not $ordinal.Equals($role, 'Worker'))) { throw 'InvalidWitnessDelta' }
          # Length prefix avoids tuple collisions even when IDs contain delimiters.
          if (-not $seen.Add($holder.Length.ToString() + ':' + $holder + $session)) { throw 'InvalidWitnessDelta' }
        } else {
          if ($propertyCount -notin @(3, 4)) { throw 'InvalidWitnessDelta' }
          $reference = requiredText $entry 'reference'; $request = requiredText $entry 'requestId'
          if ((requiredText $entry 'digest') -cnotmatch '\A[0-9a-f]{64}\z') { throw 'InvalidWitnessDelta' }
          if ($propertyCount -eq 4) { $null = requiredText $entry 'claimId' }
          if (-not $seen.Add($reference) -or -not $requests.Add($request)) { throw 'InvalidWitnessDelta' }
        }
      }
    }
  }
  process {
    if (-not $PSCmdlet.ShouldProcess($HolderId, 'Append one independently approved established-witness registration')) {
      return [pscustomobject]@{ Status = 'ProposedOnly'; UpdateId = $UpdateId.ToString('D') }
    }
    $ErrorActionPreference = 'Stop'
    $null = Get-Command Write-PSFMessage -ErrorAction Stop
    if (-not (Get-Command Read-CoordProducerContext -ErrorAction SilentlyContinue)) {
      foreach ($name in @('CoordProducerJson', 'Enter-CoordResourceLease', 'CoordProducer')) {
        . (Join-Path $PSScriptRoot "../private/$name.ps1")
      }
    }
    if (-not (Get-Command Invoke-CoordOperationFileIo -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '../private/Save-CoordOperation.ps1')
    }
    $context = $null; $replacementMayHaveOccurred = $false; $result = $null
    try {
      if ($UpdateId -eq [guid]::Empty -or [string]::IsNullOrWhiteSpace($ApprovalReference)) { throw 'InvalidWitnessDelta' }
      # Clone caller arrays before acquiring custody; no caller-controlled Context is accepted.
      [byte[]]$expected = $ExpectedWitnessBytes.Clone()
      [byte[]]$proposed = $ProposedWitnessBytes.Clone()
      $context = Read-CoordProducerContext -HolderId $HolderId -SessionId $SessionId -Role Export
      if (-not $ordinal.Equals($context.Actor.role, 'Coordinator') -or
          -not $ordinal.Equals($context.Record.coordinatorId, $HolderId) -or
          -not $ordinal.Equals($context.Actor.holderId, $HolderId) -or
          -not $ordinal.Equals($context.Actor.sessionId, $SessionId) -or
          -not $ordinal.Equals($context.Actor.windowsSid, $context.Record.custodianSid)) { throw 'ActorNotAuthorized' }
      if (-not (sameBytes $context.RecordBytes $expected) -or
          -not (sameBytes (Invoke-CoordOperationFileIo -Phase ReadBack -StatePath $context.RecordPath) $expected)) { throw 'SnapshotMismatch' }
      $before = Read-CoordJsonBytes $expected
      $after = Read-CoordJsonBytes $proposed
      if ($before.ValueKind -ne [Text.Json.JsonValueKind]::Object -or $after.ValueKind -ne [Text.Json.JsonValueKind]::Object) { throw 'InvalidWitnessDelta' }
      if ($before.GetProperty('pendingWrite').ValueKind -ne [Text.Json.JsonValueKind]::Null) { throw 'NeedsRecovery' }
      if ($context.State.GetProperty('mutationAdmission').GetProperty('status').GetString() -cne 'Admitted') { throw 'ResourceHeld' }
      foreach ($name in @('requests', 'preparedOperations')) {
        foreach ($entry in $context.State.GetProperty($name).EnumerateArray()) {
          if ($entry.GetProperty('status').GetString() -cin @('Pending', 'Prepared', 'NeedsRecovery')) { throw 'WitnessWorkPending' }
        }
      }
      $beforeProperties = @($before.EnumerateObject()); $afterProperties = @($after.EnumerateObject())
      if ($beforeProperties.Count -ne $afterProperties.Count) { throw 'InvalidWitnessDelta' }
      $appends = 0
      for ($i = 0; $i -lt $beforeProperties.Count; $i++) {
        $left = $beforeProperties[$i]; $right = $afterProperties[$i]
        if (-not $ordinal.Equals($left.Name, $right.Name)) { throw 'InvalidWitnessDelta' }
        if ($ordinal.Equals($left.Name, 'actors') -or $ordinal.Equals($left.Name, 'authorizations')) {
          if ($left.Value.ValueKind -ne [Text.Json.JsonValueKind]::Array -or $right.Value.ValueKind -ne [Text.Json.JsonValueKind]::Array) { throw 'InvalidWitnessDelta' }
          checkEntries $right.Value $left.Name $context.Record.custodianSid
          $old = @($left.Value.EnumerateArray()); $new = @($right.Value.EnumerateArray())
          if ($new.Count -eq $old.Count + 1) { $appends++ }
          elseif (-not $ordinal.Equals($left.Value.GetRawText(), $right.Value.GetRawText())) { throw 'InvalidWitnessDelta' }
          for ($j = 0; $j -lt $old.Count; $j++) {
            if (-not $ordinal.Equals($old[$j].GetRawText(), $new[$j].GetRawText())) { throw 'InvalidWitnessDelta' }
          }
        } elseif (-not $ordinal.Equals($left.Value.GetRawText(), $right.Value.GetRawText())) { throw 'InvalidWitnessDelta' }
      }
      if ($appends -ne 1) { throw 'InvalidWitnessDelta' }
      Assert-CoordActorRetirement $after $context.Record.custodianSid
      [byte[]]$stateBytes = Invoke-CoordOperationFileIo -Phase ReadBack -StatePath $context.StatePath
      if (-not (sameBytes $stateBytes $context.StateBytes) -or (Get-CoordHash $stateBytes) -cne $context.Record.stateSha256) { throw 'SnapshotMismatch' }
      $parent = [IO.Path]::GetDirectoryName($context.RecordPath)
      Assert-CoordProtection $parent $context.Record.custodianSid
      $prefix = $context.RecordPath + '.update-' + $UpdateId.ToString('D')
      $paths = [ordered]@{ Before = $prefix + '.before.bin'; After = $prefix + '.after.bin'
        Intent = $prefix + '.intent.json'; Receipt = $prefix + '.receipt.json' }
      foreach ($path in $paths.Values) {
        $null = Assert-CoordOrdinaryPath $path
        if (Test-Path -LiteralPath $path) { throw 'WitnessAuditExists' }
      }
      function retain([string]$Path, [byte[]]$Bytes) {
        try {
          $null = Invoke-CoordOperationFileIo -Phase Stage -StatePath $Path -StagePath $Path -Bytes $Bytes
          if (-not (sameBytes (Invoke-CoordOperationFileIo -Phase ReadBack -StatePath $Path) $Bytes)) { throw 'AuditReadbackFailed' }
          Assert-CoordProtection $Path $context.Record.custodianSid
        } catch { throw [InvalidOperationException]::new('WitnessAuditPersistenceFailed', $_.Exception) }
      }
      $beforeDigest = Get-CoordHash $expected; $afterDigest = Get-CoordHash $proposed
      $intent = ConvertTo-CoordStateBytes (ConvertTo-CoordElement ([ordered]@{
        updateId = $UpdateId.ToString('D'); approvalReference = $ApprovalReference
        resourceId = $context.Record.resourceId; lineageId = $context.Record.lineageId; generation = $context.Record.generation
        beforeDigest = $beforeDigest; afterDigest = $afterDigest
      }))
      retain $paths.Before $expected
      retain $paths.After $proposed
      retain $paths.Intent $intent
      # No phase is returned by the existing writer. From here, every failure is
      # conservatively uncertain; do not infer that an exception means no effect.
      $replacementMayHaveOccurred = $true
      Write-CoordAtomicBytes -Path $context.RecordPath -ExpectedBytes $expected -Bytes $proposed
      if (-not (sameBytes (Invoke-CoordOperationFileIo -Phase ReadBack -StatePath $context.RecordPath) $proposed)) { throw 'WitnessReadbackFailed' }
      Assert-CoordProtection $context.RecordPath $context.Record.custodianSid
      if (-not (sameBytes (Invoke-CoordOperationFileIo -Phase ReadBack -StatePath $context.StatePath) $stateBytes)) { throw 'StateChanged' }
      $receipt = ConvertTo-CoordStateBytes (ConvertTo-CoordElement ([ordered]@{
        updateId = $UpdateId.ToString('D'); status = 'Updated'; beforeDigest = $beforeDigest
        afterDigest = $afterDigest; stateDigest = Get-CoordHash $stateBytes
      }))
      retain $paths.Receipt $receipt
      $result = [pscustomobject]@{ Status = 'Updated'; UpdateId = $UpdateId.ToString('D')
        BeforeDigest = $beforeDigest; AfterDigest = $afterDigest; EvidencePaths = $paths }
    } catch {
      $primaryFailure = $_
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Witness update refused or uncertain; preserve images and reconcile under custody before further work.'
      } catch { } # Logging must never replace the persistence/refusal error.
      if ($replacementMayHaveOccurred) { throw [InvalidOperationException]::new('WitnessUpdateOutcomeUncertain', $primaryFailure.Exception) }
      throw $primaryFailure
    } finally {
      if ($context) {
        try {
          try { $context.BoardLease.Dispose() } finally { $context.Lease.Dispose() }
        } catch {
          if ($replacementMayHaveOccurred) { throw [InvalidOperationException]::new('WitnessUpdateOutcomeUncertain', $_.Exception) }
          throw
        }
      }
    }
    return $result
  }
  end {}
}

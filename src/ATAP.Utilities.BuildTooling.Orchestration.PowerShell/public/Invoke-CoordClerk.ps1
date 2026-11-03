function Invoke-CoordClerk {
  <#
  .SYNOPSIS
    Drains a bounded queue using established Windows-account custody.
  .DESCRIPTION
    Recovers existing prepared work before new batches. The optional borrowed
    same-process control retains Stop-CoordClerk's nine-key cancellation contract.
    Chat IDs are registered cooperative roles, not OS-authenticated principals.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param([Parameter(Mandatory)][string]$HolderId, [Parameter(Mandatory)][string]$SessionId,
    [Collections.ObjectModel.ReadOnlyDictionary[string, object]]$Control)
  begin {
    $fn = 'Invoke-CoordClerk'; $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $null = Get-Command Write-PSFMessage -ErrorAction Stop
    if (-not (Get-Command Read-CoordProducerContext -ErrorAction SilentlyContinue)) {
      foreach ($file in Get-ChildItem (Join-Path $PSScriptRoot '../private') -Filter '*.ps1' -File) { . $file.FullName }
    }
  }
  process {
    if (-not $PSCmdlet.ShouldProcess($HolderId, 'Drain configured coordination resource')) {
      return [pscustomobject]@{ Status = 'ProposedOnly'; Applied = 0; Rejected = 0; DrainStatus = 'NotStarted' }
    }
    $context = $null; $clock = [Diagnostics.Stopwatch]::StartNew()
    try {
      $context = Read-CoordProducerContext -HolderId $HolderId -SessionId $SessionId -Role Clerk -AllowPending
      $token = [Threading.CancellationToken]::None
      if ($Control) {
        $expected = @('StatePath', 'ResourceId', 'LineageId', 'Generation', 'OwnerSessionId', 'InvocationId', 'ProcessId', 'StopSource', 'StartGate')
        if ($Control.Count -ne 9) { throw 'InvalidControl' }
        foreach ($key in $expected) { if (-not $Control.ContainsKey($key)) { throw 'InvalidControl' } }
        $values = @{ StatePath = $context.StatePath; ResourceId = $context.Record.resourceId
          LineageId = $context.Record.lineageId; Generation = $context.Record.generation; OwnerSessionId = $SessionId }
        foreach ($key in $values.Keys) { if ($Control[$key] -cne $values[$key]) { throw 'ControlBindingMismatch' } }
        if ($Control['ProcessId'] -ne [Environment]::ProcessId -or
            $Control['StopSource'] -isnot [Threading.CancellationTokenSource] -or
            $Control['StartGate'] -isnot [Threading.Tasks.TaskCompletionSource[bool]] -or
            [string]::IsNullOrWhiteSpace($Control['InvocationId'])) { throw 'InvalidControl' }
        $token = $Control['StopSource'].Token
        if (($Control['StartGate'].Task.CreationOptions -band [Threading.Tasks.TaskCreationOptions]::RunContinuationsAsynchronously) -eq 0) { throw 'InvalidControl' }
        if (-not $Control['StartGate'].TrySetResult($true)) { throw 'ControlAlreadyUsed' }
      }
      $applied = 0; $rejected = 0; $considered = [long]0; $batches = 0
      $exitReason = 'QueueObserved'
      if (-not $token.IsCancellationRequested) {
        Resume-CoordProducerWrite $context
        foreach ($operation in @($context.State.GetProperty('preparedOperations').EnumerateArray())) {
          if ($operation.GetProperty('status').GetString() -cin @('Prepared', 'NeedsRecovery')) {
            Invoke-CoordDurableOperation -Context $context -Phase Complete -OperationId $operation.GetProperty('operationId').GetString()
          }
        }
        while (-not $token.IsCancellationRequested -and $considered -lt $context.Limits.MaxDrainRequests -and
            $batches -lt $context.Limits.MaxDrainBatches -and $clock.ElapsedMilliseconds -lt $context.Limits.MaxDrainMilliseconds) {
          $batch = Invoke-CoordProducerBatch -Context $context -MaximumRequests ($context.Limits.MaxDrainRequests - $considered)
          $considered += $batch.Considered; $applied += $batch.Applied; $rejected += $batch.Rejected
          if (-not $batch.Progress) { break }
          $batches++
        }
      }
      $pending = @($context.State.GetProperty('requests').EnumerateArray() | Where-Object {
        $_.GetProperty('status').GetString() -cin @('Pending', 'Prepared', 'NeedsRecovery') })
      $recovering = [bool]$context.Record.pendingWrite -or @($context.State.GetProperty('preparedOperations').EnumerateArray() |
        Where-Object { $_.GetProperty('status').GetString() -cin @('Prepared', 'NeedsRecovery') }).Count -gt 0
      if ($token.IsCancellationRequested) { $exitReason = 'StoppedAtBoundary' }
      elseif ($pending.Count) { $exitReason = 'BudgetOrPredecessorBoundary' }
      [pscustomobject]@{ Status = 'Observed'; ResourceId = $context.Record.resourceId; Applied = $applied; Rejected = $rejected
        Considered = $considered; Batches = $batches; Remaining = $pending.Count
        DrainStatus = if ($recovering) { 'NeedsRecovery' } elseif ($pending.Count -eq 0) { 'Drained' } else { 'RemainingWork' }
        ExitReason = $exitReason; StopObserved = $token.IsCancellationRequested
        RecordedHead = $context.State.GetProperty('committedRevision').GetString(); ElapsedMilliseconds = $clock.ElapsedMilliseconds }
    } finally {
      $clock.Stop()
      if ($context) { $context.BoardLease.Dispose(); $context.Lease.Dispose() }
    }
  }
  end {}
}

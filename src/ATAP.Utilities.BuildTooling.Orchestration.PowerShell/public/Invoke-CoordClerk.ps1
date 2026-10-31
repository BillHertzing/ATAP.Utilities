function Invoke-CoordClerk {
  <#
  .SYNOPSIS
    Observes a borrowed clerk control at a no-work boundary.
  .DESCRIPTION
    PARTIAL: this function never admits work, opens state, schedules, recovers,
    renders or establishes authority or custody. The trusted caller supplies the
    original live control and separately establishes authority. Matching values do
    not authenticate control references. Every real invocation is held because
    producer bindings remain incomplete. Borrowed objects are never disposed.
  .PARAMETER StatePath
    Caller-resolved absolute state path; not accessed.
  .PARAMETER ResourceId
    Caller-supplied resource identity.
  .PARAMETER LineageId
    Caller-supplied lineage identity.
  .PARAMETER Generation
    Caller-supplied generation.
  .PARAMETER OwnerSessionId
    Caller-supplied owner session.
  .PARAMETER InvocationId
    Caller-supplied single-use invocation identity.
  .PARAMETER Control
    Original borrowed nine-key same-process control.
  .OUTPUTS
    PSCustomObject reporting proposed or held control observation, never drain.
  .EXAMPLE
    Invoke-CoordClerk @bindings -Control $control -WhatIf
  .NOTES
    Control-only partial source; not an operational producer.
  .LINK
    ../Documentation/Coordination-v1.md
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$StatePath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ResourceId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$LineageId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Generation,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$OwnerSessionId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$InvocationId,
    [Parameter(Mandatory)][ValidateNotNull()]
    [Collections.ObjectModel.ReadOnlyDictionary[string, object]]$Control
  )
  begin {
    $fn = 'Invoke-CoordClerk'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $null = Get-Command Write-PSFMessage -ErrorAction Stop
  }
  process {
    $failure = 'InvalidControl'
    try {
      if ($Control.GetType() -ne [Collections.ObjectModel.ReadOnlyDictionary[string, object]]) { throw 'InvalidControl' }
      $bindings = [ordered]@{
        StatePath = $StatePath; ResourceId = $ResourceId; LineageId = $LineageId
        Generation = $Generation; OwnerSessionId = $OwnerSessionId; InvocationId = $InvocationId
      }
      $expected = @($bindings.Keys) + @('ProcessId', 'StopSource', 'StartGate')
      $keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($key in $Control.Keys) { $null = $keys.Add($key) }
      if ($Control.Count -ne $expected.Count) { throw 'InvalidControl' }
      foreach ($key in $expected) { if (-not $keys.Contains($key)) { throw 'InvalidControl' } }
      foreach ($key in $bindings.Keys) {
        if ($Control[$key] -isnot [string] -or [string]::IsNullOrWhiteSpace($Control[$key]) -or
            [string]::IsNullOrWhiteSpace($bindings[$key])) { throw 'InvalidControl' }
      }
      if (-not [IO.Path]::IsPathFullyQualified($StatePath)) { throw 'InvalidControl' }
      if ($Control['ProcessId'] -isnot [int] -or $Control['ProcessId'] -ne [Environment]::ProcessId -or
          $null -eq $Control['StopSource'] -or $Control['StopSource'].GetType() -ne [Threading.CancellationTokenSource] -or
          $null -eq $Control['StartGate'] -or $Control['StartGate'].GetType() -ne [Threading.Tasks.TaskCompletionSource[bool]]) {
        throw 'InvalidControl'
      }
      $asyncFlag = [Threading.Tasks.TaskCreationOptions]::RunContinuationsAsynchronously
      if (($Control['StartGate'].Task.CreationOptions -band $asyncFlag) -ne $asyncFlag) { throw 'InvalidControl' }
      $failure = 'ControlBindingMismatch'
      foreach ($key in $bindings.Keys) {
        if (-not [string]::Equals($bindings[$key], $Control[$key], [StringComparison]::Ordinal)) { throw 'ControlBindingMismatch' }
      }
      $failure = 'ControlUnavailable'
      $token = $Control['StopSource'].get_Token()
      $status = 'ProposedOnly'
      $exitReason = 'ShouldProcessDeclined'
      $observed = $false
      if ($PSCmdlet.ShouldProcess($InvocationId, 'Observe partial clerk control')) {
        $failure = 'ControlAlreadyUsed'
        if (-not $Control['StartGate'].TrySetResult($true)) { throw 'ControlAlreadyUsed' }
        $observed = $token.IsCancellationRequested
        $status = 'Held'
        $exitReason = 'ProducerBindingsIncomplete'
      }
      [PSCustomObject]@{
        ResourceId = $ResourceId; LineageId = $LineageId; Generation = $Generation
        OwnerSessionId = $OwnerSessionId; InvocationId = $InvocationId
        Status = $status; ExitReason = $exitReason; StopRequested = $token.IsCancellationRequested
        StopObserved = $observed; DrainStatus = 'Unknown'; RemainingObservation = 'Unknown'
        RecordedHead = $null; PendingRequestIds = $null; PreparedOperationIds = $null
        NeedsRecoveryOperationIds = $null
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Clerk control refused: $failure."
      throw [InvalidOperationException]::new("Invoke-CoordClerk: $failure.")
    }
  }
  end {}
}

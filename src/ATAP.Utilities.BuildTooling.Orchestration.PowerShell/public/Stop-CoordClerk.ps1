function Stop-CoordClerk {
  <#
  .SYNOPSIS
    Requests cooperative stop for one borrowed same-process clerk control.
  .DESCRIPTION
    The trusted caller supplies original admitted references and separately proves
    current coordinator authority, resource/lineage/epoch, owner and containment.
    Shape and matching strings do not authenticate copies or grant remote authority.
    No registry or active producer lookup exists.

    Control has exactly StatePath, ResourceId, LineageId, Generation, OwnerSessionId,
    InvocationId, ProcessId, StopSource and StartGate. The first six are nonempty
    strings, ProcessId is the current Int32 process ID, StopSource is a live BCL
    CancellationTokenSource and StartGate is a BCL TaskCompletionSource[bool] with
    RunContinuationsAsynchronously. Caller retains the same objects until Invoke
    and all Stop calls return, then retires/disposes the source. Stop never consumes
    the gate or disposes either object.

    This function only requests cancellation. It performs no state I/O, draining,
    publication, custody release or operation-terminal transition. Only Invoke can
    acknowledge observation at a safe boundary. A late request may address a live
    control whose producer already returned; it does not prove an active producer.

    Cancellation callbacks are outside the adopted caller contract. If one throws,
    the token may already be set: return a sanitized terminating error, never a
    fabricated acknowledgement or rollback. Caller callback side effects cannot
    be undone. Cancel runs callbacks synchronously; caller misuse can block Stop,
    and no deadline is imposed. A later request may report AlreadyRequested.
  .PARAMETER StatePath
    Exact caller-resolved absolute established state path; not opened or normalized.
  .PARAMETER ResourceId
    Admitted resource identity, compared ordinally.
  .PARAMETER LineageId
    Admitted retained lineage, compared ordinally.
  .PARAMETER Generation
    Current admitted authority epoch, compared ordinally.
  .PARAMETER OwnerSessionId
    Current authorized coordinator session, compared ordinally.
  .PARAMETER InvocationId
    Opaque identity of the one invocation, compared ordinally.
  .PARAMETER Control
    Original borrowed nine-key ReadOnlyDictionary[string,object] control.
  .OUTPUTS
    PSCustomObject: identities, Status, StopRequested, StopObserved=false and
    DrainStatus=NotObserved. ProposedOnly changes neither source nor gate.
  .EXAMPLE
    Stop-CoordClerk @admittedBindings -Control $control -WhatIf
  .NOTES
    Request-only same-process seam; no producer observation or completed-drain claim.
    Status describes this call's observation, not exclusive ownership of a signal;
    concurrent Stop calls may both return StopRequested after Cancel returns.
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
    $fn = 'Stop-CoordClerk'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $null = Get-Command Write-PSFMessage -ErrorAction Stop
  }
  process {
    $failure = 'InvalidControl'
    try {
      if ($Control.GetType() -ne [Collections.ObjectModel.ReadOnlyDictionary[string, object]]) {
        throw 'InvalidControl'
      }
      $bindings = [ordered]@{
        StatePath = $StatePath; ResourceId = $ResourceId; LineageId = $LineageId
        Generation = $Generation; OwnerSessionId = $OwnerSessionId; InvocationId = $InvocationId
      }
      $expected = @($bindings.Keys) + @('ProcessId', 'StopSource', 'StartGate')
      $keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($key in $Control.Keys) { $null = $keys.Add($key) }
      if ($Control.Count -ne $expected.Count) { throw 'InvalidControl' }
      foreach ($key in $expected) {
        if (-not $keys.Contains($key)) { throw 'InvalidControl' }
      }
      foreach ($key in $bindings.Keys) {
        if ($Control[$key] -isnot [string] -or [string]::IsNullOrWhiteSpace($Control[$key]) -or
            [string]::IsNullOrWhiteSpace($bindings[$key])) { throw 'InvalidControl' }
      }
      if (-not [IO.Path]::IsPathFullyQualified($StatePath)) { throw 'InvalidControl' }
      if ($Control['ProcessId'] -isnot [int] -or $Control['ProcessId'] -ne [Environment]::ProcessId -or
          $null -eq $Control['StopSource'] -or
          $Control['StopSource'].GetType() -ne [Threading.CancellationTokenSource] -or
          $null -eq $Control['StartGate'] -or
          $Control['StartGate'].GetType() -ne [Threading.Tasks.TaskCompletionSource[bool]]) {
        throw 'InvalidControl'
      }
      $asyncFlag = [Threading.Tasks.TaskCreationOptions]::RunContinuationsAsynchronously
      if (($Control['StartGate'].Task.CreationOptions -band $asyncFlag) -ne $asyncFlag) {
        throw 'InvalidControl'
      }
      $failure = 'ControlBindingMismatch'
      foreach ($key in $bindings.Keys) {
        if (-not [string]::Equals($bindings[$key], $Control[$key], [StringComparison]::Ordinal)) {
          throw 'ControlBindingMismatch'
        }
      }
      $failure = 'ControlUnavailable'
      $source = $Control['StopSource']
      $token = $source.get_Token() # Explicit getter surfaces disposal before ShouldProcess.
      $status = 'ProposedOnly'
      if ($PSCmdlet.ShouldProcess($InvocationId, 'Request same-process cooperative clerk stop')) {
        $failure = 'StopSignalFailed'
        if ($token.IsCancellationRequested) {
          $status = 'AlreadyRequested'
        } else {
          $source.Cancel()
          $status = 'StopRequested'
        }
      }
      [PSCustomObject]@{
        InvocationId = $InvocationId; ResourceId = $ResourceId; LineageId = $LineageId
        Generation = $Generation; OwnerSessionId = $OwnerSessionId; Status = $status
        StopRequested = $token.IsCancellationRequested
        StopObserved = $false; DrainStatus = 'NotObserved'
      }
    } catch {
      # Do not expose callback exceptions or pretend cancellation was rolled back.
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stop request refused or signal failed: $failure."
      throw [InvalidOperationException]::new("Stop-CoordClerk: $failure.")
    }
  }
  end {}
}

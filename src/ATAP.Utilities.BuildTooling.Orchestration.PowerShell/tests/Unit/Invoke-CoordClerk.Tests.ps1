BeforeAll {
  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
  foreach ($name in @('CoordProducerJson', 'CoordProducer', 'CoordClerkProducer', 'Invoke-CoordProducerBatch')) {
    . (Join-Path $PSScriptRoot "../../private/$name.ps1")
  }
  . (Join-Path $PSScriptRoot '../../public/Invoke-CoordClerk.ps1')
  function New-ClerkFixture {
    $source = [Threading.CancellationTokenSource]::new()
    $gate = [Threading.Tasks.TaskCompletionSource[bool]]::new([Threading.Tasks.TaskCreationOptions]::RunContinuationsAsynchronously)
    $values = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    $fields = @{ StatePath = 'C:\Fixture\state.json'; ResourceId = 'resource-1'; LineageId = 'lineage-1'
      Generation = 'generation-1'; OwnerSessionId = 'session-1'; InvocationId = 'invocation-1'
      ProcessId = [Environment]::ProcessId; StopSource = $source; StartGate = $gate }
    foreach ($key in $fields.Keys) { $values.Add($key, $fields[$key]) }
    $state = ConvertTo-CoordElement @{ committedRevision = 'head-1'; requests = @(); preparedOperations = @() }
    [pscustomobject]@{ Source = $source; Gate = $gate; Values = $values
      Control = [Collections.ObjectModel.ReadOnlyDictionary[string, object]]::new($values)
      Context = [pscustomobject]@{ StatePath = 'C:\Fixture\state.json'; State = $state
        Record = @{ resourceId = 'resource-1'; lineageId = 'lineage-1'; generation = 'generation-1'; pendingWrite = $null }
        Limits = @{ MaxDrainRequests = 8; MaxDrainBatches = 4; MaxDrainMilliseconds = 10000 }
        Lease = [IO.MemoryStream]::new(); BoardLease = [IO.MemoryStream]::new() } }
  }
}
Describe 'Invoke-CoordClerk bounded control' -Tag 'Unit' {
  BeforeEach {
    $WhatIfPreference = $false
    $script:fixture = New-ClerkFixture
    Mock Write-PSFMessage {}
    # Unit boundary only: production custody is exercised by CoordProducer integration fixtures.
    Mock Read-CoordProducerContext { $script:fixture.Context }
    Mock Resume-CoordProducerWrite {}
    Mock Invoke-CoordDurableOperation {}
    Mock Invoke-CoordProducerBatch { [pscustomobject]@{ Considered = 0; Applied = 0; Rejected = 0; Progress = $false } }
  }
  AfterEach { $fixture.Source.Dispose() }
  It 'actually invokes the bounded producer and reports the observed empty queue' {
    $result = Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Control $fixture.Control -Confirm:$false
    $result.DrainStatus | Should -BeExactly 'Drained'
    $result.Status | Should -BeExactly 'Observed'
    Should -Invoke Invoke-CoordProducerBatch -Times 1 -Exactly
    $fixture.Gate.Task.IsCompletedSuccessfully | Should -BeTrue
    { $null = $fixture.Source.Token } | Should -Not -Throw
  }
  It 'does no custody IO and preserves borrowed control under WhatIf' {
    $result = Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Control $fixture.Control -WhatIf
    $result.Status | Should -BeExactly 'ProposedOnly'
    Should -Invoke Read-CoordProducerContext -Times 0 -Exactly
    $fixture.Gate.Task.IsCompleted | Should -BeFalse
  }
  It 'observes cancellation without starting recovery or new batches' {
    $fixture.Source.Cancel()
    $result = Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Control $fixture.Control -Confirm:$false
    $result.StopObserved | Should -BeTrue
    $result.ExitReason | Should -BeExactly 'StoppedAtBoundary'
    Should -Invoke Invoke-CoordProducerBatch -Times 0 -Exactly
    Should -Invoke Resume-CoordProducerWrite -Times 0 -Exactly
  }
  It 'rejects a mismatched live binding before consuming the gate' {
    $fixture.Values['Generation'] = 'other-generation'
    { Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Control $fixture.Control -Confirm:$false } | Should -Throw '*ControlBindingMismatch*'
    $fixture.Gate.Task.IsCompleted | Should -BeFalse
  }
  It 'does not dispose borrowed cancellation when producer work fails' {
    Mock Invoke-CoordProducerBatch { throw 'Synthetic producer failure' }
    { Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Control $fixture.Control -Confirm:$false } | Should -Throw
    { $null = $fixture.Source.Token } | Should -Not -Throw
    $fixture.Context.Lease.CanRead | Should -BeFalse
  }
  It 'preserves an Int64 drain request budget beyond Int32 without narrowing' {
    $fixture.Context.Limits.MaxDrainRequests = [long]2147483648
    $result = Invoke-CoordClerk -HolderId Coordinator -SessionId session-1 -Control $fixture.Control -Confirm:$false
    $result.Considered | Should -Be 0
    $result.Applied | Should -Be 0
    $result.Rejected | Should -Be 0
    Should -Invoke Invoke-CoordProducerBatch -Times 1 -Exactly -ParameterFilter {
      $MaximumRequests -is [long] -and $MaximumRequests -eq [long]2147483648
    }
  }
}

#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

BeforeAll {
  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
  . (Join-Path $PSScriptRoot '../../public/Invoke-CoordClerk.ps1')
  function New-Control800 {
    $source = [Threading.CancellationTokenSource]::new()
    $gate = [Threading.Tasks.TaskCompletionSource[bool]]::new([Threading.Tasks.TaskCreationOptions]::RunContinuationsAsynchronously)
    $bindings = @{
      StatePath = [IO.Path]::Combine([IO.Path]::GetPathRoot($PSScriptRoot), 'NeverCreated800', 'state.json')
      ResourceId = 'Resource-A'; LineageId = 'Lineage-L'; Generation = 'Generation-G'
      OwnerSessionId = 'Owner-S'; InvocationId = 'Invocation-I'
    }
    $values = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($key in $bindings.Keys) { $values.Add($key, $bindings[$key]) }
    $values.Add('ProcessId', [Environment]::ProcessId)
    $values.Add('StopSource', $source)
    $values.Add('StartGate', $gate)
    [PSCustomObject]@{ Bindings = $bindings; Values = $values; Source = $source; Gate = $gate
      Control = [Collections.ObjectModel.ReadOnlyDictionary[string, object]]::new($values) }
  }
}

Describe 'Invoke-CoordClerk partial control boundary' -Tag 'Unit' {
  BeforeEach {
    $WhatIfPreference = $false
    $script:f800 = New-Control800
    Mock Write-PSFMessage {}
    Mock Get-Content { throw 'Unexpected IO' }
    Mock Set-Content { throw 'Unexpected IO' }
    Mock Test-Path { throw 'Unexpected IO' }
  }
  AfterEach {
    try {
      foreach ($name in @('Get-Content', 'Set-Content', 'Test-Path')) {
        Should -Invoke -CommandName $name -Times 0 -Exactly -Scope It
      }
    } finally { $script:f800.Source.Dispose() }
  }

  It 'holds without inventing work or mutating the token when pre-cancelled is <Cancelled>' -ForEach @(
    @{ Cancelled = $false }; @{ Cancelled = $true }
  ) {
    $f = $script:f800
    if ($Cancelled) { $f.Source.Cancel() }
    $bindings800 = $f.Bindings
    $result = Invoke-CoordClerk @bindings800 -Control $f.Control -Confirm:$false
    $result.Status | Should -BeExactly 'Held'
    $result.ExitReason | Should -BeExactly 'ProducerBindingsIncomplete'
    $result.StopRequested | Should -Be $Cancelled
    $result.StopObserved | Should -Be $Cancelled
    $result.DrainStatus | Should -BeExactly 'Unknown'
    $result.RemainingObservation | Should -BeExactly 'Unknown'
    foreach ($key in @('RecordedHead', 'PendingRequestIds', 'PreparedOperationIds', 'NeedsRecoveryOperationIds')) {
      $result.$key | Should -BeNullOrEmpty
      $null -eq $result.$key | Should -BeTrue
    }
    $f.Gate.Task.IsCompletedSuccessfully | Should -BeTrue
    $f.Source.IsCancellationRequested | Should -Be $Cancelled
    { $null = $f.Source.get_Token() } | Should -Not -Throw
  }

  It 'WhatIf preserves gate and token with cancellation <Cancelled>' -ForEach @(
    @{ Cancelled = $false }; @{ Cancelled = $true }
  ) {
    $f = $script:f800
    if ($Cancelled) { $f.Source.Cancel() }
    $bindings800 = $f.Bindings
    $result = Invoke-CoordClerk @bindings800 -Control $f.Control -WhatIf
    $result.Status | Should -BeExactly 'ProposedOnly'
    $result.StopObserved | Should -BeFalse
    $result.StopRequested | Should -Be $Cancelled
    $f.Gate.Task.IsCompleted | Should -BeFalse
    $f.Source.IsCancellationRequested | Should -Be $Cancelled
  }

  It 'refuses a reused gate and preserves the source' {
    $f = $script:f800; $bindings800 = $f.Bindings
    $null = Invoke-CoordClerk @bindings800 -Control $f.Control -Confirm:$false
    { Invoke-CoordClerk @bindings800 -Control $f.Control -Confirm:$false } | Should -Throw '*ControlAlreadyUsed*'
    $f.Source.IsCancellationRequested | Should -BeFalse
  }

  It 'refuses case-sensitive mismatch in <Key> before gate consumption' -ForEach @(
    @{ Key = 'StatePath' }; @{ Key = 'ResourceId' }; @{ Key = 'LineageId' }
    @{ Key = 'Generation' }; @{ Key = 'OwnerSessionId' }; @{ Key = 'InvocationId' }
  ) {
    $f = $script:f800; $args800 = $f.Bindings.Clone()
    $args800[$Key] = $args800[$Key].ToLowerInvariant()
    { Invoke-CoordClerk @args800 -Control $f.Control -Confirm:$false } | Should -Throw '*ControlBindingMismatch*'
    $f.Gate.Task.IsCompleted | Should -BeFalse
    $f.Source.IsCancellationRequested | Should -BeFalse
  }

  It 'refuses missing key, wrong process, or nonasync gate <Fault>' -ForEach @(
    @{ Fault = 'Missing' }; @{ Fault = 'Process' }; @{ Fault = 'Gate' }
  ) {
    $f = $script:f800; $bindings800 = $f.Bindings
    switch ($Fault) {
      'Missing' { $null = $f.Values.Remove('InvocationId') }
      'Process' { $f.Values['ProcessId'] = -1 }
      'Gate' { $f.Values['StartGate'] = [Threading.Tasks.TaskCompletionSource[bool]]::new() }
    }
    { Invoke-CoordClerk @bindings800 -Control $f.Control -Confirm:$false } | Should -Throw '*InvalidControl*'
    $f.Gate.Task.IsCompleted | Should -BeFalse
    $f.Source.IsCancellationRequested | Should -BeFalse
  }

  It 'refuses a disposed cancellation source before gate consumption even for WhatIf' {
    $f = $script:f800; $bindings800 = $f.Bindings; $f.Source.Dispose()
    { Invoke-CoordClerk @bindings800 -Control $f.Control -WhatIf } | Should -Throw '*ControlUnavailable*'
    $f.Gate.Task.IsCompleted | Should -BeFalse
  }

  It 'refuses a deserialized object without consuming the live fixture' {
    $f = $script:f800; $bindings800 = $f.Bindings
    $copy = [PSCustomObject]@{ StatePath = $f.Bindings.StatePath; ProcessId = [Environment]::ProcessId }
    { Invoke-CoordClerk @bindings800 -Control $copy -Confirm:$false } | Should -Throw
    $f.Gate.Task.IsCompleted | Should -BeFalse
    $f.Source.IsCancellationRequested | Should -BeFalse
  }
}

#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

BeforeAll {
  # Isolate logging even if a profile has already loaded PSFramework.
  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
  $script:stop512SourcePath = Join-Path $PSScriptRoot '../../public/Stop-CoordClerk.ps1'
  . $script:stop512SourcePath

  function New-Stop512Fixture {
    $source = [Threading.CancellationTokenSource]::new()
    $gate = [Threading.Tasks.TaskCompletionSource[bool]]::new(
      [Threading.Tasks.TaskCreationOptions]::RunContinuationsAsynchronously)
    # No file or directory is created; Stop must not resolve/open this spelling.
    $path = [IO.Path]::Combine([IO.Path]::GetPathRoot($PSScriptRoot), 'Stop512-NotCreated', 'State.json')
    $bindings = @{
      StatePath = $path; ResourceId = 'Resource-A'; LineageId = 'Lineage-L'
      Generation = 'Epoch-G'; OwnerSessionId = 'Owner-S'; InvocationId = 'Invocation-I'
    }
    $values = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($key in $bindings.Keys) { $values.Add($key, $bindings[$key]) }
    $values.Add('ProcessId', [Environment]::ProcessId)
    $values.Add('StopSource', $source)
    $values.Add('StartGate', $gate)
    [PSCustomObject]@{
      Bindings = $bindings; Source = $source; Gate = $gate
      Control = [Collections.ObjectModel.ReadOnlyDictionary[string, object]]::new($values)
    }
  }
  function Assert-Stop512Receipt {
    param($Receipt, [string]$Status, [bool]$Requested)
    @($Receipt).Count | Should -Be 1
    $Receipt.Status | Should -BeExactly $Status
    $Receipt.StopRequested | Should -Be $Requested
    $Receipt.StopObserved | Should -BeFalse
    $Receipt.DrainStatus | Should -BeExactly 'NotObserved'
    foreach ($key in @('ResourceId', 'LineageId', 'Generation', 'OwnerSessionId', 'InvocationId')) {
      $Receipt.$key | Should -BeExactly $script:stop512Fixture.Bindings[$key]
    }
    @($Receipt.PSObject.Properties.Name).Count | Should -Be 9
  }
}

Describe 'Stop-CoordClerk borrowed same-process request only' -Tag 'Unit' {
  BeforeEach {
    $WhatIfPreference = $false
    $script:stop512Fixture = New-Stop512Fixture
    $script:stop512Requested = $false
    $script:stop512GateUsed = $false
    $script:stop512DisposedByTest = $false
    $script:stop512Registration = $null
    Mock Write-PSFMessage {}
    # Guard possible command I/O; AST coverage below also forbids direct BCL file/process calls.
    Mock Get-Content { throw 'UnexpectedStopIo' }
    Mock Set-Content { throw 'UnexpectedStopIo' }
    Mock Test-Path { throw 'UnexpectedStopIo' }
    Mock Get-Process { throw 'UnexpectedStopIo' }
    Mock Stop-Process { throw 'UnexpectedStopIo' }
  }
  AfterEach {
    try {
      # These independent checks cannot be swallowed by an expected Should -Throw.
      $script:stop512Fixture.Source.IsCancellationRequested | Should -Be $script:stop512Requested
      $script:stop512Fixture.Gate.Task.IsCompleted | Should -Be $script:stop512GateUsed
      if (-not $script:stop512DisposedByTest) {
        { $null = $script:stop512Fixture.Source.get_Token() } | Should -Not -Throw
      }
      foreach ($command in @('Get-Content', 'Set-Content', 'Test-Path', 'Get-Process', 'Stop-Process')) {
        Should -Invoke -CommandName $command -Times 0 -Exactly -Scope It
      }
    } finally {
      if ($null -ne $script:stop512Registration) { $script:stop512Registration.Dispose() }
      $script:stop512Fixture.Source.Dispose()
    }
  }

  It 'requests before producer start and retains the borrowed source and unused gate' {
    $f = $script:stop512Fixture
    $bindings512 = $f.Bindings
    $script:stop512Requested = $true
    $result = Stop-CoordClerk @bindings512 -Control $f.Control -Confirm:$false
    Assert-Stop512Receipt $result 'StopRequested' $true
    [object]::ReferenceEquals($f.Source, $f.Control['StopSource']) | Should -BeTrue
    [object]::ReferenceEquals($f.Gate, $f.Control['StartGate']) | Should -BeTrue
    $f.Gate.Task.IsCompleted | Should -BeFalse
  }

  It 'repeats as AlreadyRequested without claiming observation or drain' {
    $f = $script:stop512Fixture
    $bindings512 = $f.Bindings
    $script:stop512Requested = $true
    $first = Stop-CoordClerk @bindings512 -Control $f.Control -Confirm:$false
    $second = Stop-CoordClerk @bindings512 -Control $f.Control -Confirm:$false
    Assert-Stop512Receipt $first 'StopRequested' $true
    Assert-Stop512Receipt $second 'AlreadyRequested' $true
  }

  It 'can request an already-started control without changing the gate' {
    $f = $script:stop512Fixture
    $bindings512 = $f.Bindings
    $f.Gate.SetResult($true)
    $script:stop512GateUsed = $true
    $script:stop512Requested = $true
    Assert-Stop512Receipt (Stop-CoordClerk @bindings512 -Control $f.Control -Confirm:$false) 'StopRequested' $true
    $f.Gate.Task.Result | Should -BeTrue
  }

  It 'returns ProposedOnly when ShouldProcess declines in WhatIf mode: requested=<Requested>' -ForEach @(
    @{ Requested = $false }
    @{ Requested = $true }
  ) {
    $f = $script:stop512Fixture
    $bindings512 = $f.Bindings
    if ($Requested) { $f.Source.Cancel(); $script:stop512Requested = $true }
    $result = Stop-CoordClerk @bindings512 -Control $f.Control -WhatIf
    Assert-Stop512Receipt $result 'ProposedOnly' $Requested
  }

  It 'honors an ambient WhatIf decline without signalling' {
    $f = $script:stop512Fixture
    $bindings512 = $f.Bindings
    $WhatIfPreference = $true
    Assert-Stop512Receipt (Stop-CoordClerk @bindings512 -Control $f.Control) 'ProposedOnly' $false
  }

  It 'refuses mismatched binding <Key> variant <Variant> before signalling' -ForEach @(
    @{ Key = 'StatePath'; Variant = 'different' }
    @{ Key = 'StatePath'; Variant = 'case' }
    @{ Key = 'ResourceId'; Variant = 'different' }
    @{ Key = 'ResourceId'; Variant = 'case' }
    @{ Key = 'LineageId'; Variant = 'different' }
    @{ Key = 'LineageId'; Variant = 'case' }
    @{ Key = 'Generation'; Variant = 'different' }
    @{ Key = 'Generation'; Variant = 'case' }
    @{ Key = 'OwnerSessionId'; Variant = 'different' }
    @{ Key = 'OwnerSessionId'; Variant = 'case' }
    @{ Key = 'InvocationId'; Variant = 'different' }
    @{ Key = 'InvocationId'; Variant = 'case' }
  ) {
    $f = $script:stop512Fixture
    $bindings512 = $f.Bindings
    $args512 = $f.Bindings.Clone()
    $args512[$Key] = if ($Variant -eq 'case') { $args512[$Key].ToLowerInvariant() } else { $args512[$Key] + '.other' }
    { Stop-CoordClerk @args512 -Control $f.Control -Confirm:$false } | Should -Throw '*ControlBindingMismatch*'
  }

  It 'refuses missing exact control key <Key>' -ForEach @(
    @{ Key = 'StatePath' }; @{ Key = 'ResourceId' }; @{ Key = 'LineageId' }
    @{ Key = 'Generation' }; @{ Key = 'OwnerSessionId' }; @{ Key = 'InvocationId' }
    @{ Key = 'ProcessId' }; @{ Key = 'StopSource' }; @{ Key = 'StartGate' }
  ) {
    $f = $script:stop512Fixture
    $bindings512 = $f.Bindings
    $values = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($name in $f.Control.Keys) {
      if ($name -cne $Key) { $values.Add($name, $f.Control[$name]) }
    }
    $bad = [Collections.ObjectModel.ReadOnlyDictionary[string, object]]::new($values)
    { Stop-CoordClerk @bindings512 -Control $bad -Confirm:$false } | Should -Throw '*InvalidControl*'
  }

  It 'refuses malformed live shape <Fault>' -ForEach @(
    @{ Fault = 'extra key' }
    @{ Fault = 'case key' }
    @{ Fault = 'blank binding' }
    @{ Fault = 'numeric binding' }
    @{ Fault = 'wrong process' }
    @{ Fault = 'process Int64' }
    @{ Fault = 'null source' }
    @{ Fault = 'wrong source' }
    @{ Fault = 'null gate' }
    @{ Fault = 'wrong gate generic' }
    @{ Fault = 'gate lacks asynchronous continuations' }
  ) {
    $f = $script:stop512Fixture
    $bindings512 = $f.Bindings
    $values = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($name in $f.Control.Keys) { $values.Add($name, $f.Control[$name]) }
    switch ($Fault) {
      'extra key' { $values.Add('Extra', 'no') }
      'case key' { $value = $values['ResourceId']; $null = $values.Remove('ResourceId'); $values.Add('resourceId', $value) }
      'blank binding' { $values['OwnerSessionId'] = ' ' }
      'numeric binding' { $values['ResourceId'] = 17 }
      'wrong process' { $values['ProcessId'] = [Environment]::ProcessId -bxor 1 }
      'process Int64' { $values['ProcessId'] = [long][Environment]::ProcessId }
      'null source' { $values['StopSource'] = $null }
      'wrong source' { $values['StopSource'] = [Threading.CancellationToken]::None }
      'null gate' { $values['StartGate'] = $null }
      'wrong gate generic' { $values['StartGate'] = [Threading.Tasks.TaskCompletionSource[string]]::new() }
      'gate lacks asynchronous continuations' { $values['StartGate'] = [Threading.Tasks.TaskCompletionSource[bool]]::new() }
    }
    $bad = [Collections.ObjectModel.ReadOnlyDictionary[string, object]]::new($values)
    { Stop-CoordClerk @bindings512 -Control $bad -Confirm:$false } | Should -Throw '*InvalidControl*'
  }

  It 'rejects non-control input <Fault> without token effects' -ForEach @(
    @{ Fault = 'null' }
    @{ Fault = 'plain object' }
    @{ Fault = 'deserialized' }
  ) {
    $f = $script:stop512Fixture
    $bindings512 = $f.Bindings
    $bad = switch ($Fault) {
      'null' { $null }
      'plain object' { [PSCustomObject]@{ StopSource = $f.Source; StartGate = $f.Gate } }
      'deserialized' {
        # Inert wire shape only: never serialize a pending Task (its Result can block).
        $wire = [ordered]@{}
        foreach ($name in $f.Bindings.Keys) { $wire[$name] = $f.Bindings[$name] }
        $wire.ProcessId = [Environment]::ProcessId
        $wire.StopSource = 'serialized source'; $wire.StartGate = 'serialized gate'
        [Management.Automation.PSSerializer]::Deserialize(
          [Management.Automation.PSSerializer]::Serialize([PSCustomObject]$wire))
      }
    }
    { Stop-CoordClerk @bindings512 -Control $bad -Confirm:$false } | Should -Throw
  }

  It 'rejects a relative path even when the control repeats it' {
    $f = $script:stop512Fixture
    $bindings512 = $f.Bindings
    $values = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($name in $f.Control.Keys) { $values.Add($name, $f.Control[$name]) }
    $values['StatePath'] = 'relative/state.json'
    $bad = [Collections.ObjectModel.ReadOnlyDictionary[string, object]]::new($values)
    $args512 = $f.Bindings.Clone(); $args512.StatePath = 'relative/state.json'
    { Stop-CoordClerk @args512 -Control $bad -Confirm:$false } | Should -Throw '*InvalidControl*'
  }

  It 'refuses disposed source before ShouldProcess: WhatIf=<WhatIfMode>' -ForEach @(
    @{ WhatIfMode = $false }
    @{ WhatIfMode = $true }
  ) {
    $f = $script:stop512Fixture
    $bindings512 = $f.Bindings
    $f.Source.Dispose()
    $script:stop512DisposedByTest = $true
    $output516 = [Collections.Generic.List[object]]::new()
    $caught516 = $null
    try {
      Stop-CoordClerk @bindings512 -Control $f.Control -WhatIf:$WhatIfMode -Confirm:$false |
        ForEach-Object { $output516.Add($_) }
    } catch { $caught516 = $_ }
    $caught516 | Should -Not -BeNullOrEmpty
    $caught516.Exception.Message | Should -BeExactly 'Stop-CoordClerk: ControlUnavailable.'
    $output516.Count | Should -Be 0
  }

  It 'validates bindings before a WhatIf decline' {
    $f = $script:stop512Fixture
    $bindings512 = $f.Bindings
    $args512 = $f.Bindings.Clone(); $args512.OwnerSessionId = 'other'
    { Stop-CoordClerk @args512 -Control $f.Control -WhatIf } | Should -Throw '*ControlBindingMismatch*'
  }

  It 'reports callback failure honestly without exposing callback internals or undoing the token' {
    $f = $script:stop512Fixture
    $bindings512 = $f.Bindings
    $callbackCount = [Runtime.CompilerServices.StrongBox[int]]::new(0)
    $callback = { $callbackCount.Value++; throw 'SENSITIVE-CALLBACK512' }.GetNewClosure()
    $script:stop512Registration = $f.Source.Token.Register([Action]$callback)
    $script:stop512Requested = $true
    $actual = @(); $caught = $null
    try { $actual = @(Stop-CoordClerk @bindings512 -Control $f.Control -Confirm:$false) }
    catch { $caught = $_ }
    $caught | Should -Not -BeNullOrEmpty
    $caught.Exception.Message | Should -BeExactly 'Stop-CoordClerk: StopSignalFailed.'
    $caught.Exception.InnerException | Should -BeNullOrEmpty
    $actual.Count | Should -Be 0
    $callbackCount.Value | Should -Be 1
    Should -Invoke Write-PSFMessage -Times 0 -Exactly -ParameterFilter { $Message -match 'SENSITIVE-CALLBACK512' }
    Assert-Stop512Receipt (Stop-CoordClerk @bindings512 -Control $f.Control -Confirm:$false) 'AlreadyRequested' $true
    $callbackCount.Value | Should -Be 1
  }

  It 'does not pretend matching live copies authenticate original control identity' {
    $f = $script:stop512Fixture
    $bindings512 = $f.Bindings
    # A wrapper copy retaining the same borrowed references is indistinguishable here.
    # Trusted caller supplies originals; no impossible unforgeability assertion.
    $values = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($name in $f.Control.Keys) { $values.Add($name, $f.Control[$name]) }
    $copy = [Collections.ObjectModel.ReadOnlyDictionary[string, object]]::new($values)
    [object]::ReferenceEquals($copy, $f.Control) | Should -BeFalse
    $script:stop512Requested = $true
    Assert-Stop512Receipt (Stop-CoordClerk @bindings512 -Control $copy -Confirm:$false) 'StopRequested' $true
  }

  It 'defines one function and has no state process or publication I/O command/member path' {
    $tokens = $null; $errors512 = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($script:stop512SourcePath, [ref]$tokens, [ref]$errors512)
    @($errors512).Count | Should -Be 0
    @($ast.EndBlock.Statements).Count | Should -Be 1
    $ast.EndBlock.Statements[0].Name | Should -BeExactly 'Stop-CoordClerk'
    $commands = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true))
    foreach ($command in $commands) {
      $command.GetCommandName() | Should -BeIn @('Get-Command', 'Write-PSFMessage')
    }
    # Closed finite BCL/control operations; adding any member call requires review.
    $members = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.InvokeMemberExpressionAst] }, $true))
    foreach ($member in $members) {
      $member.Member.Value | Should -BeIn @('GetType', 'new', 'Add', 'Contains', 'IsNullOrWhiteSpace', 'IsPathFullyQualified', 'Equals', 'get_Token', 'ShouldProcess', 'Cancel')
    }
    @($members | Where-Object { $_.Expression.Extent.Text -match 'StartGate|\.Task\b' -and $_.Member.Value -match 'SetResult|TrySetResult|Wait' }).Count | Should -Be 0
  }
}

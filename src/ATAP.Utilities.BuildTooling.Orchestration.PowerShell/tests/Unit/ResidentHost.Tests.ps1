#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

BeforeAll {
  . (Join-Path $PSScriptRoot '../../Resources/Resident/Invoke-CoordClerkResident.ps1')
  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
  $residentTestsRoot = if ($env:ATAP_RESIDENT_TEST_ROOT) { $env:ATAP_RESIDENT_TEST_ROOT } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../_generated/Sprint0017/ResidentTests')) }
  $null = New-Item -ItemType Directory -Path $residentTestsRoot -Force
  function New-ResidentFixture {
    $root = Join-Path $residentTestsRoot ([guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $root
    $identity = Get-CoordResidentIdentity
    $base = 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.BuildTooling.Orchestration.PowerShell\0.1.16'
    $binding = @{
      schemaVersion = 'CoordResidentStartup-v1'; mode = 'Active'; hostName = $identity.HostName; windowsSid = $identity.WindowsSid
      holderId = 'FixtureCoordinator'; sessionId = 'fixture-session'; resourceId = 'fixture-resource'; lineageId = 'fixture-lineage'; generation = 'fixture-generation'
      statePath = Join-Path $root 'state.json'; custodyPath = Join-Path $root 'custody.json'; leasePath = Join-Path $root 'resident.lock'; stopPath = Join-Path $root 'stop'
      module = @{ version = '0.1.16'; manifestPath = Join-Path $base 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psd1'; rootModulePath = Join-Path $base 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psm1'; manifestSha256 = 'A' * 64; rootModuleSha256 = 'A' * 64; hostScriptSha256 = 'A' * 64; signerThumbprint = 'A' * 40 }
      activation = @{ reference = 'synthetic-admission'; exclusionReference = 'synthetic-exclusion'; notBeforeUtc = [DateTimeOffset]::UtcNow.AddMinutes(-1).ToString('r'); notAfterUtc = [DateTimeOffset]::UtcNow.AddMinutes(5).ToString('r') }
    }
    [IO.File]::WriteAllBytes($binding.leasePath, [byte[]]@())
    $path = Join-Path $root 'binding.json'
    [IO.File]::WriteAllText($path, ($binding | ConvertTo-Json -Depth 20))
    @{ Root = $root; Binding = $binding; Path = $path; Digest = (Get-FileHash -LiteralPath $path).Hash }
  }
}

Describe 'Resident host held startup and sequential boundary behavior' -Tag 'Unit' {
  BeforeEach {
    $fixture = New-ResidentFixture
    $global:ATAPResidentFixtureCalls = [Collections.Generic.List[string]]::new()
    Mock Write-PSFMessage {}
    # Unit fixtures are owned generated files in the Dropbox checkout. Isolate
    # only path metadata here; installed consumption separately uses ordinary D:.
    Mock Assert-CoordResidentPath { param($Path) [IO.Path]::GetFullPath($Path) }
    Mock Test-CoordResidentAdmission {}
    Mock Get-CoordResidentDrain {
      { [CmdletBinding(SupportsShouldProcess)] param($HolderId, $SessionId)
        $global:ATAPResidentFixtureCalls.Add($HolderId + '/' + $SessionId)
        [pscustomobject]@{ Status = 'Observed'; ResourceId = 'fixture-resource'; DrainStatus = 'Drained'; StopObserved = $false }
      }
    }
  }
  AfterEach { Remove-Variable ATAPResidentFixtureCalls -Scope Global -ErrorAction SilentlyContinue }

  It 'holds missing startup input without importing or consulting custody' {
    $result = Invoke-CoordClerkResident -BindingPath (Join-Path $fixture.Root 'absent.json') -ExpectedBindingSha256 ('A' * 64)
    $result.Status | Should -BeExactly 'Held'
    $result.Reason | Should -BeExactly 'BindingMissing'
    Should -Invoke Get-CoordResidentDrain -Times 0
    Should -Invoke Test-CoordResidentAdmission -Times 0
  }

  It 'held mode returns before admission, import or lifetime-lease access' {
    $fixture.Binding.mode = 'Held'
    [IO.File]::WriteAllText($fixture.Path, ($fixture.Binding | ConvertTo-Json -Depth 20))
    $lock = [IO.File]::Open($fixture.Binding.leasePath, 'Open', 'ReadWrite', 'None')
    try { $result = Invoke-CoordClerkResident -BindingPath $fixture.Path -ExpectedBindingSha256 (Get-FileHash -LiteralPath $fixture.Path).Hash } finally { $lock.Dispose() }
    $result.Reason | Should -BeExactly 'ConfiguredHeld'
    $result.Drains | Should -Be 0
    Should -Invoke Get-CoordResidentDrain -Times 0
    Should -Invoke Test-CoordResidentAdmission -Times 0
  }

  It 'changed descriptor bytes hold without trusting a replacement activation' {
    [IO.File]::AppendAllText($fixture.Path, ' ')
    $result = Invoke-CoordClerkResident -BindingPath $fixture.Path -ExpectedBindingSha256 $fixture.Digest
    $result.Status | Should -BeExactly 'Held'
    Should -Invoke Get-CoordResidentDrain -Times 0
  }

  It 'rejects a different Windows identity before admission or import' {
    Mock Get-CoordResidentIdentity { @{ HostName = [Environment]::MachineName; WindowsSid = 'S-1-5-21-1-2-3-9999' } }
    $result = Invoke-CoordClerkResident -BindingPath $fixture.Path -ExpectedBindingSha256 $fixture.Digest
    $result.Status | Should -BeExactly 'Held'
    Should -Invoke Test-CoordResidentAdmission -Times 0
    Should -Invoke Get-CoordResidentDrain -Times 0
  }

  It 'honors WhatIf before admission or import' {
    $result = Invoke-CoordClerkResident -BindingPath $fixture.Path -ExpectedBindingSha256 $fixture.Digest -WhatIf
    $result.Status | Should -BeExactly 'ProposedOnly'
    Should -Invoke Test-CoordResidentAdmission -Times 0
    Should -Invoke Get-CoordResidentDrain -Times 0
  }

  It 'runs bounded drains sequentially under the same actor and releases its separate lease' {
    $result = Invoke-CoordClerkResident -BindingPath $fixture.Path -ExpectedBindingSha256 $fixture.Digest -MaximumDrains 2
    $result.Status | Should -BeExactly 'Stopped'
    $result.Drains | Should -Be 2
    @($global:ATAPResidentFixtureCalls).Count | Should -Be 2
    $global:ATAPResidentFixtureCalls[0] | Should -BeExactly 'FixtureCoordinator/fixture-session'
    $open = [IO.File]::Open($fixture.Binding.leasePath, 'Open', 'ReadWrite', 'None'); $open.Dispose()
  }

  It 'refuses a second host without invoking or importing a drain' {
    $lock = [IO.File]::Open($fixture.Binding.leasePath, 'Open', 'ReadWrite', 'None')
    try { $result = Invoke-CoordClerkResident -BindingPath $fixture.Path -ExpectedBindingSha256 $fixture.Digest -MaximumDrains 1 } finally { $lock.Dispose() }
    $result.Status | Should -BeExactly 'Held'
    Should -Invoke Get-CoordResidentDrain -Times 0
  }

  It 'observes a stop marker at the boundary without deleting it or draining' {
    [IO.File]::WriteAllText($fixture.Binding.stopPath, 'stop')
    $result = Invoke-CoordClerkResident -BindingPath $fixture.Path -ExpectedBindingSha256 $fixture.Digest -MaximumDrains 1
    $result.Status | Should -BeExactly 'Stopped'
    $result.Drains | Should -Be 0
    Test-Path -LiteralPath $fixture.Binding.stopPath | Should -BeTrue
    @($global:ATAPResidentFixtureCalls).Count | Should -Be 0
    Should -Invoke Get-CoordResidentDrain -Times 0
  }

  It 'retains a recovery outcome and holds without automatically repeating it' {
    Mock Get-CoordResidentDrain { { [CmdletBinding(SupportsShouldProcess)] param($HolderId, $SessionId)
      $global:ATAPResidentFixtureCalls.Add('recovery'); [pscustomobject]@{ Status = 'Observed'; ResourceId = 'fixture-resource'; DrainStatus = 'NeedsRecovery' }
    } }
    $result = Invoke-CoordClerkResident -BindingPath $fixture.Path -ExpectedBindingSha256 $fixture.Digest -MaximumDrains 2
    $result.Status | Should -BeExactly 'Held'
    $result.LastDrain.DrainStatus | Should -BeExactly 'NeedsRecovery'
    @($global:ATAPResidentFixtureCalls).Count | Should -Be 1
  }

  It 'cancels between drains without claiming in-flight StopObserved' {
    $source = [Threading.CancellationTokenSource]::new(); $source.Cancel()
    try { $result = Invoke-CoordClerkResident -BindingPath $fixture.Path -ExpectedBindingSha256 $fixture.Digest -CancellationToken $source.Token } finally { $source.Dispose() }
    $result.Status | Should -BeExactly 'Stopped'
    $result.Drains | Should -Be 0
    $result.StopBoundary | Should -BeExactly 'BetweenDrains'
    Should -Invoke Get-CoordResidentDrain -Times 0
  }
}

Describe 'Resident activation preflight' -Tag 'Unit' {
  BeforeEach {
    $f = New-ResidentFixture
    Mock Assert-CoordResidentPath { param($Path) [IO.Path]::GetFullPath($Path) }
    $priorKeys = Get-Variable configRootKeys -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    $priorSettings = Get-Variable settings -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    foreach ($dir in @('State', 'Custody', 'Control')) { $null = New-Item -ItemType Directory -Path (Join-Path $f.Root $dir) }
    $f.Binding.statePath = Join-Path $f.Root 'State/state.json'
    $f.Binding.custodyPath = Join-Path $f.Root 'Custody/custody.json'
    $f.Binding.leasePath = Join-Path $f.Root 'Control/resident.lock'
    $f.Binding.stopPath = Join-Path $f.Root 'Control/stop'
    $witness = @{ admissionMode = 'Established'; custodianSid = $f.Binding.windowsSid; resourceId = $f.Binding.resourceId; lineageId = $f.Binding.lineageId; generation = $f.Binding.generation; package = @{ moduleVersion = $f.Binding.module.version }; boardLockPath = Join-Path $f.Root 'board.lock'; actors = @(@{ holderId = $f.Binding.holderId; sessionId = $f.Binding.sessionId; windowsSid = $f.Binding.windowsSid; role = 'Coordinator' }) }
    $state = @{ resourceId = $f.Binding.resourceId; lineageId = $f.Binding.lineageId; generation = $f.Binding.generation; mutationAdmission = @{ status = 'Admitted' } }
    [IO.File]::WriteAllText($f.Binding.custodyPath, ($witness | ConvertTo-Json -Depth 10))
    [IO.File]::WriteAllText($f.Binding.statePath, ($state | ConvertTo-Json -Depth 10))
    $global:configRootKeys = @{ OrchestrationStateRootPathConfigRootKey = 'fixture-state'; OrchestrationCustodyRecordPathConfigRootKey = 'fixture-custody' }
    $global:settings = @{ 'fixture-state' = Split-Path $f.Binding.statePath -Parent; 'fixture-custody' = $f.Binding.custodyPath }
  }
  AfterEach { $global:configRootKeys = $priorKeys; $global:settings = $priorSettings }

  It 'accepts current synthetic actor, package, configuration and epoch without writing them' {
    $before = (Get-FileHash -LiteralPath $f.Binding.statePath).Hash
    { Test-CoordResidentAdmission -Binding $f.Binding } | Should -Not -Throw
    (Get-FileHash -LiteralPath $f.Binding.statePath).Hash | Should -BeExactly $before
  }

  It 'refuses a new epoch rather than inheriting the old session admission' {
    $f.Binding.generation = 'different-generation'
    { Test-CoordResidentAdmission -Binding $f.Binding } | Should -Throw '*ResidentEpochChanged*'
  }

  It 'refuses an expired activation before consulting protected configuration' {
    $f.Binding.activation.notBeforeUtc = [DateTimeOffset]::UtcNow.AddMinutes(-3).ToString('r')
    $f.Binding.activation.notAfterUtc = [DateTimeOffset]::UtcNow.AddMinutes(-2).ToString('r')
    { Test-CoordResidentAdmission -Binding $f.Binding } | Should -Throw '*ResidentActivationExpiredOrNotStarted*'
  }
}

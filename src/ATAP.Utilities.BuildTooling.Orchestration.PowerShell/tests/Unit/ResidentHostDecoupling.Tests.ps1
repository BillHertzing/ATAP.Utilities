#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

# Slice 6 (0.1.17): descriptor v2, Coordination-activation-v1 record, host reads custody.
# TestDrive fixtures only. Task Scheduler cmdlets are untyped stubs plus mocks; nothing is
# registered, enabled or started, and nothing is written under ProgramData.

BeforeAll {
  $script:hostSource = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../Resources/Resident/Invoke-CoordClerkResident.ps1'))
  . $script:hostSource
  . (Join-Path $PSScriptRoot '../../Resources/Resident/Register-CoordClerkLogonTask.ps1')
  function New-ScheduledTask { [CmdletBinding()] param($Action, $Trigger, $Principal, $Settings, $Description) }
  function Register-ScheduledTask { [CmdletBinding()] param($TaskPath, $TaskName, $InputObject) }
  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
  $script:moduleName = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'

  function Write-FixtureJson([string]$Path, $Value) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20)) }

  function Write-Activation {
    param($F, [int]$StartMinutes = -1, [int]$EndMinutes = 5, [int]$MaximumDrains = 0, [string]$Digest = $F.Digest)
    Write-FixtureJson $F.ActivationPath ([ordered]@{
      schemaVersion = 'Coordination-activation-v1'; descriptorSha256 = $Digest; approvalReference = 'synthetic-approval'
      notBeforeUtc = [DateTimeOffset]::UtcNow.AddMinutes($StartMinutes).ToString('r'); notAfterUtc = [DateTimeOffset]::UtcNow.AddMinutes($EndMinutes).ToString('r')
      maximumDrains = $MaximumDrains })
  }

  function Set-Custody {
    param($F, [string]$Version = '0.1.17', [string]$Generation = 'epoch-a')
    $b = $F.Binding
    Write-FixtureJson $b.custodyPath ([ordered]@{ admissionMode = 'Established'; custodianSid = $b.windowsSid; resourceId = $b.resourceId; lineageId = $b.lineageId; generation = $Generation
      package = [ordered]@{ moduleVersion = $Version; files = @() }; boardLockPath = Join-Path $F.Root 'board.lock'
      actors = @([ordered]@{ holderId = $b.holderId; sessionId = $b.sessionId; windowsSid = $b.windowsSid; role = 'Coordinator' }) })
    Write-FixtureJson $b.statePath ([ordered]@{ resourceId = $b.resourceId; lineageId = $b.lineageId; generation = $Generation; mutationAdmission = @{ status = 'Admitted' } })
  }

  function New-V2Fixture {
    param([string]$Mode = 'Active')
    $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    foreach ($dir in @('State', 'Custody', 'Control', 'Activation')) { $null = New-Item -ItemType Directory -Path (Join-Path $root $dir) -Force }
    $identity = Get-CoordResidentIdentity
    $binding = [ordered]@{
      schemaVersion = 'CoordResidentStartup-v2'; mode = $Mode; hostName = $identity.HostName; windowsSid = $identity.WindowsSid
      holderId = 'FixtureCoordinator'; sessionId = 'fixture-session'; resourceId = 'fixture-resource'; lineageId = 'fixture-lineage'
      statePath = Join-Path $root 'State\state.json'; custodyPath = Join-Path $root 'Custody\custody.json'
      leasePath = Join-Path $root 'Control\resident.lock'; stopPath = Join-Path $root 'Control\stop'
      activationPath = Join-Path $root 'Activation\activation.json'
    }
    [IO.File]::WriteAllBytes($binding.leasePath, [byte[]]@())
    $path = Join-Path $root 'binding.json'
    Write-FixtureJson $path $binding
    $f = @{ Root = $root; Binding = $binding; Path = $path; Digest = (Get-FileHash -LiteralPath $path).Hash; ActivationPath = $binding.activationPath }
    Set-Custody $f
    Write-Activation $f
    $global:configRootKeys = @{ OrchestrationStateRootPathConfigRootKey = 'fixture-state'; OrchestrationCustodyRecordPathConfigRootKey = 'fixture-custody' }
    $global:settings = @{ 'fixture-state' = Split-Path $binding.statePath -Parent; 'fixture-custody' = $binding.custodyPath }
    $f
  }

  function New-DrainMock {
    { [CmdletBinding(SupportsShouldProcess)] param($HolderId, $SessionId)
      $global:ATAPSlice6Calls.Add($HolderId + '/' + $SessionId)
      if ($global:ATAPSlice6AfterDrain) { & $global:ATAPSlice6AfterDrain }
      [pscustomobject]@{ Status = 'Observed'; ResourceId = 'fixture-resource'; DrainStatus = 'Drained'; StopObserved = $false }
    }
  }
}

Describe 'Resident descriptor v2 and version separation' -Tag 'Unit' {
  BeforeEach {
    $priorKeys = Get-Variable configRootKeys -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    $priorSettings = Get-Variable settings -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    $f = New-V2Fixture
  }
  AfterEach { $global:configRootKeys = $priorKeys; $global:settings = $priorSettings }

  It 'reads a v2 descriptor that carries identity and paths but no module, generation or activation pins' {
    $b = Read-CoordResidentBinding -Path $f.Path -Digest $f.Digest
    $b.schemaVersion | Should -BeExactly 'CoordResidentStartup-v2'
    foreach ($key in @('module', 'generation', 'activation')) { $b.Contains($key) | Should -BeFalse }
    $b.activationPath | Should -BeExactly $f.ActivationPath
  }

  It 'keeps v1 descriptors readable' {
    $identity = Get-CoordResidentIdentity
    $path = Join-Path $f.Root 'v1.json'
    Write-FixtureJson $path ([ordered]@{ schemaVersion = 'CoordResidentStartup-v1'; mode = 'Held'; hostName = $identity.HostName; windowsSid = $identity.WindowsSid })
    (Read-CoordResidentBinding -Path $path -Digest (Get-FileHash -LiteralPath $path).Hash).schemaVersion | Should -BeExactly 'CoordResidentStartup-v1'
  }

  It 'refuses ambiguous mixed versions: <Name>' -ForEach @(
    @{ Name = 'v2 with module pins'; Version = 'CoordResidentStartup-v2'; Key = 'module'; Value = @{ version = '0.1.17' } }
    @{ Name = 'v2 with generation'; Version = 'CoordResidentStartup-v2'; Key = 'generation'; Value = 'epoch-a' }
    @{ Name = 'v2 with embedded activation'; Version = 'CoordResidentStartup-v2'; Key = 'activation'; Value = @{ reference = 'x' } }
    @{ Name = 'v1 with activation record path'; Version = 'CoordResidentStartup-v1'; Key = 'activationPath'; Value = 'C:\x\activation.json' }
    @{ Name = 'unknown version'; Version = 'CoordResidentStartup-v3'; Key = 'hostName'; Value = 'x' }
  ) {
    $identity = Get-CoordResidentIdentity
    $doc = [ordered]@{ schemaVersion = $Version; mode = 'Held'; hostName = $identity.HostName; windowsSid = $identity.WindowsSid }
    $doc[$Key] = $Value
    $path = Join-Path $f.Root 'mixed.json'
    Write-FixtureJson $path $doc
    { Read-CoordResidentBinding -Path $path -Digest (Get-FileHash -LiteralPath $path).Hash } | Should -Throw '*ResidentDescriptorVersionAmbiguous*'
  }

  It 'reads package and generation from custody, so a release leaves the descriptor hash unchanged' {
    $a = Test-CoordResidentAdmission -Binding (Read-CoordResidentBinding -Path $f.Path -Digest $f.Digest) -Digest $f.Digest
    $a.Package.moduleVersion | Should -BeExactly '0.1.17'
    $a.Generation | Should -BeExactly 'epoch-a'
    Set-Custody $f -Version '0.1.18' -Generation 'epoch-b'
    (Get-FileHash -LiteralPath $f.Path).Hash | Should -BeExactly $f.Digest
    $b = Test-CoordResidentAdmission -Binding (Read-CoordResidentBinding -Path $f.Path -Digest $f.Digest) -Digest $f.Digest
    $b.Package.moduleVersion | Should -BeExactly '0.1.18'
    $b.Generation | Should -BeExactly 'epoch-b'
  }

  It 'refuses a witness/state generation split' {
    $state = Get-Content -LiteralPath $f.Binding.statePath -Raw | ConvertFrom-Json -AsHashtable
    $state.generation = 'epoch-other'
    Write-FixtureJson $f.Binding.statePath $state
    { Test-CoordResidentAdmission -Binding $f.Binding -Digest $f.Digest } | Should -Throw '*ResidentEpochChanged*'
  }

  It 'refuses a custody record without an admitted package' {
    $w = Get-Content -LiteralPath $f.Binding.custodyPath -Raw | ConvertFrom-Json -AsHashtable
    $w.Remove('package')
    Write-FixtureJson $f.Binding.custodyPath $w
    { Test-CoordResidentAdmission -Binding $f.Binding -Digest $f.Digest } | Should -Throw '*ResidentIncompatiblePackage*'
  }

  It 'returns custody''s standing policy signer, or none without a policy block (M3)' {
    (Test-CoordResidentAdmission -Binding $f.Binding -Digest $f.Digest).PolicySigner | Should -BeNullOrEmpty
    $w = Get-Content -LiteralPath $f.Binding.custodyPath -Raw | ConvertFrom-Json -AsHashtable
    $w['autoPackageAdmission'] = [ordered]@{ enabled = $true; signer = 'E' * 40; minVersion = '0.1.17'; schemaHashes = @{}; semanticRevision = 'r1' }
    Write-FixtureJson $f.Binding.custodyPath $w
    (Test-CoordResidentAdmission -Binding $f.Binding -Digest $f.Digest).PolicySigner | Should -BeExactly ('E' * 40)
  }

  It 'refuses a malformed custody policy signer: <Name>' -ForEach @(
    @{ Name = 'short'; Signer = 'E' * 39 }
    @{ Name = 'trailing newline'; Signer = ('E' * 40) + "`n" }
    @{ Name = 'not a string'; Signer = 42 }
  ) {
    $w = Get-Content -LiteralPath $f.Binding.custodyPath -Raw | ConvertFrom-Json -AsHashtable
    $w['autoPackageAdmission'] = [ordered]@{ enabled = $true; signer = $Signer }
    Write-FixtureJson $f.Binding.custodyPath $w
    { Test-CoordResidentAdmission -Binding $f.Binding -Digest $f.Digest } | Should -Throw '*ResidentSignerPolicyInvalid*'
  }
}

Describe 'Coordination-activation-v1 record' -Tag 'Unit' {
  BeforeEach {
    $priorKeys = Get-Variable configRootKeys -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    $priorSettings = Get-Variable settings -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    $f = New-V2Fixture
  }
  AfterEach { $global:configRootKeys = $priorKeys; $global:settings = $priorSettings }

  It 'accepts a current window bound to this descriptor hash' {
    $a = Read-CoordResidentActivation -Path $f.ActivationPath -DescriptorSha256 $f.Digest
    $a.approvalReference | Should -BeExactly 'synthetic-approval'
  }

  It 'refuses: <Name>' -ForEach @(
    @{ Name = 'expired window'; Start = -10; End = -5; Digest = $null; Expect = 'ResidentActivationExpiredOrNotStarted' }
    @{ Name = 'future window'; Start = 5; End = 10; Digest = $null; Expect = 'ResidentActivationExpiredOrNotStarted' }
    @{ Name = 'another descriptor'; Start = -1; End = 5; Digest = ('B' * 64); Expect = 'ResidentActivationDescriptorMismatch' }
  ) {
    $digest = if ($Digest) { $Digest } else { $f.Digest }
    Write-Activation $f -StartMinutes $Start -EndMinutes $End -Digest $digest
    { Read-CoordResidentActivation -Path $f.ActivationPath -DescriptorSha256 $f.Digest } | Should -Throw ('*' + $Expect + '*')
  }

  It 'refuses a missing record' {
    Remove-Item -LiteralPath $f.ActivationPath
    { Read-CoordResidentActivation -Path $f.ActivationPath -DescriptorSha256 $f.Digest } | Should -Throw '*ResidentActivationMissing*'
  }

  It 'refuses a schema-invalid record' {
    [IO.File]::WriteAllText($f.ActivationPath, '{"schemaVersion":"Coordination-activation-v1"}')
    { Read-CoordResidentActivation -Path $f.ActivationPath -DescriptorSha256 $f.Digest } | Should -Throw '*ResidentActivationInvalid*'
  }

  It 'caps the window at 12 hours (L5): exactly 12 hours is accepted' {
    (Get-CoordResidentActivationMaximum) | Should -Be ([TimeSpan]::FromHours(12))
    Write-Activation $f -StartMinutes -1 -EndMinutes 719
    (Read-CoordResidentActivation -Path $f.ActivationPath -DescriptorSha256 $f.Digest).approvalReference | Should -BeExactly 'synthetic-approval'
  }

  It 'caps the window at 12 hours (L5): one minute longer is refused even while current' {
    Write-Activation $f -StartMinutes -1 -EndMinutes 720
    { Read-CoordResidentActivation -Path $f.ActivationPath -DescriptorSha256 $f.Digest } | Should -Throw '*ResidentActivationWindowTooLong*'
  }

  It 'leaves the v1 embedded window uncapped' {
    $start = [DateTimeOffset]::UtcNow.AddMinutes(-1).ToString('r'); $end = [DateTimeOffset]::UtcNow.AddDays(3).ToString('r')
    { Assert-CoordResidentWindow -NotBeforeUtc $start -NotAfterUtc $end } | Should -Not -Throw
  }

  It 'refuses an activation record inside replaceable state' {
    $inside = Join-Path (Split-Path $f.Binding.statePath -Parent) 'activation.json'
    Copy-Item -LiteralPath $f.ActivationPath -Destination $inside
    $f.Binding.activationPath = $inside
    { Test-CoordResidentAdmission -Binding $f.Binding -Digest $f.Digest } | Should -Throw '*ResidentActivationPathConflict*'
  }
}

Describe 'Resident host loop with v2 descriptors' -Tag 'Unit' {
  BeforeEach {
    $priorKeys = Get-Variable configRootKeys -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    $priorSettings = Get-Variable settings -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    $f = New-V2Fixture
    $global:ATAPSlice6Calls = [Collections.Generic.List[string]]::new()
    $global:ATAPSlice6AfterDrain = $null
    Mock Write-PSFMessage {}
    Mock Get-CoordResidentDrain { New-DrainMock }
    Mock Assert-CoordResidentPackage {}
    Mock Assert-CoordResidentActivationProtection {}
  }
  AfterEach {
    $global:configRootKeys = $priorKeys; $global:settings = $priorSettings
    Remove-Variable ATAPSlice6Calls, ATAPSlice6AfterDrain, ATAPSlice6Fixture -Scope Global -ErrorAction SilentlyContinue
  }

  It 'drains under the custody-admitted package and re-verifies it every loop' {
    $r = Invoke-CoordClerkResident -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -MaximumDrains 2
    $r.Status | Should -BeExactly 'Stopped'
    $r.Reason | Should -BeExactly 'CallerDrainLimit'
    $r.Drains | Should -Be 2
    $r.PackageVersion | Should -BeExactly '0.1.17'
    $r.DescriptorVersion | Should -BeExactly 'CoordResidentStartup-v2'
    Should -Invoke Get-CoordResidentDrain -Times 1 -Exactly -ParameterFilter { $Admission.Package.moduleVersion -ceq '0.1.17' -and $Admission.Generation -ceq 'epoch-a' }
    Should -Invoke Assert-CoordResidentPackage -Times 2 -Exactly
    Should -Invoke Assert-CoordResidentActivationProtection -Times 2 -Exactly
  }

  It 'an expired activation gives Held without importing a drain' {
    Write-Activation $f -StartMinutes -10 -EndMinutes -5
    $r = Invoke-CoordClerkResident -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -MaximumDrains 1
    $r.Status | Should -BeExactly 'Held'
    $r.Reason | Should -BeExactly 'ResidentActivationExpiredOrNotStarted'
    Should -Invoke Get-CoordResidentDrain -Times 0
  }

  It 'a missing activation gives Held without importing a drain' {
    Remove-Item -LiteralPath $f.ActivationPath
    $r = Invoke-CoordClerkResident -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -MaximumDrains 1
    $r.Status | Should -BeExactly 'Held'
    $r.Reason | Should -BeExactly 'ResidentActivationMissing'
    Should -Invoke Get-CoordResidentDrain -Times 0
  }

  It 'an unadmitted package gives Held and drains nothing' {
    Mock Get-CoordResidentDrain { throw 'ResidentIncompatiblePackage' }
    $r = Invoke-CoordClerkResident -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -MaximumDrains 1
    $r.Status | Should -BeExactly 'Held'
    $r.Reason | Should -BeExactly 'ResidentIncompatiblePackage'
    $r.Drains | Should -Be 0
  }

  It 'an inventory that custody no longer admits holds at the next boundary' {
    Mock Assert-CoordResidentPackage { throw 'ResidentIncompatiblePackage' }
    $r = Invoke-CoordClerkResident -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -MaximumDrains 3
    $r.Status | Should -BeExactly 'Held'
    $r.Reason | Should -BeExactly 'ResidentIncompatiblePackage'
    $r.Drains | Should -Be 0
  }

  It 'a package re-admitted under the running process holds and exits after the current drain' {
    $global:ATAPSlice6Fixture = $f
    $global:ATAPSlice6AfterDrain = { Set-Custody $global:ATAPSlice6Fixture -Version '0.1.18' -Generation 'epoch-a' }
    $r = Invoke-CoordClerkResident -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -MaximumDrains 3
    $r.Status | Should -BeExactly 'Held'
    $r.Reason | Should -BeExactly 'ResidentIncompatiblePackage'
    $r.Drains | Should -Be 1
  }

  It 'an activation expiring between drains holds at the boundary' {
    $global:ATAPSlice6Fixture = $f
    $global:ATAPSlice6AfterDrain = { Write-Activation $global:ATAPSlice6Fixture -StartMinutes -10 -EndMinutes -5 }
    $r = Invoke-CoordClerkResident -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -MaximumDrains 3
    $r.Status | Should -BeExactly 'Held'
    $r.Reason | Should -BeExactly 'ResidentActivationExpiredOrNotStarted'
    $r.Drains | Should -Be 1
  }

  It 'a renewed window is honored with the same descriptor hash' {
    Write-Activation $f -StartMinutes -10 -EndMinutes -5
    (Invoke-CoordClerkResident -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -MaximumDrains 1).Status | Should -BeExactly 'Held'
    Write-Activation $f -StartMinutes -1 -EndMinutes 30
    (Get-FileHash -LiteralPath $f.Path).Hash | Should -BeExactly $f.Digest
    $r = Invoke-CoordClerkResident -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -MaximumDrains 1
    $r.Status | Should -BeExactly 'Stopped'
    $r.Drains | Should -Be 1
  }

  It 'applies the activation record drain limit' {
    Write-Activation $f -MaximumDrains 1
    $r = Invoke-CoordClerkResident -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -MaximumDrains 5
    $r.Reason | Should -BeExactly 'ActivationDrainLimit'
    $r.Drains | Should -Be 1
  }

  It 'v2 Held mode returns before admission or import' {
    $held = New-V2Fixture -Mode 'Held'
    $r = Invoke-CoordClerkResident -BindingPath $held.Path -ExpectedBindingSha256 $held.Digest
    $r.Reason | Should -BeExactly 'ConfiguredHeld'
    Should -Invoke Get-CoordResidentDrain -Times 0
  }
}

Describe 'Resident package admission reuses Assert-CoordPackageInventory' -Tag 'Unit' {
  BeforeAll {
    $private = Join-Path $PSScriptRoot '../../private'
    $script:probe = New-Module -Name 'ResidentSlice6InventoryProbe' -ArgumentList (Join-Path $private 'CoordProducer.ps1'), (Join-Path $private 'CoordProducerJson.ps1') -ScriptBlock {
      param($producer, $json)
      . $producer; . $json
      Export-ModuleMember -Function @()
    }
  }
  AfterAll { Remove-Module -ModuleInfo $script:probe -ErrorAction SilentlyContinue }
  BeforeEach {
    $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path (Join-Path $root 'Resources\Resident'), (Join-Path $root 'schemas'), (Join-Path $root 'tests') -Force
    [IO.File]::WriteAllText((Join-Path $root ($script:moduleName + '.psd1')), "@{ ModuleVersion = '0.1.17' }")
    Copy-Item -LiteralPath $script:hostSource -Destination (Join-Path $root 'Resources\Resident\Invoke-CoordClerkResident.ps1')
    [IO.File]::WriteAllText((Join-Path $root 'schemas\activation-record-v1.schema.json'), '{}')
    [IO.File]::WriteAllText((Join-Path $root 'tests\ignored.Tests.ps1'), '# tests are outside the inventory')
    $pins = @(foreach ($rel in @(($script:moduleName + '.psd1'), 'Resources/Resident/Invoke-CoordClerkResident.ps1', 'schemas/activation-record-v1.schema.json')) {
      [ordered]@{ path = $rel; digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes((Join-Path $root $rel)))).ToLowerInvariant() } })
    $package = @{ moduleVersion = '0.1.17'; files = $pins }
  }

  It 'admits the exact custody inventory' {
    { Assert-CoordResidentPackage -Module $script:probe -ModuleRoot $root -Package $package } | Should -Not -Throw
  }

  It 'refuses: <Name>' -ForEach @(
    @{ Name = 'a changed host byte'; Change = { param($r, $p) [IO.File]::AppendAllText((Join-Path $r 'Resources\Resident\Invoke-CoordClerkResident.ps1'), ' ') } }
    @{ Name = 'another version label'; Change = { param($r, $p) $p.moduleVersion = '0.1.18' } }
    @{ Name = 'an extra uninventoried file'; Change = { param($r, $p) [IO.File]::WriteAllText((Join-Path $r 'schemas\extra.json'), '{}') } }
  ) {
    & $Change $root $package
    { Assert-CoordResidentPackage -Module $script:probe -ModuleRoot $root -Package $package } | Should -Throw '*ResidentIncompatiblePackage*'
  }

  It 'refuses without a module to verify in' {
    { Assert-CoordResidentPackage -Module $null -ModuleRoot $root -Package $package } | Should -Throw '*ResidentIncompatiblePackage*'
  }
}

Describe 'Resident host identity under a launcher' -Tag 'Unit' {
  It 'resolves the defining host file, not the invoking launcher' {
    $launcher = Join-Path $TestDrive 'Start-CoordClerkResident.ps1'
    [IO.File]::WriteAllText($launcher, "param(`$HostPath) . `$HostPath; [pscustomobject]@{ HostFile = Get-CoordResidentHostFile; Invoker = `$PSCommandPath }")
    $r = & $launcher -HostPath $script:hostSource
    $r.HostFile | Should -BeExactly $script:hostSource
    $r.Invoker | Should -BeExactly $launcher
  }

  It 'v2 drain refuses a host that is not the custody-admitted version''s host' {
    Mock Assert-CoordResidentPath { param($Path) [IO.Path]::GetFullPath($Path) }
    $binding = @{ schemaVersion = 'CoordResidentStartup-v2'; windowsSid = (Get-CoordResidentIdentity).WindowsSid }
    $admission = [pscustomobject]@{ Package = @{ moduleVersion = '0.1.17' }; ActivationPath = 'C:\fixture\activation.json' }
    { Get-CoordResidentDrain -Binding $binding -Admission $admission } | Should -Throw '*ResidentInstalledHostRequired*'
  }

  Context 'Pinned signer trust anchor (M3)' {
    BeforeEach {
      Mock Assert-CoordResidentPath { param($Path) [IO.Path]::GetFullPath($Path) }
      Mock Get-CoordResidentHostFile { 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.BuildTooling.Orchestration.PowerShell\0.1.17\Resources\Resident\Invoke-CoordClerkResident.ps1' }
      $binding = @{ schemaVersion = 'CoordResidentStartup-v2'; windowsSid = (Get-CoordResidentIdentity).WindowsSid }
      $admission = [pscustomobject]@{ Package = @{ moduleVersion = '0.1.17' }; ActivationPath = 'C:\fixture\activation.json'; PolicySigner = $null }
    }

    It 'requires the pinned signer on the host as well as on the manifest and root module' {
      Mock Get-AuthenticodeSignature { if ($LiteralPath -like '*.ps1') { @{ Status = 'Valid'; SignerCertificate = @{ Thumbprint = 'A' * 40 } } } else { @{ Status = 'Valid'; SignerCertificate = @{ Thumbprint = 'B' * 40 } } } }
      { Get-CoordResidentDrain -Binding $binding -Admission $admission -SignerThumbprint ('A' * 40) } | Should -Throw '*ResidentInstalledSignatureRejected*'
      Should -Invoke Get-AuthenticodeSignature -Times 1 -ParameterFilter { $LiteralPath -like '*Invoke-CoordClerkResident.ps1' }
    }

    It 'does not trust the host''s own signature: consistently signed files from another signer are refused' {
      Mock Get-AuthenticodeSignature { @{ Status = 'Valid'; SignerCertificate = @{ Thumbprint = 'B' * 40 } } }
      { Get-CoordResidentDrain -Binding $binding -Admission $admission -SignerThumbprint ('A' * 40) } | Should -Throw '*ResidentInstalledSignatureRejected*'
    }

    It 'refuses with no pin and no custody policy signer, before any signature is read' {
      Mock Get-AuthenticodeSignature { @{ Status = 'Valid'; SignerCertificate = @{ Thumbprint = 'A' * 40 } } }
      { Get-CoordResidentDrain -Binding $binding -Admission $admission } | Should -Throw '*ResidentSignerPinRequired*'
      Should -Invoke Get-AuthenticodeSignature -Times 0
    }

    It 'uses custody''s policy signer when no pin is passed' {
      Mock Get-AuthenticodeSignature { @{ Status = 'Valid'; SignerCertificate = @{ Thumbprint = 'B' * 40 } } }
      $admission.PolicySigner = 'A' * 40
      { Get-CoordResidentDrain -Binding $binding -Admission $admission } | Should -Throw '*ResidentInstalledSignatureRejected*'
    }

    It 'refuses a pin that differs from custody''s policy signer' {
      $admission.PolicySigner = 'A' * 40
      { Get-CoordResidentDrain -Binding $binding -Admission $admission -SignerThumbprint ('B' * 40) } | Should -Throw '*ResidentSignerPinMismatch*'
    }

    It 'resolves the anchor: <Name>' -ForEach @(
      @{ Name = 'pin only'; Pin = 'a' * 40; Policy = ''; Expect = 'A' * 40; Throw = $null }
      @{ Name = 'policy only'; Pin = ''; Policy = 'B' * 40; Expect = 'B' * 40; Throw = $null }
      @{ Name = 'both equal, case-insensitive'; Pin = 'c' * 40; Policy = 'C' * 40; Expect = 'C' * 40; Throw = $null }
      @{ Name = 'neither'; Pin = ''; Policy = ''; Expect = $null; Throw = 'ResidentSignerPinRequired' }
      @{ Name = 'malformed pin'; Pin = 'Z' * 40; Policy = ''; Expect = $null; Throw = 'ResidentSignerPinRequired' }
      @{ Name = 'pin with trailing newline'; Pin = ('A' * 40) + "`n"; Policy = ''; Expect = $null; Throw = 'ResidentSignerPinRequired' }
      @{ Name = 'mismatch'; Pin = 'A' * 40; Policy = 'B' * 40; Expect = $null; Throw = 'ResidentSignerPinMismatch' }
    ) {
      if ($Throw) { { Resolve-CoordResidentSigner -Pin $Pin -PolicySigner $Policy } | Should -Throw ('*' + $Throw + '*') }
      else { Resolve-CoordResidentSigner -Pin $Pin -PolicySigner $Policy | Should -BeExactly $Expect }
    }
  }
}

Describe 'Registrar with v2 descriptors' -Tag 'Unit' {
  BeforeEach {
    $priorKeys = Get-Variable configRootKeys -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    $priorSettings = Get-Variable settings -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    $f = New-V2Fixture
    $launcher = Join-Path $TestDrive 'Start-CoordClerkResident.ps1'
    [IO.File]::WriteAllText($launcher, '# synthetic stable launcher stand-in')
    $thumb = 'C' * 40
    $global:ATAPSlice6Actions = [Collections.Generic.List[string]]::new()
    Mock Get-AuthenticodeSignature { @{ Status = 'Valid'; SignerCertificate = @{ Thumbprint = 'C' * 40 } } }
    Mock Get-ScheduledTask { $null }
    Mock New-ScheduledTaskTrigger { @{ Trigger = 'fixture' } }
    Mock New-ScheduledTaskPrincipal { @{ Principal = 'fixture' } }
    Mock New-ScheduledTaskAction { $global:ATAPSlice6Actions.Add($Execute + ' ' + $Argument); @{ Action = 'fixture' } }
    Mock New-ScheduledTaskSettingsSet { @{ Enabled = $false } }
    Mock New-ScheduledTask { @{ Fixture = $true } }
    Mock Register-ScheduledTask { @{ Registered = 'fixture' } }
    Mock Write-PSFMessage {}
    Mock Enable-ScheduledTask { throw 'MustNeverEnable' }
    Mock Start-ScheduledTask { throw 'MustNeverStart' }
    Mock Get-CoordResidentDrain { { 'admitted' } }
  }
  AfterEach {
    Should -Invoke Enable-ScheduledTask -Times 0
    Should -Invoke Start-ScheduledTask -Times 0
    $global:configRootKeys = $priorKeys; $global:settings = $priorSettings
    Remove-Variable ATAPSlice6Actions -Scope Global -ErrorAction SilentlyContinue
  }

  It 'registers a v2 Held descriptor disabled with the host path parameter and no version folder' {
    $held = New-V2Fixture -Mode 'Held'
    $r = Register-CoordClerkLogonTask -BindingPath $held.Path -ExpectedBindingSha256 $held.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -Confirm:$false
    $r.Status | Should -BeExactly 'RegisteredDisabled'
    $r.Arguments | Should -BeLike ('*-File "' + $launcher + '"*')
    $r.Arguments | Should -Not -Match '\\[0-9]+\.[0-9]+\.[0-9]+\\'
    $r.ActivationAdmitted | Should -BeFalse
    Should -Invoke Get-CoordResidentDrain -Times 0
    Should -Invoke New-ScheduledTaskSettingsSet -Times 1 -ParameterFilter { $Disable }
  }

  It 'a package version change leaves the descriptor hash and the task definition unchanged' {
    $first = Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -Confirm:$false
    $first.ActivationAdmitted | Should -BeTrue
    Should -Invoke Get-CoordResidentDrain -Times 1 -ParameterFilter { $Admission.Package.moduleVersion -ceq '0.1.17' }
    Set-Custody $f -Version '0.1.18' -Generation 'epoch-b'
    $second = Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -Confirm:$false
    Should -Invoke Get-CoordResidentDrain -Times 1 -ParameterFilter { $Admission.Package.moduleVersion -ceq '0.1.18' }
    (Get-FileHash -LiteralPath $f.Path).Hash | Should -BeExactly $f.Digest
    $second.Arguments | Should -BeExactly $first.Arguments
    $second.Execute | Should -BeExactly $first.Execute
    $second.Description | Should -BeExactly $first.Description
    @($global:ATAPSlice6Actions | Select-Object -Unique).Count | Should -Be 1
  }

  It 'a renewed activation window leaves the task definition unchanged' {
    $first = Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -Confirm:$false
    Write-Activation $f -StartMinutes 0 -EndMinutes 120 -MaximumDrains 4
    $second = Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -Confirm:$false
    (Get-FileHash -LiteralPath $f.Path).Hash | Should -BeExactly $f.Digest
    $second.Arguments | Should -BeExactly $first.Arguments
    @($global:ATAPSlice6Actions | Select-Object -Unique).Count | Should -Be 1
  }

  It 'v2 Active task action carries -ExecutionPolicy RemoteSigned before -File by default (D2)' {
    $r = Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -Confirm:$false
    $r.ExecutionPolicy | Should -BeExactly 'RemoteSigned'
    $r.Arguments | Should -BeLike ('*-ExecutionPolicy RemoteSigned -File "' + $launcher + '"*')
    $global:ATAPSlice6Actions[0] | Should -BeLike '*-ExecutionPolicy RemoteSigned -File *'
    Should -Invoke New-ScheduledTaskAction -Times 1 -Exactly -ParameterFilter { $Argument -clike '* -ExecutionPolicy RemoteSigned -File "*' }
  }

  It 'v2 Active accepts AllSigned as an explicit choice (D2)' {
    $r = Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -ExecutionPolicy AllSigned -WhatIf
    $r.ExecutionPolicy | Should -BeExactly 'AllSigned'
    $r.Arguments | Should -BeLike ('*-ExecutionPolicy AllSigned -File "' + $launcher + '"*')
  }

  It 'refuses Inherit for v2 Active: the policy must be deterministic (D2)' {
    { Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -ExecutionPolicy Inherit -Confirm:$false } | Should -Throw '*ResidentExecutionPolicyRequired*'
    Should -Invoke Get-CoordResidentDrain -Times 0
    Should -Invoke Register-ScheduledTask -Times 0
  }

  It 'never accepts Bypass (or any other policy) at parameter binding (D2)' {
    foreach ($policy in @('Bypass', 'Unrestricted', 'Undefined', 'remotesigned ')) {
      { Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -ExecutionPolicy $policy -WhatIf } | Should -Throw -Because $policy
    }
    Should -Invoke Register-ScheduledTask -Times 0
  }

  It 'passes the pin to the package check and refuses a pin that differs from custody''s policy signer (M3)' {
    $null = Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -WhatIf
    Should -Invoke Get-CoordResidentDrain -Times 1 -Exactly -ParameterFilter { $SignerThumbprint -ceq $thumb }
    $w = Get-Content -LiteralPath $f.Binding.custodyPath -Raw | ConvertFrom-Json -AsHashtable
    $w['autoPackageAdmission'] = [ordered]@{ enabled = $true; signer = 'D' * 40 }
    Write-FixtureJson $f.Binding.custodyPath $w
    { Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -Confirm:$false } | Should -Throw '*ResidentSignerPinMismatch*'
    Should -Invoke Register-ScheduledTask -Times 0
  }

  It 'v2 Held has no policy flag by default and can opt in to RemoteSigned or AllSigned' {
    $held = New-V2Fixture -Mode 'Held'
    $plain = Register-CoordClerkLogonTask -BindingPath $held.Path -ExpectedBindingSha256 $held.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -WhatIf
    $plain.ExecutionPolicy | Should -BeExactly 'Inherit'
    $plain.Arguments | Should -Not -BeLike '*-ExecutionPolicy*'
    foreach ($policy in @('RemoteSigned', 'AllSigned')) {
      $chosen = Register-CoordClerkLogonTask -BindingPath $held.Path -ExpectedBindingSha256 $held.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -ExecutionPolicy $policy -WhatIf
      $chosen.Arguments | Should -BeLike ('*-ExecutionPolicy ' + $policy + ' -File *')
    }
  }

  It 'refuses Active with an expired activation' {
    Write-Activation $f -StartMinutes -10 -EndMinutes -5
    { Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -Confirm:$false } | Should -Throw '*ResidentActivationExpiredOrNotStarted*'
    Should -Invoke Register-ScheduledTask -Times 0
  }

  It 'refuses Active with a missing activation' {
    Remove-Item -LiteralPath $f.ActivationPath
    { Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -Confirm:$false } | Should -Throw '*ResidentActivationMissing*'
    Should -Invoke Register-ScheduledTask -Times 0
  }

  It 'refuses Active when custody does not admit the running package' {
    Mock Get-CoordResidentDrain { throw 'ResidentIncompatiblePackage' }
    { Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -Confirm:$false } | Should -Throw '*ResidentIncompatiblePackage*'
    Should -Invoke Register-ScheduledTask -Times 0
  }

  It 'maps an unexpected admission failure to ResidentActiveNotAdmitted' {
    Mock Get-CoordResidentDrain { throw 'SomethingUnexpected' }
    { Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -Confirm:$false } | Should -Throw '*ResidentActiveNotAdmitted*'
    Should -Invoke Register-ScheduledTask -Times 0
  }

  It 'requires a host path and signer pin for v2' {
    { Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -SignerThumbprint $thumb -Confirm:$false } | Should -Throw '*ResidentHostPathRequired*'
    { Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -Confirm:$false } | Should -Throw '*ResidentSignerPinRequired*'
    Should -Invoke Register-ScheduledTask -Times 0
  }

  It 'refuses a host with another signer' {
    { Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint ('D' * 40) -Confirm:$false } | Should -Throw '*ResidentHostSignatureRejected*'
    Should -Invoke Get-ScheduledTask -Times 0
  }

  It 'still refuses an existing task name for v2' {
    Mock Get-ScheduledTask { @{ TaskName = 'CoordClerkResident' } }
    { Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -Confirm:$false } | Should -Throw '*ResidentTaskAlreadyExists*'
    Should -Invoke Register-ScheduledTask -Times 0
  }

  It 'WhatIf proposes v2 Active without querying or registering' {
    $r = Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcher -SignerThumbprint $thumb -WhatIf
    $r.Status | Should -BeExactly 'ProposedOnly'
    Should -Invoke Get-ScheduledTask -Times 0
    Should -Invoke Register-ScheduledTask -Times 0
  }

  It 'v1 Held keeps the derived host and refuses a different host path' {
    $base = 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.BuildTooling.Orchestration.PowerShell\0.1.16'
    $v1 = @{ schemaVersion = 'CoordResidentStartup-v1'; mode = 'Held'; windowsSid = (Get-CoordResidentIdentity).WindowsSid; module = @{ version = '0.1.16'; manifestPath = Join-Path $base ($script:moduleName + '.psd1'); rootModulePath = Join-Path $base ($script:moduleName + '.psm1'); manifestSha256 = 'A' * 64; rootModuleSha256 = 'A' * 64; hostScriptSha256 = 'A' * 64; signerThumbprint = 'A' * 40 } }
    Mock Read-CoordResidentBinding { $v1 }
    Mock Assert-CoordResidentPath { param($Path) [IO.Path]::GetFullPath($Path) }
    { Register-CoordClerkLogonTask -BindingPath 'C:\fixture\held.json' -ExpectedBindingSha256 ('A' * 64) -HostScriptPath $launcher -Confirm:$false } | Should -Throw '*ResidentHostPathMismatch*'
    Should -Invoke Register-ScheduledTask -Times 0
  }

  Context 'Task arguments bind to the target script (Orch017-Fix-RegistrarLauncherArguments)' {
    BeforeAll {
      $script:realLauncher = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../Resources/Resident/Start-CoordClerkResident.ps1'))
      function Split-TaskArguments([string]$Text) {
        @([regex]::Matches($Text, '"([^"]*)"|(\S+)') | ForEach-Object { if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value } })
      }
      function Get-TaskBinding([string]$Text) {
        $t = Split-TaskArguments $Text
        $i = [array]::IndexOf($t, '-File')
        $named = [ordered]@{}
        for ($k = $i + 2; $k -lt $t.Count; $k += 2) {
          if ($t[$k] -cnotmatch '\A-[A-Za-z][A-Za-z0-9]*\z' -or $k + 1 -ge $t.Count) { throw ('UnpairedTaskArgument:' + $t[$k]) }
          $named[$t[$k].Substring(1)] = $t[$k + 1]
        }
        @{ Before = @($t[0..($i - 1)]); Script = $t[$i + 1]; Named = $named }
      }
      function Get-ScriptContract([string]$Path) {
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
        $params = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
        $guard = @($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.IfStatementAst] -and $_.Extent.Text -like "if (`$MyInvocation.InvocationName*" })[0]
        $required = @()
        if ($guard) {
          # Ast.Find includes the root, so exclude the outer InvocationName guard itself.
          $outer = $guard
          $inner = $guard.Find({ param($n) $n -is [Management.Automation.Language.IfStatementAst] -and -not [object]::ReferenceEquals($n, $outer) -and $n.Extent.Text -like '*ArgumentsRequired*' }, $true)
          $required = @($inner.Clauses[0].Item1.FindAll({ param($n) $n -is [Management.Automation.Language.VariableExpressionAst] }, $true) | ForEach-Object { $_.VariablePath.UserPath } | Select-Object -Unique)
        }
        @{ Parameters = $params; Required = $required }
      }
    }
    BeforeEach {
      $launcherCopy = Join-Path (Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))) 'Start-CoordClerkResident.ps1'
      $null = New-Item -ItemType Directory -Path (Split-Path $launcherCopy) -Force
      Copy-Item -LiteralPath $script:realLauncher -Destination $launcherCopy
      $hostCopy = Join-Path (Split-Path $launcherCopy) 'Invoke-CoordClerkResident.ps1'
      Copy-Item -LiteralPath $script:hostSource -Destination $hostCopy
    }

    It 'launcher arguments satisfy every launcher parameter and entry requirement, with RemoteSigned before -File' {
      $r = Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcherCopy -SignerThumbprint $thumb -Confirm:$false
      $r.HostKind | Should -BeExactly 'StableLauncher'
      $b = Get-TaskBinding $r.Arguments
      $b.Before | Should -Contain '-ExecutionPolicy'
      [array]::IndexOf($b.Before, 'RemoteSigned') | Should -Be ([array]::IndexOf($b.Before, '-ExecutionPolicy') + 1)
      $b.Script | Should -BeExactly $launcherCopy
      $contract = Get-ScriptContract $script:realLauncher
      $contract.Required | Should -Be @('BindingPath', 'ExpectedBindingSha256', 'CustodyPath', 'SignerThumbprint')
      foreach ($name in $b.Named.Keys) { $contract.Parameters | Should -Contain $name }
      foreach ($name in $contract.Required) { $b.Named[$name] | Should -Not -BeNullOrEmpty }
      $b.Named['CustodyPath'] | Should -BeExactly ([IO.Path]::GetFullPath($f.Binding.custodyPath))
      $b.Named['SignerThumbprint'] | Should -BeExactly $thumb
      $b.Named['BindingPath'] | Should -BeExactly $f.Path
      $b.Named['ExpectedBindingSha256'] | Should -BeExactly $f.Digest
      Should -Invoke New-ScheduledTaskAction -Times 1 -Exactly -ParameterFilter { $Argument -ceq $r.Arguments }
    }

    It 'the exact registered arguments start the real launcher past its argument check' {
      $held = New-V2Fixture -Mode 'Held'
      $r = Register-CoordClerkLogonTask -BindingPath $held.Path -ExpectedBindingSha256 $held.Digest -HostScriptPath $launcherCopy -SignerThumbprint $thumb -WhatIf
      $r.HostKind | Should -BeExactly 'StableLauncher'
      $info = [Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source, $r.Arguments)
      $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true; $info.UseShellExecute = $false
      $process = [Diagnostics.Process]::Start($info)
      $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
      $process.WaitForExit()
      $text = $stdout.Result + $stderr.Result
      $text | Should -Not -BeLike '*LauncherArgumentsRequired*'
      $json = ($stdout.Result -split "`n" | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -Last 1) | ConvertFrom-Json
      $json.Status | Should -BeExactly 'Refused'
      $json.Reason | Should -Match '\ALauncher[A-Za-z]+\z'
      $json.Reason | Should -Not -BeExactly 'LauncherArgumentsRequired'
      $process.ExitCode | Should -Be 3
    }

    It 'the exact v2 Active arguments (RemoteSigned) run a local unsigned launcher, which AllSigned would block (D2)' {
      $r = Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $launcherCopy -SignerThumbprint $thumb -WhatIf
      $r.ExecutionPolicy | Should -BeExactly 'RemoteSigned'
      $run = {
        param([string]$Arguments)
        $info = [Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source, $Arguments)
        $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true; $info.UseShellExecute = $false
        $process = [Diagnostics.Process]::Start($info)
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        @{ Out = $stdout.Result; Err = $stderr.Result; Exit = $process.ExitCode }
      }
      # The TestDrive copy is unsigned and local. Under RemoteSigned it runs and refuses with a Launcher* code.
      $remote = & $run $r.Arguments
      $json = ($remote.Out -split "`n" | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -Last 1) | ConvertFrom-Json
      $json.Reason | Should -Match '\ALauncher[A-Za-z]+\z'
      $remote.Exit | Should -Be 3
      # The same arguments with AllSigned never start it: this is the B5 failure the default avoids.
      $signed = & $run ($r.Arguments.Replace('-ExecutionPolicy RemoteSigned ', '-ExecutionPolicy AllSigned '))
      ($signed.Out + $signed.Err) | Should -BeLike '*not digitally signed*'
      ($signed.Out -split "`n" | Where-Object { $_.TrimStart().StartsWith('{') }) | Should -BeNullOrEmpty
    }

    It 'a v2 versioned host also gets the signer pin, which binds to its param() (M3)' {
      $r = Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $hostCopy -SignerThumbprint $thumb -Confirm:$false
      $r.HostKind | Should -BeExactly 'VersionedHost'
      $r.Arguments | Should -BeExactly ('-NoLogo -NonInteractive -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File "{0}" -BindingPath "{1}" -ExpectedBindingSha256 "{2}" -SignerThumbprint "{3}"' -f $hostCopy, $f.Path, $f.Digest, $thumb)
      $b = Get-TaskBinding $r.Arguments
      $contract = Get-ScriptContract $script:hostSource
      @($b.Named.Keys) | Should -Be @('BindingPath', 'ExpectedBindingSha256', 'SignerThumbprint')
      foreach ($name in $b.Named.Keys) { $contract.Parameters | Should -Contain $name }
      foreach ($name in $contract.Required) { $b.Named[$name] | Should -Not -BeNullOrEmpty }
    }

    It 'refuses a v2 host whose kind cannot be decided' {
      $other = Join-Path (Split-Path $launcherCopy) 'Other-Host.ps1'
      Copy-Item -LiteralPath $launcherCopy -Destination $other
      { Register-CoordClerkLogonTask -BindingPath $f.Path -ExpectedBindingSha256 $f.Digest -HostScriptPath $other -SignerThumbprint $thumb -Confirm:$false } | Should -Throw '*ResidentHostKindUnknown*'
      Should -Invoke Register-ScheduledTask -Times 0
    }

    It 'refuses the launcher for a descriptor without a custody path' {
      $identity = Get-CoordResidentIdentity
      $path = Join-Path (Split-Path $launcherCopy) 'held-minimal.json'
      Write-FixtureJson $path ([ordered]@{ schemaVersion = 'CoordResidentStartup-v2'; mode = 'Held'; hostName = $identity.HostName; windowsSid = $identity.WindowsSid })
      { Register-CoordClerkLogonTask -BindingPath $path -ExpectedBindingSha256 (Get-FileHash -LiteralPath $path).Hash -HostScriptPath $launcherCopy -SignerThumbprint $thumb -Confirm:$false } | Should -Throw '*ResidentLauncherCustodyPathRequired*'
      Should -Invoke Register-ScheduledTask -Times 0
    }
  }

  It 'v1 Held keeps its action without a policy flag' {
    $base = 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.BuildTooling.Orchestration.PowerShell\0.1.16'
    $v1 = @{ schemaVersion = 'CoordResidentStartup-v1'; mode = 'Held'; windowsSid = (Get-CoordResidentIdentity).WindowsSid; module = @{ version = '0.1.16'; manifestPath = Join-Path $base ($script:moduleName + '.psd1'); rootModulePath = Join-Path $base ($script:moduleName + '.psm1'); manifestSha256 = 'A' * 64; rootModuleSha256 = 'A' * 64; hostScriptSha256 = 'A' * 64; signerThumbprint = 'A' * 40 } }
    Mock Read-CoordResidentBinding { $v1 }
    Mock Assert-CoordResidentPath { param($Path) [IO.Path]::GetFullPath($Path) }
    Mock Get-FileHash { @{ Hash = 'A' * 64 } }
    Mock Get-AuthenticodeSignature { @{ Status = 'Valid'; SignerCertificate = @{ Thumbprint = 'A' * 40 } } }
    $r = Register-CoordClerkLogonTask -BindingPath 'C:\fixture\held.json' -ExpectedBindingSha256 ('A' * 64) -WhatIf
    $r.ExecutionPolicy | Should -BeExactly 'Inherit'
    $r.Arguments | Should -Not -BeLike '*-ExecutionPolicy*'
  }
}


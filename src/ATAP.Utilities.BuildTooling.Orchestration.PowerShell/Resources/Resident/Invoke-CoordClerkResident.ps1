[CmdletBinding()]
param([string]$BindingPath, [string]$ExpectedBindingSha256, [string]$SignerThumbprint = '')

# Descriptor versions:
#   CoordResidentStartup-v1 pins module.* hashes, generation and the activation window inside
#   the hashed descriptor (any release or new window changes the hash and the task).
#   CoordResidentStartup-v2 binds identity and paths only. Each loop the host reads the
#   package and generation from custody, admits the package by custody's inventory plus a
#   pinned signer (custody's autoPackageAdmission.signer and/or the -SignerThumbprint pin; never
#   the host's own signature), and reads the window from a separate protected
#   Coordination-activation-v1 record bound to the descriptor hash (at most 12 hours long).

function Assert-CoordResidentPath {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path, [switch]$MustExist)
  $full = [IO.Path]::GetFullPath($Path)
  if (-not [IO.Path]::IsPathFullyQualified($Path) -or $full.StartsWith('\\', [StringComparison]::Ordinal)) { throw 'ResidentLocalPathRequired' }
  for ($part = $full; $part; $part = [IO.Path]::GetDirectoryName($part)) {
    if (Test-Path -LiteralPath $part) {
      $item = Get-Item -LiteralPath $part -Force
      if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'ResidentReparsePathRefused' }
    } elseif ($MustExist -and $part -ceq $full) { throw 'ResidentEstablishedPathRequired' }
  }
  $full
}

function Get-CoordResidentIdentity {
  [CmdletBinding()]
  param()
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  [pscustomobject]@{ HostName = [Environment]::MachineName; WindowsSid = $identity.User.Value; WindowsIdentity = $identity.Name }
}

function Get-CoordResidentHostFile {
  # The file that defines these functions, not $PSCommandPath: a launcher that dot-sources
  # this host (slice 7) is the invoking script, but this file is still the admitted host.
  [CmdletBinding()]
  param()
  $MyInvocation.MyCommand.ScriptBlock.File
}

function Get-CoordResidentActivationMaximum {
  # L5: longest window one Coordination-activation-v1 record may grant. Twelve hours covers one
  # working day of resident drains and forces a fresh, separately approved record after that.
  # The human custody handoff caps its own window at 15 minutes; a resident window is longer by
  # design, but never unbounded. v1 descriptors keep their embedded window unchanged.
  [CmdletBinding()]
  param()
  [TimeSpan]::FromHours(12)
}

function Assert-CoordResidentWindow {
  [CmdletBinding()]
  param([string]$NotBeforeUtc, [string]$NotAfterUtc, [TimeSpan]$MaximumDuration = [TimeSpan]::Zero)
  $culture = [Globalization.CultureInfo]::InvariantCulture
  try {
    $start = [DateTimeOffset]::ParseExact($NotBeforeUtc, 'r', $culture)
    $end = [DateTimeOffset]::ParseExact($NotAfterUtc, 'r', $culture)
  } catch { throw 'ResidentActivationExpiredOrNotStarted' }
  if ($MaximumDuration -gt [TimeSpan]::Zero -and ($end - $start) -gt $MaximumDuration) { throw 'ResidentActivationWindowTooLong' }
  $now = [DateTimeOffset]::UtcNow
  if ($end -le $start -or $now -lt $start -or $now -gt $end) { throw 'ResidentActivationExpiredOrNotStarted' }
}

function Resolve-CoordResidentSigner {
  # M3: the trust anchor for the installed host, manifest and root module is a pinned thumbprint,
  # never the running host's own signature. Sources: custody's standing policy signer
  # (custody.autoPackageAdmission.signer) and the caller's pin (the task argument, passed through
  # the stable launcher). Either is enough; both must agree; neither refuses.
  [CmdletBinding()]
  param([string]$Pin, [string]$PolicySigner)
  $hasPin = -not [string]::IsNullOrEmpty($Pin)
  $hasPolicy = -not [string]::IsNullOrEmpty($PolicySigner)
  if ($hasPin -and $Pin -cnotmatch '\A[0-9a-fA-F]{40}\z') { throw 'ResidentSignerPinRequired' }
  if ($hasPolicy -and $PolicySigner -cnotmatch '\A[0-9a-fA-F]{40}\z') { throw 'ResidentSignerPolicyInvalid' }
  if (-not $hasPin -and -not $hasPolicy) { throw 'ResidentSignerPinRequired' }
  if ($hasPin -and $hasPolicy -and $Pin -ine $PolicySigner) { throw 'ResidentSignerPinMismatch' }
  if ($hasPolicy) { $PolicySigner.ToUpperInvariant() } else { $Pin.ToUpperInvariant() }
}

function Read-CoordResidentBinding {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Digest)
  $full = Assert-CoordResidentPath -Path $Path -MustExist
  if ($Digest -cnotmatch '\A[0-9a-fA-F]{64}\z') { throw 'ResidentBindingPinRequired' }
  $bytes = [IO.File]::ReadAllBytes($full)
  if ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)) -ine $Digest) { throw 'ResidentBindingChanged' }
  try {
    $json = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    $binding = ConvertFrom-Json -InputObject $json -AsHashtable -Depth 30
  } catch { throw 'ResidentBindingInvalid' }
  if ($binding -isnot [Collections.IDictionary]) { throw 'ResidentBindingInvalid' }
  # Refuse ambiguous mixed versions explicitly, before the schema, so the reason is specific.
  $foreign = switch -CaseSensitive ([string]$binding['schemaVersion']) {
    'CoordResidentStartup-v1' { @('activationPath') }
    'CoordResidentStartup-v2' { @('module', 'generation', 'activation') }
    default { throw 'ResidentDescriptorVersionAmbiguous' }
  }
  foreach ($key in $foreign) { if ($binding.Contains($key)) { throw 'ResidentDescriptorVersionAmbiguous' } }
  if (-not (Test-Json -Json $json -SchemaFile (Join-Path $PSScriptRoot 'ResidentStartup.schema.json') -ErrorAction SilentlyContinue)) { throw 'ResidentBindingInvalid' }
  $identity = Get-CoordResidentIdentity
  if ($binding.hostName -ine $identity.HostName -or $binding.windowsSid -cne $identity.WindowsSid) { throw 'ResidentIdentityMismatch' }
  $binding
}

function Read-CoordResidentActivation {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$DescriptorSha256)
  $full = Assert-CoordResidentPath -Path $Path
  if (-not [IO.File]::Exists($full)) { throw 'ResidentActivationMissing' }
  $full = Assert-CoordResidentPath -Path $full -MustExist
  try { $json = [Text.UTF8Encoding]::new($false, $true).GetString([IO.File]::ReadAllBytes($full)) } catch { throw 'ResidentActivationInvalid' }
  if (-not (Test-Json -Json $json -SchemaFile (Join-Path $PSScriptRoot '../../schemas/activation-record-v1.schema.json') -ErrorAction SilentlyContinue)) { throw 'ResidentActivationInvalid' }
  $record = ConvertFrom-Json -InputObject $json -AsHashtable -Depth 10
  if ($record.descriptorSha256 -ine $DescriptorSha256) { throw 'ResidentActivationDescriptorMismatch' }
  Assert-CoordResidentWindow -NotBeforeUtc $record.notBeforeUtc -NotAfterUtc $record.notAfterUtc -MaximumDuration (Get-CoordResidentActivationMaximum)
  $record['path'] = $full
  $record
}

function Test-CoordResidentAdmission {
  [CmdletBinding()]
  param([Parameter(Mandatory)][Collections.IDictionary]$Binding, [string]$Digest)
  $v2 = $Binding.schemaVersion -ceq 'CoordResidentStartup-v2'
  if ($v2) {
    if ($Digest -cnotmatch '\A[0-9a-fA-F]{64}\z') { throw 'ResidentBindingPinRequired' }
    $activation = Read-CoordResidentActivation -Path $Binding.activationPath -DescriptorSha256 $Digest
  } else {
    Assert-CoordResidentWindow -NotBeforeUtc $Binding.activation.notBeforeUtc -NotAfterUtc $Binding.activation.notAfterUtc
    $activation = @{ approvalReference = $Binding.activation.reference; notBeforeUtc = $Binding.activation.notBeforeUtc; notAfterUtc = $Binding.activation.notAfterUtc; maximumDrains = 0; path = $null }
  }
  $keys = Get-Variable configRootKeys -Scope Global -ValueOnly -ErrorAction SilentlyContinue
  $settings = Get-Variable settings -Scope Global -ValueOnly -ErrorAction SilentlyContinue
  if ($null -eq $keys -or $null -eq $settings) { throw 'ResidentConfigurationUnavailable' }
  $stateKey = $keys['OrchestrationStateRootPathConfigRootKey']
  $custodyKey = $keys['OrchestrationCustodyRecordPathConfigRootKey']
  if (-not $stateKey -or -not $custodyKey -or -not $settings.ContainsKey($stateKey) -or -not $settings.ContainsKey($custodyKey)) { throw 'ResidentConfigurationUnavailable' }
  $statePath = Assert-CoordResidentPath -Path $Binding.statePath -MustExist
  $custodyPath = Assert-CoordResidentPath -Path $Binding.custodyPath -MustExist
  if ([IO.Path]::GetDirectoryName($statePath) -ine [IO.Path]::GetFullPath($settings[$stateKey]) -or $custodyPath -ine [IO.Path]::GetFullPath($settings[$custodyKey])) { throw 'ResidentConfiguredPathsMismatch' }
  # Read-only correlation before each drain. The public clerk independently takes
  # its leases and validates protected custody, package, state and recovery again.
  $witness = Get-Content -LiteralPath $custodyPath -Raw | ConvertFrom-Json -AsHashtable -Depth 70
  $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -AsHashtable -Depth 70
  if ($witness.admissionMode -cne 'Established' -or $witness.custodianSid -cne $Binding.windowsSid) { throw 'ResidentCustodyNotAdmitted' }
  if ($v2) {
    # v2: the generation comes from custody, not the descriptor; witness and state must agree.
    foreach ($key in @('resourceId', 'lineageId')) {
      if ($witness[$key] -cne $Binding[$key] -or $state[$key] -cne $Binding[$key]) { throw 'ResidentEpochChanged' }
    }
    if ($witness.generation -isnot [string] -or [string]::IsNullOrWhiteSpace($witness.generation) -or $state.generation -cne $witness.generation) { throw 'ResidentEpochChanged' }
  } else {
    foreach ($key in @('resourceId', 'lineageId', 'generation')) {
      if ($witness[$key] -cne $Binding[$key] -or $state[$key] -cne $Binding[$key]) { throw 'ResidentEpochChanged' }
    }
  }
  $actors = @($witness.actors | Where-Object { $_.holderId -ceq $Binding.holderId -and $_.sessionId -ceq $Binding.sessionId -and $_.windowsSid -ceq $Binding.windowsSid -and $_.role -ceq 'Coordinator' })
  if ($actors.Count -ne 1 -or $state.mutationAdmission.status -cne 'Admitted') { throw 'ResidentActorOrPackageHeld' }
  if ($v2) {
    if ($witness.package -isnot [Collections.IDictionary] -or [string]$witness.package.moduleVersion -cnotmatch '\A[0-9]+\.[0-9]+\.[0-9]+\z') { throw 'ResidentIncompatiblePackage' }
  } elseif ($witness.package.moduleVersion -cne $Binding.module.version) { throw 'ResidentActorOrPackageHeld' }
  $leasePath = [IO.Path]::GetFullPath($Binding.leasePath)
  if ($leasePath -ieq [IO.Path]::GetFullPath($witness.boardLockPath)) { throw 'ResidentProducerLeaseConflict' }
  $stopPath = [IO.Path]::GetFullPath($Binding.stopPath)
  foreach ($path in @($leasePath, $stopPath)) {
    foreach ($protectedRoot in @([IO.Path]::GetDirectoryName($statePath), [IO.Path]::GetDirectoryName($custodyPath))) {
      if ($path.StartsWith($protectedRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'ResidentControlInsideProtectedState' }
    }
  }
  if ($v2) {
    $activationPath = $activation.path
    if ($activationPath -iin @($leasePath, $stopPath, $statePath, $custodyPath) -or
        $activationPath.StartsWith([IO.Path]::GetDirectoryName($statePath).TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'ResidentActivationPathConflict' }
  }
  # Custody's standing policy signer, when a policy block exists (M3). A malformed block refuses.
  $policySigner = $null
  if ($v2 -and $witness.Contains('autoPackageAdmission') -and $null -ne $witness.autoPackageAdmission) {
    $policy = $witness.autoPackageAdmission
    if ($policy -isnot [Collections.IDictionary] -or $policy['signer'] -isnot [string] -or $policy['signer'] -cnotmatch '\A[0-9a-fA-F]{40}\z') { throw 'ResidentSignerPolicyInvalid' }
    $policySigner = $policy['signer']
  }
  [pscustomobject]@{ Generation = $witness.generation; Package = $witness.package; Activation = $activation; ActivationPath = $activation.path; PolicySigner = $policySigner }
}

function Assert-CoordResidentPackage {
  # Reuses the module's own Assert-CoordPackageInventory in module scope: custody's exact
  # version and file inventory must equal the installed folder. No second copy of the rule.
  [CmdletBinding()]
  param($Module, [string]$ModuleRoot, $Package)
  if ($Module -isnot [Management.Automation.PSModuleInfo] -or -not $ModuleRoot -or $null -eq $Package) { throw 'ResidentIncompatiblePackage' }
  try { & $Module { param($root, $package) Assert-CoordPackageInventory -ModuleRoot $root -Package $package } $ModuleRoot $Package }
  catch { if ($_.Exception.Message -ceq 'IncompatiblePackage') { throw 'ResidentIncompatiblePackage' }; throw 'ResidentPackageVerificationFailed' }
}

function Assert-CoordResidentActivationProtection {
  # The activation record must sit in a custodian-protected location (module Assert-CoordProtection).
  [CmdletBinding()]
  param($Module, [string]$Path, [string]$CustodianSid)
  if ($Module -isnot [Management.Automation.PSModuleInfo] -or -not $Path) { throw 'ResidentActivationUnprotected' }
  try { & $Module { param($p, $sid) Assert-CoordProtection -Path $p -CustodianSid $sid } $Path $CustodianSid }
  catch { throw 'ResidentActivationUnprotected' }
}

function Get-CoordResidentDrain {
  [CmdletBinding()]
  param([Parameter(Mandatory)][Collections.IDictionary]$Binding, $Admission, [string]$SignerThumbprint = '')
  $name = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
  $allUsers = 'C:\Program Files\PowerShell\Modules'
  $hostPath = Assert-CoordResidentPath -Path (Get-CoordResidentHostFile) -MustExist
  $v2 = $Binding.schemaVersion -ceq 'CoordResidentStartup-v2'
  if ($v2) {
    if ($null -eq $Admission -or [string]$Admission.Package.moduleVersion -cnotmatch '\A[0-9]+\.[0-9]+\.[0-9]+\z') { throw 'ResidentIncompatiblePackage' }
    $version = [string]$Admission.Package.moduleVersion
  } else { $version = $Binding.module.version }
  $base = [IO.Path]::GetFullPath((Join-Path $allUsers ($name + '\' + $version)))
  $expectedHost = [IO.Path]::GetFullPath((Join-Path $base 'Resources\Resident\Invoke-CoordClerkResident.ps1'))
  if ($v2) {
    # The running host must be the host of the custody-admitted version (directly, or reached
    # through the stable launcher). The trust anchor is the pinned signer (custody policy and/or
    # the task's pin), never the host's own signature: host, manifest and root module must all
    # carry exactly that signer (M3).
    $manifest = Assert-CoordResidentPath -Path (Join-Path $base ($name + '.psd1')) -MustExist
    $root = Assert-CoordResidentPath -Path (Join-Path $base ($name + '.psm1')) -MustExist
    if ($hostPath -ine $expectedHost) { throw 'ResidentInstalledHostRequired' }
    $signer = Resolve-CoordResidentSigner -Pin $SignerThumbprint -PolicySigner ([string]$Admission.PolicySigner)
    foreach ($path in @($hostPath, $manifest, $root)) {
      $signature = Get-AuthenticodeSignature -LiteralPath $path
      if ($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate -or $signature.SignerCertificate.Thumbprint -ine $signer) { throw 'ResidentInstalledSignatureRejected' }
    }
  } else {
    $manifest = Assert-CoordResidentPath -Path $Binding.module.manifestPath -MustExist
    $root = Assert-CoordResidentPath -Path $Binding.module.rootModulePath -MustExist
    if ($manifest -ine (Join-Path $base ($name + '.psd1')) -or $root -ine (Join-Path $base ($name + '.psm1'))) { throw 'ResidentInstalledAllUsersRequired' }
    if ($hostPath -ine $expectedHost -or (Get-FileHash -LiteralPath $hostPath).Hash -ine $Binding.module.hostScriptSha256) { throw 'ResidentInstalledHostRequired' }
    foreach ($pin in @(@{ Path = $manifest; Digest = $Binding.module.manifestSha256 }, @{ Path = $root; Digest = $Binding.module.rootModuleSha256 })) {
      if ((Get-FileHash -LiteralPath $pin.Path).Hash -ine $pin.Digest) { throw 'ResidentInstalledPackageChanged' }
      $signature = Get-AuthenticodeSignature -LiteralPath $pin.Path
      if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ine $Binding.module.signerThumbprint) { throw 'ResidentInstalledSignatureRejected' }
    }
  }
  foreach ($directory in $env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ }) {
    if (Test-Path -LiteralPath (Join-Path $directory $name)) {
      if ([IO.Path]::GetFullPath($directory).TrimEnd('\') -ine $allUsers) { throw 'ResidentModuleShadowed' }
      break
    }
  }
  $loaded = @(Get-Module -Name $name -All)
  if (@($loaded | Where-Object { [IO.Path]::GetFullPath($_.Path) -ine $root }).Count) { throw 'ResidentLoadedModuleMismatch' }
  $selected = Import-Module -Name $name -RequiredVersion $version -PassThru -ErrorAction Stop
  if ([IO.Path]::GetFullPath($selected.Path) -ine $root) { throw 'ResidentImportedModuleMismatch' }
  if ($v2) {
    Assert-CoordResidentPackage -Module $selected -ModuleRoot $base -Package $Admission.Package
    Assert-CoordResidentActivationProtection -Module $selected -Path $Admission.ActivationPath -CustodianSid $Binding.windowsSid
  }
  $command = Get-Command Invoke-CoordClerk -FullyQualifiedModule @{ ModuleName = $name; RequiredVersion = $version } -ErrorAction Stop
  if ([IO.Path]::GetFullPath($command.Module.Path) -ine $root -or [IO.Path]::GetFullPath($command.ScriptBlock.File) -ine $root) { throw 'ResidentDrainOriginMismatch' }
  $command
}

function Invoke-CoordClerkResident {
  <#
  .SYNOPSIS
    Hosts sequential bounded public clerk drains under separately admitted custody.
  .DESCRIPTION
    Default/missing/invalid/held bindings return Held before importing the clerk or
    reading custody. Active bindings require current same-user admission on each
    iteration. A separate pre-created lifetime lease never replaces producer locks.
    Stop is observed between drains; neither cancellation nor limits are kill timers.
    A v2 descriptor carries no package or generation pins: each iteration re-reads
    custody's admitted package (exact inventory, same signer as this host) and the
    separate activation record. A package that custody no longer admits, or a missing,
    mismatched or expired activation, returns Held and exits; it is never retried.
  .PARAMETER BindingPath
    Ordinary local, independently approved startup descriptor; never created here.
  .PARAMETER ExpectedBindingSha256
    Exact independently approved bytes. A change holds the host, not automatic reload.
  .PARAMETER CancellationToken
    Borrowed outer-loop cancellation; never claims in-flight clerk cancellation.
  .PARAMETER MaximumDrains
    Optional finite caller limit. Zero permits resident lifetime within activation.
    With a v2 activation record the lower non-zero limit of the two applies.
  .PARAMETER SignerThumbprint
    v2 only: the pinned Authenticode signer (40 hex) that the installed host, manifest and root
    module must carry. The stable launcher passes its task-argument pin; a task that runs this
    host directly passes the registrar's pin. Custody's autoPackageAdmission.signer, when
    present, must equal it. With neither, a v2 host refuses (ResidentSignerPinRequired).
  .OUTPUTS
    Host status, reason, completed drain count and last public drain result.
  .EXAMPLE
    Invoke-CoordClerkResident -BindingPath $path -ExpectedBindingSha256 $digest -WhatIf
  .NOTES
    No actor registration, package transition, task activation or assignment allocator.
    A launcher must dot-source this file and call this function (or use pwsh -File);
    invoking the file with & skips its entry block by design.
  .LINK
    ../../Documentation/Producer-v1.md
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)][string]$BindingPath,
    [Parameter(Mandatory)][string]$ExpectedBindingSha256,
    [Threading.CancellationToken]$CancellationToken = [Threading.CancellationToken]::None,
    [ValidateRange(0, 2147483647)][int]$MaximumDrains = 0,
    [string]$SignerThumbprint = ''
  )
  begin { $fn = 'Invoke-CoordClerkResident'; $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell' }
  process {
    $lease = $null; $count = 0; $last = $null; $reason = 'StartupHeld'; $status = 'Held'; $packageVersion = $null; $descriptorVersion = $null
    try {
      if (-not (Test-Path -LiteralPath $BindingPath)) { $reason = 'BindingMissing' }
      else {
        $binding = Read-CoordResidentBinding -Path $BindingPath -Digest $ExpectedBindingSha256
        $descriptorVersion = $binding.schemaVersion
        $v2 = $descriptorVersion -ceq 'CoordResidentStartup-v2'
        if ($binding.mode -ceq 'Held') { $reason = 'ConfiguredHeld' }
        elseif ($CancellationToken.IsCancellationRequested -or (Test-Path -LiteralPath (Assert-CoordResidentPath -Path $binding.stopPath))) { $status = 'Stopped'; $reason = 'StopRequestedAtBoundary' }
        elseif (-not $PSCmdlet.ShouldProcess($binding.resourceId, 'Host admitted bounded clerk drains')) { $status = 'ProposedOnly'; $reason = 'NotStarted' }
        else {
          $admission = Test-CoordResidentAdmission -Binding $binding -Digest $ExpectedBindingSha256
          if ($v2 -and $null -eq $admission) { throw 'ResidentAdmissionUnavailable' }
          $leasePath = Assert-CoordResidentPath -Path $binding.leasePath -MustExist
          $conflicts = @($binding.statePath, $binding.custodyPath, $binding.stopPath) + $(if ($v2) { @($binding.activationPath) } else { @() })
          if ($leasePath -iin @($conflicts | ForEach-Object { [IO.Path]::GetFullPath($_) })) { throw 'ResidentLeasePathConflict' }
          $lease = [IO.File]::Open($leasePath, 'Open', 'ReadWrite', 'None')
          $drain = Get-CoordResidentDrain -Binding $binding -Admission $admission -SignerThumbprint $SignerThumbprint
          if ($v2) { $packageVersion = [string]$admission.Package.moduleVersion }
          $status = 'Stopped'; $reason = 'StopRequestedAtBoundary'
          while (-not $CancellationToken.IsCancellationRequested) {
            $current = Read-CoordResidentBinding -Path $BindingPath -Digest $ExpectedBindingSha256
            if ($current.mode -cne 'Active') { $status = 'Held'; $reason = 'ConfiguredHeld'; break }
            $admission = Test-CoordResidentAdmission -Binding $current -Digest $ExpectedBindingSha256
            $activationLimit = 0
            if ($v2) {
              # Custody is re-read every loop: a package swap or re-admission under this
              # process holds and exits; the next start resolves the new version.
              if ($null -eq $admission -or [string]$admission.Package.moduleVersion -cne $packageVersion) { throw 'ResidentIncompatiblePackage' }
              $module = $drain.Module
              $moduleRoot = if ($module) { Split-Path -Path $module.Path -Parent } else { $null }
              Assert-CoordResidentPackage -Module $module -ModuleRoot $moduleRoot -Package $admission.Package
              Assert-CoordResidentActivationProtection -Module $module -Path $admission.ActivationPath -CustodianSid $current.windowsSid
              $activationLimit = [int]$admission.Activation.maximumDrains
            }
            $stopPath = Assert-CoordResidentPath -Path $current.stopPath
            if (Test-Path -LiteralPath $stopPath) { break }
            $last = & $drain -HolderId $current.holderId -SessionId $current.sessionId -Confirm:$false
            $count++
            if ($null -eq $last -or $last.Status -cne 'Observed' -or $last.ResourceId -cne $current.resourceId -or $last.DrainStatus -cnotin @('Drained', 'RemainingWork')) { throw 'ResidentDrainRequiresReconciliation' }
            if ($MaximumDrains -gt 0 -and $count -ge $MaximumDrains) { $reason = 'CallerDrainLimit'; break }
            if ($activationLimit -gt 0 -and $count -ge $activationLimit) { $reason = 'ActivationDrainLimit'; break }
            if ($CancellationToken.WaitHandle.WaitOne(2000)) { break }
          }
        }
      }
    } catch {
      $status = 'Held'; $reason = if ($_.Exception.Message -cmatch '\AResident[A-Za-z]+\z') { $_.Exception.Message } else { 'ValidationOrDrainFailed' }
      $null = Get-Command Write-PSFMessage -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message ('Resident held after validation or drain failure; no automatic retry. Reason: ' + $reason)
    } finally { if ($lease) { $lease.Dispose() } }
    [pscustomobject]@{ Status = $status; Reason = $reason; Drains = $count; LastDrain = $last; ProcessId = [Environment]::ProcessId; StopBoundary = 'BetweenDrains'; ActivationChanged = $false; DescriptorVersion = $descriptorVersion; PackageVersion = $packageVersion }
  }
  end {}
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  if (-not $BindingPath -or -not $ExpectedBindingSha256) { throw 'ResidentBindingArgumentsRequired' }
  Invoke-CoordClerkResident -BindingPath $BindingPath -ExpectedBindingSha256 $ExpectedBindingSha256 -SignerThumbprint $SignerThumbprint | ConvertTo-Json -Depth 20 -Compress
}

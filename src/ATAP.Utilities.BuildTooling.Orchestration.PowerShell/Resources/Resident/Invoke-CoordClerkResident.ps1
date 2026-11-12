[CmdletBinding()]
param([string]$BindingPath, [string]$ExpectedBindingSha256)

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

function Read-CoordResidentBinding {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Digest)
  $full = Assert-CoordResidentPath -Path $Path -MustExist
  if ($Digest -cnotmatch '\A[0-9a-fA-F]{64}\z') { throw 'ResidentBindingPinRequired' }
  $bytes = [IO.File]::ReadAllBytes($full)
  if ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)) -ine $Digest) { throw 'ResidentBindingChanged' }
  $json = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
  if (-not (Test-Json -Json $json -SchemaFile (Join-Path $PSScriptRoot 'ResidentStartup.schema.json') -ErrorAction SilentlyContinue)) { throw 'ResidentBindingInvalid' }
  $binding = ConvertFrom-Json -InputObject $json -AsHashtable -Depth 30
  $identity = Get-CoordResidentIdentity
  if ($binding.hostName -ine $identity.HostName -or $binding.windowsSid -cne $identity.WindowsSid) { throw 'ResidentIdentityMismatch' }
  $binding
}

function Test-CoordResidentAdmission {
  [CmdletBinding()]
  param([Parameter(Mandatory)][Collections.IDictionary]$Binding)
  $now = [DateTimeOffset]::UtcNow
  $culture = [Globalization.CultureInfo]::InvariantCulture
  $start = [DateTimeOffset]::ParseExact($Binding.activation.notBeforeUtc, 'r', $culture)
  $end = [DateTimeOffset]::ParseExact($Binding.activation.notAfterUtc, 'r', $culture)
  if ($end -le $start -or $now -lt $start -or $now -gt $end) { throw 'ResidentActivationExpiredOrNotStarted' }
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
  foreach ($key in @('resourceId', 'lineageId', 'generation')) {
    if ($witness[$key] -cne $Binding[$key] -or $state[$key] -cne $Binding[$key]) { throw 'ResidentEpochChanged' }
  }
  $actors = @($witness.actors | Where-Object { $_.holderId -ceq $Binding.holderId -and $_.sessionId -ceq $Binding.sessionId -and $_.windowsSid -ceq $Binding.windowsSid -and $_.role -ceq 'Coordinator' })
  if ($actors.Count -ne 1 -or $state.mutationAdmission.status -cne 'Admitted' -or $witness.package.moduleVersion -cne $Binding.module.version) { throw 'ResidentActorOrPackageHeld' }
  $leasePath = [IO.Path]::GetFullPath($Binding.leasePath)
  if ($leasePath -ieq [IO.Path]::GetFullPath($witness.boardLockPath)) { throw 'ResidentProducerLeaseConflict' }
  foreach ($path in @($leasePath, [IO.Path]::GetFullPath($Binding.stopPath))) {
    foreach ($protectedRoot in @([IO.Path]::GetDirectoryName($statePath), [IO.Path]::GetDirectoryName($custodyPath))) {
      if ($path.StartsWith($protectedRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'ResidentControlInsideProtectedState' }
    }
  }
}

function Get-CoordResidentDrain {
  [CmdletBinding()]
  param([Parameter(Mandatory)][Collections.IDictionary]$Binding)
  $name = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
  $base = Join-Path 'C:\Program Files\PowerShell\Modules' ($name + '\' + $Binding.module.version)
  $manifest = Assert-CoordResidentPath -Path $Binding.module.manifestPath -MustExist
  $root = Assert-CoordResidentPath -Path $Binding.module.rootModulePath -MustExist
  if ($manifest -ine (Join-Path $base ($name + '.psd1')) -or $root -ine (Join-Path $base ($name + '.psm1'))) { throw 'ResidentInstalledAllUsersRequired' }
  $hostPath = Assert-CoordResidentPath -Path $PSCommandPath -MustExist
  if ($hostPath -ine (Join-Path $base 'Resources/Resident/Invoke-CoordClerkResident.ps1') -or (Get-FileHash -LiteralPath $hostPath).Hash -ine $Binding.module.hostScriptSha256) { throw 'ResidentInstalledHostRequired' }
  foreach ($pin in @(@{ Path = $manifest; Digest = $Binding.module.manifestSha256 }, @{ Path = $root; Digest = $Binding.module.rootModuleSha256 })) {
    if ((Get-FileHash -LiteralPath $pin.Path).Hash -ine $pin.Digest) { throw 'ResidentInstalledPackageChanged' }
    $signature = Get-AuthenticodeSignature -LiteralPath $pin.Path
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ine $Binding.module.signerThumbprint) { throw 'ResidentInstalledSignatureRejected' }
  }
  foreach ($directory in $env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ }) {
    if (Test-Path -LiteralPath (Join-Path $directory $name)) {
      if ([IO.Path]::GetFullPath($directory).TrimEnd('\') -ine 'C:\Program Files\PowerShell\Modules') { throw 'ResidentModuleShadowed' }
      break
    }
  }
  $loaded = @(Get-Module -Name $name -All)
  if (@($loaded | Where-Object { [IO.Path]::GetFullPath($_.Path) -ine $root }).Count) { throw 'ResidentLoadedModuleMismatch' }
  $selected = Import-Module -Name $name -RequiredVersion $Binding.module.version -PassThru -ErrorAction Stop
  if ([IO.Path]::GetFullPath($selected.Path) -ine $root) { throw 'ResidentImportedModuleMismatch' }
  $command = Get-Command Invoke-CoordClerk -FullyQualifiedModule @{ ModuleName = $name; RequiredVersion = $Binding.module.version } -ErrorAction Stop
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
  .PARAMETER BindingPath
    Ordinary local, independently approved startup descriptor; never created here.
  .PARAMETER ExpectedBindingSha256
    Exact independently approved bytes. A change holds the host, not automatic reload.
  .PARAMETER CancellationToken
    Borrowed outer-loop cancellation; never claims in-flight clerk cancellation.
  .PARAMETER MaximumDrains
    Optional finite caller limit. Zero permits resident lifetime within activation.
  .OUTPUTS
    Host status, reason, completed drain count and last public drain result.
  .EXAMPLE
    Invoke-CoordClerkResident -BindingPath $path -ExpectedBindingSha256 $digest -WhatIf
  .NOTES
    No actor registration, package transition, task activation or assignment allocator.
  .LINK
    ../../Documentation/Producer-v1.md
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)][string]$BindingPath,
    [Parameter(Mandatory)][string]$ExpectedBindingSha256,
    [Threading.CancellationToken]$CancellationToken = [Threading.CancellationToken]::None,
    [ValidateRange(0, 2147483647)][int]$MaximumDrains = 0
  )
  begin { $fn = 'Invoke-CoordClerkResident'; $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell' }
  process {
    $lease = $null; $count = 0; $last = $null; $reason = 'StartupHeld'; $status = 'Held'
    try {
      if (-not (Test-Path -LiteralPath $BindingPath)) { $reason = 'BindingMissing' }
      else {
        $binding = Read-CoordResidentBinding -Path $BindingPath -Digest $ExpectedBindingSha256
        if ($binding.mode -ceq 'Held') { $reason = 'ConfiguredHeld' }
        elseif ($CancellationToken.IsCancellationRequested -or (Test-Path -LiteralPath (Assert-CoordResidentPath -Path $binding.stopPath))) { $status = 'Stopped'; $reason = 'StopRequestedAtBoundary' }
        elseif (-not $PSCmdlet.ShouldProcess($binding.resourceId, 'Host admitted bounded clerk drains')) { $status = 'ProposedOnly'; $reason = 'NotStarted' }
        else {
          Test-CoordResidentAdmission -Binding $binding
          $leasePath = Assert-CoordResidentPath -Path $binding.leasePath -MustExist
          if ($leasePath -ieq $binding.statePath -or $leasePath -ieq $binding.custodyPath -or $leasePath -ieq $binding.stopPath) { throw 'ResidentLeasePathConflict' }
          $lease = [IO.File]::Open($leasePath, 'Open', 'ReadWrite', 'None')
          $drain = Get-CoordResidentDrain -Binding $binding
          $status = 'Stopped'; $reason = 'StopRequestedAtBoundary'
          while (-not $CancellationToken.IsCancellationRequested) {
            $current = Read-CoordResidentBinding -Path $BindingPath -Digest $ExpectedBindingSha256
            if ($current.mode -cne 'Active') { $status = 'Held'; $reason = 'ConfiguredHeld'; break }
            Test-CoordResidentAdmission -Binding $current
            $stopPath = Assert-CoordResidentPath -Path $current.stopPath
            if (Test-Path -LiteralPath $stopPath) { break }
            $last = & $drain -HolderId $current.holderId -SessionId $current.sessionId -Confirm:$false
            $count++
            if ($null -eq $last -or $last.Status -cne 'Observed' -or $last.ResourceId -cne $current.resourceId -or $last.DrainStatus -cnotin @('Drained', 'RemainingWork')) { throw 'ResidentDrainRequiresReconciliation' }
            if ($MaximumDrains -gt 0 -and $count -ge $MaximumDrains) { $reason = 'CallerDrainLimit'; break }
            if ($CancellationToken.WaitHandle.WaitOne(2000)) { break }
          }
        }
      }
    } catch {
      $status = 'Held'; $reason = if ($_.Exception.Message -cmatch '\AResident[A-Za-z]+\z') { $_.Exception.Message } else { 'ValidationOrDrainFailed' }
      $null = Get-Command Write-PSFMessage -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Resident held after validation or drain failure; no automatic retry.'
    } finally { if ($lease) { $lease.Dispose() } }
    [pscustomobject]@{ Status = $status; Reason = $reason; Drains = $count; LastDrain = $last; ProcessId = [Environment]::ProcessId; StopBoundary = 'BetweenDrains'; ActivationChanged = $false }
  }
  end {}
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  if (-not $BindingPath -or -not $ExpectedBindingSha256) { throw 'ResidentBindingArgumentsRequired' }
  Invoke-CoordClerkResident -BindingPath $BindingPath -ExpectedBindingSha256 $ExpectedBindingSha256 | ConvertTo-Json -Depth 20 -Compress
}

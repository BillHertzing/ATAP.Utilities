[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$BindingPath,
  [string]$ExpectedBindingSha256,
  [string]$CustodyPath,
  [string]$SignerThumbprint,
  [int]$MaximumDrains = 0,
  [string]$ModulesRoot = 'C:\Program Files\PowerShell\Modules'
)

# Stable, version-independent resident launcher (0.1.17 slice 7, hardened by Orch017-Fix-H2).
# The logon task points at this file at a fixed path, so a package release never changes the
# task action. Each start:
#   1. reads the pinned v2 descriptor and custody with readers defined IN THIS FILE. No code
#      from any installed version folder runs to find out what custody admits (H2);
#   2. locates exactly one AllUsers install of custody's admitted version, checks the pinned
#      signer on its host, manifest and root module, and hashes every file custody pins
#      (refusing unpinned loadable files and links) before anything in it is loaded;
#   3. requires this launcher's own bytes to equal the admitted package's bundled launcher;
#   4. only then dot-sources that (now admitted) version's host, runs its full descriptor and
#      activation readers, imports the module and re-verifies the inventory in module scope;
#   5. calls Invoke-CoordClerkResident (never &), passing the signer pin through.
# It writes no file of its own. Refusals return a Launcher* code (JSON and exit code 3 under
# pwsh -File) and are logged best-effort through PSFramework when it is available (L3).

function Get-CoordLauncherModuleName { 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell' }

function Get-CoordLauncherBundledPath { 'Resources/Resident/Start-CoordClerkResident.ps1' }

function Test-CoordLauncherSigner {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Thumbprint)
  $signature = Get-AuthenticodeSignature -LiteralPath $Path
  $signature.Status -eq 'Valid' -and $null -ne $signature.SignerCertificate -and $signature.SignerCertificate.Thumbprint -ieq $Thumbprint
}

function Get-CoordLauncherSha256 {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path)
  [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($Path)))
}

function Assert-CoordLauncherPath {
  # Own copy of the host's path rule: local, fully qualified, no reparse point on any ancestor.
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path, [switch]$MustExist)
  if (-not [IO.Path]::IsPathFullyQualified($Path)) { throw 'LauncherLocalPathRequired' }
  $full = [IO.Path]::GetFullPath($Path)
  if ($full.StartsWith('\\', [StringComparison]::Ordinal)) { throw 'LauncherLocalPathRequired' }
  for ($part = $full; $part; $part = [IO.Path]::GetDirectoryName($part)) {
    if (Test-Path -LiteralPath $part) {
      if ((Get-Item -LiteralPath $part -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'LauncherReparsePathRefused' }
    } elseif ($MustExist -and $part -ceq $full) { throw 'LauncherPathMissing' }
  }
  $full
}

function ConvertFrom-CoordLauncherJson {
  # Strict UTF-8 (invalid bytes throw), parsed to hashtables. Built-in cmdlets only.
  [CmdletBinding()]
  param([Parameter(Mandatory)][byte[]]$Bytes, [Parameter(Mandatory)][string]$Code)
  try {
    $text = [Text.UTF8Encoding]::new($false, $true).GetString($Bytes)
    $value = ConvertFrom-Json -InputObject $text -AsHashtable -Depth 70
  } catch { throw $Code }
  if ($value -isnot [Collections.IDictionary]) { throw $Code }
  $value
}

function Read-CoordLauncherDescriptor {
  # Minimal descriptor reader: exact bytes, v2 only, same Windows identity. The admitted host
  # re-validates the descriptor in full (schema included) before it runs anything (step 4).
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Digest)
  if ($Digest -cnotmatch '\A[0-9a-fA-F]{64}\z') { throw 'DescriptorPinRequired' }
  $full = Assert-CoordLauncherPath -Path $Path -MustExist
  $bytes = [IO.File]::ReadAllBytes($full)
  if ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)) -ine $Digest) { throw 'DescriptorBindingChanged' }
  $binding = ConvertFrom-CoordLauncherJson -Bytes $bytes -Code 'DescriptorInvalid'
  if ($binding['schemaVersion'] -cne 'CoordResidentStartup-v2') { throw 'LauncherDescriptorV2Required' }
  foreach ($key in @('mode', 'hostName', 'windowsSid', 'custodyPath')) {
    if ($binding[$key] -isnot [string] -or [string]::IsNullOrWhiteSpace($binding[$key])) { throw 'DescriptorInvalid' }
  }
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  if ($binding.hostName -ine [Environment]::MachineName -or $binding.windowsSid -cne $identity.User.Value) { throw 'DescriptorIdentityMismatch' }
  $binding
}

function Read-CoordLauncherCustody {
  # Minimal custody reader (H2): parses custody.json and returns only what the launcher needs
  # to locate and verify the admitted package. No module or package code is loaded.
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$CustodianSid)
  $full = Assert-CoordLauncherPath -Path $Path -MustExist
  $custody = ConvertFrom-CoordLauncherJson -Bytes ([IO.File]::ReadAllBytes($full)) -Code 'CustodyInvalid'
  if ($custody['admissionMode'] -cne 'Established' -or $custody['custodianSid'] -cne $CustodianSid) { throw 'CustodyNotAdmitted' }
  $package = $custody['package']
  if ($package -isnot [Collections.IDictionary]) { throw 'NoAdmittedPackageVersion' }
  $version = $package['moduleVersion']
  if ($version -isnot [string] -or $version -cnotmatch '\A[0-9]+\.[0-9]+\.[0-9]+\z') { throw 'NoAdmittedPackageVersion' }
  $rule = if (-not $package.Contains('inventoryRule')) { 'v1' } elseif ($package['inventoryRule'] -ceq 'v2') { 'v2' } else { throw 'CustodyInventoryRuleUnknown' }
  # An empty list reads; it then fails the required pins in Assert-CoordLauncherInventory.
  $files = $package['files']
  if ($files -isnot [Collections.IList]) { throw 'CustodyInventoryInvalid' }
  foreach ($pin in $files) {
    if ($pin -isnot [Collections.IDictionary] -or $pin['path'] -isnot [string] -or $pin['digest'] -isnot [string] -or $pin['digest'] -cnotmatch '\A[0-9a-fA-F]{64}\z') { throw 'CustodyInventoryInvalid' }
  }
  $policySigner = $null
  if ($custody.Contains('autoPackageAdmission') -and $null -ne $custody['autoPackageAdmission']) {
    $policy = $custody['autoPackageAdmission']
    if ($policy -isnot [Collections.IDictionary] -or $policy['signer'] -isnot [string] -or $policy['signer'] -cnotmatch '\A[0-9a-fA-F]{40}\z') { throw 'CustodyPolicyInvalid' }
    $policySigner = $policy['signer']
  }
  [pscustomobject]@{ Version = $version; Files = @($files); InventoryRule = $rule; PolicySigner = $policySigner; Package = $package }
}

function Assert-CoordLauncherInventory {
  # Hashes every file custody pins under the version root BEFORE anything there is loaded, and
  # refuses unpinned loadable files (manifest-referenced scripts, type and format data,
  # assemblies). v2 inventories pin every file; v1 inventories pin the script and data types
  # outside tests\. The module's own Assert-CoordPackageInventory runs again after import.
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$VersionRoot, [Parameter(Mandatory)][object[]]$Files, [Parameter(Mandatory)][string]$InventoryRule, [Parameter(Mandatory)][string[]]$RequiredPaths)
  $root = [IO.Path]::GetFullPath($VersionRoot).TrimEnd('\')
  $everything = @(Get-ChildItem -LiteralPath $root -Recurse -Force)
  $pinned = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($pin in $Files) {
    $relative = [string]$pin['path']
    if ($relative -cnotmatch '\A[^\\:*?"<>|]+\z' -or $relative.StartsWith('/') -or @($relative.Split('/') | Where-Object { $_ -in @('', '.', '..') }).Count) { throw 'InventoryPathInvalid' }
    if ($pinned.ContainsKey($relative)) { throw 'InventoryPathDuplicate' }
    $pinned[$relative] = $pin
  }
  foreach ($required in $RequiredPaths) { if (-not $pinned.ContainsKey($required)) { throw ('InventoryMissingPin:' + $required) } }
  $loadable = @('.ps1', '.psm1', '.psd1', '.json', '.ps1xml', '.cdxml', '.dll', '.exe', '.cat')
  foreach ($file in @($everything | Where-Object { -not $_.PSIsContainer })) {
    $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace('\', '/')
    if ($pinned.ContainsKey($relative)) { continue }
    $inTests = $relative.StartsWith('tests/', [StringComparison]::OrdinalIgnoreCase)
    if ($InventoryRule -ceq 'v2' -or ($file.Extension -in $loadable -and -not $inTests)) { throw ('InventoryUnpinnedFile:' + $relative) }
  }
  foreach ($relative in $pinned.Keys) {
    $pin = $pinned[$relative]
    $path = [IO.Path]::GetFullPath((Join-Path $root $relative))
    if (-not $path.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase) -or -not [IO.File]::Exists($path)) { throw ('InventoryFileMissing:' + $relative) }
    $bytes = [IO.File]::ReadAllBytes($path)
    if ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)) -ine [string]$pin['digest']) { throw ('InventoryDigestMismatch:' + $relative) }
    if ($pin.Contains('size') -and $null -ne $pin['size'] -and [int64]$pin['size'] -ne $bytes.LongLength) { throw ('InventorySizeMismatch:' + $relative) }
  }
}

function Get-CoordLauncherSelfPath {
  # The file that defines the launcher's functions: the fixed-path copy the task runs.
  [CmdletBinding()]
  param()
  $MyInvocation.MyCommand.ScriptBlock.File
}

function Test-CoordLauncherSelfAdmitted {
  # The fixed-path launcher must byte-equal the launcher bundled in the custody-admitted
  # package, so the copy outside custody's inventory is admitted by reference to it. This is
  # defence in depth only: a tampered launcher could omit it. The real controls are the
  # pinned signer on the package files (see NOTES below).
  [CmdletBinding()]
  param([Parameter(Mandatory)]$Package)
  $self = Get-CoordLauncherSelfPath
  if (-not $self -or -not [IO.File]::Exists($self)) { return $false }
  $pins = @($Package.files | Where-Object { $_.path -ceq (Get-CoordLauncherBundledPath) })
  if ($pins.Count -ne 1 -or [string]$pins[0].digest -cnotmatch '\A[0-9a-fA-F]{64}\z') { return $false }
  (Get-CoordLauncherSha256 -Path $self) -ieq [string]$pins[0].digest
}

function Get-CoordLauncherHostPath {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$VersionRoot)
  [IO.Path]::GetFullPath((Join-Path $VersionRoot 'Resources\Resident\Invoke-CoordClerkResident.ps1'))
}

function Test-CoordLauncherUpgradeCompatibility {
  <#
  .SYNOPSIS
    M1 pre-upgrade check: would admitting a candidate package strand the resident behind the
    fixed-path launcher (LauncherSelfNotAdmitted)?
  .DESCRIPTION
    Pure and read-only. Compares the candidate's bundled launcher digest (from its attestation
    or custody-style file inventory) with the bytes of the installed fixed-path launcher.
    Contract for Invoke-CoordPackageUpgrade (Junior Dev #2): call it after the candidate is
    verified and BEFORE any custody write or resident stop. On Refused, return NotNow with code
    'Upgrade' + Reason and write nothing. Dot-source this file inside a dedicated function so
    its script parameters bind in that function's scope, not the caller's.
  .PARAMETER CandidateFiles
    The candidate's file inventory: attestation files[] entries (path, sha256) or custody
    package.files entries (path, digest).
  .PARAMETER InstalledLauncherPath
    The fixed-path launcher the logon task runs (C:\Program Files\ATAP\Orchestration\Start-CoordClerkResident.ps1).
  .PARAMETER LauncherReinstallPlanned
    The upgrade plan re-installs the launcher from the candidate (Install-ATAPCoordResidentLauncher
    after custody admits the candidate and before the resident restarts).
  .OUTPUTS
    Status Compatible or Refused; Reason LauncherUnchanged, LauncherReinstallPlanned,
    LauncherChangeRequiresReinstall, CandidateLauncherPinMissing or InstalledLauncherMissing;
    CandidateSha256; InstalledSha256.
  .EXAMPLE
    Test-CoordLauncherUpgradeCompatibility -CandidateFiles $attestation.files -InstalledLauncherPath 'C:\Program Files\ATAP\Orchestration\Start-CoordClerkResident.ps1'
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$CandidateFiles,
    [Parameter(Mandatory)][string]$InstalledLauncherPath,
    [switch]$LauncherReinstallPlanned
  )
  $result = { param($status, $reason, $candidate, $installed) [pscustomobject]@{ Status = $status; Reason = $reason; CandidateSha256 = $candidate; InstalledSha256 = $installed } }
  $pins = @($CandidateFiles | Where-Object { $null -ne $_ -and [string]$_.path -ceq (Get-CoordLauncherBundledPath) })
  $digest = if ($pins.Count -eq 1) { if ($pins[0].sha256) { [string]$pins[0].sha256 } else { [string]$pins[0].digest } } else { $null }
  if ($digest -cnotmatch '\A[0-9a-fA-F]{64}\z') { return & $result 'Refused' 'CandidateLauncherPinMissing' $null $null }
  $digest = $digest.ToUpperInvariant()
  if (-not [IO.File]::Exists($InstalledLauncherPath)) {
    if ($LauncherReinstallPlanned) { return & $result 'Compatible' 'LauncherReinstallPlanned' $digest $null }
    return & $result 'Refused' 'InstalledLauncherMissing' $digest $null
  }
  $installed = Get-CoordLauncherSha256 -Path $InstalledLauncherPath
  if ($installed -ieq $digest) { return & $result 'Compatible' 'LauncherUnchanged' $digest $installed }
  if ($LauncherReinstallPlanned) { return & $result 'Compatible' 'LauncherReinstallPlanned' $digest $installed }
  & $result 'Refused' 'LauncherChangeRequiresReinstall' $digest $installed
}

function Invoke-CoordLauncherAdmittedCheck {
  # Runs only after the version is custody-admitted, signer-checked and inventory-verified. The
  # admitted host is dot-sourced in THIS function's scope, so nothing it defines can replace the
  # launcher's own helpers; the full descriptor, custody and activation readers then run.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$AdmittedHostPath,
    [Parameter(Mandatory)][string]$CheckBindingPath,
    [Parameter(Mandatory)][string]$CheckDigest,
    [Parameter(Mandatory)][string]$CheckSigner,
    [Parameter(Mandatory)][string]$CheckVersion,
    [Parameter(Mandatory)][string]$CheckManifest,
    [Parameter(Mandatory)][string]$CheckRootModule,
    [Parameter(Mandatory)][string]$CheckVersionRoot
  )
  $refuse = { param($code, $inner) [pscustomobject]@{ Status = 'Refused'; Reason = $code; InnerReason = $inner } }
  . $AdmittedHostPath -BindingPath $CheckBindingPath -ExpectedBindingSha256 $CheckDigest -SignerThumbprint $CheckSigner
  try { $binding = Read-CoordResidentBinding -Path $CheckBindingPath -Digest $CheckDigest }
  catch { return & $refuse 'LauncherDescriptorRejected' $_.Exception.Message }
  try { $admission = Test-CoordResidentAdmission -Binding $binding -Digest $CheckDigest }
  catch {
    $inner = $_.Exception.Message
    if ($inner -cmatch '\AResidentActivation[A-Za-z]*\z') { return & $refuse 'LauncherActivationRefused' $inner }
    return & $refuse 'LauncherCustodyUnreadable' $inner
  }
  if ([string]$admission.Package.moduleVersion -cne $CheckVersion) { return & $refuse 'LauncherCustodyUnreadable' 'CustodyChangedDuringLaunch' }
  $name = Get-CoordLauncherModuleName
  $conflicting = @(Get-Module -Name $name -All | Where-Object { [IO.Path]::GetFullPath($_.Path) -ine $CheckRootModule })
  if ($conflicting.Count) { return & $refuse 'LauncherImportMismatch' 'ConflictingLoadedModule' }
  try { $module = Import-Module -Name $CheckManifest -PassThru -ErrorAction Stop } catch { return & $refuse 'LauncherImportMismatch' $_.Exception.Message }
  if ([string]$module.Version -cne $CheckVersion -or [IO.Path]::GetFullPath($module.Path) -ine $CheckRootModule) { return & $refuse 'LauncherImportMismatch' 'ImportedModuleIdentity' }
  try { Assert-CoordResidentPackage -Module $module -ModuleRoot $CheckVersionRoot -Package $admission.Package }
  catch { return & $refuse 'LauncherInventoryRejected' $_.Exception.Message }
  [pscustomobject]@{ Status = 'Admitted'; Reason = $null; InnerReason = $null }
}

function Resolve-CoordLauncherPackage {
  <#
  .SYNOPSIS
    Resolves and verifies the custody-admitted package; returns its host path or a refusal.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$LauncherBindingPath,
    [Parameter(Mandatory)][string]$LauncherDigest,
    [Parameter(Mandatory)][string]$LauncherCustodyPath,
    [Parameter(Mandatory)][string]$LauncherSigner,
    [Parameter(Mandatory)][string]$LauncherModulesRoot
  )
  $name = Get-CoordLauncherModuleName
  $refuse = { param($code, $inner) [pscustomobject]@{ Status = 'Refused'; Reason = $code; InnerReason = $inner; PackageVersion = $null; HostPath = $null; SignerThumbprint = $null } }
  if ($LauncherSigner -cnotmatch '\A[0-9a-fA-F]{40}\z') { return & $refuse 'LauncherSignerPinRequired' $null }
  if (-not [IO.Path]::IsPathFullyQualified($LauncherModulesRoot)) { return & $refuse 'LauncherModulesRootInvalid' $null }

  # 1. Descriptor and custody through this file's own minimal readers (H2). Nothing from any
  #    installed version folder has been read as code at this point.
  try { $binding = Read-CoordLauncherDescriptor -Path $LauncherBindingPath -Digest $LauncherDigest }
  catch {
    if ($_.Exception.Message -ceq 'LauncherDescriptorV2Required') { return & $refuse 'LauncherDescriptorV2Required' $null }
    return & $refuse 'LauncherDescriptorRejected' $_.Exception.Message
  }
  if ($binding.mode -cne 'Active') { return & $refuse 'LauncherDescriptorHeld' $binding.mode }
  if ([IO.Path]::GetFullPath($LauncherCustodyPath) -ine [IO.Path]::GetFullPath([string]$binding.custodyPath)) { return & $refuse 'LauncherCustodyPathMismatch' $null }
  try { $custody = Read-CoordLauncherCustody -Path $LauncherCustodyPath -CustodianSid $binding.windowsSid }
  catch { return & $refuse 'LauncherCustodyUnreadable' $_.Exception.Message }
  $version = $custody.Version
  # M3: custody's standing policy signer, when present, must equal the task's pin.
  if ($custody.PolicySigner -and $custody.PolicySigner -ine $LauncherSigner) { return & $refuse 'LauncherSignerPolicyMismatch' $null }

  # 2. Exactly one install of that version, and it must be the fixed AllUsers one.
  $allUsersRoot = [IO.Path]::GetFullPath((Join-Path $LauncherModulesRoot (Join-Path $name $version)))
  $searchRoots = @(@($LauncherModulesRoot) + @($env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ })) |
    ForEach-Object { [IO.Path]::GetFullPath($_).TrimEnd('\') } | Select-Object -Unique
  $installs = @($searchRoots | ForEach-Object { Join-Path $_ (Join-Path $name (Join-Path $version ($name + '.psd1'))) } | Where-Object { [IO.File]::Exists($_) } |
    ForEach-Object { [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($_)) } | Select-Object -Unique)
  if ($installs.Count -eq 0 -or $installs -inotcontains $allUsersRoot) { return & $refuse 'LauncherPackageNotInstalled' $version }
  if ($installs.Count -gt 1) { return & $refuse 'LauncherAmbiguousPackage' ($installs.Count.ToString() + ' installs of ' + $version) }

  # 3. Pinned signer on host, manifest and root module.
  $hostPath = Get-CoordLauncherHostPath -VersionRoot $allUsersRoot
  $manifest = Join-Path $allUsersRoot ($name + '.psd1')
  $rootModule = Join-Path $allUsersRoot ($name + '.psm1')
  foreach ($path in @($hostPath, $manifest, $rootModule)) {
    if (-not [IO.File]::Exists($path)) { return & $refuse 'LauncherPackageNotInstalled' ([IO.Path]::GetFileName($path)) }
    if (-not (Test-CoordLauncherSigner -Path $path -Thumbprint $LauncherSigner)) { return & $refuse 'LauncherSignerRejected' ([IO.Path]::GetFileName($path)) }
  }

  # 4. Custody's inventory, hashed before any file of that version is loaded.
  $required = @(($name + '.psd1'), ($name + '.psm1'), 'Resources/Resident/Invoke-CoordClerkResident.ps1', (Get-CoordLauncherBundledPath))
  try { Assert-CoordLauncherInventory -VersionRoot $allUsersRoot -Files $custody.Files -InventoryRule $custody.InventoryRule -RequiredPaths $required }
  catch { return & $refuse 'LauncherInventoryRejected' $_.Exception.Message }

  # 5. This fixed-path launcher must equal the admitted package's bundled launcher.
  if (-not (Test-CoordLauncherSelfAdmitted -Package $custody.Package)) { return & $refuse 'LauncherSelfNotAdmitted' $version }

  # 6. Only admitted, verified code from here on.
  $check = Invoke-CoordLauncherAdmittedCheck -AdmittedHostPath $hostPath -CheckBindingPath $LauncherBindingPath -CheckDigest $LauncherDigest `
    -CheckSigner $LauncherSigner -CheckVersion $version -CheckManifest $manifest -CheckRootModule $rootModule -CheckVersionRoot $allUsersRoot
  if ($check.Status -cne 'Admitted') { return & $refuse $check.Reason $check.InnerReason }

  [pscustomobject]@{ Status = 'Resolved'; Reason = 'CustodyAdmittedPackage'; InnerReason = $null; PackageVersion = $version; HostPath = $hostPath; SignerThumbprint = $LauncherSigner.ToUpperInvariant() }
}

function Invoke-CoordLauncherTarget {
  # Runs the admitted version's host in this process: dot-source, then call the function.
  # The host's own entry block is skipped when dot-sourced, and & is never used.
  [CmdletBinding(SupportsShouldProcess)]
  param([Parameter(Mandatory)][string]$TargetHostPath, [Parameter(Mandatory)][string]$TargetBindingPath,
    [Parameter(Mandatory)][string]$TargetDigest, [Parameter(Mandatory)][string]$TargetSignerThumbprint, [int]$TargetMaximumDrains = 0)
  . $TargetHostPath -BindingPath $TargetBindingPath -ExpectedBindingSha256 $TargetDigest -SignerThumbprint $TargetSignerThumbprint
  Invoke-CoordClerkResident -BindingPath $TargetBindingPath -ExpectedBindingSha256 $TargetDigest -MaximumDrains $TargetMaximumDrains -SignerThumbprint $TargetSignerThumbprint -WhatIf:$WhatIfPreference
}

function Write-CoordLauncherLog {
  # L3: best-effort PSFramework logging. Never fails the launch: a PSFramework that cannot load
  # (or none) simply means no log line, and the returned Launcher* reason remains the
  # authoritative record.
  [CmdletBinding()]
  param([Parameter(Mandatory)][ValidateSet('Error', 'Important')][string]$Level, [Parameter(Mandatory)][string]$Message)
  try {
    if (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue) {
      Write-PSFMessage -FunctionName 'Start-CoordClerkResident' -ModuleName (Get-CoordLauncherModuleName) -Level $Level -Message $Message
    }
  } catch { $null = $_ }
}

function Start-CoordClerkResident {
  <#
  .SYNOPSIS
    Starts the custody-admitted resident clerk host from a fixed, version-independent path.
  .DESCRIPTION
    Reads the pinned v2 descriptor and custody with this file's own minimal readers, verifies
    exactly one AllUsers install of the admitted version (pinned signer, then every custody
    inventory pin by hash) before loading anything from it, requires its own bytes to equal the
    admitted bundled launcher, and only then runs that version's readers and
    Invoke-CoordClerkResident in this process. A release changes only custody and the installed
    folders; the task action that calls this launcher stays identical.
  .PARAMETER BindingPath
    The approved CoordResidentStartup-v2 descriptor; passed through to the host.
  .PARAMETER ExpectedBindingSha256
    Exact descriptor bytes; passed through to the host.
  .PARAMETER CustodyPath
    The custody record; must equal the descriptor's custodyPath.
  .PARAMETER SignerThumbprint
    Pinned Authenticode signer of the admitted version's host, manifest and root module. Must
    equal custody's autoPackageAdmission.signer when custody has one; passed to the host.
  .PARAMETER MaximumDrains
    Optional caller drain limit; passed through to the host.
  .PARAMETER ModulesRoot
    AllUsers module root. Fixed in production; a parameter only so tests can use TestDrive.
  .OUTPUTS
    Refused with a Launcher* reason, or the host's own result with the resolved version.
  .EXAMPLE
    Start-CoordClerkResident -BindingPath $d -ExpectedBindingSha256 $h -CustodyPath $c -SignerThumbprint $t -WhatIf
  .NOTES
    Trust model and residual risk (review M2/M3; operator decision: development servers are
    trusted, so no checks against malicious file replacement: no ACL, owner, reparse-point or
    verify-then-use checks, and the execution policy is not a tamper control):
    - The launcher's self-check (step 5) is code checking itself and is defence in depth only.
    - The task runs with a deterministic -ExecutionPolicy, RemoteSigned by default (AllSigned
      only as an explicit choice), so local unsigned scripts such as PSFramework and the profile
      files load. It therefore does not protect this launcher file, which is protected only by
      its Program Files location. Residual risk: anyone who can write that file can replace it.
    - What does bind the loaded package to the release is the pinned signer on the Orchestration
      host, manifest and root module, plus custody's inventory hashes for every pinned file.
    - Verification and load are separate file reads; that window is accepted (no M5 measures).
    Activation and stop paths are not separate arguments: they travel inside the pinned
    descriptor, and the host re-reads them every loop.
  .LINK
    Invoke-CoordClerkResident.ps1
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)][string]$BindingPath,
    [Parameter(Mandatory)][string]$ExpectedBindingSha256,
    [Parameter(Mandatory)][string]$CustodyPath,
    [Parameter(Mandatory)][string]$SignerThumbprint,
    [ValidateRange(0, 2147483647)][int]$MaximumDrains = 0,
    [string]$ModulesRoot = 'C:\Program Files\PowerShell\Modules'
  )
  begin { $fn = 'Start-CoordClerkResident'; $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell' }
  process {
    try {
      $resolved = Resolve-CoordLauncherPackage -LauncherBindingPath $BindingPath -LauncherDigest $ExpectedBindingSha256 -LauncherCustodyPath $CustodyPath -LauncherSigner $SignerThumbprint -LauncherModulesRoot $ModulesRoot
    } catch {
      $resolved = [pscustomobject]@{ Status = 'Refused'; Reason = 'LauncherResolutionFailed'; InnerReason = $_.Exception.Message; PackageVersion = $null; HostPath = $null; SignerThumbprint = $null }
    }
    if ($resolved.Status -cne 'Resolved') {
      Write-CoordLauncherLog -Level Error -Message ('Resident launcher refused: {0} ({1}); the host was not started.' -f $resolved.Reason, $resolved.InnerReason)
      return $resolved
    }
    Write-CoordLauncherLog -Level Important -Message ('Resident launcher starting custody-admitted package {0}.' -f $resolved.PackageVersion)
    $result = Invoke-CoordLauncherTarget -TargetHostPath $resolved.HostPath -TargetBindingPath $BindingPath -TargetDigest $ExpectedBindingSha256 `
      -TargetSignerThumbprint $resolved.SignerThumbprint -TargetMaximumDrains $MaximumDrains -WhatIf:$WhatIfPreference
    [pscustomobject]@{ Status = 'Launched'; Reason = 'CustodyAdmittedPackage'; InnerReason = $null; PackageVersion = $resolved.PackageVersion; HostPath = $resolved.HostPath; SignerThumbprint = $resolved.SignerThumbprint; HostResult = $result }
  }
  end {}
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  if (-not $BindingPath -or -not $ExpectedBindingSha256 -or -not $CustodyPath -or -not $SignerThumbprint) { throw 'LauncherArgumentsRequired' }
  $launch = Start-CoordClerkResident -BindingPath $BindingPath -ExpectedBindingSha256 $ExpectedBindingSha256 -CustodyPath $CustodyPath -SignerThumbprint $SignerThumbprint -MaximumDrains $MaximumDrains -ModulesRoot $ModulesRoot
  $launch | ConvertTo-Json -Depth 20 -Compress
  if ($launch.Status -cne 'Launched') { exit 3 }
}

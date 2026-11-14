<#
.SYNOPSIS
  Signed launcher for Invoke-DatabaseMaintenanceWindow: imports every pinned module by absolute path, then runs one window step set.

.DESCRIPTION
  Invoked by the BuildMaster plan ATAPUtilitiesDb-MaintenanceWindow.otter in application 1005 (Design.r2 section 3, Design.r2-O3):

    pwsh -NoLogo -NonInteractive -ExecutionPolicy RemoteSigned -File "<this file>" -ModuleVersion <V>
         -DependencyPinPath <pin.json> -ExpectedDependencyPinSha256 <h> -Tier <T> -Mode <M>
         -BindingPath <binding.json> -ExpectedBindingSha256 <h>

  It runs profiled (no -NoProfile), so $global:settings resolves. In order it:
    1. requires its own path to be <modules root>\ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell\<V>\Resources\MaintenanceWindow\
       with no reparse point on any ancestor;
    2. reads the dependency pin (Coordination-database-maintenance-dependency-pin-v1) and checks its hash;
    3. for every pinned module, requires exactly <modules root>\<Name>\<Version>\<Name>.psd1 with that
       ModuleVersion and, when requireAtapSigner is true, Valid Authenticode by the release signer on the
       psd1 and psm1;
    4. refuses if any pinned module is already loaded from another folder;
    5. imports the modules in pin order by absolute psd1 path, so DatabasePackaging's RequiredModules are
       satisfied by exactly these copies, whatever the PSModulePath order;
    6. asserts each loaded ModuleBase equals its pinned folder;
    7. calls Invoke-DatabaseMaintenanceWindow and prints its result as JSON.
  Exit codes: 0 = Passed; 3 = Failed or any non-Passed status; 2 = refused before or during the run.

.NOTES
  Dual-purpose file: dot-sourcing it (unit tests) defines the functions only. The guard below runs the
  launcher only for 'pwsh -File' (invocation name not '.' or '&', and a .ps1 command path).
  AI assisted using Powershell.instructions.md as guidelines. DB-Runner-S1-Foundation.
#>
[CmdletBinding()]
param(
  [string]$ModuleVersion,
  [string]$DependencyPinPath,
  [string]$ExpectedDependencyPinSha256,
  [string]$Tier,
  [string]$Mode,
  [string]$BindingPath,
  [string]$ExpectedBindingSha256
)

function Get-MaintenanceLauncherModulesRoot {
  # The only trusted AllUsers root. A function so tests can mock it.
  [CmdletBinding()]
  param()
  'C:\Program Files\PowerShell\Modules'
}

function Get-MaintenanceLauncherSigner {
  # The ATAP release signing certificate thumbprint.
  [CmdletBinding()]
  param()
  '3B5E16C0498E1F5A92F95B9AA17FD6A40E9C406E'
}

function Get-MaintenanceLauncherSelfPath {
  [CmdletBinding()]
  param()
  $MyInvocation.MyCommand.ScriptBlock.File
}

function Assert-MaintenanceLauncherNoReparse {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path)
  for ($part = [IO.Path]::GetFullPath($Path); $part; $part = [IO.Path]::GetDirectoryName($part)) {
    if (Test-Path -LiteralPath $part) {
      $item = Get-Item -LiteralPath $part -Force
      if ($item.LinkType) { throw "MaintenanceLauncherReparsePathRefused|$part" }
    }
  }
}

function Assert-MaintenanceLauncherSelf {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$SelfPath, [Parameter(Mandatory)][string]$ModuleVersion)
  if ($ModuleVersion -cnotmatch '\A\d+\.\d+\.\d+\z') { throw 'MaintenanceLauncherModuleVersionInvalid' }
  $expected = [IO.Path]::GetFullPath((Join-Path (Get-MaintenanceLauncherModulesRoot) "ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell\$ModuleVersion\Resources\MaintenanceWindow\Start-DatabaseMaintenanceWindow.ps1"))
  if (-not [string]::Equals([IO.Path]::GetFullPath($SelfPath), $expected, [StringComparison]::OrdinalIgnoreCase)) { throw 'MaintenanceLauncherNotAtPinnedPath' }
  Assert-MaintenanceLauncherNoReparse -Path $SelfPath
}

function Read-MaintenanceLauncherDependencyPin {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$ExpectedSha256, [Parameter(Mandatory)][string]$ModuleVersion)
  if ($ExpectedSha256 -cnotmatch '\A[0-9a-fA-F]{64}\z' -or -not [IO.File]::Exists($Path)) { throw 'MaintenanceLauncherDependencyPinMissing' }
  $bytes = [IO.File]::ReadAllBytes($Path)
  if ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)) -ine $ExpectedSha256) { throw 'MaintenanceLauncherDependencyPinMismatch' }
  $pin = [Text.UTF8Encoding]::new($false, $true).GetString($bytes) | ConvertFrom-Json -Depth 10
  if ([string]$pin.kind -cne 'Coordination-database-maintenance-dependency-pin-v1') { throw 'MaintenanceLauncherDependencyPinInvalid|kind' }
  $modules = @($pin.modules)
  if ($modules.Count -lt 2) { throw 'MaintenanceLauncherDependencyPinInvalid|count' }
  $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($m in $modules) {
    if ([string]$m.name -cnotmatch '\A[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*\z' -or [string]$m.version -cnotmatch '\A\d+\.\d+\.\d+(\.\d+)?\z' -or
        $m.requireAtapSigner -isnot [bool] -or -not $seen.Add([string]$m.name)) { throw ('MaintenanceLauncherDependencyPinInvalid|' + [string]$m.name) }
  }
  if (-not $seen.Contains('ATAP.Utilities.DatabaseManagement.Powershell')) { throw 'MaintenanceLauncherDependencyPinInvalid|DatabaseManagementMissing' }
  $last = $modules[-1]
  if ([string]$last.name -cne 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell' -or [string]$last.version -cne $ModuleVersion -or $last.requireAtapSigner -ne $true) {
    throw 'MaintenanceLauncherDependencyPinInvalid|DatabasePackagingMustBeLast'
  }
  $modules
}

function Assert-MaintenanceLauncherDependency {
  [CmdletBinding()]
  param([Parameter(Mandatory)][object[]]$Modules)
  $root = Get-MaintenanceLauncherModulesRoot
  $signer = Get-MaintenanceLauncherSigner
  foreach ($m in $Modules) {
    $base = [IO.Path]::GetFullPath((Join-Path $root (Join-Path ([string]$m.name) ([string]$m.version))))
    $psd1 = Join-Path $base ([string]$m.name + '.psd1')
    if (-not [IO.File]::Exists($psd1)) { throw ('MaintenanceLauncherDependencyNotInstalled|' + [string]$m.name) }
    Assert-MaintenanceLauncherNoReparse -Path $psd1
    $declared = [string](Import-PowerShellDataFile -LiteralPath $psd1).ModuleVersion
    if ($declared -cne [string]$m.version) { throw ('MaintenanceLauncherDependencyVersionMismatch|' + [string]$m.name) }
    if ($m.requireAtapSigner) {
      foreach ($file in @($psd1, (Join-Path $base ([string]$m.name + '.psm1')))) {
        $sig = Get-AuthenticodeSignature -LiteralPath $file
        if ($sig.Status -ne 'Valid' -or $null -eq $sig.SignerCertificate -or $sig.SignerCertificate.Thumbprint -ine $signer) { throw ('MaintenanceLauncherDependencySignatureRejected|' + [string]$m.name) }
      }
    }
    foreach ($loaded in @(Get-Module -Name ([string]$m.name) -All)) {
      if (-not [string]::Equals([IO.Path]::GetFullPath([string]$loaded.ModuleBase).TrimEnd('\'), $base.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
        throw ('MaintenanceLauncherForeignCopyLoaded|' + [string]$m.name)
      }
    }
  }
}

function Import-MaintenanceLauncherDependencies {
  [CmdletBinding()]
  param([Parameter(Mandatory)][object[]]$Modules)
  $root = Get-MaintenanceLauncherModulesRoot
  foreach ($m in $Modules) {
    $base = [IO.Path]::GetFullPath((Join-Path $root (Join-Path ([string]$m.name) ([string]$m.version))))
    $imported = Import-Module -Name (Join-Path $base ([string]$m.name + '.psd1')) -PassThru -DisableNameChecking -ErrorAction Stop
    $loaded = @(Get-Module -Name ([string]$m.name) -All)
    if ($loaded.Count -ne 1 -or -not [string]::Equals([IO.Path]::GetFullPath([string]$loaded[0].ModuleBase).TrimEnd('\'), $base.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase) -or
        [string]$imported.Version -cne ([version][string]$m.version).ToString()) {
      throw ('MaintenanceLauncherImportMismatch|' + [string]$m.name)
    }
  }
}

function Invoke-MaintenanceLauncher {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$SelfPath, [Parameter(Mandatory)][string]$ModuleVersion,
    [Parameter(Mandatory)][string]$DependencyPinPath, [Parameter(Mandatory)][string]$ExpectedDependencyPinSha256,
    [Parameter(Mandatory)][string]$Tier, [Parameter(Mandatory)][string]$Mode,
    [Parameter(Mandatory)][string]$BindingPath, [Parameter(Mandatory)][string]$ExpectedBindingSha256
  )
  Assert-MaintenanceLauncherSelf -SelfPath $SelfPath -ModuleVersion $ModuleVersion
  $modules = Read-MaintenanceLauncherDependencyPin -Path $DependencyPinPath -ExpectedSha256 $ExpectedDependencyPinSha256 -ModuleVersion $ModuleVersion
  Assert-MaintenanceLauncherDependency -Modules $modules
  Import-MaintenanceLauncherDependencies -Modules $modules
  $command = Get-Command -Name Invoke-DatabaseMaintenanceWindow -CommandType Function -ErrorAction Stop
  $expectedBase = [IO.Path]::GetFullPath((Join-Path (Get-MaintenanceLauncherModulesRoot) "ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell\$ModuleVersion")).TrimEnd('\')
  if ($null -eq $command.Module -or -not [string]::Equals([IO.Path]::GetFullPath([string]$command.Module.ModuleBase).TrimEnd('\'), $expectedBase, [StringComparison]::OrdinalIgnoreCase)) { throw 'MaintenanceLauncherEntryPointNotPinned' }
  & $command -Tier $Tier -Mode $Mode -BindingPath $BindingPath -ExpectedBindingSha256 $ExpectedBindingSha256 -Confirm:$false
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&' -and $PSCommandPath -like '*.ps1') {
  try {
    if (-not $ModuleVersion -or -not $DependencyPinPath -or -not $ExpectedDependencyPinSha256 -or -not $Tier -or -not $Mode -or -not $BindingPath -or -not $ExpectedBindingSha256) { throw 'MaintenanceLauncherArgumentsRequired' }
    $outcome = Invoke-MaintenanceLauncher -SelfPath $PSCommandPath -ModuleVersion $ModuleVersion -DependencyPinPath $DependencyPinPath -ExpectedDependencyPinSha256 $ExpectedDependencyPinSha256 `
      -Tier $Tier -Mode $Mode -BindingPath $BindingPath -ExpectedBindingSha256 $ExpectedBindingSha256
    $outcome | ConvertTo-Json -Depth 6 -Compress
    if ([string]$outcome.Status -cne 'Passed') { exit 3 }
    exit 0
  } catch {
    $code = ([string]$_.Exception.Message).Split('|')[0]
    if ($code -cnotmatch '\AMaintenance(Launcher|Window)[A-Za-z]+\z') { $code = 'MaintenanceLauncherUnexpectedFailure' }
    [ordered]@{ Status = 'Refused'; Code = $code } | ConvertTo-Json -Compress
    exit 2
  }
}

#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
# DB-Runner-S1-Foundation: Start-DatabaseMaintenanceWindow.ps1 launcher. Dot-sourced, so the -File guard does not run.
# Fake modules live under TestDrive; Get-MaintenanceLauncherModulesRoot is mocked to that root.

BeforeAll {
  $script:launcher = (Join-Path $PSScriptRoot '..\..\Resources\MaintenanceWindow\Start-DatabaseMaintenanceWindow.ps1' | Resolve-Path).Path
  . $script:launcher

  function New-FakeModule {
    param([string]$Root, [string]$Name, [string]$Version)
    $base = Join-Path $Root (Join-Path $Name $Version)
    $null = New-Item -ItemType Directory -Path $base -Force
    "function Get-$($Name.Replace('.', ''))Marker { '$Version' }" | Set-Content -LiteralPath (Join-Path $base "$Name.psm1")
    "@{ RootModule = '$Name.psm1'; ModuleVersion = '$Version'; GUID = '$([guid]::NewGuid())'; FunctionsToExport = @('*') }" | Set-Content -LiteralPath (Join-Path $base "$Name.psd1")
    $base
  }
  function New-Pin {
    param([object[]]$Modules, [string]$Kind = 'Coordination-database-maintenance-dependency-pin-v1')
    $path = Join-Path $TestDrive ('pin-' + [guid]::NewGuid().ToString('N') + '.json')
    [IO.File]::WriteAllText($path, ([ordered]@{ kind = $Kind; modules = $Modules } | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
    [pscustomobject]@{ Path = $path; Sha256 = (Get-FileHash -LiteralPath $path).Hash }
  }
  $script:dm = [ordered]@{ name = 'ATAP.Utilities.DatabaseManagement.Powershell'; version = '0.1.26'; requireAtapSigner = $true }
  $script:dp = [ordered]@{ name = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell'; version = '0.1.4'; requireAtapSigner = $true }
}

Describe 'Launcher self-location' -Tag 'Unit', 'MaintenanceWindow' {
  It 'accepts only <root>\DatabasePackaging\<V>\Resources\MaintenanceWindow\Start-DatabaseMaintenanceWindow.ps1' {
    $root = Join-Path $TestDrive 'Mods'
    Mock Get-MaintenanceLauncherModulesRoot { $root }
    $self = Join-Path $root 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell\0.1.4\Resources\MaintenanceWindow\Start-DatabaseMaintenanceWindow.ps1'
    $null = New-Item -ItemType Directory -Path (Split-Path $self) -Force; 'x' | Set-Content -LiteralPath $self
    { Assert-MaintenanceLauncherSelf -SelfPath $self -ModuleVersion '0.1.4' } | Should -Not -Throw
    { Assert-MaintenanceLauncherSelf -SelfPath $self -ModuleVersion '0.1.5' } | Should -Throw 'MaintenanceLauncherNotAtPinnedPath'
    { Assert-MaintenanceLauncherSelf -SelfPath $script:launcher -ModuleVersion '0.1.4' } | Should -Throw 'MaintenanceLauncherNotAtPinnedPath'
    { Assert-MaintenanceLauncherSelf -SelfPath $self -ModuleVersion '0.1.4-pre' } | Should -Throw 'MaintenanceLauncherModuleVersionInvalid'
  }
  It 'pins the production module root and the ATAP release signer' {
    Get-MaintenanceLauncherModulesRoot | Should -BeExactly 'C:\Program Files\PowerShell\Modules'
    Get-MaintenanceLauncherSigner | Should -BeExactly '3B5E16C0498E1F5A92F95B9AA17FD6A40E9C406E'
  }
}

Describe 'Dependency pin file' -Tag 'Unit', 'MaintenanceWindow' {
  It 'accepts a pin that ends with DatabasePackaging at the launcher version' {
    $p = New-Pin -Modules @([ordered]@{ name = 'PSFramework'; version = '1.14.457'; requireAtapSigner = $false }, $script:dm, $script:dp)
    @(Read-MaintenanceLauncherDependencyPin -Path $p.Path -ExpectedSha256 $p.Sha256 -ModuleVersion '0.1.4').Count | Should -Be 3
  }
  It 'refuses <Case>' -ForEach @(
    @{ Case = 'a hash mismatch'; Modules = $null; Kind = 'Coordination-database-maintenance-dependency-pin-v1'; BadHash = $true; Version = '0.1.4'; Code = 'MaintenanceLauncherDependencyPinMismatch' }
    @{ Case = 'another kind'; Modules = $null; Kind = 'Other'; BadHash = $false; Version = '0.1.4'; Code = 'MaintenanceLauncherDependencyPinInvalid|kind' }
    @{ Case = 'a launcher version mismatch'; Modules = $null; Kind = 'Coordination-database-maintenance-dependency-pin-v1'; BadHash = $false; Version = '0.1.5'; Code = 'MaintenanceLauncherDependencyPinInvalid|DatabasePackagingMustBeLast' }
  ) {
    $p = New-Pin -Modules @($script:dm, $script:dp) -Kind $Kind
    $h = if ($BadHash) { 'F' * 64 } else { $p.Sha256 }
    { Read-MaintenanceLauncherDependencyPin -Path $p.Path -ExpectedSha256 $h -ModuleVersion $Version } | Should -Throw "$Code*"
  }
  It 'refuses a pin without DatabaseManagement' {
    $p = New-Pin -Modules @([ordered]@{ name = 'PSFramework'; version = '1.14.457'; requireAtapSigner = $false }, $script:dp)
    { Read-MaintenanceLauncherDependencyPin -Path $p.Path -ExpectedSha256 $p.Sha256 -ModuleVersion '0.1.4' } | Should -Throw 'MaintenanceLauncherDependencyPinInvalid|DatabaseManagementMissing'
  }
  It 'refuses DatabasePackaging that is not last' {
    $p = New-Pin -Modules @($script:dp, $script:dm)
    { Read-MaintenanceLauncherDependencyPin -Path $p.Path -ExpectedSha256 $p.Sha256 -ModuleVersion '0.1.4' } | Should -Throw 'MaintenanceLauncherDependencyPinInvalid|DatabasePackagingMustBeLast'
  }
  It 'refuses a duplicate module' {
    $p = New-Pin -Modules @($script:dm, $script:dm, $script:dp)
    { Read-MaintenanceLauncherDependencyPin -Path $p.Path -ExpectedSha256 $p.Sha256 -ModuleVersion '0.1.4' } | Should -Throw 'MaintenanceLauncherDependencyPinInvalid|ATAP.Utilities.DatabaseManagement.Powershell'
  }
}

Describe 'Dependency checks and absolute-path import' -Tag 'Unit', 'MaintenanceWindow' {
  BeforeEach {
    $script:root = Join-Path $TestDrive ('Mods' + [guid]::NewGuid().ToString('N').Substring(0, 6))
    $script:names = @('Lfx.Alpha', 'Lfx.Beta')
    foreach ($n in $script:names) { $null = New-FakeModule -Root $script:root -Name $n -Version '1.2.3' }
    Mock Get-MaintenanceLauncherModulesRoot { $script:root }
    $script:mods = @([pscustomobject]@{ name = 'Lfx.Alpha'; version = '1.2.3'; requireAtapSigner = $false }, [pscustomobject]@{ name = 'Lfx.Beta'; version = '1.2.3'; requireAtapSigner = $true })
  }
  AfterEach { foreach ($n in $script:names) { Remove-Module $n -Force -ErrorAction SilentlyContinue } }

  It 'refuses an ATAP-signed module whose signature is not the release signer' {
    Mock Get-AuthenticodeSignature { [pscustomobject]@{ Status = 'NotSigned'; SignerCertificate = $null } }
    { Assert-MaintenanceLauncherDependency -Modules $script:mods } | Should -Throw 'MaintenanceLauncherDependencySignatureRejected|Lfx.Beta'
  }
  It 'passes when the signer matches, then imports each module from its pinned folder' {
    Mock Get-AuthenticodeSignature { [pscustomobject]@{ Status = 'Valid'; SignerCertificate = [pscustomobject]@{ Thumbprint = '3B5E16C0498E1F5A92F95B9AA17FD6A40E9C406E' } } }
    { Assert-MaintenanceLauncherDependency -Modules $script:mods } | Should -Not -Throw
    Import-MaintenanceLauncherDependencies -Modules $script:mods
    foreach ($n in $script:names) {
      (Get-Module -Name $n).ModuleBase | Should -Be (Join-Path $script:root "$n\1.2.3")
    }
  }
  It 'refuses a module that is not installed at its pinned version' {
    $bad = @([pscustomobject]@{ name = 'Lfx.Alpha'; version = '9.9.9'; requireAtapSigner = $false })
    { Assert-MaintenanceLauncherDependency -Modules $bad } | Should -Throw 'MaintenanceLauncherDependencyNotInstalled|Lfx.Alpha'
  }
  It 'refuses a manifest whose ModuleVersion differs from its folder' {
    $base = Join-Path $script:root 'Lfx.Alpha\1.2.3'
    "@{ RootModule = 'Lfx.Alpha.psm1'; ModuleVersion = '1.2.4'; GUID = '$([guid]::NewGuid())' }" | Set-Content -LiteralPath (Join-Path $base 'Lfx.Alpha.psd1')
    { Assert-MaintenanceLauncherDependency -Modules @($script:mods[0]) } | Should -Throw 'MaintenanceLauncherDependencyVersionMismatch|Lfx.Alpha'
  }
  It 'refuses when a pinned module is already loaded from another folder' {
    $other = New-FakeModule -Root (Join-Path $TestDrive ('Other' + [guid]::NewGuid().ToString('N').Substring(0, 6))) -Name 'Lfx.Alpha' -Version '1.2.3'
    Import-Module (Join-Path $other 'Lfx.Alpha.psd1') -Force
    { Assert-MaintenanceLauncherDependency -Modules @($script:mods[0]) } | Should -Throw 'MaintenanceLauncherForeignCopyLoaded|Lfx.Alpha'
  }
}

Describe 'Launcher process entry' -Tag 'Unit', 'MaintenanceWindow' {
  It 'does not run when dot-sourced (the functions exist, nothing exited)' {
    Get-Command Invoke-MaintenanceLauncher -CommandType Function | Should -Not -BeNullOrEmpty
  }
  It 'refuses with exit code 2 and MaintenanceLauncherArgumentsRequired when run with -File and no arguments' {
    $out = & 'C:\Program Files\PowerShell\7\pwsh.exe' -NoLogo -NonInteractive -File $script:launcher
    $LASTEXITCODE | Should -Be 2
    (($out | Select-Object -Last 1) | ConvertFrom-Json).Code | Should -BeExactly 'MaintenanceLauncherArgumentsRequired'
  }
  It 'refuses with exit code 2 and MaintenanceLauncherNotAtPinnedPath when run from a source tree' {
    $out = & 'C:\Program Files\PowerShell\7\pwsh.exe' -NoLogo -NonInteractive -File $script:launcher -ModuleVersion '0.1.4' -DependencyPinPath 'C:\x.json' -ExpectedDependencyPinSha256 ('A' * 64) `
      -Tier Development -Mode PrecheckOnly -BindingPath 'C:\b.json' -ExpectedBindingSha256 ('A' * 64)
    $LASTEXITCODE | Should -Be 2
    (($out | Select-Object -Last 1) | ConvertFrom-Json).Code | Should -BeExactly 'MaintenanceLauncherNotAtPinnedPath'
  }
}

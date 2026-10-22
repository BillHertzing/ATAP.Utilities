#Requires -Modules @{ModuleName='Pester';ModuleVersion='6.2.0'}

BeforeDiscovery {
  $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
  try {
    $script:skipNonadminImport=([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } finally {$identity.Dispose()}
}

BeforeAll {
  $script:parityRoot=(Get-Item $PSScriptRoot).Parent.Parent.FullName
  $script:updaterPath=Join-Path $parityRoot 'public/Update-HostPackageFromDriftReport.ps1'
  $script:adminPath=Join-Path $parityRoot 'private/Test-ParityAdministrator.ps1'
  $script:parityManifest=Join-Path $parityRoot 'ATAP.Utilities.SystemParityMonitor.PowerShell.psd1'
  $script:proofRoot=Join-Path ([IO.Path]::GetTempPath()) ('PE_'+[guid]::NewGuid().ToString('N'))
  [void][IO.Directory]::CreateDirectory($proofRoot)
}

Describe 'Parity non-elevated import contract' -Tag Unit {
  It 'imports the real source module without elevation and exports the updater only' -Skip:$script:skipNonadminImport {
    $module=Import-Module -Name $parityManifest -Force -PassThru -ErrorAction Stop
    try {
      (& $module { Test-ParityAdministrator }) | Should -BeFalse
      $module.ExportedFunctions.Keys | Should -Contain 'Update-HostPackageFromDriftReport'
      $module.ExportedFunctions.Keys | Should -Not -Contain 'Test-ParityAdministrator'
      $missingReport=Join-Path $proofRoot 'never-created-source.md'
      Test-Path -LiteralPath $missingReport | Should -BeFalse
      foreach($preview in @($false,$true)){
        {& $module {param($path,$preview) Update-HostPackageFromDriftReport -ReportPath $path -WhatIf:$preview} $missingReport $preview} | Should -Throw '*requires Administrator rights*'
      }
    } finally { Remove-Module -ModuleInfo $module -Force }
  }

  It 'imports the actual compiled module without elevation and keeps the predicate private' -Skip:$script:skipNonadminImport {
    $builder=Join-Path (Split-Path -Parent $parityRoot) 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell/public/Build-PSModulePsm1.ps1'
    . $builder
    $generated=Join-Path $proofRoot 'package'
    [void][IO.Directory]::CreateDirectory($generated)
    $psm1=Join-Path $generated 'ATAP.Utilities.SystemParityMonitor.PowerShell.psm1'
    Build-PSModulePsm1 -ModuleRoot $parityRoot -OutputPath $psm1 -Confirm:$false | Out-Null
    Copy-Item -LiteralPath $parityManifest -Destination $generated
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($psm1,[ref]$tokens,[ref]$errors)
    @($errors) | Should -HaveCount 0
    $ast.ScriptRequirements.IsElevationRequired | Should -BeFalse
    $module=Import-Module -Name (Join-Path $generated 'ATAP.Utilities.SystemParityMonitor.PowerShell.psd1') -Force -PassThru -ErrorAction Stop
    try {
      (& $module { Test-ParityAdministrator }) | Should -BeFalse
      $module.ExportedFunctions.Keys | Should -Contain 'Update-HostPackageFromDriftReport'
      $module.ExportedFunctions.Keys | Should -Not -Contain 'Test-ParityAdministrator'
      (Get-Command Update-HostPackageFromDriftReport).Module.ModuleBase | Should -Be $generated
      $missingReport=Join-Path $proofRoot 'never-created-compiled.md'
      Test-Path -LiteralPath $missingReport | Should -BeFalse
      foreach($preview in @($false,$true)){
        {& $module {param($path,$preview) Update-HostPackageFromDriftReport -ReportPath $path -WhatIf:$preview} $missingReport $preview} | Should -Throw '*requires Administrator rights*'
      }
    } finally { Remove-Module -ModuleInfo $module -Force }
  }
}

Describe 'Update-HostPackageFromDriftReport administrator entry contract' -Tag Unit {
  BeforeAll {
    . $adminPath
    . $updaterPath
  }
  BeforeEach {
    # The missing-helper case deliberately removes this function. Restore its
    # real definition before each mock so later cases remain independent.
    . $adminPath
    Mock Write-PSFMessage { }
    Mock Test-ParityAdministrator { $false }
    Mock Test-Path { throw 'Unexpected report access' }
    Mock Get-Content { throw 'Unexpected report read' }
    Mock Get-SecretATAP { throw 'Unexpected credential lookup' }
    Mock Invoke-Command { throw 'Unexpected remoting' }
  }

  It 'denies a nonadministrator before effects, including WhatIf=<Preview>' -ForEach @(
    @{Preview=$false},@{Preview=$true}
  ) {
    {Update-HostPackageFromDriftReport -ReportPath 'not-read.md' -WhatIf:$Preview} | Should -Throw '*requires Administrator rights*'
    Should -Invoke Test-ParityAdministrator -Times 1 -Exactly -ParameterFilter {$ErrorAction -eq 'Stop'}
    Should -Invoke Write-PSFMessage -Times 0 -Exactly
    Should -Invoke Test-Path -Times 0 -Exactly
    Should -Invoke Get-Content -Times 0 -Exactly
    Should -Invoke Get-SecretATAP -Times 0 -Exactly
    Should -Invoke Invoke-Command -Times 0 -Exactly
  }

  It 'rejects a predicate exception before effects' {
    Mock Test-ParityAdministrator { throw 'synthetic token lookup failed' }
    {Update-HostPackageFromDriftReport -ReportPath 'not-read.md'} | Should -Throw '*synthetic token lookup failed*'
    Should -Invoke Write-PSFMessage -Times 0 -Exactly
    Should -Invoke Test-Path -Times 0 -Exactly
    Should -Invoke Get-Content -Times 0 -Exactly
    Should -Invoke Get-SecretATAP -Times 0 -Exactly
    Should -Invoke Invoke-Command -Times 0 -Exactly
  }

  It 'rejects a nonterminating predicate error instead of accepting a later true value' {
    Mock Test-ParityAdministrator { Write-Error 'synthetic token error'; $true }
    {Update-HostPackageFromDriftReport -ReportPath 'not-read.md'} | Should -Throw '*synthetic token error*'
    Should -Invoke Write-PSFMessage -Times 0 -Exactly
    Should -Invoke Test-Path -Times 0 -Exactly
    Should -Invoke Get-Content -Times 0 -Exactly
    Should -Invoke Get-SecretATAP -Times 0 -Exactly
    Should -Invoke Invoke-Command -Times 0 -Exactly
  }

  It 'rejects an absent predicate before effects' {
    $predicate=${function:Test-ParityAdministrator}
    Remove-Item Function:\Test-ParityAdministrator
    try {
      {Update-HostPackageFromDriftReport -ReportPath 'not-read.md'} | Should -Throw
      Should -Invoke Write-PSFMessage -Times 0 -Exactly
      Should -Invoke Test-Path -Times 0 -Exactly
      Should -Invoke Get-Content -Times 0 -Exactly
      Should -Invoke Get-SecretATAP -Times 0 -Exactly
      Should -Invoke Invoke-Command -Times 0 -Exactly
    } finally {${function:Test-ParityAdministrator}=$predicate}
  }

  It 'lets an authorized token parse an empty report without remediation' {
    Mock Test-ParityAdministrator { $true }
    Mock Test-Path { $true }
    Mock Get-Content { @('# Parity Drift Report: fixture-a vs fixture-b','## Undeclared Drift') }
    @(Update-HostPackageFromDriftReport -ReportPath 'synthetic.md') | Should -HaveCount 0
    Should -Invoke Test-ParityAdministrator -Times 1 -Exactly
    Should -Invoke Get-Content -Times 1 -Exactly -ParameterFilter {$LiteralPath -eq 'synthetic.md'}
    Should -Invoke Get-SecretATAP -Times 0 -Exactly
    Should -Invoke Invoke-Command -Times 0 -Exactly
  }

  It 'plans authorized remote drift under WhatIf without credential or remoting calls' {
    Mock Test-ParityAdministrator { $true }
    Mock Test-Path { $true }
    Mock Get-Content { @('# Parity Drift Report: fixture-remote-a vs fixture-remote-b','## Undeclared Drift',"- PackageManager/Machine/Chocolatey/example: fixture-remote-a='1.0.0' vs fixture-remote-b='2.0.0'") }
    $r=@(Update-HostPackageFromDriftReport -ReportPath 'synthetic.md' -TargetHosts fixture-remote-a -WhatIf)
    $r | Should -HaveCount 1
    $r[0].Action | Should -Be 'Skipped'
    $r[0].TargetVersion | Should -Be '2.0.0'
    $r[0].Success | Should -BeTrue
    Should -Invoke Get-SecretATAP -Times 0 -Exactly
    Should -Invoke Invoke-Command -Times 0 -Exactly
  }
}

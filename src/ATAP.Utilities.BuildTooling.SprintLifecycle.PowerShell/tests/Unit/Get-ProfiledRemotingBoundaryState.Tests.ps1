BeforeAll {
  if (Get-Module -ListAvailable -Name PSFramework) {
    Import-Module PSFramework -ErrorAction SilentlyContinue
  }

  $script:moduleRoot = Split-Path -Path $PSScriptRoot -Parent | Split-Path -Parent
  $script:helperPath = Join-Path $script:moduleRoot 'private\Get-ProfiledRemotingBoundaryState.ps1'
  . $script:helperPath
}

Describe 'Get-ProfiledRemotingBoundaryState PowerShell 7 plug-in health' -Tag 'Unit' {
  BeforeEach {
    $script:fixturePsHome = Join-Path $TestDrive 'PowerShell\7'
    New-Item -ItemType Directory -Path $script:fixturePsHome -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $script:fixturePsHome 'pwrshplugin.dll') -Force | Out-Null
    Mock Get-PSSessionConfiguration {
      [PSCustomObject]@{
        Name = 'PowerShell.7'
        Enabled = $true
        Filename = '%windir%\system32\PowerShell\7.6.3\pwrshplugin.dll'
      }
    }
  }

  It 'detects an enabled configuration whose registered plug-in is missing' {
    $state = Get-ProfiledRemotingBoundaryState -PowerShellHome $script:fixturePsHome

    $state.BrokenPowerShell7ConfigurationCount | Should -Be 1
    $state.BrokenPowerShell7Configurations[0].Name | Should -Be 'PowerShell.7'
    $state.CanonicalPluginPresent | Should -BeTrue
  }

  It 'resolves the canonical plug-in from the unversioned PowerShell home' {
    $state = Get-ProfiledRemotingBoundaryState -PowerShellHome $script:fixturePsHome

    $state.CanonicalPluginPath | Should -Be (Join-Path $script:fixturePsHome 'pwrshplugin.dll')
    $state.CanonicalPluginPath | Should -Not -Match 'PowerShell\\\d+\.\d+\.\d+\\pwrshplugin\.dll$'
  }

  It 'guides repair of only the existing Filename value and WinRM restart' {
    $state = Get-ProfiledRemotingBoundaryState -PowerShellHome $script:fixturePsHome
    $guidance = $state.RepairGuidance -join "`n"

    $guidance | Should -Match "Set-Item -LiteralPath 'WSMan:\\localhost\\Plugin\\PowerShell\.7\\Filename'"
    $guidance | Should -Match ([regex]::Escape($state.CanonicalPluginPath))
    $guidance | Should -Match 'Restart-Service -Name WinRM -Force'
    $guidance | Should -Not -Match 'Enable-PSRemoting|Register-PSSessionConfiguration|New-Item'
  }

  It 'does not classify a disabled stale configuration as an active break' {
    Mock Get-PSSessionConfiguration {
      [PSCustomObject]@{
        Name = 'PowerShell.7'
        Enabled = 'False'
        Filename = '%windir%\system32\PowerShell\7.6.3\pwrshplugin.dll'
      }
    }

    $state = Get-ProfiledRemotingBoundaryState -PowerShellHome $script:fixturePsHome

    $state.BrokenPowerShell7ConfigurationCount | Should -Be 0
    $state.RepairGuidance | Should -BeNullOrEmpty
  }
}

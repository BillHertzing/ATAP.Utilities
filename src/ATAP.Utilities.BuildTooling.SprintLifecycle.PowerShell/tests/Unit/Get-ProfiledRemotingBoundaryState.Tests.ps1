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
    $script:missingRegisteredPluginPath = Join-Path $TestDrive 'missing\pwrshplugin.dll'
    Test-Path -LiteralPath $script:missingRegisteredPluginPath -PathType Leaf | Should -BeFalse

    $missingRegisteredPluginPath = $script:missingRegisteredPluginPath
    $script:brokenConfigurationProvider = {
      [PSCustomObject]@{
        Name = 'PowerShell.7'
        Enabled = $true
        Filename = $missingRegisteredPluginPath
      }
    }.GetNewClosure()
  }

  It 'detects an enabled configuration whose registered plug-in is missing' {
    $state = Get-ProfiledRemotingBoundaryState `
      -PowerShellHome $script:fixturePsHome `
      -SessionConfigurationProvider $script:brokenConfigurationProvider

    $state.BrokenPowerShell7ConfigurationCount | Should -Be 1
    $state.BrokenPowerShell7Configurations[0].Name | Should -Be 'PowerShell.7'
    $state.CanonicalPluginPresent | Should -BeTrue
  }

  It 'resolves the canonical plug-in from the unversioned PowerShell home' {
    $state = Get-ProfiledRemotingBoundaryState `
      -PowerShellHome $script:fixturePsHome `
      -SessionConfigurationProvider $script:brokenConfigurationProvider

    $state.CanonicalPluginPath | Should -Be (Join-Path $script:fixturePsHome 'pwrshplugin.dll')
    $state.CanonicalPluginPath | Should -Not -Match 'PowerShell\\\d+\.\d+\.\d+\\pwrshplugin\.dll$'
  }

  It 'guides repair of only the existing Filename value and WinRM restart' {
    $state = Get-ProfiledRemotingBoundaryState `
      -PowerShellHome $script:fixturePsHome `
      -SessionConfigurationProvider $script:brokenConfigurationProvider
    $guidance = $state.RepairGuidance -join "`n"

    $guidance | Should -Match "Set-Item -LiteralPath 'WSMan:\\localhost\\Plugin\\PowerShell\.7\\Filename'"
    $guidance | Should -Match ([regex]::Escape($state.CanonicalPluginPath))
    $guidance | Should -Match 'Restart-Service -Name WinRM -Force'
    $guidance | Should -Not -Match 'Enable-PSRemoting|Register-PSSessionConfiguration|New-Item'
  }

  It 'does not classify a disabled stale configuration as an active break' {
    $missingRegisteredPluginPath = $script:missingRegisteredPluginPath
    $disabledConfigurationProvider = {
      [PSCustomObject]@{
        Name = 'PowerShell.7'
        Enabled = 'False'
        Filename = $missingRegisteredPluginPath
      }
    }.GetNewClosure()

    $state = Get-ProfiledRemotingBoundaryState `
      -PowerShellHome $script:fixturePsHome `
      -SessionConfigurationProvider $disabledConfigurationProvider

    $state.BrokenPowerShell7ConfigurationCount | Should -Be 0
    $state.RepairGuidance | Should -BeNullOrEmpty
  }

  It 'keeps the production default provider bound to the real remoting command' {
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
      $script:helperPath,
      [ref]$tokens,
      [ref]$parseErrors
    )

    $parseErrors | Should -BeNullOrEmpty
    $providerCommands = @($ast.FindAll({
          param($node)
          $node -is [System.Management.Automation.Language.CommandAst] -and
          $node.GetCommandName() -eq 'Get-PSSessionConfiguration'
        }, $true))
    $providerCommands.Count | Should -Be 1
    $providerCommands[0].Extent.Text | Should -Match '-ErrorAction\s+Stop'
  }

  It 'reports an injected provider failure as an unsuccessful probe' {
    $state = Get-ProfiledRemotingBoundaryState `
      -PowerShellHome $script:fixturePsHome `
      -SessionConfigurationProvider { throw 'fixture provider failed closed' }

    $state.ProbeSucceeded | Should -BeFalse
    $state.RemotingSurfacePresent | Should -BeFalse
    $state.ConfigurationCount | Should -Be 0
    $state.ProbeError | Should -Be 'fixture provider failed closed'
  }
}

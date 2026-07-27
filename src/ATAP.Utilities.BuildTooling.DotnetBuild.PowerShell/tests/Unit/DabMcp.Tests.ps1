#Requires -Module Pester

BeforeAll {
  $script:moduleRoot = (Join-Path $PSScriptRoot '..\..' | Resolve-Path).Path
  $script:moduleName = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
  $script:manifestPath = Join-Path $script:moduleRoot "$script:moduleName.psd1"
  Remove-Module $script:moduleName -Force -ErrorAction SilentlyContinue
  Import-Module -Name $script:manifestPath -Force -ErrorAction Stop
}

Describe 'DAB MCP helpers' -Tag 'Unit' {
  It 'uses deterministic BWS secret names for each SQL tier' {
    InModuleScope $script:moduleName {
      Resolve-DabMcpConnectionStringSecretName -Tier 'Production' -DatabaseHost 'utat01' |
        Should -BeExactly 'dbConnectionString.ATAPUtilities.utat01.Production'
      Resolve-DabMcpConnectionStringSecretName -Tier 'Exp' -DatabaseHost 'utat01' -UserName 'whertzing' |
        Should -BeExactly 'dbConnectionString.ATAPUtilities.utat01.Exp.whertzing'
    }
  }

  It 'does not install DAB when WhatIf is specified' {
    $result = Install-DabGlobalTool -Version '2.0.9' -WhatIf
    $result.WhatIf | Should -BeTrue
    $result.Action | Should -BeIn @('install', 'update')
  }

  It 'does not create a DAB configuration when WhatIf is specified' {
    $configPath = Join-Path $TestDrive 'dab-config.json'
    $result = Initialize-DabMcpConfiguration -ConfigPath $configPath -WhatIf
    $result.WhatIf | Should -BeTrue
    Test-Path -LiteralPath $configPath | Should -BeFalse
  }
}

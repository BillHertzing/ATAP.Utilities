#requires -Modules Pester

Describe 'BuildTooling Secrets child module contract' {
  BeforeAll {
    $script:moduleName = 'ATAP.Utilities.BuildTooling.Secrets.PowerShell'
    $script:modulePath = Join-Path $PSScriptRoot '..\..\ATAP.Utilities.BuildTooling.Secrets.PowerShell.psd1'
    $script:expectedFunctions = @(
      'Get-BWSAccessToken', 'Get-DbConnectionStringSecretDescriptor', 'Get-SecretATAP',
      'Get-SecretATAPBitwarden', 'Get-SecretATAPBitwardenSecretsManager',
      'Initialize-BWSAccessToken', 'Initialize-BWSApplicationAccessToken',
      'Initialize-BWSCredentialDirectory',
      'Invoke-BWSReadOnlyTokenBootstrap', 'New-BWSReadOnlyBootstrapEnvelope',
      'New-SprintBitwardenSecrets', 'Remove-SprintBitwardenSecrets'
    )
    Import-Module -Name $script:modulePath -Force -ErrorAction Stop
  }

  AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
  }

  It 'exports exactly the frozen public surface' {
    (Get-Command -Module $script:moduleName -CommandType Function).Name | Sort-Object |
      Should -Be ($script:expectedFunctions | Sort-Object)
  }

  It 'keeps the five implementation helpers private' {
    foreach ($name in @(
      'Get-BWSReadOnlyBootstrapCurrentIdentityName', 'Invoke-BitwardenCliWithCleanTlsEnvironment',
      'Invoke-BWSReadOnlyBootstrapWorker', 'Resolve-BitwardenCliNodeExtraCaCertsPath',
      'Resolve-BWSReadOnlyBootstrapIdentity'
    )) {
      Get-Command -Module $script:moduleName -Name $name -ErrorAction SilentlyContinue |
        Should -BeNullOrEmpty
    }
  }

  It 'declares the three global secret contracts' {
    $manifest = Import-PowerShellDataFile -Path $script:modulePath
    $manifest.FunctionsToExport | Should -Contain 'Get-BWSAccessToken'
    $manifest.FunctionsToExport | Should -Contain 'Get-SecretATAP'
    $manifest.FunctionsToExport | Should -Contain 'Initialize-BWSAccessToken'
  }
}

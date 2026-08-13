BeforeAll {
  $script:PkiModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:RepoSrc = Split-Path -Parent $script:PkiModuleRoot
  $script:UmbrellaRoot = Join-Path $script:RepoSrc 'ATAP.Utilities.Security.Powershell'
}

AfterAll {
  Remove-Module 'ATAP.Utilities.Security.Powershell', 'ATAP.Utilities.Security.PKI.PowerShell', 'ATAP.Utilities.Security.Secrets.PowerShell' -Force -ErrorAction SilentlyContinue
}

Describe 'Security umbrella compatibility contract' -Tag 'Unit' {
  It 'retains minimum dependencies on both child umbrellas' {
    $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $script:UmbrellaRoot 'ATAP.Utilities.Security.Powershell.psd1')
    $requiredNames = @($manifest.RequiredModules | ForEach-Object { if ($_ -is [string]) { $_ } else { $_.ModuleName } })
    $requiredNames | Should -Contain 'ATAP.Utilities.Security.PKI.PowerShell'
    $requiredNames | Should -Contain 'ATAP.Utilities.Security.Secrets.PowerShell'
  }

  It 're-exports child and residual commands from a source import' {
    Import-Module (Join-Path $script:UmbrellaRoot 'ATAP.Utilities.Security.Powershell.psm1') -Force -ErrorAction Stop -DisableNameChecking
    foreach ($name in @(
        'Get-DistinguishedNameQualifiedFilePath', 'New-EncryptedPrivateKey',
        'Get-BitWardenCredential', 'Invoke-RotateSecretsATAP', 'Get-UsersSecretVaultInfo')) {
      $command = Get-Command -Name $name -ErrorAction Stop
      $command.Source | Should -Be 'ATAP.Utilities.Security.Powershell' -Because $name
    }
  }

  It 'uses the package-preserved preamble for child imports' {
    Test-Path -LiteralPath (Join-Path $script:UmbrellaRoot 'module.preamble.ps1') | Should -BeTrue
    $preamble = Get-Content -LiteralPath (Join-Path $script:UmbrellaRoot 'module.preamble.ps1') -Raw
    $preamble | Should -Match 'ATAP\.Utilities\.Security\.PKI\.PowerShell'
    $preamble | Should -Match 'ATAP\.Utilities\.Security\.Secrets\.PowerShell'
  }
}

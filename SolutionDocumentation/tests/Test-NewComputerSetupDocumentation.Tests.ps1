BeforeAll {
  $script:documentationRoot = Split-Path $PSScriptRoot -Parent
  . (Join-Path $script:documentationRoot 'Test-NewComputerSetupDocumentation.ps1')
}

Describe 'Test-NewComputerSetupDocumentation' -Tag 'Unit' {
  It 'accepts the canonical active setup documentation contract' {
    $result = Test-NewComputerSetupDocumentation -DocumentationRoot $script:documentationRoot

    $result.Passed | Should -BeTrue
    $result.Findings | Should -BeNullOrEmpty
  }

  It 'reports every corrected stale setup pattern without changing the files' {
    foreach ($name in @('NewComputerSetup.md', 'BuildMaster-Install-Runbook.md', 'Runbook-BuildMasterConfiguration.md')) {
      Copy-Item -LiteralPath (Join-Path $script:documentationRoot $name) -Destination (Join-Path $TestDrive $name)
    }
    $target = Join-Path $TestDrive 'BuildMaster-Install-Runbook.md'
    Add-Content -LiteralPath $target -Value @'
Import-Module 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\Module.psd1'
$env:PROGET_ADMIN_API_KEY = 'forbidden'
Use BuildMaster.Admin.API.Key for the service account through BW_SESSION on port 8600.
'@
    $beforeValidation = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash

    $result = Test-NewComputerSetupDocumentation -DocumentationRoot $TestDrive

    $result.Passed | Should -BeFalse
    $result.Findings.Rule | Should -Contain 'StaleSprintWorktree'
    $result.Findings.Rule | Should -Contain 'StaleSprintBranch'
    $result.Findings.Rule | Should -Contain 'ObsoleteInedoPort'
    $result.Findings.Rule | Should -Contain 'RawProGetKeyEnvironment'
    $result.Findings.Rule | Should -Contain 'ServiceAccountPasswordManagerSession'
    $result.Findings.Rule | Should -Contain 'HostQualifiedSecretName'
    (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash | Should -Be $beforeValidation
  }
}

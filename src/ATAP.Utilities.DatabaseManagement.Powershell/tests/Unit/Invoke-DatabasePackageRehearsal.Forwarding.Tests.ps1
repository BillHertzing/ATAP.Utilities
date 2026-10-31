#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Invoke-DatabasePackageRehearsal.ps1')
  . (Join-Path $publicDir 'Invoke-FlywayRehearsal.ps1')
  . (Join-Path $publicDir 'Get-DatabasePackageManifest.ps1')
  . (Join-Path $publicDir 'Expand-DatabaseChangePackage.ps1')
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
}
Describe 'Invoke-DatabasePackageRehearsal forwarding' -Tag 'Unit' {
  BeforeEach {
    $script:seen = $null
    Mock Write-PSFMessage {}
    Mock Get-DatabasePackageManifest { [pscustomobject]@{ dbChangeUnit = 'Sample.Database' } }
    Mock Expand-DatabaseChangePackage { throw 'Expansion must not occur' }
    Mock Test-Path { $true }
    Mock Invoke-FlywayRehearsal {
      $script:seen = @{} + $PesterBoundParameters
      [pscustomobject]@{ Success = $true; ValidateOutput = 'ok'; MigrateOutput = 'ok'; ElapsedSeconds = 1 }
    }
  }
  It 'forwards ordered history arguments' {
    $flags = @('-table=history', '-schemas=Ace', '-defaultSchema=Ace')
    $result = Invoke-DatabasePackageRehearsal -PackagePath 'D:/ATAPArtifacts/mock-package' -BuildId '42' -FlywayAdditionalArgs $flags -Confirm:$false
    $script:seen.ContainsKey('FlywayAdditionalArgs') | Should -BeTrue
    ($script:seen.FlywayAdditionalArgs -join '|') | Should -BeExactly ($flags -join '|')
    $result.Success | Should -BeTrue
    Should -Invoke Invoke-FlywayRehearsal -Times 1 -Exactly
  }
  It 'omits the downstream key when absent' {
    Invoke-DatabasePackageRehearsal -PackagePath 'D:/ATAPArtifacts/mock-package' -BuildId '42' -Confirm:$false | Out-Null
    $script:seen.ContainsKey('FlywayAdditionalArgs') | Should -BeFalse
  }
  It 'preserves an explicitly empty array' {
    Invoke-DatabasePackageRehearsal -PackagePath 'D:/ATAPArtifacts/mock-package' -BuildId '42' -FlywayAdditionalArgs @() -Confirm:$false | Out-Null
    $script:seen.ContainsKey('FlywayAdditionalArgs') | Should -BeTrue
    @($script:seen.FlywayAdditionalArgs).Count | Should -Be 0
  }
  It 'preserves package, identity, secret and path bindings' {
    Invoke-DatabasePackageRehearsal -PackagePath 'D:/ATAPArtifacts/mock-package' -Application 'Other' -BuildId '42' -RehearsalDb 'scratch' -DBConnectionStringSecretName 'Test.Secret' -LogPath 'D:/ATAPArtifacts/mock-log.json' -FlywayAdditionalArgs @('-x') -Confirm:$false | Out-Null
    $script:seen.Application | Should -Be 'Other'
    $script:seen.SourceDatabaseName | Should -Be 'Other'
    $script:seen.BuildId | Should -Be '42'
    $script:seen.RehearsalDb | Should -Be 'scratch'
    $script:seen.DBConnectionStringSecretName | Should -Be 'Test.Secret'
    $script:seen.BundlePath | Should -Be 'D:/ATAPArtifacts/mock-package'
    $script:seen.FlywayBasePath | Should -Be 'D:/ATAPArtifacts/mock-package'
    $script:seen.FlywaySqlMigrationsPath | Should -Be (Join-Path 'D:/ATAPArtifacts/mock-package' 'db\migrations')
    $script:seen.FlywayDataPath | Should -Be (Join-Path 'D:/ATAPArtifacts/mock-package' 'db\seeds')
    $script:seen.FlywayTomlPath | Should -Be (Join-Path 'D:/ATAPArtifacts/mock-package' 'flyway.toml')
    $script:seen.LogPath | Should -Be 'D:/ATAPArtifacts/mock-log.json'
    $script:seen.ContainsKey('SqlInstance') | Should -BeFalse
  }
  It 'does not invoke rehearsal under WhatIf' {
    Invoke-DatabasePackageRehearsal -PackagePath 'D:/ATAPArtifacts/mock-package' -BuildId '42' -FlywayAdditionalArgs @('-x') -WhatIf
    Should -Invoke Invoke-FlywayRehearsal -Times 0 -Exactly
  }
}

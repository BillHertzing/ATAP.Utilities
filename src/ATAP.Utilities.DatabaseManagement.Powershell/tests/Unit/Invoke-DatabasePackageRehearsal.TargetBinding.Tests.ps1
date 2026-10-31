#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }, PSFramework

BeforeAll {
  $public = Join-Path $PSScriptRoot '../../public'
  . (Join-Path $public 'Invoke-DatabasePackageRehearsal.ps1')
  . (Join-Path $public 'Invoke-FlywayRehearsal.ps1')
  . (Join-Path $public 'Get-DatabasePackageManifest.ps1')
  . (Join-Path $public 'Expand-DatabaseChangePackage.ps1')
  function Invoke-TargetBinding568Fixture([hashtable]$Extra = @{}) {
    $parameters = @{ PackagePath = 'D:/ATAPArtifacts/mock-package-568'; BuildId = '568' }
    foreach ($key in $Extra.Keys) { $parameters[$key] = $Extra[$key] }
    Invoke-DatabasePackageRehearsal @parameters -Confirm:$false
  }
}

Describe 'Package rehearsal explicit expected source routing' -Tag 'Unit' {
  BeforeEach {
    $script:seen = $null
    $script:refuse = $false
    Mock Write-PSFMessage {}
    Mock Get-DatabasePackageManifest { [pscustomobject]@{ dbChangeUnit = 'Sample.Database' } }
    Mock Expand-DatabaseChangePackage { throw 'Unexpected expansion' }
    Mock Remove-Item { throw 'Unexpected cleanup or filesystem mutation' }
    Mock Test-Path { $true }
    Mock Invoke-FlywayRehearsal {
      $script:seen = @{} + $PesterBoundParameters
      if ($script:refuse) { throw 'Synthetic helper refusal' }
      [pscustomobject]@{ Success = $true; ValidateOutput = 'validate'; MigrateOutput = 'migrate'; ElapsedSeconds = 2 }
    }
  }

  It 'omits the expected key when absent' {
    $result = Invoke-TargetBinding568Fixture
    $script:seen.ContainsKey('ExpectedSourceDatabaseName') | Should -BeFalse
    $script:seen.SourceDatabaseName | Should -BeExactly 'Sample'
    $result.Success | Should -BeTrue
    Should -Invoke Invoke-FlywayRehearsal -Times 1 -Exactly -Scope It
  }

  It 'forwards the exact expectation with the manifest-derived source' {
    $result = Invoke-TargetBinding568Fixture @{ ExpectedSourceDatabaseName = 'Sample' }
    $script:seen.ContainsKey('ExpectedSourceDatabaseName') | Should -BeTrue
    $script:seen.ExpectedSourceDatabaseName | Should -BeExactly 'Sample'
    $script:seen.SourceDatabaseName | Should -BeExactly 'Sample'
    $result.ValidateOutput | Should -BeExactly 'validate'
    $result.MigrateOutput | Should -BeExactly 'migrate'
    $result.ElapsedSeconds | Should -Be 2
  }

  It 'preserves an explicit application and clone independently of the expectation' {
    Invoke-TargetBinding568Fixture @{ Application = 'Other'; ExpectedSourceDatabaseName = 'Other'; RehearsalDb = 'approved-copy' } | Out-Null
    $script:seen.Application | Should -BeExactly 'Other'
    $script:seen.SourceDatabaseName | Should -BeExactly 'Other'
    $script:seen.ExpectedSourceDatabaseName | Should -BeExactly 'Other'
    $script:seen.RehearsalDb | Should -BeExactly 'approved-copy'
    $script:seen.BuildId | Should -BeExactly '568'
  }

  It 'routes a mismatched expectation unchanged and propagates helper refusal' {
    $script:refuse = $true
    { Invoke-TargetBinding568Fixture @{ ExpectedSourceDatabaseName = 'Different' } } | Should -Throw '*Synthetic helper refusal*'
    $script:seen.SourceDatabaseName | Should -BeExactly 'Sample'
    $script:seen.ExpectedSourceDatabaseName | Should -BeExactly 'Different'
    Should -Invoke Invoke-FlywayRehearsal -Times 1 -Exactly -Scope It
    Should -Invoke Remove-Item -Times 0 -Exactly -Scope It
  }

  It 'does not call the helper under WhatIf with a bound expectation' {
    Invoke-DatabasePackageRehearsal -PackagePath 'D:/ATAPArtifacts/mock-package-568' -BuildId '568' -ExpectedSourceDatabaseName 'Sample' -WhatIf
    Should -Invoke Invoke-FlywayRehearsal -Times 0 -Exactly -Scope It
    Should -Invoke Remove-Item -Times 0 -Exactly -Scope It
  }

  It 'preserves ordered or explicitly empty Flyway arguments <Label>' -ForEach @(
    @{ Label = 'ordered'; Flags = @('-defaultSchema=dbo', '-table=flyway_schema_history', '-target=00160') }
    @{ Label = 'empty'; Flags = @() }
  ) {
    Invoke-TargetBinding568Fixture @{ ExpectedSourceDatabaseName = 'Sample'; FlywayAdditionalArgs = $Flags } | Out-Null
    $script:seen.ContainsKey('FlywayAdditionalArgs') | Should -BeTrue
    @($script:seen.FlywayAdditionalArgs).Count | Should -Be @($Flags).Count
    ($script:seen.FlywayAdditionalArgs -join '|') | Should -BeExactly ($Flags -join '|')
    $script:seen.ExpectedSourceDatabaseName | Should -BeExactly 'Sample'
  }

  It 'preserves default connection and package path bindings' {
    Invoke-TargetBinding568Fixture @{ ExpectedSourceDatabaseName = 'Sample' } | Out-Null
    $script:seen.DatabaseHost | Should -BeExactly 'localhost'
    $script:seen.SqlInstance | Should -BeExactly 'EXPWHERTZING'
    $script:seen.ContainsKey('DBConnectionStringSecretName') | Should -BeFalse
    $script:seen.ContainsKey('FlywayAdditionalArgs') | Should -BeFalse
    $script:seen.BundlePath | Should -BeExactly 'D:/ATAPArtifacts/mock-package-568'
    $script:seen.FlywayBasePath | Should -BeExactly $script:seen.BundlePath
    $script:seen.FlywaySqlMigrationsPath | Should -BeExactly (Join-Path $script:seen.BundlePath 'db\migrations')
    $script:seen.FlywayDataPath | Should -BeExactly (Join-Path $script:seen.BundlePath 'db\seeds')
    $script:seen.FlywayTomlPath | Should -BeExactly (Join-Path $script:seen.BundlePath 'flyway.toml')
  }

  It 'preserves secret routing and the log path' {
    Invoke-TargetBinding568Fixture @{ ExpectedSourceDatabaseName = 'Sample'; DBConnectionStringSecretName = 'Test.Secret'; LogPath = 'D:/ATAPArtifacts/mock-log-568.json' } | Out-Null
    $script:seen.DBConnectionStringSecretName | Should -BeExactly 'Test.Secret'
    $script:seen.LogPath | Should -BeExactly 'D:/ATAPArtifacts/mock-log-568.json'
    $script:seen.ContainsKey('DatabaseHost') | Should -BeFalse
    $script:seen.ContainsKey('SqlInstance') | Should -BeFalse
  }
}

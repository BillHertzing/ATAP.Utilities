#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }, PSFramework

BeforeAll {
  $public = Join-Path $PSScriptRoot '../../public'
  . (Join-Path $public 'Invoke-DatabasePackageRehearsal.ps1')
  # Future helper interface only: production fixture support is a separate unit.
  function Invoke-FlywayRehearsal {
    [CmdletBinding()]
    param(
      [string]$Application, [string]$BuildId, [string]$SourceDatabaseName,
      [string]$BundlePath, [string]$FlywayBasePath, [string]$FlywaySqlMigrationsPath,
      [string]$FlywayDataPath, [string]$FlywayTomlPath, [string]$RehearsalDb,
      [string]$DBConnectionStringSecretName, [string]$SqlInstance, [string]$DatabaseHost,
      [string]$LogPath, [string[]]$FlywayAdditionalArgs, [string]$ExpectedSourceDatabaseName,
      [string]$LoginFixturePath, [string]$DecryptFixturePath,
      [string]$PackageName, [string]$PackageVersion
    )
    throw 'Unexpected unmocked future helper call'
  }
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
    foreach ($fixtureKey in @('LoginFixturePath', 'DecryptFixturePath', 'PackageName', 'PackageVersion')) {
      $script:seen.ContainsKey($fixtureKey) | Should -BeFalse
    }
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

Describe 'Package fixture identity forwarding (599)' -Tag 'Unit' {
  BeforeEach {
    $script:seen599 = $null
    $script:manifest599 = [pscustomobject]@{ dbChangeUnit = 'Sample.Database'; appVersion = '1.2.3-test' }
    $script:fixture599 = @{
      LoginFixturePath = 'D:/ATAPArtifacts/mock599/Login.sql'
      DecryptFixturePath = 'D:/ATAPArtifacts/mock599/Decrypt.sql'
      ExpectedSourceDatabaseName = 'Sample'
      ExpectedPackageName = 'Sample.Database'
      ExpectedPackageVersion = '1.2.3-test'
    }
    Mock Write-PSFMessage {}
    Mock Test-Path { $true }
    Mock Expand-DatabaseChangePackage { 'D:/ATAPArtifacts/mock599/expanded' }
    Mock Remove-Item {}
    Mock Get-DatabasePackageManifest { $script:manifest599 }
    Mock Invoke-FlywayRehearsal {
      $script:seen599 = @{} + $PesterBoundParameters
      [pscustomobject]@{ Success = $true }
    }
  }

  It 'forwards paired paths and exact raw identity without wrapper guard keys' {
    Invoke-TargetBinding568Fixture $script:fixture599 | Out-Null
    foreach ($key599 in @('LoginFixturePath', 'DecryptFixturePath')) {
      $script:seen599[$key599] | Should -BeExactly $script:fixture599[$key599]
    }
    $script:seen599.PackageName | Should -BeExactly 'Sample.Database'
    $script:seen599.PackageVersion | Should -BeExactly '1.2.3-test'
    $script:seen599.ExpectedSourceDatabaseName | Should -BeExactly 'Sample'
    $script:seen599.ContainsKey('ExpectedPackageName') | Should -BeFalse
    $script:seen599.ContainsKey('ExpectedPackageVersion') | Should -BeFalse
    Should -Invoke Invoke-FlywayRehearsal -Times 1 -Exactly -Scope It
  }

  It 'refuses missing explicit opt-in field <Missing>' -ForEach @(
    @{ Missing = 'LoginFixturePath' }
    @{ Missing = 'DecryptFixturePath' }
    @{ Missing = 'ExpectedSourceDatabaseName' }
    @{ Missing = 'ExpectedPackageName' }
    @{ Missing = 'ExpectedPackageVersion' }
  ) {
    $script:fixture599.Remove($Missing)
    { Invoke-DatabasePackageRehearsal -NupkgPath 'D:/ATAPArtifacts/mock599.nupkg' -BuildId 599 @script:fixture599 -Confirm:$false } |
      Should -Throw '*Fixture rehearsal requires explicit*'
    Should -Invoke Expand-DatabaseChangePackage -Times 0 -Exactly -Scope It
    Should -Invoke Get-DatabasePackageManifest -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-FlywayRehearsal -Times 0 -Exactly -Scope It
  }

  It 'refuses invalid explicit identity <Label>' -ForEach @(
    @{ Label = 'null'; Value = $null }
    @{ Label = 'numeric'; Value = 123 }
    @{ Label = 'array'; Value = @('1.2.3-test') }
    @{ Label = 'empty'; Value = '' }
    @{ Label = 'space'; Value = ' ' }
    @{ Label = 'padded'; Value = ' 1.2.3-test' }
  ) {
    $script:fixture599.ExpectedPackageVersion = $Value
    { Invoke-TargetBinding568Fixture $script:fixture599 } | Should -Throw '*Fixture rehearsal requires explicit*'
    Should -Invoke Get-DatabasePackageManifest -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-FlywayRehearsal -Times 0 -Exactly -Scope It
  }

  It 'refuses malformed raw manifest identity <Label>' -ForEach @(
    @{ Label = 'missing name'; Manifest = [pscustomobject]@{ appVersion = '1.2.3-test' } }
    @{ Label = 'missing version'; Manifest = [pscustomobject]@{ dbChangeUnit = 'Sample.Database' } }
    @{ Label = 'null name'; Manifest = [pscustomobject]@{ dbChangeUnit = $null; appVersion = '1.2.3-test' } }
    @{ Label = 'numeric version'; Manifest = [pscustomobject]@{ dbChangeUnit = 'Sample.Database'; appVersion = 123 } }
    @{ Label = 'array version'; Manifest = [pscustomobject]@{ dbChangeUnit = 'Sample.Database'; appVersion = @('1.2.3-test') } }
    @{ Label = 'empty version'; Manifest = [pscustomobject]@{ dbChangeUnit = 'Sample.Database'; appVersion = '' } }
    @{ Label = 'space name'; Manifest = [pscustomobject]@{ dbChangeUnit = ' '; appVersion = '1.2.3-test' } }
    @{ Label = 'padded version'; Manifest = [pscustomobject]@{ dbChangeUnit = 'Sample.Database'; appVersion = '1.2.3-test ' } }
    @{ Label = 'case mismatch'; Manifest = [pscustomobject]@{ dbChangeUnit = 'sample.Database'; appVersion = '1.2.3-test' } }
    @{ Label = 'version mismatch'; Manifest = [pscustomobject]@{ dbChangeUnit = 'Sample.Database'; appVersion = '1.2.4-test' } }
  ) {
    $script:manifest599 = $Manifest
    { Invoke-DatabasePackageRehearsal -NupkgPath 'D:/ATAPArtifacts/mock599.nupkg' -BuildId 599 @script:fixture599 -Confirm:$false } |
      Should -Throw '*Fixture package manifest*'
    Should -Invoke Invoke-FlywayRehearsal -Times 0 -Exactly -Scope It
    Should -Invoke Remove-Item -Times 1 -Exactly -Scope It
  }

  It 'requires paths when only package guards are bound' {
    $script:fixture599.Remove('LoginFixturePath')
    $script:fixture599.Remove('DecryptFixturePath')
    { Invoke-TargetBinding568Fixture $script:fixture599 } | Should -Throw '*Fixture rehearsal requires explicit*'
    Should -Invoke Get-DatabasePackageManifest -Times 0 -Exactly -Scope It
  }

  It 'does not call the future helper under valid fixture WhatIf' {
    Invoke-DatabasePackageRehearsal -PackagePath 'D:/ATAPArtifacts/mock599' -BuildId 599 @script:fixture599 -WhatIf
    Should -Invoke Invoke-FlywayRehearsal -Times 0 -Exactly -Scope It
    Should -Invoke Remove-Item -Times 0 -Exactly -Scope It
  }

  It 'refuses malformed manifest even under WhatIf' {
    $script:manifest599 = [pscustomobject]@{ dbChangeUnit = 'Sample.Database' }
    { Invoke-DatabasePackageRehearsal -PackagePath 'D:/ATAPArtifacts/mock599' -BuildId 599 @script:fixture599 -WhatIf } |
      Should -Throw '*Fixture package manifest*'
    Should -Invoke Invoke-FlywayRehearsal -Times 0 -Exactly -Scope It
  }

  It 'cleans owned expansion after successful forwarding' {
    Invoke-DatabasePackageRehearsal -NupkgPath 'D:/ATAPArtifacts/mock599.nupkg' -BuildId 599 @script:fixture599 -Confirm:$false | Out-Null
    Should -Invoke Invoke-FlywayRehearsal -Times 1 -Exactly -Scope It
    Should -Invoke Remove-Item -Times 1 -Exactly -Scope It
  }
}

#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
# Contract-mode manifest selection in Invoke-DatabasePackageRehearsal (Impl-Rehearsal-Parameterize, Phase A).
# Offline: the manifest reader and Invoke-FlywayRehearsal are mocked; the real committed contract is read.
BeforeAll {
  $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
  $public = Join-Path $repositoryRoot 'src/ATAP.Utilities.DatabaseManagement.Powershell/public'
  $private = Join-Path $repositoryRoot 'src/ATAP.Utilities.DatabaseManagement.Powershell/private'
  Import-Module PSFramework -ErrorAction Stop
  . (Join-Path $private 'Read-RehearsalBoundaryContract.ps1')
  foreach ($file in @('Invoke-FlywayRehearsal.ps1', 'Invoke-DatabasePackageRehearsal.ps1', 'Get-DatabasePackageManifest.ps1', 'Expand-DatabaseChangePackage.ps1')) {
    . (Join-Path $public $file)
  }
  $script:contractPath = Join-Path $repositoryRoot 'Database/Verify/RehearsalBoundaries.json'
  $script:allNames = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'Database/Flyway/SQL') -Filter 'V*.sql' -File | ForEach-Object Name | Sort-Object)
  $script:virtualPackage = Join-Path $repositoryRoot '_generated/Sprint0017/RehearsalContract/virtual-package'
  function New-Manifest([string[]]$Names, [string]$Target, [string]$Version = 'synthetic-param-0126') {
    [pscustomobject]@{ dbChangeUnit = 'ATAPUtilities.Database'; appVersion = $Version; flywayTargetVersion = $Target
      files = @($Names | ForEach-Object { [pscustomobject]@{ kind = 'migration'; path = 'db/migrations/' + $_ } }) }
  }
}

Describe 'Invoke-DatabasePackageRehearsal contract mode' -Tag 'Unit', 'RehearsalContract' {
  BeforeEach {
    $script:manifest = New-Manifest $script:allNames '00220'
    $script:forwarded = $null
    $script:parameters = @{ PackagePath = $script:virtualPackage; Application = 'ATAPUtilities'; BuildId = '0126'
      ExpectedSourceDatabaseName = 'ATAPUtilities'; ExpectedPackageName = 'ATAPUtilities.Database'
      ExpectedPackageVersion = 'synthetic-param-0126'; FixtureContractPath = $script:contractPath; Confirm = $false }
    Mock Write-PSFMessage {}
    Mock Test-Path { $true }
    Mock Get-DatabasePackageManifest { $script:manifest }
    Mock Invoke-FlywayRehearsal { $script:forwarded = @{} + $PesterBoundParameters; [pscustomobject]@{ Success = $true } }
  }

  It 'admits the 0.1.26-shaped manifest (target 00220) and forwards only the contract path' {
    (Invoke-DatabasePackageRehearsal @script:parameters).Success | Should -BeTrue
    $script:forwarded.FixtureContractPath | Should -BeExactly $script:contractPath
    foreach ($legacyKey in @('LoginFixturePath', 'DecryptFixturePath', 'OrganizationFixturePath')) { $script:forwarded.ContainsKey($legacyKey) | Should -BeFalse }
    $script:forwarded.ExpectedSourceDatabaseName | Should -BeExactly 'ATAPUtilities'
    $script:forwarded.PackageName | Should -BeExactly 'ATAPUtilities.Database'
    $script:forwarded.PackageVersion | Should -BeExactly 'synthetic-param-0126'
    Should -Invoke Invoke-FlywayRehearsal -Times 1 -Exactly
  }
  It 'admits a 0.1.25-shaped manifest (target 00210) through the same contract' {
    $script:manifest = New-Manifest @($script:allNames | Where-Object { $_ -notlike 'V00220__*' }) '00210'
    (Invoke-DatabasePackageRehearsal @script:parameters).Success | Should -BeTrue
  }
  It 'takes the package version only from the parameter and the manifest (<Version>)' -ForEach @(
    @{ Version = '0.1.26' }; @{ Version = '9.9.9-anything' }
  ) {
    $script:manifest = New-Manifest $script:allNames '00220' $Version
    $script:parameters.ExpectedPackageVersion = $Version
    (Invoke-DatabasePackageRehearsal @script:parameters).Success | Should -BeTrue
    $script:forwarded.PackageVersion | Should -BeExactly $Version
  }
  It 'refuses <Label> before any rehearsal' -ForEach @(
    @{ Label = 'a declared target below the package head'; Expect = '*does not support this manifest migration boundary*'; Mutate = { $script:manifest.flywayTargetVersion = '00210' } }
    @{ Label = 'a manifest without a declared target'; Expect = '*does not support this manifest migration boundary*'; Mutate = { $script:manifest = [pscustomobject]@{ dbChangeUnit = 'ATAPUtilities.Database'; appVersion = 'synthetic-param-0126'; files = $script:manifest.files } } }
    @{ Label = 'a head that is not a contract boundary (00230)'; Expect = '*does not support this manifest migration boundary*'; Mutate = { $script:manifest = New-Manifest ($script:allNames + 'V00230__Next.sql') '00230' } }
    @{ Label = 'the refused legacy boundary 00160'; Expect = '*does not support this manifest migration boundary*'; Mutate = { $script:manifest = New-Manifest @($script:allNames | Where-Object { [string]::CompareOrdinal($_.Substring(0, 6), 'V00160') -le 0 }) '00160' } }
    @{ Label = 'a missing middle migration'; Expect = '*not exactly the contract boundary migrations*'; Mutate = { $script:manifest = New-Manifest @($script:allNames | Where-Object { $_ -notlike 'V00190__*' }) '00220' } }
    @{ Label = 'a package version that differs from the manifest'; Expect = '*identity does not match*'; Mutate = { $script:parameters.ExpectedPackageVersion = 'synthetic-other' } }
    @{ Label = 'a package identity other than the contract'; Expect = '*does not match the rehearsal boundary contract*'; Mutate = { $script:manifest.dbChangeUnit = 'Other.Database'; $script:parameters.ExpectedPackageName = 'Other.Database' } }
    @{ Label = 'a source catalog other than the contract'; Expect = '*does not match the rehearsal boundary contract*'; Mutate = { $script:parameters.ExpectedSourceDatabaseName = 'Other' } }
  ) {
    & $Mutate
    { Invoke-DatabasePackageRehearsal @script:parameters } | Should -Throw $Expect
    Should -Invoke Invoke-FlywayRehearsal -Times 0 -Exactly
  }
  It 'refuses <Label> in the begin block' -ForEach @(
    @{ Label = 'mixing the contract with an Organization path'; Expect = '*derives its verifier paths*'; Mutate = { $script:parameters.OrganizationFixturePath = 'D:/x/Verify_Organization_V00210.sql' } }
    @{ Label = 'mixing the contract with Login/Decrypt paths'; Expect = '*derives its verifier paths*'; Mutate = { $script:parameters.LoginFixturePath = 'D:/x/L.sql'; $script:parameters.DecryptFixturePath = 'D:/x/D.sql' } }
    @{ Label = 'a missing package version'; Expect = "*requires explicit nonempty trim-exact 'ExpectedPackageVersion'*"; Mutate = { $script:parameters.Remove('ExpectedPackageVersion') } }
    @{ Label = 'a padded contract path'; Expect = "*requires explicit nonempty trim-exact 'FixtureContractPath'*"; Mutate = { $script:parameters.FixtureContractPath = $script:contractPath + ' ' } }
    @{ Label = 'a relative contract path'; Expect = '*absolute FixtureContractPath*'; Mutate = { $script:parameters.FixtureContractPath = 'Database/Verify/RehearsalBoundaries.json' } }
  ) {
    & $Mutate
    { Invoke-DatabasePackageRehearsal @script:parameters } | Should -Throw $Expect
    Should -Invoke Get-DatabasePackageManifest -Times 0 -Exactly
    Should -Invoke Invoke-FlywayRehearsal -Times 0 -Exactly
  }
}

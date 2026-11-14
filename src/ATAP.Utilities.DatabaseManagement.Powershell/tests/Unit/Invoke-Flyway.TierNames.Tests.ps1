#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }, dbatools, PSFramework

# Tier-name tests for Invoke-Flyway -Environment (0.1.26, Sprint 0017 O4 / slice S0).
# Native commands, connection resolution and directory operations are doubles.
BeforeAll {
  . (Join-Path $PSScriptRoot '../../public/Resolve-DatabaseSqlConnection.ps1')
  . (Join-Path $PSScriptRoot '../../public/Invoke-Flyway.ps1')
  # Stand-in for Get-PVal that enforces -ValidValues the way the real helper does for supplied values.
  function Get-TierNameValue {
    param($ParameterName, $OriginalPSBoundParameters, $DottedPath, $Settings,
      $DefaultValue, $ValidValues, [switch]$AllowMissing)
    if ($ParameterName -eq 'Environment' -and $null -ne $DefaultValue -and $ValidValues -and
      -not ($ValidValues -contains $DefaultValue)) {
      throw "Environment '$DefaultValue' is not a valid value."
    }
    return $DefaultValue
  }
  Set-Alias -Name Get-PVal -Value Get-TierNameValue
  function java { 'openjdk version "21.0.1"' }
  function git { 'synthetic-metadata' }
  function Invoke-TierNameNative {
    $script:nativeCalls++
    $script:nativeArguments = @($args)
    $global:LASTEXITCODE = 0
    'synthetic-flyway-success'
  }
  function Invoke-TierNameFixture([string]$Environment) {
    Invoke-Flyway -DatabaseName 'ATAPUtilities' -Environment $Environment -DatabaseHost 'fixture' `
      -IntegratedSecurity -Settings @{ fixture = $true } -FlywayCommand 'validate' `
      -FlywayExecutablePath 'Invoke-TierNameNative' `
      -FlywayBasePath 'D:/ATAPArtifacts/Sprint0017/TierNames/Virtual' `
      -FlywaySqlMigrationsPath 'D:/ATAPArtifacts/Sprint0017/TierNames/Virtual/sql' `
      -FlywayDataPath 'D:/ATAPArtifacts/Sprint0017/TierNames/Virtual/data' `
      -FlywayTomlPath 'D:/ATAPArtifacts/Sprint0017/TierNames/Virtual/flyway.toml' `
      -Files @() -GitTag 'fixture' -GitCommit 'fixture' -Confirm:$false
  }
}

Describe 'Invoke-Flyway -Environment tier names' -Tag 'Unit' {
  BeforeEach {
    $script:nativeCalls = 0
    $script:nativeArguments = @()
    $script:oldExit = $global:LASTEXITCODE
    $script:oldFlywayEnvironment = @{}
    foreach ($entry in Get-ChildItem Env: | Where-Object Name -Like 'FLYWAY_*') {
      $script:oldFlywayEnvironment[$entry.Name] = $entry.Value
    }
    $script:oldPassphrase = $env:AceCommander_UserPii__PassphraseV1
    $env:AceCommander_UserPii__PassphraseV1 = 'synthetic-nonsecret'
    Mock Write-PSFMessage {}
    Mock git { 'synthetic-metadata' }
    Mock java { 'openjdk version "21.0.1"' }
    Mock Resolve-DatabaseSqlConnection {
      [pscustomobject]@{
        Connection = [pscustomobject]@{
          ConnectionString = 'Server=fixture;Database=ATAPUtilities;Integrated Security=true'
          DataSource = 'fixture'; State = 'Closed'
        }
        IsCallerOwned = $true
      }
    }
    Mock Test-Path { $true }
    Mock Resolve-Path { 'D:/ATAPArtifacts/Sprint0017/TierNames/Virtual' }
    Mock Push-Location {}
    Mock Pop-Location {}
  }
  AfterEach {
    foreach ($entry in Get-ChildItem Env: | Where-Object Name -Like 'FLYWAY_*') {
      [Environment]::SetEnvironmentVariable($entry.Name, $null, 'Process')
    }
    foreach ($name in $script:oldFlywayEnvironment.Keys) {
      [Environment]::SetEnvironmentVariable($name, $script:oldFlywayEnvironment[$name], 'Process')
    }
    $env:AceCommander_UserPii__PassphraseV1 = $script:oldPassphrase
    $global:LASTEXITCODE = $script:oldExit
  }

  It 'accepts the runtime tier <Tier> and maps it to the Flyway environment <Key> with URL prefix <Prefix>' -ForEach @(
    @{ Tier = 'Integration'; Key = 'testing';     Prefix = 'TEST' }
    @{ Tier = 'QA';          Key = 'testing';     Prefix = 'TEST' }
    @{ Tier = 'Testing';     Key = 'testing';     Prefix = 'TEST' }
    @{ Tier = 'Development'; Key = 'development'; Prefix = 'DEV' }
    @{ Tier = 'Experimental'; Key = 'experimental'; Prefix = 'EXP' }
    @{ Tier = 'Production';  Key = 'production';  Prefix = 'PROD' }
  ) {
    $result = Invoke-TierNameFixture -Environment $Tier
    $result.Success | Should -BeTrue
    $script:nativeCalls | Should -Be 1
    $script:nativeArguments | Should -Contain "-environment=$Key"
    [Environment]::GetEnvironmentVariable("FLYWAY_${Prefix}_URL", 'Process') | Should -Match '^jdbc:sqlserver://'
  }

  It 'Integration and QA produce the same Flyway invocation as the Testing alias' {
    Invoke-TierNameFixture -Environment 'Testing' | Out-Null
    $testingArguments = $script:nativeArguments
    foreach ($tier in @('Integration', 'QA')) {
      $script:nativeArguments = @()
      Invoke-TierNameFixture -Environment $tier | Out-Null
      $script:nativeArguments | Should -Be $testingArguments
    }
    $script:nativeCalls | Should -Be 3
  }

  It 'rejects an unknown tier name before native launch' {
    { Invoke-TierNameFixture -Environment 'Staging' } | Should -Throw "*not a valid value*"
    $script:nativeCalls | Should -Be 0
  }
}

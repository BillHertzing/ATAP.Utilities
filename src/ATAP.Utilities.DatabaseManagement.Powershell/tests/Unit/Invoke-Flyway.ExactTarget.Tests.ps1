#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }, dbatools, PSFramework

# Independent call-level tests. Native commands/configuration are finite doubles;
# connection resolution, SQL-facing helpers and directory operations are mocked.
BeforeAll {
  . (Join-Path $PSScriptRoot '../../public/Resolve-DatabaseSqlConnection.ps1')
  . (Join-Path $PSScriptRoot '../../public/Invoke-Flyway.ps1')
  function Get-ExactTarget553Value {
    param($ParameterName, $OriginalPSBoundParameters, $DottedPath, $Settings,
      $DefaultValue, $ValidValues, [switch]$AllowMissing)
    if ($ParameterName -eq 'DatabaseName' -and $null -ne $script:resolvedName) { return $script:resolvedName }
    if ($ParameterName -eq 'FlywayAdditionalArgs' -and $null -ne $script:resolvedArgs) { return ,$script:resolvedArgs }
    return $DefaultValue
  }
  Set-Alias -Name Get-PVal -Value Get-ExactTarget553Value
  function git { 'synthetic-metadata' }
  function java { 'openjdk version "21.0.1"' }
  function Invoke-ExactTarget553Native {
    $script:nativeCalls++
    $script:nativeArguments = @($args)
    $global:LASTEXITCODE = 0
    'synthetic-flyway-success'
  }
  function Invoke-ExactTarget553Fixture([hashtable]$Extra = @{}) {
    $parameters = @{
      DatabaseName = 'ATAPUtilities'; Environment = 'Experimental'; DatabaseHost = 'fixture'
      IntegratedSecurity = $true; Settings = @{ fixture = $true }; FlywayCommand = 'migrate'
      FlywayExecutablePath = 'Invoke-ExactTarget553Native'
      FlywayBasePath = 'D:/ATAPArtifacts/Sprint0017/Task17.68.e/ExactTarget553/Virtual'
      FlywaySqlMigrationsPath = 'D:/ATAPArtifacts/Sprint0017/Task17.68.e/ExactTarget553/Virtual/sql'
      FlywayDataPath = 'D:/ATAPArtifacts/Sprint0017/Task17.68.e/ExactTarget553/Virtual/data'
      FlywayTomlPath = 'D:/ATAPArtifacts/Sprint0017/Task17.68.e/ExactTarget553/Virtual/flyway.toml'
      Files = @(); GitTag = 'fixture'; GitCommit = 'fixture'
    }
    foreach ($key in $Extra.Keys) { $parameters[$key] = $Extra[$key] }
    Invoke-Flyway @parameters -Confirm:$false
  }
}

Describe 'Invoke-Flyway explicit exact catalog binding' -Tag 'Unit' {
  BeforeEach {
    $script:nativeCalls = 0
    $script:nativeArguments = @()
    $script:resolvedName = $null
    $script:resolvedArgs = $null
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
          ConnectionString = 'Server=fixture;Database=fixture;Integrated Security=true'
          DataSource = 'fixture'; State = 'Closed'
        }
        IsCallerOwned = $true
      }
    }
    Mock Test-Path { $true }
    Mock Resolve-Path { 'D:/ATAPArtifacts/Sprint0017/Task17.68.e/ExactTarget553/Virtual' }
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

  It 'preserves another database and raw options when expected target is omitted' {
    $result = Invoke-ExactTarget553Fixture @{ DatabaseName = 'OtherDatabase'; FlywayAdditionalArgs = @('-url=fixture-legacy-override') }
    $result.Success | Should -BeTrue
    $script:nativeCalls | Should -Be 1
    @($script:nativeArguments | Where-Object { $_ -like '-placeholders.atap_required_catalog=*' }).Count | Should -Be 0
    $script:nativeArguments | Should -Contain '-url=fixture-legacy-override'
  }

  It 'emits exactly one explicit target alongside unchanged history arguments' {
    $result = Invoke-ExactTarget553Fixture @{
      ExpectedDatabaseName = 'ATAPUtilities'
      FlywayAdditionalArgs = @('-defaultSchema=dbo', '-table=flyway_schema_history', '-target=00160', '-placeholders.other=value')
    }
    $result.Success | Should -BeTrue
    $script:nativeCalls | Should -Be 1
    @($script:nativeArguments | Where-Object { $_ -like '-placeholders.atap_required_catalog=*' }).Count | Should -Be 1
    $script:nativeArguments | Should -Contain '-placeholders.atap_required_catalog=ATAPUtilities'
    $script:nativeArguments | Should -Contain '-defaultSchema=dbo'
    $script:nativeArguments | Should -Contain '-table=flyway_schema_history'
    $script:nativeArguments | Should -Contain '-target=00160'
    $script:nativeArguments | Should -Contain '-placeholders.other=value'
    $script:nativeArguments[-1] | Should -BeExactly 'migrate'
  }

  It 'binds one exact clone rather than its prefix family' {
    $clone = 'ATAPUtilities-rehearsal-553'
    (Invoke-ExactTarget553Fixture @{ DatabaseName = $clone; ExpectedDatabaseName = $clone }).Success | Should -BeTrue
    $script:nativeArguments | Should -Contain "-placeholders.atap_required_catalog=$clone"
  }

  It 'refuses mismatched resolved name <Actual> before connection resolution' -ForEach @(
    @{ Actual = 'AnotherDatabase' }; @{ Actual = 'ataputilities' }; @{ Actual = 'ATAPUtilities ' }
  ) {
    $script:resolvedName = $Actual
    { Invoke-ExactTarget553Fixture @{ ExpectedDatabaseName = 'ATAPUtilities' } } | Should -Throw '*does not match ExpectedDatabaseName*'
    $script:nativeCalls | Should -Be 0
    Should -Invoke Resolve-DatabaseSqlConnection -Times 0 -Exactly -Scope It
  }

  It 'rejects a conflicting option returned by effective configuration' {
    $script:resolvedArgs = @('-url=configuration-override')
    { Invoke-ExactTarget553Fixture @{ ExpectedDatabaseName = 'ATAPUtilities' } } | Should -Throw '*target binding*'
    $script:nativeCalls | Should -Be 0
  }

  It 'rejects unsafe explicit expected name <Name>' -ForEach @(
    @{ Name = '' }; @{ Name = "ATAP'Utilities" }; @{ Name = "ATAPUtilities`n" }; @{ Name = ('x' * 65) }
  ) {
    { Invoke-ExactTarget553Fixture @{ ExpectedDatabaseName = $Name } } | Should -Throw
    $script:nativeCalls | Should -Be 0
  }

  It 'rejects bound conflicting option <Option> before native launch' -ForEach @(
    @{ Option = '-url=jdbc:sqlserver://other' }
    @{ Option = '--URL=jdbc:sqlserver://other' }
    @{ Option = '-configFiles=other.toml' }
    @{ Option = '-environment=production' }
    @{ Option = '-placeholderReplacement=false' }
    @{ Option = '-placeholderPrefix=other' }
    @{ Option = '-placeholderSuffix=other' }
    @{ Option = '-placeholderSeparator=other' }
    @{ Option = '-placeholders.atap_required_catalog=AnotherDatabase' }
    @{ Option = '-flyway.placeholders.atap_required_catalog=ATAPUtilities' }
    @{ Option = '-environments.experimental.url=other' }
    @{ Option = 'migrate' }
  ) {
    { Invoke-ExactTarget553Fixture @{ ExpectedDatabaseName = 'ATAPUtilities'; FlywayAdditionalArgs = @($Option) } } | Should -Throw '*target binding*'
    $script:nativeCalls | Should -Be 0
  }
}

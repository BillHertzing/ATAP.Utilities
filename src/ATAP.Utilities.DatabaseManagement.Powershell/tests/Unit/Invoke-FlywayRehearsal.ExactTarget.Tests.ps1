#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }, dbatools, PSFramework

# All SQL/copy/Flyway effects are mocked. No database or fixture file is created.
BeforeAll {
  $public = Join-Path $PSScriptRoot '../../public'
  $private = Join-Path $PSScriptRoot '../../private'
  . (Join-Path $private 'DatabaseSqlConnection.Helpers.ps1')
  . (Join-Path $private 'DatabaseSqlCommand.Helpers.ps1')
  . (Join-Path $private 'Invoke-AceCommanderLoginFixtureSequence.ps1')
  . (Join-Path $public 'Resolve-DatabaseSqlConnection.ps1')
  . (Join-Path $public 'Invoke-Flyway.ps1')
  . (Join-Path $public 'Invoke-FlywayRehearsal.ps1')
  function Invoke-ExactRehearsal553Fixture([hashtable]$Extra = @{}) {
    $parameters = @{
      Application = 'ATAPUtilities'; BuildId = '553'; DatabaseHost = 'fixture'; SqlInstance = 'fixture'
      SourceDatabaseName = 'ATAPUtilities'
    }
    foreach ($key in $Extra.Keys) { $parameters[$key] = $Extra[$key] }
    Invoke-FlywayRehearsal @parameters -Confirm:$false
  }
  # A safe command-info target exercises captured invocation without running Flyway.
  function Invoke-CapturedFlyway1738 {
    [CmdletBinding(SupportsShouldProcess)]
    param($DatabaseName, $ExpectedDatabaseName, $SqlConnection, $Environment,
      $FlywayBasePath, $FlywaySqlMigrationsPath, $FlywayDataPath, $FlywayTomlPath,
      $PackageName, $PackageVersion, $FlywayAdditionalArgs, $FlywayCommand)
    $script:bindingCalls1738.Add(@{
        DatabaseName = $DatabaseName; ExpectedDatabaseName = $ExpectedDatabaseName
        SqlConnection = $SqlConnection; Operation = $FlywayCommand
      })
    [pscustomobject]@{ Success = $true }
  }
  function Invoke-CapturedFlyway1745 {
    [CmdletBinding(SupportsShouldProcess)]
    param($DatabaseName, $ExpectedDatabaseName, $SqlConnection, $Environment,
      $FlywayBasePath, $FlywaySqlMigrationsPath, $FlywayDataPath, $FlywayTomlPath,
      $PackageName, $PackageVersion, $FlywayAdditionalArgs, $FlywayCommand)
    $script:events605.Add($FlywayCommand)
    $script:routeCalls1745.Add(@{
        DatabaseName = $DatabaseName; ExpectedDatabaseName = $ExpectedDatabaseName
        SqlConnection = $SqlConnection; FlywayAdditionalArgs = $FlywayAdditionalArgs
      })
    [pscustomobject]@{ Success = $true }
  }
}

Describe 'Invoke-FlywayRehearsal exact source and clone safety' -Tag 'Unit' {
  BeforeEach {
    $script:oldStaging = $env:ATAP_DATABASE_PACKAGE_STAGING_ROOT
    $env:ATAP_DATABASE_PACKAGE_STAGING_ROOT = 'D:/ATAPArtifacts/Sprint0017/Task17.68.e/ExactTarget553/Virtual'
    $script:capturedFlyway = @{}
    Mock Write-PSFMessage {}
    Mock Resolve-DatabaseSqlConnection {
      [pscustomobject]@{ Connection = [pscustomobject]@{ State = 'Open'; DataSource = 'fixture' }; IsCallerOwned = $true }
    }
    Mock Invoke-DatabaseSqlNonQuery { 0 }
    Mock Connect-DbaInstance { 'synthetic-instance' }
    Mock Copy-DbaDatabase {}
    Mock Invoke-AceCommanderLoginFixtureSequence { throw 'Unexpected fixture sequence in generic rehearsal' }
    Mock New-Object { throw 'Unexpected verifier allocation in generic rehearsal' }
    Mock Test-Path { $true }
    Mock Invoke-Flyway {
      $script:capturedFlyway = @{} + $PesterBoundParameters
      [pscustomobject]@{ Success = $true }
    }
  }
  AfterEach {
    $env:ATAP_DATABASE_PACKAGE_STAGING_ROOT = $script:oldStaging
  }

  It 'preserves generic source cloning without an implicit expected target' {
    $result = Invoke-ExactRehearsal553Fixture @{ Application = 'OtherApp'; SourceDatabaseName = 'OtherSource' }
    $result.Success | Should -BeTrue
    $script:capturedFlyway.DatabaseName | Should -BeExactly 'OtherApp-rehearsal-553'
    $script:capturedFlyway.ContainsKey('ExpectedDatabaseName') | Should -BeFalse
    Should -Invoke Invoke-AceCommanderLoginFixtureSequence -Times 0 -Exactly -Scope It
    Should -Invoke New-Object -Times 0 -Exactly -Scope It
    Should -Invoke Copy-DbaDatabase -Times 1 -Exactly -Scope It -ParameterFilter {
      $Database -eq 'OtherSource' -and $NewName -eq 'OtherApp-rehearsal-553'
    }
  }

  It 'preserves generic empty-source rehearsal' {
    (Invoke-ExactRehearsal553Fixture @{ SourceDatabaseName = ''; Application = 'OtherApp' }).Success | Should -BeTrue
    $script:capturedFlyway.ContainsKey('ExpectedDatabaseName') | Should -BeFalse
    Should -Invoke Copy-DbaDatabase -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 1 -Exactly -Scope It -ParameterFilter {
      $CommandText.Contains('CREATE DATABASE [OtherApp-rehearsal-553]')
    }
  }

  It 'forwards the exact generated or explicit clone <Clone>' -ForEach @(
    @{ Clone = $null; ExpectedClone = 'ATAPUtilities-rehearsal-553' }
    @{ Clone = 'approved-copy-553'; ExpectedClone = 'approved-copy-553' }
  ) {
    $extra = @{ ExpectedSourceDatabaseName = 'ATAPUtilities' }
    if ($null -ne $Clone) { $extra.RehearsalDb = $Clone }
    $result = Invoke-ExactRehearsal553Fixture $extra
    $result.Success | Should -BeTrue
    $script:capturedFlyway.DatabaseName | Should -BeExactly $ExpectedClone
    $script:capturedFlyway.ExpectedDatabaseName | Should -BeExactly $ExpectedClone
    Should -Invoke Copy-DbaDatabase -Times 1 -Exactly -Scope It -ParameterFilter {
      $Database -eq 'ATAPUtilities' -and $NewName -eq $ExpectedClone
    }
  }

  It 'refuses original clone alias <Clone> before every DROP/copy/Flyway path even without binding' -ForEach @(
    @{ Clone = 'ATAPUtilities' }; @{ Clone = 'ataputilities' }; @{ Clone = 'ATAPUtilities ' }
  ) {
    { Invoke-ExactRehearsal553Fixture @{ RehearsalDb = $Clone } } | Should -Throw '*must differ from the source*'
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
    Should -Invoke Connect-DbaInstance -Times 0 -Exactly -Scope It
    Should -Invoke Copy-DbaDatabase -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-Flyway -Times 0 -Exactly -Scope It
  }

  It 'refuses mismatched or missing explicitly bound source <Source>' -ForEach @(
    @{ Source = 'OtherSource' }; @{ Source = 'ataputilities' }; @{ Source = '' }
  ) {
    { Invoke-ExactRehearsal553Fixture @{ SourceDatabaseName = $Source; ExpectedSourceDatabaseName = 'ATAPUtilities' } } |
      Should -Throw '*does not match ExpectedSourceDatabaseName*'
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
    Should -Invoke Copy-DbaDatabase -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-Flyway -Times 0 -Exactly -Scope It
  }

  It 'refuses unsafe bound clone before SQL or copy' {
    { Invoke-ExactRehearsal553Fixture @{ RehearsalDb = "unsafe'clone"; ExpectedSourceDatabaseName = 'ATAPUtilities' } } |
      Should -Throw '*safe exact catalog name*'
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
    Should -Invoke Copy-DbaDatabase -Times 0 -Exactly -Scope It
  }

  It 'retains cleanup of that same clone when the bound Flyway call fails' {
    Mock Invoke-Flyway { throw 'synthetic flyway failure' }
    { Invoke-ExactRehearsal553Fixture @{ ExpectedSourceDatabaseName = 'ATAPUtilities'; RehearsalDb = 'approved-copy-553' } } |
      Should -Throw '*synthetic flyway failure*'
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 2 -Exactly -Scope It -ParameterFilter {
      $CommandText.Contains('DROP DATABASE [approved-copy-553]') -and -not $CommandText.Contains('CREATE DATABASE')
    }
    # One initial DROP and one cleanup DROP occur in the clone path.
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 2 -Exactly -Scope It
  }
}

Describe 'Generic package metadata binding (623)' -Tag 'Unit' {
  BeforeEach {
    Mock Write-PSFMessage {}
    Mock Resolve-DatabaseSqlConnection {
      [pscustomobject]@{ Connection = [pscustomobject]@{ State = 'Open'; DataSource = 'fixture' }; IsCallerOwned = $true }
    }
    Mock Invoke-DatabaseSqlNonQuery { 0 }
    Mock Invoke-AceCommanderLoginFixtureSequence { throw 'Unexpected selected sequence' }
    Mock New-Object { throw 'Unexpected selected verifier' }
    Mock Invoke-Flyway {
      $script:metadata623 = @{} + $PesterBoundParameters
      [pscustomobject]@{ Success = $true }
    }
    $script:metadata623 = $null
  }
  It 'preserves generic metadata string binding for <Label>' -ForEach @(
    @{ Label = 'zero'; Value = 0; Expected = '0'; Present = $true }
    @{ Label = 'false'; Value = $false; Expected = 'False'; Present = $true }
    @{ Label = 'null'; Value = $null; Expected = ''; Present = $false }
    @{ Label = 'empty'; Value = ''; Expected = ''; Present = $false }
    @{ Label = 'valid'; Value = 'exact-623'; Expected = 'exact-623'; Present = $true }
  ) {
    Invoke-ExactRehearsal553Fixture @{
      SourceDatabaseName = ''; PackageName = $Value; PackageVersion = $Value
    } | Out-Null
    foreach ($key623 in @('PackageName', 'PackageVersion')) {
      $script:metadata623.ContainsKey($key623) | Should -Be $Present
      if ($Present) {
        $script:metadata623[$key623] | Should -BeOfType ([string])
        $script:metadata623[$key623] | Should -BeExactly $Expected
      }
    }
    Should -Invoke Invoke-Flyway -Times 1 -Exactly -Scope It
    Should -Invoke Invoke-AceCommanderLoginFixtureSequence -Times 0 -Exactly -Scope It
    Should -Invoke New-Object -Times 0 -Exactly -Scope It
  }
}

Describe 'Fixture sequence inside captured clone lifetime (605)' -Tag 'Unit' {
  BeforeEach {
    $script:oldStaging605 = $env:ATAP_DATABASE_PACKAGE_STAGING_ROOT
    $env:ATAP_DATABASE_PACKAGE_STAGING_ROOT = 'D:/ATAPArtifacts/mock605-staging'
    $script:events605 = [Collections.Generic.List[string]]::new()
    $script:openFailure605 = $false; $script:closeFailure605 = $false
    $script:disposeFailure605 = $false; $script:sequenceFailure605 = $false
    $script:sequenceRefusal605 = $false; $script:allocationFailure605 = $false
    $script:sequenceSeen605 = $null; $script:settings605 = $null
    $script:authAvailable605 = $true
    $script:master605 = [pscustomobject]@{ State = 'Open'; DataSource = 'fixture'; Retired = 0 }
    $script:master605 | Add-Member ScriptMethod get_ConnectionString {
      if (-not $script:authAvailable605) { return 'Data Source=fixture;Initial Catalog=master;User ID=redacted' }
      return 'Data Source=fixture;Initial Catalog=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=False'
    }
    $script:master605 | Add-Member ScriptMethod Close { $this.Retired++ }
    $script:master605 | Add-Member ScriptMethod Dispose { $this.Retired++ }
    $script:verifier605 = [pscustomobject]@{ State = 'Closed'; Disposed = $false }
    $script:verifier605 | Add-Member ScriptMethod set_ConnectionString {
      param($value)
      $script:settings605 = [Data.Common.DbConnectionStringBuilder]::new()
      $script:settings605.set_ConnectionString($value)
      $script:events605.Add('Configure')
    }
    $script:verifier605 | Add-Member ScriptMethod Open {
      $script:events605.Add('Open')
      if ($script:openFailure605) { throw 'SyntheticOpenFailure' }
      $this.State = 'Open'
    }
    $script:verifier605 | Add-Member ScriptMethod Close {
      $script:events605.Add('Close')
      if ($script:closeFailure605) { throw 'SyntheticCloseFailure' }
      $this.State = 'Closed'
    }
    $script:verifier605 | Add-Member ScriptMethod Dispose {
      $script:events605.Add('Dispose'); $this.Disposed = $true
      if ($script:disposeFailure605) { throw 'SyntheticDisposeFailure' }
    }
    $script:inputs605 = @{
      ExpectedSourceDatabaseName = 'ATAPUtilities'
      LoginFixturePath = 'D:/ATAPArtifacts/mock605/Login.sql'
      DecryptFixturePath = 'D:/ATAPArtifacts/mock605/Decrypt.sql'
      PackageName = 'ATAPUtilities.Database'; PackageVersion = 'fixture-605'
      FlywayBasePath = 'D:/ATAPArtifacts/mock605/package'
      FlywaySqlMigrationsPath = 'D:/ATAPArtifacts/mock605/package/db/migrations'
      FlywayDataPath = 'D:/ATAPArtifacts/mock605/package/db/seeds'
      FlywayTomlPath = 'D:/ATAPArtifacts/mock605/package/flyway.toml'
      FlywayAdditionalArgs = @('-defaultSchema=dbo', '-table=flyway_schema_history')
    }
    Mock Write-PSFMessage {}
    Mock Resolve-DatabaseSqlConnection { [pscustomobject]@{ Connection = $script:master605; IsCallerOwned = $true } }
    Mock Test-Path { $true }
    Mock Connect-DbaInstance { 'synthetic-instance' }
    Mock Copy-DbaDatabase { $script:events605.Add('Copy') }
    Mock Invoke-DatabaseSqlNonQuery { $script:events605.Add('DROP'); 0 }
    Mock New-Object {
      $script:events605.Add('Allocate')
      if ($script:allocationFailure605) { throw 'SyntheticAllocationFailure' }
      $script:verifier605
    }
    Mock Invoke-Flyway { throw 'Unexpected ordinary migrate' }
    Mock Invoke-AceCommanderLoginFixtureSequence {
      $script:events605.Add('Sequence')
      $script:sequenceSeen605 = @{
        Verifier = $SqlConnection; Login = $LoginFixturePath; Decrypt = $DecryptFixturePath
        Parameters = $FlywayParameters.Clone(); WasOpen = $SqlConnection.State
      }
      if ($script:sequenceFailure605) { throw 'SyntheticSequenceFailure' }
      [pscustomobject]@{ Success = (-not $script:sequenceRefusal605); Status = 'SequenceCompleted' }
    }
    $script:dependencyCommands1738 = @{}
    foreach ($name1738 in @('Invoke-AceCommanderLoginFixtureSequence', 'New-DatabaseConnectionParameterMap',
        'Invoke-DatabaseSqlNonQuery', 'New-DatabaseSqlCommand', 'Resolve-DatabaseSqlConnection',
        'Assert-DatabaseSqlConnectionIsOpen', 'Invoke-DatabaseSqlQuery', 'Copy-DbaDatabase', 'Connect-DbaInstance')) {
      $script:dependencyCommands1738[$name1738] = Get-Command $name1738 -CommandType Function -ErrorAction Stop
    }
  }
  AfterEach {
    $env:ATAP_DATABASE_PACKAGE_STAGING_ROOT = $script:oldStaging605
    if ($null -ne $script:settings605) { $script:settings605.Clear() }
  }

  It 'runs only sequence on same dedicated verifier for clone <Clone>' -ForEach @(
    @{ Clone = 'ATAPUtilities-rehearsal-553' }
    @{ Clone = 'approved-copy-605' }
  ) {
    $script:inputs605.RehearsalDb = $Clone
    $result = Invoke-ExactRehearsal553Fixture $script:inputs605
    $result.Success | Should -BeTrue
    [object]::ReferenceEquals($script:sequenceSeen605.Verifier, $script:verifier605) | Should -BeTrue
    [object]::ReferenceEquals($script:sequenceSeen605.Verifier, $script:master605) | Should -BeFalse
    $script:sequenceSeen605.WasOpen | Should -BeExactly 'Open'
    $script:sequenceSeen605.Login | Should -BeExactly $script:inputs605.LoginFixturePath
    $script:sequenceSeen605.Decrypt | Should -BeExactly $script:inputs605.DecryptFixturePath
    $map605 = $script:sequenceSeen605.Parameters
    $map605.DatabaseName | Should -BeExactly $Clone
    $map605.ExpectedDatabaseName | Should -BeExactly $Clone
    $map605.PackageName | Should -BeExactly 'ATAPUtilities.Database'
    $map605.PackageVersion | Should -BeExactly 'fixture-605'
    foreach ($pathKey605 in @('FlywayBasePath', 'FlywaySqlMigrationsPath', 'FlywayDataPath', 'FlywayTomlPath')) {
      $map605[$pathKey605] | Should -BeExactly $script:inputs605[$pathKey605]
    }
    ($map605.FlywayAdditionalArgs -join '|') | Should -BeExactly '-defaultSchema=dbo|-table=flyway_schema_history'
    foreach ($forbidden605 in @('SqlConnection', 'FlywayCommand', 'Files', 'FlywaySharedSqlMigrationsPath', 'DBConnectionStringSecretName', 'Settings')) {
      $map605.ContainsKey($forbidden605) | Should -BeFalse
    }
    [string]$script:settings605['Initial Catalog'] | Should -BeExactly $Clone
    [string]$script:settings605['Pooling'] | Should -BeExactly 'False'
    [string]$script:settings605['MultipleActiveResultSets'] | Should -BeExactly 'False'
    [string]$script:settings605['Enlist'] | Should -BeExactly 'False'
    [string]$script:settings605['Data Source'] | Should -BeExactly 'fixture'
    [string]$script:settings605['Encrypt'] | Should -BeExactly 'True'
    [string]$script:settings605['TrustServerCertificate'] | Should -BeExactly 'False'
    [string]$script:settings605['Integrated Security'] | Should -BeExactly 'True'
    ($script:events605 -join '|') | Should -BeExactly 'DROP|Copy|Allocate|Configure|Open|Sequence|Close|Dispose|DROP'
    $script:verifier605.Disposed | Should -BeTrue
    $script:master605.Retired | Should -Be 0
    Should -Invoke New-Object -Times 1 -Exactly -Scope It -ParameterFilter {
      $TypeName -ceq $script:master605.GetType().AssemblyQualifiedName
    }
    Should -Invoke Invoke-AceCommanderLoginFixtureSequence -Times 1 -Exactly -Scope It
    Should -Invoke Invoke-Flyway -Times 0 -Exactly -Scope It
  }

  It 'binds and retains the fixture Flyway command before clone effects for <Binding>' -ForEach @(
    @{ Binding = 'current source'; Reload = $false }
    @{ Binding = 'absent'; Reload = $true }
    @{ Binding = 'module-backed missing expected target'; Reload = $true }
    @{ Binding = 'stale source missing expected target'; Reload = $true }
    @{ Binding = 'stale source missing SQL connection'; Reload = $true }
  ) {
    $script:bindingCalls1738 = [Collections.Generic.List[hashtable]]::new()
    $script:bindingLookups1738 = 0; $script:bindingAfterClone1738 = $false
    $script:bindingCase1738 = $Binding
    $script:currentCommand1738 = Get-Command Invoke-CapturedFlyway1738 -CommandType Function
    $script:siblingPath1738 = Join-Path $public 'Invoke-Flyway.ps1'
    Mock Join-Path { [IO.Path]::Combine([string]$Path, [string]$ChildPath) }
    Mock Join-Path { $script:siblingPath1738 } -ParameterFilter { $ChildPath -eq 'Invoke-Flyway.ps1' }
    Mock Get-Command {
      if (-not $script:dependencyCommands1738.ContainsKey([string]$Name)) { throw 'Unexpected dependency lookup' }
      $script:dependencyCommands1738[[string]$Name]
    }
    Mock Get-Command {
      $script:bindingLookups1738++
      if ($script:bindingAfterClone1738) { throw 'Unexpected late name lookup after clone effects' }
      if ($script:bindingLookups1738 -gt 1 -or $script:bindingCase1738 -eq 'current source') {
        return $script:currentCommand1738
      }
      if ($script:bindingCase1738 -eq 'absent') { return $null }
      $parameters1738 = @{}
      if ($script:bindingCase1738 -eq 'stale source missing SQL connection') {
        $parameters1738.ExpectedDatabaseName = $true
      } else { $parameters1738.SqlConnection = $true }
      [pscustomobject]@{
        ModuleName = $(if ($script:bindingCase1738 -like 'module-backed*') { 'OldDatabaseModule' } else { '' })
        Parameters = $parameters1738
      }
    } -ParameterFilter { $Name -eq 'Invoke-Flyway' }
    Mock Copy-DbaDatabase {
      $script:bindingLookups1738 | Should -Be 2
      $script:bindingAfterClone1738 = $true
      $script:events605.Add('Copy')
    }
    $script:verifier605 | Add-Member NoteProperty ClientConnectionId ([guid]::NewGuid())
    $script:inputs605.Remove('LoginFixturePath'); $script:inputs605.Remove('DecryptFixturePath')
    $script:inputs605.OrganizationFixturePath = [IO.Path]::GetFullPath((Join-Path $public '../../../Database/Verify/AceCommander/Verify_Organization_V00210.sql'))
    Mock Invoke-DatabaseSqlQuery {
      if ($CommandText -like '*DB_ID(@CloneName)*') { return [pscustomobject]@{ Absent = 1 } }
      if ($CommandText -ceq 'SELECT [version], [success] FROM dbo.flyway_schema_history ORDER BY [installed_rank];') {
        return @('00010','00030','00040','00050','00060','00070','00080','00090','00100','00110','00120','00130','00140','00150','00160','00170','00180','00190','00200','00210') | ForEach-Object { [pscustomobject]@{ version = $_; success = $true } }
      }
      if ($CommandText.StartsWith("DECLARE @VerificationPhase nvarchar(8)=N'Before';")) { return [pscustomobject]@{ FixturePhase = 'Before210' } }
      if ($CommandText.StartsWith("DECLARE @VerificationPhase nvarchar(8)=N'After';")) { return [pscustomobject]@{ FixturePhase = 'After210' } }
      throw 'Unexpected organization query'
    }
    Mock New-DatabaseSqlCommand {
      $command1738 = [pscustomobject]@{ Parameters = @{ '@ExpectedCatalog' = [pscustomobject]@{ SqlDbType = $null; Size = 0 } } }
      $command1738 | Add-Member ScriptMethod ExecuteNonQuery { 0 }
      $command1738 | Add-Member ScriptMethod Dispose {}
      $command1738
    }

    (Invoke-ExactRehearsal553Fixture $script:inputs605).Success | Should -BeTrue

    ($script:bindingCalls1738.Operation -join '|') | Should -BeExactly 'validate|migrate|validate'
    foreach ($call1738 in $script:bindingCalls1738) {
      $call1738.DatabaseName | Should -BeExactly 'ATAPUtilities-rehearsal-553'
      $call1738.ExpectedDatabaseName | Should -BeExactly 'ATAPUtilities-rehearsal-553'
      [object]::ReferenceEquals($call1738.SqlConnection, $script:verifier605) | Should -BeTrue
    }
    Should -Invoke Join-Path -Times ([int]$Reload) -Exactly -Scope It -ParameterFilter { $ChildPath -eq 'Invoke-Flyway.ps1' }
    Should -Invoke Get-Command -Times 2 -Exactly -Scope It -ParameterFilter { $Name -eq 'Invoke-Flyway' }
    Should -Invoke Copy-DbaDatabase -Times 1 -Exactly -Scope It
    ($script:events605 | Select-Object -Last 3) -join '|' | Should -BeExactly 'Close|Dispose|DROP'
  }

  It 'refuses a still-incompatible sibling contract before resolver and clone effects' {
    Mock Get-Command {
      if (-not $script:dependencyCommands1738.ContainsKey([string]$Name)) { throw 'Unexpected dependency lookup' }
      $script:dependencyCommands1738[[string]$Name]
    }
    Mock Get-Command { [pscustomobject]@{ ModuleName = ''; Parameters = @{ SqlConnection = $true } } } -ParameterFilter { $Name -eq 'Invoke-Flyway' }
    { Invoke-ExactRehearsal553Fixture $script:inputs605 } | Should -Throw '*current sibling Invoke-Flyway source contract*'
    Should -Invoke Resolve-DatabaseSqlConnection -Times 0 -Exactly -Scope It
    Should -Invoke Copy-DbaDatabase -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
  }

  Context 'UNIT1745 organization predecessor route' {
    BeforeEach {
      $script:verifier605 | Add-Member NoteProperty ClientConnectionId ([guid]::NewGuid())
      $script:inputs605.OrganizationFixturePath = [IO.Path]::GetFullPath((Join-Path $public '../../../Database/Verify/AceCommander/Verify_Organization_V00210.sql'))
      $script:versions1745 = @('00010','00030','00040','00050','00060','00070','00080','00090','00100','00110','00120','00130','00140','00150','00160','00170','00180','00190','00200','00210')
      $script:history1745 = @($script:versions1745[0..13] | ForEach-Object { [pscustomobject]@{ version = $_; success = $true } })
      $script:predecessorFault1745 = ''; $script:routeCalls1745 = [Collections.Generic.List[hashtable]]::new()
      $script:routeCommand1745 = Get-Command Invoke-CapturedFlyway1745 -CommandType Function
      Mock Get-Command {
        if (-not $script:dependencyCommands1738.ContainsKey([string]$Name)) { throw 'Unexpected dependency lookup' }
        $script:dependencyCommands1738[[string]$Name]
      }
      Mock Get-Command { $script:routeCommand1745 } -ParameterFilter { $Name -eq 'Invoke-Flyway' }
      Mock Invoke-DatabaseSqlQuery {
        if ($CommandText -like '*DB_ID(@CloneName)*') { return [pscustomobject]@{ Absent = 1 } }
        if ($CommandText -ceq 'SELECT [version], [success] FROM dbo.flyway_schema_history ORDER BY [installed_rank];') {
          $script:events605.Add('History'); return $script:history1745
        }
        if ($CommandText.StartsWith("DECLARE @VerificationPhase nvarchar(8)=N'Before';")) {
          $script:events605.Add('Before210'); return [pscustomobject]@{ FixturePhase = 'Before210' }
        }
        if ($CommandText.StartsWith("DECLARE @VerificationPhase nvarchar(8)=N'After';")) {
          $script:events605.Add('After210'); return [pscustomobject]@{ FixturePhase = 'After210' }
        }
        throw 'Unexpected organization query'
      }
      Mock New-DatabaseSqlCommand {
        $command1745 = [pscustomobject]@{ Parameters = @{ '@ExpectedCatalog' = [pscustomobject]@{ SqlDbType = $null; Size = 0 } } }
        $command1745 | Add-Member ScriptMethod ExecuteNonQuery { 0 }
        $command1745 | Add-Member ScriptMethod Dispose {}
        $command1745
      }
      Mock Invoke-AceCommanderLoginFixtureSequence {
        [object]::ReferenceEquals($SqlConnection, $script:verifier605) | Should -BeTrue
        $SqlConnection.State | Should -BeExactly 'Open'
        $FlywayParameters.ExpectedDatabaseName | Should -BeExactly 'ATAPUtilities-rehearsal-553'
        $LoginFixturePath | Should -BeExactly $script:inputs605.LoginFixturePath
        $DecryptFixturePath | Should -BeExactly $script:inputs605.DecryptFixturePath
        if ($script:predecessorFault1745 -eq 'GuestConflict') { throw 'Pinned predecessor Guest conflict' }
        $script:events605.Add('Login160'); $script:events605.Add('Decrypt170')
        if ($script:predecessorFault1745 -eq 'SessionChanged') { $SqlConnection.ClientConnectionId = [guid]::NewGuid() }
        $outcome1745 = [pscustomobject]@{
          Success = ($script:predecessorFault1745 -ne 'ReportedFailure')
          CompletedPhases = @('before160','migrate00160','after160','before170','migrate00170','after170')
        }
        $outcome1745
        if ($script:predecessorFault1745 -eq 'MultipleResults') { $outcome1745 }
      }
    }

    It 'routes exact V<Baseline> through its existing phases on the same clone session' -ForEach @(
      @{ Baseline = 150; Count = 14; PredecessorCalls = 1 }
      @{ Baseline = 170; Count = 16; PredecessorCalls = 0 }
      @{ Baseline = 210; Count = 20; PredecessorCalls = 0 }
    ) {
      $script:history1745 = @($script:versions1745[0..($Count-1)] | ForEach-Object { [pscustomobject]@{ version = $_; success = $true } })
      if ($Baseline -ne 150) { $script:inputs605.Remove('LoginFixturePath'); $script:inputs605.Remove('DecryptFixturePath') }

      (Invoke-ExactRehearsal553Fixture $script:inputs605).Success | Should -BeTrue

      $expected1745 = 'Copy|Allocate|Configure|Open|History|'
      if ($Baseline -eq 150) { $expected1745 += 'Login160|Decrypt170|' }
      $expected1745 += 'Before210|validate|migrate|validate|After210|Close|Dispose|DROP'
      ($script:events605 -join '|') | Should -BeExactly $expected1745
      Should -Invoke Invoke-AceCommanderLoginFixtureSequence -Times $PredecessorCalls -Exactly -Scope It
      $script:routeCalls1745.Count | Should -Be 3
      foreach ($call1745 in $script:routeCalls1745) {
        $call1745.DatabaseName | Should -BeExactly 'ATAPUtilities-rehearsal-553'
        $call1745.ExpectedDatabaseName | Should -BeExactly 'ATAPUtilities-rehearsal-553'
        [object]::ReferenceEquals($call1745.SqlConnection, $script:verifier605) | Should -BeTrue
        $call1745.FlywayAdditionalArgs | Should -Contain '-target=00210'
      }
      Should -Invoke Copy-DbaDatabase -Times 1 -Exactly -Scope It
      Should -Invoke Invoke-DatabaseSqlNonQuery -Times 1 -Exactly -Scope It
      $script:master605.Retired | Should -Be 0
    }

    It 'refuses unsupported or unsuccessful clone history <Fault> before migrations' -ForEach @(
      @{ Fault = 'V160' }; @{ Fault = 'V200' }; @{ Fault = 'WrongVersion' }
      @{ Fault = 'FailedRow' }; @{ Fault = 'NullSuccess' }
    ) {
      switch ($Fault) {
        'V160' { $script:history1745 += [pscustomobject]@{ version = '00160'; success = $true } }
        'V200' { $script:history1745 = @($script:versions1745[0..18] | ForEach-Object { [pscustomobject]@{ version = $_; success = $true } }) }
        'WrongVersion' { $script:history1745[13].version = '00140' }
        'FailedRow' { $script:history1745[13].success = $false }
        'NullSuccess' { $script:history1745[13].success = $null }
      }
      { Invoke-ExactRehearsal553Fixture $script:inputs605 } | Should -Throw '*Organization rehearsal requires*'
      Should -Invoke Invoke-AceCommanderLoginFixtureSequence -Times 0 -Exactly -Scope It
      $script:routeCalls1745.Count | Should -Be 0
      ($script:events605 | Select-Object -Last 3) -join '|' | Should -BeExactly 'Close|Dispose|DROP'
    }

    It 'stops after predecessor refusal <Fault> without organization migration or retry' -ForEach @(
      @{ Fault = 'GuestConflict' }; @{ Fault = 'ReportedFailure' }
      @{ Fault = 'MultipleResults' }; @{ Fault = 'SessionChanged' }
    ) {
      $script:predecessorFault1745 = $Fault
      { Invoke-ExactRehearsal553Fixture $script:inputs605 } | Should -Throw
      Should -Invoke Invoke-AceCommanderLoginFixtureSequence -Times 1 -Exactly -Scope It
      $script:routeCalls1745.Count | Should -Be 0
      $script:events605 | Should -Not -Contain 'Before210'
      ($script:events605 | Select-Object -Last 3) -join '|' | Should -BeExactly 'Close|Dispose|DROP'
    }

    It 'refuses V150 without predecessor paths before migrations and still cleans the clone' {
      $script:inputs605.Remove('LoginFixturePath'); $script:inputs605.Remove('DecryptFixturePath')
      { Invoke-ExactRehearsal553Fixture $script:inputs605 } | Should -Throw '*requires paired Login/Decrypt*'
      Should -Invoke Invoke-AceCommanderLoginFixtureSequence -Times 0 -Exactly -Scope It
      $script:routeCalls1745.Count | Should -Be 0
      ($script:events605 | Select-Object -Last 3) -join '|' | Should -BeExactly 'Close|Dispose|DROP'
    }
  }

  It 'refuses missing opt-in field <Missing> before resolver or clone effects' -ForEach @(
    @{ Missing = 'LoginFixturePath' }; @{ Missing = 'DecryptFixturePath' }
    @{ Missing = 'ExpectedSourceDatabaseName' }; @{ Missing = 'PackageName' }
    @{ Missing = 'PackageVersion' }; @{ Missing = 'FlywayTomlPath' }
  ) {
    $script:inputs605.Remove($Missing)
    { Invoke-ExactRehearsal553Fixture $script:inputs605 } | Should -Throw '*Fixture rehearsal requires explicit*'
    Should -Invoke Resolve-DatabaseSqlConnection -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
    Should -Invoke Copy-DbaDatabase -Times 0 -Exactly -Scope It
    Should -Invoke New-Object -Times 0 -Exactly -Scope It
  }

  It 'refuses raw package identity <Label> before clone effects' -ForEach @(
    @{ Label = 'null'; Value = $null }; @{ Label = 'numeric'; Value = 605 }
    @{ Label = 'array'; Value = @('fixture-605') }; @{ Label = 'empty'; Value = '' }
    @{ Label = 'padding'; Value = 'fixture-605 ' }
  ) {
    $script:inputs605.PackageVersion = $Value
    { Invoke-ExactRehearsal553Fixture $script:inputs605 } | Should -Throw '*Fixture rehearsal requires explicit*'
    Should -Invoke Resolve-DatabaseSqlConnection -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
  }

  It 'refuses conflicting configuration <Label> before effects' -ForEach @(
    @{ Label = 'target'; Extra = @{ FlywayAdditionalArgs = @('-target=00170') } }
    @{ Label = 'shared'; Extra = @{ FlywaySharedSqlMigrationsPath = 'D:/ATAPArtifacts/other' } }
    @{ Label = 'files'; Extra = @{ Files = @('other.sql') } }
    @{ Label = 'relative fixture'; Extra = @{ LoginFixturePath = 'Login.sql' } }
  ) {
    foreach ($extraKey605 in $Extra.Keys) { $script:inputs605[$extraKey605] = $Extra[$extraKey605] }
    { Invoke-ExactRehearsal553Fixture $script:inputs605 } | Should -Throw '*Fixture rehearsal*'
    Should -Invoke Resolve-DatabaseSqlConnection -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
  }

  It 'refuses redacted unrecoverable authentication before every DROP' {
    $script:authAvailable605 = $false
    { Invoke-ExactRehearsal553Fixture $script:inputs605 } | Should -Throw '*Cannot preserve resolved authentication*'
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
    Should -Invoke Copy-DbaDatabase -Times 0 -Exactly -Scope It
    Should -Invoke New-Object -Times 0 -Exactly -Scope It
  }

  It 'retires verifier before outer DROP on failure <Failure>' -ForEach @(
    @{ Failure = 'open'; Message = '*creation/open failed*' }
    @{ Failure = 'sequence'; Message = '*SyntheticSequenceFailure*' }
    @{ Failure = 'refusal'; Message = '*did not report success*' }
    @{ Failure = 'close'; Message = '*close failed*' }
    @{ Failure = 'dispose'; Message = '*disposal failed*' }
  ) {
    switch ($Failure) {
      'open' { $script:openFailure605 = $true }
      'sequence' { $script:sequenceFailure605 = $true }
      'refusal' { $script:sequenceRefusal605 = $true }
      'close' { $script:closeFailure605 = $true }
      'dispose' { $script:disposeFailure605 = $true }
    }
    { Invoke-ExactRehearsal553Fixture $script:inputs605 } | Should -Throw $Message
    ($script:events605 | Select-Object -Last 3) -join '|' | Should -BeExactly 'Close|Dispose|DROP'
    $script:master605.Retired | Should -Be 0
    Should -Invoke Invoke-Flyway -Times 0 -Exactly -Scope It
    Should -Invoke New-Object -Times 1 -Exactly -Scope It
  }

  It 'cleans clone when allocation fails without retiring borrowed master' {
    $script:allocationFailure605 = $true
    { Invoke-ExactRehearsal553Fixture $script:inputs605 } | Should -Throw '*creation/open failed*'
    ($script:events605 -join '|') | Should -BeExactly 'DROP|Copy|Allocate|DROP'
    $script:master605.Retired | Should -Be 0
    Should -Invoke Invoke-AceCommanderLoginFixtureSequence -Times 0 -Exactly -Scope It
  }

  It 'does not allocate verifier or execute sequence under WhatIf' {
    Invoke-FlywayRehearsal -Application ATAPUtilities -BuildId 605 -SourceDatabaseName ATAPUtilities @script:inputs605 -WhatIf
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
    Should -Invoke Copy-DbaDatabase -Times 0 -Exactly -Scope It
    Should -Invoke New-Object -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-AceCommanderLoginFixtureSequence -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-Flyway -Times 0 -Exactly -Scope It
  }

  It 'refuses a factory returning borrowed master without retiring it' {
    Mock New-Object { $script:master605 }
    { Invoke-ExactRehearsal553Fixture $script:inputs605 } | Should -Throw '*creation/open failed*'
    $script:master605.Retired | Should -Be 0
    Should -Invoke Invoke-AceCommanderLoginFixtureSequence -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 2 -Exactly -Scope It
  }

  It 'does not allocate or run sequence after clone copy fails' {
    Mock Copy-DbaDatabase { throw 'SyntheticCopyFailure' }
    { Invoke-ExactRehearsal553Fixture $script:inputs605 } | Should -Throw '*SyntheticCopyFailure*'
    Should -Invoke New-Object -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-AceCommanderLoginFixtureSequence -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 2 -Exactly -Scope It
    $script:master605.Retired | Should -Be 0
  }

  It 'preserves a resolved credential object in memory without a vault lookup' {
    $script:authAvailable605 = $false
    $credential605 = [pscustomobject]@{ Kind = 'synthetic-credential-marker' }
    $script:master605 | Add-Member NoteProperty Credential $credential605
    $script:verifier605 | Add-Member NoteProperty Credential $null
    Invoke-ExactRehearsal553Fixture $script:inputs605 | Out-Null
    [object]::ReferenceEquals($script:verifier605.Credential, $credential605) | Should -BeTrue
    Should -Invoke Resolve-DatabaseSqlConnection -Times 1 -Exactly -Scope It
    Should -Invoke New-Object -Times 1 -Exactly -Scope It
  }
}

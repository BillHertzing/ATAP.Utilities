#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
# Contract-mode rehearsal chain (Impl-Rehearsal-Parameterize, Phase A). Offline: every resolver, SQL,
# copy and Flyway boundary is mocked or replaced by a recording double. The real committed contract
# (Database/Verify/RehearsalBoundaries.json) and its pinned verifier files are used.
BeforeAll {
  $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
  $public = Join-Path $repositoryRoot 'src/ATAP.Utilities.DatabaseManagement.Powershell/public'
  $private = Join-Path $repositoryRoot 'src/ATAP.Utilities.DatabaseManagement.Powershell/private'
  Import-Module PSFramework -ErrorAction Stop
  . (Join-Path $private 'DatabaseSqlConnection.Helpers.ps1')
  . (Join-Path $private 'DatabaseSqlCommand.Helpers.ps1')
  . (Join-Path $private 'Read-RehearsalBoundaryContract.ps1')
  foreach ($file in @('Resolve-DatabaseSqlConnection.ps1', 'Invoke-FlywayRehearsal.ps1')) { . (Join-Path $public $file) }
  function Connect-DbaInstance { param($SqlInstance, [switch]$TrustServerCertificate, [switch]$AllowTrustServerCertificate) throw 'Unmocked connection forbidden' }
  function Copy-DbaDatabase { [CmdletBinding(SupportsShouldProcess)] param($Source, $Destination, $Database, $NewName, [switch]$BackupRestore, $SharedPath, [switch]$WithReplace, [switch]$Force, [switch]$EnableException) throw 'Unmocked copy forbidden' }
  # The rehearsal invokes the captured Invoke-Flyway CommandInfo, which a Pester mock does not
  # intercept, so this double records each call and simulates the clone history it would leave.
  function Invoke-Flyway {
    [CmdletBinding(SupportsShouldProcess)]
    param([object]$SqlConnection, $DatabaseName, $ExpectedDatabaseName, $Environment, $FlywayCommand,
      $FlywayBasePath, $FlywaySqlMigrationsPath, $FlywayDataPath, $FlywayTomlPath, $PackageName, $PackageVersion,
      [string[]]$FlywayAdditionalArgs, $FlywayExecutablePath)
    $script:flywayCalls.Add([pscustomobject]@{ Command = $FlywayCommand; Arguments = @($FlywayAdditionalArgs)
        ExpectedDatabaseName = $ExpectedDatabaseName; PackageVersion = $PackageVersion; SqlConnection = $SqlConnection })
    $script:events.Add($FlywayCommand)
    $target = @($FlywayAdditionalArgs | Where-Object { $_ -like '-target=*' })
    if ($FlywayCommand -ceq 'migrate' -and $target.Count -eq 1 -and $script:fault -cne 'MigrateLeavesHistory') {
      $version = $target[0].Substring(8)
      $script:historyCount = @($script:versions | Where-Object { [string]::CompareOrdinal($_, $version) -le 0 }).Count
    }
    if ($script:fault -ceq "SessionChangeOn$FlywayCommand") { $SqlConnection.ClientConnectionId = [guid]::NewGuid() }
    [pscustomobject]@{ Success = ($script:fault -cne "Fail$FlywayCommand") }
  }
  function Invoke-AceCommanderLoginFixtureSequence {
    [CmdletBinding(SupportsShouldProcess)]
    param([object]$SqlConnection, $LoginFixturePath, $DecryptFixturePath, [hashtable]$FlywayParameters,
      [string]$LoginFixtureSha256, [string]$DecryptFixtureSha256)
    $script:events.Add('LoginDecrypt')
    $script:sequenceSeen = @{ Verifier = $SqlConnection; Login = $LoginFixturePath; Decrypt = $DecryptFixturePath
      LoginSha = $LoginFixtureSha256; DecryptSha = $DecryptFixtureSha256; Parameters = $FlywayParameters.Clone() }
    $script:historyCount = @($script:versions | Where-Object { [string]::CompareOrdinal($_, '00170') -le 0 }).Count
    [pscustomobject]@{ Success = $true; CompletedPhases = @('before160', 'migrate00160', 'after160', 'before170', 'migrate00170', 'after170') }
  }
  $script:contractPath = Join-Path $repositoryRoot 'Database/Verify/RehearsalBoundaries.json'
  $script:allNames = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'Database/Flyway/SQL') -Filter 'V*.sql' -File | ForEach-Object Name | Sort-Object)
  $script:historyQuery = 'SELECT [version], [success] FROM dbo.flyway_schema_history ORDER BY [installed_rank];'
  function Set-PackageMigrations([string[]]$Names) {
    $folder = Join-Path $TestDrive ('migrations-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $folder
    foreach ($name in $Names) { [IO.File]::WriteAllText((Join-Path $folder $name), '') }
    $script:versions = @($Names | Sort-Object | ForEach-Object { $_.Substring(1, 5) })
    $script:parameters.FlywaySqlMigrationsPath = $folder
  }
  function Set-Baseline([string]$Version) {
    $script:historyCount = @($script:versions | Where-Object { [string]::CompareOrdinal($_, $Version) -le 0 }).Count
  }
}

Describe 'Invoke-FlywayRehearsal contract chain' -Tag 'Unit', 'RehearsalContract' {
  BeforeEach {
    $script:oldStaging = [Environment]::GetEnvironmentVariable('ATAP_DATABASE_PACKAGE_STAGING_ROOT', 'Process')
    $env:ATAP_DATABASE_PACKAGE_STAGING_ROOT = $TestDrive
    $script:events = [Collections.Generic.List[string]]::new()
    $script:flywayCalls = [Collections.Generic.List[object]]::new()
    $script:boundKeys = [Collections.Generic.List[string]]::new()
    $script:fault = ''; $script:present = $false; $script:sequenceSeen = $null; $script:historyFault = ''
    $script:master = [pscustomobject]@{ State = 'Open'; DataSource = 'synthetic' }
    $script:master | Add-Member ScriptMethod get_ConnectionString { 'Data Source=synthetic;Initial Catalog=master;Integrated Security=True' }
    $script:master | Add-Member ScriptMethod Close { $script:events.Add('MasterClose') }
    $script:master | Add-Member ScriptMethod Dispose { $script:events.Add('MasterDispose') }
    $script:verifier = [pscustomobject]@{ State = 'Closed'; ClientConnectionId = [guid]::NewGuid() }
    $script:verifier | Add-Member ScriptMethod set_ConnectionString { param($value) }
    $script:verifier | Add-Member ScriptMethod Open { $this.State = 'Open'; $script:events.Add('Open') }
    $script:verifier | Add-Member ScriptMethod Close { $this.State = 'Closed'; $script:events.Add('Close') }
    $script:verifier | Add-Member ScriptMethod Dispose { $script:events.Add('Dispose') }
    $package = Join-Path $TestDrive 'package'
    $script:parameters = @{ Application = 'ATAPUtilities'; BuildId = '1700'; SourceDatabaseName = 'ATAPUtilities'
      ExpectedSourceDatabaseName = 'ATAPUtilities'; FixtureContractPath = $script:contractPath
      PackageName = 'ATAPUtilities.Database'; PackageVersion = 'synthetic-param-1700'; FlywayBasePath = $package
      FlywaySqlMigrationsPath = ''; FlywayDataPath = (Join-Path $package 'db/seeds')
      FlywayTomlPath = (Join-Path $package 'flyway.toml'); FlywayAdditionalArgs = @('-defaultSchema=dbo', '-table=flyway_schema_history'); Confirm = $false }
    Set-PackageMigrations $script:allNames
    Set-Baseline '00210'
    Mock Write-PSFMessage {}
    Mock Resolve-DatabaseSqlConnection { [pscustomobject]@{ Connection = $script:master; IsCallerOwned = $true } }
    Mock Test-Path { $true }
    Mock Connect-DbaInstance { 'synthetic-instance' }
    Mock Copy-DbaDatabase { $script:events.Add('Copy') }
    Mock Invoke-DatabaseSqlNonQuery { $script:events.Add('Drop'); 0 }
    Mock New-Object { $script:verifier }
    Mock New-DatabaseSqlCommand {
      $script:boundKeys.Add([string]$Parameters.ContextKey)
      $command = [pscustomobject]@{ Parameters = @{
          '@ContextKey' = [pscustomobject]@{ SqlDbType = $null; Size = 0 }
          '@ExpectedCatalog' = [pscustomobject]@{ SqlDbType = $null; Size = 0 } } }
      $command | Add-Member ScriptMethod ExecuteNonQuery { 0 }
      $command | Add-Member ScriptMethod Dispose { }
      $command
    }
    Mock Invoke-DatabaseSqlQuery {
      if ($null -ne $Parameters -and $Parameters.ContainsKey('CloneName')) { return [pscustomobject]@{ Absent = [int](-not $script:present) } }
      if ($CommandText -ceq $script:historyQuery) {
        $script:events.Add('History')
        $rows = @($script:versions | Select-Object -First $script:historyCount | ForEach-Object { [pscustomobject]@{ version = $_; success = $true } })
        if ($script:historyFault -ceq 'WrongVersion' -and $rows.Count -gt 13) { $rows[13].version = '00145' }
        if ($script:historyFault -ceq 'FailedRow' -and $rows.Count -gt 0) { $rows[-1].success = $false }
        return $rows
      }
      $phase = if ($CommandText.StartsWith("DECLARE @VerificationPhase nvarchar(8)=N'Before';")) { 'Before' }
        elseif ($CommandText.StartsWith("DECLARE @VerificationPhase nvarchar(8)=N'After';")) { 'After' }
        else { throw 'Unexpected query' }
      $tag = if ($CommandText.Contains("SESSION_CONTEXT(N'ATAP.Organization210.ExpectedCatalog')")) { '210' }
        elseif ($CommandText.Contains("SESSION_CONTEXT(N'ATAP.AceCommanderRole220.ExpectedCatalog')")) { '220' }
        else { throw 'Unexpected verifier text' }
      $script:events.Add("$phase$tag")
      if ($script:fault -ceq "WrongMarker$phase$tag") { return [pscustomobject]@{ FixturePhase = "$phase" + '999' } }
      [pscustomobject]@{ FixturePhase = "$phase$tag" }
    }
  }
  AfterEach {
    $value = $script:oldStaging
    if ($null -eq $value) { $value = [NullString]::Value }
    [Environment]::SetEnvironmentVariable('ATAP_DATABASE_PACKAGE_STAGING_ROOT', $value, 'Process')
  }

  Context 'admitted baselines for the 0.1.26-shaped package (head 00220)' {
    It 'walks 00210 then 00220 from a twenty-row V210 clone (the 0.1.26 tier state)' {
      $result = Invoke-FlywayRehearsal @script:parameters
      $result.Success | Should -BeTrue
      $result.FlywayResult.BaselineVersion | Should -BeExactly '00210'
      $result.FlywayResult.TargetVersion | Should -BeExactly '00220'
      ($result.FlywayResult.CompletedPhases -join ',') | Should -BeExactly 'before210,validate,migrate210,validate,after210,before220,validate,migrate220,validate,after220'
      ($script:events -join '|') | Should -BeExactly ('Copy|Open|History|Before210|validate|migrate|validate|After210|History|' +
        'Before220|validate|migrate|validate|After220|History|Close|Dispose|Drop')
      ($script:boundKeys -join '|') | Should -BeExactly 'ATAP.Organization210.ExpectedCatalog|ATAP.AceCommanderRole220.ExpectedCatalog'
      $script:flywayCalls.Count | Should -Be 6
      ($script:flywayCalls[0].Arguments -join '|') | Should -BeExactly '-defaultSchema=dbo|-table=flyway_schema_history|-target=00210|-ignoreMigrationPatterns=*:pending'
      ($script:flywayCalls[1].Arguments -join '|') | Should -BeExactly '-defaultSchema=dbo|-table=flyway_schema_history|-target=00210'
      ($script:flywayCalls[2].Arguments -join '|') | Should -BeExactly '-defaultSchema=dbo|-table=flyway_schema_history|-target=00210|-ignoreMigrationPatterns=*:pending'
      ($script:flywayCalls[3].Arguments -join '|') | Should -BeExactly '-defaultSchema=dbo|-table=flyway_schema_history|-target=00220|-ignoreMigrationPatterns=*:pending'
      ($script:flywayCalls[4].Arguments -join '|') | Should -BeExactly '-defaultSchema=dbo|-table=flyway_schema_history|-target=00220'
      ($script:flywayCalls[5].Arguments -join '|') | Should -BeExactly '-defaultSchema=dbo|-table=flyway_schema_history|-target=00220|-ignoreMigrationPatterns='
      foreach ($call in $script:flywayCalls) {
        $call.ExpectedDatabaseName | Should -BeExactly 'ATAPUtilities-rehearsal-1700'
        $call.PackageVersion | Should -BeExactly 'synthetic-param-1700'
        [object]::ReferenceEquals($call.SqlConnection, $script:verifier) | Should -BeTrue
      }
      Should -Invoke Copy-DbaDatabase -Times 1 -Exactly -ParameterFilter { -not $WithReplace -and -not $Force }
      Should -Invoke Invoke-DatabaseSqlNonQuery -Times 1 -Exactly
    }
    It 're-verifies only 00220 from an already-V220 (twenty-one-row) clone' {
      Set-Baseline '00220'
      $result = Invoke-FlywayRehearsal @script:parameters
      ($result.FlywayResult.CompletedPhases -join ',') | Should -BeExactly 'before220,validate,migrate220,validate,after220'
      $script:flywayCalls.Count | Should -Be 3
      @($script:flywayCalls | Where-Object { $_.Arguments -contains '-target=00210' }).Count | Should -Be 0
    }
    It 'walks 00210 and 00220 from a sixteen-row V170 clone without the Login/Decrypt sequence' {
      Set-Baseline '00170'
      $result = Invoke-FlywayRehearsal @script:parameters
      ($result.FlywayResult.CompletedPhases -join ',') | Should -BeExactly 'before210,validate,migrate210,validate,after210,before220,validate,migrate220,validate,after220'
      $script:sequenceSeen | Should -BeNullOrEmpty
    }
    It 'runs the pinned Login/Decrypt sequence with contract paths and pins from a fourteen-row V150 clone' {
      Set-Baseline '00150'
      $result = Invoke-FlywayRehearsal @script:parameters
      ($result.FlywayResult.CompletedPhases -join ',') | Should -BeExactly ('before160,migrate00160,after160,before170,migrate00170,after170,' +
        'before210,validate,migrate210,validate,after210,before220,validate,migrate220,validate,after220')
      $script:sequenceSeen.Login | Should -BeExactly ([IO.Path]::GetFullPath((Join-Path $repositoryRoot 'Database/Verify/AceCommander/Verify_Login_V00160_ExactCatalog.sql')))
      $script:sequenceSeen.Decrypt | Should -BeExactly ([IO.Path]::GetFullPath((Join-Path $repositoryRoot 'Database/Verify/AceCommander/Verify_Decrypt_V00170_ExactCatalog.sql')))
      $script:sequenceSeen.LoginSha | Should -BeExactly 'E4B145ADCBD1140ED9599B371537A08855F7160FE968084B5DF1A2B12DB335A5'
      $script:sequenceSeen.DecryptSha | Should -BeExactly 'CD79D47FDD8DF818B7C70A6B2FB8183D99C6CD8AC79CFA70E9255442225E0433'
      [object]::ReferenceEquals($script:sequenceSeen.Verifier, $script:verifier) | Should -BeTrue
      ($script:sequenceSeen.Parameters.FlywayAdditionalArgs -join '|') | Should -BeExactly '-defaultSchema=dbo|-table=flyway_schema_history'
      $script:sequenceSeen.Parameters.PackageVersion | Should -BeExactly 'synthetic-param-1700'
    }
    It 'migrates a thirteen-row V140 clone to V150 first (Plain boundary, pending ignored on all three calls)' {
      Set-Baseline '00140'
      $result = Invoke-FlywayRehearsal @script:parameters
      (@($result.FlywayResult.CompletedPhases)[0..2] -join ',') | Should -BeExactly 'validate150,migrate150,validate150'
      foreach ($call in $script:flywayCalls[0..2]) {
        ($call.Arguments -join '|') | Should -BeExactly '-defaultSchema=dbo|-table=flyway_schema_history|-target=00150|-ignoreMigrationPatterns=*:pending'
      }
      $script:events | Should -Contain 'LoginDecrypt'
      $result.FlywayResult.TargetVersion | Should -BeExactly '00220'
    }
  }

  Context 'a 0.1.25-shaped package (head 00210) keeps the legacy argument shape' {
    It 'runs only the final 00210 boundary with the exact legacy Flyway arguments' {
      Set-PackageMigrations @($script:allNames | Where-Object { $_ -notlike 'V00220__*' })
      Set-Baseline '00210'
      $result = Invoke-FlywayRehearsal @script:parameters
      ($result.FlywayResult.CompletedPhases -join ',') | Should -BeExactly 'before210,validate,migrate210,validate,after210'
      ($script:flywayCalls.Arguments | ForEach-Object { $_ }) | Should -Not -Contain '-target=00220'
      ($script:flywayCalls[0].Arguments -join '|') | Should -BeExactly '-defaultSchema=dbo|-table=flyway_schema_history|-target=00210|-ignoreMigrationPatterns=*:pending'
      ($script:flywayCalls[1].Arguments -join '|') | Should -BeExactly '-defaultSchema=dbo|-table=flyway_schema_history|-target=00210'
      ($script:flywayCalls[2].Arguments -join '|') | Should -BeExactly '-defaultSchema=dbo|-table=flyway_schema_history|-target=00210|-ignoreMigrationPatterns='
    }
  }

  Context 'fail-closed history and verifier faults (clone always cleaned)' {
    It 'refuses an unadmitted <Label> before any Flyway call' -ForEach @(
      @{ Label = 'nineteen-row (V200) clone'; Version = '00200' }
      @{ Label = 'fifteen-row (V160) clone'; Version = '00160' }
      @{ Label = 'twelve-row (V130) clone'; Version = '00130' }
    ) {
      Set-Baseline $Version
      { Invoke-FlywayRehearsal @script:parameters } | Should -Throw '*admitted clone baseline*'
      $script:flywayCalls.Count | Should -Be 0
      ($script:events | Select-Object -Last 3) -join '|' | Should -BeExactly 'Close|Dispose|Drop'
    }
    It 'refuses a clone history beyond the package head' {
      Set-PackageMigrations @($script:allNames | Where-Object { $_ -notlike 'V00220__*' })
      $script:historyCount = 21
      $script:versions = @($script:versions) + '00220'
      { Invoke-FlywayRehearsal @script:parameters } | Should -Throw '*admitted clone baseline*'
      $script:flywayCalls.Count | Should -Be 0
    }
    It 'refuses a <Fault> predecessor history before any Flyway call' -ForEach @(@{ Fault = 'WrongVersion' }, @{ Fault = 'FailedRow' }) {
      $script:historyFault = $Fault
      { Invoke-FlywayRehearsal @script:parameters } | Should -Throw '*exact successful predecessor versions*'
      $script:flywayCalls.Count | Should -Be 0
      ($script:events | Select-Object -Last 3) -join '|' | Should -BeExactly 'Close|Dispose|Drop'
    }
    It 'stops at <Fault> without running later boundaries' -ForEach @(
      @{ Fault = 'WrongMarkerBefore210'; Expect = '*00210 predecessor verification failed*' }
      @{ Fault = 'WrongMarkerAfter220'; Expect = '*00220 post-state verification failed*' }
      @{ Fault = 'Failvalidate'; Expect = '*00210 validate failed*' }
      @{ Fault = 'Failmigrate'; Expect = '*00210 migrate failed*' }
      @{ Fault = 'MigrateLeavesHistory'; Expect = '*00210 must leave exact successful history through 00210*' }
      @{ Fault = 'SessionChangeOnmigrate'; Expect = '*verifier session changed*' }
    ) {
      # From a V170 clone the 00210 migrate must advance history (at a V210 baseline it is a no-op).
      if ($Fault -ceq 'MigrateLeavesHistory') { Set-Baseline '00170' }
      $script:fault = $Fault
      { Invoke-FlywayRehearsal @script:parameters } | Should -Throw $Expect
      ($script:events | Select-Object -Last 3) -join '|' | Should -BeExactly 'Close|Dispose|Drop'
      if ($Fault -cne 'WrongMarkerAfter220') { $script:events | Should -Not -Contain 'Before220' }
    }
    It 'refuses an existing clone name before copy or drop' {
      $script:present = $true
      { Invoke-FlywayRehearsal @script:parameters } | Should -Throw '*previously absent*'
      Should -Invoke Copy-DbaDatabase -Times 0 -Exactly
      Should -Invoke Invoke-DatabaseSqlNonQuery -Times 0 -Exactly
    }
  }

  Context 'begin-block refusals (before resolver, copy or clone)' {
    It 'refuses <Label>' -ForEach @(
      @{ Label = 'mixing the contract with an Organization path'; Expect = '*derives its verifier paths*'; Mutate = { param($p) $p.OrganizationFixturePath = 'D:/x/Verify_Organization_V00210.sql' } }
      @{ Label = 'mixing the contract with Login/Decrypt paths'; Expect = '*derives its verifier paths*'; Mutate = { param($p) $p.LoginFixturePath = 'D:/x/L.sql'; $p.DecryptFixturePath = 'D:/x/D.sql' } }
      @{ Label = 'a relative contract path'; Expect = '*absolute package and verifier paths*'; Mutate = { param($p) $p.FixtureContractPath = 'Database/Verify/RehearsalBoundaries.json' } }
      @{ Label = 'a package identity that differs from the contract'; Expect = '*does not match the rehearsal boundary contract*'; Mutate = { param($p) $p.PackageName = 'Other.Database' } }
      @{ Label = 'a source catalog that differs from the contract'; Expect = '*does not match the rehearsal boundary contract*'; Mutate = { param($p) $p.ExpectedSourceDatabaseName = 'Other'; $p.SourceDatabaseName = 'Other' } }
      @{ Label = 'a package head that is not a contract boundary'; Expect = '*does not support this manifest migration boundary*'; Mutate = { param($p) [IO.File]::WriteAllText((Join-Path $p.FlywaySqlMigrationsPath 'V00230__Next.sql'), '') } }
      @{ Label = 'a non-versioned file in the migrations folder'; Expect = '*only versioned migrations*'; Mutate = { param($p) [IO.File]::WriteAllText((Join-Path $p.FlywaySqlMigrationsPath 'R__Repeatable.sql'), '') } }
      @{ Label = 'a missing middle migration'; Expect = '*not exactly the contract boundary migrations*'; Mutate = { param($p) Remove-Item -LiteralPath (Join-Path $p.FlywaySqlMigrationsPath 'V00190__Create_ReadOrganizationEligibility_Procedure.sql') } }
    ) {
      & $Mutate $script:parameters
      { Invoke-FlywayRehearsal @script:parameters } | Should -Throw $Expect
      Should -Invoke Resolve-DatabaseSqlConnection -Times 0 -Exactly
      Should -Invoke Copy-DbaDatabase -Times 0 -Exactly
      $script:flywayCalls.Count | Should -Be 0
    }
  }
}

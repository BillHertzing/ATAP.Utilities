#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
# Offline branch/lifecycle tests. Every resolver, SQL, copy and Flyway boundary is mocked.
BeforeAll {
  $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
  $public = Join-Path $repositoryRoot 'src/ATAP.Utilities.DatabaseManagement.Powershell/public'
  $private = Join-Path $repositoryRoot 'src/ATAP.Utilities.DatabaseManagement.Powershell/private'
  Import-Module PSFramework -ErrorAction Stop
  . (Join-Path $private 'DatabaseSqlConnection.Helpers.ps1')
  . (Join-Path $private 'DatabaseSqlCommand.Helpers.ps1')
  foreach ($file in @('Invoke-Flyway.ps1','Resolve-DatabaseSqlConnection.ps1','Invoke-FlywayRehearsal.ps1',
      'Invoke-DatabasePackageRehearsal.ps1','Get-DatabasePackageManifest.ps1','Expand-DatabaseChangePackage.ps1')) {
    . (Join-Path $public $file)
  }
  function Connect-DbaInstance { param($SqlInstance,[switch]$TrustServerCertificate,[switch]$AllowTrustServerCertificate) throw 'Unmocked connection forbidden' }
  function Copy-DbaDatabase { [CmdletBinding(SupportsShouldProcess)] param($Source,$Destination,$Database,$NewName,[switch]$BackupRestore,$SharedPath,[switch]$WithReplace,[switch]$Force,[switch]$EnableException) throw 'Unmocked copy forbidden' }
  function Invoke-Flyway {
    [CmdletBinding(SupportsShouldProcess)]
    param([object]$SqlConnection,$DatabaseName,$ExpectedDatabaseName,$Environment,$FlywayCommand,
      $FlywayBasePath,$FlywaySqlMigrationsPath,$FlywayDataPath,$FlywayTomlPath,$PackageName,$PackageVersion,
      [string[]]$FlywayAdditionalArgs,$FlywayExecutablePath)
    throw 'Unmocked Flyway forbidden'
  }
  function Invoke-AceCommanderLoginFixtureSequence {
    [CmdletBinding(SupportsShouldProcess)]
    param([object]$SqlConnection,$LoginFixturePath,$DecryptFixturePath,[hashtable]$FlywayParameters)
    throw 'Unmocked legacy sequence forbidden'
  }
  $verifierPath = Join-Path $repositoryRoot 'Database/Verify/AceCommander/Verify_Organization_V00210.sql'
  $virtualPackage = Join-Path $repositoryRoot '_generated/Sprint0017/CloseStreams/UL1617/virtual-package'
  $wrapperParameters = @{ PackagePath = $virtualPackage; Application = 'ATAPUtilities'; BuildId = '1617'
    ExpectedSourceDatabaseName = 'ATAPUtilities'; ExpectedPackageName = 'ATAPUtilities.Database'; ExpectedPackageVersion = '0.1.19-Sprint.1'
    LoginFixturePath = (Join-Path $repositoryRoot 'Database/Verify/AceCommander/Verify_Login_V00160_ExactCatalog.sql')
    DecryptFixturePath = (Join-Path $repositoryRoot 'Database/Verify/AceCommander/Verify_Decrypt_V00170_ExactCatalog.sql')
    OrganizationFixturePath = $verifierPath; Confirm = $false }
}

Describe 'Incremental package manifest selection' -Tag 'UL1617' {
  BeforeEach {
    $script:manifest1617 = [pscustomobject]@{ dbChangeUnit = 'ATAPUtilities.Database'; appVersion = '0.1.19-Sprint.1'; flywayTargetVersion = '00210'
      files = @(Get-ChildItem (Join-Path $repositoryRoot 'Database/Flyway/SQL') -Filter 'V*.sql' | ForEach-Object { [pscustomobject]@{ kind = 'migration'; path = 'db/migrations/' + $_.Name } }) }
    $script:forwarded1617 = $null
    Mock Write-PSFMessage {}
    Mock Test-Path { $true }
    Mock Get-DatabasePackageManifest { $script:manifest1617 }
    Mock Invoke-FlywayRehearsal { $script:forwarded1617 = @{} + $PesterBoundParameters; [pscustomobject]@{ Success = $true } }
  }
  It 'selects only the organization verifier for target210' {
    (Invoke-DatabasePackageRehearsal @wrapperParameters).Success | Should -BeTrue
    $script:forwarded1617.OrganizationFixturePath | Should -BeExactly $verifierPath
    $script:forwarded1617.ContainsKey('LoginFixturePath') | Should -BeFalse
    $script:forwarded1617.ContainsKey('DecryptFixturePath') | Should -BeFalse
    $script:forwarded1617.ExpectedSourceDatabaseName | Should -BeExactly 'ATAPUtilities'
  }
  It 'retains the legacy paired fixture path at the original170 boundary' {
    $script:manifest1617.flywayTargetVersion = '00170'
    Invoke-DatabasePackageRehearsal @wrapperParameters | Out-Null
    $script:forwarded1617.ContainsKey('OrganizationFixturePath') | Should -BeFalse
    $script:forwarded1617.LoginFixturePath | Should -BeExactly $wrapperParameters.LoginFixturePath
    $script:forwarded1617.DecryptFixturePath | Should -BeExactly $wrapperParameters.DecryptFixturePath
  }
  It 'refuses target210 without its explicit verifier instead of replaying the legacy sequence' -Tag 'UL1617MissingVerifier' {
    $missingVerifier = $wrapperParameters.Clone()
    $missingVerifier.Remove('OrganizationFixturePath')
    { Invoke-DatabasePackageRehearsal @missingVerifier } | Should -Throw '*Organization rehearsal requires*'
    Should -Invoke Invoke-FlywayRehearsal -Times 0 -Exactly
  }
  It 'refuses unsupported or incomplete immutable boundaries before clone invocation' {
    $script:manifest1617.flywayTargetVersion = '00220'
    { Invoke-DatabasePackageRehearsal @wrapperParameters } | Should -Throw '*does not support*'
    $script:manifest1617.flywayTargetVersion = '00210'
    $script:manifest1617.files = @($script:manifest1617.files | Where-Object path -NotLike '*V00190*')
    { Invoke-DatabasePackageRehearsal @wrapperParameters } | Should -Throw '*exact four*'
    Should -Invoke Invoke-FlywayRehearsal -Times 0 -Exactly
  }
}

Describe 'Incremental clone lifetime' -Tag @('UL1617','UL1617Lifecycle') {
  BeforeEach {
    $script:oldStaging1617 = [Environment]::GetEnvironmentVariable('ATAP_DATABASE_PACKAGE_STAGING_ROOT','Process')
    $env:ATAP_DATABASE_PACKAGE_STAGING_ROOT = $virtualPackage
    $script:events1617 = [Collections.Generic.List[string]]::new()
    $script:fault1617 = ''; $script:present1617 = $false
    $script:master1617 = [pscustomobject]@{ State = 'Open'; DataSource = 'synthetic' }
    $script:master1617 | Add-Member ScriptMethod get_ConnectionString { 'Data Source=synthetic;Initial Catalog=master;Integrated Security=True' }
    $script:master1617 | Add-Member ScriptMethod Close { $script:events1617.Add('MasterClose') }
    $script:master1617 | Add-Member ScriptMethod Dispose { $script:events1617.Add('MasterDispose') }
    $script:verifier1617 = [pscustomobject]@{ State = 'Closed'; ClientConnectionId = [guid]::NewGuid() }
    $script:verifier1617 | Add-Member ScriptMethod set_ConnectionString { param($value) $script:verifierConnection1617 = $value }
    $script:verifier1617 | Add-Member ScriptMethod Open { $this.State='Open'; $script:events1617.Add('Open') }
    $script:verifier1617 | Add-Member ScriptMethod Close { $this.State='Closed'; $script:events1617.Add('Close') }
    $script:verifier1617 | Add-Member ScriptMethod Dispose { $script:events1617.Add('Dispose') }
    $script:helperParameters1617 = @{ Application='ATAPUtilities'; BuildId='1617-Experimental'; SourceDatabaseName='ATAPUtilities'
      ExpectedSourceDatabaseName='ATAPUtilities'; OrganizationFixturePath=$verifierPath
      PackageName='ATAPUtilities.Database'; PackageVersion='0.1.19-Sprint.1'; FlywayBasePath=$virtualPackage
      FlywaySqlMigrationsPath=(Join-Path $virtualPackage 'db/migrations'); FlywayDataPath=(Join-Path $virtualPackage 'db/seeds')
      FlywayTomlPath=(Join-Path $virtualPackage 'flyway.toml'); FlywayAdditionalArgs=@('-defaultSchema=dbo','-table=flyway_schema_history'); Confirm=$false }
    Mock Write-PSFMessage {}
    Mock Resolve-DatabaseSqlConnection { [pscustomobject]@{ Connection=$script:master1617; IsCallerOwned=$true } }
    Mock Test-Path { $true }
    Mock Connect-DbaInstance { 'synthetic-instance' }
    Mock Copy-DbaDatabase { $script:events1617.Add('Copy'); if ($script:fault1617 -eq 'Copy') { throw 'Copy failed' } }
    Mock Invoke-DatabaseSqlNonQuery { $script:events1617.Add('Drop'); 0 }
    Mock New-Object { $script:verifier1617 }
    Mock New-DatabaseSqlCommand {
      $command = [pscustomobject]@{ Parameters = @{ '@ExpectedCatalog' = [pscustomobject]@{ SqlDbType = $null; Size = 0 } } }
      $command | Add-Member ScriptMethod ExecuteNonQuery { 0 }
      $command | Add-Member ScriptMethod Dispose { }
      $command
    }
    Mock Invoke-DatabaseSqlQuery {
      if ($null -ne $Parameters -and $Parameters.ContainsKey('CloneName')) { return [pscustomobject]@{ Absent = [int](-not $script:present1617) } }
      $phase = if ($CommandText.Contains("=N'Before';")) { 'Before' } else { 'After' }
      $script:events1617.Add($phase)
      if ($script:fault1617 -ceq $phase) { throw "Verifier $phase failed" }
      [pscustomobject]@{ FixturePhase = $phase + '210' }
    }
    Mock Invoke-Flyway {
      $script:events1617.Add($FlywayCommand)
      [pscustomobject]@{ Success = ($script:fault1617 -cne $FlywayCommand) }
    }
  }
  AfterEach {
    $value = $script:oldStaging1617
    if ($null -eq $value) { $value = [NullString]::Value }
    [Environment]::SetEnvironmentVariable('ATAP_DATABASE_PACKAGE_STAGING_ROOT',$value,'Process')
  }
  It 'runs before-validate-migrate210-validate-after once and retires verifier before cleanup' {
    $r = Invoke-FlywayRehearsal @script:helperParameters1617
    $r.Success | Should -BeTrue
    ($script:events1617 -join '|') | Should -BeExactly 'Copy|Open|Before|validate|migrate|validate|After|Close|Dispose|Drop'
    Should -Invoke Invoke-Flyway -Times 1 -Exactly -ParameterFilter {
      $FlywayCommand -ceq 'migrate' -and $ExpectedDatabaseName -ceq 'ATAPUtilities-rehearsal-1617-Experimental' -and
      ($FlywayAdditionalArgs -join '|') -ceq '-defaultSchema=dbo|-table=flyway_schema_history|-target=00210' -and
      [object]::ReferenceEquals($SqlConnection,$script:verifier1617)
    }
    Should -Invoke Copy-DbaDatabase -Times 1 -Exactly -ParameterFilter { -not $WithReplace -and -not $Force }
  }
  It 'fails closed and cleans its clone at <Failure>' -ForEach @('Before','validate','migrate','After' | ForEach-Object { @{Failure=$_} }) {
    $script:fault1617=$Failure
    { Invoke-FlywayRehearsal @script:helperParameters1617 } | Should -Throw '*failed*'
    ($script:events1617 | Select-Object -Last 3) -join '|' | Should -BeExactly 'Close|Dispose|Drop'
    if ($Failure -in @('Before','validate')) { Should -Invoke Invoke-Flyway -Times 0 -Exactly -ParameterFilter { $FlywayCommand -ceq 'migrate' } }
  }
  It 'refuses an existing clone before copy or drop' {
    $script:present1617=$true
    { Invoke-FlywayRehearsal @script:helperParameters1617 } | Should -Throw '*previously absent*'
    Should -Invoke Copy-DbaDatabase -Times 0 -Exactly
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 0 -Exactly
  }
  It 'cleans a partially attempted owned copy when the copy fails' {
    $script:fault1617='Copy'
    { Invoke-FlywayRehearsal @script:helperParameters1617 } | Should -Throw '*Copy failed*'
    ($script:events1617 -join '|') | Should -BeExactly 'Copy|Drop'
    Should -Invoke New-Object -Times 0 -Exactly
  }
  It 'retires an owned source connection when an existing clone is refused' -Tag 'UL1617OwnedConnection' {
    $script:present1617=$true
    Mock Resolve-DatabaseSqlConnection { [pscustomobject]@{ Connection=$script:master1617; IsCallerOwned=$false } }
    { Invoke-FlywayRehearsal @script:helperParameters1617 } | Should -Throw '*previously absent*'
    ($script:events1617 -join '|') | Should -BeExactly 'MasterClose|MasterDispose'
    Should -Invoke Invoke-DatabaseSqlNonQuery -Times 0 -Exactly
    Should -Invoke Copy-DbaDatabase -Times 0 -Exactly
  }
  It 'retains the dedicated legacy sequence and its original clone lifecycle' -Tag 'UL1617Legacy' {
    $legacy = $script:helperParameters1617.Clone()
    $legacy.Remove('OrganizationFixturePath')
    $legacy.LoginFixturePath = $wrapperParameters.LoginFixturePath
    $legacy.DecryptFixturePath = $wrapperParameters.DecryptFixturePath
    Mock Invoke-AceCommanderLoginFixtureSequence { $script:events1617.Add('Legacy'); [pscustomobject]@{ Success=$true } }
    (Invoke-FlywayRehearsal @legacy).Success | Should -BeTrue
    ($script:events1617 -join '|') | Should -BeExactly 'Drop|Copy|Open|Legacy|Close|Dispose|Drop'
    Should -Invoke Invoke-AceCommanderLoginFixtureSequence -Times 1 -Exactly
    Should -Invoke Invoke-Flyway -Times 0 -Exactly
    Should -Invoke Invoke-DatabaseSqlQuery -Times 0 -Exactly
  }
}

#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

BeforeAll {
  # Fail-closed dependency stubs: no real SQL, native process or logging fallback.
  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
  function Assert-DatabaseSqlConnectionIsOpen {
    [CmdletBinding()]param($Connection, $Source)
    throw 'UnmockedVerifierValidation'
  }
  function Invoke-DatabaseSqlQuery {
    [CmdletBinding()]param($SqlConnection, $CommandText)
    throw 'UnmockedSql'
  }
  function Invoke-Flyway {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param($SqlConnection, $DatabaseName, $Environment, $FlywayBasePath, $FlywaySqlMigrationsPath, $FlywaySharedSqlMigrationsPath,
      $FlywayDataPath, $FlywayTomlPath, $PackageName, $PackageVersion, $ExpectedDatabaseName,
      $FlywayExecutablePath, $GitTag, $GitCommit, $FlywayCommand, $FlywayAdditionalArgs)
    throw 'UnmockedFlyway'
  }
  # FunctionInfo invocation bypasses Pester's name proxy. Capture this safe adapter
  # so the existing native mock still observes every parameter and failure case.
  function Invoke-CapturedFlyway554 {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param($SqlConnection, $DatabaseName, $Environment, $FlywayBasePath, $FlywaySqlMigrationsPath, $FlywaySharedSqlMigrationsPath,
      $FlywayDataPath, $FlywayTomlPath, $PackageName, $PackageVersion, $ExpectedDatabaseName,
      $FlywayExecutablePath, $GitTag, $GitCommit, $FlywayCommand, $FlywayAdditionalArgs)
    Invoke-Flyway @PSBoundParameters
  }
  function New-DatabaseSqlCommand {
    [CmdletBinding()]param($SqlConnection, $CommandText, $Parameters, $CommandType)
    throw 'UnmockedCatalogSetup'
  }
  . (Join-Path $PSScriptRoot '../../private/Invoke-AceCommanderLoginFixtureSequence.ps1')
  # Accepted immutable SQL is read as inert bytes only, never executed by this container.
  $script:loginPath554 = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../Database/Verify/AceCommander/Verify_Login_V00160_ExactCatalog.sql'))
  $script:decryptPath554 = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../Database/Verify/AceCommander/Verify_Decrypt_V00170_ExactCatalog.sql'))
  $script:loginBytes554 = [IO.File]::ReadAllBytes($script:loginPath554)
  $script:decryptBytes554 = [IO.File]::ReadAllBytes($script:decryptPath554)
  $script:loginText554 = [Text.UTF8Encoding]::new($false, $true).GetString($script:loginBytes554)
  $script:decryptText554 = [Text.UTF8Encoding]::new($false, $true).GetString($script:decryptBytes554)
  $script:guardSql554 = "SELECT DB_NAME() AS DatabaseName, CAST(@@SPID AS int) AS SessionId, @@TRANCOUNT AS TransactionCount, SESSION_CONTEXT(N'ATAP.AceCommander.Fixture.ExpectedCatalog') AS ExpectedCatalog, CONVERT(nvarchar(128), SQL_VARIANT_PROPERTY(SESSION_CONTEXT(N'ATAP.AceCommander.Fixture.ExpectedCatalog'), 'BaseType')) AS CatalogType;"

  function Invoke-Sequence554 {
    param([switch]$WhatIfMode)
    Invoke-AceCommanderLoginFixtureSequence -SqlConnection $script:connection554 -LoginFixturePath $script:loginPath554 -DecryptFixturePath $script:decryptPath554 -FlywayParameters $script:parameters554 -WhatIf:$WhatIfMode -Confirm:$false
  }

  function New-SyntheticSqlFailure699 {
    param([int]$Count = 2)
    # Construct inert provider exceptions by reflection: no connection, SQL, Add-Type or compilation.
    $exceptionType = 'System.Data.SqlClient.SqlException' -as [type]
    if ($null -eq $exceptionType) { throw 'Synthetic SqlClient exception type unavailable.' }
    $collectionType = $exceptionType.Assembly.GetType('System.Data.SqlClient.SqlErrorCollection', $true)
    $errorType = $exceptionType.Assembly.GetType('System.Data.SqlClient.SqlError', $true)
    $instanceFlags = [Reflection.BindingFlags]'Instance,NonPublic'
    $constructor = $errorType.GetConstructor($instanceFlags, $null,
      [type[]]@([int], [byte], [byte], [string], [string], [string], [int], [Exception]), $null)
    $add = $collectionType.GetMethod('Add', $instanceFlags, $null, [type[]]@($errorType), $null)
    $factory = $exceptionType.GetMethod('CreateException', [Reflection.BindingFlags]'Static,NonPublic', $null,
      [type[]]@($collectionType, [string]), $null)
    if ($null -eq $constructor -or $null -eq $add -or $null -eq $factory) { throw 'Synthetic SqlClient signature unavailable.' }
    $collection = [Activator]::CreateInstance($collectionType, $true)
    for ($index = 0; $index -lt $Count; $index++) {
      $errorItem = $constructor.Invoke([object[]]@((207 + $index), [byte]1, [byte]16,
        'SECRET699-SERVER', 'SECRET699-MESSAGE', 'SECRET699-PROCEDURE', (100 + $index), $null))
      $null = $add.Invoke($collection, [object[]]@($errorItem))
    }
    return $factory.Invoke($null, [object[]]@($collection, 'SECRET699-VERSION'))
  }

}

Describe 'Pinned Login160/Decrypt170 private fixture sequence' -Tag 'Unit' {
  BeforeEach {
    $WhatIfPreference = $false
    $script:trace554 = [Collections.Generic.List[string]]::new()
    $script:queryConnections554 = [Collections.Generic.List[object]]::new()
    $script:nativeCalls554 = [Collections.Generic.List[object]]::new()
    $script:loginCalls554 = 0; $script:decryptCalls554 = 0; $script:guardCalls554 = 0
    $script:closeCalls554 = 0
    $script:failAt554 = ''; $script:failureKind554 = ''
    $script:guardFault554 = ''; $script:guardFaultAt554 = 4; $script:corrupt554 = ''
    $script:binding578 = [PSCustomObject]@{ Value = $null; Type = $null; Created = 0; Disposed = 0; Executed = 0; Fault = ''; Parameter = $null; CommandText = $null; CommandType = $null }
    $script:observedDatabase578 = 'ATAPUtilities'
    $script:setupConnections578 = [Collections.Generic.List[object]]::new()
    $script:connection554 = [PSCustomObject]@{
      State = 'Open'; ClientConnectionId = [guid]'11111111-1111-1111-1111-111111111111'
      ConnectionString = 'Pooling=False;MultipleActiveResultSets=False;Data Source=synthetic578'
    }
    $script:expectedConnectionString578 = $script:connection554.ConnectionString
    $script:connection554 | Add-Member -MemberType ScriptMethod -Name get_ConnectionString -Value { return $this.ConnectionString }
    foreach ($lifecycleMethodName592 in @('Close', 'Dispose', 'Open', 'ChangeDatabase')) {
      $script:connection554 | Add-Member -MemberType ScriptMethod -Name $lifecycleMethodName592 -Value {
        $script:closeCalls554++; throw 'BorrowedLifetimeViolation'
      }
    }
    $script:parameters554 = @{
      DatabaseName = 'ATAPUtilities'; Environment = 'Experimental'
      FlywayBasePath = 'D:/ATAPArtifacts/Fixture554/package'
      FlywaySqlMigrationsPath = 'D:/ATAPArtifacts/Fixture554/package/db/migrations'
      FlywayDataPath = 'D:/ATAPArtifacts/Fixture554/package/db/seeds'
      FlywayTomlPath = 'D:/ATAPArtifacts/Fixture554/package/flyway.toml'
      PackageName = 'ATAPUtilities.Database'; PackageVersion = '0.0.0-fixture'
      ExpectedDatabaseName = 'ATAPUtilities'
    }
    $script:originalParameters554 = ConvertTo-Json -InputObject $script:parameters554 -Compress
    Mock Write-PSFMessage {}
    Mock Assert-DatabaseSqlConnectionIsOpen { return $Connection }
    Mock New-DatabaseSqlCommand {
      $script:setupConnections578.Add($SqlConnection)
      $binding = $script:binding578
      if ($binding.Fault -eq 'create') { throw 'SENSITIVE-SETUP578' }
      $parameter = [PSCustomObject]@{ Value = $Parameters.ExpectedCatalog; SqlDbType = [Data.SqlDbType]::Variant; Size = 0 }
      $binding.Parameter = $parameter; $binding.CommandText = $CommandText; $binding.CommandType = $CommandType
      $command = [PSCustomObject]@{ Parameters = @{ '@ExpectedCatalog' = $parameter }; Binding = $binding }
      if ($binding.Fault -eq 'missing parameter') { $command.Parameters.Clear() }
      $command | Add-Member -MemberType ScriptMethod -Name ExecuteNonQuery -Value {
        $this.Binding.Executed++
        switch ($this.Binding.Fault) {
          'execute' { throw 'SENSITIVE-SETUP578' }
          'no set' { return -1 }
          'wrong name' { $this.Binding.Value = 'Other'; $this.Binding.Type = 'nvarchar'; return -1 }
          'wrong type' { $this.Binding.Value = $this.Binding.Parameter.Value; $this.Binding.Type = 'varchar'; return -1 }
        }
        $this.Binding.Value = $this.Binding.Parameter.Value; $this.Binding.Type = 'nvarchar'
        return -1
      }
      $command | Add-Member -MemberType ScriptMethod -Name Dispose -Value { $this.Binding.Disposed++ }
      $binding.Created++
      return $command
    }
    Mock Get-Content {
      if ($LiteralPath -eq $script:loginPath554) {
        if ($script:corrupt554 -eq 'login') { return ,([byte[]]($script:loginBytes554 + [byte]0)) }
        return ,$script:loginBytes554
      }
      if ($LiteralPath -eq $script:decryptPath554) {
        if ($script:corrupt554 -eq 'decrypt') { return ,([byte[]]($script:decryptBytes554 + [byte]0)) }
        return ,$script:decryptBytes554
      }
      throw 'UnexpectedFixtureRead'
    }
    Mock Invoke-DatabaseSqlQuery {
      $script:queryConnections554.Add($SqlConnection)
      if ($CommandText -ceq $script:guardSql554) {
        $script:guardCalls554++
        $row = [PSCustomObject]@{ DatabaseName = $script:observedDatabase578; SessionId = 42; TransactionCount = 0; ExpectedCatalog = $script:binding578.Value; CatalogType = $script:binding578.Type }
        if ($script:guardCalls554 -eq $script:guardFaultAt554) {
          switch ($script:guardFault554) {
            'spid' { $row.SessionId = 43 }
            'target' { $row.DatabaseName = 'Other' }
            'transaction' { $row.TransactionCount = 1 }
            'row shape' { $row.SessionId = '42' }
            'empty' { return }
            'connection id' { $script:connection554.ClientConnectionId = [guid]'22222222-2222-2222-2222-222222222222' }
            'closed' { $script:connection554.State = 'Closed' }
            'catalog case' { $row.ExpectedCatalog = 'ataputilities' }
            'catalog trailing' { $row.ExpectedCatalog = 'ATAPUtilities ' }
            'catalog missing' { $row.ExpectedCatalog = $null; $row.CatalogType = $null }
            'catalog type' { $row.CatalogType = 'varchar' }
          }
        }
        return $row
      }
      if ($CommandText -ceq $script:loginText554) {
        $script:loginCalls554++
        $phase = if ($script:loginCalls554 -eq 1) { 'before160' } else { 'after160' }
      } elseif ($CommandText -ceq $script:decryptText554) {
        $script:decryptCalls554++
        $phase = if ($script:decryptCalls554 -eq 1) { 'before170' } else { 'after170' }
      } else { throw 'UnexpectedSqlText' }
      $script:trace554.Add($phase)
      if ($script:failAt554 -eq $phase -and $script:failureKind554 -eq 'throw') { throw 'SensitiveSqlDetail554' }
      $marker = if ($phase.StartsWith('before')) { 'BeforeCaptured' } else { 'AfterAssertionsPassed' }
      if ($script:failAt554 -eq $phase -and $script:failureKind554 -eq 'marker') { $marker = 'BeforeCapturedWrong' }
      $cases = if ($phase -eq 'after170' -and $script:failureKind554 -eq 'cases') { 12 } else { 13 }
      return [PSCustomObject]@{ FixturePhase = $marker; SyntheticCasesPassed = $cases }
    }
    Mock Invoke-Flyway {
      $version = if ($FlywayAdditionalArgs -contains '-target=00160') { '00160' } else { '00170' }
      $phase = 'migrate' + $version
      $script:trace554.Add($phase)
      $script:nativeCalls554.Add([PSCustomObject]@{
        Connection = $SqlConnection; DatabaseName = $DatabaseName; Environment = $Environment
        Base = $FlywayBasePath; Sql = $FlywaySqlMigrationsPath; Shared = $FlywaySharedSqlMigrationsPath; Data = $FlywayDataPath; Toml = $FlywayTomlPath
        PackageName = $PackageName; Version = $PackageVersion; Expected = $ExpectedDatabaseName
        Command = $FlywayCommand; Arguments = @($FlywayAdditionalArgs)
      })
      if ($script:failAt554 -eq $phase) {
        switch ($script:failureKind554) {
          'throw' { throw 'SensitiveNativeDetail554' }
          'false' { return [PSCustomObject]@{ Success = $false } }
          'null' { return }
          'untyped success' { return [PSCustomObject]@{ Success = 'true' } }
        }
      }
      return [PSCustomObject]@{ Success = $true }
    }
    $script:dependencyCommands1745 = @{}
    foreach ($dependency1745 in @('Write-PSFMessage', 'Assert-DatabaseSqlConnectionIsOpen', 'Invoke-DatabaseSqlQuery', 'New-DatabaseSqlCommand')) {
      $script:dependencyCommands1745[$dependency1745] = Get-Command $dependency1745 -ErrorAction Stop
    }
    $script:capturedNativeCommand1745 = Get-Command Invoke-CapturedFlyway554 -CommandType Function
    Mock Get-Command {
      if (-not $script:dependencyCommands1745.ContainsKey([string]$Name)) { throw 'UnexpectedDependencyLookup' }
      $script:dependencyCommands1745[[string]$Name]
    }
    Mock Get-Command { $script:capturedNativeCommand1745 } -ParameterFilter { $Name -eq 'Invoke-Flyway' }
  }
  AfterEach {
    # Independent of expected exceptions, so refusal tests cannot hide a lifetime violation.
    $script:closeCalls554 | Should -Be 0
    $script:binding578.Disposed | Should -Be $script:binding578.Created
    $script:connection554.ConnectionString | Should -BeExactly $script:expectedConnectionString578
    foreach ($connection in $script:queryConnections554) {
      [object]::ReferenceEquals($connection, $script:connection554) | Should -BeTrue
    }
    foreach ($call in $script:nativeCalls554) {
      [object]::ReferenceEquals($call.Connection, $script:connection554) | Should -BeTrue
    }
    foreach ($connection in $script:setupConnections578) {
      [object]::ReferenceEquals($connection, $script:connection554) | Should -BeTrue
    }
    (ConvertTo-Json -InputObject $script:parameters554 -Compress) | Should -BeExactly $script:originalParameters554
  }

  It 'runs exactly six pinned phases, eight guards, two targets and the same immutable package' {
    $result = Invoke-Sequence554
    $expected = @('before160', 'migrate00160', 'after160', 'before170', 'migrate00170', 'after170')
    ($script:trace554 -join '|') | Should -BeExactly ($expected -join '|')
    ($result.CompletedPhases -join '|') | Should -BeExactly ($expected -join '|')
    $result.Success | Should -BeTrue
    $result.Status | Should -BeExactly 'SequenceCompleted'
    $result.SessionId | Should -Be 42
    $script:guardCalls554 | Should -Be 8
    $script:binding578.Executed | Should -Be 1
    $script:binding578.Disposed | Should -Be 1
    $script:binding578.Parameter.SqlDbType | Should -Be ([Data.SqlDbType]::NVarChar)
    $script:binding578.Parameter.Size | Should -Be 128
    $script:binding578.Parameter.Value | Should -BeExactly 'ATAPUtilities'
    $script:binding578.CommandType | Should -Be ([Data.CommandType]::Text)
    $script:binding578.CommandText | Should -Match '@value=@ExpectedCatalog, @read_only=1'
    $script:binding578.CommandText | Should -Not -Match 'ATAPUtilities'
    Should -Invoke New-DatabaseSqlCommand -Times 1 -Exactly
    $script:nativeCalls554.Count | Should -Be 2
    for ($index = 0; $index -lt 2; $index++) {
      $call = $script:nativeCalls554[$index]
      $target = if ($index -eq 0) { '00160' } else { '00170' }
      ($call.Arguments -join '|') | Should -BeExactly "-defaultSchema=dbo|-table=flyway_schema_history|-target=$target"
      $call.DatabaseName | Should -BeExactly 'ATAPUtilities'
      $call.Expected | Should -BeExactly 'ATAPUtilities'
      $call.Environment | Should -BeExactly 'Experimental'
      $call.Command | Should -BeExactly 'migrate'
      $call.Base | Should -BeExactly $script:parameters554.FlywayBasePath
      $call.Sql | Should -BeExactly $script:parameters554.FlywaySqlMigrationsPath
      $call.Shared | Should -BeExactly ''
      $call.Data | Should -BeExactly $script:parameters554.FlywayDataPath
      $call.Toml | Should -BeExactly $script:parameters554.FlywayTomlPath
      $call.PackageName | Should -BeExactly $script:parameters554.PackageName
      $call.Version | Should -BeExactly $script:parameters554.PackageVersion
    }
    Should -Invoke Invoke-DatabaseSqlQuery -Times 12 -Exactly
    Should -Invoke Get-Content -Times 2 -Exactly -ParameterFilter { $AsByteStream -and $Raw }
    Should -Invoke Get-Command -Times 2 -Exactly -ParameterFilter { $Name -eq 'Invoke-Flyway' }
  }

  It 'WhatIf has no verifier validation, file, SQL, native or lifetime effects' {
    $script:connection554.State = 'Closed'
    $result = Invoke-Sequence554 -WhatIfMode
    $result.Status | Should -BeExactly 'ProposedOnly'
    $result.Success | Should -BeFalse
    @($result.CompletedPhases).Count | Should -Be 0
    Should -Invoke Assert-DatabaseSqlConnectionIsOpen -Times 0 -Exactly
    Should -Invoke Get-Content -Times 0 -Exactly
    Should -Invoke Invoke-DatabaseSqlQuery -Times 0 -Exactly
    Should -Invoke Invoke-Flyway -Times 0 -Exactly
    Should -Invoke New-DatabaseSqlCommand -Times 0 -Exactly
  }

  It 'refuses changed pinned <Fixture> bytes before any SQL' -ForEach @(
    @{ Fixture = 'login' }; @{ Fixture = 'decrypt' }
  ) {
    $script:corrupt554 = $Fixture
    { Invoke-Sequence554 } | Should -Throw '*FixturePinMismatch*'
    Should -Invoke Invoke-DatabaseSqlQuery -Times 0 -Exactly
    Should -Invoke Invoke-Flyway -Times 0 -Exactly
  }

  It 'normalizes only matching supplied history flags without changing caller inputs' {
    $script:parameters554.FlywayAdditionalArgs = @('-defaultSchema=dbo', '-table=flyway_schema_history')
    $script:originalParameters554 = ConvertTo-Json -InputObject $script:parameters554 -Compress
    (Invoke-Sequence554).Success | Should -BeTrue
    $script:nativeCalls554[0].Arguments.Count | Should -Be 3
    $script:nativeCalls554[1].Arguments.Count | Should -Be 3
  }

  It 'refuses caller raw override <Argument> even under WhatIf' -ForEach @(
    @{ Argument = '-target=00160' }; @{ Argument = '-TARGET=00170' }
    @{ Argument = '-defaultSchema=other' }; @{ Argument = '-table=other' }
    @{ Argument = '-url=other' }; @{ Argument = '-configFiles=other' }; @{ Argument = '-X' }
  ) {
    $script:parameters554.FlywayAdditionalArgs = @($Argument)
    $script:originalParameters554 = ConvertTo-Json -InputObject $script:parameters554 -Compress
    { Invoke-Sequence554 -WhatIfMode } | Should -Throw '*ConflictingFlywayArguments*'
    Should -Invoke Get-Content -Times 0 -Exactly
    Should -Invoke Invoke-DatabaseSqlQuery -Times 0 -Exactly
    Should -Invoke Invoke-Flyway -Times 0 -Exactly
  }

  It 'refuses alternate or mismatched input <Fault> before effects' -ForEach @(
    @{ Fault = 'alternate connection' }; @{ Fault = 'alternate command' }
    @{ Fault = 'expected target case' }; @{ Fault = 'relative package' }
    @{ Fault = 'missing package version' }; @{ Fault = 'shared location' }
  ) {
    switch ($Fault) {
      'alternate connection' { $script:parameters554.SqlConnection = [PSCustomObject]@{ State = 'Open' } }
      'alternate command' { $script:parameters554.FlywayCommand = 'repair' }
      'expected target case' { $script:parameters554.ExpectedDatabaseName = 'ataputilities' }
      'relative package' { $script:parameters554.FlywayBasePath = 'relative/package' }
      'missing package version' { $script:parameters554.Remove('PackageVersion') }
      'shared location' { $script:parameters554.FlywaySharedSqlMigrationsPath = 'D:/other' }
    }
    $script:originalParameters554 = ConvertTo-Json -InputObject $script:parameters554 -Compress
    { Invoke-Sequence554 } | Should -Throw '*InvalidInputs*'
    Should -Invoke Invoke-DatabaseSqlQuery -Times 0 -Exactly
    Should -Invoke Invoke-Flyway -Times 0 -Exactly
  }

  It 'aborts without reconnect/retry on changed verifier <Fault>' -ForEach @(
    @{ Fault = 'spid'; ExpectedCode = 'VerifierSessionChanged' }
    @{ Fault = 'connection id'; ExpectedCode = 'VerifierSessionChanged' }
    @{ Fault = 'closed'; ExpectedCode = 'VerifierSessionChanged' }
    @{ Fault = 'target'; ExpectedCode = 'VerifierTargetMismatch' }
    @{ Fault = 'transaction'; ExpectedCode = 'VerifierTransactionActive' }
    @{ Fault = 'row shape'; ExpectedCode = 'InvalidSessionObservation' }
    @{ Fault = 'empty'; ExpectedCode = 'InvalidSessionObservation' }
  ) {
    $script:guardFault554 = $Fault
    { Invoke-Sequence554 } | Should -Throw "*$ExpectedCode*"
    ($script:trace554 -join '|') | Should -BeExactly 'before160|migrate00160'
    $script:nativeCalls554.Count | Should -Be 1
  }

  It 'refuses an initial verifier <Fault> before any fixture or migration' -ForEach @(
    @{ Fault = 'target'; ExpectedCode = 'VerifierTargetMismatch' }
    @{ Fault = 'transaction'; ExpectedCode = 'VerifierTransactionActive' }
    @{ Fault = 'row shape'; ExpectedCode = 'InvalidSessionObservation' }
  ) {
    $script:guardFault554 = $Fault; $script:guardFaultAt554 = 1
    { Invoke-Sequence554 } | Should -Throw "*$ExpectedCode*"
    $script:trace554.Count | Should -Be 0
    Should -Invoke Invoke-Flyway -Times 0 -Exactly
  }

  It 'refuses a replacement validator connection before file reads or SQL' {
    Mock Assert-DatabaseSqlConnectionIsOpen { return [PSCustomObject]@{ State = 'Open' } }
    { Invoke-Sequence554 } | Should -Throw '*InvalidVerifier*'
    Should -Invoke Get-Content -Times 0 -Exactly
    Should -Invoke Invoke-DatabaseSqlQuery -Times 0 -Exactly
    Should -Invoke Invoke-Flyway -Times 0 -Exactly
  }

  It 'stops at fixture <Phase> on <Kind>' -ForEach @(
    @{ Phase = 'before160'; Kind = 'throw'; Prefix = 'before160' }
    @{ Phase = 'after160'; Kind = 'marker'; Prefix = 'before160|migrate00160|after160' }
    @{ Phase = 'before170'; Kind = 'marker'; Prefix = 'before160|migrate00160|after160|before170' }
    @{ Phase = 'after170'; Kind = 'cases'; Prefix = 'before160|migrate00160|after160|before170|migrate00170|after170' }
  ) {
    $script:failAt554 = $Phase; $script:failureKind554 = $Kind
    $expectedCode = if ($Kind -eq 'throw') { 'FixtureExecutionFailed' } else { 'FixtureMarkerMismatch' }
    { Invoke-Sequence554 } | Should -Throw "*$expectedCode*"
    ($script:trace554 -join '|') | Should -BeExactly $Prefix
  }

  It 'does not continue after failed native <Phase> result <Kind>' -ForEach @(
    @{ Phase = 'migrate00160'; Kind = 'throw'; Prefix = 'before160|migrate00160' }
    @{ Phase = 'migrate00160'; Kind = 'false'; Prefix = 'before160|migrate00160' }
    @{ Phase = 'migrate00160'; Kind = 'null'; Prefix = 'before160|migrate00160' }
    @{ Phase = 'migrate00170'; Kind = 'untyped success'; Prefix = 'before160|migrate00160|after160|before170|migrate00170' }
  ) {
    $script:failAt554 = $Phase; $script:failureKind554 = $Kind
    $caught554 = $null
    try { Invoke-Sequence554 } catch { $caught554 = $_ }
    $caught554 | Should -Not -BeNullOrEmpty
    $caught554.Exception.Message | Should -Match 'Flyway'
    $caught554.Exception.Message | Should -Not -Match 'SensitiveNativeDetail554'
    $caught554.Exception.Data['FailedPhase'] | Should -BeExactly $Phase
    $completedPrefix = if ($Phase -eq 'migrate00160') { 'before160' } else { 'before160|migrate00160|after160|before170' }
    ($caught554.Exception.Data['CompletedPhases'] -join '|') | Should -BeExactly $completedPrefix
    ($script:trace554 -join '|') | Should -BeExactly $Prefix
  }
  It 'requires the explicit expected catalog before effects' {
    $script:parameters554.Remove('ExpectedDatabaseName')
    $script:originalParameters554 = ConvertTo-Json -InputObject $script:parameters554 -Compress
    { Invoke-Sequence554 } | Should -Throw '*InvalidInputs*'
    Should -Invoke New-DatabaseSqlCommand -Times 0 -Exactly
    Should -Invoke Invoke-DatabaseSqlQuery -Times 0 -Exactly
    Should -Invoke Invoke-Flyway -Times 0 -Exactly
  }

  It 'refuses invalid expected catalog grammar <Name> even under WhatIf' -ForEach @(
    @{ Name = 'bad space' }
    @{ Name = 'café' }
    @{ Name = "ATAPUtilities'x" }
    @{ Name = ('a' * 65) }
  ) {
    $script:parameters554.DatabaseName = $Name; $script:parameters554.ExpectedDatabaseName = $Name
    $script:originalParameters554 = ConvertTo-Json -InputObject $script:parameters554 -Compress
    { Invoke-Sequence554 -WhatIfMode } | Should -Throw '*InvalidInputs*'
    Should -Invoke Get-Content -Times 0 -Exactly
    Should -Invoke New-DatabaseSqlCommand -Times 0 -Exactly
    Should -Invoke Invoke-DatabaseSqlQuery -Times 0 -Exactly
  }

  It 'refuses unsafe or implicit verifier configuration <Fault>' -ForEach @(
    @{ Fault = 'pooling'; Text = 'Pooling=True;MultipleActiveResultSets=False' }
    @{ Fault = 'MARS'; Text = 'Pooling=False;MultipleActiveResultSets=True' }
    @{ Fault = 'missing pooling'; Text = 'MultipleActiveResultSets=False' }
    @{ Fault = 'missing MARS'; Text = 'Pooling=False' }
    @{ Fault = 'malformed'; Text = 'SENSITIVE-CONNECTION578' }
  ) {
    $script:connection554.ConnectionString = $Text
    $script:expectedConnectionString578 = $Text
    $caught578 = $null
    try { Invoke-Sequence554 } catch { $caught578 = $_ }
    $caught578 | Should -Not -BeNullOrEmpty
    $caught578.Exception.Message | Should -Match 'VerifierConnectionSettings'
    $caught578.Exception.Message | Should -Not -Match 'SENSITIVE-CONNECTION578'
    Should -Invoke New-DatabaseSqlCommand -Times 0 -Exactly
    Should -Invoke Invoke-DatabaseSqlQuery -Times 0 -Exactly
    Should -Invoke Invoke-Flyway -Times 0 -Exactly
    Should -Invoke Write-PSFMessage -Times 0 -Exactly -ParameterFilter { $Message -match 'SENSITIVE-CONNECTION578' }
  }

  It 'refuses any preexisting session binding <Value>' -ForEach @(
    @{ Value = 'ATAPUtilities'; Type = 'nvarchar' }
    @{ Value = 'Other'; Type = 'nvarchar' }
    @{ Value = 17; Type = 'int' }
  ) {
    $script:binding578.Value = $Value; $script:binding578.Type = $Type
    { Invoke-Sequence554 } | Should -Throw '*VerifierContextAlreadyBound*'
    $script:trace554.Count | Should -Be 0
    Should -Invoke New-DatabaseSqlCommand -Times 0 -Exactly
    Should -Invoke Invoke-Flyway -Times 0 -Exactly
  }

  It 'stops before fixtures on setup/readback failure <Fault>' -ForEach @(
    @{ Fault = 'create'; ExpectedCode = 'CatalogBindingSetupFailed' }
    @{ Fault = 'missing parameter'; ExpectedCode = 'CatalogBindingSetupFailed' }
    @{ Fault = 'execute'; ExpectedCode = 'CatalogBindingSetupFailed' }
    @{ Fault = 'no set'; ExpectedCode = 'VerifierCatalogBindingMismatch' }
    @{ Fault = 'wrong name'; ExpectedCode = 'VerifierCatalogBindingMismatch' }
    @{ Fault = 'wrong type'; ExpectedCode = 'VerifierCatalogBindingMismatch' }
  ) {
    $script:binding578.Fault = $Fault
    $caught578 = $null
    try { Invoke-Sequence554 } catch { $caught578 = $_ }
    $caught578 | Should -Not -BeNullOrEmpty
    $caught578.Exception.Message | Should -Match $ExpectedCode
    $caught578.Exception.Message | Should -Not -Match 'SENSITIVE-SETUP578'
    $caught578.Exception.Data['FailedPhase'] | Should -BeExactly 'CatalogBinding'
    @($caught578.Exception.Data['CompletedPhases']).Count | Should -Be 0
    $script:trace554.Count | Should -Be 0
    Should -Invoke Invoke-Flyway -Times 0 -Exactly
    Should -Invoke Write-PSFMessage -Times 0 -Exactly -ParameterFilter { $Message -match 'SENSITIVE-SETUP578' }
  }

  It 'aborts a changed late binding <Fault> without rebind or later fixture' -ForEach @(
    @{ Fault = 'catalog case' }
    @{ Fault = 'catalog trailing' }
    @{ Fault = 'catalog missing' }
    @{ Fault = 'catalog type' }
  ) {
    $script:guardFault554 = $Fault
    { Invoke-Sequence554 } | Should -Throw '*VerifierCatalogBindingMismatch*'
    ($script:trace554 -join '|') | Should -BeExactly 'before160|migrate00160'
    $script:binding578.Executed | Should -Be 1
    Should -Invoke New-DatabaseSqlCommand -Times 1 -Exactly
    Should -Invoke Invoke-Flyway -Times 1 -Exactly
  }

  It 'binds one exact clone name as parameter data and native expectation' {
    $clone = 'ATAPUtilities-rehearsal-578'
    $script:parameters554.DatabaseName = $clone; $script:parameters554.ExpectedDatabaseName = $clone
    $script:observedDatabase578 = $clone
    $script:originalParameters554 = ConvertTo-Json -InputObject $script:parameters554 -Compress
    $result = Invoke-Sequence554
    $result.Success | Should -BeTrue
    $result.DatabaseName | Should -BeExactly $clone
    $script:binding578.Parameter.Value | Should -BeExactly $clone
    $script:binding578.CommandText | Should -Not -Match ([regex]::Escape($clone))
    foreach ($call in $script:nativeCalls554) {
      $call.DatabaseName | Should -BeExactly $clone
      $call.Expected | Should -BeExactly $clone
    }
  }

  It 'refuses a second run on the bound verifier instead of clearing or rebinding it' {
    (Invoke-Sequence554).Success | Should -BeTrue
    { Invoke-Sequence554 } | Should -Throw '*VerifierContextAlreadyBound*'
    $script:binding578.Executed | Should -Be 1
    $script:nativeCalls554.Count | Should -Be 2
    $script:trace554.Count | Should -Be 6
    Should -Invoke New-DatabaseSqlCommand -Times 1 -Exactly
  }

  It 'carries only wrapped SQL numeric fields and safe type through the existing receipt message' -Tag 'SafeDiagnostics699' {
    $sql = New-SyntheticSqlFailure699
    $sql.Data['SECRET699-DATA'] = 'SECRET699-VALUE'
    $script:failure699 = [InvalidOperationException]::new('SECRET699-WRAPPER', $sql)
    Mock Invoke-DatabaseSqlQuery { throw $script:failure699 } -ParameterFilter { $CommandText -ceq $script:loginText554 }
    $caught699 = $null
    try { Invoke-Sequence554 } catch { $caught699 = $_ }
    $caught699 | Should -Not -BeNullOrEmpty
    $expected = 'Invoke-AceCommanderLoginFixtureSequence: FixtureExecutionFailed at before160. Diagnostic[Type=System.Data.SqlClient.SqlException;Sql=Number=207,State=1,Class=16,LineNumber=100|Number=208,State=1,Class=16,LineNumber=101]'
    $caught699.Exception.Message | Should -BeExactly $expected
    $receipt = @{ Error = $caught699.Exception.Message } | ConvertTo-Json | ConvertFrom-Json
    $receipt.Error | Should -BeExactly $expected
    $caught699.Exception.InnerException | Should -BeNullOrEmpty
    $caught699.Exception.Data.Contains('SECRET699-DATA') | Should -BeFalse
    $caught699.Exception.Data.Contains('Number') | Should -BeFalse
    $caught699.Exception.Data['FailedPhase'] | Should -BeExactly 'before160'
    @($caught699.Exception.Data['CompletedPhases']).Count | Should -Be 0
    $caught699.Exception.ToString() | Should -Not -Match 'SECRET699'
    Should -Invoke Write-PSFMessage -Times 0 -Exactly -ParameterFilter { $Message -match 'SECRET699' }
    Should -Invoke Invoke-Flyway -Times 0 -Exactly
    $script:loginCalls554 | Should -Be 0 # Filtered fault occurs before the default mock body.
  }

  It 'reports safe nonSQL type without copying numeric-looking Data or secret text' -Tag 'SafeDiagnostics699' {
    $script:failure699 = [FormatException]::new('SECRET699-NONSQL')
    $script:failure699.Data['Number'] = 999
    $script:failure699.Data['SECRET699-DATA'] = 'SECRET699-VALUE'
    Mock Invoke-DatabaseSqlQuery { throw $script:failure699 } -ParameterFilter { $CommandText -ceq $script:loginText554 }
    $caught699 = $null
    try { Invoke-Sequence554 } catch { $caught699 = $_ }
    $caught699 | Should -Not -BeNullOrEmpty
    $caught699.Exception.Message | Should -BeExactly 'Invoke-AceCommanderLoginFixtureSequence: FixtureExecutionFailed at before160. Diagnostic[Type=System.FormatException]'
    $caught699.Exception.InnerException | Should -BeNullOrEmpty
    $caught699.Exception.ToString() | Should -Not -Match 'SECRET699|999|Sql='
    Should -Invoke Write-PSFMessage -Times 0 -Exactly -ParameterFilter { $Message -match 'SECRET699' }
    Should -Invoke Invoke-Flyway -Times 0 -Exactly
  }

  It 'caps SQL diagnostics at four errors and a bounded receipt suffix' -Tag 'SafeDiagnostics699' {
    $script:failure699 = New-SyntheticSqlFailure699 -Count 7
    Mock Invoke-DatabaseSqlQuery { throw $script:failure699 } -ParameterFilter { $CommandText -ceq $script:loginText554 }
    $caught699 = $null
    try { Invoke-Sequence554 } catch { $caught699 = $_ }
    $caught699 | Should -Not -BeNullOrEmpty
    $message = $caught699.Exception.Message
    ([regex]::Matches($message, 'Number=')).Count | Should -Be 8 # Number and LineNumber per entry.
    $message | Should -Match 'Number=210,State=1,Class=16,LineNumber=103\]$'
    $message | Should -Not -Match 'Number=211|Number=212|Number=213|SECRET699'
    $message.Length | Should -BeLessOrEqual 512
    $caught699.Exception.InnerException | Should -BeNullOrEmpty
    Should -Invoke Invoke-Flyway -Times 0 -Exactly
  }

  It 'bounds wrapper traversal without exposing a deeply nested SQL exception' -Tag 'SafeDiagnostics699' {
    $script:failure699 = New-SyntheticSqlFailure699
    for ($index = 0; $index -lt 16; $index++) {
      $script:failure699 = [InvalidOperationException]::new('SECRET699-DEEP', $script:failure699)
    }
    Mock Invoke-DatabaseSqlQuery { throw $script:failure699 } -ParameterFilter { $CommandText -ceq $script:loginText554 }
    $caught699 = $null
    try { Invoke-Sequence554 } catch { $caught699 = $_ }
    $caught699 | Should -Not -BeNullOrEmpty
    $caught699.Exception.Message | Should -BeExactly 'Invoke-AceCommanderLoginFixtureSequence: FixtureExecutionFailed at before160. Diagnostic[Type=System.InvalidOperationException]'
    $caught699.Exception.ToString() | Should -Not -Match 'Sql=|SECRET699'
    $caught699.Exception.InnerException | Should -BeNullOrEmpty
    Should -Invoke Invoke-Flyway -Times 0 -Exactly
  }

  It 'replaces unlisted exception type metadata with a constant safe label' -Tag 'SafeDiagnostics699' {
    $script:failure699 = [System.Security.SecurityException]::new('SECRET699-UNLISTED')
    Mock Invoke-DatabaseSqlQuery { throw $script:failure699 } -ParameterFilter { $CommandText -ceq $script:loginText554 }
    $caught699 = $null
    try { Invoke-Sequence554 } catch { $caught699 = $_ }
    $caught699 | Should -Not -BeNullOrEmpty
    $caught699.Exception.Message | Should -BeExactly 'Invoke-AceCommanderLoginFixtureSequence: FixtureExecutionFailed at before160. Diagnostic[Type=Other]'
    $caught699.Exception.ToString() | Should -Not -Match 'SecurityException|SECRET699'
    Should -Invoke Invoke-Flyway -Times 0 -Exactly
  }
}

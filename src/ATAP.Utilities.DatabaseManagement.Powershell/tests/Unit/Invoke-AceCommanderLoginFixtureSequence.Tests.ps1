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
  . (Join-Path $PSScriptRoot '../../private/Invoke-AceCommanderLoginFixtureSequence.ps1')
  # Accepted immutable SQL is read as inert bytes only, never executed by this container.
  $script:loginPath554 = 'D:/ATAPArtifacts/Sprint0017/Task17.68.e/SharedMigration127/PostState-Fixture.sql'
  $script:decryptPath554 = 'D:/ATAPArtifacts/Sprint0017/Task17.68.e/SharedMigration127/Decrypt-PostState-Fixture.sql'
  $script:loginBytes554 = [IO.File]::ReadAllBytes($script:loginPath554)
  $script:decryptBytes554 = [IO.File]::ReadAllBytes($script:decryptPath554)
  $script:loginText554 = [Text.UTF8Encoding]::new($false, $true).GetString($script:loginBytes554)
  $script:decryptText554 = [Text.UTF8Encoding]::new($false, $true).GetString($script:decryptBytes554)
  $script:guardSql554 = 'SELECT DB_NAME() AS DatabaseName, CAST(@@SPID AS int) AS SessionId, @@TRANCOUNT AS TransactionCount;'

  function Invoke-Sequence554 {
    param([switch]$WhatIfMode)
    Invoke-AceCommanderLoginFixtureSequence -SqlConnection $script:connection554 -LoginFixturePath $script:loginPath554 -DecryptFixturePath $script:decryptPath554 -FlywayParameters $script:parameters554 -WhatIf:$WhatIfMode -Confirm:$false
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
    $script:guardFault554 = ''; $script:guardFaultAt554 = 3; $script:corrupt554 = ''
    $script:connection554 = [PSCustomObject]@{
      State = 'Open'; ClientConnectionId = [guid]'11111111-1111-1111-1111-111111111111'
    }
    foreach ($name in @('Close', 'Dispose', 'Open', 'ChangeDatabase')) {
      $script:connection554 | Add-Member -MemberType ScriptMethod -Name $name -Value {
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
        $row = [PSCustomObject]@{ DatabaseName = 'ATAPUtilities'; SessionId = 42; TransactionCount = 0 }
        if ($script:guardCalls554 -eq $script:guardFaultAt554) {
          switch ($script:guardFault554) {
            'spid' { $row.SessionId = 43 }
            'target' { $row.DatabaseName = 'Other' }
            'transaction' { $row.TransactionCount = 1 }
            'row shape' { $row.SessionId = '42' }
            'empty' { return }
            'connection id' { $script:connection554.ClientConnectionId = [guid]'22222222-2222-2222-2222-222222222222' }
            'closed' { $script:connection554.State = 'Closed' }
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
  }
  AfterEach {
    # Independent of expected exceptions, so refusal tests cannot hide a lifetime violation.
    $script:closeCalls554 | Should -Be 0
    foreach ($connection in $script:queryConnections554) {
      [object]::ReferenceEquals($connection, $script:connection554) | Should -BeTrue
    }
    foreach ($call in $script:nativeCalls554) {
      [object]::ReferenceEquals($call.Connection, $script:connection554) | Should -BeTrue
    }
    (ConvertTo-Json -InputObject $script:parameters554 -Compress) | Should -BeExactly $script:originalParameters554
  }

  It 'runs exactly six pinned phases, seven guards, two targets and the same immutable package' {
    $result = Invoke-Sequence554
    $expected = @('before160', 'migrate00160', 'after160', 'before170', 'migrate00170', 'after170')
    ($script:trace554 -join '|') | Should -BeExactly ($expected -join '|')
    ($result.CompletedPhases -join '|') | Should -BeExactly ($expected -join '|')
    $result.Success | Should -BeTrue
    $result.Status | Should -BeExactly 'SequenceCompleted'
    $result.SessionId | Should -Be 42
    $script:guardCalls554 | Should -Be 7
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
    Should -Invoke Invoke-DatabaseSqlQuery -Times 11 -Exactly
    Should -Invoke Get-Content -Times 2 -Exactly -ParameterFilter { $AsByteStream -and $Raw }
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
}

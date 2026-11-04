function Invoke-AceCommanderLoginFixtureSequence {
  <#
  .SYNOPSIS
    Runs the pinned before160/after160/before170/after170 fixture protocol.
  .DESCRIPTION
    Private source seam. Caller supplies an already-open, admitted isolated-copy
    verifier and approved immutable package inputs. This function grants no target,
    clone, credential, history or release authority. The verifier must be dedicated,
    nonpooled and MARS-disabled. It receives one immutable session catalog binding;
    the owner must retire its session after this call, including failure.

    The verifier's physical session stays open across both native Flyway calls.
    Query uses direct parameterless Text batches; command/reader lifetime belongs
    to that existing helper. Flyway uses a separate JDBC session from the borrowed
    connection information. No reconnect, connection disposal, retry, restore/drop
    or history repair occurs here. Failure can follow an already-committed V160.

    FlywayParameters requires DatabaseName, Environment, FlywayBasePath,
    FlywaySqlMigrationsPath, FlywayDataPath, FlywayTomlPath, PackageName and
    PackageVersion and ExpectedDatabaseName. The explicit expected catalog must
    match DatabaseName ordinally and satisfy the adopted ASCII1..64 grammar.
    Optional FlywayAdditionalArgs may contain only the matching dbo history pair;
    targets and other raw flags are owned by this sequence. No shared SQL location
    or alternate connection/configuration input is accepted. Native calls explicitly
    bind an empty shared-location parameter rather than resolving an ambient path.
  .PARAMETER SqlConnection
    Borrowed open Microsoft.Data.SqlClient connection, validated by existing helper.
  .PARAMETER LoginFixturePath
    Absolute path to the pinned exact-catalog successor Login fixture.
  .PARAMETER DecryptFixturePath
    Absolute path to the pinned exact-catalog successor decrypt fixture.
  .PARAMETER FlywayParameters
    Closed package/execution inputs described above, copied without modifying caller.
  .OUTPUTS
    Local Success/Status/completed-phase/session/package metadata. No SQL rows,
    connection strings, module definitions or sensitive fixture results are emitted.
    WhatIf returns ProposedOnly before file reads, SQL or native calls.
  .EXAMPLE
    Invoke-AceCommanderLoginFixtureSequence -SqlConnection $verifier -LoginFixturePath $loginPath -DecryptFixturePath $decryptPath -FlywayParameters $packageInputs -WhatIf
  .NOTES
    No enclosing transaction is allowed. Loss/change of session aborts, never recaptures.
  .LINK
    ../public/Invoke-Flyway.ps1
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateNotNull()][object]$SqlConnection,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$LoginFixturePath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DecryptFixturePath,
    [Parameter(Mandatory)][ValidateNotNull()][hashtable]$FlywayParameters
  )
  begin {
    $fn = 'Invoke-AceCommanderLoginFixtureSequence'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    $null = Get-Command Write-PSFMessage -ErrorAction Stop
  }
  process {
    $progress = @{ Phase = 'Validation'; Failure = 'InvalidInputs'; SessionId = $null }
    $completed = [Collections.Generic.List[string]]::new()
    try {
      $required = @('DatabaseName', 'ExpectedDatabaseName', 'Environment', 'FlywayBasePath', 'FlywaySqlMigrationsPath',
        'FlywayDataPath', 'FlywayTomlPath', 'PackageName', 'PackageVersion')
      $optional = @('FlywayExecutablePath', 'GitTag', 'GitCommit', 'FlywayAdditionalArgs')
      $common = @{}
      foreach ($key in $FlywayParameters.Keys) {
        if ($key -isnot [string] -or $key -notin ($required + $optional) -or $common.ContainsKey($key)) {
          throw 'InvalidInputs'
        }
        $common[$key] = $FlywayParameters[$key]
      }
      foreach ($key in $required) {
        if ($common[$key] -isnot [string] -or [string]::IsNullOrWhiteSpace($common[$key])) { throw 'InvalidInputs' }
      }
      foreach ($key in $optional | Where-Object { $_ -ne 'FlywayAdditionalArgs' }) {
        if ($common.ContainsKey($key) -and
            ($common[$key] -isnot [string] -or [string]::IsNullOrWhiteSpace($common[$key]))) { throw 'InvalidInputs' }
      }
      foreach ($key in @('FlywayBasePath', 'FlywaySqlMigrationsPath', 'FlywayDataPath', 'FlywayTomlPath', 'FlywayExecutablePath')) {
        if ($common.ContainsKey($key) -and -not [IO.Path]::IsPathFullyQualified($common[$key])) { throw 'InvalidInputs' }
      }
      if (-not [IO.Path]::IsPathFullyQualified($LoginFixturePath) -or
          -not [IO.Path]::IsPathFullyQualified($DecryptFixturePath)) { throw 'InvalidInputs' }
      if ($common.ExpectedDatabaseName -cnotmatch '\A[A-Za-z0-9_-]{1,64}\z' -or
          -not [string]::Equals($common.ExpectedDatabaseName, $common.DatabaseName, [StringComparison]::Ordinal)) {
        throw 'InvalidInputs'
      }
      $capturedExpectedCatalog = $common.ExpectedDatabaseName
      $progress.Failure = 'ConflictingFlywayArguments'
      if ($common.ContainsKey('FlywayAdditionalArgs')) {
        if ($null -eq $common.FlywayAdditionalArgs -or
            ($common.FlywayAdditionalArgs -isnot [string[]] -and $common.FlywayAdditionalArgs -isnot [object[]])) {
          throw 'ConflictingFlywayArguments'
        }
        foreach ($arg in $common.FlywayAdditionalArgs) {
          if ($arg -isnot [string] -or
              ($arg -cne '-defaultSchema=dbo' -and $arg -cne '-table=flyway_schema_history')) {
            throw 'ConflictingFlywayArguments'
          }
        }
        $common.Remove('FlywayAdditionalArgs')
      }
      if (-not $PSCmdlet.ShouldProcess($common.DatabaseName, 'Run pinned Login160/Decrypt170 fixture sequence')) {
        return [PSCustomObject]@{
          Status = 'ProposedOnly'; Success = $false; CompletedPhases = @()
          DatabaseName = $common.DatabaseName; SessionId = $null
          PackageName = $common.PackageName; PackageVersion = $common.PackageVersion
        }
      }
      $progress.Failure = 'DependencyUnavailable'
      $fixtureFlywayCommand = Get-Command Invoke-Flyway -CommandType Function -ErrorAction SilentlyContinue
      if ($null -eq $fixtureFlywayCommand -or -not [string]::IsNullOrEmpty($fixtureFlywayCommand.ModuleName) -or
          -not $fixtureFlywayCommand.Parameters.ContainsKey('ExpectedDatabaseName') -or
          -not $fixtureFlywayCommand.Parameters.ContainsKey('SqlConnection')) {
        . (Join-Path (Split-Path -Parent $PSScriptRoot) 'public/Invoke-Flyway.ps1')
      }
      $fixtureFlywayCommand = Get-Command Invoke-Flyway -CommandType Function -ErrorAction Stop
      if (-not [string]::IsNullOrEmpty($fixtureFlywayCommand.ModuleName) -or
          -not $fixtureFlywayCommand.Parameters.ContainsKey('ExpectedDatabaseName') -or
          -not $fixtureFlywayCommand.Parameters.ContainsKey('SqlConnection')) { throw 'DependencyUnavailable' }
      foreach ($dependency in @('Assert-DatabaseSqlConnectionIsOpen', 'Invoke-DatabaseSqlQuery', 'New-DatabaseSqlCommand')) {
        $null = Get-Command $dependency -ErrorAction Stop
      }
      $progress.Failure = 'InvalidVerifier'
      $verified = Assert-DatabaseSqlConnectionIsOpen -Connection $SqlConnection -Source $fn
      if (-not [object]::ReferenceEquals($verified, $SqlConnection) -or
          $SqlConnection.ClientConnectionId -isnot [guid] -or $SqlConnection.ClientConnectionId -eq [guid]::Empty) {
        throw 'InvalidVerifier'
      }
      $connectionId = $SqlConnection.ClientConnectionId
      $progress.Failure = 'VerifierConnectionSettings'
      $configuration = [Data.Common.DbConnectionStringBuilder]::new()
      try {
        $incomingText = $SqlConnection.get_ConnectionString()
        if ($incomingText -isnot [string]) { throw 'VerifierConnectionSettings' }
        $configuration.set_ConnectionString($incomingText)
        foreach ($key in @('Pooling', 'MultipleActiveResultSets')) {
          if (-not $configuration.ContainsKey($key) -or
              -not [string]::Equals([string]$configuration[$key], 'false', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'VerifierConnectionSettings'
          }
        }
      } finally { $configuration.Clear(); $incomingText = $null } # Never log/hash incoming connection text.
      $progress.Failure = 'FixturePinMismatch'
      $utf8 = [Text.UTF8Encoding]::new($false, $true)
      function readPinnedFixture([string]$Path, [string]$Hash) {
        [byte[]]$bytes = Get-Content -LiteralPath $Path -AsByteStream -Raw -ErrorAction Stop
        $actual = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
        if (-not [string]::Equals($actual, $Hash, [StringComparison]::Ordinal)) { throw 'FixturePinMismatch' }
        return $utf8.GetString($bytes)
      }
      $login = readPinnedFixture $LoginFixturePath '91DD6DE9CC3D89A573F19757FCBA3E4454B5DB0B0402C6A2414070D78AFF01BF'
      $decrypt = readPinnedFixture $DecryptFixturePath 'CD79D47FDD8DF818B7C70A6B2FB8183D99C6CD8AC79CFA70E9255442225E0433'

      function assertSession([switch]$BeforeBinding) {
        $progress.Failure = 'VerifierSessionChanged'
        if ([string]$SqlConnection.State -cne 'Open' -or $SqlConnection.ClientConnectionId -ne $connectionId) {
          throw 'VerifierSessionChanged'
        }
        $progress.Failure = 'SessionObservationFailed'
        $rows = @(Invoke-DatabaseSqlQuery -SqlConnection $SqlConnection -CommandText "SELECT DB_NAME() AS DatabaseName, CAST(@@SPID AS int) AS SessionId, @@TRANCOUNT AS TransactionCount, SESSION_CONTEXT(N'ATAP.AceCommander.Fixture.ExpectedCatalog') AS ExpectedCatalog, CONVERT(nvarchar(128), SQL_VARIANT_PROPERTY(SESSION_CONTEXT(N'ATAP.AceCommander.Fixture.ExpectedCatalog'), 'BaseType')) AS CatalogType;" -ErrorAction Stop)
        $progress.Failure = 'InvalidSessionObservation'
        if ($rows.Count -ne 1 -or $rows[0].DatabaseName -isnot [string] -or
            $rows[0].SessionId -isnot [int] -or $rows[0].SessionId -le 0 -or
            $rows[0].TransactionCount -isnot [int]) { throw 'InvalidSessionObservation' }
        $progress.Failure = 'VerifierTargetMismatch'
        if (-not [string]::Equals($rows[0].DatabaseName, $common.DatabaseName, [StringComparison]::Ordinal)) {
          throw 'VerifierTargetMismatch'
        }
        $progress.Failure = 'VerifierTransactionActive'
        if ($rows[0].TransactionCount -ne 0) { throw 'VerifierTransactionActive' }
        $progress.Failure = 'VerifierSessionChanged'
        if ($null -ne $progress.SessionId -and $progress.SessionId -ne $rows[0].SessionId) { throw 'VerifierSessionChanged' }
        if ($SqlConnection.ClientConnectionId -ne $connectionId -or [string]$SqlConnection.State -cne 'Open') {
          throw 'VerifierSessionChanged'
        }
        $progress.SessionId = $rows[0].SessionId
        if ($BeforeBinding) {
          $progress.Failure = 'VerifierContextAlreadyBound'
          if ($null -ne $rows[0].ExpectedCatalog -or $null -ne $rows[0].CatalogType) { throw 'VerifierContextAlreadyBound' }
        } else {
          $progress.Failure = 'VerifierCatalogBindingMismatch'
          if ($rows[0].ExpectedCatalog -isnot [string] -or $rows[0].CatalogType -cne 'nvarchar' -or
              -not [string]::Equals($rows[0].ExpectedCatalog, $capturedExpectedCatalog, [StringComparison]::Ordinal)) {
            throw 'VerifierCatalogBindingMismatch'
          }
        }
      }
      function setCatalogBinding {
        $progress.Phase = 'CatalogBinding'; $progress.Failure = 'CatalogBindingSetupFailed'
        $command = $null
        try {
          $text = "IF SESSION_CONTEXT(N'ATAP.AceCommander.Fixture.ExpectedCatalog') IS NOT NULL THROW 61990, N'Fresh verifier binding required.', 1; EXEC sys.sp_set_session_context @key=N'ATAP.AceCommander.Fixture.ExpectedCatalog', @value=@ExpectedCatalog, @read_only=1;"
          $command = New-DatabaseSqlCommand -SqlConnection $SqlConnection -CommandText $text -Parameters @{ ExpectedCatalog = $capturedExpectedCatalog } -CommandType ([Data.CommandType]::Text) -ErrorAction Stop
          $parameter = $command.Parameters['@ExpectedCatalog']
          if ($null -eq $parameter) { throw 'CatalogBindingSetupFailed' }
          $parameter.SqlDbType = [Data.SqlDbType]::NVarChar
          $parameter.Size = 128
          [void]$command.ExecuteNonQuery()
        } finally { if ($null -ne $command) { $command.Dispose() } }
      }
      function runFixture([string]$Phase, [string]$Text, [string]$Marker, [switch]$RequireCases) {
        $progress.Phase = $Phase; $progress.Failure = 'FixtureExecutionFailed'
        $rows = @(Invoke-DatabaseSqlQuery -SqlConnection $SqlConnection -CommandText $Text -ErrorAction Stop)
        $progress.Failure = 'FixtureMarkerMismatch'
        if ($rows.Count -ne 1 -or $rows[0].FixturePhase -isnot [string] -or
            -not [string]::Equals($rows[0].FixturePhase, $Marker, [StringComparison]::Ordinal)) {
          throw 'FixtureMarkerMismatch'
        }
        if ($RequireCases -and ($rows[0].SyntheticCasesPassed -isnot [int] -or $rows[0].SyntheticCasesPassed -ne 13)) {
          throw 'FixtureMarkerMismatch'
        }
        assertSession
        $completed.Add($Phase)
      }
      function migrate([string]$Version) {
        $progress.Phase = 'migrate' + $Version; $progress.Failure = 'FlywayExecutionFailed'
        $parameters = $common.Clone()
        $parameters.SqlConnection = $SqlConnection
        $parameters.ExpectedDatabaseName = $capturedExpectedCatalog
        $parameters.FlywayCommand = 'migrate'
        $parameters.FlywaySharedSqlMigrationsPath = ''
        $parameters.FlywayAdditionalArgs = @('-defaultSchema=dbo', '-table=flyway_schema_history', ('-target=' + $Version))
        $summaries = @(& $fixtureFlywayCommand @parameters -Confirm:$false -ErrorAction Stop)
        $progress.Failure = 'FlywayNotSuccessful'
        if ($summaries.Count -ne 1 -or $summaries[0].Success -isnot [bool] -or -not $summaries[0].Success) {
          throw 'FlywayNotSuccessful'
        }
        assertSession
        $completed.Add($progress.Phase)
      }
      assertSession -BeforeBinding
      setCatalogBinding
      assertSession
      runFixture 'before160' $login 'BeforeCaptured'
      migrate '00160'
      runFixture 'after160' $login 'AfterAssertionsPassed'
      runFixture 'before170' $decrypt 'BeforeCaptured'
      migrate '00170'
      runFixture 'after170' $decrypt 'AfterAssertionsPassed' -RequireCases
      [PSCustomObject]@{
        Status = 'SequenceCompleted'; Success = $true; CompletedPhases = $completed.ToArray()
        DatabaseName = $common.DatabaseName; SessionId = $progress.SessionId
        PackageName = $common.PackageName; PackageVersion = $common.PackageVersion
      }
    } catch {
      $caughtException = $_.Exception
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Fixture sequence stopped at $($progress.Phase): $($progress.Failure). Earlier migration commits may remain."
      # The receipt persists Message only. Never attach the original exception or its text/Data.
      # Inspect at most eight wrappers and four SQL errors; only known types and typed numbers escape.
      $diagnostic = ' Diagnostic[Type=Other]'
      try {
        $safeTypes = @('System.Exception', 'System.InvalidOperationException', 'System.ArgumentException',
          'System.FormatException', 'System.TimeoutException', 'System.ObjectDisposedException',
          'System.IO.IOException', 'System.Management.Automation.RuntimeException',
          'System.Management.Automation.MethodInvocationException', 'System.Management.Automation.ActionPreferenceStopException',
          'Microsoft.Data.SqlClient.SqlException', 'System.Data.SqlClient.SqlException')
        $safeType = 'Other'
        $sqlErrors = [Collections.Generic.List[string]]::new()
        $current = $caughtException
        for ($depth = 0; $depth -lt 8 -and $null -ne $current; $depth++) {
          $typeName = $current.GetType().FullName
          $safeType = if ($typeName -cin $safeTypes) { $typeName } else { 'Other' }
          if ($typeName -cin @('Microsoft.Data.SqlClient.SqlException', 'System.Data.SqlClient.SqlException')) {
            for ($index = 0; $index -lt [Math]::Min(4, $current.Errors.Count); $index++) {
              $sqlError = $current.Errors[$index]
              if ($sqlError.Number -is [int] -and $sqlError.State -is [byte] -and
                  $sqlError.Class -is [byte] -and $sqlError.LineNumber -is [int] -and $sqlError.LineNumber -ge 0) {
                $sqlErrors.Add("Number=$($sqlError.Number),State=$($sqlError.State),Class=$($sqlError.Class),LineNumber=$($sqlError.LineNumber)")
              }
            }
            break
          }
          $current = $current.InnerException
        }
        $sqlSuffix = if ($sqlErrors.Count) { ';Sql=' + ($sqlErrors -join '|') } else { '' }
        $diagnostic = ' Diagnostic[Type=' + $safeType + $sqlSuffix + ']'
      } catch { } # Diagnostics must never replace the original phase/failure outcome.
      $failureRecord = [InvalidOperationException]::new("Invoke-AceCommanderLoginFixtureSequence: $($progress.Failure) at $($progress.Phase)." + $diagnostic)
      $failureRecord.Data['FailedPhase'] = $progress.Phase
      $failureRecord.Data['CompletedPhases'] = $completed.ToArray()
      throw $failureRecord
    }
  }
  end {}
}

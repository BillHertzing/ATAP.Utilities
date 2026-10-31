function Invoke-AceCommanderLoginFixtureSequence {
  <#
  .SYNOPSIS
    Runs the pinned before160/after160/before170/after170 fixture protocol.
  .DESCRIPTION
    Private source seam. Caller supplies an already-open, admitted isolated-copy
    verifier and approved immutable package inputs. This function grants no target,
    clone, credential, history or release authority. Current fixtures still require
    ATAPUtilities; clone-guard compatibility and pipeline placement remain separate.

    The verifier's physical session stays open across both native Flyway calls.
    Query uses direct parameterless Text batches; command/reader lifetime belongs
    to that existing helper. Flyway uses a separate JDBC session from the borrowed
    connection information. No reconnect, connection disposal, retry, restore/drop
    or history repair occurs here. Failure can follow an already-committed V160.

    FlywayParameters requires DatabaseName, Environment, FlywayBasePath,
    FlywaySqlMigrationsPath, FlywayDataPath, FlywayTomlPath, PackageName and
    PackageVersion. Optional ExpectedDatabaseName must match DatabaseName.
    Optional FlywayAdditionalArgs may contain only the matching dbo history pair;
    targets and other raw flags are owned by this sequence. No shared SQL location
    or alternate connection/configuration input is accepted. Native calls explicitly
    bind an empty shared-location parameter rather than resolving an ambient path.
  .PARAMETER SqlConnection
    Borrowed open Microsoft.Data.SqlClient connection, validated by existing helper.
  .PARAMETER LoginFixturePath
    Absolute path to the unchanged accepted Login127 fixture with the pinned hash.
  .PARAMETER DecryptFixturePath
    Absolute path to the unchanged accepted decrypt fixture with the pinned hash.
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
      $required = @('DatabaseName', 'Environment', 'FlywayBasePath', 'FlywaySqlMigrationsPath',
        'FlywayDataPath', 'FlywayTomlPath', 'PackageName', 'PackageVersion')
      $optional = @('FlywayExecutablePath', 'ExpectedDatabaseName', 'GitTag', 'GitCommit', 'FlywayAdditionalArgs')
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
      if ($common.ContainsKey('ExpectedDatabaseName') -and
          -not [string]::Equals($common.ExpectedDatabaseName, $common.DatabaseName, [StringComparison]::Ordinal)) {
        throw 'InvalidInputs'
      }
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
      foreach ($dependency in @('Assert-DatabaseSqlConnectionIsOpen', 'Invoke-DatabaseSqlQuery', 'Invoke-Flyway')) {
        $null = Get-Command $dependency -ErrorAction Stop
      }
      $progress.Failure = 'InvalidVerifier'
      $verified = Assert-DatabaseSqlConnectionIsOpen -Connection $SqlConnection -Source $fn
      if (-not [object]::ReferenceEquals($verified, $SqlConnection) -or
          $SqlConnection.ClientConnectionId -isnot [guid] -or $SqlConnection.ClientConnectionId -eq [guid]::Empty) {
        throw 'InvalidVerifier'
      }
      $connectionId = $SqlConnection.ClientConnectionId
      $progress.Failure = 'FixturePinMismatch'
      $utf8 = [Text.UTF8Encoding]::new($false, $true)
      function readPinnedFixture([string]$Path, [string]$Hash) {
        [byte[]]$bytes = Get-Content -LiteralPath $Path -AsByteStream -Raw -ErrorAction Stop
        $actual = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
        if (-not [string]::Equals($actual, $Hash, [StringComparison]::Ordinal)) { throw 'FixturePinMismatch' }
        return $utf8.GetString($bytes)
      }
      $login = readPinnedFixture $LoginFixturePath 'A8815D635C1427013C9995B8DA558DF644F8C59C49AB04969068D0FF7790ABB1'
      $decrypt = readPinnedFixture $DecryptFixturePath '2E6C298EFFA2D764486CEB0C5441A0FF52CE070BDE4C06738B6CFDED5302AF8E'

      function assertSession {
        $progress.Failure = 'VerifierSessionChanged'
        if ([string]$SqlConnection.State -cne 'Open' -or $SqlConnection.ClientConnectionId -ne $connectionId) {
          throw 'VerifierSessionChanged'
        }
        $progress.Failure = 'SessionObservationFailed'
        $rows = @(Invoke-DatabaseSqlQuery -SqlConnection $SqlConnection -CommandText 'SELECT DB_NAME() AS DatabaseName, CAST(@@SPID AS int) AS SessionId, @@TRANCOUNT AS TransactionCount;' -ErrorAction Stop)
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
        $parameters.FlywayCommand = 'migrate'
        $parameters.FlywaySharedSqlMigrationsPath = ''
        $parameters.FlywayAdditionalArgs = @('-defaultSchema=dbo', '-table=flyway_schema_history', ('-target=' + $Version))
        $summaries = @(Invoke-Flyway @parameters -Confirm:$false -ErrorAction Stop)
        $progress.Failure = 'FlywayNotSuccessful'
        if ($summaries.Count -ne 1 -or $summaries[0].Success -isnot [bool] -or -not $summaries[0].Success) {
          throw 'FlywayNotSuccessful'
        }
        assertSession
        $completed.Add($progress.Phase)
      }
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
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Fixture sequence stopped at $($progress.Phase): $($progress.Failure). Earlier migration commits may remain."
      $failureRecord = [InvalidOperationException]::new("Invoke-AceCommanderLoginFixtureSequence: $($progress.Failure) at $($progress.Phase).")
      $failureRecord.Data['FailedPhase'] = $progress.Phase
      $failureRecord.Data['CompletedPhases'] = $completed.ToArray()
      throw $failureRecord
    }
  }
  end {}
}

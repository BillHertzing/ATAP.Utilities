param([string]$ServerInstance = $env:ATAP_V00150_TEST_SERVER)

Describe 'V00150 newline recovery against an authorized predecessor' -Skip:([string]::IsNullOrWhiteSpace($ServerInstance)) {
  BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    . (Join-Path $repoRoot 'Database/Powershell/public/Repair-AISupervisorV00150Newlines.ps1')
    Import-Module ATAP.Utilities.DatabaseManagement.Powershell -RequiredVersion 0.1.24 -ErrorAction Stop
    $v70 = Join-Path $repoRoot 'Database/Flyway/SQL/V00070__Create_Ace_AISupervisor_Telemetry.sql'
    $connection = [Microsoft.Data.SqlClient.SqlConnection]::new("Server=$ServerInstance;Database=ATAPUtilities;Integrated Security=true;TrustServerCertificate=true")
    $connection.Open()
    function Invoke-RecoveryTestSql([string]$Text) {
      $cmd = $connection.CreateCommand()
      try { $cmd.CommandText = $Text; $cmd.ExecuteScalar() } finally { $cmd.Dispose() }
    }
    $original = [string](Invoke-RecoveryTestSql "SELECT OBJECT_DEFINITION(OBJECT_ID(N'Ace.CaptureAISupervisorAttempt',N'P'))")
    if ($original -match '@CacheTokens') { throw 'Regression fixture requires the unapplied V00150 predecessor.' }
    $lf = $original.Replace("`r`n", "`n").Replace("`r", "`n")
  }

  AfterAll { if ($connection) { $connection.Dispose() } }

  It 'recovers <Variant> without changing procedure content and is stable on a second call' -TestCases @(
    @{Variant='LF'}, @{Variant='CRLF'}, @{Variant='Mixed'}, @{Variant='BareCR'}
  ) {
    param($Variant)
    try {
      $null = Invoke-RecoveryTestSql 'BEGIN TRANSACTION'
      $definition = switch ($Variant) {
        'CRLF' { $lf.Replace("`n", "`r`n") }
        'Mixed' { $lf.Replace("`nAS`n", "`r`nAS`n") }
        'BareCR' { $lf.Replace("`n", "`r") }
        default { $lf }
      }
      $alter = $definition -replace '^CREATE PROCEDURE', 'ALTER PROCEDURE'
      $null = Invoke-RecoveryTestSql $alter
      $result = Repair-AISupervisorV00150Newlines -SqlConnection $connection -PredecessorMigrationPath $v70 -Confirm:$false
      $result.Status | Should -BeIn @('Changed','Unchanged')
      (Repair-AISupervisorV00150Newlines -SqlConnection $connection -PredecessorMigrationPath $v70 -Confirm:$false).Status | Should -Be 'Unchanged'
      $actual = [string](Invoke-RecoveryTestSql "SELECT OBJECT_DEFINITION(OBJECT_ID(N'Ace.CaptureAISupervisorAttempt',N'P'))")
      ($actual -replace '^ALTER PROCEDURE','CREATE PROCEDURE').Replace("`r`n","`n") | Should -BeExactly $lf
      $actual.Replace("`r`n",'') | Should -Not -Match '[\r\n]'
    } finally {
      $null = Invoke-RecoveryTestSql 'IF @@TRANCOUNT>0 ROLLBACK'
    }
    ([string](Invoke-RecoveryTestSql "SELECT OBJECT_DEFINITION(OBJECT_ID(N'Ace.CaptureAISupervisorAttempt',N'P'))")) | Should -BeExactly $original
  }

  It 'rejects substantive predecessor drift and rolls back' {
    try {
      $null = Invoke-RecoveryTestSql 'BEGIN TRANSACTION'
      $null = Invoke-RecoveryTestSql (($lf -replace '^CREATE PROCEDURE','ALTER PROCEDURE') + "`n-- unauthorized drift")
      { Repair-AISupervisorV00150Newlines -SqlConnection $connection -PredecessorMigrationPath $v70 -Confirm:$false } | Should -Throw '*Complete canonical V00070 capture definition mismatch*'
    } finally { $null = Invoke-RecoveryTestSql 'IF @@TRANCOUNT>0 ROLLBACK' }
    ([string](Invoke-RecoveryTestSql "SELECT OBJECT_DEFINITION(OBJECT_ID(N'Ace.CaptureAISupervisorAttempt',N'P'))")) | Should -BeExactly $original
  }

  It 'previews without changing the predecessor' {
    (Repair-AISupervisorV00150Newlines -SqlConnection $connection -PredecessorMigrationPath $v70 -WhatIf).Status | Should -Be 'WouldChange'
    ([string](Invoke-RecoveryTestSql "SELECT OBJECT_DEFINITION(OBJECT_ID(N'Ace.CaptureAISupervisorAttempt',N'P'))")) | Should -BeExactly $original
  }
}

#Requires -Version 7.0
# Pester 5+ opt-in integration coverage for Stream J5.

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  Import-Module (Join-Path $moduleRoot 'ATAP.Utilities.DatabaseManagement.Powershell.psd1') -Force
}

Describe 'Invoke-FlywayRehearsal EXPWHERTZING integration' -Tag 'Integration' {
  It 'creates a per-run rehearsal database, runs Flyway, and drops it' -Skip:($env:ATAP_RUN_DB_INTEGRATION_TESTS -ne '1') {
    $invokeSqlcmd = Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue
    $flyway = Get-Command flyway -ErrorAction SilentlyContinue
    $databaseHost = if ($env:ATAP_REHEARSAL_DATABASE_HOST) { $env:ATAP_REHEARSAL_DATABASE_HOST } else { 'localhost' }
    $sqlInstance = if ($env:ATAP_REHEARSAL_SQL_INSTANCE) { $env:ATAP_REHEARSAL_SQL_INSTANCE } else { 'EXPWHERTZING' }
    $serverInstance = if ($sqlInstance -match '\\' -or $sqlInstance -match '^(?i)(tcp|np|lpc):') {
      $sqlInstance
    } else {
      '{0}\{1}' -f $databaseHost, $sqlInstance
    }

    if (-not $invokeSqlcmd) {
      Set-ItResult -Skipped -Because 'Invoke-Sqlcmd is not installed.'
      return
    }
    if (-not $flyway) {
      Set-ItResult -Skipped -Because 'flyway.exe is not installed.'
      return
    }

    try {
      Invoke-Sqlcmd -ServerInstance $serverInstance -Database 'master' -Query 'SELECT 1 AS ConnectionProbe;' -Encrypt Optional -TrustServerCertificate -ConnectionTimeout 5 -QueryTimeout 5 | Out-Null
    } catch {
      Set-ItResult -Skipped -Because "Cannot connect to SQL Server instance '$serverInstance': $($_.Exception.Message)"
      return
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ATAP_FlywayRehearsal_' + [Guid]::NewGuid().ToString('N'))
    $sqlPath = Join-Path $tempRoot 'SQL'
    $dataPath = Join-Path $tempRoot 'Data'
    $tomlPath = Join-Path $tempRoot 'flyway.toml'

    New-Item -ItemType Directory -Path $sqlPath, $dataPath -Force | Out-Null
    Set-Content -LiteralPath $tomlPath -Encoding UTF8 -Value @'
[flyway]
cleanDisabled = true
validateOnMigrate = true
mixed = true
createSchemas = true
locations = [
  "filesystem:./SQL"
]
'@
    Set-Content -LiteralPath (Join-Path $sqlPath 'V1__stream_j_rehearsal_probe.sql') -Encoding UTF8 -Value @'
CREATE TABLE dbo.StreamJRehearsalProbe
(
  Id int NOT NULL CONSTRAINT PK_StreamJRehearsalProbe PRIMARY KEY,
  CreatedAtUtc datetime2 NOT NULL CONSTRAINT DF_StreamJRehearsalProbe_CreatedAtUtc DEFAULT SYSUTCDATETIME()
);
'@

    try {
      $buildId = 'integration-{0}' -f [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
      $result = Invoke-FlywayRehearsal `
        -Application 'AceCommander' `
        -BuildId $buildId `
        -DatabaseHost $databaseHost `
        -SqlInstance $sqlInstance `
        -FlywayExecutablePath $flyway.Source `
        -FlywayBasePath $tempRoot `
        -FlywaySqlMigrationsPath $sqlPath `
        -FlywayDataPath $dataPath `
        -FlywayTomlPath $tomlPath `
        -IntegratedSecurity

      $result.Success | Should -BeTrue
      $result.RehearsalDb | Should -Be "AceCommander-rehearsal-$buildId"
      $result.ServerInstance | Should -Be $serverInstance

      $escapedName = $result.RehearsalDb.Replace("'", "''")
      $existsAfter = Invoke-Sqlcmd -ServerInstance $serverInstance -Database 'master' -Query "SELECT DB_ID(N'$escapedName') AS DbId;" -Encrypt Optional -TrustServerCertificate
      $existsAfter.DbId | Should -BeNullOrEmpty
    } finally {
      Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

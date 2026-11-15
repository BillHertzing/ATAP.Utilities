#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
# Static contract for Database/Verify/AceCommander/Verify_AceCommanderRole_V00220.sql (Impl-Rehearsal-Parameterize).
# Pins the verifier to V00220 (grant-row count incl. optional gate G6, Flyway checksum), to the V00210
# verifier's predecessor checksums, to the package migration names and to the rehearsal contract.
# Optional: supply ScriptDomAssemblyPath through New-PesterContainer -Data to parse the verifier.
param([string]$ScriptDomAssemblyPath)

BeforeAll {
  $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
  $verifierPath = Join-Path $repositoryRoot 'Database/Verify/AceCommander/Verify_AceCommanderRole_V00220.sql'
  $verifier = [IO.File]::ReadAllText($verifierPath)
  $migrationPath = Join-Path $repositoryRoot 'Database/Flyway/SQL/V00220__Create_AceCommander_Role.sql'
  $migration = [IO.File]::ReadAllText($migrationPath)
  $organization = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'Database/Verify/AceCommander/Verify_Organization_V00210.sql'))
  $contract = Get-Content -LiteralPath (Join-Path $repositoryRoot 'Database/Verify/RehearsalBoundaries.json') -Raw | ConvertFrom-Json
  function Get-ExpectedRows([string]$Text) {
    @([regex]::Matches($Text, "\(N'(?<v>\d{5})',N'(?<s>V\d{5}__[A-Za-z0-9_]+\.sql)',(?<c>-?\d+)\)") |
        ForEach-Object { '{0}|{1}|{2}' -f $_.Groups['v'].Value, $_.Groups['s'].Value, $_.Groups['c'].Value })
  }
  function Get-FlywayChecksum([string]$Text) {
    # Flyway ChecksumCalculator: CRC32 over each line's UTF-8 bytes without terminators, as a signed int.
    $table = [uint32[]]::new(256)
    for ($i = 0; $i -lt 256; $i++) { $c = [uint32]$i; for ($k = 0; $k -lt 8; $k++) { if ($c -band 1) { $c = ([uint32]3988292384 -bxor ($c -shr 1)) } else { $c = [uint32]($c -shr 1) } }; $table[$i] = $c }
    $crc = [uint32]::MaxValue
    foreach ($line in [regex]::Split($Text.TrimEnd("`n"), "\r\n|\n|\r")) {
      foreach ($b in [Text.Encoding]::UTF8.GetBytes($line)) { $crc = [uint32]($table[($crc -bxor $b) -band 0xFF] -bxor ($crc -shr 8)) }
    }
    [BitConverter]::ToInt32([BitConverter]::GetBytes([uint32]($crc -bxor [uint32]::MaxValue)), 0)
  }
}

Describe 'Verify_AceCommanderRole_V00220.sql static contract' -Tag 'Unit', 'RehearsalContract' {
  It 'expects the grant-row count that V00220 itself asserts (65, plus 2 while optional gate G6 is present)' {
    $base = [int]([regex]::Match($migration, 'DECLARE @ExpectedPermissionRows int = (\d+);').Groups[1].Value)
    $extra = if ($migration -match 'SET @ExpectedPermissionRows \+= (\d+);') { [int]$Matches[1] } else { 0 }
    $base | Should -Be 65
    $verifier | Should -Match ("DECLARE @ExpectedPermissionRows int = {0};" -f ($base + $extra))
  }
  It 'pins the 00220 history row to the actual V00220 Flyway checksum' {
    $row = @(Get-ExpectedRows $verifier | Where-Object { $_ -like '00220|*' })
    $row.Count | Should -Be 1
    $row[0] | Should -BeExactly ('00220|V00220__Create_AceCommander_Role.sql|{0}' -f (Get-FlywayChecksum $migration))
  }
  It 'carries exactly the V00210 verifier predecessor rows (00010-00210)' {
    $mine = @(Get-ExpectedRows $verifier | Where-Object { $_ -notlike '00220|*' })
    $theirs = @(Get-ExpectedRows $organization)
    $theirs.Count | Should -Be 20
    ($mine -join "`n") | Should -BeExactly ($theirs -join "`n")
  }
  It 'names exactly the migrations in Database/Flyway/SQL' {
    $names = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'Database/Flyway/SQL') -Filter 'V*.sql' -File | ForEach-Object Name | Sort-Object)
    (@(Get-ExpectedRows $verifier | ForEach-Object { $_.Split('|')[1] }) -join '|') | Should -BeExactly ($names -join '|')
  }
  It 'binds the session key, markers and pin recorded in the rehearsal contract' {
    $boundary = @($contract.boundaries | Where-Object version -CEQ '00220')
    $boundary.Count | Should -Be 1
    $verifier | Should -Match ([regex]::Escape("SESSION_CONTEXT(N'$($boundary[0].sessionContextKey)')"))
    $verifier | Should -Match "N'Before$($boundary[0].phaseTag)'"
    $verifier | Should -Match "N'After$($boundary[0].phaseTag)'"
    (Get-FileHash -LiteralPath $verifierPath -Algorithm SHA256).Hash | Should -BeExactly $boundary[0].verifiers[0].sha256
  }
  It 'is clone-only and read-only (no DDL, DML or permission statements outside temp tables)' {
    $verifier | Should -Match "NOT LIKE N'ATAPUtilities-rehearsal-%' OR DB_NAME\(\) = N'ATAPUtilities'"
    $verifier | Should -Not -Match '(?im)^\s*(CREATE|ALTER|DROP)\s+(ROLE|USER|TABLE|PROCEDURE|VIEW|SCHEMA)\b(?!\s+#)'
    $verifier | Should -Not -Match '(?im)^\s*(GRANT|REVOKE|DENY|UPDATE|DELETE|MERGE)\b'
    $verifier | Should -Not -Match '(?i)INSERT\s+(INTO\s+)?(?![#@])[A-Za-z\[]'
    $verifier | Should -Not -Match '(?i)utat0'
  }
  It 'is LF-only ASCII without a byte-order mark' {
    $bytes = [IO.File]::ReadAllBytes($verifierPath)
    @($bytes | Where-Object { $_ -eq 13 }).Count | Should -Be 0
    @($bytes | Where-Object { $_ -gt 127 }).Count | Should -Be 0
    $bytes[0] | Should -Not -Be 0xEF
  }
  It 'parses as one T-SQL batch with ScriptDom (as executed, with the phase declaration prefix)' -Skip:([string]::IsNullOrWhiteSpace($ScriptDomAssemblyPath)) {
    if (-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])) { Add-Type -Path $ScriptDomAssemblyPath -ErrorAction Stop }
    foreach ($phase in @('Before', 'After')) {
      $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
      $reader = [IO.StringReader]::new("DECLARE @VerificationPhase nvarchar(8)=N'$phase';" + [Environment]::NewLine + $verifier)
      try {
        $parseErrors = $null
        $fragment = $parser.Parse($reader, [ref]$parseErrors)
        @($parseErrors).Count | Should -Be 0 -Because (@($parseErrors | ForEach-Object { "$($_.Line):$($_.Message)" }) -join '; ')
        $fragment.Batches.Count | Should -Be 1
      } finally { $reader.Dispose() }
    }
  }
}

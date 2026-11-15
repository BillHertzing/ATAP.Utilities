#Requires -Version 7.0
#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

param([string]$ScriptDomAssemblyPath)

# Static contract for V00220 (single AceCommander role). No SQL engine or provider is loaded.
# Optional: supply ScriptDomAssemblyPath through New-PesterContainer -Data to parse the migration.
Describe 'V00220 AceCommander role static contract' {
  BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $flywayRoot = Join-Path $repoRoot 'Database\Flyway'
    $sqlRoot = Join-Path $flywayRoot 'SQL'
    $migrationPath = Join-Path $sqlRoot 'V00220__Create_AceCommander_Role.sql'
    $migration = [IO.File]::ReadAllText($migrationPath)
    $contract = Get-Content -LiteralPath (Join-Path $repoRoot 'Database\Verify\AceCommander\AceCommanderRole.Contract.json') -Raw | ConvertFrom-Json
    $version = Get-Content -LiteralPath (Join-Path $flywayRoot 'version.json') -Raw | ConvertFrom-Json
    $allowlist = Get-Content -LiteralPath (Join-Path $flywayRoot 'package-content-allowlist.json') -Raw | ConvertFrom-Json

    function Get-ContractRows([object[]]$Grants) {
      foreach ($grant in $Grants) {
        $target = if ($grant.securable -ceq 'SCHEMA') { "SCHEMA::$($grant.name)" } else { "$($grant.securable)::$($grant.schema).$($grant.name)" }
        foreach ($permission in $grant.permissions) {
          $columns = @($grant.columns | Where-Object { $_ })
          if ($columns.Count) { foreach ($column in $columns) { "$permission|$target|$column" } }
          else { "$permission|$target|" }
        }
      }
    }

    function Get-MigrationRows([string]$Text) {
      $pattern = '(?m)^\s*GRANT\s+(?<perms>[A-Z ,]+?)\s+ON\s+(?<class>OBJECT|TYPE|SCHEMA)::(?<target>\[[^\]]+\](?:\.\[[^\]]+\])?)\s*(?:\((?<cols>[^)]*)\))?\s+TO\s+\[AceCommander\];'
      foreach ($match in [regex]::Matches($Text, $pattern)) {
        $target = $match.Groups['target'].Value.Replace('[', '').Replace(']', '')
        $columns = @($match.Groups['cols'].Value.Split(',') | ForEach-Object { $_.Trim().Trim('[', ']') } | Where-Object { $_ })
        foreach ($permission in ($match.Groups['perms'].Value.Split(',') | ForEach-Object { $_.Trim() })) {
          if ($columns.Count) { foreach ($column in $columns) { "$permission|$($match.Groups['class'].Value)::$target|$column" } }
          else { "$permission|$($match.Groups['class'].Value)::$target|" }
        }
      }
    }

    $g6Pattern = '(?s)\s*-- BEGIN OPTIONAL GATE G6:.*?-- END OPTIONAL GATE G6\n'
  }

  It 'is the unique V00220 migration and leaves every applied migration byte-identical to the allowlist' {
    @(Get-ChildItem -LiteralPath $sqlRoot -File -Filter 'V00220__*.sql').Name | Should -Be @('V00220__Create_AceCommander_Role.sql')
    foreach ($entry in @($allowlist.files | Where-Object kind -CEQ 'migration')) {
      (Get-FileHash -LiteralPath (Join-Path $flywayRoot $entry.path) -Algorithm SHA256).Hash | Should -BeExactly $entry.sha256 -Because $entry.path
    }
    $applied = @($allowlist.files | Where-Object { $_.kind -ceq 'migration' -and $_.path -cnotmatch 'V00220__' })
    $applied.Count | Should -Be 20
    ($applied[-1].path) | Should -BeExactly 'SQL/V00210__Create_ReadOrganizationProject_Procedure.sql'
  }

  It 'bumps the package to 0.1.26 consistently' {
    $version.version | Should -BeExactly '0.1.26'
    $allowlist.sourceVersion | Should -BeExactly '0.1.26'
    $allowlist.packageId | Should -BeExactly 'ATAPUtilities.Database'
  }

  It 'keeps the Flyway checksum pinned by the Ace developer helper history gate' {
    # Flyway ChecksumCalculator: CRC32 over each line's UTF-8 bytes without terminators.
    # Ace AceCommander/Deployment/New-AceCommanderDeveloperAccount.ps1 pins this value for the
    # 21-row history; any byte change to V00220 must update that pin in the same change.
    $table = [uint32[]]::new(256)
    for ($i = 0; $i -lt 256; $i++) { $c = [uint32]$i; for ($k = 0; $k -lt 8; $k++) { if ($c -band 1) { $c = ([uint32]3988292384 -bxor ($c -shr 1)) } else { $c = [uint32]($c -shr 1) } }; $table[$i] = $c }
    $crc = [uint32]::MaxValue
    $lines = [regex]::Split($migration.TrimEnd("`n"), "\r\n|\n|\r")
    foreach ($line in $lines) { foreach ($b in [Text.Encoding]::UTF8.GetBytes($line)) { $crc = [uint32]($table[($crc -bxor $b) -band 0xFF] -bxor ($crc -shr 8)) } }
    [BitConverter]::ToInt32([BitConverter]::GetBytes([uint32]($crc -bxor [uint32]::MaxValue)), 0) | Should -Be -1500945638
  }

  It 'is LF-only ASCII without a byte-order mark' {
    $bytes = [IO.File]::ReadAllBytes($migrationPath)
    @($bytes | Where-Object { $_ -eq 13 }).Count | Should -Be 0
    @($bytes | Where-Object { $_ -gt 127 }).Count | Should -Be 0
    $bytes[0] | Should -Not -Be 0xEF
  }

  It 'is transactional and fail-closed' {
    $migration | Should -Match 'SET XACT_ABORT ON;'
    $migration | Should -Match 'BEGIN TRANSACTION;'
    $migration | Should -Match 'COMMIT TRANSACTION;'
    $migration | Should -Match 'IF XACT_STATE\(\) <> 0 ROLLBACK TRANSACTION;\s+THROW;'
    $migration | Should -Match "IF DB_NAME\(\) <> N'ATAPUtilities'"
    $migration | Should -Match 'THROW 62209'
  }

  It 'is additive: no drop, revoke, deny, data change, login or server-level statement' {
    $code = [regex]::Replace($migration, '(?s)/\*.*?\*/', '')
    $code = [regex]::Replace($code, '(?m)--.*$', '')
    foreach ($forbidden in @('\bDROP\b', '\bREVOKE\b', '\bDENY\b', '\bDELETE\b', '\bUPDATE\s+\[', '\bINSERT\s+INTO\b', '\bTRUNCATE\b',
        '\bALTER\s+TABLE\b', '\bCREATE\s+LOGIN\b', '\bALTER\s+LOGIN\b', '\bALTER\s+SERVER\b', 'sp_addsrvrolemember', '\bFOR\s+LOGIN\b',
        'AceCommanderTimelineReader', 'AceCommanderGraphReader', 'AceCommanderTagsTraversalReader', '\$\{')) {
      $code | Should -Not -Match $forbidden -Because "V00220 must stay additive ($forbidden)"
    }
  }

  It 'grants exactly the contract, with no other grantee' {
    $expected = @(Get-ContractRows $contract.grants | Sort-Object)
    $actual = @(Get-MigrationRows $migration | Sort-Object)
    $actual | Should -Be $expected
    @([regex]::Matches($migration, '(?m)^\s*GRANT\b')).Count | Should -Be @([regex]::Matches($migration, '(?m)^\s*GRANT\b.*TO \[AceCommander\];')).Count
  }

  It 'keeps the postcondition row count aligned with the contract, with and without the G6 block' {
    $all = @(Get-ContractRows $contract.grants)
    $base = @(Get-ContractRows @($contract.grants | Where-Object { -not $_.optionalGate }))
    $base.Count | Should -Be 65
    $all.Count | Should -Be 67
    $migration | Should -Match 'DECLARE @ExpectedPermissionRows int = 65;'
    $migration | Should -Match 'SET @ExpectedPermissionRows \+= 2;'
    $withoutG6 = [regex]::Replace($migration, $g6Pattern, "`n")
    $withoutG6 | Should -Not -Match 'VIEW DEFINITION'
    $withoutG6 | Should -Not -Match '@ExpectedPermissionRows \+='
    @(Get-MigrationRows $withoutG6 | Sort-Object) | Should -Be @($base | Sort-Object)
  }

  It 'marks G6 as an optional, removable block that is default include' {
    $migration | Should -Match '-- BEGIN OPTIONAL GATE G6: VIEW DEFINITION'
    $migration | Should -Match 'Default include, pending explicit operator confirmation'
    $migration | Should -Match '-- END OPTIONAL GATE G6'
    @($contract.grants | Where-Object optionalGate -CEQ 'G6').Count | Should -Be 2
  }

  It 'derives the member from the host machine name with no host literal and no login' {
    $migration | Should -Match "CONVERT\(sysname, SERVERPROPERTY\('MachineName'\)\) \+ N'\\SvcAceCommander'"
    $migration | Should -Match 'SUSER_SID\(@Account\)'
    $migration | Should -Match "N'CREATE USER ' \+ QUOTENAME\(@Account\) \+ N';'"
    $migration | Should -Match "N'ALTER ROLE \[AceCommander\] ADD MEMBER ' \+ QUOTENAME\(@MemberName\)"
    $migration | Should -Not -Match '(?i)utat0'
  }

  It 'creates the role idempotently and refuses a conflicting principal' {
    $migration | Should -Match "IF DATABASE_PRINCIPAL_ID\(N'AceCommander'\) IS NULL\s+EXEC sys\.sp_executesql N'CREATE ROLE \[AceCommander\] AUTHORIZATION \[dbo\];';"
    $migration | Should -Match 'THROW 62202'
    $migration | Should -Match 'THROW 62204'
  }

  It 'checks every contract securable as a precondition' {
    foreach ($grant in @($contract.grants | Where-Object securable -CNE 'SCHEMA')) {
      $name = "[$($grant.schema)].[$($grant.name)]"
      $migration | Should -Match ([regex]::Escape("N'$name'")) -Because "precondition for $name"
    }
  }

  It 'parses as one T-SQL batch with ScriptDom' -Skip:([string]::IsNullOrWhiteSpace($ScriptDomAssemblyPath)) {
    if (-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])) { Add-Type -Path $ScriptDomAssemblyPath -ErrorAction Stop }
    $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
    $reader = [IO.StringReader]::new($migration)
    try {
      $parseErrors = $null
      $fragment = $parser.Parse($reader, [ref]$parseErrors)
      @($parseErrors).Count | Should -Be 0 -Because (@($parseErrors | ForEach-Object { "$($_.Line):$($_.Message)" }) -join '; ')
      $fragment.Batches.Count | Should -Be 1
    } finally { $reader.Dispose() }
  }
}

#Requires -Version 7.0
#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

param([string]$ScriptDomAssemblyPath)

# Static migration/package-source verification only. No SQL engine or provider is loaded.
Describe 'Forward organization migration source package' {
  BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $sqlRoot = Join-Path $repositoryRoot 'Database/Flyway/SQL'
    $componentRoot = Join-Path $repositoryRoot 'Database/Schema/ACE'
    $organizationVerifier = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Verify_Organization_V00210.sql'))
    $migrations = @(
      @{ Version = '00180'; File = 'V00180__Create_Organization_Eligibility_Schema.sql'; Source = 'OrganizationEligibility.sql'; Batches = 1 },
      @{ Version = '00190'; File = 'V00190__Create_ReadOrganizationEligibility_Procedure.sql'; Source = 'ReadOrganizationEligibility.sql'; Batches = 1 },
      @{ Version = '00200'; File = 'V00200__Create_Organization_Bootstrap.sql'; Source = 'BootstrapOrganization.sql'; Batches = 2 },
      @{ Version = '00210'; File = 'V00210__Create_ReadOrganizationProject_Procedure.sql'; Source = 'ReadOrganizationProject.sql'; Batches = 1 }
    )
    if (-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])) {
      if (-not $ScriptDomAssemblyPath -or -not (Test-Path -LiteralPath $ScriptDomAssemblyPath -PathType Leaf)) {
        throw 'Supply an existing ScriptDomAssemblyPath through New-PesterContainer -Data; no install or SQL connection is performed.'
      }
      Add-Type -Path $ScriptDomAssemblyPath -ErrorAction Stop
    }
  }

  It 'parses the dual-baseline verifier in the <Phase> session phase' -Tag 'Rehearsal1730' -ForEach @(
    @{ Phase = 'Before' }, @{ Phase = 'After' }
  ) {
    $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
    $reader = [IO.StringReader]::new("DECLARE @VerificationPhase nvarchar(8)=N'$Phase';" + [Environment]::NewLine + $organizationVerifier)
    try {
      $parseErrors = $null
      $fragment = $parser.Parse($reader, [ref]$parseErrors)
      @($parseErrors).Count | Should -Be 0 -Because (@($parseErrors | ForEach-Object Message) -join '; ')
      $fragment.Batches.Count | Should -Be 1
    } finally { $reader.Dispose() }
  }

  It 'captures every organization table declared by the retained migrations plus the full linked account' -Tag 'Rehearsal1730' {
    $declared = @($migrations | ForEach-Object {
      $text = [IO.File]::ReadAllText((Join-Path $sqlRoot $_.File))
      [regex]::Matches($text, '(?i)CREATE\s+TABLE\s+\[?ACE\]?\.\[?(?<name>[A-Za-z][A-Za-z0-9]*)\]?') |
        ForEach-Object { $_.Groups['name'].Value }
    } | Sort-Object -Unique)
    $declared.Count | Should -Be 17
    $inventory = [regex]::Match($organizationVerifier, '(?s)INSERT @OrganizationTables VALUES(?<body>.*?);').Groups['body'].Value
    $captured = @([regex]::Matches($inventory, "N'(?<name>[^']+)'") | ForEach-Object { $_.Groups['name'].Value } | Sort-Object)
    $captured | Should -Be $declared
    $organizationVerifier | Should -Match "IF @BaselineVersion = 210 INSERT @OrganizationTables VALUES \(N'User'\)"
    $organizationVerifier | Should -Match 'SELECT \* FROM ACE.\x27\+QUOTENAME\(@TableName\)'
    foreach ($field in @('c.system_type_id', 'c.user_type_id', 'c.max_length', 'c.precision', 'c.scale', 'c.is_nullable')) {
      $organizationVerifier | Should -Match ([regex]::Escape($field))
    }
  }

  It 'allows only exact V170 and V210 histories and retains full V210 history in both directions' -Tag 'Rehearsal1730' {
    $organizationVerifier | Should -Match 'CASE @HistoryRows WHEN 16 THEN 170 WHEN 20 THEN 210 END'
    $organizationVerifier | Should -Match 'IF @BaselineVersion IS NULL'
    $organizationVerifier | Should -Match '\[success\] IS NULL OR \[success\] <> 1'
    ([regex]::Matches($organizationVerifier, 'EXCEPT SELECT \[version\],\[script\],\[checksum\]')).Count | Should -Be 4
    $organizationVerifier | Should -Match 'SELECT \* FROM #Organization210History EXCEPT SELECT \* FROM dbo.flyway_schema_history'
    $organizationVerifier | Should -Match 'IF @BaselineVersion = 210 AND EXISTS \(SELECT \* FROM dbo.flyway_schema_history EXCEPT SELECT \* FROM #Organization210History\)'
    foreach ($checksum in @(902861142, -507530288, 2085240197, -1323700875)) {
      $organizationVerifier | Should -Match ([regex]::Escape([string]$checksum))
    }
  }

  It 'keeps initial upgrade emptiness separate from exact populated-state comparison' -Tag 'Rehearsal1730' {
    $organizationVerifier | Should -Match '(?s)IF @BaselineVersion = 170 AND.*?Exact V170 predecessor shape required'
    $organizationVerifier | Should -Match '(?s)IF @BaselineVersion = 170\s+BEGIN\s+SET @Check=.*?Schema deployment must not bootstrap data'
    $organizationVerifier | Should -Match '(?s)IF @BaselineVersion = 170\s+EXEC sys.sp_executesql.*?Schema deployment must leave accounts unlinked'
    $organizationVerifier | Should -Match 'i.is_primary_key=1 AND ic.key_ordinal>0'
    $organizationVerifier | Should -Match 'WITHIN GROUP \(ORDER BY ic.key_ordinal\)'
    $organizationVerifier | Should -Match 'FOR JSON PATH,INCLUDE_NULL_VALUES'
    foreach ($snapshot in @('PrimaryKeyOrder', 'ShapeJson', 'RowsJson')) {
      $organizationVerifier | Should -Match ($snapshot + ' COLLATE Latin1_General_100_BIN2')
      $organizationVerifier | Should -Match ('DATALENGTH\(' + $snapshot + '\)')
    }
    $organizationVerifier | Should -Match 'Complete populated-state snapshot required'
    $organizationVerifier | Should -Match 'Populated organization or account state changed'
  }

  It 'keeps all writes in verifier-owned temporary state and preserves the existing phase contract' -Tag 'Rehearsal1730' {
    $organizationVerifier | Should -Not -Match '(?im)^\s*(UPDATE|DELETE|MERGE|DROP|TRUNCATE|ALTER|GRANT|DENY|REVOKE)\b'
    $organizationVerifier | Should -Not -Match '(?i)\bINSERT\s+(?:\[?(?:ACE|ATAPUtilities|dbo)\]?\.)'
    $organizationVerifier | Should -Not -Match '(?im)^\s*EXEC(?:UTE)?\s+(?:\[?ACE\]?\.)?\[?BootstrapOrganization\]?\b'
    $organizationVerifier | Should -Match 'CREATE TABLE #Organization210Data'
    $organizationVerifier | Should -Match 'INSERT #Organization210Data VALUES'
    $organizationVerifier | Should -Match 'SessionId = @@SPID AND Catalog = DB_NAME\(\) AND BaselineVersion IN \(170,210\)'
    $organizationVerifier | Should -Match "SELECT CASE @VerificationPhase WHEN N'Before' THEN N'Before210' ELSE N'After210' END AS FixturePhase"
    $sequence = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'src/ATAP.Utilities.DatabaseManagement.Powershell/public/Invoke-FlywayRehearsal.ps1'))
    $sequence | Should -Match "before\[0\]\.FixturePhase -cne 'Before210'"
    $sequence | Should -Match "after\[0\]\.FixturePhase -cne 'After210'"
    $sequence | Should -Match "foreach \(\`$operation in @\('validate', 'migrate', 'validate'\)\)"
    $sequence | Should -Match 'Plain batches keep local temporary snapshots in the verifier session'
  }

  It 'reserves each migration exactly once in prerequisite order after V00170' {
    $active = @(Get-ChildItem -LiteralPath $sqlRoot -File -Filter 'V*.sql' | Sort-Object Name)
    foreach ($migration in $migrations) {
      $matches = @($active | Where-Object Name -Match ('^V' + $migration.Version + '__'))
      $matches.Count | Should -Be 1
      $matches[0].Name | Should -BeExactly $migration.File
    }
    @($active.Name | Where-Object { $_ -match '^V00(180|190|200|210)__' }) |
      Should -Be @($migrations.File)
    [array]::IndexOf($active.Name, 'V00170__Create_ACE_UserInformation_Decrypt_Procedure.sql') |
      Should -BeLessThan ([array]::IndexOf($active.Name, $migrations[0].File))
  }

  It 'preserves accepted bodies apart from the explicit caller-bound DDL catalog guard' -Tag 'UL1617Catalog' {
    foreach ($migration in $migrations) {
      $actual = [IO.File]::ReadAllText((Join-Path $sqlRoot $migration.File))
      $source = [IO.File]::ReadAllText((Join-Path $componentRoot $migration.Source))
      $expectedBody = [regex]::Replace($source, '\A/\*[\s\S]*?\*/', '')
      if ($migration.Source -in @('OrganizationEligibility.sql','BootstrapOrganization.sql')) {
        $literal = "DB_NAME() <> N'ATAPUtilities'"
        $catalogGuard = '(DB_NAME() IS NULL OR DB_NAME() COLLATE Latin1_General_100_BIN2 <> N''${atap_required_catalog}'' COLLATE Latin1_General_100_BIN2 OR DATALENGTH(DB_NAME()) <> DATALENGTH(N''${atap_required_catalog}''))'
        $position = $expectedBody.IndexOf($literal, [StringComparison]::Ordinal)
        $position | Should -BeGreaterOrEqual 0
        $expectedBody = $expectedBody.Substring(0,$position) + $catalogGuard + $expectedBody.Substring($position+$literal.Length)
      }
      [regex]::Replace($actual, '\A/\*[\s\S]*?\*/', '') | Should -BeExactly $expectedBody
    }
  }

  It 'binds the two unapplied DDL guards and allowlist hashes while retaining the runtime bootstrap catalog guard' -Tag 'UL1617Catalog' {
    $allowlist = Get-Content -LiteralPath (Join-Path $repositoryRoot 'Database/Flyway/package-content-allowlist.json') -Raw | ConvertFrom-Json
    foreach ($file in @('V00180__Create_Organization_Eligibility_Schema.sql','V00200__Create_Organization_Bootstrap.sql')) {
      $text = [IO.File]::ReadAllText((Join-Path $sqlRoot $file))
      ([regex]::Matches($text,[regex]::Escape('${atap_required_catalog}'))).Count | Should -Be 2
      $entry = @($allowlist.files | Where-Object path -CEQ ('SQL/' + $file))
      $entry.Count | Should -Be 1
      $entry[0].sha256 | Should -BeExactly (Get-FileHash -LiteralPath (Join-Path $sqlRoot $file) -Algorithm SHA256).Hash
    }
    $bootstrap = [IO.File]::ReadAllText((Join-Path $sqlRoot 'V00200__Create_Organization_Bootstrap.sql'))
    ([regex]::Matches($bootstrap,[regex]::Escape("DB_NAME() <> N'ATAPUtilities'"))).Count | Should -Be 1
    $bootstrap.Substring($bootstrap.IndexOf('CREATE PROCEDURE')) | Should -Match "IF DB_NAME\(\) <> N'ATAPUtilities' OR @@TRANCOUNT <> 1"
  }

  It 'parses all five SQL batches with the SQL Server 2022 grammar' {
    foreach ($migration in $migrations) {
      $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
      $reader = [IO.StringReader]::new([IO.File]::ReadAllText((Join-Path $sqlRoot $migration.File)))
      try {
        $parseErrors = $null
        $script = $parser.Parse($reader, [ref]$parseErrors)
        @($parseErrors).Count | Should -Be 0 -Because $migration.File
        $script.Batches.Count | Should -Be $migration.Batches -Because $migration.File
      }
      finally { $reader.Dispose() }
    }
  }

  It 'adds no destructive or permission statements or bootstrap invocation' {
    foreach ($migration in $migrations) {
      $sql = [IO.File]::ReadAllText((Join-Path $sqlRoot $migration.File))
      $sql | Should -Not -Match '(?im)^\s*(DROP|TRUNCATE|GRANT|DENY|REVOKE)\b'
      $sql | Should -Not -Match '(?im)^\s*EXEC(?:UTE)?\s+(?:\[?ACE\]?\.)?\[?BootstrapOrganization\]?\b'
    }
  }

  It 'leaves the two applied login migrations byte-identical to their accepted receipts' {
    (Get-FileHash -LiteralPath (Join-Path $sqlRoot 'V00160__Create_AceCommander_Login_Schema_And_Guest.sql') -Algorithm SHA256).Hash |
      Should -BeExactly '83BE7E03DC379EB84BCA61641A307C00667E30347A1B1B2EEAB81CDBAD7907CE'
    (Get-FileHash -LiteralPath (Join-Path $sqlRoot 'V00170__Create_ACE_UserInformation_Decrypt_Procedure.sql') -Algorithm SHA256).Hash |
      Should -BeExactly '7EF06E2052238BFC18BB97430E70BB2CCA6E99F63C71F2ECC7F6AF7713A6BB89'
  }

  It 'selects the new Experimental source version without changing package identity' {
    $version = Get-Content -LiteralPath (Join-Path $repositoryRoot 'Database/Flyway/version.json') -Raw | ConvertFrom-Json
    $version.version | Should -BeExactly '0.1.19-Sprint.1'
    $allowlist = Get-Content -LiteralPath (Join-Path $repositoryRoot 'Database/Flyway/package-content-allowlist.json') -Raw | ConvertFrom-Json
    $allowlist.packageId | Should -BeExactly 'ATAPUtilities.Database'
  }

  It 'binds all four new migrations to the exact source-version allowlist' -Tag 'Allowlist' {
    $allowlist = Get-Content -LiteralPath (Join-Path $repositoryRoot 'Database/Flyway/package-content-allowlist.json') -Raw | ConvertFrom-Json
    $allowlist.sourceVersion | Should -BeExactly '0.1.19-Sprint.1'
    @($allowlist.files).Count | Should -Be 31
    foreach ($migration in $migrations) {
      $entries = @($allowlist.files | Where-Object path -EQ ('SQL/' + $migration.File))
      $entries.Count | Should -Be 1
      $entries[0].kind | Should -BeExactly 'migration'
      $entries[0].sha256 | Should -BeExactly (Get-FileHash -LiteralPath (Join-Path $sqlRoot $migration.File) -Algorithm SHA256).Hash
    }
  }
}

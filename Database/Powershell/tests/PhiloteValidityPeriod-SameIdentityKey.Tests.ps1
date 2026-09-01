Set-StrictMode -Version Latest

Describe 'PhiloteValidityPeriod same-identity key migration static contract' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
        $migrationName = 'V00040__Add_PhiloteValidityPeriod_SameIdentity_Key.sql'
        $migrationPath = Join-Path $sqlDirectory $migrationName
        $migration = Get-Content -LiteralPath $migrationPath -Raw
        $activeMigrations = @(Get-ChildItem -LiteralPath $sqlDirectory -File -Filter 'V*.sql' | Sort-Object Name)

        $scriptDomPath = 'C:\Program Files\PowerShell\Modules\SqlServer\22.3.0\coreclr\Microsoft.SqlServer.TransactSql.ScriptDom.dll'
        if (-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])) {
            Add-Type -LiteralPath $scriptDomPath
        }
    }

    It 'allocates V00040 after the characterized V00010 and V00030 head without collision' {
        $versions = @($activeMigrations | ForEach-Object {
                if ($_.Name -notmatch '^(V\d+)__') {
                    throw "Invalid migration name: $($_.Name)"
                }
                $matches[1]
            })

        @($versions | Group-Object | Where-Object Count -gt 1).Count | Should -Be 0
        @($versions | Select-Object -First 3) | Should -Be @('V00010', 'V00030', 'V00040')
    }

    It 'parses as SQL Server 2022 T-SQL without errors' {
        $reader = [IO.StringReader]::new($migration)
        $errors = [Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
        $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
        try {
            $null = $parser.Parse($reader, [ref]$errors)
        }
        finally {
            $reader.Dispose()
        }

        @($errors | ForEach-Object { "Line $($_.Line), column $($_.Column): $($_.Message)" }) | Should -BeNullOrEmpty
    }

    It 'adds exactly the approved same-identity candidate key' {
        $migration | Should -Match 'ALTER TABLE \[ATAPUtilities\]\.\[PhiloteValidityPeriod\]'
        $migration | Should -Match 'CONSTRAINT \[UQ_PhiloteValidityPeriod_PhiloteId_PhiloteValidityPeriodId\]\s+UNIQUE \(\[PhiloteId\], \[PhiloteValidityPeriodId\]\)'
        ([regex]::Matches($migration, '(?im)^\s*ALTER\s+TABLE\b')).Count | Should -Be 1
        ([regex]::Matches($migration, '(?im)^\s*ADD\s+CONSTRAINT\b')).Count | Should -Be 1
    }

    It 'fails closed when the predecessor table, columns, or target constraint are unsuitable' {
        $migration | Should -Match "OBJECT_ID\(N'\[ATAPUtilities\]\.\[PhiloteValidityPeriod\]', N'U'\) IS NULL"
        $migration | Should -Match "COL_LENGTH\(N'ATAPUtilities\.PhiloteValidityPeriod', N'PhiloteId'\) IS NULL"
        $migration | Should -Match "COL_LENGTH\(N'ATAPUtilities\.PhiloteValidityPeriod', N'PhiloteValidityPeriodId'\) IS NULL"
        $migration | Should -Match "\[name\] = N'UQ_PhiloteValidityPeriod_PhiloteId_PhiloteValidityPeriodId'"
        $migration | Should -Match 'THROW 51040'
        $migration | Should -Match 'THROW 51041'
        $migration | Should -Match 'THROW 51042'
    }

    It 'contains no unrelated object, data, or security changes' {
        foreach ($pattern in @(
                '\b(?:INSERT|UPDATE|DELETE|MERGE|GRANT|REVOKE)\b',
                '\b(?:CREATE|DROP)\s+(?:TABLE|SCHEMA|PROCEDURE|VIEW|FUNCTION|LOGIN|USER|ROLE)\b',
                '\bALTER\s+(?:LOGIN|USER|ROLE)\b',
                '\b(?:Tag|Tenant|Principal|Alias|Successor|Assignment)\b'
            )) {
            $migration | Should -Not -Match $pattern
        }
    }
}

Describe 'PhiloteValidityPeriod same-identity key disposable-database gates' {
    It 'applies from a fresh database and preserves all existing periods' -Skip {
        throw 'Requires an explicitly authorized disposable SQL Server and Flyway execution.'
    }

    It 'upgrades the characterized V00010 and V00030 head and rejects a mismatched identity-period reference' -Skip {
        throw 'Requires an explicitly authorized disposable SQL Server and a dependent fixture table.'
    }
}

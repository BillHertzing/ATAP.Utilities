Set-StrictMode -Version Latest

Describe 'AceOutpostContentSummaryPrototype Flyway migration static contract' {
    BeforeAll {
        $repoRoot = (Get-Location).Path
        $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
        $migrationName = 'V00030__Create_AceOutpostContentSummaryPrototype.sql'
        $migrationPath = Join-Path $sqlDirectory $migrationName
        $migration = Get-Content -LiteralPath $migrationPath -Raw
        $activeMigrations = @(Get-ChildItem -LiteralPath $sqlDirectory -File -Filter 'V*.sql' | Sort-Object Name)
    }

    It 'allocates V00030 without active-version collision' {
        $versions = @($activeMigrations | ForEach-Object { if ($_.Name -notmatch '^(V\d+)__') { throw "Invalid migration name: $($_.Name)" }; $matches[1] })
        @($versions | Group-Object | Where-Object Count -gt 1).Count | Should -Be 0
        @($versions | Where-Object { $_ -eq 'V00010' }).Count | Should -Be 1
        @($versions | Where-Object { $_ -eq 'V00030' }).Count | Should -Be 1
        @($versions | Where-Object { $_ -eq 'V00020' }).Count | Should -Be 0
        (Get-ChildItem -LiteralPath (Join-Path $repoRoot 'Database\Flyway\Archive') -Recurse -File -Filter 'V00020__*.sql').Count | Should -BeGreaterThan 0
    }
    It 'creates exactly the ratified table and columns' {
        $migration | Should -Match 'CREATE TABLE \[ATAPUtilities\]\.\[AceOutpostContentSummaryPrototype\]'
        $migration | Should -Match '\[OperationId\]\s+uniqueidentifier\s+NOT NULL'
        $migration | Should -Match '\[Payload\]\s+nvarchar\(4000\)\s+NOT NULL'
        $migration | Should -Not -Match '\[CorrelationId\]'
    }
    It 'defines exact primary-key and payload constraints' {
        $migration | Should -Match 'CONSTRAINT \[PK_AceOutpostContentSummaryPrototype\]\s+PRIMARY KEY \(\[OperationId\]\)'
        $migration | Should -Match 'CONSTRAINT \[CK_AceOutpostContentSummaryPrototype_Payload\]\s+CHECK \(LEN\(\[Payload\]\) BETWEEN 1 AND 4000\)'
    }
    It 'fails closed for absent schema or existing target object' {
        $migration | Should -Match "SCHEMA_ID\(N'ATAPUtilities'\) IS NULL"
        $migration | Should -Match "OBJECT_ID\(N'\[ATAPUtilities\]\.\[AceOutpostContentSummaryPrototype\]'\) IS NOT NULL"
        $migration | Should -Match 'THROW 51030'
        $migration | Should -Match 'THROW 51031'
    }
    It 'contains no unrelated DDL, DML, or security operations' {
        foreach ($pattern in @('\b(?:INSERT|UPDATE|DELETE|MERGE|GRANT|REVOKE)\b', '\b(?:CREATE|ALTER|DROP)\s+(?:LOGIN|USER|ROLE)\b', '\bUSE\s+', '\bCREATE\s+(?:PROCEDURE|VIEW|FUNCTION|SCHEMA)\b')) { $migration | Should -Not -Match $pattern }
    }
}

Describe 'AceOutpostContentSummaryPrototype disposable local Flyway contract' {
    $discoveryInstance = [Environment]::GetEnvironmentVariable('ATAP_FLYWAY_DISPOSABLE_SQL_INSTANCE', 'Process')
    $isLocal = $discoveryInstance -and (($discoveryInstance -match "(?i)^(?:\\.|localhost|127\.0\.0\.1|$([regex]::Escape($env:COMPUTERNAME)))(?:\\[^;]+)?$") -or ($discoveryInstance -eq "$env:COMPUTERNAME\EXPWHERTZING"))
    $canRun = $isLocal -and (Get-Command flyway -ErrorAction SilentlyContinue) -and (Get-Command sqlcmd -ErrorAction SilentlyContinue)

    BeforeAll {
        $repoRoot = (Get-Location).Path
        $sqlDirectory = Join-Path $repoRoot 'Database\Flyway\SQL'
        $migrationName = 'V00030__Create_AceOutpostContentSummaryPrototype.sql'
        $localInstance = [Environment]::GetEnvironmentVariable('ATAP_FLYWAY_DISPOSABLE_SQL_INSTANCE', 'Process')
        $localInstance | Should -Not -BeNullOrEmpty
        $config = "-configFiles=$(Join-Path $repoRoot 'Database\Flyway\flyway.toml')"
        $location = "-locations=filesystem:$sqlDirectory"
        $snapshotQuery = @"
SELECT CONCAT('TABLE|',s.name,'|',t.name) FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id WHERE s.name='ATAPUtilities'
UNION ALL SELECT CONCAT('COLUMN|',s.name,'|',t.name,'|',c.name,'|',ty.name,'|',c.max_length,'|',c.is_nullable) FROM sys.columns c JOIN sys.tables t ON t.object_id=c.object_id JOIN sys.schemas s ON s.schema_id=t.schema_id JOIN sys.types ty ON ty.user_type_id=c.user_type_id WHERE s.name='ATAPUtilities'
UNION ALL SELECT CONCAT('PK|',s.name,'|',t.name,'|',k.name) FROM sys.key_constraints k JOIN sys.tables t ON t.object_id=k.parent_object_id JOIN sys.schemas s ON s.schema_id=t.schema_id WHERE s.name='ATAPUtilities' AND k.type='PK'
UNION ALL SELECT CONCAT('CHECK|',s.name,'|',t.name,'|',cc.name,'|',cc.definition) FROM sys.check_constraints cc JOIN sys.tables t ON t.object_id=cc.parent_object_id JOIN sys.schemas s ON s.schema_id=t.schema_id WHERE s.name='ATAPUtilities'
ORDER BY 1;
"@
    }

    It 'migrates the V00010 predecessor to V00030 with only the ratified schema delta' -Skip:(-not $canRun) {
        $databaseName = "ATAPUtilities_Task15182F01_$([guid]::NewGuid().ToString('N'))"
        & sqlcmd -S $localInstance -E -b -Q "CREATE DATABASE [$databaseName];"; $LASTEXITCODE | Should -Be 0
        try {
            $jdbcUrl = "jdbc:sqlserver://$localInstance;databaseName=$databaseName;integratedSecurity=true;encrypt=true;trustServerCertificate=true"
            & flyway $config $location "-url=$jdbcUrl" '-target=10' migrate; $LASTEXITCODE | Should -Be 0
            & flyway $config $location "-url=$jdbcUrl" '-target=10' validate; $LASTEXITCODE | Should -Be 0
            $before = @(& sqlcmd -S $localInstance -E -d $databaseName -b -W -h -1 -Q $snapshotQuery | Where-Object { $_ -notmatch '^\(\d+ rows affected\)$' }); $LASTEXITCODE | Should -Be 0
            & flyway $config $location "-url=$jdbcUrl" migrate; $LASTEXITCODE | Should -Be 0
            & flyway $config $location "-url=$jdbcUrl" validate; $LASTEXITCODE | Should -Be 0
            & flyway $config $location "-url=$jdbcUrl" validate; $LASTEXITCODE | Should -Be 0
            $after = @(& sqlcmd -S $localInstance -E -d $databaseName -b -W -h -1 -Q $snapshotQuery | Where-Object { $_ -notmatch '^\(\d+ rows affected\)$' }); $LASTEXITCODE | Should -Be 0
            $delta = @(Compare-Object $before $after | Where-Object SideIndicator -eq '=>' | ForEach-Object InputObject)
            Write-Verbose ('Task15.182.F01 schema delta: ' + ($delta -join ' || '))
            $delta.Count | Should -Be 5
            $delta | Should -Contain 'TABLE|ATAPUtilities|AceOutpostContentSummaryPrototype'
            @($delta | Where-Object { $_ -match '^COLUMN\|ATAPUtilities\|AceOutpostContentSummaryPrototype\|' }).Count | Should -Be 2
            $delta | Should -Contain 'COLUMN|ATAPUtilities|AceOutpostContentSummaryPrototype|OperationId|uniqueidentifier|16|0'
            $delta | Should -Contain 'COLUMN|ATAPUtilities|AceOutpostContentSummaryPrototype|Payload|nvarchar|8000|0'
            @($delta | Where-Object { $_ -notmatch '^TABLE\|ATAPUtilities\|AceOutpostContentSummaryPrototype$|^COLUMN\|ATAPUtilities\|AceOutpostContentSummaryPrototype\|' -and $_ -notmatch '^PK\|ATAPUtilities\|AceOutpostContentSummaryPrototype\|PK_AceOutpostContentSummaryPrototype$' -and $_ -notmatch '^CHECK\|ATAPUtilities\|AceOutpostContentSummaryPrototype\|CK_AceOutpostContentSummaryPrototype_Payload\|' }).Count | Should -Be 0
            ($after | Where-Object { $_ -match '^PK\|ATAPUtilities\|AceOutpostContentSummaryPrototype\|PK_AceOutpostContentSummaryPrototype$' }).Count | Should -Be 1
            ($after | Where-Object { $_ -match '^CHECK\|ATAPUtilities\|AceOutpostContentSummaryPrototype\|CK_AceOutpostContentSummaryPrototype_Payload\|.*LEN\(\[Payload\]\).*4000' }).Count | Should -Be 1
            & sqlcmd -S $localInstance -E -d $databaseName -b -Q "IF NOT EXISTS (SELECT 1 FROM [dbo].[flyway_schema_history] WHERE [script]='V00030__Create_AceOutpostContentSummaryPrototype.sql') THROW 51032, 'Expected V00030 Flyway history row is missing.', 1;"; $LASTEXITCODE | Should -Be 0
        } finally { & sqlcmd -S $localInstance -E -d master -b -Q "ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName];" }
    }

    It 'rejects a conflicting target object after predecessor migration' -Skip:(-not $canRun) {
        $databaseName = "ATAPUtilities_Task15182F01_Conflict_$([guid]::NewGuid().ToString('N'))"
        & sqlcmd -S $localInstance -E -b -Q "CREATE DATABASE [$databaseName];"; $LASTEXITCODE | Should -Be 0
        try {
            $jdbcUrl = "jdbc:sqlserver://$localInstance;databaseName=$databaseName;integratedSecurity=true;encrypt=true;trustServerCertificate=true"
            & flyway $config $location "-url=$jdbcUrl" '-target=10' migrate; $LASTEXITCODE | Should -Be 0
            & sqlcmd -S $localInstance -E -d $databaseName -b -Q 'CREATE TABLE [ATAPUtilities].[AceOutpostContentSummaryPrototype] ([OperationId] int NOT NULL);'; $LASTEXITCODE | Should -Be 0
            $conflictOutput = & flyway $config $location "-url=$jdbcUrl" migrate 2>&1
            Write-Verbose ('Task15.182.F01 conflict head output: ' + ($conflictOutput | Out-String))
            $LASTEXITCODE | Should -Not -Be 0
            ($conflictOutput | Out-String) | Should -Match 'AceOutpostContentSummaryPrototype.*already exists'
        } finally { & sqlcmd -S $localInstance -E -d master -b -Q "ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseName];" }
    }
}







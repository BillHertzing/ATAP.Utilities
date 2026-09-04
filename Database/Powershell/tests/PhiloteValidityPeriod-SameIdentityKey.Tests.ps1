Set-StrictMode -Version Latest

Describe 'PhiloteValidityPeriod same-identity key migration static contract' {
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

    $t1Marker = [Environment]::GetEnvironmentVariable('ATAP_T1_DISPOSABLE_AUTHORIZATION', 'Process')
    $t1Instance = [Environment]::GetEnvironmentVariable('ATAP_T1_DISPOSABLE_SQL_INSTANCE', 'Process')
    $t1Created = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $t1Hashes = [ordered]@{
        'V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql' = '401313150D8DCD68E86FDE5E51A6B45D6A03F91389C43EAB5206F8F4115EF962'
        'V00030__Create_AceOutpostContentSummaryPrototype.sql' = '98C0018A4A92A1A8095CA329D93706A4B426016C1C42B69BC3F7CFB865B38179'
        'V00040__Add_PhiloteValidityPeriod_SameIdentity_Key.sql' = '85EB6D5FC4DCD72A59EA11186FE561FCECDBC912D64D42D7DE2A69B33AC76D14'
    }
    function Assert-T1Target {
        param([string] $Marker, [string] $Instance, [string] $Name)
        if ($Marker -cne 'AUTHORIZE_TASK_15_140_C_T1_DISPOSABLE') { throw 'T1 authorization marker required.' }
        $parts = $Instance.Split('\')
        if ($parts.Count -ne 2 -or $parts[0] -notin @('.', 'localhost', '127.0.0.1', [Environment]::MachineName) -or $parts[1] -ine 'ExpWhertzing') {
            throw 'Only local ExpWhertzing is permitted.'
        }
        if ($Name -cnotmatch '^ATAPUtilities_Task15140cT1_[0-9a-f]{32}$') { throw 'Unsafe T1 database name.' }
    }
    function Assert-T1MigrationBytes {
        param([string] $Directory)
        foreach ($name in $t1Hashes.Keys) {
            $text = [IO.File]::ReadAllText((Join-Path $Directory $name)).Replace(([string][char]13 + [char]10), [string][char]10).Replace([string][char]13, [string][char]10)
            $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text)))
            if ($hash -cne $t1Hashes[$name]) { throw "Immutable migration drift: $name" }
        }
    }
    $t1Sql = [ordered]@{
        Snapshot = 'SELECT (SELECT * FROM [ATAPUtilities].[PhiloteValidityPeriod] ORDER BY [PhiloteValidityPeriodId] FOR JSON PATH, INCLUDE_NULL_VALUES);'
        Constraints = @'
SELECT (SELECT o.name,o.type,i.is_unique,ic.key_ordinal,c.name AS ColumnName,
               ck.is_disabled AS CheckDisabled,ck.is_not_trusted AS CheckUntrusted,
               fk.is_disabled AS ForeignKeyDisabled,fk.is_not_trusted AS ForeignKeyUntrusted
FROM sys.objects o
LEFT JOIN sys.key_constraints k ON k.object_id=o.object_id
LEFT JOIN sys.indexes i ON i.object_id=k.parent_object_id AND i.index_id=k.unique_index_id
LEFT JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0
LEFT JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
LEFT JOIN sys.check_constraints ck ON ck.object_id=o.object_id
LEFT JOIN sys.foreign_keys fk ON fk.object_id=o.object_id
WHERE o.parent_object_id=OBJECT_ID(N'ATAPUtilities.PhiloteValidityPeriod')
  AND o.type IN ('PK','UQ','F','C')
  AND o.name<>N'UQ_PhiloteValidityPeriod_PhiloteId_PhiloteValidityPeriodId'
ORDER BY o.name,ic.key_ordinal FOR JSON PATH, INCLUDE_NULL_VALUES);
'@
        Verify = @'
IF (SELECT COUNT_BIG(*) FROM dbo.flyway_schema_history)<>3
 OR (SELECT COUNT_BIG(*) FROM dbo.flyway_schema_history WHERE success=1 AND TRY_CONVERT(int,version)=10)<>1
 OR (SELECT COUNT_BIG(*) FROM dbo.flyway_schema_history WHERE success=1 AND TRY_CONVERT(int,version)=30)<>1
 OR (SELECT COUNT_BIG(*) FROM dbo.flyway_schema_history WHERE success=1 AND TRY_CONVERT(int,version)=40)<>1
 THROW 51940,'Incorrect V40 history.',1;
DECLARE @Columns nvarchar(max);
SELECT @Columns=STRING_AGG(CONVERT(nvarchar(max),c.name),N',') WITHIN GROUP (ORDER BY ic.key_ordinal)
FROM sys.key_constraints k
JOIN sys.indexes i ON i.object_id=k.parent_object_id AND i.index_id=k.unique_index_id
JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0
JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
WHERE k.parent_object_id=OBJECT_ID(N'ATAPUtilities.PhiloteValidityPeriod')
 AND k.name=N'UQ_PhiloteValidityPeriod_PhiloteId_PhiloteValidityPeriodId'
 AND k.type='UQ' AND i.is_unique=1 AND i.is_disabled=0;
IF @Columns IS NULL OR @Columns<>N'PhiloteId,PhiloteValidityPeriodId'
 THROW 51941,'Incorrect same-identity key column order.',1;
'@
        Functional = @'
SET XACT_ABORT OFF;
DECLARE @Philote uniqueidentifier,@Period uniqueidentifier,@OtherPhilote uniqueidentifier;
SELECT TOP(1) @Philote=PhiloteId,@Period=PhiloteValidityPeriodId
FROM [ATAPUtilities].[PhiloteValidityPeriod] ORDER BY PhiloteValidityPeriodId;
SELECT TOP(1) @OtherPhilote=PhiloteId FROM [ATAPUtilities].[PhiloteValidityPeriod]
WHERE PhiloteId<>@Philote ORDER BY PhiloteValidityPeriodId;
IF @Philote IS NULL OR @OtherPhilote IS NULL THROW 51942,'Two distinct seeded identities required.',1;
CREATE TABLE [dbo].[Task15140cT1Reference] (
  [PhiloteId] uniqueidentifier NOT NULL,
  [PhiloteValidityPeriodId] uniqueidentifier NOT NULL,
  CONSTRAINT [FK_Task15140cT1Reference] FOREIGN KEY ([PhiloteId],[PhiloteValidityPeriodId])
    REFERENCES [ATAPUtilities].[PhiloteValidityPeriod] ([PhiloteId],[PhiloteValidityPeriodId])
);
INSERT INTO [dbo].[Task15140cT1Reference] VALUES (@Philote,@Period);
BEGIN TRY
  INSERT INTO [dbo].[Task15140cT1Reference] VALUES (@OtherPhilote,@Period);
  THROW 51943,'Mismatched identity was accepted.',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()<>547 THROW;
END CATCH;
IF (SELECT COUNT_BIG(*) FROM [dbo].[Task15140cT1Reference])<>1
 THROW 51944,'Rejected reference left a row.',1;
BEGIN TRY
  INSERT INTO [ATAPUtilities].[PhiloteValidityPeriod]
    ([PhiloteValidityPeriodId],[PhiloteId],[PreviousValidToUtc],[ValidFromUtc],[ValidToUtc])
  SELECT NEWID(),PhiloteId,PreviousValidToUtc,ValidFromUtc,ValidToUtc
  FROM [ATAPUtilities].[PhiloteValidityPeriod] WHERE PhiloteValidityPeriodId=@Period;
  THROW 51945,'Duplicate interval was accepted.',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER() NOT IN (2601,2627) THROW;
END CATCH;
BEGIN TRY
  UPDATE [ATAPUtilities].[PhiloteValidityPeriod] SET ValidToUtc=ValidFromUtc
  WHERE PhiloteValidityPeriodId=@Period;
  THROW 51946,'Empty interval was accepted.',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()<>547 THROW;
END CATCH;
'@
    }
    function Invoke-T1Sql {
        param([string] $Name, [string] $Query, [switch] $Master)
        Assert-T1Target $t1Marker $t1Instance $Name
        if (-not $Master -and -not $t1Created.Contains($Name)) { throw 'Unowned T1 database.' }
        $database = if ($Master) { 'master' } else { $Name }
        $output = & sqlcmd -S $t1Instance -E -d $database -b -h -1 -y 0 -Q "SET NOCOUNT ON; $Query" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "T1 SQL failed: $($output -join [Environment]::NewLine)" }
        $output -join [Environment]::NewLine
    }
    function Invoke-T1Flyway {
        param([string] $Name, [string] $Location, [ValidateSet('30','40')][string] $Target, [ValidateSet('migrate','validate')][string] $Command)
        Assert-T1Target $t1Marker $t1Instance $Name
        if (-not $t1Created.Contains($Name)) { throw 'Unowned T1 database.' }
        Assert-T1MigrationBytes $Location
        $url = "jdbc:sqlserver://$t1Instance;databaseName=$Name;integratedSecurity=true;encrypt=true;trustServerCertificate=true"
        $output = & flyway "-configFiles=$repoRoot/Database/Flyway/flyway.toml" "-locations=filesystem:$Location" "-url=$url" "-target=$Target" '-cleanDisabled=true' '-baselineOnMigrate=false' '-outOfOrder=false' '-validateOnMigrate=true' $Command 2>&1
        if ($LASTEXITCODE -ne 0) { throw "T1 Flyway failed: $($output -join [Environment]::NewLine)" }
    }
    function Invoke-T1Fixture {
        param([switch] $Upgrade)
        $name = 'ATAPUtilities_Task15140cT1_' + [guid]::NewGuid().ToString('N')
        Assert-T1Target $t1Marker $t1Instance $name
        Assert-T1MigrationBytes $sqlDirectory
        $null = Get-Command sqlcmd -ErrorAction Stop
        $null = Get-Command flyway -ErrorAction Stop
        $location = Join-Path $repoRoot "_generated/Sprint0015/Task15.140/c/T1/completion-20260903/worker/fixtures/$name"
        $null = New-Item -ItemType Directory -Path $location -ErrorAction Stop
        foreach ($migrationFile in $t1Hashes.Keys) {
            Copy-Item -LiteralPath (Join-Path $sqlDirectory $migrationFile) -Destination $location -ErrorAction Stop
        }
        try {
            $null = Invoke-T1Sql $name "CREATE DATABASE [$name];" -Master
            $null = $t1Created.Add($name)
            if ($Upgrade) {
                Invoke-T1Flyway $name $location 30 migrate
                $before = Invoke-T1Sql $name $t1Sql.Snapshot
                $constraintsBefore = Invoke-T1Sql $name $t1Sql.Constraints
            }
            Invoke-T1Flyway $name $location 40 migrate
            Invoke-T1Flyway $name $location 40 validate
            if ($Upgrade) {
                (Invoke-T1Sql $name $t1Sql.Snapshot) | Should -BeExactly $before
                (Invoke-T1Sql $name $t1Sql.Constraints) | Should -BeExactly $constraintsBefore
            }
            $null = Invoke-T1Sql $name $t1Sql.Verify
            $beforeNegative = Invoke-T1Sql $name $t1Sql.Snapshot
            $null = Invoke-T1Sql $name $t1Sql.Functional
            (Invoke-T1Sql $name $t1Sql.Snapshot) | Should -BeExactly $beforeNegative
        }
        finally {
            if ($t1Created.Contains($name)) {
                $null = Invoke-T1Sql $name "ALTER DATABASE [$name] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$name];" -Master
                $null = $t1Created.Remove($name)
            }
            # Retain staged immutable bytes under _generated; no filesystem cleanup.
        }
    }
}

Describe 'T1 offline fixture guards and SQL syntax' {
    It 'pins the immutable V00010/V00030/V00040 logical content' {
        { Assert-T1MigrationBytes $sqlDirectory } | Should -Not -Throw
    }
    It 'fails closed for foreign instances, unrelated names and missing authorization' {
        $name = 'ATAPUtilities_Task15140cT1_' + [guid]::NewGuid().ToString('N')
        $marker = 'AUTHORIZE_TASK_15_140_C_T1_DISPOSABLE'
        { Assert-T1Target $marker '.\ExpWhertzing' $name } | Should -Not -Throw
        foreach ($bad in @('', 'true', 'AUTHORIZE_TASK_15_140_C_T0_DISPOSABLE')) {
            { Assert-T1Target $bad '.\ExpWhertzing' $name } | Should -Throw '*marker required*'
        }
        foreach ($bad in @('remote\ExpWhertzing', '.\Production', 'localhost', '.\ExpWhertzing;other')) {
            { Assert-T1Target $marker $bad $name } | Should -Throw '*local ExpWhertzing*'
        }
        foreach ($bad in @('ATAPUtilities', 'ATAPUtilities_Task15140cT1_existing', "$name];DROP DATABASE other")) {
            { Assert-T1Target $marker '.\ExpWhertzing' $bad } | Should -Throw '*Unsafe T1*'
        }
    }
    It 'parses every fixture SQL body and database lifecycle template offline' {
        $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
        $tokens = $null
        $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($PSCommandPath, [ref]$tokens, [ref]$errors)
        $queries = @($t1Sql.Values) + @($ast.FindAll({
            param($node)
            $node -is [Management.Automation.Language.ExpandableStringExpressionAst] -and
            $node.Value -match '^(CREATE DATABASE|ALTER DATABASE)'
        }, $true) | ForEach-Object { $_.Value.Replace('$name', 'ATAPUtilities_Task15140cT1_00000000000000000000000000000000') })
        $queries.Count | Should -Be 6
        foreach ($query in $queries) {
            $reader = [IO.StringReader]::new($query)
            $sqlErrors = [Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
            try { $null = $parser.Parse($reader, [ref]$sqlErrors) }
            finally { $reader.Dispose() }
            @($sqlErrors | ForEach-Object { $_.Message }) | Should -BeNullOrEmpty
        }
    }
}

Describe 'PhiloteValidityPeriod same-identity key disposable-database gates' {
    # Nonempty invalid opt-in fails at preflight; the default makes no native calls.
    $requested = -not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable('ATAP_T1_DISPOSABLE_AUTHORIZATION', 'Process'))
    It 'applies fresh and rejects mismatched references without changing seeded periods' -Skip:(-not $requested) {
        Invoke-T1Fixture
    }
    It 'upgrades V00030 preserving all period rows and original constraints' -Skip:(-not $requested) {
        Invoke-T1Fixture -Upgrade
    }
}

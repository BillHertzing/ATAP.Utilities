#Requires -Version 7.0
#Requires -Module Pester

Describe 'V00150 Ace AISupervisor CacheTokens static contract' {
  BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $migrationPath = Join-Path $repoRoot 'Database\Flyway\SQL\V00150__Add_AISupervisor_CacheTokens.sql'
    $migration = Get-Content -LiteralPath $migrationPath -Raw
    $version = Get-Content -LiteralPath (Join-Path $repoRoot 'Database\Flyway\version.json') -Raw | ConvertFrom-Json
    $allowlist = Get-Content -LiteralPath (Join-Path $repoRoot 'Database\Flyway\package-content-allowlist.json') -Raw | ConvertFrom-Json
  }

  It 'uses the unique next migration version without editing V00070' {
    $active = @(Get-ChildItem -LiteralPath (Split-Path $migrationPath) -File -Filter 'V*.sql' | Sort-Object Name)
    @($active.Name | Where-Object { $_ -match '^V00150__' }) | Should -Be @('V00150__Add_AISupervisor_CacheTokens.sql')
    @($active.Name | Where-Object { $_ -match '^V00150__' }).Count | Should -Be 1
    (Get-FileHash -LiteralPath (Join-Path (Split-Path $migrationPath) 'V00070__Create_Ace_AISupervisor_Telemetry.sql') -Algorithm SHA256).Hash |
      Should -BeExactly '501B2C9486C81C706C7C07BB8912053FBE91A5559865C43B57527DDB7E5453C8'
  }

  It 'adds one nullable non-negative CacheTokens column transactionally' {
    $migration | Should -Match 'SET XACT_ABORT ON'
    $migration | Should -Match 'BEGIN TRANSACTION'
    $migration | Should -Match 'ADD \[CacheTokens\] bigint NULL'
    $migration | Should -Match '\[CacheTokens\] IS NULL OR \[CacheTokens\] >= 0'
    $migration | Should -Match 'COL_LENGTH\(N''Ace\.AISupervisorUsage'', N''CacheTokens''\)'
    $migration | Should -Not -Match '(?im)^\s*UPDATE\s+\[Ace\]\.\[AISupervisorUsage\]'
  }

  It 'keeps old capture callers compatible and writes CacheTokens with the other counts' {
    $migration | Should -Match '@Metrics \[Ace\]\.\[AISupervisorMetricInput\] READONLY,'' \+ NCHAR\(13\) \+ NCHAR\(10\)\s*\+ N''    @CacheTokens bigint = NULL'''
    $migration | Should -Not -Match "@CaptureParameterAnchor \+ NCHAR\(13\) \+ NCHAR\(10\) \+ N'    @CacheTokens"
    $migration | Should -Match '@CacheTokens IS NOT NULL AND @CacheTokens < 0'
    $migration | Should -Match '\[RequestTokens\], \[ResponseTokens\], \[CacheTokens\], \[AvailabilityCode\]'
    $migration | Should -Match '@RequestTokens, @ResponseTokens, @CacheTokens, @AvailabilityCode'
  }

  It 'does not redefine request-response availability around the optional cache count' {
    $migration | Should -Not -Match '@AvailabilityCode = N''''Complete''''[^\r\n]+@CacheTokens'
    $migration | Should -Not -Match '@AvailabilityCode = N''''Missing''''[^\r\n]+@CacheTokens'
  }

  It 'exposes CacheTokens through exchange and aggregate timeline queries' {
    $migration | Should -Match 'usage\.\[ResponseTokens\], usage\.\[CacheTokens\], usage\.\[AvailabilityCode\]'
    $migration | Should -Match 'SUM\(\[CacheTokens\]\) AS \[CacheTokens\]'
  }

  It 'binds package version 0.1.15 to the exact V00150 bytes' {
    $version.version | Should -BeExactly '0.1.15'
    $allowlist.sourceVersion | Should -BeExactly '0.1.15'
    $entry = @($allowlist.files | Where-Object path -EQ 'SQL/V00150__Add_AISupervisor_CacheTokens.sql')
    $entry.Count | Should -Be 1
    $entry[0].kind | Should -BeExactly 'migration'
    $entry[0].sha256 | Should -BeExactly (Get-FileHash -LiteralPath $migrationPath -Algorithm SHA256).Hash
  }

  It 'fails closed when predecessor procedure definitions do not match exact anchors' {
    foreach ($errorNumber in 60600..60606) {
      $migration | Should -Match "THROW $errorNumber,"
    }
    $migration | Should -Match 'does not match the V00070 contract'
    $migration | Should -Match 'V00150 postcondition verification failed'
  }
}

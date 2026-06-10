#Requires -Version 7.0
#Requires -Modules Pester, PSFramework

<#
.SYNOPSIS
    Pester tests for DBA1-T04 Flyway safety gate cmdlets.

.DESCRIPTION
    Covers:
      - Get-FlywaySchemaVersion  : mock SqlConnection returns expected shape
      - Test-FlywayMigrationSafety : no destructive migrations → IsSafe = $true
      - Test-FlywayMigrationSafety : ColumnDrop + no evidence → IsSafe = $false
      - Test-FlywayMigrationSafety : ColumnDrop + evidence present → IsSafe = $true
      - Invoke-DatabasePackageRehearsal : WhatIf does not call Invoke-FlywayRehearsal
      - Test-DatabaseSeedIdempotency : no seed files in manifest → IsIdempotent = $true

    Live database connections are not required; all SQL calls are mocked.
    Task: TASKS_V4-DBA1.md DBA1-T04 / V4-E07.
#>

Describe 'Get-FlywaySchemaVersion' {

  BeforeAll {
    # Build a minimal mock SqlConnection that returns 3 fake schema history rows
    $mockReader = [PSCustomObject]@{
      _rows  = @(
        @{ InstalledRank = 3; Version = '1.3'; Description = 'AddIndex'; Type = 'SQL'; Script = 'V1.3__AddIndex.sql'; Checksum = 12345; InstalledBy = 'dbo'; InstalledOn = [datetime]'2026-01-03'; ExecutionTime = 45; Success = $true },
        @{ InstalledRank = 2; Version = '1.2'; Description = 'AddTable'; Type = 'SQL'; Script = 'V1.2__AddTable.sql'; Checksum = 67890; InstalledBy = 'dbo'; InstalledOn = [datetime]'2026-01-02'; ExecutionTime = 120; Success = $true },
        @{ InstalledRank = 1; Version = '1.1'; Description = 'Init'; Type = 'SQL'; Script = 'V1.1__Init.sql'; Checksum = 11111; InstalledBy = 'dbo'; InstalledOn = [datetime]'2026-01-01'; ExecutionTime = 200; Success = $true }
      )
      _index = -1
    }
    Add-Member -InputObject $mockReader -MemberType ScriptMethod -Name 'Read' -Value {
      $this._index++
      return $this._index -lt $this._rows.Count
    }
    Add-Member -InputObject $mockReader -MemberType ScriptMethod -Name 'get_FieldCount' -Value { return 10 }
    Add-Member -InputObject $mockReader -MemberType ScriptMethod -Name 'GetValue' -Value {
      param([int]$i) $null   # not used in current impl; uses named indexer
    }
    Add-Member -InputObject $mockReader -MemberType ScriptMethod -Name 'Dispose' -Value {}
    Add-Member -InputObject $mockReader -MemberType ScriptProperty -Name 'Item' -Value {
      param([string]$name)
      $this._rows[$this._index][$name]
    }

    $mockCmd = [PSCustomObject]@{ CommandText = '' }
    Add-Member -InputObject $mockCmd -MemberType ScriptMethod -Name 'ExecuteReader' -Value { return $mockReader }
    Add-Member -InputObject $mockCmd -MemberType ScriptMethod -Name 'Dispose' -Value {}

    $script:mockSqlConnection = [PSCustomObject]@{}
    Add-Member -InputObject $script:mockSqlConnection -MemberType ScriptMethod -Name 'CreateCommand' -Value { return $mockCmd }

    # Stub Resolve-DatabaseSqlConnection to return the mock connection
    Mock -CommandName 'Resolve-DatabaseSqlConnection' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' `
      -MockWith { return $script:mockSqlConnection }
  }

  It 'Returns 3 rows with expected shape when querying schema history' {
    $rows = Get-FlywaySchemaVersion -SqlConnection $script:mockSqlConnection
    $rows | Should -HaveCount 3
    $rows[0].InstalledRank | Should -Be 3
    $rows[0].Version | Should -Be '1.3'
    $rows[0].Success | Should -BeTrue
    $rows[2].InstalledRank | Should -Be 1
  }
}

Describe 'Test-FlywayMigrationSafety' {

  BeforeAll {
    # Helper: build a temp package folder with a manifest
    function New-TempSafetyPackage {
      param([hashtable[]]$Migrations, [string[]]$EvidenceFiles = @())
      $dir = Join-Path $TestDrive "safety-pkg-$([Guid]::NewGuid().ToString('N'))"
      New-Item $dir -ItemType Directory -Force | Out-Null
      $manifest = @{
        schemaVersion                      = 2
        dbChangeUnit                       = 'TestApp.Database.1.0.0'
        appVersion                         = '1.0.0'
        changeKind                         = 'schema'
        flywayTargetVersion                = '1.0'
        createdUtc                         = '2026-01-01T00:00:00Z'
        createdFromGitTag                  = 'v1.0.0'
        createdFromGitSha                  = 'abc123'
        files                              = @()
        expectedRowCounts                  = @{}
        compatibleAppPackageRanges         = @()
        requiresPreviousProductionSnapshot = $false
        rollbackSupported                  = $false
        rollbackNotes                      = ''
        evidenceRequirements               = @()
        migrations                         = $Migrations
      }
      $manifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $dir 'db-release-unit-manifest.json')
      foreach ($ef in $EvidenceFiles) {
        Set-Content -Path (Join-Path $dir $ef) -Value '{"approved":true}'
      }
      return $dir
    }
  }

  It 'Returns IsSafe = $true when no destructive migrations are present' {
    $migrations = @(
      @{ script = 'V1.1__AddColumn.sql'; destructiveChangeKind = 'None' }
      @{ script = 'V1.2__AddIndex.sql'; destructiveChangeKind = '' }
    )
    $dir = New-TempSafetyPackage -Migrations $migrations
    $result = Test-FlywayMigrationSafety -PackagePath $dir
    $result.IsSafe | Should -BeTrue
    $result.DestructiveMigrations | Should -HaveCount 0
    $result.MissingEvidence | Should -HaveCount 0
  }

  It 'Returns IsSafe = $false when ColumnDrop migration has no evidence file' {
    $migrations = @(
      @{ script = 'V2.1__DropObsoleteColumn.sql'; destructiveChangeKind = 'ColumnDrop' }
    )
    $dir = New-TempSafetyPackage -Migrations $migrations
    $result = Test-FlywayMigrationSafety -PackagePath $dir
    $result.IsSafe | Should -BeFalse
    $result.DestructiveMigrations | Should -Contain 'V2.1__DropObsoleteColumn.sql'
    $result.MissingEvidence | Should -Contain 'V2.1__DropObsoleteColumn.sql'
  }

  It 'Returns IsSafe = $true when ColumnDrop migration has a sibling evidence file' {
    $migrations = @(
      @{ script = 'V2.1__DropObsoleteColumn.sql'; destructiveChangeKind = 'ColumnDrop' }
    )
    $evidenceFiles = @('V2.1__DropObsoleteColumn.evidence.json')
    $dir = New-TempSafetyPackage -Migrations $migrations -EvidenceFiles $evidenceFiles
    $result = Test-FlywayMigrationSafety -PackagePath $dir
    $result.IsSafe | Should -BeTrue
    $result.DestructiveMigrations | Should -HaveCount 1   # still flagged as destructive
    $result.MissingEvidence | Should -HaveCount 0   # but evidence is present
  }

  It 'Flags TableDrop and DataLoss migrations independently' {
    $migrations = @(
      @{ script = 'V3.1__DropOldTable.sql'; destructiveChangeKind = 'TableDrop' }
      @{ script = 'V3.2__ClearLogs.sql'; destructiveChangeKind = 'DataLoss' }
    )
    # Provide evidence only for V3.1
    $evidenceFiles = @('V3.1__DropOldTable.evidence.json')
    $dir = New-TempSafetyPackage -Migrations $migrations -EvidenceFiles $evidenceFiles
    $result = Test-FlywayMigrationSafety -PackagePath $dir
    $result.IsSafe | Should -BeFalse
    $result.DestructiveMigrations | Should -HaveCount 2
    $result.MissingEvidence | Should -HaveCount 1
    $result.MissingEvidence | Should -Contain 'V3.2__ClearLogs.sql'
  }
}

Describe 'Invoke-DatabasePackageRehearsal' {

  It 'Does not call Invoke-FlywayRehearsal when -WhatIf is specified' {
    $dir = Join-Path $TestDrive 'rehearsal-pkg'
    New-Item $dir -ItemType Directory -Force | Out-Null
    $manifest = @{
      schemaVersion                      = 2
      dbChangeUnit                       = 'TestApp.Database.1.0.0'
      appVersion                         = '1.0.0'
      changeKind                         = 'schema'
      flywayTargetVersion                = '1.0'
      createdUtc                         = '2026-01-01T00:00:00Z'
      createdFromGitTag                  = 'v1.0.0'
      createdFromGitSha                  = 'abc123'
      files                              = @()
      expectedRowCounts                  = @{}
      compatibleAppPackageRanges         = @()
      requiresPreviousProductionSnapshot = $false
      rollbackSupported                  = $false
      rollbackNotes                      = ''
      evidenceRequirements               = @()
    }
    $manifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $dir 'db-release-unit-manifest.json')

    Mock -CommandName 'Invoke-FlywayRehearsal' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' `
      -MockWith { throw 'Should not be called with -WhatIf' }

    { Invoke-DatabasePackageRehearsal -PackagePath $dir -WhatIf } | Should -Not -Throw
    Should -Invoke 'Invoke-FlywayRehearsal' -Exactly 0 -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell'
  }
}

Describe 'Test-DatabaseSeedIdempotency' {

  It 'Returns IsIdempotent = $true when manifest has no seeds or loaders' {
    $dir = Join-Path $TestDrive 'idempotent-pkg'
    New-Item $dir -ItemType Directory -Force | Out-Null
    $manifest = @{
      schemaVersion                      = 2
      dbChangeUnit                       = 'TestApp.Database.1.0.0'
      appVersion                         = '1.0.0'
      changeKind                         = 'data'
      flywayTargetVersion                = '1.0'
      createdUtc                         = '2026-01-01T00:00:00Z'
      createdFromGitTag                  = 'v1.0.0'
      createdFromGitSha                  = 'abc123'
      files                              = @()
      expectedRowCounts                  = @{}
      compatibleAppPackageRanges         = @()
      requiresPreviousProductionSnapshot = $false
      rollbackSupported                  = $false
      rollbackNotes                      = ''
      evidenceRequirements               = @()
    }
    $manifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $dir 'db-release-unit-manifest.json')

    $mockConn = [PSCustomObject]@{}
    Mock -CommandName 'Resolve-DatabaseSqlConnection' -ModuleName 'ATAP.Utilities.DatabaseManagement.Powershell' `
      -MockWith { return $mockConn }

    $result = Test-DatabaseSeedIdempotency -PackagePath $dir `
      -SqlConnection $mockConn -DatabaseName 'TestDB'
    $result.IsIdempotent | Should -BeTrue
    $result.Mismatches | Should -HaveCount 0
  }
}

#Requires -Version 7.0
#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

param([string]$ScriptDomAssemblyPath)

# Static migration/package-source verification only. No SQL engine or provider is loaded.
Describe 'Forward organization migration source package' {
  BeforeAll {
    $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $sqlRoot = Join-Path $repositoryRoot 'Database/Flyway/SQL'
    $componentRoot = Join-Path $repositoryRoot 'Database/Schema/ACE'
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

  It 'preserves every accepted component body including transaction and Guest/shared-identity protections' {
    foreach ($migration in $migrations) {
      $actual = [IO.File]::ReadAllText((Join-Path $sqlRoot $migration.File))
      $source = [IO.File]::ReadAllText((Join-Path $componentRoot $migration.Source))
      [regex]::Replace($actual, '\A/\*[\s\S]*?\*/', '') |
        Should -BeExactly ([regex]::Replace($source, '\A/\*[\s\S]*?\*/', ''))
    }
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

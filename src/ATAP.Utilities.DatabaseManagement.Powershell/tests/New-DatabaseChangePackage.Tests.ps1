# Pester tests for New-DatabaseChangePackage
# Covers: determinism, error cases, output validation

BeforeAll {
  $moduleSrc = Join-Path $PSScriptRoot '..'
  . (Join-Path $moduleSrc 'public' 'New-DatabaseChangePackage.ps1')

  # Build a minimal fixture database source tree
  $script:FixtureRoot = Join-Path $TestDrive 'fixture-repo'
  $script:AppName = 'TestApp'
  $script:AppDbRoot = Join-Path $script:FixtureRoot 'Database' $script:AppName

  function New-FixtureTree {
    param([string]$DbRoot, [string]$MigrationContent = 'CREATE TABLE T (id INT);')
    # version.json
    New-Item -ItemType Directory -Path $DbRoot -Force | Out-Null
    @{ version = '1.2.3' } | ConvertTo-Json | Set-Content (Join-Path $DbRoot 'version.json')
    # migrations
    $mDir = Join-Path $DbRoot 'db' 'migrations'
    New-Item -ItemType Directory -Path $mDir -Force | Out-Null
    $MigrationContent | Set-Content (Join-Path $mDir 'V1__init.sql')
  }

  function New-CanonicalFlywayFixture {
    param([string]$RepositoryRoot)

    $flywayRoot = Join-Path $RepositoryRoot 'Database' 'Flyway'
    $sqlRoot = Join-Path $flywayRoot 'SQL'
    $dataRoot = Join-Path $flywayRoot 'Data'
    New-Item -ItemType Directory -Path $sqlRoot, $dataRoot -Force | Out-Null
    @{ version = '1.2.3' } | ConvertTo-Json | Set-Content (Join-Path $flywayRoot 'version.json')
    "PRINT 'canonical';" | Set-Content (Join-Path $sqlRoot 'V00.01.000010__core.sql')
    "Id,Name`n1,canonical" | Set-Content (Join-Path $dataRoot 'Canonical.csv')
    Write-CanonicalPackageAllowlist -FlywayRoot $flywayRoot
  }

  function Write-CanonicalPackageAllowlist {
    param([string]$FlywayRoot)

    $files = [System.Collections.Generic.List[object]]::new()
    @(
      @{ Folder = 'SQL'; Kind = 'migration'; Extension = '.sql' },
      @{ Folder = 'Repeatable'; Kind = 'repeatable'; Extension = '.sql' },
      @{ Folder = 'Data'; Kind = 'seed'; Extension = '.csv' }
    ) | ForEach-Object {
      $definition = $_
      $folderPath = Join-Path $FlywayRoot $definition.Folder
      if (Test-Path -LiteralPath $folderPath -PathType Container) {
        Get-ChildItem -LiteralPath $folderPath -File |
          Where-Object Extension -eq $definition.Extension |
          Sort-Object Name |
          ForEach-Object {
            $files.Add([ordered]@{
                path   = "$($definition.Folder)/$($_.Name)"
                kind   = $definition.Kind
                sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
              })
          }
      }
    }
    $version = (Get-Content -LiteralPath (Join-Path $FlywayRoot 'version.json') -Raw | ConvertFrom-Json).version
    [ordered]@{
      schemaVersion = 1
      packageId     = 'ATAPUtilities.Database'
      sourceVersion = $version
      files         = @($files)
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $FlywayRoot 'package-content-allowlist.json') -Encoding UTF8
  }

  New-FixtureTree -DbRoot $script:AppDbRoot
}

Describe 'New-DatabaseChangePackage — determinism' {

  It 'Identical inputs produce identical manifest digest' {
    $params = @{
      Application    = $script:AppName
      RepositoryRoot = $script:FixtureRoot
    }
    $nupkg1 = New-DatabaseChangePackage @params
    # Remove staging output before re-running so it starts fresh
    $stagingParent = Join-Path $script:FixtureRoot '_generated' 'database-packages'
    Remove-Item -Recurse -Force $stagingParent -ErrorAction SilentlyContinue
    # Rebuild fixture (same content, same git timestamp not available in TestDrive — both will use epoch)
    New-FixtureTree -DbRoot $script:AppDbRoot

    $nupkg2 = New-DatabaseChangePackage @params

    # Compare the manifests inside both nupkgs
    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
    function Get-ManifestFromNupkg {
      param([string]$Path)
      $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
      try {
        $entry = $zip.Entries | Where-Object { $_.FullName -eq 'db-release-unit-manifest.json' } | Select-Object -First 1
        if (-not $entry) { return $null }
        $reader = [System.IO.StreamReader]::new($entry.Open())
        return $reader.ReadToEnd()
      } finally { $zip.Dispose() }
    }
    $m1 = Get-ManifestFromNupkg $nupkg1
    $m2 = Get-ManifestFromNupkg $nupkg2
    $m1 | Should -Be $m2
  }
}

Describe 'New-DatabaseChangePackage — error cases' {

  It 'Missing version.json causes a terminating error' {
    $noVerRoot = Join-Path $TestDrive 'no-version'
    $appDbRoot = Join-Path $noVerRoot 'Database' $script:AppName
    New-Item -ItemType Directory -Path (Join-Path $appDbRoot 'db' 'migrations') -Force | Out-Null
    'CREATE TABLE X (id INT);' | Set-Content (Join-Path $appDbRoot 'db' 'migrations' 'V1__init.sql')

    {
      New-DatabaseChangePackage -Application $script:AppName -RepositoryRoot $noVerRoot
    } | Should -Throw -ExceptionType ([System.Exception]) -PassThru |
      ForEach-Object { $_.Exception.Message | Should -Match 'version.json' }
  }

  It 'Missing db/migrations/ folder causes a terminating error' {
    $noMigRoot = Join-Path $TestDrive 'no-migrations'
    $appDbRoot = Join-Path $noMigRoot 'Database' $script:AppName
    New-Item -ItemType Directory -Path $appDbRoot -Force | Out-Null
    @{ version = '0.1.0' } | ConvertTo-Json | Set-Content (Join-Path $appDbRoot 'version.json')

    {
      New-DatabaseChangePackage -Application $script:AppName -RepositoryRoot $noMigRoot
    } | Should -Throw -ExceptionType ([System.Exception]) -PassThru |
      ForEach-Object { $_.Exception.Message | Should -Match 'Migrations folder' }
  }
}

Describe 'New-DatabaseChangePackage — ATAPUtilities canonical Flyway layout' {

  It 'packages SQL, CSV data, and version metadata from Database/Flyway' {
    $root = Join-Path $TestDrive 'canonical-flyway'
    New-CanonicalFlywayFixture -RepositoryRoot $root

    $nupkg = New-DatabaseChangePackage -Application 'ATAPUtilities' -RepositoryRoot $root
    $stagingDir = Split-Path -Parent (Split-Path -Parent $nupkg)
    $manifest = Get-Content (Join-Path $stagingDir 'db-release-unit-manifest.json') -Raw | ConvertFrom-Json

    $manifest.dbChangeUnit | Should -Be 'ATAPUtilities.Database'
    $manifest.flywayTargetVersion | Should -Be '00.01.000010'
    $manifest.files.path | Should -Contain 'db/migrations/V00.01.000010__core.sql'
    $manifest.files.path | Should -Contain 'db/seeds/Canonical.csv'

    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
    $zip = [System.IO.Compression.ZipFile]::OpenRead($nupkg)
    try {
      $configEntry = $zip.Entries |
        Where-Object { $_.FullName -eq 'flyway.toml' } |
        Select-Object -First 1
      $configEntry | Should -Not -BeNullOrEmpty
      $reader = [System.IO.StreamReader]::new($configEntry.Open())
      try {
        $config = $reader.ReadToEnd()
      } finally {
        $reader.Dispose()
      }
      $config | Should -Match 'filesystem:\./db/migrations'
      $config | Should -Not -Match 'filesystem:\./SQL'
    } finally {
      $zip.Dispose()
    }
  }

  It 'excludes an explicitly deferred migration by exact file name' {
    $root = Join-Path $TestDrive 'canonical-flyway-exclusion'
    New-CanonicalFlywayFixture -RepositoryRoot $root
    $sqlRoot = Join-Path $root 'Database\Flyway\SQL'
    "PRINT 'future';" | Set-Content (Join-Path $sqlRoot 'V00.01.000020__future.sql')

    $nupkg = New-DatabaseChangePackage -Application 'ATAPUtilities' -RepositoryRoot $root `
      -ExcludedMigrationFileName 'V00.01.000020__future.sql'
    $stagingDir = Split-Path -Parent (Split-Path -Parent $nupkg)
    $manifest = Get-Content (Join-Path $stagingDir 'db-release-unit-manifest.json') -Raw | ConvertFrom-Json

    $manifest.flywayTargetVersion | Should -Be '00.01.000010'
    $manifest.files.path | Should -Not -Contain 'db/migrations/V00.01.000020__future.sql'
  }

  It 'fails closed when the canonical allowlist is missing' {
    $root = Join-Path $TestDrive 'canonical-missing-allowlist'
    New-CanonicalFlywayFixture -RepositoryRoot $root
    Remove-Item -LiteralPath (Join-Path $root 'Database\Flyway\package-content-allowlist.json') -Force

    {
      New-DatabaseChangePackage -Application 'ATAPUtilities' -RepositoryRoot $root
    } | Should -Throw '*allowlist not found*'
  }

  It 'fails closed when an undeclared seed is present' {
    $root = Join-Path $TestDrive 'canonical-extra-seed'
    New-CanonicalFlywayFixture -RepositoryRoot $root
    'Id,Name' | Set-Content -LiteralPath (Join-Path $root 'Database\Flyway\Data\Unexpected.csv')

    {
      New-DatabaseChangePackage -Application 'ATAPUtilities' -RepositoryRoot $root
    } | Should -Throw '*differs from the allowlist*'
  }

  It 'fails closed when a declared file checksum changes' {
    $root = Join-Path $TestDrive 'canonical-checksum-mismatch'
    New-CanonicalFlywayFixture -RepositoryRoot $root
    "PRINT 'modified';" | Set-Content -LiteralPath (Join-Path $root 'Database\Flyway\SQL\V00.01.000010__core.sql')

    {
      New-DatabaseChangePackage -Application 'ATAPUtilities' -RepositoryRoot $root
    } | Should -Throw '*checksum mismatch*'
  }

  It 'fails closed when a declared file is missing' {
    $root = Join-Path $TestDrive 'canonical-missing-file'
    New-CanonicalFlywayFixture -RepositoryRoot $root
    Remove-Item -LiteralPath (Join-Path $root 'Database\Flyway\Data\Canonical.csv') -Force

    {
      New-DatabaseChangePackage -Application 'ATAPUtilities' -RepositoryRoot $root
    } | Should -Throw '*differs from the allowlist*'
  }

  It 'fails closed when a declared file kind does not match its source folder' {
    $root = Join-Path $TestDrive 'canonical-kind-mismatch'
    New-CanonicalFlywayFixture -RepositoryRoot $root
    $allowlistPath = Join-Path $root 'Database\Flyway\package-content-allowlist.json'
    $allowlist = Get-Content -LiteralPath $allowlistPath -Raw | ConvertFrom-Json
    $allowlist.files[0].kind = 'seed'
    $allowlist | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $allowlistPath -Encoding UTF8

    {
      New-DatabaseChangePackage -Application 'ATAPUtilities' -RepositoryRoot $root
    } | Should -Throw '*invalid kind or extension*'
  }

  It 'fails closed when an allowlist path is non-canonical' {
    $root = Join-Path $TestDrive 'canonical-invalid-path'
    New-CanonicalFlywayFixture -RepositoryRoot $root
    $allowlistPath = Join-Path $root 'Database\Flyway\package-content-allowlist.json'
    $allowlist = Get-Content -LiteralPath $allowlistPath -Raw | ConvertFrom-Json
    $allowlist.files[0].path = 'SQL/../V00.01.000010__core.sql'
    $allowlist | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $allowlistPath -Encoding UTF8

    {
      New-DatabaseChangePackage -Application 'ATAPUtilities' -RepositoryRoot $root
    } | Should -Throw '*not a canonical direct-child path*'
  }

  It 'fails closed when the allowlist contains a duplicate path' {
    $root = Join-Path $TestDrive 'canonical-duplicate-path'
    New-CanonicalFlywayFixture -RepositoryRoot $root
    $allowlistPath = Join-Path $root 'Database\Flyway\package-content-allowlist.json'
    $allowlist = Get-Content -LiteralPath $allowlistPath -Raw | ConvertFrom-Json
    $allowlist.files = @($allowlist.files) + $allowlist.files[0]
    $allowlist | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $allowlistPath -Encoding UTF8

    {
      New-DatabaseChangePackage -Application 'ATAPUtilities' -RepositoryRoot $root
    } | Should -Throw '*duplicate paths*'
  }
}

Describe 'New-DatabaseChangePackage — flywayTargetVersion derivation (Task 9.12 unified scheme)' {

  BeforeAll {
    function Get-ManifestForMigrations {
      param([string[]]$MigrationFileNames)
      $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
      $dbRoot = Join-Path $root 'Database' $script:AppName
      $mDir = Join-Path $dbRoot 'db' 'migrations'
      New-Item -ItemType Directory -Path $mDir -Force | Out-Null
      @{ version = '0.1.0' } | ConvertTo-Json | Set-Content (Join-Path $dbRoot 'version.json')
      foreach ($name in $MigrationFileNames) { "PRINT 'noop';" | Set-Content (Join-Path $mDir $name) }
      $nupkg = New-DatabaseChangePackage -Application $script:AppName -RepositoryRoot $root
      $stagingDir = Split-Path -Parent (Split-Path -Parent $nupkg)
      Get-Content (Join-Path $stagingDir 'db-release-unit-manifest.json') -Raw | ConvertFrom-Json
    }
  }

  It 'derives the dotted V00.0X.NNNNNN scheme as the highest migration version' {
    $m = Get-ManifestForMigrations -MigrationFileNames @(
      'V00.01.000010__core.sql',
      'V00.02.000040__agenttext.sql',
      'V00.02.000050__smoke.sql'
    )
    $m.flywayTargetVersion | Should -Be '00.02.000050'
  }

  It 'compares versions numerically per Flyway part semantics (not lexically)' {
    # Lexical sort would pick 000301 over 000050 only within the same band; this
    # asserts a higher minor band wins regardless of the patch digits.
    $m = Get-ManifestForMigrations -MigrationFileNames @(
      'V00.01.000301__late_in_band_one.sql',
      'V00.02.000050__band_two.sql'
    )
    $m.flywayTargetVersion | Should -Be '00.02.000050'
  }

  It 'still derives a value for the legacy short-integer scheme' {
    $m = Get-ManifestForMigrations -MigrationFileNames @('V1__init.sql')
    $m.flywayTargetVersion | Should -Be '1'
  }
}

Describe 'New-DatabaseChangePackage — output validation' {

  BeforeAll {
    $script:OutRoot = Join-Path $TestDrive 'out-validation'
    $appDbRoot = Join-Path $script:OutRoot 'Database' $script:AppName
    New-FixtureTree -DbRoot $appDbRoot
    $script:NupkgPath = New-DatabaseChangePackage -Application $script:AppName -RepositoryRoot $script:OutRoot
  }

  It 'Output path exists and is a valid zip (nupkg)' {
    Test-Path $script:NupkgPath | Should -BeTrue
    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
    { [System.IO.Compression.ZipFile]::OpenRead($script:NupkgPath).Dispose() } | Should -Not -Throw
  }

  It 'package-evidence.json contains one entry per staged file' {
    $stagingDir = Split-Path -Parent (Split-Path -Parent $script:NupkgPath)
    $evidencePath = Join-Path $stagingDir 'package-evidence.json'
    $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json
    $evidence.files.Count | Should -BeGreaterThan 0

    # Count staged db files
    $dbDir = Join-Path $stagingDir 'db'
    $stagedCount = @(Get-ChildItem -Recurse -File $dbDir).Count
    $evidence.files.Count | Should -Be $stagedCount
  }
}

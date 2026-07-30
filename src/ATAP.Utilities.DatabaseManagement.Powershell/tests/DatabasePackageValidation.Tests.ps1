#Requires -Version 7.0
# Pester tests for the database package validation cmdlets:
#   Get-DatabasePackageManifest, Test-DatabasePackageManifest,
#   Test-DatabaseChangePackage, Expand-DatabaseChangePackage

BeforeAll {
  Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
  Add-Type -AssemblyName 'System.IO.Compression'

  $pubDir = Join-Path $PSScriptRoot '..' 'public'
  foreach ($cmdlet in @(
      'Get-DatabasePackageManifest',
      'Test-DatabasePackageManifest',
      'Test-DatabaseChangePackage',
      'Expand-DatabaseChangePackage'
    )) {
    . (Join-Path $pubDir "$cmdlet.ps1")
  }

  # ─────────────────────────────────────────────────────────────────────────
  # Helpers
  # ─────────────────────────────────────────────────────────────────────────

  function New-ValidManifest {
    <# Build a minimal valid v2 db-release-unit-manifest object #>
    param(
      [string]$AppVersion = '1.2.3',
      [object[]]$Files = @()
    )
    [PSCustomObject]@{
      schemaVersion                    = 2
      dbChangeUnit                     = 'TestApp.Database.1.2.3'
      appVersion                       = $AppVersion
      changeKind                       = 'schema'
      flywayTargetVersion              = '1'
      createdUtc                       = '2026-01-01T00:00:00Z'
      createdFromGitTag                = 'v1.2.3'
      createdFromGitSha                = 'abc1234'
      files                            = $Files
      expectedRowCounts                = @{}
      compatibleAppPackageRanges       = @('[1.0.0,2.0.0)')
      requiresPreviousProductionSnapshot = $false
      rollbackSupported                = $false
      rollbackNotes                    = ''
      evidenceRequirements             = @{
        experimental = @{}
        development = @{}
        integration = @{}
        qa = @{}
        stable = @{}
      }
    }
  }

  function Get-Sha256 {
    param([string]$Path)
    (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLower()
  }

  function New-PackageFolder {
    <#
    Creates an expanded package folder under TestDrive with a valid manifest
    and one migration file. Returns the folder path.
    #>
    param(
      [string]$Root,
      [string]$MigContent = 'CREATE TABLE T (id INT);',
      [hashtable]$CeilingJson = $null,
      [switch]$BadChecksum,
      [switch]$MissingFile
    )
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    $dbDir = Join-Path $Root 'db'
    $migDir = Join-Path $dbDir 'migrations'
    New-Item -ItemType Directory -Path $migDir -Force | Out-Null

    $migFile = Join-Path $migDir 'V1__init.sql'
    $MigContent | Set-Content $migFile -Encoding UTF8

    $migHash = if ($BadChecksum) { 'deadbeefdeadbeefdeadbeefdeadbeef00000000000000000000000000000000' } else { Get-Sha256 $migFile }

    $fileEntry = [PSCustomObject]@{
      path           = 'db/migrations/V1__init.sql'
      kind           = 'migration'
      checksumSha256 = $migHash
      destructiveChangeKind = 'none'
    }

    $manifest = New-ValidManifest -Files @($fileEntry)
    if ($MissingFile) {
      # Reference a file that does not exist
      $manifest.files = @(
        [PSCustomObject]@{
          path = 'db/migrations/V2__phantom.sql'
          kind = 'migration'
          checksumSha256 = 'aaaa'
          destructiveChangeKind = 'none'
        },
        $fileEntry
      )
    }

    $manifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $Root 'db-release-unit-manifest.json') -Encoding UTF8

    if ($CeilingJson) {
      $CeilingJson | ConvertTo-Json | Set-Content (Join-Path $Root 'database-package-ceiling.json') -Encoding UTF8
    }

    return $Root
  }

  function New-PackageNupkg {
    <# Compress a package folder into a .nupkg and return its path. #>
    param([string]$PackageFolder, [string]$OutputPath)
    [System.IO.Compression.ZipFile]::CreateFromDirectory($PackageFolder, $OutputPath)
    return $OutputPath
  }
}

# ═══════════════════════════════════════════════════════════════════════════
# Test-DatabaseChangePackage — good package
# ═══════════════════════════════════════════════════════════════════════════
Describe 'Test-DatabaseChangePackage — valid package' {

  It 'Returns IsValid = $true for a package with correct manifest and checksums' {
    $pkgDir = Join-Path $TestDrive 'good-pkg'
    New-PackageFolder -Root $pkgDir

    $result = Test-DatabaseChangePackage -PackagePath $pkgDir

    $result.IsValid | Should -BeTrue
    $result.ManifestErrors | Should -BeNullOrEmpty
    $result.ChecksumErrors | Should -BeNullOrEmpty
    $result.CeilingViolation | Should -BeNullOrEmpty
  }
}

# ═══════════════════════════════════════════════════════════════════════════
# Test-DatabaseChangePackage — missing file
# ═══════════════════════════════════════════════════════════════════════════
Describe 'Test-DatabaseChangePackage — missing file in manifest' {

  It 'Reports a checksum error when a file referenced in the manifest does not exist' {
    $pkgDir = Join-Path $TestDrive 'missing-file-pkg'
    New-PackageFolder -Root $pkgDir -MissingFile

    $result = Test-DatabaseChangePackage -PackagePath $pkgDir

    $result.IsValid | Should -BeFalse
    $result.ChecksumErrors | Should -Not -BeNullOrEmpty
    ($result.ChecksumErrors | Where-Object { $_ -match 'V2__phantom' }) | Should -Not -BeNullOrEmpty
  }
}

# ═══════════════════════════════════════════════════════════════════════════
# Test-DatabaseChangePackage — checksum mismatch
# ═══════════════════════════════════════════════════════════════════════════
Describe 'Test-DatabaseChangePackage — checksum mismatch' {

  It 'Reports a checksum error when a file hash does not match the manifest' {
    $pkgDir = Join-Path $TestDrive 'bad-checksum-pkg'
    New-PackageFolder -Root $pkgDir -BadChecksum

    $result = Test-DatabaseChangePackage -PackagePath $pkgDir

    $result.IsValid | Should -BeFalse
    $result.ChecksumErrors | Should -Not -BeNullOrEmpty
    ($result.ChecksumErrors | Where-Object { $_ -match '[Mm]ismatch' }) | Should -Not -BeNullOrEmpty
  }
}

# ═══════════════════════════════════════════════════════════════════════════
# Test-DatabasePackageManifest — malformed manifest
# ═══════════════════════════════════════════════════════════════════════════
Describe 'Test-DatabasePackageManifest — malformed manifest' {

  It 'Reports manifest errors when required fields are missing' {
    $pkgDir = Join-Path $TestDrive 'malformed-pkg'
    New-Item -ItemType Directory -Path $pkgDir -Force | Out-Null
    # Write a manifest that is valid JSON but missing required fields
    @{ schemaVersion = 2; changeKind = 'schema' } | ConvertTo-Json |
      Set-Content (Join-Path $pkgDir 'db-release-unit-manifest.json') -Encoding UTF8

    $result = Test-DatabasePackageManifest -PackagePath $pkgDir

    $result.IsValid | Should -BeFalse
    $result.Errors | Should -Not -BeNullOrEmpty
    ($result.Errors | Where-Object { $_ -match 'Missing required field' }) | Should -Not -BeNullOrEmpty
  }

  It 'Reports a schema-version error when schemaVersion is not 2' {
    $pkgDir = Join-Path $TestDrive 'wrong-schema-version'
    New-Item -ItemType Directory -Path $pkgDir -Force | Out-Null
    $m = New-ValidManifest
    $m.schemaVersion = 1
    $m | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $pkgDir 'db-release-unit-manifest.json') -Encoding UTF8

    $result = Test-DatabasePackageManifest -PackagePath $pkgDir

    $result.IsValid | Should -BeFalse
    ($result.Errors | Where-Object { $_ -match 'schemaVersion' }) | Should -Not -BeNullOrEmpty
  }
}

# ═══════════════════════════════════════════════════════════════════════════
# Test-DatabaseChangePackage — ceiling violation
# ═══════════════════════════════════════════════════════════════════════════
Describe 'Test-DatabaseChangePackage — ceiling policy' {

  It 'Reports a ceiling violation when version has no prerelease label and Development ceiling exists' {
    $pkgDir     = Join-Path $TestDrive 'ceiling-stable-pkg'
    $sourceDir  = Join-Path $TestDrive 'ceiling-stable-src'
    New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null

    # Stable release version — exceeds Development ceiling
    $manifest = New-ValidManifest -AppVersion '2.0.0'
    New-Item -ItemType Directory -Path $pkgDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $pkgDir 'db' 'migrations') -Force | Out-Null
    'SELECT 1;' | Set-Content (Join-Path $pkgDir 'db' 'migrations' 'V1__init.sql') -Encoding UTF8
    $h = Get-Sha256 (Join-Path $pkgDir 'db' 'migrations' 'V1__init.sql')
    $manifest.files = @([PSCustomObject]@{
        path = 'db/migrations/V1__init.sql'
        kind = 'migration'
        checksumSha256 = $h
        destructiveChangeKind = 'none'
      })
    $manifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $pkgDir 'db-release-unit-manifest.json') -Encoding UTF8

    @{ maximumTier = 'Development' } | ConvertTo-Json |
      Set-Content (Join-Path $sourceDir 'database-package-ceiling.json') -Encoding UTF8

    $result = Test-DatabaseChangePackage -PackagePath $pkgDir `
      -DatabasePackageSourcePath $sourceDir -CheckCeiling

    $result.CeilingViolation | Should -Not -BeNullOrEmpty
    $result.IsValid | Should -BeFalse
  }
}

# ═══════════════════════════════════════════════════════════════════════════
# Expand-DatabaseChangePackage — round-trip
# ═══════════════════════════════════════════════════════════════════════════
Describe 'Expand-DatabaseChangePackage' {

  BeforeAll {
    $script:PkgDir = Join-Path $TestDrive 'expand-src'
    New-PackageFolder -Root $script:PkgDir

    $script:NupkgPath = Join-Path $TestDrive 'TestApp.Database.1.2.3.nupkg'
    New-PackageNupkg -PackageFolder $script:PkgDir -OutputPath $script:NupkgPath
  }

  It 'Extracts the nupkg to a temp folder and returns the folder path' {
    $dest = Expand-DatabaseChangePackage -NupkgPath $script:NupkgPath

    $dest | Should -Not -BeNullOrEmpty
    Test-Path $dest | Should -BeTrue
    Test-Path (Join-Path $dest 'db-release-unit-manifest.json') | Should -BeTrue
  }

  It 'Extracts to an explicit destination path' {
    $explicit = Join-Path $TestDrive 'expand-explicit'
    $result = Expand-DatabaseChangePackage -NupkgPath $script:NupkgPath -DestinationPath $explicit

    $result | Should -Be $explicit
    Test-Path (Join-Path $explicit 'db-release-unit-manifest.json') | Should -BeTrue
  }

  It 'Throws a terminating error when the nupkg file does not exist' {
    { Expand-DatabaseChangePackage -NupkgPath (Join-Path $TestDrive 'nonexistent.nupkg') } |
      Should -Throw
  }

  It 'Round-trip: extracted migration file matches original byte-for-byte' {
    $dest = Join-Path $TestDrive 'expand-roundtrip'
    Expand-DatabaseChangePackage -NupkgPath $script:NupkgPath -DestinationPath $dest | Out-Null

    $origMig = Join-Path $script:PkgDir 'db' 'migrations' 'V1__init.sql'
    $expMig  = Join-Path $dest 'db' 'migrations' 'V1__init.sql'

    Test-Path $expMig | Should -BeTrue
    (Get-FileHash $origMig -Algorithm SHA256).Hash |
      Should -Be (Get-FileHash $expMig -Algorithm SHA256).Hash
  }
}

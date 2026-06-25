#Requires -Version 7.0
# Pester 5+ tests for New-ReleaseBundle (Stream I2).

BeforeAll {
    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $publicDir = Join-Path $moduleRoot 'public'
    $fixturesDir = Join-Path $moduleRoot 'tests/fixtures/New-ReleaseBundle'
    . (Join-Path $publicDir 'New-ReleaseBundle.ps1')

    $script:fixtureManifest = Join-Path $fixturesDir 'manifest/manifest.json'
    $script:fixtureSourceRoot = Join-Path $fixturesDir 'source'
}

Describe 'New-ReleaseBundle' -Tag 'Unit' {
    BeforeEach {
        $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('NewReleaseBundle_' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null

        # Binary fixtures are intentionally ignored by the repository. Build a
        # complete disposable source tree so the manifest can exercise the
        # release-bundle layout without requiring a checked-in .dll.
        $script:tempSourceRoot = Join-Path $script:tempRoot 'source'
        Copy-Item -LiteralPath $script:fixtureSourceRoot -Destination $script:tempSourceRoot -Recurse -Force
        $appBinPath = Join-Path $script:tempSourceRoot 'app/bin'
        New-Item -ItemType Directory -Path $appBinPath -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $appBinPath 'AceCommander.dll') -Value 'test fixture' -Encoding UTF8
    }

    AfterEach {
        if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
            Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'creates the documented staging layout and packs a .upack archive from a fixture manifest' {
        $result = New-ReleaseBundle -Manifest $script:fixtureManifest -OutputPath $script:tempRoot -SourceRoot $script:tempSourceRoot

        $result.Path | Should -BeOfType ([System.IO.FileInfo])
        $result.Path.Extension | Should -Be '.upack'
        $result.Path.Exists | Should -BeTrue
        $result.BundleVersion | Should -Be '1.4.0+8f4b2c1'
        $result.BundleSize | Should -BeGreaterThan 0

        $stageRoot = Join-Path $script:tempRoot '_staging/AceCommander.1.4.0+8f4b2c1'
        foreach ($relativeDirectory in @(
                'app',
                'app/bin',
                'app/config',
                'app/symbols',
                'db',
                'db/flyway',
                'db/seed',
                'installer',
                'tests',
                'docs'
            )) {
            Test-Path -LiteralPath (Join-Path $stageRoot $relativeDirectory) -PathType Container | Should -BeTrue
        }

        foreach ($relativeFile in @(
                'manifest.json',
                'app/bin/AceCommander.dll',
                'db/flyway/V1.4.0__baseline_schema.sql',
                'db/db-manifest.json',
                'db/seed/S1_4_0_roles.csv',
                'db/seed/S1_4_0_roles_load.sql',
                'installer/Install-Application.ps1',
                'tests/unit-results.trx',
                'docs/RELEASE_NOTES.md'
            )) {
            Test-Path -LiteralPath (Join-Path $stageRoot $relativeFile) -PathType Leaf | Should -BeTrue
        }

        $dbManifest = Get-Content -LiteralPath (Join-Path $stageRoot 'db/db-manifest.json') -Raw | ConvertFrom-Json
        $dbManifest.dbChangeUnit | Should -Be 'AceCommander-db-1.4.0'
        $dbManifest.files.kind | Should -Contain 'migration'
        $dbManifest.files.kind | Should -Contain 'seedLoader'
        $dbManifest.expectedRowCounts.Roles | Should -Be 3

        $extractRoot = Join-Path $script:tempRoot 'extracted'
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($result.Path.FullName, $extractRoot)

        Test-Path -LiteralPath (Join-Path $extractRoot 'manifest.json') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $extractRoot 'db/db-manifest.json') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $extractRoot 'app/bin/AceCommander.dll') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $extractRoot 'installer/Install-Application.ps1') -PathType Leaf | Should -BeTrue
    }

    It 'throws a clear error when required manifest basics are missing' {
        $badManifest = Join-Path $script:tempRoot 'manifest.json'
        @{
            schemaVersion = 1
            appPackageId = 'AceCommander'
            checksums = @{}
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $badManifest -Encoding UTF8

        { New-ReleaseBundle -Manifest $badManifest -OutputPath $script:tempRoot -SourceRoot $script:tempSourceRoot } |
            Should -Throw -ExpectedMessage "*releaseVersion*"
    }

    It 'rejects bundle asset paths that escape the staging root' {
        $badManifest = Join-Path $script:tempRoot 'manifest.json'
        @{
            schemaVersion       = 1
            releaseVersion      = '1.4.0'
            sourceTag           = 'v1.4.0'
            sourceCommit        = '8f4b2c1d3e5fa9c4b1f2e3d4a5b6c7d8e9f0a1b2'
            buildUtc            = '2026-05-06T14:32:11Z'
            appPackageId        = 'AceCommander'
            appPackageVersion   = '1.4.0'
            dbChangeUnit        = 'AceCommander-db-1.4.0'
            flywayTargetVersion = '1.4.2'
            migrationFiles      = @()
            seedFiles           = @()
            seedLoaderScripts   = @()
            checksums           = @{
                '../outside.txt' = 'sha256:not-used'
            }
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $badManifest -Encoding UTF8

        { New-ReleaseBundle -Manifest $badManifest -OutputPath $script:tempRoot -SourceRoot $script:tempSourceRoot } |
            Should -Throw -ExpectedMessage '*escapes the allowed root*'
    }

    It 'throws when a manifest-referenced asset is missing from all source roots' {
        $badManifest = Join-Path $script:tempRoot 'manifest.json'
        $manifestObject = Get-Content -LiteralPath $script:fixtureManifest -Raw | ConvertFrom-Json
        $manifestObject.checksums |
            Add-Member -NotePropertyName 'docs/MISSING.md' -NotePropertyValue ('sha256:' + ('1' * 64))
        $manifestObject | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $badManifest -Encoding UTF8

        { New-ReleaseBundle -Manifest $badManifest -OutputPath $script:tempRoot -SourceRoot $script:tempSourceRoot } |
            Should -Throw -ExpectedMessage "*docs/MISSING.md*not found under any source root*"
    }
}

#Requires -Version 7.0

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $repoRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
  $publicDir = Join-Path $moduleRoot 'public'
  . (Join-Path $publicDir 'New-ReleaseManifest.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  $script:fixtureRoot = Join-Path $moduleRoot 'tests/fixtures'
  $script:schemaPath = Join-Path $repoRoot 'SolutionDocumentation/schemas/manifest.schema.json'
  $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('NewReleaseManifestIntegration_' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
}

AfterAll {
  if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
    Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Describe 'New-ReleaseManifest integration fixture' -Tag 'Integration', 'PromotedModuleHostSensitive' {
  It 'Generates a schema-valid manifest for tests/fixtures/db/sample/releases/0.0.1.yml' {
    $context = [PSCustomObject]@{
      Application            = 'sample'
      RepoRoot               = $script:fixtureRoot
      SourceTag              = 'v0.0.1'
      SourceCommit           = '0123456789abcdef0123456789abcdef01234567'
      Branch                 = 'release/0.0.1'
      ResolvedPackageVersion = '0.0.1'
      MajorMinorPatch        = '0.0.1'
      BuildUtc               = '2026-05-11T12:00:00Z'
      BuildAgent             = 'utat022'
      ManifestSchemaPath     = $script:schemaPath
    }

    $result = New-ReleaseManifest -Context $context -OutputPath $script:tempRoot
    $manifest = Get-Content -LiteralPath $result.FullName -Raw | ConvertFrom-Json
    $dbManifestPath = Join-Path (Split-Path -Parent $result.FullName) 'db-manifest.json'
    $dbManifestSchemaPath = Join-Path (Split-Path -Parent $script:schemaPath) 'db-manifest.schema.json'

    $result.Name | Should -Be 'manifest.json'
    $manifest.dbChangeUnit | Should -Be 'sample-db-0.0.1'
    $manifest.flywayTargetVersion | Should -Be '0.0.1'
    $manifest.migrationFiles | Should -Be @(
      'db/flyway/V0.0.1__baseline.sql',
      'db/flyway/R__views.sql'
    )
    $manifest.seedFiles | Should -Be @('db/seed/S0_0_1_roles.csv')
    $manifest.seedLoaderScripts | Should -Be @(
      'db/seed/S0_0_1_roles_load.sql',
      'db/seed/R__seed_lookup.sql'
    )

    $expectedMigrationHash = (Get-FileHash -LiteralPath (Join-Path $script:fixtureRoot 'db/sample/flyway/V0.0.1__baseline.sql') -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifest.checksums.'db/flyway/V0.0.1__baseline.sql' | Should -Be "sha256:$expectedMigrationHash"

    $json = Get-Content -LiteralPath $result.FullName -Raw
    Test-Json -Json $json -SchemaFile $script:schemaPath | Should -BeTrue

    Test-Path -LiteralPath $dbManifestPath -PathType Leaf | Should -BeTrue
    $dbManifestJson = Get-Content -LiteralPath $dbManifestPath -Raw
    Test-Json -Json $dbManifestJson -SchemaFile $dbManifestSchemaPath | Should -BeTrue
  }
}

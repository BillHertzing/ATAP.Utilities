Describe 'ReleaseBundle manifest v2 schema' -Tag 'Unit', 'Schemas' {
  BeforeAll {
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:SchemaPath = Join-Path $script:RepoRoot 'SolutionDocumentation/schemas/manifest.schema.json'
    $script:ValidManifest = [ordered]@{
      schemaVersion = 2
      releaseVersion = '1.2.3'
      sourceTag = 'v1.2.3'
      sourceCommit = '0123456789abcdef0123456789abcdef01234567'
      sourceBranch = 'release/1.2.3'
      buildUtc = '2026-08-20T12:00:00.0000000Z'
      buildAgent = 'utat022'
      applicationProvenance = [ordered]@{
        productId = 'AceCommander'
        root = [ordered]@{ id = 'AceCommander.Server'; version = '1.4.1'; qualityTier = 'Production'; projectPath = 'src/AceCommander.Server/AceCommander.Server.csproj' }
        components = @(
          [ordered]@{ id = 'AceCommon'; version = '3.0.0'; qualityTier = 'Production'; projectPath = 'src/AceCommon/AceCommon.csproj' },
          [ordered]@{ id = 'AceCommander.Client'; version = '1.4.7'; qualityTier = 'Production'; projectPath = 'src/AceCommander.Client/AceCommander.Client.csproj' }
        )
        artifactKind = 'HostedWebApplication'
        configuration = 'Release'
        targetFramework = 'net10.0'
        runtimeIdentifier = $null
        publishSettings = [ordered]@{
          selfContained = $false
          publishSingleFile = $false
          publishTrimmed = $false
          useAppHost = $false
        }
      }
      includedLibraryPackages = @([ordered]@{ id = 'ATAP.Utilities.Philote'; version = '1.0.0' })
      includedPowerShellModules = @()
      databasePackageReference = [ordered]@{
        id = 'AceCommander.Database'
        compatibleVersionRange = '[1.2.0,1.3.0)'
        pinnedVersion = '1.2.1'
        lifecycleCeiling = 'database-stable'
      }
      payloadFiles = @(
        [ordered]@{ path = 'app/AceCommander.Server.dll'; checksumSha256 = ('a' * 64); sizeBytes = 4096 },
        [ordered]@{ path = 'installer/Install-Application.ps1'; checksumSha256 = ('b' * 64); sizeBytes = 512 },
        [ordered]@{ path = 'tests/server.trx'; checksumSha256 = ('c' * 64); sizeBytes = 1024 }
      )
      installerScripts = @('installer/Install-Application.ps1')
      testEvidence = @([ordered]@{ kind = 'xunit'; path = 'tests/server.trx'; checksumSha256 = ('c' * 64) })
      compatibility = [ordered]@{
        osFamilies = @('windows')
        runtimeIdentifiers = @()
        dotnetRuntimeVersion = '10.0'
      }
      rollback = [ordered]@{
        supported = $false
        notes = 'Restore the preceding immutable application bundle.'
      }
    }

    function Copy-TestManifest {
      $script:ValidManifest | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    }

    function Invoke-ManifestSchemaValidation {
      param([Parameter(Mandatory = $true)]$Manifest)
      $errors = $null
      $valid = Test-Json -Json ($Manifest | ConvertTo-Json -Depth 20) -SchemaFile $script:SchemaPath -ErrorAction SilentlyContinue -ErrorVariable errors
      [pscustomobject]@{ IsValid = [bool]$valid; Errors = @($errors) }
    }
  }

  It 'declares the v2 Draft 2020-12 schema identity' {
    $schema = Get-Content -LiteralPath $script:SchemaPath -Raw | ConvertFrom-Json
    $schema.'$schema' | Should -Be 'https://json-schema.org/draft/2020-12/schema'
    $schema.'$id' | Should -Be 'https://atap.example.com/schemas/manifest/v2.json'
    $schema.properties.schemaVersion.const | Should -Be 2
  }

  It 'validates the canonical v2 application and database-reference shape' {
    (Invoke-ManifestSchemaValidation -Manifest $script:ValidManifest).IsValid | Should -BeTrue
  }

  It 'rejects v1 on the ordinary validation path' {
    $manifest = Copy-TestManifest
    $manifest.schemaVersion = 1
    (Invoke-ManifestSchemaValidation -Manifest $manifest).IsValid | Should -BeFalse
  }

  It 'rejects embedded database fields and database payload paths' {
    $withLegacyField = Copy-TestManifest
    $withLegacyField | Add-Member -NotePropertyName databasePackageIncluded -NotePropertyValue $true
    (Invoke-ManifestSchemaValidation -Manifest $withLegacyField).IsValid | Should -BeFalse

    $withDbPayload = Copy-TestManifest
    $withDbPayload.payloadFiles = @([ordered]@{
        path = 'db/flyway/V1__legacy.sql'
        checksumSha256 = ('d' * 64)
        sizeBytes = 10
      })
    (Invoke-ManifestSchemaValidation -Manifest $withDbPayload).IsValid | Should -BeFalse

    $withDbPayload.payloadFiles[0].path = 'db-manifest.json'
    (Invoke-ManifestSchemaValidation -Manifest $withDbPayload).IsValid | Should -BeFalse
  }
}
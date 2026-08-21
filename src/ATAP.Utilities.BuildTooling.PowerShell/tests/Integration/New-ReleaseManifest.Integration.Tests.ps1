#Requires -Version 7.0

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $repoRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
  . (Join-Path $moduleRoot 'public/New-ReleaseManifest.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  $script:schemaPath = Join-Path $repoRoot 'SolutionDocumentation/schemas/manifest.schema.json'
  $script:tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('NewReleaseManifestIntegration_' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
}

AfterAll {
  if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
    Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Describe 'New-ReleaseManifest v2 integration fixture' -Tag 'Integration' {
  It 'generates byte-identical schema-valid manifests without database payload or sidecar' {
    $context = [PSCustomObject]@{
      RepoRoot = $repoRoot
      ResolvedPackageVersion = '1.4.0'
      SourceTag = 'v1.4.0'
      SourceCommit = '0123456789abcdef0123456789abcdef01234567'
      Branch = 'release/1.4.0'
      BuildUtc = '2026-08-20T12:00:00Z'
      BuildAgent = 'utat022'
      ManifestSchemaPath = $script:schemaPath
      ApplicationProvenance = [PSCustomObject]@{
        ProductId = 'AceCommander'
        Root = [PSCustomObject]@{
          Id = 'AceCommander.Server'
          Version = '1.4.1'
          QualityTier = 'Production'
          ProjectPath = 'src/AceCommander.Server/AceCommander.Server.csproj'
        }
        Components = @(
          [PSCustomObject]@{ Id = 'AceCommander.Client'; Version = '1.4.7'; QualityTier = 'Production'; ProjectPath = 'src/AceCommander.Client/AceCommander.Client.csproj' },
          [PSCustomObject]@{ Id = 'AceCommon'; Version = '3.0.0'; QualityTier = 'Production'; ProjectPath = 'src/AceCommon/AceCommon.csproj' }
        )
        ArtifactKind = 'HostedWebApplication'
        Configuration = 'Release'
        TargetFramework = 'net10.0'
        RuntimeIdentifier = $null
        PublishSettings = [PSCustomObject]@{
          SelfContained = $false
          PublishSingleFile = $false
          PublishTrimmed = $false
          UseAppHost = $false
        }
      }
      IncludedLibraryPackages = @([PSCustomObject]@{ id = 'ATAP.Utilities.Philote'; version = '1.2.3' })
      IncludedPowerShellModules = @()
      DatabasePackageReference = [PSCustomObject]@{
        Id = 'AceCommander.Database'
        CompatibleVersionRange = '[1.3.0,1.5.0)'
        PinnedVersion = '1.4.0'
        LifecycleCeiling = 'database-stable'
      }
      PayloadFiles = @(
        [PSCustomObject]@{ path = 'tests/server.trx'; checksumSha256 = ('c' * 64); sizeBytes = 1024 },
        [PSCustomObject]@{ path = 'installer/Install-Application.ps1'; checksumSha256 = ('b' * 64); sizeBytes = 512 },
        [PSCustomObject]@{ path = 'app/AceCommander.Server.dll'; checksumSha256 = ('a' * 64); sizeBytes = 4096 }
      )
      InstallerScripts = @('installer/Install-Application.ps1')
      TestEvidence = @([PSCustomObject]@{ kind = 'xunit'; path = 'tests/server.trx'; checksumSha256 = ('c' * 64) })
      Compatibility = [PSCustomObject]@{
        OsFamilies = @('windows')
        RuntimeIdentifiers = @()
        DotnetRuntimeVersion = '10.0'
      }
      Rollback = [PSCustomObject]@{
        Supported = $false
        Notes = 'Restore the preceding immutable application bundle.'
      }
    }

    $first = New-ReleaseManifest -Context $context -OutputPath (Join-Path $script:tempRoot 'first')
    $second = New-ReleaseManifest -Context $context -OutputPath (Join-Path $script:tempRoot 'second')
    $firstJson = [IO.File]::ReadAllText($first.FullName)
    $manifest = $firstJson | ConvertFrom-Json

    Test-Json -Json $firstJson -SchemaFile $script:schemaPath | Should -BeTrue
    [IO.File]::ReadAllBytes($first.FullName) | Should -Be ([IO.File]::ReadAllBytes($second.FullName))
    $manifest.schemaVersion | Should -Be 2
    $manifest.payloadFiles.path | Should -Be @(
      'app/AceCommander.Server.dll',
      'installer/Install-Application.ps1',
      'tests/server.trx'
    )
    $manifest.PSObject.Properties.Name | Should -Not -Contain 'migrationFiles'
    $manifest.PSObject.Properties.Name | Should -Not -Contain 'checksums'
    Test-Path (Join-Path $first.DirectoryName 'db-manifest.json') | Should -BeFalse
    Test-Path (Join-Path $second.DirectoryName 'db-manifest.json') | Should -BeFalse
  }
}
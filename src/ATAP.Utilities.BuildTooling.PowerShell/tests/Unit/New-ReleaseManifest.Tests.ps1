#Requires -Version 7.0

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  . (Join-Path $moduleRoot 'public/New-ReleaseManifest.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  $script:tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('NewReleaseManifestUnit_' + [Guid]::NewGuid().ToString('N'))
  $script:repoRoot = Join-Path $script:tempRoot 'repo'
  New-Item -ItemType Directory -Path $script:repoRoot -Force | Out-Null

  function New-TestContext {
    [PSCustomObject]@{
      RepoRoot = $script:repoRoot
      ResolvedPackageVersion = '1.2.3'
      SourceTag = 'v1.2.3'
      SourceCommit = '0123456789ABCDEF0123456789ABCDEF01234567'
      Branch = 'release/1.2.3'
      BuildUtc = '2026-08-20T12:00:00Z'
      BuildAgent = 'utat022'
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
      IncludedLibraryPackages = @(
        [PSCustomObject]@{ id = 'Zulu.Package'; version = '2.0.0' },
        [PSCustomObject]@{ id = 'Alpha.Package'; version = '1.0.0' }
      )
      IncludedPowerShellModules = @([PSCustomObject]@{ id = 'ATAP.Utilities.PowerShell'; version = '3.0.0' })
      DatabasePackageReference = [PSCustomObject]@{
        Id = 'AceCommander.Database'
        CompatibleVersionRange = '[1.2.0,1.3.0)'
        PinnedVersion = '1.2.1'
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
  }
}

AfterAll {
  if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
    Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Describe 'New-ReleaseManifest v2' -Tag 'Unit' {
  BeforeEach {
    Get-ChildItem -LiteralPath $script:tempRoot -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -ne 'repo' } |
      Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'emits schema v2 with exact application provenance and separate database reference' {
    $result = New-ReleaseManifest -Context (New-TestContext) -OutputPath (Join-Path $script:tempRoot 'one')
    $manifest = [IO.File]::ReadAllText($result.FullName) | ConvertFrom-Json

    $manifest.schemaVersion | Should -Be 2
    $manifest.applicationProvenance.productId | Should -Be 'AceCommander'
    $manifest.releaseVersion | Should -Be '1.2.3'
    $manifest.applicationProvenance.root.id | Should -Be 'AceCommander.Server'
    $manifest.applicationProvenance.root.version | Should -Be '1.4.1'
    $manifest.applicationProvenance.root.qualityTier | Should -Be 'Production'
    $manifest.applicationProvenance.root.projectPath | Should -Be 'src/AceCommander.Server/AceCommander.Server.csproj'
    $manifest.applicationProvenance.components.projectPath | Should -Be @('src/AceCommander.Client/AceCommander.Client.csproj', 'src/AceCommon/AceCommon.csproj')
    $manifest.applicationProvenance.components.version | Should -Be @('1.4.7', '3.0.0')
    $manifest.applicationProvenance.runtimeIdentifier | Should -BeNullOrEmpty
    $manifest.applicationProvenance.publishSettings.selfContained | Should -BeFalse
    $manifest.databasePackageReference.id | Should -Be 'AceCommander.Database'
    $manifest.databasePackageReference.compatibleVersionRange | Should -Be '[1.2.0,1.3.0)'
    $manifest.databasePackageReference.pinnedVersion | Should -Be '1.2.1'
    $manifest.databasePackageReference.lifecycleCeiling | Should -Be 'database-stable'
  }

  It 'writes byte-identical output and deterministically sorts provenance and payloads' {
    $first = New-ReleaseManifest -Context (New-TestContext) -OutputPath (Join-Path $script:tempRoot 'first')
    $second = New-ReleaseManifest -Context (New-TestContext) -OutputPath (Join-Path $script:tempRoot 'second')

    [IO.File]::ReadAllBytes($first.FullName) | Should -Be ([IO.File]::ReadAllBytes($second.FullName))
    $manifest = [IO.File]::ReadAllText($first.FullName) | ConvertFrom-Json
    $manifest.payloadFiles.path | Should -Be @(
      'app/AceCommander.Server.dll',
      'installer/Install-Application.ps1',
      'tests/server.trx'
    )
    $manifest.includedLibraryPackages.id | Should -Be @('Alpha.Package', 'Zulu.Package')
  }

  It 'uses only payloadFiles path checksumSha256 and sizeBytes evidence' {
    $result = New-ReleaseManifest -Context (New-TestContext) -OutputPath (Join-Path $script:tempRoot 'shape')
    $manifest = [IO.File]::ReadAllText($result.FullName) | ConvertFrom-Json

    $manifest.payloadFiles[0].PSObject.Properties.Name | Should -Be @('path', 'checksumSha256', 'sizeBytes')
    $manifest.PSObject.Properties.Name | Should -Not -Contain 'checksums'
    $manifest.PSObject.Properties.Name | Should -Not -Contain 'migrationFiles'
    $manifest.PSObject.Properties.Name | Should -Not -Contain 'seedFiles'
    $manifest.PSObject.Properties.Name | Should -Not -Contain 'databasePackageIncluded'
    Test-Path (Join-Path $result.DirectoryName 'db-manifest.json') | Should -BeFalse
  }

  It 'rejects embedded database payloads and case-colliding paths' {
    $dbContext = New-TestContext
    $dbContext.PayloadFiles[0].path = 'db/flyway/V1__legacy.sql'
    { New-ReleaseManifest -Context $dbContext -OutputPath (Join-Path $script:tempRoot 'db') } |
      Should -Throw -ExpectedMessage '*forbidden embedded database payload*'

    $collisionContext = New-TestContext
    $collisionContext.PayloadFiles += [PSCustomObject]@{
      path = 'APP/AceCommander.Server.dll'
      checksumSha256 = ('d' * 64)
      sizeBytes = 4096
    }
    { New-ReleaseManifest -Context $collisionContext -OutputPath (Join-Path $script:tempRoot 'collision') } |
      Should -Throw -ExpectedMessage '*duplicate or case-colliding*'
  }

  It 'rejects invalid or ambiguous component provenance' {
    $context = New-TestContext
    $context.ApplicationProvenance.Components[0].ProjectPath = 'src\AceCommander.Client\AceCommander.Client.csproj'
    { New-ReleaseManifest -Context $context -OutputPath (Join-Path $script:tempRoot 'backslash') } |
      Should -Throw -ExpectedMessage '*must use forward slashes*'

    $context = New-TestContext
    $context.ApplicationProvenance.Components[1].Id = 'acecommander.client'
    { New-ReleaseManifest -Context $context -OutputPath (Join-Path $script:tempRoot 'duplicate-id') } |
      Should -Throw -ExpectedMessage '*duplicate id*'

    $context = New-TestContext
    $context.ApplicationProvenance.Components[1].ProjectPath = 'SRC/ACECOMMANDER.CLIENT/ACECOMMANDER.CLIENT.CSPROJ'
    { New-ReleaseManifest -Context $context -OutputPath (Join-Path $script:tempRoot 'duplicate-path') } |
      Should -Throw -ExpectedMessage '*case-colliding projectPath*'
  }
  It 'fails closed when deterministic or provenance inputs are implicit' {
    $context = New-TestContext
    $context.PSObject.Properties.Remove('BuildUtc')
    { New-ReleaseManifest -Context $context -OutputPath (Join-Path $script:tempRoot 'missing-time') } |
      Should -Throw -ExpectedMessage "*missing required field 'BuildUtc'*"

    $context = New-TestContext
    $context.BuildUtc = '2026-08-20T12:00:00'
    { New-ReleaseManifest -Context $context -OutputPath (Join-Path $script:tempRoot 'implicit-utc') } |
      Should -Throw -ExpectedMessage '*explicit UTC date-time*'

    $context = New-TestContext
    $context.ApplicationProvenance.PSObject.Properties.Remove('RuntimeIdentifier')
    { New-ReleaseManifest -Context $context -OutputPath (Join-Path $script:tempRoot 'missing-rid') } |
      Should -Throw -ExpectedMessage "*use null for a RID-less publish*"
  }

  It 'rejects installer and evidence references absent from payloadFiles' {
    $context = New-TestContext
    $context.InstallerScripts = @('installer/NotShipped.ps1')
    { New-ReleaseManifest -Context $context -OutputPath (Join-Path $script:tempRoot 'installer') } |
      Should -Throw -ExpectedMessage "*not present in PayloadFiles*"

    $context = New-TestContext
    $context.TestEvidence[0].path = 'tests/not-shipped.trx'
    { New-ReleaseManifest -Context $context -OutputPath (Join-Path $script:tempRoot 'evidence') } |
      Should -Throw -ExpectedMessage "*not present in PayloadFiles*"
  }

  It 'honors WhatIf without writing output' {
    $path = Join-Path $script:tempRoot 'whatif'
    $result = New-ReleaseManifest -Context (New-TestContext) -OutputPath $path -WhatIf

    $result | Should -BeNullOrEmpty
    Test-Path -LiteralPath $path | Should -BeFalse
  }
}
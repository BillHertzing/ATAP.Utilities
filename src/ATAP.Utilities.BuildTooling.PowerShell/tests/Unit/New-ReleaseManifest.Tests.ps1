#Requires -Version 7.0
# Pester 5+ tests for New-ReleaseManifest (Stream I1).

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $publicDir = Join-Path $moduleRoot 'public'
  . (Join-Path $publicDir 'New-ReleaseManifest.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
    function global:ConvertFrom-Yaml {
      param([Parameter(ValueFromRemainingArguments = $true)]$args)
      throw 'ConvertFrom-Yaml test stub must be mocked before use.'
    }
    $script:createdConvertFromYamlStub = $true
  }

  $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('NewReleaseManifestUnit_' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
  $script:repoRoot = Join-Path $script:tempRoot 'repo'
  New-Item -ItemType Directory -Path $script:repoRoot -Force | Out-Null
  $script:outputRoot = Join-Path $script:tempRoot 'out'
  $script:ymlPath = Join-Path $script:repoRoot 'db/sample/releases/0.0.1.yml'

  $script:baseContext = [PSCustomObject]@{
    Application            = 'sample'
    RepoRoot               = $script:repoRoot
    SourceTag              = 'v0.0.1'
    SourceCommit           = '0123456789abcdef0123456789abcdef01234567'
    Branch                 = 'release/0.0.1'
    ResolvedPackageVersion = '0.0.1'
    MajorMinorPatch        = '0.0.1'
    BuildUtc               = '2026-05-11T12:00:00Z'
    BuildAgent             = 'utat022'
  }

  $script:yaml = @'
appVersion: 0.0.1
dbChangeUnit: sample-db-0.0.1
flywayTargetVersion: 0.0.2
migrations:
  - V0.0.1__baseline.sql
repeatables:
  - R__views.sql
seedFiles:
  - S0_0_1_roles.csv
seedLoaders:
  - S0_0_1_roles_load.sql
  - R__seed_lookup.sql
expectedRowCounts:
  Roles: 3
notes: |
  Unit fixture.
'@
}

AfterAll {
  if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
    Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
  if ($script:createdConvertFromYamlStub) {
    Remove-Item Function:\ConvertFrom-Yaml -ErrorAction SilentlyContinue
  }
}

Describe 'New-ReleaseManifest' -Tag 'Unit' {
  BeforeEach {
    if (Test-Path -LiteralPath $script:outputRoot) {
      Remove-Item -LiteralPath $script:outputRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Mock Get-Command -ParameterFilter { $Name -eq 'ConvertFrom-Yaml' } -MockWith { $null }
    Mock ConvertFrom-Yaml -MockWith { throw 'ConvertFrom-Yaml should not be used by simple-parser tests.' }
    Mock Get-Content -ParameterFilter { $LiteralPath -eq $script:ymlPath -and $Raw } -MockWith { $script:yaml }
    Mock Test-Path -ParameterFilter { $LiteralPath -eq $script:ymlPath -and $PathType -eq 'Leaf' } -MockWith { $true }
    Mock Test-Path -ParameterFilter { [string]$LiteralPath -like '*SolutionDocumentation*manifest.schema.json' -and $PathType -eq 'Leaf' } -MockWith { $false }
    Mock Test-Path -ParameterFilter { [string]$LiteralPath -like '*db*sample*flyway*' -and $PathType -eq 'Leaf' } -MockWith { $true }
    Mock Test-Path -ParameterFilter { [string]$LiteralPath -like '*db*sample*seed*' -and $PathType -eq 'Leaf' } -MockWith { $true }
    Mock Get-FileHash -MockWith {
      param($LiteralPath, $Algorithm)
      $leaf = Split-Path -Leaf $LiteralPath
      $hashChar = switch -Regex ($leaf) {
        '^V' { 'a'; break }
        '^R__views' { 'b'; break }
        '^S.*\.csv$' { 'c'; break }
        '_load\.sql$' { 'd'; break }
        default { 'e' }
      }
      [PSCustomObject]@{ Hash = ($hashChar * 64) }
    }
  }

  It 'Writes manifest.json to the default generated path and returns FileInfo' {
    $result = New-ReleaseManifest -Context $script:baseContext -YamlParserMode Simple

    $result | Should -BeOfType ([System.IO.FileInfo])
    $result.FullName | Should -Be (Join-Path $script:repoRoot '_generated/release-manifest/0.0.1/manifest.json')
    Test-Path -LiteralPath $result.FullName -PathType Leaf | Should -BeTrue
  }

  It 'Parses the documented simple YAML shape without ConvertFrom-Yaml and emits required fields' {
    $result = New-ReleaseManifest -Context $script:baseContext -OutputPath $script:outputRoot -YamlParserMode Simple
    $manifest = [System.IO.File]::ReadAllText($result.FullName) | ConvertFrom-Json

    $manifest.schemaVersion | Should -Be 1
    $manifest.releaseVersion | Should -Be '0.0.1'
    $manifest.sourceTag | Should -Be 'v0.0.1'
    $manifest.sourceCommit | Should -Be '0123456789abcdef0123456789abcdef01234567'
    $manifest.sourceBranch | Should -Be 'release/0.0.1'
    $manifest.appPackageId | Should -Be 'sample'
    $manifest.databasePackageIncluded | Should -BeTrue
    $manifest.dbChangeUnit | Should -Be 'sample-db-0.0.1'
    $manifest.flywayTargetVersion | Should -Be '0.0.2'
    $manifest.migrationFiles | Should -Contain 'db/flyway/V0.0.1__baseline.sql'
    $manifest.migrationFiles | Should -Contain 'db/flyway/R__views.sql'
    $manifest.seedFiles | Should -Contain 'db/seed/S0_0_1_roles.csv'
    $manifest.seedLoaderScripts | Should -Contain 'db/seed/S0_0_1_roles_load.sql'
    $manifest.installerScripts.Count | Should -BeGreaterThan 0
    $manifest.testEvidence.Count | Should -BeGreaterThan 0
    $manifest.compatibility.requiredDotnet | Should -Be '10.0'
    $manifest.rollback.supported | Should -BeFalse
  }

  It 'Computes sha256-prefixed checksums for every referenced DB file' {
    $result = New-ReleaseManifest -Context $script:baseContext -OutputPath $script:outputRoot -YamlParserMode Simple
    $manifest = [System.IO.File]::ReadAllText($result.FullName) | ConvertFrom-Json

    $manifest.checksums.'db/flyway/V0.0.1__baseline.sql' | Should -Be ('sha256:' + ('a' * 64))
    $manifest.checksums.'db/flyway/R__views.sql' | Should -Be ('sha256:' + ('b' * 64))
    $manifest.checksums.'db/seed/S0_0_1_roles.csv' | Should -Be ('sha256:' + ('c' * 64))
    $manifest.checksums.'db/seed/S0_0_1_roles_load.sql' | Should -Be ('sha256:' + ('d' * 64))
    $manifest.checksums.'db/seed/R__seed_lookup.sql' | Should -Be ('sha256:' + ('e' * 64))
    Assert-MockCalled Get-FileHash -Times 5 -Exactly -Scope It
  }

  It 'Writes a DB sub-manifest sidecar for bundle assembly' {
    $result = New-ReleaseManifest -Context $script:baseContext -OutputPath $script:outputRoot -YamlParserMode Simple
    $dbManifestPath = Join-Path (Split-Path -Parent $result.FullName) 'db-manifest.json'
    $dbManifest = [System.IO.File]::ReadAllText($dbManifestPath) | ConvertFrom-Json

    Test-Path -LiteralPath $dbManifestPath -PathType Leaf | Should -BeTrue
    $dbManifest.schemaVersion | Should -Be 1
    $dbManifest.dbChangeUnit | Should -Be 'sample-db-0.0.1'
    $dbManifest.files.path | Should -Contain 'flyway/V0.0.1__baseline.sql'
    $dbManifest.files.path | Should -Contain 'flyway/R__views.sql'
    $dbManifest.files.kind | Should -Contain 'repeatable'
    $dbManifest.files.path | Should -Contain 'seed/S0_0_1_roles_load.sql'
    $dbManifest.expectedRowCounts.Roles | Should -Be 3
  }

  It 'Throws clearly when the DB release YAML is absent' {
    Mock Test-Path -ParameterFilter { $LiteralPath -eq $script:ymlPath -and $PathType -eq 'Leaf' } -MockWith { $false }

    { New-ReleaseManifest -Context $script:baseContext -OutputPath $script:outputRoot -YamlParserMode Simple } |
      Should -Throw -ExpectedMessage '*DB release YAML not found*Database-Change-Unit-and-Flyway-Promotion.md section 2*'
  }

  It 'Throws clearly when a documented YAML field is missing' {
    Mock Get-Content -ParameterFilter { $LiteralPath -eq $script:ymlPath -and $Raw } -MockWith {
      $script:yaml -replace 'flywayTargetVersion: 0\.0\.2\r?\n', ''
    }

    { New-ReleaseManifest -Context $script:baseContext -OutputPath $script:outputRoot -YamlParserMode Simple } |
      Should -Throw -ExpectedMessage "*missing required field 'flywayTargetVersion'*"
  }

  It 'Uses ConvertFrom-Yaml when it is available' {
    Mock Get-Command -ParameterFilter { $Name -eq 'ConvertFrom-Yaml' } -MockWith { [PSCustomObject]@{ Name = 'ConvertFrom-Yaml' } }
    Mock ConvertFrom-Yaml -MockWith {
      [PSCustomObject]@{
        appVersion          = '0.0.1'
        dbChangeUnit        = 'sample-db-0.0.1'
        flywayTargetVersion = '0.0.2'
        migrations          = @('V0.0.1__baseline.sql')
        repeatables         = @('R__views.sql')
        seedFiles           = @('S0_0_1_roles.csv')
        seedLoaders         = @('S0_0_1_roles_load.sql')
        expectedRowCounts   = @{ Roles = 3 }
        notes               = 'from mock parser'
      }
    }

    New-ReleaseManifest -Context $script:baseContext -OutputPath $script:outputRoot -YamlParserMode Command | Out-Null

    Assert-MockCalled ConvertFrom-Yaml -Times 1 -Exactly -Scope It
  }

  It 'Allows Context to override dependencies, test evidence, installer, compatibility, and rollback fields' {
    $ctx = $script:baseContext.PSObject.Copy()
    $ctx | Add-Member -NotePropertyName IncludedLibraryPackages -NotePropertyValue @([PSCustomObject]@{ id = 'ATAP.Utilities.Philote'; version = '1.2.3' })
    $ctx | Add-Member -NotePropertyName IncludedPowerShellModules -NotePropertyValue @([PSCustomObject]@{ id = 'ATAP.Utilities.FileIO.PowerShell'; version = '2.3.4' })
    $ctx | Add-Member -NotePropertyName InstallerScripts -NotePropertyValue @('installer/CustomInstall.ps1')
    $ctx | Add-Member -NotePropertyName TestEvidence -NotePropertyValue @([PSCustomObject]@{ kind = 'unit'; path = 'tests/unit.trx'; checksumSha256 = ('f' * 64) })
    $ctx | Add-Member -NotePropertyName Compatibility -NotePropertyValue ([PSCustomObject]@{
        minDbVersion   = '0.0.0'
        maxDbVersion   = '0.0.2'
        supportedOs    = @('Windows 11')
        requiredDotnet = '9.0'
      })
    $ctx | Add-Member -NotePropertyName Rollback -NotePropertyValue ([PSCustomObject]@{
        supported = $true
        notes     = 'Custom rollback path is documented.'
      })

    $result = New-ReleaseManifest -Context $ctx -OutputPath $script:outputRoot -YamlParserMode Simple
    $manifest = [System.IO.File]::ReadAllText($result.FullName) | ConvertFrom-Json

    $manifest.includedLibraryPackages[0].id | Should -Be 'ATAP.Utilities.Philote'
    $manifest.includedPowerShellModules[0].version | Should -Be '2.3.4'
    $manifest.installerScripts | Should -Be @('installer/CustomInstall.ps1')
    $manifest.testEvidence[0].checksumSha256 | Should -Be ('f' * 64)
    $manifest.compatibility.requiredDotnet | Should -Be '9.0'
    $manifest.compatibility.supportedOs | Should -Be @('Windows 11')
    $manifest.rollback.supported | Should -BeTrue
    $manifest.rollback.notes | Should -Be 'Custom rollback path is documented.'
  }

  It 'Validates generated JSON with Test-Json when the schema exists' {
    $schemaPath = Join-Path $script:repoRoot 'SolutionDocumentation/schemas/manifest.schema.json'
    Mock Test-Path -ParameterFilter { $LiteralPath -eq $schemaPath -and $PathType -eq 'Leaf' } -MockWith { $true }
    Mock Test-Json -ParameterFilter { $SchemaFile -eq $schemaPath } -MockWith { $true }

    New-ReleaseManifest -Context $script:baseContext -OutputPath $script:outputRoot -YamlParserMode Simple | Out-Null

    Assert-MockCalled Test-Json -Times 1 -Exactly -Scope It -ParameterFilter { $SchemaFile -eq $schemaPath }
  }

  It 'Throws when schema validation fails' {
    $schemaPath = Join-Path $script:repoRoot 'SolutionDocumentation/schemas/manifest.schema.json'
    Mock Test-Path -ParameterFilter { $LiteralPath -eq $schemaPath -and $PathType -eq 'Leaf' } -MockWith { $true }
    Mock Test-Json -ParameterFilter { $SchemaFile -eq $schemaPath } -MockWith { $false }

    { New-ReleaseManifest -Context $script:baseContext -OutputPath $script:outputRoot -YamlParserMode Simple } |
      Should -Throw -ExpectedMessage '*does not validate against schema*'
  }
}

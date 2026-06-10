# Pester tests for explicit package version handoff used by BuildMaster.

BeforeAll {
  . (Join-Path $PSScriptRoot '..' 'public' 'New-DatabaseChangePackage.ps1')

  if (-not (Get-Command Write-PSFMessage -CommandType Function -ErrorAction SilentlyContinue)) {
    function Write-PSFMessage {
      param(
        [string]$FunctionName,
        [string]$ModuleName,
        [string]$Level,
        [string]$Message,
        [string[]]$Tag
      )
    }
  }
}

Describe 'New-DatabaseChangePackage -PackageVersion' {
  It 'uses the resolved package version when version.json contains NBGV height tokens' {
    $repoRoot = Join-Path $TestDrive 'fixture-repo'
    $dbRoot = Join-Path $repoRoot 'Database' 'ATAPUtilities'
    $migrationRoot = Join-Path $dbRoot 'db' 'migrations'

    New-Item -ItemType Directory -Path $migrationRoot -Force | Out-Null
    @{
      version = '0.1-Sprint.{height}'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dbRoot 'version.json') -Encoding UTF8
    "PRINT 'no-op';" | Set-Content -LiteralPath (Join-Path $migrationRoot 'V1__noop.sql') -Encoding UTF8

    $nupkg = New-DatabaseChangePackage `
      -Application 'ATAPUtilities' `
      -RepositoryRoot $repoRoot `
      -PackageVersion '0.1.0-Sprint.15'

    Test-Path -LiteralPath $nupkg | Should -BeTrue

    $stagingRoot = Split-Path -Parent (Split-Path -Parent $nupkg)
    $manifest = Get-Content -LiteralPath (Join-Path $stagingRoot 'db-release-unit-manifest.json') -Raw | ConvertFrom-Json
    $manifest.appVersion | Should -Be '0.1.0-Sprint.15'
  }
}

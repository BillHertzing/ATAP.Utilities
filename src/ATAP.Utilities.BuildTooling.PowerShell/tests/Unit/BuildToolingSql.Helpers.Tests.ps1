#Requires -Version 7.0
# Pester 5+ tests for BuildTooling SQL helper loading.

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $privateDir = Join-Path $moduleRoot 'private'
  $repoRoot = (Resolve-Path -LiteralPath (Join-Path $moduleRoot '..\..')).Path

  . (Join-Path $privateDir 'BuildToolingSql.Helpers.ps1')
}

Describe 'BuildToolingSql.Helpers' -Tag 'Unit' {
  It 'does not contain hard-coded Dropbox fallback paths' {
    $helperText = Get-Content -LiteralPath (Join-Path $privateDir 'BuildToolingSql.Helpers.ps1') -Raw
    $helperText | Should -Not -Match 'C:\\Dropbox'
    $helperText | Should -Not -Match 'ATAP\.Utilities-wt-\d+'
  }

  It 'loads Resolve-DatabaseSqlConnection from the supplied repository root' {
    Remove-Item Function:\Resolve-DatabaseSqlConnection -ErrorAction SilentlyContinue
    Remove-Module ATAP.Utilities.DatabaseManagement.Powershell -Force -ErrorAction SilentlyContinue

    Import-BuildToolingDatabaseResolver -RepositoryRoot $repoRoot

    Get-Command -Name Resolve-DatabaseSqlConnection -CommandType Function -ErrorAction Stop |
      Should -Not -BeNullOrEmpty
  }
}

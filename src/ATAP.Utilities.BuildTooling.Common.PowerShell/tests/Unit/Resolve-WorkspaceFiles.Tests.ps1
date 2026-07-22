BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $manifestPath = Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.Common.PowerShell.psd1'
  $promotedManifest = [System.Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
  Remove-Module -Name 'ATAP.Utilities.BuildTooling.Common.PowerShell' -Force -ErrorAction SilentlyContinue
  Import-Module -Name $(if ([string]::IsNullOrWhiteSpace($promotedManifest)) { $manifestPath } else { $promotedManifest }) -Force -ErrorAction Stop

  $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "common-rwf-$([guid]::NewGuid().ToString('N'))"
  New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
}

AfterAll {
  Remove-Item -LiteralPath $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Resolve-WorkspaceFiles' -Tag 'Unit' {
  It 'returns provider paths for multiple existing workspace files' {
    $first = Join-Path $script:tempDir 'one.code-workspace'
    $second = Join-Path $script:tempDir 'two.code-workspace'
    Set-Content -LiteralPath $first -Value '{}' -Encoding UTF8
    Set-Content -LiteralPath $second -Value '{}' -Encoding UTF8

    $result = Resolve-WorkspaceFiles -WorkspaceFiles @($first, $second)

    $result | Should -Be @((Resolve-Path -LiteralPath $first).ProviderPath, (Resolve-Path -LiteralPath $second).ProviderPath)
  }

  It 'throws when any workspace file does not exist' {
    { Resolve-WorkspaceFiles -WorkspaceFiles @((Join-Path $script:tempDir 'missing.code-workspace')) } |
      Should -Throw
  }
}

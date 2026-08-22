# Pester 5+ RepoHealth gate for Task 15.181.i Option B manual version policy.
# A protected source-content change must be accompanied by a new manually selected version.

Describe 'Package version reuse guard' -Tag 'RepoHealth' {
  BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $script:BaselinePath = Join-Path $script:RepoRoot 'tests\RepoHealth\Package.VersionReuse.Baseline.json'
    $script:ProjectRoot = Join-Path $script:RepoRoot 'src\ATAP.Utilities.Configuration'
    $script:VersionPath = Join-Path $script:ProjectRoot 'version.json'

    function Get-ProtectedPackageContentFingerprint {
      param([Parameter(Mandatory)][string]$ProjectRoot)
      $resolvedRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
      $files = Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File | Where-Object {
        $_.Name -ne 'version.json' -and $_.FullName -notmatch '[\\/](bin|obj|_generated)[\\/]'
      } | Sort-Object FullName
      $lines = foreach ($file in $files) {
        $relative = $file.FullName.Substring($resolvedRoot.Length).TrimStart([char[]]@('\','/')) -replace '\\','/'
        '{0}:{1}' -f $relative, (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
      }
      $sha256 = [System.Security.Cryptography.SHA256]::Create()
      try {
        return -join ($sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))) | ForEach-Object { $_.ToString('x2') })
      } finally {
        $sha256.Dispose()
      }
    }

    function Assert-ManualPackageVersionReuse {
      param(
        [Parameter(Mandatory)][string]$BaselineVersion,
        [Parameter(Mandatory)][string]$CurrentVersion,
        [Parameter(Mandatory)][string]$BaselineFingerprint,
        [Parameter(Mandatory)][string]$CurrentFingerprint
      )
      if ($BaselineVersion -eq $CurrentVersion -and $BaselineFingerprint -ne $CurrentFingerprint) {
        throw "Package version '$CurrentVersion' is reused with changed protected content hash. Select a new manual version before release."
      }
    }
  }

  It 'fails when a version is reused with changed protected content' {
    { Assert-ManualPackageVersionReuse -BaselineVersion '0.1.2' -CurrentVersion '0.1.2' -BaselineFingerprint ('a' * 64) -CurrentFingerprint ('b' * 64) } |
      Should -Throw '*reused with changed protected content hash*'
  }

  It 'accepts unchanged protected content for the same version' {
    { Assert-ManualPackageVersionReuse -BaselineVersion '0.1.2' -CurrentVersion '0.1.2' -BaselineFingerprint ('a' * 64) -CurrentFingerprint ('a' * 64) } |
      Should -Not -Throw
  }

  It 'permits a manually selected successor version' {
    { Assert-ManualPackageVersionReuse -BaselineVersion '0.1.2' -CurrentVersion '0.1.3' -BaselineFingerprint ('a' * 64) -CurrentFingerprint ('b' * 64) } |
      Should -Not -Throw
  }

  It 'matches the checked-in Configuration baseline exactly' {
    $baseline = Get-Content -LiteralPath $script:BaselinePath -Raw | ConvertFrom-Json -Depth 10
    $entry = @($baseline.packages | Where-Object { $_.packageId -eq 'ATAP.Utilities.Configuration' })
    $entry.Count | Should -Be 1
    $version = (Get-Content -LiteralPath $script:VersionPath -Raw | ConvertFrom-Json).version
    $version | Should -Match '^\d+\.\d+\.\d+$'
    $entry[0].version | Should -BeExactly $version
    (Get-ProtectedPackageContentFingerprint -ProjectRoot $script:ProjectRoot) | Should -BeExactly $entry[0].contentFingerprintSha256
  }
}

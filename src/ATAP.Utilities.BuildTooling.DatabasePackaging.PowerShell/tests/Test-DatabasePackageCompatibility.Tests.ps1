#Requires -Version 7.0
<#
.SYNOPSIS
    Pester 5 tests for Test-DatabasePackageCompatibility (DBA2-T06 / V4-E12).
#>

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
  Import-Module (Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell.psd1') -Force -ErrorAction Stop
}

Describe 'Test-DatabasePackageCompatibility' {

  # ── Helpers ────────────────────────────────────────────────────────────────
  function New-ManifestFile {
    param(
      [string]$Directory,
      [string[]]$Ranges
    )
    $rangeJson = if ($Ranges.Count -gt 0) {
      '[ ' + ($Ranges | ForEach-Object { "`"$_`"" } | Join-String -Separator ', ') + ' ]'
    } else {
      '[]'
    }
    $json = @"
{
  "schemaVersion": 2,
  "dbChangeUnit": "ATAPUtilities.Database.1.5.0",
  "appVersion": "1.5.0",
  "compatibleAppPackageRanges": $rangeJson
}
"@
    $path = Join-Path $Directory 'db-release-unit-manifest.json'
    Set-Content -LiteralPath $path -Value $json -Encoding UTF8
    return $path
  }

  # ── In-range tests ──────────────────────────────────────────────────────────
  Context 'Application version within range' {

    It 'Returns IsCompatible=true for version inside NuGet-style [1.4.0,1.6.0)' {
      $dir = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'tc01')
      $mPath = New-ManifestFile -Directory $dir.FullName -Ranges @('[1.4.0,1.6.0)')

      $result = Test-DatabasePackageCompatibility `
        -DatabasePackageManifestPath $mPath `
        -AppPackageVersion '1.5.3'

      $result.IsCompatible | Should -BeTrue
      $result.MatchedRange | Should -Be '[1.4.0,1.6.0)'
    }

    It 'Returns IsCompatible=true when first range matches (stops early)' {
      $dir = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'tc02')
      $mPath = New-ManifestFile -Directory $dir.FullName `
        -Ranges @('[1.4.0,1.6.0)', '[2.0.0,3.0.0)')

      $result = Test-DatabasePackageCompatibility `
        -DatabasePackageManifestPath $mPath `
        -AppPackageVersion '1.5.0'

      $result.IsCompatible | Should -BeTrue
      $result.MatchedRange | Should -Be '[1.4.0,1.6.0)'
    }

    It 'Returns IsCompatible=true when second range matches' {
      $dir = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'tc03')
      $mPath = New-ManifestFile -Directory $dir.FullName `
        -Ranges @('[1.4.0,1.6.0)', '[2.0.0,3.0.0)')

      $result = Test-DatabasePackageCompatibility `
        -DatabasePackageManifestPath $mPath `
        -AppPackageVersion '2.1.0'

      $result.IsCompatible | Should -BeTrue
      $result.MatchedRange | Should -Be '[2.0.0,3.0.0)'
    }

    It 'Returns IsCompatible=true for npm-style range (>=1.0.0 <2.0.0)' {
      $dir = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'tc04')
      $mPath = New-ManifestFile -Directory $dir.FullName -Ranges @('>=1.0.0 <2.0.0')

      $result = Test-DatabasePackageCompatibility `
        -DatabasePackageManifestPath $mPath `
        -AppPackageVersion '1.9.9'

      $result.IsCompatible | Should -BeTrue
    }

    It 'Returns IsCompatible=true when compatibleAppPackageRanges is empty (no constraint)' {
      $dir = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'tc05')
      $mPath = New-ManifestFile -Directory $dir.FullName -Ranges @()

      $result = Test-DatabasePackageCompatibility `
        -DatabasePackageManifestPath $mPath `
        -AppPackageVersion '99.0.0'

      $result.IsCompatible | Should -BeTrue
    }
  }

  # ── Out-of-range tests ──────────────────────────────────────────────────────
  Context 'Application version outside all ranges' {

    It 'Returns IsCompatible=false when version is above NuGet exclusive upper bound' {
      $dir = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'tc06')
      $mPath = New-ManifestFile -Directory $dir.FullName -Ranges @('[1.4.0,1.6.0)')

      $result = Test-DatabasePackageCompatibility `
        -DatabasePackageManifestPath $mPath `
        -AppPackageVersion '1.7.0'

      $result.IsCompatible | Should -BeFalse
      $result.MatchedRange | Should -BeNullOrEmpty
    }

    It 'Returns IsCompatible=false when version is below the lower bound' {
      $dir = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'tc07')
      $mPath = New-ManifestFile -Directory $dir.FullName -Ranges @('[1.4.0,1.6.0)')

      $result = Test-DatabasePackageCompatibility `
        -DatabasePackageManifestPath $mPath `
        -AppPackageVersion '1.2.0'

      $result.IsCompatible | Should -BeFalse
    }

    It 'Returns IsCompatible=false for npm-style range when version is too high' {
      $dir = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'tc08')
      $mPath = New-ManifestFile -Directory $dir.FullName -Ranges @('>=1.0.0 <2.0.0')

      $result = Test-DatabasePackageCompatibility `
        -DatabasePackageManifestPath $mPath `
        -AppPackageVersion '2.0.0'

      $result.IsCompatible | Should -BeFalse
    }

    It 'TriedRanges contains all ranges when none match' {
      $dir = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'tc09')
      $mPath = New-ManifestFile -Directory $dir.FullName `
        -Ranges @('[1.4.0,1.6.0)', '[2.0.0,3.0.0)')

      $result = Test-DatabasePackageCompatibility `
        -DatabasePackageManifestPath $mPath `
        -AppPackageVersion '1.9.0'

      $result.IsCompatible | Should -BeFalse
      $result.TriedRanges.Count | Should -Be 2
    }
  }

  # ── Boundary / edge cases ───────────────────────────────────────────────────
  Context 'Boundary conditions' {

    It 'Inclusive lower bound [1.4.0 includes exactly 1.4.0' {
      $dir = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'tc10')
      $mPath = New-ManifestFile -Directory $dir.FullName -Ranges @('[1.4.0,1.6.0)')

      $result = Test-DatabasePackageCompatibility `
        -DatabasePackageManifestPath $mPath `
        -AppPackageVersion '1.4.0'

      $result.IsCompatible | Should -BeTrue
    }

    It 'Exclusive upper bound 1.6.0) excludes exactly 1.6.0' {
      $dir = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'tc11')
      $mPath = New-ManifestFile -Directory $dir.FullName -Ranges @('[1.4.0,1.6.0)')

      $result = Test-DatabasePackageCompatibility `
        -DatabasePackageManifestPath $mPath `
        -AppPackageVersion '1.6.0'

      $result.IsCompatible | Should -BeFalse
    }
  }

  # ── Error cases ──────────────────────────────────────────────────────────────
  Context 'Terminating errors' {

    It 'Throws when manifest file does not exist' {
      { Test-DatabasePackageCompatibility `
          -DatabasePackageManifestPath (Join-Path $TestDrive 'missing.json') `
          -AppPackageVersion '1.0.0' } | Should -Throw
    }

    It 'Throws when AppPackageVersion is not a valid SemVer' {
      $dir = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'tc-bad-ver')
      $mPath = New-ManifestFile -Directory $dir.FullName -Ranges @('[1.0.0,2.0.0)')

      { Test-DatabasePackageCompatibility `
          -DatabasePackageManifestPath $mPath `
          -AppPackageVersion 'not-a-version' } | Should -Throw
    }

    It 'Throws on malformed NuGet range in manifest' {
      $dir = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'tc-bad-range')
      $mPath = New-ManifestFile -Directory $dir.FullName -Ranges @('[NOTVALID]')

      { Test-DatabasePackageCompatibility `
          -DatabasePackageManifestPath $mPath `
          -AppPackageVersion '1.0.0' } | Should -Throw
    }
  }
}

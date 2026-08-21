#Requires -Version 7.0
<#
.SYNOPSIS
    Pester 5 tests for Test-DatabasePackageCompatibility (DBA2-T06 / V4-E12).
#>

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
  Import-Module (Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell.psd1') -Force -ErrorAction Stop

  function script:New-ManifestFile {
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

  function script:New-ReleaseBundleV2File {
    param(
      [string]$Directory,
      [string]$Id = 'ATAPUtilities.Database',
      [string]$Range = '[1.4.0,1.6.0)',
      [string]$Pin = '1.5.0',
      [string]$Ceiling = 'database-stable',
      [switch]$OmitReference,
      [switch]$OmitPin
    )
    $manifest = [ordered]@{ schemaVersion = 2 }
    if (-not $OmitReference) {
      $reference = [ordered]@{
        id = $Id
        compatibleVersionRange = $Range
        pinnedVersion = $Pin
        lifecycleCeiling = $Ceiling
      }
      if ($OmitPin) { $reference.Remove('pinnedVersion') }
      $manifest.databasePackageReference = $reference
    }
    $path = Join-Path $Directory 'manifest.json'
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
  }
}

Describe 'Test-DatabasePackageCompatibility' {
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

Describe 'Test-DatabasePackageCompatibility ReleaseBundle v2 offline reference' {
  BeforeEach {
    $dir = New-Item -ItemType Directory -Path (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
    $databaseManifest = New-ManifestFile -Directory $dir.FullName -Ranges @('[1.0.0,2.0.0)')
  }

  It 'accepts the exact pinned package within range and lifecycle ceiling' {
    $bundle = New-ReleaseBundleV2File -Directory $dir.FullName
    $result = Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion '1.5.0' -DatabasePackageLifecycleTier 'database-integration'
    $result.IsCompatible | Should -BeTrue
    $result.Mode | Should -BeExactly 'ReleaseBundleV2'
    $result.DatabasePackageId | Should -BeExactly 'ATAPUtilities.Database'
    $result.PinnedVersion | Should -BeExactly '1.5.0'
  }

  It 'accepts an exact NuGet range' {
    $bundle = New-ReleaseBundleV2File -Directory $dir.FullName -Range '[1.5.0]'
    (Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion '1.5.0' -DatabasePackageLifecycleTier 'database-stable').IsCompatible | Should -BeTrue
  }

  It 'fails closed when the database package is absent' {
    $bundle = New-ReleaseBundleV2File -Directory $dir.FullName
    { Test-DatabasePackageCompatibility -DatabasePackageManifestPath (Join-Path $dir 'absent.json') `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion '1.5.0' -DatabasePackageLifecycleTier 'database-stable' } |
      Should -Throw -ExpectedMessage 'ATAPBUILD015:*'
  }

  It 'fails closed when the v2 reference is absent' {
    $bundle = New-ReleaseBundleV2File -Directory $dir.FullName -OmitReference
    { Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion '1.5.0' -DatabasePackageLifecycleTier 'database-stable' } |
      Should -Throw -ExpectedMessage 'ATAPBUILD015:*'
  }

  It 'fails closed for wrong or case-only package identity <Id>' -TestCases @(
    @{ Id = 'Other.Database' }
    @{ Id = 'ataputilities.database' }
  ) {
    $bundle = New-ReleaseBundleV2File -Directory $dir.FullName
    { Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId $Id `
      -DatabasePackageVersion '1.5.0' -DatabasePackageLifecycleTier 'database-stable' } |
      Should -Throw -ExpectedMessage 'ATAPBUILD015:*'
  }

  It 'fails closed when the pin is absent' {
    $bundle = New-ReleaseBundleV2File -Directory $dir.FullName -OmitPin
    { Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion '1.5.0' -DatabasePackageLifecycleTier 'database-stable' } |
      Should -Throw -ExpectedMessage 'ATAPBUILD015:*'
  }

  It 'fails closed when the actual version differs from the pin' {
    $bundle = New-ReleaseBundleV2File -Directory $dir.FullName
    { Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion '1.5.1' -DatabasePackageLifecycleTier 'database-stable' } |
      Should -Throw -ExpectedMessage 'ATAPBUILD015:*'
  }

  It 'fails closed when the pinned version is outside the compatible range' {
    $bundle = New-ReleaseBundleV2File -Directory $dir.FullName -Range '[1.4.0,1.5.0)'
    { Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion '1.5.0' -DatabasePackageLifecycleTier 'database-stable' } |
      Should -Throw -ExpectedMessage 'ATAPBUILD015:*'
  }

  It 'fails closed for a malformed range' {
    $bundle = New-ReleaseBundleV2File -Directory $dir.FullName -Range '[NOTVALID]'
    { Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion '1.5.0' -DatabasePackageLifecycleTier 'database-stable' } |
      Should -Throw -ExpectedMessage 'ATAPBUILD015:*'
  }

  It 'fails closed when lifecycle tier exceeds the declared ceiling' {
    $bundle = New-ReleaseBundleV2File -Directory $dir.FullName -Ceiling 'database-qa'
    { Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion '1.5.0' -DatabasePackageLifecycleTier 'database-stable' } |
      Should -Throw -ExpectedMessage 'ATAPBUILD015:*'
  }

  It 'accepts a lower lifecycle tier under the declared ceiling' {
    $bundle = New-ReleaseBundleV2File -Directory $dir.FullName -Ceiling 'database-qa'
    (Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion '1.5.0' -DatabasePackageLifecycleTier 'database-development').IsCompatible | Should -BeTrue
  }

  It 'rejects ordinary schema v1 compatibility input' {
    $bundle = New-ReleaseBundleV2File -Directory $dir.FullName
    $data = Get-Content -LiteralPath $bundle -Raw | ConvertFrom-Json
    $data.schemaVersion = 1
    $data | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $bundle -Encoding UTF8
    { Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion '1.5.0' -DatabasePackageLifecycleTier 'database-stable' } |
      Should -Throw -ExpectedMessage 'ATAPBUILD015:*'
  }

  It 'contains no network feed Flyway or database mutation command' {
    $source = Get-Content -LiteralPath (Join-Path $moduleRoot 'public\Test-DatabasePackageCompatibility.ps1') -Raw
    $source | Should -Not -Match 'Invoke-RestMethod|Invoke-WebRequest|dotnet|Flyway|ProGet|Invoke-Sqlcmd|Invoke-DbaQuery'
  }
}
Describe 'Test-DatabasePackageCompatibility ReleaseBundle v2 canonical adversarial inputs' {
  BeforeEach {
    $dir = New-Item -ItemType Directory -Path (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
    $databaseManifest = New-ManifestFile -Directory $dir.FullName -Ranges @('[1.0.0,2.0.0)')
    $bundle = New-ReleaseBundleV2File -Directory $dir.FullName
  }

  It 'rejects noncanonical candidate version <Version>' -TestCases @(
    @{ Version = '1.5' }
    @{ Version = '01.5.0' }
  ) {
    { Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion $Version -DatabasePackageLifecycleTier 'database-stable' } |
      Should -Throw -ExpectedMessage 'ATAPBUILD015:*'
  }

  It 'rejects a noncanonical pin' {
    $bundle = New-ReleaseBundleV2File -Directory $dir.FullName -Pin '1.5'
    { Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion '1.5.0' -DatabasePackageLifecycleTier 'database-stable' } |
      Should -Throw -ExpectedMessage 'ATAPBUILD015:*'
  }

  It 'rejects an arbitrary database manifest without schemaVersion 2' {
    '{}' | Set-Content -LiteralPath $databaseManifest -Encoding UTF8
    { Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion '1.5.0' -DatabasePackageLifecycleTier 'database-stable' } |
      Should -Throw -ExpectedMessage 'ATAPBUILD015:*'
  }

  It 'rejects a string ReleaseBundle schemaVersion' {
    $data = Get-Content -LiteralPath $bundle -Raw | ConvertFrom-Json
    $data.schemaVersion = '2'
    $data | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $bundle -Encoding UTF8
    { Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion '1.5.0' -DatabasePackageLifecycleTier 'database-stable' } |
      Should -Throw -ExpectedMessage 'ATAPBUILD015:*'
  }

  It 'rejects a noncanonical lifecycle candidate' {
    { Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion '1.5.0' -DatabasePackageLifecycleTier 'DATABASE-STABLE' } |
      Should -Throw -ExpectedMessage 'ATAPBUILD015:*'
  }

  It 'rejects a noncanonical lifecycle ceiling' {
    $bundle = New-ReleaseBundleV2File -Directory $dir.FullName -Ceiling 'DATABASE-QA'
    { Test-DatabasePackageCompatibility -DatabasePackageManifestPath $databaseManifest `
      -ReleaseBundleManifestPath $bundle -DatabasePackageId 'ATAPUtilities.Database' `
      -DatabasePackageVersion '1.5.0' -DatabasePackageLifecycleTier 'database-qa' } |
      Should -Throw -ExpectedMessage 'ATAPBUILD015:*'
  }
}
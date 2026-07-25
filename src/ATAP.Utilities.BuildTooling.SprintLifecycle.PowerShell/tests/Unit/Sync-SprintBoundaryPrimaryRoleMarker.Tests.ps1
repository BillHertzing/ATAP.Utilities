Describe 'Sync-SprintBoundaryPrimaryRoleMarker' {
  BeforeAll {
    $rootModulePath = Join-Path $PSScriptRoot '..\..\ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell.psm1'
    Import-Module $rootModulePath -Force
  }

  BeforeEach {
    $testRoot = Join-Path ([IO.Path]::GetTempPath()) "ATAP-BoundaryRole-$([guid]::NewGuid().ToString('N'))"
    $sharedState = Join-Path $testRoot 'Dropbox\ATAP\ParityState'
    $legacyState = Join-Path $testRoot 'ProgramData\ATAP\ParityState'
    $marker = [ordered] @{
      SchemaVersion = 1
      PrimaryRole = 'utat01'
      PlannedAbsence = [ordered] @{
        HostName = 'utat022'
        SinceUtc = '2026-07-14T21:00:00.0000000+00:00'
        Reason = 'first Class A test'
      }
      AuthorizedBy = 'Bill Hertzing'
      JournalEntryId = '11111111-1111-1111-1111-111111111111'
    }
  }

  AfterEach {
    if (Test-Path -LiteralPath $testRoot) {
      Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
  }

  It 'reports NotPresent without creating a shared folder' {
    $result = Sync-SprintBoundaryPrimaryRoleMarker `
      -Boundary Start `
      -SharedStatePath $sharedState `
      -LegacyStatePath $legacyState `
      -Confirm:$false

    $result.Action | Should -Be 'NotPresent'
    $result.Succeeded | Should -BeTrue
    Test-Path -LiteralPath $sharedState | Should -BeFalse
  }

  It 'migrates a lone legacy marker to the shared Dropbox state path' {
    New-Item -ItemType Directory -Path $legacyState -Force | Out-Null
    $marker | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $legacyState 'PrimaryRole.json') -Encoding utf8

    $result = Sync-SprintBoundaryPrimaryRoleMarker `
      -Boundary Start `
      -SharedStatePath $sharedState `
      -LegacyStatePath $legacyState `
      -Confirm:$false

    $result.Action | Should -Be 'MigratedLegacy'
    Test-Path -LiteralPath (Join-Path $sharedState 'PrimaryRole.json') | Should -BeTrue
    (Get-Content -LiteralPath (Join-Path $sharedState 'PrimaryRole.json') -Raw | ConvertFrom-Json).PrimaryRole | Should -Be 'utat01'
  }

  It 'verifies an existing shared marker without rewriting it' {
    New-Item -ItemType Directory -Path $sharedState -Force | Out-Null
    $sharedMarkerPath = Join-Path $sharedState 'PrimaryRole.json'
    $marker | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $sharedMarkerPath -Encoding utf8
    $beforeHash = (Get-FileHash -LiteralPath $sharedMarkerPath -Algorithm SHA256).Hash

    $result = Sync-SprintBoundaryPrimaryRoleMarker `
      -Boundary End `
      -SharedStatePath $sharedState `
      -LegacyStatePath $legacyState `
      -Confirm:$false

    $result.Action | Should -Be 'SharedVerified'
    (Get-FileHash -LiteralPath $sharedMarkerPath -Algorithm SHA256).Hash | Should -Be $beforeHash
  }

  It 'refuses differing shared and legacy markers' {
    New-Item -ItemType Directory -Path $sharedState, $legacyState -Force | Out-Null
    $marker | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $sharedState 'PrimaryRole.json') -Encoding utf8
    $legacyMarker = $marker | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $legacyMarker.PrimaryRole = 'utat022'
    $legacyMarker.PlannedAbsence = $null
    $legacyMarker | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $legacyState 'PrimaryRole.json') -Encoding utf8

    {
      Sync-SprintBoundaryPrimaryRoleMarker `
        -Boundary Start `
        -SharedStatePath $sharedState `
        -LegacyStatePath $legacyState `
        -Confirm:$false
    } | Should -Throw '*markers differ*'
  }

  It 'rejects an incomplete shared marker at a sprint boundary' {
    New-Item -ItemType Directory -Path $sharedState -Force | Out-Null
    [ordered]@{ SchemaVersion = 1; PrimaryRole = 'utat01' } |
      ConvertTo-Json |
      Set-Content -LiteralPath (Join-Path $sharedState 'PrimaryRole.json') -Encoding utf8

    {
      Sync-SprintBoundaryPrimaryRoleMarker `
        -Boundary End `
        -SharedStatePath $sharedState `
        -LegacyStatePath $legacyState `
        -Confirm:$false
    } | Should -Throw '*missing required property*'
  }

  It 'previews legacy migration without writing under WhatIf' {
    New-Item -ItemType Directory -Path $legacyState -Force | Out-Null
    $marker | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $legacyState 'PrimaryRole.json') -Encoding utf8

    $result = Sync-SprintBoundaryPrimaryRoleMarker `
      -Boundary Start `
      -SharedStatePath $sharedState `
      -LegacyStatePath $legacyState `
      -WhatIf

    $result.Action | Should -Be 'WhatIfMigrateLegacy'
    Test-Path -LiteralPath (Join-Path $sharedState 'PrimaryRole.json') | Should -BeFalse
  }
}

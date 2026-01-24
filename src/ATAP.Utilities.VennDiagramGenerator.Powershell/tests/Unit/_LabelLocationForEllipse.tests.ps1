## Pester v5.7.1 test suite for _LabelLocationForEllipse
# Save next to _LabelLocationForEllipse.ps1 (or adjust the import path below)
# Run with:  Invoke-Pester -Path .\_LabelLocationForEllipse.Tests.ps1
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.7.1' }

BeforeAll {
  # Dot‑source the function under test. Adjust path if the layout differs.
  $functionPath = Join-Path $PSScriptRoot '..' '..', 'private', '_LabelLocationForEllipse.ps1'
  . $functionPath
  # ToDo: Remove this when packaging works
  if (-not (Get-Command -Name 'Get-ClonedAndModifiedHashtable' -CommandType Function -ErrorAction SilentlyContinue)) {
    . "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ClonedAndModifiedHashtable.ps1"
  }


  # Convenience: full parameter set used across tests
  $AllParams = [ordered]@{
    XCenterEllipseCoordinate = 0
    YCenterEllipseCoordinate = 0
    XEllipseRadius           = 5
    YEllipseRadius           = 3
    LabelAngle               = 0   # will be overwritten per test
    LabelDistance            = 2
  }
}

Describe '_LabelLocationForEllipse geometry' {

  Context 'Cardinal angles' {
    $angles = @{ "0" = @{ ExpectedX = 7; ExpectedY = 0 }
      "90"           = @{ ExpectedX = 0; ExpectedY = 5 }
      "180"          = @{ ExpectedX = -7; ExpectedY = 0 }
      "270"          = @{ ExpectedX = 0; ExpectedY = -5 }
    }

    It 'returns correct X & Y for <Angle>°' -ForEach @($angles.GetEnumerator()) {
      param($Entry)

      $params = Get-ClonedAndModifiedHashtable $AllParams
      $params.LabelAngle = [int]$Entry.Key

      $result = _LabelLocationForEllipse @params -Confirm:$false

      $result.Success     | Should -BeTrue
      $result.XCoordinate | Should -Be $Entry.Value.ExpectedX
      $result.YCoordinate | Should -BeCloseTo $Entry.Value.ExpectedY 0.001

    }
  }

  Context 'Arbitrary position' {
    It 'returns correct X and Y for 45° with custom centre/radii' {
      $result = _LabelLocationForEllipse -XCenterEllipseCoordinate 10 -YCenterEllipseCoordinate -4 -XEllipseRadius 8 -YEllipseRadius 4 -LabelAngle 45 -LabelDistance 1 -Confirm:$false

      # Calculate expected values independently (same formula the cmdlet uses)
      $theta = 45 * [Math]::PI / 180
      $expectedXEdge = 10 + 8 * [Math]::Cos($theta)
      $expectedYEdge = -4 + 4 * [Math]::Sin($theta)
      $expectedX = [double]::Round($expectedXEdge + 1 * [Math]::Cos($theta), 3)
      $expectedY = [double]::Round($expectedYEdge + 1 * [Math]::Sin($theta), 3)

      $result.XCoordinate | Should -BeCloseTo $expectedX -Tolerance 0.001
      $result.YCoordinate | Should -BeCloseTo $expectedY -Tolerance 0.001
    }
  }

  Context 'Parameter validation (all parameters mandatory)' {
    # Generate a test case for each parameter omitted
    $missingCases = $AllParams.Keys | ForEach-Object { @{ Missing = $_ } }

    It 'throws when <Missing> is missing' -TestCases $missingCases {
      param($Missing)

      $params = Get-ClonedAndModifiedHashtable $AllParams
      $params.Remove($Missing)

      { _LabelLocationForEllipse @params -Confirm:$false } | Should -Throw
    }
  }
}

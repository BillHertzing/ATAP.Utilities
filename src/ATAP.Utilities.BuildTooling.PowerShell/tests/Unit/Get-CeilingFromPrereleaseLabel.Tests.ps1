#Requires -Version 7.0

BeforeAll {
  $script:privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'private'
  . (Join-Path $script:privateDir 'Get-CeilingFromPrereleaseLabel.ps1')
}

Describe 'Get-CeilingFromPrereleaseLabel' -Tag 'Unit' {

  Context 'Known labels return correct ceiling' {
    $cases = @(
      @{ Label = 'Alpha';   Expected = 'Development'  }
      @{ Label = 'Beta';    Expected = 'Integration'  }
      @{ Label = 'QA';      Expected = 'QA'           }
    )

    It "Maps '<Label>' to '<Expected>'" -TestCases $cases {
      param($Label, $Expected)
      Get-CeilingFromPrereleaseLabel -PrereleaseLabel $Label | Should -Be $Expected
    }
  }

  Context 'Sprint and feature labels resolve to Experimental' {
    $cases = @(
      @{ Label = 'Sprint'           }
      @{ Label = 'Sprint.42'        }
      @{ Label = 'Sprint42'         }
      @{ Label = 'PaymentRefactor'  }
      @{ Label = 'Canary'           }
      @{ Label = 'Preview'          }
      @{ Label = 'Sprnit'           }
    )

    It "Maps '<Label>' to Experimental" -TestCases $cases {
      param($Label)
      Get-CeilingFromPrereleaseLabel -PrereleaseLabel $Label | Should -Be 'Experimental'
    }
  }

  Context 'Numeric suffix is stripped before mapping' {
    $cases = @(
      @{ Label = 'Alpha7';   Expected = 'Development' }
      @{ Label = 'Alpha.7';  Expected = 'Development' }
      @{ Label = 'Beta123';  Expected = 'Integration' }
      @{ Label = 'QA001';    Expected = 'QA'          }
    )

    It "Strips suffix from '<Label>' and maps to '<Expected>'" -TestCases $cases {
      param($Label, $Expected)
      Get-CeilingFromPrereleaseLabel -PrereleaseLabel $Label | Should -Be $Expected
    }
  }

  Context 'Case-insensitive mapping' {
    $cases = @(
      @{ Label = 'alpha';   Expected = 'Development' }
      @{ Label = 'ALPHA';   Expected = 'Development' }
      @{ Label = 'bEtA';    Expected = 'Integration' }
      @{ Label = 'qa';      Expected = 'QA'          }
    )

    It "Accepts '<Label>' case-insensitively and returns '<Expected>'" -TestCases $cases {
      param($Label, $Expected)
      Get-CeilingFromPrereleaseLabel -PrereleaseLabel $Label | Should -Be $Expected
    }
  }

  Context 'Empty or null label means Production ceiling' {
    It 'Returns Production for null label' {
      Get-CeilingFromPrereleaseLabel -PrereleaseLabel $null | Should -Be 'Production'
    }

    It 'Returns Production for empty string' {
      Get-CeilingFromPrereleaseLabel -PrereleaseLabel '' | Should -Be 'Production'
    }

    It 'Returns Production for whitespace-only string' {
      Get-CeilingFromPrereleaseLabel -PrereleaseLabel '   ' | Should -Be 'Production'
    }
  }

  Context 'Leading hyphen is stripped before mapping' {
    It 'Strips leading hyphen from -Alpha.3 and returns Development' {
      Get-CeilingFromPrereleaseLabel -PrereleaseLabel '-Alpha.3' | Should -Be 'Development'
    }
  }

  Context 'NBGV height-0 git-hash suffix is handled' {
    It 'Strips .gABCDEF from Alpha.0.g1a2b3c4 and returns Development' {
      # The .g{hash} segment is a separate dot-segment; split on . takes only the first
      Get-CeilingFromPrereleaseLabel -PrereleaseLabel 'Alpha.0.g1a2b3c4' | Should -Be 'Development'
    }
  }
}

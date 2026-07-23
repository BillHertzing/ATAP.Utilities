#Requires -Version 7.0

BeforeAll {
  $script:publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $script:publicDir 'Get-CurrentTierFromStage.ps1')
}

Describe 'Get-CurrentTierFromStage' -Tag 'Unit' {

  Context 'Canonical stage names return the expected tier' {
    $cases = @(
      @{ Stage = 'Experimental'; Expected = 'Experimental' }
      @{ Stage = 'Development';  Expected = 'Development'  }
      @{ Stage = 'Integration';  Expected = 'Integration'  }
      @{ Stage = 'QA';           Expected = 'QA'           }
      @{ Stage = 'Production';   Expected = 'Production'   }
    )

    It "Maps stage '<Stage>' to tier '<Expected>'" -TestCases $cases {
      param($Stage, $Expected)
      Get-CurrentTierFromStage -Stage $Stage | Should -Be $Expected
    }
  }

  It 'Accepts Stable as an alias for Production' {
    Get-CurrentTierFromStage -Stage 'Stable' | Should -Be 'Production'
  }

  Context 'Case-insensitive matching' {
    $cases = @(
      @{ Stage = 'experimental'; Expected = 'Experimental' }
      @{ Stage = 'DEVELOPMENT';  Expected = 'Development'  }
      @{ Stage = 'integration';  Expected = 'Integration'  }
      @{ Stage = 'qa';           Expected = 'QA'           }
      @{ Stage = 'production';   Expected = 'Production'   }
      @{ Stage = 'stable';       Expected = 'Production'   }
    )

    It "Normalizes '<Stage>' case and returns '<Expected>'" -TestCases $cases {
      param($Stage, $Expected)
      Get-CurrentTierFromStage -Stage $Stage | Should -Be $Expected
    }
  }

  Context 'Leading and trailing whitespace is ignored' {
    $cases = @(
      @{ Stage = ' Experimental '; Expected = 'Experimental' }
      @{ Stage = '  QA  ';         Expected = 'QA'           }
      @{ Stage = ' Stable ';       Expected = 'Production'   }
    )

    It "Trims whitespace from '<Stage>' and returns '<Expected>'" -TestCases $cases {
      param($Stage, $Expected)
      Get-CurrentTierFromStage -Stage $Stage | Should -Be $Expected
    }
  }

  Context 'Unknown stage names throw' {
    $cases = @(
      @{ Stage = 'Canary'   }
      @{ Stage = 'Preview'  }
      @{ Stage = 'Unknown'  }
    )

    It "Throws for unknown stage '<Stage>'" -TestCases $cases {
      param($Stage)
      { Get-CurrentTierFromStage -Stage $Stage } | Should -Throw -ExpectedMessage "*Unknown BuildMaster stage*"
    }
  }
}

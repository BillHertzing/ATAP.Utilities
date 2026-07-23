#Requires -Version 7.0

BeforeAll {
  $script:publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $script:publicDir 'ConvertTo-BuildPromotionTierName.ps1')
  . (Join-Path $script:publicDir 'Get-TierOrder.ps1')
  . (Join-Path $script:publicDir 'Test-PromotionWithinCeiling.ps1')
}

Describe 'Test-PromotionWithinCeiling' -Tag 'Unit' {
  It 'Returns the canonical ordered tiers' {
    Get-TierOrder | Should -Be @('Experimental', 'Development', 'Integration', 'QA', 'Production')
  }

  Context 'Allowed pairs' {
    $tiers = @('Experimental', 'Development', 'Integration', 'QA', 'Production')
    $cases = foreach ($current in $tiers) {
      foreach ($ceiling in $tiers) {
        if ($tiers.IndexOf($current) -le $tiers.IndexOf($ceiling)) {
          @{ CurrentTier = $current; CeilingTier = $ceiling }
        }
      }
    }

    It "Allows '<CurrentTier>' within '<CeilingTier>'" -TestCases $cases {
      param($CurrentTier, $CeilingTier)
      { Test-PromotionWithinCeiling -CurrentTier $CurrentTier -CeilingTier $CeilingTier } | Should -Not -Throw
      Test-PromotionWithinCeiling -CurrentTier $CurrentTier -CeilingTier $CeilingTier -AsBoolean | Should -BeTrue
    }
  }

  Context 'Rejected pairs' {
    $tiers = @('Experimental', 'Development', 'Integration', 'QA', 'Production')
    $cases = foreach ($current in $tiers) {
      foreach ($ceiling in $tiers) {
        if ($tiers.IndexOf($current) -gt $tiers.IndexOf($ceiling)) {
          @{ CurrentTier = $current; CeilingTier = $ceiling }
        }
      }
    }

    It "Rejects '<CurrentTier>' above '<CeilingTier>'" -TestCases $cases {
      param($CurrentTier, $CeilingTier)
      Test-PromotionWithinCeiling -CurrentTier $CurrentTier -CeilingTier $CeilingTier -AsBoolean | Should -BeFalse

      try {
        Test-PromotionWithinCeiling -CurrentTier $CurrentTier -CeilingTier $CeilingTier
        throw 'Expected Test-PromotionWithinCeiling to throw.'
      } catch {
        $_.FullyQualifiedErrorId | Should -Match '^PromotionCeilingExceededException'
      }
    }
  }

  It 'Accepts Stable as an alias for Production' {
    Test-PromotionWithinCeiling -CurrentTier Stable -CeilingTier Production -AsBoolean | Should -BeTrue
    Test-PromotionWithinCeiling -CurrentTier Production -CeilingTier Stable -AsBoolean | Should -BeTrue
  }

  It 'Throws clearly for unknown tier names' {
    { Test-PromotionWithinCeiling -CurrentTier Canary -CeilingTier QA } | Should -Throw -ExpectedMessage '*Unknown tier*'
  }
}

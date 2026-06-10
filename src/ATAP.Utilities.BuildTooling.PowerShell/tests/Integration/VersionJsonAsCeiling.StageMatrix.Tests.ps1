#Requires -Version 7.0

BeforeAll {
  $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:publicDir = Join-Path $script:moduleRoot 'public'
  $script:privateDir = Join-Path $script:moduleRoot 'private'
  . (Join-Path $script:privateDir 'Get-CeilingFromPrereleaseLabel.ps1')
  . (Join-Path $script:publicDir 'Get-TierOrder.ps1')
  . (Join-Path $script:publicDir 'Test-PromotionWithinCeiling.ps1')
}

Describe 'version.json-as-ceiling stage matrix' -Tag 'Integration' {
  $stageCases = @(
    @{ Label = 'Sprint';          ExpectedCeiling = 'Experimental' }
    @{ Label = 'FeatureSlug';     ExpectedCeiling = 'Experimental' }
    @{ Label = 'Alpha';           ExpectedCeiling = 'Development' }
    @{ Label = 'Beta';            ExpectedCeiling = 'Integration' }
    @{ Label = 'QA';              ExpectedCeiling = 'QA' }
    @{ Label = '';                ExpectedCeiling = 'Production' }
  )

  It "Permits exactly the expected stages for label '<Label>'" -TestCases $stageCases {
    param($Label, $ExpectedCeiling)

    $ceiling = Get-CeilingFromPrereleaseLabel -PrereleaseLabel $Label
    $ceiling | Should -Be $ExpectedCeiling

    $tiers = @(Get-TierOrder)
    $ceilingIndex = $tiers.IndexOf($ceiling)
    foreach ($stage in $tiers) {
      $expectedAllowed = $tiers.IndexOf($stage) -le $ceilingIndex
      Test-PromotionWithinCeiling -CurrentTier $stage -CeilingTier $ceiling -AsBoolean | Should -Be $expectedAllowed
    }
  }
}

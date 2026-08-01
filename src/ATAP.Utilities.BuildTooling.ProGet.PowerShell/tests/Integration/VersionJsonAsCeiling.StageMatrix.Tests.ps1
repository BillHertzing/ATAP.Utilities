#Requires -Version 7.0

BeforeAll {
  $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:publicDir = Join-Path $script:moduleRoot 'public'
  . (Join-Path $script:publicDir 'ConvertTo-BuildPromotionTierName.ps1')
  . (Join-Path $script:publicDir 'Get-TierFromNBGVLabel.ps1')
  . (Join-Path $script:publicDir 'Get-TierOrder.ps1')
  . (Join-Path $script:publicDir 'Test-PromotionWithinCeiling.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
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

    $ceiling = (Get-TierFromNBGVLabel -PrereleaseLabel $Label).TierName
    $ceiling | Should -Be $ExpectedCeiling

    $tiers = @(Get-TierOrder)
    $ceilingIndex = $tiers.IndexOf($ceiling)
    foreach ($stage in $tiers) {
      $expectedAllowed = $tiers.IndexOf($stage) -le $ceilingIndex
      Test-PromotionWithinCeiling -CurrentTier $stage -CeilingTier $ceiling -AsBoolean | Should -Be $expectedAllowed
    }
  }
}

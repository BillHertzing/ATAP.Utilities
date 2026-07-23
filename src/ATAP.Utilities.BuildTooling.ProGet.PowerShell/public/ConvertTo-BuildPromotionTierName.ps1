#Requires -Version 7.0
function ConvertTo-BuildPromotionTierName {
  <#
  .SYNOPSIS
    Converts a promotion tier or supported alias to its canonical tier name.

  .DESCRIPTION
    Normalizes promotion tier names for comparisons. Stable is accepted as
    the ProGet feed alias for the canonical Production tier.

  .PARAMETER Tier
    Tier name to normalize.

  .OUTPUTS
    [string] The canonical promotion tier name.

  .EXAMPLE
    ConvertTo-BuildPromotionTierName -Tier Stable
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Tier
  )

  switch ($Tier.Trim().ToLowerInvariant()) {
    'experimental' { return 'Experimental' }
    'development'  { return 'Development' }
    'integration'  { return 'Integration' }
    'qa'           { return 'QA' }
    'production'   { return 'Production' }
    'stable'       { return 'Production' }
    default {
      throw "Unknown tier '$Tier'. Expected one of: Experimental, Development, Integration, QA, Production, Stable."
    }
  }
}

#Requires -Version 7.0
function Get-TierOrder {
  <#
.SYNOPSIS
    Returns the canonical ordered promotion tiers.

.DESCRIPTION
    This is the shared tier ordering for ceiling checks. Lower indexes are
    lower tiers. The final tier is named Production to match the BuildMaster
    stage name used by the current .otter plans; Stable is accepted as an
    alias by Test-PromotionWithinCeiling.

.OUTPUTS
    [string[]] Experimental, Development, Integration, QA, Production.

.EXAMPLE
    PS> Get-TierOrder
    Experimental
    Development
    Integration
    QA
    Production
#>
  [CmdletBinding()]
  [OutputType([string[]])]
  param()

  return @('Experimental', 'Development', 'Integration', 'QA', 'Production')
}

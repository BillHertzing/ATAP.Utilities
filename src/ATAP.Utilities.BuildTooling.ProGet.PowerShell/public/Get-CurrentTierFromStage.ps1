#Requires -Version 7.0
function Get-CurrentTierFromStage {
  <#
  .SYNOPSIS
    Maps a BuildMaster stage name to the canonical current tier name.

.DESCRIPTION
    BuildMaster stage names answer "where is this pipeline executing now?"
    They are separate from the NBGV prerelease label, which is interpreted as
    a promotion ceiling. This helper trims and case-normalizes stage names and
    accepts Stable as an alias for the Production stage.

.PARAMETER Stage
    BuildMaster stage name. Expected values are Experimental, Development,
    Integration, QA, Production, or Stable.

.OUTPUTS
    [string] The canonical current tier.
#>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Stage
  )

  $normalized = $Stage.Trim()
  switch ($normalized.ToLowerInvariant()) {
    'experimental' { return 'Experimental' }
    'development'  { return 'Development' }
    'integration'  { return 'Integration' }
    'qa'           { return 'QA' }
    'production'   { return 'Production' }
    'stable'       { return 'Production' }
    default {
      throw "Unknown BuildMaster stage '$Stage'. Expected one of: Experimental, Development, Integration, QA, Production, Stable."
    }
  }
}

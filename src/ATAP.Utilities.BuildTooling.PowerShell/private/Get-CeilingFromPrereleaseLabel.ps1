#Requires -Version 7.0
function Get-CeilingFromPrereleaseLabel {
  <#
.SYNOPSIS
    Maps an NBGV prerelease label to the highest promotion tier allowed for
    the current pipeline run.

.DESCRIPTION
    This helper implements the version.json-as-ceiling rule. The prerelease
    label is stable for a pipeline run and answers "how high may this artifact
    be promoted?" It does not answer "which stage is executing now?"

    Mapping:
      - Sprint / feature labels / unknown labels -> Experimental
      - Alpha -> Development
      - Beta -> Integration
      - QA -> QA
      - empty / null -> Production

.PARAMETER PrereleaseLabel
    The prerelease label parsed from NBGV. Full prerelease segments such as
    Alpha.7 or Alpha7 are also accepted and normalized.

.OUTPUTS
    [string] The canonical ceiling tier.
#>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [AllowNull()]
    [string]$PrereleaseLabel
  )

  if ($null -eq $PrereleaseLabel -or [string]::IsNullOrWhiteSpace($PrereleaseLabel)) {
    return 'Production'
  }

  $normalized = $PrereleaseLabel.Trim().TrimStart('-')
  $normalized = ($normalized -split '\.')[0]
  $normalized = $normalized -replace '\d+$', ''

  switch ($normalized.ToLowerInvariant()) {
    'alpha' { return 'Development' }
    'beta'  { return 'Integration' }
    'qa'    { return 'QA' }
    default { return 'Experimental' }
  }
}

#Requires -Version 7.0
function ConvertTo-BuildPromotionTierName {
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

function Test-PromotionWithinCeiling {
  <#
.SYNOPSIS
    Tests whether a stage or destination tier is within a promotion ceiling.

.DESCRIPTION
    The version.json prerelease label defines CeilingTier, the highest tier a
    single pipeline run may reach. BuildMaster's stage context defines the
    current tier. This cmdlet compares the two values using Get-TierOrder.

    By default, exceeding the ceiling throws a terminating error with the
    FullyQualifiedErrorId PromotionCeilingExceededException. With -AsBoolean,
    the cmdlet returns $true or $false and does not throw for ceiling
    violations.

.PARAMETER CurrentTier
    The current stage tier or promotion destination tier.

.PARAMETER CeilingTier
    The highest tier this pipeline run may reach.

.PARAMETER AsBoolean
    Return a boolean instead of throwing on a ceiling violation.

.OUTPUTS
    [bool]

.EXAMPLE
    Test-PromotionWithinCeiling -CurrentTier Integration -CeilingTier Beta

.EXAMPLE
    Test-PromotionWithinCeiling -CurrentTier QA -CeilingTier Integration -AsBoolean
#>
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$CurrentTier,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$CeilingTier,

    [switch]$AsBoolean
  )

  if (-not (Get-Command -Name 'Get-TierOrder' -CommandType Function -ErrorAction SilentlyContinue)) {
    $helperPath = Join-Path $PSScriptRoot 'Get-TierOrder.ps1'
    if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
      . $helperPath
    } else {
      throw "Required helper Get-TierOrder was not found at '$helperPath'."
    }
  }

  $currentCanonical = ConvertTo-BuildPromotionTierName -Tier $CurrentTier
  $ceilingCanonical = ConvertTo-BuildPromotionTierName -Tier $CeilingTier
  $tierOrder = @(Get-TierOrder)

  $currentIndex = $tierOrder.IndexOf($currentCanonical)
  $ceilingIndex = $tierOrder.IndexOf($ceilingCanonical)
  $allowed = $currentIndex -le $ceilingIndex

  if ($AsBoolean) {
    return [bool]$allowed
  }

  if (-not $allowed) {
    $message = "Promotion ceiling exceeded: current tier '$currentCanonical' is above ceiling tier '$ceilingCanonical'."
    $exception = [System.InvalidOperationException]::new($message)
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
      $exception,
      'PromotionCeilingExceededException',
      [System.Management.Automation.ErrorCategory]::PermissionDenied,
      [PSCustomObject]@{
        CurrentTier = $currentCanonical
        CeilingTier = $ceilingCanonical
      }
    )
    $PSCmdlet.ThrowTerminatingError($errorRecord)
  }

  return $true
}

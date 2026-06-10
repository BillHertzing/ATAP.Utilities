#Requires -Version 7.0
<#
.SYNOPSIS
    Returns the canonical ProGet `database-*` feed name for a given environment tier.

.DESCRIPTION
    The database change package pipeline ships packages through five
    canonical feeds — `database-experimental`, `database-development`,
    `database-integration`, `database-qa`, `database-stable`. A consumer
    (deployment job, rehearsal harness, developer script) targeting a
    particular environment tier must pull only from the feed that matches
    its tier.

    Resolve-DatabasePackageFeed maps the tier name (the same vocabulary
    used by BuildMaster pipeline stages and by `version.json` prerelease
    labels) to the canonical feed name. Unknown tiers raise a terminating
    error.

.PARAMETER Tier
    The environment tier. One of `Experimental`, `Development`,
    `Integration`, `QA`, `Production`. Production maps to `database-stable`.

.OUTPUTS
    [string] — The canonical feed name (e.g. `database-experimental`).

.EXAMPLE
    PS> Resolve-DatabasePackageFeed -Tier Integration
    database-integration

.EXAMPLE
    PS> Resolve-DatabasePackageFeed -Tier Production
    database-stable

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Task: TASKS_V4-DBA2.md DBA2-T05 / V4-E11.

.LINK
    Database-Package-Consumer-Resolution.md
#>
function Resolve-DatabasePackageFeed {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
    [string]$Tier
  )

  begin {
    $fn = 'Resolve-DatabasePackageFeed'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Entering $fn with Tier='$Tier'" -Tag 'Trace'
  }

  process {
    $feed = switch ($Tier) {
      'Experimental' { 'database-experimental' }
      'Development'  { 'database-development' }
      'Integration'  { 'database-integration' }
      'QA'           { 'database-qa' }
      'Production'   { 'database-stable' }
      default {
        $msg = "${fn}: Unknown tier '$Tier'. Valid values: Experimental, Development, Integration, QA, Production."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Tier '$Tier' resolves to feed '$feed'." -Tag 'Trace'
    return $feed
  }
}

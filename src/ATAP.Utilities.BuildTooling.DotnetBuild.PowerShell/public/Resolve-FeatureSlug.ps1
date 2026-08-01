#Requires -Version 7.0
function Resolve-FeatureSlug {
  <#
.SYNOPSIS
    Resolves a Git feature-branch name into the PascalCase `$FeatureSlug` used
    by the BuildMaster pipeline.

.DESCRIPTION
    Implements the slug derivation rule E-DEC-01 documented in
    `SolutionDocumentation/Long-Developing-Features.md` §2:

      1. The branch name MUST start with `feature/`. If it does not, the
         cmdlet returns `$null` so that callers (notably `Get-BuildContext`)
         can treat the input as a non-feature branch without exception.
      2. The text after `feature/` is split on `[-_/]+`. Each non-empty
         component is converted to PascalCase (first letter upper-cased,
         remainder lower-cased) and the components are concatenated with
         no separator.
      3. The resulting string is unconditionally truncated to at most 16
         characters so the prerelease label fits the SemVer-2.0 budget
         documented in §2.

    The cmdlet is a pure function: it makes no external calls, has no
    side effects, and is safe to call from any context.

    A `-DeveloperOffset <int>` parameter is accepted for forward
    compatibility (per V3 plan §13 critique C1.4). It is intentionally
    ignored by the current implementation. Once the team grows past three
    developers working concurrently on a single feature, the slug
    derivation will be extended to encode a per-developer offset that
    avoids NBGV height collisions; this parameter exists today so callers
    can already pass the value without a future signature change.

.PARAMETER BranchName
    The Git branch name (for example, `feature/payment-refactor`). Returns
    `$null` for any branch name that does not start with `feature/`.

.PARAMETER DeveloperOffset
    Forward-compatibility parameter. Defaults to 0. Currently ignored by
    the slug computation. Reserved for the multi-developer collision
    mitigation described in `Long-Developing-Features.md §2`.

.INPUTS
    None. The cmdlet does not accept pipeline input.

.OUTPUTS
    [string] PascalCase slug, truncated to at most 16 characters.
    [string] `$null` when `BranchName` does not start with `feature/`.

.EXAMPLE
    PS> Resolve-FeatureSlug -BranchName 'feature/payment-refactor'
    PaymentRefactor

.EXAMPLE
    PS> Resolve-FeatureSlug -BranchName 'feature/long-running-auth-overhaul'
    LongRunningAuth

.EXAMPLE
    PS> Resolve-FeatureSlug -BranchName 'feature/db-schema-v2'
    DbSchemaV2

.EXAMPLE
    PS> Resolve-FeatureSlug -BranchName 'sprint/0007-work-items'
    # Returns $null — non-feature branches have no slug.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Implements E-DEC-01 from Long-Developing-Features.md §2.

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$BranchName,

    [Parameter(Mandatory = $false)]
    [int]$DeveloperOffset = 0
  )

  begin {
    $fn = 'Resolve-FeatureSlug'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with BranchName='$BranchName' DeveloperOffset=$DeveloperOffset" -Tag 'Trace'
  }

  process {
    if ([string]::IsNullOrWhiteSpace($BranchName)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'BranchName is null/empty; returning $null'
      return $null
    }

    if ($BranchName -notmatch '^feature/(.+)$') {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "BranchName '$BranchName' does not start with 'feature/'; returning `$null"
      return $null
    }

    $rest = $Matches[1]

    # Split on hyphen, underscore, or forward slash; drop empties.
    $words = $rest -split '[-_/]+' | Where-Object { -not [string]::IsNullOrEmpty($_) }
    if ($null -eq $words -or @($words).Count -eq 0) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Feature branch '$BranchName' has no usable components after the 'feature/' prefix; returning `$null"
      return $null
    }

    $pascal = ''
    foreach ($w in $words) {
      $first = $w.Substring(0, 1).ToUpperInvariant()
      if ($w.Length -gt 1) {
        $rest2 = $w.Substring(1).ToLowerInvariant()
      } else {
        $rest2 = ''
      }
      $pascal += ($first + $rest2)
    }

    if ($pascal.Length -gt 16) {
      $pascal = $pascal.Substring(0, 16)
    }

    # Defensive post-check — truncation above is unconditional, but the
    # plan instructs us to be explicit in case a future maintainer
    # changes the logic.
    if ($pascal.Length -gt 16) {
      $msg = "Resolve-FeatureSlug produced a slug longer than 16 characters ('$pascal') from BranchName '$BranchName'. This should be impossible; investigate."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Resolved BranchName '$BranchName' to slug '$pascal'"
    return [string]$pascal
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}

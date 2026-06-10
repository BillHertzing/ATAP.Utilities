#Requires -Version 7.0
function Resolve-DbInstanceName {
  <#
.SYNOPSIS
    Resolves a SQL Server database instance name for one of the seven
    canonical DB instance kinds defined in `Database-Change-Unit-and-Flyway-Promotion.md` §5.

.DESCRIPTION
    Pure function. Takes an `-Application` name, a `-Kind` enum, and the
    optional `-GitHandle` / `-FeatureSlug` parameters required by some
    Kinds, and returns the canonical DB name per the §5 naming table:

    | Kind                 | Pattern                                   |
    |----------------------|-------------------------------------------|
    | developer-scratch    | <App>-dev-<GitHandle>                     |
    | feature-sprint       | <App>-<FeatureSlug>-<GitHandle>           |
    | feature-shared       | <App>-<FeatureSlug>-shared                |
    | trunk-dev            | <App>-dev                                 |
    | trunk-integration    | <App>-integration                         |
    | trunk-qa             | <App>-qa                                  |
    | customer-production  | <App>                                     |

    Per §5.1, the cmdlet enforces:
      - Total length ≤ 64 characters (throws if exceeded).
      - GitHandle truncated to 12 characters; lowercased for consistency.
      - FeatureSlug must be ≤ 16 characters (Resolve-FeatureSlug already
        guarantees this, but the input is re-checked defensively).
      - Hyphens-only delimiter rule: Application, GitHandle, and FeatureSlug
        must not contain '_' or '.' characters (the cmdlet would otherwise
        propagate them into the DB name).

    No I/O. No external calls. No side effects. The result feeds every
    other cmdlet in Stream J.

.PARAMETER Application
    The BuildMaster application name (e.g., `AceCommander`,
    `ATAP.Utilities`). Note: an Application name containing a `.` will be
    rejected because the hyphens-only delimiter rule forbids dots in the
    final DB name.

.PARAMETER Kind
    One of the seven instance kinds documented above. Validated via
    ValidateSet; mistyped values fail at parameter binding time.

.PARAMETER GitHandle
    The developer's GitHub handle. Required when `-Kind` is
    `developer-scratch` or `feature-sprint`. Truncated to 12 characters
    and lowercased before being inserted into the DB name.

.PARAMETER FeatureSlug
    The feature slug (PascalCase, already truncated to 16 chars by
    `Resolve-FeatureSlug`). Required when `-Kind` is `feature-sprint` or
    `feature-shared`.

.INPUTS
    None.

.OUTPUTS
    [string] The resolved DB instance name.

.EXAMPLE
    PS> Resolve-DbInstanceName -Application 'AceCommander' -Kind developer-scratch -GitHandle 'wh'
    AceCommander-dev-wh

.EXAMPLE
    PS> Resolve-DbInstanceName -Application 'AceCommander' -Kind feature-sprint `
                              -FeatureSlug 'PaymentRefactor' -GitHandle 'wh'
    AceCommander-PaymentRefactor-wh

.EXAMPLE
    PS> Resolve-DbInstanceName -Application 'AceCommander' -Kind feature-shared `
                              -FeatureSlug 'PaymentRefactor'
    AceCommander-PaymentRefactor-shared

.EXAMPLE
    PS> Resolve-DbInstanceName -Application 'AceCommander' -Kind trunk-dev
    AceCommander-dev

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Implements task J1 of Plan-DocsUpdateForImmutablePackages_V3.md.

.LINK
    Database-Change-Unit-and-Flyway-Promotion.md
#>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Application,

    [Parameter(Mandatory = $true)]
    [ValidateSet(
      'developer-scratch',
      'feature-sprint',
      'feature-shared',
      'trunk-dev',
      'trunk-integration',
      'trunk-qa',
      'customer-production'
    )]
    [string]$Kind,

    [Parameter(Mandatory = $false)]
    [string]$GitHandle,

    [Parameter(Mandatory = $false)]
    [string]$FeatureSlug
  )

  begin {
    $fn = 'Resolve-DbInstanceName'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn (Application='$Application' Kind='$Kind' GitHandle='$GitHandle' FeatureSlug='$FeatureSlug')" -Tag 'Trace'
  }

  process {
    # ---------------------------------------------------------------------
    # 1. Hyphens-only delimiter rule (§5.1): reject inputs containing '_' or '.'.
    # ---------------------------------------------------------------------
    $forbiddenChars = '[_\.]'
    if ($Application -match $forbiddenChars) {
      $msg = "Application '$Application' contains a forbidden delimiter ('_' or '.'); §5.1 requires hyphens only in DB names."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }
    if ($PSBoundParameters.ContainsKey('GitHandle') -and -not [string]::IsNullOrEmpty($GitHandle) -and $GitHandle -match $forbiddenChars) {
      $msg = "GitHandle '$GitHandle' contains a forbidden delimiter ('_' or '.'); §5.1 requires hyphens only in DB names."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }
    if ($PSBoundParameters.ContainsKey('FeatureSlug') -and -not [string]::IsNullOrEmpty($FeatureSlug) -and $FeatureSlug -match $forbiddenChars) {
      $msg = "FeatureSlug '$FeatureSlug' contains a forbidden delimiter ('_' or '.'); §5.1 requires hyphens only in DB names."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    # ---------------------------------------------------------------------
    # 2. Defensive FeatureSlug length cap (Resolve-FeatureSlug enforces 16
    #    but this cmdlet may be called with arbitrary slugs).
    # ---------------------------------------------------------------------
    if (-not [string]::IsNullOrEmpty($FeatureSlug) -and $FeatureSlug.Length -gt 16) {
      $msg = "FeatureSlug '$FeatureSlug' is $($FeatureSlug.Length) characters; §5.1 caps slugs at 16. Truncate via Resolve-FeatureSlug before passing here."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    # ---------------------------------------------------------------------
    # 3. Normalize GitHandle: lowercase + truncate to 12 chars (§5.1).
    # ---------------------------------------------------------------------
    $normalizedHandle = $null
    if (-not [string]::IsNullOrEmpty($GitHandle)) {
      $normalizedHandle = $GitHandle.ToLowerInvariant()
      if ($normalizedHandle.Length -gt 12) {
        $normalizedHandle = $normalizedHandle.Substring(0, 12)
      }
    }

    # ---------------------------------------------------------------------
    # 4. Build the name per the §5 row for the requested Kind, validating
    #    that the required parameters for each Kind are present.
    # ---------------------------------------------------------------------
    $dbName = switch ($Kind) {
      'developer-scratch' {
        if ([string]::IsNullOrEmpty($normalizedHandle)) {
          throw "Kind 'developer-scratch' requires -GitHandle."
        }
        '{0}-dev-{1}' -f $Application, $normalizedHandle
        break
      }
      'feature-sprint' {
        if ([string]::IsNullOrEmpty($FeatureSlug)) {
          throw "Kind 'feature-sprint' requires -FeatureSlug."
        }
        if ([string]::IsNullOrEmpty($normalizedHandle)) {
          throw "Kind 'feature-sprint' requires -GitHandle."
        }
        '{0}-{1}-{2}' -f $Application, $FeatureSlug, $normalizedHandle
        break
      }
      'feature-shared' {
        if ([string]::IsNullOrEmpty($FeatureSlug)) {
          throw "Kind 'feature-shared' requires -FeatureSlug."
        }
        '{0}-{1}-shared' -f $Application, $FeatureSlug
        break
      }
      'trunk-dev'           { '{0}-dev'          -f $Application; break }
      'trunk-integration'   { '{0}-integration'  -f $Application; break }
      'trunk-qa'            { '{0}-qa'           -f $Application; break }
      'customer-production' { $Application;                       break }
    }

    # ---------------------------------------------------------------------
    # 5. Final length check (§5.1 cap at 64 chars).
    # ---------------------------------------------------------------------
    if ($dbName.Length -gt 64) {
      $msg = "Resolved DB name '$dbName' is $($dbName.Length) characters; §5.1 caps total length at 64. Shorten the Application name or use a shorter GitHandle/FeatureSlug."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Resolved DB name '$dbName' for Kind '$Kind'." -Tag 'DbNaming'
    return $dbName
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}

#Requires -Version 7.0
function Get-BuildContext {
  <#
.SYNOPSIS
    Resolves the full build context for a BuildMaster pipeline run from
    either a release tag or a branch name.

.DESCRIPTION
    `Get-BuildContext` is the entry point for every BuildMaster pipeline
    run. It packages together every piece of information later stages
    need so they can read it from one place (the canonical build variable
    `$ResolvedPackageVersion` plus the related metadata documented in
    `Immutable-Build-Strategy.md §6.1`).

    The cmdlet derives:

      - The branch name (either passed in, or resolved from the current
        worktree's `HEAD` via `git symbolic-ref --short HEAD`).
      - The branch type (`stable`, `feature`, `sprint`, `release`) from
        the branch name prefix.
      - The feature slug (PascalCase, ≤16 chars) by calling
        `Resolve-FeatureSlug`. `$null` for non-feature branches.
      - The repository root via `git rev-parse --show-toplevel`.
      - The source commit via `git rev-parse HEAD`.
      - The full NuGet/SemVer package version via
        `nbgv get-version --variable NuGetPackageVersion`, run inside the
        repository root.
      - The major.minor.patch core and the prerelease label, parsed from
        the NBGV output.
      - The intended tier (`Production` / `Development` / `Integration` /
        `QA` / `Experimental`) per the table in
        `Immutable-Build-Strategy.md §6`.
      - Whether DB assets are included, by testing for the existence of
        `db/<Application>/releases/<MajorMinorPatch>.yml`.

    The cmdlet performs no write operations and is therefore not marked
    `SupportsShouldProcess`. All external calls (`git`, `nbgv`) are
    logged via PSFramework at the `Debug` level.

.PARAMETER Application
    The BuildMaster application name (e.g., `ATAP.Utilities`,
    `AceCommander`). Required. Pass-through to the returned context object
    and used to compose the DB-asset path.

.PARAMETER ReleaseTag
    A release tag (e.g., `v1.4.0`). Mutually exclusive with `-Branch`.
    When supplied, the branch name is resolved from `git symbolic-ref
    --short HEAD`. The tag is recorded as `SourceTag` on the output.

.PARAMETER Branch
    An explicit branch name. Mutually exclusive with `-ReleaseTag`. When
    supplied, the branch name is used as-is and `SourceTag` is `$null`.

.INPUTS
    None. The cmdlet does not accept pipeline input.

.OUTPUTS
    [PSCustomObject] with the following fields:
      - `Application`
      - `Branch`
      - `BranchType` — one of `stable`, `feature`, `sprint`, `release`.
      - `FeatureSlug` — `$null` for non-feature branches.
      - `RepoRoot`
      - `SourceTag` — `$null` unless `-ReleaseTag` was supplied.
      - `SourceCommit`
      - `ResolvedPackageVersion`
      - `MajorMinorPatch`
      - `PrereleaseLabel`
      - `Tier` — one of `Production`, `Development`, `Integration`, `QA`,
        `Experimental`.
      - `DbAssetsIncluded` — `[bool]`.

.EXAMPLE
    PS> Get-BuildContext -Application 'ATAP.Utilities' -Branch 'main'

    Returns the build context for the trunk pipeline run.

.EXAMPLE
    PS> Get-BuildContext -Application 'AceCommander' -ReleaseTag 'v1.4.0'

    Returns the build context for a release-tag-driven pipeline run.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Implements task H1 of Plan-DocsUpdateForImmutablePackages_V3.md.

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
  [CmdletBinding(DefaultParameterSetName = 'ByBranch')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Application,

    [Parameter(Mandatory = $true, ParameterSetName = 'ByReleaseTag')]
    [ValidateNotNullOrEmpty()]
    [string]$ReleaseTag,

    [Parameter(Mandatory = $true, ParameterSetName = 'ByBranch')]
    [ValidateNotNullOrEmpty()]
    [string]$Branch
  )

  begin {
    $fn = 'Get-BuildContext'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with Application='$Application' ParameterSetName='$($PSCmdlet.ParameterSetName)'" -Tag 'Trace'
  }

  process {
    # ---------------------------------------------------------------------
    # 1. Resolve repository root via git.
    # ---------------------------------------------------------------------
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Invoking 'git rev-parse --show-toplevel'" -Tag 'GitCall'
    $repoRootRaw = & git rev-parse --show-toplevel 2>&1
    if ($LASTEXITCODE -ne 0) {
      $msg = "git rev-parse --show-toplevel failed: $repoRootRaw"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'GitCall'
      throw $msg
    }
    $repoRoot = ([string]$repoRootRaw).Trim()
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Repository root resolved to '$repoRoot'" -Tag 'GitCall'

    # ---------------------------------------------------------------------
    # 2. Resolve branch name (either passed-in or derived from HEAD).
    # ---------------------------------------------------------------------
    $sourceTag = $null
    if ($PSCmdlet.ParameterSetName -eq 'ByReleaseTag') {
      $sourceTag = $ReleaseTag
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolving branch from HEAD because -ReleaseTag '$ReleaseTag' was supplied" -Tag 'GitCall'
      $branchRaw = & git symbolic-ref --short HEAD 2>&1
      if ($LASTEXITCODE -ne 0) {
        $msg = "git symbolic-ref --short HEAD failed: $branchRaw"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'GitCall'
        throw $msg
      }
      $resolvedBranch = ([string]$branchRaw).Trim()
    } else {
      $resolvedBranch = $Branch
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved branch '$resolvedBranch' (SourceTag='$sourceTag')" -Tag 'GitCall'

    # ---------------------------------------------------------------------
    # 3. Derive branch type.
    # ---------------------------------------------------------------------
    $branchType = switch -Regex ($resolvedBranch) {
      '^feature/' { 'feature'; break }
      '^sprint/'  { 'sprint';  break }
      '^release/' { 'release'; break }
      default     { 'stable' }
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "BranchType derived as '$branchType'"

    # ---------------------------------------------------------------------
    # 4. Derive feature slug (only meaningful for feature branches).
    # ---------------------------------------------------------------------
    if (-not (Get-Command -Name 'Resolve-FeatureSlug' -CommandType Function -ErrorAction SilentlyContinue)) {
      $slugPath = Join-Path $PSScriptRoot 'Resolve-FeatureSlug.ps1'
      if (Test-Path -LiteralPath $slugPath) {
        . $slugPath
      } else {
        $msg = "Resolve-FeatureSlug.ps1 was not found at '$slugPath'. Get-BuildContext depends on it (task H2)."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }
    }
    $featureSlug = Resolve-FeatureSlug -BranchName $resolvedBranch
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "FeatureSlug='$featureSlug'"

    # ---------------------------------------------------------------------
    # 5. Resolve source commit (HEAD SHA).
    # ---------------------------------------------------------------------
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Invoking 'git rev-parse HEAD'" -Tag 'GitCall'
    $headRaw = & git rev-parse HEAD 2>&1
    if ($LASTEXITCODE -ne 0) {
      $msg = "git rev-parse HEAD failed: $headRaw"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'GitCall'
      throw $msg
    }
    $sourceCommit = ([string]$headRaw).Trim()
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "SourceCommit='$sourceCommit'" -Tag 'GitCall'

    # ---------------------------------------------------------------------
    # 6. Resolve NBGV-derived package version.
    # ---------------------------------------------------------------------
    $nbgvCommand = Get-Command -Name 'nbgv' -ErrorAction SilentlyContinue
    if (-not $nbgvCommand) {
      $msg = "The 'nbgv' CLI was not found on PATH. Install it with: dotnet tool install -g nbgv"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'NBGV'
      throw $msg
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Invoking 'nbgv get-version --variable NuGetPackageVersion' in '$repoRoot'" -Tag 'NBGV'
    $pushed = $false
    try {
      Push-Location -LiteralPath $repoRoot
      $pushed = $true
      $nbgvRaw = & nbgv get-version --variable NuGetPackageVersion 2>&1
      $nbgvExit = $LASTEXITCODE
    } finally {
      if ($pushed) { Pop-Location }
    }
    if ($nbgvExit -ne 0) {
      $msg = "nbgv get-version failed with exit code ${nbgvExit}: $nbgvRaw"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'NBGV'
      throw $msg
    }
    $resolvedPackageVersion = ([string]$nbgvRaw).Trim()
    if ([string]::IsNullOrWhiteSpace($resolvedPackageVersion)) {
      $msg = "nbgv returned an empty version string for '$repoRoot'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'NBGV'
      throw $msg
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "ResolvedPackageVersion='$resolvedPackageVersion'" -Tag 'NBGV'

    # ---------------------------------------------------------------------
    # 7. Parse MajorMinorPatch + PrereleaseLabel out of the NBGV output.
    # ---------------------------------------------------------------------
    # Accept optional trailing .Height and optional +metadata (build hash).
    $pattern = '^(?<MMP>\d+\.\d+\.\d+)(?:-(?<Label>[A-Za-z][A-Za-z0-9]*)(?:\.\d+)?(?:\.g[0-9a-f]+)?)?(?:\+[0-9A-Za-z\.-]+)?$'
    if ($resolvedPackageVersion -notmatch $pattern) {
      $msg = "nbgv output '$resolvedPackageVersion' does not match the expected 'Major.Minor.Patch[-Label[.Height]]' pattern."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'NBGV'
      throw $msg
    }
    $majorMinorPatch = $Matches['MMP']
    $prereleaseLabel = if ($Matches.ContainsKey('Label')) { [string]$Matches['Label'] } else { '' }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "MajorMinorPatch='$majorMinorPatch' PrereleaseLabel='$prereleaseLabel'"

    # ---------------------------------------------------------------------
    # 8. Map prerelease label -> Tier per Immutable-Build-Strategy.md §6.
    # ---------------------------------------------------------------------
    $tier = if ([string]::IsNullOrEmpty($prereleaseLabel)) {
      'Production'
    } elseif ($prereleaseLabel -ieq 'Alpha') {
      'Development'
    } elseif ($prereleaseLabel -ieq 'Beta') {
      'Integration'
    } elseif ($prereleaseLabel -ieq 'QA') {
      'QA'
    } else {
      # Sprint, a FeatureSlug, anything else -> Experimental.
      'Experimental'
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Tier='$tier'"

    # ---------------------------------------------------------------------
    # 9. Test for DB assets at the standard path.
    # ---------------------------------------------------------------------
    $dbAssetPath = Join-Path -Path $repoRoot -ChildPath ("db/{0}/releases/{1}.yml" -f $Application, $majorMinorPatch)
    $dbAssetsIncluded = [bool](Test-Path -LiteralPath $dbAssetPath -PathType Leaf)
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "DbAssetsIncluded=$dbAssetsIncluded (path='$dbAssetPath')"

    # ---------------------------------------------------------------------
    # 10. Assemble and return the context object.
    # ---------------------------------------------------------------------
    $context = [PSCustomObject]@{
      Application            = $Application
      Branch                 = $resolvedBranch
      BranchType             = $branchType
      FeatureSlug            = $featureSlug
      RepoRoot               = $repoRoot
      SourceTag              = $sourceTag
      SourceCommit           = $sourceCommit
      ResolvedPackageVersion = $resolvedPackageVersion
      MajorMinorPatch        = $majorMinorPatch
      PrereleaseLabel        = $prereleaseLabel
      Tier                   = $tier
      DbAssetsIncluded       = $dbAssetsIncluded
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Get-BuildContext succeeded: Branch='$resolvedBranch' Tier='$tier' Version='$resolvedPackageVersion'"
    return $context
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}

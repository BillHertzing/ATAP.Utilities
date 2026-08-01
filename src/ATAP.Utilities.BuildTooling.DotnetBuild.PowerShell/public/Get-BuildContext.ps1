#Requires -Version 7.0
function Get-BuildContext {
  <#
.SYNOPSIS
    Resolves the full build context for a BuildMaster pipeline run from
    either a release tag or a branch name, separating current stage tier from
    version-label promotion ceiling.

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
        directory passed as `-ProjectPath`. In this repository every
        shipping C# or PowerShell project owns a project-adjacent
        `version.json` that resets the NBGV height origin to that
        project (see `SolutionDocumentation/CSharp-Packages-Versioning.md`
        §4.5). The repository root does not necessarily carry a
        `version.json`, so nbgv MUST be invoked from the per-project
        directory to obtain the correct package version.
      - The major.minor.patch core and the prerelease label, parsed from
        the NBGV output.
      - The current tier from the BuildMaster stage context (`-Stage`,
        `$env:INEDOSTAGE_NAME`, `$env:BUILDMASTER_STAGE_NAME`, or local
        default `Experimental`).
      - The ceiling tier from the NBGV prerelease label on `version.json`,
        per `Immutable-Build-Strategy.md §3` and
        `SolutionDocumentation/VersionJsonAsCeiling.md`.
      - Whether DB assets are included, by testing for the existence of
        `db/<Application>/releases/<MajorMinorPatch>.yml`. The layout of
        that folder, the per-release YAML manifest schema, and the
        promotion rules for DB change units are documented in
        `SolutionDocumentation/Database-Change-Unit-and-Flyway-Promotion.md`.
        The machine-readable schema for the YAML file lives at
        `SolutionDocumentation/schemas/db-release-unit.schema.yaml`.
        See also `SolutionDocumentation/Immutable-Build-Strategy.md` for
        the broader release-unit promotion model.

    The cmdlet performs no write operations and is therefore not marked
    `SupportsShouldProcess`. All external calls (`git`, `nbgv`) are
    logged via PSFramework at the `Debug` level.

.PARAMETER Application
    The BuildMaster application name (e.g., `ATAP.Utilities`,
    `AceCommander`). Required. Pass-through to the returned context object
    and used to compose the DB-asset path.

.PARAMETER ProjectPath
    The directory of the shipping project, or the path to that project's
    `.csproj`. `nbgv get-version` is invoked from the directory that contains
    the project-adjacent `version.json` so the NBGV height origin matches the
    package being built. The path may be absolute or relative to the current
    working directory; it is resolved to an absolute path on entry. An error
    is thrown if the directory does not exist or does not contain a
    `version.json` file.

.PARAMETER Stage
    Optional BuildMaster stage name. When supplied, it is mapped to
    `CurrentTier`. When omitted, the cmdlet reads `$env:INEDOSTAGE_NAME`,
    then `$env:BUILDMASTER_STAGE_NAME`, and finally falls back to
    `Experimental` for local development and unit tests.

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
      - `ProjectPath` — the absolute, resolved project directory used for
        the nbgv invocation.
      - `Branch`
      - `BranchType` — one of `stable`, `feature`, `sprint`, `release`.
      - `FeatureSlug` — `$null` for non-feature branches.
      - `RepoRoot`
      - `SourceTag` — `$null` unless `-ReleaseTag` was supplied.
      - `SourceCommit`
      - `ResolvedPackageVersion`
      - `MajorMinorPatch`
      - `PrereleaseLabel`
      - `CurrentTier` — one of `Production`, `Development`, `Integration`,
        `QA`, `Experimental`; derived from BuildMaster stage context.
      - `CeilingTier` — one of `Production`, `Development`, `Integration`,
        `QA`, `Experimental`; derived from `version.json` prerelease label.
      - `Tier` — deprecated script-property alias for `CeilingTier`.
      - `IsAtCeiling` — `[bool]`, true when `CurrentTier -eq CeilingTier`.
      - `DbAssetsIncluded` — `[bool]`.

.EXAMPLE
    PS> Get-BuildContext -Application 'ATAP.Utilities' `
                         -ProjectPath  'src/ATAP.Utilities.ETW' `
                         -Branch       'main' `
                         -Stage        'Development'

    Returns the build context for the trunk pipeline run of the
    ATAP.Utilities.ETW package. `CurrentTier` is `Development`; `CeilingTier`
    is computed from that project's `version.json`.

.EXAMPLE
    PS> Get-BuildContext -Application 'AceCommander' `
                         -ProjectPath  'src/AceCommander.Server' `
                         -ReleaseTag   'v1.4.0'

    Returns the build context for a release-tag-driven pipeline run of the
    AceCommander.Server package.

.EXAMPLE
    PS> $ctx = Get-BuildContext -Application 'ATAP.Utilities' `
                                -ProjectPath 'src/ATAP.Utilities.ETW' `
                                -Branch 'sprint/0007'
    PS> $ctx.CurrentTier
    Experimental
    PS> $ctx.CeilingTier
    Experimental

    Omitting `-Stage` uses the BuildMaster stage environment variable when
    present, or `Experimental` in a standalone shell.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Implements task H1 of Plan-DocsUpdateForImmutablePackages_V3.md.
    Implements the version.json-as-ceiling model from
    Plan-VersionJsonAsCeiling.md.

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
  [CmdletBinding(DefaultParameterSetName = 'ByBranch')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Application,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectPath,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Stage,

    [Parameter(Mandatory = $false, ParameterSetName = 'ByReleaseTag')]
    [ValidateNotNullOrEmpty()]
    [string]$ReleaseTag,

    [Parameter(Mandatory = $false, ParameterSetName = 'ByBranch')]
    [ValidateNotNullOrEmpty()]
    [string]$Branch
  )

  begin {
    $fn = 'Get-BuildContext'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with Application='$Application' ProjectPath='$ProjectPath' Stage='$Stage' ParameterSetName='$($PSCmdlet.ParameterSetName)'" -Tag 'Trace'

    if (-not $PSBoundParameters.ContainsKey('Branch') -and -not $PSBoundParameters.ContainsKey('ReleaseTag')) {
      $msg = "Either -Branch or -ReleaseTag is required."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    foreach ($helperName in @('Get-CeilingFromPrereleaseLabel', 'Get-CurrentTierFromStage')) {
      if (-not (Get-Command -Name $helperName -CommandType Function -ErrorAction SilentlyContinue)) {
        $helperPath = Join-Path $PSScriptRoot "..\private\$helperName.ps1"
        if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
          . $helperPath
        } else {
          $msg = "Required helper '$helperName' was not found at '$helperPath'."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
          throw $msg
        }
      }
    }

    $stageSource = 'default'
    $stageName = 'Experimental'
    if ($PSBoundParameters.ContainsKey('Stage')) {
      $stageName = $Stage
      $stageSource = '-Stage'
    } elseif (-not [string]::IsNullOrWhiteSpace($env:INEDOSTAGE_NAME)) {
      $stageName = $env:INEDOSTAGE_NAME
      $stageSource = '$env:INEDOSTAGE_NAME'
    } elseif (-not [string]::IsNullOrWhiteSpace($env:BUILDMASTER_STAGE_NAME)) {
      $stageName = $env:BUILDMASTER_STAGE_NAME
      $stageSource = '$env:BUILDMASTER_STAGE_NAME'
    }
    $currentTier = Get-CurrentTierFromStage -Stage $stageName
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "CurrentTier='$currentTier' from $stageSource ('$stageName')"

    # Resolve ProjectPath to an absolute directory and validate that it
    # carries a project-adjacent version.json. nbgv silently walks up the
    # directory tree, so a missing version.json here would otherwise cause
    # this cmdlet to return a parent (e.g. solution-level) version.
    $resolvedProjectPath = $null
    try {
      $resolvedProjectPathRaw = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).ProviderPath
    } catch {
      $msg = "ProjectPath '$ProjectPath' could not be resolved: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    if (Test-Path -LiteralPath $resolvedProjectPathRaw -PathType Leaf) {
      $resolvedProjectPath = Split-Path -Parent $resolvedProjectPathRaw
    } elseif (Test-Path -LiteralPath $resolvedProjectPathRaw -PathType Container) {
      $resolvedProjectPath = $resolvedProjectPathRaw
    } else {
      $msg = "ProjectPath '$resolvedProjectPathRaw' is neither a file nor a directory."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }
    $projectVersionJson = Join-Path -Path $resolvedProjectPath -ChildPath 'version.json'
    if (-not (Test-Path -LiteralPath $projectVersionJson -PathType Leaf)) {
      $msg = "ProjectPath '$resolvedProjectPath' does not contain a project-adjacent 'version.json'. See SolutionDocumentation/CSharp-Packages-Versioning.md section 4.5."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "ProjectPath resolved to '$resolvedProjectPath' (version.json verified)"
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

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Invoking 'nbgv get-version --variable NuGetPackageVersion' in '$resolvedProjectPath'" -Tag 'NBGV'
    $pushed = $false
    try {
      Push-Location -LiteralPath $resolvedProjectPath
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
      $msg = "nbgv returned an empty version string for '$resolvedProjectPath'."
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
    # 8. Map prerelease label -> CeilingTier per version.json-as-ceiling.
    # ---------------------------------------------------------------------
    $ceilingTier = Get-CeilingFromPrereleaseLabel -PrereleaseLabel $prereleaseLabel
    $isAtCeiling = $currentTier -eq $ceilingTier
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "CeilingTier='$ceilingTier' CurrentTier='$currentTier' IsAtCeiling=$isAtCeiling"

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
      ProjectPath            = $resolvedProjectPath
      Branch                 = $resolvedBranch
      BranchType             = $branchType
      FeatureSlug            = $featureSlug
      RepoRoot               = $repoRoot
      SourceTag              = $sourceTag
      SourceCommit           = $sourceCommit
      ResolvedPackageVersion = $resolvedPackageVersion
      MajorMinorPatch        = $majorMinorPatch
      PrereleaseLabel        = $prereleaseLabel
      CurrentTier            = $currentTier
      CeilingTier            = $ceilingTier
      IsAtCeiling            = $isAtCeiling
      DbAssetsIncluded       = $dbAssetsIncluded
    }

    $context | Add-Member -MemberType ScriptProperty -Name 'Tier' -Value {
      if (-not $script:GetBuildContextTierAliasWarningEmitted) {
        $script:GetBuildContextTierAliasWarningEmitted = $true
        Write-PSFMessage -FunctionName 'Get-BuildContext' -ModuleName $mn -Level Warning -Message "Get-BuildContext.Tier is deprecated and aliases CeilingTier. Use .CeilingTier for version-label ceiling or .CurrentTier for BuildMaster stage context."
      }
      return $this.CeilingTier
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Get-BuildContext succeeded: Branch='$resolvedBranch' CurrentTier='$currentTier' CeilingTier='$ceilingTier' Version='$resolvedPackageVersion'"
    return $context
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}

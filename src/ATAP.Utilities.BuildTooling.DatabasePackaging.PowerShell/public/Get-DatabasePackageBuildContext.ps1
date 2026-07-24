#Requires -Version 7.0
<#
.SYNOPSIS
    Thin wrapper around Get-BuildContext that constructs the canonical database
    package path and augments the returned context with database-specific fields.

.DESCRIPTION
    Get-DatabasePackageBuildContext is the entry point for any BuildMaster pipeline
    run that targets a database change package. It:

      - Constructs the canonical database source folder:
          Database/<Application>/          (single-stream)
          Database/<Application>.<Stream>/ (multi-stream)
      - Validates that a version.json exists in that folder.
      - Delegates to Get-BuildContext, passing the database folder as -ProjectPath.
      - Augments the returned context with four database-specific properties:
          DatabasePackageId, DatabasePackageSourcePath, DatabaseVersionJsonPath,
          PackageKind.

    The version.json prerelease label drives the ceiling tier exactly as it does
    for C# and PowerShell packages. See DatabaseVersioning.md §5 and
    SolutionDocumentation/VersionJsonAsCeiling.md for the full specification.

.PARAMETER Application
    The application name. For example 'ATAPUtilities' produces package id
    'ATAPUtilities.Database' and looks for the source folder at
    'Database/ATAPUtilities/'.

.PARAMETER Stream
    Optional stream name. When supplied the folder is 'Database/<Application>.<Stream>/'
    and the package id is '<Application>.<Stream>.Database'.

.PARAMETER RepoRoot
    Absolute path to the repository root. Defaults to the output of
    'git rev-parse --show-toplevel' run from the current working directory.

.PARAMETER Stage
    Optional BuildMaster stage name forwarded to Get-BuildContext.

.PARAMETER Branch
    An explicit branch name. Mutually exclusive with -ReleaseTag.

.PARAMETER ReleaseTag
    A release tag. Mutually exclusive with -Branch.

.OUTPUTS
    [PSCustomObject] — All fields from Get-BuildContext plus:
      - DatabasePackageId         : NuGet package id for the database package.
      - DatabasePackageSourcePath : Absolute path to Database/<App>/ (or <App>.<Stream>/).
      - DatabaseVersionJsonPath   : Absolute path to the version.json used.
      - PackageKind               : Always 'DatabaseChangePackage'.

.EXAMPLE
    PS> Get-DatabasePackageBuildContext -Application 'ATAPUtilities' -Branch 'main'

    Returns the build context for the ATAPUtilities.Database package on the main
    branch. The context reflects the ceiling tier encoded in
    Database/ATAPUtilities/version.json.

.EXAMPLE
    PS> Get-DatabasePackageBuildContext `
            -Application 'AceCommander' `
            -Stream      'Reporting' `
            -Branch      'sprint/0007' `
            -Stage       'Experimental'

    Returns the context for the AceCommander.Reporting.Database package.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Spec: _Planning/Archived/DatabaseVersioning.md §5.
    Task: TASKS_V4-DBA2.md DBA2-T01.

.LINK
    Get-BuildContext
#>
function Get-DatabasePackageBuildContext {
  [CmdletBinding(DefaultParameterSetName = 'ByBranch')]
  [OutputType([PSCustomObject])]
  param(
    # Application name (required). E.g. 'ATAPUtilities' or 'AceCommander'.
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Application,

    # Optional stream name. Null/empty → single-stream package.
    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$Stream,

    # Repo root. Defaults to git rev-parse --show-toplevel.
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    # BuildMaster stage hint forwarded to Get-BuildContext.
    [Parameter(Mandatory = $false)]
    [string]$Stage,

    # Branch name. Mutually exclusive with -ReleaseTag.
    [Parameter(Mandatory = $false, ParameterSetName = 'ByBranch')]
    [string]$Branch,

    # Release tag. Mutually exclusive with -Branch.
    [Parameter(Mandatory = $false, ParameterSetName = 'ByReleaseTag')]
    [string]$ReleaseTag
  )

  begin {
    $fn = 'Get-DatabasePackageBuildContext'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Entering ${fn}: Application='$Application' Stream='$Stream' Stage='$Stage' ParameterSet='$($PSCmdlet.ParameterSetName)'" `
      -Tag 'Trace'

    # Require either -Branch or -ReleaseTag.
    if (-not $PSBoundParameters.ContainsKey('Branch') -and
      -not $PSBoundParameters.ContainsKey('ReleaseTag')) {
      $msg = "${fn}: Either -Branch or -ReleaseTag must be supplied."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    # Resolve RepoRoot if not provided.
    if (-not $PSBoundParameters.ContainsKey('RepoRoot') -or [string]::IsNullOrWhiteSpace($RepoRoot)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Resolving RepoRoot via git rev-parse' -Tag 'Git'
      $RepoRoot = (& git rev-parse --show-toplevel 2>&1)
      if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($RepoRoot)) {
        $msg = "${fn}: Could not determine RepoRoot via 'git rev-parse --show-toplevel'. Ensure the current directory is inside a git repository."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }
      $RepoRoot = $RepoRoot.Trim()
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "RepoRoot='$RepoRoot'" -Tag 'Trace'
  }

  process {
    # Construct the database folder name and package id.
    $dbFolderName = if ([string]::IsNullOrWhiteSpace($Stream)) {
      $Application
    } else {
      "$Application.$Stream"
    }

    $dbPackageId = if ([string]::IsNullOrWhiteSpace($Stream)) {
      "$Application.Database"
    } else {
      "$Application.$Stream.Database"
    }

    $projectPath = Join-Path $RepoRoot 'Database' $dbFolderName
    $versionJsonPath = Join-Path $projectPath 'version.json'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "dbFolderName='$dbFolderName' dbPackageId='$dbPackageId' projectPath='$projectPath'" `
      -Tag 'Trace'

    # Validate the version.json exists — Get-BuildContext will also check, but
    # surfacing the error here gives a clearer message.
    if (-not (Test-Path -LiteralPath $versionJsonPath -PathType Leaf)) {
      $msg = "${fn}: version.json not found at expected path '$versionJsonPath'. Ensure the database package source folder exists and contains a version.json."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    # Build the splatted parameter set for Get-BuildContext.
    $buildContextParams = @{
      Application = $Application
      ProjectPath = $projectPath
    }
    if ($PSBoundParameters.ContainsKey('Stage')) {
      $buildContextParams['Stage'] = $Stage
    }
    if ($PSCmdlet.ParameterSetName -eq 'ByBranch') {
      if ($PSBoundParameters.ContainsKey('Branch')) {
        $buildContextParams['Branch'] = $Branch
      }
    } else {
      $buildContextParams['ReleaseTag'] = $ReleaseTag
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Calling Get-BuildContext for '$dbPackageId'" -Tag 'Trace'

    $baseCtx = Get-BuildContext @buildContextParams

    # Augment the context with database-specific fields.
    $baseCtx | Add-Member -NotePropertyMembers @{
      DatabasePackageId         = $dbPackageId
      DatabasePackageSourcePath = $projectPath
      DatabaseVersionJsonPath   = $versionJsonPath
      PackageKind               = 'DatabaseChangePackage'
    } -PassThru

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Returning database build context for '$dbPackageId' CeilingTier='$($baseCtx.CeilingTier)'" `
      -Tag 'Trace'
  }
}

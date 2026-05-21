#Requires -Version 7.0
function Resolve-BuildMasterPackageProjectPath {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ModuleName,

    [Parameter(Mandatory = $false)]
    [string]$ProjectPath
  )

  function Add-CandidatePath {
    param(
      [Parameter(Mandatory = $false)]
      [System.Collections.Generic.List[string]]$Candidates,

      [Parameter(Mandatory = $false)]
      [string]$Path
    )

    if (-not [string]::IsNullOrWhiteSpace($Path) -and -not $Candidates.Contains($Path)) {
      $Candidates.Add($Path) | Out-Null
    }
  }

  $candidates = [System.Collections.Generic.List[string]]::new()
  if (-not [string]::IsNullOrWhiteSpace($ProjectPath)) {
    Add-CandidatePath -Candidates $candidates -Path $ProjectPath
  } else {
    Add-CandidatePath -Candidates $candidates -Path $ModuleName
    Add-CandidatePath -Candidates $candidates -Path (Join-Path -Path (Get-Location).ProviderPath -ChildPath "src/$ModuleName")

    $repoRootRaw = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$repoRootRaw)) {
      Add-CandidatePath -Candidates $candidates -Path (Join-Path -Path ([string]$repoRootRaw).Trim() -ChildPath "src/$ModuleName")
    }
  }

  foreach ($candidate in $candidates) {
    try {
      $resolvedRaw = (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).ProviderPath
    } catch {
      continue
    }

    $resolvedDirectory = if (Test-Path -LiteralPath $resolvedRaw -PathType Leaf) {
      Split-Path -Parent $resolvedRaw
    } else {
      $resolvedRaw
    }

    $versionJson = Join-Path -Path $resolvedDirectory -ChildPath 'version.json'
    if (Test-Path -LiteralPath $versionJson -PathType Leaf) {
      return $resolvedDirectory
    }
  }

  $candidateList = ($candidates | ForEach-Object { "'$_'" }) -join ', '
  if ([string]::IsNullOrWhiteSpace($candidateList)) {
    $candidateList = '<none>'
  }
  throw "Could not resolve a project folder with project-adjacent version.json for module '$ModuleName'. Checked: $candidateList. Pass -ProjectPath to the module project folder if it is not under src/$ModuleName."
}

function Resolve-BuildMasterPackageVersionFromProjectPath {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectPath
  )

  if (-not (Get-Command -Name Get-PSModuleVersionFromNBGV -CommandType Function -ErrorAction SilentlyContinue)) {
    $helperPath = Join-Path -Path $PSScriptRoot -ChildPath 'Get-PSModuleVersionFromNBGV.ps1'
    if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
      throw "Required helper 'Get-PSModuleVersionFromNBGV' was not found at '$helperPath'."
    }
    . $helperPath
  }

  $versionJson = Join-Path -Path $ProjectPath -ChildPath 'version.json'
  if (-not (Test-Path -LiteralPath $versionJson -PathType Leaf)) {
    throw "ProjectPath '$ProjectPath' does not contain a project-adjacent 'version.json'."
  }

  $versionInfo = Get-PSModuleVersionFromNBGV -ModuleRoot $ProjectPath
  $moduleVersion = [string]$versionInfo.ModuleVersion
  $prerelease = [string]$versionInfo.Prerelease
  if ([string]::IsNullOrWhiteSpace($moduleVersion)) {
    throw "Get-PSModuleVersionFromNBGV did not return ModuleVersion for '$ProjectPath'."
  }

  if ([string]::IsNullOrWhiteSpace($prerelease)) {
    return $moduleVersion
  }

  return ('{0}-{1}' -f $moduleVersion, $prerelease)
}

function Start-BuildMasterPackagePipeline {
  <#
.SYNOPSIS
    Creates a named BuildMaster release and queues its package build.

.DESCRIPTION
    Orchestrates the BuildMaster release/build handoff after a package event
    has already resolved the package or module identity. When
    `-ResolvedPackageVersion` is omitted, the cmdlet resolves the module's
    project folder, verifies its project-adjacent `version.json`, and uses NBGV
    to compute the PowerShell module package version.
    It computes a human-readable release name of
    `"<ModuleName> <ResolvedPackageVersion>"`, creates the release with
    `New-BuildMasterRelease -ReleaseName`, and queues the build with
    package identity as build-scope variables through
    `Start-BuildMasterPipeline -Variables`.

    This is the narrow orchestration entry point used by a ProGet poller or manual
    trigger once the package tuple is known; it does not query ProGet itself.

.PARAMETER Application
    BuildMaster application name, such as `ATAP.Utilities-PowerShell`.

.PARAMETER PipelineName
    BuildMaster pipeline name, such as `global::PowerShellModule-5Stage`.

.PARAMETER ModuleName
    Module or package display identity used in the BuildMaster release name.

.PARAMETER PackageName
    ProGet package ID. Defaults to `ModuleName`.

.PARAMETER ProjectPath
    Optional module project folder, or a file under that folder. Defaults to
    `src/<ModuleName>` beneath the current working directory or Git repository
    root. The resolved folder must contain `version.json`.

.PARAMETER ResolvedPackageVersion
    Immutable package version. Aliased as `PackageVersion`. When omitted, it is
    derived from `ProjectPath/version.json` through NBGV and formatted as the
    PowerShell module package version, e.g. `0.1.0-Beta004`.

.PARAMETER Tier
    BuildMaster/package tier supplied to the build as `$Tier`. Defaults to
    `Experimental` because package events should originate from the
    Experimental feed.

.PARAMETER FeedName
    Optional feed name to pass as `$FeedName`.

.PARAMETER Branch
    Optional source branch to pass as `$Branch`.

.PARAMETER Variables
    Additional build-scope variables. Required package identity variables are
    written after these values so the build matches the release identity.

.OUTPUTS
    [PSCustomObject] summarizing the release and build API results.
#>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Application,

    [Parameter(Mandatory = $true)]
    [Alias('Pipeline')]
    [ValidateNotNullOrEmpty()]
    [string]$PipelineName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ModuleName,

    [Parameter(Mandatory = $false)]
    [string]$PackageName,

    [Parameter(Mandatory = $false)]
    [Alias('ModuleRoot', 'ModulePath')]
    [string]$ProjectPath,

    [Parameter(Mandatory = $false)]
    [Alias('PackageVersion')]
    [ValidateNotNullOrEmpty()]
    [string]$ResolvedPackageVersion,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Tier = 'Experimental',

    [Parameter(Mandatory = $false)]
    [string]$FeedName,

    [Parameter(Mandatory = $false)]
    [string]$Branch,

    [Parameter(Mandatory = $false)]
    [string]$Reason,

    [Parameter(Mandatory = $false)]
    [hashtable]$Variables,

    [Parameter(Mandatory = $false)]
    [string]$BuildMasterBaseUrl,

    [Parameter(Mandatory = $false)]
    [string]$ApiKey
  )

  begin {
    $fn = 'Start-BuildMasterPackagePipeline'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn (Application='$Application' ModuleName='$ModuleName' Version='$ResolvedPackageVersion')" -Tag 'Trace'
  }

  process {
    $effectivePackageName = if ([string]::IsNullOrWhiteSpace($PackageName)) { $ModuleName } else { $PackageName }
    if ([string]::IsNullOrWhiteSpace($ResolvedPackageVersion)) {
      $resolvedProjectPath = Resolve-BuildMasterPackageProjectPath -ModuleName $ModuleName -ProjectPath $ProjectPath
      $ResolvedPackageVersion = Resolve-BuildMasterPackageVersionFromProjectPath -ProjectPath $resolvedProjectPath
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Resolved package version '$ResolvedPackageVersion' from '$resolvedProjectPath'."
    }

    $releaseName = '{0} {1}' -f $ModuleName, $ResolvedPackageVersion
    $releaseNumber = $ResolvedPackageVersion
    $effectiveReason = if ([string]::IsNullOrWhiteSpace($Reason)) {
      "Package orchestration detected $effectivePackageName $ResolvedPackageVersion"
    } else {
      $Reason
    }

    $buildVariables = @{}
    if ($null -ne $Variables) {
      foreach ($key in $Variables.Keys) {
        $buildVariables[$key] = $Variables[$key]
      }
    }

    $buildVariables['$ModuleName'] = $ModuleName
    $buildVariables['$PackageName'] = $effectivePackageName
    $buildVariables['$PackageVersion'] = $ResolvedPackageVersion
    $buildVariables['$ResolvedPackageVersion'] = $ResolvedPackageVersion
    $buildVariables['$Tier'] = $Tier
    if (-not [string]::IsNullOrWhiteSpace($FeedName)) {
      $buildVariables['$FeedName'] = $FeedName
    }
    if (-not [string]::IsNullOrWhiteSpace($Branch)) {
      $buildVariables['$Branch'] = $Branch
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Creating BuildMaster release '$releaseName' ($Application/$releaseNumber) on '$PipelineName'."
    $target = "BuildMaster release '$releaseName' and build for '$Application'"
    if (-not $PSCmdlet.ShouldProcess($target, 'Create release and queue build')) {
      return [PSCustomObject]@{
        OperationName          = 'Start-BuildMasterPackagePipeline'
        Succeeded              = $false
        Application            = $Application
        PipelineName           = $PipelineName
        ReleaseNumber          = $releaseNumber
        ReleaseName            = $releaseName
        ModuleName             = $ModuleName
        PackageName            = $effectivePackageName
        ResolvedPackageVersion = $ResolvedPackageVersion
        ReleaseResult          = $null
        BuildResult            = $null
        ResponseSummary        = "WhatIf: planned create of $target"
      }
    }

    $releaseParams = @{
      Application  = $Application
      ReleaseNumber = $releaseNumber
      ReleaseName = $releaseName
      PipelineName = $PipelineName
    }
    if (-not [string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) { $releaseParams['BuildMasterBaseUrl'] = $BuildMasterBaseUrl }
    if (-not [string]::IsNullOrWhiteSpace($ApiKey)) { $releaseParams['ApiKey'] = $ApiKey }

    $releaseResult = New-BuildMasterRelease @releaseParams

    $buildParams = @{
      Application  = $Application
      ReleaseNumber = $releaseNumber
      Pipeline     = $PipelineName
      Variables    = $buildVariables
      Reason       = $effectiveReason
    }
    if (-not [string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) { $buildParams['BuildMasterBaseUrl'] = $BuildMasterBaseUrl }
    if (-not [string]::IsNullOrWhiteSpace($ApiKey)) { $buildParams['ApiKey'] = $ApiKey }

    $buildResult = Start-BuildMasterPipeline @buildParams
    $succeeded = [bool]$releaseResult.Succeeded -and [bool]$buildResult.Succeeded

    return [PSCustomObject]@{
      OperationName          = 'Start-BuildMasterPackagePipeline'
      Succeeded              = $succeeded
      Application            = $Application
      PipelineName           = $PipelineName
      ReleaseNumber          = $releaseNumber
      ReleaseName            = $releaseName
      ModuleName             = $ModuleName
      PackageName            = $effectivePackageName
      ResolvedPackageVersion = $ResolvedPackageVersion
      ReleaseResult          = $releaseResult
      BuildResult            = $buildResult
      ResponseSummary        = "release '$releaseName' queued as BuildMaster build $($buildResult.BuildNumber)"
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}

#Requires -Version 7.0
function Start-BuildMasterPackagePipeline {
  <#
.SYNOPSIS
    Creates a named BuildMaster release and queues its package build.

.DESCRIPTION
    Orchestrates the BuildMaster release/build handoff after a package event
    has already resolved the package or module identity and immutable version.
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

.PARAMETER ResolvedPackageVersion
    Immutable package version. Aliased as `PackageVersion`.

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

    [Parameter(Mandatory = $true)]
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

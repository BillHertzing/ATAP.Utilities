<#
.SYNOPSIS
  Builds and publishes a Release-Bundle Universal Package for a BuildMaster build.

.DESCRIPTION
  Eponymous entry-point script. Loads the captured release-bundle context JSON
  emitted by Initialize-ReleaseBundleBuildContext.ps1, calls New-ReleaseManifest
  and New-ReleaseBundle from the BuildTooling module, publishes the bundle to
  the configured ProGet Experimental feed, drops per-bundle *.tmp markers
  OtterScript reads via $FileContents(), and updates the build-context.json
  document.

.PARAMETER BuildToolingModulePath
  Path to the ATAP.Utilities.BuildTooling.PowerShell module to import.

.PARAMETER SourcePath
  Working copy / repository root. _generated/release-bundle and
  _generated/release-manifest live beneath this.

.PARAMETER BuildMasterBuildId
  BuildMaster build identifier captured into the run-context document.

.PARAMETER BuildNumber
  Optional BuildMaster build-number string for traceability.

.PARAMETER ExecutionId
  Optional BuildMaster execution identifier for traceability.

.PARAMETER ContextDirectory
  Run-context directory under _generated/buildmaster for this build.

.PARAMETER ReleaseBundleContextFile
  Path to releasebundle_context.json produced by the Initialize-ReleaseBundleBuildContext.ps1 stage.

.PARAMETER ReleaseBundleNameFile
.PARAMETER ReleaseBundleResolvedVersionFile
.PARAMETER ReleaseBundleBundleVersionFile
.PARAMETER ReleaseBundlePathFile
.PARAMETER ReleaseBundleManifestPathFile
  Output marker files OtterScript reads with $FileContents().

.PARAMETER ReleaseBundleExperimentalFeedName
  Name of the Universal Package feed that receives the freshly-built bundle.

.PARAMETER CeilingTier
  Ceiling tier captured from the build context, used by gate decisions.

.PARAMETER ProGetUrl
  Base URL of the ProGet server.

.PARAMETER ProGetApiKey
  ProGet API key passed to Publish-UniversalPackageToProGet.

.PARAMETER RetentionDays
  Run-context retention window.

.OUTPUTS
  Writes *.tmp markers and build-context.json under the run-context directory.

.EXAMPLE
  pwsh -File New-ReleaseBundleBuildMasterPackage.ps1 ...

.NOTES
  AI assisted using Powershell.instructions.md as guidelines

.LINK
  Initialize-ReleaseBundleBuildContext.ps1
#>

#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$BuildToolingModulePath,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$SourcePath,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$BuildMasterBuildId,

  [AllowEmptyString()]
  [string]$BuildNumber = '',

  [AllowEmptyString()]
  [string]$ExecutionId = '',

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ContextDirectory,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ReleaseBundleContextFile,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ReleaseBundleNameFile,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ReleaseBundleResolvedVersionFile,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ReleaseBundleBundleVersionFile,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ReleaseBundlePathFile,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ReleaseBundleManifestPathFile,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ReleaseBundleExperimentalFeedName,

  [Parameter(Mandatory)]
  [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
  [string]$CeilingTier,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ProGetUrl,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ProGetApiKey,

  [ValidateRange(0, 365)]
  [int]$RetentionDays = 14
)

$ErrorActionPreference = 'Stop'

function New-ReleaseBundleBuildMasterPackage {
  <#
  .SYNOPSIS
    Eponymous worker that builds + publishes the Release-Bundle Universal Package.
  .DESCRIPTION
    Receives the same parameters as the script entry-point and performs the
    full New-ReleaseManifest + New-ReleaseBundle + Publish-UniversalPackageToProGet
    workflow.
  .OUTPUTS
    [PSCustomObject] The persisted build-context.json payload.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][string]$BuildToolingModulePath,
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$BuildMasterBuildId,
    [AllowEmptyString()][string]$BuildNumber = '',
    [AllowEmptyString()][string]$ExecutionId = '',
    [Parameter(Mandatory)][string]$ContextDirectory,
    [Parameter(Mandatory)][string]$ReleaseBundleContextFile,
    [Parameter(Mandatory)][string]$ReleaseBundleNameFile,
    [Parameter(Mandatory)][string]$ReleaseBundleResolvedVersionFile,
    [Parameter(Mandatory)][string]$ReleaseBundleBundleVersionFile,
    [Parameter(Mandatory)][string]$ReleaseBundlePathFile,
    [Parameter(Mandatory)][string]$ReleaseBundleManifestPathFile,
    [Parameter(Mandatory)][string]$ReleaseBundleExperimentalFeedName,
    [Parameter(Mandatory)][string]$CeilingTier,
    [Parameter(Mandatory)][string]$ProGetUrl,
    [Parameter(Mandatory)][string]$ProGetApiKey,
    [int]$RetentionDays = 14
  )

  BEGIN {
    $fn = 'New-ReleaseBundleBuildMasterPackage'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn for BuildId='$BuildMasterBuildId'"

    . (Join-Path -Path $PSScriptRoot -ChildPath 'BuildMasterRunContext.Common.ps1')

    try {
      Import-Module $BuildToolingModulePath -Force
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to import BuildTooling module from '$BuildToolingModulePath'. Exception: $($_.Exception.Message)"
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Module import attempt complete for '$BuildToolingModulePath'."
    }
  }

  PROCESS {
    try {
      if (-not (Test-Path -LiteralPath $ReleaseBundleContextFile)) {
        throw "ReleaseBundle context file '$ReleaseBundleContextFile' is missing. Run Initialize-ReleaseBundleBuildContext.ps1 first."
      }

      $context = Get-Content -LiteralPath $ReleaseBundleContextFile -Raw | ConvertFrom-Json -ErrorAction Stop

      $env:PROGET_ADMIN_API_KEY = $ProGetApiKey
      $env:PROGET_BUILDMASTER_API_KEY = $ProGetApiKey
      $global:ProGetBaseUrl = $ProGetUrl

      $manifestOutputPath = Join-Path -Path $SourcePath -ChildPath '_generated/release-manifest/manifest.json'
      $bundleOutputPath   = Join-Path -Path $SourcePath -ChildPath '_generated/release-bundle'

      $manifest = New-ReleaseManifest -Context $context -OutputPath $manifestOutputPath
      $bundle   = New-ReleaseBundle -Manifest $manifest -OutputPath $bundleOutputPath -SourceRoot $SourcePath

      try {
        Publish-UniversalPackageToProGet -Path $bundle.Path.FullName -Feed $ReleaseBundleExperimentalFeedName -CeilingTier $CeilingTier
      }
      catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Publish-UniversalPackageToProGet failed for bundle '$($bundle.Path.FullName)'. Exception: $($_.Exception.Message)"
        throw
      }
      finally {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Publish-UniversalPackageToProGet call complete."
      }

      Write-BuildMasterRunContextTextFile -Path $ReleaseBundleNameFile             -Value $context.Application
      Write-BuildMasterRunContextTextFile -Path $ReleaseBundleResolvedVersionFile  -Value $context.ResolvedPackageVersion
      Write-BuildMasterRunContextTextFile -Path $ReleaseBundleBundleVersionFile    -Value $bundle.BundleVersion
      Write-BuildMasterRunContextTextFile -Path $ReleaseBundlePathFile             -Value $bundle.Path.FullName
      Write-BuildMasterRunContextTextFile -Path $ReleaseBundleManifestPathFile     -Value $manifest.FullName

      $allowDecisions = Get-BuildMasterAllowDecisions -CeilingTier $CeilingTier
      $payload = Write-BuildMasterRunContextJson `
        -ContextDirectory $ContextDirectory `
        -BuildMasterBuildId $BuildMasterBuildId `
        -BuildNumber $BuildNumber `
        -ExecutionId $ExecutionId `
        -ApplicationName $context.Application `
        -Branch $context.Branch `
        -SourcePath $SourcePath `
        -ProjectPath $SourcePath `
        -CurrentTier $context.CurrentTier `
        -CeilingTier $CeilingTier `
        -ResolvedVersion $context.ResolvedPackageVersion `
        -PrereleaseLabel $context.PrereleaseLabel `
        -AllowDecisions $allowDecisions `
        -AdditionalData @{
          PipelineKind     = 'ReleaseBundle'
          ProductName      = $context.Application
          BundleVersion    = $bundle.BundleVersion
          BundlePath       = $bundle.Path.FullName
          ManifestPath     = $manifest.FullName
          ExperimentalFeed = $ReleaseBundleExperimentalFeedName
        } `
        -RetentionDays $RetentionDays

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message ("ReleaseBundle captured: BuildId={0}; ContextDirectory={1}; Product={2}; ResolvedVersion={3}; BundleVersion={4}; BundlePath={5}" -f $BuildMasterBuildId, $ContextDirectory, $context.Application, $context.ResolvedPackageVersion, $bundle.BundleVersion, $bundle.Path.FullName)

      return $payload
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed in $fn. Exception: $($_.Exception.Message)"
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Process complete in $fn."
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Finished $fn"
  }
}

New-ReleaseBundleBuildMasterPackage `
  -BuildToolingModulePath $BuildToolingModulePath `
  -SourcePath $SourcePath `
  -BuildMasterBuildId $BuildMasterBuildId `
  -BuildNumber $BuildNumber `
  -ExecutionId $ExecutionId `
  -ContextDirectory $ContextDirectory `
  -ReleaseBundleContextFile $ReleaseBundleContextFile `
  -ReleaseBundleNameFile $ReleaseBundleNameFile `
  -ReleaseBundleResolvedVersionFile $ReleaseBundleResolvedVersionFile `
  -ReleaseBundleBundleVersionFile $ReleaseBundleBundleVersionFile `
  -ReleaseBundlePathFile $ReleaseBundlePathFile `
  -ReleaseBundleManifestPathFile $ReleaseBundleManifestPathFile `
  -ReleaseBundleExperimentalFeedName $ReleaseBundleExperimentalFeedName `
  -CeilingTier $CeilingTier `
  -ProGetUrl $ProGetUrl `
  -ProGetApiKey $ProGetApiKey `
  -RetentionDays $RetentionDays | Out-Null

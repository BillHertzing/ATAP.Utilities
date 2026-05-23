<#
.SYNOPSIS
  Captures the BuildMaster run-context for a Release-Bundle pipeline stage.

.DESCRIPTION
  Eponymous entry-point script. Resolves Get-BuildContext for the supplied
  product (optionally using a release tag), writes per-release-bundle *.tmp
  markers OtterScript reads via $FileContents(), serialises the build context
  to releasebundle_context.json, and persists the full build-context.json.

.PARAMETER BuildToolingModulePath
  Path to the ATAP.Utilities.BuildTooling.PowerShell module to import.

.PARAMETER SourcePath
  Working copy / repository root.

.PARAMETER BuildMasterBuildId
  BuildMaster build id used as the per-build context folder name.

.PARAMETER BuildNumber
  Optional BuildMaster build number string.

.PARAMETER ExecutionId
  Optional BuildMaster execution identifier.

.PARAMETER ProductName
  The product whose release bundle is being assembled.

.PARAMETER ReleaseTag
  Optional release tag; when present Get-BuildContext is queried by tag rather
  than by branch.

.PARAMETER Branch
  Optional source-branch label (used when ReleaseTag is empty).

.PARAMETER Stage
  BuildMaster stage name.

.PARAMETER RetentionDays
  Run-context retention window for sibling builds.

.OUTPUTS
  Writes *.tmp state markers and build-context.json under the run-context
  directory. No pipeline output.

.EXAMPLE
  pwsh -File Initialize-ReleaseBundleBuildContext.ps1 `
    -BuildToolingModulePath C:\src\repo\src\ATAP.Utilities.BuildTooling.PowerShell `
    -SourcePath C:\src\repo `
    -BuildMasterBuildId 12345 `
    -ProductName MyProduct `
    -Stage Experimental

.NOTES
  AI assisted using Powershell.instructions.md as guidelines

.LINK
  BuildMasterRunContext.Common.ps1
#>

#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
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
  [string]$ProductName,

  [AllowEmptyString()]
  [string]$ReleaseTag = '',

  [AllowEmptyString()]
  [string]$Branch = '',

  [Parameter(Mandatory)]
  [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
  [string]$Stage,

  [ValidateRange(0, 365)]
  [int]$RetentionDays = 14
)

$ErrorActionPreference = 'Stop'

function Initialize-ReleaseBundleBuildContext {
  <#
  .SYNOPSIS
    Eponymous worker that performs Release-Bundle run-context initialisation.
  .DESCRIPTION
    Receives the same parameters as the script entry-point and does the full
    Get-BuildContext + Write-BuildMasterRunContextJson dance for a product
    release bundle.
  .OUTPUTS
    [PSCustomObject] The persisted run-context payload.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][string]$BuildToolingModulePath,
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$BuildMasterBuildId,
    [AllowEmptyString()][string]$BuildNumber = '',
    [AllowEmptyString()][string]$ExecutionId = '',
    [Parameter(Mandatory)][string]$ProductName,
    [AllowEmptyString()][string]$ReleaseTag = '',
    [AllowEmptyString()][string]$Branch = '',
    [Parameter(Mandatory)][string]$Stage,
    [int]$RetentionDays = 14
  )

  BEGIN {
    $fn = 'Initialize-ReleaseBundleBuildContext'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn for BuildId='$BuildMasterBuildId'; Product='$ProductName'; Stage='$Stage'"

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
      $contextDirectory = Initialize-BuildMasterRunContextDirectory -SourcePath $SourcePath -BuildMasterBuildId $BuildMasterBuildId -RetentionDays $RetentionDays

      if ([string]::IsNullOrWhiteSpace($ReleaseTag)) {
        $context = Get-BuildContext -Application $ProductName -ProjectPath $SourcePath -Branch $Branch -Stage $Stage
      }
      else {
        $context = Get-BuildContext -Application $ProductName -ProjectPath $SourcePath -ReleaseTag $ReleaseTag -Stage $Stage
      }

      $allowDecisions = Get-BuildMasterAllowDecisions -CeilingTier $context.CeilingTier
      $existingContext = Read-BuildMasterRunContextJson -ContextDirectory $contextDirectory
      $capturedResolvedVersion = [string]$context.ResolvedPackageVersion
      $capturedPrereleaseLabel = [string]$context.PrereleaseLabel

      if ($context.CurrentTier -ne 'Experimental') {
        if ($null -eq $existingContext -or [string]::IsNullOrWhiteSpace([string]$existingContext.ResolvedVersion)) {
          throw "BuildMaster run context '$contextDirectory' is missing a captured ResolvedVersion for build id '$BuildMasterBuildId'. Run the Experimental stage first or transfer the build-id context folder."
        }

        if ([string]$existingContext.ResolvedVersion -ne [string]$context.ResolvedPackageVersion) {
          throw "BuildMaster run context '$contextDirectory' captured version '$($existingContext.ResolvedVersion)', but this stage resolved '$($context.ResolvedPackageVersion)'."
        }

        $capturedResolvedVersion = [string]$existingContext.ResolvedVersion
        if (-not [string]::IsNullOrWhiteSpace([string]$existingContext.PrereleaseLabel)) {
          $capturedPrereleaseLabel = [string]$existingContext.PrereleaseLabel
        }
      }

      $stateFiles = [ordered]@{
        CurrentTier       = Join-Path -Path $contextDirectory -ChildPath 'releasebundle_current_tier.tmp'
        CeilingTier       = Join-Path -Path $contextDirectory -ChildPath 'releasebundle_ceiling_tier.tmp'
        ResolvedVersion   = Join-Path -Path $contextDirectory -ChildPath 'releasebundle_resolved_version.tmp'
        PrereleaseLabel   = Join-Path -Path $contextDirectory -ChildPath 'releasebundle_prerelease_label.tmp'
        ContextJson       = Join-Path -Path $contextDirectory -ChildPath 'releasebundle_context.json'
        Name              = Join-Path -Path $contextDirectory -ChildPath 'releasebundle_name.tmp'
        BundleVersion     = Join-Path -Path $contextDirectory -ChildPath 'releasebundle_bundle_version.tmp'
        BundlePath        = Join-Path -Path $contextDirectory -ChildPath 'releasebundle_path.tmp'
        ManifestPath      = Join-Path -Path $contextDirectory -ChildPath 'releasebundle_manifest_path.tmp'
        AllowExperimental = Join-Path -Path $contextDirectory -ChildPath 'releasebundle_allow_experimental.tmp'
        AllowDevelopment  = Join-Path -Path $contextDirectory -ChildPath 'releasebundle_allow_development.tmp'
        AllowIntegration  = Join-Path -Path $contextDirectory -ChildPath 'releasebundle_allow_integration.tmp'
        AllowQA           = Join-Path -Path $contextDirectory -ChildPath 'releasebundle_allow_qa.tmp'
        AllowProduction   = Join-Path -Path $contextDirectory -ChildPath 'releasebundle_allow_production.tmp'
      }

      Write-BuildMasterRunStateFiles -StateFiles $stateFiles -Values @{
        CurrentTier       = $context.CurrentTier
        CeilingTier       = $context.CeilingTier
        ResolvedVersion   = $capturedResolvedVersion
        PrereleaseLabel   = $capturedPrereleaseLabel
        AllowExperimental = $allowDecisions['Experimental'].ToString().ToLowerInvariant()
        AllowDevelopment  = $allowDecisions['Development'].ToString().ToLowerInvariant()
        AllowIntegration  = $allowDecisions['Integration'].ToString().ToLowerInvariant()
        AllowQA           = $allowDecisions['QA'].ToString().ToLowerInvariant()
        AllowProduction   = $allowDecisions['Production'].ToString().ToLowerInvariant()
      }

      $context | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $stateFiles.ContextJson -Encoding utf8

      $payload = Write-BuildMasterRunContextJson `
        -ContextDirectory $contextDirectory `
        -BuildMasterBuildId $BuildMasterBuildId `
        -BuildNumber $BuildNumber `
        -ExecutionId $ExecutionId `
        -ApplicationName $ProductName `
        -Branch $Branch `
        -SourcePath $SourcePath `
        -ProjectPath $SourcePath `
        -CurrentTier $context.CurrentTier `
        -CeilingTier $context.CeilingTier `
        -ResolvedVersion $capturedResolvedVersion `
        -PrereleaseLabel $capturedPrereleaseLabel `
        -AllowDecisions $allowDecisions `
        -StateFiles $stateFiles `
        -AdditionalData @{ PipelineKind = 'ReleaseBundle'; ProductName = $ProductName; ReleaseTag = $ReleaseTag } `
        -RetentionDays $RetentionDays

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message ("BuildMaster run context initialized: BuildId={0}; BuildNumber={1}; ExecutionId={2}; ContextDirectory={3}; Product={4}; ReleaseTag={5}; CurrentTier={6}; CeilingTier={7}; ResolvedVersion={8}" -f $BuildMasterBuildId, $BuildNumber, $ExecutionId, $contextDirectory, $ProductName, $ReleaseTag, $context.CurrentTier, $context.CeilingTier, $capturedResolvedVersion)

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

Initialize-ReleaseBundleBuildContext `
  -BuildToolingModulePath $BuildToolingModulePath `
  -SourcePath $SourcePath `
  -BuildMasterBuildId $BuildMasterBuildId `
  -BuildNumber $BuildNumber `
  -ExecutionId $ExecutionId `
  -ProductName $ProductName `
  -ReleaseTag $ReleaseTag `
  -Branch $Branch `
  -Stage $Stage `
  -RetentionDays $RetentionDays | Out-Null

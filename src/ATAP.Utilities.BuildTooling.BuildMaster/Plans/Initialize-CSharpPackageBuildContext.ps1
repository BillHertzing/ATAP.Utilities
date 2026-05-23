<#
.SYNOPSIS
  Captures the BuildMaster run-context for a C# package pipeline stage.

.DESCRIPTION
  Eponymous entry-point script. Resolves Get-BuildContext for the current
  application/project/branch/stage, validates that an already-captured
  ResolvedVersion has not drifted between stages, emits the per-tier state
  marker files OtterScript reads via $FileContents(), and persists the full
  build-context.json document.

  Intended to be invoked from an OtterScript plan via 'Exec pwsh -File'.

.PARAMETER BuildToolingModulePath
  Path to the ATAP.Utilities.BuildTooling.PowerShell module manifest or folder.

.PARAMETER SourcePath
  Working copy / repository root. _generated/buildmaster lives beneath this.

.PARAMETER BuildMasterBuildId
  The BuildMaster build identifier (e.g. $BuildMasterId(build) in OtterScript).

.PARAMETER BuildNumber
  Optional BuildMaster build-number string for traceability.

.PARAMETER ExecutionId
  Optional BuildMaster execution identifier for traceability.

.PARAMETER ApplicationName
  The product/application this pipeline targets.

.PARAMETER PackageName
  Optional NuGet package id; defaults to ApplicationName if not supplied.

.PARAMETER ProjectPath
  Path to the C# project being built.

.PARAMETER Branch
  Optional source branch label.

.PARAMETER Stage
  BuildMaster stage name (Experimental/Development/Integration/QA/Production).

.PARAMETER RetentionDays
  Run-context retention window for sibling builds under _generated/buildmaster.

.OUTPUTS
  Writes a build-context.json plus *.tmp state files under the run-context
  directory. No pipeline output.

.EXAMPLE
  pwsh -File Initialize-CSharpPackageBuildContext.ps1 `
    -BuildToolingModulePath C:\src\repo\src\ATAP.Utilities.BuildTooling.PowerShell `
    -SourcePath C:\src\repo `
    -BuildMasterBuildId 12345 `
    -ApplicationName MyApp `
    -ProjectPath C:\src\repo\src\MyApp `
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
  [string]$ApplicationName,

  [AllowEmptyString()]
  [string]$PackageName = '',

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ProjectPath,

  [AllowEmptyString()]
  [string]$Branch = '',

  [Parameter(Mandatory)]
  [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
  [string]$Stage,

  [ValidateRange(0, 365)]
  [int]$RetentionDays = 14
)

$ErrorActionPreference = 'Stop'

function Initialize-CSharpPackageBuildContext {
  <#
  .SYNOPSIS
    Eponymous worker that performs the C# package run-context initialisation.
  .DESCRIPTION
    Receives the same parameters as the script entry-point and does the full
    Get-BuildContext / Write-BuildMasterRunContextJson dance.
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
    [Parameter(Mandatory)][string]$ApplicationName,
    [AllowEmptyString()][string]$PackageName = '',
    [Parameter(Mandatory)][string]$ProjectPath,
    [AllowEmptyString()][string]$Branch = '',
    [Parameter(Mandatory)][string]$Stage,
    [int]$RetentionDays = 14
  )

  BEGIN {
    $fn = 'Initialize-CSharpPackageBuildContext'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn for BuildId='$BuildMasterBuildId'; Application='$ApplicationName'; Stage='$Stage'"

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
      $context = Get-BuildContext -Application $ApplicationName -ProjectPath $ProjectPath -Branch $Branch -Stage $Stage
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
        CurrentTier       = Join-Path -Path $contextDirectory -ChildPath '_current_tier.tmp'
        CeilingTier       = Join-Path -Path $contextDirectory -ChildPath '_ceiling_tier.tmp'
        ResolvedVersion   = Join-Path -Path $contextDirectory -ChildPath '_resolved_version.tmp'
        PrereleaseLabel   = Join-Path -Path $contextDirectory -ChildPath '_prerelease_label.tmp'
        AllowExperimental = Join-Path -Path $contextDirectory -ChildPath '_allow_experimental.tmp'
        AllowDevelopment  = Join-Path -Path $contextDirectory -ChildPath '_allow_development.tmp'
        AllowIntegration  = Join-Path -Path $contextDirectory -ChildPath '_allow_integration.tmp'
        AllowQA           = Join-Path -Path $contextDirectory -ChildPath '_allow_qa.tmp'
        AllowProduction   = Join-Path -Path $contextDirectory -ChildPath '_allow_production.tmp'
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

      $payload = Write-BuildMasterRunContextJson `
        -ContextDirectory $contextDirectory `
        -BuildMasterBuildId $BuildMasterBuildId `
        -BuildNumber $BuildNumber `
        -ExecutionId $ExecutionId `
        -ApplicationName $ApplicationName `
        -Branch $Branch `
        -SourcePath $SourcePath `
        -ProjectPath $ProjectPath `
        -CurrentTier $context.CurrentTier `
        -CeilingTier $context.CeilingTier `
        -ResolvedVersion $capturedResolvedVersion `
        -PrereleaseLabel $capturedPrereleaseLabel `
        -AllowDecisions $allowDecisions `
        -StateFiles $stateFiles `
        -AdditionalData @{ PipelineKind = 'CSharpPackage'; PackageName = $PackageName } `
        -RetentionDays $RetentionDays

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message ("BuildMaster run context initialized: BuildId={0}; BuildNumber={1}; ExecutionId={2}; ContextDirectory={3}; CurrentTier={4}; CeilingTier={5}; ResolvedVersion={6}" -f $BuildMasterBuildId, $BuildNumber, $ExecutionId, $contextDirectory, $context.CurrentTier, $context.CeilingTier, $capturedResolvedVersion)

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

Initialize-CSharpPackageBuildContext `
  -BuildToolingModulePath $BuildToolingModulePath `
  -SourcePath $SourcePath `
  -BuildMasterBuildId $BuildMasterBuildId `
  -BuildNumber $BuildNumber `
  -ExecutionId $ExecutionId `
  -ApplicationName $ApplicationName `
  -PackageName $PackageName `
  -ProjectPath $ProjectPath `
  -Branch $Branch `
  -Stage $Stage `
  -RetentionDays $RetentionDays | Out-Null

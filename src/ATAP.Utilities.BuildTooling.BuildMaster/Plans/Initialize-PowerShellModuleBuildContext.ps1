<#
.SYNOPSIS
  Captures the BuildMaster run-context for a PowerShell-module pipeline stage.

.DESCRIPTION
  Eponymous entry-point script. Resolves Get-BuildContext for the supplied
  module, validates the captured immutable ResolvedVersion across reruns,
  drops per-module *.tmp state markers OtterScript reads via $FileContents(),
  and writes the full build-context.json document.

  Module-scoped behaviour differs from the C# variant in two ways:
    * The state file names are prefixed with $ModuleName so two modules can
      share one run-context directory without colliding.
    * A drift between captured and current ResolvedPackageVersion is reported
      via Write-PSFMessage -Level Important rather than thrown, because the
      captured nupkg version is immutable inside ProGet.

.PARAMETER BuildToolingModulePath
  Path to the ATAP.Utilities.BuildTooling.PowerShell module to import.

.PARAMETER SourcePath
  Working copy / repository root.

.PARAMETER BuildMasterBuildId
  BuildMaster build id used as the per-build context folder name.

.PARAMETER BuildNumber
  Optional BuildMaster build number for traceability.

.PARAMETER ExecutionId
  Optional BuildMaster execution id for traceability.

.PARAMETER ApplicationName
  Product/application this pipeline targets.

.PARAMETER ModuleName
  PowerShell module name being built (drives state-file naming).

.PARAMETER PackageName
  Optional NuGet package id; defaults to ModuleName.

.PARAMETER ModulePath
  Filesystem path to the module's source tree.

.PARAMETER Branch
  Optional source-branch label.

.PARAMETER Stage
  Optional BuildMaster stage hint passed to Get-BuildContext.

.PARAMETER RetentionDays
  Run-context retention window for sibling builds.

.OUTPUTS
  Writes per-module *.tmp markers and build-context.json under the
  run-context directory. No pipeline output.

.EXAMPLE
  pwsh -File Initialize-PowerShellModuleBuildContext.ps1 `
    -BuildToolingModulePath C:\src\repo\src\ATAP.Utilities.BuildTooling.PowerShell `
    -SourcePath C:\src\repo `
    -BuildMasterBuildId 12345 `
    -ApplicationName MyApp `
    -ModuleName ATAP.Utilities.Foo `
    -ModulePath C:\src\repo\src\ATAP.Utilities.Foo

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

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ModuleName,

  [AllowEmptyString()]
  [string]$PackageName = '',

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ModulePath,

  [AllowEmptyString()]
  [string]$Branch = '',

  [AllowEmptyString()]
  [string]$Stage = '',

  [ValidateRange(0, 365)]
  [int]$RetentionDays = 14
)

$ErrorActionPreference = 'Stop'

function Initialize-PowerShellModuleBuildContext {
  <#
  .SYNOPSIS
    Eponymous worker performing PowerShell-module run-context initialisation.
  .DESCRIPTION
    Receives the same parameters as the script entry-point and performs the
    full Get-BuildContext + Write-BuildMasterRunContextJson workflow for a
    single PowerShell module.
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
    [Parameter(Mandatory)][string]$ModuleName,
    [AllowEmptyString()][string]$PackageName = '',
    [Parameter(Mandatory)][string]$ModulePath,
    [AllowEmptyString()][string]$Branch = '',
    [AllowEmptyString()][string]$Stage = '',
    [int]$RetentionDays = 14
  )

  BEGIN {
    $fn = 'Initialize-PowerShellModuleBuildContext'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn for BuildId='$BuildMasterBuildId'; Module='$ModuleName'"

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
      $contextParameters = @{
        Application = $ApplicationName
        ProjectPath = $ModulePath
        Branch      = $Branch
      }
      if (-not [string]::IsNullOrWhiteSpace($Stage)) {
        $contextParameters['Stage'] = $Stage
      }

      $context = Get-BuildContext @contextParameters
      $existingContext = Read-BuildMasterRunContextJson -ContextDirectory $contextDirectory
      $capturedResolvedVersion = [string]$context.ResolvedPackageVersion
      $capturedPrereleaseLabel = [string]$context.PrereleaseLabel
      $effectiveCeilingTier = [string]$context.CeilingTier

      if ($context.CurrentTier -ne 'Experimental') {
        if ($null -eq $existingContext -or [string]::IsNullOrWhiteSpace([string]$existingContext.ResolvedVersion)) {
          throw "BuildMaster run context '$contextDirectory' is missing a captured ResolvedVersion for build id '$BuildMasterBuildId'. Run the Experimental stage first or transfer the build-id context folder."
        }

        if ([string]$existingContext.ResolvedVersion -ne [string]$context.ResolvedPackageVersion) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "BuildMaster run context '$contextDirectory' captured version '$($existingContext.ResolvedVersion)' while this stage resolved '$($context.ResolvedPackageVersion)'; continuing with captured immutable package version."
        }

        $capturedResolvedVersion = [string]$existingContext.ResolvedVersion
        if (-not [string]::IsNullOrWhiteSpace([string]$existingContext.PrereleaseLabel)) {
          $capturedPrereleaseLabel = [string]$existingContext.PrereleaseLabel
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$existingContext.CeilingTier)) {
          $effectiveCeilingTier = [string]$existingContext.CeilingTier
        }
      }

      $allowDecisions = Get-BuildMasterAllowDecisions -CeilingTier $effectiveCeilingTier

      $stateFiles = [ordered]@{
        CeilingTier       = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.ceiling-tier.tmp"
        CurrentTier       = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.current-tier.tmp"
        ResolvedVersion   = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.resolved-version.tmp"
        PrereleaseLabel   = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.prerelease-label.tmp"
        AllowExperimental = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.allow-experimental.tmp"
        AllowDevelopment  = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.allow-development.tmp"
        AllowIntegration  = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.allow-integration.tmp"
        AllowQA           = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.allow-qa.tmp"
        AllowProduction   = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.allow-production.tmp"
      }

      Write-BuildMasterRunStateFiles -StateFiles $stateFiles -Values @{
        CeilingTier       = $effectiveCeilingTier
        CurrentTier       = $context.CurrentTier
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
        -ProjectPath $ModulePath `
        -CurrentTier $context.CurrentTier `
        -CeilingTier $effectiveCeilingTier `
        -ResolvedVersion $capturedResolvedVersion `
        -PrereleaseLabel $capturedPrereleaseLabel `
        -AllowDecisions $allowDecisions `
        -StateFiles $stateFiles `
        -AdditionalData @{ PipelineKind = 'PowerShellModule'; ModuleName = $ModuleName; PackageName = $PackageName } `
        -RetentionDays $RetentionDays

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message ("BuildMaster run context initialized: BuildId={0}; BuildNumber={1}; ExecutionId={2}; ContextDirectory={3}; Module={4}; CurrentTier={5}; CeilingTier={6}; ResolvedVersion={7}" -f $BuildMasterBuildId, $BuildNumber, $ExecutionId, $contextDirectory, $ModuleName, $context.CurrentTier, $effectiveCeilingTier, $capturedResolvedVersion)

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

Initialize-PowerShellModuleBuildContext `
  -BuildToolingModulePath $BuildToolingModulePath `
  -SourcePath $SourcePath `
  -BuildMasterBuildId $BuildMasterBuildId `
  -BuildNumber $BuildNumber `
  -ExecutionId $ExecutionId `
  -ApplicationName $ApplicationName `
  -ModuleName $ModuleName `
  -PackageName $PackageName `
  -ModulePath $ModulePath `
  -Branch $Branch `
  -Stage $Stage `
  -RetentionDays $RetentionDays | Out-Null

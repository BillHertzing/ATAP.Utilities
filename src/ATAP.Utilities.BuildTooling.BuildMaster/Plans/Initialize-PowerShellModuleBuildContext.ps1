#Requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$BuildToolingModulePath,

  [Parameter(Mandatory)]
  [string]$SourcePath,

  [Parameter(Mandatory)]
  [string]$BuildMasterBuildId,

  [AllowEmptyString()]
  [string]$BuildNumber = '',

  [AllowEmptyString()]
  [string]$ExecutionId = '',

  [Parameter(Mandatory)]
  [string]$ApplicationName,

  [Parameter(Mandatory)]
  [string]$ModuleName,

  [AllowEmptyString()]
  [string]$PackageName = '',

  [Parameter(Mandatory)]
  [string]$ModulePath,

  [AllowEmptyString()]
  [string]$Branch = '',

  [Parameter(Mandatory)]
  [string]$Stage,

  [int]$RetentionDays = 14
)

$ErrorActionPreference = 'Stop'
. (Join-Path -Path $PSScriptRoot -ChildPath 'BuildMasterRunContext.Common.ps1')

Import-Module $BuildToolingModulePath -Force

$contextDirectory = Initialize-BuildMasterRunContextDirectory -SourcePath $SourcePath -BuildMasterBuildId $BuildMasterBuildId -RetentionDays $RetentionDays
$context = Get-BuildContext -Application $ApplicationName -ProjectPath $ModulePath -Branch $Branch -Stage $Stage
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
  CeilingTier     = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.ceiling-tier.tmp"
  CurrentTier     = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.current-tier.tmp"
  ResolvedVersion = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.resolved-version.tmp"
  PrereleaseLabel = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.prerelease-label.tmp"
  AllowExperimental = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.allow-experimental.tmp"
  AllowDevelopment  = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.allow-development.tmp"
  AllowIntegration  = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.allow-integration.tmp"
  AllowQA           = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.allow-qa.tmp"
  AllowProduction   = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.allow-production.tmp"
}

Write-BuildMasterRunStateFiles -StateFiles $stateFiles -Values @{
  CeilingTier       = $context.CeilingTier
  CurrentTier       = $context.CurrentTier
  ResolvedVersion   = $capturedResolvedVersion
  PrereleaseLabel   = $capturedPrereleaseLabel
  AllowExperimental = $allowDecisions['Experimental'].ToString().ToLowerInvariant()
  AllowDevelopment  = $allowDecisions['Development'].ToString().ToLowerInvariant()
  AllowIntegration  = $allowDecisions['Integration'].ToString().ToLowerInvariant()
  AllowQA           = $allowDecisions['QA'].ToString().ToLowerInvariant()
  AllowProduction   = $allowDecisions['Production'].ToString().ToLowerInvariant()
}

Write-BuildMasterRunContextJson `
  -ContextDirectory $contextDirectory `
  -BuildMasterBuildId $BuildMasterBuildId `
  -BuildNumber $BuildNumber `
  -ExecutionId $ExecutionId `
  -ApplicationName $ApplicationName `
  -Branch $Branch `
  -SourcePath $SourcePath `
  -ProjectPath $ModulePath `
  -CurrentTier $context.CurrentTier `
  -CeilingTier $context.CeilingTier `
  -ResolvedVersion $capturedResolvedVersion `
  -PrereleaseLabel $capturedPrereleaseLabel `
  -AllowDecisions $allowDecisions `
  -StateFiles $stateFiles `
  -AdditionalData @{ PipelineKind = 'PowerShellModule'; ModuleName = $ModuleName; PackageName = $PackageName } `
  -RetentionDays $RetentionDays | Out-Null

Write-Host ("BuildMaster run context initialized: BuildId={0}; BuildNumber={1}; ExecutionId={2}; ContextDirectory={3}; Module={4}; CurrentTier={5}; CeilingTier={6}; ResolvedVersion={7}" -f $BuildMasterBuildId, $BuildNumber, $ExecutionId, $contextDirectory, $ModuleName, $context.CurrentTier, $context.CeilingTier, $capturedResolvedVersion)

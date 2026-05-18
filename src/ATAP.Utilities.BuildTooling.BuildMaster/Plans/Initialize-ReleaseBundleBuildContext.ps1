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
  [string]$ProductName,

  [AllowEmptyString()]
  [string]$ReleaseTag = '',

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

Write-BuildMasterRunContextJson `
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
  -RetentionDays $RetentionDays | Out-Null

Write-Host ("BuildMaster run context initialized: BuildId={0}; BuildNumber={1}; ExecutionId={2}; ContextDirectory={3}; Product={4}; ReleaseTag={5}; CurrentTier={6}; CeilingTier={7}; ResolvedVersion={8}" -f $BuildMasterBuildId, $BuildNumber, $ExecutionId, $contextDirectory, $ProductName, $ReleaseTag, $context.CurrentTier, $context.CeilingTier, $capturedResolvedVersion)

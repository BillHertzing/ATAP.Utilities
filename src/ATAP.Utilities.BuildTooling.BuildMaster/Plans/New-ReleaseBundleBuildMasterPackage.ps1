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
  [string]$ContextDirectory,

  [Parameter(Mandatory)]
  [string]$ReleaseBundleContextFile,

  [Parameter(Mandatory)]
  [string]$ReleaseBundleNameFile,

  [Parameter(Mandatory)]
  [string]$ReleaseBundleResolvedVersionFile,

  [Parameter(Mandatory)]
  [string]$ReleaseBundleBundleVersionFile,

  [Parameter(Mandatory)]
  [string]$ReleaseBundlePathFile,

  [Parameter(Mandatory)]
  [string]$ReleaseBundleManifestPathFile,

  [Parameter(Mandatory)]
  [string]$ReleaseBundleExperimentalFeedName,

  [Parameter(Mandatory)]
  [string]$CeilingTier,

  [Parameter(Mandatory)]
  [string]$ProGetUrl,

  [Parameter(Mandatory)]
  [string]$ProGetApiKey,

  [int]$RetentionDays = 14
)

$ErrorActionPreference = 'Stop'
. (Join-Path -Path $PSScriptRoot -ChildPath 'BuildMasterRunContext.Common.ps1')

Import-Module $BuildToolingModulePath -Force

if (-not (Test-Path -LiteralPath $ReleaseBundleContextFile)) {
  throw "ReleaseBundle context file '$ReleaseBundleContextFile' is missing. Run Initialize-ReleaseBundleBuildContext.ps1 first."
}

$context = Get-Content -LiteralPath $ReleaseBundleContextFile -Raw | ConvertFrom-Json -ErrorAction Stop
$env:PROGET_ADMIN_API_KEY = $ProGetApiKey
$env:PROGET_BUILDMASTER_API_KEY = $ProGetApiKey
$global:ProGetBaseUrl = $ProGetUrl

$manifestOutputPath = Join-Path -Path $SourcePath -ChildPath '_generated/release-manifest/manifest.json'
$bundleOutputPath = Join-Path -Path $SourcePath -ChildPath '_generated/release-bundle'

$manifest = New-ReleaseManifest -Context $context -OutputPath $manifestOutputPath
$bundle = New-ReleaseBundle -Manifest $manifest -OutputPath $bundleOutputPath -SourceRoot $SourcePath
Publish-UniversalPackageToProGet -Path $bundle.Path.FullName -Feed $ReleaseBundleExperimentalFeedName -CeilingTier $CeilingTier

Write-BuildMasterRunContextTextFile -Path $ReleaseBundleNameFile -Value $context.Application
Write-BuildMasterRunContextTextFile -Path $ReleaseBundleResolvedVersionFile -Value $context.ResolvedPackageVersion
Write-BuildMasterRunContextTextFile -Path $ReleaseBundleBundleVersionFile -Value $bundle.BundleVersion
Write-BuildMasterRunContextTextFile -Path $ReleaseBundlePathFile -Value $bundle.Path.FullName
Write-BuildMasterRunContextTextFile -Path $ReleaseBundleManifestPathFile -Value $manifest.FullName

$allowDecisions = Get-BuildMasterAllowDecisions -CeilingTier $CeilingTier
Write-BuildMasterRunContextJson `
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
    PipelineKind       = 'ReleaseBundle'
    ProductName        = $context.Application
    BundleVersion      = $bundle.BundleVersion
    BundlePath         = $bundle.Path.FullName
    ManifestPath       = $manifest.FullName
    ExperimentalFeed   = $ReleaseBundleExperimentalFeedName
  } `
  -RetentionDays $RetentionDays | Out-Null

Write-Host ("ReleaseBundle captured: BuildId={0}; ContextDirectory={1}; Product={2}; ResolvedVersion={3}; BundleVersion={4}; BundlePath={5}" -f $BuildMasterBuildId, $ContextDirectory, $context.Application, $context.ResolvedPackageVersion, $bundle.BundleVersion, $bundle.Path.FullName)

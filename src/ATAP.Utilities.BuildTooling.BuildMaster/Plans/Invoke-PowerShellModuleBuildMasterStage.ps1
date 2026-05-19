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

  [AllowEmptyString()]
  [string]$ModulePath = '',

  [AllowEmptyString()]
  [string]$Branch = '',

  [AllowEmptyString()]
  [string]$Stage = '',

  [AllowEmptyString()]
  [string]$PackageOutputPath = '',

  [AllowEmptyString()]
  [string]$NupkgPathFile = '',

  [AllowEmptyString()]
  [string]$CurrentTier = '',

  [AllowEmptyString()]
  [string]$CeilingTier = '',

  [AllowEmptyString()]
  [string]$ResolvedPackageVersion = '',

  [Parameter(Mandatory)]
  [string]$ProGetUrl,

  [Parameter(Mandatory)]
  [string]$ProGetApiKey,

  [AllowEmptyString()]
  [string]$AllowExperimental = '',

  [AllowEmptyString()]
  [string]$AllowDevelopment = '',

  [AllowEmptyString()]
  [string]$AllowIntegration = '',

  [AllowEmptyString()]
  [string]$AllowQA = '',

  [AllowEmptyString()]
  [string]$AllowProduction = '',

  [string]$ExperimentalFeed = 'powershellget-experimental',
  [string]$DevelopmentFeed = 'powershellget-development',
  [string]$IntegrationFeed = 'powershellget-integration',
  [string]$QAFeed = 'powershellget-qa',
  [string]$ProductionFeed = 'powershellget-stable'
)

$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath 'BuildMasterRunContext.Common.ps1')

if (-not (Get-Command -Name Write-PSFMessage -CommandType Function -ErrorAction SilentlyContinue)) {
  function Write-PSFMessage {
    param(
      [string]$FunctionName,
      [string]$ModuleName,
      [string]$Level,
      [string]$Message,
      [string[]]$Tag
    )
    if ($Level -in @('Important', 'Warning', 'Error')) {
      Write-Host "$Level [$FunctionName] $Message"
    }
  }
}

$buildToolingRoot = Split-Path -Parent $BuildToolingModulePath

function Resolve-BuildToolingFunctionFile {
  param(
    [Parameter(Mandatory)]
    [string]$RelativePath
  )

  $path = Join-Path -Path $buildToolingRoot -ChildPath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Required BuildTooling function file not found: $path"
  }

  return $path
}

. (Resolve-BuildToolingFunctionFile -RelativePath 'private/Get-CeilingFromPrereleaseLabel.ps1')
. (Resolve-BuildToolingFunctionFile -RelativePath 'private/Get-CurrentTierFromStage.ps1')
. (Resolve-BuildToolingFunctionFile -RelativePath 'public/Get-TierOrder.ps1')
. (Resolve-BuildToolingFunctionFile -RelativePath 'public/Resolve-FeatureSlug.ps1')
. (Resolve-BuildToolingFunctionFile -RelativePath 'public/Test-PromotionWithinCeiling.ps1')
. (Resolve-BuildToolingFunctionFile -RelativePath 'public/Get-BuildContext.ps1')
. (Resolve-BuildToolingFunctionFile -RelativePath 'public/Invoke-ModuleBuildWithRetry.ps1')

function Add-GitSafeDirectoryForCurrentProcess {
  param(
    [Parameter(Mandatory)]
    [string]$RepositoryPath
  )

  $safeDirectory = [System.IO.Path]::GetFullPath($RepositoryPath).Replace('\', '/')
  $count = 0
  if (-not [string]::IsNullOrWhiteSpace($env:GIT_CONFIG_COUNT)) {
    $count = [int]$env:GIT_CONFIG_COUNT
  }

  [Environment]::SetEnvironmentVariable("GIT_CONFIG_KEY_$count", 'safe.directory', 'Process')
  [Environment]::SetEnvironmentVariable("GIT_CONFIG_VALUE_$count", $safeDirectory, 'Process')
  [Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT', ($count + 1).ToString([Globalization.CultureInfo]::InvariantCulture), 'Process')
  Write-Host "Configured process-local git safe.directory for '$safeDirectory'."
}

function Get-PowerShellGetFeedUri {
  param(
    [Parameter(Mandatory)]
    [string]$BaseUrl,

    [Parameter(Mandatory)]
    [string]$FeedName
  )

  return ('{0}/nuget/{1}/' -f $BaseUrl.TrimEnd('/'), $FeedName)
}

function Convert-BuildMasterTierToModuleBuildTier {
  param(
    [Parameter(Mandatory)]
    [string]$Tier
  )

  switch ($Tier.Trim().ToLowerInvariant()) {
    'experimental' { return 'Sprint' }
    'development'  { return 'Alpha' }
    'integration'  { return 'Beta' }
    'qa'           { return 'QA' }
    'production'   { return 'Production' }
    default {
      throw "Unsupported BuildMaster tier '$Tier'. Expected one of: Experimental, Development, Integration, QA, Production."
    }
  }
}

function Find-LatestPowerShellModulePackage {
  param(
    [Parameter(Mandatory)]
    [string]$PackageDirectory
  )

  if (-not (Test-Path -LiteralPath $PackageDirectory -PathType Container)) {
    throw "PowerShell module package directory does not exist after module.build.ps1 ran: $PackageDirectory"
  }

  $package = Get-ChildItem -LiteralPath $PackageDirectory -Filter '*.nupkg' -File |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1

  if ($null -eq $package) {
    throw "module.build.ps1 did not produce a .nupkg under '$PackageDirectory'."
  }

  return $package
}

function Publish-PowerShellModulePackageToExperimental {
  param(
    [Parameter(Mandatory)]
    [string]$NupkgPath,

    [Parameter(Mandatory)]
    [string]$FeedName,

    [Parameter(Mandatory)]
    [string]$ApiKey
  )

  try {
    Publish-PSResource -NupkgPath $NupkgPath -Repository $FeedName -ApiKey $ApiKey
    return "Published '$NupkgPath' to '$FeedName'."
  } catch {
    $message = [string]$_.Exception.Message
    if ($message -match '(?i)already exists|already present|duplicate version|409') {
      return "Package '$NupkgPath' is already present in '$FeedName'; treating re-execution as idempotent success."
    }

    throw
  }
}

function Add-BuildMasterPublishTrace {
  param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [string]$Message
  )

  $line = '{0:u} {1}' -f [datetime]::UtcNow, $Message
  Add-Content -LiteralPath $Path -Value $line -Encoding utf8
}

function Select-ModuleBuildRetryResult {
  param(
    [Parameter(ValueFromPipeline)]
    [object]$InputObject
  )

  process {
    if ($null -ne $InputObject -and $InputObject.PSObject.Properties.Name -contains 'ExitCode') {
      $InputObject
    }
  }
}

function Ensure-PSResourceRepository {
  param(
    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter(Mandatory)]
    [string]$Uri
  )

  $existing = Get-PSResourceRepository -Name $Name -ErrorAction SilentlyContinue
  if ($null -eq $existing) {
    Register-PSResourceRepository -Name $Name -Uri $Uri -Trusted
    return
  }

  if ([string]$existing.Uri -ne $Uri) {
    Set-PSResourceRepository -Name $Name -Uri $Uri -Trusted
  }
}

if ([string]::IsNullOrWhiteSpace($PackageName)) {
  $PackageName = $ModuleName
}

if ([string]::IsNullOrWhiteSpace($ModulePath)) {
  $ModulePath = Join-Path -Path $SourcePath -ChildPath "src/$ModuleName"
}

$neoConfigurationPath = Join-Path -Path $SourcePath -ChildPath 'src/ATAP.Utilities.PowerShell/public/Get-ParameterValueFromNeoConfigurationRoot.ps1'
if (-not (Get-Command -Name Get-ParameterValueFromNeoConfigurationRoot -CommandType Function -ErrorAction SilentlyContinue)) {
  if (-not (Test-Path -LiteralPath $neoConfigurationPath -PathType Leaf)) {
    throw "Required NeoConfigurationRoot helper not found: $neoConfigurationPath"
  }

  . $neoConfigurationPath
}
Set-Alias -Name Get-PVal -Value Get-ParameterValueFromNeoConfigurationRoot -Scope Global -Force

Add-GitSafeDirectoryForCurrentProcess -RepositoryPath $SourcePath

$contextDirectory = Initialize-BuildMasterRunContextDirectory -SourcePath $SourcePath -BuildMasterBuildId $BuildMasterBuildId
$contextParameters = @{
  Application = $ApplicationName
  ProjectPath = $ModulePath
  Branch      = $Branch
}
if (-not [string]::IsNullOrWhiteSpace($Stage)) {
  $contextParameters['Stage'] = $Stage
}

$context = Get-BuildContext @contextParameters
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
  -AdditionalData @{ PipelineKind = 'PowerShellModule'; ModuleName = $ModuleName; PackageName = $PackageName } | Out-Null

$moduleBuildPackageOutputPath = Join-Path -Path $SourcePath -ChildPath "_generated/psmodules/$ModuleName/packages"
if ([string]::IsNullOrWhiteSpace($PackageOutputPath)) {
  $PackageOutputPath = $moduleBuildPackageOutputPath
} elseif ([System.IO.Path]::GetFullPath($PackageOutputPath) -ne [System.IO.Path]::GetFullPath($moduleBuildPackageOutputPath)) {
  Write-Host "Ignoring PackageOutputPath '$PackageOutputPath' because module.build.ps1 writes packages to '$moduleBuildPackageOutputPath'."
  $PackageOutputPath = $moduleBuildPackageOutputPath
}

if ([string]::IsNullOrWhiteSpace($NupkgPathFile)) {
  $NupkgPathFile = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.nupkg-path.tmp"
}

$tier = $context.CurrentTier.Trim()
$ceilingTier = [string]$context.CeilingTier
$allowByTier = @{
  Experimental = [bool]$allowDecisions['Experimental']
  Development  = [bool]$allowDecisions['Development']
  Integration  = [bool]$allowDecisions['Integration']
  QA           = [bool]$allowDecisions['QA']
  Production   = [bool]$allowDecisions['Production']
}

if (-not $allowByTier.ContainsKey($tier)) {
  throw "Unsupported BuildMaster tier '$($context.CurrentTier)'."
}

if (-not $allowByTier[$tier]) {
  Write-Host "Skipping PowerShell module stage '$tier' because ceiling '$ceilingTier' does not allow it."
  return
}

Push-Location -LiteralPath $SourcePath
try {
  switch ($tier) {
    'Experimental' {
      New-Item -ItemType Directory -Path (Split-Path -Parent $NupkgPathFile) -Force | Out-Null
      $moduleBuildTier = Convert-BuildMasterTierToModuleBuildTier -Tier $tier
      $buildLogPath = Join-Path -Path $contextDirectory -ChildPath 'PSModuleBuildLogs'
      $buildResults = @(
        Invoke-ModuleBuildWithRetry `
          -ProjectPath $ModulePath `
          -Tier $moduleBuildTier `
          -Task CI `
          -SkipPublish `
          -MaxRetries 1 `
          -BuildLogPath $buildLogPath
      )
      $moduleBuildRetryResults = @($buildResults | Select-ModuleBuildRetryResult)
      if ($moduleBuildRetryResults.Count -eq 0) {
        throw "Invoke-ModuleBuildWithRetry did not return a result object for '$ModuleName'."
      }

      $failedBuildResults = @($moduleBuildRetryResults | Where-Object { [int]$_.ExitCode -ne 0 })
      if ($failedBuildResults.Count -gt 0) {
        $failureSummary = ($failedBuildResults | ForEach-Object { $_.BuildOutput -join [Environment]::NewLine }) -join [Environment]::NewLine
        throw "module.build.ps1 failed for '$ModuleName' at BuildMaster tier '$tier' (module.build tier '$moduleBuildTier'). $failureSummary"
      }

      $nupkg = Find-LatestPowerShellModulePackage -PackageDirectory $PackageOutputPath
      $nupkg.FullName | Set-Content -LiteralPath $NupkgPathFile -Encoding utf8 -NoNewline

      $publishTracePath = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.publish.log"
      $feedUri = Get-PowerShellGetFeedUri -BaseUrl $ProGetUrl -FeedName $ExperimentalFeed
      Add-BuildMasterPublishTrace -Path $publishTracePath -Message "Using PowerShellGet feed '$ExperimentalFeed' at '$feedUri'."
      Ensure-PSResourceRepository -Name $ExperimentalFeed -Uri $feedUri
      Add-BuildMasterPublishTrace -Path $publishTracePath -Message "PSResourceRepository '$ExperimentalFeed' is registered."

      $env:PROGET_APIKEY_POWERSHELLGET_EXPERIMENTAL = $ProGetApiKey
      $env:PROGET_ADMIN_API_KEY = $ProGetApiKey

      try {
        $publishSummary = Publish-PowerShellModulePackageToExperimental -NupkgPath $nupkg.FullName -FeedName $ExperimentalFeed -ApiKey $ProGetApiKey
        Add-BuildMasterPublishTrace -Path $publishTracePath -Message $publishSummary
      } catch {
        Add-BuildMasterPublishTrace -Path $publishTracePath -Message "ERROR: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
        throw
      }
      Write-Host "$publishSummary Ceiling='$ceilingTier'. module.build.ps1 tier='$moduleBuildTier'."
    }

    default {
      throw "PowerShell module BuildMaster runner reached '$tier', but promotion/test execution for this step-compatible runner is not implemented yet."
    }
  }
} finally {
  Pop-Location
}

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

# Load Helpers
try {
  # ToDo: Remove this when packaging works
  $temporaryPowerShellHelperRootCandidates = @(
    (Join-Path -Path $SourcePath -ChildPath 'src/ATAP.Utilities.PowerShell/public'),
    'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public'
  )

  foreach ($helperName in @(
      'Get-ParameterValueFromNeoConfigurationRoot',
      'Get-ClonedAndModifiedHashtable'
    )) {
    if (-not (Get-Command -Name $helperName -CommandType Function -ErrorAction SilentlyContinue)) {
      $helperPath = $temporaryPowerShellHelperRootCandidates |
        ForEach-Object { Join-Path -Path $_ -ChildPath "$helperName.ps1" } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1

      if ([string]::IsNullOrWhiteSpace($helperPath)) {
        throw "Required helper function '$helperName' could not be found under: $($temporaryPowerShellHelperRootCandidates -join '; ')"
      }

      . $helperPath
    }
  }

  Set-Alias -Name Get-PVal -Value Get-ParameterValueFromNeoConfigurationRoot -Scope Global -Force
}
catch {
  $errorMessage = "Failed to load temporary PowerShell helper functions. Exception: $($_.Exception.Message)"
  Write-PSFMessage -FunctionName 'Invoke-PowerShellModuleBuildMasterStage' -ModuleName 'ATAP.Utilities.BuildTooling.BuildMaster' -Level Error -Message $errorMessage
  throw
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
. (Resolve-BuildToolingFunctionFile -RelativePath 'public/Move-ProGetPackageInterTier.ps1')
. (Resolve-BuildToolingFunctionFile -RelativePath 'public/Promote-ProGetPackage.ps1')
. (Resolve-BuildToolingFunctionFile -RelativePath 'public/Invoke-PSModulePesterTests.ps1')
. (Resolve-BuildToolingFunctionFile -RelativePath 'public/Invoke-PromotedModuleTests.ps1')

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

function Get-PowerShellModulePackageVersionFromNupkgPath {
  param(
    [Parameter(Mandatory)]
    [string]$NupkgPath,

    [Parameter(Mandatory)]
    [string]$PackageName
  )

  if ([string]::IsNullOrWhiteSpace($NupkgPath)) {
    throw 'PowerShell module package path is empty; run the Experimental stage first.'
  }

  $leaf = [System.IO.Path]::GetFileNameWithoutExtension($NupkgPath.Trim())
  $prefix = "$PackageName."
  if (-not $leaf.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PowerShell module package '$NupkgPath' does not match expected package name '$PackageName'."
  }

  $version = $leaf.Substring($prefix.Length)
  if ([string]::IsNullOrWhiteSpace($version)) {
    throw "Could not derive package version from '$NupkgPath'."
  }

  return $version
}

function Test-ProGetPackageVersionInFeed {
  param(
    [Parameter(Mandatory)]
    [string]$BaseUrl,

    [Parameter(Mandatory)]
    [string]$FeedName,

    [Parameter(Mandatory)]
    [string]$PackageName,

    [Parameter(Mandatory)]
    [string]$Version,

    [Parameter(Mandatory)]
    [string]$ApiKey
  )

  function Test-ProGetPackageVersionMatch {
    param(
      [Parameter(Mandatory = $false)]
      [AllowNull()]
      [object]$Value,

      [Parameter(Mandatory)]
      [string]$ExpectedVersion
    )

    if ($null -eq $Value) {
      return $false
    }

    if ($Value -is [string]) {
      return ([string]$Value -eq $ExpectedVersion)
    }

    if ($Value -is [System.Collections.IEnumerable]) {
      foreach ($entry in $Value) {
        if (Test-ProGetPackageVersionMatch -Value $entry -ExpectedVersion $ExpectedVersion) {
          return $true
        }
      }
      return $false
    }

    $propertyNames = @($Value.PSObject.Properties.Name)
    foreach ($versionProperty in @('version', 'Version', 'packageVersion', 'PackageVersion', 'versionNumber', 'VersionNumber')) {
      if ($propertyNames -contains $versionProperty) {
        if ([string]$Value.$versionProperty -eq $ExpectedVersion) {
          return $true
        }
      }
    }

    foreach ($collectionProperty in @('versions', 'Versions', 'items', 'Items', 'data', 'Data')) {
      if ($propertyNames -contains $collectionProperty) {
        if (Test-ProGetPackageVersionMatch -Value $Value.$collectionProperty -ExpectedVersion $ExpectedVersion) {
          return $true
        }
      }
    }

    return $false
  }

  $trimmedBaseUrl = $BaseUrl.TrimEnd('/')
  $checkUrl = "$trimmedBaseUrl/api/packages/$FeedName/versions" +
    "?name=$([uri]::EscapeDataString($PackageName))&version=$([uri]::EscapeDataString($Version))"
  $headers = @{
    'Accept'   = 'application/json'
    'X-ApiKey' = $ApiKey
  }

  try {
    $response = Invoke-RestMethod -Uri $checkUrl -Headers $headers -Method Get -TimeoutSec 15 -ErrorAction Stop
  } catch {
    return $false
  }

  return (Test-ProGetPackageVersionMatch -Value $response -ExpectedVersion $Version)
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

function Assert-BuildMasterOperationSucceeded {
  param(
    [Parameter(Mandatory)]
    [object]$Result,

    [Parameter(Mandatory)]
    [string]$OperationName
  )

  if ($null -eq $Result) {
    throw "$OperationName did not return a result object."
  }

  if ($Result.PSObject.Properties.Name -contains 'Succeeded' -and -not [bool]$Result.Succeeded) {
    throw "$OperationName reported Succeeded=false. $($Result.ResponseSummary)"
  }

  if ($Result.PSObject.Properties.Name -contains 'GatePass' -and -not [bool]$Result.GatePass) {
    throw "$OperationName reported GatePass=false. $($Result.ResponseSummary)"
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
    Register-PSResourceRepository -Name $Name -Uri $Uri -Trusted -ApiVersion V2
    return
  }

  Set-PSResourceRepository -Name $Name -Uri $Uri -Trusted -ApiVersion V2
}

function Get-PowerShellModuleStageCompletionMarkerPath {
  param(
    [Parameter(Mandatory)]
    [string]$ContextDirectory,

    [Parameter(Mandatory)]
    [string]$ModuleName,

    [Parameter(Mandatory)]
    [string]$Tier
  )

  return (Join-Path -Path $ContextDirectory -ChildPath "$ModuleName.$Tier.completed.tmp")
}

function Set-PowerShellModuleStageCompleted {
  param(
    [Parameter(Mandatory)]
    [string]$ContextDirectory,

    [Parameter(Mandatory)]
    [string]$ModuleName,

    [Parameter(Mandatory)]
    [string]$Tier,

    [Parameter(Mandatory)]
    [string]$PackageVersion
  )

  $markerPath = Get-PowerShellModuleStageCompletionMarkerPath -ContextDirectory $ContextDirectory -ModuleName $ModuleName -Tier $Tier
  $payload = [ordered]@{
    Tier           = $Tier
    PackageVersion = $PackageVersion
    CompletedUtc   = [datetime]::UtcNow.ToString('o')
  }
  $payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $markerPath -Encoding utf8
}

function Test-PowerShellModuleStageCompleted {
  param(
    [Parameter(Mandatory)]
    [string]$ContextDirectory,

    [Parameter(Mandatory)]
    [string]$ModuleName,

    [Parameter(Mandatory)]
    [string]$Tier
  )

  $markerPath = Get-PowerShellModuleStageCompletionMarkerPath -ContextDirectory $ContextDirectory -ModuleName $ModuleName -Tier $Tier
  return (Test-Path -LiteralPath $markerPath -PathType Leaf)
}

function Get-PreviousBuildMasterTier {
  param(
    [Parameter(Mandatory)]
    [string]$Tier
  )

  $tierOrder = @(Get-TierOrder)
  $tierIndex = $tierOrder.IndexOf($Tier)
  if ($tierIndex -le 0) {
    throw "Tier '$Tier' does not have a previous promotion tier."
  }

  return $tierOrder[$tierIndex - 1]
}

function Get-PowerShellModulePackageVersionForRun {
  param(
    [Parameter(Mandatory)]
    [string]$ContextDirectory,

    [Parameter(Mandatory)]
    [string]$NupkgPathFile,

    [Parameter(Mandatory)]
    [string]$PackageName
  )

  if (Test-Path -LiteralPath $NupkgPathFile -PathType Leaf) {
    $nupkgPath = (Get-Content -LiteralPath $NupkgPathFile -Raw).Trim()
    if (-not [string]::IsNullOrWhiteSpace($nupkgPath) -and (Test-Path -LiteralPath $nupkgPath -PathType Leaf)) {
      return (Get-PowerShellModulePackageVersionFromNupkgPath -NupkgPath $nupkgPath -PackageName $PackageName)
    }
  }

  $runContext = Read-BuildMasterRunContextJson -ContextDirectory $ContextDirectory
  if ($null -ne $runContext -and $runContext.PSObject.Properties.Name -contains 'PackageVersion') {
    $packageVersion = [string]$runContext.PackageVersion
    if (-not [string]::IsNullOrWhiteSpace($packageVersion)) {
      return $packageVersion
    }
  }

  throw "PowerShell module package version is not captured for build context '$ContextDirectory'; run the Experimental stage first."
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
$existingContext = Read-BuildMasterRunContextJson -ContextDirectory $contextDirectory
$capturedResolvedVersion = [string]$context.ResolvedPackageVersion
$capturedPrereleaseLabel = [string]$context.PrereleaseLabel
$effectiveCeilingTier = [string]$context.CeilingTier

if ($context.CurrentTier -ne 'Experimental') {
  if ($null -eq $existingContext -or [string]::IsNullOrWhiteSpace([string]$existingContext.ResolvedVersion)) {
    throw "BuildMaster run context '$contextDirectory' is missing a captured ResolvedVersion for build id '$BuildMasterBuildId'. Run the Experimental stage first or transfer the build-id context folder."
  }

  if ([string]$existingContext.ResolvedVersion -ne [string]$context.ResolvedPackageVersion) {
    Write-Host "BuildMaster run context '$contextDirectory' captured version '$($existingContext.ResolvedVersion)' while this stage resolved '$($context.ResolvedPackageVersion)'; continuing with captured immutable package version."
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
  -CeilingTier $effectiveCeilingTier `
  -ResolvedVersion $capturedResolvedVersion `
  -PrereleaseLabel $capturedPrereleaseLabel `
  -AllowDecisions $allowDecisions `
  -StateFiles $stateFiles `
  -AdditionalData @{ PipelineKind = 'PowerShellModule'; ModuleName = $ModuleName; PackageName = $PackageName } | Out-Null

function Update-PowerShellModulePackageContext {
  param(
    [Parameter(Mandatory)]
    [string]$PackageVersion,

    [AllowEmptyString()]
    [string]$NupkgPath = ''
  )

  $additionalData = @{
    PipelineKind   = 'PowerShellModule'
    ModuleName     = $ModuleName
    PackageName    = $PackageName
    PackageVersion = $PackageVersion
  }
  if (-not [string]::IsNullOrWhiteSpace($NupkgPath)) {
    $additionalData['NupkgPath'] = $NupkgPath
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
    -CeilingTier $ceilingTier `
    -ResolvedVersion $capturedResolvedVersion `
    -PrereleaseLabel $capturedPrereleaseLabel `
    -AllowDecisions $allowDecisions `
    -StateFiles $stateFiles `
    -AdditionalData $additionalData | Out-Null
}

$moduleBuildOutputRoot = Join-Path -Path $contextDirectory -ChildPath "psmodules/$ModuleName"
$moduleBuildPackageOutputPath = Join-Path -Path $moduleBuildOutputRoot -ChildPath 'packages'
if ([string]::IsNullOrWhiteSpace($PackageOutputPath)) {
  $PackageOutputPath = $moduleBuildPackageOutputPath
} elseif ([System.IO.Path]::GetFullPath($PackageOutputPath) -ne [System.IO.Path]::GetFullPath($moduleBuildPackageOutputPath)) {
  Write-Host "Ignoring PackageOutputPath '$PackageOutputPath' because BuildMaster runs module.build.ps1 with build-scoped package output '$moduleBuildPackageOutputPath'."
  $PackageOutputPath = $moduleBuildPackageOutputPath
}

if ([string]::IsNullOrWhiteSpace($NupkgPathFile)) {
  $NupkgPathFile = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.nupkg-path.tmp"
}

$tier = $context.CurrentTier.Trim()
$ceilingTier = $effectiveCeilingTier
$allowByTier = @{
  Experimental = [bool]$allowDecisions['Experimental']
  Development  = [bool]$allowDecisions['Development']
  Integration  = [bool]$allowDecisions['Integration']
  QA           = [bool]$allowDecisions['QA']
  Production   = [bool]$allowDecisions['Production']
}
$feedByTier = @{
  Experimental = $ExperimentalFeed
  Development  = $DevelopmentFeed
  Integration  = $IntegrationFeed
  QA           = $QAFeed
  Production   = $ProductionFeed
}

function Invoke-PowerShellModulePromotionAndTests {
  param(
    [Parameter(Mandatory)]
    [string]$Tier,

    [Parameter(Mandatory)]
    [string]$PromotedPackageVersion
  )

  $previousTier = Get-PreviousBuildMasterTier -Tier $Tier
  $sourceFeed = $feedByTier[$previousTier]
  $destinationFeed = $feedByTier[$Tier]
  if ([string]::IsNullOrWhiteSpace($sourceFeed) -or [string]::IsNullOrWhiteSpace($destinationFeed)) {
    throw "Cannot resolve PowerShellGet promotion feeds for '$previousTier' -> '$Tier'."
  }

  Write-Host "PowerShell module stage '$Tier' starting promotion/test for '$PackageName' version '$PromotedPackageVersion' from '$sourceFeed' to '$destinationFeed'."
  $promotionTracePath = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.$($Tier.ToLowerInvariant()).log"
  Add-BuildMasterPublishTrace -Path $promotionTracePath -Message "Promoting '$PackageName' version '$PromotedPackageVersion' from '$sourceFeed' to '$destinationFeed'. Captured resolved version is '$capturedResolvedVersion'."

  $env:PROGET_BUILDMASTER_API_KEY = $ProGetApiKey
  $global:ProGetBaseUrl = $ProGetUrl

  $destinationFeedUri = Get-PowerShellGetFeedUri -BaseUrl $ProGetUrl -FeedName $destinationFeed
  Ensure-PSResourceRepository -Name $destinationFeed -Uri $destinationFeedUri
  Add-BuildMasterPublishTrace -Path $promotionTracePath -Message "PSResourceRepository '$destinationFeed' is registered at '$destinationFeedUri'."

  Write-Host "Promoting '$PackageName' version '$PromotedPackageVersion' from '$sourceFeed' to '$destinationFeed'."
  $promotionResult = Promote-ProGetPackage `
    -Name $PackageName `
    -Version $PromotedPackageVersion `
    -FromFeed $sourceFeed `
    -ToFeed $destinationFeed `
    -Reason "$Tier gate for $ApplicationName $PromotedPackageVersion on $Branch" `
    -CeilingTier $ceilingTier
  Assert-BuildMasterOperationSucceeded -Result $promotionResult -OperationName 'Promote-ProGetPackage'
  Add-BuildMasterPublishTrace -Path $promotionTracePath -Message $promotionResult.ResponseSummary

  $resultsPath = Join-Path -Path $contextDirectory -ChildPath "$($Tier)TestResults"
  $testResult = Invoke-PromotedModuleTests `
    -Name $PackageName `
    -Version $PromotedPackageVersion `
    -Feed $destinationFeed `
    -Tier $Tier `
    -ResultsPath $resultsPath `
    -ModuleSourceRoot $ModulePath `
    -WorkingDirectory $SourcePath `
    -ProGetBaseUrl $ProGetUrl `
    -ApiKey $ProGetApiKey `
    -PesterOutputVerbosity None
  Assert-BuildMasterOperationSucceeded -Result $testResult -OperationName 'Invoke-PromotedModuleTests'
  Add-BuildMasterPublishTrace -Path $promotionTracePath -Message $testResult.ResponseSummary

  Write-Host "Promoted '$PackageName' version '$PromotedPackageVersion' to '$destinationFeed' and passed $Tier tests. Ceiling='$ceilingTier'."
}

if (-not $allowByTier.ContainsKey($tier)) {
  throw "Unsupported BuildMaster tier '$($context.CurrentTier)'."
}

if (-not $allowByTier[$tier]) {
  throw "PowerShell module stage '$tier' exceeds version ceiling '$ceilingTier' for build '$BuildMasterBuildId'. Refusing deployment so BuildMaster does not advance stages above the package ceiling."
}

$tierOrder = @(Get-TierOrder)
$currentTierIndex = $tierOrder.IndexOf($tier)
$ceilingTierIndex = $tierOrder.IndexOf($ceilingTier)
if ($currentTierIndex -lt 0) {
  throw "Unsupported BuildMaster tier '$tier'."
}
if ($ceilingTierIndex -lt 0) {
  throw "Unsupported BuildMaster ceiling tier '$ceilingTier'."
}

$tiersToRun = @()
for ($tierIndex = $currentTierIndex; $tierIndex -le $ceilingTierIndex; $tierIndex++) {
  $tiersToRun += $tierOrder[$tierIndex]
}
Write-Host "PowerShell module runner will execute tier(s): $($tiersToRun -join ', ') (current='$tier'; ceiling='$ceilingTier')."

$packageVersionForRun = $null

Push-Location -LiteralPath $SourcePath
try {
  foreach ($tierToRun in $tiersToRun) {
    if (-not $allowByTier[$tierToRun]) {
      Write-Host "Stopping PowerShell module auto-advance before '$tierToRun' because ceiling '$ceilingTier' does not allow it."
      break
    }

    if (Test-PowerShellModuleStageCompleted -ContextDirectory $contextDirectory -ModuleName $ModuleName -Tier $tierToRun) {
      $completedTierIndex = $tierOrder.IndexOf($tierToRun)
      if ($tierToRun -eq $tier -and $completedTierIndex -ge $ceilingTierIndex) {
        throw "PowerShell module stage '$tierToRun' already completed for build '$BuildMasterBuildId' and ceiling '$ceilingTier' has been reached. Refusing a successful no-op deployment because BuildMaster would advance the next stage above the ceiling."
      }
      Write-Host "PowerShell module stage '$tierToRun' already completed for build '$BuildMasterBuildId'; skipping re-execution."
      continue
    }

    switch ($tierToRun) {
      'Experimental' {
        New-Item -ItemType Directory -Path (Split-Path -Parent $NupkgPathFile) -Force | Out-Null
        $moduleBuildTier = Convert-BuildMasterTierToModuleBuildTier -Tier $tierToRun
        $buildLogPath = Join-Path -Path $contextDirectory -ChildPath 'PSModuleBuildLogs'
        $buildResults = @(
          Invoke-ModuleBuildWithRetry `
            -ProjectPath $ModulePath `
            -Tier $moduleBuildTier `
            -Task CI `
            -SkipPublish `
            -MaxRetries 1 `
            -BuildLogPath $buildLogPath `
            -OutputRoot $moduleBuildOutputRoot
        )
        $moduleBuildRetryResults = @($buildResults | Select-ModuleBuildRetryResult)
        if ($moduleBuildRetryResults.Count -eq 0) {
          throw "Invoke-ModuleBuildWithRetry did not return a result object for '$ModuleName'."
        }

        $failedBuildResults = @($moduleBuildRetryResults | Where-Object { [int]$_.ExitCode -ne 0 })
        if ($failedBuildResults.Count -gt 0) {
          $failureSummary = ($failedBuildResults | ForEach-Object { $_.BuildOutput -join [Environment]::NewLine }) -join [Environment]::NewLine
          throw "module.build.ps1 failed for '$ModuleName' at BuildMaster tier '$tierToRun' (module.build tier '$moduleBuildTier'). $failureSummary"
        }

        $nupkg = Find-LatestPowerShellModulePackage -PackageDirectory $PackageOutputPath
        $nupkg.FullName | Set-Content -LiteralPath $NupkgPathFile -Encoding utf8 -NoNewline
        $packageVersionForRun = Get-PowerShellModulePackageVersionFromNupkgPath -NupkgPath $nupkg.FullName -PackageName $PackageName
        Update-PowerShellModulePackageContext -PackageVersion $packageVersionForRun -NupkgPath $nupkg.FullName

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
        if ([string]::IsNullOrWhiteSpace($packageVersionForRun)) {
          $packageVersionForRun = Get-PowerShellModulePackageVersionForRun -ContextDirectory $contextDirectory -NupkgPathFile $NupkgPathFile -PackageName $PackageName
          Update-PowerShellModulePackageContext -PackageVersion $packageVersionForRun
        }
        Invoke-PowerShellModulePromotionAndTests -Tier $tierToRun -PromotedPackageVersion $packageVersionForRun
      }
    }

    if ([string]::IsNullOrWhiteSpace($packageVersionForRun)) {
      $packageVersionForRun = Get-PowerShellModulePackageVersionForRun -ContextDirectory $contextDirectory -NupkgPathFile $NupkgPathFile -PackageName $PackageName
    }
    Set-PowerShellModuleStageCompleted -ContextDirectory $contextDirectory -ModuleName $ModuleName -Tier $tierToRun -PackageVersion $packageVersionForRun

    $completedTierIndex = $tierOrder.IndexOf($tierToRun)
    if ($completedTierIndex -lt $ceilingTierIndex) {
      $nextTier = $tierOrder[$completedTierIndex + 1]
      Write-Host "PowerShell module stage '$tierToRun' completed; next stage gate '$nextTier' is within ceiling '$ceilingTier', continuing."
    } elseif ($completedTierIndex + 1 -lt $tierOrder.Count) {
      $nextTier = $tierOrder[$completedTierIndex + 1]
      Write-Host "PowerShell module stage '$tierToRun' completed; next stage '$nextTier' exceeds ceiling '$ceilingTier', stopping."
    } else {
      Write-Host "PowerShell module stage '$tierToRun' completed at final tier '$ceilingTier'."
    }
  }
} finally {
  Pop-Location
}

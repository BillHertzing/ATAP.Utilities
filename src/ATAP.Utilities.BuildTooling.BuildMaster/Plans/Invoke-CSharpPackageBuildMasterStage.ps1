<#
.SYNOPSIS
  Drives a single BuildMaster stage of a C# 5-tier package pipeline.

.DESCRIPTION
  Eponymous entry-point script for the C# package pipeline. Mirrors the
  PowerShell-module runner pattern proven during the Sprint 0007 BuildMaster
  PowerShell pipeline live runs (see
  SharedVSCode-wt-*/BuildMaster-PowerShell-Pipeline-Debugging-Decision-Log.md):
  the OtterScript plan stays tiny and this script owns stage/context branching,
  per-tier idempotent completion markers, run-context JSON, ProGet API-key
  resolution, ceiling-clamp enforcement, and the publish/promote/test loop.

  For Experimental the script runs `dotnet build` and `dotnet pack` against the
  per-build run-context output directory, captures the resulting `.nupkg` for
  the configured `$MetaPackageName`, publishes it (and any sibling roll-up
  `.nupkg` files dotnet pack emits) to the Experimental feed via
  Publish-NuGetPackageToProGet (which itself reads the API key from environment
  and applies --skip-duplicate), records the immutable package version on
  build-context.json, and writes a per-tier completion marker.

  For Development/Integration/QA/Production it promotes the captured immutable
  version from the previous tier's feed to the destination feed via
  Promote-ProGetPackage, then runs Invoke-PromotedPackageTests against the
  destination feed with a tier-appropriate filter. Completion markers make
  reruns within a single BuildMaster build id idempotent.

  Designed to be invoked from an OtterScript plan via 'Exec pwsh -File'.

.PARAMETER BuildToolingModulePath
  Path to the ATAP.Utilities.BuildTooling.PowerShell module manifest or folder.

.PARAMETER SourcePath
  Working copy / repository root. _generated/buildmaster lives beneath this.

.PARAMETER BuildMasterBuildId
  BuildMaster build id used as the per-build run-context folder name.

.PARAMETER BuildNumber
  Optional BuildMaster build number for traceability.

.PARAMETER ExecutionId
  Optional BuildMaster execution identifier for traceability.

.PARAMETER ApplicationName
  The product/application this pipeline targets (Get-BuildContext -Application).

.PARAMETER MetaPackageName
  Roll-up NuGet package id, e.g. ATAP.Utilities.StronglyTypedId. Used to pick
  which `.nupkg` from the pack output drives promotion/test runs.

.PARAMETER PackageName
  Optional package id used for promotion / test; defaults to MetaPackageName.

.PARAMETER ProjectPath
  Path (relative to SourcePath or absolute) to the .csproj being packed. The
  parent directory must contain the project's version.json so Get-BuildContext
  can resolve the immutable package version via nbgv from there.

.PARAMETER SolutionPath
  Optional solution / .slnf path passed to Invoke-PromotedPackageTests above
  Experimental. Defaults to 'ATAP.Utilities.sln'.

.PARAMETER Configuration
  MSBuild configuration; defaults to Release.

.PARAMETER Branch
  Optional source-branch label.

.PARAMETER Stage
  Optional BuildMaster stage hint passed to Get-BuildContext.

.PARAMETER PackageOutputPath
  Optional override of the pack output directory. Defaults to a build-scoped
  path under the run-context directory (the recommended value; non-default
  paths are accepted but logged as Important).

.PARAMETER NupkgPathFile
  Optional file path that receives the captured .nupkg path; defaults to
  $contextDirectory/$MetaPackageName.nupkg-path.tmp.

.PARAMETER ProGetUrl
  Base URL of the ProGet server hosting the NuGet feeds.

.PARAMETER ExperimentalFeed
.PARAMETER DevelopmentFeed
.PARAMETER IntegrationFeed
.PARAMETER QAFeed
.PARAMETER ProductionFeed
  NuGet feed names per tier.

.OUTPUTS
  None. Side effects: dotnet build, dotnet pack, ProGet publish / promote,
  promoted-package test run, run-context JSON / state files / completion
  markers under _generated/buildmaster/<BuildMasterBuildId>.

.EXAMPLE
  pwsh -File Invoke-CSharpPackageBuildMasterStage.ps1 `
    -BuildToolingModulePath C:\src\repo\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1 `
    -SourcePath C:\src\repo `
    -BuildMasterBuildId 12345 `
    -ApplicationName ATAP.Utilities `
    -MetaPackageName ATAP.Utilities.StronglyTypedId `
    -ProjectPath src/ATAP.Utilities.StronglyTypedID/ATAP.Utilities.StronglyTypedId.csproj `
    -SolutionPath ATAP.Utilities.Production.slnf `
    -Configuration Release `
    -Stage Experimental `
    -ProGetUrl http://localhost:50000

.NOTES
  AI assisted using Powershell.instructions.md as guidelines

.LINK
  BuildMasterRunContext.Common.ps1

.LINK
  Invoke-PowerShellModuleBuildMasterStage.ps1
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
  [string]$ApplicationName,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$MetaPackageName,

  [AllowEmptyString()]
  [string]$PackageName = '',

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ProjectPath,

  [AllowEmptyString()]
  [string]$SolutionPath = '',

  [ValidateNotNullOrEmpty()]
  [string]$Configuration = 'Release',

  [AllowEmptyString()]
  [string]$Branch = '',

  [AllowEmptyString()]
  [string]$Stage = '',

  [AllowEmptyString()]
  [string]$PackageOutputPath = '',

  [AllowEmptyString()]
  [string]$NupkgPathFile = '',

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ProGetUrl,

  [string]$ExperimentalFeed = 'nuget-experimental',
  [string]$DevelopmentFeed = 'nuget-development',
  [string]$IntegrationFeed = 'nuget-integration',
  [string]$QAFeed = 'nuget-qa',
  [string]$ProductionFeed = 'nuget-stable'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command -Name Write-PSFMessage -CommandType Function, Cmdlet -ErrorAction SilentlyContinue)) {
  function Write-PSFMessage {
    param(
      [string]$FunctionName,
      [string]$ModuleName,
      [string]$Level,
      [string]$Message,
      [string[]]$Tag
    )
    if ($Level -in @('Important', 'Warning', 'Error')) {
      Write-Output "$Level [$FunctionName] $Message"
    }
  }
}

. (Join-Path -Path $PSScriptRoot -ChildPath 'BuildMasterRunContext.Common.ps1')

function Set-NoProfileProGetFeedSettings {
  <#
  .SYNOPSIS
    Bootstraps minimal $global:Settings and $global:configRootKeys so that
    Publish-NuGetPackageToProGet -> Resolve-ProGetFeedFromSettings works
    under -NoProfile.
  .DESCRIPTION
    Publish-NuGetPackageToProGet resolves feed URIs through
    Resolve-ProGetFeedFromSettings, which reads $global:Settings and
    $global:configRootKeys. Under -NoProfile (BuildMaster's invocation
    pattern, and ours) the user profile that populates those globals never
    loaded. We populate exactly the keys the resolver needs: the canonical
    five NuGet feed entries derived from ProGetUrl + feed names. Existing
    globals are left untouched if they are already populated (so a
    profile-loaded host wins over this fallback).
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Tracked by V4-B02 (no-profile audit) and V4-G05 for a structural fix in
    Resolve-ProGetFeedFromSettings.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ProGetUrl,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ExperimentalFeed,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DevelopmentFeed,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$IntegrationFeed,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$QAFeed,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ProductionFeed
  )

  BEGIN {
    $fn = 'Set-NoProfileProGetFeedSettings'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
    # Set-StrictMode -Version Latest is active in BuildMasterRunContext.Common.ps1.
    # Reading an undeclared global throws under strict mode, so check via Get-Variable
    # before dereferencing.
    $collectionKey = 'ProGetFeedCollection'

    $configRootKeysVar = Get-Variable -Name 'configRootKeys' -Scope Global -ErrorAction SilentlyContinue
    $existingConfigRootKeys = if ($null -ne $configRootKeysVar) { $configRootKeysVar.Value } else { $null }
    if ($null -eq $existingConfigRootKeys -or -not ($existingConfigRootKeys -is [System.Collections.IDictionary])) {
      $global:configRootKeys = @{}
    }
    if (-not $global:configRootKeys.Contains('ProGetFeedCollectionConfigRootKey')) {
      $global:configRootKeys['ProGetFeedCollectionConfigRootKey'] = $collectionKey
    } else {
      $collectionKey = [string]$global:configRootKeys['ProGetFeedCollectionConfigRootKey']
    }

    $settingsVar = Get-Variable -Name 'Settings' -Scope Global -ErrorAction SilentlyContinue
    $existingSettings = if ($null -ne $settingsVar) { $settingsVar.Value } else { $null }
    if ($null -eq $existingSettings -or -not ($existingSettings -is [System.Collections.IDictionary])) {
      $global:Settings = @{}
    }
    if (-not $global:Settings.Contains($collectionKey) -or $null -eq $global:Settings[$collectionKey]) {
      $trimmed = $ProGetUrl.TrimEnd('/')
      $tierByFeed = [ordered]@{
        $ExperimentalFeed = 'experimental'
        $DevelopmentFeed  = 'development'
        $IntegrationFeed  = 'integration'
        $QAFeed           = 'qa'
        $ProductionFeed   = 'stable'
      }
      $feedCollection = @{}
      foreach ($feedName in $tierByFeed.Keys) {
        $tier = $tierByFeed[$feedName]
        $feedCollection[$feedName] = @{
          FeedType    = 'nuget'
          Tier        = $tier
          FeedName    = $feedName
          Uri         = "$trimmed/nuget/$feedName/"
          NuGetV3Uri  = "$trimmed/nuget/$feedName/v3/index.json"
          ApiKeyName  = 'PROGET_ADMIN_API_KEY'
        }
      }
      $global:Settings[$collectionKey] = $feedCollection
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Bootstrapped no-profile ProGet feed settings ($($feedCollection.Keys.Count) feeds) from ProGetUrl='$ProGetUrl'."
    } else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Existing ProGet feed settings under '$collectionKey' preserved; no-profile bootstrap skipped."
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Add-GitSafeDirectoryForCurrentProcess {
  <#
  .SYNOPSIS
    Adds a process-local git safe.directory entry for the supplied repo path.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryPath
  )

  BEGIN {
    $fn = 'Add-GitSafeDirectoryForCurrentProcess'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
    $safeDirectory = [System.IO.Path]::GetFullPath($RepositoryPath).Replace('\', '/')
    $count = 0
    if (-not [string]::IsNullOrWhiteSpace($env:GIT_CONFIG_COUNT)) {
      $count = [int]$env:GIT_CONFIG_COUNT
    }
    [Environment]::SetEnvironmentVariable("GIT_CONFIG_KEY_$count", 'safe.directory', 'Process')
    [Environment]::SetEnvironmentVariable("GIT_CONFIG_VALUE_$count", $safeDirectory, 'Process')
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT', ($count + 1).ToString([Globalization.CultureInfo]::InvariantCulture), 'Process')
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Configured process-local git safe.directory for '$safeDirectory'."
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Get-CSharpPackagePackageVersionFromNupkgPath {
  <#
  .SYNOPSIS
    Derives the package version from a $PackageName.$Version.nupkg path.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$NupkgPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageName
  )

  BEGIN {
    $fn = 'Get-CSharpPackagePackageVersionFromNupkgPath'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
    if ([string]::IsNullOrWhiteSpace($NupkgPath)) {
      throw 'C# package path is empty; run the Experimental stage first.'
    }

    $leaf = [System.IO.Path]::GetFileNameWithoutExtension($NupkgPath.Trim())
    $prefix = "$PackageName."
    if (-not $leaf.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "C# package '$NupkgPath' does not match expected package name '$PackageName'."
    }

    $version = $leaf.Substring($prefix.Length)
    if ([string]::IsNullOrWhiteSpace($version)) {
      throw "Could not derive package version from '$NupkgPath'."
    }
    return $version
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Find-CSharpMetaPackageNupkg {
  <#
  .SYNOPSIS
    Returns the most recently written .nupkg for $MetaPackageName under $PackageDirectory.
  .DESCRIPTION
    `dotnet pack` of an aggregator project may emit several .nupkg files (one
    for the aggregator and one per packable referenced project). The captured
    immutable build version is derived from the .nupkg whose filename starts
    with "$MetaPackageName.", not from any sibling roll-up.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageDirectory,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$MetaPackageName
  )

  BEGIN {
    $fn = 'Find-CSharpMetaPackageNupkg'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
    if (-not (Test-Path -LiteralPath $PackageDirectory -PathType Container)) {
      throw "C# package output directory does not exist after dotnet pack: $PackageDirectory"
    }

    $prefix = "$MetaPackageName."
    $package = Get-ChildItem -LiteralPath $PackageDirectory -Filter '*.nupkg' -File |
      Where-Object { $_.Name.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) } |
      Sort-Object LastWriteTimeUtc -Descending |
      Select-Object -First 1

    if ($null -eq $package) {
      $emitted = (Get-ChildItem -LiteralPath $PackageDirectory -Filter '*.nupkg' -File | Select-Object -ExpandProperty Name) -join ', '
      throw "dotnet pack did not produce a .nupkg matching MetaPackageName '$MetaPackageName' under '$PackageDirectory'. Found: $emitted."
    }
    return $package
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Add-BuildMasterPublishTrace {
  <#
  .SYNOPSIS
    Appends a UTC-timestamped line to a per-tier publish/promote trace file.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message
  )

  BEGIN {
    $fn = 'Add-BuildMasterPublishTrace'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
    $line = '{0:u} {1}' -f [datetime]::UtcNow, $Message
    Add-Content -LiteralPath $Path -Value $line -Encoding utf8
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Assert-BuildMasterOperationSucceeded {
  <#
  .SYNOPSIS
    Throws if a BuildTooling result object reports Succeeded=$false or GatePass=$false.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object]$Result,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$OperationName
  )

  BEGIN {
    $fn = 'Assert-BuildMasterOperationSucceeded'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn (Operation='$OperationName')"
  }

  PROCESS {
    if ($null -eq $Result) {
      throw "$OperationName did not return a result object."
    }
    $propertyNames = @($Result.PSObject.Properties.Name)
    $responseSummary = if ($propertyNames -contains 'ResponseSummary') {
      [string]$Result.ResponseSummary
    } else {
      ''
    }
    if ($propertyNames -contains 'Succeeded' -and -not [bool]$Result.Succeeded) {
      throw "$OperationName reported Succeeded=false. $responseSummary"
    }
    if ($propertyNames -contains 'GatePass' -and -not [bool]$Result.GatePass) {
      throw "$OperationName reported GatePass=false. $responseSummary"
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Get-CSharpPackageStageCompletionMarkerPath {
  <#
  .SYNOPSIS
    Returns the per-package, per-tier completion marker file path.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ContextDirectory,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$MetaPackageName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Tier
  )

  BEGIN {
    $fn = 'Get-CSharpPackageStageCompletionMarkerPath'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
    return (Join-Path -Path $ContextDirectory -ChildPath "$MetaPackageName.$Tier.completed.tmp")
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Set-CSharpPackageStageCompleted {
  <#
  .SYNOPSIS
    Writes a completion marker JSON for a given package/tier/version.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ContextDirectory,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$MetaPackageName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Tier,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageVersion
  )

  BEGIN {
    $fn = 'Set-CSharpPackageStageCompleted'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn (Tier='$Tier'; Version='$PackageVersion')"
  }

  PROCESS {
    $markerPath = Get-CSharpPackageStageCompletionMarkerPath -ContextDirectory $ContextDirectory -MetaPackageName $MetaPackageName -Tier $Tier
    $payload = [ordered]@{
      Tier           = $Tier
      PackageVersion = $PackageVersion
      CompletedUtc   = [datetime]::UtcNow.ToString('o')
    }
    if ($PSCmdlet.ShouldProcess($markerPath, 'Write stage completion marker')) {
      $payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $markerPath -Encoding utf8
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Test-CSharpPackageStageCompleted {
  <#
  .SYNOPSIS
    Returns $true if the completion marker for a package/tier exists.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ContextDirectory,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$MetaPackageName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Tier
  )

  BEGIN {
    $fn = 'Test-CSharpPackageStageCompleted'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
    $markerPath = Get-CSharpPackageStageCompletionMarkerPath -ContextDirectory $ContextDirectory -MetaPackageName $MetaPackageName -Tier $Tier
    return (Test-Path -LiteralPath $markerPath -PathType Leaf)
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Get-PreviousBuildMasterTier {
  <#
  .SYNOPSIS
    Returns the tier immediately preceding $Tier in the canonical tier order.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Tier
  )

  BEGIN {
    $fn = 'Get-PreviousBuildMasterTier'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn (Tier='$Tier')"
  }

  PROCESS {
    $tierOrder = @(Get-TierOrder)
    $tierIndex = $tierOrder.IndexOf($Tier)
    if ($tierIndex -le 0) {
      throw "Tier '$Tier' does not have a previous promotion tier."
    }
    return $tierOrder[$tierIndex - 1]
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Get-CSharpPackageTestFilterForTier {
  <#
  .SYNOPSIS
    Maps a BuildMaster tier to a dotnet test --filter expression.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Tier
  )

  BEGIN {
    $fn = 'Get-CSharpPackageTestFilterForTier'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn (Tier='$Tier')"
  }

  PROCESS {
    switch ($Tier) {
      'Development' { return 'Category=Unit' }
      'Integration' { return 'Category=Unit|Category=Integration' }
      'QA'          { return '' }
      'Production'  { return 'Category=Smoke' }
      default        { return '' }
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Get-CSharpPackagePackageVersionForRun {
  <#
  .SYNOPSIS
    Resolves the immutable package version for the current build, from either
    the captured nupkg path file or the build-context.json document.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ContextDirectory,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$NupkgPathFile,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageName
  )

  BEGIN {
    $fn = 'Get-CSharpPackagePackageVersionForRun'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
    if (Test-Path -LiteralPath $NupkgPathFile -PathType Leaf) {
      $nupkgPath = (Get-Content -LiteralPath $NupkgPathFile -Raw).Trim()
      if (-not [string]::IsNullOrWhiteSpace($nupkgPath) -and (Test-Path -LiteralPath $nupkgPath -PathType Leaf)) {
        return (Get-CSharpPackagePackageVersionFromNupkgPath -NupkgPath $nupkgPath -PackageName $PackageName)
      }
    }

    $runContext = Read-BuildMasterRunContextJson -ContextDirectory $ContextDirectory
    if ($null -ne $runContext -and $runContext.PSObject.Properties.Name -contains 'PackageVersion') {
      $packageVersion = [string]$runContext.PackageVersion
      if (-not [string]::IsNullOrWhiteSpace($packageVersion)) {
        return $packageVersion
      }
    }
    throw "C# package version is not captured for build context '$ContextDirectory'; run the Experimental stage first."
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Invoke-CSharpPackageBuildMasterStage {
  <#
  .SYNOPSIS
    Eponymous worker that drives one BuildMaster stage of the 5-tier C# package pipeline.
  .DESCRIPTION
    See file-level comment-based help. Implements the run loop over
    current..ceiling tiers, handling Experimental (build + pack + publish) and
    promotion tiers (promote + Invoke-PromotedPackageTests) and emitting
    completion markers along the way.
  .OUTPUTS
    None.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory)][string]$BuildToolingModulePath,
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$BuildMasterBuildId,
    [AllowEmptyString()][string]$BuildNumber = '',
    [AllowEmptyString()][string]$ExecutionId = '',
    [Parameter(Mandatory)][string]$ApplicationName,
    [Parameter(Mandatory)][string]$MetaPackageName,
    [AllowEmptyString()][string]$PackageName = '',
    [Parameter(Mandatory)][string]$ProjectPath,
    [AllowEmptyString()][string]$SolutionPath = '',
    [string]$Configuration = 'Release',
    [AllowEmptyString()][string]$Branch = '',
    [AllowEmptyString()][string]$Stage = '',
    [AllowEmptyString()][string]$PackageOutputPath = '',
    [AllowEmptyString()][string]$NupkgPathFile = '',
    [Parameter(Mandatory)][string]$ProGetUrl,
    [string]$ExperimentalFeed = 'nuget-experimental',
    [string]$DevelopmentFeed = 'nuget-development',
    [string]$IntegrationFeed = 'nuget-integration',
    [string]$QAFeed = 'nuget-qa',
    [string]$ProductionFeed = 'nuget-stable'
  )

  BEGIN {
    $fn = 'Invoke-CSharpPackageBuildMasterStage'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn for BuildId='$BuildMasterBuildId'; MetaPackage='$MetaPackageName'"

    $script:resolvedProGetApiKey = if (-not [string]::IsNullOrWhiteSpace($env:PROGET_BUILDMASTER_API_KEY)) {
      $env:PROGET_BUILDMASTER_API_KEY
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:PROGET_ADMIN_API_KEY)) {
      $env:PROGET_ADMIN_API_KEY
    }
    else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Unable to resolve ProGet API key.'
      throw 'Unable to resolve ProGet API key. Set PROGET_BUILDMASTER_API_KEY or PROGET_ADMIN_API_KEY in the BuildMaster process environment.'
    }
    $env:PROGET_BUILDMASTER_API_KEY = $script:resolvedProGetApiKey
    $env:PROGET_ADMIN_API_KEY = $script:resolvedProGetApiKey

    Set-NoProfileProGetFeedSettings `
      -ProGetUrl $ProGetUrl `
      -ExperimentalFeed $ExperimentalFeed `
      -DevelopmentFeed $DevelopmentFeed `
      -IntegrationFeed $IntegrationFeed `
      -QAFeed $QAFeed `
      -ProductionFeed $ProductionFeed

    $script:buildToolingRoot = Split-Path -Parent $BuildToolingModulePath
  }

  PROCESS {
    function Resolve-BuildToolingFunctionFile {
      [CmdletBinding()]
      [OutputType([string])]
      param([Parameter(Mandatory)][string]$RelativePath)
      BEGIN { $f = 'Resolve-BuildToolingFunctionFile'; $m = 'ATAP.Utilities.BuildTooling.BuildMaster' }
      PROCESS {
        $path = Join-Path -Path $script:buildToolingRoot -ChildPath $RelativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
          Write-PSFMessage -FunctionName $f -ModuleName $m -Level Error -Message "Required BuildTooling function file not found: $path"
          throw "Required BuildTooling function file not found: $path"
        }
        return $path
      }
      END {}
    }

    . (Resolve-BuildToolingFunctionFile -RelativePath 'private/Get-CeilingFromPrereleaseLabel.ps1')
    . (Resolve-BuildToolingFunctionFile -RelativePath 'private/Get-CurrentTierFromStage.ps1')
    . (Resolve-BuildToolingFunctionFile -RelativePath 'public/Get-TierOrder.ps1')
    . (Resolve-BuildToolingFunctionFile -RelativePath 'public/Resolve-FeatureSlug.ps1')
    . (Resolve-BuildToolingFunctionFile -RelativePath 'public/Test-PromotionWithinCeiling.ps1')
    . (Resolve-BuildToolingFunctionFile -RelativePath 'public/Get-BuildContext.ps1')
    . (Resolve-BuildToolingFunctionFile -RelativePath 'public/Move-ProGetPackageInterTier.ps1')
    . (Resolve-BuildToolingFunctionFile -RelativePath 'public/Promote-ProGetPackage.ps1')
    . (Resolve-BuildToolingFunctionFile -RelativePath 'public/Publish-NuGetPackageToProGet.ps1')
    . (Resolve-BuildToolingFunctionFile -RelativePath 'public/Invoke-PromotedPackageTests.ps1')

    # Move-ProGetPackageInterTier references the Get-PVal alias for
    # Get-ParameterValueFromNeoConfigurationRoot. Mirror the PowerShell-module
    # runner: dot-source the helper from ATAP.Utilities.PowerShell if it is
    # not already loaded, then register the alias at global scope.
    $neoConfigurationPath = Join-Path -Path $SourcePath -ChildPath 'src/ATAP.Utilities.PowerShell/public/Get-ParameterValueFromNeoConfigurationRoot.ps1'
    if (-not (Get-Command -Name Get-ParameterValueFromNeoConfigurationRoot -CommandType Function -ErrorAction SilentlyContinue)) {
      if (-not (Test-Path -LiteralPath $neoConfigurationPath -PathType Leaf)) {
        throw "Required NeoConfigurationRoot helper not found: $neoConfigurationPath"
      }
      . $neoConfigurationPath
    }
    Set-Alias -Name Get-PVal -Value Get-ParameterValueFromNeoConfigurationRoot -Scope Global -Force

    if ([string]::IsNullOrWhiteSpace($PackageName)) { $PackageName = $MetaPackageName }
    if ([string]::IsNullOrWhiteSpace($SolutionPath)) { $SolutionPath = 'ATAP.Utilities.sln' }

    $resolvedProjectPath = if ([System.IO.Path]::IsPathRooted($ProjectPath)) {
      $ProjectPath
    } else {
      Join-Path -Path $SourcePath -ChildPath $ProjectPath
    }
    if (-not (Test-Path -LiteralPath $resolvedProjectPath -PathType Leaf)) {
      throw "C# project file not found: '$resolvedProjectPath'."
    }
    $projectDirectory = Split-Path -Parent $resolvedProjectPath

    $resolvedSolutionPath = if ([System.IO.Path]::IsPathRooted($SolutionPath)) {
      $SolutionPath
    } else {
      Join-Path -Path $SourcePath -ChildPath $SolutionPath
    }

    Add-GitSafeDirectoryForCurrentProcess -RepositoryPath $SourcePath

    $contextDirectory = Initialize-BuildMasterRunContextDirectory -SourcePath $SourcePath -BuildMasterBuildId $BuildMasterBuildId
    $contextParameters = @{
      Application = $ApplicationName
      ProjectPath = $projectDirectory
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
      CeilingTier       = Join-Path -Path $contextDirectory -ChildPath "$MetaPackageName.ceiling-tier.tmp"
      CurrentTier       = Join-Path -Path $contextDirectory -ChildPath "$MetaPackageName.current-tier.tmp"
      ResolvedVersion   = Join-Path -Path $contextDirectory -ChildPath "$MetaPackageName.resolved-version.tmp"
      PrereleaseLabel   = Join-Path -Path $contextDirectory -ChildPath "$MetaPackageName.prerelease-label.tmp"
      AllowExperimental = Join-Path -Path $contextDirectory -ChildPath "$MetaPackageName.allow-experimental.tmp"
      AllowDevelopment  = Join-Path -Path $contextDirectory -ChildPath "$MetaPackageName.allow-development.tmp"
      AllowIntegration  = Join-Path -Path $contextDirectory -ChildPath "$MetaPackageName.allow-integration.tmp"
      AllowQA           = Join-Path -Path $contextDirectory -ChildPath "$MetaPackageName.allow-qa.tmp"
      AllowProduction   = Join-Path -Path $contextDirectory -ChildPath "$MetaPackageName.allow-production.tmp"
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
      -ProjectPath $projectDirectory `
      -CurrentTier $context.CurrentTier `
      -CeilingTier $effectiveCeilingTier `
      -ResolvedVersion $capturedResolvedVersion `
      -PrereleaseLabel $capturedPrereleaseLabel `
      -AllowDecisions $allowDecisions `
      -StateFiles $stateFiles `
      -AdditionalData @{ PipelineKind = 'CSharpPackage'; MetaPackageName = $MetaPackageName; PackageName = $PackageName; SolutionPath = $resolvedSolutionPath; Configuration = $Configuration } | Out-Null

    $packBuildOutputRoot = Join-Path -Path $contextDirectory -ChildPath "nuget/$MetaPackageName"
    if ([string]::IsNullOrWhiteSpace($PackageOutputPath)) {
      $PackageOutputPath = $packBuildOutputRoot
    }
    elseif ([System.IO.Path]::GetFullPath($PackageOutputPath) -ne [System.IO.Path]::GetFullPath($packBuildOutputRoot)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "PackageOutputPath '$PackageOutputPath' differs from build-scoped default '$packBuildOutputRoot'; using caller-supplied path."
    }

    if ([string]::IsNullOrWhiteSpace($NupkgPathFile)) {
      $NupkgPathFile = Join-Path -Path $contextDirectory -ChildPath "$MetaPackageName.nupkg-path.tmp"
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

    function Update-CSharpPackagePackageContext {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)][string]$PackageVersion,
        [AllowEmptyString()][string]$NupkgPath = ''
      )
      BEGIN { $f = 'Update-CSharpPackagePackageContext'; $m = 'ATAP.Utilities.BuildTooling.BuildMaster' }
      PROCESS {
        $additionalData = @{
          PipelineKind    = 'CSharpPackage'
          MetaPackageName = $MetaPackageName
          PackageName     = $PackageName
          PackageVersion  = $PackageVersion
          SolutionPath    = $resolvedSolutionPath
          Configuration   = $Configuration
        }
        if (-not [string]::IsNullOrWhiteSpace($NupkgPath)) { $additionalData['NupkgPath'] = $NupkgPath }
        Write-BuildMasterRunContextJson `
          -ContextDirectory $contextDirectory `
          -BuildMasterBuildId $BuildMasterBuildId `
          -BuildNumber $BuildNumber `
          -ExecutionId $ExecutionId `
          -ApplicationName $ApplicationName `
          -Branch $Branch `
          -SourcePath $SourcePath `
          -ProjectPath $projectDirectory `
          -CurrentTier $context.CurrentTier `
          -CeilingTier $ceilingTier `
          -ResolvedVersion $capturedResolvedVersion `
          -PrereleaseLabel $capturedPrereleaseLabel `
          -AllowDecisions $allowDecisions `
          -StateFiles $stateFiles `
          -AdditionalData $additionalData | Out-Null
        Write-PSFMessage -FunctionName $f -ModuleName $m -Level Verbose -Message "Updated run-context with PackageVersion='$PackageVersion'."
      }
      END {}
    }

    function Invoke-CSharpPackagePromotionAndTests {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)][string]$Tier,
        [Parameter(Mandatory)][string]$PromotedPackageVersion
      )
      BEGIN { $f = 'Invoke-CSharpPackagePromotionAndTests'; $m = 'ATAP.Utilities.BuildTooling.BuildMaster' }
      PROCESS {
        $previousTier = Get-PreviousBuildMasterTier -Tier $Tier
        $sourceFeed = $feedByTier[$previousTier]
        $destinationFeed = $feedByTier[$Tier]
        if ([string]::IsNullOrWhiteSpace($sourceFeed) -or [string]::IsNullOrWhiteSpace($destinationFeed)) {
          throw "Cannot resolve NuGet promotion feeds for '$previousTier' -> '$Tier'."
        }

        Write-PSFMessage -FunctionName $f -ModuleName $m -Level Important -Message "C# package stage '$Tier' starting promotion/test for '$PackageName' version '$PromotedPackageVersion' from '$sourceFeed' to '$destinationFeed'."
        $promotionTracePath = Join-Path -Path $contextDirectory -ChildPath "$MetaPackageName.$($Tier.ToLowerInvariant()).log"
        Add-BuildMasterPublishTrace -Path $promotionTracePath -Message "Promoting '$PackageName' version '$PromotedPackageVersion' from '$sourceFeed' to '$destinationFeed'. Captured resolved version is '$capturedResolvedVersion'."

        $env:PROGET_BUILDMASTER_API_KEY = $script:resolvedProGetApiKey
        $env:PROGET_ADMIN_API_KEY = $script:resolvedProGetApiKey
        $global:ProGetBaseUrl = $ProGetUrl

        Write-PSFMessage -FunctionName $f -ModuleName $m -Level Important -Message "Promoting '$PackageName' version '$PromotedPackageVersion' from '$sourceFeed' to '$destinationFeed'."
        try {
          $promotionResult = Promote-ProGetPackage `
            -Name $PackageName `
            -Version $PromotedPackageVersion `
            -FromFeed $sourceFeed `
            -ToFeed $destinationFeed `
            -Reason "$Tier gate for $ApplicationName $PromotedPackageVersion on $Branch" `
            -CeilingTier $ceilingTier
        }
        catch {
          Write-PSFMessage -FunctionName $f -ModuleName $m -Level Error -Message "Promote-ProGetPackage threw for '$PackageName' '$PromotedPackageVersion'. Exception: $($_.Exception.Message)"
          throw
        }
        finally {
          Write-PSFMessage -FunctionName $f -ModuleName $m -Level Debug -Message "Promote-ProGetPackage call complete."
        }
        Assert-BuildMasterOperationSucceeded -Result $promotionResult -OperationName 'Promote-ProGetPackage'
        Add-BuildMasterPublishTrace -Path $promotionTracePath -Message $promotionResult.ResponseSummary

        $resultsPath = Join-Path -Path $contextDirectory -ChildPath "$($Tier)TestResults"
        $testFilter = Get-CSharpPackageTestFilterForTier -Tier $Tier
        $testParameters = @{
          Name             = $PackageName
          Version          = $PromotedPackageVersion
          Feed             = $destinationFeed
          ResultsPath      = $resultsPath
          ProjectPath      = $resolvedSolutionPath
          ProGetUrl        = $ProGetUrl
          WorkingDirectory = $SourcePath
        }
        if (-not [string]::IsNullOrWhiteSpace($testFilter)) {
          $testParameters['TestFilter'] = $testFilter
        }
        if ($Tier -eq 'QA') {
          $testParameters['CollectCoverage'] = $true
        }
        try {
          # `dotnet restore` + `dotnet test` inside Invoke-PromotedPackageTests
          # write to the success stream, so the caller receives an array of
          # console strings plus the PSCustomObject result. Capture the full
          # pipeline and filter to the canonical result by OperationName so
          # downstream property access works under StrictMode. Mirrors
          # Select-ModuleBuildRetryResult used by the PowerShell-module runner.
          $testRawResults = @(Invoke-PromotedPackageTests @testParameters)
          $testResult = $testRawResults |
            Where-Object {
              $_ -is [System.Management.Automation.PSCustomObject] -and
              $_.PSObject.Properties.Name -contains 'OperationName' -and
              [string]$_.OperationName -eq 'Invoke-PromotedPackageTests'
            } |
            Select-Object -Last 1
        }
        catch {
          Write-PSFMessage -FunctionName $f -ModuleName $m -Level Error -Message "Invoke-PromotedPackageTests threw for '$PackageName' '$PromotedPackageVersion'. Exception: $($_.Exception.Message)"
          throw
        }
        finally {
          Write-PSFMessage -FunctionName $f -ModuleName $m -Level Debug -Message "Invoke-PromotedPackageTests call complete."
        }
        if ($null -eq $testResult) {
          throw "Invoke-PromotedPackageTests did not return a recognizable result object for '$PackageName' '$PromotedPackageVersion'."
        }
        Assert-BuildMasterOperationSucceeded -Result $testResult -OperationName 'Invoke-PromotedPackageTests'
        $testSummary = if ($testResult.PSObject.Properties.Name -contains 'ResponseSummary') { [string]$testResult.ResponseSummary } else { "$($testResult.OperationName) GatePass=$($testResult.GatePass)" }
        Add-BuildMasterPublishTrace -Path $promotionTracePath -Message $testSummary

        Write-PSFMessage -FunctionName $f -ModuleName $m -Level Important -Message "Promoted '$PackageName' version '$PromotedPackageVersion' to '$destinationFeed' and passed $Tier tests. Ceiling='$ceilingTier'."
      }
      END {}
    }

    if (-not $allowByTier.ContainsKey($tier)) {
      throw "Unsupported BuildMaster tier '$($context.CurrentTier)'."
    }
    if (-not $allowByTier[$tier]) {
      throw "C# package stage '$tier' exceeds version ceiling '$ceilingTier' for build '$BuildMasterBuildId'. Refusing deployment so BuildMaster does not advance stages above the package ceiling."
    }

    $tierOrder = @(Get-TierOrder)
    $currentTierIndex = $tierOrder.IndexOf($tier)
    $ceilingTierIndex = $tierOrder.IndexOf($ceilingTier)
    if ($currentTierIndex -lt 0) { throw "Unsupported BuildMaster tier '$tier'." }
    if ($ceilingTierIndex -lt 0) { throw "Unsupported BuildMaster ceiling tier '$ceilingTier'." }

    $tiersToRun = @()
    for ($tierIndex = $currentTierIndex; $tierIndex -le $ceilingTierIndex; $tierIndex++) {
      $tiersToRun += $tierOrder[$tierIndex]
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "C# package runner will execute tier(s): $($tiersToRun -join ', ') (current='$tier'; ceiling='$ceilingTier')."

    $packageVersionForRun = $null

    Push-Location -LiteralPath $SourcePath
    try {
      foreach ($tierToRun in $tiersToRun) {
        if (-not $allowByTier[$tierToRun]) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Stopping C# package auto-advance before '$tierToRun' because ceiling '$ceilingTier' does not allow it."
          break
        }

        if (Test-CSharpPackageStageCompleted -ContextDirectory $contextDirectory -MetaPackageName $MetaPackageName -Tier $tierToRun) {
          $completedTierIndex = $tierOrder.IndexOf($tierToRun)
          if ($tierToRun -eq $tier -and $completedTierIndex -ge $ceilingTierIndex) {
            throw "C# package stage '$tierToRun' already completed for build '$BuildMasterBuildId' and ceiling '$ceilingTier' has been reached. Refusing a successful no-op deployment because BuildMaster would advance the next stage above the ceiling."
          }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "C# package stage '$tierToRun' already completed for build '$BuildMasterBuildId'; skipping re-execution."
          continue
        }

        switch ($tierToRun) {
          'Experimental' {
            New-Item -ItemType Directory -Path (Split-Path -Parent $NupkgPathFile) -Force | Out-Null
            New-Item -ItemType Directory -Path $PackageOutputPath -Force | Out-Null

            $publishTracePath = Join-Path -Path $contextDirectory -ChildPath "$MetaPackageName.publish.log"
            Add-BuildMasterPublishTrace -Path $publishTracePath -Message "dotnet build '$resolvedProjectPath' -c '$Configuration' (deterministic)."

            $buildArgs = @(
              'build', $resolvedProjectPath,
              '--configuration', $Configuration,
              '--no-incremental',
              '-p:ContinuousIntegrationBuild=true'
            )
            # Retry dotnet build up to 3 times. Mirrors Invoke-ModuleBuildWithRetry
            # from the PowerShell-module runner; specifically catches transient
            # post-compile file-lock races (e.g. Fody writing the .pdb while a
            # parallel watcher or sync agent has a read handle on it) that
            # surface on workstations and CI agents alike.
            $maxBuildAttempts = 3
            $buildExit = $null
            for ($attempt = 1; $attempt -le $maxBuildAttempts; $attempt++) {
              try {
                dotnet @buildArgs
                $buildExit = $LASTEXITCODE
              }
              catch {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "dotnet build threw for '$resolvedProjectPath' on attempt $attempt. Exception: $($_.Exception.Message)"
                if ($attempt -eq $maxBuildAttempts) { throw }
                $buildExit = -1
              }
              if ($buildExit -eq 0) { break }
              if ($attempt -lt $maxBuildAttempts) {
                $waitSeconds = 3 * $attempt
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "dotnet build exit=$buildExit on attempt $attempt for '$resolvedProjectPath'; retrying after ${waitSeconds}s."
                Add-BuildMasterPublishTrace -Path $publishTracePath -Message "dotnet build exit=$buildExit on attempt $attempt; retry in ${waitSeconds}s."
                Start-Sleep -Seconds $waitSeconds
              }
            }
            if ($buildExit -ne 0) {
              throw "dotnet build failed for '$resolvedProjectPath' after $maxBuildAttempts attempt(s); last exit code $buildExit."
            }

            $packArgs = @(
              'pack', $resolvedProjectPath,
              '--configuration', $Configuration,
              '--no-build',
              '--output', $PackageOutputPath,
              '-p:ContinuousIntegrationBuild=true'
            )
            Add-BuildMasterPublishTrace -Path $publishTracePath -Message "dotnet pack '$resolvedProjectPath' --output '$PackageOutputPath' (deterministic)."
            try {
              dotnet @packArgs
              $packExit = $LASTEXITCODE
            }
            catch {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "dotnet pack threw for '$resolvedProjectPath'. Exception: $($_.Exception.Message)"
              throw
            }
            if ($packExit -ne 0) {
              throw "dotnet pack failed for '$resolvedProjectPath' with exit code $packExit."
            }

            $metaPackageNupkg = Find-CSharpMetaPackageNupkg -PackageDirectory $PackageOutputPath -MetaPackageName $MetaPackageName
            $metaPackageNupkg.FullName | Set-Content -LiteralPath $NupkgPathFile -Encoding utf8 -NoNewline
            $packageVersionForRun = Get-CSharpPackagePackageVersionFromNupkgPath -NupkgPath $metaPackageNupkg.FullName -PackageName $PackageName
            Update-CSharpPackagePackageContext -PackageVersion $packageVersionForRun -NupkgPath $metaPackageNupkg.FullName

            Add-BuildMasterPublishTrace -Path $publishTracePath -Message "Captured meta-package '$($metaPackageNupkg.Name)' version '$packageVersionForRun'."

            $allNupkgs = @(Get-ChildItem -LiteralPath $PackageOutputPath -Filter '*.nupkg' -File)
            foreach ($nupkg in $allNupkgs) {
              Add-BuildMasterPublishTrace -Path $publishTracePath -Message "Publishing '$($nupkg.Name)' to '$ExperimentalFeed'."
              try {
                $publishResult = Publish-NuGetPackageToProGet -NupkgPath $nupkg.FullName -Feed $ExperimentalFeed
              }
              catch {
                Add-BuildMasterPublishTrace -Path $publishTracePath -Message "ERROR: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
                throw
              }
              if ($null -ne $publishResult -and $publishResult.PSObject.Properties.Name -contains 'ResponseSummary') {
                Add-BuildMasterPublishTrace -Path $publishTracePath -Message $publishResult.ResponseSummary
              }
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Experimental publish complete for '$MetaPackageName' version '$packageVersionForRun'. Ceiling='$ceilingTier'."
          }
          default {
            if ([string]::IsNullOrWhiteSpace($packageVersionForRun)) {
              $packageVersionForRun = Get-CSharpPackagePackageVersionForRun -ContextDirectory $contextDirectory -NupkgPathFile $NupkgPathFile -PackageName $PackageName
              Update-CSharpPackagePackageContext -PackageVersion $packageVersionForRun
            }
            Invoke-CSharpPackagePromotionAndTests -Tier $tierToRun -PromotedPackageVersion $packageVersionForRun
          }
        }

        if ([string]::IsNullOrWhiteSpace($packageVersionForRun)) {
          $packageVersionForRun = Get-CSharpPackagePackageVersionForRun -ContextDirectory $contextDirectory -NupkgPathFile $NupkgPathFile -PackageName $PackageName
        }
        Set-CSharpPackageStageCompleted -ContextDirectory $contextDirectory -MetaPackageName $MetaPackageName -Tier $tierToRun -PackageVersion $packageVersionForRun

        $completedTierIndex = $tierOrder.IndexOf($tierToRun)
        if ($completedTierIndex -lt $ceilingTierIndex) {
          $nextTier = $tierOrder[$completedTierIndex + 1]
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "C# package stage '$tierToRun' completed; next stage gate '$nextTier' is within ceiling '$ceilingTier', continuing."
        }
        elseif ($completedTierIndex + 1 -lt $tierOrder.Count) {
          $nextTier = $tierOrder[$completedTierIndex + 1]
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "C# package stage '$tierToRun' completed; next stage '$nextTier' exceeds ceiling '$ceilingTier', stopping."
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "C# package stage '$tierToRun' completed at final tier '$ceilingTier'."
        }
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed in $fn. Exception: $($_.Exception.Message)"
      throw
    }
    finally {
      Pop-Location
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Process complete in $fn."
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Finished $fn"
  }
}

Invoke-CSharpPackageBuildMasterStage `
  -BuildToolingModulePath $BuildToolingModulePath `
  -SourcePath $SourcePath `
  -BuildMasterBuildId $BuildMasterBuildId `
  -BuildNumber $BuildNumber `
  -ExecutionId $ExecutionId `
  -ApplicationName $ApplicationName `
  -MetaPackageName $MetaPackageName `
  -PackageName $PackageName `
  -ProjectPath $ProjectPath `
  -SolutionPath $SolutionPath `
  -Configuration $Configuration `
  -Branch $Branch `
  -Stage $Stage `
  -PackageOutputPath $PackageOutputPath `
  -NupkgPathFile $NupkgPathFile `
  -ProGetUrl $ProGetUrl `
  -ExperimentalFeed $ExperimentalFeed `
  -DevelopmentFeed $DevelopmentFeed `
  -IntegrationFeed $IntegrationFeed `
  -QAFeed $QAFeed `
  -ProductionFeed $ProductionFeed

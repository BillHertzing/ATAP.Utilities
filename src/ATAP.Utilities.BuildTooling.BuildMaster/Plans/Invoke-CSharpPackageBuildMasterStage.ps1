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

  For Experimental Prepare the script runs `dotnet build`, then uses the stable Visual
  Studio Build Tools MSBuild/NuGet pack implementation against the per-build
  run-context output directory. The runner rejects NuGet versions older than
  7.8 because they do not honor deterministic pack. It captures the resulting `.nupkg` for
  the configured `$MetaPackageName`, persists an immutable prepared-manifest
  SHA, and stops without feed mutation. Inspect re-hashes the packages; Approve
  persists the named operator and exact inspected SHA; only Publish may call
  Publish-NuGetPackageToProGet after re-validating that state. Publish then
  records the immutable package version and writes the completion marker.

  For Development/Integration/QA/Production it promotes the captured immutable
  version from the previous tier's feed to the destination feed via
  Promote-ProGetPackage, then runs Invoke-PromotedPackageTests against the
  destination feed with a tier-appropriate filter. Development restore is
  intentionally unlocked so the promoted-package SUTVersion can be written into
  the build workspace's lock-file state; Integration, QA, and Production pass
  -LockedRestore so dotnet restore uses --locked-mode. Completion markers make
  reruns within a single BuildMaster build id idempotent.

  Designed to be invoked from an OtterScript plan via 'Exec pwsh -File'.

.PARAMETER BuildToolingModulePath
  Path to the ATAP.Utilities.BuildTooling.PowerShell module manifest or folder.

.PARAMETER SourcePath
  Working copy / repository root.

.PARAMETER ArtifactsPath
  Canonical external execution path in the form
  <root>\dotnet\ATAP.Utilities\<worktree-id>\<execution-id>. All build, pack,
  smoke-test, binlog, and provenance output is rooted beneath this path.

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
  None. Side effects: dotnet build, Visual Studio MSBuild pack, ProGet publish / promote,
  promoted-package test run, run-context JSON / state files / completion
  markers under _generated/buildmaster/<BuildMasterBuildId>.

.EXAMPLE
  pwsh -File Invoke-CSharpPackageBuildMasterStage.ps1 `
    -BuildToolingModulePath C:\src\repo\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1 `
    -SourcePath C:\src\repo `
    -ArtifactsPath C:\ATAPArtifacts\dotnet\ATAP.Utilities\wt137\build-12345 `
    -BuildMasterBuildId 12345 `
    -ApplicationName ATAP.Utilities `
    -MetaPackageName ATAP.Utilities.StronglyTypedId `
    -ProjectPath src/ATAP.Utilities.StronglyTypedID/ATAP.Utilities.StronglyTypedId.csproj `
    -SolutionPath ATAP.Utilities.Production.slnf `
    -Configuration Release `
    -Stage Experimental `
    -ProGetUrl https://utat022:50000

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
  [string]$ArtifactsPath,

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

  [ValidateSet('Prepare', 'Inspect', 'Approve', 'Publish')]
  [string]$ApprovalAction = 'Prepare',

  [AllowEmptyString()]
  [string]$ExpectedPreparedManifestSha256 = '',

  [AllowEmptyString()]
  [string]$ApprovedBy = '',

  [AllowEmptyString()]
  [string]$PackageOutputPath = '',

  [AllowEmptyString()]
  [string]$NupkgPathFile = '',

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ProGetUrl,

  [ValidateNotNullOrEmpty()]
  [string]$ProGetApiKeySecretName = 'ProGet.BuildMaster.API.Key',

  [string]$ExperimentalFeed = 'nuget-experimental',
  [string]$DevelopmentFeed = 'nuget-development',
  [string]$IntegrationFeed = 'nuget-integration',
  [string]$QAFeed = 'nuget-qa',
  [string]$ProductionFeed = 'nuget-stable'
)

$ErrorActionPreference = 'Stop'

# Initialize host settings using the standalone loader (Task 9.38). The
# BuildMaster plan intentionally allows the PowerShell profile to load first;
# this loader then resolves the repository/host settings contract explicitly.

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
. (Join-Path -Path $PSScriptRoot -ChildPath 'CSharpPackageApprovalBoundary.ps1')
Initialize-LocalHostSettings -SourcePath $SourcePath

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

function Resolve-CSharpPackageArtifactsContext {
  <#
  .SYNOPSIS
    Validates the canonical external artifact path and establishes its owner marker.
  .OUTPUTS
    PSCustomObject compatible with the shared ArtifactsContext contract.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ArtifactsPath
  )

  $resolvedArtifactsPath = [System.IO.Path]::GetFullPath($ArtifactsPath)
  if (-not [System.IO.Path]::IsPathRooted($resolvedArtifactsPath) -or $resolvedArtifactsPath -match '(?i)[\\/]Dropbox[\\/]') {
    throw "ArtifactsPath '$ArtifactsPath' must be an absolute external path outside Dropbox."
  }

  $executionDirectory = [System.IO.DirectoryInfo]::new($resolvedArtifactsPath)
  $worktreeDirectory = $executionDirectory.Parent
  $repositoryDirectory = if ($null -ne $worktreeDirectory) { $worktreeDirectory.Parent } else { $null }
  $dotnetDirectory = if ($null -ne $repositoryDirectory) { $repositoryDirectory.Parent } else { $null }
  $artifactsRootDirectory = if ($null -ne $dotnetDirectory) { $dotnetDirectory.Parent } else { $null }
  if (
    $null -eq $artifactsRootDirectory -or
    $dotnetDirectory.Name -cne 'dotnet' -or
    $repositoryDirectory.Name -cne 'ATAP.Utilities' -or
    [string]::IsNullOrWhiteSpace($worktreeDirectory.Name) -or
    [string]::IsNullOrWhiteSpace($executionDirectory.Name)
  ) {
    throw "ArtifactsPath '$resolvedArtifactsPath' must match '<root>\\dotnet\\ATAP.Utilities\\<worktree-id>\\<execution-id>'."
  }

  $context = [pscustomobject]@{
    Root               = $artifactsRootDirectory.FullName
    WorktreeId         = $worktreeDirectory.Name
    ExecutionId        = $executionDirectory.Name
    ArtifactsPath      = $resolvedArtifactsPath
    BinlogPath         = Join-Path $resolvedArtifactsPath 'binlogs/experimental-build.binlog'
    PackageStagingPath = Join-Path $resolvedArtifactsPath 'packages'
    PublishStagingPath = Join-Path $resolvedArtifactsPath 'publish'
  }

  [System.IO.Directory]::CreateDirectory($resolvedArtifactsPath) | Out-Null
  $artifactsOwner = "ATAP.Utilities|$($context.WorktreeId)|$($context.ExecutionId)"
  $ownerMarkerPath = Join-Path $resolvedArtifactsPath '.atap-artifacts-owner'
  if (Test-Path -LiteralPath $ownerMarkerPath -PathType Leaf) {
    $existingOwner = ([System.IO.File]::ReadAllText($ownerMarkerPath)).Trim()
    if ($existingOwner -cne $artifactsOwner) {
      throw "ArtifactsPath '$resolvedArtifactsPath' is owned by '$existingOwner', not '$artifactsOwner'."
    }
  }
  else {
    try {
      $stream = [System.IO.FileStream]::new($ownerMarkerPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
      try {
        $writer = [System.IO.StreamWriter]::new($stream, [System.Text.UTF8Encoding]::new($false))
        try { $writer.Write($artifactsOwner) } finally { $writer.Dispose() }
      }
      finally { $stream.Dispose() }
    }
    catch [System.IO.IOException] {
      $existingOwner = ([System.IO.File]::ReadAllText($ownerMarkerPath)).Trim()
      if ($existingOwner -cne $artifactsOwner) { throw }
    }
  }

  return $context
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
    [Parameter(Mandatory)][string]$ArtifactsPath,
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
    [ValidateSet('Prepare', 'Inspect', 'Approve', 'Publish')][string]$ApprovalAction = 'Prepare',
    [AllowEmptyString()][string]$ExpectedPreparedManifestSha256 = '',
    [AllowEmptyString()][string]$ApprovedBy = '',
    [AllowEmptyString()][string]$PackageOutputPath = '',
    [AllowEmptyString()][string]$NupkgPathFile = '',
    [Parameter(Mandatory)][string]$ProGetUrl,
    [ValidateNotNullOrEmpty()][string]$ProGetApiKeySecretName = 'ProGet.BuildMaster.API.Key',
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

    $script:buildToolingRoot = Split-Path -Parent $BuildToolingModulePath
  }

  PROCESS {
    function Resolve-DeterministicNuGetMSBuild {
      [CmdletBinding()]
      [OutputType([pscustomobject])]
      param()

      BEGIN {
        $f = 'Resolve-DeterministicNuGetMSBuild'
        $m = 'ATAP.Utilities.BuildTooling.BuildMaster'
      }

      PROCESS {
        if (-not $IsWindows) {
          throw 'Deterministic production NuGet pack currently requires stable Visual Studio Build Tools 2026 18.8 or later on Windows.'
        }

        $programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
        $vsWherePath = Join-Path -Path $programFilesX86 -ChildPath 'Microsoft Visual Studio\Installer\vswhere.exe'
        if (-not (Test-Path -LiteralPath $vsWherePath -PathType Leaf)) {
          throw "Visual Studio Installer discovery tool not found at '$vsWherePath'. Follow SolutionDocumentation/NewComputerSetup.md to install stable Visual Studio Build Tools 2026 with the NuGet Build Tools component."
        }

        $installationPath = @(
          & $vsWherePath -latest -products Microsoft.VisualStudio.Product.BuildTools `
            -requires Microsoft.VisualStudio.Component.NuGet.BuildTools `
            -property installationPath
        ) | Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace([string]$installationPath)) {
          throw 'No stable Visual Studio Build Tools installation with Microsoft.VisualStudio.Component.NuGet.BuildTools was found. Install stable Visual Studio Build Tools 2026 18.8 or later as documented in SolutionDocumentation/NewComputerSetup.md.'
        }

        $msBuildPath = Join-Path -Path $installationPath -ChildPath 'MSBuild\Current\Bin\MSBuild.exe'
        $nuGetPackagingPath = Join-Path -Path $installationPath -ChildPath 'Common7\IDE\CommonExtensions\Microsoft\NuGet\NuGet.Packaging.dll'
        foreach ($requiredPath in @($msBuildPath, $nuGetPackagingPath)) {
          if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "Stable deterministic pack prerequisite is incomplete; required file not found: '$requiredPath'. Repair Visual Studio Build Tools using SolutionDocumentation/NewComputerSetup.md."
          }
        }

        $msBuildVersion = [version](Get-Item -LiteralPath $msBuildPath).VersionInfo.FileVersion
        $nuGetVersion = [System.Reflection.AssemblyName]::GetAssemblyName($nuGetPackagingPath).Version
        if ($msBuildVersion -lt [version]'18.8.0.0' -or $nuGetVersion -lt [version]'7.8.0.0') {
          throw "Stable deterministic pack requires Visual Studio Build Tools 2026 18.8+ and NuGet 7.8+. Found MSBuild '$msBuildVersion' and NuGet '$nuGetVersion' at '$installationPath'."
        }

        $sdkVersionText = (& dotnet --version 2>&1 | Select-Object -First 1).ToString().Trim()
        $sdkPackTaskPath = Join-Path -Path (Split-Path -Parent (Get-Command dotnet -ErrorAction Stop).Source) -ChildPath "sdk\$sdkVersionText\Sdks\Microsoft.NET.Sdk\tools\net472\NuGet.Build.Tasks.Pack.dll"
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $sdkPackTaskPath -PathType Leaf)) {
          throw "The repository-selected .NET SDK '$sdkVersionText' does not expose the NuGet pack task required by Visual Studio MSBuild. Install Microsoft.NetCore.Component.SDK and use the stable SDK pinned by global.json."
        }
        $sdkPackTaskVersion = [System.Reflection.AssemblyName]::GetAssemblyName($sdkPackTaskPath).Version
        if ($sdkPackTaskVersion -lt [version]'7.8.0.0') {
          throw "The repository-selected .NET SDK '$sdkVersionText' would load NuGet Pack '$sdkPackTaskVersion'; deterministic pack requires NuGet Pack 7.8+. Update global.json and the Microsoft.NetCore.Component.SDK installation."
        }

        Write-PSFMessage -FunctionName $f -ModuleName $m -Level Important -Message "Using stable Visual Studio MSBuild '$msBuildVersion', SDK '$sdkVersionText', and NuGet Pack '$sdkPackTaskVersion' for deterministic pack."
        return [pscustomobject]@{
          InstallationPath = [string]$installationPath
          MSBuildPath      = $msBuildPath
          MSBuildVersion   = $msBuildVersion
          NuGetVersion     = $nuGetVersion
          SDKVersion       = $sdkVersionText
          NuGetPackVersion = $sdkPackTaskVersion
        }
      }

      END {}
    }

    function Get-SourceDateEpoch {
      [CmdletBinding()]
      [OutputType([long])]
      param([Parameter(Mandatory)][string]$RepositoryPath)

      PROCESS {
        $sourceDateEpochText = (& git -C $RepositoryPath show -s --format=%ct HEAD 2>&1 | Select-Object -First 1).ToString().Trim()
        $sourceDateEpoch = 0L
        if ($LASTEXITCODE -ne 0 -or -not [long]::TryParse($sourceDateEpochText, [ref]$sourceDateEpoch) -or $sourceDateEpoch -le 0) {
          throw "Cannot derive a stable SOURCE_DATE_EPOCH from Git HEAD in '$RepositoryPath'; deterministic pack is refused."
        }
        return $sourceDateEpoch
      }
    }

    function Resolve-BuildToolingFunctionFile {
      [CmdletBinding()]
      [OutputType([string])]
      param(
        [Parameter(Mandatory)][string]$RelativePath,
        [string]$ModuleName = 'ATAP.Utilities.BuildTooling.PowerShell'
      )
      BEGIN { $f = 'Resolve-BuildToolingFunctionFile'; $m = 'ATAP.Utilities.BuildTooling.BuildMaster' }
      PROCESS {
        $moduleRoot = Join-Path -Path (Split-Path -Parent $script:buildToolingRoot) -ChildPath $ModuleName
        $path = Join-Path -Path $moduleRoot -ChildPath $RelativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
          Write-PSFMessage -FunctionName $f -ModuleName $m -Level Error -Message "Required BuildTooling function file not found: $path"
          throw "Required BuildTooling function file not found: $path"
        }
        return $path
      }
      END {}
    }

    . (Resolve-BuildToolingFunctionFile -ModuleName 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell' -RelativePath 'private/Get-CeilingFromPrereleaseLabel.ps1')
    . (Resolve-BuildToolingFunctionFile -ModuleName 'ATAP.Utilities.BuildTooling.ProGet.PowerShell' -RelativePath 'public/Get-CurrentTierFromStage.ps1')
    . (Resolve-BuildToolingFunctionFile -ModuleName 'ATAP.Utilities.BuildTooling.ProGet.PowerShell' -RelativePath 'public/Get-TierOrder.ps1')
    . (Resolve-BuildToolingFunctionFile -ModuleName 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell' -RelativePath 'public/Resolve-FeatureSlug.ps1')
    . (Resolve-BuildToolingFunctionFile -ModuleName 'ATAP.Utilities.BuildTooling.ProGet.PowerShell' -RelativePath 'public/Test-PromotionWithinCeiling.ps1')
    . (Resolve-BuildToolingFunctionFile -ModuleName 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell' -RelativePath 'public/Get-BuildContext.ps1')
    . (Resolve-BuildToolingFunctionFile -ModuleName 'ATAP.Utilities.BuildTooling.ProGet.PowerShell' -RelativePath 'public/Move-ProGetPackageInterTier.ps1')
    . (Resolve-BuildToolingFunctionFile -ModuleName 'ATAP.Utilities.BuildTooling.ProGet.PowerShell' -RelativePath 'public/Promote-ProGetPackage.ps1')
    . (Resolve-BuildToolingFunctionFile -ModuleName 'ATAP.Utilities.BuildTooling.ProGet.PowerShell' -RelativePath 'public/Publish-NuGetPackageToProGet.ps1')
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

    $artifactsContext = Resolve-CSharpPackageArtifactsContext -ArtifactsPath $ArtifactsPath
    $resolvedArtifactsPath = [string]$artifactsContext.ArtifactsPath
    $contextDirectory = Initialize-BuildMasterRunContextDirectory -SourcePath $resolvedArtifactsPath -BuildMasterBuildId $BuildMasterBuildId
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
      -AdditionalData @{ PipelineKind = 'CSharpPackage'; MetaPackageName = $MetaPackageName; PackageName = $PackageName; SolutionPath = $resolvedSolutionPath; Configuration = $Configuration; ArtifactsPath = $resolvedArtifactsPath; BinlogPath = $artifactsContext.BinlogPath } | Out-Null

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

        $global:ProGetBaseUrl = $ProGetUrl

        Write-PSFMessage -FunctionName $f -ModuleName $m -Level Important -Message "Promoting '$PackageName' version '$PromotedPackageVersion' from '$sourceFeed' to '$destinationFeed'."
        try {
          $promotionResult = Promote-ProGetPackage `
            -Name $PackageName `
            -Version $PromotedPackageVersion `
            -FromFeed $sourceFeed `
            -ToFeed $destinationFeed `
            -Reason "$Tier gate for $ApplicationName $PromotedPackageVersion on $Branch" `
            -ProGetApiKeySecretName $ProGetApiKeySecretName `
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
        $testArtifactsContext = [pscustomobject]@{
          Root               = $artifactsContext.Root
          WorktreeId         = $artifactsContext.WorktreeId
          ExecutionId        = $artifactsContext.ExecutionId
          ArtifactsPath      = $artifactsContext.ArtifactsPath
          BinlogPath         = Join-Path (Split-Path -Parent $artifactsContext.BinlogPath) "$($Tier.ToLowerInvariant())-smoke-test.binlog"
          PackageStagingPath = $artifactsContext.PackageStagingPath
          PublishStagingPath = $artifactsContext.PublishStagingPath
        }
        $testParameters = @{
          Name             = $PackageName
          Version          = $PromotedPackageVersion
          Feed             = $destinationFeed
          ResultsPath      = $resultsPath
          ProjectPath      = $resolvedSolutionPath
          ProGetUrl        = $ProGetUrl
          WorkingDirectory = $SourcePath
          ArtifactsContext = $testArtifactsContext
        }
        if (-not [string]::IsNullOrWhiteSpace($testFilter)) {
          $testParameters['TestFilter'] = $testFilter
        }
        if ($Tier -eq 'QA') {
          $testParameters['CollectCoverage'] = $true
        }
        if ($Tier -in @('Integration', 'QA', 'Production')) {
          $testParameters['LockedRestore'] = $true
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

    $approvalDirectory = Join-Path $contextDirectory 'approval-boundary'
    $preparedManifestPath = Join-Path $approvalDirectory 'prepared.json'
    $approvalRecordPath = Join-Path $approvalDirectory 'approved.json'
    if ($tier -eq 'Experimental' -and $ApprovalAction -ne 'Prepare') {
      switch ($ApprovalAction) {
        'Inspect' {
          $inspection = Get-CSharpPackagePreparedManifestInspection -ManifestPath $preparedManifestPath
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Prepared manifest inspected; SHA256='$($inspection.PreparedManifestSha256)'; packages=$($inspection.Packages.Count). No feed was mutated."
          return
        }
        'Approve' {
          if ([string]::IsNullOrWhiteSpace($ExpectedPreparedManifestSha256) -or [string]::IsNullOrWhiteSpace($ApprovedBy)) {
            throw 'Approve requires ExpectedPreparedManifestSha256 and ApprovedBy.'
          }
          $approval = Approve-CSharpPackagePreparedManifest `
            -ManifestPath $preparedManifestPath `
            -ExpectedPreparedManifestSha256 $ExpectedPreparedManifestSha256 `
            -ApprovedBy $ApprovedBy `
            -ApprovalPath $approvalRecordPath
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Prepared manifest approved by '$ApprovedBy'; approval SHA256='$($approval.ApprovalSha256)'. No feed was mutated."
          return
        }
        'Publish' {
          $authorization = Assert-CSharpPackagePublicationAuthorized -ManifestPath $preparedManifestPath -ApprovalPath $approvalRecordPath
          foreach ($package in $authorization.Packages) {
            $publishResult = Publish-NuGetPackageToProGet `
              -NupkgPath $package.Path `
              -Feed $ExperimentalFeed `
              -ProGetApiKeySecretName $ProGetApiKeySecretName
            Assert-BuildMasterOperationSucceeded -Result $publishResult -OperationName 'Publish-NuGetPackageToProGet'
          }
          $packageVersionForRun = [string]$authorization.Manifest.PackageVersion
          $metaPackageNupkg = Find-CSharpMetaPackageNupkg -PackageDirectory $PackageOutputPath -MetaPackageName $MetaPackageName
          $metaPackageNupkg.FullName | Set-Content -LiteralPath $NupkgPathFile -Encoding utf8 -NoNewline
          Update-CSharpPackagePackageContext -PackageVersion $packageVersionForRun -NupkgPath $metaPackageNupkg.FullName
          Set-CSharpPackageStageCompleted -ContextDirectory $contextDirectory -MetaPackageName $MetaPackageName -Tier 'Experimental' -PackageVersion $packageVersionForRun
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Authorized Experimental publish complete for '$MetaPackageName' version '$packageVersionForRun'; approved SHA256='$($authorization.PreparedManifestSha256)'."
          return
        }
      }
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
            New-Item -ItemType Directory -Path (Split-Path -Parent $artifactsContext.BinlogPath) -Force | Out-Null

            $publishTracePath = Join-Path -Path $contextDirectory -ChildPath "$MetaPackageName.publish.log"
            Add-BuildMasterPublishTrace -Path $publishTracePath -Message "dotnet build '$resolvedProjectPath' -c '$Configuration' (deterministic)."

            $buildArgs = @(
              'build', $resolvedProjectPath,
              '--configuration', $Configuration,
              '--no-incremental',
              '--artifacts-path', $resolvedArtifactsPath,
              '-p:ContinuousIntegrationBuild=true',
              "-p:ATAPArtifactsRoot=$($artifactsContext.Root)",
              "-p:ATAPArtifactsWorktreeId=$($artifactsContext.WorktreeId)",
              "-p:ATAPArtifactsExecutionId=$($artifactsContext.ExecutionId)",
              "/bl:$($artifactsContext.BinlogPath)"
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

            $deterministicPackTool = Resolve-DeterministicNuGetMSBuild
            $sourceDateEpoch = Get-SourceDateEpoch -RepositoryPath $SourcePath
            $packVerificationRoot = Join-Path -Path $contextDirectory -ChildPath "$MetaPackageName.deterministic-pack.$([guid]::NewGuid().ToString('N'))"
            $packRecordsByRun = @()
            foreach ($packRun in 1..2) {
              $packRunOutputPath = Join-Path -Path $packVerificationRoot -ChildPath "run$packRun"
              New-Item -ItemType Directory -Path $packRunOutputPath -Force | Out-Null
              $packArgs = @(
                $resolvedProjectPath,
                '/t:Pack',
                "/p:Configuration=$Configuration",
                '/p:NoBuild=true',
                "/p:PackageOutputPath=$packRunOutputPath",
                '/p:ContinuousIntegrationBuild=true',
                '/p:Deterministic=true',
                "/p:DeterministicTimestamp=$sourceDateEpoch",
                "/p:ArtifactsPath=$resolvedArtifactsPath",
                "/p:ATAPArtifactsRoot=$($artifactsContext.Root)",
                "/p:ATAPArtifactsWorktreeId=$($artifactsContext.WorktreeId)",
                "/p:ATAPArtifactsExecutionId=$($artifactsContext.ExecutionId)",
                "/bl:$(Join-Path (Split-Path -Parent $artifactsContext.BinlogPath) "pack-run-$packRun.binlog")",
                '/m:1',
                '/nr:false'
              )
              Add-BuildMasterPublishTrace -Path $publishTracePath -Message "Deterministic pack run ${packRun}: Visual Studio MSBuild '$($deterministicPackTool.MSBuildVersion)', SDK '$($deterministicPackTool.SDKVersion)', and NuGet Pack '$($deterministicPackTool.NuGetPackVersion)' pack '$resolvedProjectPath' with DeterministicTimestamp='$sourceDateEpoch'."
              try {
                & $deterministicPackTool.MSBuildPath @packArgs
                $packExit = $LASTEXITCODE
              }
              catch {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Visual Studio MSBuild deterministic pack run $packRun threw for '$resolvedProjectPath'. Exception: $($_.Exception.Message)"
                throw
              }
              if ($packExit -ne 0) {
                throw "Visual Studio MSBuild deterministic pack run $packRun failed for '$resolvedProjectPath' with exit code $packExit."
              }

              $packRecords = @(
                Get-ChildItem -LiteralPath $packRunOutputPath -File |
                  Where-Object Extension -In @('.nupkg', '.snupkg') |
                  Sort-Object Name |
                  ForEach-Object {
                    [pscustomobject]@{
                      Name   = $_.Name
                      SHA256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
                      Path   = $_.FullName
                    }
                  }
              )
              if ($packRecords.Count -eq 0) {
                throw "Deterministic pack run $packRun emitted no NuGet packages under '$packRunOutputPath'."
              }
              $packRecordsByRun += ,$packRecords
            }

            $run1IdentityAndHashes = @($packRecordsByRun[0] | Select-Object Name, SHA256 | ConvertTo-Json -Compress)
            $run2IdentityAndHashes = @($packRecordsByRun[1] | Select-Object Name, SHA256 | ConvertTo-Json -Compress)
            if ($run1IdentityAndHashes.Count -ne 1 -or $run2IdentityAndHashes.Count -ne 1 -or $run1IdentityAndHashes[0] -cne $run2IdentityAndHashes[0]) {
              $comparisonPath = Join-Path -Path $packVerificationRoot -ChildPath 'package-hash-comparison.json'
              [pscustomobject]@{ Run1 = $packRecordsByRun[0]; Run2 = $packRecordsByRun[1]; Equal = $false } |
                ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $comparisonPath -Encoding utf8
              throw "Deterministic two-pack SHA-256 gate failed. No feed was mutated. Evidence: '$comparisonPath'."
            }

            $existingPackageOutputs = @(Get-ChildItem -LiteralPath $PackageOutputPath -File | Where-Object Extension -In @('.nupkg', '.snupkg'))
            if ($existingPackageOutputs.Count -gt 0) {
              throw "Final package output '$PackageOutputPath' is not empty; refusing to overwrite package artifacts after the deterministic gate."
            }
            $packRecordsByRun[0] | ForEach-Object { Copy-Item -LiteralPath $_.Path -Destination $PackageOutputPath }
            [pscustomobject]@{ Run1 = $packRecordsByRun[0]; Run2 = $packRecordsByRun[1]; Equal = $true } |
              ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $packVerificationRoot 'package-hash-comparison.json') -Encoding utf8
            Add-BuildMasterPublishTrace -Path $publishTracePath -Message "Deterministic two-pack SHA-256 gate passed for $($packRecordsByRun[0].Count) package artifact(s); copied run 1 bytes to '$PackageOutputPath'."

            $metaPackageNupkg = Find-CSharpMetaPackageNupkg -PackageDirectory $PackageOutputPath -MetaPackageName $MetaPackageName
            $metaPackageNupkg.FullName | Set-Content -LiteralPath $NupkgPathFile -Encoding utf8 -NoNewline
            $packageVersionForRun = Get-CSharpPackagePackageVersionFromNupkgPath -NupkgPath $metaPackageNupkg.FullName -PackageName $PackageName
            Update-CSharpPackagePackageContext -PackageVersion $packageVersionForRun -NupkgPath $metaPackageNupkg.FullName

            Add-BuildMasterPublishTrace -Path $publishTracePath -Message "Captured meta-package '$($metaPackageNupkg.Name)' version '$packageVersionForRun'."

            $allNupkgs = @(Get-ChildItem -LiteralPath $PackageOutputPath -Filter '*.nupkg' -File)
            $sourceCommit = (& git -C $SourcePath rev-parse HEAD 2>$null).Trim()
            if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch '^[0-9a-fA-F]{40}$') {
              throw "Cannot prepare publication because Git HEAD could not be resolved for '$SourcePath'."
            }
            $prepared = New-CSharpPackagePreparedManifest `
              -ArtifactsPath $resolvedArtifactsPath `
              -ManifestPath $preparedManifestPath `
              -NupkgPath $allNupkgs.FullName `
              -BuildMasterBuildId $BuildMasterBuildId `
              -SourceCommit $sourceCommit `
              -PackageVersion $packageVersionForRun
            Add-BuildMasterPublishTrace -Path $publishTracePath -Message "Prepared immutable package set; manifest SHA256='$($prepared.PreparedManifestSha256)'. No feed was mutated."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Experimental preparation complete for '$MetaPackageName' version '$packageVersionForRun'; inspect '$preparedManifestPath' and approve SHA256='$($prepared.PreparedManifestSha256)' before Publish. No feed was mutated."
            return
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
  -ArtifactsPath $ArtifactsPath `
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
  -ApprovalAction $ApprovalAction `
  -ExpectedPreparedManifestSha256 $ExpectedPreparedManifestSha256 `
  -ApprovedBy $ApprovedBy `
  -PackageOutputPath $PackageOutputPath `
  -NupkgPathFile $NupkgPathFile `
  -ProGetUrl $ProGetUrl `
  -ProGetApiKeySecretName $ProGetApiKeySecretName `
  -ExperimentalFeed $ExperimentalFeed `
  -DevelopmentFeed $DevelopmentFeed `
  -IntegrationFeed $IntegrationFeed `
  -QAFeed $QAFeed `
  -ProductionFeed $ProductionFeed

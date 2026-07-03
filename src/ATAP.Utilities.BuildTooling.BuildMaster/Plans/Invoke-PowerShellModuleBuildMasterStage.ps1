<#
.SYNOPSIS
  Drives a single BuildMaster stage of a PowerShell-module 5-tier pipeline.

.DESCRIPTION
  Eponymous entry-point script. Resolves the BuildMaster run-context, evaluates
  the per-tier allow decisions against the package ceiling, then for each tier
  from the current stage up to the ceiling either:
    * Experimental: invokes module.build.ps1 via Invoke-ModuleBuildWithRetry,
      locates the produced .nupkg, captures its immutable version, registers
      the PSResourceRepository, and publishes the package to the Experimental
      feed (idempotent across reruns).
    * Other tiers: promotes the captured package version between ProGet feeds
      using Promote-ProGetPackage, then runs Invoke-PromotedModuleTests.

  Stage completion markers ($ModuleName.$Tier.completed.tmp) make reruns within
  a single BuildMaster build id idempotent. Captured package version is stored
  on the build-context.json document and never re-derived after Experimental.

  Designed to be invoked from an OtterScript plan via 'Exec pwsh -File'.

.PARAMETER BuildToolingModulePath
  Path to the ATAP.Utilities.BuildTooling.PowerShell module manifest or folder.

.PARAMETER SourcePath
  Working copy / repository root. _generated/buildmaster lives beneath this.

.PARAMETER BuildMasterBuildId
  BuildMaster build id used as the per-build context folder name.

.PARAMETER BuildNumber
  Optional BuildMaster build number for traceability.

.PARAMETER ExecutionId
  Optional BuildMaster execution identifier for traceability.

.PARAMETER ApplicationName
  The product/application this pipeline targets.

.PARAMETER ModuleName
  PowerShell module name being built (drives state-file naming).

.PARAMETER PackageName
  Optional NuGet package id; defaults to ModuleName.

.PARAMETER ModulePath
  Optional explicit module source path; defaults to $SourcePath/src/$ModuleName.

.PARAMETER Branch
  Optional source-branch label.

.PARAMETER Stage
  Optional BuildMaster stage hint passed to Get-BuildContext.

.PARAMETER PackageOutputPath
  Optional override of module.build.ps1 package output directory; in practice
  it is forced to a build-scoped path under the run-context directory.

.PARAMETER NupkgPathFile
  Optional file path that receives the latest produced .nupkg path; defaults to
  $contextDirectory/$ModuleName.nupkg-path.tmp.

.PARAMETER CurrentTier
.PARAMETER CeilingTier
.PARAMETER ResolvedPackageVersion
  Legacy passthrough parameters preserved for backwards compatibility with the
  OtterScript plan; the current implementation reads these from Get-BuildContext
  and the captured build-context.json.

.PARAMETER ProGetUrl
  Base URL of the ProGet server hosting the PowerShellGet feeds.

.PARAMETER AllowExperimental
.PARAMETER AllowDevelopment
.PARAMETER AllowIntegration
.PARAMETER AllowQA
.PARAMETER AllowProduction
  Legacy passthrough parameters preserved for backwards compatibility with the
  OtterScript plan; the current implementation re-derives Allow decisions from
  the captured CeilingTier.

.PARAMETER ExperimentalFeed
.PARAMETER DevelopmentFeed
.PARAMETER IntegrationFeed
.PARAMETER QAFeed
.PARAMETER ProductionFeed
  PowerShellGet feed names per tier.

.OUTPUTS
  None. Side effects: module build, ProGet publish / promote, test run.

.EXAMPLE
  pwsh -File Invoke-PowerShellModuleBuildMasterStage.ps1 `
    -BuildToolingModulePath C:\src\repo\src\ATAP.Utilities.BuildTooling.PowerShell `
    -SourcePath C:\src\repo `
    -BuildMasterBuildId 12345 `
    -ApplicationName MyApp `
    -ModuleName ATAP.Utilities.Foo `
    -ProGetUrl https://proget.local

.NOTES
  AI assisted using Powershell.instructions.md as guidelines

.LINK
  BuildMasterRunContext.Common.ps1
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
  [ValidateNotNullOrEmpty()]
  [string]$ProGetUrl,

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

# Initialize host settings using the standalone loader (Task 9.38). This populates
# the settings and configRootKeys globals in memory in this profileless shell.

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
Initialize-LocalHostSettings -SourcePath $SourcePath

function Add-GitSafeDirectoryForCurrentProcess {
  <#
  .SYNOPSIS
    Adds a process-local git safe.directory entry for the supplied repo path.
  .DESCRIPTION
    BuildMaster service runs under a different identity than the workspace owner,
    so we have to allowlist the directory inside this process only.
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

function Get-PowerShellGetFeedUri {
  <#
  .SYNOPSIS
    Returns the canonical PowerShellGet (NuGet v2) feed URI for a feed name.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$BaseUrl,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$FeedName
  )

  BEGIN {
    $fn = 'Get-PowerShellGetFeedUri'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
    return ('{0}/nuget/{1}/' -f $BaseUrl.TrimEnd('/'), $FeedName)
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Convert-BuildMasterTierToModuleBuildTier {
  <#
  .SYNOPSIS
    Maps a BuildMaster tier name to the corresponding module.build.ps1 tier.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Tier
  )

  BEGIN {
    $fn = 'Convert-BuildMasterTierToModuleBuildTier'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn (Tier='$Tier')"
  }

  PROCESS {
    switch ($Tier.Trim().ToLowerInvariant()) {
      'experimental' { return 'Sprint' }
      'development'  { return 'Alpha' }
      'integration'  { return 'Beta' }
      'qa'           { return 'QA' }
      'production'   { return 'Production' }
      default {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Unsupported BuildMaster tier '$Tier'."
        throw "Unsupported BuildMaster tier '$Tier'. Expected one of: Experimental, Development, Integration, QA, Production."
      }
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Find-LatestPowerShellModulePackage {
  <#
  .SYNOPSIS
    Returns the most recently written .nupkg under the given directory.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageDirectory
  )

  BEGIN {
    $fn = 'Find-LatestPowerShellModulePackage'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
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

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Get-PowerShellModulePackageVersionFromNupkgPath {
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
    $fn = 'Get-PowerShellModulePackageVersionFromNupkgPath'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
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

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Test-ProGetPackageVersionInFeed {
  <#
  .SYNOPSIS
    Returns $true if ProGet reports the supplied package version present in the feed.
  .DESCRIPTION
    Tolerates several ProGet response shapes (string, array, nested versions
    collections). Any HTTP error is treated as 'not present' rather than failure.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$BaseUrl,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$FeedName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Version,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApiKey
  )

  BEGIN {
    $fn = 'Test-ProGetPackageVersionInFeed'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn (Feed='$FeedName'; Version='$Version')"

    function Test-ProGetPackageVersionMatch {
      param(
        [Parameter(Mandatory = $false)][AllowNull()][object]$Value,
        [Parameter(Mandatory)][string]$ExpectedVersion
      )
      if ($null -eq $Value) { return $false }
      if ($Value -is [string]) { return ([string]$Value -eq $ExpectedVersion) }
      if ($Value -is [System.Collections.IEnumerable]) {
        foreach ($entry in $Value) {
          if (Test-ProGetPackageVersionMatch -Value $entry -ExpectedVersion $ExpectedVersion) { return $true }
        }
        return $false
      }
      $propertyNames = @($Value.PSObject.Properties.Name)
      foreach ($versionProperty in @('version', 'Version', 'packageVersion', 'PackageVersion', 'versionNumber', 'VersionNumber')) {
        if ($propertyNames -contains $versionProperty) {
          if ([string]$Value.$versionProperty -eq $ExpectedVersion) { return $true }
        }
      }
      foreach ($collectionProperty in @('versions', 'Versions', 'items', 'Items', 'data', 'Data')) {
        if ($propertyNames -contains $collectionProperty) {
          if (Test-ProGetPackageVersionMatch -Value $Value.$collectionProperty -ExpectedVersion $ExpectedVersion) { return $true }
        }
      }
      return $false
    }
  }

  PROCESS {
    $trimmedBaseUrl = $BaseUrl.TrimEnd('/')
    $checkUrl = "$trimmedBaseUrl/api/packages/$FeedName/versions" +
      "?name=$([uri]::EscapeDataString($PackageName))&version=$([uri]::EscapeDataString($Version))"
    $headers = @{
      'Accept'   = 'application/json'
      'X-ApiKey' = $ApiKey
    }

    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $checkUrl" -Tag 'RestCall'
      $response = Invoke-RestMethod -Uri $checkUrl -Headers $headers -Method Get -TimeoutSec 15 -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $checkUrl" -Tag 'RestCall'
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "ProGet version probe failed for '$PackageName'@'$Version' at '$checkUrl': $($_.Exception.Message). Treating as not-present." -Tag 'RestCall'
      return $false
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Probe complete for '$checkUrl'." -Tag 'RestCall'
    }

    return (Test-ProGetPackageVersionMatch -Value $response -ExpectedVersion $Version)
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Publish-PowerShellModulePackageToExperimental {
  <#
  .SYNOPSIS
    Publishes a .nupkg to the Experimental feed via Publish-PSResource.
  .DESCRIPTION
    Treats 'already present / duplicate version / 409' as success because reruns
    of the Experimental stage must be idempotent within one BuildMaster build id.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$NupkgPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$FeedName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApiKey
  )

  BEGIN {
    $fn = 'Publish-PowerShellModulePackageToExperimental'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn (FeedName='$FeedName')"
  }

  PROCESS {
    try {
      Publish-PSResource -NupkgPath $NupkgPath -Repository $FeedName -ApiKey $ApiKey
      return "Published '$NupkgPath' to '$FeedName'."
    }
    catch {
      $message = [string]$_.Exception.Message
      if ($message -match '(?i)already exists|already present|duplicate version|409') {
        return "Package '$NupkgPath' is already present in '$FeedName'; treating re-execution as idempotent success."
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed Publish-PSResource '$NupkgPath' -> '$FeedName'. Exception: $message"
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Publish attempt complete for '$NupkgPath'."
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Finished $fn"
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

function Select-ModuleBuildRetryResult {
  <#
  .SYNOPSIS
    Pipeline filter that selects Invoke-ModuleBuildWithRetry result objects.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline)][object]$InputObject
  )

  BEGIN {
    $fn = 'Select-ModuleBuildRetryResult'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
    if ($null -ne $InputObject -and $InputObject.PSObject.Properties.Name -contains 'ExitCode') {
      $InputObject
    }
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
    if ($Result.PSObject.Properties.Name -contains 'Succeeded' -and -not [bool]$Result.Succeeded) {
      throw "$OperationName reported Succeeded=false. $($Result.ResponseSummary)"
    }
    if ($Result.PSObject.Properties.Name -contains 'GatePass' -and -not [bool]$Result.GatePass) {
      throw "$OperationName reported GatePass=false. $($Result.ResponseSummary)"
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Set-PSResourceRepositoryEnsured {
  <#
  .SYNOPSIS
    Registers or updates a PSResourceRepository so $Name -> $Uri (Trusted, V2).
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Name,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Uri
  )

  BEGIN {
    $fn = 'Set-PSResourceRepositoryEnsured'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn (Name='$Name')"
  }

  PROCESS {
    try {
      $existing = Get-PSResourceRepository -Name $Name -ErrorAction SilentlyContinue
      if ($null -eq $existing) {
        if ($PSCmdlet.ShouldProcess($Name, 'Register-PSResourceRepository')) {
          Register-PSResourceRepository -Name $Name -Uri $Uri -Trusted -ApiVersion V2
        }
        return
      }
      if ($PSCmdlet.ShouldProcess($Name, 'Set-PSResourceRepository')) {
        Set-PSResourceRepository -Name $Name -Uri $Uri -Trusted -ApiVersion V2
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to ensure PSResourceRepository '$Name' at '$Uri'. Exception: $($_.Exception.Message)"
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Ensure complete for '$Name'."
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Finished $fn"
  }
}
Set-Alias -Name Ensure-PSResourceRepository -Value Set-PSResourceRepositoryEnsured

function Get-PowerShellModuleStageCompletionMarkerPath {
  <#
  .SYNOPSIS
    Returns the per-module, per-tier completion marker file path.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ContextDirectory,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ModuleName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Tier
  )

  BEGIN {
    $fn = 'Get-PowerShellModuleStageCompletionMarkerPath'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
    return (Join-Path -Path $ContextDirectory -ChildPath "$ModuleName.$Tier.completed.tmp")
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Set-PowerShellModuleStageCompleted {
  <#
  .SYNOPSIS
    Writes a completion marker JSON for a given module/tier/version.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ContextDirectory,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ModuleName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Tier,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageVersion
  )

  BEGIN {
    $fn = 'Set-PowerShellModuleStageCompleted'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn (Tier='$Tier'; Version='$PackageVersion')"
  }

  PROCESS {
    $markerPath = Get-PowerShellModuleStageCompletionMarkerPath -ContextDirectory $ContextDirectory -ModuleName $ModuleName -Tier $Tier
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

function Test-PowerShellModuleStageCompleted {
  <#
  .SYNOPSIS
    Returns $true if the completion marker for a module/tier exists.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ContextDirectory,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ModuleName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Tier
  )

  BEGIN {
    $fn = 'Test-PowerShellModuleStageCompleted'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
    $markerPath = Get-PowerShellModuleStageCompletionMarkerPath -ContextDirectory $ContextDirectory -ModuleName $ModuleName -Tier $Tier
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

function Get-PowerShellModulePackageVersionForRun {
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
    $fn = 'Get-PowerShellModulePackageVersionForRun'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
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

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Invoke-PowerShellModuleBuildMasterStage {
  <#
  .SYNOPSIS
    Eponymous worker that drives one BuildMaster stage of the 5-tier PowerShell-module pipeline.
  .DESCRIPTION
    See file-level comment-based help. Implements the run loop over current..ceiling tiers,
    handling Experimental (build + publish) and promotion tiers (promote + test) and emitting
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
    [Parameter(Mandatory)][string]$ModuleName,
    [AllowEmptyString()][string]$PackageName = '',
    [AllowEmptyString()][string]$ModulePath = '',
    [AllowEmptyString()][string]$Branch = '',
    [AllowEmptyString()][string]$Stage = '',
    [AllowEmptyString()][string]$PackageOutputPath = '',
    [AllowEmptyString()][string]$NupkgPathFile = '',
    [Parameter(Mandatory)][string]$ProGetUrl,
    [string]$ExperimentalFeed = 'powershellget-experimental',
    [string]$DevelopmentFeed = 'powershellget-development',
    [string]$IntegrationFeed = 'powershellget-integration',
    [string]$QAFeed = 'powershellget-qa',
    [string]$ProductionFeed = 'powershellget-stable'
  )

  BEGIN {
    $fn = 'Invoke-PowerShellModuleBuildMasterStage'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn for BuildId='$BuildMasterBuildId'; Module='$ModuleName'"

    # Load helper functions
    # None of this is needed once the modules are built and installed into the PSModulePath, but while we are still
    # running from source code, we need to dot source the helper functions that are not yet in a module. Once the
    # modules are built and installed, all of the helper functions will be available as cmdlets and this block can be
    # removed.
    $helpfunctionsneeded = @(
      @{FunctionName = 'Get-RepositoryRoot'; ModuleName = 'ATAP.Utilities.BuildTooling.PowerShell' },
      @{FunctionName = 'Get-ClonedAndModifiedHashtable'; ModuleName = 'ATAP.Utilities.PowerShell' },
      @{FunctionName = 'Get-ParameterValueFromNeoConfigurationRoot'; ModuleName = 'ATAP.Utilities.PowerShell' }
    )
    $resolvedModulePath = Join-Path -Path $SourcePath -ChildPath 'src'
    foreach ($helpfunction in $helpfunctionsneeded) {
      $helperPath = Join-Path -Path $resolvedModulePath -ChildPath (Join-Path -Path $helpfunction.ModuleName -ChildPath (Join-Path -Path 'public' -ChildPath "$($helpfunction.FunctionName).ps1"))
      try {
        if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
          throw "Source helper file not found: $helperPath"
        }
        . $helperPath
      }
      catch {
        $errorMessage = "Failed to load $($helpfunction.FunctionName) from source path '$helperPath'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw
      }
    }
    # End of help loading block

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
    . (Resolve-BuildToolingFunctionFile -RelativePath 'public/Invoke-ModuleBuildWithRetry.ps1')
    . (Resolve-BuildToolingFunctionFile -RelativePath 'public/Move-ProGetPackageInterTier.ps1')
    . (Resolve-BuildToolingFunctionFile -RelativePath 'public/Promote-ProGetPackage.ps1')
    . (Resolve-BuildToolingFunctionFile -RelativePath 'public/Invoke-PSModulePesterTests.ps1')
    . (Resolve-BuildToolingFunctionFile -RelativePath 'public/Invoke-PromotedModuleTests.ps1')

    if ([string]::IsNullOrWhiteSpace($PackageName)) { $PackageName = $ModuleName }
    if ([string]::IsNullOrWhiteSpace($ModulePath)) {
      $ModulePath = Join-Path -Path $SourcePath -ChildPath "src/$ModuleName"
    }

    $neoConfigurationPath = Join-Path -Path $SourcePath -ChildPath 'src/ATAP.Utilities.PowerShell/public/Get-ParameterValueFromNeoConfigurationRoot.ps1'
    if (-not (Test-Path -LiteralPath $neoConfigurationPath -PathType Leaf)) {
      throw "Required NeoConfigurationRoot helper not found: $neoConfigurationPath"
    }
    . $neoConfigurationPath
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

    $moduleBuildOutputRoot = Join-Path -Path $contextDirectory -ChildPath "psmodules/$ModuleName"
    $moduleBuildPackageOutputPath = Join-Path -Path $moduleBuildOutputRoot -ChildPath 'packages'
    if ([string]::IsNullOrWhiteSpace($PackageOutputPath)) {
      $PackageOutputPath = $moduleBuildPackageOutputPath
    }
    elseif ([System.IO.Path]::GetFullPath($PackageOutputPath) -ne [System.IO.Path]::GetFullPath($moduleBuildPackageOutputPath)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Ignoring PackageOutputPath '$PackageOutputPath' because BuildMaster runs module.build.ps1 with build-scoped package output '$moduleBuildPackageOutputPath'."
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

    function Update-PowerShellModulePackageContext {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)][string]$PackageVersion,
        [AllowEmptyString()][string]$NupkgPath = ''
      )
      BEGIN { $f = 'Update-PowerShellModulePackageContext'; $m = 'ATAP.Utilities.BuildTooling.BuildMaster' }
      PROCESS {
        $additionalData = @{
          PipelineKind   = 'PowerShellModule'
          ModuleName     = $ModuleName
          PackageName    = $PackageName
          PackageVersion = $PackageVersion
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
          -ProjectPath $ModulePath `
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

    function Invoke-PowerShellModulePromotionAndTests {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)][string]$Tier,
        [Parameter(Mandatory)][string]$PromotedPackageVersion
      )
      BEGIN { $f = 'Invoke-PowerShellModulePromotionAndTests'; $m = 'ATAP.Utilities.BuildTooling.BuildMaster' }
      PROCESS {
        $previousTier = Get-PreviousBuildMasterTier -Tier $Tier
        $sourceFeed = $feedByTier[$previousTier]
        $destinationFeed = $feedByTier[$Tier]
        if ([string]::IsNullOrWhiteSpace($sourceFeed) -or [string]::IsNullOrWhiteSpace($destinationFeed)) {
          throw "Cannot resolve PowerShellGet promotion feeds for '$previousTier' -> '$Tier'."
        }

        Write-PSFMessage -FunctionName $f -ModuleName $m -Level Important -Message "PowerShell module stage '$Tier' starting promotion/test for '$PackageName' version '$PromotedPackageVersion' from '$sourceFeed' to '$destinationFeed'."
        $promotionTracePath = Join-Path -Path $contextDirectory -ChildPath "$ModuleName.$($Tier.ToLowerInvariant()).log"
        Add-BuildMasterPublishTrace -Path $promotionTracePath -Message "Promoting '$PackageName' version '$PromotedPackageVersion' from '$sourceFeed' to '$destinationFeed'. Captured resolved version is '$capturedResolvedVersion'."

        $env:PROGET_BUILDMASTER_API_KEY = $script:resolvedProGetApiKey
        $global:ProGetBaseUrl = $ProGetUrl

        $destinationFeedUri = Get-PowerShellGetFeedUri -BaseUrl $ProGetUrl -FeedName $destinationFeed
        Set-PSResourceRepositoryEnsured -Name $destinationFeed -Uri $destinationFeedUri
        Add-BuildMasterPublishTrace -Path $promotionTracePath -Message "PSResourceRepository '$destinationFeed' is registered at '$destinationFeedUri'."

        Write-PSFMessage -FunctionName $f -ModuleName $m -Level Important -Message "Promoting '$PackageName' version '$PromotedPackageVersion' from '$sourceFeed' to '$destinationFeed'."
        try {
          $promotionResult = Promote-ProGetPackage `
            -Name $PackageName `
            -Version $PromotedPackageVersion `
            -FromFeed $sourceFeed `
            -ToFeed $destinationFeed `
            -Reason "$Tier gate for $ApplicationName $PromotedPackageVersion on $Branch" `
            -ProGetBaseUrl $ProGetUrl `
            -ApiKey $script:resolvedProGetApiKey `
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
        $pesterOutputVerbosity = 'None'
        if (-not [string]::IsNullOrWhiteSpace($env:ATAP_BUILDTOOLING_PESTER_OUTPUT_VERBOSITY)) {
          $requestedVerbosity = $env:ATAP_BUILDTOOLING_PESTER_OUTPUT_VERBOSITY.Trim()
          if ($requestedVerbosity -in @('None', 'Normal', 'Detailed', 'Diagnostic')) {
            $pesterOutputVerbosity = $requestedVerbosity
          } else {
            Write-PSFMessage -FunctionName $f -ModuleName $m -Level Warning -Message "Ignoring unsupported ATAP_BUILDTOOLING_PESTER_OUTPUT_VERBOSITY '$requestedVerbosity'."
          }
        }
        try {
          $testResult = Invoke-PromotedModuleTests `
            -Name $PackageName `
            -Version $PromotedPackageVersion `
            -Feed $destinationFeed `
            -Tier $Tier `
            -ResultsPath $resultsPath `
            -ModuleSourceRoot $ModulePath `
            -WorkingDirectory $SourcePath `
            -ProGetBaseUrl $ProGetUrl `
            -ApiKey $script:resolvedProGetApiKey `
            -PesterOutputVerbosity $pesterOutputVerbosity
        }
        catch {
          Write-PSFMessage -FunctionName $f -ModuleName $m -Level Error -Message "Invoke-PromotedModuleTests threw for '$PackageName' '$PromotedPackageVersion'. Exception: $($_.Exception.Message)"
          throw
        }
        finally {
          Write-PSFMessage -FunctionName $f -ModuleName $m -Level Debug -Message "Invoke-PromotedModuleTests call complete."
        }
        Assert-BuildMasterOperationSucceeded -Result $testResult -OperationName 'Invoke-PromotedModuleTests'
        Add-BuildMasterPublishTrace -Path $promotionTracePath -Message $testResult.ResponseSummary

        Write-PSFMessage -FunctionName $f -ModuleName $m -Level Important -Message "Promoted '$PackageName' version '$PromotedPackageVersion' to '$destinationFeed' and passed $Tier tests. Ceiling='$ceilingTier'."
      }
      END {}
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
    if ($currentTierIndex -lt 0) { throw "Unsupported BuildMaster tier '$tier'." }
    if ($ceilingTierIndex -lt 0) { throw "Unsupported BuildMaster ceiling tier '$ceilingTier'." }

    $tiersToRun = @()
    for ($tierIndex = $currentTierIndex; $tierIndex -le $ceilingTierIndex; $tierIndex++) {
      $tiersToRun += $tierOrder[$tierIndex]
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "PowerShell module runner will execute tier(s): $($tiersToRun -join ', ') (current='$tier'; ceiling='$ceilingTier')."

    $packageVersionForRun = $null

    Push-Location -LiteralPath $SourcePath
    try {
      foreach ($tierToRun in $tiersToRun) {
        if (-not $allowByTier[$tierToRun]) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Stopping PowerShell module auto-advance before '$tierToRun' because ceiling '$ceilingTier' does not allow it."
          break
        }

        if (Test-PowerShellModuleStageCompleted -ContextDirectory $contextDirectory -ModuleName $ModuleName -Tier $tierToRun) {
          $completedTierIndex = $tierOrder.IndexOf($tierToRun)
          if ($tierToRun -eq $tier -and $completedTierIndex -ge $ceilingTierIndex) {
            if (($completedTierIndex + 1) -ge $tierOrder.Count) {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "PowerShell module final stage '$tierToRun' already completed for build '$BuildMasterBuildId'; accepting no-op deployment."
              continue
            }
            throw "PowerShell module stage '$tierToRun' already completed for build '$BuildMasterBuildId' and ceiling '$ceilingTier' has been reached. Refusing a successful no-op deployment because BuildMaster would advance the next stage above the ceiling."
          }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "PowerShell module stage '$tierToRun' already completed for build '$BuildMasterBuildId'; skipping re-execution."
          continue
        }

        switch ($tierToRun) {
          'Experimental' {
            New-Item -ItemType Directory -Path (Split-Path -Parent $NupkgPathFile) -Force | Out-Null
            $moduleBuildTier = Convert-BuildMasterTierToModuleBuildTier -Tier $tierToRun
            $buildLogPath = Join-Path -Path $contextDirectory -ChildPath 'PSModuleBuildLogs'
            try {
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
            }
            catch {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Invoke-ModuleBuildWithRetry threw for '$ModuleName'. Exception: $($_.Exception.Message)"
              throw
            }
            finally {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Invoke-ModuleBuildWithRetry call complete."
            }
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
            Set-PSResourceRepositoryEnsured -Name $ExperimentalFeed -Uri $feedUri
            Add-BuildMasterPublishTrace -Path $publishTracePath -Message "PSResourceRepository '$ExperimentalFeed' is registered."

            $env:PROGET_APIKEY_POWERSHELLGET_EXPERIMENTAL = $script:resolvedProGetApiKey
            $env:PROGET_ADMIN_API_KEY = $script:resolvedProGetApiKey

            try {
              $publishSummary = Publish-PowerShellModulePackageToExperimental -NupkgPath $nupkg.FullName -FeedName $ExperimentalFeed -ApiKey $script:resolvedProGetApiKey
              Add-BuildMasterPublishTrace -Path $publishTracePath -Message $publishSummary
            }
            catch {
              Add-BuildMasterPublishTrace -Path $publishTracePath -Message "ERROR: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
              throw
            }
            finally {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Experimental publish attempt complete."
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "$publishSummary Ceiling='$ceilingTier'. module.build.ps1 tier='$moduleBuildTier'."
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
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "PowerShell module stage '$tierToRun' completed; next stage gate '$nextTier' is within ceiling '$ceilingTier', continuing."
        }
        elseif ($completedTierIndex + 1 -lt $tierOrder.Count) {
          $nextTier = $tierOrder[$completedTierIndex + 1]
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "PowerShell module stage '$tierToRun' completed; next stage '$nextTier' exceeds ceiling '$ceilingTier', stopping."
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "PowerShell module stage '$tierToRun' completed at final tier '$ceilingTier'."
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

Invoke-PowerShellModuleBuildMasterStage `
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
  -PackageOutputPath $PackageOutputPath `
  -NupkgPathFile $NupkgPathFile `
  -ProGetUrl $ProGetUrl `
  -ExperimentalFeed $ExperimentalFeed `
  -DevelopmentFeed $DevelopmentFeed `
  -IntegrationFeed $IntegrationFeed `
  -QAFeed $QAFeed `
  -ProductionFeed $ProductionFeed

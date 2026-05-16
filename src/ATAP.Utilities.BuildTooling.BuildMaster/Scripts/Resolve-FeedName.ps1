<#
.SYNOPSIS
  Resolves a ProGet feed name for a given 5-Tier tier and feed type from
  BuildTooling settings, then writes it to an output file for OtterScript consumption.

.DESCRIPTION
  This script is designed to be invoked from an OtterScript plan via `Exec pwsh`.
  It translates the OtterScript $Tier variable (Experimental/Development/Integration/
  QA/Production) to the canonical ProGet feed tier, resolves the value via
  Resolve-ProGetFeedFromSettings, and writes the result to -OutputFile so
  OtterScript can read it back with $FileContents().

  If $global:Settings/$global:configRootKeys are not already initialized, the script
  bootstraps the ProGet feed collection from the machine-scope compatibility export
  written by New-HostSettingsForPackageRepositoryFeeds.

  Exit code 0 = success. Any other exit code = failure.

.PARAMETER Tier
  The 5-Tier tier name. One of:
    Experimental, Development, Integration, QA, Production (Stable).

.PARAMETER FeedType
  The feed type. One of: nuget, powershellget.

.PARAMETER OutputFile
  Relative or absolute path where the resolved feed name is written (no newline).
  Defaults to '_feedname.tmp' in the current directory.

.PARAMETER SettingsPath
  Optional path to the machine-scope HostSettings.PackageRepositoryFeeds.psd1 file.
  Defaults to $env:ProgramData\ATAP\HostSettings.PackageRepositoryFeeds.psd1.

.OUTPUTS
  Writes the resolved feed name string to -OutputFile. No pipeline output.

.EXAMPLE
  # From OtterScript:
  Exec pwsh
  (
      Arguments: >>-NoProfile -File Build/BuildMaster/Scripts/Resolve-FeedName.ps1 -Tier $Tier -FeedType nuget -OutputFile _feedname.tmp>>,
      WorkingDirectory: $SourcePath,
      SuccessExitCode: 0
  );
  set $FeedName = $Trim($FileContents($PathCombine($SourcePath, _feedname.tmp)));

.NOTES
  AI assisted using Powershell.instructions.md as guidelines
  Phase 3C — T-31 (7.1-3 OtterScript feed name resolution from BuildTooling settings)
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production', 'Stable')]
  [string] $Tier,

  [Parameter(Mandatory)]
  [ValidateSet('nuget', 'powershell', 'powershellget', 'psresourceget', 'chocolatey')]
  [string] $FeedType,

  [string] $OutputFile = '_feedname.tmp',

  [string] $SettingsPath = (Join-Path $env:ProgramData 'ATAP\HostSettings.PackageRepositoryFeeds.psd1')
)

$fn = 'Resolve-FeedName.ps1'

function Get-RepositoryRoot {
  $current = $PSScriptRoot
  while (-not [string]::IsNullOrWhiteSpace($current)) {
    if (Test-Path -LiteralPath (Join-Path $current '.git')) {
      return $current
    }

    $parent = Split-Path -Parent $current
    if ($parent -eq $current) {
      break
    }
    $current = $parent
  }

  $gitOutput = & git -c safe.directory='*' rev-parse --show-toplevel 2>$null
  if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitOutput)) {
    return [string]$gitOutput.Trim()
  }

  throw "$fn : Unable to locate repository root from '$PSScriptRoot'."
}

function Get-BuildToolingFeedResolverPath {
  if (Get-Command -Name 'Resolve-ProGetFeedFromSettings' -CommandType Function -ErrorAction SilentlyContinue) {
    return $null
  }

  $repoRoot = Get-RepositoryRoot
  $resolverPath = Join-Path $repoRoot 'src\ATAP.Utilities.BuildTooling.PowerShell\private\Resolve-ProGetFeedFromSettings.ps1'
  if (-not (Test-Path -LiteralPath $resolverPath -PathType Leaf)) {
    throw "$fn : Resolve-ProGetFeedFromSettings.ps1 not found at '$resolverPath'."
  }

  return $resolverPath
}

function Initialize-ProGetFeedSettings {
  if ($null -ne $global:Settings -and $null -ne $global:configRootKeys) {
    $feedCollectionKey = $global:configRootKeys['ProGetFeedCollectionConfigRootKey']
    if (-not [string]::IsNullOrWhiteSpace($feedCollectionKey) -and $null -ne $global:Settings[$feedCollectionKey]) {
      return
    }
  }

  if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
    throw "$fn : BuildTooling feed settings are not initialized and '$SettingsPath' was not found. Run New-HostSettingsForPackageRepositoryFeeds or pass -SettingsPath."
  }

  $feedSettings = Import-PowerShellDataFile -LiteralPath $SettingsPath
  if ($null -eq $feedSettings.Feeds) {
    throw "$fn : '$SettingsPath' does not contain a Feeds hashtable."
  }

  if ($null -eq $global:configRootKeys) {
    $global:configRootKeys = @{}
  }
  $global:configRootKeys['ProGetFeedCollectionConfigRootKey'] = 'ProGetFeedCollection'

  if ($null -eq $global:Settings) {
    $global:Settings = @{}
  }
  $global:Settings['ProGetFeedCollection'] = $feedSettings.Feeds
}

$resolverPath = Get-BuildToolingFeedResolverPath
if ($null -ne $resolverPath) {
  . $resolverPath
}
Initialize-ProGetFeedSettings

try {
  $feed = Resolve-ProGetFeedFromSettings -FeedType $FeedType -Tier $Tier
  $feedName = $feed.FeedName
} catch {
  Write-Error "$fn : Failed to resolve feed for Tier='$Tier' FeedType='$FeedType'. $($_.Exception.Message)"
  exit 1
}

if ([string]::IsNullOrWhiteSpace($feedName)) {
  Write-Error "$fn : Resolved feed name for Tier='$Tier' FeedType='$FeedType' is empty."
  exit 1
}

$resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputFile)) {
  $OutputFile
} else {
  Join-Path (Get-Location) $OutputFile
}

$feedName | Out-File -FilePath $resolvedOutput -Encoding utf8 -NoNewline
Write-Host "$fn : Resolved Tier='$Tier' FeedType='$FeedType' -> '$feedName' (written to '$resolvedOutput')"
exit 0

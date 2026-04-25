<#
.SYNOPSIS
  Resolves a ProGet feed name for a given 5-Tier tier and feed type using
  Get-ATAPIACConstant, then writes it to an output file for OtterScript consumption.

.DESCRIPTION
  This script is designed to be invoked from an OtterScript plan via `Exec pwsh`.
  It translates the OtterScript $Tier variable (Experimental/Development/Integration/
  QA/Production) to the canonical ATAP.IAC constant name, resolves the value via
  Get-ATAPIACConstant, and writes the result to -OutputFile so OtterScript can read
  it back with $FileContents().

  If Get-ATAPIACConstant is not available (module not loaded), the script falls back
  to a direct file-load of the ATAP.IAC constants/*.psd1 files by walking up from
  the current git root to the sibling ATAP.IAC repository.

  Exit code 0 = success. Any other exit code = failure.

.PARAMETER Tier
  The 5-Tier tier name. One of:
    Experimental, Development, Integration, QA, Production (Stable).

.PARAMETER FeedType
  The feed type. One of: nuget, powershellget.

.PARAMETER OutputFile
  Relative or absolute path where the resolved feed name is written (no newline).
  Defaults to '_feedname.tmp' in the current directory.

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
  Phase 3C — T-31 (7.1-3 OtterScript feed name resolution via Get-ATAPIACConstant)
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production', 'Stable')]
  [string] $Tier,

  [Parameter(Mandatory)]
  [ValidateSet('nuget', 'powershellget')]
  [string] $FeedType,

  [string] $OutputFile = '_feedname.tmp'
)

$fn = 'Resolve-FeedName.ps1'

# Map 'Production' → 'Stable' (canonical tier name for the stable feed)
$canonicalTier = if ($Tier -eq 'Production') { 'Stable' } else { $Tier }

# Build the ATAP.IAC constant name
$prefix = if ($FeedType -eq 'nuget') { 'NuGetFeedName' } else { 'PowerShellGetFeedName' }
$constantName = "${prefix}_${canonicalTier}"

function Resolve-ViaDirectLoad {
  param([string]$ConstantName)
  # Walk up from current git root to locate sibling ATAP.IAC repository
  $gitOutput = & git rev-parse --show-toplevel 2>&1
  if ($LASTEXITCODE -ne 0) { throw "git rev-parse --show-toplevel failed: $gitOutput" }
  $repoRoot = $gitOutput.Trim()
  $iacRoot = Join-Path (Split-Path -Parent $repoRoot) 'ATAP.IAC'
  if (-not (Test-Path $iacRoot -PathType Container)) {
    throw "ATAP.IAC repository not found at '$iacRoot'."
  }
  $constantsDir = Join-Path $iacRoot 'constants'
  foreach ($psd1 in (Get-ChildItem -Path $constantsDir -Filter '*.psd1' -File)) {
    $data = Import-PowerShellDataFile -Path $psd1.FullName
    if ($data.ContainsKey($ConstantName)) { return [string]$data[$ConstantName] }
  }
  throw "Constant '$ConstantName' not found in any *.psd1 under '$constantsDir'."
}

$feedName = $null
$cmdlet = Get-Command -Name 'Get-ATAPIACConstant' -ErrorAction SilentlyContinue
if ($null -ne $cmdlet) {
  try {
    $feedName = Get-ATAPIACConstant -Name $constantName
  } catch {
    Write-Warning "$fn : Get-ATAPIACConstant threw for '$constantName'; trying direct file load. Error: $_"
    $feedName = $null
  }
}

if ([string]::IsNullOrWhiteSpace($feedName)) {
  $feedName = Resolve-ViaDirectLoad -ConstantName $constantName
}

if ([string]::IsNullOrWhiteSpace($feedName)) {
  Write-Error "$fn : Resolved feed name for constant '$constantName' is empty."
  exit 1
}

$resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputFile)) {
  $OutputFile
} else {
  Join-Path (Get-Location) $OutputFile
}

$feedName | Out-File -FilePath $resolvedOutput -Encoding utf8 -NoNewline
Write-Host "$fn : Resolved '$constantName' → '$feedName' (written to '$resolvedOutput')"
exit 0

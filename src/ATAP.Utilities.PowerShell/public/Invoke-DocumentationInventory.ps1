#############################################################################
#region Invoke-DocumentationInventory
<#
.SYNOPSIS
Runs the full ATAP Documentation Review inventory from a ReviewConfig.json file.

.DESCRIPTION
Driver for the DR-2.1 inventory run of the ATAP Documentation Review program
(_Planning\DocumentationReview\DocumentationReview-Plan.md). Reads ReviewConfig.json — the
HITL-edited source of truth for scope — validates the active roots, calls
Export-DocumentationInventory (DR-1.3) to write the inventory of record into the curated
directory with stable names, then copies both outputs into the evidence directory with
datestamped names (SC-0033).

Config schema (all output directories may be absolute or relative to the config file's folder):

  {
    "activeRoots":        [ { "repoName": "...", "rootPath": "C:\\..." }, ... ],
    "deferredRoots":      [ { "repoName": "...", "reason": "..." }, ... ],
    "includeExtensions":  [ ".md", ... ],        // optional; omit for function defaults
    "excludePathPattern": "regex",               // optional; omit for function defaults
    "outputs": { "curatedDirectory": "...", "evidenceDirectory": "..." }
  }

An active root whose rootPath does not exist is skipped with a warning (mirrors the
Render-AIAdapters trusted-directory behavior), so the config survives sprints where a
worktree is absent.

This file is dual-purpose: dot-sourced/imported it only defines the function; executed via
`pwsh -File` it runs immediately (&-proof guard).

.PARAMETER ConfigPath
Path to ReviewConfig.json. Mandatory — the config file, not this code, defines scope.

.INPUTS
None.

.OUTPUTS
The Export-DocumentationInventory summary object, extended with EvidenceCsvPath and
EvidenceJsonlPath.

.EXAMPLE
Invoke-DocumentationInventory -ConfigPath 'C:\...\_Planning-wt-26-...\DocumentationReview\ReviewConfig.json'

.EXAMPLE
pwsh -File .\Invoke-DocumentationInventory.ps1 -ConfigPath 'C:\...\DocumentationReview\ReviewConfig.json'
#>
Function Invoke-DocumentationInventory {
  #region FunctionParameters
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $ConfigPath
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Entering Function Invoke-DocumentationInventory in module ATAP.Utilities.Powershell' -Tag 'Trace'
    if (-not (Get-Command -Name 'Export-DocumentationInventory' -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot 'Export-DocumentationInventory.ps1')
    }
  }
  #endregion FunctionBeginBlock
  #region FunctionEndBlock
  ########################################
  END {
    $configDirectory = Split-Path -Path (Resolve-Path -LiteralPath $ConfigPath).ProviderPath -Parent
    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

    $resolveOutputDirectory = {
      param($candidate)
      if ([System.IO.Path]::IsPathRooted($candidate)) { $candidate }
      else { Join-Path $configDirectory $candidate }
    }
    $curatedDirectory = & $resolveOutputDirectory $config.outputs.curatedDirectory
    $evidenceDirectory = & $resolveOutputDirectory $config.outputs.evidenceDirectory

    $activeRoots = @()
    foreach ($entry in $config.activeRoots) {
      if (Test-Path -LiteralPath $entry.rootPath -PathType Container) {
        $activeRoots += [PSCustomObject]@{ RepoName = $entry.repoName; RootPath = $entry.rootPath }
      } else {
        Write-PSFMessage -Level Important -Message "Invoke-DocumentationInventory: active root '$($entry.repoName)' skipped — path not found: $($entry.rootPath)" -Tag 'DocumentationReview'
      }
    }
    if (-not $activeRoots) {
      throw "Invoke-DocumentationInventory: no active roots in $ConfigPath resolve to existing directories."
    }

    $exportArgs = @{ Root = $activeRoots; OutputDirectory = $curatedDirectory }
    if ($config.includeExtensions) { $exportArgs.IncludeExtension = [string[]]$config.includeExtensions }
    if ($config.excludePathPattern) { $exportArgs.ExcludePathPattern = [string]$config.excludePathPattern }
    $summary = Export-DocumentationInventory @exportArgs

    if (-not (Test-Path -LiteralPath $evidenceDirectory -PathType Container)) {
      New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $evidenceCsvPath = Join-Path $evidenceDirectory "DocumentationInventory-$stamp.csv"
    $evidenceJsonlPath = Join-Path $evidenceDirectory "DocumentationInventory-$stamp.jsonl"
    Copy-Item -LiteralPath $summary.CsvPath -Destination $evidenceCsvPath
    Copy-Item -LiteralPath $summary.JsonlPath -Destination $evidenceJsonlPath

    $summary |
      Add-Member -NotePropertyName EvidenceCsvPath -NotePropertyValue $evidenceCsvPath -PassThru |
      Add-Member -NotePropertyName EvidenceJsonlPath -NotePropertyValue $evidenceJsonlPath -PassThru
    Write-PSFMessage -Level Debug -Message 'Leaving Function Invoke-DocumentationInventory in module ATAP.Utilities.Powershell' -Tag 'Trace'
  }
  #endregion FunctionEndBlock
}
#endregion Invoke-DocumentationInventory

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  # This block fires ONLY under: pwsh -File <script>
  # Skipped on: dot-source (.), module import, call operator (&)
  Invoke-DocumentationInventory @args
}
#############################################################################

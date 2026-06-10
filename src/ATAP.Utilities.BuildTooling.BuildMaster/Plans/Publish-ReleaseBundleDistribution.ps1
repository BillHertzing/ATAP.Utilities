<#
.SYNOPSIS
  Publishes the production Release Bundle to Chocolatey and WinGet during
  the Distribution stage of ReleaseBundle-6Stage.otter.

.DESCRIPTION
  Eponymous entry-point script for the Distribution stage. Per
  ExplainerEliminationPlan_V1.md Section 0a D-06, Chocolatey and WinGet
  publication is deferred for Sprint 0007 — this runner therefore reads
  the immutable bundle-version marker captured by Experimental and calls
  Publish-ChocolateyRelease + Update-WinGetManifestSource. Those two
  BuildTooling cmdlets may remain future stubs until Stream N implements
  their full behavior; this script keeps the OtterScript surface tiny and
  centralizes any future credential resolution in PowerShell (SEC-T1 /
  BLOCKER-8).

  Designed to be invoked from ReleaseBundle-6Stage.otter via
  Exec FileName: pwsh, Arguments: -NoProfile -File.

.PARAMETER BuildToolingModulePath
  Path to the ATAP.Utilities.BuildTooling.PowerShell module manifest.

.PARAMETER SourcePath
  Working copy / repository root.

.PARAMETER ReleaseBundleBundleVersionFile
  Marker file containing the immutable bundle version.

.OUTPUTS
  None. Side effects: Publish-ChocolateyRelease and Update-WinGetManifestSource
  side effects (currently future stubs).

.EXAMPLE
  pwsh -NoProfile -File Publish-ReleaseBundleDistribution.ps1 `
    -BuildToolingModulePath C:\src\repo\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1 `
    -SourcePath C:\src\repo `
    -ReleaseBundleBundleVersionFile C:\src\repo\_generated\buildmaster\12345\releasebundle_bundle_version.tmp

.NOTES
  AI assisted using Powershell.instructions.md as guidelines

.LINK
  ReleaseBundle-6Stage.otter
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
  [string]$ReleaseBundleBundleVersionFile
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

function Publish-ReleaseBundleDistribution {
  <#
  .SYNOPSIS
    Eponymous worker that runs the Distribution-stage publish cmdlets.
  .OUTPUTS
    None.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory)][string]$BuildToolingModulePath,
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$ReleaseBundleBundleVersionFile
  )

  BEGIN {
    $fn = 'Publish-ReleaseBundleDistribution'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn"

    try {
      Import-Module $BuildToolingModulePath -Force
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to import BuildTooling module from '$BuildToolingModulePath'. Exception: $($_.Exception.Message)"
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "BuildTooling module import attempt complete."
    }
  }

  PROCESS {
    try {
      if (-not (Test-Path -LiteralPath $ReleaseBundleBundleVersionFile -PathType Leaf)) {
        throw "ReleaseBundle bundle-version marker '$ReleaseBundleBundleVersionFile' is missing. Run the Experimental stage first."
      }
      $version = (Get-Content -LiteralPath $ReleaseBundleBundleVersionFile -Raw).Trim()
      if ([string]::IsNullOrWhiteSpace($version)) {
        throw "ReleaseBundle bundle-version marker '$ReleaseBundleBundleVersionFile' is empty."
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Publishing release bundle version '$version' to Chocolatey and WinGet."

      if ($PSCmdlet.ShouldProcess("Chocolatey $version", 'Publish-ChocolateyRelease')) {
        try {
          Publish-ChocolateyRelease -BundleVersion $version
        }
        catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Publish-ChocolateyRelease failed for version '$version'. Exception: $($_.Exception.Message)"
          throw
        }
        finally {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Publish-ChocolateyRelease call complete."
        }
      }

      if ($PSCmdlet.ShouldProcess("WinGet $version", 'Update-WinGetManifestSource')) {
        try {
          Update-WinGetManifestSource -BundleVersion $version
        }
        catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Update-WinGetManifestSource failed for version '$version'. Exception: $($_.Exception.Message)"
          throw
        }
        finally {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Update-WinGetManifestSource call complete."
        }
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed in $fn. Exception: $($_.Exception.Message)"
      throw
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Finished $fn"
  }
}

Publish-ReleaseBundleDistribution `
  -BuildToolingModulePath $BuildToolingModulePath `
  -SourcePath $SourcePath `
  -ReleaseBundleBundleVersionFile $ReleaseBundleBundleVersionFile | Out-Null

<#
.SYNOPSIS
  Promotes a previously-built Release Bundle Universal Package between
  two ProGet releasebundle-* feeds for a single BuildMaster stage.

.DESCRIPTION
  Eponymous entry-point script for the post-Experimental Release-Bundle
  promote stages (Development, QA, Production). Reads the bundle name and
  bundle version from per-build marker files written by
  New-ReleaseBundleBuildMasterPackage.ps1, resolves the ProGet API key from
  the canonical ProGet BuildMaster SecretName and calls Promote-ProGetPackage
  to copy the immutable bundle bytes from the source feed to the
  destination feed.

  Designed to be invoked from ReleaseBundle-6Stage.otter via
  Exec FileName: pwsh, Arguments: -NoProfile -File. The API key never appears
  in command-line arguments or BuildMaster transcripts.

.PARAMETER BuildToolingModulePath
  Path to the ATAP.Utilities.BuildTooling.PowerShell module manifest or folder.

.PARAMETER SourcePath
  Working copy / repository root used as Promote-ProGetPackage WorkingDirectory.

.PARAMETER Stage
  BuildMaster stage being executed. One of Development, QA, Production.

.PARAMETER ReleaseBundleNameFile
  Path to the marker file containing the bundle name (written by Experimental).

.PARAMETER ReleaseBundleBundleVersionFile
  Path to the marker file containing the immutable bundle version.

.PARAMETER FromFeed
  Source ProGet feed (the previous tier's releasebundle-* feed).

.PARAMETER ToFeed
  Destination ProGet feed (the current tier's releasebundle-* feed).

.PARAMETER CeilingTier
  Promotion ceiling captured from version.json by the Initialize stage.

.PARAMETER ProGetUrl
  Base URL of the ProGet server hosting the releasebundle-* feeds.

.PARAMETER Reason
  Optional Promote-ProGetPackage reason text. Defaults to
  "Release Bundle <Stage> promotion".

.OUTPUTS
  None. Side effects: ProGet promote API call.

.EXAMPLE
  pwsh -NoProfile -File Promote-ReleaseBundleBuildMasterPackage.ps1 `
    -BuildToolingModulePath C:\src\repo\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1 `
    -SourcePath C:\src\repo `
    -Stage Development `
    -ReleaseBundleNameFile C:\src\repo\_generated\buildmaster\12345\releasebundle_name.tmp `
    -ReleaseBundleBundleVersionFile C:\src\repo\_generated\buildmaster\12345\releasebundle_bundle_version.tmp `
    -FromFeed releasebundle-experimental `
    -ToFeed releasebundle-development `
    -CeilingTier Production `
    -ProGetUrl https://utat022:50000

.NOTES
  AI assisted using Powershell.instructions.md as guidelines

.LINK
  New-ReleaseBundleBuildMasterPackage.ps1
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
  [ValidateSet('Development', 'Integration', 'QA', 'Production')]
  [string]$Stage,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ReleaseBundleNameFile,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ReleaseBundleBundleVersionFile,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$FromFeed,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ToFeed,

  [Parameter(Mandatory)]
  [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
  [string]$CeilingTier,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ProGetUrl,

  [ValidateNotNullOrEmpty()]
  [string]$ProGetApiKeySecretName = 'ProGet.BuildMaster.API.Key',

  [AllowEmptyString()]
  [string]$Reason = ''
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

function Promote-ReleaseBundleBuildMasterPackage {
  <#
  .SYNOPSIS
    Eponymous worker that promotes a release bundle between two ProGet feeds.
  .OUTPUTS
    None.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory)][string]$BuildToolingModulePath,
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$Stage,
    [Parameter(Mandatory)][string]$ReleaseBundleNameFile,
    [Parameter(Mandatory)][string]$ReleaseBundleBundleVersionFile,
    [Parameter(Mandatory)][string]$FromFeed,
    [Parameter(Mandatory)][string]$ToFeed,
    [Parameter(Mandatory)][string]$CeilingTier,
    [Parameter(Mandatory)][string]$ProGetUrl,
    [ValidateNotNullOrEmpty()][string]$ProGetApiKeySecretName = 'ProGet.BuildMaster.API.Key',
    [AllowEmptyString()][string]$Reason = ''
  )

  BEGIN {
    $fn = 'Promote-ReleaseBundleBuildMasterPackage'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn for Stage='$Stage' FromFeed='$FromFeed' ToFeed='$ToFeed'"

    try {
      Import-Module $BuildToolingModulePath -Force
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to import BuildTooling module from '$BuildToolingModulePath'. Exception: $($_.Exception.Message)"
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Module import attempt complete for '$BuildToolingModulePath'."
    }

    $global:ProGetBaseUrl = $ProGetUrl
  }

  PROCESS {
    try {
      if (-not (Test-Path -LiteralPath $ReleaseBundleNameFile -PathType Leaf)) {
        throw "ReleaseBundle name marker '$ReleaseBundleNameFile' is missing. Run the Experimental stage first."
      }
      if (-not (Test-Path -LiteralPath $ReleaseBundleBundleVersionFile -PathType Leaf)) {
        throw "ReleaseBundle bundle-version marker '$ReleaseBundleBundleVersionFile' is missing. Run the Experimental stage first."
      }

      $name = (Get-Content -LiteralPath $ReleaseBundleNameFile -Raw).Trim()
      $version = (Get-Content -LiteralPath $ReleaseBundleBundleVersionFile -Raw).Trim()
      if ([string]::IsNullOrWhiteSpace($name)) {
        throw "ReleaseBundle name marker '$ReleaseBundleNameFile' is empty."
      }
      if ([string]::IsNullOrWhiteSpace($version)) {
        throw "ReleaseBundle bundle-version marker '$ReleaseBundleBundleVersionFile' is empty."
      }

      $resolvedReason = if ([string]::IsNullOrWhiteSpace($Reason)) {
        "Release Bundle $Stage promotion"
      } else {
        $Reason
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Promoting release bundle '$name' version '$version' from '$FromFeed' to '$ToFeed' (CeilingTier='$CeilingTier')."

      if ($PSCmdlet.ShouldProcess("$name $version", "Promote-ProGetPackage $FromFeed -> $ToFeed")) {
        try {
          Promote-ProGetPackage `
            -Name $name `
            -Version $version `
            -FromFeed $FromFeed `
            -ToFeed $ToFeed `
            -Reason $resolvedReason `
            -ProGetApiKeySecretName $ProGetApiKeySecretName `
            -CeilingTier $CeilingTier | Out-Null
        }
        catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Promote-ProGetPackage failed for '$name' '$version' ($FromFeed -> $ToFeed). Exception: $($_.Exception.Message)"
          throw
        }
        finally {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Promote-ProGetPackage call complete."
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

Promote-ReleaseBundleBuildMasterPackage `
  -BuildToolingModulePath $BuildToolingModulePath `
  -SourcePath $SourcePath `
  -Stage $Stage `
  -ReleaseBundleNameFile $ReleaseBundleNameFile `
  -ReleaseBundleBundleVersionFile $ReleaseBundleBundleVersionFile `
  -FromFeed $FromFeed `
  -ToFeed $ToFeed `
  -CeilingTier $CeilingTier `
  -ProGetUrl $ProGetUrl `
  -ProGetApiKeySecretName $ProGetApiKeySecretName `
  -Reason $Reason | Out-Null

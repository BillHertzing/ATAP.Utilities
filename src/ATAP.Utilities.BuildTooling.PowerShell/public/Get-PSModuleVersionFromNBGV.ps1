#region Get-PSModuleVersionFromNBGV
<#
.SYNOPSIS
  Resolve a PowerShell module's NBGV-derived version and translate it into the
  `ModuleVersion` / `Prerelease` pair that `Update-ModuleManifest` accepts.
.DESCRIPTION
  Invokes `nbgv get-version --variable NuGetPackageVersion` in the module root
  and parses the resulting `Major.Minor.Patch[-Label.Height]` string into a
  `[PSCustomObject]` containing:

    - `ModuleVersion`   : a 3-part `[System.Version]` (the prerelease suffix
                          is stripped; e.g. `0.1.0-Alpha.6` becomes `0.1.0`).
    - `Prerelease`      : the prerelease label concatenated with the height,
                          containing only alphanumerics (no dots, no hyphens)
                          so that `Update-ModuleManifest -Prerelease ...` will
                          accept it. Empty string for stable (T5) builds.
    - `FullNuGetVersion`: the raw string returned by NBGV.

  This cmdlet is part of the 5-Tier PowerShell module build pipeline; see
  `src/ATAP.Utilities.BuildTooling.PowerShell/Documentation/5tier Implementation plan.md`
  section 3 for the authoritative mapping.
.PARAMETER ModuleRoot
  The absolute path to the module folder (the directory that owns the module's
  `version.json`). NBGV will be executed with this directory as its working
  directory.
.INPUTS
  None. This cmdlet does not accept pipeline input.
.OUTPUTS
  [PSCustomObject] with `ModuleVersion`, `Prerelease`, and `FullNuGetVersion`.
.EXAMPLE
  PS> Get-PSModuleVersionFromNBGV -ModuleRoot 'C:\repo\src\ATAP.Utilities.Foo.PowerShell'
  ModuleVersion Prerelease FullNuGetVersion
  ------------- ---------- ----------------
  0.1.0         Alpha6     0.1.0-Alpha.6
.EXAMPLE
  PS> $v = Get-PSModuleVersionFromNBGV -ModuleRoot $PSScriptRoot
  PS> Update-ModuleManifest -Path $manifest -ModuleVersion $v.ModuleVersion -Prerelease $v.Prerelease
.NOTES
  AI assisted using Powershell.instructions.md as guidelines
.LINK
  https://github.com/dotnet/Nerdbank.GitVersioning
#>
function Get-PSModuleVersionFromNBGV {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $ModuleRoot
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = $MyInvocation.MyCommand.ModuleName
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with ModuleRoot='$ModuleRoot'" -Tag 'Trace'

    if (-not (Test-Path -LiteralPath $ModuleRoot -PathType Container)) {
      $message = "ModuleRoot '$ModuleRoot' does not exist or is not a directory."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message -Tag 'NBGV'
      throw $message
    }
  }
  process {
    # Ensure nbgv is on PATH before invoking it
    $nbgvCommand = Get-Command -Name 'nbgv' -ErrorAction SilentlyContinue
    if (-not $nbgvCommand) {
      $message = "The 'nbgv' CLI was not found on PATH. Install it with: dotnet tool install -g nbgv"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message -Tag 'NBGV'
      throw $message
    }

    $fullNuGetVersion = $null
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Invoking nbgv get-version --variable NuGetPackageVersion in '$ModuleRoot'" -Tag 'NBGV'
      $pushed = $false
      try {
        Push-Location -LiteralPath $ModuleRoot
        $pushed = $true
        $rawOutput = & nbgv get-version --variable NuGetPackageVersion 2>&1
        $exit = $LASTEXITCODE
      } finally {
        if ($pushed) { Pop-Location }
      }

      if ($exit -ne 0) {
        $message = "nbgv get-version failed with exit code ${exit}: $rawOutput"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message -Tag 'NBGV'
        throw $message
      }

      $fullNuGetVersion = ([string]$rawOutput).Trim()
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "nbgv returned '$fullNuGetVersion'" -Tag 'NBGV'
    } catch {
      $message = "Failed to retrieve NBGV version for '$ModuleRoot': $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message -Tag 'NBGV'
      throw
    }

    if ([string]::IsNullOrWhiteSpace($fullNuGetVersion)) {
      $message = "nbgv returned an empty version string for '$ModuleRoot'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message -Tag 'NBGV'
      throw $message
    }

    # Parse M.m.p and optional -Label.N, with optional trailing .g{hash} suffix produced by NBGV at height 0
    $pattern = '^(?<Major>\d+)\.(?<Minor>\d+)\.(?<Patch>\d+)(?:-(?<Label>[A-Za-z][A-Za-z0-9]*)(?:\.(?<Height>\d+))?(?:\.g[0-9a-f]+)?)?$'
    if ($fullNuGetVersion -notmatch $pattern) {
      $message = "nbgv output '$fullNuGetVersion' does not match the expected 'Major.Minor.Patch[-Label[.Height]]' pattern."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message -Tag 'NBGV'
      throw $message
    }

    $major = [int]$Matches['Major']
    $minor = [int]$Matches['Minor']
    $patch = [int]$Matches['Patch']
    $label = $Matches['Label']
    $height = $Matches['Height']

    $moduleVersion = [System.Version]::new($major, $minor, $patch)

    if ([string]::IsNullOrEmpty($label)) {
      # Stable / T5 Production: no prerelease segment
      $prerelease = ''
    } else {
      # Prerelease must be alphanumeric only (no dots, no hyphens)
      $prerelease = '{0}{1}' -f $label, $height
      if ($prerelease -notmatch '^[A-Za-z0-9]+$') {
        $message = "Computed Prerelease '$prerelease' does not match the required alphanumeric pattern for Update-ModuleManifest."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message -Tag 'NBGV'
        throw $message
      }
    }

    $result = [PSCustomObject]@{
      ModuleVersion    = $moduleVersion
      Prerelease       = $prerelease
      FullNuGetVersion = $fullNuGetVersion
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Resolved ModuleVersion=$($result.ModuleVersion), Prerelease='$($result.Prerelease)', FullNuGetVersion='$($result.FullNuGetVersion)'" -Tag 'NBGV'
    return $result
  }
  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}
#endregion Get-PSModuleVersionFromNBGV

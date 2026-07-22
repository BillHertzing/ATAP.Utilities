function New-BuildToolingChildModule {
  <#
  .SYNOPSIS
    Creates one empty BuildTooling child-module scaffold from approved family metadata.
  .DESCRIPTION
    Renders an importable child module under a caller-provided source root. The function
    reads ModuleFamily.psd1 but never edits another repository or the family metadata.
  .PARAMETER ModuleName
    Exact approved child-module name from ModuleFamily.psd1.
  .PARAMETER SourceRoot
    Directory that will contain the generated module folder.
  .PARAMETER ModuleFamilyPath
    Path to the checked-in ModuleFamily.psd1 file.
  .OUTPUTS
    PSCustomObject describing the generated module and proposed external map text.
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)]
    [ValidatePattern('^ATAP\.Utilities\.BuildTooling\.[A-Za-z]+\.PowerShell$')]
    [string] $ModuleName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $SourceRoot,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ModuleFamilyPath = (Join-Path (Get-RepositoryRoot) 'ModuleFamily.psd1')
  )

  begin {
    $fn = 'New-BuildToolingChildModule'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function'
  }

  process {
    try {
      if (-not (Test-Path -LiteralPath $ModuleFamilyPath -PathType Leaf)) {
        throw "Module family metadata was not found: '$ModuleFamilyPath'."
      }
      $family = Import-PowerShellDataFile -LiteralPath $ModuleFamilyPath
      $member = @($family.Members | Where-Object { $_.Name -eq $ModuleName })
      if ($member.Count -ne 1) {
        throw "ModuleName '$ModuleName' is not exactly one approved child member."
      }
      if ($ModuleName -eq $family.BootstrapModule) {
        throw "'$ModuleName' is the bootstrap parent, not a child scaffold target."
      }
      $templateRoot = Join-Path (Split-Path -Parent $ModuleFamilyPath) 'src\_Templates\BuildToolingChildModule'
      if (-not (Test-Path -LiteralPath $templateRoot -PathType Container)) {
        throw "Child module template was not found: '$templateRoot'."
      }
      $targetRoot = Join-Path $SourceRoot $ModuleName
      if (Test-Path -LiteralPath $targetRoot) {
        throw "Refusing to overwrite existing child module '$targetRoot'."
      }
      if (-not $PSCmdlet.ShouldProcess($targetRoot, "Create empty child module '$ModuleName'")) {
        return
      }

      Copy-Item -LiteralPath $templateRoot -Destination $targetRoot -Recurse -Force -ErrorAction Stop
      $requiredModules = @(
        foreach ($dependency in @($member[0].Dependencies)) {
          @{ ModuleName = $dependency; ModuleVersion = $member[0].MinimumVersions[$dependency] }
        }
      )
      $manifestPath = Join-Path $targetRoot "$ModuleName.psd1"
      New-ModuleManifest -Path $manifestPath -RootModule "$ModuleName.psm1" -ModuleVersion '0.1.0' `
        -Guid ([guid]$member[0].Guid) -Author 'Bill Hertzing for ATAPUtilities.org' `
        -CompanyName 'ATAPUtilities.org' -Description "BuildTooling $ModuleName child module." `
        -PowerShellVersion ([version]$family.Defaults.PowerShellVersion) `
        -CompatiblePSEditions @($family.Defaults.CompatiblePSEditions) `
        -RequiredModules $requiredModules -FunctionsToExport @() -CmdletsToExport @() `
        -VariablesToExport @() -AliasesToExport @() -ErrorAction Stop

      $loaderPath = Join-Path $targetRoot "$ModuleName.psm1"
      $loader = @'
$publicFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$privateFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
foreach ($import in @($publicFunctions + $privateFunctions)) {
  . $import.FullName
}
'@
      Set-Content -LiteralPath $loaderPath -Value $loader -Encoding utf8BOM

      [pscustomobject]@{
        ModuleName = $ModuleName
        ModuleRoot = $targetRoot
        ManifestPath = $manifestPath
        BuildMasterMapEntry = "'$ModuleName' = '$($family.Defaults.BuildMasterApplication)'"
        SolutionDocumentationIndexPointer = "module: $ModuleName"
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $_.Exception.Message
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function'
  }
}

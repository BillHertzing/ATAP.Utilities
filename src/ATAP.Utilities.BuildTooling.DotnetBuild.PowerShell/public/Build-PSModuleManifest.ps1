<#
.SYNOPSIS
  Copies a source PowerShell module manifest (.psd1) to an output path and updates it
  with version, prerelease, exported functions, aliases, assemblies, formats, and DSC
  resources.
.DESCRIPTION
  Copies $SourceManifestPath to $OutputManifestPath (creating the parent directory if
  needed), builds a splatted hashtable of Update-ModuleManifest parameters honoring
  only the non-empty list params and $Prerelease when non-empty, invokes
  Update-ModuleManifest, clears any source prerelease when $Prerelease is empty,
  and validates the result via Test-ModuleManifest. Throws clearly if validation
  fails.
.PARAMETER SourceManifestPath
  The absolute path to the source .psd1 manifest that should be used as the template.
.PARAMETER OutputManifestPath
  The absolute path where the generated manifest will be written.
.PARAMETER ModuleVersion
  The three-part System.Version to stamp into the manifest.
.PARAMETER Prerelease
  Optional prerelease suffix (e.g. 'Alpha6'). When empty, the generated manifest
  is made stable by removing any copied PrivateData.PSData.Prerelease assignment.
.PARAMETER PublicFunctions
  Names of functions to export (FunctionsToExport). Only passed when non-empty.
.PARAMETER Aliases
  Names of aliases to export (AliasesToExport). Only passed when non-empty.
.PARAMETER RequiredAssemblies
  Required assembly paths. Only passed when non-empty.
.PARAMETER FormatFiles
  FormatsToProcess file paths. Only passed when non-empty.
.PARAMETER DscResources
  DscResourcesToExport names. Only passed when non-empty.
.OUTPUTS
  System.IO.FileInfo
  A FileInfo handle to the generated manifest file.
.EXAMPLE
  Build-PSModuleManifest -SourceManifestPath 'C:/src/Foo.psd1' -OutputManifestPath 'C:/out/Foo.psd1' -ModuleVersion ([version]'1.2.3')
.EXAMPLE
  Build-PSModuleManifest -SourceManifestPath 'C:/src/Foo.psd1' -OutputManifestPath 'C:/out/Foo.psd1' -ModuleVersion ([version]'1.2.3') -Prerelease 'Alpha6' -PublicFunctions @('Get-Foo','Set-Foo')
.NOTES
  AI assisted using Powershell.instructions.md as guidelines
.LINK
  https://github.com/whertzing/ATAP.Utilities
#>
function Build-PSModuleManifest {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $SourceManifestPath,

    [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $OutputManifestPath,

    [Parameter(Mandatory = $true, Position = 2, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNull()]
    [System.Version] $ModuleVersion,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string] $Prerelease = '',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string[]] $PublicFunctions = @(),

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string] $ModuleRoot = '',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string] $ModuleFamilyPath = '',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string[]] $Aliases = @(),

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string[]] $RequiredAssemblies = @(),

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string[]] $FormatFiles = @(),

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string[]] $DscResources = @()
  )

  begin {
    $fn = 'Build-PSModuleManifest'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function'
  }

  process {
    if (-not $PSCmdlet.ShouldProcess($OutputManifestPath, "Build module manifest from '$SourceManifestPath'")) {
      return
    }

    try {
      if (-not (Test-Path -Path $SourceManifestPath -PathType Leaf)) {
        $message = "SourceManifestPath '$SourceManifestPath' does not exist"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message
        throw $message
      }

      # Ensure parent directory of output exists
      $outputParent = Split-Path -Path $OutputManifestPath -Parent
      if ($outputParent -and -not (Test-Path -Path $outputParent -PathType Container)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Creating parent directory '$outputParent'"
        New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
      }

      $sourceManifest = Import-PowerShellDataFile -LiteralPath $SourceManifestPath -ErrorAction Stop
      $effectiveModuleRoot = if ([string]::IsNullOrWhiteSpace($ModuleRoot)) {
        Split-Path -Parent $SourceManifestPath
      } else {
        $ModuleRoot
      }
      $manifestBaseName = [System.IO.Path]::GetFileNameWithoutExtension($SourceManifestPath)
      $moduleFolderName = Split-Path -Leaf $effectiveModuleRoot
      if ($PSBoundParameters.ContainsKey('ModuleRoot') -and $moduleFolderName -ne $manifestBaseName) {
        throw "Module folder '$moduleFolderName' must match manifest BaseName '$manifestBaseName'."
      }
      if ($PSBoundParameters.ContainsKey('PublicFunctions') -and $PublicFunctions.Count -gt 0) {
        $resolvedPublicFunctions = @($PublicFunctions | Sort-Object -Unique)
      } else {
        $publicDirectory = Join-Path $effectiveModuleRoot 'public'
        $resolvedPublicFunctions = if (Test-Path -LiteralPath $publicDirectory -PathType Container) {
          @(Get-ChildItem -LiteralPath $publicDirectory -Filter '*.ps1' -File |
              Select-Object -ExpandProperty BaseName | Sort-Object -Unique)
        } else {
          @()
        }
      }
      $familyRequiredModules = @()
      if (-not [string]::IsNullOrWhiteSpace($ModuleFamilyPath)) {
        if (-not (Test-Path -LiteralPath $ModuleFamilyPath -PathType Leaf)) {
          throw "ModuleFamilyPath '$ModuleFamilyPath' does not exist."
        }
        $family = Import-PowerShellDataFile -LiteralPath $ModuleFamilyPath -ErrorAction Stop
        $member = @($family.Members | Where-Object { $_.Name -eq $manifestBaseName })
        if ($member.Count -ne 1) {
          throw "Manifest '$manifestBaseName' is not exactly one ModuleFamily member."
        }
        $familyRequiredModules = @(
          foreach ($dependency in @($member[0].Dependencies)) {
            @{ ModuleName = $dependency; ModuleVersion = $member[0].MinimumVersions[$dependency] }
          }
        )
      }
      $sourceRequiredModules = if ($sourceManifest.ContainsKey('RequiredModules')) {
        @($sourceManifest.RequiredModules | Where-Object { $_ })
      } else {
        @()
      }
      $params = @{
        Path          = $OutputManifestPath
        ModuleVersion = $ModuleVersion
      }
      foreach ($manifestField in @(
          @{ Key = 'RootModule'; Value = $sourceManifest.RootModule },
          @{ Key = 'Guid'; Value = if ($sourceManifest.GUID) { [guid]$sourceManifest.GUID } else { $null } },
          @{ Key = 'Author'; Value = $sourceManifest.Author },
          @{ Key = 'CompanyName'; Value = $sourceManifest.CompanyName },
          @{ Key = 'Copyright'; Value = $sourceManifest.Copyright },
          @{ Key = 'Description'; Value = $sourceManifest.Description },
          @{ Key = 'PowerShellVersion'; Value = if ($sourceManifest.PowerShellVersion) { [version]$sourceManifest.PowerShellVersion } else { $null } },
          @{ Key = 'CompatiblePSEditions'; Value = @($sourceManifest.CompatiblePSEditions | Where-Object { $_ }) },
          @{ Key = 'RequiredModules'; Value = if ($familyRequiredModules.Count -gt 0) { $familyRequiredModules } else { $sourceRequiredModules } },
          @{ Key = 'CmdletsToExport'; Value = @($sourceManifest.CmdletsToExport | Where-Object { $_ }) },
          @{ Key = 'VariablesToExport'; Value = @($sourceManifest.VariablesToExport | Where-Object { $_ }) }
        )) {
        if ($null -eq $manifestField.Value) {
          continue
        }
        if ($manifestField.Value -is [array] -and $manifestField.Value.Count -eq 0) {
          continue
        }
        if ($manifestField.Value -is [string] -and [string]::IsNullOrWhiteSpace($manifestField.Value)) {
          continue
        }
        $params[$manifestField.Key] = $manifestField.Value
      }
      if (-not [string]::IsNullOrWhiteSpace($Prerelease)) {
        $params['Prerelease'] = $Prerelease
      }
      $params['FunctionsToExport'] = $resolvedPublicFunctions
      if ($Aliases -and $Aliases.Count -gt 0) {
        $params['AliasesToExport'] = $Aliases
      }
      if ($RequiredAssemblies -and $RequiredAssemblies.Count -gt 0) {
        $params['RequiredAssemblies'] = $RequiredAssemblies
      }
      if ($FormatFiles -and $FormatFiles.Count -gt 0) {
        $params['FormatsToProcess'] = $FormatFiles
      }
      if ($DscResources -and $DscResources.Count -gt 0) {
        $params['DscResourcesToExport'] = $DscResources
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling New-ModuleManifest on '$OutputManifestPath' with $($params.Keys.Count) parameter(s)"
      New-ModuleManifest @params
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from New-ModuleManifest for '$OutputManifestPath'"

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Validating manifest via Test-ModuleManifest '$OutputManifestPath'"
      $validationError = $null
      $null = Test-ModuleManifest -Path $OutputManifestPath -ErrorAction SilentlyContinue -ErrorVariable validationError
      if ($validationError) {
        $message = "Generated manifest '$OutputManifestPath' failed Test-ModuleManifest validation: $($validationError[0].Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message
        throw $message
      }

      return (Get-Item -LiteralPath $OutputManifestPath)
    } catch {
      $errorMessage = "Failed to build module manifest '$OutputManifestPath' from '$SourceManifestPath'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving PROCESS block'
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function'
  }
}

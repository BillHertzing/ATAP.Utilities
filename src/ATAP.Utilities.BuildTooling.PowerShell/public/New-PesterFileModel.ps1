<#
.SYNOPSIS
Creates a new Pester file model hashtable representing a structured .Tests.ps1 file.

.DESCRIPTION
Builds a structured hashtable (the PesterFile model) that describes every composable
element of a Pester v5 test file: Param block, BeforeDiscovery, one or more Describe
blocks, and their nested Context / It / setup-teardown blocks.

The returned model is consumed by New-PesterTestFile to synthesize the actual
.Tests.ps1 source text.

.PARAMETER Name
Base name of the module or script under test (without extension). Used to derive the
default test file name.

.PARAMETER Path
Target directory path for the generated .Tests.ps1 file. Defaults to the current
working directory.

.PARAMETER Extension
File extension for the generated test file. Defaults to '.Tests.ps1'.

.PARAMETER Describes
Array of Describe-block hashtables, each created by New-PesterDescribeBlock.
At least one Describe block is required.

.PARAMETER ParamBlock
Optional multiline string for the top-level param() block, rendered before
BeforeDiscovery.

.PARAMETER BeforeDiscovery
Optional multiline string for a top-level BeforeDiscovery block.

.OUTPUTS
Hashtable - A PesterFile model with keys: Name, Path, Extension, ParamBlock,
BeforeDiscovery, Describes.

.EXAMPLE
$model = New-PesterFileModel -Name 'Get-RepositoryRoot' `
    -Path 'src/ATAP.Utilities.BuildTooling.PowerShell/tests/Unit' `
    -Describes @(New-PesterDescribeBlock -Name 'Get-RepositoryRoot')

Creates a minimal PesterFile model for the Get-RepositoryRoot function tests.

.NOTES
Philote ID: "a1b2c3d4-e5f6-7890-ab12-cd34ef567890"
AI assisted using Powershell.instructions.md as guidelines
#>
function New-PesterFileModel {
  [CmdletBinding()]
  [OutputType([hashtable])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory = $false)]
    [string]$Path = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [string]$Extension = '.Tests.ps1',

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [hashtable[]]$Describes,

    [Parameter(Mandatory = $false)]
    [string]$ParamBlock,

    [Parameter(Mandatory = $false)]
    [string]$BeforeDiscovery
  )

  begin {
    $fn = 'New-PesterFileModel'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering New-PesterFileModel'
    # Load required helper functions
    try {
      if (-not (Get-Command -Name 'Get-RepositoryRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-RepositoryRoot.ps1'
      }
      $repositoryRoot = Get-RepositoryRoot

      if (-not (Get-Command -Name 'Get-PVal' -CommandType Function -ErrorAction SilentlyContinue)) {
        . (Join-Path $repositoryRoot 'src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1')
      }
    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
    # Snippet: Check and populate simple parameter
    $Name = Get-PVal -ParameterName 'Name' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Name' -DefaultValue $Name
    # Snippet: Check and populate simple parameter
    $Path = Get-PVal -ParameterName 'Path' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Path' -DefaultValue $Path
    # Snippet: Check and populate simple parameter
    $Extension = Get-PVal -ParameterName 'Extension' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Extension' -DefaultValue $Extension
    # Snippet: Check and populate simple parameter as Type
    $Describes = Get-PVal -ParameterName 'Describes' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Describes' -DefaultValue $Describes -AsType ([hashtable[]])
    # Snippet: Check and populate simple parameter
    $ParamBlock = Get-PVal -ParameterName 'ParamBlock' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ParamBlock' -DefaultValue $ParamBlock
    # Snippet: Check and populate simple parameter
    $BeforeDiscovery = Get-PVal -ParameterName 'BeforeDiscovery' -originalPSBoundParameters $PSBoundParameters -dottedPath 'BeforeDiscovery' -DefaultValue $BeforeDiscovery
  }

  process {
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Creating PesterFile model for: $Name"
      foreach ($describe in $Describes) {
        if (-not $describe.ContainsKey('Name') -or [string]::IsNullOrWhiteSpace($describe['Name'])) {
          throw "Each Describe block must have a non-empty 'Name' key."
        }
      }

      $model = @{
        Name            = $Name
        Path            = $Path
        Extension       = $Extension
        ParamBlock      = $ParamBlock
        BeforeDiscovery = $BeforeDiscovery
        Describes       = $Describes
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "PesterFile model created with $($Describes.Count) Describe block(s)."
      return $model
    }
    catch {
      $errorMessage = "Failed to create PesterFile model '$Name'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  end {}
}

<#
.SYNOPSIS
Creates a Describe-block hashtable for use in a PesterFile model.

.DESCRIPTION
Builds a hashtable representing a single Pester Describe block with its Name,
Tags, optional setup/teardown bodies, nested Context blocks, and direct It blocks.
The result is intended to be passed as an element of the -Describes parameter
of New-PesterFileModel.

.PARAMETER Name
Required. Human-readable label for the Describe block (passed as the first
positional argument to Pester's Describe keyword).

.PARAMETER Tags
Optional array of tag strings applied to this Describe block via -Tag.

.PARAMETER BeforeAll
Optional string body of a BeforeAll block inside this Describe.

.PARAMETER BeforeEach
Optional string body of a BeforeEach block inside this Describe.

.PARAMETER AfterEach
Optional string body of an AfterEach block inside this Describe.

.PARAMETER AfterAll
Optional string body of an AfterAll block inside this Describe.

.PARAMETER Contexts
Optional array of Context-block hashtables created by New-PesterContextBlock.

.PARAMETER Its
Optional array of It-block hashtables created by New-PesterItBlock for direct
It blocks inside this Describe (not inside a Context).

.OUTPUTS
Hashtable - A Describe-block model with keys: Name, Tags, BeforeAll, BeforeEach,
AfterEach, AfterAll, Contexts, Its.

.EXAMPLE
$describe = New-PesterDescribeBlock -Name 'Get-RepositoryRoot' `
    -Tags @('Unit') `
    -BeforeAll ". Join-Path `$PSScriptRoot '..', '..', 'public', 'Get-RepositoryRoot.ps1'" `
    -Its @(New-PesterItBlock -Name 'returns the repository root path')

.NOTES
Philote ID: "b2c3d4e5-f6a7-8901-bc23-de45f6789012"
AI assisted using Powershell.instructions.md as guidelines
#>
function New-PesterDescribeBlock {
  [CmdletBinding()]
  [OutputType([hashtable])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory = $false)]
    [string[]]$Tags = @(),

    [Parameter(Mandatory = $false)]
    [string]$BeforeAll,

    [Parameter(Mandatory = $false)]
    [string]$BeforeEach,

    [Parameter(Mandatory = $false)]
    [string]$AfterEach,

    [Parameter(Mandatory = $false)]
    [string]$AfterAll,

    [Parameter(Mandatory = $false)]
    [hashtable[]]$Contexts = @(),

    [Parameter(Mandatory = $false)]
    [hashtable[]]$Its = @()
  )

  begin {
    $fn = 'New-PesterDescribeBlock'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering New-PesterDescribeBlock'
    # Load required helper functions
    try {
      $getPValCommand = Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue
      if (-not $getPValCommand -or -not $getPValCommand.Parameters.ContainsKey('ParameterName')) {
        $helperCandidates = @()
        if ($PSScriptRoot) {
          $helperCandidates += Join-Path -Path $PSScriptRoot -ChildPath 'Get-ParameterValueFromNeoConfigurationRoot.ps1'
          $helperCandidates += [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..\..\ATAP.Utilities.PowerShell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'))
          $helperCandidates += [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..\..\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'))
        }
        $helperCandidates += Join-Path -Path (Get-Location).Path -ChildPath 'src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
        $helperCandidates += 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
        $helperPath = $helperCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
        if (-not $helperPath) {
          throw "Could not locate Get-ParameterValueFromNeoConfigurationRoot.ps1. Checked: $($helperCandidates -join ', ')"
        }
        . $helperPath
      }
      Set-Alias -Name Get-PVal -Value Get-ParameterValueFromNeoConfigurationRoot -Scope Local -Force
    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
    # Snippet: Check and populate simple parameter
    $Name = Get-PVal -ParameterName 'Name' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Name' -DefaultValue $Name
    # Snippet: Check and populate simple parameter as Type
    $Tags = Get-PVal -ParameterName 'Tags' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Tags' -DefaultValue $Tags -AsType ([string[]])
    # Snippet: Check and populate simple parameter
    $BeforeAll = Get-PVal -ParameterName 'BeforeAll' -originalPSBoundParameters $PSBoundParameters -dottedPath 'BeforeAll' -DefaultValue $BeforeAll
    # Snippet: Check and populate simple parameter
    $BeforeEach = Get-PVal -ParameterName 'BeforeEach' -originalPSBoundParameters $PSBoundParameters -dottedPath 'BeforeEach' -DefaultValue $BeforeEach
    # Snippet: Check and populate simple parameter
    $AfterEach = Get-PVal -ParameterName 'AfterEach' -originalPSBoundParameters $PSBoundParameters -dottedPath 'AfterEach' -DefaultValue $AfterEach
    # Snippet: Check and populate simple parameter
    $AfterAll = Get-PVal -ParameterName 'AfterAll' -originalPSBoundParameters $PSBoundParameters -dottedPath 'AfterAll' -DefaultValue $AfterAll
    # Snippet: Check and populate simple parameter as Type
    $Contexts = Get-PVal -ParameterName 'Contexts' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Contexts' -DefaultValue $Contexts -AsType ([hashtable[]])
    # Snippet: Check and populate simple parameter as Type
    $Its = Get-PVal -ParameterName 'Its' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Its' -DefaultValue $Its -AsType ([hashtable[]])
  }

  process {
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Creating Describe block: $Name"
      return @{
        Name       = $Name
        Tags       = $Tags
        BeforeAll  = $BeforeAll
        BeforeEach = $BeforeEach
        AfterEach  = $AfterEach
        AfterAll   = $AfterAll
        Contexts   = $Contexts
        Its        = $Its
      }
    }
    catch {
      $errorMessage = "Failed to create Describe block '$Name'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  end {}
}

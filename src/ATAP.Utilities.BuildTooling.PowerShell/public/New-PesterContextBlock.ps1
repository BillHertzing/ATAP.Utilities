<#
.SYNOPSIS
Creates a Context-block hashtable for use inside a Describe-block model.

.DESCRIPTION
Builds a hashtable representing a single Pester Context block with its Name,
Tags, optional ForEach data, setup/teardown bodies, and nested It blocks.
The result is intended to be passed as an element of the -Contexts parameter
of New-PesterDescribeBlock.

.PARAMETER Name
Required. Human-readable label for the Context block.

.PARAMETER Tags
Optional array of tag strings applied to this Context block via -Tag.

.PARAMETER ForEach
Optional string expression used for -ForEach data-driven test iteration
(e.g., '@($testCases)' or '$testData').

.PARAMETER BeforeAll
Optional string body of a BeforeAll block inside this Context.

.PARAMETER BeforeEach
Optional string body of a BeforeEach block inside this Context.

.PARAMETER AfterEach
Optional string body of an AfterEach block inside this Context.

.PARAMETER AfterAll
Optional string body of an AfterAll block inside this Context.

.PARAMETER Its
Optional array of It-block hashtables created by New-PesterItBlock.

.OUTPUTS
Hashtable - A Context-block model with keys: Name, Tags, ForEach, BeforeAll,
BeforeEach, AfterEach, AfterAll, Its.

.EXAMPLE
$context = New-PesterContextBlock -Name 'When the path exists' `
    -BeforeAll '$script:result = Get-RepositoryRoot' `
    -Its @(New-PesterItBlock -Name 'returns a non-null result' `
           -Body '$script:result | Should -Not -BeNullOrEmpty')

.NOTES
Philote ID: "c3d4e5f6-a7b8-9012-cd34-ef5678901234"
AI assisted using Powershell.instructions.md as guidelines
#>
function New-PesterContextBlock {
  [CmdletBinding()]
  [OutputType([hashtable])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory = $false)]
    [string[]]$Tags = @(),

    [Parameter(Mandatory = $false)]
    [string]$ForEach,

    [Parameter(Mandatory = $false)]
    [string]$BeforeAll,

    [Parameter(Mandatory = $false)]
    [string]$BeforeEach,

    [Parameter(Mandatory = $false)]
    [string]$AfterEach,

    [Parameter(Mandatory = $false)]
    [string]$AfterAll,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [hashtable[]]$Its
  )

  begin {
    $fn = 'New-PesterContextBlock'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering New-PesterContextBlock'
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
    # Snippet: Check and populate simple parameter as Type
    $Tags = Get-PVal -ParameterName 'Tags' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Tags' -DefaultValue $Tags -AsType ([string[]])
    # Snippet: Check and populate simple parameter
    $ForEach = Get-PVal -ParameterName 'ForEach' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ForEach' -DefaultValue $ForEach
    # Snippet: Check and populate simple parameter
    $BeforeAll = Get-PVal -ParameterName 'BeforeAll' -originalPSBoundParameters $PSBoundParameters -dottedPath 'BeforeAll' -DefaultValue $BeforeAll
    # Snippet: Check and populate simple parameter
    $BeforeEach = Get-PVal -ParameterName 'BeforeEach' -originalPSBoundParameters $PSBoundParameters -dottedPath 'BeforeEach' -DefaultValue $BeforeEach
    # Snippet: Check and populate simple parameter
    $AfterEach = Get-PVal -ParameterName 'AfterEach' -originalPSBoundParameters $PSBoundParameters -dottedPath 'AfterEach' -DefaultValue $AfterEach
    # Snippet: Check and populate simple parameter
    $AfterAll = Get-PVal -ParameterName 'AfterAll' -originalPSBoundParameters $PSBoundParameters -dottedPath 'AfterAll' -DefaultValue $AfterAll
    # Snippet: Check and populate simple parameter as Type
    $Its = Get-PVal -ParameterName 'Its' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Its' -DefaultValue $Its -AsType ([hashtable[]])
  }

  process {
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Creating Context block: $Name"
      return @{
        Name       = $Name
        Tags       = $Tags
        ForEach    = $ForEach
        BeforeAll  = $BeforeAll
        BeforeEach = $BeforeEach
        AfterEach  = $AfterEach
        AfterAll   = $AfterAll
        Its        = $Its
      }
    }
    catch {
      $errorMessage = "Failed to create Context block '$Name'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  end {}
}

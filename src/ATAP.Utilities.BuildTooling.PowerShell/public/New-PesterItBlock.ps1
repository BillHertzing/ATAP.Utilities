<#
.SYNOPSIS
Creates an It-block hashtable for use inside a Describe or Context block model.

.DESCRIPTION
Builds a hashtable representing a single Pester It block with its Name, Tags,
optional ForEach / TestCases data, and an assertion body. The result is intended
to be passed as an element of the -Its parameter of New-PesterDescribeBlock or
New-PesterContextBlock.

.PARAMETER Name
Required. Human-readable label for the It block, following the convention
'FunctionName_StateUnderTest_ExpectedBehavior'.

.PARAMETER Tags
Optional array of tag strings applied to this It block via -Tag.

.PARAMETER TestCases
Optional string expression for the -TestCases parameter used in Pester v4 style
parameterized tests (e.g., '@(@{Value=1},@{Value=2})').

.PARAMETER ForEach
Optional string expression for the -ForEach parameter used in Pester v5 style
data-driven tests. Takes precedence over TestCases in rendered output.

.PARAMETER Body
Required. The script block body text (without surrounding braces). Must contain
at least one Should assertion clause.

.OUTPUTS
Hashtable - An It-block model with keys: Name, Tags, TestCases, ForEach, Body.

.EXAMPLE
$it = New-PesterItBlock `
    -Name 'Get-RepositoryRoot_ValidRepo_ReturnsRelativePath' `
    -Body '$result = Get-RepositoryRoot; $result | Should -Not -BeNullOrEmpty'

.EXAMPLE
$it = New-PesterItBlock `
    -Name 'Processes each input value' `
    -ForEach '$testCases' `
    -Body 'Process-Value -Input $_.Input | Should -Be $_.Expected'

.NOTES
Philote ID: "d4e5f6a7-b8c9-0123-de45-f6789012abcd"
AI assisted using Powershell.instructions.md as guidelines
#>
function New-PesterItBlock {
  [CmdletBinding()]
  [OutputType([hashtable])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory = $false)]
    [string[]]$Tags = @(),

    [Parameter(Mandatory = $false)]
    [string]$TestCases,

    [Parameter(Mandatory = $false)]
    [string]$ForEach,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Body
  )

  begin {
    $fn = 'New-PesterItBlock'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering New-PesterItBlock'
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
    $TestCases = Get-PVal -ParameterName 'TestCases' -originalPSBoundParameters $PSBoundParameters -dottedPath 'TestCases' -DefaultValue $TestCases
    # Snippet: Check and populate simple parameter
    $ForEach = Get-PVal -ParameterName 'ForEach' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ForEach' -DefaultValue $ForEach
    # Snippet: Check and populate simple parameter
    $Body = Get-PVal -ParameterName 'Body' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Body' -DefaultValue $Body
  }

  process {
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Creating It block: $Name"
      return @{
        Name      = $Name
        Tags      = $Tags
        TestCases = $TestCases
        ForEach   = $ForEach
        Body      = $Body
      }
    }
    catch {
      $errorMessage = "Failed to create It block '$Name'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  end {}
}

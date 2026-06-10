<#
.SYNOPSIS
Creates a PesterFile model conforming to the Basic Unit Test RuleSet.

.DESCRIPTION
Applies the Basic Unit Test RuleSet to generate a ready-to-use PesterFile model
for unit testing a single PowerShell function. The template creates:

  - A single Describe block named after the function under test.
  - A BeforeAll block that dot-sources the function's source file.
  - One Context block per logical scenario (supplied via -Scenarios), each with
    Its of its own.
  - An optional AfterAll cleanup block.

This satisfies the Pester Kind structural rules:
  1. All assertions inside It blocks.
  2. Dot-source in BeforeAll (Run phase).
  3. File name = FunctionName.Tests.ps1.

.PARAMETER FunctionName
Name of the function under test. Used as the Describe block name and to derive
the default test file name.

.PARAMETER SourceRelativePath
Relative path from the test file's directory to the source .ps1 file, used in
the BeforeAll dot-source statement (e.g., '..', '..', 'public', 'My-Function.ps1').
Provide as an array; Join-Path will be applied across elements.

.PARAMETER OutputPath
Directory path where the .Tests.ps1 file will be written. If omitted, the
model is returned without writing a file.

.PARAMETER Tags
Optional tags applied to the top-level Describe block.

.PARAMETER Scenarios
Array of scenario hashtables, each with keys:
  - Name   (string)  - Context block name
  - Its    (hashtable[]) - It blocks from New-PesterItBlock

.PARAMETER AfterAll
Optional string body for a top-level AfterAll cleanup block inside the Describe.

.PARAMETER Force
Overwrite an existing file when -OutputPath is specified.

.OUTPUTS
Hashtable - The generated PesterFile model.

.EXAMPLE
$scenarios = @(
  @{
    Name = 'When called with a valid Git repository'
    Its  = @(
      New-PesterItBlock -Name 'Get-RepositoryRoot_ValidRepo_ReturnsRelativePath' `
                        -Body '$result = Get-RepositoryRoot; $result | Should -Not -BeNullOrEmpty'
    )
  }
)

$model = New-PesterBasicUnitTestTemplate `
    -FunctionName 'Get-RepositoryRoot' `
    -SourceRelativePath '..', '..', 'public', 'Get-RepositoryRoot.ps1' `
    -OutputPath 'tests/Unit' `
    -Scenarios $scenarios `
    -Force

.NOTES
Philote ID: "f6a7b8c9-d0e1-2345-f678-901234567890"
RuleSet: 'PesterBasicUnitTest'
AI assisted using Powershell.instructions.md as guidelines
#>
function New-PesterBasicUnitTestTemplate {
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([hashtable])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$FunctionName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$SourceRelativePath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string[]]$Tags = @('Unit'),

    [Parameter(Mandatory = $false)]
    [hashtable[]]$Scenarios = @(),

    [Parameter(Mandatory = $false)]
    [string]$AfterAll,

    [Parameter(Mandatory = $false)]
    [switch]$Force
  )

  begin {
    $fn = 'New-PesterBasicUnitTestTemplate'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering New-PesterBasicUnitTestTemplate'
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
    $FunctionName = Get-PVal -ParameterName 'FunctionName' -originalPSBoundParameters $PSBoundParameters -dottedPath 'FunctionName' -DefaultValue $FunctionName
    # Snippet: Check and populate simple parameter as Type
    $SourceRelativePath = Get-PVal -ParameterName 'SourceRelativePath' -originalPSBoundParameters $PSBoundParameters -dottedPath 'SourceRelativePath' -DefaultValue $SourceRelativePath -AsType ([string[]])
    # Snippet: Check and populate simple parameter
    $OutputPath = Get-PVal -ParameterName 'OutputPath' -originalPSBoundParameters $PSBoundParameters -dottedPath 'OutputPath' -DefaultValue $OutputPath
    # Snippet: Check and populate simple parameter as Type
    $Tags = Get-PVal -ParameterName 'Tags' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Tags' -DefaultValue $Tags -AsType ([string[]])
    # Snippet: Check and populate simple parameter as Type
    $Scenarios = Get-PVal -ParameterName 'Scenarios' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Scenarios' -DefaultValue $Scenarios -AsType ([hashtable[]])
    # Snippet: Check and populate simple parameter
    $AfterAll = Get-PVal -ParameterName 'AfterAll' -originalPSBoundParameters $PSBoundParameters -dottedPath 'AfterAll' -DefaultValue $AfterAll
    # Snippet: Check and populate simple parameter as Type
    $Force = Get-PVal -ParameterName 'Force' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Force' -DefaultValue $Force -AsType ([switch])
  }

  process {
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Building Basic Unit Test template for: $FunctionName"
      # Build the dot-source BeforeAll statement
      $joinedPath = "Join-Path `$PSScriptRoot $(($SourceRelativePath | ForEach-Object { "'$_'" }) -join ', ')"
      $beforeAllBody = ". $joinedPath"

      # Build Context blocks from scenarios
      $contexts = @()
      foreach ($scenario in $Scenarios) {
        if (-not $scenario.ContainsKey('Name') -or -not $scenario.ContainsKey('Its')) {
          throw "Each Scenario must have 'Name' and 'Its' keys."
        }
        $contexts += New-PesterContextBlock `
          -Name $scenario['Name'] `
          -Its  $scenario['Its']
      }

      $describeParams = @{
        Name      = $FunctionName
        Tags      = $Tags
        BeforeAll = $beforeAllBody
        Contexts  = $contexts
        Its       = @()
      }
      if (-not [string]::IsNullOrWhiteSpace($AfterAll)) {
        $describeParams['AfterAll'] = $AfterAll
      }

      $describe = New-PesterDescribeBlock @describeParams

      $modelParams = @{
        Name      = $FunctionName
        Describes = @($describe)
      }
      if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $modelParams['Path'] = $OutputPath
      }

      $model = New-PesterFileModel @modelParams

      if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $forceSwitch = if ($Force) { @{ Force = $true } } else { @{} }
        $null = New-PesterTestFile -Model $model -OutputPath $OutputPath @forceSwitch
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Basic Unit Test template built for: $FunctionName"
      return $model
    }
    catch {
      $errorMessage = "Failed to build Basic Unit Test template for '$FunctionName'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  end {}
}

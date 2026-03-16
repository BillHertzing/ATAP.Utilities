<#
.SYNOPSIS
Creates a PesterFile model conforming to the Data-Driven Unit Test RuleSet.

.DESCRIPTION
Applies the Data-Driven Unit Test RuleSet to generate a PesterFile model that
uses Pester v5 -ForEach on It blocks to drive parameterized test execution.
The template creates:

  - A single Describe block named after the function under test.
  - A BeforeAll block that dot-sources the function's source file and, optionally,
    assigns test-case data from a hashtable array variable.
  - A single Context block whose It blocks use -ForEach to iterate over test cases.
  - Each It entry receives a $_ binding containing the test-case fields.

This satisfies Pester Kind structural rules:
  1. Data defined in BeforeDiscovery or as a literal array in foreach.
  2. All assertions inside It blocks.
  3. -ForEach used on It (Pester v5 preferred style).

.PARAMETER FunctionName
Name of the function under test.

.PARAMETER SourceRelativePath
Relative path segments from the test file's directory to the source file.

.PARAMETER TestCasesVariable
Name of the variable holding the test-case array (without the $ sigil).
Defaults to 'testCases'. The variable will be emitted as `$<variable>` in
the generated BeforeDiscovery block.

.PARAMETER TestCasesExpression
PowerShell expression (as a string) used to populate the TestCasesVariable
inside BeforeDiscovery. If omitted a placeholder comment is emitted instead.

.PARAMETER ContextName
Name of the Context block. Defaults to 'For each input scenario'.

.PARAMETER ItName
Name of the It block. The placeholder '<Name>' maps to $_.Name when -ForEach
iterates the test-case array.

.PARAMETER ItBody
Script block body text for the It block. Reference test-case fields via $_.FieldName.

.PARAMETER OutputPath
Optional directory path to write the .Tests.ps1 file.

.PARAMETER Tags
Optional tags applied to the top-level Describe block.

.PARAMETER Force
Overwrite an existing file when -OutputPath is specified.

.OUTPUTS
Hashtable - The generated PesterFile model.

.EXAMPLE
$model = New-PesterDataDrivenTestTemplate `
    -FunctionName 'Convert-Value' `
    -SourceRelativePath '..', '..', 'public', 'Convert-Value.ps1' `
    -TestCasesVariable 'testCases' `
    -TestCasesExpression '@(@{Input=1;Expected=2},@{Input=3;Expected=6})' `
    -ItName 'Convert-Value_<Name>_ReturnsExpected' `
    -ItBody 'Convert-Value -Input $_.Input | Should -Be $_.Expected' `
    -OutputPath 'tests/Unit' `
    -Force

.NOTES
Philote ID: "a7b8c9d0-e1f2-3456-7890-abcdef012345"
RuleSet: 'PesterDataDrivenUnitTest'
AI assisted using Powershell.instructions.md as guidelines
#>
function New-PesterDataDrivenTestTemplate {
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
    [string]$TestCasesVariable = 'testCases',

    [Parameter(Mandatory = $false)]
    [string]$TestCasesExpression,

    [Parameter(Mandatory = $false)]
    [string]$ContextName = 'For each input scenario',

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ItName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ItBody,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string[]]$Tags = @('Unit'),

    [Parameter(Mandatory = $false)]
    [switch]$Force
  )

  begin {
    $fn = 'New-PesterDataDrivenTestTemplate'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering New-PesterDataDrivenTestTemplate'
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
    $FunctionName = Get-PVal -ParameterName 'FunctionName' -originalPSBoundParameters $PSBoundParameters -dottedPath 'FunctionName' -DefaultValue $FunctionName
    # Snippet: Check and populate simple parameter as Type
    $SourceRelativePath = Get-PVal -ParameterName 'SourceRelativePath' -originalPSBoundParameters $PSBoundParameters -dottedPath 'SourceRelativePath' -DefaultValue $SourceRelativePath -AsType ([string[]])
    # Snippet: Check and populate simple parameter
    $TestCasesVariable = Get-PVal -ParameterName 'TestCasesVariable' -originalPSBoundParameters $PSBoundParameters -dottedPath 'TestCasesVariable' -DefaultValue $TestCasesVariable
    # Snippet: Check and populate simple parameter
    $TestCasesExpression = Get-PVal -ParameterName 'TestCasesExpression' -originalPSBoundParameters $PSBoundParameters -dottedPath 'TestCasesExpression' -DefaultValue $TestCasesExpression
    # Snippet: Check and populate simple parameter
    $ContextName = Get-PVal -ParameterName 'ContextName' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ContextName' -DefaultValue $ContextName
    # Snippet: Check and populate simple parameter
    $ItName = Get-PVal -ParameterName 'ItName' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ItName' -DefaultValue $ItName
    # Snippet: Check and populate simple parameter
    $ItBody = Get-PVal -ParameterName 'ItBody' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ItBody' -DefaultValue $ItBody
    # Snippet: Check and populate simple parameter
    $OutputPath = Get-PVal -ParameterName 'OutputPath' -originalPSBoundParameters $PSBoundParameters -dottedPath 'OutputPath' -DefaultValue $OutputPath
    # Snippet: Check and populate simple parameter as Type
    $Tags = Get-PVal -ParameterName 'Tags' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Tags' -DefaultValue $Tags -AsType ([string[]])
    # Snippet: Check and populate simple parameter as Type
    $Force = Get-PVal -ParameterName 'Force' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Force' -DefaultValue $Force -AsType ([switch])
  }

  process {
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Building Data-Driven template for: $FunctionName"
      # BeforeDiscovery — populate test-case data in discovery phase
      $discoveryBody = if (-not [string]::IsNullOrWhiteSpace($TestCasesExpression)) {
        "`$$TestCasesVariable = $TestCasesExpression"
      }
      else {
        "# TODO: populate `$$TestCasesVariable with test-case hashtable array`n`$$TestCasesVariable = @()"
      }

      # BeforeAll — dot-source the function under test
      $joinedPath = "Join-Path `$PSScriptRoot $(($SourceRelativePath | ForEach-Object { "'$_'" }) -join ', ')"
      $beforeAllBody = ". $joinedPath"

      $it = New-PesterItBlock `
        -Name    $ItName `
        -ForEach "`$$TestCasesVariable" `
        -Body    $ItBody

      $context = New-PesterContextBlock `
        -Name $ContextName `
        -Its  @($it)

      $describe = New-PesterDescribeBlock `
        -Name      $FunctionName `
        -Tags      $Tags `
        -BeforeAll $beforeAllBody `
        -Contexts  @($context) `
        -Its       @()

      $modelParams = @{
        Name            = $FunctionName
        Describes       = @($describe)
        BeforeDiscovery = $discoveryBody
      }
      if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $modelParams['Path'] = $OutputPath
      }

      $model = New-PesterFileModel @modelParams

      if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $forceSwitch = if ($Force) { @{ Force = $true } } else { @{} }
        $null = New-PesterTestFile -Model $model -OutputPath $OutputPath @forceSwitch
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Data-Driven template built for: $FunctionName"
      return $model
    }
    catch {
      $errorMessage = "Failed to build Data-Driven template for '$FunctionName'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  end {}
}

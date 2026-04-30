function Invoke-BuildToolingPesterDebug {
  <#
  .SYNOPSIS
    Runs BuildTooling Pester tests with debug-friendly defaults.
  .DESCRIPTION
    Builds a merged Pester configuration, applies debug overrides, and invokes Pester.
    This file only defines the function; module exports are controlled by the manifest.
  .PARAMETER TestPath
    Path to the test folder or test file to run.
  .PARAMETER Tag
    Optional Pester tag filter.
  .PARAMETER ExcludeTag
    Optional Pester excluded tag filter.
  .PARAMETER OutputFormat
    Optional Pester test-result output format.
  .OUTPUTS
    Pester run result.
  .EXAMPLE
    Invoke-BuildToolingPesterDebug -TestPath .\tests\Unit
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    Get-MergedPesterConfigurations
  #>
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [string]$TestPath = (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'tests\Unit'),

    [string[]]$Tag,

    [string[]]$ExcludeTag,

    [ValidateSet('NUnitXml', 'JUnitXml', 'LegacyNUnitXml', 'None')]
    [string]$OutputFormat = 'None'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }

  process {
    $cfg = Get-MergedPesterConfigurations -Path $TestPath

    $cfg.Run.Path = $TestPath
    $cfg.Output.Verbosity = 'Detailed'
    $cfg.Run.Exit = $true
    $cfg.Run.Throw = $true

    if ($Tag) { $cfg.Filter.Tag = $Tag }
    if ($ExcludeTag) { $cfg.Filter.ExcludeTag = $ExcludeTag }

    if ($OutputFormat -ne 'None') {
      $cfg.TestResult.Enabled = $true
      $cfg.TestResult.OutputFormat = $OutputFormat
      $cfg.TestResult.OutputPath = Join-Path -Path $TestPath -ChildPath 'TestResults.xml'
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Running tests in '$TestPath' with config: $($cfg | Out-String)"
    Invoke-Pester -Configuration $cfg
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
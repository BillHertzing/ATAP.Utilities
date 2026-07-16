<#
.SYNOPSIS
  Runs repository-wide health gates that are intentionally outside package build/test flows.

.DESCRIPTION
  Invokes the repo-level Pester tests under tests/RepoHealth. These tests may
  evaluate many projects and shared repository conventions, so they are not
  part of any individual PowerShell module or C# package test tree.

  C# build pipelines should call this gate after restore and before pack or
  publish. The current RepoHealth suite audits Directory.Build.props property
  propagation across every C# project under src/.

.PARAMETER RepoRoot
  Repository root. Defaults to the parent of this script's Build directory.

.PARAMETER OutputPath
  Optional NUnit XML result path. Defaults to
  _generated/repo-health/RepoHealth.TestResults.xml.

.PARAMETER PesterOutput
  Pester output verbosity for this gate. Defaults to Normal.

.OUTPUTS
  Pester run result object when Invoke-Pester supports -PassThru.

.EXAMPLE
  pwsh -File Build\Invoke-RepoHealthGate.ps1

.NOTES
  AI assisted using Powershell.instructions.md as guidelines
#>

#Requires -Version 7.0
#Requires -Module Pester
[CmdletBinding(SupportsShouldProcess)]
param(
  [ValidateNotNullOrEmpty()]
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,

  [AllowEmptyString()]
  [string]$OutputPath = '',

  [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
  [string]$PesterOutput = 'Normal'
)

$ErrorActionPreference = 'Stop'

function Invoke-RepoHealthGate {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoRoot,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$PesterOutput = 'Normal'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.RepoHealth'
    if (-not (Get-Command -Name Write-PSFMessage -CommandType Function, Cmdlet -ErrorAction SilentlyContinue)) {
      function Write-PSFMessage {
        param(
          [string]$FunctionName,
          [string]$ModuleName,
          [string]$Level,
          [string]$Message,
          [string[]]$Tag
        )
        if ($Level -in @('Important', 'Warning', 'Error')) {
          [Console]::Out.WriteLine("$Level [$FunctionName] $Message")
        }
      }
    }

    $resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    $testPath = Join-Path $resolvedRepoRoot 'tests\RepoHealth'
    if (-not (Test-Path -LiteralPath $testPath -PathType Container)) {
      throw "Repo health test path not found: $testPath"
    }

  }

  process {
    if (-not $PSCmdlet.ShouldProcess($testPath, 'Invoke repo health Pester gate')) {
      return $null
    }

    $outputDirectory = Split-Path -Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory) -and -not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
      New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "RepoHealth gate starting: $testPath"

    $configuration = [PesterConfiguration]::Default
    $configuration.Run.Path = @($testPath)
    $configuration.Run.PassThru = $true
    $configuration.Run.Exit = $false
    $configuration.Run.Throw = $false
    $configuration.Filter.Tag = @('RepoHealth')
    $configuration.Output.Verbosity = $PesterOutput
    $configuration.TestResult.Enabled = $true
    $configuration.TestResult.OutputFormat = 'NUnitXml'
    $configuration.TestResult.OutputPath = $OutputPath

    $result = Invoke-Pester -Configuration $configuration
    $failedContainers = if ($result.PSObject.Properties.Name -contains 'FailedContainersCount') {
      [int]$result.FailedContainersCount
    } else {
      @($result.FailedContainers).Count
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "RepoHealth gate complete: Result=$($result.Result) Passed=$($result.PassedCount) Failed=$($result.FailedCount) FailedContainers=$failedContainers Total=$($result.TotalCount) Output=$OutputPath"

    if ($result.Result -ne 'Passed' -or $result.FailedCount -gt 0 -or $failedContainers -gt 0) {
      throw "RepoHealth gate failed: Result=$($result.Result), failing tests=$($result.FailedCount), failed containers=$failedContainers. See '$OutputPath'."
    }

    return $result
  }

  end {
  }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $RepoRoot '_generated\repo-health\RepoHealth.TestResults.xml'
}

Invoke-RepoHealthGate -RepoRoot $RepoRoot -OutputPath $OutputPath -PesterOutput $PesterOutput

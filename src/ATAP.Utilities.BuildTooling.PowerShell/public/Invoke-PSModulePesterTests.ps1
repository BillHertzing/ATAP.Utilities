<#
.SYNOPSIS
Runs Pester tests for a PowerShell module with tier-appropriate tag filters.

.DESCRIPTION
Tier-aware wrapper around Invoke-Pester used by the 5-Tier module build
pipeline. At tier Sprint, tests are skipped entirely and GatePass = $true.
At tiers Alpha and above, the tag include/exclude lists follow section 5.2
of the 5-Tier Implementation Plan. Pester 5+ is required. JUnit XML test
results and JaCoCo code coverage are emitted to the supplied paths.

.PARAMETER ModuleRoot
Root folder of the module whose tests should run.

.PARAMETER Tier
One of Sprint, Alpha, Beta, QA, Production. Drives the tag filter.

.PARAMETER OutputPath
Destination JUnit-XML file for the Pester test results.

.PARAMETER CoverageOutputPath
Destination JaCoCo XML file for code coverage. Cobertura conversion is a
separate downstream task.

.PARAMETER TestPaths
Override the default test path. Defaults to "$ModuleRoot/tests".

.PARAMETER PesterOutputVerbosity
Controls Pester console output. Defaults to Normal so BuildMaster logs keep
test totals without listing every passing test. Use Detailed or Diagnostic for
interactive troubleshooting.

.OUTPUTS
[PSCustomObject] projecting Pester summary fields plus GatePass, OutputFile,
CoverageFile.

.EXAMPLE
Invoke-PSModulePesterTests -ModuleRoot ./src/MyModule -Tier Alpha -OutputPath ./out/Results.xml -CoverageOutputPath ./out/Coverage.xml

.NOTES
AI assisted using Powershell.instructions.md as guidelines
#>

# Internal helper: selects the tag include / exclude lists for a given tier.
# Exposed as a script-scoped function so the Pester meta-tests can dot-source
# this file and validate the filter table without running nested Pester.
function Get-PSModulePesterTierFilter {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('Sprint', 'Alpha', 'Beta', 'QA', 'Production')]
    [string]$Tier
  )

  # K07: temporary exclusion until New-SprintStage1 is converted to a side-effect-free function contract.
  $pendingStreamKTag = 'PendingStreamK'

  switch ($Tier) {
    'Sprint' {
      return [PSCustomObject]@{
        Skip       = $true
        IncludeTag = @()
        ExcludeTag = @('Disabled')
      }
    }
    'Alpha' {
      return [PSCustomObject]@{
        Skip       = $false
        IncludeTag = @('Unit')
        ExcludeTag = @('Slow', 'Disabled', $pendingStreamKTag)
      }
    }
    'Beta' {
      return [PSCustomObject]@{
        Skip       = $false
        IncludeTag = @('Unit', 'Integration')
        ExcludeTag = @('Slow', 'Disabled', $pendingStreamKTag)
      }
    }
    'QA' {
      return [PSCustomObject]@{
        Skip       = $false
        IncludeTag = @('Unit', 'Integration', 'Functional', 'Regression', 'E2E', 'Performance')
        ExcludeTag = @('Disabled', $pendingStreamKTag)
      }
    }
    'Production' {
      return [PSCustomObject]@{
        Skip       = $false
        IncludeTag = @('Unit', 'Integration', 'Functional', 'Regression', 'E2E', 'Performance', 'Smoke')
        ExcludeTag = @('Disabled', $pendingStreamKTag)
      }
    }
  }
}

# Internal helper: builds the Pester 5 Configuration object from pre-computed
# filter lists and the test/output/coverage paths. Also dot-sourceable for
# meta-tests.
function New-PSModulePesterConfiguration {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string[]]$TestPaths,
    [Parameter(Mandatory)] [string[]]$IncludeTag,
    [Parameter(Mandatory)] [string[]]$ExcludeTag,
    [Parameter(Mandatory)] [string]$OutputPath,
    [Parameter(Mandatory)] [string]$CoverageOutputPath,
    [string[]]$CoveragePaths,
    [switch]$SkipTestResult,
    [switch]$SkipCodeCoverage,
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$PesterOutputVerbosity = 'Normal'
  )

  $cfg = [PesterConfiguration]::Default
  $cfg.Run.Path = $TestPaths
  $cfg.Run.Exit = $false
  $cfg.Run.Throw = $false
  $cfg.Run.PassThru = $true

  if ($IncludeTag -and $IncludeTag.Count -gt 0) {
    $cfg.Filter.Tag = $IncludeTag
  }
  if ($ExcludeTag -and $ExcludeTag.Count -gt 0) {
    $cfg.Filter.ExcludeTag = $ExcludeTag
  }

  if ($SkipTestResult) {
    $cfg.TestResult.Enabled = $false
  } else {
    $cfg.TestResult.Enabled = $true
    $cfg.TestResult.OutputFormat = 'JUnitXml'
    $cfg.TestResult.OutputPath = $OutputPath
  }

  if ($SkipCodeCoverage) {
    $cfg.CodeCoverage.Enabled = $false
  } else {
    $cfg.CodeCoverage.Enabled = $true
    $cfg.CodeCoverage.OutputFormat = 'JaCoCo'
    $cfg.CodeCoverage.OutputPath = $CoverageOutputPath
    $cfg.CodeCoverage.CoveragePercentTarget = 0
    if ($CoveragePaths -and $CoveragePaths.Count -gt 0) {
      $cfg.CodeCoverage.Path = $CoveragePaths
    }
  }

  $cfg.Output.Verbosity = $PesterOutputVerbosity
  return $cfg
}

function Invoke-PSModulePesterTests {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)]
    [string]$ModuleRoot,

    [Parameter(Mandatory)]
    [ValidateSet('Sprint', 'Alpha', 'Beta', 'QA', 'Production')]
    [string]$Tier,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [Parameter(Mandatory)]
    [string]$CoverageOutputPath,

    [string[]]$TestPaths,

    [switch]$SkipTestResult,

    [switch]$SkipCodeCoverage,

    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$PesterOutputVerbosity = 'Normal'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = $MyInvocation.MyCommand.ModuleName
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with ModuleRoot='$ModuleRoot' Tier='$Tier'"

    # Check and populate simple parameter: ModuleRoot
    if (-not $PSBoundParameters.ContainsKey('ModuleRoot') -or [string]::IsNullOrWhiteSpace($ModuleRoot)) {
      throw "[$fn] Parameter 'ModuleRoot' is required"
    }
    # Check and populate simple parameter: Tier
    if (-not $PSBoundParameters.ContainsKey('Tier') -or [string]::IsNullOrWhiteSpace($Tier)) {
      throw "[$fn] Parameter 'Tier' is required"
    }
    # Check and populate simple parameter: OutputPath
    if (-not $PSBoundParameters.ContainsKey('OutputPath') -or [string]::IsNullOrWhiteSpace($OutputPath)) {
      throw "[$fn] Parameter 'OutputPath' is required"
    }
    # Check and populate simple parameter: CoverageOutputPath
    if (-not $PSBoundParameters.ContainsKey('CoverageOutputPath') -or [string]::IsNullOrWhiteSpace($CoverageOutputPath)) {
      throw "[$fn] Parameter 'CoverageOutputPath' is required"
    }

    if (-not $TestPaths -or $TestPaths.Count -eq 0) {
      $TestPaths = @(Join-Path $ModuleRoot 'tests')
    }
  }

  process {
    try {
      if ($Tier -eq 'Sprint') {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Tier is Sprint; skipping Pester entirely and emitting stub JUnit XML'

        # Write a stub JUnit XML so downstream pipeline steps (e.g. GateAck) can
        # rely on the file existing — matches Invoke-PSModulePSScriptAnalyzer pattern.
        $outDir = Split-Path -Path $OutputPath -Parent
        if ($outDir -and -not (Test-Path -Path $outDir)) {
          if ($PSCmdlet.ShouldProcess($outDir, 'Create output directory')) {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
          }
        }
        $stubXml = @'
<?xml version="1.0" encoding="utf-8"?>
<testsuites tests="0" failures="0" errors="0" time="0">
  <testsuite name="Pester" tests="0" failures="0" errors="0" skipped="0" time="0" />
</testsuites>
'@
        if ($PSCmdlet.ShouldProcess($OutputPath, 'Write stub Pester JUnit XML')) {
          Set-Content -Path $OutputPath -Value $stubXml -Encoding UTF8
        }

        return [PSCustomObject]@{
          Tier         = $Tier
          Passed       = 0
          Failed       = 0
          PassedCount  = 0
          FailedCount  = 0
          SkippedCount = 0
          TotalCount   = 0
          Duration     = [TimeSpan]::Zero
          GatePass     = $true
          Skipped      = $true
          OutputFile   = $OutputPath
          CoverageFile = $CoverageOutputPath
          Result       = $null
        }
      }

      # Ensure Pester 5+ is available.
      $pester = Get-Module -ListAvailable -Name Pester |
        Where-Object { $_.Version -ge [version]'5.0.0' } |
        Sort-Object Version -Descending |
        Select-Object -First 1
      if (-not $pester) {
        $msg = 'Pester 5 or newer is not installed. Install it with: Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }
      Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop

      # Create output folders.
      foreach ($p in @($OutputPath, $CoverageOutputPath)) {
        $dir = Split-Path -Path $p -Parent
        if ($dir -and -not (Test-Path -Path $dir)) {
          if ($PSCmdlet.ShouldProcess($dir, 'Create output directory')) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
          }
        }
      }

      $filter = Get-PSModulePesterTierFilter -Tier $Tier
      $excludeTag = @($filter.ExcludeTag)
      if ($PesterOutputVerbosity -eq 'None') {
        # Some unit tests intentionally exercise SupportsShouldProcess with
        # -WhatIf. PowerShell writes those host messages outside the normal
        # streams, so skip them only in transcript-quiet BuildMaster runs.
        $excludeTag += 'BuildTranscriptNoise'
      }

      $coveragePaths = @()
      $publicDir = Join-Path $ModuleRoot 'public'
      $privateDir = Join-Path $ModuleRoot 'private'
      if (Test-Path -Path $publicDir) { $coveragePaths += $publicDir }
      if (Test-Path -Path $privateDir) { $coveragePaths += $privateDir }

      $cfg = New-PSModulePesterConfiguration `
        -TestPaths $TestPaths `
        -IncludeTag $filter.IncludeTag `
        -ExcludeTag $excludeTag `
        -OutputPath $OutputPath `
        -CoverageOutputPath $CoverageOutputPath `
        -CoveragePaths $coveragePaths `
        -SkipTestResult:$SkipTestResult `
        -SkipCodeCoverage:$SkipCodeCoverage `
        -PesterOutputVerbosity $PesterOutputVerbosity

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Running Invoke-Pester for tier $Tier (IncludeTag=$($filter.IncludeTag -join ',') ExcludeTag=$($filter.ExcludeTag -join ','))"

      $result = $null
      if ($PSCmdlet.ShouldProcess("$TestPaths", 'Invoke-Pester')) {
        if ($PesterOutputVerbosity -eq 'None') {
          # BuildMaster summary logging comes from this wrapper. When Pester's
          # own output is disabled, suppress incidental streams emitted by
          # tests that intentionally exercise warning/error paths.
          $result = Invoke-Pester -Configuration $cfg 2>$null 3>$null 4>$null 5>$null 6>$null
        } else {
          $result = Invoke-Pester -Configuration $cfg
        }
      }

      $passed = if ($result) { [int]$result.PassedCount } else { 0 }
      $failed = if ($result) { [int]$result.FailedCount } else { 0 }
      $skipped = if ($result) { [int]$result.SkippedCount } else { 0 }
      $total = if ($result) { [int]$result.TotalCount } else { 0 }
      $duration = if ($result -and $result.Duration) { $result.Duration } else { [TimeSpan]::Zero }

      $gatePass = ($failed -eq 0)
      if (-not $gatePass) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Pester gate FAILED: $failed failing test(s) of $total"
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Pester gate passed ($passed passed)"
      }

      return [PSCustomObject]@{
        Tier         = $Tier
        Passed       = $passed
        Failed       = $failed
        PassedCount  = $passed
        FailedCount  = $failed
        SkippedCount = $skipped
        TotalCount   = $total
        Duration     = $duration
        GatePass     = $gatePass
        OutputFile   = $OutputPath
        CoverageFile = $CoverageOutputPath
        Result       = $result
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failure in $fn : $($_.Exception.Message)" -ErrorRecord $_
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn"
    }
  }
}

if ($MyInvocation.MyCommand.ScriptBlock.Module) {
  Export-ModuleMember -Function Invoke-PSModulePesterTests, Get-PSModulePesterTierFilter, New-PSModulePesterConfiguration
}

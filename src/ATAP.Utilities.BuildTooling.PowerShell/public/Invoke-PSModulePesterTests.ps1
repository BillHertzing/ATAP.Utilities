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
        ExcludeTag = @('Slow', 'Disabled')
      }
    }
    'Beta' {
      return [PSCustomObject]@{
        Skip       = $false
        IncludeTag = @('Unit', 'Integration')
        ExcludeTag = @('Slow', 'Disabled')
      }
    }
    'QA' {
      return [PSCustomObject]@{
        Skip       = $false
        IncludeTag = @('Unit', 'Integration', 'Functional', 'Regression', 'E2E', 'Performance')
        ExcludeTag = @('Disabled')
      }
    }
    'Production' {
      return [PSCustomObject]@{
        Skip       = $false
        IncludeTag = @('Unit', 'Integration', 'Functional', 'Regression', 'E2E', 'Performance', 'Smoke')
        ExcludeTag = @('Disabled')
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
    [string[]]$CoveragePaths
  )

  $cfg = [PesterConfiguration]::Default
  $cfg.Run.Path = $TestPaths
  $cfg.Run.Exit = $false
  $cfg.Run.Throw = $false

  if ($IncludeTag -and $IncludeTag.Count -gt 0) {
    $cfg.Filter.Tag = $IncludeTag
  }
  if ($ExcludeTag -and $ExcludeTag.Count -gt 0) {
    $cfg.Filter.ExcludeTag = $ExcludeTag
  }

  $cfg.TestResult.Enabled = $true
  $cfg.TestResult.OutputFormat = 'JUnitXml'
  $cfg.TestResult.OutputPath = $OutputPath

  $cfg.CodeCoverage.Enabled = $true
  $cfg.CodeCoverage.OutputFormat = 'JaCoCo'
  $cfg.CodeCoverage.OutputPath = $CoverageOutputPath
  if ($CoveragePaths -and $CoveragePaths.Count -gt 0) {
    $cfg.CodeCoverage.Path = $CoveragePaths
  }

  $cfg.Output.Verbosity = 'Detailed'
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

    [string[]]$TestPaths
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
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Tier is Sprint; skipping Pester entirely'
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

      $coveragePaths = @()
      $publicDir = Join-Path $ModuleRoot 'public'
      $privateDir = Join-Path $ModuleRoot 'private'
      if (Test-Path -Path $publicDir) { $coveragePaths += $publicDir }
      if (Test-Path -Path $privateDir) { $coveragePaths += $privateDir }

      $cfg = New-PSModulePesterConfiguration `
        -TestPaths $TestPaths `
        -IncludeTag $filter.IncludeTag `
        -ExcludeTag $filter.ExcludeTag `
        -OutputPath $OutputPath `
        -CoverageOutputPath $CoverageOutputPath `
        -CoveragePaths $coveragePaths

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Running Invoke-Pester for tier $Tier (IncludeTag=$($filter.IncludeTag -join ',') ExcludeTag=$($filter.ExcludeTag -join ','))"

      $result = $null
      if ($PSCmdlet.ShouldProcess("$TestPaths", 'Invoke-Pester')) {
        $result = Invoke-Pester -Configuration $cfg
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

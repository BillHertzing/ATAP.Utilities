# Meta tests for Invoke-PSModulePesterTests.
# These tests MUST NOT invoke nested Pester. They validate the tier-filter
# helper and the early-return behavior for Sprint.
# AI assisted using Powershell.instructions.md as guidelines

BeforeAll {
  $functionPath = Join-Path $PSScriptRoot '../public/Invoke-PSModulePesterTests.ps1'
  . $functionPath

  Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("psp_" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
}

AfterAll {
  if ($script:tempRoot -and (Test-Path $script:tempRoot)) {
    Remove-Item -Recurse -Force $script:tempRoot -ErrorAction SilentlyContinue
  }
}

Describe 'Get-PSModulePesterTierFilter' -Tag 'Unit' {

  It 'marks Sprint as Skip with only Disabled excluded' {
    $f = Get-PSModulePesterTierFilter -Tier 'Sprint'
    $f.Skip       | Should -BeTrue
    $f.IncludeTag | Should -BeNullOrEmpty
    $f.ExcludeTag | Should -Contain 'Disabled'
  }

  It 'Alpha includes only Unit and excludes Slow,Disabled,PendingStreamK' {
    $f = Get-PSModulePesterTierFilter -Tier 'Alpha'
    $f.Skip       | Should -BeFalse
    $f.IncludeTag | Should -Be @('Unit')
    $f.ExcludeTag | Should -Contain 'Slow'
    $f.ExcludeTag | Should -Contain 'Disabled'
    $f.ExcludeTag | Should -Contain 'PendingStreamK'
  }

  It 'Beta includes Unit,Integration and excludes Slow,Disabled,PendingStreamK' {
    $f = Get-PSModulePesterTierFilter -Tier 'Beta'
    $f.IncludeTag | Should -Be @('Unit', 'Integration')
    $f.ExcludeTag | Should -Contain 'Slow'
    $f.ExcludeTag | Should -Contain 'Disabled'
    $f.ExcludeTag | Should -Contain 'PendingStreamK'
  }

  It 'QA includes the full functional suite and excludes Disabled,PendingStreamK' {
    $f = Get-PSModulePesterTierFilter -Tier 'QA'
    $f.IncludeTag | Should -Be @('Unit', 'Integration', 'Functional', 'Regression', 'E2E', 'Performance')
    $f.ExcludeTag | Should -Be @('Disabled', 'PendingStreamK')
    $f.ExcludeTag | Should -Not -Contain 'Slow'
  }

  It 'Production includes Smoke on top of QA and excludes Disabled,PendingStreamK' {
    $f = Get-PSModulePesterTierFilter -Tier 'Production'
    $f.IncludeTag | Should -Contain 'Smoke'
    $f.IncludeTag | Should -Contain 'Unit'
    $f.IncludeTag | Should -Contain 'Performance'
    $f.ExcludeTag | Should -Be @('Disabled', 'PendingStreamK')
  }
}

Describe 'New-PSModulePesterConfiguration' -Tag 'Unit' {

  It 'produces a Pester Configuration object matching the filter table' {
    $out = Join-Path $script:tempRoot 'Results.xml'
    $cov = Join-Path $script:tempRoot 'Coverage.xml'
    $cfg = New-PSModulePesterConfiguration `
      -TestPaths @('C:\nonexistent\tests') `
      -IncludeTag @('Unit', 'Integration') `
      -ExcludeTag @('Slow', 'Disabled') `
      -OutputPath $out `
      -CoverageOutputPath $cov

    $cfg.Filter.Tag.Value        | Should -Be @('Unit', 'Integration')
    $cfg.Filter.ExcludeTag.Value | Should -Be @('Slow', 'Disabled')
    $cfg.Run.PassThru.Value      | Should -BeTrue
    $cfg.TestResult.Enabled.Value      | Should -BeTrue
    $cfg.TestResult.OutputFormat.Value | Should -Be 'JUnitXml'
    $cfg.TestResult.OutputPath.Value   | Should -Be $out
    $cfg.CodeCoverage.Enabled.Value      | Should -BeTrue
    $cfg.CodeCoverage.OutputFormat.Value | Should -Be 'JaCoCo'
    $cfg.CodeCoverage.OutputPath.Value   | Should -Be $cov
    $cfg.CodeCoverage.CoveragePercentTarget.Value | Should -Be 0
    $cfg.Output.Verbosity.Value          | Should -Be 'Normal'
  }

  It 'honors an explicit Pester output verbosity' {
    $out = Join-Path $script:tempRoot 'Results-detailed.xml'
    $cov = Join-Path $script:tempRoot 'Coverage-detailed.xml'
    $cfg = New-PSModulePesterConfiguration `
      -TestPaths @('C:\nonexistent\tests') `
      -IncludeTag @('Unit') `
      -ExcludeTag @('Slow', 'Disabled') `
      -OutputPath $out `
      -CoverageOutputPath $cov `
      -PesterOutputVerbosity 'Detailed'

    $cfg.Output.Verbosity.Value | Should -Be 'Detailed'
  }

  It 'can disable code coverage while preserving the test-result settings' {
    $out = Join-Path $script:tempRoot 'Results-no-coverage.xml'
    $cov = Join-Path $script:tempRoot 'Coverage-no-coverage.xml'
    $cfg = New-PSModulePesterConfiguration `
      -TestPaths @('C:\nonexistent\tests') `
      -IncludeTag @('Unit') `
      -ExcludeTag @('Slow', 'Disabled') `
      -OutputPath $out `
      -CoverageOutputPath $cov `
      -SkipCodeCoverage

    $cfg.TestResult.Enabled.Value | Should -BeTrue
    $cfg.TestResult.OutputPath.Value | Should -Be $out
    $cfg.CodeCoverage.Enabled.Value | Should -BeFalse
  }

  It 'can disable JUnit test-result output while preserving the run filters' {
    $out = Join-Path $script:tempRoot 'Results-no-junit.xml'
    $cov = Join-Path $script:tempRoot 'Coverage-no-junit.xml'
    $cfg = New-PSModulePesterConfiguration `
      -TestPaths @('C:\nonexistent\tests') `
      -IncludeTag @('Unit') `
      -ExcludeTag @('Slow', 'Disabled') `
      -OutputPath $out `
      -CoverageOutputPath $cov `
      -SkipTestResult

    $cfg.Filter.Tag.Value | Should -Be @('Unit')
    $cfg.Filter.ExcludeTag.Value | Should -Be @('Slow', 'Disabled')
    $cfg.TestResult.Enabled.Value | Should -BeFalse
    $cfg.CodeCoverage.Enabled.Value | Should -BeTrue
  }
}

Describe 'Invoke-PSModulePesterTests (Sprint short-circuit)' -Tag 'Unit' {

  It 'returns GatePass=$true without invoking Pester when Tier=Sprint' {
    Mock -CommandName Invoke-Pester -MockWith { throw 'Invoke-Pester must not be called on Sprint tier' }

    $moduleRoot = Join-Path $script:tempRoot 'm1'
    New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null

    $out = Join-Path $script:tempRoot 'sprint-out.xml'
    $cov = Join-Path $script:tempRoot 'sprint-cov.xml'

    $result = Invoke-PSModulePesterTests -ModuleRoot $moduleRoot -Tier 'Sprint' -OutputPath $out -CoverageOutputPath $cov

    $result.Tier        | Should -Be 'Sprint'
    $result.GatePass    | Should -BeTrue
    $result.Passed      | Should -Be 0
    $result.Failed      | Should -Be 0
    $result.PassedCount | Should -Be 0
    $result.FailedCount | Should -Be 0

    Should -Invoke -CommandName Invoke-Pester -Times 0
  }
}

Describe 'Invoke-PSModulePesterTests (quiet output)' -Tag 'Unit' {

  BeforeEach {
    Mock Write-PSFMessage { }
  }

  It 'suppresses incidental Pester streams when output verbosity is None' {
    $script:capturedPesterConfiguration = $null
    Mock -CommandName Invoke-Pester -MockWith {
      param($Configuration)
      $script:capturedPesterConfiguration = $Configuration

      Write-Error 'expected negative-path error noise' -ErrorAction Continue
      Write-Warning 'expected negative-path warning noise'
      Write-Verbose 'expected verbose noise' -Verbose
      Write-Debug 'expected debug noise' -Debug
      Write-Information 'expected information noise' -InformationAction Continue

      [PSCustomObject]@{
        PassedCount  = 1
        FailedCount  = 0
        SkippedCount = 0
        TotalCount   = 1
        Duration     = [TimeSpan]::Zero
      }
    }

    $moduleRoot = Join-Path $script:tempRoot 'quiet-module'
    New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null

    $out = Join-Path $script:tempRoot 'quiet-out.xml'
    $cov = Join-Path $script:tempRoot 'quiet-cov.xml'

    $output = Invoke-PSModulePesterTests `
      -ModuleRoot $moduleRoot `
      -Tier 'Alpha' `
      -OutputPath $out `
      -CoverageOutputPath $cov `
      -PesterOutputVerbosity 'None' 2>&1 3>&1 4>&1 5>&1 6>&1

    @($output).Count | Should -Be 1
    $output.GatePass | Should -BeTrue
    $output.Passed | Should -Be 1
    $script:capturedPesterConfiguration.Filter.ExcludeTag.Value | Should -Contain 'BuildTranscriptNoise'
    Should -Invoke -CommandName Invoke-Pester -Times 1 -Exactly
  }
}

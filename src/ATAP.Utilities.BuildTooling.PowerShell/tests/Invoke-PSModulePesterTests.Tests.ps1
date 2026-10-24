# Meta tests for Invoke-PSModulePesterTests.
# These tests MUST NOT invoke nested Pester. They validate the tier-filter
# helper and the early-return behavior for Sprint.
# AI assisted using Powershell.instructions.md as guidelines

BeforeAll {
  $functionPath = Join-Path $PSScriptRoot '../public/Invoke-PSModulePesterTests.ps1'
  . $functionPath

  Import-Module Pester -RequiredVersion 6.2.0 -DisableNameChecking -ErrorAction Stop

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

  It 'Alpha includes only Unit and excludes Slow,Disabled (PendingStreamK no longer excluded — V4-B06)' {
    $f = Get-PSModulePesterTierFilter -Tier 'Alpha'
    $f.Skip       | Should -BeFalse
    $f.IncludeTag | Should -Be @('Unit')
    $f.ExcludeTag | Should -Contain 'Slow'
    $f.ExcludeTag | Should -Contain 'Disabled'
    $f.ExcludeTag | Should -Not -Contain 'PendingStreamK'
  }

  It 'Beta includes Unit,Integration and excludes Slow,Disabled (PendingStreamK no longer excluded — V4-B06)' {
    $f = Get-PSModulePesterTierFilter -Tier 'Beta'
    $f.IncludeTag | Should -Be @('Unit', 'Integration')
    $f.ExcludeTag | Should -Contain 'Slow'
    $f.ExcludeTag | Should -Contain 'Disabled'
    $f.ExcludeTag | Should -Not -Contain 'PendingStreamK'
  }

  It 'QA includes the full functional suite and excludes only Disabled (V4-B06)' {
    $f = Get-PSModulePesterTierFilter -Tier 'QA'
    $f.IncludeTag | Should -Be @('Unit', 'Integration', 'Functional', 'Regression', 'E2E', 'Performance')
    $f.ExcludeTag | Should -Be @('Disabled')
    $f.ExcludeTag | Should -Not -Contain 'Slow'
    $f.ExcludeTag | Should -Not -Contain 'PendingStreamK'
  }

  It 'Production includes Smoke on top of QA and excludes only Disabled (V4-B06)' {
    $f = Get-PSModulePesterTierFilter -Tier 'Production'
    $f.IncludeTag | Should -Contain 'Smoke'
    $f.IncludeTag | Should -Contain 'Unit'
    $f.IncludeTag | Should -Contain 'Performance'
    $f.ExcludeTag | Should -Be @('Disabled')
    $f.ExcludeTag | Should -Not -Contain 'PendingStreamK'
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

Describe 'New-PSModulePesterProgressPlugin' -Tag 'Unit' {

  It 'reports discovery and every configured completed-test interval' {
    $messages = [System.Collections.Generic.List[string]]::new()
    $plugin = New-PSModulePesterProgressPlugin -Interval 2 -FunctionName 'TestFn' -WriteLine {
      param([string]$Line)
      $messages.Add($Line)
    }

    $testA = [PSCustomObject]@{ Name = 'first'; ShouldRun = $true }
    $testB = [PSCustomObject]@{ Name = 'second'; ShouldRun = $true }
    $innerBlock = [PSCustomObject]@{
      ShouldRun = $true
      Tests     = @($testA, $testB)
      Blocks    = @()
    }
    $rootBlock = [PSCustomObject]@{
      ShouldRun = $true
      Tests     = @()
      Blocks    = @($innerBlock)
    }

    $pluginOutput = @(
      & $plugin.DiscoveryStart @{ BlockContainers = @('a.tests.ps1') }
      & $plugin.DiscoveryEnd @{ BlockContainers = @($rootBlock); Duration = [TimeSpan]::FromSeconds(1) }
      & $plugin.EachTestSetupStart @{ Test = $testA }
      & $plugin.EachTestTeardownEnd @{ Test = $testA }
      & $plugin.EachTestSetupStart @{ Test = $testB }
      & $plugin.EachTestTeardownEnd @{ Test = $testB }
    )

    $pluginOutput | Should -BeNullOrEmpty
    $messages.Count | Should -Be 4
    $messages[0] | Should -Be 'Important [TestFn] Pester discovery started for 1 test container(s).'
    $messages[1] | Should -Match 'Pester discovery completed: 2 test\(s\) discovered'
    $messages[2] | Should -Match 'Pester current test: 1/2 started'
    $messages[2] | Should -Match 'first'
    $messages[3] | Should -Match 'Pester progress: 2/2 test\(s\) completed'
    $messages[3] | Should -Match 'last: second'
  }
}

Describe 'Get-PSModulePesterFailedTestSummary' -Tag 'Unit' {

  It 'returns compact failing-test details from a Pester result object' {
    $failedTest = [PSCustomObject]@{
      Result      = 'Failed'
      ExpandedName = 'does the important thing'
      ErrorRecord = @(
        [System.Management.Automation.ErrorRecord]::new(
          [System.Exception]::new("first line`nsecond line"),
          'ExampleFailure',
          [System.Management.Automation.ErrorCategory]::InvalidResult,
          $null
        )
      )
    }
    $passedTest = [PSCustomObject]@{
      Result = 'Passed'
      Name   = 'is fine'
    }
    $result = [PSCustomObject]@{
      Containers = @(
        [PSCustomObject]@{
          Item   = 'C:\tests\Example.Tests.ps1'
          Blocks = @(
            [PSCustomObject]@{
              Tests  = @($passedTest, $failedTest)
              Blocks = @()
            }
          )
        }
      )
    }

    $summary = Get-PSModulePesterFailedTestSummary -PesterResult $result

    $summary | Should -HaveCount 1
    $summary[0].Container | Should -Be 'Example.Tests.ps1'
    $summary[0].Name | Should -Be 'does the important thing'
    $summary[0].Message | Should -Be 'first line second line'
  }
}

Describe 'Select-PSModulePesterRunResult' -Tag 'Unit' {

  It 'selects the Pester summary object from mixed success-stream output' {
    $summary = [PSCustomObject]@{
      PassedCount = 2
      FailedCount = 1
      TotalCount  = 3
    }

    $result = Select-PSModulePesterRunResult -InvocationOutput @('test output', [PSCustomObject]@{ Name = 'noise' }, $summary)

    $result | Should -Be $summary
  }
}

Describe 'Write-PSModulePesterJUnitResult' -Tag 'Unit' {

  It 'excludes tag-filtered NotRun tests from JUnit counts and cases' {
    $result = [PSCustomObject]@{
      PassedCount  = 1
      FailedCount  = 0
      SkippedCount = 1
      NotRunCount  = 1
      TotalCount   = 3
      Duration     = [TimeSpan]::FromSeconds(1)
      Tests        = @(
        [PSCustomObject]@{ Name = 'runs'; Result = 'Passed'; Duration = [TimeSpan]::Zero }
        [PSCustomObject]@{ Name = 'explicit skip'; Result = 'Skipped'; Duration = [TimeSpan]::Zero }
        [PSCustomObject]@{ Name = 'filtered out'; Result = 'NotRun'; Duration = [TimeSpan]::Zero }
      )
    }
    $out = Join-Path $script:tempRoot 'filtered-junit.xml'

    Write-PSModulePesterJUnitResult -PesterResult $result -OutputPath $out

    $xml = [xml](Get-Content -LiteralPath $out -Raw)
    $xml.testsuites.tests | Should -Be '2'
    $xml.testsuites.skipped | Should -Be '1'
    @($xml.testsuites.testsuite.testcase) | Should -HaveCount 2
    @($xml.testsuites.testsuite.testcase.name) | Should -Not -Contain 'filtered out'
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

Describe 'Invoke-PSModulePesterTests run and framework gate' -Tag 'Unit' {
  BeforeEach { Mock Write-PSFMessage { } }

  It '<Case>' -ForEach @(
    @{Case='accepts a complete Passed result'; Raw='Passed'; Blocks=0; Containers=0; State='Passed'; HasContainerError=$false; Missing=$false; Filtered=$false; Expected=$true}
    @{Case='accepts Passed with filtered NotRun containers'; Raw='Passed'; Blocks=0; Containers=0; State='Passed'; HasContainerError=$false; Missing=$false; Filtered=$true; Expected=$true}
    @{Case='rejects raw Failed with zero failed cases'; Raw='Failed'; Blocks=0; Containers=0; State='Passed'; HasContainerError=$false; Missing=$false; Filtered=$false; Expected=$false}
    @{Case='rejects a failed container aggregate with passing cases'; Raw='Passed'; Blocks=0; Containers=1; State='Passed'; HasContainerError=$false; Missing=$false; Filtered=$false; Expected=$false}
    @{Case='rejects a failed block with passing cases'; Raw='Passed'; Blocks=1; Containers=0; State='Passed'; HasContainerError=$false; Missing=$false; Filtered=$false; Expected=$false}
    @{Case='rejects a Failed container with inconsistent zero aggregates'; Raw='Passed'; Blocks=0; Containers=0; State='Failed'; HasContainerError=$false; Missing=$false; Filtered=$false; Expected=$false}
    @{Case='rejects an error-bearing container with inconsistent Passed summary'; Raw='Passed'; Blocks=0; Containers=0; State='Passed'; HasContainerError=$true; Missing=$false; Filtered=$false; Expected=$false}
    @{Case='rejects a missing raw Result property'; Raw='Passed'; Blocks=0; Containers=0; State='Passed'; HasContainerError=$false; Missing=$true; Filtered=$false; Expected=$false}
    @{Case='rejects a null raw Result'; Raw=$null; Blocks=0; Containers=0; State='Passed'; HasContainerError=$false; Missing=$false; Filtered=$false; Expected=$false}
  ) {
    $script:gateSummary=[PSCustomObject]@{
      Result=$Raw; PassedCount=1; FailedCount=0; SkippedCount=0
      NotRunCount=0; TotalCount=1; Duration=[TimeSpan]::Zero
      FailedBlocksCount=$Blocks; FailedContainersCount=$Containers
      FailedBlocks=@(); Tests=@([PSCustomObject]@{Name='passing synthetic case';Result='Passed';Duration=[TimeSpan]::Zero})
      Containers=@([PSCustomObject]@{Item='synthetic-container';Result=$State;ErrorRecord=@()})
    }
    if($HasContainerError){$script:gateSummary.Containers[0].ErrorRecord=@([Management.Automation.ErrorRecord]::new([InvalidOperationException]::new('synthetic cleanup failed'),'CleanupFailure',[Management.Automation.ErrorCategory]::InvalidResult,$null))}
    if($Blocks){$script:gateSummary.FailedBlocks=@([PSCustomObject]@{Path=@('synthetic','AfterAll');Result='Failed';ErrorRecord=@('synthetic teardown failed')})}
    if($Missing){$script:gateSummary.PSObject.Properties.Remove('Result')}
    if($Filtered){
      $script:gateSummary.NotRunCount=2; $script:gateSummary.TotalCount=3
      $script:gateSummary.Containers+=([PSCustomObject]@{Item='filtered-container';Result='NotRun';ErrorRecord=@()})
    }
    Mock Invoke-Pester { $script:gateSummary }
    $root=Join-Path $script:tempRoot ([guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($root)
    $out=Join-Path $root 'gate.xml'
    $r=Invoke-PSModulePesterTests -ModuleRoot $root -Tier Alpha -OutputPath $out -CoverageOutputPath (Join-Path $root 'coverage.xml') -SkipCodeCoverage
    $r.GatePass | Should -Be $Expected
    $r.PassedCount | Should -Be 1
    $r.FailedCount | Should -Be 0
    $r.TotalCount | Should -Be 1
    Should -Invoke Invoke-Pester -Times 1 -Exactly
    if(-not $Expected){
      $failure=Get-Content -LiteralPath ([IO.Path]::ChangeExtension($out,'.Failures.json')) -Raw|ConvertFrom-Json
      $expectedRaw=if($Missing){''}else{[string]$Raw}
      $failure.RawResult | Should -Be $expectedRaw
      $failure.FailedBlocksCount | Should -Be $Blocks
      $failure.FailedContainersCount | Should -Be $Containers
      if($HasContainerError){$failure.ContainerFailures[0].Errors | Should -Contain 'synthetic cleanup failed'}
      if($Blocks){$failure.FailedBlocks[0].Errors | Should -Contain 'synthetic teardown failed'}
      if($State -eq 'Failed'){$failure.ContainerFailures[0].Result | Should -Be 'Failed'}
    }
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
      Write-Output 'expected success-stream noise'

      [PSCustomObject]@{
        Result = 'Passed'
        FailedBlocksCount = 0
        FailedContainersCount = 0
        Containers = @([PSCustomObject]@{Result='Passed';ErrorRecord=@();Item='synthetic-container'})
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
    $script:capturedPesterConfiguration.Filter.ExcludeTag.Value | Should -Contain 'PromotedModuleHostSensitive'
    Should -Invoke -CommandName Invoke-Pester -Times 1 -Exactly
  }

  It 'adds caller-supplied exclusions independently of output verbosity' {
    $script:capturedPesterConfiguration = $null
    Mock -CommandName Invoke-Pester -MockWith {
      param($Configuration)
      $script:capturedPesterConfiguration = $Configuration
      [PSCustomObject]@{
        Result = 'Passed'
        FailedBlocksCount = 0
        FailedContainersCount = 0
        Containers = @([PSCustomObject]@{Result='Passed';ErrorRecord=@();Item='synthetic-container'})
        PassedCount  = 1
        FailedCount  = 0
        SkippedCount = 0
        TotalCount   = 1
        Duration     = [TimeSpan]::Zero
      }
    }

    $moduleRoot = Join-Path $script:tempRoot 'additional-exclude-module'
    New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null

    $result = Invoke-PSModulePesterTests `
      -ModuleRoot $moduleRoot `
      -Tier 'Alpha' `
      -OutputPath (Join-Path $script:tempRoot 'additional-exclude-out.xml') `
      -CoverageOutputPath (Join-Path $script:tempRoot 'additional-exclude-cov.xml') `
      -AdditionalExcludeTag @('PromotedModuleHostSensitive', 'Disabled')

    $result.GatePass | Should -BeTrue
    $script:capturedPesterConfiguration.Filter.ExcludeTag.Value | Should -Contain 'PromotedModuleHostSensitive'
    @($script:capturedPesterConfiguration.Filter.ExcludeTag.Value | Where-Object { $_ -eq 'Disabled' }).Count | Should -Be 1
  }

  It 'fails a non-Sprint gate when the tier filter selects zero tests' {
    Mock -CommandName Invoke-Pester -MockWith {
      [PSCustomObject]@{
        Result = 'Passed'
        FailedBlocksCount = 0
        FailedContainersCount = 0
        Containers = @([PSCustomObject]@{Result='Passed';ErrorRecord=@();Item='synthetic-container'})
        PassedCount  = 0
        FailedCount  = 0
        SkippedCount = 0
        TotalCount   = 0
        Duration     = [TimeSpan]::Zero
      }
    }

    $moduleRoot = Join-Path $script:tempRoot 'zero-test-module'
    New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null

    $result = Invoke-PSModulePesterTests `
      -ModuleRoot $moduleRoot `
      -Tier 'Production' `
      -OutputPath (Join-Path $script:tempRoot 'zero-test-out.xml') `
      -CoverageOutputPath (Join-Path $script:tempRoot 'zero-test-cov.xml') `
      -SkipTestResult

    $result.TotalCount | Should -Be 0
    $result.GatePass | Should -BeFalse
  }

  It 'reports only executed tests in the tier gate total' {
    Mock -CommandName Invoke-Pester -MockWith {
      [PSCustomObject]@{
        Result = 'Passed'
        FailedBlocksCount = 0
        FailedContainersCount = 0
        Containers = @([PSCustomObject]@{Result='Passed';ErrorRecord=@();Item='synthetic-container'})
        PassedCount  = 1
        FailedCount  = 0
        SkippedCount = 0
        NotRunCount  = 2
        TotalCount   = 3
        Duration     = [TimeSpan]::Zero
      }
    }

    $moduleRoot = Join-Path $script:tempRoot 'filtered-count-module'
    New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null

    $result = Invoke-PSModulePesterTests `
      -ModuleRoot $moduleRoot `
      -Tier 'Alpha' `
      -OutputPath (Join-Path $script:tempRoot 'filtered-count-out.xml') `
      -CoverageOutputPath (Join-Path $script:tempRoot 'filtered-count-cov.xml') `
      -SkipTestResult

    $result.TotalCount | Should -Be 1
    $result.GatePass | Should -BeTrue
  }

  It 'retains runner helpers when a test reload removes the owning module' {
    $runnerModuleName = 'ATAP.BuildTooling.PesterRunner.IsolationTest'
    $runnerModule = New-Module -Name $runnerModuleName -ArgumentList $functionPath -ScriptBlock {
      param([string]$RunnerFunctionPath)

      . $RunnerFunctionPath
      Export-ModuleMember -Function Invoke-PSModulePesterTests
    }
    Import-Module $runnerModule -Force

    try {
      Mock -CommandName Invoke-Pester -ModuleName $runnerModuleName -MockWith {
        Remove-Module 'ATAP.BuildTooling.PesterRunner.IsolationTest' -Force
        $passedTest = [PSCustomObject]@{
          Name      = 'survives module reload'
          Result    = 'Passed'
          Duration  = [TimeSpan]::FromMilliseconds(5)
          Path      = 'C:\tests\RunnerIsolation.Tests.ps1'
        }
        [PSCustomObject]@{
          Result = 'Passed'
          FailedBlocksCount = 0
          FailedContainersCount = 0
          Containers = @([PSCustomObject]@{Result='Passed';ErrorRecord=@();Item='synthetic-container'})
          PassedCount  = 1
          FailedCount  = 0
          SkippedCount = 0
          TotalCount   = 1
          Duration     = [TimeSpan]::Zero
          Tests        = @($passedTest)
        }
      }

      $moduleRoot = Join-Path $script:tempRoot 'module-reload-isolation'
      New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
      $out = Join-Path $script:tempRoot 'module-reload-isolation-out.xml'
      $cov = Join-Path $script:tempRoot 'module-reload-isolation-cov.xml'

      $result = & $runnerModule {
        param($ModuleRoot, $OutputPath, $CoverageOutputPath)

        Invoke-PSModulePesterTests `
          -ModuleRoot $ModuleRoot `
          -Tier 'Alpha' `
          -OutputPath $OutputPath `
          -CoverageOutputPath $CoverageOutputPath `
          -PesterOutputVerbosity 'None' `
          -PesterProgressInterval 1
      } $moduleRoot $out $cov

      $result.GatePass | Should -BeTrue
      $result.Passed | Should -Be 1
      Test-Path -LiteralPath $out | Should -BeTrue
      Get-Module $runnerModuleName | Should -BeNullOrEmpty
    } finally {
      Remove-Module $runnerModuleName -Force -ErrorAction SilentlyContinue
    }
  }

  It 'restores Get-SecretATAP after a test installs a global double' {
    $originalCommand = ${function:global:Get-SecretATAP}
    $hadOriginalFunction = $null -ne $originalCommand
    ${function:global:Get-SecretATAP} = { 'original-secret-resolver' }

    try {
      Mock -CommandName Invoke-Pester -MockWith {
        ${function:global:Get-SecretATAP} = { 'leaked-test-double' }
        [PSCustomObject]@{
          Result = 'Passed'
          FailedBlocksCount = 0
          FailedContainersCount = 0
          Containers = @([PSCustomObject]@{Result='Passed';ErrorRecord=@();Item='synthetic-container'})
          PassedCount  = 1
          FailedCount  = 0
          SkippedCount = 0
          TotalCount   = 1
          Duration     = [TimeSpan]::Zero
          Tests        = @()
        }
      }

      $moduleRoot = Join-Path $script:tempRoot 'secret-resolver-isolation'
      New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
      $result = Invoke-PSModulePesterTests `
        -ModuleRoot $moduleRoot `
        -Tier 'Alpha' `
        -OutputPath (Join-Path $script:tempRoot 'secret-resolver-isolation-out.xml') `
        -CoverageOutputPath (Join-Path $script:tempRoot 'secret-resolver-isolation-cov.xml') `
        -SkipTestResult

      $result.GatePass | Should -BeTrue
      (& global:Get-SecretATAP) | Should -Be 'original-secret-resolver'
    } finally {
      if ($hadOriginalFunction) {
        ${function:global:Get-SecretATAP} = $originalCommand
      } else {
        ${function:global:Get-SecretATAP} = $null
      }
    }
  }
}

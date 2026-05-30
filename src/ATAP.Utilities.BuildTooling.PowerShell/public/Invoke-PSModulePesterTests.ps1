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

.PARAMETER PesterProgressInterval
When PesterOutputVerbosity is None, writes compact progress lines after this
many completed tests. Defaults to 20; set to 0 to disable.

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

function Get-PSModulePesterBlockTestCount {
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline)]
    $Block
  )

  process {
    if ($null -eq $Block) {
      return 0
    }

    if ($Block.PSObject.Properties.Name -contains 'ShouldRun' -and -not $Block.ShouldRun) {
      return 0
    }

    $count = 0
    foreach ($test in @($Block.Tests)) {
      if ($null -eq $test) {
        continue
      }

      if ($test.PSObject.Properties.Name -contains 'ShouldRun' -and -not $test.ShouldRun) {
        continue
      }

      $count++
    }

    foreach ($child in @($Block.Blocks)) {
      $count += Get-PSModulePesterBlockTestCount -Block $child
    }

    return $count
  }
}

function New-PSModulePesterProgressPlugin {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$Interval,

    [string]$FunctionName = 'Invoke-PSModulePesterTests',

    [scriptblock]$WriteLine
  )

  if (-not $WriteLine) {
    $WriteLine = {
      param([string]$Line)
      [Console]::Out.WriteLine($Line)
    }
  }

  $state = [PSCustomObject]@{
    Started   = 0
    Completed = 0
    Interval  = $Interval
    Total     = 0
    Stopwatch = [Diagnostics.Stopwatch]::StartNew()
  }
  $countBlockTests = ${function:Get-PSModulePesterBlockTestCount}
  $getTestName = {
    param($Test)

    if ($Test -and -not [string]::IsNullOrWhiteSpace($Test.Name)) {
      return (([string]$Test.Name) -replace '\s+', ' ')
    }

    return '<unknown>'
  }

  $writeProgressLine = {
    param([string]$Message)

    try {
      & $WriteLine "Important [$FunctionName] $Message"
    } catch {
      # Progress logging must never affect the test gate.
    }
  }.GetNewClosure()

  [PSCustomObject]@{
    Name                    = 'ATAP.Utilities.BuildTooling.PowerShell.PesterProgress'
    DiscoveryStart          = {
      param($Context)

      $null = & {
        $state.Stopwatch.Restart()
        $containerCount = @($Context.BlockContainers).Count
        & $writeProgressLine "Pester discovery started for $containerCount test container(s)."
      }
    }.GetNewClosure()
    DiscoveryEnd            = {
      param($Context)

      $null = & {
        $total = 0
        foreach ($block in @($Context.BlockContainers)) {
          $total += & $countBlockTests -Block $block
        }

        $state.Total = $total
        $duration = if ($Context.Duration) { $Context.Duration } else { $state.Stopwatch.Elapsed }
        $elapsedText = $duration.ToString('hh\:mm\:ss')
        & $writeProgressLine "Pester discovery completed: $total test(s) discovered in $elapsedText; reporting every $($state.Interval) completed test(s)."
      }
    }.GetNewClosure()
    EachTestSetupStart      = {
      param($Context)

      $null = & {
        $null = $state.Started++
        if ((($state.Started - 1) % $Interval) -ne 0) {
          return
        }

        $testName = & $getTestName $Context.Test
        $totalText = if ($state.Total -gt 0) { "/$($state.Total)" } else { '' }
        $elapsedText = $state.Stopwatch.Elapsed.ToString('hh\:mm\:ss')
        & $writeProgressLine "Pester current test: $($state.Started)$totalText started after $elapsedText ($testName)."
      }
    }.GetNewClosure()
    EachTestTeardownEnd     = {
      param($Context)

      $null = & {
        $null = $state.Completed++
        if (($state.Completed % $Interval) -ne 0) {
          return
        }

        $lastTestName = & $getTestName $Context.Test

        $totalText = if ($state.Total -gt 0) { "/$($state.Total)" } else { '' }
        $elapsedText = $state.Stopwatch.Elapsed.ToString('hh\:mm\:ss')
        & $writeProgressLine "Pester progress: $($state.Completed)$totalText test(s) completed in $elapsedText (last: $lastTestName)."
      }
    }.GetNewClosure()
    PSTypeName              = 'Plugin'
  }
}

function Push-PSModulePesterAdditionalPlugin {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    $Plugin
  )

  $pesterModule = Get-Module Pester | Select-Object -First 1
  if (-not $pesterModule) {
    return $null
  }

  $snapshot = & $pesterModule {
    $variable = Get-Variable -Name additionalPlugins -Scope Script -ErrorAction SilentlyContinue
    [PSCustomObject]@{
      Exists = $null -ne $variable
      Value  = if ($null -ne $variable) { @($script:additionalPlugins) } else { @() }
    }
  }

  & $pesterModule {
    param($Plugin)
    $script:additionalPlugins = @($script:additionalPlugins) + $Plugin
  } $Plugin

  [PSCustomObject]@{
    Module   = $pesterModule
    Snapshot = $snapshot
  }
}

function Restore-PSModulePesterAdditionalPlugin {
  [CmdletBinding()]
  param(
    $State
  )

  if (-not $State -or -not $State.Module -or -not $State.Snapshot) {
    return
  }

  & $State.Module {
    param($Snapshot)

    if ($Snapshot.Exists) {
      $script:additionalPlugins = @($Snapshot.Value)
    } else {
      Remove-Variable -Name additionalPlugins -Scope Script -ErrorAction SilentlyContinue
    }
  } $State.Snapshot
}

function Get-PSModulePesterTestName {
  [CmdletBinding()]
  param($Test)

  foreach ($propertyName in @('ExpandedName', 'Name')) {
    if ($Test -and $Test.PSObject.Properties.Name -contains $propertyName) {
      $value = [string]$Test.$propertyName
      if (-not [string]::IsNullOrWhiteSpace($value)) {
        return ($value -replace '\s+', ' ').Trim()
      }
    }
  }

  return '<unknown>'
}

function Get-PSModulePesterFailureMessage {
  [CmdletBinding()]
  param($Test)

  if (-not $Test -or -not ($Test.PSObject.Properties.Name -contains 'ErrorRecord') -or -not $Test.ErrorRecord) {
    return ''
  }

  $messages = foreach ($errorRecord in @($Test.ErrorRecord)) {
    if ($errorRecord -and $errorRecord.Exception -and -not [string]::IsNullOrWhiteSpace($errorRecord.Exception.Message)) {
      ([string]$errorRecord.Exception.Message -replace '\r?\n', ' ').Trim()
    }
  }

  return (($messages | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ' | ')
}

function Get-PSModulePesterTestContainer {
  [CmdletBinding()]
  param($Test)

  if ($Test -and ($Test.PSObject.Properties.Name -contains 'Block') -and $Test.Block -and
    ($Test.Block.PSObject.Properties.Name -contains 'Container') -and $Test.Block.Container -and
    ($Test.Block.Container.PSObject.Properties.Name -contains 'Item') -and $Test.Block.Container.Item) {
    try {
      return Split-Path -Leaf ([string]$Test.Block.Container.Item)
    } catch {
      return [string]$Test.Block.Container.Item
    }
  }

  if ($Test -and ($Test.PSObject.Properties.Name -contains 'Path') -and $Test.Path) {
    return ([string](@($Test.Path)[0]) -replace '\s+', ' ').Trim()
  }

  return '<unknown>'
}

function Get-PSModulePesterFailedTestSummary {
  [CmdletBinding()]
  param(
    $PesterResult,

    [ValidateRange(1, [int]::MaxValue)]
    [int]$Maximum = 50
  )

  if ($PesterResult -and ($PesterResult.PSObject.Properties.Name -contains 'Failed') -and $PesterResult.Failed) {
    return @(
      foreach ($test in @($PesterResult.Failed | Select-Object -First $Maximum)) {
        [PSCustomObject]@{
          Container = Get-PSModulePesterTestContainer -Test $test
          Name      = Get-PSModulePesterTestName -Test $test
          Message   = Get-PSModulePesterFailureMessage -Test $test
        }
      }
    )
  }

  $failures = [System.Collections.Generic.List[object]]::new()
  $walkBlock = {
    param($Block, [string]$Container)

    if ($null -eq $Block -or $failures.Count -ge $Maximum) {
      return
    }

    foreach ($test in @($Block.Tests)) {
      if ($failures.Count -ge $Maximum) {
        return
      }

      if ($test -and ($test.PSObject.Properties.Name -contains 'Result') -and $test.Result -eq 'Failed') {
        $failures.Add([PSCustomObject]@{
            Container = $Container
            Name      = Get-PSModulePesterTestName -Test $test
            Message   = Get-PSModulePesterFailureMessage -Test $test
          }) | Out-Null
      }
    }

    foreach ($child in @($Block.Blocks)) {
      & $walkBlock $child $Container
    }
  }

  foreach ($container in @($PesterResult.Containers)) {
    $containerName = '<unknown>'
    if ($container -and $container.PSObject.Properties.Name -contains 'Item' -and $container.Item) {
      try {
        $containerName = Split-Path -Leaf ([string]$container.Item)
      } catch {
        $containerName = [string]$container.Item
      }
    }

    foreach ($block in @($container.Blocks)) {
      & $walkBlock $block $containerName
    }
  }

  return $failures.ToArray()
}

function Set-PSModulePesterXmlAttribute {
  param(
    [Parameter(Mandatory)] [System.Xml.XmlElement]$Element,
    [Parameter(Mandatory)] [string]$Name,
    [AllowNull()] $Value
  )

  $Element.SetAttribute($Name, [string]$Value)
}

function Write-PSModulePesterJUnitResult {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    $PesterResult,

    [Parameter(Mandatory)]
    [string]$OutputPath
  )

  $tests = @($PesterResult.Tests)
  $total = [int]$PesterResult.TotalCount
  $failed = [int]$PesterResult.FailedCount
  $skipped = [int]$PesterResult.SkippedCount
  $duration = if ($PesterResult.Duration) { [double]$PesterResult.Duration.TotalSeconds } else { 0 }

  $doc = [System.Xml.XmlDocument]::new()
  $null = $doc.AppendChild($doc.CreateXmlDeclaration('1.0', 'utf-8', $null))
  $root = $doc.CreateElement('testsuites')
  Set-PSModulePesterXmlAttribute -Element $root -Name 'name' -Value 'Pester'
  Set-PSModulePesterXmlAttribute -Element $root -Name 'tests' -Value $total
  Set-PSModulePesterXmlAttribute -Element $root -Name 'failures' -Value $failed
  Set-PSModulePesterXmlAttribute -Element $root -Name 'errors' -Value 0
  Set-PSModulePesterXmlAttribute -Element $root -Name 'skipped' -Value $skipped
  Set-PSModulePesterXmlAttribute -Element $root -Name 'time' -Value ('{0:n3}' -f $duration)
  $null = $doc.AppendChild($root)

  $suite = $doc.CreateElement('testsuite')
  Set-PSModulePesterXmlAttribute -Element $suite -Name 'name' -Value 'Pester'
  Set-PSModulePesterXmlAttribute -Element $suite -Name 'tests' -Value $total
  Set-PSModulePesterXmlAttribute -Element $suite -Name 'failures' -Value $failed
  Set-PSModulePesterXmlAttribute -Element $suite -Name 'errors' -Value 0
  Set-PSModulePesterXmlAttribute -Element $suite -Name 'skipped' -Value $skipped
  Set-PSModulePesterXmlAttribute -Element $suite -Name 'time' -Value ('{0:n3}' -f $duration)
  $null = $root.AppendChild($suite)

  foreach ($test in $tests) {
    $case = $doc.CreateElement('testcase')
    $testName = Get-PSModulePesterTestName -Test $test
    $container = Get-PSModulePesterTestContainer -Test $test
    $testDuration = if ($test.Duration) { [double]$test.Duration.TotalSeconds } else { 0 }

    Set-PSModulePesterXmlAttribute -Element $case -Name 'name' -Value $testName
    Set-PSModulePesterXmlAttribute -Element $case -Name 'classname' -Value $container
    Set-PSModulePesterXmlAttribute -Element $case -Name 'status' -Value $test.Result
    Set-PSModulePesterXmlAttribute -Element $case -Name 'time' -Value ('{0:n3}' -f $testDuration)

    if ($test.Result -eq 'Failed') {
      $failure = $doc.CreateElement('failure')
      $message = Get-PSModulePesterFailureMessage -Test $test
      Set-PSModulePesterXmlAttribute -Element $failure -Name 'message' -Value $message
      $failure.InnerText = $message
      $null = $case.AppendChild($failure)
    } elseif ($test.Result -in @('Skipped', 'NotRun')) {
      $skippedElement = $doc.CreateElement('skipped')
      $null = $case.AppendChild($skippedElement)
    }

    $null = $suite.AppendChild($case)
  }

  $outputDirectory = Split-Path -Path $OutputPath -Parent
  if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
  }
  $doc.Save($OutputPath)
}

function Select-PSModulePesterRunResult {
  [CmdletBinding()]
  param(
    [AllowNull()]
    [object[]]$InvocationOutput
  )

  $items = @($InvocationOutput)
  for ($i = $items.Count - 1; $i -ge 0; $i--) {
    $item = $items[$i]
    if (Test-PSModulePesterRunResult -InputObject $item) {
      return $item
    }
  }

  return $null
}

function Test-PSModulePesterRunResult {
  [CmdletBinding()]
  param(
    [AllowNull()]
    [object]$InputObject
  )

  if ($null -eq $InputObject) {
    return $false
  }

  $properties = @($InputObject.PSObject.Properties.Name)
  return ($properties -contains 'PassedCount' -and $properties -contains 'FailedCount' -and $properties -contains 'TotalCount')
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
    [string]$PesterOutputVerbosity = 'Normal',

    [ValidateRange(0, [int]::MaxValue)]
    [int]$PesterProgressInterval = 20
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
        # A small number of tests are still useful locally but have proven
        # host-sensitive under the BuildMaster service account while Pester
        # output streams are suppressed.
        $excludeTag += 'BuildTranscriptNoise'
        $excludeTag += 'PromotedModuleHostSensitive'
      }

      $coveragePaths = @()
      $publicDir = Join-Path $ModuleRoot 'public'
      $privateDir = Join-Path $ModuleRoot 'private'
      if (Test-Path -Path $publicDir) { $coveragePaths += $publicDir }
      if (Test-Path -Path $privateDir) { $coveragePaths += $privateDir }

      # Pester's native XML export can query host runtime data that is not
      # available under the BuildMaster service account. Keep PassThru as the
      # source of truth and write the JUnit-style artifact ourselves below.
      $delegateSkipTestResult = $true

      $cfg = New-PSModulePesterConfiguration `
        -TestPaths $TestPaths `
        -IncludeTag $filter.IncludeTag `
        -ExcludeTag $excludeTag `
        -OutputPath $OutputPath `
        -CoverageOutputPath $CoverageOutputPath `
        -CoveragePaths $coveragePaths `
        -SkipTestResult:$delegateSkipTestResult `
        -SkipCodeCoverage:$SkipCodeCoverage `
        -PesterOutputVerbosity $PesterOutputVerbosity

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Running Invoke-Pester for tier $Tier (IncludeTag=$($filter.IncludeTag -join ',') ExcludeTag=$($filter.ExcludeTag -join ','))"

      $result = $null
      if ($PSCmdlet.ShouldProcess("$TestPaths", 'Invoke-Pester')) {
        if ($PesterOutputVerbosity -eq 'None') {
          # BuildMaster summary logging comes from this wrapper. When Pester's
          # own output is disabled, suppress incidental streams emitted by
          # tests that intentionally exercise warning/error paths.
          $progressPluginState = $null
          if ($PesterProgressInterval -gt 0) {
            $progressPlugin = New-PSModulePesterProgressPlugin -Interval $PesterProgressInterval -FunctionName $fn
            $progressPluginState = Push-PSModulePesterAdditionalPlugin -Plugin $progressPlugin
          }

          try {
            Invoke-Pester -Configuration $cfg 2>$null 3>$null 4>$null 5>$null 6>$null | ForEach-Object {
              if (Test-PSModulePesterRunResult -InputObject $_) {
                $result = $_
              }
            }
          } finally {
            Restore-PSModulePesterAdditionalPlugin -State $progressPluginState
          }
        } else {
          Invoke-Pester -Configuration $cfg | ForEach-Object {
            if (Test-PSModulePesterRunResult -InputObject $_) {
              $result = $_
            }
          }
        }
      }

      $passed = if ($result) { [int]$result.PassedCount } else { 0 }
      $failed = if ($result) { [int]$result.FailedCount } else { 0 }
      $skipped = if ($result) { [int]$result.SkippedCount } else { 0 }
      $total = if ($result) { [int]$result.TotalCount } else { 0 }
      $duration = if ($result -and $result.Duration) { $result.Duration } else { [TimeSpan]::Zero }

      $gatePass = ($failed -eq 0)
      if (-not $SkipTestResult -and $result) {
        Write-PSModulePesterJUnitResult -PesterResult $result -OutputPath $OutputPath
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Pester test result artifact: '$OutputPath'"
      }

      if (-not $gatePass) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Pester gate FAILED: $failed failing test(s) of $total"
        $failedTests = Get-PSModulePesterFailedTestSummary -PesterResult $result -Maximum 50
        foreach ($failedTest in @($failedTests)) {
          $messageSuffix = if (-not [string]::IsNullOrWhiteSpace($failedTest.Message)) { " -- $($failedTest.Message)" } else { '' }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failing test: $($failedTest.Container) :: $($failedTest.Name)$messageSuffix"
        }

        if ($failed -gt @($failedTests).Count -and @($failedTests).Count -gt 0) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failing test list truncated at $(@($failedTests).Count) of $failed; see '$OutputPath' for the complete per-test results."
        } elseif (-not $SkipTestResult -and @($failedTests).Count -eq 0) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "No failing-test detail was available from the Pester result object; see '$OutputPath' for the complete per-test results."
        }
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

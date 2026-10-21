#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

BeforeAll {
  $moduleRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  . (Join-Path $moduleRoot 'public/Invoke-PSModulePesterTests.ps1')
  $preamblePath = Join-Path $moduleRoot 'module.preamble.ps1'

  function Invoke-PesterInitializationProbe {
    param([string]$PreloadVersion)
    # Exercise the package's actual initialization statements, excluding child proxies.
    $child = @'
$ErrorActionPreference = 'Stop'
if ('PRELOAD') { Import-Module Pester -RequiredVersion 'PRELOAD' -ErrorAction Stop }
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile('PREAMBLE', [ref]$tokens, [ref]$errors)
$initialization = ($ast.EndBlock.Statements | Select-Object -First 3 | ForEach-Object { $_.Extent.Text }) -join [Environment]::NewLine
try {
  & ([scriptblock]::Create($initialization))
  [pscustomobject]@{ Version = (Get-Module Pester).Version.ToString(); Error = $null } | ConvertTo-Json -Compress
} catch {
  [pscustomobject]@{ Version = (Get-Module Pester).Version.ToString(); Error = $_.Exception.Message } | ConvertTo-Json -Compress
}
'@
    $child = $child.Replace('PRELOAD', $PreloadVersion).Replace('PREAMBLE', $preamblePath.Replace("'", "''"))
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = (Get-Process -Id $PID).Path
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.ArgumentList.Add('-EncodedCommand')
    $start.ArgumentList.Add([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($child)))
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
      [void]$process.Start()
      $stdout = $process.StandardOutput.ReadToEndAsync()
      $stderr = $process.StandardError.ReadToEndAsync()
      $process.WaitForExit()
      $output = $stdout.GetAwaiter().GetResult()
      $errorOutput = $stderr.GetAwaiter().GetResult()
      if ($process.ExitCode -ne 0) { throw $errorOutput }
      $output | ConvertFrom-Json
    } finally {
      $process.Dispose()
    }
  }
}

Describe 'Pester execution version selection' {
  BeforeEach {
    $script:available = @([pscustomobject]@{ Version = [version]'6.2.0'; Path = 'C:\PesterFixture\6.2.0\Pester.psd1' })
    $script:runResult = [pscustomobject]@{
      PassedCount = 1; FailedCount = 0; SkippedCount = 0; TotalCount = 1
      Duration = [TimeSpan]::Zero
      Tests = @([pscustomobject]@{ Name = 'fixture'; Result = 'Passed'; Duration = [TimeSpan]::Zero })
    }
    $script:configuration = $null
    Mock Write-PSFMessage {}
    Mock Get-Module { $script:available } -ParameterFilter { $ListAvailable -and $Name -eq 'Pester' }
    Mock Import-Module {} -ParameterFilter { $Name -like 'C:\PesterFixture\*' }
    Mock Invoke-Pester {
      param($Configuration)
      $script:configuration = $Configuration
      $script:runResult
    }
    $fixtureRoot = Join-Path $TestDrive 'module'
    [void][IO.Directory]::CreateDirectory($fixtureRoot)
    $runParameters = @{
      ModuleRoot = $fixtureRoot; Tier = 'Alpha'; PesterProgressInterval = 0
      OutputPath = (Join-Path $TestDrive 'result.xml')
      CoverageOutputPath = (Join-Path $TestDrive 'coverage.xml')
    }
  }

  It 'rejects an installation that offers only major 5 without invoking tests' {
    $script:available = @([pscustomobject]@{ Version = [version]'5.7.1'; Path = 'C:\PesterFixture\5.7.1\Pester.psd1' })
    { Invoke-PSModulePesterTests @runParameters } | Should -Throw '*Pester 6.2.0 is not installed*'
    Should -Invoke Invoke-Pester -Times 0 -Exactly
    Should -Invoke Import-Module -Times 0 -Exactly
  }

  It 'imports exact 6.2.0 when it is the only available version' {
    (Invoke-PSModulePesterTests @runParameters).GatePass | Should -BeTrue
    Should -Invoke Import-Module -Times 1 -Exactly -ParameterFilter {
      $Name -eq 'C:\PesterFixture\6.2.0\Pester.psd1' -and $RequiredVersion -eq [version]'6.2.0'
    }
  }

  It 'selects 6.2.0 from mixed older and newer versions' {
    $script:available += [pscustomobject]@{ Version = [version]'5.7.1'; Path = 'C:\PesterFixture\5.7.1\Pester.psd1' }
    $script:available += [pscustomobject]@{ Version = [version]'6.3.0'; Path = 'C:\PesterFixture\6.3.0\Pester.psd1' }
    (Invoke-PSModulePesterTests @runParameters).GatePass | Should -BeTrue
    Should -Invoke Import-Module -Times 1 -Exactly -ParameterFilter { $RequiredVersion -eq [version]'6.2.0' }
  }

  It 'rejects an empty module inventory' {
    $script:available = @()
    { Invoke-PSModulePesterTests @runParameters } | Should -Throw '*Pester 6.2.0 is not installed*'
    Should -Invoke Invoke-Pester -Times 0 -Exactly
  }

  It 'preserves the Sprint intentional skip and its zero-test JUnit artifact' {
    $runParameters.Tier = 'Sprint'
    $result = Invoke-PSModulePesterTests @runParameters
    $result.GatePass | Should -BeTrue
    $result.Skipped | Should -BeTrue
    Should -Invoke Invoke-Pester -Times 0 -Exactly
    ([xml][IO.File]::ReadAllText($runParameters.OutputPath)).testsuites.tests | Should -Be '0'
  }

  It 'fails the gate when no tests match and emits failure evidence' {
    $script:runResult.PassedCount = 0
    $script:runResult.TotalCount = 0
    $script:runResult.Tests = @()
    (Invoke-PSModulePesterTests @runParameters).GatePass | Should -BeFalse
    [IO.File]::Exists([IO.Path]::ChangeExtension($runParameters.OutputPath, '.Failures.json')) | Should -BeTrue
  }

  It 'propagates a failing result to the gate and JUnit artifact' {
    $script:runResult.PassedCount = 0
    $script:runResult.FailedCount = 1
    $script:runResult.Tests[0].Result = 'Failed'
    $result = Invoke-PSModulePesterTests @runParameters
    $result.GatePass | Should -BeFalse
    $result.Failed | Should -Be 1
    ([xml][IO.File]::ReadAllText($runParameters.OutputPath)).testsuites.failures | Should -Be '1'
  }

  It 'preserves Unit filtering and JUnit/JaCoCo configuration' {
    [void](Invoke-PSModulePesterTests @runParameters)
    $script:configuration.Filter.Tag.Value | Should -Be @('Unit')
    $script:configuration.Filter.ExcludeTag.Value | Should -Contain 'Disabled'
    $script:configuration.CodeCoverage.Enabled.Value | Should -BeTrue
    $script:configuration.CodeCoverage.OutputFormat.Value | Should -Be 'JaCoCo'
    $script:configuration.CodeCoverage.OutputPath.Value | Should -Be $runParameters.CoverageOutputPath
    ([xml][IO.File]::ReadAllText($runParameters.OutputPath)).testsuites.tests | Should -Be '1'
  }
}

Describe 'Package Pester initialization in fresh profiled processes' {
  It 'pins Pester before any child dependency can initialize its configuration type' {
    $manifest = Import-PowerShellDataFile (Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.PowerShell.psd1')
    $manifest.RequiredModules[0].ModuleName | Should -Be 'Pester'
    $manifest.RequiredModules[0].RequiredVersion | Should -Be '6.2.0'
    $child = Import-PowerShellDataFile (Join-Path $moduleRoot '../ATAP.Utilities.BuildTooling.PesterScaffolding.PowerShell/ATAP.Utilities.BuildTooling.PesterScaffolding.PowerShell.psd1')
    ($child.RequiredModules | Where-Object ModuleName -eq 'Pester').ModuleVersion | Should -Be '6.2.0'
  }

  It 'loads exact 6.2.0 when no Pester type is present' {
    $result = Invoke-PesterInitializationProbe -PreloadVersion ''
    $result.Error | Should -BeNullOrEmpty
    $result.Version | Should -Be '6.2.0'
  }

  It 'accepts an already-loaded 6.2 configuration type' {
    $result = Invoke-PesterInitializationProbe -PreloadVersion '6.2.0'
    $result.Error | Should -BeNullOrEmpty
    $result.Version | Should -Be '6.2.0'
  }

  It 'rejects an already-loaded major-5 type with a fresh-process instruction' {
    $result = Invoke-PesterInitializationProbe -PreloadVersion '5.7.1'
    $result.Version | Should -Be '5.7.1'
    $result.Error | Should -BeLike '*requires Pester 6.2.0*Start a fresh profiled PowerShell process*'
  }
}


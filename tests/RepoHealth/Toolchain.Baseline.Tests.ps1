#Requires -Module Pester
BeforeAll {
  $script:repoRoot = (Resolve-Path -LiteralPath (Join-Path (Split-Path -Parent $PSCommandPath) '..\..')).Path
  $script:validator = Join-Path $script:repoRoot 'Build\Test-ToolchainBaseline.ps1'
  . $script:validator
  $script:fixtureRoot = Join-Path $script:repoRoot (Join-Path '_generated\Sprint0015\Task15.180\j\T01\fixtures' ([guid]::NewGuid().ToString('N')))
  [IO.Directory]::CreateDirectory($script:fixtureRoot) | Out-Null
  function New-Fixture {
    param([switch]$NoGlobalJson, [switch]$Malformed)
    $root = Join-Path $script:fixtureRoot ([guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory((Join-Path $root 'src\Probe')) | Out-Null
    [IO.File]::WriteAllText((Join-Path $root 'src\Probe\Probe.csproj'), '<Project Sdk="Microsoft.NET.Sdk" />')
    if (-not $NoGlobalJson) {
      $text = if ($Malformed) { '{ "sdk": ' } else { '{"sdk":{"version":"10.0.400","rollForward":"latestPatch","allowPrerelease":false}}' }
      [IO.File]::WriteAllText((Join-Path $root 'global.json'), $text)
    }
    (Resolve-Path -LiteralPath $root).Path
  }
  function New-ProbeResult { param([int]$ExitCode=0,[string]$StdOut='',[string]$StdErr='') [pscustomobject]@{ExitCode=$ExitCode;StdOut=$StdOut;StdErr=$StdErr} }
  function Set-GoodMock {
    param([string]$Root,[string]$Cib='')
    $script:mockRoot = $Root
    $script:mockSdkBase = Join-Path $Root 'sdk'
    $script:mockCib = $Cib
    Mock Invoke-ToolchainProcess {
      if ($WorkingDirectory -ne $script:mockRoot) { throw "Wrong working directory '$WorkingDirectory'." }
      switch -Regex ($ArgumentList -join ' ') {
        '^--list-sdks$' { New-ProbeResult -StdOut "10.0.400 [$script:mockSdkBase]"; break }
        '^--version$' { New-ProbeResult -StdOut '10.0.400'; break }
        '^msbuild -version -nologo$' { New-ProbeResult -StdOut '18.0.0'; break }
        '^nuget --version$' { New-ProbeResult -StdOut 'NuGet Command Line 7.0.0'; break }
        '^msbuild .*Deterministic' { New-ProbeResult -StdOut (@{Properties=@{Deterministic='true';ContinuousIntegrationBuild=$script:mockCib}}|ConvertTo-Json -Compress); break }
        default { throw "Unexpected arguments '$($ArgumentList -join ' ')'." }
      }
    }
  }
}
AfterAll {
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
  for ($attempt = 1; $attempt -le 20 -and (Test-Path -LiteralPath $script:fixtureRoot); $attempt++) {
    try { Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force -ErrorAction Stop }
    catch {
      if ($attempt -eq 20) { throw }
      Start-Sleep -Milliseconds 100
    }
  }
}
Describe 'Toolchain baseline hermetic contract' -Tag RepoHealth,Toolchain {
  BeforeEach { $script:fixture=New-Fixture; Set-GoodMock -Root $script:fixture }
  It 'runs every dotnet probe from the explicit repository root and never probes workloads' {
    $actual=Test-ToolchainBaseline -RepoRoot $script:fixture
    $actual.Success | Should -BeTrue -Because (($actual.Failures | ConvertTo-Json -Compress) -join '')
    Should -Invoke Invoke-ToolchainProcess -Times 5 -Exactly -ParameterFilter { $WorkingDirectory -eq $script:fixture }
    Should -Invoke Invoke-ToolchainProcess -Times 0 -ParameterFilter { ($ArgumentList -join ' ') -match 'workload' }
  }
  It 'reports SDK, SDK-owned MSBuild, NuGet, and deterministic facts' {
    $actual=Test-ToolchainBaseline -RepoRoot $script:fixture
    $actual.Facts.PinnedVersion | Should -BeExactly '10.0.400'
    $actual.Facts.SelectedVersion | Should -BeExactly '10.0.400'
    $actual.Facts.MSBuildVersion | Should -BeExactly '18.0.0'
    $actual.Facts.NuGetCliVersion | Should -BeExactly '7.0.0'
    $actual.Facts.Deterministic | Should -BeExactly 'true'
  }
  It 'requires ContinuousIntegrationBuild only when requested' {
    (Test-ToolchainBaseline -RepoRoot $script:fixture).FailureCodes | Should -Not -Contain 'ATAPTOOLCHAIN012'
    $required=Test-ToolchainBaseline -RepoRoot $script:fixture -RequireContinuousIntegrationBuild
    $required.FailureCodes | Should -Contain 'ATAPTOOLCHAIN012'
    Set-GoodMock -Root $script:fixture -Cib 'true'
    (Test-ToolchainBaseline -RepoRoot $script:fixture -RequireContinuousIntegrationBuild).Success | Should -BeTrue
  }
  It 'fails closed on missing or malformed global.json' {
    $missing=New-Fixture -NoGlobalJson; Set-GoodMock -Root $missing
    (Test-ToolchainBaseline -RepoRoot $missing).FailureCodes | Should -Contain 'ATAPTOOLCHAIN001'
    $bad=New-Fixture -Malformed; Set-GoodMock -Root $bad
    (Test-ToolchainBaseline -RepoRoot $bad).FailureCodes | Should -Contain 'ATAPTOOLCHAIN002'
  }
  It 'fails closed when the SDK NuGet CLI is unavailable' {
    Mock Invoke-ToolchainProcess {
      if (($ArgumentList -join ' ') -eq 'nuget --version') { New-ProbeResult -ExitCode 1 -StdErr 'unavailable' }
      elseif (($ArgumentList -join ' ') -eq '--list-sdks') { New-ProbeResult -StdOut "10.0.400 [$(Join-Path $script:fixture 'sdk')]" }
      elseif (($ArgumentList -join ' ') -eq '--version') { New-ProbeResult -StdOut '10.0.400' }
      elseif (($ArgumentList -join ' ') -eq 'msbuild -version -nologo') { New-ProbeResult -StdOut '18.0.0' }
      else { New-ProbeResult -StdOut (@{Properties=@{Deterministic='true';ContinuousIntegrationBuild=''}}|ConvertTo-Json -Compress) }
    }
    (Test-ToolchainBaseline -RepoRoot $script:fixture).FailureCodes | Should -Contain 'ATAPTOOLCHAIN013'
  }
}
Describe 'Toolchain validator source safety' -Tag RepoHealth,Toolchain {
  It 'has an async drain, required dual-purpose guard, and no caller or workload mutation' {
    $text=Get-Content -LiteralPath $script:validator -Raw
    $text | Should -Match 'StandardOutput\.ReadToEndAsync'
    $text | Should -Match 'StandardError\.ReadToEndAsync'
    $text | Should -Match 'InvocationName-ne''\.''-and\$MyInvocation\.InvocationName-ne''&'''
    $text | Should -Not -Match '(?m)^\s*\$ErrorActionPreference\s*='
    $text | Should -Not -Match 'global:Write-PSFMessage'
    $text | Should -Not -Match 'workload\s+list'
  }
  It 'uses a unique per-execution fixture beneath the assigned evidence path' {
    $script:fixtureRoot | Should -Match '_generated[\\/]Sprint0015[\\/]Task15\.180[\\/]j[\\/]T01[\\/]fixtures[\\/][0-9a-f]{32}$'
  }
}
Describe 'SDK version parsing' -Tag RepoHealth,Toolchain {
  It 'recognizes feature bands and prerelease versions' {
    (ConvertTo-SdkVersionInfo '10.0.409').FeatureBand | Should -Be 4
    (ConvertTo-SdkVersionInfo '10.0.100-preview.5').IsPrerelease | Should -BeTrue
  }
}

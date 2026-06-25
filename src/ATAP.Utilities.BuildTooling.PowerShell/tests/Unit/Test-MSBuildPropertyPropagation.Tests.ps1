#Requires -Version 7.0
# Pester 5+ tests for the 5-Tier MSBuild property propagation defined in
# Directory.Build.props (tasks 1.1-1 through 1.1-4 / T-32).
#
# Strategy:
#   Unit: structural checks — confirm the expected properties and targets
#         are present in Directory.Build.props without invoking the toolchain.
#   Integration: functional checks — invoke dotnet msbuild -getProperty against
#                a single representative project for each NBGV prerelease-label
#                variant and verify the resulting TargetProGetFeed and
#                CentralPackageVersionOverridesEnabled values.
#
# AI assisted using pesterTest.instructions.md as guidelines

BeforeAll {
  # Navigate from tests/Unit up four levels to the repo root.
  $script:repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
  $script:propsFile = Join-Path $script:repoRoot 'Directory.Build.props'

  # A simple StringConstants project — minimal dependencies, fast to evaluate.
  $script:probeProject = Join-Path $script:repoRoot `
    'src\ATAP.Console.Console01.StringConstants\ATAP.Console.Console01.StringConstants.csproj'

  # Helper: invoke dotnet msbuild -getProperty and return the trimmed stdout value.
  function script:Get-MSBuildProperty {
    param(
      [Parameter(Mandatory)][string] $ProjectPath,
      [Parameter(Mandatory)][string] $PropertyName,
      [string] $NBGVLabel = ''
    )
    $result = & dotnet msbuild $ProjectPath `
      "-getProperty:$PropertyName" `
      "-p:NBGV_PrereleaseLabel=$NBGVLabel" `
      '-nologo' 2>&1
    # dotnet msbuild writes warnings/errors to stdout in this mode.
    # The property value is the last non-empty, non-error line.
    $valueLines = $result | Where-Object { $_ -notmatch '^MSBUILD\s*:' -and $_.Trim() -ne '' }
    return ($valueLines | Select-Object -Last 1).Trim()
  }
}

Describe 'Directory.Build.props — structural checks (task 1.1-1 through 1.1-4)' -Tag 'Unit' {

  Context '1.1-1: PackageLifeCycleStage is sourced from NBGV_PrereleaseLabel' {
    It 'Directory.Build.props defines PackageLifeCycleStage from $(NBGV_PrereleaseLabel)' {
      $content = Get-Content $script:propsFile -Raw
      $content | Should -Match ([regex]::Escape('<PackageLifeCycleStage>$(NBGV_PrereleaseLabel)</PackageLifeCycleStage>'))
    }
  }

  Context '1.1-2: All five tier-to-feed mappings are declared' {
    $expectedMappings = @(
      @{ Feed = 'nuget-experimental' }
      @{ Feed = 'nuget-development' }
      @{ Feed = 'nuget-integration' }
      @{ Feed = 'nuget-qa' }
      @{ Feed = 'nuget-stable' }
    )

    It "Directory.Build.props declares TargetProGetFeed '<Feed>'" -TestCases $expectedMappings {
      param($Feed)
      $content = Get-Content $script:propsFile -Raw
      $content | Should -Match ([regex]::Escape("<TargetProGetFeed>$Feed</TargetProGetFeed>"))
    }
  }

  Context '1.1-3: Build-time validation target is present' {
    It 'ValidatePackageLifeCycleStage target is declared in Directory.Build.props' {
      $content = Get-Content $script:propsFile -Raw
      $content | Should -Match 'ValidatePackageLifeCycleStage'
    }

    It 'ValidatePackageLifeCycleStage fires BeforeTargets="Build"' {
      $content = Get-Content $script:propsFile -Raw
      $content | Should -Match 'BeforeTargets="Build"'
    }

    It 'ValidatePackageLifeCycleStage emits error code ATAP5TIER001' {
      $content = Get-Content $script:propsFile -Raw
      $content | Should -Match 'ATAP5TIER001'
    }
  }

  Context '1.1-4: CentralPackageVersionOverridesEnabled is declared false' {
    It 'Directory.Build.props sets CentralPackageVersionOverridesEnabled to false' {
      $content = Get-Content $script:propsFile -Raw
      $content | Should -Match ([regex]::Escape('<CentralPackageVersionOverridesEnabled>false</CentralPackageVersionOverridesEnabled>'))
    }
  }
}

Describe 'Directory.Build.props — TargetProGetFeed evaluation (task 1.1-2, Integration)' -Tag 'Integration', 'PromotedModuleHostSensitive' {

  BeforeAll {
    if (-not (Test-Path $script:probeProject)) {
      throw "Probe project not found: $script:probeProject"
    }
  }

  $tierCases = @(
    @{ Label = 'Sprint'; ExpectedFeed = 'nuget-experimental' }
    @{ Label = 'Alpha'; ExpectedFeed = 'nuget-development' }
    @{ Label = 'Beta'; ExpectedFeed = 'nuget-integration' }
    @{ Label = 'QA'; ExpectedFeed = 'nuget-qa' }
    @{ Label = ''; ExpectedFeed = 'nuget-stable' }
  )

  It "NBGV_PrereleaseLabel='<Label>' yields TargetProGetFeed '<ExpectedFeed>'" `
    -TestCases $tierCases {
    param($Label, $ExpectedFeed)
    $actual = Get-MSBuildProperty -ProjectPath $script:probeProject `
      -PropertyName 'TargetProGetFeed' -NBGVLabel $Label
    $actual | Should -BeExactly $ExpectedFeed
  }
}

Describe 'Directory.Build.props — CentralPackageVersionOverridesEnabled evaluation (task 1.1-4, Integration)' -Tag 'Integration', 'PromotedModuleHostSensitive' {

  BeforeAll {
    if (-not (Test-Path $script:probeProject)) {
      throw "Probe project not found: $script:probeProject"
    }
  }

  It 'CentralPackageVersionOverridesEnabled evaluates to false for a representative project' {
    $actual = Get-MSBuildProperty -ProjectPath $script:probeProject `
      -PropertyName 'CentralPackageVersionOverridesEnabled'
    $actual | Should -BeExactly 'false'
  }
}

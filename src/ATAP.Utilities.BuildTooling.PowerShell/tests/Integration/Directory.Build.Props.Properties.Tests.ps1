# tests/Integration/Directory.Build.Props.Properties.Tests.ps1
#
# Pester 5+ integration tests for the 5-Tier Software Production model MSBuild
# properties that must propagate to every csproj under src/ via
# Directory.Build.props:
#
#   * PackageLifeCycleStage            — derived from NBGV prerelease label
#       (Sprint | Alpha | Beta | QA | '' (stable))
#   * TargetProGetFeed                 — feed name per stage-to-feed mapping:
#       Sprint -> nuget-experimental, Alpha -> nuget-development,
#       Beta   -> nuget-integration, QA    -> nuget-qa,
#       ''     -> nuget-stable
#   * CentralPackageVersionOverridesEnabled — must evaluate to 'false'
#
# Mechanism: each csproj is queried with
#     dotnet msbuild <csproj> -getProperty:<Prop>
# which writes the evaluated value to stdout. This exercises the full MSBuild
# evaluation chain (Directory.Build.props -> NBGV import -> csproj).
#
# Tagged 'Integration' and '5Tier' so the CI tier-filter table can include
# or exclude them independently of unit tests.

#Requires -Module Pester

BeforeDiscovery {
  $script:srcRoot = Join-Path $PSScriptRoot '..\..\..' | Resolve-Path
  # Walk up: tests/Integration -> tests -> ATAP.Utilities.BuildTooling.PowerShell -> src
  # So $srcRoot points at .../src. Enumerate every csproj beneath it.
  $script:csprojFiles = Get-ChildItem -Path $script:srcRoot.Path -Recurse -Filter *.csproj -File |
    Where-Object {
      # Exclude build output directories; include everything else (tests included
      # per repo default — no precedent test file exempts them).
      $_.FullName -notmatch '\\(bin|obj)\\'
    } |
    Sort-Object FullName

  # Build the -ForEach test case table once per discovery.
  $script:csprojCases = @($script:csprojFiles | ForEach-Object {
      @{
        CsprojPath = $_.FullName
        CsprojName = $_.BaseName
      }
    })

  # Valid value sets per the 5-Tier spec.
  $script:validStages = @('Sprint', 'Alpha', 'Beta', 'QA', '')
  $script:stageToFeed = @{
    'Sprint' = 'nuget-experimental'
    'Alpha'  = 'nuget-development'
    'Beta'   = 'nuget-integration'
    'QA'     = 'nuget-qa'
    ''       = 'nuget-stable'
  }
  $script:validFeeds = @($script:stageToFeed.Values)
}

BeforeAll {
  # PSFramework logging shim, per repo CLAUDE.md conventions.
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param( [Parameter(ValueFromRemainingArguments = $true)] $rest )
    }
  }
  else {
    Import-Module PSFramework -ErrorAction SilentlyContinue
  }

  # Pester 5 scoping note: variables set in BeforeDiscovery do NOT automatically
  # survive into BeforeAll/It. Re-materialize everything the It blocks need.
  $script:validStages = @('Sprint', 'Alpha', 'Beta', 'QA', '')
  $script:stageToFeed = @{
    'Sprint' = 'nuget-experimental'
    'Alpha'  = 'nuget-development'
    'Beta'   = 'nuget-integration'
    'QA'     = 'nuget-qa'
    ''       = 'nuget-stable'
  }
  $script:validFeeds = @($script:stageToFeed.Values)

  function script:Get-EvaluatedMSBuildProperty {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory)][string] $CsprojPath,
      [Parameter(Mandatory)][string] $PropertyName
    )
    # dotnet 8+ supports -getProperty:<Name>; writes only the evaluated value
    # to stdout. Non-zero exit => evaluation failure — surface it.
    $stdout = & dotnet msbuild $CsprojPath "-getProperty:$PropertyName" 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "dotnet msbuild -getProperty:$PropertyName failed for '$CsprojPath' (exit $LASTEXITCODE): $stdout"
    }
    # -getProperty returns a single-line value (possibly empty) — trim trailing newline.
    return ([string]$stdout).Trim()
  }
}

Describe 'Directory.Build.props — PackageLifeCycleStage propagates to every csproj' -Tag 'Integration', '5Tier', 'PromotedModuleHostSensitive' {

  It "PackageLifeCycleStage is in the valid-stage set for <CsprojName>" -ForEach $script:csprojCases {
    param($CsprojPath, $CsprojName)
    $value = Get-EvaluatedMSBuildProperty -CsprojPath $CsprojPath -PropertyName 'PackageLifeCycleStage'
    # Per spec: value must be one of Sprint | Alpha | Beta | QA | '' (stable).
    # Empty string is allowed — it corresponds to a stable (main) branch.
    $script:validStages | Should -Contain $value -Because "csproj '$CsprojName' evaluated PackageLifeCycleStage='$value', which is not in the allowed 5-Tier stage set"
  }
}

Describe 'Directory.Build.props — TargetProGetFeed propagates and matches stage' -Tag 'Integration', '5Tier', 'PromotedModuleHostSensitive' {

  It "TargetProGetFeed matches the expected feed for PackageLifeCycleStage on <CsprojName>" -ForEach $script:csprojCases {
    param($CsprojPath, $CsprojName)
    $stage = Get-EvaluatedMSBuildProperty -CsprojPath $CsprojPath -PropertyName 'PackageLifeCycleStage'
    $feed  = Get-EvaluatedMSBuildProperty -CsprojPath $CsprojPath -PropertyName 'TargetProGetFeed'

    $script:validFeeds | Should -Contain $feed -Because "csproj '$CsprojName' evaluated TargetProGetFeed='$feed', which is not in the allowed 5-Tier feed set"

    $expectedFeed = $script:stageToFeed[$stage]
    $feed | Should -BeExactly $expectedFeed -Because "csproj '$CsprojName' has PackageLifeCycleStage='$stage', so TargetProGetFeed must be '$expectedFeed' per the 5-Tier stage->feed mapping"
  }
}

Describe 'Directory.Build.props — CentralPackageVersionOverridesEnabled is false' -Tag 'Integration', '5Tier', 'PromotedModuleHostSensitive' {

  It "CentralPackageVersionOverridesEnabled evaluates to 'false' on <CsprojName>" -ForEach $script:csprojCases {
    param($CsprojPath, $CsprojName)
    $value = Get-EvaluatedMSBuildProperty -CsprojPath $CsprojPath -PropertyName 'CentralPackageVersionOverridesEnabled'
    # MSBuild booleans are case-insensitive; compare normalized. Exact string
    # comparison against 'false' per spec — treat any other value (true,
    # empty, etc.) as a failure, since central package management must remain
    # locked.
    $value | Should -BeExactly 'false' -Because "csproj '$CsprojName' evaluated CentralPackageVersionOverridesEnabled='$value'; central package management must remain enforced (expected 'false')"
  }
}

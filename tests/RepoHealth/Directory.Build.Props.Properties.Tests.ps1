# tests/RepoHealth/Directory.Build.Props.Properties.Tests.ps1
#
# Pester 5+ repository health tests for the 5-Tier Software Production model
# MSBuild properties that must propagate to every csproj under src/ via
# Directory.Build.props:
#
#   * PackageLifeCycleStage            - derived from NBGV prerelease label
#       (Sprint | Alpha | Beta | QA | '' (stable))
#   * TargetProGetFeed                 - feed name per stage-to-feed mapping:
#       Sprint -> nuget-experimental, Alpha -> nuget-development,
#       Beta   -> nuget-integration, QA    -> nuget-qa,
#       ''     -> nuget-stable
#   * CentralPackageVersionOverridesEnabled - must evaluate to 'false'
#
# Mechanism: each csproj is queried with
#     dotnet msbuild <csproj> -getProperty:<Prop>
# which writes the evaluated value to stdout. This exercises the full MSBuild
# evaluation chain (Directory.Build.props -> NBGV import -> csproj).
#
# This file intentionally lives outside any PowerShell module's tests/ folder.
# Run it through Build/Invoke-RepoHealthGate.ps1 from C# build or CI flows.

#Requires -Module Pester

BeforeDiscovery {
  $testFilePath = if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $PSCommandPath
  } elseif ($MyInvocation.MyCommand.Path) {
    $MyInvocation.MyCommand.Path
  } else {
    throw 'Unable to resolve the RepoHealth test file path during Pester discovery.'
  }
  $testDirectory = Split-Path -Path $testFilePath -Parent
  $script:repoRoot = (Resolve-Path -Path (Join-Path $testDirectory '..\..')).Path
  $script:srcRoot = Join-Path $script:repoRoot 'src'
  $script:csprojFiles = Get-ChildItem -Path $script:srcRoot -Recurse -Filter *.csproj -File |
    Where-Object {
      $_.FullName -notmatch '\\(bin|obj)\\'
    } |
    Sort-Object FullName

  $script:csprojCases = @($script:csprojFiles | ForEach-Object {
      @{
        CsprojPath = $_.FullName
        CsprojName = $_.BaseName
      }
    })

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
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param( [Parameter(ValueFromRemainingArguments = $true)] $rest )
    }
  }
  else {
    Import-Module PSFramework -ErrorAction SilentlyContinue
  }

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

    $stdout = & dotnet msbuild $CsprojPath "-getProperty:$PropertyName" 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "dotnet msbuild -getProperty:$PropertyName failed for '$CsprojPath' (exit $LASTEXITCODE): $stdout"
    }

    return ([string]$stdout).Trim()
  }
}

Describe 'Directory.Build.props - PackageLifeCycleStage propagates to every csproj' -Tag 'RepoHealth', 'Integration', '5Tier' {

  It "PackageLifeCycleStage is in the valid-stage set for <CsprojName>" -ForEach $script:csprojCases {
    param($CsprojPath, $CsprojName)
    $value = Get-EvaluatedMSBuildProperty -CsprojPath $CsprojPath -PropertyName 'PackageLifeCycleStage'
    $script:validStages | Should -Contain $value -Because "csproj '$CsprojName' evaluated PackageLifeCycleStage='$value', which is not in the allowed 5-Tier stage set"
  }
}

Describe 'Directory.Build.props - TargetProGetFeed propagates and matches stage' -Tag 'RepoHealth', 'Integration', '5Tier' {

  It "TargetProGetFeed matches the expected feed for PackageLifeCycleStage on <CsprojName>" -ForEach $script:csprojCases {
    param($CsprojPath, $CsprojName)
    $stage = Get-EvaluatedMSBuildProperty -CsprojPath $CsprojPath -PropertyName 'PackageLifeCycleStage'
    $feed  = Get-EvaluatedMSBuildProperty -CsprojPath $CsprojPath -PropertyName 'TargetProGetFeed'

    $script:validFeeds | Should -Contain $feed -Because "csproj '$CsprojName' evaluated TargetProGetFeed='$feed', which is not in the allowed 5-Tier feed set"

    $expectedFeed = $script:stageToFeed[$stage]
    $feed | Should -BeExactly $expectedFeed -Because "csproj '$CsprojName' has PackageLifeCycleStage='$stage', so TargetProGetFeed must be '$expectedFeed' per the 5-Tier stage-to-feed mapping"
  }
}

Describe 'Directory.Build.props - CentralPackageVersionOverridesEnabled is false' -Tag 'RepoHealth', 'Integration', '5Tier' {

  It "CentralPackageVersionOverridesEnabled evaluates to 'false' on <CsprojName>" -ForEach $script:csprojCases {
    param($CsprojPath, $CsprojName)
    $value = Get-EvaluatedMSBuildProperty -CsprojPath $CsprojPath -PropertyName 'CentralPackageVersionOverridesEnabled'
    $value | Should -BeExactly 'false' -Because "csproj '$CsprojName' evaluated CentralPackageVersionOverridesEnabled='$value'; central package management must remain enforced (expected 'false')"
  }
}

#Requires -Module Pester

# Repository-wide evaluation checks for the ratified Task 15.180 lifecycle and
# Central Package Management contract. OpenHardwareMonitorLib is deliberately
# excluded from discovery and cannot block this gate.

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
  $script:openHardwareMonitorRoot = Join-Path $script:repoRoot 'OpenHardwareMonitorLib'
  $script:csprojFiles = @(Get-ChildItem -Path $script:srcRoot -Recurse -Filter *.csproj -File |
      Where-Object {
        $_.FullName -notmatch '\\(bin|obj|_generated)\\' -and
        -not $_.FullName.StartsWith($script:openHardwareMonitorRoot, [StringComparison]::OrdinalIgnoreCase)
      } |
      Sort-Object FullName)
  $script:csprojCases = @($script:csprojFiles | ForEach-Object {
      @{
        CsprojPath = $_.FullName
        CsprojName = $_.BaseName
      }
    })
}

BeforeAll {
  $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
  $script:canonicalToFeed = @{
    Experimental = 'nuget-experimental'
    Development = 'nuget-development'
    Integration = 'nuget-integration'
    QA = 'nuget-qa'
    Production = 'nuget-stable'
  }

  function script:Get-EvaluatedMSBuildProperty {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory)][string] $CsprojPath,
      [Parameter(Mandatory)][string] $PropertyName
    )

    $stdout = & dotnet msbuild $CsprojPath "-getProperty:$PropertyName" '-nologo' 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "dotnet msbuild -getProperty:$PropertyName failed for '$CsprojPath' (exit $LASTEXITCODE): $stdout"
    }

    return ([string]$stdout).Trim()
  }
}

Describe 'Task 15.180.e E07 repository project inventory' -Tag 'RepoHealth', 'Integration', '5Tier' {
  It 'discovers production source projects without OpenHardwareMonitorLib' {
    $inventory = @(Get-ChildItem -Path (Join-Path $script:repoRoot 'src') -Recurse -Filter *.csproj -File |
        Where-Object { $_.FullName -notmatch '\\(bin|obj|_generated)\\' })
    $inventory.Count | Should -BeGreaterThan 0
    @($inventory | Where-Object {
        $_.FullName -match '(^|[\\/])OpenHardwareMonitorLib([\\/]|$)'
      }).Count | Should -Be 0
  }
}

Describe 'Directory.Build.props lifecycle routing propagates to every included source project' -Tag 'RepoHealth', 'Integration', '5Tier' {
  It 'evaluates a canonical lifecycle stage and exact feed for <CsprojName>' -ForEach $script:csprojCases {
    param($CsprojPath, $CsprojName)

    $canonical = Get-EvaluatedMSBuildProperty -CsprojPath $CsprojPath -PropertyName 'CanonicalPackageLifeCycleStage'
    $feed = Get-EvaluatedMSBuildProperty -CsprojPath $CsprojPath -PropertyName 'TargetProGetFeed'

    $script:canonicalToFeed.Keys | Should -Contain $canonical -Because "'$CsprojName' must evaluate one ratified canonical lifecycle stage"
    $feed | Should -BeExactly $script:canonicalToFeed[$canonical] -Because "'$CsprojName' must route canonical stage '$canonical' to its exact physical feed"
  }
}

Describe 'Directory.Packages.props CPM default propagates to every included source project' -Tag 'RepoHealth', 'Integration', '5Tier' {
  It "evaluates CentralPackageVersionOverrideEnabled as 'false' for <CsprojName>" -ForEach $script:csprojCases {
    param($CsprojPath, $CsprojName)

    $value = Get-EvaluatedMSBuildProperty -CsprojPath $CsprojPath -PropertyName 'CentralPackageVersionOverrideEnabled'
    $value | Should -BeExactly 'false' -Because "'$CsprojName' must inherit the repository CPM default unless its package-SUT switch is explicitly enabled"
  }
}
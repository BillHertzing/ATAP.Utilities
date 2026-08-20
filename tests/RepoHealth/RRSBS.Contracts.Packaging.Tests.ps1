#Requires -Module Pester

BeforeAll {
  $testDirectory = Split-Path -Path $PSCommandPath -Parent
  $script:repoRoot = (Resolve-Path -Path (Join-Path $testDirectory '..\..')).Path
  $script:projectPath = Join-Path $script:repoRoot 'src\ATAP.Utilities.RRSBS.Contracts\ATAP.Utilities.RRSBS.Contracts.csproj'
  $script:versionPath = Join-Path $script:repoRoot 'src\ATAP.Utilities.RRSBS.Contracts\version.json'
  foreach ($name in @('ATAP_ARTIFACTS_ROOT', 'ATAP_ARTIFACTS_WORKTREE_ID', 'ATAP_ARTIFACTS_EXECUTION_ID', 'ATAP_ARTIFACTS_PATH')) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name, 'Process'))) {
      throw "RepoHealth requires process environment value $name."
    }
  }
  $script:artifactPropertyArguments = @(
    "-property:ATAPArtifactsRoot=$env:ATAP_ARTIFACTS_ROOT"
    "-property:ATAPArtifactsWorktreeId=$env:ATAP_ARTIFACTS_WORKTREE_ID"
    "-property:ATAPArtifactsExecutionId=$env:ATAP_ARTIFACTS_EXECUTION_ID"
    "-property:ArtifactsPath=$env:ATAP_ARTIFACTS_PATH"
  )

  function Get-EvaluatedMSBuildProperty {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory)][string] $ProjectPath,
      [Parameter(Mandatory)][string] $PropertyName
    )

    $output = & dotnet msbuild $ProjectPath "-getProperty:$PropertyName" @script:artifactPropertyArguments 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "dotnet msbuild -getProperty:$PropertyName failed for '$ProjectPath' (exit $LASTEXITCODE): $output"
    }

    return ([string]$output).Trim()
  }

  function Test-ContractsFrameworkContract {
    [CmdletBinding()]
    param(
      [AllowEmptyString()][string] $TargetFramework,
      [AllowEmptyString()][string] $TargetFrameworks
    )

    return $TargetFramework -eq '' -and $TargetFrameworks -ceq 'net10.0'
  }

  function Test-ContractsStableVersionContract {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory)][string] $Version,
      [AllowNull()][AllowEmptyString()][string] $Prerelease
    )

    if (-not [string]::IsNullOrEmpty($Prerelease)) {
      return $false
    }

    if ($Version -notmatch '^0\.1\.(?<Patch>\d+)$') {
      return $false
    }

    return [int]$Matches.Patch -ge 1
  }
}

Describe 'ATAP.Utilities.RRSBS.Contracts packaging metadata' -Tag 'RepoHealth', 'Integration', 'Packaging' {
  It 'evaluates exactly one target framework: net10.0' {
    $targetFramework = Get-EvaluatedMSBuildProperty -ProjectPath $script:projectPath -PropertyName 'TargetFramework'
    $targetFrameworks = Get-EvaluatedMSBuildProperty -ProjectPath $script:projectPath -PropertyName 'TargetFrameworks'

    Test-ContractsFrameworkContract -TargetFramework $targetFramework -TargetFrameworks $targetFrameworks | Should -BeTrue
    @($targetFrameworks -split ';') | Should -HaveCount 1
    $targetFrameworks | Should -Not -Match '(^|;)net8\.0(;|$)'
    $targetFrameworks | Should -Not -Match '(^|;)net9\.0(;|$)'
  }

  It 'uses the project-adjacent stable version 0.1.2' {
    $versionSource = Get-Content -LiteralPath $script:versionPath -Raw | ConvertFrom-Json
    $prerelease = if ($versionSource.version -match '-') { $versionSource.version.Substring($versionSource.version.IndexOf('-') + 1) } else { '' }
    $versionSource.version | Should -BeExactly '0.1.2'
    Test-ContractsStableVersionContract -Version $versionSource.version -Prerelease $prerelease | Should -BeTrue
    @($versionSource.publicReleaseRefSpec) | Should -Contain '.*'
  }

  It 'accepts stable production patch versions at 0.1.1 or higher' -TestCases @(
    @{ Version = '0.1.1' }
    @{ Version = '0.1.2' }
    @{ Version = '0.1.99' }
  ) {
    param($Version)

    Test-ContractsStableVersionContract -Version $Version -Prerelease '' | Should -BeTrue
  }

  It 'rejects close framework variants' -TestCases @(
    @{ TargetFramework = ''; TargetFrameworks = 'net8.0;net9.0;net10.0' }
    @{ TargetFramework = ''; TargetFrameworks = 'net9.0;net10.0' }
    @{ TargetFramework = 'net10.0'; TargetFrameworks = 'net10.0' }
    @{ TargetFramework = ''; TargetFrameworks = 'NET10.0' }
  ) {
    param($TargetFramework, $TargetFrameworks)

    Test-ContractsFrameworkContract -TargetFramework $TargetFramework -TargetFrameworks $TargetFrameworks | Should -BeFalse
  }

  It 'rejects close version variants' -TestCases @(
    @{ Version = '0.1.0'; Prerelease = $null }
    @{ Version = '0.2.0'; Prerelease = $null }
    @{ Version = '0.1.1-Sprint.1'; Prerelease = 'Sprint.1' }
    @{ Version = '0.1.1'; Prerelease = 'alpha' }
  ) {
    param($Version, $Prerelease)

    Test-ContractsStableVersionContract -Version $Version -Prerelease $Prerelease | Should -BeFalse
  }
}

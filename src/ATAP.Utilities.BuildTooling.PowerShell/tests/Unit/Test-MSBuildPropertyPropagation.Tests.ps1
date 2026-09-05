#Requires -Version 7.0
#Requires -Module Pester

# Focused Task 15.180.e E07 contract tests. These tests evaluate MSBuild
# properties and invoke only the validation target; they do not restore or build.

BeforeDiscovery {
  # These are repository-contract tests: they evaluate MSBuild properties from
  # Directory.Build.props and a probe .csproj. Those exist in a worktree, not inside an
  # extracted module package.
  #
  # The previous form was `(Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName`,
  # four fixed hops that assume src/<module>/tests/Unit. BuildMaster's promoted-module
  # gate runs these against the module extracted from the package, where the depth
  # differs, so a .Parent returned $null and .FullName on it threw "You cannot call a
  # method on a null-valued expression". That rejected build 4 of
  # ATAP.Utilities.BuildTooling.PowerShell 0.1.76 with 13 failures of 251.
  #
  # Walk up looking for the repository marker instead of counting hops, and skip rather
  # than crash when there is no repository - a repo-contract test has nothing to assert
  # against an extracted package.
  $script:discoveredRepoRoot = $null
  $probe = Get-Item -LiteralPath $PSScriptRoot -ErrorAction SilentlyContinue
  while ($probe) {
    if (Test-Path -LiteralPath (Join-Path $probe.FullName 'Directory.Build.props')) {
      $script:discoveredRepoRoot = $probe.FullName
      break
    }
    $probe = $probe.Parent
  }
  $script:repositoryContractTestsAvailable = [bool]$script:discoveredRepoRoot

  $script:lifecycleCases = @(
    @{ InputStage = 'sPrInT'; ExpectedNormalized = 'sprint'; ExpectedCanonical = 'Experimental'; ExpectedFeed = 'nuget-experimental' }
    @{ InputStage = 'EXPERIMENTAL'; ExpectedNormalized = 'experimental'; ExpectedCanonical = 'Experimental'; ExpectedFeed = 'nuget-experimental' }
    @{ InputStage = 'Alpha'; ExpectedNormalized = 'alpha'; ExpectedCanonical = 'Development'; ExpectedFeed = 'nuget-development' }
    @{ InputStage = 'development'; ExpectedNormalized = 'development'; ExpectedCanonical = 'Development'; ExpectedFeed = 'nuget-development' }
    @{ InputStage = 'BETA'; ExpectedNormalized = 'beta'; ExpectedCanonical = 'Integration'; ExpectedFeed = 'nuget-integration' }
    @{ InputStage = 'Integration'; ExpectedNormalized = 'integration'; ExpectedCanonical = 'Integration'; ExpectedFeed = 'nuget-integration' }
    @{ InputStage = 'qA'; ExpectedNormalized = 'qa'; ExpectedCanonical = 'QA'; ExpectedFeed = 'nuget-qa' }
    @{ InputStage = ''; ExpectedNormalized = ''; ExpectedCanonical = 'Production'; ExpectedFeed = 'nuget-stable' }
    @{ InputStage = 'sTaBlE'; ExpectedNormalized = 'stable'; ExpectedCanonical = 'Production'; ExpectedFeed = 'nuget-stable' }
    @{ InputStage = 'PRODUCTION'; ExpectedNormalized = 'production'; ExpectedCanonical = 'Production'; ExpectedFeed = 'nuget-stable' }
  )
  $script:unknownCases = @(
    @{ InputStage = 'Prodution' }
    @{ InputStage = 'Stable-' }
  )
  $script:stableRefs = @(
    @{ BuildingRef = 'refs/heads/main' }
    @{ BuildingRef = 'refs/heads/release/0.1.0' }
    @{ BuildingRef = 'refs/heads/137-Sprint-0015-work-items' }
    @{ BuildingRef = 'refs/heads/42-sprint-0009-work-items' }
  )
  $script:overrideAllowlist = @(
    'tests/ATAP.Utilities.Philote.Tests/ATAP.Utilities.Philote.Tests.csproj'
    'tests/ATAP.Utilities.Secrets.BitwardenSecretsManager.PackageSmoke.Tests/ATAP.Utilities.Secrets.BitwardenSecretsManager.PackageSmoke.Tests.csproj'
    'tests/ATAP.Utilities.Serializer.Interfaces.PackageSmoke.Tests/ATAP.Utilities.Serializer.Interfaces.PackageSmoke.Tests.csproj'
    'tests/ATAP.Utilities.StronglyTypedIDs.Tests/ATAP.Utilities.StronglyTypedIDs.Tests.csproj'
  )
}

BeforeAll {
  # Recomputed here rather than reused from BeforeDiscovery: Pester 5 runs discovery and
  # execution in separate scopes, so a $script: variable set at discovery is not visible
  # during the run phase.
  $script:repoRoot = $null
  $probe = Get-Item -LiteralPath $PSScriptRoot -ErrorAction SilentlyContinue
  while ($probe) {
    if (Test-Path -LiteralPath (Join-Path $probe.FullName 'Directory.Build.props')) {
      $script:repoRoot = $probe.FullName
      break
    }
    $probe = $probe.Parent
  }
  $script:propsFile = Join-Path $script:repoRoot 'Directory.Build.props'
  $script:packagesPropsFile = Join-Path $script:repoRoot 'Directory.Packages.props'
  $script:probeProject = Join-Path $script:repoRoot 'src\ATAP.Utilities.RRSBS.Contracts\ATAP.Utilities.RRSBS.Contracts.csproj'

  function script:Get-MSBuildProperty {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory)][string] $PropertyName,
      [AllowEmptyString()][string] $InputStage
    )

    $result = & dotnet msbuild $script:probeProject `
      "-getProperty:$PropertyName" `
      "-p:PackageLifeCycleStage=$InputStage" `
      '-p:NBGV_BuildingRef=refs/heads/137-Sprint-0015-work-items' `
      '-nologo' 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "MSBuild property evaluation failed for $PropertyName / '$InputStage': $($result -join [Environment]::NewLine)"
    }

    return ([string]($result | Select-Object -Last 1)).Trim()
  }

  function script:Invoke-LifecycleValidation {
    [CmdletBinding()]
    param(
      [AllowEmptyString()][string] $InputStage,
      [Parameter(Mandatory)][string] $BuildingRef
    )

    $output = & dotnet msbuild $script:probeProject `
      '-target:ValidatePackageLifeCycleStage' `
      "-p:PackageLifeCycleStage=$InputStage" `
      "-p:NBGV_BuildingRef=$BuildingRef" `
      '-nologo' 2>&1

    return [pscustomobject]@{
      ExitCode = $LASTEXITCODE
      Output = $output -join [Environment]::NewLine
    }
  }
}

Describe 'Task 15.180 lifecycle contract structure' -Tag 'Unit', '5Tier' -Skip:(-not $script:repositoryContractTestsAvailable) {
  BeforeAll {
    [xml] $script:propsXml = Get-Content -LiteralPath $script:propsFile -Raw
    [xml] $script:packagesPropsXml = Get-Content -LiteralPath $script:packagesPropsFile -Raw
  }

  It 'normalizes lifecycle input case-insensitively before canonical routing' {
    $content = Get-Content -LiteralPath $script:propsFile -Raw
    $content | Should -Match 'NormalizedPackageLifeCycleStage'
    $content | Should -Match 'ToLowerInvariant\(\)'
  }

  It 'declares exactly the five canonical feed mappings without an Otherwise fallback' {
    $mappingChoose = @($script:propsXml.SelectNodes('/Project/Choose[When/PropertyGroup/TargetProGetFeed]'))
    $mappingChoose.Count | Should -Be 1
    @($mappingChoose[0].When).Count | Should -Be 5
    $mappingChoose[0].Otherwise | Should -BeNullOrEmpty

    $feeds = @($mappingChoose[0].When | ForEach-Object { [string]$_.PropertyGroup.TargetProGetFeed })
    $expectedFeeds = @('nuget-experimental', 'nuget-development', 'nuget-integration', 'nuget-qa', 'nuget-stable')
    @(Compare-Object -ReferenceObject $expectedFeeds -DifferenceObject $feeds -SyncWindow 0).Count |
      Should -Be 0
  }

  It 'owns the CPM default only in Directory.Packages.props' {
    @($script:propsXml.SelectNodes('//CentralPackageVersionOverrideEnabled')).Count | Should -Be 0
    $defaultNodes = @($script:packagesPropsXml.SelectNodes('//CentralPackageVersionOverrideEnabled'))
    $defaultNodes.Count | Should -Be 1
    $defaultNodes[0].InnerText | Should -BeExactly 'false'
  }

  It 'declares the fail-closed ATAP5TIER001 validation target' {
    $target = @($script:propsXml.Project.Target | Where-Object { $_.Name -eq 'ValidatePackageLifeCycleStage' })
    $target.Count | Should -Be 1
    $target[0].BeforeTargets | Should -BeExactly 'Build'
    @($target[0].Error | Where-Object { $_.Code -eq 'ATAP5TIER001' }).Count | Should -Be 2
  }
}

Describe 'Task 15.180 lifecycle aliases and canonical feed routing' -Tag 'Integration', '5Tier' -Skip:(-not $script:repositoryContractTestsAvailable) {
  It "maps '<InputStage>' to <ExpectedCanonical> and <ExpectedFeed>" -TestCases $script:lifecycleCases {
    param($InputStage, $ExpectedNormalized, $ExpectedCanonical, $ExpectedFeed)

    Get-MSBuildProperty -PropertyName 'NormalizedPackageLifeCycleStage' -InputStage $InputStage |
      Should -BeExactly $ExpectedNormalized
    Get-MSBuildProperty -PropertyName 'CanonicalPackageLifeCycleStage' -InputStage $InputStage |
      Should -BeExactly $ExpectedCanonical
    Get-MSBuildProperty -PropertyName 'TargetProGetFeed' -InputStage $InputStage |
      Should -BeExactly $ExpectedFeed
  }

  It "rejects unknown lifecycle '<InputStage>' with ATAP5TIER001 and no feed" -TestCases $script:unknownCases {
    param($InputStage)

    Get-MSBuildProperty -PropertyName 'CanonicalPackageLifeCycleStage' -InputStage $InputStage |
      Should -BeNullOrEmpty
    Get-MSBuildProperty -PropertyName 'TargetProGetFeed' -InputStage $InputStage |
      Should -BeNullOrEmpty
    $result = Invoke-LifecycleValidation -InputStage $InputStage -BuildingRef 'refs/heads/137-Sprint-0015-work-items'
    $result.ExitCode | Should -Not -Be 0
    $result.Output | Should -Match 'ATAP5TIER001'
    $result.Output | Should -Not -Match 'nuget-stable'
  }
}

Describe 'Task 15.180 empty lifecycle branch safeguard' -Tag 'Integration', '5Tier' -Skip:(-not $script:repositoryContractTestsAvailable) {
  It "accepts empty lifecycle on stable-capable ref '<BuildingRef>'" -TestCases $script:stableRefs {
    param($BuildingRef)

    $result = Invoke-LifecycleValidation -InputStage '' -BuildingRef $BuildingRef
    $result.ExitCode | Should -Be 0 -Because $result.Output
    $result.Output | Should -Not -Match 'ATAP5TIER001'
  }

  It 'rejects empty lifecycle on an arbitrary feature branch' {
    $result = Invoke-LifecycleValidation -InputStage '' -BuildingRef 'refs/heads/feature/unapproved-stable-build'
    $result.ExitCode | Should -Not -Be 0
    $result.Output | Should -Match 'ATAP5TIER001'
  }
}

Describe 'Task 15.180 exact VersionOverride fixture allowlist' -Tag 'Unit', 'CPM' -Skip:(-not $script:repositoryContractTestsAvailable) {
  It 'contains exactly the four ratified conditional local enables' {
    $actual = @(Get-ChildItem -LiteralPath $script:repoRoot -Recurse -Filter *.csproj -File |
        Where-Object {
          $_.FullName -notmatch '\\(bin|obj|_generated|OpenHardwareMonitorLib)\\'
        } |
        ForEach-Object {
          [xml] $project = Get-Content -LiteralPath $_.FullName -Raw
          $enabled = @($project.SelectNodes('//CentralPackageVersionOverrideEnabled') | Where-Object {
              $_.InnerText -eq 'true'
            })
          if ($enabled.Count -gt 0) {
            $_.FullName.Substring($script:repoRoot.Length + 1).Replace('\', '/')
          }
        } |
        Sort-Object)

    $expected = @(
      'tests/ATAP.Utilities.Philote.Tests/ATAP.Utilities.Philote.Tests.csproj'
      'tests/ATAP.Utilities.Secrets.BitwardenSecretsManager.PackageSmoke.Tests/ATAP.Utilities.Secrets.BitwardenSecretsManager.PackageSmoke.Tests.csproj'
      'tests/ATAP.Utilities.Serializer.Interfaces.PackageSmoke.Tests/ATAP.Utilities.Serializer.Interfaces.PackageSmoke.Tests.csproj'
      'tests/ATAP.Utilities.StronglyTypedIDs.Tests/ATAP.Utilities.StronglyTypedIDs.Tests.csproj'
    ) | Sort-Object
    @(Compare-Object -ReferenceObject $expected -DifferenceObject $actual -SyncWindow 0).Count |
      Should -Be 0
  }

  It 'keeps OpenHardwareMonitorLib outside the production filter and override inventory' {
    $productionFilter = Get-Content -LiteralPath (Join-Path $script:repoRoot 'ATAP.Utilities.Production.slnf') -Raw
    $productionFilter | Should -Not -Match 'OpenHardwareMonitorLib'
    $script:overrideAllowlist | Should -Not -Match 'OpenHardwareMonitorLib'
  }
}
Describe 'Task 15.181 production and verification solution-filter contract' -Tag 'Unit', 'SolutionFilter' -Skip:(-not $script:repositoryContractTestsAvailable) {
  BeforeAll {
    $productionFilterPath = Join-Path $script:repoRoot 'ATAP.Utilities.Production.slnf'
    $verificationFilterPath = Join-Path $script:repoRoot 'ATAP.Utilities.ProductionVerification.slnf'
    $script:productionFilter = Get-Content -LiteralPath $productionFilterPath -Raw | ConvertFrom-Json
    $script:verificationFilter = Get-Content -LiteralPath $verificationFilterPath -Raw | ConvertFrom-Json
    $script:productionPaths = @($script:productionFilter.solution.projects | ForEach-Object { $_.Replace('\', '/') })
    $script:verificationPaths = @($script:verificationFilter.solution.projects | ForEach-Object { $_.Replace('\', '/') })
    $script:verificationOnlyPaths = @($script:verificationPaths | Where-Object { $_ -cnotin $script:productionPaths })
  }

  It 'uses the same solution and exact ratified ordered project universes' {
    $script:productionFilter.solution.path | Should -BeExactly 'ATAP.Utilities.sln'
    $script:verificationFilter.solution.path | Should -BeExactly 'ATAP.Utilities.sln'

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
      $productionHash = [Convert]::ToHexString($sha256.ComputeHash(
          [Text.Encoding]::UTF8.GetBytes(($script:productionPaths -join "`n")))).ToLowerInvariant()
      $verificationHash = [Convert]::ToHexString($sha256.ComputeHash(
          [Text.Encoding]::UTF8.GetBytes(($script:verificationPaths -join "`n")))).ToLowerInvariant()
    } finally {
      $sha256.Dispose()
    }

    $productionHash | Should -BeExactly '471dfd7ff0243573f1b4638d1464994613fc4df946992c6f18c80fe4af9d7994'
    $verificationHash | Should -BeExactly '214e3d14151ebae0b145d9f96bf1a6712dc5f4808618c29408321ea2f8a75230'
  }

  It 'keeps all 145 shipping projects and zero tests in production' {
    $script:productionPaths.Count | Should -Be 145
    @($script:productionPaths | Where-Object { $_ -match '(?i)^tests/' }).Count | Should -Be 0
  }

  It 'contains every production path plus exactly the 32 current tests in verification' {
    $script:verificationPaths.Count | Should -Be 177
    @($script:productionPaths | Where-Object { $_ -cnotin $script:verificationPaths }).Count | Should -Be 0
    $script:verificationOnlyPaths.Count | Should -Be 32
    @($script:verificationOnlyPaths | Where-Object { $_ -notmatch '(?i)^tests/' }).Count | Should -Be 0
    @($script:verificationPaths | Where-Object { $_ -cnotin @($script:productionPaths + $script:verificationOnlyPaths) }).Count |
      Should -Be 0
  }

  It 'excludes all deferred GenerateProgram projects from both filters' {
    @($script:productionPaths | Where-Object { $_ -match '(?i)GenerateProgram' }).Count | Should -Be 0
    @($script:verificationPaths | Where-Object { $_ -match '(?i)GenerateProgram' }).Count | Should -Be 0
  }

  It 'has no duplicate or case-variant project paths' {
    @($script:productionPaths | Sort-Object -Unique -CaseSensitive).Count | Should -Be $script:productionPaths.Count
    @($script:productionPaths | Sort-Object -Unique).Count | Should -Be $script:productionPaths.Count
    @($script:verificationPaths | Sort-Object -Unique -CaseSensitive).Count | Should -Be $script:verificationPaths.Count
    @($script:verificationPaths | Sort-Object -Unique).Count | Should -Be $script:verificationPaths.Count
  }

  It 'places both VersionOverride PackageSmoke fixtures only in verification' {
    $packageSmokeFixtures = @(
      'tests/ATAP.Utilities.Secrets.BitwardenSecretsManager.PackageSmoke.Tests/ATAP.Utilities.Secrets.BitwardenSecretsManager.PackageSmoke.Tests.csproj'
      'tests/ATAP.Utilities.Serializer.Interfaces.PackageSmoke.Tests/ATAP.Utilities.Serializer.Interfaces.PackageSmoke.Tests.csproj'
    )

    foreach ($fixture in $packageSmokeFixtures) {
      $script:verificationPaths | Should -Contain $fixture
      $script:productionPaths | Should -Not -Contain $fixture
    }
  }

  It 'keeps future ETW performance-test projects verification-only by excluding all tests from production' {
    $performanceTestPaths = @($script:verificationPaths | Where-Object {
        $_ -match '(?i)^tests/.+(performance|benchmark).+\.csproj$'
      })
    @($performanceTestPaths | Where-Object { $_ -cin $script:productionPaths }).Count | Should -Be 0
    @($script:productionPaths | Where-Object { $_ -match '(?i)^tests/' }).Count | Should -Be 0
  }
}

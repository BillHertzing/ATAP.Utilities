#Requires -Version 7.0
#Requires -Module Pester

# Focused Task 15.180.e E07 contract tests. These tests evaluate MSBuild
# properties and invoke only the validation target; they do not restore or build.

BeforeDiscovery {
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
  $script:repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
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

Describe 'Task 15.180 lifecycle contract structure' -Tag 'Unit', '5Tier' {
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

Describe 'Task 15.180 lifecycle aliases and canonical feed routing' -Tag 'Integration', '5Tier' {
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

Describe 'Task 15.180 empty lifecycle branch safeguard' -Tag 'Integration', '5Tier' {
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

Describe 'Task 15.180 exact VersionOverride fixture allowlist' -Tag 'Unit', 'CPM' {
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
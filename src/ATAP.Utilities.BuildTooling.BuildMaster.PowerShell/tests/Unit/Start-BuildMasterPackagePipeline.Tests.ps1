#Requires -Version 7.0
# Pester 6.2+ tests for Start-BuildMasterPackagePipeline.
# Mocks the BuildMaster API wrapper cmdlets; no real network contact.

BeforeAll {
  $parentModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $publicDir = Join-Path $parentModuleRoot 'public'
  $dotnetPublicDir = Join-Path (Split-Path -Parent $parentModuleRoot) 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell\public'
  . (Join-Path $publicDir 'New-BuildMasterRelease.ps1')
  . (Join-Path $publicDir 'Start-BuildMasterPipeline.ps1')
  . (Join-Path $publicDir 'Start-BuildMasterDeployment.ps1')
  . (Join-Path $dotnetPublicDir 'Get-PSModuleVersionFromNBGV.ps1')
  . (Join-Path $publicDir 'Start-BuildMasterPackagePipeline.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
}

Describe 'Start-BuildMasterPackagePipeline' -Tag 'Unit', 'PromotedModuleHostSensitive' {
  BeforeEach {
    Mock Write-PSFMessage { }
    Mock Write-Host { }
    $script:releaseCall = $null
    $script:buildCall = $null
    $script:deploymentCall = $null

    Mock New-BuildMasterRelease -MockWith {
      $script:releaseCall = @{
        Application        = $Application
        ReleaseNumber      = $ReleaseNumber
        ReleaseName        = $ReleaseName
        PipelineName       = $PipelineName
        BuildMasterBaseUrl = $BuildMasterBaseUrl
        BuildMasterAdminApiKeySecretName = $BuildMasterAdminApiKeySecretName
      }
      [PSCustomObject]@{
        Succeeded     = $true
        ReleaseId     = '1001'
        ReleaseNumber = $ReleaseNumber
        ReleaseName   = $ReleaseName
      }
    }
    Mock Start-BuildMasterPipeline -MockWith {
      $script:buildCall = @{
        Application        = $Application
        ReleaseNumber      = $ReleaseNumber
        Pipeline           = $Pipeline
        Variables          = $Variables
        Reason             = $Reason
        BuildMasterBaseUrl = $BuildMasterBaseUrl
        BuildMasterAdminApiKeySecretName = $BuildMasterAdminApiKeySecretName
      }
      [PSCustomObject]@{
        Succeeded   = $true
        BuildId     = '2002'
        BuildNumber = '23'
      }
    }
    Mock Start-BuildMasterDeployment -MockWith {
      $script:deploymentCall = @{
        Application        = $Application
        ReleaseNumber      = $ReleaseNumber
        BuildNumber        = $BuildNumber
        ToStage            = $ToStage
        BuildMasterBaseUrl = $BuildMasterBaseUrl
        BuildMasterAdminApiKeySecretName = $BuildMasterAdminApiKeySecretName
      }
      [PSCustomObject]@{
        Succeeded       = $true
        DeploymentId    = '3003'
        DeploymentState = 'pending'
      }
    }
  }

  It 'Computes ReleaseName from module name and resolved package version before creating the release' {
    $result = Start-BuildMasterPackagePipeline `
      -Application 'ATAP.Utilities-PowerShell' `
      -PipelineName 'global::PowerShellModule-5Stage' `
      -ModuleName 'ATAP.Utilities.PowerShell' `
      -ResolvedPackageVersion '0.1.0-Alpha025'

    $script:releaseCall['Application'] | Should -Be 'ATAP.Utilities-PowerShell'
    $script:releaseCall['ReleaseNumber'] | Should -Be '0.1.0-Alpha025.ATAP.Utilities.PowerShell'
    $script:releaseCall['ReleaseName'] | Should -Be 'ATAP.Utilities.PowerShell 0.1.0-Alpha025'
    $script:releaseCall['PipelineName'] | Should -Be 'global::PowerShellModule-5Stage'
    $result.ReleaseNumber | Should -Be '0.1.0-Alpha025.ATAP.Utilities.PowerShell'
    $result.ReleaseName | Should -Be 'ATAP.Utilities.PowerShell 0.1.0-Alpha025'
  }

  It 'Writes operator-facing progress to the console' {
    Start-BuildMasterPackagePipeline `
      -Application 'ATAP.Utilities-PowerShell' `
      -PipelineName 'global::PowerShellModule-5Stage' `
      -ModuleName 'ATAP.Utilities.PowerShell' `
      -ResolvedPackageVersion '0.1.0-Alpha025' | Out-Null

    Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
      $Object -eq "Starting BuildMaster package pipeline for module 'ATAP.Utilities.PowerShell' in application 'ATAP.Utilities-PowerShell'."
    }
    Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
      $Object -eq "Using supplied package version '0.1.0-Alpha025'."
    }
    Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
      $Object -eq "Creating BuildMaster release 'ATAP.Utilities.PowerShell 0.1.0-Alpha025' (ATAP.Utilities-PowerShell/0.1.0-Alpha025.ATAP.Utilities.PowerShell) on 'global::PowerShellModule-5Stage'."
    }
    Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
      $Object -eq "Queueing BuildMaster build for release '0.1.0-Alpha025.ATAP.Utilities.PowerShell'."
    }
    Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
      $Object -eq 'Calling BuildMaster release API (timeout 30s).'
    }
    Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
      $Object -eq 'Calling BuildMaster build API (timeout 30s).'
    }
    Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
      $Object -eq "Queued BuildMaster build '23' for release 'ATAP.Utilities.PowerShell 0.1.0-Alpha025'."
    }
    Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
      $Object -eq "Starting BuildMaster deployment for build '23' to the next pipeline stage."
    }
    Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
      $Object -eq 'Calling BuildMaster deploy API (timeout 30s).'
    }
    Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
      $Object -eq "Started BuildMaster deployment for build '23' to the next pipeline stage."
    }
  }

  It 'Runs with operator-friendly defaults when invoked without required identity parameters' {
    Mock Resolve-BuildMasterPackageModuleName { 'ATAP.Utilities.PowerShell' }
    Mock Resolve-BuildMasterPackageProjectPath { 'C:\fake\src\ATAP.Utilities.PowerShell' }
    Mock Resolve-BuildMasterPackageVersionFromProjectPath { '0.1.0-Beta008' }

    $result = Start-BuildMasterPackagePipeline

    $script:releaseCall['Application'] | Should -Be 'ATAP.Utilities-PowerShell'
    $script:releaseCall['PipelineName'] | Should -Be 'global::PowerShellModule-5Stage'
    $script:releaseCall['ReleaseNumber'] | Should -Be '0.1.0-Beta008.ATAP.Utilities.PowerShell'
    $script:releaseCall['ReleaseName'] | Should -Be 'ATAP.Utilities.PowerShell 0.1.0-Beta008'
    $script:buildCall['Variables']['$ModuleName'] | Should -Be 'ATAP.Utilities.PowerShell'
    $script:deploymentCall['ToStage'] | Should -BeNullOrEmpty
    $result.Succeeded | Should -BeTrue

    Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
      $Object -eq "ModuleName was not supplied; using 'ATAP.Utilities.PowerShell'."
    }
  }

  It 'Derives the package version from the inferred module project version.json when no version is supplied' {
    $repoRoot = Join-Path -Path $TestDrive -ChildPath 'repo'
    $moduleName = 'ATAP.Utilities.PowerShell'
    $moduleRoot = Join-Path -Path $repoRoot -ChildPath "src/$moduleName"
    New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path -Path $moduleRoot -ChildPath 'version.json') -Value '{"version":"0.1-Beta.{height}"}' -Encoding utf8

    Mock Get-PSModuleVersionFromNBGV -MockWith {
      [PSCustomObject]@{
        ModuleVersion    = [System.Version]'0.1.0'
        Prerelease       = 'Beta004'
        FullNuGetVersion = '0.1.0-Beta.4'
      }
    }

    Push-Location -LiteralPath $repoRoot
    try {
      $result = Start-BuildMasterPackagePipeline `
        -Application 'ATAP.Utilities-PowerShell' `
        -PipelineName 'global::PowerShellModule-5Stage' `
        -ModuleName $moduleName
    } finally {
      Pop-Location
    }

    $script:releaseCall['ReleaseNumber'] | Should -Be '0.1.0-Beta004.ATAP.Utilities.PowerShell'
    $script:releaseCall['ReleaseName'] | Should -Be 'ATAP.Utilities.PowerShell 0.1.0-Beta004'
    $script:buildCall['Variables']['$ResolvedPackageVersion'] | Should -Be '0.1.0-Beta004'
    $result.ResolvedPackageVersion | Should -Be '0.1.0-Beta004'
  }

  It 'Queues the build with package identity as BuildMaster build-scope variables' {
    Start-BuildMasterPackagePipeline `
      -Application 'ATAP.Utilities-PowerShell' `
      -PipelineName 'global::PowerShellModule-5Stage' `
      -ModuleName 'ATAP.Utilities.PowerShell' `
      -PackageName 'ATAP.Utilities.PowerShell' `
      -ResolvedPackageVersion '0.1.0-Beta001' `
      -FeedName 'powershellget-experimental' `
      -Branch '100-Sprint-0007-work-items' `
      -Variables @{ '$CustomFlag' = 'yes' } | Out-Null

    $script:buildCall['Application'] | Should -Be 'ATAP.Utilities-PowerShell'
    $script:buildCall['ReleaseNumber'] | Should -Be '0.1.0-Beta001.ATAP.Utilities.PowerShell'
    $script:buildCall['Pipeline'] | Should -Be 'global::PowerShellModule-5Stage'
    $variables = $script:buildCall['Variables']
    $variables['$ModuleName'] | Should -Be 'ATAP.Utilities.PowerShell'
    $variables['$PackageName'] | Should -Be 'ATAP.Utilities.PowerShell'
    $variables['$PackageVersion'] | Should -Be '0.1.0-Beta001'
    $variables['$ResolvedPackageVersion'] | Should -Be '0.1.0-Beta001'
    $variables['$Tier'] | Should -Be 'Experimental'
    $variables['$FeedName'] | Should -Be 'powershellget-experimental'
    $variables['$Branch'] | Should -Be '100-Sprint-0007-work-items'
    $variables['$CustomFlag'] | Should -Be 'yes'
  }

  It 'Starts deployment for the queued build at the next stage by default' {
    $result = Start-BuildMasterPackagePipeline `
      -Application 'ATAP.Utilities-PowerShell' `
      -PipelineName 'global::PowerShellModule-5Stage' `
      -ModuleName 'ATAP.Utilities.PowerShell' `
      -ResolvedPackageVersion '0.1.0-Beta001' `
      -BuildMasterBaseUrl 'https://utat022:50017' `
      -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01'

    $script:deploymentCall['Application'] | Should -Be 'ATAP.Utilities-PowerShell'
    $script:deploymentCall['ReleaseNumber'] | Should -Be '0.1.0-Beta001.ATAP.Utilities.PowerShell'
    $script:deploymentCall['BuildNumber'] | Should -Be '23'
    $script:deploymentCall['ToStage'] | Should -BeNullOrEmpty
    $script:deploymentCall['BuildMasterBaseUrl'] | Should -Be 'https://utat022:50017'
    $script:deploymentCall['BuildMasterAdminApiKeySecretName'] | Should -Be 'BuildMaster.Admin.API.Key.utat01'
    $result.DeploymentResult.DeploymentId | Should -Be '3003'
    $result.ResponseSummary | Should -Match 'deployment started'
  }

  It 'Honors an explicit deployment stage when supplied' {
    Start-BuildMasterPackagePipeline `
      -Application 'ATAP.Utilities-PowerShell' `
      -PipelineName 'global::PowerShellModule-5Stage' `
      -ModuleName 'ATAP.Utilities.PowerShell' `
      -ResolvedPackageVersion '0.1.0-Beta001' `
      -DeploymentStage 'Experimental' | Out-Null

    $script:deploymentCall['ToStage'] | Should -Be 'Experimental'
  }

  It 'Allows callers to create the release/build without starting deployment' {
    $result = Start-BuildMasterPackagePipeline `
      -Application 'ATAP.Utilities-PowerShell' `
      -PipelineName 'global::PowerShellModule-5Stage' `
      -ModuleName 'ATAP.Utilities.PowerShell' `
      -ResolvedPackageVersion '0.1.0-Beta001' `
      -SkipDeployment

    Should -Invoke Start-BuildMasterDeployment -Times 0 -Exactly -Scope It
    $script:deploymentCall | Should -BeNullOrEmpty
    $result.Succeeded | Should -BeTrue
    $result.ResponseSummary | Should -Match 'deployment skipped'
  }

  It 'Formats stable package versions correctly using a hyphen suffix' {
    $result = Start-BuildMasterPackagePipeline `
      -Application 'ATAP.Utilities-PowerShell' `
      -PipelineName 'global::PowerShellModule-5Stage' `
      -ModuleName 'ATAP.Utilities.PowerShell' `
      -ResolvedPackageVersion '0.1.0' `
      -SkipDeployment

    $script:releaseCall['ReleaseNumber'] | Should -Be '0.1.0-ATAP.Utilities.PowerShell'
    $result.ReleaseNumber | Should -Be '0.1.0-ATAP.Utilities.PowerShell'
  }

  It 'keeps overlength package release numbers bounded, deterministic, and collision resistant' {
    $nonWindowsCandidate = '0.1.2-ATAP.Utilities.Secrets.BitwardenSecretsManager'
    $windowsCandidate = '0.1.2-ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows'

    $nonWindows = ConvertTo-BuildMasterBoundedReleaseNumber -Candidate $nonWindowsCandidate
    $windows = ConvertTo-BuildMasterBoundedReleaseNumber -Candidate $windowsCandidate

    $nonWindows.Length | Should -Be 50
    $windows.Length | Should -Be 50
    $nonWindows | Should -Not -Be $windows
    (ConvertTo-BuildMasterBoundedReleaseNumber -Candidate $nonWindowsCandidate) | Should -BeExactly $nonWindows
    (ConvertTo-BuildMasterBoundedReleaseNumber -Candidate $windowsCandidate) | Should -BeExactly $windows
  }

  # SC-0360 boundary coverage: exactly at the limit, one over, well under.
  It 'leaves a release number of exactly 50 characters unchanged' {
    $atLimit = '0.1.0-' + ('M' * 44)
    $atLimit.Length | Should -Be 50
    ConvertTo-BuildMasterBoundedReleaseNumber -Candidate $atLimit | Should -BeExactly $atLimit
  }

  It 'bounds a release number of 51 characters to 50 with a 12-hex-character hash suffix' {
    $overByOne = '0.1.0-' + ('M' * 45)
    $bounded = ConvertTo-BuildMasterBoundedReleaseNumber -Candidate $overByOne
    $bounded.Length | Should -Be 50
    $bounded | Should -Match '^0\.1\.0-M{31}-[0-9a-f]{12}$'
    # The bounded form differs from the plain 50-character truncation BuildMaster would store.
    $bounded | Should -Not -Be $overByOne.Substring(0, 50)
  }

  It 'leaves a release number well under the limit unchanged' {
    ConvertTo-BuildMasterBoundedReleaseNumber -Candidate '0.1.0-Short' | Should -BeExactly '0.1.0-Short'
  }

  It 'gives distinct bounded values to two modules whose composed numbers share their first 50 characters' {
    $sharedPrefix = '0.1.34-ATAP.Utilities.BuildTooling.SprintLifecycle'
    $sharedPrefix.Length | Should -Be 50
    $first = ConvertTo-BuildMasterBoundedReleaseNumber -Candidate ($sharedPrefix + '.PowerShell')
    $second = ConvertTo-BuildMasterBoundedReleaseNumber -Candidate ($sharedPrefix + '.Windows.PowerShell')
    $first | Should -Not -Be $second
    $first.Substring(0, 37) | Should -BeExactly $second.Substring(0, 37)
  }

  It 'returns the bounded ReleaseNumber, the composed value, and uses the bounded value for every BuildMaster call' {
    $result = Start-BuildMasterPackagePipeline `
      -Application 'ATAP.Utilities-PowerShell' `
      -PipelineName 'global::PowerShellModule-5Stage' `
      -ModuleName 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell' `
      -ResolvedPackageVersion '0.1.34'

    $composed = '0.1.34-ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    $result.ComposedReleaseNumber | Should -BeExactly $composed
    $result.ReleaseNumberWasBounded | Should -BeTrue
    $result.ReleaseNumber.Length | Should -Be 50
    $result.ReleaseNumber | Should -BeExactly (ConvertTo-BuildMasterBoundedReleaseNumber -Candidate $composed)
    $script:releaseCall['ReleaseNumber'] | Should -BeExactly $result.ReleaseNumber
    $script:buildCall['ReleaseNumber'] | Should -BeExactly $result.ReleaseNumber
    $script:deploymentCall['ReleaseNumber'] | Should -BeExactly $result.ReleaseNumber
  }

  It 'reports ReleaseNumberWasBounded false when the composed value fits' {
    $result = Start-BuildMasterPackagePipeline `
      -Application 'ATAP.Utilities-PowerShell' `
      -PipelineName 'global::PowerShellModule-5Stage' `
      -ModuleName 'ATAP.Utilities.PowerShell' `
      -ResolvedPackageVersion '0.1.0' `
      -SkipDeployment

    $result.ReleaseNumberWasBounded | Should -BeFalse
    $result.ComposedReleaseNumber | Should -BeExactly $result.ReleaseNumber
  }

  It 'returns the composed and bounded values under -WhatIf without calling BuildMaster' {
    $result = Start-BuildMasterPackagePipeline `
      -Application 'ATAP.Utilities-PowerShell' `
      -PipelineName 'global::PowerShellModule-5Stage' `
      -ModuleName 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell' `
      -ResolvedPackageVersion '0.1.0-Alpha001' `
      -WhatIf

    Should -Invoke New-BuildMasterRelease -Times 0 -Exactly -Scope It
    $result.ComposedReleaseNumber | Should -BeExactly '0.1.0-Alpha001.ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $result.ReleaseNumberWasBounded | Should -BeTrue
    $result.ReleaseNumber.Length | Should -Be 50
  }
}

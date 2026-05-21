#Requires -Version 7.0
# Pester 5+ tests for Start-BuildMasterPackagePipeline.
# Mocks the BuildMaster API wrapper cmdlets; no real network contact.

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'New-BuildMasterRelease.ps1')
  . (Join-Path $publicDir 'Start-BuildMasterPipeline.ps1')
  . (Join-Path $publicDir 'Get-PSModuleVersionFromNBGV.ps1')
  . (Join-Path $publicDir 'Start-BuildMasterPackagePipeline.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
}

Describe 'Start-BuildMasterPackagePipeline' -Tag 'Unit', 'PromotedModuleHostSensitive' {
  BeforeEach {
    Mock Write-PSFMessage { }
    $script:releaseCall = $null
    $script:buildCall = $null

    Mock New-BuildMasterRelease -MockWith {
      $script:releaseCall = @{
        Application        = $Application
        ReleaseNumber      = $ReleaseNumber
        ReleaseName        = $ReleaseName
        PipelineName       = $PipelineName
        BuildMasterBaseUrl = $BuildMasterBaseUrl
        ApiKey             = $ApiKey
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
        ApiKey             = $ApiKey
      }
      [PSCustomObject]@{
        Succeeded   = $true
        BuildId     = '2002'
        BuildNumber = '23'
      }
    }
  }

  It 'Computes ReleaseName from module name and resolved package version before creating the release' {
    $result = Start-BuildMasterPackagePipeline `
      -Application 'ATAP.Utilities-PowerShell' `
      -PipelineName 'global::PowerShellModule-5Stage' `
      -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' `
      -ResolvedPackageVersion '0.1.0-Alpha025'

    $script:releaseCall['Application'] | Should -Be 'ATAP.Utilities-PowerShell'
    $script:releaseCall['ReleaseNumber'] | Should -Be '0.1.0-Alpha025'
    $script:releaseCall['ReleaseName'] | Should -Be 'ATAP.Utilities.BuildTooling.PowerShell 0.1.0-Alpha025'
    $script:releaseCall['PipelineName'] | Should -Be 'global::PowerShellModule-5Stage'
    $result.ReleaseName | Should -Be 'ATAP.Utilities.BuildTooling.PowerShell 0.1.0-Alpha025'
  }

  It 'Derives the package version from the inferred module project version.json when no version is supplied' {
    $repoRoot = Join-Path -Path $TestDrive -ChildPath 'repo'
    $moduleName = 'ATAP.Utilities.BuildTooling.PowerShell'
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

    $script:releaseCall['ReleaseNumber'] | Should -Be '0.1.0-Beta004'
    $script:releaseCall['ReleaseName'] | Should -Be 'ATAP.Utilities.BuildTooling.PowerShell 0.1.0-Beta004'
    $script:buildCall['Variables']['$ResolvedPackageVersion'] | Should -Be '0.1.0-Beta004'
    $result.ResolvedPackageVersion | Should -Be '0.1.0-Beta004'
  }

  It 'Queues the build with package identity as BuildMaster build-scope variables' {
    Start-BuildMasterPackagePipeline `
      -Application 'ATAP.Utilities-PowerShell' `
      -PipelineName 'global::PowerShellModule-5Stage' `
      -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' `
      -PackageName 'ATAP.Utilities.BuildTooling.PowerShell' `
      -ResolvedPackageVersion '0.1.0-Beta001' `
      -FeedName 'powershellget-experimental' `
      -Branch '100-Sprint-0007-work-items' `
      -Variables @{ '$CustomFlag' = 'yes' } | Out-Null

    $script:buildCall['Application'] | Should -Be 'ATAP.Utilities-PowerShell'
    $script:buildCall['ReleaseNumber'] | Should -Be '0.1.0-Beta001'
    $script:buildCall['Pipeline'] | Should -Be 'global::PowerShellModule-5Stage'
    $variables = $script:buildCall['Variables']
    $variables['$ModuleName'] | Should -Be 'ATAP.Utilities.BuildTooling.PowerShell'
    $variables['$PackageName'] | Should -Be 'ATAP.Utilities.BuildTooling.PowerShell'
    $variables['$PackageVersion'] | Should -Be '0.1.0-Beta001'
    $variables['$ResolvedPackageVersion'] | Should -Be '0.1.0-Beta001'
    $variables['$Tier'] | Should -Be 'Experimental'
    $variables['$FeedName'] | Should -Be 'powershellget-experimental'
    $variables['$Branch'] | Should -Be '100-Sprint-0007-work-items'
    $variables['$CustomFlag'] | Should -Be 'yes'
  }
}

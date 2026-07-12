#Requires -Version 7.0

BeforeAll {
  $script:manifestPath = Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.PowerShell.psd1'
  Import-Module $script:manifestPath -Force
}

Describe 'Set-SprintBoundaryUserProfiles [public]' {
  BeforeAll {
    $script:testRoot = Join-Path ([IO.Path]::GetTempPath()) "sbup_test_$([guid]::NewGuid().ToString('N'))"
    $script:gitRoot = Join-Path $script:testRoot 'git'
    $script:utilRoot = Join-Path $script:gitRoot 'ATAP.Utilities-wt-118-Sprint-0011-work-items'
    $script:iacRoot = Join-Path $script:gitRoot 'ATAP.IAC-wt-13-Sprint-0011-work-items'
    $script:developerHome = Join-Path $script:testRoot 'DeveloperHome'
    $script:serviceHome = Join-Path $script:testRoot 'SvcHome'
    $templateDir = Join-Path $script:iacRoot 'Windows\ProfileTemplates'
    New-Item -ItemType Directory -Path $templateDir, $script:developerHome, $script:serviceHome -Force | Out-Null
    @'
# ATAP-Managed-UserScopeProfile: v1
# developer profile payload
'@ | Set-Content -LiteralPath (Join-Path $templateDir 'CurrentUserAllHostsV7CoreProfile.ps1') -Encoding UTF8 -NoNewline
    @'
# ATAP-Managed-UserScopeProfile: v1
Set-StrictMode -Version Latest
'@ | Set-Content -LiteralPath (Join-Path $templateDir 'ProfileForServiceAccountUsers.ps1') -Encoding UTF8 -NoNewline

    $script:overviewPath = Join-Path $script:gitRoot 'Overview.Sprint.0011.code-workspace'
    @{
      folders = @(@{ path = 'ATAP.Utilities-wt-118-Sprint-0011-work-items' })
      developers = @(
        @{
          username = 'alice'
          host = $env:COMPUTERNAME
        }
      )
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:overviewPath -Encoding UTF8
  }

  AfterAll {
    Remove-Item -LiteralPath $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  BeforeEach {
    Mock -ModuleName ATAP.Utilities.BuildTooling.PowerShell Initialize-ATAPConfigurationGlobals {
      $global:configRootKeys = @{
        DatabasesCollectionConfigRootKey = 'DatabasesCollection'
        BuildMasterServiceAccountConfigRootKey = 'BuildMasterServiceAccount'
        BuildMasterServiceAccountUserHomeDirectoryConfigRootKey = 'BuildMasterServiceAccountUserHomeDirectory'
      }
      $global:settings = @{
        DatabasesCollection = @{ ATAPUtilities = @{} }
        BuildMasterServiceAccount = 'SvcBuildmaster'
        BuildMasterServiceAccountUserHomeDirectory = 'C:\Users\SvcBuildmaster'
      }
      [PSCustomObject]@{ Initialized = $true }
    }
    Mock -ModuleName ATAP.Utilities.BuildTooling.PowerShell Add-ParityChangeEntry { [PSCustomObject]@{ Id = 'journal-entry' } }
    Remove-Item -LiteralPath (Join-Path $script:developerHome 'Documents'), (Join-Path $script:serviceHome 'Documents') -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'deploys the developer profile to Documents\\PowerShell\\profile.ps1' {
    Mock -ModuleName ATAP.Utilities.BuildTooling.PowerShell Get-LocalUser {
      [PSCustomObject]@{ Name = 'SvcBuildmaster'; Enabled = $false }
    }

    $result = Set-SprintBoundaryUserProfiles `
      -ATAPUtilitiesRoot $script:utilRoot `
      -ATAPIACRoot $script:iacRoot `
      -GitRoot $script:gitRoot `
      -OverviewWorkspacePath $script:overviewPath `
      -HomeDirectoryOverrides @{ alice = $script:developerHome } `
      -Confirm:$false

    $result.Ok | Should -BeTrue
    $developerProfile = Join-Path $script:developerHome 'Documents\PowerShell\profile.ps1'
    Test-Path -LiteralPath $developerProfile | Should -BeTrue
    Get-Content -LiteralPath $developerProfile -Raw |
      Should -Match 'developer profile payload'
  }

  It 'deploys the service-account profile for an enabled local account' {
    Mock -ModuleName ATAP.Utilities.BuildTooling.PowerShell Get-LocalUser {
      [PSCustomObject]@{ Name = 'SvcBuildmaster'; Enabled = $true }
    }

    $result = Set-SprintBoundaryUserProfiles `
      -ATAPUtilitiesRoot $script:utilRoot `
      -ATAPIACRoot $script:iacRoot `
      -GitRoot $script:gitRoot `
      -OverviewWorkspacePath $script:overviewPath `
      -HomeDirectoryOverrides @{ alice = $script:developerHome; SvcBuildmaster = $script:serviceHome } `
      -Confirm:$false

    $result.Ok | Should -BeTrue
    $serviceProfile = Join-Path $script:serviceHome 'Documents\PowerShell\profile.ps1'
    Test-Path -LiteralPath $serviceProfile | Should -BeTrue
    Get-Content -LiteralPath $serviceProfile -Raw |
      Should -Match 'Set-StrictMode'
  }

  It 'skips a missing or disabled service account with an explicit warning' {
    Mock -ModuleName ATAP.Utilities.BuildTooling.PowerShell Get-LocalUser { $null }

    $result = Set-SprintBoundaryUserProfiles `
      -ATAPUtilitiesRoot $script:utilRoot `
      -ATAPIACRoot $script:iacRoot `
      -GitRoot $script:gitRoot `
      -OverviewWorkspacePath $script:overviewPath `
      -HomeDirectoryOverrides @{ alice = $script:developerHome } `
      -Confirm:$false

    $result.Ok | Should -BeTrue
    $result.Warnings | Should -Match 'Service account ''SvcBuildmaster'' is not present'
    ($result.Profiles | Where-Object Kind -EQ 'ServiceAccount').Action | Should -Be 'Skipped'
  }

  It 'does not mutate the filesystem under WhatIf while still returning the planned profiles' {
    Mock -ModuleName ATAP.Utilities.BuildTooling.PowerShell Get-LocalUser {
      [PSCustomObject]@{ Name = 'SvcBuildmaster'; Enabled = $true }
    }

    $result = Set-SprintBoundaryUserProfiles `
      -ATAPUtilitiesRoot $script:utilRoot `
      -ATAPIACRoot $script:iacRoot `
      -GitRoot $script:gitRoot `
      -OverviewWorkspacePath $script:overviewPath `
      -HomeDirectoryOverrides @{ alice = $script:developerHome; SvcBuildmaster = $script:serviceHome } `
      -WhatIf `
      -Confirm:$false

    $result.Ok | Should -BeTrue
    ($result.Profiles | Where-Object Identity -EQ 'alice').Action | Should -Match '^Would'
    Test-Path -LiteralPath (Join-Path $script:serviceHome 'Documents\PowerShell\profile.ps1') | Should -BeFalse
  }
}

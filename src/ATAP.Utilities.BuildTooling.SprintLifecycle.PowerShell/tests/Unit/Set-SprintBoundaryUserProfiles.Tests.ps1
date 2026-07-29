#Requires -Version 7.0

BeforeAll {
  $script:addedGetLocalUserShim = $false
  if (-not (Get-Command -Name Get-LocalUser -ErrorAction SilentlyContinue)) {
    function global:Get-LocalUser {
      param([string]$Name)
      return $null
    }
    $script:addedGetLocalUserShim = $true
  }

  $script:setUserScopeProfilePath = Join-Path $PSScriptRoot '..' '..' '..' `
    'ATAP.Utilities.BuildTooling.PowerShell' 'public' 'Set-UserScopeProfile.ps1'
  . $script:setUserScopeProfilePath
  $script:manifestPath = Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell.psd1'
  Import-Module $script:manifestPath -Force
}

AfterAll {
  if ($script:addedGetLocalUserShim) {
    Remove-Item -LiteralPath 'Function:\global:Get-LocalUser' -ErrorAction SilentlyContinue
  }
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
    $setUserScopeProfileTarget = Join-Path $script:utilRoot `
      'src\ATAP.Utilities.BuildTooling.PowerShell\public\Set-UserScopeProfile.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $setUserScopeProfileTarget) -Force | Out-Null
    Copy-Item -LiteralPath $script:setUserScopeProfilePath -Destination $setUserScopeProfileTarget
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
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Initialize-ATAPConfigurationGlobals {
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
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Add-ParityChangeEntry { [PSCustomObject]@{ Id = 'journal-entry' } }
    Remove-Item -LiteralPath (Join-Path $script:developerHome 'Documents'), (Join-Path $script:serviceHome 'Documents') -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'discovers and validates the canonical developer profile without requiring a cross-account write' {
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Get-LocalUser {
      if ($Name -eq 'SvcBuildmaster') {
        [PSCustomObject]@{ Name = 'SvcBuildmaster'; Enabled = $false }
      }
    }

    $result = Set-SprintBoundaryUserProfiles `
      -ATAPUtilitiesRoot $script:utilRoot `
      -ATAPIACRoot $script:iacRoot `
      -GitRoot $script:gitRoot `
      -OverviewWorkspacePath $script:overviewPath `
      -HomeDirectoryOverrides @{ alice = $script:developerHome } `
      -WhatIf `
      -Confirm:$false

    $result.Failures | Should -BeNullOrEmpty
    $result.Ok | Should -BeTrue
    $developerProfile = Join-Path $script:developerHome 'Documents\PowerShell\profile.ps1'
    $developerResult = $result.Profiles | Where-Object Kind -EQ 'Developer'
    $developerResult.Action | Should -Be 'WouldCreated'
    Test-Path -LiteralPath $developerProfile | Should -BeFalse
    $developerResult.SourcePath |
      Should -Be (Join-Path $script:iacRoot 'Windows\ProfileTemplates\CurrentUserAllHostsV7CoreProfile.ps1')
    Get-Content -LiteralPath $developerResult.SourcePath -Raw |
      Should -Match 'developer profile payload'
    Test-Path -LiteralPath (Join-Path $script:utilRoot 'src\ATAP.Utilities.PowerShell\Profiles') |
      Should -BeFalse
  }

  It 'discovers and validates the canonical service-account profile without requiring a credential or cross-account write' {
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Get-LocalUser {
      if ($Name -eq 'SvcBuildmaster') {
        [PSCustomObject]@{ Name = 'SvcBuildmaster'; Enabled = $true }
      }
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
    $serviceProfile = Join-Path $script:serviceHome 'Documents\PowerShell\profile.ps1'
    $serviceResult = $result.Profiles | Where-Object Kind -EQ 'ServiceAccount'
    $serviceResult.Action | Should -Be 'WouldCreated'
    Test-Path -LiteralPath $serviceProfile | Should -BeFalse
    $serviceResult.SourcePath |
      Should -Be (Join-Path $script:iacRoot 'Windows\ProfileTemplates\ProfileForServiceAccountUsers.ps1')
    Get-Content -LiteralPath $serviceResult.SourcePath -Raw |
      Should -Match 'Set-StrictMode'
    Test-Path -LiteralPath (Join-Path $script:utilRoot 'src\ATAP.Utilities.PowerShell\Profiles') |
      Should -BeFalse
  }

  It 'merges approved local service accounts when ConfigRootKeys do not describe them' {
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Initialize-ATAPConfigurationGlobals {
      $global:configRootKeys = @{
        DatabasesCollectionConfigRootKey = 'DatabasesCollection'
      }
      $global:settings = @{
        DatabasesCollection = @{ ATAPUtilities = @{} }
      }
      [PSCustomObject]@{ Initialized = $true }
    }
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Get-LocalUser {
      if ($Name -in @('SvcBuildMaster', 'SvcProGet', 'SvcSQLServer')) {
        [PSCustomObject]@{ Name = $Name; Enabled = $true }
      }
    }

    $buildMasterHome = Join-Path $script:testRoot 'SvcBuildMasterHome'
    $proGetHome = Join-Path $script:testRoot 'SvcProGetHome'
    $sqlServerHome = Join-Path $script:testRoot 'SvcSQLServerHome'
    New-Item -ItemType Directory -Path $buildMasterHome, $proGetHome, $sqlServerHome -Force | Out-Null

    $result = Set-SprintBoundaryUserProfiles `
      -ATAPUtilitiesRoot $script:utilRoot `
      -ATAPIACRoot $script:iacRoot `
      -GitRoot $script:gitRoot `
      -OverviewWorkspacePath $script:overviewPath `
      -HomeDirectoryOverrides @{
        alice = $script:developerHome
        SvcBuildMaster = $buildMasterHome
        SvcProGet = $proGetHome
        SvcSQLServer = $sqlServerHome
      } `
      -WhatIf `
      -Confirm:$false

    $result.Ok | Should -BeTrue
    $serviceResults = @($result.Profiles | Where-Object Kind -EQ 'ServiceAccount')
    $serviceResults.Count | Should -Be 3
    @($serviceResults.Identity | Sort-Object) |
      Should -Be @('SvcBuildMaster', 'SvcProGet', 'SvcSQLServer')
    @($serviceResults.Action | Select-Object -Unique) | Should -Be @('WouldCreated')
    @($serviceResults.RequiresSecret | Select-Object -Unique) | Should -Be @($true)
  }
  It 'prevents an approved service identity from managing peer service-account profiles' {
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Initialize-ATAPConfigurationGlobals {
      $global:configRootKeys = @{}
      $global:settings = @{}
      [PSCustomObject]@{ Initialized = $true }
    }
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Get-LocalUser {
      if ($Name -in @('SvcBuildMaster', 'SvcProGet', 'SvcSQLServer')) {
        [PSCustomObject]@{ Name = $Name; Enabled = $true }
      }
    }

    $oldUsername = $env:USERNAME
    try {
      $env:USERNAME = 'SvcBuildMaster'
      $buildMasterHome = Join-Path $script:testRoot 'SvcBuildMasterOwnHome'
      $proGetHome = Join-Path $script:testRoot 'SvcProGetPeerHome'
      $sqlServerHome = Join-Path $script:testRoot 'SvcSQLServerPeerHome'
      New-Item -ItemType Directory -Path $buildMasterHome, $proGetHome, $sqlServerHome -Force | Out-Null

      $result = Set-SprintBoundaryUserProfiles `
        -ATAPUtilitiesRoot $script:utilRoot `
        -ATAPIACRoot $script:iacRoot `
        -GitRoot $script:gitRoot `
        -OverviewWorkspacePath $script:overviewPath `
        -HomeDirectoryOverrides @{
          alice = $script:developerHome
          SvcBuildMaster = $buildMasterHome
          SvcProGet = $proGetHome
          SvcSQLServer = $sqlServerHome
        } `
        -WhatIf `
        -Confirm:$false

      $result.Ok | Should -BeTrue
      ($result.Profiles | Where-Object Identity -EQ 'SvcBuildMaster').Action | Should -Be 'WouldCreated'
      @(
        $result.Profiles |
          Where-Object { $_.Identity -in @('SvcProGet', 'SvcSQLServer') } |
          Select-Object -ExpandProperty Action -Unique
      ) | Should -Be @('Skipped')
      (($result.Profiles | Where-Object { $_.Identity -in @('SvcProGet', 'SvcSQLServer') }).Warning -join ';') |
        Should -Match 'cross-account profile management is skipped'
    } finally {
      $env:USERNAME = $oldUsername
    }
  }
  It 'selects the current-host assignment and deploys only the redirected loaded profile idempotently' {
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Get-LocalUser { $null }
    $currentHome = Join-Path $script:testRoot 'CurrentDeveloperHome'
    $redirectedProfile = Join-Path $script:testRoot 'Dropbox\CurrentDeveloper\PowerShell\profile.ps1'
    $multiHostOverview = Join-Path $script:gitRoot 'Overview.Sprint.0013.MultiHost.code-workspace'
    @{
      folders = @()
      developers = @(
        @{ username = $env:USERNAME; host = 'not-this-host' }
        @{ username = $env:USERNAME; host = $env:COMPUTERNAME }
      )
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $multiHostOverview -Encoding UTF8

    $parameters = @{
      ATAPUtilitiesRoot = $script:utilRoot
      ATAPIACRoot = $script:iacRoot
      GitRoot = $script:gitRoot
      OverviewWorkspacePath = $multiHostOverview
      HomeDirectoryOverrides = @{ $env:USERNAME = $currentHome }
      CurrentUserAllHostsProfilePath = $redirectedProfile
      Confirm = $false
    }

    $first = Set-SprintBoundaryUserProfiles @parameters
    $second = Set-SprintBoundaryUserProfiles @parameters

    $developerProfiles = @($second.Profiles | Where-Object Kind -EQ 'Developer')
    $developerProfiles.Count | Should -Be 1
    $developerProfiles[0].Host | Should -Be $env:COMPUTERNAME
    $developerProfiles[0].Action | Should -Be 'AlreadyCurrent'
    $developerProfiles[0].ProfilePath | Should -Be ([IO.Path]::GetFullPath($redirectedProfile))
    Test-Path -LiteralPath $redirectedProfile -PathType Leaf | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $currentHome 'Documents\PowerShell\profile.ps1') | Should -BeFalse
    $first.Ok | Should -BeTrue
    $second.Ok | Should -BeTrue
  }

  It 'skips a missing or disabled service account with an explicit warning' {
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Get-LocalUser { $null }

    $result = Set-SprintBoundaryUserProfiles `
      -ATAPUtilitiesRoot $script:utilRoot `
      -ATAPIACRoot $script:iacRoot `
      -GitRoot $script:gitRoot `
      -OverviewWorkspacePath $script:overviewPath `
      -HomeDirectoryOverrides @{ alice = $script:developerHome } `
      -WhatIf `
      -Confirm:$false

    $result.Ok | Should -BeTrue
    $result.Warnings | Should -Match 'Service account ''SvcBuildmaster'' is not present'
    ($result.Profiles | Where-Object Kind -EQ 'ServiceAccount').Action | Should -Be 'Skipped'
  }

  It 'does not mutate the filesystem under WhatIf while still returning the planned profiles' {
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Get-LocalUser {
      if ($Name -eq 'SvcBuildmaster') {
        [PSCustomObject]@{ Name = 'SvcBuildmaster'; Enabled = $true }
      }
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

  It 'ignores pre-existing retired ATAP.Utilities template candidates' {
    Mock -ModuleName ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell Get-LocalUser {
      if ($Name -eq 'SvcBuildmaster') {
        [PSCustomObject]@{ Name = 'SvcBuildmaster'; Enabled = $true }
      }
    }
    $retiredTemplateRoot = Join-Path $script:utilRoot 'src\ATAP.Utilities.PowerShell\Profiles'
    New-Item -ItemType Directory -Path $retiredTemplateRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $retiredTemplateRoot 'CurrentUserAllHostsV7CoreProfile.ps1') `
      -Value '# retired developer payload must not be selected' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $retiredTemplateRoot 'ProfileForServiceAccountUsers.ps1') `
      -Value '# retired service payload must not be selected' -Encoding UTF8

    $result = Set-SprintBoundaryUserProfiles `
      -ATAPUtilitiesRoot $script:utilRoot `
      -ATAPIACRoot $script:iacRoot `
      -GitRoot $script:gitRoot `
      -OverviewWorkspacePath $script:overviewPath `
      -HomeDirectoryOverrides @{ alice = $script:developerHome; SvcBuildmaster = $script:serviceHome } `
      -WhatIf `
      -Confirm:$false

    $result.Ok | Should -BeTrue
    @($result.Profiles | Where-Object { -not $_.Skipped }).SourcePath |
      Should -Not -Contain (Join-Path $retiredTemplateRoot 'CurrentUserAllHostsV7CoreProfile.ps1')
    @($result.Profiles | Where-Object { -not $_.Skipped }).SourcePath |
      Should -Not -Contain (Join-Path $retiredTemplateRoot 'ProfileForServiceAccountUsers.ps1')
    ($result.Profiles | Where-Object Kind -EQ 'Developer').SourcePath |
      Should -Be (Join-Path $script:iacRoot 'Windows\ProfileTemplates\CurrentUserAllHostsV7CoreProfile.ps1')
    ($result.Profiles | Where-Object Kind -EQ 'ServiceAccount').SourcePath |
      Should -Be (Join-Path $script:iacRoot 'Windows\ProfileTemplates\ProfileForServiceAccountUsers.ps1')
  }
}

#Requires -Version 7.0

BeforeAll {
  $script:manifestPath = Join-Path $PSScriptRoot '..' '..' 'ATAP.Utilities.BuildTooling.PowerShell.psd1'
  Import-Module $script:manifestPath -Force
}

Describe 'Set-UserScopeProfile [public]' {
  BeforeAll {
    $script:testRoot = Join-Path ([IO.Path]::GetTempPath()) "user_scope_profile_$([guid]::NewGuid().ToString('N'))"
    $script:iacRoot = Join-Path $script:testRoot 'ATAP.IAC'
    $script:utilitiesRoot = Join-Path $script:testRoot 'ATAP.Utilities'
    $script:userHome = Join-Path $script:testRoot 'whertzing'
    $script:templateRoot = Join-Path $script:iacRoot 'Windows\ProfileTemplates'
    New-Item -ItemType Directory -Path $script:templateRoot, $script:utilitiesRoot, $script:userHome -Force | Out-Null
    @'
# ATAP-Managed-UserScopeProfile: v1
# Canonical developer profile payload.
$global:Task1249Fixture = 'developer'
'@ | Set-Content -LiteralPath (Join-Path $script:templateRoot 'CurrentUserAllHostsV7CoreProfile.ps1') -Encoding utf8 -NoNewline
    @'
# ATAP-Managed-UserScopeProfile: v1
# Minimal non-interactive service-account profile for {{ACCOUNT_NAME}}.
Set-StrictMode -Version Latest
'@ | Set-Content -LiteralPath (Join-Path $script:templateRoot 'ProfileForServiceAccountUsers.ps1') -Encoding utf8 -NoNewline
  }

  AfterAll {
    Remove-Item -LiteralPath $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  BeforeEach {
    Remove-Item -LiteralPath (Join-Path $script:userHome 'Documents') -Recurse -Force -ErrorAction SilentlyContinue
    Mock -ModuleName ATAP.Utilities.BuildTooling.PowerShell Add-ParityChangeEntry { [PSCustomObject]@{ Id = 'journal-entry' } }
  }

  It 'copies the canonical developer payload byte-for-byte' {
    $result = Set-UserScopeProfile -AccountName 'whertzing' -AccountClass Developer `
      -ATAPIACRoot $script:iacRoot -ATAPUtilitiesRoot $script:utilitiesRoot `
      -UserProfilePath $script:userHome -Confirm:$false

    $result.Action | Should -Be 'Created'
    $result.Journaled | Should -BeTrue
    $result.ProfilePath | Should -Exist
    $result.SourcePath | Should -Be (Join-Path $script:templateRoot 'CurrentUserAllHostsV7CoreProfile.ps1')
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($result.ProfilePath)) |
      Should -Be ([Convert]::ToBase64String([IO.File]::ReadAllBytes($result.SourcePath)))
    Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Add-ParityChangeEntry -Times 1 -Exactly -Scope It
  }

  It 'is idempotent when the managed profile is current' {
    Set-UserScopeProfile -AccountName 'whertzing' -AccountClass Developer `
      -ATAPIACRoot $script:iacRoot -ATAPUtilitiesRoot $script:utilitiesRoot `
      -UserProfilePath $script:userHome -Confirm:$false | Out-Null

    $result = Set-UserScopeProfile -AccountName 'whertzing' -AccountClass Developer `
      -ATAPIACRoot $script:iacRoot -ATAPUtilitiesRoot $script:utilitiesRoot `
      -UserProfilePath $script:userHome -Confirm:$false

    $result.Action | Should -Be 'AlreadyCurrent'
    $result.Changed | Should -BeFalse
    Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Add-ParityChangeEntry -Times 1 -Exactly -Scope It
  }

  It 'refuses to overwrite an unmanaged profile unless Force is supplied' {
    $profileDirectory = Join-Path $script:userHome 'Documents\PowerShell'
    New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $profileDirectory 'profile.ps1') -Value '# user-owned profile' -Encoding utf8 -NoNewline

    {
      Set-UserScopeProfile -AccountName 'whertzing' -AccountClass Developer `
        -ATAPIACRoot $script:iacRoot -ATAPUtilitiesRoot $script:utilitiesRoot `
        -UserProfilePath $script:userHome -Confirm:$false
    } | Should -Throw '*Refusing to overwrite unmanaged profile*'
  }

  It 'migrates the known SSH-safe legacy dot-source wrapper without Force' {
    $profileDirectory = Join-Path $script:userHome 'Documents\PowerShell'
    New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
    @'
# Quiet SSH-backed PowerShell remoting before profile initialization.
if ($env:SSH_CONNECTION) { return }
. 'C:\Legacy\CurrentUserAllHostsV7CoreProfile.ps1'
'@ | Set-Content -LiteralPath (Join-Path $profileDirectory 'profile.ps1') -Encoding utf8 -NoNewline

    $result = Set-UserScopeProfile -AccountName 'whertzing' -AccountClass Developer `
      -ATAPIACRoot $script:iacRoot -ATAPUtilitiesRoot $script:utilitiesRoot `
      -UserProfilePath $script:userHome -Confirm:$false

    $result.Action | Should -Be 'Updated'
    Get-Content -LiteralPath $result.ProfilePath -Raw | Should -Match 'Canonical developer profile payload'
  }

  It 'does not mutate the filesystem under WhatIf' {
    $result = Set-UserScopeProfile -AccountName 'whertzing' -AccountClass ServiceAccount `
      -ATAPIACRoot $script:iacRoot -ATAPUtilitiesRoot $script:utilitiesRoot `
      -UserProfilePath $script:userHome -WhatIf -Confirm:$false

    $result.Action | Should -Be 'WouldCreated'
    Test-Path -LiteralPath $result.ProfilePath | Should -BeFalse
    Should -Invoke -ModuleName ATAP.Utilities.BuildTooling.PowerShell Add-ParityChangeEntry -Times 0 -Exactly -Scope It
  }
}

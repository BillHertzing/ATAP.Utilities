#Requires -Modules Pester

BeforeAll {
  function Write-PSFMessage {
    param()
  }

  . (Join-Path $PSScriptRoot '..\..\private\Set-ClaudeSettingsSymlink.ps1')
  $script:originalUserProfile = $env:USERPROFILE
}

AfterAll {
  $env:USERPROFILE = $script:originalUserProfile
}

Describe 'Set-ClaudeSettingsSymlink mutation boundary' {
  BeforeEach {
    $script:testRoot = Join-Path (
      [IO.Path]::GetTempPath()
    ) ('claude-settings-link-' + [Guid]::NewGuid().ToString('N'))
    $script:sharedRoot = Join-Path $script:testRoot 'SharedVSCode'
    $script:userRoot = Join-Path $script:testRoot 'UserProfile'
    New-Item -ItemType Directory -Path $script:sharedRoot -Force | Out-Null
    [IO.File]::WriteAllText(
      (Join-Path $script:sharedRoot 'claude-settings.json'),
      '{"permissions":{"allow":[]}}',
      [Text.UTF8Encoding]::new($false)
    )
    $env:USERPROFILE = $script:userRoot
  }

  AfterEach {
    $env:USERPROFILE = $script:originalUserProfile
    Remove-Item -LiteralPath $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'does not create ~/.claude when WhatIf declines the operation' {
    Set-ClaudeSettingsSymlink `
      -SharedVSCodeWorktreePath $script:sharedRoot `
      -WhatIf `
      -Confirm:$false

    Test-Path -LiteralPath (Join-Path $script:userRoot '.claude') | Should -BeFalse
  }

  It 'does not remove or replace an existing settings file under WhatIf' {
    $claudeRoot = Join-Path $script:userRoot '.claude'
    $settingsPath = Join-Path $claudeRoot 'settings.json'
    New-Item -ItemType Directory -Path $claudeRoot -Force | Out-Null
    [IO.File]::WriteAllText(
      $settingsPath,
      'original settings',
      [Text.UTF8Encoding]::new($false)
    )

    Set-ClaudeSettingsSymlink `
      -SharedVSCodeWorktreePath $script:sharedRoot `
      -WhatIf `
      -Confirm:$false

    (Get-Content -LiteralPath $settingsPath -Raw) | Should -BeExactly 'original settings'
    (Get-Item -LiteralPath $settingsPath -Force).LinkType | Should -BeNullOrEmpty
  }

  It 'replaces only settings.json with the approved SharedVSCode symlink' {
    $claudeRoot = Join-Path $script:userRoot '.claude'
    $settingsPath = Join-Path $claudeRoot 'settings.json'
    $projectsPath = Join-Path $claudeRoot 'projects'
    New-Item -ItemType Directory -Path $projectsPath -Force | Out-Null
    [IO.File]::WriteAllText(
      (Join-Path $projectsPath 'sentinel.jsonl'),
      'preserve me',
      [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
      $settingsPath,
      'old settings',
      [Text.UTF8Encoding]::new($false)
    )

    Set-ClaudeSettingsSymlink `
      -SharedVSCodeWorktreePath $script:sharedRoot `
      -Confirm:$false

    $settingsItem = Get-Item -LiteralPath $settingsPath -Force
    $settingsItem.LinkType | Should -Be 'SymbolicLink'
    $settingsItem.Target | Should -Contain (
      Join-Path $script:sharedRoot 'claude-settings.json'
    )
    (Get-Content -LiteralPath (Join-Path $projectsPath 'sentinel.jsonl') -Raw) |
      Should -BeExactly 'preserve me'
  }
}

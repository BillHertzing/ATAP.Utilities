#Requires -Modules Pester

BeforeAll {
  function Write-PSFMessage {
    param()
  }

  . (Join-Path $PSScriptRoot '..\..\public\Set-ClaudeSettingsSymlink.ps1')
  $script:originalUserProfile = $env:USERPROFILE
}

AfterAll {
  $env:USERPROFILE = $script:originalUserProfile
}

Describe 'Set-ClaudeSettingsSymlink managed render boundary' {
  BeforeEach {
    $script:testRoot = Join-Path (
      [IO.Path]::GetTempPath()
    ) ('claude-settings-render-' + [Guid]::NewGuid().ToString('N'))
    $script:sharedRoot = Join-Path $script:testRoot 'SharedVSCode'
    $script:userRoot = Join-Path $script:testRoot 'UserProfile'
    $script:configRoot = Join-Path $script:sharedRoot '.ai\config\claudecode'
    New-Item -ItemType Directory -Path $script:configRoot -Force | Out-Null
    $script:renderedSettingsPath = Join-Path $script:sharedRoot '.claude\settings.json'
    New-Item -ItemType Directory -Path (Split-Path $script:renderedSettingsPath -Parent) -Force | Out-Null
    [IO.File]::WriteAllText(
      $script:renderedSettingsPath,
      (@{
          model = 'sonnet'
          permissions = @{
            defaultMode = 'acceptEdits'
            allow = @('PowerShell(:*)')
            deny = @()
            ask = @()
          }
          hooks = @{
            PreToolUse = @(@{
                matcher = 'Bash|PowerShell'
                hooks = @(@{
                    type = 'command'
                    command = 'pwsh -File "C:\GitHub\SharedVSCode\.claude\hooks\PreToolUse-PwshGuard.ps1"'
                  })
              })
          }
          env = @{ CLAUDE_CODE_SHELL = 'pwsh' }
        } | ConvertTo-Json -Depth 10),
      [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
      (Join-Path $script:configRoot 'local-preserve.json'),
      (@{
          preservePaths = @('${HOME}/.claude.json', '.claude/settings.local.json', '.mcp.json')
          preserveDomains = @('local-preferences', 'mcp')
          ephemeralSettings = @()
        } | ConvertTo-Json -Depth 10),
      [Text.UTF8Encoding]::new($false)
    )
    $env:USERPROFILE = $script:userRoot
  }

  AfterEach {
    $env:USERPROFILE = $script:originalUserProfile
    Remove-Item -LiteralPath $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'requires both user-global write gates for live mutation' {
    { Set-ClaudeSettingsSymlink -SharedVSCodeWorktreePath $script:sharedRoot -Confirm:$false } |
      Should -Throw '*AllowUserGlobalWrite*'
    { Set-ClaudeSettingsSymlink -SharedVSCodeWorktreePath $script:sharedRoot -AllowUserGlobalWrite -Confirm:$false } |
      Should -Throw '*CheckpointConfirmed*'
  }

  It 'does not create ~/.claude when WhatIf declines the operation' {
    Set-ClaudeSettingsSymlink `
      -SharedVSCodeWorktreePath $script:sharedRoot `
      -WhatIf `
      -Confirm:$false

    Test-Path -LiteralPath (Join-Path $script:userRoot '.claude') | Should -BeFalse
  }

  It 'renders a real settings file whose managed keys match the overlay and unmanaged keys are preserved' {
    $claudeRoot = Join-Path $script:userRoot '.claude'
    $settingsPath = Join-Path $claudeRoot 'settings.json'
    New-Item -ItemType Directory -Path $claudeRoot -Force | Out-Null
    [IO.File]::WriteAllText(
      $settingsPath,
      (@{
          permissions = @{ defaultMode = 'bypassPermissions'; allow = @('old') }
          localPreference = 'keep-me'
        } | ConvertTo-Json -Depth 10),
      [Text.UTF8Encoding]::new($false)
    )

    $result = Set-ClaudeSettingsSymlink `
      -SharedVSCodeWorktreePath $script:sharedRoot `
      -AllowUserGlobalWrite `
      -CheckpointConfirmed `
      -Confirm:$false

    $settingsItem = Get-Item -LiteralPath $settingsPath -Force
    $settingsItem.LinkType | Should -BeNullOrEmpty
    $result.Action | Should -Be 'rendered'
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    $settings.model | Should -Be 'sonnet'
    $settings.permissions.defaultMode | Should -Be 'acceptEdits'
    $settings.permissions.allow | Should -Contain 'PowerShell(:*)'
    $settings.env.CLAUDE_CODE_SHELL | Should -Be 'pwsh'
    $settings.hooks.PreToolUse[0].hooks[0].command | Should -Match 'C:\\GitHub\\SharedVSCode'
    ($settings | ConvertTo-Json -Depth 20) | Should -Not -Match 'WORKTREE_PATH'
    $settings.localPreference | Should -Be 'keep-me'
  }

  It 'rejects a rendered projection that still contains a worktree placeholder' {
    [IO.File]::WriteAllText(
      $script:renderedSettingsPath,
      '{"permissions":{"additionalDirectories":["${STABLE_WORKTREE_PATH_SHAREDVSCODE}"]}}',
      [Text.UTF8Encoding]::new($false)
    )

    {
      Set-ClaudeSettingsSymlink `
        -SharedVSCodeWorktreePath $script:sharedRoot `
        -AllowUserGlobalWrite `
        -CheckpointConfirmed `
        -Confirm:$false
    } | Should -Throw '*unresolved worktree placeholders*'
  }

  It 'replaces a symlink target with a real settings file' {
    $claudeRoot = Join-Path $script:userRoot '.claude'
    $settingsPath = Join-Path $claudeRoot 'settings.json'
    $legacyTarget = Join-Path $script:sharedRoot 'claude-settings.json'
    New-Item -ItemType Directory -Path $claudeRoot -Force | Out-Null
    [IO.File]::WriteAllText($legacyTarget, '{"legacy":true}', [Text.UTF8Encoding]::new($false))
    $link = New-Item -ItemType SymbolicLink -Path $settingsPath -Target $legacyTarget `
      -ErrorAction SilentlyContinue
    if (-not $link) {
      Set-ItResult -Skipped -Because 'the current token cannot create symbolic links'
      return
    }

    Set-ClaudeSettingsSymlink `
      -SharedVSCodeWorktreePath $script:sharedRoot `
      -AllowUserGlobalWrite `
      -CheckpointConfirmed `
      -Confirm:$false

    $settingsItem = Get-Item -LiteralPath $settingsPath -Force
    $settingsItem.LinkType | Should -BeNullOrEmpty
    (Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json).model | Should -Be 'sonnet'
  }

  It 'restores the original target bytes when a post-backup failure is injected' {
    $claudeRoot = Join-Path $script:userRoot '.claude'
    $settingsPath = Join-Path $claudeRoot 'settings.json'
    New-Item -ItemType Directory -Path $claudeRoot -Force | Out-Null
    [IO.File]::WriteAllText(
      $settingsPath,
      '{"localPreference":"original"}',
      [Text.UTF8Encoding]::new($false)
    )

    {
      Set-ClaudeSettingsSymlink `
        -SharedVSCodeWorktreePath $script:sharedRoot `
        -AllowUserGlobalWrite `
        -CheckpointConfirmed `
        -InjectFailureAfterBackup `
        -Confirm:$false
    } | Should -Throw '*Injected failure*'

    (Get-Content -LiteralPath $settingsPath -Raw) | Should -BeExactly '{"localPreference":"original"}'
    (Get-ChildItem -LiteralPath (Join-Path $script:sharedRoot '_generated\ClaudeSettingsBackups') -File).Count |
      Should -Be 1
  }
}

BeforeAll {
  $script:moduleName = 'ATAP.Utilities.BuildTooling.PowerShell'
  $script:modulePath = Join-Path $PSScriptRoot '..\..\ATAP.Utilities.BuildTooling.PowerShell.psd1'
  Remove-Module $script:moduleName -Force -ErrorAction SilentlyContinue
  Import-Module $script:modulePath -Force
}

Describe 'Set-DownstreamSharedVSCodeContext [public]' {
  BeforeAll {
    # Build fake SharedVSCode tree and fake downstream repo
    $script:tempDir      = Join-Path ([System.IO.Path]::GetTempPath()) "sdsvc_$([guid]::NewGuid().ToString('N'))"
    $script:fakeGitRoot  = $script:tempDir
    $script:fakeShared   = Join-Path $script:fakeGitRoot 'SharedVSCode'
    $script:fakeRepoRoot = Join-Path $script:tempDir 'DownstreamRepo'
    $script:wrongRepoRoot = Join-Path $script:tempDir 'WrongRepo'

    New-Item -ItemType Directory -Path $script:fakeShared -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:fakeShared '.githooks') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:fakeShared 'GitTemplates') -Force | Out-Null
    New-Item -ItemType Directory -Path $script:fakeRepoRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $script:wrongRepoRoot -Force | Out-Null

    Set-Content -Path (Join-Path $script:fakeShared '.gitconfig')    -Value '[core]'      -Encoding UTF8
    Set-Content -Path (Join-Path $script:fakeShared '.gitattributes') -Value '* text=auto' -Encoding UTF8
    Set-Content -Path (Join-Path $script:fakeShared 'GitTemplates\git.commit.template.txt') -Value 'template' -Encoding UTF8

    $script:wsFile = Join-Path $script:fakeRepoRoot 'Test.code-workspace'
    @{
      folders  = @(@{ path = '.' })
      settings = @{
        'atap.sharedVSCode.templateRef' = 'main'
        'atap.sharedVSCode.profile'     = 'default'
      }
    } | ConvertTo-Json -Depth 10 | Set-Content -Path $script:wsFile -Encoding UTF8
  }

  AfterAll {
    Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  BeforeEach {
    Mock Assert-GitAvailable -ModuleName $script:moduleName { }
    Mock git -ModuleName $script:moduleName { return $null }
  }

  It 'Creates a generated .gitattributes in the downstream repo root' {
    Set-DownstreamSharedVSCodeContext `
      -WorkspaceFiles @($script:wsFile) `
      -GitRoot $script:fakeGitRoot `
      -SharedVSCodeRepoName 'SharedVSCode'

    $gaPath = Join-Path $script:fakeRepoRoot '.gitattributes'
    Test-Path $gaPath | Should -BeTrue
    $content = Get-Content -Path $gaPath -Raw
    $content | Should -Match 'GENERATED FILE'
    $content | Should -Match 'text=auto'
  }

  It 'Creates a generated .gitconfig.shared in the downstream repo root' {
    Set-DownstreamSharedVSCodeContext `
      -WorkspaceFiles @($script:wsFile) `
      -GitRoot $script:fakeGitRoot `
      -SharedVSCodeRepoName 'SharedVSCode'

    $gcPath = Join-Path $script:fakeRepoRoot '.gitconfig.shared'
    Test-Path $gcPath | Should -BeTrue
    $content = Get-Content -Path $gcPath -Raw
    $content | Should -Match 'GENERATED FILE'
    $content | Should -Match '\[core\]'
  }

  It 'Calls git config for commit.template, include.path, and core.hooksPath' {
    Set-DownstreamSharedVSCodeContext `
      -WorkspaceFiles @($script:wsFile) `
      -GitRoot $script:fakeGitRoot `
      -SharedVSCodeRepoName 'SharedVSCode'

    # commit.template + include.path + core.hooksPath = 3 calls
    Should -Invoke git -ModuleName $script:moduleName -Times 3 -Exactly -Scope It
  }

  It 'Skips core.hooksPath when hooks directory does not exist' {
    # Remove hooks directory
    $hooksDir = Join-Path $script:fakeShared '.githooks'
    Remove-Item -Path $hooksDir -Recurse -Force

    Set-DownstreamSharedVSCodeContext `
      -WorkspaceFiles @($script:wsFile) `
      -GitRoot $script:fakeGitRoot `
      -SharedVSCodeRepoName 'SharedVSCode'

    # Only commit.template + include.path = 2 calls
    Should -Invoke git -ModuleName $script:moduleName -Times 2 -Exactly -Scope It

    # Recreate hooks dir for other tests
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
  }

  It 'Uses New-GeneratedFileContent (private) to stamp downstream files' {
    InModuleScope $script:moduleName {
      Mock New-GeneratedFileContent {
        return "# MOCKED HEADER`n$( Get-Content -Path $SourcePath -Raw -Encoding UTF8 )"
      }
    }

    Set-DownstreamSharedVSCodeContext `
      -WorkspaceFiles @($script:wsFile) `
      -GitRoot $script:fakeGitRoot `
      -SharedVSCodeRepoName 'SharedVSCode'

    Should -Invoke New-GeneratedFileContent -ModuleName $script:moduleName -Times 2 -Exactly -Scope It
    $gaContent = Get-Content -Path (Join-Path $script:fakeRepoRoot '.gitattributes') -Raw
    $gaContent | Should -Match 'MOCKED HEADER'
  }

  Context 'LF-only, BOM-free, idempotent output (Task 16.85)' {
    BeforeAll {
      $script:expectedFor = {
        param([string]$SourceName, [string]$SourceText)
        (@(
            '# ==================================================================='
            '# GENERATED FILE - DO NOT EDIT DIRECTLY'
            "# Source: SharedVSCode/$SourceName"
            '# Regenerate using Set-DownstreamSharedVSCodeContext'
            '# ==================================================================='
            ''
          ) -join "`n") + $SourceText + "`n"
      }
      $script:invokeContext = {
        Set-DownstreamSharedVSCodeContext `
          -WorkspaceFiles @($script:wsFile) `
          -GitRoot $script:fakeGitRoot `
          -SharedVSCodeRepoName 'SharedVSCode'
      }
    }

    BeforeEach {
      # LF sources shaped like the real SharedVSCode files (trailing LF, no BOM).
      $script:attrSource = "* text=auto eol=lf`n*.cmd text eol=crlf`n"
      $script:configSource = "[alias]`n`tst = status`n"
      [IO.File]::WriteAllText((Join-Path $script:fakeShared '.gitattributes'), $script:attrSource, [Text.UTF8Encoding]::new($false))
      [IO.File]::WriteAllText((Join-Path $script:fakeShared '.gitconfig'), $script:configSource, [Text.UTF8Encoding]::new($false))
      Remove-Item (Join-Path $script:fakeRepoRoot '.gitattributes'), (Join-Path $script:fakeRepoRoot '.gitconfig.shared') -ErrorAction SilentlyContinue
    }

    It 'writes both files LF-only with no BOM, byte-equal to the committed downstream form' {
      & $script:invokeContext

      foreach ($case in @(
          @{ Target = '.gitattributes'; Name = '.gitattributes'; Source = $script:attrSource }
          @{ Target = '.gitconfig.shared'; Name = '.gitconfig'; Source = $script:configSource })) {
        $bytes = [IO.File]::ReadAllBytes((Join-Path $script:fakeRepoRoot $case.Target))
        $bytes | Should -Not -Contain ([byte]13)
        ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
        [Text.Encoding]::UTF8.GetString($bytes) | Should -BeExactly (& $script:expectedFor $case.Name $case.Source)
      }
    }

    It 'normalizes a CRLF source to LF' {
      [IO.File]::WriteAllText((Join-Path $script:fakeShared '.gitattributes'), ($script:attrSource -replace "`n", "`r`n"), [Text.UTF8Encoding]::new($false))

      & $script:invokeContext

      $text = [IO.File]::ReadAllText((Join-Path $script:fakeRepoRoot '.gitattributes'))
      $text | Should -Not -Match "`r"
      $text | Should -BeExactly (& $script:expectedFor '.gitattributes' $script:attrSource)
    }

    It 'does not rewrite unchanged files on a second run' {
      & $script:invokeContext
      $paths = @((Join-Path $script:fakeRepoRoot '.gitattributes'), (Join-Path $script:fakeRepoRoot '.gitconfig.shared'))
      $marker = [datetime]::new(2001, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
      foreach ($p in $paths) { [IO.File]::SetLastWriteTimeUtc($p, $marker) }
      $before = $paths | ForEach-Object { (Get-FileHash -LiteralPath $_).Hash }

      & $script:invokeContext

      foreach ($p in $paths) { [IO.File]::GetLastWriteTimeUtc($p) | Should -Be $marker }
      ($paths | ForEach-Object { (Get-FileHash -LiteralPath $_).Hash }) | Should -Be $before
    }

    It 'repairs an existing mixed-EOL file left by the previous writer' {
      $mixed = (& $script:expectedFor '.gitattributes' $script:attrSource) -replace '^((?:[^\n]*\n){5})', { $_.Groups[1].Value -replace "`n", "`r`n" }
      [IO.File]::WriteAllText((Join-Path $script:fakeRepoRoot '.gitattributes'), $mixed, [Text.UTF8Encoding]::new($false))

      & $script:invokeContext

      [IO.File]::ReadAllText((Join-Path $script:fakeRepoRoot '.gitattributes')) |
        Should -BeExactly (& $script:expectedFor '.gitattributes' $script:attrSource)
    }
  }

  It 'Targets the repository that owns the workspace file rather than the caller location' {
    Set-DownstreamSharedVSCodeContext `
      -WorkspaceFiles @($script:wsFile) `
      -GitRoot $script:fakeGitRoot `
      -SharedVSCodeRepoName 'SharedVSCode'

    Test-Path (Join-Path $script:fakeRepoRoot '.gitattributes') | Should -BeTrue
    Test-Path (Join-Path $script:wrongRepoRoot '.gitattributes') | Should -BeFalse
  }
}

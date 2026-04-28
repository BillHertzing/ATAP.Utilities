BeforeAll {
  . "$PSScriptRoot\..\Import-SharedVSCodeFunctions.ps1"
}

Describe 'Set-DownstreamSharedVSCodeContext [public]' {
  BeforeAll {
    # Build fake SharedVSCode tree and fake downstream repo
    $script:tempDir      = Join-Path ([System.IO.Path]::GetTempPath()) "sdsvc_$([guid]::NewGuid().ToString('N'))"
    $script:fakeGitRoot  = $script:tempDir
    $script:fakeShared   = Join-Path $script:fakeGitRoot 'SharedVSCode'
    $script:fakeRepoRoot = Join-Path $script:tempDir 'DownstreamRepo'

    New-Item -ItemType Directory -Path $script:fakeShared -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:fakeShared '.githooks') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:fakeShared 'GitTemplates') -Force | Out-Null
    New-Item -ItemType Directory -Path $script:fakeRepoRoot -Force | Out-Null

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
    Mock Assert-GitAvailable { }
    Mock Get-RepoRoot { return $script:fakeRepoRoot }
    Mock git { return $null }
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
    Should -Invoke git -Times 3 -Exactly -Scope It
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
    Should -Invoke git -Times 2 -Exactly -Scope It

    # Recreate hooks dir for other tests
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
  }

  It 'Uses New-GeneratedFileContent (private) to stamp downstream files' {
    Mock New-GeneratedFileContent {
      return "# MOCKED HEADER`n$( Get-Content -Path $SourcePath -Raw -Encoding UTF8 )"
    }

    Set-DownstreamSharedVSCodeContext `
      -WorkspaceFiles @($script:wsFile) `
      -GitRoot $script:fakeGitRoot `
      -SharedVSCodeRepoName 'SharedVSCode'

    Should -Invoke New-GeneratedFileContent -Times 2 -Exactly -Scope It
    $gaContent = Get-Content -Path (Join-Path $script:fakeRepoRoot '.gitattributes') -Raw
    $gaContent | Should -Match 'MOCKED HEADER'
  }
}

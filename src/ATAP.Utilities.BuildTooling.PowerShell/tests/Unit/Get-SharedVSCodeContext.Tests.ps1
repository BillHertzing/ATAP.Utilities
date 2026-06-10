BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  . (Join-Path $moduleRoot 'private\Get-WorkspaceJson.ps1')
  . (Join-Path $moduleRoot 'private\Resolve-WorkspaceFiles.ps1')
  . (Join-Path $moduleRoot 'private\Get-SharedVSCodeRootFromTemplateRef.ps1')
  . (Join-Path $moduleRoot 'public\Get-SharedVSCodeContext.ps1')
}

# Helper: builds a fake SharedVSCode tree and returns its paths
function New-FakeSharedVSCodeTree {
  param([string]$RootName = 'SharedVSCode')

  $tempDir   = Join-Path ([System.IO.Path]::GetTempPath()) "gsvc_$([guid]::NewGuid().ToString('N'))"
  $gitRoot   = $tempDir
  $sharedRoot = Join-Path $gitRoot $RootName

  New-Item -ItemType Directory -Path $sharedRoot -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $sharedRoot '.githooks') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $sharedRoot 'GitTemplates') -Force | Out-Null

  Set-Content -Path (Join-Path $sharedRoot '.gitconfig')    -Value '[core]'      -Encoding UTF8
  Set-Content -Path (Join-Path $sharedRoot '.gitattributes') -Value '* text=auto' -Encoding UTF8
  Set-Content -Path (Join-Path $sharedRoot 'GitTemplates\git.commit.template.txt') -Value 'template' -Encoding UTF8

  return @{
    TempDir    = $tempDir
    GitRoot    = $gitRoot
    SharedRoot = $sharedRoot
  }
}

Describe 'Get-SharedVSCodeContext [public]' {
  BeforeAll {
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "gsvc_$([guid]::NewGuid().ToString('N'))"
    $gitRoot = $tempDir
    $sharedRoot = Join-Path $gitRoot 'SharedVSCode'

    New-Item -ItemType Directory -Path $sharedRoot -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $sharedRoot '.githooks') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $sharedRoot 'GitTemplates') -Force | Out-Null

    Set-Content -Path (Join-Path $sharedRoot '.gitconfig') -Value '[core]' -Encoding UTF8
    Set-Content -Path (Join-Path $sharedRoot '.gitattributes') -Value '* text=auto' -Encoding UTF8
    Set-Content -Path (Join-Path $sharedRoot 'GitTemplates\git.commit.template.txt') -Value 'template' -Encoding UTF8

    $script:tree = @{
      TempDir    = $tempDir
      GitRoot    = $gitRoot
      SharedRoot = $sharedRoot
    }
  }

  AfterAll {
    Remove-Item -Path $script:tree.TempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  Context 'Happy path — workspace points to main' {
    It 'Returns a context object with correct properties' {
      $wsFile = Join-Path $script:tree.TempDir 'Test.code-workspace'
      @{
        folders  = @(@{ path = '.' })
        settings = @{
          'atap.sharedVSCode.templateRef' = 'main'
          'atap.sharedVSCode.profile'     = 'default'
        }
      } | ConvertTo-Json -Depth 10 | Set-Content -Path $wsFile -Encoding UTF8

      $result = Get-SharedVSCodeContext `
        -WorkspaceFiles @($wsFile) `
        -GitRoot $script:tree.GitRoot `
        -SharedVSCodeRepoName 'SharedVSCode'

      $result.Count | Should -Be 1
      $result[0].TemplateRef  | Should -Be 'main'
      $result[0].Profile      | Should -Be 'default'
      $result[0].SharedRoot   | Should -Be $script:tree.SharedRoot
      $result[0].GitConfig    | Should -Match '\.gitconfig$'
      $result[0].HooksPath    | Should -Match '\.githooks$'
    }
  }

  Context 'Profile defaults to "default" when missing' {
    It 'Fills in the default profile' {
      $wsFile = Join-Path $script:tree.TempDir 'NoProfile.code-workspace'
      @{
        folders  = @(@{ path = '.' })
        settings = @{ 'atap.sharedVSCode.templateRef' = 'main' }
      } | ConvertTo-Json -Depth 10 | Set-Content -Path $wsFile -Encoding UTF8

      $result = Get-SharedVSCodeContext `
        -WorkspaceFiles @($wsFile) `
        -GitRoot $script:tree.GitRoot `
        -SharedVSCodeRepoName 'SharedVSCode'

      $result[0].Profile | Should -Be 'default'
    }
  }

  Context 'Error: templateRef is missing' {
    It 'Throws' {
      $wsFile = Join-Path $script:tree.TempDir 'BadRef.code-workspace'
      @{
        folders  = @(@{ path = '.' })
        settings = @{}
      } | ConvertTo-Json -Depth 10 | Set-Content -Path $wsFile -Encoding UTF8

      { Get-SharedVSCodeContext `
          -WorkspaceFiles @($wsFile) `
          -GitRoot $script:tree.GitRoot
      } | Should -Throw '*missing setting*templateRef*'
    }
  }

  Context 'Error: settings object is missing entirely' {
    It 'Throws' {
      $wsFile = Join-Path $script:tree.TempDir 'NoSettings.code-workspace'
      Set-Content -Path $wsFile -Value '{"folders":[{"path":"."}]}' -Encoding UTF8

      { Get-SharedVSCodeContext `
          -WorkspaceFiles @($wsFile) `
          -GitRoot $script:tree.GitRoot
      } | Should -Throw '*missing the settings object*'
    }
  }

  Context 'Error: SharedVSCode root does not exist' {
    It 'Throws' {
      $wsFile = Join-Path $script:tree.TempDir 'Ghost.code-workspace'
      @{
        folders  = @(@{ path = '.' })
        settings = @{ 'atap.sharedVSCode.templateRef' = 'nonexistent-worktree' }
      } | ConvertTo-Json -Depth 10 | Set-Content -Path $wsFile -Encoding UTF8

      { Get-SharedVSCodeContext `
          -WorkspaceFiles @($wsFile) `
          -GitRoot $script:tree.GitRoot
      } | Should -Throw '*does not exist*'
    }
  }

  Context 'Error: required asset file is missing' {
    It 'Throws when .gitconfig is absent' {
      $incomplete = Join-Path $script:tree.GitRoot 'IncompleteVSCode'
      New-Item -ItemType Directory -Path $incomplete -Force | Out-Null
      # only create .gitattributes and commit template, skip .gitconfig
      Set-Content -Path (Join-Path $incomplete '.gitattributes') -Value '' -Encoding UTF8
      New-Item -ItemType Directory -Path (Join-Path $incomplete 'GitTemplates') -Force | Out-Null
      Set-Content -Path (Join-Path $incomplete 'GitTemplates\git.commit.template.txt') -Value '' -Encoding UTF8

      $wsFile = Join-Path $script:tree.TempDir 'MissingAsset.code-workspace'
      @{
        folders  = @(@{ path = '.' })
        settings = @{ 'atap.sharedVSCode.templateRef' = 'IncompleteVSCode' }
      } | ConvertTo-Json -Depth 10 | Set-Content -Path $wsFile -Encoding UTF8

      { Get-SharedVSCodeContext `
          -WorkspaceFiles @($wsFile) `
          -GitRoot $script:tree.GitRoot
      } | Should -Throw '*asset not found*'
    }
  }

  Context 'Multiple workspace files' {
    It 'Returns a context object per workspace file' {
      $ws1 = Join-Path $script:tree.TempDir 'Multi1.code-workspace'
      $ws2 = Join-Path $script:tree.TempDir 'Multi2.code-workspace'
      $json = @{
        folders  = @(@{ path = '.' })
        settings = @{ 'atap.sharedVSCode.templateRef' = 'main' }
      } | ConvertTo-Json -Depth 10
      Set-Content -Path $ws1 -Value $json -Encoding UTF8
      Set-Content -Path $ws2 -Value $json -Encoding UTF8

      $result = Get-SharedVSCodeContext `
        -WorkspaceFiles @($ws1, $ws2) `
        -GitRoot $script:tree.GitRoot `
        -SharedVSCodeRepoName 'SharedVSCode'

      $result.Count | Should -Be 2
    }
  }
}

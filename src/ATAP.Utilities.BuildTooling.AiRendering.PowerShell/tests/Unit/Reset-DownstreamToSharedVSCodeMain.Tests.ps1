BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param([Parameter(ValueFromRemainingArguments = $true)] $Rest)
    }
  }
  function global:Set-WorkspaceSharedVSCodeReference {
    param(
      [string[]] $WorkspaceFiles,
      [string] $TemplateRef,
      [string] $Profile
    )
    foreach ($workspaceFile in $WorkspaceFiles) {
      $workspace = Get-Content -LiteralPath $workspaceFile -Raw | ConvertFrom-Json
      $workspace.settings.'atap.sharedVSCode.templateRef' = $TemplateRef
      $workspace.settings.'atap.sharedVSCode.profile' = $Profile
      $workspace | ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath $workspaceFile -Encoding UTF8
    }
  }
  function global:Set-DownstreamSharedVSCodeContext {
    param(
      [string[]] $WorkspaceFiles,
      [string] $GitRoot,
      [string] $SharedVSCodeRepoName,
      [string] $SharedHooksSubPath,
      [string] $CommitTemplateRelativePath
    )
  }

  . "$PSScriptRoot\..\..\public\Reset-DownstreamToSharedVSCodeMain.ps1"
}

AfterAll {
  Remove-Item Function:\Write-PSFMessage -Force -ErrorAction SilentlyContinue
  Remove-Item Function:\Set-WorkspaceSharedVSCodeReference -Force -ErrorAction SilentlyContinue
  Remove-Item Function:\Set-DownstreamSharedVSCodeContext -Force -ErrorAction SilentlyContinue
}

Describe 'Reset-DownstreamToSharedVSCodeMain [public]' -Tag 'Unit' {
  BeforeAll {
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "rdm_test_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
  }

  AfterAll {
    Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  BeforeEach {
    $script:wsFile = Join-Path $script:tempDir "Reset_$([guid]::NewGuid().ToString('N')).code-workspace"
    @{
      folders = @(@{ path = '.' })
      settings = @{
        'atap.sharedVSCode.templateRef' = 'SharedVSCode-wt-5-sprint-0003-work-items'
        'atap.sharedVSCode.profile' = 'sprint-0003'
      }
    } | ConvertTo-Json -Depth 10 | Set-Content -Path $script:wsFile -Encoding UTF8

    Mock Set-DownstreamSharedVSCodeContext { }
  }

  It 'resets templateRef to main' {
    Reset-DownstreamToSharedVSCodeMain -WorkspaceFiles @($script:wsFile)

    $result = Get-Content -LiteralPath $script:wsFile -Raw | ConvertFrom-Json
    $result.settings.'atap.sharedVSCode.templateRef' | Should -Be 'main'
  }

  It 'resets profile to default' {
    Reset-DownstreamToSharedVSCodeMain -WorkspaceFiles @($script:wsFile)

    $result = Get-Content -LiteralPath $script:wsFile -Raw | ConvertFrom-Json
    $result.settings.'atap.sharedVSCode.profile' | Should -Be 'default'
  }

  It 'calls Set-DownstreamSharedVSCodeContext to refresh plumbing' {
    Reset-DownstreamToSharedVSCodeMain -WorkspaceFiles @($script:wsFile)

    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 1 -Exactly -Scope It
  }

  It 'delegates pointer update to Set-WorkspaceSharedVSCodeReference' {
    Mock Set-WorkspaceSharedVSCodeReference { }

    Reset-DownstreamToSharedVSCodeMain -WorkspaceFiles @($script:wsFile)

    Should -Invoke Set-WorkspaceSharedVSCodeReference -Times 1 -Exactly -Scope It `
      -ParameterFilter { $TemplateRef -eq 'main' -and $Profile -eq 'default' }
  }
}

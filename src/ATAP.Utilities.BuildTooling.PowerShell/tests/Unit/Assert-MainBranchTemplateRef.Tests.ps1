BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  . (Join-Path $moduleRoot 'private\Get-WorkspaceJson.ps1')
  . (Join-Path $moduleRoot 'private\Resolve-WorkspaceFiles.ps1')
  . (Join-Path $moduleRoot 'public\Assert-MainBranchTemplateRef.ps1')
}

Describe 'Assert-MainBranchTemplateRef [public]' {
  BeforeAll {
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ambtr_test_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
  }

  AfterAll {
    Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  Context 'All workspace files point to main' {
    It 'Does not throw' {
      $wsFile = Join-Path $script:tempDir 'Good.code-workspace'
      @{
        folders  = @(@{ path = '.' })
        settings = @{ 'atap.sharedVSCode.templateRef' = 'main' }
      } | ConvertTo-Json -Depth 10 | Set-Content -Path $wsFile -Encoding UTF8

      { Assert-MainBranchTemplateRef -WorkspaceFiles @($wsFile) } | Should -Not -Throw
    }
  }

  Context 'A workspace file points to a sprint ref' {
    It 'Throws a merge-gate violation naming the ref' {
      $wsFile = Join-Path $script:tempDir 'Sprint.code-workspace'
      @{
        folders  = @(@{ path = '.' })
        settings = @{ 'atap.sharedVSCode.templateRef' = 'SharedVSCode-wt-5-sprint-0003-work-items' }
      } | ConvertTo-Json -Depth 10 | Set-Content -Path $wsFile -Encoding UTF8

      { Assert-MainBranchTemplateRef -WorkspaceFiles @($wsFile) } |
        Should -Throw '*Merge-gate violation*'
    }
  }

  Context 'templateRef is missing' {
    It 'Throws a merge-gate violation for missing ref' {
      $wsFile = Join-Path $script:tempDir 'Missing.code-workspace'
      @{
        folders  = @(@{ path = '.' })
        settings = @{}
      } | ConvertTo-Json -Depth 10 | Set-Content -Path $wsFile -Encoding UTF8

      { Assert-MainBranchTemplateRef -WorkspaceFiles @($wsFile) } |
        Should -Throw '*Merge-gate violation*missing*'
    }
  }

  Context 'Settings object is absent' {
    It 'Throws a merge-gate violation' {
      $wsFile = Join-Path $script:tempDir 'NoSettings.code-workspace'
      Set-Content -Path $wsFile -Value '{"folders":[{"path":"."}]}' -Encoding UTF8

      { Assert-MainBranchTemplateRef -WorkspaceFiles @($wsFile) } |
        Should -Throw '*Merge-gate violation*'
    }
  }

  Context 'Multiple files — one good, one bad' {
    It 'Reports the offending file in the error message' {
      $wsGood = Join-Path $script:tempDir 'MultiGood.code-workspace'
      @{
        folders  = @(@{ path = '.' })
        settings = @{ 'atap.sharedVSCode.templateRef' = 'main' }
      } | ConvertTo-Json -Depth 10 | Set-Content -Path $wsGood -Encoding UTF8

      $wsBad = Join-Path $script:tempDir 'MultiBad.code-workspace'
      @{
        folders  = @(@{ path = '.' })
        settings = @{ 'atap.sharedVSCode.templateRef' = 'sprint-ref' }
      } | ConvertTo-Json -Depth 10 | Set-Content -Path $wsBad -Encoding UTF8

      { Assert-MainBranchTemplateRef -WorkspaceFiles @($wsGood, $wsBad) } |
        Should -Throw '*MultiBad*'
    }
  }

  Context 'Multiple files — all good' {
    It 'Does not throw' {
      $ws1 = Join-Path $script:tempDir 'AllGood1.code-workspace'
      $ws2 = Join-Path $script:tempDir 'AllGood2.code-workspace'
      $json = @{
        folders  = @(@{ path = '.' })
        settings = @{ 'atap.sharedVSCode.templateRef' = 'main' }
      } | ConvertTo-Json -Depth 10
      Set-Content -Path $ws1 -Value $json -Encoding UTF8
      Set-Content -Path $ws2 -Value $json -Encoding UTF8

      { Assert-MainBranchTemplateRef -WorkspaceFiles @($ws1, $ws2) } | Should -Not -Throw
    }
  }

  Context 'Uses private helpers Resolve-WorkspaceFiles and Get-WorkspaceJson' {
    It 'Calls through Resolve-WorkspaceFiles for path resolution' {
      Mock Resolve-WorkspaceFiles { return @($WorkspaceFiles[0]) }

      $wsFile = Join-Path $script:tempDir 'DelegateTest.code-workspace'
      @{
        folders  = @(@{ path = '.' })
        settings = @{ 'atap.sharedVSCode.templateRef' = 'main' }
      } | ConvertTo-Json -Depth 10 | Set-Content -Path $wsFile -Encoding UTF8

      { Assert-MainBranchTemplateRef -WorkspaceFiles @($wsFile) } | Should -Not -Throw
      Should -Invoke Resolve-WorkspaceFiles -Times 1 -Exactly -Scope It
    }
  }
}

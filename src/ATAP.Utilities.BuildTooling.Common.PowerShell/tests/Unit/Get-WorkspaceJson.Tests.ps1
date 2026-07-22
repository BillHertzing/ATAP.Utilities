BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $manifestPath = Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.Common.PowerShell.psd1'
  Import-Module -Name $manifestPath -Force

  $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "common-gwj-$([guid]::NewGuid().ToString('N'))"
  New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
}

AfterAll {
  Remove-Item -LiteralPath $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Get-WorkspaceJson' -Tag 'Unit' {
  It 'returns the parsed workspace object for valid JSON' {
    $workspaceFile = Join-Path $script:tempDir 'valid.code-workspace'
    @{ folders = @(@{ path = '.' }); settings = @{ TemplateRef = 'main' } } |
      ConvertTo-Json -Depth 5 |
      Set-Content -LiteralPath $workspaceFile -Encoding UTF8

    $result = Get-WorkspaceJson -WorkspaceFile $workspaceFile

    $result.settings.TemplateRef | Should -Be 'main'
    $result.folders.Count | Should -Be 1
  }

  It 'throws when the workspace file does not exist' {
    { Get-WorkspaceJson -WorkspaceFile (Join-Path $script:tempDir 'missing.code-workspace') } |
      Should -Throw '*not found*'
  }

  It 'throws when the workspace file contains invalid JSON' {
    $workspaceFile = Join-Path $script:tempDir 'invalid.code-workspace'
    Set-Content -LiteralPath $workspaceFile -Value 'not-json' -Encoding UTF8

    { Get-WorkspaceJson -WorkspaceFile $workspaceFile } | Should -Throw
  }
}

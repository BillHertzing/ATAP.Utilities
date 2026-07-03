BeforeAll {
  . "$PSScriptRoot\..\..\public\Set-WorktreeJunctions.ps1"

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }
}

Describe 'Set-WorktreeJunctions [public]' {
  BeforeEach {
    $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "wt_junctions_$([guid]::NewGuid().ToString('N'))"
    $script:sourceRepo = Join-Path $script:testRoot 'source'
    $script:worktree = Join-Path $script:testRoot 'worktree'
    New-Item -ItemType Directory -Path $script:sourceRepo, $script:worktree -Force | Out-Null

    git -C $script:sourceRepo init --quiet --initial-branch=main
    git -C $script:sourceRepo config user.email 'test@example.invalid'
    git -C $script:sourceRepo config user.name 'Junction Test'
    Set-Content -LiteralPath (Join-Path $script:sourceRepo 'README.md') -Value 'seed' -Encoding UTF8
    git -C $script:sourceRepo add .
    git -C $script:sourceRepo commit --quiet -m seed

    foreach ($name in @('.claude', '.github', '.vscode')) {
      $target = Join-Path $script:testRoot ("target-$($name.TrimStart('.'))")
      New-Item -ItemType Directory -Path $target -Force | Out-Null
      New-Item -ItemType Junction -Path (Join-Path $script:sourceRepo $name) -Target $target -Force | Out-Null
    }
  }

  AfterEach {
    if ($script:testRoot -and (Test-Path -LiteralPath $script:testRoot)) {
      Remove-Item -LiteralPath $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'recreates only the requested stable junction leaf names' {
    $result = Set-WorktreeJunctions `
      -SourceRepoPath $script:sourceRepo `
      -WorktreePath $script:worktree `
      -SourceRepoFolderNames @('.vscode')

    $result.Success | Should -BeTrue
    $result.JunctionsCreated | Should -Be 1
    $result.JunctionsList.RelativePath | Should -Be @('.vscode')
    Test-Path -LiteralPath (Join-Path $script:worktree '.vscode') | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $script:worktree '.claude') | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $script:worktree '.github') | Should -BeFalse
  }
}

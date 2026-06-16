#Requires -Version 7.0

BeforeAll {
  Import-Module "$PSScriptRoot\..\..\ATAP.Utilities.BuildTooling.PowerShell.psd1" -Force

  function New-InvokeGitCommitTestRepo {
    $repo = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $repo -Force | Out-Null

    & git -C $repo init --quiet | Out-Null
    & git -C $repo config user.email 'test@example.invalid' | Out-Null
    & git -C $repo config user.name 'Invoke GitCommit Test' | Out-Null

    Set-Content -LiteralPath (Join-Path -Path $repo -ChildPath 'README.md') -Value 'seed'
    & git -C $repo add . | Out-Null
    & git -C $repo commit -m 'seed commit' --quiet | Out-Null

    return $repo
  }

  function Add-InvokeGitCommitTestFile {
    param(
      [Parameter(Mandatory)]
      [string] $RepoPath,

      [Parameter(Mandatory)]
      [string] $RelativePath,

      [Parameter(Mandatory)]
      [string] $Content
    )

    $absolutePath = Join-Path -Path $RepoPath -ChildPath $RelativePath
    $parent = Split-Path -Path $absolutePath -Parent
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Set-Content -LiteralPath $absolutePath -Value $Content
  }
}

Describe 'Invoke-GitCommit' -Tag 'Unit' {
  BeforeEach {
    $script:repo = New-InvokeGitCommitTestRepo
  }

  It 'creates one commit for a cohesive working tree' {
    Add-InvokeGitCommitTestFile -RepoPath $script:repo -RelativePath 'src/App/app.txt' -Content 'one'
    Add-InvokeGitCommitTestFile -RepoPath $script:repo -RelativePath 'src/App/more.txt' -Content 'two'

    Invoke-GitCommit `
      -RepoPath $script:repo `
      -Message 'feat(app): update app files' `
      -SkipLockFileGuard `
      -Confirm:$false

    $subjects = @(& git -C $script:repo log --format='%s' -2)
    $subjects[0] | Should -Be 'feat(app): update app files'
    $subjects[1] | Should -Be 'seed commit'

    $body = & git -C $script:repo log -1 --format='%B'
    ($body -join "`n") | Should -Match '(?m)^Co-Authored-By:'
  }

  It 'creates separate commits for explicit groups and runs the lock guard for each group' {
    Add-InvokeGitCommitTestFile -RepoPath $script:repo -RelativePath 'src/App/app.txt' -Content 'app change'
    Add-InvokeGitCommitTestFile -RepoPath $script:repo -RelativePath 'docs/readme.md' -Content 'doc change'

    Mock Assert-LockFilesClean { } -ModuleName ATAP.Utilities.BuildTooling.PowerShell

    Invoke-GitCommit `
      -RepoPath $script:repo `
      -Groups @(
        @{ Paths = @('src/App/**'); Message = 'feat(app): update app flow' },
        @{ Paths = @('docs/**'); Message = 'docs(readme): update docs' }
      ) `
      -Confirm:$false

    Assert-MockCalled Assert-LockFilesClean -ModuleName ATAP.Utilities.BuildTooling.PowerShell -Times 2 -Exactly -Scope It

    $log = @(& git -C $script:repo log --format='%H|%s' -2)
    $log[0] | Should -Match '\|docs\(readme\): update docs$'
    $log[1] | Should -Match '\|feat\(app\): update app flow$'

    $docsCommit = ($log[0] -split '\|')[0]
    $appCommit = ($log[1] -split '\|')[0]
    $docsPaths = @(& git -C $script:repo show --name-only --format= $docsCommit | Where-Object { $_ })
    $appPaths = @(& git -C $script:repo show --name-only --format= $appCommit | Where-Object { $_ })

    $docsPaths | Should -Contain 'docs/readme.md'
    $docsPaths | Should -Not -Contain 'src/App/app.txt'
    $appPaths | Should -Contain 'src/App/app.txt'
    $appPaths | Should -Not -Contain 'docs/readme.md'

    $docsBody = & git -C $script:repo log -1 --format='%B' $docsCommit
    ($docsBody -join "`n") | Should -Match '(?m)^Co-Authored-By:'
  }

  It 'refuses to collapse multiple detected scopes into one supplied message by default' {
    Add-InvokeGitCommitTestFile -RepoPath $script:repo -RelativePath 'src/App/app.txt' -Content 'app change'
    Add-InvokeGitCommitTestFile -RepoPath $script:repo -RelativePath 'docs/readme.md' -Content 'doc change'

    {
      Invoke-GitCommit `
        -RepoPath $script:repo `
        -Message 'chore(repo): collapse unrelated changes' `
        -SkipLockFileGuard `
        -Confirm:$false
    } | Should -Throw '*multiple change groups*'
  }
}


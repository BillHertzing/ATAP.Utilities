BeforeAll {
  Import-Module "$PSScriptRoot\..\..\ATAP.Utilities.BuildTooling.PowerShell.psd1" -Force
}

Describe 'Assert-LockFilesClean' {
  BeforeEach {
    $script:repo = Join-Path -Path $TestDrive -ChildPath 'repo'
    New-Item -ItemType Directory -Path $script:repo -Force | Out-Null

    & git -C $script:repo init | Out-Null
    & git -C $script:repo config user.email 'test@example.invalid' | Out-Null
    & git -C $script:repo config user.name 'Lock Guard Test' | Out-Null

    $projectDir = Join-Path -Path $script:repo -ChildPath 'src\App'
    New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path -Path $projectDir -ChildPath 'App.csproj') -Value '<Project Sdk="Microsoft.NET.Sdk" />'
    Set-Content -LiteralPath (Join-Path -Path $projectDir -ChildPath 'packages.lock.json') -Value '{"version":1}'

    & git -C $script:repo add . | Out-Null
    & git -C $script:repo commit -m 'seed lock file' | Out-Null
  }

  It 'passes when tracked lock files are unchanged' {
    $result = Assert-LockFilesClean -RepoPath $script:repo

    $result.AllOk | Should -BeTrue
    $result.Checks.GitStatus.DirtyLockFiles | Should -BeNullOrEmpty
    $result.Checks.GitStatus.MissingTrackedLockFiles | Should -BeNullOrEmpty
  }

  It 'detects dirty packages.lock.json files and throws when requested' {
    Add-Content -LiteralPath (Join-Path -Path $script:repo -ChildPath 'src\App\packages.lock.json') -Value "`n"

    $result = Assert-LockFilesClean -RepoPath $script:repo

    $result.AllOk | Should -BeFalse
    $result.Checks.GitStatus.DirtyLockFiles | Should -Contain 'src/App/packages.lock.json'
    { Assert-LockFilesClean -RepoPath $script:repo -ThrowOnFailure } | Should -Throw '*Lock files are not clean*'
  }

  It 'detects tracked lock files deleted from disk' {
    Remove-Item -LiteralPath (Join-Path -Path $script:repo -ChildPath 'src\App\packages.lock.json') -Force

    $result = Assert-LockFilesClean -RepoPath $script:repo

    $result.AllOk | Should -BeFalse
    $result.Checks.GitStatus.MissingTrackedLockFiles | Should -Contain 'src/App/packages.lock.json'
  }

  It 'ignores excluded sample lock files' {
    $sampleDir = Join-Path -Path $script:repo -ChildPath 'samples\Demo'
    New-Item -ItemType Directory -Path $sampleDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path -Path $sampleDir -ChildPath 'packages.lock.json') -Value '{"version":1}'

    $result = Assert-LockFilesClean -RepoPath $script:repo

    $result.AllOk | Should -BeTrue
  }

  It 'detects projects in a solution filter that are missing lock files' {
    $noLockProjectDir = Join-Path -Path $script:repo -ChildPath 'src\NoLock'
    New-Item -ItemType Directory -Path $noLockProjectDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path -Path $noLockProjectDir -ChildPath 'NoLock.csproj') -Value '<Project Sdk="Microsoft.NET.Sdk" />'

    $solutionFilter = @{
      solution = @{
        path     = 'Repo.sln'
        projects = @(
          'src/App/App.csproj',
          'src/NoLock/NoLock.csproj'
        )
      }
    } | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath (Join-Path -Path $script:repo -ChildPath 'Repo.slnf') -Value $solutionFilter

    $result = Assert-LockFilesClean -RepoPath $script:repo -CheckSolutionFilter -SolutionFilterPath 'Repo.slnf'

    $result.AllOk | Should -BeFalse
    $result.Checks.SolutionFilter.MissingLockFiles.ProjectPath | Should -Contain 'src/NoLock/NoLock.csproj'
  }

  It 'allows documented solution-filter lock-file exceptions' {
    $noLockProjectDir = Join-Path -Path $script:repo -ChildPath 'src\Facade'
    New-Item -ItemType Directory -Path $noLockProjectDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path -Path $noLockProjectDir -ChildPath 'Facade.csproj') -Value '<Project Sdk="Microsoft.NET.Sdk" />'

    $solutionFilter = @{
      solution = @{
        path     = 'Repo.sln'
        projects = @(
          'src/App/App.csproj',
          'src/Facade/Facade.csproj'
        )
      }
    } | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath (Join-Path -Path $script:repo -ChildPath 'Repo.slnf') -Value $solutionFilter

    $result = Assert-LockFilesClean `
      -RepoPath $script:repo `
      -CheckSolutionFilter `
      -SolutionFilterPath 'Repo.slnf' `
      -AllowedMissingLockFileProjectPaths @('src/Facade/Facade.csproj')

    $result.AllOk | Should -BeTrue
  }
}

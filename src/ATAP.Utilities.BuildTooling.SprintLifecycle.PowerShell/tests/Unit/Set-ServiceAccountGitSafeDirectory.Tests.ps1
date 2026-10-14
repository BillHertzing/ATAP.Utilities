BeforeAll {
  $script:functionPath = Join-Path $PSScriptRoot '..' '..' 'public' 'Set-ServiceAccountGitSafeDirectory.ps1'
  . $script:functionPath
}

Describe 'Set-ServiceAccountGitSafeDirectory [public]' {
  BeforeEach {
    $script:configPath = Join-Path $TestDrive '.gitconfig'
    Remove-Item -LiteralPath $script:configPath -Force -ErrorAction SilentlyContinue
    $script:acePath = Join-Path $TestDrive 'Ace-wt-45-Sprint-0015-work-items'
    $script:utilitiesPath = Join-Path $TestDrive 'ATAP.Utilities-wt-137-Sprint-0015-work-items'
    $script:iacPath = Join-Path $TestDrive 'ATAP.IAC-wt-23-Sprint-0015-work-items'
    $script:stablePath = (Join-Path $TestDrive 'ATAP.Utilities').Replace('\', '/')
    $script:unrelatedPath = (Join-Path $TestDrive 'Other-wt-9-Sprint-0015-work-items').Replace('\', '/')
    & git config --file $script:configPath --add safe.directory $script:stablePath
    & git config --file $script:configPath --add safe.directory $script:unrelatedPath
    $LASTEXITCODE | Should -Be 0
  }

  It 'Start adds only exact Ace and ATAP.Utilities sprint worktrees' {
    $result = Set-ServiceAccountGitSafeDirectory -Boundary Start `
      -WorktreePaths @($script:acePath, $script:utilitiesPath, $script:iacPath) `
      -GitConfigPath $script:configPath `
      -Confirm:$false

    $result.Success | Should -BeTrue
    $result.Added.Count | Should -Be 2
    $result.SelectedPaths.Count | Should -Be 2
    $result.SelectedPaths | Should -Contain $script:acePath.Replace('\', '/')
    $result.SelectedPaths | Should -Contain $script:utilitiesPath.Replace('\', '/')
    $result.SelectedPaths | Should -Not -Contain $script:iacPath.Replace('\', '/')
    $result.After | Should -Contain $script:stablePath
    $result.After | Should -Contain $script:unrelatedPath
  }

  It 'Start is idempotent and does not add duplicate values' {
    Set-ServiceAccountGitSafeDirectory -Boundary Start `
      -WorktreePaths @($script:acePath, $script:utilitiesPath) `
      -GitConfigPath $script:configPath `
      -Confirm:$false | Out-Null

    $second = Set-ServiceAccountGitSafeDirectory -Boundary Start `
      -WorktreePaths @($script:acePath, $script:utilitiesPath) `
      -GitConfigPath $script:configPath `
      -Confirm:$false

    $second.Added | Should -BeNullOrEmpty
    $second.Unchanged.Count | Should -Be 2
    @($second.After | Where-Object { $_ -eq $script:acePath.Replace('\', '/') }).Count | Should -Be 1
    @($second.After | Where-Object { $_ -eq $script:utilitiesPath.Replace('\', '/') }).Count | Should -Be 1
  }

  It 'End removes only exact selected sprint entries and preserves stable and unrelated values' {
    Set-ServiceAccountGitSafeDirectory -Boundary Start `
      -WorktreePaths @($script:acePath, $script:utilitiesPath) `
      -GitConfigPath $script:configPath `
      -Confirm:$false | Out-Null

    $result = Set-ServiceAccountGitSafeDirectory -Boundary End `
      -WorktreePaths @($script:acePath, $script:utilitiesPath) `
      -GitConfigPath $script:configPath `
      -Confirm:$false

    $result.Removed.Count | Should -Be 2
    $result.After | Should -Contain $script:stablePath
    $result.After | Should -Contain $script:unrelatedPath
    $result.After | Should -Not -Contain $script:acePath.Replace('\', '/')
    $result.After | Should -Not -Contain $script:utilitiesPath.Replace('\', '/')
  }

  It 'WhatIf projects Start additions without changing the config file' {
    $beforeHash = (Get-FileHash -LiteralPath $script:configPath -Algorithm SHA256).Hash

    $result = Set-ServiceAccountGitSafeDirectory -Boundary Start `
      -WorktreePaths @($script:acePath, $script:utilitiesPath) `
      -GitConfigPath $script:configPath `
      -WhatIf

    $afterHash = (Get-FileHash -LiteralPath $script:configPath -Algorithm SHA256).Hash
    $result.DryRun | Should -BeTrue
    $result.Added.Count | Should -Be 2
    $result.After | Should -Contain $script:acePath.Replace('\', '/')
    $result.After | Should -Contain $script:utilitiesPath.Replace('\', '/')
    $afterHash | Should -Be $beforeHash
  }

  It 'Ignores stable paths and close repository-name variants' {
    $nearVariants = @(
      (Join-Path $TestDrive 'Ace'),
      (Join-Path $TestDrive 'AceCommander-wt-45-Sprint-0015-work-items'),
      (Join-Path $TestDrive 'Ace-wt-x-Sprint-0015-work-items'),
      (Join-Path $TestDrive 'ATAP.Utilities-wt-137-Sprint-current-work-items')
    )

    $result = Set-ServiceAccountGitSafeDirectory -Boundary Start `
      -WorktreePaths $nearVariants `
      -GitConfigPath $script:configPath `
      -Confirm:$false

    $result.SelectedPaths | Should -BeNullOrEmpty
    $result.Added | Should -BeNullOrEmpty
    $result.After.Count | Should -Be 2
  }

  It 'Treats path case and separator variants as the same exact entry' {
    $configuredAce = $script:acePath.Replace('\', '/').ToLowerInvariant()
    & git config --file $script:configPath --add safe.directory $configuredAce
    $LASTEXITCODE | Should -Be 0

    $result = Set-ServiceAccountGitSafeDirectory -Boundary Start `
      -WorktreePaths @($script:acePath) `
      -GitConfigPath $script:configPath `
      -Confirm:$false

    $result.Added | Should -BeNullOrEmpty
    $result.Unchanged.Count | Should -Be 1
    @($result.After | Where-Object { $_ -ieq $script:acePath.Replace('\', '/') }).Count | Should -Be 1
  }
}
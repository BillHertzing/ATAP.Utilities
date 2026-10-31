BeforeAll {
  . (Join-Path $PSScriptRoot '../../public/Get-LocalGitWorktreeMetadata.ps1')
  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
}

Describe 'Get-LocalGitWorktreeMetadata bounded observations' {
  BeforeEach {
    $script:root = $TestDrive
    $script:scenario = 'good'
    Mock Get-Command {
      if ($Name -eq 'git') { return [pscustomobject]@{ Name = 'git' } }
      return [pscustomobject]@{ Name = 'Write-PSFMessage' }
    }
    Mock git {
      $global:LASTEXITCODE = 0
      if ($script:scenario -eq 'interrupted') { throw 'interrupted' }
      if ($args -contains '--show-toplevel') {
        if ($script:scenario -eq 'mismatch') { return (Join-Path $script:root 'other') }
        return $script:root
      }
      if ($args -contains '--absolute-git-dir') { return $script:root }
      if ($args -contains '--git-common-dir') { return $script:root }
      if ($args -contains 'symbolic-ref') {
        if ($script:scenario -eq 'unknown') { $global:LASTEXITCODE = 1; return }
        return 'main'
      }
      if ($args -contains '--porcelain') {
        $output = @("worktree $script:root", ('HEAD ' + ('a' * 40)), 'branch refs/heads/main')
        if ($script:scenario -eq 'locked') { $output += 'locked test' }
        if ($script:scenario -eq 'valid-with-unknown-field') { $output += 'future-field value' }
        if ($script:scenario -eq 'unsupported') { return @("worktree $script:root", 'unrecognized') }
        return $output
      }
      throw 'Unexpected Git invocation'
    }
  }

  It 'reports only checked metadata without findings for a consistent selected registration' {
    (Get-LocalGitWorktreeMetadata -RootPath $script:root).Status | Should -Be 'NoFindingsInCheckedMetadata'
  }
  It 'returns inconclusive only after adding an unsupported registration field to a valid registration' {
    $script:scenario = 'good'
    $control = Get-LocalGitWorktreeMetadata -RootPath $script:root
    $script:scenario = 'valid-with-unknown-field'
    $unsupported = Get-LocalGitWorktreeMetadata -RootPath $script:root
    $control.Status | Should -Be 'NoFindingsInCheckedMetadata'
    $unsupported.Status | Should -Be 'Inconclusive'
  }
  It 'reports a top-level mismatch as a finding' {
    $script:scenario = 'mismatch'
    (Get-LocalGitWorktreeMetadata -RootPath $script:root).Status | Should -Be 'Finding'
  }
  It 'reports a locked selected registration as a finding' {
    $script:scenario = 'locked'
    (Get-LocalGitWorktreeMetadata -RootPath $script:root).Status | Should -Be 'Finding'
  }
  It 'returns inconclusive for <Case>' -ForEach @(
    @{ Case = 'interrupted' }, @{ Case = 'unknown' }, @{ Case = 'unsupported' }
  ) {
    $script:scenario = $Case
    (Get-LocalGitWorktreeMetadata -RootPath $script:root).Status | Should -Be 'Inconclusive'
  }
  It 'returns inconclusive for a missing root' {
    (Get-LocalGitWorktreeMetadata -RootPath (Join-Path $script:root 'missing')).Status | Should -Be 'Inconclusive'
  }
  It 'returns inconclusive when Git is unavailable' {
    Mock Get-Command { if ($Name -eq 'git') { return $null }; [pscustomobject]@{ Name = 'Write-PSFMessage' } }
    (Get-LocalGitWorktreeMetadata -RootPath $script:root).Status | Should -Be 'Inconclusive'
  }
}

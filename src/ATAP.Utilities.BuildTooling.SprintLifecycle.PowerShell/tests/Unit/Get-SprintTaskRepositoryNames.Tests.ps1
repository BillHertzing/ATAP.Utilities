BeforeAll {
  . "$PSScriptRoot\..\..\private\Get-SprintTaskRepositoryNames.ps1"
}

Describe 'Get-SprintTaskRepositoryNames [private]' {
  It 'extracts only repo markers immediately after the task token' {
    $tasksContent = @(
      '- [ ] **Task 7.49** [ATAP.Utilities] Tighten parser; mentions [Swarm], [Junior], and [switch] later.'
      '- [ ] **Task 7.50** [SharedVSCode] Excluded repo marker.'
      '- [ ] **Task 7.51** [AceCommander] Real downstream task.'
      '  [NotARepo] prose-only bracket should not match.'
      '- [ ] **Task 7.52** Description before [ATAP.IAC] should not match.'
    )

    $result = Get-SprintTaskRepositoryNames -TasksContent $tasksContent -ExcludeRepos @('SharedVSCode')

    $result | Should -Contain 'ATAP.Utilities'
    $result | Should -Contain 'AceCommander'
    $result | Should -Not -Contain 'Swarm'
    $result | Should -Not -Contain 'Junior'
    $result | Should -Not -Contain 'switch'
    $result | Should -Not -Contain 'ATAP.IAC'
    $result.Count | Should -Be 2
  }
  It 'splits compound repository markers on plus signs' {
    $tasksContent = @(
      '- [ ] **Task 11.16** [ATAP.Utilities + ATAP.IAC] Validate both downstream worktrees.'
      '- [ ] **Task 11.17** [SharedVSCode + _Planning] Excluded compound marker.'
    )

    $result = Get-SprintTaskRepositoryNames -TasksContent $tasksContent -ExcludeRepos @('SharedVSCode', '_Planning')

    $result | Should -Contain 'ATAP.Utilities'
    $result | Should -Contain 'ATAP.IAC'
    $result | Should -Not -Contain 'SharedVSCode'
    $result | Should -Not -Contain '_Planning'
    $result.Count | Should -Be 2
  }
}


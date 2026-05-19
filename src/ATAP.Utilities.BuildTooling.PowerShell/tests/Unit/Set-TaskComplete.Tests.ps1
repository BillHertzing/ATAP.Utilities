#Requires -Version 7.0

BeforeAll {
  Import-Module PSFramework -ErrorAction SilentlyContinue
  $script:publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  # Dot-source Invoke-WithFileLock first so Mock can find it; Set-TaskComplete will
  # also dot-source it internally but the function will already be in scope.
  . (Join-Path $script:publicDir 'Invoke-WithFileLock.ps1')
  . (Join-Path $script:publicDir 'Set-TaskComplete.ps1')

  function New-TestTasksFile {
    param([string[]]$Lines)
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ("tasks_$([guid]::NewGuid().ToString('N')).md")
    [System.IO.File]::WriteAllLines($path, $Lines, [System.Text.Encoding]::UTF8)
    return $path
  }
}

Describe 'Set-TaskComplete' -Tag 'Unit' {

  BeforeEach {
    # Bypass real file locking — execute the Action block inline so tests don't need a
    # _Planning/_locks directory or risk collisions with other concurrent test runs.
    Mock Invoke-WithFileLock { & $Action }
  }

  Context 'ByNumber parameter set (current V3 checkbox format)' {

    It 'Flips [ ] to [x] for a V3-style alphanumeric task number (A04)' {
      $tasks = @(
        '- [ ] **A03 [BLOCKING]** Earlier task.',
        '- [ ] **A04 [INTEGRATION-GAP]** Resolve manifest mismatch.',
        '- [ ] **A05** Another task.'
      )
      $path = New-TestTasksFile -Lines $tasks
      try {
        $changed = Set-TaskComplete -TaskNumber 'A04' -TasksFilePath $path
        $changed | Should -Be 1
        $result = [System.IO.File]::ReadAllLines($path)
        $result[0] | Should -Match '^\- \[ \] \*\*A03'
        $result[1] | Should -Match '^\- \[x\] \*\*A04 \[INTEGRATION-GAP\]\*\* Resolve manifest mismatch\.$'
        $result[2] | Should -Match '^\- \[ \] \*\*A05'
      } finally {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
      }
    }

    It 'Flips a task number followed immediately by ** (no tag)' {
      $tasks = @(
        '- [ ] **B10** Add Set-TaskComplete support for the current checkbox format.'
      )
      $path = New-TestTasksFile -Lines $tasks
      try {
        $changed = Set-TaskComplete -TaskNumber 'B10' -TasksFilePath $path
        $changed | Should -Be 1
        $result = [System.IO.File]::ReadAllLines($path)
        $result[0] | Should -Match '^\- \[x\] \*\*B10\*\* Add Set-TaskComplete'
      } finally {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
      }
    }

    It 'Supports legacy numeric task numbers with dots (7.1)' {
      $tasks = @(
        '- [ ] **7.1** Step 3 add SignalR hub.',
        '- [ ] **7.10** Unrelated later task.'
      )
      $path = New-TestTasksFile -Lines $tasks
      try {
        $changed = Set-TaskComplete -TaskNumber '7.1' -TasksFilePath $path
        $changed | Should -Be 1
        $result = [System.IO.File]::ReadAllLines($path)
        $result[0] | Should -Match '^\- \[x\] \*\*7\.1\*\*'
        $result[1] | Should -Match '^\- \[ \] \*\*7\.10\*\*'  # 7.10 not flipped
      } finally {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
      }
    }

    It 'Supports alphanumeric task numbers with trailing letters (F01a)' {
      $tasks = @(
        '- [ ] **F01** Earlier task.',
        '- [ ] **F01a [NEW]** New diagnosis task.'
      )
      $path = New-TestTasksFile -Lines $tasks
      try {
        $changed = Set-TaskComplete -TaskNumber 'F01a' -TasksFilePath $path
        $changed | Should -Be 1
        $result = [System.IO.File]::ReadAllLines($path)
        $result[0] | Should -Match '^\- \[ \] \*\*F01\*\*'   # F01 untouched
        $result[1] | Should -Match '^\- \[x\] \*\*F01a'
      } finally {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
      }
    }

    It 'Is idempotent — re-running on an already-completed task returns 0 changes' {
      $tasks = @(
        '- [x] **A04 [INTEGRATION-GAP]** Already complete.'
      )
      $path = New-TestTasksFile -Lines $tasks
      try {
        $changed = Set-TaskComplete -TaskNumber 'A04' -TasksFilePath $path
        $changed | Should -Be 0
        $result = [System.IO.File]::ReadAllLines($path)
        $result[0] | Should -Match '^\- \[x\] \*\*A04'  # unchanged
      } finally {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
      }
    }

    It 'Returns 0 when the task number is not found' {
      $tasks = @(
        '- [ ] **A04** Some task.'
      )
      $path = New-TestTasksFile -Lines $tasks
      try {
        $changed = Set-TaskComplete -TaskNumber 'Z99' -TasksFilePath $path
        $changed | Should -Be 0
      } finally {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
      }
    }

    It '-DryRun does not modify the file but reports the would-be change' {
      $tasks = @(
        '- [ ] **A04 [INTEGRATION-GAP]** Resolve manifest mismatch.'
      )
      $path = New-TestTasksFile -Lines $tasks
      try {
        $original = [System.IO.File]::ReadAllText($path)
        $changed = Set-TaskComplete -TaskNumber 'A04' -TasksFilePath $path -DryRun
        $changed | Should -Be 1
        $after = [System.IO.File]::ReadAllText($path)
        $after | Should -BeExactly $original
      } finally {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
      }
    }

    It 'Does not corrupt task body text (preserves [TAG] brackets inside the line)' {
      $tasks = @(
        '- [ ] **A04 [INTEGRATION-GAP] [BLOCKING]** Resolve [edge] manifest mismatch.'
      )
      $path = New-TestTasksFile -Lines $tasks
      try {
        $changed = Set-TaskComplete -TaskNumber 'A04' -TasksFilePath $path
        $changed | Should -Be 1
        $result = [System.IO.File]::ReadAllLines($path)
        # Only the FIRST [ ] (the checkbox) flips; [TAG] brackets and [edge] survive.
        $result[0] | Should -BeExactly '- [x] **A04 [INTEGRATION-GAP] [BLOCKING]** Resolve [edge] manifest mismatch.'
      } finally {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'ByText parameter set (legacy behavior preserved)' {

    It 'Flips a task line by substring match' {
      $tasks = @(
        '- [ ] **A04 [INTEGRATION-GAP]** Resolve manifest mismatch.',
        '- [ ] **A05** Other task.'
      )
      $path = New-TestTasksFile -Lines $tasks
      try {
        $changed = Set-TaskComplete -TaskText 'manifest mismatch' -TasksFilePath $path
        $changed | Should -Be 1
        $result = [System.IO.File]::ReadAllLines($path)
        $result[0] | Should -Match '^\- \[x\] \*\*A04'
        $result[1] | Should -Match '^\- \[ \] \*\*A05'
      } finally {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'Parameter validation' {

    It 'Throws when TasksFilePath does not exist' {
      $missing = Join-Path ([System.IO.Path]::GetTempPath()) "does_not_exist_$([guid]::NewGuid()).md"
      { Set-TaskComplete -TaskNumber 'A04' -TasksFilePath $missing } |
        Should -Throw '*TASKS.md not found*'
    }

    It 'Rejects calls that supply both TaskText and TaskNumber (parameter sets are exclusive)' {
      $tasks = @('- [ ] **A04** Some task.')
      $path = New-TestTasksFile -Lines $tasks
      try {
        { Set-TaskComplete -TaskNumber 'A04' -TaskText 'Some' -TasksFilePath $path } |
          Should -Throw
      } finally {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
      }
    }
  }
}

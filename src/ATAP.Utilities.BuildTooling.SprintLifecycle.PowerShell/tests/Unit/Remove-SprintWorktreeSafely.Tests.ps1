#Requires -Version 7.0

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  $moduleRoot = Join-Path $PSScriptRoot '..\..'
  . (Join-Path $moduleRoot 'private\Get-SprintEndActiveWorkspaceRoot.ps1')
  . (Join-Path $moduleRoot 'private\Invoke-SprintEndNativeCommand.ps1')
  . (Join-Path $moduleRoot 'public\Remove-SprintWorktreeSafely.ps1')
}

Describe 'Remove-SprintWorktreeSafely' -Tag 'Unit' {
  BeforeEach {
    $caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $script:repository = Join-Path $caseRoot 'App'
    $script:worktree = Join-Path $caseRoot 'App-wt-42-Sprint-0013-work-items'
    $script:handoff = Join-Path $caseRoot 'HANDOFF.Remove-App.md'
    New-Item -ItemType Directory -Path $script:repository, $script:worktree -Force | Out-Null
    Mock Get-SprintEndActiveWorkspaceRoot { @() }
  }

  It 'blocks an active Codex workspace before invoking Git removal and writes only the remaining step' {
    Mock Get-SprintEndActiveWorkspaceRoot {
      @([PSCustomObject]@{ Source = 'Process:Codex.exe:42'; Root = $script:worktree })
    }
    Mock Invoke-SprintEndNativeCommand { throw 'Git must not run while the worktree is active.' }

    $result = Remove-SprintWorktreeSafely -RepositoryPath $script:repository `
      -WorktreePath $script:worktree -HandoffPath $script:handoff -Confirm:$false
    $text = Get-Content -Raw -LiteralPath $script:handoff

    $result.Ok | Should -BeFalse
    $result.Attempts | Should -Be 0
    $text | Should -Match 'Remove-SprintWorktreeSafely'
    $text | Should -Not -Match 'Set-SprintBoundaryContext|pull --ff-only|Remove-SprintDatabases'
    Assert-MockCalled Invoke-SprintEndNativeCommand -Times 0
  }

  It 'uses bounded retries and succeeds on the third removal attempt' {
    $script:removeCalls = 0
    $lockedFile = Join-Path $script:worktree 'locked.txt'
    Set-Content -LiteralPath $lockedFile -Value 'fixture'
    Mock Invoke-SprintEndNativeCommand {
      if ($ArgumentList[3] -eq 'list') {
        return [PSCustomObject]@{ Succeeded = $true; ExitCode = 0; Output = @("worktree $script:worktree") }
      }
      if ($ArgumentList[3] -eq 'remove') {
        $script:removeCalls++
        if ($script:removeCalls -eq 3) {
          [IO.File]::Delete($lockedFile)
          [IO.Directory]::Delete($script:worktree, $false)
          return [PSCustomObject]@{ Succeeded = $true; ExitCode = 0; Output = @() }
        }
        return [PSCustomObject]@{ Succeeded = $false; ExitCode = 1; Output = @('locked') }
      }
      return [PSCustomObject]@{ Succeeded = $true; ExitCode = 0; Output = @() }
    }

    $result = Remove-SprintWorktreeSafely -RepositoryPath $script:repository `
      -WorktreePath $script:worktree -MaxAttempts 3 -RetryDelayMilliseconds 0 -Confirm:$false

    $result.Ok | Should -BeTrue
    $result.Attempts | Should -Be 3
    $script:removeCalls | Should -Be 3
  }

  It 'stops exactly at MaxAttempts and writes a minimal retry handoff' {
    Set-Content -LiteralPath (Join-Path $script:worktree 'locked.txt') -Value 'fixture'
    Mock Invoke-SprintEndNativeCommand {
      if ($ArgumentList[3] -eq 'list') {
        return [PSCustomObject]@{ Succeeded = $true; ExitCode = 0; Output = @("worktree $script:worktree") }
      }
      return [PSCustomObject]@{ Succeeded = $false; ExitCode = 32; Output = @('in use') }
    }

    $result = Remove-SprintWorktreeSafely -RepositoryPath $script:repository `
      -WorktreePath $script:worktree -MaxAttempts 2 -RetryDelayMilliseconds 0 `
      -HandoffPath $script:handoff -Confirm:$false

    $result.Ok | Should -BeFalse
    $result.Attempts | Should -Be 2
    Test-Path -LiteralPath $script:handoff | Should -BeTrue
    Assert-MockCalled Invoke-SprintEndNativeCommand -ParameterFilter { $ArgumentList[3] -eq 'remove' } -Times 2
  }

  It 'deletes only an explicitly named empty ordinary adapter placeholder without recursion' {
    $placeholder = Join-Path $script:worktree '.codex'
    New-Item -ItemType Directory -Path $placeholder | Out-Null
    Mock Invoke-SprintEndNativeCommand {
      if ($ArgumentList[3] -eq 'list') {
        return [PSCustomObject]@{ Succeeded = $true; ExitCode = 0; Output = @("worktree $script:worktree") }
      }
      return [PSCustomObject]@{ Succeeded = $false; ExitCode = 1; Output = @('root remains') }
    }

    $result = Remove-SprintWorktreeSafely -RepositoryPath $script:repository `
      -WorktreePath $script:worktree -AdapterPlaceholderPath '.codex' `
      -MaxAttempts 1 -RetryDelayMilliseconds 0 -Confirm:$false

    $result.Ok | Should -BeTrue
    $result.RemovedPlaceholders | Should -Contain $placeholder
    Test-Path -LiteralPath $script:worktree | Should -BeFalse
  }

  It 'preserves and reports a named placeholder containing a hidden file' {
    $placeholder = Join-Path $script:worktree '.agents'
    New-Item -ItemType Directory -Path $placeholder | Out-Null
    Set-Content -LiteralPath (Join-Path $placeholder '.keep') -Value 'preserve'
    Mock Invoke-SprintEndNativeCommand {
      if ($ArgumentList[3] -eq 'list') {
        return [PSCustomObject]@{ Succeeded = $true; ExitCode = 0; Output = @("worktree $script:worktree") }
      }
      return [PSCustomObject]@{ Succeeded = $false; ExitCode = 1; Output = @('root remains') }
    }

    $result = Remove-SprintWorktreeSafely -RepositoryPath $script:repository `
      -WorktreePath $script:worktree -AdapterPlaceholderPath '.agents' `
      -MaxAttempts 1 -RetryDelayMilliseconds 0 -Confirm:$false

    $result.Ok | Should -BeFalse
    Test-Path -LiteralPath (Join-Path $placeholder '.keep') | Should -BeTrue
    $result.Failures -join ' ' | Should -Match 'Refused non-empty'
  }

  It 'rejects a placeholder path outside the exact worktree boundary' {
    $outside = Join-Path $TestDrive 'App-wt-42-Sprint-0013-work-items-evil'
    New-Item -ItemType Directory -Path $outside | Out-Null

    {
      Remove-SprintWorktreeSafely -RepositoryPath $script:repository `
        -WorktreePath $script:worktree -AdapterPlaceholderPath $outside -Confirm:$false
    } | Should -Throw '*outside the worktree*'
  }

  It 'rejects a nested placeholder even when its lexical path is inside the worktree' {
    $nested = Join-Path $script:worktree '.codex\cache'
    New-Item -ItemType Directory -Path $nested -Force | Out-Null

    {
      Remove-SprintWorktreeSafely -RepositoryPath $script:repository `
        -WorktreePath $script:worktree -AdapterPlaceholderPath $nested -Confirm:$false
    } | Should -Throw '*direct child*'
  }

  It 'refuses an existing path not registered to the supplied stable repository' {
    Mock Invoke-SprintEndNativeCommand {
      [PSCustomObject]@{ Succeeded = $true; ExitCode = 0; Output = @("worktree $script:repository") }
    }

    $result = Remove-SprintWorktreeSafely -RepositoryPath $script:repository `
      -WorktreePath $script:worktree -HandoffPath $script:handoff -Confirm:$false

    $result.Ok | Should -BeFalse
    $result.Attempts | Should -Be 0
    $result.Failures[0] | Should -Match 'not registered'
  }

  It 'is idempotent when the worktree path is already absent' {
    Set-Content -LiteralPath $script:handoff -Value 'stale handoff'
    [IO.Directory]::Delete($script:worktree, $false)
    Mock Invoke-SprintEndNativeCommand { throw 'Git registration is unnecessary for an absent path.' }

    $result = Remove-SprintWorktreeSafely -RepositoryPath $script:repository `
      -WorktreePath $script:worktree -HandoffPath $script:handoff -Confirm:$false

    $result.Ok | Should -BeTrue
    $result.Removed | Should -BeTrue
    $result.Attempts | Should -Be 0
    Test-Path -LiteralPath $script:handoff | Should -BeFalse
    Assert-MockCalled Invoke-SprintEndNativeCommand -Times 0
  }

  It 'WhatIf verifies registration but performs no removal or handoff write' {
    Mock Invoke-SprintEndNativeCommand {
      [PSCustomObject]@{ Succeeded = $true; ExitCode = 0; Output = @("worktree $script:worktree") }
    }

    $result = Remove-SprintWorktreeSafely -RepositoryPath $script:repository `
      -WorktreePath $script:worktree -HandoffPath $script:handoff -WhatIf

    $result.Planned | Should -BeTrue
    Test-Path -LiteralPath $script:worktree | Should -BeTrue
    Test-Path -LiteralPath $script:handoff | Should -BeFalse
    Assert-MockCalled Invoke-SprintEndNativeCommand -ParameterFilter { $ArgumentList[3] -eq 'remove' } -Times 0
  }

  It 'contains no recursive deletion surface in the production implementation' {
    $source = Get-Content -Raw -LiteralPath (Join-Path $moduleRoot 'public\Remove-SprintWorktreeSafely.ps1')
    $source | Should -Not -Match 'Remove-Item[^\r\n]*-Recurse|Directory\.Delete\([^\r\n]*\$true\)'
    $source | Should -Match 'for \(\$attempt = 1; \$attempt -le \$MaxAttempts; \$attempt\+\+\)'
  }
}

Describe 'Get-SprintEndActiveWorkspaceRoot' -Tag 'Unit' {
  It 'detects when the current shell location is inside the candidate worktree' {
    $worktree = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $child = Join-Path $worktree 'src'
    New-Item -ItemType Directory -Path $child -Force | Out-Null
    Mock Get-CimInstance { @() }

    Push-Location -LiteralPath $child
    try {
      $result = @(Get-SprintEndActiveWorkspaceRoot -WorktreePath $worktree)
    } finally {
      Pop-Location
    }

    $result.Source | Should -Contain 'CurrentLocation'
  }

  It 'detects a Codex process command line that references the exact worktree' -Skip:(-not $IsWindows) {
    $worktree = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $worktree | Out-Null
    Mock Get-CimInstance {
      @([PSCustomObject]@{
          Name = 'Codex.exe'; ProcessId = 42
          CommandLine = "Codex.exe --workspace `"$worktree`""
        })
    }

    $result = @(Get-SprintEndActiveWorkspaceRoot -WorktreePath $worktree)

    $result.Source | Should -Contain 'Process:Codex.exe:42'
  }

  It 'blocks closed when Codex process inspection is unavailable' -Skip:(-not $IsWindows) {
    $worktree = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $worktree | Out-Null
    Mock Get-CimInstance { throw 'CIM unavailable' }

    $result = @(Get-SprintEndActiveWorkspaceRoot -WorktreePath $worktree)

    $result.Source | Should -Contain 'ProcessInspectionUnavailable'
  }
}

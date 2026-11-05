#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

# Source-only handoff. Execution requires a separately reviewed fixture/import plan.
# All filesystem/native operations below are mocked; no directory or junction is
# created and no cleanup runs. Synthetic paths remain in the owning generated root.
BeforeAll {
  . (Join-Path $PSScriptRoot '..\..\private\Set-AIAgentMemoryJunction.ps1')

  # A missing mock must fail rather than invoke an actual native executable.
  function git {
    param([string]$C, [Parameter(ValueFromRemainingArguments = $true)][object[]]$Arguments)
    throw 'Native Git is forbidden in result/progress fixtures.'
  }
  function Write-PSFMessage {
    param([string]$FunctionName, [string]$ModuleName, [string]$Level, [string]$Message, [string[]]$Tag)
  }

  $script:fixtureRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\_generated\Sprint0017\17.66\G3C2ProgressSource01\FixtureOnly'))
  $script:repo = Join-Path $script:fixtureRoot 'StableRepo'
  $script:worktree = Join-Path $script:fixtureRoot 'SprintWorktree'
  $script:memoryRoot = Join-Path $script:fixtureRoot 'Memory'
  $script:projectsRoot = Join-Path $script:fixtureRoot 'Projects'
}

Describe 'Set-AIAgentMemoryJunction truthful result and retained progress' {
  BeforeEach {
    $script:previousExitCode = $global:LASTEXITCODE
    $script:junctionCalls = 0
    Mock git { $global:LASTEXITCODE = 0; return (Join-Path $script:repo '.git') }
    Mock Write-PSFMessage { }
    Mock Resolve-Path { [PSCustomObject]@{ Path = $script:repo } }
    Mock Test-Path { return $LiteralPath -eq $script:worktree }
    Mock Get-Item { throw 'Unexpected Get-Item in virtual fixture.' }
    Mock Get-ChildItem { throw 'Unexpected enumeration in virtual fixture.' }
    Mock New-Item { throw 'Unexpected mutation in virtual fixture.' }
    Mock Move-Item { throw 'Unexpected move in virtual fixture.' }
    Mock Remove-Item { throw 'Unexpected removal in virtual fixture.' }
  }

  AfterEach {
    $global:LASTEXITCODE = $script:previousExitCode
  }

  It 'classifies WhatIf as planned rather than successful created work' {
    $r = Set-AIAgentMemoryJunction -WorktreePath $script:worktree `
      -AIAgentMemoryRoot $script:memoryRoot -ClaudeProjectsRoot $script:projectsRoot -WhatIf

    $r.Success | Should -BeFalse
    $r.Disposition | Should -Be 'Planned'
    $r.Changed | Should -BeFalse
    $r.JunctionsCreated | Should -Be 0
    $r.DeclinedActions | Should -Be 3
    @($r.Progress | Where-Object State -eq 'Planned').Count | Should -Be 3
    Should -Invoke New-Item -Times 0 -Exactly
    Should -Invoke Move-Item -Times 0 -Exactly
    Should -Invoke Remove-Item -Times 0 -Exactly
  }

  It 'keeps an explicit configuration-unavailable skip as a no-effect legacy result' {
    $savedSettings = $global:settings
    $savedKeys = $global:configRootKeys
    try {
      $global:settings = @{}
      $global:configRootKeys = @{}
      $r = Set-AIAgentMemoryJunction -WorktreePath $script:worktree `
        -ClaudeProjectsRoot $script:projectsRoot -Confirm:$false

      $r.Success | Should -BeTrue
      $r.Skipped | Should -BeTrue
      $r.Disposition | Should -Be 'Skipped'
      $r.Changed | Should -BeFalse
      $r.JunctionsCreated | Should -Be 0
      $r.Progress.Count | Should -Be 0
      Should -Invoke New-Item -Times 0 -Exactly
    } finally {
      $global:settings = $savedSettings
      $global:configRootKeys = $savedKeys
    }
  }

  It 'retains the first created junction and the uncertain second attempt on failure' {
    Mock New-Item {
      if ($ItemType -eq 'Junction') {
        $script:junctionCalls++
        if ($script:junctionCalls -eq 2) { throw 'Injected second-junction failure.' }
      }
      [PSCustomObject]@{ FullName = $Path }
    }
    $r = Set-AIAgentMemoryJunction -WorktreePath $script:worktree `
      -AIAgentMemoryRoot $script:memoryRoot -ClaudeProjectsRoot $script:projectsRoot -Confirm:$false

    $r.Success | Should -BeFalse
    $r.Disposition | Should -Be 'PartialFailure'
    $r.Changed | Should -BeTrue
    $r.HasUncertainEffects | Should -BeTrue
    $r.JunctionsCreated | Should -Be 1
    $r.Junctions.Count | Should -Be 1
    @($r.Progress | Where-Object { $_.Kind -eq 'CreateJunction' -and $_.State -eq 'Completed' }).Count | Should -Be 1
    @($r.Progress | Where-Object { $_.Kind -eq 'CreateJunction' -and $_.State -eq 'Uncertain' }).Count | Should -Be 1
    @($r.Progress | Where-Object Kind -eq 'FailureBoundary').Count | Should -Be 1
  }

  It 'retains a completed move when a remaining real-directory entry prevents replacement' {
    Mock New-Item { [PSCustomObject]@{ FullName = $Path } }
    Mock Test-Path {
      if ($LiteralPath -eq $script:worktree) { return $true }
      # Only the second/worktree slug has a pre-existing real memory directory.
      return $LiteralPath.EndsWith('SprintWorktree\memory', [StringComparison]::Ordinal)
    }
    Mock Get-Item { [PSCustomObject]@{ LinkType = $null } }
    Mock Get-ChildItem {
      if ($File) {
        [PSCustomObject]@{ Name = 'moved.md'; FullName = (Join-Path $LiteralPath 'moved.md') }
      } else {
        [PSCustomObject]@{ Name = 'remaining-directory'; FullName = (Join-Path $LiteralPath 'remaining-directory') }
      }
    }
    Mock Move-Item { }
    $r = Set-AIAgentMemoryJunction -WorktreePath $script:worktree `
      -AIAgentMemoryRoot $script:memoryRoot -ClaudeProjectsRoot $script:projectsRoot -Confirm:$false

    $r.Success | Should -BeFalse
    $r.Disposition | Should -Be 'PartialFailure'
    $r.FilesMoved.Count | Should -Be 1
    $r.FilesMoved[0].Source | Should -BeLike '*moved.md'
    @($r.Progress | Where-Object { $_.Kind -eq 'MoveMemoryFile' -and $_.State -eq 'Completed' }).Count | Should -Be 1
    @($r.Progress | Where-Object Kind -eq 'FailureBoundary').Count | Should -Be 1
    Should -Invoke Move-Item -Times 1 -Exactly
    Should -Invoke Remove-Item -Times 0 -Exactly
  }

  It 'does not complete an ignored nonterminating mutator failure' {
    Mock New-Item { Write-Error -Message 'Injected nonterminating store failure.' -Category WriteError }
    $r = Set-AIAgentMemoryJunction -WorktreePath $script:worktree `
      -AIAgentMemoryRoot $script:memoryRoot -ClaudeProjectsRoot $script:projectsRoot -Confirm:$false -ErrorAction Ignore

    $r.Success | Should -BeFalse
    $r.Disposition | Should -Be 'PartialFailure'
    $r.Changed | Should -BeFalse
    $r.HasUncertainEffects | Should -BeTrue
    @($r.Progress | Where-Object { $_.Kind -eq 'CreateStore' -and $_.State -eq 'Uncertain' }).Count | Should -Be 1
    @($r.Progress | Where-Object State -eq 'Completed').Count | Should -Be 0
    $r.FilesMoved.Count | Should -Be 0
    $r.JunctionsCreated | Should -Be 0
    Should -Invoke New-Item -Times 1 -Exactly -ParameterFilter { $ErrorAction -eq 'Stop' }
    Should -Invoke Move-Item -Times 0 -Exactly
    Should -Invoke Remove-Item -Times 0 -Exactly
  }

  It 'retains earlier junction progress when an enumeration error is silenced by the caller' {
    Mock New-Item { [PSCustomObject]@{ FullName = $Path } }
    Mock Test-Path {
      if ($LiteralPath -eq $script:worktree) { return $true }
      return $LiteralPath.EndsWith('SprintWorktree\memory', [StringComparison]::Ordinal)
    }
    Mock Get-Item { [PSCustomObject]@{ LinkType = $null } }
    Mock Get-ChildItem { Write-Error -Message 'Injected memory enumeration denial.' -Category PermissionDenied }
    $r = Set-AIAgentMemoryJunction -WorktreePath $script:worktree `
      -AIAgentMemoryRoot $script:memoryRoot -ClaudeProjectsRoot $script:projectsRoot -Confirm:$false -ErrorAction SilentlyContinue

    $r.Success | Should -BeFalse
    $r.Disposition | Should -Be 'PartialFailure'
    $r.Changed | Should -BeTrue
    $r.JunctionsCreated | Should -Be 1
    $r.Junctions.Count | Should -Be 1
    @($r.Progress | Where-Object { $_.Kind -eq 'ReadMemoryFiles' -and $_.State -eq 'Failed' }).Count | Should -Be 1
    @($r.Progress | Where-Object Kind -eq 'FailureBoundary').Count | Should -Be 1
    Should -Invoke Get-ChildItem -Times 1 -Exactly -ParameterFilter { $ErrorAction -eq 'Stop' }
    Should -Invoke Move-Item -Times 0 -Exactly
    Should -Invoke Remove-Item -Times 0 -Exactly
  }

  It 'distinguishes a failed existence read from an expected missing path' {
    Mock Test-Path { Write-Error -Message 'Injected existence access denial.' -Category PermissionDenied }
    $r = Set-AIAgentMemoryJunction -WorktreePath $script:worktree `
      -AIAgentMemoryRoot $script:memoryRoot -ClaudeProjectsRoot $script:projectsRoot -Confirm:$false -ErrorAction Ignore

    $r.Success | Should -BeFalse
    $r.Disposition | Should -Be 'Failed'
    $r.Changed | Should -BeFalse
    $r.HasUncertainEffects | Should -BeFalse
    @($r.Progress | Where-Object { $_.Kind -eq 'ReadWorktreePath' -and $_.State -eq 'Failed' }).Count | Should -Be 1
    Should -Invoke New-Item -Times 0 -Exactly
    Should -Invoke Move-Item -Times 0 -Exactly
    Should -Invoke Remove-Item -Times 0 -Exactly
  }

  It 'retains a completed move when the remaining-entry read fails' {
    Mock New-Item { [PSCustomObject]@{ FullName = $Path } }
    Mock Test-Path {
      if ($LiteralPath -eq $script:worktree) { return $true }
      return $LiteralPath.EndsWith('SprintWorktree\memory', [StringComparison]::Ordinal)
    }
    Mock Get-Item { [PSCustomObject]@{ LinkType = $null } }
    Mock Get-ChildItem {
      if ($File) { [PSCustomObject]@{ Name = 'moved.md'; FullName = (Join-Path $LiteralPath 'moved.md') } }
      else { Write-Error -Message 'Injected remaining-entry enumeration denial.' -Category PermissionDenied }
    }
    Mock Move-Item { }
    $r = Set-AIAgentMemoryJunction -WorktreePath $script:worktree `
      -AIAgentMemoryRoot $script:memoryRoot -ClaudeProjectsRoot $script:projectsRoot -Confirm:$false -ErrorAction Ignore

    $r.Success | Should -BeFalse
    $r.Disposition | Should -Be 'PartialFailure'
    $r.FilesMoved.Count | Should -Be 1
    @($r.Progress | Where-Object { $_.Kind -eq 'MoveMemoryFile' -and $_.State -eq 'Completed' }).Count | Should -Be 1
    @($r.Progress | Where-Object { $_.Kind -eq 'ReadRemainingMemoryEntries' -and $_.State -eq 'Failed' }).Count | Should -Be 1
    Should -Invoke Move-Item -Times 1 -Exactly -ParameterFilter { $ErrorAction -eq 'Stop' }
    Should -Invoke Remove-Item -Times 0 -Exactly
  }
}

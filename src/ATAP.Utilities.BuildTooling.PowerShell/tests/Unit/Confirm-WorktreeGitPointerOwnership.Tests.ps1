BeforeAll {
  . "$PSScriptRoot\..\..\private\Confirm-WorktreeGitPointerOwnership.ps1"

  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }

  $script:operator = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
}

Describe 'Confirm-WorktreeGitPointerOwnership' {
  BeforeEach {
    $script:worktree = Join-Path $TestDrive 'repo-wt-1'
    New-Item -ItemType Directory -Path $script:worktree -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $script:worktree '.git') -Value 'gitdir: C:\repo\.git\worktrees\repo-wt-1'
  }

  It 'returns verified without repair when the exact pointer owner already matches' {
    Mock Get-Acl { [PSCustomObject]@{ Owner = $script:operator } }
    Mock Set-Acl {}

    $result = Confirm-WorktreeGitPointerOwnership -WorktreePath $script:worktree -Confirm:$false

    $result.Verified | Should -BeTrue
    $result.Repaired | Should -BeFalse
    Assert-MockCalled Set-Acl -Times 0 -Exactly
  }

  It 'repairs only the exact pointer and verifies the owner again' {
    $script:aclReads = 0
    $acl = [PSCustomObject]@{ Owner = 'BUILTIN\Administrators' }
    $acl | Add-Member -MemberType ScriptMethod -Name SetOwner -Value {
      param($account)
      $this.Owner = $account.Value
    }
    Mock Get-Acl {
      $script:aclReads++
      $acl
    }
    Mock Set-Acl {}

    $result = Confirm-WorktreeGitPointerOwnership -WorktreePath $script:worktree -InteractiveOperator $script:operator -Confirm:$false

    $result.Verified | Should -BeTrue
    $result.Repaired | Should -BeTrue
    Assert-MockCalled Set-Acl -Times 1 -Exactly -ParameterFilter {
      $LiteralPath -eq (Join-Path $script:worktree '.git')
    }
    $script:aclReads | Should -Be 2
  }

  It 'fails closed on a mismatch when repair is disabled' {
    Mock Get-Acl { [PSCustomObject]@{ Owner = 'BUILTIN\Administrators' } }
    Mock Set-Acl {}

    {
      Confirm-WorktreeGitPointerOwnership `
        -WorktreePath $script:worktree `
        -InteractiveOperator $script:operator `
        -RepairOwnership:$false `
        -Confirm:$false
    } | Should -Throw '*not interactive operator*'

    Assert-MockCalled Set-Acl -Times 0 -Exactly
  }

  It 'contains no safe.directory mutation or wildcard trust' {
    $source = Get-Content -LiteralPath "$PSScriptRoot\..\..\private\Confirm-WorktreeGitPointerOwnership.ps1" -Raw
    $source | Should -Not -Match 'safe\.directory'
    $source | Should -Not -Match 'config\s+--global\s+--add'
  }
}

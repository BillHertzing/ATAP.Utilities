#Requires -Version 7.0
BeforeAll {
  $moduleRoot = Join-Path $PSScriptRoot '../..'
  foreach ($file in @('Get-SprintEndActiveWorkspaceRoot', 'Invoke-SprintEndNativeCommand', 'Get-SprintWorktreeRecoveryState', 'Remove-SprintWorktreeResidual')) { . (Join-Path $moduleRoot "private/$file.ps1") }
  . (Join-Path $moduleRoot 'public/Remove-SprintWorktreeSafely.ps1')
}
Describe 'Remove-SprintWorktreeSafely recovery contracts' -Tag 'Unit' {
  BeforeEach {
    $script:caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $script:repository = Join-Path $caseRoot 'owner'
    $script:worktree = Join-Path $caseRoot 'target'
    $script:handoff = Join-Path $caseRoot 'handoff.md'
    New-Item -ItemType Directory $script:repository,$script:worktree -Force | Out-Null
    Mock Get-SprintEndActiveWorkspaceRoot { @() }
    Mock Invoke-SprintEndNativeCommand {
      if ($ArgumentList[2] -eq 'rev-parse' -and $ArgumentList -contains '--git-common-dir') { return [pscustomobject]@{ Succeeded=$true; ExitCode=0; Output=@((Join-Path $script:repository '.git')) } }
      return [pscustomobject]@{ Succeeded=$true; ExitCode=0; Output=@("worktree $script:repository",'HEAD aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa') }
    }
  }
  It 'blocks active roots before Git and writes the remaining teardown only' {
    Mock Get-SprintEndActiveWorkspaceRoot { @([pscustomobject]@{ Source='CurrentLocation';Root=$script:worktree }) }
    $result=Remove-SprintWorktreeSafely -RepositoryPath $repository -WorktreePath $worktree -HandoffPath $handoff -Confirm:$false
    $result.Ok | Should -BeFalse
    $result.Attempts | Should -Be 0
    Get-Content $handoff -Raw | Should -Match 'Remove-SprintWorktreeSafely'
    Should -Invoke Invoke-SprintEndNativeCommand -Times 0 -Exactly
  }
  It 'requires explicit evidence for an unregistered existing directory' {
    $result=Remove-SprintWorktreeSafely -RepositoryPath $repository -WorktreePath $worktree -HandoffPath $handoff -Confirm:$false
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'not registered'
    Test-Path $worktree | Should -BeTrue
  }
  It 'rejects wrong-root forged receipt before any mutation' {
    $receipt=Join-Path $caseRoot 'receipt.json'
    @{SchemaVersion=1;RepositoryPath=$repository;WorktreePath='C:/wrong';CommonDirectory=(Join-Path $repository '.git');Head=('a'*40);RecoveryReference='refs/archive/test';Deregistered=$true}|ConvertTo-Json|Set-Content $receipt
    {Get-SprintWorktreeRecoveryState -RepositoryPath $repository -WorktreePath $worktree -ReceiptPath $receipt}|Should -Throw '*identity mismatch*'
  }
  It 'rejects a forged deregistered receipt without the native-success provenance' {
    $receipt=Join-Path $caseRoot 'receipt.json'
    @{SchemaVersion=1;RepositoryPath=$repository;WorktreePath=$worktree;CommonDirectory=(Join-Path $repository '.git');Head=('a'*40);RecoveryReference='refs/archive/test';Deregistered=$true;BeforeRegistration=@("worktree $worktree",('HEAD '+('a'*40)));NativeAttempts=@();AfterRegistration=@("worktree $repository",('HEAD '+('a'*40)))}|ConvertTo-Json -Depth 8|Set-Content $receipt
    {Get-SprintWorktreeRecoveryState -RepositoryPath $repository -WorktreePath $worktree -ReceiptPath $receipt}|Should -Throw '*successful native removal*'
  }
  It 'rejects legacy import without explicit opt-in' {
    {Get-SprintWorktreeRecoveryState -RepositoryPath $repository -WorktreePath $worktree -ReceiptPath (Join-Path $caseRoot 'absent.json') -LegacyRecoveryEvidencePath 'anything'}|Should -Throw '*explicit*'
  }
  It 'rejects malformed legacy evidence and wrong binary provenance' {
    $legacy=Join-Path $caseRoot 'legacy.json'
    @{SchemaVersion=1;RepositoryPath=$repository;WorktreePath=$worktree;InstalledModuleSha256='forged'}|ConvertTo-Json|Set-Content $legacy
    {Get-SprintWorktreeRecoveryState -RepositoryPath $repository -WorktreePath $worktree -ReceiptPath (Join-Path $caseRoot 'absent.json') -LegacyRecoveryEvidencePath $legacy -AcceptLegacy043Recovery}|Should -Throw '*provenance*'
  }
  It 'rejects escaping and nested placeholder paths' {
    {Remove-SprintWorktreeSafely -RepositoryPath $repository -WorktreePath $worktree -AdapterPlaceholderPath '../escape' -Confirm:$false}|Should -Throw '*outside the worktree*'
    {Remove-SprintWorktreeSafely -RepositoryPath $repository -WorktreePath $worktree -AdapterPlaceholderPath 'a/b' -Confirm:$false}|Should -Throw '*direct child*'
  }
  It 'removes an explicitly selected empty ordinary placeholder nonrecursively' {
    New-Item -ItemType Directory (Join-Path $worktree '.codex') | Out-Null
    $events=[Collections.Generic.List[string]]::new()
    Remove-SprintWorktreeResidual -Root $worktree -PlaceholderPath '.codex' -JunctionTarget @{} -DirectoryRoot @() -Record {param($event,$detail) $events.Add($event)} | Out-Null
    Test-Path $worktree | Should -BeFalse
    $events | Should -Contain 'EmptyDirectoryRemoved'
  }
  It 'refuses a hidden file before removing any approved sibling' {
    New-Item -ItemType Directory (Join-Path $worktree '.codex'),(Join-Path $worktree '_generated') | Out-Null
    Set-Content (Join-Path $worktree '_generated/.keep') 'retain'
    {Remove-SprintWorktreeResidual -Root $worktree -PlaceholderPath '.codex' -JunctionTarget @{} -DirectoryRoot '_generated' -Record {throw 'No effect allowed'}}|Should -Throw '*file is forbidden*'
    Test-Path (Join-Path $worktree '.codex')|Should -BeTrue
  }
  It 'rejects unknown root entries and unsupported reparse tags' {
    New-Item -ItemType Directory (Join-Path $worktree 'unknown') | Out-Null
    {Remove-SprintWorktreeResidual -Root $worktree -PlaceholderPath @() -JunctionTarget @{} -DirectoryRoot @() -Record {}}|Should -Throw '*Unapproved residual*'
  }
  It 'contains no recursive deletion or global worktree prune surface' {
    $source=Get-Content (Join-Path $moduleRoot 'public/Remove-SprintWorktreeSafely.ps1') -Raw
    $source|Should -Not -Match 'Remove-Item[^\r\n]*-Recurse|Directory\.Delete\([^\r\n]*\$true\)|''worktree'', ''prune'''
    $source|Should -Match 'for \(\$attempt = 1; \$attempt -le \$MaxAttempts; \$attempt\+\+\)'
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

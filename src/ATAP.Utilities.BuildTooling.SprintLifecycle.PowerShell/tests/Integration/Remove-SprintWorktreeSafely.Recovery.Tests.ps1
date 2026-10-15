#Requires -Version 7.0
BeforeAll {
  $moduleRoot = Join-Path $PSScriptRoot '../..'
  foreach ($file in @('Get-SprintEndActiveWorkspaceRoot', 'Invoke-SprintEndNativeCommand', 'Get-SprintWorktreeRecoveryState', 'Remove-SprintWorktreeResidual', 'Remove-SprintWorktreeRecoveryMetadata')) { . (Join-Path $moduleRoot "private/$file.ps1") }
  . (Join-Path $moduleRoot 'public/Remove-SprintWorktreeSafely.ps1')
  $repoRoot = [IO.Path]::GetFullPath((Join-Path $moduleRoot '../..'))
  $fixtureBase = Join-Path $repoRoot ('_generated/Remover044Integration/' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory $fixtureBase -Force | Out-Null
  function New-RemovalFixture {
    $root = Join-Path $fixtureBase ([guid]::NewGuid().ToString('N'))
    $owner = Join-Path $root 'owner'; $worktree = Join-Path $root 'target'
    New-Item -ItemType Directory $root -Force | Out-Null
    & git init --quiet $owner
    & git -C $owner -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty --quiet -m fixture
    & git -C $owner worktree add --quiet --detach $worktree HEAD
    if ($LASTEXITCODE) { throw 'Fixture Git initialization failed.' }
    return @{ RepositoryPath = $owner; WorktreePath = $worktree; ReceiptPath = (Join-Path $root 'receipt.json'); Confirm = $false }
  }
}
Describe 'Safe worktree recovery Windows filesystem integration' -Tag 'Integration' {
  BeforeEach { Mock Get-SprintEndActiveWorkspaceRoot { @() } }
  It 'removes a normal registered worktree and persists exact attempt and recovery ref' {
    $f = New-RemovalFixture
    $result = Remove-SprintWorktreeSafely @f
    $result.Ok | Should -BeTrue
    $result.Attempts | Should -Be 1
    Test-Path $f.WorktreePath | Should -BeFalse
    $receipt = Get-Content $f.ReceiptPath -Raw | ConvertFrom-Json
    $receipt.Deregistered | Should -BeTrue
    $receipt.NativeAttempts.Count | Should -Be 1
    (& git -C $f.RepositoryPath rev-parse $receipt.RecoveryReference) | Should -Be $receipt.Head
  }
  It 'unlinks an actual approved junction while preserving the stable target' {
    $f = New-RemovalFixture
    $stable = Join-Path (Split-Path $f.RepositoryPath) 'stable-config'
    New-Item -ItemType Directory $stable | Out-Null
    Set-Content (Join-Path $stable 'retain.txt') 'retain'
    New-Item -ItemType Junction -Path (Join-Path $f.WorktreePath '.vscode') -Target $stable | Out-Null
    $before = (Get-FileHash (Join-Path $stable 'retain.txt')).Hash
    $result = Remove-SprintWorktreeSafely @f -ApprovedJunctionTarget @{ '.vscode' = $stable }
    $result.Ok | Should -BeTrue
    $result.Attempts | Should -Be 1
    (Get-FileHash (Join-Path $stable 'retain.txt')).Hash | Should -Be $before
    $receipt = Get-Content $f.ReceiptPath -Raw | ConvertFrom-Json
    @($receipt.Events | Where-Object Event -EQ 'JunctionUnlinked').Count | Should -Be 1
  }
  It 'removes a real zero-file Dropbox 0x9000e01a tree with individual empty removals' -Tag 'Cloud' {
    $f = New-RemovalFixture
    $cloud = Join-Path $f.WorktreePath '_generated/a/b/c'
    New-Item -ItemType Directory $cloud -Force | Out-Null
    $query = (& fsutil.exe reparsepoint query $cloud 2>&1) -join "`n"
    if ($query -notmatch '0x9000e01a') {
      Set-ItResult -Skipped -Because 'Dropbox provider has not tagged this isolated fixture; actual cloud consumption acceptance is deferred to installed typed recovery.'
      return
    }
    $result = Remove-SprintWorktreeSafely @f -ResidualDirectoryRoot '_generated'
    $result.Ok | Should -BeTrue
    $result.Attempts | Should -Be 1
    $receipt = Get-Content $f.ReceiptPath -Raw | ConvertFrom-Json
    @($receipt.Events | Where-Object Event -EQ 'EmptyDirectoryRemoved').Count | Should -BeGreaterThan 0
  }
  It 'WhatIf produces no recovery reference, receipt, handoff or removal' {
    $f = New-RemovalFixture; $f.Remove('Confirm')
    $result = Remove-SprintWorktreeSafely @f -WhatIf
    $result.Planned | Should -BeTrue
    Test-Path $f.ReceiptPath | Should -BeFalse
    Test-Path ([IO.Path]::ChangeExtension($f.ReceiptPath, '.handoff.md')) | Should -BeFalse
    @(& git -C $f.RepositoryPath for-each-ref refs/archive).Count | Should -Be 0
    Test-Path $f.WorktreePath | Should -BeTrue
  }
  It 'rejects a changed junction target and preserves both targets' {
    $f = New-RemovalFixture
    $stable = Join-Path (Split-Path $f.RepositoryPath) 'stable'
    New-Item -ItemType Directory $stable | Out-Null
    Set-Content (Join-Path $stable 'retain.txt') 'retain'
    New-Item -ItemType Junction -Path (Join-Path $f.WorktreePath '.vscode') -Target $stable | Out-Null
    $result = Remove-SprintWorktreeSafely @f -ApprovedJunctionTarget @{ '.vscode' = (Join-Path $stable 'wrong') }
    $result.Ok | Should -BeFalse
    Test-Path (Join-Path $stable 'retain.txt') | Should -BeTrue
  }
  It 'preserves unselected nested worktrees and unrelated sibling registrations' {
    $f = New-RemovalFixture
    $child = Join-Path $f.WorktreePath '_generated/child'
    & git -C $f.RepositoryPath worktree add --quiet --detach $child HEAD
    $result = Remove-SprintWorktreeSafely @f
    $result.Ok | Should -BeFalse
    $result.Attempts | Should -Be 0
    Test-Path (Join-Path $child '.git') | Should -BeTrue
  }
  It 'resumes a genuine deregistration receipt without another native removal' {
    $f = New-RemovalFixture
    $first = Remove-SprintWorktreeSafely @f -ResidualDirectoryRoot '_generated'
    $first.Ok | Should -BeTrue
    New-Item -ItemType Directory (Join-Path $f.WorktreePath '_generated/a/b') -Force | Out-Null
    $second = Remove-SprintWorktreeSafely @f -ResidualDirectoryRoot '_generated'
    $second.Ok | Should -BeTrue
    $second.Attempts | Should -Be 0
    (Get-Content $f.ReceiptPath -Raw | ConvertFrom-Json).NativeAttempts.Count | Should -Be 1
  }
  It 'rejects a widened manifest or a recreated same-HEAD registration on resume' {
    $f = New-RemovalFixture
    Remove-SprintWorktreeSafely @f -ResidualDirectoryRoot '_generated' | Out-Null
    New-Item -ItemType Directory (Join-Path $f.WorktreePath '_generated') -Force | Out-Null
    $widen = Remove-SprintWorktreeSafely @f -ResidualDirectoryRoot @('_generated','extra')
    $widen.Ok | Should -BeFalse
    $widen.Failures -join ' ' | Should -Match 'manifest changed'
    [IO.Directory]::Delete((Join-Path $f.WorktreePath '_generated'),$false)
    [IO.Directory]::Delete($f.WorktreePath,$false)
    & git -C $f.RepositoryPath worktree add --quiet --detach $f.WorktreePath HEAD
    $recreated = Remove-SprintWorktreeSafely @f -ResidualDirectoryRoot '_generated'
    $recreated.Ok | Should -BeFalse
    $recreated.Failures -join ' ' | Should -Match 'current registered checkout'
    Test-Path (Join-Path $f.WorktreePath '.git') | Should -BeTrue
  }
  It 'removes selected live cross-owner children first and retains unrelated siblings' {
    $f = New-RemovalFixture
    $other = New-RemovalFixture
    $child = Join-Path $f.WorktreePath '_generated/cross-owner'
    & git -C $other.RepositoryPath worktree add --quiet --detach $child HEAD
    $head = & git -C $other.RepositoryPath rev-parse HEAD
    $ref = 'refs/archive/remover-test/' + $head
    & git -C $other.RepositoryPath update-ref $ref $head
    $plan = @{RepositoryPath=$other.RepositoryPath;WorktreePath=$child;Head=$head;RecoveryReference=$ref}
    $result = Remove-SprintWorktreeSafely @f -OwningRepositoryPath $other.RepositoryPath -SelectedNestedWorktree $plan -ResidualDirectoryRoot '_generated'
    $result.Ok | Should -BeTrue
    Test-Path $other.WorktreePath | Should -BeTrue
    (& git -C $other.RepositoryPath rev-parse $ref) | Should -Be $head
    (& git -C $other.RepositoryPath worktree list --porcelain) -join ' ' | Should -Not -Match ([regex]::Escape($child.Replace('\','/')))
  }
  It 'scopes prunable metadata removal to the selected slot and preserves an unrelated slot' {
    $f = New-RemovalFixture
    $other = New-RemovalFixture
    $child = Join-Path $f.WorktreePath '_generated/selected'
    & git -C $other.RepositoryPath worktree add --quiet --detach $child HEAD
    $head = & git -C $other.RepositoryPath rev-parse HEAD
    $ref = 'refs/archive/remover-test/' + $head
    & git -C $other.RepositoryPath update-ref $ref $head
    $admin = (& git -C $child rev-parse --absolute-git-dir)
    [IO.File]::Delete((Join-Path $child '.git'))
    $plan = @{RepositoryPath=$other.RepositoryPath;WorktreePath=$child;Head=$head;RecoveryReference=$ref;AdministrativePath=$admin}
    $result = Remove-SprintWorktreeSafely @f -OwningRepositoryPath $other.RepositoryPath -SelectedNestedWorktree $plan -ResidualDirectoryRoot '_generated'
    $result.Ok | Should -BeTrue
    Test-Path $admin | Should -BeFalse
    Test-Path (Join-Path $other.WorktreePath '.git') | Should -BeTrue
    $receipt = Get-Content $f.ReceiptPath -Raw | ConvertFrom-Json
    $receipt.MetadataSlots[0].Completed | Should -BeTrue
    @($receipt.Events | Where-Object Event -EQ 'SelectedMetadataFileRemoved').Count | Should -BeGreaterThan 0
  }
  It 'keeps bounded native failures visible without residual deletion' {
    $f = New-RemovalFixture
    $nativeImplementation = ${function:Invoke-SprintEndNativeCommand}
    Mock Invoke-SprintEndNativeCommand {
      if ($ArgumentList[3] -eq 'remove') { return [pscustomobject]@{ FilePath='git';ArgumentList=$ArgumentList;Succeeded=$false;ExitCode=32;Output=@('fixture failure') } }
      & $nativeImplementation -FilePath $FilePath -ArgumentList $ArgumentList -AllowNonZeroExitCode
    }
    $result = Remove-SprintWorktreeSafely @f -MaxAttempts 2 -RetryDelayMilliseconds 0
    $result.Ok | Should -BeFalse
    $result.Attempts | Should -Be 2
    $result.Failures -join ' ' | Should -Match 'exit code 32'
    Test-Path $f.WorktreePath | Should -BeTrue
    (Get-Content $f.ReceiptPath -Raw | ConvertFrom-Json).NativeAttempts.Count | Should -Be 2
  }
  It 'resumes a journaled slot after gitdir or HEAD deletion without trusting vanished files' {
    $f = New-RemovalFixture
    $child = Join-Path $f.WorktreePath '_generated/interrupted'
    & git -C $f.RepositoryPath worktree add --quiet --detach $child HEAD
    $head = & git -C $f.RepositoryPath rev-parse HEAD
    $ref = 'refs/archive/remover-test/' + $head
    & git -C $f.RepositoryPath update-ref $ref $head
    $admin = & git -C $child rev-parse --absolute-git-dir
    [IO.File]::Delete((Join-Path $child '.git'))
    $selection = @{RepositoryPath=$f.RepositoryPath;WorktreePath=$child;Head=$head;RecoveryReference=$ref;AdministrativePath=$admin}
    $state = @{ MetadataSlots=@(); Events=@() }
    $record = {param($event,$detail)
      $state.Events += @{Event=$event;Detail=$detail}
      if ($event -eq 'SelectedMetadataFileRemoved' -and (Split-Path $detail -Leaf) -eq 'gitdir') { throw 'simulated process interruption after effect' }
    }
    {Remove-SprintWorktreeRecoveryMetadata -Selection $selection -State $state -Record $record}|Should -Throw '*interruption*'
    $state = $state | ConvertTo-Json -Depth 30 | ConvertFrom-Json -AsHashtable
    Remove-SprintWorktreeRecoveryMetadata -Selection $selection -State $state -Record {param($event,$detail) $state.Events += @{Event=$event;Detail=$detail}}
    $state.MetadataSlots[0].Completed|Should -BeTrue
    Test-Path $admin|Should -BeFalse
  }
  It 'imports authentic installed .43 failure evidence only with explicit opt-in' {
    $f = New-RemovalFixture
    $module43 = 'C:/Program Files/PowerShell/Modules/ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell/0.1.43/ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell.psm1'
    $hash=(Get-FileHash $module43 -Algorithm SHA256).Hash
    $hash|Should -Be 'E26A75A7FF932FE943F3C654444470E3B8B057042BF80215B22E34A03170CC2E'
    $head=& git -C $f.RepositoryPath rev-parse HEAD
    $ref='refs/archive/remover-test/'+$head
    & git -C $f.RepositoryPath update-ref $ref $head
    $before=@{InstalledModuleVersion='0.1.43';InstalledModuleSha256=$hash;Repositories=@(@{Repository=$f.RepositoryPath;Worktree=$f.WorktreePath;WorktreeHead=$head;Registration=@(& git -C $f.RepositoryPath worktree list --porcelain)})}
    $stable=Join-Path (Split-Path $f.RepositoryPath) 'legacy-stable'
    New-Item -ItemType Directory $stable|Out-Null
    Set-Content (Join-Path $stable 'retain.txt') 'retain'
    New-Item -ItemType Junction -Path (Join-Path $f.WorktreePath '.vscode') -Target $stable|Out-Null
    # Isolated dynamic module binds genuine installed .43 code without replacing .44.
    $legacyModule=New-Module -Name ('LegacyRemoverTest'+[guid]::NewGuid().ToString('N')) -ScriptBlock {param($source) . $source} -ArgumentList $module43
    $legacyCommand=& $legacyModule {Get-Command Remove-SprintWorktreeSafely}
    $old=& $legacyCommand -RepositoryPath $f.RepositoryPath -WorktreePath $f.WorktreePath -HandoffPath (Join-Path (Split-Path $f.RepositoryPath) 'old-handoff.md') -MaxAttempts 3 -RetryDelayMilliseconds 0 -Confirm:$false
    $old.Ok|Should -BeFalse
    $old.Failures -join ' '|Should -Match 'Attempt 2 failed with Git exit code 128'
    $beforePath=Join-Path (Split-Path $f.RepositoryPath) 'before.json';$before|ConvertTo-Json -Depth 15|Set-Content $beforePath
    $oldPath=Join-Path (Split-Path $f.RepositoryPath) 'old.json';$old|ConvertTo-Json -Depth 15|Set-Content $oldPath
    $legacyPath=Join-Path (Split-Path $f.RepositoryPath) 'legacy.json'
    @{SchemaVersion=1;RepositoryPath=$f.RepositoryPath;WorktreePath=$f.WorktreePath;Head=$head;RecoveryReference=$ref;BeforeSnapshotPath=$beforePath;FailedReceiptPath=$oldPath;InstalledModulePath=$module43;InstalledModuleSha256=$hash}|ConvertTo-Json|Set-Content $legacyPath
    $result=Remove-SprintWorktreeSafely @f -LegacyRecoveryEvidencePath $legacyPath -AcceptLegacy043Recovery -ApprovedJunctionTarget @{'.vscode'=$stable}
    $result.Ok|Should -BeTrue
    $result.Attempts|Should -Be 0
    Get-Content (Join-Path $stable 'retain.txt') -Raw|Should -Match 'retain'
    $old.Failures = @('Attempt 1 failed with Git exit code 1.') + @($old.Failures)
    $old|ConvertTo-Json -Depth 15|Set-Content $oldPath
    {Get-SprintWorktreeRecoveryState -RepositoryPath $f.RepositoryPath -WorktreePath $f.WorktreePath -ReceiptPath ($f.ReceiptPath+'.unwritten') -LegacyRecoveryEvidencePath $legacyPath -AcceptLegacy043Recovery}|Should -Throw '*semantics mismatch*'
  }
  It 'unlinks only an approved nested dangling junction without following its absent target' {
    $f=New-RemovalFixture
    $parent=Join-Path $f.WorktreePath '_generated/installer-tests'
    New-Item -ItemType Directory $parent -Force|Out-Null
    $destination=Join-Path (Split-Path $f.RepositoryPath) 'absent-destination'
    New-Item -ItemType Directory $destination|Out-Null
    New-Item -ItemType Junction -Path (Join-Path $parent 'actual-junction') -Target $destination|Out-Null
    [IO.Directory]::Delete($destination,$false)
    $map=@{'_generated/installer-tests/actual-junction'=$destination}
    $result=Remove-SprintWorktreeSafely @f -ApprovedJunctionTarget $map -ResidualDirectoryRoot '_generated'
    $result.Ok|Should -BeTrue
    $result.Attempts|Should -Be 1
    Test-Path $destination|Should -BeFalse
  }
  It 'refuses unknown and changed-target nested junctions before any residual effect' {
    $f=New-RemovalFixture
    # A genuine deregistration receipt gives this residual-only test its authority.
    Remove-SprintWorktreeSafely @f -ResidualDirectoryRoot '_generated'|Out-Null
    $parent=Join-Path $f.WorktreePath '_generated/nested'
    New-Item -ItemType Directory $parent -Force|Out-Null
    $stable=Join-Path (Split-Path $f.RepositoryPath) 'nested-stable'
    New-Item -ItemType Directory $stable|Out-Null
    Set-Content (Join-Path $stable 'retain.txt') 'retain'
    New-Item -ItemType Junction -Path (Join-Path $parent 'actual-junction') -Target $stable|Out-Null
    $result=Remove-SprintWorktreeSafely @f -ResidualDirectoryRoot '_generated'
    $result.Ok|Should -BeFalse
    $result.Failures -join ' '|Should -Match 'junction'
    Test-Path (Join-Path $stable 'retain.txt')|Should -BeTrue
    {Remove-SprintWorktreeResidual -Root $f.WorktreePath -DirectoryRoot '_generated' -JunctionTarget @{'_generated/nested/actual-junction'=(Join-Path $stable 'wrong')} -Record {throw 'No effect allowed'}}|Should -Throw '*junction*'
    Test-Path $parent|Should -BeTrue
  }
  It 'rejects traversal or nested junctions outside an explicit directory-root manifest' {
    $f=New-RemovalFixture
    {Remove-SprintWorktreeSafely @f -ApprovedJunctionTarget @{'../outside'='C:/outside'}}|Should -Throw '*traversal*'
    {Remove-SprintWorktreeSafely @f -ApprovedJunctionTarget @{'unselected/actual-junction'='C:/outside'}}|Should -Throw '*explicitly allowed directory root*'
  }
  It 'bounds transient failures and succeeds on the third native attempt with history retained' {
    $f=New-RemovalFixture
    $nativeImplementation=${function:Invoke-SprintEndNativeCommand}
    $script:transientCount=0
    Mock Invoke-SprintEndNativeCommand {
      if ($ArgumentList[3] -eq 'remove') {
        $script:transientCount++
        if ($script:transientCount -lt 3) { return [pscustomobject]@{FilePath='git';ArgumentList=$ArgumentList;Succeeded=$false;ExitCode=32;Output=@('transient fixture lock')} }
      }
      & $nativeImplementation -FilePath $FilePath -ArgumentList $ArgumentList -AllowNonZeroExitCode
    }
    $result=Remove-SprintWorktreeSafely @f -MaxAttempts 3 -RetryDelayMilliseconds 0
    $result.Ok|Should -BeTrue
    $result.Attempts|Should -Be 3
    $result.Failures.Count|Should -Be 2
    (Get-Content $f.ReceiptPath -Raw|ConvertFrom-Json).NativeAttempts.Count|Should -Be 3
  }
  It 'pins owners and every completed nested selection identity across resume' {
    $f=New-RemovalFixture;$other=New-RemovalFixture
    $child=Join-Path $f.WorktreePath '_generated/pinned'
    & git -C $other.RepositoryPath worktree add --quiet --detach $child HEAD
    $head=& git -C $other.RepositoryPath rev-parse HEAD
    $ref='refs/archive/remover-test/'+$head
    & git -C $other.RepositoryPath update-ref $ref $head
    $admin=& git -C $child rev-parse --absolute-git-dir
    $plan=@{RepositoryPath=$other.RepositoryPath;WorktreePath=$child;Head=$head;RecoveryReference=$ref;AdministrativePath=$admin}
    (Remove-SprintWorktreeSafely @f -OwningRepositoryPath $other.RepositoryPath -SelectedNestedWorktree $plan -ResidualDirectoryRoot '_generated').Ok|Should -BeTrue
    $pinned=(Get-Content $f.ReceiptPath -Raw|ConvertFrom-Json).NestedPlan
    $variants=@()
    foreach($field in @('AdministrativePath','RecoveryReference','Head','ResidualDirectoryRoot')) {
      $variant=$plan.Clone()
      $variant[$field]=switch($field){AdministrativePath {$admin+'-wrong'} RecoveryReference {$ref+'-wrong'} Head {'b'*40} ResidualDirectoryRoot {@('_generated')}}
      $variants+=@{Owners=@($other.RepositoryPath);Rows=@($variant)}
    }
    $variants+=@{Owners=@($other.RepositoryPath,$other.WorktreePath);Rows=@($plan)}
    $variants+=@{Owners=@($other.RepositoryPath);Rows=@($plan,$plan.Clone())}
    $variants+=@{Owners=@($other.RepositoryPath);Rows=@()}
    foreach($variant in $variants) {
      $result=Remove-SprintWorktreeSafely @f -OwningRepositoryPath $variant.Owners -SelectedNestedWorktree $variant.Rows -ResidualDirectoryRoot '_generated'
      $result.Ok|Should -BeFalse
      $result.Failures -join ' '|Should -Match 'nested recovery plan changed'
      (Get-Content $f.ReceiptPath -Raw|ConvertFrom-Json).NestedPlan|Should -Be $pinned
      Test-Path (Join-Path $other.WorktreePath '.git')|Should -BeTrue
    }
  }
  It 'WhatIf validates prunable slot identity and unexpected files with zero receipt or metadata effects' {
    $f=New-RemovalFixture
    $child=Join-Path $f.WorktreePath '_generated/preview'
    & git -C $f.RepositoryPath worktree add --quiet --detach $child HEAD
    $head=& git -C $f.RepositoryPath rev-parse HEAD
    $ref='refs/archive/remover-test/'+$head
    & git -C $f.RepositoryPath update-ref $ref $head
    $admin=& git -C $child rev-parse --absolute-git-dir
    [IO.File]::Delete((Join-Path $child '.git'))
    $plan=@{RepositoryPath=$f.RepositoryPath;WorktreePath=$child;Head=$head;RecoveryReference=$ref;AdministrativePath=$admin}
    $state=@{Events=@()};$beforeState=$state|ConvertTo-Json -Compress
    Remove-SprintWorktreeRecoveryMetadata -Selection $plan -State $state -Record {throw 'Dry validation must not journal'} -InventoryOnly
    ($state|ConvertTo-Json -Compress)|Should -Be $beforeState
    $beforeRegistration=(& git -C $f.RepositoryPath worktree list --porcelain)-join "`n"
    $bad=$plan.Clone();$bad.AdministrativePath=$admin+'-unrelated'
    $result=Remove-SprintWorktreeSafely @f -SelectedNestedWorktree $bad -ResidualDirectoryRoot '_generated' -WhatIf
    $result.Ok|Should -BeFalse
    Test-Path $f.ReceiptPath|Should -BeFalse
    Test-Path ([IO.Path]::ChangeExtension($f.ReceiptPath,'.handoff.md'))|Should -BeFalse
    $unexpected=Join-Path $admin 'unexpected.bin';Set-Content $unexpected 'preserve'
    $hash=(Get-FileHash $unexpected).Hash
    $result=Remove-SprintWorktreeSafely @f -SelectedNestedWorktree $plan -ResidualDirectoryRoot '_generated' -WhatIf
    $result.Ok|Should -BeFalse
    $result.Failures -join ' '|Should -Match 'Unexpected administrative file'
    (Get-FileHash $unexpected).Hash|Should -Be $hash
    ((& git -C $f.RepositoryPath worktree list --porcelain)-join "`n")|Should -Be $beforeRegistration
    Test-Path $f.ReceiptPath|Should -BeFalse
    @(& git -C $f.RepositoryPath for-each-ref refs/archive/sprint-worktree-removal).Count|Should -Be 0
  }
  It 'refuses a junction target swapped by the journaling callback before unlink' {
    $f=New-RemovalFixture;$base=Split-Path $f.RepositoryPath
    $root=Join-Path $base 'residual';$first=Join-Path $base 'first';$second=Join-Path $base 'second'
    New-Item -ItemType Directory $root,$first,$second|Out-Null
    Set-Content (Join-Path $first 'retain.txt') 'first';Set-Content (Join-Path $second 'retain.txt') 'second'
    $link=Join-Path $root '.vscode';New-Item -ItemType Junction -Path $link -Target $first|Out-Null
    $secondHash=(Get-FileHash (Join-Path $second 'retain.txt')).Hash
    {Remove-SprintWorktreeResidual -Root $root -JunctionTarget @{'.vscode'=$first} -PlaceholderPath @() -DirectoryRoot @() -Record {
      param($event,$detail)
      if($event -eq 'BeforeJunctionUnlink'){[IO.Directory]::Delete($detail,$false);New-Item -ItemType Junction -Path $detail -Target $second|Out-Null}
    }}|Should -Throw '*junction*'
    (Get-Item $link -Force).Target|Should -Be $second
    (Get-FileHash (Join-Path $second 'retain.txt')).Hash|Should -Be $secondHash
    Test-Path (Join-Path $first 'retain.txt')|Should -BeTrue
  }
  It 'refuses a directory populated by the journaling callback before deletion' {
    $f=New-RemovalFixture;$root=Join-Path (Split-Path $f.RepositoryPath) 'residual'
    New-Item -ItemType Directory (Join-Path $root '_generated/a') -Force|Out-Null
    {Remove-SprintWorktreeResidual -Root $root -JunctionTarget @{} -PlaceholderPath @() -DirectoryRoot '_generated' -Record {
      param($event,$detail)
      if($event -eq 'BeforeEmptyDirectoryRemoval'){Set-Content (Join-Path $detail 'appeared.txt') 'retain'}
    }}|Should -Throw '*after journaling*'
    Test-Path (Join-Path $root '_generated/a/appeared.txt')|Should -BeTrue
  }
  It 'refuses an administrative ancestor replaced by a journaling callback and preserves its new target' {
    $f=New-RemovalFixture;$child=Join-Path $f.WorktreePath '_generated/swapped'
    & git -C $f.RepositoryPath worktree add --quiet --detach $child HEAD
    $head=& git -C $f.RepositoryPath rev-parse HEAD;$ref='refs/archive/remover-test/'+$head
    & git -C $f.RepositoryPath update-ref $ref $head
    $admin=& git -C $child rev-parse --absolute-git-dir
    [IO.File]::Delete((Join-Path $child '.git'))
    $plan=@{RepositoryPath=$f.RepositoryPath;WorktreePath=$child;Head=$head;RecoveryReference=$ref;AdministrativePath=$admin}
    $protected=Join-Path (Split-Path $f.RepositoryPath) 'protected-metadata';New-Item -ItemType Directory $protected|Out-Null
    $state=@{Events=@()}
    {Remove-SprintWorktreeRecoveryMetadata -Selection $plan -State $state -Record {
      param($event,$detail)
      $state.Events+=@{Event=$event;Detail=$detail}
      if($event -eq 'BeforeSelectedMetadataFileRemoval'){
        $relative=[IO.Path]::GetRelativePath($admin,$detail)
        $marker=Join-Path $protected $relative
        New-Item -ItemType Directory (Split-Path $marker -Parent) -Force|Out-Null
        Set-Content $marker 'protected'
        [IO.Directory]::Move($admin,$admin+'-retained')
        New-Item -ItemType Junction -Path $admin -Target $protected|Out-Null
      }
    }}|Should -Throw '*unsafe reparse point*'
    @(Get-ChildItem -LiteralPath $protected -File -Recurse | Get-Content) -join ' '|Should -Match 'protected'
    Test-Path (Join-Path ($admin+'-retained') 'gitdir')|Should -BeTrue
  }
  It 'rechecks every surviving metadata hash after journaling before deleting the intended file' {
    $f=New-RemovalFixture;$child=Join-Path $f.WorktreePath '_generated/changed-sibling'
    & git -C $f.RepositoryPath worktree add --quiet --detach $child HEAD
    $head=& git -C $f.RepositoryPath rev-parse HEAD;$ref='refs/archive/remover-test/'+$head
    & git -C $f.RepositoryPath update-ref $ref $head
    $admin=& git -C $child rev-parse --absolute-git-dir
    [IO.File]::Delete((Join-Path $child '.git'))
    $plan=@{RepositoryPath=$f.RepositoryPath;WorktreePath=$child;Head=$head;RecoveryReference=$ref;AdministrativePath=$admin}
    $state=@{Events=@()}
    {Remove-SprintWorktreeRecoveryMetadata -Selection $plan -State $state -Record {
      param($event,$detail)
      $state.Events+=@{Event=$event;Detail=$detail}
      if($event -eq 'BeforeSelectedMetadataFileRemoval'){Set-Content (Join-Path $admin 'index') 'changed after journal'}
    }}|Should -Throw '*Remaining administrative file changed*'
    Test-Path (Join-Path $admin 'commondir')|Should -BeTrue
    Test-Path (Join-Path $admin 'gitdir')|Should -BeTrue
  }
}


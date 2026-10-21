param([object]$ReceiptSink)
$script:backupReceiptSink = $ReceiptSink
BeforeAll {
  $script:backupReceiptSink = $ReceiptSink
  foreach ($name in @('Get-GeneratedRemediationTreeCensus','New-GeneratedRemediationFileArchive',
    'Restore-GeneratedRemediationFileArchive','New-GeneratedRemediationDirectoryArchive',
    'Restore-GeneratedRemediationDirectoryArchive','New-GeneratedRemediationCustodyBundle')) {
    . (Join-Path $PSScriptRoot ("../../private/$name.ps1"))
  }
  $script:realBackupBundle = (Get-Command New-GeneratedRemediationCustodyBundle).ScriptBlock
  $script:realBackupGetItem = Get-Command Get-Item -CommandType Cmdlet
  . "$PSScriptRoot\..\..\public\Invoke-GeneratedFolderRemediation.ps1"
  . "$PSScriptRoot\..\..\private\Get-GeneratedRemediationByteComparison.ps1"
  . "$PSScriptRoot\..\..\private\Get-GeneratedRemediationFileSnapshot.ps1"
  $script:realFileSnapshot = (Get-Command Get-GeneratedRemediationFileSnapshot).ScriptBlock
  $script:fixtureRoot = [IO.Path]::GetFullPath("$PSScriptRoot/../../../../_generated/Sprint0016/Task16.84/CarryoverByteGuardTests-v1/Fixtures")
  $script:realGitCommand = Get-Command 'C:/Program Files/Git/cmd/git.exe' -CommandType Application -ErrorAction Stop
  $ordinaryGit = Get-Command git -ErrorAction Stop
  if ($ordinaryGit.CommandType -ne 'Application' -or $ordinaryGit.Path -ine $script:realGitCommand.Path) {
    throw 'Unmocked public git resolution differs from the preferred Git executable.'
  }
  $script:realCompressArchive = Get-Command Compress-Archive -CommandType Function, Cmdlet
  $null = New-Item -ItemType Directory -Path $script:fixtureRoot -Force
  $cursor = $script:fixtureRoot
  while ($cursor) {
    $item = Get-Item -LiteralPath $cursor -Force
    if ($item.LinkType -or $item.Target) { throw 'Redirecting fixture ancestor.' }
    $cursor = Split-Path -Parent $cursor
  }

  function script:Get-TestCleanupPaths {
    param([string]$Root, [string]$Stable, [string]$Sprint)

    $separators = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd($separators)
    if ((Resolve-Path -LiteralPath $rootFull).ProviderPath -ine $rootFull -or
      (Get-Item -LiteralPath $rootFull -Force).LinkType) { throw 'Redirected fixture cleanup root.' }
    $stableFull = [IO.Path]::GetFullPath($Stable).TrimEnd($separators)
    $sprintFull = [IO.Path]::GetFullPath($Sprint).TrimEnd($separators)
    $basePrefix = $script:fixtureRoot.TrimEnd($separators) + [IO.Path]::DirectorySeparatorChar
    $rootPrefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    if (-not $rootFull.StartsWith($basePrefix, [StringComparison]::OrdinalIgnoreCase) -or
      -not $stableFull.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or
      -not $sprintFull.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or
      $stableFull -ine (Join-Path $rootFull 'Repo') -or
      $sprintFull -ine (Join-Path $rootFull 'Repo-wt-7-Sprint-0016-work-items')) {
      throw 'Fixture cleanup paths escape the owned root or expected children.'
    }
    [pscustomobject]@{ Root = $rootFull; Stable = $stableFull; Sprint = $sprintFull }
  }

  function script:New-TestFile {
    param([string]$Root, [string]$Relative, [string]$Content = 'x')
    $path = Join-Path $Root $Relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    Set-Content -LiteralPath $path -Value $Content -Encoding utf8
  }

  function script:Invoke-TestGit {
    param([string]$Repo, [Parameter(ValueFromRemainingArguments)][string[]]$GitArgs)
    $out = & $script:realGitCommand -C $Repo -c user.name=Test -c user.email=test@example.invalid -c core.autocrlf=false @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed: $out" }
    $out
  }
  function Get-TestSelectionManifest {
    param([string[]]$RelativePaths = @('_generated/Sprint0015/old-evidence.md'))
    $hash = 'A' * 64
    $rows = @(for ($i = 0; $i -lt $RelativePaths.Count; $i++) {
      $relative = $RelativePaths[$i]
      $files = @(foreach ($root in @($script:stable, $script:sprint)) {
        $path = Join-Path $root $relative
        [ordered]@{
          repositoryIdentity = 'Repo'; root = $root; relativePath = $relative
          bytes = (Get-Item -LiteralPath $path -Force).Length; sha256 = (Get-FileHash -LiteralPath $path).Hash
          tracked = $true
          streams = @(foreach ($stream in (Get-Item -LiteralPath $path -Stream '*' -Force | Where-Object Stream -CNE ':$DATA')) {
            [ordered]@{ name = $stream.Stream; bytes = $stream.Length
              sha256 = (Get-FileHash -LiteralPath ($path + ':' + $stream.Stream)).Hash
              archiveMember = 'streams/' + $stream.Stream; restoreVerified = $true }
          })
          streamInventoryComplete = $true
        }
      })
      [ordered]@{ id = "row$i"; kind = 'File'; baselineRowSHA256 = $hash; source = $files[0]; candidate = $files[1]; pathClassification = 'Regular'; protectionReasons = @(); proposedAction = 'Preserve'; approved = $false }
    })
    [ordered]@{
      schemaVersion = 1; runId = 'public-plan-fixture'; capturedUtc = '2026-10-21T12:00:00Z'; host = 'fixture'
      operation = 'SprintDuplicateSelection'; approved = $false
      repository = [ordered]@{ identity = 'Repo'; commonGitDir = (Invoke-TestGit $script:stable rev-parse --path-format=absolute --git-common-dir); stableRoot = $script:stable; sprintRoot = $script:sprint }
      worktrees = @(foreach ($role in @('Stable', 'Sprint')) {
        $root = if ($role -eq 'Stable') { $script:stable } else { $script:sprint }
        [ordered]@{ role = $role; root = $root; head = (Invoke-TestGit $root rev-parse HEAD); indexSHA256 = $hash; stagedSHA256 = $hash; unstagedSHA256 = $hash; untrackedSHA256 = $hash; inventoryComplete = $true }
      })
      baseline = [ordered]@{ origin = 'LiveStable'; manifestSHA256 = $hash; custodyReceiptSHA256 = $hash }
      rows = $rows
    }
  }

  function Save-TestSelectionManifest {
    param($Manifest)
    $path = Join-Path $script:gitRoot 'selection.json'
    [IO.File]::WriteAllText($path, ($Manifest | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
    @{ SelectionManifestPath = $path; ExpectedSelectionManifestSHA256 = (Get-FileHash -LiteralPath $path).Hash }
  }

  function Initialize-TestBackupFixture {
    $null = New-Item -ItemType Directory -Path $script:archive
    $script:backupFile = Join-Path $script:sprint '_generated/Sprint0015/old-evidence.md'
    $script:backupGenerated = Join-Path $script:sprint '_generated'
    $script:backupParent = Join-Path $script:backupGenerated 'Sprint0015'
    [IO.File]::WriteAllBytes($script:backupFile+':notes',[byte[]]@(1,2,0,4))
    [IO.File]::WriteAllBytes($script:backupFile+':empty',[byte[]]@())
    [IO.File]::WriteAllBytes($script:backupGenerated+':root-note',[byte[]]@(9,8,7,6))
    [IO.File]::WriteAllBytes($script:backupParent+':empty',[byte[]]@())
    [IO.File]::WriteAllBytes($script:backupParent+':'+[char]0x9644,[byte[]]@(9,0,255))
    New-TestFile $script:sprint '_generated/Sprint0017/keep.bin' 'future'
    $script:backupSourcePaths = @('_generated','_generated/Sprint0015','_generated/Sprint0015/old-evidence.md',
      '_generated/legacy-tracked.txt','_generated/Sprint0016','_generated/Sprint0016/Task16.80',
      '_generated/Sprint0016/Task16.80/evidence.md','_generated/Sprint0016/tracked-now.md',
      '_generated/sprint-end-0007','_generated/sprint-end-0007/stale.log',
      '_generated/SprintEnd0013-StableProjection','_generated/SprintEnd0013-StableProjection/p.json',
      '_generated/scratch','_generated/scratch/no-sprint-name.txt','_generated/Sprint0017','_generated/Sprint0017/keep.bin')
    $script:backupProofPaths = @('_generated','_generated/Sprint0015','_generated/Sprint0015/old-evidence.md')
    Save-TestSelectionManifest (Get-TestSelectionManifest)
  }

  function Get-TestBackupCensus {
    param([string]$RootPath,[int]$MaxEntries,[int]$MaxDepth)
    # Explicit synthetic fixture metadata, never the native census or a replacement walker.
    $paths = if ($RootPath -ceq $script:sprint) { $script:backupSourcePaths } else { $script:backupProofPaths }
    $rows = @(foreach ($relative in $paths) {
      $item = & $script:realBackupGetItem -LiteralPath (Join-Path $RootPath $relative) -Force
      [pscustomobject]@{RelativePath=$relative;Depth=[int]($relative.Split('/').Count-1)
        Kind=if($item.PSIsContainer){'Directory'}else{'File'};ReparseTag=$null
        Attributes=[long]$item.Attributes;CreationTicks=[long]$item.CreationTimeUtc.Ticks;LastWriteTicks=[long]$item.LastWriteTimeUtc.Ticks
        Length=if($item.PSIsContainer){$null}else{[long]$item.Length};Hold=$false}
    })
    $first = [pscustomobject]@{Rows=$rows;Holds=0}
    $second = [Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($first))
    [pscustomobject]@{SyntheticCensus=$true;Success=$true;Consistent=$true;StructuralInventoryComplete=$true;RootState='Present'
      Errors=@();FailedWalks=@();Binding=[pscustomobject]@{Root=$RootPath;RelativePath='_generated';MaxEntries=$MaxEntries;MaxDepth=$MaxDepth}
      Observations=@($first,$second)}
  }

}

Describe 'Invoke-GeneratedFolderRemediation [public]' {
  BeforeEach {
    $script:gitRoot = Join-Path $script:fixtureRoot ([guid]::NewGuid().ToString('N').Substring(0, 8))
    $script:stable = Join-Path $script:gitRoot 'Repo'
    $script:sprint = Join-Path $script:gitRoot 'Repo-wt-7-Sprint-0016-work-items'
    $script:archive = Join-Path $script:gitRoot 'archive'
    New-Item -ItemType Directory -Path $script:stable -Force | Out-Null

    Invoke-TestGit $script:stable init -q -b main | Out-Null
    New-TestFile $script:stable '.gitignore' '_generated/'
    New-TestFile $script:stable 'src/a.txt'
    New-TestFile $script:stable '_generated/Sprint0015/old-evidence.md'
    New-TestFile $script:stable '_generated/legacy-tracked.txt'
    Invoke-TestGit $script:stable add .gitignore src/a.txt | Out-Null
    Invoke-TestGit $script:stable add -f _generated/Sprint0015/old-evidence.md _generated/legacy-tracked.txt | Out-Null
    Invoke-TestGit $script:stable commit -q -m 'seed' | Out-Null

    Invoke-TestGit $script:stable worktree add -q -b sprint16 $script:sprint | Out-Null

    # Stable: untracked/ignored debris plus a current-sprint file that must be protected.
    New-TestFile $script:stable '_generated/AIAdapterBackups/backup.json'
    New-TestFile $script:stable '_generated/Sprint0016/current.md'

    # Sprint: current-sprint evidence (tracked and untracked), prior-sprint untracked, one modified inherited file.
    New-TestFile $script:sprint '_generated/Sprint0016/Task16.80/evidence.md'
    New-TestFile $script:sprint '_generated/Sprint0016/tracked-now.md'
    Invoke-TestGit $script:sprint add -f _generated/Sprint0016/tracked-now.md | Out-Null
    Invoke-TestGit $script:sprint commit -q -m 'sprint work' | Out-Null
    New-TestFile $script:sprint '_generated/sprint-end-0007/stale.log'
    New-TestFile $script:sprint '_generated/SprintEnd0013-StableProjection/p.json'
    New-TestFile $script:sprint '_generated/scratch/no-sprint-name.txt'
  }

  AfterEach {
    if ($script:gitRoot -and (Test-Path -LiteralPath $script:gitRoot)) {
      $cleanup = script:Get-TestCleanupPaths -Root $script:gitRoot -Stable $script:stable -Sprint $script:sprint
      & $script:realGitCommand -C $cleanup.Stable worktree remove --force $cleanup.Sprint 2>$null | Out-Null
      $cleanup = script:Get-TestCleanupPaths -Root $script:gitRoot -Stable $script:stable -Sprint $script:sprint
      Remove-Item -LiteralPath $cleanup.Root -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'creates an actual selected-file backup and restore from the manifest-bound Plan without source or Git changes' {
    $options = Initialize-TestBackupFixture
    Mock Get-GeneratedRemediationTreeCensus { Get-TestBackupCensus -RootPath $RootPath -MaxEntries $MaxEntries -MaxDepth $MaxDepth }
    $script:backupStreamPaths = [Collections.Generic.List[string]]::new()
    Mock Get-Item {
      $path = [IO.Path]::GetFullPath([string]$LiteralPath)
      if ($path.StartsWith($script:sprint+'\',[StringComparison]::OrdinalIgnoreCase)) {
        $script:backupStreamPaths.Add($path)
        if ($path -cnotin @($script:backupGenerated,$script:backupParent,$script:backupFile)) { throw 'Unselected source stream inventory.' }
      }
      & $script:realBackupGetItem @PesterBoundParameters
    } -ParameterFilter { $Stream -eq '*' }
    $sourcePaths = @($script:backupFile,($script:backupFile+':notes'),($script:backupFile+':empty'),
      ($script:backupGenerated+':root-note'),($script:backupParent+':empty'),($script:backupParent+':'+[char]0x9644))
    $sourceHashes = @(foreach ($path in $sourcePaths) { [pscustomobject]@{Path=$path;SHA256=(Get-FileHash -LiteralPath $path).Hash} })
    $gitBefore = @(foreach ($root in @($script:stable,$script:sprint)) {
      $index = (& $script:realGitCommand -C $root rev-parse --path-format=absolute --git-path index)
      [pscustomobject]@{Root=$root;Head=(& $script:realGitCommand -C $root rev-parse HEAD);IndexPath=$index;IndexSHA256=(Get-FileHash -LiteralPath $index).Hash;IndexBytes=[Convert]::ToBase64String([IO.File]::ReadAllBytes($index))}
    })
    $evidence = Join-Path $script:gitRoot 'backup-report.json'
    $expectedBytes = (Get-Item -LiteralPath $script:backupFile -Force).Length + 11
    $r = Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options -CreateBackup -ArchiveRoot $script:archive -AllowVerifiedCloudDirectoryMetadata -EvidencePath $evidence -Confirm:$false
    $r.Mode | Should -Be Backup
    $r.Errors.Count | Should -Be 0
    $entry = $r.Sprint[0]
    $entry.Action | Should -Be BackedUp
    $entry.Backup.Status | Should -Be Verified
    $bundle = $entry.Backup.Receipt
    $bundle.BundlePath | Should -BeExactly $entry.Backup.BundleRoot
    $bundle.RequestedRelativePaths.Count | Should -Be 1
    $bundle.RequestedRelativePaths[0] | Should -BeExactly '_generated/Sprint0015/old-evidence.md'
    $bundle.VerifiedEntries | Should -Be 3
    $bundle.VerifiedPayloadBytes | Should -Be $expectedBytes
    $bundle.SourceStreamVerification.Bytes | Should -Be $expectedBytes
    $bundle.ProofStreamVerification.Bytes | Should -Be $expectedBytes
    $bundle.CoherentTreeRestoreVerified | Should -BeTrue
    $bundle.AggregateSourceBytesRechecked | Should -BeTrue
    @($script:backupStreamPaths | Select-Object -Unique).Count | Should -Be 3
    $actual = @('_generated') + @(Get-ChildItem -LiteralPath (Join-Path $bundle.ProofRoot '_generated') -Recurse -Force | ForEach-Object {
      '_generated/' + [IO.Path]::GetRelativePath((Join-Path $bundle.ProofRoot '_generated'),$_.FullName).Replace('\','/')
    })
    @($actual).Count | Should -Be 3
    foreach ($relative in $script:backupProofPaths) { $actual | Should -Contain $relative }
    $digests = @(foreach ($row in $bundle.Entries) {
      foreach ($descriptor in $row.Writer.Manifest.Streams) {
        $sourcePath = Join-Path $script:sprint $row.RelativePath
        $proofPath = $row.Restore.ProofPath
        if ($descriptor.Name -cne ':$DATA') { $sourcePath += ':'+$descriptor.Name; $proofPath += ':'+$descriptor.Name }
        $sourceHash = (Get-FileHash -LiteralPath $sourcePath).Hash
        $proofHash = (Get-FileHash -LiteralPath $proofPath).Hash
        $sourceHash | Should -Be $descriptor.SHA256
        $proofHash | Should -Be $descriptor.SHA256
        [pscustomobject]@{RelativePath=$row.RelativePath;Name=$descriptor.Name;Bytes=$descriptor.Bytes;ManifestSHA256=$descriptor.SHA256;SourceSHA256=$sourceHash;ProofSHA256=$proofHash}
      }
    })
    $digests.Count | Should -Be 6
    foreach ($row in $sourceHashes) { (Get-FileHash -LiteralPath $row.Path).Hash | Should -Be $row.SHA256 }
    foreach ($before in $gitBefore) {
      (& $script:realGitCommand -C $before.Root rev-parse HEAD) | Should -Be $before.Head
      $indexHashAfter = (Get-FileHash -LiteralPath $before.IndexPath).Hash
      if($indexHashAfter -cne $before.IndexSHA256 -and $null -ne $script:backupReceiptSink){
        $script:backupReceiptSink.Add([pscustomobject]@{FailedIndexWitness=$before;AfterSHA256=$indexHashAfter
          AfterBytes=[Convert]::ToBase64String([IO.File]::ReadAllBytes($before.IndexPath))})
      }
      $indexHashAfter | Should -Be $before.IndexSHA256
    }
    foreach ($flag in @('Approved','CustodyVerified','NamedStreamsVerified','ReadyForRemoval')) {
      $r.$flag | Should -BeFalse
      $entry.$flag | Should -BeFalse
      $entry.Backup.$flag | Should -BeFalse
    }
    $entry.GitRemoved | Should -Be 0
    $entry.DeletedFiles | Should -Be 0
    Should -Invoke Get-GeneratedRemediationTreeCensus -Times 5 -Exactly -ParameterFilter { $AllowVerifiedCloudDirectoryMetadata }
    $saved = Get-Content -LiteralPath $evidence -Raw | ConvertFrom-Json -Depth 60
    $saved.Sprint[0].Backup.Receipt.Entries[0].Writer.Manifest.Streams[0].SHA256 | Should -Match '^[A-F0-9]{64}$'
    $r | Add-Member -NotePropertyName SyntheticBackupEvidence -NotePropertyValue ([pscustomobject]@{
      ActualProofPaths=$actual;ActualStreamDigests=$digests;SourceHashesBefore=$sourceHashes;GitBefore=$gitBefore
      SourceAndGitUnchanged=$true;SourceStreamAcquisitionPaths=@($script:backupStreamPaths | Select-Object -Unique)
      NoUnselectedStreamInventory=$true;SyntheticCensusUsed=$true;ActualArchiveRestoreIO=$true
    })
    if ($null -ne $script:backupReceiptSink) { $script:backupReceiptSink.Add($r) }
  }

  It 'does not invoke backup for ordinary Plan WhatIf no selected rows or a held manifest' {
    $options = Initialize-TestBackupFixture
    Mock New-GeneratedRemediationCustodyBundle { throw 'No bundle invocation expected.' }
    $plan = Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options
    $plan.Mode | Should -Be Plan
    $whatIf = Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options -CreateBackup -ArchiveRoot $script:archive -WhatIf
    $whatIf.Sprint[0].Backup.Status | Should -Be Skipped
    Test-Path -LiteralPath $whatIf.Sprint[0].Backup.BundleRoot | Should -BeFalse
    $manifest = Get-TestSelectionManifest
    $manifest.rows = @()
    $emptyOptions = Save-TestSelectionManifest $manifest
    $empty = Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @emptyOptions -CreateBackup -ArchiveRoot $script:archive -Confirm:$false
    $empty.Sprint[0].Backup.Status | Should -Be NoSelection
    $empty.Sprint[0].Action | Should -Be NothingToBackUp
    $emptyOptions.ExpectedSelectionManifestSHA256 = '0'*64
    $held = Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @emptyOptions -CreateBackup -ArchiveRoot $script:archive -Confirm:$false
    $held.Sprint[0].Action | Should -Be Held
    $held.Sprint[0].Backup.Status | Should -Be Held
    Should -Invoke New-GeneratedRemediationCustodyBundle -Times 0
    @(Get-ChildItem -LiteralPath $script:archive -Force).Count | Should -Be 0
  }

  It 'reports a held backup and retains partial output' {
    $options = Initialize-TestBackupFixture
    Mock New-GeneratedRemediationCustodyBundle {
      $null = New-Item -ItemType Directory -Path $BundleRoot
      [IO.File]::WriteAllText((Join-Path $BundleRoot 'partial.txt'),'retained')
      [pscustomobject]@{Status='Hold';BundlePath=$BundleRoot;BundleCreated=$true;Errors=@('simulated archive failure')}
    }
    $r = Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options -CreateBackup -ArchiveRoot $script:archive -Confirm:$false
    $r.Sprint[0].Action | Should -Be BackupHeld
    $r.Sprint[0].Backup.Status | Should -Be Held
    $r.Sprint[0].Backup.Receipt.Status | Should -Be Hold
    Get-Content -LiteralPath (Join-Path $r.Sprint[0].Backup.BundlePath 'partial.txt') -Raw | Should -Be retained
    $r.Errors -join ';' | Should -Match 'simulated archive failure'
  }

  It 'holds an actual backup receipt whose source binding was substituted' {
    $options = Initialize-TestBackupFixture
    Mock Get-GeneratedRemediationTreeCensus { Get-TestBackupCensus -RootPath $RootPath -MaxEntries $MaxEntries -MaxDepth $MaxDepth }
    Mock New-GeneratedRemediationCustodyBundle {
      $receipt = & $script:realBackupBundle @PesterBoundParameters
      $receipt.Status | Should -Be Verified -Because ($receipt.Errors -join ';')
      $receipt.InitialCensus.Binding.Root = $script:stable
      $receipt
    }
    $r = Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options -CreateBackup -ArchiveRoot $script:archive -Confirm:$false
    $r.Sprint[0].Action | Should -Be BackupHeld
    $r.Errors -join ';' | Should -Match 'receipt source/path/selection binding differs'
    Test-Path -LiteralPath $r.Sprint[0].Backup.BundleRoot | Should -BeTrue
  }

  It 'requires an existing external destination and explicit backup mode options' {
    $options = Save-TestSelectionManifest (Get-TestSelectionManifest)
    { Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo -CreateBackup } | Should -Throw '*requires*'
    { Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options -CreateBackup -ArchiveRoot $script:archive } | Should -Throw '*existing ArchiveRoot*'
    $null = New-Item -ItemType Directory -Path $script:archive
    { Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options -CreateBackup -ArchiveRoot $script:archive -NoArchive } | Should -Throw '*no NoArchive*'
    { Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options -AllowVerifiedCloudDirectoryMetadata:$false } | Should -Throw '*only with*'
    Mock New-GeneratedRemediationCustodyBundle { throw 'No bundle invocation permitted.' }
    $inside = Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options -CreateBackup -ArchiveRoot (Join-Path $script:sprint '_generated') -Confirm:$false
    $inside.Sprint[0].Action | Should -Be BackupHeld
    $inside.Errors -join ';' | Should -Match 'outside stable, sprint and common Git'
    Should -Invoke New-GeneratedRemediationCustodyBundle -Times 0
  }

  It 'narrows Plan to the bound manifest intersection without trusting supplied custody or snapshot digests' {
    $options = Save-TestSelectionManifest (Get-TestSelectionManifest)
    $raw = [IO.File]::ReadAllText($options.SelectionManifestPath)
    [IO.File]::WriteAllText($options.SelectionManifestPath, $raw, [Text.UTF8Encoding]::new($true))
    $options.ExpectedSelectionManifestSHA256 = (Get-FileHash -LiteralPath $options.SelectionManifestPath).Hash
    $manifestBefore = (Get-FileHash -LiteralPath $options.SelectionManifestPath).Hash
    Mock Compress-Archive { throw 'No archive permitted in Plan.' }
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options
    $r.Errors.Count | Should -Be 0
    $entry = $r.Sprint[0]
    @($entry.InheritedTracked).Count | Should -Be 1
    $entry.InheritedTracked[0] | Should -BeExactly '_generated/Sprint0015/old-evidence.md'
    @($entry.DefaultDataWitnesses).Count | Should -Be 1
    $entry.SelectionManifestBinding.Status | Should -Be 'BoundPlan'
    $entry.SelectionManifestBinding.ActualSHA256 | Should -Be $manifestBefore
    $entry.SelectionManifestBinding.SchemaValid | Should -BeTrue
    $entry.SelectionManifestBinding.RepositoryRootsAndHeadsBound | Should -BeTrue
    $entry.SelectionManifestBinding.SelectedDefaultBytesBound | Should -BeTrue
    $entry.SelectionManifestBinding.SelectedFileStreamsBound | Should -BeTrue
    $entry.SelectionManifestBinding.SelectedCandidateCount | Should -Be 1
    foreach ($flag in @('Approved','CustodyVerified','NamedStreamsVerified','ReadyForRemoval')) { $entry.SelectionManifestBinding.$flag | Should -BeFalse }
    $entry.CustodyVerified | Should -BeFalse
    $entry.ReadyForRemoval | Should -BeFalse
    $entry.NamedStreamsVerified | Should -BeFalse
    $entry.SelectionManifestBinding.Verification | Should -Match 'not independently verified'
    @($entry.PreservedFiles.Path) | Should -Contain '_generated/legacy-tracked.txt'
    (Get-FileHash -LiteralPath $options.SelectionManifestPath).Hash | Should -Be $manifestBefore
    Should -Invoke Compress-Archive -Times 0
  }


  It 'binds actual per-side named streams including empty and Unicode data without requiring cross-side ADS equality' {
    $relative = '_generated/Sprint0015/old-evidence.md'
    $streamName = [string][char]0x9644 + [char]0x6ce8
    foreach ($root in @($script:stable,$script:sprint)) {
      [IO.File]::WriteAllBytes((Join-Path $root $relative)+':empty',[byte[]]@())
      [IO.File]::WriteAllText((Join-Path $root $relative)+(':'+$streamName),$(if($root -ceq $script:stable){'stable metadata'}else{'sprint metadata'}))
    }
    $options = Save-TestSelectionManifest (Get-TestSelectionManifest @($relative,'_generated/legacy-tracked.txt'))
    $before = @(foreach($root in @($script:stable,$script:sprint)){
      $index = Invoke-TestGit $root rev-parse --path-format=absolute --git-path index
      [pscustomobject]@{Root=$root;Head=(Invoke-TestGit $root rev-parse HEAD);Index=$index;SHA256=(Get-FileHash -LiteralPath $index).Hash}
    })
    $script:fileSnapshotCalls = [Collections.Generic.List[object]]::new()
    Mock Get-GeneratedRemediationFileSnapshot {
      $actual = & $script:realFileSnapshot -RootPath $RootPath -RelativePath $RelativePath
      $script:fileSnapshotCalls.Add([pscustomobject]@{Root=$RootPath;RelativePath=$RelativePath;InventoryComplete=$actual.InventoryComplete})
      $actual
    }
    $r = Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options
    $script:fileSnapshotCalls.Count | Should -Be 4
    @($script:fileSnapshotCalls | Where-Object InventoryComplete).Count | Should -Be 0
    foreach($call in $script:fileSnapshotCalls){
      $call.Root | Should -BeIn @($script:stable,$script:sprint)
      $call.RelativePath | Should -BeIn @($relative,'_generated/legacy-tracked.txt')
    }
    $binding = $r.Sprint[0].SelectionManifestBinding
    $binding.SelectedCandidateCount | Should -Be 2
    $binding.SelectedFileStreamsBound | Should -BeTrue
    $row = $binding.Rows[0]
    $row.FileStreamsBound | Should -BeTrue
    $row.FileStreamEvidence.Count | Should -Be 2
    foreach($side in $row.FileStreamEvidence){
      $side.Bound | Should -BeTrue
      $side.ObservationsVerified | Should -Be 2
      $side.Binding.RelativePath | Should -BeExactly $relative
      ($side.ObservedStreams | Where-Object Name -CEQ empty).Bytes | Should -Be 0
      @($side.ObservedStreams).Count | Should -Be 3
    }
    ($row.FileStreamEvidence[0].ObservedStreams | Where-Object Name -CEQ $streamName).SHA256 |
      Should -Not -Be ($row.FileStreamEvidence[1].ObservedStreams | Where-Object Name -CEQ $streamName).SHA256
    foreach($side in $binding.Rows[1].FileStreamEvidence){
      $side.ObservedStreams.Count | Should -Be 1
      $side.ObservedStreams[0].Name | Should -BeExactly ':$DATA'
    }
    foreach($state in $before){
      (Invoke-TestGit $state.Root rev-parse HEAD) | Should -Be $state.Head
      (Get-FileHash -LiteralPath $state.Index).Hash | Should -Be $state.SHA256
    }
    foreach($flag in @('Approved','CustodyVerified','NamedStreamsVerified','ReadyForRemoval')) { $binding.$flag | Should -BeFalse }
    if($null -ne $script:backupReceiptSink){$script:backupReceiptSink.Add([pscustomobject]@{
      ActualFileStreamBinding=$binding;ActualSnapshotCalls=@($script:fileSnapshotCalls);SourceAndGitUnchanged=$true;ActualUnchangedFileSnapshotReader=$true
    })}
  }

  It 'preserves same-default files with wrong omitted extra or case-changed named streams and never backs them up' {
    $relative = '_generated/Sprint0015/old-evidence.md'
    $null = New-Item -ItemType Directory -Path $script:archive
    foreach($root in @($script:stable,$script:sprint)){
      [IO.File]::WriteAllText((Join-Path $root $relative)+':notes','actual metadata')
    }
    Mock New-GeneratedRemediationCustodyBundle { throw 'Mismatched file streams must not reach backup.' }
    foreach($variant in @('sourceHash','candidateLength','omitted','extra','case')){
      $manifest = Get-TestSelectionManifest
      switch($variant){
        sourceHash { $manifest.rows[0].source.streams[0].sha256 = 'B'*64 }
        candidateLength { $manifest.rows[0].candidate.streams[0].bytes++ }
        omitted { $manifest.rows[0].source.streams = @() }
        extra { $manifest.rows[0].candidate.streams += [ordered]@{name='missing';bytes=0;sha256='B'*64;archiveMember='streams/missing';restoreVerified=$true} }
        case { $manifest.rows[0].candidate.streams[0].name = 'NOTES' }
      }
      $options = Save-TestSelectionManifest $manifest
      $r = Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options -CreateBackup -ArchiveRoot $script:archive -Confirm:$false
      $row = $r.Sprint[0].SelectionManifestBinding.Rows[0]
      $row.DefaultBytesBound | Should -BeTrue -Because $variant
      $row.FileStreamsBound | Should -BeFalse -Because $variant
      $row.Action | Should -Be Preserve
      $row.Reason | Should -Match 'named.stream'
      $r.Sprint[0].SelectionManifestBinding.SelectedCandidateCount | Should -Be 0
      $r.Sprint[0].Backup.Status | Should -Be NoSelection
      @($r.Sprint[0].InheritedTracked).Count | Should -Be 0
    }
    Should -Invoke New-GeneratedRemediationCustodyBundle -Times 0
    @(Get-ChildItem -LiteralPath $script:archive -Force).Count | Should -Be 0
  }

  It 'preserves unavailable inconsistent substituted or changed-default snapshots' {
    $options = Save-TestSelectionManifest (Get-TestSelectionManifest)
    foreach($variant in @('unavailable','inconsistent','root','relative','path','default')){
      $script:snapshotVariant = $variant
      Mock Get-GeneratedRemediationFileSnapshot {
        $actual = & $script:realFileSnapshot -RootPath $RootPath -RelativePath $RelativePath
        switch($script:snapshotVariant){
          unavailable { $actual.Success=$false; $actual.Errors=@('fixture unavailable') }
          inconsistent { $actual.Consistent=$false }
          root { $actual.Binding.Root=$script:gitRoot }
          relative { $actual.Binding.RelativePath='_generated/other.txt' }
          path { $actual.Binding.Path=Join-Path $script:stable '_generated/other.txt' }
          default { $actual.Observations[0].Streams[0].SHA256='B'*64 }
        }
        $actual
      }
      $r = Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options
      $row=$r.Sprint[0].SelectionManifestBinding.Rows[0]
      $row.DefaultBytesBound | Should -BeTrue -Because $variant
      $row.FileStreamsBound | Should -BeFalse -Because $variant
      $row.Action | Should -Be Preserve
      $row.Reason | Should -Match 'snapshot|observed default'
      $r.Sprint[0].SelectionManifestBinding.SelectedCandidateCount | Should -Be 0
    }
  }

  It 'requires paired manifest inputs and one explicit SprintCarryover repository scope' {
    $options = Save-TestSelectionManifest (Get-TestSelectionManifest)
    { Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo -SelectionManifestPath $options.SelectionManifestPath } | Should -Throw '*must be paired*'
    { Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo -ExpectedSelectionManifestSHA256 $options.ExpectedSelectionManifestSHA256 } | Should -Throw '*must be paired*'
    { Invoke-GeneratedFolderRemediation -SprintNumber 0016 -GitRoot $script:gitRoot -RepositoryName Repo @options } | Should -Throw '*must be paired*'
    { Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo,Other @options } | Should -Throw '*must be paired*'
  }

  It 'keeps execution refusal ahead of manifest option validation and IO' {
    { Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo -Execute -SelectionManifestPath 'missing.json' } | Should -Throw '*Execution held*'
    { Invoke-GeneratedFolderRemediation -SprintNumber 0016 -GitRoot $script:gitRoot -RepositoryName Repo -PushRewrittenHistory -SelectionManifestPath 'missing.json' } | Should -Throw '*retired*'
  }

  It 'holds wrong raw hash or invalid snapshot with no fallback candidates' {
    $options = Save-TestSelectionManifest (Get-TestSelectionManifest)
    $options.ExpectedSelectionManifestSHA256 = '0' * 64
    $r = Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options
    $r.Sprint[0].Action | Should -Be 'Held'
    $r.Errors -join ';' | Should -Match 'Raw manifest SHA256 differs'
    @($r.Sprint[0].InheritedTracked).Count | Should -Be 0
    [IO.File]::WriteAllText($options.SelectionManifestPath, '{}')
    $options.ExpectedSelectionManifestSHA256 = (Get-FileHash -LiteralPath $options.SelectionManifestPath).Hash
    $r = Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options
    $r.Sprint[0].Action | Should -Be 'Held'
    $r.Errors -join ';' | Should -Match 'Invalid selection manifest'
    @($r.Sprint[0].DefaultDataWitnesses).Count | Should -Be 0
  }

  It 'holds mismatched repository common Git roots and stale Stable or Sprint HEADs' {
    foreach ($variant in @('identity','commonGitDir','stableRoot','sprintRoot','StableHead','SprintHead')) {
      $manifest = Get-TestSelectionManifest
      switch ($variant) {
        identity { $manifest.repository.identity = 'Other' }
        commonGitDir { $manifest.repository.commonGitDir = Join-Path $script:gitRoot 'other.git' }
        stableRoot { $manifest.repository.stableRoot = Join-Path $script:gitRoot 'Other'; $manifest.worktrees[0].root = $manifest.repository.stableRoot; $manifest.rows[0].source.root = $manifest.repository.stableRoot }
        sprintRoot { $manifest.repository.sprintRoot = Join-Path $script:gitRoot 'OtherSprint'; $manifest.worktrees[1].root = $manifest.repository.sprintRoot; $manifest.rows[0].candidate.root = $manifest.repository.sprintRoot }
        StableHead { $manifest.worktrees[0].head = '0' * 40 }
        SprintHead { $manifest.worktrees[1].head = '0' * 40 }
      }
      $options = Save-TestSelectionManifest $manifest
      $r = Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options
      $r.Sprint[0].Action | Should -Be 'Held' -Because $variant
      $r.Errors -join ';' | Should -Match 'binding differs'
      $r.Sprint[0].SelectionManifestBinding.SchemaValid | Should -BeTrue
      $r.Sprint[0].SelectionManifestBinding.RepositoryRootsAndHeadsBound | Should -BeFalse
      @($r.Sprint[0].InheritedTracked).Count | Should -Be 0
    }
  }

  It 'preserves schema-eligible rows whose supplied default bytes differ from the actual witness' {
    foreach ($field in @('sha256','bytes')) {
      $manifest = Get-TestSelectionManifest
      if ($field -eq 'sha256') { $manifest.rows[0].source.sha256 = 'B' * 64; $manifest.rows[0].candidate.sha256 = 'B' * 64 }
      else { $manifest.rows[0].source.bytes++; $manifest.rows[0].candidate.bytes++ }
      $options = Save-TestSelectionManifest $manifest
      $r = Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options
      $r.Sprint[0].SelectionManifestBinding.Status | Should -Be 'BoundPlan'
      $r.Sprint[0].SelectionManifestBinding.Rows[0].Action | Should -Be 'Preserve'
      $r.Sprint[0].SelectionManifestBinding.SelectedDefaultBytesBound | Should -BeFalse
      @($r.Sprint[0].InheritedTracked).Count | Should -Be 0
      @($r.Sprint[0].DefaultDataWitnesses).Count | Should -Be 0
    }
  }

  It 'keeps current future staged and unstaged paths protected despite matching supplied default records' {
    foreach ($root in @($script:stable,$script:sprint)) {
      New-TestFile $root '_generated/legacy-tracked.txt' 'modified default'
      New-TestFile $root '_generated/Sprint0016/current.md' 'current'
      New-TestFile $root '_generated/Sprint0017/future.md' 'future'
      New-TestFile $root '_generated/Sprint0015/staged.txt' 'staged'
    }
    Invoke-TestGit $script:sprint add -f _generated/Sprint0015/staged.txt | Out-Null
    $manifest = Get-TestSelectionManifest @('_generated/Sprint0015/old-evidence.md','_generated/legacy-tracked.txt','_generated/Sprint0016/current.md','_generated/Sprint0017/future.md','_generated/Sprint0015/staged.txt')
    $options = Save-TestSelectionManifest $manifest
    Mock Get-GeneratedRemediationFileSnapshot {
      if($RelativePath -cne '_generated/Sprint0015/old-evidence.md'){throw 'Protected or WIP row acquired.'}
      & $script:realFileSnapshot -RootPath $RootPath -RelativePath $RelativePath
    }
    $r = Invoke-GeneratedFolderRemediation -SprintNumber 0016 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options
    @($r.Sprint[0].InheritedTracked).Count | Should -Be 1
    $r.Sprint[0].InheritedTracked[0] | Should -Be '_generated/Sprint0015/old-evidence.md'
    @($r.Sprint[0].SelectionManifestBinding.Rows | Where-Object Action -EQ Preserve).Count | Should -Be 4
    @($r.Sprint[0].SkippedModified) | Should -Contain '_generated/legacy-tracked.txt'
    @($r.Sprint[0].SkippedModified) | Should -Contain '_generated/Sprint0015/staged.txt'
    Should -Invoke Get-GeneratedRemediationFileSnapshot -Times 2 -Exactly -ParameterFilter { $RelativePath -ceq '_generated/Sprint0015/old-evidence.md' }
  }

  It 'holds manifest Plan when the explicit current sprint worktree is absent' {
    $options = Save-TestSelectionManifest (Get-TestSelectionManifest)
    $r = Invoke-GeneratedFolderRemediation -SprintNumber 0017 -Scope SprintCarryover -GitRoot $script:gitRoot -RepositoryName Repo @options
    $r.Sprint[0].Action | Should -Be 'Held'
    $r.Sprint[0].SelectionManifestBinding.Status | Should -Be 'Held'
  }

  It 'plans without changing anything by default' {
    Mock Get-GeneratedRemediationFileSnapshot { throw 'Unmanifested Plan must not acquire file streams.' }
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName 'Repo'

    $r.Mode | Should -Be 'Plan'
    $r.Stable[0].UntrackedFiles | Should -Be 1
    $r.Stable[0].CurrentSprintProtected | Should -Be 1
    @($r.Stable[0].TrackedDeferred).Count | Should -Be 2
    @($r.Sprint[0].InheritedTracked).Count | Should -Be 2
    @($r.Sprint[0].PriorSprintNamedUntracked).Count | Should -Be 0
    @($r.Sprint[0].PreservedFiles).Count | Should -Be 2
    $r.History[0].HistoryPathCount | Should -Be 2
    $r.History[0].Action | Should -Be 'Planned'
    Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
    Test-Path (Join-Path $script:sprint '_generated/sprint-end-0007/stale.log') | Should -BeTrue
    Should -Invoke Get-GeneratedRemediationFileSnapshot -Times 0
  }

  It 'refuses all worktree execution preserving default and named data directories index and HEAD' {
    $payloads=@()
    $nodes=@()
    foreach($root in @($script:stable,$script:sprint)){
      $generated=Join-Path $root '_generated'
      $directory=Join-Path $generated 'ads-only'
      $null=New-Item -ItemType Directory -Path $directory
      $file=Join-Path $generated 'legacy-tracked.txt'
      [IO.File]::WriteAllText($file+':notes','named sentinel')
      [IO.File]::WriteAllText($generated+':root-note','root sentinel')
      [IO.File]::WriteAllBytes($directory+':empty',[byte[]]@())
      [IO.File]::WriteAllBytes($directory+':'+[char]0x9644,[byte[]]@(0,9,255))
      $payloads+=@($file,($file+':notes'),($generated+':root-note'),($directory+':empty'),($directory+':'+[char]0x9644))
      $nodes+=@($generated,$directory)
    }
    $before=@(foreach($path in $payloads){[pscustomobject]@{Path=$path;Hash=(Get-FileHash -LiteralPath $path).Hash}})
    $streamSets=@(foreach($path in $nodes){[pscustomobject]@{Path=$path;Streams=@(Get-Item -LiteralPath $path -Stream '*'|Select-Object Stream,Length)}})
    $gitState=@(foreach($root in @($script:stable,$script:sprint)){
      $index=(& $script:realGitCommand -C $root rev-parse --path-format=absolute --git-path index)
      [pscustomobject]@{Root=$root;Index=$index;IndexHash=(Get-FileHash -LiteralPath $index).Hash;Head=(& $script:realGitCommand -C $root rev-parse HEAD)}
    })
    $output=Join-Path $script:gitRoot 'evidence/report.json'
    Mock git { throw 'No Git call permitted during refusal' }
    Mock Get-Command { throw 'No helper lookup permitted' }
    Mock New-Item { throw 'No output permitted' }
    Mock Compress-Archive { throw 'No archive permitted' }
    foreach($options in @(
      @{Scope=@('StableWorktree')},@{Scope=@('SprintCarryover')},
      @{Scope=@('StableWorktree','SprintCarryover')},
      @{Scope=@('StableWorktree','SprintCarryover');WhatIf=$true}
    )){
      { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Execute -ArchiveRoot $script:archive -EvidencePath $output -Confirm:$false @options } | Should -Throw '*Execution held*complete approved*root/directory*'
    }
    Should -Invoke git -Times 0
    Should -Invoke Get-Command -Times 0
    Should -Invoke New-Item -Times 0
    Should -Invoke Compress-Archive -Times 0
    foreach($row in $before){(Get-FileHash -LiteralPath $row.Path).Hash | Should -Be $row.Hash}
    foreach($row in $streamSets){
      Test-Path -LiteralPath $row.Path -PathType Container | Should -BeTrue
      $after=@(Get-Item -LiteralPath $row.Path -Stream '*'|Select-Object Stream,Length)
      ($after|ConvertTo-Json -Compress) | Should -Be ($row.Streams|ConvertTo-Json -Compress)
    }
    foreach($row in $gitState){
      (Get-FileHash -LiteralPath $row.Index).Hash | Should -Be $row.IndexHash
      (& $script:realGitCommand -C $row.Root rev-parse HEAD) | Should -Be $row.Head
    }
    Test-Path -LiteralPath $script:archive | Should -BeFalse
    Test-Path -LiteralPath $output | Should -BeFalse
  }

  It 'protects every nested current or future sprint match in planning across all three selectors and refuses execution' {
    $protectedSegments = @(
      'Sprint0015/Sprint0016',
      'Sprint0015/Sprint0017',
      'Sprint0016/Sprint0015',
      'Sprint0015-and-Sprint0016',
      'Sprint0015-and-Sprint0017',
      'sPrInT_0015/SpRiNt-EnD-0016',
      'SprintEnd0015/Sprint-0016',
      'Sprint_0017-and-Sprint0015'
    )
    $protectedStable = @()
    $protectedSprint = @()
    foreach ($segment in $protectedSegments) {
      $stableOnly = "_generated/$segment/stable-only.bin"
      $inherited = "_generated/$segment/inherited.bin"
      $untracked = "_generated/$segment/untracked.bin"
      New-TestFile $script:stable $stableOnly "stable:$segment"
      New-TestFile $script:stable $inherited "inherited:$segment"
      Invoke-TestGit $script:stable add -f -- $inherited | Out-Null
      New-TestFile $script:sprint $inherited "inherited:$segment"
      Invoke-TestGit $script:sprint add -f -- $inherited | Out-Null
      New-TestFile $script:sprint $untracked "untracked:$segment"
      $protectedStable += $stableOnly
      $protectedSprint += $inherited, $untracked
    }
    $oldTracked = '_generated/Sprint0014/Sprint0015/old-tracked.bin'
    $oldUntracked = '_generated/Sprint0014/Sprint0015/old-untracked.bin'
    $noSprint = '_generated/SprintABCD/no-number.bin'
    foreach ($root in @($script:stable, $script:sprint)) {
      New-TestFile $root $oldTracked 'old tracked'
      Invoke-TestGit $root add -f -- $oldTracked | Out-Null
      New-TestFile $root $oldUntracked 'old untracked'
      New-TestFile $root $noSprint 'no sprint number'
      Invoke-TestGit $root commit -q -m 'nested protection fixtures' | Out-Null
    }
    $before = @{}
    foreach ($rel in $protectedStable) {
      $path = Join-Path $script:stable $rel
      $before[$path] = (Get-FileHash -LiteralPath $path).Hash
    }
    foreach ($rel in $protectedSprint) {
      $path = Join-Path $script:sprint $rel
      $before[$path] = (Get-FileHash -LiteralPath $path).Hash
    }

    $plan = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree, SprintCarryover
    $plan.Errors | Should -BeNullOrEmpty
    $plan.Mode | Should -Be Plan
    $plan.Stable[0].CurrentSprintProtected | Should -Be (1 + $protectedSegments.Count)
    foreach ($rel in $protectedSprint) {
      $plan.Sprint[0].InheritedTracked | Should -Not -Contain $rel
      $plan.Sprint[0].PriorSprintNamedTracked | Should -Not -Contain $rel
      $plan.Sprint[0].PriorSprintNamedUntracked | Should -Not -Contain $rel
    }
    $plan.Sprint[0].InheritedTracked | Should -Contain $oldTracked
    $plan.Sprint[0].PriorSprintNamedUntracked | Should -Contain $oldUntracked
    $plan.Sprint[0].PriorSprintNamedUntracked | Should -Not -Contain $noSprint
    foreach ($path in $before.Keys) { (Get-FileHash -LiteralPath $path).Hash | Should -Be $before[$path] }

    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree,SprintCarryover -Execute -ArchiveRoot $script:archive -Confirm:$false } | Should -Throw '*Execution held*'
    foreach ($path in $before.Keys) { (Get-FileHash -LiteralPath $path).Hash | Should -Be $before[$path] }
    Test-Path -LiteralPath (Join-Path $script:stable $oldUntracked) | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $script:sprint $oldUntracked) | Should -BeTrue
  }

  It 'skips inherited files that have uncommitted modifications' {
    Set-Content -LiteralPath (Join-Path $script:sprint '_generated/legacy-tracked.txt') -Value 'edited'
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName 'Repo' `
      -Scope SprintCarryover -ArchiveRoot $script:archive -Confirm:$false

    $r.Sprint[0].SkippedModified | Should -Contain '_generated/legacy-tracked.txt'
    Test-Path (Join-Path $script:sprint '_generated/legacy-tracked.txt') | Should -BeTrue
  }

  It 'plans only actual same-path equal candidates and preserves different or missing partners' {
    $equal = '_generated/Sprint0015/equal.bin'
    $empty = '_generated/Sprint0015/empty.bin'
    $different = '_generated/Sprint0015/different.bin'
    $missing = '_generated/Sprint0015/missing.bin'
    foreach ($root in @($script:stable, $script:sprint)) {
      New-TestFile $root $equal 'same bytes'
      New-TestFile $root $empty ''
      [IO.File]::WriteAllBytes((Join-Path $root $empty), [byte[]]@())
      New-TestFile $root $different 'AAAA'
    }
    New-TestFile $script:sprint $different 'BBBB'
    New-TestFile $script:sprint $missing 'same bytes'
    New-TestFile $script:stable '_generated/Sprint0015/other-name.bin' 'same bytes'
    New-TestFile $script:sprint '_generated/legacy-tracked.txt' 'different committed bytes'
    Invoke-TestGit $script:sprint add -f -- _generated/legacy-tracked.txt | Out-Null
    Invoke-TestGit $script:sprint commit -q -m 'different tracked content' | Out-Null
    $beforeDifferent = (Get-FileHash -LiteralPath (Join-Path $script:sprint $different)).Hash

    $plan = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover
    $plan.Errors | Should -BeNullOrEmpty
    $plan.Sprint[0].PriorSprintNamedUntracked | Should -Contain $equal
    $plan.Sprint[0].PriorSprintNamedUntracked | Should -Contain $empty
    $plan.Sprint[0].PriorSprintNamedUntracked | Should -Not -Contain $different
    $plan.Sprint[0].PriorSprintNamedUntracked | Should -Not -Contain $missing
    ($plan.Sprint[0].PreservedFiles | Where-Object Path -EQ $different).Status | Should -Be Different
    ($plan.Sprint[0].PreservedFiles | Where-Object Path -EQ $missing).Status | Should -Be Hold
    $plan.Sprint[0].InheritedTracked | Should -Not -Contain '_generated/legacy-tracked.txt'

    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -Execute -ArchiveRoot $script:archive -Confirm:$false } | Should -Throw '*Execution held*'
    foreach($rel in @($equal,$empty,$different,$missing)){Test-Path -LiteralPath (Join-Path $script:sprint $rel) | Should -BeTrue}
    (Get-FileHash -LiteralPath (Join-Path $script:sprint $different)).Hash | Should -Be $beforeDifferent
    $plan.Sprint[0].ReadyForRemoval | Should -BeFalse
    $plan.Sprint[0].NamedStreamsVerified | Should -BeFalse
    $plan.Sprint[0].CustodyVerified | Should -BeFalse
  }

  It 'plans combined scopes without removing either equal partner' {
    $rel='_generated/Sprint0015/combined.bin'
    foreach($root in @($script:stable,$script:sprint)){New-TestFile $root $rel 'equal baseline'}
    $r=Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree,SprintCarryover
    $r.Errors | Should -BeNullOrEmpty
    $r.Sprint[0].PriorSprintNamedUntracked | Should -Contain $rel
    Test-Path -LiteralPath (Join-Path $script:stable $rel) | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $script:sprint $rel) | Should -BeTrue
  }

  It 'preserves staged changes before asking the byte comparator' {
    New-TestFile $script:sprint '_generated/legacy-tracked.txt' 'staged WIP'
    Invoke-TestGit $script:sprint add -f -- _generated/legacy-tracked.txt | Out-Null
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -ArchiveRoot $script:archive -Confirm:$false
    $r.Sprint[0].SkippedModified | Should -Contain '_generated/legacy-tracked.txt'
    (Get-Content -LiteralPath (Join-Path $script:sprint '_generated/legacy-tracked.txt') -Raw).Trim() | Should -Be 'staged WIP'
    ($r.Sprint[0].DefaultDataWitnesses.Binding.RelativePath) | Should -Not -Contain '_generated/legacy-tracked.txt'
  }

  It 'holds carryover when stable branch identity differs' {
    Invoke-TestGit $script:stable checkout -q -b other | Out-Null
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -ArchiveRoot $script:archive -Confirm:$false
    $r.Sprint[0].Action | Should -Be Held
    $r.Errors -join ' ' | Should -Match 'Stable branch binding'
    $r.Sprint[0].GitRemoved | Should -Be 0
  }

  It 'holds an unrelated repository with a matching sprint directory name' {
    $unrelated = Join-Path $script:gitRoot 'Repo-wt-9-Sprint-0016-work-items'
    $null = New-Item -ItemType Directory -Path $unrelated
    Invoke-TestGit $unrelated init -q -b main | Out-Null
    New-TestFile $unrelated 'seed.txt'
    Invoke-TestGit $unrelated add seed.txt | Out-Null
    Invoke-TestGit $unrelated commit -q -m 'unrelated' | Out-Null
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover
    ($r.Sprint | Where-Object Path -EQ $unrelated).Action | Should -Be Held
    $r.Errors -join ' ' | Should -Match 'common repository binding'
  }

  It 'does not turn a failed common-repository query into an empty successful plan' {
    Mock git {
      if ($args -contains '--git-common-dir') { $global:LASTEXITCODE = 128; return 'identity query failed' }
      & $script:realGitCommand @args
    }
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -ArchiveRoot $script:archive -Confirm:$false
    $r.Sprint[0].Action | Should -Be Held
    $r.Errors -join ' ' | Should -Match 'Git inventory failed'
    $r.Sprint[0].Archive | Should -BeNullOrEmpty
    Test-Path -LiteralPath (Join-Path $script:sprint '_generated/legacy-tracked.txt') | Should -BeTrue
  }

  It 'refuses before legacy archive hooks can change source bytes or the index' {
    Mock Compress-Archive { throw 'Archive hook must not run' }
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -Execute -ArchiveRoot $script:archive -Confirm:$false } | Should -Throw '*Execution held*'
    Should -Invoke Compress-Archive -Times 0
    Test-Path -LiteralPath $script:archive | Should -BeFalse
    @(Invoke-TestGit $script:sprint diff --cached --name-only).Count | Should -Be 0
  }





  It 'loads the private helper from source when it is not already available' {
    Remove-Item Function:\Get-GeneratedRemediationByteComparison -ErrorAction Stop
    try {
      $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover
      $r.Errors | Should -BeNullOrEmpty
      $r.Sprint[0].InheritedTracked | Should -Contain '_generated/legacy-tracked.txt'
    } finally { . "$PSScriptRoot\..\..\private\Get-GeneratedRemediationByteComparison.ps1" }
  }

  It 'refuses missing custody before requiring an archive destination' {
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree -Execute -Confirm:$false } | Should -Throw '*Execution held*complete approved*'
  }

  It 'rejects unsupported options before Git autoload output or source and index mutation' {
    $sourcePath=Join-Path $script:sprint '_generated/legacy-tracked.txt'
    $sourceHash=(Get-FileHash -LiteralPath $sourcePath).Hash
    $indexPath=(& $script:realGitCommand -C $script:sprint rev-parse --path-format=absolute --git-path index)
    $indexHash=(Get-FileHash -LiteralPath $indexPath).Hash
    $history=Join-Path $script:gitRoot 'history'
    $evidence=Join-Path $script:gitRoot 'output/report.json'
    Mock git { throw 'Unexpected Git call' }
    Mock Get-Command { throw 'Unexpected helper lookup' }
    Mock Import-Module { throw 'Unexpected helper loading' }
    Mock New-Item { throw 'Unexpected output creation' }
    $cases=@(
      @{Execute=$true;NoArchive=$true;Scope=@('StableWorktree')},
      @{Execute=$true;NoArchive=$true;Scope=@('SprintCarryover')},
      @{Execute=$true;NoArchive=$true;Scope=@('StableWorktree','SprintCarryover');WhatIf=$true},
      @{Execute=$true;Scope=@('StableHistory')},
      @{Execute=$true;Scope=@('StableWorktree','StableHistory')},
      @{Execute=$true},
      @{PushRewrittenHistory=$true;Scope=@('StableHistory')},
      @{Execute=$true;PushRewrittenHistory=$true;Scope=@('SprintCarryover')}
    )
    foreach($options in $cases){
      { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -ArchiveRoot $script:archive -HistoryWorkRoot $history -EvidencePath $evidence -Confirm:$false @options } | Should -Throw
    }
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -Execute -NoArchive -Confirm:$false } | Should -Throw '*NoArchive*unsupported*'
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableHistory -Execute -Confirm:$false } | Should -Throw '*StableHistory execution is retired*'
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -PushRewrittenHistory } | Should -Throw '*PushRewrittenHistory is retired*'
    Should -Invoke git -Times 0
    Should -Invoke Get-Command -Times 0
    Should -Invoke Import-Module -Times 0
    Should -Invoke New-Item -Times 0
    foreach($path in @($script:archive,$history,$evidence)){Test-Path -LiteralPath $path | Should -BeFalse}
    (Get-FileHash -LiteralPath $sourcePath).Hash | Should -Be $sourceHash
    (Get-FileHash -LiteralPath $indexPath).Hash | Should -Be $indexHash
  }

  It 'does not accept an archive-looking destination as complete custody proof' {
    $destination=Join-Path $script:stable '_generated/arch'
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree -Execute -ArchiveRoot $destination -Confirm:$false } | Should -Throw '*Execution held*'
    Test-Path -LiteralPath $destination | Should -BeFalse
  }

  It 'keeps history and NoArchive planning read-only with legacy parameters' {
    $history=Join-Path $script:gitRoot 'unused-history'
    $r=Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableHistory -NoArchive -HistoryWorkRoot $history
    $r.Mode | Should -Be Plan
    $r.History[0].Action | Should -Be Planned
    $r.History[0].HistoryPathCount | Should -Be 2
    $r.History[0].BareClone | Should -BeNullOrEmpty
    $r.History[0].RefsRewritten | Should -BeNullOrEmpty
    $r.History[0].Pushed | Should -BeFalse
    Test-Path -LiteralPath $history | Should -BeFalse
    Test-Path -LiteralPath $script:archive | Should -BeFalse
    $worktreePlan=Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree,SprintCarryover -NoArchive
    $worktreePlan.Mode | Should -Be Plan
    $worktreePlan.Errors | Should -BeNullOrEmpty
    Test-Path -LiteralPath (Join-Path $script:sprint '_generated/legacy-tracked.txt') | Should -BeTrue
  }

  It 'skips the stable scope when the stable worktree is not on the stable branch' {
    Invoke-TestGit $script:stable checkout -q -b other | Out-Null
    $r = Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName 'Repo' `
      -Scope StableWorktree -ArchiveRoot $script:archive -Confirm:$false
    $r.Stable[0].Action | Should -BeLike 'Skipped*'
    Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
  }

  It 'refuses execution even when the supplied archive destination is a file' {
    New-TestFile $script:gitRoot 'blocked-archive' 'sentinel'
    $path=Join-Path $script:gitRoot 'blocked-archive'
    $before=(Get-FileHash -LiteralPath $path).Hash
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree -Execute -ArchiveRoot $path -Confirm:$false } | Should -Throw '*Execution held*'
    (Get-FileHash -LiteralPath $path).Hash | Should -Be $before
  }

  It 'exposes no caller-supplied approval or receipt bypass' {
    foreach($forged in @(@{Approved=$true},@{CustodyVerified=$true},@{CustodyReceipt=[pscustomobject]@{Status='Verified'}})){
      { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope SprintCarryover -Execute -ArchiveRoot $script:archive @forged } | Should -Throw '*parameter*'
    }
    Test-Path -LiteralPath $script:archive | Should -BeFalse
  }

  It 'refuses before attempting a selected payload that would be unavailable' {
    Mock Get-Item { throw 'Unavailable selected payload' } -ParameterFilter { $LiteralPath -like '*backup.json' }
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree -Execute -ArchiveRoot $script:archive -Confirm:$false } | Should -Throw '*Execution held*'
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $LiteralPath -like '*backup.json' }
    Test-Path -LiteralPath (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
  }

  It 'aborts on native Git inventory failure without deleting untracked files' {
    Mock git { $global:LASTEXITCODE = 128; 'fatal: inventory unavailable' }
    { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo `
        -Scope StableWorktree -ArchiveRoot $script:archive -Confirm:$false } | Should -Throw '*Git inventory failed*'
    Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
  }

  It 'rejects a junction before following it or deleting any original' {
    New-TestFile $script:gitRoot 'outside/keep.txt'
    $junction = Join-Path $script:stable '_generated/external'
    New-Item -ItemType Junction -Path $junction -Target (Join-Path $script:gitRoot 'outside') -ErrorAction Stop | Out-Null
    try {
      { Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo `
          -Scope StableWorktree -ArchiveRoot $script:archive -Confirm:$false } | Should -Throw '*Reparse point*'
      Test-Path (Join-Path $script:gitRoot 'outside/keep.txt') | Should -BeTrue
      Test-Path (Join-Path $script:stable '_generated/AIAdapterBackups/backup.json') | Should -BeTrue
    } finally { Remove-Item -LiteralPath $junction -Force }
  }

  It 'includes hidden files in repeated read-only planning without creating archives' {
    New-TestFile $script:stable '_generated/hidden.bin' 'hidden bytes'
    $hidden=Join-Path $script:stable '_generated/hidden.bin'
    (Get-Item -LiteralPath $hidden).Attributes=[IO.FileAttributes]::Hidden
    $before=(Get-FileHash -LiteralPath $hidden).Hash
    foreach($pass in 1..2){
      $r=Invoke-GeneratedFolderRemediation -SprintNumber '0016' -GitRoot $script:gitRoot -RepositoryName Repo -Scope StableWorktree
      $r.Mode | Should -Be Plan
      $r.Stable[0].UntrackedFiles | Should -Be 2
      $r.Stable[0].CurrentSprintProtected | Should -Be 1
      @($r.Stable[0].TrackedDeferred).Count | Should -Be 2
      (Get-FileHash -LiteralPath $hidden).Hash | Should -Be $before
    }
    Test-Path -LiteralPath $script:archive | Should -BeFalse
  }
}

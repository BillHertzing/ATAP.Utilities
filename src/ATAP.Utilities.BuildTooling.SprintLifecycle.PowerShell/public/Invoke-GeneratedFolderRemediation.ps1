function Invoke-GeneratedFolderRemediation {
  <#
  .SYNOPSIS
    Plans and, on request, removes `_generated/` content that leaked past a
    sprint boundary: stable worktree folders, prior-sprint carryover in the
    current sprint worktrees, and `_generated/` paths in stable-branch history.

  .DESCRIPTION
    These are legacy partial remediation modes, not the complete expanded
    Task 16.84 solution. They do not implement same-path/identical-byte duplicate
    selection, complete stable-tree removal, or coordinated stable/sprint history
    migration. Execution requires a separately reviewed plan and authorization.

    Rule R-38 says sprint `_generated/` folders are deleted at sprint end. In
    practice, files reach the stable worktrees anyway (see SC-0470): sprint-close
    commits force-add ignored `_generated/` files, and SprintEnd/AIAdapter steps
    write backups straight into the stable worktrees. This cmdlet remediates
    three scopes:

    StableWorktree
      For each stable worktree (`<GitRoot>\<RepositoryName>` on -StableBranch),
      deletes every untracked or ignored file under `_generated/`. Tracked
      files are NOT deleted here, nor is any path whose sprint segment is
      -SprintNumber or later (CurrentSprintProtected), because removing them would mean a commit to
      the stable branch. They are reported as TrackedDeferred and leave the
      stable branch when the sprint branch, which removes them in the
      SprintCarryover scope, merges at sprint end.

    SprintCarryover
      For each current sprint worktree
      (`<GitRoot>\<RepositoryName>-wt-*-Sprint-<SprintNumber>-work-items`),
      removes `_generated/` files that came from an earlier sprint:
        - InheritedTracked: files tracked on the sprint branch whose path also
          exists in the -StableBranch tree. They are removed with `git rm` and
          staged, never committed.
        - PriorSprintNamed: tracked-or-untracked files whose path has a sprint
          segment (Sprint0015, SprintEnd0013, sprint-end-0007, ...) numbered
          below -SprintNumber.
      Files with uncommitted modifications are skipped and reported.

    StableHistory
      Reports every `_generated/` path and commit reachable from -StableBranch.
      With -Execute and -HistoryWorkRoot, the cmdlet makes a fresh bare clone
      of origin and rewrites every branch and tag with
      `git filter-repo --invert-paths --path _generated/`, then verifies that
      no `_generated/` path remains. With -PushRewrittenHistory as well, it
      force-pushes each rewritten branch and tag with a per-ref lease on the
      pre-rewrite SHA. The push is refused while any other worktree of that
      repository exists (sprint worktrees under -GitRoot and any registered
      build/release worktree elsewhere), because they still carry the old history
      and would re-introduce it on merge. After a push, every clone and
      worktree has to be re-synchronized; GitHub keeps old commits reachable
      through pull-request refs until GitHub support runs a GC.

    Without -Execute the cmdlet only plans. With -Execute, each destructive
    action also goes through ShouldProcess (ConfirmImpact High). Before
    StableWorktree deletion requires a ZIP under -ArchiveRoot, verified by exact
    entry paths and SHA-256 readback before removal. It rejects -NoArchive when
    deletion is attempted. The legacy SprintCarryover mode can bypass its archive
    with -NoArchive and does not provide the stable mode's archive verification.
    Archive destination junction/resolved-containment checks and concurrent-writer
    races are unresolved; these partial safeguards do not establish execution readiness.

  .PARAMETER SprintNumber
    Current four-digit sprint number, for example '0016'.
  .PARAMETER Scope
    Scopes to process. Defaults to all three.
  .PARAMETER GitRoot
    Folder that holds the stable worktrees and sprint worktrees.
  .PARAMETER RepositoryName
    Stable worktree folder names under -GitRoot.
  .PARAMETER StableBranch
    Stable branch name. Defaults to main.
  .PARAMETER Execute
    Performs the removals. Without it, the cmdlet only produces the plan.
  .PARAMETER ArchiveRoot
    Folder receiving ZIP archives. StableWorktree deletion always requires a
    verified archive. SprintCarryover requires this folder unless -NoArchive is
    passed. It must be outside affected `_generated` trees. The current lexical
    guard does not prove resolved destination containment through junctions.
  .PARAMETER NoArchive
    Bypasses archiving only in the legacy SprintCarryover mode. StableWorktree
    reports a failed deletion attempt and retains originals when this switch is
    used; skipped worktrees and worktrees with no deletion candidates are unchanged.
  .PARAMETER HistoryWorkRoot
    Empty-or-new folder for the bare clones that StableHistory rewrites.
    Required with -Execute for StableHistory.
  .PARAMETER PushRewrittenHistory
    Force-pushes the rewritten history. Requires -Execute and -HistoryWorkRoot.
  .PARAMETER EvidencePath
    Optional JSON file path for the full report (SC-0033: place it under a
    `_generated/` folder of the current sprint).
  .OUTPUTS
    [PSCustomObject] report with Stable, Sprint, History, Errors and Mode.
  .EXAMPLE
    Invoke-GeneratedFolderRemediation -SprintNumber '0016' -EvidencePath $plan
    # Legacy partial-mode inventory only; not the expanded Task 16.84 plan.
  .EXAMPLE
    Invoke-GeneratedFolderRemediation -SprintNumber '0016' -Scope StableWorktree, SprintCarryover `
      -Execute -ArchiveRoot 'D:\Temp\GeneratedArchive'
    # Legacy partial-mode syntax only; not an approved Task 16.84 execution runbook.
  .EXAMPLE
    Invoke-GeneratedFolderRemediation -SprintNumber '0017' -Scope StableHistory -Execute `
      -HistoryWorkRoot 'D:\Temp\GeneratedHistory' -PushRewrittenHistory
    # Legacy partial-mode syntax only; not a coordinated history migration runbook.
  .NOTES
    Sprint 0016 unplanned remediation task. Durable SprintEnd fix: SC-0470.
    AI assisted using Powershell.instructions.md as guidelines.
  .LINK
    Clear-SprintGeneratedArtifacts
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{4}$')]
    [string]$SprintNumber,

    [Parameter()]
    [ValidateSet('StableWorktree', 'SprintCarryover', 'StableHistory')]
    [string[]]$Scope = @('StableWorktree', 'SprintCarryover', 'StableHistory'),

    [Parameter()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$GitRoot = 'C:\Dropbox\whertzing\GitHub',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$RepositoryName = @('_Planning', 'Ace', 'ATAP.Utilities', 'SharedVSCode', 'ATAP.IAC'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$StableBranch = 'main',

    [Parameter()]
    [switch]$Execute,

    [Parameter()]
    [string]$ArchiveRoot,

    [Parameter()]
    [switch]$NoArchive,

    [Parameter()]
    [string]$HistoryWorkRoot,

    [Parameter()]
    [switch]$PushRewrittenHistory,

    [Parameter()]
    [string]$EvidencePath
  )

  begin {
    $fn = 'Invoke-GeneratedFolderRemediation'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    $currentSprint = [int]$SprintNumber
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $errors = [System.Collections.Generic.List[string]]::new()

    # Runs git and separates stdout lines from stderr text.
    $invokeGit = {
      param([string[]]$ArgumentList)
      $raw = & git -c core.quotepath=off @ArgumentList 2>&1
      $code = $LASTEXITCODE
      [PSCustomObject]@{
        ExitCode = $code
        Output   = @($raw | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ })
        Error    = (@($raw | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { $_.ToString() }) -join "`n")
      }
    }

    # Failed stable inventory must never be interpreted as an empty one.
    $checkedGit = {
      param([string[]]$ArgumentList)
      $result = & $invokeGit $ArgumentList
      if ($result.ExitCode -ne 0) { throw "Git inventory failed: $($result.Error)" }
      $result
    }

    # Reject redirecting links in every ancestor. Dropbox cloud placeholders may
    # carry ReparsePoint without a link target; their bytes must still hash fully.
    $safeStablePath = {
      param([string]$Root, [string]$RelativePath)
      $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
      $generatedFull = Join-Path $rootFull '_generated'
      $full = [IO.Path]::GetFullPath((Join-Path $rootFull $RelativePath))
      if ($full -ne $generatedFull -and -not $full.StartsWith($generatedFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes _generated: $RelativePath"
      }
      $cursor = $full
      while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $null -ne $item.ResolveLinkTarget($false)) {
          throw "Reparse point redirects the path: $cursor"
        }
        $cursor = Split-Path -Parent $cursor
      }
      $full
    }

    # Walk explicitly to reject junctions before any recursive enumeration.
    $stableDiskFiles = {
      param([string]$Root)
      $generated = Join-Path $Root '_generated'
      if (-not (Test-Path -LiteralPath $generated)) { return }
      $null = & $safeStablePath $Root '_generated'
      $pending = [Collections.Generic.Stack[string]]::new()
      $pending.Push($generated)
      $prefix = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
      while ($pending.Count) {
        foreach ($item in Get-ChildItem -LiteralPath $pending.Pop() -Force -ErrorAction Stop) {
          if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $null -ne $item.ResolveLinkTarget($false)) {
            throw "Reparse point redirects the path: $($item.FullName)"
          }
          if ($item.PSIsContainer) { $pending.Push($item.FullName) }
          else { $item.FullName.Substring($prefix.Length).Replace('\', '/') }
        }
      }
    }

    # Stable-only ZIP readback proves the exact path set and hashes before deletion.
    $archiveStableFiles = {
      param([string]$Root, [string[]]$RelativePaths, [string]$Name)
      if ($NoArchive) { throw 'StableWorktree cleanup requires a verified archive; -NoArchive is not allowed.' }
      [void](New-Item -ItemType Directory -Path $ArchiveRoot -Force -ErrorAction Stop)
      $zip = Join-Path $ArchiveRoot "$Name-$stamp-$([guid]::NewGuid().ToString('N')).zip"
      $hashes = @{}
      $writer = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
      try {
        foreach ($rel in $RelativePaths) {
          $source = & $safeStablePath $Root $rel
          $hashes[$rel] = (Get-FileHash -LiteralPath $source -Algorithm SHA256 -ErrorAction Stop).Hash
          $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($writer, $source, $rel)
        }
      } finally { $writer.Dispose() }
      $reader = [IO.Compression.ZipFile]::OpenRead($zip)
      try {
        if ($reader.Entries.Count -ne $RelativePaths.Count) { throw 'Archive entry count mismatch.' }
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($entry in $reader.Entries) {
          if (-not $hashes.ContainsKey($entry.FullName) -or -not $seen.Add($entry.FullName)) { throw 'Archive path set mismatch.' }
          $stream = $entry.Open()
          $sha = [Security.Cryptography.SHA256]::Create()
          try { $hash = [Convert]::ToHexString($sha.ComputeHash($stream)) }
          finally { $sha.Dispose(); $stream.Dispose() }
          if ($hash -ne $hashes[$entry.FullName]) { throw "Archive hash mismatch: $($entry.FullName)" }
        }
      } finally { $reader.Dispose() }
      foreach ($rel in $RelativePaths) {
        $source = & $safeStablePath $Root $rel
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256 -ErrorAction Stop).Hash -ne $hashes[$rel]) {
          throw "Source changed during archive: $rel"
        }
      }
      [PSCustomObject]@{ Path = $zip; Hashes = $hashes }
    }

    # Builds a case-insensitive path set; tolerates $null (empty script-block output unrolls to $null).
    $newSet = {
      param($Items)
      $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($item in @($Items)) { if ($item) { [void]$set.Add([string]$item) } }
      , $set
    }

    # Splits `-z` output into relative paths.
    $splitNul = {
      param([string[]]$Lines)
      @(($Lines -join "`n") -split "`0" | ForEach-Object { $_.Trim("`n") } | Where-Object { $_ })
    }

    # Returns the highest sprint number across all matches in all segments, or $null.
    $priorSprintOf = {
      param([string]$RelativePath)
      $highestSprint = $null
      foreach ($segment in ($RelativePath -split '[\\/]')) {
        foreach ($sprintMatch in [regex]::Matches($segment, '(?i)sprint[-_]?(?:end[-_]?)?(\d{4})')) {
          $sprint = [int]$sprintMatch.Groups[1].Value
          if ($null -eq $highestSprint -or $sprint -gt $highestSprint) { $highestSprint = $sprint }
        }
      }
      $highestSprint
    }

    # Lists files on disk under <root>\_generated as repo-relative '/' paths.
    $listDiskFiles = {
      param([string]$Root)
      $generated = Join-Path $Root '_generated'
      if (-not (Test-Path -LiteralPath $generated -PathType Container)) { return @() }
      $prefix = ([IO.Path]::GetFullPath($Root)).TrimEnd('\') + '\'
      @(Get-ChildItem -LiteralPath $generated -Recurse -File -Force -ErrorAction SilentlyContinue |
          ForEach-Object { $_.FullName.Substring($prefix.Length).Replace('\', '/') })
    }

    # Zips the given repo-relative files, preserving their relative paths.
    $archiveFiles = {
      param([string]$Root, [string[]]$RelativePaths, [string]$Name)
      if ($NoArchive -or $RelativePaths.Count -eq 0) { return $null }
      $staging = Join-Path ([IO.Path]::GetTempPath()) "GeneratedRemediation-$([guid]::NewGuid().ToString('N'))"
      try {
        foreach ($rel in $RelativePaths) {
          $source = Join-Path $Root $rel
          if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
          $dest = Join-Path $staging $rel
          [void](New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force)
          Copy-Item -LiteralPath $source -Destination $dest -Force
        }
        if (-not (Test-Path -LiteralPath $ArchiveRoot)) { [void](New-Item -ItemType Directory -Path $ArchiveRoot -Force) }
        $zip = Join-Path $ArchiveRoot "$Name-$stamp.zip"
        Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $zip -CompressionLevel Optimal -Force
        $zip
      } finally {
        if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue }
      }
    }

    # Removes now-empty directories under <root>\_generated (and the folder itself when empty).
    $pruneEmpty = {
      param([string]$Root)
      $generated = Join-Path $Root '_generated'
      if (-not (Test-Path -LiteralPath $generated)) { return }
      Get-ChildItem -LiteralPath $generated -Recurse -Directory -Force |
        Sort-Object { $_.FullName.Length } -Descending |
        Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force) } |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
      if (-not (Get-ChildItem -LiteralPath $generated -Force)) { Remove-Item -LiteralPath $generated -Force }
    }

    $needsArchive = $Execute -and -not $NoArchive -and
      ($Scope -contains 'StableWorktree' -or $Scope -contains 'SprintCarryover')
    if ($needsArchive) {
      if ([string]::IsNullOrWhiteSpace($ArchiveRoot)) {
        throw "-ArchiveRoot is required with -Execute for the StableWorktree/SprintCarryover scopes (or pass -NoArchive)."
      }
      $ArchiveRoot = [IO.Path]::GetFullPath($ArchiveRoot)
      if ([IO.Path]::GetRelativePath([IO.Path]::GetFullPath($GitRoot), $ArchiveRoot) -match '(?i)(^|[\\/])_generated([\\/]|$)' -and
        $ArchiveRoot.StartsWith([IO.Path]::GetFullPath($GitRoot), [StringComparison]::OrdinalIgnoreCase)) {
        throw "-ArchiveRoot '$ArchiveRoot' is inside a _generated folder under GitRoot; it could be deleted by this remediation."
      }
    }
    if ($PushRewrittenHistory -and -not $Execute) { throw '-PushRewrittenHistory requires -Execute.' }
    if ($Execute -and $Scope -contains 'StableHistory' -and [string]::IsNullOrWhiteSpace($HistoryWorkRoot)) {
      throw '-HistoryWorkRoot is required with -Execute for the StableHistory scope.'
    }
  }

  process {
    $stableResults = [System.Collections.Generic.List[object]]::new()
    $sprintResults = [System.Collections.Generic.List[object]]::new()
    $historyResults = [System.Collections.Generic.List[object]]::new()

    foreach ($repo in $RepositoryName) {
      $stablePath = Join-Path $GitRoot $repo
      if (-not (Test-Path -LiteralPath (Join-Path $stablePath '.git'))) {
        $errors.Add("[$repo] stable worktree '$stablePath' not found; skipped.")
        continue
      }
      $branchReader = if ($Scope -contains 'StableWorktree') { $checkedGit } else { $invokeGit }
      $branch = (& $branchReader @('-C', $stablePath, 'branch', '--show-current')).Output | Select-Object -First 1
      $sprintWorktrees = @(Get-ChildItem -LiteralPath $GitRoot -Directory -Filter "$repo-wt-*" -ErrorAction SilentlyContinue)
      $currentSprintWorktrees = @($sprintWorktrees | Where-Object { $_.Name -like "$repo-wt-*-sprint-$SprintNumber-work-items" })

      # ---------------- StableWorktree ----------------
      if ($Scope -contains 'StableWorktree') {
        $entry = [ordered]@{
          Repository = $repo; Path = $stablePath; Branch = $branch; Action = 'Planned'
          TrackedDeferred = @(); UntrackedFiles = 0; UntrackedSample = @(); DeletedFiles = 0; Archive = $null
          CurrentSprintProtected = 0; CurrentSprintProtectedSample = @()
        }
        if ($branch -ne $StableBranch) {
          $entry.Action = "Skipped: on branch '$branch', not '$StableBranch'"
          $errors.Add("[$repo] stable worktree is on '$branch'; StableWorktree skipped.")
        } else {
          $tracked = & $splitNul (& $checkedGit @('-C', $stablePath, 'ls-files', '-z', '--', '_generated')).Output
          $trackedSet = (& $newSet $tracked)
          $candidates = @(& $stableDiskFiles $stablePath | Where-Object { -not $trackedSet.Contains($_) })
          $protected = @($candidates | Where-Object { $s = & $priorSprintOf $_; $null -ne $s -and $s -ge $currentSprint })
          $protectedSet = (& $newSet $protected)
          $untracked = @($candidates | Where-Object { -not $protectedSet.Contains($_) })
          $entry.CurrentSprintProtected = $protected.Count
          $entry.CurrentSprintProtectedSample = @($protected | Select-Object -First 10)
          $entry.TrackedDeferred = @($tracked)
          $entry.UntrackedFiles = $untracked.Count
          $entry.UntrackedSample = @($untracked | Select-Object -First 25)
          if ($untracked.Count -eq 0) {
            $entry.Action = 'NothingToDelete'
          } elseif ($Execute -and $PSCmdlet.ShouldProcess("$stablePath\_generated ($($untracked.Count) untracked file(s))", 'Archive and delete')) {
            try {
              $archive = & $archiveStableFiles $stablePath $untracked "$repo-stable-_generated"
              $entry.Archive = $archive.Path
              foreach ($rel in $untracked) {
                $target = & $safeStablePath $stablePath $rel
                if ((Get-FileHash -LiteralPath $target -Algorithm SHA256 -ErrorAction Stop).Hash -ne $archive.Hashes[$rel]) {
                  throw "Source changed before deletion: $rel"
                }
                Remove-Item -LiteralPath $target -Force -ErrorAction Stop
                $entry.DeletedFiles++
              }
              & $pruneEmpty $stablePath
              $entry.Action = 'Deleted'
            } catch {
              $entry.Action = 'Failed'
              $errors.Add("[$repo] stable delete failed: $($_.Exception.Message)")
            }
          }
        }
        $stableResults.Add([PSCustomObject]$entry)
      }

      # ---------------- SprintCarryover ----------------
      if ($Scope -contains 'SprintCarryover') {
        if ($currentSprintWorktrees.Count -eq 0) {
          $sprintResults.Add([PSCustomObject]@{ Repository = $repo; Path = $null; Action = "NoSprint$SprintNumber`Worktree" })
        }
        foreach ($wt in $currentSprintWorktrees) {
          $wtPath = $wt.FullName
          $entry = [ordered]@{
            Repository = $repo; Path = $wtPath; Action = 'Planned'
            InheritedTracked = @(); PriorSprintNamedTracked = @(); PriorSprintNamedUntracked = @()
            SkippedModified = @(); GitRemoved = 0; DeletedFiles = 0; Archive = $null
          }
          $mainPaths = & $splitNul (& $invokeGit @('-C', $wtPath, 'ls-tree', '-r', '-z', '--name-only', $StableBranch, '--', '_generated')).Output
          $mainSet = (& $newSet $mainPaths)
          $tracked = & $splitNul (& $invokeGit @('-C', $wtPath, 'ls-files', '-z', '--', '_generated')).Output
          $trackedSet = (& $newSet $tracked)
          $modified = & $splitNul (& $invokeGit @('-C', $wtPath, 'diff', '--name-only', '-z', 'HEAD', '--', '_generated')).Output
          $modifiedSet = (& $newSet $modified)

          $gitTargets = [System.Collections.Generic.List[string]]::new()
          foreach ($rel in $tracked) {
            $priorSprint = & $priorSprintOf $rel
            # Current-sprint (or later) evidence is never removed, even when inherited.
            if ($null -ne $priorSprint -and $priorSprint -ge $currentSprint) { continue }
            $isInherited = $mainSet.Contains($rel)
            $isPriorNamed = ($null -ne $priorSprint -and $priorSprint -lt $currentSprint)
            if (-not ($isInherited -or $isPriorNamed)) { continue }
            if ($modifiedSet.Contains($rel)) { $entry.SkippedModified += $rel; continue }
            if ($isInherited) { $entry.InheritedTracked += $rel } else { $entry.PriorSprintNamedTracked += $rel }
            $gitTargets.Add($rel)
          }
          $untrackedTargets = @(& $listDiskFiles $wtPath | Where-Object {
              if ($trackedSet.Contains($_)) { return $false }
              $priorSprint = & $priorSprintOf $_
              $null -ne $priorSprint -and $priorSprint -lt $currentSprint
            })
          $entry.PriorSprintNamedUntracked = $untrackedTargets

          $total = $gitTargets.Count + $untrackedTargets.Count
          if ($total -eq 0) {
            $entry.Action = 'NothingToRemove'
          } elseif ($Execute -and $PSCmdlet.ShouldProcess("$wtPath\_generated ($total prior-sprint file(s))", 'Archive and remove (git rm staged, not committed)')) {
            try {
              $entry.Archive = & $archiveFiles $wtPath (@($gitTargets) + $untrackedTargets) "$($wt.Name)-carryover-_generated"
              if ($gitTargets.Count -gt 0) {
                $specFile = Join-Path ([IO.Path]::GetTempPath()) "GeneratedRemediation-$([guid]::NewGuid().ToString('N')).txt"
                try {
                  [IO.File]::WriteAllText($specFile, (($gitTargets | ForEach-Object { ":(literal)$_" }) -join "`0"), [Text.UTF8Encoding]::new($false))
                  $rm = & $invokeGit @('-C', $wtPath, 'rm', '-q', '--ignore-unmatch', "--pathspec-from-file=$specFile", '--pathspec-file-nul')
                  if ($rm.ExitCode -ne 0) { throw "git rm failed: $($rm.Error)" }
                } finally { Remove-Item -LiteralPath $specFile -Force -ErrorAction SilentlyContinue }
                $entry.GitRemoved = $gitTargets.Count
              }
              foreach ($rel in $untrackedTargets) {
                Remove-Item -LiteralPath (Join-Path $wtPath $rel) -Force -ErrorAction Stop
                $entry.DeletedFiles++
              }
              & $pruneEmpty $wtPath
              $entry.Action = 'Removed'
            } catch {
              $entry.Action = 'Failed'
              $errors.Add("[$($wt.Name)] carryover removal failed: $($_.Exception.Message)")
            }
          }
          $sprintResults.Add([PSCustomObject]$entry)
        }
      }

      # ---------------- StableHistory ----------------
      if ($Scope -contains 'StableHistory') {
        $histPaths = @((& $invokeGit @('-C', $stablePath, 'log', $StableBranch, '--name-only', '--format=', '--', '_generated')).Output |
            Where-Object { $_ } | Sort-Object -Unique)
        $histCommits = @((& $invokeGit @('-C', $stablePath, 'log', $StableBranch, '--format=%h %ad %s', '--date=short', '--', '_generated')).Output |
            Where-Object { $_ })
        $originUrl = (& $invokeGit @('-C', $stablePath, 'remote', 'get-url', 'origin')).Output | Select-Object -First 1
        # Every registered worktree except the stable one, wherever it lives (build/release worktrees included).
        $stableFull = ([IO.Path]::GetFullPath($stablePath)).TrimEnd('\')
        $registeredOthers = @((& $invokeGit @('-C', $stablePath, 'worktree', 'list', '--porcelain')).Output |
            Where-Object { $_ -like 'worktree *' } |
            ForEach-Object { ([IO.Path]::GetFullPath($_.Substring(9))).TrimEnd('\') } |
            Where-Object { -not $_.Equals($stableFull, [StringComparison]::OrdinalIgnoreCase) })
        $otherWorktrees = @(@($sprintWorktrees.FullName) + $registeredOthers | Where-Object { $_ } | Sort-Object -Unique)
        $entry = [ordered]@{
          Repository = $repo; Origin = $originUrl; Action = 'Planned'
          HistoryPathCount = $histPaths.Count; HistoryCommitCount = $histCommits.Count
          HistoryCommits = $histCommits; OtherWorktrees = $otherWorktrees
          BareClone = $null; RefsRewritten = @(); Verified = $false; Pushed = $false
        }
        if ($histPaths.Count -eq 0) {
          $entry.Action = 'NoHistory'
        } elseif ($Execute) {
          try {
            $null = & git filter-repo --version 2>&1
            if ($LASTEXITCODE -ne 0) {
              throw "git filter-repo is not installed. Install it ('py -m pip install git-filter-repo') and re-run."
            }
            if (-not $PSCmdlet.ShouldProcess("$repo history ($($histCommits.Count) commit(s))", 'Rewrite a fresh bare clone with git filter-repo')) {
              $historyResults.Add([PSCustomObject]$entry); continue
            }
            $bare = Join-Path ([IO.Path]::GetFullPath($HistoryWorkRoot)) "$repo-$stamp.git"
            if (Test-Path -LiteralPath $bare) { throw "History clone target '$bare' already exists." }
            [void](New-Item -ItemType Directory -Path (Split-Path -Parent $bare) -Force)
            $clone = & $invokeGit @('clone', '--bare', '--quiet', $originUrl, $bare)
            if ($clone.ExitCode -ne 0) { throw "bare clone failed: $($clone.Error)" }
            $entry.BareClone = $bare
            $before = @{}
            foreach ($line in (& $invokeGit @('-C', $bare, 'for-each-ref', '--format=%(refname) %(objectname)', 'refs/heads', 'refs/tags')).Output) {
              $parts = $line -split ' ', 2; $before[$parts[0]] = $parts[1]
            }
            $filter = & $invokeGit @('-C', $bare, 'filter-repo', '--invert-paths', '--path', '_generated/', '--force')
            if ($filter.ExitCode -ne 0) { throw "filter-repo failed: $($filter.Error)" }
            $left = @((& $invokeGit @('-C', $bare, 'log', '--all', '--name-only', '--format=', '--', '_generated')).Output | Where-Object { $_ })
            $entry.Verified = ($left.Count -eq 0)
            if (-not $entry.Verified) { throw "verification failed: $($left.Count) _generated path(s) remain after filter-repo." }
            $refs = foreach ($line in (& $invokeGit @('-C', $bare, 'for-each-ref', '--format=%(refname) %(objectname)', 'refs/heads', 'refs/tags')).Output) {
              $parts = $line -split ' ', 2
              [PSCustomObject]@{ Ref = $parts[0]; Old = $before[$parts[0]]; New = $parts[1] }
            }
            $entry.RefsRewritten = @($refs | Where-Object { $_.Old -ne $_.New })
            $entry.Action = 'RewrittenLocally'

            if ($PushRewrittenHistory) {
              if ($otherWorktrees.Count -gt 0) {
                throw "push refused: other worktree(s) still exist ($($otherWorktrees -join ', ')); they carry the old history. Remove them (run after sprint end) first."
              }
              if ($PSCmdlet.ShouldProcess("$originUrl ($($entry.RefsRewritten.Count) ref(s))", 'FORCE-PUSH rewritten history')) {
                [void](& $invokeGit @('-C', $bare, 'remote', 'add', 'origin', $originUrl))
                foreach ($ref in $entry.RefsRewritten) {
                  $leaseArgs = if ($ref.Old) { "--force-with-lease=$($ref.Ref):$($ref.Old)" } else { '--force' }
                  $push = & $invokeGit @('-C', $bare, 'push', $leaseArgs, 'origin', "$($ref.New):$($ref.Ref)")
                  if ($push.ExitCode -ne 0) { throw "push of $($ref.Ref) failed: $($push.Error)" }
                }
                $entry.Pushed = $true
                $entry.Action = 'Pushed'
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                  -Message "[$repo] history rewritten and pushed. Re-sync every clone/worktree (fetch, then reset to origin/$StableBranch) after preserving local work."
              }
            }
          } catch {
            $entry.Action = 'Failed'
            $errors.Add("[$repo] history: $($_.Exception.Message)")
          }
        }
        $historyResults.Add([PSCustomObject]$entry)
      }
    }

    $report = [PSCustomObject]@{
      SprintNumber = $SprintNumber
      Mode         = if ($Execute) { 'Execute' } else { 'Plan' }
      Timestamp    = $stamp
      Scope        = $Scope
      Stable       = $stableResults.ToArray()
      Sprint       = $sprintResults.ToArray()
      History      = $historyResults.ToArray()
      Errors       = $errors.ToArray()
    }

    if (-not [string]::IsNullOrWhiteSpace($EvidencePath)) {
      $dir = Split-Path -Parent $EvidencePath
      if ($dir -and -not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
      $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $EvidencePath -Encoding utf8
    }
    foreach ($e in $errors) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $e }
    $report
  }
}

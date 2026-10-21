function Invoke-GeneratedFolderRemediation {
  <#
  .SYNOPSIS
    Plans Generated folder remediation; all execution is currently held.

  .DESCRIPTION
    Supported operation is read-only planning. Every -Execute request is refused
    because complete approved, bound file/default-data, named-stream and
    root/directory custody is not integrated. Individual entry restores do not
    establish that contract. No caller approval flag or receipt bypass exists.
    The prior controlled two-host cleanup remains accepted and is not repeated.

    Rule R-38 says sprint `_generated/` folders are deleted at sprint end. In
    practice, files reach the stable worktrees anyway (see SC-0470): sprint-close
    commits force-add ignored `_generated/` files, and SprintEnd/AIAdapter steps
    write backups straight into the stable worktrees. This cmdlet remediates
    three scopes:

    StableWorktree (Plan only)
      For each stable worktree (`<GitRoot>\<RepositoryName>` on -StableBranch),
      reports untracked or ignored legacy removal candidates under `_generated/`. Tracked
      files are NOT deleted here, nor is any path whose sprint segment is
      -SprintNumber or later (CurrentSprintProtected), because removing them would mean a commit to
      the stable branch. They are reported as TrackedDeferred and leave the
      stable branch when the sprint branch, which removes them in the
      SprintCarryover scope, merges at sprint end.

    SprintCarryover (Plan only)
      For each current sprint worktree
      (`<GitRoot>\<RepositoryName>-wt-*-Sprint-<SprintNumber>-work-items`),
      reports legacy `_generated/` candidates from an earlier sprint:
        - InheritedTracked: files tracked on the sprint branch whose path also
          exists in the -StableBranch tree. They are removed with `git rm` and
          staged, never committed.
        - PriorSprintNamed: tracked-or-untracked files whose path has a sprint
          segment (Sprint0015, SprintEnd0013, sprint-end-0007, ...) numbered
          below -SprintNumber.
      These are candidate classes only. Current/future paths and files with
      uncommitted modifications are skipped. Each remaining candidate requires
      an existing identical-relative-path file in the corresponding stable
      worktree and actual default-data byte equality. Missing, different or held
      partners are preserved and reported. Git common repository and stable
      branch are checked before comparison. A stable partner already removed by
      combined StableWorktree processing is missing, never retrospective proof.
      Selection/index/HEAD/byte witnesses are rechecked after archiving before
      removal. This is non-atomic and requires quiet producers; default-data
      equality establishes neither named-stream equality nor custody/readiness.

    StableHistory
      Reports every `_generated/` path and commit reachable from -StableBranch.
      Execution and -PushRewrittenHistory are retired. History changes require
      the separately coordinated operator workflow; this cmdlet only inventories.

    Plan retains same-path default-byte comparison, Git/WIP and current/future
    sprint protection. It does not establish complete inventory, ADS equality,
    coherent restore, aggregate source stability or removal readiness.
    No execution can create archives, temporary files or evidence, prune
    directories, remove files or change a Git index. -WhatIf with -Execute
    receives the same refusal. History mutation remains retired.

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
    Always refused until a complete approved custody contract is integrated.
    Without this switch, only planning is supported.
  .PARAMETER ArchiveRoot
    Retained for call compatibility; supplying an archive path cannot enable
    execution. Planning does not create an archive.
  .PARAMETER NoArchive
    Retained for planning compatibility. Any use with -Execute is rejected.
  .PARAMETER HistoryWorkRoot
    Retained for call compatibility only; no history output is created.
    StableHistory execution is retired.
  .PARAMETER PushRewrittenHistory
    Retired option; rejected with or without -Execute.
  .PARAMETER SelectionManifestPath
    Optional SprintDuplicateSelection v1 JSON snapshot. Requires the expected
    raw-file SHA256, Scope SprintCarryover only, one RepositoryName and exactly
    one current sprint worktree. Narrows Plan only; never authorizes execution.
  .PARAMETER ExpectedSelectionManifestSHA256
    Expected exact raw-file SHA256. Repository identity, roots, common Git
    directory, HEADs and selected default bytes are checked against this Plan.
    Supplied ADS, custody, baseline and snapshot index/WIP digests remain unverified.
  .PARAMETER EvidencePath
    Optional JSON file path for the full report (SC-0033: place it under a
    `_generated/` folder of the current sprint).
  .OUTPUTS
    [PSCustomObject] report with Stable, Sprint, History, Errors and Mode.
  .EXAMPLE
    Invoke-GeneratedFolderRemediation -SprintNumber '0016' -EvidencePath $plan
    # Legacy partial-mode inventory only; not the expanded Task 16.84 plan.
  .EXAMPLE
    Invoke-GeneratedFolderRemediation -SprintNumber '0016' -Scope StableWorktree, SprintCarryover
    # Read-only candidate plan; no execution is supported.
  .EXAMPLE
    Invoke-GeneratedFolderRemediation -SprintNumber '0017' -Scope StableHistory
    # Read-only history inventory; history execution is retired.
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
    [string]$EvidencePath,

    [Parameter()]
    [string]$SelectionManifestPath,

    [Parameter()]
    [string]$ExpectedSelectionManifestSHA256
  )

  begin {
    $fn = 'Invoke-GeneratedFolderRemediation'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    # Reject unsupported execution before logging, helper loading or Git/output.
    if ($PushRewrittenHistory) { throw '-PushRewrittenHistory is retired. Use read-only planning and the coordinated operator history workflow.' }
    if ($Execute -and $NoArchive) { throw '-Execute with -NoArchive is unsupported. Use planning and the reviewed archive workflow.' }
    if ($Execute -and $Scope -contains 'StableHistory') { throw 'StableHistory execution is retired, including default or combined scopes. Use read-only history planning and the coordinated operator workflow.' }
    if ($Execute) { throw 'Execution held: complete approved bound file/default-data, named-stream and root/directory custody is not integrated. Use read-only planning.' }
    $useSelectionManifest = $PSBoundParameters.ContainsKey('SelectionManifestPath') -or $PSBoundParameters.ContainsKey('ExpectedSelectionManifestSHA256')
    if ($useSelectionManifest -and (
        [string]::IsNullOrWhiteSpace($SelectionManifestPath) -or $ExpectedSelectionManifestSHA256 -notmatch '^[A-Fa-f0-9]{64}$' -or
        $Scope.Count -ne 1 -or $Scope[0] -cne 'SprintCarryover' -or $RepositoryName.Count -ne 1)) {
      throw 'SelectionManifestPath and ExpectedSelectionManifestSHA256 must be paired for one explicit SprintCarryover Plan repository.'
    }
    if ($useSelectionManifest -and -not (Get-Command Get-GeneratedRemediationManifestSelection -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '../private/Get-GeneratedRemediationManifestSelection.ps1')
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
    if ($Scope -contains 'SprintCarryover' -and -not (Get-Command Get-GeneratedRemediationByteComparison -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '../private/Get-GeneratedRemediationByteComparison.ps1')
    }

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
      if ($RelativePaths.Count -eq 0) { return $null }
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

    $needsArchive = $Execute -and
      ($Scope -contains 'StableWorktree' -or $Scope -contains 'SprintCarryover')
    if ($needsArchive) {
      if ([string]::IsNullOrWhiteSpace($ArchiveRoot)) {
        throw "-ArchiveRoot is required with -Execute for the StableWorktree/SprintCarryover scopes."
      }
      $ArchiveRoot = [IO.Path]::GetFullPath($ArchiveRoot)
      if ([IO.Path]::GetRelativePath([IO.Path]::GetFullPath($GitRoot), $ArchiveRoot) -match '(?i)(^|[\\/])_generated([\\/]|$)' -and
        $ArchiveRoot.StartsWith([IO.Path]::GetFullPath($GitRoot), [StringComparison]::OrdinalIgnoreCase)) {
        throw "-ArchiveRoot '$ArchiveRoot' is inside a _generated folder under GitRoot; it could be deleted by this remediation."
      }
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
      $branchReader = if ($Scope -contains 'StableWorktree' -or $Scope -contains 'SprintCarryover') { $checkedGit } else { $invokeGit }
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
        if ($useSelectionManifest -and $currentSprintWorktrees.Count -ne 1) {
          $errors.Add("[$repo] manifest Plan requires exactly one current sprint worktree.")
          $sprintResults.Add([pscustomobject]@{
            Repository = $repo; Path = $null; Action = 'Held'
            SelectionManifestBinding = [pscustomobject]@{ Status = 'Held'; Errors = @('Exactly one current sprint worktree is required.'); Approved = $false; CustodyVerified = $false; NamedStreamsVerified = $false; ReadyForRemoval = $false }
          })
          continue
        }
        if ($currentSprintWorktrees.Count -eq 0) {
          $sprintResults.Add([PSCustomObject]@{ Repository = $repo; Path = $null; Action = "NoSprint$SprintNumber`Worktree" })
        }
        foreach ($wt in $currentSprintWorktrees) {
          $wtPath = $wt.FullName
          $entry = [ordered]@{
            Repository = $repo; Path = $wtPath; Action = 'Planned'
            InheritedTracked = @(); PriorSprintNamedTracked = @(); PriorSprintNamedUntracked = @()
            SkippedModified = @(); GitRemoved = 0; DeletedFiles = 0; Archive = $null
            PreservedFiles = @(); DefaultDataWitnesses = @()
            ReadyForRemoval = $false; CustodyVerified = $false; NamedStreamsVerified = $false
          }
          # All identity and selection reads are checked; a failed command is not an empty inventory.
          $getCarryoverState = {
            $stableBranchNow = (& $checkedGit @('-C', $stablePath, 'branch', '--show-current')).Output
            if (@($stableBranchNow).Count -ne 1 -or $stableBranchNow[0] -cne $StableBranch) { throw 'Stable branch binding differs.' }
            $stableCommon = (& $checkedGit @('-C', $stablePath, 'rev-parse', '--path-format=absolute', '--git-common-dir')).Output
            $sprintCommon = (& $checkedGit @('-C', $wtPath, 'rev-parse', '--path-format=absolute', '--git-common-dir')).Output
            if (@($stableCommon).Count -ne 1 -or @($sprintCommon).Count -ne 1 -or
              -not [IO.Path]::IsPathFullyQualified($stableCommon[0]) -or -not [IO.Path]::IsPathFullyQualified($sprintCommon[0]) -or
              [IO.Path]::GetFullPath($stableCommon[0]).TrimEnd('\', '/') -ine [IO.Path]::GetFullPath($sprintCommon[0]).TrimEnd('\', '/')) {
              throw 'Stable and sprint common repository binding differs.'
            }
            [pscustomobject]@{
              Common = [IO.Path]::GetFullPath($stableCommon[0])
              StableHead = (& $checkedGit @('-C', $stablePath, 'rev-parse', '--verify', 'HEAD')).Output
              SprintHead = (& $checkedGit @('-C', $wtPath, 'rev-parse', '--verify', 'HEAD')).Output
              MainPaths = (& $checkedGit @('-C', $wtPath, 'ls-tree', '-r', '-z', '--name-only', $StableBranch, '--', '_generated')).Output
              Index = (& $checkedGit @('-C', $wtPath, 'ls-files', '--stage', '-z', '--', '_generated')).Output
              Tracked = (& $checkedGit @('-C', $wtPath, 'ls-files', '-z', '--', '_generated')).Output
              Modified = (& $checkedGit @('-C', $wtPath, 'diff', '--name-only', '-z', 'HEAD', '--', '_generated')).Output
            }
          }
          try { $selectionState = & $getCarryoverState }
          catch {
            $entry.Action = 'Held'
            $errors.Add("[$($wt.Name)] carryover identity/inventory held: $($_.Exception.Message)")
            $sprintResults.Add([PSCustomObject]$entry)
            continue
          }
          $manifestBinding = $null
          if ($useSelectionManifest) {
            $manifestBinding = [ordered]@{
              Status = 'Held'; Path = $SelectionManifestPath; ExpectedSHA256 = $ExpectedSelectionManifestSHA256; ActualSHA256 = $null
              SchemaValid = $false; RepositoryRootsAndHeadsBound = $false; SelectedDefaultBytesBound = $false
              Rows = @(); Errors = @(); Approved = $false; CustodyVerified = $false; NamedStreamsVerified = $false; ReadyForRemoval = $false
              Verification = 'Partial snapshot Plan binding only. Supplied ADS, custody, baseline/baselineRow and snapshot index/staged/unstaged/untracked digests are not independently verified; current live WIP protection still applies. Non-atomic; quiet producers required.'
            }
            $entry.SelectionManifestBinding = $manifestBinding
            try {
              $manifestBinding.Path = [IO.Path]::GetFullPath($SelectionManifestPath)
              $manifestBytes = [IO.File]::ReadAllBytes($manifestBinding.Path)
              $manifestBinding.ActualSHA256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($manifestBytes))
              if ($manifestBinding.ActualSHA256 -ine $ExpectedSelectionManifestSHA256) { throw 'Raw manifest SHA256 differs.' }
              $manifestText = [Text.UTF8Encoding]::new($false, $true).GetString($manifestBytes)
              if ($manifestText.StartsWith([string][char]0xFEFF, [StringComparison]::Ordinal)) { $manifestText = $manifestText.Substring(1) }
              $manifestSelection = Get-GeneratedRemediationManifestSelection -ManifestJson $manifestText -CurrentSprintNumber $currentSprint
              if (-not $manifestSelection.Valid) { throw ('Invalid selection manifest: ' + ($manifestSelection.Errors -join '; ')) }
              $manifestBinding.SchemaValid = $true
              $manifest = ConvertFrom-Json -InputObject $manifestText -AsHashtable -Depth 64 -ErrorAction Stop
              $repository = $manifest.repository
              if ($repository.identity -cne $repo -or
                [IO.Path]::GetFullPath($repository.commonGitDir).TrimEnd('\', '/') -ine $selectionState.Common.TrimEnd('\', '/') -or
                [IO.Path]::GetFullPath($repository.stableRoot).TrimEnd('\', '/') -ine [IO.Path]::GetFullPath($stablePath).TrimEnd('\', '/') -or
                [IO.Path]::GetFullPath($repository.sprintRoot).TrimEnd('\', '/') -ine [IO.Path]::GetFullPath($wtPath).TrimEnd('\', '/')) {
                throw 'Manifest repository/common Git/root binding differs.'
              }
              $stableRecord = @($manifest.worktrees | Where-Object role -CEQ 'Stable')[0]
              $sprintRecord = @($manifest.worktrees | Where-Object role -CEQ 'Sprint')[0]
              if (@($selectionState.StableHead).Count -ne 1 -or @($selectionState.SprintHead).Count -ne 1 -or
                $stableRecord.head -cne $selectionState.StableHead[0] -or $sprintRecord.head -cne $selectionState.SprintHead[0]) {
                throw 'Manifest Stable/Sprint HEAD binding differs.'
              }
              $manifestBinding.RepositoryRootsAndHeadsBound = $true
            } catch {
              $manifestBinding.Errors = @($_.Exception.Message)
              $entry.Action = 'Held'
              $errors.Add("[$($wt.Name)] manifest Plan held: $($_.Exception.Message)")
              $sprintResults.Add([pscustomobject]$entry)
              continue
            }
          }
          $mainPaths = & $splitNul $selectionState.MainPaths
          $mainSet = (& $newSet $mainPaths)
          $tracked = & $splitNul $selectionState.Tracked
          $trackedSet = (& $newSet $tracked)
          $modified = & $splitNul $selectionState.Modified
          $modifiedSet = (& $newSet $modified)
          $witnesses = @{}
          $qualifyCarryoverPath = {
            param([string]$Relative)
            $proof = Get-GeneratedRemediationByteComparison -StableRoot $stablePath -SprintRoot $wtPath -RepositoryName $repo -RelativePath $Relative
            if ($proof.Status -ceq 'Equal' -and $proof.DefaultDataEqual -is [bool] -and $proof.DefaultDataEqual) {
              $witnesses[$Relative] = $proof
              return $true
            }
            $entry.PreservedFiles += [pscustomobject]@{ Path = $Relative; Status = $proof.Status; Reason = $proof.Reason; Errors = $proof.Errors }
            return $false
          }

          $gitTargets = [System.Collections.Generic.List[string]]::new()
          foreach ($rel in $tracked) {
            $priorSprint = & $priorSprintOf $rel
            # Current-sprint (or later) evidence is never removed, even when inherited.
            if ($null -ne $priorSprint -and $priorSprint -ge $currentSprint) { continue }
            $isInherited = $mainSet.Contains($rel)
            $isPriorNamed = ($null -ne $priorSprint -and $priorSprint -lt $currentSprint)
            if (-not ($isInherited -or $isPriorNamed)) { continue }
            if ($modifiedSet.Contains($rel)) { $entry.SkippedModified += $rel; continue }
            if (-not (& $qualifyCarryoverPath $rel)) { continue }
            if ($isInherited) { $entry.InheritedTracked += $rel } else { $entry.PriorSprintNamedTracked += $rel }
            $gitTargets.Add($rel)
          }
          $untrackedTargets = @(& $listDiskFiles $wtPath | Where-Object {
              if ($trackedSet.Contains($_)) { return $false }
              $priorSprint = & $priorSprintOf $_
              if ($null -eq $priorSprint -or $priorSprint -ge $currentSprint) { return $false }
              & $qualifyCarryoverPath $_
            })
          $entry.PriorSprintNamedUntracked = $untrackedTargets
          if ($useSelectionManifest) {
            $selectedPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            $rawRows = @{}
            foreach ($row in $manifest.rows) { $rawRows[$row.id] = $row }
            foreach ($selectedRow in $manifestSelection.Rows) {
              $rawRow = $rawRows[$selectedRow.Id]
              $witness = $witnesses[$selectedRow.RelativePath]
              $defaultBytesMatch = $selectedRow.Action -ceq 'EligibleCandidate' -and $null -ne $witness -and $witness.Binding.RelativePath -ceq $selectedRow.RelativePath -and
                $rawRow.source.bytes -eq $witness.BytesCompared -and $rawRow.candidate.bytes -eq $witness.BytesCompared -and
                $rawRow.source.sha256 -ieq $witness.StableSHA256 -and $rawRow.candidate.sha256 -ieq $witness.SprintSHA256
              if ($defaultBytesMatch) { $null = $selectedPaths.Add($selectedRow.RelativePath) }
              $manifestBinding.Rows += [pscustomobject]@{
                Id = $selectedRow.Id; RelativePath = $selectedRow.RelativePath; DefaultBytesBound = [bool]$defaultBytesMatch
                Action = if ($defaultBytesMatch) { 'EligibleCandidate' } else { 'Preserve' }
                Reason = if ($defaultBytesMatch) { 'Existing live candidate and manifest default-byte witness match.' } else { 'Snapshot eligibility, live candidate/protection/WIP or default-byte witness did not match.' }
                Approved = $false
              }
            }
            foreach ($relative in @($gitTargets) + $untrackedTargets) {
              if (-not $selectedPaths.Contains($relative)) {
                $entry.PreservedFiles += [pscustomobject]@{ Path = $relative; Status = 'Preserve'; Reason = 'Not selected by bound manifest default-byte intersection.'; Errors = @() }
              }
            }
            $entry.InheritedTracked = @($entry.InheritedTracked | Where-Object { $selectedPaths.Contains($_) })
            $entry.PriorSprintNamedTracked = @($entry.PriorSprintNamedTracked | Where-Object { $selectedPaths.Contains($_) })
            $entry.PriorSprintNamedUntracked = @($entry.PriorSprintNamedUntracked | Where-Object { $selectedPaths.Contains($_) })
            $gitTargets = @($gitTargets | Where-Object { $selectedPaths.Contains($_) })
            $untrackedTargets = @($untrackedTargets | Where-Object { $selectedPaths.Contains($_) })
            $manifestBinding.Status = 'BoundPlan'
            $manifestBinding.SelectedDefaultBytesBound = ($selectedPaths.Count -gt 0)
            $manifestBinding.SelectedCandidateCount = $selectedPaths.Count
          }
          $entry.DefaultDataWitnesses = @($witnesses.Values | Where-Object { -not $useSelectionManifest -or $selectedPaths.Contains($_.Binding.RelativePath) })

          $total = $gitTargets.Count + $untrackedTargets.Count
          if ($total -eq 0) {
            $entry.Action = 'NothingToRemove'
          } elseif ($Execute -and $PSCmdlet.ShouldProcess("$wtPath\_generated ($total prior-sprint file(s))", 'Archive and remove (git rm staged, not committed)')) {
            try {
              $entry.Archive = & $archiveFiles $wtPath (@($gitTargets) + $untrackedTargets) "$($wt.Name)-carryover-_generated"
              $freshState = & $getCarryoverState
              if (($selectionState | ConvertTo-Json -Depth 5 -Compress) -cne ($freshState | ConvertTo-Json -Depth 5 -Compress)) {
                throw 'Carryover selection/index/HEAD drift after archive; batch preserved.'
              }
              foreach ($rel in @($gitTargets) + $untrackedTargets) {
                $fresh = Get-GeneratedRemediationByteComparison -StableRoot $stablePath -SprintRoot $wtPath -RepositoryName $repo -RelativePath $rel
                $original = $witnesses[$rel]
                if ($fresh.Status -cne 'Equal' -or $fresh.DefaultDataEqual -isnot [bool] -or -not $fresh.DefaultDataEqual -or
                  $fresh.StableSHA256 -cne $original.StableSHA256 -or $fresh.SprintSHA256 -cne $original.SprintSHA256 -or
                  $fresh.BytesCompared -ne $original.BytesCompared) { throw "Carryover byte witness drift after archive: $rel; batch preserved." }
              }
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
        if ($histPaths.Count -eq 0) { $entry.Action = 'NoHistory' }
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

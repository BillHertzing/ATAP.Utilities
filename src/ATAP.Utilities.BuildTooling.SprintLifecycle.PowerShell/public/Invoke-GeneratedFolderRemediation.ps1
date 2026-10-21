function Invoke-GeneratedFolderRemediation {
  <#
  .SYNOPSIS
    Plans Generated folder remediation and creates selected-file backups; removal is held.

  .DESCRIPTION
    Supports read-only planning and explicit selected-file backup/restore verification.
    Every -Execute request is refused
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
    No -Execute request can create archives, temporary files or evidence, prune
    directories, remove files or change a Git index. -WhatIf with -Execute
    receives the same refusal. History mutation remains retired.
    -CreateBackup separately backs up only the manifest-bound Plan selection and
    required ancestor directory streams to a new child of an existing external
    ArchiveRoot. Ordinary Plan creates no backup. Backup success grants no removal
    approval and does not verify supplied manifest custody/ADS/index assertions.

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
    Existing external parent for a fresh backup child with -CreateBackup.
    Required explicitly in that mode; never created on the caller's behalf.
    Supplying an archive path alone does not create a backup or enable removal.
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
  .PARAMETER CreateBackup
    Backup-only mode for the bound finite SprintCarryover Plan. Requires the
    paired selection manifest inputs, one repository, existing ArchiveRoot and
    no NoArchive. Honors ShouldProcess/WhatIf and retains partial output.
  .PARAMETER AllowVerifiedCloudDirectoryMetadata
    Existing reviewed census option, forwarded only with explicit CreateBackup.
    Default false. Supplying it for ordinary Plan is rejected.
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
    [string]$ExpectedSelectionManifestSHA256,

    [Parameter()]
    [switch]$CreateBackup,

    [Parameter()]
    [switch]$AllowVerifiedCloudDirectoryMetadata
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
    if ($CreateBackup -and (-not $useSelectionManifest -or $NoArchive -or [string]::IsNullOrWhiteSpace($ArchiveRoot))) {
      throw '-CreateBackup requires the paired manifest inputs, one SprintCarryover repository, existing ArchiveRoot and no NoArchive.'
    }
    if ($PSBoundParameters.ContainsKey('AllowVerifiedCloudDirectoryMetadata') -and -not $CreateBackup) {
      throw '-AllowVerifiedCloudDirectoryMetadata is supported only with -CreateBackup.'
    }
    if ($CreateBackup) {
      $ArchiveRoot = [IO.Path]::GetFullPath($ArchiveRoot)
      if ($ArchiveRoot.Length -gt 3) { $ArchiveRoot = $ArchiveRoot.TrimEnd([char[]]'\/') }
      if (-not (Test-Path -LiteralPath $ArchiveRoot -PathType Container)) { throw '-CreateBackup requires an existing ArchiveRoot directory.' }
    }
    if ($useSelectionManifest -and -not (Get-Command Get-GeneratedRemediationManifestSelection -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '../private/Get-GeneratedRemediationManifestSelection.ps1')
    }
    if ($useSelectionManifest -and -not (Get-Command Get-GeneratedRemediationFileSnapshot -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '../private/Get-GeneratedRemediationFileSnapshot.ps1')
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
      $raw = & git --no-optional-locks -c core.quotepath=off @ArgumentList 2>&1
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
          if ($CreateBackup) {
            $entry.Approved = $false
            $entry.Backup = [pscustomobject]@{
              Status = 'Held'; RequestedRelativePaths = @(); BundleRoot = $null; BundlePath = $null; Receipt = $null; Errors = @()
              Approved = $false; CustodyVerified = $false; NamedStreamsVerified = $false; ReadyForRemoval = $false
            }
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
              SchemaValid = $false; RepositoryRootsAndHeadsBound = $false; SelectedDefaultBytesBound = $false; SelectedFileStreamsBound = $false
              Rows = @(); Errors = @(); Approved = $false; CustodyVerified = $false; NamedStreamsVerified = $false; ReadyForRemoval = $false
              Verification = 'Partial snapshot Plan binding: selected file default/named streams are observed against each corresponding record. Supplied archiveMember/restoreVerified, root/directory streams, custody, baseline/baselineRow and snapshot index/staged/unstaged/untracked digests are not independently verified; current live WIP protection still applies. Non-atomic; quiet producers required; no durable identity or ABA proof.'
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
              $fileStreamEvidence = @()
              $fileStreamsMatch = $false
              $bindingReason = 'Snapshot eligibility, live candidate/protection/WIP or default-byte witness did not match.'
              if ($defaultBytesMatch) {
                try {
                  foreach ($side in @('source', 'candidate')) {
                    $expectedRoot = if ($side -ceq 'source') { $stablePath } else { $wtPath }
                    $expectedHash = if ($side -ceq 'source') { $witness.StableSHA256 } else { $witness.SprintSHA256 }
                    $snapshot = Get-GeneratedRemediationFileSnapshot -RootPath $expectedRoot -RelativePath $selectedRow.RelativePath
                    $sideEvidence = [pscustomobject]@{
                      Side = $side; Bound = $false; Binding = $snapshot.Binding
                      Success = $snapshot.Success; Consistent = $snapshot.Consistent
                      ObservedStreams = @(); ObservationsVerified = 0; Errors = @($snapshot.Errors)
                    }
                    $fileStreamEvidence += $sideEvidence
                    if ($snapshot.Success -isnot [bool] -or -not $snapshot.Success -or
                      $snapshot.Consistent -isnot [bool] -or -not $snapshot.Consistent -or @($snapshot.Observations).Count -ne 2) {
                      throw "$side file snapshot unavailable or inconsistent: $($snapshot.Errors -join '; ')"
                    }
                    if ($null -eq $snapshot.Binding -or
                      $snapshot.Binding.Root -ine [IO.Path]::GetFullPath($expectedRoot).TrimEnd([char[]]'\/') -or
                      $snapshot.Binding.RelativePath -cne $selectedRow.RelativePath -or
                      $snapshot.Binding.Path -ine (Join-Path $expectedRoot $selectedRow.RelativePath)) {
                      throw "$side file snapshot root/path binding differs."
                    }
                    foreach ($observation in $snapshot.Observations) {
                      $defaultStream = @($observation.Streams | Where-Object Name -CEQ ':$DATA')
                      $namedStreams = @($observation.Streams | Where-Object Name -CNE ':$DATA')
                      if ($defaultStream.Count -ne 1 -or $defaultStream[0].Bytes -ne $witness.BytesCompared -or
                        $defaultStream[0].SHA256 -ine $expectedHash) {
                        throw "$side observed default stream differs from byte witness."
                      }
                      if ($namedStreams.Count -ne @($rawRow[$side].streams).Count) {
                        throw "$side named-stream set differs from manifest."
                      }
                      foreach ($expectedStream in $rawRow[$side].streams) {
                        $observed = @($namedStreams | Where-Object Name -CEQ $expectedStream.name)
                        if ($observed.Count -ne 1 -or $observed[0].Bytes -ne $expectedStream.bytes -or
                          $observed[0].SHA256 -ine $expectedStream.sha256) {
                          throw "$side named stream '$($expectedStream.name)' name/length/hash differs from manifest."
                        }
                      }
                      $sideEvidence.ObservationsVerified++
                    }
                    $sideEvidence.ObservedStreams = @($snapshot.Observations[0].Streams)
                    $sideEvidence.Bound = $true
                  }
                  $fileStreamsMatch = $true
                  $bindingReason = 'Live candidate, default-byte witness and each side file-stream record match.'
                } catch {
                  $bindingReason = $_.Exception.Message
                }
              }
              if ($fileStreamsMatch) { $null = $selectedPaths.Add($selectedRow.RelativePath) }
              $manifestBinding.Rows += [pscustomobject]@{
                Id = $selectedRow.Id; RelativePath = $selectedRow.RelativePath; DefaultBytesBound = [bool]$defaultBytesMatch
                FileStreamsBound = $fileStreamsMatch; FileStreamEvidence = $fileStreamEvidence
                Action = if ($fileStreamsMatch) { 'EligibleCandidate' } else { 'Preserve' }
                Reason = $bindingReason
                Approved = $false
              }
            }
            foreach ($relative in @($gitTargets) + $untrackedTargets) {
              if (-not $selectedPaths.Contains($relative)) {
                $entry.PreservedFiles += [pscustomobject]@{ Path = $relative; Status = 'Preserve'; Reason = 'Not selected by bound manifest default-byte/file-stream intersection.'; Errors = @() }
              }
            }
            $entry.InheritedTracked = @($entry.InheritedTracked | Where-Object { $selectedPaths.Contains($_) })
            $entry.PriorSprintNamedTracked = @($entry.PriorSprintNamedTracked | Where-Object { $selectedPaths.Contains($_) })
            $entry.PriorSprintNamedUntracked = @($entry.PriorSprintNamedUntracked | Where-Object { $selectedPaths.Contains($_) })
            $gitTargets = @($gitTargets | Where-Object { $selectedPaths.Contains($_) })
            $untrackedTargets = @($untrackedTargets | Where-Object { $selectedPaths.Contains($_) })
            $manifestBinding.Status = 'BoundPlan'
            $manifestBinding.SelectedDefaultBytesBound = ($selectedPaths.Count -gt 0)
            $manifestBinding.SelectedFileStreamsBound = ($selectedPaths.Count -gt 0)
            $manifestBinding.SelectedCandidateCount = $selectedPaths.Count
          }
          $entry.DefaultDataWitnesses = @($witnesses.Values | Where-Object { -not $useSelectionManifest -or $selectedPaths.Contains($_.Binding.RelativePath) })

          $total = $gitTargets.Count + $untrackedTargets.Count
          if ($CreateBackup) {
            $backupPaths = [string[]]@(@($gitTargets) + $untrackedTargets)
            $entry.Backup.RequestedRelativePaths = $backupPaths
            if ($total -eq 0) {
              $entry.Backup.Status = 'NoSelection'; $entry.Action = 'NothingToBackUp'
            } else {
              try {
                foreach ($protectedRoot in @($stablePath, $wtPath, $selectionState.Common)) {
                  $protectedBoundary = [IO.Path]::GetFullPath($protectedRoot).TrimEnd([char[]]'\/')
                  if ($ArchiveRoot -ieq $protectedBoundary -or $ArchiveRoot.StartsWith($protectedBoundary + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                    throw 'ArchiveRoot must be outside stable, sprint and common Git boundaries.'
                  }
                }
                $backupRoot = Join-Path $ArchiveRoot ('GeneratedBackup-' + [guid]::NewGuid().ToString('N'))
                $entry.Backup.BundleRoot = $backupRoot
                if (-not $PSCmdlet.ShouldProcess($backupRoot, "Back up and verify restore of $total selected file(s)")) {
                  $entry.Backup.Status = 'Skipped'; $entry.Action = 'BackupSkipped'
                } else {
                  if (-not (Get-Command New-GeneratedRemediationCustodyBundle -ErrorAction SilentlyContinue)) {
                    . (Join-Path $PSScriptRoot '../private/New-GeneratedRemediationCustodyBundle.ps1')
                  }
                  $backupReceipts = @(New-GeneratedRemediationCustodyBundle -RootPath $wtPath -BundleRoot $backupRoot -RelativePaths $backupPaths -AllowVerifiedCloudDirectoryMetadata:$AllowVerifiedCloudDirectoryMetadata -Confirm:$false -WhatIf:$false)
                  $entry.Backup.Receipt = $backupReceipts
                  if ($backupReceipts.Count -ne 1) { throw 'Expected exactly one backup receipt.' }
                  $backup = $backupReceipts[0]
                  $entry.Backup.Receipt = $backup
                  $entry.Backup.BundlePath = $backup.BundlePath
                  if ($backup.Status -ceq 'Skipped') {
                    $entry.Backup.Status = 'Skipped'; $entry.Action = 'BackupSkipped'
                  } elseif ($backup.Status -cne 'Verified') {
                    throw ('Backup held: ' + ($backup.Errors -join '; '))
                  } else {
                    $expectedClosure = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
                    foreach ($relative in $backupPaths) {
                      $cursor = $relative
                      while ($true) {
                        $null = $expectedClosure.Add($cursor)
                        if ($cursor -ceq '_generated') { break }
                        $cursor = $cursor.Substring(0, $cursor.LastIndexOf('/'))
                      }
                    }
                    $expectedProof = Join-Path $backupRoot 'recovery'
                    if ($backup.CoverageScope -cne 'SelectedFilesAndAncestors' -or -not $backup.BundleCreated -or
                      $backup.BundlePath -cne $backupRoot -or $backup.ProofRoot -cne $expectedProof -or
                      $backup.InitialCensus.Binding.Root -ine $wtPath -or $backup.FinalCensus.Binding.Root -ine $wtPath -or
                      $backup.ProofCensus.Binding.Root -ine $expectedProof -or @($backup.Errors).Count -ne 0 -or
                      $backup.ExpectedEntries -ne $expectedClosure.Count -or $backup.VerifiedEntries -ne $expectedClosure.Count -or
                      $backup.VerifiedPayloadBytes -ne $backup.PreflightPayloadBytes -or
                      $backup.SourceStreamVerification.Bytes -ne $backup.VerifiedPayloadBytes -or $backup.ProofStreamVerification.Bytes -ne $backup.VerifiedPayloadBytes -or
                      @($backup.RequestedRelativePaths).Count -ne $backupPaths.Count -or
                      @(Compare-Object $backupPaths @($backup.RequestedRelativePaths) -CaseSensitive).Count) { throw 'Backup receipt source/path/selection binding differs.' }
                    foreach ($coverage in @(
                      @{ Paths = @($backup.IncludedRelativePaths) },
                      @{ Paths = @($backup.Entries.RelativePath) },
                      @{ Paths = @($backup.SourceStreamVerification.Entries.RelativePath) },
                      @{ Paths = @($backup.ProofStreamVerification.Entries.RelativePath) }
                    )) {
                      if ($coverage.Paths.Count -ne $expectedClosure.Count -or
                        @(Compare-Object @($expectedClosure) $coverage.Paths -CaseSensitive).Count) { throw 'Backup receipt selected coverage differs.' }
                    }
                    if (@($backup.Entries | Where-Object { $_.Verified -ne $true }).Count) { throw 'Backup receipt has an unverified entry.' }
                    foreach ($flag in @('EntryProofCoverageComplete','CoherentTreeRestoreVerified','AggregateSourceBytesRechecked')) {
                      if ($backup.$flag -isnot [bool] -or -not $backup.$flag) { throw 'Backup receipt selected restore checks are incomplete.' }
                    }
                    foreach ($flag in @('Approved','ReadyForRemoval','CustodyVerified','RootStreamsVerified','DirectoryStreamsVerified')) {
                      if ($backup.$flag -isnot [bool] -or $backup.$flag) { throw 'Backup receipt has unsupported approval flags.' }
                    }
                    $entry.Backup.Status = 'Verified'; $entry.Action = 'BackedUp'; $entry.Archive = $backup.BundlePath
                  }
                }
              } catch {
                $entry.Backup.Status = 'Held'; $entry.Action = 'BackupHeld'
                $entry.Backup.Errors = @($_.Exception.Message)
                $errors.Add("[$($wt.Name)] backup held: $($_.Exception.Message)")
              }
            }
            $sprintResults.Add([pscustomobject]$entry)
            continue
          }
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
      Mode         = if ($CreateBackup) { 'Backup' } elseif ($Execute) { 'Execute' } else { 'Plan' }
      Timestamp    = $stamp
      Scope        = $Scope
      Stable       = $stableResults.ToArray()
      Sprint       = $sprintResults.ToArray()
      History      = $historyResults.ToArray()
      Errors       = $errors.ToArray()
    }

    if ($CreateBackup) {
      foreach ($flag in @('Approved','CustodyVerified','NamedStreamsVerified','ReadyForRemoval')) {
        $report | Add-Member -NotePropertyName $flag -NotePropertyValue $false
      }
    }
    if (-not [string]::IsNullOrWhiteSpace($EvidencePath)) {
      $dir = Split-Path -Parent $EvidencePath
      if ($dir -and -not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
      $reportDepth = if ($CreateBackup -or $useSelectionManifest) { 40 } else { 8 }
      $report | ConvertTo-Json -Depth $reportDepth | Set-Content -LiteralPath $EvidencePath -Encoding utf8
    }
    foreach ($e in $errors) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $e }
    $report
  }
}

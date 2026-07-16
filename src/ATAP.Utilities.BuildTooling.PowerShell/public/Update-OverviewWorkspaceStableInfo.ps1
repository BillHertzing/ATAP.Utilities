function Update-OverviewWorkspaceStableInfo {
  <#
  .SYNOPSIS
    Idempotently merges stable-branch workspace data into the root
    `Overview.code-workspace` at sprint end.
  .DESCRIPTION
    Called from SprintEndAgent (the counterpart of `New-OverviewSprintWorkspace`,
    which produces the sprint-specific `Overview.Sprint.NNNN.code-workspace` at
    sprint start). After a sprint's life, the *sprint* workspace is the freshest
    source of truth for repository folder layout and ProGet feed catalog, since
    new repos or new feeds may have been added during the sprint. This cmdlet
    folds those stable-branch-tracked items back into the root Overview workspace
    so the next sprint starts from a current baseline.

    The merge is deliberately narrow: only fields that describe permanent
    (non-sprint) state are propagated. Sprint-ephemeral fields produced by
    `New-OverviewSprintWorkspace` (`sprintEphemeral`, `generatedBy`,
    `generatedAt`) are explicitly stripped if they appear on the root.

    Merge rules:

      - `folders[]` — replaced by the canonical stable-folder list derived from
        the source workspace by stripping any `-wt-NNN-Sprint-NNNN-work-items`
        suffix from each folder path. Order from the source is preserved. Each
        derived folder is verified to exist under `-GitRoot`; missing folders
        are dropped (`PruneMissing` is the default) unless `-KeepMissing` is
        supplied.
      - `progetFeeds` — copied verbatim from the source workspace when present.
      - `settings.powershell.cwd` — set to the bare repo name of the stable
        `_Planning` folder (if discovered). All other `settings.*` entries are
        preserved unchanged.
      - `extensions` and any other unmodelled top-level keys — preserved
        unchanged on the root.
      - `sprintEphemeral` — removed if present on the root.

    Optional remote refresh:

      - `-Fetch` runs `git -C <stable-repo> fetch --quiet` for every stable
        repository folder before computing the merge. This is purely diagnostic
        (no checkout, no merge, no working-tree changes); per-repo failures are
        logged and aggregated into the returned object's `fetchErrors`.

    Idempotency:

      - The cmdlet computes the proposed JSON body, normalises it, compares it
        to the existing root file body, and skips the write entirely when the
        two are byte-identical. Re-running the cmdlet against an already-merged
        root workspace is therefore a true no-op (returns `WasChanged = $false`
        and writes nothing).

    Safety:

      - `[CmdletBinding(SupportsShouldProcess = $true)]`. `-WhatIf` returns the
        full result object describing the merge that *would* occur, without
        writing to disk.
      - When a write is performed, the previous root file (if present) is
        copied to `Overview.code-workspace.bak-<UTC-stamp>` next to it.
  .PARAMETER GitRoot
    Root directory containing the repository stable and sprint worktrees.
    Defaults to `C:\Dropbox\<USERNAME>\GitHub`.
  .PARAMETER RootWorkspacePath
    Path to the root Overview workspace file to update. Defaults to
    `<GitRoot>\Overview.code-workspace`, falling back to the legacy
    `<GitRoot>\OverView.code-workspace` if only that spelling exists. When the
    target does not yet exist, an empty workspace object is used as the seed.
  .PARAMETER SourceWorkspacePath
    Path to the sprint workspace whose stable-branch data should be merged in.
    Defaults to the most-recently modified `Overview.Sprint.*.code-workspace`
    under `-GitRoot`. Required (resolved or supplied) for the merge to run.
  .PARAMETER Fetch
    When set, runs `git fetch --quiet` for each discovered stable repository
    before computing the merge. Read-only; failures are reported in the
    returned object's `fetchErrors` array and do not abort the merge.
  .PARAMETER KeepMissing
    When set, retains derived stable folder entries even if the folder does
    not currently exist on disk under `-GitRoot`. Default behaviour drops them.
  .OUTPUTS
    [PSCustomObject] with fields:
      rootWorkspacePath    [string]   — absolute path of the (possibly updated) root workspace
      sourceWorkspacePath  [string]   — absolute path of the sprint workspace used as input
      wasChanged           [bool]     — whether the root file content would change
      changes              [string[]] — short descriptions of every detected delta
      stableFolders        [string[]] — canonical stable folder list applied
      progetFeedCount      [int]      — number of ProGet feeds propagated
      backupPath           [string]   — path of the .bak file written, or empty when no write occurred
      fetchErrors          [string[]] — per-repo `git fetch` failures (only populated when -Fetch is set)
      errors               [string[]] — non-fatal merge errors
  .EXAMPLE
    Update-OverviewWorkspaceStableInfo
    # Merges the latest sprint workspace's stable fields into Overview.code-workspace.
  .EXAMPLE
    Update-OverviewWorkspaceStableInfo -WhatIf
    # Computes the merge and returns the result object without writing.
  .EXAMPLE
    Update-OverviewWorkspaceStableInfo -Fetch -SourceWorkspacePath 'C:\Dropbox\user\GitHub\Overview.Sprint.0007.code-workspace'
    # Fetches each stable repo to surface remote drift, then merges from the named source.
  .NOTES
    Called from SprintEndAgent. Counterpart of `New-OverviewSprintWorkspace`
    (which runs at sprint start).
    AI assisted using ./claude/Rules/Powershell.md as guidelines.
  .LINK
    New-OverviewSprintWorkspace
  .LINK
    Save-SprintRetrospectiveSnapshot
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$GitRoot = "C:\Dropbox\$env:USERNAME\GitHub",

    [Parameter(Mandatory = $false)]
    [string]$RootWorkspacePath,

    [Parameter(Mandatory = $false)]
    [string]$SourceWorkspacePath,

    [Parameter(Mandatory = $false)]
    [switch]$Fetch,

    [Parameter(Mandatory = $false)]
    [switch]$KeepMissing
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    if (-not (Test-Path -LiteralPath $GitRoot -PathType Container)) {
      $msg = "GitRoot '$GitRoot' does not exist or is not a directory."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    if ([string]::IsNullOrWhiteSpace($RootWorkspacePath)) {
      $preferred = Join-Path -Path $GitRoot -ChildPath 'Overview.code-workspace'
      $legacy = Join-Path -Path $GitRoot -ChildPath 'OverView.code-workspace'
      if (Test-Path -LiteralPath $preferred -PathType Leaf) {
        $RootWorkspacePath = $preferred
      } elseif (Test-Path -LiteralPath $legacy -PathType Leaf) {
        $RootWorkspacePath = $legacy
      } else {
        # No existing root - seed with the preferred spelling.
        $RootWorkspacePath = $preferred
      }
    }

    if ([string]::IsNullOrWhiteSpace($SourceWorkspacePath)) {
      $workspaceFiles = @()
      $workspaceFiles += Get-ChildItem -LiteralPath $GitRoot -File -Filter 'Overview.Sprint.*.code-workspace' -ErrorAction SilentlyContinue
      # Legacy compatibility only:
      $workspaceFiles += Get-ChildItem -LiteralPath $GitRoot -File -Filter 'Overview.Sprint*.code-workspace' -ErrorAction SilentlyContinue
      $workspaceFiles += Get-ChildItem -LiteralPath $GitRoot -File -Filter 'OverviewSprint*.code-workspace' -ErrorAction SilentlyContinue
      $workspaceFiles += Get-ChildItem -LiteralPath $GitRoot -File -Filter 'OverViewSprint*.code-workspace' -ErrorAction SilentlyContinue
      $candidates = @($workspaceFiles | Sort-Object -Property LastWriteTimeUtc -Descending)
      if ($candidates.Count -ge 1) {
        $SourceWorkspacePath = $candidates[0].FullName
      } else {
        $msg = "No sprint workspace (Overview.Sprint.*.code-workspace or a supported legacy spelling) found under '$GitRoot' and no -SourceWorkspacePath supplied."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }
    }

    if (-not (Test-Path -LiteralPath $SourceWorkspacePath -PathType Leaf)) {
      $msg = "Source sprint workspace file not found: '$SourceWorkspacePath'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "GitRoot=$GitRoot Root=$RootWorkspacePath Source=$SourceWorkspacePath Fetch=$Fetch KeepMissing=$KeepMissing"

    function Read-WorkspaceJsonContent {
      [CmdletBinding()]
      param([Parameter(Mandatory)] [string]$Path)
      $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
      # Most workspace files (including those written by New-OverviewSprintWorkspace)
      # are pure JSON. Real VS Code workspace files may carry `//`-style comments
      # and trailing commas - so fall back to a JSONC-tolerant strip only when
      # strict parsing fails. The strict-first pass avoids the URL-vs-comment
      # ambiguity (e.g. `"url": "http://..."`) inherent in naive `//.*$` regex.
      try {
        return $raw | ConvertFrom-Json -ErrorAction Stop
      } catch {
        # Strip whole-line `// ...` comments only (must be preceded by whitespace
        # or line start) plus trailing commas before `]` / `}`. Inline `//` inside
        # string values is left alone.
        $stripped = $raw -replace '(?m)^\s*//.*$', ''
        $stripped = $stripped -replace ',(\s*[\]}])', '$1'
        return $stripped | ConvertFrom-Json -ErrorAction Stop
      }
    }

    function Set-ObjectPropertyValue {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)] [object]$InputObject,
        [Parameter(Mandatory)] [string]$Name,
        [AllowNull()] [object]$Value
      )
      if ($InputObject.PSObject.Properties[$Name]) {
        $InputObject.$Name = $Value
      } else {
        Add-Member -InputObject $InputObject -MemberType NoteProperty -Name $Name -Value $Value
      }
    }

    function Remove-ObjectPropertyIfPresent {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)] [object]$InputObject,
        [Parameter(Mandatory)] [string]$Name
      )
      if ($InputObject.PSObject.Properties[$Name]) {
        $InputObject.PSObject.Properties.Remove($Name)
        return $true
      }
      return $false
    }

    function ConvertTo-StableFolderName {
      [CmdletBinding()]
      param([Parameter(Mandatory)] [string]$FolderPath)
      $leaf = Split-Path -Path ($FolderPath -replace '/', '\') -Leaf
      if ([string]::IsNullOrWhiteSpace($leaf)) { $leaf = $FolderPath }
      if ($leaf -match '^(?<Repo>.+)-wt-\d+-Sprint-\d{4}-work-items$') {
        return $Matches['Repo']
      }
      return $leaf
    }
  }

  process {
    $errors = [System.Collections.Generic.List[string]]::new()
    $changes = [System.Collections.Generic.List[string]]::new()
    $fetchErrors = [System.Collections.Generic.List[string]]::new()

    # ── 1. Load source (sprint) workspace ──────────────────────────────────
    try {
      $source = Read-WorkspaceJsonContent -Path $SourceWorkspacePath
    } catch {
      $msg = "Failed to parse source workspace '$SourceWorkspacePath': $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    # ── 2. Load root workspace (or seed empty) ─────────────────────────────
    $rootExists = Test-Path -LiteralPath $RootWorkspacePath -PathType Leaf
    if ($rootExists) {
      try {
        $root = Read-WorkspaceJsonContent -Path $RootWorkspacePath
      } catch {
        $msg = "Failed to parse root workspace '$RootWorkspacePath': $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }
    } else {
      [void]$changes.Add("Created new root workspace at $RootWorkspacePath")
      $root = [PSCustomObject]@{ folders = @(); settings = [PSCustomObject]@{} }
    }

    # ── 3. Derive canonical stable folder list from source ─────────────────
    $sourceFolders = @($source.folders)
    $derived = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($f in $sourceFolders) {
      $name = ConvertTo-StableFolderName -FolderPath ([string]$f.path)
      if ($seen.Add($name)) { [void]$derived.Add($name) }
    }

    # ── 4. Optional remote refresh on each stable repo (read-only) ─────────
    if ($Fetch) {
      foreach ($repo in $derived) {
        $repoPath = Join-Path -Path $GitRoot -ChildPath $repo
        if (-not (Test-Path -LiteralPath $repoPath -PathType Container)) { continue }
        if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git') )) { continue }
        try {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "git -C $repoPath fetch --quiet"
          $null = & git -C $repoPath fetch --quiet 2>&1
          if ($LASTEXITCODE -ne 0) {
            [void]$fetchErrors.Add("$repo (exit $LASTEXITCODE)")
          }
        } catch {
          [void]$fetchErrors.Add("$repo - $($_.Exception.Message)")
        }
      }
    }

    # ── 5. Filter missing folders (default) ────────────────────────────────
    $finalFolderNames = if ($KeepMissing) {
      $derived
    } else {
      @($derived | Where-Object { Test-Path -LiteralPath (Join-Path $GitRoot $_) -PathType Container })
    }
    $finalFolders = @($finalFolderNames | ForEach-Object { [PSCustomObject]@{ path = $_ } })

    # ── 6. Detect folder delta ─────────────────────────────────────────────
    $existingFolderNames = @()
    if ($root.PSObject.Properties['folders'] -and $null -ne $root.folders) {
      $existingFolderNames = @($root.folders | ForEach-Object { [string]$_.path })
    }
    $folderDelta = Compare-Object -ReferenceObject $existingFolderNames -DifferenceObject $finalFolderNames -SyncWindow 0
    if ($null -ne $folderDelta -and @($folderDelta).Count -gt 0) {
      foreach ($d in $folderDelta) {
        if ($d.SideIndicator -eq '<=') { [void]$changes.Add("folders: removed '$($d.InputObject)'") }
        elseif ($d.SideIndicator -eq '=>') { [void]$changes.Add("folders: added '$($d.InputObject)'") }
      }
    }
    Set-ObjectPropertyValue -InputObject $root -Name 'folders' -Value $finalFolders

    # ── 7. Merge progetFeeds verbatim ──────────────────────────────────────
    $progetFeedCount = 0
    if ($source.PSObject.Properties['progetFeeds'] -and $null -ne $source.progetFeeds) {
      $newFeeds = $source.progetFeeds
      $progetFeedCount = @($newFeeds).Count
      $existingFeedsJson = ''
      if ($root.PSObject.Properties['progetFeeds']) {
        $existingFeedsJson = ($root.progetFeeds | ConvertTo-Json -Depth 20 -Compress)
      }
      $newFeedsJson = ($newFeeds | ConvertTo-Json -Depth 20 -Compress)
      if ($existingFeedsJson -ne $newFeedsJson) {
        [void]$changes.Add("progetFeeds: refreshed ($progetFeedCount feed(s))")
      }
      Set-ObjectPropertyValue -InputObject $root -Name 'progetFeeds' -Value $newFeeds
    }

    # ── 8. Settings: preserve existing, only touch powershell.cwd ──────────
    if (-not $root.PSObject.Properties['settings'] -or $null -eq $root.settings) {
      Set-ObjectPropertyValue -InputObject $root -Name 'settings' -Value ([PSCustomObject]@{})
    }
    $planningStable = @($finalFolderNames | Where-Object { $_ -eq '_Planning' } | Select-Object -First 1)
    if ($planningStable.Count -gt 0) {
      $existingCwd = $null
      if ($root.settings.PSObject.Properties['powershell.cwd']) { $existingCwd = [string]$root.settings.'powershell.cwd' }
      if ($existingCwd -ne $planningStable[0]) {
        [void]$changes.Add("settings.powershell.cwd: '$existingCwd' -> '$($planningStable[0])'")
        Set-ObjectPropertyValue -InputObject $root.settings -Name 'powershell.cwd' -Value $planningStable[0]
      }
    }

    # ── 9. Strip sprint-ephemeral debris from root ─────────────────────────
    foreach ($ephemeralProp in @('sprintEphemeral', 'generatedBy', 'generatedAt')) {
      if (Remove-ObjectPropertyIfPresent -InputObject $root -Name $ephemeralProp) {
        [void]$changes.Add("removed sprint-ephemeral property '$ephemeralProp'")
      }
    }

    # ── 10. Render and compare for true idempotency ────────────────────────
    $newJson = ($root | ConvertTo-Json -Depth 30)
    $wasChanged = $true
    if ($rootExists) {
      $existingRaw = Get-Content -LiteralPath $RootWorkspacePath -Raw -ErrorAction SilentlyContinue
      if ($null -ne $existingRaw -and $existingRaw.Trim() -eq $newJson.Trim()) {
        $wasChanged = $false
        $changes.Clear()
      }
    }

    # ── 11. Persist (ShouldProcess + backup) ───────────────────────────────
    $backupPath = ''
    if ($wasChanged -and $PSCmdlet.ShouldProcess($RootWorkspacePath, 'Merge stable info into root Overview workspace')) {
      try {
        if ($rootExists) {
          $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
          $backupPath = "$RootWorkspacePath.bak-$stamp"
          Copy-Item -LiteralPath $RootWorkspacePath -Destination $backupPath -Force
        }
        Set-Content -LiteralPath $RootWorkspacePath -Value $newJson -Encoding UTF8
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Updated root Overview workspace: $RootWorkspacePath ($(@($changes).Count) change(s))"
      } catch {
        $msg = "Failed to write '$RootWorkspacePath': $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        [void]$errors.Add($msg)
      }
    } elseif (-not $wasChanged) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "No changes to apply - root workspace already in sync."
    }

    [PSCustomObject]@{
      rootWorkspacePath   = $RootWorkspacePath
      sourceWorkspacePath = $SourceWorkspacePath
      wasChanged          = $wasChanged
      changes             = $changes.ToArray()
      stableFolders       = $finalFolderNames
      progetFeedCount     = $progetFeedCount
      backupPath          = $backupPath
      fetchErrors         = $fetchErrors.ToArray()
      errors              = $errors.ToArray()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}

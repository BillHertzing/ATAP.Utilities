function Set-SprintBoundaryContext {
  <#
  .SYNOPSIS
    Orchestrates all sprint-boundary retargeting in a single call: machine links
    (junctions), SharedVSCode settings symlinks, and downstream workspace contexts.
  .DESCRIPTION
    A sprint worktree's pointers and links must point at the SharedVSCode *sprint*
    worktree while the sprint is active, and back at the *stable* SharedVSCode
    worktree once the sprint merges. Until now that retargeting was performed
    piecemeal across New-SprintStage1, New-SprintStage2, and several inline
    SprintStartAgent / SprintEndAgent steps. This cmdlet is the single, testable
    orchestrator that performs (or reverses) the full retarget for one or more
    sprint worktrees.

    SINGLE START ENTRY POINT (Task 12.2.b / SC-0236): this cmdlet is the ONLY
    code path that provisions a sprint worktree at the Start boundary. The
    per-worktree order is fixed and structurally enforced: junctions
    ('.vscode' only) -> downstream context -> full adapter materialization
    (Invoke-SprintAIAdapterLifecycle, all canonical domains). A junction
    failure skips the later steps for that worktree, so adapter rendering can
    never race ahead of junction setup. New-SprintStage1 and New-SprintStage2
    delegate their per-worktree provisioning here (with
    -SkipSharedVSCodeSettings and -SkipProfileSymlinks, because they handle
    those machine-global concerns themselves), and Initialize-SprintAIAdapters
    is a thin delegate over the same Invoke-SprintAIAdapterLifecycle code path.

    It covers the original five V4-H03 concerns plus the AI adapter lifecycle:

      - machine links (NTFS junctions) ........ Set-WorktreeJunctions (per worktree)
      - SharedVSCode settings ................. Set-UserSettingsSymlink + Set-ClaudeSettingsSymlink (once)
      - downstream contexts ................... Initialize-DownstreamSprintFromSharedVSCode (Start)
                                                / Reset-DownstreamToSharedVSCodeMain (End) (per worktree)
      - canonical AI adapters ................. Invoke-SprintAIAdapterLifecycle (per worktree)
      - PowerShell 7 profile + HostSettings ... Set-PowerShell7ProfileSymlink (once)
      - ConfigRootKeys ........................ in-process bootstrap, no symlink

    The machine-wide PowerShell 7 profile payload and HostSettings link are NOT
    stable-by-design: the payload is copied from the selected ATAP.IAC stable or sprint
    worktree, and HostSettings tracks the same boundary (H09/SC-0188, Task 10.13).
    This concern delegates to Set-PowerShell7ProfileSymlink, which also
    removes the now-obsolete global_ConfigRootKeys.ps1 and global_environmentVariables.ps1
    symlinks. ConfigRootKeys remain genuinely stable-by-design: they are bootstrapped
    in-process by Initialize-ATAPConfigurationGlobals (Task 10.5) rather than dot-sourced
    from a worktree symlink, so there is nothing to retarget.

    Every worker is invoked under the cmdlet's own ShouldProcess, so -WhatIf
    previews the full retarget without mutating anything.
  .PARAMETER Boundary
    'Start' retargets the supplied worktrees and the machine settings symlinks to
    the SharedVSCode sprint worktree. 'End' retargets them back to the stable
    SharedVSCode worktree.
  .PARAMETER WorktreePaths
    Zero or more downstream sprint worktree paths to retarget (junctions and
    downstream context). Each is expected to contain at least one
    *.code-workspace file. Omit to perform settings-symlink retargeting only.
  .PARAMETER SharedVSCodeWorktreePath
    On 'Start', the SharedVSCode sprint worktree (junction dev-redirect target and
    settings-symlink source). On 'End', the stable SharedVSCode worktree path.
  .PARAMETER TemplateRef
    'Start' only. The SharedVSCode sprint worktree reference written into each
    downstream workspace context (for example
    'SharedVSCode-wt-42-Sprint-0007-work-items'). Defaults to the leaf name of
    SharedVSCodeWorktreePath.
  .PARAMETER Profile
    'Start' only. Profile label applied to each downstream workspace context.
    Defaults to 'default'.
  .PARAMETER JunctionFolderNames
    Names of junction folders whose targets are dev-redirected to the SharedVSCode
    sprint worktree on 'Start'. Ignored on 'End' (junctions follow the stable repo).
    Defaults to '.vscode' only: `.claude`/`.github` are concrete, canonical-rendered
    directories in every repo (SC-0231 decision) and must never be junctioned, even
    for dev-redirect purposes, so they are excluded from this default.
  .PARAMETER StableJunctionFolderNames
    Names of source-repository junction folders that SprintEnd is allowed to
    recreate from the stable repo. Defaults to '.vscode' so obsolete rendered
    `.claude` / `.github` folders are not recreated as junctions during close.
  .PARAMETER GitRoot
    Root directory containing all Git repositories. Used to derive each worktree's
    stable repo path (junction source). Defaults to 'C:\dropbox\whertzing\GitHub'.
  .PARAMETER SharedVSCodeRepoName
    Name of the SharedVSCode repository folder. Passed through to the downstream
    context workers.
  .PARAMETER SharedHooksSubPath
    Relative path under the SharedVSCode root where hooks live. Passed through to
    the downstream context workers.
  .PARAMETER CommitTemplateRelativePath
    Relative path under the SharedVSCode root for the commit template. Passed
    through to the downstream context workers.
  .PARAMETER SkipAIAdapterLifecycle
    Skip project-scope AI adapter materialization/audit. Intended only for
    narrowly scoped repair or diagnostic calls.
  .PARAMETER ATAPUtilitiesRoot
    Repository or worktree root that owns the profile.ps1 symlink target. Defaults
    to the ATAP.Utilities sprint worktree (from WorktreePaths) on Start and the
    stable '<GitRoot>\ATAP.Utilities' on End.
  .PARAMETER ATAPIACRoot
    Repository or worktree root that owns the HostSettings.ps1 symlink target.
    Defaults to the ATAP.IAC sprint worktree (when one exists) on Start and the
    stable '<GitRoot>\ATAP.IAC' on End.
  .PARAMETER SkipProfileSymlinks
    Skip the machine-wide PowerShell 7 profile-symlink retarget concern. Intended
    only for narrowly scoped repair or diagnostic calls.
  .PARAMETER SkipSharedVSCodeSettings
    Skip the machine-global SharedVSCode settings concern (shared-settings
    render, Set-UserSettingsSymlink, Set-ClaudeSettingsSymlink). Used by
    New-SprintStage1/New-SprintStage2 which orchestrate those machine-global
    concerns once per stage while delegating per-worktree provisioning here
    (Task 12.2.b).
  .PARAMETER AllowUserGlobalWrite
    Permit this boundary operation to update user-global settings files such as
    ~/.claude/settings.json.
  .PARAMETER CheckpointConfirmed
    Confirms the sprint session has been checkpointed before user-global settings
    files are updated.
  .PARAMETER PrimaryRoleSharedStatePath
    Optional explicit Dropbox-synchronized ParityState folder for the canonical
    PrimaryRole.json marker. Defaults to the ATAP\ParityState folder beside the
    GitHub folder under the Dropbox account root.
  .OUTPUTS
    PSCustomObject with Boundary, DryRun, a per-concern Concerns array, a
    PerWorktree breakdown, and an aggregate Errors array.
  .EXAMPLE
    # Sprint start — retarget every sprint worktree to the SharedVSCode sprint worktree
    Set-SprintBoundaryContext -Boundary Start `
      -WorktreePaths $worktrees.FullName `
      -SharedVSCodeWorktreePath 'C:\Dropbox\whertzing\GitHub\SharedVSCode-wt-42-Sprint-0007-work-items'
  .EXAMPLE
    # Sprint end — retarget everything back to stable SharedVSCode
    Set-SprintBoundaryContext -Boundary End `
      -WorktreePaths $worktrees.FullName `
      -SharedVSCodeWorktreePath 'C:\Dropbox\whertzing\GitHub\SharedVSCode'
  .NOTES
    AI assisted using ./.claude/Rules/Powershell.md as guidelines.
    Completes V4-H03 (Sprint 0007). See
    SolutionDocumentation/Sprint-Boundary-Retargeting.md.
  .LINK
    Set-WorktreeJunctions
  .LINK
    Initialize-DownstreamSprintFromSharedVSCode
  .LINK
    Reset-DownstreamToSharedVSCodeMain
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('Start', 'End')]
    [string]$Boundary,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SharedVSCodeWorktreePath,

    [string[]]$WorktreePaths = @(),

    [string]$TemplateRef,

    [string]$Profile = 'default',

    [string[]]$JunctionFolderNames = @('.vscode'),

    [string[]]$StableJunctionFolderNames = @('.vscode'),

    [string]$GitRoot = 'C:\dropbox\whertzing\GitHub',

    [string]$SharedVSCodeRepoName = 'SharedVSCode',

    [string]$SharedHooksSubPath = '.githooks',

    [string]$CommitTemplateRelativePath = 'GitTemplates\git.commit.template.txt',

    [string]$ATAPUtilitiesRoot,

    [string]$ATAPIACRoot,

    [switch]$SkipProfileSymlinks,

    [switch]$SkipSharedVSCodeSettings,

    [switch]$AllowUserGlobalWrite,

    [switch]$CheckpointConfirmed,

    [string]$PrimaryRoleSharedStatePath,

    [Alias('SkipAISettingsLifecycle')]
    [switch]$SkipAIAdapterLifecycle
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn (Boundary=$Boundary)"

    # When the file is dot-sourced from source (no module import), the private
    # settings-symlink helpers are not yet defined. Load them on demand.
    foreach ($privateHelperName in @('Set-ClaudeSettingsSymlink', 'Set-UserSettingsSymlink')) {
      if (-not (Get-Command -Name $privateHelperName -CommandType Function -ErrorAction SilentlyContinue)) {
        $privateHelperPath = Join-Path $PSScriptRoot '..' 'private' "$privateHelperName.ps1"
        if (Test-Path -LiteralPath $privateHelperPath) {
          . $privateHelperPath
        }
      }
    }

    if (-not $PSBoundParameters.ContainsKey('TemplateRef') -or [string]::IsNullOrWhiteSpace($TemplateRef)) {
      $TemplateRef = Split-Path $SharedVSCodeWorktreePath -Leaf
    }

    $concerns = [System.Collections.Generic.List[object]]::new()
    $perWorktree = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[string]]::new()
  }

  process {
    # ------------------------------------------------------------------
    # Per-worktree concerns: machine links (junctions) + downstream context
    # ------------------------------------------------------------------
    $junctionsOk = $true
    $contextOk = $true
    $adapterLifecycleOk = $true

    foreach ($worktreePath in $WorktreePaths) {
      $wtEntry = [ordered]@{
        WorktreePath        = $worktreePath
        StableRepoPath      = $null
        JunctionsRetargeted  = $false
        ContextRetargeted    = $false
        AISettingsProcessed  = $false
        AISettingsDriftClean = $null
        # Granular per-concern errors (Task 12.2.b) so delegating callers
        # (New-SprintStage1/New-SprintStage2) can map severities without
        # parsing the aggregate Error string.
        JunctionError        = $null
        ContextError         = $null
        AdapterError         = $null
        Error                = $null
      }

      if (-not (Test-Path -LiteralPath $worktreePath -PathType Container)) {
        $wtEntry.Error = "Worktree path not found: '$worktreePath'"
        $errors.Add($wtEntry.Error)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $wtEntry.Error
        $perWorktree.Add([PSCustomObject]$wtEntry)
        $junctionsOk = $false
        $contextOk = $false
        continue
      }

      # Derive the stable repo path (junction source) by stripping the sprint suffix.
      $repoName = (Split-Path $worktreePath -Leaf) -replace '-wt-\d+-[Ss]print-\d+-work-items$', ''
      $stableRepoPath = Join-Path $GitRoot $repoName
      $wtEntry.StableRepoPath = $stableRepoPath

      # CP06-D02 (Sprint 0012 close incident, Task 13.20.a): refuse to treat a
      # stable repository root as if it were a sprint worktree. This happens
      # when a caller (or a stale post-deletion disk rescan) substitutes a
      # stable path into WorktreePaths -- the worktree leaf then has no
      # '-wt-<n>-Sprint-<nnnn>-work-items' suffix to strip, so the derived
      # "stable" path and the supplied "worktree" path are identical. Previously
      # this was only caught deep inside Set-WorktreeJunctions, which surfaced
      # as an opaque failure after other retargeting had already started. Reject
      # it here, before any external helper is invoked, with an unambiguous
      # message that names the offending path.
      $normalizedWorktreePath = ([IO.Path]::GetFullPath($worktreePath)).TrimEnd('\')
      $normalizedStableRepoPath = ([IO.Path]::GetFullPath($stableRepoPath)).TrimEnd('\')
      if ([StringComparer]::OrdinalIgnoreCase.Equals($normalizedWorktreePath, $normalizedStableRepoPath)) {
        $samePathError = "Refusing to retarget junctions for '$worktreePath': the derived stable repository path is identical to the supplied worktree path. This is a stable repository root, not a sprint worktree -- pass the actual sprint worktree path (its leaf name must match '-wt-<n>-Sprint-<nnnn>-work-items')."
        $wtEntry.JunctionError = $samePathError
        $wtEntry.Error = $samePathError
        $errors.Add($samePathError)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $samePathError
        $perWorktree.Add([PSCustomObject]$wtEntry)
        $junctionsOk = $false
        $contextOk = $false
        continue
      }

      # SprintEnd must pass adapter drift review before any junction or downstream
      # context teardown occurs. A failed audit leaves the worktree pointed at its
      # sprint sources so promote/regenerate review can be completed safely.
      if ($Boundary -eq 'End' -and -not $SkipAIAdapterLifecycle) {
        try {
          if ($PSCmdlet.ShouldProcess($worktreePath, 'Audit canonical AI adapter drift before teardown')) {
            $adapterLifecycleResult = Invoke-SprintAIAdapterLifecycle `
              -Boundary End `
              -TargetRoot $worktreePath `
              -SharedVSCodeWorktreePath $SharedVSCodeWorktreePath `
              -Confirm:$false
            $wtEntry.AISettingsProcessed = $true
            $wtEntry.AISettingsDriftClean = $adapterLifecycleResult.DriftClean
            if (-not $adapterLifecycleResult.DriftClean) {
              throw 'AI adapter drift requires promote-or-regenerate review before retarget.'
            }
          }
        } catch {
          $adapterLifecycleOk = $false
          $adapterError = "AI adapter lifecycle failed for '$worktreePath': $($_.Exception.Message)"
          $wtEntry.AdapterError = $adapterError
          $wtEntry.Error = $adapterError
          $errors.Add($adapterError)
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $adapterError
          $perWorktree.Add([PSCustomObject]$wtEntry)
          continue
        }
      }

      # --- machine links (junctions) ---
      try {
        if (-not (Test-Path -LiteralPath $stableRepoPath -PathType Container)) {
          throw "Stable repo path not found: '$stableRepoPath'"
        }
        if ($PSCmdlet.ShouldProcess($worktreePath, "Retarget junctions ($Boundary)")) {
          $junctionParams = @{
            SourceRepoPath = $stableRepoPath
            WorktreePath   = $worktreePath
          }
          if ($Boundary -eq 'Start') {
            # Dev-redirect the junction folders (default '.vscode' only) to the
            # SharedVSCode sprint worktree. `.claude`/`.github` are concrete,
            # canonical-rendered directories (SC-0231) and are intentionally excluded
            # from $JunctionFolderNames so they are never dev-redirected as junctions.
            # SC-0236: also restrict the SOURCE SCAN itself to $JunctionFolderNames —
            # DevSourceRepoFolderNames only controls which recreated junctions get
            # redirected, not which ones are scanned/recreated in the first place. If
            # the stable repo still has `.claude`/`.github` as junctions, an unfiltered
            # scan would recreate them in the new sprint worktree regardless.
            $junctionParams.DevSourceRepoPath        = $SharedVSCodeWorktreePath
            $junctionParams.DevSourceRepoFolderNames = $JunctionFolderNames
            $junctionParams.SourceRepoFolderNames    = $JunctionFolderNames
          } else {
            $junctionParams.SourceRepoFolderNames = $StableJunctionFolderNames
          }
          $junctionResult = Set-WorktreeJunctions @junctionParams
          if ($junctionResult.Success) {
            $wtEntry.JunctionsRetargeted = $true
          } else {
            throw "Set-WorktreeJunctions reported errors: $($junctionResult.Errors -join '; ')"
          }
        }
      } catch {
        $junctionsOk = $false
        $wtEntry.JunctionError = "Junction retarget failed for '$worktreePath': $($_.Exception.Message)"
        $wtEntry.Error = $wtEntry.JunctionError
        $errors.Add($wtEntry.Error)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $wtEntry.Error
        $perWorktree.Add([PSCustomObject]$wtEntry)
        continue
      }

      # --- downstream context ---
      try {
        $workspaceFiles = @(Get-ChildItem -Path $worktreePath -Filter '*.code-workspace' -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName)

        if ($workspaceFiles.Count -eq 0) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "No .code-workspace files found in '$worktreePath'; skipping downstream context"
        } elseif ($PSCmdlet.ShouldProcess($worktreePath, "Retarget downstream context ($Boundary)")) {
          if ($Boundary -eq 'Start') {
            Initialize-DownstreamSprintFromSharedVSCode `
              -WorkspaceFiles $workspaceFiles `
              -TemplateRef $TemplateRef `
              -Profile $Profile `
              -GitRoot $GitRoot `
              -SharedVSCodeRepoName $SharedVSCodeRepoName `
              -SharedHooksSubPath $SharedHooksSubPath `
              -CommitTemplateRelativePath $CommitTemplateRelativePath
          } else {
            Reset-DownstreamToSharedVSCodeMain `
              -WorkspaceFiles $workspaceFiles `
              -GitRoot $GitRoot `
              -SharedVSCodeRepoName $SharedVSCodeRepoName `
              -SharedHooksSubPath $SharedHooksSubPath `
              -CommitTemplateRelativePath $CommitTemplateRelativePath
          }
          $wtEntry.ContextRetargeted = $true
        }
      } catch {
        $contextOk = $false
        $wtEntry.ContextError = "Downstream context retarget failed for '$worktreePath': $($_.Exception.Message)"
        $wtEntry.Error = $wtEntry.ContextError
        $errors.Add($wtEntry.Error)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $wtEntry.Error
      }

      # SprintStart materializes canonical project adapters after the worktree
      # links and downstream context point at the sprint SharedVSCode source.
      if ($Boundary -eq 'Start') {
        try {
          if (-not $SkipAIAdapterLifecycle -and $PSCmdlet.ShouldProcess($worktreePath, 'Start canonical AI adapter lifecycle')) {
            $adapterLifecycleResult = Invoke-SprintAIAdapterLifecycle `
              -Boundary Start `
              -TargetRoot $worktreePath `
              -SharedVSCodeWorktreePath $SharedVSCodeWorktreePath `
              -Confirm:$false
            $wtEntry.AISettingsProcessed = $true
            $wtEntry.AISettingsDriftClean = $adapterLifecycleResult.DriftClean
          }
        } catch {
          $adapterLifecycleOk = $false
          $adapterError = "AI adapter lifecycle failed for '$worktreePath': $($_.Exception.Message)"
          $wtEntry.AdapterError = $adapterError
          $wtEntry.Error = @($wtEntry.Error, $adapterError) | Where-Object { $_ } | Join-String -Separator '; '
          $errors.Add($adapterError)
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $adapterError
        }
      }

      $perWorktree.Add([PSCustomObject]$wtEntry)
    }

    if ($WorktreePaths.Count -gt 0) {
      $concerns.Add([PSCustomObject]@{
          Concern        = 'MachineLinks'
          Action         = "Set-WorktreeJunctions x$($WorktreePaths.Count)"
          StableByDesign = $false
          Succeeded      = $junctionsOk
          Error          = $null
        })
      $concerns.Add([PSCustomObject]@{
          Concern        = 'DownstreamContexts'
          Action         = ($Boundary -eq 'Start' ? 'Initialize-DownstreamSprintFromSharedVSCode' : 'Reset-DownstreamToSharedVSCodeMain')
          StableByDesign = $false
          Succeeded      = $contextOk
          Error          = $null
        })
      $concerns.Add([PSCustomObject]@{
          Concern        = 'AIAdapterLifecycle'
          Action         = ($Boundary -eq 'Start' ? 'Materialize project adapters' : 'Retarget-or-promote adapter drift audit')
          StableByDesign = $false
          Succeeded      = $adapterLifecycleOk
          Error          = $null
        })
    }

    # ------------------------------------------------------------------
    # Machine-global concern: SharedVSCode settings symlinks (once)
    # ------------------------------------------------------------------
    $settingsOk = $true
    $settingsError = $null
    try {
      if (-not $SkipSharedVSCodeSettings -and $PSCmdlet.ShouldProcess($SharedVSCodeWorktreePath, "Retarget SharedVSCode settings symlinks ($Boundary)")) {
        $sharedSettingsRenderParameters = @{
          Boundary = 'Start'
          TargetRoot = $SharedVSCodeWorktreePath
          SharedVSCodeWorktreePath = $SharedVSCodeWorktreePath
          Confirm = $false
          WhatIf = $WhatIfPreference
          AllowUserGlobalWrite = $AllowUserGlobalWrite
          CheckpointConfirmed = $CheckpointConfirmed
        }
        if ($Boundary -eq 'End') {
          $sharedSettingsRenderParameters.OmitSprintWorktrees = $true
        }
        Invoke-SprintAIAdapterLifecycle @sharedSettingsRenderParameters | Out-Null
        Set-UserSettingsSymlink -SharedVSCodeWorktreePath $SharedVSCodeWorktreePath
        Set-ClaudeSettingsSymlink `
          -SharedVSCodeWorktreePath $SharedVSCodeWorktreePath `
          -AllowUserGlobalWrite:$AllowUserGlobalWrite `
          -CheckpointConfirmed:$CheckpointConfirmed
      }
    } catch {
      $settingsOk = $false
      $settingsError = "Settings symlink retarget failed: $($_.Exception.Message)"
      $errors.Add($settingsError)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $settingsError
    }
    $concerns.Add([PSCustomObject]@{
        Concern        = 'SharedVSCodeSettings'
        Action         = ($SkipSharedVSCodeSettings ? 'Skipped' : 'Invoke-SprintAIAdapterLifecycle (render shared settings) + Set-UserSettingsSymlink + Set-ClaudeSettingsSymlink')
        StableByDesign = $false
        Succeeded      = $settingsOk
        Error          = $settingsError
      })

    # ------------------------------------------------------------------
    # Machine-global concern: PowerShell 7 profile deployment and HostSettings link (once)
    # profile.ps1 is copied from ATAP.IAC; HostSettings.ps1 links to ATAP.IAC. Formerly
    # 'stable-by-design / no-op'; now actively retargeted per H09/SC-0188 (Task
    # 10.13). The worker also removes the obsolete global_ConfigRootKeys.ps1 and
    # global_environmentVariables.ps1 symlinks.
    # ------------------------------------------------------------------
    $profileSymlinksOk = $true
    $profileSymlinksError = $null
    if (-not $SkipProfileSymlinks) {
      try {
        # Resolve the repo roots used by the compatibility cmdlet. Start tracks the
        # sprint worktrees; End resets to the stable repositories under GitRoot.
        if (-not $PSBoundParameters.ContainsKey('ATAPUtilitiesRoot') -or [string]::IsNullOrWhiteSpace($ATAPUtilitiesRoot)) {
          if ($Boundary -eq 'Start') {
            $utilMatch = @($WorktreePaths | Where-Object { (Split-Path $_ -Leaf) -match '^ATAP\.Utilities-wt-' })
            $ATAPUtilitiesRoot = if ($utilMatch.Count -gt 0) { $utilMatch[0] } else { Join-Path $GitRoot 'ATAP.Utilities' }
          } else {
            $ATAPUtilitiesRoot = Join-Path $GitRoot 'ATAP.Utilities'
          }
        }
        if (-not $PSBoundParameters.ContainsKey('ATAPIACRoot') -or [string]::IsNullOrWhiteSpace($ATAPIACRoot)) {
          if ($Boundary -eq 'Start') {
            $iacMatch = @($WorktreePaths | Where-Object { (Split-Path $_ -Leaf) -match '^ATAP\.IAC-wt-' })
            if ($iacMatch.Count -eq 0) {
              $iacMatch = @(Get-ChildItem -Path $GitRoot -Directory -Filter 'ATAP.IAC-wt-*' -ErrorAction SilentlyContinue |
                  Sort-Object Name | Select-Object -Last 1 -ExpandProperty FullName)
            }
            $ATAPIACRoot = if ($iacMatch.Count -gt 0) { $iacMatch[0] } else { Join-Path $GitRoot 'ATAP.IAC' }
          } else {
            $ATAPIACRoot = Join-Path $GitRoot 'ATAP.IAC'
          }
        }

        if ($PSCmdlet.ShouldProcess($ATAPUtilitiesRoot, "Deploy PowerShell 7 profile and retarget HostSettings ($Boundary)")) {
          $profileSymlinkResult = Set-PowerShell7ProfileSymlink `
            -ATAPUtilitiesRoot $ATAPUtilitiesRoot `
            -ATAPIACRoot $ATAPIACRoot `
            -Confirm:$false
          if (-not $profileSymlinkResult.Ok) {
            $profileSymlinksOk = $false
            $profileSymlinksError = "Profile symlink retarget reported failures: $($profileSymlinkResult.Failures -join '; ')"
            $errors.Add($profileSymlinksError)
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $profileSymlinksError
          }
        }
      } catch {
        $profileSymlinksOk = $false
        $profileSymlinksError = "Profile symlink retarget failed: $($_.Exception.Message)"
        $errors.Add($profileSymlinksError)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $profileSymlinksError
      }
    }
    $concerns.Add([PSCustomObject]@{
        Concern        = 'PowerShell7ProfileSymlinks'
        Action         = ($SkipProfileSymlinks ? 'Skipped' : "Set-PowerShell7ProfileSymlink ($Boundary)")
        StableByDesign = $false
        Succeeded      = $profileSymlinksOk
        Error          = $profileSymlinksError
      })

    # ------------------------------------------------------------------
    # User-profile concerns: developer and service-account profiles (once)
    # Each applicable identity receives Documents\PowerShell\profile.ps1 that
    # tracks the ATAP.Utilities sprint or stable profile source.
    # ------------------------------------------------------------------
    $developerProfilesOk = $true
    $developerProfilesError = $null
    $serviceProfilesOk = $true
    $serviceProfilesError = $null
    try {
      if (-not $SkipProfileSymlinks -and $PSCmdlet.ShouldProcess($ATAPUtilitiesRoot, "Retarget developer and service-account PowerShell profiles ($Boundary)")) {
        $userProfileResult = Set-SprintBoundaryUserProfiles `
          -ATAPUtilitiesRoot $ATAPUtilitiesRoot `
          -ATAPIACRoot $ATAPIACRoot `
          -GitRoot $GitRoot `
          -Confirm:$false `
          -WhatIf:$WhatIfPreference

        foreach ($warning in @($userProfileResult.Warnings)) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $warning
        }

        $developerFailures = @(
          $userProfileResult.Profiles |
            Where-Object { $_.Kind -eq 'Developer' -and -not $_.Succeeded }
        )
        $serviceFailures = @(
          $userProfileResult.Profiles |
            Where-Object { $_.Kind -eq 'ServiceAccount' -and -not $_.Succeeded }
        )

        if ($developerFailures.Count -gt 0) {
          $developerProfilesOk = $false
          $developerProfilesError = "Developer profile deployment reported failures: $((@($developerFailures.Error) | Where-Object { $_ }) -join '; ')"
          $errors.Add($developerProfilesError)
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $developerProfilesError
        }

        if ($serviceFailures.Count -gt 0) {
          $serviceProfilesOk = $false
          $serviceProfilesError = "Service-account profile deployment reported failures: $((@($serviceFailures.Error) | Where-Object { $_ }) -join '; ')"
          $errors.Add($serviceProfilesError)
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $serviceProfilesError
        }
      }
    } catch {
      $developerProfilesOk = $false
      $serviceProfilesOk = $false
      $developerProfilesError = "Managed user-profile deployment failed: $($_.Exception.Message)"
      $serviceProfilesError = $developerProfilesError
      $errors.Add($developerProfilesError)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $developerProfilesError
    }
    $concerns.Add([PSCustomObject]@{
        Concern        = 'DeveloperPowerShellProfiles'
        Action         = ($SkipProfileSymlinks ? 'Skipped' : "Set-SprintBoundaryUserProfiles ($Boundary)")
        StableByDesign = $false
        Succeeded      = $developerProfilesOk
        Error          = $developerProfilesError
      })
    $concerns.Add([PSCustomObject]@{
        Concern        = 'ServiceAccountPowerShellProfiles'
        Action         = ($SkipProfileSymlinks ? 'Skipped' : "Set-SprintBoundaryUserProfiles ($Boundary)")
        StableByDesign = $false
        Succeeded      = $serviceProfilesOk
        Error          = $serviceProfilesError
      })

    # ------------------------------------------------------------------
    # Local registration of the managed, profiled PowerShell 7 remoting
    # endpoint (SC-0267). This is a local-only, sibling step to the profile
    # deployment above -- it registers/refreshes the WithProfiles.pssc-defined
    # session configuration on THIS host so it reflects whichever profile
    # payloads Set-SprintBoundaryUserProfiles just deployed. Cross-host
    # registration on a peer (for example utat01 from utat022) is a separate,
    # explicit call to Register-ProfiledRemotingEndpoint -ComputerName -Credential,
    # not performed automatically at every boundary.
    # ------------------------------------------------------------------
    $profiledEndpointOk = $true
    $profiledEndpointError = $null
    try {
      if (-not $SkipProfileSymlinks) {
        if (-not (Get-Command -Name Register-ProfiledRemotingEndpoint -ErrorAction SilentlyContinue)) {
          $profiledEndpointError = 'Register-ProfiledRemotingEndpoint (ATAP.Utilities.PowerShell) is not available; skipping local endpoint registration.'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $profiledEndpointError
        } elseif ($PSCmdlet.ShouldProcess('local', "Register profiled PowerShell 7 remoting endpoint ($Boundary)")) {
          $endpointResult = Register-ProfiledRemotingEndpoint -Confirm:$false -WhatIf:$WhatIfPreference
          if (-not $endpointResult.Ok) {
            $profiledEndpointOk = $false
            $profiledEndpointError = "Profiled remoting endpoint registration reported failures: $($endpointResult.Failures -join '; ')"
            $errors.Add($profiledEndpointError)
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $profiledEndpointError
          }
        }
      }
    } catch {
      $profiledEndpointOk = $false
      $profiledEndpointError = "Profiled remoting endpoint registration failed: $($_.Exception.Message)"
      $errors.Add($profiledEndpointError)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $profiledEndpointError
    }
    $concerns.Add([PSCustomObject]@{
        Concern        = 'ProfiledRemotingEndpoint'
        Action         = ($SkipProfileSymlinks ? 'Skipped' : "Register-ProfiledRemotingEndpoint ($Boundary)")
        StableByDesign = $false
        Succeeded      = $profiledEndpointOk
        Error          = $profiledEndpointError
      })

    # ------------------------------------------------------------------
    # Stable operational concern: the single DPOM PrimaryRole.json marker
    # lives under Dropbox outside every Git worktree. Boundary processing
    # validates the shared marker and may migrate a lone legacy ProgramData
    # marker, but never rewrites role content or chooses between conflicts.
    # ------------------------------------------------------------------
    $primaryRoleMarkerOk = $true
    $primaryRoleMarkerError = $null
    $primaryRoleMarkerAction = 'NotProcessed'
    try {
      $primaryRoleTarget = if ([string]::IsNullOrWhiteSpace($PrimaryRoleSharedStatePath)) {
        Join-Path (Split-Path -Path ([IO.Path]::GetFullPath($GitRoot)) -Parent) 'ATAP\ParityState'
      } else {
        $PrimaryRoleSharedStatePath
      }
      if ($PSCmdlet.ShouldProcess($primaryRoleTarget, "Validate shared DPOM primary-role marker ($Boundary)")) {
        $primaryRoleParameters = @{
          Boundary = $Boundary
          GitRoot = $GitRoot
          Confirm = $false
          WhatIf = $WhatIfPreference
        }
        if (-not [string]::IsNullOrWhiteSpace($PrimaryRoleSharedStatePath)) {
          $primaryRoleParameters.SharedStatePath = $PrimaryRoleSharedStatePath
        }
        $primaryRoleResult = Sync-SprintBoundaryPrimaryRoleMarker @primaryRoleParameters
        $primaryRoleMarkerAction = $primaryRoleResult.Action
      } elseif ($WhatIfPreference) {
        $primaryRoleMarkerAction = 'WhatIf'
      }
    } catch {
      $primaryRoleMarkerOk = $false
      $primaryRoleMarkerError = "Shared DPOM primary-role marker validation failed: $($_.Exception.Message)"
      $errors.Add($primaryRoleMarkerError)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $primaryRoleMarkerError
    }
    $concerns.Add([PSCustomObject]@{
        Concern        = 'SharedPrimaryRoleMarker'
        Action         = $primaryRoleMarkerAction
        StableByDesign = $true
        Succeeded      = $primaryRoleMarkerOk
        Error          = $primaryRoleMarkerError
      })

    # ------------------------------------------------------------------
    # Stable-by-design concern: ConfigRootKeys
    # ------------------------------------------------------------------
    $concerns.Add([PSCustomObject]@{
        Concern        = 'ConfigRootKeys'
        Action         = 'None (in-process bootstrap via Initialize-ATAPConfigurationGlobals; legacy symlink removed by profile retarget)'
        StableByDesign = $true
        Succeeded      = $true
        Error          = $null
      })
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn ($($errors.Count) error(s))"
    [PSCustomObject]@{
      Boundary    = $Boundary
      DryRun      = [bool]$WhatIfPreference
      Concerns    = $concerns.ToArray()
      PerWorktree = $perWorktree.ToArray()
      Errors      = $errors.ToArray()
    }
  }
}

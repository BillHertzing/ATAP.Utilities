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

    It covers the original five V4-H03 concerns plus the AI adapter lifecycle:

      - machine links (NTFS junctions) ........ Set-WorktreeJunctions (per worktree)
      - SharedVSCode settings ................. Set-UserSettingsSymlink + Set-ClaudeSettingsSymlink (once)
      - downstream contexts ................... Initialize-DownstreamSprintFromSharedVSCode (Start)
                                                / Reset-DownstreamToSharedVSCodeMain (End) (per worktree)
      - canonical AI adapters ................. Invoke-SprintAIAdapterLifecycle (per worktree)
      - PowerShell 7 profile symlinks ......... Set-PowerShell7ProfileSymlink (once)
      - ConfigRootKeys ........................ in-process bootstrap, no symlink

    The machine-wide PowerShell 7 profile symlinks (profile.ps1 -> ATAP.Utilities,
    HostSettings.ps1 -> ATAP.IAC) are NOT stable-by-design: profile.ps1 is how the
    AllUsersAllHosts core profile detects the active stable-vs-sprint worktree, so it
    must track the sprint worktree at Start and reset to stable at End (H09/SC-0188,
    Task 10.13). This concern delegates to Set-PowerShell7ProfileSymlink, which also
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
    Defaults to '.claude', '.github', '.vscode'.
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

    [string[]]$JunctionFolderNames = @('.claude', '.github', '.vscode'),

    [string]$GitRoot = 'C:\dropbox\whertzing\GitHub',

    [string]$SharedVSCodeRepoName = 'SharedVSCode',

    [string]$SharedHooksSubPath = '.githooks',

    [string]$CommitTemplateRelativePath = 'GitTemplates\git.commit.template.txt',

    [string]$ATAPUtilitiesRoot,

    [string]$ATAPIACRoot,

    [switch]$SkipProfileSymlinks,

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
            # Dev-redirect .claude/.github/.vscode to the SharedVSCode sprint worktree.
            $junctionParams.DevSourceRepoPath        = $SharedVSCodeWorktreePath
            $junctionParams.DevSourceRepoFolderNames = $JunctionFolderNames
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
        $wtEntry.Error = "Junction retarget failed for '$worktreePath': $($_.Exception.Message)"
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
        $wtEntry.Error = "Downstream context retarget failed for '$worktreePath': $($_.Exception.Message)"
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
      if ($PSCmdlet.ShouldProcess($SharedVSCodeWorktreePath, "Retarget SharedVSCode settings symlinks ($Boundary)")) {
        Set-UserSettingsSymlink -SharedVSCodeWorktreePath $SharedVSCodeWorktreePath
        Set-ClaudeSettingsSymlink -SharedVSCodeWorktreePath $SharedVSCodeWorktreePath
      }
    } catch {
      $settingsOk = $false
      $settingsError = "Settings symlink retarget failed: $($_.Exception.Message)"
      $errors.Add($settingsError)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $settingsError
    }
    $concerns.Add([PSCustomObject]@{
        Concern        = 'SharedVSCodeSettings'
        Action         = 'Set-UserSettingsSymlink + Set-ClaudeSettingsSymlink'
        StableByDesign = $false
        Succeeded      = $settingsOk
        Error          = $settingsError
      })

    # ------------------------------------------------------------------
    # Machine-global concern: PowerShell 7 profile symlinks (once)
    # profile.ps1 -> ATAP.Utilities, HostSettings.ps1 -> ATAP.IAC. Formerly
    # 'stable-by-design / no-op'; now actively retargeted per H09/SC-0188 (Task
    # 10.13). The worker also removes the obsolete global_ConfigRootKeys.ps1 and
    # global_environmentVariables.ps1 symlinks.
    # ------------------------------------------------------------------
    $profileSymlinksOk = $true
    $profileSymlinksError = $null
    if (-not $SkipProfileSymlinks) {
      try {
        # Resolve the repo roots that own the two managed symlinks. Start tracks the
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

        if ($PSCmdlet.ShouldProcess($ATAPUtilitiesRoot, "Retarget PowerShell 7 profile symlinks ($Boundary)")) {
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

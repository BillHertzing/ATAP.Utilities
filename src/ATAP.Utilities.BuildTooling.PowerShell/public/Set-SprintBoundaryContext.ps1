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

    It covers the five concerns named in the V4-H03 acceptance criteria:

      - machine links (NTFS junctions) ........ Set-WorktreeJunctions (per worktree)
      - SharedVSCode settings ................. Set-UserSettingsSymlink + Set-ClaudeSettingsSymlink (once)
      - downstream contexts ................... Initialize-DownstreamSprintFromSharedVSCode (Start)
                                                / Reset-DownstreamToSharedVSCodeMain (End) (per worktree)
      - PowerShell profiles ................... stable-by-design, no per-sprint retarget
      - ConfigRootKeys ........................ stable-by-design, no per-sprint retarget

    PowerShell profiles load their ATAP modules from the stable repo path and
    PSModulePath, and ConfigRootKeys store host/user values (never worktree paths),
    so neither is retargeted at a sprint boundary. The cmdlet records both as an
    explicit StableByDesign no-op so the returned contract demonstrably covers all
    five concerns.

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

    [string]$CommitTemplateRelativePath = 'GitTemplates\git.commit.template.txt'
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

    foreach ($worktreePath in $WorktreePaths) {
      $wtEntry = [ordered]@{
        WorktreePath        = $worktreePath
        StableRepoPath      = $null
        JunctionsRetargeted = $false
        ContextRetargeted   = $false
        Error               = $null
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
    # Stable-by-design concerns: PowerShell profiles + ConfigRootKeys
    # ------------------------------------------------------------------
    $concerns.Add([PSCustomObject]@{
        Concern        = 'PowerShellProfiles'
        Action         = 'None (loads modules from stable repo path + PSModulePath)'
        StableByDesign = $true
        Succeeded      = $true
        Error          = $null
      })
    $concerns.Add([PSCustomObject]@{
        Concern        = 'ConfigRootKeys'
        Action         = 'None (store host/user values, no worktree paths)'
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

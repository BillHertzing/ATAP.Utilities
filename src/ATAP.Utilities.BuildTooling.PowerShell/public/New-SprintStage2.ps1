function New-SprintStage2 {
  <#
  .SYNOPSIS
    Creates downstream repo sprint branches, workTrees, NTFS junctions,
    applies SharedVSCode context, symlinks claude-settings.json, scaffolds
    BuildMaster sprint builds, and resets the sprint database in existing SQL
    Server instances. Sprint start does NOT create or delete any secrets
    (SC-0172). ProGet feeds are permanent and ecosystem-wide — not created per
    sprint.
  .DESCRIPTION
    Reads the sprint TASKS.md file and extracts every unique repository name
    mentioned in task lines (the [RepoName] markers). Repos named '_Planning',
    'SharedVSCode', and 'Cross-Repo' are excluded — Step 1 already handled the
    first two, and Cross-Repo is not an actual repository. The active HTML task
    board for humans is `TASKS.html` or the highest `TASKS_V*.html`; keep
    `TASKS.md` synchronized with that board until Stage 2 no longer depends on
    markdown parsing.

    For each discovered repo the cmdlet:
      1. Creates a GitHub issue via 'gh issue create'.
      2. Fetches and pulls main.
      3. Creates the sprint branch and worktree.
      4. Calls Set-WorktreeJunctions to create NTFS junctions pointing to the
         SharedVSCode sprint worktree.
      5. Calls Initialize-DownstreamSprintFromSharedVSCode to apply templateRef,
         hooksPath, and commitTemplate.

    After all repos are processed the cmdlet also:
      5c. Generates and verifies the Overview sprint workspace, then calls
          Build-AIInstructionsPerRepository once to distribute CLAUDE.md,
          AGENTS.md, GEMINI.md, and .github/copilot-instructions.md.
      6. Creates a symlink from the SharedVSCode sprint worktree's
         claude-settings.json to ~/.claude/settings.json.
      6b. Retargets the VS Code user settings symlink
          ($env:APPDATA\Code\User\settings.json) to point at UserSettings.jsonc
          in the SharedVSCode sprint worktree via Set-UserSettingsSymlink.
      7. Scaffolds BuildMaster sprint build configurations (DRAFT — see notes).
      8. (Removed, SC-0172) Sprint start no longer creates or deletes any
         Bitwarden secrets. Connection-string secrets are provisioned out of band.
      9. Resets the single ATAPUtilities database (which contains the
         ATAPUtilities, AceCommander, Tags and Gmail schemas — D-1) inside the
         existing local Dev<username> and Exp<username> SQL Server instances using
         the single Flyway migration set, via Reset-SprintDatabases. One reset per
         instance (2 total), not per schema.

    ProGet feeds are permanent and ecosystem-wide — they are NOT created per
    sprint. See New-ProGetFeedSet for one-time feed provisioning.

    If a step fails for a given repo, the error is captured in that repo's
    entry and the cmdlet continues with the next repo.
  .PARAMETER TasksFilePath
    Path to the TASKS.md file produced by sprint planning (Step 2).
    Defaults to the TASKS.md inside the _Planning sprint worktree whose
    path is provided via Stage1Result. This remains the legacy automation input;
    keep it synchronized with the active HTML board and companion task files.
  .PARAMETER Stage1Result
    The PSCustomObject returned by New-SprintStage1. Supplies the sprint
    number, SharedVSCode worktree path, and _Planning worktree path.
  .PARAMETER GitRoot
    Root directory containing all Git repositories.
  .PARAMETER Owner
    GitHub owner / organisation name.
  .PARAMETER JunctionFolderNames
    Folder names to junction from SharedVSCode into downstream repos.
    Defaults to @('.claude', '.github', '.vscode').
  .PARAMETER ExcludeRepos
    Repo names to skip even if they appear in TASKS.md.
    Defaults to @('_Planning', 'SharedVSCode', 'Cross-Repo').
  .PARAMETER IncludeRepos
    Additional repository names to provision even when they are not referenced
    by a task-board [RepoName] marker. ExcludeRepos still takes precedence.
  .PARAMETER SkipDatabaseReset
    Skips the Dev/Exp SQL Server instance preflight and the destructive
    Reset-SprintDatabases step. Intended for granular recovery of the remaining
    Stage 2 work after database readiness has been handled separately.
  .PARAMETER ProGetBaseUrl
    Base URL for the ProGet server.
    Defaults to 'http://localhost:50000'.
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server.
    Defaults to 'http://localhost:50017'.
  .PARAMETER DryRun
    Preview all sprint-start downstream actions without creating GitHub issues,
    branches, worktrees, junctions, SharedVSCode context, SQL Server database
    resets, BuildMaster variables, or claude-settings links. (Sprint start never
    creates or deletes secrets — SC-0172.)
  .OUTPUTS
    PSCustomObject — contains repoResults, infrastructure, and error fields.
  .EXAMPLE
    $stage2 = New-SprintStage2 -Stage1Result $stage1
    $stage2 | ConvertTo-Json -Depth 4
  .EXAMPLE
    $stage2 = New-SprintStage2 -Stage1Result $stage1 `
      -TasksFilePath 'C:\Dropbox\whertzing\GitHub\_Planning-wt-12-sprint-0006-work-items\TASKS.md'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    SprintStartAgent.md — Step 3
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [PSCustomObject]$Stage1Result,

    [string]$TasksFilePath,

    [string]$GitRoot,

    [string]$Owner,

    [string[]]$JunctionFolderNames = @('.claude', '.github', '.vscode'),

    [string[]]$ExcludeRepos = @('_Planning', 'SharedVSCode', 'Cross-Repo'),

    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string[]]$IncludeRepos = @(),

    [string]$ProGetBaseUrl,

    [string]$BuildMasterBaseUrl,

    [switch]$Force,

    [switch]$SkipDatabaseReset,

    [switch]$DryRun
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    if ($DryRun) {
      $WhatIfPreference = $true
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'DryRun enabled — no external side effects will be performed.'
    }

    # --- Resolve configuration via Get-PVal (FSS-03): param > env > settings >
    #     documented default. Get-PVal raises a loud-failure guard when no settings
    #     source is loaded (tests / no-profile shells), so each lookup is wrapped
    #     and degrades to the default rather than aborting sprint start.
    #     Task 10.2: the documented Owner default is read from
    #     OverView.code-workspace githubOwner (the file in the folder above the
    #     stable worktrees), falling back to $env:USERNAME only when that file or
    #     key is absent — so a no-Owner dry run resolves the real org owner. ---
    $getPValAvailable = [bool](Get-Command -Name 'Get-PVal' -ErrorAction SilentlyContinue)
    $proGetBaseUrlKey = if ($global:configRootKeys -and $global:configRootKeys['ProGetBaseUrlConfigRootKey']) {
      $global:configRootKeys['ProGetBaseUrlConfigRootKey']
    } else { 'ProGetBaseUrl' }
    $buildMasterBaseUrlKey = if ($global:configRootKeys -and $global:configRootKeys['BuildMasterBaseUrlConfigRootKey']) {
      $global:configRootKeys['BuildMasterBaseUrlConfigRootKey']
    } else { 'BuildMasterBaseUrl' }

    $gitRootDefault = 'C:\Dropbox\whertzing\GitHub'
    $gitRootForOwner = if (-not [string]::IsNullOrWhiteSpace($GitRoot)) { $GitRoot } else { $gitRootDefault }
    $ownerDefault = if (Get-Command -Name 'Get-GitHubOwnerFromWorkspace' -ErrorAction SilentlyContinue) {
      Get-GitHubOwnerFromWorkspace -GitRoot $gitRootForOwner -Fallback $env:USERNAME
    } else { $env:USERNAME }
    $proGetBaseUrlDefault = 'http://localhost:50000'
    $buildMasterBaseUrlDefault = 'http://localhost:50017'

    if ($getPValAvailable) {
      foreach ($spec in @(
          @{ Name = 'GitRoot'; Path = 'GitRoot'; Default = $gitRootDefault },
          @{ Name = 'Owner'; Path = 'GitHubOwner'; Default = $ownerDefault },
          @{ Name = 'ProGetBaseUrl'; Path = $proGetBaseUrlKey; Default = $proGetBaseUrlDefault },
          @{ Name = 'BuildMasterBaseUrl'; Path = $buildMasterBaseUrlKey; Default = $buildMasterBaseUrlDefault })) {
        # Highest-precedence source is an explicitly-bound parameter
        # (param > env > settings > default). Never let Get-PVal re-resolution
        # overwrite a value the caller passed in. Without this guard the
        # documented default silently clobbered a bound -GitRoot whenever
        # Get-PVal was loaded (profile/build env), which failed the
        # Development-tier promoted-module test gate. See SC-0203 / SC-0205.
        if ($PSBoundParameters.ContainsKey($spec.Name)) { continue }
        try {
          $resolvedSetting = Get-PVal -ParameterName $spec.Name `
            -originalPSBoundParameters $PSBoundParameters `
            -dottedPath $spec.Path -DefaultValue $spec.Default -AllowMissing
          Set-Variable -Name $spec.Name -Value $resolvedSetting
        } catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message "Get-PVal lookup for '$($spec.Name)' fell back to its default. Exception: $($_.Exception.Message)"
        }
      }
    }
    if ([string]::IsNullOrWhiteSpace($GitRoot)) { $GitRoot = $gitRootDefault }
    if ([string]::IsNullOrWhiteSpace($Owner)) { $Owner = $ownerDefault }
    if ([string]::IsNullOrWhiteSpace($ProGetBaseUrl)) { $ProGetBaseUrl = $proGetBaseUrlDefault }
    if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) { $BuildMasterBaseUrl = $buildMasterBaseUrlDefault }
    $ProGetBaseUrl = $ProGetBaseUrl.TrimEnd('/')
    $BuildMasterBaseUrl = $BuildMasterBaseUrl.TrimEnd('/')

    # Task 10.2: surface the resolved GitHub owner so a no-Owner dry run shows the
    # value read from OverView.code-workspace (e.g. 'BillHertzing') before any
    # gh issue create / ShouldProcess target string is evaluated.
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Resolved GitHub owner '$Owner' (no-Owner default sourced from OverView.code-workspace githubOwner)."

    # Autoload-or-throw contract (FSS-11): the BuildTooling module is CI-built and
    # installed, so every command this stage calls must resolve by module autoload
    # (public functions and the private helpers Set-ClaudeSettingsSymlink,
    # Set-UserSettingsSymlink, Get-SprintTaskRepositoryNames). A missing command is
    # an environment fault the user must repair — never a silent dot-source from a
    # worktree path.
    foreach ($required in @(
        'Set-ClaudeSettingsSymlink',
        'Set-UserSettingsSymlink',
        'Get-SprintTaskRepositoryNames',
        'Initialize-ATAPConfigurationGlobals',
        'Reset-SprintDatabases',
        'Set-WorktreeJunctions',
        'Initialize-DownstreamSprintFromSharedVSCode',
        'Initialize-SprintAIAdapters',
        'New-OverviewSprintWorkspace',
        'Build-AIInstructionsPerRepository')) {
      if (-not (Get-Command -Name $required -ErrorAction SilentlyContinue)) {
        throw "Required command '$required' is not available. The " +
        'ATAP.Utilities.BuildTooling.PowerShell module must be installed and ' +
        'autoloadable. Repair the module install before retrying sprint start.'
      }
    }

    # --- Validate Stage1Result has the fields we need ---
    $sprintNum = $Stage1Result.nextSprintNumber
    if ([string]::IsNullOrWhiteSpace($sprintNum)) {
      throw 'Stage1Result.nextSprintNumber is missing or empty.'
    }

    $svWorktreePath = $Stage1Result.sharedVSCode.worktreePath
    if ([string]::IsNullOrWhiteSpace($svWorktreePath)) {
      throw 'Stage1Result.sharedVSCode.worktreePath is missing or empty.'
    }

    $svIssueNum = $Stage1Result.sharedVSCode.issueNumber
    if ([string]::IsNullOrWhiteSpace($svIssueNum)) {
      $svBranchName = $Stage1Result.sharedVSCode.branchName
      if (-not [string]::IsNullOrWhiteSpace($svBranchName) -and $svBranchName -match '^(?<IssueNumber>\d+)-Sprint-\d{4}-work-items$') {
        $svIssueNum = $Matches['IssueNumber']
      }
    }
    if ([string]::IsNullOrWhiteSpace($svIssueNum)) {
      $svWorktreeLeaf = Split-Path -Path $svWorktreePath -Leaf
      if ($svWorktreeLeaf -match '^SharedVSCode-wt-(?<IssueNumber>\d+)-Sprint-\d{4}-work-items$') {
        $svIssueNum = $Matches['IssueNumber']
      }
    }
    if ([string]::IsNullOrWhiteSpace($svIssueNum)) {
      throw 'Stage1Result.sharedVSCode.issueNumber is missing and could not be derived from branchName or worktreePath.'
    }

    # --- Resolve TasksFilePath default ---
    if (-not $PSBoundParameters.ContainsKey('TasksFilePath')) {
      $planningWt = $Stage1Result.planning.worktreePath
      if ([string]::IsNullOrWhiteSpace($planningWt)) {
        throw 'Stage1Result.planning.worktreePath is missing and -TasksFilePath was not supplied.'
      }
      $currentTasksFilePath = Join-Path $planningWt "Tasks.Sprint$sprintNum.md"
      $legacyTasksFilePath = Join-Path $planningWt "TasksSprint$sprintNum.md"
      $TasksFilePath = if (Test-Path -LiteralPath $currentTasksFilePath -PathType Leaf) {
        $currentTasksFilePath
      } else {
        $legacyTasksFilePath
      }
    }

    if (-not (Test-Path -LiteralPath $TasksFilePath -PathType Leaf)) {
      throw "Sprint task markdown was not found at $TasksFilePath"
    }

    $planningWorktreePath = Split-Path -Path $TasksFilePath -Parent
    $currentTaskBoardPath = Join-Path $planningWorktreePath "Tasks.Sprint$sprintNum.html"
    $legacyTaskBoardPath = Join-Path $planningWorktreePath "TasksSprint$sprintNum.html"
    $activeTaskBoardPath = if (Test-Path -LiteralPath $currentTaskBoardPath -PathType Leaf) {
      $currentTaskBoardPath
    } else {
      $legacyTaskBoardPath
    }
    $versionedTaskBoards = @(
      @(Get-ChildItem -LiteralPath $planningWorktreePath -Filter "Tasks.Sprint${sprintNum}.V*.html" -File -ErrorAction SilentlyContinue)
      @(Get-ChildItem -LiteralPath $planningWorktreePath -Filter "TasksSprint${sprintNum}_V*.html" -File -ErrorAction SilentlyContinue)
    ) | Sort-Object Name -Descending
    if ($versionedTaskBoards.Count -gt 0) {
      $activeTaskBoardPath = $versionedTaskBoards[0].FullName
    }
    $accomplishedPath = Join-Path $planningWorktreePath "Tasks.Sprint$sprintNum.Accomplished.html"
    $proceduralDetailsPath = Join-Path $planningWorktreePath "Tasks.Sprint$sprintNum.ProceduralDetails.html"

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Stage 2 repository discovery reads '$([System.IO.Path]::GetFileName($TasksFilePath))' at '$TasksFilePath'. Keep it synchronized with the active task board '$activeTaskBoardPath' and companion files '$accomplishedPath' / '$proceduralDetailsPath'."

    # Task 10.5: agent shells do not reliably inherit the workstation profile.
    # Bootstrap the canonical ConfigRootKeys + host settings before Stage 2
    # reads any host-specific values. Prefer the current stable ATAP.Utilities
    # source here; after the sprint worktree is created, the DB reset explicitly
    # uses that newer worktree for SQL/Flyway content.
    if (-not $DryRun) {
      $configurationRepositoryRoot = Join-Path $GitRoot 'ATAP.Utilities'
      Initialize-ATAPConfigurationGlobals `
        -RepositoryRoot $configurationRepositoryRoot `
        -Confirm:$false | Out-Null
    }

    # Sprint start no longer creates SQL Server instances. Fail before creating
    # GitHub issues/worktrees if the permanent developer instances are missing.
    # Task 10.4: -SkipDatabaseReset bypasses this guard as well as the reset.
    if (-not $DryRun -and -not $SkipDatabaseReset) {
      $requiredSqlInstanceNames = @("Dev$($env:USERNAME)", "Exp$($env:USERNAME)")
      $missingSqlInstances = [System.Collections.Generic.List[string]]::new()

      foreach ($instanceName in $requiredSqlInstanceNames) {
        $serviceName = "MSSQL`$$instanceName"
        $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -eq $existingService) {
          [void]$missingSqlInstances.Add("$instanceName (service $serviceName)")
        }
      }

      if ($missingSqlInstances.Count -gt 0) {
        $onboardingCommand = 'Run the developer onboarding SQL Server instance setup for this workstation.'
        throw "New-SprintStage2 requires existing SQL Server instance(s): $($missingSqlInstances -join ', '). $onboardingCommand Stage 2 only resets databases; it never installs SQL Server instances."
      }
    }

    # --- Ensure external dependencies ---
    if (-not $DryRun) {
      Assert-GitAvailable

      if (-not (Get-Command -Name 'gh' -ErrorAction SilentlyContinue)) {
        throw 'The GitHub CLI (gh) is required but was not found on PATH.'
      }
    }
  }

  process {
    # ===================================================================
    # Parse TASKS.md to discover downstream repos
    # ===================================================================
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Parsing $TasksFilePath for repo references"

    $tasksContent = Get-Content -Path $TasksFilePath -ErrorAction Stop
    $discoveredRepoNames = @(Get-SprintTaskRepositoryNames -TasksContent $tasksContent -ExcludeRepos $ExcludeRepos)
    $repoNames = @(
      foreach ($candidate in (@($discoveredRepoNames) + @($IncludeRepos))) {
        if ($candidate -is [System.Collections.IEnumerable] -and $candidate -isnot [string]) {
          foreach ($nestedCandidate in $candidate) {
            [string]$nestedCandidate
          }
        } else {
          [string]$candidate
        }
      }
    ) | Where-Object {
      -not [string]::IsNullOrWhiteSpace($_) -and
      $ExcludeRepos -notcontains $_
    } | Select-Object -Unique

    if ($repoNames.Count -eq 0) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message 'No downstream repos found in TASKS.md — nothing to do'
      return @()
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Downstream repos detected: $($repoNames -join ', ')"

    # ===================================================================
    # Process each downstream repo
    # ===================================================================
    $repoResults = [System.Collections.ArrayList]::new()

    foreach ($repoName in $repoNames) {
      $entry = @{
        repoName         = $repoName
        issueNumber      = $null
        branchName       = $null
        worktreePath     = $null
        created          = $false
        dryRun           = $DryRun.IsPresent
        error            = $null
      }

      $repoPath = Join-Path $GitRoot $repoName

      # Verify the repo exists locally
      if (-not $DryRun -and -not (Test-Path (Join-Path $repoPath '.git'))) {
        $entry.error = "Local repo not found at $repoPath"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $entry.error
        [void]$repoResults.Add([PSCustomObject]$entry)
        continue
      }

      # --- 1. Create GitHub issue ---
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
          -Message "Creating GitHub issue for $repoName sprint $sprintNum"

        if ($PSCmdlet.ShouldProcess("$Owner/$repoName", "Create GitHub issue 'Sprint $sprintNum work items'")) {
          $ghOutput = gh issue create `
            --repo "$Owner/$repoName" `
            --title "Sprint $sprintNum work items" `
            --label 'sprint' `
            --body "Sprint $sprintNum work items for $repoName" 2>&1

          if ($LASTEXITCODE -ne 0) {
            throw "gh issue create failed (exit $LASTEXITCODE): $ghOutput"
          }

          if ($ghOutput -match '/issues/(\d+)') {
            $entry.issueNumber = [int]$Matches[1]
          } else {
            throw "Could not parse issue number from gh output: $ghOutput"
          }

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "$repoName issue #$($entry.issueNumber) created"
        }
      } catch {
        $entry.error = "Failed to create $repoName GitHub issue. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $entry.error
        [void]$repoResults.Add([PSCustomObject]$entry)
        continue
      }

      # --- 2. Fetch latest main ---
      if ($DryRun -and $null -eq $entry.issueNumber) {
        $entry.issueNumber = 'DRYRUN'
      }

      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
          -Message "Fetching and checking out $repoName main"

        if ($PSCmdlet.ShouldProcess($repoPath, 'git fetch/checkout/pull main')) {
          git -C $repoPath fetch origin 2>&1 | Out-Null
          git -C $repoPath checkout main 2>&1 | Out-Null
          git -C $repoPath pull origin main 2>&1 | Out-Null
        }
      } catch {
        $entry.error = "Failed to update $repoName main. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $entry.error
        [void]$repoResults.Add([PSCustomObject]$entry)
        continue
      }

      # --- 3. Create branch and worktree ---
      $issueNum = $entry.issueNumber
      $branchName = "$issueNum-Sprint-$sprintNum-work-items"
      $worktreePath = Join-Path $GitRoot "$repoName-wt-$issueNum-Sprint-$sprintNum-work-items"
      $entry.branchName = $branchName
      $entry.worktreePath = $worktreePath

      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
          -Message "Creating $repoName worktree at $worktreePath on branch $branchName"

        if ($PSCmdlet.ShouldProcess($worktreePath, "git worktree add -b $branchName")) {
          $wtOutput = git -C $repoPath worktree add $worktreePath -b $branchName 2>&1
          if ($LASTEXITCODE -ne 0) {
            throw "git worktree add failed (exit $LASTEXITCODE): $wtOutput"
          }
          $entry.created = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "$repoName worktree created at $worktreePath"
        }
      } catch {
        $entry.error = "Failed to create $repoName worktree. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $entry.error
        [void]$repoResults.Add([PSCustomObject]$entry)
        continue
      }

      # --- 4. Create NTFS junctions ---
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
          -Message "Creating NTFS junctions in $repoName worktree pointing to SharedVSCode sprint worktree"

        if ($PSCmdlet.ShouldProcess($worktreePath, 'Set-WorktreeJunctions')) {
          $junctionResult = Set-WorktreeJunctions `
            -SourceRepoPath $repoPath `
            -WorktreePath $worktreePath `
            -DevSourceRepoPath $svWorktreePath `
            -DevSourceRepoFolderNames $JunctionFolderNames

          if ($junctionResult.Success) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "$repoName junctions created: $($junctionResult.JunctionsCreated) junction(s)"
          } else {
            $junctionErrors = ($junctionResult.Errors -join '; ')
            throw "Set-WorktreeJunctions completed but reported errors: $junctionErrors"
          }
        }
      } catch {
        $entry.error = "Failed to create $repoName junctions. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $entry.error
        [void]$repoResults.Add([PSCustomObject]$entry)
        continue
      }

      # --- 4b. Materialize AI adapters in downstream repo worktree (FSS-22) ---
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
          -Message "Materializing AI adapters in $repoName worktree"

        if ($PSCmdlet.ShouldProcess($worktreePath, 'Initialize-SprintAIAdapters')) {
          Initialize-SprintAIAdapters `
            -TargetRoot $worktreePath `
            -SharedVSCodeWorktreePath $svWorktreePath `
            -Force:$Force | Out-Null

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "AI adapters materialized in $repoName worktree"
        }
      } catch {
        # FSS-54: Non-fatal adapter materialization failure
        $warningMessage = "Warning: AI adapter materialization failed in $repoName worktree. Exception: $($_.Exception.Message). Continuing with other setup steps."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $warningMessage
      }

      # --- 5. Apply SharedVSCode context ---
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
          -Message "Applying SharedVSCode context to $repoName worktree"

        if ($PSCmdlet.ShouldProcess($worktreePath, 'Initialize-DownstreamSprintFromSharedVSCode')) {
          $workspaceFiles = @(Get-ChildItem -Path $worktreePath -Filter '*.code-workspace' |
              Select-Object -ExpandProperty FullName)

          if ($workspaceFiles.Count -eq 0) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "No .code-workspace files found in $repoName worktree; skipping context initialization"
          } else {
            $templateRef = "SharedVSCode-wt-$svIssueNum-Sprint-$sprintNum-work-items"
            Initialize-DownstreamSprintFromSharedVSCode `
              -WorkspaceFiles $workspaceFiles `
              -TemplateRef $templateRef `
              -Profile "sprint-$sprintNum"

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "$repoName context applied with templateRef $templateRef"
          }
        }
      } catch {
        $entry.error = "Failed to apply SharedVSCode context to $repoName. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $entry.error
        # Don't continue — junctions and worktree are already created, just log the context error
      }

      [void]$repoResults.Add([PSCustomObject]$entry)
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Downstream repos complete — processed $($repoResults.Count) repo(s)"

    # ===================================================================
    # 5c. Generate and verify the sprint Overview workspace (Task 10.14.a)
    # OverviewSprintNNNN.code-workspace is the manifest every later step uses to
    # discover the sprint (Build-CLAUDEPerRepository / CLAUDE.md propagation in
    # Task 10.3 and other cross-repo tooling). Earlier sprints created it only via
    # a documentation-only agent step (SprintStartAgent Step 3a), so a live run
    # that deviated from the runbook left it missing and blocked CLAUDE.md
    # propagation at Sprint 0010 start (SC-0193). Generating it here — after every
    # sprint worktree exists (so folder resolution finds them) and before Stage 2
    # reports success — makes the step unskippable. The verification gate confirms
    # the file exists and resolves at least one sprint worktree folder.
    # ===================================================================
    $overviewWorkspacePath = $null
    $overviewWorkspaceVerified = $false
    $overviewWorkspaceError = $null
    $expectedOverviewPath = Join-Path $GitRoot ('OverviewSprint{0}.code-workspace' -f $sprintNum)

    try {
      if ($PSCmdlet.ShouldProcess($expectedOverviewPath, 'Generate and verify Overview sprint workspace')) {
        $overviewResult = New-OverviewSprintWorkspace `
          -SprintNumber ([int]$sprintNum) `
          -GitRoot $GitRoot `
          -DeveloperUsername $env:USERNAME `
          -BuildMasterBaseUrl $BuildMasterBaseUrl `
          -ProGetBaseUrl $ProGetBaseUrl `
          -Confirm:$false `
          -WhatIf:$WhatIfPreference

        $overviewWorkspacePath = if ($overviewResult -and -not [string]::IsNullOrWhiteSpace($overviewResult.OutputWorkspacePath)) {
          $overviewResult.OutputWorkspacePath
        } else {
          $expectedOverviewPath
        }

        # --- Verification gate: file exists AND resolves >=1 sprint worktree folder ---
        if (-not (Test-Path -LiteralPath $overviewWorkspacePath -PathType Leaf)) {
          throw "Overview sprint workspace was not created at '$overviewWorkspacePath'."
        }

        $overviewRaw = Get-Content -LiteralPath $overviewWorkspacePath -Raw -ErrorAction Stop
        $overviewJsonText = $overviewRaw -replace ',(\s*[\]}])', '$1'
        $overviewObj = $overviewJsonText | ConvertFrom-Json -ErrorAction Stop

        $sprintFolderPattern = '-wt-\d+-Sprint-' + $sprintNum + '-work-items$'
        $resolvedSprintFolders = @(@($overviewObj.folders) |
            Where-Object { $_.path -match $sprintFolderPattern })

        if ($resolvedSprintFolders.Count -eq 0) {
          throw "Overview sprint workspace at '$overviewWorkspacePath' resolved no sprint worktree folders matching '*$sprintFolderPattern'."
        }

        $overviewWorkspaceVerified = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Overview sprint workspace generated and verified at '$overviewWorkspacePath' ($($resolvedSprintFolders.Count) sprint worktree folder(s))."
      } else {
        $overviewWorkspacePath = $expectedOverviewPath
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "DryRun/WhatIf: Overview sprint workspace generation skipped; would write '$expectedOverviewPath'."
      }
    } catch {
      $overviewWorkspaceError = "Failed to generate or verify the Overview sprint workspace. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $overviewWorkspaceError
    }

    # ===================================================================
    # 5d. Distribute all per-repository AI instruction lanes through one
    # orchestration call (Task 10.34). The orchestrator parses the Overview
    # workspace once, applies the stable-worktree boundary once, and returns
    # one aggregate for CLAUDE.md, AGENTS.md, GEMINI.md, and Copilot.
    # ===================================================================
    $aiInstructionsResult = $null
    $aiInstructionsError = $null

    if ($WhatIfPreference) {
      $aiInstructionsResult = [PSCustomObject]@{
        Success       = $true
        DryRun        = $true
        WorkspacePath = $overviewWorkspacePath
        Builders      = $null
        Errors        = @()
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "DryRun/WhatIf: would run one Build-AIInstructionsPerRepository distribution step for '$overviewWorkspacePath'."
    } elseif (-not $overviewWorkspaceVerified) {
      $aiInstructionsError = "AI instruction distribution skipped because the Overview sprint workspace was not verified: $overviewWorkspaceError"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $aiInstructionsError
    } else {
      try {
        if ($PSCmdlet.ShouldProcess($overviewWorkspacePath, 'Distribute all per-repository AI instruction lanes')) {
          $aiInstructionsResult = Build-AIInstructionsPerRepository `
            -WorktreeRoot $svWorktreePath `
            -WorkspacePath $overviewWorkspacePath `
            -Confirm:$false

          if (-not $aiInstructionsResult.Success -or @($aiInstructionsResult.Errors).Count -gt 0) {
            throw "Build-AIInstructionsPerRepository reported errors: $(@($aiInstructionsResult.Errors) -join '; ')"
          }

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "AI instruction distribution completed through one orchestration call for $($aiInstructionsResult.RepositoriesDiscovered) repository folder(s)."
        }
      } catch {
        $aiInstructionsError = "Failed to distribute per-repository AI instructions. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $aiInstructionsError
      }
    }

    # ===================================================================
    # 6. Symlink claude-settings.json
    # ===================================================================
    $claudeSettingsError = $null

    try {
      if ($PSCmdlet.ShouldProcess($svWorktreePath, 'Set claude-settings.json symlink')) {
        Set-ClaudeSettingsSymlink -SharedVSCodeWorktreePath $svWorktreePath
      }
    } catch {
      $claudeSettingsError = "Failed to symlink claude-settings.json. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $claudeSettingsError
    }

    # ===================================================================
    # 6b. Retarget VS Code UserSettings symlink to sprint worktree
    # ===================================================================
    $userSettingsLinked = $false
    $userSettingsError = $null

    try {
      if ($PSCmdlet.ShouldProcess($svWorktreePath, 'Retarget VS Code UserSettings.jsonc symlink')) {
        Set-UserSettingsSymlink -SharedVSCodeWorktreePath $svWorktreePath
        $userSettingsLinked = $true
      }
    } catch {
      $userSettingsError = "Failed to retarget VS Code UserSettings symlink. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $userSettingsError
    }

    # ===================================================================
    # 6c. Retarget machine-wide PowerShell 7 profile symlinks to the sprint
    # worktrees (H09/SC-0188, Task 10.13). profile.ps1 must track the
    # ATAP.Utilities sprint worktree so the AllUsersAllHosts core profile detects
    # the active sprint context; HostSettings.ps1 tracks the ATAP.IAC sprint
    # worktree when one is part of this sprint, else stable. The worker also
    # removes the now-obsolete global_ConfigRootKeys.ps1 /
    # global_environmentVariables.ps1 symlinks. SprintEnd resets all of these to
    # the stable repositories via Set-SprintBoundaryContext.
    # ===================================================================
    $profileSymlinksRetargeted = $false
    $profileSymlinkError = $null

    try {
      $utilWtRoot = $repoResults |
        Where-Object { $_.repoName -eq 'ATAP.Utilities' -and -not [string]::IsNullOrWhiteSpace($_.worktreePath) } |
        Select-Object -First 1 -ExpandProperty worktreePath
      if ([string]::IsNullOrWhiteSpace($utilWtRoot)) { $utilWtRoot = Join-Path $GitRoot 'ATAP.Utilities' }

      $iacWtRoot = $repoResults |
        Where-Object { $_.repoName -eq 'ATAP.IAC' -and -not [string]::IsNullOrWhiteSpace($_.worktreePath) } |
        Select-Object -First 1 -ExpandProperty worktreePath
      if ([string]::IsNullOrWhiteSpace($iacWtRoot)) { $iacWtRoot = Join-Path $GitRoot 'ATAP.IAC' }

      if ($PSCmdlet.ShouldProcess($utilWtRoot, 'Retarget PowerShell 7 profile symlinks to sprint worktrees')) {
        $profileSymlinkResult = Set-PowerShell7ProfileSymlink `
          -ATAPUtilitiesRoot $utilWtRoot `
          -ATAPIACRoot $iacWtRoot `
          -Confirm:$false
        if ($profileSymlinkResult.Ok) {
          $profileSymlinksRetargeted = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "PowerShell 7 profile symlinks retargeted: profile.ps1 -> $utilWtRoot, HostSettings.ps1 -> $iacWtRoot"
        } else {
          $profileSymlinkError = "Profile symlink retarget reported failures: $($profileSymlinkResult.Failures -join '; ')"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $profileSymlinkError
        }
      }
    } catch {
      $profileSymlinkError = "Failed to retarget PowerShell 7 profile symlinks. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $profileSymlinkError
    }

    # ===================================================================
    # 7. Set BuildMaster sprint application variables (Area 7.2-1)
    # Sets SprintNumber, UserName, SprintBranchName for each application.
    # These are consumed by the 5-Stage OtterScript plans and are cleared
    # at sprint-end by Clear-BuildMasterSprintVariables.
    # NOTE: ProGet feed creation (formerly Step 7) has been removed.
    # All ProGet feeds are permanent and ecosystem-wide. (Area 5 — reverted scheme)
    # ===================================================================
    $buildMasterResult = $null
    $buildMasterError = $null

    try {
      # Build per-application sprint branch name and source path hashtables from $repoResults
      $sprintBranchNameMap = @{}
      $sprintSourcePathMap = @{}
      foreach ($rr in $repoResults) {
        if (-not [string]::IsNullOrWhiteSpace($rr.repoName)) {
          if (-not [string]::IsNullOrWhiteSpace($rr.branchName)) {
            $sprintBranchNameMap[$rr.repoName] = $rr.branchName
          }
          if (-not [string]::IsNullOrWhiteSpace($rr.worktreePath)) {
            $sprintSourcePathMap[$rr.repoName] = $rr.worktreePath
          }
        }
      }

      if ($PSCmdlet.ShouldProcess($BuildMasterBaseUrl, 'Set BuildMaster sprint variables')) {
        $buildMasterResult = Set-BuildMasterSprintVariables `
          -SprintNumber $sprintNum `
          -Username $env:USERNAME `
          -SprintBranchNames $sprintBranchNameMap `
          -SourcePaths $sprintSourcePathMap `
          -BuildMasterBaseUrl $BuildMasterBaseUrl `
          -WhatIf:$WhatIfPreference
      }
    } catch {
      $buildMasterError = "Failed to set BuildMaster sprint variables. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $buildMasterError
    }

    # ===================================================================
    # 9. (Removed — SC-0172) Sprint start no longer creates Bitwarden secrets.
    # Connection-string secrets are provisioned out of band; New-SprintStage2
    # neither creates nor deletes vault items. The former
    # New-SprintBitwardenSecrets call and the connectionStrings/connectionStringError
    # return fields were removed.
    # ===================================================================

    # ===================================================================
    # 10. Reset sprint databases inside existing SQL Server instances
    # ===================================================================
    $dbResetResults = $null
    $dbResetError = $null

    if ($SkipDatabaseReset) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message 'Database reset skipped by explicit -SkipDatabaseReset request.'
    } else {
      # Read database settings for the reset call. There is ONE database,
      # ATAPUtilities (D-1), containing the ATAPUtilities, AceCommander, Tags and
      # Gmail schemas — confirmed by
      # ATAP.Utilities/Database/Flyway/SQL/V00.01.000010__Create_ATAPUtilities_Core_Schema.sql.
      # The Databases collection is a structured host setting, so it is read
      # directly (the same way Reset-SprintDatabases reads it) rather than via the
      # scalar Get-PVal path used for GitRoot/Owner/base URLs.
      $dbInstHost = 'localhost'
      $dbInstConnMethod = 'tcp'
      $databasesKey2 = if ($global:configRootKeys) { $global:configRootKeys['DatabasesCollectionConfigRootKey'] } else { $null }
      if ($databasesKey2 -and $global:settings -and $global:settings.ContainsKey($databasesKey2)) {
        $dbColl2 = $global:settings[$databasesKey2]
        $atapDb2 = if ($dbColl2.ContainsKey('ATAPUtilities')) { $dbColl2['ATAPUtilities'] } else { @{} }
        if (-not [string]::IsNullOrWhiteSpace($atapDb2['DatabaseHost'])) {
          $dbInstHost = $atapDb2['DatabaseHost']
        }
        if (-not [string]::IsNullOrWhiteSpace($atapDb2['ConnectionMethod'])) {
          $dbInstConnMethod = $atapDb2['ConnectionMethod']
        }
      }

      # Task 10.4: the installed BuildTooling module must drive the current
      # sprint-worktree Flyway/provisioning sources, never its module-relative
      # path or a stale path retained in host settings.
      $atapUtilitiesRepoResult = $repoResults |
        Where-Object {
          $_.repoName -eq 'ATAP.Utilities' -and
          -not [string]::IsNullOrWhiteSpace($_.worktreePath) -and
          (Test-Path -LiteralPath $_.worktreePath -PathType Container)
        } |
        Select-Object -First 1
      $databaseRepositoryRoot = if ($null -ne $atapUtilitiesRepoResult) {
        $atapUtilitiesRepoResult.worktreePath
      } else {
        Join-Path $GitRoot 'ATAP.Utilities'
      }
      $provisioningScriptsPath = Join-Path $databaseRepositoryRoot 'src\ATAP.Utilities.DatabaseManagement\SharedSQL'

      $dbResetParams = @{
        DatabaseHost           = $dbInstHost
        ConnectionMethod       = $dbInstConnMethod
        RepositoryRoot         = $databaseRepositoryRoot
        ProvisioningScriptsPath = $provisioningScriptsPath
      }

      try {
        if ($PSCmdlet.ShouldProcess('local SQL Server', 'Reset sprint databases in existing SQL Server instances')) {
          $dbResetResults = Reset-SprintDatabases @dbResetParams -Confirm:$false -WhatIf:$WhatIfPreference
        }
      } catch {
        $dbResetError = "Failed to reset sprint databases. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $dbResetError
      }
    }

    # ===================================================================
    # Assemble final result via New-SprintStage2Result (FSS-41)
    # ===================================================================
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Sprint Stage 2 complete — processed $($repoResults.Count) downstream repo(s)"

    $finalResult = New-SprintStage2Result `
      -DryRun:$DryRun `
      -RepoResults ($repoResults.ToArray()) `
      -ClaudeSettingsError $claudeSettingsError `
      -UserSettingsLinked $userSettingsLinked `
      -UserSettingsError $userSettingsError `
      -ProfileSymlinksRetargeted $profileSymlinksRetargeted `
      -ProfileSymlinkError $profileSymlinkError `
      -BuildMasterVariablesSet $(if ($buildMasterResult) { $buildMasterResult.variablesSet } else { @() }) `
      -BuildMasterVariablesErrors $(if ($buildMasterResult) { $buildMasterResult.errors } else { @() }) `
      -BuildMasterError $buildMasterError `
      -DatabaseResets $(if ($dbResetResults) { $dbResetResults } else { @() }) `
      -DatabaseResetError $dbResetError `
      -OverviewWorkspacePath $overviewWorkspacePath `
      -OverviewWorkspaceVerified $overviewWorkspaceVerified `
      -OverviewWorkspaceError $overviewWorkspaceError `
      -AIInstructionsResult $aiInstructionsResult `
      -AIInstructionsError $aiInstructionsError

    return $finalResult
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}

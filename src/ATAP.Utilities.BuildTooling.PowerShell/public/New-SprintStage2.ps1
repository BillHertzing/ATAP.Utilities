# =====================================================================
# Dot-source private helper functions
# =====================================================================
$privateDir = Join-Path $PSScriptRoot '..' 'private'
. (Join-Path $privateDir 'Set-ClaudeSettingsSymlink.ps1')
. (Join-Path $privateDir 'Get-SprintTaskRepositoryNames.ps1')
# New-SprintBuildMasterBuilds.ps1 replaced by public Set-BuildMasterSprintVariables (Area 7.2-1)
# New-SprintDatabaseInstances (private) superseded by public New-SprintSqlServerInstances
if (-not (Get-Command -Name 'New-SprintSqlServerInstances' -CommandType Function -ErrorAction SilentlyContinue)) {
  . (Join-Path $PSScriptRoot 'New-SprintSqlServerInstances.ps1')
}

# =====================================================================
# Main public cmdlet
# =====================================================================

function New-SprintStage2 {
  <#
  .SYNOPSIS
    Creates downstream repo sprint branches, workTrees, NTFS junctions,
    applies SharedVSCode context, symlinks claude-settings.json, scaffolds
    BuildMaster sprint builds, creates Bitwarden connection string secrets,
    and provisions sprint SQL Server database instances. ProGet feeds are
    permanent and ecosystem-wide — not created per sprint.
  .DESCRIPTION
    Reads the sprint TASKS.md file and extracts every unique repository name
    mentioned in task lines (the [RepoName] markers). Repos named '_Planning',
    'SharedVSCode', and 'Cross-Repo' are excluded — Step 1 already handled the
    first two, and Cross-Repo is not an actual repository.

    For each discovered repo the cmdlet:
      1. Creates a GitHub issue via 'gh issue create'.
      2. Fetches and pulls main.
      3. Creates the sprint branch and worktree.
      4. Calls Set-WorktreeJunctions to create NTFS junctions pointing to the
         SharedVSCode sprint worktree.
      5. Calls Initialize-DownstreamSprintFromSharedVSCode to apply templateRef,
         hooksPath, and commitTemplate.

    After all repos are processed the cmdlet also:
      6. Creates a symlink from the SharedVSCode sprint worktree's
         claude-settings.json to ~/.claude/settings.json.
      7. Scaffolds BuildMaster sprint build configurations (DRAFT — see notes).
      8. Creates Bitwarden secure-note items with SQL Server connection strings
         for the ATAPUtilities and AceCommander databases across Development
         and Experimental tiers via New-SprintBitwardenSecrets.
      9. Creates local Dev<username> and Exp<username> SQL Server instances and
         builds the ATAPUtilities and AceCommander databases using full Flyway migrations,
         via New-SprintSqlServerInstances.

    ProGet feeds are permanent and ecosystem-wide — they are NOT created per
    sprint. See New-ProGetFeedSet for one-time feed provisioning.

    If a step fails for a given repo, the error is captured in that repo's
    entry and the cmdlet continues with the next repo.
  .PARAMETER TasksFilePath
    Path to the TASKS.md file produced by sprint planning (Step 2).
    Defaults to the TASKS.md inside the _Planning sprint worktree whose
    path is provided via Stage1Result.
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
  .PARAMETER ProGetBaseUrl
    Base URL for the ProGet server.
    Defaults to 'http://localhost:50000'.
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server.
    Defaults to 'http://localhost:50001'.
  .PARAMETER DryRun
    Preview all sprint-start downstream actions without creating GitHub issues,
    branches, worktrees, junctions, SharedVSCode context, secrets, SQL Server
    instances, BuildMaster variables, or claude-settings links.
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

    [string]$GitRoot = 'C:\Dropbox\whertzing\GitHub',

    [string]$Owner = 'whertzing',

    [string[]]$JunctionFolderNames = @('.claude', '.github', '.vscode'),

    [string[]]$ExcludeRepos = @('_Planning', 'SharedVSCode', 'Cross-Repo'),

    [string]$ProGetBaseUrl = 'http://localhost:50000',

    [string]$BuildMasterBaseUrl = 'http://localhost:50001',

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
      $TasksFilePath = Join-Path $planningWt 'TASKS.md'
    }

    if (-not (Test-Path $TasksFilePath)) {
      throw "TASKS.md not found at $TasksFilePath"
    }

    # Stage 2 reads host-specific database and package settings. Fail early so
    # agent/no-profile shells do not create partial sprint infrastructure.
    if (-not $DryRun) {
      $missingGlobalConfig = [System.Collections.Generic.List[string]]::new()

      if ($null -eq $global:configRootKeys -or
        -not ($global:configRootKeys -is [hashtable]) -or
        $global:configRootKeys.Count -eq 0) {
        [void]$missingGlobalConfig.Add('$global:configRootKeys')
      }

      if ($null -eq $global:settings -or
        -not ($global:settings -is [hashtable]) -or
        $global:settings.Count -eq 0) {
        [void]$missingGlobalConfig.Add('$global:settings')
      }

      if ($missingGlobalConfig.Count -gt 0) {
        $setupCommand = 'Set-GlobalConfigRootKeys; $global:settings = Get-HostSettings -hostName $env:COMPUTERNAME'
        throw "New-SprintStage2 requires $($missingGlobalConfig -join ' and ') before it can run. Run the ATAP configuration setup command first: $setupCommand"
      }
    }

    # --- Ensure external dependencies ---
    if (-not $DryRun) {
      Assert-GitAvailable

      if (-not (Get-Command -Name 'gh' -ErrorAction SilentlyContinue)) {
        throw 'The GitHub CLI (gh) is required but was not found on PATH.'
      }
    }

    # Dot-source Set-WorktreeJunctions if not already loaded
    $setWtJunctionsPath = Join-Path $GitRoot 'ATAP.Utilities' 'src' `
      'ATAP.Utilities.BuildTooling.PowerShell' 'public' 'Set-WorktreeJunctions.ps1'
    if (-not (Get-Command -Name 'Set-WorktreeJunctions' -CommandType Function -ErrorAction SilentlyContinue)) {
      if ($DryRun) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'DryRun: skipping Set-WorktreeJunctions dependency load.'
      } elseif (Test-Path $setWtJunctionsPath) {
        . $setWtJunctionsPath
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
          -Message "Set-WorktreeJunctions.ps1 not found at $setWtJunctionsPath"
        throw "Set-WorktreeJunctions.ps1 not found at $setWtJunctionsPath"
      }
    }

    # Ensure SharedVSCode functions are loaded
    if (-not (Get-Command -Name 'Initialize-DownstreamSprintFromSharedVSCode' -CommandType Function -ErrorAction SilentlyContinue)) {
      $importPath = Join-Path $GitRoot 'SharedVSCode' 'Powershell' 'Import-SharedVSCodeFunctions.ps1'
      if ($DryRun) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'DryRun: skipping SharedVSCode function dependency load.'
      } elseif (Test-Path $importPath) {
        . $importPath
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
          -Message "Import-SharedVSCodeFunctions.ps1 not found at $importPath"
        throw "Import-SharedVSCodeFunctions.ps1 not found at $importPath"
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
    $repoNames = @(Get-SprintTaskRepositoryNames -TasksContent $tasksContent -ExcludeRepos $ExcludeRepos)

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
        junctionsCreated = $false
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
            $entry.junctionsCreated = $true
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
    # 6. Symlink claude-settings.json
    # ===================================================================
    $claudeSettingsLinked = $false
    $claudeSettingsError = $null

    try {
      if ($PSCmdlet.ShouldProcess($svWorktreePath, 'Set claude-settings.json symlink')) {
        Set-ClaudeSettingsSymlink -SharedVSCodeWorktreePath $svWorktreePath
        $claudeSettingsLinked = $true
      }
    } catch {
      $claudeSettingsError = "Failed to symlink claude-settings.json. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $claudeSettingsError
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
      # Build per-application sprint branch name hashtable from $repoResults
      $sprintBranchNameMap = @{}
      foreach ($rr in $repoResults) {
        if (-not [string]::IsNullOrWhiteSpace($rr.repoName) -and -not [string]::IsNullOrWhiteSpace($rr.branchName)) {
          $sprintBranchNameMap[$rr.repoName] = $rr.branchName
        }
      }

      if ($PSCmdlet.ShouldProcess($BuildMasterBaseUrl, 'Set BuildMaster sprint variables')) {
        $buildMasterResult = Set-BuildMasterSprintVariables `
          -SprintNumber $sprintNum `
          -Username $env:USERNAME `
          -SprintBranchNames $sprintBranchNameMap `
          -BuildMasterBaseUrl $BuildMasterBaseUrl `
          -WhatIf:$WhatIfPreference
      }
    } catch {
      $buildMasterError = "Failed to set BuildMaster sprint variables. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $buildMasterError
    }

    # ===================================================================
    # 9. Create Bitwarden connection string secrets
    # ===================================================================
    $connStringResults = $null
    $connStringError = $null

    try {
      if ($PSCmdlet.ShouldProcess('Bitwarden vault', 'Create sprint connection string secrets')) {
        $connStringResults = New-SprintBitwardenSecrets `
          -SprintNumber $sprintNum `
          -DeveloperUsername $env:USERNAME `
          -WhatIf:$WhatIfPreference
      }
    } catch {
      $connStringError = "Failed to create Bitwarden connection string secrets. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $connStringError
    }

    # ===================================================================
    # 10. Create sprint SQL Server database instances
    # ===================================================================
    $dbInstanceResults = $null
    $dbInstanceError = $null

    # Read database settings from global config for the DB instance call
    $dbInstHost = 'localhost'
    $dbInstConnMethod = 'tcp'
    $dbInstPort = $null
    $databasesKey2 = if ($global:configRootKeys) { $global:configRootKeys['DatabasesCollectionConfigRootKey'] } else { $null }
    if ($databasesKey2 -and $global:settings -and $global:settings.ContainsKey($databasesKey2)) {
      $dbColl2 = $global:settings[$databasesKey2]
      $atapDb2 = if ($dbColl2.ContainsKey('ATAPUtilities')) {
        $dbColl2['ATAPUtilities']
      } elseif ($dbColl2.ContainsKey('ATAPUtilities')) {
        $dbColl2['ATAPUtilities']
      } else {
        @{}
      }
      if (-not [string]::IsNullOrWhiteSpace($atapDb2['DatabaseHost'])) {
        $dbInstHost = $atapDb2['DatabaseHost']
      }
      if (-not [string]::IsNullOrWhiteSpace($atapDb2['ConnectionMethod'])) {
        $dbInstConnMethod = $atapDb2['ConnectionMethod']
      }
      if (-not [string]::IsNullOrWhiteSpace($atapDb2['Port'])) {
        $dbInstPort = $atapDb2['Port']
      }
    }

    $dbInstanceParams = @{
      DatabaseHost     = $dbInstHost
      ConnectionMethod = $dbInstConnMethod
    }

    try {
      if ($PSCmdlet.ShouldProcess('local SQL Server', 'Create sprint SQL Server instances and databases')) {
        $dbInstanceResults = New-SprintSqlServerInstances @dbInstanceParams -WhatIf:$WhatIfPreference
      }
    } catch {
      $dbInstanceError = "Failed to create sprint database instances. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $dbInstanceError
    }

    # ===================================================================
    # Assemble final result
    # ===================================================================
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Sprint Stage 2 complete — processed $($repoResults.Count) downstream repo(s)"

    $finalResult = [PSCustomObject]@{
      dryRun         = $DryRun.IsPresent
      repoResults    = $repoResults.ToArray()
      infrastructure = [PSCustomObject]@{
        claudeSettingsLinked       = $claudeSettingsLinked
        claudeSettingsError        = $claudeSettingsError
        # PLACEHOLDER: buildMaster fields are draft — values will be empty
        # until BuildMaster API integration is tested and enabled.
        buildMasterVariablesSet    = if ($buildMasterResult) { $buildMasterResult.variablesSet } else { @() }
        buildMasterVariablesErrors = if ($buildMasterResult) { $buildMasterResult.errors } else { @() }
        buildMasterVariablesError  = $buildMasterError
        # Connection string secrets created in Bitwarden (UNTESTED)
        connectionStrings          = if ($connStringResults) { $connStringResults } else { @() }
        connectionStringError      = $connStringError
        # Sprint SQL Server database instances
        databaseInstances          = if ($dbInstanceResults) { $dbInstanceResults } else { @() }
        databaseInstanceError      = $dbInstanceError
      }
    }

    return $finalResult
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}

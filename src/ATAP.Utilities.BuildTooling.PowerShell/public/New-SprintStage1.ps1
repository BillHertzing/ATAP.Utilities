# Load contract: dot-source this file to define New-SprintStage1. No top-level
# code executes on load — all side effects occur only when the function is called.
function New-SprintStage1 {
  <#
  .SYNOPSIS
    Bootstraps Stage 1 of a new sprint: determines the sprint number, creates
    SharedVSCode and _Planning branches/workTrees, creates NTFS junctions, and
    applies SharedVSCode context to _Planning.
  .DESCRIPTION
    Performs, in order:
      1. Determines the next sprint number from the most recent retrospective
         document in _Planning/SprintRetrospective.
      2. Creates a GitHub issue, branch, and worktree for SharedVSCode.
      3. Creates a GitHub issue, branch, and worktree for _Planning.
      4. Creates NTFS junctions in the _Planning worktree pointing to the
         SharedVSCode sprint worktree.
      5. Applies SharedVSCode context (templateRef, hooksPath, commitTemplate)
         to the _Planning worktree.
      6. Creates a sprint NuGet.config in the SharedVSCode worktree referencing
          all five ProGet feeds (experimental, development, integration, qa, stable)
          plus nuget.org.
      7. Leaves the `_Planning` sprint worktree ready for Step 2 to create the
         sprint task artifact set: `TASKS.html`, `Tasks.Accomplished.html`,
         `Tasks.ProceduralDetails.html`, and the synchronized `TASKS.md`.

    If any step fails the function captures the error into the appropriate field
    of the return object and stops further processing for that repo while still
    returning a populated result.
  .PARAMETER GitRoot
    Root directory containing all Git repositories.
  .PARAMETER Owner
    GitHub owner / organisation name.
  .PARAMETER SprintNumber
    Explicit sprint number (four-digit zero-padded string, e.g. '0006').
    When omitted the function auto-detects from the latest retrospective.
  .PARAMETER JunctionFolderNames
    Folder names to junction from SharedVSCode into _Planning.
    Defaults to @('.claude', '.github', '.vscode').
  .PARAMETER DryRun
    Preview all sprint-start actions without creating GitHub issues, branches,
    worktrees, junctions, SharedVSCode context, or NuGet.config files.
  .OUTPUTS
    PSCustomObject — see the return structure in the code.
  .EXAMPLE
    $stage1 = New-SprintStage1
    $stage1 | ConvertTo-Json -Depth 4
  .EXAMPLE
    $stage1 = New-SprintStage1 -SprintNumber '0006'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    SprintStartAgent.md — Steps 1-3
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [string]$GitRoot,

    [string]$Owner,

    [ValidatePattern('^\d{4}$')]
    [string]$SprintNumber,

    [string[]]$JunctionFolderNames = @('.claude', '.github', '.vscode'),

    [string]$ProGetBaseUrl,

    [switch]$Force,

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

    # --- Resolve configuration via Get-PVal (FSS-02): param > env > settings >
    #     documented default. This replaces the hard-coded parameter defaults and
    #     the brittle OverView.code-workspace githubOwner read. Get-PVal raises a
    #     loud-failure guard when no settings source is loaded (tests / no-profile
    #     shells), so each lookup is wrapped and degrades to the default rather
    #     than aborting sprint start. ---
    $getPValAvailable = [bool](Get-Command -Name 'Get-PVal' -ErrorAction SilentlyContinue)
    $proGetBaseUrlKey = if ($global:configRootKeys -and $global:configRootKeys['ProGetBaseUrlConfigRootKey']) {
      $global:configRootKeys['ProGetBaseUrlConfigRootKey']
    } else { 'ProGetBaseUrl' }

    $gitRootDefault = 'C:\Dropbox\whertzing\GitHub'
    $ownerDefault = $env:USERNAME
    $proGetBaseUrlDefault = 'http://localhost:50000'

    if ($getPValAvailable) {
      foreach ($spec in @(
          @{ Name = 'GitRoot'; Path = 'GitRoot'; Default = $gitRootDefault },
          @{ Name = 'Owner'; Path = 'GitHubOwner'; Default = $ownerDefault },
          @{ Name = 'ProGetBaseUrl'; Path = $proGetBaseUrlKey; Default = $proGetBaseUrlDefault })) {
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
    $ProGetBaseUrl = $ProGetBaseUrl.TrimEnd('/')

    # --- Ensure external dependencies are available ---
    if (-not $DryRun) {
      Assert-GitAvailable

      if (-not (Get-Command -Name 'gh' -ErrorAction SilentlyContinue)) {
        throw 'The GitHub CLI (gh) is required but was not found on PATH.'
      }
    }

    # Autoload-or-throw contract (FSS-10): the BuildTooling module is CI-built and
    # installed, so the functions this stage calls must resolve by module autoload.
    # A missing command is an environment fault the user must repair — never a
    # silent dot-source fallback from a worktree path.
    foreach ($required in @('Set-WorktreeJunctions', 'Initialize-DownstreamSprintFromSharedVSCode', 'Initialize-SprintAIAdapters')) {
      if (-not (Get-Command -Name $required -ErrorAction SilentlyContinue)) {
        throw "Required command '$required' is not available. The " +
        'ATAP.Utilities.BuildTooling.PowerShell module must be installed and ' +
        'autoloadable. Repair the module install before retrying sprint start.'
      }
    }
  }

  process {
    # ----- Build the result object -----
    $result = [PSCustomObject]@{
      nextSprintNumber     = $null
      previousSprintNumber = $null
      dryRun               = $DryRun.IsPresent
      sharedVSCode         = @{
        issueNumber  = $null
        branchName   = $null
        worktreePath = $null
        created      = $false
        error        = $null
      }
      planning             = @{
        issueNumber      = $null
        branchName       = $null
        worktreePath     = $null
        created          = $false
        junctionsCreated = $false
        planningComplete = $false
        error            = $null
      }
    }

    # ===================================================================
    # Step 1 — Determine the next sprint number
    # ===================================================================
    if ($PSBoundParameters.ContainsKey('SprintNumber')) {
      $sprintNum = $SprintNumber
      $prevNum = '{0:D4}' -f ([int]$sprintNum - 1)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Using explicit sprint number $sprintNum"
    } else {
      $planningRoot = Join-Path $GitRoot '_Planning'
      $retroDir = Join-Path $planningRoot 'SprintRetrospective'

      $retrospectives = Get-ChildItem $retroDir `
        -Filter 'Notebook-SprintWorkSession-*-End.md' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending

      if ($retrospectives) {
        $lastRetro = $retrospectives[0].Name
        if ($lastRetro -match 'SprintWorkSession-(\d{4})-End') {
          $lastSprintN = [int]$Matches[1]
          $newSprintN = $lastSprintN + 1
        } else {
          $newSprintN = 1
        }
      } else {
        $newSprintN = 1
      }

      $sprintNum = '{0:D4}' -f $newSprintN
      $prevNum = '{0:D4}' -f ($newSprintN - 1)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Auto-detected sprint number $sprintNum (previous: $prevNum)"
    }

    $result.nextSprintNumber = $sprintNum
    $result.previousSprintNumber = $prevNum

    # ===================================================================
    # Step 2 — SharedVSCode: issue + branch + worktree
    # ===================================================================
    $svRepoPath = Join-Path $GitRoot 'SharedVSCode'
    $svIssueNum = $null

    # 2a. Create GitHub issue
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Creating GitHub issue for SharedVSCode sprint $sprintNum"

      if ($PSCmdlet.ShouldProcess("$Owner/SharedVSCode", "Create GitHub issue 'Sprint $sprintNum work items'")) {
        $ghOutput = gh issue create `
          --repo "$Owner/SharedVSCode" `
          --title "Sprint $sprintNum work items" `
          --label 'sprint' `
          --body "Sprint $sprintNum work items for SharedVSCode" 2>&1

        if ($LASTEXITCODE -ne 0) {
          throw "gh issue create failed (exit $LASTEXITCODE): $ghOutput"
        }

        # gh returns the issue URL; extract the number from the end
        if ($ghOutput -match '/issues/(\d+)') {
          $svIssueNum = [int]$Matches[1]
        } else {
          throw "Could not parse issue number from gh output: $ghOutput"
        }

        $result.sharedVSCode.issueNumber = $svIssueNum
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "SharedVSCode issue #$svIssueNum created"
      }
    } catch {
      $errorMessage = "Failed to create SharedVSCode GitHub issue. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.sharedVSCode.error = $errorMessage
      return $result
    }

    if ($DryRun -and $null -eq $svIssueNum) {
      $svIssueNum = 'DRYRUN'
      $result.sharedVSCode.issueNumber = $svIssueNum
    }

    # 2b. Fetch latest main
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message 'Fetching and checking out SharedVSCode main'

      if ($PSCmdlet.ShouldProcess($svRepoPath, 'git fetch/checkout/pull main')) {
        git -C $svRepoPath fetch origin 2>&1 | Out-Null
        git -C $svRepoPath checkout main 2>&1 | Out-Null
        git -C $svRepoPath pull origin main 2>&1 | Out-Null
      }
    } catch {
      $errorMessage = "Failed to update SharedVSCode main. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.sharedVSCode.error = $errorMessage
      return $result
    }

    # 2c. Create branch and worktree
    $svBranch = "$svIssueNum-Sprint-$sprintNum-work-items"
    $svWorktreePath = Join-Path $GitRoot "SharedVSCode-wt-$svIssueNum-Sprint-$sprintNum-work-items"
    $result.sharedVSCode.branchName = $svBranch
    $result.sharedVSCode.worktreePath = $svWorktreePath

    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Creating SharedVSCode worktree at $svWorktreePath on branch $svBranch"

      if ($PSCmdlet.ShouldProcess($svWorktreePath, "git worktree add -b $svBranch")) {
        $wtOutput = git -C $svRepoPath worktree add $svWorktreePath -b $svBranch 2>&1
        if ($LASTEXITCODE -ne 0) {
          throw "git worktree add failed (exit $LASTEXITCODE): $wtOutput"
        }
        $result.sharedVSCode.created = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "SharedVSCode worktree created at $svWorktreePath"
      }
    } catch {
      $errorMessage = "Failed to create SharedVSCode worktree. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.sharedVSCode.error = $errorMessage
      return $result
    }

    # ===================================================================
    # Step 3 — _Planning: issue + branch + worktree + junctions + context
    # ===================================================================
    $planRepoPath = Join-Path $GitRoot '_Planning'
    $planIssueNum = $null

    # 3a. Create GitHub issue
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Creating GitHub issue for _Planning sprint $sprintNum"

      if ($PSCmdlet.ShouldProcess("$Owner/_Planning", "Create GitHub issue 'Sprint $sprintNum work items'")) {
        $ghOutput = gh issue create `
          --repo "$Owner/_Planning" `
          --title "Sprint $sprintNum work items" `
          --label 'sprint' `
          --body "Sprint $sprintNum work items for _Planning" 2>&1

        if ($LASTEXITCODE -ne 0) {
          throw "gh issue create failed (exit $LASTEXITCODE): $ghOutput"
        }

        if ($ghOutput -match '/issues/(\d+)') {
          $planIssueNum = [int]$Matches[1]
        } else {
          throw "Could not parse issue number from gh output: $ghOutput"
        }

        $result.planning.issueNumber = $planIssueNum
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "_Planning issue #$planIssueNum created"
      }
    } catch {
      $errorMessage = "Failed to create _Planning GitHub issue. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.planning.error = $errorMessage
      return $result
    }

    if ($DryRun -and $null -eq $planIssueNum) {
      $planIssueNum = 'DRYRUN'
      $result.planning.issueNumber = $planIssueNum
    }

    # 3b. Fetch latest main
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message 'Fetching and checking out _Planning main'

      if ($PSCmdlet.ShouldProcess($planRepoPath, 'git fetch/checkout/pull main')) {
        git -C $planRepoPath fetch origin 2>&1 | Out-Null
        git -C $planRepoPath checkout main 2>&1 | Out-Null
        git -C $planRepoPath pull origin main 2>&1 | Out-Null
      }
    } catch {
      $errorMessage = "Failed to update _Planning main. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.planning.error = $errorMessage
      return $result
    }

    # 3c. Create branch and worktree
    $planBranch = "$planIssueNum-Sprint-$sprintNum-work-items"
    $planWorktreePath = Join-Path $GitRoot "_Planning-wt-$planIssueNum-Sprint-$sprintNum-work-items"
    $result.planning.branchName = $planBranch
    $result.planning.worktreePath = $planWorktreePath

    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Creating _Planning worktree at $planWorktreePath on branch $planBranch"

      if ($PSCmdlet.ShouldProcess($planWorktreePath, "git worktree add -b $planBranch")) {
        $wtOutput = git -C $planRepoPath worktree add $planWorktreePath -b $planBranch 2>&1
        if ($LASTEXITCODE -ne 0) {
          throw "git worktree add failed (exit $LASTEXITCODE): $wtOutput"
        }
        $result.planning.created = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "_Planning worktree created at $planWorktreePath"
      }
    } catch {
      $errorMessage = "Failed to create _Planning worktree. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.planning.error = $errorMessage
      return $result
    }

    # 3d. Create NTFS junctions in the _Planning worktree
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message 'Creating NTFS junctions in _Planning worktree pointing to SharedVSCode sprint worktree'

      if ($PSCmdlet.ShouldProcess($planWorktreePath, 'Set-WorktreeJunctions')) {
        $junctionResult = Set-WorktreeJunctions `
          -SourceRepoPath $planRepoPath `
          -WorktreePath $planWorktreePath `
          -DevSourceRepoPath $svWorktreePath `
          -DevSourceRepoFolderNames $JunctionFolderNames

        if ($junctionResult.Success) {
          $result.planning.junctionsCreated = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "_Planning junctions created: $($junctionResult.JunctionsCreated) junction(s)"
        } else {
          $junctionErrors = ($junctionResult.Errors -join '; ')
          throw "Set-WorktreeJunctions completed but reported errors: $junctionErrors"
        }
      }
    } catch {
      $errorMessage = "Failed to create _Planning junctions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.planning.error = $errorMessage
      return $result
    }

    # 3f. Materialize AI adapters in the _Planning worktree (FSS-22)
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message 'Materializing AI adapters in _Planning worktree'

      if ($PSCmdlet.ShouldProcess($planWorktreePath, 'Initialize-SprintAIAdapters')) {
        Initialize-SprintAIAdapters `
          -TargetRoot $planWorktreePath `
          -SharedVSCodeWorktreePath $svWorktreePath `
          -Force:$Force | Out-Null

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message 'AI adapters materialized in _Planning worktree'
      }
    } catch {
      $errorMessage = "Failed to materialize _Planning AI adapters. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.planning.error = $errorMessage
      return $result
    }

    # 3e. Apply SharedVSCode context to _Planning
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message 'Applying SharedVSCode context to _Planning worktree'

      if ($PSCmdlet.ShouldProcess($planWorktreePath, 'Initialize-DownstreamSprintFromSharedVSCode')) {
        $workspaceFiles = @(Get-ChildItem -Path $planWorktreePath -Filter '*.code-workspace' |
            Select-Object -ExpandProperty FullName)

        if ($workspaceFiles.Count -eq 0) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message 'No .code-workspace files found in _Planning worktree; skipping context initialization'
        } else {
          $templateRef = "SharedVSCode-wt-$svIssueNum-Sprint-$sprintNum-work-items"
          Initialize-DownstreamSprintFromSharedVSCode `
            -WorkspaceFiles $workspaceFiles `
            -TemplateRef $templateRef `
            -Profile "sprint-$sprintNum"

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "_Planning context applied with templateRef $templateRef"
        }
      }
    } catch {
      $errorMessage = "Failed to apply SharedVSCode context to _Planning. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.planning.error = $errorMessage
      return $result
    }

    # 3g. Rename planning files to sprint-scoped names (FSS-25)
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message 'Renaming planning files to sprint-scoped names in _Planning worktree'

      $renameMap = @{
        'TASKS.md'                     = "TasksSprint$sprintNum.md"
        'TASKS.html'                   = "TasksSprint$sprintNum.html"
        'Tasks.Accomplished.html'      = "Tasks.Accomplished.Sprint$sprintNum.html"
        'Tasks.ProceduralDetails.html' = "Tasks.ProceduralDetails.Sprint$sprintNum.html"
      }

      foreach ($oldName in $renameMap.Keys) {
        $oldPath = Join-Path $planWorktreePath $oldName
        $newName = $renameMap[$oldName]
        $newPath = Join-Path $planWorktreePath $newName

        if ($DryRun) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "[DRY RUN] Would rename $oldPath to $newPath"
        } elseif (Test-Path $oldPath) {
          if ($PSCmdlet.ShouldProcess($oldPath, "Rename file to $newPath")) {
            Rename-Item -Path $oldPath -NewName $newName -Force
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "Renamed planning file: $oldName -> $newName"
          }
        } else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
            -Message "Planning file $oldName not found at $oldPath; skipping rename."
        }
      }
    } catch {
      $errorMessage = "Failed to rename planning files. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.planning.error = $errorMessage
      return $result
    }

    # ===================================================================
    # Step 4 — Create sprint NuGet.config in SharedVSCode worktree
    # ===================================================================
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Creating sprint NuGet.config in SharedVSCode worktree at $svWorktreePath"

      $nugetConfigPath = Join-Path $svWorktreePath 'NuGet.config'
      $templatePath = Join-Path $svWorktreePath 'NuGet.config.template'
      if (-not (Test-Path $templatePath)) {
        $templatePath = Join-Path $GitRoot 'SharedVSCode/NuGet.config.template'
      }
      if (-not (Test-Path $templatePath)) {
        $templatePath = 'C:/Dropbox/whertzing/GitHub/SharedVSCode/NuGet.config.template'
      }

      if (-not (Test-Path $templatePath)) {
        throw "NuGet.config.template not found at '$templatePath'"
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Reading NuGet.config.template from $templatePath"

      $templateContent = Get-Content -LiteralPath $templatePath -Raw
      $nugetConfigContent = $templateContent.Replace('${ProGetBaseUrl}', $ProGetBaseUrl)

      if ($PSCmdlet.ShouldProcess($nugetConfigPath, 'Set-Content NuGet.config')) {
        Set-Content -Path $nugetConfigPath -Value $nugetConfigContent -Encoding utf8
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Sprint NuGet.config created at $nugetConfigPath"
      }
    } catch {
      $errorMessage = "Failed to create sprint NuGet.config. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      # NuGet.config creation failure is non-fatal; log and continue
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Sprint Stage 1 complete for sprint $sprintNum"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Step 2 planning must create or refresh the sprint task artifact set in the _Planning worktree: active board (TasksSprint$sprintNum.html or later TasksSprint${sprintNum}_V*.html), Tasks.Accomplished.Sprint$sprintNum.html, Tasks.ProceduralDetails.Sprint$sprintNum.html, and a synchronized TasksSprint$sprintNum.md."

    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}

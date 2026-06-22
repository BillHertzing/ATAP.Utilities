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
         the permanent ProGet feeds and nuget.org.
      7. Uses the immediately prior sprint's task markdown as a structure-only
         template, creates a content-fresh `Tasks.SprintNNNN.md`, synchronizes
         `Tasks.SprintNNNN.html`, and creates empty-but-structured
         `Tasks.SprintNNNN.Accomplished.html` and
         `Tasks.SprintNNNN.ProceduralDetails.html` companion files.

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

    $gitRootDefault = 'C:\Dropbox\whertzing\GitHub'
    $gitRootForOwner = if (-not [string]::IsNullOrWhiteSpace($GitRoot)) { $GitRoot } else { $gitRootDefault }
    $ownerDefault = if (Get-Command -Name 'Get-GitHubOwnerFromWorkspace' -ErrorAction SilentlyContinue) {
      Get-GitHubOwnerFromWorkspace -GitRoot $gitRootForOwner -Fallback $env:USERNAME
    } else { $env:USERNAME }
    $proGetBaseUrlDefault = 'http://localhost:50000'

    if ($getPValAvailable) {
      foreach ($spec in @(
          @{ Name = 'GitRoot'; Path = 'GitRoot'; Default = $gitRootDefault },
          @{ Name = 'Owner'; Path = 'GitHubOwner'; Default = $ownerDefault },
          @{ Name = 'ProGetBaseUrl'; Path = $proGetBaseUrlKey; Default = $proGetBaseUrlDefault })) {
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
    $ProGetBaseUrl = $ProGetBaseUrl.TrimEnd('/')

    # Task 10.2: surface the resolved GitHub owner so a no-Owner dry run shows the
    # value read from OverView.code-workspace (e.g. 'BillHertzing') before any
    # gh issue create / ShouldProcess target string is evaluated.
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Resolved GitHub owner '$Owner' (no-Owner default sourced from OverView.code-workspace githubOwner)."

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
    foreach ($required in @(
        'Set-WorktreeJunctions'
        'Initialize-DownstreamSprintFromSharedVSCode'
        'Initialize-SprintAIAdapters'
        'Convert-TasksMdToSprintBoard')) {
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
      owner                = $Owner
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
      # FSS-54: Non-fatal adapter materialization failure
      $errorMessage = "Warning: AI adapter materialization failed in _Planning worktree. Exception: $($_.Exception.Message). Continuing sprint start."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $errorMessage
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

    # 3g. Create a content-fresh sprint task artifact set from the prior
    #     sprint's structure-only template (Task 10.11 / FSS-25).
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message 'Creating the sprint task artifact set from the prior sprint structure'

      $artifactNames = [ordered]@{
        Markdown          = "Tasks.Sprint$sprintNum.md"
        Board             = "Tasks.Sprint$sprintNum.html"
        Accomplished      = "Tasks.Sprint$sprintNum.Accomplished.html"
        ProceduralDetails = "Tasks.Sprint$sprintNum.ProceduralDetails.html"
      }

      $artifactPaths = [ordered]@{}
      foreach ($key in $artifactNames.Keys) {
        $artifactPaths[$key] = Join-Path $planWorktreePath $artifactNames[$key]
      }

      if ($DryRun) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "[DRY RUN] Would generate sprint task artifacts: $($artifactNames.Values -join ', ')"
      } else {
        $priorMarkdownCandidates = @(
          "Tasks.Sprint$prevNum.md"
          "TasksSprint$prevNum.md"
          'TASKS.md'
        )
        $priorMarkdownPath = $priorMarkdownCandidates |
          ForEach-Object { Join-Path $planWorktreePath $_ } |
          Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
          Select-Object -First 1

        if (-not $priorMarkdownPath) {
          throw "Prior sprint task markdown was not found in '$planWorktreePath'. Expected one of: $($priorMarkdownCandidates -join ', ')."
        }

        $priorMarkdownLines = @(Get-Content -LiteralPath $priorMarkdownPath -Encoding UTF8)
        foreach ($requiredMarker in @(
            @{ Name = 'current sprint heading'; Pattern = '^# Current Sprint:\s+' }
            @{ Name = 'goal section'; Pattern = '^## Goal\s*$' }
            @{ Name = 'stream section'; Pattern = '^## Stream\s+' })) {
          if (-not ($priorMarkdownLines | Where-Object { $_ -match $requiredMarker.Pattern } | Select-Object -First 1)) {
            throw "Prior sprint task template '$priorMarkdownPath' is missing the required $($requiredMarker.Name)."
          }
        }

        $priorStreamIds = @(
          $priorMarkdownLines |
            Where-Object { $_ -match '^## Stream (?<Id>[A-Za-z0-9]+)\s+[–-]\s+' } |
            ForEach-Object {
              if ($_ -match '^## Stream (?<Id>[A-Za-z0-9]+)\s+[–-]\s+') {
                $Matches['Id']
              }
            }
        )
        if ($priorStreamIds.Count -eq 0) {
          throw "Prior sprint task template '$priorMarkdownPath' contains no parseable stream headings."
        }

        $generatedDate = Get-Date -Format 'yyyy-MM-dd'
        $sprintDisplayNumber = [int]$sprintNum
        $freshMarkdownLines = [System.Collections.Generic.List[string]]::new()
        $freshMarkdownLines.Add("# Current Sprint: Sprint $sprintDisplayNumber - Planning in progress")
        $freshMarkdownLines.Add('')
        $freshMarkdownLines.Add("Source: SprintStartAgent structure-only template from Sprint $prevNum ($generatedDate)")
        $freshMarkdownLines.Add("Last updated: $generatedDate (content-fresh scaffold; finalize during Step 2 planning)")
        $freshMarkdownLines.Add("Active board: ``$($artifactNames.Board)`` (generated from this authoritative markdown file via ``Convert-TasksMdToSprintBoard``).")
        $freshMarkdownLines.Add('')
        $freshMarkdownLines.Add('## Goal')
        $freshMarkdownLines.Add('')
        $freshMarkdownLines.Add("Define the Sprint $sprintNum goal during Step 2 planning.")
        $freshMarkdownLines.Add('')
        $freshMarkdownLines.Add('---')

        foreach ($streamId in $priorStreamIds) {
          $freshMarkdownLines.Add('')
          $freshMarkdownLines.Add("## Stream $streamId - Sprint $sprintNum planning [DRAFT]")
          $freshMarkdownLines.Add('')
          $freshMarkdownLines.Add('Generate current-sprint tasks for this stream during Step 2 planning; no prior-sprint task content was carried forward.')
        }
        $freshMarkdownLines.Add('')

        if ($PSCmdlet.ShouldProcess($artifactPaths.Markdown, "Generate content-fresh task markdown from '$priorMarkdownPath' structure")) {
          Set-Content -LiteralPath $artifactPaths.Markdown -Value $freshMarkdownLines -Encoding UTF8
        }

        if ($PSCmdlet.ShouldProcess($artifactPaths.Board, "Synchronize board from '$($artifactPaths.Markdown)'")) {
          Convert-TasksMdToSprintBoard `
            -TasksFilePath $artifactPaths.Markdown `
            -OutputPath $artifactPaths.Board `
            -Confirm:$false | Out-Null
        }

        $accomplishedHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Sprint $sprintNum - Accomplished Work &amp; Evidence</title>
</head>
<body>
<header>
  <h1>Sprint $sprintNum - Accomplished Work &amp; Evidence</h1>
  <p>Created empty at sprint start on $generatedDate. Append one entry per completed unit of work.</p>
</header>
<main class="entries">
</main>
</body>
</html>
"@

        $proceduralDetailsHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Sprint $sprintNum - Procedural Details</title>
</head>
<body>
<header>
  <h1>Sprint $sprintNum - Procedural Details</h1>
  <p>Created empty at sprint start on $generatedDate. Add reusable procedures when they change.</p>
</header>
<main class="procedures">
</main>
</body>
</html>
"@

        if ($PSCmdlet.ShouldProcess($artifactPaths.Accomplished, 'Create empty accomplished-work companion')) {
          Set-Content -LiteralPath $artifactPaths.Accomplished -Value $accomplishedHtml -Encoding UTF8 -NoNewline
        }
        if ($PSCmdlet.ShouldProcess($artifactPaths.ProceduralDetails, 'Create empty procedural-details companion')) {
          Set-Content -LiteralPath $artifactPaths.ProceduralDetails -Value $proceduralDetailsHtml -Encoding UTF8 -NoNewline
        }

        $priorArtifactCandidates = @(
          "Tasks.Sprint$prevNum.md"
          "Tasks.Sprint$prevNum.html"
          "Tasks.Sprint$prevNum.Accomplished.html"
          "Tasks.Sprint$prevNum.ProceduralDetails.html"
          "TasksSprint$prevNum.md"
          "TasksSprint$prevNum.html"
          "Tasks.Accomplished.Sprint$prevNum.html"
          "Tasks.ProceduralDetails.Sprint$prevNum.html"
          'TASKS.md'
          'TASKS.html'
          'Tasks.Accomplished.html'
          'Tasks.ProceduralDetails.html'
        )

        foreach ($priorName in $priorArtifactCandidates | Select-Object -Unique) {
          $priorPath = Join-Path $planWorktreePath $priorName
          if ((Test-Path -LiteralPath $priorPath -PathType Leaf) -and
            ($priorPath -notin $artifactPaths.Values) -and
            $PSCmdlet.ShouldProcess($priorPath, 'Remove prior-sprint task artifact after templating')) {
            Remove-Item -LiteralPath $priorPath -Force
          }
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Created content-fresh sprint task artifacts from '$priorMarkdownPath': $($artifactNames.Values -join ', ')"
      }
    } catch {
      $errorMessage = "Failed to create sprint task artifacts. Exception: $($_.Exception.Message)"
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

      # FSS-56: Remove hard-coded template path fallback. Template must be in one of the expected locations.
      $templatePath = Join-Path $svWorktreePath 'NuGet.config.template'
      if (-not (Test-Path $templatePath)) {
        $templatePath = Join-Path $GitRoot 'SharedVSCode/NuGet.config.template'
      }

      if (-not (Test-Path $templatePath)) {
        throw "NuGet.config.template not found. Expected location: $(Join-Path $svWorktreePath 'NuGet.config.template') or $(Join-Path $GitRoot 'SharedVSCode/NuGet.config.template'). " +
              "Ensure SharedVSCode sprint worktree is initialized with required template files."
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
      -Message "Step 2 planning must replace the generated scaffold content in Tasks.Sprint$sprintNum.md, then synchronize Tasks.Sprint$sprintNum.html; Tasks.Sprint$sprintNum.Accomplished.html and Tasks.Sprint$sprintNum.ProceduralDetails.html start empty."

    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}

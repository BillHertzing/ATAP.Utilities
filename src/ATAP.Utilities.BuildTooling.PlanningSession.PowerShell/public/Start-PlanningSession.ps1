<#
.SYNOPSIS
    Begin a planning session: pull main, create a GitHub issue, open a worktree branch,
    generate the session document, and open VS Code — all in one command.

.DESCRIPTION
    Full Git-integrated planning session startup. Steps in order:

      1. Pull latest main in the _Planning repo
      2. Compute a collision-safe branch name  planning/YYYY-MM-DD[-HHmmss]
      3. Create a GitHub issue  "Planning Session YYYY-MM-DD" tagged [planning]
      4. Create a Git worktree at  <repos-parent>\_Planning-ws-YYYYMMDD[-HHmmss]
         on the new branch — this is where ALL session edits happen
      5. Parse pending inbox (and optionally deferred) items
      6. Generate the session document inside the worktree's Sessions\ folder
         (the doc header carries BranchName, IssueNumber, WorktreePath so
          Complete-PlanningSession can find everything without extra flags)
      7. Open VS Code with the worktree as the workspace root
      8. Print Claude upload instructions and the suggested opening prompt

    The planning branch is the ONLY approved way to modify TASKS.md and the
    sprint task HTML set (`TASKS.html`, `Tasks.Accomplished.html`,
    `Tasks.ProceduralDetails.html`).
    Complete-PlanningSession commits, pushes, opens a PR, squash-merges,
    and removes the worktree — targeting < 1 hour total elapsed time.

.PARAMETER IncludeDeferred
    Also pull in items with Status: Deferred so they can be reconsidered.

.PARAMETER SessionDate
    Override the session date (default: today). Format: YYYY-MM-DD.

.PARAMETER PlanFile
    Path to the weekly implementation plan. Defaults to searching the planning root.

.PARAMETER SkipVSCode
    Do not launch VS Code (useful in SSH / headless contexts).

.PARAMETER SkipGitHub
    Skip the GitHub issue creation (useful when gh CLI is not configured).
    A placeholder IssueNumber of 0 is written to the session doc.

.PARAMETER GhRepo
    GitHub repo in owner/name format. Defaults to auto-detection via gh repo view.

.OUTPUTS
    [void]

.EXAMPLE
    Start-PlanningSession
    # Standard weekly session — inbox items only, full Git workflow.

.EXAMPLE
    Start-PlanningSession -IncludeDeferred
    # Milestone review — reconsider deferred ideas too.

.EXAMPLE
    Start-PlanningSession -SkipGitHub -SkipVSCode
    # Offline / headless — worktree + session doc only, no GitHub or VS Code.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
function Start-PlanningSession {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([void])]
  param(
    [Parameter(Mandatory = $false)]
    [switch] $IncludeDeferred,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
    [string] $SessionDate = (Get-Date -Format 'yyyy-MM-dd'),

    [Parameter(Mandatory = $false)]
    [string] $PlanFile,

    [Parameter(Mandatory = $false)]
    [switch] $SkipVSCode,

    [Parameter(Mandatory = $false)]
    [switch] $SkipGitHub,

    [Parameter(Mandatory = $false)]
    [string] $GhRepo = ''
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = $MyInvocation.MyCommand.ModuleName

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function'

    # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: SessionDate)
    $SessionDate = Get-PVal -ParameterName SessionDate -originalPSBoundParameters $PSBoundParameters -dottedPath SessionDate -DefaultValue $SessionDate

    # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: PlanFile)
    $PlanFile = Get-PVal -ParameterName PlanFile -originalPSBoundParameters $PSBoundParameters -dottedPath PlanFile -DefaultValue $PlanFile

    # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: GhRepo)
    $GhRepo = Get-PVal -ParameterName GhRepo -originalPSBoundParameters $PSBoundParameters -dottedPath GhRepo -DefaultValue $GhRepo

    # ── Private helpers ────────────────────────────────────────────────────────

    function invokeGit {
      param([string]$WorkDir, [string[]]$GitArgs)
      if ($WhatIfPreference) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "[WhatIf] git -C '$WorkDir' $($GitArgs -join ' ')"
        return
      }
      $result = & git -C $WorkDir @GitArgs 2>&1
      if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed in $WorkDir`n$result" }
      return $result
    }

    function getScopeCreepEntries {
      param([string]$FilePath, [string[]]$Statuses)
      if (-not (Test-Path $FilePath)) { return @() }
      $content = Get-Content $FilePath -Raw
      $blocks  = [regex]::Split($content, '(?m)(?=^## SC-\d{4})')
      $entries = foreach ($block in $blocks) {
        if ($block -notmatch '(?m)^## SC-(\d{4})') { continue }
        $scId = "SC-$($Matches[1])"
        $Extr = { param([string]$F)
          if ($block -match "(?m)^\s*- \*\*$F\*\*:\s*(.+)$") { $Matches[1].Trim() } else { '' }
        }
        $status = & $Extr 'Status'
        if ($Statuses -notcontains $status) { continue }
        [PSCustomObject]@{
          ScId          = $scId
          Title         = & $Extr 'Title'
          SuggestedBy   = & $Extr 'SuggestedBy'
          SuggestedDate = & $Extr 'SuggestedDate'
          Repo          = & $Extr 'Repo'
          Context       = & $Extr 'Context'
          InitialSize   = & $Extr 'InitialSize'
          Tags          = & $Extr 'Tags'
          Status        = $status
          DeferredReason = & $Extr 'DeferredReason'
          Description   = if ($block -match '(?ms)- \*\*Description\*\*[^`n]*\n([\s\S]+?)(?=\n## SC-|\z)') {
            $Matches[1] -replace '(?m)^\s{2}', '' | ForEach-Object { $_.Trim() }
          } else { '' }
        }
      }
      return @($entries)
    }
  }

  process {
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'START PLANNING SESSION'

      # ════════════════════════════════════════════════════════════════════════
      # 1.  Locate the _Planning repo and plan file
      # ════════════════════════════════════════════════════════════════════════

      $planningRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent   # Powershell\Public\ → _Planning\
      $reposParent  = Split-Path $planningRoot -Parent                         # _Planning\ → repos root

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Planning repo: $planningRoot"

      if (-not $PlanFile) {
        $found    = Get-ChildItem $planningRoot -Filter 'AceCommander-Weekly-Implementation-Plan*.md' |
          Sort-Object Name -Descending | Select-Object -First 1
        $PlanFile = if ($found) { $found.FullName } else { $null }
      }

      # ════════════════════════════════════════════════════════════════════════
      # 2.  Pull latest main
      # ════════════════════════════════════════════════════════════════════════

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Fetching and pulling main...'
      try {
        $defaultBranch = (invokeGit $planningRoot @('symbolic-ref', 'refs/remotes/origin/HEAD')) `
          -replace 'refs/remotes/origin/', ''
        if (-not $defaultBranch) { $defaultBranch = 'main' }

        invokeGit $planningRoot @('checkout', $defaultBranch) | Out-Null
        invokeGit $planningRoot @('pull', 'origin', $defaultBranch) | Out-Null
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Up to date with origin/$defaultBranch"
      }
      catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "Could not pull: $_ — continuing on current HEAD; ensure you are on main before merging."
        $defaultBranch = 'main'
      }

      # ════════════════════════════════════════════════════════════════════════
      # 3.  Determine collision-safe branch name and worktree path
      # ════════════════════════════════════════════════════════════════════════

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Computing branch name...'

      $baseBranch = "planning/$SessionDate"
      $datePart   = $SessionDate -replace '-', ''

      $existingBranches  = & git -C $planningRoot branch --list "planning/$SessionDate*" 2>$null
      $existingBranches += & git -C $planningRoot branch -r --list "origin/planning/$SessionDate*" 2>$null

      if ($existingBranches | Where-Object { $_ -match "planning/$([regex]::Escape($SessionDate))$" }) {
        $timeSuffix = Get-Date -Format 'HHmmss'
        $branchName = "planning/$SessionDate-$timeSuffix"
        $wsSuffix   = "$datePart-$timeSuffix"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "Branch $baseBranch already exists — using $branchName"
      } else {
        $branchName = $baseBranch
        $wsSuffix   = $datePart
      }

      $worktreePath = Join-Path $reposParent "_Planning-ws-$wsSuffix"

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Branch: $branchName  Worktree: $worktreePath"

      # ════════════════════════════════════════════════════════════════════════
      # 4.  Create GitHub issue
      # ════════════════════════════════════════════════════════════════════════

      $issueNumber = 0

      if (-not $SkipGitHub) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Creating GitHub issue...'
        try {
          if (-not $GhRepo) {
            $GhRepo = (& gh repo view --json nameWithOwner -q '.nameWithOwner' 2>$null)
          }

          $issueTitle = "Planning Session $SessionDate"
          $issueBody  = @"
## Automated Planning Session

**Branch**: ``$branchName``
**Session date**: $SessionDate
**Type**: $(if ($IncludeDeferred) { 'Full review (inbox + deferred)' } else { 'Standard (inbox items only)' })

This issue is opened automatically by ``Start-PlanningSession`` and closed by ``Complete-PlanningSession`` via PR merge.

### Scope
- Triage all inbox scope-creep ideas
- Update TASKS.md with any adopted changes
- Amend the weekly implementation plan as required

_Do not edit this issue manually._
"@

          if ($PSCmdlet.ShouldProcess("$GhRepo", "Create GitHub issue '$issueTitle'")) {
            $issueUrl = & gh issue create `
              --title $issueTitle `
              --body $issueBody `
              --label 'planning' `
              --repo $GhRepo 2>&1

            if ($LASTEXITCODE -eq 0 -and $issueUrl -match '/(\d+)$') {
              $issueNumber = [int]$Matches[1]
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Issue #$issueNumber created: $issueUrl"
            } else {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "gh issue create returned unexpected output: $issueUrl — continuing with IssueNumber = 0."
            }
          }
        }
        catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "GitHub issue creation failed: $_ — install/configure gh CLI for full automation. Continuing without a GitHub issue."
        }
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message 'Skipping GitHub issue (SkipGitHub flag set). IssueNumber = 0.'
      }

      # ════════════════════════════════════════════════════════════════════════
      # 5.  Create Git worktree
      # ════════════════════════════════════════════════════════════════════════

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Creating worktree on branch $branchName..."

      if (Test-Path $worktreePath) {
        throw "Worktree path already exists: $worktreePath — remove it first with: git -C '$planningRoot' worktree remove '$worktreePath' --force"
      }

      if ($PSCmdlet.ShouldProcess($worktreePath, "Create git worktree on branch '$branchName'")) {
        try {
          invokeGit $planningRoot @('worktree', 'add', $worktreePath, '-b', $branchName) | Out-Null
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Worktree ready at $worktreePath"
        }
        catch {
          throw "Worktree creation failed: $_"
        }
      }

      # ════════════════════════════════════════════════════════════════════════
      # 6.  Collect scope-creep items (read from MAIN repo — writes go to worktree)
      # ════════════════════════════════════════════════════════════════════════

      $inboxPath    = Join-Path $planningRoot 'ScopeCreepManagement' 'ScopeCreep-Inbox.md'
      $deferredPath = Join-Path $planningRoot 'ScopeCreepManagement' 'ScopeCreep-Deferred.md'

      $statusFilter = if ($IncludeDeferred) { @('Inbox', 'Deferred') } else { @('Inbox') }
      $items = getScopeCreepEntries -FilePath $inboxPath -Statuses $statusFilter

      if ($IncludeDeferred -and (Test-Path $deferredPath)) {
        $deferredItems = getScopeCreepEntries -FilePath $deferredPath -Statuses @('Deferred')
        $items = @($items) + @($deferredItems)
      }
      $items = @($items)

      if ($items.Count -eq 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "No pending ideas in Inbox$(if ($IncludeDeferred) { ' or Deferred' }). Run Add-ScopeCreepIdea to capture ideas, or the session will be empty. Continuing anyway."
      }

      # ════════════════════════════════════════════════════════════════════════
      # 7.  Determine session number (count existing session files)
      # ════════════════════════════════════════════════════════════════════════

      $sessionsDirMain = Join-Path $planningRoot 'ReplanningNotebooks'
      if (-not (Test-Path $sessionsDirMain)) { New-Item -ItemType Directory -Path $sessionsDirMain | Out-Null }

      $existingSessions = Get-ChildItem $sessionsDirMain -Filter '*-Session.md' -ErrorAction SilentlyContinue
      $sessionNum       = 'SESSION-{0:D4}' -f ($existingSessions.Count + 1)

      $sessionsDirWt = Join-Path $worktreePath 'ReplanningNotebooks'
      if (-not (Test-Path $sessionsDirWt)) { New-Item -ItemType Directory -Path $sessionsDirWt | Out-Null }

      $sessionFileName = "$SessionDate-Session.md"
      if ($branchName -match 'planning/\d{4}-\d{2}-\d{2}-(\d{6})$') {
        $sessionFileName = "$SessionDate-$($Matches[1])-Session.md"
      }
      $sessionFile = Join-Path $sessionsDirWt $sessionFileName

      # ════════════════════════════════════════════════════════════════════════
      # 8.  Build the session document
      # ════════════════════════════════════════════════════════════════════════

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Generating session document...'

      $sb = [System.Text.StringBuilder]::new()

      $null = $sb.AppendLine("# Planning Session — $SessionDate")
      $null = $sb.AppendLine()
      $null = $sb.AppendLine('<!-- Git metadata — do not edit manually -->')
      $null = $sb.AppendLine('| Field | Value |')
      $null = $sb.AppendLine('|-------|-------|')
      $null = $sb.AppendLine("| **SessionId** | $sessionNum |")
      $null = $sb.AppendLine("| **Date** | $SessionDate |")
      $null = $sb.AppendLine('| **Facilitator** | |')
      $null = $sb.AppendLine('| **Status** | In-Progress |')
      $null = $sb.AppendLine("| **BranchName** | $branchName |")
      $null = $sb.AppendLine("| **IssueNumber** | $issueNumber |")
      $null = $sb.AppendLine("| **WorktreePath** | $worktreePath |")
      $null = $sb.AppendLine("| **ItemsInbox** | $(($items | Where-Object Status -EQ 'Inbox').Count) |")
      if ($IncludeDeferred) {
        $null = $sb.AppendLine("| **ItemsDeferred** | $(($items | Where-Object Status -EQ 'Deferred').Count) |")
      }
      $null = $sb.AppendLine('| **PreviousProjectEnd** | Week 23 _(update if prior amendments changed this)_ |')
      $null = $sb.AppendLine()
      $null = $sb.AppendLine('---')
      $null = $sb.AppendLine()

      if ($items.Count -gt 0) {
        $null = $sb.AppendLine('## Ideas for Review')
        $null = $sb.AppendLine()

        foreach ($item in $items) {
          $deferTag = if ($item.Status -eq 'Deferred') { ' 🔁 _(was Deferred)_' } else { '' }

          $null = $sb.AppendLine("### $($item.ScId) — $($item.Title)$deferTag")
          $null = $sb.AppendLine()
          $tagsDisplay = if ($item.Tags) { " | **Tags**: $($item.Tags)" } else { '' }
          $null = $sb.AppendLine("> **SuggestedBy**: $($item.SuggestedBy) | **Date**: $($item.SuggestedDate) | **Repo**: $($item.Repo) | **Size**: $($item.InitialSize)$tagsDisplay")
          $null = $sb.AppendLine("> **Context**: $($item.Context)")
          if ($item.DeferredReason) {
            $null = $sb.AppendLine("> **Prior defer reason**: $($item.DeferredReason)")
          }
          $null = $sb.AppendLine('>')
          $null = $sb.AppendLine("> $($item.Description)")
          $null = $sb.AppendLine()
          $null = $sb.AppendLine("**Decision**: ``[ ] Adopt  [ ] Defer  [ ] Reject``")
          $null = $sb.AppendLine()
          $null = $sb.AppendLine('**Rationale**:')
          $null = $sb.AppendLine()
          $null = $sb.AppendLine('**If Adopted**:')
          $null = $sb.AppendLine('- InsertAt: _(e.g. Week 9, after Task 9.2)_')
          $null = $sb.AppendLine('- ImpactWeeks: _(e.g. +1)_')
          $null = $sb.AppendLine("- MilestonesAffected: _(list any ◆ diamonds that shift, or 'none')_")
          $null = $sb.AppendLine('- NewProjectEnd: _(running total, e.g. Week 24)_')
          $null = $sb.AppendLine('- TasksAdded: _(brief list of new TASKS.md entries)_')
          $null = $sb.AppendLine()
          $null = $sb.AppendLine('**If Deferred**:')
          $null = $sb.AppendLine('- DeferredReason:')
          $null = $sb.AppendLine('- DeferredUntil: _(e.g. After Week 15, or At Milestone 3)_')
          $null = $sb.AppendLine()
          $null = $sb.AppendLine('---')
          $null = $sb.AppendLine()
        }
      } else {
        $null = $sb.AppendLine('## Ideas for Review')
        $null = $sb.AppendLine()
        $null = $sb.AppendLine('_(No inbox items — this is a milestone review or TASKS.md update session)_')
        $null = $sb.AppendLine()
        $null = $sb.AppendLine('---')
        $null = $sb.AppendLine()
      }

      $null = $sb.AppendLine('## TASKS.md Changes')
      $null = $sb.AppendLine()
      $null = $sb.AppendLine('_(List any TASKS.md edits made this session — even if no SC ideas were adopted)_')
      $null = $sb.AppendLine()
      $null = $sb.AppendLine('| Repo | Task ID | Change | Reason |')
      $null = $sb.AppendLine('|------|---------|--------|--------|')
      $null = $sb.AppendLine('| | | | |')
      $null = $sb.AppendLine()
      $null = $sb.AppendLine('---')
      $null = $sb.AppendLine()
      $null = $sb.AppendLine('## Sprint Task Artifact Set')
      $null = $sb.AppendLine()
      $null = $sb.AppendLine('- Active board: `TASKS.html`, or the highest `TASKS_V*.html` if any versioned boards exist.')
      $null = $sb.AppendLine('- Work log: `Tasks.Accomplished.html` (starts empty; append concrete work/evidence as tasks progress).')
      $null = $sb.AppendLine('- Carry-forward procedure log: `Tasks.ProceduralDetails.html` (seed with reusable procedure notes carried from the prior sprint).')
      $null = $sb.AppendLine('- If the board is rebaselined mid-sprint, copy the current board to the next `TASKS_Vx.html`; the highest version becomes active.')
      $null = $sb.AppendLine('- Keep `TASKS.md` synchronized with the active HTML board until downstream automation stops reading `TASKS.md`.')
      $null = $sb.AppendLine()
      $null = $sb.AppendLine('---')
      $null = $sb.AppendLine()
      $null = $sb.AppendLine('## Tags Taxonomy Review')
      $null = $sb.AppendLine()
      $null = $sb.AppendLine('_(Optional — review Tags-Taxonomy.md during this session if new tags were proposed)_')
      $null = $sb.AppendLine()
      $null = $sb.AppendLine('| Action | Tag | Domain | Rationale |')
      $null = $sb.AppendLine('|--------|-----|--------|-----------|')
      $null = $sb.AppendLine('| | | | |')
      $null = $sb.AppendLine()
      $null = $sb.AppendLine('Actions: **Ratify** (move from Proposed to hierarchy) | **Rename** | **Merge** (combine two tags) | **Propose** (add to Proposed table)')
      $null = $sb.AppendLine()
      $null = $sb.AppendLine('---')
      $null = $sb.AppendLine()
      $null = $sb.AppendLine('## Session Summary')
      $null = $sb.AppendLine()
      $null = $sb.AppendLine('_(Fill in after all decisions are made — before running Complete-PlanningSession)_')
      $null = $sb.AppendLine()
      $null = $sb.AppendLine('| Metric | Value |')
      $null = $sb.AppendLine('|--------|-------|')
      $null = $sb.AppendLine("| Ideas Reviewed | $($items.Count) |")
      $null = $sb.AppendLine('| Adopted | |')
      $null = $sb.AppendLine('| Deferred | |')
      $null = $sb.AppendLine('| Rejected | |')
      $null = $sb.AppendLine('| Total Schedule Impact | |')
      $null = $sb.AppendLine('| Previous Project End | Week 23 |')
      $null = $sb.AppendLine('| New Project End | |')
      $null = $sb.AppendLine('| TASKS.md Updated | Yes / No |')
      $null = $sb.AppendLine('| Notes | |')

      if ($PSCmdlet.ShouldProcess($sessionFile, 'Write session document')) {
        Set-Content -Path $sessionFile -Value $sb.ToString() -Encoding UTF8
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Session document: $sessionFile ($($items.Count) item(s) | $sessionNum)"
      }

      # ════════════════════════════════════════════════════════════════════════
      # 9.  Open VS Code in the worktree
      # ════════════════════════════════════════════════════════════════════════

      if (-not $SkipVSCode) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Opening VS Code...'

        $filesToOpen = @($sessionFile)
        $wtInbox     = Join-Path $worktreePath 'ScopeCreepManagement' 'ScopeCreep-Inbox.md'
        if (Test-Path $wtInbox) { $filesToOpen += $wtInbox }
        $wtTasks = Join-Path $worktreePath 'TASKS.md'
        if (Test-Path $wtTasks) { $filesToOpen += $wtTasks }
        $wtTaskBoard = Join-Path $worktreePath 'TASKS.html'
        if (Test-Path $wtTaskBoard) { $filesToOpen += $wtTaskBoard }
        $versionedBoards = @(Get-ChildItem -LiteralPath $worktreePath -Filter 'TASKS_V*.html' -File -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending)
        if ($versionedBoards.Count -gt 0) { $filesToOpen += $versionedBoards[0].FullName }
        foreach ($artifactLeaf in @('Tasks.Accomplished.html', 'Tasks.ProceduralDetails.html')) {
          $artifactPath = Join-Path $worktreePath $artifactLeaf
          if (Test-Path $artifactPath) { $filesToOpen += $artifactPath }
        }
        if ($PlanFile) {
          $wtPlan = Join-Path $worktreePath (Split-Path $PlanFile -Leaf)
          if (Test-Path $wtPlan) { $filesToOpen += $wtPlan }
          elseif (Test-Path $PlanFile) { $filesToOpen += $PlanFile }
        }

        try {
          & code --new-window $worktreePath
          Start-Sleep -Milliseconds 800
          foreach ($f in $filesToOpen) { & code --reuse-window $f }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "VS Code opened: $worktreePath"
        }
        catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "Could not launch VS Code (is 'code' in PATH?). Open manually: $worktreePath"
        }
      }

      # ════════════════════════════════════════════════════════════════════════
      # 10.  Next-step instructions
      # ════════════════════════════════════════════════════════════════════════

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'NEXT STEPS'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Working branch: $branchName  |  Worktree: $worktreePath$(if ($issueNumber -gt 0) { "  |  Issue: #$issueNumber (closed by PR merge)" })"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'ALL edits during this session go in the worktree, not in main. Use the sprint task artifact set there: active board (`TASKS.html` or highest `TASKS_V*.html`), `Tasks.Accomplished.html`, and `Tasks.ProceduralDetails.html`.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Keep `TASKS.md` synchronized with the active HTML board until downstream automation stops reading `TASKS.md`.'

      $claudeFiles = "1. $sessionFileName"
      if ($PlanFile) { $claudeFiles += " | 2. $(Split-Path $PlanFile -Leaf)" }
      $claudeFiles += ' | 3. TASKS.md | 4. active task board (`TASKS.html` or latest `TASKS_V*.html`) | 5. Tasks.Accomplished.html | 6. Tasks.ProceduralDetails.html | 7. ScopeCreep-Adopted.md (duplicate detection)'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Upload to Claude project: $claudeFiles"

      $claudePrompt = '"Here is today''s scope-creep triage session. For each idea: 1. Recommend Adopt, Defer, or Reject with a brief rationale. 2. For Adopted ideas: InsertAt, ImpactWeeks, milestone shifts, NewProjectEnd, TASKS.md entries, and any required updates to the active sprint task board plus its Accomplished/ProceduralDetails companions. 3. Check ScopeCreep-Adopted.md for near-duplicates before adopting. 4. Produce a completed session document. 5. Produce the updated TASKS.md and task-board sections for any adopted ideas."'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Suggested Claude opening prompt: $claudePrompt"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "When done, run: Complete-PlanningSession -SessionFile '$sessionFileName'"
    }
    catch {
      $errorMessage = "Start-PlanningSession failed. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function'
  }
}

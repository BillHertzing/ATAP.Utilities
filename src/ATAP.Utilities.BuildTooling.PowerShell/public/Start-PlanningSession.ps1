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
          Complete-PlanningSession.ps1 can find everything without extra flags)
      7. Open VS Code with the worktree as the workspace root
      8. Print Claude upload instructions and the suggested opening prompt

    The planning branch is the ONLY approved way to modify TASKS.md.
    Complete-PlanningSession.ps1 commits, pushes, opens a PR, squash-merges,
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
    GitHub repo in owner/name format.  Defaults to auto-detection via  gh repo view.

.EXAMPLE
    .\Start-PlanningSession.ps1
    # Standard weekly session — inbox items only, full Git workflow.

.EXAMPLE
    .\Start-PlanningSession.ps1 -IncludeDeferred
    # Milestone review — reconsider deferred ideas too.

.EXAMPLE
    .\Start-PlanningSession.ps1 -SkipGitHub -SkipVSCode
    # Offline / headless — worktree + session doc only, no GitHub or VS Code.
#>

[CmdletBinding()]
param(
    [switch]$IncludeDeferred,

    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
    [string]$SessionDate = (Get-Date -Format 'yyyy-MM-dd'),

    [string]$PlanFile,

    [switch]$SkipVSCode,

    [switch]$SkipGitHub,

    [string]$GhRepo = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ════════════════════════════════════════════════════════════════════════════
# 0.  Helpers
# ════════════════════════════════════════════════════════════════════════════

function Write-Step { param([string]$Msg) Write-Host "  ► $Msg" -ForegroundColor Cyan }
function Write-OK { param([string]$Msg) Write-Host "  ✓ $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "  ⚠ $Msg" -ForegroundColor Yellow }
function Write-Info { param([string]$Msg) Write-Host "    $Msg" -ForegroundColor DarkGray }
function Write-Rule { Write-Host ("  " + "═" * 55) -ForegroundColor DarkCyan }
function Write-Header([string]$T) { Write-Rule; Write-Host "   $T" -ForegroundColor Cyan; Write-Rule }

function Invoke-Git {
    param([string]$WorkDir, [string[]]$GitArgs)
    $result = & git -C $WorkDir @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed in $WorkDir`n$result" }
    return $result
}

function Get-ScopeCreepEntries {
    param([string]$FilePath, [string[]]$Statuses)
    if (-not (Test-Path $FilePath)) { return @() }
    $content = Get-Content $FilePath -Raw
    $blocks = [regex]::Split($content, '(?m)(?=^## SC-\d{4})')
    $entries = foreach ($block in $blocks) {
        if ($block -notmatch '(?m)^## SC-(\d{4})') { continue }
        $scId = "SC-$($Matches[1])"
        $Extr = { param([string]$F)
            if ($block -match "(?m)^\s*- \*\*$F\*\*:\s*(.+)$") { $Matches[1].Trim() } else { '' }
        }
        $status = & $Extr 'Status'
        if ($Statuses -notcontains $status) { continue }
        [PSCustomObject]@{
            ScId           = $scId
            Title          = & $Extr 'Title'
            SuggestedBy    = & $Extr 'SuggestedBy'
            SuggestedDate  = & $Extr 'SuggestedDate'
            Repo           = & $Extr 'Repo'
            Context        = & $Extr 'Context'
            InitialSize    = & $Extr 'InitialSize'
            Tags           = & $Extr 'Tags'
            Status         = $status
            DeferredReason = & $Extr 'DeferredReason'
            Description    = if ($block -match '(?ms)- \*\*Description\*\*[^`n]*\n([\s\S]+?)(?=\n## SC-|\z)') {
                $Matches[1] -replace '(?m)^\s{2}', '' | ForEach-Object { $_.Trim() }
            }
            else { '' }
        }
    }
    return @($entries)
}

# ════════════════════════════════════════════════════════════════════════════
# 1.  Locate the _Planning repo and plan file
# ════════════════════════════════════════════════════════════════════════════

$planningRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent   # Powershell\Public\ → _Planning\
$reposParent = Split-Path $planningRoot -Parent                          # _Planning\ → repos root

Write-Host ""
Write-Header "START PLANNING SESSION"
Write-Host ""

Write-Step "Planning repo: $planningRoot"

if (-not $PlanFile) {
    $found = Get-ChildItem $planningRoot -Filter 'AceCommander-Weekly-Implementation-Plan*.md' |
    Sort-Object Name -Descending | Select-Object -First 1
    $PlanFile = if ($found) { $found.FullName } else { $null }
}

# ════════════════════════════════════════════════════════════════════════════
# 2.  Pull latest main
# ════════════════════════════════════════════════════════════════════════════

Write-Step "Fetching and pulling main..."
try {
    # Determine default branch name (main or master)
    $defaultBranch = (Invoke-Git $planningRoot @('symbolic-ref', 'refs/remotes/origin/HEAD')) `
        -replace 'refs/remotes/origin/', ''
    if (-not $defaultBranch) { $defaultBranch = 'main' }

    Invoke-Git $planningRoot @('checkout', $defaultBranch) | Out-Null
    Invoke-Git $planningRoot @('pull', 'origin', $defaultBranch) | Out-Null
    Write-OK "Up to date with origin/$defaultBranch"
}
catch {
    Write-Warn "Could not pull: $_"
    Write-Warn "Continuing on current HEAD — ensure you are on main before merging."
    $defaultBranch = 'main'
}

# ════════════════════════════════════════════════════════════════════════════
# 3.  Determine collision-safe branch name and worktree path
# ════════════════════════════════════════════════════════════════════════════

Write-Step "Computing branch name..."

$baseBranch = "planning/$SessionDate"
$datePart = $SessionDate -replace '-', ''         # 20260316

# List existing remote + local branches to detect same-day collision
$existingBranches = & git -C $planningRoot branch --list "planning/$SessionDate*" 2>$null
$existingBranches += & git -C $planningRoot branch -r --list "origin/planning/$SessionDate*" 2>$null

if ($existingBranches | Where-Object { $_ -match "planning/$([regex]::Escape($SessionDate))$" }) {
    $timeSuffix = Get-Date -Format 'HHmmss'
    $branchName = "planning/$SessionDate-$timeSuffix"
    $wsSuffix = "$datePart-$timeSuffix"
    Write-Warn "Branch $baseBranch already exists — using $branchName"
}
else {
    $branchName = $baseBranch
    $wsSuffix = $datePart
}

$worktreePath = Join-Path $reposParent "_Planning-ws-$wsSuffix"

Write-OK "Branch  : $branchName"
Write-Info "Worktree: $worktreePath"

# ════════════════════════════════════════════════════════════════════════════
# 4.  Create GitHub issue
# ════════════════════════════════════════════════════════════════════════════

$issueNumber = 0

if (-not $SkipGitHub) {
    Write-Step "Creating GitHub issue..."
    try {
        # Auto-detect repo if not provided
        if (-not $GhRepo) {
            $GhRepo = (& gh repo view --json nameWithOwner -q '.nameWithOwner' 2>$null)
        }

        $issueTitle = "Planning Session $SessionDate"
        $issueBody = @"
## Automated Planning Session

**Branch**: \`$branchName\`
**Session date**: $SessionDate
**Type**: $(if ($IncludeDeferred) { 'Full review (inbox + deferred)' } else { 'Standard (inbox items only)' })

This issue is opened automatically by \`Start-PlanningSession.ps1\` and closed by \`Complete-PlanningSession.ps1\` via PR merge.

### Scope
- Triage all inbox scope-creep ideas
- Update TASKS.md with any adopted changes
- Amend the weekly implementation plan as required

_Do not edit this issue manually._
"@

        $issueUrl = & gh issue create `
            --title $issueTitle `
            --body  $issueBody  `
            --label 'planning'  `
            --repo  $GhRepo     2>&1

        if ($LASTEXITCODE -eq 0 -and $issueUrl -match '/(\d+)$') {
            $issueNumber = [int]$Matches[1]
            Write-OK "Issue #$issueNumber created: $issueUrl"
        }
        else {
            Write-Warn "gh issue create returned unexpected output: $issueUrl"
            Write-Warn "Continuing with IssueNumber = 0. Create the issue manually if needed."
        }
    }
    catch {
        Write-Warn "GitHub issue creation failed: $_"
        Write-Warn "Install/configure gh CLI (https://cli.github.com) for full automation."
        Write-Warn "Continuing without a GitHub issue."
    }
}
else {
    Write-Warn "Skipping GitHub issue (SkipGitHub flag set). IssueNumber = 0."
}

# ════════════════════════════════════════════════════════════════════════════
# 5.  Create Git worktree
# ════════════════════════════════════════════════════════════════════════════

Write-Step "Creating worktree on branch $branchName..."

if (Test-Path $worktreePath) {
    Write-Warn "Worktree path already exists: $worktreePath"
    Write-Warn "Remove it first with:  git -C '$planningRoot' worktree remove '$worktreePath' --force"
    exit 1
}

try {
    Invoke-Git $planningRoot @('worktree', 'add', $worktreePath, '-b', $branchName) | Out-Null
    Write-OK "Worktree ready at $worktreePath"
}
catch {
    Write-Host "  ✗ Worktree creation failed: $_" -ForegroundColor Red
    exit 1
}

# ════════════════════════════════════════════════════════════════════════════
# 6.  Collect scope-creep items  (read from MAIN repo, not worktree —
#     the files are identical at this point; writes go to the worktree)
# ════════════════════════════════════════════════════════════════════════════

$inboxPath = Join-Path $planningRoot 'ScopeCreepManagement' 'ScopeCreep-Inbox.md'
$deferredPath = Join-Path $planningRoot 'ScopeCreepManagement' 'ScopeCreep-Deferred.md'

$statusFilter = if ($IncludeDeferred) { @('Inbox', 'Deferred') } else { @('Inbox') }
$items = Get-ScopeCreepEntries -FilePath $inboxPath -Statuses $statusFilter

if ($IncludeDeferred -and (Test-Path $deferredPath)) {
    $deferredItems = Get-ScopeCreepEntries -FilePath $deferredPath -Statuses @('Deferred')
    $items = @($items) + @($deferredItems)
}
$items = @($items)

if ($items.Count -eq 0) {
    Write-Warn "No pending ideas in Inbox$(if ($IncludeDeferred){' or Deferred'})."
    Write-Warn "Run Add-ScopeCreepIdea.ps1 to capture ideas, or the session will be empty."
    # Continue anyway — you may still want to update TASKS.md or do a milestone review
}

# ════════════════════════════════════════════════════════════════════════════
# 7.  Determine session number  (count existing session files)
# ════════════════════════════════════════════════════════════════════════════

$sessionsDirMain = Join-Path $planningRoot 'ReplanningNotebooks'
if (-not (Test-Path $sessionsDirMain)) { New-Item -ItemType Directory -Path $sessionsDirMain | Out-Null }

$existingSessions = Get-ChildItem $sessionsDirMain -Filter '*-Session.md' -ErrorAction SilentlyContinue
$sessionNum = 'SESSION-{0:D4}' -f ($existingSessions.Count + 1)

# Session and amendments files live in the WORKTREE
$sessionsDirWt = Join-Path $worktreePath 'ReplanningNotebooks'
if (-not (Test-Path $sessionsDirWt)) { New-Item -ItemType Directory -Path $sessionsDirWt | Out-Null }

$sessionFileName = "$SessionDate-Session.md"
# Disambiguate filename when branch has time suffix
if ($branchName -match 'planning/\d{4}-\d{2}-\d{2}-(\d{6})$') {
    $sessionFileName = "$SessionDate-$($Matches[1])-Session.md"
}
$sessionFile = Join-Path $sessionsDirWt $sessionFileName

# ════════════════════════════════════════════════════════════════════════════
# 8.  Build the session document
# ════════════════════════════════════════════════════════════════════════════

Write-Step "Generating session document..."

$sb = [System.Text.StringBuilder]::new()

$null = $sb.AppendLine("# Planning Session — $SessionDate")
$null = $sb.AppendLine()
$null = $sb.AppendLine("<!-- Git metadata — do not edit manually -->")
$null = $sb.AppendLine("| Field | Value |")
$null = $sb.AppendLine("|-------|-------|")
$null = $sb.AppendLine("| **SessionId** | $sessionNum |")
$null = $sb.AppendLine("| **Date** | $SessionDate |")
$null = $sb.AppendLine("| **Facilitator** | |")
$null = $sb.AppendLine("| **Status** | In-Progress |")
$null = $sb.AppendLine("| **BranchName** | $branchName |")
$null = $sb.AppendLine("| **IssueNumber** | $issueNumber |")
$null = $sb.AppendLine("| **WorktreePath** | $worktreePath |")
$null = $sb.AppendLine("| **ItemsInbox** | $(($items | Where-Object Status -eq 'Inbox').Count) |")
if ($IncludeDeferred) {
    $null = $sb.AppendLine("| **ItemsDeferred** | $(($items | Where-Object Status -eq 'Deferred').Count) |")
}
$null = $sb.AppendLine("| **PreviousProjectEnd** | Week 23 _(update if prior amendments changed this)_ |")
$null = $sb.AppendLine()
$null = $sb.AppendLine("---")
$null = $sb.AppendLine()

if ($items.Count -gt 0) {
    $null = $sb.AppendLine("## Ideas for Review")
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
        $null = $sb.AppendLine(">")
        $null = $sb.AppendLine("> $($item.Description)")
        $null = $sb.AppendLine()
        $null = $sb.AppendLine("**Decision**: ``[ ] Adopt  [ ] Defer  [ ] Reject``")
        $null = $sb.AppendLine()
        $null = $sb.AppendLine("**Rationale**:")
        $null = $sb.AppendLine()
        $null = $sb.AppendLine("**If Adopted**:")
        $null = $sb.AppendLine("- InsertAt: _(e.g. Week 9, after Task 9.2)_")
        $null = $sb.AppendLine("- ImpactWeeks: _(e.g. +1)_")
        $null = $sb.AppendLine("- MilestonesAffected: _(list any ◆ diamonds that shift, or 'none')_")
        $null = $sb.AppendLine("- NewProjectEnd: _(running total, e.g. Week 24)_")
        $null = $sb.AppendLine("- TasksAdded: _(brief list of new TASKS.md entries)_")
        $null = $sb.AppendLine()
        $null = $sb.AppendLine("**If Deferred**:")
        $null = $sb.AppendLine("- DeferredReason:")
        $null = $sb.AppendLine("- DeferredUntil: _(e.g. After Week 15, or At Milestone 3)_")
        $null = $sb.AppendLine()
        $null = $sb.AppendLine("---")
        $null = $sb.AppendLine()
    }
}
else {
    $null = $sb.AppendLine("## Ideas for Review")
    $null = $sb.AppendLine()
    $null = $sb.AppendLine("_(No inbox items — this is a milestone review or TASKS.md update session)_")
    $null = $sb.AppendLine()
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine()
}

$null = $sb.AppendLine("## TASKS.md Changes")
$null = $sb.AppendLine()
$null = $sb.AppendLine("_(List any TASKS.md edits made this session — even if no SC ideas were adopted)_")
$null = $sb.AppendLine()
$null = $sb.AppendLine("| Repo | Task ID | Change | Reason |")
$null = $sb.AppendLine("|------|---------|--------|--------|")
$null = $sb.AppendLine("| | | | |")
$null = $sb.AppendLine()
$null = $sb.AppendLine("---")
$null = $sb.AppendLine()
$null = $sb.AppendLine("## Tags Taxonomy Review")
$null = $sb.AppendLine()
$null = $sb.AppendLine("_(Optional — review Tags-Taxonomy.md during this session if new tags were proposed)_")
$null = $sb.AppendLine()
$null = $sb.AppendLine("| Action | Tag | Domain | Rationale |")
$null = $sb.AppendLine("|--------|-----|--------|-----------|")
$null = $sb.AppendLine("| | | | |")
$null = $sb.AppendLine()
$null = $sb.AppendLine("Actions: **Ratify** (move from Proposed to hierarchy) | **Rename** | **Merge** (combine two tags) | **Propose** (add to Proposed table)")
$null = $sb.AppendLine()
$null = $sb.AppendLine("---")
$null = $sb.AppendLine()
$null = $sb.AppendLine("## Session Summary")
$null = $sb.AppendLine()
$null = $sb.AppendLine("_(Fill in after all decisions are made — before running Complete-PlanningSession.ps1)_")
$null = $sb.AppendLine()
$null = $sb.AppendLine("| Metric | Value |")
$null = $sb.AppendLine("|--------|-------|")
$null = $sb.AppendLine("| Ideas Reviewed | $($items.Count) |")
$null = $sb.AppendLine("| Adopted | |")
$null = $sb.AppendLine("| Deferred | |")
$null = $sb.AppendLine("| Rejected | |")
$null = $sb.AppendLine("| Total Schedule Impact | |")
$null = $sb.AppendLine("| Previous Project End | Week 23 |")
$null = $sb.AppendLine("| New Project End | |")
$null = $sb.AppendLine("| TASKS.md Updated | Yes / No |")
$null = $sb.AppendLine("| Notes | |")

Set-Content -Path $sessionFile -Value $sb.ToString() -Encoding UTF8

Write-OK "Session document: $sessionFile"
Write-Info "($($items.Count) item(s) | $sessionNum)"

# ════════════════════════════════════════════════════════════════════════════
# 9.  Open VS Code in the worktree
# ════════════════════════════════════════════════════════════════════════════

if (-not $SkipVSCode) {
    Write-Step "Opening VS Code..."

    # Collect key files to open as tabs alongside the workspace folder
    $filesToOpen = @($sessionFile)
    $wtInbox = Join-Path $worktreePath 'ScopeCreepManagement' 'ScopeCreep-Inbox.md'
    if (Test-Path $wtInbox) { $filesToOpen += $wtInbox }
    $wtTasks = Join-Path $worktreePath 'TASKS.md'
    if (Test-Path $wtTasks) { $filesToOpen += $wtTasks }
    if ($PlanFile) {
        $wtPlan = Join-Path $worktreePath (Split-Path $PlanFile -Leaf)
        if (Test-Path $wtPlan) { $filesToOpen += $wtPlan }
        elseif (Test-Path $PlanFile) { $filesToOpen += $PlanFile }
    }

    try {
        # Open the worktree as the workspace root, then open files as tabs
        & code --new-window $worktreePath
        Start-Sleep -Milliseconds 800    # give VS Code a moment to start
        foreach ($f in $filesToOpen) { & code --reuse-window $f }
        Write-OK "VS Code opened: $worktreePath"
    }
    catch {
        Write-Warn "Could not launch VS Code (is 'code' in PATH?). Open manually: $worktreePath"
    }
}

# ════════════════════════════════════════════════════════════════════════════
# 10.  Instructions
# ════════════════════════════════════════════════════════════════════════════

Write-Host ""
Write-Header "NEXT STEPS"
Write-Host ""

Write-Host "  You are now working in the planning branch:" -ForegroundColor White
Write-Host "    Branch   : $branchName" -ForegroundColor Yellow
Write-Host "    Worktree : $worktreePath" -ForegroundColor Yellow
if ($issueNumber -gt 0) {
    Write-Host "    Issue    : #$issueNumber (will be closed by PR merge)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  ALL edits during this session go in the worktree, not in main." -ForegroundColor White
Write-Host "  TASKS.md in the worktree is the approved place to record task changes." -ForegroundColor White
Write-Host ""
Write-Header "CLAUDE UPLOAD INSTRUCTIONS"
Write-Host ""
Write-Host "  Upload these files to the Claude project:" -ForegroundColor White
Write-Host "    1. $sessionFileName" -ForegroundColor Yellow
if ($PlanFile) {
    Write-Host "    2. $(Split-Path $PlanFile -Leaf)" -ForegroundColor Yellow
}
Write-Host "    3. AceCommander-Project-State.md" -ForegroundColor Yellow
Write-Host "    4. TASKS.md" -ForegroundColor Yellow
Write-Host "    5. ScopeCreep-Adopted.md  (duplicate detection)" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Suggested opening prompt:" -ForegroundColor White
Write-Host @"

  "Here is today's scope-creep triage session. For each idea:
   1. Recommend Adopt, Defer, or Reject with a brief rationale.
   2. For Adopted ideas: InsertAt (week + task), ImpactWeeks, milestone
      shifts, NewProjectEnd, and the TASKS.md entries to add.
   3. Check ScopeCreep-Adopted.md for near-duplicates before adopting.
   4. Produce a completed session document I can save to the worktree.
   5. Produce the updated TASKS.md sections for any adopted ideas."

"@ -ForegroundColor DarkGray

Write-Host "  When done, save the session doc to the worktree and run:" -ForegroundColor White
Write-Host "    .\Scripts\Complete-PlanningSession.ps1 -SessionFile '$sessionFileName'" -ForegroundColor Yellow
Write-Host "  (run from _Planning main repo or from the worktree — both work)" -ForegroundColor DarkGray
Write-Host ""

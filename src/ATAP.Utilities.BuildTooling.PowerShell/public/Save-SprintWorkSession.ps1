# Save-SprintWorkSession.ps1
# Archives the current Claude Code conversation JSONL and copies memory files
# for the current sprint work session.
#
# Usage: run from the repo root whose session you want to save.
#   pwsh -File Save-SprintWorkSession.ps1
#   pwsh -File Save-SprintWorkSession.ps1 -SprintN 0006
#   pwsh -File Save-SprintWorkSession.ps1 -SprintN 0006 -PlanningRoot "C:\...\GitHub\_Planning-wt-12-sprint-0006-work-items"
#
# -SprintN      auto-detected from current branch (regex ^\d+-sprint-(\d{4})-.+$)
#               when omitted. Pass to override.
# -PlanningRoot auto-resolved from sibling directories matching
#               ^_Planning-wt-\d+-sprint-<SprintN> when omitted. Falls back to
#               main _Planning if no sprint worktree is found.

param(
    [string]$SprintN = "",
    [string]$PlanningRoot = ""
)

$claudeProjectsRoot = "C:\Users\whertzing\.claude\projects"

# --- auto-detect sprint number from branch ---
$branch = git rev-parse --abbrev-ref HEAD
if (-not $SprintN) {
    if ($branch -match '^\d+-sprint-(\d{4})-.+$') {
        $SprintN = $Matches[1]
        Write-Host "Sprint number auto-detected from branch '$branch': $SprintN"
    }
    else {
        Write-Warning "Current branch '$branch' is not a sprint branch (expected ^\d+-sprint-(\d{4})-.+$)."
        Write-Host "Re-run with -SprintN <NNNN> to override (e.g. -SprintN 0006)."
        exit 1
    }
}
$sprintN = $SprintN

# --- auto-resolve _Planning worktree from siblings ---
if (-not $PlanningRoot) {
    $parentDir = Split-Path -Parent (Get-Location).Path
    $planningWTs = @(Get-ChildItem $parentDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "^_Planning-wt-\d+-sprint-$sprintN" })

    if ($planningWTs.Count -eq 1) {
        $PlanningRoot = $planningWTs[0].FullName
        Write-Host "Planning worktree auto-resolved: $PlanningRoot"
    }
    elseif ($planningWTs.Count -gt 1) {
        Write-Warning "Multiple _Planning sprint worktrees match sprint $sprintN. Pass -PlanningRoot to disambiguate:"
        $planningWTs | ForEach-Object { Write-Host "  $($_.FullName)" }
        exit 1
    }
    else {
        $PlanningRoot = "C:\Dropbox\whertzing\GitHub\_Planning"
        Write-Warning "No _Planning sprint worktree found for sprint $sprintN. Falling back to main _Planning: $PlanningRoot"
    }
}
$planningRoot = $PlanningRoot

# --- derive project slug from cwd ---
# Claude Code slugs the project path by lowercasing the drive letter
# and replacing ':', '\', '_' with '-'.
$cwd = (Get-Location).Path
$slug = ($cwd.Substring(0, 1).ToLower() + $cwd.Substring(1)) -replace '[:\\._]', '-' -replace '^-', ''

# --- find most-recent session JSONL ---
$sessionDir = Join-Path $claudeProjectsRoot $slug
$jsonl = Get-ChildItem -Path $sessionDir -Filter "*.jsonl" |
Sort-Object LastWriteTime -Descending |
Select-Object -First 1

if (-not $jsonl) {
    Write-Warning "No JSONL found in $sessionDir — is the slug correct?"
    Write-Host "Slug derived: $slug"
    exit 1
}

# --- build name components ---
$ts = Get-Date -Format "yyyy-MM-dd-HH-mm"
$base = "SprintWorkSession-$sprintN"
$convName = "$base-Conversation-$branch-$ts"
$memName = "$base-$branch-$ts"

# --- 1. compress conversation JSONL ---
$convDir = Join-Path $planningRoot "SprintWorkSessionConversations"
New-Item -ItemType Directory -Path $convDir -Force | Out-Null
$archive = Join-Path $convDir "$convName.7z"
7z a $archive $jsonl.FullName
if (Test-Path $archive) {
    Write-Host "Conversation saved: $archive"
}
else {
    Write-Warning "Archive not created — check 7z is on PATH"
}

# --- 2. copy memory files ---
# Memory lives under the slug of the directory where Claude Code was launched
# (i.e. the current working directory), NOT under the _Planning slug.
$memSrcDir = Join-Path $claudeProjectsRoot "$slug\memory"
$memDstDir = Join-Path $planningRoot "SprintWorkSessionMemorys\$memName"

if (-not (Test-Path $memSrcDir)) {
    Write-Warning "Memory directory not found: $memSrcDir"
    Write-Host "Slug derived from cwd: $slug"
    Write-Host "Memory copy skipped — no memory files to save."
    return
}

New-Item -ItemType Directory -Path $memDstDir -Force | Out-Null
Copy-Item -Path (Join-Path $memSrcDir "*.md") -Destination $memDstDir -Force
$copied = (Get-ChildItem $memDstDir).Count
Write-Host "Memory files saved ($copied files): $memDstDir"

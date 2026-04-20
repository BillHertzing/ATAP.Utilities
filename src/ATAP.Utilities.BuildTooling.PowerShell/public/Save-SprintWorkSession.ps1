# Save-SprintWorkSession.ps1
# Archives the current Claude Code conversation JSONL and copies memory files
# for the current sprint work session.
#
# Usage: run from the repo root whose session you want to save.
#   pwsh -File Save-SprintWorkSession.ps1 -SprintN 0003
#   pwsh -File Save-SprintWorkSession.ps1 -SprintN 0003 -PlanningRoot "C:\...\GitHub\_Planning-wt-5-sprint-0003-work-items"
#
# -SprintN      defaults to "0003" if not supplied.
# -PlanningRoot defaults to main _Planning repo. Pass a sprint _Planning worktree
#               path to write output there instead.

param(
    [string]$SprintN = "0003",   # sprint number, zero-padded to 4 digits
    [string]$PlanningRoot = ""        # empty = fall back to main _Planning
)

# --- configuration ---
if (-not $PlanningRoot) {
    $PlanningRoot = "C:\Dropbox\whertzing\GitHub\_Planning"
}
$planningRoot = $PlanningRoot
$claudeProjectsRoot = "C:\Users\whertzing\.claude\projects"
$sprintN = $SprintN

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
$branch = git rev-parse --abbrev-ref HEAD
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
# Memory lives under the _Planning project slug, not the worktree-specific slug.
$planningSlug = ($planningRoot.Substring(0, 1).ToLower() + $planningRoot.Substring(1)) -replace '[:\\._]', '-' -replace '^-', ''
$memSrcDir = Join-Path $claudeProjectsRoot "$planningSlug\memory"
$memDstDir = Join-Path $planningRoot "SprintWorkSessionMemorys\$memName"
New-Item -ItemType Directory -Path $memDstDir -Force | Out-Null
Copy-Item -Path (Join-Path $memSrcDir "*.md") -Destination $memDstDir -Force
$copied = (Get-ChildItem $memDstDir).Count
Write-Host "Memory files saved ($copied files): $memDstDir"

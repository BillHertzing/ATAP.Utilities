cmdlet New-WorktreeWithJunctions
param(
    [Parameter(Mandatory)][string]$SourceRepoPath,   # e.g. "C:\Dropbox\whertzing\GitHub\ATAP.Utilities"
    [Parameter(Mandatory)][string]$WorktreePath,      # e.g. "..\ATAP.Utilities-branch63"
    [Parameter(Mandatory)][string]$BranchName         # e.g. "63-update-atap-utilities-database-scripts"
)

$SourceRepoPath = Resolve-Path $SourceRepoPath

# Step 1: Create the worktree
Write-Host "Creating worktree at '$WorktreePath' for branch '$BranchName'..." -ForegroundColor Cyan
git -C $SourceRepoPath worktree add $WorktreePath $BranchName
if ($LASTEXITCODE -ne 0) { throw "git worktree add failed." }

$WorktreeFullPath = Resolve-Path $WorktreePath

# Step 2: Find all junctions in the source repo
Write-Host "Scanning for junctions in '$SourceRepoPath'..." -ForegroundColor Cyan

$junctions = Get-ChildItem -Path $SourceRepoPath -Recurse -Force -Attributes ReparsePoint |
    Where-Object { $_.LinkType -eq 'Junction' }

if (-not $junctions) {
    Write-Host "No junctions found. Done." -ForegroundColor Yellow
    return
}

Write-Host "Found $($junctions.Count) junction(s). Recreating in worktree..." -ForegroundColor Cyan

foreach ($junction in $junctions) {
    # Compute the relative path from source repo root
    $relativePath = $junction.FullName.Substring($SourceRepoPath.Path.Length).TrimStart('\')

    # Target path in the new worktree
    $newJunctionPath = Join-Path $WorktreeFullPath $relativePath

    # Junction's current target
    $target = $junction.Target

    # Ensure the parent directory exists in the worktree
    $parentDir = Split-Path $newJunctionPath -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    # Remove placeholder folder if git created one, then create junction
    if (Test-Path $newJunctionPath) {
        Remove-Item $newJunctionPath -Force -Recurse
    }

    New-Item -ItemType Junction -Path $newJunctionPath -Target $target | Out-Null
    Write-Host "  Created junction: $newJunctionPath -> $target" -ForegroundColor Green
}

Write-Host "`nWorktree setup complete with $($junctions.Count) junction(s) recreated." -ForegroundColor Cyan

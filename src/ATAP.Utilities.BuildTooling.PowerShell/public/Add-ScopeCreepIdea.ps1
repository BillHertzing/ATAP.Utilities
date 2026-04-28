<#
.SYNOPSIS
    Capture a new scope-creep idea into ScopeCreep-Inbox.md.

.DESCRIPTION
    Appends a formatted SC-NNNN entry to ScopeCreep-Inbox.md with auto-incremented ID.
    Runs interactively when parameters are omitted; fully parameterizable for profile aliases.

.PARAMETER Title
    Short, imperative description of the idea (e.g. "Add dark-mode toggle").

.PARAMETER SuggestedBy
    Name or handle of the person suggesting the idea. Defaults to "Self".

.PARAMETER Repo
    Primary repository affected.

.PARAMETER Context
    Feature area, plugin, or layer the idea touches.

.PARAMETER InitialSize
    Rough effort: XS (<2h), S (½-1d), M (2-4d), L (1-2wk), XL (>2wk).

.PARAMETER Description
    Free-form description. Can be multi-line if passed as a here-string.

.PARAMETER Paste
    If specified, reads the description from the clipboard instead of prompting.
    Equivalent to -Description (Get-Clipboard).

.PARAMETER GitCommit
    If specified, stages ScopeCreep-Inbox.md and commits with a structured message.

.EXAMPLE
    .\Add-ScopeCreepIdea.ps1
    # Fully interactive — prompts for each field.

.EXAMPLE
    .\Add-ScopeCreepIdea.ps1 -Title "Cache tile prefetch on WiFi" -SuggestedBy "Self" `
        -Repo AceCommander -Context "Outdoor Sharing / tile cache" `
        -InitialSize S -Description "Pre-fetch next zoom level on WiFi to cut wait time." `
        -GitCommit
#>

[CmdletBinding()]
param(
    [string]$Title,

    [string]$SuggestedBy,

    [ValidateSet('AceCommander', 'ATAP.Utilities', 'SharedVSCode', '_Planning', 'Cross-Repo')]
    [string]$Repo,

    [string]$Context,

    [ValidateSet('XS', 'S', 'M', 'L', 'XL')]
    [string]$InitialSize,

    [string]$Description,

    [switch]$Paste,

    [string]$Tags,

    [switch]$GitCommit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Locate files ────────────────────────────────────────────────────────────
function script:Find-PlanningWorktree {
    # The repos root is always C:\Dropbox\<username>\GitHub.
    # Look there for 'OverviewSprint*.code-workspace', parse the _Planning-wt-*
    # folder entry, and resolve it relative to the repos root.
    # Returns $null if no sprint workspace file exists.
    $reposRoot = "C:\Dropbox\$env:USERNAME\GitHub"
    $wsFiles = Get-ChildItem -Path $reposRoot -Filter 'OverviewSprint*.code-workspace' -File -ErrorAction SilentlyContinue
    if (-not $wsFiles) { return $null }
    $wsContent = Get-Content $wsFiles[0].FullName -Raw
    $m = [regex]::Match($wsContent, '"path"\s*:\s*"(_Planning-wt-[^"]+)"')
    if ($m.Success) {
        $candidate = Join-Path $reposRoot $m.Groups[1].Value
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

$found = Find-PlanningWorktree
$planningRoot = if ($found) {
    $found
} else {
    # Fallback: use the repo root that contains this script (stable _Planning tree)
    Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$inboxPath = Join-Path $planningRoot 'ScopeCreepManagement' 'ScopeCreep-Inbox.md'

if (-not (Test-Path $inboxPath)) {
    Write-Error "ScopeCreep-Inbox.md not found at: $inboxPath"
    exit 1
}

# ── Determine next SC-NNNN ID ────────────────────────────────────────────────
$content = Get-Content $inboxPath -Raw
$idMatches = [regex]::Matches($content, '(?m)^## SC-(\d{4})')
$existingIds = @($idMatches | ForEach-Object { [int]$_.Groups[1].Value })
$nextNum = if ($existingIds.Count -gt 0) { [int]($existingIds | Measure-Object -Maximum).Maximum + 1 } else { 1 }
$scId = 'SC-{0:D4}' -f $nextNum

Write-Host "`n  Adding $scId to ScopeCreep-Inbox.md`n" -ForegroundColor Cyan

# ── Interactive prompts for missing parameters ───────────────────────────────
function Prompt-Required {
    param([string]$Field, [string]$Hint = '')
    $prompt = if ($Hint) { "$Field ($Hint)" } else { $Field }
    $value = ''
    while (-not $value.Trim()) {
        $value = Read-Host "  $prompt"
        if (-not $value.Trim()) { Write-Host '  (required — cannot be blank)' -ForegroundColor Yellow }
    }
    return $value.Trim()
}

function Prompt-Menu {
    param([string]$Field, [string[]]$Options)
    Write-Host "  $Field" -ForegroundColor White
    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host "    [$($i+1)] $($Options[$i])"
    }
    $choice = ''
    while ($choice -notmatch '^\d+$' -or [int]$choice -lt 1 -or [int]$choice -gt $Options.Count) {
        $choice = Read-Host "  Choice (1-$($Options.Count))"
    }
    return $Options[[int]$choice - 1]
}

if (-not $Title) { $Title = Prompt-Required 'Title' 'short imperative phrase' }
if (-not $SuggestedBy) {
    $raw = Read-Host '  SuggestedBy (name/handle, Enter = Self)'
    $SuggestedBy = if ($raw.Trim()) { $raw.Trim() } else { 'Self' }
}
if (-not $Repo) {
    $Repo = Prompt-Menu 'Repo' @('AceCommander', 'ATAP.Utilities', 'SharedVSCode', '_Planning', 'Cross-Repo')
}
if (-not $Context) { $Context = Prompt-Required 'Context' 'plugin / layer / feature area' }
if (-not $InitialSize) {
    $InitialSize = Prompt-Menu 'Initial size  [XS <2h | S ½-1d | M 2-4d | L 1-2wk | XL >2wk]' `
    @('XS', 'S', 'M', 'L', 'XL')
}
if ($Paste -and -not $Description) {
    $Description = Get-Clipboard
    if (-not $Description.Trim()) {
        Write-Error '-Paste was specified but the clipboard is empty.'
        exit 1
    }
    Write-Host "  Description (from clipboard): $Description" -ForegroundColor DarkGray
}
if (-not $Description) {
    Write-Host '  Description (single line; you can expand in the file later):'
    $Description = Prompt-Required 'Description'
}
if (-not $Tags) {
    $raw = Read-Host '  Tags (optional, comma-separated PascalCase from Tags-Taxonomy.md, Enter to skip)'
    $Tags = $raw.Trim()
}

# ── Build the entry ──────────────────────────────────────────────────────────
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm'

# Indent continuation lines of description for YAML-ish block scalar style
$descLines = $Description -split "`n"
$descFormatted = $descLines[0]
if ($descLines.Count -gt 1) {
    $rest = $descLines[1..($descLines.Count - 1)] | ForEach-Object { "  $_" }
    $descFormatted = $descFormatted + "`n" + ($rest -join "`n")
}

$tagsLine = if ($Tags) { "`n- **Tags**: $Tags" } else { '' }

$entry = @"


## $scId
- **Title**: $Title
- **SuggestedBy**: $SuggestedBy
- **SuggestedDate**: $timestamp
- **Repo**: $Repo
- **Context**: $Context
- **InitialSize**: $InitialSize$tagsLine
- **Status**: Inbox
- **Description**: >
  $descFormatted
"@

# ── Append to inbox ──────────────────────────────────────────────────────────
Add-Content -Path $inboxPath -Value $entry -Encoding UTF8

Write-Host ''
Write-Host "  ✓ Recorded $scId — $Title" -ForegroundColor Green
Write-Host "    File: $inboxPath" -ForegroundColor DarkGray

# ── Optional git commit ──────────────────────────────────────────────────────
if ($GitCommit) {
    Push-Location $planningRoot
    try {
        git add (Resolve-Path $inboxPath -Relative)
        git commit -m "chore(inbox): capture $scId — $Title"
        Write-Host '  ✓ Committed to git' -ForegroundColor Green
    } catch {
        Write-Warning "Git commit failed: $_"
    } finally {
        Pop-Location
    }
}

Write-Host ''
